### Purpose
Authoritative rules for flat barbell bench press scoring from iPhone video (single 2D view). Use this rubric to instruct the LLM on **what** to measure and **why**. The JSON schema lives in a separate file.

## Technique Standard (flat bench)
**Setup & Start.** Eyes under bar, medium grip ~1.5–2× shoulder width; neutral wrists (knuckles up); scapulae **retracted & depressed**; moderate thoracic arch while **head/shoulders/hips** stay on bench; feet flat and planted for leg drive.

**Descent.** Control the bar to a **lower-chest touch** (lower pecs to just below xiphoid). Elbows ~**45–70°** from torso for medium grip (wider grips flare more; close grips tuck more). Forearms vertical at bottom. **No bounce.**

**Press.** Initiate with **leg drive** while keeping hips down. Follow a slight **"J-curve"**: up and **back** toward shoulders early, then vertical to lockout; finish with bar **over the shoulder joint**. Maintain scapular retraction.

**Lockout & Rack.** Full elbow extension, symmetrical arms. Re-rack by moving bar back to uprights, then down.

## Recommended Bar Path & Joint Targets
- **Bar path corridor:** chest touch below nipples → back toward shoulders → up. Typical backward drift **~5–10 cm** chest→top; deviations outside corridor are penalized.
- **Elbow flare (bottom):** target **45–70°** (medium grip). >80–85° = over-flare (major); <30–40° = over-tuck (contextual). Check with **forearm verticality** at bottom.
- **Wrist extension:** neutral best; **≤15°** optimal, **15–30°** acceptable; **>30°** poor; **>50°** severe. Penalize in tiers.
- **Scapulae:** maintain retraction/depression throughout; visible protraction/elevation during press = fault.
- **Leg drive/feet:** feet flat, planted; drive horizontally; **no hip lift**.
- **ROM:** generally full ROM (touch chest → lockout). Gentle **soft touch or brief pause** preferred; **no bounce**.

## Red-Flag Faults (penalize via schema)
- **Hips off bench** (any daylight) → serious fault.
- **Bounce** off chest → major penalty. Soft touch OK with small deduction vs paused.
- **Excessive wrist extension** per tiers; **uneven lockout/asymmetry** (bar tilt or timing); **head off bench**; **foot instability**; **scapular protraction**; **extreme elbow flare**; **gross bar-path drift**. See JSON penalties.

## Intensity (effort) from video only
- **Rep-time / velocity decay across set:** larger slowdown from early to last rep indicates higher effort (e.g., >25–40% drop = high effort). Map decay to points.
- **Cadence stability:** low variance ≤0.15 s is best; >0.5 s indicates erratic pacing or rests → penalties.
- **ROM maintenance:** preserve depth and lockout under fatigue. >5–10% ROM loss late = deductions.
- **Grind factor:** very slow final concentric (e.g., >2 s or very low velocity) = near-failure; rewarded if form maintained.

## Camera & Measurement Notes (2D iPhone)
- **Angle:** prefer **~45° front-side** at bench height, 2–3 m away; alternative side view acceptable. Tolerances applied for parallax/foreshortening.
- **Landmarks:** bar position, shoulders, elbows, wrists, hips, feet. Forearm verticality at bottom; bar-to-shoulder horizontal distance chest→mid→top.
- **Frame-rate:** 60 fps ideal; we smooth timing and use broad thresholds when fps lower.

## Scoring Overview
- **Form (0–100):** starts at 100; subtract weighted penalties (see JSON).
- **Intensity (0–100):** built from decay, cadence, ROM, grind (see JSON).
- **Holistic (0–100):** default **0.5·Form + 0.5·Intensity** (adjustable later).

**Beginner cue sheet (for feedback):**
- Feet planted + leg drive; hips down; even lockout; J-curve path; soft chest touch (no bounce); neutral wrists; eyes up/fixed; keep scapulae retracted. Include simple drills (e.g., pause/Spoto press, Larsen press, wrist wrap guidance).
