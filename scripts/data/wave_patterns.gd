class_name WavePatterns
extends RefCounted

const ROW_COUNTS: Array[int] = [4, 8, 8, 10, 10]
const ROW_DEPTHS: Array[float] = [-54.0, -51.0, -49.0, -47.0, -45.0]
const ROW_Y: Array[float] = [6.0, 3.3, 0.8, -1.7, -4.2]
const COL_SPACING := 2.6


static func get_formation_slot_local(row: int, col: int) -> Vector3:
	var r: int = clampi(row, 0, ROW_COUNTS.size() - 1)
	var count: int = ROW_COUNTS[r]
	var center: float = float(count - 1) * 0.5
	var x: float = (float(col) - center) * COL_SPACING
	return Vector3(x, ROW_Y[r], ROW_DEPTHS[r])


static func sample_entry_path(squad_index: int, t: float) -> Vector3:
	var u: float = clampf(t, 0.0, 1.0)
	match squad_index % 5:
		0: # Top-center plunging arc
			return Vector3(
				sin(u * TAU) * 10.0,
				lerpf(22.0, 4.0, u) + cos(u * PI) * 4.0,
				lerpf(-150.0, -52.0, u)
			)
		1: # Left helical ribbon
			return Vector3(
				lerpf(-28.0, -4.0, u) + sin(u * TAU) * 9.0,
				cos(u * TAU) * 8.0,
				lerpf(-155.0, -50.0, u)
			)
		2: # Right helical ribbon
			return Vector3(
				lerpf(28.0, 4.0, u) - sin(u * TAU) * 9.0,
				cos(u * TAU) * 8.0,
				lerpf(-155.0, -50.0, u)
			)
		3: # Lower swoop rising into grid
			return Vector3(
				sin(u * PI * 1.5) * 14.0,
				lerpf(-18.0, 1.0, u) - sin(u * PI) * 5.0,
				lerpf(-145.0, -47.0, u)
			)
		_: # Double corkscrew center
			return Vector3(
				cos(u * TAU * 1.25) * (12.0 * (1.0 - u * 0.5)),
				sin(u * TAU * 1.25) * (7.0 * (1.0 - u * 0.4)),
				lerpf(-150.0, -46.0, u)
			)


static func sample_challenge_path(wave_index: int, t: float) -> Vector3:
	var u: float = clampf(t, 0.0, 1.0)
	var z: float = lerpf(-95.0, 14.0, u)
	match wave_index % 5:
		0: # Wide figure-8 sweep
			return Vector3(sin(u * TAU) * 13.0, sin(u * PI * 4.0) * 4.5, z)
		1: # Left-to-right high arc
			return Vector3(lerpf(-16.0, 16.0, u), sin(u * PI) * 7.5 - 1.5, z)
		2: # Right-to-left low arc
			return Vector3(lerpf(16.0, -16.0, u), -sin(u * PI) * 7.5 + 1.5, z)
		3: # Corkscrew tunnel
			var radius: float = 9.0 * (1.0 - absf(u - 0.5))
			return Vector3(cos(u * TAU * 2.0) * radius, sin(u * TAU * 2.0) * radius * 0.65, z)
		_: # Cross-dive diamond
			return Vector3(sin(u * PI * 3.0) * 12.0, cos(u * PI * 2.0) * 6.0, z)


static func sample_dive_offset(archetype: int, t: float, side: float) -> Vector3:
	var u: float = clampf(t, 0.0, 1.0)
	match archetype:
		0: # Zako: S-curve sweep
			return Vector3(sin(u * TAU) * 5.5 * side, -sin(u * PI) * 2.5, 0.0)
		1: # Goei: 3D corkscrew helix
			var r: float = 4.2 * sin(u * PI)
			return Vector3(cos(u * TAU * 2.0) * r * side, sin(u * TAU * 2.0) * r * 0.7, 0.0)
		_: # Boss Galaga: commanding wide arc
			return Vector3(sin(u * PI) * 4.0 * side, cos(u * PI) * 2.0, 0.0)
