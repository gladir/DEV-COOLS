{$MODE OBJFPC}{$H+}
Program VerifyLX;
{ Harnais de verification INDEPENDANT : reimplemente, ligne par ligne, la    }
{ MEME logique que Lx_ReadHeader/Emu_LoadLX/Lx_ApplyPageFixups de           }
{ DEVENV.PAS (relu directement dans le source avant d'ecrire ceci) pour     }
{ confirmer que les 3 executables LX construits a la main par buildlx.pas   }
{ seront bien parses de la facon attendue - meme discipline que les         }
{ harnais hfstest.pas/os2tcptest.pas de cette meme session : un simple      }
{ relecture de code n'aurait pas suffi a attraper les 2 bogues deja         }
{ trouves ET corriges dans buildlx.pas (en-tete LX a 168 au lieu de 176     }
{ octets, arguments ModOrd inverses) - une execution reelle contre le       }
{ fichier produit est le seul test qui compte vraiment. }

Uses SysUtils, StrUtils;

Type
 TLXHeader = Record
  e32_magic0, e32_magic1: Byte;
  e32_border, e32_worder: Byte;
  e32_level: LongInt;
  e32_cpu, e32_os: Word;
  e32_ver, e32_mflags, e32_mpages, e32_startobj, e32_eip, e32_stackobj,
  e32_esp, e32_pagesize, e32_pageshift, e32_fixupsize, e32_fixupsum,
  e32_ldrsize, e32_ldrsum, e32_objtab, e32_objcnt, e32_objmap, e32_itermap,
  e32_rsrctab, e32_rsrccnt, e32_restab, e32_enttab, e32_dirtab, e32_dircnt,
  e32_fpagetab, e32_frectab, e32_impmod, e32_impmodcnt, e32_impproc,
  e32_pagesum, e32_datapage, e32_preload, e32_nrestab, e32_cbnrestab,
  e32_nressum, e32_autodata, e32_debuginfo, e32_debuglen, e32_instpreload,
  e32_instdemand, e32_heapsize, e32_stacksize: LongInt;
 End;

 TLXObject = Record
  o32_size, o32_base, o32_flags, o32_pagemap, o32_mapsize, o32_reserved: LongInt;
 End;

 TLXObjPageEntry = Record
  SectorOffset: LongInt;
  SizeBytes, PageFlags: Word;
 End;

Var
 ImportModNames: Array[1..64] Of String;
 ImportSlotMod: Array[0..511] Of Byte;
 ImportSlotIsOrd: Array[0..511] Of Boolean;
 ImportSlotVal: Array[0..511] Of LongInt;
 ImportSlotName: Array[0..511] Of String;
 ImportSlotCount: Integer;
 AnyFailure: Boolean;

Function ResolveSlot(ModOrd: Byte; IsOrdinal: Boolean; Value: LongInt): Integer;
Var I: Integer;
Begin
 For I := 0 To ImportSlotCount - 1 Do
  If (ImportSlotMod[I] = ModOrd) And (ImportSlotIsOrd[I] = IsOrdinal) And (ImportSlotVal[I] = Value) Then Begin
   Result := I; Exit;
  End;
 If ImportSlotCount >= 512 Then Begin Result := -1; Exit; End;
 Result := ImportSlotCount;
 ImportSlotMod[Result] := ModOrd;
 ImportSlotIsOrd[Result] := IsOrdinal;
 ImportSlotVal[Result] := Value;
 ImportSlotName[Result] := '';
 Inc(ImportSlotCount);
End;

Procedure Fail(Const Msg: String);
Begin
 WriteLn('  *** ECHEC : ', Msg);
 AnyFailure := True;
End;

Procedure VerifyFile(Const Path: String);
Var
 F: File;
 FSize, HdrOfs: LongInt;
 Sig0, Sig1: Byte;
 Hdr: TLXHeader;
 BytesRead: Word;
 I, PageIdx: Integer;
 Obj: TLXObject;
 ObjBase: Array[1..64] Of LongInt;
 Page: TLXObjPageEntry;
 GlobalPageNo, FileOfs, DestAddr, CopyLen: LongInt;
 ModNameLen: Byte;
 ModNameBuf: String;
 CodeImgSize: LongInt;
 CodeImg: Array[0..8191] Of Byte;
 TotalPages: LongInt;

 Procedure DumpFixupsForPage(GlobalPg, DestA: LongInt);
 Var
  FStartBuf, FEndBuf, FixStart, FixEnd: LongInt;
  BR: Word;
  Src, Flg: Byte;
  SrcType, TgtType: Byte;
  SrcList, TgtOfs32, Add32, Obj16, Ord8, Additive: Boolean;
  SrcOfs: Word;
  B1: Byte; W1: Word; D1: LongInt;
  ModOrd, ImportVal, TargetVal, WriteAddr: LongInt;
  SlotIdx: Integer;
  SavedPos: LongInt;
  NameLen2: Byte;
  ProcName: String;
  OpByte: Byte;
 Begin
  Seek(F, HdrOfs + Hdr.e32_fpagetab + LongInt(GlobalPg - 1) * 4);
  BlockRead(F, FStartBuf, 4, BR); If BR <> 4 Then Begin Fail('lecture fpagetab'); Exit; End;
  BlockRead(F, FEndBuf, 4, BR); If BR <> 4 Then Begin Fail('lecture fpagetab (fin)'); Exit; End;
  FixStart := FStartBuf; FixEnd := FEndBuf;
  If FixEnd <= FixStart Then Begin
   WriteLn('    page globale ', GlobalPg, ' : aucun fixup.');
   Exit;
  End;
  Seek(F, HdrOfs + Hdr.e32_frectab + FixStart);
  While HdrOfs + Hdr.e32_frectab + FixStart < HdrOfs + Hdr.e32_frectab + FixEnd Do Begin
   BlockRead(F, Src, 1, BR); Inc(FixStart);
   BlockRead(F, Flg, 1, BR); Inc(FixStart);
   SrcType := Src And $0F; SrcList := (Src And $20) <> 0;
   TgtType := Flg And $03; Additive := (Flg And $04) <> 0;
   TgtOfs32 := (Flg And $10) <> 0; Add32 := (Flg And $20) <> 0;
   Obj16 := (Flg And $40) <> 0; Ord8 := (Flg And $80) <> 0;
   If SrcList Or ((SrcType <> 7) And (SrcType <> 8)) Or (TgtType = 3) Then Begin
    Fail('fixup hors perimetre (SrcType=' + IntToStr(SrcType) + ' TgtType=' + IntToStr(TgtType) + ')');
    Exit;
   End;
   BlockRead(F, W1, 2, BR); Inc(FixStart, 2); SrcOfs := W1;
   TargetVal := 0;
   Case TgtType Of
    0: Begin
     If Obj16 Then Begin BlockRead(F, W1, 2, BR); Inc(FixStart, 2); End
     Else Begin BlockRead(F, B1, 1, BR); Inc(FixStart); End;
     If TgtOfs32 Then Begin BlockRead(F, D1, 4, BR); Inc(FixStart, 4); End
     Else Begin BlockRead(F, W1, 2, BR); Inc(FixStart, 2); End;
     Fail('fixup INTERNAL inattendu (non utilise par buildlx.pas)');
    End;
    1, 2: Begin
     If Obj16 Then Begin BlockRead(F, W1, 2, BR); Inc(FixStart, 2); ModOrd := W1; End
     Else Begin BlockRead(F, B1, 1, BR); Inc(FixStart); ModOrd := B1; End;
     If TgtType = 1 Then Begin
      If Ord8 Then Begin BlockRead(F, B1, 1, BR); Inc(FixStart); ImportVal := B1; End
      Else If TgtOfs32 Then Begin BlockRead(F, D1, 4, BR); Inc(FixStart, 4); ImportVal := D1; End
      Else Begin BlockRead(F, W1, 2, BR); Inc(FixStart, 2); ImportVal := W1; End;
     End Else Begin
      If TgtOfs32 Then Begin BlockRead(F, D1, 4, BR); Inc(FixStart, 4); ImportVal := D1; End
      Else Begin BlockRead(F, W1, 2, BR); Inc(FixStart, 2); ImportVal := W1; End;
     End;
     If (ModOrd < 1) Or (ModOrd > Hdr.e32_impmodcnt) Then Begin
      Fail('ModOrd hors bornes (' + IntToStr(ModOrd) + ', impmodcnt=' + IntToStr(Hdr.e32_impmodcnt) + ')');
      Exit;
     End;
     SlotIdx := ResolveSlot(Byte(ModOrd), TgtType = 1, ImportVal);
     If SlotIdx < 0 Then Begin Fail('table de slots pleine'); Exit; End;
     ProcName := '';
     If TgtType = 2 Then Begin
      SavedPos := FilePos(F);
      Seek(F, HdrOfs + Hdr.e32_impproc + ImportVal);
      BlockRead(F, NameLen2, 1, BR);
      If BR = 1 Then Begin
       If NameLen2 > 0 Then Begin
        SetLength(ProcName, NameLen2);
        BlockRead(F, ProcName[1], NameLen2, BR);
        If BR <> NameLen2 Then ProcName := '';
       End;
      End;
      Seek(F, SavedPos);
      ImportSlotName[SlotIdx] := ProcName;
     End;
     WriteAddr := DestA + SrcOfs;
     { Verifie que l'octet juste AVANT ce disp32 est bien E8 (CALL rel32), }
     { preuve directe que le fixup cible exactement l'instruction CALL      }
     { emise par buildlx.pas et pas un octet voisin par erreur de calcul    }
     { (relecture via CodeImg, deja charge plus haut depuis le fichier). }
     If (WriteAddr - $00010000 >= 1) And (WriteAddr - $00010000 - 1 < CodeImgSize) Then Begin
      OpByte := CodeImg[WriteAddr - $00010000 - 1];
      If OpByte <> $E8 Then
       Fail('octet precedant le fixup (offset code ' + IntToStr(WriteAddr - $00010000 - 1) +
        ') = $' + HexStr(OpByte, 2) + ', attendu $E8 (CALL rel32)')
      Else
       WriteLn('    fixup OK : CALL a l''offset code $', HexStr(WriteAddr - $00010000 - 1, 4),
        ' -> module #', ModOrd, ' (', ImportModNames[ModOrd], ') proc "', ImportSlotName[SlotIdx],
        '" (slot ', SlotIdx, ', NameOfs=', ImportVal, ')');
     End Else
      Fail('WriteAddr hors de l''objet CODE charge (' + IntToStr(WriteAddr) + ')');
    End;
   End;
   If Additive Then Begin
    If Add32 Then Begin BlockRead(F, D1, 4, BR); Inc(FixStart, 4); End
    Else Begin BlockRead(F, W1, 2, BR); Inc(FixStart, 2); End;
    Fail('bit Additive inattendu (non utilise par buildlx.pas)');
   End;
  End;
 End;

Begin
 WriteLn('=== Verification de ', Path, ' ===');
 Assign(F, Path);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Begin Fail('impossible d''ouvrir le fichier'); Exit; End;
 FSize := FileSize(F);

 BlockRead(F, Sig0, 1, BytesRead); { 'M' }
 BlockRead(F, Sig1, 1, BytesRead); { 'Z' }
 If (Sig0 <> Ord('M')) Or (Sig1 <> Ord('Z')) Then Fail('signature MZ absente');
 Seek(F, 6);
 BlockRead(F, BytesRead, 2, I); { e_crlc, reutilise BytesRead comme buffer temporaire }
 If BytesRead <> 0 Then Fail('e_crlc (offset 6-7) <> 0 - NCFindExeKind classerait ce fichier NCEXE_DOS16');
 Seek(F, $3C);
 BlockRead(F, HdrOfs, 4, BytesRead);
 WriteLn('HdrOfs = $', HexStr(HdrOfs, 8));
 Seek(F, HdrOfs);
 BlockRead(F, Sig0, 1, BytesRead); BlockRead(F, Sig1, 1, BytesRead);
 If (Sig0 <> Ord('L')) Or (Sig1 <> Ord('X')) Then Fail('signature LX absente a HdrOfs');

 Seek(F, HdrOfs);
 BlockRead(F, Hdr, SizeOf(Hdr), BytesRead);
 If BytesRead <> SizeOf(Hdr) Then Begin Fail('lecture en-tete incomplete'); Exit; End;
 WriteLn('e32_objcnt=', Hdr.e32_objcnt, ' startobj=', Hdr.e32_startobj, ' eip=', Hdr.e32_eip,
  ' stackobj=', Hdr.e32_stackobj, ' esp=', Hdr.e32_esp, ' pageshift=', Hdr.e32_pageshift,
  ' impmodcnt=', Hdr.e32_impmodcnt, ' datapage=$', HexStr(Hdr.e32_datapage, 8));
 If (Hdr.e32_objcnt < 1) Or (Hdr.e32_objcnt > 64) Then Fail('objcnt hors bornes');
 If (Hdr.e32_startobj < 1) Or (Hdr.e32_startobj > Hdr.e32_objcnt) Then Fail('startobj hors bornes');
 If (Hdr.e32_stackobj < 1) Or (Hdr.e32_stackobj > Hdr.e32_objcnt) Then Fail('stackobj hors bornes');
 If Hdr.e32_pageshift < 1 Then Fail('pageshift < 1');

 For I := 1 To 64 Do ImportModNames[I] := '';
 If (Hdr.e32_impmodcnt > 0) And (Hdr.e32_impmodcnt < 64) Then Begin
  Seek(F, HdrOfs + Hdr.e32_impmod);
  For I := 1 To Hdr.e32_impmodcnt Do Begin
   BlockRead(F, ModNameLen, 1, BytesRead);
   ModNameBuf := '';
   If ModNameLen > 0 Then Begin
    SetLength(ModNameBuf, ModNameLen);
    BlockRead(F, ModNameBuf[1], ModNameLen, BytesRead);
   End;
   ImportModNames[I] := ModNameBuf;
   WriteLn('  module #', I, ' = "', ModNameBuf, '"');
  End;
 End Else Fail('impmodcnt hors bornes [1..63] : ' + IntToStr(Hdr.e32_impmodcnt));

 TotalPages := 0;
 ImportSlotCount := 0;
 Seek(F, HdrOfs + Hdr.e32_objtab);
 For I := 1 To Hdr.e32_objcnt Do Begin
  BlockRead(F, Obj, SizeOf(Obj), BytesRead);
  If BytesRead <> SizeOf(Obj) Then Begin Fail('lecture objet #' + IntToStr(I) + ' incomplete'); Exit; End;
  WriteLn('  objet #', I, ' : size=', Obj.o32_size, ' base=$', HexStr(Obj.o32_base, 8),
   ' flags=$', HexStr(Obj.o32_flags, 4), ' pagemap=', Obj.o32_pagemap, ' mapsize=', Obj.o32_mapsize);
  ObjBase[I] := Obj.o32_base;
  If (Obj.o32_base < 0) Or (Obj.o32_size < 0) Then Fail('objet #' + IntToStr(I) + ' base/size negatif');

  For PageIdx := 1 To Obj.o32_mapsize Do Begin
   GlobalPageNo := Obj.o32_pagemap + PageIdx - 1;
   If GlobalPageNo > TotalPages Then TotalPages := GlobalPageNo;
   Seek(F, HdrOfs + Hdr.e32_objmap + LongInt(GlobalPageNo - 1) * SizeOf(Page));
   BlockRead(F, Page, SizeOf(Page), BytesRead);
   If BytesRead <> SizeOf(Page) Then Begin Fail('lecture page objet incomplete'); Exit; End;
   DestAddr := Obj.o32_base + (PageIdx - 1) * Hdr.e32_pagesize;
   CopyLen := Page.SizeBytes;
   If CopyLen > Hdr.e32_pagesize Then CopyLen := Hdr.e32_pagesize;
   FileOfs := Page.SectorOffset * (1 Shl Hdr.e32_pageshift);
   WriteLn('    page globale #', GlobalPageNo, ' -> DestAddr=$', HexStr(DestAddr, 8),
    ' SectorOffset=', Page.SectorOffset, ' -> FileOfs=$', HexStr(FileOfs, 8),
    ' SizeBytes=', Page.SizeBytes,
    ' (', IfThen(FileOfs >= Hdr.e32_datapage, 'donnees reelles', 'BSS zero-fill'), ')');
   If I = Hdr.e32_startobj Then Begin
    { Charge l'image de l'objet CODE pour la verification des fixups       }
    { ci-dessous (octet precedant chaque disp32 doit etre $E8). }
    If (FileOfs >= Hdr.e32_datapage) And (CopyLen > 0) Then Begin
     Seek(F, FileOfs);
     BlockRead(F, CodeImg, CopyLen, BytesRead);
     CodeImgSize := BytesRead;
     If BytesRead <> Word(CopyLen) Then Fail('lecture image CODE incomplete');
    End;
   End;
   DumpFixupsForPage(GlobalPageNo, DestAddr);
   Seek(F, HdrOfs + Hdr.e32_objtab + LongInt(I) * SizeOf(Obj)); { repositionne comme Emu_LoadLX }
  End;
 End;

 WriteLn('Point d''entree = $', HexStr(ObjBase[Hdr.e32_startobj] + Hdr.e32_eip, 8),
  ' ESP initial = $', HexStr(ObjBase[Hdr.e32_stackobj] + Hdr.e32_esp, 8));
 WriteLn('Total slots d''import resolus : ', ImportSlotCount);
 For I := 0 To ImportSlotCount - 1 Do
  WriteLn('  slot ', I, ' : module #', ImportSlotMod[I], ' (', ImportModNames[ImportSlotMod[I]],
   ') proc="', ImportSlotName[I], '"');
 Close(F);
 WriteLn;
End;

Begin
 AnyFailure := False;
 VerifyFile(ParamStr(1));
 VerifyFile(ParamStr(2));
 VerifyFile(ParamStr(3));
 If AnyFailure Then Begin
  WriteLn('=== AU MOINS UN ECHEC DETECTE ===');
  Halt(1);
 End Else
  WriteLn('=== TOUTES LES VERIFICATIONS ONT REUSSI ===');
End.
