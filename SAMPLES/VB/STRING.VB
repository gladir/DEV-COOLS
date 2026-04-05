' STRING.VB - Operations sur chaines en Visual Basic 6
' Exemple de fonctions de chaines pour VBCW32

Sub Main()
    Dim s As String
    Dim s2 As String

    s = "  Hello, Visual Basic 6!  "

    Print "Chaine originale : [" & s & "]"
    Print "Longueur         : " & CStr(Len(s))
    Print "Trim             : [" & Trim(s) & "]"
    Print "LTrim            : [" & LTrim(s) & "]"
    Print "RTrim            : [" & RTrim(s) & "]"
    Print "UCase            : " & UCase(Trim(s))
    Print "LCase            : " & LCase(Trim(s))
    Print "Left(s, 10)      : " & Left(Trim(s), 10)
    Print "Right(s, 5)      : " & Right(Trim(s), 5)
    Print "Mid(s, 8, 6)     : " & Mid(Trim(s), 8, 6)

    s2 = "Visual"
    Print "InStr('Visual')  : " & CStr(InStr(Trim(s), s2))

    ' Concatenation
    Dim prenom As String
    Dim nom As String
    prenom = "Jean"
    nom = "Dupont"
    Print "Nom complet      : " & prenom & " " & nom

    ' Conversion
    Dim n As Long
    n = 12345
    Print "Nombre           : " & CStr(n)
    Print "Hex              : " & Hex(n)
    Print "Oct              : " & Oct(n)

    ' Asc et Chr
    Print "Asc('A')         : " & CStr(Asc("A"))
    Print "Chr(65)          : " & Chr(65)

    ' Replace
    s = "Bonjour le monde"
    Print "Replace          : " & Replace(s, "monde", "VB6")
End Sub
