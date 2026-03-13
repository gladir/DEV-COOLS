{ test_program.pas - Test du programme principal (TODO 08) }
program TestProgram(Output);

uses
  Crt, Dos;

const
  AppName = 'TP2JS Test';
  Version = 1;
  MaxItems = 50;
  Pi = 3.14159;
  Debug = TRUE;

type
  TPoint = record
    X, Y: Integer;
  end;

var
  counter: Integer;
  name: String;
  flag: Boolean;
  value: Real;

const
  MinValue = 0;
  MaxValue = 100;

var
  extra: Integer;

label
  99;

begin
  WriteLn('Program: ', AppName);
  WriteLn('Version: ', Version);
  counter := 42;
  name := 'Hello World';
  flag := True;
  value := Pi;
  WriteLn('Counter = ', counter);
  WriteLn(name);
  if flag then
    WriteLn('Flag is true');
  if counter > 10 then
    WriteLn('Counter > 10')
  else
    WriteLn('Counter <= 10');
  if counter = 42 then
  begin
    WriteLn('Counter is 42');
    WriteLn('Inside begin/end block');
  end;
  extra := MaxItems + MinValue;
  WriteLn('Extra = ', extra);
  Write('Done');
  WriteLn('.');
end.
