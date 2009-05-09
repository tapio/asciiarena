' Ascii Arena

Const VERSION = "0.1.0"

#Define NETWORK_enabled

#Include "PNGscreenshot.bas"
#Include Once "def.bi"
#Include Once "util.bas"
#Include Once "words.bi"
#Include Once "protocol.bi"
'#Include "fbgfx.bi"

Const scrW = 800
Const scrH = 600
ScreenRes scrW, scrH, 32, 2', 1
WindowTitle "AsciiArena Client"
Dim As Byte workpage

'Const viewX = 36
'Const viewY = 36
#Define viewX (36)
#Define viewY (36)
Const viewStartX = 8*10'scrW * .5 - viewX * 8
Const viewStartY = 8*4'7 * 8

Const log_enabled = -1

Declare Function GameInput(promt As String = "", x As Integer, y As Integer, stri As String, k As String = "") As String
Declare Sub AddPlayer(As String)
Declare Sub AddMsg(_msg As String)
Declare Sub PrintMessages(x As Integer, y As Integer, _count As Integer = 1)
Declare Sub DrawASCIIFrame(x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, col As UInteger = 0, Title As String = "")
Declare Sub DrawASCIICircle(xCenter As Integer, yCenter As Integer, radius As Integer, c As UInteger=0)
Declare Sub DrawASCIIBar(x As Integer, y As Integer, w As Integer, value As Integer, maxValue As Integer, col1 As UInteger, col2 As UInteger, barchar As String = "|")

Const TimeSyncInterval = 5.000
Declare Sub TimeManager()
Declare Function GetTime() As ULongInt
Dim Shared As ULongInt gametime = 0

Dim map(1 To mapWidth,1 To mapHeight) As UByte


#Define char_starship Chr(234)
#Define char_lander   Chr(227)
#Define char_walking  "@"



Dim firstBlast As BlastWave Ptr = 0


Type Player
	id 	 As UByte
	name As String
	x    As UByte
	y    As UByte
	cond As UByte = 100
	ene  As UByte = 50
    Declare Constructor(x As UByte = 0, y As UByte = 0)
End Type
    Constructor Player(x As UByte = 0, y As UByte = 0)
        this.x   = x
        this.y   = y
    End Constructor


Dim Shared maxPlayers As Integer = 32
ReDim Shared players(maxPlayers) As Player
Dim Shared numPlayers As Integer = 0
Dim As String temp, temp2, tempst
Dim As String msg = "", traffic_in = "", traffic_out = "", k = "" 'k = key
Dim As String my_name
Dim As UByte my_id, char, testbyte
Dim As Double pingTime
Dim As Integer i,j, count, ping

#Include "crt/string.bi"
#Include "chisock/chisock.bi"
Using chi

Dim As socket sock

Randomize Timer

Dim As String serveraddress
Dim As Integer port = 11002
Var f = FreeFile
Open "server.ini" For Input As #f
	Line Input #f, serveraddress
	Input #f, port
Close #f
If serveraddress = "" Or port = 0 Then Print "Could not find server.ini or it is broken!" :Sleep:End

Print "Connecting to " & serveraddress & ":" & Str(port)

Var res = sock.client( serveraddress, port )
If( res ) Then Print translate_error(res): Sleep: End

Sleep 500
my_name =  Chr(Rand(63, 75)) +  Chr(Rand(63, 75))
sock.put(1) : sock.put(Chr(protocol.introduce) & my_name)
Print "Name sent"
Sleep 500
'*** Here be selection of game ***'

Print "Requesting to join a game..."
sock.put(1) : sock.put(Chr(protocol.join, 1) )

Do
	sock.get(traffic_in)
	If Asc(Left(traffic_in,1)) = protocol.introduce And Mid(traffic_in,5) = my_name Then
		my_id = Asc(Mid(traffic_in,2,1))
		AddPlayer(Mid(traffic_in,2))
		Exit Do
	ElseIf Asc(Left(traffic_in,1)) = protocol.mapData Then
		tempst = Mid(traffic_in, 3)
		j = Asc(Mid(traffic_in, 2, 1))
		For i = 1 To Len(tempst)
			map(i,j) = Asc(Mid(tempst,i,1))
		Next i
	EndIf
	k = InKey
	If k = Chr(27) Or k = Chr(255) & "k" Then End
	Sleep 10
