' LOOPS.VB - Boucles en Visual Basic 6
' Exemple de For, Do/Loop, While/Wend pour VBCW32

Sub Main()
    Dim i As Long
    Dim n As Long
    Dim total As Long

    ' Boucle For/Next classique
    Print "Boucle For 1 a 5 :"
    For i = 1 To 5
        Print "  i = " & CStr(i)
    Next i

    ' Boucle For avec Step
    Print "Boucle For avec Step 2 :"
    For i = 0 To 10 Step 2
        Print "  i = " & CStr(i)
    Next i

    ' Boucle For descendante
    Print "Boucle For descendante :"
    For i = 5 To 1 Step -1
        Print "  i = " & CStr(i)
    Next i

    ' Boucle Do While...Loop
    Print "Do While (somme jusqu'a 100) :"
    total = 0
    n = 1
    Do While total < 100
        total = total + n
        n = n + 1
    Loop
    Print "  total = " & CStr(total) & " (apres " & CStr(n - 1) & " iterations)"

    ' Boucle Do...Loop Until
    Print "Do...Loop Until (chercher multiple de 7 > 50) :"
    n = 50
    Do
        n = n + 1
    Loop Until (n Mod 7 = 0)
    Print "  Trouve : " & CStr(n)

    ' Boucle While...Wend
    Print "While...Wend (puissances de 2) :"
    n = 1
    While n <= 1024
        Print "  " & CStr(n)
        n = n * 2
    Wend

    ' Exit For
    Print "Exit For (trouver premier > 50 dans boucle 1..100) :"
    For i = 1 To 100
        If i > 50 Then
            Print "  Trouve : " & CStr(i)
            Exit For
        End If
    Next i
End Sub
