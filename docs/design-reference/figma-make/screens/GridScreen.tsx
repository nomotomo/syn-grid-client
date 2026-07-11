import HUDPill from '../components/HUDPill'
import ItemCard, { type ItemCardData } from '../components/ItemCard'

// ── item pools ──────────────────────────────────────────────────────────────

const BASE_PLACED: Record<string, ItemCardData> = {
  A1: { name: 'VOIDBLADE', icon: '⚔️', rarity: 'epic', category: 'weapon', atk: 42, spd: 18, synergy: true },
  B1: { name: 'SHADOWMANTLE', icon: '🛡️', rarity: 'gold', category: 'armor', def: 35, spd: 12, synergy: true },
  C2: { name: 'NECROFLASK', icon: '🧪', rarity: 'silver', category: 'potion', atk: 15, def: 20 },
  D3: { name: 'RUNESPIKE', icon: '💠', rarity: 'bronze', category: 'weapon', atk: 28, spd: 22 },
  B3: { name: 'GRIMHELM', icon: '⛓️', rarity: 'gold', category: 'armor', def: 45, spd: 8 },
}

const EXTRA_5: Record<string, ItemCardData> = {
  E1: { name: 'GLOOMFANG', icon: '🦷', rarity: 'silver', category: 'weapon', atk: 31, spd: 16 },
  A4: { name: 'VEXWARD', icon: '🔱', rarity: 'bronze', category: 'armor', def: 18, spd: 10 },
  E3: { name: 'RUNESHOT', icon: '🏹', rarity: 'gold', category: 'weapon', atk: 38, spd: 26 },
  D5: { name: 'DARKSPELL', icon: '🌑', rarity: 'epic', category: 'relic', atk: 48, spd: 32 },
}

const EXTRA_6: Record<string, ItemCardData> = {
  ...EXTRA_5,
  F1: { name: 'SPECTERGUN', icon: '🔫', rarity: 'gold', category: 'weapon', atk: 36, spd: 20 },
  B5: { name: 'BLOODVEIL', icon: '🩸', rarity: 'silver', category: 'armor', def: 24, spd: 7 },
  F4: { name: 'NULLSHIELD', icon: '🔵', rarity: 'bronze', category: 'armor', def: 22 },
  A6: { name: 'HEXBOLT', icon: '⚡', rarity: 'epic', category: 'relic', atk: 52, spd: 36 },
}

const EXTRA_7: Record<string, ItemCardData> = {
  ...EXTRA_6,
  G1: { name: 'VOIDWARD', icon: '🌀', rarity: 'gold', category: 'relic', atk: 28, spd: 18 },
  E6: { name: 'ASHSWORD', icon: '🗡️', rarity: 'bronze', category: 'weapon', atk: 22, spd: 14 },
  G3: { name: 'DARKMATTER', icon: '🌑', rarity: 'epic', category: 'relic', atk: 60, spd: 40 },
  D7: { name: 'RUNEBREAK', icon: '💥', rarity: 'silver', category: 'weapon', atk: 34, spd: 19 },
  F7: { name: 'WRAITHBOLT', icon: '👁️', rarity: 'gold', category: 'weapon', atk: 40, spd: 24 },
}

function getPlaced(size: number): Record<string, ItemCardData> {
  if (size === 5) return { ...BASE_PLACED, ...EXTRA_5 }
  if (size === 6) return { ...BASE_PLACED, ...EXTRA_6 }
  if (size === 7) return { ...BASE_PLACED, ...EXTRA_7 }
  return BASE_PLACED
}

const SYNERGY_PAIRS = new Set(['A1|B1'])
function sharesEdge(c1: string, r1: string, c2: string, r2: string) {
  return SYNERGY_PAIRS.has([`${c1}${r1}`, `${c2}${r2}`].sort().join('|'))
}

const BENCH_ITEMS: ItemCardData[] = [
  { name: 'THORNMAIL', icon: '🌵', rarity: 'silver', category: 'armor', def: 22 },
  { name: 'DARKPULSE', icon: '🌑', rarity: 'bronze', category: 'weapon', atk: 18, spd: 15 },
  { name: 'LIFETONIC', icon: '💊', rarity: 'gold', category: 'potion', def: 30, atk: 8 },
  { name: 'ASHMANTLE', icon: '🪨', rarity: 'silver', category: 'armor', def: 26, spd: 5 },
  { name: 'SPECTERLASH', icon: '👁️', rarity: 'epic', category: 'weapon', atk: 50, spd: 28 },
]

const SYNERGY_CHIPS = [
  { name: 'Void Pact', count: '2/3', active: true },
  { name: 'Iron Shell', count: '1/2', active: false },
  { name: 'Shade Step', count: '2/2', active: true },
] as const

// ── main component ──────────────────────────────────────────────────────────

interface Props {
  gridSize?: 4 | 5 | 6 | 7
  concept?: boolean
  onFight: (size: 4 | 5 | 6 | 7) => void
  onOpenMarket: () => void
}

