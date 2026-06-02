Function Fact(n As Long) As Long
    If n <= 1 Then
        Fact = 1
    Else
        Fact = n * Fact(n - 1)
    End If
End Function

Sub Main()
    Print "F8="; Fact(8)
    Print "F10="; Fact(10)
    Print "F12="; Fact(12)
    ExitProcess 0
End Sub
