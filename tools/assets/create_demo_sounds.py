"""Original, deterministic synthesis for prototype feedback (no samples or paid API)."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "Godot/assets/demo/audio"
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050
for index, (name, duration) in enumerate([
    ("cannon", 1.1), ("impact", 0.23), ("splash", 0.6),
    ("swing", 0.16), ("select", 0.08), ("success", 0.65)
]):
    rng = random.Random(300 + index)
    samples = []
    filtered = 0.0
    for i in range(int(RATE * duration)):
        t = i / RATE
        u = t / duration
        noise = rng.uniform(-1, 1)
        filtered = filtered * 0.86 + noise * 0.14
        if name == "cannon":
            value = (filtered * 2.1 + math.sin(2 * math.pi * (80*t - 13*t*t)) * 0.32) * math.exp(-t * 5)
        elif name == "impact":
            value = (noise * 0.32 + math.sin(2 * math.pi * 360 * t) * 0.28) * math.exp(-t * 25)
        elif name == "splash":
            value = filtered * 2.0 * math.sin(math.pi * u) * math.exp(-t * 3)
        elif name == "swing":
            value = noise * 0.22 * math.sin(math.pi * u) ** 2
        elif name == "select":
            value = math.sin(2 * math.pi * 660 * t) * 0.12 * math.sin(math.pi * u) ** 2
        else:
            value = sum(math.sin(2 * math.pi * f * t) for f in (330, 412.5, 495)) * 0.07 * math.sin(math.pi * u)
        samples.append(max(-0.9, min(0.9, value)))
    with wave.open(str(OUT / (name + ".wav")), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b"".join(struct.pack("<h", round(x * 32767)) for x in samples))
print("Created 6 original prototype feedback sounds; no external samples.")
