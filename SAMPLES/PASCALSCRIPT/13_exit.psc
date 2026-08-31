{ 13_exit.psc - Sortie anticipee d'une fonction }

function PremierPositif(A, B: Integer): Integer;
begin
  Result := 0;
  if A > 0 then
  begin
    Result := A;
    Exit;
  end;
  if B > 0 then
    Result := B;
end;

begin
  WScript.Echo('Premier positif : ' + IntToStr(PremierPositif(-4, 9)));
end.
