/**
 * Lightweight i18n for the SIS map view (and, progressively, the admin panel).
 *
 * Resolution order for the active language:
 *   1. the visitor's own choice (localStorage 'sis_lang', set by the selector)
 *   2. the instance default (api.setting LANGUAGE, applied via
 *      setInstanceDefault() once settings are loaded)
 *   3. English
 *
 * t(key, params) falls back key → active locale → English → the key itself,
 * so a missing translation can never break the UI. New languages are one JSON
 * file in src/locales/ plus one entry in AVAILABLE.
 */
import en from '../locales/en.json';
import es from '../locales/es.json';
import pt from '../locales/pt.json';
import ru from '../locales/ru.json';

const LOCALES = { en, es, pt, ru };
export const AVAILABLE = [
  ['en', 'English'],
  ['es', 'Español'],
  ['pt', 'Português'],
  ['ru', 'Русский'],
];

let instanceDefault = 'en';

function stored() {
  try { return localStorage.getItem('sis_lang'); } catch (e) { return null; }
}

export function currentLang() {
  const s = stored();
  if (s && LOCALES[s]) return s;
  return LOCALES[instanceDefault] ? instanceDefault : 'en';
}

export function setInstanceDefault(code) {
  if (code && LOCALES[code]) instanceDefault = code;
}

export function switchLanguage(code) {
  try { localStorage.setItem('sis_lang', code); } catch (e) { /* private mode */ }
  location.reload();
}

export function t(key, params) {
  const l = currentLang();
  let s = (LOCALES[l] && LOCALES[l][key]) || LOCALES.en[key] || key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      s = s.replace(`{${k}}`, v);
    }
  }
  return s;
}
