# Galaga 3D: Vanguard — Design Specification

- **Date:** 2026-11-19
- **Engine:** Godot 4.7 (`/opt/homebrew/bin/godot`, GDScript strictly typed)
- **Project Directory:** `/Users/kjw5541/.gemini/antigravity/scratch/galaga-3d`
- **Genre:** 3D Third-Person Rail-Corridor Arcade Shooter (Star Fox perspective × Galaga core loop)
- **Visual Style:** Low-Poly Sci-Fi / Neon Arcade 3D (procedural meshes + emissive materials + ACES Glow)
- **Primary Platform & Controls:** PC (Gamepad & Keyboard-centric aiming; optional mouse offset not required)

---

## 1. Core Concept & Perspective

Classic Galaga's top-down formation loop is reimagined as a **3D Depth-Layered Rail Arena** viewed from behind the player's starfighter:

- **Coordinate System (Godot 3D right-handed):** `+X` right, `+Y` up, `-Z` forward into the screen, `+Z` toward the camera.
- **Forward Motion Illusion:** High-speed 3D starfield (`GPUParticles3D`) and neon space-corridor depth rings stream continuously from `Z = -180` toward `Z = +20`, delivering rail-shooter speed without breaking formation readability.
- **Player Playplane (`Z = 0`):** The player's fighter maneuvers freely across `X ∈ [-14.0, 14.0]`, `Y ∈ [-8.0, 8.0]`.
- **Enemy Depth Space (`Z = -160` to `+10`):** Squads enter from deep space (`Z = -150`) along 3D `Path3D` splines, dock into a hovering 3D formation grid at `Z = -46` to `-54`, and dive straight toward the player's plane (`Z → +10`) before looping back into formation.

---

## 2. Camera, Controls & Aiming

### 2.1 Camera
- **Position:** Smoothly follows player at `(player.x * 0.25, player.y * 0.20 + 3.2, 12.5)` with damping (`lerp` weight `6.0 * delta`).
- **Look Target:** `(player.x * 0.15, player.y * 0.10, -35.0)`.
- **FOV & Juice:** Base `60°`, widens to `65°` briefly during Barrel Roll; decayed trauma-based camera shake on damage, EMP pulse, and boss explosions.

### 2.2 Controls (Gamepad + Keyboard First)
All actions are configured in `project.godot` `InputMap`:

| Action | Keyboard | Gamepad | Behavior |
|---|---|---|---|
| `move_left` / `move_right` | `A`/`D`, `←`/`→` | Left Stick X, D-Pad | X-axis movement (`22 u/s`), fighter banks up to `±28°` roll |
| `move_up` / `move_down` | `W`/`S`, `↑`/`↓` | Left Stick Y, D-Pad | Y-axis movement (`18 u/s`), fighter pitches up to `±16°` |
| `fire_primary` | `Z`, `J`, `Space` | South (`A`/`Cross`), RT | Tap or hold for twin lasers (`0.16s` interval; `0.09s` with Rapid) |
| `fire_lockon` | `X`, `K` | West (`X`/`Square`), RB | Hold to paint up to 4 targets inside reticle cone; release to fire homing missiles |
| `barrel_roll` | `Left Shift`, `C`, `L` | East (`B`/`Circle`), LB | `0.45s` 360° roll (`0.32s` invulnerable + lateral burst), `1.5s` cooldown |
| `emp_pulse` | `V`, `U` | North (`Y`/`Triangle`) | Consumes 1 EMP charge: clears enemy bullets and stuns diving enemies for `2.0s` |
| `pause` | `Esc` | Start | Toggle pause menu |

### 2.3 Dual 3D Reticle & Soft Aim Assist
- **Linked Aiming:** Movement drives the ship's nose and projects two aligned 3D wireframe reticles ahead of the fighter at `Z = -22` (near outer bracket) and `Z = -50` (far inner diamond). Optional right-stick input adds up to `±4°` fine aim lead without moving the fighter.
- **Laser Vector:** Lasers fire from fighter wingtip muzzles toward the far reticle world point (`Z = -50`).
- **Arcade Soft Magnetism:** If an enemy center lies within a `1.8`-unit cylindrical radius around the aim ray at that enemy's Z-depth, laser shots subtly converge onto the target to ensure crisp 3D depth hit feedback.

