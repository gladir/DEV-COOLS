{ 07_procedures.psc - Procedures, valeur et reference }

procedure Saluer(const Nom: String);
begin
  WScript.Echo('Bonjour ' + Nom);
end;

procedure Ajouter(var Total: Integer; Valeur: Integer);
begin
  Total := Total + Valeur;
end;

var
  Somme: Integer;

begin
  Somme := 10;
  Saluer('PascalScript');
  Ajouter(Somme, 5);
  Ajouter(Somme, 7);
  WScript.Echo('Somme = ' + IntToStr(Somme));
end.
