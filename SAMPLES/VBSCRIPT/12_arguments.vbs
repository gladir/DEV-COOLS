Rem 12_arguments.vbs - Arguments de la ligne de commande
Rem Exemple : cscript 12_arguments.vbs alpha beta gamma

Dim nombre
nombre = WScript.Arguments.Count
WScript.Echo "Nombre d'arguments : " & nombre

If nombre > 0 Then WScript.Echo "Argument 0 : " & WScript.Arguments(0)
If nombre > 1 Then WScript.Echo "Argument 1 : " & WScript.Arguments(1)
If nombre > 2 Then WScript.Echo "Argument 2 : " & WScript.Arguments(2)
