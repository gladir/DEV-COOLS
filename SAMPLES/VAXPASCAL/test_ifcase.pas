{ Test TODO 12 : IF / THEN / ELSE + CASE / OF + LABEL / GOTO }
program test_ifcase(output);

label 100, 200, sortie;

var
  X : Integer;
  Y : Integer;
  C : Char;

begin
  { --- IF / THEN simple --- }
  X := 10;
  if X = 10 then
    WriteLn('IF simple: OK');

  { --- IF / THEN / ELSE --- }
  Y := 5;
  if Y > 10 then
    WriteLn('IF/ELSE: FAIL')
  else
    WriteLn('IF/ELSE: OK');

  { --- IF / THEN / ELSE avec BEGIN..END --- }
  if X = 10 then
  begin
    WriteLn('IF block: OK');
    Y := 20
  end
  else
  begin
    WriteLn('IF block: FAIL');
    Y := 0
  end;

  { --- IF imbrique --- }
  if X > 0 then
    if Y = 20 then
      WriteLn('Nested IF: OK')
    else
      WriteLn('Nested IF: FAIL');

  { --- CASE / OF avec valeurs simples --- }
  X := 2;
  case X of
    1 : WriteLn('CASE val: FAIL');
    2 : WriteLn('CASE val: OK');
    3 : WriteLn('CASE val: FAIL');
  end;

  { --- CASE / OF avec OTHERS --- }
  X := 99;
  case X of
    1 : WriteLn('CASE others: FAIL');
    2 : WriteLn('CASE others: FAIL');
    others : WriteLn('CASE others: OK');
  end;

  { --- CASE / OF avec OTHERWISE --- }
  case X of
    1 : WriteLn('CASE otherwise: FAIL');
    otherwise : WriteLn('CASE otherwise: OK');
  end;

  { --- CASE / OF avec intervalle --- }
  X := 5;
  case X of
    1..3  : WriteLn('CASE range: FAIL');
    4..6  : WriteLn('CASE range: OK');
    7..10 : WriteLn('CASE range: FAIL');
  end;

  { --- LABEL et GOTO --- }
  goto 100;
  WriteLn('GOTO: FAIL');

100:
  WriteLn('GOTO numeric: OK');
  goto sortie;

200:
  WriteLn('GOTO: FAIL');

sortie:
  WriteLn('GOTO ident: OK');

  WriteLn('Tous les tests TODO 12 OK')
end.
