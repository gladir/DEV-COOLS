Rem 08_subs_static.vbs - Sub, Call, ByVal et Static

Sub Saluer(ByVal nom)
    WScript.Echo "Bonjour " & nom
End Sub

Sub Compter()
    Static compteur
    compteur = compteur + 1
    WScript.Echo "Appel numero " & compteur
End Sub

Call Saluer("Sylvain")
Saluer "VBScript"
Compter
Compter
Compter
