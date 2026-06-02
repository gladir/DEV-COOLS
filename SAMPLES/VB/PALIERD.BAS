' PALIERD.BAS  --  test du Palier D : boucles
' Calcule la somme 1+2+...+10 = 55, puis decremente jusqu a 13 via While,
' puis Do/Loop While pour finir a 42 (= 13 + 29).
Dim S As Long

Sub Main()
    Dim I As Long
    Dim K As Long
    S = 0
    For I = 1 To 10
        S = S + I
    Next I
    ' S = 55
    While S > 13
        S = S - 1
    Wend
    ' S = 13
    K = 0
    Do
        K = K + 1
        If K = 29 Then
            Exit Do
        End If
    Loop While K < 100
    S = S + K
    ExitProcess S
End Sub
