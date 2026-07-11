import { useState } from 'react'

const RARITY_LABEL: Record<'bronze' | 'silver' | 'gold' | 'epic', string> = {
  bronze: 'I',
  silver: 'II',
  gold: 'III',
  epic: 'IV',
}

const TIER_GLOW: Record<'bronze' | 'silver' | 'gold' | 'epic', string> = {
  bronze: 'glow-tier-bronze',
  silver: 'glow-tier-silver',
  gold: 'glow-tier-gold',
  epic: 'glow-tier-epic',
}

function abbrev(name: string): string {
  if (name.length <= 8) return name
  const first = name.split(/[\s-_]/)[0]
  if (first.length <= 8) return first
  return name.slice(0, 7) + '…'
}

export interface ItemCardData {
  name: string
  icon: string
  rarity: keyof typeof RARITY_LABEL
  category: 'weapon' | 'armor' | 'potion' | 'relic'
  atk?: number
  def?: number
  spd?: number
  cost?: number
  synergy?: boolean
}

interface Props {
  item: ItemCardData
  variant?: 'grid' | 'shop' | 'bench'
}

type StatKind = 'atk' | 'def' | 'spd'

const STAT_TONE_CLASS: Record<StatKind, string> = {
  atk: 'text-crimson',
  def: 'text-teal',
  spd: 'text-amber',
}

export default function ItemCard({ item, variant = 'shop' }: Props) {
  const [tip, setTip] = useState(false)
  const isAbbreviated = abbrev(item.name) !== item.name

  return (
    <div
      className={[
        'item-card',
        `item-card--${variant}`,
        `item-card--${item.rarity}`,
        `item-card--${item.category}`,
        TIER_GLOW[item.rarity],
        isAbbreviated ? 'cursor-pointer' : '',
      ]
        .filter(Boolean)
        .join(' ')}
      onMouseEnter={() => isAbbreviated && setTip(true)}
      onMouseLeave={() => setTip(false)}
      onPointerDown={() => isAbbreviated && setTip(true)}
      onPointerUp={() => setTip(false)}
      onPointerLeave={() => setTip(false)}
    >
      {tip && (
        <div className="item-card__tooltip" role="tooltip">
          {item.name}
          <div className="item-card__tooltip-arrow" aria-hidden="true" />
        </div>
      )}

      {item.synergy && <div className="item-card__synergy-rim synergy-edge" aria-hidden="true" />}

      <div className="item-card__rarity-chip">{RARITY_LABEL[item.rarity]}</div>

      {item.cost !== undefined && (
        <div className="item-card__cost-chip">💰{item.cost}</div>
      )}

      <div className="item-card__inner">
        <div className="item-card__icon" aria-hidden="true">
          {item.icon}
        </div>

        <div className="item-card__name font-body">{abbrev(item.name)}</div>

        <div className="item-card__stats">
          {item.atk !== undefined && <Pip label="ATK" value={item.atk} kind="atk" />}
          {item.def !== undefined && <Pip label="DEF" value={item.def} kind="def" />}
          {item.spd !== undefined && <Pip label="SPD" value={item.spd} kind="spd" />}
        </div>
      </div>
    </div>
  )
}

function Pip({ label, value, kind }: { label: string; value: number; kind: StatKind }) {
  return (
    <div className="item-card__pip">
      <span className="item-card__pip-label">{label}</span>
      <span className={`item-card__pip-value text-mono-stat ${STAT_TONE_CLASS[kind]}`}>
        {value}
      </span>
    </div>
  )
}
