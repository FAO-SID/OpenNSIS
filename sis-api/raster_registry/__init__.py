"""
Raster registry — shared service that turns a GeoTIFF on disk into a
fully-registered SIS layer (soil_data.* rows + XML in pyCSW).

Used by:
  - Add Raster (operator uploads a TIFF)
  - DST engine (recipe writes a TIFF, then calls the registrar)

See /home/carva014/Work/Code/FAO/OpenNSIS/RASTER-AND-DST-PLAN.md for the
broader plan and the relationship to the external pipeline in
~/Work/Code/FAO/GloSIS-private/Metadata/.
"""

from .register import register_raster  # noqa: F401
