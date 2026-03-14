{$TITLE Test Preprocessor}
{$HEADER Preprocessor Test Suite}
{$PAGE}
{$LENGTH=60}
{$WIDTH=132}
{$SOURCE}
{$OPTIONS SPECIAL, CHECK}
{$DEFINE DEBUG_ON}
Program PreprocessorTest(Output);
Var
  x : Integer;
Begin
{$IFDEF DEBUG_ON}
  x := 1;
{$ELSE}
  x := 0;
{$ENDIF}
{$IFNDEF RELEASE}
  WriteLn('Debug mode, x=', x);
{$END}
{$NOSOURCE}
  WriteLn('Done');
End.
