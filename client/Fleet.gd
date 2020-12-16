tool
extends Spatial

var white = true
var black = false
var basic = true
var vip = false


var stackOffest = 2.2
var rowsOffset = -2.5

var startX = 2
var startY = 2
var startZ = -4

var heightOffset = 0.3

var trays = {5:["res://assets/tray/tray-5x5.tscn",[[3,3,3,-1],[3,3,3,3]]],6:["res://assets/tray/tray-6x6.tscn",[[3,3,-1],[3,3,3,3],[3,3,3,3]]],7:["res://assets/tray/tray-7x7.tscn",[[3,3,3,3,-1],[3,3,3,3,3],[3,3,3,3,1]]]}
var traysize = 5
var colour = "W"
var style = "B"

var stacks = []
# These functions might not be needed
# just in case we keep them until 
# we confirm basic attribute setting is enough
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

func getChosenCirya(pieceid=null):
    var cirya = null
    if white:
        if basic:
            cirya = load("res://units/cirya-w-basic.tscn").instance()
            cirya.pieceid = pieceid
        else:
            cirya = load("res://CiryaLV.tscn").instance()
            cirya.pieceid = pieceid
    else: # so far, we reuse white
        if basic:
            cirya = load("res://CiryaLB.tscn").instance()
            cirya.pieceid = pieceid
        else:
            cirya = load("res://CiryaLV.tscn").instance()
            cirya.pieceid = pieceid
    return cirya

func getChosenHallacirya(pieceid=null):
    var hallacirya = null
    if white:
        if basic:
            hallacirya = load("res://units/hallacirya-w-basic.tscn").instance()
            hallacirya.pieceid = pieceid
        else:
            hallacirya = load("res://HallaciryaLV.tscn").instance()
            hallacirya.pieceid = pieceid
    else: # so far, we reuse white
        if basic:
            hallacirya = load("res://CiryaLB.tscn").instance()
            hallacirya.pieceid = pieceid
        else:
            hallacirya = load("res://CiryaLV.tscn").instance()
            hallacirya.pieceid = pieceid
    return hallacirya


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

func removeCiryafromFleet(pieceid):
    for s in stacks:
        for p in s:
            if p.fleetSelectable:
                if p.pieceid == pieceid:
                    print("Cirya has been removed")
                    s.erase(p)
                    if len(s) != 0:
                        s[-1].fleetSelectable = true
                    remove_child(p)
                   
                    break
            else:
                pass
        
# Called when the node enters the scene tree for the first time.
func _ready():
    

    var piece = null
    var aTray = load(trays[traysize][0]).instance()
    add_child(aTray)
    
    var originalstartZ = startZ
    
    var pieceid = 1
    for r in trays[traysize][1]:
       
        for s in r:
            var st = 0
            var sX = startX
            var sY = startY
            var sZ = startZ
            if s > 0:
                var onestack = []
                for p in range(s):
                    var c = getChosenCirya(pieceid)
                    var x = sX + rand_range(-0.002, 0.002)
                    var z = sZ + rand_range(-0.02, 0.02)
                    var y = sY + heightOffset*st
                    c.translation.x = x
                    c.translation.z = z
                    c.translation.y = y
                    c.rotation.y = randi()%5+1

                    add_child(c)
                    onestack.append(c)
                    st +=1
                    pieceid +=1
                
                startZ += stackOffest
                onestack[-1].fleetSelectable = true
                stacks.append(onestack)
            else:
                var c = getChosenHallacirya(pieceid)
                var x = sX + rand_range(-0.002, 0.002)
                var z = sZ + rand_range(-0.02, 0.02)
                var y = sY + heightOffset*st
                c.translation.x = x
                c.translation.z = z
                c.translation.y = y
                c.rotation.y = randi()%5+1

                add_child(c)
                c.fleetSelectable = true
                stacks.append([c])
                st +=1
                pieceid +=1
                    
            
        startX += rowsOffset
        startZ = originalstartZ
    
    print(stacks,stacks.size())
