' FIBONACCI.VB - Suite de Fibonacci en Visual Basic 6
' Exemple de boucle For et variables pour VBCW32

Sub Main()
    Dim i As Long
    Dim a As Long
    Dim b As Long
    Dim temp As Long
    Dim n As Long

    n = 20
    a = 0
    b = 1

    Print "Suite de Fibonacci (premiers " & CStr(n) & " termes) :"
    Print CStr(a)
    Print CStr(b)

    For i = 3 To n
        temp = a + b
        a = b
        b = temp
        Print CStr(b)
    Next i
End Sub
