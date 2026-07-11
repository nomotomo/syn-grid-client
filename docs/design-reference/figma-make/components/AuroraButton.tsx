import type { ReactNode } from 'react'

interface AuroraButtonProps {
  children: ReactNode
  onClick?: () => void
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

export default function AuroraButton({ children, onClick, size = 'md', className = '' }: AuroraButtonProps) {
  const pad = size === 'lg' ? 'px-12 py-4' : size === 'sm' ? 'px-6 py-2' : 'px-8 py-3'
  const textSize = size === 'lg' ? 'text-xl' : size === 'sm' ? 'text-sm' : 'text-base'

  return (
    <button
      onClick={onClick}
      className={`aurora-btn relative rounded-full font-display font-bold tracking-widest uppercase cursor-pointer ${pad} ${textSize} ${className}`}
      style={{
        background: 'linear-gradient(135deg, #1F1F26 0%, #2A2A33 100%)',
        color: '#00F5D4',
        border: 'none',
        letterSpacing: '0.15em',
      }}
    >
      {children}
    </button>
  )
}
