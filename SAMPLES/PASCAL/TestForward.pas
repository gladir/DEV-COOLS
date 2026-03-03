Program TestForward;

{ Test FORWARD déclarations de procédures et fonctions }

{ Déclarations FORWARD }
Function CalculateFibonacci(n: Integer): Integer; FORWARD;
Procedure DisplayResult(value: Integer); FORWARD;

{ Implémentation des procédures/fonctions }
Procedure DisplayResult(value: Integer);
Begin
  Write('Résultat: ');
  WriteLn(value);
End;

Function CalculateFibonacci(n: Integer): Integer;
Begin
  If n <= 1 Then
    CalculateFibonacci := n
  Else
    CalculateFibonacci := CalculateFibonacci(n-1) + CalculateFibonacci(n-2);
End;

{ Programme principal }
Begin
  writeln('Test des déclarations FORWARD');
  DisplayResult(CalculateFibonacci(5));
End.