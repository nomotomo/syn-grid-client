import { useState, useEffect } from 'react'
import TabBar, { type TabId } from '../components/TabBar'

const PLAYERS = [
  { rank: 1, name: 'VEXKRIN-9', triumph: 10, isMe: false },
  { rank: 2, name: 'RIFTCALLER', triumph: 9, isMe: false },
  { rank: 3, name: 'NULLSHADE', triumph: 9, isMe: false },
  { rank: 4, name: 'THORNWEAVE', triumph: 8, isMe: false },
  { rank: 5, name: 'usr_2c9a1f', triumph: 7, isMe: false },
  { rank: 6, name: 'CRIMSONFANG', triumph: 6, isMe: false },
  { rank: 7, name: 'SHADOWMANCER', triumph: 3, isMe: true },
  { rank: 8, name: 'GALEHUNTER', triumph: 3, isMe: false },
  { rank: 9, name: 'usr_8b3d2e', triumph: 2, isMe: false },
  { rank: 10, name: 'DUSKBLADE', triumph: 2, isMe: false },
  { rank: 11, name: 'usr_4f1c7a', triumph: 1, isMe: false },
  { rank: 12, name: 'VOIDWATCH', triumph: 1, isMe: false },
]

const MEDAL_TIER: Record<number, 'gold' | 'silver' | 'bronze'> = {
  1: 'gold',
  2: 'silver',
  3: 'bronze',
}

// ── sub-components ─────────────────────────────────────────────────────────

function SkeletonRow() {
  return (
    <div className="rank-skeleton-row">
      <div className="shimmer w-6 h-3.5 rounded shrink-0" />
      <div className="shimmer flex-1 h-3.5 rounded" />
      <div className="shimmer w-10 h-3.5 rounded shrink-0" />
    </div>
  )
}

function MedalBadge({ rank }: { rank: number }) {
  const tier = MEDAL_TIER[rank]
  const player = PLAYERS[rank - 1]

  return (
    <div className={`rank-medal rank-medal--${tier}`}>
      <div className={`rank-medal__circle rank-medal__circle--${tier}`}>
        <span className="rank-medal__rank">#{rank}</span>
        {rank === 1 && (
          <span className="text-[10px] mt-0.5" aria-hidden="true">
            👑
          </span>
        )}
      </div>
      <div className="rank-medal__name">{player.name}</div>
      <div className="rank-medal__triumph">T {player.triumph}/10</div>
    </div>
  )
}

function LeaderboardTab({ loading }: { loading: boolean }) {
  return (
    <div className="leaderboard-scroll scroll-neon">
      {!loading && (
        <div className="medallion-row">
          <MedalBadge rank={2} />
          <MedalBadge rank={1} />
          <MedalBadge rank={3} />
        </div>
      )}

      <div className="rank-list">
        {loading
          ? [...Array(8)].map((_, i) => <SkeletonRow key={i} />)
          : PLAYERS.slice(3).map((p) => {
              const isAnon = p.name.startsWith('usr_')
              return (
                <div key={p.rank} className={`rank-row${p.isMe ? ' rank-row--me' : ''}`}>
                  <div className="rank-row__position">#{p.rank}</div>
                  <div
                    className={`rank-row__name text-[11px] ${isAnon ? 'rank-row__name--mono' : 'rank-row__name--display'}`}
                  >
                    {p.name}
                    {p.isMe && <span className="rank-row__you">YOU</span>}
                  </div>
                  <div className="rank-row__triumph">
                    <span className="text-[8px] mr-0.5">T</span>
                    {p.triumph}/10
                  </div>
                </div>
              )
            })}
      </div>
    </div>
  )
}

function SeasonTab() {
  return (
    <div className="season-tab-scroll scroll-neon">
      <div className="surface-season-banner p-4 px-5 mb-3">
        <div className="season-banner__title tracking-widest mb-1">SEASON 4 · ARCANE RIFT</div>
        <div className="text-mono-stat text-base text-amber tracking-wide mb-2.5">
          ENDS IN 12D 04H 30M
        </div>
        <div className="flex gap-3">
          <div className="bg-bg rounded-[10px] px-3.5 py-2">
            <div className="text-mono-caption text-[8px] tracking-normal mb-0.5">YOUR RANK</div>
            <div className="text-mono-stat text-teal">#7</div>
          </div>
          <div className="bg-bg rounded-[10px] px-3.5 py-2">
            <div className="text-mono-caption text-[8px] tracking-normal mb-0.5">TRIUMPH</div>
            <div className="text-mono-stat text-amber">3/10</div>
          </div>
        </div>
      </div>

      <div className="text-display-label text-text-faint mb-2">REWARD BRACKETS</div>
      <div className="surface-panel p-5 flex flex-col items-center gap-2">
        <span className="text-[22px] opacity-50 grayscale" aria-hidden="true">
          🔒
        </span>
        <div className="text-display-label text-text-faint tracking-widest">COMING SOON</div>
        <p className="text-mono-caption text-center leading-relaxed tracking-normal">
          Reward tiers will be revealed
          <br />
          once Season 4 brackets are finalized.
        </p>
      </div>
      <div className="h-4" />
    </div>
  )
}

// ── main screen ────────────────────────────────────────────────────────────

export default function RanksScreen({ onTabPress }: { onTabPress: (id: TabId) => void }) {
  const [innerTab, setInnerTab] = useState<'leaderboard' | 'season'>('leaderboard')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const t = setTimeout(() => setLoading(false), 1400)
    return () => clearTimeout(t)
  }, [])

  return (
    <div className="screen-canvas ranks-canvas">
      <header className="ranks-header">
        <p className="text-bracket-subtitle mb-3.5 m-0">NEON GRIMOIRE · SYN-GRID</p>
        <h1 className="text-display-title text-teal m-0 mb-3.5">LEADERBOARD</h1>

        <div className="inner-tab-bar" role="tablist" aria-label="Ranks views">
          {(['leaderboard', 'season'] as const).map((tab) => {
            const isActive = innerTab === tab
            return (
              <button
                key={tab}
                type="button"
                role="tab"
                aria-selected={isActive}
                onClick={() => setInnerTab(tab)}
                className={`inner-tab-btn ${
                  isActive
                    ? tab === 'leaderboard'
                      ? 'inner-tab-btn--active-leaderboard'
                      : 'inner-tab-btn--active-season'
                    : ''
                }`}
              >
                {tab === 'leaderboard' ? '◈ LEADERBOARD' : '⟁ SEASON'}
              </button>
            )
          })}
        </div>
      </header>

      {innerTab === 'leaderboard' ? (
        <LeaderboardTab loading={loading} />
      ) : (
        <SeasonTab />
      )}

      <div className="relative z-[var(--z-tab-bar)]">
        <TabBar active="ranks" onTabPress={onTabPress} />
      </div>
    </div>
  )
}
