' SELECTCS.BAS - Select Case en Visual Basic 6
' Exemple de structures Select Case pour VBCW32

Sub Main()
    Dim note As Long
    Dim jour As Long
    Dim mois As Long

    ' Select Case simple
    note = 85
    Print "Note : " & CStr(note)
    Select Case note
        Case 90 To 100
            Print "  Resultat : Excellent"
        Case 80 To 89
            Print "  Resultat : Tres bien"
        Case 70 To 79
            Print "  Resultat : Bien"
        Case 60 To 69
            Print "  Resultat : Passable"
        Case Else
            Print "  Resultat : Echec"
    End Select

    ' Select Case avec valeurs multiples
    jour = 3
    Print "Jour " & CStr(jour) & " :"
    Select Case jour
        Case 1
            Print "  Lundi"
        Case 2
            Print "  Mardi"
        Case 3
            Print "  Mercredi"
        Case 4
            Print "  Jeudi"
        Case 5
            Print "  Vendredi"
        Case 6, 7
            Print "  Weekend"
        Case Else
            Print "  Jour invalide"
    End Select

    ' Select Case avec Is
    mois = 7
    Print "Mois " & CStr(mois) & " :"
    Select Case mois
        Case 1, 2, 12
            Print "  Saison : Hiver"
        Case 3, 4, 5
            Print "  Saison : Printemps"
        Case 6, 7, 8
            Print "  Saison : Ete"
        Case 9, 10, 11
            Print "  Saison : Automne"
    End Select
End Sub