export default function GridScreen({ gridSize = 4, concept = false, onFight, onOpenMarket }: Props) {
  const COLS = 'ABCDEFG'.slice(0, gridSize).split('')
  const ROWS = Array.from({ length: gridSize }, (_, i) => String(i + 1))
  const placed = getPlaced(gridSize)
  const labelSize = gridSize >= 6 ? 8 : 10
  const colTemplate = `18px repeat(${gridSize}, 1fr)`

  let activeSynergies = 0
  ROWS.forEach((row) => {
    COLS.forEach((col, ci) => {
      const rightCol = COLS[ci + 1]
      if (rightCol && sharesEdge(col, row, rightCol, row)) {
        activeSynergies++
      }
    })
  })

  return (
    <div className="screen-canvas prep-canvas">
      <header className="battle-hud-row">
        <HUDPill icon="❤️" value="6/8" variant="life" />
        <HUDPill icon="💰" value="7" variant="gold" />
        <HUDPill icon="⟁" value="Round 4" variant="round" />
        <HUDPill icon="◈" value="3/10" variant="triumph" />
      </header>

      <div className="prep-phase-row">
        {concept ? (
          <span className="prep-badge prep-badge--concept">
            {gridSize}×{gridSize} GRID — CONCEPT
          </span>
        ) : (
          <span className="prep-badge">PREP PHASE</span>
        )}
        <div className="divider-purple" />
        <button type="button" onClick={onOpenMarket} className="market-open-btn">
          <span className="text-xs" aria-hidden="true">
            🛒
          </span>
          <span className="market-open-btn__label">MARKET</span>
          <span className="market-open-btn__count">5 NEW</span>
        </button>
      </div>

      <div className="synergy-chip-row scroll-hide">
        {SYNERGY_CHIPS.map((s) => (
          <div
            key={s.name}
            className={`synergy-chip ${s.active ? 'synergy-chip--active' : 'synergy-chip--inactive'}`}
          >
            <span className="synergy-chip__dot" aria-hidden="true" />
            <span className="synergy-chip__name">{s.name}</span>
            <span className="synergy-chip__count">{s.count}</span>
          </div>
        ))}
      </div>

      <section className="tactical-grid-panel">
        <div
          className="grid mb-0.5 shrink-0"
          style={{ gridTemplateColumns: colTemplate, gap: 3 }}
        >
          <div />
          {COLS.map((c) => (
            <div key={c} className="tactical-grid-label" style={{ fontSize: labelSize }}>
              {c}
            </div>
          ))}
        </div>

        <div className="tactical-grid-scroll scroll-hide">
          <div className="tactical-grid-rows">
            {ROWS.map((row) => (
              <div
                key={row}
                className="tactical-grid-row"
                style={{ gridTemplateColumns: colTemplate }}
              >
                <div
                  className="tactical-grid-label flex items-center justify-center"
                  style={{ fontSize: labelSize }}
                >
                  {row}
                </div>
                {COLS.map((col, ci) => {
                  const key = `${col}${row}`
                  const item = placed[key]
                  const rightCol = COLS[ci + 1]
                  const synergyRight = rightCol ? sharesEdge(col, row, rightCol, row) : false
                  return (
                    <div key={key} className="relative min-w-0 min-h-0">
                      {item ? (
                        <ItemCard item={item} variant="grid" />
                      ) : (
                        <div className="grid-socket-empty">+</div>
                      )}
                      {synergyRight && (
                        <div className="synergy-connector synergy-edge" aria-hidden="true" />
                      )}
                    </div>
                  )
                })}
              </div>
            ))}
          </div>
        </div>
      </section>

      <footer className="prep-bottom-panel">
        <div>
          <div className="bench-header">
            <span className="bench-header__label">BENCH</span>
            <div className="bench-header__rule" />
          </div>
          <div className="bench-grid scroll-hide">
            {BENCH_ITEMS.map((item) => (
              <ItemCard key={item.name} item={item} variant="bench" />
            ))}
            {[...Array(15 - BENCH_ITEMS.length)].map((_, i) => (
              <div key={i} className="bench-slot-empty">
                +
              </div>
            ))}
          </div>
        </div>

        <div className="prep-fight-row">
          <button type="button" className="auto-toggle-btn surface-quick-tile">
            <span className="text-sm" aria-hidden="true">
              ⚡
            </span>
            <span className="text-display-label text-[6.5px] text-text mt-0.5">AUTO</span>
          </button>

          <div className="flex flex-col items-center">
            <button
              type="button"
              onClick={() => onFight(gridSize)}
              className="aurora-btn font-display font-bold uppercase tracking-wider text-xl px-12 py-4 cursor-pointer"
            >
              ⚔️ START MATCH
            </button>
            <p className="prep-synergy-hint">{activeSynergies} synergy link(s) active</p>
          </div>
        </div>
      </footer>
    </div>
  )
}
