{ Test TODO 11 : Write / WriteLn / Read / ReadLn }
program test_writeread(output);

var
  X : Integer;
  C : Char;
  S : String;
  B : Boolean;

begin
  { WriteLn sans arguments -> CRLF }
  WriteLn;

  { WriteLn avec chaine }
  WriteLn('Hello, VAX Pascal!');

  { Write sans saut de ligne }
  Write('Valeur: ');

  { WriteLn avec entier }
  X := 42;
  WriteLn(X);

  { WriteLn avec expression }
  WriteLn(X + 8);

  { WriteLn avec booleen }
  B := True;
  WriteLn(B);

  { WriteLn avec caractere }
  C := 'A';
  WriteLn(C);

  { WriteLn avec format largeur (stub) }
  WriteLn(X:10);

  { WriteLn avec fichier predefini }
  WriteLn(output, 'Sur output');

  { WriteLn multi-arguments }
  WriteLn('X=', X, ' B=', B);

  { Write avec format :w:d }
  WriteLn(3.14:8:2);

  { Fin du programme }
  WriteLn('TODO 11 : Write/WriteLn OK');
end.
