{ test_dos_fattr.pas - Test GetFAttr/SetFAttr/FSplit/FExpand }
program TestDosFattr;

uses Dos;

var
  F : File;
  Attr : Word;
  Dir : DirStr;
  Name : NameStr;
  Ext : ExtStr;
  S : PathStr;

begin
  { Test FSplit }
  FSplit('C:\DIR\FILE.TXT', Dir, Name, Ext);
  WriteLn('Dir=', Dir);
  WriteLn('Name=', Name);
  WriteLn('Ext=', Ext);
  WriteLn('FSplit OK');

  { Test FExpand }
  S := FExpand('TEST.PAS');
  WriteLn('FExpand=', S);
  If Length(S) > 0 Then WriteLn('FExpand OK')
  Else WriteLn('FExpand FAIL');

  WriteLn('OK');
end.
