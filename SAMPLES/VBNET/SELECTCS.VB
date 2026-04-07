' SELECTCS.VB - Select Case en Visual Basic .NET
' Exemple de structures Select Case pour VBNCW32

Module MainModule
    Sub Main()
        Dim note As Integer
        Dim jour As Integer
        Dim mois As Integer

        ' Select Case simple
        note = 85
        Console.WriteLine("Note : " & note.ToString())
        Select Case note
            Case 90 To 100
                Console.WriteLine("  Resultat : Excellent")
            Case 80 To 89
                Console.WriteLine("  Resultat : Tres bien")
            Case 70 To 79
                Console.WriteLine("  Resultat : Bien")
            Case 60 To 69
                Console.WriteLine("  Resultat : Passable")
            Case Else
                Console.WriteLine("  Resultat : Echec")
        End Select

        ' Select Case avec valeurs multiples
        jour = 3
        Console.WriteLine("Jour " & jour.ToString() & " :")
        Select Case jour
            Case 1
                Console.WriteLine("  Lundi")
            Case 2
                Console.WriteLine("  Mardi")
            Case 3
                Console.WriteLine("  Mercredi")
            Case 4
                Console.WriteLine("  Jeudi")
            Case 5
                Console.WriteLine("  Vendredi")
            Case 6, 7
                Console.WriteLine("  Weekend")
            Case Else
                Console.WriteLine("  Jour invalide")
        End Select

        ' Select Case avec Is
        mois = 7
        Console.WriteLine("Mois " & mois.ToString() & " :")
        Select Case mois
            Case 1, 2, 12
                Console.WriteLine("  Saison : Hiver")
            Case 3, 4, 5
                Console.WriteLine("  Saison : Printemps")
            Case 6, 7, 8
                Console.WriteLine("  Saison : Ete")
            Case 9, 10, 11
                Console.WriteLine("  Saison : Automne")
        End Select
    End Sub
End Module
