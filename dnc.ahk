;
; AutoHotkey Version: 1.x
; Language:       English
; Platform:       Win9x/NT
; Author:         Michael Soza
; Based upon the 'Mouser' AutoHotkey script by Adam Pash <adam.pash@gmail.com>
; Based upon DNC from Petr 'Vorkronor' Stedry (petr.stedry@gmail.com)

#SingleInstance,Force 
#InstallKeybdHook
SetBatchLines -1
SetKeyDelay -1
SetWinDelay,0 

iniFile = dnc.ini
LoadConfigurationFile()
color := Ceil(color)
transparency := transparency
CoordMode, Mouse, Screen

GetMonitorMouse()
{
    MouseGetPos, x, y
	
	SysGet, MonitorCount, MonitorCount
    
	Loop, %MonitorCount%
	{
		SysGet, Monitor, Monitor, %A_Index%
	
		if(x >= MonitorLeft && x <= MonitorRight)
		{	
			return %A_Index%
		}
	}
}

SysGet, resolution, Monitor
MAX_DEPTH := calculateMaxDepth(resolutionBottom)


resetSharedState(){
	global
	depth := 0
	BackAll:=Object()
}

resetSharedState()


setupInitialBox()
{
	currentMonitor := GetMonitorMouse()
	SysGet, Monitor, Monitor, %currentMonitor%
	bD:= {}
	bD.sectorTopX := MonitorLeft
	bD.sectorTopY := 0
	bD.sectorWidth := (MonitorRight-MonitorLeft)
	bD.sectorHeight := MonitorBottom

	MouseGetPos, currentMouseX, currentMouseY
	bD.newX:= currentMouseX
	bD.newY:= currentMouseY
	return bD
}


setupInitialBoxLeft()
{
	currentMonitor := 1
	SysGet, Monitor, Monitor, %currentMonitor%
	bD:= {}
	bD.sectorTopX := MonitorLeft
	bD.sectorTopY := 0
	bD.sectorWidth := (MonitorRight-MonitorLeft)
	bD.sectorHeight := MonitorBottom

	MouseGetPos, currentMouseX, currentMouseY
	bD.newX:= currentMouseX
	bD.newY:= currentMouseY
	return bD
}


setupInitialBoxRight()
{
	currentMonitor := 2
	SysGet, Monitor, Monitor, %currentMonitor%
	bD:= {}
	bD.sectorTopX := MonitorLeft
	bD.sectorTopY := 0
	bD.sectorWidth := (MonitorRight-MonitorLeft)
	bD.sectorHeight := MonitorBottom

	MouseGetPos, currentMouseX, currentMouseY
	bD.newX:= currentMouseX
	bD.newY:= currentMouseY
	return bD
}



main(currentBox, userInput)
{
	global depth
	global MAX_DEPTH
	global BackAll

	if (depth >= MAX_DEPTH) 
	{
		CleanUpGui()
		return
	}
	
	if userInput in x,c,v,s,d,f,w,e,r
	{
		currentBox:= computeNewBox(currentBox, userInput)
		moveMouseToCellCenter(currentBox)
		DrawGrid(currentBox)

		BackAll.Insert(currentBox)			
		depth := depth + 1		
	}
	else 
	{			
		if userInput = j
			ClickLeft()

		if userInput = l  
			ClickRight()

		if userInput = k
			ClickDouble()

		if (userInput = "Escape")
			Quit()

		if (userInput = "Space")
		{
			if(depth>0)
			{
				currentBox:= GoBack(BackAll)
				depth:= depth - 1
			}
		}
	}
	return currentBox
}

moveMouseToCellCenter(currentBox)
{
	xpos:= currentBox.newX
	ypos:= currentBox.newY
	MouseMove, xpos, ypos
}

computeNewBox(currentBox, selection)
{
	newBox := currentBox.Clone()
	newBox.sectorWidth := Floor(newBox.sectorWidth/3)
	newBox.sectorHeight := Floor(newBox.sectorHeight/3)

	if selection in c,d,e
		newBox.sectorTopX := newBox.sectorTopX + newBox.sectorWidth
	if selection in v,f,r
		newBox.sectorTopX := newBox.sectorTopX + (2*newBox.sectorWidth)

	if selection in x,c,v
		newBox.sectorTopY := newBox.sectorTopY + (2*newBox.sectorHeight)
	if selection in s,d,f
		newBox.sectorTopY := newBox.sectorTopY + newBox.sectorHeight

	newBox.newX := newBox.sectorTopX + Floor(newBox.sectorWidth/2)
	newBox.newY := newBox.sectorTopY + Floor(newBox.sectorHeight/2)

	return newBox
}

