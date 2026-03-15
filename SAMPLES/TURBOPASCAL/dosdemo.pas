{ dosdemo.pas - uses Dos: GetDate, GetTime, FindFirst, Exec (TODO 25) }
program DosDemo;

uses Dos;

var
  Year, Month, Day, DayOfWeek: Word;
  Hour, Minute, Second, Sec100: Word;
  SR: SearchRec;
  DT: DateTime;
  EnvStr: String;

begin
  { Date et heure }
  GetDate(Year, Month, Day, DayOfWeek);
  WriteLn('Date: ', Day, '/', Month, '/', Year);
  WriteLn('Jour de la semaine: ', DayOfWeek);

  GetTime(Hour, Minute, Second, Sec100);
  WriteLn('Heure: ', Hour, ':', Minute, ':', Second);

  { Version de DOS }
  WriteLn('DosVersion: ', Lo(DosVersion), '.', Hi(DosVersion));

  { Variables d environnement }
  EnvStr := GetEnv('PATH');
  if Length(EnvStr) > 0 then
    WriteLn('PATH = ', Copy(EnvStr, 1, 60), '...')
  else
    WriteLn('PATH non defini');

  { Recherche de fichiers }
  WriteLn('Recherche *.pas:');
  FindFirst('*.pas', Archive, SR);
  while DosError = 0 do
  begin
    WriteLn('  ', SR.Name, ' (', SR.Size, ' octets)');
    FindNext(SR);
  end;

  { Taille du disque }
  WriteLn('DiskFree(0) = ', DiskFree(0));
  WriteLn('DiskSize(0) = ', DiskSize(0));

  WriteLn('Done.');
end.
