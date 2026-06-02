Function Fact(n As Long) As Long
    If n <= 1 Then
        Fact = 1
    Else
        Fact = n * Fact(n - 1)
    End If
End Function

Sub DoIt
    Print "hello"
End Sub

Sub Main()
    Print "Fact(5) = "; Fact(5)
    Print "Fact(10) = "; Fact(10)
    ExitProcess 0
End Sub
