{ 04_conditions.psc - If, then, else et case }

var
  Note: Integer;

begin
  Note := 82;

  if Note >= 90 then
    WScript.Echo('Excellent')
  else if Note >= 75 then
    WScript.Echo('Tres bien')
  else if Note >= 60 then
    WScript.Echo('Reussi')
  else
    WScript.Echo('A reprendre');

  case Note div 10 of
    10, 9: WScript.Echo('Categorie A');
    8:     WScript.Echo('Categorie B');
    7:     WScript.Echo('Categorie C');
  else
    WScript.Echo('Categorie D');
  end;
end.
