import { useState } from 'react'
import AuroraButton from './AuroraButton'

const PLAYER_ID  = 'usr_7f3a9c1b2e'
const INIT_NAME  = 'SHADOWMANCER'
const AVATAR_HUE = '#7B2FBE'

interface Props { onClose: () => void }

export default function ProfileModal({ onClose }: Props) {
  const [name, setName] = useState(INIT_NAME)
  const [saved, setSaved] = useState(false)

  const handleConfirm = () => {
    setSaved(true)
    setTimeout(() => { setSaved(false); onClose() }, 800)
  }

  return (
    /* backdrop — tap outside to dismiss */
    <div
      onClick={onClose}
      style={{
        position: 'absolute', inset: 0, zIndex: 200,
        background: '#14141988', backdropFilter: 'blur(6px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '0 24px',
      }}
    >
      {/* modal card — stop propagation so tapping inside doesn't dismiss */}
      <div
        className="modal-in"
        onClick={e => e.stopPropagation()}
        style={{
          width: '100%', maxWidth: 360,
          background: '#1F1F26',
          border: '1px solid #7B2FBE55',
          borderRadius: 20,
          boxShadow: '0 0 40px #7B2FBE33, 0 24px 48px #00000088',
          overflow: 'hidden',
        }}
      >
        {/* header */}
        <div style={{
          padding: '14px 20px', borderBottom: '1px solid #2A2A33',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <span style={{ fontFamily: 'Orbitron', fontSize: 12, fontWeight: 700, letterSpacing: '0.15em', color: '#C8CDD6' }}>PROFILE</span>
          <button onClick={onClose} style={{
            background: 'none', border: 'none', cursor: 'pointer',
            fontFamily: 'JetBrains Mono', fontSize: 16, color: '#C8CDD644',
            lineHeight: 1, padding: '2px 6px',
          }}>✕</button>
        </div>

        {/* identity block */}
        <div style={{ padding: '24px 20px 16px', display: 'flex', gap: 16, alignItems: 'center' }}>
          {/* avatar */}
          <div style={{
            width: 56, height: 56, borderRadius: '50%', flexShrink: 0,
            background: `linear-gradient(135deg, ${AVATAR_HUE}, #00F5D4)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 0 0 2px #141419, 0 0 0 3px ${AVATAR_HUE}88, 0 0 16px ${AVATAR_HUE}44`,
          }}>
            <span style={{ fontFamily: 'Orbitron', fontWeight: 900, fontSize: 22, color: '#fff' }}>
              {(name[0] || 'S').toUpperCase()}
            </span>
          </div>

          {/* id + current name */}
          <div style={{ minWidth: 0 }}>
            <div style={{
              fontFamily: 'JetBrains Mono', fontSize: 10, color: '#C8CDD644',
              letterSpacing: '0.08em', marginBottom: 4,
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{PLAYER_ID}</div>
            <div style={{
              fontFamily: 'Orbitron', fontSize: 15, fontWeight: 700,
              color: '#C8CDD6', letterSpacing: '0.06em',
              overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            }}>{name || '—'}</div>
            <div style={{
              fontFamily: 'Inter', fontSize: 10, color: '#00F5D488', marginTop: 3,
            }}>Triumph 3/10 · Season 4</div>
          </div>
        </div>

        {/* divider */}
        <div style={{ height: 1, background: '#2A2A33', margin: '0 20px' }} />

        {/* editable display name */}
        <div style={{ padding: '16px 20px 20px' }}>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
            marginBottom: 8,
          }}>
            <label style={{ fontFamily: 'Orbitron', fontSize: 9, letterSpacing: '0.14em', color: '#C8CDD666' }}>
              DISPLAY NAME
            </label>
            <span style={{
              fontFamily: 'JetBrains Mono', fontSize: 9,
              color: name.length > 20 ? '#FFB627' : '#C8CDD633',
            }}>
              {name.length}/24
            </span>
          </div>

          <input
            value={name}
            maxLength={24}
            onChange={e => setName(e.target.value.toUpperCase())}
            style={{
              width: '100%', boxSizing: 'border-box',
              background: '#141419', border: '1px solid #2A2A33',
              borderRadius: 10, padding: '10px 14px',
              fontFamily: 'Orbitron', fontSize: 13, fontWeight: 700,
              color: '#C8CDD6', letterSpacing: '0.06em',
              outline: 'none',
            }}
            onFocus={e => { e.currentTarget.style.borderColor = '#00F5D488' }}
            onBlur={e => { e.currentTarget.style.borderColor = '#2A2A33' }}
          />

          {name.length === 0 && (
            <div style={{ fontFamily: 'Inter', fontSize: 10, color: '#D81E3D88', marginTop: 6 }}>
              Display name cannot be empty.
            </div>
          )}

          <div style={{ marginTop: 16, display: 'flex', justifyContent: 'center' }}>
            {saved ? (
              <div style={{
                fontFamily: 'Orbitron', fontSize: 12, color: '#00F5D4',
                letterSpacing: '0.12em', padding: '12px 0',
              }}>✓ SAVED</div>
            ) : (
              <AuroraButton
                size="sm"
                onClick={handleConfirm}
                className={name.length === 0 ? 'opacity-40 pointer-events-none' : ''}
              >
                CONFIRM
              </AuroraButton>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
