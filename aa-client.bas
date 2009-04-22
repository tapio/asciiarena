' Ascii Arena

Const VERSION = "0.0.1"

#Define NETWORK_enabled

#Include "PNGscreenshot.bas"
#Include Once "def.bi"
#Include Once "util.bas"
#Include Once "words.bi"
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
Const viewStartX = scrW * .5 - viewX * 8
Const viewStartY = 7 * 8

Const log_enabled = -1

Declare Function GameInput(promt As String = "", x As Integer, y As Integer, stri As String, k As String = "") As String
'Declare Function GoToCoords(stamp As String, ByRef pl As SpaceShip, ByRef tileBuf As TileCache) As Byte
Declare Sub GenerateTextures(seed As Double = -1)
Declare Sub GenerateDistantStarBG(array() As UByte)
Declare Sub AddVariance(ByRef tile As ASCIITile, variance As Short)
Declare Function AddVarianceToColor(col As UInteger, variance As Short) As UInteger
Declare Sub AddMsg(_msg As String)
Declare Sub PrintMessages(x As Integer, y As Integer, _count As Integer = 1)
Declare Sub DrawASCIIFrame(x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, col As UInteger = 0, Title As String = "")
Declare Sub SaveBookmarks(filename As String = "bookmarks.ini")
Declare Sub LoadBookmarks(filename As String = "bookmarks.ini")

Const TimeSyncInterval = 5.000
Declare Sub TimeManager()
Declare Function GetTime() As ULongInt
Dim Shared As ULongInt gametime = 0


#Include Once "protocol.bi"
#Include Once "universeTypes.bi"
#Include Once "helps.bas"

'Dim Shared As UByte farStarBG(1024, 1024)
'GenerateDistantStarBG(farStarBG()) 

#Define char_starship Chr(234)
#Define char_lander   Chr(227)
#Define char_walking  "@"

Type Player
	id 	 As UByte
	name As String
	x    As UByte
	y    As UByte
    curIcon As String = char_starship
    Declare Constructor(x As UByte = 0, y As UByte = 0)
