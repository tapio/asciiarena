
Enum protocol
	introduce	= 1
	join
	message
	gameInfo
	mapHeader
	mapData
	updatePos
	updateStatus
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

