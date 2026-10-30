## Project rules
- UI text is translated inline with `useI18n().t(fr, en, ar)` (or `Tri` tuples + `labelOf` for shared labels in `src/lib/platform.ts`); French renders on the server and the stored language applies after hydration — keeps SSR and hydration consistent without a translation library.
- Stored database values (statuses, vehicle types, services) stay as fixed keys/French values; only their displayed labels are translated — avoids data migrations when wording changes.
- Theme is the `.dark` class on `<html>`, set before paint by `themeInitScript` and toggled by `ThemeToggle`; light is the default — prevents a flash of the wrong theme.
- Styling uses semantic tokens and shared classes in `src/styles.css` with logical (inline-start/end) properties — required for correct Arabic RTL layout.
- App images must be bundled files imported from `src/assets`.
- Supabase connection is 100% external via standard Supabase JS client and PostgreSQL functions.
- Public car categories (wedding / family) are derived from each car's `services` via `carInCategory` in `src/lib/platform.ts`, not stored separately — one source of truth for filters, badges and home sections.
