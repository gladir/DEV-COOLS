Module MainModule
    Sub Main()
        Dim i As Integer
        Console.WriteLine("Avant")
        For i = 0 To 2
            Console.WriteLine("  iter " & i.ToString())
        Next
        Console.WriteLine("Apres")
    End Sub
End Module
