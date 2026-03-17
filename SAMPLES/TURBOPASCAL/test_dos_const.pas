{ test_dos_const.pas - Test des constantes de l unite Dos }
program TestDosConst;

uses Dos;

begin
  { Constantes d attributs de fichier }
  WriteLn('ReadOnly=', ReadOnly);
  WriteLn('Hidden=', Hidden);
  WriteLn('SysFile=', SysFile);
  WriteLn('VolumeID=', VolumeID);
  WriteLn('Directory=', Directory);
  WriteLn('Archive=', Archive);
  WriteLn('AnyFile=', AnyFile);

  { Constantes de drapeaux processeur }
  WriteLn('FCarry=', FCarry);
  WriteLn('FParity=', FParity);
  WriteLn('FAuxiliary=', FAuxiliary);
  WriteLn('FZero=', FZero);
  WriteLn('FSign=', FSign);
  WriteLn('FOverflow=', FOverflow);

  { Constantes de modes de fichier }
  WriteLn('fmClosed=', fmClosed);
  WriteLn('fmInput=', fmInput);
  WriteLn('fmOutput=', fmOutput);
  WriteLn('fmInOut=', fmInOut);

  WriteLn('OK');
end.
