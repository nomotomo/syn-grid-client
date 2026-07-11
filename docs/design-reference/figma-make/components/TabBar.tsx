export type TabId = 'home' | 'ranks' | 'season' | 'profile'

const TABS: { id: TabId; label: string; icon: string }[] = [
  { id: 'home', label: 'HOME', icon: '⬡' },
  { id: 'ranks', label: 'RANKS', icon: '◈' },
  { id: 'season', label: 'SEASON', icon: '⟁' },
  { id: 'profile', label: 'PROFILE', icon: '○' },
]

interface TabBarProps {
  active?: TabId
  onTabPress?: (id: TabId) => void
}

export default function TabBar({ active = 'home', onTabPress }: TabBarProps) {
  return (
    <nav className="tab-bar" aria-label="Main navigation">
      {TABS.map((tab) => {
        const isActive = tab.id === active
        return (
          <button
            key={tab.id}
            type="button"
            onClick={() => onTabPress?.(tab.id)}
            className={`tab-bar__btn ${isActive ? 'tab-bar__btn--active' : 'tab-bar__btn--inactive'}`}
            aria-current={isActive ? 'page' : undefined}
          >
            <span className="tab-bar__icon" aria-hidden="true">
              {tab.icon}
            </span>
            <span className="tab-bar__label">{tab.label}</span>
            {isActive && <span className="tab-bar__indicator" aria-hidden="true" />}
          </button>
        )
      })}
    </nav>
  )
}
