' FACTORI.BAS - Factorielle en Visual Basic 6
' Exemple de Function recursive pour VBCW32

Function Factorielle(n As Long) As Long
    If n <= 1 Then
        Factorielle = 1
    Else
        Factorielle = n * Factorielle(n - 1)
    End If
End Function

Sub Main()
    Dim i As Long

    Print "Table des factorielles :"
    For i = 0 To 12
        Print CStr(i) & "! = " & CStr(Factorielle(i))
    Next i
End Sub
