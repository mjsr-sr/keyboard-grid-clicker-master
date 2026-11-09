param(
    [string]$AutoHotkey = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)

$ErrorActionPreference = 'Stop'
$source = Get-Content (Join-Path $PSScriptRoot '..\dnc_v2.ahk') -Raw
$functions = [regex]::Matches($source, '(?ms)^\w+\([^\r\n]*\)\r?\n\{.*?^\}') |
    ForEach-Object { $_.Value }
$implementation = $functions -join "`r`n"
# Keep real GUI rendering and mouse movement, but inject deterministic slow frames
# and record clicks instead of clicking any application on the user's desktop.
$implementation = $implementation -replace '(?m)^DrawGrid\(', 'RenderGrid('
$implementation = $implementation -replace '(?m)^moveMouseToCellCenter\(', 'MoveToCell('
$implementation = $implementation -replace '(?m)^ClickLeft\(', 'ProductionClickLeft('
$implementation = $implementation -replace '(?m)^ClickRight\(', 'ProductionClickRight('
$implementation = $implementation -replace '(?m)^ClickDouble\(', 'ProductionClickDouble('
$implementation = $implementation -replace '(?m)^EndGridInput\(', 'ProductionEndGridInput('

$harness = @'
#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, StdOut
#Warn LocalSameAsGlobal, Off
InstallKeybdHook
SetWinDelay -1
SetMouseDelay -1
Thread "Interrupt", 0
CoordMode "Mouse", "Screen"
depth := 0
MAX_DEPTH := 5
BackAll := []
gridGuis := []
gridSession := 0
activeMonitor := 0
activeWindow := 0
lastClick := 0
iniFile := A_ScriptFullPath ".ini"
color := "00FF00"
transparency := 70
MONITOR_LAYOUT := [MonitorGetPrimary()]
frameDelay := 0
drawCount := 0
firstFrame := 0
failFrame := false
endedSession := 0
clicks := []
sender := 0
oldWindow := WinExist("A")
MouseGetPos(&oldX, &oldY)
testGui := Gui("+AlwaysOnTop", "Grid input regression test")
testEdit := testGui.AddEdit("w360 h100")
testGui.Show("w400 h160")
WinActivate(testGui)
WinWaitActive(testGui, , 2)
testEdit.Focus()

