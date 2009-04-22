Const VERSION = "0.5.0"
WindowTitle "Infiniverse Server"

#Ifdef __FBWIN32__
	#Define exename "infiniverse-server.exe"
#Else
	#Define exename "infiniverse-server"
#EndIf

#Include Once "chisock/chisock.bi"
#Include Once "def.bi"
#Include Once "../../TileEngine/types.bi"

Using chi

Declare Sub ServerOutput(_st As String)

#Include "../protocol.bi"
#Include "logic.bas"

Declare Sub ServerThread( curCli As CLIENT_NODE Ptr)


Sub http_thread( Byval s As socket Ptr )
	If( s->server( socket.PORT.HTTP ) = 0 ) Then
		Do
			Dim As socket new_sock
			Dim As String st
			If( new_sock.listen_to_new(*s) ) Then
				st = !"HTTP/1.0 200 OK\n" & !"Content-Type: text/html\n" !"Connection: Close\n\n"
				st += !"<html> <head> <title>Infiniverse</title> </head>\n"
				st += !"<body>Homepage <a href=""http://aave.phatcode.net/ascii/"">here.</a><br><br>\n"
				st += !"<b>Server stats:</b><ul><li>Players online: " & Str(clients) & "</li><li>Up since: " & StartTime & "</li><li>Registered users: " & Str(regCount) & "</li>"
				st += !"<li>Software version: " & VERSION & !"</li></ul>\n</body>\n</html>"
				new_sock.put( *Cast(UByte Ptr, StrPtr(st)), Len(st) )
			EndIf
		Loop While Not s->is_closed
	Else
		ServerOutput "HTTP Server couldn't start"
	End If
End Sub


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
				'If( new_cnx->get( new_cli->name, 1, socket.BLOCK ) ) Then 
					new_cli->cnx = new_cnx
					ServerOutput "New Connection: " & Str(*(new_cli->cnx->connection_info()))
					clients += 1
					If firstCli = 0 Then firstCli = new_cli
					If lastCli <> 0 Then lastCli->nextPl = new_cli
					lastCli = new_cli
					lastCli->cnx->put(Chr(actions.message) & "Connection to server established")
					lastCli->thread = ThreadCreate( Cast(Sub(ByVal As Any Ptr), @ServerThread), lastCli )
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
ServerOutput "#### Starting server on " & StartTime
LoadModifications
regCount = CountRegPlayers()
Dim Shared As Integer port = 11000
Dim As socket sock, httpsock
Var res = sock.server( port )
If( res ) Then
	Print translate_error( res )
EndIf

'Var http_t = ThreadCreate( Cast(Sub(ByVal As Any Ptr), @http_thread), @httpsock )
Var t = ThreadCreate( Cast(Sub(ByVal As Any Ptr), @accept_thread), @sock )
ServerOutput "Listening on port " & port

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
'		plNode->cnx->put(Chr(actions.message) & "SERVER: Server is shutting down...")
'		plNode = plNode->nextPl
'	Loop
'MutexUnLock(lock_players)
Sleep 2500, 1
sock.close( )
httpsock.close( )
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

