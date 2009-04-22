
Declare Function GetWord(st As String, index As Integer, sep_ As String = " ") As String
Declare Function CountWords(st As String, sep_ As String = " ") As Integer

Const DB_areas = "db_areas.dat"
Const DB_players = "db_players.dat"


Type ActiveAreaFwd As ActiveArea

Type CLIENT_NODE
	name As String = ""
	cnx  As Socket Ptr = 0
	thread As Any Ptr = 0
	flags As UByte
	x As Integer
	y As Integer
	vLvl As Byte = zStarmap '''''''''''''''''0
	actArea As ActiveAreaFwd Ptr = 0
	nextInArea As CLIENT_NODE Ptr = 0
	prevInArea As CLIENT_NODE Ptr = 0
	nextPl As CLIENT_NODE Ptr = 0
	prevPl As CLIENT_NODE Ptr = 0
End Type
Dim Shared As CLIENT_NODE Ptr firstCli = 0, lastCli = 0
Dim Shared As Integer clients = 0, regCount = 0
Dim Shared As ULongInt runningID = 1 

Type Modification
	x As Integer = -1
	y As Integer = -1
	bID As Integer = 0
	modType As UByte
	anydata As Any Ptr
	nextModification As Modification Ptr = 0
End Type

Type ActiveArea
	id                As String
	plcount           As Integer
	firstPlayer       As CLIENT_NODE Ptr = 0
	firstModification As Modification Ptr = 0
	nextArea          As ActiveArea Ptr = 0
End Type
Dim Shared As ActiveArea Ptr firstAreas(zStarmap To zDetail)

Type StoredArea
	id As String
	firstModification As Modification Ptr = 0
	nextStoredArea    As StoredArea Ptr = 0
End Type 
Dim Shared firstStoredArea As StoredArea Ptr = 0

Type Factory
	fType As UByte
	startTime As UInteger
End Type

Dim Shared As Double StartTimer
Dim Shared As String StartTime

Dim Shared lock_players As Any Ptr : lock_players = MutexCreate()
Dim Shared lock_area    As Any Ptr : lock_area    = MutexCreate()
Dim Shared lock_mod     As Any Ptr : lock_mod     = MutexCreate()
Dim Shared lock_output  As Any Ptr : lock_output  = MutexCreate()

Dim Shared As Byte serverShutdown = 0

Function GetStoredArea(id As String) As StoredArea Ptr
	MutexLock(lock_area)
	Dim iArea As StoredArea Ptr = firstStoredArea
	Do While iArea <> 0
		If iArea->id = id Then MutexUnLock(lock_area): Return iArea
		iArea = iArea->nextStoredArea
	Loop
	Var newstorage = New StoredArea
	newstorage->id = id
	newstorage->nextStoredArea = firstStoredArea
	firstStoredArea = newstorage
	MutexUnLock(lock_area)
	Return newstorage 
End Function


Sub AttachModifications(area As ActiveArea Ptr)
	MutexLock(lock_area)
	Dim iArea As StoredArea Ptr = firstStoredArea
	Do While iArea <> 0
		If iArea->id = area->id Then area->firstModification = iArea->firstModification: MutexUnLock(lock_area): Exit Sub
		iArea = iArea->nextStoredArea
	Loop
	MutexUnLock(lock_area)
End Sub


Function GetActiveAreaPtr(areaKey As String, vLvl As Byte) As ActiveArea Ptr
	MutexLock(lock_area)
	Dim iArea As ActiveArea Ptr = firstAreas(vLvl)
	Do While iArea <> 0
		If iArea->id = areaKey Then MutexUnLock(lock_area): Return iArea
		iArea = iArea->nextArea
	Loop
	iArea = New ActiveArea
	iArea->id = areaKey
	If vLvl = zDetail Then MutexUnLock(lock_area): AttachModifications(iArea): MutexLock(lock_area)
	iArea->nextArea = firstAreas(vLvl)
	firstAreas(vLvl) = iArea
	MutexUnLock(lock_area)
	Return iArea
End Function


Sub SendToAllInArea(area As ActiveArea Ptr, msg As String, exclude As String = "")
	If area = 0 OrElse msg = "" Then Exit Sub
	MutexLock(lock_players)
	Dim plNode As CLIENT_NODE Ptr = area->firstPlayer
	Do While plNode <> 0
		If plNode->name <> exclude Then plNode->cnx->put( msg )
		plNode = plNode->nextInArea
	Loop
	MutexUnLock(lock_players)
End Sub

' Composes a string containing all player positions in the area
Function GetAreaPlayers(area As ActiveArea Ptr, exclude As String = "") As String
	If area = 0 Then Return "0" 
	Dim ret As String = ""
	Dim As Integer count = 0
	MutexLock(lock_players)
	Dim plNode As CLIENT_NODE Ptr = area->firstPlayer
	Do While plNode <> 0
		If plNode->name <> exclude Then ret += SEP & plNode->Name & SEP & Str(plNode->x) & SEP & Str(plNode->y): count+=1 
		plNode = plNode->nextInArea
	Loop
	MutexUnLock(lock_players)
	Return Str(count) & ret
End Function

' Composes a string containing all modifications in the area
Function GetAreaChanges(area As ActiveArea Ptr) As String
	If area = 0 OrElse area->firstModification = 0 Then Return "0" 
	Dim ret As String = ""
	Dim As Integer count = 0
	MutexLock(lock_mod)
	Dim iMod As Modification Ptr = area->firstModification
	Do While iMod <> 0
		ret += Chr(iMod->x+detCoordOffSet, iMod->y+detCoordOffSet, iMod->bID)
		count += 1
		iMod = iMod->nextModification
	Loop
	MutexUnLock(lock_mod)
	If count = 0 Then Return "0"
	Return Str(count) & SEP & ret
End Function

Sub LoadModifications()
	Dim As String row = ""
	Dim newmod As Modification Ptr
	Dim storage As StoredArea Ptr
	Var f = FreeFile
	Open DB_areas For Input As #f
		Do Until Eof(f)
			Line Input #f, row
			newmod = New Modification
			newmod->x = Asc(Mid(row,1,1)) - detCoordOffSet
			newmod->y = Asc(Mid(row,2,1)) - detCoordOffSet
			newmod->bID = Asc(Mid(row,3,1))
			storage = GetStoredArea(Mid(row,4))
			newmod->nextModification = storage->firstModification	'new's next is storage's first
			storage->firstModification = newmod						'new becomes strage's first
		Loop
	Close #f
End Sub


Sub DoModification(area As ActiveArea Ptr, m As Modification)
	Var newmod = New Modification
	newmod->x = m.x : newmod->y = m.y
	newmod->bID = m.bID
	Var storage = GetStoredArea(area->id)					'get storage
	MutexLock(lock_mod)
	newmod->nextModification = storage->firstModification	'new's next is storage's first
	storage->firstModification = newmod						'new becomes strage's first
	area->firstModification = newmod						'update area's first
	Var f = FreeFile
	Open DB_areas For Append As #f
		Print #f, (Chr(m.x+detCoordOffSet,m.y+detCoordOffSet,m.bID) & area->id) 
	Close #f
	MutexUnLock(lock_mod)
End Sub

Sub EraseModification(area As ActiveArea Ptr, x As Integer, y As Integer)
	MutexLock(lock_mod)
	Dim iMod As Modification Ptr = area->firstModification
	Dim prevMod As Modification Ptr = 0
	Do While iMod <> 0
		If iMod->x = x And iMod->y = y Then
			If prevMod <> 0 Then prevMod->nextModification = iMod->nextModification Else area->firstModification = iMod->nextModification
			Delete(iMod)
			MutexUnLock(lock_mod)
			Exit Sub
		EndIf
		prevMod = iMod
		iMod = iMod->nextModification
	Loop
	MutexUnLock(lock_mod)
End Sub



Sub AddToArea(pl As CLIENT_NODE Ptr, area As ActiveArea Ptr)
	If area = 0 OrElse pl = 0 Then Exit Sub
	MutexLock(lock_area)
	pl->nextInArea = area->firstPlayer
	area->firstPlayer = pl
	pl->actArea = area
	area->plcount += 1
	MutexUnLock(lock_area)
End Sub

Sub RemoveFromArea(pl As CLIENT_NODE Ptr, area As ActiveArea Ptr)
	If area = 0 OrElse pl = 0 Then Exit Sub
	MutexLock(lock_area)
	If pl = area->firstPlayer Then area->firstPlayer = pl->nextPl
	area->plcount -= 1
	MutexUnLock(lock_area)
	MutexLock(lock_players)
	If pl->nextInArea <> 0 Then pl->nextInArea->prevInArea = pl->prevInArea
	If pl->prevInArea <> 0 Then pl->prevInArea->nextInArea = pl->nextInArea
	pl->actArea    = 0
	pl->nextInArea = 0
	pl->prevInArea = 0
	MutexUnLock(lock_players)
End Sub


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


Function LoadPlayer(nick As String, pw As String, pl As CLIENT_NODE Ptr) As Byte
	Function = 0
	Dim row As String 
	Var f = FreeFile
	Open DB_players For Input As #f
		While Not Eof(f)
			Line Input #f, row
			If nick = GetWord(row,1,"#") Then
				If pw = GetWord(row,2,"#") Then
					'load stuff
					pl->name = nick
					If pl->name = "Aave" Then pl->flags = cflags.admin
					Function = 1
					Exit While
				EndIf
				Function = -1
				Exit While
			EndIf
		Wend
	Close #f
End Function

Function CountRegPlayers() As Integer
	Dim row As String
	Dim count As Integer
	Var f = FreeFile
	Open DB_players For Input As #f
		While Not Eof(f)
			Line Input #f, row
			count+=1
		Wend
	Close #f
	Return count
End Function



Sub SavePlayer(nick As String, pw As String)
	Var f = FreeFile
	Open DB_players For Append As #f
		Print #f, Str(nick & "#" & pw & "#1" )
	Close #f
End Sub

Dim Shared As UInteger ticks = 0
Function GetGameTicks() As UInteger
	Return ticks
End Function


' String Functions ''

Function CountWords(st As String, sep_ As String = " ") As Integer
    Dim As Integer count = 0, nextIndex = 0
    st = Trim(st, sep_)
    If Len(st) = 0 Then Return 0
    nextIndex = InStr(st, sep_)
	Do While nextIndex > 0 'if not found loop will be skipped
		count+=1
	    nextIndex = InStr(nextIndex + Len(sep_), st, sep_)
	Loop
    Return count+1
End Function


Function GetWord(st As String, index As Integer, sep_ As String = " ") As String
    Dim As Integer count = 1, nextIndex = 0, wordStart = -1
    st = Trim(st, sep_)
    If Len(st) = 0 Or index <= 0 Or index > CountWords(st,sep_) Then Return ""
    st += sep_
    Do
        If count = index Then wordStart = nextIndex + Len(sep_)
        nextIndex = InStr(nextIndex + Len(sep_), st, sep_)
        count+=1
    Loop Until wordStart <> -1
    Dim As String ret = Mid(st, wordStart, nextIndex-wordStart)
    Return ret
End Function
