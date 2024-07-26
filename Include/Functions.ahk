win_restore_and_move_to_main_monitor(winTitle){
    WinWait(winTitle,, 5)
    if (WinGetMinMax)
        WinRestore
    sleep(50)
    
    WinMove 100, 100, 1000, 1000
    sleep(50)
}

; Snap windows to screen
snap_window_left_wide(winTitle) {    
    win_restore_and_move_to_main_monitor(winTitle)    
    WinMove 0, 0, (A_ScreenWidth/4)*3, A_ScreenHeight, WinTitle
}


snap_window_right_narrow(winTitle) {    
    WinWait(winTitle,, 5)
    if (WinGetMinMax)
        WinRestore
    sleep(50)
    
    WinMove 100, 100, 1000, 1000 
    sleep(50)
    
    WinMove (A_ScreenWidth/4)*3-20, 0, A_ScreenWidth/4 + 28, A_ScreenHeight, WinTitle
}


; Analyse directories
get_latest_created_file(directory){
    latest := 0
    Loop Files, directory{
        time_stamp := FileGetTime(A_LoopFilePath, "C")
        if time_stamp > latest{
            latest := time_stamp
            latest_file := A_LoopFilePath
        }        
    }
    return latest_file
}


get_current_application(){
    explorerHwnd := WinActive("ahk_class CabinetWClass")
    if WinActive("ahk_exe chrome.exe"){
        Send("^l")
        CurrentApplication := get_highlighted_text()
    } else if (explorerHwnd){
        for window in ComObject("Shell.Application").Windows{
            if (window.hwnd==explorerHwnd){
                CurrentApplication := window.Document.Folder.Self.Path
            }
        }
    } else {
    windows_pid := WinGetPID("A")
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ProcessId=" . windows_pid)
        CurrentApplication := process.CommandLine
    }
    return CurrentApplication
}


; Casting and string functions
array_to_str(array){
    str := ""
    for value in array{
        str := str . value .  ", "
    }
    return "[" RTrim(str, ", ") "]"
}

single_quote_wrap(str){
    return "`'" . str . "`'"
}

double_quote_wrap(str){
    return "`"" . str . "`""
}

str_mult(str, int){
    res := ""
    Loop int
        res := res . str
    return res
}

; File Utilities
count_txt_lines(txt_path){
	Loop Read txt_path 
        total_lines := A_Index
	return total_lines
}

TextFile_Replace(file, expression, replacement){
    file_content := FileRead(file)
    new_file_content := StrReplace(file_content, expression, replacement)
    FileAppend(new_file_content, "outputfile.txt")
    FileMove("outputfile.txt", file, 1)
}

TextFile_RegExReplace(file, expression, replacement){
    file_content := FileRead(file)
    new_file_content := RegExReplace(file_content, expression, replacement)
    FileAppend(new_file_content, "outputfile.txt")
    FileMove("outputfile.txt", file, 1)
}

; Run Programs easily
run_python_script(script, parameters*){
    str := ""
    for item in parameters{
        str := str . double_quote_wrap(item) " "
    }
    run('cmd.exe /k python' " " double_quote_wrap(script) " " str)
}

; Tasks Automation (Replaced by GUI)
google(service){
    urls := map(
        "Google Search",          "https://www.google.com/search?hl=en&q=",               	; 1 Simple Search
        "Search On Google Maps",  "https://www.google.com/maps/search/",         		   	; 2 Google Maps
        "Search On Longman Dict", "https://www.ldoceonline.com/dictionary/",              	; 3 Longman Dictionary
        "Google Translator",      "https://translate.google.com/?sl=auto&tl=es&text=")      ; 4 Translation  	
    
    highlightedText := get_highlighted_text()

    if !highlightedText {
        obj := InputBox("", service, "w200 h65")
        if obj.Result = "Cancel" ; The user pressed Cancel.
            return
        highlightedText := obj.value
    }
    
	if (SubStr(highlightedText, 1 , 8) == "https://")   ; if it starts with "https://" go to, rather than search in google search
		return run(highlightedText)

    Run(urls[service] . highlightedText)
}

get_highlighted_text(){
	ClipboardOld := A_Clipboard 
    A_Clipboard  := ""

    Send("{Ctrl down}c{Ctrl up}")
    if !ClipWait(0.08)
        selected := ""
    else
        selected := A_Clipboard

    A_Clipboard := ClipboardOld
	return selected
}

copy_file_path(){
    A_clipboard :=  get_highlighted_text()
}

search_click_image(image_path, ImageSearch_options:="*100", X1:=0, Y1:=0, X2:=1920, Y2:=1080, clickButton:="Left"){
    MouseGetPos(&OriginalXpos, &OriginalYpos)
    ImageSearch(&FoundX, &FoundY, X1, Y1, X2, Y2, ImageSearch_options . " " . image_path)
    try{
        MouseClick(clickButton, FoundX, FoundY, Clickcount:=1, Speed:=0)
        MouseMove(OriginalXpos, OriginalYpos, Speed:=0)
        return True
    } 
    Return False
}

; time code // Credits to CodeKnight: https://www.autohotkey.com/boards/viewtopic.php?t=45263
Global StartTimer := ""
CodeTimer()
{

	Global StartTimer
	
	If (StartTimer != "")
	{
		FinishTimer := A_TickCount
		TimedDuration := FinishTimer - StartTimer
		StartTimer := ""
		MsgBox(TimedDuration . "ms have elapsed!")
		Return TimedDuration
	}
	Else
		StartTimer := A_TickCount
}

; Boolean questions
MouseIsOver(WinTitle) {
    MouseGetPos( ,,&Win)  						 	; Detect Window mouse is over
    return WinExist(WinTitle " ahk_id " Win) 	; Return Window title that Mouse is overj    
}