End Type
    Constructor SpaceShip(x As Double = 0, y As Double = 0
        this.x   = x
        this.y   = y
    End Constructor

Declare Sub Keys(ByRef pl As SpaceShip, ByRef tileBuf As TileCache)


ReDim players(0) As Player
Dim numPlayers As Integer = 0
Dim As String temp, temp2, tempst
Dim As String msg = "", traffic_in = "", traffic_out = "", k = "" 'k = key
Dim As Double pingTime
Dim As UByte char, testbyte
Dim As Integer i,j, tempx,tempy, tempz, count

#Ifndef SEP
	#Define SEP Chr(1)
#EndIf

	Dim Shared As Integer pendingModifications = 0
	Dim Shared modQueue(pendingModifications) As String
	'If log_enabled Then AddLog(my_name & "---NEW---")

    Dim Shared game As GameLogic
        game.viewLevel = zStarmap
        game.curGalaxy = Galaxy(42)
        game.updateBounds
        game.curStarmap.seed = game.curGalaxy.seed
        BuildNoiseTables game.curStarmap.seed, 8
    'Dim pl As SpaceShip = SpaceShip(GALAXYSIZE/2,GALAXYSIZE/2,90)
    Dim pl As SpaceShip = SpaceShip(game.curStarmap.size/2,game.curStarmap.size/2,90)
    Dim tileBuf As TileCache = TileCache(pl.x, pl.y, @GetStarmapTile)
    GoToCoords("4194312,4194292", pl, tileBuf)
    Dim gameTimer As FrameTimer

    Dim trafficTimer As DelayTimer = DelayTimer(0.05)
	Dim Shared As Byte moveStyle = 0, hasMoved = 0, hasMovedOnline = 0
	Dim Shared As UByte serverQueries = 0, gotoBookmarkSlot = 0
	Dim Shared As Byte consoleOpen = 0, auto_slow = 0
	Dim Shared As String bookmarks(1 To 9)
	Dim As Byte helpscreen = 0

	LoadBookmarks()

	#Ifdef NETWORK_enabled
		sock.put(1)
		sock.put(Chr(protocol.changeArea + game.viewLevel) & my_name & SEP & Str(CInt(pl.x)) & SEP & Str(CInt(pl.y)) & SEP & game.getAreaID)
	#EndIf


    ' ------- MAIN LOOP ------- '
    Do
        gameTimer.Update
		TimeManager()
        ScreenSet workpage, workpage Xor 1
        Cls
        
        If helpscreen = 0 Then
        If consoleOpen = 0 Then Keys pl, tileBuf
        If gotoBookmarkSlot <> 0 Then tempz = GoToCoords(bookmarks(gotoBookmarkSlot),pl,tileBuf): gotoBookmarkSlot = 0
        
        UpdateCache tileBuf, CInt(pl.x),CInt(pl.y), viewX,viewY
        DrawView tileBuf, CInt(pl.x),CInt(pl.y), viewStartX,viewStartY, viewX,viewY
        Draw String ( viewStartX + 8*viewX, viewStartY + 8*viewY ), pl.curIcon, RGB(150,250,150)
        Draw String ( viewStartX + 8*(viewX+CInt(Cos(pl.ang*DegToRad)*10)), viewStartY + 8*(viewY-CInt(Sin(pl.ang*DegToRad)*10)) ), "x", RGB(0,255,0)
        If pl.upX > 0 AndAlso Abs(pl.upX-pl.x) < viewX AndAlso Abs(pl.upY-pl.y) < viewY Then Draw String ( viewStartX + 8*(viewX + (pl.upX-CInt(pl.x))), viewStartY + 8*(viewY + (pl.upY-CInt(pl.y))) ), "X", RGB(200,0,200)
		If game.viewLevel = zSystem Then
			For i = 0 To game.curSystem.starCount + game.curSystem.planetCount - 1
				Dim As Integer xdiff = game.curSystem.objects(i).x - pl.x
				Dim As Integer ydiff = game.curSystem.objects(i).y - pl.y
				If Abs(xdiff) > viewX Or Abs(ydiff) > viewY Then
					If Abs(xdiff) > Abs(ydiff) Then
						If xdiff < 0 Then xdiff = -viewX: char = 17 Else xdiff = viewX: char = 16
					Else
						If ydiff < 0 Then ydiff = -viewY: char = 30 Else ydiff = viewY: char = 31
					EndIf
					xdiff = Clip(xdiff,-viewX,viewX)
					ydiff = Clip(ydiff,-viewY,viewY)
					Draw String ( viewStartX + 8*(viewX+xdiff), viewStartY + 8*(viewY+ydiff) ), Chr(char), game.curSystem.objects(i).col
				EndIf
			Next i
		EndIf


		For i = 1 To numPlayers
			Draw String ( viewStartX + 8*(viewX + (CInt(players(i).x)-CInt(pl.x))), viewStartY + 8*(viewY + (CInt(players(i).y)-CInt(pl.y))) ), Chr(234), RGB(100,100,100)
		Next i
	
	If sock.is_closed = FALSE Then
		'process incoming
		If sock.get(traffic_in) Then
			Select Case Asc(Left(traffic_in,1))
				Case protocol.introduce

				Case protocol.message
					AddMsg(Mid(traffic_in,2))
				Case protocol.updatePos
					temp = GetWord(Mid(traffic_in,2),1,SEP)
					For i = 1 To numPlayers
						If players(i).id = temp Then
							players(i).x = CInt( GetWord(traffic_in,2,SEP) )
							players(i).y = CInt( GetWord(traffic_in,3,SEP) )
							i = -1 : Exit For
						EndIf
					Next i
					If i <> -1 Then
						numPlayers+=1
						ReDim Preserve players(1 To numPlayers) As Player
						players(numPlayers).id = temp
						players(numPlayers).x  = CInt( GetWord(traffic_in,2,SEP) )
						players(numPlayers).y  = CInt( GetWord(traffic_in,3,SEP) )
						If log_enabled Then AddLog(my_name & "Player " & temp & " added.")
					EndIf
				Case protocol.changeArea
					temp = Mid(traffic_in,2)
					For i = 1 To numPlayers
						If players(i).id = temp Then
							players(i) = players(numPlayers)
							players(numPlayers).id = ""
							numPlayers-=1
							If log_enabled Then AddLog(my_name & "Player " & temp & " erased.")
							Exit For
						EndIf
					Next i
				Case protocol.modifyArea
					temp = Mid(traffic_in,2)
					count = CInt( GetWord(temp,1,SEP) )
					temp = Mid(traffic_in,InStr(traffic_in,SEP)+1)
					j = 0
					'Dim tempTex As AsciiTexture
					For i = 1 To count
						tempx = Asc(Mid(temp,j+1,1)) - detCoordOffSet
						tempy = Asc(Mid(temp,j+2,1)) - detCoordOffSet
						tempz = Asc(Mid(temp,j+3,1))
						AddLog("xyz" & tempx & " " & tempy & " " & tempz)
						'tempTex = ASCIITexture(Asc(Mid(temp,j+3,1)), Asc(Mid(temp,j+4,1)), Asc(Mid(temp,j+5,1)), Asc(Mid(temp,j+6,1)) )
						game.curArea.Modify( tempx,tempy, ASCIITile(buildings(tempz).tex,0,buildings(tempz).flags) )
						j+=3
					Next i		
					tileBuf.isEmpty = -1
				Case protocol.areaStatus
					temp = Mid(traffic_in,2)
					numPlayers = CInt( GetWord(temp,1,SEP) )
					ReDim players(1 To numPlayers) As Player
					j = 2
					For i = 1 To numPlayers
						players(i).id = GetWord(temp,j,SEP)
						players(i).x  = CInt( GetWord(temp,j+1,SEP) )
						players(i).y  = CInt( GetWord(temp,j+2,SEP) )
						j+=3
						If log_enabled Then AddLog(my_name & "Player " & players(i).id & " added.")
					Next i
			End Select
	
		End If
		
		'send out
		If trafficTimer.hasExpired Then
			ElseIf hasMovedOnline Then
				traffic_out = Chr(protocol.updatePos, pl.id, pl.x, pl.y)
				'AddMsg("OUT:"&traffic_out)
				sock.put(1)
				sock.put(traffic_out)
				traffic_out = ""
				hasMovedOnline = 0
				trafficTimer.start
			ElseIf msg <> "" And consoleOpen = 0 Then
				traffic_out = Chr(protocol.message) & my_name & ": " & msg
				'AddMsg("OUT:"&traffic_out)
				sock.put(1)
				sock.put(traffic_out)
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
 		
        k = InKey
		If k = Chr(255,68) Then SavePNG("shots/shot"+Str(Int(Rnd*9000)+1000)+".png")': Sleep 1000
        If consoleOpen Then
        	msg = GameInput("> ", viewStartX, scrH-16, msg, k)
        	'#Ifdef CLIPBOARD_enabled
        		If MultiKey(KEY_CONTROL) And MultiKey(KEY_V) Then msg = msg & getClip():Sleep 500
        		If MultiKey(KEY_CONTROL) And MultiKey(KEY_C) Then setClip(msg):Sleep 500
        	'#EndIf
        	If MultiKey(KEY_ENTER) Then
        		consoleOpen = 0
        		If msg = "/ping" Then serverQueries += queries.ping : msg = ""
        		If msg = "/info" Or msg = "/who" Or msg = "/count" Then serverQueries += queries.playerCount : msg = ""
        		If Left(msg,6) = "/goto " Then GoToCoords(Mid(msg,7),pl,tileBuf): msg = ""
        	EndIf
        Else
        	If helpscreen = 1 And k <> "" Then helpscreen = 0
        	If k = Chr(255,59) Then helpscreen = 1
        EndIf
        switch(workpage)
        Sleep 2,1 'this hack reduces cpu usage in some cases
    Loop Until k = Chr(27) Or k = Chr(255) & "k"

#Ifdef NETWORK_enabled
    sock.close()
#EndIf
    End


''''''''''''''''''''''''''''
'''                      '''
'''   END OF MAIN LOOP   '''
'''                      '''
''''''''''''''''''''''''''''


Sub Keys(ByRef pl As SpaceShip, ByRef tileBuf As TileCache)
	#Macro dostuff(updown)
	    game.viewLevel += updown
	    If updown < 0 Then pl.upX = pl.x : pl.upY = pl.y Else pl.upX = -100 : pl.upY = -100
	    game.updateBounds
	    moveStyle = 0
	    pl.spd = 0
	    game.viewLevelChanged = -1
	#EndMacro
    Static moveTimer As DelayTimer = DelayTimer(0.01)
    Static keyTimer As DelayTimer = DelayTimer(0.5)
    hasMoved = 0
    
    If MultiKey(KEY_LSHIFT) Then moveTimer.delay = 0 Else moveTimer.delay = .002
    'If moveStyle = 0 Then moveTimer.delay = .1 Else moveTimer.delay = .002
    
    Dim As Integer tempx, tempy
    
    If moveTimer.hasExpired Then
        pl.oldx = pl.x : pl.oldy = pl.y
        If moveStyle = 0 Then
        	Dim As UByte tempang = 0
        	pl.spd = 0
	        If MultiKey(KEY_UP)    Then tempang+=&b1000: pl.spd = .333
	        If MultiKey(KEY_DOWN)  Then tempang+=&b0010: pl.spd = .333
	        If MultiKey(KEY_LEFT)  Then tempang+=&b0001: pl.spd = .333
	        If MultiKey(KEY_RIGHT) Then tempang+=&b0100: pl.spd = .333
	        If pl.spd <> 0 Then pl.ang = table_dirAngles(tempang)
	        If MultiKey(KEY_W) AndAlso game.viewLevel <> zDetail AndAlso game.viewLevel <> zGalaxy Then moveStyle = 1: pl.spd = 1.0
        Else
        	'If MultiKey(KEY_SPACE) Then pl.spd = 0
	        If MultiKey(KEY_W) Then
	        	pl.spd += .02
	        Else
	        	If auto_slow Then pl.spd *= .95
	        	If pl.spd < .2 Then pl.spd = 0: moveStyle = 0
	        EndIf
	        If MultiKey(KEY_S)  Then pl.spd = Max(0,pl.spd-.01)': moveTimer.start
        EndIf
        If MultiKey(KEY_A) Then pl.ang = wrap(pl.ang+5,360): moveTimer.start
        If MultiKey(KEY_D) Then pl.ang = wrap(pl.ang-5,360): moveTimer.start
		If pl.spd <> 0 Then
	        pl.x = pl.x + Cos(pl.ang * DegToRad) * pl.spd
	        pl.y = pl.y - Sin(pl.ang * DegToRad) * pl.spd
			hasMoved = -1
			moveTimer.start
		EndIf
		'If ( game.viewLevel = zGalaxy ) AndAlso (Not inBounds(pl.x,0,game.boundW(game.viewLevel)-1) OrElse Not inBounds(pl.y,0,game.boundH(game.viewLevel)-1)) Then
		'	pl.x = pl.oldx: pl.y = pl.oldy
		If game.viewLevel = zDetail AndAlso (pl.x <> pl.oldx OrElse pl.y <> pl.oldy) Then
			If (game.curArea.areaArray(CInt(pl.x),CInt(pl.y)).flags And BLOCKS_MOVEMENT) <> 0 Then pl.x = CInt(pl.oldx): pl.y = CInt(pl.oldy): pl.spd = 0
			If (Not inBounds(pl.x,0,game.boundW(game.viewLevel)-1) OrElse Not inBounds(pl.y,0,game.boundH(game.viewLevel)-1)) Then
				tempx = game.curArea.x
				tempy = game.curArea.y
				Dim As Integer arriveX = CInt(pl.x), arriveY = CInt(pl.y)
				If pl.x < 0 Then tempx -= 1: arriveX = game.boundW(game.viewLevel)-1
				If pl.x > game.boundW(game.viewLevel)-1 Then tempx += 1: arriveX = 0
				If pl.y < 0 Then tempy -= 1: arriveY = game.boundH(game.viewLevel)-1
				If pl.y > game.boundH(game.viewLevel)-1 Then tempy += 1: arriveY = 0
			    game.curArea = SurfaceArea(tempx, tempy, tempy * game.curPlanet.w + tempx)
	            game.updateBounds
                pl.x = arriveX : pl.y = arriveY
                tileBuf = TileCache(pl.x, pl.y, @GetAreaTile)
        		game.viewLevelChanged = -1
			EndIf
		ElseIf (Not inBounds(pl.x,0,game.boundW(game.viewLevel)-1)) OrElse (Not inBounds(pl.y,0,game.boundH(game.viewLevel)-1)) Then
			If game.viewLevel = zSystem Then
                pl.x = game.curSystem.x
                pl.y = game.curSystem.y
                tileBuf = TileCache(pl.x, pl.y, @GetStarmapTile)
                BuildNoiseTables game.curStarmap.seed, 8
				dostuff(-1)
			Else
				If pl.x < 0 Then pl.x += game.boundW(game.viewLevel)
				If pl.y < 0 Then pl.y += game.boundH(game.viewLevel)
				If pl.x > game.boundW(game.viewLevel) Then pl.x -= game.boundW(game.viewLevel)
				If pl.y > game.boundH(game.viewLevel) Then pl.y -= game.boundH(game.viewLevel)
				'pl.x = wrap(pl.x, game.boundW(game.viewLevel))
				'pl.y = wrap(pl.y, game.boundH(game.viewLevel))
			EndIf
		EndIf
    EndIf
    
    Dim As Byte controlKey = 0, buildMode = 0
    If MultiKey(KEY_B) And game.viewLevel = zDetail Then buildMode = -1'Not buildmode '-1
    If MultiKey(KEY_CONTROL) Then controlKey = -1
    
    tempx = CInt(pl.x): tempy = CInt(pl.y)
    ' Keys that are pressed, not held down: 
    If keyTimer.hasExpired Then
    	Dim As String tempk
    	If MultiKey(KEY_T) Then consoleOpen = -1: tempk = InKey: Exit Sub
    	'If MultiKey(KEY_F2) Then switch(moveStyle): pl.x = Int(pl.x): pl.y = Int(pl.y): keyTimer.start
    	If MultiKey(KEY_F3) Then switch(auto_slow): keyTimer.start
    	#Ifdef NETWORK_enabled
    	If MultiKey(KEY_I) Then serverQueries = queries.areaInfo   : keyTimer.start
    	If MultiKey(KEY_O) Then serverQueries = queries.playerCount: keyTimer.start
    	If MultiKey(KEY_P) Then serverQueries = queries.ping       : keyTimer.start
    	#EndIf
    	If buildMode Then
    		For i As Integer = 1 To BuildingCount
    			If MultiKey(i+1) Then
    				If game.curArea.Modify(tempx,tempy, ASCIITile( buildings(i).tex,0,buildings(i).flags )) Then
						#Ifdef NETWORK_enabled
				    		pendingModifications+=1
				    		ReDim Preserve modQueue(1 To pendingModifications) As String
				    		modQueue(pendingModifications) = Chr(tempx+detCoordOffSet,tempy+detCoordOffSet,i)
						#Endif
						'RefreshTile(tileBuf,tempx,tempy)
						tileBuf.isEmpty = -1
					EndIf
					keyTimer.start
    				Exit For
    			EndIf
    		Next i
       	EndIf
    	If MultiKey(KEY_N) And MultiKey(KEY_B) And game.viewLevel = zDetail Then
    		For i As Integer = 1 To 100
    			tempx = Rand(1,127) : tempy = Rand(1,127)
    			game.curArea.Modify(tempx,tempy,ASCIITile(ASCIITexture(Asc("#"), 128,128,128),0,BLOCKS_MOVEMENT))
	    		pendingModifications+=1
	    		ReDim Preserve modQueue(1 To pendingModifications) As String
	    		modQueue(pendingModifications) = SEP & Str(tempx) & SEP & Str(tempy) & SEP & "#" & Chr(128,128,128)
    		Next i
    		tileBuf.isEmpty = -1
    		keyTimer.start
    	EndIf

    If hasMoved Then hasMovedOnline = -1
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
		Draw String ( x, y + (i-1)*8 ), messageBuffer(i), RGB( 	blend(mcolr,mcolmin,(_count-i)/_count), _
																blend(mcolg,mcolmin,(_count-i)/_count), _
																blend(mcolb,mcolmin,(_count-i)/_count)  )
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

#Include "world.bas"
