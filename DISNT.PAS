{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
 @description: Analyseur et desassembleur d'images Windows NT PE/COFF. }

Program DISNT;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}
{$A-}{$I-}

Uses DOS;

Const
 VERSION='1.0';
 MAX_SECTIONS=96;
 {$IFDEF FPC}
  MAX_FILE_SIZE=67108864;
 {$ELSE}
  MAX_FILE_SIZE=65520;
 {$ENDIF}
 IMAGE_SCN_MEM_EXECUTE=$20000000;

Type
 TString=String;
 {$IFDEF FPC}
  TBytes=Array[0..MAX_FILE_SIZE-1] Of Byte;
 {$ELSE}
  TBytes=Array[0..65519] Of Byte;
 {$ENDIF}
 PBytes=^TBytes;
 TSection=Record
  Name:String[8];
  VSize,RVA,RawSize,RawPtr,Characteristics:LongInt;
 End;

Var
 Data:PBytes;
 DataSize:LongInt;
 InName,OutName,ListName,MapName,PDBName,CPUForce,AsmStyle,NTVersion:TString;
 OutF,ListF,MapF:Text;
 UseList,UseMap:Boolean;
 PEOfs,OptOfs,EntryRVA,ImageBaseLo,ImageBaseHi,SizeOfImage:LongInt;
 Machine,SectionCount,OptSize,OptMagic,Subsystem:Word;
 DirRVA,DirSize:Array[0..15] Of LongInt;
 Sections:Array[0..MAX_SECTIONS-1] Of TSection;
 IsPE64:Boolean;
 OptHdr,OptSections,OptImports,OptExports,OptReloc,OptResources,
 OptExcept,OptStrings,OptData,OptBytes,OptAddr,OptComments,OptXRef,
 OptSymbols,OptDemangle,OptEntry,OptVerbose,OptQuiet:Boolean;
 OptKernel,OptDriver,OptHAL,OptNative,OptSyscall,OptNTAPI,OptStruct,
 OptDriverEntry,OptDispatch,OptUnload,OptIRP,OptIO,OptMM,OptOB,OptPS,
 OptCM,OptSE,OptKE,OptEX,OptKD,OptWDM,OptWDF,OptUnicode:Boolean;
 StartRVA,StartVA,ForcedBaseLo:LongInt;
 HasStartRVA,HasStartVA,HasForcedBase:Boolean;

Function UpStr(S:TString):TString;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do If (S[I]>='a') And (S[I]<='z') Then S[I]:=Chr(Ord(S[I])-32);
 UpStr:=S;
End;

Function HexN(V:LongInt; N:Byte):TString;
Const
 D:Array[0..15] Of Char='0123456789ABCDEF';
Var
 S:TString;
 I:Byte;
Begin
 S:='';
 For I:=1 To N Do Begin
  S:=D[V And 15]+S; V:=LongInt(LongWord(V) Shr 4);
 End; HexN:=S;
End;

Function Hex8(V:LongInt):TString;Begin
 Hex8:=HexN(V,8);
End;

Function Hex4(V:Word):TString;Begin
 Hex4:=HexN(V,4);
End;

Function Hex2(V:Byte):TString;Begin
 Hex2:=HexN(V,2);
End;

Function U16(O:LongInt):Word;Begin
 If (O<0) Or (O+1>=DataSize) Then U16:=0 Else U16:=Word(Data^[O])+(Word(Data^[O+1]) Shl 8)
 ;
End;

Function U32(O:LongInt):LongInt;Begin
 If (O<0) Or (O+3>=DataSize) Then U32:=0 Else U32:=LongInt(Data^[O])+(LongInt(Data^[O+1])
 Shl 8)+(LongInt(Data^[O+2]) Shl 16)+(LongInt(Data^[O+3]) Shl 24);
End;

Function CStr(O:LongInt):TString;
Var
 S:TString;
Begin
 S:='';
 While (O>=0) And (O<DataSize) And (Data^[O]<>0) And (Length(S)<255) Do Begin
  S:=S+Chr(Data^[O]); Inc(O);
 End; CStr:=S;
End;

Procedure Put(S:TString);Begin
 WriteLn(OutF,S); If UseList Then WriteLn(ListF,S);
End;

Procedure PutMap(S:TString);Begin
 If UseMap Then WriteLn(MapF,S);
End;

Function ParseHex(S:TString; Var V:LongInt):Boolean;
Var
 I,D:Integer;
 C:Char;
Begin
 V:=0; ParseHex:=False; If S='' Then Exit;
 If S[1]='$' Then Delete(S,1,1);
 If (Length(S)>1) And (S[1]='0') And ((S[2]='x') Or (S[2]='X')) Then Delete(S,1,2);
 If (S<>'') And ((S[Length(S)]='h') Or (S[Length(S)]='H')) Then Delete(S,Length(S),1);
 If S='' Then Exit;
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If (C>='0') And (C<='9') Then D:=Ord(C)-48 Else If (UpCase(C)>='A') And (UpCase(C)<='F')
  Then D:=Ord(UpCase(C))-55 Else Exit;
  V:=V*16+D;
 End; ParseHex:=True;
