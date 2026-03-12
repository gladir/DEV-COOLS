{ test_memport.pas - Test emulation Mem/MemW/MemL/Port/PortW (TODO 22) }
program TestMemPort;
var
  B: Byte;
  W: Word;
  L: LongInt;
begin
  { Test lecture Mem (BIOS Data Area) }
  B := Mem[$0040:$0017];     { etat clavier }
  WriteLn('Etat clavier = ', B);

  B := Mem[$0040:$0049];     { mode video }
  WriteLn('Mode video = ', B);

  B := Mem[$0040:$004A];     { colonnes }
  WriteLn('Colonnes = ', B);

  B := Mem[$0040:$0084];     { lignes - 1 }
  WriteLn('Lignes - 1 = ', B);

  { Test lecture MemW }
  W := MemW[$0040:$004A];    { colonnes en 16 bits }
  WriteLn('MemW colonnes = ', W);

  { Test lecture MemL }
  L := MemL[$0040:$004A];    { colonnes en 32 bits }
  WriteLn('MemL colonnes = ', L);

  { Test ecriture Mem (stub - ignoree) }
  Mem[$B800:$0000] := 65;    { ecrire 'A' en memoire video }

  { Test Port en lecture }
  B := Port[$61];             { controle haut-parleur }
  WriteLn('Port 61h = ', B);

  { Test PortW en lecture }
  W := PortW[$61];
  WriteLn('PortW 61h = ', W);

  { Test Port en ecriture (CMOS index) }
  Port[$70] := 0;            { index CMOS = secondes }
  B := Port[$71];            { lire secondes via CMOS emule }
  WriteLn('CMOS secondes = ', B);

  WriteLn('Test Mem/Port termine.');
end.
