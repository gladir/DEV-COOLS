' TRYCATCH.VB - Gestion des exceptions en Visual Basic .NET
' Exemple de Try/Catch/Finally/Throw pour VBNCW32

Module MainModule
    Sub DiviserParZero()
        Dim a As Integer
        Dim b As Integer
        Dim result As Integer

        Try
            a = 100
            b = 0
            result = a \ b
            Console.WriteLine("Resultat = " & result.ToString())
        Catch ex As Exception
            Console.WriteLine("  Erreur : " & ex.Message)
        End Try
    End Sub

    Sub OuvrirFichierInexistant()
        Dim nFile As Integer

        Try
            nFile = FreeFile()
            FileOpen(nFile, "INEXISTANT.TXT", OpenMode.Input)
            FileClose(nFile)
            Console.WriteLine("Fichier ouvert avec succes")
        Catch ex As Exception
            Console.WriteLine("  Erreur : " & ex.Message)
        End Try
    End Sub

    Sub TestFinally()
        Console.WriteLine("  Debut du bloc Try")
        Try
            Console.WriteLine("  Dans le bloc Try")
            Dim x As Integer = 10
            Dim y As Integer = 0
            Dim z As Integer = x \ y
        Catch ex As Exception
            Console.WriteLine("  Catch : " & ex.Message)
        Finally
            Console.WriteLine("  Finally : toujours execute")
        End Try
    End Sub

    Sub TestThrow()
        Try
            Throw New Exception("Erreur personnalisee de test")
        Catch ex As Exception
            Console.WriteLine("  Exception interceptee :")
            Console.WriteLine("    Message : " & ex.Message)
        End Try
    End Sub

    Sub TestMultipleCatch()
        Dim i As Integer

        For i = -2 To 2
            Try
                Dim result As Integer = 100 \ i
                Console.WriteLine("  Division 100 \ " & i.ToString() & " = " & result.ToString())
            Catch ex As DivideByZeroException
                Console.WriteLine("  Division 100 \ " & i.ToString() & " -> Division par zero!")
            Catch ex As Exception
                Console.WriteLine("  Division 100 \ " & i.ToString() & " -> Erreur: " & ex.Message)
            End Try
        Next
    End Sub

    Sub Main()
        Console.WriteLine("Test 1 : Division par zero")
        DiviserParZero()

        Console.WriteLine("Test 2 : Fichier inexistant")
        OuvrirFichierInexistant()

        Console.WriteLine("Test 3 : Finally")
        TestFinally()

        Console.WriteLine("Test 4 : Throw")
        TestThrow()

        Console.WriteLine("Test 5 : Multiple Catch")
        TestMultipleCatch()
    End Sub
End Module
