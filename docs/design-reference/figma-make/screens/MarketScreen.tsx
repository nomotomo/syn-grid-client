import ItemCard, { type ItemCardData } from '../components/ItemCard'

const SHOP_ITEMS: ItemCardData[] = [
  { name: 'BANSHEE ROD', icon: '🪄', rarity: 'gold', category: 'weapon', atk: 38, spd: 14, cost: 3 },
  { name: 'IRONWARD', icon: '🔰', rarity: 'silver', category: 'armor', def: 28, spd: 6, cost: 2 },
  { name: 'BLINKSTONE', icon: '💎', rarity: 'epic', category: 'relic', atk: 22, spd: 40, cost: 5 },
  { name: 'CURSED ELIXIR', icon: '☠️', rarity: 'bronze', category: 'potion', atk: 10, def: 10, cost: 1 },
  { name: 'WRAITHCLOAK', icon: '🌫️', rarity: 'gold', category: 'armor', def: 32, spd: 18, cost: 4 },
]

const BENCH_ITEMS: ItemCardData[] = [
  { name: 'THORNMAIL', icon: '🌵', rarity: 'silver', category: 'armor', def: 22 },
  { name: 'DARKPULSE', icon: '🌑', rarity: 'bronze', category: 'weapon', atk: 18, spd: 15 },
  { name: 'LIFETONIC', icon: '💊', rarity: 'gold', category: 'potion', def: 30, atk: 8 },
  { name: 'ASHMANTLE', icon: '🪨', rarity: 'silver', category: 'armor', def: 26, spd: 5 },
  { name: 'SPECTERLASH', icon: '👁️', rarity: 'epic', category: 'weapon', atk: 50, spd: 28 },
]

export default function MarketScreen({ onBack }: { onBack: () => void }) {
  return (
    <div className="screen-canvas market-canvas">
      <header className="market-header">
        <h1 className="text-display-title text-teal m-0">MARKET</h1>
        <div className="market-gold-pill">
          <span aria-hidden="true">💰</span>
          <span className="text-mono-stat">7g</span>
        </div>
      </header>

      <div className="market-body scroll-hide">
        <section className="market-section">
          <div className="market-section-header">
            <h2 className="text-display-label text-teal m-0">BUY / REQUISITION</h2>
            <button type="button" className="market-reroll-btn">
              🎲 REROLL <span className="text-text-faint">2g</span>
            </button>
          </div>
          <div className="market-shop-row scroll-hide">
            {SHOP_ITEMS.map((item) => (
              <ItemCard key={item.name} item={item} variant="shop" />
            ))}
          </div>
        </section>

        <div className="market-divider" />

        <section>
          <h2 className="text-display-label text-crimson mb-4">SELL FROM BENCH</h2>
          <div className="grid grid-cols-3 gap-4">
            {BENCH_ITEMS.map((item) => (
              <button key={item.name} type="button" className="sell-tile">
                <ItemCard item={item} variant="bench" />
                <span className="sell-tile__price">
                  SELL +{item.cost ? Math.floor(item.cost / 2) || 1 : 2}g
                </span>
              </button>
            ))}
          </div>
        </section>
      </div>

      <footer className="market-footer">
        <button
          type="button"
          onClick={onBack}
          className="aurora-btn w-full font-display font-bold uppercase tracking-wider text-xl px-12 py-4 cursor-pointer"
        >
          ← BACK TO GRID
        </button>
      </footer>
    </div>
  )
}
