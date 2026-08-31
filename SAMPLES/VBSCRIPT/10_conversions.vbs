Rem 10_conversions.vbs - Conversions et verification des types

Dim valeur, tableau, objet
valeur = "123.75"
tableau = Array(10, 20, 30)
Set objet = Nothing

WScript.Echo "CInt  = " & CInt(valeur)
WScript.Echo "CLng  = " & CLng(valeur)
WScript.Echo "CDbl  = " & CDbl(valeur)
WScript.Echo "CStr  = " & CStr(42)
WScript.Echo "Hex   = " & Hex(255)
WScript.Echo "Oct   = " & Oct(64)
WScript.Echo "Val   = " & Val("42.5 pixels")
WScript.Echo "IsNumeric = " & IsNumeric(valeur)
WScript.Echo "IsArray   = " & IsArray(tableau)
WScript.Echo "IsObject  = " & IsObject(objet)
WScript.Echo "VarType   = " & VarType(tableau)