---

## 3. Core Gameplay Mechanics

### 3.1 Stage Cadence (Unambiguous Rule)
Stage type is determined purely by `stage_number` (1-indexed):
1. `stage_number % 5 == 0` → **Boss Stage** (Stages 5, 10, 15…)
2. `else if stage_number % 3 == 0` → **Bonus (Challenge) Stage** (Stages 3, 6, 9, 12…)
3. `else` → **Standard Formation Wave** (Stages 1, 2, 4, 7, 8…)

### 3.2 Standard Formation Wave & Enemy Archetypes
Each standard wave deploys **40 enemies** arranged in a 3D breathing grid (`sway_x = ±2.0`, `sway_y = ±0.6`):

| Archetype | Row & Depth | Count | HP | Visual Trim | Score (Form / Dive) | Dive Pattern |
|---|---|---|---|---|---|---|
| **Boss Galaga** | Row 0 (`Z = -54`) | 4 | 2 | Neon Green `#39FF14` → Blue `#00D4FF` at 1 HP | `150` / `400` (`800` w/ 1 escort, `1600` w/ 2 escorts) | Escort formation dive OR Tractor Beam capture dive |
| **Goei (Butterfly)** | Rows 1–2 (`Z = -50`) | 16 | 1 | Neon Magenta `#FF2E88` | `80` / `160` | 3D corkscrew helix toward player + 1–2 aimed energy orbs |
| **Zako (Bee)** | Rows 3–4 (`Z = -46`) | 20 | 1 | Neon Amber `#FFB800` | `50` / `100` | S-curve sweep toward player; loops from rear back to slot |

- **Entry Choreography:** 5 squads of 8 units enter sequentially from `Z = -150` along authored `Path3D` splines (top dive, left/right helical loops, lower sweep) before slotting into the grid.
- **Difficulty Scaling:** Wave speed multiplier `1.0 + 0.06 * (stage - 1)` (capped at `1.8`), max simultaneous divers scales from `2` (Stage 1) to `5` (Stage 8+), dive fire frequency increases gradually.

### 3.3 3D Tractor Beam & Dual Fighter System
- **Eligibility:** A Boss Galaga may initiate `TRACTOR_BEAM` dive only when the player is in `SINGLE` fighter state, no fighter is currently captured, and at least `12s` have elapsed since the previous tractor attempt.
- **Beam Deployment:** Boss dives to `(target_x, target_y + 3.0, -14.0)`, holds `3.0s`, and emits a downward/forward conical neon cyan-violet beam (`Area3D`, radius `2.8` at `Z = 0`).
- **Capture Resolution:** Staying inside the beam for `0.65s` while not invulnerable captures the fighter:
  1. Fighter spins upward and attaches to Boss's top capture mount (`offset (0, +2.2, 0)`), material tinted hostile red.
  2. Boss returns to its formation slot carrying the captured fighter.
  3. Player loses 1 life; if `lives > 0`, a fresh Single Fighter spawns after `1.5s` with `2.5s` invulnerability.
- **Rescue vs. Hostile Turn:**
  - **Boss destroyed while `DIVING` with captured ship:** Captured fighter switches to friendly cyan, descends to `Z = 0` alongside player, and docks → **`DUAL` Fighter** mode (`+1000` rescue bonus).
  - **Boss destroyed while `IN_FORMATION` with captured ship:** Captured fighter detaches as a hostile red unit, performs one high-speed dive toward the player, then exits (`+1000` if destroyed).
  - **Player shoots captured fighter directly:** Captured fighter explodes; no rescue.
- **Dual Fighter Properties:**
  - Two wing-linked fighters (`offset X = ±1.25`), firing 4 laser beams per volley (2 per ship).
  - Combined hitbox width increases from `1.6` to `3.4`.
  - Taking a non-shielded hit destroys only the struck wing fighter and downgrades cleanly to `SINGLE` mode with `1.8s` invulnerability (no life lost).

