Sub Main()
    Dim i As Long
    i = 1
    GoTo Skip
    i = 99
Skip:
    Print "i = "
    Print i
    GoTo Done
    Print "fail"
Done:
    Print "done"
End Sub
