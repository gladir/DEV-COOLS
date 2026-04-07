' CALC.VB - Calculatrice simple en Visual Basic .NET
' Exemple d'operations arithmetiques pour VBNCW32

Module MainModule
    Sub Main()
        Dim a As Integer
        Dim b As Integer
        Dim result As Integer

        a = 42
        b = 18

        result = a + b
        Console.WriteLine("Addition     : " & a.ToString() & " + " & b.ToString() & " = " & result.ToString())

        result = a - b
        Console.WriteLine("Soustraction : " & a.ToString() & " - " & b.ToString() & " = " & result.ToString())

        result = a * b
        Console.WriteLine("Multiplication: " & a.ToString() & " * " & b.ToString() & " = " & result.ToString())

        result = a \ b
        Console.WriteLine("Division ent.: " & a.ToString() & " \ " & b.ToString() & " = " & result.ToString())

        result = a Mod b
        Console.WriteLine("Modulo       : " & a.ToString() & " Mod " & b.ToString() & " = " & result.ToString())
    End Sub
End Module
