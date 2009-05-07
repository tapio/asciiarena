
'' PROTOCOLS
'' > to server
'' < to client
'' P proto identifier
''
'' > introduce			P,my_name
'' < introduce			P,ID,x,y,name
'' > join				P,game_id
'' < mapData			P,mapdata
'' > message			P,message
'' < message			P,message
'' > updatePos			P,move_dir
'' < updatePos			P,ID,x,y
'' < updateStatus		P,ID,cond,gun_energy
'' > newBlastWave		P
'' < newBlastWave		P,x,y


Enum protocol
	introduce	= 1
	join
	message
	gameInfo
	mapHeader
	mapData
	updatePos
	updateStatus
	newBlastWave
End Enum

Enum actions
	north		= 1
	east
	south
	west
	fire
End Enum

Enum queries
	ping        = &b00000001
	playerCount = &b00000010
	areaInfo    = &b00000011
	timeSync    = &b00000100
	clientWait	= &b00000101
	serverOp	= &b00000111
End Enum

Enum adminOps
	shutdown	= &b000001
	restart		= &b000010
	reload		= &b000011
	update		= &b000100
End Enum

Enum cflags
	admin		= &b10000000
End Enum

Enum tile_flags
	BLOCKS_MOVEMENT = &b00000001
End Enum



#Define actionMask &b11100000
#Define viewLvlMask &b00000111
#Define success &b00001000
#Define SEP Chr(1)
#Define detCoordOffSet 32

Const mapWidth = 64
Const mapHeight = 64

Const timestep = 0.05

#Define encSpd(s) (CUByte(s*16.0))
#Define decSpd(b) (CSng(b)/16.0)
