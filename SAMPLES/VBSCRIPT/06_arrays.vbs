Rem 06_arrays.vbs - Array, Dim, ReDim et Preserve

Dim couleurs()
ReDim couleurs(2)
couleurs(0) = "Rouge"
couleurs(1) = "Vert"
couleurs(2) = "Bleu"

WScript.Echo "LBound = " & LBound(couleurs)
WScript.Echo "UBound = " & UBound(couleurs)

ReDim Preserve couleurs(4)
couleurs(3) = "Cyan"
couleurs(4) = "Magenta"

Dim couleur
For Each couleur In couleurs
    WScript.Echo couleur
Next

Erase couleurs
WScript.Echo "Tableau efface"
