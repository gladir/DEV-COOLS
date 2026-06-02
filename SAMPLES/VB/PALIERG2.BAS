Function Fact(n As Long) As Long
    If n <= 1 Then
        Fact = 1
    Else
        Fact = n * Fact(n - 1)
    End If
End Function

Sub Main()
    Print "F1="; Fact(1)
    Print "F2="; Fact(2)
    Print "F3="; Fact(3)
    Print "F4="; Fact(4)
    ExitProcess 0
End Sub
