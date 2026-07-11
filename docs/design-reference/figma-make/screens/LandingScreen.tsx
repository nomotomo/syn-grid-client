import RuneField from '../components/RuneField'
import TabBar, { type TabId } from '../components/TabBar'
import ProfileModal from '../components/ProfileModal'
import { useState } from 'react'

interface Props {
  onPlay: () => void
  onTabPress: (id: TabId) => void
  onOpenDaily: () => void
}

const TICKER_MESSAGES = [
  '⚡ Patch 2.4 live — Balance changes to Lich tier',
  '🎁 Daily reward available',
  '◈ Ranked queue open',
  '⟁ Season 4 championship begins Friday',
] as const

export default function LandingScreen({ onPlay, onTabPress, onOpenDaily }: Props) {
  const [profileOpen, setProfileOpen] = useState(false)

  const handleTab = (id: TabId) => {
    if (id === 'profile') {
      setProfileOpen(true)
      return
    }
    onTabPress(id)
  }

  return (
    <div className="screen-canvas flex flex-col">
      <RuneField />
      <div className="scan-line-beam" aria-hidden="true" />

      {/* Top status bar */}
      <header className="status-bar">
        <span className="text-mono-caption">SYN-GRID v2.4.1</span>
        <div className="status-bar__actions">
          <span className="text-mono-caption status-online">● ONLINE</span>
          <span className="text-mono-caption">23:41</span>
          <button
            type="button"
            className="avatar-gradient"
            onClick={() => setProfileOpen(true)}
            aria-label="Open profile"
          >
            S
          </button>
          <button
            type="button"
            className="text-text-muted text-base leading-none"
            aria-label="Settings"
          >
            ⚙️
          </button>
        </div>
      </header>

      {/* Logo + CTA zone */}
      <main className="landing-stack">
        <span className="badge-genre mb-5">Dark-Fantasy · Auto-Battler</span>

        <div className="text-center leading-[0.9] mb-2">
          <h1 className="text-display-hero crt-logo text-glow-teal text-teal m-0">NEON</h1>
          <h1
            className="text-display-hero crt-logo text-glow-white text-white m-0"
            style={{ animationDelay: '0.3s' }}
          >
            GRIMOIRE
          </h1>
        </div>

        <p className="text-bracket-subtitle mb-2">[ SYN-GRID ]</p>

        <div className="wordmark-divider">
          <div className="divider-neon" />
          <span className="text-teal text-base" aria-hidden="true">
            ⬡
          </span>
          <div className="divider-neon-reverse" />
        </div>

        <button
          type="button"
          className="season-banner surface-season-banner"
          onClick={() => onTabPress('season')}
        >
          <span className="text-[22px] leading-none" aria-hidden="true">
            ⟁
          </span>
          <div className="flex-1 min-w-0">
            <div className="season-banner__title">SEASON 4 · ARCANE RIFT</div>
            <div className="season-banner__teaser">
              New units · New synergies · New dread
            </div>
          </div>
          <div className="season-banner__days">12d left</div>
        </button>

        <button
          type="button"
          onClick={onPlay}
          className="aurora-btn font-display font-bold uppercase tracking-wider text-xl px-12 py-4 cursor-pointer"
        >
          ⚡ PLAY
        </button>

        <div className="quick-actions-row">
          <button
            type="button"
            onClick={onOpenDaily}
            className="quick-action-tile surface-quick-tile"
          >
            <span className="text-xl" aria-hidden="true">
              🎁
            </span>
            <span className="quick-action-tile__label">Daily</span>
            <span className="notification-dot" aria-hidden="true" />
          </button>

          <button type="button" className="quick-action-tile surface-quick-tile">
            <span className="text-xl" aria-hidden="true">
              📖
            </span>
            <span className="quick-action-tile__label">Codex</span>
          </button>
        </div>

        <div className="ticker-strip">
          <div className="ticker-strip__track">
            {[...Array(2)].map((_, i) => (
              <div key={i} className="flex gap-[60px]">
                {TICKER_MESSAGES.map((msg) => (
                  <span key={`${i}-${msg}`} className="ticker-strip__message">
                    {msg}
                  </span>
                ))}
              </div>
            ))}
          </div>
        </div>
      </main>

      <div className="relative z-[var(--z-tab-bar)]">
        <TabBar active="home" onTabPress={handleTab} />
      </div>

      {profileOpen && <ProfileModal onClose={() => setProfileOpen(false)} />}
    </div>
  )
}
