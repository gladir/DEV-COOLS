Rem 04_conditions.vbs - If, ElseIf et Else

Dim note
note = 82

If note >= 90 Then
    WScript.Echo "Excellent"
ElseIf note >= 75 Then
    WScript.Echo "Tres bien"
ElseIf note >= 60 Then
    WScript.Echo "Reussi"
Else
    WScript.Echo "A reprendre"
End If

If note >= 60 Then WScript.Echo "Resultat : succes" Else WScript.Echo "Resultat : echec"
