{ hello.pas - WriteLn, variables, constantes, String (TODO 25) }
program Hello;

const
  Greeting = 'Hello, World!';
  AppVersion = 1;
  MaxLen = 80;

var
  Name: String;
  Counter: Integer;
  PI: Real;

begin
  WriteLn(Greeting);
  WriteLn('Version: ', AppVersion);
  Name := 'TP2JS';
  Counter := 42;
  PI := 3.14159;
  WriteLn('Name = ', Name);
  WriteLn('Counter = ', Counter);
  WriteLn('PI = ', PI:8:5);
  WriteLn('MaxLen = ', MaxLen);
  Write('Done');
  WriteLn('.');
end.
