Rem 03_strings.vbs - Fonctions de chaines

Dim texte, resultat
texte = "  Gladir.com et VBScript  "

WScript.Echo "Original : [" & texte & "]"
WScript.Echo "Trim     : [" & Trim(texte) & "]"
WScript.Echo "LCase    : " & LCase(texte)
WScript.Echo "UCase    : " & UCase(texte)
WScript.Echo "Left     : " & Left(Trim(texte), 6)
WScript.Echo "Right    : " & Right(Trim(texte), 8)
WScript.Echo "Mid      : " & Mid(Trim(texte), 8, 3)
WScript.Echo "Longueur : " & Len(texte)

resultat = StrComp("Bonjour", "BONJOUR", 1)
WScript.Echo "StrComp texte : " & resultat
resultat = String(8, "*")
WScript.Echo "String : " & resultat
