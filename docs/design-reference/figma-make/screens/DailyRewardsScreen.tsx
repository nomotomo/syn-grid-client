interface Props {
  onBack: () => void
}

const MISSIONS = [
  { label: 'Win 1 round', reward: '50g', rewardType: 'gold' as const, progress: '0/1' },
  {
    label: 'Play 5 units of Void Pact',
    reward: '+1 Triumph',
    rewardType: 'triumph' as const,
    progress: '2/5',
  },
  {
    label: 'Upgrade an item to Gold tier',
    reward: '20g',
    rewardType: 'gold' as const,
    progress: '1/1',
    isComplete: true,
  },
]

export default function DailyRewardsScreen({ onBack }: Props) {
  return (
    <div className="screen-canvas daily-canvas">
      <header className="daily-header">
        <button type="button" onClick={onBack} className="daily-back-btn" aria-label="Go back">
          ←
        </button>
        <h1 className="flex-1 text-center text-display-title text-teal m-0">DAILY REWARDS</h1>
        <div className="w-5" aria-hidden="true" />
      </header>

      <div className="daily-concept-strip">
        <p className="text-mono-caption text-amber text-center tracking-normal m-0">
          CONCEPT PREVIEW
        </p>
      </div>

      <div className="daily-body scroll-hide">
        <section>
          <h2 className="text-display-label text-text text-center mb-4 m-0">LOGIN STREAK</h2>

          <div className="grid grid-cols-4 gap-2 mb-2">
            {[1, 2, 3, 4].map((day) => (
              <RewardDay
                key={day}
                day={day}
                state={day < 3 ? 'claimed' : day === 3 ? 'current' : 'future'}
              />
            ))}
          </div>
          <div className="grid grid-cols-3 gap-2">
            {[5, 6, 7].map((day) => (
              <RewardDay key={day} day={day} state="future" isGrand={day === 7} />
            ))}
          </div>

          <div className="mt-6 flex justify-center">
            <button
              type="button"
              className="aurora-btn font-display font-bold uppercase tracking-wider text-xl px-12 py-4 cursor-pointer"
            >
              🎁 CLAIM DAY 3
            </button>
          </div>
        </section>

        <div className="market-divider" />

        <section>
          <h2 className="text-display-label text-text text-center mb-4 m-0">DAILY MISSIONS</h2>
          <div className="flex flex-col gap-3">
            {MISSIONS.map((mission) => (
              <MissionRow key={mission.label} {...mission} />
            ))}
          </div>
        </section>
      </div>
    </div>
  )
}

function RewardDay({
  day,
  state,
  isGrand,
}: {
  day: number
  state: 'claimed' | 'current' | 'future'
  isGrand?: boolean
}) {
  const isClaimed = state === 'claimed'

  return (
    <div
      className={[
        'reward-day surface-quick-tile',
        `reward-day--${state}`,
        isGrand ? 'reward-day--grand' : '',
      ]
        .filter(Boolean)
        .join(' ')}
    >
      {isClaimed && (
        <div className="reward-day__claimed-overlay" aria-hidden="true">
          <span className="text-2xl drop-shadow-md">✔️</span>
        </div>
      )}
      <div className="reward-day__label">DAY {day}</div>
      <div className="reward-day__icon" aria-hidden="true">
        {isGrand ? '🏆' : '🎁'}
      </div>
      {isGrand && <div className="reward-day__grand-label">GRAND REWARD</div>}
    </div>
  )
}

function MissionRow({
  label,
  reward,
  rewardType,
  progress,
  isComplete,
}: {
  label: string
  reward: string
  rewardType: 'gold' | 'triumph'
  progress: string
  isComplete?: boolean
}) {
  return (
    <div className={`mission-row${isComplete ? ' mission-row--complete' : ''}`}>
      <div className="flex-1">
        <div className="mission-row__label">{label}</div>
        <span
          className={`mission-reward-chip mission-reward-chip--${rewardType}${
            rewardType === 'gold' ? ' glow-amber-sm' : ' glow-purple-sm'
          }`}
        >
          {rewardType === 'gold' ? '💰 ' : '◈ '}
          {reward}
        </span>
      </div>
      <div className="flex flex-col items-end gap-1">
        <div className="mission-row__progress">{progress}</div>
        {isComplete && (
          <span className="text-sm" aria-hidden="true">
            ✔️
          </span>
        )}
      </div>
    </div>
  )
}
