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


def make_look_busy():
    """Look Busy (the office's boss): the door creak, a coworker's warning
    cough, the busted sting, a video call ringing and the 5 PM bell. Own
    random generator, so every sound above stays byte-for-byte the same."""
    rng = np.random.default_rng(57)

    def burst(dur):
        return rng.uniform(-1, 1, int(SR * dur))

    # Door creak: a slow, stuttering hinge squeal sliding down in pitch.
    dur = 1.1
    t = t_axis(dur)
    f = 520 * np.exp(-t * 0.6) + 40 * np.sin(2 * np.pi * 3 * t)
    stutter = 0.6 + 0.4 * (np.sin(2 * np.pi * 23 * t) > -0.2)
    creak = harmonics(f, 8, 0.8) * stutter * np.sin(np.linspace(0, np.pi, len(t))) ** 0.6
    creak = shape(creak, [(900, 400, 1.0), (2200, 700, 0.5)], 0.05)
    creak += shape(burst(dur), [(3000, 1500, 1.0)], 0.0) * 0.06
    write_wav("creak", reverb(creak, 0.15, 0.3, 0.08), 0.6)

    # Cough: two breathy bursts with a voiced edge.
    cough = np.zeros(int(SR * 0.7))
    for start, f0 in ((0.0, 190), (0.28, 170)):
        d = 0.2
        voiced = harmonics(np.full(int(SR * d), f0), 10, 1.2)
        air = shape(burst(d), [(700, 300, 1.0), (1700, 500, 0.6), (2600, 600, 0.3)], 0.02)
        place(cough, (air * 0.9 + voiced * 0.25) * decay(d, 0.06, 0.004), start)
    write_wav("cough", reverb(cough, 0.1, 0.2, 0.05), 0.7)

    # Busted: a stabbing brass "dun dun DUN".
    busted = np.zeros(int(SR * 1.6))
    for i, (m, d) in enumerate([(55, 0.16), (54, 0.16), (49, 1.0)]):
        place(busted, brass(m, d, vibrato=0.02 if i == 2 else 0.0, wah=(500, 1400)) + 0.6 * brass(m - 12, d), i * 0.2)
    write_wav("busted", reverb(busted, 0.2), 0.8)

    # A 90s office phone ring (one ring; the game repeats it).
    t = t_axis(0.9)
    tone = np.sin(2 * np.pi * 440 * t) + np.sin(2 * np.pi * 480 * t)
    trill = (np.sin(2 * np.pi * 20 * t) > 0).astype(float)
    ring = tone * trill * np.where(t < 0.8, 1.0, 0.0)
    ring[-200:] *= np.linspace(1, 0, 200)
    write_wav("ring", ring, 0.4)

    # The 5 PM bell: two warm strikes.
    t = t_axis(1.6)
    def strike(f0):
        return sum(np.sin(2 * np.pi * f0 * k * t) * a for k, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.15))) * decay(1.6, 0.5)
    bell = strike(note(76))
    place(bell, strike(note(72))[: int(SR * 1.2)], 0.4, 0.8)
    write_wav("bell", bell, 0.55)