Loop
'print my_id
'print players(my_id).name
'sleep

    Dim gameTimer As FrameTimer
    Dim trafficTimer As DelayTimer = DelayTimer(0.05)
	Dim moveTimer As DelayTimer = DelayTimer(0.01)
    Dim keyTimer As DelayTimer = DelayTimer(0.5)

	Dim Shared As Byte moveStyle = 0, hasMoved = 0, hasMovedOnline = 0
	Dim Shared As Byte consoleOpen = 0
	Dim As UByte tempid, tempx, tempy, move_dir
	Dim As Byte helpscreen = 0, fire = 0
	Dim As Integer xx,yy


    ' ------- MAIN LOOP ------- '
    Do
        gameTimer.Update
        ScreenSet workpage, workpage Xor 1
        Cls
        
        'If consoleOpen = 0 Then Keys pl, tileBuf
        If moveTimer.hasExpired And Not consoleOpen Then
			If MultiKey(KEY_UP)    Then move_dir = actions.north
	        If MultiKey(KEY_DOWN)  Then move_dir = actions.south
	        If MultiKey(KEY_LEFT)  Then move_dir = actions.west
	        If MultiKey(KEY_RIGHT) Then move_dir = actions.east
		EndIf
		If keyTimer.hasExpired And Not consoleOpen Then
			If MultiKey(KEY_SPACE) Then fire = TRUE: keyTimer.start
		EndIf
		
		'' Draw Map
        For j = 1 To mapHeight
			For i = 1 to mapWidth
				If map(i,j) <> 0 Then Draw String ( viewStartX+8*i, viewStartY+8*j ), Chr(map(i,j)), RGB(100,100,100)
			Next i
		Next j

		'' Draw Players
		For i = 1 To maxPlayers
			If players(i).id <> 0 Then _
				Draw String ( viewStartX + 8*players(i).x, viewStartY + 8*players(i).y ), "@", RGB(200,100,100)
		Next i
		
		'' Draw Blasts
		Dim As BlastWave Ptr curBlast = firstBlast, prevBlast = 0
		While curBlast <> 0
		'AddMsg("blast present")
			Var dist = ((Timer - curBlast->startTime) * curBlast->speed)
			Var ene = curBlast->energy - (dist * curBlast->energyUsage)
			If ene >= 1 Then
				For i = 1 To numBlastParticles
					If curBlast->particles(i) = 0 Then
						xx = curBlast->x + Cos((i-1)*blastAngle*DegToRad) * dist
						yy = curBlast->y - Sin((i-1)*blastAngle*DegToRad) * dist
						If xx>=1 AndAlso yy>=1 AndAlso xx <= mapWidth AndAlso yy <=mapHeight AndAlso map(xx,yy) = 32 Then
							Draw String (viewStartX+8*xx,viewStartY+8*yy), "*", RGB(0,255,0)
						Else
							curBlast->particles(i) = 1
						EndIf
					EndIf
				Next i
				
				prevBlast = curBlast
				curBlast = curBlast->nextNode
			Else
				If firstBlast = curBlast Then firstBlast = curBlast->nextNode
				If prevBlast <> 0 Then prevBlast->nextNode = curBlast->nextNode
				Delete(curBlast)
				If prevBlast <> 0 Then curBlast = prevBlast->nextNode Else curBlast = 0
			EndIf
		Wend
		
		'' Networking
		If sock.is_closed = FALSE Then
			'' Process incoming
			If sock.get(traffic_in) Then
			AddMsg(traffic_in)
				Select Case Asc(Left(traffic_in,1))
					Case protocol.introduce
						AddPlayer(Mid(traffic_in,2))
					Case protocol.newBlastWave
						Var newWave = New BlastWave(Asc(Mid(traffic_in,2,1)),Asc(Mid(traffic_in,3,1)))
						newWave->startTime = Timer
						newWave->energy = Asc(Mid(traffic_in,4,1))
						newWave->energyUsage = Asc(Mid(traffic_in,5,1))
						newWave->speed = Asc(Mid(traffic_in,6,1))
						newWave->nextNode = firstBlast
						firstBlast = newWave
					Case protocol.updatePos
						tempid = Asc(Mid(traffic_in,2,1))
						players(tempid).x = Asc(Mid(traffic_in,3,1))
						players(tempid).y = Asc(Mid(traffic_in,4,1))
					Case protocol.updateStatus
						tempid = Asc(Mid(traffic_in,2,1))
						i = Asc(Mid(traffic_in,3,1))
						players(tempid).cond = i
						If i = 0 Then
							players(tempid).id = 0
							numPlayers-=1
							If tempid = my_id Then
								sock.close()
								Cls
								temp = "You died!"
								Draw String ( (scrW - Len(temp)*8)*.5, (scrH-8)*.5 ), temp, RGB(255,0,0)
								switch(workpage)
								ScreenSet workpage, workpage Xor 1
								Sleep 1500,1
								Sleep
								End 
							EndIf
						Else
							players(tempid).ene = Asc(Mid(traffic_in,4,1))
						Endif
					Case protocol.message
						AddMsg(Mid(traffic_in,2))
				End Select
		
			End If
			
			'' Send out
			If trafficTimer.hasExpired Then
				If move_dir <> 0 Then
					traffic_out = Chr(protocol.updatePos, move_dir)
					AddMsg("OUT:"&traffic_out)
					sock.put(1) : sock.put(traffic_out)
					traffic_out = ""
					hasMoved = 0
					move_dir = 0
					trafficTimer.start
					moveTimer.start
				ElseIf fire <> 0 Then
					AddMsg("OUT: FIRE")
					sock.put(1) : sock.put(Chr(protocol.newBlastWave))
					traffic_out = ""
					fire = 0
					trafficTimer.start
				ElseIf msg <> "" And consoleOpen = 0 Then
					traffic_out = Chr(protocol.message) & players(my_id).name & ": " & msg
					'AddMsg("OUT:"&traffic_out)
					sock.put(1) : sock.put(traffic_out)
					'pingTime = Timer
					traffic_out = ""
					msg = ""
					trafficTimer.start
				EndIf
			EndIf
		Else
			Cls
			temp = "Connection to server lost!"
			Draw String ( (scrW - Len(temp)*8)*.5, (scrH-8)*.5 ), temp, RGB(255,0,0)
			switch(workpage)
			ScreenSet workpage, workpage Xor 1
			Sleep 1500,1
			Sleep
			End 
		EndIf


        Locate 1,1: Color RGB(80,40,40)
        Print "FPS:";gameTimer.getFPS
        'Print "UniqueId:";GetStarId(pl.x,pl.y)
        'Print "Players:";numPlayers
        'Print traffic_in
        'Print "Coords:";pl.x;pl.y
		Draw String (8*12, 8*1), "Condition:", RGB(128,128,128)
		DrawAsciiBar(12, 2, 30, players(my_id).cond, 100, RGB(255,0,0), RGB(0,255,0),   Chr(177))
		Draw String (8*12, 8*3), "Charge:", RGB(128,128,128)
		DrawAsciiBar(12, 4, 30, players(my_id).ene,  100, RGB(0,0,255), RGB(255,0,255), Chr(177))

		PrintMessages 10, 20, 8
		
        k = InKey
		If k = Chr(255,68) Then SavePNG("shots/shot"+Str(Int(Rnd*9000)+1000)+".png")': Sleep 1000
		If k = "t" Or k = "T" Then consoleOpen = TRUE
        If consoleOpen Then
        	msg = GameInput("> ", viewStartX, scrH-16, msg, k)
        	#Ifdef CLIPBOARD_enabled
        		If MultiKey(KEY_CONTROL) And MultiKey(KEY_V) Then msg = msg & getClip():Sleep 500
        		If MultiKey(KEY_CONTROL) And MultiKey(KEY_C) Then setClip(msg):Sleep 500
        	#EndIf
        	If MultiKey(KEY_ENTER) Then
        		consoleOpen = FALSE
        		'If msg = "/ping" Then serverQueries += queries.ping : msg = ""
        		'If msg = "/info" Or msg = "/who" Or msg = "/count" Then serverQueries += queries.playerCount : msg = ""
        	EndIf
        EndIf
        switch(workpage)
        Sleep 2,1 'this hack reduces cpu usage in some cases
    Loop Until k = Chr(27) Or k = Chr(255) & "k"

    sock.close()
    End

