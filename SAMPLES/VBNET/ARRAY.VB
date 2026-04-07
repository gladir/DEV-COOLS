' ARRAY.VB - Operations sur tableaux en Visual Basic .NET
' Exemple de tableaux statiques et dynamiques pour VBNCW32

Module MainModule
    Sub Main()
        Dim scores(9) As Integer
        Dim i As Integer
        Dim total As Integer
        Dim moyenne As Integer

        ' Remplir le tableau
        scores(0) = 85
        scores(1) = 92
        scores(2) = 78
        scores(3) = 95
        scores(4) = 88
        scores(5) = 76
        scores(6) = 90
        scores(7) = 84
        scores(8) = 91
        scores(9) = 87

        ' Calculer le total
        total = 0
        For i = 0 To 9
            total = total + scores(i)
        Next

        moyenne = total \ 10

        Console.WriteLine("Scores :")
        For i = 0 To 9
            Console.WriteLine("  Score " & (i + 1).ToString() & " = " & scores(i).ToString())
        Next
        Console.WriteLine("Total   = " & total.ToString())
        Console.WriteLine("Moyenne = " & moyenne.ToString())

        ' Tableau dynamique
        Dim dynArr() As Integer
        ReDim dynArr(5)
        For i = 0 To 5
            dynArr(i) = i * i
        Next

        Console.WriteLine("Tableau dynamique (carres) :")
        For i = 0 To 5
            Console.WriteLine("  " & i.ToString() & "^2 = " & dynArr(i).ToString())
        Next

        Erase dynArr
    End Sub
End Module
