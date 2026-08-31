Rem 07_functions.vbs - Fonctions utilisateur et recursion

Function Doubler(ByVal valeur)
    Doubler = valeur * 2
End Function

Function Factorielle(ByVal valeur)
    If valeur <= 1 Then
        Factorielle = 1
        Exit Function
    End If
    Factorielle = valeur * Factorielle(valeur - 1)
End Function

WScript.Echo "Doubler(7) = " & Doubler(7)
WScript.Echo "Factorielle(5) = " & Factorielle(5)
