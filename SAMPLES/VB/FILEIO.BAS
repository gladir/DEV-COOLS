' FILEIO.BAS - Entrees/Sorties fichiers en Visual Basic 6
' Exemple de lecture et ecriture de fichiers pour VBCW32

Sub Main()
    Dim sLine As String
    Dim nFile As Integer

    ' Ecriture dans un fichier
    nFile = FreeFile
    Open "TEST.TXT" For Output As #nFile
    Print #nFile, "Ligne 1 : Bonjour"
    Print #nFile, "Ligne 2 : Visual Basic 6"
    Print #nFile, "Ligne 3 : Entrees/Sorties"
    Print #nFile, "Ligne 4 : Fin du fichier"
    Close #nFile

    Print "Fichier TEST.TXT ecrit avec succes."

    ' Lecture du fichier
    Print "Contenu du fichier :"
    nFile = FreeFile
    Open "TEST.TXT" For Input As #nFile
    Do While Not EOF(nFile)
        Line Input #nFile, sLine
        Print "  " & sLine
    Loop
    Close #nFile

    ' Ecriture avec Write (format CSV)
    nFile = FreeFile
    Open "DATA.CSV" For Output As #nFile
    Write #nFile, "Nom", "Age", "Ville"
    Write #nFile, "Alice", 30, "Paris"
    Write #nFile, "Bob", 25, "Lyon"
    Write #nFile, "Carol", 35, "Marseille"
    Close #nFile

    Print "Fichier DATA.CSV ecrit avec succes."
End Sub