try
{
    SetTimer DiagnoseTimeout, -8000
    PrepareGridGuis()
    handles := []
    for gridGui in gridGuis
        handles.Push(gridGui.Hwnd)

    ; A second process injects a burst while the first frame is deliberately slow.
    for target in ["window", "monitor", "selection"]
    {
        FileAppend("TEST: rapid " target " activation`n", "*")
        FocusTest()
        lastClick := 0
        drawCount := 0
        frameDelay := 100
        ArmBurst(target = "selection" ? "af" : "f", 'SendEvent "vc{Space}d{Escape}"')
        ActivateGrid(target)
        WaitForSender()
        Assert(depth = 3, "All rapid commands processed for " target)
        expected := BackAll[1]
        for key in ["f", "v", "d"]
            expected := computeNewBox(expected, key)
        Assert(SameBox(BackAll[BackAll.Length], expected),
            "Rapid navigation preserves order and undo for " target)
        Assert(testEdit.Value = "", "No text leaks during startup/redraw for " target)
        Assert(!IsObject(gridSession), "Session released after Escape for " target)
        Assert(drawCount = 6, "Every queued navigation and undo is rendered for " target)
        for index, gridGui in gridGuis
            Assert(gridGui.Hwnd = handles[index], "Grid windows reused across frames")
        FileAppend("PASS: rapid " target " activation`n", "*")
    }

    ; Non-text shortcuts must be swallowed too, not just printable letters.
    FocusTest()
    testEdit.Value := "sentinel"
    ArmBurst("{Tab}{Enter}{Backspace}{Delete}{LCtrl down}a{LCtrl up}{LAlt down}q{LAlt up}{Escape}")
    ActivateGrid("window")
    WaitForSender()
    Assert(testEdit.Value = "sentinel", "Non-text keys and modified input are suppressed")

    FocusTest()
    testEdit.Value := ""
    frameDelay := 0
    lastClick := 0
    keys := ""
    Loop 100
        keys .= "fvc"
    ArmBurst(keys "{Escape}")
    ActivateGrid("window")
    WaitForSender()
    expected := BackAll[1]
    expectedDepth := 0
    while (expectedDepth < MAX_DEPTH && expected["sectorWidth"] >= 3
        && expected["sectorHeight"] >= 3)
    {
        expected := computeNewBox(expected, "f")
        expectedDepth += 1
    }
    Assert(depth = expectedDepth, "A long burst respects depth and minimum cell size")
    Assert(endedSession["queue"].Length = 301 && endedSession["next"] = 302,
        "Every key in a 300-character burst and its Escape is processed")
    Assert(testEdit.Value = "", "Keys beyond maximum depth stay suppressed")

    FocusTest()
    frameDelay := 100
    failFrame := true
    ArmBurst("fvc")
    rejected := false
    try
        ActivateGrid("window")
    catch as err
        rejected := err.Message = "Injected redraw failure."
    WaitForSender()
    Assert(rejected && !IsObject(gridSession), "Rendering errors release the capture session")
    Assert(testEdit.Value = "", "Keys arriving before a rendering error remain suppressed")
    for gridGui in gridGuis
        Assert(!DllCall("IsWindowVisible", "ptr", gridGui.Hwnd), "Errors hide the grid")
    frameDelay := 0

    FocusTest()
    SendLevel 1
    SendEvent "{LCtrl down}"
    ArmBurst("{LCtrl up}{Escape}")
    ActivateGrid("window")
    WaitForSender()
    ctrlStuck := DllCall("GetAsyncKeyState", "int", 0xA2, "short") & 0x8000
    SendEvent "{LCtrl up}"
    Assert(!ctrlStuck, "Modifiers held before activation can be released without sticking")

    for key in ["j", "k", "l"]
    {
        FocusTest()
        testEdit.Value := ""
        lastClick := 0
        ArmBurst("fvc" key)
        ActivateGrid("window")
        WaitForSender()
        Assert(depth = 3 && clicks[clicks.Length] = key, "Rapid click dispatch: " key)
        Assert(testEdit.Value = "", "Click sequence does not leak: " key)
    }

    ; Ending a session must not expose autorepeat or the tail of a held-key burst.
    FocusTest()
    testEdit.Value := ""
    frameDelay := 0
    ArmBurst("{j down}", "SendEvent `"{j down}fvc{j up}`"")
    ActivateGrid("window")
    WaitForSender()
    Assert(clicks[clicks.Length] = "j" && testEdit.Value = "",
        "Held exit key, repeats, and trailing keys remain suppressed")

    ; Input returns to the application after the session is fully released.
    FocusTest()
    SendLevel 1
    SendEvent "z"
    Sleep 30
    Assert(testEdit.Value = "z", "Normal input restored after exit")

    FocusTest()
    frameDelay := 0
    drawCount := 0
    firstFrame := 0
    ArmBurst("{Escape}", "", 100)
    start := A_TickCount
    ActivateGrid("window")
    WaitForSender()
    FileAppend("INFO: activation to first grid frame: " (firstFrame - start) " ms`n", "*")

    box := setupInitialBoxMonitor(MonitorGetPrimary())
    elapsed := 0
    Loop 30
    {
        start := A_TickCount
        DrawGrid(box)
        elapsed += A_TickCount - start
    }
    FileAppend("INFO: mean cached redraw: " Round(elapsed / 30, 2) " ms`n", "*")
    FileAppend("PASS: real input hook, rapid activation/redraw bursts, monitor selection, "
        "ordered navigation/undo, suppression, held-key exit, clicks and GUI reuse`n", "*")
}
catch as err
{
    FileAppend("FAIL: " err.Message " (line " err.Line ")`n", "**")
    ExitApp 1
}
finally
{
    if IsObject(sender)
        WaitForSender()
    if IsObject(gridSession)
        EndGridInput(gridSession)
    CleanUpGui()
    testGui.Destroy()
    MouseMove oldX, oldY, 0
    if WinExist(oldWindow)
        WinActivate(oldWindow)
}
ExitApp 0

Assert(condition, message)
{
    if !condition
        throw Error(message)
}
DiagnoseTimeout()
{
    global gridSession, sender, testEdit, drawCount
    detail := "frames=" drawCount ", text=" testEdit.Value
    if IsObject(sender)
        detail .= ", senderStatus=" sender.Status
    if IsObject(gridSession)
    {
        detail .= ", queued=" gridSession["queue"].Length ", next=" gridSession["next"]
            . ", held=" gridSession["held"].Count ", closing=" gridSession["closing"]
        for code in gridSession["held"]
            detail .= ", heldKey=" code "/" GetKeyName(code) "/" GetKeyState(GetKeyName(code))
    }
    FileAppend("FAIL: timed out: " detail "`n", "**")
    ExitApp 1
}
SameBox(actual, expected)
{
    for key, value in expected
        if (actual[key] != value)
            return false
    return true
}
FocusTest()
{
    global testGui, testEdit
    WinActivate(testGui)
    WinWaitActive(testGui, , 2)
    testEdit.Focus()
}
moveMouseToCellCenter(box)
{
    MoveToCell(box)
}
DrawGrid(box)
{
    global frameDelay, drawCount, firstFrame, failFrame
    drawCount += 1
    if frameDelay
        Sleep frameDelay
    if failFrame
    {
        failFrame := false
        throw Error("Injected redraw failure.")
    }
    RenderGrid(box)
    if !firstFrame
        firstFrame := A_TickCount
}
EndGridInput(session)
{
    global endedSession
    ProductionEndGridInput(session)
    endedSession := session
}
ClickLeft()
{
    RecordClick("j")
}
ClickRight()
{
    RecordClick("l")
}
ClickDouble()
{
    RecordClick("k")
}
RecordClick(key)
{
    global clicks
    CleanUpGui()
    RememberClickedCell()
    clicks.Push(key)
}
ArmBurst(keys, tail := "", delay := 30)
{
    global sender, testGui
    ; Sending from another process exercises suppression while this script is busy.
    path := A_ScriptFullPath ".sender.ahk"
    script := "#Requires AutoHotkey v2.0`n#SingleInstance Off`n"
        . "SetKeyDelay -1, -1`nSendLevel 1`nSleep " delay "`n"
        . "if !WinActive(" testGui.Hwnd ")`n    ExitApp 2`n"
        . "SendEvent `"" keys "`"`n"
    if (tail != "")
        script .= "Sleep 100`n" tail "`n"
    script .= "ExitApp`n"
    if FileExist(path)
        FileDelete(path)
    FileAppend(script, path, "UTF-8")
    shell := ComObject("WScript.Shell")
    sender := shell.Exec('"' A_AhkPath '" /ErrorStdOut "' path '"')
}
WaitForSender()
{
    global sender
    if !IsObject(sender)
        return
    while (sender.Status = 0)
        Sleep 5
    result := sender.ExitCode
    output := sender.StdOut.ReadAll() sender.StdErr.ReadAll()
    sender := 0
    Assert(result = 0, "Input sender succeeded: " output)
}
'@

$tempScript = Join-Path ([System.IO.Path]::GetTempPath()) ("grid-rapid-" + [guid]::NewGuid() + ".ahk")
$process = $null
try {
    Set-Content $tempScript ($harness + "`r`n" + $implementation) -Encoding UTF8
    $process = Start-Process -FilePath $AutoHotkey -ArgumentList '/ErrorStdOut', "`"$tempScript`"" -PassThru -NoNewWindow
    $null = $process.Handle
    if (-not $process.WaitForExit(30000)) {
        Stop-Process -Id $process.Id
        throw 'Rapid input regression tests timed out'
    }
    if ($process.ExitCode -ne 0) {
        throw "Rapid input regression tests failed with exit code $($process.ExitCode)"
    }
}
finally {
    Remove-Item -LiteralPath $tempScript
    if (Test-Path -LiteralPath "$tempScript.sender.ahk") {
        Remove-Item -LiteralPath "$tempScript.sender.ahk"
    }
}
