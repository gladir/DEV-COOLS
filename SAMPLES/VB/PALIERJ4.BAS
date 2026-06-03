Sub Main()
    Dim a As Long
    Dim b As Long
    a = 100
    b = 0
    On Error GoTo H
    Print "avant"
    Print a \ b
    Print "apres (ne devrait pas s'afficher)"
    Exit Sub
H:
    Print "handler"
    Print Err.Number
End Sub
