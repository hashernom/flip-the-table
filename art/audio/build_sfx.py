"""Efectos de sonido procedurales de Flip the Table (plan 09, Tarea 6).

Cada efecto se sintetiza desde cero con numpy: osciladores, ruido filtrado y envolventes. No usa
muestras de terceros, así que no hay licencia que confirmar; solo falta subirlos a Roblox y aprobarlos.
El resultado es determinista (semilla fija): volver a ejecutar el script da los mismos archivos.

Uso:  python art/audio/build_sfx.py
Salida: art/audio/sfx/<id>.wav (mono, 44,1 kHz, 16 bits)
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
OUT = Path(__file__).resolve().parent / "sfx"
rng = np.random.default_rng(20261105)


# --- piezas básicas -------------------------------------------------------------------------------

def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def env(seconds: float, attack: float = 0.002, decay: float = 0.1) -> np.ndarray:
    """Ataque lineal y caída exponencial: el golpe de casi todo lo que suena en la mesa."""
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def tone(freq: float, seconds: float, decay: float, partials=((1, 1.0),), attack=0.002) -> np.ndarray:
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for mult, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * mult * t)
    return out * env(seconds, attack, decay)


def sweep(f0: float, f1: float, seconds: float, decay: float) -> np.ndarray:
    t = t_axis(seconds)
    freq = f0 * (f1 / f0) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) * env(seconds, 0.003, decay)


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(seconds * RATE))


def band(signal: np.ndarray, low: float, high: float, order: int = 2) -> np.ndarray:
    sos = butter(order, [low, high], btype="bandpass", fs=RATE, output="sos")
    return sosfilt(sos, signal)


def lowpass(signal: np.ndarray, cut: float, order: int = 2) -> np.ndarray:
    sos = butter(order, cut, btype="lowpass", fs=RATE, output="sos")
    return sosfilt(sos, signal)


def place(dest: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = int(at * RATE)
    end = min(len(dest), start + len(src))
    dest[start:end] += gain * src[: end - start]


def canvas(seconds: float) -> np.ndarray:
    return np.zeros(int(seconds * RATE))


def knock(freq: float, seconds: float = 0.06, bright: float = 1.0) -> np.ndarray:
    """Golpe de madera: un tono grave que cae rápido más un chasquido de ruido filtrado."""
    body = tone(freq, seconds, 0.012, partials=((1, 1.0), (2.7, 0.35)))
    click = band(noise(seconds), 1500, 6000) * env(seconds, 0.0005, 0.004) * bright
    return body + click


# --- efectos --------------------------------------------------------------------------------------

def ui_press() -> np.ndarray:
    # Clic corto y seco, como pulsar un interruptor de obra.
    return knock(900, 0.05, bright=0.8)


def ui_hover() -> np.ndarray:
    return tone(2400, 0.03, 0.006) * 0.5


def ui_open() -> np.ndarray:
    out = canvas(0.22)
    place(out, knock(520, 0.08), 0.0, 0.7)
    place(out, tone(659, 0.18, 0.06, ((1, 1), (2, 0.25))), 0.01, 0.6)
    place(out, tone(988, 0.16, 0.06, ((1, 1), (2, 0.2))), 0.06, 0.5)
    return out


def ui_close() -> np.ndarray:
    out = canvas(0.2)
    place(out, tone(988, 0.14, 0.05, ((1, 1), (2, 0.2))), 0.0, 0.5)
    place(out, tone(659, 0.16, 0.05, ((1, 1), (2, 0.25))), 0.05, 0.55)
    place(out, knock(420, 0.08), 0.06, 0.6)
    return out


def ui_confirm() -> np.ndarray:
    # Arpegio mayor de campana: la acción salió bien.
    out = canvas(0.55)
    bell = ((1, 1.0), (2.0, 0.4), (3.01, 0.15), (4.2, 0.08))
    for i, f in enumerate((1047, 1319, 1568)):
        place(out, tone(f, 0.4, 0.12, bell), i * 0.055, 0.45)
    return out


def ui_deny() -> np.ndarray:
    # Dos notas graves que bajan, con un poco de aspereza: la acción no se pudo hacer.
    out = canvas(0.3)
    rough = ((1, 1.0), (2, 0.5), (3, 0.3))
    place(out, tone(330, 0.12, 0.05, rough), 0.0, 0.5)
    place(out, tone(247, 0.18, 0.07, rough), 0.09, 0.55)
    return lowpass(out, 2500)


def ui_money() -> np.ndarray:
    # Dos monedas que chocan: parciales metálicos inarmónicos.
    out = canvas(0.5)
    coin = ((1, 1.0), (1.47, 0.6), (2.09, 0.4), (2.76, 0.25))
    place(out, tone(2093, 0.35, 0.09, coin), 0.0, 0.35)
    place(out, tone(2637, 0.4, 0.12, coin), 0.07, 0.35)
    place(out, band(noise(0.02), 4000, 10000) * env(0.02, 0.0005, 0.004), 0.0, 0.3)
    place(out, band(noise(0.02), 4000, 10000) * env(0.02, 0.0005, 0.004), 0.07, 0.3)
    return out


def ui_card() -> np.ndarray:
    # Papel que se desliza: ruido con la banda subiendo.
    seconds = 0.16
    n = noise(seconds)
    lo = band(n, 800, 3000)
    hi = band(n, 3000, 9000)
    t = t_axis(seconds) / seconds
    mix = lo * (1 - t) + hi * t
    return mix * env(seconds, 0.02, 0.05) * 1.6


def ui_tick() -> np.ndarray:
    return knock(1400, 0.03, bright=0.5) * 0.7


def sfx_dice() -> np.ndarray:
    # Dados de madera rodando: golpes con intervalos que se acortan y bajan de fuerza.
    out = canvas(0.7)
    at = 0.0
    gap = 0.11
    strength = 1.0
    while at < 0.55 and strength > 0.12:
        freq = rng.uniform(700, 1100)
        place(out, knock(freq, 0.05), at, strength * 0.6)
        if rng.random() < 0.5:
            place(out, knock(rng.uniform(700, 1100), 0.05), at + rng.uniform(0.01, 0.025), strength * 0.4)
        at += gap * rng.uniform(0.7, 1.1)
        gap *= 0.82
        strength *= 0.78
    return out


def sfx_build() -> np.ndarray:
    # Obra que sube: golpe grave, dos martillazos y un brillo ascendente al terminar.
    out = canvas(0.9)
    thump = tone(90, 0.25, 0.07, ((1, 1.0), (1.5, 0.3))) + lowpass(noise(0.25), 400) * env(0.25, 0.001, 0.03)
    place(out, thump, 0.0, 0.8)
    place(out, knock(620, 0.07), 0.14, 0.55)
    place(out, knock(700, 0.07), 0.26, 0.6)
    sparkle = ((1, 1.0), (2, 0.3), (3, 0.1))
    for i, f in enumerate((784, 1047, 1319, 1568)):
        place(out, tone(f, 0.35, 0.1, sparkle), 0.36 + i * 0.05, 0.32)
    return out


def sfx_demolish() -> np.ndarray:
    # Derribo: ruido grave que se desmorona y una nota que cae.
    seconds = 0.7
    rubble = lowpass(noise(seconds), 900) * env(seconds, 0.005, 0.18)
    grains = canvas(seconds)
    for _ in range(14):
        place(grains, knock(rng.uniform(180, 420), 0.05, bright=0.4), rng.uniform(0.02, 0.5), rng.uniform(0.2, 0.45))
    fall = sweep(300, 90, 0.5, 0.2)
    out = rubble * 0.9 + grains
    place(out, fall, 0.0, 0.5)
    return out


def sfx_pact_break() -> np.ndarray:
    # Algo que se parte: chasquido agudo y un tono que baja.
    out = canvas(0.45)
    snap = band(noise(0.04), 2000, 9000) * env(0.04, 0.0005, 0.008)
    place(out, snap, 0.0, 1.0)
    place(out, sweep(700, 180, 0.4, 0.12), 0.01, 0.5)
    return out


def sfx_chime() -> np.ndarray:
    # Aviso suave y brillante: la corona cambia de manos, sube la Furia.
    out = canvas(0.8)
    bell = ((1, 1.0), (2.0, 0.35), (3.01, 0.12))
    place(out, tone(1568, 0.7, 0.25, bell), 0.0, 0.35)
    place(out, tone(2093, 0.7, 0.25, bell), 0.09, 0.3)
    return out


EFFECTS = {
    "ui-press": ui_press,
    "ui-hover": ui_hover,
    "ui-open": ui_open,
    "ui-close": ui_close,
    "ui-confirm": ui_confirm,
    "ui-deny": ui_deny,
    "ui-money": ui_money,
    "ui-card": ui_card,
    "ui-tick": ui_tick,
    "sfx-dice": sfx_dice,
    "sfx-build": sfx_build,
    "sfx-demolish": sfx_demolish,
    "sfx-pact-break": sfx_pact_break,
    "sfx-chime": sfx_chime,
}

# Pico de cada archivo: deja margen para que la mezcla de `AudioDirector` no recorte.
PEAK = 0.7


def fade_tail(signal: np.ndarray, seconds: float = 0.01) -> np.ndarray:
    n = min(len(signal), int(seconds * RATE))
    signal[-n:] *= np.linspace(1, 0, n)
    return signal


def write(name: str, signal: np.ndarray) -> Path:
    signal = fade_tail(signal.astype(np.float64))
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal = signal / peak * PEAK
    data = (signal * 32767).astype("<i2")
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    return path


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in EFFECTS.items():
        path = write(name, make())
        print(f"{path.relative_to(OUT.parent.parent.parent)}  {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
