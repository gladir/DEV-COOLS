Sub TestResumeNext()
    Dim a As Long
    Dim b As Long
    Dim r As Long
    a = 100
    b = 0
    On Error Resume Next
    Print "before"
    r = a \ b
    Print "after divzero"
    Print Err.Number
    Err.Clear
    Print Err.Number
End Sub

Sub TestGotoResume()
    Dim a As Long
    Dim b As Long
    Dim r As Long
    a = 50
    b = 0
    On Error GoTo H
    Print "before2"
    r = a \ b
    Print "this should not print"
    Print "after handler returns"
    Exit Sub
H:
    Print "in handler"
    Print Err.Number
    Resume Next
End Sub

Sub Main()
    TestResumeNext
    Print "---"
    TestGotoResume
    Print "done"
End Sub
