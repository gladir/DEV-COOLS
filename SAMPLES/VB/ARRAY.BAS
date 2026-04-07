' ARRAY.BAS - Operations sur tableaux en Visual Basic 6
' Exemple de tableaux statiques et dynamiques pour VBCW32

Sub Main()
    Dim scores(1 To 10) As Long
    Dim i As Long
    Dim total As Long
    Dim moyenne As Long

    ' Remplir le tableau
    scores(1) = 85
    scores(2) = 92
    scores(3) = 78
    scores(4) = 95
    scores(5) = 88
    scores(6) = 76
    scores(7) = 90
    scores(8) = 84
    scores(9) = 91
    scores(10) = 87

    ' Calculer le total
    total = 0
    For i = 1 To 10
        total = total + scores(i)
    Next i

    moyenne = total \ 10

    Print "Scores :"
    For i = 1 To 10
        Print "  Score " & CStr(i) & " = " & CStr(scores(i))
    Next i
    Print "Total   = " & CStr(total)
    Print "Moyenne = " & CStr(moyenne)

    ' Tableau dynamique
    Dim dynArr() As Long
    ReDim dynArr(5)
    For i = 0 To 5
        dynArr(i) = i * i
    Next i

    Print "Tableau dynamique (carres) :"
    For i = 0 To 5
        Print "  " & CStr(i) & "^2 = " & CStr(dynArr(i))
    Next i

    Erase dynArr
End Sub