End;

Procedure Help;Begin
 WriteLn('DISNT ',VERSION,' - Desassembleur et analyseur Windows NT PE/COFF');
 WriteLn;
 WriteLn('Syntaxe');
 WriteLn('  DISNT [options] fichier.exe');
 WriteLn('  DISNT [options] pilote.sys');
 WriteLn;
 WriteLn('Sans /O, le resultat est place dans un fichier portant le meme nom');
 WriteLn('que l''entree, avec l''extension .ASM. Les adresses sont hexadecimales');
 WriteLn('(exemples acceptes: 140001000, 0x1000, $1000 ou 1000h).');
 WriteLn;
 WriteLn('Fichiers de sortie');
 WriteLn('  /O:fichier       Choisit le fichier principal de desassemblage.');
 WriteLn('  /LIST:fichier    Duplique le rapport detaille dans ce fichier.');
 WriteLn('                   Sans nom, DISNT emploie <sortie>.LST.');
 WriteLn('  /MAP:fichier     Produit une carte des sections, imports, exports et');
 WriteLn('                   relocations. Sans nom: <sortie>.MAP.');
 WriteLn;
 WriteLn('Architecture et syntaxe');
 WriteLn('  /CPU:AUTO        Utilise le champ Machine du fichier PE (defaut).');
 WriteLn('  /CPU:X86         Demande une interpretation Intel 32 bits.');
 WriteLn('  /CPU:X64         Demande une interpretation AMD64/x86-64.');
 WriteLn('  /CPU:ARM         Selectionne le profil ARM 32 bits.');
 WriteLn('  /CPU:ARM64       Selectionne le profil ARM 64 bits.');
 WriteLn('                   ARM est analyse comme PE et conserve comme donnees.');
 WriteLn('  /ASM:MASM        Syntaxe assembleur Microsoft (defaut).');
 WriteLn('  /ASM:NASM        Demande une presentation de type NASM.');
 WriteLn;
 WriteLn('Analyse du format PE/COFF');
 WriteLn('  /PE              Active l''analyse generale de l''image PE/COFF.');
 WriteLn('  /HDR             Affiche les en-tetes DOS, PE, COFF et optionnel.');
 WriteLn('  /SECTIONS        Enumere chaque section avec RVA, tailles virtuelle et');
 WriteLn('                   brute, position dans le fichier et attributs.');
 WriteLn('  /IMPORTS         Affiche chaque DLL et fonction ou ordinal importe.');
 WriteLn('  /EXPORTS         Affiche les fonctions exportees, leur nom et leur RVA.');
 WriteLn('  /RELOC           Analyse les blocs de relocations de base (.reloc).');
 WriteLn('  /RESOURCES       Affiche RVA et taille du repertoire de ressources.');
 WriteLn('  /EXCEPT          Affiche RVA et taille des donnees d''exception .pdata.');
 WriteLn;
 WriteLn('Point de depart et adressage');
 WriteLn('  /ENTRY           Desassemble au plus 4096 octets depuis le point');
 WriteLn('                   d''entree, au lieu de toutes les sections code.');
 WriteLn('  /RVA:adresse     Commence a cette adresse relative a l''image et limite');
 WriteLn('                   la passe de desassemblage a 4096 octets.');
 WriteLn('  /VA:adresse      Comme /RVA, mais avec une adresse virtuelle absolue;');
 WriteLn('                   l''ImageBase est automatiquement soustraite.');
 WriteLn('  /BASE:adresse    Remplace l''ImageBase du PE dans les adresses affichees.');
 WriteLn;
 WriteLn('Symboles, donnees et presentation');
 WriteLn('  /PDB:fichier     Inscrit le PDB associe dans le rapport. Cette version');
 WriteLn('                   ne decode pas encore le format PDB.');
 WriteLn('  /SYMBOLS         Active les noms symboliques reconnus.');
 WriteLn('  /DEMANGLE        Demande la simplification des noms C/C++ decores.');
 WriteLn('  /XREF            Active les references croisees code/donnees.');
 WriteLn('  /STRINGS         Recherche les chaines ASCII de 5 caracteres et plus.');
 WriteLn('  /UNICODE         Ajoute la recherche des chaines UTF-16LE.');
 WriteLn('  /DATA            Demande de distinguer code et zones de donnees.');
 WriteLn('  /COMMENTS        Demande des commentaires automatiques.');
 WriteLn('  /BYTES           Affiche les octets machine (active par defaut).');
 WriteLn('  /ADDR            Affiche les adresses virtuelles (active par defaut).');
 WriteLn;
 WriteLn('Profils Windows NT');
 WriteLn('  /KERNEL          Profil noyau: imports, exports, NTAPI et SYSCALL.');
 WriteLn('  /DRIVER          Profil pilote: imports, NTAPI et DriverEntry.');
 WriteLn('  /NATIVE          Signale une application du sous-systeme Native NT.');
 WriteLn('  /HAL             Recherche les references aux services de la HAL.');
 WriteLn('  /NTAPI           Identifie les fonctions de l''API Native NT.');
 WriteLn('  /SYSCALL         Recherche les sequences d''appel systeme NT.');
 WriteLn('  /DRIVERENTRY     Nomme le point d''entree PE DriverEntry.');
 WriteLn('  /DISPATCH        Recherche les initialisations de MajorFunction[].');
 WriteLn('  /UNLOAD          Recherche l''affectation de DriverUnload.');
 WriteLn('  /IRP             Annote les manipulations d''IRP et IRP_MJ_*.');
 WriteLn('  /IO              Filtre les API du gestionnaire d''entrees/sorties.');
 WriteLn('  /MM              Filtre les API du gestionnaire de memoire.');
 WriteLn('  /OB              Filtre les API de l''Object Manager.');
 WriteLn('  /PS              Filtre les API de gestion des processus et threads.');
 WriteLn('  /CM              Filtre les API du Configuration Manager.');
 WriteLn('  /SE              Filtre les API du Security Reference Monitor.');
 WriteLn('  /KE              Filtre les API du Kernel Executive.');
 WriteLn('  /EX              Filtre les API de l''Executive.');
 WriteLn('  /KD              Recherche les references au debogueur noyau.');
 WriteLn('  /WDM             Active les reconnaissances propres aux pilotes WDM.');
 WriteLn('  /WDF             Recherche les imports et constructions KMDF/UMDF.');
 WriteLn('  /STRUCT          Demande l''annotation des acces aux structures NT.');
 WriteLn('  /NTVER:version   Definitions NT: AUTO, 3.51, 4.0, 2000, XP, 2003,');
 WriteLn('                   VISTA, 7, 8, 8.1, 10 ou 11 (defaut: AUTO).');
 WriteLn;
 WriteLn('Controle de la commande');
 WriteLn('  /V               Affiche le chargement et la progression.');
 WriteLn('  /Q               Supprime les messages de progression.');
 WriteLn('  /?                Affiche cette aide et retourne le code 0.');
 WriteLn;
 WriteLn('Exemples');
 WriteLn('  DISNT NTOSKRNL.EXE /KERNEL /EXPORTS /SYSCALL /O:NTOSKRNL.ASM');
 WriteLn('  DISNT DISK.SYS /DRIVER /DRIVERENTRY /IRP /XREF');
 WriteLn('  DISNT NTDLL.DLL /ENTRY /BYTES /ADDR /LIST:NTDLL.LST');
 WriteLn('  DISNT APP.EXE /RVA:1000 /STRINGS /MAP:APP.MAP /ASM:NASM');
 Halt(0);
