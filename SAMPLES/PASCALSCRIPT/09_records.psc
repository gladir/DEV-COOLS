{ 09_records.psc - Types enumeres et enregistrements }

type
  TCouleur = (Rouge, Vert, Bleu);
  TPersonne = record
    Nom: String;
    Age: Integer;
    Couleur: TCouleur;
  end;

var
  Personne: TPersonne;

begin
  Personne.Nom := 'Ada Lovelace';
  Personne.Age := 36;
  Personne.Couleur := Bleu;

  WScript.Echo('Nom : ' + Personne.Nom);
  WScript.Echo('Age : ' + IntToStr(Personne.Age));

  if Personne.Couleur = Bleu then
    WScript.Echo('Couleur preferee : bleu');
end.
