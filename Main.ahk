#Requires AutoHotkey v2.0

#SingleInstance Prompt
#Include "%A_LineFile%"
#Include TaskRunner/GUI_TaskRunner.ahk

F9::GuiTaskRunner().draw_gui()

#HotIf WinActive("Task Runner")
F9::Send("{Enter}")
#HotIf