''''''''''''''''''''''''''''
'''                      '''
'''   END OF MAIN LOOP   '''
'''                      '''
''''''''''''''''''''''''''''



Sub AddPlayer(plrow As String)
	Var id = Asc(Mid(plrow,1,1))
	players(id).id		= id
	players(id).x		= Asc(Mid(plrow,2,1))
	players(id).y		= Asc(Mid(plrow,3,1))
	players(id).name	= Mid(plrow,4)
	numPlayers += 1
End Sub


Const maxMsg = 10
Dim Shared messageBuffer(1 To maxMsg) As String
Sub AddMsg(_msg As String)
	For i As Integer = maxMsg To 2 Step -1
		messageBuffer(i) = messageBuffer(i-1)
	Next i
	messageBuffer(1) = _msg
End Sub

Sub PrintMessages(x As Integer, y As Integer, _count As Integer = 1)
	#define mcolr 128.0
	#define mcolg 128.0
	#define mcolb 128.0
	#define mcolmin 32.0
	For i As Integer = 1 To _count
		If messageBuffer(i) = "" Then Return
		Draw String ( x, y + (i-1)*8 ), messageBuffer(i), _
				RGB(blend(mcolr,mcolmin,(_count-i)/_count), _
					blend(mcolg,mcolmin,(_count-i)/_count), _
					blend(mcolb,mcolmin,(_count-i)/_count))
	Next i
