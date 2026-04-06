' SUBS.BAS - Sub et Function en Visual Basic 6
' Exemple de procedures et fonctions pour VBCW32

' Function avec retour par nom
Function Maximum(a As Long, b As Long) As Long
    If a > b Then
        Maximum = a
    Else
        Maximum = b
    End If
End Function

' Function avec retour par nom
Function Minimum(a As Long, b As Long) As Long
    If a < b Then
        Minimum = a
    Else
        Minimum = b
    End If
End Function

' Function recursive : puissance
Function Puissance(base As Long, exposant As Long) As Long
    If exposant = 0 Then
        Puissance = 1
    Else
        Puissance = base * Puissance(base, exposant - 1)
    End If
End Function

' Sub avec ByRef (modification du parametre)
Sub Echanger(ByRef a As Long, ByRef b As Long)
    Dim temp As Long
    temp = a
    a = b
    b = temp
End Sub

' Sub avec ByVal (pas de modification)
Sub AfficherDouble(ByVal n As Long)
    n = n * 2
    Print "  Double (local) = " & CStr(n)
End Sub

' Function avec parametre Optional
Function Saluer(nom As String, Optional titre As String = "M.") As String
    Saluer = "Bonjour " & titre & " " & nom & " !"
End Function

Sub Main()
    Dim x As Long
    Dim y As Long

    ' Test Maximum / Minimum
    Print "Maximum(15, 23) = " & CStr(Maximum(15, 23))
    Print "Minimum(15, 23) = " & CStr(Minimum(15, 23))

    ' Test Puissance
    Print "2^10 = " & CStr(Puissance(2, 10))
    Print "3^5  = " & CStr(Puissance(3, 5))

    ' Test ByRef (Echanger)
    x = 100
    y = 200
    Print "Avant echange : x=" & CStr(x) & " y=" & CStr(y)
    Echanger x, y
    Print "Apres echange : x=" & CStr(x) & " y=" & CStr(y)

    ' Test ByVal
    x = 42
    Print "Avant AfficherDouble : x=" & CStr(x)
    AfficherDouble x
    Print "Apres AfficherDouble : x=" & CStr(x) & " (inchange)"

    ' Test Optional
    Print Saluer("Dupont")
    Print Saluer("Martin", "Mme")
End Sub
