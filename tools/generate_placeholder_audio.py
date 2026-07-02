#!/usr/bin/env python3
"""Generate placeholder audio for the Syn-Grid client.

Synthesizes every SFX in the juice_manual.md section 5 event matrix plus the
two looping BGM tracks (prep: dark synthwave / combat: percussive chiptune),
entirely from oscillators and noise - no samples, so everything here is safe
to commit and ship while real assets are sourced per section 6.

Run from the repo root:  python3 tools/generate_placeholder_audio.py
Outputs 16-bit mono WAVs into assets/audio/{sfx,bgm}/.
"""

import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
BGM_DIR = ROOT / "assets" / "audio" / "bgm"

rng = np.random.default_rng(seed=8080)


# ---------------------------------------------------------------- primitives

def samples(dur: float) -> int:
    return int(SR * dur)


def time_axis(dur: float) -> np.ndarray:
    return np.arange(samples(dur)) / SR


def osc(freq, dur: float, shape: str = "sine", duty: float = 0.5) -> np.ndarray:
    """freq may be a scalar or a per-sample array (for sweeps/vibrato)."""
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (samples(dur),))
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.sign(np.sin(phase) - np.cos(np.pi * duty))
    if shape == "saw":
        return 2.0 * ((phase / (2.0 * np.pi)) % 1.0) - 1.0
    if shape == "triangle":
        return 2.0 * np.abs(2.0 * ((phase / (2.0 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(shape)


def sweep(f0: float, f1: float, dur: float) -> np.ndarray:
    """Exponential frequency ramp, natural for pitch drops/rises."""
    return f0 * (f1 / f0) ** (time_axis(dur) / dur)


def noise(dur: float) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, samples(dur))


def decay_env(dur: float, k: float = 6.0, attack: float = 0.002) -> np.ndarray:
    n = samples(dur)
    env = np.exp(-k * np.arange(n) / n)
    a = min(samples(attack), n)
    if a > 0:
        env[:a] *= np.linspace(0.0, 1.0, a)
    return env


def trap_env(dur: float, attack: float, release: float) -> np.ndarray:
    n = samples(dur)
    env = np.ones(n)
    a, r = min(samples(attack), n), min(samples(release), n)
    if a > 0:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        env[n - r:] = np.linspace(1.0, 0.0, r)
    return env


def lowpass(sig: np.ndarray, cutoff) -> np.ndarray:
    """One-pole lowpass; cutoff may be a scalar or per-sample array (sweeps)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), sig.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    out = np.empty_like(sig)
    acc = 0.0
    for i in range(len(sig)):
        acc += alpha[i] * (sig[i] - acc)
        out[i] = acc
    return out


def highpass(sig: np.ndarray, cutoff: float) -> np.ndarray:
    return sig - lowpass(sig, cutoff)


def karplus(freq: float, dur: float, damp: float = 0.996) -> np.ndarray:
    """Karplus-Strong plucked string - the bow twang."""
    n = samples(dur)
    period = int(SR / freq)
    buf = rng.uniform(-1.0, 1.0, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def place(buf: np.ndarray, sig: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = samples(at)
    end = min(start + len(sig), len(buf))
    buf[start:end] += gain * sig[: end - start]


def write_wav(path: Path, sig: np.ndarray, peak: float = 0.7) -> None:
    sig = sig * (peak / max(1e-9, np.max(np.abs(sig))))
    pcm = (np.clip(sig, -1.0, 1.0) * 32767).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    print(f"  {path.relative_to(ROOT)}  ({len(sig) / SR:.2f}s)")


# ----------------------------------------------------------------------- SFX

def sfx_shop_reroll() -> np.ndarray:
    """High-freq wooden dice clatter + mechanical metallic notch."""
    out = np.zeros(samples(0.4))
    for i, at in enumerate([0.0, 0.055, 0.10, 0.14]):
        click = highpass(noise(0.03), 2500 - i * 400) * decay_env(0.03, k=9)
        place(out, click, at, gain=0.9 - i * 0.12)
    notch = (osc(2093, 0.18) + 0.5 * osc(3136, 0.18)) * decay_env(0.18, k=10)
    place(out, notch, 0.18, gain=0.5)
    return out


def sfx_synergy_link() -> np.ndarray:
    """Rising synth chime; pitch_scale ascends further per modifier_pct."""
    out = np.zeros(samples(0.55))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        tone = (osc(f, 0.28) + 0.4 * osc(f * 2, 0.28)) * decay_env(0.28, k=5, attack=0.008)
        place(out, tone, i * 0.07, gain=0.55 + i * 0.1)
    return out


def sfx_grid_snap() -> np.ndarray:
    """Satisfying grid-snap click, short transient."""
    out = np.zeros(samples(0.14))
    place(out, highpass(noise(0.008), 3000) * decay_env(0.008, k=4), 0.0, gain=0.9)
    place(out, osc(sweep(220, 150, 0.1), 0.1) * decay_env(0.1, k=8), 0.004, gain=0.9)
    return out


def sfx_item_drag() -> np.ndarray:
    """Soft card-lift whoosh."""
    body = lowpass(noise(0.16), sweep(500, 2600, 0.16))
    return body * trap_env(0.16, 0.05, 0.07) * 0.8


def sfx_melee_strike() -> np.ndarray:
    """Explosive metallic slice, immediate decay."""
    out = np.zeros(samples(0.28))
    slice_ = lowpass(noise(0.16), sweep(7000, 500, 0.16)) * decay_env(0.16, k=7)
    place(out, slice_, 0.0, gain=1.0)
    place(out, osc(sweep(150, 70, 0.18), 0.18) * decay_env(0.18, k=6), 0.005, gain=0.8)
    return out


def sfx_ranged_strike() -> np.ndarray:
    """Bow twang / crossbow snap."""
    out = np.zeros(samples(0.32))
    place(out, highpass(noise(0.012), 2000) * decay_env(0.012, k=5), 0.0, gain=0.7)
    place(out, karplus(180, 0.3) * decay_env(0.3, k=5), 0.004, gain=1.0)
    return out


def sfx_arcane_strike() -> np.ndarray:
    """Staff hum / spell whoosh."""
    dur = 0.42
    vib = sweep(300, 950, dur) * (1.0 + 0.02 * osc(9, dur))
    hum = osc(vib, dur) * trap_env(dur, 0.06, 0.18)
    shimmer = highpass(noise(dur), 4000) * trap_env(dur, 0.15, 0.2)
    return hum * 0.9 + shimmer * 0.25


def sfx_crit_hit() -> np.ndarray:
    """Melee strike + heavy pitched-down impact overtone (contract: layered)."""
    base = sfx_melee_strike()
    out = np.zeros(samples(0.5))
    place(out, base, 0.0, gain=1.0)
    place(out, base[::2], 0.0, gain=0.9)          # same strike pitched up an octave
    low = lowpass(np.repeat(base, 2), 900)        # and stretched down an octave
    place(out, low, 0.0, gain=0.9)
    place(out, osc(sweep(65, 40, 0.3), 0.3) * decay_env(0.3, k=5), 0.0, gain=0.9)
    return out


def sfx_shield_absorb() -> np.ndarray:
    """Dense low-freq iron chime with a distinct ring-out trail."""
    dur = 0.85
    out = np.zeros(samples(dur))
    for f, g in [(220, 1.0), (332.6, 0.6), (523.7, 0.4), (810.3, 0.25)]:
        place(out, osc(f, dur) * decay_env(dur, k=4.5), 0.0, gain=g)
    place(out, lowpass(noise(0.02), 1500) * decay_env(0.02, k=4), 0.0, gain=0.6)
    return out


def sfx_hp_loss() -> np.ndarray:
    """Soft thud - pitched-down cousin of the melee strike."""
    thud = osc(sweep(110, 55, 0.22), 0.22) * decay_env(0.22, k=6, attack=0.004)
    body = lowpass(noise(0.08), 400) * decay_env(0.08, k=6)
    out = np.zeros(samples(0.24))
    place(out, thud, 0.0, gain=1.0)
    place(out, body, 0.0, gain=0.5)
    return out


def sfx_fatal_hp_loss() -> np.ndarray:
    """Sub-bass drop; the BGM LPF sweep is applied live by AudioManager."""
    dur = 1.4
    drop = osc(sweep(130, 36, dur), dur) * trap_env(dur, 0.01, 0.6)
    rumble = lowpass(noise(dur), 120) * trap_env(dur, 0.2, 0.7)
    return drop * 0.95 + rumble * 0.4


def sfx_triple_merge() -> np.ndarray:
    """Rising chime + particle-impact sparkle."""
    out = np.zeros(samples(0.65))
    for i, f in enumerate([659.25, 880.0, 1318.5]):
        tone = (osc(f, 0.3) + 0.35 * osc(f * 2, 0.3)) * decay_env(0.3, k=5, attack=0.006)
        place(out, tone, i * 0.09, gain=0.7)
    for _ in range(8):
        f = rng.uniform(2000, 5200)
        at = rng.uniform(0.28, 0.5)
        place(out, osc(f, 0.06) * decay_env(0.06, k=6), at, gain=0.18)
    return out


def sfx_win_round() -> np.ndarray:
    """Ascending 3-note victory chime."""
    out = np.zeros(samples(1.0))
    notes = [(523.25, 0.0, 0.22), (659.25, 0.16, 0.22), (783.99, 0.32, 0.6)]
    for f, at, d in notes:
        tone = (osc(f, d) + 0.5 * osc(f * 2, d) + 0.2 * osc(f * 3, d))
        place(out, tone * decay_env(d, k=4, attack=0.005), at, gain=0.8)
    return out


def sfx_triumph_milestone() -> np.ndarray:
    """Short fanfare sting."""
    out = np.zeros(samples(1.1))
    chords = [([392.0, 493.88, 587.33], 0.0, 0.18), ([523.25, 659.25, 783.99], 0.2, 0.7)]
    for freqs, at, d in chords:
        for f in freqs:
            stab = osc(f, d, "square", duty=0.3) + osc(f * 1.005, d, "saw")
            place(out, lowpass(stab, 3500) * decay_env(d, k=3.5, attack=0.01), at, gain=0.4)
    place(out, highpass(noise(0.5), 5000) * decay_env(0.5, k=5), 0.2, gain=0.15)
    return out


SFX_BUILDERS = {
    "sfx_shop_reroll": sfx_shop_reroll,
    "sfx_synergy_link": sfx_synergy_link,
    "sfx_grid_snap": sfx_grid_snap,
    "sfx_item_drag": sfx_item_drag,
    "sfx_melee_strike": sfx_melee_strike,
    "sfx_ranged_strike": sfx_ranged_strike,
    "sfx_arcane_strike": sfx_arcane_strike,
    "sfx_crit_hit": sfx_crit_hit,
    "sfx_shield_absorb": sfx_shield_absorb,
    "sfx_hp_loss": sfx_hp_loss,
    "sfx_fatal_hp_loss": sfx_fatal_hp_loss,
    "sfx_triple_merge": sfx_triple_merge,
    "sfx_win_round": sfx_win_round,
    "sfx_triumph_milestone": sfx_triumph_milestone,
}


# ----------------------------------------------------------------------- BGM

# Note frequencies (equal temperament).
N = {
    "A1": 55.0, "D2": 73.42, "E2": 82.41, "F2": 87.31, "G2": 98.0, "A2": 110.0,
    "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.0, "GS3": 207.65,
    "A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63,
    "F4": 349.23, "G4": 392.0, "A4": 440.0, "C5": 523.25, "E5": 659.25,
}


def kick(dur: float = 0.3) -> np.ndarray:
    return osc(sweep(100, 42, dur), dur) * decay_env(dur, k=7, attack=0.001)


def bgm_prep() -> np.ndarray:
    """Dark synthwave, 80 BPM, 12 bars = 36s seamless loop (contract: 30-45s)."""
    bpm, bars = 80.0, 12
    beat = 60.0 / bpm
    bar = 4.0 * beat
    out = np.zeros(samples(bars * bar))
    # i - VI - iv - V in A minor: [bass root, pad voicing...]
    prog = [
        (N["A1"], [N["A3"], N["C4"], N["E4"]]),
        (N["F2"] / 2, [N["F3"], N["A3"], N["C4"]]),
        (N["D2"], [N["D3"], N["F3"], N["A3"]]),
        (N["E2"], [N["E3"], N["GS3"], N["B3"]]),
    ]
    for b in range(bars):
        at = b * bar
        root, pad_notes = prog[b % 4]
        # Detuned saw pad, heavily lowpassed, breathing in per bar.
        pad = np.zeros(samples(bar))
        for f in pad_notes:
            for det in (0.996, 1.004):
                pad += osc(f * det, bar, "saw")
        place(out, lowpass(pad, 900) * trap_env(bar, 0.9, 0.6), at, gain=0.16)
        # Slow pulsing sub bass: dotted pattern on the root.
        for pulse_beat, plen in [(0.0, 1.2), (1.5, 0.9), (2.5, 1.2)]:
            sub = (osc(root, plen * beat, "triangle") + 0.4 * osc(root * 2, plen * beat, "square", 0.4))
            place(out, lowpass(sub, 250) * trap_env(plen * beat, 0.02, 0.3), at + pulse_beat * beat, gain=0.5)
        # Sparse sine arp, octave up, 8th notes - drops out every 4th bar.
        if b % 4 != 3:
            arp_notes = [f * 2 for f in pad_notes] + [pad_notes[1] * 4]
            for i in range(8):
                f = arp_notes[i % len(arp_notes)]
                tone = osc(f, 0.45 * beat) * decay_env(0.45 * beat, k=4, attack=0.004)
                place(out, tone, at + i * 0.5 * beat, gain=0.14)
        # Soft heartbeat kick on 1 and 3.
        place(out, kick(0.35), at, gain=0.55)
        place(out, kick(0.35), at + 2 * beat, gain=0.4)
    return out


def bgm_combat() -> np.ndarray:
    """Percussive chiptune / synthwave, 128 BPM, 16 bars = 30s seamless loop."""
    bpm, bars = 128.0, 16
    beat = 60.0 / bpm
    bar = 4.0 * beat
    out = np.zeros(samples(bars * bar))
    prog = [
        (N["A2"], [N["A3"], N["C4"], N["E4"]]),
        (N["G2"], [N["G3"], N["B3"], N["D4"]]),
        (N["F2"], [N["F3"], N["A3"], N["C4"]]),
        (N["E2"], [N["E3"], N["GS3"], N["B3"]]),
    ]
    for b in range(bars):
        at = b * bar
        root, chord = prog[b % 4]
        # Four-on-the-floor kick + snare on 2 and 4 + offbeat hats.
        for k_ in range(4):
            place(out, kick(0.22), at + k_ * beat, gain=0.8)
        for s in (1, 3):
            snare = (highpass(noise(0.12), 1800) + 0.3 * osc(190, 0.12)) * decay_env(0.12, k=6)
            place(out, snare, at + s * beat, gain=0.5)
        for h in range(8):
            if h % 2 == 1:
                place(out, highpass(noise(0.04), 6000) * decay_env(0.04, k=6), at + h * 0.5 * beat, gain=0.22)
        # Driving square bass, 8ths alternating octave.
        for i in range(8):
            f = root if i % 2 == 0 else root * 2
            tone = osc(f, 0.4 * beat, "square", duty=0.45)
            place(out, lowpass(tone, 700) * trap_env(0.4 * beat, 0.004, 0.05), at + i * 0.5 * beat, gain=0.32)
        # Chiptune lead arp, 16ths - rests every 4th bar for tension.
        if b % 4 != 3:
            arp = [chord[0] * 2, chord[1] * 2, chord[2] * 2, chord[1] * 4]
            for i in range(16):
                f = arp[i % 4]
                tone = osc(f, 0.22 * beat, "square", duty=0.25)
                place(out, tone * decay_env(0.22 * beat, k=3, attack=0.002), at + i * 0.25 * beat, gain=0.13)
        else:
            stab = sum(osc(f * 2, 2 * beat, "saw") for f in chord)
            place(out, lowpass(stab, 1400) * trap_env(2 * beat, 0.02, 1.2), at, gain=0.16)
    return out


# ---------------------------------------------------------------------- main

def main() -> None:
    print("SFX:")
    for name, build in SFX_BUILDERS.items():
        write_wav(SFX_DIR / f"{name}.wav", build(), peak=0.7)
    print("BGM:")
    write_wav(BGM_DIR / "bgm_prep.wav", bgm_prep(), peak=0.5)
    write_wav(BGM_DIR / "bgm_combat.wav", bgm_combat(), peak=0.55)


if __name__ == "__main__":
    main()