### 3.4 Bonus (Challenge) Stage
- **Structure:** 5 sequential waves × 8 unarmed drones (`40` total) traversing sweeping 3D `Path3D` ribbons across `Z = -90 → -15 → +10` without firing or colliding fatally (passing behind player simply exits).
- **Scoring:** `100` per enemy destroyed, `+1000` per full wave (8/8) cleared, and **`+10,000` Perfect Bonus** if all 40 enemies are destroyed. Summary overlay displays hits/40 and bonus breakdown for `3.0s` before advancing.

### 3.5 3D Weapons & Power-Up Capsules
- **Multi-Lock-On Homing Missile (Built-in Secondary):**
  - Energy gauge `0..100` (starts full at `100`, passive regen `+12/s`, `+6` per primary laser hit).
  - Holding `fire_lockon` scans enemies/boss sub-parts within a `4.5`-unit cone around the aim ray, painting up to `4` unique diamond lock-on HUD brackets (preferring diving enemies and exposed boss parts).
  - Releasing `fire_lockon` spends `25` energy per locked target and launches curved homing missiles (`damage = 2`, speed `95 u/s`, strong steering).
- **Power-Up Capsules:**
  - Drop rule: Guaranteed 1 drop from a diving Boss Galaga kill (max 2 drops per standard wave) + `15%` chance on diving Goei kills.
  - Capsules drift from kill depth to `Z = 0` at `18 u/s`, gently magnetized toward player within `3.5` units.
  - Types (weighted cycle):
    - `SHIELD` (Cyan): 1-hit energy barrier per active fighter (max 1 stack per fighter).
    - `RAPID` (Orange): Primary fire interval `0.16s → 0.09s`, projectile speed `120 → 160 u/s` for `15.0s`.
    - `EMP` (Violet): `+1` EMP Pulse charge (max `2` stored).

### 3.6 Boss Stage: Queen Galaga Dreadnought (Stage 5, 10, 15…)
- **Entrance:** Warps from `Z = -150` to combat plane `Z = -55`, executing slow figure-8 sway (`±6.0 X, ±2.0 Y`).
- **Multi-Part Architecture:**
  1. **Left Tractor Cannon** (`HP = 18 + stage * 2`): Periodically fires sweeping laser beams and tractor hazard pulses toward the player plane.
  2. **Right Swarm Hangar** (`HP = 18 + stage * 2`): Launches 3-unit Zako drone squads on curved 3D dives every `8.0s`.
  3. **Central Core** (`HP = 40 + stage * 4`): Armored (`50%` damage reduction, metallic blue shield glow) while either flank module is alive. Once both flanks are destroyed, enters **Phase 2** (core turns incandescent crimson, `100%` damage, fires 3D spiral orb rings and rapid lunge sweeps).
- **Victory:** Destroying the Central Core triggers staggered explosions, awards `5000 * (stage / 5)` points, refills 1 Shield, and advances to the next stage.

---

## 4. Technical Architecture (Godot 4.7)

### 4.1 Physics Collision Layers
1. `player` (bit 1)
2. `player_projectile` (bit 2)
3. `enemy` (bit 3)
4. `enemy_projectile` (bit 4)
5. `tractor_beam` (bit 5)
6. `pickup` (bit 6)