def make_lift():
    """The ladder's elevators: the arrival chime, the motor hum of a ride and
    the doors sliding. Own random generator, after everything else, so every
    sound above stays byte-for-byte the same."""
    rng = np.random.default_rng(91)

    def burst(dur):
        return rng.uniform(-1, 1, int(SR * dur))

    # Arrival chime: a soft two-note bell, high then low (ding-dong).
    def strike(f0, dur):
        t = t_axis(dur)
        return sum(np.sin(2 * np.pi * f0 * k * t) * a for k, a in ((1, 1.0), (2.0, 0.3), (3.0, 0.12))) * decay(dur, 0.35, 0.003)
    chime = np.zeros(int(SR * 1.3))
    place(chime, strike(note(81), 0.9), 0.0)
    place(chime, strike(note(77), 1.0), 0.32, 0.9)
    write_wav("lift_ding", chime, 0.5)

    # The ride: a low motor hum that spins up, holds and settles (2.4 s; the
    # game stops it early on short rides).
    dur = 2.4
    t = t_axis(dur)
    env = np.clip(t / 0.35, 0, 1) * np.clip((dur - t) / 0.5, 0, 1)
    f = 58 + 6 * np.clip(t / 0.4, 0, 1)
    hum = harmonics(f, 6, 1.4) * 0.8
    hum += shape(burst(dur), [(180, 120, 1.0), (520, 200, 0.3)], 0.0) * 0.5
    hum *= 1 + 0.08 * np.sin(2 * np.pi * 7 * t)
    write_wav("lift_hum", hum * env, 0.45)

    # Doors: a short rumbling slide with a soft bump at the end.
    dur = 0.6
    t = t_axis(dur)
    slide = shape(burst(dur), [(300, 200, 1.0), (900, 300, 0.25)], 0.0) * np.sin(np.linspace(0, np.pi, len(t))) ** 0.8
    bump = np.zeros(len(t))
    place(bump, np.sin(2 * np.pi * 70 * t_axis(0.12)) * decay(0.12, 0.03), 0.48)
    write_wav("lift_doors", slide * 0.7 + bump, 0.4)


def make_rage():
    """The Rage Cage on the trading floor: a sledgehammer crunching plastic
    and a CRT's glass shattering. Own random generator, after everything else,
    so every sound above stays byte-for-byte the same."""
    rng = np.random.default_rng(404)

    def burst(dur):
        return rng.uniform(-1, 1, int(SR * dur))

    # Smash: a low body thud, then a crackle of breaking plastic.
    dur = 0.55
    smash = np.sin(2 * np.pi * np.cumsum(np.geomspace(140, 45, int(SR * dur))) / SR) * decay(dur, 0.09) * 0.9
    crack = shape(burst(dur), [(900, 500, 1.0), (2600, 900, 0.6)], 0.0)
    grains = (rng.uniform(0, 1, len(crack)) > 0.985).astype(float)
    smash += crack * decay(dur, 0.07, 0.001) * 0.6
    smash += shape(grains * burst(dur), [(1800, 1200, 1.0)], 0.0) * decay(dur, 0.18) * 1.4
    write_wav("rage_smash", smash, 0.75)

    # Shatter: a bright burst of glass, then tinkling pieces landing.
    dur = 1.1
    shatter = highpass(burst(dur), 2500) * decay(dur, 0.06, 0.001) * 0.8
    for i in range(14):
        f0 = rng.uniform(2800, 6200)
        d = rng.uniform(0.08, 0.25)
        t = t_axis(d)
        ping = sum(np.sin(2 * np.pi * f0 * k * t) * a for k, a in ((1, 1.0), (1.47, 0.5), (2.09, 0.25))) * decay(d, d * 0.3, 0.001)
        place(shatter, ping, rng.uniform(0.02, 0.85), rng.uniform(0.15, 0.4))
    write_wav("rage_shatter", reverb(shatter, 0.15, 0.4, 0.08), 0.6)



# ---------------------------------------------------------------- office jazz

# The office's own soundtrack: vintage 8-bit jazz, played like a 90s console
# would. Two pulse waves (lead + comping arpeggios), a 4-bit stepped triangle
# walking bass and LFSR noise drums. Written at its own sample rate with its
# own random generator, so every sound above stays byte-for-byte the same.
#   office_title.ogg  "Clock-In Ballad": slow, warm, a little vinyl crackle
#                     (the Look Busy title screen).
#   office_jazz.ogg   "Golden Hour Shuffle": the swinging loop you walk around
#                     to (head, a solo chorus, the head out; ~2 minutes).

JSR = 32000

