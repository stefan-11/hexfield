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

## Anzahl der Felder, die vom Mittelfeld in jede Richtung ausgehen.
@export var radius: int = 3
## Skalierung der Felder (0.8 sorgt dafür, dass das Feld ins Standardfenster passt).
@export var tile_scale: float = 1
## Platziert das Spielfeld beim Start in der Mitte des Viewports.
@export var center_in_viewport: bool = true

## Alle Felder des Spielfelds, Schlüssel ist die axiale Koordinate (q, r).
var tiles: Dictionary[Vector2i, Sprite2D] = {}

var _tile_size: Vector2


func _ready() -> void:
	_tile_size = HEX_TEXTURE.get_size() * tile_scale
	if center_in_viewport:
		position = get_viewport_rect().size / 2.0
	generate_map()


func _unhandled_input(event: InputEvent) -> void:
	# Test: Angeklicktes Feld einfärben und seine Koordinate ausgeben.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hex := pixel_to_axial(get_local_mouse_position())
		if has_tile(hex):
			var tile := tiles[hex]
			tile.modulate = Color.WHITE if tile.modulate != Color.WHITE else Color.CORNFLOWER_BLUE
			print("Hex (q=%d, r=%d, s=%d), Abstand zur Mitte: %d" % [hex.x, hex.y, -hex.x - hex.y, distance(hex, Vector2i.ZERO)])


## Erzeugt alle Felder innerhalb von `radius` um das Mittelfeld (0, 0).
func generate_map() -> void:
	clear_map()
	for q in range(-radius, radius + 1):
		var r_min := maxi(-radius, -q - radius)
		var r_max := mini(radius, -q + radius)
		for r in range(r_min, r_max + 1):
			_create_tile(Vector2i(q, r))


func clear_map() -> void:
	for tile in tiles.values():
		tile.queue_free()
	tiles.clear()


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
