Function Add(a As Long, b As Long) As Long
    Add = a + b
End Function

Sub PrintTwice(x As Long)
    Print "x="; x
End Sub

Sub Main()
    Print "Add(3, 4) = "; Add(3, 4)
    ExitProcess 0
End Sub
