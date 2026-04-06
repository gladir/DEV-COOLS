' FILEIO.VB - Entrees/Sorties fichiers en Visual Basic .NET
' Exemple de lecture et ecriture de fichiers pour VBNCW32

Module MainModule
    Sub Main()
        Dim sLine As String
        Dim nFile As Integer

        ' Ecriture dans un fichier
        nFile = FreeFile()
        FileOpen(nFile, "TEST.TXT", OpenMode.Output)
        PrintLine(nFile, "Ligne 1 : Bonjour")
        PrintLine(nFile, "Ligne 2 : Visual Basic .NET")
        PrintLine(nFile, "Ligne 3 : Entrees/Sorties")
        PrintLine(nFile, "Ligne 4 : Fin du fichier")
        FileClose(nFile)

        Console.WriteLine("Fichier TEST.TXT ecrit avec succes.")

        ' Lecture du fichier
        Console.WriteLine("Contenu du fichier :")
        nFile = FreeFile()
        FileOpen(nFile, "TEST.TXT", OpenMode.Input)
        Do While Not EOF(nFile)
            sLine = LineInput(nFile)
            Console.WriteLine("  " & sLine)
        Loop
        FileClose(nFile)

        ' Ecriture avec Write (format CSV)
        nFile = FreeFile()
        FileOpen(nFile, "DATA.CSV", OpenMode.Output)
        WriteLine(nFile, "Nom", "Age", "Ville")
        WriteLine(nFile, "Alice", 30, "Paris")
        WriteLine(nFile, "Bob", 25, "Lyon")
        WriteLine(nFile, "Carol", 35, "Marseille")
        FileClose(nFile)

        Console.WriteLine("Fichier DATA.CSV ecrit avec succes.")
    End Sub
End Module
