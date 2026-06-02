Sub Main()
    Dim a(1 To 3) As Long
    Dim i As Long
    a(1) = 10
    a(2) = 20
    a(3) = 30
    For i = 1 To 3
        Print "  a(" & CStr(i) & ") = " & CStr(a(i))
    Next i
    Print "Somme = " & CStr(a(1) + a(2) + a(3))
End Sub
