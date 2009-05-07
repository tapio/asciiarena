Const VERSION = "0.1.0"
WindowTitle "AsciiArena Server"

#Ifdef __FBWIN32__
	#Define exename "aa-server.exe"
#Else
	#Define exename "aa-server"
#EndIf

#Include Once "def.bi"
#Include Once "util.bas"
#Include Once "words.bi"
#Include Once "chisock/chisock.bi"
Using chi
#Include Once "protocol.bi"

Declare Sub ServerOutput(_st As String)
#Include Once "server-logic.bas"

Declare Sub ServerThread( curCli As CLIENT_NODE Ptr)



Sub accept_thread( Byval s As socket Ptr )
	Var new_cnx = New socket
	Var new_cli = New CLIENT_NODE
	Do
		new_cnx->listen_to_new( *s )
		If ( s->is_closed Or serverShutdown ) Then 
			Exit Do 
		EndIf
		If ( new_cnx->is_closed = FALSE ) Then 
			MutexLock(lock_players)
			'If new_cnx->get( h ) Then
				'If new_cnx->get( new_cli->name, 1, socket.BLOCK ) Then 
					new_cli->cnx = new_cnx
					ServerOutput "New Connection: " & Str(*(new_cli->cnx->connection_info()))
					clients += 1
					If firstCli = 0 Then firstCli = new_cli
					If lastCli <> 0 Then lastCli->nextPl = new_cli
					lastCli = new_cli
					lastCli->cnx->put(Chr(protocol.message) & "Connection to server established")
					lastCli->gun = New Weapon
					lastCli->thread = ThreadCreate( Cast(Sub(ByVal As Any Ptr), @ServerThread), lastCli )
				'EndIf
			'EndIf
			MutexUnLock(lock_players)
			new_cnx = New socket
			new_cli = New CLIENT_NODE
		EndIf
		Sleep 20,1
	Loop
	ServerOutput "Listener thread terminated"
End Sub


StartTimer = Timer
StartTime = Date & " " & Time
ServerOutput "#### Starting aa-server on " & StartTime
Dim Shared As Integer port = 11002
Dim As socket sock, httpsock
Var res = sock.server( port )
If( res ) Then Print translate_error( res )

Var t = ThreadCreate( Cast(Sub(ByVal As Any Ptr), @accept_thread), @sock )
ServerOutput "Listening on port " & port


CreateGame("Dummy Test Game", "dummy")
ServerOutput "Created one game"


Dim As Double temptime = Timer
'***********'
Dim As String k = ""
Do
	Sleep 500, 1
	If Timer + 60 > temptime Then ticks+=1
	k = Inkey
Loop Until k = Chr(27) Or k = Chr(255)+"k" Or serverShutdown <> 0
'***********'
If serverShutDown = 0 Then serverShutdown = 1
ServerOutput "Shutting down server..."
'MutexLock(lock_players)
'	Dim plNode As CLIENT_NODE Ptr = firstCli
'	Do While plNode <> 0
'		plNode->cnx->put(Chr(protocol.message) & "SERVER: Server is shutting down...")
'		plNode = plNode->nextPl
'	Loop
'MutexUnLock(lock_players)
Sleep 2500, 1
sock.close( )
'MutexLock(lock_players)
'	Do While plNode <> 0
'		ThreadWait(plNode->thread)  ' tästä tulis luultavasti null pointereita...
'		plNode = plNode->nextPl
'	Loop
'MutexUnLock(lock_players)
ThreadWait(t)
'ThreadWait(http_t)
ServerOutput "#### Server terminated on " & Date & " " & Time
If serverShutdown = 2 Then Run exename
End


