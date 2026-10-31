"""Synthesizes every sound in Killin' in Comedy (no samples, no downloads).

Run from the project root:  python3 tools/make_audio.py
Writes short sound effects as WAV and the lounge music loop as OGG (via
ffmpeg) into audio/. Needs numpy and ffmpeg.
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- helpers

def note(n):
    """MIDI note number -> frequency."""
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return RNG.uniform(-1, 1, int(SR * dur))


def decay(dur, tau, attack=0.002):
    t = t_axis(dur)
    e = np.exp(-t / tau)
    a = int(SR * attack)
    if a:
        e[:a] *= np.linspace(0, 1, a)
    e[-64:] *= np.linspace(1, 0, 64)
    return e


def shape(sig, peaks, floor=0.03):
    """Filter by multiplying the spectrum with gaussian bumps (center, width, gain)."""
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    h = np.full(len(f), floor)
    for fc, bw, g in peaks:
        h += g * np.exp(-0.5 * ((f - fc) / bw) ** 2)
    return np.fft.irfft(spec * h, len(sig))


def highpass(sig, cutoff):
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    return np.fft.irfft(spec * (1 / (1 + (cutoff / np.maximum(f, 1)) ** 4)), len(sig))


def reverb(sig, mix=0.25, length=0.5, tau=0.12):
    ir = noise(length) * np.exp(-t_axis(length) / tau)
    n = len(sig) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(sig, n) * np.fft.rfft(ir, n), n)
    wet /= max(1e-9, np.max(np.abs(wet))) / max(1e-9, np.max(np.abs(sig)))
    out = np.concatenate([sig, np.zeros(len(ir))]) + wet * mix
    return out


def place(mix, sig, start, gain=1.0):
    i = int(round(start * SR))
    j = min(i + len(sig), len(mix))
    if i < len(mix):
        mix[i:j] += sig[: j - i] * gain


def normalize(sig, peak=0.9):
    return sig * (peak / max(1e-9, np.max(np.abs(sig))))


def write_wav(name, data, peak=0.9):
    data = np.clip(normalize(data, peak), -1, 1)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32000).astype("<i2").tobytes())
    return path


def harmonics(freqs, count, tilt=1.0):
    """Buzzy voiced source from a per-sample frequency array."""
    phase = np.cumsum(freqs) / SR
    out = np.zeros(len(freqs))
    for h in range(1, count + 1):
        out += np.sin(2 * np.pi * h * phase) / h ** tilt
    return out


# ---------------------------------------------------------------- crowd

VOWELS = {
    "ha": [(750, 120, 1.0), (1150, 160, 0.6), (2600, 300, 0.2)],
    "heh": [(550, 110, 1.0), (1800, 220, 0.5), (2600, 300, 0.2)],
    "ho": [(560, 100, 1.0), (850, 140, 0.6), (2500, 300, 0.15)],
}


def laugh_voice(dur, f0, rate, start):
    n = int(SR * dur)
    env = np.zeros(n)
    t0, amp = start, RNG.uniform(0.7, 1.0)
    while t0 < dur - 0.2 and amp > 0.15:
        pulse = decay(0.16, 0.06, attack=0.012) * amp
        place(env, pulse, t0)
        t0 += (1 / rate) * RNG.uniform(0.85, 1.15)
        amp *= RNG.uniform(0.82, 0.97)
    f = f0 * np.linspace(1.12, 0.88, n) * (1 + 0.04 * np.sin(2 * np.pi * rate * t_axis(dur)))
    src = harmonics(f, 14) * 0.7 + noise(dur) * 0.45
    vowel = VOWELS[RNG.choice(list(VOWELS))]
    return shape(src * env, vowel)


def crowd_laugh(voices, dur):
    mix = np.zeros(int(SR * dur))
    for v in range(voices):
        f0 = RNG.uniform(105, 290)
        rate = RNG.uniform(4.2, 6.8)
        start = 0.0 if v < 2 else RNG.uniform(0, 0.2)  # first laughs land instantly
        mix += laugh_voice(dur, f0, rate, start) * RNG.uniform(0.5, 1.0)
    mix += shape(noise(dur), [(900, 600, 0.3)]) * 0.05 * decay(dur, dur / 2)
    return reverb(mix, 0.3)


def applause(dur, density):
    claps = [shape(noise(0.012), [(RNG.uniform(900, 2600), 700, 1.0)]) * decay(0.012, 0.004, 0.0005)
             for _ in range(16)]
    mix = np.zeros(int(SR * dur))
    t = 0.0
    while t < dur - 0.02:
        x = t / dur
        level = min(1.0, x / 0.12) * (1.0 if x < 0.55 else max(0.0, (1 - x) / 0.45))
        place(mix, claps[RNG.integers(len(claps))], t, RNG.uniform(0.3, 1.0) * level)
        t += RNG.exponential(1 / density)
    return reverb(mix, 0.35, 0.6, 0.15)


def crickets(dur):
    mix = shape(noise(dur), [(300, 200, 0.2)]) * 0.01
    for pitch, offset in ((4300, 0.05), (4650, 0.38)):
        g = offset
        while g < dur - 0.4:
            for k in range(3):
                t = t_axis(0.07)
                chirp = np.sin(2 * np.pi * pitch * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 45 * t))
                place(mix, chirp * decay(0.07, 0.03, 0.005), g + k * 0.11, 0.35)
            g += RNG.uniform(0.55, 0.75)
    return mix


def groan(dur=1.3, voices=9):
    mix = np.zeros(int(SR * dur))
    for _ in range(voices):
        f0 = RNG.uniform(95, 230)
        n = len(mix)
        f = f0 * np.linspace(1.05, 0.78, n)
        env = np.minimum(1, t_axis(dur) / 0.12) * np.exp(-t_axis(dur) / 0.7)
        src = (harmonics(f, 12) * 0.7 + noise(dur) * 0.25) * env
        place(mix, shape(src, VOWELS["ho"]), RNG.uniform(0, 0.12), RNG.uniform(0.5, 1.0))
    return reverb(mix, 0.3)


# ---------------------------------------------------------------- instruments

def brass(midi, dur, vibrato=0.0, wah=(450, 1600)):
    t = t_axis(dur)
    f = note(midi) * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.4))
    cutoff = np.interp(t, [0, min(0.15, dur / 2), dur], [wah[0], wah[1], wah[1] * 0.7])
    phase = np.cumsum(f) / SR
    out = np.zeros(len(t))
    for h in range(1, 12):
        out += np.sin(2 * np.pi * h * phase) / h ** 0.8 / (1 + (h * f / cutoff) ** 4)
    env = np.minimum(1, t / 0.03) * np.minimum(1, (dur - t) / 0.08)
    return out * env


def tom(f0, f1, dur=0.18):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * np.cumsum(np.geomspace(f0, f1, len(t))) / SR)
    return (s + noise(dur) * 0.15) * decay(dur, 0.07)


def cymbal(dur, tau):
    metal = sum(np.sin(2 * np.pi * f * t_axis(dur)) for f in (3150, 4420, 5310, 6870, 8120))
    return (highpass(noise(dur), 5000) * 0.8 + metal * 0.08) * decay(dur, tau, 0.001)


def snare(dur=0.18):
    body = np.sin(2 * np.pi * 190 * t_axis(dur)) * decay(dur, 0.04)
    return body * 0.5 + shape(noise(dur), [(3000, 1500, 1.0)]) * decay(dur, 0.06, 0.001)


def keys(midi, dur):
    """Electric-piano-ish tone: sine + bell partials + tremolo."""
    t = t_axis(dur)
    f = note(midi)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t / 0.15) \
        + 0.08 * np.sin(2 * np.pi * 7.1 * f * t) * np.exp(-t / 0.03)
    return tone * (1 + 0.12 * np.sin(2 * np.pi * 4.8 * t)) * decay(dur, 0.8, 0.004)


def bass(midi, dur):
    t = t_axis(dur)
    f = note(midi)
    tone = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)
    return tone * decay(dur, 0.35, 0.008)


# ---------------------------------------------------------------- sounds

def make_sfx():
    write_wav("laugh_small", crowd_laugh(5, 1.6), 0.7)
    write_wav("laugh_big", crowd_laugh(12, 2.2), 0.85)
    write_wav("laugh_huge", crowd_laugh(22, 3.0) + np.pad(applause(3.0, 60), (0, int(SR * 0.5)))[: int(SR * 3.5)] * 0.4, 0.9)
    write_wav("applause", applause(3.2, 140), 0.85)
    write_wav("cheer", applause(1.2, 90), 0.6)
    write_wav("crickets", crickets(2.0), 0.5)
    write_wav("groan", groan(), 0.7)

    rim = np.zeros(int(SR * 1.2))
    place(rim, tom(210, 170), 0.0, 0.8)
    place(rim, tom(150, 120), 0.15, 0.8)
    place(rim, snare(), 0.32, 0.7)
    place(rim, cymbal(0.85, 0.3), 0.32, 0.6)
    write_wav("rimshot", rim, 0.8)

    trombone = np.zeros(int(SR * 2.6))
    for i, (m, d) in enumerate([(58, 0.38), (57, 0.38), (56, 0.38), (55, 1.4)]):
        place(trombone, brass(m, d, vibrato=0.025 if i == 3 else 0.0, wah=(350, 1300)), i * 0.4)
    write_wav("sad_trombone", reverb(trombone, 0.2), 0.75)

    fanfare = np.zeros(int(SR * 1.8))
    for i, (m, d) in enumerate([(60, 0.14), (64, 0.14), (67, 0.14), (72, 0.9)]):
        place(fanfare, brass(m, d, vibrato=0.01 if i == 3 else 0.0), i * 0.15)
        if i == 3:
            place(fanfare, brass(64, d) * 0.6 + brass(67, d) * 0.6, i * 0.15)
    write_wav("fanfare", reverb(fanfare, 0.2), 0.75)

    t = t_axis(0.06)
    write_wav("click", (np.sin(2 * np.pi * 950 * t) + 0.4 * np.sin(2 * np.pi * 1900 * t)) * decay(0.06, 0.012, 0.0005), 0.45)
    flick = shape(noise(0.07), [(3200, 1800, 1.0)]) * decay(0.07, 0.015, 0.001)
    flick[: int(SR * 0.03)] += np.sin(2 * np.pi * 140 * t_axis(0.03)) * decay(0.03, 0.01) * 0.6
    write_wav("card", flick, 0.5)
    t = t_axis(1.2)
    bell = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((1046.5, 1.0), (1568, 0.6), (2093, 0.35), (2960, 0.15)))
    write_wav("chime", bell * decay(1.2, 0.35), 0.5)
    thump = np.sin(2 * np.pi * np.cumsum(np.geomspace(120, 55, int(SR * 0.16))) / SR) * decay(0.16, 0.05)
    thump += shape(noise(0.16), [(400, 300, 1.0)]) * decay(0.16, 0.02) * 0.4
    write_wav("thump", thump, 0.6)

    # Casino sounds. Pure tones only (no RNG), so every other sound stays identical.
    def bell_tone(f0, dur, tau):
        t = t_axis(dur)
        b = sum(np.sin(2 * np.pi * f0 * k * t) * a for k, a in ((1, 1.0), (2.0, 0.45), (3.01, 0.2), (4.2, 0.1)))
        return b * decay(dur, tau, 0.001)
    # Slot-machine ding: bright and short, made to repeat fast and pitch up.
    write_wav("ding", bell_tone(1760, 0.32, 0.09) + 0.5 * bell_tone(2637, 0.32, 0.06), 0.55)
    # Coin clink: two tiny metallic hits.
    coin = np.zeros(int(SR * 0.16))
    place(coin, bell_tone(3520, 0.1, 0.025), 0.0, 1.0)
    place(coin, bell_tone(4186, 0.1, 0.02), 0.045, 0.7)
    write_wav("coin", coin, 0.45)
    # Jackpot: a rising run of dings that rings out.
    jack = np.zeros(int(SR * 1.4))
    for i, m in enumerate([72, 76, 79, 84, 88, 91, 96]):
        place(jack, bell_tone(note(m), 0.6, 0.18), i * 0.07, 0.8)
    place(jack, bell_tone(note(96), 0.9, 0.3), 0.5, 0.6)
    write_wav("jackpot", reverb(jack, 0.15), 0.7)


def make_music():
    """8 bars of swinging lounge jazz in Bb, looping."""
    bpm = 96
    beat = 60 / bpm
    swing = beat * 2 / 3
    bars = 8
    total = int(round(SR * beat * 4 * bars))
    mix = np.zeros(total + SR)  # one extra second for ringing notes

    walking = [
        [36, 38, 39, 43], [41, 45, 48, 47], [46, 45, 43, 41], [43, 46, 50, 49],
        [48, 46, 43, 39], [41, 43, 45, 47], [46, 50, 53, 50], [43, 47, 50, 37],
    ]
    chords = [
        [63, 67, 70, 74], [63, 69, 72, 75], [62, 65, 69, 72], [65, 70, 74, 77],
        [63, 67, 70, 74], [63, 69, 72, 75], [62, 65, 69, 72], [65, 71, 75, 77],
    ]
    for bar in range(bars):
        t_bar = bar * beat * 4
        for k, m in enumerate(walking[bar]):
            place(mix, bass(m, beat * 0.95), t_bar + k * beat, 0.5)
        # Comping: on 1, and the swung "and" of 2 (every other bar).
        hits = [0.0, beat + swing] if bar % 2 == 0 else [beat * 2 + swing]
        for h in hits:
            for m in chords[bar]:
                place(mix, keys(m, beat * 1.6), t_bar + h, 0.09)
        # Ride: ding, ding-a ding, ding-a.
        for k in range(4):
            place(mix, cymbal(0.5, 0.18), t_bar + k * beat, 0.05 if k % 2 == 0 else 0.07)
            if k % 2 == 1:
                place(mix, cymbal(0.3, 0.1), t_bar + k * beat + swing, 0.04)
        # Brushes on 2 and 4.
        for k in (1, 3):
            brush = shape(noise(0.25), [(2500, 1500, 1.0)]) * decay(0.25, 0.08, 0.02)
            place(mix, brush, t_bar + k * beat, 0.08)

    # Fold the ringing tail of the last bar back onto the start: seamless loop.
    tail = mix[total:]
    mix = mix[:total]
    mix[: len(tail)] += tail
    wav = write_wav("music_tmp", mix, 0.8)
    ogg = os.path.join(OUT, "music.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", ogg], check=True)
    os.remove(wav)


# ---------------------------------------------------------------- office

def make_office():
    """The 3D office: an air-conditioner room tone (seamless OGG loop) and
    soft footsteps on carpet. Own random generator, so adding these leaves
    every sound above byte-for-byte the same."""
    rng = np.random.default_rng(31)
    loop = 12.0  # every rate below fits a whole number of cycles in 12 s
    n = int(SR * loop)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1 / SR)

    def colored(gain_fn):
        # Noise shaped in one FFT over the whole loop is circular: the end
        # flows straight back into the start with no click.
        spec = np.fft.rfft(rng.standard_normal(n)) * gain_fn(np.maximum(f, 1.0))
        out = np.fft.irfft(spec, n)
        return out / np.max(np.abs(out))

    # Air rushing through the duct: brown-ish rumble rolling off above ~500 Hz.
    rumble = colored(lambda x: 1 / np.sqrt(x) / (1 + (x / 500) ** 2) * (x > 25))
    # Breathy hiss out of the vent grille.
    hiss = colored(lambda x: np.exp(-0.5 * ((x - 3200) / 1400) ** 2) + 0.4 * np.exp(-0.5 * ((x - 1200) / 500) ** 2))
    # Fan blades chopping the air (8 Hz) and a slow breathing drift (every 6 s / 12 s).
    chop = 1 + 0.06 * np.sin(2 * np.pi * 8 * t) + 0.03 * np.sin(2 * np.pi * 16 * t + 1.0)
    drift = 1 + 0.07 * np.sin(2 * np.pi * t / 6) + 0.05 * np.sin(2 * np.pi * t / 12 + 2.0)
    # Compressor motor hum: 60 Hz mains and its harmonics, quiet and wavering.
    wobble = 1 + 0.15 * np.sin(2 * np.pi * 0.25 * t)
    hum = (np.sin(2 * np.pi * 60 * t) * 0.5 + np.sin(2 * np.pi * 120 * t) * 0.35
           + np.sin(2 * np.pi * 180 * t) * 0.12 + np.sin(2 * np.pi * 240 * t) * 0.06) * wobble
    ac = rumble * 0.75 * chop * drift + hiss * 0.18 * drift + hum * 0.09
    wav = write_wav("office_ac_tmp", ac, 0.7)
    ogg = os.path.join(OUT, "office_ac.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", ogg], check=True)
    os.remove(wav)

    # Footsteps on office carpet: a padded heel thud, a fabric scuff, then the
    # lighter roll onto the toe. Four takes so walking never sounds looped.
    def burst(dur):
        return rng.uniform(-1, 1, int(SR * dur))

    for k in range(4):
        dur = 0.32
        step = np.zeros(int(SR * dur))
        f0 = rng.uniform(70, 95)
        th = t_axis(0.12)
        heel = np.sin(2 * np.pi * (f0 * th + 20 * np.exp(-th / 0.02))) * decay(0.12, 0.028, 0.004)
        heel += shape(burst(0.12), [(160, 90, 1.0)], 0.0) * decay(0.12, 0.02, 0.003) * 0.6
        place(step, heel, 0.0, 1.0)
        scuff = shape(burst(0.09), [(rng.uniform(1600, 2400), 900, 1.0), (500, 250, 0.4)], 0.0)
        scuff *= np.sin(np.linspace(0, np.pi, len(scuff))) ** 2
        place(step, scuff, rng.uniform(0.005, 0.02), rng.uniform(0.18, 0.28))
        toe = shape(burst(0.08), [(240, 120, 1.0), (1400, 700, 0.3)], 0.0) * decay(0.08, 0.018, 0.004)
        place(step, toe, rng.uniform(0.065, 0.095), rng.uniform(0.35, 0.5))
        write_wav("step_%d" % (k + 1), reverb(step, 0.08, 0.25, 0.05), 0.6)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sfx()
    make_music()
    make_office()
    for f in sorted(os.listdir(OUT)):
        if not f.endswith(".import"):
            print(f"{f:20s} {os.path.getsize(os.path.join(OUT, f)) // 1024} KB")
