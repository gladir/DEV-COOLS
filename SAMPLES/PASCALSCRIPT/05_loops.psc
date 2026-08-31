{ 05_loops.psc - Boucles for, while et repeat }

var
  I: Integer;

begin
  for I := 1 to 5 do
    WScript.Echo('For croissant : ' + IntToStr(I));

  for I := 5 downto 1 do
    WScript.Echo('For decroissant : ' + IntToStr(I));

  I := 0;
  while I < 3 do
  begin
    WScript.Echo('While : ' + IntToStr(I));
    I := I + 1;
  end;

  I := 0;
  repeat
    I := I + 1;
    WScript.Echo('Repeat : ' + IntToStr(I));
  until I = 3;
end.
