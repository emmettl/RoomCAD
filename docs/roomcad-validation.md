# RoomCAD against measured rooms

This report compares RoomCAD's responses with measurements in three real rooms from the Benchmark
for Room Acoustical Simulation (BRAS):

- scene CR2, the seminar room at RWTH Aachen University;
- scene CR3, the chamber music hall of the Konzerthaus Berlin, which is 20 times larger (see
  [A larger room](#a-larger-room-the-chamber-music-hall));
- scene CR4, the Auditorium Maximum of TU Berlin, which is 60 times larger (see
  [A large room](#a-large-room-the-auditorium)).

It is the comparison that roadmap milestone M4 item 5 asks for. It sets out what agrees, what doesn't
and why, and separates agreement with the measurements from what the model's assumptions decide.

## The room and the data

BRAS describes CR2 as a room with a simple geometry and challenging low-frequency behaviour: 145 m³,
almost empty, with hard walls and a reverberation time of about 2 s at mid frequencies. BRAS
provides:

- a SketchUp model;
- photographs;
- the positions of two dodecahedron loudspeakers and five omnidirectional microphones;
- ten measured room impulse responses at 44.1 kHz, one per source–microphone pair;
- each material's random-incidence absorption and scattering in third octaves, in two sets.

The two material sets are:

- **Initial estimates**, from published data and impedance-tube measurements, made without
  reference to the room's measured decay. This is an honest prediction.
- **Fitted estimates**, the initial ones scaled in each third octave so that Eyring's formula gives
  the measured reverberation time. This is what a designer would do after measuring.

RoomCAD's version of the room is in `Validation/bras-cr2/scene.json`, and how it was derived
is in that folder's README. In short:

- **Geometry.** The plan is 14 vertical walls, taken from the SketchUp model's vertices; it ignores
  three 12 cm window recesses. Its volume is 145.7 m³, against BRAS's 145 m³.
- **Walls of mixed material.** Walls with two materials take an area-weighted mean: the window
  wall, and two walls that are partly plaster and partly concrete.
- **Materials by octave.** Each material's octave values are the mean of its three third octaves.
- **The source's drivers.** The dodecahedron has three drivers at different heights, with
  crossovers at 177 Hz and 1.42 kHz. RoomCAD simulates each driver at its own height. The three
  responses are kept to their bands by complementary crossovers and summed.
- **Air.** It is set to the measured 19.5 °C and 41.7% relative humidity.

## Method

`make validate` runs `acousticbench --bras-cr2`, then `--bras-cr3` and `--bras-cr4`. For CR2 it
simulates all ten pairs, 3.5 s long like the measurements, in four configurations:

- the initial materials with the wave solver;
- BRAS's fitted materials with the wave solver;
- materials fitted to this model, with the wave solver and without it;
- for a scene with fitted zones, the same with them;
- materials fitted by simulating this model, with the wave solver.

BRAS fitted its materials to its own model, with its own volume and areas, in third octaves.
**Fitted to this model** instead takes the initial materials and scales their absorption in each
octave so that Eyring's formula, with this model's volume, areas and air, gives the measured mean
T30 (`ValidationScene.refitting`). This is what a designer with a measurement would do. The two
fitted sets differ by up to 10% in Eyring's estimate here.

**Fitted by simulating this model** goes one step further. It takes the set fitted to this model and
scales its absorption in each band until RoomCAD's own simulated T30 matches the measured mean
(`AbsorptionCalibration`; see
[Matching a measured reverberation time](room-acoustics-model.md#matching-a-measured-reverberation-time)).
The fit simulates one driver of loudspeaker 1 at all five microphones. With T30 matched by
construction, what remains to compare is the shape of the decay: EDT, clarity, definition and centre
time.

It analyses the measured and the simulated responses in the same way. Each one is timed in each
octave band from that band's own onset, the first sample within 20 dB of the band's peak. This
matters because the dodecahedron's crossover delays its low-frequency driver by up to 20 ms.

**Parameters.** These are the ISO 3382-1 parameters: EDT, T20, T30, C50, C80, D50 and centre time
Ts, all from Schroeder's backward integral (`RoomParameters`). A measured response ends in
background noise, so it is cut where its decay meets the noise, and the missing decay is added back
from the slope, after Lundeby et al. A simulated response has no noise and is integrated whole. The
octave bands are those RoomCAD renders with, except that the 63 Hz and 8 kHz bands are closed like
the others, below 31 Hz and above 16 kHz (`OctaveBands.measurementWeight`). The
tables give the mean over the ten pairs. Each simulated mean is followed by its difference from the
measured mean in just-noticeable differences (JNDs): 5% for decay times, 1 dB for C50 and C80, 0.05
for D50 and 10 ms for Ts (ISO 3382-1, Annex A).

**Low-frequency fine structure.** From 30 to 175 Hz, the spectrum's level 1/24 octave apart, less
its mean over the surrounding octave, leaves the modal peaks and dips. The source's and the room's
broad trends are removed. The correlation between measured and simulated fine structure is given at
the same position, and, as a baseline, against the other positions. The simulated spectrum is also
read with its frequencies scaled by up to ±4%, which shows any systematic shift of the mode
frequencies.

**Early reflections.** Above 500 Hz, the energy in 1 ms bins from 1.5 to 19.5 ms after the direct
sound is compared as a level. It is correlated at the same position, and at other positions as a
baseline.

The measured parameters are kept in `Validation/bras-cr2/measured.json`, so the comparison
runs without downloading the measurements. `Scripts/fetch-bras.py` fetches the 6 MB of
BRAS that the fixture is derived from, and `acousticbench --bras-cr2 --update-fixture` rebuilds the
fixture from it. A run takes about 6 minutes on a Mac Studio (M4 Max), almost all of it in the wave
solver.

**Two corrections to the analysis.** Looking into the auditorium's slow early decay at 63 Hz found two
faults in how the parameters were measured, which affected the measured and the simulated responses
alike. The three fixtures were rebuilt from BRAS's responses with both corrected; nothing else in them
changed, and every number in this report uses them.

- **The edge bands were not octaves.** The bands RoomCAD renders with must sum to one, so the lowest
  took in everything below 62.5 Hz at full weight, down to 0 Hz, and the highest everything above
  8 kHz, up to the Nyquist frequency. Closed like the others, they fall to nothing at 31 Hz and 16 kHz.
  Open, a "63 Hz" parameter mixed in what lies below the octave, and an "8 kHz" one what lies above
  it, where the two sides differ. The simulated source is flat down to 20 Hz, while the dodecahedron
  is 18–30 dB down at 20–31.5 Hz against 63 Hz (in the auditorium), and the room's sparse modes there
  ring long.
  Above 11 kHz the real air absorbs far more than at 8 kHz and the source is more directional, so the
  top of the measured band is mostly direct sound and early reflections; the model gives the whole
  band 8 kHz's air. With both bands closed like the others, the measured 8 kHz EDT is 0.96, 0.72 and
  0.83 s in the three rooms, not 0.68, 0.53 and 0.61 s, and C80 is 3.8, 6.4 and 5.5 dB, not 6.8, 9.0
  and 8.4 dB.
- **A burst of noise could stretch the noise compensation.** The fit to the decay ran to the last 10 ms
  block more than 10 dB above the noise, so one louder block late in the response, such as a knock in
  the building, took the fit through the noise. At 63 Hz the decay starts only 41–59 dB above the noise,
  and this made one auditorium pair's T30 4.69 s, against 2.4–2.9 s at the other nine (2.54 s now). The
  fit now ends where the decay, averaged over 50 ms, first comes within 10 dB of the noise, as Lundeby
  et al. describe. Apart from the 63 Hz band, only one value changed by more than 0.3%: one seminar-room
  pair's T30 at 125 Hz, from 1.67 to 1.43 s, now in line with its T20 of 1.42 s.

Together these lower the measured 63 Hz T30 from 1.71 ± 0.47 to 1.56 ± 0.18 s in the seminar room,
from 1.98 ± 0.25 to 1.81 ± 0.14 s in the chamber music hall, and from 2.89 ± 0.62 to 2.52 ± 0.16 s in
the auditorium, closer to each room's T20. The materials fitted to this model follow the measured T30,
so at 63 Hz they now absorb more. `AbsorptionCalibration` measures in the same closed bands.

## Results

The first run of this comparison found the wave solver's low-frequency decay too long. Its walls are
locally reacting, and they take only half as much energy from modes that graze them as from modes that
strike them. With the fitted materials, its T30 at 63 and 125 Hz came out 2.02 and 1.85 s, against 1.71
and 1.40 s as then measured. The solver now damps each band so the room decays, on average, at Eyring's
diffuse rate (see [the wave solver](room-acoustics-model.md#low-frequencies-the-wave-solver)). The
results below include that matching. The probes measured the bare decay at 1.2–1.4 times Eyring's
estimate in each of the solver's bands.

### Reverberation time

T30, mean over the pairs (measured ± spread across the pairs), with JNDs in brackets:

| | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|
| Measured | 1.56 ± 0.18 | 1.38 ± 0.08 | 1.72 ± 0.14 | 2.02 ± 0.04 | 1.94 ± 0.04 | 1.75 ± 0.02 | 1.57 ± 0.01 | 1.10 ± 0.01 |
| Initial | 3.29 (+22) | 2.62 (+18) | 1.93 (+2.4) | 1.81 (−2.0) | 1.84 (−1.0) | 1.67 (−0.9) | 1.27 (−3.7) | 0.80 (−5.5) |
| Fitted by BRAS | 1.47 (−1.1) | 1.46 (+1.1) | 1.91 (+2.2) | 2.25 (+2.3) | 2.12 (+1.9) | 1.92 (+1.9) | 1.67 (+1.3) | 1.08 (−0.4) |
| Fitted to this model | 1.47 (−1.1) | 1.50 (+1.7) | 2.02 (+3.4) | 2.17 (+1.5) | 2.01 (+0.8) | 1.81 (+0.7) | 1.58 (+0.2) | 1.11 (+0.1) |
| Fitted to this model, no wave solver | 1.57 (+0.2) | 1.65 (+3.9) | 2.01 (+3.4) | 2.17 (+1.5) | 2.01 (+0.8) | 1.81 (+0.7) | 1.58 (+0.2) | 1.11 (+0.1) |

T20 and EDT follow the same pattern.

- **250 Hz to 2 kHz, initial materials.** RoomCAD predicts the measured T30 to within 12% (−10% to
  +12%) from published material data alone. That is the most useful result, because a designer
  usually has no measurement.
- **Fitted materials.** Fitted to this model, Eyring's estimate equals the measured T30 by
  construction. RoomCAD's decay is then within 4% of it from 1 to 8 kHz, but 7–17% longer from 125 to
  500 Hz. In a room this close to a box, with scattering of only 0.05–0.07 below 1 kHz on the walls
  and floor, some sound keeps travelling between parallel surfaces and decays more slowly than in a
  diffuse field. This is the non-diffuse decay that Kuttruff describes, and the geometrical model
  shows it for that reason. The real room has chairs, radiators and fittings that scatter more.
  BRAS's fitted set gives decay 6–11% long from 250 Hz to 4 kHz.
- **4 and 8 kHz, initial materials.** The decay is 19% and 27% too short. The initial high-frequency
  absorption, including air, is too high for this room. The fitted sets correct it.
- **63 and 125 Hz, initial materials.** The decay is about twice as long as measured. The published
  absorption of plaster and concrete is only 0.02–0.05 there. The real room loses much more energy at
  low frequencies, through the windows' and doors' flexibility and transmission. A designer needs
  realistic low-frequency absorption for small rooms, which published coefficients for hard walls
  don't give.
- **63 and 125 Hz, fitted materials.** With the wave solver, the decay is within 6% and 9% of the
  measurement with either fitted set (the two are alike at 63 Hz). Geometrical acoustics alone gives
  +1% and +20% with the set fitted to this model.

### Clarity, definition and early decay

| | | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|---|
| C80 (dB) | Measured | 2.8 ± 2.5 | 0.8 ± 2.0 | 1.0 ± 1.3 | −1.4 ± 0.7 | −0.8 ± 0.6 | −0.1 ± 0.6 | 0.2 ± 0.4 | 3.8 ± 0.4 |
| | Initial | −1.9 (−4.7) | −1.9 (−2.6) | −2.4 (−3.4) | −0.5 (+0.8) | −1.2 (−0.4) | 0.1 (+0.2) | 2.1 (+1.9) | 6.1 (+2.4) |
| | Fitted by BRAS | 2.0 (−0.8) | 1.6 (+0.9) | −2.4 (−3.4) | −1.9 (−0.5) | −2.1 (−1.3) | −0.9 (−0.7) | 0.1 (+0.0) | 3.5 (−0.2) |
| | Fitted to this model | 2.0 (−0.8) | 1.6 (+0.9) | −2.9 (−3.9) | −1.7 (−0.3) | −1.8 (−1.0) | −0.5 (−0.4) | 0.4 (+0.2) | 2.6 (−1.2) |
| | Fitted to this model, no wave solver | −0.7 (−3.5) | −0.3 (−1.0) | −2.9 (−3.9) | −1.7 (−0.3) | −1.8 (−1.0) | −0.5 (−0.4) | 0.4 (+0.2) | 2.6 (−1.2) |
| D50 | Measured | 0.50 ± 0.14 | 0.36 ± 0.09 | 0.42 ± 0.12 | 0.30 ± 0.05 | 0.32 ± 0.04 | 0.36 ± 0.03 | 0.36 ± 0.02 | 0.55 ± 0.03 |
| | Initial | 0.30 (−4.0) | 0.28 (−1.6) | 0.26 (−3.1) | 0.34 (+0.7) | 0.29 (−0.5) | 0.36 (+0.0) | 0.46 (+2.0) | 0.65 (+2.0) |
| | Fitted by BRAS | 0.48 (−0.3) | 0.44 (+1.6) | 0.26 (−3.1) | 0.28 (−0.5) | 0.26 (−1.2) | 0.32 (−0.8) | 0.36 (+0.0) | 0.53 (−0.4) |
| | Fitted to this model | 0.48 (−0.3) | 0.44 (+1.6) | 0.24 (−3.5) | 0.29 (−0.3) | 0.27 (−1.0) | 0.33 (−0.5) | 0.37 (+0.2) | 0.48 (−1.3) |
| | Fitted to this model, no wave solver | 0.30 (−4.1) | 0.29 (−1.4) | 0.24 (−3.6) | 0.29 (−0.3) | 0.27 (−1.0) | 0.33 (−0.5) | 0.37 (+0.2) | 0.48 (−1.3) |

- **500 Hz to 2 kHz.** C80 and D50 are within about one JND with any material set. EDT is within
  about 2 JND with the initial set and the set fitted to this model; BRAS's set gives EDT 2–3 JND
  long, like its T30.
- **63 and 125 Hz, fitted materials.** With the wave solver, clarity, definition and EDT are within
  about 1.6 JND with either fitted set; EDT at 63 Hz is 1.36 s against 1.38 s. Without the solver,
  clarity and definition at 63 Hz are about 4 JND too low and EDT 3.3 JND long: geometrical acoustics
  misses how the room's modes shape the early energy.
- **250 Hz.** Every configuration gives 3.4–3.9 dB less clarity than measured. This band lies
  above the wave solver's crossover (174 Hz), where the geometrical model's slow, nearly specular
  decay applies.
- **8 kHz.** Measured in a closed octave (see [Method](#method)), the response's early decay is a
  little faster than its late decay: EDT 0.96 s against T30 1.10 s, and C80 3.8 dB. BRAS's fitted set
  gives EDT, C80 and D50 within 0.8 JND. The set fitted to this model gives EDT 4 JND long and C80
  1.2 dB low. Before the band was closed, the measured EDT was 0.68 s and C80 6.8 dB, and this report
  put the difference down to the dodecahedron's directivity; most of it came from the band's content
  above its octave.

### Low-frequency fine structure

From 30 to 175 Hz:

| | Same position | Other positions | Best frequency scale |
|---|---|---|---|
| Initial | 0.63 ± 0.08 | 0.39 | 0.67, simulated frequencies 1.5% higher |
| Fitted by BRAS | 0.63 ± 0.09 | 0.38 | 0.68, simulated frequencies 1.5% higher |
| Fitted to this model | 0.63 ± 0.09 | 0.38 | 0.68, simulated frequencies 1.5% higher |
| Fitted to this model, no wave solver | 0.14 ± 0.15 | 0.03 | 0.16, simulated frequencies 1% higher |

- **The wave solver reproduces the room's modal structure.** At the same position the fine
  structure correlates at 0.63, against 0.14 for geometrical acoustics alone, whose low end has no
  modes. Matching the decay left this unchanged.
- **Position-specific structure.** The correlation is higher at the same position than at others
  (0.38), so the solver captures where each mode is loud or quiet, not just its frequency.
- **Mode frequencies.** Raising the simulated frequencies by 1–1.5% improves the agreement slightly,
  so the measured modes lie about 1.5% higher than the simulated ones. The solver's own mode
  frequencies are checked to 0.25% in a rigid box. The likely cause is that the simplified room is a
  little too large acoustically: it leaves out radiators, sills, window frames and ceiling lights.

### Early reflections

Above 500 Hz, between 1.5 and 19.5 ms, the correlation is the same in every configuration, since
the wave solver works only below 174 Hz: 0.60–0.61 ± 0.25 at the same position, against 0.21–0.22 at
others.

The simulated early reflections follow the measured pattern at most positions. They are not identical.
The dodecahedron spans about 30 cm, and its drivers radiate unevenly. The measured onsets imply
positions that agree with the documented ones to within about ±20 cm. The model also leaves out the
window recesses, sills and fittings, which add reflections of their own. One pair, loudspeaker 1 to
microphone 2, doesn't correlate at all. Two of the measured responses from loudspeaker 2 have a weak
direct sound and strong arrivals near 10 and 16 ms that the model lacks.

### Fitted by simulating the model

The fit took three simulations. The absorption rose by 4–25% from 125 Hz to 2 kHz, most at 250 Hz,
and by 28% at 8 kHz; it fell by 7% at 63 Hz.

| | | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|---|
| T30 (s) | Measured | 1.56 ± 0.18 | 1.38 ± 0.08 | 1.72 ± 0.14 | 2.02 ± 0.04 | 1.94 ± 0.04 | 1.75 ± 0.02 | 1.57 ± 0.01 | 1.10 ± 0.01 |
| | Simulated | 1.59 (+0.4) | 1.32 (−0.9) | 1.72 (+0.0) | 2.00 (−0.2) | 1.94 (+0.0) | 1.75 (+0.0) | 1.57 (+0.0) | 1.08 (−0.5) |
| EDT (s) | Measured | 1.38 ± 0.28 | 1.41 ± 0.23 | 1.45 ± 0.10 | 1.98 ± 0.14 | 1.90 ± 0.07 | 1.72 ± 0.05 | 1.58 ± 0.03 | 0.96 ± 0.03 |
| | Simulated | 1.45 (+1.0) | 1.28 (−1.8) | 1.61 (+2.3) | 2.04 (+0.7) | 2.01 (+1.1) | 1.72 (−0.1) | 1.56 (−0.2) | 1.09 (+2.9) |
| C80 (dB) | Measured | 2.8 ± 2.5 | 0.8 ± 2.0 | 1.0 ± 1.3 | −1.4 ± 0.7 | −0.8 ± 0.6 | −0.1 ± 0.6 | 0.2 ± 0.4 | 3.8 ± 0.4 |
| | Simulated | 1.6 (−1.2) | 2.4 (+1.7) | −1.7 (−2.7) | −1.1 (+0.2) | −1.5 (−0.8) | −0.3 (−0.2) | 0.4 (+0.3) | 2.9 (−0.9) |
| D50 | Measured | 0.50 ± 0.14 | 0.36 ± 0.09 | 0.42 ± 0.12 | 0.30 ± 0.05 | 0.32 ± 0.04 | 0.36 ± 0.03 | 0.36 ± 0.02 | 0.55 ± 0.03 |
| | Simulated | 0.47 (−0.7) | 0.47 (+2.3) | 0.29 (−2.5) | 0.31 (+0.2) | 0.28 (−0.8) | 0.34 (−0.3) | 0.38 (+0.3) | 0.50 (−1.0) |

- **500 Hz to 4 kHz.** With T30 matched, EDT, C80, D50 and centre time are all within about 1.1 JND.
  The model's decay has the right shape there.
- **250 Hz.** Clarity is still 2.7 JND low and EDT 2.3 JND long, better than with Eyring-fitted
  materials (3.9 and 7.2 JND). This band lies just above the wave solver's crossover, where the
  geometrical model's nearly specular decay is too slow at first.
- **8 kHz.** EDT is 2.9 JND long, and C80 and D50 within about one JND.
- **63 Hz.** EDT, C80 and D50 are within 1.2 JND.
- **Low frequencies and early reflections.** These are unchanged: fine structure 0.64, early
  reflections 0.61.

## A larger room: the chamber music hall

### The room

BRAS's scene CR3 is the chamber music hall of the Konzerthaus Berlin. Its features are:

- a flat floor of seating;
- side aisles under galleries, and a rear balcony;
- a stage behind a proscenium, 1 m above the floor, with a shell of angled panels;
- a flat ceiling at 7.6 m, with an attic above it that opens into the stage house.

The reverberation time is about 1.3 s at mid frequencies. Its Schroeder frequency is about 40 Hz,
so modes matter much less here than in CR2.

RoomCAD's version is in `Validation/bras-cr3/`. Unlike CR2's, it is not a floor plan.

- **Pieces of air.** The room is built from 12 boxes and extrusions of air, joined, with the stage
  shell's panels and a 1 cm layer of seating cut out. RoomCAD turns them into a closed mesh with
  constructive solid geometry (see [Rooms of any shape](room-acoustics-model.md#rooms-of-any-shape)).
- **Simplifications.** The mesh leaves out the pillars between the galleries, the ornament on the
  walls and ceiling, and the chairs themselves.
- **Size.** Its volume is 3,119 m³, against 3,331 m³ in BRAS's model. Its surface area is 2,286 m²,
  against 2,763 m². Most of the missing area is structured plaster: 565 m² here, against 1,172 m².

The folder's README lists the pieces and the material areas.

### Materials fitted to this model

BRAS's fitted materials make Eyring's formula give the measured T30 in BRAS's own model. Here the volume
and surface areas differ, so with those materials Eyring's formula gives times up to 19% longer than
measured: 16–19% from 500 Hz to 2 kHz. The set **fitted to this model** (see [Method](#method)) matters
more here than in CR2, where the two sets differ by up to 10%.

### Results

T30, mean over the ten pairs, with JNDs in brackets:

| | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|
| Measured | 1.81 ± 0.14 | 1.62 ± 0.07 | 1.45 ± 0.04 | 1.29 ± 0.03 | 1.33 ± 0.03 | 1.32 ± 0.01 | 1.06 ± 0.02 | 0.77 ± 0.01 |
| Initial | 3.12 (+14) | 2.97 (+17) | 2.95 (+21) | 2.25 (+15) | 1.68 (+5.2) | 1.36 (+0.6) | 1.13 (+1.4) | 0.77 (−0.1) |
| Fitted by BRAS | 2.06 (+2.8) | 2.30 (+8.5) | 2.26 (+11) | 1.90 (+9.4) | 1.81 (+7.1) | 1.70 (+5.9) | 1.30 (+4.5) | 0.87 (+2.6) |
| Fitted to this model | 1.88 (+0.8) | 2.09 (+5.8) | 2.05 (+8.3) | 1.74 (+6.9) | 1.59 (+3.8) | 1.49 (+2.6) | 1.20 (+2.7) | 0.86 (+2.3) |
| Fitted to this model, no wave solver | 2.52 (+7.9) | 2.10 (+5.9) | 2.05 (+8.3) | 1.74 (+6.9) | 1.59 (+3.8) | 1.49 (+2.6) | 1.20 (+2.7) | 0.86 (+2.3) |

Clarity and centre time, fitted to this model:

| | | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|---|
| C80 (dB) | Measured | 0.7 ± 2.7 | 0.4 ± 1.0 | 0.8 ± 2.1 | 1.6 ± 1.5 | 1.7 ± 0.7 | 1.6 ± 0.6 | 3.3 ± 0.8 | 6.4 ± 0.7 |
| | Simulated | 2.0 (+1.3) | −0.2 (−0.6) | −0.7 (−1.5) | 0.8 (−0.8) | 1.2 (−0.6) | 1.5 (−0.1) | 2.7 (−0.6) | 5.1 (−1.3) |
| Ts (ms) | Measured | 112 ± 24 | 113 ± 6 | 99 ± 17 | 94 ± 15 | 92 ± 9 | 91 ± 7 | 70 ± 8 | 47 ± 6 |
| | Simulated | 111 (−0.1) | 126 (+1.3) | 136 (+3.8) | 108 (+1.4) | 100 (+0.8) | 96 (+0.5) | 78 (+0.8) | 55 (+0.8) |

- **Clarity, definition and centre time.** Fitted to this model, these are within about one JND
  from 500 Hz to 4 kHz. Without the wave solver, C80 at 63 Hz is 2.3 JND low, as in CR2.
- **Decay.** T30 is still too long: 29–41% at 125–500 Hz, and 12–20% from 1 to 8 kHz. EDT is 2.5–4
  JND long, and 8 JND at 250 Hz. With BRAS's own fitted set, the decay is 36–56% too long from 125 Hz
  to 1 kHz.
- **Low frequencies.** At 63 Hz the wave solver gives T30 4% long, C80, D50 and centre time within
  1.3 JND, and EDT 2.7 JND long (1.75 s against 1.54 s). Without it, T30 is 39% long, EDT 9.7 JND long
  and C80 2.3 JND low. The wave solver's crossover is 85–87 Hz. The low-frequency fine structure
  doesn't correlate in any configuration (−0.01 to 0.04). That is expected: the hall's modes above
  40 Hz overlap, so its spectrum is a random pattern that depends on details the model leaves out.
- **Early reflections.** These correlate at 0.49 ± 0.16 at the same position, against 0.23 at others.
  With the initial materials the correlation is 0.50.
- **The initial materials.** From 2 to 8 kHz they predict T30 within 7%, but at 125–500 Hz the decay
  is 1.7–2 times too long. As in CR2, the published low-frequency absorption is too low.

### Why the decay is long

The geometrical model decays more slowly than Eyring's formula, even with the same volume and
absorption, because the room is not fully diffuse. Probing the hall with BRAS's fitted set, from
source LS1 to three receivers, without the wave solver:

| | 500 Hz | 1 kHz | 2 kHz |
|---|---|---|---|
| As modelled | +25% | +13% | +8% |
| Every surface scattering at least 0.5 | +13% | +6% | +3% |
| Every surface scattering fully | +13% | +7% | +4% |
| Without the attic | +23% | +11% | +10% |

These are T30 above Eyring's estimate for the same room. Two things make up the excess:

- **Scattering.** More scattering takes away about half of it. The simplified hall has smooth walls
  where the real one has pillars, coffers and mouldings, and a flat layer where it has chairs. BRAS's
  scattering coefficients describe surfaces on their own, not the objects in front of them.
- **Concentrated absorption.** The rest remains even when every surface scatters fully. Most of the
  hall's absorption is in the seating, on the floor, and Eyring's formula takes absorption to be spread
  evenly. With it concentrated, a diffuse room still decays more slowly than the formula says. Any
  model of the room would show this; fitting absorption to the formula cannot remove it.

The attic makes little difference.

### Chairs as fitted zones

BRAS models the seating as a material on the floor. It counts the chairs in its notes on the model:
246 in the stalls, 22 in each side gallery and 61 on the rear balcony. The configuration **fitted to
this model, with chairs** adds them as
[fitted zones](room-acoustics-model.md#fitted-zones), 0.9 m high over the seating. Each chair is
taken to have 1.5 m² of surface, an estimate, which gives a density of 0.8–1.0 per metre. Their
absorption stays with the seating material, so the fitted absorption is unchanged. T30, against the
measurement:

| | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|
| Without chairs | +29% | +41% | +35% | +20% | +13% | +13% | +12% |
| With chairs | +22% | +35% | +27% | +17% | +12% | +13% | +16% |

The chairs shorten the decay by 6–8 points from 125 to 500 Hz, make little difference from 1 to
4 kHz and lengthen it by 4 points at 8 kHz. Clarity, definition and centre time change by about a JND
or less. The early reflections correlate at 0.46 ± 0.13, against 0.49 without the chairs. Doubling
each chair's surface did not shorten the decay further in a shorter probe.

### Fitted by simulating the model

The fit kept, in each band, the closest of six simulations. The absorption rose by 14–53% from
125 Hz to 8 kHz, most at 250 and 500 Hz; at 63 Hz it was unchanged.

| | | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|---|
| T30 (s) | Measured | 1.81 ± 0.14 | 1.62 ± 0.07 | 1.45 ± 0.04 | 1.29 ± 0.03 | 1.33 ± 0.03 | 1.32 ± 0.01 | 1.06 ± 0.02 | 0.77 ± 0.01 |
| | Simulated | 1.78 (−0.3) | 1.59 (−0.4) | 1.47 (+0.4) | 1.32 (+0.4) | 1.35 (+0.2) | 1.34 (+0.4) | 1.09 (+0.7) | 0.79 (+0.3) |
| EDT (s) | Measured | 1.54 ± 0.30 | 1.58 ± 0.20 | 1.37 ± 0.09 | 1.34 ± 0.10 | 1.31 ± 0.08 | 1.24 ± 0.04 | 1.04 ± 0.04 | 0.72 ± 0.04 |
| | Simulated | 1.79 (+3.2) | 1.37 (−2.6) | 1.34 (−0.4) | 1.16 (−2.7) | 1.26 (−0.8) | 1.25 (+0.2) | 1.06 (+0.3) | 0.77 (+1.4) |
| C80 (dB) | Measured | 0.7 ± 2.7 | 0.4 ± 1.0 | 0.8 ± 2.1 | 1.6 ± 1.5 | 1.7 ± 0.7 | 1.6 ± 0.6 | 3.3 ± 0.8 | 6.4 ± 0.7 |
| | Simulated | 0.9 (+0.2) | 1.9 (+1.5) | 1.9 (+1.1) | 3.1 (+1.6) | 2.5 (+0.7) | 2.3 (+0.8) | 3.5 (+0.2) | 5.8 (−0.6) |
| D50 | Measured | 0.43 ± 0.17 | 0.36 ± 0.11 | 0.42 ± 0.14 | 0.43 ± 0.12 | 0.43 ± 0.07 | 0.42 ± 0.05 | 0.52 ± 0.06 | 0.67 ± 0.04 |
| | Simulated | 0.40 (−0.5) | 0.48 (+2.5) | 0.46 (+0.7) | 0.54 (+2.1) | 0.50 (+1.3) | 0.47 (+1.2) | 0.55 (+0.5) | 0.65 (−0.3) |

- **T30.** It now matches within 0.7 JND in every band.
- **The shape of the decay.** From 1 to 8 kHz, EDT, clarity and definition are within about 1.4
  JND. At 125 and 500 Hz, though, the early decay is now too fast: EDT is 2.6–2.7 JND short, and
  clarity and definition 1.5–2.5 JND high. With Eyring-fitted materials, EDT and T30 were both too
  long. The simulated decay sags, falling quickly at first and more slowly later, where the measured
  one falls in a straight line. Matching one end of it leaves the other wrong. That is what a room
  that mixes its sound too little does: early on, sound meets the absorbing audience often; later,
  what is left travels between the walls and ceiling and meets it less. It points the same way as
  the diagnosis above: the simplified hall needs the scattering its smooth surfaces and missing
  objects lack.
- **63 Hz.** EDT is 3.2 JND long (1.79 s against 1.54 s), with C80 and D50 within 0.5 JND.
- **Early reflections.** These correlate at 0.48 ± 0.14.

## A large room: the auditorium

### The room

BRAS's scene CR4 is the Auditorium Maximum of TU Berlin, a lecture hall of 8,650 m³ for about 1,200
people. Its features are:

- a fan-shaped plan between brick walls, splayed at 8.9° from the axis;
- stalls that rise 1.8 m towards the back, in 22 rows;
- side galleries that rise along the walls to a rear balcony;
- a stage 0.8 m above the front of the stalls, with a reflector over its front;
- a concrete ceiling that rises from 10 to 13 m, with 35 white panels hung below it.

The reverberation time is about 2.1 s at mid frequencies, and 2.4 s at 125 and 250 Hz. Its Schroeder
frequency is about 30 Hz. The wave solver's crossover is lowered to 71–73 Hz to fit its budget, so the
upper half of the 63 Hz band is partly geometrical and the 125 Hz band entirely.

RoomCAD's version is in `Validation/bras-cr4/`. Like CR3's, it is built from pieces of air.

- **Pieces of air.** A long section, with the stage, the raked stalls and the sloping ceiling, is
  extruded across the hall. The rear balcony, the side galleries, the stage reflector, the ceiling
  panels and a 1 cm layer of seating are cut out of it. The splayed side walls and the curved back wall
  cut away everything beyond them. The mesh has 1,343 faces.
- **Reading BRAS's model.** BRAS's SketchUp model has the room's dimensions only as faces. They were read
  with `read-skp.py`, which recovers 1,826 faces whose areas match BRAS's own list of material areas.
- **Simplifications.** The model leaves out the folds of the concrete ceiling above the panels, the
  pillars, the stairs, the lobbies in the back corners and the side galleries' parapets. The
  galleries' steps are a slope.
- **Size.** Its volume is 8,727 m³, against 8,650 m³ in BRAS's documentation. Its surface area is
  4,963 m², against 5,851 m². Most of the missing area is concrete: 1,142 m² here, against 1,774 m².

The folder's README lists the pieces, the source files with their checksums, and the material areas.

### Materials fitted to this model

The surface is 15% smaller than in BRAS's model, and the volume about the same. So with BRAS's fitted
materials, Eyring's formula gives times about 13% longer than measured at 125 and 250 Hz. The set
**fitted to this model** (see [Method](#method)) corrects this, as in CR3.

### Results

T30, mean over the ten pairs, with JNDs in brackets:

| | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|
| Measured | 2.52 ± 0.16 | 2.40 ± 0.09 | 2.38 ± 0.06 | 2.07 ± 0.04 | 2.10 ± 0.04 | 1.85 ± 0.02 | 1.42 ± 0.01 | 0.94 ± 0.01 |
| Initial | 3.38 (+6.9) | 3.48 (+9.1) | 2.81 (+3.7) | 2.34 (+2.6) | 2.18 (+0.8) | 1.52 (−3.5) | 1.08 (−4.8) | 0.71 (−4.8) |
| Fitted by BRAS | 3.03 (+4.0) | 3.10 (+5.8) | 2.94 (+4.8) | 2.60 (+5.2) | 2.53 (+4.1) | 2.14 (+3.2) | 1.62 (+2.8) | 1.05 (+2.5) |
| Fitted to this model | 2.87 (+2.7) | 2.88 (+4.1) | 2.67 (+2.5) | 2.39 (+3.1) | 2.40 (+2.9) | 2.02 (+1.8) | 1.55 (+1.8) | 1.05 (+2.3) |
| Fitted to this model, no wave solver | 3.04 (+4.2) | 2.89 (+4.1) | 2.67 (+2.5) | 2.39 (+3.1) | 2.40 (+2.9) | 2.02 (+1.8) | 1.55 (+1.8) | 1.05 (+2.3) |

Early decay, clarity, definition and centre time, fitted to this model:

| | | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|---|
| EDT (s) | Measured | 1.68 ± 0.23 | 2.21 ± 0.35 | 2.42 ± 0.14 | 2.09 ± 0.10 | 2.19 ± 0.14 | 1.86 ± 0.09 | 1.42 ± 0.10 | 0.83 ± 0.08 |
| | Simulated | 2.33 (+7.8) | 2.59 (+3.4) | 2.60 (+1.4) | 2.32 (+2.2) | 2.36 (+1.5) | 1.94 (+0.8) | 1.52 (+1.4) | 0.97 (+3.4) |
| C80 (dB) | Measured | 1.2 ± 1.9 | −0.6 ± 1.6 | −1.8 ± 2.5 | 0.3 ± 1.7 | −0.6 ± 1.2 | −0.0 ± 0.8 | 2.0 ± 2.0 | 5.5 ± 1.5 |
| | Simulated | 1.1 (−0.1) | −2.6 (−2.0) | −2.5 (−0.7) | −1.4 (−1.7) | −1.4 (−0.8) | −0.0 (+0.0) | 1.6 (−0.5) | 4.5 (−1.0) |
| D50 | Measured | 0.45 ± 0.11 | 0.32 ± 0.08 | 0.28 ± 0.14 | 0.40 ± 0.10 | 0.35 ± 0.08 | 0.37 ± 0.07 | 0.47 ± 0.15 | 0.63 ± 0.11 |
| | Simulated | 0.44 (−0.2) | 0.26 (−1.1) | 0.26 (−0.3) | 0.34 (−1.2) | 0.33 (−0.3) | 0.39 (+0.3) | 0.47 (+0.0) | 0.61 (−0.4) |
| Ts (ms) | Measured | 120 ± 19 | 147 ± 12 | 166 ± 31 | 127 ± 21 | 142 ± 14 | 125 ± 11 | 91 ± 21 | 54 ± 13 |
| | Simulated | 135 (+1.5) | 190 (+4.3) | 186 (+2.1) | 158 (+3.1) | 160 (+1.8) | 127 (+0.2) | 97 (+0.6) | 61 (+0.8) |

- **The initial materials.** At 1 kHz they predict T30 within 4%, at 250 and 500 Hz it is 13–18% long,
  and at 125 Hz 45% long. From 2 to 8 kHz it is 18–24% short: the initial high-frequency absorption is
  too high, as in CR2.
- **Decay, fitted to this model.** T30 is 9–20% too long from 125 Hz to 8 kHz: 20% at 125 Hz, 12–15%
  from 250 Hz to 1 kHz, 9% at 2 and 4 kHz and 12% at 8 kHz. That is less than in the chamber music
  hall (12–41%), but it points the same way: the simplified room is less diffuse than Eyring's formula
  assumes. EDT is 0.8–2.2 JND long from 250 Hz to 4 kHz. With BRAS's own fitted set, the decay is
  14–29% too long from 125 Hz to 4 kHz.
- **Clarity, definition and centre time.** Fitted to this model, C80 and D50 are within one JND
  from 1 to 4 kHz, and centre time from 2 to 4 kHz. At 500 Hz, C80 is 1.7 dB low and centre time 31 ms
  long. From 125 to 500 Hz, centre time is 2.1–4.3 JND long, following the long decay.
- **8 kHz.** EDT is 0.97 s against 0.83 s measured (3.4 JND), and C80 and D50 are within one JND.
  Before the band was closed (see [Method](#method)), the measured EDT was 0.61 s and C80 8.4 dB, and
  the difference was put down to the dodecahedron's directivity.
- **Low frequencies.** At 63 Hz, with the wave solver, C80, D50 and centre time are within 1.5 JND, but
  T30 is 14% long and EDT 2.33 s against 1.68 s (7.8 JND). Without the solver T30 is 21% long, and C80
  and D50 are 3.4–4 JND low. See [the early decay at 63 Hz](#the-early-decay-at-63-hz).
- **Low-frequency fine structure.** It correlates at 0.23 ± 0.13 at the same position, against −0.00
  at other positions. Without the wave solver it does not correlate (0.03). So the solver captures part
  of the position-specific pattern below its crossover, at 71–73 Hz, even in this hall. With the
  crossover at 89–96 Hz, before the solver's walls took each band's own absorption (see
  [the wave solver](room-acoustics-model.md#low-frequencies-the-wave-solver)), it was 0.29.
- **Early reflections.** These correlate at 0.41 ± 0.13 at the same position, against 0.25 at others.
  With the initial materials the correlation is 0.42. The scattered part's random detail moves this by
  about ±0.06 from one random seed to another (see [Chairs as fitted zones](#chairs-as-fitted-zones-1)).

### The early decay at 63 Hz

The first version of this comparison found the 63 Hz early decay far too slow: EDT 2.90 s against
1.80 s measured, and C80 and D50 2.3–2.4 JND low, with T30 within 2%. Looking for the cause found the
two faults in the analysis described under [Method](#method), and a third in the wave solver. In a room
built as a mesh, the solver grouped bands into runs by the box's materials, which a mesh leaves rigid,
not by the mesh's faces, so every band shared one run whose walls took the mean absorption of all its
bands. Each band now has its own; in the two halls that takes two or three runs, so the budget lowers
the crossover, to 71–73 Hz here instead of 89–96 Hz, and to 85–94 Hz in the chamber music hall instead
of about 110 Hz. The solver's matching to Eyring's decay also now measures each band as the comparison
does, closed below 31 Hz. With all of this corrected, C80, D50 and centre time at 63 Hz agree within
1.5 JND, and the measured T30 is 2.52 s, not 2.89 s. But EDT remains 7.8 JND long, and T30 is now 14%
long. What was tested, from loudspeaker 1 to the five microphones, in the 63 Hz octave:

| | EDT (s) | T20 (s) | T30 (s) | C80 (dB) |
|---|---|---|---|---|
| Measured | 1.76 | 2.37 | 2.49 | 1.2 |
| As compared above: walls with each band's absorption, crossover 72 Hz | 2.34 | 2.83 | 2.79 | 1.0 |
| The same, bare: not matched to Eyring's decay | 2.60 | 3.06 | 3.01 | 0.5 |
| The same with the crossover at 96 Hz | 2.63 | 2.58 | 2.55 | 0.9 |
| The same, bare | 3.45 | 3.28 | 3.34 | −0.5 |
| Walls with the bands' mean absorption, as before, crossover 96 Hz | 2.37 | 2.53 | 2.48 | 1.4 |
| The same, bare | 3.24 | 3.15 | 3.11 | 0.1 |
| The same with the crossover at 150 Hz, and cells of 16 cm instead of 25 cm | 2.45 | 2.38 | 2.44 | 0.7 |
| The same with the crossover at 70 Hz | 2.50 | 2.67 | 2.77 | 1.1 |

(The last four runs damped each band as measured over the band before it was closed below.) These rule
out:

- **The damping to Eyring's decay.** Bare, the solver's decay is as straight as when it is damped: EDT
  is within 15% of T30, against 33% shorter measured. The damping applies e^(−Δt) from the direct sound
  on, which shortens the early and the late decay alike; it does not straighten a curved decay, because
  there is none to straighten.
- **The crossover and the grid.** With the crossover at 70, 96 or 150 Hz, the 63 Hz octave entirely
  wave-solved at 150 Hz with cells a third smaller, EDT is 2.37–2.50 s.
- **The walls' impedance in each band.** Each band's own absorption, or the bands' mean, give EDT 2.63
  and 2.37 s at the same crossover.
- **The source.** The 63 Hz octave is entirely the low-frequency driver's, simulated at its own
  height, below its 177 Hz crossover. Within the octave, from 50 to 80 Hz, the measured and simulated
  levels agree within 2 dB; at 40 and 100 Hz the simulated ones are 5–7 dB higher against 63 Hz. That
  does not explain the slow decay: every third octave from 63 to 100 Hz has a simulated EDT 0.3–1.1 s
  longer than measured.
- **The receivers.** At 63 Hz a wavelength spans 16 cells or more, and the finer grid changed nothing.
- **Onsets and noise.** Timing the band from the broadband direct sound instead of its own onset, or
  leaving out the noise compensation, changes the measured EDT by 0.05 s or less.

What remains is the shape of the measured decay within the octave. Its two halves decay differently:

| | 44–63 Hz EDT | T30 | 63–88 Hz EDT | T30 | 88–125 Hz EDT | T30 |
|---|---|---|---|---|---|---|
| Measured | 2.18 | 2.68 | 1.56 | 2.11 | 1.84 | 2.19 |
| Fitted to this model | 2.33 | 2.72 | 2.51 | 3.04 | 2.57 | 2.98 |
| Fitted by simulating this model | 2.15 | 2.40 | 2.40 | 2.50 | 2.26 | 2.31 |

Below 63 Hz the model matches the measurement: EDT within 7% and T30 within 2%. Above it the hall
decays much faster, with T30 2.1–2.2 s against 2.7 s below and 2.4 s in the 125 Hz octave, so something
in the real hall absorbs most around 63–100 Hz; panels, windows and the seating's cavities are
candidates. The octave's T30, which the materials are fitted to, is set by its slower lower half, which
dominates the late decay; its early decay is set by both halves. RoomCAD gives each material one
absorption per octave, and the wave solver one impedance, so the model decays at nearly one rate
across the octave and cannot follow it. The upper half also lies above the 72 Hz crossover, where the
geometrical model's decay is too long, as at 125 Hz (+20%). The pattern is milder in the other rooms:
from 63 to 88 Hz the measured EDT is 1.30 s and 1.17 s in the chamber music hall and the seminar room,
against 1.82 s and 1.38 s simulated, while below 63 Hz the model is within 10–13%. At 63 Hz EDT is
2.7 JND long in the chamber music hall, and within 0.4 JND in the seminar room, whose 63 Hz band the
wave solver holds entirely. Representing it would need absorption in third octaves.

### Chairs as fitted zones

`CR4_ModelSimplifications.pdf` counts 1,172 chairs: 418 on the rake and 12 in the last row in each half
of the stalls, 26 on each side gallery and 260 on the rear balcony (BRAS's list of materials gives 1,192
seats). The configuration **fitted to this model, with chairs** adds them as fitted zones 0.9 m high, each
chair with an estimated 1.5 m² of surface, as in CR3. Zones are boxes, so over the rake and the galleries
they are cut into lengths, each at its middle's floor height. T30, against the measurement:

| | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|
| Without chairs | +20% | +12% | +15% | +14% | +9% | +9% | +12% |
| With chairs | +10% | +13% | +16% | +17% | +13% | +13% | +15% |

Unlike in the chamber music hall, the chairs shorten the decay only at 63 and 125 Hz, by 6% and 8%.
From 250 Hz to 8 kHz they lengthen it by 0–4%. At 500 Hz they raise C80 by 0.6 dB; at 125 Hz they lower
D50 by one JND. Elsewhere clarity, definition and centre time change by less than a JND. They lower
the early reflections' correlation from 0.41 to 0.28 ± 0.16, against 0.15 at other positions.

**What the zones do to the early sound.** The direct sound crosses no zone at any pair, for any driver:
the receivers are 0.23–0.33 m above the zones, and the line from the stage passes over them. The
reflection from the seating floor does cross them, at eight of the ten pairs. It arrives 1.0–2.5 ms
after the direct sound, at 11–30° above the rake, and crosses the 0.9 m of chairs twice at a slant, so
the image sources keep it 10–36 dB weaker; the rays carry the rest as scattered energy. Grazing sound
over real seating is attenuated too: the seat-dip effect is a dip of 10–20 dB at about 100–250 Hz for
sound passing close over the seats, weaker at steeper angles, caused by interference between the
direct sound and the sound reflected by the seats and the spaces between them (Schultz and Watters,
1964; Sessler and West, 1964; Bradley, 1991). Above it, the seat backs reflect sound at grazing
incidence rather than absorbing all of it. A zone of objects scattered at random, which takes the same
toll in every band, removes that reflection at all frequencies.

Each configuration below was run four times, with random seeds 1 to 4, from both loudspeakers and
without the wave solver, which the early reflections above 500 Hz do not depend on:

| Early reflections, same position | Seeds 1–4 | Mean |
|---|---|---|
| No chairs | 0.41, 0.47, 0.47, 0.45 | 0.45 |
| Chairs as zones | 0.28, 0.39, 0.39, 0.33 | 0.35 |
| Chairs as zones, before the timing fix below | 0.30, 0.42, 0.40, 0.42 | 0.39 |
| No chairs, before the timing fix | 0.51, 0.47, 0.40, 0.45 | 0.46 |
| The stalls' seating as a block 0.9 m high, galleries' and balcony's chairs as zones | 0.29, 0.36, 0.42, 0.29 | 0.34 |

- **The random seed.** The correlation moves by up to about ±0.06 between seeds, so the earlier 0.51
  against 0.31 overstated the chairs' effect: averaged over seeds, the zones lower it by about 0.1.
- **Timing.** The receivers' spheres have a radius of 2.1 m here and reach into the zones, and rays
  scattered by chairs inside a sphere were counted up to 6 ms before the direct sound, 15–40 dB below
  it, which moved the onset of two pairs by 1.4–2.1 ms. They are now timed by their path through the
  chair (see [Scattered energy](room-acoustics-model.md#scattered-energy)). This is a correction, but it
  does not improve the correlation: within the spread between seeds, it is unchanged without chairs and
  0.04 lower with them.
- **An audience block.** Geometrical models often represent seating as a block at the height of the
  seat backs, whose top reflects. Built that way, the hall's early reflections correlate no better than
  with zones (0.34), and worse than with the seating as a layer on the floor (0.45).

So the zones do take away early reflections that the measured responses keep, but neither the
audience block nor a correction to the timing recovers them, and no model of seating tested here
matches the early sound better than leaving the chairs out. The model is left as it is.

### Fitted by simulating the model

The fit kept, in each band, the closest of six simulations. The absorption rose by 9–27% from 63 Hz to
4 kHz, most at 125 Hz, and by 69% at 8 kHz.

| | | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
|---|---|---|---|---|---|---|---|---|---|
| T30 (s) | Measured | 2.52 ± 0.16 | 2.40 ± 0.09 | 2.38 ± 0.06 | 2.07 ± 0.04 | 2.10 ± 0.04 | 1.85 ± 0.02 | 1.42 ± 0.01 | 0.94 ± 0.01 |
| | Simulated | 2.45 (−0.6) | 2.27 (−1.1) | 2.33 (−0.4) | 2.07 (+0.0) | 2.10 (+0.0) | 1.85 (+0.0) | 1.43 (+0.2) | 0.96 (+0.5) |
| EDT (s) | Measured | 1.68 ± 0.23 | 2.21 ± 0.35 | 2.42 ± 0.14 | 2.09 ± 0.10 | 2.19 ± 0.14 | 1.86 ± 0.09 | 1.42 ± 0.10 | 0.83 ± 0.08 |
| | Simulated | 2.27 (+7.1) | 2.22 (+0.0) | 2.38 (−0.4) | 2.08 (−0.1) | 2.09 (−0.9) | 1.79 (−0.7) | 1.36 (−0.9) | 0.77 (−1.5) |
| C80 (dB) | Measured | 1.2 ± 1.9 | −0.6 ± 1.6 | −1.8 ± 2.5 | 0.3 ± 1.7 | −0.6 ± 1.2 | −0.0 ± 0.8 | 2.0 ± 2.0 | 5.5 ± 1.5 |
| | Simulated | 1.6 (+0.4) | −1.3 (−0.8) | −1.6 (+0.2) | −0.4 (−0.7) | −0.6 (+0.1) | 0.5 (+0.5) | 2.3 (+0.3) | 6.0 (+0.5) |
| D50 | Measured | 0.45 ± 0.11 | 0.32 ± 0.08 | 0.28 ± 0.14 | 0.40 ± 0.10 | 0.35 ± 0.08 | 0.37 ± 0.07 | 0.47 ± 0.15 | 0.63 ± 0.11 |
| | Simulated | 0.47 (+0.4) | 0.33 (+0.1) | 0.29 (+0.3) | 0.38 (−0.3) | 0.37 (+0.4) | 0.41 (+0.8) | 0.51 (+0.8) | 0.67 (+0.9) |
| Ts (ms) | Measured | 120 ± 19 | 147 ± 12 | 166 ± 31 | 127 ± 21 | 142 ± 14 | 125 ± 11 | 91 ± 21 | 54 ± 13 |
| | Simulated | 126 (+0.6) | 155 (+0.8) | 167 (+0.1) | 136 (+0.9) | 139 (−0.4) | 117 (−0.8) | 86 (−0.5) | 50 (−0.4) |

- **T30.** It now matches within 1.1 JND in every band.
- **The shape of the decay.** From 125 Hz to 8 kHz, EDT, C80, D50 and centre time are all within about
  1.5 JND. Here, unlike in the chamber music hall, matching T30 does not leave the early decay too
  fast: the simulated decay has the measured shape. The fan-shaped plan, the splayed and stepped
  surfaces and the hung panels mix the sound better than the chamber music hall's simplified box.
- **63 Hz.** EDT is still 7.1 JND long, for the reason [above](#the-early-decay-at-63-hz); C80, D50 and
  centre time are within 0.6 JND.
- **Early reflections.** These correlate at 0.39 ± 0.16, against 0.21 at other positions.

A run of `acousticbench --bras-cr4` takes about 24 minutes on a Mac Studio (M4 Max): 100–120 s for each
source in each configuration with the wave solver, and the six calibration simulations.

## What the comparison shows

1. **Mid frequencies.** In the seminar room, from 250 Hz to 2 kHz, with only published material data,
   RoomCAD predicts reverberation time within 12%, and clarity and definition within about one JND.
   In the chamber music hall, with materials fitted to the model, clarity, definition and centre time
   are within about one JND from 500 Hz to 4 kHz. In the auditorium, C80 and D50 are within one JND
   from 1 to 4 kHz.
2. **Diffuseness.** With absorption fitted so that Eyring's formula gives the measured T30, the
   geometrical model decays more slowly than the measurement, because the simplified rooms are not
   fully diffuse: 7–17% from 125 to 500 Hz in the seminar room, 12–41% in the chamber music hall, and
   9–20% from 125 Hz to 8 kHz in the auditorium.
   Fitting materials to a measured T30 should therefore be done with RoomCAD itself rather than with
   Eyring's formula, which `AbsorptionCalibration` now does. In the seminar room, absorption fitted
   that way leaves EDT, clarity, definition and centre time within about 1.1 JND from 500 Hz to 4 kHz.
   In the chamber music hall, it shows the simplified hall's decay sagging at 125 and 500 Hz. In the
   auditorium, whose fan-shaped plan, stepped surfaces and hung panels mix the sound better, it leaves
   EDT, clarity, definition and centre time within about 1.5 JND from 125 Hz to 8 kHz.
3. **Scattering by objects.** A hall simplified to smooth surfaces needs the scattering of its
   pillars, ornament and seating put back. Raising every surface's scattering to at least 0.5 halves
   the chamber music hall's excess decay.
4. **Low-frequency modes.** In the seminar room, the wave solver reproduces the modal fine structure
   and its position dependence, with mode frequencies within about 1.5%. In the hall, whose modes
   overlap above 40 Hz, neither model reproduces the fine structure, nor is it expected to. In the
   auditorium, the wave solver, below about 72 Hz, gives a weak but position-specific correlation
   (0.23, against −0.00 at other positions and 0.03 without it).
5. **Low-frequency decay.** The bare wave solver's locally reacting walls let modes that graze them
   outlast a diffuse field, by 10–40% here. With each band matched to the diffuse decay, the solver
   gives the measured T30, EDT, clarity and definition at 63 and 125 Hz within about 2 JND in the
   seminar room, and T30 at 63 Hz within 4% in the hall. In the auditorium clarity and definition at
   63 Hz agree, but T30 is 14% long and EDT 2.33 s against 1.68 s. The measured hall decays much faster
   from 63 to 125 Hz than below 63 Hz, which absorption given per octave cannot follow; below 63 Hz the
   model matches it.
6. **Early reflections.** These follow the measured pattern at most positions in all three rooms
   (correlation 0.61, 0.49 and 0.41, against 0.22–0.25 at the wrong position). The scattered part's
   random detail moves them by about ±0.06. In the auditorium, chairs as uniform fitted zones lower the
   correlation by about 0.1, averaged over random seeds; neither modelling the seating as a block nor
   a correction to the rays' timing recovers it.
7. **Published low-frequency absorption.** For walls such as plaster and concrete, it is much lower
   than real rooms behave, in all three rooms, which a designer must allow for.
8. **Measuring the edge bands.** Measured as octaves, closed like the others, the 63 Hz and 8 kHz
   bands agree much better than before. The slow 8 kHz early decay once put down to the source's
   directivity came mostly from what the measured band held above its octave: fitted by simulating the
   model, EDT, C80 and D50 at 8 kHz are now within 3 JND in the seminar room and 1.5 JND in the halls.

## Limitations of the comparison

- **Three rooms.** Two are rectangular in essence; the auditorium has a fan-shaped plan, a raked floor
  and rising galleries. BRAS's reference scenes RS1–7 and its first complex room, CR1, which is coupled
  to a reverberation chamber, are not compared.
- **Large objects.** The chairs of the chamber music hall and the auditorium are modelled as fitted
  zones, with an estimated surface area each. Zones are boxes, so over the auditorium's rake and
  galleries they are cut into lengths. A zone takes the same toll of the early reflections in every
  band, where real seating's attenuation of grazing sound is concentrated in the seat dip. The halls'
  pillars and ornament, and the auditorium's folded ceiling, stairs and corner lobbies, are not
  modelled.
- **Octave bands.** Materials, and the wave solver's walls, are given one absorption per octave. The
  auditorium's measured decay changes markedly within the 63 Hz octave.
- **The source.** It is treated as omnidirectional, at each driver's height. Its directivity, the
  size of its drivers, and the crossover's phase are not modelled.
- **Geometry.** It is simplified, as listed above, and wall materials are averaged by area.
- **Fitted estimates.** They were fitted to the measured times with Eyring's formula, so they are not
  an independent prediction; they test the model's shape of decay.
- **Not a listening test.** The roadmap asks for listening comparisons as well; these have not been
  made.

## Tests

`MeasuredRoomTests` keeps parts of this comparison in the regular test suite, using the fixture:

- the simplified room's volume and material averaging;
- the early-reflection correlation, above 0.55 at the same position and below 0.35 at others;
- that the chamber music hall's solids make a valid closed room, within 10% of BRAS's volume, with
  every source and receiver inside;
- that refitting its materials makes Eyring's estimate the time asked for, within 1%;
- that the auditorium's solids make a valid closed room, within 10% of BRAS's volume, with every
  receiver and every driver of both loudspeakers inside, and 1,172 chairs in fitted zones whose
  centres are in the room.

The decay and wave-solver comparisons take minutes in a debug build. They run in the bench and are
not part of the tests.

## Sources

- L. Aspöck, M. Vorländer, F. Brinkmann, D. Ackermann and S. Weinzierl, *Benchmark for Room
  Acoustical Simulation (BRAS)*, TU Berlin and RWTH Aachen, 2020, DOI 10.14279/depositonce-6726.3,
  https://depositonce.tu-berlin.de/items/38410727-febb-4769-8002-9c710ba393c4, CC BY-SA 4.0.
- ISO 3382-1:2009, *Acoustics — Measurement of room acoustic parameters — Part 1: Performance
  spaces*, for the parameters and their just-noticeable differences.
- A. Lundeby, T. E. Vigran, H. Bietz and M. Vorländer, "Uncertainties of measurements in room
  acoustics", *Acustica* 81, 344–355, 1995, for the treatment of background noise.
- H. Kuttruff, *Room Acoustics*, 6th edn, CRC Press, 2016, for decay in rooms that are not diffuse.
- T. J. Schultz and B. G. Watters, "Propagation of sound across audience seating", *J. Acoust. Soc.
  Am.* 36, 885–896, 1964; G. M. Sessler and J. E. West, "Sound transmission over theatre seats",
  *J. Acoust. Soc. Am.* 36, 1725–1732, 1964; J. S. Bradley, "Some further investigations of the seat
  dip effect", *J. Acoust. Soc. Am.* 90, 324–333, 1991, for sound passing over seating.
