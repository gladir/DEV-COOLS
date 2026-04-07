' FIBONACCI.VB - Suite de Fibonacci en Visual Basic .NET
' Exemple de boucle For et variables pour VBNCW32

Module MainModule
    Sub Main()
        Dim i As Integer
        Dim a As Integer
        Dim b As Integer
        Dim temp As Integer
        Dim n As Integer

        n = 20
        a = 0
        b = 1

        Console.WriteLine("Suite de Fibonacci (premiers " & n.ToString() & " termes) :")
        Console.WriteLine(a.ToString())
        Console.WriteLine(b.ToString())

        For i = 3 To n
            temp = a + b
            a = b
            b = temp
            Console.WriteLine(b.ToString())
        Next
    End Sub
End Module
