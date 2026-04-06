' USERTYPE.VB - Types utilisateur en Visual Basic 6
' Exemple de Type et Enum pour VBCW32

Type TPersonne
    Nom As String * 30
    Prenom As String * 20
    Age As Long
    Taille As Long
End Type

Enum ECouleur
    Rouge = 1
    Vert = 2
    Bleu = 3
    Jaune = 4
    Blanc = 5
End Enum

Function CouleurNom(c As Long) As String
    Select Case c
        Case Rouge
            CouleurNom = "Rouge"
        Case Vert
            CouleurNom = "Vert"
        Case Bleu
            CouleurNom = "Bleu"
        Case Jaune
            CouleurNom = "Jaune"
        Case Blanc
            CouleurNom = "Blanc"
        Case Else
            CouleurNom = "Inconnu"
    End Select
End Function

Sub AfficherPersonne(p As TPersonne)
    Print "  Nom    : " & Trim(p.Prenom) & " " & Trim(p.Nom)
    Print "  Age    : " & CStr(p.Age) & " ans"
    Print "  Taille : " & CStr(p.Taille) & " cm"
End Sub

Sub Main()
    Dim pers1 As TPersonne
    Dim pers2 As TPersonne
    Dim c As Long

    ' Remplir personne 1
    pers1.Nom = "Dupont"
    pers1.Prenom = "Jean"
    pers1.Age = 35
    pers1.Taille = 180

    ' Remplir personne 2
    With pers2
        .Nom = "Martin"
        .Prenom = "Marie"
        .Age = 28
        .Taille = 165
    End With

    Print "Personne 1 :"
    AfficherPersonne pers1

    Print "Personne 2 :"
    AfficherPersonne pers2

    ' Utilisation de l'enum
    Print "Couleurs :"
    For c = Rouge To Blanc
        Print "  " & CStr(c) & " = " & CouleurNom(c)
    Next c
End Sub
