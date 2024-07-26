#Requires AutoHotkey v2.0

#SingleInstance Prompt
#Include "%A_LineFile%"
#Include Lib/GUI_TaskRunner.ahk

F9::GuiTaskRunner().draw_gui()