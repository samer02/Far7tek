import { useState, type InputHTMLAttributes } from "react";
import { Check } from "lucide-react";
import { CAR_COLORS, findCarColor } from "@/lib/platform";
import { useI18n } from "@/lib/i18n";

/** Plain text box that only accepts digits (no up/down arrows). */
export function NumberInput(props: Omit<InputHTMLAttributes<HTMLInputElement>, "type">) {
  return (
    <input
      {...props}
      type="text"
      inputMode="numeric"
      autoComplete="off"
      dir="ltr"
      onInput={(e) => {
        const el = e.currentTarget;
        const clean = el.value.replace(/[^0-9]/g, "");
        if (clean !== el.value) el.value = clean;
      }}
    />
  );
}

/** Colour swatches; the chosen colour is sent with the form under `name`. */
export function ColorPalette({ name, defaultValue = "" }: { name: string; defaultValue?: string }) {
  const { p, t } = useI18n();
  const [value, setValue] = useState(() => findCarColor(defaultValue)?.value ?? defaultValue);
  const current = CAR_COLORS.find((c) => c.value === value);
  return (
    <div className="color-palette">
      <input type="hidden" name={name} value={value} />
      <div className="color-swatches" role="radiogroup" aria-label={t("Couleur", "Colour", "اللون")}>
        {CAR_COLORS.map((c) => (
          <button
            key={c.value}
            type="button"
            role="radio"
            aria-checked={value === c.value}
            aria-label={p(c.label)}
            title={p(c.label)}
            className="color-swatch"
            style={{ backgroundColor: c.hex }}
            onClick={() => setValue(c.value)}
          >
            {value === c.value && <Check />}
          </button>
        ))}
      </div>
      <small className="color-current">{current ? p(current.label) : value || t("Choisissez une couleur", "Pick a colour", "اختر لوناً")}</small>
    </div>
  );
}

/** Small dot showing a stored car colour. */
export function ColorDot({ color }: { color: string | null | undefined }) {
  const c = findCarColor(color);
  if (!c) return null;
  return <span className="color-dot" style={{ backgroundColor: c.hex }} aria-hidden />;
}
