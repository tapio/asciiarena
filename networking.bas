	If game.viewLevel <> zGalaxy Then
		For i = 1 To numPlayers
			Draw String ( viewStartX + 8*(viewX + (CInt(players(i).x)-CInt(pl.x))), viewStartY + 8*(viewY + (CInt(players(i).y)-CInt(pl.y))) ), Chr(234), RGB(100,100,100)
		Next i
	EndIf 
	
	If sock.is_closed = FALSE Then
		'process incoming
		If sock.get(traffic_in) Then
			Select Case (Asc(Left(traffic_in,1)) And actionMask)
				Case actions.serverQuery
					testbyte = ( Asc(Left(traffic_in,1)) And queries.ping)
					If ( testbyte ) <> 0 Then
						AddMsg("PING: " & Str(CInt((Timer-pingTime)*1000.0)))
						pingTime = 0
					EndIf 
				Case actions.message
					AddMsg(Mid(traffic_in,2))
				Case actions.updatePos
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
				Case actions.changeArea
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
				Case actions.modifyArea
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
				Case actions.areaStatus
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
			If game.viewLevelChanged Then
				If game.viewLevel <> zGalaxy Then
					traffic_out = Chr(actions.changeArea + game.viewLevel) & my_name & SEP & Str(Int(pl.x)) & SEP & Str(Int(pl.y)) & SEP & game.getAreaID
					'AddMsg("OUT:"&traffic_out)
					sock.put(1)
					sock.put(traffic_out)
					traffic_out = ""
					hasMoved = 0
					game.viewLevelChanged = 0
					trafficTimer.start
				EndIf
			ElseIf pendingModifications > 0 Then
				traffic_out = Chr(actions.modifyArea + game.viewLevel) & modQueue(1)
				'AddMsg("OUT:"&traffic_out)
				sock.put(1)
				sock.put(traffic_out)
				traffic_out = ""
				trafficTimer.start
				For i = 1 To pendingModifications-1
					modQueue(i) = modQueue(i+1)
				Next i
				pendingModifications-=1
				ReDim Preserve modQueue(1 To pendingModifications) As String	
				trafficTimer.start
			ElseIf hasMovedOnline Then
				traffic_out = Chr(actions.updatePos + game.viewLevel) & my_name & SEP & Str(CInt(pl.x)) & SEP & Str(CInt(pl.y))
				'AddMsg("OUT:"&traffic_out)
				sock.put(1)
				sock.put(traffic_out)
				traffic_out = ""
				hasMovedOnline = 0
				trafficTimer.start
			ElseIf serverQueries <> 0 Then
				traffic_out = Chr(actions.serverQuery + serverQueries)
				'AddMsg("OUT:"&traffic_out)
				sock.put(1)
				sock.put(traffic_out)
				pingTime = Timer
				traffic_out = ""
				serverQueries = 0
				trafficTimer.start
			ElseIf msg <> "" And consoleOpen = 0 Then
				If Left(msg,7) = "/toall " Then traffic_out = Chr(actions.message+success) & my_name & ":: " & Mid(msg,8) Else traffic_out = Chr(actions.message) & my_name & ": " & msg
				'AddMsg("OUT:"&traffic_out)
				sock.put(1)
				sock.put(traffic_out)
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