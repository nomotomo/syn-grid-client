import { useEffect, useRef } from 'react'

const RUNES = ['ᚠ','ᚢ','ᚦ','ᚨ','ᚱ','ᚲ','ᚷ','ᚹ','ᚺ','ᚾ','ᛁ','ᛃ','ᛇ','ᛈ','ᛉ','ᛊ','ᛏ','ᛒ','ᛖ','ᛗ','ᛚ','ᛜ','ᛞ','ᛟ','⬡','◈','⟁','⌬']

interface Particle {
  x: number; y: number; char: string
  size: number; opacity: number; speed: number; drift: number
  life: number; maxLife: number; purple: boolean
}

export default function RuneField({ accentColor = '#7B2FBE' }: { accentColor?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const W = canvas.width = canvas.offsetWidth
    const H = canvas.height = canvas.offsetHeight
    const particles: Particle[] = []

    const spawn = () => {
      particles.push({
        x: Math.random() * W,
        y: H + 20,
        char: RUNES[Math.floor(Math.random() * RUNES.length)],
        size: 10 + Math.random() * 18,
        opacity: 0,
        speed: 0.3 + Math.random() * 0.5,
        drift: (Math.random() - 0.5) * 0.3,
        life: 0,
        maxLife: 200 + Math.random() * 300,
        purple: Math.random() < 0.15,
      })
    }

    for (let i = 0; i < 30; i++) {
      spawn()
      const p = particles[particles.length - 1]
      p.y = Math.random() * H
      p.life = Math.random() * p.maxLife
    }

    let frame: number
    let ticker = 0

    const draw = () => {
      ctx.clearRect(0, 0, W, H)
      ticker++
      if (ticker % 40 === 0 && particles.length < 50) spawn()

      for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i]
        p.life++
        p.y -= p.speed
        p.x += p.drift
        const t = p.life / p.maxLife
        p.opacity = t < 0.2 ? t / 0.2 * 0.15 : t > 0.8 ? (1 - t) / 0.2 * 0.15 : 0.15
        if (p.purple) p.opacity *= 2.5

        ctx.save()
        ctx.font = `${p.size}px 'Inter', sans-serif`
        ctx.fillStyle = p.purple ? accentColor : '#C8CDD6'
        ctx.globalAlpha = p.opacity
        ctx.fillText(p.char, p.x, p.y)
        ctx.restore()

        if (p.life >= p.maxLife) particles.splice(i, 1)
      }

      // dust specks
      for (let i = 0; i < 3; i++) {
        const x = Math.random() * W
        const y = Math.random() * H
        ctx.save()
        ctx.beginPath()
        ctx.arc(x, y, 0.8, 0, Math.PI * 2)
        ctx.fillStyle = '#C8CDD6'
        ctx.globalAlpha = Math.random() * 0.06
        ctx.fill()
        ctx.restore()
      }

      frame = requestAnimationFrame(draw)
    }

    draw()
    return () => cancelAnimationFrame(frame)
  }, [accentColor])

  return (
    <>
      <canvas ref={canvasRef} className="absolute inset-0 w-full h-full" style={{ opacity: 1 }} />
      {/* vignette */}
      <div className="absolute inset-0" style={{
        background: 'radial-gradient(ellipse at center, transparent 40%, #141419 100%)',
        pointerEvents: 'none',
      }} />
    </>
  )
}
