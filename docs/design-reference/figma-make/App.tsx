import { useState } from 'react'
import LandingScreen from './screens/LandingScreen'
import GridScreen from './screens/GridScreen'
import BattleScreen from './screens/BattleScreen'
import ResultScreen from './screens/ResultScreen'
import RanksScreen from './screens/RanksScreen'
import SeasonScreen from './screens/SeasonScreen'
import DailyRewardsScreen from './screens/DailyRewardsScreen'
import BattleReportScreen from './screens/BattleReportScreen'
import MarketScreen from './screens/MarketScreen'
import type { TabId } from './components/TabBar'

type Screen =
  | 'landing'
  | 'grid'
  | 'grid5'
  | 'grid6'
  | 'grid7'
  | 'market'
  | 'battle'
  | 'result'
  | 'result-defeat'
  | 'report'
  | 'ranks'
  | 'season'
  | 'daily'

const LABELS: [Screen, string][] = [
  ['landing', '① MAIN MENU'],
  ['grid', '② GRID 4×4'],
  ['grid5', '② GRID 5×5 CONCEPT'],
  ['grid6', '② GRID 6×6 CONCEPT'],
  ['grid7', '② GRID 7×7 CONCEPT'],
  ['market', '②b MARKET'],
  ['battle', '③ BATTLE'],
  ['result', '④a ROUND RESULT — VICTORY'],
  ['result-defeat', '④b ROUND RESULT — DEFEAT'],
  ['report', '④c BATTLE REPORT FLOW'],
  ['ranks', '⑤ LEADERBOARD'],
  ['season', '⑥ SEASON HUB'],
  ['daily', '⑦ DAILY REWARDS CONCEPT'],
]

const GRID_SIZE: Record<string, 4 | 5 | 6 | 7> = {
  grid: 4,
  grid5: 5,
  grid6: 6,
  grid7: 7,
}

export default function App() {
  const [screen, setScreen] = useState<Screen>('landing')
  const [battleGridSize, setBattleGridSize] = useState<4 | 5 | 6 | 7>(4)
  const [lastGridScreen, setLastGridScreen] = useState<Screen>('grid')

  const handleTabPress = (id: TabId) => {
    if (id === 'home') setScreen('landing')
    if (id === 'ranks') setScreen('ranks')
    if (id === 'season') setScreen('season')
  }

  const handleFight = (size: 4 | 5 | 6 | 7) => {
    setBattleGridSize(size)
    setScreen('battle')
  }

  return (
    <div className="dev-shell">
      {/* Dev-only screen picker */}
      <nav className="dev-nav" aria-label="Screen preview navigation">
        {LABELS.map(([s, label]) => (
          <button
            key={s}
            type="button"
            onClick={() => {
              setScreen(s)
              if (s.startsWith('grid')) setLastGridScreen(s)
            }}
            className={`dev-nav__btn${screen === s ? ' dev-nav__btn--active' : ''}`}
          >
            {label}
          </button>
        ))}
        <p className="dev-hint">
          ⑦ PROFILE — tap ○ PROFILE tab or the &quot;S&quot; avatar on Main Menu
        </p>
      </nav>

      {/* Mobile device frame */}
      <div className="mobile-frame shrink-0">
        <div className="device-notch" aria-hidden="true" />
        {screen === 'landing' && (
          <LandingScreen
            onPlay={() => {
              setLastGridScreen('grid')
              setScreen('grid')
            }}
            onTabPress={handleTabPress}
            onOpenDaily={() => setScreen('daily')}
          />
        )}
        {(screen === 'grid' ||
          screen === 'grid5' ||
          screen === 'grid6' ||
          screen === 'grid7') && (
          <GridScreen
            gridSize={GRID_SIZE[screen]}
            concept={screen !== 'grid'}
            onFight={handleFight}
            onOpenMarket={() => {
              setLastGridScreen(screen)
              setScreen('market')
            }}
          />
        )}
        {screen === 'market' && <MarketScreen onBack={() => setScreen(lastGridScreen)} />}
        {screen === 'battle' && (
          <BattleScreen
            onEnd={() => setScreen('result')}
            gridSize={battleGridSize}
            concept={battleGridSize !== 4}
          />
        )}
        {screen === 'result' && (
          <ResultScreen
            variant="victory"
            onContinue={() => setScreen('landing')}
            onReport={() => setScreen('report')}
          />
        )}
        {screen === 'result-defeat' && (
          <ResultScreen
            variant="defeat"
            onContinue={() => setScreen('landing')}
            onReport={() => setScreen('report')}
          />
        )}
        {screen === 'report' && (
          <div className="screen-canvas">
            <BattleReportScreen onExit={() => setScreen('landing')} />
          </div>
        )}
        {screen === 'ranks' && <RanksScreen onTabPress={handleTabPress} />}
        {screen === 'season' && <SeasonScreen onBack={() => setScreen('landing')} />}
        {screen === 'daily' && <DailyRewardsScreen onBack={() => setScreen('landing')} />}
      </div>

      <p className="dev-footer-caption">
        NEON GRIMOIRE · SYN-GRID · 7-SCREEN + 3 CONCEPT VARIANTS
      </p>
    </div>
  )
}
