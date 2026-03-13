Program test_findfile;
Uses DOS;
Var
  Info: SearchRec;
  FileFind: Text;
  CurrLine: String;
Begin
  WriteLn('Testing FindFirst...');
  FindFirst('test_find_input.txt', AnyFile, Info);
  WriteLn('DOSError = ', DOSError);
  If DOSError = 0 Then Begin
    WriteLn('Found: ', Info.Name);
    WriteLn('Assigning...');
    Assign(FileFind, Info.Name);
    WriteLn('Resetting...');
    Reset(FileFind);
    WriteLn('Reading...');
    WriteLn('Before EOF check...');
    If EOF(FileFind) Then
      WriteLn('EOF is TRUE')
    Else
      WriteLn('EOF is FALSE');
    WriteLn('After EOF check.');
    ReadLn(FileFind, CurrLine);
    WriteLn('After ReadLn, line=', CurrLine);
    Close(FileFind);
    WriteLn('Done.');
  End
  Else
    WriteLn('File not found!');
END.
