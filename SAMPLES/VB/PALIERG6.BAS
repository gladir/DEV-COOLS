Function Fact(n As Long) As Long
    If n <= 1 Then
        Fact = 1
    Else
        Fact = n * Fact(n - 1)
    End If
End Function

Sub PrintTwice(x As Long)
    Print "x="; x
End Sub

Sub Main()
    Print "F10="; Fact(10)
    PrintTwice 21
    ExitProcess 0
End Sub
