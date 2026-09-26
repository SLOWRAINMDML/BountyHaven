class_name BHSpiral
extends RefCounted
## GDScript port of Space Station 14 Content.Shared/Maths/UlamSpiral.cs.
## Copyright (c) 2017-2026 Space Wizards Federation. MIT. See LICENSE.txt.
## Upstream blob 1226d6022bb669d7a720f3b78007a0110c1a4d8d.
## Changes: explicit Godot numeric conversions; Vector2i return; snake_case.
## Used by housing's nearest legal placement search, not an unused sample.

static func point(n: int) -> Vector2i:
	if n <= 0:
		return Vector2i.ZERO
	var k: int = int(ceil((sqrt(float(n)) - 1.0) / 2.0))
	var t: int = 2 * k + 1
	var m: int = t * t
	t -= 1
	if n >= m - t:
		return Vector2i(k - (m - n), -k)
	m -= t
	if n >= m - t:
		return Vector2i(-k, -k + (m - n))
	m -= t
	if n >= m - t:
		return Vector2i(-k + (m - n), k)
	return Vector2i(k, k - (m - n - t))

static func points_for_max_distance(distance: int) -> int:
	var side: int = maxi(0, distance) * 2 + 1
	return side * side
