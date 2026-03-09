{ Test TODO 14 : FONCTIONS ET PROCEDURES }
program test_funcproc(output);

var
  R : Integer;

{ --- Procedure simple sans parametres --- }
procedure SayHello;
begin
  WriteLn('Hello from proc')
end;

{ --- Procedure avec parametre --- }
procedure PrintVal(X : Integer);
begin
  WriteLn(X)
end;

{ --- Fonction simple : retour par nom --- }
function Double(N : Integer) : Integer;
begin
  Double := N + N
end;

{ --- Fonction avec result --- }
function Triple(N : Integer) : Integer;
begin
  result := N + N + N
end;

{ --- Procedure avec deux parametres --- }
procedure AddPrint(A : Integer; B : Integer);
var
  S : Integer;
begin
  S := A + B;
  WriteLn(S)
end;

{ --- Fonction appelee par une autre --- }
function Square(N : Integer) : Integer;
begin
  Square := N * N
end;

function SumOfSquares(A : Integer; B : Integer) : Integer;
begin
  SumOfSquares := Square(A) + Square(B)
end;

{ --- Procedure avec exit premature --- }
procedure TestExit(X : Integer);
begin
  if X = 0 then
  begin
    WriteLn('exit early');
    exit
  end;
  WriteLn('not reached if 0')
end;

{ --- Forward declaration --- }
function Fwd(N : Integer) : Integer; forward;

function Fwd(N : Integer) : Integer;
begin
  Fwd := N + 100
end;

begin
  { Appel procedure simple }
  SayHello;

  { Appel procedure avec param }
  Write('PrintVal: ');
  PrintVal(42);

  { Appel fonction }
  R := Double(7);
  Write('Double 7 = ');
  WriteLn(R);

  { Appel fonction result }
  R := Triple(5);
  Write('Triple 5 = ');
  WriteLn(R);

  { Procedure deux params }
  Write('3+4 = ');
  AddPrint(3, 4);

  { Fonction imbriquee }
  R := SumOfSquares(3, 4);
  Write('3^2+4^2 = ');
  WriteLn(R);

  { Procedure avec exit }
  TestExit(0);

  { Forward }
  R := Fwd(5);
  Write('Fwd 5 = ');
  WriteLn(R);

  WriteLn('Tous les tests TODO 14 OK')
end.
