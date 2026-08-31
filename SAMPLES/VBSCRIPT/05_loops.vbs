Rem 05_loops.vbs - For, For Each, While et Do Loop

Dim i, noms, nom

For i = 1 To 5
    WScript.Echo "For : " & i
Next i

For i = 10 To 2 Step -2
    WScript.Echo "For negatif : " & i
Next

noms = Array("Ada", "Grace", "Linus")
For Each nom In noms
    WScript.Echo "Nom : " & nom
Next

i = 0
While i < 3
    WScript.Echo "While : " & i
    i = i + 1
Wend

i = 0
Do
    i = i + 1
    WScript.Echo "Do : " & i
Loop Until i = 3