# Chord qualities -> intervals (chord tones, then the scale a line can use).
QUAL = {
    "maj7": ([0, 4, 7, 11], [0, 2, 4, 7, 9, 11]),
    "6": ([0, 4, 7, 9], [0, 2, 4, 7, 9]),
    "m7": ([0, 3, 7, 10], [0, 2, 3, 5, 7, 9, 10]),
    "m6": ([0, 3, 7, 9], [0, 2, 3, 5, 7, 9]),
    "7": ([0, 4, 7, 10], [0, 2, 4, 5, 7, 9, 10]),
}
PC = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def _jt(dur):
    return np.arange(int(JSR * dur)) / JSR


def _blep(ph, dt):
    """PolyBLEP: rounds off a hard edge so high pulses don't alias."""
    out = np.zeros_like(ph)
    a = ph < dt
    x = ph[a] / dt[a]
    out[a] = 2 * x - x * x - 1
    b = ph > 1 - dt
    x = (ph[b] - 1) / dt[b]
    out[b] = x * x + 2 * x + 1
    return out


def chip_pulse(midi, dur, duty=0.25, vib=0.0, vib_delay=0.25):
    n = int(JSR * dur)
    t = np.arange(n) / JSR
    f = np.full(n, note(midi))
    if vib:
        ramp = np.clip((t - vib_delay) / 0.3, 0, 1)
        f *= 1 + vib * ramp * np.sin(2 * np.pi * 5.6 * t)
    dt = f / JSR
    ph = np.cumsum(dt) % 1.0
    sig = np.where(ph < duty, 1.0, -1.0) + _blep(ph, dt) - _blep((ph - duty) % 1.0, dt)
    return sig - np.mean(sig)


def chip_tri(midi, dur):
    """The console triangle: 16 volume steps, no volume control (on/off only)."""
    n = int(JSR * dur)
    ph = (np.arange(n) * note(midi) / JSR) % 1.0
    tri = 1 - 4 * np.abs(ph - 0.5)
    return np.round((tri + 1) * 7.5) / 7.5 - 1


def _lfsr(short, steps):
    reg, out = 1, np.empty(steps)
    tap = 6 if short else 1
    for i in range(steps):
        bit = (reg ^ (reg >> tap)) & 1
        reg = (reg >> 1) | (bit << 14)
        out[i] = 1.0 if reg & 1 else -1.0
    return out


_LFSR_LONG = None
_LFSR_SHORT = None


def chip_noise(dur, clock, short=False):
    """Noise channel: an LFSR stepped `clock` times a second. Short mode loops
    93 steps, which rings metallic (the ride cymbal)."""
    global _LFSR_LONG, _LFSR_SHORT
    if _LFSR_LONG is None:
        _LFSR_LONG = _lfsr(False, 32767)
        _LFSR_SHORT = _lfsr(True, 93)
    seq = _LFSR_SHORT if short else _LFSR_LONG
    n = int(JSR * dur)
    idx = (np.arange(n) * clock / JSR).astype(int) % len(seq)
    return seq[idx]


def _env(n, attack=0.004, release=0.03, decay_to=1.0, decay_t=0.3):
    t = np.arange(n) / JSR
    e = decay_to + (1 - decay_to) * np.exp(-t / max(decay_t, 1e-4))
    a = max(1, int(JSR * attack))
    e[:a] *= np.linspace(0, 1, a)
    r = min(n, max(1, int(JSR * release)))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def _jplace(mix, sig, start, gain=1.0):
    i = int(round(start * JSR))
    j = min(i + len(sig), len(mix))
    if 0 <= i < len(mix):
        mix[i:j] += sig[: j - i] * gain


def _lowpass(sig, cutoff):
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1 / JSR)
    return np.fft.irfft(spec / np.sqrt(1 + (f / cutoff) ** 4), len(sig))


def _echo(sig, delay, fb=0.3, mix=0.2, taps=4):
    out = sig.copy()
    d = int(JSR * delay)
    for k in range(1, taps + 1):
        if d * k >= len(sig):
            break
        out[d * k:] += sig[:-d * k] * mix * fb ** (k - 1)
    return out


