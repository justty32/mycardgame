## Pure screen-space mapping. Rectangles never describe gameplay adjacency or deployment.
extends RefCounted
class_name BoardLayout

const SLOT_SIZE: Vector2 = Vector2(460, 280)
const SINGLE_ORIGIN: Vector2 = Vector2(360, 170)
const DUAL_ORIGINS: Array[Vector2] = [Vector2(70, 170), Vector2(640, 170)]

## Caller-supplied rectangles support any count without choosing a product layout policy.
## Reject incomplete mappings rather than silently dropping boards or sharing the last slot.
static func map_slots(ids: Array, rects: Array[Rect2]) -> Dictionary[String, Rect2]:
	var result: Dictionary[String, Rect2] = {}
	if ids.size() != rects.size():
		return result
	for index: int in ids.size():
		var id: String = str(ids[index])
		if id.is_empty() or result.has(id) or not valid_slot(rects[index]):
			return {}
		result[id] = rects[index]
	return result

## Existing one/two-board composition only; higher counts require explicit rectangles.
static func compatibility_slots(ids: Array) -> Dictionary[String, Rect2]:
	var rects: Array[Rect2] = []
	if ids.size() > 2:
		return {}
	for index: int in ids.size():
		var origin: Vector2 = SINGLE_ORIGIN if ids.size() == 1 else DUAL_ORIGINS[index]
		rects.append(Rect2(origin, SLOT_SIZE))
	return map_slots(ids, rects)

static func centered_position(slot: Rect2, view_size: Vector2) -> Vector2:
	return slot.position + ((slot.size - view_size) * 0.5).floor()

static func valid_slot(slot: Rect2) -> bool:
	return slot.position.is_finite() and slot.size.is_finite() and slot.size.x > 0 and slot.size.y > 0
