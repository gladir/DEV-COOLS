Program TestSetVideoMode;

Uses MsGraph;

Var
 N : Integer;

BEGIN
 N := _SetVideoMode(_MRES16COLOR);
 WriteLn('Retour de _SetVideoMode: ', N);
 if N <> 0 then
   WriteLn('Succes, lignes texte: ', N)
 else
   WriteLn('Erreur');
 _SetVideoMode(_DEFAULTMODE);
END.
