import { useState, useEffect, useRef } from 'react'
import HUDPill from '../components/HUDPill'
import ItemCard, { type ItemCardData } from '../components/ItemCard'

// ── item data by grid size ─────────────────────────────────────────────────

const PLAYER_4: Record<string, ItemCardData> = {
  A1: { name: 'VOIDBLADE', icon: '⚔️', rarity: 'epic', category: 'weapon', atk: 42, spd: 18 },
  B1: { name: 'SHADOWMANTLE', icon: '🛡️', rarity: 'gold', category: 'armor', def: 35, spd: 12 },
  C2: { name: 'NECROFLASK', icon: '🧪', rarity: 'silver', category: 'potion', atk: 15, def: 20 },
  B3: { name: 'GRIMHELM', icon: '⛓️', rarity: 'gold', category: 'armor', def: 45, spd: 8 },
}
const ENEMY_4: Record<string, ItemCardData> = {
  A1: { name: 'PHANTOMCLAW', icon: '👻', rarity: 'epic', category: 'weapon', atk: 50, spd: 25 },
  B1: { name: 'CURSESHIELD', icon: '💀', rarity: 'gold', category: 'armor', def: 30, spd: 10 },
  C2: { name: 'DOOMSTAFF', icon: '🔮', rarity: 'silver', category: 'relic', atk: 28, spd: 14 },
  D3: { name: 'BLOODTHORN', icon: '🌹', rarity: 'bronze', category: 'weapon', atk: 20, spd: 20 },
}

const EXTRA_PLAYER_5: Record<string, ItemCardData> = {
  E1: { name: 'GLOOMFANG', icon: '🦷', rarity: 'silver', category: 'weapon', atk: 31, spd: 16 },
  A4: { name: 'VEXWARD', icon: '🔱', rarity: 'bronze', category: 'armor', def: 18, spd: 10 },
}
const EXTRA_ENEMY_5: Record<string, ItemCardData> = {
  E1: { name: 'ASHBLADE', icon: '🗡️', rarity: 'silver', category: 'weapon', atk: 26, spd: 18 },
  D4: { name: 'HEXWARD', icon: '🌀', rarity: 'bronze', category: 'armor', def: 20, spd: 7 },
}

const EXTRA_PLAYER_6: Record<string, ItemCardData> = {
  ...EXTRA_PLAYER_5,
  F1: { name: 'SPECTERGUN', icon: '🔫', rarity: 'gold', category: 'weapon', atk: 36, spd: 20 },
  B5: { name: 'BLOODVEIL', icon: '🩸', rarity: 'silver', category: 'armor', def: 24, spd: 7 },
}
const EXTRA_ENEMY_6: Record<string, ItemCardData> = {
  ...EXTRA_ENEMY_5,
  F2: { name: 'DUSKBOLT', icon: '⚡', rarity: 'gold', category: 'weapon', atk: 40, spd: 28 },
  C5: { name: 'IRONHUSK', icon: '🪨', rarity: 'silver', category: 'armor', def: 28, spd: 5 },
}

const EXTRA_PLAYER_7: Record<string, ItemCardData> = {
  ...EXTRA_PLAYER_6,
  G1: { name: 'VOIDWARD', icon: '🌀', rarity: 'gold', category: 'relic', atk: 28, spd: 18 },
  E6: { name: 'ASHSWORD', icon: '🗡️', rarity: 'bronze', category: 'weapon', atk: 22, spd: 14 },
}
const EXTRA_ENEMY_7: Record<string, ItemCardData> = {
  ...EXTRA_ENEMY_6,
  G1: { name: 'NIGHTBANE', icon: '🌑', rarity: 'gold', category: 'weapon', atk: 44, spd: 30 },
  D6: { name: 'WRAITHVEIL', icon: '👁️', rarity: 'silver', category: 'armor', def: 26, spd: 9 },
}

function getGridItems(size: number) {
  const pBase = PLAYER_4
  const eBase = ENEMY_4
  if (size === 5) return { p: { ...pBase, ...EXTRA_PLAYER_5 }, e: { ...eBase, ...EXTRA_ENEMY_5 } }
  if (size === 6) return { p: { ...pBase, ...EXTRA_PLAYER_6 }, e: { ...eBase, ...EXTRA_ENEMY_6 } }
  if (size === 7) return { p: { ...pBase, ...EXTRA_PLAYER_7 }, e: { ...eBase, ...EXTRA_ENEMY_7 } }
  return { p: pBase, e: eBase }
}

