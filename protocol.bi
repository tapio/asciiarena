'' Ascii Arena
'' (c) Tapio Vierros 2009
'' License: Creative Commons Attribution 3.0
'' 			http://creativecommons.org/licenses/by/3.0/



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
'' < newBlastWave		P,x,y,ene,eneUsage,spd


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


'' Shared types ''

Const numBlastParticles = 16
Const blastAngle = 360.0/numBlastParticles
Type BlastWave
	x			As UByte
	y			As UByte
	energy		As Single = 10
	energyUsage	As Single = 1.0
	speed		As Single = 5.0
	dmgMult		As Single = 1.0
	startTime	As Double
	particles(1 To numBlastParticles) As UByte
	nextNode	As BlastWave Ptr
	'color As UInteger
	Declare Constructor(x As UByte = 0, y As UByte = 0)
End Type
    Constructor BlastWave(x As UByte = 0, y As UByte = 0)
        this.x   = x
        this.y   = y
    End Constructor
