' PALIERC2.BAS  --  variantes du palier C
' Tests : division entiere, Mod, comparaison, Else non pris
Dim R As Long

Sub Main()
    Dim A As Long
    Dim B As Long
    A = 100
    B = 7
    R = A \ B          ' 14
    R = R + (A Mod B)  ' 14 + 2 = 16
    If R <= 10 Then
        ExitProcess 0
    Else
        ExitProcess R + 1   ' 17
    End If
End Sub