const THREAT_UNITS = [
  { name: 'PHANTOMCLAW', icon: '👻' },
  { name: 'DOOMSTAFF', icon: '🔮' },
  { name: 'BLOODTHORN', icon: '🌹' },
  { name: 'CURSESHIELD', icon: '💀' },
]

const SYNERGY_EVENTS = [
  { name: 'VOID PACT', bonus: '+18% ATK to all Void units' },
  { name: 'SHADE STEP', bonus: 'next hit evades counter-strike' },
  { name: 'IRON SHELL', bonus: '+12 DEF stack applied' },
]

type LogTone = 'teal' | 'crimson' | 'gold' | 'muted'

const LOG_TONE_CLASS: Record<LogTone, string> = {
  teal: 'text-teal',
  crimson: 'text-crimson',
  gold: 'text-amber',
  muted: 'text-text',
}

const LOG_ENTRIES: { tone: LogTone; msg: string }[] = [
  { tone: 'teal', msg: 'VOIDBLADE → PHANTOMCLAW  -42 dmg' },
  { tone: 'crimson', msg: 'PHANTOMCLAW → VOIDBLADE  -50 dmg  CRIT' },
  { tone: 'teal', msg: 'SHADOWMANTLE absorbs 12 dmg' },
  { tone: 'gold', msg: 'NECROFLASK procs VOID PACT  +15% ATK' },
  { tone: 'teal', msg: 'GRIMHELM → BLOODTHORN  -45 dmg' },
  { tone: 'crimson', msg: 'DOOMSTAFF → NECROFLASK  -28 dmg' },
  { tone: 'muted', msg: 'Round 4 in progress...' },
  { tone: 'teal', msg: 'VOIDBLADE → PHANTOMCLAW  -38 dmg' },
]

type GridTint = 'teal' | 'crimson'

const GRID_TINT_VAR: Record<GridTint, string> = {
  teal: 'var(--ng-teal)',
  crimson: 'var(--ng-crimson)',
}

// ── sub-components ─────────────────────────────────────────────────────────

function MiniGrid({
  items,
  tint,
  flip = false,
  gridSize = 4,
}: {
  items: Record<string, ItemCardData>
  tint: GridTint
  flip?: boolean
  gridSize?: number
}) {
  const COLS = 'ABCDEFG'.slice(0, gridSize).split('')
  const ROWS = Array.from({ length: gridSize }, (_, i) => String(i + 1))
  const labelSz = gridSize >= 6 ? 7 : 9
  const rowLabelW = gridSize >= 6 ? 12 : 16
  const colLabel = `${rowLabelW}px repeat(${gridSize}, 1fr)`
  const maxWidth =
    gridSize === 7 ? '65%' : gridSize === 6 ? '75%' : gridSize === 5 ? '88%' : '100%'
  const compact = gridSize >= 6
  const gap = gridSize >= 6 ? 1 : 2
  const minEmptyH = gridSize >= 6 ? 18 : 28

  return (
    <div
      className={`mini-grid-zone${flip ? ' mini-grid-zone--flip' : ''}${compact ? ' mini-grid-zone--compact' : ''}`}
      style={{ '--grid-tint': GRID_TINT_VAR[tint] } as React.CSSProperties}
    >
      <div className="w-full transition-[max-width] duration-300" style={{ maxWidth }}>
        <div
          className="mini-grid-arc"
          style={{ width: Math.min(260, gridSize * 38), height: 90 }}
          aria-hidden="true"
        />

        <div className="grid mb-0.5" style={{ gridTemplateColumns: colLabel }}>
          <div />
          {COLS.map((c) => (
            <div key={c} className="mini-grid-label" style={{ fontSize: labelSz }}>
              {c}
            </div>
          ))}
        </div>

        {ROWS.map((row) => (
          <div
            key={row}
            className="grid mb-0.5"
            style={{ gridTemplateColumns: colLabel, gap, marginBottom: gap }}
          >
            <div className="mini-grid-row-label" style={{ fontSize: labelSz }}>
              {row}
            </div>
            {COLS.map((col) => {
              const item = items[`${col}${row}`]
              return (
                <div key={col} className="aspect-square min-w-0">
                  {item ? (
                    <ItemCard item={item} variant="grid" />
                  ) : (
                    <div className="mini-grid-empty" style={{ minHeight: minEmptyH }} />
                  )}
                </div>
              )
            })}
          </div>
        ))}
      </div>
    </div>
  )
}

