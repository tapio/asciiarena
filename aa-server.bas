Const VERSION = "0.0.1"
WindowTitle "AsciiArena Server"

#Ifdef __FBWIN32__
	#Define exename "aa-server.exe"
#Else
	#Define exename "aa-server"
#EndIf

#Include Once "chisock/chisock.bi"
#Include Once "def.bi"
#Include Once "words.bi"

Using chi

Declare Sub ServerOutput(_st As String)

#Include "protocol.bi"
#Include "server-logic.bas"

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
				'If( new_cnx->get( new_cli->name, 1, socket.BLOCK ) ) Then 
					new_cli->cnx = new_cnx
					ServerOutput "New Connection: " & Str(*(new_cli->cnx->connection_info()))
					clients += 1
					If firstCli = 0 Then firstCli = new_cli
					If lastCli <> 0 Then lastCli->nextPl = new_cli
					lastCli = new_cli
					lastCli->cnx->put(Chr(protocol.message) & "Connection to server established")
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
'		plNode->cnx->put(Chr(protocol.message) & "SERVER: Server is shutting down...")
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
				Case protocol.introduce
				
				Case protocol.message
					ServerOutput("MSG>"&Mid(msg,2))
					SendToAllInArea(curCli->actArea, msg)
				Case protocol.updatePos
					SendToAllInArea(curCli->actArea, msg, curCli->name)
					MutexLock(lock_players)
					curCli->x = CInt( GetWord(msg,2,SEP) )
					curCli->y = CInt( GetWord(msg,3,SEP) )
					MutexUnLock(lock_players)
				End Select
			End Select
			
			' Login stuff
			Else
				Dim As Byte flag
				tempst = Mid(msg,2)
				Select Case (Asc(Left(msg,1)) And &b11110000)
					Case protocol.login
						flag = LoadPlayer(GetWord(tempst,1,SEP),GetWord(tempst,2,SEP),curCli)
						If flag = 1 Then curCli->cnx->Put(Chr(protocol.login+success) & "Login succesful") Else curCli->cnx->Put(Chr(protocol.login) & "Bad name or password")
					Case protocol.register
						If isValidName(GetWord(tempst,1,SEP)) = 0 Then
							curCli->cnx->Put(Chr(protocol.register) & "Invalid name")
						Else
							flag = LoadPlayer(GetWord(tempst,1,SEP),GetWord(tempst,2,SEP),curCli)
							If flag = 0 Then
								SavePlayer(GetWord(tempst,1,SEP),GetWord(tempst,2,SEP))
								curCli->name = GetWord(tempst,1,SEP)
								curCli->cnx->Put(Chr(protocol.register+success) & "Registeration complete")
								regCount+=1
							Else
								curCli->cnx->Put(Chr(protocol.register) & "Name already in use")
							EndIf
						EndIf
					Case protocol.serverQuery
						If (Asc(Left(msg,1)) And queries.ping)        <> 0 Then curCli->cnx->Put(Chr(protocol.serverQuery + queries.ping))
						If (Asc(Left(msg,1)) And queries.playerCount) <> 0 Then curCli->cnx->Put(Chr(protocol.message + queries.playerCount) & "Players Online: " & Str(clients))
				End Select
				If curCli->name <> "" Then ServerOutput "Connection " & Str(*(curCli->cnx->connection_info())) & " identified as " & curCli->name
			EndIf
		EndIf
		EndIf
		Sleep 5,1
	Loop
	If curCli->name <> "" Then SendToAllInArea(curCli->actArea, Chr(protocol.changeArea) & curCli->name, curCli->name) Else curCli->Name = Str(*(curCli->cnx->connection_info()))
	If serverShutdown <> 0 And (Not curCli->cnx->is_closed()) Then curCli->cnx->put(Chr(protocol.message) & "SERVER: Server is shutting down...")
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
