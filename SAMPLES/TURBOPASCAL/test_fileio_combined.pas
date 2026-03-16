{ test_fileio_combined.pas - Test combine lecture/ecriture texte et binaire }
{ Demontre ecriture texte, lecture texte, ecriture binaire, lecture binaire }
program TestFileIOCombined;

var
  TF: Text;
  S: String;
  Buf: array[1..20] of Byte;
  I, Count: Integer;

begin
  WriteLn('=== Test combine fichier texte et binaire ===');

  { 1. Ecriture fichier texte }
  WriteLn('--- Etape 1: Ecriture texte ---');
  Assign(TF, 'combined_text.txt');
  Rewrite(TF);
  WriteLn(TF, 'Alpha');
  WriteLn(TF, 'Beta');
  WriteLn(TF, 'Gamma');
  WriteLn(TF, 'Delta');
  WriteLn(TF, 'Epsilon');
  Close(TF);
  WriteLn('5 lignes ecrites.');

  { 2. Lecture fichier texte }
  WriteLn('--- Etape 2: Lecture texte ---');
  Assign(TF, 'combined_text.txt');
  Reset(TF);
  Count := 0;
  while not EOF(TF) do
  begin
    ReadLn(TF, S);
    Count := Count + 1;
    WriteLn('  ', S);
  end;
  Close(TF);
  WriteLn(Count, ' lignes lues.');

  { 3. Ecriture fichier binaire }
  WriteLn('--- Etape 3: Ecriture binaire ---');
  For I := 1 To 20 Do
    Buf[I] := I * 5;
  Assign(TF, 'combined_bin.dat');
  Rewrite(TF);
  BlockWrite(TF, Buf, 20);
  Close(TF);
  WriteLn('20 octets binaires ecrits.');

  { 4. Lecture fichier binaire }
  WriteLn('--- Etape 4: Lecture binaire ---');
  For I := 1 To 20 Do
    Buf[I] := 0;
  Assign(TF, 'combined_bin.dat');
  Reset(TF);
  BlockRead(TF, Buf, 20);
  Close(TF);
  WriteLn('Premiers octets: ', Buf[1], ' ', Buf[2], ' ', Buf[3]);
  WriteLn('Derniers octets: ', Buf[18], ' ', Buf[19], ' ', Buf[20]);

  { 5. Ajout texte avec Append }
  WriteLn('--- Etape 5: Append texte ---');
  Assign(TF, 'combined_text.txt');
  Append(TF);
  WriteLn(TF, 'Zeta (ajoutee)');
  Close(TF);

  { 6. Relire pour verifier }
  WriteLn('--- Etape 6: Verification ---');
  Assign(TF, 'combined_text.txt');
  Reset(TF);
  Count := 0;
  while not EOF(TF) do
  begin
    ReadLn(TF, S);
    Count := Count + 1;
    WriteLn('  ', S);
  end;
  Close(TF);
  WriteLn(Count, ' lignes apres ajout.');

  WriteLn('Done.');
end.
