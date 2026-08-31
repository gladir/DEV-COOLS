{ 10_arguments.psc - Arguments de la ligne de commande }

var
  I: Integer;

begin
  WScript.Echo('Nombre d''arguments : ' + IntToStr(WScript.Arguments.Count));

  for I := 0 to WScript.Arguments.Count - 1 do
    WScript.Echo('Argument ' + IntToStr(I) + ' : ' + WScript.Arguments.Item(I));
end.
