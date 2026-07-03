"""DST engine — turn a recipe JSON into a GeoTIFF.

Recipe shape (see RASTER-AND-DST-PLAN.md for full details):

    {
      "steps": [
        { "step_id": 1, "layer_id": "BT-...",
          "op": ">",       "threshold": 50,
          "true_score": 1, "false_score": 0, "weight": 1 },
        { "step_id": 2, "layer_id": "BT-...",
          "op": "between", "low": 5.5, "high": 7.0,
          "true_score": 1, "false_score": 0, "weight": 2 }
      ],
      "aggregation":      "sum",       # sum | min | max | mean | product
      "no_data_handling": "propagate", # propagate | treat_as_zero
      "metadata": { ... }              # passed through to register_raster
    }

v1 constraints:
- All input layers must share grid + CRS (no on-the-fly reprojection).
- Single-band rasters only (we read band 1).
"""

import logging
import os
from typing import Optional

import numpy as np
import rasterio

log = logging.getLogger("raster_registry")


SUPPORTED_OPS = {">", ">=", "<", "<=", "==", "!=", "between"}
SUPPORTED_AGG = {"sum", "min", "max", "mean", "product"}
# Identity element per aggregation — masked (no-data) pixels contribute this so
# they don't affect the running accumulator (see execute_recipe's streaming fold).
_AGG_IDENTITY = {
    "sum": 0.0, "mean": 0.0, "product": 1.0,
    "min": float("inf"), "max": float("-inf"),
}
RASTER_DIR = os.getenv("RASTER_DIR", "/srv/rasters")


def _resolve_input_path(cur, layer_id: str) -> Optional[str]:
    """Return the on-disk path for a layer's TIFF, or None if not found."""
    cur.execute(
        """
        SELECT file_path, file_extension
        FROM soil_data.layer
        WHERE layer_id = %s
        """,
        (layer_id,),
    )
    row = cur.fetchone()
    if not row:
        return None
    file_path, file_extension = row
    ext = (file_extension or "tif").lstrip(".")
    if file_path:
        candidate = os.path.join(file_path, f"{layer_id}.{ext}")
        if os.path.exists(candidate):
            return candidate
    fallback = os.path.join(RASTER_DIR, f"{layer_id}.{ext}")
    return fallback if os.path.exists(fallback) else None


def validate_recipe(conn, recipe: dict) -> dict:
    """Dry-run: confirm shape, that input layers exist on disk, and that all
    grids match. Returns {ok, warnings, errors, n_steps, grid}."""
    errors = []
    warnings = []
    steps = recipe.get("steps") or []
    if not steps:
        errors.append("recipe has no steps")
    agg = recipe.get("aggregation", "sum")
    if agg not in SUPPORTED_AGG:
        errors.append(f"unsupported aggregation: {agg!r}")

    grid = None
    with conn.cursor() as cur:
        for i, step in enumerate(steps):
            op = step.get("op")
            if op not in SUPPORTED_OPS:
                errors.append(f"step {i}: unsupported op {op!r}")
            layer_id = step.get("layer_id")
            if not layer_id:
                errors.append(f"step {i}: missing layer_id")
                continue
            path = _resolve_input_path(cur, layer_id)
            if not path:
                errors.append(f"step {i}: input layer {layer_id!r} not found on disk")
                continue
            try:
                with rasterio.open(path) as src:
                    here = (src.width, src.height, tuple(src.transform[:6]),
                            str(src.crs))
            except Exception as e:
                errors.append(f"step {i}: cannot open {layer_id!r}: {e}")
                continue
            if grid is None:
                grid = here
            elif here != grid:
                errors.append(
                    f"step {i}: grid mismatch — {layer_id!r} does not align "
                    "with earlier inputs (CRS / transform / size differ)"
                )

    return {
        "ok": not errors,
        "errors": errors,
        "warnings": warnings,
        "n_steps": len(steps),
        "grid": (
            {"width": grid[0], "height": grid[1],
             "transform": list(grid[2]), "crs": grid[3]}
            if grid else None
        ),
    }


def _apply_op(arr: np.ndarray, step: dict) -> np.ndarray:
    op = step["op"]
    ts = float(step.get("true_score", 1))
    fs = float(step.get("false_score", 0))
    w = float(step.get("weight", 1))

    if op == "between":
        lo = float(step["low"])
        hi = float(step["high"])
        cond = (arr >= lo) & (arr <= hi)
    else:
        thr = float(step["threshold"])
        if op == ">":
            cond = arr > thr
        elif op == ">=":
            cond = arr >= thr
        elif op == "<":
            cond = arr < thr
        elif op == "<=":
            cond = arr <= thr
        elif op == "==":
            cond = arr == thr
        elif op == "!=":
            cond = arr != thr
        else:
            raise ValueError(f"unsupported op {op!r}")

    out = np.where(cond, ts, fs).astype(np.float32)
    if w != 1:
        out *= w
    return out


def _aggregate(stack: np.ndarray, agg: str) -> np.ndarray:
    if agg == "sum":
        return stack.sum(axis=0)
    if agg == "product":
        return stack.prod(axis=0)
    if agg == "min":
        return stack.min(axis=0)
    if agg == "max":
        return stack.max(axis=0)
    if agg == "mean":
        return stack.mean(axis=0)
    raise ValueError(f"unsupported aggregation {agg!r}")


