' FACTORI.VB - Factorielle en Visual Basic .NET
' Exemple de Function recursive avec Return pour VBNCW32

Module MainModule
    Function Factorielle(ByVal n As Integer) As Integer
        If n <= 1 Then
            Return 1
        Else
            Return n * Factorielle(n - 1)
        End If
    End Function

    Sub Main()
        Dim i As Integer

        Console.WriteLine("Table des factorielles :")
        For i = 0 To 12
            Console.WriteLine(i.ToString() & "! = " & Factorielle(i).ToString())
        Next
    End Sub
End Module
