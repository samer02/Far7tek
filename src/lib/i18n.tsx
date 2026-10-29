import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type Lang = "fr" | "en" | "ar";
/** A label in the three supported languages: [fr, en, ar]. */
export type Tri = readonly [string, string, string];

export const LANGS: { code: Lang; short: string; name: string }[] = [
  { code: "fr", short: "FR", name: "Français" },
  { code: "en", short: "EN", name: "English" },
  { code: "ar", short: "ع", name: "العربية" },
];

export const LANG_STORAGE_KEY = "far7tek-lang";
const INDEX: Record<Lang, 0 | 1 | 2> = { fr: 0, en: 1, ar: 2 };
const LOCALES: Record<Lang, string> = { fr: "fr-FR", en: "en-GB", ar: "ar-MA-u-nu-latn" };

export const pick = (t: Tri, lang: Lang) => t[INDEX[lang]];
export const labelOf = (map: Record<string, Tri>, key: string, lang: Lang) => (map[key] ? pick(map[key], lang) : key);

type Ctx = {
  lang: Lang;
  locale: string;
  dir: "ltr" | "rtl";
  setLang: (l: Lang) => void;
  t: (fr: string, en: string, ar: string) => string;
  p: (tri: Tri) => string;
  date: (d: string) => string;
  dateTime: (d: string) => string;
};

function build(lang: Lang, setLang: (l: Lang) => void): Ctx {
  const locale = LOCALES[lang];
  return {
    lang,
    locale,
    dir: lang === "ar" ? "rtl" : "ltr",
    setLang,
    t: (fr, en, ar) => (lang === "ar" ? ar : lang === "en" ? en : fr),
    p: (tri) => pick(tri, lang),
    date: (d) => new Date(d).toLocaleDateString(locale),
    dateTime: (d) => new Date(d).toLocaleString(locale),
  };
}

const fallback = build("fr", () => {});
const I18nContext = createContext<Ctx>(fallback);

export function I18nProvider({ children }: { children: ReactNode }) {
  // Server and first client render are always French; the stored choice is applied after hydration.
  const [lang, setLangState] = useState<Lang>("fr");

  useEffect(() => {
    try {
      const s = localStorage.getItem(LANG_STORAGE_KEY);
      if (s === "en" || s === "ar" || s === "fr") setLangState(s);
    } catch {
      /* storage unavailable */
    }
  }, []);

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
  }, [lang]);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try {
      localStorage.setItem(LANG_STORAGE_KEY, l);
    } catch {
      /* storage unavailable */
    }
  }, []);

  const value = useMemo(() => build(lang, setLang), [lang, setLang]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export const useI18n = () => useContext(I18nContext);
