' PALIERC.BAS  --  test du palier C
' Globals + locals + arithmetique + If/Then/Else + ExitProcess
Dim G As Long

Sub Main()
    Dim X As Long
    Dim Y As Long
    X = 10
    Y = 4
    G = X * Y - 2     ' 38
    If G > 30 Then
        G = G + 4     ' 42
    Else
        G = 0
    End If
    ExitProcess G
End Sub