def execute_recipe(
    conn,
    recipe: dict,
    *,
    output_layer_id: str,
    output_dir: str = RASTER_DIR,
) -> str:
    """Apply the recipe pixel-wise. Writes a GeoTIFF and returns its path.

    Caller is responsible for the surrounding transaction / status updates.
    """
    steps = recipe["steps"]
    if not steps:
        raise ValueError("recipe has no steps")
    agg = recipe.get("aggregation", "sum")
    if agg not in SUPPORTED_AGG:
        raise ValueError(f"unsupported aggregation {agg!r}")
    no_data_mode = recipe.get("no_data_handling", "propagate")

    layer_paths = []
    with conn.cursor() as cur:
        for i, step in enumerate(steps):
            path = _resolve_input_path(cur, step["layer_id"])
            if not path:
                raise FileNotFoundError(
                    f"step {i}: input layer {step['layer_id']!r} not on disk"
                )
            layer_paths.append(path)

    profile = None

    # NULL (no-data) pixels are excluded per-layer from the aggregation rather
    # than propagated: the output is NULL only at pixels where EVERY input was
    # NULL. (`no_data_mode` is kept on the recipe for back-compat but is now a
    # no-op — "skip" is the only mode.)
    #
    # We FOLD each input into a running accumulator instead of stacking all
    # inputs in memory. The old stack-then-aggregate form held O(n_inputs)
    # full rasters at once (plus the stack copy) and OOM-killed the worker on
    # country-scale grids. This streaming form holds ~3 rasters regardless of
    # how many inputs the recipe has.
    ident = _AGG_IDENTITY[agg]
    acc = None          # running aggregate (float32)
    any_valid = None    # bool: at least one input was valid at this pixel
    count = None        # number of valid inputs per pixel (mean only)

    for step, path in zip(steps, layer_paths):
        with rasterio.open(path) as src:
            if profile is None:
                profile = src.profile.copy()
            arr = src.read(1, masked=True)
        mask = np.ma.getmaskarray(arr)
        valid = ~mask
        data = np.ma.filled(arr, fill_value=0).astype(np.float32)
        scored = _apply_op(data, step)
        # Masked pixels contribute the identity element so they don't change
        # the result (0 for sum/mean, 1 for product, ±inf for min/max).
        contrib = np.where(valid, scored, np.float32(ident))
        if acc is None:
            acc = contrib.astype(np.float32, copy=True)
            any_valid = valid.copy()
            if agg == "mean":
                count = valid.astype(np.float32)
        else:
            if agg in ("sum", "mean"):
                acc += contrib
                if agg == "mean":
                    count += valid
            elif agg == "product":
                acc *= contrib
            elif agg == "min":
                np.minimum(acc, contrib, out=acc)
            elif agg == "max":
                np.maximum(acc, contrib, out=acc)
            any_valid |= valid
        del arr, mask, valid, data, scored, contrib

    nodata_value = -9999.0
    if agg == "mean":
        with np.errstate(invalid="ignore", divide="ignore"):
            acc = np.where(count > 0, acc / np.where(count > 0, count, 1.0), 0.0).astype(np.float32)
    # Output is NULL only where no input had a valid pixel at all.
    result = np.where(any_valid, acc, np.float32(nodata_value)).astype(np.float32)

    os.makedirs(output_dir, exist_ok=True)
    out_path = os.path.join(output_dir, f"{output_layer_id}.tif")
    # Write to a temp file then atomic-rename. Overwriting in place keeps the
    # same inode; GDAL (in MapServer) keeps serving from its block cache, which
    # leaves rendered WMS tiles stale even when the bytes on disk are new. A new
    # inode forces a re-read.
    #
    # Output is a Cloud-Optimised GeoTIFF (COG): DEFLATE + predictor 2, internal
    # tiling and overviews — so MapServer renders faster when zoomed out and the
    # file is a valid COG for direct download. GDAL's COG driver is CreateCopy-
    # only, so write a plain tiled GeoTIFF first and copy it into a COG.
    import rasterio.shutil as _rio_shutil

    src_profile = profile.copy()
    src_profile.update(
        driver="GTiff", dtype="float32", count=1, nodata=nodata_value,
        compress="deflate", tiled=True, blockxsize=512, blockysize=512,
    )
    src_profile.pop("interleave", None)

    tmp_src = out_path + ".src.tif"
    tmp_cog = out_path + ".cog.tif"
    try:
        with rasterio.open(tmp_src, "w", **src_profile) as dst:
            dst.write(result, 1)
        _rio_shutil.copy(
            tmp_src, tmp_cog, driver="COG",
            compress="DEFLATE", predictor=2, blocksize=512,
            # nearest keeps exact score values in the overviews — averaging
            # would invent in-between values and corrupt categorical outputs.
            overview_resampling="nearest", num_threads="ALL_CPUS",
        )
        os.replace(tmp_cog, out_path)
    finally:
        for _p in (tmp_src, tmp_cog):
            if os.path.exists(_p):
                try:
                    os.remove(_p)
                except OSError:
                    pass

    log.info("DST engine wrote %s (%d steps, agg=%s)", out_path, len(steps), agg)
    return out_path
