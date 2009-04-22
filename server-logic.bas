

Const DB_players = "db_players.dat"


Type CLIENT_NODE
	name As String = ""
	cnx  As Socket Ptr = 0
	thread As Any Ptr = 0
	flags As UByte
	x As UByte
	y As UByte
	nextPl As CLIENT_NODE Ptr
End Type

Dim Shared As CLIENT_NODE Ptr firstCli = 0, lastCli = 0
Dim Shared As Integer clients = 0, regCount = 0
Dim Shared As ULongInt runningID = 1 

Dim Shared As Double StartTimer
Dim Shared As String StartTime

Dim Shared lock_players As Any Ptr : lock_players = MutexCreate()
Dim Shared lock_output  As Any Ptr : lock_output  = MutexCreate()

Dim Shared As Byte serverShutdown = 0

Const maxPlayers = 32
Type GameFwd As Game 

Type Game
	name As String
	players(maxPlayers) As CLIENT_NODE Ptr
	
	'nextGame As GameFwd Ptr
	Declare Sub sendToAll(msg As String)
End Type
	Sub sendToAll(msg As String)
		For i As Integer = 1 to maxPlayers
			If players(i)->name <> "" Then players(i)->send(msg)
		Next i
	End Sub


Dim Shared games(numGames) As Game




Sub DeletePlayer(pl As CLIENT_NODE Ptr)
	RemoveFromArea(pl, pl->actArea)
	MutexLock(lock_players)
	If pl = firstCli Then firstCli = pl->nextPl
	If pl = lastCli  Then lastCli  = pl->prevPl
	If pl->nextPL <> 0 Then pl->nextPl->prevPl = pl->prevPl
	If pl->prevPL <> 0 Then pl->prevPl->nextPl = pl->nextPl
	Delete(pl->cnx)
	Delete(pl)
	clients -= 1
	MutexUnLock(lock_players)
End Sub





Function isValidName(st As String) As Byte
	Return -1
End Function


Dim Shared As UInteger ticks = 0
Function GetGameTicks() As UInteger
	Return ticks
End Function