class _Clock:
    """Bars and beats -> seconds, with swung off-beat eighths."""

    def __init__(self, bpm, swing):
        self.beat = 60 / bpm
        self.swing = swing

    def at(self, bar, b):
        whole = np.floor(b + 1e-9)
        frac = b - whole
        if abs(frac - 0.5) < 1e-6:
            frac = self.swing
        return (bar * 4 + whole + frac) * self.beat

    def span(self, bar, b, dur):
        return self.at(bar, b + dur) - self.at(bar, b)


def _tones(chord, low, high, ext=()):
    root, q = chord
    ivs = QUAL[q][0] + list(ext)
    return sorted(m for m in range(low, high + 1) if (m - root) % 12 in [i % 12 for i in ivs])


def _scale(chord, low, high):
    root, q = chord
    return [m for m in range(low, high + 1) if (m - root) % 12 in QUAL[q][1]]


def _ch(s):
    """'Gm7' -> (pitch class, quality)."""
    for name in sorted(PC, key=len, reverse=True):
        if s.startswith(name):
            q = s[len(name):] or "maj7"
            q = {"m": "m7"}.get(q, q)
            return (PC[name], q)
    raise ValueError(s)


def _walk(changes, rng, low=36, high=50):
    """A walking bass line: root on the chord's first beat, chord and scale
    tones between, a chromatic step into every new chord."""
    beats = []
    for bar in changes:
        for half in (bar[0], bar[0], bar[1], bar[1]):
            beats.append(half)
    line, prev = [], 41
    for i, ch in enumerate(beats):
        nxt = beats[(i + 1) % len(beats)]
        first = i == 0 or beats[i - 1] != ch
        last = nxt != ch
        if first:
            roots = [m for m in range(low, high + 1) if m % 12 == ch[0]]
            m = min(roots, key=lambda r: abs(r - prev) + (0 if 39 <= r <= 47 else 6))
        elif last:
            roots = [m for m in range(low, high + 1) if m % 12 == nxt[0]]
            target = min(roots, key=lambda r: abs(r - prev))
            m = target + (1 if rng.random() < 0.5 else -1)
            if m == prev:
                m = target + (1 if m < target else -1) * -1
        else:
            pool = [x for x in _tones(ch, low, high) + _scale(ch, low, high) if 0 < abs(x - prev) <= 5]
            m = int(rng.choice(pool)) if pool else prev + 2
        line.append(int(np.clip(m, low, high)))
        prev = line[-1]
    return line