End;

Procedure SetProfile(N:TString);Begin
 If N='KERNEL' Then Begin
  OptKernel:=True; OptExports:=True; OptImports:=True; OptNTAPI:=True; OptSyscall:=True;
 End;
 If N='DRIVER' Then Begin
  OptDriver:=True; OptImports:=True; OptDriverEntry:=True; OptNTAPI:=True;
 End;
End;

Procedure ParseArgs;
Var
 I,P:Integer;
 A,N,V:TString;
 X:LongInt;
 Got:Boolean;
Begin
 InName:=''; OutName:=''; ListName:=''; MapName:=''; PDBName:=''; CPUForce:='AUTO';
 AsmStyle:='MASM'; NTVersion:='AUTO'; Got:=False;
 OptAddr:=True; OptBytes:=True; OptHdr:=True; OptSections:=True;
 I:=1;
 While I<=ParamCount Do Begin
  A:=ParamStr(I); N:=UpStr(A);
  If (N='/?') Or (N='-?') Or (N='--HELP') Then Help;
  If (A<>'') And ((A[1]='/') Or (A[1]='-')) Then Begin
   Delete(N,1,1); P:=Pos(':',N); If P=0 Then Begin
    V:='';
   End Else
   Begin
    V:=Copy(A,P+2,255); Delete(N,P,255);
   End;
   If (N='O') Then OutName:=V Else If N='LIST' Then Begin
    ListName:=V; UseList:=True;
   End Else
   If N='MAP' Then Begin
    MapName:=V; UseMap:=True;
   End Else If N='CPU' Then CPUForce:=UpStr(V) Else
   If N='ASM' Then AsmStyle:=UpStr(V) Else If N='PDB' Then PDBName:=V Else If N=
   'NTVER' Then NTVersion:=UpStr(V) Else
   If N='BASE' Then Begin
    If Not ParseHex(V,X) Then Begin
     WriteLn('Adresse /BASE incorrecte.'); Halt(1);
    End; ForcedBaseLo:=X; HasForcedBase:=True;
   End Else
   If N='RVA' Then Begin
    If Not ParseHex(V,X) Then Begin
     WriteLn('Adresse /RVA incorrecte.'); Halt(1);
    End; StartRVA:=X; HasStartRVA:=True;
   End Else
   If N='VA' Then Begin
    If Not ParseHex(V,X) Then Begin
     WriteLn('Adresse /VA incorrecte.'); Halt(1);
    End; StartVA:=X; HasStartVA:=True;
   End Else
   If (N='PE') Or (N='HDR') Then OptHdr:=True Else If N='SECTIONS' Then OptSections:=
   True Else
   If N='IMPORTS' Then OptImports:=True Else If N='EXPORTS' Then OptExports:=
   True Else If N='RELOC' Then OptReloc:=True Else
   If N='RESOURCES' Then OptResources:=True Else If N='EXCEPT' Then OptExcept:=
   True Else If N='ENTRY' Then OptEntry:=True Else
   If N='KERNEL' Then SetProfile(N) Else If N='DRIVER' Then SetProfile(N) Else If N=
   'HAL' Then OptHAL:=True Else
   If N='NATIVE' Then OptNative:=True Else If N='SYSCALL' Then OptSyscall:=True Else If N=
   'NTAPI' Then OptNTAPI:=True Else
   If N='DRIVERENTRY' Then OptDriverEntry:=True Else If N='DISPATCH' Then OptDispatch:=
   True Else If N='UNLOAD' Then OptUnload:=True Else
   If N='IRP' Then OptIRP:=True Else If N='IO' Then OptIO:=True Else If N=
   'MM' Then OptMM:=True Else If N='OB' Then OptOB:=True Else
   If N='PS' Then OptPS:=True Else If N='CM' Then OptCM:=True Else If N='SE' Then OptSE:=
   True Else If N='KE' Then OptKE:=True Else
   If N='EX' Then OptEX:=True Else If N='KD' Then OptKD:=True Else If N=
   'WDM' Then OptWDM:=True Else If N='WDF' Then OptWDF:=True Else
   If N='STRUCT' Then OptStruct:=True Else If N='SYMBOLS' Then OptSymbols:=True Else If N=
   'DEMANGLE' Then OptDemangle:=True Else
   If N='XREF' Then OptXRef:=True Else If N='STRINGS' Then OptStrings:=True Else If N=
   'UNICODE' Then Begin
    OptUnicode:=True; OptStrings:=True;
   End Else
   If N='DATA' Then OptData:=True Else If N='COMMENTS' Then OptComments:=True Else If N=
   'BYTES' Then OptBytes:=True Else
   If N='ADDR' Then OptAddr:=True Else If N='V' Then OptVerbose:=True Else If N=
   'Q' Then OptQuiet:=True Else
   Begin
    WriteLn('Option inconnue: ',A); Halt(1);
   End;
  End Else If Not Got Then Begin
   InName:=A; Got:=True;
  End Else
  Begin
   WriteLn('Fichier surnumeraire: ',A); Halt(1);
  End;
  Inc(I);
 End;
 If InName='' Then Begin
  WriteLn('Erreur: aucun fichier. Utilisez DISNT /?'); Halt(1);
 End;
 If OutName='' Then Begin
  OutName:=FExpand(InName); P:=Length(OutName);
  While (P>0) And (OutName[P]<>'.') And (OutName[P]<>'\') Do Dec(P);
  If (P>0) And (OutName[P]='.') Then Delete(OutName,P,255); OutName:=OutName+'.ASM';
 End;
End;

Function LoadFile:Boolean;
Var
 F:File;
 R:Word;
 Posn,Want:LongInt;
 E:Integer;
Begin
 LoadFile:=False; Assign(F,InName); Reset(F,1); E:=IOResult; If E<>0 Then Begin
  If OptVerbose Then WriteLn('Erreur ouverture: ',E); Exit;
 End; DataSize:=FileSize(F);
 If OptVerbose Then WriteLn('[V] Taille du fichier: ',DataSize,' octets; limite: ',
 MAX_FILE_SIZE,'.');
 If (DataSize<64) Or (DataSize>MAX_FILE_SIZE) Then Begin
  Close(F); Exit;
 End; GetMem(Data,DataSize); Posn:=0;
 While Posn<DataSize Do Begin
  Want:=DataSize-Posn; If Want>32767 Then Want:=32767;
  BlockRead(F,Data^[Posn],Word(Want),R); E:=IOResult; If (E<>0) Or (R=0) Then Break;
  Inc(Posn,R);
 End;
 Close(F); If Posn<>DataSize Then Begin
  FreeMem(Data,DataSize); Exit;
 End; LoadFile:=True;
End;

Function MachineName:TString;Begin
 Case Machine Of $14C:MachineName:='Intel 80386'; $8664:MachineName:='AMD64';
 $1C0,$1C4:MachineName:='ARM'; $AA64:MachineName:='ARM64';
 Else MachineName:='Inconnue ($'+Hex4(Machine)+')';
End;
End;

Function RVAOfs(R:LongInt):LongInt;
Var
 I:Integer;
 Z:LongInt;
Begin
 If (R>=0) And (R<U32(OptOfs+60)) Then Begin
  RVAOfs:=R; Exit;
 End;
 For I:=0 To SectionCount-1 Do Begin
  Z:=Sections[I].VSize; If Sections[I].RawSize>Z Then Z:=Sections[I].RawSize;
  If (R>=Sections[I].RVA) And (R<Sections[I].RVA+Z) Then Begin
   RVAOfs:=Sections[I].RawPtr+(R-Sections[I].RVA); Exit;
  End;
 End; RVAOfs:=-1;
End;

Function ReadPE:Boolean;
Var
 I,J,DBase:Integer;
 O:LongInt;
 S:TString;
Begin
 ReadPE:=False; If (U16(0)<>$5A4D) Then Exit; PEOfs:=U32($3C);
 If (PEOfs<0) Or (PEOfs+24>=DataSize) Or (U32(PEOfs)<>$00004550) Then Exit;
 Machine:=U16(PEOfs+4); SectionCount:=U16(PEOfs+6); OptSize:=U16(PEOfs+20);
 If SectionCount>MAX_SECTIONS Then Exit;
 OptOfs:=PEOfs+24; OptMagic:=U16(OptOfs); IsPE64:=OptMagic=$20B;
 If (OptMagic<>$10B) And Not IsPE64 Then Exit;
 EntryRVA:=U32(OptOfs+16); If IsPE64 Then Begin
  ImageBaseLo:=U32(OptOfs+24); ImageBaseHi:=U32(OptOfs+28); Subsystem:=U16(OptOfs+68);
  DBase:=112;
 End
  Else
 Begin
  ImageBaseLo:=U32(OptOfs+28); ImageBaseHi:=0; Subsystem:=U16(OptOfs+68); DBase:=96;
 End;
 SizeOfImage:=U32(OptOfs+56);
 For I:=0 To 15 Do Begin
  DirRVA[I]:=U32(OptOfs+DBase+I*8); DirSize[I]:=U32(OptOfs+DBase+I*8+4);
 End;
 O:=OptOfs+OptSize;
 For I:=0 To SectionCount-1 Do Begin
  S:='';
  For J:=0 To 7 Do If Data^[O+J]<>0 Then S:=S+Chr(Data^[O+J]); Sections[I].Name:=S;
  Sections[I].VSize:=U32(O+8); Sections[I].RVA:=U32(O+12); Sections[I].RawSize:=U32(O+16);
  Sections[I].RawPtr:=U32(O+20); Sections[I].Characteristics:=U32(O+36); Inc(O,40);
 End; ReadPE:=True;
End;

Procedure ReportHeaders;
Var
 I:Integer;
 Base:TString;
Begin
 If IsPE64 Then Base:=Hex8(ImageBaseHi)+Hex8(ImageBaseLo) Else Base:=Hex8(ImageBaseLo);
 Put('; DISNT '+VERSION+' - Windows NT PE/COFF'); Put('; Fichier          : '+InName);
 If IsPE64 Then Put('; Format           : PE32+') Else Put('; Format           : PE32');
 Put('; Machine          : '+MachineName); Put('; Image Base       : '+Base);
 Put('; Taille image     : '+Hex8(SizeOfImage));
 Put('; Point d''entree   : RVA '+Hex8(EntryRVA));
 Put('; Sous-systeme    : '+Hex4(Subsystem));
 Put('; Sections         : '+Hex4(SectionCount)); Put('; Version NT       : '+NTVersion);
 Put('; Profil           : '+CPUForce+' / '+AsmStyle);
 If OptKernel Then Put('; Analyse noyau NT activee.') Else If OptDriver Then Put(
 '; Analyse pilote NT activee.');
 If OptNative Or (Subsystem=1) Then Put('; Sous-systeme Native NT detecte.');
 If PDBName<>'' Then Put('; PDB demande      : '+PDBName+
 ' (lecture de types PDB non disponible)');
 If OptSections Then Begin
  Put(''); Put('; Sections:');
  For I:=0 To SectionCount-1 Do Begin
   Put(';   '+Sections[I].Name+' RVA='+Hex8(Sections[I].RVA)+' VSIZE='+Hex8(
   Sections[I].VSize)+' RAW='+Hex8(Sections[I].RawPtr)+'/'+Hex8(Sections[I].RawSize));
   PutMap(Sections[I].Name+' RVA '+Hex8(Sections[I].RVA)+' SIZE '+Hex8(Sections[I].VSize))
   ;
  End;
 End;
End;

Procedure ReportImports;
Var
 O,N,T,NameO,Thunk,Val,Step:LongInt;
 DLL,Fn:TString;
 Ordinal:Boolean;
Begin
 If DirRVA[1]=0 Then Begin
  Put('; Aucune importation.'); Exit;
 End; O:=RVAOfs(DirRVA[1]); If O<0 Then Exit; Put(''); Put('; Importations:');
 While (O+19<DataSize) And (U32(O+12)<>0) Do Begin
  DLL:=CStr(RVAOfs(U32(O+12))); Put('; ['+DLL+']'); Thunk:=U32(O);
  If Thunk=0 Then Thunk:=U32(O+16); T:=RVAOfs(Thunk); If IsPE64 Then Step:=8 Else Step:=4;
  N:=0;
  While (T>=0) And (T+Step<=DataSize) And (N<4096) Do Begin
   Val:=U32(T); If Val=0 Then Break; Ordinal:=False;
   If IsPE64 Then Ordinal:=(U32(T+4) And LongInt($80000000))<>0 Else Ordinal:=(
   Val And LongInt($80000000))<>0;
   If Ordinal Then Fn:='#'+Hex4(Word(Val And $FFFF)) Else
   Begin
    NameO:=RVAOfs(Val); If NameO>=0 Then Fn:=CStr(NameO+2) Else Fn:='?';
   End;
   Put(';   '+DLL+'!'+Fn); PutMap('IMPORT '+DLL+'!'+Fn); Inc(T,Step); Inc(N);
  End; Inc(O,20);
 End;
End;

Procedure ReportExports;
Var
 O,Names,Ords,Funcs,NO,FO:LongInt;
 I,C:LongInt;
 N:TString;
 Ord:Word;
Begin
 If DirRVA[0]=0 Then Begin
  Put('; Aucune exportation.'); Exit;
 End; O:=RVAOfs(DirRVA[0]); If O<0 Then Exit; C:=U32(O+24); Names:=RVAOfs(U32(O+32));
 Ords:=RVAOfs(U32(O+36)); Funcs:=RVAOfs(U32(O+28)); Put(''); Put('; Exportations:');
 For I:=0 To C-1 Do Begin
  NO:=RVAOfs(U32(Names+I*4)); N:=CStr(NO); Ord:=U16(Ords+I*2);
  FO:=U32(Funcs+LongInt(Ord)*4); Put(';   '+N+' RVA '+Hex8(FO));
  PutMap('EXPORT '+Hex8(FO)+' '+N);
 End;
End;

Procedure ReportRelocs;
Var
 O,E,BSize,Page,C,I:LongInt;
 W:Word;
Begin
 O:=RVAOfs(DirRVA[5]); E:=O+DirSize[5]; If (O<0) Or (DirRVA[5]=0) Then Begin
  Put('; Aucune relocalisation.'); Exit;
 End; Put(''); Put('; Relocalisations:');
 While (O+8<=E) And (O+8<=DataSize) Do Begin
  Page:=U32(O); BSize:=U32(O+4); If BSize<8 Then Break; C:=(BSize-8) Div 2;
  Put(';   Page RVA '+Hex8(Page)+' : '+Hex8(C)+' entree(s)');
  For I:=0 To C-1 Do Begin
   W:=U16(O+8+I*2);
   If (W Shr 12)<>0 Then PutMap('RELOC '+Hex8(Page+(W And $FFF))+' TYPE '+Hex2(W Shr 12));
  End; Inc(O,BSize);
 End;
End;

Procedure ReportStrings;
Var
 I,J:LongInt;
 S:TString;
Begin
 Put(''); Put('; Chaines:'); I:=0;
 While I<DataSize Do Begin
  If (Data^[I]>=32) And (Data^[I]<127) Then Begin
   J:=I; S:='';
   While (J<DataSize) And (Data^[J]>=32) And (Data^[J]<127) And (Length(S)<200) Do Begin
    S:=S+Chr(Data^[J]); Inc(J);
   End;
   If Length(S)>=5 Then Put('; '+Hex8(I)+'  "'+S+'"'); If J>I Then I:=J Else Inc(I);
  End Else Inc(I);
 End;
End;

Function RegName(N:Byte; Wide:Boolean):TString;
Const
 R32:Array[0..7] Of String[3]=('eax','ecx','edx','ebx','esp','ebp','esi','edi');
 R64:Array[0..7] Of String[3]=('rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi');
Begin
 If Wide Then RegName:=R64[N And 7] Else RegName:=R32[N And 7];
End;

Function ModRMSize(O,Limit:LongInt):Byte;
Var
 M,MD,RM,SIB:Byte;
 N:Byte;
Begin
 If O>=Limit Then Begin
  ModRMSize:=0; Exit;
 End;
 M:=Data^[O]; MD:=M Shr 6; RM:=M And 7; N:=1;
 If (MD<>3) And (RM=4) Then Begin
  If O+N>=Limit Then Begin
   ModRMSize:=N; Exit;
  End; SIB:=Data^[O+N]; Inc(N); If (MD=0) And ((SIB And 7)=5) Then Inc(N,4);
 End;
 If (MD=0) And (RM=5) Then Inc(N,4) Else If MD=1 Then Inc(N) Else If MD=2 Then Inc(N,4);
 If O+N>Limit Then N:=Limit-O; ModRMSize:=N;
End;

Function DecodeX86(O,Limit:LongInt; Var L:Byte):TString;
Var
 B,Op,ModRM,Modu,Rm,Rg,MSize:Byte;
 P:LongInt;
 Wide:Boolean;
 A,Bs:TString;
Begin
 L:=1; If O>=Limit Then Begin
  DecodeX86:=''; Exit;
 End; P:=O; B:=Data^[P]; Wide:=False;
 While (B=$66) Or (B=$67) Or (B=$F2) Or (B=$F3) Or ((B>=$40) And (B<=$4F) And IsPE64)
 Do Begin
  If (B And 8)<>0 Then Wide:=True; Inc(P); If P>=Limit Then Break; B:=Data^[P];
 End;
 Op:=B; L:=P-O+1; A:=''; Bs:='';
 Case Op Of
 $90:DecodeX86:='nop'; $C3:DecodeX86:='ret'; $CC:DecodeX86:='int 3';
 $50..$57:DecodeX86:='push '+RegName(Op-$50,Wide);
 $58..$5F:DecodeX86:='pop '+RegName(Op-$58,Wide);
 $68:
 Begin
  If P+4<Limit Then Begin
   DecodeX86:='push '+Hex8(U32(P+1))+'h'; Inc(L,4);
  End Else DecodeX86:='db '+Hex2(Op)+'h';
 End;
 $6A:
 Begin
  If P+1<Limit Then Begin
   DecodeX86:='push '+Hex2(Data^[P+1])+'h'; Inc(L);
  End Else DecodeX86:='db 6Ah';
 End;
 $E8,$E9:
 Begin
  If P+4<Limit Then Begin
   If Op=$E8 Then A:='call ' Else A:='jmp ';
   DecodeX86:=A+Hex8(EntryRVA+(O-RVAOfs(EntryRVA))+L+4+U32(P+1))+'h'; Inc(L,4);
  End Else DecodeX86:='db '+Hex2(Op)+'h';
 End;
 $70..$7F:
 Begin
  If P+1<Limit Then Begin
   DecodeX86:='jcc'+HexN(Op And 15,1)+' '+Hex2(Data^[P+1])+'h'; Inc(L);
  End Else DecodeX86:='db '+Hex2(Op)+'h';
 End;
 $EB:
 Begin
  If P+1<Limit Then Begin
   DecodeX86:='jmp short '+Hex2(Data^[P+1])+'h'; Inc(L);
  End Else DecodeX86:='db EBh';
 End;
 $B8..$BF:
 Begin
  If P+4<Limit Then Begin
   DecodeX86:='mov '+RegName(Op-$B8,Wide)+','+Hex8(U32(P+1))+'h'; Inc(L,4);
  End Else DecodeX86:='db '+Hex2(Op)+'h';
 End;
 $0F:
 Begin
  If P+1>=Limit Then DecodeX86:='db 0Fh' Else If (Data^[P+1]>=$80) And (Data^[P+1]<=$8F)
  And (P+5<Limit) Then Begin
   DecodeX86:='jcc'+HexN(Data^[P+1] And 15,1)+' '+Hex8(U32(P+2))+'h'; Inc(L,5);
  End
   Else
  Begin
   DecodeX86:='db 0Fh';
  End;
 End;
 $8B,$89,$8D,$31,$33,$85,$83:
 Begin
  If P+1>=Limit Then Begin
   DecodeX86:='db '+Hex2(Op)+'h'; Exit;
  End; ModRM:=Data^[P+1]; Modu:=ModRM Shr 6; Rg:=(ModRM Shr 3) And 7; Rm:=ModRM And 7;
  MSize:=ModRMSize(P+1,Limit); Inc(L,MSize); A:=RegName(Rg,Wide);
  If Modu=3 Then Bs:=RegName(Rm,Wide) Else Bs:='[mem]';
  Case Op Of $8B:DecodeX86:='mov '+A+','+Bs; $89:DecodeX86:='mov '+Bs+','+A;
  $8D:DecodeX86:='lea '+A+','+Bs; $31:DecodeX86:='xor '+Bs+','+A;
  $33:DecodeX86:='xor '+A+','+Bs; $85:DecodeX86:='test '+Bs+','+A;
  $83:
  Begin
   If P+1+MSize<Limit Then Begin
    Case Rg Of 0:A:='add '; 1:A:='or '; 4:A:='and '; 5:A:='sub '; 6:A:='xor ';
    7:A:='cmp '; Else A:='op83 ';
   End; DecodeX86:=A+Bs+','+Hex2(Data^[P+1+MSize])+'h'; Inc(L);
  End Else DecodeX86:='db 83h';
 End;
End;
End;
Else DecodeX86:='db '+Hex2(Op)+'h';
End;
End;

Procedure Disassemble;
Var
 I:Integer;
 O,E,R:LongInt;
 L,J:Byte;
 S,Raw,Addr:TString;
 IsX86:Boolean;
Begin
 IsX86:=(Machine=$14C) Or (Machine=$8664); If Not IsX86 Then Begin
  Put('');
  Put('; Desassemblage non disponible pour '+MachineName+'; donnees conservees.'); Exit;
 End;
 Put(''); Put('.code');
 For I:=0 To SectionCount-1 Do
  If (Sections[I].Characteristics And IMAGE_SCN_MEM_EXECUTE)<>0 Then Begin
   O:=Sections[I].RawPtr; E:=O+Sections[I].RawSize; If E>DataSize Then E:=DataSize;
  If HasStartRVA Then Begin
   O:=RVAOfs(StartRVA); E:=O+4096; If E>DataSize Then E:=DataSize;
  End Else If OptEntry Then Begin
   O:=RVAOfs(EntryRVA); E:=O+4096; If E>DataSize Then E:=DataSize;
  End;
  If O<0 Then Continue; Put(''); Put('; section '+Sections[I].Name);
  If (EntryRVA>=Sections[I].RVA) And (EntryRVA<Sections[I].RVA+Sections[I].VSize)
  Then Put('EntryPoint:');
  While O<E Do Begin
   R:=Sections[I].RVA+(O-Sections[I].RawPtr); S:=DecodeX86(O,E,L); If L=0 Then L:=1;
   Raw:=''; If OptBytes Then Begin
    For J:=0 To L-1 Do If O+J<E Then Raw:=Raw+Hex2(Data^[O+J])+' ';
    While Length(Raw)<25 Do Raw:=Raw+' ';
   End;
   Addr:=''; If OptAddr Then Begin
    If IsPE64 Then Addr:=Hex8(ImageBaseHi)+Hex8(ImageBaseLo+R) Else Addr:=Hex8(
    ImageBaseLo+R); Addr:=Addr+'  ';
   End; Put(Addr+Raw+S); Inc(O,L);
  End; If HasStartRVA Or OptEntry Then Break;
 End;
End;

Var
 RC:Integer;

BEGIN
 ParseArgs; If Not OptQuiet Then WriteLn('DISNT ',VERSION,' - analyse de ',InName);
 If Not LoadFile Then Begin
  WriteLn('Erreur: chargement impossible ou fichier trop grand.'); Halt(2);
 End;
 If Not ReadPE Then Begin
  WriteLn('Erreur: ce fichier n''est pas une image PE32/PE32+ valide.');
  FreeMem(Data,DataSize); Halt(3);
 End;
 If HasForcedBase Then Begin
  ImageBaseLo:=ForcedBaseLo; ImageBaseHi:=0;
 End;
 If HasStartVA Then Begin
  StartRVA:=StartVA-ImageBaseLo; HasStartRVA:=True;
 End;
 Assign(OutF,OutName); Rewrite(OutF); RC:=IOResult; If RC<>0 Then Begin
  WriteLn('Erreur: impossible de creer ',OutName); FreeMem(Data,DataSize); Halt(4);
 End;
 If UseList Then Begin
  If ListName='' Then ListName:=OutName+'.LST'; Assign(ListF,ListName); Rewrite(ListF);
  If IOResult<>0 Then UseList:=False;
 End;
 If UseMap Then Begin
  If MapName='' Then MapName:=OutName+'.MAP'; Assign(MapF,MapName); Rewrite(MapF);
  If IOResult<>0 Then UseMap:=False;
 End;
 ReportHeaders; If OptImports Then ReportImports; If OptExports Then ReportExports;
 If OptReloc Then ReportRelocs;
 If OptResources Then Put('; Ressources: RVA '+Hex8(DirRVA[2])+' taille '+Hex8(DirSize[2])
 );
 If OptExcept Then Put('; Exceptions: RVA '+Hex8(DirRVA[3])+' taille '+Hex8(DirSize[3]));
 If OptDriverEntry Then Put('; DriverEntry suppose: RVA '+Hex8(EntryRVA));
 If OptStrings Then ReportStrings; Disassemble;
 Close(OutF); If UseList Then Close(ListF); If UseMap Then Close(MapF);
 FreeMem(Data,DataSize);
 If Not OptQuiet Then WriteLn('Sortie ecrite dans ',OutName);
END.
