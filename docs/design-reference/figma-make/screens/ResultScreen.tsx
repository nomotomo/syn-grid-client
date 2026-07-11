import ItemCard, { type ItemCardData } from '../components/ItemCard'

const ITEM_STATS: Array<ItemCardData & { dmg: number; shots: number; synBonus: number; critRate: number }> =
  [
    {
      name: 'VOIDBLADE',
      icon: '⚔️',
      rarity: 'epic',
      category: 'weapon',
      atk: 42,
      spd: 18,
      dmg: 186,
      shots: 12,
      synBonus: 18,
      critRate: 33,
    },
    {
      name: 'SHADOWMANTLE',
      icon: '🛡️',
      rarity: 'gold',
      category: 'armor',
      def: 35,
      spd: 12,
      dmg: 0,
      shots: 0,
      synBonus: 18,
      critRate: 0,
    },
    {
      name: 'NECROFLASK',
      icon: '🧪',
      rarity: 'silver',
      category: 'potion',
      atk: 15,
      def: 20,
      dmg: 62,
      shots: 8,
      synBonus: 5,
      critRate: 12,
    },
    {
      name: 'GRIMHELM',
      icon: '⛓️',
      rarity: 'gold',
      category: 'armor',
      def: 45,
      spd: 8,
      dmg: 0,
      shots: 0,
      synBonus: 0,
      critRate: 0,
    },
  ]

const ADVICE_TIPS = [
  { icon: '⚠️', text: 'Health Tonic never fired this fight — check its placement.' },
  { icon: '💡', text: 'Longbow never synergized with a neighbor. Try positioning it next to an Archer unit.' },
]

type StatTone = 'crimson' | 'muted' | 'teal' | 'gold'

const STAT_TONE_CLASS: Record<StatTone, string> = {
  crimson: 'text-crimson',
  muted: 'text-text',
  teal: 'text-teal',
  gold: 'text-amber',
}