def _solo(changes, rng, low=62, high=86):
    """An improvised-sounding bebop chorus: eighth-note lines that land on
    chord tones on the beat, approach the next chord chromatically, and
    breathe in two-bar phrases."""
    notes, cur, direction = [], 72, 1
    bars = len(changes)
    bar = 0
    while bar < bars:
        length = 2 if rng.random() < 0.6 else 1
        start = 0.5 if rng.random() < 0.5 else 0.0
        if rng.random() < 0.25:
            start += 1.0
        b = bar * 4 + start
        end = min(bars, bar + length) * 4 - (1.0 + rng.integers(0, 3) * 0.5)
        while b < end - 0.4:
            whole = int(b // 4)
            beat = b - whole * 4
            ch = changes[whole][0 if beat < 2 else 1]
            nb = b + 0.5
            nbar, nbeat = int(nb // 4), nb - int(nb // 4) * 4
            nch = changes[nbar % bars][0 if nbeat < 2 else 1]
            if nch != ch and abs(nbeat - round(nbeat)) < 1e-6:
                # Chromatic approach into the next chord's nearest chord tone.
                tgt = min(_tones(nch, low, high), key=lambda m: abs(m - cur))
                m = tgt + (-1 if direction > 0 else 1)
            elif abs(beat - round(beat)) < 1e-6:
                pool = [m for m in _tones(ch, low, high, (14,)) if 0 < (m - cur) * direction <= 5]
                m = pool[0] if direction > 0 and pool else (pool[-1] if pool else cur + direction * 2)
            else:
                pool = [m for m in _scale(ch, low, high) if 0 < (m - cur) * direction <= 3]
                m = (pool[0] if direction > 0 else pool[-1]) if pool else cur + direction
            if m >= high - 2 or m <= low + 2 or rng.random() < 0.18:
                direction = -direction
            m = int(np.clip(m, low, high))
            if rng.random() < 0.08 and beat % 1 == 0 and b + 1 < end:
                notes.append((b, 1.0, m))
                b += 1.0
            else:
                notes.append((b, 0.5, m))
                b += 0.5
            cur = m
        # Land the phrase on a long chord tone (3rd or 7th).
        whole = min(int(b // 4), bars - 1)
        beat = b - whole * 4
        ch = changes[whole][0 if beat < 2 else 1]
        guide = [m for m in range(low, high + 1) if (m - ch[0]) % 12 in (QUAL[ch[1]][0][1], QUAL[ch[1]][0][3])]
        land = min(guide, key=lambda m: abs(m - cur))
        notes.append((b, 1.0 if rng.random() < 0.6 else 1.5, land))
        cur = land
        bar += length
    return notes


def _render(spec):
    """Mixes one tune from its spec. Returns the looping mix (tail folded in)."""
    clk = spec["clock"]
    changes = spec["changes"]
    bars = len(changes)
    total = int(round(clk.at(bars, 0) * JSR))
    mix = np.zeros(total + JSR * 3)
    lead = np.zeros_like(mix)

    # Lead melody (pulse 1).
    for bar_off, notes, duty, gain in spec["lead"]:
        for b, dur, m in notes:
            bar = bar_off + int(b // 4)
            bt = b - int(b // 4) * 4
            t0 = clk.at(bar, bt)
            length = clk.span(bar, bt, dur) * (0.94 if dur >= 1 else 0.82)
            sig = chip_pulse(m, length, duty, vib=0.006 if dur >= 1 else 0.0, vib_delay=0.18)
            env = _env(len(sig), 0.004, 0.035, 0.72, 0.18)
            _jplace(lead, sig * env, t0, gain)
    mix += _echo(lead, clk.beat * 0.75, 0.35, spec.get("echo", 0.22))

    # Walking (or half-note) bass on the triangle.
    rng = spec["rng"]
    if spec["bass"] == "walk":
        line = _walk(changes, rng)
        for i, m in enumerate(line):
            bar, bt = divmod(i, 4)
            sig = chip_tri(m - 12 if m > 48 else m, clk.beat * 0.86)
            sig *= _env(len(sig), 0.003, 0.012)
            _jplace(mix, sig, clk.at(bar, bt), 0.55)
    else:
        for bar, (c1, c2) in enumerate(changes):
            for half, ch in ((0, c1), (2, c2)):
                root = 36 + ch[0] % 12
                root = root - 12 if root > 46 else root
                m = root + 7 if half == 2 and c1 == c2 else root
                sig = chip_tri(m, clk.beat * 1.9)
                _jplace(mix, sig * _env(len(sig), 0.003, 0.05), clk.at(bar, half), 0.5)

    # Comping on pulse 2: chords as fast console arpeggios.
    comp = np.zeros_like(mix)
    for bar, (c1, c2) in enumerate(changes):
        for hit_beat, hit_len in spec["comp"](bar, rng):
            ch = c1 if hit_beat < 2 else c2
            voice = _tones(ch, 57, 72, (14,))
            length = clk.span(bar, hit_beat, hit_len)
            if spec.get("arp") == "frame":
                # 60 Hz frame arpeggio: the classic "chord" on one channel.
                step = 1 / 60
                k = 0
                while k * step < length:
                    m = voice[k % len(voice)]
                    seg = chip_pulse(m, step + 0.002, 0.5)
                    _jplace(comp, seg * _env(len(seg), 0.001, 0.001), clk.at(bar, hit_beat) + k * step,
                            0.9 * np.exp(-k * step / 0.22))
                    k += 1
            else:
                # Slow broken chord in triplets, up and back.
                order = voice[:5] + voice[3:0:-1]
                trip = clk.beat / 3
                for k in range(int(round(length / trip))):
                    m = order[k % len(order)]
                    seg = chip_pulse(m, trip * 0.9, 0.125)
                    _jplace(comp, seg * _env(len(seg), 0.003, 0.02, 0.6, 0.08), clk.at(bar, hit_beat) + k * trip, 1.0)
    mix += comp * spec["comp_gain"]

    # Drums on the noise channel.
    for bar in range(bars):
        for kind, b, g in spec["drums"](bar, bars, rng):
            t0 = clk.at(bar, b)
            if kind == "ride":
                s = chip_noise(0.4, 9000, True) * np.exp(-_jt(0.4) / 0.11)
                s = s * 0.6 + chip_noise(0.4, 14000) * np.exp(-_jt(0.4) / 0.05) * 0.4
            elif kind == "hat":
                s = chip_noise(0.05, 16000) * _env(int(JSR * 0.05), 0.001, 0.02, 0.0, 0.012)
            elif kind == "snare":
                s = chip_noise(0.16, 6000) * np.exp(-_jt(0.16) / 0.045)
            elif kind == "brush":
                n = int(JSR * clk.beat * 0.9)
                s = chip_noise(n / JSR, 11000) * np.sin(np.linspace(0, np.pi, n)) ** 2
            elif kind == "kick":
                t = _jt(0.12)
                f = 90 * np.exp(-t / 0.03) + 45
                tri = 1 - 4 * np.abs((np.cumsum(f) / JSR) % 1.0 - 0.5)
                s = np.round((tri + 1) * 7.5) / 7.5 - 1
                s *= np.exp(-t / 0.05)
            _jplace(mix, s, t0, g)

    # Fold the ringing tail back onto the start: a seamless loop.
    tail = mix[total:]
    mix = mix[:total]
    mix[: len(tail)] += tail
    return mix


def _write_ogg(name, sig, peak=0.85):
    sig = np.clip(normalize(sig, peak), -1, 1)
    wav = os.path.join(OUT, name + "_tmp.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(JSR)
        w.writeframes((sig * 32000).astype("<i2").tobytes())
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", ogg], check=True)
    os.remove(wav)


def make_office_jazz():
    rng = np.random.default_rng(1959)
    c = _ch

    # ----- Golden Hour Shuffle: 32-bar AABA in F, medium-up swing.
    a_turn = [(c("F"), c("F")), (c("D7"), c("D7")), (c("Gm7"), c("Gm7")), (c("C7"), c("C7")),
              (c("Am7"), c("D7")), (c("Gm7"), c("C7")), (c("F"), c("D7")), (c("Gm7"), c("C7"))]
    a_end = a_turn[:6] + [(c("F6"), c("F6")), (c("Gm7"), c("C7"))]
    bridge = [(c("Cm7"), c("Cm7")), (c("F7"), c("F7")), (c("Bb"), c("Bb")), (c("Bb"), c("Bb")),
              (c("Dm7"), c("Dm7")), (c("G7"), c("G7")), (c("Gm7"), c("Gm7")), (c("C7"), c("C7"))]
    chorus = a_turn + a_end + bridge + a_turn
    changes = chorus + chorus

    head_a = [
        (0.5, 0.5, 69), (1, 0.5, 72), (1.5, 0.5, 76), (2, 1, 74), (3, 1, 72),
        (4, 1.5, 69), (5.5, 0.5, 66), (6, 0.5, 69), (6.5, 0.5, 72), (7, 1, 75),
        (8, 2, 74), (10, 0.5, 70), (10.5, 0.5, 69), (11, 1, 67),
        (12, 0.5, 64), (12.5, 0.5, 67), (13, 0.5, 70), (13.5, 0.5, 74), (14, 1.5, 72), (15.5, 0.5, 70),
        (16, 1, 69), (17, 0.5, 72), (17.5, 0.5, 76), (18, 1, 78), (19, 0.5, 76), (19.5, 0.5, 74),
        (20, 1, 77), (21, 0.5, 74), (21.5, 0.5, 70), (22, 1, 76), (23, 1, 72),
    ]
    turn = [(24, 2, 69), (26, 0.5, 72), (26.5, 0.5, 75), (27, 0.5, 78), (27.5, 0.5, 81),
            (28, 1, 79), (29, 0.5, 77), (29.5, 0.5, 74), (30, 1, 76)]
    end = [(24, 3, 77), (30, 0.5, 67), (30.5, 0.5, 70), (31, 0.5, 74), (31.5, 0.5, 77)]
    b_head = [
        (0, 1, 75), (1, 0.5, 74), (1.5, 0.5, 72), (2, 1, 70), (3, 1, 67),
        (4, 1.5, 69), (5.5, 0.5, 72), (6, 0.5, 75), (6.5, 0.5, 74), (7, 1, 72),
        (8, 0.5, 74), (8.5, 0.5, 77), (9, 1.5, 81), (10.5, 0.5, 79), (11, 1, 77),
        (12, 3, 74), (15.5, 0.5, 76),
        (16, 1, 77), (17, 0.5, 76), (17.5, 0.5, 74), (18, 1, 72), (19, 1, 69),
        (20, 0.5, 71), (20.5, 0.5, 74), (21, 0.5, 77), (21.5, 0.5, 80), (22, 1, 79), (23, 1, 77),
        (24, 1, 70), (25, 0.5, 74), (25.5, 0.5, 77), (26, 1, 81), (27, 1, 79),
        (28, 1.5, 76), (29.5, 0.5, 74), (30, 0.5, 72), (30.5, 0.5, 70), (31, 1, 67),
    ]
    solo = _solo(chorus[:24], rng)  # solo over A A B; the head comes back for the last A
    lead = [
        (0, head_a + turn, 0.25, 0.34),
        (8, head_a + end, 0.25, 0.34),
        (16, b_head, 0.25, 0.34),
        (24, head_a + turn, 0.25, 0.34),
        (32, solo, 0.125, 0.3),
        (56, head_a + turn, 0.25, 0.34),
    ]

    patterns = [[(0, 0.6), (1.5, 0.4)], [(1.5, 0.4), (3, 0.5)], [(0.5, 0.4), (2.5, 0.4)],
                [(2, 0.6), (3.5, 0.4)], [(0, 1.2)], [(1.5, 0.4), (3.5, 0.4)]]

    def comp(bar, r):
        if bar % 8 == 7 and bar % 32 != 31:
            return [(0, 0.6), (2, 0.6)]
        return patterns[int(r.integers(0, len(patterns)))]

    def drums(bar, bars, r):
        hits = []
        for b in range(4):
            hits.append(("ride", b, 0.16 if b % 2 == 0 else 0.2))
            hits.append(("kick", b, 0.12))
        hits += [("ride", 1.5, 0.12), ("ride", 3.5, 0.12), ("hat", 1, 0.2), ("hat", 3, 0.2)]
        if bar >= 32 and bar < 56:  # busier under the solo
            for b in (0.5, 1.5, 2.5, 3.5):
                if r.random() < 0.22:
                    hits.append(("snare", b, 0.1))
        if bar % 8 == 7:  # a little fill into each new section
            hits += [("snare", 3, 0.2), ("snare", 3.5, 0.24)]
        if bar % 32 == 31:
            hits += [("snare", 2.5, 0.16), ("kick", 3.5, 0.3)]
        return hits

    shuffle = _render({
        "clock": _Clock(138, 0.64), "changes": changes, "rng": rng, "lead": lead,
        "bass": "walk", "comp": comp, "comp_gain": 0.16, "arp": "frame", "drums": drums, "echo": 0.2,
    })
    _write_ogg("office_jazz", _lowpass(shuffle, 9000))

    # ----- Clock-In Ballad: 16 bars in F, slow, triplet arpeggios.
    ballad_changes = [
        (c("Bb"), c("Bb")), (c("Am7"), c("Am7")), (c("Gm7"), c("Gm7")), (c("C7"), c("C7")),
        (c("F"), c("F")), (c("Dm7"), c("Dm7")), (c("Gm7"), c("Gm7")), (c("C7"), c("C7")),
        (c("Bb"), c("Bb")), (c("Bbm6"), c("Eb7")), (c("Am7"), c("Am7")), (c("D7"), c("D7")),
        (c("Gm7"), c("Gm7")), (c("C7"), c("C7")), (c("F6"), c("F6")), (c("Gm7"), c("C7")),
    ]
    tune = [
        (0, 1.5, 77), (1.5, 0.5, 76), (2, 1, 74), (3, 1, 69),
        (4, 3, 72),
        (8, 1.5, 70), (9.5, 0.5, 69), (10, 1, 67), (11, 1, 74),
        (12, 2, 76), (14, 1, 74), (15, 1, 70),
        (16, 2, 69), (18, 1, 72), (19, 1, 76),
        (20, 2.5, 77), (22.5, 0.5, 76), (23, 1, 74),
        (24, 1.5, 74), (25.5, 0.5, 72), (26, 1, 70), (27, 1, 69),
        (28, 3, 67),
        (32, 1.5, 77), (33.5, 0.5, 76), (34, 1, 74), (35, 1, 69),
        (36, 2, 73), (38, 1, 72), (39, 1, 70),
        (40, 2, 72), (42, 1, 76), (43, 1, 79),
        (44, 2, 78), (46, 1, 76), (47, 1, 72),
        (48, 1.5, 70), (49.5, 0.5, 74), (50, 2, 77),
        (52, 1.5, 76), (53.5, 0.5, 74), (54, 1, 70), (55, 1, 67),
        (56, 4, 69),
        (63, 0.5, 72), (63.5, 0.5, 74),
    ]

    def ballad_drums(bar, bars, r):
        hits = [("brush", 0, 0.05), ("brush", 2, 0.05), ("hat", 1, 0.1), ("hat", 3, 0.1)]
        if bar % 4 == 3:
            hits.append(("ride", 3.5, 0.08))
        return hits

    ballad = _render({
        "clock": _Clock(76, 2 / 3), "changes": ballad_changes, "rng": rng,
        "lead": [(0, tune, 0.25, 0.36)], "bass": "halves",
        "comp": lambda bar, r: [(0, 2), (2, 2)], "comp_gain": 0.13, "arp": "triplet",
        "drums": ballad_drums, "echo": 0.3,
    })
    # Vintage: a faint hiss and the odd crackle, like an old record.
    crackle = rng.normal(0, 0.004, len(ballad))
    for _ in range(int(len(ballad) / JSR * 5)):
        i = int(rng.integers(0, len(ballad) - 200))
        crackle[i:i + 120] += rng.uniform(-0.12, 0.12) * np.exp(-np.arange(120) / 12)
    ballad = _lowpass(ballad, 7000) + _lowpass(crackle, 5000) * np.max(np.abs(ballad))
    _write_ogg("office_title", ballad)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_sfx()
    make_music()
    make_office()
    make_look_busy()
    make_lift()
    make_rage()
    make_office_jazz()
    for f in sorted(os.listdir(OUT)):
        if not f.endswith(".import"):
            print(f"{f:20s} {os.path.getsize(os.path.join(OUT, f)) // 1024} KB")
