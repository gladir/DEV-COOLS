' LOOPS.VB - Boucles en Visual Basic .NET
' Exemple de For, Do/Loop, While/End While pour VBNCW32

Module MainModule
    Sub Main()
        Dim i As Integer
        Dim n As Integer
        Dim total As Integer

        ' Boucle For/Next classique
        Console.WriteLine("Boucle For 1 a 5 :")
        For i = 1 To 5
            Console.WriteLine("  i = " & i.ToString())
        Next

        ' Boucle For avec Step
        Console.WriteLine("Boucle For avec Step 2 :")
        For i = 0 To 10 Step 2
            Console.WriteLine("  i = " & i.ToString())
        Next

        ' Boucle For descendante
        Console.WriteLine("Boucle For descendante :")
        For i = 5 To 1 Step -1
            Console.WriteLine("  i = " & i.ToString())
        Next

        ' Boucle Do While...Loop
        Console.WriteLine("Do While (somme jusqu'a 100) :")
        total = 0
        n = 1
        Do While total < 100
            total = total + n
            n = n + 1
        Loop
        Console.WriteLine("  total = " & total.ToString() & " (apres " & (n - 1).ToString() & " iterations)")

        ' Boucle Do...Loop Until
        Console.WriteLine("Do...Loop Until (chercher multiple de 7 > 50) :")
        n = 50
        Do
            n = n + 1
        Loop Until (n Mod 7 = 0)
        Console.WriteLine("  Trouve : " & n.ToString())

        ' Boucle While...End While
        Console.WriteLine("While...End While (puissances de 2) :")
        n = 1
        While n <= 1024
            Console.WriteLine("  " & n.ToString())
            n = n * 2
        End While

        ' Exit For
        Console.WriteLine("Exit For (trouver premier > 50 dans boucle 1..100) :")
        For i = 1 To 100
            If i > 50 Then
                Console.WriteLine("  Trouve : " & i.ToString())
                Exit For
            End If
        Next

        ' Continue For
        Console.WriteLine("Continue For (nombres impairs de 1 a 10) :")
        For i = 1 To 10
            If i Mod 2 = 0 Then Continue For
            Console.WriteLine("  " & i.ToString())
        Next
    End Sub
End Module
