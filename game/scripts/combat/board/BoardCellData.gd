## One cell of the combat board (combat framework Phase 2). Not saved.
extends RefCounted
class_name BoardCellData

## unit_uid of the unit covering the cell; "" = empty.
var occupant_uid: String = ""
var is_deploy_zone: bool = false
var is_spawn_zone: bool = false
## Obstacle: cannot be entered or stopped on, truncates LINE shapes; flying units pass over it.
var is_blocked: bool = false
var tags: Array[String] = []