End Sub



Function GameInput(promt As String = "", x As Integer, y As Integer, stri As String, k As String = "") As String
	Dim As UByte j = Asc(k)
	If j >= 32 And j <= 246 Then stri = stri & Chr(j)
	If Len(stri) > 0 Then
		If j = 8 Then
			stri = Left(stri,Len(stri)-1)
		ElseIf MultiKey(KEY_BACKSPACE) Then	
			stri = Left(stri,Len(stri)-1)
		EndIf		
	EndIf
	Draw String (x,y), promt & stri & "|", RGB(150,250,250)
	Return stri
End Function

Sub DrawASCIIFrame(x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, col As UInteger = 0, Title As String = "")
	If col = 0 Then col = LoWord(Color())
	Dim As String sthorz = String((x2-x1-8)/8, Chr(205)) '196
	Draw String (x1+8,y1  ), sthorz, col
	Draw String (x1+8,y2  ), sthorz, col
	For j As Integer = y1+8 To y2-8 Step 8 
		Draw String (x1,j), Chr(186), col '179
		Draw String (x2,j), Chr(186), col '179
	Next j
	'corners
	Draw String (x1,y1), Chr(201), col '218
	Draw String (x2,y1), Chr(187), col '191
	Draw String (x1,y2), Chr(200), col '192
	Draw String (x2,y2), Chr(188), col '217
	If Title <> "" Then Line (x1+15, y1)-(x1+15+8*Len(Title), y1+7), RGB(0,0,0), BF : Draw String (x1+16, y1), Title, col
End Sub

Sub DrawASCIIBar(x As Integer, y As Integer, w As Integer, value As Integer, maxValue As Integer, col1 As UInteger, col2 As UInteger, barchar As String = "|")
	'x = 8*x : y = 8*y
	'w = value / maxValue * w
	For i As Integer = 0 To value / maxValue * w
		Draw String ( (x+i)*8, y*8 ), barchar, blendRGB(col1,col2,1.0-CSng(i)/Csng(w))
	Next i
End Sub


Sub circlePoints(cx As Integer, cy As Integer, x As Integer, y As Integer, c As UInteger)
	#Define drawChar(i,j) Draw String (viewStartX + (i)*8, viewStartY + (j)*8), "*", c
	If (x = 0) Then
		drawChar(cx, cy + y)
		drawChar(cx, cy - y)
		drawChar(cx + y, cy)
		drawChar(cx - y, cy)
	ElseIf (x = y) Then
		drawChar(cx + x, cy + y)
		drawChar(cx - x, cy + y)
		drawChar(cx + x, cy - y)
		drawChar(cx - x, cy - y)
	ElseIf (x < y) Then
		drawChar(cx + x, cy + y)
		drawChar(cx - x, cy + y)
		drawChar(cx + x, cy - y)
		drawChar(cx - x, cy - y)
		drawChar(cx + y, cy + x)
		drawChar(cx - y, cy + x)
		drawChar(cx + y, cy - x)
		drawChar(cx - y, cy - x)
	EndIf
End Sub

Sub DrawASCIICircle(xCenter As Integer, yCenter As Integer, radius As Integer, c As UInteger=0)
	If c = 0 Then c = LoWord(Color())
	Dim As Integer x = 0, y = radius, p = (5 - radius*4)/4
	circlePoints(xCenter, yCenter, x, y, c)
	While (x < y)
		x += 1
		If (p < 0) Then
			p += 2*x+1
		Else
			y -= 1
			p += 2*(x-y)+1
		EndIf
		circlePoints(xCenter, yCenter, x, y, c)
	Wend
End Sub



Sub TimeManager()
	Static timeGame As DelayTimer = DelayTimer(1.0)
	Static timeSyncTimer As DelayTimer = DelayTimer(TimeSyncInterval)
	If timeGame.hasExpired Then
		gametime+=1
		timeGame.start
	EndIf	
	If timeSyncTimer.hasExpired Then
		''''' Send time update request
		timeSyncTimer.start
	EndIf
End Sub

Function GetTime() As ULongInt
	Return gametime
End Function