export default function ResultScreen({
  variant = 'victory',
  onContinue,
  onReport,
}: {
  variant?: 'victory' | 'defeat'
  onContinue: () => void
  onReport: () => void
}) {
  const win = variant === 'victory'
  const totalDmg = ITEM_STATS.reduce((s, i) => s + i.dmg, 0)
  const totalShots = ITEM_STATS.reduce((s, i) => s + i.shots, 0)
  const avgSyn = Math.round(ITEM_STATS.reduce((s, i) => s + i.synBonus, 0) / ITEM_STATS.length)
  const shooters = ITEM_STATS.filter((i) => i.shots > 0)
  const avgCrit = Math.round(shooters.reduce((s, i) => s + i.critRate, 0) / shooters.length)

  const aggregateStats: { label: string; value: string | number; tone: StatTone }[] = [
    { label: 'DMG DEALT', value: totalDmg, tone: 'crimson' },
    { label: 'SHOTS', value: totalShots, tone: 'muted' },
    { label: 'SYN BONUS', value: `${avgSyn}%`, tone: 'teal' },
    { label: 'CRIT RATE', value: `${avgCrit}%`, tone: 'gold' },
  ]

  return (
    <div className="screen-canvas result-canvas">
      <div
        className={`result-ambient ${win ? 'result-ambient--victory' : 'result-ambient--defeat'}`}
        aria-hidden="true"
      />

      <header className="px-6 pt-10 pb-2 flex justify-between items-start relative z-[var(--z-content)]">
        <div>
          <div className="result-hud-label">LIFE</div>
          <div className="flex gap-1">
            {[...Array(8)].map((_, i) => (
              <span
                key={i}
                className={`text-base ${win && i < 6 ? '' : 'grayscale opacity-30'}`}
                aria-hidden="true"
              >
                {win ? '❤️' : '💔'}
              </span>
            ))}
          </div>
        </div>

        <div className="text-right">
          <div className="result-hud-label">
            TRIUMPH{' '}
            <span className="text-purple font-mono text-xs">3/10</span>
          </div>
          <div className="flex gap-0.5 justify-end">
            {[...Array(10)].map((_, i) => (
              <div
                key={i}
                className={`triumph-orb${i < 3 ? ' triumph-orb--filled' : ''}`}
                aria-hidden="true"
              />
            ))}
          </div>
        </div>
      </header>

      <div className="flex flex-col items-center py-4 relative z-[var(--z-content)]">
        <h1
          className={[
            'text-display-hero crt-logo m-0',
            win ? 'text-teal text-glow-teal animate-victory-pulse' : 'text-crimson result-headline--defeat',
          ].join(' ')}
        >
          {win ? 'VICTORY' : 'DEFEAT'}
        </h1>
        <p className="result-subtitle m-0">ROUND 4 COMPLETE · +3 GOLD EARNED</p>
      </div>

      <div className="px-6 mb-4 relative z-[var(--z-content)]">
        <div
          className={[
            'result-summary-banner',
            win ? 'result-summary-banner--victory' : 'result-summary-banner--defeat',
            win ? 'result-summary-banner--pulse' : '',
          ]
            .filter(Boolean)
            .join(' ')}
        >
          {win
            ? '⚔️ Void Pact synergy (+18% ATK) let VOIDBLADE chain two kills. SHADOWMANTLE absorbed lethal damage in the final frame.'
            : '💀 PHANTOMCLAW outpaced your speed tier and targeted VOIDBLADE first. Consider more SPD items or a frontline armor.'}
        </div>
      </div>

      <div className="px-6 mb-4 relative z-[var(--z-content)]">
        <div className="flex flex-col gap-2">
          {ADVICE_TIPS.map((tip) => (
            <div key={tip.text} className="result-advice-card">
              <span className="text-base shrink-0" aria-hidden="true">
                {tip.icon}
              </span>
              <span className="text-body text-[11px] leading-snug">{tip.text}</span>
            </div>
          ))}
        </div>
      </div>

      <section className="px-6 mb-3 relative z-[var(--z-content)]">
        <div className="result-hud-label mb-2">COMBAT ANALYSIS</div>
        <div className="grid grid-cols-4 gap-2">
          {aggregateStats.map((s) => (
            <div key={s.label} className="result-stat-tile">
              <div className={`text-mono-stat text-lg ${STAT_TONE_CLASS[s.tone]}`}>{s.value}</div>
              <div className="text-[8px] text-text-faint tracking-normal mt-0.5 font-body">
                {s.label}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="px-6 flex-1 overflow-y-auto scroll-hide relative z-[var(--z-content)] min-h-0">
        <div className="result-hud-label mb-2">PER-UNIT BREAKDOWN</div>
        <div className="flex flex-col gap-2 pb-2">
          {ITEM_STATS.map((item) => (
            <div key={item.name} className="result-unit-row">
              <div className="shrink-0">
                <ItemCard item={item} variant="bench" />
              </div>
              <div className="flex-1 grid grid-cols-4 gap-1">
                {[
                  { label: 'DMG', value: item.dmg || '—', tone: 'crimson' as StatTone },
                  { label: 'SHOTS', value: item.shots || '—', tone: 'muted' as StatTone },
                  {
                    label: 'SYN%',
                    value: item.synBonus ? `+${item.synBonus}%` : '—',
                    tone: 'teal' as StatTone,
                  },
                  {
                    label: 'CRIT%',
                    value: item.critRate ? `${item.critRate}%` : '—',
                    tone: 'gold' as StatTone,
                  },
                ].map((s) => (
                  <div key={s.label} className="text-center">
                    <div className={`text-mono-stat text-xs ${STAT_TONE_CLASS[s.tone]}`}>
                      {s.value}
                    </div>
                    <div className="text-[7.5px] text-text-faint tracking-wide font-body">
                      {s.label}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </section>

      <footer className="result-footer flex flex-col items-center gap-3 px-6 py-4 relative z-[var(--z-content)]">
        <button
          type="button"
          onClick={onContinue}
          className="aurora-btn font-display font-bold uppercase tracking-wider text-xl px-12 py-4 cursor-pointer"
        >
          {win ? '▶ CONTINUE' : '↺ NEW RUN'}
        </button>
        <button type="button" onClick={onReport} className="result-report-link">
          VIEW REPORT
        </button>
      </footer>
    </div>
  )
}
