tool
extends Spatial

var white = true
var black = false
var basic = true
var vip = false


var stackOffest = 2.2
var rowsOffset = -3

var startX = 1.5
var startY = 0.2
var startZ = -4

var heightOffset = 0.3

var trays = {5:["res://Tray5.tscn",[[3,3,3],[3,3,3,3]]],6:["res://Tray5.tscn",[[3,3,3,3],[3,3,3,3],[3,3]]],7:["res://Tray5.tscn",[[3,3,3,3,3],[3,3,3,3,3],[3,3,3,1]]]}
var traysize = 5
var colour = "W"
var style = "B"

func setVIP():
	basic = false
	vip = true

func setBasic():
	vip = false
	basic = true

func setWhite():
	black = false
	white = true

func setBlack():
	white = false
	black = true

func getChosenCirya(ciryaid=null):
	var cirya = null
	if white:
		if basic:
			cirya = load("res://CiryaLB.tscn").instance()
			cirya.ciryaid = ciryaid
		else:
			cirya = load("res://CiryaLV.tscn").instance()
			cirya.ciryaid = ciryaid
	else: # so far, we reuse white
		if basic:
			cirya = load("res://CiryaLB.tscn").instance()
			cirya.ciryaid = ciryaid
		else:
			cirya = load("res://CiryaLV.tscn").instance()
			cirya.ciryaid = ciryaid
	return cirya

func setup(ts,c,s):
	traysize = ts
	colour = c
	if colour == "W":
		setWhite()
	else:
		setBlack()
	style = s
	if style == "B":
		setBasic()
	else:
		setVIP()
		
# Called when the node enters the scene tree for the first time.
func _ready():
	
	var ciryar = []
	var piece = null
	var aTray = load(trays[traysize][0]).instance()
	add_child(aTray)
	
	var originalstartZ = startZ
	
	var ciryaid = 1
	for r in trays[traysize][1]:
		print("r",r)
	   
		for s in r:
			var st = 0
			var sX = startX
			var sY = startY
			var sZ = startZ
			for p in range(s):
				var c = getChosenCirya(ciryaid)
				var x = sX + rand_range(-0.002, 0.002)
				var z = sZ + rand_range(-0.02, 0.02)
				var y = sY + heightOffset*st
				c.get_node("piece").translation.x = x
				c.get_node("piece").translation.z = z
				c.get_node("piece").translation.y = y
				c.get_node("piece").rotation.y = randi()%5+1

				add_child(c)
				ciryar.append(c)
				st +=1
				ciryaid +=1
				print(c.ciryaid)
			
			startZ += stackOffest
		
			
		startX += rowsOffset
		startZ = originalstartZ
	
	print(ciryar,ciryar.size())
