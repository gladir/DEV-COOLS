Function Add(a As Long, b As Long) As Long
    Add = a + b
End Function

Function Fact(n As Long) As Long
    If n <= 1 Then
        Fact = 1
    Else
        Fact = n * Fact(n - 1)
    End If
End Function

Sub Main()
    Print "Add="; Add(3, 4)
    Print "F5="; Fact(5)
    Print "F10="; Fact(10)
    ExitProcess 0
End Sub
