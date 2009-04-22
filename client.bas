#Include "crt/string.bi"
#Include "chisock/chisock.bi"
Using chi

Dim As socket sock

Randomize Timer
Dim As String my_name = "", passwd = ""

Dim As String serveraddress
Dim As Integer port = 11000
Var f = FreeFile
Open "server.ini" For Input As #f
	Line Input #f, serveraddress
	Input #f, port
Close #f
If serveraddress = "" Or port = 0 Then Print "Could not findserver.ini or it is broken!" :Sleep:End

temp = "Connecting to server..."
Draw String ( (scrW - Len(temp)*8)*.5, (scrH-8)*.5 ), temp, RGB(128,128,128)

Var res = sock.client( serveraddress, port )
If( res ) Then
	temp = translate_error( res )
	Draw String ( (scrW - Len(temp)*8)*.5, (scrH+8*4)*.5 ), temp, RGB(200,0,0)
	Sleep
	End
EndIf

Sleep 200

my_name = "Aave"
sock.put(1)
sock.put(Chr(actions.login) & my_name & SEP & "peitsamo")
GoTo skipthisshit


Dim As Integer pingpong
pingTime = Timer
sock.put(1)
sock.put(Chr(actions.serverQuery+queries.ping))
Do
	sock.get(traffic_in)
	If ( Asc(Left(traffic_in,1)) And queries.ping ) = queries.ping Then
		pingpong = CInt((Timer-pingTime)*1000.0)
		pingTime = 0
		traffic_in = ""
		sock.put(1)
		sock.put(Chr(actions.serverQuery+queries.playerCount))
	ElseIf ( Asc(Left(traffic_in,1)) And queries.playerCount ) = queries.playerCount Then
		traffic_in = Mid(traffic_in,2)
		Exit Do 
	EndIf
	k = InKey
	If k = Chr(27) Or k = Chr(255) & "k" Then End
	Sleep 10
Loop

Dim As Double angle,dx,dy,fx,fy
Dim As UByte titleCol = 100, titleColDir = 1
Dim As Byte clientphase = 0
Dim As Short rows = HiWord(Width()), cols = LoWord(Width())
Const starsize = 32
Do
	switch(workpage)
	ScreenSet workpage, workpage Xor 1
	Cls
    
    ReDim temp_buffer(-starsize To starsize, -starsize To starsize) As UByte

    For j = 1 To 1024
        angle = Rnd * 360 * DegToRad
        dx = Cos(angle)
        dy = Sin(angle)
        fx = 0
        fy = 0
        For i = 1 To starsize * (Rnd*.5 + .5)
            temp_buffer(CInt(fx),CInt(fy)) = min(Int(temp_buffer(CInt(fx),CInt(fy))) + 3, 255) 
            fx += dx
            fy += dy
        Next i
    Next j
	For j = -starsize To starsize
		For i = -starsize To starsize
		    Locate j+starsize+1,i+cols/2
		    Color RGB(temp_buffer(i,j),temp_buffer(i,j),temp_buffer(i,j))
		    Print Chr(176)
		Next
	Next
	titleCol += titleColDir
	If Not inBounds(titleCol,50,250) Then titleColDir = -titleColDir
	Color RGB(0,0,titleCol)
	PrintCenterScreen "|  |\  |  |--  |  |\  |  |  |  |  |--  |-\  /--  |--", 7
	PrintCenterScreen "|  | \ |  |-   |  | \ |  |  |  |  |-   |_/  \-\  |- ", 8
	PrintCenterScreen "|  |  \|  |    |  |  \|  |   \/   |--  | \  --/  |  ", 9
	PrintCenterScreen "|                                                |-/", 10
	PrintCenterScreen "Version " & VERSION ,11
	PrintCenterScreen "(c) Tapio Vierros 2008", rows-1, 24,24,24

	k = InKey
	If k = Chr(27) Or k = Chr(255) & "k" Then End
	Select Case As Const clientphase
		Case 0
			PrintCenterScreen("Connection established!", rows - 16, 0,120,0)
			PrintCenterScreen(traffic_in, rows - 15, 0,0,128)
			PrintCenterScreen("Ping " & Chr(247,32) & Str(pingpong), rows - 14, 0,100,80)
			PrintCenterScreen("Do you wish to [l]ogin or [r]egister?", rows - 12, 128,80,0)
			If k = "l" Or k = "L" Or k = " " Then clientphase = 1
			If k = "r" Or k = "R" Then clientphase = 2
		Case 1
			PrintCenterScreen "Enter your name", rows-12, 0,128,0
			my_name = GameInput(">", scrW/2-50, scrH-8*10,my_name,k)
			If k = Chr(13) Then clientphase = 3: my_name = UCase(Left(my_name,1)) & LCase(Mid(my_name,2))
		Case 2
			PrintCenterScreen "Enter desired name (3-8 chars, only letters a-z)", rows-12, 0,128,0
			my_name = GameInput(">", scrW/2-50, scrH-8*10,my_name,k)
			If k = Chr(13) Then
				If Len(my_name) < 3 Or Len(my_name) > 8 Or InStr(my_name, Any "0123456789,.-;:_'¨*^~§½!#¤%&/()=?+\}][{$£@€<>|") <> 0 Then tempst = "Invalid name": clientphase = 10 Else clientphase = 4
				my_name = UCase(Left(my_name,1)) & LCase(Mid(my_name,2)) 
			EndIf
		Case 3
			PrintCenterScreen "Enter password", rows-12, 0,128,0
			passwd = GameInput(">", scrW/2-50, scrH-8*10,passwd,k)
			If k = Chr(13) Then
				sock.put(1) : sock.put(Chr(actions.login) & my_name & SEP & passwd)
				clientphase = 6
			EndIf
		Case 4
			PrintCenterScreen "Enter password (4-10 chars, letters and/or numbers)", rows-12, 0,128,0
			passwd = GameInput(">", scrW/2-50, scrH-8*10,passwd,k)
			If k = Chr(13) Then
				If Len(passwd) < 4 Or Len(passwd) > 10 Then
					tempst = "Invalid password": clientphase = 10
				Else
					tempst = "": clientphase = 5
				EndIf 
			EndIf			
		Case 5
			PrintCenterScreen "Re-enter password", rows-12, 0,128,0
			tempst = GameInput(">", scrW/2-50, scrH-8*10,tempst,k)
			If k = Chr(13) Then
				If tempst <> passwd Then
					tempst = "Passwords didn't match": clientphase = 10
				Else
					sock.put(1) : sock.put(Chr(actions.register) & my_name & SEP & passwd)
					clientphase = 6
				EndIf 
			EndIf		
		Case 6
			tempst = "": traffic_in = ""
			sock.get(traffic_in)
			If traffic_in <> "" Then
				tempst = Mid(traffic_in,2)
				If (Asc(Left(traffic_in,1)) And success) = 0 Then clientphase = 10 Else clientphase = 11
			EndIf
		Case 10
			my_name = "" : passwd = ""
			PrintCenterScreen(tempst, rows - 16, 0,120,0)
			PrintCenterScreen("Do you wish to [l]ogin or [r]egister?", rows - 12, 128,80,0)
			If k = "l" Or k = "L" Or k = " " Then clientphase = 1
			If k = "r" Or k = "R" Then clientphase = 2
		Case 11
			PrintCenterScreen tempst, rows - 16, 0,128,0
			If k <> "" Then Exit Do
	End Select
	
	Sleep 5
Loop

skipthisshit:
