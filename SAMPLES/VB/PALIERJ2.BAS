Sub Main()
    On Error GoTo H
    Print "avant"
    Err.Raise 42, "src", "ma description"
    Print "apres (ne devrait pas s'afficher)"
    Exit Sub
H:
    Print "handler"
    Print Err.Number
    Print Err.Description
    Err.Clear
    Print Err.Number
End Sub
