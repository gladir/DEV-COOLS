' STRUCTUR.VB - Structures et Enum en Visual Basic .NET
' Exemple de Structure et Enum pour VBNCW32

Module MainModule
    Structure Personne
        Public Nom As String
        Public Prenom As String
        Public Age As Integer
        Public Taille As Integer
    End Structure

    Enum Couleur
        Rouge = 1
        Vert = 2
        Bleu = 3
        Jaune = 4
        Blanc = 5
    End Enum

    Function CouleurNom(ByVal c As Couleur) As String
        Select Case c
            Case Couleur.Rouge
                Return "Rouge"
            Case Couleur.Vert
                Return "Vert"
            Case Couleur.Bleu
                Return "Bleu"
            Case Couleur.Jaune
                Return "Jaune"
            Case Couleur.Blanc
                Return "Blanc"
            Case Else
                Return "Inconnu"
        End Select
    End Function

    Sub AfficherPersonne(ByVal p As Personne)
        Console.WriteLine("  Nom    : " & p.Prenom & " " & p.Nom)
        Console.WriteLine("  Age    : " & p.Age.ToString() & " ans")
        Console.WriteLine("  Taille : " & p.Taille.ToString() & " cm")
    End Sub

    Sub Main()
        Dim pers1 As Personne
        Dim pers2 As Personne
        Dim c As Integer

        ' Remplir personne 1
        pers1.Nom = "Dupont"
        pers1.Prenom = "Jean"
        pers1.Age = 35
        pers1.Taille = 180

        ' Remplir personne 2
        pers2.Nom = "Martin"
        pers2.Prenom = "Marie"
        pers2.Age = 28
        pers2.Taille = 165

        Console.WriteLine("Personne 1 :")
        AfficherPersonne(pers1)

        Console.WriteLine("Personne 2 :")
        AfficherPersonne(pers2)

        ' Utilisation de l'enum
        Console.WriteLine("Couleurs :")
        For c = Couleur.Rouge To Couleur.Blanc
            Console.WriteLine("  " & c.ToString() & " = " & CouleurNom(CType(c, Couleur)))
        Next
    End Sub
End Module