### 4.2 Directory & Scene Structure
```text
galaga-3d/
├── project.godot
├── docs/superpowers/specs/2026-11-19-galaga-3d-design.md
├── autoload/
│   ├── game_state.gd            # Run state, score, lives, dual/powerup state, signal bus
│   └── sfx_manager.gd           # Procedural arcade Web/PCM AudioStreamGenerator SFX
├── scripts/
│   ├── visuals/
│   │   └── mesh_factory.gd      # Procedural low-poly neon ArrayMesh/PrimitiveMesh builders
│   └── data/
│       └── wave_patterns.gd     # 3D Path3D spline definitions & stage routing logic
├── scenes/
│   ├── main.tscn / main.gd      # Root orchestrator, WorldEnvironment, Camera3D, starfield, stage flow
│   ├── player/
│   │   ├── player_fighter.tscn / player_fighter.gd
│   │   ├── reticle_rig.gd       # Dual 3D reticle + lock-on cone scanner
│   │   └── projectile.tscn / projectile.gd  # Player laser, homing missile, enemy orb
│   ├── enemies/
│   │   ├── formation_manager.tscn / formation_manager.gd
│   │   ├── enemy_unit.tscn / enemy_unit.gd
│   │   ├── tractor_beam.tscn / tractor_beam.gd
│   │   └── queen_boss.tscn / queen_boss.gd
│   ├── pickups/
│   │   └── powerup_capsule.tscn / powerup_capsule.gd
│   └── ui/
│       └── hud.tscn / hud.gd    # Score, lives, stage banner, lock-on brackets, EMP/energy bars, game over
└── tests/
    └── run_headless_checks.gd   # Headless Godot verification script (state transitions & math)
```

### 4.3 Component Boundaries & Data Flow
- **`GameState` (Autoload):** Single source of truth for `score`, `high_score`, `lives` (starts `3`, extra life at `20,000` and every `70,000`), `stage`, `fighter_mode` (`SINGLE` / `DUAL`), `shield_count`, `rapid_timer`, `emp_charges`, `lockon_energy`. Emits typed signals (`score_changed`, `lives_changed`, `stage_started`, `fighter_mode_changed`, `emp_triggered`, `game_over`) so HUD and audio stay decoupled from gameplay nodes.
- **`Main`:** Owns stage lifecycle (`TITLE` → `STAGE_INTRO` → `PLAYING` → `STAGE_CLEAR` → `GAME_OVER`), spawns either `FormationManager` (Standard/Challenge) or `QueenBoss` (Boss), and manages hit-stop / camera shake via signals.
- **`FormationManager`:** Owns slot grid, entry `Path3D` spawning, dive scheduler, tractor beam cooldown, and Challenge Stage 40-enemy tracking.
- **`EnemyUnit`:** Self-contained finite state machine (`ENTERING`, `FORMATION`, `DIVING`, `TRACTOR_BEAM`, `RETURNING`, `CAPTURED_HOSTILE`, `RESCUED_DOCKING`).
- **`PlayerFighter`:** Consumes `InputMap`, updates movement/banking/barrel-roll, delegates aiming/lock-on to `ReticleRig`, and reacts to `GameState` fighter mode changes (`SINGLE` ↔ `DUAL`).

---

## 5. Error Handling & Verification Plan

- **Null/Lifecycle Safety:** All lock-on target references and escort/captured-fighter references are validated with `is_instance_valid()` before access; freeing an enemy emits cleanup signals so `FormationManager` and `ReticleRig` never hold dangling nodes.
- **Static Analysis:** Every GDScript file uses explicit static typing and must pass `godot-plugin_godot:validate_scripts` with zero errors.
- **Headless Automated Self-Checks (`tests/run_headless_checks.gd`):**
  1. Stage routing (`1,2,4 → STANDARD`, `3,6,9 → CHALLENGE`, `5,10,15 → BOSS`).
  2. Tractor capture → diving rescue → `DUAL` upgrade, vs. formation kill → hostile turn (no upgrade).
  3. Dual fighter damage downgrades to `SINGLE` without decrementing lives.
  4. Lock-on cap (`<= 4`) and energy cost/recharge boundaries.
  5. Challenge stage perfect bonus (`40/40 → +10,000`) and wave clear bonus.
  6. Queen Boss flank-armor (`50%` mitigation) vs. Phase 2 full core damage (`100%`).
- **Runtime Verification:** Run project via `godot-plugin_godot:run_project`, verify zero runtime errors (`game_get_errors`), and capture gameplay screenshot (`game_screenshot`) to confirm neon 3D framing, dual reticle alignment, and formation visibility.
