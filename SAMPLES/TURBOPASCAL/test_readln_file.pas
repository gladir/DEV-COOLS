Program test_readln_file;
Var
  F: Text;
  S: String;
Begin
  WriteLn('Step 1: Assign');
  Assign(F, 'test_find_input.txt');
  WriteLn('Step 2: Reset');
  Reset(F);
  WriteLn('Step 3: ReadLn');
  ReadLn(F, S);
  WriteLn('Step 4: Got line=', S);
  Close(F);
  WriteLn('Step 5: Done');
END.
