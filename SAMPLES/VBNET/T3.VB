Module MainModule
    Sub Main()
        Dim i As Integer
        Console.WriteLine("L1")
        For i = 0 To 2
            Console.WriteLine("inner")
        Next
        Console.WriteLine("L3")
    End Sub
End Module
