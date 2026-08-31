{ 03_strings.psc - Manipulation des chaines }

var
  Texte: String;

begin
  Texte := 'PascalScript et Gladir.com';

  WScript.Echo('Texte     : ' + Texte);
  WScript.Echo('Longueur  : ' + IntToStr(Length(Texte)));
  WScript.Echo('Debut     : ' + Copy(Texte, 1, 12));
  WScript.Echo('Position  : ' + IntToStr(Pos('Gladir', Texte)));
  WScript.Echo('Majuscules: ' + UpperCase(Texte));
  WScript.Echo('Minuscules: ' + LowerCase(Texte));
end.
