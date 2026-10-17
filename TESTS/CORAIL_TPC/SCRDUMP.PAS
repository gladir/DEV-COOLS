program SCRDUMP;
{ Copie le texte de l'ecran (B800) dans un fichier, lignes sans espaces de fin }
var F: Text; X, Y, L: Integer; S: String; C: Char; Seg: Word;
begin
  if Mem[$40:$49] = 7 then Seg := $B000 else Seg := $B800;
  Assign(F, ParamStr(1)); Rewrite(F);
  for Y := 0 to 24 do begin
    S := '';
    for X := 0 to 79 do begin
      C := Chr(Mem[Seg:(Y * 80 + X) * 2]);
      if C = #0 then C := ' ';
      S := S + C;
    end;
    L := Length(S);
    while (L > 0) and (S[L] = ' ') do Dec(L);
    S[0] := Chr(L);
    WriteLn(F, S);
  end;
  Close(F);
end.