''					''
''	ServerThread	''
''					''
Sub ServerThread( curCli As CLIENT_NODE Ptr )
	Dim As Integer h = 0, i = 0, j = 0
	Dim As String msg = "", tempst = ""
	Var moveTimer = DelayTimer(0.05)
	Do Until curCli->cnx->is_closed() Or serverShutdown <> 0
		'process incoming data
		If( curCli->cnx->get( h ) ) Then 
		If( curCli->cnx->get( msg , 1, socket.block ) ) Then
		'ServerOutput Str(curCli->curGame)
		If curCli->curGame <> 0 Then
			Select Case Asc(Left(msg,1))
				Case protocol.updatePos
					'ServerOutput "Movement: "+Str(Asc(Mid(msg,2)))
					If moveTimer.hasExpired Then
					i = curCli->x
					j = curCli->y
					Select Case Asc(Mid(msg,2))
						Case actions.north : j -= 1
						Case actions.east  : i += 1
						Case actions.south : j += 1
						Case actions.west  : i -= 1
					End Select
					If curCli->curGame->map(i,j) = Asc(" ") Then
						curCli->x = i : curCli->y = j
						curCli->curGame->sendToAll(Chr(protocol.updatePos, curCli->id, i, j))
					EndIf
					moveTimer.start
					EndIf
				Case protocol.newBlastWave
					If curCli->getEne() > curCli->gun->energy Then
						'curCli->curGame->sendToAll(Chr(protocol.newBlastWave, curCli->x, curCli->y))
						'Var newBlast = new BlastWave
						'curCli->curGame->addBlastWave(newBlast)
						curCli->gun->shoot(curCli)
					EndIf
				Case protocol.message
					curCli->curGame->sendToAll(Mid(msg,2))
					ServerOutput("MSG>"&Mid(msg,2))
			End Select
			
		' Starting stuff
		Else
			h = Asc(Left(msg,1))
			'ServerOutput msg
			If curCli->name = "" Then
				If h = protocol.introduce Then
					curCli->name = Mid(msg,2)
					ServerOutput "Connection " & Str(*(curCli->cnx->connection_info())) & " identified as " & curCli->name
				EndIf
			ElseIf h = protocol.join Then
				ServerOutput "Join request detected"
				curCli->id = games(1)->addPlayer(curCli)
				ServerOutput "Assigned " & curCli->name & " to id " & Str(curCli->id) & " and game " & Str(curCli->curGame->id)
				ServerOutput "Sending map"
				For j = 1 To mapHeight
					tempst = ""
					For i = 1 To mapWidth
						tempst += Chr(curCli->curGame->map(i,j))
					Next i
					curCli->send(Chr(protocol.mapData, j)+tempst)
				Next j
				ServerOutput "Sending introductions"
				curCli->curGame->sendToAll(Chr(protocol.introduce, curCli->id, curCli->x, curCli->y) & curCli->name)
				For i = 1 To maxPlayers
					If curCli->curGame->players(i) <> 0 AndAlso curCli->curGame->players(i) <> curCli Then
						curCli->send(Chr(protocol.introduce, curCli->curGame->players(i)->id, curCli->curGame->players(i)->x, curCli->curGame->players(i)->y) & curCli->curGame->players(i)->name)
					EndIf
				Next i

			EndIf
		EndIf
		EndIf
		EndIf
		Sleep 5,1
	Loop
	If curCli->curGame <> 0 Then curCli->curGame->sendToAll(Chr(protocol.updateStatus, curCli->id))
	If serverShutdown <> 0 And (Not curCli->cnx->is_closed()) Then curCli->cnx->put(Chr(protocol.message) & "SERVER: Server is shutting down...")
	curCli->cnx->close()
	ServerOutput "Connection to " & curCli->name & " terminated"
	DeletePlayer(curCli)
End Sub


'Sub AddLog(logstr As String, filename As String = "log.txt")
'	Var f = FreeFile
'	Open filename For Append As #f
'		Print #f, logstr
'   Close #f
'End Sub


Sub ServerOutput(_st As String)
	MutexLock(lock_output)
	Print _st
	AddLog(_st, "server_log.txt")
	MutexUnLock(lock_output)
End Sub
