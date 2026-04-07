' SUBS.VB - Sub et Function en Visual Basic .NET
' Exemple de procedures et fonctions pour VBNCW32

Module MainModule
    ' Function avec Return
    Function Maximum(ByVal a As Integer, ByVal b As Integer) As Integer
        If a > b Then
            Return a
        Else
            Return b
        End If
    End Function

    ' Function avec Return
    Function Minimum(ByVal a As Integer, ByVal b As Integer) As Integer
        If a < b Then
            Return a
        Else
            Return b
        End If
    End Function

    ' Function recursive : puissance
    Function Puissance(ByVal base As Integer, ByVal exposant As Integer) As Integer
        If exposant = 0 Then
            Return 1
        Else
            Return base * Puissance(base, exposant - 1)
        End If
    End Function

    ' Sub avec ByRef (modification du parametre)
    Sub Echanger(ByRef a As Integer, ByRef b As Integer)
        Dim temp As Integer
        temp = a
        a = b
        b = temp
    End Sub

    ' Sub avec ByVal (pas de modification)
    Sub AfficherDouble(ByVal n As Integer)
        n = n * 2
        Console.WriteLine("  Double (local) = " & n.ToString())
    End Sub

    ' Function avec parametre Optional
    Function Saluer(ByVal nom As String, Optional ByVal titre As String = "M.") As String
        Return "Bonjour " & titre & " " & nom & " !"
    End Function

    Sub Main()
        Dim x As Integer
        Dim y As Integer

        ' Test Maximum / Minimum
        Console.WriteLine("Maximum(15, 23) = " & Maximum(15, 23).ToString())
        Console.WriteLine("Minimum(15, 23) = " & Minimum(15, 23).ToString())

        ' Test Puissance
        Console.WriteLine("2^10 = " & Puissance(2, 10).ToString())
        Console.WriteLine("3^5  = " & Puissance(3, 5).ToString())

        ' Test ByRef (Echanger)
        x = 100
        y = 200
        Console.WriteLine("Avant echange : x=" & x.ToString() & " y=" & y.ToString())
        Echanger(x, y)
        Console.WriteLine("Apres echange : x=" & x.ToString() & " y=" & y.ToString())

        ' Test ByVal
        x = 42
        Console.WriteLine("Avant AfficherDouble : x=" & x.ToString())
        AfficherDouble(x)
        Console.WriteLine("Apres AfficherDouble : x=" & x.ToString() & " (inchange)")

        ' Test Optional
        Console.WriteLine(Saluer("Dupont"))
        Console.WriteLine(Saluer("Martin", "Mme"))
    End Sub
End Module
