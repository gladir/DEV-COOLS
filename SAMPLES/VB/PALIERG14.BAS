Function F(n As Long) As Long
    F = n
End Function

Sub S(x As Long)
    Print "x="; x
End Sub

Sub Main()
    Print "1="; F(1)
    Print "2="; F(2)
    Print "3="; F(3)
    ExitProcess 0
End Sub
