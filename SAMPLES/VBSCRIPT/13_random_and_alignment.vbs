Rem 13_random_and_alignment.vbs - Randomize, Rnd, LSet et RSet

Dim i, champ
Randomize 42

For i = 1 To 5
    WScript.Echo "Rnd : " & Rnd()
Next

champ = ".........."
LSet champ = "gauche"
WScript.Echo "LSet : [" & champ & "]"

champ = ".........."
RSet champ = "droite"
WScript.Echo "RSet : [" & champ & "]"
