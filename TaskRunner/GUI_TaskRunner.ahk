; ======================================================================================================================
; Program Name:     TaskRunner
; Author:           CarlosPeredaMieses
; Tested with:      AHK 2.0.11 (x64)
; Tested on:        Win 10 Home (x64)
; Suggested Hotkey: The most accessible button you have / F8 / F9 / Four Taps on mousepad / special mouse button if any
; Notes:            The user should not write to the DB directly.
; License:          Feel free to modify this software and in case of publishing mention the author.
; ======================================================================================================================
; This software is provided 'as-is', without any express or implied warranty.
; In no event will the authors be held liable for any damages arising from the use of this software.
; ======================================================================================================================

#Include "%A_LineFile%"
#Include Include/Functions.ahk

BUTTONS := map(
    "delete", "Static1",
    "edit", "Static2",
    "add", "Static3",
    "refresh", "Button2",  
    "question_mark_icon", "Static5",
    "cancel", "Button1",
    "save_close", "Button2",
    "save_continue", "Button3",
    "edit_in_default_editor", "Button4"
)

Class GuiTaskRunner extends Gui{
    __New(){
        super.__New("AlwaysOnTop", "Task Runner")
        this.cd := RegExReplace(A_LineFile, "[^\\]*$", "")
        this.DB := this.cd . "DB.txt"
        this.task_map := map()
    }


    draw_gui(){
        this.create_controls()
        this.set_events()
        this.show()
    }


    create_controls(){
        this.SetFont("s11")

        this.search_control := this.Add("Edit", "-vscroll w340 h22")

        this.delete_task_button     := this.Add("Picture", "ys h20 w20", this.cd . "images\delete_task_button.png")
        this.edit_task_button       := this.Add("Picture", "ys h20 w20", this.cd . "images\edit_task_button.png")
        this.add_task_button        := this.Add("Picture", "ys h20 w20", this.cd . "images\add_task_button.png")
        this.execute_task_button    := this.Add("Button", "x-0 y-0 hidden default", "[Hidden] OK")
        this.refresh_button         := this.Add("Button", "x-0 y-0 hidden", "[Hidden] refresh to add missing identifiers")

        this.listview_control := this.Add("ListView", "xs r10 w440 Background2a2a2a cffffff -E0x200 -hdr +AltSubmit -Multi", ["original_name", "OriginalKeyboards", "OriginalPriority"])
        this.listview_control.modifyCol(1, 420)   ; Hide second and subsequent columns
        this.listview_control.modifyCol(2, 0)     ; Hide horizontal slide bar
        this.listview_control.modifyCol(3, 0)     ; Hide horizontal slide bar
    }


    set_events(){
        this.search_control.OnEvent("Change", this.fill_listview.bind(this))
        this.delete_task_button.OnEvent("Click", this.click_delete_task_button.bind(this))
        this.edit_task_button.OnEvent("Click", this.click_edit_task_button.bind(this))
        this.add_task_button.OnEvent("Click", this.click_add_task_button.bind(this))
        this.execute_task_button.OnEvent("Click", this.click_execute_task_button.bind(this))
        this.refresh_button.OnEvent("Click", this.click_refresh_button.bind(this))
        this.listview_control.OnEvent("DoubleClick", this.click_execute_task_button.bind(this))
    }


    fill_listview(*){
        this.show()

        this.listview_control.Delete()

        if !this.search_control.value
            return

        DB_content := FileRead(this.DB)
        
        Loop Parse, DB_content, "`n", "`r" {
            RegExMatch(A_LoopField, "(.*),(.*),(.*)", &parsed_task)
        
            task_name := parsed_task[1]
            task_keywords := parsed_task[2]
            task_priority := parsed_task[3]
            search_query := this.search_control.value

            search_query := RegExReplace(search_query, "\\", "") ; Avoid a bug when user writes backslash symbol (\)
            search_query_array := StrSplit(search_query, " ")

            task_found := True
            for word in search_query_array{
                word := "i)\s" . word

                if !RegExMatch(" " . task_keywords, word){
                    task_found := False
                    Break
                }
            }

            if task_found
                this.listview_control.Add(, task_name, task_keywords, task_priority)
        }

        this.listview_control.modify(1, "Vis Focus Select")
    }


    click_delete_task_button(*){
        this.task_map := this.get_focused_row_data()

        if MsgBox("The Entry `"" . this.task_map["original_name"] . "`" will be erased.`n" .
                         "Press OK to continue",,
                         "4096 48 1") == "Cancel"
            return

        Loop Read this.DB, "OutputFile.txt" {
            RegExMatch(A_LoopReadLine, "^([^,]*)", &listview_name)
            If (listview_name[1] != this.task_map["original_name"]) {
                FileAppend(A_LoopReadLine . "`n")
            }
        }
        FileAppend("", "OutputFile.txt") ; This line ensures the file OutputFile exists

        FileMove("OutputFile.txt", this.DB, 1)
        FileDelete(this.task_map["unique_identifier_path"])

        this.delete_empty_rows_from_db()
        

        task_selected := this.listview_control.GetNext(0, "Focused") ; stores the row number of the focused item
        this.fill_listview()
        if task_selected <= 1
            task_selected := 2
        
        this.listview_control.modify(task_selected-1, "Vis Focus Select")

    }


    click_edit_task_button(*){
        new_entry := 0
        this.task_map := this.get_focused_row_data()
        this.opt("Disabled")
        GuiEditTask(this.HWND,
            new_entry,
            this.task_map["original_name"],
            this.task_map["original_content"],
            this.task_map["original_keywords"],
            this.task_map["original_priority"]
        ).draw_gui()
    }


    click_add_task_button(*){
        WinMinimize("A")

        original_name := ""
        original_content := "run(" get_current_application() ")"
        original_keywords := ""
        original_priority := "0"
        new_entry := 1

        this.show()
        this.opt("Disabled")
        GuiEditTaskInstance := GuiEditTask(
            this.HWND,
            new_entry,
            original_name,
            original_content,
            original_keywords,
            original_priority
        ).draw_gui()

        
        get_current_application(){
            sleep(10)
            explorerHwnd := WinActive("ahk_class CabinetWClass")
            if WinActive("ahk_exe chrome.exe") || WinActive("ahk_exe msedge.exe") || 
                WinActive("ahk_exe firefox.exe") || WinActive("ahk_exe opera.exe"){
                Send("^l")
                CurrentApplication := get_highlighted_text()

            ; Thanks to AlexV for the next part of the code
            ; https://www.autohotkey.com/boards/viewtopic.php?t=69925
            } else if (explorerHwnd){
                for window in ComObject("Shell.Application").Windows{
                    if (window.hwnd==explorerHwnd){
                        CurrentApplication := window.Document.Folder.Self.Path
                    }
                }
            } else {

            ; Thanks to flyingDman for the next part of the code
            ; https://www.autohotkey.com/boards/viewtopic.php?p=494583
            windows_pid := WinGetPID("A")
            for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ProcessId=" . windows_pid)
                CurrentApplication := process.CommandLine
            }


            CurrentApplication := RegExReplace(CurrentApplication, "`"", "")
            CurrentApplication := RegExReplace(CurrentApplication, "(?=\w:\\)", "`"")
            CurrentApplication := RegExReplace(CurrentApplication, "(\.\w+)(\s|$)", "$1`"$2")
            CurrentApplication := "`'" . CurrentApplication . "`'"

            return CurrentApplication
        }
    }


    click_execute_task_button(*){
        if !this.search_control.value{
            this.destroy()
            exit
        }

        this.task_map := this.get_focused_row_data()
        run(this.task_map["unique_identifier_path"])
        this.destroy()
    }


    get_focused_row_data(*){
        task_selected := this.listview_control.GetNext(0, "Focused") ; stores the row number of the focused item

        if !task_selected {
            MsgBox("You haven't selected an task", "Task Runner Error", 4112)
            exit
        }

        original_name           := this.listview_control.GetText(task_selected, 1) ; Retrieves the text at the task_selected row and column 1
        original_keywords       := this.listview_control.GetText(task_selected, 2) ; Retrieves the text at the task_selected row and column 2
        original_priority       := this.listview_control.GetText(task_selected, 3) ; Retrieves the text at the task_selected row and column 3
        unique_identifier       := RegExReplace(original_name, "[^a-zA-Z\d]", "") ; all non alphanumeric characters are deleted to get the unique_identifier
        unique_identifier_path  := this.cd . "Unique Identifiers\" . unique_identifier . ".ahk"
        original_content        := FileRead(unique_identifier_path)

        return map(
            "original_name", original_name,
            "original_content", original_content,
            "original_keywords", original_keywords,
            "original_priority", original_priority,
            "unique_identifier_path", unique_identifier_path
            )
    }


    click_refresh_button(*){
        this.add_missing_identifiers_to_DB()
        this.sort_DB_priority_alphabetically()

        this.remove_missing_tasks_from_DB()

        this.delete_empty_rows_from_db()        
        this.fill_listview()
    }


    add_missing_identifiers_to_DB(){
        DB_content := FileRead(this.DB)
        DB_content := RegExReplace(DB_content, "[^a-zA-Z\d,\n]", "")  ; Delete all non alpha numeric characters from DB

        tasks_extension := ""
        Loop Files, this.cd . "Unique Identifiers\*.ahk"{

            unique_identifier := RegExReplace(A_LoopFileName, ".ahk", "")
            if !RegExMatch(DB_content, unique_identifier . ","){
                new_task := unique_identifier . "," . unique_identifier . "," . "0"
                new_task := RegExReplace(new_task, "([a-z])([A-Z])", "$1 $2")
                new_task := RegExReplace(new_task, "(?<!^)(?<!\s)(?<!,)([A-Z])([a-z])", " $1$2")
                tasks_extension := tasks_extension . new_task . "`n"
            }
        }

        FileAppend("`n" . tasks_extension, this.DB)
    }


    sort_DB_priority_alphabetically(){
        DB_content := FileRead(this.DB)
        DB_content := Sort(DB_content)
        FileDelete this.DB
        FileAppend Sort(DB_content,, priority_sort), this.DB
        DB_content := "" ; Free the memory.

        priority_sort(a, b, *){
            if (a=="")
                return 1
            if (b=="")
                return -1

            RegExMatch(a, "([^,]*)$", &taskA_priority)
            RegExMatch(b, "([^,]*)$", &taskB_priority)
            return Number(taskA_priority[1]) < Number(taskB_priority[1]) ? 1 :
                   Number(taskA_priority[1]) > Number(taskB_priority[1]) ? -1 : 0
        }
    }


    remove_missing_tasks_from_DB(){
        all_unique_identifiers := ""
        Loop Files, this.cd . "Unique Identifiers\*.ahk"{
            new_identifier := RegExReplace(A_LoopFileName, ".ahk", "")
            all_unique_identifiers := all_unique_identifiers . new_identifier . "`n"
        }

        Loop Read this.DB, "OutputFile.txt" {
            RegExMatch(A_LoopReadLine, "^([^,]*)", &listview_name)
            unique_identifier := RegExReplace(listview_name[], "[^a-zA-Z\d]", "")
            If (inStr(all_unique_identifiers, unique_identifier, False)) {
                FileAppend(A_LoopReadLine . "`n")
            }
        }

        FileMove("OutputFile.txt", this.DB, 1)
    }


    delete_empty_rows_from_db(){
        TextFile_RegExReplace(this.DB, "\n(?=\n)", "")
        TextFile_RegExReplace(this.DB, "^\n", "")
        TextFile_RegExReplace(this.DB, "\n$", "")
    }
    

    binary_search(target_name, target_priority){
        DB_content := FileRead(this.DB)
        DB_content := StrLower(DB_content)
        str_array := StrSplit(DB_content, "`n")
        
        min_index := 1
        max_index := str_array.Length
        middle := (max_index+min_index)//2
        target_name := StrLower(target_name)

        while min_index <= max_index{
            RegExMatch(str_array[middle], "(^[^,]*)", &middle_name)
            RegExMatch(str_array[middle], "([^,]*)$", &middle_priority)
            
            if target_name == middle_name[]{
                return middle
            } else {
                if target_priority == Number(middle_priority[]){                
                    lower := is_str1_lower_than_str2(target_name, middle_name[]) ; Ord(target_name) < Ord(middle_name[]) ; FIX
                } else {
                    lower := target_priority > Number(middle_priority[])
                }
                if lower{
                    max_index := middle - 1
                } else {
                    min_index := middle + 1
                }
                middle := (min_index + max_index) // 2
            }
        }

        is_str1_lower_than_str2(str1, str2){
            if StrLen(str1) == 0{
                return False
            }
            if StrLen(str2) == 0{
                return True
            }

            if (Ord(str1) < Ord(str2)) {
                return True
            }else if (Ord(str1) > Ord(str2)){
                return False
            }else{
                return is_str1_lower_than_str2(SubStr(str1, 2), SubStr(str2, 2))
            }
        }
    }
}


Class GuiEditTask extends Gui{
    __New(OwnerHWND, new_entry, original_name, original_content, original_keywords, original_priority){
        super.__New("-minimizeBox alwaysOnTop +owner" . OwnerHWND, "Edit Task")
        this.cd := RegExReplace(A_LineFile, "[^\\]*$", "")
        this.gui_owner := GuiFromHwnd(OwnerHWND)
        this.gui_owner_HWND := OwnerHWND
        this.new_entry := new_entry
        this.original_name := original_name
        this.original_content := original_content
        this.original_keywords := original_keywords
        this.original_priority := original_priority
    }


    draw_gui(){
        this.create_controls()
        this.create_events()
        this.Show()
    }


    create_controls(){
        this.add("Text",, "Task Name:")
        this.add("Edit", "xm vEditedName r1 w300 -VScroll", this.original_name)

        this.add("Text",, "Content / Action:")
        this.SetFont("s12")
        this.add("Edit", "vEditedContent r18 w750 VScroll +HScroll -wrap", this.original_content)
        this.SetFont("s9")

        this.add("Text", "Section", "Keywords:")
        this.add("Edit", "vEditedKeywords r1 w660 -VScroll -Multi lowercase", this.original_keywords)

        this.add("Text", "ys", "Priority:")
        this.add("Edit", "r1 w80 -VScroll -Multi lowercase")
        this.add("UpDown", "vEditPriority Range-10000-10000",  this.original_priority)

        this.cancel_button          := this.add("Button", "w80 x300", "Cancel")
        this.save_close_button      := this.add("Button", "yp w80", "Save")
        this.save_continue_button   := this.add("Button", "w1 hidden x-0 y-0", "HiddenSave")
        this.edit_in_editor_button  := this.add("Button", "w1 hidden x-0 y-0", "Save and Edit")
        this.question_mark_icon     := this.Add("Picture", "ym+5 xm+735 h11 w11 Icon95", "C:\WINDOWS\system32\imageres.dll")
    }


    create_events(){
        this.save_close_button.OnEvent("Click",      this.click_save_button.bind(this, save_and_exit:=1))
        this.save_continue_button.onEvent("Click",   this.click_save_button.bind(this, save_and_exit:=0))
        this.edit_in_editor_button.onEvent("Click",  this.click_edit_in_editor_button.bind(this))
        this.cancel_button.OnEvent("Click",          this.gui_close.bind(this))
        this.OnEvent("Close", this.gui_close)
        OnMessage(0x200, this.show_question_mark_tooltip)
    }


    click_save_button(save_and_exit, *){
        Saved := this.submit(1)

        if this.assert_saving_task(Saved){
            this.original_content := Saved.EditedContent
            this.original_keywords := Saved.EditedKeywords
            this.original_priority := Saved.EditPriority
            this.gui_close()
            return GuiEditTask(this.gui_owner_HWND,
                this.new_entry,
                "",
                Saved.EditedContent,
                Saved.EditedKeywords,
                Saved.EditPriority
            ).draw_gui()
        }

        this.save_item_data(Saved)

        this.gui_owner.sort_DB_priority_alphabetically()
        this.gui_owner.search_control.value := " "
        this.gui_owner.delete_empty_rows_from_db()
        this.gui_owner.fill_listview()
        
        row_index := this.gui_owner.binary_search(Saved.EditedName, Saved.EditPriority)
        this.gui_owner.listview_control.modify(row_index, "Vis Focus Select")

        new_entry := 0

        if save_and_exit{
            this.gui_close()
            return
        } 
        
        GuiEditTask(this.gui_owner_HWND,
            new_entry,
            Saved.EditedName,
            Saved.EditedContent,
            Saved.EditedKeywords,
            Saved.EditPriority
        ).draw_gui()
    }


    click_edit_in_editor_button(*){
        this.click_save_button(1)
        Run "edit " this.gui_owner.task_map["unique_identifier_path"]
        this.gui_owner.destroy()
    }


    save_item_data(gui_saved){
        new_task_string := gui_saved.EditedName . "," . gui_saved.EditedKeywords . "," . gui_saved.EditPriority
        if (this.new_entry){
            FileAppend("`n" new_task_string, this.gui_owner.DB) ; Add entry to DB
        } else {
            old_task_str := this.original_name "," this.original_keywords "," . this.original_priority
            old_task_str := RegExReplace(old_task_str, "(\[|\]|\(|\)|\{|\})", "\$1")
            old_task_str := "m)^\b" . old_task_str . "*\b,*$" ; Capture the complete item only if it matches a complete line
            TextFile_RegExReplace(this.gui_owner.DB, old_task_str, new_task_string)

            old_unique_identifier := RegExReplace(this.original_name, "[^a-zA-Z\d]", "")
            old_unique_identifier_path := this.cd . "Unique Identifiers\" old_unique_identifier ".ahk"
            FileDelete(old_unique_identifier_path)
        }

        unique_identifier := RegExReplace(gui_saved.EditedName , "[^a-zA-Z\d]", "")
        unique_identifier_path := this.cd . "Unique Identifiers\" unique_identifier ".ahk"
        FileAppend gui_saved.EditedContent, unique_identifier_path ; Creates a new ahk file with new Action and name.
    }


    show_question_mark_tooltip(*){
        MouseGetPos(,,, &OutputVarControl)
        If (OutputVarControl == BUTTONS["question_mark_icon"])
            ToolTip("Task Name:`nThe name of the task which appears in the listview and is used to get its respective ahk file.`n`n" .
                    "Content / Action:`nCode that is executed when a task is selected.`n`n" .
                    "Keywords:`nWords by which you can search the task in the listview`n`n" .
                    "Priority:`nA number which dictates the position of the task within the listview. Greater priority puts the task on top", 550, 50)
        else
            ToolTip("")
    }


    assert_saving_task(gui_saved){
        Newunique_identifier := RegExReplace(gui_saved.EditedName, "[^a-zA-Z\d]", "")
        if Newunique_identifier == ""{
            return MsgBox("The unique_identifier name cannot be empty","Error Saving Item", 4112)
        }

        original_name := RegExReplace(this.original_name, "[^a-zA-Z\d]", "") ; all non alphanumeric characters are deleted to get the unique_identifier
        DB_content := FileRead(this.gui_owner.DB)
        DB_content := RegExReplace(DB_content, "[^a-zA-Z\d,\n]", "")
        if (RegExMatch(DB_content, "mi)^" . Newunique_identifier . "," ) and original_name != Newunique_identifier)
            return MsgBox("The new configuration couldn't save because unique_identifier ('" Newunique_identifier "') " .
                          "already exist.`n`nChoose another name or change existing item name instead.",
                          "Error Saving Item", 4112)
    }


    gui_close(*){
        this.gui_owner.opt("-Disabled")
        this.destroy
    }
}


#HotIf WinActive("Task Runner",, "Edit")
F8::Send("{Enter}")
Esc::WinClose("A")

Up::{
    new_task_gui := GuiFromHwnd(WinExist("Task Runner"))
    PreviousPos  := new_task_gui.listview_control.GetNext()
    ChoicePos:=PreviousPos-1

    if (ChoicePos > 0)
        return ControlSend("{Up}", "SysListview321", "Task Runner")
    ControlSend("{End}", "SysListview321", "Task Runner")
}

Down::{
    new_task_gui := GuiFromHwnd(WinExist("Task Runner"))
    PreviousPos  := new_task_gui.listview_control.GetNext()
    ItemsInList  := new_task_gui.listview_control.GetCount()
    ChoicePos:=PreviousPos+1
    if (ChoicePos <= ItemsInList)
        return ControlSend("{Down}", "SysListview321", "Task Runner")

    ControlSend("{Home}", "SysListview321", "Task Runner")
}
^e::ControlClick(BUTTONS["edit"], "Task Runner",,"Left",1)
Delete::ControlClick(BUTTONS["delete"], "Task Runner",,"Left",1)
^n::ControlClick(BUTTONS["add"], "Task Runner",,"Left",1)
F5::ControlClick(BUTTONS["refresh"], "Task Runner",,"Left",1)
^o::{
    new_task_gui := GuiFromHwnd(WinExist("Task Runner"))
    Run new_task_gui.cd . "\Unique Identifiers"
    if WinExist("DB.txt")
        WinClose
    Run(new_task_gui.DB)
}


#HotIf WinActive("Edit Task")
^Enter::ControlClick(BUTTONS["save_close"], "Edit Task",,"Left",1)
^s::ControlClick(BUTTONS["save_continue"], "Edit Task",,"Left",1)
^o::ControlClick(BUTTONS["edit_in_default_editor"], "Edit Task",,"Left",1)
Esc::WinClose("A")
#HotIf

^5::{
    if WinExist("Task Runner"){
       return 
    }
    GuiTaskRunner().draw_gui()
    ControlClick(BUTTONS["add"], "Task Runner",,"Left",1)
}