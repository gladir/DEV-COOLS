Program test_readln_min;
Var
  F: Text;
Begin
  WriteLn('A');
  Assign(F, 'test_find_input.txt');
  WriteLn('B');
  Reset(F);
  WriteLn('C');
  ReadLn(F);
  WriteLn('D');
  Close(F);
  WriteLn('E');
END.