function TimerRing({ pct }: { pct: number }) {
  const r = 28
  const cx = 36
  const cy = 36
  const circ = 2 * Math.PI * r
  const progressClass =
    pct > 0.3
      ? 'timer-ring__progress--ok'
      : pct > 0.1
        ? 'timer-ring__progress--warn'
        : 'timer-ring__progress--danger'

  return (
    <div className="timer-ring" aria-hidden="true">
      <svg width="72" height="72" className="timer-ring__svg">
        <circle className="timer-ring__track" cx={cx} cy={cy} r={r} />
        <circle
          className={`timer-ring__progress ${progressClass}`}
          cx={cx}
          cy={cy}
          r={r}
          strokeDasharray={`${circ * pct} ${circ}`}
          transform={`rotate(-90 ${cx} ${cy})`}
        />
      </svg>
    </div>
  )
}

interface DmgFloat {
  id: number
  value: number
  crit: boolean
  x: number
}
interface SynergyBanner {
  name: string
  bonus: string
  phase: 'in' | 'out'
}

// ── main component ─────────────────────────────────────────────────────────

interface Props {
  onEnd: () => void
  gridSize?: 4 | 5 | 6 | 7
  concept?: boolean
}

export default function BattleScreen({ onEnd, gridSize = 4, concept = false }: Props) {
  const { p: playerItems, e: enemyItems } = getGridItems(gridSize)

  const [floats, setFloats] = useState<DmgFloat[]>([])
  const [hits, setHits] = useState(0)
  const [crits, setCrits] = useState(0)
  const [kos, setKos] = useState(0)
  const [showBanner, setShowBanner] = useState(true)
  const [timerPct, setTimerPct] = useState(0.72)

  const [playerHP, setPlayerHP] = useState(89)
  const [enemyHP, setEnemyHP] = useState(72)
  const [threatDmg, setThreatDmg] = useState<number[]>([0, 0, 0, 0])
  const [synergyBanner, setSynergyBanner] = useState<SynergyBanner | null>(null)
  const synergyTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const isLosing = playerHP < 30 && enemyHP > enemyHP * 0.6

  useEffect(() => {
    const t = setTimeout(() => setShowBanner(false), 2800)
    return () => clearTimeout(t)
  }, [])

  useEffect(() => {
    const interval = setInterval(() => {
      const crit = Math.random() < 0.25
      const val = Math.floor(Math.random() * 50) + 10
      const id = Date.now() + Math.random()

      setFloats((prev) => [...prev.slice(-5), { id, value: val, crit, x: Math.random() * 50 - 25 }])
      setHits((h) => h + 1)
      if (crit) setCrits((c) => c + 1)
      if (Math.random() < 0.08) setKos((k) => k + 1)
      setTimerPct((p) => Math.max(0, p - 0.03))
      setPlayerHP((h) => Math.max(0, h - Math.floor(val * 0.15)))
      setEnemyHP((h) => Math.max(0, h - Math.floor(val * 0.1)))

      const unitIdx = Math.floor(Math.random() * 3)
      setThreatDmg((prev) => prev.map((d, i) => (i === unitIdx ? d + val : d)))

      if (Math.random() < 0.12 && !synergyBanner) {
        const ev = SYNERGY_EVENTS[Math.floor(Math.random() * SYNERGY_EVENTS.length)]
        setSynergyBanner({ ...ev, phase: 'in' })
        if (synergyTimer.current) clearTimeout(synergyTimer.current)
        synergyTimer.current = setTimeout(() => {
          setSynergyBanner((b) => (b ? { ...b, phase: 'out' } : null))
          setTimeout(() => setSynergyBanner(null), 400)
        }, 2200)
      }
    }, 900)

    return () => {
      clearInterval(interval)
      if (synergyTimer.current) clearTimeout(synergyTimer.current)
    }
  }, [synergyBanner])

  const topThreats = THREAT_UNITS.map((u, i) => ({ ...u, dmg: threatDmg[i] }))
    .sort((a, b) => b.dmg - a.dmg)
    .slice(0, 3)

  const footerStats: { label: string; value: number; tone: LogTone }[] = [
    { label: 'HITS', value: hits, tone: 'muted' },
    { label: 'CRITS', value: crits, tone: 'crimson' },
    { label: 'KOs', value: kos, tone: 'gold' },
  ]

  return (
    <div className="screen-canvas battle-canvas scroll-hide">
      {showBanner && (
        <div className="battle-intro-backdrop">
          <div className="battle-intro-card">
            <div className="text-display-label text-purple mb-2">
              ROUND 4 · BATTLE{concept ? ` · ${gridSize}×${gridSize} CONCEPT` : ''}
            </div>
            <div className="text-display-title text-teal text-glow-teal tracking-normal">
              SHADOWMANCER
            </div>
            <div className="font-mono text-sm text-text-muted my-1.5">VS</div>
            <div className="text-display-title text-crimson tracking-normal">VEXKRIN-9</div>
          </div>
        </div>
      )}

      {synergyBanner && (
        <div
          className={`battle-synergy-banner battle-synergy-banner--${synergyBanner.phase}`}
          role="status"
        >
          <span className="text-base shrink-0" aria-hidden="true">
            ⟁
          </span>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-1 text-display-label text-purple overflow-hidden">
              <span className="shrink-0">SYNERGY ACTIVATED</span>
              <span className="shrink-0">·</span>
              <span className="truncate min-w-0">{synergyBanner.name}</span>
            </div>
            <div className="text-body text-[10px] mt-px leading-tight break-words">
              {synergyBanner.bonus}
            </div>
          </div>
        </div>
      )}

      <header className="battle-hud-row">
        <HUDPill icon="❤️" value="6/8" variant="life" />
        <HUDPill icon="💰" value="7" variant="gold" />
        <TimerRing pct={timerPct} />
        <HUDPill icon="⟁" value="Round 4" variant="round" />
        <HUDPill icon="◈" value="3/10" variant="triumph" />
      </header>

      <div className="battle-threat-row">
        <span className="battle-threat-label">THREAT</span>
        {topThreats.map((u, i) => (
          <div
            key={u.name}
            className={`battle-threat-chip${i === 0 ? ' battle-threat-chip--primary' : ''}`}
          >
            <span className="text-[10px]" aria-hidden="true">
              {u.icon}
            </span>
            <span
              className={`font-mono text-[8px] font-bold ${i === 0 ? 'text-crimson' : 'text-text-faint'}`}
            >
              {u.dmg || '—'}
            </span>
          </div>
        ))}
      </div>

      <section className="battle-grid-section--enemy">
        <div className="battle-grid-header">
          <span className="battle-grid-name--enemy">VEXKRIN-9</span>
          <div className="divider-crimson" />
          <span className="battle-grid-hp--enemy">HP {enemyHP}/120</span>
        </div>
        <MiniGrid items={enemyItems} tint="crimson" flip gridSize={gridSize} />
      </section>

      <section className="battle-combat-zone" aria-hidden="true">
        <div className="battle-projectile-teal" />
        <div className="battle-projectile-crimson" />
        <div className="battle-muzzle-teal" />
        <span className="battle-vs-label">· · · VS · · ·</span>
      </section>

      <section className="battle-grid-section--player">
        <div className="battle-grid-header battle-grid-header--player">
          <span className="battle-grid-name--player">SHADOWMANCER</span>
          {isLosing && (
            <div className="battle-losing-badge">
              <span className="text-[9px]" aria-hidden="true">
                ⚠️
              </span>
              <span className="battle-losing-badge__label">LOSING</span>
            </div>
          )}
          <div className="divider-teal" />
          <span className="battle-grid-hp--player">HP {playerHP}/100</span>
        </div>
        <MiniGrid items={playerItems} tint="teal" gridSize={gridSize} />

        {floats.slice(-4).map((f) => (
          <div
            key={f.id}
            className={`damage-float absolute top-[25%] pointer-events-none z-30 whitespace-nowrap ${f.crit ? 'damage-float--crit' : 'damage-float--normal'}`}
            style={{ left: `${30 + f.x}%` }}
          >
            {f.crit ? '💥 ' : ''}-{f.value}
            {f.crit ? ' CRIT!' : ''}
          </div>
        ))}
      </section>

      <div className="battle-log-strip">
        <div className="battle-log-track">
          {[...Array(2)].map((_, i) => (
            <div key={i} className="flex gap-12">
              {LOG_ENTRIES.map((e, j) => (
                <span
                  key={`${i}-${j}`}
                  className={`battle-log-entry ${LOG_TONE_CLASS[e.tone]}`}
                >
                  {e.msg}
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>

      <footer className="battle-stats-footer">
        {footerStats.map((s) => (
          <div key={s.label} className="text-center">
            <div className={`battle-stat__value ${LOG_TONE_CLASS[s.tone]}`}>{s.value}</div>
            <div className="battle-stat__label">{s.label}</div>
          </div>
        ))}
        <button type="button" onClick={onEnd} className="battle-skip-btn">
          SKIP →
        </button>
      </footer>
    </div>
  )
}
