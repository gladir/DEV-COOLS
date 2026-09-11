{ @author: Sylvain Maltais (support@gladir.com), d'apres GeoDump 0.5 de Marcus Groeber
  @created: 2026
  @abstract: Clone Turbo Pascal / Free Pascal de GEODUMP 0.5. }
Program GEODUMP;

{$A-}
{$I-}

Const
 GEOS1_ID = $53CF45C7;
 GEOS2_ID = $53C145C7;
 BSWF_ID  = $46575342;
 VM_ID    = $ADEB;
 GEOS1_HEADER_SIZE = 192;
 GEOS2_HEADER_SIZE = 256;
 APP1_HEADER_POS = $C0;
 APP2_HEADER_POS = 248;
 APP1_HEADER_SIZE = 96;
 APP2_HEADER_SIZE = 88;
 VM_DIR_HEADER_SIZE = 32;
 VM_DIR_RECORD_SIZE = 12;

Type
 TSegment = Record
  Len, FixLen, Flags : Word;
  Pos : LongInt;
 End;

Var
 F : File;
 FileName, DisplayName : String;
 FileLen, GeosBase : LongInt;
 GeosVersion : Integer;
 DoDump, DoList, OnePass : Boolean;
 OneResource : Integer;
 HadError : Boolean;

Function IfThenString(Test:Boolean;Const A,B:String):String; Forward;

Function HexDigit(N: Byte): Char;
Begin If N < 10 Then HexDigit := Chr(Ord('0') + N) Else HexDigit := Chr(Ord('A') + N - 10); End;

Function HexN(V: LongWord; Digits: Integer): String;
Var S: String; I: Integer;
Begin
 S := ''; For I := 1 to Digits do Begin S := HexDigit(Byte(V and 15)) + S; V := V shr 4; End;
 HexN := S;
End;

Function DecStr(V: LongInt): String;
Var S: String;
Begin Str(V, S); DecStr := S; End;

Procedure Fail(Const S: String);
Begin WriteLn('GeoDump: ', S); HadError := True; End;

Function ValidRange(Posn, Count: LongInt): Boolean;
Begin ValidRange := (Posn >= 0) and (Count >= 0) and (Posn <= FileLen) and (Count <= FileLen - Posn); End;

Procedure Go(Posn: LongInt);
Begin
 If not ValidRange(Posn, 0) Then Begin Fail('position de fichier invalide 0x' + HexN(LongWord(Posn), 8)); Exit; End;
 Seek(F, Posn); If IOResult <> 0 Then Fail('erreur de positionnement');
End;

Function ByteAt(Posn: LongInt): Byte;
Var B: Byte; N: Word;
Begin
 B := 0; If not ValidRange(Posn, 1) Then Begin Fail('fin de fichier inattendue'); ByteAt := 0; Exit; End;
 Seek(F, Posn); BlockRead(F, B, 1, N); If (IOResult <> 0) or (N <> 1) Then Fail('erreur de lecture'); ByteAt := B;
End;

Function WordAt(Posn: LongInt): Word;
Begin WordAt := Word(ByteAt(Posn)) or (Word(ByteAt(Posn + 1)) shl 8); End;

Function LongAt(Posn: LongInt): LongInt;
Begin LongAt := LongInt(LongWord(WordAt(Posn)) or (LongWord(WordAt(Posn + 2)) shl 16)); End;

