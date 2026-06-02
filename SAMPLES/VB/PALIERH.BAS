' PALIERH.BAS - Test tableaux statiques 1D Long
Sub Main()
    Dim scores(1 To 10) As Long
    Dim i As Long
    Dim total As Long

    For i = 1 To 10
        scores(i) = i * 10
    Next i

    total = 0
    For i = 1 To 10
        total = total + scores(i)
    Next i

    Print "Total = "
    Print total
    Print "scores(5) = "
    Print scores(5)

    ' Test borne 0
    Dim arr(0 To 4) As Long
    arr(0) = 100
    arr(1) = 200
    arr(2) = 300
    arr(3) = 400
    arr(4) = 500
    Print "arr(2) = "
    Print arr(2)
    Print "arr(0) + arr(4) = "
    Print arr(0) + arr(4)
End Sub
