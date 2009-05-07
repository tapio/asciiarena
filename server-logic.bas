
Type GameFwd As Game 
Type ClientFwd As CLIENT_NODE
Type WeaponFwd As Weapon

'Function Distance(x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer) As Single
'	Return Sqr( CSng((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1)) )
'End Function 


Type BlastWave
	x			As UByte
	y			As UByte
	energy		As Single = 10
	energyUsage	As Single = 1.0
	dmgMult		As Single = 1.0
	speed		As Single = 2.0
	startTime	As Double
	nextNode	As BlastWave Ptr
	'color As UInteger
	'Declare Constructor (x As UByte, y As UByte, energy As Single)
End Type

	

Type CLIENT_NODE
	name As String = ""
	id   As UByte
	cnx  As Socket Ptr = 0
	thread As Any Ptr = 0
	flags As UByte
	x As UByte
	y As UByte
	hp As Single = 100
	maxhp As Single = 100
	gun As WeaponFwd Ptr = 0
	energy As Single = 100
	maxEne As Single = 100
	nextPl As CLIENT_NODE Ptr
	curGame As GameFwd Ptr
	Declare Sub send(msg As String)
	Declare Function takeDmg(amount As Single) As UByte
	Declare Function getCond() As Ubyte
	Declare Function getEne() As Ubyte
End Type
	Sub CLIENT_NODE.send(msg As String)
		'this.cnx->put(1)
		this.cnx->put(msg)
	End Sub
	Function CLIENT_NODE.takeDmg(amount As Single) As UByte
		this.hp -= amount
		If this.hp > 0 Then Return Int(this.hp/this.maxhp *100)
		Return 0
	End Function
	Function CLIENT_NODE.getCond() As UByte
		'Return Int(this.hp/this.maxhp *100)
		Return Int(this.hp)
	End Function
	Function CLIENT_NODE.getEne() As UByte
		'Return Int(this.ene/this.maxEne *100)
		Return Int(this.energy)
	End Function


Dim Shared As CLIENT_NODE Ptr firstCli = 0, lastCli = 0
Dim Shared As Integer clients = 0, regCount = 0
Dim Shared As ULongInt runningID = 1 

Dim Shared As Double StartTimer
Dim Shared As String StartTime

Dim Shared lock_players As Any Ptr : lock_players = MutexCreate()
Dim Shared lock_output  As Any Ptr : lock_output  = MutexCreate()

Dim Shared As Byte serverShutdown = 0


Const maxPlayers = 8

Type Game
	title As String
	id As UByte
	thread As Any Ptr = 0
	plCount As UByte = 0
	plLimit As UByte = maxPlayers
	lock_pl As Any Ptr
	players(1 To maxPlayers) As CLIENT_NODE Ptr
	map(1 To mapWidth,1 To mapHeight) As UByte
	firstBlast As BlastWave Ptr
	Declare Constructor (title As String = "")
	Declare Function AddPlayer(cli As CLIENT_NODE Ptr) As UByte
	Declare Sub removePlayer(id As UByte)
	Declare Sub sendToAll(msg As String)
	Declare Sub addBlastWave(newBlast As BlastWave Ptr)
	Declare Sub updateLogic()
	Declare Operator Cast() As String