calculateMaxDepth(screenSize) {
	tmpHeight := screenSize
	
	Loop {
		tmpHeight := tmpHeight / 3

		if (tmpHeight <= 3) {
			return %A_Index%
		}
	}
}

GoBack(history)
{
	history.remove(history.MaxIndex())
	BackOne := history[history.MaxIndex()]
	
	moveMouseToCellCenter(BackOne)
	DrawGrid(BackOne)
	return BackOne
}

DrawGrid(boxDefinition){
	global
	drawing := true
	bD := boxDefinition.Clone()
	drawRect(bD.sectorTopX, bD.sectorTopY, bD.sectorWidth, 1, 1)
	drawRect(bD.sectorTopX + bD.sectorWidth - 1, bD.sectorTopY, 1, bD.sectorHeight, 2)
	drawRect(bD.sectorTopX, bD.sectorTopY + bD.sectorHeight - 1, bD.sectorWidth, 1, 3)
	drawRect(bD.sectorTopX, bD.sectorTopY, 1, bD.sectorHeight, 4)

	drawRect(bD.sectorTopX, bD.sectorTopY + Floor(bD.sectorHeight/3), bD.sectorWidth, 1, 5)
	drawRect(bD.sectorTopX, bD.sectorTopY + Ceil(2 * (bD.sectorHeight/3)), bD.sectorWidth, 1, 6)
	
	drawRect(bD.sectorTopX + Floor(bD.sectorWidth/3), bD.sectorTopY, 1, bD.sectorHeight, 7)
	drawRect(bD.sectorTopX + Ceil(2 * (bD.sectorWidth/3)), bD.sectorTopY, 1, bD.sectorHeight, 8)
	drawing := false
}

drawRect(x, y, width, height, winNo) {
	Gui, %winNo%: +AlwaysOnTop -Caption +LastFound +ToolWindow
	Gui, %winNo%: Color, 666666
	WinSet, TransColor, %color% %transparency%
	Gui, %winNo%: Show, x%x% y%y% w%width% h%height% noactivate
}

PartialDestroy()
{
	global
	Gui,1: Destroy
	Gui,2: Destroy
	Gui,3: Destroy
	Gui,4: Destroy
	Gui,5: Destroy
	Gui,6: Destroy
	Gui,7: Destroy
	Gui,8: Destroy
}

CleanUpGui()
{
	global
	while drawing {
		Sleep, 500
	}
	Gui,1: Destroy
	Gui,2: Destroy
	Gui,3: Destroy
	Gui,4: Destroy
	Gui,5: Destroy
	Gui,6: Destroy
	Gui,7: Destroy
	Gui,8: Destroy
	BackAll:=Object()
}


Quit()
{
	CleanUpGui()
	Exit
	
}
	

ClickLeft()
{
	CleanUpGui()
	click
	
}

ClickRight()
{
	Click right
	CleanUpGui()
	
}

ClickDouble()
{
	Click 2
	CleanUpGui()
	
}

LoadConfigurationFile()
{
	global
	IfNotExist,%iniFile%
	{
		IniWrite,^NumpadMult,%iniFile%,Settings,hotkey
		IniWrite,FF3333,%iniFile%,Settings,color
		IniWrite,70,%iniFile%,Settings,transparency
	}
	IniRead,hotkey,%iniFile%,Settings,hotkey
	IniRead,color,%iniFile%,Settings,color
	IniRead,transparency,%iniFile%,Settings,transparency
}


PgUp::
BlockInput, On
resetSharedState()
currentBox:= setupInitialBoxLeft()
DrawGrid(currentBox)d
BackAll.Insert(currentBox)
MainLoop(currentBox)
BlockInput, Off
return


PgDn::
BlockInput, On
resetSharedState()
currentBox:= setupInitialBoxRight()
DrawGrid(currentBox)j
BackAll.Insert(currentBox)
MainLoop(currentBox)  
BlockInput, Off
return

MainLoop(currentBox){
	While, true
	{
		;BlockInput, Off
		Input, SingleKey, L1, {Escape}{Space}
		;BlockInput, On
		userInput := SingleKey
 		if (ErrorLevel = "EndKey:Space")
		{
			userInput := "Space"
		}
		if (ErrorLevel = "EndKey:Escape")
		{
			userInput := "Escape"
		}
		currentBox:= main(currentBox, userInput)
		if userInput in j,k,l,"Escape"
		{
			break
		}
	}
}
