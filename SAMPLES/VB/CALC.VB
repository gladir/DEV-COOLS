' CALC.VB - Calculatrice simple en Visual Basic 6
' Exemple d'operations arithmetiques pour VBCW32

Sub Main()
    Dim a As Long
    Dim b As Long
    Dim result As Long

    a = 42
    b = 18

    result = a + b
    Print "Addition     : " & CStr(a) & " + " & CStr(b) & " = " & CStr(result)

    result = a - b
    Print "Soustraction : " & CStr(a) & " - " & CStr(b) & " = " & CStr(result)

    result = a * b
    Print "Multiplication: " & CStr(a) & " * " & CStr(b) & " = " & CStr(result)

    result = a \ b
    Print "Division ent.: " & CStr(a) & " \ " & CStr(b) & " = " & CStr(result)

    result = a Mod b
    Print "Modulo       : " & CStr(a) & " Mod " & CStr(b) & " = " & CStr(result)
End Sub
