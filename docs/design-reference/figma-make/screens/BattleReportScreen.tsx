import { useState } from 'react'
import AuroraButton from '../components/AuroraButton'

interface Props {
  onExit: () => void
}

type ReportStep = 'breakdown' | 'heatmap' | 'timeline'

export default function BattleReportScreen({ onExit }: Props) {
  const [step, setStep] = useState<ReportStep>('breakdown')

  const nextStep = () => {
    if (step === 'breakdown') setStep('heatmap')
    else if (step === 'heatmap') setStep('timeline')
    else onExit()
  }

  const prevStep = () => {
    if (step === 'timeline') setStep('heatmap')
    else if (step === 'heatmap') setStep('breakdown')
  }

  return (
    <div style={{ width: '100%', height: '100%', background: '#141419', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '38px 16px 12px', borderBottom: '1px solid #2A2A33', flexShrink: 0 }}>
        <div style={{ fontFamily: 'Orbitron', fontSize: 14, fontWeight: 700, letterSpacing: '0.15em', color: '#00F5D4' }}>
          {step === 'breakdown' && 'BREAKDOWN'}
          {step === 'heatmap' && 'HEATMAP'}
          {step === 'timeline' && 'TIMELINE'}
        </div>
        <button onClick={onExit} style={{ background: 'transparent', border: 'none', color: '#C8CDD688', fontFamily: 'JetBrains Mono', fontSize: 10, letterSpacing: '0.1em', cursor: 'pointer' }}>SKIP ✕</button>
      </div>

      {/* Content Area */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px' }} className="scroll-hide">
        {step === 'breakdown' && <BreakdownStep />}
        {step === 'heatmap' && <HeatmapStep />}
        {step === 'timeline' && <TimelineStep />}
      </div>

      {/* Footer Nav */}
      <div style={{ borderTop: '1px solid #2A2A33', padding: '16px', display: 'flex', gap: 12, flexShrink: 0, background: '#141419' }}>
        <button 
          onClick={prevStep} 
          disabled={step === 'breakdown'}
          style={{
            flex: 1, background: '#1F1F26', border: '1px solid #2A2A33', borderRadius: 8,
            color: step === 'breakdown' ? '#C8CDD633' : '#C8CDD6', fontFamily: 'Orbitron', fontSize: 10, letterSpacing: '0.1em', cursor: step === 'breakdown' ? 'default' : 'pointer'
          }}
        >
          PREV
        </button>
        <div style={{ flex: 2 }}>
          <AuroraButton size="lg" onClick={nextStep} style={{ width: '100%' }}>
            {step === 'timeline' ? '✓ CONTINUE' : 'NEXT ▶'}
          </AuroraButton>
        </div>
      </div>
    </div>
  )
}

function BreakdownStep() {
  const sections = [
    { title: 'DAMAGE DEALT', color: '#00F5D4', items: [{ name: 'VOIDBLADE', val: 186, max: 200 }, { name: 'NECROFLASK', val: 62, max: 200 }] },
    { title: 'DAMAGE TAKEN', color: '#D81E3D', items: [{ name: 'SHADOWMANTLE', val: 120, max: 150 }, { name: 'GRIMHELM', val: 45, max: 150 }] },
    { title: 'SYNERGY CONTRIBUTION', color: '#7B2FBE', items: [{ name: 'VOIDBLADE', val: 18, max: 30 }, { name: 'SHADOWMANTLE', val: 18, max: 30 }] },
  ]

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
      {sections.map(sec => (
        <div key={sec.title}>
          <div style={{ fontFamily: 'Orbitron', fontSize: 9, letterSpacing: '0.15em', color: '#C8CDD644', marginBottom: 12 }}>{sec.title}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {sec.items.map(item => (
              <div key={item.name} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 80, fontFamily: 'Inter', fontSize: 9, color: '#C8CDD6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.name}</div>
                <div style={{ flex: 1, height: 12, background: '#1F1F26', borderRadius: 4, overflow: 'hidden', border: '1px solid #2A2A33' }}>
                  <div style={{ width: `${(item.val / item.max) * 100}%`, height: '100%', background: sec.color, opacity: 0.8 }} />
                </div>
                <div style={{ width: 30, textAlign: 'right', fontFamily: 'JetBrains Mono', fontSize: 10, color: '#C8CDD6' }}>{item.val}</div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

function HeatmapStep() {
  const legend = [
    { color: '#00F5D4', label: 'Dealt Dmg' },
    { color: '#4A90E2', label: 'Took Dmg' },
    { color: '#D81E3D', label: 'Never Fired' },
  ]

  const opponentGrid = [
    { id: '1', role: 'dealt', name: 'PHANTOM' },
    { id: '2', role: 'took', name: 'CURSE' },
    { id: '3', role: 'none', name: 'DOOM' },
    { id: '4', role: 'dealt', name: 'BLOOD' },
  ]
  const playerGrid = [
    { id: '1', role: 'dealt', name: 'VOID' },
    { id: '2', role: 'took', name: 'SHADOW' },
    { id: '3', role: 'none', name: 'NECRO' },
    { id: '4', role: 'took', name: 'GRIM' },
  ]

  const getColor = (role: string) => role === 'dealt' ? '#00F5D4' : role === 'took' ? '#4A90E2' : '#D81E3D'

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Legend */}
      <div style={{ display: 'flex', justifyContent: 'center', gap: 16, background: '#1F1F26', padding: '8px', borderRadius: 8, border: '1px solid #2A2A33' }}>
        {legend.map(l => (
          <div key={l.label} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: l.color, boxShadow: `0 0 5px ${l.color}` }} />
            <span style={{ fontFamily: 'Inter', fontSize: 9, color: '#C8CDD688' }}>{l.label}</span>
          </div>
        ))}
      </div>

      <HeatmapGrid title="OPPONENT" data={opponentGrid} getColor={getColor} />
      <div style={{ height: 1, background: '#2A2A33', margin: '0 20px' }} />
      <HeatmapGrid title="YOU" data={playerGrid} getColor={getColor} />
    </div>
  )
}

function HeatmapGrid({ title, data, getColor }: { title: string, data: any[], getColor: (role: string) => string }) {
  return (
    <div>
      <div style={{ fontFamily: 'Orbitron', fontSize: 10, letterSpacing: '0.15em', color: '#C8CDD6', textAlign: 'center', marginBottom: 12 }}>{title}</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, padding: '0 20px' }}>
        {/* Placeholder cells for a 4x4 representation */}
        {[...Array(16)].map((_, i) => {
          // Just scatter the 4 items randomly for the visual mockup
          const item = i === 5 ? data[0] : i === 6 ? data[1] : i === 9 ? data[2] : i === 10 ? data[3] : null
          
          if (!item) return <div key={i} style={{ aspectRatio: '1', background: '#1F1F26', borderRadius: 6, border: '1px solid #2A2A3344' }} />
          
          const color = getColor(item.role)
          return (
            <div key={i} style={{ 
              aspectRatio: '1', background: '#1F1F26', borderRadius: 6, 
              border: `2px solid ${color}`, boxShadow: `0 0 10px ${color}44, inset 0 0 8px ${color}22`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: 'Orbitron', fontSize: 7, color: '#C8CDD6', fontWeight: 700
            }}>
              {item.name}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function TimelineStep() {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 32, paddingTop: 20 }}>
      
      {/* HP Bars */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <TimelineBar label="OPPONENT HP" color="#D81E3D" pct={0} val="0/120" />
        <TimelineBar label="YOUR HP" color="#00F5D4" pct={35} val="35/100" />
      </div>

      {/* Scrubber */}
      <div style={{ marginTop: 20 }}>
        <div style={{ fontFamily: 'Orbitron', fontSize: 9, letterSpacing: '0.15em', color: '#C8CDD644', marginBottom: 20, textAlign: 'center' }}>BATTLE TIMELINE</div>
        
        <div style={{ position: 'relative', height: 4, background: '#1F1F26', borderRadius: 2, border: '1px solid #2A2A33' }}>
          <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: '100%', background: '#7B2FBE44', borderRadius: 2 }} />
          
          {/* Turning Point Marker */}
          <div style={{ position: 'absolute', left: '60%', top: -8, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
            <div style={{ fontFamily: 'Inter', fontSize: 8, color: '#FFB627', whiteSpace: 'nowrap', background: '#141419', padding: '2px 4px', borderRadius: 4, border: '1px solid #FFB62744' }}>TURNING POINT</div>
            <div style={{ width: 2, height: 12, background: '#FFB627' }} />
          </div>

          {/* Current Tick Handle */}
          <div style={{ position: 'absolute', left: '100%', top: '50%', transform: 'translate(-50%, -50%)', width: 12, height: 12, borderRadius: '50%', background: '#00F5D4', boxShadow: '0 0 8px #00F5D4' }} />
        </div>
        
        <div style={{ textAlign: 'center', fontFamily: 'JetBrains Mono', fontSize: 10, color: '#C8CDD688', marginTop: 16 }}>
          TICK 142 / 142
        </div>
      </div>
    </div>
  )
}

function TimelineBar({ label, color, pct, val }: { label: string, color: string, pct: number, val: string }) {
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
        <span style={{ fontFamily: 'Orbitron', fontSize: 9, letterSpacing: '0.1em', color: '#C8CDD6' }}>{label}</span>
        <span style={{ fontFamily: 'JetBrains Mono', fontSize: 9, color: '#C8CDD688' }}>{val}</span>
      </div>
      <div style={{ height: 16, background: '#1F1F26', borderRadius: 8, overflow: 'hidden', border: '1px solid #2A2A33', position: 'relative' }}>
        <div style={{ width: `${pct}%`, height: '100%', background: color, opacity: 0.8 }} />
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', paddingLeft: 8, fontFamily: 'JetBrains Mono', fontSize: 9, color: '#fff', textShadow: '0 1px 2px rgba(0,0,0,0.8)' }}>
          {pct > 0 ? val : 'K.O.'}
        </div>
      </div>
    </div>
  )
}