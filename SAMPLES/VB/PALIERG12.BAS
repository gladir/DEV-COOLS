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

Sub PrintTwice(x As Long)
    Print "x="; x
End Sub

Sub Main()
    Print "Add(3, 4) = "; Add(3, 4)
    Print "Fact(10) = "; Fact(10)
    ExitProcess 0
End Sub
