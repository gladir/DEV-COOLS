' STRING.VB - Operations sur chaines en Visual Basic .NET
' Exemple de fonctions de chaines pour VBNCW32

Module MainModule
    Sub Main()
        Dim s As String
        Dim s2 As String

        s = "  Hello, Visual Basic .NET!  "

        Console.WriteLine("Chaine originale : [" & s & "]")
        Console.WriteLine("Longueur         : " & s.Length.ToString())
        Console.WriteLine("Trim             : [" & s.Trim() & "]")
        Console.WriteLine("TrimStart        : [" & s.TrimStart() & "]")
        Console.WriteLine("TrimEnd          : [" & s.TrimEnd() & "]")
        Console.WriteLine("ToUpper          : " & s.Trim().ToUpper())
        Console.WriteLine("ToLower          : " & s.Trim().ToLower())
        Console.WriteLine("Substring(0,10)  : " & s.Trim().Substring(0, 10))
        Console.WriteLine("Substring(18)    : " & s.Trim().Substring(18))

        s2 = "Visual"
        Console.WriteLine("IndexOf('Visual'): " & s.Trim().IndexOf(s2).ToString())

        ' Concatenation
        Dim prenom As String
        Dim nom As String
        prenom = "Jean"
        nom = "Dupont"
        Console.WriteLine("Nom complet      : " & prenom & " " & nom)

        ' Conversion
        Dim n As Integer
        n = 12345
        Console.WriteLine("Nombre           : " & n.ToString())
        Console.WriteLine("Hex              : " & Hex(n))

        ' Asc et Chr
        Console.WriteLine("Asc('A')         : " & Asc("A").ToString())
        Console.WriteLine("Chr(65)          : " & Chr(65))

        ' Replace
        s = "Bonjour le monde"
        Console.WriteLine("Replace          : " & s.Replace("monde", "VB.NET"))
    End Sub
End Module
