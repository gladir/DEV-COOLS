{ mathunit.pas - Unite de fonctions mathematiques (TODO 25) }
unit MathUnit;

interface

const
  MathPI = 3.14159265;

function MathAdd(A, B: Integer): Integer;
function MathSub(A, B: Integer): Integer;
function MathMul(A, B: Integer): Integer;
function MathMax(A, B: Integer): Integer;
function MathMin(A, B: Integer): Integer;
function MathAvg(A, B: Integer): Real;

implementation

function MathAdd(A, B: Integer): Integer;
begin
  MathAdd := A + B;
end;

function MathSub(A, B: Integer): Integer;
begin
  MathSub := A - B;
end;

function MathMul(A, B: Integer): Integer;
begin
  MathMul := A * B;
end;

function MathMax(A, B: Integer): Integer;
begin
  if A > B then
    MathMax := A
  else
    MathMax := B;
end;

function MathMin(A, B: Integer): Integer;
begin
  if A < B then
    MathMin := A
  else
    MathMin := B;
end;

function MathAvg(A, B: Integer): Real;
begin
  MathAvg := (A + B) / 2.0;
end;

begin
  WriteLn('MathUnit initialized');
end.
