extends Control
## Resolution-independent local vector icon. No font glyphs, textures or network assets.
@export_enum("level", "population", "happy", "storage", "money", "keys", "road", "residential", "commercial", "industrial", "services", "specializations", "bulldoze", "power", "water", "trade", "save", "cancel", "park", "education", "transport") var kind: String = "road"
@export var tint: Color = Color(1, 1, 1, 1)

const INK := Color("#29445b")
const GOLD := Color("#ffc83d")
const BLUE := Color("#48a9e8")
const GREEN := Color("#52bd79")
const RED := Color("#ed6b59")
const PAPER := Color("#fff3d8")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var u := s / 32.0
	var col := tint
	match kind:
		"road":
			draw_rect(Rect2(c.x-7*u,c.y-15*u,14*u,30*u), Color("#596d7c"))
			for y in [-9, -2, 5]:
				draw_rect(Rect2(c.x-0.8*u,c.y+y*u,1.6*u,4*u), GOLD)
		"residential":
			draw_colored_polygon(PackedVector2Array([c+Vector2(-14,-2)*u,c+Vector2(0,-14)*u,c+Vector2(14,-2)*u]), RED)
			draw_rect(Rect2(c.x-10*u,c.y-2*u,20*u,15*u), Color("#f4c77d"))
			draw_rect(Rect2(c.x-3*u,c.y+4*u,6*u,9*u), Color("#8a6045"))
			draw_rect(Rect2(c.x-8*u,c.y+1*u,4*u,4*u), BLUE)
			draw_rect(Rect2(c.x+4*u,c.y+1*u,4*u,4*u), BLUE)
		"commercial":
			draw_rect(Rect2(c.x-12*u,c.y-12*u,24*u,25*u), Color("#65b6dc"))
			draw_rect(Rect2(c.x-14*u,c.y-5*u,28*u,5*u), RED)
			draw_rect(Rect2(c.x-8*u,c.y+3*u,16*u,10*u), PAPER)
			draw_rect(Rect2(c.x-3*u,c.y+5*u,6*u,8*u), Color("#6b8ba0"))
		"industrial":
			draw_rect(Rect2(c.x-13*u,c.y-5*u,26*u,18*u), Color("#8797a5"))
			draw_rect(Rect2(c.x+4*u,c.y-15*u,7*u,14*u), RED)
			draw_rect(Rect2(c.x-9*u,c.y-11*u,5*u,7*u), Color("#c2d1d8"))
			draw_rect(Rect2(c.x-8*u,c.y+1*u,6*u,6*u), GOLD)
			draw_rect(Rect2(c.x+2*u,c.y+1*u,6*u,6*u), GOLD)
		"services":
			draw_colored_polygon(PackedVector2Array([c+Vector2(2,-15)*u,c+Vector2(-9,2)*u,c+Vector2(-1,2)*u,c+Vector2(-4,15)*u,c+Vector2(10,-3)*u,c+Vector2(2,-3)*u]), GOLD)
		"specializations", "park":
			draw_circle(c+Vector2(0,-5)*u,9*u,GREEN)
			draw_rect(Rect2(c.x-2*u,c.y+1*u,4*u,12*u),Color("#936846"))
			draw_circle(c+Vector2(-7,-1)*u,5*u,Color("#79ce83"))
			draw_circle(c+Vector2(7,-1)*u,5*u,Color("#79ce83"))
		"bulldoze":
			draw_rect(Rect2(c.x-13*u,c.y-3*u,20*u,9*u), GOLD)
			draw_rect(Rect2(c.x-9*u,c.y-10*u,10*u,7*u), BLUE)
			draw_circle(c+Vector2(-7,8)*u,4*u,INK)
			draw_circle(c+Vector2(7,8)*u,4*u,INK)
			draw_line(c+Vector2(8,-8)*u,c+Vector2(14,-14)*u,RED,3*u,true)
		"level":
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-15)*u,c+Vector2(4,-5)*u,c+Vector2(15,-5)*u,c+Vector2(6,2)*u,c+Vector2(9,13)*u,c+Vector2(0,7)*u,c+Vector2(-9,13)*u,c+Vector2(-6,2)*u,c+Vector2(-15,-5)*u,c+Vector2(-4,-5)*u]), GOLD)
		"population":
			draw_circle(c+Vector2(0,-7)*u,6*u,BLUE)
			draw_circle(c+Vector2(-10,-3)*u,4*u,Color("#79c8ef"))
			draw_circle(c+Vector2(10,-3)*u,4*u,Color("#79c8ef"))
			draw_rect(Rect2(c.x-8*u,c.y,16*u,12*u),BLUE)
			draw_rect(Rect2(c.x-15*u,c.y+3*u,7*u,9*u),Color("#79c8ef"))
			draw_rect(Rect2(c.x+8*u,c.y+3*u,7*u,9*u),Color("#79c8ef"))
		"happy":
			draw_circle(c,14*u,GOLD)
			draw_circle(c+Vector2(-5,-4)*u,1.5*u,INK)
			draw_circle(c+Vector2(5,-4)*u,1.5*u,INK)
			draw_arc(c+Vector2(0,0)*u,7*u,0.25,2.9,16,INK,1.8*u,true)
		"storage":
			draw_rect(Rect2(c.x-13*u,c.y-10*u,26*u,21*u),Color("#b68b5b"))
			draw_rect(Rect2(c.x-13*u,c.y-10*u,26*u,5*u),Color("#e0b77b"))
			draw_line(c+Vector2(0,-5)*u,c+Vector2(0,10)*u,INK,1.5*u)
		"money":
			draw_circle(c,14*u,GREEN)
			draw_circle(c,10*u,Color("#d8f3ce"))
			draw_line(c+Vector2(-4,-7)*u,c+Vector2(4,7)*u, GREEN,2*u)
		"keys":
			draw_circle(c+Vector2(-5,-4)*u,6*u,GOLD)
			draw_circle(c+Vector2(-5,-4)*u,2*u,INK)
			draw_rect(Rect2(c.x,c.y-2*u,14*u,4*u),GOLD)
			draw_rect(Rect2(c.x+8*u,c.y+1*u,3*u,5*u),GOLD)
		"power":
			draw_colored_polygon(PackedVector2Array([c+Vector2(2,-14)*u,c+Vector2(-8,2)*u,c+Vector2(-1,2)*u,c+Vector2(-4,14)*u,c+Vector2(9,-3)*u,c+Vector2(2,-3)*u]),GOLD)
		"water":
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-14)*u,c+Vector2(-10,1)*u,c+Vector2(-9,7)*u,c+Vector2(-4,13)*u,c+Vector2(4,13)*u,c+Vector2(9,7)*u,c+Vector2(10,1)*u]),BLUE)
		"trade":
			draw_line(c+Vector2(-12,-5)*u,c+Vector2(10,-5)*u,GREEN,3*u,true)
			draw_colored_polygon(PackedVector2Array([c+Vector2(10,-10)*u,c+Vector2(15,-5)*u,c+Vector2(10,0)*u]),GREEN)
			draw_line(c+Vector2(12,6)*u,c+Vector2(-10,6)*u,BLUE,3*u,true)
			draw_colored_polygon(PackedVector2Array([c+Vector2(-10,1)*u,c+Vector2(-15,6)*u,c+Vector2(-10,11)*u]),BLUE)
		"save":
			draw_rect(Rect2(c.x-12*u,c.y-12*u,24*u,24*u),BLUE)
			draw_rect(Rect2(c.x-7*u,c.y-12*u,14*u,8*u),PAPER)
			draw_rect(Rect2(c.x-7*u,c.y+2*u,14*u,10*u),PAPER)
		"cancel":
			draw_line(c+Vector2(-9,-9)*u,c+Vector2(9,9)*u,RED,4*u,true)
			draw_line(c+Vector2(9,-9)*u,c+Vector2(-9,9)*u,RED,4*u,true)
		"education":
			draw_colored_polygon(PackedVector2Array([c+Vector2(-15,-6)*u,c+Vector2(0,-14)*u,c+Vector2(15,-6)*u,c+Vector2(0,2)*u]),GOLD)
			draw_rect(Rect2(c.x-10*u,c.y-3*u,20*u,10*u),BLUE)
		"transport":
			draw_rect(Rect2(c.x-12*u,c.y-10*u,24*u,19*u),BLUE)
			draw_rect(Rect2(c.x-8*u,c.y-6*u,16*u,7*u),PAPER)
			draw_circle(c+Vector2(-7,10)*u,3*u,INK)
			draw_circle(c+Vector2(7,10)*u,3*u,INK)
