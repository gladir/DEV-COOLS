' ERRORS.VB - Gestion des erreurs en Visual Basic 6
' Exemple de On Error, Resume, Err pour VBCW32

Sub DiviserParZero()
    Dim a As Long
    Dim b As Long
    Dim result As Long

    On Error GoTo ErrHandler

    a = 100
    b = 0
    result = a \ b
    Print "Resultat = " & CStr(result)
    Exit Sub

ErrHandler:
    Print "  Erreur " & CStr(Err.Number) & " : " & Err.Description
    Resume Next
End Sub

Sub OuvrirFichierInexistant()
    Dim nFile As Integer

    On Error GoTo ErrOpen

    nFile = FreeFile
    Open "INEXISTANT.TXT" For Input As #nFile
    Close #nFile
    Print "Fichier ouvert avec succes"
    Exit Sub

ErrOpen:
    Print "  Erreur " & CStr(Err.Number) & " : " & Err.Description
    Err.Clear
End Sub

Sub TestResumeNext()
    Dim i As Long
    Dim result As Long

    On Error Resume Next

    For i = -2 To 2
        result = 100 \ i
        If Err.Number <> 0 Then
            Print "  Division 100 \ " & CStr(i) & " -> Erreur: " & Err.Description
            Err.Clear
        Else
            Print "  Division 100 \ " & CStr(i) & " = " & CStr(result)
        End If
    Next i

    On Error GoTo 0
End Sub

Sub TestErrRaise()
    On Error GoTo ErrCustom

    Err.Raise 9999, "ERRORS.VB", "Erreur personnalisee de test"
    Exit Sub

ErrCustom:
    Print "  Erreur personnalisee interceptee :"
    Print "    Numero : " & CStr(Err.Number)
    Print "    Source : " & Err.Source
    Print "    Desc.  : " & Err.Description
End Sub

Sub Main()
    Print "Test 1 : Division par zero"
    DiviserParZero

    Print "Test 2 : Fichier inexistant"
    OuvrirFichierInexistant

    Print "Test 3 : Resume Next"
    TestResumeNext

    Print "Test 4 : Err.Raise"
    TestErrRaise
End Sub
