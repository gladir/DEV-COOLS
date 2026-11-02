{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2
  @description: Clone de l'application Devpac
}

(* ======================================================================
  DEVPAC.PAS - Clone de HiSoft Devpac (Atari ST / Commodore Amiga)

  Environnement de developpement 68000 en mode graphique, imitant le
  bureau GEM de l'Atari ST : barre de menus (Desk, File, Search, Options,
  Program), fenetre d'edition, boites de dialogue et selecteur de fichiers.

  Tout est contenu dans ce seul fichier (aucune unite ni fichier
  d'inclusion supplementaire) :
    - editeur de texte plein ecran (blocs, recherche, remplacement),
    - assembleur macro GenST/GenAm (68000, macros, conditionnels, REPT,
      INCLUDE, sections TEXT/DATA/BSS, sortie GEMDOS .PRG ou Amiga Hunk),
    - desassembleur et moniteur/debogueur MonST/MonAm (registres,
      desassemblage, memoire, points d'arret, execution pas a pas),
    - emulateur Motorola 68000 integre avec un TOS simplifie
      (GEMDOS dont Pexec, BIOS, XBIOS, Line-A, terminal VT52, ecran
      monochrome 640x400) et un GEM complet reimplemente :
        * VDI : stations virtuelles, attributs, lignes, polylignes,
          marqueurs, polygones, arcs, ellipses, secteurs, rectangles
          arrondis, remplissage (motifs, hachures, motifs utilisateur,
          remplissage par germe), texte (tailles, effets, rotation,
          alignement), copies raster (vro/vrt_cpyfm), requetes,
          sequences d'echappement du curseur ;
        * AES : applications, evenements (clavier, souris, rectangles,
          messages, minuterie, double-clic), barre de menus deroulants,
          gestionnaire de fenetres (cadres, ascenseurs, deplacement,
          taille, listes de rectangles, redessins WM_REDRAW), objets
          (tous les types, edition de champs, icones, images, routines
          utilisateur), formulaires (form_do, form_alert, form_dial),
          fichiers ressources .RSC (rsrc_load, rsrc_gaddr...), graf_*,
          selecteur de fichiers, shell (shel_get/put, envrn, rdef/wdef),
          presse-papiers (scrp_read/write/clear), menus deroulants
          independants (menu_popup) et sous-menus attaches (menu_attach),
          enregistrement et relecture d'evenements (appl_trecord/tplay),
          graf_slidebox, routines utilisateur vex_motv/butv/curv/timv ;
        * accessoires de bureau (fichiers .ACC) en multitache cooperatif ;
        * fils lances par Pexec : chacun a son propre contexte AES (ap_id,
          menus, fenetres, ressources), nettoye et restitue a sa fin ;
        * peripheriques : lecteurs de disquettes A:..D: sur des images .ST
          (Floprd, Flopwr, Flopfmt, Rwabs, Getbpb, Protobt...), port serie
          (AUX.IN / AUX.OUT), MIDI (MIDI.IN / MIDI.OUT), imprimante
          (PRINTER.OUT), tables clavier, Iorec, Rsconf, Giaccess, Random ;
      ainsi qu'un AmigaOS simplifie (exec.library / dos.library).

  Langue : francais par defaut ; LANGUAGE=EN pour l'anglais ;
           LANGUAGE=GR pour l'allemand.

  Syntaxe : DEVPAC [options] [fichier.S ...]      (voir DEVPAC /?)
  Disquettes : DISKA.ST .. DISKD.ST du dossier courant, ou /FLA:image ...
====================================================================== *)

Program DEVPAC;

{$A-}
{$I-}
{$R-}
{$Q-}
{$IFDEF FPC}
 {$H-}
{$ELSE}
 {$M 32768,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      {$IFDEF UNIX}cthreads,{$ENDIF}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      DOS,Crt,Graph
     {$ENDIF};

{ ====================================================================== }
{                              CONSTANTES                                }
{ ====================================================================== }

Const
 VERSION_TEXT = '2.00';
 SCR_W        = 640;
 SCR_H        = 480;
 MENU_H       = 19;
 INK          = 0;
 PAPER        = 15;
 LINE_H       = 10;        { hauteur d'une ligne de texte de l'editeur }

 MAXLN        = 16000;     { lignes maximum du fichier edite }
 MAXERR       = 100;       { erreurs d'assemblage memorisees }

 { Codes de touches : caractere = ord ; touche etendue = 256 + code }
 K_ESC    = 27;
 K_ENTER  = 13;
 K_BKSP   = 8;
 K_TAB    = 9;
 K_UP     = 328;
 K_DOWN   = 336;
 K_LEFT   = 331;
 K_RIGHT  = 333;
 K_HOME   = 327;
 K_END    = 335;
 K_PGUP   = 329;
 K_PGDN   = 337;
 K_INS    = 338;
 K_DEL    = 339;
 K_F1     = 315;
 K_F2     = 316;
 K_F3     = 317;
 K_F4     = 318;
 K_F5     = 319;
 K_F6     = 320;
 K_F7     = 321;
 K_F8     = 322;
 K_F9     = 323;
 K_F10    = 324;
 K_CLEFT  = 371;
 K_CRIGHT = 372;
 K_CEND   = 373;
 K_CHOME  = 375;
 K_CPGUP  = 388;
 K_CPGDN  = 374;
 K_STAB   = 271;

 { Codes de balayage (scan codes) des touches Alt-A .. Alt-Z }
 AltScan : Array[0..25] Of Byte =
  (30,48,46,32,18,33,34,35,23,36,37,38,50,49,24,25,16,19,31,20,22,47,17,45,21,44);

{ ====================================================================== }
{                       LANGUE / UTILITAIRES                             }
{ ====================================================================== }

Var
 Lang      : Integer;     { 0 anglais, 1 francais, 2 allemand }
 BatchMode : Boolean;     { mode console (sans interface graphique) }
 AmigaMode : Boolean;     { False = Atari ST (defaut), True = Amiga }
 GfxOn     : Boolean;     { le mode graphique est actif }
 ConOut    : Text;        { sortie standard directe (sans passer par Crt) }
 ConIn     : Text;        { entree standard directe }

Function T3(Const En,Fr,De: String): String;
Begin
 Case Lang Of
  0: T3:=En;
  2: T3:=De;
 Else T3:=Fr;
 End;
End;

{ 'EN~FR~DE' : extrait la partie N }
Function Part3(Const S: String; N: Integer): String;
Var I,K: Integer; R: String;
Begin
 R:='';K:=0;
 For I:=1 To Length(S) Do
  If S[I]='~' Then Inc(K) Else If K=N Then R:=R+S[I];
 If (R='') And (N<>0) Then Part3:=Part3(S,0) Else Part3:=R;
End;

Function IntStr(N: LongInt): String;
Var S: String;
Begin
 Str(N,S);
 IntStr:=S;
End;

Function Upper(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 Upper:=S;
End;

Function LowerStr(S: String): String;
Var I: Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='A') And (S[I]<='Z') Then S[I]:=Chr(Ord(S[I])+32);
 LowerStr:=S;
End;

Function Min2(A,B: LongInt): LongInt;
Begin
 If A<B Then Min2:=A Else Min2:=B;
End;

Function Max2(A,B: LongInt): LongInt;
Begin
 If A>B Then Max2:=A Else Max2:=B;
End;

Function Clamp(V,A,B: LongInt): LongInt;
Begin
 If V<A Then V:=A;
 If V>B Then V:=B;
 Clamp:=V;
End;

Function PadL(Const S: String; W: Integer): String;
Var R: String;
Begin
 R:=S;
 While Length(R)<W Do R:=' '+R;
 PadL:=R;
End;

Function PadR(Const S: String; W: Integer): String;
Var R: String;
Begin
 R:=S;
 While Length(R)<W Do R:=R+' ';
 PadR:=R;
End;

Function ToInt(Const S: String): LongInt;
Var V: LongInt; C: Integer;
Begin
 Val(S,V,C);
 If C<>0 Then V:=0;
 ToInt:=V;
End;

{ Decalage logique a droite d'un LongInt (identique sous TP7 et FPC) }
Function ShrL(V: LongInt; N: Integer): LongInt;
Begin
 If N<=0 Then ShrL:=V
 Else If N>=32 Then ShrL:=0
 Else Begin
  V:=V shr N;
  If N>0 Then V:=V And ((LongInt(1) shl (32-N))-1);
  ShrL:=V;
 End;
End;

Function HexN(V: LongInt; N: Integer): String;
Const HD : String[16] = '0123456789ABCDEF';
Var S: String; I: Integer;
Begin
 S:='';
 For I:=1 To N Do Begin
  S:=HD[(V And 15)+1]+S;
  V:=ShrL(V,4);
 End;
 HexN:=S;
End;

Function Hex2(V: LongInt): String;
Begin
 Hex2:=HexN(V,2);
End;

Function Hex4(V: LongInt): String;
Begin
 Hex4:=HexN(V,4);
End;

Function Hex6(V: LongInt): String;
Begin
 Hex6:=HexN(V,6);
End;

Function Hex8(V: LongInt): String;
Begin
 Hex8:=HexN(V,8);
End;

{ Arithmetique de pointeur portable (TP7 en mode reel et FPC) }
Function PtrAdd(P: Pointer; N: LongInt): Pointer;
Begin
 {$IFDEF FPC}
 PtrAdd:=Pointer(PtrUInt(P)+PtrUInt(N));
 {$ELSE}
 PtrAdd:=Ptr(Seg(P^),Ofs(P^)+N);
 {$ENDIF}
End;

Function MsNow: LongInt;
Var H,M,S,Hs: Word;
Begin
 GetTime(H,M,S,Hs);
 MsNow:=((LongInt(H)*60+M)*60+S)*1000+LongInt(Hs)*10;
End;

Function FileExists(Const N: String): Boolean;
Var F: File;
Begin
 {$I-}
 Assign(F,N);
 Reset(F,1);
 {$I+}
 If IOResult=0 Then Begin Close(F);FileExists:=True;End Else FileExists:=False;
End;

Function ShortName(Const N: String): String;
Var I: Integer;
Begin
 I:=Length(N);
 While (I>0) And (N[I]<>'\') And (N[I]<>'/') And (N[I]<>':') Do Dec(I);
 ShortName:=Copy(N,I+1,255);
End;

Function PathOf(Const N: String): String;
Var I: Integer;
Begin
 I:=Length(N);
 While (I>0) And (N[I]<>'\') And (N[I]<>'/') And (N[I]<>':') Do Dec(I);
 PathOf:=Copy(N,1,I);
End;

Function AddExt(Const N,Ext: String): String;
Var S: String;
Begin
 S:=N;
 If Pos('.',ShortName(S))=0 Then S:=S+'.'+Ext;
 AddExt:=S;
End;

Function ChangeExt(Const N,Ext: String): String;
Var I: Integer; S: String;
Begin
 S:=N;
 I:=Length(S);
 While (I>0) And (S[I]<>'.') And (S[I]<>'\') And (S[I]<>'/') Do Dec(I);
 If (I>0) And (S[I]='.') Then S:=Copy(S,1,I-1);
 ChangeExt:=S+'.'+Ext;
End;

Function GetExt(Const N: String): String;
Var S: String; I: Integer;
Begin
 S:=ShortName(N);
 I:=Length(S);
 While (I>0) And (S[I]<>'.') Do Dec(I);
 If I>0 Then GetExt:=Upper(Copy(S,I,255)) Else GetExt:='';
End;

{ Noms specifiques a la machine cible }
Function AsmName: String;
Begin
 If AmigaMode Then AsmName:='GenAm' Else AsmName:='GenST';
End;

Function MonName: String;
Begin
 If AmigaMode Then MonName:='MonAm' Else MonName:='MonST';
End;

Function AppTitle: String;
Begin
 AppTitle:=AsmName+' 68000 Editor/Assembler from HiSoft v '+VERSION_TEXT;
End;

{ ====================================================================== }
{                  GRAPHIQUE / SOURIS (squelette)                        }
{ ====================================================================== }

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
  GfxOn:=True;
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

Type
 TEvent = Record
  { 0 rien, 1 touche, 2 bouton bas, 3 bouton haut, 4 mouvement }
  Kind : Byte;
  Key  : Word;
  X,Y,B: LongInt;
 End;

Var
 MX,MY,MB,LastB : LongInt;
 PrevMX,PrevMY  : LongInt;
 NeedDraw       : Boolean;
 Quit           : Boolean;
 IdleCount      : LongInt;

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouse;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 { Sous PtcMouse le curseur est invisible : fleche logicielle avec
   sauvegarde de l'arriere-plan }
 Var
  CurMask,CurData : Array[0..15] Of Word;
  CurHotX,CurHotY : Integer;
  CurMX,CurMY : LongInt;
  CurSaved,CurShown : Boolean;
  CurBuf : Pointer;
  CurSz  : LongInt;
  CurX,CurY : LongInt;

 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure CursorErase;
 Begin
  If CurSaved Then Begin
   PutImage(CurX,CurY,CurBuf^,NormalPut);
   FreeMem(CurBuf,CurSz);
   CurSaved:=False;
  End;
 End;

 Procedure CursorDraw(X,Y: LongInt);
 Var R,C: Integer; Bx,By: LongInt;
 Begin
  CurMX:=X;CurMY:=Y;
  Bx:=X-CurHotX;By:=Y-CurHotY;
  If Bx>SCR_W-16 Then Bx:=SCR_W-16;
  If By>SCR_H-16 Then By:=SCR_H-16;
  If Bx<0 Then Bx:=0;
  If By<0 Then By:=0;
  CursorErase;
  CurSz:=ImageSize(Bx,By,Bx+15,By+15);
  GetMem(CurBuf,CurSz);
  GetImage(Bx,By,Bx+15,By+15,CurBuf^);
  CurX:=Bx;CurY:=By;CurSaved:=True;
  For R:=0 To 15 Do
   For C:=0 To 15 Do
    If (CurMask[R] And ($8000 Shr C))<>0 Then Begin
     If (CurData[R] And ($8000 Shr C))<>0 Then PutPixel(Bx+C,By+R,Black)
     Else PutPixel(Bx+C,By+R,White);
    End;
 End;

 Procedure ShowMouse;
 Begin
  CurShown:=True;
  CursorDraw(MX,MY);
 End;

 Procedure HideMouse;
 Begin
  CursorErase;
  CurShown:=False;
 End;
{$ENDIF}

{ ====================================================================== }
{                       PRIMITIVES GRAPHIQUES                            }
{ ====================================================================== }

Const
 PatGrey : FillPatternType = ($AA,$55,$AA,$55,$AA,$55,$AA,$55);

Procedure Box(X1,Y1,X2,Y2,C: Integer);
Begin
 SetFillStyle(SolidFill,C);
 Bar(X1,Y1,X2,Y2);
End;

Procedure Frame(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 Rectangle(X1,Y1,X2,Y2);
End;

{ Le BGI peint les bits a 1 avec la couleur et les bits a 0 avec la couleur 0 :
  on inverse donc le motif et on le peint en blanc pour obtenir noir sur blanc }
Procedure PatBar(X1,Y1,X2,Y2: Integer; Const Pat: FillPatternType);
Var Q: FillPatternType; I: Integer;
Begin
 For I:=1 To 8 Do Q[I]:=Not Pat[I];
 SetFillPattern(Q,PAPER);
 Bar(X1,Y1,X2,Y2);
End;

Procedure PText(X,Y: Integer; Const S: String);
Begin
 SetColor(INK);
 OutTextXY(X,Y,S);
End;

Procedure WText(X,Y: Integer; Const S: String);
Begin
 SetColor(PAPER);
 OutTextXY(X,Y,S);
End;

Procedure GreyText(X,Y: Integer; Const S: String);
Var I,J,W: Integer;
Begin
 PText(X,Y,S);
 W:=Length(S)*8;
 For J:=0 To 7 Do
  For I:=0 To W-1 Do
   If Odd(I+J) Then
    If GetPixel(X+I,Y+J)=INK Then PutPixel(X+I,Y+J,PAPER);
End;

Function TextW(Const S: String): Integer;
Begin
 TextW:=Length(S)*8;
End;

Function InBox(X,Y,X1,Y1,X2,Y2: LongInt): Boolean;
Begin
 InBox:=(X>=X1) And (X<=X2) And (Y>=Y1) And (Y<=Y2);
End;

Procedure ArrowBox(X1,Y1,X2,Y2,Dir: Integer);
{ Dir : 1 haut, 2 bas, 3 gauche, 4 droite }
Var Pt: Array[1..3] Of PointType; CX,CY: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 CX:=(X1+X2) Div 2;CY:=(Y1+Y2) Div 2;
 Case Dir Of
  1: Begin
    Pt[1].X:=CX;Pt[1].Y:=CY-3;Pt[2].X:=CX-4;Pt[2].Y:=CY+3;Pt[3].X:=CX+4;
    Pt[3].Y:=CY+3;End;
  2: Begin
    Pt[1].X:=CX;Pt[1].Y:=CY+3;Pt[2].X:=CX-4;Pt[2].Y:=CY-3;Pt[3].X:=CX+4;
    Pt[3].Y:=CY-3;End;
  3: Begin
    Pt[1].X:=CX-3;Pt[1].Y:=CY;Pt[2].X:=CX+3;Pt[2].Y:=CY-4;Pt[3].X:=CX+3;
    Pt[3].Y:=CY+4;End;
  4: Begin
    Pt[1].X:=CX+3;Pt[1].Y:=CY;Pt[2].X:=CX-3;Pt[2].Y:=CY-4;Pt[3].X:=CX-3;
    Pt[3].Y:=CY+4;End;
 End;
 SetFillStyle(SolidFill,INK);
 SetColor(INK);
 FillPoly(3,Pt);
End;

Procedure IdleTick; Forward;

Procedure PollEvent(Var E: TEvent);
Var Ch: Char; K: Word;
Begin
 E.Kind:=0;E.Key:=0;E.X:=MX;E.Y:=MY;E.B:=MB;
 If KeyPressed Then Begin
  Ch:=ReadKey;
  If Ch=#0 Then K:=256+Ord(ReadKey) Else K:=Ord(Ch);
  E.Kind:=1;E.Key:=K;
  Exit;
 End;
 PrevMX:=MX;PrevMY:=MY;LastB:=MB;
 GetMouseState(MX,MY,MB);
 E.X:=MX;E.Y:=MY;E.B:=MB;
 If ((MB And 3)<>0) And ((LastB And 3)=0) Then E.Kind:=2
 Else If ((MB And 3)=0) And ((LastB And 3)<>0) Then E.Kind:=3
 Else If (MX<>PrevMX) Or (MY<>PrevMY) Then E.Kind:=4;
 {$IFDEF FPC}
 If (E.Kind<>0) And CurShown And ((MX<>CurMX) Or (MY<>CurMY)) Then
  CursorDraw(MX,MY);
 {$ENDIF}
 If E.Kind=0 Then Begin
  IdleTick;
  Delay(3);
 End;
End;

{ ====================================================================== }
{                    ASSEMBLEUR GenST / GenAm : NOYAU                    }
{ ====================================================================== }

Const
 HASHSZ     = 2048;
 MAXMAC     = 256;
 MAXCOND    = 64;
 MAXSRC     = 24;
 MAXRELOC   = 16000;
 MAXDEC     = 32000;
 MAXLOG     = 4000;
 CHUNKSZ    = 8192;
 NCHUNK     = 64;           { 512 Ko par section }

 SEC_TEXT   = 0;
 SEC_DATA   = 1;
 SEC_BSS    = 2;
 SEC_ABS    = -1;

Type
 PString   = ^String;
 PLineArr  = ^TLineArr;
 TLineArr  = Array[1..MAXLN] Of PString;

 PSym = ^TSym;
 TSym = Record
  Name  : String[63];
  Value : LongInt;
  Sect  : Integer;       { -1 absolu, 0 texte, 1 data, 2 bss }
  Kind  : Byte;          { 0 etiquette/EQU, 1 SET, 2 liste de registres }
  Defd  : Boolean;
  Next  : PSym;
  Pas   : Integer;       { numero de passe de la definition }
 End;

 TMacro = Record
  Name  : String[40];
  PNames: String[100];
  Body  : PLineArr;
  Count : Integer;
 End;

 TSrc = Record
  Kind    : Integer;       { 0 fichier/tampon, 1 macro, 2 REPT }
  Lines   : PLineArr;
  Count   : Integer;
  Pos     : Integer;
  Name    : String[80];
  Own     : Boolean;       { les lignes appartiennent a la source }
  Args    : Array[0..9] Of String[100];
  NArg    : Integer;
  MacId   : LongInt;
  Reps    : Integer;
  Suffix  : String[8];
  MacIdx  : Integer;
 End;

 TCond = Record
  Active : Boolean;       { la branche courante est assemblee }
  Parent : Boolean;       { le niveau parent est actif }
  Taken  : Boolean;       { une branche a deja ete prise }
 End;

 TTV = Record
  V : LongInt;
  S : Integer;
  U : Boolean;
 End;

 TChunkTab = Array[0..NCHUNK-1] Of Pointer;
 PLongArr  = ^TLongArr;
 TLongArr  = Array[0..16000] Of LongInt;
 PByteArr  = ^TByteArr;
 TByteArr  = Array[0..32000] Of Byte;

Var
 { Options }
 OptListing,OptSymbols,OptToDisk,OptOptimize,OptCase,OptDebug : Boolean;
 OptWarnings : Boolean;
 OptOutName,OptIncPath,OptListName : String;
 OptTabSize : Integer;
 { Etat de l'assemblage }
 AsmPassNo   : Integer;
 AsmErrors,AsmWarns : Integer;
 AsmLines    : LongInt;
 AsmFileName : String;
 CurSrcName  : String;
 CurLineNo   : LongInt;
 ErrLn       : Array[1..MAXERR] Of LongInt;
 ErrNm       : Array[1..MAXERR] Of String[60];
 ErrTx       : Array[1..MAXERR] Of String[90];
 LastErrLine : LongInt;
 AsmLog      : Array[1..MAXLOG] Of PString;
 AsmLogN     : Integer;
 AsmFromEditor : Boolean;

 Hash        : Array[0..HASHSZ-1] Of PSym;
 SymCount    : Integer;
 Macros      : Array[1..MAXMAC] Of TMacro;
 MacCount    : Integer;
 Srcs        : Array[1..MAXSRC] Of TSrc;
 SrcTop      : Integer;
 Conds       : Array[1..MAXCOND] Of TCond;
 CondTop     : Integer;
 CondActive  : Boolean;
 MacUniq     : LongInt;
 LastGlobal  : String[63];

 { Sections }
 Chunks      : Array[0..1] Of TChunkTab;
 SecLen      : Array[0..2] Of LongInt;
 CurSect     : Integer;
 AbsMode     : Boolean;
 OrgAddr     : LongInt;
 SecBase     : Array[0..2] Of LongInt;   { adresse de l'image }
 PrevLen     : Array[0..2] Of LongInt;   { tailles trouvees a la passe 1 }
 RelocPos    : PLongArr;   { decalage dans la section source }
 RelocSrc    : PByteArr;
 RelocDst    : PByteArr;
 RelocN      : Integer;
 Decs        : PByteArr;
 DecIdx      : Integer;
 EntryPoint  : LongInt;
 EntrySect   : Integer;
 HaveOutput  : Boolean;

 { Evaluation d'expressions }
 ES          : String;
 EP          : Integer;
 ExprErrMsg  : String[80];
 UndefName   : String[63];
 ReqDef      : Boolean;        { exige que les symboles soient definis }

 { Contenu de la ligne en cours }
 LnLabel,LnOp,LnArgs,LnSuffix : String;
 LnText      : String;
 LnAddr      : LongInt;
 LnStartLen  : LongInt;
 ListF       : Text;
 ListOn      : Boolean;
 ListSuppress: Boolean;

Procedure LogLine(Const S: String);
Var P: PString;
Begin
 If AsmLogN<MAXLOG Then Begin
  Inc(AsmLogN);
  GetMem(P,Length(S)+1);
  P^:=S;
  AsmLog[AsmLogN]:=P;
 End;
 If BatchMode Then WriteLn(ConOut,S);
End;

Procedure LogClear;
Var I: Integer;
Begin
 For I:=1 To AsmLogN Do FreeMem(AsmLog[I],Length(AsmLog[I]^)+1);
 AsmLogN:=0;
End;

Function NewStr(Const S: String): PString;
Var P: PString;
Begin
 GetMem(P,Length(S)+1);
 P^:=S;
 NewStr:=P;
End;

Procedure FreeStr(P: PString);
Begin
 If P<>Nil Then FreeMem(P,Length(P^)+1);
End;

{ ---------------------------------------------------------------------- }
{ Erreurs                                                                 }
{ ---------------------------------------------------------------------- }

Procedure Err3(Const En,Fr,De: String);
Var S: String; I: Integer;
Begin
 If AsmPassNo<>2 Then Exit;
 If (CurLineNo=LastErrLine) And (CurSrcName=AsmFileName) Then Exit;
 LastErrLine:=CurLineNo;
 Inc(AsmErrors);
 S:=T3(En,Fr,De);
 If AsmErrors<=MAXERR Then Begin
  ErrLn[AsmErrors]:=CurLineNo;
  If CurSrcName=AsmFileName Then ErrNm[AsmErrors]:='' Else
   ErrNm[AsmErrors]:=Copy(CurSrcName,1,60);
  ErrTx[AsmErrors]:=Copy(S,1,90);
 End;
 If CurSrcName=AsmFileName Then
  LogLine(T3('Error in line ','Erreur ligne ','Fehler in Zeile ')+IntStr(CurLineNo)+': '+S)
 Else
  LogLine(T3('Error in ','Erreur dans ','Fehler in ')+CurSrcName+' ('+IntStr(CurLineNo)+'): '+S);
 If LnText<>'' Then Begin
  S:=Copy(LnText,1,70);
  For I:=1 To Length(S) Do If S[I]=#9 Then S[I]:=' ';
  LogLine('    '+S);
 End;
End;

Procedure Err(Const S: String);
Begin
 Err3(S,S,S);
End;

Procedure Warn3(Const En,Fr,De: String);
Begin
 If Not OptWarnings Then Exit;
 If AsmPassNo<>2 Then Exit;
 Inc(AsmWarns);
 LogLine(T3('Warning in line ','Avertissement ligne ','Warnung Zeile ')+
         IntStr(CurLineNo)+': '+T3(En,Fr,De));
End;

{ ---------------------------------------------------------------------- }
{ Table des symboles                                                      }
{ ---------------------------------------------------------------------- }

Function HashOf(Const S: String): Integer;
Var I: Integer; H: LongInt;
Begin
 H:=0;
 For I:=1 To Length(S) Do H:=(H*31+Ord(S[I])) And $7FFFFFF;
 HashOf:=H Mod HASHSZ;
End;

Function KeyOf(Const S: String): String;
Begin
 If OptCase Then KeyOf:=S Else KeyOf:=Upper(S);
End;

Function FindSym(Const Name: String): PSym;
Var P: PSym; K: String;
Begin
 K:=KeyOf(Name);
 P:=Hash[HashOf(K)];
 While P<>Nil Do Begin
  If P^.Name=K Then Begin FindSym:=P;Exit;End;
  P:=P^.Next;
 End;
 FindSym:=Nil;
End;

Function AddSym(Const Name: String): PSym;
Var P: PSym; H: Integer; K: String;
Begin
 K:=KeyOf(Name);
 New(P);
 P^.Name:=Copy(K,1,63);
 P^.Value:=0;P^.Sect:=SEC_ABS;P^.Kind:=0;P^.Defd:=False;P^.Pas:=0;
 H:=HashOf(P^.Name);
 P^.Next:=Hash[H];
 Hash[H]:=P;
 Inc(SymCount);
 AddSym:=P;
End;

Procedure FreeSyms;
Var I: Integer; P,Q: PSym;
Begin
 For I:=0 To HASHSZ-1 Do Begin
  P:=Hash[I];
  While P<>Nil Do Begin Q:=P^.Next;Dispose(P);P:=Q;End;
  Hash[I]:=Nil;
 End;
 SymCount:=0;
End;

{ Nom interne : les etiquettes locales (.nom ou nom$) dependent de la
  derniere etiquette globale }
Function LocalName(Const N: String): String;
Begin
 If (N<>'') And ((N[1]='.') Or (N[Length(N)]='$')) Then
  LocalName:=LastGlobal+'~'+N
 Else LocalName:=N;
End;

{ ---------------------------------------------------------------------- }
{ Sections et emission                                                    }
{ ---------------------------------------------------------------------- }

Procedure FreeSections;
Var S,C: Integer;
Begin
 For S:=0 To 1 Do
  For C:=0 To NCHUNK-1 Do
   If Chunks[S][C]<>Nil Then Begin
    FreeMem(Chunks[S][C],CHUNKSZ);
    Chunks[S][C]:=Nil;
   End;
End;

Procedure SecPut(S: Integer; Off: LongInt; B: Byte);
Var C: Integer; P: ^Byte;
Begin
 If (S<0) Or (S>1) Then Exit;
 C:=Off Div CHUNKSZ;
 If (C<0) Or (C>=NCHUNK) Then Exit;
 If Chunks[S][C]=Nil Then Begin
  GetMem(Chunks[S][C],CHUNKSZ);
  FillChar(Chunks[S][C]^,CHUNKSZ,0);
 End;
 P:=PtrAdd(Chunks[S][C],Off Mod CHUNKSZ);
 P^:=B;
End;

Function SecGet(S: Integer; Off: LongInt): Byte;
Var C: Integer; P: ^Byte;
Begin
 SecGet:=0;
 If (S<0) Or (S>1) Then Exit;
 C:=Off Div CHUNKSZ;
 If (C<0) Or (C>=NCHUNK) Then Exit;
 If Chunks[S][C]=Nil Then Exit;
 P:=PtrAdd(Chunks[S][C],Off Mod CHUNKSZ);
 SecGet:=P^;
End;

Function CurPC: LongInt;
Begin
 If AbsMode Then CurPC:=OrgAddr+SecLen[0]
 Else CurPC:=SecLen[CurSect];
End;

Procedure EmitByte(B: Byte);
Var S: Integer;
Begin
 S:=CurSect;
 If AbsMode Then S:=0;
 If S=SEC_BSS Then Begin
  Err3('Cannot generate code in BSS','Impossible de generer du code en BSS','Code im BSS nicht moeglich');
  Exit;
 End;
 If SecLen[S]>=LongInt(NCHUNK)*CHUNKSZ-1 Then Begin
  Err3('Program too large','Programme trop grand','Programm zu gross');
  Exit;
 End;
 If AsmPassNo=2 Then SecPut(S,SecLen[S],B);
 Inc(SecLen[S]);
End;

Procedure EmitWord(W: LongInt);
Begin
 EmitByte((W Shr 8) And $FF);
 EmitByte(W And $FF);
End;

{ Mot long, avec relocation eventuelle (RSect >= 0) }
Procedure EmitLong(L: LongInt; RSect: Integer);
Begin
 If (RSect>=0) And Not AbsMode And (AsmPassNo=2) And (CurSect<>SEC_BSS) Then Begin
  If RelocN<MAXRELOC Then Begin
   Inc(RelocN);
   RelocPos^[RelocN]:=SecLen[CurSect];
   RelocSrc^[RelocN]:=CurSect;
   RelocDst^[RelocN]:=RSect;
  End;
 End;
 EmitWord(ShrL(L,16));
 EmitWord(L And $FFFF);
End;

Procedure ReserveBytes(N: LongInt);
Begin
 If N<=0 Then Exit;
 If AbsMode Then Begin Inc(SecLen[0],N);Exit;End;
 If CurSect=SEC_BSS Then Inc(SecLen[SEC_BSS],N)
 Else Begin
  While N>0 Do Begin EmitByte(0);Dec(N);End;
 End;
End;

Procedure EvenPC;
Begin
 If Odd(CurPC) Then ReserveBytes(1);
End;

{ ---------------------------------------------------------------------- }
{ Evaluation des expressions                                              }
{ ---------------------------------------------------------------------- }

Function ImgOf(V: LongInt; S: Integer): LongInt;
Begin
 If (S>=0) And Not AbsMode Then ImgOf:=V+SecBase[S] Else ImgOf:=V;
End;

Procedure SkipSp;
Begin
 While (EP<=Length(ES)) And ((ES[EP]=' ') Or (ES[EP]=#9)) Do Inc(EP);
End;

Function IsIdStart(C: Char): Boolean;
Begin
 IsIdStart:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C='_') Or (C='.');
End;

Function IsIdChar(C: Char): Boolean;
Begin
 IsIdChar:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C='_') Or
           (C='.') Or ((C>='0') And (C<='9')) Or (C='$');
End;

Function IsHexCh(C: Char): Boolean;
Begin
 IsHexCh:=((C>='0') And (C<='9')) Or ((C>='A') And (C<='F')) Or ((C>='a') And (C<='f'));
End;

Function HexVal(C: Char): Integer;
Begin
 If (C>='0') And (C<='9') Then HexVal:=Ord(C)-48
 Else HexVal:=(Ord(UpCase(C))-55);
End;

Procedure ExprError3(Const En,Fr,De: String);
Begin
 If ExprErrMsg='' Then ExprErrMsg:=Copy(T3(En,Fr,De),1,80);
End;

Function MkTV(V: LongInt; S: Integer; U: Boolean): TTV;
Var R: TTV;
Begin
 R.V:=V;R.S:=S;R.U:=U;
 MkTV:=R;
End;

Function ExprLevel(L: Integer): TTV; Forward;

Function MacArgCount: LongInt;
Begin
 If SrcTop>0 Then Begin
  If Srcs[SrcTop].Kind=1 Then MacArgCount:=Srcs[SrcTop].NArg
  Else MacArgCount:=0;
 End Else MacArgCount:=0;
End;

Function ExprPrimary: TTV;
Var R: TTV; C: Char; V: LongInt; N,I: Integer; Name: String; P: PSym;
    Q: Char; Cnt: Integer;
Begin
 R:=MkTV(0,SEC_ABS,False);
 SkipSp;
 If EP>Length(ES) Then Begin
  ExprError3('Operand expected','Operande attendue','Operand erwartet');
  ExprPrimary:=R;Exit;
 End;
 C:=ES[EP];
 If C='(' Then Begin
  Inc(EP);
  R:=ExprLevel(0);
  SkipSp;
  If (EP<=Length(ES)) And (ES[EP]=')') Then Inc(EP)
  Else ExprError3('Missing )','Parenthese ) manquante','Klammer ) fehlt');
 End
 Else If C='$' Then Begin
  If (EP<Length(ES)) And IsHexCh(ES[EP+1]) Then Begin
   Inc(EP);V:=0;
   While (EP<=Length(ES)) And IsHexCh(ES[EP]) Do Begin
    V:=(V Shl 4) Or HexVal(ES[EP]);Inc(EP);
   End;
   R.V:=V;
  End Else Begin
   Inc(EP);
   R.V:=CurPC;
   If Not AbsMode Then R.S:=CurSect;
  End;
 End
 Else If C='%' Then Begin
  Inc(EP);V:=0;
  If (EP>Length(ES)) Or Not (ES[EP] In ['0','1']) Then
   ExprError3('Bad binary number','Nombre binaire incorrect','Falsche Binaerzahl');
  While (EP<=Length(ES)) And (ES[EP] In ['0','1']) Do Begin
   V:=(V Shl 1) Or (Ord(ES[EP])-48);Inc(EP);
  End;
  R.V:=V;
 End
 Else If C='@' Then Begin
  Inc(EP);V:=0;
  While (EP<=Length(ES)) And (ES[EP] In ['0'..'7']) Do Begin
   V:=(V Shl 3) Or (Ord(ES[EP])-48);Inc(EP);
  End;
  R.V:=V;
 End
 Else If (C>='0') And (C<='9') Then Begin
  V:=0;
  If (C='0') And (EP<Length(ES)) And ((ES[EP+1]='x') Or (ES[EP+1]='X')) Then Begin
   Inc(EP,2);
   While (EP<=Length(ES)) And IsHexCh(ES[EP]) Do Begin
    V:=(V Shl 4) Or HexVal(ES[EP]);Inc(EP);
   End;
  End Else Begin
   While (EP<=Length(ES)) And (ES[EP]>='0') And (ES[EP]<='9') Do Begin
    V:=V*10+(Ord(ES[EP])-48);Inc(EP);
   End;
  End;
  R.V:=V;
 End
 Else If (C='''') Or (C='"') Then Begin
  Q:=C;Inc(EP);V:=0;Cnt:=0;
  While EP<=Length(ES) Do Begin
   If ES[EP]=Q Then Begin
    If (EP<Length(ES)) And (ES[EP+1]=Q) Then Begin
     V:=(V Shl 8) Or Ord(Q);Inc(Cnt);Inc(EP,2);
    End Else Begin Inc(EP);Break;End;
   End Else Begin
    V:=(V Shl 8) Or Ord(ES[EP]);Inc(Cnt);Inc(EP);
   End;
  End;
  R.V:=V;
 End
 Else If C='*' Then Begin
  Inc(EP);
  R.V:=CurPC;
  If Not AbsMode Then R.S:=CurSect;
 End
 Else If IsIdStart(C) Then Begin
  N:=EP;
  While (EP<=Length(ES)) And IsIdChar(ES[EP]) Do Inc(EP);
  Name:=Copy(ES,N,EP-N);
  If Upper(Name)='NARG' Then R.V:=MacArgCount
  Else Begin
   Name:=LocalName(Name);
   P:=FindSym(Name);
   If (P<>Nil) And P^.Defd And (P^.Kind<>2) Then Begin
    R.V:=P^.Value;R.S:=P^.Sect;
   End Else Begin
    R.U:=True;
    R.V:=0;
    If UndefName='' Then UndefName:=Copy(Name,1,63);
   End;
  End;
 End
 Else Begin
  ExprError3('Bad expression','Expression incorrecte','Falscher Ausdruck');
  Inc(EP);
 End;
 ExprPrimary:=R;
End;

Function ExprUnary: TTV;
Var R: TTV;
Begin
 SkipSp;
 If EP<=Length(ES) Then Begin
  If ES[EP]='-' Then Begin
   Inc(EP);R:=ExprUnary;
   R.V:=-R.V;
   If R.S>=0 Then Begin R.S:=SEC_ABS;ExprError3('Illegal relocation','Relocation illegale','Illegale Relokation');End;
   ExprUnary:=R;Exit;
  End;
  If ES[EP]='+' Then Begin Inc(EP);ExprUnary:=ExprUnary;Exit;End;
  If ES[EP]='~' Then Begin
   Inc(EP);R:=ExprUnary;
   R.V:=Not R.V;
   ExprUnary:=R;Exit;
  End;
 End;
 ExprUnary:=ExprPrimary;
End;

Function SignedLt(A,B: LongInt): Boolean;
Begin
 SignedLt:=A<B;
End;

Function ExprLevel(L: Integer): TTV;
Var A,B: TTV; Op: Integer; C,D: Char; Done: Boolean;
Begin
 If L>6 Then Begin ExprLevel:=ExprUnary;Exit;End;
 A:=ExprLevel(L+1);
 Repeat
  SkipSp;
  Done:=True;
  If EP<=Length(ES) Then Begin
   C:=ES[EP];
   If EP<Length(ES) Then D:=ES[EP+1] Else D:=#0;
   Op:=0;
   Case L Of
    0: Begin
        If (C='=') Then Begin Op:=1;Inc(EP);If D='=' Then Inc(EP);End
        Else If (C='<') And (D='>') Then Begin Op:=2;Inc(EP,2);End
        Else If (C='<') And (D='=') Then Begin Op:=5;Inc(EP,2);End
        Else If (C='>') And (D='=') Then Begin Op:=6;Inc(EP,2);End
        Else If (C='<') And (D<>'<') Then Begin Op:=3;Inc(EP);End
        Else If (C='>') And (D<>'>') Then Begin Op:=4;Inc(EP);End
        Else If (C='!') And (D='=') Then Begin Op:=2;Inc(EP,2);End;
       End;
    1: If (C='|') Or ((C='!') And (D<>'=')) Then Begin Op:=1;Inc(EP);End;
    2: If C='^' Then Begin Op:=1;Inc(EP);End;
    3: If C='&' Then Begin Op:=1;Inc(EP);End;
    4: If (C='<') And (D='<') Then Begin Op:=1;Inc(EP,2);End
       Else If (C='>') And (D='>') Then Begin Op:=2;Inc(EP,2);End;
    5: If C='+' Then Begin Op:=1;Inc(EP);End
       Else If C='-' Then Begin Op:=2;Inc(EP);End;
    6: If C='*' Then Begin Op:=1;Inc(EP);End
       Else If C='/' Then Begin Op:=2;Inc(EP);End
       Else If (C='%') Then Begin Op:=3;Inc(EP);End;
   End;
   If Op<>0 Then Begin
    Done:=False;
    B:=ExprLevel(L+1);
    A.U:=A.U Or B.U;
    Case L Of
     0: Begin
         Case Op Of
          1: If A.V=B.V Then A.V:=-1 Else A.V:=0;
          2: If A.V<>B.V Then A.V:=-1 Else A.V:=0;
          3: If A.V<B.V Then A.V:=-1 Else A.V:=0;
          4: If A.V>B.V Then A.V:=-1 Else A.V:=0;
          5: If A.V<=B.V Then A.V:=-1 Else A.V:=0;
          6: If A.V>=B.V Then A.V:=-1 Else A.V:=0;
         End;
         A.S:=SEC_ABS;
        End;
     1: Begin A.V:=A.V Or B.V;A.S:=SEC_ABS;End;
     2: Begin A.V:=A.V Xor B.V;A.S:=SEC_ABS;End;
     3: Begin A.V:=A.V And B.V;A.S:=SEC_ABS;End;
     4: Begin
         If Op=1 Then A.V:=A.V Shl (B.V And 63)
         Else A.V:=ShrL(A.V,B.V And 63);
         A.S:=SEC_ABS;
        End;
     5: Begin
         If Op=1 Then Begin
          If (A.S>=0) And (B.S>=0) Then
           ExprError3('Illegal relocation','Relocation illegale','Illegale Relokation')
          Else If B.S>=0 Then A.S:=B.S;
          A.V:=A.V+B.V;
         End Else Begin
          If (A.S>=0) And (B.S>=0) Then Begin
           If A.S<>B.S Then Begin
            If Not (A.U Or B.U) Then
             ExprError3('Illegal relocation','Relocation illegale','Illegale Relokation');
           End;
           A.S:=SEC_ABS;
          End Else If (A.S<0) And (B.S>=0) Then
           ExprError3('Illegal relocation','Relocation illegale','Illegale Relokation');
          A.V:=A.V-B.V;
         End;
        End;
     6: Begin
         If (A.S>=0) Or (B.S>=0) Then
          ExprError3('Illegal relocation','Relocation illegale','Illegale Relokation');
         A.S:=SEC_ABS;
         Case Op Of
          1: A.V:=A.V*B.V;
          2: If B.V=0 Then Begin
              If Not A.U Then ExprError3('Division by zero','Division par zero','Division durch Null');
              A.V:=0;
             End Else If (B.V=-1) Then A.V:=-A.V Else A.V:=A.V Div B.V;
          3: If B.V=0 Then Begin
              If Not A.U Then ExprError3('Division by zero','Division par zero','Division durch Null');
              A.V:=0;
             End Else If B.V=-1 Then A.V:=0 Else A.V:=A.V Mod B.V;
         End;
        End;
    End;
   End;
  End;
 Until Done;
 ExprLevel:=A;
End;

{ Evalue une expression a partir de ES[EP] ; l'analyse s'arrete a la
  premiere virgule ou parenthese fermante non appariee }
Function EvalAt(Var R: TTV): Boolean;
Begin
 ExprErrMsg:='';UndefName:='';
 R:=ExprLevel(0);
 If (ExprErrMsg='') And R.U And (AsmPassNo=2) And (UndefName<>'') Then Begin
  Err3('Undefined symbol: '+UndefName,'Symbole non defini : '+UndefName,
       'Undefiniertes Symbol: '+UndefName);
  EvalAt:=False;Exit;
 End;
 If ExprErrMsg<>'' Then Begin
  Err(ExprErrMsg);
  EvalAt:=False;
  Exit;
 End;
 EvalAt:=True;
End;

{ Evalue une chaine complete }
Function EvalStr(Const S: String; Var R: TTV): Boolean;
Begin
 ES:=S;EP:=1;
 If Not EvalAt(R) Then Begin EvalStr:=False;Exit;End;
 SkipSp;
 If EP<=Length(ES) Then Begin
  Err3('Bad expression','Expression incorrecte','Falscher Ausdruck');
  EvalStr:=False;Exit;
 End;
 EvalStr:=True;
End;

{ ---------------------------------------------------------------------- }
{ Operandes et modes d'adressage                                         }
{ ---------------------------------------------------------------------- }

Const
 OK_NONE=0; OK_DN=1; OK_AN=2; OK_IND=3; OK_POST=4; OK_PRE=5; OK_DISP=6;
 OK_IDX=7; OK_ABSW=8; OK_ABSL=9; OK_PCD=10; OK_PCI=11; OK_IMM=12;
 OK_SR=13; OK_CCR=14; OK_USP=15; OK_LIST=16;

 MA_ALL  = $1FFE;
 MA_DATA = $1FFA;
 MA_ALT  = $03FE;
 MA_DALT = $03FA;
 MA_MALT = $03F8;
 MA_CTRL = $0FC8;
 MA_CALT = $03C8;

 CondNames : Array[0..17] Of String[2] =
  ('T','F','HI','LS','CC','CS','NE','EQ','VC','VS','PL','MI','GE','LT','GT','LE','HS','LO');

Type
 TOp = Record
  K    : Integer;
  R    : Integer;        { numero de registre (An/Dn) ou registre de base }
  XR   : Integer;        { registre d'index 0..15 }
  XL   : Boolean;        { index long }
  V    : LongInt;
  S    : Integer;
  U    : Boolean;
  Sz   : Integer;        { taille imposee pour un absolu : 2 ou 4 }
  Mask : LongInt;        { liste de registres (D0=bit0 .. A7=bit15) }
  HasX : Boolean;
 End;

Var
 Ops    : Array[1..4] Of TOp;
 OpStr  : Array[1..4] Of String[120];
 NOps   : Integer;
 LnSz   : Integer;       { 0 aucune, 1 B, 2 W, 4 L, 8 S }
 InstrOff : LongInt;     { decalage de l'instruction dans la section }
 InstrPC  : LongInt;     { adresse de l'instruction (image) }
 OpW      : LongInt;     { mot d'operation }
 XW       : Array[1..8] Of LongInt;
 XLg      : Array[1..8] Of Boolean;
 XRl      : Array[1..8] Of Integer;
 XN       : Integer;
 XWords   : Integer;
 BadInstr : Boolean;

Function KBit(K: Integer): LongInt;
Begin
 KBit:=LongInt(1) Shl K;
End;

Function TrimS(Const S: String): String;
Var A,B: Integer;
Begin
 A:=1;B:=Length(S);
 While (A<=B) And ((S[A]=' ') Or (S[A]=#9)) Do Inc(A);
 While (B>=A) And ((S[B]=' ') Or (S[B]=#9)) Do Dec(B);
 TrimS:=Copy(S,A,B-A+1);
End;

{ Registre : 0..7 = D0..D7, 8..15 = A0..A7 (SP = A7), 20 SR, 21 CCR, 22 USP,
  23 PC, -1 sinon }
Function RegOf(Const U: String): Integer;
Begin
 RegOf:=-1;
 If Length(U)=2 Then Begin
  If (U[1]='D') And (U[2]>='0') And (U[2]<='7') Then RegOf:=Ord(U[2])-48
  Else If (U[1]='A') And (U[2]>='0') And (U[2]<='7') Then RegOf:=8+Ord(U[2])-48
  Else If U='SP' Then RegOf:=15
  Else If U='SR' Then RegOf:=20
  Else If U='PC' Then RegOf:=23;
 End Else If U='CCR' Then RegOf:=21
 Else If U='USP' Then RegOf:=22;
End;

{ Decoupe une chaine sur les virgules de niveau 0 }
Function SplitTop(Const S: String; Var Parts: Array Of String; MaxN: Integer): Integer;
Var I,D,N: Integer; Q: Char; Cur: String;
Begin
 N:=0;D:=0;Q:=#0;Cur:='';
 For I:=1 To Length(S) Do Begin
  If Q<>#0 Then Begin
   Cur:=Cur+S[I];
   If S[I]=Q Then Q:=#0;
  End Else Begin
   Case S[I] Of
    '''','"': Begin Q:=S[I];Cur:=Cur+S[I];End;
    '(','[': Begin Inc(D);Cur:=Cur+S[I];End;
    ')',']': Begin Dec(D);Cur:=Cur+S[I];End;
    ',': If D=0 Then Begin
          If N<MaxN Then Begin Parts[N]:=TrimS(Cur);Inc(N);End;
          Cur:='';
         End Else Cur:=Cur+S[I];
   Else Cur:=Cur+S[I];
   End;
  End;
 End;
 If (Cur<>'') Or (N>0) Then Begin
  If N<MaxN Then Begin Parts[N]:=TrimS(Cur);Inc(N);End;
 End;
 SplitTop:=N;
End;

Function ParseRegList(Const U: String; Var Mask: LongInt): Boolean;
Var I,A,B,R1,R2,K: Integer; Tok: String; C: Char;
Begin
 ParseRegList:=False;
 Mask:=0;
 If (Pos('-',U)=0) And (Pos('/',U)=0) Then Exit;
 I:=1;
 While I<=Length(U) Do Begin
  Tok:='';
  While (I<=Length(U)) And (U[I]<>'/') And (U[I]<>'-') Do Begin Tok:=Tok+U[I];Inc(I);End;
  R1:=RegOf(Tok);
  If (R1<0) Or (R1>15) Then Exit;
  R2:=R1;
  If (I<=Length(U)) And (U[I]='-') Then Begin
   Inc(I);Tok:='';
   While (I<=Length(U)) And (U[I]<>'/') Do Begin Tok:=Tok+U[I];Inc(I);End;
   R2:=RegOf(Tok);
   If (R2<0) Or (R2>15) Then Exit;
  End;
  If R2<R1 Then Begin K:=R1;R1:=R2;R2:=K;End;
  For K:=R1 To R2 Do Mask:=Mask Or (LongInt(1) Shl K);
  If (I<=Length(U)) And (U[I]='/') Then Inc(I);
 End;
 C:=#0;
 A:=0;B:=0;
 If (A=B) And (C=#0) Then ParseRegList:=True;
End;

{ Analyse un registre d'index : "D3.W", "A2.L", "D1" }
Function ParseIndexReg(Const S0: String; Var R: Integer; Var L: Boolean): Boolean;
Var S: String; P: Integer;
Begin
 ParseIndexReg:=False;
 S:=Upper(TrimS(S0));
 L:=False;
 P:=Pos('*',S);
 If P>0 Then S:=Copy(S,1,P-1);
 P:=Pos('.',S);
 If P>0 Then Begin
  If Copy(S,P+1,1)='L' Then L:=True
  Else If Copy(S,P+1,1)<>'W' Then Exit;
  S:=Copy(S,1,P-1);
 End;
 R:=RegOf(S);
 If (R<0) Or (R>15) Then Exit;
 ParseIndexReg:=True;
End;

Function EvalOpnd(Const S: String; Var V: LongInt; Var Sc: Integer; Var U: Boolean): Boolean;
Var R: TTV;
Begin
 If S='' Then Begin V:=0;Sc:=SEC_ABS;U:=False;EvalOpnd:=True;Exit;End;
 If EvalStr(S,R) Then Begin
  V:=R.V;Sc:=R.S;U:=R.U;
  EvalOpnd:=True;
 End Else Begin
  V:=0;Sc:=SEC_ABS;U:=True;
  EvalOpnd:=False;
 End;
End;

Procedure ParseOp(Const S0: String; Var O: TOp);
Var S,U,Pre,Inn,Suf: String; R,P,D,I,L,N: Integer; Items: Array[0..3] Of String;
    Post,IsReg: Boolean; Sy: PSym; M: LongInt; XL: Boolean; Ok: Boolean;
Begin
 FillChar(O,SizeOf(O),0);
 O.S:=SEC_ABS;
 S:=TrimS(S0);
 If S='' Then Begin
  Err3('Operand expected','Operande attendue','Operand erwartet');
  BadInstr:=True;Exit;
 End;
 U:=Upper(S);
 If S[1]='#' Then Begin
  O.K:=OK_IMM;
  EvalOpnd(Copy(S,2,255),O.V,O.S,O.U);
  Exit;
 End;
 R:=RegOf(U);
 If R>=0 Then Begin
  If R<8 Then Begin O.K:=OK_DN;O.R:=R;End
  Else If R<16 Then Begin O.K:=OK_AN;O.R:=R-8;End
  Else If R=20 Then O.K:=OK_SR
  Else If R=21 Then O.K:=OK_CCR
  Else If R=22 Then O.K:=OK_USP
  Else Begin Err3('Illegal addressing mode','Mode d''adressage illegal','Illegaler Adressmodus');BadInstr:=True;End;
  Exit;
 End;
 If ParseRegList(U,M) Then Begin O.K:=OK_LIST;O.Mask:=M;Exit;End;
 { symbole de liste de registres (REG) }
 If IsIdStart(S[1]) Then Begin
  Sy:=FindSym(LocalName(S));
  If (Sy<>Nil) And (Sy^.Kind=2) Then Begin O.K:=OK_LIST;O.Mask:=Sy^.Value;Exit;End;
 End;
 L:=Length(S);
 { predecrementation / postincrementation / indirections }
 Post:=False;
 If (L>=3) And (S[L]='+') And (S[L-1]=')') Then Begin Post:=True;Suf:=Copy(S,1,L-1);End
 Else Suf:=S;
 L:=Length(Suf);
 If (L>=3) And (Suf[L]=')') Then Begin
  D:=0;P:=0;
  For I:=L Downto 1 Do Begin
   If Suf[I]=')' Then Inc(D);
   If Suf[I]='(' Then Begin
    Dec(D);
    If D=0 Then Begin P:=I;Break;End;
   End;
  End;
  If P>0 Then Begin
   Pre:=TrimS(Copy(Suf,1,P-1));
   Inn:=Copy(Suf,P+1,L-P-1);
   N:=SplitTop(Inn,Items,4);
   IsReg:=False;
   If N>=1 Then Begin
    R:=RegOf(Upper(Items[0]));
    If (R>=8) And (R<=15) Then IsReg:=True;
    If R=23 Then IsReg:=True;
    If (N>=2) And (RegOf(Upper(Items[1]))>=8) And (RegOf(Upper(Items[1]))<=15) Then IsReg:=True;
    If (N>=2) And (RegOf(Upper(Items[1]))=23) Then IsReg:=True;
   End;
   If IsReg Then Begin
    Ok:=True;
    If N=1 Then Begin
     R:=RegOf(Upper(Items[0]));
     If R=23 Then Begin
      O.K:=OK_PCD;
      EvalOpnd(Pre,O.V,O.S,O.U);
     End Else Begin
      O.R:=R-8;
      If Post Then O.K:=OK_POST
      Else If Pre='-' Then O.K:=OK_PRE
      Else If Pre='' Then O.K:=OK_IND
      Else Begin
       O.K:=OK_DISP;
       EvalOpnd(Pre,O.V,O.S,O.U);
      End;
     End;
    End Else Begin
     { avec index }
     R:=RegOf(Upper(Items[0]));
     If (R>=8) And (R<=15) Or (R=23) Then Begin
      { d(An,Xn) : le deplacement est dans Pre }
      If R=23 Then O.K:=OK_PCI Else Begin O.K:=OK_IDX;O.R:=R-8;End;
      If Not ParseIndexReg(Items[1],O.XR,O.XL) Then Ok:=False;
      EvalOpnd(Pre,O.V,O.S,O.U);
     End Else Begin
      { (d,An) ou (d,An,Xn) }
      EvalOpnd(Items[0],O.V,O.S,O.U);
      R:=RegOf(Upper(Items[1]));
      If R=23 Then O.K:=OK_PCD Else If (R>=8) And (R<=15) Then Begin
       O.K:=OK_DISP;O.R:=R-8;
      End Else Ok:=False;
      If (N>=3) And Ok Then Begin
       If R=23 Then O.K:=OK_PCI Else O.K:=OK_IDX;
       If Not ParseIndexReg(Items[2],O.XR,O.XL) Then Ok:=False;
      End;
     End;
    End;
    If Not Ok Then Begin
     Err3('Illegal addressing mode','Mode d''adressage illegal','Illegaler Adressmodus');
     BadInstr:=True;
    End;
    Exit;
   End;
  End;
 End;
 { absolu : adr[.W|.L] }
 L:=Length(S);
 O.Sz:=0;
 If (L>2) And (S[L-1]='.') Then Begin
  If UpCase(S[L])='W' Then Begin O.Sz:=2;S:=Copy(S,1,L-2);End
  Else If UpCase(S[L])='L' Then Begin O.Sz:=4;S:=Copy(S,1,L-2);End;
 End;
 If O.Sz=2 Then O.K:=OK_ABSW Else O.K:=OK_ABSL;
 EvalOpnd(S,O.V,O.S,O.U);
End;

{ ---------------------------------------------------------------------- }
{ Mots d'extension                                                        }
{ ---------------------------------------------------------------------- }

Procedure PutX(V: LongInt; IsLong: Boolean; Rel: Integer);
Begin
 If XN<8 Then Begin
  Inc(XN);
  XW[XN]:=V;XLg[XN]:=IsLong;XRl[XN]:=Rel;
  If IsLong Then Inc(XWords,2) Else Inc(XWords);
 End;
End;

Procedure CheckRange(V: LongInt; U: Boolean; Lo,Hi: LongInt);
Begin
 If U Then Exit;
 If (V<Lo) Or (V>Hi) Then
  Err3('Value out of range','Valeur hors limites','Wert ausserhalb des Bereichs');
End;

{ Valeur immediate selon la taille }
Procedure PutImm(Var O: TOp; Sz: Integer);
Begin
 Case Sz Of
  1: Begin CheckRange(O.V,O.U,-256,255);PutX(O.V And $FF,False,-1);End;
  2: Begin CheckRange(O.V,O.U,-32768,65535);PutX(O.V And $FFFF,False,-1);End;
 Else PutX(ImgOf(O.V,O.S),True,O.S);
 End;
End;

{ Encode un mode d'adressage ; retourne mode*8+registre ou -1 }
Function EncEA(Var O: TOp; Sz: Integer; Allowed: LongInt): Integer;
Var Disp,Tgt,At: LongInt; Ext: LongInt;
Begin
 EncEA:=-1;
 If (O.K<1) Or (O.K>12) Or ((Allowed And KBit(O.K))=0) Then Begin
  Err3('Illegal addressing mode','Mode d''adressage illegal','Illegaler Adressmodus');
  BadInstr:=True;Exit;
 End;
 Case O.K Of
  OK_DN: EncEA:=O.R;
  OK_AN: EncEA:=8+O.R;
  OK_IND: EncEA:=16+O.R;
  OK_POST: EncEA:=24+O.R;
  OK_PRE: EncEA:=32+O.R;
  OK_DISP: Begin
            CheckRange(O.V,O.U,-32768,32767);
            PutX(O.V And $FFFF,False,-1);
            EncEA:=40+O.R;
           End;
  OK_IDX: Begin
           CheckRange(O.V,O.U,-128,127);
           Ext:=(O.XR Shl 12) Or (O.V And $FF);
           If O.XL Then Ext:=Ext Or $800;
           PutX(Ext,False,-1);
           EncEA:=48+O.R;
          End;
  OK_ABSW: Begin
            CheckRange(O.V,O.U,-32768,32767);
            PutX(O.V And $FFFF,False,-1);
            EncEA:=56;
           End;
  OK_ABSL: Begin
            PutX(ImgOf(O.V,O.S),True,O.S);
            EncEA:=57;
           End;
  OK_PCD,OK_PCI: Begin
            At:=InstrPC+2+2*XWords;
            Tgt:=ImgOf(O.V,O.S);
            Disp:=Tgt-At;
            If O.K=OK_PCD Then Begin
             If (AsmPassNo=2) And Not O.U Then
              If (Disp<-32768) Or (Disp>32767) Then
               Err3('Offset out of range','Deplacement hors limites','Abstand ausserhalb des Bereichs');
             PutX(Disp And $FFFF,False,-1);
             EncEA:=58;
            End Else Begin
             If (AsmPassNo=2) And Not O.U Then
              If (Disp<-128) Or (Disp>127) Then
               Err3('Offset out of range','Deplacement hors limites','Abstand ausserhalb des Bereichs');
             Ext:=(O.XR Shl 12) Or (Disp And $FF);
             If O.XL Then Ext:=Ext Or $800;
             PutX(Ext,False,-1);
             EncEA:=59;
            End;
           End;
  OK_IMM: Begin
           PutImm(O,Sz);
           EncEA:=60;
          End;
 End;
End;

Procedure FlushInstr;
Var I: Integer;
Begin
 If BadInstr Then Exit;
 EmitWord(OpW And $FFFF);
 For I:=1 To XN Do Begin
  If XLg[I] Then EmitLong(XW[I],XRl[I]) Else EmitWord(XW[I]);
 End;
End;

Function SzBits(Sz: Integer): Integer;
Begin
 Case Sz Of
  1: SzBits:=0;
  4: SzBits:=2;
 Else SzBits:=1;
 End;
End;

Function DefSize(Sz,D: Integer): Integer;
Begin
 If (Sz=0) Or (Sz=8) Then DefSize:=D Else DefSize:=Sz;
End;

Function NeedOps(N: Integer): Boolean;
Begin
 NeedOps:=True;
 If NOps<>N Then Begin
  If NOps<N Then Err3('Operand expected','Operande attendue','Operand erwartet')
  Else Err3('Too many operands','Trop d''operandes','Zu viele Operanden');
  BadInstr:=True;
  NeedOps:=False;
 End;
End;

Function CondCode(Const S: String): Integer;
Var I: Integer;
Begin
 CondCode:=-1;
 For I:=0 To 17 Do
  If CondNames[I]=S Then Begin
   If I=16 Then CondCode:=4 Else If I=17 Then CondCode:=5 Else CondCode:=I;
   Exit;
  End;
End;

Procedure BadMode;
Begin
 Err3('Illegal addressing mode','Mode d''adressage illegal','Illegaler Adressmodus');
 BadInstr:=True;
End;

Procedure BadSize;
Begin
 Err3('Illegal size','Taille illegale','Illegale Groesse');
 BadInstr:=True;
End;

{ ---------------------------------------------------------------------- }
{ Groupes d'instructions                                                  }
{ ---------------------------------------------------------------------- }

Function GImplied(Const M: String): Boolean;
Begin
 GImplied:=True;
 If M='NOP' Then OpW:=$4E71
 Else If M='RTS' Then OpW:=$4E75
 Else If M='RTE' Then OpW:=$4E73
 Else If M='RTR' Then OpW:=$4E77
 Else If M='RESET' Then OpW:=$4E70
 Else If M='TRAPV' Then OpW:=$4E76
 Else If M='ILLEGAL' Then OpW:=$4AFC
 Else Begin GImplied:=False;Exit;End;
 If NOps<>0 Then Begin
  Err3('Too many operands','Trop d''operandes','Zu viele Operanden');BadInstr:=True;
 End;
End;

Function GUnary(Const M: String): Boolean;
Var Base,Allowed: LongInt; Sz,E: Integer; Sized: Boolean;
Begin
 GUnary:=True;
 Sized:=True;Allowed:=MA_DALT;
 If M='CLR' Then Base:=$4200
 Else If M='NEG' Then Base:=$4400
 Else If M='NEGX' Then Base:=$4000
 Else If M='NOT' Then Base:=$4600
 Else If M='TST' Then Base:=$4A00
 Else If M='JMP' Then Begin Base:=$4EC0;Allowed:=MA_CTRL;Sized:=False;End
 Else If M='JSR' Then Begin Base:=$4E80;Allowed:=MA_CTRL;Sized:=False;End
 Else If M='PEA' Then Begin Base:=$4840;Allowed:=MA_CTRL;Sized:=False;End
 Else If M='TAS' Then Begin Base:=$4AC0;Sized:=False;End
 Else If M='NBCD' Then Begin Base:=$4800;Sized:=False;End
 Else Begin GUnary:=False;Exit;End;
 If Not NeedOps(1) Then Exit;
 If Sized Then Begin
  Sz:=DefSize(LnSz,2);
  If M='TST' Then Allowed:=MA_DALT;
  E:=EncEA(Ops[1],Sz,Allowed);
  If E<0 Then Exit;
  If (Sz=1) And (Ops[1].K=OK_AN) Then BadSize;
  OpW:=Base Or (SzBits(Sz) Shl 6) Or E;
 End Else Begin
  E:=EncEA(Ops[1],2,Allowed);
  If E<0 Then Exit;
  OpW:=Base Or E;
 End;
End;

Procedure ImmBase(Const M: String; Var B: LongInt);
Begin
 If (M='ADD') Or (M='ADDI') Then B:=$0600
 Else If (M='SUB') Or (M='SUBI') Then B:=$0400
 Else If (M='AND') Or (M='ANDI') Then B:=$0200
 Else If (M='OR') Or (M='ORI') Then B:=$0000
 Else If (M='EOR') Or (M='EORI') Then B:=$0A00
 Else B:=$0C00;
End;

Function GArith(Const M: String): Boolean;
Var Base,IB: LongInt; Sz,E,E2: Integer; Imm: Boolean; Q: LongInt;
Begin
 GArith:=True;
 If (M='ADD') Or (M='SUB') Or (M='AND') Or (M='OR') Or (M='EOR') Or (M='CMP') Or
    (M='ADDI') Or (M='SUBI') Or (M='ANDI') Or (M='ORI') Or (M='EORI') Or (M='CMPI') Or
    (M='ADDA') Or (M='SUBA') Or (M='CMPA') Then Begin
  If Not NeedOps(2) Then Exit;
  If (M='ADD') Or (M='ADDA') Or (M='ADDI') Then Base:=$D000
  Else If (M='SUB') Or (M='SUBA') Or (M='SUBI') Then Base:=$9000
  Else If (M='AND') Or (M='ANDI') Then Base:=$C000
  Else If (M='OR') Or (M='ORI') Then Base:=$8000
  Else If (M='EOR') Or (M='EORI') Then Base:=$B100
  Else Base:=$B000;
  { vers SR / CCR }
  If (Ops[2].K=OK_SR) Or (Ops[2].K=OK_CCR) Then Begin
   If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
   ImmBase(M,IB);
   If (M<>'AND') And (M<>'ANDI') And (M<>'OR') And (M<>'ORI') And (M<>'EOR') And (M<>'EORI') Then Begin
    BadMode;Exit;
   End;
   If Ops[2].K=OK_CCR Then Begin
    OpW:=IB Or $003C;
    PutImm(Ops[1],1);
   End Else Begin
    OpW:=IB Or $007C;
    PutImm(Ops[1],2);
   End;
   Exit;
  End;
  { ADDA/SUBA/CMPA }
  If (M='ADDA') Or (M='SUBA') Or (M='CMPA') Or
     (((M='ADD') Or (M='SUB') Or (M='CMP')) And (Ops[2].K=OK_AN)) Then Begin
   If Ops[2].K<>OK_AN Then Begin BadMode;Exit;End;
   Sz:=DefSize(LnSz,2);
   If Sz=1 Then Begin BadSize;Exit;End;
   If Sz=4 Then Base:=Base Or $01C0 Else Base:=Base Or $00C0;
   E:=EncEA(Ops[1],Sz,MA_ALL);
   If E<0 Then Exit;
   OpW:=Base Or (Ops[2].R Shl 9) Or E;
   Exit;
  End;
  Sz:=DefSize(LnSz,2);
  Imm:=(Ops[1].K=OK_IMM) Or (M='ADDI') Or (M='SUBI') Or (M='ANDI') Or (M='ORI') Or
       (M='EORI') Or (M='CMPI');
  If Imm Then Begin
   If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
   ImmBase(M,IB);
   PutImm(Ops[1],Sz);
   E:=EncEA(Ops[2],Sz,MA_DALT);
   If E<0 Then Exit;
   OpW:=IB Or (SzBits(Sz) Shl 6) Or E;
   Exit;
  End;
  If M='EOR' Then Begin
   If Ops[1].K<>OK_DN Then Begin BadMode;Exit;End;
   E:=EncEA(Ops[2],Sz,MA_DALT);
   If E<0 Then Exit;
   OpW:=Base Or (Ops[1].R Shl 9) Or (SzBits(Sz) Shl 6) Or E;
   Exit;
  End;
  If M='CMP' Then Begin
   If Ops[2].K<>OK_DN Then Begin BadMode;Exit;End;
   E:=EncEA(Ops[1],Sz,MA_ALL);
   If E<0 Then Exit;
   If (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSize;Exit;End;
   OpW:=Base Or (Ops[2].R Shl 9) Or (SzBits(Sz) Shl 6) Or E;
   Exit;
  End;
  { ADD, SUB, AND, OR }
  If Ops[2].K=OK_DN Then Begin
   If (M='AND') Or (M='OR') Then E:=EncEA(Ops[1],Sz,MA_DATA)
   Else E:=EncEA(Ops[1],Sz,MA_ALL);
   If E<0 Then Exit;
   If (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSize;Exit;End;
   OpW:=Base Or (Ops[2].R Shl 9) Or (SzBits(Sz) Shl 6) Or E;
  End Else If Ops[1].K=OK_DN Then Begin
   E:=EncEA(Ops[2],Sz,MA_MALT);
   If E<0 Then Exit;
   OpW:=Base Or (Ops[1].R Shl 9) Or $100 Or (SzBits(Sz) Shl 6) Or E;
  End Else BadMode;
  Exit;
 End;
 If (M='ADDQ') Or (M='SUBQ') Then Begin
  If Not NeedOps(2) Then Exit;
  Sz:=DefSize(LnSz,2);
  If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
  CheckRange(Ops[1].V,Ops[1].U,1,8);
  Q:=Ops[1].V And 7;
  E:=EncEA(Ops[2],Sz,MA_ALT);
  If E<0 Then Exit;
  If (Ops[2].K=OK_AN) And (Sz=1) Then Begin BadSize;Exit;End;
  If M='ADDQ' Then Base:=$5000 Else Base:=$5100;
  OpW:=Base Or (Q Shl 9) Or (SzBits(Sz) Shl 6) Or E;
  Exit;
 End;
 If (M='ADDX') Or (M='SUBX') Or (M='ABCD') Or (M='SBCD') Then Begin
  If Not NeedOps(2) Then Exit;
  If M='ADDX' Then Base:=$D100 Else If M='SUBX' Then Base:=$9100
  Else If M='ABCD' Then Base:=$C100 Else Base:=$8100;
  If (M='ABCD') Or (M='SBCD') Then Sz:=1 Else Sz:=DefSize(LnSz,2);
  If (Ops[1].K=OK_DN) And (Ops[2].K=OK_DN) Then
   OpW:=Base Or (Ops[2].R Shl 9) Or (SzBits(Sz) Shl 6) Or Ops[1].R
  Else If (Ops[1].K=OK_PRE) And (Ops[2].K=OK_PRE) Then
   OpW:=Base Or (Ops[2].R Shl 9) Or (SzBits(Sz) Shl 6) Or 8 Or Ops[1].R
  Else BadMode;
  Exit;
 End;
 If M='CMPM' Then Begin
  If Not NeedOps(2) Then Exit;
  Sz:=DefSize(LnSz,2);
  If (Ops[1].K<>OK_POST) Or (Ops[2].K<>OK_POST) Then Begin BadMode;Exit;End;
  OpW:=$B108 Or (Ops[2].R Shl 9) Or (SzBits(Sz) Shl 6) Or Ops[1].R;
  Exit;
 End;
 If (M='MULU') Or (M='MULS') Or (M='DIVU') Or (M='DIVS') Or (M='CHK') Then Begin
  If Not NeedOps(2) Then Exit;
  If M='MULU' Then Base:=$C0C0 Else If M='MULS' Then Base:=$C1C0
  Else If M='DIVU' Then Base:=$80C0 Else If M='DIVS' Then Base:=$81C0
  Else Base:=$4180;
  If Ops[2].K<>OK_DN Then Begin BadMode;Exit;End;
  E:=EncEA(Ops[1],2,MA_DATA);
  If E<0 Then Exit;
  OpW:=Base Or (Ops[2].R Shl 9) Or E;
  Exit;
 End;
 GArith:=False;
End;

Function GMove(Const M: String): Boolean;
Var Sz,E,E2,SC: Integer; Mk,RM: LongInt; I: Integer;
Begin
 GMove:=True;
 If (M='MOVE') Or (M='MOVEA') Then Begin
  If Not NeedOps(2) Then Exit;
  If Ops[2].K=OK_SR Then Begin
   E:=EncEA(Ops[1],2,MA_DATA);If E<0 Then Exit;
   OpW:=$46C0 Or E;Exit;
  End;
  If Ops[2].K=OK_CCR Then Begin
   E:=EncEA(Ops[1],2,MA_DATA);If E<0 Then Exit;
   OpW:=$44C0 Or E;Exit;
  End;
  If Ops[1].K=OK_SR Then Begin
   E:=EncEA(Ops[2],2,MA_DALT);If E<0 Then Exit;
   OpW:=$40C0 Or E;Exit;
  End;
  If Ops[1].K=OK_CCR Then Begin
   E:=EncEA(Ops[2],2,MA_DALT);If E<0 Then Exit;
   OpW:=$42C0 Or E;Exit;
  End;
  If (Ops[1].K=OK_USP) And (Ops[2].K=OK_AN) Then Begin OpW:=$4E68 Or Ops[2].R;Exit;End;
  If (Ops[2].K=OK_USP) And (Ops[1].K=OK_AN) Then Begin OpW:=$4E60 Or Ops[1].R;Exit;End;
  Sz:=DefSize(LnSz,2);
  If Sz=1 Then SC:=1 Else If Sz=4 Then SC:=2 Else SC:=3;
  If Ops[2].K=OK_AN Then Begin
   If Sz=1 Then Begin BadSize;Exit;End;
   E:=EncEA(Ops[1],Sz,MA_ALL);If E<0 Then Exit;
   OpW:=(SC Shl 12) Or (Ops[2].R Shl 9) Or $40 Or E;
   Exit;
  End;
  If M='MOVEA' Then Begin BadMode;Exit;End;
  E:=EncEA(Ops[1],Sz,MA_ALL);If E<0 Then Exit;
  If (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSize;Exit;End;
  E2:=EncEA(Ops[2],Sz,MA_DALT);If E2<0 Then Exit;
  OpW:=(SC Shl 12) Or ((E2 And 7) Shl 9) Or ((E2 Shr 3) Shl 6) Or E;
  Exit;
 End;
 If M='MOVEQ' Then Begin
  If Not NeedOps(2) Then Exit;
  If (Ops[1].K<>OK_IMM) Or (Ops[2].K<>OK_DN) Then Begin BadMode;Exit;End;
  CheckRange(Ops[1].V,Ops[1].U,-128,255);
  OpW:=$7000 Or (Ops[2].R Shl 9) Or (Ops[1].V And $FF);
  Exit;
 End;
 If M='MOVEM' Then Begin
  If Not NeedOps(2) Then Exit;
  Sz:=DefSize(LnSz,2);
  If Sz=1 Then Begin BadSize;Exit;End;
  If (Ops[1].K=OK_LIST) Or (Ops[1].K=OK_DN) Or (Ops[1].K=OK_AN) Then Begin
   If Ops[1].K=OK_DN Then Ops[1].Mask:=LongInt(1) Shl Ops[1].R
   Else If Ops[1].K=OK_AN Then Ops[1].Mask:=LongInt(1) Shl (8+Ops[1].R);
   Mk:=Ops[1].Mask;
   If Ops[2].K=OK_PRE Then Begin
    RM:=0;
    For I:=0 To 15 Do If (Mk And (LongInt(1) Shl I))<>0 Then RM:=RM Or (LongInt(1) Shl (15-I));
    Mk:=RM;
   End;
   PutX(Mk And $FFFF,False,-1);
   E:=EncEA(Ops[2],Sz,MA_CALT Or KBit(OK_PRE));If E<0 Then Exit;
   OpW:=$4880 Or E;
   If Sz=4 Then OpW:=OpW Or $40;
  End Else If (Ops[2].K=OK_LIST) Or (Ops[2].K=OK_DN) Or (Ops[2].K=OK_AN) Then Begin
   If Ops[2].K=OK_DN Then Ops[2].Mask:=LongInt(1) Shl Ops[2].R
   Else If Ops[2].K=OK_AN Then Ops[2].Mask:=LongInt(1) Shl (8+Ops[2].R);
   PutX(Ops[2].Mask And $FFFF,False,-1);
   E:=EncEA(Ops[1],Sz,MA_CTRL Or KBit(OK_POST));If E<0 Then Exit;
   OpW:=$4C80 Or E;
   If Sz=4 Then OpW:=OpW Or $40;
  End Else BadMode;
  Exit;
 End;
 If M='MOVEP' Then Begin
  If Not NeedOps(2) Then Exit;
  Sz:=DefSize(LnSz,2);
  If Sz=1 Then Begin BadSize;Exit;End;
  If (Ops[1].K=OK_DN) And ((Ops[2].K=OK_DISP) Or (Ops[2].K=OK_IND)) Then Begin
   OpW:=$0188 Or (Ops[1].R Shl 9) Or Ops[2].R;
   If Sz=4 Then OpW:=OpW Or $40;
   PutX(Ops[2].V And $FFFF,False,-1);
  End Else If (Ops[2].K=OK_DN) And ((Ops[1].K=OK_DISP) Or (Ops[1].K=OK_IND)) Then Begin
   OpW:=$0108 Or (Ops[2].R Shl 9) Or Ops[1].R;
   If Sz=4 Then OpW:=OpW Or $40;
   PutX(Ops[1].V And $FFFF,False,-1);
  End Else BadMode;
  Exit;
 End;
 GMove:=False;
End;

Function GShift(Const M: String): Boolean;
Var T,Dir,Sz,E,Cnt,IR: Integer;
Begin
 GShift:=True;
 If (M='ASL') Or (M='ASR') Then T:=0
 Else If (M='LSL') Or (M='LSR') Then T:=1
 Else If (M='ROXL') Or (M='ROXR') Then T:=2
 Else If (M='ROL') Or (M='ROR') Then T:=3
 Else Begin GShift:=False;Exit;End;
 If M[Length(M)]='L' Then Dir:=1 Else Dir:=0;
 Sz:=DefSize(LnSz,2);
 If NOps=1 Then Begin
  If Ops[1].K=OK_DN Then Begin
   OpW:=$E000 Or (1 Shl 9) Or (Dir Shl 8) Or (SzBits(Sz) Shl 6) Or (T Shl 3) Or Ops[1].R;
  End Else Begin
   E:=EncEA(Ops[1],2,MA_MALT);If E<0 Then Exit;
   OpW:=$E0C0 Or (T Shl 9) Or (Dir Shl 8) Or E;
  End;
  Exit;
 End;
 If Not NeedOps(2) Then Exit;
 If Ops[2].K<>OK_DN Then Begin BadMode;Exit;End;
 If Ops[1].K=OK_DN Then Begin Cnt:=Ops[1].R;IR:=1;End
 Else If Ops[1].K=OK_IMM Then Begin
  CheckRange(Ops[1].V,Ops[1].U,1,8);
  Cnt:=Ops[1].V And 7;IR:=0;
 End Else Begin BadMode;Exit;End;
 OpW:=$E000 Or (Cnt Shl 9) Or (Dir Shl 8) Or (SzBits(Sz) Shl 6) Or (IR Shl 5) Or (T Shl 3) Or Ops[2].R;
End;

Function GBit(Const M: String): Boolean;
Var T,E: Integer; Sz: Integer; Al: LongInt;
Begin
 GBit:=True;
 If M='BTST' Then T:=0 Else If M='BCHG' Then T:=1
 Else If M='BCLR' Then T:=2 Else If M='BSET' Then T:=3
 Else Begin GBit:=False;Exit;End;
 If Not NeedOps(2) Then Exit;
 If T=0 Then Al:=MA_DATA Else Al:=MA_DALT;
 If Ops[2].K=OK_DN Then Sz:=4 Else Sz:=1;
 If Ops[1].K=OK_DN Then Begin
  E:=EncEA(Ops[2],Sz,Al);If E<0 Then Exit;
  OpW:=$0100 Or (T Shl 6) Or (Ops[1].R Shl 9) Or E;
 End Else If Ops[1].K=OK_IMM Then Begin
  PutX(Ops[1].V And $FF,False,-1);
  E:=EncEA(Ops[2],Sz,Al);If E<0 Then Exit;
  OpW:=$0800 Or (T Shl 6) Or E;
 End Else BadMode;
End;

Function GBranch(Const M: String): Boolean;
Var CC: Integer; Disp,Tgt,At: LongInt; Short,SameSec: Boolean; Sz: Integer;
    N: String;
Begin
 GBranch:=False;
 CC:=-1;
 If M='BRA' Then CC:=0
 Else If M='BSR' Then CC:=1
 Else If (Length(M)>=3) And (M[1]='B') And (M<>'BTST') And (M<>'BCHG') And
         (M<>'BCLR') And (M<>'BSET') And (M<>'BRA') And (M<>'BSR') Then Begin
  N:=Copy(M,2,2);
  CC:=CondCode(N);
  If (CC<=1) Then CC:=-1;
 End;
 If CC<0 Then Exit;
 GBranch:=True;
 If Not NeedOps(1) Then Exit;
 If (Ops[1].K<>OK_ABSL) And (Ops[1].K<>OK_ABSW) Then Begin BadMode;Exit;End;
 Tgt:=ImgOf(Ops[1].V,Ops[1].S);
 At:=InstrPC+2;
 Disp:=Tgt-At;
 Sz:=LnSz;
 If (Sz=1) Or (Sz=8) Then Short:=True
 Else If Sz=2 Then Short:=False
 Else Begin
  { taille automatique : decision enregistree a la passe 1 }
  Inc(DecIdx);
  If DecIdx>MAXDEC Then DecIdx:=MAXDEC;
  If AsmPassNo=1 Then Begin
   SameSec:=AbsMode Or (Ops[1].S=CurSect);
   Decs^[DecIdx]:=0;
   If Not Ops[1].U And SameSec And (Disp>=-128) And (Disp<=127) And (Disp<>0)
      And (Disp<>-1) Then Begin
    If OptOptimize Or (Disp<0) Then Decs^[DecIdx]:=1;
   End;
  End;
  Short:=Decs^[DecIdx]=1;
 End;
 If Short Then Begin
  If (AsmPassNo=2) And Not Ops[1].U Then
   If (Disp<-128) Or (Disp>127) Then
    Err3('Branch out of range','Branchement hors limites','Sprung ausserhalb des Bereichs');
  OpW:=$6000 Or (CC Shl 8) Or (Disp And $FF);
  If (Disp=0) And (Sz<>2) And (Ops[1].S=CurSect) Or ((Disp=0) And AbsMode) Then OpW:=$4E71;
 End Else Begin
  If (AsmPassNo=2) And Not Ops[1].U Then
   If (Disp<-32768) Or (Disp>32767) Then
    Err3('Branch out of range','Branchement hors limites','Sprung ausserhalb des Bereichs');
  OpW:=$6000 Or (CC Shl 8);
  PutX(Disp And $FFFF,False,-1);
 End;
End;

Function GMisc(Const M: String): Boolean;
Var E,CC: Integer; Disp,At: LongInt; N: String;
Begin
 GMisc:=True;
 If M='LEA' Then Begin
  If Not NeedOps(2) Then Exit;
  If Ops[2].K<>OK_AN Then Begin BadMode;Exit;End;
  E:=EncEA(Ops[1],4,MA_CTRL);If E<0 Then Exit;
  OpW:=$41C0 Or (Ops[2].R Shl 9) Or E;
 End Else If M='LINK' Then Begin
  If Not NeedOps(2) Then Exit;
  If (Ops[1].K<>OK_AN) Or (Ops[2].K<>OK_IMM) Then Begin BadMode;Exit;End;
  OpW:=$4E50 Or Ops[1].R;
  PutImm(Ops[2],2);
 End Else If M='UNLK' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_AN Then Begin BadMode;Exit;End;
  OpW:=$4E58 Or Ops[1].R;
 End Else If M='SWAP' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_DN Then Begin BadMode;Exit;End;
  OpW:=$4840 Or Ops[1].R;
 End Else If M='EXT' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_DN Then Begin BadMode;Exit;End;
  If LnSz=4 Then OpW:=$48C0 Or Ops[1].R
  Else If (LnSz=0) Or (LnSz=2) Then OpW:=$4880 Or Ops[1].R
  Else BadSize;
 End Else If M='EXG' Then Begin
  If Not NeedOps(2) Then Exit;
  If (Ops[1].K=OK_DN) And (Ops[2].K=OK_DN) Then
   OpW:=$C140 Or (Ops[1].R Shl 9) Or Ops[2].R
  Else If (Ops[1].K=OK_AN) And (Ops[2].K=OK_AN) Then
   OpW:=$C148 Or (Ops[1].R Shl 9) Or Ops[2].R
  Else If (Ops[1].K=OK_DN) And (Ops[2].K=OK_AN) Then
   OpW:=$C188 Or (Ops[1].R Shl 9) Or Ops[2].R
  Else If (Ops[1].K=OK_AN) And (Ops[2].K=OK_DN) Then
   OpW:=$C188 Or (Ops[2].R Shl 9) Or Ops[1].R
  Else BadMode;
 End Else If M='TRAP' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
  CheckRange(Ops[1].V,Ops[1].U,0,15);
  OpW:=$4E40 Or (Ops[1].V And 15);
 End Else If M='STOP' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
  OpW:=$4E72;
  PutImm(Ops[1],2);
 End Else If (M='DBRA') Or ((Length(M)>=3) And (Length(M)<=4) And (Copy(M,1,2)='DB') And (CondCode(Copy(M,3,2))>=0)) Then Begin
  If Not NeedOps(2) Then Exit;
  If M='DBRA' Then CC:=1 Else CC:=CondCode(Copy(M,3,2));
  If (Ops[1].K<>OK_DN) Or ((Ops[2].K<>OK_ABSL) And (Ops[2].K<>OK_ABSW)) Then Begin BadMode;Exit;End;
  At:=InstrPC+2;
  Disp:=ImgOf(Ops[2].V,Ops[2].S)-At;
  If (AsmPassNo=2) And Not Ops[2].U Then
   If (Disp<-32768) Or (Disp>32767) Then
    Err3('Branch out of range','Branchement hors limites','Sprung ausserhalb des Bereichs');
  OpW:=$50C8 Or (CC Shl 8) Or Ops[1].R;
  PutX(Disp And $FFFF,False,-1);
 End Else If (Length(M)>=2) And (Length(M)<=3) And (M[1]='S') And
             (M<>'SUB') And (CondCode(Copy(M,2,2))>=0) Then Begin
  If Not NeedOps(1) Then Exit;
  CC:=CondCode(Copy(M,2,2));
  E:=EncEA(Ops[1],1,MA_DALT);If E<0 Then Exit;
  OpW:=$50C0 Or (CC Shl 8) Or E;
 End Else GMisc:=False;
End;

Const
 MnList1 = ' NOP RTS RTE RTR RESET TRAPV ILLEGAL CLR NEG NEGX NOT TST JMP JSR PEA TAS NBCD ADD SUB AND OR EOR CMP '+
  'ADDI SUBI ANDI ORI EORI CMPI ADDA SUBA CMPA ADDQ SUBQ ADDX SUBX ABCD SBCD CMPM MULU MULS DIVU DIVS CHK ';
 MnList2 = ' MOVE MOVEA MOVEQ MOVEM MOVEP ASL ASR LSL LSR ROL ROR ROXL ROXR BTST BCHG BCLR BSET '+
  'LEA LINK UNLK SWAP EXT EXG TRAP STOP DBRA ';

Function IsMnemonic(Const M: String): Boolean;
Begin
 IsMnemonic:=True;
 If Pos(' '+M+' ',MnList1)>0 Then Exit;
 If Pos(' '+M+' ',MnList2)>0 Then Exit;
 If (Length(M)>=3) And (M[1]='B') And (CondCode(Copy(M,2,2))>=0) Then Exit;
 If M='BRA' Then Exit;
 If M='BSR' Then Exit;
 If (Length(M)>=3) And (Length(M)<=4) And (Copy(M,1,2)='DB') And (CondCode(Copy(M,3,2))>=0) Then Exit;
 If (Length(M)>=2) And (Length(M)<=3) And (M[1]='S') And (CondCode(Copy(M,2,2))>=0) Then Exit;
 IsMnemonic:=False;
End;

{ Assemble l'instruction courante : M est le mnemonique en majuscules }
Function AsmInstruction(Const M: String): Boolean;
Var I,N: Integer; Parts: Array[0..3] Of String;
Begin
 AsmInstruction:=True;
 If Not IsMnemonic(M) Then Begin AsmInstruction:=False;Exit;End;
 BadInstr:=False;XN:=0;XWords:=0;OpW:=0;
 NOps:=0;
 If LnArgs<>'' Then Begin
  N:=SplitTop(LnArgs,Parts,4);
  For I:=1 To N Do Begin
   OpStr[I]:=Parts[I-1];
   NOps:=N;
  End;
 End;
 If Odd(CurPC) Then ReserveBytes(1);
 InstrOff:=SecLen[CurSect];
 If AbsMode Then InstrOff:=SecLen[0];
 InstrPC:=ImgOf(InstrOff,CurSect);
 If AbsMode Then InstrPC:=OrgAddr+SecLen[0];
 For I:=1 To NOps Do ParseOp(OpStr[I],Ops[I]);
 If BadInstr Then Begin AsmInstruction:=True;Exit;End;
 If GImplied(M) Or GUnary(M) Or GArith(M) Or GMove(M) Or GShift(M) Or
    GBit(M) Or GBranch(M) Or GMisc(M) Then Begin
  FlushInstr;
 End Else AsmInstruction:=False;
End;

{ ---------------------------------------------------------------------- }
{ Chargement de fichiers texte                                            }
{ ---------------------------------------------------------------------- }

Function LoadLines(Const Name: String; Var Arr: PLineArr; Var Count: Integer): Boolean;
Var F: File; Buf: Array[0..4095] Of Byte; N,I: Integer; Cur: String;
    Got: Word; LastCR: Boolean;
Begin
 LoadLines:=False;
 Count:=0;
 Assign(F,Name);
 {$I-}
 Reset(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 New(Arr);
 Cur:='';LastCR:=False;
 Repeat
  BlockRead(F,Buf,SizeOf(Buf),Got);
  For I:=0 To Got-1 Do Begin
   If Buf[I]=13 Then Begin
    If Count<MAXLN Then Begin Inc(Count);Arr^[Count]:=NewStr(Cur);End;
    Cur:='';LastCR:=True;
   End Else If Buf[I]=10 Then Begin
    If Not LastCR Then Begin
     If Count<MAXLN Then Begin Inc(Count);Arr^[Count]:=NewStr(Cur);End;
     Cur:='';
    End;
    LastCR:=False;
   End Else Begin
    LastCR:=False;
    If Buf[I]=26 Then Begin End
    Else If Length(Cur)<250 Then Cur:=Cur+Chr(Buf[I]);
   End;
  End;
 Until Got=0;
 If Cur<>'' Then If Count<MAXLN Then Begin Inc(Count);Arr^[Count]:=NewStr(Cur);End;
 Close(F);
 LoadLines:=True;
End;

Procedure FreeLines(Arr: PLineArr; Count: Integer);
Var I: Integer;
Begin
 If Arr=Nil Then Exit;
 For I:=1 To Count Do FreeStr(Arr^[I]);
 Dispose(Arr);
End;

{ ---------------------------------------------------------------------- }
{ Pile des sources                                                        }
{ ---------------------------------------------------------------------- }

Procedure PushSrc(K: Integer; Lines: PLineArr; Count: Integer; Const Name: String; Own: Boolean);
Begin
 If SrcTop>=MAXSRC Then Begin
  Err3('Includes nested too deeply','Imbrications trop profondes','Zu tiefe Verschachtelung');
  Exit;
 End;
 Inc(SrcTop);
 FillChar(Srcs[SrcTop],SizeOf(TSrc),0);
 Srcs[SrcTop].Kind:=K;
 Srcs[SrcTop].Lines:=Lines;
 Srcs[SrcTop].Count:=Count;
 Srcs[SrcTop].Pos:=1;
 Srcs[SrcTop].Name:=Copy(Name,1,80);
 Srcs[SrcTop].Own:=Own;
 Srcs[SrcTop].Reps:=1;
End;

Procedure PopSrc;
Begin
 If SrcTop<=0 Then Exit;
 If Srcs[SrcTop].Own Then FreeLines(Srcs[SrcTop].Lines,Srcs[SrcTop].Count);
 Dec(SrcTop);
End;

Procedure UpdateLoc;
Var I: Integer;
Begin
 I:=SrcTop;
 While (I>0) And (Srcs[I].Kind<>0) Do Dec(I);
 If I>0 Then Begin
  CurLineNo:=Srcs[I].Pos-1;
  CurSrcName:=Srcs[I].Name;
 End;
End;

Function ParamIndex(Const Names,Nm: String): Integer;
Var I,K,P: Integer; Cur: String;
Begin
 ParamIndex:=0;
 K:=0;Cur:='';
 For I:=1 To Length(Names)+1 Do Begin
  If (I>Length(Names)) Or (Names[I]=',') Then Begin
   Inc(K);
   If (Cur<>'') And (Upper(TrimS(Cur))=Upper(Nm)) Then Begin ParamIndex:=K;Exit;End;
   Cur:='';
  End Else Cur:=Cur+Names[I];
 End;
End;

Function SubstMacro(Const S: String; Var T: TSrc): String;
Var R,Nm: String; I,K,J: Integer; C: Char;
Begin
 If Pos('\',S)=0 Then Begin SubstMacro:=S;Exit;End;
 R:='';I:=1;
 While I<=Length(S) Do Begin
  If (S[I]='\') And (I<Length(S)) Then Begin
   C:=S[I+1];
   If (C>='0') And (C<='9') Then Begin
    K:=Ord(C)-48;
    If K=0 Then R:=R+T.Suffix Else R:=R+T.Args[K];
    Inc(I,2);
   End Else If C='@' Then Begin
    R:=R+'_'+IntStr(T.MacId);
    Inc(I,2);
   End Else If IsIdStart(C) And (T.MacIdx>0) Then Begin
    J:=I+1;Nm:='';
    While (J<=Length(S)) And IsIdChar(S[J]) Do Begin Nm:=Nm+S[J];Inc(J);End;
    K:=ParamIndex(Macros[T.MacIdx].PNames,Nm);
    If (K>0) And (K<=9) Then Begin R:=R+T.Args[K];I:=J;End
    Else Begin R:=R+S[I];Inc(I);End;
   End Else Begin R:=R+S[I];Inc(I);End;
  End Else Begin R:=R+S[I];Inc(I);End;
 End;
 SubstMacro:=Copy(R,1,255);
End;

Function NextLine(Var S: String): Boolean;
Begin
 NextLine:=False;
 While SrcTop>0 Do Begin
  If Srcs[SrcTop].Pos>Srcs[SrcTop].Count Then Begin
   If (Srcs[SrcTop].Kind=2) And (Srcs[SrcTop].Reps>1) Then Begin
    Dec(Srcs[SrcTop].Reps);
    Srcs[SrcTop].Pos:=1;
   End Else PopSrc;
  End Else Begin
   S:=Srcs[SrcTop].Lines^[Srcs[SrcTop].Pos]^;
   Inc(Srcs[SrcTop].Pos);
   If Srcs[SrcTop].Kind=1 Then S:=SubstMacro(S,Srcs[SrcTop]);
   UpdateLoc;
   NextLine:=True;
   Exit;
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Analyse d'une ligne                                                     }
{ ---------------------------------------------------------------------- }

Procedure SplitLine(Const S: String; Var Lbl,Op,Suf,Args: String);
Var I,D: Integer; Q: Char; Tk: String;
Begin
 Lbl:='';Op:='';Suf:='';Args:='';
 I:=1;
 If S='' Then Exit;
 If (S[1]='*') Or (S[1]=';') Then Exit;
 If (S[1]<>' ') And (S[1]<>#9) Then Begin
  While (I<=Length(S)) And (S[I]<>' ') And (S[I]<>#9) Do Begin
   Lbl:=Lbl+S[I];Inc(I);
  End;
  If (Lbl<>'') And (Lbl[Length(Lbl)]=':') Then Delete(Lbl,Length(Lbl),1);
  If (Lbl<>'') And (Lbl[Length(Lbl)]=':') Then Delete(Lbl,Length(Lbl),1);
 End;
 While (I<=Length(S)) And ((S[I]=' ') Or (S[I]=#9)) Do Inc(I);
 If (I>Length(S)) Or (S[I]=';') Then Exit;
 If (S[I]='*') And (Lbl='') Then Exit;
 Tk:='';
 While (I<=Length(S)) And (S[I]<>' ') And (S[I]<>#9) And (S[I]<>';') Do Begin
  Tk:=Tk+S[I];Inc(I);
 End;
 D:=Pos('.',Tk);
 If (D>1) And (Tk[1]<>'.') Then Begin
  Op:=Upper(Copy(Tk,1,D-1));
  Suf:=Upper(Copy(Tk,D+1,10));
 End Else Op:=Upper(Tk);
 While (I<=Length(S)) And ((S[I]=' ') Or (S[I]=#9)) Do Inc(I);
 { champ des operandes }
 Q:=#0;D:=0;
 While I<=Length(S) Do Begin
  If Q<>#0 Then Begin
   Args:=Args+S[I];
   If S[I]=Q Then Q:=#0;
   Inc(I);
  End Else Begin
   Case S[I] Of
    '''','"': Begin Q:=S[I];Args:=Args+S[I];Inc(I);End;
    '(': Begin Inc(D);Args:=Args+S[I];Inc(I);End;
    ')': Begin Dec(D);Args:=Args+S[I];Inc(I);End;
    ';': If D<=0 Then Break Else Begin Args:=Args+S[I];Inc(I);End;
    ' ',#9: Begin
             If (D>0) Or ((Args<>'') And (Args[Length(Args)]=',')) Then Begin
              Inc(I);
             End Else Begin
              D:=I;
              While (D<=Length(S)) And ((S[D]=' ') Or (S[D]=#9)) Do Inc(D);
              If (D<=Length(S)) And (S[D]=',') Then I:=D
              Else Break;
              D:=0;
             End;
            End;
   Else Begin Args:=Args+S[I];Inc(I);End;
   End;
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Definition de symboles                                                  }
{ ---------------------------------------------------------------------- }

Var
 PassSerial : Integer;
 EndFlag    : Boolean;
 RSCount    : LongInt;
 OutFileName: String;

Procedure DefSym(Const NameIn: String; V: LongInt; Sc: Integer; Kind: Byte);
Var P: PSym; Name: String;
Begin
 Name:=LocalName(NameIn);
 P:=FindSym(Name);
 If P=Nil Then P:=AddSym(Name)
 Else If P^.Defd And (P^.Pas=PassSerial) Then Begin
  If (Kind<>1) Or (P^.Kind<>1) Then Begin
   Err3('Symbol already defined: '+NameIn,'Symbole deja defini : '+NameIn,
        'Symbol bereits definiert: '+NameIn);
   Exit;
  End;
 End Else If (AsmPassNo=2) And P^.Defd And (Kind=0) And (P^.Kind=0) Then Begin
  If (P^.Value<>V) Or (P^.Sect<>Sc) Then
   Err3('Phasing error: '+NameIn,'Erreur de phase : '+NameIn,'Phasenfehler: '+NameIn);
 End;
 P^.Value:=V;P^.Sect:=Sc;P^.Kind:=Kind;P^.Defd:=True;P^.Pas:=PassSerial;
End;

Procedure DefLabel(Const Name: String);
Var Sc: Integer;
Begin
 If AbsMode Then Sc:=SEC_ABS Else Sc:=CurSect;
 DefSym(Name,CurPC,Sc,0);
 If (Name<>'') And (Name[1]<>'.') And (Name[Length(Name)]<>'$') Then
  LastGlobal:=Copy(Name,1,63);
End;

{ ---------------------------------------------------------------------- }
{ Conditionnels                                                           }
{ ---------------------------------------------------------------------- }

Procedure SetCondActive;
Begin
 If CondTop=0 Then CondActive:=True Else CondActive:=Conds[CondTop].Active;
End;

Procedure CondPush(Test: Boolean);
Begin
 If CondTop>=MAXCOND Then Begin
  Err3('Conditionals nested too deeply','Conditionnels trop imbriques','Zu tiefe Verschachtelung');
  Exit;
 End;
 Inc(CondTop);
 Conds[CondTop].Parent:=CondActive;
 Conds[CondTop].Active:=CondActive And Test;
 Conds[CondTop].Taken:=Conds[CondTop].Active;
 SetCondActive;
End;

Function StrOperand(Const S0: String): String;
Var S: String;
Begin
 S:=TrimS(S0);
 If (Length(S)>=2) And ((S[1]='''') Or (S[1]='"')) And (S[Length(S)]=S[1]) Then
  S:=Copy(S,2,Length(S)-2);
 StrOperand:=S;
End;

Function CondDirective(Const Op0,Args: String): Boolean;
Var R: TTV; Test: Boolean; Parts: Array[0..3] Of String; N: Integer; P: PSym; Op: String;
Begin
 CondDirective:=True;
 Op:=Op0;
 If Op='IFDEF' Then Op:='IFD' Else If Op='IFNDEF' Then Op:='IFND';
 If (Op='ENDC') Or (Op='ENDIF') Then Begin
  If CondTop=0 Then Err3('ENDC without IF','ENDC sans IF','ENDC ohne IF')
  Else Begin Dec(CondTop);SetCondActive;End;
  Exit;
 End;
 If Op='ELSE' Then Begin
  If CondTop=0 Then Err3('ELSE without IF','ELSE sans IF','ELSE ohne IF')
  Else Begin
   Conds[CondTop].Active:=Conds[CondTop].Parent And Not Conds[CondTop].Taken;
   If Conds[CondTop].Active Then Conds[CondTop].Taken:=True;
   SetCondActive;
  End;
  Exit;
 End;
 If (Op='IFEQ') Or (Op='IFNE') Or (Op='IFGT') Or (Op='IFGE') Or (Op='IFLT') Or
    (Op='IFLE') Or (Op='IF') Then Begin
  Test:=False;
  If CondActive Then Begin
   If Not EvalStr(Args,R) Then R.V:=0;
   If Op='IFEQ' Then Test:=R.V=0
   Else If (Op='IFNE') Or (Op='IF') Then Test:=R.V<>0
   Else If Op='IFGT' Then Test:=R.V>0
   Else If Op='IFGE' Then Test:=R.V>=0
   Else If Op='IFLT' Then Test:=R.V<0
   Else Test:=R.V<=0;
  End;
  CondPush(Test);
  Exit;
 End;
 If (Op='IFD') Or (Op='IFND') Then Begin
  Test:=False;
  If CondActive Then Begin
   P:=FindSym(LocalName(TrimS(Args)));
   Test:=(P<>Nil) And P^.Defd;
   If Op='IFND' Then Test:=Not Test;
  End;
  CondPush(Test);
  Exit;
 End;
 If (Op='IFC') Or (Op='IFNC') Then Begin
  Test:=False;
  If CondActive Then Begin
   N:=SplitTop(Args,Parts,4);
   If N=2 Then Test:=StrOperand(Parts[0])=StrOperand(Parts[1]);
   If Op='IFNC' Then Test:=Not Test;
  End;
  CondPush(Test);
  Exit;
 End;
 CondDirective:=False;
End;

{ ---------------------------------------------------------------------- }
{ Macros et REPT                                                          }
{ ---------------------------------------------------------------------- }

Var TmpBody : PLineArr;

Function CollectBody(Const OpStart,OpEnd: String; Var Cnt: Integer): PLineArr;
Var S,L,O,Sf,A: String; Depth,I: Integer; Res: PLineArr; Done: Boolean;
Begin
 Cnt:=0;Depth:=0;Done:=False;
 While Not Done Do Begin
  If Not NextLine(S) Then Begin
   Err3('Unexpected end of file in '+OpStart,'Fin de fichier inattendue dans '+OpStart,
        'Unerwartetes Dateiende in '+OpStart);
   Break;
  End;
  SplitLine(S,L,O,Sf,A);
  If O=OpStart Then Inc(Depth)
  Else If O=OpEnd Then Begin
   If Depth=0 Then Begin Done:=True;Continue;End;
   Dec(Depth);
  End;
  If Cnt<MAXLN Then Begin Inc(Cnt);TmpBody^[Cnt]:=NewStr(S);End;
 End;
 GetMem(Res,Cnt*SizeOf(PString)+4);
 For I:=1 To Cnt Do Res^[I]:=TmpBody^[I];
 CollectBody:=Res;
End;

Procedure FreeMacros;
Var I,J: Integer;
Begin
 For I:=1 To MacCount Do Begin
  For J:=1 To Macros[I].Count Do FreeStr(Macros[I].Body^[J]);
  FreeMem(Macros[I].Body,Macros[I].Count*SizeOf(PString)+4);
 End;
 MacCount:=0;
End;

Function FindMacro(Const Name: String): Integer;
Var I: Integer;
Begin
 FindMacro:=0;
 For I:=1 To MacCount Do If Macros[I].Name=Name Then Begin FindMacro:=I;Exit;End;
End;

Procedure DefineMacro(Const Name,PNames: String);
Var Cnt: Integer; B: PLineArr; I: Integer;
Begin
 B:=CollectBody('MACRO','ENDM',Cnt);
 If Name='' Then Begin
  Err3('Macro name missing','Nom de macro manquant','Makroname fehlt');
 End Else If MacCount>=MAXMAC Then Err3('Too many macros','Trop de macros','Zu viele Makros')
 Else Begin
  I:=FindMacro(Upper(Name));
  If I<>0 Then Begin
   Err3('Macro already defined','Macro deja definie','Makro bereits definiert');
  End Else Begin
   Inc(MacCount);
   Macros[MacCount].Name:=Copy(Upper(Name),1,40);
   Macros[MacCount].PNames:=Copy(PNames,1,100);
   Macros[MacCount].Body:=B;
   Macros[MacCount].Count:=Cnt;
   Exit;
  End;
 End;
 For I:=1 To Cnt Do FreeStr(B^[I]);
 FreeMem(B,Cnt*SizeOf(PString)+4);
End;

Procedure CallMacro(Idx: Integer; Const Args,Suf: String);
Var Parts: Array[0..9] Of String; N,I: Integer; A: String;
Begin
 N:=SplitTop(Args,Parts,10);
 PushSrc(1,Macros[Idx].Body,Macros[Idx].Count,Macros[Idx].Name,False);
 If SrcTop=0 Then Exit;
 With Srcs[SrcTop] Do Begin
  Inc(MacUniq);
  MacId:=MacUniq;
  NArg:=N;
  MacIdx:=Idx;
  Suffix:=Copy(Suf,1,8);
  For I:=1 To 9 Do Begin
   If I<=N Then Begin
    A:=Parts[I-1];
    If (Length(A)>=2) And (A[1]='<') And (A[Length(A)]='>') Then
     A:=Copy(A,2,Length(A)-2);
    Args[I]:=Copy(A,1,100);
   End Else Args[I]:='';
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Directives de donnees                                                   }
{ ---------------------------------------------------------------------- }

Procedure DirDC(Sz: Integer; Const Args: String);
Var Parts: Array[0..39] Of String; N,I,J: Integer; R: TTV; S: String; Q: Char;
Begin
 If Sz=0 Then Sz:=2;
 If Sz=8 Then Sz:=1;
 N:=SplitTop(Args,Parts,40);
 If N=0 Then Begin
  Err3('Operand expected','Operande attendue','Operand erwartet');Exit;
 End;
 For I:=0 To N-1 Do Begin
  S:=Parts[I];
  If (S<>'') And ((S[1]='''') Or (S[1]='"')) And (Sz=1) Then Begin
   Q:=S[1];
   { chaine pure ? }
   J:=2;
   While J<=Length(S) Do Begin
    If S[J]=Q Then Begin
     If (J<Length(S)) And (S[J+1]=Q) Then Inc(J) Else Break;
    End;
    Inc(J);
   End;
   If J=Length(S) Then Begin
    J:=2;
    While J<Length(S) Do Begin
     EmitByte(Ord(S[J]));
     If S[J]=Q Then Inc(J);
     Inc(J);
    End;
    Continue;
   End;
  End;
  If Not EvalStr(S,R) Then R.V:=0;
  Case Sz Of
   1: Begin CheckRange(R.V,R.U,-256,255);EmitByte(R.V And $FF);End;
   2: Begin CheckRange(R.V,R.U,-32768,65535);EmitWord(R.V And $FFFF);End;
  Else EmitLong(ImgOf(R.V,R.S),R.S);
  End;
 End;
End;

Function ReadFileBytes(Const Name: String; Var P: Pointer; Var Len: LongInt): Boolean;
Var F: File;
Begin
 ReadFileBytes:=False;P:=Nil;Len:=0;
 Assign(F,Name);
 {$I-}
 Reset(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 Len:=FileSize(F);
 If Len>0 Then Begin
  GetMem(P,Len);
  BlockRead(F,P^,Len);
 End;
 Close(F);
 ReadFileBytes:=True;
End;

Function FindInclude(Const Name: String): String;
Var Cand: String;
Begin
 If FileExists(Name) Then Begin FindInclude:=Name;Exit;End;
 Cand:=PathOf(AsmFileName)+Name;
 If FileExists(Cand) Then Begin FindInclude:=Cand;Exit;End;
 If OptIncPath<>'' Then Begin
  Cand:=OptIncPath;
  If (Cand[Length(Cand)]<>'\') And (Cand[Length(Cand)]<>'/') And (Cand[Length(Cand)]<>':') Then
   Cand:=Cand+'/';
  Cand:=Cand+Name;
  If FileExists(Cand) Then Begin FindInclude:=Cand;Exit;End;
 End;
 FindInclude:='';
End;

Procedure DirOpt(Const Args: String);
Var Parts: Array[0..19] Of String; N,I: Integer; S: String; On: Boolean;
Begin
 N:=SplitTop(Args,Parts,20);
 For I:=0 To N-1 Do Begin
  S:=Upper(Parts[I]);
  If S='' Then Continue;
  On:=True;
  If S[Length(S)]='+' Then Delete(S,Length(S),1)
  Else If S[Length(S)]='-' Then Begin On:=False;Delete(S,Length(S),1);End;
  If S='D' Then OptDebug:=On
  Else If (S='O') Or (S='O1') Or (S='O2') Then OptOptimize:=On
  Else If S='C' Then OptCase:=On
  Else If S='W' Then OptWarnings:=On
  Else If S='L' Then Begin End;
 End;
End;

Procedure DirSection(Const Op,Args: String);
Var N: String; P: Integer;
Begin
 If AbsMode Then Exit;
 If (Op='TEXT') Or (Op='CODE') Then CurSect:=SEC_TEXT
 Else If Op='DATA' Then CurSect:=SEC_DATA
 Else If Op='BSS' Then CurSect:=SEC_BSS
 Else Begin
  N:=Upper(Args);
  P:=Pos(',',N);
  If P>0 Then N:=Copy(N,P+1,40);
  If Copy(N,1,4)='DATA' Then CurSect:=SEC_DATA
  Else If Copy(N,1,3)='BSS' Then CurSect:=SEC_BSS
  Else CurSect:=SEC_TEXT;
 End;
End;

Procedure PByteSet(P: Pointer; I: LongInt; V: Byte);
Var Q: ^Byte;
Begin
 Q:=PtrAdd(P,I);
 Q^:=V;
End;

Function PByteAt(P: Pointer; I: LongInt): Byte;
Var Q: ^Byte;
Begin
 Q:=PtrAdd(P,I);
 PByteAt:=Q^;
End;

{ Traite une directive ; retourne True si Op en est une }
Function Directive(Const Lbl,Op,Args: String; Sz: Integer): Boolean;
Var R: TTV; V: LongInt; Parts: Array[0..3] Of String; N,K: Integer; I: LongInt;
    FN,Full: String; Lines: PLineArr; Cnt: Integer; P: Pointer; Len: LongInt;
    SzB: Integer; Sy: PSym; Mk: LongInt;
Begin
 Directive:=True;
 If Sz=0 Then SzB:=2 Else If Sz=8 Then SzB:=1 Else SzB:=Sz;
 If Op='DC' Then Begin DirDC(Sz,Args);Exit;End;
 If Op='DS' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If R.V<0 Then R.V:=0;
  ReserveBytes(R.V*SzB);
  Exit;
 End;
 If Op='DCB' Then Begin
  N:=SplitTop(Args,Parts,4);
  If N<>2 Then Begin Err3('Operand expected','Operande attendue','Operand erwartet');Exit;End;
  If Not EvalStr(Parts[0],R) Then R.V:=0;
  K:=R.V;
  If Not EvalStr(Parts[1],R) Then R.V:=0;
  For I:=1 To K Do Begin
   If SzB=1 Then EmitByte(R.V And $FF)
   Else If SzB=2 Then EmitWord(R.V And $FFFF)
   Else EmitLong(ImgOf(R.V,R.S),R.S);
  End;
  Exit;
 End;
 If Op='EVEN' Then Begin EvenPC;Exit;End;
 If Op='CNOP' Then Begin
  N:=SplitTop(Args,Parts,4);
  If N<>2 Then Begin Err3('Operand expected','Operande attendue','Operand erwartet');Exit;End;
  If Not EvalStr(Parts[0],R) Then R.V:=0;
  V:=R.V;
  If Not EvalStr(Parts[1],R) Then R.V:=1;
  If R.V<=0 Then R.V:=1;
  While (CurPC Mod R.V)<>(V Mod R.V) Do ReserveBytes(1);
  Exit;
 End;
 If Op='ORG' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If Not AbsMode And (SecLen[0]=0) And (SecLen[1]=0) And (SecLen[2]=0) Then Begin
   AbsMode:=True;OrgAddr:=R.V;
  End Else If AbsMode Then Begin
   If R.V>=CurPC Then ReserveBytes(R.V-CurPC)
   Else Err3('ORG goes backwards','ORG recule','ORG geht rueckwaerts');
  End Else Err3('ORG must be the first statement','ORG doit etre la premiere instruction',
                'ORG muss die erste Anweisung sein');
  Exit;
 End;
 If (Op='SECTION') Or (Op='TEXT') Or (Op='DATA') Or (Op='BSS') Or (Op='CODE') Then Begin
  DirSection(Op,Args);Exit;
 End;
 If (Op='EQU') Or (Op='=') Or (Op='SET') Or (Op='EQUR') Then Begin
  If Lbl='' Then Begin Err3('Label expected','Etiquette attendue','Label erwartet');Exit;End;
  If Not EvalStr(Args,R) Then Begin R.V:=0;R.S:=SEC_ABS;End;
  If Op='SET' Then DefSym(Lbl,R.V,R.S,1) Else DefSym(Lbl,R.V,R.S,0);
  Exit;
 End;
 If Op='REG' Then Begin
  If Lbl='' Then Begin Err3('Label expected','Etiquette attendue','Label erwartet');Exit;End;
  If Not ParseRegList(Upper(TrimS(Args)),Mk) Then Begin
   N:=RegOf(Upper(TrimS(Args)));
   If (N>=0) And (N<16) Then Mk:=LongInt(1) Shl N
   Else Begin Err3('Bad register list','Liste de registres incorrecte','Falsche Registerliste');Exit;End;
  End;
  DefSym(Lbl,Mk,SEC_ABS,2);
  Exit;
 End;
 If Op='RSRESET' Then Begin RSCount:=0;Exit;End;
 If Op='RSSET' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  RSCount:=R.V;Exit;
 End;
 If Op='RS' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If SzB>1 Then If Odd(RSCount) Then Inc(RSCount);
  If Lbl<>'' Then DefSym(Lbl,RSCount,SEC_ABS,0);
  RSCount:=RSCount+R.V*SzB;
  Exit;
 End;
 If (Op='INCLUDE') Or (Op='INCBIN') Then Begin
  FN:=StrOperand(Args);
  If (FN<>'') And (FN[1]='<') Then FN:=Copy(FN,2,Length(FN)-2);
  Full:=FindInclude(FN);
  If Full='' Then Begin
   Err3('Cannot open file: '+FN,'Impossible d''ouvrir le fichier : '+FN,'Datei nicht lesbar: '+FN);
   Exit;
  End;
  If Op='INCLUDE' Then Begin
   If LoadLines(Full,Lines,Cnt) Then PushSrc(0,Lines,Cnt,Full,True)
   Else Err3('Cannot read file: '+FN,'Impossible de lire le fichier : '+FN,'Datei nicht lesbar: '+FN);
  End Else Begin
   If ReadFileBytes(Full,P,Len) Then Begin
    For I:=0 To Len-1 Do EmitByte(PByteAt(P,I));
    If P<>Nil Then FreeMem(P,Len);
   End;
  End;
  Exit;
 End;
 If Op='OPT' Then Begin DirOpt(Args);Exit;End;
 If Op='END' Then Begin EndFlag:=True;Exit;End;
 If Op='OUTPUT' Then Begin
  OutFileName:=StrOperand(Args);
  Exit;
 End;
 If Op='FAIL' Then Begin
  Err3('FAIL: '+Args,'FAIL : '+Args,'FAIL: '+Args);Exit;
 End;
 If Op='MEXIT' Then Begin
  K:=SrcTop;
  While (K>0) And (Srcs[K].Kind<>1) Do Dec(K);
  If K>0 Then While SrcTop>=K Do PopSrc;
  Exit;
 End;
 If Op='REPT' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  Lines:=CollectBody('REPT','ENDR',Cnt);
  If (R.V>0) And (Cnt>0) Then Begin
   PushSrc(2,Lines,Cnt,'REPT',True);
   Srcs[SrcTop].Reps:=R.V;
  End Else FreeLines(Lines,Cnt);
  Exit;
 End;
 If (Op='ENDR') Or (Op='ENDM') Then Begin
  Err3('Unexpected '+Op,Op+' inattendu',Op+' unerwartet');Exit;
 End;
 If (Op='LIST') Or (Op='NOLIST') Or (Op='PAGE') Or (Op='TTL') Or (Op='SUBTTL') Or
    (Op='LLEN') Or (Op='PLEN') Or (Op='SPC') Or (Op='IDNT') Or (Op='FORMAT') Or
    (Op='NOPAGE') Or (Op='XDEF') Or (Op='XREF') Or (Op='PUBLIC') Or (Op='GLOBAL') Or
    (Op='EXPORT') Or (Op='IMPORT') Or (Op='COMMENT') Or (Op='ECHO') Or (Op='NOFORMAT') Or
    (Op='MASK2') Or (Op='OFFSET') Then Exit;
 Directive:=False;
End;

{ ---------------------------------------------------------------------- }
{ Traitement d'une ligne source                                           }
{ ---------------------------------------------------------------------- }

Var
 OptDebug0,OptOptimize0,OptCase0,OptWarnings0 : Boolean;
 OutPathFinal : String;
 OutIsTemp    : Boolean;

Function IsValueDirective(Const Op: String): Boolean;
Begin
 IsValueDirective:=(Op='EQU') Or (Op='=') Or (Op='SET') Or (Op='REG') Or
  (Op='EQUR') Or (Op='RS') Or (Op='RSSET') Or (Op='RSRESET');
End;

Procedure ListLine(Const S: String);
Var Ln,B: String; I: Integer; Sect: Integer; N: LongInt;
Begin
 If Not ListOn Then Exit;
 Ln:=PadL(IntStr(CurLineNo),5)+' ';
 Sect:=CurSect;If AbsMode Then Sect:=0;
 If (LnStartLen<>SecLen[Sect]) Or (LnAddr>=0) Then Begin
  Ln:=Ln+Hex6(LnAddr)+' ';
  B:='';
  N:=SecLen[Sect]-LnStartLen;
  If N>6 Then N:=6;
  If Sect<>SEC_BSS Then
   For I:=0 To N-1 Do B:=B+Hex2(SecGet(Sect,LnStartLen+I));
  Ln:=Ln+PadR(B,13);
 End Else Ln:=Ln+PadR('',20);
 WriteLn(ListF,Ln+S);
End;

Procedure ProcessLine(Const S: String);
Var Lbl,Op,Suf,Args: String; Sz,M: Integer; Even,IsInstr: Boolean; Sect: Integer;
Begin
 LnText:=S;
 SplitLine(S,Lbl,Op,Suf,Args);
 LnStartLen:=SecLen[CurSect];
 If AbsMode Then LnStartLen:=SecLen[0];
 LnAddr:=CurPC;
 If (Op<>'') And CondDirective(Op,Args) Then Begin
  If AsmPassNo=2 Then ListLine(S);
  Exit;
 End;
 If Not CondActive Then Exit;
 If Op='' Then Begin
  If Lbl<>'' Then DefLabel(Lbl);
  If AsmPassNo=2 Then ListLine(S);
  Exit;
 End;
 Sz:=0;
 If Suf<>'' Then Begin
  Case Suf[1] Of
   'B': Sz:=1;
   'W': Sz:=2;
   'L': Sz:=4;
   'S': Sz:=8;
  Else Err3('Bad size suffix','Suffixe de taille incorrect','Falsche Groessenangabe');
  End;
  If Length(Suf)>1 Then Err3('Bad size suffix','Suffixe de taille incorrect','Falsche Groessenangabe');
 End;
 LnSz:=Sz;
 LnArgs:=Args;
 If Op='MACRO' Then Begin
  If Lbl<>'' Then DefineMacro(Lbl,Args) Else DefineMacro(TrimS(Args),'');
  Exit;
 End;
 M:=FindMacro(Op);
 If IsValueDirective(Op) And (M=0) Then Begin
  Directive(Lbl,Op,Args,Sz);
  If AsmPassNo=2 Then ListLine(S);
  Exit;
 End;
 IsInstr:=IsMnemonic(Op) And (M=0);
 Even:=IsInstr Or (((Op='DC') Or (Op='DCB')) And ((Sz=2) Or (Sz=4) Or (Sz=0))) Or
       ((Op='DS') And ((Sz=2) Or (Sz=4) Or (Sz=0)));
 If Even And Odd(CurPC) And (CurSect<>SEC_BSS) Then Begin
  EvenPC;
  LnAddr:=CurPC;
  LnStartLen:=SecLen[CurSect];
  If AbsMode Then LnStartLen:=SecLen[0];
 End;
 If Even And Odd(CurPC) And (CurSect=SEC_BSS) Then Begin
  ReserveBytes(1);LnAddr:=CurPC;
 End;
 If (Lbl<>'') And (Op<>'MACRO') Then DefLabel(Lbl);
 If M<>0 Then CallMacro(M,Args,Suf)
 Else If Directive(Lbl,Op,Args,Sz) Then
 Else If Not AsmInstruction(Op) Then
  Err3('Unknown opcode: '+Op,'Code operation inconnu : '+Op,'Unbekannter Befehl: '+Op);
 If AsmPassNo=2 Then ListLine(S);
End;

{ ---------------------------------------------------------------------- }
{ Passes                                                                  }
{ ---------------------------------------------------------------------- }

Function EvenUp(N: LongInt): LongInt;
Begin
 If Odd(N) Then EvenUp:=N+1 Else EvenUp:=N;
End;

Procedure RunPass(Lines: PLineArr; Count: Integer);
Var S: String; I: Integer;
Begin
 Inc(PassSerial);
 For I:=0 To 2 Do SecLen[I]:=0;
 CurSect:=SEC_TEXT;AbsMode:=False;OrgAddr:=0;
 RelocN:=0;DecIdx:=0;CondTop:=0;CondActive:=True;SrcTop:=0;
 FreeMacros;
 EndFlag:=False;RSCount:=0;LastGlobal:='';MacUniq:=0;LastErrLine:=0;
 OptDebug:=OptDebug0;OptOptimize:=OptOptimize0;OptCase:=OptCase0;OptWarnings:=OptWarnings0;
 OutFileName:='';
 AsmLines:=0;
 PushSrc(0,Lines,Count,AsmFileName,False);
 While (Not EndFlag) And NextLine(S) Do Begin
  Inc(AsmLines);
  ProcessLine(S);
 End;
 While SrcTop>0 Do PopSrc;
 If (AsmPassNo=2) And (CondTop>0) Then Begin
  CurLineNo:=Count;CurSrcName:=AsmFileName;LnText:='';
  Err3('Missing ENDC','ENDC manquant','ENDC fehlt');
 End;
End;

Function SymChecksum: LongInt;
Var I: Integer; P: PSym; H: LongInt;
Begin
 H:=0;
 For I:=0 To HASHSZ-1 Do Begin
  P:=Hash[I];
  While P<>Nil Do Begin
   If P^.Defd Then H:=H*31+P^.Value*7+P^.Sect;
   P:=P^.Next;
  End;
 End;
 For I:=0 To 2 Do H:=H*17+SecLen[I];
 SymChecksum:=H;
End;

Procedure ComputeBases;
Begin
 If AmigaMode Or AbsMode Then Begin
  SecBase[0]:=0;SecBase[1]:=0;SecBase[2]:=0;
 End Else Begin
  SecBase[0]:=0;
  SecBase[1]:=EvenUp(SecLen[0]);
  SecBase[2]:=SecBase[1]+EvenUp(SecLen[1]);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Fichiers de sortie                                                      }
{ ---------------------------------------------------------------------- }

Var
 OutF   : File;
 OBuf   : Array[0..4095] Of Byte;
 OPos   : Integer;
 OutOk  : Boolean;

Procedure OutFlush;
Begin
 If OPos>0 Then BlockWrite(OutF,OBuf,OPos);
 OPos:=0;
End;

Procedure OutByte(B: Byte);
Begin
 If OPos>=SizeOf(OBuf) Then OutFlush;
 OBuf[OPos]:=B;Inc(OPos);
End;

Procedure OutWord(W: LongInt);
Begin
 OutByte((W Shr 8) And $FF);OutByte(W And $FF);
End;

Procedure OutLong(L: LongInt);
Begin
 OutWord(ShrL(L,16));OutWord(L And $FFFF);
End;

Function OpenOut(Const Name: String): Boolean;
Begin
 Assign(OutF,Name);
 {$I-}
 Rewrite(OutF,1);
 {$I+}
 OPos:=0;
 OpenOut:=IOResult=0;
End;

Procedure CloseOut;
Begin
 OutFlush;
 Close(OutF);
End;

Function SymTypeOf(P: PSym; Var T: Word; Var V: LongInt): Boolean;
Begin
 SymTypeOf:=False;
 If Not P^.Defd Then Exit;
 If P^.Kind<>0 Then Exit;
 If P^.Sect<0 Then Exit;
 If Pos('~',P^.Name)>0 Then Exit;
 T:=$8000;
 Case P^.Sect Of
  0: T:=T Or $0200;
  1: T:=T Or $0400;
  2: T:=T Or $0100;
 End;
 V:=P^.Value+SecBase[P^.Sect];
 SymTypeOf:=True;
End;

Function PrgSymbolBytes: LongInt;
Var I: Integer; P: PSym; N: LongInt; T: Word; V: LongInt;
Begin
 N:=0;
 For I:=0 To HASHSZ-1 Do Begin
  P:=Hash[I];
  While P<>Nil Do Begin
   If SymTypeOf(P,T,V) Then Begin
    Inc(N);
    If Length(P^.Name)>8 Then Inc(N);
   End;
   P:=P^.Next;
  End;
 End;
 PrgSymbolBytes:=N*14;
End;

Procedure SortLongs(Var A: TLongArr; N: Integer);
Var Gap,I,J: Integer; T: LongInt;
Begin
 Gap:=N Div 2;
 While Gap>0 Do Begin
  For I:=Gap To N-1 Do Begin
   T:=A[I];J:=I;
   While (J>=Gap) And (A[J-Gap]>T) Do Begin A[J]:=A[J-Gap];J:=J-Gap;End;
   A[J]:=T;
  End;
  Gap:=Gap Div 2;
 End;
End;

Function WritePRG(Const Name: String): Boolean;
Var TS,DS,BS,SS,I,J: LongInt; P: PSym; H: Integer; T: Word; V: LongInt;
    RO: PLongArr; Prev,D: LongInt; Nm: String;
Begin
 WritePRG:=False;
 If Not OpenOut(Name) Then Exit;
 TS:=EvenUp(SecLen[0]);DS:=EvenUp(SecLen[1]);BS:=SecLen[2];
 If OptDebug Then SS:=PrgSymbolBytes Else SS:=0;
 OutWord($601A);OutLong(TS);OutLong(DS);OutLong(BS);OutLong(SS);
 OutLong(0);OutLong(0);OutWord(0);
 For I:=0 To TS-1 Do OutByte(SecGet(0,I));
 For I:=0 To DS-1 Do OutByte(SecGet(1,I));
 If OptDebug Then
  For H:=0 To HASHSZ-1 Do Begin
   P:=Hash[H];
   While P<>Nil Do Begin
    If SymTypeOf(P,T,V) Then Begin
     Nm:=P^.Name;
     If Length(Nm)>8 Then T:=T Or $0048;
     For J:=1 To 8 Do If J<=Length(Nm) Then OutByte(Ord(Nm[J])) Else OutByte(0);
     OutWord(T);OutLong(V);
     If Length(Nm)>8 Then Begin
      For J:=9 To 22 Do If J<=Length(Nm) Then OutByte(Ord(Nm[J])) Else OutByte(0);
     End;
    End;
    P:=P^.Next;
   End;
  End;
 { table de relocation }
 GetMem(RO,SizeOf(TLongArr));
 For I:=1 To RelocN Do Begin
  RO^[I-1]:=RelocPos^[I];
  If RelocSrc^[I]=1 Then RO^[I-1]:=RO^[I-1]+SecBase[1];
 End;
 If RelocN>1 Then SortLongs(RO^,RelocN);
 If RelocN=0 Then OutLong(0)
 Else Begin
  OutLong(RO^[0]);
  Prev:=RO^[0];
  For I:=1 To RelocN-1 Do Begin
   D:=RO^[I]-Prev;Prev:=RO^[I];
   If D<>0 Then Begin
    While D>254 Do Begin OutByte(1);D:=D-254;End;
    OutByte(D);
   End;
  End;
  OutByte(0);
 End;
 FreeMem(RO,SizeOf(TLongArr));
 CloseOut;
 WritePRG:=True;
End;

Function WriteBin(Const Name: String): Boolean;
Var I: LongInt;
Begin
 WriteBin:=False;
 If Not OpenOut(Name) Then Exit;
 For I:=0 To SecLen[0]-1 Do OutByte(SecGet(0,I));
 CloseOut;
 WriteBin:=True;
End;

Function WriteHunk(Const Name: String): Boolean;
Var Hn: Array[0..2] Of Integer; NH,S,T: Integer; I,J,K,Cnt: LongInt; Sz: LongInt; P: PSym; H: Integer;
    Nm: String; Pad: Integer;
Begin
 WriteHunk:=False;
 If Not OpenOut(Name) Then Exit;
 NH:=0;
 For S:=0 To 2 Do Begin
  If (S=0) Or (SecLen[S]>0) Then Begin Hn[S]:=NH;Inc(NH);End Else Hn[S]:=-1;
 End;
 OutLong($3F3);OutLong(0);OutLong(NH);OutLong(0);OutLong(NH-1);
 For S:=0 To 2 Do If Hn[S]>=0 Then OutLong((SecLen[S]+3) Div 4);
 For S:=0 To 2 Do Begin
  If Hn[S]<0 Then Continue;
  Sz:=(SecLen[S]+3) Div 4;
  If S=0 Then OutLong($3E9) Else If S=1 Then OutLong($3EA) Else OutLong($3EB);
  OutLong(Sz);
  If S<2 Then Begin
   For I:=0 To Sz*4-1 Do Begin
    If I<SecLen[S] Then OutByte(SecGet(S,I)) Else OutByte(0);
   End;
  End;
  { relocations }
  For T:=0 To 2 Do Begin
   If Hn[T]<0 Then Continue;
   Cnt:=0;
   For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]=T) Then Inc(Cnt);
   If Cnt>0 Then Begin
    If Cnt=0 Then Continue;
   End;
  End;
  Cnt:=0;
  For I:=1 To RelocN Do If RelocSrc^[I]=S Then Inc(Cnt);
  If Cnt>0 Then Begin
   OutLong($3EC);
   For T:=0 To 2 Do Begin
    If Hn[T]<0 Then Continue;
    K:=0;
    For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]=T) Then Inc(K);
    If K>0 Then Begin
     OutLong(K);OutLong(Hn[T]);
     For I:=1 To RelocN Do
      If (RelocSrc^[I]=S) And (RelocDst^[I]=T) Then OutLong(RelocPos^[I]);
    End;
   End;
   OutLong(0);
  End;
  If OptDebug Then Begin
   K:=0;
   For H:=0 To HASHSZ-1 Do Begin
    P:=Hash[H];
    While P<>Nil Do Begin
     If P^.Defd And (P^.Kind=0) And (P^.Sect=S) And (Pos('~',P^.Name)=0) Then Inc(K);
     P:=P^.Next;
    End;
   End;
   If K>0 Then Begin
    OutLong($3F0);
    For H:=0 To HASHSZ-1 Do Begin
     P:=Hash[H];
     While P<>Nil Do Begin
      If P^.Defd And (P^.Kind=0) And (P^.Sect=S) And (Pos('~',P^.Name)=0) Then Begin
       Nm:=P^.Name;
       OutLong((Length(Nm)+3) Div 4);
       For J:=1 To ((Length(Nm)+3) Div 4)*4 Do
        If J<=Length(Nm) Then OutByte(Ord(Nm[J])) Else OutByte(0);
       OutLong(P^.Value);
      End;
      P:=P^.Next;
     End;
    End;
    OutLong(0);
   End;
  End;
  OutLong($3F2);
 End;
 CloseOut;
 WriteHunk:=True;
End;

{ Imprime la table des symboles dans le listing }
Procedure PrintSymbols;
Var Arr: Array[1..2000] Of PSym; N,I,J: Integer; P: PSym; T: PSym; H: Integer;
    Sc: String;
Begin
 N:=0;
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin
   If P^.Defd And (N<2000) And (P^.Kind<>2) Then Begin Inc(N);Arr[N]:=P;End;
   P:=P^.Next;
  End;
 End;
 For I:=2 To N Do Begin
  T:=Arr[I];J:=I-1;
  While (J>=1) And (Arr[J]^.Name>T^.Name) Do Begin Arr[J+1]:=Arr[J];Dec(J);End;
  Arr[J+1]:=T;
 End;
 WriteLn(ListF);
 WriteLn(ListF,T3('Symbol table','Table des symboles','Symboltabelle'));
 For I:=1 To N Do Begin
  Case Arr[I]^.Sect Of
   0: Sc:='TEXT';
   1: Sc:='DATA';
   2: Sc:='BSS ';
  Else Sc:='ABS ';
  End;
  WriteLn(ListF,PadR(Arr[I]^.Name,40),' ',Hex8(Arr[I]^.Value),' ',Sc);
 End;
End;

Function StripExt(Const N: String): String;
Var S: String;
Begin
 S:=ChangeExt(N,'X');
 StripExt:=Copy(S,1,Length(S)-2);
End;

{ ---------------------------------------------------------------------- }
{ Point d'entree de l'assembleur                                          }
{ ---------------------------------------------------------------------- }

Procedure InitAsmTables;
Var I: Integer;
Begin
 For I:=0 To HASHSZ-1 Do Hash[I]:=Nil;
 SymCount:=0;MacCount:=0;SrcTop:=0;CondTop:=0;
 FillChar(Chunks,SizeOf(Chunks),0);
 If RelocPos=Nil Then Begin
  New(RelocPos);New(RelocSrc);New(RelocDst);New(Decs);New(TmpBody);
 End;
 OptListing:=False;OptSymbols:=False;OptToDisk:=True;OptOptimize:=False;
 OptCase:=True;OptDebug:=False;OptWarnings:=True;
 OptOutName:='';OptIncPath:='';OptListName:='';OptTabSize:=8;
 AsmLogN:=0;AmigaMode:=AmigaMode;
End;

{ Assemble Lines[1..Count] ; True si aucune erreur }
Function AssembleSource(Const Name: String; Lines: PLineArr; Count: Integer): Boolean;
Var Prev,Cur: LongInt; N: Integer; Ext: String; L: LongInt;
Begin
 AssembleSource:=False;
 LogClear;
 FreeSyms;FreeSections;
 AsmErrors:=0;AsmWarns:=0;AsmFileName:=Name;CurSrcName:=Name;CurLineNo:=0;
 PassSerial:=0;RelocN:=0;
 FillChar(SecLen,SizeOf(SecLen),0);
 FillChar(SecBase,SizeOf(SecBase),0);
 OptDebug0:=OptDebug;OptOptimize0:=OptOptimize;OptCase0:=OptCase;OptWarnings0:=OptWarnings;
 LogLine(AsmName+T3(' Macro Assembler  Version ',' Macro-assembleur  Version ',' Makro-Assembler  Version ')+VERSION_TEXT);
 LogLine(T3('DEV-COOLS clone of HiSoft Devpac','Clone DEV-COOLS de HiSoft Devpac','DEV-COOLS-Klon von HiSoft Devpac'));
 LogLine('');
 FillChar(Decs^,SizeOf(TByteArr),0);
 { passe 1 repetee jusqu'a stabilisation des symboles }
 Prev:=-1;N:=0;
 Repeat
  AsmPassNo:=1;
  If N=0 Then LogLine('Pass 1') ;
  RunPass(Lines,Count);
  ComputeBases;
  Cur:=SymChecksum;
  Inc(N);
  If Cur=Prev Then Break;
  Prev:=Cur;
 Until N>=8;
 { passe 2 : generation }
 AsmPassNo:=2;
 LogLine('Pass 2');
 FreeSections;
 ListOn:=False;
 If OptListing Then Begin
  If OptListName='' Then OptListName:=ChangeExt(Name,'LST');
  Assign(ListF,OptListName);
  {$I-}
  Rewrite(ListF);
  {$I+}
  ListOn:=IOResult=0;
 End;
 RunPass(Lines,Count);
 If ListOn Then Begin
  PrintSymbols;
  Close(ListF);
 End;
 LogLine('');
 LogLine('CODE '+IntStr(SecLen[0])+'  DATA '+IntStr(SecLen[1])+'  BSS '+IntStr(SecLen[2])+
         T3(' bytes',' octets',' Bytes'));
 If AsmWarns>0 Then LogLine(IntStr(AsmWarns)+T3(' warning(s)',' avertissement(s)',' Warnung(en)'));
 If AsmErrors=0 Then Begin
  LogLine(T3('No errors','Aucune erreur','Keine Fehler'));
  { fichier de sortie }
  If OutFileName<>'' Then OptOutName:=OutFileName;
  If Not OptToDisk Then Begin
   OutPathFinal:=PathOf(Name)+'DEVPAC.TMP';OutIsTemp:=True;
  End Else Begin
   OutIsTemp:=False;
   If OptOutName<>'' Then OutPathFinal:=OptOutName
   Else If AbsMode Then OutPathFinal:=ChangeExt(Name,'BIN')
   Else If AmigaMode Then OutPathFinal:=StripExt(Name)
   Else OutPathFinal:=ChangeExt(Name,'PRG');
  End;
  If AbsMode Then Begin
   If WriteBin(OutPathFinal) Then HaveOutput:=True;
  End Else If AmigaMode Then Begin
   If WriteHunk(OutPathFinal) Then HaveOutput:=True;
  End Else Begin
   If WritePRG(OutPathFinal) Then HaveOutput:=True;
  End;
  If Not HaveOutput Then Begin
   LogLine(T3('Cannot write output file ','Impossible d''ecrire le fichier ','Ausgabedatei nicht schreibbar ')+OutPathFinal);
   Inc(AsmErrors);
  End Else If OptToDisk Then LogLine(T3('Output: ','Sortie : ','Ausgabe: ')+OutPathFinal);
 End Else Begin
  LogLine(IntStr(AsmErrors)+T3(' error(s)',' erreur(s)',' Fehler'));
  HaveOutput:=False;
 End;
 FreeMacros;
 AssembleSource:=(AsmErrors=0) And HaveOutput;
End;

{ ====================================================================== }
{                 MEMOIRE DE L'EMULATEUR ET DESASSEMBLEUR                }
{ ====================================================================== }

Const
 PAGE_SZ   = 4096;
 MAX_PAGES = 2048;            { 8 Mo maximum }
 SCR_BYTES = 32000;           { ecran ST monochrome 640x400 }
 ST_MEMKB  = 1024;            { memoire emulee : 1 Mo }

Type
 TPageTab = Array[0..MAX_PAGES-1] Of Pointer;

Var
 PageTab    : TPageTab;
 MemSize    : LongInt;
 BusErr     : Boolean;
 BusAddr    : LongInt;
 AddrErr    : Boolean;
 ScrBase    : LongInt;        { adresse de l'ecran physique (affiche) }
 DrawBase   : LongInt;        { adresse de l'ecran logique (cible du dessin) }
 ScrDirtyLo : Integer;
 ScrDirtyHi : Integer;

Procedure InitMemory(KB: LongInt);
Var I,N: Integer; P: Pointer;
Begin
 N:=(KB*1024) Div PAGE_SZ;
 If N>MAX_PAGES Then N:=MAX_PAGES;
 For I:=0 To N-1 Do Begin
  GetMem(P,PAGE_SZ);
  FillChar(P^,PAGE_SZ,0);
  PageTab[I]:=P;
 End;
 MemSize:=LongInt(N)*PAGE_SZ;
 BusErr:=False;AddrErr:=False;
 ScrDirtyLo:=0;ScrDirtyHi:=399;
End;

Procedure FreeMemory;
Var I: Integer;
Begin
 For I:=0 To MAX_PAGES-1 Do
  If PageTab[I]<>Nil Then Begin FreeMem(PageTab[I],PAGE_SZ);PageTab[I]:=Nil;End;
 MemSize:=0;
End;

Procedure ClearMemory;
Var I: Integer;
Begin
 For I:=0 To (MemSize Div PAGE_SZ)-1 Do FillChar(PageTab[I]^,PAGE_SZ,0);
End;

Procedure MarkScr(A: LongInt);
Var Row: Integer;
Begin
 Row:=(A-ScrBase) Div 80;
 If Row<ScrDirtyLo Then ScrDirtyLo:=Row;
 If Row>ScrDirtyHi Then ScrDirtyHi:=Row;
End;

Function Rd8(A: LongInt): Byte;
Var P: ^Byte;
Begin
 A:=A And $FFFFFF;
 If A>=MemSize Then Begin
  If A<$FF0000 Then Begin BusErr:=True;BusAddr:=A;End;
  Rd8:=0;Exit;
 End;
 {$IFDEF FPC}
 P:=PageTab[A Shr 12];
 Inc(P,A And 4095);
 {$ELSE}
 P:=PtrAdd(PageTab[A Shr 12],A And 4095);
 {$ENDIF}
 Rd8:=P^;
End;

Procedure Wr8(A: LongInt; V: Byte);
Var P: ^Byte;
Begin
 A:=A And $FFFFFF;
 If A>=MemSize Then Begin
  If A<$FF0000 Then Begin BusErr:=True;BusAddr:=A;End;
  Exit;
 End;
 {$IFDEF FPC}
 P:=PageTab[A Shr 12];
 Inc(P,A And 4095);
 {$ELSE}
 P:=PtrAdd(PageTab[A Shr 12],A And 4095);
 {$ENDIF}
 P^:=V;
 If (A>=ScrBase) And (A<ScrBase+SCR_BYTES) Then MarkScr(A);
End;

Function Rd16(A: LongInt): LongInt;
Begin
 Rd16:=(LongInt(Rd8(A)) Shl 8) Or Rd8(A+1);
End;

Function Rd32(A: LongInt): LongInt;
Begin
 Rd32:=(LongInt(Rd8(A)) Shl 24) Or (LongInt(Rd8(A+1)) Shl 16) Or
       (LongInt(Rd8(A+2)) Shl 8) Or Rd8(A+3);
End;

Procedure Wr16(A: LongInt; V: LongInt);
Begin
 Wr8(A,(V Shr 8) And $FF);
 Wr8(A+1,V And $FF);
End;

Procedure Wr32(A: LongInt; V: LongInt);
Begin
 Wr8(A,ShrL(V,24) And $FF);
 Wr8(A+1,ShrL(V,16) And $FF);
 Wr8(A+2,ShrL(V,8) And $FF);
 Wr8(A+3,V And $FF);
End;

Function RdStr(A: LongInt; Max: Integer): String;
Var S: String; B: Byte;
Begin
 S:='';
 While Length(S)<Max Do Begin
  B:=Rd8(A+Length(S));
  If B=0 Then Break;
  S:=S+Chr(B);
 End;
 RdStr:=S;
End;

Procedure WrStr(A: LongInt; Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do Wr8(A+I-1,Ord(S[I]));
 Wr8(A+Length(S),0);
End;

{ ---------------------------------------------------------------------- }
{ Table des symboles du debogueur (chargee depuis l'executable)           }
{ ---------------------------------------------------------------------- }

Const
 MAXDBG = 3000;

Type
 TDbgSym = Record
  Name : String[24];
  Addr : LongInt;
 End;
 PDbgArr = ^TDbgArr;
 TDbgArr = Array[1..MAXDBG] Of TDbgSym;

Var
 DbgSyms : PDbgArr;
 DbgN    : Integer;

Function DbgFind(A: LongInt): String;
Var I: Integer;
Begin
 DbgFind:='';
 If DbgSyms=Nil Then Exit;
 For I:=1 To DbgN Do
  If DbgSyms^[I].Addr=A Then Begin DbgFind:=DbgSyms^[I].Name;Exit;End;
End;

Function DbgByName(Const N: String; Var A: LongInt): Boolean;
Var I: Integer; U: String;
Begin
 DbgByName:=False;
 If DbgSyms=Nil Then Exit;
 U:=Upper(N);
 For I:=1 To DbgN Do
  If Upper(DbgSyms^[I].Name)=U Then Begin A:=DbgSyms^[I].Addr;DbgByName:=True;Exit;End;
End;

Procedure DbgAdd(Const N: String; A: LongInt);
Begin
 If DbgSyms=Nil Then New(DbgSyms);
 If DbgN<MAXDBG Then Begin
  Inc(DbgN);
  DbgSyms^[DbgN].Name:=Copy(N,1,24);
  DbgSyms^[DbgN].Addr:=A;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Desassembleur 68000                                                     }
{ ---------------------------------------------------------------------- }

Var
 DPC : LongInt;

Function DNextW: LongInt;
Begin
 DNextW:=Rd16(DPC);
 Inc(DPC,2);
End;

Function DNextL: LongInt;
Begin
 DNextL:=Rd32(DPC);
 Inc(DPC,4);
End;

Function SX16(V: LongInt): LongInt;
Begin
 V:=V And $FFFF;
 If V>=$8000 Then V:=V-$10000;
 SX16:=V;
End;

Function SX8(V: LongInt): LongInt;
Begin
 V:=V And $FF;
 If V>=$80 Then V:=V-$100;
 SX8:=V;
End;

Function HexS(V: LongInt): String;
Var S: String;
Begin
 S:=Hex8(V);
 While (Length(S)>1) And (S[1]='0') Do Delete(S,1,1);
 HexS:='$'+S;
End;

Function SgnHex(V: LongInt): String;
Begin
 If V<0 Then SgnHex:='-'+HexS(-V) Else SgnHex:=HexS(V);
End;

Function SymOrHex(A: LongInt): String;
Var S: String;
Begin
 S:=DbgFind(A);
 If S<>'' Then SymOrHex:=S Else SymOrHex:=HexS(A);
End;

Function DSizeCh(Sz: Integer): String;
Begin
 Case Sz Of
  0: DSizeCh:='B';
  1: DSizeCh:='W';
 Else DSizeCh:='L';
 End;
End;

Function ImmText(V: LongInt): String;
Begin
 If (V>=0) And (V<=9) Then ImmText:='#'+IntStr(V)
 Else ImmText:='#'+HexS(V);
End;

Function DEA(Mode,Reg,Sz: Integer): String;
Var W,D: LongInt; S: String; Ext: LongInt; XR: String;
Begin
 Case Mode Of
  0: DEA:='D'+IntStr(Reg);
  1: DEA:='A'+IntStr(Reg);
  2: DEA:='(A'+IntStr(Reg)+')';
  3: DEA:='(A'+IntStr(Reg)+')+';
  4: DEA:='-(A'+IntStr(Reg)+')';
  5: Begin
      D:=SX16(DNextW);
      DEA:=SgnHex(D)+'(A'+IntStr(Reg)+')';
     End;
  6: Begin
      Ext:=DNextW;
      D:=SX8(Ext);
      If (Ext And $8000)<>0 Then XR:='A' Else XR:='D';
      XR:=XR+IntStr((Ext Shr 12) And 7);
      If (Ext And $800)<>0 Then XR:=XR+'.L' Else XR:=XR+'.W';
      DEA:=SgnHex(D)+'(A'+IntStr(Reg)+','+XR+')';
     End;
  7: Case Reg Of
      0: Begin W:=SX16(DNextW);DEA:=SymOrHex(W)+'.W';End;
      1: Begin D:=DNextL;DEA:=SymOrHex(D);End;
      2: Begin
          W:=DPC;D:=SX16(DNextW);
          S:=DbgFind(W+D);
          If S<>'' Then DEA:=S+'(PC)' Else DEA:=SgnHex(D)+'(PC)';
         End;
      3: Begin
          W:=DPC;
          Ext:=DNextW;
          D:=SX8(Ext);
          If (Ext And $8000)<>0 Then XR:='A' Else XR:='D';
          XR:=XR+IntStr((Ext Shr 12) And 7);
          If (Ext And $800)<>0 Then XR:=XR+'.L' Else XR:=XR+'.W';
          DEA:=SgnHex(D)+'(PC,'+XR+')';
         End;
      4: Begin
          If Sz=2 Then D:=DNextL
          Else Begin D:=DNextW;If Sz=0 Then D:=D And $FF;End;
          DEA:=ImmText(D);
         End;
     Else DEA:='?';
     End;
 Else DEA:='?';
 End;
End;

Function RegListText(Mask: LongInt; Rev: Boolean): String;
Var I,J,Start: Integer; S: String; M: LongInt; Bank: Integer; Ch: Char;
Begin
 M:=Mask;
 If Rev Then Begin
  M:=0;
  For I:=0 To 15 Do If (Mask And (LongInt(1) Shl I))<>0 Then M:=M Or (LongInt(1) Shl (15-I));
 End;
 S:='';
 For Bank:=0 To 1 Do Begin
  If Bank=0 Then Ch:='D' Else Ch:='A';
  I:=0;
  While I<8 Do Begin
   If (M And (LongInt(1) Shl (Bank*8+I)))<>0 Then Begin
    J:=I;
    While (J<7) And ((M And (LongInt(1) Shl (Bank*8+J+1)))<>0) Do Inc(J);
    If S<>'' Then S:=S+'/';
    If J>I Then S:=S+Ch+IntStr(I)+'-'+Ch+IntStr(J) Else S:=S+Ch+IntStr(I);
    I:=J+1;
   End Else Inc(I);
  End;
 End;
 RegListText:=S;
End;

Const
 CCText : Array[0..15] Of String[2] =
  ('T','F','HI','LS','CC','CS','NE','EQ','VC','VS','PL','MI','GE','LT','GT','LE');

Function Pad8(Const S: String): String;
Begin
 Pad8:=PadR(S,8);
End;

Function Dis(PCIn: LongInt; Var Len: Integer): String;
Var Op,Mode,Reg,Sz,Ty,Cnt,Rg: LongInt; R,S1,S2: String; T,D: LongInt;
    Mk: LongInt;
Begin
 DPC:=PCIn;
 Op:=DNextW;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Sz:=(Op Shr 6) And 3;Rg:=(Op Shr 9) And 7;
 R:='DC.W    '+HexS(Op);
 Case (Op Shr 12) And 15 Of
  0: Begin
      If (Op And $F138)=$0108 Then Begin
       D:=SX16(DNextW);
       If (Op And $80)<>0 Then
        R:=Pad8('MOVEP.'+DSizeCh(((Op Shr 6) And 1)+1))+'D'+IntStr(Rg)+','+SgnHex(D)+'(A'+IntStr(Reg)+')'
       Else
        R:=Pad8('MOVEP.'+DSizeCh(((Op Shr 6) And 1)+1))+SgnHex(D)+'(A'+IntStr(Reg)+'),D'+IntStr(Rg);
      End Else If (Op And $0100)<>0 Then Begin
       Case Sz Of
        0: S1:='BTST'; 1: S1:='BCHG'; 2: S1:='BCLR';
       Else S1:='BSET';
       End;
       R:=Pad8(S1)+'D'+IntStr(Rg)+','+DEA(Mode,Reg,0);
      End Else Begin
       Case (Op Shr 8) And 15 Of
        0,2,4,6,10,12: Begin
          Case (Op Shr 8) And 15 Of
           0: S1:='ORI'; 2: S1:='ANDI'; 4: S1:='SUBI'; 6: S1:='ADDI';
           10: S1:='EORI';
          Else S1:='CMPI';
          End;
          If (Op=$003C) Or (Op=$023C) Or (Op=$0A3C) Then
           R:=Pad8(S1)+ImmText(DNextW And $FF)+',CCR'
          Else If (Op=$007C) Or (Op=$027C) Or (Op=$0A7C) Then
           R:=Pad8(S1)+ImmText(DNextW And $FFFF)+',SR'
          Else If Sz=3 Then R:='DC.W    '+HexS(Op)
          Else Begin
           If Sz=2 Then T:=DNextL Else Begin T:=DNextW;If Sz=0 Then T:=T And $FF;End;
           R:=Pad8(S1+'.'+DSizeCh(Sz))+ImmText(T)+','+DEA(Mode,Reg,Sz);
          End;
         End;
        8: Begin
          Case Sz Of
           0: S1:='BTST'; 1: S1:='BCHG'; 2: S1:='BCLR';
          Else S1:='BSET';
          End;
          T:=DNextW And $FF;
          R:=Pad8(S1)+'#'+IntStr(T)+','+DEA(Mode,Reg,0);
         End;
       End;
      End;
     End;
  1,2,3: Begin
      Case (Op Shr 12) And 3 Of
       1: Sz:=0;
       3: Sz:=1;
      Else Sz:=2;
      End;
      S1:=DEA(Mode,Reg,Sz);
      S2:=DEA((Op Shr 6) And 7,Rg,Sz);
      If ((Op Shr 6) And 7)=1 Then R:=Pad8('MOVEA.'+DSizeCh(Sz))+S1+','+S2
      Else R:=Pad8('MOVE.'+DSizeCh(Sz))+S1+','+S2;
     End;
  4: Begin
      If (Op And $F1C0)=$41C0 Then Begin
       S1:=DEA(Mode,Reg,2);R:=Pad8('LEA')+S1+',A'+IntStr(Rg);
      End Else If (Op And $F1C0)=$4180 Then Begin
       S1:=DEA(Mode,Reg,1);R:=Pad8('CHK')+S1+',D'+IntStr(Rg);
      End Else Begin
       Case Op And $0F00 Of
        $0000,$0200,$0400,$0600: Begin
          Case Op And $0F00 Of
           $0000: S1:='NEGX'; $0200: S1:='CLR'; $0400: S1:='NEG';
          Else S1:='NOT';
          End;
          If Sz=3 Then Begin
           Case Op And $0F00 Of
            $0000: R:=Pad8('MOVE')+'SR,'+DEA(Mode,Reg,1);
            $0200: R:=Pad8('MOVE')+'CCR,'+DEA(Mode,Reg,1);
            $0400: R:=Pad8('MOVE')+DEA(Mode,Reg,1)+',CCR';
           Else R:=Pad8('MOVE')+DEA(Mode,Reg,1)+',SR';
           End;
          End Else R:=Pad8(S1+'.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz);
         End;
        $0800: Begin
          If (Op And $FFC0)=$4800 Then R:=Pad8('NBCD')+DEA(Mode,Reg,0)
          Else If (Op And $FFF8)=$4840 Then R:=Pad8('SWAP')+'D'+IntStr(Reg)
          Else If (Op And $FFC0)=$4840 Then R:=Pad8('PEA')+DEA(Mode,Reg,2)
          Else If (Op And $FFF8)=$4880 Then R:=Pad8('EXT.W')+'D'+IntStr(Reg)
          Else If (Op And $FFF8)=$48C0 Then R:=Pad8('EXT.L')+'D'+IntStr(Reg)
          Else If (Op And $FF80)=$4880 Then Begin
           Mk:=DNextW;
           If Mode=4 Then S1:=RegListText(Mk,True) Else S1:=RegListText(Mk,False);
           R:=Pad8('MOVEM.'+DSizeCh(((Op Shr 6) And 1)+1))+S1+','+DEA(Mode,Reg,2);
          End;
         End;
        $0A00: Begin
          If Op=$4AFC Then R:='ILLEGAL'
          Else If Sz=3 Then R:=Pad8('TAS')+DEA(Mode,Reg,0)
          Else R:=Pad8('TST.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz);
         End;
        $0C00: Begin
          If (Op And $FF80)=$4C80 Then Begin
           Mk:=DNextW;
           S1:=DEA(Mode,Reg,2);
           R:=Pad8('MOVEM.'+DSizeCh(((Op Shr 6) And 1)+1))+S1+','+RegListText(Mk,False);
          End;
         End;
        $0E00: Begin
          If (Op And $FFF0)=$4E40 Then R:=Pad8('TRAP')+'#'+IntStr(Op And 15)
          Else If (Op And $FFF8)=$4E50 Then Begin
           D:=SX16(DNextW);R:=Pad8('LINK')+'A'+IntStr(Reg)+',#'+SgnHex(D);
          End Else If (Op And $FFF8)=$4E58 Then R:=Pad8('UNLK')+'A'+IntStr(Reg)
          Else If (Op And $FFF8)=$4E60 Then R:=Pad8('MOVE')+'A'+IntStr(Reg)+',USP'
          Else If (Op And $FFF8)=$4E68 Then R:=Pad8('MOVE')+'USP,A'+IntStr(Reg)
          Else If Op=$4E70 Then R:='RESET'
          Else If Op=$4E71 Then R:='NOP'
          Else If Op=$4E72 Then R:=Pad8('STOP')+ImmText(DNextW)
          Else If Op=$4E73 Then R:='RTE'
          Else If Op=$4E75 Then R:='RTS'
          Else If Op=$4E76 Then R:='TRAPV'
          Else If Op=$4E77 Then R:='RTR'
          Else If (Op And $FFC0)=$4E80 Then R:=Pad8('JSR')+DEA(Mode,Reg,2)
          Else If (Op And $FFC0)=$4EC0 Then R:=Pad8('JMP')+DEA(Mode,Reg,2);
         End;
       End;
      End;
     End;
  5: Begin
      If Sz=3 Then Begin
       If Mode=1 Then Begin
        D:=SX16(DNextW);
        R:=Pad8('DB'+CCText[(Op Shr 8) And 15])+'D'+IntStr(Reg)+','+SymOrHex(PCIn+2+D);
        If ((Op Shr 8) And 15)=1 Then R:=Pad8('DBRA')+'D'+IntStr(Reg)+','+SymOrHex(PCIn+2+D);
       End Else R:=Pad8('S'+CCText[(Op Shr 8) And 15])+DEA(Mode,Reg,0);
      End Else Begin
       T:=Rg;If T=0 Then T:=8;
       If (Op And $100)<>0 Then S1:='SUBQ' Else S1:='ADDQ';
       R:=Pad8(S1+'.'+DSizeCh(Sz))+'#'+IntStr(T)+','+DEA(Mode,Reg,Sz);
      End;
     End;
  6: Begin
      T:=Op And $FF;
      If T=0 Then D:=SX16(DNextW) Else D:=SX8(T);
      Case (Op Shr 8) And 15 Of
       0: S1:='BRA'; 1: S1:='BSR';
      Else S1:='B'+CCText[(Op Shr 8) And 15];
      End;
      If T<>0 Then S1:=S1+'.S';
      R:=Pad8(S1)+SymOrHex(PCIn+2+D);
     End;
  7: Begin
      R:=Pad8('MOVEQ')+'#'+SgnHex(SX8(Op And $FF))+',D'+IntStr(Rg);
      If (SX8(Op And $FF)>=0) And (SX8(Op And $FF)<=9) Then
       R:=Pad8('MOVEQ')+'#'+IntStr(Op And $FF)+',D'+IntStr(Rg);
     End;
  8,9,11,12,13: Begin
      Case (Op Shr 12) And 15 Of
       8: S1:='OR'; 9: S1:='SUB'; 11: S1:='CMP'; 12: S1:='AND';
      Else S1:='ADD';
      End;
      If ((Op Shr 12) And 15=8) And (Sz=3) Then Begin
       If (Op And $100)<>0 Then R:=Pad8('DIVS')+DEA(Mode,Reg,1)+',D'+IntStr(Rg)
       Else R:=Pad8('DIVU')+DEA(Mode,Reg,1)+',D'+IntStr(Rg);
      End Else If ((Op Shr 12) And 15=12) And (Sz=3) Then Begin
       If (Op And $100)<>0 Then R:=Pad8('MULS')+DEA(Mode,Reg,1)+',D'+IntStr(Rg)
       Else R:=Pad8('MULU')+DEA(Mode,Reg,1)+',D'+IntStr(Rg);
      End Else If ((Op Shr 12) And 15=8) And ((Op And $1F0)=$100) Then Begin
       If Mode=0 Then R:=Pad8('SBCD')+'D'+IntStr(Reg)+',D'+IntStr(Rg)
       Else R:=Pad8('SBCD')+'-(A'+IntStr(Reg)+'),-(A'+IntStr(Rg)+')';
      End Else If ((Op Shr 12) And 15=12) And ((Op And $1F0)=$100) Then Begin
       If Mode=0 Then R:=Pad8('ABCD')+'D'+IntStr(Reg)+',D'+IntStr(Rg)
       Else R:=Pad8('ABCD')+'-(A'+IntStr(Reg)+'),-(A'+IntStr(Rg)+')';
      End Else If ((Op Shr 12) And 15=12) And (((Op And $F1F8)=$C140) Or ((Op And $F1F8)=$C148) Or
                  ((Op And $F1F8)=$C188)) Then Begin
       If (Op And $F1F8)=$C140 Then R:=Pad8('EXG')+'D'+IntStr(Rg)+',D'+IntStr(Reg)
       Else If (Op And $F1F8)=$C148 Then R:=Pad8('EXG')+'A'+IntStr(Rg)+',A'+IntStr(Reg)
       Else R:=Pad8('EXG')+'D'+IntStr(Rg)+',A'+IntStr(Reg);
      End Else If ((Op Shr 12) And 15=11) And (Sz=3) Then Begin
       If (Op And $100)<>0 Then Sz:=2 Else Sz:=1;
       R:=Pad8('CMPA.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+',A'+IntStr(Rg);
      End Else If ((Op Shr 12) And 15=11) And ((Op And $100)<>0) And (Mode=1) And (Sz<>3) Then
       R:=Pad8('CMPM.'+DSizeCh(Sz))+'(A'+IntStr(Reg)+')+,(A'+IntStr(Rg)+')+'
      Else If ((Op Shr 12) And 15=11) And ((Op And $100)<>0) Then
       R:=Pad8('EOR.'+DSizeCh(Sz))+'D'+IntStr(Rg)+','+DEA(Mode,Reg,Sz)
      Else If (((Op Shr 12) And 15=9) Or ((Op Shr 12) And 15=13)) And (Sz=3) Then Begin
       If (Op And $100)<>0 Then Sz:=2 Else Sz:=1;
       R:=Pad8(S1+'A.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+',A'+IntStr(Rg);
      End Else If (((Op Shr 12) And 15=9) Or ((Op Shr 12) And 15=13)) And ((Op And $130)=$100) Then Begin
       If Mode=0 Then R:=Pad8(S1+'X.'+DSizeCh(Sz))+'D'+IntStr(Reg)+',D'+IntStr(Rg)
       Else R:=Pad8(S1+'X.'+DSizeCh(Sz))+'-(A'+IntStr(Reg)+'),-(A'+IntStr(Rg)+')';
      End Else Begin
       If (Op And $100)<>0 Then
        R:=Pad8(S1+'.'+DSizeCh(Sz))+'D'+IntStr(Rg)+','+DEA(Mode,Reg,Sz)
       Else
        R:=Pad8(S1+'.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+',D'+IntStr(Rg);
      End;
     End;
  10: R:='DC.W    '+HexS(Op)+'  ; Line A';
  14: Begin
      If Sz=3 Then Begin
       Ty:=(Op Shr 9) And 3;
       Case Ty Of
        0: S1:='AS'; 1: S1:='LS'; 2: S1:='ROX';
       Else S1:='RO';
       End;
       If (Op And $100)<>0 Then S1:=S1+'L' Else S1:=S1+'R';
       R:=Pad8(S1+'.W')+DEA(Mode,Reg,1);
      End Else Begin
       Ty:=(Op Shr 3) And 3;
       Case Ty Of
        0: S1:='AS'; 1: S1:='LS'; 2: S1:='ROX';
       Else S1:='RO';
       End;
       If (Op And $100)<>0 Then S1:=S1+'L' Else S1:=S1+'R';
       If (Op And $20)<>0 Then R:=Pad8(S1+'.'+DSizeCh(Sz))+'D'+IntStr(Rg)+',D'+IntStr(Reg)
       Else Begin
        Cnt:=Rg;If Cnt=0 Then Cnt:=8;
        R:=Pad8(S1+'.'+DSizeCh(Sz))+'#'+IntStr(Cnt)+',D'+IntStr(Reg);
       End;
      End;
     End;
  15: R:='DC.W    '+HexS(Op)+'  ; Line F';
 End;
 Len:=Integer(DPC-PCIn);
 Dis:=R;
End;

{ ====================================================================== }
{                      EMULATEUR MOTOROLA 68000                          }
{ ====================================================================== }

Const
 SR_C = 1;  SR_V = 2;  SR_Z = 4;  SR_N = 8;  SR_X = 16;
 SR_S = $2000;  SR_T = $8000;

 STOP_NONE  = 0;
 STOP_EXIT  = 1;     { programme termine }
 STOP_BREAK = 2;     { point d'arret }
 STOP_FAULT = 3;     { exception sans gestionnaire }
 STOP_STOP  = 4;     { instruction STOP }
 STOP_USER  = 5;     { interruption par l'utilisateur }
 STOP_TRACE = 6;     { pas a pas termine }

 MAXBP = 16;

Const
 Low32 : LongInt = -2147483647-1;

Var
 SingleStack : Boolean;
 Rg       : Array[0..15] Of LongInt;   { D0-D7 = 0..7, A0-A7 = 8..15 }
 PC       : LongInt;
 SRv      : LongInt;
 USPv,SSPv: LongInt;
 StopReason : Integer;
 StopMsg    : String;
 ExitCode   : LongInt;
 InstrCount : LongInt;
 Bps        : Array[1..MAXBP] Of LongInt;
 NBps       : Integer;
 CurOpPC    : LongInt;
 TraceOver  : Boolean;
 { Etat du calcul d'adresse effective }
 EAK        : Integer;      { 0 Dn, 1 An, 2 memoire, 3 immediat }
 EAR        : Integer;
 EAA        : LongInt;

Procedure DoTrap(N: Integer); Forward;
Procedure DoLineA(Op: LongInt); Forward;
Procedure HleLibCheck; Forward;

Function Msk(V: LongInt; Sz: Integer): LongInt;
Begin
 Case Sz Of
  1: Msk:=V And $FF;
  2: Msk:=V And $FFFF;
 Else Msk:=V;
 End;
End;

Function IsNeg(V: LongInt; Sz: Integer): Boolean;
Begin
 Case Sz Of
  1: IsNeg:=(V And $80)<>0;
  2: IsNeg:=(V And $8000)<>0;
 Else IsNeg:=V<0;
 End;
End;

Function SExt(V: LongInt; Sz: Integer): LongInt;
Begin
 Case Sz Of
  1: Begin V:=V And $FF;If V>=$80 Then V:=V-$100;End;
  2: Begin V:=V And $FFFF;If V>=$8000 Then V:=V-$10000;End;
 End;
 SExt:=V;
End;

Procedure SetSR(V: LongInt);
Var NewS: Boolean;
Begin
 V:=V And $A71F;
 NewS:=(V And SR_S)<>0;
 If (Not SingleStack) And (NewS<>((SRv And SR_S)<>0)) Then Begin
  If NewS Then Begin USPv:=Rg[15];Rg[15]:=SSPv;End
  Else Begin SSPv:=Rg[15];Rg[15]:=USPv;End;
 End;
 SRv:=V;
End;

Procedure SetF(M: LongInt; C: Boolean);
Begin
 If C Then SRv:=SRv Or M Else SRv:=SRv And (Not M);
End;

Function GetF(M: LongInt): Boolean;
Begin
 GetF:=(SRv And M)<>0;
End;

Procedure SetNZ(V: LongInt; Sz: Integer);
Begin
 SetF(SR_N,IsNeg(V,Sz));
 SetF(SR_Z,Msk(V,Sz)=0);
End;

Procedure SetLogic(V: LongInt; Sz: Integer);
Begin
 SetNZ(V,Sz);
 SetF(SR_V,False);SetF(SR_C,False);
End;

Procedure Halt68(Const Msg: String);
Begin
 If StopReason=STOP_NONE Then Begin
  StopReason:=STOP_FAULT;
  StopMsg:=Msg;
 End;
End;

Procedure PushL(V: LongInt);
Begin
 Rg[15]:=Rg[15]-4;
 Wr32(Rg[15],V);
End;

Procedure PushW(V: LongInt);
Begin
 Rg[15]:=Rg[15]-2;
 Wr16(Rg[15],V);
End;

Function PopL: LongInt;
Begin
 PopL:=Rd32(Rg[15]);
 Rg[15]:=Rg[15]+4;
End;

Function PopW: LongInt;
Begin
 PopW:=Rd16(Rg[15]);
 Rg[15]:=Rg[15]+2;
End;

Function Fetch16: LongInt;
Begin
 If Odd(PC) Then AddrErr:=True;
 Fetch16:=Rd16(PC);
 PC:=PC+2;
End;

Function Fetch32: LongInt;
Begin
 Fetch32:=Rd32(PC);
 PC:=PC+4;
End;

Function MemRd(A: LongInt; Sz: Integer): LongInt;
Begin
 If (Sz>1) And Odd(A) Then Begin AddrErr:=True;BusAddr:=A;MemRd:=0;Exit;End;
 Case Sz Of
  1: MemRd:=Rd8(A);
  2: MemRd:=Rd16(A);
 Else MemRd:=Rd32(A);
 End;
End;

Procedure MemWr(A: LongInt; Sz: Integer; V: LongInt);
Begin
 If (Sz>1) And Odd(A) Then Begin AddrErr:=True;BusAddr:=A;Exit;End;
 Case Sz Of
  1: Wr8(A,V And $FF);
  2: Wr16(A,V And $FFFF);
 Else Wr32(A,V);
 End;
End;

Procedure RaiseExc(Vec: Integer);
Var Hnd,OldSR: LongInt; Names: String;
Begin
 Hnd:=Rd32(Vec*4);
 If (Hnd=0) Or (Vec>=32) And (Hnd<$400) Then Begin
  Case Vec Of
   2: Names:='Bus error';
   3: Names:='Address error';
   4: Names:='Illegal instruction';
   5: Names:='Divide by zero';
   6: Names:='CHK exception';
   7: Names:='TRAPV exception';
   8: Names:='Privilege violation';
   11: Names:='Line F emulator';
  Else Names:='Exception #'+IntStr(Vec);
  End;
  Halt68(Names+' at $'+Hex6(CurOpPC));
  Exit;
 End;
 OldSR:=SRv;
 SetSR((SRv Or SR_S) And $7FFF);
 PushL(PC);
 PushW(OldSR);
 PC:=Hnd;
End;

Function TestCC(CC: Integer): Boolean;
Var C,V,Z,N: Boolean;
Begin
 C:=GetF(SR_C);V:=GetF(SR_V);Z:=GetF(SR_Z);N:=GetF(SR_N);
 Case CC Of
  0: TestCC:=True;
  1: TestCC:=False;
  2: TestCC:=Not C And Not Z;
  3: TestCC:=C Or Z;
  4: TestCC:=Not C;
  5: TestCC:=C;
  6: TestCC:=Not Z;
  7: TestCC:=Z;
  8: TestCC:=Not V;
  9: TestCC:=V;
  10: TestCC:=Not N;
  11: TestCC:=N;
  12: TestCC:=N=V;
  13: TestCC:=N<>V;
  14: TestCC:=(Not Z) And (N=V);
 Else TestCC:=Z Or (N<>V);
 End;
End;

{ Calcule l'adresse effective ; Sz en octets (1,2,4) }
Procedure CalcEA(Mode,Reg,Sz: Integer);
Var Ext,D: LongInt; XV: LongInt; XR: Integer;
Begin
 EAK:=2;EAR:=Reg;
 Case Mode Of
  0: EAK:=0;
  1: EAK:=1;
  2: EAA:=Rg[8+Reg];
  3: Begin
      EAA:=Rg[8+Reg];
      If (Reg=7) And (Sz=1) Then Rg[8+Reg]:=Rg[8+Reg]+2 Else Rg[8+Reg]:=Rg[8+Reg]+Sz;
     End;
  4: Begin
      If (Reg=7) And (Sz=1) Then Rg[8+Reg]:=Rg[8+Reg]-2 Else Rg[8+Reg]:=Rg[8+Reg]-Sz;
      EAA:=Rg[8+Reg];
     End;
  5: Begin D:=SExt(Fetch16,2);EAA:=Rg[8+Reg]+D;End;
  6: Begin
      Ext:=Fetch16;
      XR:=(Ext Shr 12) And 15;
      XV:=Rg[XR];
      If (Ext And $800)=0 Then XV:=SExt(XV,2);
      EAA:=Rg[8+Reg]+SExt(Ext,1)+XV;
     End;
  7: Case Reg Of
      0: EAA:=SExt(Fetch16,2);
      1: EAA:=Fetch32;
      2: Begin D:=PC;EAA:=D+SExt(Fetch16,2);End;
      3: Begin
          D:=PC;
          Ext:=Fetch16;
          XR:=(Ext Shr 12) And 15;
          XV:=Rg[XR];
          If (Ext And $800)=0 Then XV:=SExt(XV,2);
          EAA:=D+SExt(Ext,1)+XV;
         End;
      4: Begin
          EAK:=3;
          If Sz=4 Then EAA:=Fetch32
          Else Begin EAA:=Fetch16;If Sz=1 Then EAA:=EAA And $FF;End;
         End;
     Else Begin EAK:=3;EAA:=0;Halt68('Illegal addressing mode at $'+Hex6(CurOpPC));End;
     End;
 End;
End;

Function ReadEA(Sz: Integer): LongInt;
Begin
 Case EAK Of
  0: ReadEA:=Msk(Rg[EAR],Sz);
  1: ReadEA:=Msk(Rg[8+EAR],Sz);
  2: ReadEA:=MemRd(EAA,Sz);
 Else ReadEA:=Msk(EAA,Sz);
 End;
End;

Procedure WriteEA(Sz: Integer; V: LongInt);
Begin
 Case EAK Of
  0: Case Sz Of
      1: Rg[EAR]:=(Rg[EAR] And (Not $FF)) Or (V And $FF);
      2: Rg[EAR]:=(Rg[EAR] And (Not $FFFF)) Or (V And $FFFF);
     Else Rg[EAR]:=V;
     End;
  1: Rg[8+EAR]:=SExt(V,Sz);
  2: MemWr(EAA,Sz,V);
 End;
End;

{ ---------------------------------------------------------------------- }
{ ALU                                                                      }
{ ---------------------------------------------------------------------- }

Function AluAdd(S,D: LongInt; Sz: Integer; WithX: Boolean; SetX: Boolean): LongInt;
Var R: LongInt; XI: LongInt; C,V: Boolean;
Begin
 S:=Msk(S,Sz);D:=Msk(D,Sz);
 XI:=0;
 If WithX And GetF(SR_X) Then XI:=1;
 R:=Msk(S+D+XI,Sz);
 C:=IsNeg((S And D) Or ((Not R) And (S Or D)),Sz);
 V:=IsNeg((S Xor R) And (D Xor R),Sz);
 SetF(SR_C,C);SetF(SR_V,V);
 If SetX Then SetF(SR_X,C);
 If WithX Then Begin If R<>0 Then SetF(SR_Z,False);End
 Else SetF(SR_Z,R=0);
 SetF(SR_N,IsNeg(R,Sz));
 AluAdd:=R;
End;

{ R = D - S }
Function AluSub(S,D: LongInt; Sz: Integer; WithX: Boolean; SetX: Boolean): LongInt;
Var R: LongInt; XI: LongInt; C,V: Boolean;
Begin
 S:=Msk(S,Sz);D:=Msk(D,Sz);
 XI:=0;
 If WithX And GetF(SR_X) Then XI:=1;
 R:=Msk(D-S-XI,Sz);
 C:=IsNeg(((Not D) And S) Or (R And ((Not D) Or S)),Sz);
 V:=IsNeg((S Xor D) And (R Xor D),Sz);
 SetF(SR_C,C);SetF(SR_V,V);
 If SetX Then SetF(SR_X,C);
 If WithX Then Begin If R<>0 Then SetF(SR_Z,False);End
 Else SetF(SR_Z,R=0);
 SetF(SR_N,IsNeg(R,Sz));
 AluSub:=R;
End;

Function SzFromBits(B: Integer): Integer;
Begin
 Case B Of
  0: SzFromBits:=1;
  1: SzFromBits:=2;
 Else SzFromBits:=4;
 End;
End;

{ Decalages et rotations ; Ty : 0 AS, 1 LS, 2 ROX, 3 RO ; Left : sens }
Function Shift(Ty: Integer; Left: Boolean; V: LongInt; Cnt: Integer; Sz: Integer): LongInt;
Var I: Integer; C,Msb,Old,X: Boolean; Top: LongInt; Ovf: Boolean;
Begin
 V:=Msk(V,Sz);
 Cnt:=Cnt And 63;
 C:=False;Ovf:=False;
 If Cnt=0 Then Begin
  If Ty=2 Then C:=GetF(SR_X);
  SetF(SR_C,C);SetF(SR_V,False);SetNZ(V,Sz);
  Shift:=V;Exit;
 End;
 For I:=1 To Cnt Do Begin
  Msb:=IsNeg(V,Sz);
  If Left Then Begin
   Case Ty Of
    0: Begin C:=Msb;V:=Msk(V Shl 1,Sz);If IsNeg(V,Sz)<>Msb Then Ovf:=True;End;
    1: Begin C:=Msb;V:=Msk(V Shl 1,Sz);End;
    2: Begin
        X:=GetF(SR_X);C:=Msb;V:=Msk(V Shl 1,Sz);
        If X Then V:=V Or 1;
        SetF(SR_X,C);
       End;
   Else Begin C:=Msb;V:=Msk(V Shl 1,Sz);If C Then V:=V Or 1;End;
   End;
  End Else Begin
   C:=(V And 1)<>0;
   Case Ty Of
    0: Begin
        V:=Msk(ShrL(V,1),Sz);
        If Msb Then Begin
         Case Sz Of 1: V:=V Or $80; 2: V:=V Or $8000;
         Else V:=V Or (LongInt(1) Shl 31) End;
        End;
       End;
    1: V:=Msk(ShrL(V,1),Sz);
    2: Begin
        X:=GetF(SR_X);
        V:=Msk(ShrL(V,1),Sz);
        If X Then Begin
         Case Sz Of 1: V:=V Or $80; 2: V:=V Or $8000;
         Else V:=V Or (LongInt(1) Shl 31) End;
        End;
        SetF(SR_X,C);
       End;
   Else Begin
         V:=Msk(ShrL(V,1),Sz);
         If C Then Begin
          Case Sz Of 1: V:=V Or $80; 2: V:=V Or $8000;
          Else V:=V Or (LongInt(1) Shl 31) End;
         End;
        End;
   End;
  End;
 End;
 SetF(SR_C,C);
 If Ty<>3 Then SetF(SR_X,C);
 If Ty=2 Then SetF(SR_X,C);
 SetF(SR_V,Ovf And (Ty=0));
 SetNZ(V,Sz);
 Shift:=V;
End;

Function DivU32(Num: LongInt; Den: LongInt; Var Rem: LongInt): LongInt;
{ division non signee 32 bits / 16 bits par soustractions }
Var Q,R: LongInt; I: Integer; Bit: LongInt;
Begin
 Q:=0;R:=0;
 For I:=31 Downto 0 Do Begin
  Bit:=ShrL(Num,I) And 1;
  R:=(R Shl 1) Or Bit;
  If (R>=0) And (R>=Den) Then Begin
   R:=R-Den;
   Q:=Q Or (LongInt(1) Shl I);
  End Else If R<0 Then Begin
   R:=R-Den;
   Q:=Q Or (LongInt(1) Shl I);
  End;
 End;
 Rem:=R;
 DivU32:=Q;
End;

{ ---------------------------------------------------------------------- }
{ Groupes d'instructions                                                  }
{ ---------------------------------------------------------------------- }

Function Supervisor: Boolean;
Begin
 If (SRv And SR_S)=0 Then Begin
  PC:=CurOpPC+2;
  RaiseExc(8);
  Supervisor:=False;
 End Else Supervisor:=True;
End;

Procedure Op0(Op: LongInt);
Var Mode,Reg,Rn,Sz,Ty,T,Bit: Integer; Imm,V,R,D: LongInt; A: LongInt;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 If (Op And $F138)=$0108 Then Begin
  D:=SExt(Fetch16,2);
  A:=Rg[8+Reg]+D;
  If (Op And $80)=0 Then Begin
   { memoire vers registre }
   If (Op And $40)=0 Then Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or (LongInt(Rd8(A)) Shl 8) Or Rd8(A+2)
   Else Rg[Rn]:=(LongInt(Rd8(A)) Shl 24) Or (LongInt(Rd8(A+2)) Shl 16) Or (LongInt(Rd8(A+4)) Shl 8) Or Rd8(A+6);
  End Else Begin
   If (Op And $40)=0 Then Begin Wr8(A,ShrL(Rg[Rn],8) And $FF);Wr8(A+2,Rg[Rn] And $FF);End
   Else Begin
    Wr8(A,ShrL(Rg[Rn],24) And $FF);Wr8(A+2,ShrL(Rg[Rn],16) And $FF);
    Wr8(A+4,ShrL(Rg[Rn],8) And $FF);Wr8(A+6,Rg[Rn] And $FF);
   End;
  End;
  Exit;
 End;
 If ((Op And $0100)<>0) Or ((Op And $0F00)=$0800) Then Begin
  { instructions sur bits }
  Ty:=(Op Shr 6) And 3;
  If (Op And $0100)<>0 Then Bit:=Rg[Rn] Else Bit:=Fetch16 And $FF;
  If Mode=0 Then Begin
   Bit:=Bit And 31;
   V:=Rg[Reg];
   SetF(SR_Z,(ShrL(V,Bit) And 1)=0);
   Case Ty Of
    1: V:=V Xor (LongInt(1) Shl Bit);
    2: V:=V And (Not (LongInt(1) Shl Bit));
    3: V:=V Or (LongInt(1) Shl Bit);
   End;
   If Ty<>0 Then Rg[Reg]:=V;
  End Else Begin
   Bit:=Bit And 7;
   CalcEA(Mode,Reg,1);
   V:=ReadEA(1);
   SetF(SR_Z,((V Shr Bit) And 1)=0);
   Case Ty Of
    1: V:=V Xor (1 Shl Bit);
    2: V:=V And (Not (1 Shl Bit));
    3: V:=V Or (1 Shl Bit);
   End;
   If Ty<>0 Then WriteEA(1,V);
  End;
  Exit;
 End;
 T:=(Op Shr 8) And $F;
 { operations immediates sur CCR/SR }
 If ((Op And $FF)=$3C) And ((T=0) Or (T=2) Or (T=10)) Then Begin
  Imm:=Fetch16 And $FF;
  V:=SRv And $FF;
  Case T Of 0: V:=V Or Imm; 2: V:=V And Imm; Else V:=V Xor Imm End;
  SetSR((SRv And $FF00) Or (V And $FF));
  Exit;
 End;
 If ((Op And $FF)=$7C) And ((T=0) Or (T=2) Or (T=10)) Then Begin
  If Not Supervisor Then Exit;
  Imm:=Fetch16;
  V:=SRv;
  Case T Of 0: V:=V Or Imm; 2: V:=V And Imm; Else V:=V Xor Imm End;
  SetSR(V);
  Exit;
 End;
 Sz:=SzFromBits((Op Shr 6) And 3);
 If ((Op Shr 6) And 3)=3 Then Begin RaiseExc(4);Exit;End;
 If Sz=4 Then Imm:=Fetch32 Else Imm:=Fetch16;
 Imm:=Msk(Imm,Sz);
 CalcEA(Mode,Reg,Sz);
 V:=ReadEA(Sz);
 Case T Of
  0: Begin R:=V Or Imm;SetLogic(R,Sz);WriteEA(Sz,R);End;
  2: Begin R:=V And Imm;SetLogic(R,Sz);WriteEA(Sz,R);End;
  4: Begin R:=AluSub(Imm,V,Sz,False,True);WriteEA(Sz,R);End;
  6: Begin R:=AluAdd(Imm,V,Sz,False,True);WriteEA(Sz,R);End;
  10: Begin R:=V Xor Imm;SetLogic(R,Sz);WriteEA(Sz,R);End;
  12: R:=AluSub(Imm,V,Sz,False,False);
 Else RaiseExc(4);
 End;
End;

Procedure OpMove(Op: LongInt);
Var Sz,SM,SR1,DM,DR: Integer; V: LongInt;
Begin
 Case (Op Shr 12) And 3 Of
  1: Sz:=1;
  3: Sz:=2;
 Else Sz:=4;
 End;
 SM:=(Op Shr 3) And 7;SR1:=Op And 7;
 DM:=(Op Shr 6) And 7;DR:=(Op Shr 9) And 7;
 CalcEA(SM,SR1,Sz);
 V:=ReadEA(Sz);
 If DM=1 Then Begin
  Rg[8+DR]:=SExt(V,Sz);
  Exit;
 End;
 CalcEA(DM,DR,Sz);
 WriteEA(Sz,V);
 SetLogic(V,Sz);
End;

Procedure OpMovem(Op: LongInt);
Var Mode,Reg,Sz,I: Integer; Mk: LongInt; A: LongInt; ToMem: Boolean;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 If (Op And $40)<>0 Then Sz:=4 Else Sz:=2;
 ToMem:=(Op And $400)=0;
 Mk:=Fetch16;
 If ToMem Then Begin
  If Mode=4 Then Begin
   A:=Rg[8+Reg];
   For I:=0 To 15 Do
    If (Mk And (LongInt(1) Shl I))<>0 Then Begin
     A:=A-Sz;
     If Sz=4 Then Wr32(A,Rg[15-I]) Else Wr16(A,Rg[15-I]);
    End;
   Rg[8+Reg]:=A;
  End Else Begin
   CalcEA(Mode,Reg,Sz);
   A:=EAA;
   For I:=0 To 15 Do
    If (Mk And (LongInt(1) Shl I))<>0 Then Begin
     If Sz=4 Then Wr32(A,Rg[I]) Else Wr16(A,Rg[I]);
     A:=A+Sz;
    End;
  End;
 End Else Begin
  If Mode=3 Then A:=Rg[8+Reg] Else Begin CalcEA(Mode,Reg,Sz);A:=EAA;End;
  For I:=0 To 15 Do
   If (Mk And (LongInt(1) Shl I))<>0 Then Begin
    If Sz=4 Then Rg[I]:=Rd32(A) Else Rg[I]:=SExt(Rd16(A),2);
    A:=A+Sz;
   End;
  If Mode=3 Then Rg[8+Reg]:=A;
 End;
End;

Procedure Op4(Op: LongInt);
Var Mode,Reg,Rn,Sz,SzB: Integer; V,R,D,A,Lo: LongInt; T: Integer;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 SzB:=(Op Shr 6) And 3;
 If (Op And $F1C0)=$41C0 Then Begin
  CalcEA(Mode,Reg,4);
  Rg[8+Rn]:=EAA;Exit;
 End;
 If (Op And $F1C0)=$4180 Then Begin
  CalcEA(Mode,Reg,2);
  V:=ReadEA(2);
  D:=SExt(Rg[Rn],2);
  If D<0 Then Begin SetF(SR_N,True);RaiseExc(6);End
  Else If D>SExt(V,2) Then Begin SetF(SR_N,False);RaiseExc(6);End;
  Exit;
 End;
 Case Op And $0F00 Of
  $0000,$0200,$0400,$0600: Begin
    If SzB=3 Then Begin
     Case Op And $0F00 Of
      $0000: Begin CalcEA(Mode,Reg,2);WriteEA(2,SRv And $FFFF);End;
      $0200: Begin CalcEA(Mode,Reg,2);WriteEA(2,SRv And $FF);End;
      $0400: Begin CalcEA(Mode,Reg,2);V:=ReadEA(2);SetSR((SRv And $FF00) Or (V And $FF));End;
     Else Begin
       If Supervisor Then Begin CalcEA(Mode,Reg,2);V:=ReadEA(2);SetSR(V);End;
      End;
     End;
     Exit;
    End;
    Sz:=SzFromBits(SzB);
    CalcEA(Mode,Reg,Sz);
    V:=ReadEA(Sz);
    Case Op And $0F00 Of
     $0000: Begin R:=AluSub(V,0,Sz,True,True);WriteEA(Sz,R);End;
     $0200: Begin R:=0;WriteEA(Sz,0);SRv:=(SRv And (Not 15)) Or SR_Z;End;
     $0400: Begin R:=AluSub(V,0,Sz,False,True);WriteEA(Sz,R);End;
    Else Begin R:=Msk(Not V,Sz);WriteEA(Sz,R);SetLogic(R,Sz);End;
    End;
   End;
  $0800: Begin
    If (Op And $FFC0)=$4800 Then Begin
     CalcEA(Mode,Reg,1);
     V:=ReadEA(1);
     { NBCD : 0 - V - X }
     Lo:=(0-(V And $F)-Ord(GetF(SR_X)));
     D:=0-(ShrL(V,4) And $F);
     If Lo<0 Then Begin Lo:=Lo+10;D:=D-1;End;
     SetF(SR_C,False);
     If D<0 Then Begin D:=D+10;SetF(SR_C,True);End;
     R:=((D And $F) Shl 4) Or (Lo And $F);
     If R<>0 Then SetF(SR_Z,False);
     SetF(SR_X,GetF(SR_C));
     WriteEA(1,R);
    End Else If (Op And $FFF8)=$4840 Then Begin
     R:=(ShrL(Rg[Reg],16) And $FFFF) Or ((Rg[Reg] And $FFFF) Shl 16);
     Rg[Reg]:=R;SetLogic(R,4);
    End Else If (Op And $FFC0)=$4840 Then Begin
     CalcEA(Mode,Reg,4);
     PushL(EAA);
    End Else If (Op And $FFF8)=$4880 Then Begin
     R:=SExt(Rg[Reg],1);
     Rg[Reg]:=(Rg[Reg] And (Not $FFFF)) Or (R And $FFFF);
     SetLogic(R,2);
    End Else If (Op And $FFF8)=$48C0 Then Begin
     R:=SExt(Rg[Reg],2);Rg[Reg]:=R;SetLogic(R,4);
    End Else If (Op And $FF80)=$4880 Then OpMovem(Op)
    Else RaiseExc(4);
   End;
  $0A00: Begin
    If Op=$4AFC Then Begin PC:=CurOpPC+2;RaiseExc(4);Exit;End;
    If SzB=3 Then Begin
     CalcEA(Mode,Reg,1);
     V:=ReadEA(1);
     SetLogic(V,1);
     WriteEA(1,V Or $80);
    End Else Begin
     Sz:=SzFromBits(SzB);
     CalcEA(Mode,Reg,Sz);
     V:=ReadEA(Sz);
     SetLogic(V,Sz);
    End;
   End;
  $0C00: Begin
    If (Op And $FF80)=$4C80 Then OpMovem(Op) Else RaiseExc(4);
   End;
  $0E00: Begin
    If (Op And $FFF0)=$4E40 Then DoTrap(Op And 15)
    Else If (Op And $FFF8)=$4E50 Then Begin
     D:=SExt(Fetch16,2);
     PushL(Rg[8+Reg]);
     Rg[8+Reg]:=Rg[15];
     Rg[15]:=Rg[15]+D;
    End Else If (Op And $FFF8)=$4E58 Then Begin
     Rg[15]:=Rg[8+Reg];
     Rg[8+Reg]:=PopL;
    End Else If (Op And $FFF8)=$4E60 Then Begin
     If Supervisor Then USPv:=Rg[8+Reg];
    End Else If (Op And $FFF8)=$4E68 Then Begin
     If Supervisor Then Rg[8+Reg]:=USPv;
    End Else If Op=$4E70 Then Begin If Supervisor Then Begin End;End
    Else If Op=$4E71 Then Begin End
    Else If Op=$4E72 Then Begin
     If Supervisor Then Begin
      SetSR(Fetch16);
      StopReason:=STOP_STOP;StopMsg:='STOP';
     End;
    End Else If Op=$4E73 Then Begin
     If Supervisor Then Begin
      V:=PopW;A:=PopL;
      SetSR(V);PC:=A;
     End;
    End Else If Op=$4E75 Then PC:=PopL
    Else If Op=$4E76 Then Begin If GetF(SR_V) Then RaiseExc(7);End
    Else If Op=$4E77 Then Begin
     V:=PopW;
     SetSR((SRv And $FF00) Or (V And $FF));
     PC:=PopL;
    End Else If (Op And $FFC0)=$4E80 Then Begin
     CalcEA(Mode,Reg,4);
     PushL(PC);
     PC:=EAA;
    End Else If (Op And $FFC0)=$4EC0 Then Begin
     CalcEA(Mode,Reg,4);
     PC:=EAA;
    End Else RaiseExc(4);
   End;
 End;
End;

Procedure Op5(Op: LongInt);
Var Mode,Reg,Sz,CC: Integer; V,R,Q,D,Base: LongInt;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 CC:=(Op Shr 8) And 15;
 If ((Op Shr 6) And 3)=3 Then Begin
  If Mode=1 Then Begin
   Base:=PC;
   D:=SExt(Fetch16,2);
   If Not TestCC(CC) Then Begin
    V:=(Rg[Reg] And $FFFF)-1;
    Rg[Reg]:=(Rg[Reg] And (Not $FFFF)) Or (V And $FFFF);
    If (V And $FFFF)<>$FFFF Then PC:=Base+D;
   End;
  End Else Begin
   CalcEA(Mode,Reg,1);
   If TestCC(CC) Then WriteEA(1,$FF) Else WriteEA(1,0);
  End;
  Exit;
 End;
 Sz:=SzFromBits((Op Shr 6) And 3);
 Q:=(Op Shr 9) And 7;If Q=0 Then Q:=8;
 CalcEA(Mode,Reg,Sz);
 If EAK=1 Then Begin
  If (Op And $100)=0 Then Rg[8+EAR]:=Rg[8+EAR]+Q Else Rg[8+EAR]:=Rg[8+EAR]-Q;
  Exit;
 End;
 V:=ReadEA(Sz);
 If (Op And $100)=0 Then R:=AluAdd(Q,V,Sz,False,True)
 Else R:=AluSub(Q,V,Sz,False,True);
 WriteEA(Sz,R);
End;

Procedure OpBcc(Op: LongInt);
Var D,Base: LongInt; CC: Integer;
Begin
 CC:=(Op Shr 8) And 15;
 Base:=PC;
 D:=Op And $FF;
 If D=0 Then D:=SExt(Fetch16,2)
 Else If D=$FF Then D:=Fetch32
 Else D:=SExt(D,1);
 If CC=1 Then Begin
  PushL(PC);
  PC:=Base+D;
 End Else If TestCC(CC) Then PC:=Base+D;
End;

Procedure Op8(Op: LongInt);
Var Mode,Reg,Rn,Sz: Integer; V,R,Q,Den,Rem,Num,Lo: LongInt; Neg1,Neg2: Boolean;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 Sz:=SzFromBits((Op Shr 6) And 3);
 If ((Op Shr 6) And 3)=3 Then Begin
  CalcEA(Mode,Reg,2);
  Den:=ReadEA(2);
  If Den=0 Then Begin PC:=CurOpPC+2;RaiseExc(5);Exit;End;
  Num:=Rg[Rn];
  If (Op And $100)=0 Then Begin
   Q:=DivU32(Num,Den,Rem);
   If (Q<0) Or (Q>$FFFF) Then Begin SetF(SR_V,True);SetF(SR_C,False);Exit;End;
   Rg[Rn]:=((Rem And $FFFF) Shl 16) Or (Q And $FFFF);
   SetF(SR_V,False);SetF(SR_C,False);SetNZ(Q,2);
  End Else Begin
   Den:=SExt(Den,2);
   If (Num=Low32) And (Den=-1) Then Begin SetF(SR_V,True);SetF(SR_C,False);Exit;End;
   Q:=Num Div Den;Rem:=Num Mod Den;
   If (Q<-32768) Or (Q>32767) Then Begin SetF(SR_V,True);SetF(SR_C,False);Exit;End;
   Rg[Rn]:=((Rem And $FFFF) Shl 16) Or (Q And $FFFF);
   SetF(SR_V,False);SetF(SR_C,False);SetNZ(Q,2);
  End;
  Exit;
 End;
 If (Op And $1F0)=$100 Then Begin
  { SBCD }
  If Mode=0 Then Begin V:=Rg[Reg] And $FF;R:=Rg[Rn] And $FF;End
  Else Begin
   CalcEA(4,Reg,1);V:=Rd8(EAA);
   CalcEA(4,Rn,1);R:=Rd8(EAA);
  End;
  Lo:=(R And $F)-(V And $F)-Ord(GetF(SR_X));
  Q:=(ShrL(R,4) And $F)-(ShrL(V,4) And $F);
  If Lo<0 Then Begin Lo:=Lo+10;Q:=Q-1;End;
  SetF(SR_C,False);
  If Q<0 Then Begin Q:=Q+10;SetF(SR_C,True);End;
  R:=((Q And $F) Shl 4) Or (Lo And $F);
  If R<>0 Then SetF(SR_Z,False);
  SetF(SR_X,GetF(SR_C));
  If Mode=0 Then Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R Else Wr8(EAA,R);
  Exit;
 End;
 CalcEA(Mode,Reg,Sz);
 If (Op And $100)=0 Then Begin
  V:=ReadEA(Sz);
  R:=Msk(V Or Rg[Rn],Sz);
  SetLogic(R,Sz);
  Case Sz Of
   1: Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R;
   2: Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or R;
  Else Rg[Rn]:=R;
  End;
 End Else Begin
  V:=ReadEA(Sz);
  R:=Msk(V Or Rg[Rn],Sz);
  SetLogic(R,Sz);
  WriteEA(Sz,R);
 End;
End;

Procedure OpAddSub(Op: LongInt; IsAdd: Boolean);
Var Mode,Reg,Rn,Sz: Integer; V,R,S: LongInt; Q: Integer;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 If ((Op Shr 6) And 3)=3 Then Begin
  If (Op And $100)<>0 Then Sz:=4 Else Sz:=2;
  CalcEA(Mode,Reg,Sz);
  V:=SExt(ReadEA(Sz),Sz);
  If IsAdd Then Rg[8+Rn]:=Rg[8+Rn]+V Else Rg[8+Rn]:=Rg[8+Rn]-V;
  Exit;
 End;
 Sz:=SzFromBits((Op Shr 6) And 3);
 If ((Op And $130)=$100) And (Mode<2) Then Begin
  { ADDX / SUBX }
  If Mode=0 Then Begin V:=Rg[Reg];S:=Rg[Rn];End
  Else Begin
   CalcEA(4,Reg,Sz);V:=MemRd(EAA,Sz);
   CalcEA(4,Rn,Sz);S:=MemRd(EAA,Sz);
  End;
  If IsAdd Then R:=AluAdd(V,S,Sz,True,True) Else R:=AluSub(V,S,Sz,True,True);
  If Mode=0 Then Begin
   Case Sz Of
    1: Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R;
    2: Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or R;
   Else Rg[Rn]:=R;
   End;
  End Else MemWr(EAA,Sz,R);
  Exit;
 End;
 CalcEA(Mode,Reg,Sz);
 If (Op And $100)=0 Then Begin
  V:=ReadEA(Sz);
  If IsAdd Then R:=AluAdd(V,Rg[Rn],Sz,False,True) Else R:=AluSub(V,Rg[Rn],Sz,False,True);
  Case Sz Of
   1: Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R;
   2: Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or R;
  Else Rg[Rn]:=R;
  End;
 End Else Begin
  V:=ReadEA(Sz);
  If IsAdd Then R:=AluAdd(Rg[Rn],V,Sz,False,True) Else R:=AluSub(Rg[Rn],V,Sz,False,True);
  WriteEA(Sz,R);
 End;
End;

Procedure OpB(Op: LongInt);
Var Mode,Reg,Rn,Sz: Integer; V,R,S: LongInt;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 If ((Op Shr 6) And 3)=3 Then Begin
  If (Op And $100)<>0 Then Sz:=4 Else Sz:=2;
  CalcEA(Mode,Reg,Sz);
  V:=SExt(ReadEA(Sz),Sz);
  R:=AluSub(V,Rg[8+Rn],4,False,False);
  Exit;
 End;
 Sz:=SzFromBits((Op Shr 6) And 3);
 If (Op And $100)=0 Then Begin
  CalcEA(Mode,Reg,Sz);
  V:=ReadEA(Sz);
  R:=AluSub(V,Rg[Rn],Sz,False,False);
 End Else If Mode=1 Then Begin
  { CMPM }
  CalcEA(3,Reg,Sz);V:=MemRd(EAA,Sz);
  CalcEA(3,Rn,Sz);S:=MemRd(EAA,Sz);
  R:=AluSub(V,S,Sz,False,False);
 End Else Begin
  CalcEA(Mode,Reg,Sz);
  V:=ReadEA(Sz);
  R:=Msk(V Xor Rg[Rn],Sz);
  SetLogic(R,Sz);
  WriteEA(Sz,R);
 End;
End;

Procedure OpC(Op: LongInt);
Var Mode,Reg,Rn,Sz: Integer; V,R,S,Lo,Q: LongInt; T: LongInt;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 If ((Op Shr 6) And 3)=3 Then Begin
  CalcEA(Mode,Reg,2);
  V:=ReadEA(2);
  If (Op And $100)=0 Then R:=(V And $FFFF)*(Rg[Rn] And $FFFF)
  Else R:=SExt(V,2)*SExt(Rg[Rn],2);
  Rg[Rn]:=R;
  SetLogic(R,4);
  Exit;
 End;
 If (Op And $1F0)=$100 Then Begin
  { ABCD }
  If Mode=0 Then Begin V:=Rg[Reg] And $FF;R:=Rg[Rn] And $FF;End
  Else Begin
   CalcEA(4,Reg,1);V:=Rd8(EAA);
   CalcEA(4,Rn,1);R:=Rd8(EAA);
  End;
  Lo:=(R And $F)+(V And $F)+Ord(GetF(SR_X));
  Q:=(ShrL(R,4) And $F)+(ShrL(V,4) And $F);
  If Lo>9 Then Begin Lo:=Lo-10;Q:=Q+1;End;
  SetF(SR_C,False);
  If Q>9 Then Begin Q:=Q-10;SetF(SR_C,True);End;
  R:=((Q And $F) Shl 4) Or (Lo And $F);
  If R<>0 Then SetF(SR_Z,False);
  SetF(SR_X,GetF(SR_C));
  If Mode=0 Then Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R Else Wr8(EAA,R);
  Exit;
 End;
 If (Op And $F1F8)=$C140 Then Begin T:=Rg[Rn];Rg[Rn]:=Rg[Reg];Rg[Reg]:=T;Exit;End;
 If (Op And $F1F8)=$C148 Then Begin T:=Rg[8+Rn];Rg[8+Rn]:=Rg[8+Reg];Rg[8+Reg]:=T;Exit;End;
 If (Op And $F1F8)=$C188 Then Begin T:=Rg[Rn];Rg[Rn]:=Rg[8+Reg];Rg[8+Reg]:=T;Exit;End;
 Sz:=SzFromBits((Op Shr 6) And 3);
 CalcEA(Mode,Reg,Sz);
 V:=ReadEA(Sz);
 R:=Msk(V And Rg[Rn],Sz);
 SetLogic(R,Sz);
 If (Op And $100)=0 Then Begin
  Case Sz Of
   1: Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R;
   2: Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or R;
  Else Rg[Rn]:=R;
  End;
 End Else WriteEA(Sz,R);
End;

Procedure OpE(Op: LongInt);
Var Mode,Reg,Rn,Sz,Ty,Cnt: Integer; V,R: LongInt;
Begin
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Rn:=(Op Shr 9) And 7;
 If ((Op Shr 6) And 3)=3 Then Begin
  Ty:=(Op Shr 9) And 3;
  CalcEA(Mode,Reg,2);
  V:=ReadEA(2);
  R:=Shift(Ty,(Op And $100)<>0,V,1,2);
  WriteEA(2,R);
  Exit;
 End;
 Sz:=SzFromBits((Op Shr 6) And 3);
 Ty:=(Op Shr 3) And 3;
 If (Op And $20)<>0 Then Cnt:=Rg[Rn] And 63
 Else Begin Cnt:=Rn;If Cnt=0 Then Cnt:=8;End;
 R:=Shift(Ty,(Op And $100)<>0,Rg[Reg],Cnt,Sz);
 Case Sz Of
  1: Rg[Reg]:=(Rg[Reg] And (Not $FF)) Or R;
  2: Rg[Reg]:=(Rg[Reg] And (Not $FFFF)) Or R;
 Else Rg[Reg]:=R;
 End;
End;

Procedure CpuReset;
Var I: Integer;
Begin
 For I:=0 To 15 Do Rg[I]:=0;
 PC:=0;SRv:=$2700;USPv:=0;SSPv:=0;
 StopReason:=STOP_NONE;StopMsg:='';ExitCode:=0;InstrCount:=0;
 BusErr:=False;AddrErr:=False;
End;

Procedure Step;
Var Op: LongInt;
Begin
 CurOpPC:=PC;
 HleLibCheck;
 If StopReason<>STOP_NONE Then Exit;
 CurOpPC:=PC;
 Op:=Fetch16;
 Inc(InstrCount);
 Case (Op Shr 12) And 15 Of
  0: Op0(Op);
  1,2,3: OpMove(Op);
  4: Op4(Op);
  5: Op5(Op);
  6: OpBcc(Op);
  7: Begin
      Rg[(Op Shr 9) And 7]:=SExt(Op And $FF,1);
      SetLogic(Rg[(Op Shr 9) And 7],4);
     End;
  8: Op8(Op);
  9: OpAddSub(Op,False);
  10: DoLineA(Op);
  11: OpB(Op);
  12: OpC(Op);
  13: OpAddSub(Op,True);
  14: OpE(Op);
 Else Begin PC:=CurOpPC+2;RaiseExc(11);End;
 End;
 If AddrErr Then Begin
  AddrErr:=False;
  Halt68('Address error at $'+Hex6(CurOpPC));
 End;
 If BusErr Then Begin
  BusErr:=False;
  Halt68('Bus error at $'+Hex6(BusAddr)+' (PC=$'+Hex6(CurOpPC)+')');
 End;
End;

Function IsBreakpoint(A: LongInt): Boolean;
Var I: Integer;
Begin
 IsBreakpoint:=False;
 For I:=1 To NBps Do If Bps[I]=A Then Begin IsBreakpoint:=True;Exit;End;
End;

{ Execute au plus Max instructions ; s'arrete sur un point d'arret }
Procedure RunCpu(Max: LongInt);
Var N: LongInt;
Begin
 N:=0;
 While (StopReason=STOP_NONE) And (N<Max) Do Begin
  Step;
  Inc(N);
  If (StopReason=STOP_NONE) And (NBps>0) And IsBreakpoint(PC) Then Begin
   StopReason:=STOP_BREAK;
   StopMsg:='Breakpoint';
  End;
 End;
End;

{ ====================================================================== }
{          ECRAN ATARI ST (640x400 MONOCHROME), TERMINAL VT52, CLAVIER   }
{ ====================================================================== }

Const
 KQ_SIZE = 64;
 CON_ROWS = 25;
 CON_COLS = 80;
 EMU_Y0   = 40;               { decalage vertical de l'ecran emule }

Var
 Font8     : Array[0..255,0..7] Of Byte;
 FontReady : Boolean;
 KQ        : Array[0..KQ_SIZE-1] Of LongInt;
 KQHead,KQTail : Integer;
 UserBreak : Boolean;
 ConRow,ConCol : Integer;
 ConRev,ConWrap,ConCurOn : Boolean;
 ConState  : Integer;           { 0 normal, 1 apres ESC, 2/3 ESC Y }
 ConYRow   : Integer;
 ScrShadow : Array[0..SCR_BYTES-1] Of Byte;
 EmuTitle  : String;
 Emu_GEM   : Boolean;           { GEM actif (VDI/AES) }
 EmuVisible: Boolean;
 IdleBlit  : Boolean;
 MonActive : Boolean;           { le moniteur est affiche }
 UserCursor : Boolean;            { vex_curv : le programme dessine le curseur }
 RecActive  : Boolean;
 MouseHidden : Integer;         { compteur v_hide_c / graf_mouse M_OFF }

{ Construit la table des glyphes 8x8 a partir de la police BGI }
Procedure BuildFont;
Var C,X,Y: Integer;
Begin
 If FontReady Or Not GfxOn Then Exit;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 SetColor(White);
 For C:=0 To 255 Do Begin
  Box(0,0,15,15,Black);
  OutTextXY(0,0,Chr(C));
  For Y:=0 To 7 Do Begin
   Font8[C,Y]:=0;
   For X:=0 To 7 Do
    If GetPixel(X,Y)<>Black Then Font8[C,Y]:=Font8[C,Y] Or (128 Shr X);
  End;
 End;
 Box(0,0,15,15,Black);
 FontReady:=True;
End;

{ ---------------------------------------------------------------------- }
{ Primitives sur le bitmap de l'ecran emule                                }
{ ---------------------------------------------------------------------- }

Procedure BPix(X,Y: Integer; V: Boolean);
Var A: LongInt; B: Byte;
Begin
 If (X<0) Or (X>=640) Or (Y<0) Or (Y>=400) Then Exit;
 A:=DrawBase+LongInt(Y)*80+(X Shr 3);
 B:=Rd8(A);
 If V Then B:=B Or (128 Shr (X And 7)) Else B:=B And Not (128 Shr (X And 7));
 Wr8(A,B);
End;

Function BGet(X,Y: Integer): Boolean;
Begin
 BGet:=False;
 If (X<0) Or (X>=640) Or (Y<0) Or (Y>=400) Then Exit;
 BGet:=(Rd8(DrawBase+LongInt(Y)*80+(X Shr 3)) And (128 Shr (X And 7)))<>0;
End;

Procedure BRect(X1,Y1,X2,Y2: Integer; V: Boolean);
Var X,Y: Integer;
Begin
 For Y:=Y1 To Y2 Do
  For X:=X1 To X2 Do BPix(X,Y,V);
End;

Procedure BLine(X1,Y1,X2,Y2: Integer; V: Boolean);
Var DX,DY,SX,SY,Err,E2: Integer;
Begin
 DX:=Abs(X2-X1);DY:=-Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err:=DX+DY;
 While True Do Begin
  BPix(X1,Y1,V);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*Err;
  If E2>=DY Then Begin Err:=Err+DY;X1:=X1+SX;End;
  If E2<=DX Then Begin Err:=Err+DX;Y1:=Y1+SY;End;
 End;
End;

{ Texte 8x16 en coordonnees pixels (coin superieur gauche) }
Procedure BText(X,Y: Integer; Const S: String; Inv: Boolean);
Var I,GY,GX: Integer; B: Byte;
Begin
 For I:=1 To Length(S) Do
  For GY:=0 To 15 Do Begin
   B:=Font8[Ord(S[I]),GY Shr 1];
   If Inv Then B:=Not B;
   For GX:=0 To 7 Do BPix(X+(I-1)*8+GX,Y+GY,(B And (128 Shr GX))<>0);
  End;
End;

Procedure ConGlyph(R,C: Integer; Ch: Byte; Rev: Boolean);
Var GY: Integer; B: Byte; A: LongInt;
Begin
 A:=DrawBase+LongInt(R)*16*80+C;
 For GY:=0 To 15 Do Begin
  B:=Font8[Ch,GY Shr 1];
  If Rev Then B:=Not B;
  Wr8(A+LongInt(GY)*80,B);
 End;
End;

Procedure ConClear;
Var I: LongInt;
Begin
 For I:=0 To SCR_BYTES-1 Do Wr8(DrawBase+I,0);
 ConRow:=0;ConCol:=0;
End;

Procedure ConScroll;
Var I: LongInt;
Begin
 For I:=0 To (CON_ROWS-1)*16*80-1 Do Wr8(DrawBase+I,Rd8(DrawBase+I+16*80));
 For I:=(CON_ROWS-1)*16*80 To SCR_BYTES-1 Do Wr8(DrawBase+I,0);
End;

Procedure ConCursor(On: Boolean);
Var GY: Integer; A: LongInt;
Begin
 If BatchMode Then Exit;
 A:=DrawBase+LongInt(ConRow)*16*80+ConCol;
 For GY:=13 To 15 Do Wr8(A+LongInt(GY)*80,Rd8(A+LongInt(GY)*80) Xor $FF);
End;

Procedure ConNewLine;
Begin
 ConCol:=0;
 If ConRow>=CON_ROWS-1 Then ConScroll Else Inc(ConRow);
End;

{ Ecrit un octet sur la console ST (interprete les sequences VT52) }
Procedure ConPut(B: Byte);
Begin
 If BatchMode Then Begin
  Case ConState Of
   0: If B=27 Then ConState:=1
      Else If B=10 Then WriteLn(ConOut)
      Else If (B=9) Or (B=8) Or (B>=32) Then Write(ConOut,Chr(B));
   1: Begin
       If B=Ord('Y') Then ConState:=2
       Else If (B=Ord('b')) Or (B=Ord('c')) Then ConState:=4
       Else ConState:=0;
      End;
   2: ConState:=3;
   3: ConState:=0;
   4: ConState:=0;
  End;
  Exit;
 End;
 Case ConState Of
  1: Begin
      ConState:=0;
      Case Chr(B) Of
       'A': If ConRow>0 Then Dec(ConRow);
       'B': If ConRow<CON_ROWS-1 Then Inc(ConRow);
       'C': If ConCol<CON_COLS-1 Then Inc(ConCol);
       'D': If ConCol>0 Then Dec(ConCol);
       'E': ConClear;
       'H': Begin ConRow:=0;ConCol:=0;End;
       'J': Begin
             ConGlyph(ConRow,ConCol,32,False);
             While ConCol<CON_COLS Do Begin ConGlyph(ConRow,ConCol,32,False);Inc(ConCol);End;
             ConCol:=0;
            End;
       'K': Begin
             While ConCol<CON_COLS Do Begin ConGlyph(ConRow,ConCol,32,False);Inc(ConCol);End;
             ConCol:=0;
            End;
       'Y': ConState:=2;
       'b','c': ConState:=4;
       'e': ConCurOn:=True;
       'f': ConCurOn:=False;
       'p': ConRev:=True;
       'q': ConRev:=False;
       'v': ConWrap:=True;
       'w': ConWrap:=False;
      End;
     End;
  2: Begin ConYRow:=Integer(B)-32;ConState:=3;End;
  3: Begin
      ConState:=0;
      If (ConYRow>=0) And (ConYRow<CON_ROWS) Then ConRow:=ConYRow;
      If (Integer(B)-32>=0) And (Integer(B)-32<CON_COLS) Then ConCol:=Integer(B)-32;
     End;
  4: ConState:=0;
 Else
  Case B Of
   27: ConState:=1;
   13: ConCol:=0;
   10: Begin If ConRow>=CON_ROWS-1 Then ConScroll Else Inc(ConRow);End;
   8: If ConCol>0 Then Dec(ConCol);
   9: Begin ConCol:=(ConCol+8) And Not 7;If ConCol>=CON_COLS Then ConNewLine;End;
   7: Begin End;
  Else
   If B>=32 Then Begin
    ConGlyph(ConRow,ConCol,B,ConRev);
    Inc(ConCol);
    If ConCol>=CON_COLS Then Begin
     If ConWrap Then ConNewLine Else ConCol:=CON_COLS-1;
    End;
   End;
  End;
 End;
End;

Procedure ConWrite(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do ConPut(Ord(S[I]));
End;

{ ---------------------------------------------------------------------- }
{ Presentation de l'ecran emule                                           }
{ ---------------------------------------------------------------------- }

Procedure BlitScreen(Full: Boolean);
Var Y,XB,Bit: Integer; A: LongInt; B,O: Byte; Lo,Hi: Integer;
Begin
 If BatchMode Or Not GfxOn Then Exit;
 If MonActive And Not EmuVisible And Not Full Then Exit;
 If Full Then Begin
  Box(0,0,SCR_W-1,SCR_H-1,Black);
  FillChar(ScrShadow,SizeOf(ScrShadow),$FF);
  Lo:=0;Hi:=399;
 End Else Begin
  Lo:=ScrDirtyLo;Hi:=ScrDirtyHi;
  If Lo<0 Then Lo:=0;
  If Hi>399 Then Hi:=399;
 End;
 If Lo<=Hi Then Begin
  HideMouse;
  For Y:=Lo To Hi Do Begin
   A:=ScrBase+LongInt(Y)*80;
   For XB:=0 To 79 Do Begin
    B:=Rd8(A+XB);
    O:=ScrShadow[Y*80+XB];
    If B<>O Then Begin
     ScrShadow[Y*80+XB]:=B;
     For Bit:=0 To 7 Do
      If ((B Xor O) And (128 Shr Bit))<>0 Then Begin
       If (B And (128 Shr Bit))<>0 Then PutPixel(XB*8+Bit,Y+EMU_Y0,Black)
       Else PutPixel(XB*8+Bit,Y+EMU_Y0,White);
      End;
    End;
   End;
  End;
  If (MouseHidden<=0) And Not UserCursor Then ShowMouse;
 End;
 ScrDirtyLo:=400;ScrDirtyHi:=-1;
End;

{ ---------------------------------------------------------------------- }
{ Clavier                                                                 }
{ ---------------------------------------------------------------------- }

Function ScanOfChar(C: Char): Integer;
Const R1 : String[10] = '1234567890';
      R2 : String[10] = 'qwertyuiop';
      R3 : String[9]  = 'asdfghjkl';
      R4 : String[7]  = 'zxcvbnm';
Var P: Integer;
Begin
 ScanOfChar:=0;
 C:=LowerStr(C)[1];
 P:=Pos(C,R1);If P>0 Then Begin ScanOfChar:=1+P;Exit;End;
 P:=Pos(C,R2);If P>0 Then Begin ScanOfChar:=15+P;Exit;End;
 P:=Pos(C,R3);If P>0 Then Begin ScanOfChar:=29+P;Exit;End;
 P:=Pos(C,R4);If P>0 Then Begin ScanOfChar:=43+P;Exit;End;
 If C=' ' Then ScanOfChar:=57;
End;

Procedure RecEvent(Kind: Integer; Data: LongInt); Forward;

Procedure KQPush(V: LongInt);
Begin
 If RecActive Then RecEvent(3,(((V Shr 16) And $FF) Shl 8) Or (V And $FF));
 If ((KQTail+1) Mod KQ_SIZE)<>KQHead Then Begin
  KQ[KQTail]:=V;
  KQTail:=(KQTail+1) Mod KQ_SIZE;
 End;
End;

Function KQEmpty: Boolean;
Begin
 KQEmpty:=KQHead=KQTail;
End;

Function KQPop: LongInt;
Begin
 If KQHead=KQTail Then KQPop:=0
 Else Begin
  KQPop:=KQ[KQHead];
  KQHead:=(KQHead+1) Mod KQ_SIZE;
 End;
End;

{ Lit le clavier hote et alimente la file de touches ST }
Procedure PollKeys;
Var Ch: Char; K: Word; Scan,Asc: Integer;
Begin
 If BatchMode Then Begin
  If Not Eof(ConIn) Then Begin
   Read(ConIn,Ch);
   If Ch=#10 Then Ch:=#13;
   KQPush((LongInt(ScanOfChar(Ch)) Shl 16) Or Ord(Ch));
  End Else If KQEmpty Then KQPush((LongInt(1) Shl 16) Or 27);
  Exit;
 End;
 While KeyPressed Do Begin
  Ch:=ReadKey;
  If Ch=#0 Then Begin
   K:=Ord(ReadKey);
   Scan:=K;Asc:=0;
   If K=83 Then Asc:=127;
   KQPush((LongInt(Scan) Shl 16) Or Asc);
  End Else Begin
   If Ch=#3 Then Begin UserBreak:=True;Continue;End;
   Asc:=Ord(Ch);
   Scan:=ScanOfChar(Ch);
   If Ch=#27 Then Scan:=1
   Else If Ch=#8 Then Scan:=14
   Else If Ch=#9 Then Scan:=15
   Else If Ch=#13 Then Scan:=28;
   KQPush((LongInt(Scan) Shl 16) Or Asc);
  End;
 End;
End;

Procedure EmuIdle;
Begin
 PollKeys;
 If Not BatchMode Then Begin
  BlitScreen(False);
  Delay(2);
 End;
End;

Function WaitKeyEmu: LongInt;
Begin
 If MonActive And Not EmuVisible And Not BatchMode Then Begin
  EmuVisible:=True;BlitScreen(True);
 End;
 If Not Emu_GEM Then ConCursor(True);
 If Not BatchMode Then BlitScreen(False);
 While KQEmpty And Not UserBreak Do EmuIdle;
 If Not Emu_GEM Then ConCursor(False);
 If UserBreak Then WaitKeyEmu:=0 Else WaitKeyEmu:=KQPop;
End;

{ ====================================================================== }
{       PERIPHERIQUES EMULES : SERIE, MIDI, IMPRIMANTE, DISQUETTES        }
{ ====================================================================== }

Const
 STUB_RTS   = $0440;
 KT_UNSH    = $0A00;
 KT_SHIFT   = $0A80;
 KT_CAPS    = $0B00;
 KT_PTRS    = $0B80;
 KBDVECS    = $0B90;
 IOREC_BASE = $0C00;
 BPB_BASE   = $0D00;
 ZERO_WORD  = $0DF0;
 PARM_BLK   = $0F00;
 SCRATCH_BLK= $8000;
 MOUSE_PKT  = $8300;
 ENV_BLK    = $8400;
 ENV_SIZE   = $0200;

 E_OK=0; E_ERROR=-1; E_NOTRDY=-2; E_CRC=-4; E_SEEK=-6; E_RNF=-8; E_WRITF=-10;
 E_READF=-11; E_WRPRO=-13; E_UNDEV=-15;

Type
 TFlp = Record
  On,Changed,RO : Boolean;
  Name : String[80];
  Size : LongInt;
  Spt,Sides,Tracks : Integer;
  F    : File;
 End;

Var
 AuxOutF,MidiOutF,PrnOutF,AuxInF,MidiInF : File;
 AuxOutOpen,MidiOutOpen,PrnOutOpen,AuxInOpen,MidiInOpen : Boolean;
 AuxInTried,MidiInTried : Boolean;
 Flp : Array[0..3] Of TFlp;
 FlpImage : Array[0..3] Of String[80];
 GiRegs : Array[0..15] Of Byte;
 Palette68 : Array[0..15] Of Word;
 RsConfig : Array[0..5] Of LongInt;
 PrtConfig,KbRate,CurBlinkRate,FlpRate : LongInt;
 TimeOffsetSec : LongInt;
 DosoundPtr : LongInt;
 MfpEnable : LongInt;
 XbVec : Array[0..31] Of LongInt;

Procedure DevOut(Var F: File; Var Opened: Boolean; Const Name: String; B: Byte);
Var Bb: Byte;
Begin
 If Not Opened Then Begin
  Assign(F,Name);
  {$I-}
  FileMode:=2;
  Reset(F,1);
  If IOResult<>0 Then Rewrite(F,1)
  Else Seek(F,FileSize(F));
  {$I+}
  If IOResult<>0 Then Exit;
  Opened:=True;
 End;
 Bb:=B;
 {$I-}
 BlockWrite(F,Bb,1);
 {$I+}
 If IOResult<>0 Then Begin End;
End;

Function DevIn(Var F: File; Var Opened,Tried: Boolean; Const Name: String; Var B: Byte): Boolean;
Var Got: LongInt;
Begin
 DevIn:=False;
 If Not Opened Then Begin
  If Tried Then Exit;
  Tried:=True;
  Assign(F,Name);
  {$I-}
  FileMode:=0;
  Reset(F,1);
  {$I+}
  If IOResult<>0 Then Exit;
  Opened:=True;
 End;
 {$I-}
 BlockRead(F,B,1,Got);
 {$I+}
 If (IOResult=0) And (Got=1) Then DevIn:=True;
End;

Function DevAvail(Var F: File; Var Opened,Tried: Boolean; Const Name: String): Boolean;
Begin
 DevAvail:=False;
 If Not Opened Then Begin
  If Tried Then Exit;
  Tried:=True;
  Assign(F,Name);
  {$I-}
  FileMode:=0;
  Reset(F,1);
  {$I+}
  If IOResult<>0 Then Exit;
  Opened:=True;
 End;
 DevAvail:=FilePos(F)<FileSize(F);
End;

Procedure AuxPut(B: Byte);
Begin
 DevOut(AuxOutF,AuxOutOpen,'AUX.OUT',B);
End;

Function AuxGet(Var B: Byte): Boolean;
Begin
 AuxGet:=DevIn(AuxInF,AuxInOpen,AuxInTried,'AUX.IN',B);
End;

Function AuxAvail: Boolean;
Begin
 AuxAvail:=DevAvail(AuxInF,AuxInOpen,AuxInTried,'AUX.IN');
End;

Procedure MidiPut(B: Byte);
Begin
 DevOut(MidiOutF,MidiOutOpen,'MIDI.OUT',B);
End;

Function MidiGet(Var B: Byte): Boolean;
Begin
 MidiGet:=DevIn(MidiInF,MidiInOpen,MidiInTried,'MIDI.IN',B);
End;

Function MidiAvail: Boolean;
Begin
 MidiAvail:=DevAvail(MidiInF,MidiInOpen,MidiInTried,'MIDI.IN');
End;

Procedure PrnPut(B: Byte);
Begin
 DevOut(PrnOutF,PrnOutOpen,'PRINTER.OUT',B);
End;

Procedure DevCloseAll;
Begin
 {$I-}
 If AuxOutOpen Then Close(AuxOutF);
 If MidiOutOpen Then Close(MidiOutF);
 If PrnOutOpen Then Close(PrnOutF);
 If AuxInOpen Then Close(AuxInF);
 If MidiInOpen Then Close(MidiInF);
 {$I+}
 If IOResult<>0 Then Begin End;
 AuxOutOpen:=False;MidiOutOpen:=False;PrnOutOpen:=False;AuxInOpen:=False;MidiInOpen:=False;
 AuxInTried:=False;MidiInTried:=False;
End;

{ ---------------------------------------------------------------------- }
{ Images de disquettes (secteurs de 512 octets)                            }
{ ---------------------------------------------------------------------- }

Procedure FlpClose(D: Integer);
Begin
 If Flp[D].On Then Begin
  {$I-}
  Close(Flp[D].F);
  {$I+}
  If IOResult<>0 Then Begin End;
  Flp[D].On:=False;
 End;
End;

Function FlpMount(D: Integer; Const Name: String): Boolean;
Var B: Array[0..31] Of Byte; Got: LongInt; Bps,Spt,Sd,Tot: LongInt;
Begin
 FlpMount:=False;
 If (D<0) Or (D>3) Then Exit;
 FlpClose(D);
 Assign(Flp[D].F,Name);
 Flp[D].RO:=False;
 {$I-}
 FileMode:=2;
 Reset(Flp[D].F,1);
 If IOResult<>0 Then Begin
  FileMode:=0;
  Reset(Flp[D].F,1);
  Flp[D].RO:=True;
 End;
 {$I+}
 If IOResult<>0 Then Exit;
 Flp[D].On:=True;Flp[D].Changed:=True;Flp[D].Name:=Name;
 Flp[D].Size:=FileSize(Flp[D].F);
 FillChar(B,SizeOf(B),0);
 {$I-}
 BlockRead(Flp[D].F,B,32,Got);
 {$I+}
 If IOResult<>0 Then Begin End;
 Bps:=B[11]+B[12]*256;Spt:=B[24]+B[25]*256;Sd:=B[26]+B[27]*256;Tot:=B[19]+B[20]*256;
 If (Bps<>512) Or (Spt<1) Or (Spt>30) Or (Sd<1) Or (Sd>2) Then Begin
  Spt:=9;Sd:=2;
  If Flp[D].Size<=368640 Then Sd:=1;
  If (Flp[D].Size=409600) Or (Flp[D].Size=819200) Then Spt:=10;
  If Flp[D].Size>900000 Then Spt:=18;
 End;
 Flp[D].Spt:=Spt;Flp[D].Sides:=Sd;
 Flp[D].Tracks:=Flp[D].Size Div (512*Spt*Sd);
 If Flp[D].Tracks<1 Then Flp[D].Tracks:=1;
 FlpMount:=True;
End;

{ Lit / ecrit Count secteurs a partir du secteur logique Lsn }
Function FlpRW(D: Integer; Lsn,Count: LongInt; Buf: LongInt; Wr: Boolean): Integer;
Var I,J: LongInt; Tmp: Array[0..511] Of Byte; Got: LongInt;
Begin
 FlpRW:=E_NOTRDY;
 If (D<0) Or (D>3) Or Not Flp[D].On Then Exit;
 If Wr And Flp[D].RO Then Begin FlpRW:=E_WRPRO;Exit;End;
 If (Lsn<0) Or ((Lsn+Count)*512>Flp[D].Size) Then Begin FlpRW:=E_RNF;Exit;End;
 For I:=0 To Count-1 Do Begin
  {$I-}
  Seek(Flp[D].F,(Lsn+I)*512);
  If Wr Then Begin
   For J:=0 To 511 Do Tmp[J]:=Rd8(Buf+I*512+J);
   BlockWrite(Flp[D].F,Tmp,512,Got);
  End Else Begin
   BlockRead(Flp[D].F,Tmp,512,Got);
   For J:=0 To 511 Do Wr8(Buf+I*512+J,Tmp[J]);
  End;
  {$I+}
  If IOResult<>0 Then Begin If Wr Then FlpRW:=E_WRITF Else FlpRW:=E_READF;Exit;End;
 End;
 FlpRW:=E_OK;
End;

Procedure DevInitAll;
Var I: Integer;
Begin
 DevCloseAll;
 For I:=0 To 3 Do FlpClose(I);
 FillChar(GiRegs,SizeOf(GiRegs),0);
 FillChar(Palette68,SizeOf(Palette68),0);
 Palette68[0]:=$0777;
 PrtConfig:=0;KbRate:=$0F0F;CurBlinkRate:=30;
 FillChar(RsConfig,SizeOf(RsConfig),0);
 FillChar(XbVec,SizeOf(XbVec),0);
 DosoundPtr:=0;MfpEnable:=0;FlpRate:=2;
 For I:=0 To 3 Do Begin
  If FlpImage[I]<>'' Then Begin
   If FileExists(FlpImage[I]) Then FlpMount(I,FlpImage[I]);
  End Else Begin
   If FileExists('DISK'+Chr(65+I)+'.ST') Then FlpMount(I,'DISK'+Chr(65+I)+'.ST')
   Else If FileExists('disk'+Chr(97+I)+'.st') Then FlpMount(I,'disk'+Chr(97+I)+'.st');
  End;
 End;
End;

{ ====================================================================== }
{       TOS SIMPLIFIE (GEMDOS / BIOS / XBIOS / VDI / AES) ET AMIGAOS     }
{ ====================================================================== }

Const
 BP_ADDR     = $10000;
 STUB_EXIT   = $0400;
 STUB_USER   = $0410;
 LINEA_VARS  = $0500;
 EXECBASE    = $2000;
 DOSBASE     = $3000;
 INTUIBASE   = $3800;
 GFXBASE     = $4000;
 AMIGA_LO    = $1C00;
 AMIGA_HI    = $4100;
 MAXFH       = 45;

Var
 HitPa,HeapLo,HeapHi : LongInt;
 MBase,MSize : Array[1..64] Of LongInt;
 MCnt        : Integer;
 DtaAddr     : LongInt;
 FHUsed      : Array[6..MAXFH] Of Boolean;
 FHs         : Array[6..MAXFH] Of File;
 DtaSR       : SearchRec;
 DtaActive   : Boolean;
 AmigaRun    : Boolean;
 UnknownCall : String;
 VdiLineCol,VdiFillInt,VdiFillCol,VdiTextCol,VdiFillStyle : Integer;
 RandSeed68  : LongInt;
 ProgName    : String;
 ProgCmd     : String;

Function HostPath(Const S0: String): String;
Var S: String; I: Integer;
Begin
 S:=S0;
 {$IFDEF FPC}
 {$IFDEF UNIX}
 If (Length(S)>=2) And (S[2]=':') Then S:=Copy(S,3,255);
 If (S<>'') And (S[1]='\') Then S:=Copy(S,2,255);
 If S='' Then S:='.';
 For I:=1 To Length(S) Do If S[I]='\' Then S[I]:='/';
 If Not FileExists(S) Then Begin
  If FileExists(LowerStr(S)) Then S:=LowerStr(S);
 End;
 {$ENDIF}
 {$ENDIF}
 HostPath:=S;
End;

Procedure CloseAllFiles;
Var I: Integer;
Begin
 For I:=6 To MAXFH Do
  If FHUsed[I] Then Begin
   {$I-}
   Close(FHs[I]);
   {$I+}
   If IOResult=0 Then Begin End;
   FHUsed[I]:=False;
  End;
End;

Function AllocFH: Integer;
Var I: Integer;
Begin
 AllocFH:=0;
 For I:=6 To MAXFH Do If Not FHUsed[I] Then Begin AllocFH:=I;Exit;End;
End;

{ Gestion du tas (Malloc/Mfree) }
Function HeapFindGap(N: LongInt): LongInt;
Var Start: LongInt; I: Integer; Moved: Boolean;
Begin
 Start:=HeapLo;
 Repeat
  Moved:=False;
  For I:=1 To MCnt Do
   If (MBase[I]<Start+N) And (MBase[I]+MSize[I]>Start) Then Begin
    Start:=MBase[I]+MSize[I];Moved:=True;
   End;
 Until Not Moved;
 If Start+N<=HeapHi Then HeapFindGap:=Start Else HeapFindGap:=0;
End;

Function HeapLargest: LongInt;
Var Start,Best,Nxt: LongInt; I: Integer; Done: Boolean;
Begin
 Best:=0;Start:=HeapLo;
 Repeat
  Nxt:=HeapHi;
  For I:=1 To MCnt Do
   If (MBase[I]>=Start) And (MBase[I]<Nxt) Then Nxt:=MBase[I];
  If Nxt-Start>Best Then Best:=Nxt-Start;
  Done:=True;
  For I:=1 To MCnt Do
   If MBase[I]=Nxt Then Begin Start:=MBase[I]+MSize[I];Done:=False;End;
  If Nxt>=HeapHi Then Done:=True;
 Until Done;
 HeapLargest:=Best;
End;

Function DoMalloc(N: LongInt): LongInt;
Var A: LongInt;
Begin
 If N=-1 Then Begin DoMalloc:=HeapLargest;Exit;End;
 If Odd(N) Then Inc(N);
 If (N<=0) Or (MCnt>=64) Then Begin DoMalloc:=0;Exit;End;
 A:=HeapFindGap(N);
 If A<>0 Then Begin
  Inc(MCnt);MBase[MCnt]:=A;MSize[MCnt]:=N;
 End;
 DoMalloc:=A;
End;

Function DoMfree(A: LongInt): LongInt;
Var I,J: Integer;
Begin
 DoMfree:=-40;
 For I:=1 To MCnt Do
  If MBase[I]=A Then Begin
   For J:=I To MCnt-1 Do Begin MBase[J]:=MBase[J+1];MSize[J]:=MSize[J+1];End;
   Dec(MCnt);
   DoMfree:=0;Exit;
  End;
End;

{ ---------------------------------------------------------------------- }
{ GEMDOS                                                                  }
{ ---------------------------------------------------------------------- }

Function PW(Off: LongInt): LongInt;
Begin
 PW:=Rd16(Rg[15]+Off);
End;

Function PL(Off: LongInt): LongInt;
Begin
 PL:=Rd32(Rg[15]+Off);
End;

Procedure KeyToStr;
Begin
End;

Procedure FillDta;
Var N: String; I: Integer; T: LongInt;
Begin
 N:=Upper(DtaSR.Name);
 Wr8(DtaAddr+21,DtaSR.Attr And $FF);
 T:=DtaSR.Time;
 Wr16(DtaAddr+22,T And $FFFF);
 Wr16(DtaAddr+24,ShrL(T,16) And $FFFF);
 Wr32(DtaAddr+26,DtaSR.Size);
 For I:=0 To 13 Do Wr8(DtaAddr+30+I,0);
 For I:=1 To Length(N) Do If I<=13 Then Wr8(DtaAddr+29+I,Ord(N[I]));
End;

Function ConLineInput(Buf: LongInt): LongInt;
Var MaxL,Len: Integer; K: LongInt; Ch: Integer;
Begin
 MaxL:=Rd8(Buf);Len:=0;
 Repeat
  K:=WaitKeyEmu;
  If UserBreak Then Break;
  Ch:=K And $FF;
  If Ch=13 Then Begin ConPut(13);ConPut(10);Break;End
  Else If Ch=8 Then Begin
   If Len>0 Then Begin Dec(Len);ConPut(8);ConPut(32);ConPut(8);End;
  End Else If (Ch>=32) And (Len<MaxL) Then Begin
   Wr8(Buf+2+Len,Ch);Inc(Len);ConPut(Ch);
  End;
 Until False;
 Wr8(Buf+1,Len);
 ConLineInput:=Len;
End;

Function DoPexec(Mode: Integer; NameP,CmdP,EnvP: LongInt): LongInt; Forward;

Procedure Gemdos;
Var Fn: LongInt; R: LongInt; H: Integer; I,N: LongInt; S: String; K: LongInt; Buf: Array[0..4095] Of Byte;
    Cnt,Got,A,Off: LongInt; Bb: Byte; Y,Mo,D,Dw,Hh,Mi,Se,Hs: Word; Fp: LongInt;
    FPtr: ^File;
Begin
 Fn:=PW(0);
 R:=0;
 Case Fn Of
  $00: Begin StopReason:=STOP_EXIT;ExitCode:=0;End;
  $4C: Begin StopReason:=STOP_EXIT;ExitCode:=SExt(PW(2),2);End;
  $31: Begin StopReason:=STOP_EXIT;ExitCode:=SExt(PW(6),2);End;
  $01: Begin
        K:=WaitKeyEmu;
        If (K And $FF)<>0 Then ConPut(K And $FF);
        R:=K;
       End;
  $02: ConPut(PW(2) And $FF);
  $03: Begin If AuxGet(Bb) Then R:=Bb Else R:=0;End;
  $04: AuxPut(PW(2) And $FF);
  $05: Begin PrnPut(PW(2) And $FF);R:=-1;End;
  $06: Begin
        If (PW(2) And $FF)=$FF Then Begin
         PollKeys;
         If KQEmpty Then R:=0 Else R:=KQPop;
        End Else ConPut(PW(2) And $FF);
       End;
  $07,$08: R:=WaitKeyEmu;
  $09: Begin
        A:=PL(2);
        N:=0;
        While (Rd8(A+N)<>0) And (N<30000) Do Begin ConPut(Rd8(A+N));Inc(N);End;
       End;
  $0A: R:=ConLineInput(PL(2));
  $0B: Begin PollKeys;If KQEmpty Then R:=0 Else R:=-1;End;
  $0E: R:=4;
  $10: R:=-1;
  $11: R:=-1;
  $12: Begin If AuxAvail Then R:=-1 Else R:=0;End;
  $13: R:=-1;
  $19: R:=2;
  $1A: DtaAddr:=PL(2);
  $20: Begin
        A:=PL(2);
        If A=0 Then Begin
         If (SRv And SR_S)=0 Then Begin
          SSPv:=Rg[15];USPv:=Rg[15];
          SRv:=SRv Or SR_S;
          R:=Rg[15];
         End Else R:=Rg[15];
        End Else If A=1 Then Begin
         If (SRv And SR_S)<>0 Then R:=-1 Else R:=0;
        End Else Begin
         SRv:=SRv And (Not SR_S);
         R:=0;
        End;
       End;
  $2A: Begin
        GetDate(Y,Mo,D,Dw);
        R:=((Y-1980) Shl 9) Or (Mo Shl 5) Or D;
       End;
  $2B: R:=0;
  $2C: Begin
        GetTime(Hh,Mi,Se,Hs);
        R:=(Hh Shl 11) Or (Mi Shl 5) Or (Se Div 2);
       End;
  $2D: R:=0;
  $2F: R:=DtaAddr;
  $30: R:=$1300;
  $36: Begin
        A:=PL(2);
        Wr32(A,10000);Wr32(A+4,20000);Wr32(A+8,512);Wr32(A+12,2);
       End;
  $39,$3A,$3B: R:=0;
  $3C,$3D: Begin
        S:=HostPath(RdStr(PL(2),200));
        H:=AllocFH;
        If H=0 Then R:=-35
        Else Begin
         Assign(FHs[H],S);
         {$I-}
         If Fn=$3C Then Rewrite(FHs[H],1)
         Else Begin
          If PW(6)=0 Then FileMode:=0 Else FileMode:=2;
          Reset(FHs[H],1);
         End;
         {$I+}
         If IOResult<>0 Then R:=-33
         Else Begin FHUsed[H]:=True;R:=H;End;
        End;
       End;
  $3E: Begin
        H:=PW(2);
        If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
         {$I-}
         Close(FHs[H]);
         {$I+}
         If IOResult=0 Then Begin End;
         FHUsed[H]:=False;
         R:=0;
        End Else R:=-37;
       End;
  $3F: Begin
        H:=PW(2);Cnt:=PL(4);A:=PL(8);
        If H=2 Then Begin
         R:=0;
         While (R<Cnt) And AuxGet(Bb) Do Begin Wr8(A+R,Bb);Inc(R);End;
        End Else If H=0 Then Begin
         { lecture sur la console : une ligne }
         R:=0;
         While R<Cnt Do Begin
          K:=WaitKeyEmu;
          If UserBreak Then Break;
          Wr8(A+R,K And $FF);Inc(R);
          ConPut(K And $FF);
          If (K And $FF)=13 Then Begin
           If R<Cnt Then Begin Wr8(A+R,10);Inc(R);End;
           ConPut(10);
           Break;
          End;
         End;
        End Else If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
         R:=0;
         While Cnt>0 Do Begin
          If Cnt>4096 Then N:=4096 Else N:=Cnt;
          {$I-}
          BlockRead(FHs[H],Buf,N,Got);
          {$I+}
          If IOResult<>0 Then Got:=0;
          For I:=0 To Got-1 Do Wr8(A+R+I,Buf[I]);
          R:=R+Got;Cnt:=Cnt-Got;
          If Got<N Then Break;
         End;
        End Else R:=-37;
       End;
  $40: Begin
        H:=PW(2);Cnt:=PL(4);A:=PL(8);
        If (H=1) Or (H=2) Or (H=3) Then Begin
         For I:=0 To Cnt-1 Do Begin
          If H=1 Then ConPut(Rd8(A+I)) Else If H=2 Then AuxPut(Rd8(A+I)) Else PrnPut(Rd8(A+I));
         End;
         R:=Cnt;
        End Else If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
         R:=0;
         While Cnt>0 Do Begin
          If Cnt>4096 Then N:=4096 Else N:=Cnt;
          For I:=0 To N-1 Do Buf[I]:=Rd8(A+R+I);
          {$I-}
          BlockWrite(FHs[H],Buf,N,Got);
          {$I+}
          If IOResult<>0 Then Got:=0;
          R:=R+Got;Cnt:=Cnt-Got;
          If Got<N Then Break;
         End;
        End Else R:=-37;
       End;
  $41: Begin
        S:=HostPath(RdStr(PL(2),200));
        Assign(FHs[6],S);
        {$I-}
        Erase(FHs[6]);
        {$I+}
        If IOResult<>0 Then R:=-33 Else R:=0;
       End;
  $42: Begin
        Off:=PL(2);H:=PW(6);N:=PW(8);
        If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
         {$I-}
         Case N Of
          0: Fp:=Off;
          1: Fp:=FilePos(FHs[H])+Off;
         Else Fp:=FileSize(FHs[H])+Off;
         End;
         If Fp<0 Then Fp:=0;
         Seek(FHs[H],Fp);
         {$I+}
         If IOResult<>0 Then R:=-64 Else R:=Fp;
        End Else R:=-37;
       End;
  $43: R:=0;
  $45: R:=-36;
  $47: Begin
        A:=PL(2);Wr8(A,Ord('\'));Wr8(A+1,0);
       End;
  $48: R:=DoMalloc(PL(2));
  $49: R:=DoMfree(PL(2));
  $4A: Begin
        A:=PL(6);N:=PL(8);
        If A=BP_ADDR Then Begin
         HeapLo:=BP_ADDR+((N+1) And (Not 1));
         If HeapLo>HeapHi Then HeapLo:=HeapHi;
        End;
        R:=0;
       End;
  $4B: R:=DoPexec(PW(2),PL(4),PL(8),PL(12));
  $4E: Begin
        S:=HostPath(RdStr(PL(2),200));
        If DtaActive Then Begin
         {$IFDEF FPC}
         FindClose(DtaSR);
         {$ENDIF}
        End;
        FindFirst(S,AnyFile,DtaSR);
        If DosError=0 Then Begin DtaActive:=True;FillDta;R:=0;End
        Else Begin DtaActive:=False;R:=-33;End;
       End;
  $4F: Begin
        If Not DtaActive Then R:=-33
        Else Begin
         FindNext(DtaSR);
         If DosError=0 Then Begin FillDta;R:=0;End Else Begin R:=-33;DtaActive:=False;End;
        End;
       End;
  $56: R:=0;
  $57: R:=0;
 Else Begin
   UnknownCall:='GEMDOS $'+Hex2(Fn);
   R:=-32;
  End;
 End;
 Rg[0]:=R;
End;

{ ====================================================================== }
{                       BIOS ET XBIOS DE L'ATARI ST                      }
{ ====================================================================== }

Var
 KeytblInit : Boolean;
 IorecInit  : Boolean;
 MouseVecUser : LongInt;
 TimeBase : LongInt;
 TimeSetPacked : LongInt;
 TimeSetOn : Boolean;

Procedure ConPutRaw(B: Byte);
Begin
 If BatchMode Then Begin Write(ConOut,Chr(B));Exit;End;
 ConGlyph(ConRow,ConCol,B,ConRev);
 Inc(ConCol);
 If ConCol>=CON_COLS Then Begin
  If ConWrap Then ConNewLine Else ConCol:=CON_COLS-1;
 End;
End;

Procedure KeyTables;
Const
 Rows : Array[0..45,0..2] Of Byte = (
  (1,27,27),(2,49,33),(3,50,64),(4,51,35),(5,52,36),(6,53,37),(7,54,94),(8,55,38),(9,56,42),(10,57,40),
  (11,48,41),(12,45,95),(13,61,43),(14,8,8),(15,9,9),(26,91,123),(27,93,125),(28,13,13),(39,59,58),(40,39,34),
  (41,96,126),(43,92,124),(51,44,60),(52,46,62),(53,47,63),(57,32,32),(83,127,127),(74,45,45),(78,43,43),(99,40,40),
  (100,41,41),(101,47,47),(102,42,42),(103,55,55),(104,56,56),(105,57,57),(106,52,52),(107,53,53),(108,54,54),(109,49,49),
  (110,50,50),(111,51,51),(112,48,48),(113,46,46),(114,13,13),(0,0,0));
 L1 : String[10] = 'qwertyuiop';
 L2 : String[9]  = 'asdfghjkl';
 L3 : String[7]  = 'zxcvbnm';
Var I: Integer; C: Char;
Begin
 For I:=0 To 127 Do Begin Wr8(KT_UNSH+I,0);Wr8(KT_SHIFT+I,0);Wr8(KT_CAPS+I,0);End;
 For I:=0 To 44 Do Begin
  Wr8(KT_UNSH+Rows[I,0],Rows[I,1]);Wr8(KT_SHIFT+Rows[I,0],Rows[I,2]);Wr8(KT_CAPS+Rows[I,0],Rows[I,1]);
 End;
 For I:=1 To 10 Do Begin
  Wr8(KT_UNSH+15+I,Ord(L1[I]));Wr8(KT_SHIFT+15+I,Ord(UpCase(L1[I])));Wr8(KT_CAPS+15+I,Ord(UpCase(L1[I])));
 End;
 For I:=1 To 9 Do Begin
  Wr8(KT_UNSH+29+I,Ord(L2[I]));Wr8(KT_SHIFT+29+I,Ord(UpCase(L2[I])));Wr8(KT_CAPS+29+I,Ord(UpCase(L2[I])));
 End;
 For I:=1 To 7 Do Begin
  Wr8(KT_UNSH+43+I,Ord(L3[I]));Wr8(KT_SHIFT+43+I,Ord(UpCase(L3[I])));Wr8(KT_CAPS+43+I,Ord(UpCase(L3[I])));
 End;
 Wr32(KT_PTRS,KT_UNSH);Wr32(KT_PTRS+4,KT_SHIFT);Wr32(KT_PTRS+8,KT_CAPS);
End;

{ Initialise les structures systeme (vecteurs clavier, tables de touches) }
Procedure SysTablesInit;
Var I: Integer;
Begin
 Wr16(STUB_RTS,$4E75);
 KeyTables;
 For I:=0 To 8 Do Wr32(KBDVECS+I*4,STUB_RTS);
 Wr32(ZERO_WORD,0);
 IorecInit:=False;
 MouseVecUser:=0;
End;

{ Date et heure GEMDOS en secondes depuis un instant de reference }
Function PackedToSec(P: LongInt; Var Y,Mo,D,H,Mi,S: Integer): Boolean;
Begin
 Y:=((ShrL(P,25) And 127)+1980);Mo:=ShrL(P,21) And 15;D:=ShrL(P,16) And 31;
 H:=ShrL(P,11) And 31;Mi:=ShrL(P,5) And 63;S:=(P And 31)*2;
 PackedToSec:=True;
End;

Function DaysIn(Y,M: Integer): Integer;
Begin
 Case M Of
  2: If ((Y Mod 4)=0) And (((Y Mod 100)<>0) Or ((Y Mod 400)=0)) Then DaysIn:=29 Else DaysIn:=28;
  4,6,9,11: DaysIn:=30;
 Else DaysIn:=31;
 End;
End;

Function PackedAdd(P: LongInt; Secs: LongInt): LongInt;
Var Y,Mo,D,H,Mi,S: Integer; T: LongInt;
Begin
 PackedToSec(P,Y,Mo,D,H,Mi,S);
 T:=LongInt(H)*3600+Mi*60+S+Secs;
 While T>=86400 Do Begin
  T:=T-86400;Inc(D);
  If D>DaysIn(Y,Mo) Then Begin D:=1;Inc(Mo);If Mo>12 Then Begin Mo:=1;Inc(Y);End;End;
 End;
 H:=T Div 3600;Mi:=(T Mod 3600) Div 60;S:=T Mod 60;
 PackedAdd:=(LongInt((Y-1980) Shl 9 Or (Mo Shl 5) Or D) Shl 16) Or LongInt((H Shl 11) Or (Mi Shl 5) Or (S Div 2));
End;

Function HostPacked: LongInt;
Var Y,Mo,D,Dw,H,Mi,S,Hs: Word;
Begin
 GetDate(Y,Mo,D,Dw);GetTime(H,Mi,S,Hs);
 HostPacked:=(LongInt((Y-1980) Shl 9 Or (Mo Shl 5) Or D) Shl 16) Or LongInt((H Shl 11) Or (Mi Shl 5) Or (S Div 2));
End;

Function MfpEndAddr: LongInt;
Begin
 MfpEndAddr:=0;
End;

Procedure ProtoBootSector(Buf: LongInt; Serial: LongInt; DiskType: Integer; Exec: Integer);
Var I,Sum: Integer; Spc,Nroot,Media,Spf,Sides,Tot: Integer; W: LongInt;
Begin
 Case DiskType Of
  0: Begin Tot:=360;Spc:=1;Nroot:=64;Media:=$FC;Spf:=2;Sides:=1;End;
  1: Begin Tot:=720;Spc:=2;Nroot:=112;Media:=$FD;Spf:=2;Sides:=2;End;
  2: Begin Tot:=720;Spc:=2;Nroot:=112;Media:=$F8;Spf:=3;Sides:=1;End;
 Else Begin Tot:=1440;Spc:=2;Nroot:=112;Media:=$F9;Spf:=5;Sides:=2;End;
 End;
 If DiskType>=0 Then Begin
  Wr8(Buf,$60);Wr8(Buf+1,$1C);
  For I:=2 To 7 Do Wr8(Buf+I,Ord('L'));
  If Serial<0 Then Serial:=(RandSeed68 Shr 8) And $FFFFFF;
  Wr8(Buf+8,ShrL(Serial,16) And $FF);Wr8(Buf+9,ShrL(Serial,8) And $FF);Wr8(Buf+10,Serial And $FF);
  Wr8(Buf+11,0);Wr8(Buf+12,2);Wr8(Buf+13,Spc);Wr8(Buf+14,1);Wr8(Buf+15,0);
  Wr8(Buf+16,2);Wr8(Buf+17,Nroot And $FF);Wr8(Buf+18,Nroot Shr 8);
  Wr8(Buf+19,Tot And $FF);Wr8(Buf+20,Tot Shr 8);Wr8(Buf+21,Media);
  Wr8(Buf+22,Spf);Wr8(Buf+23,0);Wr8(Buf+24,9);Wr8(Buf+25,0);Wr8(Buf+26,Sides);Wr8(Buf+27,0);
  For I:=28 To 29 Do Wr8(Buf+I,0);
 End;
 Wr16(Buf+510,0);
 Sum:=0;
 For I:=0 To 254 Do Sum:=(Sum+Rd16(Buf+I*2)) And $FFFF;
 If Exec<>0 Then W:=($1234-Sum) And $FFFF Else W:=($1235-Sum) And $FFFF;
 Wr16(Buf+510,W);
End;

Procedure PrnDumpByte(Var F: File; B: Byte);
Begin
 BlockWrite(F,B,1);
End;

Procedure ScreenDump;
Var F: File; I: Integer; Hd: String;
Begin
 Assign(F,'SCRDUMP.PBM');
 {$I-}
 Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 Hd:='P4'#10'640 400'#10;
 BlockWrite(F,Hd[1],Length(Hd));
 For I:=0 To SCR_BYTES-1 Do PrnDumpByte(F,Rd8(ScrBase+I));
 Close(F);
End;

{ Bloc d'environnement invite (shel_envrn, Pexec) }
Procedure EnvInit;
Var A: LongInt; S: String;
 Procedure Add(Const V: String);
 Var I: Integer;
 Begin
  For I:=1 To Length(V) Do Wr8(A+I-1,Ord(V[I]));
  Wr8(A+Length(V),0);A:=A+Length(V)+1;
 End;
Begin
 A:=ENV_BLK;
 Add('PATH=A:\;C:\');
 Add('TERM=st52');
 Add('HOME=C:\');
 S:=GetEnv('LANGUAGE');
 If S<>'' Then Add('LANGUAGE='+S);
 Wr8(A,0);Wr8(A+1,0);
End;

Procedure Bios;
Var Fn: LongInt; R,K,Cnt,Rec: LongInt; Dev,I: Integer; B: Byte; Sec: Integer; Bp,Boot: LongInt;
    Bps,Spc,Res,Nfat,Nroot,Tot,Spf,Rdlen,Datrec,Ncl: LongInt; Tmp: Array[0..31] Of Byte;
Begin
 Fn:=PW(0);
 R:=0;
 Case Fn Of
  0: Begin
      K:=PL(2);
      Wr32(K,0);Wr32(K+4,0);Wr32(K+8,0);
     End;
  1: Begin
      Dev:=PW(2);
      Case Dev Of
       1: If AuxAvail Then R:=-1 Else R:=0;
       2: Begin PollKeys;If KQEmpty Then R:=0 Else R:=-1;End;
       3: If MidiAvail Then R:=-1 Else R:=0;
      Else R:=0;
      End;
     End;
  2: Begin
      Dev:=PW(2);
      Case Dev Of
       1: If AuxGet(B) Then R:=B Else R:=0;
       2: R:=WaitKeyEmu;
       3: If MidiGet(B) Then R:=B Else R:=0;
      Else R:=0;
      End;
     End;
  3: Begin
      Dev:=PW(2);
      Case Dev Of
       0: PrnPut(PW(4) And $FF);
       1: AuxPut(PW(4) And $FF);
       2: ConPut(PW(4) And $FF);
       3: MidiPut(PW(4) And $FF);
       5: ConPutRaw(PW(4) And $FF);
      End;
     End;
  4: Begin
      { Rwabs : rwflag, buf, count, recno, dev, lrecno }
      Dev:=PW(12);
      If SExt(Rd16(Rg[15]+10),2)=-1 Then Rec:=PL(14) Else Rec:=Rd16(Rg[15]+10);
      Cnt:=SExt(PW(8),2);
      If (PW(2) And 1)=0 Then R:=FlpRW(Dev,Rec,Cnt,PL(4),False)
      Else R:=FlpRW(Dev,Rec,Cnt,PL(4),True);
      If (Dev>3) Then R:=E_UNDEV;
     End;
  5: Begin
      R:=Rd32(PW(2)*4);
      If PL(4)<>-1 Then Wr32(PW(2)*4,PL(4));
     End;
  6: R:=20;
  7: Begin
      { Getbpb }
      Dev:=PW(2);
      R:=0;
      If (Dev>=0) And (Dev<=3) And Flp[Dev].On Then Begin
       Boot:=BPB_BASE+Dev*32;
       Tot:=0;
       { relit le secteur de boot }
       If FlpRW(Dev,0,1,BPB_BASE+$100,False)=0 Then Begin
        For I:=0 To 31 Do Tmp[I]:=Rd8(BPB_BASE+$100+I);
        Bps:=Tmp[11]+Tmp[12]*256;Spc:=Tmp[13];Res:=Tmp[14]+Tmp[15]*256;Nfat:=Tmp[16];
        Nroot:=Tmp[17]+Tmp[18]*256;Tot:=Tmp[19]+Tmp[20]*256;Spf:=Tmp[22]+Tmp[23]*256;
        If (Bps<>512) Or (Spc=0) Or (Nfat=0) Then Begin
         Bps:=512;Spc:=2;Res:=1;Nfat:=2;Nroot:=112;Spf:=5;Tot:=Flp[Dev].Size Div 512;
        End;
        Rdlen:=(Nroot*32+511) Div 512;
        Datrec:=Res+Nfat*Spf+Rdlen;
        Ncl:=(Tot-Datrec) Div Spc;
        Wr16(Boot,Bps);Wr16(Boot+2,Spc);Wr16(Boot+4,Bps*Spc);Wr16(Boot+6,Rdlen);
        Wr16(Boot+8,Spf);Wr16(Boot+10,Res+Spf);Wr16(Boot+12,Datrec);Wr16(Boot+14,Ncl);
        If Ncl>4086 Then Wr16(Boot+16,1) Else Wr16(Boot+16,0);
        Flp[Dev].Changed:=False;
        R:=Boot;
       End;
      End;
     End;
  8: Begin
      Dev:=PW(2);
      If Dev=1 Then R:=-1 Else If Dev=0 Then R:=-1 Else If Dev=3 Then R:=-1 Else R:=-1;
     End;
  9: Begin
      Dev:=PW(2);
      If (Dev>=0) And (Dev<=3) And Flp[Dev].On Then Begin
       If Flp[Dev].Changed Then R:=2 Else R:=0;
      End Else R:=0;
     End;
  10: Begin
       R:=4;
       For I:=0 To 3 Do If Flp[I].On Then R:=R Or (1 Shl I);
      End;
  11: R:=0;
 Else R:=0;
 End;
 Rg[0]:=R;
End;

Procedure Xbios;
Var Fn: LongInt; R,A,B,L: LongInt; Hh,Mi,Se,Hs,Y,Mo,D,Dw: Word; Dev,Sec,Trk,Sd,Cnt,I: Integer; Lsn: LongInt;
    Tmp: Byte; Old: LongInt; V: LongInt;
Begin
 Fn:=PW(0);
 R:=0;
 Case Fn Of
  0: Begin
      MouseVecUser:=PL(8);
      If MouseVecUser<>0 Then Wr32(KBDVECS+16,MouseVecUser) Else Wr32(KBDVECS+16,STUB_RTS);
     End;
  1: R:=0;
  2: R:=ScrBase;
  3: R:=DrawBase;
  4: R:=2;
  5: Begin
      A:=PL(2);B:=PL(6);
      If A<>-1 Then DrawBase:=A;
      If B<>-1 Then Begin
       ScrBase:=B;
       ScrDirtyLo:=0;ScrDirtyHi:=399;
       FillChar(ScrShadow,SizeOf(ScrShadow),$FF);
      End;
     End;
  6: Begin
      A:=PL(2);
      For I:=0 To 15 Do Palette68[I]:=Rd16(A+I*2);
     End;
  7: Begin
      I:=PW(2) And 15;
      R:=Palette68[I];
      If SExt(PW(4),2)>=0 Then Palette68[I]:=PW(4) And $777;
     End;
  8,9: Begin
        { Floprd / Flopwr }
        A:=PL(2);Dev:=PW(10);Sec:=PW(12);Trk:=PW(14);Sd:=PW(16);Cnt:=PW(18);
        If (Dev<0) Or (Dev>1) Or Not Flp[Dev].On Then R:=E_NOTRDY
        Else If (Sd>=Flp[Dev].Sides) Or (Trk>=Flp[Dev].Tracks) Or (Sec<1) Or (Sec>Flp[Dev].Spt) Then R:=E_RNF
        Else Begin
         Lsn:=(LongInt(Trk)*Flp[Dev].Sides+Sd)*Flp[Dev].Spt+(Sec-1);
         R:=FlpRW(Dev,Lsn,Cnt,A,Fn=9);
        End;
       End;
  10: Begin
       { Flopfmt }
       A:=PL(2);Dev:=PW(10);Trk:=PW(14);Sd:=PW(16);
       If (Dev<0) Or (Dev>1) Or Not Flp[Dev].On Then R:=E_NOTRDY
       Else If PL(20)<>-2023406815 Then R:=E_ERROR
       Else If (Sd>=Flp[Dev].Sides) Or (Trk>=Flp[Dev].Tracks) Then R:=E_SEEK
       Else Begin
        Cnt:=PW(12);
        For I:=0 To 511 Do Wr8(SCRATCH_BLK+I,((PW(24) Shr 8) And $FF));
        Lsn:=(LongInt(Trk)*Flp[Dev].Sides+Sd)*Flp[Dev].Spt;
        For I:=0 To Cnt-1 Do FlpRW(Dev,Lsn+I,1,SCRATCH_BLK,True);
        Wr16(ZERO_WORD,0);
        R:=ZERO_WORD;
       End;
      End;
  11: R:=0;
  12: Begin
       Cnt:=PW(2)+1;A:=PL(4);
       For I:=0 To Cnt-1 Do MidiPut(Rd8(A+I));
      End;
  13: Begin
       I:=PW(2) And 15;
       Wr32($100+I*4,PL(4));XbVec[I]:=PL(4);
      End;
  14: Begin
       If Not IorecInit Then Begin
        IorecInit:=True;
        For I:=0 To 2 Do Begin
         A:=DoMalloc(512);
         Wr32(IOREC_BASE+I*$40,A);Wr16(IOREC_BASE+I*$40+4,256);
         Wr16(IOREC_BASE+I*$40+6,0);Wr16(IOREC_BASE+I*$40+8,0);
         Wr16(IOREC_BASE+I*$40+10,64);Wr16(IOREC_BASE+I*$40+12,192);
         Wr32(IOREC_BASE+I*$40+14,A+256);Wr16(IOREC_BASE+I*$40+18,256);
         Wr16(IOREC_BASE+I*$40+20,0);Wr16(IOREC_BASE+I*$40+22,0);
         Wr16(IOREC_BASE+I*$40+24,64);Wr16(IOREC_BASE+I*$40+26,192);
        End;
       End;
       R:=IOREC_BASE+(PW(2) And 3)*$40;
      End;
  15: Begin
       { Rsconf : retourne l'ancienne configuration }
       R:=RsConfig[0];
       If SExt(PW(2),2)<>-2 Then Begin
        RsConfig[0]:=(LongInt(PW(2)) Shl 16) Or PW(4);
        RsConfig[1]:=PW(6);RsConfig[2]:=PW(8);RsConfig[3]:=PW(10);RsConfig[4]:=PW(12);
       End;
      End;
  16: Begin
       A:=PL(2);
       If A<>-1 Then Wr32(KT_PTRS,A);
       A:=PL(6);If A<>-1 Then Wr32(KT_PTRS+4,A);
       A:=PL(10);If A<>-1 Then Wr32(KT_PTRS+8,A);
       R:=KT_PTRS;
      End;
  17: Begin
       RandSeed68:=RandSeed68*1103515245+12345;
       R:=ShrL(RandSeed68,8) And $FFFFFF;
      End;
  18: ProtoBootSector(PL(2),PL(6),SExt(PW(10),2),PW(12));
  19: Begin
       Wr16(PL(2),0);R:=0;
       Dev:=PW(10);
       If (Dev<0) Or (Dev>1) Or Not Flp[Dev].On Then R:=E_NOTRDY;
      End;
  20: ScreenDump;
  21: Begin
       Case PW(2) Of
        0: ConCurOn:=False;
        1: ConCurOn:=True;
        2,3: Begin End;
        4: CurBlinkRate:=PW(4);
        5: R:=CurBlinkRate;
       End;
      End;
  22: Begin
       TimeSetPacked:=PL(2);TimeSetOn:=True;TimeBase:=MsNow Div 1000;
      End;
  23: Begin
       If TimeSetOn Then R:=PackedAdd(TimeSetPacked,(MsNow Div 1000)-TimeBase)
       Else R:=HostPacked;
       { le mot haut contient la date, le mot bas l'heure }
      End;
  24: KeyTables;
  25: Begin
       { Ikbdws : commandes du clavier intelligent (ignorees) }
      End;
  26: Begin MfpEnable:=MfpEnable And Not (LongInt(1) Shl (PW(2) And 31));End;
  27: Begin MfpEnable:=MfpEnable Or (LongInt(1) Shl (PW(2) And 31));End;
  28: Begin
       I:=PW(4);
       If (I And $80)<>0 Then Begin GiRegs[I And 15]:=PW(2) And $FF;R:=GiRegs[I And 15];End
       Else R:=GiRegs[I And 15];
      End;
  29: Begin GiRegs[14]:=GiRegs[14] And (PW(2) And $FF);End;
  30: Begin GiRegs[14]:=GiRegs[14] Or (PW(2) And $FF);End;
  31: Begin
       I:=PW(2) And 3;
       XbVec[16+I]:=PL(8);
       Wr32($134+I*4,PL(8));
      End;
  32: Begin R:=DosoundPtr;DosoundPtr:=PL(2);End;
  33: Begin R:=PrtConfig;If SExt(PW(2),2)>=0 Then PrtConfig:=PW(2);End;
  34: R:=KBDVECS;
  35: Begin
       R:=KbRate;
       If SExt(PW(2),2)>=0 Then KbRate:=(LongInt(PW(2)) Shl 8) Or PW(4);
      End;
  36: R:=0;
  37: Begin PollKeys;Delay(16);End;
  38: Begin
       A:=PL(2);
       PushL(PC);
       PushL(STUB_USER);
       SRv:=SRv Or SR_S;
       PC:=A;
       Exit;
      End;
  39: R:=0;
  64: R:=0;
 Else R:=0;
 End;
 Rg[0]:=R;
End;

{ ====================================================================== }
{                  BUREAU GEM : FENETRES ET DIALOGUES                    }
{ ====================================================================== }

Const
 {$IFDEF FPC}
 {$IFDEF UNIX}
 DirSep = '/';
 {$ELSE}
 DirSep = '\';
 {$ENDIF}
 {$ELSE}
 DirSep = '\';
 {$ENDIF}

 CELL_W = 8;
 CELL_H = 16;
 MAXDI  = 30;

 { Types d'elements de dialogue }
 DK_LABEL  = 1;
 DK_EDIT   = 2;
 DK_RADIO  = 3;
 DK_BUTTON = 4;
 DK_BOXED  = 5;
 DK_ICON   = 6;
 DK_HLINE  = 7;

Type
 TDItem = Record
  Kind : Byte;
  X,Y,W : Integer;       { position en cellules }
  Txt  : String[70];
  Val  : String[60];
  Sel  : Integer;
  Id   : Integer;
  Def  : Boolean;
  Max  : Integer;
 End;

Var
 DI      : Array[1..MAXDI] Of TDItem;
 DN      : Integer;
 DCols,DRows : Integer;
 DFocus  : Integer;
 DTitle  : String;
 LastClickT : LongInt;
 LastClickX,LastClickY : LongInt;
 TickCount  : LongInt;

Procedure DrawAll; Forward;

Procedure DlgReset(Cols,Rows: Integer);
Begin
 DN:=0;DCols:=Cols;DRows:=Rows;DFocus:=0;DTitle:='';
End;

Function DlgAdd(K: Byte; X,Y,W: Integer; Const Txt: String): Integer;
Begin
 If DN<MAXDI Then Begin
  Inc(DN);
  FillChar(DI[DN],SizeOf(TDItem),0);
  DI[DN].Kind:=K;DI[DN].X:=X;DI[DN].Y:=Y;DI[DN].W:=W;DI[DN].Txt:=Copy(Txt,1,70);
  DI[DN].Sel:=1;DI[DN].Max:=W;
  DlgAdd:=DN;
 End Else DlgAdd:=DN;
End;

Function DlgLabel(X,Y: Integer; Const Txt: String): Integer;
Begin
 DlgLabel:=DlgAdd(DK_LABEL,X,Y,Length(Txt),Txt);
End;

Function DlgEdit(X,Y,W: Integer; Const Val: String): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_EDIT,X,Y,W,'');
 DI[N].Val:=Val;
 DlgEdit:=N;
End;

Function DlgRadio(X,Y: Integer; Const Opts: String; Sel: Integer): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_RADIO,X,Y,0,Opts);
 DI[N].Sel:=Sel;
 DlgRadio:=N;
End;

Function DlgButton(X,Y,W: Integer; Const Txt: String; Id: Integer; Def: Boolean): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_BUTTON,X,Y,W,Txt);
 DI[N].Id:=Id;DI[N].Def:=Def;
 DlgButton:=N;
End;

{ Boutons de style GEM }
Procedure GButton(X1,Y1,X2,Y2: Integer; Const S: String; Def,Sel: Boolean);
Var TX: Integer;
Begin
 If Sel Then Begin
  Box(X1,Y1,X2,Y2,INK);
 End Else Begin
  Box(X1,Y1,X2,Y2,PAPER);
  Frame(X1,Y1,X2,Y2);
  If Def Then Begin
   Frame(X1-1,Y1-1,X2+1,Y2+1);
   Frame(X1-2,Y1-2,X2+2,Y2+2);
  End;
 End;
 TX:=(X1+X2+1-TextW(S)) Div 2;
 If Sel Then WText(TX,(Y1+Y2-6) Div 2,S) Else PText(TX,(Y1+Y2-6) Div 2,S);
End;

Procedure GemFrame(X1,Y1,X2,Y2: Integer);
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 Frame(X1+1,Y1+1,X2-1,Y2-1);
 Frame(X1+2,Y1+2,X2-2,Y2-2);
End;

Function DlgX0: Integer;
Begin
 DlgX0:=(SCR_W-(DCols*CELL_W+16)) Div 2;
End;

Function DlgY0: Integer;
Begin
 DlgY0:=(SCR_H-(DRows*CELL_H+16)) Div 2;
End;

Function RadioOptStr(Const Opts: String; N: Integer): String;
Var I,K: Integer; R: String;
Begin
 R:='';K:=1;
 For I:=1 To Length(Opts) Do
  If Opts[I]='|' Then Inc(K) Else If K=N Then R:=R+Opts[I];
 RadioOptStr:=R;
End;

Function RadioCount(Const Opts: String): Integer;
Var I,K: Integer;
Begin
 K:=1;
 For I:=1 To Length(Opts) Do If Opts[I]='|' Then Inc(K);
 RadioCount:=K;
End;

Procedure DlgDraw;
Var X0,Y0,I,K,N,PX,PY,W,OX: Integer; S: String;
Begin
 HideMouse;
 X0:=DlgX0;Y0:=DlgY0;
 GemFrame(X0,Y0,X0+DCols*CELL_W+15,Y0+DRows*CELL_H+15);
 For I:=1 To DN Do Begin
  PX:=X0+8+DI[I].X*CELL_W;PY:=Y0+8+DI[I].Y*CELL_H;
  Case DI[I].Kind Of
   DK_LABEL: PText(PX,PY+4,DI[I].Txt);
   DK_BOXED: Begin
              Frame(PX-4,PY-2,PX+DI[I].W*CELL_W+3,PY+CELL_H+1);
              PText(PX,PY+4,DI[I].Txt);
             End;
   DK_HLINE: Begin SetColor(INK);Line(PX,PY+8,PX+DI[I].W*CELL_W,PY+8);End;
   DK_ICON: Begin
             Frame(PX,PY,PX+31,PY+31);
             SetColor(INK);
             Case DI[I].Sel Of
              1: Begin Line(PX+16,PY+4,PX+4,PY+27);Line(PX+4,PY+27,PX+28,PY+27);
                       Line(PX+28,PY+27,PX+16,PY+4);PText(PX+12,PY+14,'!');End;
              2: Begin Circle(PX+16,PY+16,12);PText(PX+12,PY+12,'?');End;
              3: Begin Circle(PX+16,PY+16,12);PText(PX+12,PY+12,'i');End;
             End;
            End;
   DK_EDIT: Begin
             S:=DI[I].Val;
             If Length(S)>DI[I].Max Then S:=Copy(S,Length(S)-DI[I].Max+1,DI[I].Max);
             PText(PX,PY+4,S);
             If I=DFocus Then PText(PX+Length(S)*8,PY+4,'_')
             Else Begin
              SetColor(INK);Line(PX+Length(S)*8,PY+14,PX+DI[I].W*CELL_W-1,PY+14);
             End;
            End;
   DK_RADIO: Begin
              N:=RadioCount(DI[I].Txt);OX:=PX;
              For K:=1 To N Do Begin
               S:=RadioOptStr(DI[I].Txt,K);
               W:=Length(S)*8+16;
               If K=DI[I].Sel Then Begin
                Box(OX,PY,OX+W,PY+CELL_H+1,INK);
                WText(OX+8,PY+5,S);
               End Else Begin
                Box(OX,PY,OX+W,PY+CELL_H+1,PAPER);
                Frame(OX,PY,OX+W,PY+CELL_H+1);
                PText(OX+8,PY+5,S);
               End;
               OX:=OX+W;
              End;
             End;
   DK_BUTTON: GButton(PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H+2,DI[I].Txt,DI[I].Def,False);
  End;
 End;
 ShowMouse;
End;

Function DlgHit(MX1,MY1: LongInt; Var Sub: Integer): Integer;
Var X0,Y0,I,K,N,PX,PY,W,OX: Integer; S: String;
Begin
 DlgHit:=0;Sub:=0;
 X0:=DlgX0;Y0:=DlgY0;
 For I:=1 To DN Do Begin
  PX:=X0+8+DI[I].X*CELL_W;PY:=Y0+8+DI[I].Y*CELL_H;
  Case DI[I].Kind Of
   DK_EDIT: If InBox(MX1,MY1,PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H) Then DlgHit:=I;
   DK_BUTTON: If InBox(MX1,MY1,PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H+2) Then DlgHit:=I;
   DK_RADIO: Begin
              N:=RadioCount(DI[I].Txt);OX:=PX;
              For K:=1 To N Do Begin
               S:=RadioOptStr(DI[I].Txt,K);
               W:=Length(S)*8+16;
               If InBox(MX1,MY1,OX,PY,OX+W,PY+CELL_H+1) Then Begin DlgHit:=I;Sub:=K;End;
               OX:=OX+W;
              End;
             End;
  End;
 End;
End;

{ Boucle d'un dialogue : retourne l'Id du bouton choisi (0 si Echap) }
Function DlgRun: Integer;
Var E: TEvent; Done: Boolean; Res,I,Sub,F: Integer; DefId,EscId: Integer;
    Ch: Char; S: String;
Begin
 DefId:=0;EscId:=0;
 For I:=1 To DN Do
  If DI[I].Kind=DK_BUTTON Then Begin
   If DI[I].Def Then DefId:=DI[I].Id;
   If DI[I].Id=0 Then EscId:=0;
  End;
 DFocus:=0;
 For I:=1 To DN Do If (DI[I].Kind=DK_EDIT) And (DFocus=0) Then DFocus:=I;
 DlgDraw;
 Done:=False;Res:=0;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin Res:=DefId;Done:=True;End;
    K_ESC: Begin Res:=0;Done:=True;End;
    K_TAB,K_DOWN: Begin
        If DFocus>0 Then Begin
         F:=DFocus;
         Repeat
          Inc(F);If F>DN Then F:=1;
         Until (DI[F].Kind=DK_EDIT) Or (F=DFocus);
         DFocus:=F;DlgDraw;
        End;
       End;
    K_STAB,K_UP: Begin
        If DFocus>0 Then Begin
         F:=DFocus;
         Repeat
          Dec(F);If F<1 Then F:=DN;
         Until (DI[F].Kind=DK_EDIT) Or (F=DFocus);
         DFocus:=F;DlgDraw;
        End;
       End;
    K_BKSP: If (DFocus>0) And (Length(DI[DFocus].Val)>0) Then Begin
             Dec(DI[DFocus].Val[0]);DlgDraw;
            End;
    K_DEL: If DFocus>0 Then Begin DI[DFocus].Val:='';DlgDraw;End;
    32..255: If DFocus>0 Then Begin
              If Length(DI[DFocus].Val)<DI[DFocus].Max Then Begin
               Ch:=Chr(E.Key);
               DI[DFocus].Val:=DI[DFocus].Val+Ch;DlgDraw;
              End;
             End;
   End;
  End Else If E.Kind=2 Then Begin
   I:=DlgHit(E.X,E.Y,Sub);
   If I>0 Then Begin
    Case DI[I].Kind Of
     DK_EDIT: Begin DFocus:=I;DlgDraw;End;
     DK_RADIO: Begin DI[I].Sel:=Sub;DlgDraw;End;
     DK_BUTTON: Begin Res:=DI[I].Id;Done:=True;End;
    End;
   End;
  End;
 Until Done;
 NeedDraw:=True;
 DlgRun:=Res;
End;

{ ---------------------------------------------------------------------- }
{ Alertes GEM                                                              }
{ ---------------------------------------------------------------------- }

{ Icone : 0 aucune, 1 note (!), 2 question, 3 stop ; Btns = 'Annuler|OK' }
Function AlertBox(Icon: Integer; Const Txt,Btns: String; Def: Integer): Integer;
Var Lines: Array[1..8] Of String; NL,I,W,NB,BW,X,TxtX: Integer; S,B: String; P,K: Integer;
    BT: Array[1..4] Of String[20]; IdMap: Array[1..4] Of Integer; R: Integer;
Begin
 NL:=0;S:=Txt;
 While (S<>'') And (NL<8) Do Begin
  P:=Pos('|',S);Inc(NL);
  If P=0 Then Begin Lines[NL]:=S;S:='';End Else Begin Lines[NL]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 NB:=0;S:=Btns;
 While (S<>'') And (NB<4) Do Begin
  P:=Pos('|',S);Inc(NB);
  If P=0 Then Begin BT[NB]:=S;S:='';End Else Begin BT[NB]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 W:=0;
 For I:=1 To NL Do If Length(Lines[I])>W Then W:=Length(Lines[I]);
 BW:=0;
 For I:=1 To NB Do If Length(BT[I])+2>BW Then BW:=Length(BT[I])+2;
 If NB*(BW+2)>W Then W:=NB*(BW+2);
 If Icon>0 Then TxtX:=6 Else TxtX:=1;
 W:=W+TxtX+2;
 If W<20 Then W:=20;
 DlgReset(W,NL+3+Ord(NL<2));
 If Icon>0 Then Begin I:=DlgAdd(DK_ICON,1,0,4,'');DI[I].Sel:=Icon;End;
 For I:=1 To NL Do DlgLabel(TxtX,I-1+Ord(NL<2),Lines[I]);
 X:=(W-NB*(BW+2)) Div 2;
 For I:=1 To NB Do Begin
  DlgButton(X+(I-1)*(BW+2),NL+1+Ord(NL<2),BW,BT[I],I,I=Def);
 End;
 R:=DlgRun;
 If R=0 Then Begin
  For I:=1 To NB Do If (BT[I]=T3('Cancel','Annuler','Abbruch')) Or (BT[I]='Cancel') Then R:=I;
  If R=0 Then R:=NB;
 End;
 AlertBox:=R;
End;

Procedure Alert1(Icon: Integer; Const Txt: String);
Var R: Integer;
Begin
 R:=AlertBox(Icon,Txt,'OK',1);
End;

Function InputDlg(Const Title,Prompt: String; Var S: String; MaxLen: Integer): Boolean;
Var W,R: Integer;
Begin
 W:=Length(Prompt)+MaxLen+4;
 If W<Length(Title)+6 Then W:=Length(Title)+6;
 DlgReset(W,4);
 DlgLabel(1,0,Title);
 DlgLabel(1,1,Prompt);
 DlgEdit(2+Length(Prompt),1,MaxLen,S);
 DlgButton(W-24,2,10,'OK',1,True);
 DlgButton(W-12,2,10,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R=1 Then Begin S:=DI[3].Val;InputDlg:=True;End Else InputDlg:=False;
End;

{ ---------------------------------------------------------------------- }
{ Selecteur de fichiers (style GEM)                                       }
{ ---------------------------------------------------------------------- }

Const
 FS_MAX = 400;
 FS_ROWS = 10;

Var
 FSList : Array[1..FS_MAX] Of String[40];
 FSN    : Integer;

Function NormDir(Const D: String): String;
Var S: String; I: Integer;
Begin
 S:=D;
 For I:=1 To Length(S) Do If (S[I]='\') Or (S[I]='/') Then S[I]:=DirSep;
 If (S<>'') And (S[Length(S)]<>DirSep) And (S[Length(S)]<>':') Then S:=S+DirSep;
 NormDir:=S;
End;

Function WildMatch(Const Pat,Name: String): Boolean;
Var P,N: String;
 Function M(PI,NI: Integer): Boolean;
 Begin
  While PI<=Length(P) Do Begin
   If P[PI]='*' Then Begin
    While PI<=Length(P) Do If P[PI]='*' Then Inc(PI) Else Break;
    If PI>Length(P) Then Begin M:=True;Exit;End;
    While NI<=Length(N)+1 Do Begin
     If M(PI,NI) Then Begin M:=True;Exit;End;
     Inc(NI);
    End;
    M:=False;Exit;
   End;
   If NI>Length(N) Then Begin M:=False;Exit;End;
   If (P[PI]<>'?') And (P[PI]<>N[NI]) Then Begin M:=False;Exit;End;
   Inc(PI);Inc(NI);
  End;
  M:=NI>Length(N);
 End;
Begin
 P:=Upper(Pat);N:=Upper(Name);
 If Pos('.',P)=0 Then P:=P+'.*';
 WildMatch:=M(1,1);
End;

Procedure FSScan(Const Dir,Mask: String);
Var SR: SearchRec; I,J,NDirs: Integer; T: String[40];
Begin
 FSN:=0;
 If Length(Dir)>1 Then Begin
  Inc(FSN);FSList[FSN]:=DirSep+'..';
 End;
 FindFirst(Dir+'*',Directory Or $17,SR);
 While (DosError=0) And (FSN<FS_MAX) Do Begin
  If ((SR.Attr And Directory)<>0) And (SR.Name<>'.') And (SR.Name<>'..') Then Begin
   Inc(FSN);FSList[FSN]:=DirSep+Copy(SR.Name,1,38);
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 NDirs:=FSN;
 FindFirst(Dir+'*',AnyFile,SR);
 While (DosError=0) And (FSN<FS_MAX) Do Begin
  If ((SR.Attr And Directory)=0) And WildMatch(Mask,SR.Name) Then Begin
   Inc(FSN);FSList[FSN]:=Copy(SR.Name,1,38);
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 { tri : repertoires puis fichiers }
 For I:=2 To NDirs Do Begin
  T:=FSList[I];J:=I-1;
  While (J>=1) And (Upper(FSList[J])>Upper(T)) And (FSList[J]<>DirSep+'..') Do Begin
   FSList[J+1]:=FSList[J];Dec(J);
  End;
  FSList[J+1]:=T;
 End;
 For I:=NDirs+2 To FSN Do Begin
  T:=FSList[I];J:=I-1;
  While (J>NDirs) And (Upper(FSList[J])>Upper(T)) Do Begin
   FSList[J+1]:=FSList[J];Dec(J);
  End;
  FSList[J+1]:=T;
 End;
End;

Function GetCurDir: String;
Var S: String;
Begin
 GetDir(0,S);
 GetCurDir:=NormDir(S);
End;

{ Retourne True et le chemin complet dans Path }
Function FileSelect(Const Title,Mask: String; Var Path: String): Boolean;
Var Dir,Sel,Msk: String; Top,Cur,I,X0,Y0,LX,LY,LW,Row,Foc: Integer; E: TEvent;
    Done,Ok,Redraw: Boolean; P: Integer; K: LongInt; FullS: String; DblT: LongInt;
    LastIdx: Integer; EditDir: String;
 Procedure Rescan;
 Begin
  FSScan(Dir,Msk);Top:=1;Cur:=0;
 End;
 Procedure DrawFS;
 Var R,Idx,Y: Integer; S: String;
 Begin
  HideMouse;
  GemFrame(X0,Y0,X0+16+62*8-1,Y0+16+19*16-1);
  PText(X0+16,Y0+10,Title);
  PText(X0+16,Y0+30,T3('Directory: ','Repertoire : ','Verzeichnis: ')+Copy(Dir+Msk,1,48));
  { liste }
  LX:=X0+16;LY:=Y0+54;LW:=50*8;
  Box(LX,LY,LX+LW,LY+FS_ROWS*16+2,PAPER);
  Frame(LX,LY,LX+LW,LY+FS_ROWS*16+2);
  For R:=0 To FS_ROWS-1 Do Begin
   Idx:=Top+R;
   If Idx<=FSN Then Begin
    Y:=LY+2+R*16;
    S:=FSList[Idx];
    If Idx=Cur Then Begin
     Box(LX+1,Y,LX+LW-1,Y+15,INK);
     WText(LX+8,Y+4,S);
    End Else PText(LX+8,Y+4,S);
   End;
  End;
  ArrowBox(LX+LW+8,LY,LX+LW+8+16,LY+16,1);
  ArrowBox(LX+LW+8,LY+FS_ROWS*16-14,LX+LW+8+16,LY+FS_ROWS*16+2,2);
  Box(LX+LW+8,LY+17,LX+LW+8+16,LY+FS_ROWS*16-15,PAPER);
  PatBar(LX+LW+8,LY+17,LX+LW+8+16,LY+FS_ROWS*16-15,PatGrey);
  Frame(LX+LW+8,LY+17,LX+LW+8+16,LY+FS_ROWS*16-15);
  PText(LX,LY+FS_ROWS*16+14,T3('Selection: ','Selection : ','Auswahl: '));
  S:=Sel;
  PText(LX+88,LY+FS_ROWS*16+14,S);
  If Foc=1 Then PText(LX+88+Length(S)*8,LY+FS_ROWS*16+14,'_')
  Else Begin SetColor(INK);Line(LX+88+Length(S)*8,LY+FS_ROWS*16+23,LX+88+24*8,LY+FS_ROWS*16+23);End;
  GButton(LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56,'OK',True,False);
  GButton(LX+16+100,LY+FS_ROWS*16+36,LX+16+100+80,LY+FS_ROWS*16+56,T3('Cancel','Annuler','Abbruch'),False,False);
  ShowMouse;
 End;
 Procedure Accept;
 Begin
  If Sel<>'' Then Begin
   If (Pos(DirSep,Sel)>0) Or (Pos(':',Sel)>0) Then Path:=Sel Else Path:=Dir+Sel;
   Ok:=True;Done:=True;
  End;
 End;
Begin
 FileSelect:=False;
 Msk:=Mask;
 P:=Length(Path);
 While (P>0) And (Path[P]<>'\') And (Path[P]<>'/') Do Dec(P);
 If P>0 Then Begin Dir:=NormDir(Copy(Path,1,P));Sel:=Copy(Path,P+1,80);End
 Else Begin Dir:=GetCurDir;Sel:=Path;End;
 If (Pos('*',Sel)>0) Or (Pos('?',Sel)>0) Then Begin Msk:=Sel;Sel:='';End;
 X0:=(SCR_W-(16+62*8)) Div 2;Y0:=(SCR_H-(16+19*16)) Div 2;
 Rescan;
 Foc:=1;Done:=False;Ok:=False;LastIdx:=0;DblT:=0;
 DrawFS;
 Repeat
  PollEvent(E);
  Redraw:=False;
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin
              If (Cur>0) And (Sel='') Then Sel:=FSList[Cur];
              If (Sel<>'') And (Sel[1]=DirSep) Then Begin
               If Sel=DirSep+'..' Then Begin
                P:=Length(Dir)-1;
                While (P>0) And (Dir[P]<>DirSep) And (Dir[P]<>':') Do Dec(P);
                Dir:=Copy(Dir,1,P);
               End Else Dir:=Dir+Copy(Sel,2,80)+DirSep;
               Sel:='';Rescan;Redraw:=True;
              End Else Accept;
             End;
    K_ESC: Done:=True;
    K_UP: If Cur>1 Then Begin Dec(Cur);Sel:=FSList[Cur];Redraw:=True;End
          Else If Cur=0 Then If FSN>0 Then Begin Cur:=1;Sel:=FSList[1];Redraw:=True;End;
    K_DOWN: If Cur<FSN Then Begin Inc(Cur);Sel:=FSList[Cur];Redraw:=True;End;
    K_PGUP: Begin Cur:=Max2(1,Cur-FS_ROWS);If FSN>0 Then Sel:=FSList[Cur];Redraw:=True;End;
    K_PGDN: Begin Cur:=Min2(FSN,Cur+FS_ROWS);If FSN>0 Then Sel:=FSList[Cur];Redraw:=True;End;
    K_BKSP: If Length(Sel)>0 Then Begin Dec(Sel[0]);Cur:=0;Redraw:=True;End;
    32..255: If E.Key<>K_DEL Then Begin
              If Length(Sel)<40 Then Begin Sel:=Sel+Chr(E.Key);Cur:=0;Redraw:=True;End;
             End;
   End;
   If (Cur>0) And (Cur<Top) Then Top:=Cur;
   If (Cur>=Top+FS_ROWS) Then Top:=Cur-FS_ROWS+1;
  End Else If E.Kind=2 Then Begin
   LX:=X0+16;LY:=Y0+54;LW:=50*8;
   If InBox(E.X,E.Y,LX,LY,LX+LW,LY+FS_ROWS*16+2) Then Begin
    Row:=(E.Y-LY-2) Div 16;
    I:=Top+Row;
    If (I>=1) And (I<=FSN) Then Begin
     K:=TickCount;
     If (I=LastIdx) And (K-DblT<40) Then Begin
      Sel:=FSList[I];
      If Sel[1]=DirSep Then Begin
       If Sel=DirSep+'..' Then Begin
        P:=Length(Dir)-1;
        While (P>0) And (Dir[P]<>DirSep) And (Dir[P]<>':') Do Dec(P);
        Dir:=Copy(Dir,1,P);
       End Else Dir:=Dir+Copy(Sel,2,80)+DirSep;
       Sel:='';Rescan;
      End Else Accept;
     End Else Begin Cur:=I;Sel:=FSList[I];End;
     LastIdx:=I;DblT:=K;
     Redraw:=True;
    End;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY,LX+LW+24,LY+16) Then Begin
    If Top>1 Then Dec(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY+FS_ROWS*16-14,LX+LW+24,LY+FS_ROWS*16+2) Then Begin
    If Top+FS_ROWS<=FSN Then Inc(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY+17,LX+LW+24,LY+FS_ROWS*16-15) Then Begin
    If E.Y<LY+FS_ROWS*8 Then Top:=Max2(1,Top-FS_ROWS) Else Top:=Max2(1,Min2(FSN-FS_ROWS+1,Top+FS_ROWS));
    Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56) Then Accept
   Else If InBox(E.X,E.Y,LX+16+100,LY+FS_ROWS*16+36,LX+16+180,LY+FS_ROWS*16+56) Then Done:=True;
  End;
  If Redraw Then DrawFS;
 Until Done;
 FileSelect:=Ok;
 NeedDraw:=True;
End;

{ ---------------------------------------------------------------------- }
{ Menus deroulants                                                         }
{ ---------------------------------------------------------------------- }

Const
 NMENU = 5;
 MTitle : Array[1..NMENU] Of String[40] =
  ('Desk~Bureau~Desk','File~Fichier~Datei','Search~Recherche~Suchen',
   'Options~Options~Optionen','Program~Programme~Programm');

Var
 MenuOpen,MenuHi : Integer;
 OptRunGem       : Boolean;

Function MCount(M: Integer): Integer;
Begin
 Case M Of
  1: MCount:=4;
  2: MCount:=8;
  3: MCount:=13;
  4: MCount:=6;
  5: MCount:=8;
 Else MCount:=0;
 End;
End;

{ Libelle : "texte|raccourci" ; '-' = separateur }
Function MLabel(M,I: Integer): String;
Begin
 MLabel:='';
 Case M Of
  1: Case I Of
      1: MLabel:=T3('About ','A propos de ','Ueber ')+'Devpac...';
      2: MLabel:='-';
      3: MLabel:=T3('Help...|F1','Aide...|F1','Hilfe...|F1');
      4: MLabel:=T3('Memory...','Memoire...','Speicher...');
     End;
  2: Case I Of
      1: MLabel:=T3('New|^N','Nouveau|^N','Neu|^N');
      2: MLabel:=T3('Load...|^L','Charger...|^L','Laden...|^L');
      3: MLabel:=T3('Save|^S','Sauver|^S','Sichern|^S');
      4: MLabel:=T3('Save as...','Sauver sous...','Sichern als...');
      5: MLabel:=T3('Append...','Ajouter...','Anhaengen...');
      6: MLabel:=T3('Save block...','Sauver le bloc...','Block sichern...');
      7: MLabel:='-';
      8: MLabel:=T3('Quit|^Q','Quitter|^Q','Ende|^Q');
     End;
  3: Case I Of
      1: MLabel:=T3('Find...|^F','Chercher...|^F','Suchen...|^F');
      2: MLabel:=T3('Find next|^G','Suivant|^G','Weitersuchen|^G');
      3: MLabel:=T3('Replace...|^R','Remplacer...|^R','Ersetzen...|^R');
      4: MLabel:=T3('Goto line...|^W','Aller a la ligne...|^W','Gehe zu Zeile...|^W');
      5: MLabel:='-';
      6: MLabel:=T3('Set block start|F5','Debut de bloc|F5','Blockanfang|F5');
      7: MLabel:=T3('Set block end|F6','Fin de bloc|F6','Blockende|F6');
      8: MLabel:=T3('Copy block|^C','Copier le bloc|^C','Block kopieren|^C');
      9: MLabel:=T3('Cut block|^U','Couper le bloc|^U','Block ausschn.|^U');
      10: MLabel:=T3('Paste block|^V','Coller le bloc|^V','Block einfuegen|^V');
      11: MLabel:=T3('Delete block|^B','Effacer le bloc|^B','Block loeschen|^B');
      12: MLabel:='-';
      13: MLabel:=T3('Select all','Tout selectionner','Alles auswaehlen');
     End;
  4: Case I Of
      1: MLabel:=T3('Editor preferences...','Preferences editeur...','Editor-Einstellungen...');
      2: MLabel:=T3('Assembler options...','Options assembleur...','Assembler-Optionen...');
      3: MLabel:=T3('Debugger options...','Options debogueur...','Debugger-Optionen...');
      4: MLabel:='-';
      5: MLabel:=T3('Save preferences','Sauver preferences','Einstellungen sichern');
      6: MLabel:=T3('Load preferences','Charger preferences','Einstellungen laden');
     End;
  5: Case I Of
      1: MLabel:=T3('Assemble|^A','Assembler|^A','Assemblieren|^A');
      2: MLabel:=T3('Run|^X','Executer|^X','Starten|^X');
      3: MLabel:=T3('Debug|^D','Deboguer|^D','Debuggen|^D');
      4: MLabel:=MonName+'|AltM';
      5: MLabel:=T3('Run with GEM|^K','Executer avec GEM|^K','Mit GEM starten|^K');
      6: MLabel:='-';
      7: MLabel:=T3('Jump to error|^J','Aller a l''erreur|^J','Zum Fehler|^J');
      8: MLabel:=T3('Run Other...|^O','Executer autre...|^O','Anderes starten...|^O');
     End;
 End;
 If AmigaMode And (M=5) And (I=5) Then MLabel:=T3('Run as CLI|^K','Executer en CLI|^K','Als CLI starten|^K');
End;

Function MChecked(M,I: Integer): Boolean;
Begin
 MChecked:=(M=5) And (I=5) And OptRunGem;
End;

Function MIsSep(M,I: Integer): Boolean;
Begin
 MIsSep:=MLabel(M,I)='-';
End;

Function MT(I: Integer): String;
Begin
 MT:=Part3(MTitle[I],Lang);
End;

Function MenuX(M: Integer): Integer;
Var I,X: Integer;
Begin
 X:=16;
 For I:=1 To M-1 Do X:=X+Length(MT(I))*8+24;
 MenuX:=X;
End;

Function ItemH(M,I: Integer): Integer;
Begin
 If MIsSep(M,I) Then ItemH:=8 Else ItemH:=16;
End;

Procedure DropRect(M: Integer; Var X1,Y1,X2,Y2: Integer);
Var I,W,L,P: Integer; S: String;
Begin
 W:=0;Y2:=MENU_H+2;
 For I:=1 To MCount(M) Do Begin
  S:=MLabel(M,I);
  P:=Pos('|',S);
  If P>0 Then L:=(P-1)*8+24+(Length(S)-P)*8 Else L:=Length(S)*8;
  If L>W Then W:=L;
  Y2:=Y2+ItemH(M,I);
 End;
 X1:=MenuX(M)-8;
 X2:=X1+W+40;
 If X2>SCR_W-4 Then Begin X1:=X1-(X2-(SCR_W-4));X2:=SCR_W-4;End;
 Y1:=MENU_H;
 Y2:=Y2+2;
End;

Function ItemY(M,I: Integer): Integer;
Var K,Y: Integer;
Begin
 Y:=MENU_H+2;
 For K:=1 To I-1 Do Y:=Y+ItemH(M,K);
 ItemY:=Y;
End;

Function DropHit(M: Integer; X,Y: LongInt): Integer;
Var X1,Y1,X2,Y2,I: Integer;
Begin
 DropHit:=0;
 DropRect(M,X1,Y1,X2,Y2);
 If Not InBox(X,Y,X1,Y1,X2,Y2) Then Exit;
 For I:=1 To MCount(M) Do
  If (Y>=ItemY(M,I)) And (Y<ItemY(M,I)+ItemH(M,I)) Then DropHit:=I;
End;

Function TitleHit(X,Y: LongInt): Integer;
Var M: Integer;
Begin
 TitleHit:=0;
 If (Y<0) Or (Y>=MENU_H) Then Exit;
 For M:=1 To NMENU Do
  If (X>=MenuX(M)-8) And (X<=MenuX(M)+Length(MT(M))*8+8) Then TitleHit:=M;
End;

Procedure DrawMenuBar;
Var M: Integer;
Begin
 Box(0,0,SCR_W-1,MENU_H-1,PAPER);
 SetColor(INK);
 SetLineStyle(SolidLn,0,1);
 Line(0,MENU_H-1,SCR_W-1,MENU_H-1);
 For M:=1 To NMENU Do Begin
  If M=MenuOpen Then Begin
   Box(MenuX(M)-8,0,MenuX(M)+Length(MT(M))*8+8,MENU_H-2,INK);
   WText(MenuX(M),5,MT(M));
  End Else PText(MenuX(M),5,MT(M));
 End;
End;

Function MEnabled(M,I: Integer): Boolean; Forward;

Procedure DrawDropDown;
Var X1,Y1,X2,Y2,I,Y,P: Integer; S,Sc,Lb: String; Hi: Boolean;
Begin
 If MenuOpen=0 Then Exit;
 DropRect(MenuOpen,X1,Y1,X2,Y2);
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 For I:=1 To MCount(MenuOpen) Do Begin
  S:=MLabel(MenuOpen,I);
  Y:=ItemY(MenuOpen,I);
  If S='-' Then Begin
   SetLineStyle(UserBitLn,$AAAA,1);
   SetColor(INK);
   Line(X1+2,Y+3,X2-2,Y+3);
   SetLineStyle(SolidLn,0,1);
  End Else Begin
   P:=Pos('|',S);
   If P>0 Then Begin Lb:=Copy(S,1,P-1);Sc:=Copy(S,P+1,20);End Else Begin
     Lb:=S;Sc:='';End;
   Hi:=(I=MenuHi) And MEnabled(MenuOpen,I);
   If Hi Then Box(X1+1,Y,X2-1,Y+15,INK);
   If MChecked(MenuOpen,I) Then Begin
    If Hi Then WText(X1+6,Y+4,#251) Else PText(X1+6,Y+4,#251);
   End;
   If Not MEnabled(MenuOpen,I) Then Begin
    GreyText(X1+24,Y+4,Lb);
    If Sc<>'' Then GreyText(X2-8-Length(Sc)*8,Y+4,Sc);
   End Else If Hi Then Begin
    WText(X1+24,Y+4,Lb);
    If Sc<>'' Then WText(X2-8-Length(Sc)*8,Y+4,Sc);
   End Else Begin
    PText(X1+24,Y+4,Lb);
    If Sc<>'' Then PText(X2-8-Length(Sc)*8,Y+4,Sc);
   End;
  End;
 End;
End;

Function NextItem(M,From,Dir: Integer): Integer;
Var I,N: Integer;
Begin
 N:=MCount(M);I:=From;
 Repeat
  I:=I+Dir;
  If I<1 Then I:=N;
  If I>N Then I:=1;
  If (Not MIsSep(M,I)) And MEnabled(M,I) Then Begin
    NextItem:=I;Exit;End;
 Until I=From;
 NextItem:=From;
End;

Procedure DoMenu(M,I: Integer); Forward;

Procedure RunMenu(StartM: Integer; ByMouse: Boolean);
Var M,Hi,H,T: Integer; E: TEvent; Done,Pick,Redraw: Boolean;
Begin
 M:=StartM;Hi:=0;
 If Not ByMouse Then Hi:=NextItem(M,0,1);
 MenuOpen:=M;MenuHi:=Hi;
 DrawAll;
 Done:=False;Pick:=False;
 Repeat
  PollEvent(E);
  Redraw:=False;
  Case E.Kind Of
   4,2: Begin
         T:=TitleHit(E.X,E.Y);
         If (T>0) And (T<>M) Then Begin M:=T;Hi:=0;Redraw:=True;End
         Else Begin
          H:=DropHit(M,E.X,E.Y);
          If (H<>0) And (MIsSep(M,H) Or Not MEnabled(M,H)) Then H:=0;
          If H<>Hi Then Begin Hi:=H;Redraw:=True;End;
         End;
         If E.Kind=2 Then Begin
          If DropHit(M,E.X,E.Y)=0 Then Begin
           If TitleHit(E.X,E.Y)=0 Then Done:=True;
          End Else If Hi<>0 Then Begin Pick:=True;Done:=True;End;
         End;
        End;
   3: Begin
       H:=DropHit(M,E.X,E.Y);
       If (H<>0) And (Hi=H) Then Begin Pick:=True;Done:=True;End;
      End;
   1: Case E.Key Of
       K_ESC: Done:=True;
       K_LEFT: Begin Dec(M);If M<1 Then
         M:=NMENU;Hi:=NextItem(M,0,1);Redraw:=True;End;
       K_RIGHT: Begin Inc(M);If M>NMENU Then
         M:=1;Hi:=NextItem(M,0,1);Redraw:=True;End;
       K_UP: Begin Hi:=NextItem(M,Hi,-1);Redraw:=True;End;
       K_DOWN: Begin Hi:=NextItem(M,Hi,1);Redraw:=True;End;
       K_ENTER: If Hi<>0 Then Begin Pick:=True;Done:=True;End;
      End;
  End;
  If Redraw Then Begin MenuOpen:=M;MenuHi:=Hi;DrawAll;End;
 Until Done;
 MenuOpen:=0;MenuHi:=0;
 DrawAll;
 If Pick And (Hi>0) Then DoMenu(M,Hi);
End;

{ Barre de titre GEM (hachuree) }
Procedure GemTitleBar(X1,Y1,X2,Y2: Integer; Const Title: String; HasFull: Boolean);
Var Y,TX,TW: Integer;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 SetColor(INK);
 Y:=Y1+2;
 While Y<=Y2-2 Do Begin Line(X1+19,Y,X2-19,Y);Inc(Y,2);End;
 TW:=Length(Title)*8+16;
 TX:=(X1+X2-TW) Div 2;
 If TX<X1+20 Then TX:=X1+20;
 Box(TX,Y1+1,TX+TW,Y2-1,PAPER);
 PText(TX+8,Y1+((Y2-Y1)-7) Div 2+1,Copy(Title,1,(X2-X1-60) Div 8));
 { case de fermeture }
 Box(X1+1,Y1+1,X1+17,Y2-1,PAPER);
 Frame(X1+1,Y1+1,X1+17,Y2-1);
 If HasFull Then Begin
  Box(X2-17,Y1+1,X2-1,Y2-1,PAPER);
  Frame(X2-17,Y1+1,X2-1,Y2-1);
  Frame(X2-14,Y1+4,X2-4,Y2-4);
 End;
End;

Function ReadAll(Const Name: String; Var P: Pointer; Var Len: LongInt): Boolean;
Begin
 ReadAll:=ReadFileBytes(Name,P,Len);
End;

Function BufB(P: Pointer; I: LongInt): LongInt;
Begin
 BufB:=PByteAt(P,I);
End;

Function BufL(P: Pointer; I: LongInt): LongInt;
Begin
 BufL:=(BufB(P,I) Shl 24) Or (BufB(P,I+1) Shl 16) Or (BufB(P,I+2) Shl 8) Or BufB(P,I+3);
End;

Function BufW(P: Pointer; I: LongInt): LongInt;
Begin
 BufW:=(BufB(P,I) Shl 8) Or BufB(P,I+1);
End;


{ ====================================================================== }
{                  GEM : VDI (Virtual Device Interface)                  }
{ ====================================================================== }

Const
 MAXVWK  = 16;
 SW      = 640;
 SH      = 400;
 WM_REPL = 1;  WM_TRANS = 2;  WM_XOR = 3;  WM_RTRANS = 4;

Type
 TVdi = Record
  Used     : Boolean;
  Owner    : Integer;
  WrMode   : Integer;
  LineType,LineCol,LineWidth,LineEnd0,LineEnd1 : Integer;
  LineUd   : Word;
  MarkType,MarkCol,MarkH : Integer;
  TxtFont,TxtCol,TxtRot,TxtEff,TxtHAl,TxtVAl,TxtCell : Integer;
  FillInt,FillSty,FillCol,FillPer : Integer;
  UdPat    : Array[0..15] Of Word;
  ClipOn   : Boolean;
  Cx1,Cy1,Cx2,Cy2 : Integer;
 End;
 TPoly = Array[0..255] Of Integer;     { x0,y0,x1,y1,... }

Var
 Vd      : Array[0..MAXVWK] Of TVdi;
 VP      : ^TVdi;
 VCur    : Integer;
 CX1,CY1,CX2,CY2 : Integer;          { fenetre de clipping effective }
 GMouseX,GMouseY,GMouseB : LongInt;
 BayerM  : Array[0..3,0..3] Of Byte;
 BayerCnt: Array[1..8] Of Byte;
 PX,PY   : TPoly;                    { sommets pour les polygones }
 LinePhase : Integer;
 AesTrace  : Boolean;
 VdiOwnerProc : Integer;
 { routines utilisateur vex_* }
 VexTim,VexBut,VexMot,VexCur : LongInt;
 VexTimLast  : LongInt;
 InVex       : Boolean;
 KbdPrevX,KbdPrevY,KbdPrevB : LongInt;

Procedure VdiInitTables;
Const B : Array[0..15] Of Byte = (0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);
      C : Array[1..8] Of Byte = (1,2,4,6,8,10,12,14);
Var I: Integer;
Begin
 For I:=0 To 15 Do BayerM[I Div 4,I Mod 4]:=B[I];
 For I:=1 To 8 Do BayerCnt[I]:=C[I];
End;

Procedure VdiDefaults(Var V: TVdi);
Var I: Integer;
Begin
 V.WrMode:=WM_REPL;
 V.LineType:=1;V.LineCol:=1;V.LineWidth:=1;V.LineEnd0:=0;V.LineEnd1:=0;V.LineUd:=$FFFF;
 V.MarkType:=3;V.MarkCol:=1;V.MarkH:=8;
 V.TxtFont:=1;V.TxtCol:=1;V.TxtRot:=0;V.TxtEff:=0;V.TxtHAl:=0;V.TxtVAl:=0;V.TxtCell:=16;
 V.FillInt:=0;V.FillSty:=1;V.FillCol:=1;V.FillPer:=1;
 For I:=0 To 15 Do V.UdPat[I]:=$AAAA;
 V.ClipOn:=False;V.Cx1:=0;V.Cy1:=0;V.Cx2:=SW-1;V.Cy2:=SH-1;
End;

Procedure SelVdi(H: Integer);
Begin
 If (H<0) Or (H>MAXVWK) Or Not Vd[H].Used Then H:=1;
 If Not Vd[H].Used Then H:=0;
 VCur:=H;VP:=@Vd[H];
 If VP^.ClipOn Then Begin
  CX1:=Max2(0,VP^.Cx1);CY1:=Max2(0,VP^.Cy1);CX2:=Min2(SW-1,VP^.Cx2);CY2:=Min2(SH-1,VP^.Cy2);
 End Else Begin CX1:=0;CY1:=0;CX2:=SW-1;CY2:=SH-1;End;
End;

Procedure SetClip(X1,Y1,X2,Y2: Integer);
Begin
 CX1:=Max2(0,X1);CY1:=Max2(0,Y1);CX2:=Min2(SW-1,X2);CY2:=Min2(SH-1,Y2);
End;

{ ---------------------------------------------------------------------- }
{ Pixels et segments                                                       }
{ ---------------------------------------------------------------------- }

Procedure PlotPat(X,Y: Integer; PatBit,Col: Boolean);
Begin
 If (X<CX1) Or (X>CX2) Or (Y<CY1) Or (Y>CY2) Then Exit;
 Case VP^.WrMode Of
  WM_REPL: If PatBit Then BPix(X,Y,Col) Else BPix(X,Y,False);
  WM_TRANS: If PatBit Then BPix(X,Y,Col);
  WM_XOR: If PatBit Then BPix(X,Y,Not BGet(X,Y));
  WM_RTRANS: If Not PatBit Then BPix(X,Y,Col);
 End;
End;

Procedure PlotSolid(X,Y: Integer; Col: Boolean);
Begin
 PlotPat(X,Y,True,Col);
End;

Procedure FastSpan(Y,X1,X2: Integer; Col: Boolean; Xor_: Boolean);
Var XB1,XB2,XB: Integer; M1,M2,B: Byte; A: LongInt;
Begin
 If X1<CX1 Then X1:=CX1;
 If X2>CX2 Then X2:=CX2;
 If (X1>X2) Or (Y<CY1) Or (Y>CY2) Then Exit;
 A:=DrawBase+LongInt(Y)*80;
 XB1:=X1 Shr 3;XB2:=X2 Shr 3;
 M1:=$FF Shr (X1 And 7);
 M2:=$FF Shl (7-(X2 And 7));
 If XB1=XB2 Then Begin
  M1:=M1 And M2;
  B:=Rd8(A+XB1);
  If Xor_ Then B:=B Xor M1 Else If Col Then B:=B Or M1 Else B:=B And Not M1;
  Wr8(A+XB1,B);
 End Else Begin
  B:=Rd8(A+XB1);
  If Xor_ Then B:=B Xor M1 Else If Col Then B:=B Or M1 Else B:=B And Not M1;
  Wr8(A+XB1,B);
  For XB:=XB1+1 To XB2-1 Do Begin
   If Xor_ Then Wr8(A+XB,Rd8(A+XB) Xor $FF) Else If Col Then Wr8(A+XB,$FF) Else Wr8(A+XB,0);
  End;
  B:=Rd8(A+XB2);
  If Xor_ Then B:=B Xor M2 Else If Col Then B:=B Or M2 Else B:=B And Not M2;
  Wr8(A+XB2,B);
 End;
End;

Function ColBit(C: Integer): Boolean;
Begin
 ColBit:=C<>0;
End;

{ ---------------------------------------------------------------------- }
{ Motifs de remplissage                                                    }
{ ---------------------------------------------------------------------- }

Function PatPix(Sty,X,Y: Integer): Boolean;
Var R: Boolean; A,B: Integer;
Begin
 X:=X And 15;Y:=Y And 15;
 Case Sty Of
  1..8: R:=BayerM[Y And 3,X And 3]<BayerCnt[Sty];
  9: R:=((Y And 7)=0) Or (((X+(((Y Shr 3) And 1)*8)) And 15)=0);
  10: R:=((Y And 3)=0) Or (((X+(((Y Shr 2) And 1)*4)) And 7)=0);
  11: R:=((X+Y) And 7)=0;
  12: R:=((X+Y) And 3)=0;
  13: R:=((X-Y) And 7)=0;
  14: R:=((X-Y) And 3)=0;
  15: R:=((Y And 3)=0) Or ((X And 3)=0);
  16: R:=((X And 7)=0) Or ((Y And 7)=0);
  17: R:=(((X Shr 1)+(Y Shr 1)) And 1)=0;
  18: R:=(((X Shr 2)+(Y Shr 2)) And 1)=0;
  19: Begin A:=Abs((X And 7)-4);B:=Abs((Y And 7)-4);R:=A+B<=3;End;
  20: Begin A:=(X+(((Y Shr 2) And 1)*4)) And 7;R:=(A<4) Xor ((Y And 3)>=2);End;
  21: R:=((X+Y) And 3)<2;
  22: R:=BayerM[Y And 3,X And 3]<13;
  23: R:=BayerM[Y And 3,X And 3]<14;
  24: R:=BayerM[Y And 3,X And 3]<15;
 Else R:=True;
 End;
 PatPix:=R;
End;

Function HatchPix(Sty,X,Y: Integer): Boolean;
Var R: Boolean;
Begin
 X:=X And 15;Y:=Y And 15;
 Case Sty Of
  1: R:=((X+Y) And 7)=0;
  2: R:=((X+Y) And 3)=0;
  3: R:=((X-Y) And 7)=0;
  4: R:=((X-Y) And 3)=0;
  5: R:=(Y And 7)=0;
  6: R:=(Y And 3)=0;
  7: R:=(X And 7)=0;
  8: R:=(X And 3)=0;
  9: R:=((X And 7)=0) Or ((Y And 7)=0);
  10: R:=((X And 3)=0) Or ((Y And 3)=0);
  11: R:=(((X+Y) And 7)=0) Or (((X-Y) And 7)=0);
 Else R:=(((X+Y) And 3)=0) Or (((X-Y) And 3)=0);
 End;
 HatchPix:=R;
End;

Function FillBit(X,Y: Integer): Boolean;
Begin
 Case VP^.FillInt Of
  0: FillBit:=False;
  1: FillBit:=True;
  2: FillBit:=PatPix(Clamp(VP^.FillSty,1,24),X,Y);
  3: FillBit:=HatchPix(Clamp(VP^.FillSty,1,12),X,Y);
  4: FillBit:=(VP^.UdPat[Y And 15] And ($8000 Shr (X And 15)))<>0;
 Else FillBit:=True;
 End;
End;

Procedure FillSpanPat(Y,X1,X2: Integer);
Var X: Integer; Col: Boolean;
Begin
 Col:=ColBit(VP^.FillCol);
 If (VP^.FillInt=1) And (VP^.WrMode=WM_REPL) Then Begin FastSpan(Y,X1,X2,Col,False);Exit;End;
 If (VP^.FillInt=1) And (VP^.WrMode=WM_XOR) Then Begin FastSpan(Y,X1,X2,Col,True);Exit;End;
 If (VP^.FillInt=0) And (VP^.WrMode=WM_REPL) Then Begin FastSpan(Y,X1,X2,False,False);Exit;End;
 For X:=X1 To X2 Do PlotPat(X,Y,FillBit(X,Y),Col);
End;

{ ---------------------------------------------------------------------- }
{ Lignes                                                                   }
{ ---------------------------------------------------------------------- }

Function LineStyleWord: Word;
Begin
 Case VP^.LineType Of
  1: LineStyleWord:=$FFFF;
  2: LineStyleWord:=$FFF0;
  3: LineStyleWord:=$C0C0;
  4: LineStyleWord:=$FF18;
  5: LineStyleWord:=$FF00;
  6: LineStyleWord:=$F191;
 Else LineStyleWord:=VP^.LineUd;
 End;
End;

Procedure PolyFillPts(N: Integer; Var XS,YS: TPoly; UseFillAttr: Boolean); Forward;

Procedure ThinLine(X1,Y1,X2,Y2: Integer; Mask: Word; Col: Boolean);
Var DX,DY,SX,SY,Err,E2: Integer;
Begin
 DX:=Abs(X2-X1);DY:=-Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err:=DX+DY;
 While True Do Begin
  PlotPat(X1,Y1,(Mask And ($8000 Shr (LinePhase And 15)))<>0,Col);
  Inc(LinePhase);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*Err;
  If E2>=DY Then Begin Err:=Err+DY;X1:=X1+SX;End;
  If E2<=DX Then Begin Err:=Err+DX;Y1:=Y1+SY;End;
 End;
End;

Procedure DiscFill(CXx,CYy,R: Integer; Col: Boolean);
Var Y,W: Integer;
Begin
 For Y:=-R To R Do Begin
  W:=Trunc(Sqrt(R*R-Y*Y)+0.5);
  FastSpan(CYy+Y,CXx-W,CXx+W,Col,False);
 End;
End;

Procedure VLine(X1,Y1,X2,Y2: Integer);
Var W: Integer; Col: Boolean; DXf,DYf,L,NX,NY: Real; QX,QY: TPoly; Sv,SvC,SvW: Integer;
Begin
 W:=VP^.LineWidth;Col:=ColBit(VP^.LineCol);
 If W<=1 Then Begin
  ThinLine(X1,Y1,X2,Y2,LineStyleWord,Col);
  Exit;
 End;
 DXf:=X2-X1;DYf:=Y2-Y1;
 L:=Sqrt(DXf*DXf+DYf*DYf);
 If L=0 Then Begin DiscFill(X1,Y1,W Div 2,Col);Exit;End;
 NX:=-DYf/L*(W/2);NY:=DXf/L*(W/2);
 QX[0]:=Round(X1+NX);QY[0]:=Round(Y1+NY);
 QX[1]:=Round(X2+NX);QY[1]:=Round(Y2+NY);
 QX[2]:=Round(X2-NX);QY[2]:=Round(Y2-NY);
 QX[3]:=Round(X1-NX);QY[3]:=Round(Y1-NY);
 Sv:=VP^.FillInt;SvC:=VP^.FillCol;
 VP^.FillInt:=1;VP^.FillCol:=VP^.LineCol;
 PolyFillPts(4,QX,QY,False);
 VP^.FillInt:=Sv;VP^.FillCol:=SvC;
 If VP^.LineEnd0=2 Then DiscFill(X1,Y1,W Div 2,Col);
 If VP^.LineEnd1=2 Then DiscFill(X2,Y2,W Div 2,Col);
End;

{ ---------------------------------------------------------------------- }
{ Polygones remplis (parite)                                               }
{ ---------------------------------------------------------------------- }

Procedure PolyFillPts(N: Integer; Var XS,YS: TPoly; UseFillAttr: Boolean);
Var Y,MinY,MaxY,I,J,K,Cnt: Integer; Xi: Array[0..127] Of Integer; X1,Y1,X2,Y2,T: Integer;
Begin
 If N<3 Then Exit;
 MinY:=YS[0];MaxY:=YS[0];
 For I:=1 To N-1 Do Begin
  If YS[I]<MinY Then MinY:=YS[I];
  If YS[I]>MaxY Then MaxY:=YS[I];
 End;
 If MinY<CY1 Then MinY:=CY1;
 If MaxY>CY2 Then MaxY:=CY2;
 For Y:=MinY To MaxY Do Begin
  Cnt:=0;
  For I:=0 To N-1 Do Begin
   J:=(I+1) Mod N;
   X1:=XS[I];Y1:=YS[I];X2:=XS[J];Y2:=YS[J];
   If Y1=Y2 Then Continue;
   If Y1>Y2 Then Begin T:=X1;X1:=X2;X2:=T;T:=Y1;Y1:=Y2;Y2:=T;End;
   If (Y>=Y1) And (Y<Y2) And (Cnt<127) Then Begin
    Xi[Cnt]:=X1+Integer(LongInt(Y-Y1)*(X2-X1) Div (Y2-Y1));
    Inc(Cnt);
   End;
  End;
  For I:=1 To Cnt-1 Do Begin
   T:=Xi[I];K:=I-1;
   While (K>=0) And (Xi[K]>T) Do Begin Xi[K+1]:=Xi[K];Dec(K);End;
   Xi[K+1]:=T;
  End;
  I:=0;
  While I+1<Cnt Do Begin
   FillSpanPat(Y,Xi[I],Xi[I+1]);
   Inc(I,2);
  End;
 End;
End;

Procedure PolyOutline(N: Integer; Var XS,YS: TPoly; Closed: Boolean);
Var I: Integer;
Begin
 LinePhase:=0;
 For I:=0 To N-2 Do VLine(XS[I],YS[I],XS[I+1],YS[I+1]);
 If Closed And (N>2) Then VLine(XS[N-1],YS[N-1],XS[0],YS[0]);
End;

Procedure FillPolyAttr(N: Integer; Var XS,YS: TPoly);
Var SvW,SvC,SvT: Integer;
Begin
 PolyFillPts(N,XS,YS,True);
 If VP^.FillPer<>0 Then Begin
  SvW:=VP^.LineWidth;SvC:=VP^.LineCol;SvT:=VP^.LineType;
  VP^.LineWidth:=1;VP^.LineCol:=1;VP^.LineType:=1;
  PolyOutline(N,XS,YS,True);
  VP^.LineWidth:=SvW;VP^.LineCol:=SvC;VP^.LineType:=SvT;
 End;
End;

Procedure VBar(X1,Y1,X2,Y2: Integer);
Var Y,T: Integer; SvW,SvC,SvT: Integer;
Begin
 If X2<X1 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y2<Y1 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 For Y:=Max2(Y1,CY1) To Min2(Y2,CY2) Do FillSpanPat(Y,X1,X2);
 If VP^.FillPer<>0 Then Begin
  SvW:=VP^.LineWidth;SvC:=VP^.LineCol;SvT:=VP^.LineType;
  VP^.LineWidth:=1;VP^.LineCol:=1;VP^.LineType:=1;
  LinePhase:=0;
  VLine(X1,Y1,X2,Y1);VLine(X2,Y1,X2,Y2);VLine(X2,Y2,X1,Y2);VLine(X1,Y2,X1,Y1);
  VP^.LineWidth:=SvW;VP^.LineCol:=SvC;VP^.LineType:=SvT;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Arcs, ellipses, rectangles arrondis                                      }
{ ---------------------------------------------------------------------- }

Function ArcPoints(CXx,CYy,RX,RY,A0,A1: Integer; Var XS,YS: TPoly; Start: Integer): Integer;
Var N,I,Steps: Integer; A,Span: Real;
Begin
 Span:=(A1-A0)/10.0;
 If Span<=0 Then Span:=Span+360;
 Steps:=Round((Abs(RX)+Abs(RY))*Span/360.0/1.5);
 If Steps<4 Then Steps:=4;
 If Steps>120 Then Steps:=120;
 N:=Start;
 For I:=0 To Steps Do Begin
  If N>250 Then Break;
  A:=(A0/10.0+Span*I/Steps)*Pi/180.0;
  XS[N]:=CXx+Round(RX*Cos(A));
  YS[N]:=CYy-Round(RY*Sin(A));
  Inc(N);
 End;
 ArcPoints:=N;
End;

Procedure VArc(CXx,CYy,RX,RY,A0,A1: Integer; Mode: Integer);
Var N: Integer;
Begin
 If RX<=0 Then RX:=1;
 If RY<=0 Then RY:=1;
 Case Mode Of
  0: Begin N:=ArcPoints(CXx,CYy,RX,RY,A0,A1,PX,PY,0);PolyOutline(N,PX,PY,False);End;
  1: Begin
      N:=ArcPoints(CXx,CYy,RX,RY,A0,A1,PX,PY,0);
      PX[N]:=CXx;PY[N]:=CYy;Inc(N);
      FillPolyAttr(N,PX,PY);
     End;
 Else Begin
   N:=ArcPoints(CXx,CYy,RX,RY,0,3600,PX,PY,0);
   Dec(N);
   FillPolyAttr(N,PX,PY);
  End;
 End;
End;

Procedure VRoundRect(X1,Y1,X2,Y2: Integer; Fill: Boolean);
Var R,N,T: Integer;
Begin
 If X2<X1 Then Begin T:=X1;X1:=X2;X2:=T;End;
 If Y2<Y1 Then Begin T:=Y1;Y1:=Y2;Y2:=T;End;
 R:=Min2(X2-X1,Y2-Y1) Div 4;
 If R<2 Then R:=2;
 N:=0;
 N:=ArcPoints(X2-R,Y1+R,R,R,0,900,PX,PY,N);
 N:=ArcPoints(X1+R,Y1+R,R,R,900,1800,PX,PY,N);
 N:=ArcPoints(X1+R,Y2-R,R,R,1800,2700,PX,PY,N);
 N:=ArcPoints(X2-R,Y2-R,R,R,2700,3600,PX,PY,N);
 If Fill Then FillPolyAttr(N,PX,PY) Else PolyOutline(N,PX,PY,True);
End;

Procedure VMarker(X,Y: Integer);
Var H,I: Integer; Col: Boolean; SvW,SvT,SvC: Integer;
Begin
 H:=Max2(1,VP^.MarkH Div 2);
 Col:=ColBit(VP^.MarkCol);
 SvW:=VP^.LineWidth;SvT:=VP^.LineType;SvC:=VP^.LineCol;
 VP^.LineWidth:=1;VP^.LineType:=1;VP^.LineCol:=VP^.MarkCol;
 LinePhase:=0;
 Case VP^.MarkType Of
  1: PlotSolid(X,Y,Col);
  2: Begin VLine(X-H,Y,X+H,Y);VLine(X,Y-H,X,Y+H);End;
  3: Begin VLine(X-H,Y,X+H,Y);VLine(X,Y-H,X,Y+H);VLine(X-H,Y-H,X+H,Y+H);VLine(X-H,Y+H,X+H,Y-H);End;
  4: Begin VLine(X-H,Y-H,X+H,Y-H);VLine(X+H,Y-H,X+H,Y+H);VLine(X+H,Y+H,X-H,Y+H);VLine(X-H,Y+H,X-H,Y-H);End;
  5: Begin VLine(X-H,Y-H,X+H,Y+H);VLine(X-H,Y+H,X+H,Y-H);End;
  6: Begin VLine(X,Y-H,X+H,Y);VLine(X+H,Y,X,Y+H);VLine(X,Y+H,X-H,Y);VLine(X-H,Y,X,Y-H);End;
 Else Begin
   For I:=-1 To 1 Do PlotSolid(X+I,Y,Col);
   PlotSolid(X,Y-1,Col);PlotSolid(X,Y+1,Col);
  End;
 End;
 VP^.LineWidth:=SvW;VP^.LineType:=SvT;VP^.LineCol:=SvC;
End;

{ ---------------------------------------------------------------------- }
{ Texte                                                                    }
{ ---------------------------------------------------------------------- }

Function CellW(Cell: Integer): Integer;
Begin
 If Cell<=6 Then CellW:=6 Else CellW:=8;
End;

Function GlyphPix(Cell: Integer; Ch,Gx,Gy: Integer): Boolean;
Var Row,Col: Integer;
Begin
 GlyphPix:=False;
 If (Gx<0) Or (Gy<0) Then Exit;
 If Cell<=6 Then Begin
  If (Gx>5) Or (Gy>5) Then Exit;
  Row:=Gy*8 Div 6;Col:=Gx*8 Div 6;
 End Else If Cell<=8 Then Begin
  If (Gx>7) Or (Gy>7) Then Exit;
  Row:=Gy;Col:=Gx;
 End Else Begin
  If (Gx>7) Or (Gy>15) Then Exit;
  Row:=Gy Shr 1;Col:=Gx;
 End;
 GlyphPix:=(Font8[Ch And 255,Row] And (128 Shr Col))<>0;
End;

Function BaseLine(Cell: Integer): Integer;
Begin
 If Cell<=6 Then BaseLine:=5 Else If Cell<=8 Then BaseLine:=6 Else BaseLine:=12;
End;

Function TextWidthPx(Const S: String): Integer;
Var W: Integer;
Begin
 W:=Length(S)*CellW(VP^.TxtCell);
 If (VP^.TxtEff And 1)<>0 Then W:=W+Length(S);
 TextWidthPx:=W;
End;

Procedure DrawGlyph(OX,OY: Integer; Ch: Integer; Rot: Integer; RX,RY: Integer);
Var Gx,Gy,Cw,Ch2,DX,DY,TX,TY,Sh: Integer; On_,Col: Boolean; Bl: Integer;
Begin
 Cw:=CellW(VP^.TxtCell);Ch2:=VP^.TxtCell;
 If Ch2<6 Then Ch2:=6;
 Col:=ColBit(VP^.TxtCol);
 Bl:=BaseLine(Ch2);
 For Gy:=0 To Ch2-1 Do Begin
  Sh:=0;
  If (VP^.TxtEff And 4)<>0 Then Sh:=(Ch2-1-Gy) Div 4;
  For Gx:=0 To Cw-1 Do Begin
   On_:=GlyphPix(Ch2,Ch,Gx,Gy);
   If (VP^.TxtEff And 1)<>0 Then
    On_:=On_ Or GlyphPix(Ch2,Ch,Gx-1,Gy);
   If (VP^.TxtEff And 2)<>0 Then
    If On_ And (((OX+Gx+OY+Gy) And 1)=1) Then On_:=False;
   If (VP^.TxtEff And 8)<>0 Then If Gy=Bl+1 Then On_:=True;
   If ((VP^.TxtEff And 16)<>0) And Not On_ Then Begin
    If GlyphPix(Ch2,Ch,Gx-1,Gy) Or GlyphPix(Ch2,Ch,Gx+1,Gy) Or
       GlyphPix(Ch2,Ch,Gx,Gy-1) Or GlyphPix(Ch2,Ch,Gx,Gy+1) Then On_:=True;
   End;
   DX:=OX+Gx+Sh-RX;DY:=OY+Gy-RY;
   Case Rot Of
    1: Begin TX:=DY;TY:=-DX;End;
    2: Begin TX:=-DX;TY:=-DY;End;
    3: Begin TX:=-DY;TY:=DX;End;
   Else Begin TX:=DX;TY:=DY;End;
   End;
   If (VP^.WrMode=WM_REPL) Then PlotPat(RX+TX,RY+TY,On_,Col)
   Else If On_ Then PlotPat(RX+TX,RY+TY,True,Col);
  End;
 End;
End;

Procedure VGText(X,Y: Integer; Const S: String);
Var I,Cw,Ch,W,Rot,OX,OY,Bl,Adv: Integer;
Begin
 Cw:=CellW(VP^.TxtCell);Ch:=VP^.TxtCell;
 If Ch<6 Then Ch:=6;
 Bl:=BaseLine(Ch);
 Adv:=Cw;If (VP^.TxtEff And 1)<>0 Then Inc(Adv);
 W:=TextWidthPx(S);
 Rot:=((VP^.TxtRot+450) Div 900) And 3;
 OX:=X;
 Case VP^.TxtHAl Of
  1: OX:=X-W Div 2;
  2: OX:=X-W;
 End;
 Case VP^.TxtVAl Of
  0: OY:=Y-Bl;
  1: OY:=Y-Bl+(Bl Div 2);
  2: OY:=Y;
  3: OY:=Y-(Ch-1);
  4: OY:=Y-(Bl+1);
 Else OY:=Y;
 End;
 For I:=1 To Length(S) Do
  DrawGlyph(OX+(I-1)*Adv,OY,Ord(S[I]),Rot,X,Y);
End;

{ ---------------------------------------------------------------------- }
{ Copies raster                                                            }
{ ---------------------------------------------------------------------- }

Type
 TMfdb = Record
  Addr  : LongInt;
  W,H,WW,Stand,Planes : Integer;
 End;

Procedure ReadMfdb(P: LongInt; Var M: TMfdb);
Begin
 If P=0 Then Begin
  M.Addr:=0;M.W:=SW;M.H:=SH;M.WW:=40;M.Stand:=0;M.Planes:=1;Exit;
 End;
 M.Addr:=Rd32(P);M.W:=SExt(Rd16(P+4),2);M.H:=SExt(Rd16(P+6),2);
 M.WW:=SExt(Rd16(P+8),2);M.Stand:=Rd16(P+10);M.Planes:=SExt(Rd16(P+12),2);
 If M.Planes<1 Then M.Planes:=1;
End;

Function MBit(Const M: TMfdb; X,Y: Integer): Boolean;
Var A: LongInt;
Begin
 If M.Addr=0 Then MBit:=BGet(X,Y)
 Else Begin
  A:=M.Addr+LongInt(Y)*M.WW*2*M.Planes+(X Shr 3);
  MBit:=(Rd8(A) And (128 Shr (X And 7)))<>0;
 End;
End;

Procedure MPut(Const M: TMfdb; X,Y: Integer; V: Boolean);
Var A: LongInt; B: Byte;
Begin
 If M.Addr=0 Then Begin
  If (X>=CX1) And (X<=CX2) And (Y>=CY1) And (Y<=CY2) Then BPix(X,Y,V);
 End Else Begin
  A:=M.Addr+LongInt(Y)*M.WW*2*M.Planes+(X Shr 3);
  B:=Rd8(A);
  If V Then B:=B Or (128 Shr (X And 7)) Else B:=B And Not (128 Shr (X And 7));
  Wr8(A,B);
 End;
End;

Function RopBit(Mode: Integer; S,D: Boolean): Boolean;
Begin
 Case Mode Of
  0: RopBit:=False;
  1: RopBit:=S And D;
  2: RopBit:=S And Not D;
  3: RopBit:=S;
  4: RopBit:=Not S And D;
  5: RopBit:=D;
  6: RopBit:=S Xor D;
  7: RopBit:=S Or D;
  8: RopBit:=Not (S Or D);
  9: RopBit:=Not (S Xor D);
  10: RopBit:=Not D;
  11: RopBit:=S Or Not D;
  12: RopBit:=Not S;
  13: RopBit:=Not S Or D;
  14: RopBit:=Not (S And D);
 Else RopBit:=True;
 End;
End;

Procedure CopyRaster(Const Src,Dst: TMfdb; SX1,SY1,SX2,SY2,DX1,DY1: Integer; Mode: Integer;
                     Trans: Boolean; Fg,Bg: Integer);
Var W,H,X,Y,X0,X1_,XS,Y0,Y1_,YS: Integer; S,D,R: Boolean;
Begin
 If SX2<SX1 Then Begin X:=SX1;SX1:=SX2;SX2:=X;End;
 If SY2<SY1 Then Begin Y:=SY1;SY1:=SY2;SY2:=Y;End;
 W:=SX2-SX1+1;H:=SY2-SY1+1;
 If (W<=0) Or (H<=0) Then Exit;
 If (DY1>SY1) And (Src.Addr=Dst.Addr) Then Begin Y0:=H-1;Y1_:=0;YS:=-1;End
 Else Begin Y0:=0;Y1_:=H-1;YS:=1;End;
 If (DX1>SX1) And (Src.Addr=Dst.Addr) Then Begin X0:=W-1;X1_:=0;XS:=-1;End
 Else Begin X0:=0;X1_:=W-1;XS:=1;End;
 Y:=Y0;
 While True Do Begin
  X:=X0;
  While True Do Begin
   S:=MBit(Src,SX1+X,SY1+Y);
   D:=MBit(Dst,DX1+X,DY1+Y);
   If Trans Then Begin
    Case Mode Of
     1: If S Then R:=ColBit(Fg) Else R:=ColBit(Bg);
     2: If S Then R:=ColBit(Fg) Else R:=D;
     3: If S Then R:=Not D Else R:=D;
     4: If S Then R:=D Else R:=ColBit(Fg);
    Else R:=S;
    End;
    MPut(Dst,DX1+X,DY1+Y,R);
   End Else MPut(Dst,DX1+X,DY1+Y,RopBit(Mode,S,D));
   If X=X1_ Then Break;
   X:=X+XS;
  End;
  If Y=Y1_ Then Break;
  Y:=Y+YS;
 End;
End;

Procedure FloodFill(X,Y: Integer; Border: Integer);
Var Stack: Array[0..511,0..1] Of Integer; SP: Integer; L,R,I,XX: Integer; Seed: Boolean;
 Function Stop(Xp,Yp: Integer): Boolean;
 Begin
  If Border>=0 Then Stop:=BGet(Xp,Yp)=ColBit(Border) Else Stop:=BGet(Xp,Yp)<>Seed;
 End;
Begin
 Seed:=BGet(X,Y);
 If (X<CX1) Or (X>CX2) Or (Y<CY1) Or (Y>CY2) Then Exit;
 If Border>=0 Then If BGet(X,Y)=ColBit(Border) Then Exit;
 SP:=0;Stack[0,0]:=X;Stack[0,1]:=Y;SP:=1;
 While SP>0 Do Begin
  Dec(SP);XX:=Stack[SP,0];Y:=Stack[SP,1];
  If (Y<CY1) Or (Y>CY2) Then Continue;
  If Stop(XX,Y) Then Continue;
  If (Border<0) And (VP^.FillInt=1) And (Seed=ColBit(VP^.FillCol)) Then Continue;
  L:=XX;R:=XX;
  While (L>CX1) And Not Stop(L-1,Y) Do Dec(L);
  While (R<CX2) And Not Stop(R+1,Y) Do Inc(R);
  FillSpanPat(Y,L,R);
  For I:=L To R Do Begin
   If SP>=510 Then Break;
   If (Y>CY1) And Not Stop(I,Y-1) And ((I=L) Or Stop(I-1,Y-1)) Then Begin Stack[SP,0]:=I;Stack[SP,1]:=Y-1;Inc(SP);End;
   If (Y<CY2) And Not Stop(I,Y+1) And ((I=L) Or Stop(I-1,Y+1)) Then Begin Stack[SP,0]:=I;Stack[SP,1]:=Y+1;Inc(SP);End;
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Dispatcher VDI (TRAP #2, D0 = $73)                                      }
{ ---------------------------------------------------------------------- }

Var
 VdiMouseVec : Array[0..3] Of LongInt;
 TxtOutW,TxtOutH,TxtOutCW,TxtOutCH : Integer;

Function PtsX(Pi: LongInt; I: Integer): Integer;
Begin
 PtsX:=SExt(Rd16(Pi+I*4),2);
End;

Function PtsY(Pi: LongInt; I: Integer): Integer;
Begin
 PtsY:=SExt(Rd16(Pi+I*4+2),2);
End;

Procedure SetCellFromHeight(H: Integer);
Begin
 If H>=11 Then Begin VP^.TxtCell:=16;TxtOutW:=8;TxtOutH:=13;TxtOutCW:=8;TxtOutCH:=16;End
 Else If H>=7 Then Begin VP^.TxtCell:=8;TxtOutW:=8;TxtOutH:=7;TxtOutCW:=8;TxtOutCH:=8;End
 Else Begin VP^.TxtCell:=6;TxtOutW:=6;TxtOutH:=5;TxtOutCW:=6;TxtOutCH:=6;End;
End;

Procedure VdiOpenInfo(Io,Po: LongInt);
Var I: Integer;
Const Ii : Array[0..44] Of Integer =
 (639,399,0,372,372,3,7,0,6,0,1,24,12,2,10,1,2,3,4,5,6,7,8,9,10,
  1,2,3,4,5,6,7,8,9,10, 1,1,1,0,2,2,1,1,1,2);
Begin
 For I:=0 To 44 Do Wr16(Io+I*2,Ii[I]);
 Wr16(Io+26,2);
 { po : tailles min/max }
 Wr16(Po,4);Wr16(Po+2,4);Wr16(Po+4,8);Wr16(Po+6,16);
 Wr16(Po+8,1);Wr16(Po+10,0);Wr16(Po+12,40);Wr16(Po+14,0);
 Wr16(Po+16,8);Wr16(Po+18,8);Wr16(Po+20,24);Wr16(Po+22,24);
End;

Procedure CheckFonts;
Begin
 If Not FontReady Then Begin
  { en mode batch : police vide }
  FillChar(Font8,SizeOf(Font8),0);
  FontReady:=True;
 End;
End;

Procedure Vdi(Pb: LongInt);
Var Ctl,Ii,Pi,Io,Po: LongInt; Op,Sub,N,NI,H,I,J: Integer; S: String;
    X1,Y1,X2,Y2,V: Integer; Src,Dst: TMfdb; Mode: Integer; Hn: Integer;
    SvVP: Integer;
 Procedure RetI(Cnt: Integer);
 Begin
  Wr16(Ctl+8,Cnt);
 End;
 Procedure RetP(Cnt: Integer);
 Begin
  Wr16(Ctl+4,Cnt);
 End;
 Function IntIn(K: Integer): Integer;
 Begin
  IntIn:=SExt(Rd16(Ii+K*2),2);
 End;
 Procedure SetOut(K,Vv: Integer);
 Begin
  Wr16(Io+K*2,Vv And $FFFF);
 End;
 Procedure SetPts(K,Vv: Integer);
 Begin
  Wr16(Po+K*2,Vv And $FFFF);
 End;
 Procedure ReturnText;
 Begin
  SetPts(0,TxtOutW);SetPts(1,TxtOutH);SetPts(2,TxtOutCW);SetPts(3,TxtOutCH);
  RetP(2);
 End;
Begin
 CheckFonts;
 Ctl:=Rd32(Pb);Ii:=Rd32(Pb+4);Pi:=Rd32(Pb+8);Io:=Rd32(Pb+12);Po:=Rd32(Pb+16);
 Op:=Rd16(Ctl);N:=Rd16(Ctl+2);NI:=Rd16(Ctl+6);Sub:=Rd16(Ctl+10);H:=Rd16(Ctl+12);
 RetP(0);RetI(0);
 If AesTrace Then Begin
  Write(ConOut,'VDI ',Op,' sub=',Sub,' h=',H,' n=',N,' ni=',NI,' pts=');
  For I:=0 To 5 Do Write(ConOut,SExt(Rd16(Pi+I*2),2),' ');
  WriteLn(ConOut);Flush(ConOut);
 End;
 If Op=1 Then Begin
  { v_opnwk : station physique }
  Vd[1].Used:=True;VdiDefaults(Vd[1]);
  Wr16(Ctl+12,1);
  VdiOpenInfo(Io,Po);RetI(45);RetP(6);
  Exit;
 End;
 If Op=100 Then Begin
  Hn:=0;
  For I:=2 To MAXVWK Do If Not Vd[I].Used Then Begin Hn:=I;Break;End;
  If Hn=0 Then Begin Wr16(Ctl+12,0);Exit;End;
  Vd[Hn].Used:=True;VdiDefaults(Vd[Hn]);Vd[Hn].Owner:=VdiOwnerProc;
  If NI>=2 Then Begin
   Vd[Hn].LineType:=Clamp(IntIn(1),1,7);Vd[Hn].LineCol:=IntIn(2);
   Vd[Hn].MarkType:=Clamp(IntIn(3),1,6);Vd[Hn].MarkCol:=IntIn(4);
   Vd[Hn].TxtFont:=IntIn(5);Vd[Hn].TxtCol:=IntIn(6);
   Vd[Hn].FillInt:=Clamp(IntIn(7),0,4);Vd[Hn].FillSty:=IntIn(8);Vd[Hn].FillCol:=IntIn(9);
  End;
  Wr16(Ctl+12,Hn);
  VdiOpenInfo(Io,Po);RetI(45);RetP(6);
  Exit;
 End;
 SelVdi(H);
 Case Op Of
  2: Begin If (H>=1) And (H<=MAXVWK) Then Vd[H].Used:=False;End;
  101: Begin If (H>=2) And (H<=MAXVWK) Then Vd[H].Used:=False;End;
  3: Begin
      SetClip(0,0,SW-1,SH-1);
      BRect(0,0,SW-1,SH-1,False);
      ConRow:=0;ConCol:=0;
      SelVdi(H);
     End;
  4: Begin End;
  5: Case Sub Of
      1: Begin SetOut(0,CON_ROWS);SetOut(1,CON_COLS);RetI(2);End;
      2: Begin End;
      3: Begin ConClear;End;
      4: If ConRow>0 Then Dec(ConRow);
      5: If ConRow<CON_ROWS-1 Then Inc(ConRow);
      6: If ConCol<CON_COLS-1 Then Inc(ConCol);
      7: If ConCol>0 Then Dec(ConCol);
      8: Begin ConRow:=0;ConCol:=0;End;
      9: Begin ConPut(27);ConPut(Ord('J'));End;
      10: Begin ConPut(27);ConPut(Ord('K'));End;
      11: Begin
           ConRow:=Clamp(IntIn(0)-1,0,CON_ROWS-1);ConCol:=Clamp(IntIn(1)-1,0,CON_COLS-1);
          End;
      12: For I:=0 To NI-1 Do ConPut(IntIn(I) And $FF);
      13: ConRev:=True;
      14: ConRev:=False;
      15: Begin SetOut(0,ConRow+1);SetOut(1,ConCol+1);RetI(2);End;
      16: Begin SetOut(0,1);RetI(1);End;
      18: Begin End;
      19: Begin End;
     End;
  6: Begin
      For I:=0 To N-1 Do Begin PX[I]:=PtsX(Pi,I);PY[I]:=PtsY(Pi,I);End;
      LinePhase:=0;
      If VP^.LineWidth>1 Then Begin
       For I:=0 To N-2 Do VLine(PX[I],PY[I],PX[I+1],PY[I+1]);
      End Else PolyOutline(N,PX,PY,False);
     End;
  7: For I:=0 To N-1 Do VMarker(PtsX(Pi,I),PtsY(Pi,I));
  8: Begin
      S:='';
      For I:=0 To NI-1 Do Begin
       If Length(S)<250 Then S:=S+Chr(Rd16(Ii+I*2) And $FF);
      End;
      VGText(PtsX(Pi,0),PtsY(Pi,0),S);
     End;
  9: Begin
      If N>250 Then N:=250;
      For I:=0 To N-1 Do Begin PX[I]:=PtsX(Pi,I);PY[I]:=PtsY(Pi,I);End;
      FillPolyAttr(N,PX,PY);
     End;
  10: Begin
       X1:=PtsX(Pi,0);Y1:=PtsY(Pi,0);X2:=PtsX(Pi,1);Y2:=PtsY(Pi,1);
       N:=SExt(Rd16(Ctl+14),2);   { longueur de ligne }
       J:=SExt(Rd16(Ctl+18),2);   { nombre de lignes }
       If (N>0) And (J>0) Then
        For I:=0 To N*J-1 Do Begin
         V:=SExt(Rd16(Ii+I*2),2);
         If V<>0 Then
          Begin
           PlotSolid(X1+(I Mod N)*(X2-X1+1) Div N,Y1+(I Div N)*(Y2-Y1+1) Div J,True);
          End;
        End;
      End;
  11: Case Sub Of
       1: VBar(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1));
       2: VArc(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,3),PtsX(Pi,3),IntIn(0),IntIn(1),0);
       3: VArc(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,3),PtsX(Pi,3),IntIn(0),IntIn(1),1);
       4: VArc(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,2),PtsX(Pi,2),0,3600,2);
       5: VArc(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),0,3600,2);
       6: VArc(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),IntIn(0),IntIn(1),0);
       7: VArc(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),IntIn(0),IntIn(1),1);
       8: VRoundRect(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),False);
       9: VRoundRect(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),True);
       10: Begin
            S:='';
            For I:=2 To NI-1 Do If Length(S)<250 Then S:=S+Chr(Rd16(Ii+I*2) And $FF);
            X1:=PtsX(Pi,0);Y1:=PtsY(Pi,0);N:=PtsX(Pi,1);
            If Length(S)>1 Then Begin
             J:=TextWidthPx(S);
             If (IntIn(1)<>0) And (N>J) Then Begin
              For I:=1 To Length(S) Do Begin
               VGText(X1+(I-1)*N Div Length(S),Y1,S[I]);
              End;
             End Else VGText(X1,Y1,S);
            End Else VGText(X1,Y1,S);
           End;
      End;
  12: Begin SetCellFromHeight(PtsY(Pi,1));ReturnText;End;
  13: Begin V:=IntIn(0);V:=((V+450) Div 900)*900;V:=V Mod 3600;If V<0 Then V:=0;VP^.TxtRot:=V;SetOut(0,V);RetI(1);End;
  14: Begin SetOut(0,IntIn(0));RetI(1);End;
  15: Begin VP^.LineType:=Clamp(IntIn(0),1,7);SetOut(0,VP^.LineType);RetI(1);End;
  16: Begin
       V:=PtsX(Pi,0);If V<1 Then V:=1;If Not Odd(V) Then Dec(V,0);
       If V>39 Then V:=39;
       VP^.LineWidth:=V;SetPts(0,V);SetPts(1,0);RetP(1);
      End;
  17: Begin VP^.LineCol:=IntIn(0);SetOut(0,IntIn(0));RetI(1);End;
  18: Begin VP^.MarkType:=Clamp(IntIn(0),1,6);SetOut(0,VP^.MarkType);RetI(1);End;
  19: Begin VP^.MarkH:=Max2(1,PtsY(Pi,1));SetPts(0,VP^.MarkH);SetPts(1,VP^.MarkH);RetP(1);End;
  20: Begin VP^.MarkCol:=IntIn(0);SetOut(0,IntIn(0));RetI(1);End;
  21: Begin VP^.TxtFont:=IntIn(0);SetOut(0,1);RetI(1);End;
  22: Begin VP^.TxtCol:=IntIn(0);SetOut(0,IntIn(0));RetI(1);End;
  23: Begin VP^.FillInt:=Clamp(IntIn(0),0,4);SetOut(0,VP^.FillInt);RetI(1);End;
  24: Begin VP^.FillSty:=IntIn(0);SetOut(0,VP^.FillSty);RetI(1);End;
  25: Begin VP^.FillCol:=IntIn(0);SetOut(0,IntIn(0));RetI(1);End;
  26: Begin
       V:=IntIn(0);SetOut(0,V);
       If V=0 Then Begin SetOut(1,1000);SetOut(2,1000);SetOut(3,1000);End
       Else Begin SetOut(1,0);SetOut(2,0);SetOut(3,0);End;
       RetI(4);
      End;
  28: Begin
       SetPts(0,GMouseX);SetPts(1,GMouseY);RetP(1);SetOut(0,GMouseB);RetI(1);
      End;
  29: Begin SetOut(0,0);SetOut(1,0);RetI(2);End;
  30: Begin SetOut(0,1);RetI(1);End;
  31: RetI(0);
  32: Begin
       V:=IntIn(0);If (V<1) Or (V>4) Then V:=1;VP^.WrMode:=V;SetOut(0,V);RetI(1);
      End;
  33: Begin SetOut(0,IntIn(1));RetI(1);End;
  35: Begin
       SetOut(0,VP^.LineType);SetOut(1,VP^.LineCol);SetOut(2,VP^.WrMode);
       SetOut(3,VP^.LineEnd0);SetOut(4,VP^.LineEnd1);RetI(5);
       SetPts(0,VP^.LineWidth);SetPts(1,0);RetP(1);
      End;
  36: Begin
       SetOut(0,VP^.MarkType);SetOut(1,VP^.MarkCol);SetOut(2,VP^.WrMode);RetI(3);
       SetPts(0,VP^.MarkH);SetPts(1,VP^.MarkH);RetP(1);
      End;
  37: Begin
       SetOut(0,VP^.FillInt);SetOut(1,VP^.FillCol);SetOut(2,VP^.FillSty);
       SetOut(3,VP^.WrMode);SetOut(4,VP^.FillPer);RetI(5);
      End;
  38: Begin
       SetOut(0,VP^.TxtFont);SetOut(1,VP^.TxtCol);SetOut(2,VP^.TxtRot);
       SetOut(3,VP^.TxtHAl);SetOut(4,VP^.TxtVAl);SetOut(5,VP^.WrMode);RetI(6);
       SetCellFromHeight(VP^.TxtCell);ReturnText;
      End;
  39: Begin
       VP^.TxtHAl:=Clamp(IntIn(0),0,2);VP^.TxtVAl:=Clamp(IntIn(1),0,5);
       SetOut(0,VP^.TxtHAl);SetOut(1,VP^.TxtVAl);RetI(2);
      End;
  102: Begin
        If IntIn(0)=0 Then Begin VdiOpenInfo(Io,Po);RetI(45);RetP(6);End
        Else Begin
         For I:=0 To 44 Do SetOut(I,0);
         SetOut(0,1);SetOut(1,2);SetOut(2,63);SetOut(3,0);SetOut(4,1);SetOut(5,0);
         SetOut(6,2000);SetOut(7,1);SetOut(8,1);SetOut(9,4);SetOut(10,1);SetOut(11,1);
         SetOut(14,128);SetOut(15,-1);SetOut(16,2);
         For I:=0 To 11 Do SetPts(I,0);
         RetI(45);RetP(6);
        End;
       End;
  103: Begin
        FloodFill(PtsX(Pi,0),PtsY(Pi,0),IntIn(0));
       End;
  104: Begin VP^.FillPer:=Ord(IntIn(0)<>0);SetOut(0,VP^.FillPer);RetI(1);End;
  105: Begin
        V:=Ord(BGet(PtsX(Pi,0),PtsY(Pi,0)));SetOut(0,V);SetOut(1,V);RetI(2);
       End;
  106: Begin VP^.TxtEff:=IntIn(0) And 63;SetOut(0,VP^.TxtEff);RetI(1);End;
  107: Begin
        V:=IntIn(0);
        If V>=10 Then SetCellFromHeight(16) Else If V>=9 Then SetCellFromHeight(8) Else SetCellFromHeight(6);
        SetOut(0,V);RetI(1);ReturnText;
       End;
  108: Begin VP^.LineEnd0:=IntIn(0);VP^.LineEnd1:=IntIn(1);SetOut(0,VP^.LineEnd0);SetOut(1,VP^.LineEnd1);RetI(2);End;
  109,121: Begin
        ReadMfdb(Rd32(Ctl+14),Src);ReadMfdb(Rd32(Ctl+18),Dst);
        If Op=109 Then Begin
         Mode:=IntIn(0);
         CopyRaster(Src,Dst,PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),PtsX(Pi,2),PtsY(Pi,2),Mode,False,1,0);
        End Else
         CopyRaster(Src,Dst,PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),PtsX(Pi,2),PtsY(Pi,2),
                    Clamp(IntIn(0),1,4),True,IntIn(1),IntIn(2));
       End;
  110: Begin
        ReadMfdb(Rd32(Ctl+14),Src);ReadMfdb(Rd32(Ctl+18),Dst);
        If (Src.Addr<>0) And (Dst.Addr<>0) And (Src.Addr<>Dst.Addr) Then
         For I:=0 To Src.WW*2*Src.H*Src.Planes-1 Do Wr8(Dst.Addr+I,Rd8(Src.Addr+I));
        Wr16(Rd32(Ctl+18)+10,Ord(Rd16(Rd32(Ctl+14)+10)=0));
       End;
  112: For I:=0 To 15 Do VP^.UdPat[I]:=Rd16(Ii+I*2);
  113: VP^.LineUd:=Rd16(Ii);
  114: Begin
        I:=VP^.FillPer;VP^.FillPer:=0;
        VBar(PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1));
        VP^.FillPer:=I;
       End;
  116: Begin
        S:='';
        For I:=0 To NI-1 Do S:=S+Chr(Rd16(Ii+I*2) And $FF);
        J:=TextWidthPx(S);
        If VP^.TxtCell<6 Then VP^.TxtCell:=6;
        SetPts(0,0);SetPts(1,VP^.TxtCell);SetPts(2,J);SetPts(3,VP^.TxtCell);
        SetPts(4,J);SetPts(5,0);SetPts(6,0);SetPts(7,0);RetP(4);
       End;
  117: Begin
        SetPts(0,CellW(VP^.TxtCell));SetPts(1,0);SetPts(2,0);SetPts(3,0);SetPts(4,0);SetPts(5,0);RetP(3);
        SetOut(0,IntIn(0));RetI(1);
       End;
  118: Begin
        Wr32(Ctl+18,VexTim);VexTim:=Rd32(Ctl+14);VexTimLast:=MsNow;
        SetOut(0,20);RetI(1);
       End;
  119: Begin SetOut(0,0);RetI(1);End;
  120: Begin End;
  122: Begin
        If IntIn(0)<>0 Then MouseHidden:=0 Else If MouseHidden>0 Then Dec(MouseHidden);
       End;
  123: Inc(MouseHidden);
  124: Begin SetOut(0,GMouseB);RetI(1);SetPts(0,GMouseX);SetPts(1,GMouseY);RetP(1);End;
  125: Begin Wr32(Ctl+18,VexBut);VexBut:=Rd32(Ctl+14);End;
  126: Begin Wr32(Ctl+18,VexMot);VexMot:=Rd32(Ctl+14);End;
  127: Begin
        Wr32(Ctl+18,VexCur);VexCur:=Rd32(Ctl+14);
        UserCursor:=VexCur<>STUB_RTS;
       End;
  128: Begin SetOut(0,0);RetI(1);End;
  129: Begin
        VP^.ClipOn:=IntIn(0)<>0;
        VP^.Cx1:=PtsX(Pi,0);VP^.Cy1:=PtsY(Pi,0);VP^.Cx2:=PtsX(Pi,1);VP^.Cy2:=PtsY(Pi,1);
        SetOut(0,0);
       End;
  130: Begin
        SetOut(0,1);
        S:='Atari System Font';
        For I:=1 To 32 Do If I<=Length(S) Then SetOut(I,Ord(S[I])) Else SetOut(I,0);
        SetOut(33,0);RetI(34);
       End;
  131: Begin
        If VP^.TxtCell<6 Then VP^.TxtCell:=6;
        SetOut(0,32);SetOut(1,255);RetI(2);
        I:=BaseLine(VP^.TxtCell);
        SetPts(0,CellW(VP^.TxtCell));SetPts(1,VP^.TxtCell-1-I);SetPts(2,CellW(VP^.TxtCell));SetPts(3,0);
        SetPts(4,0);SetPts(5,VP^.TxtCell-1-I);SetPts(6,0);SetPts(7,I Div 2);SetPts(8,0);SetPts(9,I);
        RetP(5);
       End;
 End;
End;

{ ====================================================================== }
{                  GEM : OBJETS, RESSOURCES ET EDITION                   }
{ ====================================================================== }

Const
 G_BOX=20; G_TEXT=21; G_BOXTEXT=22; G_IMAGE=23; G_USERDEF=24; G_IBOX=25;
 G_BUTTON=26; G_BOXCHAR=27; G_STRING=28; G_FTEXT=29; G_FBOXTEXT=30; G_ICON=31;
 G_TITLE=32;
 OF_SELECTABLE=1; OF_DEFAULT=2; OF_EXIT=4; OF_EDITABLE=8; OF_RBUTTON=16;
 OF_LASTOB=32; OF_TOUCHEXIT=64; OF_HIDETREE=128; OF_INDIRECT=256;
 OS_SELECTED=1; OS_CROSSED=2; OS_CHECKED=4; OS_DISABLED=8; OS_OUTLINED=16;
 OS_SHADOWED=32;
 STUB_RET = $0430;

Type
 TScrSave = Record
  P : Pointer;
  XB1,XB2,Y1,Y2 : Integer;
  Sz : LongInt;
 End;

Var
 ObjDepthGuard : Integer;
 EditObj,EditIdx : Integer;
 EditTree : LongInt;

{ ---------------------------------------------------------------------- }
{ Acces aux arbres d'objets                                                 }
{ ---------------------------------------------------------------------- }

Function OA(T: LongInt; I: Integer): LongInt;
Begin
 OA:=T+LongInt(I)*24;
End;

Function ONext(T: LongInt; I: Integer): Integer;
Begin
 ONext:=SExt(Rd16(OA(T,I)),2);
End;

Function OHead(T: LongInt; I: Integer): Integer;
Begin
 OHead:=SExt(Rd16(OA(T,I)+2),2);
End;

Function OTail(T: LongInt; I: Integer): Integer;
Begin
 OTail:=SExt(Rd16(OA(T,I)+4),2);
End;

Function OType(T: LongInt; I: Integer): Integer;
Begin
 OType:=Rd16(OA(T,I)+6) And $FF;
End;

Function OFlags(T: LongInt; I: Integer): Integer;
Begin
 OFlags:=Rd16(OA(T,I)+8);
End;

Function OState(T: LongInt; I: Integer): Integer;
Begin
 OState:=Rd16(OA(T,I)+10);
End;

Function OSpec(T: LongInt; I: Integer): LongInt;
Begin
 OSpec:=Rd32(OA(T,I)+12);
End;

Function OX(T: LongInt; I: Integer): Integer;
Begin
 OX:=SExt(Rd16(OA(T,I)+16),2);
End;

Function OY(T: LongInt; I: Integer): Integer;
Begin
 OY:=SExt(Rd16(OA(T,I)+18),2);
End;

Function OW(T: LongInt; I: Integer): Integer;
Begin
 OW:=SExt(Rd16(OA(T,I)+20),2);
End;

Function OH(T: LongInt; I: Integer): Integer;
Begin
 OH:=SExt(Rd16(OA(T,I)+22),2);
End;

Procedure SetOState(T: LongInt; I,V: Integer);
Begin
 Wr16(OA(T,I)+10,V And $FFFF);
End;

Procedure SetOFlags(T: LongInt; I,V: Integer);
Begin
 Wr16(OA(T,I)+8,V And $FFFF);
End;

Function OParent(T: LongInt; I: Integer): Integer;
Var Cur,Nx,Guard: Integer;
Begin
 OParent:=-1;
 If I<=0 Then Exit;
 Cur:=I;Guard:=0;
 While Guard<2000 Do Begin
  Nx:=ONext(T,Cur);
  If Nx<0 Then Exit;
  If OTail(T,Nx)=Cur Then Begin OParent:=Nx;Exit;End;
  Cur:=Nx;Inc(Guard);
 End;
End;

Procedure ObjOffset(T: LongInt; I: Integer; Var X,Y: Integer);
Var Cur,Guard: Integer;
Begin
 X:=0;Y:=0;Cur:=I;Guard:=0;
 While (Cur>=0) And (Guard<64) Do Begin
  X:=X+OX(T,Cur);Y:=Y+OY(T,Cur);
  Cur:=OParent(T,Cur);
  Inc(Guard);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Sauvegarde / restauration de zones de l'ecran                            }
{ ---------------------------------------------------------------------- }

Procedure ScrSave(X1,Y1,X2,Y2: Integer; Var S: TScrSave);
Var Y,XB: Integer; Q: LongInt;
Begin
 If X1<0 Then X1:=0;If Y1<0 Then Y1:=0;
 If X2>SW-1 Then X2:=SW-1;If Y2>SH-1 Then Y2:=SH-1;
 S.XB1:=X1 Shr 3;S.XB2:=X2 Shr 3;S.Y1:=Y1;S.Y2:=Y2;
 S.Sz:=LongInt(S.XB2-S.XB1+1)*(Y2-Y1+1);
 If S.Sz<=0 Then Begin S.P:=Nil;S.Sz:=0;Exit;End;
 GetMem(S.P,S.Sz);
 Q:=0;
 For Y:=Y1 To Y2 Do
  For XB:=S.XB1 To S.XB2 Do Begin
   PByteSet(S.P,Q,Rd8(DrawBase+LongInt(Y)*80+XB));Inc(Q);
  End;
End;

Procedure ScrRestore(Var S: TScrSave);
Var Y,XB: Integer; Q: LongInt;
Begin
 If S.P=Nil Then Exit;
 Q:=0;
 For Y:=S.Y1 To S.Y2 Do
  For XB:=S.XB1 To S.XB2 Do Begin
   Wr8(DrawBase+LongInt(Y)*80+XB,PByteAt(S.P,Q));Inc(Q);
  End;
 FreeMem(S.P,S.Sz);S.P:=Nil;
End;

{ ---------------------------------------------------------------------- }
{ Appel d'une routine du programme invite                                  }
{ ---------------------------------------------------------------------- }

Function CallGuestEx(Addr,Arg,D0,D1,A0: LongInt; Var OD0,OD1: LongInt): LongInt;
Var SvRg: Array[0..15] Of LongInt; SvPC,SvSR,SvUSP,SvSSP,SvOp: LongInt; N: LongInt; SvStop: Integer;
Begin
 Move(Rg,SvRg,SizeOf(Rg));
 SvPC:=PC;SvSR:=SRv;SvUSP:=USPv;SvSSP:=SSPv;SvOp:=CurOpPC;SvStop:=StopReason;
 If ((SRv And SR_S)=0) And (SSPv>$1000) Then SetSR(SRv Or SR_S);
 Rg[15]:=Rg[15]-64;
 PushL(Arg);
 PushL(STUB_RET);
 Rg[0]:=D0;Rg[1]:=D1;Rg[8]:=A0;
 PC:=Addr;
 N:=0;
 StopReason:=STOP_NONE;
 While (PC<>STUB_RET) And (StopReason=STOP_NONE) And (N<2000000) Do Begin
  Step;Inc(N);
 End;
 CallGuestEx:=Rg[0];
 OD0:=Rg[0];OD1:=Rg[1];
 If StopReason=STOP_NONE Then Begin
  Move(SvRg,Rg,SizeOf(Rg));
  PC:=SvPC;SRv:=SvSR;USPv:=SvUSP;SSPv:=SvSSP;CurOpPC:=SvOp;
  StopReason:=SvStop;
 End;
End;

Function CallGuest(Addr,Arg: LongInt): LongInt;
Var A,B: LongInt;
Begin
 CallGuest:=CallGuestEx(Addr,Arg,Rg[0],Rg[1],Rg[8],A,B);
End;

{ ---------------------------------------------------------------------- }
{ Dessin d'un objet                                                        }
{ ---------------------------------------------------------------------- }

Procedure OSetup;
Begin
 SelVdi(0);
 VP^.WrMode:=WM_REPL;VP^.FillPer:=0;VP^.LineWidth:=1;VP^.LineType:=1;VP^.LineCol:=1;
 VP^.TxtEff:=0;VP^.TxtRot:=0;VP^.TxtHAl:=0;VP^.TxtVAl:=0;
End;

Procedure OFill(X1,Y1,X2,Y2: Integer; Pat: Integer; ColIdx: Integer);
Begin
 If Pat=0 Then Begin VP^.FillInt:=0;VP^.FillCol:=0;End
 Else If Pat=7 Then Begin VP^.FillInt:=1;VP^.FillCol:=ColIdx;End
 Else Begin VP^.FillInt:=2;VP^.FillSty:=Pat;VP^.FillCol:=ColIdx;End;
 VBar(X1,Y1,X2,Y2);
End;

Procedure OFrameRect(X1,Y1,X2,Y2: Integer; Col: Integer);
Var C: Boolean;
Begin
 C:=ColBit(Col);
 FastSpan(Y1,X1,X2,C,False);FastSpan(Y2,X1,X2,C,False);
 If Y2>Y1+1 Then Begin
  VP^.FillInt:=1;VP^.FillCol:=Col;
  VBar(X1,Y1+1,X1,Y2-1);VBar(X2,Y1+1,X2,Y2-1);
 End;
End;

Procedure OBorder(X,Y,W,H,Th,Col: Integer);
Var I,A: Integer;
Begin
 If Th=0 Then Exit;
 A:=Abs(Th);
 For I:=0 To A-1 Do Begin
  If Th>0 Then OFrameRect(X+I,Y+I,X+W-1-I,Y+H-1-I,Col)
  Else OFrameRect(X-1-I,Y-1-I,X+W+I,Y+H+I,Col);
 End;
End;

Procedure OText(X,Y: Integer; Const S: String; Cell: Integer; ColIdx: Integer; Repl: Boolean);
Begin
 VP^.TxtCell:=Cell;VP^.TxtCol:=ColIdx;
 If Repl Then VP^.WrMode:=WM_REPL Else VP^.WrMode:=WM_TRANS;
 VP^.TxtHAl:=0;VP^.TxtVAl:=5;
 VGText(X,Y,S);
 VP^.WrMode:=WM_REPL;VP^.TxtVAl:=0;
End;

Function CellOfFont(F: Integer): Integer;
Begin
 If F=5 Then CellOfFont:=8 Else CellOfFont:=16;
End;

{ Construit la chaine affichee d'un champ editable (modele + saisie) }
Function FtextDisplay(Const Tmpl,Txt: String): String;
Var R: String; I,K: Integer;
Begin
 R:='';K:=1;
 For I:=1 To Length(Tmpl) Do Begin
  If Tmpl[I]='_' Then Begin
   If K<=Length(Txt) Then Begin R:=R+Txt[K];Inc(K);End Else R:=R+'_';
  End Else R:=R+Tmpl[I];
 End;
 FtextDisplay:=R;
End;

Procedure ObjDrawOne(T: LongInt; I: Integer; AX,AY: Integer; Const ClipX1,ClipY1,ClipX2,ClipY2: Integer);
Var Ty,St,Fl,W,H,Th,Cw,Ch,Fi,Pat,Ic,Bc,Tc,Just,Fnt,Cell: Integer; Sp,Ted,Pr: LongInt;
    Col: Word; S,Tm: String; Ch1: Char; TXx,TYy,Rx,K,J,XX,YY: Integer; Repl: Boolean;
    Ib: LongInt; Wb,Hl,Wi,Hi,Xi,Yi,Bx,By: Integer; PrevSt: Integer; Rv: LongInt; Tw: Integer;
    Pb: LongInt;
Begin
 OSetup;
 SetClip(ClipX1,ClipY1,ClipX2,ClipY2);
 Ty:=OType(T,I);St:=OState(T,I);Fl:=OFlags(T,I);
 W:=OW(T,I);H:=OH(T,I);Sp:=OSpec(T,I);
 If (Fl And OF_INDIRECT)<>0 Then Sp:=Rd32(Sp);
 { ombre }
 If (St And OS_SHADOWED)<>0 Then Begin
  Th:=SExt((Sp Shr 16) And $FF,1);
  If (Ty=G_BOXTEXT) Or (Ty=G_FBOXTEXT) Then Th:=SExt(Rd16(Sp+22),2);
  K:=Max2(2,Abs(Th)*2);
  If Th<0 Then Begin AX:=AX;End;
  OFill(AX+K,AY+H,AX+W-1+K,AY+H+K-1,7,1);
  OFill(AX+W,AY+K,AX+W+K-1,AY+H-1,7,1);
 End;
 If (St And OS_OUTLINED)<>0 Then Begin
  OFill(AX-3,AY-3,AX+W+2,AY+H+2,0,0);
  OFrameRect(AX-3,AY-3,AX+W+2,AY+H+2,1);
 End;
 Case Ty Of
  G_BOX,G_IBOX,G_BOXCHAR: Begin
    Col:=Sp And $FFFF;Th:=SExt((Sp Shr 16) And $FF,1);
    Ic:=Col And 15;Pat:=(Col Shr 4) And 7;Tc:=(Col Shr 8) And 15;Bc:=(Col Shr 12) And 15;
    If Ty<>G_IBOX Then Begin
     If Th>=0 Then OFill(AX,AY,AX+W-1,AY+H-1,Pat,Ic)
     Else OFill(AX,AY,AX+W-1,AY+H-1,Pat,Ic);
    End;
    OBorder(AX,AY,W,H,Th,Bc);
    If Ty=G_BOXCHAR Then Begin
     Ch1:=Chr((Sp Shr 24) And $FF);
     Repl:=(Col And $80)<>0;
     OText(AX+(W-8) Div 2,AY+(H-16) Div 2,Ch1,16,Tc,False);
    End;
   End;
  G_TEXT,G_FTEXT,G_BOXTEXT,G_FBOXTEXT: Begin
    Ted:=Sp;
    Col:=Rd16(Ted+18);Fnt:=Rd16(Ted+12);Just:=Rd16(Ted+16);Th:=SExt(Rd16(Ted+22),2);
    Ic:=Col And 15;Pat:=(Col Shr 4) And 7;Tc:=(Col Shr 8) And 15;Bc:=(Col Shr 12) And 15;
    Repl:=(Col And $80)<>0;
    Cell:=CellOfFont(Fnt);
    If (Ty=G_BOXTEXT) Or (Ty=G_FBOXTEXT) Then Begin
     OFill(AX,AY,AX+W-1,AY+H-1,Pat,Ic);
     OBorder(AX,AY,W,H,Th,Bc);
    End Else If Repl Then OFill(AX,AY,AX+W-1,AY+H-1,Pat,Ic);
    S:=RdStr(Rd32(Ted),120);
    If (Ty=G_FTEXT) Or (Ty=G_FBOXTEXT) Then S:=FtextDisplay(RdStr(Rd32(Ted+4),120),S);
    Tw:=Length(S)*8;
    Case Just Of
     1: TXx:=AX+W-Tw;
     2: TXx:=AX+(W-Tw) Div 2;
    Else TXx:=AX;
    End;
    TYy:=AY+(H-Cell) Div 2;
    OText(TXx,TYy,S,Cell,Tc,False);
   End;
  G_STRING,G_TITLE: Begin
    S:=RdStr(Sp,120);
    OFill(AX,AY,AX+W-1,AY+H-1,0,0);
    OText(AX,AY+(H-16) Div 2,S,16,1,False);
   End;
  G_BUTTON: Begin
    S:=RdStr(Sp,120);
    Th:=1;
    If (Fl And OF_EXIT)<>0 Then Th:=2;
    If (Fl And OF_DEFAULT)<>0 Then Th:=3;
    OFill(AX,AY,AX+W-1,AY+H-1,0,0);
    OBorder(AX,AY,W,H,Th,1);
    OText(AX+(W-Length(S)*8) Div 2,AY+(H-16) Div 2,S,16,1,False);
   End;
  G_IMAGE: Begin
    Pb:=Sp;
    Wb:=Rd16(Pb+4);Hl:=Rd16(Pb+6);Col:=Rd16(Pb+12);
    Ic:=Col And 15;
    For YY:=0 To Hl-1 Do
     For XX:=0 To Wb*8-1 Do Begin
      If (Rd8(Rd32(Pb)+LongInt(YY)*Wb+(XX Shr 3)) And (128 Shr (XX And 7)))<>0 Then
       PlotSolid(AX+XX,AY+YY,ColBit(Ic))
      Else PlotSolid(AX+XX,AY+YY,False);
     End;
   End;
  G_ICON: Begin
    Ib:=Sp;
    Wi:=SExt(Rd16(Ib+22),2);Hi:=SExt(Rd16(Ib+24),2);
    Xi:=SExt(Rd16(Ib+18),2);Yi:=SExt(Rd16(Ib+20),2);
    For YY:=0 To Hi-1 Do
     For XX:=0 To Wi-1 Do Begin
      K:=((Wi+15) Div 16)*2;
      If (Rd8(Rd32(Ib)+LongInt(YY)*K+(XX Shr 3)) And (128 Shr (XX And 7)))<>0 Then Begin
       If (Rd8(Rd32(Ib+4)+LongInt(YY)*K+(XX Shr 3)) And (128 Shr (XX And 7)))<>0 Then
        PlotSolid(AX+Xi+XX,AY+Yi+YY,True)
       Else PlotSolid(AX+Xi+XX,AY+Yi+YY,False);
      End;
     End;
    S:=RdStr(Rd32(Ib+8),40);
    Tw:=SExt(Rd16(Ib+30),2);
    OFill(AX+SExt(Rd16(Ib+26),2),AY+SExt(Rd16(Ib+28),2),AX+SExt(Rd16(Ib+26),2)+Tw-1,
          AY+SExt(Rd16(Ib+28),2)+SExt(Rd16(Ib+32),2)-1,0,0);
    OText(AX+SExt(Rd16(Ib+26),2)+(Tw-Length(S)*8) Div 2,AY+SExt(Rd16(Ib+28),2),S,8,1,False);
    If Rd16(Ib+12)<>0 Then
     OText(AX+SExt(Rd16(Ib+14),2),AY+SExt(Rd16(Ib+16),2),Chr(Rd16(Ib+12) And $FF),8,1,False);
    OSetup;SetClip(ClipX1,ClipY1,ClipX2,ClipY2);
    If (St And OS_SELECTED)<>0 Then Begin
     { icone et texte inverses, sans le reste de l'objet }
     VP^.FillInt:=1;VP^.WrMode:=WM_XOR;VP^.FillCol:=1;
     VBar(AX+Xi,AY+Yi,AX+Xi+Wi-1,AY+Yi+Hi-1);
     VBar(AX+SExt(Rd16(Ib+26),2),AY+SExt(Rd16(Ib+28),2),AX+SExt(Rd16(Ib+26),2)+Tw-1,
          AY+SExt(Rd16(Ib+28),2)+SExt(Rd16(Ib+32),2)-1);
     VP^.WrMode:=WM_REPL;
     St:=St And Not OS_SELECTED;
    End;
   End;
  G_USERDEF: Begin
    PrevSt:=St;
    Pb:=PARM_BLK;
    Wr32(Pb,T);Wr16(Pb+4,I);Wr16(Pb+6,St);Wr16(Pb+8,St);
    Wr16(Pb+10,AX);Wr16(Pb+12,AY);Wr16(Pb+14,W);Wr16(Pb+16,H);
    Wr16(Pb+18,ClipX1);Wr16(Pb+20,ClipY1);Wr16(Pb+22,ClipX2-ClipX1+1);Wr16(Pb+24,ClipY2-ClipY1+1);
    Wr32(Pb+26,Rd32(Sp+4));
    Rv:=CallGuest(Rd32(Sp),Pb);
    OSetup;SetClip(ClipX1,ClipY1,ClipX2,ClipY2);
    St:=Rv And $FFFF;
   End;
 End;
 { etats }
 OSetup;SetClip(ClipX1,ClipY1,ClipX2,ClipY2);
 If (St And OS_CROSSED)<>0 Then Begin
  VP^.LineCol:=1;LinePhase:=0;
  VLine(AX,AY,AX+W-1,AY+H-1);VLine(AX,AY+H-1,AX+W-1,AY);
 End;
 If (St And OS_CHECKED)<>0 Then OText(AX+2,AY+(H-16) Div 2,#251,16,1,False);
 If (St And OS_SELECTED)<>0 Then Begin
  VP^.FillInt:=1;VP^.WrMode:=WM_XOR;VP^.FillCol:=1;
  VBar(AX,AY,AX+W-1,AY+H-1);
  VP^.WrMode:=WM_REPL;
 End;
 If (St And OS_DISABLED)<>0 Then Begin
  For YY:=AY To AY+H-1 Do
   For XX:=AX To AX+W-1 Do
    If Odd(XX+YY) Then PlotPat(XX,YY,True,False);
 End;
End;

{ Dessine l'arbre a partir de I jusqu'a la profondeur Depth }
Procedure ObjDrawRec(T: LongInt; I: Integer; Depth: Integer; AX,AY: Integer;
                     CX1_,CY1_,CX2_,CY2_: Integer);
Var C: Integer; Guard: Integer;
Begin
 If (OFlags(T,I) And OF_HIDETREE)<>0 Then Exit;
 ObjDrawOne(T,I,AX,AY,CX1_,CY1_,CX2_,CY2_);
 If Depth>0 Then Begin
  C:=OHead(T,I);Guard:=0;
  If C>=0 Then
   While (C>=0) And (C<>I) And (Guard<2000) Do Begin
    ObjDrawRec(T,C,Depth-1,AX+OX(T,C),AY+OY(T,C),CX1_,CY1_,CX2_,CY2_);
    If C=OTail(T,I) Then Break;
    C:=ONext(T,C);Inc(Guard);
   End;
 End;
End;

Procedure ObjDraw(T: LongInt; Start,Depth: Integer; Cx,Cy,Cw,Ch: Integer);
Var X,Y: Integer; Sv: Integer;
Begin
 ObjOffset(T,Start,X,Y);
 If (Cw<=0) Or (Ch<=0) Then Begin Cx:=0;Cy:=0;Cw:=SW;Ch:=SH;End;
 ObjDrawRec(T,Start,Depth,X,Y,Cx,Cy,Cx+Cw-1,Cy+Ch-1);
 SetClip(0,0,SW-1,SH-1);
End;

{ Recherche de l'objet sous (MXx,MYy) }
Function ObjFindRec(T: LongInt; I,Depth,AX,AY,MXx,MYy: Integer): Integer;
Var C,R,Guard: Integer; Hit: Integer;
Begin
 ObjFindRec:=-1;
 If (OFlags(T,I) And OF_HIDETREE)<>0 Then Exit;
 Hit:=-1;
 If (MXx>=AX) And (MXx<AX+OW(T,I)) And (MYy>=AY) And (MYy<AY+OH(T,I)) Then Hit:=I
 Else If (OState(T,I) And OS_SHADOWED)=0 Then Begin
  If Not ((OType(T,I)=G_IBOX) Or (OType(T,I)=G_BOX)) Then Exit;
 End;
 If Depth>0 Then Begin
  C:=OHead(T,I);Guard:=0;
  While (C>=0) And (C<>I) And (Guard<2000) Do Begin
   R:=ObjFindRec(T,C,Depth-1,AX+OX(T,C),AY+OY(T,C),MXx,MYy);
   If R>=0 Then Hit:=R;
   If C=OTail(T,I) Then Break;
   C:=ONext(T,C);Inc(Guard);
  End;
 End;
 ObjFindRec:=Hit;
End;

Function ObjFind(T: LongInt; Start,Depth: Integer; MXx,MYy: Integer): Integer;
Var X,Y: Integer;
Begin
 ObjOffset(T,Start,X,Y);
 ObjFind:=ObjFindRec(T,Start,Depth,X,Y,MXx,MYy);
End;

{ Redessine un seul objet (pour les changements d'etat) }
Procedure ObjRedraw(T: LongInt; I: Integer);
Var X,Y: Integer;
Begin
 ObjOffset(T,I,X,Y);
 ObjDrawRec(T,I,0,X,Y,X-4,Y-4,X+OW(T,I)+8,Y+OH(T,I)+8);
 SetClip(0,0,SW-1,SH-1);
End;

{ Ajoute / retire / reordonne }
Procedure ObjAdd(T: LongInt; Parent,Child: Integer);
Var Last: Integer;
Begin
 Last:=OTail(T,Parent);
 If OHead(T,Parent)<0 Then Begin
  Wr16(OA(T,Parent)+2,Child);Wr16(OA(T,Parent)+4,Child);
  Wr16(OA(T,Child),Parent);
 End Else Begin
  Wr16(OA(T,Last),Child);
  Wr16(OA(T,Parent)+4,Child);
  Wr16(OA(T,Child),Parent);
 End;
End;

Procedure ObjDelete(T: LongInt; Obj: Integer);
Var P,C,Prev: Integer;
Begin
 P:=OParent(T,Obj);
 If P<0 Then Exit;
 If OHead(T,P)=Obj Then Begin
  If OTail(T,P)=Obj Then Begin
   Wr16(OA(T,P)+2,$FFFF);Wr16(OA(T,P)+4,$FFFF);
  End Else Wr16(OA(T,P)+2,ONext(T,Obj));
 End Else Begin
  Prev:=OHead(T,P);
  While ONext(T,Prev)<>Obj Do Prev:=ONext(T,Prev);
  Wr16(OA(T,Prev),ONext(T,Obj));
  If OTail(T,P)=Obj Then Wr16(OA(T,P)+4,Prev);
 End;
 Wr16(OA(T,Obj),$FFFF);
End;

Procedure ObjOrder(T: LongInt; Obj,Pos: Integer);
Var P,C,N,I,Prev: Integer; Idx: Array[0..63] Of Integer;
Begin
 P:=OParent(T,Obj);
 If P<0 Then Exit;
 ObjDelete(T,Obj);
 N:=0;C:=OHead(T,P);
 While (C>=0) And (C<>P) And (N<62) Do Begin
  Idx[N]:=C;Inc(N);
  If C=OTail(T,P) Then Break;
  C:=ONext(T,C);
 End;
 If (Pos<0) Or (Pos>N) Then Pos:=N;
 { reconstruit la liste des enfants }
 For I:=N Downto Pos+1 Do Idx[I]:=Idx[I-1];
 Idx[Pos]:=Obj;Inc(N);
 Wr16(OA(T,P)+2,Idx[0]);Wr16(OA(T,P)+4,Idx[N-1]);
 For I:=0 To N-2 Do Wr16(OA(T,Idx[I]),Idx[I+1]);
 Wr16(OA(T,Idx[N-1]),P);
End;

{ ---------------------------------------------------------------------- }
{ Edition de champs de texte                                               }
{ ---------------------------------------------------------------------- }

Function ValidChar(V: Char; Ch: Char): Boolean;
Begin
 ValidChar:=False;
 Case V Of
  '9': ValidChar:=(Ch>='0') And (Ch<='9');
  'a': ValidChar:=((Ch>='a') And (Ch<='z')) Or ((Ch>='A') And (Ch<='Z')) Or (Ch=' ');
  'A': ValidChar:=((Ch>='A') And (Ch<='Z')) Or (Ch=' ');
  'n': ValidChar:=((Ch>='a') And (Ch<='z')) Or ((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or (Ch=' ');
  'N': ValidChar:=((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or (Ch=' ');
  'F': ValidChar:=((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or (Ch='?') Or (Ch='*') Or (Ch=':') Or (Ch='.') Or (Ch='_');
  'f': ValidChar:=(Ch>' ') And (Ch<>'\') And (Ch<>'/');
  'P': ValidChar:=((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or (Ch='\') Or (Ch=':') Or (Ch='.') Or (Ch='_') Or (Ch='?') Or (Ch='*');
  'p': ValidChar:=(Ch>=' ');
  'X': ValidChar:=Ch>=' ';
 Else ValidChar:=Ch>=' ';
 End;
End;

{ Position en pixels du curseur d'edition (dans le champ) }
Function EditCursorX(T: LongInt; Obj,Idx: Integer): Integer;
Var Ted: LongInt; Tm: String; I,K: Integer; X,Y: Integer; Just,W,Tw,TX: Integer; S: String;
Begin
 Ted:=OSpec(T,Obj);
 Tm:=RdStr(Rd32(Ted+4),120);
 S:=FtextDisplay(Tm,RdStr(Rd32(Ted),120));
 ObjOffset(T,Obj,X,Y);
 W:=OW(T,Obj);Tw:=Length(S)*8;Just:=Rd16(Ted+16);
 Case Just Of
  1: TX:=X+W-Tw;
  2: TX:=X+(W-Tw) Div 2;
 Else TX:=X;
 End;
 K:=0;
 For I:=1 To Length(Tm) Do Begin
  If Tm[I]='_' Then Begin
   If K=Idx Then Begin EditCursorX:=TX+(I-1)*8;Exit;End;
   Inc(K);
  End;
 End;
 EditCursorX:=TX+Length(Tm)*8;
End;

Procedure EditDrawCursor(T: LongInt; Obj,Idx: Integer);
Var X,Y,CXp: Integer;
Begin
 ObjOffset(T,Obj,X,Y);
 CXp:=EditCursorX(T,Obj,Idx);
 OSetup;SetClip(0,0,SW-1,SH-1);
 VP^.WrMode:=WM_XOR;
 VP^.FillInt:=1;VP^.FillCol:=1;
 VBar(CXp,Y+(OH(T,Obj)-16) Div 2,CXp,Y+(OH(T,Obj)-16) Div 2+15);
 VP^.WrMode:=WM_REPL;
End;

Function EditTextLen(T: LongInt; Obj: Integer): Integer;
Var Ted: LongInt; Tm: String; I,K: Integer;
Begin
 Ted:=OSpec(T,Obj);
 Tm:=RdStr(Rd32(Ted+4),120);K:=0;
 For I:=1 To Length(Tm) Do If Tm[I]='_' Then Inc(K);
 EditTextLen:=K;
End;

{ objc_edit : Kind 0 INIT, 1 CHAR, 2 INIT(pas de curseur), 3 END }
Function ObjEdit(T: LongInt; Obj: Integer; Key: LongInt; Var Idx: Integer; Kind: Integer): Integer;
Var Ted,Txt,Vp: LongInt; S,Vl: String; Mx: Integer; Ch: Char; Scan,Asc: Integer; Ok: Boolean;
Begin
 ObjEdit:=1;
 Ted:=OSpec(T,Obj);
 Txt:=Rd32(Ted);Vp:=Rd32(Ted+8);
 S:=RdStr(Txt,120);Vl:=RdStr(Vp,120);
 Mx:=EditTextLen(T,Obj);
 Case Kind Of
  0,2: Begin
        Idx:=Length(S);
        ObjRedraw(T,Obj);
        If Kind=0 Then EditDrawCursor(T,Obj,Idx);
       End;
  3: Begin ObjRedraw(T,Obj);End;
  1: Begin
      Asc:=Key And $FF;Scan:=(Key Shr 8) And $FF;
      If Idx>Length(S) Then Idx:=Length(S);
      Ok:=False;
      If (Asc=8) Or (Asc=127) Then Begin
       If (Asc=8) And (Idx>0) Then Begin Delete(S,Idx,1);Dec(Idx);Ok:=True;End
       Else If (Asc=127) And (Idx<Length(S)) Then Begin Delete(S,Idx+1,1);Ok:=True;End;
      End Else If (Asc=0) And (Scan=$4B) Then Begin If Idx>0 Then Dec(Idx);Ok:=True;End
      Else If (Asc=0) And (Scan=$4D) Then Begin If Idx<Length(S) Then Inc(Idx);Ok:=True;End
      Else If (Asc=0) And (Scan=$47) Then Begin Idx:=0;Ok:=True;End
      Else If (Asc=0) And (Scan=$4F) Then Begin Idx:=Length(S);Ok:=True;End
      Else If Asc>=32 Then Begin
       Ch:=Chr(Asc);
       If Length(S)<Mx Then Begin
        If Idx<Length(Vl) Then Begin
         If ValidChar(Vl[Idx+1],Ch) Then Begin
          If (Vl[Idx+1]='A') Or (Vl[Idx+1]='N') Then Ch:=UpCase(Ch);
          Insert(Ch,S,Idx+1);Inc(Idx);Ok:=True;
         End;
        End Else If Length(Vl)>0 Then Begin
         If ValidChar(Vl[Length(Vl)],Ch) Then Begin Insert(Ch,S,Idx+1);Inc(Idx);Ok:=True;End;
        End Else Begin Insert(Ch,S,Idx+1);Inc(Idx);Ok:=True;End;
       End;
      End;
      If Ok Then Begin
       WrStr(Txt,S);
       ObjRedraw(T,Obj);
       EditDrawCursor(T,Obj,Idx);
      End Else ObjEdit:=0;
     End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Fichiers ressources (.RSC)                                               }
{ ---------------------------------------------------------------------- }

Var
 RscBase    : LongInt;
 RscSize    : LongInt;
 RscLoaded  : Boolean;

Procedure ObjFix(T: LongInt; I: Integer);
Var A: LongInt; V: Integer;
 Function Fx(V,Cell: Integer): Integer;
 Begin
  Fx:=(V And $FF)*Cell+SExt(ShrL(V,8) And $FF,1);
 End;
Begin
 A:=OA(T,I);
 Wr16(A+16,Fx(Rd16(A+16),8));Wr16(A+18,Fx(Rd16(A+18),16));
 Wr16(A+20,Fx(Rd16(A+20),8));Wr16(A+22,Fx(Rd16(A+22),16));
End;

Function RscLoad(Const Name: String): Boolean;
Var P: Pointer; Len,B,I,J,Nobs,Nted,Nib,Nbb,Nstr,Nimg,Ntree,Oobj,Oted,Oib,Obb,Ofrs,Ofri,Otri: LongInt;
    A: LongInt; Ty: Integer; F: String;
Begin
 RscLoad:=False;
 F:=HostPath(Name);
 If Not ReadFileBytes(F,P,Len) Then Begin
  F:=HostPath(PathOf(ProgName)+ShortName(Name));
  If Not ReadFileBytes(F,P,Len) Then Exit;
 End;
 If Len<36 Then Begin FreeMem(P,Len);Exit;End;
 Oobj:=BufW(P,2);Oted:=BufW(P,4);Oib:=BufW(P,6);Obb:=BufW(P,8);Ofrs:=BufW(P,10);
 Ofri:=BufW(P,16);Otri:=BufW(P,18);
 Nobs:=BufW(P,20);Ntree:=BufW(P,22);Nted:=BufW(P,24);Nib:=BufW(P,26);Nbb:=BufW(P,28);
 Nstr:=BufW(P,30);Nimg:=BufW(P,32);
 RscSize:=BufW(P,34);
 If RscSize<Len Then RscSize:=Len;
 B:=DoMalloc(RscSize+16);
 If B=0 Then Begin FreeMem(P,Len);Exit;End;
 For I:=0 To Len-1 Do Wr8(B+I,BufB(P,I));
 FreeMem(P,Len);
 RscBase:=B;RscLoaded:=True;
 { objets }
 For I:=0 To Nobs-1 Do Begin
  A:=B+Oobj+I*24;
  Ty:=Rd16(A+6) And $FF;
  If (Ty<>G_BOX) And (Ty<>G_IBOX) And (Ty<>G_BOXCHAR) Then Wr32(A+12,Rd32(A+12)+B);
 End;
 For I:=0 To Nted-1 Do Begin
  A:=B+Oted+I*28;
  Wr32(A,Rd32(A)+B);Wr32(A+4,Rd32(A+4)+B);Wr32(A+8,Rd32(A+8)+B);
 End;
 For I:=0 To Nib-1 Do Begin
  A:=B+Oib+I*34;
  Wr32(A,Rd32(A)+B);Wr32(A+4,Rd32(A+4)+B);Wr32(A+8,Rd32(A+8)+B);
 End;
 For I:=0 To Nbb-1 Do Begin
  A:=B+Obb+I*14;
  Wr32(A,Rd32(A)+B);
 End;
 For I:=0 To Nstr-1 Do Wr32(B+Ofrs+I*4,Rd32(B+Ofrs+I*4)+B);
 For I:=0 To Nimg-1 Do Wr32(B+Ofri+I*4,Rd32(B+Ofri+I*4)+B);
 For I:=0 To Ntree-1 Do Wr32(B+Otri+I*4,Rd32(B+Otri+I*4)+B);
 For I:=0 To Nobs-1 Do ObjFix(B+Oobj,I);
 { l'arbre i : l'objet 0 de chaque arbre est dans la table }
 RscLoad:=True;
End;

Function RscGaddr(Ty,Idx: Integer; Var Addr: LongInt): Boolean;
Var B,Oobj,Oted,Oib,Obb,Ofrs,Ofri,Otri: LongInt;
Begin
 RscGaddr:=False;
 If Not RscLoaded Then Exit;
 B:=RscBase;
 Oobj:=Rd16(B+2);Oted:=Rd16(B+4);Oib:=Rd16(B+6);Obb:=Rd16(B+8);Ofrs:=Rd16(B+10);
 Ofri:=Rd16(B+16);Otri:=Rd16(B+18);
 Case Ty Of
  0: If Idx<Rd16(B+22) Then Begin Addr:=Rd32(B+Otri+Idx*4);RscGaddr:=True;End;
  1: If Idx<Rd16(B+20) Then Begin Addr:=B+Oobj+Idx*24;RscGaddr:=True;End;
  2: If Idx<Rd16(B+24) Then Begin Addr:=B+Oted+Idx*28;RscGaddr:=True;End;
  3: If Idx<Rd16(B+26) Then Begin Addr:=B+Oib+Idx*34;RscGaddr:=True;End;
  4: If Idx<Rd16(B+28) Then Begin Addr:=B+Obb+Idx*14;RscGaddr:=True;End;
  5,15: If Idx<Rd16(B+30) Then Begin Addr:=Rd32(B+Ofrs+Idx*4);RscGaddr:=True;End;
  6,16: If Idx<Rd16(B+32) Then Begin Addr:=Rd32(B+Ofri+Idx*4);RscGaddr:=True;End;
 End;
End;

{ ====================================================================== }
{          GEM : AES (Application Environment Services) - ETAT          }
{ ====================================================================== }

Const
 MAXPROC = 8;
 MAXWIN  = 8;
 NAME_=1; CLOSER_=2; FULLER_=4; MOVER_=8; INFO_=16; SIZER_=32; UPARROW_=64;
 DNARROW_=128; VSLIDE_=256; LFARROW_=512; RTARROW_=1024; HSLIDE_=2048;
 WTITLE_H = 19;
 WINFO_H  = 18;
 WSCROLL  = 18;
 MN_SELECTED=10; WM_REDRAW=20; WM_TOPPED=21; WM_CLOSED=22; WM_FULLED=23;
 WM_ARROWED=24; WM_HSLID=25; WM_VSLID=26; WM_SIZED=27; WM_MOVED=28;
 WM_NEWTOP=29; AC_OPEN=40; AC_CLOSE=41;
 STOP_YIELD = 7;

Type
 TRect = Record X,Y,W,H: Integer; End;
 TWin = Record
  Used,Open : Boolean;
  Kind,Owner : Integer;
  Name,Info : LongInt;
  R,Prev,Full : TRect;
  HSl,VSl,HSz,VSz : Integer;
  RectIdx : Integer;
 End;
 TProc = Record
  Used,Blocked,IsAcc,Started,Fresh : Boolean;
  Name : String[9];
  ApId : Integer;
  Rgs  : Array[0..15] Of LongInt;
  PCs,SRs,USPs,SSPs : LongInt;
  BpAddr : LongInt;
  { evenement en attente }
  WFlags,WClicks,WMask,WState : Integer;
  WM1F,WM2F : Integer;
  WM1,WM2 : TRect;
  WDeadline : LongInt;
  WIo,WAi,WCtl : LongInt;
  WOp : Integer;
  Q : Array[1..16,0..7] Of Integer;
  QN : Integer;
  MenuId : Integer;
 End;

Var
 Wins    : Array[0..MAXWIN] Of TWin;
 WZ      : Array[1..MAXWIN] Of Integer;
 NWZ     : Integer;
 Procs   : Array[0..MAXPROC-1] Of TProc;
 CurProc : Integer;
 MainProc: Integer;
 AesActive : Boolean;
 { barre de menus }
 MenuTree   : LongInt;
 MenuOwner  : Integer;
 MenuH      : Integer;
 MenuBar    : Integer;
 AccSlots   : Array[0..5] Of Integer;
 AccProc    : Array[0..5] Of Integer;
 AccStr     : Array[0..5] Of LongInt;
 { bureau }
 DeskTree   : LongInt;
 DeskStart  : Integer;
 { souris et clavier }
 PrevB      : LongInt;
 BtnLastTime,BtnClickCnt : LongInt;
 ClickCount : Integer;
 DClickSpeed: Integer;
 UpdateLevel,MCtrlLevel : Integer;
 MCtrlOwner : Integer;
 ButtonTaken : Boolean;      { le clic courant a ete consomme par le gestionnaire }
 EvtBtnDown  : Boolean;
 KShift      : Integer;
 RectList    : Array[1..64] Of TRect;
 RectN,RectPos : Integer;
 CurShape    : Integer;
 ScrapDir    : String;
 ScrapSet    : Boolean;
 MenuSet     : Array[0..4] Of LongInt;
 AttachN     : Integer;
 AttachTree  : Array[1..16] Of LongInt;
 AttachItem  : Array[1..16] Of Integer;
 AttachSub   : Array[1..16] Of LongInt;
 AttachBox   : Array[1..16] Of Integer;
 AttachSubItem : Array[1..16] Of Integer;
 MenuIStart  : Integer;
 ShelBuf     : Array[0..4095] Of Byte;
 ShelLen     : Integer;
 ShelDefCmd,ShelDefDir : String;
 EnvCacheN   : Integer;
 EnvCacheName: Array[1..16] Of String[40];
 EnvCachePtr : Array[1..16] Of LongInt;
 { enregistrement / lecture d'evenements }
 RecMem,RecCnt,RecPos,RecLast : LongInt;
 PlayMem,PlayCnt,PlayPos,PlayDeadline : LongInt;
 PlayScale   : Integer;
 SynthMouse  : Boolean;
 PlayWait    : Boolean;
 IStartTree : Array[1..16] Of LongInt;
 IStartMenu,IStartItem : Array[1..16] Of Integer;
 IStartN : Integer;
 SynthRel    : Boolean;
 PopSel      : Integer;
 SynthX,SynthY,SynthB : LongInt;
 GemHandle   : Integer;
 ShelNext    : String;
 ShelTail    : String;
 AccNames    : Array[1..6] Of String[40];

Function RectMake(X,Y,W,H: Integer): TRect;
Var R: TRect;
Begin
 R.X:=X;R.Y:=Y;R.W:=W;R.H:=H;
 RectMake:=R;
End;

Function RectInter(A,B: TRect; Var R: TRect): Boolean;
Var X1,Y1,X2,Y2: Integer;
Begin
 X1:=Max2(A.X,B.X);Y1:=Max2(A.Y,B.Y);
 X2:=Min2(A.X+A.W,B.X+B.W);Y2:=Min2(A.Y+A.H,B.Y+B.H);
 R:=RectMake(X1,Y1,X2-X1,Y2-Y1);
 RectInter:=(X2>X1) And (Y2>Y1);
End;

Function InRect(X,Y: Integer; Const R: TRect): Boolean;
Begin
 InRect:=(X>=R.X) And (X<R.X+R.W) And (Y>=R.Y) And (Y<R.Y+R.H);
End;

{ ---------------------------------------------------------------------- }
{ Formes du curseur de la souris                                           }
{ ---------------------------------------------------------------------- }

Const
 CurShapes : Array[0..7,0..15] Of String[16] = (
  { 0 fleche }
  ('X...............','XX..............','XoX.............','XooX............','XoooX...........',
   'XooooX..........','XoooooX.........','XooooooX........','XoooooooX.......','XooooXXXXX......',
   'XooXooX.........','XoX.XooX........','XX..XooX........','X....XooX.......','.....XooX.......',
   '......XX........'),
  { 1 curseur de texte }
  ('................','..XXX.XXX.......','....XoX.........','....XoX.........','....XoX.........',
   '....XoX.........','....XoX.........','....XoX.........','....XoX.........','....XoX.........',
   '....XoX.........','....XoX.........','....XoX.........','..XXX.XXX.......','................',
   '................'),
  { 2 abeille / sablier }
  ('..XXXXXXXXXX....','..XooooooooX....','...XoooooooX....','....XooooooX....','.....XooooX.....',
   '......XooX......','.......XX.......','......XooX......','.....XooooX.....','....XooooooX....',
   '...XoooooooX....','..XooooooooX....','..XXXXXXXXXX....','................','................',
   '................'),
  { 3 main pointant }
  ('.....XX.........','....XooX........','....XooX........','....XooX........','....XooXXX......',
   '....XooXooXXX...','.XX.XooXooXooX..','XooXXooooooooX..','XooooooooooooX..','.XooooooooooooX.',
   '..XoooooooooooX.','..XoooooooooooX.','...XooooooooooX.','...XXooooooooX..','....XXooooooX...',
   '.....XXXXXXXX...'),
  { 4 main plate }
  ('......XX........','..XX.XooXXX.....','.XooXXooXooXX...','.XooXXooXooXooX.','..XooXooXooXooX.',
   '..XooXooXooXooX.','XXXooooooooooooX','XooXooooooooooX.','XooooooooooooX..','.XoooooooooooX..',
   '..XooooooooooX..','..XooooooooooX..','...XooooooooX...','....XooooooX....','....XXXXXXXX....',
   '................'),
  { 5 croix fine }
  ('.......XX.......','.......XX.......','.......XX.......','.......XX.......','.......XX.......',
   '.......XX.......','.......XX.......','XXXXXX.....XXXXX','XXXXXX.....XXXXX','.......XX.......',
   '.......XX.......','.......XX.......','.......XX.......','.......XX.......','.......XX.......',
   '.......XX.......'),
  { 6 croix epaisse }
  ('.......XX.......','.......XX.......','.......XX.......','.......XX.......','.......XX.......',
   '.......XX.......','.......XX.......','XXXXXXXXXXXXXXXX','XXXXXXXXXXXXXXXX','.......XX.......',
   '.......XX.......','.......XX.......','.......XX.......','.......XX.......','.......XX.......',
   '.......XX.......'),
  { 7 croix evidee }
  ('......XooX......','......XooX......','......XooX......','......XooX......','......XooX......',
   '......XooX......','XXXXXXXooXXXXXXX','XooooooooooooooX','XooooooooooooooX','XXXXXXXooXXXXXXX',
   '......XooX......','......XooX......','......XooX......','......XooX......','......XooX......',
   '......XooX......'));
 CurHot : Array[0..7,0..1] Of Byte = ((0,0),(5,7),(7,6),(7,0),(7,0),(7,7),(7,7),(7,7));

Procedure SetMouseShape(N: Integer);
Var Y,X: Integer; M,D: Word; C: Char;
Begin
 If (N<0) Or (N>7) Then N:=0;
 CurShape:=N;
 For Y:=0 To 15 Do Begin
  M:=0;D:=0;
  For X:=0 To 15 Do Begin
   C:=CurShapes[N,Y][X+1];
   If (C='X') Or (C='o') Then M:=M Or ($8000 Shr X);
   If C='X' Then D:=D Or ($8000 Shr X);
  End;
  CurMask[Y]:=M;CurData[Y]:=D;
 End;
 CurHotX:=CurHot[N,0];CurHotY:=CurHot[N,1];
End;

{ ---------------------------------------------------------------------- }
{ Messages                                                                 }
{ ---------------------------------------------------------------------- }

Procedure PostMsg(P: Integer; M0,M3,M4,M5,M6,M7: Integer; Sender: Integer);
Var K: Integer;
Begin
 If (P<0) Or (P>=MAXPROC) Or Not Procs[P].Used Then Exit;
 { fusion des redessins identiques }
 If Procs[P].QN>=16 Then Begin
  For K:=1 To 15 Do Procs[P].Q[K]:=Procs[P].Q[K+1];
  Procs[P].QN:=15;
 End;
 Inc(Procs[P].QN);
 K:=Procs[P].QN;
 Procs[P].Q[K,0]:=M0;Procs[P].Q[K,1]:=Sender;Procs[P].Q[K,2]:=0;
 Procs[P].Q[K,3]:=M3;Procs[P].Q[K,4]:=M4;Procs[P].Q[K,5]:=M5;
 Procs[P].Q[K,6]:=M6;Procs[P].Q[K,7]:=M7;
End;

Function PopMsg(P: Integer; Buf: LongInt): Boolean;
Var K,I: Integer;
Begin
 PopMsg:=False;
 If Procs[P].QN<=0 Then Exit;
 For I:=0 To 7 Do Wr16(Buf+I*2,Procs[P].Q[1,I] And $FFFF);
 For K:=1 To Procs[P].QN-1 Do Procs[P].Q[K]:=Procs[P].Q[K+1];
 Dec(Procs[P].QN);
 PopMsg:=True;
End;

{ ---------------------------------------------------------------------- }
{ Fenetres : geometrie                                                     }
{ ---------------------------------------------------------------------- }

Function HasTitle(K: Integer): Boolean;
Begin
 HasTitle:=(K And (NAME_ Or CLOSER_ Or FULLER_ Or MOVER_))<>0;
End;

Function HasVBar(K: Integer): Boolean;
Begin
 HasVBar:=(K And (UPARROW_ Or DNARROW_ Or VSLIDE_))<>0;
End;

Function HasHBar(K: Integer): Boolean;
Begin
 HasHBar:=(K And (LFARROW_ Or RTARROW_ Or HSLIDE_))<>0;
End;

{ zone de travail depuis la zone exterieure }
Function WorkOf(K: Integer; Const O: TRect): TRect;
Var R: TRect; T: Integer;
Begin
 T:=0;
 If HasTitle(K) Then T:=T+WTITLE_H;
 If (K And INFO_)<>0 Then T:=T+WINFO_H;
 R.X:=O.X+1;R.Y:=O.Y+1+T;
 R.W:=O.W-2;R.H:=O.H-2-T;
 If HasVBar(K) Then R.W:=R.W-WSCROLL;
 If HasHBar(K) Then R.H:=R.H-WSCROLL;
 WorkOf:=R;
End;

Function OuterOf(K: Integer; Const W: TRect): TRect;
Var R: TRect; T: Integer;
Begin
 T:=0;
 If HasTitle(K) Then T:=T+WTITLE_H;
 If (K And INFO_)<>0 Then T:=T+WINFO_H;
 R.X:=W.X-1;R.Y:=W.Y-1-T;
 R.W:=W.W+2;R.H:=W.H+2+T;
 If HasVBar(K) Then R.W:=R.W+WSCROLL;
 If HasHBar(K) Then R.H:=R.H+WSCROLL;
 OuterOf:=R;
End;

Function WinWork(H: Integer): TRect;
Begin
 WinWork:=WorkOf(Wins[H].Kind,Wins[H].R);
End;

Function ZPos(H: Integer): Integer;
Var I: Integer;
Begin
 ZPos:=0;
 For I:=1 To NWZ Do If WZ[I]=H Then Begin ZPos:=I;Exit;End;
End;

Procedure ZRemove(H: Integer);
Var I,P: Integer;
Begin
 P:=ZPos(H);
 If P=0 Then Exit;
 For I:=P To NWZ-1 Do WZ[I]:=WZ[I+1];
 Dec(NWZ);
End;

Procedure ZToTop(H: Integer);
Var I: Integer;
Begin
 ZRemove(H);
 For I:=NWZ Downto 1 Do WZ[I+1]:=WZ[I];
 WZ[1]:=H;Inc(NWZ);
End;

Function TopWin: Integer;
Begin
 If NWZ>0 Then TopWin:=WZ[1] Else TopWin:=0;
End;

{ Liste des rectangles visibles d'une zone de la fenetre H (non masquee par
  les fenetres du dessus) }
Procedure VisibleRects(H: Integer; Const Area: TRect);
Var I,K,Z,Cnt: Integer; Cur: Array[1..64] Of TRect; N,M: Integer; B,A,P: TRect; Tmp: Array[1..64] Of TRect;
 Procedure Add(Const R: TRect);
 Begin
  If (R.W>0) And (R.H>0) And (M<64) Then Begin Inc(M);Tmp[M]:=R;End;
 End;
Begin
 RectN:=0;RectPos:=1;
 Z:=ZPos(H);
 N:=1;Cur[1]:=Area;
 { le bureau (H=0) est sous toutes les fenetres }
 If Z=0 Then Z:=NWZ+1;
 For I:=1 To Z-1 Do Begin
  B:=Wins[WZ[I]].R;
  If Not Wins[WZ[I]].Open Then Continue;
  M:=0;
  For K:=1 To N Do Begin
   A:=Cur[K];
   If Not RectInter(A,B,P) Then Begin Add(A);Continue;End;
   { decoupe A \ B }
   Add(RectMake(A.X,A.Y,A.W,P.Y-A.Y));
   Add(RectMake(A.X,P.Y+P.H,A.W,A.Y+A.H-(P.Y+P.H)));
   Add(RectMake(A.X,P.Y,P.X-A.X,P.H));
   Add(RectMake(P.X+P.W,P.Y,A.X+A.W-(P.X+P.W),P.H));
  End;
  N:=M;
  For K:=1 To N Do Cur[K]:=Tmp[K];
 End;
 For K:=1 To N Do If RectN<64 Then Begin Inc(RectN);RectList[RectN]:=Cur[K];End;
End;

{ ---------------------------------------------------------------------- }
{ Dessin des fenetres                                                      }
{ ---------------------------------------------------------------------- }

Procedure AFill(X1,Y1,X2,Y2: Integer; Pat,Col: Integer);
Begin
 OSetup;OFill(X1,Y1,X2,Y2,Pat,Col);
End;

Procedure ABox(X1,Y1,X2,Y2: Integer);
Begin
 OSetup;OFrameRect(X1,Y1,X2,Y2,1);
End;

Procedure AArrow(X,Y,W,H,Dir: Integer);
Var CXp,CYp,I: Integer;
Begin
 AFill(X,Y,X+W-1,Y+H-1,0,0);ABox(X,Y,X+W-1,Y+H-1);
 CXp:=X+W Div 2;CYp:=Y+H Div 2;
 OSetup;
 For I:=0 To 4 Do Begin
  Case Dir Of
   0: FastSpan(CYp-3+I,CXp-I,CXp+I,True,False);
   1: FastSpan(CYp+3-I,CXp-I,CXp+I,True,False);
   2: Begin VP^.FillInt:=1;VP^.FillCol:=1;VBar(CXp-3+I,CYp-I,CXp-3+I,CYp+I);End;
  Else Begin VP^.FillInt:=1;VP^.FillCol:=1;VBar(CXp+3-I,CYp-I,CXp+3-I,CYp+I);End;
  End;
 End;
End;

Procedure DrawWinFrame(H: Integer);
Var W: ^TWin; R,Wk: TRect; K,X1,Y1,X2,Y2,I,TX,Tw: Integer; S: String; Top: Boolean;
    TrackLen,SlLen,SlPos: Integer;
Begin
 W:=@Wins[H];
 R:=W^.R;K:=W^.Kind;Wk:=WorkOf(K,R);Top:=(TopWin=H);
 OSetup;
 X1:=R.X;Y1:=R.Y;X2:=R.X+R.W-1;Y2:=R.Y+R.H-1;
 ABox(X1,Y1,X2,Y2);
 If HasTitle(K) Then Begin
  AFill(X1+1,Y1+1,X2-1,Y1+WTITLE_H-1,0,0);
  If Top Then Begin
   OSetup;
   For I:=0 To WTITLE_H-4 Do If Odd(I) Then FastSpan(Y1+2+I,X1+2,X2-2,True,False);
  End;
  FastSpan(Y1+WTITLE_H,X1,X2,True,False);
  TX:=X1+1;
  If (K And CLOSER_)<>0 Then Begin
   AFill(X1+1,Y1+1,X1+WSCROLL-1,Y1+WTITLE_H-1,0,0);ABox(X1+1,Y1+1,X1+WSCROLL-1,Y1+WTITLE_H-1);
   ABox(X1+5,Y1+5,X1+WSCROLL-5,Y1+WTITLE_H-5);
   TX:=X1+WSCROLL;
  End;
  Tw:=X2-1;
  If (K And FULLER_)<>0 Then Begin
   AFill(X2-WSCROLL+1,Y1+1,X2-1,Y1+WTITLE_H-1,0,0);ABox(X2-WSCROLL+1,Y1+1,X2-1,Y1+WTITLE_H-1);
   ABox(X2-WSCROLL+5,Y1+5,X2-5,Y1+WTITLE_H-5);
   Tw:=X2-WSCROLL;
  End;
  If W^.Name<>0 Then Begin
   S:=RdStr(W^.Name,80);
   If Length(S)*8+8>Tw-TX Then S:=Copy(S,1,(Tw-TX-8) Div 8);
   I:=TX+(Tw-TX-Length(S)*8) Div 2;
   AFill(I-4,Y1+1,I+Length(S)*8+3,Y1+WTITLE_H-1,0,0);
   OText(I,Y1+(WTITLE_H-8) Div 2+1,S,8,1,False);
  End;
 End;
 If (K And INFO_)<>0 Then Begin
  I:=Y1+1+(Ord(HasTitle(K))*WTITLE_H);
  AFill(X1+1,I,X2-1,I+WINFO_H-2,0,0);
  If W^.Info<>0 Then Begin
   S:=RdStr(W^.Info,100);
   OText(X1+6,I+(WINFO_H-8) Div 2-1,Copy(S,1,(R.W-12) Div 8),8,1,False);
  End;
  FastSpan(I+WINFO_H-1,X1,X2,True,False);
 End;
 { barres de defilement }
 If HasVBar(K) Then Begin
  X1:=Wk.X+Wk.W;
  AFill(X1,Wk.Y,X1+WSCROLL-1,Wk.Y+Wk.H+Ord(HasHBar(K))*WSCROLL-1,0,0);
  OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VBar(X1,Wk.Y,X1,Wk.Y+Wk.H-1+Ord(HasHBar(K))*WSCROLL);
  Y1:=Wk.Y;Y2:=Wk.Y+Wk.H-1;
  If (K And UPARROW_)<>0 Then Begin AArrow(X1+1,Y1,WSCROLL-1,WSCROLL,0);Y1:=Y1+WSCROLL;End;
  If (K And DNARROW_)<>0 Then Begin AArrow(X1+1,Y2-WSCROLL+1,WSCROLL-1,WSCROLL,1);Y2:=Y2-WSCROLL;End;
  If (K And VSLIDE_)<>0 Then Begin
   OSetup;
   For I:=Y1 To Y2 Do FastSpan(I,X1+1,X1+WSCROLL-1,False,False);
   For I:=Y1 To Y2 Do If Odd(I) Then Begin
    FastSpan(I,X1+1,X1+WSCROLL-1,True,False);
    FastSpan(I,X1+1,X1+WSCROLL-1,False,False);
   End;
   For I:=Y1 To Y2 Do Begin
    OSetup;
    VP^.FillInt:=2;VP^.FillSty:=4;VP^.FillCol:=1;VBar(X1+1,I,X1+WSCROLL-1,I);
   End;
   TrackLen:=Y2-Y1+1;
   If W^.VSz<=0 Then SlLen:=TrackLen Else SlLen:=Max2(WSCROLL,TrackLen*W^.VSz Div 1000);
   SlPos:=(TrackLen-SlLen)*Clamp(W^.VSl,0,1000) Div 1000;
   AFill(X1+1,Y1+SlPos,X1+WSCROLL-1,Y1+SlPos+SlLen-1,0,0);
   ABox(X1+1,Y1+SlPos,X1+WSCROLL-1,Y1+SlPos+SlLen-1);
  End;
 End;
 If HasHBar(K) Then Begin
  Y1:=Wk.Y+Wk.H;
  AFill(Wk.X,Y1,Wk.X+Wk.W-1,Y1+WSCROLL-1,0,0);
  OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VBar(Wk.X,Y1,Wk.X+Wk.W-1,Y1);
  X1:=Wk.X;X2:=Wk.X+Wk.W-1;
  If (K And LFARROW_)<>0 Then Begin AArrow(X1,Y1+1,WSCROLL,WSCROLL-1,2);X1:=X1+WSCROLL;End;
  If (K And RTARROW_)<>0 Then Begin AArrow(X2-WSCROLL+1,Y1+1,WSCROLL,WSCROLL-1,3);X2:=X2-WSCROLL;End;
  If (K And HSLIDE_)<>0 Then Begin
   OSetup;
   For I:=X1 To X2 Do Begin
    VP^.FillInt:=2;VP^.FillSty:=4;VP^.FillCol:=1;VBar(I,Y1+1,I,Y1+WSCROLL-1);
   End;
   TrackLen:=X2-X1+1;
   If W^.HSz<=0 Then SlLen:=TrackLen Else SlLen:=Max2(WSCROLL,TrackLen*W^.HSz Div 1000);
   SlPos:=(TrackLen-SlLen)*Clamp(W^.HSl,0,1000) Div 1000;
   AFill(X1+SlPos,Y1+1,X1+SlPos+SlLen-1,Y1+WSCROLL-1,0,0);
   ABox(X1+SlPos,Y1+1,X1+SlPos+SlLen-1,Y1+WSCROLL-1);
  End;
 End;
 If ((K And SIZER_)<>0) Then Begin
  X1:=Wk.X+Wk.W;Y1:=Wk.Y+Wk.H;
  If HasVBar(K) And HasHBar(K) Then Begin
   AFill(X1,Y1,X1+WSCROLL-1,Y1+WSCROLL-1,0,0);ABox(X1,Y1,X1+WSCROLL-1,Y1+WSCROLL-1);
   ABox(X1+4,Y1+4,X1+WSCROLL-4,Y1+WSCROLL-4);
  End;
 End;
End;

{ Fond du bureau }
Procedure DrawDesktopRect(X1,Y1,X2,Y2: Integer);
Var X,Y: Integer;
Begin
 OSetup;
 SetClip(X1,Y1,X2,Y2);
 If DeskTree<>0 Then Begin
  ObjDrawRec(DeskTree,DeskStart,8,OX(DeskTree,DeskStart),OY(DeskTree,DeskStart),X1,Y1,X2,Y2);
  OSetup;
 End Else Begin
  For Y:=Y1 To Y2 Do
   For X:=X1 To X2 Do BPix(X,Y,Odd(X+Y) Or (Not Odd(X+Y) And False));
 End;
 SetClip(0,0,SW-1,SH-1);
End;

Procedure DrawMenuBarNow; Forward;

{ Redessine une zone : bureau, cadres des fenetres, barre de menus.
  SendRedraw : avertit les applications (contenu des fenetres) }
Procedure Repaint(R: TRect; SendRedraw: Boolean);
Var I,H: Integer; A,P: TRect; Wk: TRect;
Begin
 If Not RectInter(R,RectMake(0,0,SW,SH),A) Then Exit;
 If A.Y<MenuH Then Begin
  DrawMenuBarNow;
  If A.Y+A.H<=MenuH Then Begin SetClip(0,0,SW-1,SH-1);Exit;End;
  A.H:=A.H-(MenuH-A.Y);A.Y:=MenuH;
 End;
 DrawDesktopRect(A.X,A.Y,A.X+A.W-1,A.Y+A.H-1);
 For I:=NWZ Downto 1 Do Begin
  H:=WZ[I];
  If Not Wins[H].Open Then Continue;
  If RectInter(A,Wins[H].R,P) Then Begin
   OSetup;SetClip(P.X,P.Y,P.X+P.W-1,P.Y+P.H-1);
   { efface le cadre sous la zone de travail ? non : la zone de travail est
     redessinee par l'application (WM_REDRAW) apres un fond blanc }
   DrawWinFrame(H);
   Wk:=WinWork(H);
   If RectInter(P,Wk,Wk) Then Begin
    If SendRedraw Then Begin
     OSetup;SetClip(P.X,P.Y,P.X+P.W-1,P.Y+P.H-1);
     OFill(Wk.X,Wk.Y,Wk.X+Wk.W-1,Wk.Y+Wk.H-1,0,0);
     PostMsg(Wins[H].Owner,WM_REDRAW,H,Wk.X,Wk.Y,Wk.W,Wk.H,0);
    End;
   End;
  End;
 End;
 SetClip(0,0,SW-1,SH-1);
End;

Procedure RepaintAll;
Begin
 Repaint(RectMake(0,0,SW,SH),True);
End;

{ ====================================================================== }
{          GEM : AES - ENTREES, MENUS, FENETRES, FORMULAIRES             }
{ ====================================================================== }

Var
 ModalLevel : Integer;
 NoBlit     : Boolean;

{ Appel d'une routine utilisateur (vex_*, mousevec) dans le contexte invite }
Procedure VexCall(Addr,D0,D1: LongInt; Var O0,O1: LongInt);
Var R: LongInt;
Begin
 O0:=D0;O1:=D1;
 If InVex Or (Addr=0) Or (Addr=STUB_RTS) Or BatchMode Then Exit;
 InVex:=True;
 R:=CallGuestEx(Addr,0,D0,D1,0,O0,O1);
 InVex:=False;
End;

{ Enregistrement d'evenements (appl_trecord) : 0 minuterie, 1 bouton, 2 souris, 3 clavier }
Procedure RecEvent(Kind: Integer; Data: LongInt);
Var T: LongInt;
 Procedure Put(K: LongInt; V: LongInt);
 Begin
  If RecPos<RecCnt Then Begin
   Wr32(RecMem+RecPos*8,K);Wr32(RecMem+RecPos*8+4,V);Inc(RecPos);
  End;
 End;
Begin
 If (RecMem=0) Or (RecPos>=RecCnt) Then Begin RecActive:=False;Exit;End;
 T:=MsNow;
 If T-RecLast>=10 Then Begin Put(0,T-RecLast);RecLast:=T;End;
 Put(Kind,Data);
 If RecPos>=RecCnt Then RecActive:=False;
End;

{ Lecture d'evenements (appl_tplay) }
Procedure PlayStep;
Var K,V: LongInt;
Begin
 If PlayMem=0 Then Exit;
 While PlayPos<PlayCnt Do Begin
  K:=Rd32(PlayMem+PlayPos*8);V:=Rd32(PlayMem+PlayPos*8+4);
  Case K Of
   0: Begin
       If BatchMode Then Begin Inc(PlayPos);Continue;End;
       If Not PlayWait Then Begin
        PlayDeadline:=MsNow+(V*100) Div Max2(PlayScale,1);PlayWait:=True;
       End;
       If MsNow-PlayDeadline>=0 Then Begin PlayWait:=False;Inc(PlayPos);Continue;End;
       Exit;
      End;
   1: Begin
       SynthB:=V And 3;Inc(PlayPos);
      End;
   2: Begin
       SynthX:=Clamp(SExt((V Shr 16) And $FFFF,2),0,SW-1);
       SynthY:=Clamp(SExt(V And $FFFF,2),0,SH-1);
       Inc(PlayPos);
      End;
   3: Begin
       KQPush((((V Shr 8) And $FF) Shl 16) Or (V And $FF));
       Inc(PlayPos);
      End;
  Else Inc(PlayPos);
  End;
 End;
 { fin : la souris synthetique est liberee apres la prise en compte du dernier etat }
 SynthRel:=SynthMouse;PlayMem:=0;
End;

{ Lit clavier et souris hotes ; met a jour l'etat GEM }
Procedure PollInput;
Var NX,NY,NB,T,O0,O1: LongInt; Moved,BtnChg: Boolean; Bt,Dx,Dy: LongInt;
Begin
 PollKeys;
 PlayStep;
 If BatchMode Or Not GfxOn Then Exit;
 If SynthMouse Then Begin
  NX:=SynthX;NY:=SynthY+EMU_Y0;NB:=SynthB;
  If SynthRel Then Begin SynthMouse:=False;SynthRel:=False;End;
 End
 Else GetMouseState(NX,NY,NB);
 MX:=NX;MY:=NY;MB:=NB;
 {$IFDEF FPC}
 If CurShown And ((MX<>CurMX) Or (MY<>CurMY)) Then CursorDraw(MX,MY);
 {$ENDIF}
 GMouseX:=Clamp(NX,0,SW-1);GMouseY:=Clamp(NY-EMU_Y0,0,SH-1);
 GMouseB:=NB And 3;
 Moved:=(GMouseX<>KbdPrevX) Or (GMouseY<>KbdPrevY);
 BtnChg:=GMouseB<>KbdPrevB;
 If BtnChg Then Begin
  { routine vex_butv }
  VexCall(VexBut,GMouseB,0,O0,O1);
 End;
 If Moved Then Begin
  { routine vex_motv : peut modifier la position }
  VexCall(VexMot,GMouseX,GMouseY,O0,O1);
  If (O0<>GMouseX) Or (O1<>GMouseY) Then Begin
   GMouseX:=Clamp(SExt(O0 And $FFFF,2),0,SW-1);GMouseY:=Clamp(SExt(O1 And $FFFF,2),0,SH-1);
  End;
  If UserCursor Then VexCall(VexCur,GMouseX,GMouseY,O0,O1);
 End;
 { paquet du vecteur souris du clavier intelligent (Initmous) }
 If (Moved Or BtnChg) And (MouseVecUser<>0) And Not InVex Then Begin
  Bt:=((GMouseB And 1) Shl 1) Or ((GMouseB And 2) Shr 1);
  Dx:=Clamp(GMouseX-KbdPrevX,-128,127);Dy:=Clamp(GMouseY-KbdPrevY,-128,127);
  Wr8(MOUSE_PKT,$F8 Or Bt);Wr8(MOUSE_PKT+1,Dx And $FF);Wr8(MOUSE_PKT+2,Dy And $FF);
  InVex:=True;
  CallGuestEx(MouseVecUser,0,0,0,MOUSE_PKT,O0,O1);
  InVex:=False;
 End;
 { appl_trecord }
 If RecActive Then Begin
  If BtnChg Then RecEvent(1,GMouseB Or (LongInt(Max2(1,ClickCount)) Shl 16));
  If Moved Then RecEvent(2,((GMouseX And $FFFF) Shl 16) Or (GMouseY And $FFFF));
 End;
 KbdPrevX:=GMouseX;KbdPrevY:=GMouseY;KbdPrevB:=GMouseB;
 { minuterie utilisateur vex_timv : 50 Hz }
 T:=MsNow;
 If (VexTim<>STUB_RTS) And (VexTim<>0) And (T-VexTimLast>=20) Then Begin
  VexTimLast:=T;
  VexCall(VexTim,0,0,O0,O1);
 End;
 If (GMouseB And 1)<>0 Then Begin
  If (PrevB And 1)=0 Then Begin
   T:=MsNow;
   If (T-BtnLastTime>=0) And (T-BtnLastTime<LongInt(DClickSpeed)*80) Then Inc(ClickCount)
   Else ClickCount:=1;
   BtnLastTime:=T;
  End;
 End;
 PrevB:=GMouseB;
End;

Procedure GemIdle;
Begin
 PollInput;
 If Not BatchMode Then Begin
  If Not NoBlit Then BlitScreen(False);
  Delay(1);
 End;
End;

Procedure WaitButtonRelease;
Begin
 Repeat GemIdle;Until ((GMouseB And 3)=0) Or UserBreak;
End;

Procedure SyncSysVars;
Var T: LongInt;
Begin
 T:=MsNow Div 5;
 Wr32($4BA,T);Wr32($462,T Div 4);
End;

{ ---------------------------------------------------------------------- }
{ Barre de menus                                                            }
{ ---------------------------------------------------------------------- }

Procedure DrawMenuBarNow;
Var Sv: Integer;
Begin
 OSetup;SetClip(0,0,SW-1,MenuH);
 OFill(0,0,SW-1,MenuH-1,0,0);
 FastSpan(MenuH-1,0,SW-1,True,False);
 If MenuTree<>0 Then Begin
  ObjDrawRec(MenuTree,MenuBar,4,OX(MenuTree,MenuBar)+OX(MenuTree,0),OY(MenuTree,MenuBar)+OY(MenuTree,0),
             0,0,SW-1,MenuH-1);
  OSetup;FastSpan(MenuH-1,0,SW-1,True,False);
 End;
 SetClip(0,0,SW-1,SH-1);
End;

Function TitleIndexOf(T: LongInt; Title: Integer): Integer;
Var P,C,K: Integer;
Begin
 P:=OParent(T,Title);K:=0;C:=OHead(T,P);
 While C>=0 Do Begin
  If C=Title Then Begin TitleIndexOf:=K;Exit;End;
  Inc(K);
  If C=OTail(T,P) Then Break;
  C:=ONext(T,C);
 End;
 TitleIndexOf:=0;
End;

Function NthChild(T: LongInt; Parent,N: Integer): Integer;
Var C,K: Integer;
Begin
 NthChild:=-1;
 C:=OHead(T,Parent);K:=0;
 While C>=0 Do Begin
  If K=N Then Begin NthChild:=C;Exit;End;
  Inc(K);
  If C=OTail(T,Parent) Then Break;
  C:=ONext(T,C);
 End;
End;

Function ItemSelectable(T: LongInt; I: Integer): Boolean;
Var S: String;
Begin
 ItemSelectable:=False;
 If OType(T,I)<>G_STRING Then Exit;
 If (OState(T,I) And OS_DISABLED)<>0 Then Exit;
 S:=RdStr(OSpec(T,I),4);
 If (S<>'') And (S[1]='-') Then Exit;
 If TrimS(S)='' Then Exit;
 ItemSelectable:=True;
End;

{ Cherche l'index d'accessoire correspondant a un element du menu Desk }
Function AccOfItem(Item: Integer; Var Slot: Integer): Integer;
Var K: Integer;
Begin
 AccOfItem:=-1;
 For K:=0 To 5 Do
  If AccSlots[K]=Item Then Begin Slot:=K;AccOfItem:=K;Exit;End;
End;

Function MouseOnTitle: Boolean;
Var I: Integer;
Begin
 MouseOnTitle:=False;
 If (MenuTree=0) Or (GMouseY>=MenuH) Then Exit;
 I:=ObjFind(MenuTree,MenuBar,4,GMouseX,GMouseY);
 MouseOnTitle:=(I>=0) And (OType(MenuTree,I)=G_TITLE);
End;

{ ---------------------------------------------------------------------- }
{ Menus deroulants independants (menu_popup) et sous-menus attaches         }
{ ---------------------------------------------------------------------- }

Var
 PopTree,PopMenuIdx : LongInt;

Function FindAttach(T: LongInt; Item: Integer): Integer;
Var K: Integer;
Begin
 FindAttach:=0;
 For K:=1 To AttachN Do
  If (AttachTree[K]=T) And (AttachItem[K]=Item) Then Begin FindAttach:=K;Exit;End;
End;

Function PopItemFromPoint(T: LongInt; Menu,PX,PY: Integer): Integer;
Var I: Integer;
Begin
 I:=ObjFind(T,Menu,1,PX,PY);
 If (I<=0) Or (I=Menu) Or Not ItemSelectable(T,I) Then I:=-1;
 PopItemFromPoint:=I;
End;

{ Affiche le menu Menu de l'arbre T en (X,Y) ; True si un element est choisi.
  Hover : la souris sortant du menu l'annule (sous-menus de la barre) }
Function PopupMenu(T: LongInt; Menu,X0,Y0: Integer; Var Item: Integer; Hover: Boolean): Boolean;
Var Sv: TScrSave; BoxR: TRect; W,H,X,Y,Ax,Ay,OldX,OldY,Cur,I,K,Sc: Integer;
    Done,Sel,WasDown,Pressed,Opened,SubDone: Boolean; Kq: LongInt; HoverT: LongInt; SubItem: Integer;
    ItY,LMx,LMy: Integer;
 Procedure Light(I: Integer; On_: Boolean);
 Begin
  If I<0 Then Exit;
  If On_ Then SetOState(T,I,OState(T,I) Or OS_SELECTED)
  Else SetOState(T,I,OState(T,I) And Not OS_SELECTED);
  ObjRedraw(T,I);
 End;
 Procedure Nav(Dir: Integer);
 Var L: Array[0..63] Of Integer; N,P,C: Integer;
 Begin
  N:=0;P:=-1;C:=OHead(T,Menu);
  While (C>=0) And (N<64) Do Begin
   If ItemSelectable(T,C) Then Begin
    If C=Cur Then P:=N;
    L[N]:=C;Inc(N);
   End;
   If C=OTail(T,Menu) Then Break;
   C:=ONext(T,C);
  End;
  If N=0 Then Exit;
  If P<0 Then Begin If Dir>0 Then P:=0 Else P:=N-1;End
  Else P:=(P+Dir+N) Mod N;
  Light(Cur,False);Cur:=L[P];Light(Cur,True);HoverT:=MsNow;
 End;
Begin
 PopupMenu:=False;PopSel:=-1;SubDone:=False;LMx:=-1;LMy:=-1;PopTree:=T;PopMenuIdx:=Menu;
 W:=OW(T,Menu);H:=OH(T,Menu);
 X:=Clamp(X0,0,Max2(0,SW-W-4));Y:=Clamp(Y0,MenuH,Max2(MenuH,SH-H-4));
 OldX:=SExt(Rd16(OA(T,Menu)+16),2);OldY:=SExt(Rd16(OA(T,Menu)+18),2);
 ObjOffset(T,Menu,Ax,Ay);
 Wr16(OA(T,Menu)+16,(OldX+X-Ax) And $FFFF);Wr16(OA(T,Menu)+18,(OldY+Y-Ay) And $FFFF);
 BoxR:=RectMake(X,Y,W,H);
 ScrSave(X-2,Y-2,X+W+4,Y+H+4,Sv);
 ObjDrawRec(T,Menu,8,X,Y,X-2,Y-2,X+W+4,Y+H+4);
 OSetup;OFrameRect(X,Y,X+W-1,Y+H-1,1);
 OFill(X+3,Y+H,X+W+2,Y+H+2,7,1);
 OFill(X+W,Y+3,X+W+2,Y+H-1,7,1);
 SetClip(0,0,SW-1,SH-1);
 Cur:=-1;Done:=False;Sel:=False;WasDown:=(GMouseB And 1)<>0;Opened:=False;HoverT:=MsNow;
 If Item>0 Then Begin Cur:=Item;Light(Cur,True);End;
 Repeat
  PollInput;
  I:=-1;
  If InRect(GMouseX,GMouseY,BoxR) Then Begin
   I:=PopItemFromPoint(T,Menu,GMouseX,GMouseY);
   Opened:=True;
  End Else If Hover And Opened Then Done:=True;
  If (GMouseX<>LMx) Or (GMouseY<>LMy) Then Begin
   LMx:=GMouseX;LMy:=GMouseY;
   If (I<>Cur) And ((I>=0) Or Not Hover) Then Begin
    Light(Cur,False);Cur:=I;Light(Cur,True);HoverT:=MsNow;
   End;
  End;
  { clavier }
  While Not KQEmpty Do Begin
   Kq:=KQPop;Sc:=(Kq Shr 16) And $FF;
   Case Sc Of
    1: Begin Done:=True;Sel:=False;Cur:=-1;End;
    28,114: If Cur>=0 Then Begin Sel:=True;Done:=True;End;
    72: Nav(-1);
    80: Nav(1);
   End;
  End;
  Pressed:=(GMouseB And 1)<>0;
  If Cur>=0 Then Begin
   If (Pressed And Not WasDown) Or ((Not Pressed) And WasDown And InRect(GMouseX,GMouseY,BoxR) And
      (Not Hover Or (MsNow-HoverT>150))) Then Begin Sel:=True;Done:=True;End;
  End;
  { sous-menu attache a l'element }
  If (Not Done) And (Cur>=0) Then Begin
   K:=FindAttach(T,Cur);
   If (K>0) And ((MsNow-HoverT>=MenuSet[0]) Or (Pressed And Not WasDown)) Then Begin
    ObjOffset(T,Cur,Ax,ItY);
    SubItem:=AttachSubItem[K];
    If PopupMenu(AttachSub[K],AttachBox[K],X+W-3,ItY,SubItem,True) Then Begin
     Sel:=True;Done:=True;SubDone:=True;
    End Else HoverT:=MsNow;
    Pressed:=(GMouseB And 1)<>0;
   End;
  End;
  If Done And Sel And Not SubDone And (Cur>=0) And (FindAttach(T,Cur)>0) Then Begin Done:=False;Sel:=False;End;
  If (Not Hover) And (Pressed And Not WasDown) And Not InRect(GMouseX,GMouseY,BoxR) Then Begin Done:=True;Sel:=False;End;
  WasDown:=Pressed;
  If Not NoBlit Then BlitScreen(False);
  If Not Done Then Delay(1);
 Until Done Or UserBreak;
 If Cur>=0 Then SetOState(T,Cur,OState(T,Cur) And Not OS_SELECTED);
 ScrRestore(Sv);
 Wr16(OA(T,Menu)+16,OldX And $FFFF);Wr16(OA(T,Menu)+18,OldY And $FFFF);
 If Sel And (Cur>=0) Then Begin
  If Not SubDone Then Begin PopTree:=T;PopSel:=Cur;PopMenuIdx:=Menu;End;
  Item:=PopSel;PopupMenu:=True;
 End Else Begin Item:=-1;End;
 If Sel Then Begin While ((GMouseB And 1)<>0) And Not UserBreak Do GemIdle;End;
End;

Procedure MenuTrack;
Var Active,Box,Item,T,I,Screen,Prev: Integer; Sv: TScrSave; Saved,Done,Selected,InBar,InBox,WasDown,SubSel: Boolean;
    HoverItem,SubItem,Ak,Ix,Iy: Integer; HoverT: LongInt;
    BoxR: TRect; MXp,MYp: Integer; X,Y: Integer; Target: Integer; Slot,Ac: Integer;
 Procedure CloseBox;
 Begin
  If Saved Then Begin ScrRestore(Sv);Saved:=False;End;
  If Item>=0 Then Begin SetOState(MenuTree,Item,OState(MenuTree,Item) And Not OS_SELECTED);Item:=-1;End;
 End;
 Procedure OpenBox(Tt: Integer);
 Var K: Integer; Bx: Integer;
 Begin
  Active:=Tt;
  SetOState(MenuTree,Tt,OState(MenuTree,Tt) Or OS_SELECTED);
  ObjRedraw(MenuTree,Tt);
  Screen:=ONext(MenuTree,MenuBar);
  K:=TitleIndexOf(MenuTree,Tt);
  Box:=NthChild(MenuTree,Screen,K);
  If Box>=0 Then Begin
   ObjOffset(MenuTree,Box,X,Y);
   BoxR:=RectMake(X,Y,OW(MenuTree,Box),OH(MenuTree,Box));
   ScrSave(X-2,Y-2,X+BoxR.W+4,Y+BoxR.H+4,Sv);Saved:=True;
   ObjDrawRec(MenuTree,Box,8,X,Y,X-2,Y-2,X+BoxR.W+4,Y+BoxR.H+4);
   OSetup;OFrameRect(X,Y,X+BoxR.W-1,Y+BoxR.H-1,1);
   OFill(X+3,Y+BoxR.H,X+BoxR.W+2,Y+BoxR.H+2,7,1);
   OFill(X+BoxR.W,Y+3,X+BoxR.W+2,Y+BoxR.H-1,7,1);
   SetClip(0,0,SW-1,SH-1);
  End;
 End;
Begin
 If MenuTree=0 Then Exit;
 Active:=-1;Box:=-1;Item:=-1;Saved:=False;Done:=False;Selected:=False;SubSel:=False;HoverItem:=-1;HoverT:=MsNow;
 WasDown:=(GMouseB And 1)<>0;
 Repeat
  PollInput;
  MXp:=GMouseX;MYp:=GMouseY;
  InBar:=MYp<MenuH;
  T:=-1;
  If InBar Then Begin
   I:=ObjFind(MenuTree,MenuBar,4,MXp,MYp);
   If (I>=0) And (OType(MenuTree,I)=G_TITLE) Then T:=I;
  End;
  If (T>=0) And (T<>Active) Then Begin
   If Active>=0 Then Begin
    CloseBox;
    SetOState(MenuTree,Active,OState(MenuTree,Active) And Not OS_SELECTED);
    ObjRedraw(MenuTree,Active);
   End;
   OpenBox(T);
  End;
  InBox:=False;Prev:=Item;
  If (Active>=0) And (Box>=0) Then Begin
   InBox:=InRect(MXp,MYp,BoxR);
   If InBox Then Begin
    I:=ObjFind(MenuTree,Box,1,MXp,MYp);
    If (I<=0) Or (I=Box) Or Not ItemSelectable(MenuTree,I) Then I:=-1;
   End Else I:=-1;
   If I<>Item Then Begin
    If Item>=0 Then Begin
     SetOState(MenuTree,Item,OState(MenuTree,Item) And Not OS_SELECTED);ObjRedraw(MenuTree,Item);
    End;
    Item:=I;
    If Item>=0 Then Begin
     SetOState(MenuTree,Item,OState(MenuTree,Item) Or OS_SELECTED);ObjRedraw(MenuTree,Item);
    End;
   End;
  End;
  If Item<>HoverItem Then Begin HoverItem:=Item;HoverT:=MsNow;End;
  If (Item>=0) And (AttachN>0) Then Begin
   Ak:=FindAttach(MenuTree,Item);
   If (Ak>0) And ((MsNow-HoverT>=MenuSet[0]) Or (((GMouseB And 1)<>0) And Not WasDown)) Then Begin
    ObjOffset(MenuTree,Item,Ix,Iy);
    SubItem:=AttachSubItem[Ak];
    If PopupMenu(AttachSub[Ak],AttachBox[Ak],BoxR.X+BoxR.W-3,Iy,SubItem,True) Then Begin
     SubSel:=True;Selected:=True;Done:=True;
    End Else Begin HoverT:=MsNow;WasDown:=(GMouseB And 1)<>0;End;
   End;
  End;
  If (Item>=0) And Not Done And (AttachN>0) And (FindAttach(MenuTree,Item)>0) Then Begin End
  Else If Item>=0 Then Begin
   If ((GMouseB And 1)<>0) And Not WasDown Then Begin Selected:=True;Done:=True;End;
   If ((GMouseB And 1)=0) And WasDown Then Begin Selected:=True;Done:=True;End;
  End;
  WasDown:=(GMouseB And 1)<>0;
  If (Not InBar) And (Not InBox) Then Done:=True;
  If (Active<0) And (Not InBar Or (T<0)) Then Done:=True;
  If Not NoBlit Then BlitScreen(False);
  If Not Done Then Delay(1);
 Until Done Or UserBreak;
 Target:=Item;
 If Saved Then Begin ScrRestore(Sv);Saved:=False;End;
 If Selected And (Item>=0) Then Begin
  { le menu Desk : elements d'accessoires }
  Ac:=-1;
  If TitleIndexOf(MenuTree,Active)=0 Then Ac:=AccOfItem(Item,Slot);
  SetOState(MenuTree,Item,OState(MenuTree,Item) And Not OS_SELECTED);
  If Ac>=0 Then Begin
   SetOState(MenuTree,Active,OState(MenuTree,Active) And Not OS_SELECTED);
   ObjRedraw(MenuTree,Active);
   PostMsg(AccProc[Ac],AC_OPEN,0,Procs[AccProc[Ac]].MenuId,0,0,0,0);
  End Else
   If SubSel Then PostMsg(MenuOwner,MN_SELECTED,Active,PopSel,PopTree Shr 16,PopTree And $FFFF,PopMenuIdx,0)
   Else PostMsg(MenuOwner,MN_SELECTED,Active,Item,MenuTree Shr 16,MenuTree And $FFFF,Box,0);
  ButtonTaken:=True;
 End Else If Active>=0 Then Begin
  SetOState(MenuTree,Active,OState(MenuTree,Active) And Not OS_SELECTED);
  ObjRedraw(MenuTree,Active);
 End;
 If Item>=0 Then Begin End;
 SetClip(0,0,SW-1,SH-1);
 DrawMenuBarNow;
End;

{ ---------------------------------------------------------------------- }
{ Rectangles elastiques et deplacements                                    }
{ ---------------------------------------------------------------------- }

Procedure XorFrame(X,Y,W,H: Integer);
Begin
 OSetup;SetClip(0,0,SW-1,SH-1);
 VP^.WrMode:=WM_XOR;VP^.FillInt:=1;VP^.FillCol:=1;
 If (W<2) Or (H<2) Then Exit;
 VBar(X,Y,X+W-1,Y);VBar(X,Y+H-1,X+W-1,Y+H-1);
 If H>2 Then Begin VBar(X,Y+1,X,Y+H-2);VBar(X+W-1,Y+1,X+W-1,Y+H-2);End;
 VP^.WrMode:=WM_REPL;
End;

{ Deplace un rectangle jusqu'au relachement du bouton }
Procedure DragBox(W,H,SX,SY: Integer; Const Bound: TRect; Var RX,RY: Integer);
Var OXx,OYy,NXx,NYy,DX,DY: Integer; Drawn: Boolean;
Begin
 DX:=GMouseX-SX;DY:=GMouseY-SY;
 OXx:=SX;OYy:=SY;
 XorFrame(OXx,OYy,W,H);Drawn:=True;
 While ((GMouseB And 1)<>0) And Not UserBreak Do Begin
  GemIdle;
  NXx:=Clamp(GMouseX-DX,Bound.X,Max2(Bound.X,Bound.X+Bound.W-W));
  NYy:=Clamp(GMouseY-DY,Bound.Y,Max2(Bound.Y,Bound.Y+Bound.H-H));
  If (NXx<>OXx) Or (NYy<>OYy) Then Begin
   XorFrame(OXx,OYy,W,H);
   OXx:=NXx;OYy:=NYy;
   XorFrame(OXx,OYy,W,H);
  End;
 End;
 XorFrame(OXx,OYy,W,H);
 RX:=OXx;RY:=OYy;
End;

Procedure RubberBox(X,Y,MinW,MinH: Integer; Var RW,RH: Integer);
Var NW,NH,OW_,OH_: Integer;
Begin
 OW_:=Max2(MinW,1);OH_:=Max2(MinH,1);
 XorFrame(X,Y,OW_,OH_);
 While ((GMouseB And 1)<>0) And Not UserBreak Do Begin
  GemIdle;
  NW:=Max2(MinW,GMouseX-X+1);NH:=Max2(MinH,GMouseY-Y+1);
  If (NW<>OW_) Or (NH<>OH_) Then Begin
   XorFrame(X,Y,OW_,OH_);OW_:=NW;OH_:=NH;XorFrame(X,Y,OW_,OH_);
  End;
 End;
 XorFrame(X,Y,OW_,OH_);
 RW:=OW_;RH:=OH_;
End;

Procedure GrowShrink(Const A,B: TRect);
Var I: Integer; R: TRect;
Begin
 For I:=1 To 6 Do Begin
  R.X:=A.X+(B.X-A.X)*I Div 6;R.Y:=A.Y+(B.Y-A.Y)*I Div 6;
  R.W:=A.W+(B.W-A.W)*I Div 6;R.H:=A.H+(B.H-A.H)*I Div 6;
  XorFrame(R.X,R.Y,R.W,R.H);
  If Not BatchMode Then Begin BlitScreen(False);Delay(8);End;
  XorFrame(R.X,R.Y,R.W,R.H);
 End;
 If Not BatchMode Then BlitScreen(False);
End;

{ Surveille un objet pendant que le bouton est enfonce }
Function WatchBox(T: LongInt; Obj,InSt,OutSt: Integer): Boolean;
Var Inside,Was: Boolean; X,Y: Integer;
Begin
 ObjOffset(T,Obj,X,Y);
 Was:=True;
 SetOState(T,Obj,InSt);ObjRedraw(T,Obj);
 While ((GMouseB And 1)<>0) And Not UserBreak Do Begin
  GemIdle;
  Inside:=InRect(GMouseX,GMouseY,RectMake(X,Y,OW(T,Obj),OH(T,Obj)));
  If Inside<>Was Then Begin
   If Inside Then SetOState(T,Obj,InSt) Else SetOState(T,Obj,OutSt);
   ObjRedraw(T,Obj);
   Was:=Inside;
  End;
 End;
 WatchBox:=Was;
End;

{ Deplace le curseur d'un ascenseur (graf_slidebox) : renvoie 0..1000 }
Function SlideBox(T: LongInt; Par,Obj,Vh: Integer): Integer;
Var Px,Py,Ox,Oy,Pw,Ph,Ow_,Oh_,Gx,Gy,Nx,Ny,Cx,Cy,Den: Integer;
Begin
 ObjOffset(T,Par,Px,Py);ObjOffset(T,Obj,Ox,Oy);
 Pw:=OW(T,Par);Ph:=OH(T,Par);Ow_:=OW(T,Obj);Oh_:=OH(T,Obj);
 { point saisi dans le curseur }
 Gx:=GMouseX-Ox;Gy:=GMouseY-Oy;
 If (Gx<0) Or (Gx>=Ow_) Then Gx:=Ow_ Div 2;
 If (Gy<0) Or (Gy>=Oh_) Then Gy:=Oh_ Div 2;
 Cx:=Ox;Cy:=Oy;
 XorFrame(Cx,Cy,Ow_,Oh_);
 While ((GMouseB And 1)<>0) And Not UserBreak Do Begin
  GemIdle;
  Nx:=Cx;Ny:=Cy;
  If Vh=0 Then Nx:=Clamp(GMouseX-Gx,Px,Max2(Px,Px+Pw-Ow_))
  Else Ny:=Clamp(GMouseY-Gy,Py,Max2(Py,Py+Ph-Oh_));
  If (Nx<>Cx) Or (Ny<>Cy) Then Begin
   XorFrame(Cx,Cy,Ow_,Oh_);Cx:=Nx;Cy:=Ny;XorFrame(Cx,Cy,Ow_,Oh_);
  End;
 End;
 XorFrame(Cx,Cy,Ow_,Oh_);
 If Vh=0 Then Begin Den:=Pw-Ow_;If Den<=0 Then SlideBox:=0 Else SlideBox:=((Cx-Px)*1000+Den Div 2) Div Den;End
 Else Begin Den:=Ph-Oh_;If Den<=0 Then SlideBox:=0 Else SlideBox:=((Cy-Py)*1000+Den Div 2) Div Den;End;
End;

{ ---------------------------------------------------------------------- }
{ Fenetres : operations                                                    }
{ ---------------------------------------------------------------------- }

Function WinCreate(Kind: Integer; Const Full: TRect): Integer;
Var H: Integer;
Begin
 WinCreate:=-1;
 For H:=1 To MAXWIN-1 Do
  If Not Wins[H].Used Then Begin
   FillChar(Wins[H],SizeOf(TWin),0);
   Wins[H].Used:=True;Wins[H].Kind:=Kind;Wins[H].Owner:=CurProc;
   Wins[H].Full:=Full;Wins[H].R:=Full;Wins[H].Prev:=Full;
   Wins[H].HSl:=0;Wins[H].VSl:=0;Wins[H].HSz:=-1;Wins[H].VSz:=-1;
   WinCreate:=H;
   Exit;
  End;
End;

Procedure WinOpen(H: Integer; R: TRect);
Begin
 If (H<1) Or (H>=MAXWIN) Or Not Wins[H].Used Or Wins[H].Open Then Exit;
 If R.X<0 Then R.X:=0;If R.Y<MenuH Then R.Y:=MenuH;
 If R.X+R.W>SW Then R.W:=SW-R.X;
 If R.Y+R.H>SH Then R.H:=SH-R.Y;
 Wins[H].R:=R;Wins[H].Prev:=R;Wins[H].Open:=True;
 ZToTop(H);
 GrowShrink(RectMake(R.X+R.W Div 2,R.Y+R.H Div 2,2,2),R);
 Repaint(R,True);
End;

Procedure WinClose(H: Integer);
Var R: TRect;
Begin
 If (H<1) Or (H>=MAXWIN) Or Not Wins[H].Open Then Exit;
 R:=Wins[H].R;
 GrowShrink(R,RectMake(R.X+R.W Div 2,R.Y+R.H Div 2,2,2));
 Wins[H].Open:=False;
 ZRemove(H);
 Repaint(R,True);
End;

Procedure WinDelete(H: Integer);
Begin
 If (H<1) Or (H>=MAXWIN) Then Exit;
 If Wins[H].Open Then WinClose(H);
 Wins[H].Used:=False;
End;

Procedure WinSetRect(H: Integer; R: TRect);
Var Old,U: TRect; Sz: Boolean;
Begin
 If (H<1) Or (H>=MAXWIN) Or Not Wins[H].Used Then Exit;
 Old:=Wins[H].R;
 Wins[H].Prev:=Old;
 Wins[H].R:=R;
 If Wins[H].Open Then Begin
  { zone anciennement couverte, non recouverte par la nouvelle : redessin
    complet ; la fenetre elle-meme : redessinee avec contenu }
  Repaint(Old,True);
  Repaint(R,True);
 End;
End;

Procedure WinTop(H: Integer);
Var OldTop: Integer;
Begin
 If (H<1) Or (H>=MAXWIN) Or Not Wins[H].Open Then Exit;
 If TopWin=H Then Exit;
 ZToTop(H);
 Repaint(Wins[H].R,True);
End;

Function WinFind(X,Y: Integer): Integer;
Var I,H: Integer;
Begin
 WinFind:=0;
 For I:=1 To NWZ Do Begin
  H:=WZ[I];
  If Wins[H].Open And InRect(X,Y,Wins[H].R) Then Begin WinFind:=H;Exit;End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Gestionnaire d'ecran : clics sur les cadres des fenetres                 }
{ ---------------------------------------------------------------------- }

{ Bouton de fenetre : inverse tant que le bouton est enfonce ; True si relache dedans }
Function WatchBoxRect(X,Y,W,H: Integer): Boolean;
Var Inside,Was: Boolean;
Begin
 Was:=True;
 OSetup;SetClip(0,0,SW-1,SH-1);VP^.FillInt:=1;VP^.FillCol:=1;VP^.WrMode:=WM_XOR;
 VBar(X,Y,X+W-1,Y+H-1);
 While ((GMouseB And 1)<>0) And Not UserBreak Do Begin
  GemIdle;
  Inside:=InRect(GMouseX,GMouseY,RectMake(X,Y,W,H));
  If Inside<>Was Then Begin
   OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VP^.WrMode:=WM_XOR;
   VBar(X,Y,X+W-1,Y+H-1);Was:=Inside;
  End;
 End;
 If Was Then Begin OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VP^.WrMode:=WM_XOR;VBar(X,Y,X+W-1,Y+H-1);End;
 OSetup;
 WatchBoxRect:=Was;
End;

Procedure SliderMsg(H: Integer; Vert: Boolean);
Var W: ^TWin; Wk: TRect; K,X1,Y1,X2,Y2,Track,SlLen,SlPos,Pos0,Off,Sz: Integer; Pos: LongInt; Start: Integer;
    Done: Boolean; DX,DY: Integer; NewPos: Integer;
Begin
 W:=@Wins[H];Wk:=WinWork(H);K:=W^.Kind;
 If Vert Then Begin
  Y1:=Wk.Y;Y2:=Wk.Y+Wk.H-1;
  If (K And UPARROW_)<>0 Then Y1:=Y1+WSCROLL;
  If (K And DNARROW_)<>0 Then Y2:=Y2-WSCROLL;
  Track:=Y2-Y1+1;
  If W^.VSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.VSz Div 1000);
  SlPos:=(Track-SlLen)*Clamp(W^.VSl,0,1000) Div 1000;
  Off:=GMouseY-(Y1+SlPos);
  Start:=GMouseY;
 End Else Begin
  X1:=Wk.X;X2:=Wk.X+Wk.W-1;
  If (K And LFARROW_)<>0 Then X1:=X1+WSCROLL;
  If (K And RTARROW_)<>0 Then X2:=X2-WSCROLL;
  Track:=X2-X1+1;
  If W^.HSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.HSz Div 1000);
  SlPos:=(Track-SlLen)*Clamp(W^.HSl,0,1000) Div 1000;
  Off:=GMouseX-(X1+SlPos);
 End;
 While ((GMouseB And 1)<>0) And Not UserBreak Do GemIdle;
 If Vert Then Begin
  Pos:=GMouseY-Off-Y1;
  If Track-SlLen>0 Then NewPos:=Clamp(Pos*1000 Div (Track-SlLen),0,1000) Else NewPos:=0;
  PostMsg(W^.Owner,WM_VSLID,H,NewPos,0,0,0,0);
 End Else Begin
  Pos:=GMouseX-Off-X1;
  If Track-SlLen>0 Then NewPos:=Clamp(Pos*1000 Div (Track-SlLen),0,1000) Else NewPos:=0;
  PostMsg(W^.Owner,WM_HSLID,H,NewPos,0,0,0,0);
 End;
End;

{ Traite un appui sur le bouton gauche ; retourne True si le clic est consomme }
Function ScreenManagerClick: Boolean;
Var H,K,Z: Integer; W: ^TWin; R,Wk: TRect; X,Y,NX,NY,NW,NH,RW,RH: Integer; Bound: TRect; Ok: Boolean;
    X1,Y1,X2,Y2,Arrow,Own: Integer; SlLen,Track,SlPos: Integer;
Begin
 ScreenManagerClick:=False;
 X:=GMouseX;Y:=GMouseY;
 If (MenuTree<>0) And (Y<MenuH) Then Begin
  ScreenManagerClick:=True;Exit;
 End;
 H:=WinFind(X,Y);
 If H=0 Then Exit;
 W:=@Wins[H];K:=W^.Kind;R:=W^.R;Wk:=WinWork(H);
 Own:=W^.Owner;
 If InRect(X,Y,Wk) Then Begin
  If TopWin<>H Then Begin
   PostMsg(Own,WM_TOPPED,H,0,0,0,0,0);
   ScreenManagerClick:=True;
  End;
  Exit;
 End;
 ScreenManagerClick:=True;
 If TopWin<>H Then Begin PostMsg(Own,WM_TOPPED,H,0,0,0,0,0);Exit;End;
 { barre de titre }
 If HasTitle(K) And (Y<R.Y+WTITLE_H) Then Begin
  If ((K And CLOSER_)<>0) And (X<R.X+WSCROLL) Then Begin
   Ok:=WatchBoxRect(R.X+1,R.Y+1,WSCROLL-1,WTITLE_H-1);
   If Ok Then PostMsg(Own,WM_CLOSED,H,0,0,0,0,0);
   Exit;
  End;
  If ((K And FULLER_)<>0) And (X>=R.X+R.W-WSCROLL) Then Begin
   Ok:=WatchBoxRect(R.X+R.W-WSCROLL+1,R.Y+1,WSCROLL-1,WTITLE_H-1);
   If Ok Then PostMsg(Own,WM_FULLED,H,0,0,0,0,0);
   Exit;
  End;
  If (K And MOVER_)<>0 Then Begin
   Bound:=RectMake(0,MenuH,SW,SH-MenuH);
   DragBox(R.W,R.H,R.X,R.Y,RectMake(-R.W+40,MenuH,SW+R.W-80,SH),NX,NY);
   If (NX<>R.X) Or (NY<>R.Y) Then PostMsg(Own,WM_MOVED,H,NX,NY,R.W,R.H,0);
  End;
  Exit;
 End;
 { barres de defilement }
 If HasVBar(K) And (X>=Wk.X+Wk.W) And (X<Wk.X+Wk.W+WSCROLL) And (Y>=Wk.Y) And (Y<Wk.Y+Wk.H) Then Begin
  Y1:=Wk.Y;Y2:=Wk.Y+Wk.H-1;
  If ((K And UPARROW_)<>0) And (Y<Y1+WSCROLL) Then Begin
   Ok:=WatchBoxRect(Wk.X+Wk.W+1,Wk.Y,WSCROLL-1,WSCROLL);
   If Ok Then PostMsg(Own,WM_ARROWED,H,2,0,0,0,0);Exit;
  End;
  If ((K And DNARROW_)<>0) And (Y>Y2-WSCROLL) Then Begin
   Ok:=WatchBoxRect(Wk.X+Wk.W+1,Y2-WSCROLL+1,WSCROLL-1,WSCROLL);
   If Ok Then PostMsg(Own,WM_ARROWED,H,3,0,0,0,0);Exit;
  End;
  If (K And UPARROW_)<>0 Then Y1:=Y1+WSCROLL;
  If (K And DNARROW_)<>0 Then Y2:=Y2-WSCROLL;
  If (K And VSLIDE_)<>0 Then Begin
   Track:=Y2-Y1+1;
   If W^.VSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.VSz Div 1000);
   SlPos:=(Track-SlLen)*Clamp(W^.VSl,0,1000) Div 1000;
   If (Y>=Y1+SlPos) And (Y<Y1+SlPos+SlLen) Then SliderMsg(H,True)
   Else If Y<Y1+SlPos Then PostMsg(Own,WM_ARROWED,H,0,0,0,0,0)
   Else PostMsg(Own,WM_ARROWED,H,1,0,0,0,0);
   WaitButtonRelease;
  End;
  Exit;
 End;
 If HasHBar(K) And (Y>=Wk.Y+Wk.H) And (Y<Wk.Y+Wk.H+WSCROLL) And (X>=Wk.X) And (X<Wk.X+Wk.W) Then Begin
  X1:=Wk.X;X2:=Wk.X+Wk.W-1;
  If ((K And LFARROW_)<>0) And (X<X1+WSCROLL) Then Begin
   Ok:=WatchBoxRect(Wk.X,Wk.Y+Wk.H+1,WSCROLL,WSCROLL-1);
   If Ok Then PostMsg(Own,WM_ARROWED,H,6,0,0,0,0);Exit;
  End;
  If ((K And RTARROW_)<>0) And (X>X2-WSCROLL) Then Begin
   Ok:=WatchBoxRect(X2-WSCROLL+1,Wk.Y+Wk.H+1,WSCROLL,WSCROLL-1);
   If Ok Then PostMsg(Own,WM_ARROWED,H,7,0,0,0,0);Exit;
  End;
  If (K And LFARROW_)<>0 Then X1:=X1+WSCROLL;
  If (K And RTARROW_)<>0 Then X2:=X2-WSCROLL;
  If (K And HSLIDE_)<>0 Then Begin
   Track:=X2-X1+1;
   If W^.HSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.HSz Div 1000);
   SlPos:=(Track-SlLen)*Clamp(W^.HSl,0,1000) Div 1000;
   If (X>=X1+SlPos) And (X<X1+SlPos+SlLen) Then SliderMsg(H,False)
   Else If X<X1+SlPos Then PostMsg(Own,WM_ARROWED,H,4,0,0,0,0)
   Else PostMsg(Own,WM_ARROWED,H,5,0,0,0,0);
   WaitButtonRelease;
  End;
  Exit;
 End;
 { coin de redimensionnement }
 If ((K And SIZER_)<>0) And (X>=R.X+R.W-WSCROLL) And (Y>=R.Y+R.H-WSCROLL) Then Begin
  RubberBox(R.X,R.Y,80,60,RW,RH);
  If (RW<>R.W) Or (RH<>R.H) Then PostMsg(Own,WM_SIZED,H,R.X,R.Y,RW,RH,0);
 End;
End;

{ ====================================================================== }
{                  GEM : AES - FORMULAIRES ET API                        }
{ ====================================================================== }

{ ---------------------------------------------------------------------- }
{ form_alert                                                               }
{ ---------------------------------------------------------------------- }

Procedure DrawAlertIcon(X,Y,Ic: Integer);
Var I: Integer;
Begin
 OSetup;SetClip(0,0,SW-1,SH-1);
 Case Ic Of
  1: Begin
      For I:=0 To 28 Do FastSpan(Y+2+I,X+16-I Div 2,X+16+I Div 2,False,False);
      LinePhase:=0;VP^.LineCol:=1;VP^.LineWidth:=2;
      VLine(X+16,Y+2,X+2,Y+30);VLine(X+16,Y+2,X+30,Y+30);VLine(X+2,Y+30,X+30,Y+30);
      VP^.LineWidth:=1;
      OText(X+12,Y+14,'!',16,1,False);
     End;
  2: Begin
      VP^.FillInt:=0;VP^.FillPer:=1;VArc(X+16,Y+16,15,15,0,3600,2);VP^.FillPer:=0;
      OText(X+12,Y+8,'?',16,1,False);
     End;
  3: Begin
      VP^.FillInt:=1;VP^.FillCol:=1;
      PX[0]:=X+10;PY[0]:=Y;PX[1]:=X+22;PY[1]:=Y;PX[2]:=X+32;PY[2]:=Y+10;PX[3]:=X+32;PY[3]:=Y+22;
      PX[4]:=X+22;PY[4]:=Y+32;PX[5]:=X+10;PY[5]:=Y+32;PX[6]:=X;PY[6]:=Y+22;PX[7]:=X;PY[7]:=Y+10;
      PolyFillPts(8,PX,PY,True);
      OText(X+12,Y+8,'X',16,0,False);
     End;
 End;
End;

Function FormAlert(Def: Integer; Const Txt: String): Integer;
Var Lines: Array[1..6] Of String; Btns: Array[1..4] Of String; NL,NB,I,P,Ic,W,H,X0,Y0,BW,TX,BX,Sel,Res: Integer;
    S,Cur: String; Part: Integer; Sv: TScrSave; Done: Boolean; K: LongInt; PrevDown: Boolean;
    Rc: Array[1..4] Of TRect; Mx,My: Integer;
Begin
 NL:=0;NB:=0;Ic:=0;Part:=0;
 I:=1;
 While I<=Length(Txt) Do Begin
  If Txt[I]='[' Then Begin
   Inc(Part);Cur:='';Inc(I);
   While (I<=Length(Txt)) And (Txt[I]<>']') Do Begin Cur:=Cur+Txt[I];Inc(I);End;
   Case Part Of
    1: Ic:=ToInt(Cur);
    2: While (Cur<>'') And (NL<6) Do Begin
        P:=Pos('|',Cur);Inc(NL);
        If P=0 Then Begin Lines[NL]:=Cur;Cur:='';End Else Begin Lines[NL]:=Copy(Cur,1,P-1);Delete(Cur,1,P);End;
       End;
    3: While (Cur<>'') And (NB<4) Do Begin
        P:=Pos('|',Cur);Inc(NB);
        If P=0 Then Begin Btns[NB]:=Cur;Cur:='';End Else Begin Btns[NB]:=Copy(Cur,1,P-1);Delete(Cur,1,P);End;
       End;
   End;
  End;
  Inc(I);
 End;
 If NB=0 Then Begin NB:=1;Btns[1]:='OK';End;
 BW:=0;
 For I:=1 To NB Do If Length(Btns[I])*8+16>BW Then BW:=Length(Btns[I])*8+16;
 W:=0;
 For I:=1 To NL Do If Length(Lines[I])*8>W Then W:=Length(Lines[I])*8;
 If Ic>0 Then TX:=64 Else TX:=16;
 W:=TX+W+16;
 If NB*(BW+16)+16>W Then W:=NB*(BW+16)+16;
 H:=Max2(NL*16,32)+16+8+24+24;
 X0:=(SW-W) Div 2;Y0:=(SH-H) Div 2;
 ScrSave(X0-2,Y0-2,X0+W+6,Y0+H+6,Sv);
 OSetup;SetClip(0,0,SW-1,SH-1);
 OFill(X0+4,Y0+4,X0+W+3,Y0+H+3,7,1);
 OFill(X0,Y0,X0+W-1,Y0+H-1,0,0);
 OBorder(X0,Y0,W,H,3,1);OBorder(X0+4,Y0+4,W-8,H-8,1,1);
 If Ic>0 Then DrawAlertIcon(X0+16,Y0+16,Ic);
 For I:=1 To NL Do OText(X0+TX,Y0+16+(I-1)*16,Lines[I],16,1,False);
 BX:=X0+(W-NB*(BW+16)+16) Div 2;
 If Def<1 Then Def:=0;
 For I:=1 To NB Do Begin
  Rc[I]:=RectMake(BX+(I-1)*(BW+16),Y0+H-40,BW,22);
 End;
 Sel:=Def;
 Done:=False;Res:=Max2(1,Def);
 For I:=1 To NB Do Begin
  OSetup;SetClip(0,0,SW-1,SH-1);
  OFill(Rc[I].X,Rc[I].Y,Rc[I].X+Rc[I].W-1,Rc[I].Y+Rc[I].H-1,0,0);
  If I=Def Then OBorder(Rc[I].X,Rc[I].Y,Rc[I].W,Rc[I].H,3,1) Else OBorder(Rc[I].X,Rc[I].Y,Rc[I].W,Rc[I].H,1,1);
  OText(Rc[I].X+(BW-Length(Btns[I])*8) Div 2,Rc[I].Y+3,Btns[I],16,1,False);
 End;
 If Not BatchMode Then BlitScreen(False);
 If BatchMode Then Begin Done:=True;Res:=Max2(1,Def);End;
 PrevDown:=True;
 Inc(ModalLevel);
 While Not Done And Not UserBreak Do Begin
  GemIdle;
  If Not KQEmpty Then Begin
   K:=KQPop;
   If (K And $FF)=13 Then Begin Res:=Max2(1,Def);Done:=True;End;
  End;
  If ((GMouseB And 1)<>0) And Not PrevDown Then Begin
   For I:=1 To NB Do
    If InRect(GMouseX,GMouseY,Rc[I]) Then Begin
     OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VP^.WrMode:=WM_XOR;
     VBar(Rc[I].X,Rc[I].Y,Rc[I].X+Rc[I].W-1,Rc[I].Y+Rc[I].H-1);
     OSetup;
     If Not BatchMode Then BlitScreen(False);
     WaitButtonRelease;
     Res:=I;Done:=True;
    End;
  End;
  PrevDown:=(GMouseB And 1)<>0;
 End;
 Dec(ModalLevel);
 ScrRestore(Sv);
 If Not BatchMode Then BlitScreen(False);
 FormAlert:=Res;
End;

Function FormErrorText(N: Integer): String;
Begin
 Case N Of
  2,18: FormErrorText:='[1][This application cannot find the|folder or file you tried to access.][ OK ]';
  3: FormErrorText:='[1][This application cannot find the|folder you tried to access.][ OK ]';
  4: FormErrorText:='[1][This application has run out of|file handles.][ OK ]';
  5: FormErrorText:='[1][You cannot access this item.][ OK ]';
  8: FormErrorText:='[1][There is not enough memory to|run this application.][ OK ]';
  15: FormErrorText:='[1][The drive you specified does not|exist.][ OK ]';
 Else FormErrorText:='[3][An error occurred (TOS error '+IntStr(N)+').][ OK ]';
 End;
End;

{ ---------------------------------------------------------------------- }
{ form_do                                                                  }
{ ---------------------------------------------------------------------- }

Function NextEditable(T: LongInt; Cur,Dir: Integer): Integer;
Var I,Cnt,N: Integer;
Begin
 NextEditable:=-1;
 N:=0;
 Repeat
  Inc(N);If N>2000 Then Exit;
  Cur:=Cur+Dir;
  If (Cur<0) Then Cur:=0;
  If (Cur>=0) And ((OFlags(T,Cur) And OF_EDITABLE)<>0) And ((OFlags(T,Cur) And OF_HIDETREE)=0) Then Begin
   NextEditable:=Cur;Exit;
  End;
  If (Dir>0) And ((OFlags(T,Cur) And OF_LASTOB)<>0) Then Begin
   { reprend au debut }
   Cur:=-1;
   If N>1 Then Begin
    For I:=0 To 2000 Do Begin
     If ((OFlags(T,I) And OF_EDITABLE)<>0) Then Begin NextEditable:=I;Exit;End;
     If (OFlags(T,I) And OF_LASTOB)<>0 Then Break;
    End;
    Exit;
   End;
  End;
  If (Dir<0) And (Cur=0) Then Begin
   For I:=0 To 2000 Do Begin
    If ((OFlags(T,I) And OF_EDITABLE)<>0) Then NextEditable:=I;
    If (OFlags(T,I) And OF_LASTOB)<>0 Then Break;
   End;
   Exit;
  End;
 Until False;
End;

Function FormDo(T: LongInt; Start: Integer): Integer;
Var Cur,Idx,Obj,I,Ex,P,Def,Nx: Integer; K: LongInt; Fl,St: Integer; Done: Boolean; PrevDown: Boolean;
    X,Y: Integer; Res: Integer; Cl: Integer; Sib: Integer; Sel,Inside: Boolean; Mx: Integer;
    CharX,Tmplpos: Integer;
Begin
 Inc(ModalLevel);
 Def:=-1;
 For I:=0 To 2000 Do Begin
  If ((OFlags(T,I) And OF_DEFAULT)<>0) And (Def<0) Then Def:=I;
  If (OFlags(T,I) And OF_LASTOB)<>0 Then Break;
 End;
 Cur:=-1;
 If (Start>0) And ((OFlags(T,Start) And OF_EDITABLE)<>0) Then Cur:=Start
 Else Cur:=NextEditable(T,0,1);
 If (Cur=0) Then Cur:=-1;
 If Cur>0 Then ObjEdit(T,Cur,0,Idx,0);
 Done:=False;Res:=0;PrevDown:=True;
 If BatchMode Then Begin
  If Def>0 Then Res:=Def Else Res:=0;
  Done:=True;
 End;
 While Not Done And Not UserBreak Do Begin
  GemIdle;
  If Not KQEmpty Then Begin
   K:=KQPop;
   If ((K And $FF)=13) And (Def>0) Then Begin
    Res:=Def;
    SetOState(T,Res,OState(T,Res) Or OS_SELECTED);ObjRedraw(T,Res);
    Done:=True;
   End Else If (K And $FF)=9 Then Begin
    If Cur>0 Then Begin
     ObjEdit(T,Cur,0,Idx,3);
     Nx:=NextEditable(T,Cur,1);If Nx>0 Then Cur:=Nx;
     ObjEdit(T,Cur,0,Idx,0);
    End;
   End Else If ((K Shr 16) And $FF=$50) And ((K And $FF)=0) And (Cur>0) Then Begin
    ObjEdit(T,Cur,0,Idx,3);Nx:=NextEditable(T,Cur,1);If Nx>0 Then Cur:=Nx;ObjEdit(T,Cur,0,Idx,0);
   End Else If ((K Shr 16) And $FF=$48) And ((K And $FF)=0) And (Cur>0) Then Begin
    ObjEdit(T,Cur,0,Idx,3);Nx:=NextEditable(T,Cur,-1);If Nx>0 Then Cur:=Nx;ObjEdit(T,Cur,0,Idx,0);
   End Else If Cur>0 Then
    ObjEdit(T,Cur,((K Shr 16) And $FF) Shl 8 Or (K And $FF),Idx,1);
  End;
  If ((GMouseB And 1)<>0) And Not PrevDown Then Begin
   Obj:=ObjFind(T,0,8,GMouseX,GMouseY);
   If (Obj>0) And ((OState(T,Obj) And OS_DISABLED)=0) Then Begin
    Fl:=OFlags(T,Obj);Cl:=ClickCount;
    If ((Fl And OF_EDITABLE)<>0) And (Obj<>Cur) And ((Fl And (OF_SELECTABLE Or OF_EXIT Or OF_TOUCHEXIT))=0) Then Begin
     If Cur>0 Then ObjEdit(T,Cur,0,Idx,3);
     Cur:=Obj;ObjEdit(T,Cur,0,Idx,0);
    End Else If (Fl And OF_EDITABLE)<>0 Then Begin
     { position du curseur d'apres le clic }
     If Cur>0 Then ObjEdit(T,Cur,0,Idx,3);
     Cur:=Obj;ObjEdit(T,Cur,0,Idx,0);
     ObjOffset(T,Obj,X,Y);
     Idx:=Clamp((GMouseX-EditCursorX(T,Obj,0)) Div 8,0,Idx);
     ObjRedraw(T,Obj);EditDrawCursor(T,Obj,Idx);
    End;
    If (Fl And OF_SELECTABLE)<>0 Then Begin
     If (Fl And OF_RBUTTON)<>0 Then Begin
      If (OState(T,Obj) And OS_SELECTED)=0 Then Begin
       P:=OParent(T,Obj);
       If P>=0 Then Begin
        Sib:=OHead(T,P);
        While Sib>=0 Do Begin
         If (Sib<>Obj) And ((OFlags(T,Sib) And OF_RBUTTON)<>0) And ((OState(T,Sib) And OS_SELECTED)<>0) Then Begin
          SetOState(T,Sib,OState(T,Sib) And Not OS_SELECTED);ObjRedraw(T,Sib);
         End;
         If Sib=OTail(T,P) Then Break;
         Sib:=ONext(T,Sib);
        End;
       End;
       SetOState(T,Obj,OState(T,Obj) Or OS_SELECTED);ObjRedraw(T,Obj);
      End;
      If Not BatchMode Then BlitScreen(False);
      WaitButtonRelease;
     End Else Begin
      St:=OState(T,Obj);
      If (Fl And OF_TOUCHEXIT)<>0 Then Begin
       SetOState(T,Obj,St Xor OS_SELECTED);ObjRedraw(T,Obj);
      End Else Begin
       Inside:=WatchBox(T,Obj,St Xor OS_SELECTED,St);
       If Not Inside Then SetOState(T,Obj,St) Else SetOState(T,Obj,St Xor OS_SELECTED);
       ObjRedraw(T,Obj);
      End;
     End;
    End;
    If ((Fl And OF_EXIT)<>0) Or ((Fl And OF_TOUCHEXIT)<>0) Then Begin
     If ((Fl And OF_SELECTABLE)=0) Or ((OState(T,Obj) And OS_SELECTED)<>0) Or ((Fl And OF_TOUCHEXIT)<>0) Then Begin
      Res:=Obj;If Cl>=2 Then Res:=Res Or $8000;
      Done:=True;
     End;
    End;
   End;
  End;
  PrevDown:=(GMouseB And 1)<>0;
 End;
 If Cur>0 Then ObjEdit(T,Cur,0,Idx,3);
 Dec(ModalLevel);
 FormDo:=Res;
End;

{ ---------------------------------------------------------------------- }
{ Selecteur de fichiers                                                    }
{ ---------------------------------------------------------------------- }

Function AesFsel(PathAddr,FileAddr: LongInt; Const Title: String): Boolean;
Var Path,Sel,Mask,Dir: String; I,P: Integer; Full: String; Ok: Boolean;
Begin
 AesFsel:=False;
 Path:=RdStr(PathAddr,120);
 Sel:=RdStr(FileAddr,14);
 P:=Length(Path);
 While (P>0) And (Path[P]<>'\') And (Path[P]<>'/') And (Path[P]<>':') Do Dec(P);
 Dir:=Copy(Path,1,P);Mask:=Copy(Path,P+1,40);
 If Mask='' Then Mask:='*.*';
 If BatchMode Then Exit;
 Full:=HostPath(Dir)+Sel;
 If (Dir='') Or (Length(Dir)<=3) Then Full:=Sel;
 HideMouse;
 Ok:=FileSelect(Title,Mask,Full);
 BlitScreen(True);
 If Ok Then Begin
  P:=Length(Full);
  While (P>0) And (Full[P]<>'\') And (Full[P]<>'/') Do Dec(P);
  If P>0 Then Begin
   Dir:=Copy(Full,1,P);
   WrStr(PathAddr,Dir+Mask);
  End;
  WrStr(FileAddr,Upper(Copy(Full,P+1,12)));
  AesFsel:=True;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Gestion des processus et de l'ordonnancement                             }
{ ---------------------------------------------------------------------- }

Procedure SaveCtx(P: Integer);
Begin
 Move(Rg,Procs[P].Rgs,SizeOf(Rg));
 Procs[P].PCs:=PC;Procs[P].SRs:=SRv;Procs[P].USPs:=USPv;Procs[P].SSPs:=SSPv;
End;

Procedure LoadCtx(P: Integer);
Begin
 Move(Procs[P].Rgs,Rg,SizeOf(Rg));
 PC:=Procs[P].PCs;SRv:=Procs[P].SRs;USPv:=Procs[P].USPs;SSPv:=Procs[P].SSPs;
End;

Function ProcApName(Const Name: String): String;
Var S: String; P: Integer;
Begin
 S:=Upper(ShortName(Name));
 P:=Pos('.',S);
 If P>0 Then S:=Copy(S,1,P-1);
 ProcApName:=Copy(S,1,8);
End;

Function NewProc(Const Name: String; IsAcc: Boolean): Integer;
Var I: Integer;
Begin
 NewProc:=-1;
 For I:=0 To MAXPROC-1 Do
  If Not Procs[I].Used Then Begin
   FillChar(Procs[I],SizeOf(TProc),0);
   Procs[I].Used:=True;Procs[I].IsAcc:=IsAcc;Procs[I].ApId:=I;
   Procs[I].Name:=ProcApName(Name);Procs[I].MenuId:=-1;
   NewProc:=I;Exit;
  End;
End;

Procedure GemReset;
Var I: Integer;
Begin
 FillChar(Wins,SizeOf(Wins),0);NWZ:=0;
 FillChar(Procs,SizeOf(Procs),0);
 CurProc:=0;MainProc:=0;
 MenuTree:=0;MenuOwner:=0;MenuH:=19;MenuBar:=1;DeskTree:=0;DeskStart:=0;
 For I:=0 To 5 Do Begin AccSlots[I]:=-1;AccProc[I]:=-1;AccStr[I]:=0;End;
 UpdateLevel:=0;MCtrlLevel:=0;MCtrlOwner:=-1;ModalLevel:=0;
 ClickCount:=0;DClickSpeed:=3;PrevB:=0;ButtonTaken:=False;MouseHidden:=0;
 BtnLastTime:=0;RscLoaded:=False;
 VdiInitTables;
 FillChar(Vd,SizeOf(Vd),0);
 Vd[0].Used:=True;VdiDefaults(Vd[0]);
 Vd[1].Used:=True;VdiDefaults(Vd[1]);
 SelVdi(0);
 SetMouseShape(0);
 ScrapDir:='C:\CLIPBRD';ScrapSet:=True;
 VexTim:=STUB_RTS;VexBut:=STUB_RTS;VexMot:=STUB_RTS;VexCur:=STUB_RTS;VexTimLast:=0;InVex:=False;
 KbdPrevX:=-1;KbdPrevY:=-1;KbdPrevB:=0;
 RecActive:=False;RecMem:=0;PlayMem:=0;SynthMouse:=False;SynthRel:=False;PlayWait:=False;
 MenuSet[0]:=200;MenuSet[1]:=10000;MenuSet[2]:=250;MenuSet[3]:=0;MenuSet[4]:=16;AttachN:=0;IStartN:=0;
 ShelNext:='';ShelTail:='';
 AesActive:=True;NoBlit:=False;
End;

{ Installe les noms des accessoires dans le menu Desk de l'arbre }
Procedure InstallAccItems(T: LongInt);
Var Screen,Box,N,K,I,C: Integer; Items: Array[0..63] Of Integer;
Begin
 For K:=0 To 5 Do AccSlots[K]:=-1;
 Screen:=ONext(T,OHead(T,0));
 If Screen<0 Then Exit;
 Box:=OHead(T,Screen);
 If Box<0 Then Exit;
 N:=0;C:=OHead(T,Box);
 While (C>=0) And (N<63) Do Begin
  Items[N]:=C;Inc(N);
  If C=OTail(T,Box) Then Break;
  C:=ONext(T,C);
 End;
 If N<6 Then Exit;
 For K:=0 To 5 Do Begin
  I:=Items[N-6+K];
  AccSlots[K]:=I;
  If AccStr[K]<>0 Then Begin
   Wr32(OA(T,I)+12,AccStr[K]);
   SetOState(T,I,OState(T,I) And Not OS_DISABLED);
  End;
 End;
End;

Function RegisterAcc(P: Integer; Const Name: String): Integer;
Var K: Integer; A: LongInt;
Begin
 RegisterAcc:=-1;
 For K:=0 To 5 Do
  If AccProc[K]<0 Then Begin
   A:=DoMalloc(Length(Name)+2);
   If A=0 Then Exit;
   WrStr(A,Name);
   AccStr[K]:=A;AccProc[K]:=P;
   If (MenuTree<>0) And (AccSlots[K]>=0) Then Begin
    Wr32(OA(MenuTree,AccSlots[K])+12,A);
    SetOState(MenuTree,AccSlots[K],OState(MenuTree,AccSlots[K]) And Not OS_DISABLED);
    RegisterAcc:=AccSlots[K];
   End Else RegisterAcc:=K;
   Procs[P].MenuId:=K;
   Exit;
  End;
End;

{ ====================================================================== }
{                  GEM : AES - EVENEMENTS ET DISPATCHER                  }
{ ====================================================================== }

Var
 PrevDbgX,PrevDbgY : LongInt;
 LastRun    : Integer;
 PressTime  : LongInt;
 PressPending : Boolean;
 SmPrevDown : Boolean;

Function KeyOwnerWants(P: Integer): Boolean;
Begin
 KeyOwnerWants:=Procs[P].Used And Procs[P].Blocked And ((Procs[P].WFlags And 1)<>0);
End;

{ processus qui recoit les touches }
Function KeyOwner: Integer;
Var H,I: Integer;
Begin
 KeyOwner:=-1;
 H:=TopWin;
 If (H>0) And KeyOwnerWants(Wins[H].Owner) Then Begin KeyOwner:=Wins[H].Owner;Exit;End;
 If KeyOwnerWants(MainProc) Then Begin KeyOwner:=MainProc;Exit;End;
 For I:=0 To MAXPROC-1 Do If KeyOwnerWants(I) Then Begin KeyOwner:=I;Exit;End;
End;

Function ClickOwner: Integer;
Var H: Integer;
Begin
 H:=WinFind(GMouseX,GMouseY);
 If H=0 Then ClickOwner:=MainProc Else ClickOwner:=Wins[H].Owner;
End;

{ Ecrit les sorties d'un evenement termine ; True si l'attente est satisfaite }
Function TryComplete(P: Integer): Boolean;
Var Pr: ^TProc; Fl,Got,Cl: Integer; Io,Ai: LongInt; K: LongInt; Inside: Boolean; Now: LongInt;
    KeyV,Btn: Integer; Kb: Boolean;
 Procedure Out(I,V: Integer);
 Begin
  Wr16(Pr^.WIo+I*2,V And $FFFF);
 End;
Begin
 TryComplete:=False;
 Pr:=@Procs[P];
 Fl:=Pr^.WFlags;Got:=0;Io:=Pr^.WIo;Ai:=Pr^.WAi;
 KeyV:=0;Cl:=0;Btn:=GMouseB;
 If BatchMode Then Begin
  { pas d'interaction : on envoie un message de fermeture }
  If (Fl And 1)<>0 Then Begin Got:=Got Or 1;KeyV:=27;End;
  If (Fl And 16)<>0 Then Begin
   Procs[P].QN:=0;PostMsg(P,WM_CLOSED,0,0,0,0,0,0);
   PopMsg(P,Rd32(Ai));Got:=Got Or 16;
  End;
  If (Fl And 32)<>0 Then Got:=Got Or 32;
  If (Fl And 64)<>0 Then Got:=Got Or 64;
  If (Fl And 128)<>0 Then Got:=Got Or 128;
  If Got=0 Then Got:=Fl;
 End Else Begin
  If ((Fl And 1)<>0) And (KeyOwner=P) And Not KQEmpty Then Begin
   K:=KQPop;KeyV:=(((K Shr 16) And $FF) Shl 8) Or (K And $FF);Got:=Got Or 1;
  End;
  If (Fl And 2)<>0 Then Begin
   If Not ButtonTaken And (ClickOwner=P) Then Begin
    If (GMouseB And Pr^.WMask)=Pr^.WState Then Begin
     If Pr^.WClicks<=1 Then Begin Got:=Got Or 2;Cl:=Max2(1,ClickCount);End
     Else Begin
      If ClickCount>=Pr^.WClicks Then Begin Got:=Got Or 2;Cl:=ClickCount;End
      Else If (MsNow-BtnLastTime>LongInt(DClickSpeed)*80) Or ((GMouseB And Pr^.WMask)<>Pr^.WState) Then Begin
       Got:=Got Or 2;Cl:=ClickCount;
      End;
     End;
    End;
   End;
  End;
  If (Fl And 4)<>0 Then Begin
   Inside:=InRect(GMouseX,GMouseY,Pr^.WM1);
   If Inside=(Pr^.WM1F=0) Then Got:=Got Or 4;
  End;
  If (Fl And 8)<>0 Then Begin
   Inside:=InRect(GMouseX,GMouseY,Pr^.WM2);
   If Inside=(Pr^.WM2F=0) Then Got:=Got Or 8;
  End;
  If ((Fl And 16)<>0) And (Pr^.QN>0) Then Begin
   PopMsg(P,Rd32(Ai));Got:=Got Or 16;
  End;
  If ((Fl And 32)<>0) And (MsNow-Pr^.WDeadline>=0) Then Got:=Got Or 32;
  If ((Fl And 64)<>0) And Not RecActive Then Got:=Got Or 64;
  If ((Fl And 128)<>0) And (PlayMem=0) Then Got:=Got Or 128;
 End;
 If Got=0 Then Exit;
 TryComplete:=True;
 Case Pr^.WOp Of
  20: Out(0,KeyV);
  21: Begin Out(0,Cl);Out(1,GMouseX);Out(2,GMouseY);Out(3,Btn);Out(4,0);End;
  22: Begin Out(0,1);Out(1,GMouseX);Out(2,GMouseY);Out(3,Btn);Out(4,0);End;
  23,11: Out(0,1);
  24: Out(0,1);
  26: Out(0,DClickSpeed);
  14: Out(0,1);
  15: Begin Out(0,RecPos);RecActive:=False;RecMem:=0;End;
 Else Begin
   Out(0,Got);Out(1,GMouseX);Out(2,GMouseY);Out(3,Btn);Out(4,0);Out(5,KeyV);Out(6,Cl);
  End;
 End;
End;

Procedure ScreenManager;
Var Down: Boolean;
Begin
 If BatchMode Then Exit;
 If AesTrace And ((GMouseX<>PrevDbgX) Or (GMouseY<>PrevDbgY)) Then Begin
  PrevDbgX:=GMouseX;PrevDbgY:=GMouseY;
  WriteLn(ConOut,'MOUSE ',GMouseX,' ',GMouseY,' b=',GMouseB,' menuH=',MenuH,' tree=',Hex8(MenuTree),' title=',MouseOnTitle);Flush(ConOut);
 End;
 Down:=(GMouseB And 1)<>0;
 If Not Down Then ButtonTaken:=False;
 If (MCtrlLevel>0) Or (ModalLevel>0) Then Begin SmPrevDown:=Down;Exit;End;
 If MouseOnTitle And (GMouseB=0) And (Not ButtonTaken) Then Begin
  MenuTrack;
  SmPrevDown:=(GMouseB And 1)<>0;Exit;
 End;
 If MouseOnTitle And Down And Not SmPrevDown Then Begin
  MenuTrack;SmPrevDown:=(GMouseB And 1)<>0;Exit;
 End;
 If Down And Not SmPrevDown And Not ButtonTaken Then Begin
  If ScreenManagerClick Then ButtonTaken:=True;
 End;
 SmPrevDown:=Down;
End;

Procedure ResumeProc(P: Integer);
Begin
 If P<>CurProc Then LoadCtx(P);
 CurProc:=P;
 Procs[P].Blocked:=False;
 LastRun:=P;
End;

{ Appele quand le programme courant bloque : traite les entrees jusqu'a ce
  qu'un processus puisse reprendre }
Procedure GemDispatch;
Var N,P: Integer; Done: Boolean;
Begin
 Done:=False;
 Repeat
  PollInput;
  SyncSysVars;
  ScreenManager;
  For N:=1 To MAXPROC Do Begin
   P:=(LastRun+N) Mod MAXPROC;
   If Procs[P].Used And Procs[P].Blocked Then
    If TryComplete(P) Then Begin
     ResumeProc(P);Done:=True;Break;
    End;
  End;
  If Not Done Then Begin
   If Not BatchMode Then Begin BlitScreen(False);Delay(1);End;
  End;
 Until Done Or UserBreak;
 If Done Then StopReason:=STOP_NONE
 Else If UserBreak Then StopReason:=STOP_USER;
End;

Procedure BlockProc(Op,Flags: Integer; Io,Ai,Ctl: LongInt);
Begin
 With Procs[CurProc] Do Begin
  WOp:=Op;WFlags:=Flags;WIo:=Io;WAi:=Ai;WCtl:=Ctl;Blocked:=True;
 End;
 SaveCtx(CurProc);
 StopReason:=STOP_YIELD;
End;

{ ---------------------------------------------------------------------- }
{ Dispatcher AES (TRAP #2, D0 = $C8)                                       }
{ ---------------------------------------------------------------------- }

Procedure WindGet(H,Fld: Integer; Io: LongInt);
Var W: ^TWin; R: TRect; I: Integer;
 Procedure SetR(Const Rr: TRect);
 Begin
  Wr16(Io+2,Rr.X);Wr16(Io+4,Rr.Y);Wr16(Io+6,Rr.W);Wr16(Io+8,Rr.H);
 End;
Begin
 Wr16(Io,1);
 If (H<0) Or (H>=MAXWIN) Then Begin Wr16(Io,0);Exit;End;
 W:=@Wins[H];
 If H=0 Then Begin
  Case Fld Of
   4,5,7,17: SetR(RectMake(0,MenuH,SW,SH-MenuH));
   10: Begin Wr16(Io+2,TopWin);If TopWin>0 Then Wr16(Io+4,Wins[TopWin].Owner) Else Wr16(Io+4,0);End;
   14: Begin Wr16(Io+2,DeskTree Shr 16);Wr16(Io+4,DeskTree And $FFFF);Wr16(Io+6,DeskStart);End;
  End;
  If Fld=11 Then Begin
   VisibleRects(0,RectMake(0,MenuH,SW,SH-MenuH));
   If RectN>0 Then Begin SetR(RectList[1]);RectPos:=2;End Else Begin SetR(RectMake(0,0,0,0));End;
  End Else If Fld=12 Then Begin
   If RectPos<=RectN Then Begin SetR(RectList[RectPos]);Inc(RectPos);End Else SetR(RectMake(0,0,0,0));
  End;
  Exit;
 End;
 If Not W^.Used Then Begin Wr16(Io,0);Exit;End;
 Case Fld Of
  1: Wr16(Io+2,W^.Kind);
  2: Begin Wr16(Io+2,W^.Name Shr 16);Wr16(Io+4,W^.Name And $FFFF);End;
  3: Begin Wr16(Io+2,W^.Info Shr 16);Wr16(Io+4,W^.Info And $FFFF);End;
  4: SetR(WinWork(H));
  5: SetR(W^.R);
  6: SetR(W^.Prev);
  7: SetR(W^.Full);
  8: Wr16(Io+2,W^.HSl);
  9: Wr16(Io+2,W^.VSl);
  10: Begin Wr16(Io+2,TopWin);If TopWin>0 Then Wr16(Io+4,Wins[TopWin].Owner);End;
  11: Begin
       R:=WinWork(H);
       VisibleRects(H,R);
       If RectN>0 Then Begin SetR(RectList[1]);RectPos:=2;End Else SetR(RectMake(0,0,0,0));
      End;
  12: Begin
       If RectPos<=RectN Then Begin SetR(RectList[RectPos]);Inc(RectPos);End Else SetR(RectMake(0,0,0,0));
      End;
  15: Wr16(Io+2,W^.HSz);
  16: Wr16(Io+2,W^.VSz);
  17: SetR(RectMake(0,MenuH,SW,SH-MenuH));
 End;
End;

Procedure WindSet(H,Fld: Integer; Ii: LongInt);
Var W: ^TWin; R: TRect; V: Integer;
 Function I(K: Integer): Integer;
 Begin
  I:=SExt(Rd16(Ii+K*2),2);
 End;
Begin
 If H=0 Then Begin
  If Fld=14 Then Begin
   DeskTree:=(LongInt(Rd16(Ii+4)) Shl 16) Or Rd16(Ii+6);DeskStart:=I(4);
   If DeskTree<>0 Then Repaint(RectMake(0,MenuH,SW,SH-MenuH),True);
  End;
  Exit;
 End;
 If (H<0) Or (H>=MAXWIN) Or Not Wins[H].Used Then Exit;
 W:=@Wins[H];
 Case Fld Of
  1: Begin W^.Kind:=I(2) And $FFF;End;
  2: Begin W^.Name:=(LongInt(Rd16(Ii+4)) Shl 16) Or Rd16(Ii+6);If W^.Open Then Repaint(W^.R,False);End;
  3: Begin W^.Info:=(LongInt(Rd16(Ii+4)) Shl 16) Or Rd16(Ii+6);If W^.Open Then Repaint(W^.R,False);End;
  5: Begin
      R:=RectMake(I(2),I(3),I(4),I(5));
      If R.W<80 Then R.W:=80;If R.H<60 Then R.H:=60;
      If R.Y<MenuH Then R.Y:=MenuH;
      WinSetRect(H,R);
     End;
  7: W^.Full:=RectMake(I(2),I(3),I(4),I(5));
  8: Begin W^.HSl:=Clamp(I(2),0,1000);If W^.Open Then Repaint(W^.R,False);End;
  9: Begin W^.VSl:=Clamp(I(2),0,1000);If W^.Open Then Repaint(W^.R,False);End;
  10: WinTop(H);
  15: Begin W^.HSz:=I(2);If W^.Open Then Repaint(W^.R,False);End;
  16: Begin W^.VSz:=I(2);If W^.Open Then Repaint(W^.R,False);End;
 End;
End;

Function HostSep: Char;
Begin
 {$IFDEF UNIX}HostSep:='/';{$ELSE}HostSep:='\';{$ENDIF}
End;

Procedure ScrapMakeDir;
Begin
 {$I-}
 MkDir(HostPath(ScrapDir));
 {$I+}
 If IOResult<>0 Then Begin End;
End;

Procedure ScrapClear;
Var SR: SearchRec; D: String; Ef: File;
Begin
 D:=HostPath(ScrapDir);
 FindFirst(D+HostSep+'*',AnyFile,SR);
 While DosError=0 Do Begin
  If (Upper(Copy(SR.Name,1,6))='SCRAP.') And ((SR.Attr And Directory)=0) Then Begin
   {$I-}
   Assign(Ef,D+HostSep+SR.Name);Erase(Ef);
   {$I+}
   If IOResult<>0 Then Begin End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
End;

{ cherche une variable d'environnement invite (bloc ENV_BLK) ; renvoie l'adresse de la valeur }
Function EnvLookup(Const Name: String): LongInt;
Var A,B: LongInt; S: String;
Begin
 EnvLookup:=0;
 A:=ENV_BLK;
 While (Rd8(A)<>0) And (A<ENV_BLK+ENV_SIZE-2) Do Begin
  S:=RdStr(A,120);
  B:=A+Length(S)+1;
  If (Pos('=',Name)>0) And (Upper(Copy(S,1,Length(Name)))=Upper(Name)) Then Begin
   EnvLookup:=A+Length(Name);Exit;
  End;
  If (Pos('=',Name)=0) And (Upper(Copy(S,1,Length(Name)+1))=Upper(Name)+'=') Then Begin
   EnvLookup:=A+Length(Name)+1;Exit;
  End;
  A:=B;
 End;
End;

Procedure CopyMenuStruct(Dst,Tree: LongInt; Menu,Item,Scroll: Integer);
Begin
 Wr32(Dst,Tree);Wr16(Dst+4,Menu And $FFFF);Wr16(Dst+6,Item And $FFFF);
 Wr16(Dst+8,Scroll And $FFFF);Wr16(Dst+10,KShift And $FFFF);
End;

Function IStartFind(T: LongInt; Menu: Integer): Integer;
Var K: Integer;
Begin
 IStartFind:=0;
 For K:=1 To IStartN Do If (IStartTree[K]=T) And (IStartMenu[K]=Menu) Then IStartFind:=K;
End;

Function NProcsUsed: Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=0 To MAXPROC-1 Do If Procs[I].Used Then Inc(N);
 NProcsUsed:=N;
End;

Procedure Aes(Pb: LongInt);
Var Ctl,Glb,Ii,Io,Ai,Ao: LongInt; Op,I,J,K,H: Integer; S: String; T: LongInt; R,R2: TRect;
    A,B: LongInt; Fl,Cl,Mk,St: Integer; Dm: Integer; X,Y,W,Hh: Integer;
 Function IV(N: Integer): Integer;
 Begin
  IV:=SExt(Rd16(Ii+N*2),2);
 End;
 Function AI_(N: Integer): LongInt;
 Begin
  AI_:=Rd32(Ai+N*4);
 End;
 Procedure OV(N,V: Integer);
 Begin
  Wr16(Io+N*2,V And $FFFF);
 End;
 Procedure Wait(Flags: Integer);
 Begin
  BlockProc(Op,Flags,Io,Ai,Ctl);
  With Procs[CurProc] Do Begin
   WClicks:=0;WMask:=0;WState:=0;WM1F:=0;WM2F:=0;
  End;
 End;
Begin
 Ctl:=Rd32(Pb);Glb:=Rd32(Pb+4);Ii:=Rd32(Pb+8);Io:=Rd32(Pb+12);Ai:=Rd32(Pb+16);Ao:=Rd32(Pb+20);
 Op:=Rd16(Ctl);
 OV(0,1);
 If AesTrace Then Begin
  Write(ConOut,'AES ',Op,' [');
  For I:=0 To 7 Do Write(ConOut,SExt(Rd16(Ii+I*2),2),' ');
  WriteLn(ConOut,'] a0=',Hex8(Rd32(Ai)));Flush(ConOut);
 End;
 Case Op Of
  10: Begin
       If Not Procs[CurProc].Used Then Begin
        K:=NewProc(ProgName,False);If K>=0 Then CurProc:=K;
       End;
       If Procs[CurProc].Fresh Then Begin
        { premier appl_init d'un fils de Pexec : il remplace la barre de menus et le bureau }
        Procs[CurProc].Fresh:=False;
        MenuTree:=0;DeskTree:=0;MenuH:=19;
        If Not BatchMode And GfxOn Then Repaint(RectMake(0,0,SW,SH),True);
       End;
       Wr16(Glb,$0140);
       If NProcsUsed>1 Then Wr16(Glb+2,$FFFF) Else Wr16(Glb+2,1);
       Wr16(Glb+4,CurProc);Wr32(Glb+6,0);
       Wr32(Glb+10,0);Wr32(Glb+14,0);
       OV(0,CurProc);
       If Procs[CurProc].Name='' Then Procs[CurProc].Name:=ProcApName(ProgName);
      End;
  11: Begin
       If Procs[CurProc].QN>0 Then Begin PopMsg(CurProc,AI_(0));OV(0,1);End
       Else Wait(16);
      End;
  12: Begin
       K:=IV(0);
       If (K>=0) And (K<MAXPROC) And Procs[K].Used Then Begin
        A:=AI_(0);
        PostMsg(K,Rd16(A),Rd16(A+6),Rd16(A+8),Rd16(A+10),Rd16(A+12),Rd16(A+14),CurProc);
        For I:=0 To 7 Do Procs[K].Q[Procs[K].QN,I]:=SExt(Rd16(A+I*2),2);
        OV(0,1);
       End Else OV(0,0);
      End;
  13: Begin
       S:=Upper(TrimS(RdStr(AI_(0),9)));
       OV(0,-1);
       For I:=0 To MAXPROC-1 Do
        If Procs[I].Used And (Upper(Procs[I].Name)=S) Then OV(0,I);
      End;
  14: Begin
       { appl_tplay : relit les evenements enregistres }
       A:=AI_(0);Cl:=IV(0);
       If (A=0) Or (Cl<=0) Then OV(0,0)
       Else Begin
        PlayMem:=A;PlayCnt:=Cl;PlayPos:=0;PlayScale:=Max2(1,IV(1));PlayWait:=False;
        SynthX:=GMouseX;SynthY:=GMouseY;SynthB:=GMouseB;
        SynthMouse:=Not BatchMode;
        Wait(128);
       End;
      End;
  15: Begin
       { appl_trecord : enregistre les evenements utilisateur }
       A:=AI_(0);Cl:=IV(0);
       If (A=0) Or (Cl<=0) Or BatchMode Then OV(0,0)
       Else Begin
        RecMem:=A;RecCnt:=Cl;RecPos:=0;RecLast:=MsNow;RecActive:=True;
        Wait(64);
       End;
      End;
  19: OV(0,1);
  20: Wait(1);
  21: Begin
       Wait(2);
       Procs[CurProc].WClicks:=IV(0);Procs[CurProc].WMask:=IV(1);Procs[CurProc].WState:=IV(2);
      End;
  22: Begin
       Wait(Ord(IV(0)=0)*4+Ord(IV(0)<>0)*4);
       Procs[CurProc].WM1F:=IV(0);Procs[CurProc].WM1:=RectMake(IV(1),IV(2),IV(3),IV(4));
      End;
  23: Wait(16);
  24: Begin
       Wait(32);
       Procs[CurProc].WDeadline:=MsNow+((LongInt(Rd16(Ii+2)) Shl 16) Or Rd16(Ii));
      End;
  25: Begin
       Fl:=IV(0);
       Wait(Fl And $3F);
       With Procs[CurProc] Do Begin
        WClicks:=IV(1);WMask:=IV(2);WState:=IV(3);
        WM1F:=IV(4);WM1:=RectMake(IV(5),IV(6),IV(7),IV(8));
        WM2F:=IV(9);WM2:=RectMake(IV(10),IV(11),IV(12),IV(13));
        WDeadline:=MsNow+((LongInt(Rd16(Ii+30)) Shl 16) Or Rd16(Ii+28));
       End;
      End;
  26: Begin
       If IV(1)<>0 Then DClickSpeed:=Clamp(IV(0),0,4);
       OV(0,DClickSpeed);
      End;
  { ---- menus ---- }
  30: Begin
       T:=AI_(0);
       Case IV(0) Of
        0: Begin
            If MenuTree<>0 Then Begin MenuTree:=0;Repaint(RectMake(0,0,SW,MenuH),True);End;
            OV(0,1);
           End;
        1: Begin
            MenuTree:=T;MenuOwner:=CurProc;MenuBar:=OHead(T,0);
            I:=OY(T,MenuBar)+OH(T,MenuBar)+OY(T,0);
            MenuH:=Max2(19,I+1);
            InstallAccItems(T);
            Repaint(RectMake(0,0,SW,SH),True);
            OV(0,1);
           End;
       Else OV(0,MenuOwner);
       End;
      End;
  31: Begin
       T:=AI_(0);I:=IV(0);
       If IV(1)<>0 Then SetOState(T,I,OState(T,I) Or OS_CHECKED) Else SetOState(T,I,OState(T,I) And Not OS_CHECKED);
       OV(0,1);
      End;
  32: Begin
       T:=AI_(0);I:=IV(0);
       If IV(1)<>0 Then SetOState(T,I,OState(T,I) And Not OS_DISABLED) Else SetOState(T,I,OState(T,I) Or OS_DISABLED);
       OV(0,1);
      End;
  33: Begin
       T:=AI_(0);I:=IV(0);
       If IV(1)<>0 Then SetOState(T,I,OState(T,I) And Not OS_SELECTED) Else SetOState(T,I,OState(T,I) Or OS_SELECTED);
       If T=MenuTree Then Begin DrawMenuBarNow;If Not BatchMode Then BlitScreen(False);End;
       OV(0,1);
      End;
  34: Begin
       T:=AI_(0);I:=IV(0);
       S:=RdStr(AI_(1),60);
       A:=Rd32(OA(T,I)+12);
       WrStr(A,S);
       OV(0,1);
      End;
  35: Begin
       S:=RdStr(AI_(0),40);
       OV(0,RegisterAcc(IV(0),S));
      End;
  36: Begin
       If Rd16(Ctl+6)>=2 Then Begin
        { menu_popup(me,x,y,mdata) }
        A:=AI_(0);B:=AI_(1);
        T:=Rd32(A);I:=SExt(Rd16(A+4),2);K:=SExt(Rd16(A+6),2);
        If K<=0 Then Begin J:=IStartFind(T,I);If J>0 Then K:=IStartItem[J];End;
        If PopupMenu(T,I,IV(0),IV(1),K,False) Then Begin
         If B<>0 Then CopyMenuStruct(B,PopTree,PopMenuIdx,PopSel,SExt(Rd16(A+8),2));
         OV(0,1);
        End Else Begin
         If B<>0 Then CopyMenuStruct(B,T,I,-1,SExt(Rd16(A+8),2));
         OV(0,0);
        End;
       End Else Begin
        { menu_unregister }
        K:=IV(0);
        If K=-1 Then K:=Procs[CurProc].MenuId;
        If (K>=0) And (K<=5) Then Begin
         AccProc[K]:=-1;AccStr[K]:=0;
         If (MenuTree<>0) And (AccSlots[K]>=0) Then
          SetOState(MenuTree,AccSlots[K],OState(MenuTree,AccSlots[K]) Or OS_DISABLED);
         Procs[CurProc].MenuId:=-1;
        End;
        OV(0,1);
       End;
      End;
  37: Begin
       { menu_attach(flag,tree,item,mdata) }
       T:=AI_(0);B:=AI_(1);I:=IV(1);J:=FindAttach(T,I);OV(0,0);
       Case IV(0) Of
        0: If (J>0) And (B<>0) Then Begin
            CopyMenuStruct(B,AttachSub[J],AttachBox[J],AttachSubItem[J],0);OV(0,1);
           End;
        1: If B=0 Then Begin
            If J>0 Then Begin
             AttachTree[J]:=AttachTree[AttachN];AttachItem[J]:=AttachItem[AttachN];AttachSub[J]:=AttachSub[AttachN];
             AttachBox[J]:=AttachBox[AttachN];AttachSubItem[J]:=AttachSubItem[AttachN];Dec(AttachN);
            End;
            OV(0,1);
           End Else Begin
            If J=0 Then Begin
             If AttachN<16 Then Begin Inc(AttachN);J:=AttachN;End;
            End;
            If J>0 Then Begin
             AttachTree[J]:=T;AttachItem[J]:=I;AttachSub[J]:=Rd32(B);
             AttachBox[J]:=SExt(Rd16(B+4),2);AttachSubItem[J]:=SExt(Rd16(B+6),2);
             OV(0,1);
            End;
           End;
        2: If J>0 Then Begin
            AttachTree[J]:=AttachTree[AttachN];AttachItem[J]:=AttachItem[AttachN];AttachSub[J]:=AttachSub[AttachN];
            AttachBox[J]:=AttachBox[AttachN];AttachSubItem[J]:=AttachSubItem[AttachN];Dec(AttachN);
            OV(0,1);
           End;
       End;
      End;
  38: Begin
       { menu_istart(flag,tree,imenu,item) }
       T:=AI_(0);I:=IV(1);J:=IStartFind(T,I);
       If IV(0)=0 Then Begin
        If J>0 Then OV(0,IStartItem[J]) Else OV(0,0);
       End Else Begin
        If J=0 Then Begin If IStartN<16 Then Begin Inc(IStartN);J:=IStartN;End;End;
        If J>0 Then Begin IStartTree[J]:=T;IStartMenu[J]:=I;IStartItem[J]:=IV(2);OV(0,IV(2));End Else OV(0,0);
       End;
      End;
  39: Begin
       { menu_settings(flag,set) }
       A:=AI_(0);
       If A<>0 Then Begin
        If IV(0)=0 Then Begin
         For J:=0 To 3 Do Wr32(A+J*4,MenuSet[J]);
         Wr16(A+16,MenuSet[4]);
        End Else Begin
         For J:=0 To 3 Do MenuSet[J]:=Rd32(A+J*4);
         MenuSet[4]:=SExt(Rd16(A+16),2);
        End;
       End;
       OV(0,1);
      End;
  { ---- objets ---- }
  40: Begin ObjAdd(AI_(0),IV(0),IV(1));OV(0,1);End;
  41: Begin ObjDelete(AI_(0),IV(0));OV(0,1);End;
  42: Begin
       ObjDraw(AI_(0),IV(0),IV(1),IV(2),IV(3),IV(4),IV(5));
       OV(0,1);
      End;
  43: OV(0,ObjFind(AI_(0),IV(0),IV(1),IV(2),IV(3)));
  44: Begin ObjOffset(AI_(0),IV(0),X,Y);OV(0,1);OV(1,X);OV(2,Y);End;
  45: Begin ObjOrder(AI_(0),IV(0),IV(1));OV(0,1);End;
  46: Begin
       K:=IV(2);
       OV(0,ObjEdit(AI_(0),IV(0),IV(1),K,IV(3)));
       OV(1,K);
      End;
  47: Begin
       T:=AI_(0);I:=IV(0);
       SetOState(T,I,IV(6));
       If IV(7)<>0 Then Begin
        ObjOffset(T,I,X,Y);
        SetClip(IV(2),IV(3),IV(2)+IV(4)-1,IV(3)+IV(5)-1);
        ObjDrawRec(T,I,0,X,Y,IV(2),IV(3),IV(2)+IV(4)-1,IV(3)+IV(5)-1);
        SetClip(0,0,SW-1,SH-1);
       End;
       OV(0,1);
      End;
  { ---- formulaires ---- }
  50: OV(0,FormDo(AI_(0),IV(0)));
  51: Begin
       Case IV(0) Of
        0: Begin End;
        1: GrowShrink(RectMake(IV(1),IV(2),IV(3),IV(4)),RectMake(IV(5),IV(6),IV(7),IV(8)));
        2: GrowShrink(RectMake(IV(5),IV(6),IV(7),IV(8)),RectMake(IV(1),IV(2),IV(3),IV(4)));
        3: Repaint(RectMake(IV(5)-4,IV(6)-4,IV(7)+10,IV(8)+10),True);
       End;
       OV(0,1);
      End;
  52: OV(0,FormAlert(IV(0),RdStr(AI_(0),250)));
  53: OV(0,FormAlert(1,FormErrorText(IV(0))));
  54: Begin
       T:=AI_(0);
       W:=OW(T,0);Hh:=OH(T,0);
       X:=(SW-W) Div 2;Y:=MenuH+(SH-MenuH-Hh) Div 2;
       Wr16(OA(T,0)+16,X);Wr16(OA(T,0)+18,Y);
       OV(0,1);OV(1,X-4);OV(2,Y-4);OV(3,W+8);OV(4,Hh+8);
      End;
  55: Begin OV(0,1);OV(1,IV(1));OV(2,IV(2));End;
  56: Begin OV(0,1);OV(1,IV(1));End;
  { ---- graf ---- }
  70: Begin
       RubberBox(IV(0),IV(1),IV(2),IV(3),W,Hh);
       OV(0,1);OV(1,W);OV(2,Hh);
      End;
  71: Begin
       R:=RectMake(IV(4),IV(5),IV(6),IV(7));
       DragBox(IV(0),IV(1),IV(2),IV(3),R,X,Y);
       OV(0,1);OV(1,X);OV(2,Y);
      End;
  72: Begin GrowShrink(RectMake(IV(0),IV(1),IV(2),IV(3)),RectMake(IV(4),IV(5),IV(2),IV(3)));OV(0,1);End;
  73: Begin GrowShrink(RectMake(IV(0),IV(1),IV(2),IV(3)),RectMake(IV(4),IV(5),IV(6),IV(7)));OV(0,1);End;
  74: Begin GrowShrink(RectMake(IV(4),IV(5),IV(6),IV(7)),RectMake(IV(0),IV(1),IV(2),IV(3)));OV(0,1);End;
  75: Begin
       T:=AI_(0);
       If WatchBox(T,IV(1),IV(2),IV(3)) Then OV(0,1) Else OV(0,0);
      End;
  76: OV(0,SlideBox(AI_(0),IV(0),IV(1),IV(2)));
  77: Begin OV(0,1);OV(1,8);OV(2,16);OV(3,8);OV(4,16);End;
  78: Begin
       K:=IV(0);
       Case K Of
        256: Begin Inc(MouseHidden);End;
        257: Begin If MouseHidden>0 Then Dec(MouseHidden);End;
        255: Begin
              A:=AI_(0);
              CurHotX:=Clamp(SExt(Rd16(A),2),0,15);CurHotY:=Clamp(SExt(Rd16(A+2),2),0,15);
              For I:=0 To 15 Do Begin
               CurMask[I]:=Rd16(A+10+I*2);CurData[I]:=Rd16(A+42+I*2);
              End;
             End;
       Else SetMouseShape(K);
       End;
       {$IFDEF FPC}
       If GfxOn Then Begin If MouseHidden>0 Then HideMouse Else CursorDraw(MX,MY);End;
       {$ENDIF}
       OV(0,1);
      End;
  79: Begin OV(0,1);OV(1,GMouseX);OV(2,GMouseY);OV(3,GMouseB);OV(4,0);End;
  80: Begin
       { scrp_read }
       If ScrapSet Then Begin ScrapMakeDir;WrStr(AI_(0),ScrapDir);OV(0,1);End
       Else Begin Wr8(AI_(0),0);OV(0,0);End;
      End;
  81: Begin
       { scrp_write }
       ScrapDir:=RdStr(AI_(0),120);ScrapSet:=ScrapDir<>'';
       If ScrapSet Then ScrapMakeDir;
       OV(0,1);
      End;
  82: Begin
       { scrp_clear }
       If ScrapSet Then ScrapClear;
       OV(0,1);
      End;
  90,91: Begin
       S:='File selector';
       If Op=91 Then S:=RdStr(AI_(2),40);
       If AesFsel(AI_(0),AI_(1),S) Then Begin OV(0,1);OV(1,1);End Else Begin OV(0,1);OV(1,0);End;
      End;
  { ---- fenetres ---- }
  100: Begin
        OV(0,WinCreate(IV(0),RectMake(IV(1),IV(2),IV(3),IV(4))));
       End;
  101: Begin WinOpen(IV(0),RectMake(IV(1),IV(2),IV(3),IV(4)));OV(0,1);End;
  102: Begin WinClose(IV(0));OV(0,1);End;
  103: Begin WinDelete(IV(0));OV(0,1);End;
  104: WindGet(IV(0),IV(1),Io);
  105: Begin WindSet(IV(0),IV(1),Ii);OV(0,1);End;
  106: OV(0,WinFind(IV(0),IV(1)));
  107: Begin
        Case IV(0) Of
         1: Inc(UpdateLevel);
         0: If UpdateLevel>0 Then Dec(UpdateLevel);
         3: Begin Inc(MCtrlLevel);MCtrlOwner:=CurProc;End;
         2: If MCtrlLevel>0 Then Dec(MCtrlLevel);
        End;
        OV(0,1);
       End;
  108: Begin
        If IV(0)=0 Then R:=OuterOf(IV(1),RectMake(IV(2),IV(3),IV(4),IV(5)))
        Else R:=WorkOf(IV(1),RectMake(IV(2),IV(3),IV(4),IV(5)));
        OV(0,1);OV(1,R.X);OV(2,R.Y);OV(3,R.W);OV(4,R.H);
       End;
  109: OV(0,1);
  { ---- ressources ---- }
  110: Begin
        S:=RdStr(AI_(0),100);
        If RscLoad(S) Then Begin
         OV(0,1);
         Wr32(Glb+10,RscBase+Rd16(RscBase+18));
        End Else OV(0,0);
       End;
  111: Begin
        If RscLoaded Then DoMfree(RscBase);RscLoaded:=False;OV(0,1);
       End;
  112: Begin
        If RscGaddr(IV(0),IV(1),A) Then Begin Wr32(Ao,A);OV(0,1);End Else Begin Wr32(Ao,0);OV(0,0);End;
       End;
  113: Begin
        A:=AI_(0);
        If RscLoaded Then Begin
         Case IV(0) Of
          0: Wr32(RscBase+Rd16(RscBase+18)+IV(1)*4,A);
          5,15: Wr32(Rd16(RscBase+10)+RscBase+IV(1)*4,A);
         End;
        End;
        OV(0,1);
       End;
  114: Begin ObjFix(AI_(0),IV(0));OV(0,1);End;
  { ---- shell ---- }
  120: Begin
        WrStr(AI_(0),ShortName(ProgName));
        WrStr(AI_(1),Chr(Length(ProgCmd))+ProgCmd);
        OV(0,1);
       End;
  121: Begin
        ShelNext:=RdStr(AI_(0),128);ShelTail:=RdStr(AI_(1),128);
        OV(0,1);
       End;
  122: Begin
        { shel_get(len,buf) }
        A:=AI_(0);Cl:=Clamp(IV(0),0,4096);
        For I:=0 To Cl-1 Do Wr8(A+I,ShelBuf[I]);
        OV(0,1);
       End;
  123: Begin
        { shel_put(len,buf) }
        A:=AI_(0);Cl:=Clamp(IV(0),0,4096);
        For I:=0 To Cl-1 Do ShelBuf[I]:=Rd8(A+I);
        ShelLen:=Cl;
        OV(0,1);
       End;
  124: Begin
        S:=RdStr(AI_(0),128);
        If FileExists(HostPath(S)) Or FileExists(HostPath(ShortName(S))) Then OV(0,1) Else OV(0,0);
       End;
  125: Begin
        { shel_envrn(ppath,psrch) }
        Wr32(AI_(0),EnvLookup(RdStr(AI_(1),60)));
        OV(0,1);
       End;
  126: Begin
        { shel_rdef(cmd,dir) }
        WrStr(AI_(0),ShelDefCmd);WrStr(AI_(1),ShelDefDir);OV(0,1);
       End;
  127: Begin
        { shel_wdef(cmd,dir) }
        ShelDefCmd:=RdStr(AI_(0),127);ShelDefDir:=RdStr(AI_(1),127);OV(0,1);
       End;
 Else OV(0,0);
 End;
End;


{ ---------------------------------------------------------------------- }
{ Contexte AES propre a un fils lance par Pexec                            }
{ ---------------------------------------------------------------------- }

Type
 TGemSave = Record
  Proc : Integer;
  MTree,DTree : LongInt;
  MOwner,MBar,MH,DStart : Integer;
  Rsc  : LongInt;
  RscOk : Boolean;
  PName,PCmd : String;
  Child : Integer;
 End;

{ Cree le processus AES du fils : il aura son propre ap_id, sa propre barre de
  menus, ses fenetres et son fichier ressource ; le contexte du pere est
  sauvegarde et restitue a la fin }
Procedure GemChildEnter(Var S: TGemSave; Const Name,Cmd: String);
Var K: Integer;
Begin
 S.Proc:=CurProc;S.MTree:=MenuTree;S.DTree:=DeskTree;S.MOwner:=MenuOwner;S.MBar:=MenuBar;
 S.MH:=MenuH;S.DStart:=DeskStart;S.Rsc:=RscBase;S.RscOk:=RscLoaded;S.PName:=ProgName;S.PCmd:=ProgCmd;
 S.Child:=-1;
 If Name<>'' Then ProgName:=Name;
 ProgCmd:=Cmd;
 RscLoaded:=False;
 If Emu_GEM And AesActive Then Begin
  K:=NewProc(ProgName,False);
  If K>=0 Then Begin
   Procs[K].Started:=True;
   S.Child:=K;CurProc:=K;
   { la barre de menus et le bureau du pere ne sont retires qu'au appl_init du fils }
   Procs[K].Fresh:=True;
  End;
 End;
End;

{ Supprime tout ce qui appartient au fils et restitue le contexte du pere }
Procedure GemChildLeave(Var S: TGemSave);
Var K,H,I: Integer; Redraw: Boolean;
Begin
 K:=S.Child;
 Redraw:=False;
 If (K>=0) And Not Procs[K].Fresh Then Redraw:=True;
 If K>=0 Then Begin
  For H:=1 To MAXWIN-1 Do
   If Wins[H].Used And (Wins[H].Owner=K) Then Begin
    If Wins[H].Open Then Redraw:=True;
    Wins[H].Open:=False;ZRemove(H);Wins[H].Used:=False;
   End;
  For I:=2 To MAXVWK Do If Vd[I].Used And (Vd[I].Owner=K) Then Vd[I].Used:=False;
  For I:=0 To 5 Do
   If AccProc[I]=K Then Begin AccProc[I]:=-1;AccStr[I]:=0;End;
  If MCtrlOwner=K Then Begin MCtrlLevel:=0;MCtrlOwner:=-1;End;
  If MenuOwner=K Then MenuTree:=0;
  Procs[K].Used:=False;Procs[K].Blocked:=False;
  If LastRun=K Then LastRun:=S.Proc;
 End;
 If RscLoaded Then Begin
  If RscBase<>S.Rsc Then DoMfree(RscBase);
 End;
 RscBase:=S.Rsc;RscLoaded:=S.RscOk;
 CurProc:=S.Proc;
 MenuTree:=S.MTree;DeskTree:=S.DTree;MenuOwner:=S.MOwner;MenuBar:=S.MBar;MenuH:=S.MH;DeskStart:=S.DStart;
 ProgName:=S.PName;ProgCmd:=S.PCmd;
 ButtonTaken:=False;
 If Redraw And Not BatchMode And GfxOn Then Repaint(RectMake(0,0,SW,SH),True);
End;
{ ---------------------------------------------------------------------- }
{ Interruptions de l'emulateur                                            }
{ ---------------------------------------------------------------------- }

Procedure DoTrap(N: Integer);
Begin
 If AmigaRun And (N<>1) Then Begin
  RaiseExc(32+N);Exit;
 End;
 Case N Of
  1: Gemdos;
  2: Begin
      If Not Emu_GEM Then Halt68('GEM is not available (Run with GEM is off)')
      Else If (Rg[0] And $FFFF)=$73 Then Begin VdiOwnerProc:=CurProc;Vdi(Rg[1]);End
      Else If (Rg[0] And $FFFF)=$C8 Then Aes(Rg[1]);
     End;
  13: Bios;
  14: Xbios;
 Else RaiseExc(32+N);
 End;
End;

Const
 LA_PTSIN  = LINEA_VARS+$300;
 LA_INTIN  = LINEA_VARS+$400;
 LA_CONTRL = LINEA_VARS+$440;

Procedure LineAInit;
Var I: Integer;
Begin
 For I:=0 To 130 Do Wr8(LINEA_VARS+I,0);
 Wr16(LINEA_VARS,1);Wr16(LINEA_VARS+2,80);
 Wr32(LINEA_VARS+4,LA_CONTRL);Wr32(LINEA_VARS+8,LA_INTIN);Wr32(LINEA_VARS+12,LA_PTSIN);
 Wr32(LINEA_VARS+16,LA_INTIN+$40);Wr32(LINEA_VARS+20,LA_PTSIN+$40);
 Wr16(LINEA_VARS+24,1);Wr16(LINEA_VARS+34,$FFFF);Wr16(LINEA_VARS+36,0);
 Wr16(LINEA_VARS+56,0);Wr16(LINEA_VARS+58,0);Wr16(LINEA_VARS+60,639);Wr16(LINEA_VARS+62,399);
 Rg[0]:=LINEA_VARS;Rg[8]:=LINEA_VARS;
 Rg[9]:=LINEA_VARS+$100;Rg[10]:=LINEA_VARS+$200;
End;

Procedure DoLineA(Op: LongInt);
Var F: Integer; X1,Y1,X2,Y2,Col,Y,Wm: Integer; Bc: LongInt; Src,Dst: TMfdb; A,Pa: LongInt;
    W,H,Mode,XX,YY: Integer; Sb,Db: Boolean; Ot: Integer;
Begin
 F:=Op And $FFF;
 SelVdi(0);
 If F>0 Then CheckFonts;
 X1:=SExt(Rd16(LINEA_VARS+38),2);Y1:=SExt(Rd16(LINEA_VARS+40),2);
 X2:=SExt(Rd16(LINEA_VARS+42),2);Y2:=SExt(Rd16(LINEA_VARS+44),2);
 Col:=Rd16(LINEA_VARS+24) And 1;
 Wm:=Rd16(LINEA_VARS+36);
 If Wm=0 Then VP^.WrMode:=WM_REPL Else If Wm=2 Then VP^.WrMode:=WM_XOR Else VP^.WrMode:=WM_TRANS;
 VP^.LineCol:=Col;VP^.LineWidth:=1;VP^.LineType:=7;VP^.LineUd:=Rd16(LINEA_VARS+34);
 VP^.FillInt:=1;VP^.FillCol:=Col;VP^.FillPer:=0;
 SetClip(0,0,SW-1,SH-1);
 If Rd16(LINEA_VARS+54)<>0 Then
  SetClip(SExt(Rd16(LINEA_VARS+56),2),SExt(Rd16(LINEA_VARS+58),2),SExt(Rd16(LINEA_VARS+60),2),SExt(Rd16(LINEA_VARS+62),2));
 Case F Of
  0: LineAInit;
  1: Begin
      X1:=SExt(Rd16(Rd32(LINEA_VARS+12)),2);Y1:=SExt(Rd16(Rd32(LINEA_VARS+12)+2),2);
      PlotPat(X1,Y1,True,ColBit(Rd16(Rd32(LINEA_VARS+8))));
     End;
  2: Begin
      X1:=SExt(Rd16(Rd32(LINEA_VARS+12)),2);Y1:=SExt(Rd16(Rd32(LINEA_VARS+12)+2),2);
      Rg[0]:=Ord(BGet(X1,Y1));
     End;
  3: Begin LinePhase:=0;VLine(X1,Y1,X2,Y2);End;
  4: Begin LinePhase:=0;VLine(X1,Y1,X2,Y1);End;
  5: Begin
      If Rd32(LINEA_VARS+46)<>0 Then Begin
       VP^.FillInt:=4;
       For Y:=0 To 15 Do VP^.UdPat[Y]:=Rd16(Rd32(LINEA_VARS+46)+(Y And ((Rd16(LINEA_VARS+50)+1)*0+15))*2);
      End;
      For Y:=Y1 To Y2 Do FillSpanPat(Y,X1,X2);
     End;
  7: Begin
      A:=Rg[14];
      W:=Rd16(A)+0;H:=SExt(Rd16(A+2),2);
      Src.Addr:=Rd32(A+18);Src.WW:=SExt(Rd16(A+22),2) Div 2;Src.Planes:=1;
      Dst.Addr:=Rd32(A+32);Dst.WW:=SExt(Rd16(A+36),2) Div 2;Dst.Planes:=1;
      Ot:=Rd8(A+10);
      If Src.Addr=0 Then Src.Addr:=0;
      For YY:=0 To H-1 Do
       For XX:=0 To W-1 Do Begin
        Sb:=MBit(Src,SExt(Rd16(A+14),2)+XX,SExt(Rd16(A+16),2)+YY);
        Db:=MBit(Dst,SExt(Rd16(A+28),2)+XX,SExt(Rd16(A+30),2)+YY);
        MPut(Dst,SExt(Rd16(A+28),2)+XX,SExt(Rd16(A+30),2)+YY,RopBit(Rd8(A+10+(Ord(Sb)*2) And 3) And 15,Sb,Db));
       End;
     End;
  9: Begin MouseHidden:=Max2(0,MouseHidden-1);End;
  10: Inc(MouseHidden);
  11: Begin
       A:=Rg[8];
       CurHotX:=Clamp(SExt(Rd16(A),2),0,15);CurHotY:=Clamp(SExt(Rd16(A+2),2),0,15);
       For Y:=0 To 15 Do Begin CurMask[Y]:=Rd16(A+10+Y*2);CurData[Y]:=Rd16(A+42+Y*2);End;
      End;
  12,13: Begin End;
 End;
 SetClip(0,0,SW-1,SH-1);
 VP^.WrMode:=WM_REPL;
End;

{ ---------------------------------------------------------------------- }
{ AmigaOS simplifie : exec.library, dos.library                           }
{ ---------------------------------------------------------------------- }

Procedure AmigaCall(Base: LongInt; Off: LongInt);
Var Lib: Integer; R,A,N: LongInt; S: String; I: LongInt; Buf: Array[0..4095] Of Byte; Got: LongInt; H: Integer;
Begin
 R:=0;
 If Base=EXECBASE Then Begin
  Case Off Of
   -552: Begin
          S:=Upper(RdStr(Rg[9],40));
          If S='DOS.LIBRARY' Then R:=DOSBASE
          Else If S='INTUITION.LIBRARY' Then R:=INTUIBASE
          Else If S='GRAPHICS.LIBRARY' Then R:=GFXBASE
          Else R:=0;
         End;
   -198: Begin
          R:=DoMalloc(Rg[0]);
          If (R<>0) And ((Rg[1] And $10000)<>0) Then
           For I:=0 To Rg[0]-1 Do Wr8(R+I,0);
         End;
   -684: R:=DoMalloc(Rg[0]);
   -210: Begin DoMfree(Rg[9]);End;
   -690: Begin DoMfree(Rg[9]);End;
   -294: R:=$2800;
  Else R:=0;
  End;
 End Else If Base=DOSBASE Then Begin
  Case Off Of
   -30: Begin
         S:=HostPath(RdStr(Rg[1],200));
         H:=AllocFH;
         If H=0 Then R:=0
         Else Begin
          Assign(FHs[H],S);
          {$I-}
          If Rg[2]=1006 Then Rewrite(FHs[H],1) Else Begin FileMode:=0;Reset(FHs[H],1);End;
          {$I+}
          If IOResult<>0 Then R:=0 Else Begin FHUsed[H]:=True;R:=H;End;
         End;
        End;
   -36: Begin
         H:=Rg[1];
         If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
          {$I-}
          Close(FHs[H]);
          {$I+}
          If IOResult=0 Then Begin End;
          FHUsed[H]:=False;R:=-1;
         End;
        End;
   -42: Begin
         H:=Rg[1];N:=Rg[3];A:=Rg[2];
         If H=1 Then Begin
          R:=0;
          While R<N Do Begin
           Got:=WaitKeyEmu;
           If UserBreak Then Break;
           Wr8(A+R,Got And $FF);Inc(R);ConPut(Got And $FF);
           If (Got And $FF)=13 Then Begin ConPut(10);Break;End;
          End;
         End Else If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
          If N>4096 Then N:=4096;
          {$I-}
          BlockRead(FHs[H],Buf,N,Got);
          {$I+}
          If IOResult<>0 Then Got:=0;
          For I:=0 To Got-1 Do Wr8(A+I,Buf[I]);
          R:=Got;
         End Else R:=-1;
        End;
   -48: Begin
         H:=Rg[1];N:=Rg[3];A:=Rg[2];
         If (H=1) Or (H=2) Then Begin
          For I:=0 To N-1 Do ConPut(Rd8(A+I));
          R:=N;
         End Else If (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
          If N>4096 Then N:=4096;
          For I:=0 To N-1 Do Buf[I]:=Rd8(A+I);
          {$I-}
          BlockWrite(FHs[H],Buf,N,Got);
          {$I+}
          If IOResult<>0 Then Got:=0;
          R:=Got;
         End Else R:=-1;
        End;
   -54: R:=1;
   -60: R:=2;
   -72: Begin
         S:=HostPath(RdStr(Rg[1],200));
         Assign(FHs[6],S);
         {$I-}
         Erase(FHs[6]);
         {$I+}
         If IOResult=0 Then R:=-1 Else R:=0;
        End;
   -144: Begin StopReason:=STOP_EXIT;ExitCode:=Rg[1];End;
   -198: Delay(Rg[1]*20);
   -948: Begin
          A:=Rg[1];N:=0;
          While (Rd8(A+N)<>0) And (N<30000) Do Begin ConPut(Rd8(A+N));Inc(N);End;
         End;
  Else R:=0;
  End;
 End;
 Rg[0]:=R;
End;

Procedure HleLibCheck;
Begin
 If Not AmigaRun Then Exit;
 If (PC<AMIGA_LO) Or (PC>=AMIGA_HI) Then Exit;
 If (PC>=EXECBASE-1024) And (PC<EXECBASE) Then AmigaCall(EXECBASE,PC-EXECBASE)
 Else If (PC>=DOSBASE-1024) And (PC<DOSBASE) Then AmigaCall(DOSBASE,PC-DOSBASE)
 Else Rg[0]:=0;
 PC:=PopL;
End;

{ ---------------------------------------------------------------------- }
{ Chargement des programmes                                               }
{ ---------------------------------------------------------------------- }

Procedure EmuReset;
Var I: Integer;
Begin
 CpuReset;
 SingleStack:=True;
 ClearMemory;
 ScrBase:=(MemSize-SCR_BYTES) And $FFFF00;DrawBase:=ScrBase;
 HitPa:=(ScrBase-$1000) And $FFFF00;
 HeapLo:=BP_ADDR+$100;HeapHi:=HitPa-$4000;
 MCnt:=0;DtaAddr:=BP_ADDR+$80;DtaActive:=False;
 CloseAllFiles;
 ConRow:=0;ConCol:=0;ConRev:=False;ConWrap:=True;ConCurOn:=True;ConState:=0;
 KQHead:=0;KQTail:=0;UserBreak:=False;
 NBps:=0;DbgN:=0;UnknownCall:='';
 AmigaRun:=False;
 GemReset;
 DevInitAll;EnvInit;
 SysTablesInit;
 UserCursor:=False;RecActive:=False;
 ScrDirtyLo:=0;ScrDirtyHi:=399;
 { stub de sortie : clr.w -(sp) ; trap #1 }
 Wr16(STUB_EXIT,$4267);Wr16(STUB_EXIT+2,$4E41);
 { stub Supexec : andi #$DFFF,sr ; rts }
 Wr16(STUB_USER,$027C);Wr16(STUB_USER+2,$DFFF);Wr16(STUB_USER+4,$4E75);
 FillChar(ScrShadow,SizeOf(ScrShadow),$FF);
End;

{ Charge une image PRG dans la page de base Bp ; TB = debut du texte, EndA = fin du BSS }
Function LoadPRGImage(P: Pointer; Len: LongInt; Const CmdLine: String; Bp: LongInt;
                      WantSyms: Boolean; Var TB,EndA,TextSz: LongInt): Boolean;
Var TS,DS,BS,SS,I,Off,Cur,Sym,Typ,B: LongInt; Name: String; J: Integer;
Begin
 LoadPRGImage:=False;
 If (Len<28) Or (BufW(P,0)<>$601A) Then Exit;
 TS:=BufL(P,2);DS:=BufL(P,6);BS:=BufL(P,10);SS:=BufL(P,14);
 TB:=Bp+$100;
 EndA:=TB+TS+DS+BS;
 If EndA>HeapHi Then Exit;
 TextSz:=TS+DS;
 For I:=0 To TS+DS-1 Do Wr8(TB+I,BufB(P,28+I));
 For I:=0 To BS-1 Do Wr8(TB+TS+DS+I,0);
 Off:=28+TS+DS+SS;
 If Off+4<=Len Then Begin
  Cur:=BufL(P,Off);Inc(Off,4);
  If Cur<>0 Then Begin
   Wr32(TB+Cur,Rd32(TB+Cur)+TB);
   While Off<Len Do Begin
    B:=BufB(P,Off);Inc(Off);
    If B=0 Then Break;
    If B=1 Then Cur:=Cur+254
    Else Begin Cur:=Cur+B;Wr32(TB+Cur,Rd32(TB+Cur)+TB);End;
   End;
  End;
 End;
 If WantSyms Then Begin
  DbgN:=0;
  Sym:=28+TS+DS;
  While (SS>=14) And (Sym+14<=28+TS+DS+SS) Do Begin
   Name:='';
   For J:=0 To 7 Do If BufB(P,Sym+J)<>0 Then Name:=Name+Chr(BufB(P,Sym+J));
   Typ:=BufW(P,Sym+8);
   If (Typ And $0048)=$0048 Then Begin
    For J:=0 To 13 Do If BufB(P,Sym+14+J)<>0 Then Name:=Name+Chr(BufB(P,Sym+14+J));
    DbgAdd(Name,BufL(P,Sym+10)+TB);
    Inc(Sym,28);
   End Else Begin
    If (Typ And $8000)<>0 Then DbgAdd(Name,BufL(P,Sym+10)+TB);
    Inc(Sym,14);
   End;
  End;
 End;
 For I:=0 TO 255 Do Wr8(Bp+I,0);
 Wr32(Bp,Bp);Wr32(Bp+4,EndA);
 Wr32(Bp+8,TB);Wr32(Bp+12,TS);
 Wr32(Bp+16,TB+TS);Wr32(Bp+20,DS);
 Wr32(Bp+24,TB+TS+DS);Wr32(Bp+28,BS);
 Wr32(Bp+32,Bp+$80);Wr32(Bp+36,BP_ADDR);Wr32(Bp+44,ENV_BLK);
 Wr8(Bp+$80,Length(CmdLine));
 For J:=1 To Length(CmdLine) Do Wr8(Bp+$80+J,Ord(CmdLine[J]));
 Wr8(Bp+$F0,0);
 LoadPRGImage:=True;
End;

Function LoadPRG(P: Pointer; Len: LongInt; Const CmdLine: String): Boolean;
Var TB,EndA,TSz,Sp: LongInt;
Begin
 LoadPRG:=False;
 If Not LoadPRGImage(P,Len,CmdLine,BP_ADDR,True,TB,EndA,TSz) Then Exit;
 Wr32(BP_ADDR+4,HitPa);
 HeapLo:=EndA;
 If Odd(HeapLo) Then Inc(HeapLo);
 Sp:=HitPa-8;
 Wr32(Sp,STUB_EXIT);Wr32(Sp+4,BP_ADDR);
 Rg[15]:=Sp;USPv:=Sp;SSPv:=$7000;
 PC:=TB;SRv:=0;
 LoadPRG:=True;
End;

Var
 OptAccs : Boolean;

Procedure LoadOneAcc(Const F: String);
Var P: Pointer; Len,Bp,TB,EndA,TSz,Top: LongInt; K: Integer; Ok: Boolean;
Begin
 If Not ReadFileBytes(F,P,Len) Then Exit;
 Bp:=(HeapLo+255) And Not 255;
 Ok:=LoadPRGImage(P,Len,'',Bp,False,TB,EndA,TSz);
 If P<>Nil Then FreeMem(P,Len);
 If Not Ok Then Exit;
 Top:=(EndA+$2000+255) And Not 255;
 If Top>=HeapHi Then Exit;
 K:=NewProc(F,True);
 If K<0 Then Exit;
 HeapLo:=Top;
 Wr32(Bp+4,Top);
 FillChar(Procs[K].Rgs,SizeOf(Procs[K].Rgs),0);
 Wr32(Top-8,STUB_EXIT);Wr32(Top-4,Bp);
 Procs[K].Rgs[15]:=Top-8;Procs[K].USPs:=Top-8;Procs[K].SSPs:=$7000;
 Procs[K].PCs:=TB;Procs[K].SRs:=0;Procs[K].BpAddr:=Bp;Procs[K].Started:=False;
End;

Procedure LoadAccessories;
Var SR: SearchRec; D1,D2: String; Seen: String;
 Procedure Scan(Const Dir: String);
 Begin
  FindFirst(Dir+'*.ACC',AnyFile,SR);
  While DosError=0 Do Begin
   If Pos('|'+Upper(SR.Name)+'|',Seen)=0 Then Begin
    Seen:=Seen+'|'+Upper(SR.Name)+'|';
    LoadOneAcc(Dir+SR.Name);
   End;
   FindNext(SR);
  End;
  {$IFDEF FPC}
  FindClose(SR);
  {$ENDIF}
  {$IFDEF UNIX}
  FindFirst(Dir+'*.acc',AnyFile,SR);
  While DosError=0 Do Begin
   If Pos('|'+Upper(SR.Name)+'|',Seen)=0 Then Begin
    Seen:=Seen+'|'+Upper(SR.Name)+'|';
    LoadOneAcc(Dir+SR.Name);
   End;
   FindNext(SR);
  End;
  FindClose(SR);
  {$ENDIF}
 End;
Begin
 Seen:='';
 D1:=PathOf(ProgName);
 Scan(D1);
 If D1<>'' Then Scan('');
End;

{ Demarre les accessoires : chacun s'execute jusqu'a son premier evenement }
Procedure GemBoot;
Var K: Integer; N: LongInt;
Begin
 RepaintAll;
 If Not BatchMode Then BlitScreen(True);
 SaveCtx(MainProc);
 For K:=0 To MAXPROC-1 Do
  If Procs[K].Used And Procs[K].IsAcc And Not Procs[K].Started Then Begin
   LoadCtx(K);CurProc:=K;Procs[K].Started:=True;
   StopReason:=STOP_NONE;N:=0;
   While (StopReason=STOP_NONE) And (N<200) Do Begin RunCpu(100000);Inc(N);End;
   If StopReason<>STOP_YIELD Then Begin Procs[K].Used:=False;End;
   StopReason:=STOP_NONE;
  End;
 LoadCtx(MainProc);CurProc:=MainProc;
 StopReason:=STOP_NONE;
 If Not BatchMode Then BlitScreen(False);
End;

Function LoadHunk(P: Pointer; Len: LongInt; Const CmdLine: String): Boolean;
Var Pos,NH,First,Last,I,Cur,T,Sz,N,Dst,Base,Nm: LongInt; HAddr,HSize: Array[0..15] Of LongInt;
    J: Integer; Name: String; Sp,Val: LongInt;
 Function NextL: LongInt;
 Begin
  If Pos+4>Len Then NextL:=0 Else NextL:=BufL(P,Pos);
  Inc(Pos,4);
 End;
Begin
 LoadHunk:=False;
 Pos:=0;
 If BufL(P,0)<>$3F3 Then Exit;
 Inc(Pos,4);
 While True Do Begin
  N:=NextL;
  If N=0 Then Break;
  Inc(Pos,N*4);
 End;
 NH:=NextL;First:=NextL;Last:=NextL;
 If (NH>16) Or (NH<=0) Then Exit;
 Base:=$20000;
 For I:=0 To Last-First Do Begin
  HSize[I]:=(NextL And $3FFFFFFF)*4;
  HAddr[I]:=Base;
  Base:=Base+HSize[I]+16;
  For J:=0 To HSize[I]-1 Do Wr8(HAddr[I]+J,0);
 End;
 If Base>HeapHi Then Exit;
 Cur:=0;DbgN:=0;
 While Pos<Len Do Begin
  T:=NextL And $3FFFFFFF;
  Case T Of
   $3E9,$3EA: Begin
               Sz:=NextL*4;
               For J:=0 To Sz-1 Do Wr8(HAddr[Cur]+J,BufB(P,Pos+J));
               Inc(Pos,Sz);
              End;
   $3EB: NextL;
   $3EC: Begin
          While True Do Begin
           N:=NextL;
           If N=0 Then Break;
           Dst:=NextL;
           For J:=1 To N Do Begin
            Sz:=NextL;
            Wr32(HAddr[Cur]+Sz,Rd32(HAddr[Cur]+Sz)+HAddr[Dst]);
           End;
          End;
         End;
   $3F0: Begin
          While True Do Begin
           N:=NextL And $FFFFFF;
           If N=0 Then Break;
           Name:='';
           For J:=0 To N*4-1 Do If BufB(P,Pos+J)<>0 Then Name:=Name+Chr(BufB(P,Pos+J));
           Inc(Pos,N*4);
           Val:=NextL;
           DbgAdd(Name,HAddr[Cur]+Val);
          End;
         End;
   $3F1: Begin Sz:=NextL*4;Inc(Pos,Sz);End;
   $3F2: Begin Inc(Cur);If Cur>Last-First Then Break;End;
  Else Break;
  End;
 End;
 HeapLo:=Base;
 AmigaRun:=True;
 Wr32(4,EXECBASE);
 Wr32(BP_ADDR+$80,0);
 For J:=1 To Length(CmdLine) Do Wr8(BP_ADDR+$80+J-1,Ord(CmdLine[J]));
 Sp:=HitPa-8;
 Wr32(Sp,STUB_EXIT);
 Wr16(STUB_EXIT,$3F00);Wr16(STUB_EXIT+2,$3F3C);Wr16(STUB_EXIT+4,$004C);Wr16(STUB_EXIT+6,$4E41);
 Rg[15]:=Sp;USPv:=Sp;SSPv:=$7000;
 Rg[0]:=Length(CmdLine);Rg[8]:=BP_ADDR+$80;Rg[14]:=EXECBASE;
 PC:=HAddr[0];SRv:=0;
 LoadHunk:=True;
End;


{ Pexec GEMDOS : charge et execute un programme fils }
Function DoPexec(Mode: Integer; NameP,CmdP,EnvP: LongInt): LongInt;
Var Nm,Cmd: String; P: Pointer; Len,Bp,TB,EndA,TSz,Top,SvHeap,Code: LongInt; Ok: Boolean;
    SvRg: Array[0..15] Of LongInt; SvPC,SvSR,SvUSP,SvSSP,SvOp: LongInt; I: Integer; SvProc: Integer;
 Procedure RunChild(B: LongInt; Const ChName,ChCmd: String);
 Var N: LongInt; Gs: TGemSave;
 Begin
  Move(Rg,SvRg,SizeOf(Rg));
  SvPC:=PC;SvSR:=SRv;SvUSP:=USPv;SvSSP:=SSPv;SvOp:=CurOpPC;SvProc:=CurProc;
  GemChildEnter(Gs,ChName,ChCmd);
  FillChar(Rg,SizeOf(Rg),0);
  Top:=Rd32(B+4);
  Rg[15]:=Top-8;Wr32(Top-8,STUB_EXIT);Wr32(Top-4,B);
  PC:=Rd32(B+8);SRv:=0;
  StopReason:=STOP_NONE;
  While (StopReason=STOP_NONE) Or (StopReason=STOP_YIELD) Do Begin
   RunCpu(20000);
   If StopReason=STOP_YIELD Then GemDispatch;
   PollKeys;
   If UserBreak Then StopReason:=STOP_USER;
  End;
  If StopReason=STOP_EXIT Then Code:=ExitCode Else Code:=-1;
  Move(SvRg,Rg,SizeOf(Rg));
  PC:=SvPC;SRv:=SvSR;USPv:=SvUSP;SSPv:=SvSSP;CurOpPC:=SvOp;
  GemChildLeave(Gs);
  CurProc:=SvProc;
  StopReason:=STOP_NONE;UserBreak:=False;
 End;
Begin
 DoPexec:=-33;
 Case Mode Of
  0,3,5: Begin
    If Mode=5 Then Begin
     Bp:=DoMalloc(256);
     If Bp=0 Then Begin DoPexec:=-39;Exit;End;
     For I:=0 To 255 Do Wr8(Bp+I,0);
     Wr32(Bp,Bp);Wr32(Bp+36,BP_ADDR);
     DoPexec:=Bp;Exit;
    End;
    Nm:=HostPath(RdStr(NameP,200));
    If CmdP<>0 Then Cmd:=RdStr(CmdP+1,Rd8(CmdP)) Else Cmd:='';
    If Not ReadFileBytes(Nm,P,Len) Then Exit;
    Bp:=(HeapLo+255) And Not 255;
    SvHeap:=HeapLo;
    Ok:=LoadPRGImage(P,Len,Cmd,Bp,False,TB,EndA,TSz);
    If P<>Nil Then FreeMem(P,Len);
    If Not Ok Then Begin DoPexec:=-66;Exit;End;
    Top:=(EndA+$1000+255) And Not 255;
    Wr32(Bp+4,Top);
    HeapLo:=Top;
    If Mode=3 Then Begin DoPexec:=Bp;Exit;End;
    RunChild(Bp,Nm,Cmd);
    HeapLo:=SvHeap;
    DoPexec:=Code;
   End;
  4,6: Begin
    Bp:=CmdP;
    SvHeap:=HeapLo;
    RunChild(Bp,'',RdStr(Bp+$81,Rd8(Bp+$80)));
    If Mode=6 Then HeapLo:=SvHeap;
    DoPexec:=Code;
   End;
 End;
End;

{ Charge un executable ST (.PRG) ou Amiga (Hunk) ; reinitialise l'emulateur }
Function LoadProgram(Const Name,CmdLine: String; GemOn: Boolean): Boolean;
Var P: Pointer; Len: LongInt; Ok: Boolean; K: Integer;
Begin
 LoadProgram:=False;
 If Not ReadAll(Name,P,Len) Then Exit;
 EmuReset;
 Emu_GEM:=GemOn;
 ProgName:=Name;ProgCmd:=CmdLine;
 If BufW(P,0)=$601A Then Ok:=LoadPRG(P,Len,CmdLine)
 Else If BufL(P,0)=$3F3 Then Ok:=LoadHunk(P,Len,CmdLine)
 Else Ok:=False;
 If P<>Nil Then FreeMem(P,Len);
 If Ok Then Begin
  K:=NewProc(Name,False);
  If K>=0 Then Begin MainProc:=K;CurProc:=K;Procs[K].Started:=True;End;
  If GemOn And OptAccs And Not AmigaRun Then LoadAccessories;
 End;
 LoadProgram:=Ok;
End;

{ ====================================================================== }
{                          EDITEUR DE TEXTE                              }
{ ====================================================================== }

Const
 WX1 = 0;
 WY1 = MENU_H+1;
 WX2 = SCR_W-1;
 WY2 = SCR_H-1;
 TITLE_H = 18;
 INFO_Y  = WY1+TITLE_H;         { ligne d'information }
 INFO_H  = 13;
 TX0     = 4;                   { debut du texte }
 TY0     = INFO_Y+INFO_H+2;
 SB_W    = 17;
 TXT_X2  = WX2-SB_W-1;
 TXT_Y2  = WY2-SB_W-1;
 TXT_ROWS = (TXT_Y2-TY0+1) Div LINE_H;
 TXT_COLS = (TXT_X2-TX0) Div 8;

Var
 Ed      : PLineArr;
 EdN     : Integer;
 CurL,CurC : Integer;
 TopL,LeftV : Integer;
 WantV   : Integer;
 EdFile  : String;
 EdMod   : Boolean;
 EdIns   : Boolean;
 EdMem   : LongInt;
 BlkSL,BlkSC,BlkEL,BlkEC : Integer;
 BlkSet  : Boolean;             { bloc defini }
 BlkAnch : Boolean;             { debut pose, fin non posee }
 ClipLn  : PLineArr;
 ClipN   : Integer;
 FindStr,ReplStr : String;
 FindCase : Boolean;
 CursorOn : Boolean;
 DragSel  : Boolean;
 AnchL,AnchC : Integer;
 { Preferences }
 PrefTab,PrefBuf : LongInt;
 PrefNumPad,PrefBackup,PrefIndent,PrefFlash,PrefLoadMon : Integer;
 ErrJump  : Integer;

Procedure EdInit;
Begin
 If Ed=Nil Then New(Ed);
 If ClipLn=Nil Then New(ClipLn);
 EdN:=1;
 Ed^[1]:=NewStr('');
 CurL:=1;CurC:=1;TopL:=1;LeftV:=0;WantV:=0;EdMod:=False;EdMem:=0;
 BlkSet:=False;BlkAnch:=False;EdIns:=True;
End;

Procedure EdClear;
Var I: Integer;
Begin
 For I:=1 To EdN Do FreeStr(Ed^[I]);
 EdN:=0;
 EdInit;
End;

Function Expand(Const S: String): String;
Var R: String; I: Integer;
Begin
 If Pos(#9,S)=0 Then Begin Expand:=S;Exit;End;
 R:='';
 For I:=1 To Length(S) Do Begin
  If S[I]=#9 Then Begin
   Repeat R:=R+' ';Until (Length(R) Mod PrefTab)=0;
  End Else R:=R+S[I];
  If Length(R)>250 Then Break;
 End;
 Expand:=R;
End;

{ Colonne visuelle (0..) du caractere C (1..) }
Function VisOf(Const S: String; C: Integer): Integer;
Var V,I: Integer;
Begin
 V:=0;
 For I:=1 To C-1 Do Begin
  If I>Length(S) Then Begin Inc(V);Continue;End;
  If S[I]=#9 Then V:=V+PrefTab-(V Mod PrefTab) Else Inc(V);
 End;
 VisOf:=V;
End;

Function CharOfVis(Const S: String; V: Integer): Integer;
Var Cv,I,W: Integer;
Begin
 Cv:=0;
 For I:=1 To Length(S) Do Begin
  If S[I]=#9 Then W:=PrefTab-(Cv Mod PrefTab) Else W:=1;
  If V<Cv+W Then Begin CharOfVis:=I;Exit;End;
  Cv:=Cv+W;
 End;
 CharOfVis:=Length(S)+1;
End;

Function MemFree: LongInt;
Begin
 MemFree:=PrefBuf-EdMem-12;
End;

Function SetLine(I: Integer; Const S: String): Boolean;
Var Delta: LongInt;
Begin
 Delta:=Length(S)-Length(Ed^[I]^);
 If (Delta>0) And (Delta>MemFree) Then Begin
  Alert1(3,T3('Out of text memory|Increase the text buffer|in Options|Editor preferences',
              'Memoire texte pleine|Augmentez le tampon texte|dans Options|Preferences editeur',
              'Textspeicher voll|Textpuffer erhoehen|in Optionen|Editor-Einstellungen'));
  SetLine:=False;Exit;
 End;
 FreeStr(Ed^[I]);
 Ed^[I]:=NewStr(S);
 EdMem:=EdMem+Delta;
 EdMod:=True;
 SetLine:=True;
End;

Function InsLineAt(I: Integer; Const S: String): Boolean;
Var J: Integer;
Begin
 InsLineAt:=False;
 If EdN>=MAXLN Then Begin
  Alert1(3,T3('Too many lines','Trop de lignes','Zu viele Zeilen'));Exit;
 End;
 If Length(S)+1>MemFree Then Begin
  Alert1(3,T3('Out of text memory','Memoire texte pleine','Textspeicher voll'));Exit;
 End;
 For J:=EdN Downto I Do Ed^[J+1]:=Ed^[J];
 Ed^[I]:=NewStr(S);
 Inc(EdN);
 EdMem:=EdMem+Length(S)+1;
 EdMod:=True;
 InsLineAt:=True;
End;

Procedure DelLineAt(I: Integer);
Var J: Integer;
Begin
 EdMem:=EdMem-Length(Ed^[I]^)-1;
 FreeStr(Ed^[I]);
 For J:=I To EdN-1 Do Ed^[J]:=Ed^[J+1];
 Dec(EdN);
 If EdN=0 Then Begin EdN:=1;Ed^[1]:=NewStr('');EdMem:=0;End;
 EdMod:=True;
End;

Procedure EnsureVisible;
Var V: Integer;
Begin
 If CurL<1 Then CurL:=1;
 If CurL>EdN Then CurL:=EdN;
 If CurC<1 Then CurC:=1;
 If CurC>Length(Ed^[CurL]^)+1 Then CurC:=Length(Ed^[CurL]^)+1;
 If CurL<TopL Then TopL:=CurL;
 If CurL>=TopL+TXT_ROWS Then TopL:=CurL-TXT_ROWS+1;
 If TopL<1 Then TopL:=1;
 V:=VisOf(Ed^[CurL]^,CurC);
 If V<LeftV Then LeftV:=V;
 If V>=LeftV+TXT_COLS Then LeftV:=V-TXT_COLS+1;
 If LeftV<0 Then LeftV:=0;
End;

Procedure ClearBlock;
Begin
 BlkSet:=False;BlkAnch:=False;
End;

Procedure BlockOrder(Var SL,SC,EL,EC: Integer);
Begin
 SL:=BlkSL;SC:=BlkSC;EL:=BlkEL;EC:=BlkEC;
 If (SL>EL) Or ((SL=EL) And (SC>EC)) Then Begin
  SL:=BlkEL;SC:=BlkEC;EL:=BlkSL;EC:=BlkSC;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Dessin                                                                   }
{ ---------------------------------------------------------------------- }

Function InfoText: String;
Var M: LongInt;
Begin
 M:=MemFree;
 If M<0 Then M:=0;
 InfoText:='Line:'+PadL(IntStr(CurL),4)+' Col:'+PadL(IntStr(VisOf(Ed^[CurL]^,CurC)+1),3)+
           ' Mem:'+IntStr(M);
End;

Procedure DrawScrollBars;
Var Tot,Pos,Sz,Y1,Y2,H,X1,X2,W: LongInt;
Begin
 { verticale }
 Box(TXT_X2+1,TY0-2,WX2,TXT_Y2+1,PAPER);
 ArrowBox(TXT_X2+1,TY0-1,WX2,TY0+SB_W-2,1);
 ArrowBox(TXT_X2+1,TXT_Y2-SB_W+2,WX2,TXT_Y2+1,2);
 Y1:=TY0+SB_W-1;Y2:=TXT_Y2-SB_W+1;
 PatBar(TXT_X2+2,Y1,WX2-1,Y2,PatGrey);
 Frame(TXT_X2+1,Y1,WX2,Y2);
 H:=Y2-Y1-2;
 If EdN<=TXT_ROWS Then Begin
  Box(TXT_X2+2,Y1+1,WX2-1,Y2-1,PAPER);Frame(TXT_X2+1,Y1+1,WX2,Y2-1);
 End Else Begin
  Sz:=H*TXT_ROWS Div EdN;If Sz<12 Then Sz:=12;
  Pos:=(H-Sz)*(TopL-1) Div (EdN-TXT_ROWS);
  If Pos<0 Then Pos:=0;
  Box(TXT_X2+2,Y1+1+Pos,WX2-1,Y1+1+Pos+Sz,PAPER);
  Frame(TXT_X2+1,Y1+1+Pos,WX2,Y1+1+Pos+Sz);
 End;
 { horizontale }
 Box(WX1,TXT_Y2+1,TXT_X2,WY2,PAPER);
 ArrowBox(WX1,TXT_Y2+1,WX1+SB_W-1,WY2,3);
 ArrowBox(TXT_X2-SB_W+1,TXT_Y2+1,TXT_X2,WY2,4);
 X1:=WX1+SB_W;X2:=TXT_X2-SB_W;
 PatBar(X1+1,TXT_Y2+2,X2-1,WY2-1,PatGrey);
 Frame(X1,TXT_Y2+1,X2,WY2);
 W:=X2-X1-2;
 Sz:=W*TXT_COLS Div (TXT_COLS+LeftV+40);If Sz<12 Then Sz:=12;
 Pos:=(W-Sz)*LeftV Div (LeftV+40);
 If Pos<0 Then Pos:=0;
 Box(X1+1+Pos,TXT_Y2+2,X1+1+Pos+Sz,WY2-1,PAPER);
 Frame(X1+1+Pos,TXT_Y2+1,X1+1+Pos+Sz,WY2);
 { coin }
 Box(TXT_X2+1,TXT_Y2+1,WX2,WY2,PAPER);
 Frame(TXT_X2+1,TXT_Y2+1,WX2,WY2);
End;

Procedure DrawTextLine(Row: Integer);
Var L: Integer; S,E,Seg: String; Y,V1,V2,SL,SC,EL,EC,X1,X2: Integer; Vis: String;
Begin
 Y:=TY0+Row*LINE_H;
 Box(WX1+1,Y,TXT_X2,Y+LINE_H-1,PAPER);
 L:=TopL+Row;
 If L>EdN Then Exit;
 S:=Ed^[L]^;
 E:=Expand(S);
 Vis:=Copy(E,LeftV+1,TXT_COLS);
 PText(TX0,Y+1,Vis);
 If BlkSet Then Begin
  BlockOrder(SL,SC,EL,EC);
  If (L>=SL) And (L<=EL) Then Begin
   If L=SL Then V1:=VisOf(S,SC) Else V1:=0;
   If L=EL Then V2:=VisOf(S,EC) Else V2:=Length(E)+1;
   If (L<EL) And (V2<=V1) Then V2:=V1+1;
   X1:=V1-LeftV;X2:=V2-LeftV;
   If X1<0 Then X1:=0;
   If X2>TXT_COLS Then X2:=TXT_COLS;
   If X2>X1 Then Begin
    Box(TX0+X1*8,Y,TX0+X2*8-1,Y+LINE_H-1,INK);
    Seg:=Copy(E+' ',LeftV+X1+1,X2-X1);
    WText(TX0+X1*8,Y+1,Seg);
   End;
  End;
 End;
End;

Procedure DrawCursor(On: Boolean);
Var Row,V,X,Y: Integer; Ch: String;
Begin
 Row:=CurL-TopL;
 If (Row<0) Or (Row>=TXT_ROWS) Then Exit;
 V:=VisOf(Ed^[CurL]^,CurC)-LeftV;
 If (V<0) Or (V>=TXT_COLS) Then Exit;
 X:=TX0+V*8;Y:=TY0+Row*LINE_H;
 HideMouse;
 If On Then Begin
  Ch:=Copy(Ed^[CurL]^,CurC,1);
  If (Ch=#9) Or (Ch='') Then Ch:=' ';
  If EdIns Then Begin
   Box(X,Y,X+7,Y+LINE_H-1,INK);
   WText(X,Y+1,Ch);
  End Else Begin
   Box(X,Y+LINE_H-3,X+7,Y+LINE_H-1,INK);
  End;
 End Else DrawTextLine(Row);
 ShowMouse;
End;

Procedure DrawEditor;
Var R: Integer; T: String;
Begin
 Box(WX1,WY1,WX2,WY2,PAPER);
 If EdFile<>'' Then T:=EdFile Else T:=AppTitle;
 GemTitleBar(WX1,WY1,WX2,WY1+TITLE_H-1,T,True);
 { ligne d'information }
 Box(WX1,INFO_Y,WX2,INFO_Y+INFO_H,PAPER);
 PText(WX1+8,INFO_Y+3,InfoText);
 If EdMod Then PText(WX2-90,INFO_Y+3,T3('modified','modifie','geaendert'));
 If Not EdIns Then PText(WX2-170,INFO_Y+3,'OVR');
 SetColor(INK);
 Line(WX1,INFO_Y+INFO_H,WX2,INFO_Y+INFO_H);
 Frame(WX1,WY1,WX2,WY2);
 For R:=0 To TXT_ROWS-1 Do DrawTextLine(R);
 DrawScrollBars;
End;

{ ---------------------------------------------------------------------- }
{ Edition                                                                  }
{ ---------------------------------------------------------------------- }

Procedure MoveCur(L,C: Integer);
Begin
 CurL:=L;CurC:=C;
 EnsureVisible;
 WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure InsertChar(Ch: Char);
Var S: String;
Begin
 S:=Ed^[CurL]^;
 If Length(S)>=250 Then Exit;
 If EdIns Or (CurC>Length(S)) Then Insert(Ch,S,CurC)
 Else S[CurC]:=Ch;
 If SetLine(CurL,S) Then Inc(CurC);
 EnsureVisible;
 WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure NewLineAt;
Var S,Rest,Ind: String; I: Integer;
Begin
 S:=Ed^[CurL]^;
 Rest:=Copy(S,CurC,255);
 S:=Copy(S,1,CurC-1);
 Ind:='';
 If PrefIndent=1 Then Begin
  I:=1;
  While (I<=Length(S)) And ((S[I]=' ') Or (S[I]=#9)) Do Begin Ind:=Ind+S[I];Inc(I);End;
 End;
 If Not SetLine(CurL,S) Then Exit;
 If Not InsLineAt(CurL+1,Ind+Rest) Then Exit;
 Inc(CurL);CurC:=Length(Ind)+1;
 EnsureVisible;
 WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure DoBackspace;
Var S: String; P: String;
Begin
 If CurC>1 Then Begin
  S:=Ed^[CurL]^;
  Delete(S,CurC-1,1);
  If SetLine(CurL,S) Then Dec(CurC);
 End Else If CurL>1 Then Begin
  P:=Ed^[CurL-1]^;
  S:=Ed^[CurL]^;
  If Length(P)+Length(S)>250 Then Exit;
  Dec(CurL);
  CurC:=Length(P)+1;
  If SetLine(CurL,P+S) Then DelLineAt(CurL+1);
 End;
 EnsureVisible;
 WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure DoDelete;
Var S: String;
Begin
 S:=Ed^[CurL]^;
 If CurC<=Length(S) Then Begin
  Delete(S,CurC,1);
  SetLine(CurL,S);
 End Else If CurL<EdN Then Begin
  S:=S+Ed^[CurL+1]^;
  If Length(S)>250 Then Exit;
  If SetLine(CurL,S) Then DelLineAt(CurL+1);
 End;
 EnsureVisible;
End;

Procedure DoTab;
Var S: String; V: Integer;
Begin
 S:=Ed^[CurL]^;
 Insert(#9,S,CurC);
 If SetLine(CurL,S) Then Inc(CurC);
 EnsureVisible;
 V:=0;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure DeleteCurLine;
Begin
 DelLineAt(CurL);
 If CurL>EdN Then CurL:=EdN;
 CurC:=1;
 EnsureVisible;
 WantV:=0;
End;

{ Mots : debut du mot suivant / precedent }
Procedure WordRight;
Var S: String;
Begin
 S:=Ed^[CurL]^;
 If CurC>Length(S) Then Begin
  If CurL<EdN Then Begin Inc(CurL);CurC:=1;End;
 End Else Begin
  While (CurC<=Length(S)) And (S[CurC]<>' ') And (S[CurC]<>#9) Do Inc(CurC);
  While (CurC<=Length(S)) And ((S[CurC]=' ') Or (S[CurC]=#9)) Do Inc(CurC);
 End;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure WordLeft;
Var S: String;
Begin
 If CurC=1 Then Begin
  If CurL>1 Then Begin Dec(CurL);CurC:=Length(Ed^[CurL]^)+1;End;
 End Else Begin
  S:=Ed^[CurL]^;
  Dec(CurC);
  While (CurC>1) And ((S[CurC]=' ') Or (S[CurC]=#9)) Do Dec(CurC);
  While (CurC>1) And (S[CurC-1]<>' ') And (S[CurC-1]<>#9) Do Dec(CurC);
 End;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

{ ---------------------------------------------------------------------- }
{ Blocs                                                                    }
{ ---------------------------------------------------------------------- }

Procedure ClipFree;
Var I: Integer;
Begin
 For I:=1 To ClipN Do FreeStr(ClipLn^[I]);
 ClipN:=0;
End;

Procedure CopyBlock;
Var SL,SC,EL,EC,L: Integer; S: String;
Begin
 If Not BlkSet Then Begin
  Alert1(1,T3('No block defined','Aucun bloc defini','Kein Block definiert'));Exit;
 End;
 BlockOrder(SL,SC,EL,EC);
 ClipFree;
 For L:=SL To EL Do Begin
  S:=Ed^[L]^;
  If L=EL Then S:=Copy(S,1,EC-1);
  If L=SL Then S:=Copy(S,SC,255);
  If ClipN<MAXLN Then Begin Inc(ClipN);ClipLn^[ClipN]:=NewStr(S);End;
 End;
End;

Procedure DeleteBlock;
Var SL,SC,EL,EC,L: Integer; S,T: String;
Begin
 If Not BlkSet Then Exit;
 BlockOrder(SL,SC,EL,EC);
 S:=Copy(Ed^[SL]^,1,SC-1)+Copy(Ed^[EL]^,EC,255);
 If SetLine(SL,S) Then Begin
  For L:=EL Downto SL+1 Do DelLineAt(L);
  CurL:=SL;CurC:=SC;
 End;
 ClearBlock;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure PasteBlock;
Var I: Integer; S,Tail: String;
Begin
 If ClipN=0 Then Begin
  Alert1(1,T3('Block buffer is empty','Le tampon de bloc est vide','Blockpuffer ist leer'));Exit;
 End;
 S:=Ed^[CurL]^;
 Tail:=Copy(S,CurC,255);
 If ClipN=1 Then Begin
  S:=Copy(S,1,CurC-1)+ClipLn^[1]^+Tail;
  If SetLine(CurL,S) Then CurC:=CurC+Length(ClipLn^[1]^);
 End Else Begin
  If Not SetLine(CurL,Copy(S,1,CurC-1)+ClipLn^[1]^) Then Exit;
  For I:=2 To ClipN-1 Do
   If Not InsLineAt(CurL+I-1,ClipLn^[I]^) Then Exit;
  If Not InsLineAt(CurL+ClipN-1,ClipLn^[ClipN]^+Tail) Then Exit;
  CurL:=CurL+ClipN-1;
  CurC:=Length(ClipLn^[ClipN]^)+1;
 End;
 ClearBlock;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure SelectAll;
Begin
 BlkSL:=1;BlkSC:=1;BlkEL:=EdN;BlkEC:=Length(Ed^[EdN]^)+1;
 BlkSet:=True;BlkAnch:=False;
End;

{ ---------------------------------------------------------------------- }
{ Fichiers                                                                 }
{ ---------------------------------------------------------------------- }

Function EdLoadFile(Const Name: String; Append: Boolean): Boolean;
Var Arr: PLineArr; Cnt,I: Integer; Tot: LongInt;
Begin
 EdLoadFile:=False;
 If Not LoadLines(Name,Arr,Cnt) Then Begin
  Alert1(3,T3('Cannot open file|','Impossible d''ouvrir le fichier|','Datei nicht lesbar|')+ShortName(Name));
  Exit;
 End;
 Tot:=0;
 For I:=1 To Cnt Do Tot:=Tot+Length(Arr^[I]^)+1;
 If Tot>PrefBuf-12-EdMem Then Begin
  Alert1(3,T3('File too large for the text buffer|Increase it in Options|Editor preferences',
              'Fichier trop grand pour le tampon texte|Augmentez-le dans Options|Preferences editeur',
              'Datei zu gross fuer den Textpuffer|In Optionen erhoehen|Editor-Einstellungen'));
  FreeLines(Arr,Cnt);Exit;
 End;
 If Not Append Then Begin
  EdClear;
  If Cnt=0 Then Begin Cnt:=1;Arr^[1]:=NewStr('');End;
  Dispose(Ed);
  Ed:=Arr;EdN:=Cnt;
  EdMem:=Tot;
  EdFile:=Name;EdMod:=False;
  CurL:=1;CurC:=1;TopL:=1;LeftV:=0;WantV:=0;
 End Else Begin
  For I:=1 To Cnt Do
   If Not InsLineAt(CurL+I,Arr^[I]^) Then Break;
  FreeLines(Arr,Cnt);
 End;
 ClearBlock;
 EdLoadFile:=True;
End;

Function EdSaveFile(Const Name: String): Boolean;
Var F: File; I: Integer; S: String; Bak: String; G: File;
Begin
 EdSaveFile:=False;
 If PrefBackup=1 Then
  If FileExists(Name) Then Begin
   Bak:=ChangeExt(Name,'BAK');
   If FileExists(Bak) Then Begin
    Assign(G,Bak);{$I-}Erase(G);{$I+}If IOResult<>0 Then Begin End;
   End;
   Assign(G,Name);{$I-}Rename(G,Bak);{$I+}If IOResult<>0 Then Begin End;
  End;
 Assign(F,Name);
 {$I-}
 Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Begin
  Alert1(3,T3('Cannot write file|','Impossible d''ecrire le fichier|','Datei nicht schreibbar|')+ShortName(Name));
  Exit;
 End;
 For I:=1 To EdN Do Begin
  S:=Ed^[I]^+#13#10;
  BlockWrite(F,S[1],Length(S));
 End;
 Close(F);
 EdFile:=Name;EdMod:=False;
 EdSaveFile:=True;
End;

Function SaveBlockFile(Const Name: String): Boolean;
Var F: File; I: Integer; S: String;
Begin
 SaveBlockFile:=False;
 CopyBlock;
 If ClipN=0 Then Exit;
 Assign(F,Name);
 {$I-}
 Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 For I:=1 To ClipN Do Begin
  S:=ClipLn^[I]^+#13#10;
  BlockWrite(F,S[1],Length(S));
 End;
 Close(F);
 SaveBlockFile:=True;
End;

{ ---------------------------------------------------------------------- }
{ Recherche                                                                }
{ ---------------------------------------------------------------------- }

Function FindFrom(L,C: Integer; Const Pat: String; Var FL,FC: Integer): Boolean;
Var S,P: String; I,Pp: Integer;
Begin
 FindFrom:=False;
 If Pat='' Then Exit;
 If FindCase Then P:=Pat Else P:=Upper(Pat);
 For I:=L To EdN Do Begin
  S:=Ed^[I]^;
  If Not FindCase Then S:=Upper(S);
  If I=L Then Begin
   If C>Length(S)+1 Then Continue;
   Pp:=Pos(P,Copy(S,C,255));
   If Pp>0 Then Pp:=Pp+C-1;
  End Else Pp:=Pos(P,S);
  If Pp>0 Then Begin FL:=I;FC:=Pp;FindFrom:=True;Exit;End;
 End;
End;

Procedure GotoLine(L: Integer);
Begin
 If L<1 Then L:=1;
 If L>EdN Then L:=EdN;
 MoveCur(L,1);
 TopL:=L-TXT_ROWS Div 2;
 If TopL<1 Then TopL:=1;
 EnsureVisible;
End;

Procedure DoFindNext;
Var FL,FC: Integer;
Begin
 If FindStr='' Then Exit;
 If FindFrom(CurL,CurC+1,FindStr,FL,FC) Then Begin
  BlkSL:=FL;BlkSC:=FC;BlkEL:=FL;BlkEC:=FC+Length(FindStr);BlkSet:=True;
  MoveCur(FL,FC);
  TopL:=FL-TXT_ROWS Div 2;If TopL<1 Then TopL:=1;
  EnsureVisible;
 End Else Alert1(1,T3('Not found','Introuvable','Nicht gefunden'));
End;

Procedure DoFind;
Var R: Integer;
Begin
 DlgReset(44,6);
 DlgLabel(1,0,T3('Find','Chercher','Suchen'));
 DlgLabel(1,1,T3('Text:','Texte :','Text:'));
 DlgEdit(8,1,30,FindStr);
 DlgLabel(1,2,T3('Case:','Casse :','Gross/klein:'));
 DlgRadio(14,2,T3('Ignore|Match','Ignorer|Respecter','Egal|Beachten'),Ord(FindCase)+1);
 DlgButton(2,4,10,'OK',1,True);
 DlgButton(14,4,12,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R=1 Then Begin
  FindStr:=DI[3].Val;
  FindCase:=DI[5].Sel=2;
  DoFindNext;
 End;
End;

Procedure DoReplace;
Var R,N,FL,FC,I: Integer; S: String; All: Boolean;
Begin
 DlgReset(52,8);
 DlgLabel(1,0,T3('Replace','Remplacer','Ersetzen'));
 DlgLabel(1,1,T3('Find   :','Chercher :','Suchen  :'));
 DlgEdit(12,1,30,FindStr);
 DlgLabel(1,2,T3('Replace:','Remplacer:','Ersetzen:'));
 DlgEdit(12,2,30,ReplStr);
 DlgLabel(1,3,T3('Case   :','Casse    :','Gr/Kl   :'));
 DlgRadio(12,3,T3('Ignore|Match','Ignorer|Respecter','Egal|Beachten'),Ord(FindCase)+1);
 DlgLabel(1,4,T3('Mode   :','Mode     :','Modus   :'));
 DlgRadio(12,4,T3('One|All','Un|Tous','Eins|Alle'),1);
 DlgButton(2,6,10,'OK',1,True);
 DlgButton(14,6,12,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R<>1 Then Exit;
 FindStr:=DI[3].Val;ReplStr:=DI[5].Val;
 FindCase:=DI[7].Sel=2;
 All:=DI[9].Sel=2;
 If FindStr='' Then Exit;
 N:=0;
 If All Then Begin
  FL:=1;FC:=1;
  While FindFrom(FL,FC,FindStr,FL,FC) Do Begin
   S:=Ed^[FL]^;
   Delete(S,FC,Length(FindStr));
   Insert(ReplStr,S,FC);
   If Not SetLine(FL,S) Then Break;
   Inc(N);
   FC:=FC+Length(ReplStr);
  End;
  Alert1(3-2,IntStr(N)+T3(' replacement(s)',' remplacement(s)',' Ersetzung(en)'));
  ClearBlock;
  EnsureVisible;
 End Else Begin
  If FindFrom(CurL,CurC,FindStr,FL,FC) Then Begin
   S:=Ed^[FL]^;
   Delete(S,FC,Length(FindStr));
   Insert(ReplStr,S,FC);
   If SetLine(FL,S) Then MoveCur(FL,FC+Length(ReplStr));
  End Else Alert1(1,T3('Not found','Introuvable','Nicht gefunden'));
 End;
End;

Procedure DoGotoLine;
Var S: String; V: LongInt;
Begin
 S:=IntStr(CurL);
 If InputDlg(T3('Goto line','Aller a la ligne','Gehe zu Zeile'),T3('Line:','Ligne :','Zeile:'),S,6) Then Begin
  V:=ToInt(S);
  GotoLine(V);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Preferences                                                              }
{ ---------------------------------------------------------------------- }

Procedure PrefDefaults;
Begin
 PrefTab:=8;PrefBuf:=60000;PrefNumPad:=1;PrefBackup:=1;PrefIndent:=1;
 PrefFlash:=1;PrefLoadMon:=2;
End;

Procedure SavePrefs;
Var T: Text;
Begin
 Assign(T,'DEVPAC.INF');
 {$I-}
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(T,'TAB=',PrefTab);
 WriteLn(T,'BUFFER=',PrefBuf);
 WriteLn(T,'NUMPAD=',PrefNumPad);
 WriteLn(T,'BACKUP=',PrefBackup);
 WriteLn(T,'INDENT=',PrefIndent);
 WriteLn(T,'CURSOR=',PrefFlash);
 WriteLn(T,'LOADMON=',PrefLoadMon);
 WriteLn(T,'TODISK=',Ord(OptToDisk));
 WriteLn(T,'DEBUG=',Ord(OptDebug));
 WriteLn(T,'LISTING=',Ord(OptListing));
 WriteLn(T,'OPTIMIZE=',Ord(OptOptimize));
 WriteLn(T,'CASE=',Ord(OptCase));
 WriteLn(T,'RUNGEM=',Ord(OptRunGem));
 WriteLn(T,'ACC=',Ord(OptAccs));
 WriteLn(T,'INCPATH=',OptIncPath);
 Close(T);
End;

Procedure LoadPrefs;
Var T: Text; S,K,V: String; P: Integer;
Begin
 Assign(T,'DEVPAC.INF');
 {$I-}
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(T) Do Begin
  ReadLn(T,S);
  P:=Pos('=',S);
  If P>0 Then Begin
   K:=Upper(Copy(S,1,P-1));V:=Copy(S,P+1,200);
   If K='TAB' Then PrefTab:=Clamp(ToInt(V),1,32)
   Else If K='BUFFER' Then PrefBuf:=Clamp(ToInt(V),4000,1000000)
   Else If K='NUMPAD' Then PrefNumPad:=ToInt(V)
   Else If K='BACKUP' Then PrefBackup:=ToInt(V)
   Else If K='INDENT' Then PrefIndent:=ToInt(V)
   Else If K='CURSOR' Then PrefFlash:=ToInt(V)
   Else If K='LOADMON' Then PrefLoadMon:=ToInt(V)
   Else If K='TODISK' Then OptToDisk:=ToInt(V)=1
   Else If K='DEBUG' Then OptDebug:=ToInt(V)=1
   Else If K='LISTING' Then OptListing:=ToInt(V)=1
   Else If K='OPTIMIZE' Then OptOptimize:=ToInt(V)=1
   Else If K='CASE' Then OptCase:=ToInt(V)=1
 Else If K='RUNGEM' Then OptRunGem:=ToInt(V)=1
   Else If K='ACC' Then OptAccs:=ToInt(V)=1
   Else If K='INCPATH' Then OptIncPath:=V;
  End;
 End;
 Close(T);
End;

{ Dialogue "Editor preferences" (voir la capture d'ecran de Devpac) }
Procedure EditorPrefsDlg;
Var R,I: Integer; Msg: String;
Begin
 DlgReset(40,12);
 DlgLabel(2,0,T3('Editor preferences','Preferences de l''editeur','Editor-Einstellungen'));
 DlgLabel(2,2,T3('Tab setting:','Tabulation  :','Tabulator   :'));
 DlgEdit(16,2,4,IntStr(PrefTab));
 DlgLabel(2,3,T3('Text buffer:','Tampon texte:','Textpuffer  :'));
 DlgEdit(16,3,8,IntStr(PrefBuf));
 DlgLabel(2,4,T3('Numeric pad:','Pave num.   :','Zehnerblock :'));
 DlgRadio(16,4,T3('Numbers|Cursor','Chiffres|Curseur','Zahlen|Cursor'),PrefNumPad);
 DlgLabel(2,5,T3('Backups    :','Sauvegardes :','Sicherungen :'));
 DlgRadio(16,5,T3('Yes|No','Oui|Non','Ja|Nein'),2-PrefBackup);
 DlgLabel(2,6,T3('Auto indent:','Auto-retrait :','Auto-Einzug  :'));
 DlgRadio(16,6,T3('Yes|No','Oui|Non','Ja|Nein'),2-PrefIndent);
 DlgLabel(2,7,T3('Cursor     :','Curseur     :','Cursor      :'));
 DlgRadio(16,7,T3('Flash|Still','Clignote|Fixe','Blinkt|Fest'),PrefFlash);
 DlgLabel(2,8,T3('Load '+MonName+':','Charger '+MonName+':','Lade '+MonName+':'));
 DlgRadio(16,8,T3('Yes|No','Oui|Non','Ja|Nein'),PrefLoadMon);
 DlgButton(2,10,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(14,10,10,T3('Save','Sauver','Sichern'),2,False);
 DlgButton(26,10,10,'OK',1,True);
 R:=DlgRun;
 If R=0 Then Exit;
 PrefTab:=Clamp(ToInt(DI[3].Val),1,32);
 PrefBuf:=Clamp(ToInt(DI[5].Val),4000,1000000);
 PrefNumPad:=DI[7].Sel;
 PrefBackup:=Ord(DI[9].Sel=1);
 PrefIndent:=Ord(DI[11].Sel=1);
 PrefFlash:=DI[13].Sel;
 PrefLoadMon:=DI[15].Sel;
 If R=2 Then SavePrefs;
 EnsureVisible;
End;

Procedure AsmOptionsDlg;
Var R: Integer; S: String;
Begin
 DlgReset(52,14);
 DlgLabel(2,0,AsmName+T3(' options',' - options',' Optionen'));
 DlgLabel(2,2,T3('Output     :','Sortie     :','Ausgabe    :'));
 DlgRadio(16,2,T3('Memory|Disk','Memoire|Disque','Speicher|Disk'),1+Ord(OptToDisk));
 DlgLabel(2,3,T3('Debug info :','Infos debug :','Debug-Info  :'));
 DlgRadio(16,3,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptDebug));
 DlgLabel(2,4,T3('Listing    :','Listing     :','Listing     :'));
 DlgRadio(16,4,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptListing));
 DlgLabel(2,5,T3('Optimise   :','Optimiser   :','Optimieren  :'));
 DlgRadio(16,5,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptOptimize));
 DlgLabel(2,6,T3('Symbols    :','Symboles    :','Symbole     :'));
 DlgRadio(16,6,T3('Case|Any','Casse|Libre','Gr/Kl|Egal'),2-Ord(OptCase));
 DlgLabel(2,7,T3('Include dir:','Rep. include:','Include-Verz.:'));
 DlgEdit(16,7,30,OptIncPath);
 DlgLabel(2,8,T3('Output file:','Fichier sortie:','Ausgabedatei:'));
 DlgEdit(16,8,30,OptOutName);
 DlgButton(2,12,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(18,12,10,T3('Save','Sauver','Sichern'),2,False);
 DlgButton(34,12,10,'OK',1,True);
 R:=DlgRun;
 If R=0 Then Exit;
 OptToDisk:=DI[3].Sel=2;
 OptDebug:=DI[5].Sel=1;
 OptListing:=DI[7].Sel=1;
 OptOptimize:=DI[9].Sel=1;
 OptCase:=DI[11].Sel=1;
 OptIncPath:=DI[13].Val;
 OptOutName:=DI[15].Val;
 If R=2 Then SavePrefs;
End;

{ ====================================================================== }
{                  MONITEUR / DEBOGUEUR MonST / MonAm                    }
{ ====================================================================== }

Const
 MON_LOG = 300;
 MR_ROWS = 10;                 { rangees de la fenetre des registres }
 MD_ROWS = 16;                 { rangees des fenetres du milieu }
 MC_ROWS = 17;                 { rangees de la fenetre de commande }
 MROW    = 10;                 { hauteur d'une rangee }

Var
 MLog      : Array[1..MON_LOG] Of PString;
 MLogN     : Integer;
 MonDisAddr,MonMemAddr : LongInt;
 MonCmd    : String;
 MonCmdHist: String;
 MonLoaded : Boolean;
 MonQuit   : Boolean;
 MonSeen   : Boolean;
 MonLastCmdKey : LongInt;

Procedure MonPrint(Const S: String);
Var I: Integer;
Begin
 If MLogN>=MON_LOG Then Begin
  FreeStr(MLog[1]);
  For I:=1 To MLogN-1 Do MLog[I]:=MLog[I+1];
  Dec(MLogN);
 End;
 Inc(MLogN);
 MLog[MLogN]:=NewStr(Copy(S,1,78));
End;

Procedure ClrErr;
Begin
 BusErr:=False;AddrErr:=False;
End;

Function ParseHexVal(Const S: String; Var V: LongInt): Boolean;
Var I: Integer;
Begin
 V:=0;ParseHexVal:=False;
 If S='' Then Exit;
 For I:=1 To Length(S) Do Begin
  If Not IsHexCh(S[I]) Then Exit;
  V:=(V Shl 4) Or HexVal(S[I]);
 End;
 ParseHexVal:=True;
End;

{ Evaluation d'expression du moniteur : hexadecimal par defaut }
Var MS: String; MP: Integer; MErr: Boolean;

Function MonExpr: LongInt; Forward;

Function MonTerm: LongInt;
Var V: LongInt; Tk: String; R: Integer; C: Char; A: LongInt; Neg: Boolean;
Begin
 V:=0;
 While (MP<=Length(MS)) And (MS[MP]=' ') Do Inc(MP);
 If MP>Length(MS) Then Begin MErr:=True;MonTerm:=0;Exit;End;
 C:=MS[MP];
 If C='-' Then Begin Inc(MP);MonTerm:=-MonTerm;Exit;End;
 If C='(' Then Begin
  Inc(MP);V:=MonExpr;
  If (MP<=Length(MS)) And (MS[MP]=')') Then Inc(MP) Else MErr:=True;
  MonTerm:=V;Exit;
 End;
 If C='[' Then Begin
  Inc(MP);V:=MonExpr;
  If (MP<=Length(MS)) And (MS[MP]=']') Then Inc(MP) Else MErr:=True;
  V:=Rd32(V);ClrErr;
  MonTerm:=V;Exit;
 End;
 If C='#' Then Begin
  Inc(MP);Neg:=False;
  If (MP<=Length(MS)) And (MS[MP]='-') Then Begin Neg:=True;Inc(MP);End;
  While (MP<=Length(MS)) And (MS[MP]>='0') And (MS[MP]<='9') Do Begin
   V:=V*10+Ord(MS[MP])-48;Inc(MP);
  End;
  If Neg Then V:=-V;
  MonTerm:=V;Exit;
 End;
 If C='%' Then Begin
  Inc(MP);
  While (MP<=Length(MS)) And (MS[MP] In ['0','1']) Do Begin V:=V*2+Ord(MS[MP])-48;Inc(MP);End;
  MonTerm:=V;Exit;
 End;
 If C='''' Then Begin
  Inc(MP);
  While (MP<=Length(MS)) And (MS[MP]<>'''') Do Begin V:=(V Shl 8) Or Ord(MS[MP]);Inc(MP);End;
  If MP<=Length(MS) Then Inc(MP);
  MonTerm:=V;Exit;
 End;
 If C='$' Then Inc(MP);
 Tk:='';
 While (MP<=Length(MS)) And (IsIdChar(MS[MP])) Do Begin Tk:=Tk+MS[MP];Inc(MP);End;
 If Tk='' Then Begin MErr:=True;MonTerm:=0;Exit;End;
 R:=RegOf(Upper(Tk));
 If (C<>'$') And (R>=0) And (R<16) Then Begin MonTerm:=Rg[R];Exit;End;
 If (C<>'$') And (Upper(Tk)='PC') Then Begin MonTerm:=PC;Exit;End;
 If (C<>'$') And (Upper(Tk)='SR') Then Begin MonTerm:=SRv;Exit;End;
 If (C<>'$') And (Upper(Tk)='SP') Then Begin MonTerm:=Rg[15];Exit;End;
 If ParseHexVal(Tk,V) Then Begin MonTerm:=V;Exit;End;
 If DbgByName(Tk,A) Then Begin MonTerm:=A;Exit;End;
 MErr:=True;
 MonTerm:=0;
End;

Function MonExpr: LongInt;
Var V,W: LongInt; Op: Char;
Begin
 V:=MonTerm;
 While MP<=Length(MS) Do Begin
  While (MP<=Length(MS)) And (MS[MP]=' ') Do Inc(MP);
  If MP>Length(MS) Then Break;
  Op:=MS[MP];
  If (Op='+') Or (Op='-') Or (Op='*') Or (Op='/') Or (Op='&') Or (Op='|') Then Begin
   Inc(MP);W:=MonTerm;
   Case Op Of
    '+': V:=V+W;
    '-': V:=V-W;
    '*': V:=V*W;
    '/': If W<>0 Then V:=V Div W Else MErr:=True;
    '&': V:=V And W;
    '|': V:=V Or W;
   End;
  End Else Break;
 End;
 MonExpr:=V;
End;

Function MonEval(Const S: String; Var V: LongInt): Boolean;
Begin
 MS:=S;MP:=1;MErr:=False;
 V:=MonExpr;
 While (MP<=Length(MS)) And (MS[MP]=' ') Do Inc(MP);
 MonEval:=Not MErr And (MP>Length(MS));
End;

{ ---------------------------------------------------------------------- }
{ Affichage                                                                }
{ ---------------------------------------------------------------------- }

Procedure MonBar(Y: Integer; X1,X2: Integer; Const S: String);
Begin
 Box(X1,Y,X2,Y+MROW-1,INK);
 WText(X1+4,Y+1,S);
End;

Function FlagStr: String;
Var S: String;
Begin
 S:='';
 If GetF(SR_X) Then S:=S+'X' Else S:=S+'-';
 If GetF(SR_N) Then S:=S+'N' Else S:=S+'-';
 If GetF(SR_Z) Then S:=S+'Z' Else S:=S+'-';
 If GetF(SR_V) Then S:=S+'V' Else S:=S+'-';
 If GetF(SR_C) Then S:=S+'C' Else S:=S+'-';
 FlagStr:=S;
End;

Function ModeStr: String;
Begin
 If (SRv And SR_S)<>0 Then ModeStr:=T3('Super','Super','Super') Else ModeStr:=T3('User','Util.','User');
End;

Procedure DrawMonitor;
Var R,I,Y,X: Integer; A: LongInt; S,Lbl: String; Len: Integer; Idx: Integer; Mk: String;
    B: Byte; Asc: String;
Begin
 HideMouse;
 Box(0,0,SCR_W-1,SCR_H-1,PAPER);
 { 1 Registers }
 MonBar(0,0,SCR_W-1,'1 '+T3('Registers','Registres','Register'));
 For I:=0 To 7 Do Begin
  Y:=(1+I)*MROW;
  A:=Rg[I];
  S:='D'+IntStr(I)+':'+Hex8(A)+' ';
  For R:=0 To 3 Do S:=S+Hex4(Rd16(A+R*2))+' ';
  PText(4,Y+1,S);
  A:=Rg[8+I];
  If I=7 Then S:='A7:' Else S:='A'+IntStr(I)+':';
  S:=S+Hex8(A)+' ';
  For R:=0 To 3 Do S:=S+Hex4(Rd16(A+R*2))+' ';
  PText(324,Y+1,S);
 End;
 ClrErr;
 Y:=9*MROW;
 PText(4,Y+1,'SR:'+Hex4(SRv)+' '+FlagStr+'  '+Chr(Ord('0'))+IntStr((SRv Shr 8) And 7)+
   ' '+T3('Mode:','Mode:','Modus:')+' '+ ModeStr);
 PText(324,Y+1,'PC:'+Hex8(PC)+' '+T3('Instr:','Instr:','Befehle:')+IntStr(InstrCount));
 { 2 Disassembled PC et 3 Memory }
 Y:=MR_ROWS*MROW;
 MonBar(Y,0,319,'2 '+T3('Disassembled PC','Desassemblage PC','Disassembler PC'));
 MonBar(Y,320,SCR_W-1,'3 '+T3('Memory','Memoire','Speicher'));
 A:=MonDisAddr;
 For R:=0 To MD_ROWS-1 Do Begin
  Y:=(MR_ROWS+1+R)*MROW;
  S:=Hex6(A)+' ';
  If A=PC Then S[7]:='*';
  If IsBreakpoint(A) Then S[7]:='B';
  Lbl:=Dis(A,Len);
  ClrErr;
  If A=PC Then Begin
   Box(0,Y,319,Y+MROW-1,INK);
   WText(4,Y+1,Copy(S+Lbl,1,38));
  End Else PText(4,Y+1,Copy(S+Lbl,1,38));
  A:=A+Len;
 End;
 A:=MonMemAddr;
 For R:=0 To MD_ROWS-1 Do Begin
  Y:=(MR_ROWS+1+R)*MROW;
  S:=Hex6(A)+' ';
  Asc:='';
  For I:=0 To 7 Do Begin
   B:=Rd8(A+I);
   If (I And 1)=0 Then Begin
    If I>0 Then S:=S+' ';
   End;
   S:=S+Hex2(B);
   If (B>=32) And (B<127) Then Asc:=Asc+Chr(B) Else Asc:=Asc+'.';
  End;
  ClrErr;
  PText(324,Y+1,Copy(S+' '+Asc,1,39));
  A:=A+8;
 End;
 { 4 commande }
 Y:=(MR_ROWS+MD_ROWS+1)*MROW;
 MonBar(Y,0,SCR_W-1,'4 '+T3('Command','Commande','Befehl')+'   '+ProgName);
 Idx:=MLogN-MC_ROWS+1;If Idx<1 Then Idx:=1;
 For R:=0 To MC_ROWS-1 Do Begin
  If Idx+R<=MLogN Then PText(4,Y+(R+1)*MROW+1,MLog[Idx+R]^);
 End;
 Y:=Y+(MC_ROWS+1)*MROW;
 PText(4,Y+1,'>'+MonCmd+'_');
 { aide }
 Y:=SCR_H-MROW-1;
 Box(0,Y-1,SCR_W-1,SCR_H-1,INK);
 WText(4,Y,'F7:Trace F8:Over F9:Run F10:Screen  G T B D M R ? H Q');
 ShowMouse;
End;

{ ---------------------------------------------------------------------- }
{ Commandes                                                                }
{ ---------------------------------------------------------------------- }

Procedure MonLoad(Const Name: String);
Begin
 If LoadProgram(Name,'',OptRunGem) Then Begin
  MonLoaded:=True;ProgName:=Name;
  MonDisAddr:=PC;MonMemAddr:=Rg[15];
  MonPrint(T3('Loaded ','Charge : ','Geladen: ')+Name+'  PC=$'+Hex8(PC)+'  '+IntStr(DbgN)+T3(' symbols',' symboles',' Symbole'));
 End Else Begin
  MonLoaded:=False;
  MonPrint(T3('Cannot load ','Impossible de charger ','Laden nicht moeglich: ')+Name);
 End;
End;

Procedure ReportStop;
Begin
 Case StopReason Of
  STOP_EXIT: MonPrint(T3('Program terminated, exit code ','Programme termine, code de sortie ','Programm beendet, Code ')+IntStr(ExitCode));
  STOP_BREAK: MonPrint(T3('Breakpoint at $','Point d''arret en $','Haltepunkt bei $')+Hex6(PC));
  STOP_FAULT: MonPrint(StopMsg);
  STOP_STOP: MonPrint(T3('STOP instruction','Instruction STOP','STOP-Befehl'));
  STOP_USER: MonPrint(T3('Interrupted by user','Interrompu par l''utilisateur','Vom Benutzer unterbrochen'));
 End;
 If UnknownCall<>'' Then Begin
  MonPrint(T3('Unsupported call: ','Appel non gere : ','Nicht unterstuetzt: ')+UnknownCall);
  UnknownCall:='';
 End;
End;

Procedure MonYield;
Begin
 EmuVisible:=True;
 BlitScreen(True);
 GemDispatch;
 EmuVisible:=False;
End;

Procedure MonTraceN(N: LongInt);
Var I: LongInt;
Begin
 If Not MonLoaded Then Begin MonPrint(T3('No program loaded','Aucun programme charge','Kein Programm geladen'));Exit;End;
 If (StopReason<>STOP_NONE) And (StopReason<>STOP_BREAK) And (StopReason<>STOP_TRACE) Then Begin
  ReportStop;Exit;
 End;
 StopReason:=STOP_NONE;
 For I:=1 To N Do Begin
  Step;
  If StopReason=STOP_YIELD Then MonYield;
  If StopReason<>STOP_NONE Then Break;
 End;
 If StopReason<>STOP_NONE Then ReportStop;
 MonDisAddr:=PC;
End;

Procedure MonRunUntil(Target: LongInt);
Var Saved: Integer;
Begin
 If Not MonLoaded Then Begin MonPrint(T3('No program loaded','Aucun programme charge','Kein Programm geladen'));Exit;End;
 If (StopReason<>STOP_NONE) And (StopReason<>STOP_BREAK) And (StopReason<>STOP_TRACE) Then Begin
  ReportStop;Exit;
 End;
 StopReason:=STOP_NONE;
 EmuVisible:=True;
 BlitScreen(True);
 UserBreak:=False;
 Step;
 If StopReason=STOP_YIELD Then GemDispatch;
 While (StopReason=STOP_NONE) And Not UserBreak Do Begin
  If (Target<>-1) And (PC=Target) Then Break;
  RunCpu(20000);
  If StopReason=STOP_YIELD Then GemDispatch;
  If (Target<>-1) And (PC=Target) Then Break;
  PollInput;
  BlitScreen(False);
 End;
 If UserBreak Then StopReason:=STOP_USER;
 UserBreak:=False;
 EmuVisible:=False;
 If StopReason<>STOP_NONE Then ReportStop;
 MonDisAddr:=PC;
End;

Procedure MonStepOver;
Var Op: LongInt; Len: Integer; T: String;
Begin
 Op:=Rd16(PC);
 T:=Dis(PC,Len);
 ClrErr;
 If ((Op And $FFC0)=$4E80) Or ((Op And $FF00)=$6100) Or ((Op And $F0F8)=$50C8) Or ((Op And $FFF0)=$4E40) Then
  MonRunUntil(PC+Len)
 Else MonTraceN(1);
End;

Procedure ToggleBp(A: LongInt);
Var I,J: Integer;
Begin
 For I:=1 To NBps Do
  If Bps[I]=A Then Begin
   For J:=I To NBps-1 Do Bps[J]:=Bps[J+1];
   Dec(NBps);
   MonPrint(T3('Breakpoint removed at $','Point d''arret supprime en $','Haltepunkt entfernt bei $')+Hex6(A));
   Exit;
  End;
 If NBps<MAXBP Then Begin
  Inc(NBps);Bps[NBps]:=A;
  MonPrint(T3('Breakpoint set at $','Point d''arret pose en $','Haltepunkt gesetzt bei $')+Hex6(A));
 End Else MonPrint(T3('Too many breakpoints','Trop de points d''arret','Zu viele Haltepunkte'));
End;

Procedure MonHelp;
Begin
 MonPrint(T3('Commands (numbers are hexadecimal, # = decimal):','Commandes (nombres en hexadecimal, # = decimal) :','Befehle (Zahlen hexadezimal, # = dezimal):'));
 MonPrint('  ? expr       '+T3('evaluate an expression','evalue une expression','Ausdruck auswerten'));
 MonPrint('  D [addr]     '+T3('disassemble from address','desassemble a partir de l''adresse','Disassemblieren ab Adresse'));
 MonPrint('  M [addr]     '+T3('show memory at address','affiche la memoire','Speicher anzeigen'));
 MonPrint('  T [n]  F7    '+T3('trace n instructions','execute n instructions','n Befehle verfolgen'));
 MonPrint('  S      F8    '+T3('step over JSR/BSR/TRAP/DBcc','saute JSR/BSR/TRAP/DBcc','JSR/BSR/TRAP/DBcc ueberspringen'));
 MonPrint('  G [addr] F9  '+T3('run (ESC/^C interrupts)','execute (ESC/^C interrompt)','starten (ESC/^C unterbricht)'));
 MonPrint('  B addr       '+T3('toggle breakpoint; BC clear all; BL list','pose/retire un point d''arret; BC efface; BL liste','Haltepunkt; BC loeschen; BL Liste'));
 MonPrint('  Dn=v An=v PC=v SR=v   '+T3('change a register','modifie un registre','Register aendern'));
 MonPrint('  F addr len b '+T3('fill memory','remplit la memoire','Speicher fuellen'));
 MonPrint('  L file       '+T3('load an executable','charge un executable','Programm laden'));
 MonPrint('  X            '+T3('reload the program','recharge le programme','Programm neu laden'));
 MonPrint('  V  F10       '+T3('view the program screen','affiche l''ecran du programme','Programmbildschirm'));
 MonPrint('  Q            '+T3('quit the monitor','quitte le moniteur','Monitor verlassen'));
End;

Procedure ViewProgramScreen;
Var E: TEvent;
Begin
 EmuVisible:=True;
 BlitScreen(True);
 Repeat PollEvent(E);Until E.Kind=1;
 EmuVisible:=False;
End;

Procedure MonExec(Const Line: String);
Var S,Cmd,Arg: String; P,N,I: Integer; V,V2,V3: LongInt; U: String; R: Integer;
    Prt: Array[0..3] Of String;
Begin
 S:=TrimS(Line);
 If S='' Then Exit;
 MonPrint('> '+S);
 P:=Pos(' ',S);
 If P>0 Then Begin Cmd:=Upper(Copy(S,1,P-1));Arg:=TrimS(Copy(S,P+1,200));End
 Else Begin Cmd:=Upper(S);Arg:='';End;
 { affectation de registre }
 P:=Pos('=',S);
 If P>1 Then Begin
  U:=Upper(TrimS(Copy(S,1,P-1)));
  If MonEval(Copy(S,P+1,100),V) Then Begin
   R:=RegOf(U);
   If (R>=0) And (R<16) Then Begin Rg[R]:=V;Exit;End;
   If U='PC' Then Begin PC:=V;MonDisAddr:=V;Exit;End;
   If U='SR' Then Begin SetSR(V);Exit;End;
   If U='SP' Then Begin Rg[15]:=V;Exit;End;
  End;
  MonPrint(T3('Bad assignment','Affectation incorrecte','Falsche Zuweisung'));
  Exit;
 End;
 If Cmd='?' Then Begin
  If MonEval(Arg,V) Then
   MonPrint('$'+Hex8(V)+'  #'+IntStr(V)+'  %'+IntStr(V And $FFFF)+' ('+T3('word','mot','Wort')+')')
  Else MonPrint(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else If Cmd='D' Then Begin
  If Arg='' Then MonDisAddr:=PC
  Else If MonEval(Arg,V) Then MonDisAddr:=V
  Else MonPrint(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else If Cmd='M' Then Begin
  If Arg='' Then MonMemAddr:=Rg[15]
  Else If MonEval(Arg,V) Then MonMemAddr:=V
  Else MonPrint(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else If (Cmd='T') Or (Cmd='Z') Then Begin
  V:=1;
  If Arg<>'' Then If Not MonEval(Arg,V) Then V:=1;
  MonTraceN(V);
 End Else If Cmd='S' Then MonStepOver
 Else If Cmd='G' Then Begin
  If Arg<>'' Then Begin
   If MonEval(Arg,V) Then PC:=V Else Begin MonPrint(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));Exit;End;
  End;
  MonRunUntil(-1);
 End Else If Cmd='B' Then Begin
  If Arg='' Then V:=PC Else If Not MonEval(Arg,V) Then Begin
   MonPrint(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));Exit;End;
  ToggleBp(V);
 End Else If Cmd='BC' Then Begin NBps:=0;MonPrint(T3('Breakpoints cleared','Points d''arret effaces','Haltepunkte geloescht'));End
 Else If Cmd='BL' Then Begin
  If NBps=0 Then MonPrint(T3('No breakpoints','Aucun point d''arret','Keine Haltepunkte'));
  For I:=1 To NBps Do MonPrint('  $'+Hex6(Bps[I])+'  '+DbgFind(Bps[I]));
 End Else If Cmd='F' Then Begin
  N:=SplitTop(Arg,Prt,3);
  If N<3 Then Begin
   MonPrint('F addr,len,value');
  End Else If MonEval(Prt[0],V) And MonEval(Prt[1],V2) And MonEval(Prt[2],V3) Then Begin
   For I:=0 To V2-1 Do Wr8(V+I,V3 And $FF);
   ClrErr;
  End;
 End Else If Cmd='L' Then Begin
  If Arg='' Then MonPrint(T3('Usage: L file','Syntaxe : L fichier','Syntax: L Datei')) Else MonLoad(Arg);
 End Else If Cmd='X' Then Begin
  If ProgName<>'' Then MonLoad(ProgName);
 End Else If (Cmd='V') Then ViewProgramScreen
 Else If (Cmd='H') Or (Cmd='HELP') Then MonHelp
 Else If (Cmd='Q') Or (Cmd='QUIT') Then MonQuit:=True
 Else If Cmd='R' Then Begin End
 Else MonPrint(T3('Unknown command (H for help)','Commande inconnue (H pour l''aide)','Unbekannter Befehl (H fuer Hilfe)'));
End;

{ Boucle principale du moniteur }
Procedure RunMonitor(Const Prog: String; Prompt: Boolean);
Var E: TEvent; Done: Boolean; S: String; Dirty: Boolean;
Begin
 MonActive:=True;MonQuit:=False;EmuVisible:=False;Dirty:=True;
 MonCmd:='';
 If Prog<>'' Then MonLoad(Prog)
 Else If Prompt Then Begin
  S:='';
  DrawMonitor;
  If InputDlg(T3('Executable file to load','Fichier executable a charger','Zu ladendes Programm'),'',S,40) Then
   If S<>'' Then MonLoad(S);
 End;
 If Not MonLoaded Then MonPrint(T3('Type H for help, L file to load a program','Tapez H pour l''aide, L fichier pour charger un programme','H fuer Hilfe, L Datei zum Laden'));

 While Not MonQuit Do Begin
  If Dirty Then Begin DrawMonitor;Dirty:=False;End;
  PollEvent(E);
  If (E.Kind=1) Or (E.Kind=2) Then Dirty:=True;
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin
              If MonCmd<>'' Then MonCmdHist:=MonCmd;
              S:=MonCmd;MonCmd:='';
              MonExec(S);
             End;
    K_ESC: MonCmd:='';
    K_BKSP: If Length(MonCmd)>0 Then Dec(MonCmd[0]);
    K_UP: MonCmd:=MonCmdHist;
    K_F7,26: MonTraceN(1);
    K_F8,1: MonStepOver;
    K_F9,18: MonRunUntil(-1);
    K_F10: ViewProgramScreen;
    K_F1: MonHelp;
    17: MonQuit:=True;
    32..255: If Length(MonCmd)<70 Then MonCmd:=MonCmd+Chr(E.Key);
   End;
  End;
 End;
 MonActive:=False;EmuVisible:=False;
 NeedDraw:=True;
End;

{ ====================================================================== }
{                       APPLICATION : COMMANDES                          }
{ ====================================================================== }

Var
 IdleOK     : Boolean;
 RunOther   : String;
 RunOtherArg: String;
 FileQueue  : Array[1..20] Of String[120];
 NQueue     : Integer;
 StartAction: Char;            { ' ', 'A', 'X', 'D', 'M' }
 PreDefs    : Array[1..10] Of String[80];
 NPre       : Integer;
 LastAsmOk  : Boolean;

Procedure IdleTick;
Begin
 Inc(TickCount);
 If Not IdleOK Then Exit;
 If PrefFlash=1 Then Begin
  If (TickCount Mod 70)=0 Then Begin
   CursorOn:=Not CursorOn;
   If MenuOpen=0 Then DrawCursor(CursorOn);
  End;
 End;
End;

Procedure DrawAll;
Begin
 HideMouse;
 SetViewPort(0,0,SCR_W-1,SCR_H-1,True);
 EnsureVisible;
 DrawEditor;
 DrawMenuBar;
 DrawDropDown;
 CursorOn:=True;
 If MenuOpen=0 Then DrawCursor(True);
 ShowMouse;
 NeedDraw:=False;
End;

Function MEnabled(M,I: Integer): Boolean;
Begin
 MEnabled:=True;
 If M=3 Then Begin
  If (I=2) And (FindStr='') Then MEnabled:=False;
  If (I=8) Or (I=9) Or (I=11) Then MEnabled:=BlkSet;
  If (I=10) Then MEnabled:=ClipN>0;
 End;
 If (M=2) And (I=6) Then MEnabled:=BlkSet;
 If (M=5) And (I=7) Then MEnabled:=AsmErrors>0;
 If (M=4) And (I=3) Then MEnabled:=True;
End;

{ ---------------------------------------------------------------------- }
{ Utilitaires d'interface                                                  }
{ ---------------------------------------------------------------------- }

Procedure WaitAnyKey;
Var E: TEvent;
Begin
 Repeat PollEvent(E);Until (E.Kind=1) Or (E.Kind=2);
 Repeat PollEvent(E);Until (E.Kind<>2) And ((MB And 3)=0);
End;

Procedure ShowTextScreen(Wait: Boolean);
Var I,First,Y: Integer;
Begin
 HideMouse;
 Box(0,0,SCR_W-1,SCR_H-1,PAPER);
 First:=1;
 If AsmLogN>46 Then First:=AsmLogN-45;
 Y:=4;
 For I:=First To AsmLogN Do Begin
  PText(4,Y,AsmLog[I]^);
  Y:=Y+10;
 End;
 If Wait Then Begin
  Y:=SCR_H-14;
  PText(4,Y,T3('Press any key','Appuyez sur une touche','Taste druecken'));
 End;
 ShowMouse;
 If Wait Then WaitAnyKey;
End;

Function MainFileName: String;
Begin
 If EdFile<>'' Then MainFileName:=EdFile
 Else If AmigaMode Then MainFileName:='NONAME.s' Else MainFileName:='NONAME.S';
End;

Procedure JumpToError;
Var K: Integer;
Begin
 If AsmErrors=0 Then Begin
  Alert1(1,T3('No errors','Aucune erreur','Keine Fehler'));Exit;
 End;
 K:=ErrJump;
 If (K<1) Or (K>AsmErrors) Or (K>MAXERR) Then K:=1;
 If ErrNm[K]='' Then Begin
  GotoLine(ErrLn[K]);
  MoveCur(ErrLn[K],1);
 End;
 If ErrNm[K]='' Then Alert1(3,ErrTx[K])
 Else Alert1(3,ErrNm[K]+'|'+T3('line ','ligne ','Zeile ')+IntStr(ErrLn[K])+'|'+ErrTx[K]);
 ErrJump:=K+1;
 If ErrJump>AsmErrors Then ErrJump:=1;
End;

Procedure ApplyPreDefs;
Var I,P: Integer; V: LongInt;
Begin
 For I:=1 To NPre Do Begin
  P:=Pos('=',PreDefs[I]);
  If P>0 Then DefSym(Copy(PreDefs[I],1,P-1),ToInt(Copy(PreDefs[I],P+1,40)),SEC_ABS,1)
  Else DefSym(PreDefs[I],1,SEC_ABS,1);
 End;
End;

{ Assemble le tampon de l'editeur ; affiche le compte rendu }
Function DoAssemble(ShowLog,ForRun: Boolean): Boolean;
Var Ok: Boolean;
Begin
 AsmFromEditor:=True;
 HaveOutput:=False;
 If Not ForRun Then Begin End;
 Ok:=AssembleSource(MainFileName,Ed,EdN);
 LastAsmOk:=Ok;
 If ShowLog Or Not Ok Then ShowTextScreen(True);
 NeedDraw:=True;
 If Not Ok Then Begin
  ErrJump:=1;
  If AsmErrors>0 Then JumpToError;
 End;
 DoAssemble:=Ok;
End;

{ Execute un programme dans l'emulateur avec affichage graphique }
Procedure RunProgramGUI(Const Name,Cmd: String);
Var Msg,Cur,Nxt: String; I: LongInt;
Begin
 Cur:=Name;
 Repeat
  If Not LoadProgram(Cur,Cmd,OptRunGem) Then Begin
   Alert1(3,T3('Cannot load the program|','Impossible de charger le programme|','Programm nicht ladbar|')+ShortName(Cur));
   Exit;
  End;
  HideMouse;
  MonActive:=False;EmuVisible:=True;
  ConClear;
  BlitScreen(True);
  UserBreak:=False;
  ShelNext:='';
  If Emu_GEM Then GemBoot;
  While ((StopReason=STOP_NONE) Or (StopReason=STOP_YIELD)) And Not UserBreak Do Begin
   RunCpu(30000);
   If StopReason=STOP_YIELD Then GemDispatch;
   PollInput;
   BlitScreen(False);
  End;
  If UserBreak Then Begin StopReason:=STOP_USER;StopMsg:='^C';End;
  Nxt:=ShelNext;
  If (Nxt<>'') And (StopReason=STOP_EXIT) Then Begin
   CloseAllFiles;
   Cur:=Nxt;
  End Else Nxt:='';
 Until Nxt='';
 Case StopReason Of
  STOP_EXIT: Msg:=T3('Program terminated, exit code ','Programme termine, code ','Programm beendet, Code ')+IntStr(ExitCode);
  STOP_FAULT: Msg:=StopMsg;
  STOP_USER: Msg:=T3('Interrupted (^C)','Interrompu (^C)','Unterbrochen (^C)');
  STOP_STOP: Msg:='STOP';
 Else Msg:='';
 End;
 If UnknownCall<>'' Then Msg:=Msg+' ['+UnknownCall+']';
 If Msg<>'' Then Begin
  MouseHidden:=0;
  BText(0,384,PadR(' '+Msg+' - '+T3('press a key','appuyez sur une touche','Taste druecken'),80),True);
  BlitScreen(False);
 End;
 KQHead:=0;KQTail:=0;UserBreak:=False;
 MouseHidden:=0;
 SetMouseShape(0);
 ShowMouse;
 WaitAnyKey;
 EmuVisible:=False;
 CloseAllFiles;
 NeedDraw:=True;
End;

Procedure CleanTemp;
Var F: File;
Begin
 If OutIsTemp And (OutPathFinal<>'') And FileExists(OutPathFinal) Then Begin
  Assign(F,OutPathFinal);
  {$I-}
  Erase(F);
  {$I+}
  If IOResult<>0 Then Begin End;
 End;
End;

Procedure CmdAssemble;
Begin
 DoAssemble(True,False);
 CleanTemp;
End;

Procedure CmdRun;
Begin
 If DoAssemble(False,True) Then Begin
  RunProgramGUI(OutPathFinal,'');
  CleanTemp;
 End;
End;

Procedure CmdDebug;
Var SaveDbg: Boolean;
Begin
 SaveDbg:=OptDebug;
 OptDebug:=True;
 If DoAssemble(False,True) Then Begin
  OptDebug:=SaveDbg;
  RunMonitor(OutPathFinal,False);
  CleanTemp;
 End;
 OptDebug:=SaveDbg;
 NeedDraw:=True;
End;

Procedure CmdMonitor;
Begin
 RunMonitor('',True);
 NeedDraw:=True;
End;

Procedure CmdRunOther;
Var R: Integer; S: String;
Begin
 DlgReset(60,6);
 DlgLabel(1,0,T3('Run other program','Executer un autre programme','Anderes Programm starten'));
 DlgLabel(1,1,T3('Program     :','Programme    :','Programm     :'));
 DlgEdit(15,1,40,RunOther);
 DlgLabel(1,2,T3('Command line:','Ligne de cmd. :','Kommandozeile:'));
 DlgEdit(15,2,40,RunOtherArg);
 DlgButton(2,4,10,'OK',1,True);
 DlgButton(14,4,14,T3('Select...','Choisir...','Waehlen...'),2,False);
 DlgButton(30,4,12,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R=2 Then Begin
  S:=RunOther;
  If FileSelect(T3('Program to run','Programme a executer','Programm'),'*.*',S) Then Begin
   RunOther:=S;
   RunProgramGUI(RunOther,RunOtherArg);
  End;
  Exit;
 End;
 If R=1 Then Begin
  RunOther:=DI[3].Val;RunOtherArg:=DI[5].Val;
  If RunOther<>'' Then RunProgramGUI(RunOther,RunOtherArg);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Fichiers                                                                 }
{ ---------------------------------------------------------------------- }

Function ConfirmDiscard: Boolean;
Var R: Integer;
Begin
 ConfirmDiscard:=True;
 If Not EdMod Then Exit;
 R:=AlertBox(2,T3('The text has been modified|Discard the changes ?','Le texte a ete modifie|Abandonner les modifications ?','Der Text wurde geaendert|Aenderungen verwerfen ?'),
  T3('Cancel|Discard','Annuler|Abandonner','Abbruch|Verwerfen'),1);
 ConfirmDiscard:=R=2;
End;

Procedure CmdNew;
Begin
 If Not ConfirmDiscard Then Exit;
 EdClear;
 EdFile:='';
 NeedDraw:=True;
End;

Procedure CmdLoad;
Var P: String;
Begin
 If Not ConfirmDiscard Then Exit;
 P:=EdFile;
 If FileSelect(T3('Load file','Charger un fichier','Datei laden'),'*.S',P) Then
  EdLoadFile(P,False);
 NeedDraw:=True;
End;

Procedure CmdSaveAs;
Var P: String;
Begin
 P:=EdFile;
 If FileSelect(T3('Save file as','Sauver le fichier sous','Datei sichern als'),'*.S',P) Then Begin
  If FileExists(P) Then
   If AlertBox(2,T3('File exists|Overwrite it ?','Le fichier existe|Le remplacer ?','Datei existiert|Ueberschreiben ?'),
        T3('Cancel|Overwrite','Annuler|Remplacer','Abbruch|Ueberschr.'),1)<>2 Then Begin NeedDraw:=True;Exit;End;
  EdSaveFile(P);
 End;
 NeedDraw:=True;
End;

Procedure CmdSave;
Begin
 If EdFile='' Then CmdSaveAs Else EdSaveFile(EdFile);
 NeedDraw:=True;
End;

Procedure CmdAppend;
Var P: String;
Begin
 P:='';
 If FileSelect(T3('Append file','Ajouter un fichier','Datei anhaengen'),'*.S',P) Then
  EdLoadFile(P,True);
 NeedDraw:=True;
End;

Procedure CmdSaveBlock;
Var P: String;
Begin
 If Not BlkSet Then Exit;
 P:='';
 If FileSelect(T3('Save block as','Sauver le bloc sous','Block sichern als'),'*.S',P) Then
  SaveBlockFile(P);
 NeedDraw:=True;
End;

Procedure CmdQuit;
Var R: Integer;
Begin
 If EdMod Then Begin
  R:=AlertBox(2,T3('The text has been modified','Le texte a ete modifie','Der Text wurde geaendert'),
       T3('Save|Quit|Cancel','Sauver|Quitter|Annuler','Sichern|Ende|Abbruch'),1);
  If R=1 Then Begin CmdSave;If EdMod Then Exit;End
  Else If R<>2 Then Begin NeedDraw:=True;Exit;End;
 End;
 Quit:=True;
End;

Procedure CmdAbout;
Var R: Integer;
Begin
 DlgReset(46,13);
 DlgAdd(DK_BOXED,5,1,32,'  '+AsmName+' 68000 Editor/Assembler');
 DlgLabel(11,3,T3('DEV-COOLS clone, 2026','Clone DEV-COOLS, 2026','DEV-COOLS-Klon, 2026'));
 DlgLabel(2,5,T3('Inspired by HiSoft Devpac v','Inspire de HiSoft Devpac v','Nach HiSoft Devpac v')+VERSION_TEXT);
 DlgLabel(2,6,T3('Author: Sylvain Maltais','Auteur : Sylvain Maltais','Autor: Sylvain Maltais'));
 DlgLabel(2,7,'www.gladir.com/dev-cools');
 If AmigaMode Then DlgAdd(DK_BOXED,7,9,28,T3(' Mode: Commodore Amiga',' Mode : Commodore Amiga',' Modus: Commodore Amiga'))
 Else DlgAdd(DK_BOXED,7,9,28,T3(' Mode: Atari ST',' Mode : Atari ST',' Modus: Atari ST'));
 DlgButton(18,11,8,'OK',1,True);
 R:=DlgRun;
End;

Procedure CmdHelp;
Var R: Integer;
Begin
 R:=AlertBox(3,
  T3('^N New  ^L Load  ^S Save  ^Q Quit|^F Find  ^G Next  ^R Replace  ^W Goto|^C Copy  ^U Cut  ^V Paste  ^B Delete|F5/F6 Block start/end  ^Y Delete line|^A Assemble  ^X Run  ^D Debug|AltM '+MonName+'  ^K GEM  ^J Jump  ^O Other',
     '^N Nouveau  ^L Charger  ^S Sauver  ^Q Quitter|^F Chercher  ^G Suivant  ^R Remplacer  ^W Aller|^C Copier  ^U Couper  ^V Coller  ^B Effacer|F5/F6 Debut/fin de bloc  ^Y Effacer ligne|^A Assembler  ^X Executer  ^D Deboguer|AltM '+MonName+'  ^K GEM  ^J Erreur  ^O Autre',
     '^N Neu  ^L Laden  ^S Sichern  ^Q Ende|^F Suchen  ^G Weiter  ^R Ersetzen  ^W Gehe zu|^C Kopieren  ^U Ausschn.  ^V Einfuegen  ^B Loeschen|F5/F6 Blockanfang/-ende  ^Y Zeile loeschen|^A Assemblieren  ^X Starten  ^D Debuggen|AltM '+MonName+'  ^K GEM  ^J Fehler  ^O Anderes'),
  'OK',1);
End;

Procedure CmdMemory;
Begin
 Alert1(3-2,T3('Text buffer: ','Tampon texte : ','Textpuffer: ')+IntStr(PrefBuf)+T3(' bytes',' octets',' Bytes')+'|'+
   T3('Used       : ','Utilise      : ','Benutzt    : ')+IntStr(EdMem)+'|'+
   T3('Free       : ','Libre        : ','Frei       : ')+IntStr(MemFree)+'|'+
   T3('Lines      : ','Lignes       : ','Zeilen     : ')+IntStr(EdN)+'|'+
   T3('Emulated RAM: ','RAM emulee   : ','Emul. RAM : ')+IntStr(MemSize Div 1024)+' KB');
End;

Procedure RunOptionsDlg;
Var R: Integer;
Begin
 DlgReset(46,9);
 DlgLabel(2,0,T3('Run / debug options','Options d''execution / debogage','Start- / Debug-Optionen'));
 DlgLabel(2,2,T3('GEM        :','GEM         :','GEM         :'));
 DlgRadio(16,2,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptRunGem));
 DlgLabel(2,3,T3('Accessories:','Accessoires :','Accessories :'));
 DlgRadio(16,3,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptAccs));
 DlgLabel(2,4,'           '+T3('(*.ACC from the program folder)','(*.ACC du dossier du programme)','(*.ACC aus dem Programmordner)'));
 DlgButton(2,6,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(14,6,10,T3('Save','Sauver','Sichern'),2,False);
 DlgButton(26,6,10,'OK',1,True);
 R:=DlgRun;
 If R=0 Then Exit;
 OptRunGem:=DI[3].Sel=1;
 OptAccs:=DI[5].Sel=1;
 If R=2 Then SavePrefs;
End;

Procedure DoMenu(M,I: Integer);
Begin
 Case M Of
  1: Case I Of
      1: CmdAbout;
      3: CmdHelp;
      4: CmdMemory;
     End;
  2: Case I Of
      1: CmdNew;
      2: CmdLoad;
      3: CmdSave;
      4: CmdSaveAs;
      5: CmdAppend;
      6: CmdSaveBlock;
      8: CmdQuit;
     End;
  3: Case I Of
      1: DoFind;
      2: DoFindNext;
      3: DoReplace;
      4: DoGotoLine;
      6: Begin BlkSL:=CurL;BlkSC:=CurC;BlkAnch:=True;BlkSet:=False;End;
      7: Begin
          If BlkAnch Then Begin BlkEL:=CurL;BlkEC:=CurC;BlkSet:=True;BlkAnch:=False;End
          Else Alert1(1,T3('Set the block start first','Posez d''abord le debut du bloc','Zuerst Blockanfang setzen'));
         End;
      8: CopyBlock;
      9: Begin CopyBlock;DeleteBlock;End;
      10: PasteBlock;
      11: DeleteBlock;
      13: SelectAll;
     End;
  4: Case I Of
      1: EditorPrefsDlg;
      2: AsmOptionsDlg;
      3: RunOptionsDlg;
      5: SavePrefs;
      6: LoadPrefs;
     End;
  5: Case I Of
      1: CmdAssemble;
      2: CmdRun;
      3: CmdDebug;
      4: CmdMonitor;
      5: OptRunGem:=Not OptRunGem;
      7: JumpToError;
      8: CmdRunOther;
     End;
 End;
 NeedDraw:=True;
End;

{ ---------------------------------------------------------------------- }
{ Clavier et souris                                                         }
{ ---------------------------------------------------------------------- }

Procedure CtrlCommand(K: Word);
Begin
 Case K Of
  1: CmdAssemble;
  2: DeleteBlock;
  3: CopyBlock;
  4: CmdDebug;
  6: DoFind;
  7: DoFindNext;
  10: JumpToError;
  11: OptRunGem:=Not OptRunGem;
  12: CmdLoad;
  14: CmdNew;
  15: CmdRunOther;
  17: CmdQuit;
  18: DoReplace;
  19: CmdSave;
  21: Begin CopyBlock;DeleteBlock;End;
  22: PasteBlock;
  23: DoGotoLine;
  24: CmdRun;
  25: DeleteCurLine;
 End;
End;

Procedure HandleKey(K: Word);
Var S: String; V: Integer; HadBlock: Boolean;
Begin
 If (K>=1) And (K<=26) And (K<>8) And (K<>9) And (K<>13) Then Begin
  CtrlCommand(K);NeedDraw:=True;Exit;
 End;
 Case K Of
  K_F1: CmdHelp;
  K_F5: DoMenu(3,6);
  K_F6: DoMenu(3,7);
  K_F10: RunMenu(1,False);
  K_F9: CmdRun;
  256+50: CmdMonitor;
  K_UP: Begin
         If CurL>1 Then Begin
          Dec(CurL);CurC:=CharOfVis(Ed^[CurL]^,WantV);
          EnsureVisible;
         End;
        End;
  K_DOWN: Begin
         If CurL<EdN Then Begin
          Inc(CurL);CurC:=CharOfVis(Ed^[CurL]^,WantV);
          EnsureVisible;
         End;
        End;
  K_LEFT: Begin
         If CurC>1 Then Dec(CurC)
         Else If CurL>1 Then Begin Dec(CurL);CurC:=Length(Ed^[CurL]^)+1;End;
         EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
        End;
  K_RIGHT: Begin
         If CurC<=Length(Ed^[CurL]^) Then Inc(CurC)
         Else If CurL<EdN Then Begin Inc(CurL);CurC:=1;End;
         EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
        End;
  K_CLEFT: WordLeft;
  K_CRIGHT: WordRight;
  K_HOME: Begin CurC:=1;EnsureVisible;WantV:=0;End;
  K_END: Begin CurC:=Length(Ed^[CurL]^)+1;EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);End;
  K_CHOME: Begin CurL:=1;CurC:=1;TopL:=1;EnsureVisible;WantV:=0;End;
  K_CEND: Begin CurL:=EdN;CurC:=Length(Ed^[CurL]^)+1;EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);End;
  K_PGUP: Begin
         CurL:=Max2(1,CurL-TXT_ROWS+1);TopL:=Max2(1,TopL-TXT_ROWS+1);
         CurC:=CharOfVis(Ed^[CurL]^,WantV);EnsureVisible;
        End;
  K_PGDN: Begin
         CurL:=Min2(EdN,CurL+TXT_ROWS-1);
         If TopL+TXT_ROWS-1<EdN Then TopL:=Min2(EdN,TopL+TXT_ROWS-1);
         CurC:=CharOfVis(Ed^[CurL]^,WantV);EnsureVisible;
        End;
  K_INS: EdIns:=Not EdIns;
  K_DEL: Begin
          If BlkSet Then DeleteBlock Else DoDelete;
         End;
  K_BKSP: Begin
           If BlkSet Then DeleteBlock Else DoBackspace;
          End;
  K_ENTER: Begin
            If BlkSet Then ClearBlock;
            NewLineAt;
           End;
  K_TAB: Begin ClearBlock;DoTab;End;
  K_ESC: ClearBlock;
  32..255: Begin
            If BlkSet Then ClearBlock;
            InsertChar(Chr(K));
           End;
 End;
 NeedDraw:=True;
End;

Procedure EdPosAt(X,Y: LongInt; Var L,C: Integer);
Var V: Integer;
Begin
 L:=TopL+((Y-TY0) Div LINE_H);
 If Y<TY0 Then L:=TopL-1;
 If L<1 Then L:=1;
 If L>EdN Then L:=EdN;
 V:=LeftV+((X-TX0+4) Div 8);
 If X<TX0 Then V:=LeftV-1;
 If V<0 Then V:=0;
 C:=CharOfVis(Ed^[L]^,V);
End;

Procedure VScroll(D: Integer);
Begin
 TopL:=Clamp(TopL+D,1,Max2(1,EdN-TXT_ROWS+1));
End;

Procedure MouseDown(X,Y,B: LongInt);
Var T,L,C: Integer; Y1,Y2,H: LongInt;
Begin
 T:=TitleHit(X,Y);
 If T>0 Then Begin RunMenu(T,True);Exit;End;
 If Y<WY1 Then Exit;
 If InBox(X,Y,WX1+1,WY1+1,WX1+17,WY1+TITLE_H-2) Then Begin CmdQuit;Exit;End;
 If InBox(X,Y,TX0-4,TY0,TXT_X2,TXT_Y2) Then Begin
  EdPosAt(X,Y,L,C);
  MoveCur(L,C);
  ClearBlock;
  DragSel:=True;AnchL:=L;AnchC:=C;
  NeedDraw:=True;
  Exit;
 End;
 If X>TXT_X2 Then Begin
  Y1:=TY0+SB_W-1;Y2:=TXT_Y2-SB_W+1;
  If InBox(X,Y,TXT_X2+1,TY0-1,WX2,TY0+SB_W-2) Then VScroll(-1)
  Else If InBox(X,Y,TXT_X2+1,TXT_Y2-SB_W+2,WX2,TXT_Y2+1) Then VScroll(1)
  Else If (Y>=Y1) And (Y<=Y2) Then Begin
   H:=Y2-Y1;
   TopL:=Clamp(1+(Y-Y1)*Max2(0,EdN-TXT_ROWS) Div Max2(1,H),1,Max2(1,EdN-TXT_ROWS+1));
  End;
  NeedDraw:=True;Exit;
 End;
 If Y>TXT_Y2 Then Begin
  If X<WX1+SB_W Then LeftV:=Max2(0,LeftV-4)
  Else If X>TXT_X2-SB_W Then LeftV:=LeftV+4
  Else If X<(WX1+TXT_X2) Div 2 Then LeftV:=Max2(0,LeftV-TXT_COLS Div 2)
  Else LeftV:=LeftV+TXT_COLS Div 2;
  NeedDraw:=True;
 End;
End;

Procedure MouseMove(X,Y: LongInt);
Var L,C: Integer;
Begin
 If DragSel And ((MB And 3)<>0) Then Begin
  EdPosAt(X,Y,L,C);
  If (L<>CurL) Or (C<>CurC) Then Begin
   CurL:=L;CurC:=C;
   BlkSL:=AnchL;BlkSC:=AnchC;BlkEL:=L;BlkEC:=C;
   BlkSet:=(L<>AnchL) Or (C<>AnchC);
   EnsureVisible;
   WantV:=VisOf(Ed^[CurL]^,CurC);
   NeedDraw:=True;
  End;
 End;
End;

Procedure MouseUp;
Begin
 DragSel:=False;
End;

Procedure MainLoop;
Var E: TEvent;
Begin
 Repeat
  If NeedDraw Then DrawAll;
  IdleOK:=True;
  PollEvent(E);
  IdleOK:=False;
  Case E.Kind Of
   1: HandleKey(E.Key);
   2: MouseDown(E.X,E.Y,E.B);
   3: MouseUp;
   4: MouseMove(E.X,E.Y);
  End;
 Until Quit;
End;

{ ---------------------------------------------------------------------- }
{ Ligne de commande                                                        }
{ ---------------------------------------------------------------------- }

Procedure ShowHelpLine;
Begin
 WriteLn(ConOut,'DEVPAC - '+T3('Clone of HiSoft Devpac (Atari ST / Commodore Amiga).',
   'Clone de HiSoft Devpac (Atari ST / Commodore Amiga).','Klon von HiSoft Devpac (Atari ST / Commodore Amiga).'));
 WriteLn(ConOut);
 WriteLn(ConOut,T3('Usage : DEVPAC [options] [file.S ...]','Syntaxe : DEVPAC [options] [fichier.S ...]','Aufruf : DEVPAC [Optionen] [Datei.S ...]'));
 WriteLn(ConOut);
 WriteLn(ConOut,'  /ATARIST    '+T3('Atari ST mode: GenST, MonST, GEMDOS .PRG (default)','Mode Atari ST : GenST, MonST, .PRG GEMDOS (defaut)','Atari-ST-Modus: GenST, MonST, GEMDOS-.PRG (Standard)'));
 WriteLn(ConOut,'  /AMIGA      '+T3('Amiga mode: GenAm, MonAm, Hunk executable','Mode Amiga : GenAm, MonAm, executable Hunk','Amiga-Modus: GenAm, MonAm, Hunk-Programm'));
 WriteLn(ConOut,'  /A          '+T3('assemble the file(s) at startup','assemble le(s) fichier(s) au demarrage','Datei(en) beim Start assemblieren'));
 WriteLn(ConOut,'  /X          '+T3('assemble then run the program','assemble puis execute le programme','assemblieren und starten'));
 WriteLn(ConOut,'  /D          '+T3('assemble then debug (MonST/MonAm)','assemble puis debogue (MonST/MonAm)','assemblieren und debuggen'));
 WriteLn(ConOut,'  /M          '+T3('start MonST/MonAm on the executable given','lance MonST/MonAm sur l''executable indique','MonST/MonAm mit dem Programm starten'));
 WriteLn(ConOut,'  /B          '+T3('batch mode (no graphics): assemble, with /X run it','mode batch (sans graphisme) : assemble, avec /X execute','Batch-Modus (ohne Grafik): assemblieren, mit /X starten'));
 WriteLn(ConOut,'  /L          '+T3('produce a listing file (.LST)','produit un fichier de listing (.LST)','Listing-Datei (.LST) erzeugen'));
 WriteLn(ConOut,'  /S          '+T3('include the symbol table (debug) in the executable','inclut la table des symboles (debug) dans l''executable','Symboltabelle (Debug) im Programm'));
 WriteLn(ConOut,'  /O          '+T3('optimise branches (OPT O+)','optimise les branchements (OPT O+)','Spruenge optimieren (OPT O+)'));
 WriteLn(ConOut,'  /OUT:file   '+T3('output file name','nom du fichier de sortie','Name der Ausgabedatei'));
 WriteLn(ConOut,'  /INC:dir    '+T3('INCLUDE search directory','repertoire de recherche des INCLUDE','Suchverzeichnis fuer INCLUDE'));
 WriteLn(ConOut,'  /DEF:n=v    '+T3('define the symbol n with the value v','definit le symbole n avec la valeur v','Symbol n mit Wert v definieren'));
 WriteLn(ConOut,'  /NODISK     '+T3('assemble to memory only (no output file)','assemble en memoire seulement (pas de fichier)','nur im Speicher assemblieren'));
 WriteLn(ConOut,'  /FLA:file   '+T3('floppy image for drive A: (also /FLB: /FLC: /FLD:; default DISKA.ST ...)','image de disquette du lecteur A: (aussi /FLB: /FLC: /FLD: ; defaut DISKA.ST ...)','Diskettenabbild fuer Laufwerk A: (auch /FLB: /FLC: /FLD:; Standard DISKA.ST ...)'));
 WriteLn(ConOut,'  /NOGEM      '+T3('run programs without GEM (VDI/AES)','execute sans GEM (VDI/AES)','ohne GEM (VDI/AES) starten'));
 WriteLn(ConOut,'  /?          '+T3('this help','cette aide','diese Hilfe'));
 WriteLn(ConOut);
 WriteLn(ConOut,T3('Language: French by default, LANGUAGE=EN for English, LANGUAGE=GR for German.',
   'Langue : francais par defaut, LANGUAGE=EN pour l''anglais, LANGUAGE=GR pour l''allemand.',
   'Sprache: Franzoesisch als Standard, LANGUAGE=EN fuer Englisch, LANGUAGE=GR fuer Deutsch.'));
End;

Function IsOption(Const A: String): Boolean;
Var U: String;
Begin
 U:=Upper(A);
 If (U='') Or ((U[1]<>'/') And (U[1]<>'-')) Then Begin IsOption:=False;Exit;End;
 U:=Copy(U,2,200);
 If (U<>'') And (U[1]='-') Then U:=Copy(U,2,200);
 IsOption:=(U='?') Or (U='H') Or (U='HELP') Or (U='ATARIST') Or (U='AMIGA') Or (U='A') Or
  (U='X') Or (U='D') Or (U='M') Or (U='B') Or (U='L') Or (U='S') Or (U='O') Or
  (U='NODISK') Or (U='NOGEM') Or (Copy(U,1,4)='OUT:') Or (Copy(U,1,4)='INC:') Or
  (Copy(U,1,4)='DEF:') Or ((Copy(U,1,2)='FL') And (Length(U)>=5) And (U[3]>='A') And (U[3]<='D') And (U[4]=':'));
End;

Procedure ParseCommandLine;
Var I: Integer; A,U: String; HelpWanted: Boolean;
Begin
 HelpWanted:=False;NQueue:=0;StartAction:=' ';NPre:=0;
 For I:=1 To ParamCount Do Begin
  A:=ParamStr(I);
  If IsOption(A) Then Begin
   U:=Upper(Copy(A,2,200));
   If (U<>'') And (U[1]='-') Then U:=Copy(U,2,200);
   If (U='?') Or (U='H') Or (U='HELP') Then HelpWanted:=True
   Else If U='ATARIST' Then AmigaMode:=False
   Else If U='AMIGA' Then AmigaMode:=True
   Else If U='A' Then StartAction:='A'
   Else If U='X' Then StartAction:='X'
   Else If U='D' Then StartAction:='D'
   Else If U='M' Then StartAction:='M'
   Else If U='B' Then BatchMode:=True
   Else If U='L' Then OptListing:=True
   Else If U='S' Then OptDebug:=True
   Else If U='O' Then OptOptimize:=True
   Else If U='NODISK' Then OptToDisk:=False
   Else If U='NOGEM' Then OptRunGem:=False
   Else If Copy(U,1,4)='OUT:' Then OptOutName:=Copy(A,Pos(':',A)+1,200)
   Else If Copy(U,1,4)='INC:' Then OptIncPath:=Copy(A,Pos(':',A)+1,200)
   Else If (Copy(U,1,2)='FL') And (Length(U)>=5) And (U[3]>='A') And (U[3]<='D') And (U[4]=':') Then
    FlpImage[Ord(U[3])-65]:=Copy(A,6,200)
   Else If Copy(U,1,4)='DEF:' Then Begin
    If NPre<10 Then Begin Inc(NPre);PreDefs[NPre]:=Copy(A,Pos(':',A)+1,80);End;
   End;
  End Else If NQueue<20 Then Begin
   Inc(NQueue);FileQueue[NQueue]:=A;
  End;
 End;
 If HelpWanted Then Begin
  ShowHelpLine;
  Flush(ConOut);
  Halt(0);
 End;
End;

{ Mode batch : assemble (et execute) sans interface graphique }
Function BatchRun: Integer;
Var Arr: PLineArr; Cnt,I: Integer; Rc: Integer; Name,Src: String;
Begin
 Rc:=0;
 If NQueue=0 Then Begin
  WriteLn(ConOut,T3('No source file specified (DEVPAC /? for help)','Aucun fichier source indique (DEVPAC /? pour l''aide)','Keine Quelldatei angegeben (DEVPAC /? fuer Hilfe)'));
  BatchRun:=2;Exit;
 End;
 InitMemory(ST_MEMKB);
 For I:=1 To NQueue Do Begin
  Name:=FileQueue[I];
  If (Not FileExists(Name)) And FileExists(Name+'.S') Then Name:=Name+'.S';
  If (Not FileExists(Name)) And FileExists(Name+'.s') Then Name:=Name+'.s';
  If Not LoadLines(Name,Arr,Cnt) Then Begin
   WriteLn(ConOut,T3('Cannot open ','Impossible d''ouvrir ','Kann nicht oeffnen: ')+Name);
   Rc:=2;Continue;
  End;
  AsmFromEditor:=False;
  HaveOutput:=False;
  If Not AssembleSource(Name,Arr,Cnt) Then Rc:=1
  Else If StartAction='X' Then Begin
   If LoadProgram(OutPathFinal,'',OptRunGem) Then Begin
    EmuVisible:=False;MonActive:=False;
    If Emu_GEM Then GemBoot;
    While (StopReason=STOP_NONE) Or (StopReason=STOP_YIELD) Do Begin
     RunCpu(100000);
     If StopReason=STOP_YIELD Then GemDispatch;
    End;
    WriteLn(ConOut);
    If StopReason=STOP_EXIT Then Rc:=ExitCode And $FF
    Else Begin
     WriteLn(ConOut,StopMsg);Rc:=3;
    End;
    If UnknownCall<>'' Then WriteLn(ConOut,'[',UnknownCall,']');
   End Else Begin WriteLn(ConOut,'Cannot load ',OutPathFinal);Rc:=3;End;
  End;
  CleanTemp;
  FreeLines(Arr,Cnt);
 End;
 BatchRun:=Rc;
End;

Procedure InitApp;
Var S: String;
Begin
 S:=Upper(Copy(GetEnv('LANGUAGE'),1,2));
 If S='EN' Then Lang:=0
 Else If (S='GR') Or (S='DE') Then Lang:=2
 Else Lang:=1;
 FillChar(PageTab,SizeOf(PageTab),0);
 FillChar(FHUsed,SizeOf(FHUsed),0);
 InitAsmTables;
 PrefDefaults;
 OptRunGem:=True;OptAccs:=True;
 RunOther:='';RunOtherArg:='';
 FindStr:='';ReplStr:='';FindCase:=False;
 MenuOpen:=0;MenuHi:=0;
 MX:=0;MY:=0;MB:=0;LastB:=0;
 NeedDraw:=True;Quit:=False;
 ErrJump:=1;
 DbgN:=0;DbgSyms:=Nil;
 MonActive:=False;EmuVisible:=False;
 ProgName:='';
 {$IFDEF FPC}
 CurSaved:=False;CurShown:=False;
 {$ENDIF}
End;

Procedure StartupActions;
Var I: Integer; Name: String;
Begin
 If StartAction=' ' Then Exit;
 Case StartAction Of
  'A','X','D': Begin
    For I:=1 To NQueue Do Begin
     If I>1 Then Begin
      Name:=FileQueue[I];
      If FileExists(Name) Then EdLoadFile(Name,False);
     End;
     If StartAction='A' Then CmdAssemble
     Else If StartAction='X' Then CmdRun
     Else CmdDebug;
    End;
   End;
  'M': Begin
    If NQueue>0 Then RunMonitor(FileQueue[1],False) Else RunMonitor('',True);
   End;
 End;
End;

Var I: Integer;
BEGIN
 Assign(ConOut,'');Rewrite(ConOut);
 Assign(ConIn,'');Reset(ConIn);
 AmigaMode:=False;BatchMode:=False;
 AesTrace:=GetEnv('DEVPAC_TRACE')<>'';
 InitApp;
 ParseCommandLine;
 LoadPrefs;
 { les options de la ligne de commande l'emportent : on les relit }
 ParseCommandLine;
 If BatchMode Then Begin
  I:=BatchRun;
  DevCloseAll;
  Flush(ConOut);
  Halt(I);
 End;
 InitializeGraphics;
 BuildFont;
 InitMemory(ST_MEMKB);
 ScrBase:=(MemSize-SCR_BYTES) And $FFFF00;DrawBase:=ScrBase;
 EdInit;
 If NQueue>0 Then Begin
  If (StartAction<>'M') Then Begin
   If FileExists(FileQueue[1]) Then EdLoadFile(FileQueue[1],False)
   Else If FileExists(FileQueue[1]+'.S') Then EdLoadFile(FileQueue[1]+'.S',False)
   Else EdFile:=FileQueue[1];
  End;
 End;
 If MouseDriverFound Then ShowMouse;
 DrawAll;
 StartupActions;
 MainLoop;
 HideMouse;
 DevCloseAll;
 CloseGraph;
END.
