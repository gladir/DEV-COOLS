Module MainModule
    Sub Main()
        Dim i As Integer
        Dim n As Integer
        i = 42
        n = 100
        Console.WriteLine("i = " & i.ToString())
        Console.WriteLine("n + i = " & (n + i).ToString())
        Console.WriteLine("Produit = " & (i * 2).ToString())
        Console.WriteLine("Reste = " & (n Mod 7).ToString())
    End Sub
End Module
