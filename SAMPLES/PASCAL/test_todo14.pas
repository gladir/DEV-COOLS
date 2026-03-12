program TestTodo14;

{ Test TODO 14 : PROCEDURES ET FONCTIONS }
{ Ce fichier teste les procedures, fonctions, parametres VAR, }
{ le mot-cle Result, les declarations Forward, et les        }
{ procedures imbriquees (nested).                             }

var
  a, b, c: Integer;

{ Test 1 : Procedure simple sans parametres }
procedure SayHello;
begin
  WriteLn('Hello from SayHello!');
end;

{ Test 2 : Procedure avec parametres par valeur }
procedure ShowSum(x, y: Integer);
begin
  WriteLn('Sum = ', x + y);
end;

{ Test 3 : Fonction avec Result (pas de var locale 'result') }
function Double(n: Integer): Integer;
begin
  Result := n * 2;
end;

{ Test 4 : Fonction avec affectation via nom de fonction }
function Triple(n: Integer): Integer;
begin
  Triple := n * 3;
end;

{ Test 5 : Procedure avec parametre VAR (par reference) }
procedure Increment(var x: Integer);
begin
  x := x + 1;
end;

{ Test 6 : Procedure avec parametre CONST }
procedure ShowValue(const v: Integer);
begin
  WriteLn('Value = ', v);
end;

{ Test 7 : Fonction recursive (factorielle) }
function Factorial(n: Integer): Integer;
begin
  if n <= 1 then
    Factorial := 1
  else
    Factorial := n * Factorial(n - 1);
end;

{ Test 8 : Forward declaration }
procedure Later; forward;

procedure CallLater;
begin
  Later;
end;

procedure Later;
begin
  WriteLn('Called Later via Forward');
end;

{ Test 9 : Procedure imbriquee (nested) }
procedure Outer;

  procedure Inner;
  begin
    WriteLn('Inside Inner');
  end;

begin
  WriteLn('Inside Outer');
  Inner;
end;

{ Test 10 : Fonction imbriquee avec parametres }
function Compute(x: Integer): Integer;

  function AddTen(n: Integer): Integer;
  begin
    AddTen := n + 10;
  end;

begin
  Compute := AddTen(x) + 5;
end;

begin
  { Test 1 : Procedure simple }
  SayHello;

  { Test 2 : Procedure avec parametres }
  ShowSum(10, 20);

  { Test 3 : Fonction avec Result }
  a := Double(7);
  WriteLn('Double(7) = ', a);

  { Test 4 : Fonction avec nom }
  b := Triple(5);
  WriteLn('Triple(5) = ', b);

  { Test 5 : VAR parameter }
  c := 42;
  Increment(c);
  WriteLn('After Increment(42) = ', c);

  { Test 6 : CONST parameter }
  ShowValue(99);

  { Test 7 : Recursion }
  WriteLn('Factorial(5) = ', Factorial(5));

  { Test 8 : Forward }
  CallLater;

  { Test 9 : Nested procedure }
  Outer;

  { Test 10 : Nested function }
  WriteLn('Compute(3) = ', Compute(3));
end.
