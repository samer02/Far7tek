import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { useI18n } from "@/lib/i18n";

export const THEME_STORAGE_KEY = "far7tek-theme";

/** Runs before paint: applies the saved theme (light by default) and text direction. */
export const themeInitScript = `try{var d=document.documentElement;if(localStorage.getItem('${THEME_STORAGE_KEY}')==='dark')d.classList.add('dark');var l=localStorage.getItem('far7tek-lang');if(l==='ar'){d.dir='rtl';d.lang='ar'}else if(l==='en'){d.lang='en'}}catch(e){}`;

export function ThemeToggle({ className = "" }: { className?: string }) {
  const { t } = useI18n();
  const [dark, setDark] = useState(false);
  useEffect(() => setDark(document.documentElement.classList.contains("dark")), []);

  function toggle() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    try {
      localStorage.setItem(THEME_STORAGE_KEY, next ? "dark" : "light");
    } catch {
      /* storage unavailable */
    }
  }

  const label = dark ? t("Mode clair", "Light mode", "الوضع الفاتح") : t("Mode sombre", "Dark mode", "الوضع الداكن");
  return (
    <button type="button" className={`icon-btn ${className}`} onClick={toggle} aria-label={label} title={label}>
      {dark ? <Sun /> : <Moon />}
    </button>
  );
}
