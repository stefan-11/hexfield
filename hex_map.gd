class_name HexMap
extends Node2D

## Verwaltet ein hexagonales Spielfeld mit axialen Koordinaten (q, r).
## Ausrichtung: Flat-Top (passend zu hex-white.png mit 128 x 110 px).
## Die dritte Würfelkoordinate ergibt sich jeweils aus s = -q - r.

const HEX_TEXTURE: Texture2D = preload("res://hex-white.png")

## Axiale Richtungsvektoren zu den sechs Nachbarfeldern.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

const SELECTED_COLOR := Color.CORNFLOWER_BLUE
const HOVER_COLOR := Color(0.85, 0.9, 1.0)

## Anzahl der Felder, die vom Mittelfeld in jede Richtung ausgehen.
@export var radius: int = 3
## Skalierung der Felder (0.8 sorgt dafür, dass das Feld ins Standardfenster passt).
@export var tile_scale: float = 1
## Platziert das Spielfeld beim Start in der Mitte des Viewports.
@export var center_in_viewport: bool = true

## Alle Felder des Spielfelds, Schlüssel ist die axiale Koordinate (q, r).
var tiles: Dictionary[Vector2i, Sprite2D] = {}
## Aktuell markierte Felder (maximal zwei: Feld 1 und Feld 2).
var selected: Array[Vector2i] = []
## Feld unter dem Mauszeiger, oder null.
var hovered: Variant = null
## Angezeigter Pfad: Feld 1 -> Feld 2, oder als Vorschau Feld 1 -> Feld unter der Maus.
var path: Array[Vector2i] = []

var _tile_size: Vector2
var _astar := AStar2D.new()
## AStar2D arbeitet mit Zahlen-IDs: Zuordnung Koordinate -> ID und ID -> Koordinate.
var _point_ids: Dictionary[Vector2i, int] = {}
var _point_hexes: Array[Vector2i] = []


func _ready() -> void:
	_tile_size = HEX_TEXTURE.get_size() * tile_scale
	if center_in_viewport:
		position = get_viewport_rect().size / 2.0
	generate_map()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hex := pixel_to_axial(get_local_mouse_position())
		if has_tile(hex):
			select_tile(hex)
	elif event is InputEventMouseMotion:
		set_hovered(pixel_to_axial(get_local_mouse_position()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		set_hovered(null)


## Setzt das Feld unter dem Mauszeiger (null bzw. Koordinate außerhalb = keins).
func set_hovered(hex: Variant) -> void:
	if hex != null and not has_tile(hex):
		hex = null
	if hex == hovered:
		return
	hovered = hex
	_update_highlights()


## Markiert ein Feld. Es sind höchstens zwei Felder gleichzeitig markiert:
## Ein dritter Klick hebt die bisherige Auswahl auf und beginnt eine neue.
func select_tile(hex: Vector2i) -> void:
	if selected.size() >= 2:
		selected.clear()
	selected.append(hex)
	_update_highlights()
	print("Feld %d: (q=%d, r=%d, s=%d)" % [selected.size(), hex.x, hex.y, -hex.x - hex.y])
	if selected.size() == 2:
		print("Distanz zwischen Feld 1 und Feld 2: %d" % distance(selected[0], selected[1]))
		print("Pfad: ", path)


func clear_selection() -> void:
	selected.clear()
	_update_highlights()


## Kürzester Pfad zwischen zwei Feldern, inklusive Start- und Zielfeld.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for id in _astar.get_id_path(_point_ids[from], _point_ids[to]):
		result.append(_point_hexes[id])
	return result


## Berechnet den angezeigten Pfad neu und färbt alle Felder ein:
## angeklickte Felder und der fertige Pfad kräftig blau,
## Pfad-Vorschau und Feld unter der Maus hellblau, alle anderen weiß.
func _update_highlights() -> void:
	path.clear()
	if selected.size() == 2:
		path = find_path(selected[0], selected[1])
	elif selected.size() == 1 and hovered != null:
		path = find_path(selected[0], hovered)
	var path_color := SELECTED_COLOR if selected.size() == 2 else HOVER_COLOR
	for hex in tiles:
		if hex in selected:
			tiles[hex].modulate = SELECTED_COLOR
		elif hex in path:
			tiles[hex].modulate = path_color
		elif hex == hovered:
			tiles[hex].modulate = HOVER_COLOR
		else:
			tiles[hex].modulate = Color.WHITE


## Erzeugt alle Felder innerhalb von `radius` um das Mittelfeld (0, 0).
func generate_map() -> void:
	clear_map()
	for q in range(-radius, radius + 1):
		var r_min := maxi(-radius, -q - radius)
		var r_max := mini(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			_create_tile(Vector2i(q, r))
	_setup_pathfinding()


## Legt für jedes Feld einen AStar2D-Punkt an und verbindet ihn mit seinen Hex-Nachbarn.
## Als Punktposition dient ein ideales Hexgitter, in dem alle sechs Nachbarn exakt
## gleich weit entfernt sind. So reichen die eingebauten Kosten (euklidische Distanz)
## und der kürzeste Pfad hat immer die minimale Anzahl an Schritten.
func _setup_pathfinding() -> void:
	_astar.clear()
	_point_ids.clear()
	_point_hexes.clear()
	for hex in tiles:
		var id := _point_hexes.size()
		_point_ids[hex] = id
		_point_hexes.append(hex)
		_astar.add_point(id, Vector2(1.5 * hex.x, sqrt(3.0) * (hex.y + hex.x / 2.0)))
	for hex in tiles:
		for dir in DIRECTIONS:
			var neighbor := hex + dir
			if has_tile(neighbor):
				_astar.connect_points(_point_ids[hex], _point_ids[neighbor])


func clear_map() -> void:
	for tile in tiles.values():
		tile.queue_free()
	tiles.clear()
	selected.clear()
	hovered = null
	path.clear()


func has_tile(hex: Vector2i) -> bool:
	return tiles.has(hex)


func get_tile(hex: Vector2i) -> Sprite2D:
	return tiles.get(hex)


## Liefert die existierenden Nachbarfelder einer Koordinate.
func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var neighbor := hex + dir
		if has_tile(neighbor):
			result.append(neighbor)
	return result


## Anzahl der Schritte zwischen zwei Feldern.
func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## Mittelpunkt eines Feldes in lokalen Koordinaten dieses Knotens.
func axial_to_pixel(hex: Vector2i) -> Vector2:
	var x := _tile_size.x * 0.75 * hex.x
	var y := _tile_size.y * (hex.y + hex.x / 2.0)
	return Vector2(x, y)


## Axiale Koordinate des Feldes, das einen lokalen Punkt enthält.
func pixel_to_axial(point: Vector2) -> Vector2i:
	var q := point.x / (_tile_size.x * 0.75)
	var r := point.y / _tile_size.y - q / 2.0
	return _axial_round(q, r)


func _axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


func _create_tile(hex: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Hex_%d_%d" % [hex.x, hex.y]
	sprite.texture = HEX_TEXTURE
	sprite.scale = Vector2.ONE * tile_scale
	sprite.position = axial_to_pixel(hex)
	add_child(sprite)
	tiles[hex] = sprite