Function FixedString(Posn: LongInt; Count: Integer; StopAtNull: Boolean): String;
Var S: String; I: Integer; C: Byte;
Begin
 S := ''; For I := 0 to Count - 1 do Begin C := ByteAt(Posn + I);
  If StopAtNull and (C = 0) Then Break;
  If Length(S) < 255 Then S := S + Chr(C);
 End;
 While (Length(S) > 0) and (S[Length(S)] in [#0, ' ']) do Delete(S, Length(S), 1);
 FixedString := S;
End;

Function BaseName(Const S: String): String;
Var I, StartPos, DotPos: Integer;
Begin
 StartPos := 1; DotPos := 0;
 For I := 1 to Length(S) do If S[I] in ['\','/',':'] Then Begin StartPos := I + 1; DotPos := 0; End Else If S[I] = '.' Then DotPos := I;
 If DotPos = 0 Then DotPos := Length(S) + 1; BaseName := Copy(S, StartPos, DotPos - StartPos);
End;

Function HasExtension(Const S: String): Boolean;
Var I: Integer;
Begin
 HasExtension := False; For I := Length(S) DownTo 1 do Begin
  If S[I] = '.' Then Begin HasExtension := True; Exit; End;
  If S[I] in ['\','/',':'] Then Exit;
 End;
End;

Function OpenInput(Const Requested: String): Boolean;
Var N: String; Success: Boolean;
Begin
 N := Requested; Assign(F, N); Reset(F, 1);
 If (IOResult <> 0) and not HasExtension(N) Then Begin N := N + '.GEO'; Assign(F, N); Reset(F, 1); End;
 Success := IOResult = 0; OpenInput := Success;
 If Success Then Begin FileName := N; DisplayName := BaseName(N); FileLen := FileSize(F); End;
End;

Function TokenAt(P: LongInt): String;
Var S: String; N: Word;
Begin
 S := FixedString(P, 4, True); N := WordAt(P + 4);
 If S = '' Then TokenAt := '-' Else TokenAt := S + ',' + DecStr(N);
End;

Function ReleaseAt(P: LongInt): String;
Begin ReleaseAt := DecStr(WordAt(P)) + '.' + DecStr(WordAt(P+2)) + '  ' + DecStr(WordAt(P+4)) + '-' + DecStr(WordAt(P+6)); End;

Function ProtocolAt(P: LongInt): String;
Var R: String;
Begin R := DecStr(WordAt(P+2)); While Length(R) < 3 do R := '0' + R; ProtocolAt := DecStr(WordAt(P)) + '.' + R; End;

Function Printable(B: Byte): Char;
Begin If (B >= 32) and (B <= 122) Then Printable := Chr(B) Else Printable := '.'; End;

Procedure DumpBytes(Posn, Count: LongInt; StartOffset: Word; Handle: LongInt);
Var I, J, N: LongInt; A: String; B: Byte;
Begin
 If not ValidRange(Posn, Count) Then Begin Fail('le bloc depasse la fin du fichier'); Exit; End;
 I := 0; While I < Count do Begin N := Count - I; If N > 16 Then N := 16;
  If Handle >= 0 Then A := '[' + HexN(Handle,4) + '] ' + HexN(StartOffset + I,4) + ':'
  Else If Handle = -2 Then A := '* Donnees: ' + HexN(StartOffset + I,4) + ':' Else A := HexN(StartOffset + I,4) + ':';
  Write(A); While Length(A) < 14 do Begin Write(' '); A := A + ' '; End; Write(' ');
  For J := 0 to 15 do If J < N Then Write(HexN(ByteAt(Posn+I+J),2),' ') Else Write('   ');
  For J := 0 to N - 1 do Begin B := ByteAt(Posn+I+J); Write(Printable(B)); End; WriteLn;
  Handle := -1; Inc(I, N);
 End;
End;

Procedure ListBytes(Posn, Count: LongInt; StartOffset: Word);
Var I, J, N: LongInt;
Begin
 If not ValidRange(Posn, Count) Then Begin Fail('la ressource depasse la fin du fichier'); Exit; End;
 I := 0; While I < Count do Begin N := Count-I; If N>8 Then N:=8;
  Write('L',HexN(StartOffset+I,4),':',#9,'db',#9);
  For J:=0 to N-1 do Begin If J<>0 Then Write(','); Write('0',HexN(ByteAt(Posn+I+J),2),'h'); End;
  WriteLn; Inc(I,N);
 End;
End;

Function SegmentFlags(V: Word): String;
Var S: String;
 Procedure Add(Const N: String);
 Begin If S <> '' Then S := S + ','; S := S + N; End;
Begin
 S := '';
 If (V and $8000) <> 0 Then Add('INITIALISE_A_ZERO'); If (V and $4000) <> 0 Then Add('VERROUILLE');
 If (V and $2000) <> 0 Then Add('SANS_ERREUR'); If (V and $1000) <> 0 Then Add('INTERFACE');
 If (V and $0800) <> 0 Then Add('LECTURE_SEULE'); If (V and $0400) <> 0 Then Add('RESSOURCE_OBJET');
 If (V and $0200) <> 0 Then Add('CODE'); If (V and $0100) <> 0 Then Add('CONFORME');
 If (V and $0080) <> 0 Then Add('FIXE'); If (V and $0040) <> 0 Then Add('PARTAGEABLE');
 If (V and $0020) <> 0 Then Add('JETABLE'); If (V and $0010) <> 0 Then Add('PERMUTABLE');
 If (V and $0008) <> 0 Then Add('LMEM'); If (V and $0004) <> 0 Then Add('DEBOGAGE');
 If (V and $0002) <> 0 Then Add('JETE'); If (V and $0001) <> 0 Then Add('PERMUTE');
 If S = '' Then S := '0'; SegmentFlags := S;
End;

Procedure DisplayHeap(Posn, Size: LongInt);
Var HList, Entries, FreeSize, Flags, LType, I, Ofs, BlockSize, NextOfs: Word;
Begin
 If not ValidRange(Posn, 16) Then Begin Fail('en-tete LMem tronque'); Exit; End;
 HList := WordAt(Posn+2); Flags := WordAt(Posn+4); LType := WordAt(Posn+6);
 Entries := WordAt(Posn+10); Ofs := WordAt(Posn+12); FreeSize := WordAt(Posn+14);
 WriteLn; WriteLn(' * LMem: Taille: ',WordAt(Posn+8):5,' octets   Liste des handles: @ 0x',HexN(HList,4),'   Entrees: ',Entries);
 WriteLn('        Libre: ',FreeSize:5,' octets'); WriteLn('     Attributs: ',HexN(Flags,4)); WriteLn('         Type: ',HexN(LType,4));
 If (Entries > 0) and (HList < Size) and ValidRange(Posn+HList, LongInt(Entries)*2) Then
  For I := 0 to Entries - 1 do Begin
   BlockSize := WordAt(Posn+HList+LongInt(I)*2);
   If (BlockSize <> 0) and (BlockSize <> $FFFF) and (BlockSize > HList) and (BlockSize < Size) Then Begin
    If BlockSize >= 2 Then Begin
     NextOfs := WordAt(Posn+BlockSize-2); If NextOfs > 2 Then DumpBytes(Posn+BlockSize, NextOfs-2, BlockSize, HList+I*2);
    End;
   End;
  End;
 I := 0; While (Ofs <> 0) and (I < 4096) do Begin
  If (Ofs < 2) or (Ofs >= Size) Then Begin Fail('liste libre LMem invalide'); Break; End;
  BlockSize := WordAt(Posn+Ofs-2); NextOfs := WordAt(Posn+Ofs);
  WriteLn('         ',HexN(Ofs,4),': *** libre: ',BlockSize:5,' octets'); Ofs := NextOfs; Inc(I);
 End;
End;

Procedure DisplayFixup(SegPos: LongInt; FixPos: LongInt; FixCount: Word);
Var I, T, O: Word; Kind, Target: String;
Begin
 If FixCount = 0 Then Exit;
 For I := 0 to FixCount - 1 do Begin
  T := WordAt(FixPos + LongInt(I)*4); O := WordAt(FixPos + LongInt(I)*4 + 2);
  Case T and $000F of
   0: Kind := 'pointeur distant vers routine'; 1: Kind := 'deplacement vers routine'; 2: Kind := 'segment de routine';
   3: Kind := 'segment'; 4: Kind := 'pointeur distant'; Else Kind := 'inconnu';
  End;
  Case T and $0030 of $00: Target := 'noyau'; $10: Target := 'bibliotheque'; $20: Target := 'programme'; Else Target := 'inconnu'; End;
  WriteLn('  Relogements: @ 0x',HexN(O,4),'  ',Kind,' (',Target,', type=',HexN(T,4),')');
 End;
End;

Procedure DisplaySegment(Index, NumSeg: Word; TablePos: LongInt);
Var S: TSegment; FixPos, DataPos, Rounded: LongInt; FixCount: Word; Prefix, SegName: String;
Begin
 S.Len := WordAt(TablePos + LongInt(Index)*2);
 S.Pos := LongAt(TablePos + LongInt(NumSeg)*2 + LongInt(Index)*4);
 S.FixLen := WordAt(TablePos + LongInt(NumSeg)*6 + LongInt(Index)*2);
 S.Flags := WordAt(TablePos + LongInt(NumSeg)*8 + LongInt(Index)*2);
 If (Index = 0) and (S.Len = 0) Then Exit;
 If Index = 1 Then SegName := 'idata' Else SegName := 'SEG' + DecStr(Index);
 If DoList Then Begin
  If (S.Flags and 8) <> 0 Then WriteLn(SegName,#9,'SEGMENT lmem 0',HexN(WordAt(GeosBase+S.Pos+6),4),'h,0',HexN(WordAt(GeosBase+S.Pos+4),4),'h')
  Else WriteLn(SegName,#9,'SEGMENT'); Prefix := ';';
 End Else Begin WriteLn('Ressource ',Index,':'); Prefix := ' '; End;
 DataPos := GeosBase + S.Pos; Rounded := (LongInt(S.Len) + 15) and LongInt($FFFFFFF0); FixPos := DataPos + Rounded;
 FixCount := S.FixLen div 4;
 WriteLn(Prefix,' Position fichier: @ 0x0',HexN(LongWord(DataPos),8),' Taille: 0x0',HexN(S.Len,4),'     Relogements: ',FixCount);
 WriteLn(Prefix,' ',SegmentFlags(S.Flags));
 If DoDump Then Begin
  If (S.Flags and 8) <> 0 Then DisplayHeap(DataPos, S.Len)
  Else Begin WriteLn; If DoList Then ListBytes(DataPos,S.Len,0) Else DumpBytes(DataPos, S.Len, 0, -2); End;
  If S.FixLen = 0 Then Begin End
  Else If ValidRange(FixPos, S.FixLen) Then DisplayFixup(DataPos, FixPos, FixCount)
  Else Fail('table de relogements tronquee dans la ressource ' + DecStr(Index));
 End;
 If DoList Then WriteLn(SegName,#9,'ENDS'); WriteLn;
End;

Procedure DisplayApplication;
Var P, D, LibPos, ExpPos, SegTable: LongInt; Attr, AppType, NumLib, NumExp, NumSeg, StackSize, I: Word;
    N, E, T: String;
Begin
 If GeosVersion = 1 Then P := APP1_HEADER_POS Else P := APP2_HEADER_POS; D := 0;
 If not ValidRange(P, APP1_HEADER_SIZE) Then Begin Fail('en-tete d''application tronque'); Exit; End;
 Attr := WordAt(P+34+D); AppType := WordAt(P+36+D); StackSize := WordAt(P+22+D);
 NumExp := WordAt(P+82+D); NumLib := WordAt(P+84+D); NumSeg := WordAt(P+88+D);
 N := FixedString(P+52+D,8,False); E := FixedString(P+60+D,4,False);
 WriteLn; WriteLn('    Nom permanent: ',N,E);
 Case AppType of 1:T:='[Application]'; 2:T:='[Bibliotheque]'; 3:T:='[Pilote]'; Else T:='???'; End;
 WriteLn('            Type: ',HexN(AppType,2),' ',T); WriteLn('       Attributs: ',HexN(Attr,4));
 WriteLn(' Protocole noyau: ',ProtocolAt(P+12+D)); WriteLn('            CRC?: 0x0',HexN(WordAt(P+50+D),4));
 WriteLn(' Pile/non-init.: ',StackSize,' octets');
 LibPos := P+APP1_HEADER_SIZE;
 If NumLib > 0 Then For I := 0 to NumLib-1 do Begin
  N := FixedString(LibPos+LongInt(I)*14,8,False); AppType := WordAt(LibPos+LongInt(I)*14+8);
  If AppType=$2000 Then T:='Pilote' Else If AppType=$4000 Then T:='Bibliotheque' Else T:='???';
  WriteLn('  Bibliotheques: ',I:2,': ',N,' ',T,' (protocole ',ProtocolAt(LibPos+LongInt(I)*14+10),')');
 End;
 If (Attr and $8000)<>0 Then Begin WriteLn('Classe processus: Ress:0x',HexN(WordAt(P+26+D),4),' Dep:0x',HexN(WordAt(P+24+D),4));
  WriteLn('Objet application: Ress:0x',HexN(WordAt(P+30+D),4),' Fragment:0x',HexN(WordAt(P+28+D),4)); End;
 If (Attr and $4000)<>0 Then WriteLn('  Initialisation: Ress:0x',HexN(WordAt(P+78+D),4),' Dep:0x',HexN(WordAt(P+76+D),4));
 If (Attr and $2000)<>0 Then WriteLn('  Table du pilote: Ress:0x',HexN(WordAt(P+74+D),4),' Dep:0x',HexN(WordAt(P+72+D),4));
 ExpPos := LibPos + LongInt(NumLib)*14;
 If DoDump and (NumExp > 0) Then For I := 0 to NumExp-1 do Begin If (I mod 4)=0 Then Write('    Exportations: ');
  Write(I:5,'=',HexN(WordAt(ExpPos+LongInt(I)*4+2),4),':',HexN(WordAt(ExpPos+LongInt(I)*4),4),' ');
  If ((I mod 4)=3) or (I=NumExp-1) Then WriteLn; End
 Else If NumExp<>0 Then WriteLn('    Exportations: ',NumExp,' emplacements');
 SegTable := ExpPos + LongInt(NumExp)*4; WriteLn;
 If DoList Then Begin WriteLn('%',#10,#10,'include stdapp.def',#10);
  If OnePass Then WriteLn('; Passes de desassemblage necessaires: 1 (/1)') Else WriteLn('; Passes de desassemblage necessaires: 1'); WriteLn;
 End;
 If NumSeg > 0 Then For I := 0 to NumSeg-1 do If (OneResource<0) or (I=OneResource) Then DisplaySegment(I,NumSeg,SegTable);
End;

Procedure DisplayVMFile;
Var P, DirPos, RecPos, BlockPos: LongInt; DirSize, Count, I, Hdl, Flags, ID, BlockSize: Word;
    TotalUsed, TotalFree: LongInt;
Begin
 If GeosVersion=1 Then P:=$C0 Else P:=GeosBase-8;
 If GeosVersion=1 Then Inc(P,8);
 If WordAt(P)<>VM_ID Then Begin WriteLn('Fichier VM invalide.'); Exit; End;
 DirSize:=WordAt(P+2); DirPos:=LongAt(P+4)+GeosBase;
 WriteLn; WriteLn(' Repertoire VM: @ 0x',HexN(LongWord(DirPos),6),'   Longueur: ',DirSize,' octets');
 If not ValidRange(DirPos,VM_DIR_HEADER_SIZE) Then Begin Fail('repertoire VM tronque'); Exit; End;
 WriteLn; WriteLn('  Blocs libres: ',WordAt(DirPos+10),'                         Handles libres: ',WordAt(DirPos+12));
 WriteLn('  Blocs utilises: ',WordAt(DirPos+14),'                     Blocs attaches: ',WordAt(DirPos+16));
 WriteLn('   Taille totale: ',LongAt(DirPos+24),' octets'); WriteLn('       Attributs: ',HexN(WordAt(DirPos+28),4));
 WriteLn; WriteLn(' Handle bloc carte: [',HexN(WordAt(DirPos+20),4),']  Handle bloc DBMap: [',HexN(WordAt(DirPos+30),4),']');
 WriteLn('1er bloc libre: [',HexN(WordAt(DirPos+2),4),']  dernier bloc libre: [',HexN(WordAt(DirPos+4),4),']  1er handle libre: [',HexN(WordAt(DirPos+6),4),']'); WriteLn;
 If DirSize<VM_DIR_HEADER_SIZE Then Begin Fail('taille du repertoire VM invalide'); Exit; End;
 Count:=(DirSize-VM_DIR_HEADER_SIZE) div VM_DIR_RECORD_SIZE; TotalUsed:=0; TotalFree:=0;
 If Count > 0 Then For I:=0 to Count-1 do Begin RecPos:=DirPos+VM_DIR_HEADER_SIZE+LongInt(I)*VM_DIR_RECORD_SIZE;
  Hdl:=VM_DIR_HEADER_SIZE+I*VM_DIR_RECORD_SIZE; Flags:=WordAt(RecPos+2); ID:=WordAt(RecPos+4);
  BlockSize:=WordAt(RecPos+6); BlockPos:=LongAt(RecPos+8)+GeosBase; Write('[',HexN(Hdl,4),']: ');
  If BlockSize<>0 Then Begin Inc(TotalUsed,BlockSize); WriteLn('     @ 0x',HexN(LongWord(BlockPos),6),' ',BlockSize:5,' octets  Handle mem.: ',HexN(WordAt(RecPos),4),'  ID utilisateur: ',HexN(ID,4));
   If Flags<>$00FF Then WriteLn('         Attributs: ',HexN(Flags,4));
   If DoDump Then Begin If I=0 Then WriteLn('        (repertoire des handles)') Else If (Flags and $0100)<>0 Then DisplayHeap(BlockPos,BlockSize) Else DumpBytes(BlockPos,BlockSize,0,-2); WriteLn; End;
  End Else If BlockPos<>GeosBase Then Begin Inc(TotalFree,WordAt(RecPos+4)); WriteLn('libre @ 0x',HexN(LongWord(BlockPos),6),' ',WordAt(RecPos+4):5,' octets   Precedent: [',HexN(WordAt(RecPos+2),4),']  Suivant: [',HexN(WordAt(RecPos),4),']'); End
  Else WriteLn('**** (inutilise)');
 End;
 WriteLn; WriteLn('Total des blocs: ',TotalUsed+TotalFree,' octets (',TotalUsed,' utilises, ',TotalFree,' libres)');
End;

Procedure DisplayFont;
Var FontID,Raster,PointStart,PointEnd,OutlineStart,OutlineEnd:Word; Family:Byte; P:LongInt;
Begin
 WriteLn('  Nom de police: ',FixedString(13,20,True)); FontID:=WordAt(8); Raster:=WordAt(10); Family:=ByteAt(12);
 WriteLn(' ID de la police: ',HexN(FontID,4)); WriteLn('          Famille: ',HexN(Family,2),' - Moteur de rendu: ',HexN(Raster,4));
 PointStart:=WordAt(33); PointEnd:=WordAt(35); OutlineStart:=WordAt(37); OutlineEnd:=WordAt(39);
 If OutlineStart<>0 Then Begin WriteLn; WriteLn('*** Donnees vectorielles ***'); P:=LongInt(OutlineStart)+6;
  While P<LongInt(OutlineEnd)+6 do Begin Write('        Style: ',HexN(ByteAt(P),2),' - Graisse: ',HexN(ByteAt(P+1),2));
   WriteLn(' - Taille totale: ',LongAt(P+6)+LongAt(P+14)+LongAt(P+22),' octets'); If DoDump Then DumpBytes(LongAt(P+2),LongAt(P+6),0,-1); Inc(P,26); End;
 End;
 If PointStart<>0 Then Begin WriteLn; WriteLn('*** Donnees matricielles (taille en points) ***'); P:=LongInt(PointStart)+6;
  While P<LongInt(PointEnd)+6 do Begin WriteLn('   Bloc de donnees: @ ',HexN(LongWord(LongAt(P+6)),8),' - Taille: ',WordAt(P+4):5,' octets - Style: ',HexN(ByteAt(P),2),' - Taille points: ',HexN(ByteAt(P+1),2),HexN(ByteAt(P+2),2),'.',HexN(ByteAt(P+3),2));
   If DoList Then DumpBytes(LongAt(P+6),WordAt(P+4),0,-1); Inc(P,10); End;
 End; WriteLn;
End;

Procedure DisplayGeosFile;
Var Magic:LongInt; ClassID,Flags,DateV,TimeV:Word; Name,Info,Copyright:String;
Begin
 Magic:=LongAt(0); If Magic=BSWF_ID Then Begin DisplayFont; Exit; End;
 If Magic=GEOS1_ID Then Begin GeosVersion:=1; GeosBase:=0; ClassID:=WordAt(4); Flags:=WordAt(6);
  Name:=FixedString(32,36,True); Info:=FixedString(68,100,True); Copyright:=FixedString(168,24,True);
  WriteLn('             Nom: ',Name,'       Jeton: ',TokenAt(20)); WriteLn('Type fichier GEOS: ',IfThenString(ClassID=0,'Executable (1.x)','Fichier VM (1.x)'),' Application: ',TokenAt(26));
  WriteLn('         Version: ',ReleaseAt(8),'    Protocole: ',ProtocolAt(16)); WriteLn('       Attributs: ',HexN(Flags,4));
 End Else If Magic=GEOS2_ID Then Begin GeosVersion:=2; GeosBase:=GEOS2_HEADER_SIZE; Name:=FixedString(4,36,True); ClassID:=WordAt(40); Flags:=WordAt(42);
  Info:=FixedString(68,100,True); Copyright:=FixedString(168,24,True); DateV:=WordAt(200); TimeV:=WordAt(202);
  WriteLn('             Nom: ',Name,'       Jeton: ',TokenAt(56));
  Case ClassID of 1:Name:='Executable (2.x)';2:Name:='Fichier VM (2.x)';3:Name:='Fichier niveau octet';4:Name:='Fichier d''information de repertoire';5:Name:='Lien';Else Name:='???';End;
  WriteLn('Type fichier GEOS: ',Name,' Application: ',TokenAt(62)); WriteLn('         Version: ',ReleaseAt(44),'    Protocole: ',ProtocolAt(52));
  WriteLn('            Cree: ',(DateV shr 5) and 15:2,'/',DateV and 31:2,'/',1980+(DateV shr 9):4,'  ',TimeV shr 11:2,':',(TimeV shr 5) and 63:2,'.',(TimeV and 31)*2:2);
  WriteLn('       Attributs: ',HexN(Flags,4));
 End Else Begin WriteLn('Ce fichier n''est pas un fichier PC/GEOS.'); Exit; End;
 If Info<>'' Then WriteLn('Informations util.: ',Info); If Copyright<>'' Then WriteLn(' Droits d''auteur: ',Copyright);
 If ((GeosVersion=1) and (ClassID=0)) or ((GeosVersion=2) and (ClassID=1)) Then DisplayApplication
 Else If ((GeosVersion=1) and (ClassID=1)) or ((GeosVersion=2) and (ClassID=2)) Then DisplayVMFile;
End;

Function IfThenString(Test:Boolean;Const A,B:String):String;
Begin If Test Then IfThenString:=A Else IfThenString:=B; End;
Procedure Usage;
Begin
  WriteLn('GEODUMP - Cette commande permet d''analyser des formats de fichiers PC/GEOS.'); 
 WriteLn;
 WriteLn('Syntaxe : GEODUMP [/D|/L] [/Rnn] [/1] fichier');
 WriteLn(#9,'  /D      Affiche le contenu des blocs et des ressources');
 WriteLn(#9,'  /L      Produit un listing des ressources ou polices (inclut /D)');
 WriteLn(#9,'  /Rnn    Limite l''affichage a la ressource nn (decimal)');
 WriteLn(#9,'  /1      Produit le listing des la premiere passe');
End;

Procedure ParseCommand;
Var I, Code:Integer; S,N:String;
Begin
 DoDump:=False;DoList:=False;OnePass:=False;OneResource:=-1;FileName:=''; I:=1;
 While I<=ParamCount do Begin S:=ParamStr(I);
  If (Length(S)>=2) and (S[1] in ['/','-']) Then Begin
   Case UpCase(S[2]) of 'D':DoDump:=True; 'L':Begin DoList:=True;DoDump:=True;End; '1':OnePass:=True;
    '?':Begin Usage; Halt(0); End;
    'R':Begin N:=Copy(S,3,Length(S));Val(N,OneResource,Code);If (Code<>0) or (N='') Then Begin Fail('numero de ressource invalide');OneResource:=-1;End;End;
   Else Fail('option inconnue '+S); End;
  End Else If FileName='' Then FileName:=S Else Fail('trop de noms de fichiers'); Inc(I);
 End;
End;

Begin
 HadError:=False; ParseCommand; If FileName='' Then Begin Usage; Halt(1); End;
 If HadError Then Halt(1); If not OpenInput(FileName) Then Begin WriteLn('Fichier introuvable.'); Halt(1); End;
 If DoList Then WriteLn('comment %'); WriteLn; WriteLn(#9#9#9'    Contenu de ',DisplayName); WriteLn;
 DisplayGeosFile; Close(F); If HadError Then Halt(1);
End.
