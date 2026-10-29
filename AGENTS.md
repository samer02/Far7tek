<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

## Project rules
- UI text is translated inline with `useI18n().t(fr, en, ar)` (or `Tri` tuples + `labelOf` for shared labels in `src/lib/platform.ts`); French renders on the server and the stored language applies after hydration — keeps SSR and hydration consistent without a translation library.
- Stored database values (statuses, vehicle types, services) stay as fixed keys/French values; only their displayed labels are translated — avoids data migrations when wording changes.
- Theme is the `.dark` class on `<html>`, set before paint by `themeInitScript` and toggled by `ThemeToggle`; light is the default — prevents a flash of the wrong theme.
- Styling uses semantic tokens and shared classes in `src/styles.css` with logical (inline-start/end) properties — required for correct Arabic RTL layout.
