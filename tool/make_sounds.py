"""Synthesise the app's sound cues as 16-bit mono WAVs into argv[1].

work.wav       bright rising two-note chime  -> "go!"
rest.wav       soft falling two-note chime   -> "breathe"
finish.wav     major arpeggio                -> "done"
countdown.wav  short high pip for 3-2-1
silence.wav    2 s of silence, looped to keep the app alive in the background

Run from the project root:
  python3 tool/make_sounds.py assets/sounds
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)


def chime(freq, length, tau, partials, attack=0.004):
    """Additive bell: (ratio, amplitude, decay multiplier) per partial."""
    t = np.arange(int(SR * length)) / SR
    sig = np.zeros_like(t)
    for ratio, amp, decay in partials:
        sig += amp * np.exp(-t * decay / tau) * np.sin(2 * np.pi * freq * ratio * t)
    env = np.minimum(1, t / attack)
    return sig * env


def mix(length, notes):
    buf = np.zeros(int(SR * length))
    for start, sig in notes:
        i = int(SR * start)
        n = min(len(sig), len(buf) - i)
        buf[i : i + n] += sig[:n]
    return buf


def save(name, sig, peak):
    loudest = np.abs(sig).max()
    if loudest:
        sig = sig / loudest * peak
    # 5 ms fade-out so the file never ends on a click.
    fade = int(SR * 0.005)
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype("<i2").tobytes()
    with wave.open(str(out / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(name, f"{len(sig) / SR:.2f}s")


BRIGHT = [(1, 1.0, 1.0), (2.0, 0.55, 1.8), (3.0, 0.3, 2.6), (4.07, 0.18, 3.4)]
SOFT = [(1, 1.0, 1.0), (2.0, 0.22, 2.0), (3.0, 0.06, 3.0)]

C5, E5, G5, C6, G6 = 523.25, 659.25, 783.99, 1046.5, 1567.98

work = mix(1.0, [
    (0.00, chime(C6, 0.5, 0.18, BRIGHT)),
    (0.11, chime(G6, 0.9, 0.38, BRIGHT)),
])
save("work.wav", work, 0.89)

rest = mix(1.6, [
    (0.00, chime(G5, 1.0, 0.55, SOFT, attack=0.012)),
    (0.22, chime(C5, 1.4, 0.75, SOFT, attack=0.012)),
])
save("rest.wav", rest, 0.80)

finish = mix(2.2, [
    (0.00, chime(C5, 0.6, 0.30, BRIGHT)),
    (0.12, chime(E5, 0.6, 0.30, BRIGHT)),
    (0.24, chime(G5, 0.6, 0.30, BRIGHT)),
    (0.36, chime(C6, 1.8, 0.80, BRIGHT)),
])
save("finish.wav", finish, 0.89)

pip = chime(1318.51, 0.14, 0.035, [(1, 1.0, 1.0), (2.76, 0.25, 2.0)], attack=0.002)
save("countdown.wav", pip, 0.55)

save("silence.wav", np.zeros(SR * 2), 0)
