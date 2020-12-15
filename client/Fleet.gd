tool
extends Spatial

var white = true
var black = false
var basic = true
var vip = false

var fleetNumber = 21
var hallaciryar = 1

var stackSize = 3
var rows = 2

var stackOffest = 2.2
var rowsOffset = -3

var startX = 1.5
var startY = 0.2
var startZ = -4

var heightOffset = 0.3

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

func getChosenCirya():
    var cirya = null
    if white:
        if basic:
            cirya = load("res://CiryaLB.tscn").instance()
    return cirya
    
# Called when the node enters the scene tree for the first time.
func _ready():
    
    var ciryar = []
    var piece = null
    
    #FIXME el cḉalculo del extra no es del todo correcto aunque funciona en los casos fijos
    var stacksPerRow = (fleetNumber/stackSize)/rows
    var extraStacksLastRow = (fleetNumber/stackSize)%rows
    print(stacksPerRow, extraStacksLastRow)
    
    var stacks = []
    for i in range(rows):
        var arow = []
        for j in range(stacksPerRow):
            arow.append(stackSize)
        stacks.append(arow)
    for k in range(extraStacksLastRow):
        stacks[-1].append(stackSize)
    
    var originalstartZ = startZ

    for r in stacks:
        print("r",r)
       
        for s in r:
            var st = 0
            var sX = startX
            var sY = startY
            var sZ = startZ
            for p in range(s):
                var c = getChosenCirya()
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
            
            startZ += stackOffest
        
            
        startX += rowsOffset
        startZ = originalstartZ
        print(startX)

    

    print(ciryar,ciryar.size())
