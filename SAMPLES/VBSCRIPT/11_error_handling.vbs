Rem 11_error_handling.vbs - Gestion simple des erreurs

WScript.Echo "Avant la zone protegee"

On Error Resume Next
instruction_inconnue
WScript.Echo "Le script continue apres l'erreur"
On Error GoTo 0

WScript.Echo "Traitement normal restaure"
