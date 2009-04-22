

Const DB_players = "db_players.dat"


Type CLIENT_NODE
	name As String = ""
	id   As UByte
	cnx  As Socket Ptr = 0
	thread As Any Ptr = 0
	flags As UByte
	x As UByte
	y As UByte
	nextPl As CLIENT_NODE Ptr
	gameId As UByte
	Declare Sub send(msg As String)
End Type
	Sub CLIENT_NODE.send(msg As String)
		'this.cnx->put(1)
		this.cnx->put(msg)
	End Sub

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
	title As String
	players(maxPlayers) As CLIENT_NODE Ptr
	map(1 To mapWidth,1 To mapHeight) As UByte
	'nextGame As GameFwd Ptr
	Declare Constructor (title As String = "")
	Declare Function AddPlayer(cli As CLIENT_NODE Ptr) As UByte
	Declare Sub removePlayer(id As UByte)
	Declare Sub sendToAll(msg As String)
End Type
	Constructor Game(title As String = "")
		this.title = title
	End Constructor
	Sub Game.sendToAll(msg As String)
		For i As Integer = 1 to maxPlayers
			If this.players(i)->name <> "" Then this.players(i)->send(msg)
		Next i
	End Sub
	Function Game.AddPlayer(cli As CLIENT_NODE Ptr) As UByte
		For i As Integer = 1 To maxPlayers
			If this.players(i) = 0 Then this.players(i) = cli: cli->id = i: Return i
		Next i
		Return 0
	End Function
	Sub Game.removePlayer(id As UByte)
		this.players(id)->id = 0
		this.players(id) = 0
	End Sub
	

Dim Shared As Integer numGames = 0
Dim Shared games(1 To numGames) As Game




Sub DeletePlayer(pl As CLIENT_NODE Ptr)
	'RemoveFromArea(pl, pl->actArea)
	'MutexLock(lock_players)
	'If pl = firstCli Then firstCli = pl->nextPl
	'If pl = lastCli  Then lastCli  = pl->prevPl
	'If pl->nextPL <> 0 Then pl->nextPl->prevPl = pl->prevPl
	'If pl->prevPL <> 0 Then pl->prevPl->nextPl = pl->nextPl
	'Delete(pl->cnx)
	'Delete(pl)
	'clients -= 1
	'MutexUnLock(lock_players)
End Sub


Sub CreateGame(title As String, map As String)
	numGames += 1
	games(numGames) = Game(title)
	For j As Integer = 1 To mapHeight
		For i As Integer = 1 To mapWidth
			If rnd > .8 Then games(numGames).map(i,j) = Asc("#")
		Next i
	Next j
End Sub


Function isValidName(st As String) As Byte
	Return -1
End Function


Dim Shared As UInteger ticks = 0
Function GetGameTicks() As UInteger
	Return ticks
End Function