Sub ServerThread( curCli As CLIENT_NODE Ptr )
	Dim As Integer h = 0
	Dim As String msg = "", tempst = ""
	Do Until curCli->cnx->is_closed() Or serverShutdown <> 0
		'process incoming data
		If( curCli->cnx->get( h ) ) Then 
		If( curCli->cnx->get( msg , 1, socket.block ) ) Then
		If curCli->name <> "" Then
			Select Case (Asc(Left(msg,1)) And actionMask)
				Case actions.message
					ServerOutput("MSG>"&Mid(msg,2))
					If (Asc(Left(msg,1)) And success) <> success Then 
						SendToAllInArea(curCli->actArea, msg)
					Else 'send to everyone
						Dim plNode As CLIENT_NODE Ptr = firstCli
						MutexLock(lock_players)
						Do While plNode <> 0
							plNode->cnx->put( msg )
							plNode = plNode->nextPl
						Loop
						MutexUnLock(lock_players)
					EndIf 
				Case actions.updatePos
					SendToAllInArea(curCli->actArea, msg, curCli->name)
					MutexLock(lock_players)
					curCli->x = CInt( GetWord(msg,2,SEP) )
					curCli->y = CInt( GetWord(msg,3,SEP) )
					MutexUnLock(lock_players)
				Case actions.changeArea
					SendToAllInArea(curCli->actArea, Chr(actions.changeArea+curCli->vLvl) & curCli->name, curCli->name)
					RemoveFromArea(curCli, curCli->actArea)
					MutexLock(lock_players)
					curCli->vLvl = (Asc(Left(msg,1)) And viewLvlMask)
					curCli->x = CInt( GetWord(msg,2,SEP) )
					curCli->y = CInt( GetWord(msg,3,SEP) )
					MutexUnLock(lock_players)
					tempst = GetWord(msg,4,SEP)
					AddToArea(curCli, GetActiveAreaPtr(tempst, curCli->vLvl))
					'send back info about players
					tempst = GetAreaPlayers(curCli->actArea, curCli->name)
					If tempst <> "0" Then MutexLock(lock_players): curCli->cnx->Put( Chr(actions.areaStatus) & tempst ): MutexUnLock(lock_players)
					'send arrival info to others
					tempst = Chr(actions.updatePos + curCli->vLvl) & curCli->Name & SEP & Str(curCli->x) & SEP & Str(curCli->y)
					SendToAllInArea(curCli->actArea, tempst, curCli->name)
					'send back info about area changes
					If curCli->vLvl = zDetail Then
						tempst = GetAreaChanges(curCli->actArea)
						If tempst <> "0" Then MutexLock(lock_players): curCli->cnx->Put( Chr(actions.modifyArea) & tempst ): MutexUnLock(lock_players)
					EndIf
				Case actions.modifyArea
					If curCli->vLvl = zDetail Then
						Dim m As Modification
						m.x = Asc( Mid(msg,2,1) ) - detCoordOffSet
						m.y = Asc( Mid(msg,3,1) ) - detCoordOffSet
						m.bID = Asc( Mid(msg,4,1) )
						DoModification(curCli->actArea, m)
						SendToAllInArea(curCli->actArea, Chr(actions.modifyArea) & "1" & SEP & Chr(m.x+detCoordOffSet, m.y+detCoordOffSet, m.bID),curCli->name)
					EndIf
				Case actions.areaStatus
					MutexLock(lock_players)
					curCli->cnx->Put(Chr(actions.areaStatus) & GetAreaPlayers(curCli->actArea, curCli->name))
					MutexUnLock(lock_players)
				Case actions.serverQuery
					Select Case (Asc(Left(msg,1)) And &b0111)
						Case queries.ping: 			MutexLock(lock_players): _
							curCli->cnx->Put(Chr(actions.serverQuery + queries.ping)): MutexUnLock(lock_players)
						Case queries.playerCount: 	MutexLock(lock_players): _
							curCli->cnx->Put(Chr(actions.message + queries.playerCount) & "Players Online: " & Str(clients)): MutexUnLock(lock_players)
						Case queries.areaInfo:		MutexLock(lock_players): _
							curCli->cnx->Put(Chr(actions.message + queries.areaInfo) & "Area id: " & curCli->actArea->id & "  Players: " & Str( curCli->actArea->plcount ) ): MutexUnLock(lock_players)
						Case queries.timeSync:		MutexLock(lock_players): _
							curCli->cnx->Put(Chr(actions.serverQuery + queries.timeSync) & Str(GetGameTicks())): MutexUnLock(lock_players)
						Case queries.adminOp
							If (curCli->flags And cflags.admin) <> 0
							Select Case Asc(Mid(msg,2,1))
								Case adminOps.shutdown
									serverShutdown = 1
								Case adminOps.restart
								
								Case adminOps.reload
								
								Case adminOps.update
								
							End Select
							EndIf
					End Select
				
			End Select
			
			' Login stuff
			Else
				Dim As Byte flag
				tempst = Mid(msg,2)
				Select Case (Asc(Left(msg,1)) And &b11110000)
					Case actions.login
						flag = LoadPlayer(GetWord(tempst,1,SEP),GetWord(tempst,2,SEP),curCli)
						If flag = 1 Then curCli->cnx->Put(Chr(actions.login+success) & "Login succesful") Else curCli->cnx->Put(Chr(actions.login) & "Bad name or password")
					Case actions.register
						If isValidName(GetWord(tempst,1,SEP)) = 0 Then
							curCli->cnx->Put(Chr(actions.register) & "Invalid name")
						Else
							flag = LoadPlayer(GetWord(tempst,1,SEP),GetWord(tempst,2,SEP),curCli)
							If flag = 0 Then
								SavePlayer(GetWord(tempst,1,SEP),GetWord(tempst,2,SEP))
								curCli->name = GetWord(tempst,1,SEP)
								curCli->cnx->Put(Chr(actions.register+success) & "Registeration complete")
								regCount+=1
							Else
								curCli->cnx->Put(Chr(actions.register) & "Name already in use")
							EndIf
						EndIf
					Case actions.serverQuery
						If (Asc(Left(msg,1)) And queries.ping)        <> 0 Then curCli->cnx->Put(Chr(actions.serverQuery + queries.ping))
						If (Asc(Left(msg,1)) And queries.playerCount) <> 0 Then curCli->cnx->Put(Chr(actions.message + queries.playerCount) & "Players Online: " & Str(clients))
				End Select
				If curCli->name <> "" Then ServerOutput "Connection " & Str(*(curCli->cnx->connection_info())) & " identified as " & curCli->name
			EndIf
		EndIf
		EndIf
		Sleep 5,1
	Loop
	If curCli->name <> "" Then SendToAllInArea(curCli->actArea, Chr(actions.changeArea) & curCli->name, curCli->name) Else curCli->Name = Str(*(curCli->cnx->connection_info()))
	If serverShutdown <> 0 And (Not curCli->cnx->is_closed()) Then curCli->cnx->put(Chr(actions.message) & "SERVER: Server is shutting down...")
	curCli->cnx->close()
	ServerOutput "Connection to " & curCli->name & " terminated"
	DeletePlayer(curCli)
End Sub


Sub AddLog(logstr As String, filename As String = "log.txt")
	Var f = FreeFile
	Open filename For Append As #f
		Print #f, logstr
    Close #f
End Sub


Sub ServerOutput(_st As String)
	MutexLock(lock_output)
	Print _st
	AddLog(_st, "server_log.txt")
	MutexUnLock(lock_output)
End Sub
