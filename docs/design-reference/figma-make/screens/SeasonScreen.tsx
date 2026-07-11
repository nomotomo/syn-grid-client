import RuneField from '../components/RuneField'

export default function SeasonScreen({ onBack }: { onBack: () => void }) {
  return (
    <div className="screen-canvas season-canvas">
      <RuneField />
      <div className="season-vignette" aria-hidden="true" />

      <div className="season-content">
        <header className="season-top-bar">
          <button type="button" onClick={onBack} className="season-back-btn">
            ← BACK
          </button>
          <span className="season-epoch">SEASON 4</span>
        </header>

        <div className="season-title-block">
          <h1 className="text-display-title text-text m-0 leading-none">SEASON HUB</h1>
          <p className="season-subtitle-glow m-0">ARCANE RIFT</p>

          <div className="season-divider">
            <div className="divider-purple-full" />
            <span className="text-purple text-sm" aria-hidden="true">
              ⟁
            </span>
            <div className="divider-purple-full-reverse" />
          </div>
        </div>

        <div className="season-scroll scroll-neon">
          <section className="surface-season-banner season-card season-card--timer p-[18px] px-5 mb-3">
            <div className="season-card__label">
              <span aria-hidden="true">⏳</span>
              <span>SEASON TIMER</span>
            </div>
            <div className="season-timer-value">ENDS IN 12D 04H 30M</div>
            <div className="mt-2.5">
              <div className="season-progress-track">
                <div className="season-progress-fill" style={{ width: '72%' }} />
              </div>
              <div className="season-progress-labels">
                <span>SEASON START</span>
                <span>72% ELAPSED</span>
                <span>SEASON END</span>
              </div>
            </div>
          </section>

          <section className="season-card">
            <div className="season-triumph-header">
              <span aria-hidden="true">◈</span>
              <span className="season-card__label mb-0">TRIUMPH PROGRESS</span>
              <span className="season-triumph-count">3/10</span>
            </div>

            <div className="season-triumph-orbs">
              {[...Array(10)].map((_, i) =>
                i < 3 ? (
                  <span
                    key={i}
                    className="pill-capsule pill-triumph glow-purple-sm season-milestone-pill"
                    aria-hidden="true"
                  >
                    <span className="pill-capsule__value text-[8px]">{i + 1}</span>
                  </span>
                ) : (
                  <span
                    key={i}
                    className="chip chip-inactive season-milestone-pill text-[8px] px-2 py-1"
                    aria-hidden="true"
                  >
                    ○
                  </span>
                ),
              )}
            </div>

            <p className="text-body-muted text-[11px] mt-2.5 mb-0">
              7 more triumphs to complete Season 4.
            </p>
          </section>

          <section className="season-rewards-placeholder">
            <span className="text-[28px] opacity-50 grayscale" aria-hidden="true">
              🏆
            </span>
            <div className="text-display-label text-text-faint tracking-widest text-center">
              REWARDS LADDER
            </div>
            <div className="text-body text-text-faint tracking-wide">COMING SOON</div>
            <p className="text-mono-caption text-center max-w-[200px] leading-relaxed tracking-normal m-0">
              Seasonal reward tiers will be revealed here once finalized.
            </p>
          </section>

          <div className="h-2" />
        </div>

        <footer className="season-footer">
          <button
            type="button"
            onClick={onBack}
            className="aurora-btn w-full font-display font-bold uppercase tracking-wider text-xl px-12 py-4 cursor-pointer"
          >
            ← BACK TO MAIN MENU
          </button>
        </footer>
      </div>
    </div>
  )
}
