export type HUDPillVariant = 'life' | 'gold' | 'round' | 'triumph' | 'accent'

const VARIANT_CLASS: Record<HUDPillVariant, string> = {
  life: 'pill-life',
  gold: 'pill-gold',
  round: 'pill-round',
  triumph: 'pill-triumph',
  accent: '',
}

/** Maps legacy hex color props (GridScreen) to semantic variants during migration. */
const LEGACY_COLOR_VARIANT: Record<string, HUDPillVariant> = {
  '#00f5d4': 'accent',
  '#d81e3d': 'life',
  '#ffb627': 'gold',
  '#c8cdd6': 'round',
  '#7b2fbe': 'triumph',
}

interface HUDPillProps {
  icon: string
  value: string | number
  variant?: HUDPillVariant
  /** @deprecated Prefer `variant` (life | gold | round | triumph | accent). */
  color?: string
}

export default function HUDPill({ icon, value, variant, color }: HUDPillProps) {
  const resolvedVariant =
    variant ??
    (color ? LEGACY_COLOR_VARIANT[color.trim().toLowerCase()] : undefined) ??
    'accent'

  const variantClass = VARIANT_CLASS[resolvedVariant]

  return (
    <div className={`pill-capsule${variantClass ? ` ${variantClass}` : ''}`}>
      <span className="text-sm leading-none flex items-center justify-center" aria-hidden="true">
        {icon}
      </span>
      <span className="pill-capsule__value">{value}</span>
    </div>
  )
}