End Type
	Constructor Game(title As String = "")
		this.title = title
		this.lock_pl = MutexCreate()
	End Constructor
	Sub Game.sendToAll(msg As String)
		For i As Integer = 1 to maxPlayers
			If this.players(i)->name <> "" Then this.players(i)->send(msg)
		Next i
	End Sub
	Function Game.AddPlayer(cli As CLIENT_NODE Ptr) As UByte
		MutexLock(this.lock_pl)
		For i As Integer = 1 To this.plLimit
		'ServerOutput "Iterating for open player slot... "&Str(i)
			If this.players(i) = 0 Then
			'ServerOutput "found"
				this.players(i) = cli
				cli->id = i
				cli->x = 10
				cli->y = 10
				cli->curGame = @this
				this.plCount += 1
				'ServerOutput "ready to return"
				MutexUnLock(this.lock_pl)
				Return i
			EndIf
		Next i
		MutexUnLock(this.lock_pl)
		Return 0
	End Function
	Sub Game.removePlayer(id As UByte)
		MutexLock(this.lock_pl)
		this.players(id)->id = 0
		this.players(id) = 0
		this.plCount -= 1
		MutexUnLock(this.lock_pl)
	End Sub
	Operator Game.Cast() As String
		Return Str(this.id)+" - "+this.title+" - "+Str(this.plCount)+"/"+Str(this.plLimit)
	End Operator
	Sub Game.addBlastWave(newBlast As BlastWave Ptr)
		newBlast->nextNode = this.firstBlast
		this.firstBlast = newBlast
		newBlast->startTime = Timer
		this.sendToAll(Chr(protocol.newBlastWave, newBlast->x, newBlast->y, newBlast->energy, newBlast->energyUsage, newBlast->speed))
	End Sub
	Sub Game.updateLogic()
		Dim As BlastWave Ptr curBlast = firstBlast, prevBlast = 0
		While curBlast <> 0
			Var dist = ((Timer - curBlast->startTime) * curBlast->speed)
			Var ene = curBlast->energy - (dist * curBlast->energyUsage)
			If ene >= 1 Then
				For i As Integer = 1 to this.plLimit
					If this.players(i) <> 0 AndAlso Int(Distance(curBlast->x, curBlast->y, _
						this.players(i)->x, this.players(i)->y)) = dist Then
							Var temp = this.players(i)->takeDmg(ene * curBlast->dmgMult)
							'this.sendToAll(Chr(protocol.updateStatus, players(i)->id, temp))
					EndIf
				Next i
				prevBlast = curBlast
				curBlast = curBlast->nextNode
			Else
				If this.firstBlast = curBlast Then this.firstBlast = curBlast->nextNode
				If prevBlast <> 0 Then prevBlast->nextNode = curBlast->nextNode
				Delete(curBlast)
				If prevBlast <> 0 Then curBlast = prevBlast->nextNode Else curBlast = 0
			EndIf
		Wend
	End Sub
	

Dim Shared As Integer numGames = 0
Dim Shared games(1 To numGames) As Game Ptr



Type Weapon
	energy		As Single = 10
	maxEnergy	As Single = 50
	energyUsage	As Single = 10.0
	dmgMult		As Single = 1.0
	speed		As Single = 4.0
	recharge	As Single = 10.0
	'color As UInteger
	'Declare Constructor ()
	Declare Sub Shoot(shooter As ClientFwd Ptr)
End Type
	'Constructor Weapon()
	'End Constructor
	Sub Weapon.Shoot(shooter As ClientFwd Ptr)
		Var newBlast = new BlastWave
		newBlast->x = shooter->x
		newBlast->y = shooter->y
		newBlast->energy = min(this.maxEnergy, shooter->energy)
			shooter->energy -= newBlast->energy
		newBlast->energyUsage = this.energyUsage
		newBlast->dmgMult = this.dmgMult
		newBlast->speed = this.speed
		shooter->curGame->addBlastWave(newBlast)
	End Sub



Sub GameThread(curGame As Game Ptr)
	Dim statusTimer As DelayTimer = DelayTimer(0.5)
	Dim blastTimer As DelayTimer = DelayTimer(0.04)
	Dim i As Integer
	Dim pl As CLIENT_NODE Ptr
	Do Until serverShutdown <> 0
		
		If statusTimer.hasExpired Then
			For i As Integer = 1 to curGame->plLimit
				pl = curGame->players(i)				
				If pl <> 0 Then
					pl->energy += pl->gun->recharge'/2.0
					If pl->energy > pl->maxEne Then pl->energy = pl->maxEne
					pl->send(Chr(protocol.updateStatus, i, pl->getCond(), pl->getEne()))
				EndIf
			Next i
			statusTimer.start
		EndIf
		
		If blastTimer.hasExpired Then
			curGame->updateLogic
			blastTimer.start
		Else
			Sleep 4,1
		EndIf
		
		Sleep 1,1
	Loop
End Sub



Sub DeletePlayer(pl As CLIENT_NODE Ptr)
	If pl->curGame <> 0 Then pl->curGame->removePlayer(pl->id)
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
	ReDim Preserve games(1 To numGames)
	games(numGames) = New Game(title)
	games(numGames)->id = numGames
	For j As Integer = 1 To mapHeight
		For i As Integer = 1 To mapWidth
			If rnd > .8 Then games(numGames)->map(i,j) = Asc("#") Else games(numGames)->map(i,j) = Asc(" ")
			If i=1 Or j=1 Or i=mapWidth Or j=mapHeight Then games(numGames)->map(i,j) = Asc("#")
		Next i
	Next j
	games(numGames)->thread = ThreadCreate( Cast(Sub(ByVal As Any Ptr), @GameThread), games(numGames) )
End Sub


Function isValidName(st As String) As Byte
	Return -1
End Function


Dim Shared As UInteger ticks = 0
Function GetGameTicks() As UInteger
	Return ticks
End Function

