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
          independants (menu_popup, avec defilement) et sous-menus
          attaches (menu_attach),
          enregistrement et relecture d'evenements (appl_trecord/tplay),
          graf_slidebox, routines utilisateur vex_motv/butv/curv/timv,
          appl_yield/search/bvset/getinfo, objc_sysvar, rsrc_rcfix,
          form_keybd/form_button, vq_cellarray, vsc_form, vqin_mode ;
        * accessoires de bureau (fichiers .ACC) en multitache cooperatif ;
        * fils lances par Pexec : chacun a son propre contexte AES (ap_id,
          menus, fenetres, ressources), nettoye et restitue a sa fin ;
        * peripheriques : lecteurs de disquettes A:..D: sur des images .ST
          (Floprd, Flopwr, Flopfmt, Rwabs, Getbpb, Protobt...) ; sans
          image, A: est une disquette vierge formatee dont le fichier
          DISKA.ST n'est cree qu'a la premiere ecriture ; port serie
          (AUX.IN / AUX.OUT), MIDI (MIDI.IN / MIDI.OUT), imprimante
          (PRINTER.OUT), clavier intelligent (Ikbdws : modes souris
          relatif / absolu / touches, horloge, Initmous), generateur
          sonore YM2149 (Dosound, Giaccess, cloche VT52 ; sortie par
          Beep de kernel32 sous Windows, Sound/NoSound ailleurs),
          tables clavier, Iorec, Rsconf, Random ;
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
 {$modeswitch class}
{$ELSE}
 {$M 32768,0,655360}
{$ENDIF}

Uses {$IFDEF FPC}
      {$IFDEF UNIX}cthreads,{$ENDIF}
      DOS,Crt,PtcGraph,PtcCrt,PtcMouse,Ptc
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
  (30,48,46,32,18,33,34,35,23,36,37,38,50,49,24,25,16,19,31,20,22,47,17,45,21,
    44);

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

{ ---------------------------------------------------------------------- }
{ Lecture du clavier avec les modificateurs (Maj / Ctrl / Alt)            }
{ Sous FPC les evenements PTC sont lus directement (PtcCrt ne donne pas   }
{ l'etat de Maj) ; sous TP7 on lit les indicateurs du BIOS ($40:$17).      }
{ KeyMods : bit 0 = Maj, bit 1 = Ctrl, bit 2 = Alt (derniere touche lue). }
{ ---------------------------------------------------------------------- }

Const
 KM_SHIFT = 1;
 KM_CTRL  = 2;
 KM_ALT   = 4;

Var
 EnvPathS,EnvClinkS,EnvLibsS : String;   { variables d'environnement vues par
   les programmes lances (Options > Environment) }
 KeyMods : Byte;
 ModsHeld: Byte;                 { modificateurs enfonces a l'instant present
   (FPC) }
 KMQK    : Array[0..63] Of Word;
 KMQM    : Array[0..63] Of Byte;
 KMQH,KMQT : Integer;

{$IFDEF FPC}
Procedure KMAdd(K: Word; M: Byte);
Begin
 If ((KMQT+1) Mod 64)=KMQH Then Exit;
 KMQK[KMQT]:=K;KMQM[KMQT]:=M;
 KMQT:=(KMQT+1) Mod 64;
End;

{ Traduit un evenement clavier PTC en code de touche DEVPAC (caractere ou
  256+code etendu) }
Procedure KMTranslate(C,U: Integer; Sh,Ct,Al: Boolean);
Var M: Byte; K: Integer;
Begin
 M:=0;
 If Sh Then M:=M Or KM_SHIFT;
 If Ct Then M:=M Or KM_CTRL;
 If Al Then M:=M Or KM_ALT;
 K:=-1;
 If Al And Ct And (U>=32) And ((C<PTCKEY_NUMPAD0) Or (C>PTCKEY_DIVIDE)) Then
   Begin { AltGr : caractere produit }
  KMAdd(U,0);Exit;
 End;
 Case C Of
  PTCKEY_SHIFT,PTCKEY_CONTROL,PTCKEY_ALT,PTCKEY_CAPSLOCK,PTCKEY_NUMLOCK,
  PTCKEY_SCROLLLOCK,PTCKEY_META: Exit;
  PTCKEY_ESCAPE: K:=27;
  PTCKEY_ENTER: K:=13;
  PTCKEY_TAB: If Sh Then K:=256+15 Else K:=9;
  PTCKEY_BACKSPACE: If Ct Then K:=127 Else K:=8;
  PTCKEY_DELETE: K:=256+83;
  PTCKEY_INSERT: K:=256+82;
  PTCKEY_HELP: K:=256+82;
  PTCKEY_F1..PTCKEY_F10: Begin
    If Al Then K:=256+104+(C-PTCKEY_F1)
    Else If Ct Then K:=256+94+(C-PTCKEY_F1)
    Else If Sh Then K:=256+84+(C-PTCKEY_F1)
    Else K:=256+59+(C-PTCKEY_F1);
   End;
  PTCKEY_F11: K:=256+133;
  PTCKEY_F12: K:=256+134;
  PTCKEY_LEFT: If Ct Then K:=256+115 Else K:=256+75;
  PTCKEY_RIGHT: If Ct Then K:=256+116 Else K:=256+77;
  PTCKEY_UP: K:=256+72;
  PTCKEY_DOWN: K:=256+80;
  PTCKEY_HOME: If Ct Then K:=256+119 Else K:=256+71;
  PTCKEY_END: If Ct Then K:=256+117 Else K:=256+79;
  PTCKEY_PAGEUP: If Ct Then K:=256+132 Else K:=256+73;
  PTCKEY_PAGEDOWN: If Ct Then K:=256+118 Else K:=256+81;
  PTCKEY_SPACE: If Ct Then K:=256+3 Else K:=32;
  PTCKEY_A..PTCKEY_Z: Begin
    If Al Then Begin
     { Alt-lettre : code etendu = balayage (table AltScan) }
     K:=256+AltScan[C-PTCKEY_A];
    End Else If Ct Then K:=C-PTCKEY_A+1
    Else If (U>=32) And (U<=255) Then K:=U;
   End;
  PTCKEY_ZERO..PTCKEY_NINE: Begin
    If Al Then Begin
     If C=PTCKEY_ZERO Then K:=256+129 Else K:=256+120+(C-PTCKEY_ONE);
    End Else If Ct Then K:=C { Ctrl-chiffre : le caractere, modificateur Ctrl }
    Else If (U>=32) And (U<=255) Then K:=U;
   End;
  PTCKEY_DECIMAL,PTCKEY_DIVIDE,PTCKEY_MULTIPLY,PTCKEY_SUBTRACT,PTCKEY_ADD: Begin
    If Al Then Begin
     Case C Of
      PTCKEY_DECIMAL: K:=256+250;
      PTCKEY_DIVIDE: K:=256+251;
      PTCKEY_MULTIPLY: K:=256+252;
      PTCKEY_SUBTRACT: K:=256+253;
      PTCKEY_ADD: K:=256+254;
     End;
    End Else If (U>=32) And (U<=255) Then K:=U;
   End;
  PTCKEY_NUMPAD0..PTCKEY_NUMPAD9: Begin
    If Al Then K:=256+240+(C-PTCKEY_NUMPAD0)
    Else If (U>=32) And (U<=255) Then K:=U;
   End;
 Else
  If (Not Al) And (Not Ct) And (U>=32) And (U<=255) Then K:=U;
 End;
 If K>=0 Then KMAdd(K,M);
End;

Procedure KMPump;
Var Ev: IPTCEvent; KE: IPTCKeyEvent;
Begin
 If PTCWrapperObject=Nil Then Exit;
 If Not PTCWrapperObject.IsOpen Then Exit;
 While PTCWrapperObject.NextEvent(Ev,False,[PTCKeyEvent,PTCCloseEvent]) Do Begin
  If Ev.EventType=PTCCloseEvent Then KMAdd(3,0)
  Else Begin
   KE:=Ev As IPTCKeyEvent;
   { etat des modificateurs : une touche Maj/Ctrl/Alt change l'etat, les autres
     le portent }
   Case KE.Code Of
    PTCKEY_SHIFT: If KE.Press Then ModsHeld:=ModsHeld Or KM_SHIFT Else
      ModsHeld:=ModsHeld And Not KM_SHIFT;
    PTCKEY_CONTROL: If KE.Press Then ModsHeld:=ModsHeld Or KM_CTRL Else
      ModsHeld:=ModsHeld And Not KM_CTRL;
    PTCKEY_ALT: If KE.Press Then ModsHeld:=ModsHeld Or KM_ALT Else
      ModsHeld:=ModsHeld And Not KM_ALT;
   Else
    ModsHeld:=0;
    If KE.Shift Then ModsHeld:=ModsHeld Or KM_SHIFT;
    If KE.Control Then ModsHeld:=ModsHeld Or KM_CTRL;
    If KE.Alt Then ModsHeld:=ModsHeld Or KM_ALT;
   End;
   If KE.Press Then KMTranslate(KE.Code,KE.Unicode,KE.Shift,KE.Control,KE.Alt);
  End;
 End;
End;

{ modificateurs enfonces en ce moment (utile pour un clic de souris) }
Function ModsNow: Byte;
Begin
 KMPump;
 ModsNow:=ModsHeld;
End;

{ Souris : un evenement de bouton a la fois (PtcMouse ne garde que le dernier
  etat, donc un clic bref entre deux lectures etait perdu) ; les mouvements
  consecutifs sont fusionnes. }
Function GetMouseM(Var X,Y,B: LongInt): Boolean;
Var Ev: IPTCEvent; ME: IPTCMouseEvent; NB: LongInt;
Begin
 GetMouseM:=False;
 If PTCWrapperObject=Nil Then Exit;
 If Not PTCWrapperObject.IsOpen Then Exit;
 While PTCWrapperObject.NextEvent(Ev,False,[PTCMouseEvent]) Do Begin
  ME:=Ev As IPTCMouseEvent;
  NB:=0;
  If PTCMouseButton1 In ME.ButtonState Then NB:=NB Or 1;
  If PTCMouseButton2 In ME.ButtonState Then NB:=NB Or 2;
  If PTCMouseButton3 In ME.ButtonState Then NB:=NB Or 4;
  X:=ME.X;Y:=ME.Y;
  GetMouseM:=True;
  If NB<>B Then Begin B:=NB;Exit;End;
 End;
End;

Function GetKeyM(Var K: Word): Boolean;
Begin
 If KMQH=KMQT Then KMPump;
 If KMQH=KMQT Then Begin GetKeyM:=False;Exit;End;
 K:=KMQK[KMQH];KeyMods:=KMQM[KMQH];
 KMQH:=(KMQH+1) Mod 64;
 GetKeyM:=True;
End;
{$ELSE}
Function ModsNow: Byte;
Var F: Byte; M: Byte;
Begin
 F:=Mem[$0040:$0017];
 M:=0;
 If (F And 3)<>0 Then M:=M Or KM_SHIFT;
 If (F And 4)<>0 Then M:=M Or KM_CTRL;
 If (F And 8)<>0 Then M:=M Or KM_ALT;
 ModsNow:=M;
End;

Function GetKeyM(Var K: Word): Boolean;
Var Ch: Char; F: Byte;
Begin
 GetKeyM:=False;
 If Not KeyPressed Then Exit;
 F:=Mem[$0040:$0017];
 KeyMods:=0;
 If (F And 3)<>0 Then KeyMods:=KeyMods Or KM_SHIFT;
 If (F And 4)<>0 Then KeyMods:=KeyMods Or KM_CTRL;
 If (F And 8)<>0 Then KeyMods:=KeyMods Or KM_ALT;
 Ch:=ReadKey;
 If Ch=#0 Then K:=256+Ord(ReadKey) Else K:=Ord(Ch);
 GetKeyM:=True;
End;
{$ENDIF}

Procedure IdleTick; Forward;

Procedure PollEvent(Var E: TEvent);
Var K: Word;
Begin
 E.Kind:=0;E.Key:=0;E.X:=MX;E.Y:=MY;E.B:=MB;
 If GetKeyM(K) Then Begin
  E.Kind:=1;E.Key:=K;
  Exit;
 End;
 PrevMX:=MX;PrevMY:=MY;LastB:=MB;
 {$IFDEF FPC}
 GetMouseM(MX,MY,MB);
 {$ELSE}
 GetMouseState(MX,MY,MB);
 {$ENDIF}
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
 MAXCOND    = 32767;
 MAXSRC     = 24;
 RELOCINIT  = 16000;       { capacite initiale des relocations (extensible) }
 DECCAP     = 1000000;     { decisions de taille de branche (octets) }
 MAXLOG     = 4000;
 CHUNKSZ    = 8192;
 NCHUNK     = 512;          { 4 Mo par section }

 SEC_TEXT   = 0;
 SEC_DATA   = 1;
 SEC_BSS    = 2;
 SEC_ABS    = -1;
 SEC_EXT    = -3;          { symbole importe (XREF) }
 RELIMP     = 1000;        { codes de relocation >= RELIMP : imports (voir p03)
   }

Type
 PString   = ^String;
 PLineArr  = ^TLineArr;
 TLineArr  = Array[1..MAXLN] Of PString;

 PSym = ^TSym;
 TSym = Record
  Name  : String[255];
  Value : LongInt;
  Sect  : Integer;       { -1 absolu, 0 texte, 1 data, 2 bss }
  Kind  : Byte;          { 0 etiquette/EQU, 1 SET, 2 liste de registres }
  Defd  : Boolean;
  Next  : PSym;
  Pas   : Integer;       { numero de passe de la definition }
 End;

 TMacro = Record
  Name  : String[63];
  Raw   : String[63];
  EndTxt: String[60];
  PNames: String[100];
  Body  : PLineArr;
  Count : Integer;
  Even  : Boolean;
 End;

 TSrc = Record
  Kind    : Integer;       { 0 fichier/tampon, 1 macro, 2 REPT }
  Lines   : PLineArr;
  Count   : LongInt;
  Pos     : LongInt;
  Name    : String[80];
  Own     : Boolean;       { les lignes appartiennent a la source }
  Args    : Array[0..35] Of String[200];
  NArg    : Integer;
  MacId   : LongInt;
  Reps    : LongInt;
  Suffix  : String[8];
  MacIdx  : Integer;
  CondBase: Integer;
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
  X : LongInt;           { index d'import (XREF) ou 0 }
  NS: Integer;           { GST : section soustraite (-1 aucune) }
 End;

 TAsmOpts = Record
  SymLen  : Integer;        { significance des symboles (8..127) }
  BrDef   : Integer;        { 0 BRW, 1 BRB/BRS, 3 BRL }
  OldBra  : Boolean;        { OPT OLD }
  LocalU,Mex,Symtab,List1,TraceIf,Inconce,NoType,ChkImm,ChkPC,EvenChk,AutoPC,
  AllowZero,User,Gensym,Line,Hcln,XDebug : Boolean;
  ChkBit  : Integer;        { 0 erreur, 1 inactif, 2 avertissement }
  BdW,OdL : Boolean;
  FPU,MMU : Boolean;        { coprocesseurs 68881/2 et 68851 }
  FpId    : Integer;        { identifiant de coprocesseur (FOPT ID=) }        {
    BDW / ODL }
  Opt     : Array[1..12] Of Boolean;
  OW      : Array[0..12] Of Boolean;   { 0 : avertissements d'optimisation en
    general }
  Proc    : LongInt;        { 68000, 68010, 68020, 68030, 68040, 68332 }
  Fmt     : Integer;        { 0 Atari, 1 GST, 2 DRI, 6 SREC, 7 Lattice }
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
 AO,AO0      : TAsmOpts;
 PassSerial  : Integer;
 Pass1Idx    : Integer;      { numero de l'iteration de la passe 1 }
 FwdRef      : Boolean;      { reference en avant rencontree dans l'expression }
 SkipPass2   : Boolean;      { erreurs de syntaxe en passe 1 : on s'arrete }
 ErrOvr      : String;       { texte d'erreur impose (ex. invalid IF
   expression) }
 ModNames    : Array[1..64] Of String[40];
 ModN        : Integer;
 AsmErrCnt   : Integer;      { vraies erreurs (AsmErrors = erreurs +
   avertissements listes) }
 AsmFatal    : Boolean;
 CmdOpts     : String;       { +OPTION / -V de la ligne de commande }
 CmdSyms     : String;       { -E sym=expr,... }
 CmdHeaders  : String;
 NoBinary    : Boolean;      { -B : pas de fichier binaire }
 OptCheckOnly: Boolean;
 OptListDev  : Integer;      { 0 aucun, 1 ecran, 2 imprimante, 3 disque }
 OptFormatSel: Integer;      { format de sortie choisi (-L, dialogue) }
 OptIncList  : String;
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
 LnStartSect : Integer;
 CondLn      : Array[1..MAXCOND] Of LongInt;
 MacUniq     : LongInt;
 LastGlobal  : String[255];

 { Sections }
 Chunks      : Array[0..1] Of TChunkTab;
 SecLen      : Array[0..2] Of LongInt;
 CurSect     : Integer;
 AbsMode     : Boolean;
 OffMode     : Boolean;       { section OFFSET en cours }
 OffPC       : LongInt;
 OrgAddr     : LongInt;
 SecBase     : Array[0..2] Of LongInt;   { adresse de l'image }
 PrevLen     : Array[0..2] Of LongInt;   { tailles trouvees a la passe 1 }
 RelocPos    : PLongArr;   { decalage dans la section source }
 RelocSrc    : PLongArr;
 RelocDst    : PLongArr;
 ImpN        : Integer;
 ImpNames    : Array[1..2000] Of String[80];
 XdefN       : Integer;
 XdefNames   : Array[1..2000] Of String[80];
 ModName     : String;
 ModIdx      : Integer;      { GST : numero du module courant (0 = premier) }
 GstSecName  : Array[0..2] Of String[40];
 GstSecCust  : Array[0..2] Of Boolean;
 GstGapN     : Integer;      { RORG GST : trous sans donnees }
 GstGapSec   : Array[1..200] Of Integer;
 GstGapPos,GstGapEnd : Array[1..200] Of LongInt;
 GstOrgN     : Integer;      { ORG multiples en mode absolu }
 GstOrgPos,GstOrgAddr : Array[1..200] Of LongInt;
 GstCmtN     : Integer;
 GstCmt      : Array[1..40] Of String[80];
 RelocN      : LongInt;
 RelocCap    : LongInt;
 Decs        : PByteArr;
 DecIdx      : LongInt;
 EntryPoint  : LongInt;
 EntrySect   : Integer;
 HaveOutput  : Boolean;

 { Evaluation d'expressions }
 ES          : String;
 EP          : Integer;
 ExprErrMsg  : String[80];
 UndefName   : String[255];
 ReqDef      : Boolean;        { exige que les symboles soient definis }

 { Contenu de la ligne en cours }
 LnLabel,LnOp,LnArgs,LnSuffix : String;
 LnText      : String;
 LnAddr      : LongInt;
 LnStartLen  : LongInt;
 ListF       : Text;
 ListOn      : Boolean;
 ListSuppress: Boolean;

Function ListWanted: Boolean;
Begin
 ListWanted:=(AsmPassNo=2) Or ((AsmPassNo=1) And (Pass1Idx=0) And AO.List1);
End;

Procedure LogLine(Const S: String);
Var P: PString;
Begin
 If AsmLogN<MAXLOG Then Begin
  Inc(AsmLogN);
  GetMem(P,Length(S)+1);
  Move(S[0],P^[0],Length(S)+1);
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
 Move(S[0],P^[0],Length(S)+1);
 NewStr:=P;
End;

Procedure FreeStr(P: PString);
Begin
 If P<>Nil Then FreeMem(P,Length(P^)+1);
End;

{ ---------------------------------------------------------------------- }
{ Erreurs                                                                 }
{ ---------------------------------------------------------------------- }

Var
 LastWarnLine : LongInt;
 LastWarnTxt  : String[80];

Var NoListMsg,ListOnlyPass,LnHadMsg: Boolean;

Procedure ListOut(Const Ln: String); Forward;
Function ListEnabled: Boolean; Forward;

Procedure AddMsg(IsWarn: Boolean; Const S: String);
Var I: Integer; T: String;
Begin
 If ListEnabled And (AsmPassNo=2) And Not NoListMsg Then Begin
  If IsWarn Then T:='Warning ' Else T:='Error ';
  ListOut(T+S+' at line '+IntStr(CurLineNo)+' in file '+CurSrcName);
  LnHadMsg:=True;
 End;
 If ListOnlyPass Then Exit;
 If AsmErrors<32000 Then Inc(AsmErrors);
 If IsWarn Then Begin If AsmWarns<32000 Then Inc(AsmWarns);End
 Else If AsmErrCnt<32000 Then Inc(AsmErrCnt);
 If (AsmErrors<=MAXERR) And (AsmErrors>=1) Then Begin
  ErrLn[AsmErrors]:=CurLineNo;
  If CurSrcName=AsmFileName Then ErrNm[AsmErrors]:='' Else
   ErrNm[AsmErrors]:=Copy(CurSrcName,1,60);
  ErrTx[AsmErrors]:=Copy(S,1,90);
 End;
 If IsWarn Then
   T:=T3('Warning in line ','Avertissement ligne ','Warnung Zeile ')
 Else T:=T3('Error in line ','Erreur ligne ','Fehler in Zeile ');
 If CurSrcName=AsmFileName Then
  LogLine(T+IntStr(CurLineNo)+': '+S)
 Else If IsWarn Then
  LogLine(T3('Warning in ','Avertissement dans ','Warnung in ')+CurSrcName+' ('+
    IntStr(CurLineNo)+'): '+S)
 Else
  LogLine(T3('Error in ','Erreur dans ','Fehler in ')+CurSrcName+' ('+
    IntStr(CurLineNo)+'): '+S);
 If LnText<>'' Then Begin
  T:=Copy(LnText,1,70);
  For I:=1 To Length(T) Do If T[I]=#9 Then T[I]:=' ';
  LogLine('    '+T);
 End;
End;

{ erreurs detectees des la passe 1 par le vrai GenST (syntaxe) : arret apres la
  passe 1 }
Function P1Msg(Const S: String): Boolean;
Begin
 P1Msg:=(S='instruction not recognised') Or (S='comma expected') Or
   (S='garbage following instruction') Or
  (S='expression mismatch') Or (S='addressing mode not recognised') Or
    (S='symbol defined twice') Or
  (S='spurious ENDC') Or (S='spurious ENDM or MEXIT') Or (S='spurious ENDR') Or
    (S='addressing mode not allowed') Or
  (S='missing quote') Or (S='DCB or DS count must not be negative') Or
    (S='symbol expected') Or (S='invalid option') Or
  (S='invalid section name, TEXT assumed') Or (S='missing close bracket') Or
    (S='invalid size') Or
  (S='invalid FORMAT parameter') Or (S='local not allowed') Or
    (S='misuse of label') Or
  (S='data register expected') Or (S='address register expected') Or
    (S='immediate data expected') Or
  (S='number too large') Or (S='invalid number') Or (S='odd address') Or
    (S='cannot nest repeat loops') Or (S='user error');
End;

Procedure Err3(Const En,Fr,De: String);
Begin
 If AsmPassNo=1 Then Begin
  If (Pass1Idx<>0) Or Not P1Msg(En) Then Exit;
  If (CurLineNo=LastErrLine) And (CurSrcName=AsmFileName) Then Exit;
  LastErrLine:=CurLineNo;
  If ErrOvr<>'' Then AddMsg(False,ErrOvr) Else AddMsg(False,T3(En,Fr,De));
  Exit;
 End;
 If AsmPassNo<>2 Then Exit;
 If ListOnlyPass And Not P1Msg(En) Then Exit;
 If (CurLineNo=LastErrLine) And (CurSrcName=AsmFileName) Then Exit;
 LastErrLine:=CurLineNo;
 If ErrOvr<>'' Then AddMsg(False,ErrOvr) Else AddMsg(False,T3(En,Fr,De));
End;

Procedure Err(Const S: String);
Begin
 Err3(S,S,S);
End;

{ Erreur fatale : arrete l'assemblage (code retour 20) }
Procedure FatalErr3(Const En,Fr,De: String);
Var Sv: Integer;
Begin
 Sv:=AsmPassNo;
 AsmPassNo:=2;
 LastErrLine:=0;
 NoListMsg:=True;
 Err3(En,Fr,De);
 NoListMsg:=False;
 AsmPassNo:=Sv;
 AsmFatal:=True;
End;

Procedure Warn3(Const En,Fr,De: String);
Var S: String;
Begin
 If Not OptWarnings Then Exit;
 If AsmPassNo<>2 Then Exit;
 If ListOnlyPass Then Exit;
 If AO.NoType And (En='relative cannot be relocated') Then Exit;
 S:=T3(En,Fr,De);
 If (CurLineNo=LastWarnLine) And (LastWarnTxt=Copy(S,1,80)) Then Exit;
 LastWarnLine:=CurLineNo;LastWarnTxt:=Copy(S,1,80);
 AddMsg(True,S);
End;

{ Avertissement d'optimisation n (1..12) }
Procedure WarnOpt(N: Integer; Const En: String);
Begin
 If AO.OW[0] And AO.OW[N] Then Warn3(En,En,En);
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
Var K: String;
Begin
 K:=S;
 If (Length(K)>AO.SymLen) And (Pos('~',K)=0) And (Pos('^',K)=0) Then
   K:=Copy(K,1,AO.SymLen);
 If OptCase Then KeyOf:=K Else KeyOf:=Upper(K);
End;

Var
 FeqName : Array[1..200] Of String[80];
 FeqVal  : Array[1..200] Of Extended;
 FeqN    : Integer;
 FPParse : Boolean;       { l'instruction courante est flottante }

Function FeqFind(Const N: String): Integer;
Var K: Integer; U: String;
Begin
 FeqFind:=0;U:=KeyOf(N);
 For K:=1 To FeqN Do If FeqName[K]=U Then FeqFind:=K;
End;

Procedure FeqSet(Const N: String; V: Extended);
Var K: Integer;
Begin
 K:=FeqFind(N);
 If K=0 Then Begin
  If FeqN>=200 Then Exit;
  Inc(FeqN);K:=FeqN;FeqName[K]:=Copy(KeyOf(N),1,80);
 End;
 FeqVal[K]:=V;
End;

Function LookupSym(Const K: String): PSym;
Var P: PSym;
Begin
 P:=Hash[HashOf(K)];
 While P<>Nil Do Begin
  If P^.Name=K Then Begin LookupSym:=P;Exit;End;
  P:=P^.Next;
 End;
 LookupSym:=Nil;
End;

{ cle d'un symbole relatif du module courant (GST : un espace de noms par
  MODULE) }
Function ModKey(Const Name: String): String;
Var K: String;
Begin
 K:=KeyOf(Name);
 If (ModIdx>0) And (Pos('^',K)=0) Then K:=K+'^'+IntStr(ModIdx);
 ModKey:=K;
End;

Function FindSym(Const Name: String): PSym;
Var P: PSym; K: String;
Begin
 K:=KeyOf(Name);
 If (ModIdx>0) And (Pos('^',K)=0) Then Begin
  P:=LookupSym(K+'^'+IntStr(ModIdx));
  If P<>Nil Then Begin FindSym:=P;Exit;End;
 End;
 FindSym:=LookupSym(K);
End;

Function AddSym(Const Name: String): PSym;
Var P: PSym; H: Integer; K: String;
Begin
 K:=KeyOf(Name);
 New(P);
 P^.Name:=K;
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
Function IsLocalName(Const N: String): Boolean;
Begin
 If N='' Then IsLocalName:=False
 Else If AO.LocalU Then IsLocalName:=(N[1]='_') Or (N[Length(N)]='$')
 Else IsLocalName:=(N[1]='.') Or (N[Length(N)]='$');
End;

Function LocalName(Const N: String): String;
Begin
 If IsLocalName(N) Then
  LocalName:=Copy(LastGlobal,1,AO.SymLen)+'~'+Copy(N,1,AO.SymLen)
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
 If OffMode Then CurPC:=OffPC Else
 If AbsMode Then CurPC:=OrgAddr+SecLen[0]
 Else CurPC:=SecLen[CurSect];
End;

Procedure EmitByte(B: Byte);
Var S: Integer;
Begin
 S:=CurSect;
 If AbsMode Then S:=0;
 If OffMode Or (S=SEC_BSS) Then Begin
  Err3('BSS or OFFSET section cannot contain dat'+'a',
    'Impossible de generer du code en BSS','Code im BSS nicht moeglich');
  Exit;
 End;
 If SecLen[S]>=LongInt(NCHUNK)*CHUNKSZ-1 Then Begin
  Err3('program buffer full','Programme trop grand','Programm zu gross');
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

Procedure GrowRelocs;
Var NC: LongInt; A,B,C: PLongArr;
Begin
 NC:=RelocCap*2;
 GetMem(A,NC*4+8);GetMem(B,NC*4+8);GetMem(C,NC*4+8);
 Move(RelocPos^,A^,(RelocN+1)*4);
 Move(RelocSrc^,B^,(RelocN+1)*4);
 Move(RelocDst^,C^,(RelocN+1)*4);
 FreeMem(RelocPos,RelocCap*4+8);FreeMem(RelocSrc,RelocCap*4+8);FreeMem(RelocDst,
   RelocCap*4+8);
 RelocPos:=A;RelocSrc:=B;RelocDst:=C;RelocCap:=NC;
End;

{ Mot long, avec relocation eventuelle (RSect >= 0) }
Procedure EmitLong(L: LongInt; RSect: LongInt);
Begin
 If (RSect>=0) And Not AbsMode And (AsmPassNo=2) And (CurSect<>SEC_BSS) Then
   Begin
  If RelocN>=RelocCap Then GrowRelocs;
  Inc(RelocN);
  RelocPos^[RelocN]:=SecLen[CurSect];
  RelocSrc^[RelocN]:=CurSect;
  RelocDst^[RelocN]:=RSect;
 End;
 EmitWord(ShrL(L,16));
 EmitWord(L And $FFFF);
End;

{ Mot (16 bits) avec relocation d'import (Rel >= RELIMP) }
Procedure EmitWordRel(W: LongInt; Rel: LongInt);
Begin
 If ((Rel>=RELIMP) Or (Rel<=-10)) And Not AbsMode And (AsmPassNo=2) And
   (CurSect<>SEC_BSS) And Not OffMode Then Begin
  If RelocN>=RelocCap Then GrowRelocs;
  Inc(RelocN);
  RelocPos^[RelocN]:=SecLen[CurSect];
  RelocSrc^[RelocN]:=CurSect;
  RelocDst^[RelocN]:=Rel;
 End;
 EmitWord(W);
End;

Procedure ReserveBytes(N: LongInt);
Begin
 If N<=0 Then Exit;
 If OffMode Then Begin Inc(OffPC,N);Exit;End;
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
 IsIdStart:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C='_') Or
   (C='.') Or (C='@');
End;

Function IsIdChar(C: Char): Boolean;
Begin
 IsIdChar:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C='_') Or
           (C='.') Or ((C>='0') And (C<='9')) Or (C='$') Or (C='@');
End;

Function IsHexCh(C: Char): Boolean;
Begin
 IsHexCh:=((C>='0') And (C<='9')) Or ((C>='A') And (C<='F')) Or ((C>='a') And
   (C<='f'));
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
 R.V:=V;R.S:=S;R.U:=U;R.X:=0;R.NS:=-1;
 MkTV:=R;
End;

Function ExprLevel(L: Integer): TTV; Forward;

Var
 NumRadix  : Integer;     { RADIX : 2, 4, 8, 10 ou 16 }
 CurRS     : LongInt;     { compteur RS (symbole reserve __RS) }

Function MacArgCount: LongInt;
Var K: Integer;
Begin
 MacArgCount:=0;
 K:=SrcTop;
 While (K>0) And (Srcs[K].Kind<>1) Do Dec(K);
 If K>0 Then MacArgCount:=Srcs[K].NArg;
End;

Function DigitOk(C: Char; Rdx: Integer): Boolean;
Begin
 DigitOk:=False;
 If Not IsHexCh(C) Then Exit;
 DigitOk:=HexVal(C)<Rdx;
End;

Function ReservedSym(Const U: String; Var V: LongInt): Boolean;
Begin
 ReservedSym:=True;
 If U='NARG' Then V:=MacArgCount
 Else If U='__RS' Then V:=CurRS
 Else If U='__LK' Then V:=AO.Fmt
 Else If U='__G2' Then V:=45+256*(AO.Proc Mod 100)
 Else ReservedSym:=False;
End;

Function ExprPrimary: TTV;
Var R: TTV; C: Char; V: LongInt; N: Integer; Name: String; P: PSym;
    Q: Char; Cnt: Integer; Closed: Boolean; RV: LongInt;
Begin
 R:=MkTV(0,SEC_ABS,False);
 SkipSp;
 If EP>Length(ES) Then Begin
  ExprError3('expression mismatch','Operande attendue','Operand erwartet');
  ExprPrimary:=R;Exit;
 End;
 C:=ES[EP];
 { chiffres suivis de $ : etiquette locale }
 N:=EP;
 If (C>='0') And (C<='9') Then Begin
  While (N<=Length(ES)) And (ES[N]>='0') And (ES[N]<='9') Do Inc(N);
  If (N<=Length(ES)) And (ES[N]='$') Then C:='_';
 End;
 If C='(' Then Begin
  Inc(EP);
  If (EP<=Length(ES)) And (ES[EP]=')') Then
    ExprError3('XREFs not allowed within brackets',
    'XREF interdit entre parentheses','XREF in Klammern nicht erlaubt');
  R:=ExprLevel(0);
  SkipSp;
  If (EP<=Length(ES)) And (ES[EP]=')') Then Inc(EP)
  Else
    ExprError3('missing close bracket','Parenthese ) manquante',
    'Klammer ) fehlt');
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
   ExprError3('invalid number','Nombre invalide','Ungueltige Zahl');
  End;
 End
 Else If C='%' Then Begin
  Inc(EP);V:=0;
  If (EP>Length(ES)) Or Not (ES[EP] In ['0','1']) Then
   ExprError3('invalid number','Nombre binaire incorrect','Falsche Binaerzahl');
  While (EP<=Length(ES)) And (ES[EP] In ['0','1']) Do Begin
   V:=(V Shl 1) Or (Ord(ES[EP])-48);Inc(EP);
  End;
  R.V:=V;
 End
 Else If (C='@') And (EP<Length(ES)) And (ES[EP+1] In ['0'..'7']) Then Begin
  Inc(EP);V:=0;
  While (EP<=Length(ES)) And (ES[EP] In ['0'..'7']) Do Begin
   V:=(V Shl 3) Or (Ord(ES[EP])-48);Inc(EP);
  End;
  R.V:=V;
 End
 Else If (C>='0') And (C<='9') Then Begin
  V:=0;
  If (C='0') And (EP<Length(ES)) And ((ES[EP+1]='x') Or (ES[EP+1]='X')) Then
    Begin
   Inc(EP,2);
   While (EP<=Length(ES)) And IsHexCh(ES[EP]) Do Begin
    V:=(V Shl 4) Or HexVal(ES[EP]);Inc(EP);
   End;
  End Else Begin
   While (EP<=Length(ES)) And DigitOk(ES[EP],NumRadix) Do Begin
    V:=V*NumRadix+HexVal(ES[EP]);Inc(EP);
   End;
   If (EP<=Length(ES)) And (ES[EP]>='0') And (ES[EP]<='9') Then
    ExprError3('number too large','Nombre trop grand','Zahl zu gross');
  End;
  R.V:=V;
 End
 Else If (C='''') Or (C='"') Then Begin
  Q:=C;Inc(EP);V:=0;Cnt:=0;Closed:=False;
  While EP<=Length(ES) Do Begin
   If ES[EP]=Q Then Begin
    If (EP<Length(ES)) And (ES[EP+1]=Q) Then Begin
     V:=(V Shl 8) Or Ord(Q);Inc(Cnt);Inc(EP,2);
    End Else Begin Inc(EP);Closed:=True;Break;End;
   End Else Begin
    V:=(V Shl 8) Or Ord(ES[EP]);Inc(Cnt);Inc(EP);
   End;
  End;
  If Not Closed Then
    ExprError3('missing quote','Apostrophe manquante',
    'Anfuehrungszeichen fehlt');
  If Cnt>4 Then
    ExprError3('number too large','Nombre trop grand','Zahl zu gross');
  R.V:=V;
 End
 Else If C='*' Then Begin
  Inc(EP);
  R.V:=CurPC;
  If Not AbsMode And Not OffMode Then R.S:=CurSect;
 End
 Else If IsIdStart(C) Or (C='_') Then Begin
  N:=EP;
  While (EP<=Length(ES)) And IsIdChar(ES[EP]) Do Inc(EP);
  Name:=Copy(ES,N,EP-N);
  If ReservedSym(Upper(Name),RV) Then R.V:=RV
  Else Begin
   Name:=LocalName(Name);
   P:=FindSym(Name);
   If (P=Nil) Or Not P^.Defd Or (P^.Pas<>PassSerial) Then FwdRef:=True;
   If (P<>Nil) And P^.Defd And (P^.Kind=3) Then Begin
    R.V:=0;R.S:=P^.Sect;R.X:=P^.Value;
   End Else If (P<>Nil) And P^.Defd And (P^.Kind=2) Then Begin
    Warn3('misuse of register list','Mauvaise utilisation de liste de registr'+
      'es','Falsche Verwendung der Registerliste');
    R.V:=P^.Value;R.S:=SEC_ABS;
   End Else If (P<>Nil) And P^.Defd Then Begin
    R.V:=P^.Value;R.S:=P^.Sect;
   End Else Begin
    R.U:=True;
    R.V:=0;
    If UndefName='' Then UndefName:=Copy(Name,1,255);
   End;
  End;
 End
 Else Begin
  ExprError3('expression mismatch','Expression incorrecte','Falscher Ausdruck');
  Inc(EP);
 End;
 ExprPrimary:=R;
End;

Procedure TypeErr;
Begin
 If Not AO.NoType Then
  ExprError3('illegal type combination','Combinaison de types illegale',
    'Illegale Typkombination');
End;

Function ExprUnary: TTV;
Var R: TTV;
Begin
 SkipSp;
 If EP<=Length(ES) Then Begin
  If ES[EP]='-' Then Begin
   Inc(EP);
   If (EP<=Length(ES)) And (ES[EP] In ['-','+','~']) Then
     ExprError3('expression mismatch','Expression incorrecte',
     'Falscher Ausdruck');
   R:=ExprUnary();
   R.V:=-R.V;
   If R.X>0 Then Begin
     R.X:=0;ExprError3('illegal type combination',
     'Combinaison de types illegale','Illegale Typkombination');End;
   If R.S>=0 Then Begin R.S:=SEC_ABS;TypeErr;End;
   ExprUnary:=R;Exit;
  End;
  If ES[EP]='+' Then Begin
   Inc(EP);
   If (EP<=Length(ES)) And (ES[EP] In ['-','+','~']) Then
     ExprError3('expression mismatch','Expression incorrecte',
     'Falscher Ausdruck');
   ExprUnary:=ExprUnary();Exit;
  End;
  If ES[EP]='~' Then Begin
   Inc(EP);
   If (EP<=Length(ES)) And (ES[EP]='~') Then
     ExprError3('expression mismatch','Expression incorrecte',
     'Falscher Ausdruck');
   R:=ExprUnary();
   R.V:=Not R.V;
   If R.S>=0 Then Begin R.S:=SEC_ABS;TypeErr;End;
   ExprUnary:=R;Exit;
  End;
 End;
 ExprUnary:=ExprPrimary;
End;

Function SignedLt(A,B: LongInt): Boolean;
Begin
 SignedLt:=A<B;
End;

{ Niveaux (priorite croissante, manuel p.70) : 0 comparaisons, 1 + -, 2 * / %,
  3 & | ^ (meme niveau), 4 << >>, puis unaire }
Function ExprLevel(L: Integer): TTV;
Var A,B: TTV; Op: Integer; C,D: Char; Done: Boolean;
Begin
 If L>4 Then Begin ExprLevel:=ExprUnary;Exit;End;
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
    1: If C='+' Then Begin Op:=1;Inc(EP);End
       Else If C='-' Then Begin Op:=2;Inc(EP);End;
    2: If C='*' Then Begin Op:=1;Inc(EP);End
       Else If C='/' Then Begin Op:=2;Inc(EP);End
       Else If (C='%') Then
         ExprError3('invalid number','Nombre invalide','Ungueltige Zahl');
    3: If C='&' Then Begin Op:=1;Inc(EP);End
       Else If (C='|') Or ((C='!') And (D<>'=')) Then Begin Op:=2;Inc(EP);End
       Else If C='^' Then Begin Op:=3;Inc(EP);End;
    4: If (C='<') And (D='<') Then Begin Op:=1;Inc(EP,2);End
       Else If (C='>') And (D='>') Then Begin Op:=2;Inc(EP,2);End;
   End;
   If Op<>0 Then Begin
    Done:=False;
    B:=ExprLevel(L+1);
    A.U:=A.U Or B.U;
    If (A.X>0) Or (B.X>0) Then Begin
     If (L=1) And (Not ((A.X>0) And (B.X>0))) And (Not ((Op=2) And (B.X>0)))
       Then Begin
      If B.X>0 Then Begin A.X:=B.X;A.S:=B.S;End;
     End Else
       ExprError3('illegal type combination','Combinaison de types illegale',
       'Illegale Typkombination');
    End;
    Case L Of
     0: Begin
         If (A.S>=0)<>(B.S>=0) Then TypeErr;
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
     3: Begin
         If (A.S>=0) Or (B.S>=0) Then TypeErr;
         Case Op Of
          1: A.V:=A.V And B.V;
          2: A.V:=A.V Or B.V;
          3: A.V:=A.V Xor B.V;
         End;
         A.S:=SEC_ABS;
        End;
     4: Begin
         If (A.S>=0) Or (B.S>=0) Then TypeErr;
         If (B.V And 63)>=32 Then A.V:=0
         Else If Op=1 Then A.V:=A.V Shl (B.V And 63)
         Else A.V:=ShrL(A.V,B.V And 63);
         A.S:=SEC_ABS;
        End;
     1: Begin
         If Op=1 Then Begin
          If (A.S>=0) And (B.S>=0) Then TypeErr
          Else If B.S>=0 Then A.S:=B.S;
          A.V:=A.V+B.V;
         End Else If (AO.Fmt=1) And (A.NS<0) And (B.NS<0) And (B.X=0) And
           (B.S>=0) And
                     ((A.X>0) Or ((A.S>=0) And (A.S<>B.S))) Then Begin
          { GST : (import ou relatif) - relatif d'une autre section :
            relogement a deux termes }
          A.V:=A.V-B.V;A.NS:=B.S;
         End Else Begin
          If (A.S>=0) And (B.S>=0) Then Begin
           If A.S<>B.S Then Begin
            If (AO.Fmt=0) And Not AbsMode Then Begin
             { le vrai GenST : difference d'adresses finales de deux sections }
             A.V:=ImgOf(A.V,A.S);B.V:=ImgOf(B.V,B.S);
            End Else If Not (A.U Or B.U) Then TypeErr;
           End;
           A.S:=SEC_ABS;
          End Else If (A.S<0) And (B.S>=0) Then TypeErr;
          A.V:=A.V-B.V;
         End;
        End;
     2: Begin
         If (A.S>=0) Or (B.S>=0) Then TypeErr;
         A.S:=SEC_ABS;
         Case Op Of
          1: A.V:=A.V*B.V;
          2: If B.V=0 Then Begin
              If Not A.U Then
                ExprError3('division by zero','Division par zero',
                'Division durch Null');
              A.V:=0;
             End Else If (B.V=-1) Then A.V:=-A.V Else A.V:=A.V Div B.V;
          3: If B.V=0 Then Begin
              If Not A.U Then
                ExprError3('division by zero','Division par zero',
                'Division durch Null');
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
  Err3('undefined symbol','Symbole non defini : '+UndefName,
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
  If IsIdChar(ES[EP]) Then
    Err3('garbage following instruction','Trop d''operandes',
    'Zu viele Operanden')
  Else Err3('expression mismatch','Expression incorrecte','Falscher Ausdruck');
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
 OK_SR=13; OK_CCR=14; OK_USP=15; OK_LIST=16; OK_PAIR=17; OK_FULL=18;
   OK_FPREG=19; OK_FPCR=20; OK_FPLIST=21; OK_FPPAIR=22;

 MA_ALL  = $1FFE;
 MA_DATA = $1FFA;
 MA_ALT  = $03FE;
 MA_DALT = $03FA;
 MA_MALT = $03F8;
 MA_CTRL = $0FC8;
 MA_CALT = $03C8;

 CondNames : Array[0..17] Of String[2] =
  ('T','F','HI','LS','CC','CS','NE','EQ','VC','VS','PL','MI','GE','LT','GT',
    'LE','HS','LO');

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
  Scale: Integer;       { echelle de l'index (1,2,4,8) }
  X    : LongInt;       { index d'import (XREF) ou 0 }
  NS   : Integer;       { GST : section soustraite }
  FB,FIx,FSc,FMem,FBdSz,FOdSz,FBdS,FOdS : Integer;   { mode 68020 complet }
  FSup,FIxL,FHasBd,FHasOd,FBdU,FOdU : Boolean;
  FBdV,FOdV : LongInt;
  BF   : LongInt;       (* champ de bits off:width : bits 11..0 du mot d
    extension *)
  HasBF: Boolean;
  FTxt : String[80];     { texte d'une constante immediate flottante }
  FIsFloat,HasK,KDyn : Boolean;
  KV   : Integer;        { facteur k (FMOVE.P) }
 End;

Var
 Ops    : Array[1..4] Of TOp;
 OpStr  : Array[1..4] Of String[120];
 NOps   : Integer;
 LnSz   : Integer;       { 0 aucune, 1 B, 2 W, 4 L, 8 S }
 InstrOff : LongInt;     { decalage de l'instruction dans la section }
 InstrPC  : LongInt;     { adresse de l'instruction (image) }
 OpW      : LongInt;     { mot d'operation }
 XW       : Array[1..16] Of LongInt;
 XLg      : Array[1..16] Of Boolean;
 XRl      : Array[1..16] Of LongInt;
 XN       : Integer;
 XWords   : Integer;
 BadInstr : Boolean;
 EvenSkip : Boolean;     { l'instruction n'accede pas a la memoire (LEA,
   PEA...) }
 ExplSize : Boolean;

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
Var
 EqurName : Array[1..64] Of String[40];
 EqurReg  : Array[1..64] Of Integer;
 EqurN    : Integer;

Function RegOf(Const U: String): Integer;
Var K: Integer;
Begin
 RegOf:=-1;
 If EqurN>0 Then
  For K:=1 To EqurN Do
   If EqurName[K]=U Then Begin RegOf:=EqurReg[K];Exit;End;
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
Function SplitTop(Const S: String; Var Parts: Array Of String; MaxN: Integer):
  Integer;
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

Var RegListRev: Boolean;

Function ParseRegList(Const U: String; Var Mask: LongInt): Boolean;
Var I,A,B,R1,R2,K: Integer; Tok: String; C: Char;
Begin
 ParseRegList:=False;
 Mask:=0;RegListRev:=False;
 If (Pos('-',U)=0) And (Pos('/',U)=0) Then Exit;
 I:=1;
 While I<=Length(U) Do Begin
  Tok:='';
  While (I<=Length(U)) And (U[I]<>'/') And (U[I]<>'-') Do Begin
    Tok:=Tok+U[I];Inc(I);End;
  R1:=RegOf(Tok);
  If (R1<0) Or (R1>15) Then Exit;
  R2:=R1;
  If (I<=Length(U)) And (U[I]='-') Then Begin
   Inc(I);Tok:='';
   While (I<=Length(U)) And (U[I]<>'/') Do Begin Tok:=Tok+U[I];Inc(I);End;
   R2:=RegOf(Tok);
   If (R2<0) Or (R2>15) Then Exit;
  End;
  If R2<R1 Then Begin K:=R1;R1:=R2;R2:=K;RegListRev:=True;End;
  For K:=R1 To R2 Do Mask:=Mask Or (LongInt(1) Shl K);
  If (I<=Length(U)) And (U[I]='/') Then Inc(I);
 End;
 C:=#0;
 A:=0;B:=0;
 If (A=B) And (C=#0) Then ParseRegList:=True;
End;

{ Analyse un registre d'index : "D3.W", "A2.L", "D1", "D1.W*4" }
Function ParseIndexReg(Const S0: String; Var R: Integer; Var L: Boolean; Var
  Sc: Integer): Boolean;
Var S: String; P: Integer; T: String;
Begin
 ParseIndexReg:=False;
 S:=Upper(TrimS(S0));
 L:=False;Sc:=1;
 P:=Pos('*',S);
 If P>0 Then Begin
  T:=TrimS(Copy(S,P+1,10));
  S:=TrimS(Copy(S,1,P-1));
  If T='1' Then Sc:=1 Else If T='2' Then Sc:=2 Else If T='4' Then Sc:=4 Else If
    T='8' Then Sc:=8
  Else Begin
    Err3('invalid index scale','Echelle d''index invalide',
    'Ungueltiger Indexfaktor');Exit;End;
  If (Sc<>1) And (AO.Proc<68020) Then Begin
   Err3('missing close bracket','Mode d''adressage 68020 invalide',
     'Ungueltiger 68020-Adressmodus');Exit;
  End;
 End;
 P:=Pos('.',S);
 If P>0 Then Begin
  If Copy(S,P+1,1)='L' Then L:=True
  Else If Copy(S,P+1,1)<>'W' Then Begin
   Err3('-W or .L expected as index size','-W oder .L erwartet',
     '-W or .L expected as index size');Exit;
  End;
  S:=Copy(S,1,P-1);
 End;
 R:=RegOf(S);
 If (R<0) Or (R>15) Then Exit;
 ParseIndexReg:=True;
End;

Var LastX : LongInt;
 LastNS : Integer;

Function EvalOpnd(Const S: String; Var V: LongInt; Var Sc: Integer; Var U:
  Boolean): Boolean;
Var R: TTV;
Begin
 If S='' Then Begin V:=0;Sc:=SEC_ABS;U:=False;EvalOpnd:=True;Exit;End;
 If EvalStr(S,R) Then Begin
  V:=R.V;Sc:=R.S;U:=R.U;LastX:=R.X;LastNS:=R.NS;
  EvalOpnd:=True;
 End Else Begin
  V:=0;Sc:=SEC_ABS;U:=True;
  EvalOpnd:=False;
 End;
End;

Function LooksFloat(Const T0: String): Boolean;
Var T: String; I: Integer;
Begin
 T:=TrimS(T0);LooksFloat:=False;
 If T='' Then Exit;
 If T[1]=':' Then Begin LooksFloat:=True;Exit;End;
 If (T[1]='-') Or (T[1]='+') Then Delete(T,1,1);
 If T='' Then Exit;
 If FeqFind(T)>0 Then Begin LooksFloat:=True;Exit;End;
 If (T[1]='$') Or (T[1]='%') Or (T[1]='@') Or (T[1]='(') Then Exit;
 If Not (T[1] In ['0'..'9','.']) Then Exit;
 For I:=1 To Length(T) Do
  If (T[I]='.') Or (((T[I]='E') Or (T[I]='e')) And (I>1)) Then Begin
    LooksFloat:=True;Exit;End;
End;

Function FpRegOf(Const U: String): Integer;
Begin
 FpRegOf:=-1;
 If (Length(U)=3) And (U[1]='F') And (U[2]='P') And (U[3]>='0') And (U[3]<='7')
   Then FpRegOf:=Ord(U[3])-48;
End;

{ liste de registres de controle FPCR/FPSR/FPIAR : masque 4/2/1 ou 0 }
Function FpCtlMask(Const U: String): Integer;
Var I: Integer; Tk: String; M: Integer;
Begin
 FpCtlMask:=0;M:=0;Tk:='';
 For I:=1 To Length(U)+1 Do Begin
  If (I>Length(U)) Or (U[I]='/') Then Begin
   If Tk='FPCR' Then M:=M Or 4 Else If Tk='FPSR' Then M:=M Or 2 Else If
     Tk='FPIAR' Then M:=M Or 1 Else Exit;
   Tk:='';
  End Else Tk:=Tk+U[I];
 End;
 FpCtlMask:=M;
End;

{ liste FPn-FPm/FPk : masque FP0=bit 0, ou -1 }
Function FpListMask(Const U: String): Integer;
Var I,A,B,K,M: Integer; Tk: String; Rng: Boolean;
Begin
 FpListMask:=-1;M:=0;
 If (Pos('/',U)=0) And (Pos('-',U)=0) Then Exit;
 I:=1;
 While I<=Length(U) Do Begin
  Tk:='';
  While (I<=Length(U)) And (U[I]<>'/') And (U[I]<>'-') Do Begin
    Tk:=Tk+U[I];Inc(I);End;
  A:=FpRegOf(Tk);If A<0 Then Exit;
  B:=A;
  If (I<=Length(U)) And (U[I]='-') Then Begin
   Inc(I);Tk:='';
   While (I<=Length(U)) And (U[I]<>'/') Do Begin Tk:=Tk+U[I];Inc(I);End;
   B:=FpRegOf(Tk);If B<0 Then Exit;
  End;
  If B<A Then Begin K:=A;A:=B;B:=K;End;
  For K:=A To B Do M:=M Or (1 Shl K);
  If (I<=Length(U)) And (U[I]='/') Then Inc(I);
 End;
 FpListMask:=M;
End;

Procedure ParseFull(Const Inn: String; Var O: TOp); Forward;

{ le contenu des parentheses demande-t-il le format complet 68020 ? }
Function NeedFull(Const Inn: String): Boolean;
Var Parts: Array[0..7] Of String; N,I,L: Integer; U: String;
Begin
 NeedFull:=False;
 If Pos('[',Inn)>0 Then Begin NeedFull:=True;Exit;End;
 N:=SplitTop(Inn,Parts,8);
 For I:=0 To N-1 Do Begin
  U:=Upper(TrimS(Parts[I]));L:=Length(U);
  If (U='ZPC') Or (U='ZSP') Or ((L=3) And (U[1]='Z') And (U[2]='A')) Then Begin
    NeedFull:=True;Exit;End;
  If (L>2) And (U[L-1]='.') And ((U[L]='W') Or (U[L]='L')) And (Pos('*',U)=0)
    And (RegOf(Copy(U,1,L-2))<0) Then Begin
   NeedFull:=True;Exit;
  End;
 End;
End;

Procedure ChkPcAbs(Var O: TOp);
Begin
 If (AsmPassNo=2) And Not AbsMode And Not O.U And (O.S<0) And (O.X=0) Then
  Err3('absolute not allowed','Absolu interdit','Absolut nicht erlaubt');
End;

Procedure ParseOp0(Const S0: String; Var O: TOp);
Var S,U,Pre,Inn,Suf: String; R,P,D,I,L,N: Integer; Items: Array[0..3] Of String;
    Post,IsReg: Boolean; Sy: PSym; M: LongInt; XL: Boolean; Ok: Boolean;
Begin
 FillChar(O,SizeOf(O),0);
 O.S:=SEC_ABS;O.Scale:=1;
 S:=TrimS(S0);
 If S='' Then Begin
  Err3('expression mismatch','Operande attendue','Operand erwartet');
  BadInstr:=True;Exit;
 End;
 U:=Upper(S);
 If S[1]='#' Then Begin
  O.K:=OK_IMM;
  O.FTxt:=Copy(S,2,80);
  If FPParse And LooksFloat(O.FTxt) Then Begin
    O.FIsFloat:=True;O.V:=0;O.S:=SEC_ABS;Exit;End;
  EvalOpnd(Copy(S,2,255),O.V,O.S,O.U);
  Exit;
 End;
 { registres et listes flottants }
 If FpRegOf(U)>=0 Then Begin O.K:=OK_FPREG;O.R:=FpRegOf(U);Exit;End;
 P:=FpCtlMask(U);
 If P<>0 Then Begin O.K:=OK_FPCR;O.Mask:=P;Exit;End;
 P:=FpListMask(U);
 If P>=0 Then Begin O.K:=OK_FPLIST;O.Mask:=P;Exit;End;
 P:=Pos(':',U);
 If (P>1) And (FpRegOf(Copy(U,1,P-1))>=0) And (FpRegOf(Copy(U,P+1,10))>=0) Then
   Begin
  O.K:=OK_FPPAIR;O.R:=FpRegOf(Copy(U,1,P-1));O.XR:=FpRegOf(Copy(U,P+1,10));Exit;
 End;
 R:=RegOf(U);
 If R>=0 Then Begin
  If R<8 Then Begin O.K:=OK_DN;O.R:=R;End
  Else If R<16 Then Begin O.K:=OK_AN;O.R:=R-8;End
  Else If R=20 Then O.K:=OK_SR
  Else If R=21 Then O.K:=OK_CCR
  Else If R=22 Then O.K:=OK_USP
  Else Begin
    Err3('addressing mode not recognised','Mode d''adressage non reconnu',
    'Adressmodus nicht erkannt');BadInstr:=True;End;
  Exit;
 End;
 P:=Pos(':',U);
 If P>1 Then Begin
  R:=RegOf(TrimS(Copy(U,1,P-1)));
  D:=RegOf(TrimS(Copy(U,P+1,20)));
  If (R>=0) And (R<8) And (D>=0) And (D<8) Then Begin
   O.K:=OK_PAIR;O.R:=R;O.XR:=D;Exit;
  End;
 End;
 If ParseRegList(U,M) Then Begin
  O.K:=OK_LIST;O.Mask:=M;
  If RegListRev Then Begin
    Err3('invalid register list','Liste de registres incorrecte',
    'Falsche Registerliste');BadInstr:=True;End;
  Exit;
 End;
 { symbole de liste de registres (REG) }
 If IsIdStart(S[1]) Then Begin
  Sy:=FindSym(LocalName(S));
  If (Sy<>Nil) And (Sy^.Kind=2) Then Begin
    O.K:=OK_LIST;O.Mask:=Sy^.Value;Exit;End;
 End;
 L:=Length(S);
 { predecrementation / postincrementation / indirections }
 Post:=False;
 If (L>=3) And (S[L]='+') And (S[L-1]=')') Then Begin
   Post:=True;Suf:=Copy(S,1,L-1);End
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
   If (Pre='') And Not Post And NeedFull(Inn) Then Begin
     ParseFull(Inn,O);Exit;End;
   N:=SplitTop(Inn,Items,4);
   IsReg:=False;
   If N>=1 Then Begin
    R:=RegOf(Upper(Items[0]));
    If (R>=8) And (R<=15) Then IsReg:=True;
    If R=23 Then IsReg:=True;
    If (N>=2) And (RegOf(Upper(Items[1]))>=8) And (RegOf(Upper(Items[1]))<=15)
      Then IsReg:=True;
    If (N>=2) And (RegOf(Upper(Items[1]))=23) Then IsReg:=True;
   End;
   If IsReg Then Begin
    Ok:=True;
    If N=1 Then Begin
     R:=RegOf(Upper(Items[0]));
     If R=23 Then Begin
      O.K:=OK_PCD;
      EvalOpnd(Pre,O.V,O.S,O.U);
      ChkPcAbs(O);
     End Else Begin
      O.R:=R-8;
      If Post And (Pre='-') Then Begin
        Err3('garbage following instruction','Trop d''operandes',
        'Zu viele Operanden');BadInstr:=True;Exit;End;
      If Post And (Pre<>'') Then Begin
        Err3('comma expected','Virgule attendue',
        'Komma erwartet');BadInstr:=True;Exit;End;
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
      If Not ParseIndexReg(Items[1],O.XR,O.XL,O.Scale) Then Ok:=False;
      EvalOpnd(Pre,O.V,O.S,O.U);
      If R=23 Then ChkPcAbs(O);
     End Else Begin
      { (d,An) ou (d,An,Xn) }
      EvalOpnd(Items[0],O.V,O.S,O.U);
      R:=RegOf(Upper(Items[1]));
      If R=23 Then O.K:=OK_PCD Else If (R>=8) And (R<=15) Then Begin
       O.K:=OK_DISP;O.R:=R-8;
      End Else Ok:=False;
      If (N>=3) And Ok Then Begin
       If R=23 Then O.K:=OK_PCI Else O.K:=OK_IDX;
       If Not ParseIndexReg(Items[2],O.XR,O.XL,O.Scale) Then Ok:=False;
      End;
     End;
    End;
    If Not Ok Then Begin
     Err3('addressing mode not recognised','Mode d''adressage non reconnu',
       'Adressmodus nicht erkannt');
     BadInstr:=True;
    End;
    Exit;
   End;
  End;
 End;
 { parentheses non equilibrees : mode non reconnu }
 If S[1]='(' Then Begin
  D:=0;
  For I:=1 To Length(S) Do Begin If S[I]='(' Then Inc(D) Else If S[I]=')' Then
    Dec(D);End;
  If D>0 Then Begin
   If S='(' Then
     Err3('XREFs not allowed within brackets','XREF interdit entre parentheses',
     'XREF in Klammern nicht erlaubt')
   Else If (Pos(',',S)=0) Or (S[Length(S)]=',') Then
     Err3('addressing mode not recognised','Mode d''adressage non reconnu',
     'Adressmodus nicht erkannt')
   Else
     Err3('missing close bracket','Parenthese fermante manquante',
     'Schliessende Klammer fehlt');
   BadInstr:=True;Exit;
  End;
  If D<0 Then Begin
    Err3('addressing mode not recognised','Mode d''adressage non reconnu',
    'Adressmodus nicht erkannt');BadInstr:=True;Exit;End;
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

 Procedure ParseOp(Const S0: String; Var O: TOp);
Var P,Q,Off,Wd: LongInt; B,F,A1,A2: String; Sc: Integer; U: Boolean; Dof,Dwf:
  Boolean; R1: Integer;
Begin
 LastX:=0;LastNS:=-1;
 P:=Pos('{',S0);
 B:=S0;F:='';
 If (P>1) And (S0[Length(S0)]='}') Then Begin
   B:=Copy(S0,1,P-1);F:=Copy(S0,P+1,Length(S0)-P-1);End;
 ParseOp0(B,O);
 O.X:=LastX;O.NS:=LastNS;
 O.HasBF:=False;O.BF:=0;O.HasK:=False;
 If F<>'' Then Begin
  Q:=Pos(':',F);
  If Q=0 Then Begin
   (* facteur k *)
   O.HasK:=True;
   If (F<>'') And (F[1]='#') Then Begin
     EvalOpnd(Copy(F,2,40),Off,Sc,U);O.KV:=Off;O.KDyn:=False;End
   Else Begin R1:=RegOf(Upper(TrimS(F)));If (R1<0) Or (R1>7) Then Begin
     Err3('invalid k-factor','Facteur k invalide',
     'Ungueltiger k-Faktor');BadInstr:=True;Exit;End;O.KV:=R1;O.KDyn:=True;End;
   Exit;
  End;
  A1:=TrimS(Copy(F,1,Q-1));A2:=TrimS(Copy(F,Q+1,40));
  R1:=RegOf(Upper(A1));
  If (R1>=0) And (R1<8) Then Begin Dof:=True;Off:=R1;End
  Else Begin Dof:=False;EvalOpnd(A1,Off,Sc,U);If (Off<0) Or (Off>31) Then Begin
    Err3('invalid bitfield specification','Champ de bits invalide',
    'Ungueltiges Bitfeld');BadInstr:=True;End;End;
  R1:=RegOf(Upper(A2));
  If (R1>=0) And (R1<8) Then Begin Dwf:=True;Wd:=R1;End
  Else Begin
   Dwf:=False;EvalOpnd(A2,Wd,Sc,U);
   If (Wd<0) Or (Wd>32) Or ((Wd=0) And Not AO.AllowZero) Then Begin
     Err3('invalid bitfield specification','Champ de bits invalide',
     'Ungueltiges Bitfeld');BadInstr:=True;End;
   If Wd=32 Then Wd:=0;
  End;
  O.BF:=(Ord(Dof) Shl 11) Or ((Off And 31) Shl 6) Or (Ord(Dwf) Shl 5) Or (Wd
    And 31);
  If Dof Then O.BF:=(O.BF And Not $7C0) Or ((Off And 7) Shl 6);
  If Dwf Then O.BF:=(O.BF And Not $1F) Or (Wd And 7);
  O.HasBF:=True;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Mots d'extension                                                        }
{ ---------------------------------------------------------------------- }

Procedure PutX(V: LongInt; IsLong: Boolean; Rel: LongInt);
Begin
 If XN<16 Then Begin
  Inc(XN);
  XW[XN]:=V;XLg[XN]:=IsLong;XRl[XN]:=Rel;
  If IsLong Then Inc(XWords,2) Else Inc(XWords);
 End;
End;

Procedure CheckRange(V: LongInt; U: Boolean; Lo,Hi: LongInt);
Begin
 If U Then Exit;
 If (V<Lo) Or (V>Hi) Then
  Err3('data too large','Valeur hors limites','Wert ausserhalb des Bereichs');
End;

{ Valeur immediate selon la taille }
{ code de relocation : import (kind 0 long, 1 mot absolu, 2 mot relatif PC) ou
  Def }
Function ImpRel(Var O: TOp; Kind,Def: LongInt): LongInt;
Var R: LongInt;
Begin
 If O.X>0 Then R:=RELIMP+O.X*4+Kind Else R:=Def;
 If (O.NS>=0) And (R>=0) Then R:=R+LongInt(O.NS+1)*100000;
 ImpRel:=R;
End;

Procedure PutImm(Var O: TOp; Sz: Integer);
Begin
 Case Sz Of
  1: Begin
      If O.X>0 Then
        Err3('relocation not allowed','Relocation interdite',
        'Relokation nicht erlaubt');
      CheckRange(O.V,O.U,-256,255);
      If O.S>=0 Then
        Warn3('relative cannot be relocated','Relatif non relogeable',
        'Relativ nicht relozierbar');
      PutX(O.V And $FF,False,-1);
     End;
  2: Begin
      CheckRange(O.V,O.U,-65536,65535);
      If (O.S>=0) Or (O.X>0) Then
        Warn3('relative cannot be relocated','Relatif non relogeable',
        'Relativ nicht relozierbar');
      PutX(O.V And $FFFF,False,ImpRel(O,1,-1));
     End;
 Else Begin
  If AO.ChkPC And (O.S>=0) Then
    Err3('relocation not allowed','Relocation interdite',
    'Relokation nicht erlaubt');
  PutX(ImgOf(O.V,O.S),True,ImpRel(O,0,O.S));
 End;
 End;
End;

{ Encode un mode d'adressage ; retourne mode*8+registre ou -1 }
{ ---------------------------------------------------------------------- }
{ Optimisations O2..O12 : decisions prises a la passe 1 (Decs), stables       }
{ ---------------------------------------------------------------------- }

Var
 OptCount,OptSaved : LongInt;

Function OptDecide(Cond: Boolean): Boolean;
Begin
 Inc(DecIdx);
 If DecIdx>=DECCAP Then DecIdx:=DECCAP-1;
 If (AsmPassNo=1) And (Pass1Idx=0) Then Decs^[DecIdx]:=Ord(Cond);
 OptDecide:=Decs^[DecIdx]=1;
End;

Procedure OptStat(Saved: Integer);
Begin
 If AsmPassNo=2 Then Begin Inc(OptCount);Inc(OptSaved,Saved);End;
End;

{ valeur absolue connue dans [Lo,Hi] ? }
Function KnownAbs(Var O: TOp; Lo,Hi: LongInt): Boolean;
Begin
 KnownAbs:=(Not O.U) And (O.S<0) And (O.X=0) And (O.V>=Lo) And (O.V<=Hi);
End;

Function ScaleBits(Sc: Integer): LongInt;
Begin
 Case Sc Of
  2: ScaleBits:=$200;
  4: ScaleBits:=$400;
  8: ScaleBits:=$600;
 Else ScaleBits:=0;
 End;
End;

{ controle d'adresse impaire pour un absolu connu (OPT EVEN) }
Procedure CheckOddAbs(Var O: TOp; Sz: Integer);
Var V: LongInt;
Begin
 { seuls les symboles relatifs (etiquettes) sont controles : un absolu impair
   (EQU) est legal a l'assemblage }
 If Not AO.EvenChk Or EvenSkip Or O.U Or (Sz<2) Then Exit;
 If (AsmPassNo<>2) And (O.S>=0) Then Exit;
 V:=ImgOf(O.V,O.S);
 If Odd(V) Then Err3('odd address','Adresse impaire','Ungerade Adresse');
End;

{ ---------------------------------------------------------------------- }
{ Modes d'adressage 68020+ : (bd,An,Xn*sc), ([bd,An],Xn,od), ([bd,An,Xn],od) }
{ ---------------------------------------------------------------------- }

{ separe un suffixe .W / .L d'une expression : retourne 0, 2 ou 4 }
Function SplitSize(Var S: String): Integer;
Var L: Integer;
Begin
 SplitSize:=0;L:=Length(S);
 If (L>2) And (S[L-1]='.') Then Begin
  If UpCase(S[L])='W' Then Begin SplitSize:=2;S:=Copy(S,1,L-2);End
  Else If UpCase(S[L])='L' Then Begin SplitSize:=4;S:=Copy(S,1,L-2);End;
 End;
End;

{ registre de base : 0..7 An, 8 PC ; +16 si supprime (ZAn / ZPC) ; -1 sinon }
Function BaseRegOf(Const U: String): Integer;
Begin
 BaseRegOf:=-1;
 If (Length(U)=3) And (U[1]='Z') And (U[2]='A') And (U[3]>='0') And (U[3]<='7')
   Then BaseRegOf:=16+Ord(U[3])-48
 Else If U='ZSP' Then BaseRegOf:=23
 Else If U='ZPC' Then BaseRegOf:=24
 Else If U='PC' Then BaseRegOf:=8
 Else If (RegOf(U)>=8) And (RegOf(U)<=15) Then BaseRegOf:=RegOf(U)-8;
End;

Procedure ParseFull(Const Inn: String; Var O: TOp);
Var Parts,Sub: Array[0..7] Of String; N,NS,I,J: Integer; T,U: String; Sz:
  Integer; InBr: Boolean;
    V: LongInt; Sc: Integer; Un: Boolean; Rg: Integer; Ok: Boolean;

 Procedure Item(T0: String; Br: Boolean);
 Var T2,U2: String; B,Rx: Integer; Lg: Boolean; Sc2: Integer;
 Begin
  T2:=TrimS(T0);U2:=Upper(T2);
  If T2='' Then Begin Ok:=False;Exit;End;
  B:=BaseRegOf(U2);
  If (B>=0) And (O.FB<0) Then Begin
   If B>=24 Then Begin O.FSup:=True;O.FB:=8;End
   Else If B>=16 Then Begin O.FSup:=True;O.FB:=B-16;End
   Else O.FB:=B;
   Exit;
  End;
  If ParseIndexReg(T2,Rx,Lg,Sc2) Then Begin
   If O.FIx>=0 Then Begin Ok:=False;Exit;End;
   O.FIx:=Rx;O.FIxL:=Lg;O.FSc:=Sc2;
   If O.FMem=1 Then Begin If Not Br Then O.FMem:=2;End;
   Exit;
  End;
  { expression : deplacement de base ou externe }
  Sz:=SplitSize(T2);
  If Not EvalOpnd(T2,V,Sc,Un) Then Begin Ok:=False;Exit;End;
  If LastX>0 Then Begin
    Err3('XREFs not allowed within brackets','XREF interdit entre crochets',
    'XREF in Klammern nicht erlaubt');Ok:=False;LastX:=0;End;
  If (O.FMem<>0) And Not Br Then Begin
   O.FHasOd:=True;O.FOdV:=V;O.FOdS:=Sc;O.FOdU:=Un;O.FOdSz:=Sz;
  End Else Begin
   If O.FHasBd Then Begin Ok:=False;Exit;End;
   O.FHasBd:=True;O.FBdV:=V;O.FBdS:=Sc;O.FBdU:=Un;O.FBdSz:=Sz;
  End;
 End;

Begin
 Ok:=True;
 O.K:=OK_FULL;O.FB:=-1;O.FIx:=-1;O.FSc:=1;O.FMem:=0;O.FSup:=False;O.FHasBd:=
   False;O.FHasOd:=False;
 N:=SplitTop(Inn,Parts,8);
 For I:=0 To N-1 Do Begin
  T:=TrimS(Parts[I]);
  If (T<>'') And (T[1]='[') And (T[Length(T)]=']') Then Begin
   O.FMem:=1;
   NS:=SplitTop(Copy(T,2,Length(T)-2),Sub,8);
   For J:=0 To NS-1 Do Item(Sub[J],True);
  End Else Item(T,False);
 End;
 { ZAn : numero de registre de base }
 If O.FB<0 Then Begin O.FB:=0;O.FSup:=True;End;
 If (AO.Proc<68020) Then Begin
  Err3('invalid 68020 addressing mode','Mode d''adressage 68020 invalide',
    'Ungueltiger 68020-Adressmodus');Ok:=False;
 End;
 If Not Ok Then Begin
  If AO.Proc>=68020 Then
    Err3('invalid 68020 addressing mode','Mode d''adressage 68020 invalide',
    'Ungueltiger 68020-Adressmodus');
  BadInstr:=True;
 End;
End;

Function EncFull(Var O: TOp): Integer;
Var Ext,Bs,Os: LongInt; At,Disp: LongInt; BdSz,OdSz,IIS: Integer; Bd,Od:
  LongInt; BdRel: Integer; ModeCode: Integer;
Begin
 At:=InstrPC+2+2*XWords;
 Ext:=$0100;
 If O.FIx>=0 Then Begin
  Ext:=Ext Or (LongInt(O.FIx) Shl 12) Or ScaleBits(O.FSc);
  If O.FIxL Then Ext:=Ext Or $800;
 End Else Ext:=Ext Or $40;
 If O.FSup Then Ext:=Ext Or $80;
 { base displacement }
 Bd:=0;BdRel:=-1;BdSz:=1;
 If O.FHasBd Then Begin
  Bd:=ImgOf(O.FBdV,O.FBdS);
  If O.FBdS>=0 Then BdRel:=O.FBdS;
  If (O.FB=8) And Not O.FSup Then Begin Bd:=Bd-At;BdRel:=-1;End;
  BdSz:=O.FBdSz;
  If BdSz=0 Then Begin
   If AO.BdW Then BdSz:=2 Else BdSz:=4;
   If (BdRel<0) And ((Bd>=-32768) And (Bd<=32767)) And (Not AO.BdW) And
     AO.Opt[8] And Not O.FBdU Then Begin
    BdSz:=2;OptStat(2);WarnOpt(8,'base displacement shortened');
   End;
  End;
  If BdSz=2 Then BdSz:=2;
  If BdSz=2 Then Ext:=Ext Or $20 Else Ext:=Ext Or $30;
 End Else Ext:=Ext Or $10;
 { deplacement externe }
 IIS:=0;OdSz:=0;Od:=0;
 If O.FMem<>0 Then Begin
  If O.FHasOd Then Begin
   Od:=ImgOf(O.FOdV,O.FOdS);OdSz:=O.FOdSz;
   If OdSz=0 Then Begin If AO.OdL Then OdSz:=4 Else OdSz:=2;End;
   If (OdSz=4) And (O.FOdSz=0) And AO.Opt[9] And (Od>=-32768) And (Od<=32767)
     And (O.FOdS<0) And Not O.FOdU Then Begin
    OdSz:=2;OptStat(2);WarnOpt(9,'outer displacement shortened');
   End;
   If OdSz=2 Then IIS:=2 Else IIS:=3;
  End Else IIS:=1;
  If O.FMem=2 Then IIS:=IIS Or 4;
  Ext:=Ext Or IIS;
 End;
 PutX(Ext,False,-1);
 If O.FHasBd Then Begin
  If BdSz=2 Then Begin CheckRange(Bd,O.FBdU,-32768,32767);PutX(Bd And
    $FFFF,False,-1);End
  Else PutX(Bd,True,BdRel);
 End;
 If OdSz=2 Then PutX(Od And $FFFF,False,-1) Else If OdSz=4 Then
   PutX(Od,True,-1);
 If (O.FB=8) And Not O.FSup Then EncFull:=59
 Else If O.FSup And (O.FB=8) Then EncFull:=59
 Else EncFull:=48+(O.FB And 7);
End;

Function EncEA(Var O: TOp; Sz: Integer; Allowed: LongInt): Integer;
Var Disp,Tgt,At: LongInt; Ext: LongInt;
Begin
 EncEA:=-1;
 { promotion d'un index court en format complet (68020+) }
 If (AO.Proc>=68020) And ((O.K=OK_IDX) Or (O.K=OK_PCI)) And Not O.U And (O.X=0)
   And
    ((O.V<-128) Or (O.V>127)) And (O.K=OK_IDX) Then Begin
  O.FB:=O.R;O.FIx:=O.XR;O.FIxL:=O.XL;O.FSc:=O.Scale;O.FMem:=0;O.FSup:=False;O.
    FHasBd:=True;
  O.FBdV:=O.V;O.FBdS:=O.S;O.FBdU:=O.U;O.FBdSz:=0;O.FHasOd:=False;O.FOdSz:=0;
  O.K:=OK_FULL;
 End;
 If (AO.Proc>=68020) And (O.K=OK_DISP) And Not O.U And (O.X=0) And
   ((O.V<-32768) Or (O.V>32767)) Then Begin
  O.FB:=O.R;O.FIx:=-1;O.FIxL:=False;O.FSc:=1;O.FMem:=0;O.FSup:=False;O.FHasBd:=
    True;
  O.FBdV:=O.V;O.FBdS:=O.S;O.FBdU:=O.U;O.FBdSz:=0;O.FHasOd:=False;O.FOdSz:=0;
  O.K:=OK_FULL;
 End;
 If O.K=OK_FULL Then Begin
  If (Allowed And KBit(OK_IDX))=0 Then Begin
   Err3('addressing mode not allowed','Mode d''adressage illegal',
     'Illegaler Adressmodus');BadInstr:=True;Exit;
  End;
  If (O.FB=8) And ((Allowed And KBit(OK_PCI))=0) Then Begin
   Err3('addressing mode not allowed','Mode d''adressage illegal',
     'Illegaler Adressmodus');BadInstr:=True;Exit;
  End;
  EncEA:=EncFull(O);Exit;
 End;
 If (O.K<1) Or (O.K>12) Or ((Allowed And KBit(O.K))=0) Then Begin
  Err3('addressing mode not allowed','Mode d''adressage illegal',
    'Illegaler Adressmodus');
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
            PutX(O.V And $FFFF,False,ImpRel(O,1,-1));
            EncEA:=40+O.R;
           End;
  OK_IDX: Begin
           CheckRange(O.V,O.U,-128,127);
           Ext:=(O.XR Shl 12) Or (O.V And $FF);
           If O.XL Then Ext:=Ext Or $800;
           Ext:=Ext Or ScaleBits(O.Scale);
           PutX(Ext,False,-1);
           EncEA:=48+O.R;
          End;
  OK_ABSW: Begin
            CheckRange(O.V,O.U,-32768,32767);
            If AO.ChkPC And (O.S>=0) Then
              Err3('relocation not allowed','Relocation interdite',
              'Relokation nicht erlaubt');
            CheckOddAbs(O,Sz);
            PutX(O.V And $FFFF,False,ImpRel(O,1,-1));
            EncEA:=56;
           End;
  OK_ABSL: Begin
            If AO.ChkPC And (O.S>=0) Then
              Err3('relocation not allowed','Relocation interdite',
              'Relokation nicht erlaubt');
            CheckOddAbs(O,Sz);
            PutX(ImgOf(O.V,O.S),True,ImpRel(O,0,O.S));
            EncEA:=57;
           End;
  OK_PCD,OK_PCI: Begin
            At:=InstrPC+2+2*XWords;
            Tgt:=ImgOf(O.V,O.S);
            Disp:=Tgt-At;
            If O.X>0 Then Disp:=O.V;
            If (AsmPassNo=2) And ((AO.Fmt=2) Or (AO.Fmt=7)) And (O.S>=0) And
              (O.S<>CurSect) Then
             Err3('linker format restriction',
               'Format d''edition de liens non gere',
               'Linker-Format nicht unterstuetzt');
            If (AO.Fmt=1) And (O.X=0) And (O.S>=0) And (O.S<>CurSect) And Not
              AbsMode Then Disp:=O.V;
            If O.K=OK_PCD Then Begin
             If (AsmPassNo=2) And Not O.U Then
              If (Disp<-32768) Or (Disp>32767) Then
               Err3('data too large','Deplacement hors limites',
                 'Abstand ausserhalb des Bereichs');
             If (AO.Fmt=1) And (O.X=0) And (O.S>=0) And (O.S<>CurSect) And Not
               AbsMode Then
              PutX(O.V And $FFFF,False,-10-O.S)
             Else PutX(Disp And $FFFF,False,ImpRel(O,2,-1));
             EncEA:=58;
            End Else Begin
             If (AsmPassNo=2) And Not O.U Then
              If (Disp<-128) Or (Disp>127) Then
               Err3('data too large','Deplacement hors limites',
                 'Abstand ausserhalb des Bereichs');
             Ext:=(O.XR Shl 12) Or (Disp And $FF);
             If O.XL Then Ext:=Ext Or $800;
             Ext:=Ext Or ScaleBits(O.Scale);
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
  If XLg[I] Then EmitLong(XW[I],XRl[I])
  Else If (XRl[I]>=RELIMP) Or (XRl[I]<=-10) Then EmitWordRel(XW[I],XRl[I])
  Else EmitWord(XW[I]);
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
  If (NOps=1) And (N=2) Then
    Err3('comma expected','Virgule attendue','Komma erwartet')
  Else If NOps<N Then
    Err3('expression mismatch','Operande attendue','Operand erwartet')
  Else
    Err3('garbage following instruction','Trop d''operandes',
    'Zu viele Operanden');
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
 Err3('addressing mode not allowed','Mode d''adressage illegal',
   'Illegaler Adressmodus');
 BadInstr:=True;
End;

Procedure BadSizeAn;
Begin
 Err3('invalid size','Taille illegale','Illegale Groesse');
 BadInstr:=True;
End;

Procedure BadErr(Const En,Fr,De: String);
Begin
 Err3(En,Fr,De);BadInstr:=True;
End;

Procedure BadSize;
Begin
 Err3('invalid size','Taille illegale','Illegale Groesse');
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
  Err3('garbage following instruction','Trop d''operandes',
    'Zu viele Operanden');BadInstr:=True;
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
  If M='TST' Then Begin Allowed:=MA_DALT;If AO.Proc>=68020 Then
    Allowed:=MA_ALL;End;
  If (M='TST') And (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSizeAn;Exit;End;
  E:=EncEA(Ops[1],Sz,Allowed);
  If E<0 Then Exit;
  If (Sz=1) And (Ops[1].K=OK_AN) Then BadSizeAn;
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

Function IsBranchM(Const M: String): Boolean;
Begin
 IsBranchM:=(M='BRA') Or (M='BSR') Or (Copy(M,1,2)='DB') Or
  ((Length(M)>=3) And (Length(M)<=3) And (M[1]='B') And
    (CondCode(Copy(M,2,2))>=0));
End;

Function NeedProc(P: LongInt): Boolean;
Begin
 NeedProc:=True;
 If AO.Proc<P Then Begin
  Err3('wrong processor','Mauvais processeur','Falscher Prozessor');
  BadInstr:=True;NeedProc:=False;
 End;
End;

Procedure GMul32(Const M: String);
Var E: Integer; Ext: LongInt; Sg,Dv: Boolean;
Begin
 If AO.Proc<68020 Then Begin
  If LnSz=4 Then Err3('invalid size','Taille illegale','Illegale Groesse')
  Else Err3('wrong processor','Mauvais processeur','Falscher Prozessor');
  BadInstr:=True;Exit;
 End;
 Sg:=(M='MULS') Or (M='DIVS') Or (M='DIVSL');
 Dv:=(M='DIVU') Or (M='DIVS') Or (M='DIVUL') Or (M='DIVSL');
 If (Ops[2].K<>OK_DN) And (Ops[2].K<>OK_PAIR) Then Begin BadMode;Exit;End;
 If Ops[2].K=OK_PAIR Then Begin
  { Dh:Dl (MUL) ou Dr:Dq (DIV) }
  If Dv Then Ext:=(LongInt(Ops[2].XR) Shl 12) Or Ops[2].R Else
    Ext:=(LongInt(Ops[2].XR) Shl 12) Or Ops[2].R;
  If (M<>'DIVUL') And (M<>'DIVSL') Then Ext:=Ext Or $400;
 End Else Begin
  If (M='DIVUL') Or (M='DIVSL') Then Begin BadMode;Exit;End;
  Ext:=(LongInt(Ops[2].R) Shl 12);
  If Dv Then Ext:=Ext Or Ops[2].R;
 End;
 If Sg Then Ext:=Ext Or $800;
 PutX(Ext,False,-1);
 E:=EncEA(Ops[1],4,MA_DATA);
 If E<0 Then Exit;
 If Dv Then OpW:=$4C40 Or E Else OpW:=$4C00 Or E;
End;

Function GArith(Const M: String): Boolean;
Var Base,IB: LongInt; Sz,E,E2: Integer; Imm: Boolean; Q: LongInt;
Begin
 GArith:=True;
 If (M='ADD') Or (M='SUB') Or (M='AND') Or (M='OR') Or (M='EOR') Or (M='CMP') Or
    (M='ADDI') Or (M='SUBI') Or (M='ANDI') Or (M='ORI') Or (M='EORI') Or
      (M='CMPI') Or
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
   If (M<>'AND') And (M<>'ANDI') And (M<>'OR') And (M<>'ORI') And (M<>'EOR')
     And (M<>'EORI') Then Begin
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
   If Sz=1 Then Begin BadSizeAn;Exit;End;
   If (Ops[1].K=OK_IMM) And ((M='ADD') Or (M='SUB') Or (M='ADDA') Or
     (M='SUBA')) Then Begin
    If AO.Opt[5] And ((M='ADD') Or (M='SUB')) Then
     If OptDecide(KnownAbs(Ops[1],1,8)) Then Begin
      If (M='ADD') Or (M='ADDA') Then OpW:=$5008 Else OpW:=$5108;
      OpW:=OpW Or (SzBits(Sz) Shl 6) Or ((Ops[1].V And 7) Shl 9) Or Ops[2].R;
      OptStat(4);WarnOpt(5,'quick form used');Exit;
     End;
    If AO.Opt[10] Then
     If OptDecide(KnownAbs(Ops[1],-32768,32767)) Then Begin
      OpW:=$41E8 Or (Ops[2].R Shl 9) Or Ops[2].R;
      If (M='ADD') Or (M='ADDA') Then PutX(Ops[1].V And $FFFF,False,-1) Else
        PutX((-Ops[1].V) And $FFFF,False,-1);
      OptStat(2);WarnOpt(10,'ADD/SUB converted to LEA');Exit;
     End;
   End;
   If AO.Opt[12] And (Sz=4) And (Ops[1].K=OK_IMM) Then
    If OptDecide(KnownAbs(Ops[1],-32768,32767)) Then Begin
      Sz:=2;OptStat(2);WarnOpt(12,'size should be .W');End;
   If Sz=4 Then Base:=Base Or $01C0 Else Base:=Base Or $00C0;
   E:=EncEA(Ops[1],Sz,MA_ALL);
   If E<0 Then Exit;
   OpW:=Base Or (Ops[2].R Shl 9) Or E;
   Exit;
  End;
  Sz:=DefSize(LnSz,2);
  Imm:=(Ops[1].K=OK_IMM) Or (M='ADDI') Or (M='SUBI') Or (M='ANDI') Or (M='ORI')
    Or
       (M='EORI') Or (M='CMPI');
  If Imm And ((M='ADD') Or (M='SUB')) And (Ops[1].K=OK_IMM) And AO.Opt[5] Then
   If OptDecide(KnownAbs(Ops[1],1,8)) Then Begin
    E:=EncEA(Ops[2],Sz,MA_ALT);If E<0 Then Exit;
    If M='ADD' Then Base:=$5000 Else Base:=$5100;
    OpW:=Base Or ((Ops[1].V And 7) Shl 9) Or (SzBits(Sz) Shl 6) Or E;
    OptStat(2);WarnOpt(5,'quick form used');Exit;
   End;
  If (M='CMP') And (Ops[1].K=OK_IMM) And (Ops[2].K=OK_DN) Then Imm:=False; { le
    vrai GenST garde CMP #imm,Dn }
  If Imm Then Begin
   If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
   ImmBase(M,IB);
   PutImm(Ops[1],Sz);
   If (IB=$0C00) And (AO.Proc>=68020) Then E:=EncEA(Ops[2],Sz,MA_DALT Or
     KBit(OK_PCD) Or KBit(OK_PCI))
   Else E:=EncEA(Ops[2],Sz,MA_DALT);
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
   If (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSizeAn;Exit;End;
   OpW:=Base Or (Ops[2].R Shl 9) Or (SzBits(Sz) Shl 6) Or E;
   Exit;
  End;
  { ADD, SUB, AND, OR }
  If Ops[2].K=OK_DN Then Begin
   If (M='AND') Or (M='OR') Then E:=EncEA(Ops[1],Sz,MA_DATA)
   Else E:=EncEA(Ops[1],Sz,MA_ALL);
   If E<0 Then Exit;
   If (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSizeAn;Exit;End;
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
  If AO.AllowZero And (Ops[1].V=0) And Not Ops[1].U Then Begin End
  Else CheckRange(Ops[1].V,Ops[1].U,1,8);
  If (Ops[1].S>=0) And Not Ops[1].U And (Ops[1].X=0) Then
    Err3('absolute not allowed','Absolu interdit','Absolut nicht erlaubt');
  Q:=Ops[1].V And 7;
  E:=EncEA(Ops[2],Sz,MA_ALT);
  If E<0 Then Exit;
  If (Ops[2].K=OK_AN) And (Sz=1) Then Begin BadSizeAn;Exit;End;
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
 If (M='DIVUL') Or (M='DIVSL') Then Begin
  If Not NeedOps(2) Then Exit;
  GMul32(M);Exit;
 End;
 If (M='MULU') Or (M='MULS') Or (M='DIVU') Or (M='DIVS') Or (M='CHK') Then Begin
  If Not NeedOps(2) Then Exit;
  If (LnSz=4) And (M<>'CHK') Then Begin GMul32(M);Exit;End;
  If M='MULU' Then Base:=$C0C0 Else If M='MULS' Then Base:=$C1C0
  Else If M='DIVU' Then Base:=$80C0 Else If M='DIVS' Then Base:=$81C0
  Else If LnSz=4 Then Begin
   If Not NeedProc(68020) Then Exit;
   Base:=$4100;
  End Else Base:=$4180;
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
   If AO.Proc>=68010 Then OpW:=$42C0 Or E
   Else Begin
    OpW:=$40C0 Or E;
    Warn3('68010 instruction, converted to MOVE SR',
      'Instruction 68010 convertie en MOVE SR',
      '68010-Befehl, in MOVE SR umgewandelt');
   End;
   Exit;
  End;
  If (Ops[1].K=OK_USP) And (Ops[2].K=OK_AN) Then Begin OpW:=$4E68 Or
    Ops[2].R;Exit;End;
  If (Ops[2].K=OK_USP) And (Ops[1].K=OK_AN) Then Begin OpW:=$4E60 Or
    Ops[1].R;Exit;End;
  Sz:=DefSize(LnSz,2);
  If Sz=1 Then SC:=1 Else If Sz=4 Then SC:=2 Else SC:=3;
  If (Sz=4) And (LnSz=4) And AO.Opt[4] And (Ops[1].K=OK_IMM) And
    (Ops[2].K=OK_DN) Then
   If OptDecide(KnownAbs(Ops[1],-128,127)) Then Begin
    OpW:=$7000 Or (Ops[2].R Shl 9) Or (Ops[1].V And $FF);
    OptStat(4);WarnOpt(4,'MOVEQ substituted');Exit;
   End;
  If (Sz=4) And (LnSz=4) And AO.Opt[12] And (Ops[1].K=OK_IMM) And
    (Ops[2].K=OK_AN) Then
   If OptDecide(KnownAbs(Ops[1],-32768,32767)) Then Begin
    Sz:=2;SC:=3;OptStat(2);WarnOpt(12,'size should be .W');
   End;
  If Ops[2].K=OK_AN Then Begin
   If Sz=1 Then Begin BadSizeAn;Exit;End;
   E:=EncEA(Ops[1],Sz,MA_ALL);If E<0 Then Exit;
   OpW:=(SC Shl 12) Or (Ops[2].R Shl 9) Or $40 Or E;
   Exit;
  End;
  If M='MOVEA' Then Begin BadMode;Exit;End;
  E:=EncEA(Ops[1],Sz,MA_ALL);If E<0 Then Exit;
  If (Sz=1) And (Ops[1].K=OK_AN) Then Begin BadSizeAn;Exit;End;
  E2:=EncEA(Ops[2],Sz,MA_DALT);If E2<0 Then Exit;
  OpW:=(SC Shl 12) Or ((E2 And 7) Shl 9) Or ((E2 Shr 3) Shl 6) Or E;
  Exit;
 End;
 If M='MOVEQ' Then Begin
  If Not NeedOps(2) Then Exit;
  If (Ops[1].K<>OK_IMM) Or (Ops[2].K<>OK_DN) Then Begin BadMode;Exit;End;
  CheckRange(Ops[1].V,Ops[1].U,-128,255);
  If (Ops[1].S>=0) And Not Ops[1].U And (Ops[1].X=0) Then
    Err3('relative not allowed','Relatif interdit','Relativ nicht erlaubt');
  If (Ops[1].V>=128) And (Ops[1].V<=255) And (LnSz<>4) And Not Ops[1].U Then
   Warn3('sign extended operand','Operande etendu avec signe',
     'Operand vorzeichenerweitert');
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
    For I:=0 To 15 Do If (Mk And (LongInt(1) Shl I))<>0 Then RM:=RM Or
      (LongInt(1) Shl (15-I));
    Mk:=RM;
   End;
   PutX(Mk And $FFFF,False,-1);
   E:=EncEA(Ops[2],Sz,MA_CALT Or KBit(OK_PRE));If E<0 Then Exit;
   OpW:=$4880 Or E;
   If Sz=4 Then OpW:=OpW Or $40;
  End Else If (Ops[2].K=OK_LIST) Or (Ops[2].K=OK_DN) Or (Ops[2].K=OK_AN) Then
    Begin
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
  End Else If (Ops[2].K=OK_DN) And ((Ops[1].K=OK_DISP) Or (Ops[1].K=OK_IND))
    Then Begin
   OpW:=$0108 Or (Ops[2].R Shl 9) Or Ops[1].R;
   If Sz=4 Then OpW:=OpW Or $40;
   PutX(Ops[1].V And $FFFF,False,-1);
  End Else
    BadErr('invalid MOVEP addressing mode','Mode MOVEP invalide',
    'Ungueltiger MOVEP-Adressmodus');
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
   OpW:=$E000 Or (1 Shl 9) Or (Dir Shl 8) Or (SzBits(Sz) Shl 6) Or (T Shl 3) Or
     Ops[1].R;
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
 OpW:=$E000 Or (Cnt Shl 9) Or (Dir Shl 8) Or (SzBits(Sz) Shl 6) Or (IR Shl 5)
   Or (T Shl 3) Or Ops[2].R;
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
  If (Ops[2].K<>OK_DN) And Not Ops[1].U And ((Ops[1].V<0) Or (Ops[1].V>7)) Then
    Begin
   If AO.ChkBit=0 Then
     Err3('Bit number should be 0-7 for byte','Numero de bit 0-7 pour un octet',
     'Bitnummer 0-7 fuer Byte')
   Else If AO.ChkBit=2 Then
     Warn3('Bit number should be 0-7 for byte',
     'Numero de bit 0-7 pour un octet','Bitnummer 0-7 fuer Byte');
  End;
  PutX(Ops[1].V And $FF,False,-1);
  E:=EncEA(Ops[2],Sz,Al);If E<0 Then Exit;
  OpW:=$0800 Or (T Shl 6) Or E;
 End Else BadMode;
End;

Function GBranch(Const M: String): Boolean;
Var CC: Integer; Disp,Tgt,At: LongInt; Short,SameSec,Lng: Boolean; Sz: Integer;
    N: String; Explicit: Boolean;
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
 If (Ops[1].X>0) Or ((AO.Fmt=1) And (Ops[1].S>=0) And (Ops[1].S<>CurSect) And
   Not AbsMode) Then Begin
  { branche vers un import ou (GST) une autre section : toujours un mot, le
    deplacement est l'addenda }
  If (LnSz=1) Or (LnSz=8) Then
    Err3('relocation not allowed','Relocation interdite',
    'Relokation nicht erlaubt');
  OpW:=$6000 Or (CC Shl 8);
  If Ops[1].X>0 Then PutX(Ops[1].V And $FFFF,False,ImpRel(Ops[1],2,-1))
  Else PutX(Ops[1].V And $FFFF,False,-10-Ops[1].S);
  Exit;
 End;
 Sz:=LnSz;
 Explicit:=Sz<>0;
 If Sz=0 Then Begin
  If AO.BrDef=1 Then Sz:=1 Else If AO.BrDef=3 Then Sz:=4;
 End;
 Lng:=False;
 If Sz=4 Then Begin
  If (AO.Proc>=68020) And Not AO.OldBra Then Lng:=True
  Else Begin
   If Explicit Then
     Warn3('size should be .W','La taille devrait etre .W',
     'Groesse sollte .W sein');
   Sz:=2;
  End;
 End;
 If (Sz=1) Or (Sz=8) Then Short:=True
 Else If (Sz=2) Or Lng Then Short:=False
 Else Begin
  { taille automatique : decision enregistree a la passe 1 }
  Inc(DecIdx);
  If DecIdx>=DECCAP Then Begin
   DecIdx:=DECCAP-1;
   Err3('program buffer full','Programme trop grand','Programm zu gross');
  End;
  If AsmPassNo=1 Then Begin
   SameSec:=AbsMode Or (Ops[1].S=CurSect);
   Decs^[DecIdx]:=0;
   If Not Ops[1].U And SameSec And (Disp>=-128) And (Disp<=127) And (Disp<>0)
      And (Disp<>-1) Then Begin
    If OptOptimize Or (AO.Opt[1] And (Disp<0)) Then Decs^[DecIdx]:=1;
   End;
  End;
  Short:=Decs^[DecIdx]=1;
  If AsmPassNo=2 Then Begin
   If Short And AO.Opt[1] And (Disp<0) Then Begin
     OptStat(2);WarnOpt(1,'branch made short');End;
   If (Not Short) And AO.Opt[6] And AO.Opt[1] And Not Ops[1].U And (Disp>0) And
     (Disp<=127) Then WarnOpt(6,'branch could be short');
  End;
 End;
 If (AsmPassNo=2) And ((AO.Fmt=2) Or (AO.Fmt=7)) And (Ops[1].S>=0) And
   (Ops[1].S<>CurSect) Then
  Err3('linker format restriction','Format d''edition de liens non gere',
    'Linker-Format nicht unterstuetzt');
 If AsmPassNo=2 Then Begin
  If Not Ops[1].U And Odd(Tgt) Then
    Err3('odd address','Adresse impaire','Ungerade Adresse');
 End;
 If Short Then Begin
  If (AsmPassNo=2) And Not Ops[1].U Then
   If (Disp<-128) Or (Disp>127) Then
    Err3('data too large','Branchement hors limites',
      'Sprung ausserhalb des Bereichs');
  OpW:=$6000 Or (CC Shl 8) Or (Disp And $FF);
  If (Disp=0) And ((Ops[1].S=CurSect) Or AbsMode) And Not Ops[1].U Then Begin
   If CC=1 Then Err3('illegal BSR.S','BSR.S illegal','BSR.S unzulaessig')
   Else If AO.Opt[7] Then Begin
    OpW:=$4E71;
    Warn3('short branch converted to NOP','Branchement court converti en NOP',
      'Kurzer Sprung in NOP umgewandelt');
   End Else
     Err3('short branch cannot be 0 bytes','Branchement court de 0 octet',
     'Kurzer Sprung mit 0 Bytes');
  End;
 End Else If Lng Then Begin
  OpW:=$6000 Or (CC Shl 8) Or $FF;
  PutX(Disp,True,-1);
 End Else Begin
  If (AsmPassNo=2) And Not Ops[1].U Then
   If (Disp<-32768) Or (Disp>32767) Then
    Err3('data too large','Branchement hors limites',
      'Sprung ausserhalb des Bereichs');
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
  If Ops[2].K<>OK_AN Then Begin
    BadErr('address register expected','Registre d''adresse attendu',
    'Adressregister erwartet');Exit;End;
  If AO.Opt[11] And (Ops[1].K=OK_DISP) And (Ops[1].R=Ops[2].R) Then
   If OptDecide(KnownAbs(Ops[1],-8,8) And (Ops[1].V<>0)) Then Begin
    If Ops[1].V>0 Then OpW:=$5048 Or ((Ops[1].V And 7) Shl 9) Or Ops[2].R
    Else OpW:=$5148 Or (((-Ops[1].V) And 7) Shl 9) Or Ops[2].R;
    OptStat(2);WarnOpt(11,'LEA converted to ADDQ/SUBQ');Exit;
   End;
  E:=EncEA(Ops[1],4,MA_CTRL);If E<0 Then Exit;
  OpW:=$41C0 Or (Ops[2].R Shl 9) Or E;
 End Else If M='LINK' Then Begin
  If Not NeedOps(2) Then Exit;
  If Ops[1].K<>OK_AN Then Begin
    BadErr('address register expected','Registre d''adresse attendu',
    'Adressregister erwartet');Exit;End;
  If Ops[2].K<>OK_IMM Then Begin
    BadErr('immediate data expected','Donnee immediate attendue',
    'Direkter Wert erwartet');Exit;End;
  If Not Ops[2].U Then
   If (Ops[2].V>0) Or Odd(Ops[2].V) Then
    Warn3('invalid LINK displacement','Deplacement LINK invalide',
      'Ungueltige LINK-Verschiebung');
  If LnSz=4 Then Begin
   If AO.Proc<68020 Then Begin
    Err3('wrong processor','Mauvais processeur',
      'Falscher Prozessor');BadInstr:=True;Exit;
   End;
   OpW:=$4808 Or Ops[1].R;
   PutImm(Ops[2],4);
  End Else Begin
   OpW:=$4E50 Or Ops[1].R;
   PutImm(Ops[2],2);
  End;
 End Else If M='UNLK' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_AN Then Begin
    BadErr('address register expected','Registre d''adresse attendu',
    'Adressregister erwartet');Exit;End;
  OpW:=$4E58 Or Ops[1].R;
 End Else If M='SWAP' Then Begin
  If NOps=0 Then Begin
    BadErr('data register expected','Registre de donnees attendu',
    'Datenregister erwartet');Exit;End;
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_DN Then Begin
    BadErr('data register expected','Registre de donnees attendu',
    'Datenregister erwartet');Exit;End;
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
   OpW:=$C148 Or (Ops[2].R Shl 9) Or Ops[1].R
  Else If (Ops[1].K=OK_DN) And (Ops[2].K=OK_AN) Then
   OpW:=$C188 Or (Ops[1].R Shl 9) Or Ops[2].R
  Else If (Ops[1].K=OK_AN) And (Ops[2].K=OK_DN) Then
   OpW:=$C188 Or (Ops[2].R Shl 9) Or Ops[1].R
  Else BadMode;
 End Else If M='TRAP' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_IMM Then Begin
    BadErr('immediate data expected','Donnee immediate attendue',
    'Direkter Wert erwartet');Exit;End;
  CheckRange(Ops[1].V,Ops[1].U,0,15);
  If (Ops[1].S>=0) And Not Ops[1].U And (Ops[1].X=0) Then
    Err3('relative not allowed','Relatif interdit','Relativ nicht erlaubt');
  OpW:=$4E40 Or (Ops[1].V And 15);
 End Else If M='STOP' Then Begin
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_IMM Then Begin
    BadErr('immediate data expected','Donnee immediate attendue',
    'Direkter Wert erwartet');Exit;End;
  OpW:=$4E72;
  PutImm(Ops[1],2);
 End Else If (M='DBRA') Or ((Length(M)>=3) And (Length(M)<=4) And
   (Copy(M,1,2)='DB') And (CondCode(Copy(M,3,2))>=0)) Then Begin
  If Not NeedOps(2) Then Exit;
  If M='DBRA' Then CC:=1 Else CC:=CondCode(Copy(M,3,2));
  If (Ops[1].K<>OK_DN) Or ((Ops[2].K<>OK_ABSL) And (Ops[2].K<>OK_ABSW)) Then
    Begin BadMode;Exit;End;
  At:=InstrPC+2;
  Disp:=ImgOf(Ops[2].V,Ops[2].S)-At;
  If (AsmPassNo=2) And Not Ops[2].U Then
   If (Disp<-32768) Or (Disp>32767) Then
    Err3('data too large','Branchement hors limites',
      'Sprung ausserhalb des Bereichs');
  If (AsmPassNo=2) And Not Ops[2].U And Odd(Disp+At) Then
    Err3('odd address','Adresse impaire','Ungerade Adresse');
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

{ ---------------------------------------------------------------------- }
{ Instructions 68010 / 68020 / 68030 / 68040 (entiers)                     }
{ ---------------------------------------------------------------------- }

{ registre de controle MOVEC : numero ou -1 ; Mini : processeur minimal }
Function CtlReg(Const U: String; Var Mini: LongInt): Integer;
Begin
 CtlReg:=-1;Mini:=68010;
 If U='SFC' Then CtlReg:=$000 Else If U='DFC' Then CtlReg:=$001
 Else If U='USP' Then CtlReg:=$800 Else If U='VBR' Then CtlReg:=$801
 Else Begin
  Mini:=68020;
  If U='CACR' Then CtlReg:=$002 Else If U='CAAR' Then CtlReg:=$802
  Else If U='MSP' Then CtlReg:=$803 Else If U='ISP' Then CtlReg:=$804
  Else Begin
   Mini:=68040;
   If U='TC' Then CtlReg:=$003 Else If U='ITT0' Then CtlReg:=$004 Else If
     U='ITT1' Then CtlReg:=$005
   Else If U='DTT0' Then CtlReg:=$006 Else If U='DTT1' Then CtlReg:=$007
   Else If U='MMUSR' Then CtlReg:=$805 Else If U='URP' Then CtlReg:=$806 Else
     If U='SRP' Then CtlReg:=$807;
  End;
 End;
End;

Procedure GMovec;
Var A,B: String; R,C: Integer; Mini: LongInt; ToCtl: Boolean;
Begin
 If NOps<>2 Then Begin NeedOps(2);Exit;End;
 A:=Upper(TrimS(OpStr[1]));B:=Upper(TrimS(OpStr[2]));
 If RegOf(A)>=0 Then Begin
  R:=RegOf(A);C:=CtlReg(B,Mini);ToCtl:=True;
 End Else Begin
  R:=RegOf(B);C:=CtlReg(A,Mini);ToCtl:=False;
 End;
 If (R<0) Or (R>15) Or (C<0) Then Begin BadMode;Exit;End;
 If Not NeedProc(Mini) Then Exit;
 If ToCtl Then OpW:=$4E7B Else OpW:=$4E7A;
 PutX((LongInt(R) Shl 12) Or C,False,-1);
End;

Procedure GCas2;
Var S: Array[1..3] Of String; I,P: Integer; R: Array[1..6] Of Integer; T:
  String;
Begin
 If Not NeedProc(68020) Then Exit;
 If NOps<>3 Then Begin NeedOps(3);Exit;End;
 For I:=1 To 3 Do Begin
  S[I]:=OpStr[I];P:=Pos(':',S[I]);
  If P=0 Then Begin
    BadErr('colon (:) expected','Deux-points (:) attendu',
    'Doppelpunkt (:) erwartet');Exit;End;
  R[I*2-1]:=-1;R[I*2]:=-1;
  T:=Upper(TrimS(Copy(S[I],1,P-1)));
  If (T<>'') And (T[1]='(') Then T:=Copy(T,2,Length(T)-2);
  R[I*2-1]:=RegOf(T);
  T:=Upper(TrimS(Copy(S[I],P+1,40)));
  If (T<>'') And (T[1]='(') Then T:=Copy(T,2,Length(T)-2);
  R[I*2]:=RegOf(T);
  If (R[I*2-1]<0) Or (R[I*2]<0) Or (R[I*2-1]>15) Or (R[I*2]>15) Then Begin
    BadMode;Exit;End;
 End;
 If LnSz=4 Then OpW:=$0EFC Else OpW:=$0CFC;
 PutX((LongInt(R[5]) Shl 12) Or (LongInt(R[3]) Shl 6) Or R[1],False,-1);
 PutX((LongInt(R[6]) Shl 12) Or (LongInt(R[4]) Shl 6) Or R[2],False,-1);
End;

Procedure GMove16;
Var A,B: String; Ra,Rb: Integer; E: Integer;
 Function Ind(Const S: String; Var Post: Boolean): Integer;
 Var U: String;
 Begin
  Ind:=-1;Post:=False;U:=Upper(TrimS(S));
  If (Length(U)>=4) And (U[1]='(') Then Begin
   If (Length(U)=5) And (U[5]='+') Then Post:=True;
   If (U[Length(U)]=')') Or Post Then Ind:=RegOf(Copy(U,2,2))-8;
  End;
 End;
Var Pa,Pb: Boolean; Ob: TOp;
Begin
 If Not NeedProc(68040) Then Exit;
 If NOps<>2 Then Begin NeedOps(2);Exit;End;
 Ra:=Ind(OpStr[1],Pa);Rb:=Ind(OpStr[2],Pb);
 If (Ra>=0) And (Ra<8) And Pa And (Rb>=0) And (Rb<8) And Pb Then Begin
  OpW:=$F620 Or Ra;PutX($8000 Or (LongInt(Rb) Shl 12),False,-1);Exit;
 End;
 If (Ra>=0) And Pa And (Ops[2].K=OK_ABSL) Then Begin OpW:=$F600 Or
   Ra;PutX(ImgOf(Ops[2].V,Ops[2].S),True,Ops[2].S);Exit;End;
 If (Rb>=0) And Pb And (Ops[1].K=OK_ABSL) Then Begin OpW:=$F608 Or
   Rb;PutX(ImgOf(Ops[1].V,Ops[1].S),True,Ops[1].S);Exit;End;
 If (Ra>=0) And Not Pa And (Ops[2].K=OK_ABSL) Then Begin OpW:=$F610 Or
   Ra;PutX(ImgOf(Ops[2].V,Ops[2].S),True,Ops[2].S);Exit;End;
 If (Rb>=0) And Not Pb And (Ops[1].K=OK_ABSL) Then Begin OpW:=$F618 Or
   Rb;PutX(ImgOf(Ops[1].V,Ops[1].S),True,Ops[1].S);Exit;End;
 BadMode;
End;

Function GExt(Const M: String): Boolean;
Var E,Cc,Sc,Ca: Integer; Ext: LongInt; Mk: LongInt; I: Integer; Sz: Integer; P:
  LongInt;
Begin
 GExt:=True;
 If (M='CALLM') Or (M='RTM') Then Begin
  If Not NeedProc(68020) Then Exit;
  BadErr('not yet implemented','Pas encore implemente',
    'Noch nicht implementiert');Exit;
 End Else If M='EXTB' Then Begin
  If Not NeedProc(68020) Then Exit;
  If Not NeedOps(1) Then Exit;
  If (Ops[1].K<>OK_DN) Or (LnSz=1) Or (LnSz=2) Then Begin BadMode;Exit;End;
  OpW:=$49C0 Or Ops[1].R;
 End Else If M='RTD' Then Begin
  If Not NeedProc(68010) Then Exit;
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
  OpW:=$4E74;PutImm(Ops[1],2);
 End Else If M='BKPT' Then Begin
  If Not NeedProc(68010) Then Exit;
  If Not NeedOps(1) Then Exit;
  If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
  CheckRange(Ops[1].V,Ops[1].U,0,7);
  OpW:=$4848 Or (Ops[1].V And 7);
 End Else If (Length(M)>=5) And (Copy(M,1,4)='TRAP') And (M<>'TRAPV') And
   (M<>'TRAP') Then Begin
  Cc:=CondCode(Copy(M,5,2));
  If Cc<0 Then Begin GExt:=False;Exit;End;
  If Not NeedProc(68020) Then Exit;
  If (NOps=0) And (LnSz=0) Then OpW:=$50FC Or (Cc Shl 8)
  Else If NOps=1 Then Begin
   If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
   If LnSz=4 Then Begin OpW:=$50FB Or (Cc Shl 8);PutImm(Ops[1],4);End
   Else Begin OpW:=$50FA Or (Cc Shl 8);PutImm(Ops[1],2);End;
  End Else Begin NeedOps(0);Exit;End;
 End Else If M='MOVES' Then Begin
  If Not NeedProc(68010) Then Exit;
  If Not NeedOps(2) Then Exit;
  Sz:=DefSize(LnSz,2);
  If (Ops[1].K=OK_DN) Or (Ops[1].K=OK_AN) Then Begin
   If Ops[1].K=OK_DN Then I:=Ops[1].R Else I:=8+Ops[1].R;
   Ext:=(LongInt(I) Shl 12) Or $800;
   PutX(Ext,False,-1);
   E:=EncEA(Ops[2],Sz,MA_MALT);If E<0 Then Exit;
  End Else If (Ops[2].K=OK_DN) Or (Ops[2].K=OK_AN) Then Begin
   If Ops[2].K=OK_DN Then I:=Ops[2].R Else I:=8+Ops[2].R;
   PutX(LongInt(I) Shl 12,False,-1);
   E:=EncEA(Ops[1],Sz,MA_MALT);If E<0 Then Exit;
  End Else Begin BadMode;Exit;End;
  OpW:=$0E00 Or (SzBits(Sz) Shl 6) Or E;
 End Else If (M='BFTST') Or (M='BFCHG') Or (M='BFCLR') Or (M='BFSET') Or
   (M='BFEXTU') Or (M='BFEXTS') Or
             (M='BFFFO') Or (M='BFINS') Then Begin
  If Not NeedProc(68020) Then Exit;
  If (M='BFTST') Or (M='BFCHG') Or (M='BFCLR') Or (M='BFSET') Then Begin
   If Not NeedOps(1) Then Exit;
   If Not Ops[1].HasBF Then Begin BadMode;Exit;End;
   If M='BFTST' Then Begin OpW:=$E8C0;Mk:=MA_CTRL Or KBit(OK_DN) Or
     KBit(OK_PCD) Or KBit(OK_PCI);End
   Else Begin
    If M='BFCHG' Then OpW:=$EAC0 Else If M='BFCLR' Then OpW:=$ECC0 Else
      OpW:=$EEC0;
    Mk:=MA_CALT Or KBit(OK_DN);
   End;
   PutX(Ops[1].BF,False,-1);
   E:=EncEA(Ops[1],4,Mk);If E<0 Then Exit;
   OpW:=OpW Or E;
  End Else If M='BFINS' Then Begin
   If Not NeedOps(2) Then Exit;
   If (Ops[1].K<>OK_DN) Or Not Ops[2].HasBF Then Begin BadMode;Exit;End;
   PutX((LongInt(Ops[1].R) Shl 12) Or Ops[2].BF,False,-1);
   E:=EncEA(Ops[2],4,MA_CALT Or KBit(OK_DN));If E<0 Then Exit;
   OpW:=$EFC0 Or E;
  End Else Begin
   If Not NeedOps(2) Then Exit;
   If Not Ops[1].HasBF Or (Ops[2].K<>OK_DN) Then Begin BadMode;Exit;End;
   If M='BFEXTU' Then OpW:=$E9C0 Else If M='BFEXTS' Then OpW:=$EBC0 Else
     OpW:=$EDC0;
   PutX((LongInt(Ops[2].R) Shl 12) Or Ops[1].BF,False,-1);
   E:=EncEA(Ops[1],4,MA_CTRL Or KBit(OK_DN) Or KBit(OK_PCD) Or KBit(OK_PCI));If
     E<0 Then Exit;
   OpW:=OpW Or E;
  End;
 End Else If M='CAS' Then Begin
  If Not NeedProc(68020) Then Exit;
  If Not NeedOps(3) Then Exit;
  If (Ops[1].K<>OK_DN) Or (Ops[2].K<>OK_DN) Then Begin BadMode;Exit;End;
  Sz:=DefSize(LnSz,2);
  PutX((LongInt(Ops[2].R) Shl 6) Or Ops[1].R,False,-1);
  E:=EncEA(Ops[3],Sz,MA_MALT);If E<0 Then Exit;
  If Sz=1 Then OpW:=$0AC0 Else If Sz=2 Then OpW:=$0CC0 Else OpW:=$0EC0;
  OpW:=OpW Or E;
 End Else If (M='CMP2') Or (M='CHK2') Then Begin
  If Not NeedProc(68020) Then Exit;
  If Not NeedOps(2) Then Exit;
  Sz:=DefSize(LnSz,2);
  If Ops[2].K=OK_DN Then I:=Ops[2].R Else If Ops[2].K=OK_AN Then I:=8+Ops[2].R
    Else Begin BadMode;Exit;End;
  Ext:=LongInt(I) Shl 12;
  If M='CHK2' Then Ext:=Ext Or $800;
  PutX(Ext,False,-1);
  E:=EncEA(Ops[1],Sz,MA_CTRL Or KBit(OK_PCD) Or KBit(OK_PCI));If E<0 Then Exit;
  OpW:=(LongInt(SzBits(Sz)) Shl 9) Or $00C0 Or E;
 End Else If (M='PACK') Or (M='UNPK') Then Begin
  If Not NeedProc(68020) Then Exit;
  If Not NeedOps(3) Then Exit;
  If Ops[3].K<>OK_IMM Then Begin BadMode;Exit;End;
  If (Ops[1].K=OK_DN) And (Ops[2].K=OK_DN) Then P:=0
  Else If (Ops[1].K=OK_PRE) And (Ops[2].K=OK_PRE) Then P:=8
  Else Begin BadMode;Exit;End;
  If M='PACK' Then OpW:=$8140 Else OpW:=$8180;
  OpW:=OpW Or (LongInt(Ops[2].R) Shl 9) Or P Or Ops[1].R;
  PutImm(Ops[3],2);
 End Else If (M='CINVL') Or (M='CINVP') Or (M='CINVA') Or (M='CPUSHL') Or
   (M='CPUSHP') Or (M='CPUSHA') Then Begin
  If Not NeedProc(68040) Then Exit;
  Sc:=1;
  If M[Length(M)]='P' Then Sc:=2 Else If M[Length(M)]='A' Then Sc:=3;
  If Sc=3 Then Begin If Not NeedOps(1) Then Exit;End Else If Not NeedOps(2)
    Then Exit;
  Ca:=-1;
  If Not (((Ops[1].K=OK_ABSL) Or (Ops[1].K=OK_ABSW)) And (Ops[1].V=0)) Then
    Begin End;
  Case UpCase(OpStr[1][1]) Of
   'N': Ca:=0;
   'D': Ca:=1;
   'I': Ca:=2;
   'B': Ca:=3;
  End;
  If (Ca<0) Or (Length(OpStr[1])<>2) Then Begin BadMode;Exit;End;
  OpW:=$F400 Or (LongInt(Ca) Shl 6) Or (LongInt(Sc) Shl 3);
  If Copy(M,1,5)='CPUSH' Then OpW:=OpW Or $20;
  If Sc<>3 Then Begin
   If Ops[2].K<>OK_IND Then Begin BadMode;Exit;End;
   OpW:=OpW Or Ops[2].R;
  End;
 End Else GExt:=False;
End;

{ ---------------------------------------------------------------------- }
{ Constantes et instructions 68881 / 68882 / 68040 FPU                    }
{ ---------------------------------------------------------------------- }

Type
 TFBytes = Array[0..11] Of Byte;

Function HasFPU: Boolean;
Begin
 HasFPU:=AO.FPU Or (AO.Proc>=68040);
End;

Function NeedFPU: Boolean;
Begin
 NeedFPU:=True;
 If Not HasFPU Then Begin
  Err3('maths co-processor required','Coprocesseur arithmetique requis',
    'Mathematischer Coprozessor erforderlich');
  BadInstr:=True;NeedFPU:=False;
 End;
End;

Function ByteVal(C: Char): Integer;
Begin
 ByteVal:=HexVal(C);
End;

{ valeur d'un texte flottant decimal : Ok=False si syntaxe invalide }
Function DecToExt(Const T0: String; Var E: Extended): Boolean;
Var T: String; C: Integer; Neg: Boolean; K: Integer;
Begin
 T:=TrimS(T0);Neg:=False;
 If (T<>'') And (T[1]='-') Then Begin Neg:=True;Delete(T,1,1);End
 Else If (T<>'') And (T[1]='+') Then Delete(T,1,1);
 If T='' Then Begin DecToExt:=False;Exit;End;
 If (T[1]>='A') Or ((T[1]>='a') And (T[1]<='z')) Then Begin
  K:=FeqFind(T);
  If K=0 Then Begin DecToExt:=False;Exit;End;
  E:=FeqVal[K];If Neg Then E:=-E;DecToExt:=True;Exit;
 End;
 If T[1]='.' Then T:='0'+T;
 Val(T,E,C);
 If C<>0 Then Begin DecToExt:=False;Exit;End;
 If Neg Then E:=-E;
 DecToExt:=True;
End;

{ octets 68881 d'une valeur etendue : Sz = 8 (S), 16 (D), 32 (X) ; erreur si
  trop grand }
Function ExtToBytes(E: Extended; Sz: Integer; Var B: TFBytes; Var Len:
  Integer): Boolean;
Var Sg: Single; Db: Double; Tmp: Array[0..9] Of Byte; I: Integer; A: Extended;
  S4: Array[0..3] Of Byte; D8: Array[0..7] Of Byte;
Begin
 ExtToBytes:=True;FillChar(B,SizeOf(B),0);
 A:=E;If A<0 Then A:=-A;
 If Sz=8 Then Begin
  Len:=4;
  If A>3.4028234663852886E38 Then Begin ExtToBytes:=False;Exit;End;
  If (A<>0) And (A<1.1754943508222875E-38) And (A<1.4E-45) Then Sg:=0 Else
    Sg:=E;
  Move(Sg,S4,4);
  For I:=0 To 3 Do B[I]:=S4[3-I];
 End Else If Sz=16 Then Begin
  Len:=8;
  If A>1.7976931348623157E308 Then Begin ExtToBytes:=False;Exit;End;
  Db:=E;
  Move(Db,D8,8);
  For I:=0 To 7 Do B[I]:=D8[7-I];
 End Else Begin
  Len:=12;
  Move(E,Tmp,10);
  B[0]:=Tmp[9];B[1]:=Tmp[8];
  For I:=0 To 7 Do B[4+I]:=Tmp[7-I];
 End;
End;

{ decimal packe (96 bits) depuis un texte decimal }
Function DecToPacked(Const T0: String; Var B: TFBytes): Boolean;
Var T,Dg: String; I,P,Ex,Fr: Integer; Neg,ENeg,Seen: Boolean; Mant: String; C:
  Integer;
    ExS: String; ExV: LongInt;
Begin
 DecToPacked:=False;FillChar(B,SizeOf(B),0);
 T:=TrimS(T0);Neg:=False;
 If (T<>'') And (T[1]='-') Then Begin Neg:=True;Delete(T,1,1);End Else If
   (T<>'') And (T[1]='+') Then Delete(T,1,1);
 Dg:='';Fr:=0;Seen:=False;ExV:=0;I:=1;
 While (I<=Length(T)) And ((T[I] In ['0'..'9']) Or (T[I]='.')) Do Begin
  If T[I]='.' Then Begin If Seen Then Exit;Seen:=True;End
  Else Begin Dg:=Dg+T[I];If Seen Then Inc(Fr);End;
  Inc(I);
 End;
 If Dg='' Then Exit;
 If I<=Length(T) Then Begin
  If (T[I]<>'E') And (T[I]<>'e') Then Exit;
  ExS:=Copy(T,I+1,10);Val(ExS,ExV,C);If C<>0 Then Exit;
 End;
 { normalise : 1 chiffre entier + 16 decimales, exposant decimal }
 While (Length(Dg)>1) And (Dg[1]='0') Do Delete(Dg,1,1);
 Ex:=ExV-Fr+Length(Dg)-1;
 If (Dg='0') Or (Dg='00') Then Ex:=0;
 While Length(Dg)<17 Do Dg:=Dg+'0';
 Dg:=Copy(Dg,1,17);
 If ExV=0 Then ;
 ENeg:=Ex<0;If ENeg Then Ex:=-Ex;
 If Ex>9999 Then Exit;
 { mot 0 : SM SE 00 E2 E1 E0 ; E3 en bits 79-76 }
 B[0]:=((Ex Div 100) Mod 10)+0;
 B[0]:=B[0] Or (Ord(Neg) Shl 7) Or (Ord(ENeg) Shl 6);
 B[1]:=(((Ex Div 10) Mod 10) Shl 4) Or (Ex Mod 10);
 B[2]:=((Ex Div 1000) Mod 10) Shl 4;
 B[3]:=Ord(Dg[1])-48;
 For I:=0 To 7 Do B[4+I]:=((Ord(Dg[2+I*2])-48) Shl 4) Or (Ord(Dg[3+I*2])-48);
 DecToPacked:=True;
End;

{ constante flottante pour la taille Sz (4=L 2=W 1=B : entier) ; Ok=False ->
  erreur deja signalee }
Function FpConst(Const T0: String; Sz: Integer; Var B: TFBytes; Var Len:
  Integer): Boolean;
Var T: String; E: Extended; I,N: Integer; R: TTV; V: LongInt; Want: Integer;
Begin
 FpConst:=False;
 T:=TrimS(T0);FillChar(B,SizeOf(B),0);
 If T='' Then Begin
   Err3('invalid floating point expression','Expression flottante invalide',
   'Ungueltiger Gleitkommaausdruck');Exit;End;
 Case Sz Of
  1,2,4: Begin
   { entier }
   If (Pos('.',T)>0) Or (Pos('E',Upper(T))>0) And (T[1] In ['0'..'9']) Then
     Begin
    Err3('floating point constant not allowed','Constante flottante interdite',
      'Gleitkommakonstante nicht erlaubt');Exit;
   End;
   If Not EvalStr(T,R) Then Exit;
   V:=R.V;
   If Sz=1 Then Begin Len:=1;B[0]:=V And $FF;End
   Else If Sz=2 Then Begin Len:=2;B[0]:=(V Shr 8) And $FF;B[1]:=V And $FF;End
   Else Begin Len:=4;B[0]:=ShrL(V,24) And $FF;B[1]:=ShrL(V,16) And
     $FF;B[2]:=ShrL(V,8) And $FF;B[3]:=V And $FF;End;
   FpConst:=True;Exit;
  End;
 End;
 If Sz=8 Then Want:=4 Else If Sz=16 Then Want:=8 Else Want:=12;
 { hexadecimal : : ou $ }
 If (T[1]=':') Or (T[1]='$') Then Begin
  N:=Length(T)-1;
  If (N>Want*2) Or (N=0) Then Begin
    Err3('hex floating point number too large',
    'Nombre flottant hexa trop grand','Hex-Gleitkommazahl zu gross');Exit;End;
  For I:=1 To N Do If Not IsHexCh(T[I+1]) Then Begin
    Err3('invalid floating point expression','Expression flottante invalide',
    'Ungueltiger Gleitkommaausdruck');Exit;End;
  { cadrage a droite sur la taille }
  For I:=1 To N Do Begin
   If Odd(N-I) Then B[Want-1-((N-I) Div 2)]:=B[Want-1-((N-I) Div 2)] Or
     (HexVal(T[I+1]) Shl 4)
   Else B[Want-1-((N-I) Div 2)]:=B[Want-1-((N-I) Div 2)] Or HexVal(T[I+1]);
  End;
  Len:=Want;FpConst:=True;Exit;
 End;
 If Sz=64 Then Begin
  If DecToPacked(T,B) Then Begin Len:=12;FpConst:=True;Exit;End;
  If DecToExt(T,E) Then Begin
   { depuis un symbole : repasse par un texte decimal }
   Str(E:28,T);
   For I:=Length(T) DownTo 1 Do If T[I]=' ' Then Delete(T,I,1);
   If DecToPacked(T,B) Then Begin Len:=12;FpConst:=True;Exit;End;
  End;
  Err3('invalid floating point expression','Expression flottante invalide',
    'Ungueltiger Gleitkommaausdruck');Exit;
 End;
 If Not DecToExt(T,E) Then Begin
  Err3('bad floating point expression','Expression flottante incorrecte',
    'Fehlerhafter Gleitkommaausdruck');Exit;
 End;
 If Not ExtToBytes(E,Sz,B,Len) Then Begin
  Err3('floating point constant too large','Constante flottante trop grande',
    'Gleitkommakonstante zu gross');Exit;
 End;
 FpConst:=True;
End;

{ ---------------------------------------------------------------------- }
{ Instructions                                                             }
{ ---------------------------------------------------------------------- }

Const
 FpOps1 =
   ' FMOVE=00 FINT=01 FSINH=02 FINTRZ=03 FSQ'+
   'RT=04 FLOGNP1=06 FETOXM1=08 FTANH=09 FAT'+
   'AN=0A FASIN=0C FATANH=0D FSIN=0E FTAN=0F'+' ';
 FpOps2 =
   ' FETOX=10 FTWOTOX=11 FTENTOX=12 FLOGN=14'+
   ' FLOG10=15 FLOG2=16 FABS=18 FCOSH=19 FNE'+
   'G=1A FACOS=1C FCOS=1D FGETEXP=1E FGETMAN'+'=1F ';
 FpOps3 =
   ' FDIV=20 FMOD=21 FADD=22 FMUL=23 FSGLDIV'+
   '=24 FREM=25 FSCALE=26 FSGLMUL=27 FSUB=28'+' FCMP=38 FTST=3A ';
 FpOps4 =
   ' FSMOVE=40 FDMOVE=44 FSSQRT=41 FDSQRT=45'+
   ' FSABS=58 FDABS=5C FSNEG=5A FDNEG=5E FSD'+
   'IV=60 FDDIV=64 FSADD=62 FDADD=66 FSMUL=6'+'3 FDMUL=67 FSSUB=68 FDSUB=6C ';
 FpMisc = ' FMOVEM FMOVECR FSINCOS FNOP FSAVE FRESTORE ';
 FpCondN : Array[0..31] Of String[5] =
   ('F','EQ','OGT','OGE','OLT','OLE','OGL','OR','UN','UEQ','UGT','UGE','ULT',
   'ULE','NE','T',
   'SF','SEQ','GT','GE','LT','LE','GL','GLE','NGLE','NGL','NLE','NLT','NGE',
     'NGT','SNE','ST');

Function FpOpMode(Const M: String): Integer;
 Function Find(Const L: String): Integer;
 Var Q: Integer;
 Begin
  Find:=-1;
  Q:=Pos(' '+M+'=',L);
  If Q>0 Then Find:=HexVal(L[Q+Length(M)+2])*16+HexVal(L[Q+Length(M)+3]);
 End;
Var R: Integer;
Begin
 R:=Find(FpOps1);
 If R<0 Then R:=Find(FpOps2);
 If R<0 Then R:=Find(FpOps3);
 If R<0 Then R:=Find(FpOps4);
 FpOpMode:=R;
End;

Function FpCondOf(Const N: String): Integer;
Var K: Integer;
Begin
 FpCondOf:=-1;
 For K:=0 To 31 Do If FpCondN[K]=N Then Begin FpCondOf:=K;Exit;End;
End;

Function IsFpMnemonic(Const M: String): Boolean;
Begin
 IsFpMnemonic:=False;
 If (M='') Or (M[1]<>'F') Then Exit;
 If FpOpMode(M)>=0 Then Begin IsFpMnemonic:=True;Exit;End;
 If Pos(' '+M+' ',FpMisc)>0 Then Begin IsFpMnemonic:=True;Exit;End;
 If (Copy(M,1,2)='FB') And (FpCondOf(Copy(M,3,5))>=0) Then Begin
   IsFpMnemonic:=True;Exit;End;
 If (Copy(M,1,3)='FDB') And (FpCondOf(Copy(M,4,5))>=0) Then Begin
   IsFpMnemonic:=True;Exit;End;
 If (Copy(M,1,5)='FTRAP') And (FpCondOf(Copy(M,6,5))>=0) Then Begin
   IsFpMnemonic:=True;Exit;End;
 If (Copy(M,1,2)='FS') And (FpCondOf(Copy(M,3,5))>=0) Then IsFpMnemonic:=True;
End;

{ code de format de l'operande source : L0 S1 X2 P3 W4 D5 B6 }
Function FpFmt(Sz: Integer): Integer;
Begin
 Case Sz Of
  4: FpFmt:=0; 8: FpFmt:=1; 32: FpFmt:=2; 64: FpFmt:=3; 2: FpFmt:=4; 16:
    FpFmt:=5; 1: FpFmt:=6;
 Else FpFmt:=2;
 End;
End;

Function CpBase: LongInt;
Begin
 CpBase:=$F000 Or (LongInt(AO.FpId And 7) Shl 9);
End;

{ emet une constante immediate flottante (ou entiere) de taille Sz }
Procedure PutFpImm(Var O: TOp; Sz: Integer);
Var B: TFBytes; Len,I: Integer;
Begin
 If O.FIsFloat Or (Sz>=8) Then Begin
  If Not FpConst(O.FTxt,Sz,B,Len) Then Begin BadInstr:=True;Exit;End;
 End Else Begin
  { entier : B, W, L }
  Case Sz Of
   1: Begin PutX(O.V And $FF,False,-1);Exit;End;
   2: Begin PutX(O.V And $FFFF,False,-1);Exit;End;
  Else Begin PutX(O.V,True,ImpRel(O,0,O.S));Exit;End;
  End;
 End;
 If Sz=1 Then Begin PutX(B[0],False,-1);Exit;End;
 I:=0;
 While I<Len Do Begin
  If (Len-I>=4) Then Begin PutX((LongInt(B[I]) Shl 24) Or (LongInt(B[I+1]) Shl
    16) Or (LongInt(B[I+2]) Shl 8) Or B[I+3],True,-1);Inc(I,4);End
  Else Begin PutX((LongInt(B[I]) Shl 8) Or B[I+1],False,-1);Inc(I,2);End;
 End;
End;

{ masque de modes d'adressage pour une source memoire de format Fm }
Function FpSrcMask(Fm: Integer): LongInt;
Begin
 If (Fm=0) Or (Fm=1) Or (Fm=4) Or (Fm=6) Then FpSrcMask:=MA_DATA
 Else FpSrcMask:=MA_DATA And Not KBit(OK_DN);
End;

{ cherche un registre FP dans OpStr (apres le source) et affecte le mot
  d'extension : retourne Ok }
Procedure GFpGeneral(Const M: String; Op: Integer);
Var Sz,Fm,Dst,E: Integer; Tst: Boolean; Ext: LongInt; Mono: Boolean;
Begin
 Tst:=(M='FTST');
 { operations monadiques : un seul operande autorise (dest = source) }
 Mono:=Tst Or (Op<$20) Or (M='FSSQRT') Or (M='FDSQRT') Or (M='FSABS') Or
   (M='FDABS') Or (M='FSNEG') Or (M='FDNEG');
 If (Op=$00) Or (M='FSMOVE') Or (M='FDMOVE') Then Mono:=False;
 If Mono And (NOps=1) And Not Tst Then Begin
  Ops[2]:=Ops[1];NOps:=2;
  If Ops[1].K<>OK_FPREG Then Begin
    Err3('floating-point register expected','Registre flottant attendu',
    'Gleitkommaregister erwartet');BadInstr:=True;Exit;End;
 End;
 If Tst Then Begin
  If Not NeedOps(1) Then Exit;
  Dst:=0;
 End Else Begin
  If Not NeedOps(2) Then Exit;
  If Ops[2].K<>OK_FPREG Then Begin
    Err3('floating-point register expected','Registre flottant attendu',
    'Gleitkommaregister erwartet');BadInstr:=True;Exit;End;
  Dst:=Ops[2].R;
 End;
 Sz:=LnSz;
 If Ops[1].K=OK_FPREG Then Begin
  If (Sz<>0) And (Sz<>32) Then Begin
    Err3('invalid size','Taille invalide',
    'Ungueltige Groesse');BadInstr:=True;Exit;End;
  If Tst Then Dst:=0;
  OpW:=CpBase;
  PutX((LongInt(Ops[1].R) Shl 10) Or (LongInt(Dst) Shl 7) Or Op,False,-1);
  Exit;
 End;
 If Sz=0 Then Sz:=32;
 Fm:=FpFmt(Sz);
 Ext:=$4000 Or (LongInt(Fm) Shl 10) Or (LongInt(Dst) Shl 7) Or Op;
 PutX(Ext,False,-1);
 If Ops[1].K=OK_IMM Then Begin
  PutFpImm(Ops[1],Sz);
  If BadInstr Then Exit;
  OpW:=CpBase Or 60;
  Exit;
 End;
 E:=EncEA(Ops[1],4,FpSrcMask(Fm));
 If E<0 Then Exit;
 OpW:=CpBase Or E;
End;

Procedure GFmove;
Var Sz,Fm,E: Integer; Ext: LongInt; Mk: LongInt; Sel: Integer;
Begin
 If Not NeedOps(2) Then Exit;
 Sz:=LnSz;
 { vers/depuis un registre de controle }
 If Ops[2].K=OK_FPCR Then Begin
  If (Sz<>0) And (Sz<>4) Then Begin BadSize;Exit;End;
  Sel:=Ops[2].Mask;
  If (Sel<>4) And (Sel<>2) And (Sel<>1) Then Begin
    Err3('only FPIAR allowed','Seul FPIAR permis',
    'Nur FPIAR erlaubt');BadInstr:=True;Exit;End;
  PutX($8000 Or (LongInt(Sel) Shl 10),False,-1);
  If Ops[1].K=OK_IMM Then Begin PutX(Ops[1].V,True,-1);OpW:=CpBase Or
    60;Exit;End;
  If Sel=1 Then Mk:=MA_ALL Else Mk:=MA_DATA;
  E:=EncEA(Ops[1],4,Mk);If E<0 Then Exit;
  OpW:=CpBase Or E;Exit;
 End;
 If Ops[1].K=OK_FPCR Then Begin
  If (Sz<>0) And (Sz<>4) Then Begin BadSize;Exit;End;
  Sel:=Ops[1].Mask;
  If (Sel<>4) And (Sel<>2) And (Sel<>1) Then Begin
    Err3('only FPIAR allowed','Seul FPIAR permis',
    'Nur FPIAR erlaubt');BadInstr:=True;Exit;End;
  PutX($A000 Or (LongInt(Sel) Shl 10),False,-1);
  If Sel=1 Then Mk:=MA_ALT Else Mk:=MA_DALT;
  E:=EncEA(Ops[2],4,Mk);If E<0 Then Exit;
  OpW:=CpBase Or E;Exit;
 End;
 { FMOVE FPn,<ea> : memorisation }
 If (Ops[1].K=OK_FPREG) And (Ops[2].K<>OK_FPREG) Then Begin
  If Sz=0 Then Sz:=32;
  Fm:=FpFmt(Sz);
  Ext:=$6000 Or (LongInt(Fm) Shl 10) Or (LongInt(Ops[1].R) Shl 7);
  If Fm=3 Then Begin
   If Ops[2].HasK Then Begin
    If Ops[2].KDyn Then Begin Ext:=Ext Or $1000 Or (LongInt(Ops[2].KV) Shl
      4);Ext:=(Ext And Not $1C00) Or (7 Shl 10);End
    Else Ext:=Ext Or (Ops[2].KV And $7F);
   End;
  End;
  PutX(Ext,False,-1);
  If (Fm=0) Or (Fm=1) Or (Fm=4) Or (Fm=6) Then Mk:=MA_DALT Else Mk:=MA_DALT And
    Not KBit(OK_DN);
  Mk:=Mk Or KBit(OK_PRE);
  E:=EncEA(Ops[2],4,Mk);If E<0 Then Exit;
  OpW:=CpBase Or E;Exit;
 End;
 GFpGeneral('FMOVE',0);
End;

{ liste FMOVEM : masque en ordre FP0=bit0 ; retourne l'octet pour le mode }
Function RevByte(M: Integer): Integer;
Var I,R: Integer;
Begin
 R:=0;
 For I:=0 To 7 Do If (M And (1 Shl I))<>0 Then R:=R Or (1 Shl (7-I));
 RevByte:=R;
End;

Procedure GFmovem;
Var Sz,E,Mode,Lst: Integer; Ext: LongInt; Mk: LongInt;
Begin
 If Not NeedOps(2) Then Exit;
 Sz:=LnSz;
 { registres de controle : FMOVEM.L }
 If (Ops[1].K=OK_FPCR) Or (Ops[2].K=OK_FPCR) Then Begin
  If (Sz<>0) And (Sz<>4) Then Begin BadSize;Exit;End;
  If Ops[2].K=OK_FPCR Then Begin
   PutX($8000 Or (LongInt(Ops[2].Mask) Shl 10),False,-1);
   If Ops[1].K=OK_IMM Then Begin PutX(Ops[1].V,True,-1);OpW:=CpBase Or
     60;Exit;End;
   Mk:=MA_DATA;If Ops[2].Mask=1 Then Mk:=MA_ALL;
   If (Ops[2].Mask<>4) And (Ops[2].Mask<>2) And (Ops[2].Mask<>1) Then
     Mk:=MA_CTRL Or KBit(OK_POST);
   E:=EncEA(Ops[1],4,Mk);If E<0 Then Exit;
   OpW:=CpBase Or E;
  End Else Begin
   PutX($A000 Or (LongInt(Ops[1].Mask) Shl 10),False,-1);
   Mk:=MA_ALT;
   If (Ops[1].Mask<>4) And (Ops[1].Mask<>2) And (Ops[1].Mask<>1) Then
     Mk:=MA_CALT Or KBit(OK_PRE);
   E:=EncEA(Ops[2],4,Mk);If E<0 Then Exit;
   OpW:=CpBase Or E;
  End;
  Exit;
 End;
 If (Sz<>0) And (Sz<>32) Then Begin BadSize;Exit;End;
 If (Ops[1].K=OK_FPLIST) Or (Ops[1].K=OK_FPREG) Or ((Ops[1].K=OK_DN) And
   (Ops[2].K<>OK_FPLIST) And (Ops[2].K<>OK_FPREG)) Then Begin
  { registres -> memoire }
  If Ops[2].K=OK_PRE Then Begin Mode:=0;Mk:=KBit(OK_PRE);End Else Begin
    Mode:=2;Mk:=MA_CALT;End;
  If Ops[1].K=OK_DN Then Begin
   Ext:=$E000 Or ((Mode+1) Shl 11) Or (LongInt(Ops[1].R) Shl 4);
  End Else Begin
   If Ops[1].K=OK_FPREG Then Lst:=1 Shl Ops[1].R Else Lst:=Ops[1].Mask;
   If Mode=0 Then Lst:=Lst; { predecrement : FP0 = bit 0 }
   If Mode=2 Then Lst:=RevByte(Lst);
   Ext:=$E000 Or (LongInt(Mode) Shl 11) Or Lst;
  End;
  PutX(Ext,False,-1);
  E:=EncEA(Ops[2],4,Mk);If E<0 Then Exit;
  OpW:=CpBase Or E;Exit;
 End;
 If (Ops[2].K=OK_FPLIST) Or (Ops[2].K=OK_FPREG) Or (Ops[2].K=OK_DN) Then Begin
  { memoire -> registres }
  Mode:=2;
  If Ops[2].K=OK_DN Then Ext:=$C000 Or (3 Shl 11) Or (LongInt(Ops[2].R) Shl 4)
  Else Begin
   If Ops[2].K=OK_FPREG Then Lst:=1 Shl Ops[2].R Else Lst:=Ops[2].Mask;
   Ext:=$C000 Or (2 Shl 11) Or RevByte(Lst);
  End;
  PutX(Ext,False,-1);
  E:=EncEA(Ops[1],4,MA_CTRL Or KBit(OK_POST) Or KBit(OK_PCD) Or
    KBit(OK_PCI));If E<0 Then Exit;
  OpW:=CpBase Or E;Exit;
 End;
 BadMode;
End;

Function GFpu(Const M: String): Boolean;
Var Op,Cc,E,Dst: Integer; T: String; Disp,At: LongInt; Fm: Integer;
Begin
 GFpu:=True;
 If Not IsFpMnemonic(M) Then Begin GFpu:=False;Exit;End;
 If Not NeedFPU Then Exit;
 If M='FNOP' Then Begin OpW:=CpBase Or $80;PutX(0,False,-1);Exit;End;
 If M='FMOVE' Then Begin GFmove;Exit;End;
 If M='FMOVEM' Then Begin GFmovem;Exit;End;
 If M='FMOVECR' Then Begin
  If Not NeedOps(2) Then Exit;
  If (Ops[1].K<>OK_IMM) Or (Ops[2].K<>OK_FPREG) Then Begin BadMode;Exit;End;
  OpW:=CpBase;PutX($5C00 Or (LongInt(Ops[2].R) Shl 7) Or (Ops[1].V And
    $7F),False,-1);Exit;
 End;
 If (M='FSAVE') Or (M='FRESTORE') Then Begin
  If Not NeedOps(1) Then Exit;
  If M='FSAVE' Then E:=EncEA(Ops[1],4,MA_CALT Or KBit(OK_PRE)) Else
    E:=EncEA(Ops[1],4,MA_CTRL Or KBit(OK_POST) Or KBit(OK_PCD) Or KBit(OK_PCI));
  If E<0 Then Exit;
  If M='FSAVE' Then OpW:=CpBase Or $100 Or E Else OpW:=CpBase Or $140 Or E;
  Exit;
 End;
 If M='FSINCOS' Then Begin
  If Not NeedOps(2) Then Exit;
  If Ops[2].K<>OK_FPPAIR Then Begin
    Err3('floating-point register expected','Registre flottant attendu',
    'Gleitkommaregister erwartet');BadInstr:=True;Exit;End;
  Dst:=Ops[2].XR;
  If Ops[1].K=OK_FPREG Then Begin OpW:=CpBase;PutX((LongInt(Ops[1].R) Shl 10)
    Or (LongInt(Dst) Shl 7) Or $30 Or Ops[2].R,False,-1);Exit;End;
  Fm:=FpFmt(LnSz);If LnSz=0 Then Fm:=2;
  PutX($4000 Or (LongInt(Fm) Shl 10) Or (LongInt(Dst) Shl 7) Or $30 Or
    Ops[2].R,False,-1);
  If Ops[1].K=OK_IMM Then Begin If LnSz=0 Then
    LnSz:=32;PutFpImm(Ops[1],LnSz);OpW:=CpBase Or 60;Exit;End;
  E:=EncEA(Ops[1],4,FpSrcMask(Fm));If E<0 Then Exit;
  OpW:=CpBase Or E;Exit;
 End;
 Op:=FpOpMode(M);
 If Op>=0 Then Begin GFpGeneral(M,Op);Exit;End;
 { FBcc }
 If Copy(M,1,2)='FB' Then Begin
  Cc:=FpCondOf(Copy(M,3,5));
  If Not NeedOps(1) Then Exit;
  If (Ops[1].K<>OK_ABSL) And (Ops[1].K<>OK_ABSW) Then Begin BadMode;Exit;End;
  Disp:=ImgOf(Ops[1].V,Ops[1].S)-(InstrPC+2);
  If LnSz=4 Then Begin OpW:=CpBase Or $C0 Or Cc;PutX(Disp,True,-1);End
  Else Begin
   If (AsmPassNo=2) And Not Ops[1].U And ((Disp<-32768) Or (Disp>32767)) Then
     Err3('data too large','Branchement hors limites',
     'Sprung ausserhalb des Bereichs');
   OpW:=CpBase Or $80 Or Cc;PutX(Disp And $FFFF,False,-1);
  End;
  Exit;
 End;
 If Copy(M,1,3)='FDB' Then Begin
  Cc:=FpCondOf(Copy(M,4,5));
  If Not NeedOps(2) Then Exit;
  If (Ops[1].K<>OK_DN) Or ((Ops[2].K<>OK_ABSL) And (Ops[2].K<>OK_ABSW)) Then
    Begin BadMode;Exit;End;
  PutX(Cc,False,-1);
  Disp:=ImgOf(Ops[2].V,Ops[2].S)-(InstrPC+4);
  OpW:=CpBase Or $48 Or Ops[1].R;
  PutX(Disp And $FFFF,False,-1);
  Exit;
 End;
 If Copy(M,1,5)='FTRAP' Then Begin
  Cc:=FpCondOf(Copy(M,6,5));
  PutX(Cc,False,-1);
  If NOps=0 Then OpW:=CpBase Or $7C
  Else Begin
   If Ops[1].K<>OK_IMM Then Begin BadMode;Exit;End;
   If LnSz=4 Then Begin OpW:=CpBase Or $7B;PutImm(Ops[1],4);End Else Begin
     OpW:=CpBase Or $7A;PutImm(Ops[1],2);End;
  End;
  Exit;
 End;
 If Copy(M,1,2)='FS' Then Begin
  Cc:=FpCondOf(Copy(M,3,5));
  If Not NeedOps(1) Then Exit;
  PutX(Cc,False,-1);
  E:=EncEA(Ops[1],1,MA_DALT);If E<0 Then Exit;
  OpW:=CpBase Or $40 Or E;
  Exit;
 End;
 GFpu:=False;
End;

{ ---------------------------------------------------------------------- }
{ MMU 68851 / 68030 / 68040                                                }
{ ---------------------------------------------------------------------- }

Const
 MmuCondN : Array[0..15] Of String[2] =
   ('BS','BC','LS','LC','SS','SC','AS','AC','WS','WC','IS','IC','GS','GC','CS',
   'CC');
 MmuList =
   ' PMOVE PMOVEFD PFLUSH PFLUSHS PFLUSHA PF'+
   'LUSHR PFLUSHN PFLUSHAN PLOADR PLOADW PTE'+
   'STR PTESTW PVALID PSAVE PRESTORE ';

Function MmuCondOf(Const N: String): Integer;
Var K: Integer;
Begin
 MmuCondOf:=-1;
 For K:=0 To 15 Do If MmuCondN[K]=N Then MmuCondOf:=K;
End;

Function IsMmuMnemonic(Const M: String): Boolean;
Begin
 IsMmuMnemonic:=False;
 If (M='') Or (M[1]<>'P') Then Exit;
 If Pos(' '+M+' ',MmuList)>0 Then Begin IsMmuMnemonic:=True;Exit;End;
 If (Copy(M,1,2)='PB') And (MmuCondOf(Copy(M,3,2))>=0) Then IsMmuMnemonic:=True
 Else If (Copy(M,1,3)='PDB') And (MmuCondOf(Copy(M,4,2))>=0) Then
   IsMmuMnemonic:=True
 Else If (Copy(M,1,5)='PTRAP') And (MmuCondOf(Copy(M,6,2))>=0) Then
   IsMmuMnemonic:=True
 Else If (Copy(M,1,2)='PS') And (M<>'PSAVE') And (MmuCondOf(Copy(M,3,2))>=0)
   Then IsMmuMnemonic:=True;
End;

Procedure MmuWrong;
Begin
 Err3('wrong processor','Mauvais processeur',
   'Falscher Prozessor');BadInstr:=True;
End;

Function Has851: Boolean;
Begin
 Has851:=AO.MMU;
End;

Function Has030Mmu: Boolean;
Begin
 Has030Mmu:=AO.MMU Or (AO.Proc=68030);
End;

{ code de fonction : 0 SFC, 1 DFC, 8+n Dn, 16+n immediat ; -1 + erreur }
Function MmuFc(Const S0: String): Integer;
Var S,U: String; R: Integer; V: TTV;
Begin
 MmuFc:=-1;
 S:=TrimS(S0);U:=Upper(S);
 If U='SFC' Then Begin MmuFc:=0;Exit;End;
 If U='DFC' Then Begin MmuFc:=1;Exit;End;
 R:=RegOf(U);
 If (R>=0) And (R<8) Then Begin MmuFc:=8+R;Exit;End;
 If (S<>'') And (S[1]='#') Then Begin
  If EvalStr(Copy(S,2,40),V) Then
   If (V.V>=0) And (V.V<=15) Then Begin MmuFc:=16+V.V;Exit;End;
 End;
 Err3('invalid MMU function code','Code de fonction MMU invalide',
   'Ungueltiger MMU-Funktionscode');BadInstr:=True;
End;

Function MmuImm(Const S0: String; Lo,Hi: Integer): Integer;
Var S: String; V: TTV;
Begin
 MmuImm:=-1;S:=TrimS(S0);
 If (S<>'') And (S[1]='#') And EvalStr(Copy(S,2,40),V) And (V.V>=Lo) And
   (V.V<=Hi) Then MmuImm:=V.V
 Else Begin
   Err3('data too large','Valeur hors limites',
   'Wert ausserhalb des Bereichs');BadInstr:=True;End;
End;

{ registre MMU : retourne l'octet haut + champs (mot d'extension sans R/W/FD)
  ou -1 }
Function MmuRegExt(Const U: String): LongInt;
Var N: Integer;
Begin
 MmuRegExt:=-1;
 If U='TC' Then MmuRegExt:=$4000
 Else If U='DRP' Then MmuRegExt:=$4400
 Else If U='SRP' Then MmuRegExt:=$4800
 Else If U='CRP' Then MmuRegExt:=$4C00
 Else If U='CAL' Then MmuRegExt:=$5000
 Else If U='VAL' Then MmuRegExt:=$5400
 Else If U='SCC' Then MmuRegExt:=$5800
 Else If U='AC' Then MmuRegExt:=$5C00
 Else If (U='PSR') Or (U='MMUSR') Then MmuRegExt:=$6000
 Else If U='PCSR' Then MmuRegExt:=$6400
 Else If U='TT0' Then MmuRegExt:=$0800
 Else If U='TT1' Then MmuRegExt:=$0C00
 Else If (Length(U)=4) And (Copy(U,1,3)='BAD') And (U[4]>='0') And (U[4]<='7')
   Then MmuRegExt:=$7000 Or (LongInt(Ord(U[4])-48) Shl 2)
 Else If (Length(U)=4) And (Copy(U,1,3)='BAC') And (U[4]>='0') And (U[4]<='7')
   Then MmuRegExt:=$7400 Or (LongInt(Ord(U[4])-48) Shl 2);
End;

Procedure GMmu(Const M: String);
Var A: Array[1..4] Of String; I,N,E,Cc,Fc,Msk,Lv,An,Mode: Integer; Ext,Disp:
  LongInt; Rx: LongInt; Wr,Fd: Boolean;
    U1,U2: String; O1,O2: TOp; Reg: Integer;

 Function IndAn(Const S: String): Integer;
 Var U: String;
 Begin
  U:=Upper(TrimS(S));IndAn:=-1;
  If (Length(U)=4) And (U[1]='(') And (U[4]=')') And (U[2]='A') And (U[3]>='0')
    And (U[3]<='7') Then IndAn:=Ord(U[3])-48;
 End;

Begin
 N:=NOps;
 For I:=1 To 4 Do If I<=N Then A[I]:=OpStr[I] Else A[I]:='';
 { 68040 : PFLUSH (An), PFLUSHN, PFLUSHA, PFLUSHAN, PTESTR/W (An) }
 If (AO.Proc>=68040) And ((M='PFLUSH') Or (M='PFLUSHN') Or (M='PFLUSHA') Or
   (M='PFLUSHAN') Or (M='PTESTR') Or (M='PTESTW')) Then Begin
  If (M='PFLUSHA') Or (M='PFLUSHAN') Then Begin
   If N<>0 Then Begin NeedOps(0);Exit;End;
   If M='PFLUSHA' Then OpW:=$F518 Else OpW:=$F510;Exit;
  End;
  If N<>1 Then Begin NeedOps(1);Exit;End;
  An:=IndAn(A[1]);
  If An<0 Then Begin
    Err3('only (An) allowed for this instruction',
    'Seul (An) permis pour cette instruction',
    'Nur (An) erlaubt fuer diesen Befehl');BadInstr:=True;Exit;End;
  If M='PFLUSH' Then OpW:=$F508 Else If M='PFLUSHN' Then OpW:=$F500 Else If
    M='PTESTR' Then OpW:=$F568 Else OpW:=$F548;
  OpW:=OpW Or An;Exit;
 End;
 If (M='PFLUSHN') Or (M='PFLUSHAN') Then Begin MmuWrong;Exit;End;
 If (M='PMOVE') Or (M='PMOVEFD') Then Begin
  If Not Has030Mmu Then Begin MmuWrong;Exit;End;
  If N<>2 Then Begin NeedOps(2);Exit;End;
  U1:=Upper(TrimS(A[1]));U2:=Upper(TrimS(A[2]));
  Fd:=M='PMOVEFD';
  Rx:=MmuRegExt(U2);
  If Rx>=0 Then Begin Wr:=False;Reg:=1;End
  Else Begin Rx:=MmuRegExt(U1);Wr:=True;Reg:=0;End;
  If Rx<0 Then Begin
    Err3('MMU register expected','Registre MMU attendu',
    'MMU-Register erwartet');BadInstr:=True;Exit;End;
  If (Not AO.MMU) And ((Rx=$4400) Or (Rx=$5000) Or (Rx=$5400) Or (Rx=$5800) Or
    (Rx=$5C00) Or (Rx=$6400) Or (Rx>=$7000)) Then Begin MmuWrong;Exit;End;
  If (Rx=$0800) Or (Rx=$0C00) Then Begin If AO.Proc<>68030 Then Begin
    MmuWrong;Exit;End;End;
  Ext:=Rx;
  If Wr Then Ext:=Ext Or $200;
  If Fd Then Ext:=Ext Or $100;
  PutX(Ext,False,-1);
  If Wr Then Begin ParseOp(A[2],O2);If BadInstr Then Exit;E:=EncEA(O2,4,MA_ALT
    And Not KBit(OK_DN));End
  Else Begin ParseOp(A[1],O1);If BadInstr Then Exit;E:=EncEA(O1,4,MA_ALL And
    Not KBit(OK_AN) And Not KBit(OK_DN));End;
  If E<0 Then Exit;
  OpW:=$F000 Or E;Exit;
 End;
 If (M='PFLUSHA') Or (M='PFLUSH') Or (M='PFLUSHS') Then Begin
  If Not Has030Mmu Then Begin MmuWrong;Exit;End;
  If (M='PFLUSHS') And Not AO.MMU Then Begin MmuWrong;Exit;End;
  If M='PFLUSHA' Then Begin If N<>0 Then Begin
    NeedOps(0);Exit;End;OpW:=$F000;PutX($2400,False,-1);Exit;End;
  If (N<>2) And (N<>3) Then Begin NeedOps(2);Exit;End;
  Fc:=MmuFc(A[1]);If Fc<0 Then Exit;
  Msk:=MmuImm(A[2],0,15);If Msk<0 Then Exit;
  Ext:=$3000 Or (LongInt(Msk) Shl 5) Or Fc;
  If N=3 Then Ext:=Ext Or $800;
  If M='PFLUSHS' Then Ext:=Ext Or $400;
  PutX(Ext,False,-1);
  If N=3 Then Begin ParseOp(A[3],O1);If BadInstr Then
    Exit;E:=EncEA(O1,4,MA_CTRL);If E<0 Then Exit;OpW:=$F000 Or E;End
  Else OpW:=$F000;
  Exit;
 End;
 If M='PFLUSHR' Then Begin
  If Not AO.MMU Then Begin MmuWrong;Exit;End;
  If N<>1 Then Begin NeedOps(1);Exit;End;
  PutX($A000,False,-1);
  ParseOp(A[1],O1);If BadInstr Then Exit;E:=EncEA(O1,8,MA_ALL And Not
    KBit(OK_DN) And Not KBit(OK_AN));If E<0 Then Exit;OpW:=$F000 Or E;Exit;
 End;
 If (M='PLOADR') Or (M='PLOADW') Then Begin
  If Not Has030Mmu Then Begin MmuWrong;Exit;End;
  If N<>2 Then Begin NeedOps(2);Exit;End;
  Fc:=MmuFc(A[1]);If Fc<0 Then Exit;
  Ext:=$2000 Or Fc;If M='PLOADR' Then Ext:=Ext Or $200;
  PutX(Ext,False,-1);
  ParseOp(A[2],O1);If BadInstr Then Exit;E:=EncEA(O1,4,MA_CTRL);If E<0 Then
    Exit;OpW:=$F000 Or E;Exit;
 End;
 If (M='PTESTR') Or (M='PTESTW') Then Begin
  If Not Has030Mmu Then Begin MmuWrong;Exit;End;
  If (N<>3) And (N<>4) Then Begin NeedOps(3);Exit;End;
  Fc:=MmuFc(A[1]);If Fc<0 Then Exit;
  Lv:=MmuImm(A[3],0,7);If Lv<0 Then Exit;
  Ext:=$8000 Or (LongInt(Lv) Shl 10) Or Fc;
  If M='PTESTR' Then Ext:=Ext Or $200;
  If N=4 Then Begin
   An:=RegOf(Upper(TrimS(A[4])));
   If (An<8) Or (An>15) Then Begin
     Err3('address register expected','Registre d''adresse attendu',
     'Adressregister erwartet');BadInstr:=True;Exit;End;
   Ext:=Ext Or $100 Or (LongInt(An-8) Shl 5);
  End;
  PutX(Ext,False,-1);
  ParseOp(A[2],O1);If BadInstr Then Exit;E:=EncEA(O1,4,MA_CTRL);If E<0 Then
    Exit;OpW:=$F000 Or E;Exit;
 End;
 If M='PVALID' Then Begin
  If Not AO.MMU Then Begin MmuWrong;Exit;End;
  If N<>2 Then Begin NeedOps(2);Exit;End;
  U1:=Upper(TrimS(A[1]));
  If U1='VAL' Then Ext:=$2800
  Else Begin
   An:=RegOf(U1);
   If (An<8) Or (An>15) Then Begin
     Err3('MMU register expected','Registre MMU attendu',
     'MMU-Register erwartet');BadInstr:=True;Exit;End;
   Ext:=$2C00 Or (An-8);
  End;
  PutX(Ext,False,-1);
  ParseOp(A[2],O1);If BadInstr Then Exit;E:=EncEA(O1,4,MA_CTRL);If E<0 Then
    Exit;OpW:=$F000 Or E;Exit;
 End;
 If (M='PSAVE') Or (M='PRESTORE') Then Begin
  If Not AO.MMU Then Begin MmuWrong;Exit;End;
  If N<>1 Then Begin NeedOps(1);Exit;End;
  ParseOp(A[1],O1);If BadInstr Then Exit;
  If M='PSAVE' Then Begin E:=EncEA(O1,4,MA_CALT Or KBit(OK_PRE));If E<0 Then
    Exit;OpW:=$F100 Or E;End
  Else Begin E:=EncEA(O1,4,MA_CTRL Or KBit(OK_POST));If E<0 Then
    Exit;OpW:=$F140 Or E;End;
  Exit;
 End;
 { conditionnels 68851 }
 If Not AO.MMU Then Begin MmuWrong;Exit;End;
 If Copy(M,1,2)='PB' Then Begin
  Cc:=MmuCondOf(Copy(M,3,2));
  If N<>1 Then Begin NeedOps(1);Exit;End;
  ParseOp(A[1],O1);If BadInstr Then Exit;
  Disp:=ImgOf(O1.V,O1.S)-(InstrPC+2);
  If LnSz=4 Then Begin OpW:=$F0C0 Or Cc;PutX(Disp,True,-1);End Else Begin
    OpW:=$F080 Or Cc;PutX(Disp And $FFFF,False,-1);End;
  Exit;
 End;
 If Copy(M,1,3)='PDB' Then Begin
  Cc:=MmuCondOf(Copy(M,4,2));
  If N<>2 Then Begin NeedOps(2);Exit;End;
  ParseOp(A[1],O1);ParseOp(A[2],O2);If BadInstr Then Exit;
  If O1.K<>OK_DN Then Begin BadMode;Exit;End;
  PutX(Cc,False,-1);
  Disp:=ImgOf(O2.V,O2.S)-(InstrPC+4);
  OpW:=$F048 Or O1.R;PutX(Disp And $FFFF,False,-1);Exit;
 End;
 If Copy(M,1,5)='PTRAP' Then Begin
  Cc:=MmuCondOf(Copy(M,6,2));
  PutX(Cc,False,-1);
  If N=0 Then OpW:=$F07C
  Else Begin
   ParseOp(A[1],O1);If BadInstr Then Exit;
   If O1.K<>OK_IMM Then Begin BadMode;Exit;End;
   If LnSz=4 Then Begin OpW:=$F07B;PutImm(O1,4);End Else Begin
     OpW:=$F07A;PutImm(O1,2);End;
  End;
  Exit;
 End;
 Cc:=MmuCondOf(Copy(M,3,2));
 If N<>1 Then Begin NeedOps(1);Exit;End;
 PutX(Cc,False,-1);
 ParseOp(A[1],O1);If BadInstr Then Exit;
 E:=EncEA(O1,1,MA_DALT);If E<0 Then Exit;
 OpW:=$F040 Or E;
End;

Const
 MnList1 =
   ' NOP RTS RTE RTR RESET TRAPV ILLEGAL CLR'+
   ' NEG NEGX NOT TST JMP JSR PEA TAS NBCD A'+'DD SUB AND OR EOR CMP '+
  'ADDI SUBI ANDI ORI EORI CMPI ADDA SUBA C'+
    'MPA ADDQ SUBQ ADDX SUBX ABCD SBCD CMPM M'+
    'ULU MULS DIVU DIVS CHK DIVUL DIVSL ';
 MnList2 =
   ' MOVE MOVEA MOVEQ MOVEM MOVEP ASL ASR LS'+
   'L LSR ROL ROR ROXL ROXR BTST BCHG BCLR B'+'SET '+
  'LEA LINK UNLK SWAP EXT EXG TRAP STOP DBRA ';
 MnList3 =
   ' CALLM RTM EXTB RTD BKPT MOVEC MOVES BFT'+
   'ST BFCHG BFCLR BFSET BFEXTU BFEXTS BFFFO'+
   ' BFINS CAS CAS2 CHK2 CMP2 PACK UNPK '+
  'MOVE16 CINVL CINVP CINVA CPUSHL CPUSHP CPUSHA ';

Function IsMnemonic(Const M: String): Boolean;
Begin
 IsMnemonic:=True;
 If Pos(' '+M+' ',MnList1)>0 Then Exit;
 If Pos(' '+M+' ',MnList2)>0 Then Exit;
 If Pos(' '+M+' ',MnList3)>0 Then Exit;
 If IsFpMnemonic(M) Then Exit;
 If IsMmuMnemonic(M) Then Exit;
 If (Length(M)>=3) And (M[1]='B') And (CondCode(Copy(M,2,2))>=0) Then Exit;
 If M='BRA' Then Exit;
 If M='BSR' Then Exit;
 If (Length(M)>=5) And (Copy(M,1,4)='TRAP') And (M<>'TRAPV') And
   (CondCode(Copy(M,5,2))>=0) Then Exit;
 If (Length(M)>=3) And (Length(M)<=4) And (Copy(M,1,2)='DB') And
   (CondCode(Copy(M,3,2))>=0) Then Exit;
 If (Length(M)>=2) And (Length(M)<=3) And (M[1]='S') And
   (CondCode(Copy(M,2,2))>=0) Then Exit;
 IsMnemonic:=False;
End;

{ tailles permises : 1 B, 2 W, 4 L, 8 S ; 0 = pas de verification }
Function SizeMask(Const M: String): Integer;
Begin
 SizeMask:=15;
 If IsFpMnemonic(M) Or IsMmuMnemonic(M) Then Begin SizeMask:=127;Exit;End;
 { table relevee sur le vrai GenST 2.23 : B=1 W=2 L=4 S=8 }
 If (M='STOP') Or (M='TRAP') Or (M='JMP') Or (M='JSR') Or (M='UNLK') Then
   SizeMask:=0
 Else If M='LINK' Then Begin If AO.Proc>=68020 Then SizeMask:=4 Else
   SizeMask:=0;End
 Else If (M='PEA') Or (M='LEA') Or (M='EXG') Or (M='EXTB') Then SizeMask:=4
 Else If (M='ADDA') Or (M='SUBA') Or (M='CMPA') Or (M='MOVEA') Or (M='MOVEM')
   Or (M='MOVEP') Or (M='EXT') Then SizeMask:=6
 Else If M='SWAP' Then SizeMask:=2
 Else If (M='MULU') Or (M='MULS') Or (M='DIVU') Or (M='DIVS') Or (M='CHK') Then
   SizeMask:=6
 Else If (M='DIVUL') Or (M='DIVSL') Then SizeMask:=4
 Else If (M='NBCD') Or (M='TAS') Or (M='ABCD') Or (M='SBCD') Then SizeMask:=9
 Else If (M='BTST') Or (M='BCHG') Or (M='BCLR') Or (M='BSET') Then SizeMask:=4
 Else If (M='DBRA') Or ((Length(M)>=3) And (Length(M)<=4) And
   (Copy(M,1,2)='DB') And (CondCode(Copy(M,3,2))>=0)) Then SizeMask:=2
 Else If (Length(M)>=2) And (Length(M)<=3) And (M[1]='S') And (M<>'SUB') And
   (M<>'STOP') And (M<>'SWAP') And
         (M<>'SBCD') And (CondCode(Copy(M,2,2))>=0) Then SizeMask:=9
 Else If (Length(M)>=5) And (Copy(M,1,4)='TRAP') And (M<>'TRAPV') And
   (M<>'TRAP') Then SizeMask:=6;
End;

{ OPT CHKIMM : un absolu a la place d'un immediat ? }
Procedure CheckImmMissing(Const M: String);
Begin
 If Not AO.ChkImm Or (NOps<>2) Then Exit;
 If Not ((M='ADD') Or (M='SUB') Or (M='AND') Or (M='OR') Or (M='CMP') Or
   (M='ADDX') Or (M='SUBX')) Then Exit;
 If (Ops[2].K<>OK_DN) And (Ops[2].K<>OK_AN) Then Exit;
 If (Ops[1].K<>OK_ABSL) Or (Ops[1].Sz<>0) Or (Ops[1].S>=0) Or Ops[1].U Then
   Exit;
 If (Ops[1].V<-128) Or (Ops[1].V>255) Then Exit;
 Err3('# probably missing','# probablement manquant',
   '# wahrscheinlich vergessen');
 BadInstr:=True;
End;

{ O2 : 0(An) -> (An) ; O3 : absolu long -> absolu court }
Procedure OptOperands(Const M: String);
Var I: Integer;
Begin
 If IsBranchM(M) Or (M='MOVEP') Then Exit;
 For I:=1 To NOps Do Begin
  If AO.Opt[2] And (Ops[I].K=OK_DISP) Then
   If OptDecide(KnownAbs(Ops[I],0,0)) Then Begin
    Ops[I].K:=OK_IND;OptStat(2);WarnOpt(2,'offset removed');
   End;
  If AO.Opt[3] And (Ops[I].K=OK_ABSL) And (Ops[I].Sz=0) Then
   If OptDecide(KnownAbs(Ops[I],-32768,32767)) Then Begin
    Ops[I].K:=OK_ABSW;OptStat(2);WarnOpt(3,'short word addressing used');
   End;
 End;
End;

{ OPT USER : instructions privilegiees refusees }
Procedure CheckPrivileged(Const M: String);
Var Priv: Boolean; I: Integer;
Begin
 If Not AO.User Then Exit;
 Priv:=(M='RESET') Or (M='RTE') Or (M='STOP');
 For I:=1 To NOps Do
  If (Ops[I].K=OK_USP) Or ((Ops[I].K=OK_SR) And (I=NOps) And (M<>'MOVE')) Or
     ((Ops[I].K=OK_SR) And (I=2) And (M='MOVE')) Then Priv:=True;
 If (M='MOVE') And (NOps=2) And (Ops[1].K=OK_SR) And (AO.Proc>=68010) Then
   Priv:=True;
 If Priv Then Begin
  Err3('privileged instruction','Instruction privilegiee',
    'Privilegierter Befehl');
  BadInstr:=True;
 End;
End;

{ OPT AUTOPC : les absolus relatifs au texte deviennent PC-relatifs }
Procedure AutoPCConv(Const M: String);
Var I,Last: Integer;
Begin
 If Not AO.AutoPC Or AbsMode Or (CurSect<>SEC_TEXT) Then Exit;
 Last:=0;
 If NOps=2 Then Last:=1
 Else If (NOps=1) And ((M='JMP') Or (M='JSR') Or (M='PEA')) Then Last:=1;
 If (M='LEA') Or (M='MOVEA') Then Last:=1;
 If (M='MOVEM') And (NOps=2) And (Ops[1].K<>OK_LIST) And (Ops[1].K<>OK_DN) And
   (Ops[1].K<>OK_AN) Then Last:=1;
 For I:=1 To Last Do
  If ((Ops[I].K=OK_ABSL) Or (Ops[I].K=OK_ABSW)) And (Ops[I].Sz=0) And
    (Ops[I].S=SEC_TEXT) Then
   Ops[I].K:=OK_PCD;
End;

{ Assemble l'instruction courante : M est le mnemonique en majuscules }
Function AsmInstruction(Const M: String): Boolean;
Var I,N: Integer; Parts: Array[0..4] Of String;
Begin
 AsmInstruction:=True;
 If Not IsMnemonic(M) Then Begin AsmInstruction:=False;Exit;End;
 BadInstr:=False;XN:=0;XWords:=0;OpW:=0;
 NOps:=0;FPParse:=IsFpMnemonic(M);
 If (M='NOP') Or (M='RTS') Or (M='RTE') Or (M='RTR') Or (M='RESET') Or
   (M='TRAPV') Or (M='ILLEGAL') Then LnArgs:='';
 EvenSkip:=(M='LEA') Or (M='PEA');
 If LnArgs<>'' Then Begin
  N:=SplitTop(LnArgs,Parts,5);
  If N>4 Then Begin
   Err3('garbage following instruction','Trop d''operandes',
     'Zu viele Operanden');
   BadInstr:=True;N:=4;
  End;
  For I:=1 To N Do Begin
   OpStr[I]:=Parts[I-1];
   NOps:=N;
  End;
 End;
 If (LnSz<>0) And ((SizeMask(M) And LnSz)=0) Then Begin
  Err3('invalid size','Taille illegale','Illegale Groesse');
  BadInstr:=True;
 End;
 If Odd(CurPC) Then ReserveBytes(1);
 InstrOff:=SecLen[CurSect];
 If AbsMode Then InstrOff:=SecLen[0];
 InstrPC:=ImgOf(InstrOff,CurSect);
 If AbsMode Then InstrPC:=OrgAddr+SecLen[0];
 If IsMmuMnemonic(M) Then Begin
  GMmu(M);
  If Not BadInstr Then FlushInstr;
  Exit;
 End;
 If (M='MOVEC') Or (M='CAS2') Or (M='MOVE16') Or (Copy(M,1,4)='CINV') Or
   (Copy(M,1,5)='CPUSH') Then Begin
  If M='MOVE16' Then For I:=1 To NOps Do ParseOp(OpStr[I],Ops[I]);
  If ((Copy(M,1,4)='CINV') Or (Copy(M,1,5)='CPUSH')) And (NOps=2) Then
    ParseOp(OpStr[2],Ops[2]);
  If BadInstr Then Begin AsmInstruction:=True;Exit;End;
  If M='MOVEC' Then GMovec Else If M='CAS2' Then GCas2 Else If M='MOVE16' Then
    GMove16 Else GExt(M);
  FlushInstr;Exit;
 End;
 For I:=1 To NOps Do ParseOp(OpStr[I],Ops[I]);
 If BadInstr Then Begin AsmInstruction:=True;Exit;End;
 If AO.Opt[2] Or AO.Opt[3] Then OptOperands(M);
 CheckImmMissing(M);
 If BadInstr Then Begin AsmInstruction:=True;Exit;End;
 CheckPrivileged(M);
 If BadInstr Then Begin AsmInstruction:=True;Exit;End;
 AutoPCConv(M);
 If GImplied(M) Or GUnary(M) Or GArith(M) Or GMove(M) Or GShift(M) Or
    GBit(M) Or GBranch(M) Or GMisc(M) Or GExt(M) Or GFpu(M) Then Begin
  FlushInstr;
 End Else AsmInstruction:=False;
End;

{ ---------------------------------------------------------------------- }
{ Chargement de fichiers texte                                            }
{ ---------------------------------------------------------------------- }

Var
 LongLines : LongInt;       { lignes tronquees a 255 caracteres }

Type
 TMemFileHook = Function(Const Name: String; Var Arr: PLineArr; Var Count:
   LongInt): Boolean;
Var
 MemFileHook : TMemFileHook;   { editeur : fournit le texte d'un include ouvert
   dans une fenetre }

Function LoadLines(Const Name: String; Var Arr: PLineArr; Var Count: Integer):
  Boolean;
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
 If Cur<>'' Then If Count<MAXLN Then Begin
   Inc(Count);Arr^[Count]:=NewStr(Cur);End;
 Close(F);
 LoadLines:=True;
End;

{ Version de l'assembleur : nombre de lignes illimite (tableau extensible) }
Function LoadLinesBig(Const Name: String; Var Arr: PLineArr; Var Count:
  LongInt): Boolean;
Var F: File; Buf: Array[0..4095] Of Byte; I: Integer; Cur: String;
    Got: Word; LastCR: Boolean; Cap: LongInt; Trunc: Boolean;

 Procedure AddL;
 Var NA: PLineArr;
 Begin
  If Count>=Cap Then Begin
   GetMem(NA,Cap*2*SizeOf(PString)+8);
   Move(Arr^,NA^,Cap*SizeOf(PString));
   FreeMem(Arr,Cap*SizeOf(PString)+8);
   Arr:=NA;Cap:=Cap*2;
  End;
  Inc(Count);Arr^[Count]:=NewStr(Cur);
  Cur:='';
 End;

Begin
 LoadLinesBig:=False;
 Count:=0;
 If Assigned(MemFileHook) Then
  If MemFileHook(Name,Arr,Count) Then Begin LoadLinesBig:=True;Exit;End;
 Assign(F,Name);
 {$I-}
 Reset(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 Cap:=2048;
 GetMem(Arr,Cap*SizeOf(PString)+8);
 Cur:='';LastCR:=False;Trunc:=False;
 Repeat
  BlockRead(F,Buf,SizeOf(Buf),Got);
  For I:=0 To Got-1 Do Begin
   If Buf[I]=13 Then Begin
    AddL;Trunc:=False;LastCR:=True;
   End Else If Buf[I]=10 Then Begin
    If Not LastCR Then Begin AddL;Trunc:=False;End;
    LastCR:=False;
   End Else Begin
    LastCR:=False;
    If Buf[I]=26 Then Begin End
    Else If Length(Cur)<255 Then Cur:=Cur+Chr(Buf[I])
    Else If Not Trunc Then Begin Trunc:=True;Inc(LongLines);End;
   End;
  End;
 Until Got=0;
 If Cur<>'' Then AddL;
 Close(F);
 LoadLinesBig:=True;
End;

Procedure FreeLines(Arr: PLineArr; Count: Integer);
Var I: Integer;
Begin
 If Arr=Nil Then Exit;
 For I:=1 To Count Do FreeStr(Arr^[I]);
 Dispose(Arr);
End;

Procedure FreeLinesBig(Arr: PLineArr; Count: LongInt);
Var I: LongInt;
Begin
 If Arr=Nil Then Exit;
 For I:=1 To Count Do FreeStr(Arr^[I]);
 Dispose(Arr);
End;

{ ---------------------------------------------------------------------- }
{ Pile des sources                                                        }
{ ---------------------------------------------------------------------- }

Procedure PushSrc(K: Integer; Lines: PLineArr; Count: LongInt; Const Name:
  String; Own: Boolean);
Begin
 If SrcTop>=MAXSRC Then Begin
  If K=1 Then
    FatalErr3('INTERNAL:macro memory','INTERNAL:macro memory',
    'INTERNAL:macro memory')
  Else
    Err3('Includes nested too deeply','Imbrications trop profondes',
    'Zu tiefe Verschachtelung');
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
 If Srcs[SrcTop].Own Then FreeLinesBig(Srcs[SrcTop].Lines,Srcs[SrcTop].Count);
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
   If (Cur<>'') And (Upper(TrimS(Cur))=Upper(Nm)) Then Begin
     ParamIndex:=K;Exit;End;
   Cur:='';
  End Else Cur:=Cur+Names[I];
 End;
End;

{ index de parametre : 1-9, A-Z, a-z (10..35), -1 sinon }
Function ParamOfChar(C: Char): Integer;
Begin
 ParamOfChar:=-1;
 If (C>='1') And (C<='9') Then ParamOfChar:=Ord(C)-48
 Else If (C>='A') And (C<='Z') Then ParamOfChar:=Ord(C)-55
 Else If (C>='a') And (C<='z') Then ParamOfChar:=Ord(C)-87;
End;

Function HexMin(V: LongInt): String;
Var S: String;
Begin
 S:=HexN(V,8);
 While (Length(S)>1) And (S[1]='0') Do Delete(S,1,1);
 HexMin:=S;
End;

Function PadZero(N: LongInt; W: Integer): String;
Var S: String;
Begin
 S:=IntStr(N);
 While Length(S)<W Do S:='0'+S;
 PadZero:=S;
End;

Function SubstMacro(Const S: String; Var T: TSrc): String;
Var R,Nm: String; I,K,J: Integer; C: Char; P: PSym; V: LongInt; Hx: Boolean;
Begin
 If Pos('\',S)=0 Then Begin SubstMacro:=S;Exit;End;
 R:='';I:=1;
 While I<=Length(S) Do Begin
  If (S[I]='\') And (I<Length(S)) Then Begin
   C:=S[I+1];
   If C='0' Then Begin
    If T.Suffix='' Then R:=R+'W' Else R:=R+T.Suffix;
    Inc(I,2);
   End Else If C='@' Then Begin
    R:=R+'_'+PadZero(T.MacId,3);
    Inc(I,2);
   End Else If C='#' Then Begin
    R:=R+IntStr(T.NArg);
    Inc(I,2);
   End Else If C='\' Then Begin
    R:=R+'\';
    Inc(I,2);
   End Else If (C='?') And (I+2<=Length(S)) Then Begin
    K:=ParamOfChar(S[I+2]);
    If K>0 Then R:=R+IntStr(Length(T.Args[K])) Else R:=R+'0';
    Inc(I,3);
   End Else If C='<' Then Begin
    J:=I+2;Nm:='';
    While (J<=Length(S)) And (S[J]<>'>') Do Begin Nm:=Nm+S[J];Inc(J);End;
    Hx:=False;
    If (Nm<>'') And (Nm[1]='$') Then Begin Hx:=True;Delete(Nm,1,1);End;
    P:=FindSym(LocalName(Nm));
    If (P<>Nil) And P^.Defd And (P^.Sect<0) And (P^.Kind<>2) Then Begin
     If Hx Then R:=R+HexMin(P^.Value) Else R:=R+IntStr(P^.Value);
    End Else If AsmPassNo=2 Then
     Err3('invalid numeric expansion','Expansion numerique invalide',
       'Ungueltige numerische Expansion');
    I:=J+1;
   End Else If IsIdStart(C) And (T.MacIdx>0) And (Macros[T.MacIdx].PNames<>'')
     Then Begin
    J:=I+1;Nm:='';
    While (J<=Length(S)) And IsIdChar(S[J]) Do Begin Nm:=Nm+S[J];Inc(J);End;
    K:=ParamIndex(Macros[T.MacIdx].PNames,Nm);
    If (K>0) And (K<=35) Then Begin R:=R+T.Args[K];I:=J;End
    Else Begin
     K:=ParamOfChar(C);
     If K>0 Then Begin R:=R+T.Args[K];Inc(I,2);End
     Else Begin R:=R+S[I];Inc(I);End;
    End;
   End Else Begin
    K:=ParamOfChar(C);
    If K>0 Then Begin R:=R+T.Args[K];Inc(I,2);End
    Else Begin R:=R+S[I];Inc(I);End;
   End;
  End Else Begin R:=R+S[I];Inc(I);End;
 End;
 SubstMacro:=Copy(R,1,255);
End;

Procedure ListMacEnd(Const Tx: String); Forward;
Var LastEndTxt: String[60];

Function NextLine(Var S: String): Boolean;
Begin
 NextLine:=False;
 While SrcTop>0 Do Begin
  If Srcs[SrcTop].Pos>Srcs[SrcTop].Count Then Begin
   If (Srcs[SrcTop].Kind=2) And (Srcs[SrcTop].Reps>1) Then Begin
    Dec(Srcs[SrcTop].Reps);
    Srcs[SrcTop].Pos:=1;
   End Else Begin
    If (Srcs[SrcTop].Kind=1) And (Srcs[SrcTop].MacIdx>0) Then
      ListMacEnd(Macros[Srcs[SrcTop].MacIdx].EndTxt);
    PopSrc;
   End;
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

{ Ligne suivante de la source courante, sans la consommer ('' si fin) }
Function PeekLine(Var S: String): Boolean;
Begin
 PeekLine:=False;
 If SrcTop<=0 Then Exit;
 If Srcs[SrcTop].Pos>Srcs[SrcTop].Count Then Exit;
 S:=Srcs[SrcTop].Lines^[Srcs[SrcTop].Pos]^;
 If Srcs[SrcTop].Kind=1 Then S:=SubstMacro(S,Srcs[SrcTop]);
 PeekLine:=True;
End;

{ Appel de macro sur plusieurs lignes : la ligne se termine par une virgule et
  la suivante commence par & }
Procedure JoinContinuation(Var S: String);
Var T: String; I,Q: Integer; Qc: Char;
Begin
 While PeekLine(T) Do Begin
  Q:=1;
  While (Q<=Length(T)) And ((T[Q]=' ') Or (T[Q]=#9)) Do Inc(Q);
  If (Q>Length(T)) Or (T[Q]<>'&') Then Break;
  { enleve le commentaire de la ligne courante }
  Qc:=#0;
  For I:=1 To Length(S) Do Begin
   If Qc<>#0 Then Begin If S[I]=Qc Then Qc:=#0;End
   Else If (S[I]='''') Or (S[I]='"') Then Qc:=S[I]
   Else If (S[I]=';') And (I>1) And ((S[I-1]=' ') Or (S[I-1]=#9)) Then Begin
     S:=Copy(S,1,I-1);Break;End;
  End;
  While (S<>'') And ((S[Length(S)]=' ') Or (S[Length(S)]=#9)) Do
    Delete(S,Length(S),1);
  Inc(Q);
  While (Q<=Length(T)) And ((T[Q]=' ') Or (T[Q]=#9)) Do Inc(Q);
  S:=Copy(S+Copy(T,Q,255),1,255);
  Inc(Srcs[SrcTop].Pos);
  UpdateLoc;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Analyse d'une ligne                                                     }
{ ---------------------------------------------------------------------- }

Function FindMacro(Const Name: String): Integer; Forward;

{ noms de directives : une macro de meme nom est ignoree (comme dans le vrai
  GenST) }
Function IsDirName(Const Op: String): Boolean;
Begin
 IsDirName:=Pos(' '+Op+' ',' DC DS DCB EVEN CNOP ORG OFFSET SECTION '+
   'TEXT DATA BSS EQU SET = EQUR REG RS RSSE'+
   'T RSRESET FAIL END INCLUDE INCBIN LIST N'+
   'OLIST PAGE SPC TTL SUBTTL PLEN LLEN FORM'+
   'AT OPT OUTPUT COMMENT XDEF XREF MACRO EN'+
   'DM MEXIT REPT ENDR IFEQ IFNE IFGT IFGE I'+
   'FLT IFLE IFC IFNC IFD IFND ENDC ELSE ELS'+
   'EIF IIF MODULE IDNT CARGS FEQU FOPT ')>0;
End;


Procedure SplitLine(Const S: String; Var Lbl,Op,Suf,Args: String);
Var I,D: Integer; Q: Char; Tk,RawOp: String; IsMac: Boolean;
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
 { etiquette indentee terminee par ':' }
 If (Lbl='') And (Length(Tk)>1) And (Tk[Length(Tk)]=':') And (S[1]<>'*') Then
   Begin
  Lbl:=Copy(Tk,1,Length(Tk)-1);
  If (Lbl<>'') And (Lbl[Length(Lbl)]=':') Then Delete(Lbl,Length(Lbl),1);
  While (I<=Length(S)) And ((S[I]=' ') Or (S[I]=#9)) Do Inc(I);
  If (I>Length(S)) Or (S[I]=';') Then Exit;
  Tk:='';
  While (I<=Length(S)) And (S[I]<>' ') And (S[I]<>#9) And (S[I]<>';') Do Begin
   Tk:=Tk+S[I];Inc(I);
  End;
 End;
 D:=Pos('.',Tk);
 If (D>1) And (Tk[1]<>'.') Then Begin
  Op:=Upper(Copy(Tk,1,D-1));
  Suf:=Upper(Copy(Tk,D+1,10));
  RawOp:=Copy(Tk,1,D-1);
 End Else Begin Op:=Upper(Tk);RawOp:=Tk;End;
 If OptCase And (MacCount>0) Then Begin
  D:=FindMacro(Op);
  If (D<>0) And (Macros[D].Raw<>RawOp) Then Op:=Op+'#';
 End;
 IsMac:=(MacCount>0) And (FindMacro(Op)<>0) And Not IsDirName(Op);
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
    '<': If IsMac And ((Args='') Or (Args[Length(Args)]=',')) Then Begin
          Args:=Args+'<';Inc(I);
          While I<=Length(S) Do Begin
           If S[I]='>' Then Begin
            If (I<Length(S)) And (S[I+1]='>') Then Begin
              Args:=Args+'>>';Inc(I,2);End
            Else Begin Args:=Args+'>';Inc(I);Break;End;
           End Else Begin Args:=Args+S[I];Inc(I);End;
          End;
         End Else Begin Args:=Args+S[I];Inc(I);End;
    ';': If D<=0 Then Break Else Begin Args:=Args+S[I];Inc(I);End;
    ' ',#9: Begin
             If (Args<>'') And (Args[Length(Args)]=',') And (((Op='DC')) Or
               IsMac) Then Inc(I)
             Else Break;
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
 EndFlag    : Boolean;
 OutFileName: String;
 HeadFlags  : LongInt;
 HeadSet    : Boolean;
 { listing }
 ListCnt    : Integer;       { compteur LIST +/- }
 ListSkip,ListIsEqu,ListMacMark,ListAfter,ListNoData,ListDone : Boolean;
 ListEquVal : LongInt;
 ListPLen,ListLLen,ListPage,ListLineNo,ListSpc : Integer;
 ListQ      : Array[1..8] Of String[255];
 ListQN     : Integer;
 ListHold   : Boolean;
 ListTitle,ListSub : String[80];
 ListFmt    : Array[0..2] Of Boolean;
 IncDirs    : Array[1..16] Of String[120];
 IncDirN    : Integer;
 IncSeen    : Array[1..200] Of String[120];
 IncSeenN   : Integer;

Procedure GstNewModule(Const N: String); Forward;

Procedure DefSym(Const NameIn: String; V: LongInt; Sc: Integer; Kind: Byte);
Var P: PSym; Name: String;
Begin
 Name:=LocalName(NameIn);
 If (ModIdx>0) And (Sc>=0) Then Name:=ModKey(Name);
 P:=FindSym(Name);
 If P=Nil Then Begin
  If (AsmPassNo=2) And (Kind<>1) Then
    Err3('additional symbol on pass 2','Symbole supplementaire en passe 2',
    'Zusaetzliches Symbol in Pass 2');
  P:=AddSym(Name);
 End Else If P^.Defd And (P^.Pas=PassSerial) Then Begin
  If (Kind<>1) Or (P^.Kind<>1) Then Begin
   Err3('symbol defined twice','Symbole deja defini : '+NameIn,
        'Symbol bereits definiert: '+NameIn);
   Exit;
  End;
 End Else If (AsmPassNo=2) And P^.Defd And (Kind=0) And (P^.Kind=0) Then Begin
  If (P^.Value<>V) Or (P^.Sect<>Sc) Then
   Err3('phasing error','Erreur de phase : '+NameIn,'Phasenfehler: '+NameIn);
 End;
 P^.Value:=V;P^.Sect:=Sc;P^.Kind:=Kind;P^.Defd:=True;P^.Pas:=PassSerial;
End;

Procedure DefLabel(Const Name: String);
Var Sc: Integer;
Begin
 If IsLocalName(Name) And (LastGlobal='') Then Begin
  Err3('local not allowed','Etiquette locale non permise',
    'Lokales Label nicht erlaubt');Exit;
 End;
 If AbsMode Or OffMode Then Sc:=SEC_ABS Else Sc:=CurSect;
 DefSym(Name,CurPC,Sc,0);
 If (Name<>'') And Not IsLocalName(Name) Then
  LastGlobal:=Copy(Name,1,255);
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
  Err3('Conditionals nested too deeply','Conditionnels trop imbriques',
    'Zu tiefe Verschachtelung');
  Exit;
 End;
 Inc(CondTop);
 CondLn[CondTop]:=CurLineNo;
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
Var R: TTV; Test: Boolean; Parts: Array[0..3] Of String; N,NC: Integer; P:
  PSym; Op: String; RV: LongInt;
Begin
 CondDirective:=True;
 Op:=Op0;
 If Op='IFDEF' Then Op:='IFD' Else If Op='IFNDEF' Then Op:='IFND';
 If (Op='ENDC') Or (Op='ENDIF') Then Begin
  If CondTop=0 Then Err3('spurious ENDC','ENDC sans IF','ENDC ohne IF')
  Else Begin
   NC:=SrcTop;
   While (NC>0) And (Srcs[NC].Kind<>1) Do Dec(NC);
   If (NC>0) And (CondTop<=Srcs[NC].CondBase) Then
     FatalErr3('fatally bad conditional','Conditionnel gravement incorrect',
     'Schwerwiegend fehlerhafte Bedingung')
   Else Begin Dec(CondTop);SetCondActive;End;
  End;
  Exit;
 End;
 If (Op='ELSE') Or (Op='ELSEIF') Then Begin
  If CondTop=0 Then Err3('ELSE without IF','ELSE sans IF','ELSE ohne IF')
  Else Begin
   Conds[CondTop].Active:=Conds[CondTop].Parent And Not Conds[CondTop].Taken;
   If Conds[CondTop].Active Then Conds[CondTop].Taken:=True;
   SetCondActive;
  End;
  Exit;
 End;
 If (Op='IFEQ') Or (Op='IFNE') Or (Op='IFGT') Or (Op='IFGE') Or (Op='IFLT') Or
    (Op='IFLE') Then Begin
  Test:=False;
  If CondActive Then Begin
   ErrOvr:='invalid IF expression, ignored';
   FwdRef:=False;
   If Not EvalStr(Args,R) Then Begin ErrOvr:='';Exit;End;
   ErrOvr:='';
   ListIsEqu:=True;ListEquVal:=R.V;
   If FwdRef Then Begin
    Err3('absolute expression MUST evaluate',
      'L''expression absolue doit etre evaluabl'+'e',
      'Absoluter Ausdruck muss auswertbar sein');
    Exit;
   End;
   If Op='IFEQ' Then Test:=R.V=0
   Else If Op='IFNE' Then Test:=R.V<>0
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
   If ReservedSym(Upper(TrimS(Args)),RV) Then Test:=True
   Else Begin
    P:=FindSym(LocalName(TrimS(Args)));
    Test:=(P<>Nil) And P^.Defd;
   End;
   If Op='IFND' Then Test:=Not Test;
  End;
  CondPush(Test);
  Exit;
 End;
 If (Op='IFC') Or (Op='IFNC') Then Begin
  Test:=False;
  If CondActive Then Begin
   N:=SplitTop(Args,Parts,4);
   If N=2 Then Begin
    If (Parts[0]='') Or (Parts[1]='') Or Not (Parts[0][1] In ['''','"']) Or Not
      (Parts[1][1] In ['''','"']) Then Begin
     Err3('missing quote','Apostrophe manquante','Anfuehrungszeichen fehlt');
     Exit;
    End;
    Test:=StrOperand(Parts[0])=StrOperand(Parts[1]);
   End;
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

Procedure ListLine(Const S: String); Forward;

Function CollectBody(Const OpStart,OpEnd: String; Var Cnt: Integer): PLineArr;
Var S,L,O,Sf,A: String; Depth,I: Integer; Res: PLineArr; Done: Boolean;
  StartLn: LongInt;
Begin
 Cnt:=0;Depth:=0;Done:=False;StartLn:=CurLineNo;
 While Not Done Do Begin
  If Not NextLine(S) Then Begin
   CurLineNo:=StartLn;
   FatalErr3('source expired prematurely','Fin de fichier inattendue dans '+
     OpStart,
        'Unerwartetes Dateiende in '+OpStart);
   Break;
  End;
  SplitLine(S,L,O,Sf,A);
  If ((OpStart='MACRO') Or (OpStart='REPT')) And ListWanted Then Begin
    LnStartLen:=SecLen[CurSect];ListLine(S);End;
  If O=OpStart Then Begin
   If OpStart<>'REPT' Then Inc(Depth);
   If OpStart='MACRO' Then
    Err3('cannot nest MACRO definitions or define '+'in REPTs',
      'Macros imbriquees interdites','Verschachtelte Makros nicht erlaubt');
  End Else If (OpStart='REPT') And (O='MACRO') Then
   Err3('cannot nest MACRO definitions or define '+'in REPTs',
     'Macro dans REPT interdite','Makro in REPT nicht erlaubt')
  Else If O=OpEnd Then Begin
   If Depth=0 Then Begin Done:=True;LastEndTxt:=Copy(S,1,60);Continue;End;
   Dec(Depth);
  End;
  If Cnt<MAXLN Then Begin Inc(Cnt);TmpBody^[Cnt]:=NewStr(S);End
  Else Err3('program buffer full','Programme trop grand','Programm zu gross');
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
 For I:=1 To MacCount Do If Macros[I].Name=Name Then Begin
   FindMacro:=I;Exit;End;
End;

Procedure DefineMacro(Const Name,PNames,Suf: String);
Var Cnt: Integer; B: PLineArr; I: Integer;
Begin
 If Name='' Then Begin
  Err3('symbol expected','Nom de macro manquant','Makroname fehlt');Exit;
 End;
 If FindMacro(Upper(Name))<>0 Then Begin
  { le vrai GenST signale l'erreur sur la ligne MACRO et ne saute pas le corps }
  Err3('symbol defined twice','Macro deja definie',
    'Makro bereits definiert');Exit;
 End;
 B:=CollectBody('MACRO','ENDM',Cnt);
 If MacCount>=MAXMAC Then
   Err3('out of memory','Trop de macros','Zu viele Makros')
 Else Begin
  I:=FindMacro(Upper(Name));
  If I<>0 Then Begin
   Err3('symbol defined twice','Macro deja definie','Makro bereits definiert');
  End Else Begin
   Inc(MacCount);
   Macros[MacCount].Name:=Copy(Upper(Name),1,63);
   Macros[MacCount].Raw:=Copy(Name,1,63);
   Macros[MacCount].EndTxt:=LastEndTxt;
   Macros[MacCount].PNames:=Copy(PNames,1,100);
   Macros[MacCount].Body:=B;
   Macros[MacCount].Count:=Cnt;
   Macros[MacCount].Even:=(Suf='W') Or (Suf='L');
   Exit;
  End;
 End;
 For I:=1 To Cnt Do FreeStr(B^[I]);
 FreeMem(B,Cnt*SizeOf(PString)+4);
End;

{ Decoupe les parametres d'un appel de macro (virgules, < > , guillemets) }
Function SplitMacArgs(Const S: String; Var Arr: Array Of String; MaxN:
  Integer): Integer;
Var I,D,N: Integer; Q: Char; Cur: String; Br: Boolean;

 Procedure Fin;
 Var T: String; K: Integer;
 Begin
  T:=TrimS(Cur);
  If Br And (Length(T)>=2) And (T[1]='<') And (T[Length(T)]='>') Then Begin
   T:=Copy(T,2,Length(T)-2);
   K:=Pos('>>',T);
   While K>0 Do Begin Delete(T,K,1);K:=Pos('>>',T);End;
  End;
  If N<MaxN Then Begin Arr[N]:=T;Inc(N);End;
  Cur:='';Br:=False;
 End;

Begin
 N:=0;D:=0;Q:=#0;Cur:='';Br:=False;
 I:=1;
 While I<=Length(S) Do Begin
  If Q<>#0 Then Begin
   Cur:=Cur+S[I];
   If S[I]=Q Then Q:=#0;
   Inc(I);
  End Else Begin
   Case S[I] Of
    '''','"': Begin Q:=S[I];Cur:=Cur+S[I];Inc(I);End;
    '(': Begin Inc(D);Cur:=Cur+S[I];Inc(I);End;
    ')': Begin Dec(D);Cur:=Cur+S[I];Inc(I);End;
    '<': If TrimS(Cur)='' Then Begin
          Br:=True;
          Cur:=Cur+'<';Inc(I);
          While I<=Length(S) Do Begin
           If S[I]='>' Then Begin
            If (I<Length(S)) And (S[I+1]='>') Then Begin
              Cur:=Cur+'>>';Inc(I,2);End
            Else Begin Cur:=Cur+'>';Inc(I);Break;End;
           End Else Begin Cur:=Cur+S[I];Inc(I);End;
          End;
         End Else Begin Cur:=Cur+S[I];Inc(I);End;
    ',': If D<=0 Then Begin Fin;Inc(I);End Else Begin Cur:=Cur+S[I];Inc(I);End;
   Else Begin Cur:=Cur+S[I];Inc(I);End;
   End;
  End;
 End;
 If (Cur<>'') Or (N>0) Then Fin;
 SplitMacArgs:=N;
End;

Procedure CallMacro(Idx: Integer; Const Args,Suf: String);
Var Parts: Array[0..35] Of String; N,I: Integer; A: String;
Begin
 N:=SplitMacArgs(Args,Parts,36);
 If Macros[Idx].Even Then EvenPC;
 PushSrc(1,Macros[Idx].Body,Macros[Idx].Count,Macros[Idx].Name,False);
 If SrcTop=0 Then Exit;
 With Srcs[SrcTop] Do Begin
  Inc(MacUniq);
  MacId:=MacUniq;
  NArg:=N;
  MacIdx:=Idx;
  CondBase:=CondTop;
  Suffix:=Copy(Suf,1,8);
  For I:=1 To 35 Do Begin
   If I<=N Then Args[I]:=Copy(Parts[I-1],1,200) Else Args[I]:='';
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Directives de donnees                                                   }
{ ---------------------------------------------------------------------- }

{ Operande suivant d'une liste separee par des virgules (niveau 0) }
Function NextOperand(Const S: String; Var P: Integer; Var Item: String):
  Boolean;
Var D: Integer; Q: Char;
Begin
 NextOperand:=False;
 If P>Length(S)+1 Then Exit;
 Item:='';D:=0;Q:=#0;
 While P<=Length(S) Do Begin
  If Q<>#0 Then Begin
   Item:=Item+S[P];
   If S[P]=Q Then Q:=#0;
   Inc(P);
  End Else Begin
   Case S[P] Of
    '''','"': Begin Q:=S[P];Item:=Item+S[P];Inc(P);End;
    '(','[': Begin Inc(D);Item:=Item+S[P];Inc(P);End;
    ')',']': Begin Dec(D);Item:=Item+S[P];Inc(P);End;
    ',': If D=0 Then Begin Inc(P);Item:=TrimS(Item);NextOperand:=True;Exit;End
         Else Begin Item:=Item+S[P];Inc(P);End;
   Else Begin Item:=Item+S[P];Inc(P);End;
   End;
  End;
 End;
 Item:=TrimS(Item);
 Inc(P);
 NextOperand:=True;
End;

{ DC / DS / DCB flottants : Sz = 8 (S), 16 (D), 32 (X), 64 (P) }
Function FloatLen(Sz: Integer): Integer;
Begin
 If Sz=8 Then FloatLen:=4 Else If Sz=16 Then FloatLen:=8 Else FloatLen:=12;
End;

Procedure DirFloat(Const Op,Args: String; Sz: Integer);
Var P,Len,I: Integer; S,S2: String; B: TFBytes; R: TTV; K,N: LongInt;
Begin
 If Not NeedFPU Then Begin BadInstr:=False;Exit;End;
 If Op='DC' Then Begin
  P:=1;
  While NextOperand(Args,P,S) Do Begin
   If FpConst(S,Sz,B,Len) Then
    For I:=0 To Len-1 Do EmitByte(B[I]);
  End;
 End Else If Op='DS' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If R.V<0 Then
    Err3('DCB or DS count must not be negative','DCB/DS negatif',
    'DCB/DS negativ')
  Else ReserveBytes(R.V*FloatLen(Sz));
 End Else Begin
  P:=1;
  If Not NextOperand(Args,P,S) Then Exit;
  If Not EvalStr(S,R) Then R.V:=0;
  N:=R.V;
  If N<0 Then Begin
    Err3('DCB or DS count must not be negative','DCB/DS negatif',
    'DCB/DS negativ');Exit;End;
  S2:='0';
  If NextOperand(Args,P,S) Then S2:=S;
  If FpConst(S2,Sz,B,Len) Then
   For K:=1 To N Do
    For I:=0 To Len-1 Do EmitByte(B[I]);
 End;
End;

{ valeur etendue d'une constante hexa ou decimale pour FEQU }
Function FequValue(Const T: String; Sz: Integer; Var E: Extended): Boolean;
Var B: TFBytes; Len,I: Integer; Sg: Single; Db: Double; Tmp: Array[0..9] Of
  Byte; S4: Array[0..3] Of Byte; D8: Array[0..7] Of Byte;
    TT: String;
Begin
 FequValue:=False;
 TT:=TrimS(T);
 If (TT<>'') And ((TT[1]=':') Or (TT[1]='$')) Then Begin
  If Not FpConst(TT,Sz,B,Len) Then Exit;
  If Sz=8 Then Begin For I:=0 To 3 Do S4[3-I]:=B[I];Move(S4,Sg,4);E:=Sg;End
  Else If Sz=16 Then Begin For I:=0 To 7 Do
    D8[7-I]:=B[I];Move(D8,Db,8);E:=Db;End
  Else Begin
   Tmp[9]:=B[0];Tmp[8]:=B[1];
   For I:=0 To 7 Do Tmp[7-I]:=B[4+I];
   Move(Tmp,E,10);
  End;
  FequValue:=True;Exit;
 End;
 If Not DecToExt(TT,E) Then Begin
   Err3('bad floating point expression','Expression flottante incorrecte',
   'Fehlerhafter Gleitkommaausdruck');Exit;End;
 FequValue:=True;
End;

Procedure DirDC(Sz: Integer; Const Args: String);
Var P,J: Integer; R: TTV; S: String; Q: Char; Any: Boolean;
Begin
 If Sz=0 Then Sz:=2;
 If Sz=8 Then Sz:=1;
 If TrimS(Args)='' Then Begin
  Err3('expression mismatch','Operande attendue','Operand erwartet');Exit;
 End;
 P:=1;
 While NextOperand(Args,P,S) Do Begin
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
   1: Begin
       CheckRange(R.V,R.U,-256,255);
       If R.X>0 Then
         Err3('relocation not allowed','Relocation interdite',
         'Relokation nicht erlaubt');
       If R.S>=0 Then
         Warn3('relative cannot be relocated','Relatif non relogeable',
         'Relativ nicht relozierbar');
       EmitByte(R.V And $FF);
      End;
   2: Begin
       CheckRange(R.V,R.U,-65536,65535);
       If (R.S>=0) And (R.X=0) Then
         Warn3('relative cannot be relocated','Relatif non relogeable',
         'Relativ nicht relozierbar');
       If R.X>0 Then Begin
        If R.NS>=0 Then EmitWordRel(R.V And
          $FFFF,RELIMP+R.X*4+1+LongInt(R.NS+1)*100000)
        Else EmitWordRel(R.V And $FFFF,RELIMP+R.X*4+1);
       End Else EmitWord(R.V And $FFFF);
      End;
  Else If R.X>0 Then Begin
   If R.NS>=0 Then EmitLong(R.V,RELIMP+R.X*4+LongInt(R.NS+1)*100000) Else
     EmitLong(R.V,RELIMP+R.X*4);
  End
  Else If (R.NS>=0) And (R.S>=0) Then EmitLong(R.V,R.S+LongInt(R.NS+1)*100000)
  Else EmitLong(ImgOf(R.V,R.S),R.S);
  End;
 End;
End;

Function ReadFileBytes(Const Name: String; Var P: Pointer; Var Len: LongInt):
  Boolean;
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

{ nom TOS -> nom hote (\ en /, lecteur ignore) }
Function AsmHostPath(Const S0: String): String;
Var S: String; I: Integer;
Begin
 S:=S0;
 {$IFDEF FPC}
 {$IFDEF UNIX}
 If (Length(S)>=2) And (S[2]=':') Then S:=Copy(S,3,255);
 For I:=1 To Length(S) Do If S[I]='\' Then S[I]:='/';
 {$ENDIF}
 {$ENDIF}
 AsmHostPath:=S;
End;

{ fichier existant (casse libre pour chaque composant du chemin) ou '' }
Function ExistCI(Const S: String): String;
Var Cur,Comp,Rest,U,Found: String; SR: SearchRec; P: Integer;
Begin
 ExistCI:='';
 If S='' Then Exit;
 If FileExists(S) Then Begin ExistCI:=S;Exit;End;
 Cur:='';Rest:=S;
 If Rest[1]='/' Then Begin Cur:='/';Delete(Rest,1,1);End;
 While Rest<>'' Do Begin
  P:=Pos('/',Rest);
  If P>0 Then Begin Comp:=Copy(Rest,1,P-1);Rest:=Copy(Rest,P+1,255);End
  Else Begin Comp:=Rest;Rest:='';End;
  If (Comp='') Or (Comp='.') Or (Comp='..') Then Begin
   If P>0 Then Cur:=Cur+Comp+'/' Else Cur:=Cur+Comp;
   Continue;
  End;
  U:=Upper(Comp);Found:='';
  FindFirst(Cur+'*',AnyFile,SR);
  While DosError=0 Do Begin
   If SR.Name=Comp Then Begin Found:=SR.Name;Break;End;
   If (Found='') And (Upper(SR.Name)=U) Then Found:=SR.Name;
   FindNext(SR);
  End;
  {$IFDEF FPC}FindClose(SR);{$ENDIF}
  If Found='' Then Exit;
  If P>0 Then Cur:=Cur+Found+'/' Else Cur:=Cur+Found;
 End;
 If FileExists(Cur) Then ExistCI:=Cur;
End;

Function FindInclude(Const Name0: String): String;
Var Cand,Name: String; I: Integer;
Begin
 Name:=AsmHostPath(Name0);
 Cand:=ExistCI(Name);
 If Cand<>'' Then Begin FindInclude:=Cand;Exit;End;
 Cand:=ExistCI(PathOf(AsmFileName)+Name);
 If Cand<>'' Then Begin FindInclude:=Cand;Exit;End;
 For I:=1 To IncDirN Do Begin
  Cand:=IncDirs[I];
  If Cand='' Then Continue;
  If (Cand[Length(Cand)]<>'\') And (Cand[Length(Cand)]<>'/') And
    (Cand[Length(Cand)]<>':') Then
   Cand:=Cand+'/';
  Cand:=ExistCI(AsmHostPath(Cand)+Name);
  If Cand<>'' Then Begin FindInclude:=Cand;Exit;End;
 End;
 FindInclude:='';
End;

Procedure AddIncDirs(Const L: String);
Var P: Integer; Item,Cur: String; Q: Boolean; I: Integer;
Begin
 Cur:='';Q:=False;
 For I:=1 To Length(L)+1 Do Begin
  If (I>Length(L)) Or (((L[I]=',') Or (L[I]=';')) And Not Q) Then Begin
   Item:=TrimS(Cur);Cur:='';
   If (Length(Item)>=2) And (Item[1]='"') And (Item[Length(Item)]='"') Then
     Item:=Copy(Item,2,Length(Item)-2);
   If (Item<>'') And (IncDirN<16) Then Begin
     Inc(IncDirN);IncDirs[IncDirN]:=Copy(Item,1,120);End;
  End Else Begin
   If L[I]='"' Then Q:=Not Q;
   Cur:=Cur+L[I];
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Fichiers de symboles pre-assembles .GS (Output Symbols, OPT GENSYM, -H) : }
{ format texte propre a ce projet, voir DOC (GS_FORMAT dans le resume)      }
{   DEVPAC-GS 1 / I nom (include deja traite) / S nom hex (absolu)          }
{   R nom hex (REG) / M nom pair|parametres puis L ligne... puis E          }
{ ---------------------------------------------------------------------- }

Var
 GsSeen   : Array[1..64] Of String[80];
 GsSeenN  : Integer;
 GsIncl   : Array[1..64] Of String[120];
 GsInclN  : Integer;
 GsOutName: String;

Function BaseUp(Const N: String): String;
Begin
 BaseUp:=Upper(ShortName(AsmHostPath(N)));
End;

Function GsIsSeen(Const N: String): Boolean;
Var K: Integer; U: String;
Begin
 GsIsSeen:=False;U:=BaseUp(N);
 For K:=1 To GsSeenN Do If GsSeen[K]=U Then GsIsSeen:=True;
End;

Procedure GsAddSeen(Const N: String);
Begin
 If (GsSeenN<64) And Not GsIsSeen(N) Then Begin
   Inc(GsSeenN);GsSeen[GsSeenN]:=Copy(BaseUp(N),1,80);End;
End;

Function HexToLong(Const S: String): LongInt;
Var I: Integer; V: LongInt;
Begin
 V:=0;
 For I:=1 To Length(S) Do If IsHexCh(S[I]) Then V:=(V Shl 4) Or HexVal(S[I]);
 HexToLong:=V;
End;

Procedure LoadGS(Const Fn: String);
Var T: Text; L,Nm,Rest: String; P,Cnt,I: Integer; Ok,InMac: Boolean; V: LongInt;
    MName,MPar: String; MEven: Boolean; B: PLineArr; Sy: PSym;
Begin
 Assign(T,Fn);
 {$I-}
 Reset(T);
 {$I+}
 If IOResult<>0 Then Begin
  Err3('invalid pre-assembled file','Fichier pre-assemble invalide : '+Fn,
    'Ungueltige vorassemblierte Datei: '+Fn);Exit;
 End;
 Ok:=False;InMac:=False;Cnt:=0;
 If Not Eof(T) Then Begin ReadLn(T,L);Ok:=Copy(L,1,12)='DEVPAC-GS 1';End;
 While Ok And Not Eof(T) Do Begin
  ReadLn(T,L);
  If L='' Then Continue;
  If InMac Then Begin
   If L='E' Then Begin
    InMac:=False;
    If (FindMacro(MName)=0) And (MacCount<MAXMAC) Then Begin
     GetMem(B,Cnt*SizeOf(PString)+4);
     For I:=1 To Cnt Do B^[I]:=TmpBody^[I];
     Inc(MacCount);
     Macros[MacCount].Name:=Copy(MName,1,63);
     Macros[MacCount].PNames:=Copy(MPar,1,100);
     Macros[MacCount].Body:=B;Macros[MacCount].Count:=Cnt;Macros[MacCount].Even
       :=MEven;
    End Else For I:=1 To Cnt Do FreeStr(TmpBody^[I]);
   End Else If (L[1]='L') And (Cnt<MAXLN) Then Begin
     Inc(Cnt);TmpBody^[Cnt]:=NewStr(Copy(L,3,255));End;
   Continue;
  End;
  Rest:=Copy(L,3,255);
  Case L[1] Of
   'I': GsAddSeen(Rest);
   'S','R': Begin
     P:=Pos(' ',Rest);
     If P<2 Then Ok:=False
     Else Begin
      Nm:=Copy(Rest,1,P-1);V:=HexToLong(Copy(Rest,P+1,20));
      Sy:=FindSym(Nm);
      If (Sy=Nil) Or Not (Sy^.Defd And (Sy^.Pas=PassSerial)) Then
       If L[1]='S' Then DefSym(Nm,V,SEC_ABS,0) Else DefSym(Nm,V,SEC_ABS,2);
     End;
    End;
   'M': Begin
     P:=Pos(' ',Rest);
     If P<2 Then Ok:=False
     Else Begin
      MName:=Copy(Rest,1,P-1);Rest:=Copy(Rest,P+1,255);
      MEven:=(Rest<>'') And (Rest[1]='1');
      MPar:=Copy(Rest,3,100);
      InMac:=True;Cnt:=0;
     End;
    End;
  Else Ok:=False;
  End;
 End;
 Close(T);
 If Not Ok Or InMac Then
  Err3('invalid pre-assembled file','Fichier pre-assemble invalide : '+Fn,
    'Ungueltige vorassemblierte Datei: '+Fn);
End;

{ -H / liste « Pre-assembled includes » : charge les .GS au debut de chaque
  passe }
Procedure LoadHeaders(Const L: String);
Var P: Integer; S,Full: String;
Begin
 P:=1;
 While NextOperand(L,P,S) Do Begin
  If S='' Then Continue;
  Full:=FindInclude(S);
  If (Full='') And (Pos('.',S)=0) Then Full:=FindInclude(S+'.GS');
  If Full='' Then
    FatalErr3('file not found','Fichier introuvable : '+S,
    'Datei nicht gefunden: '+S)
  Else Begin LoadGS(Full);GsAddSeen(S);End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ OPT                                                                     }
{ ---------------------------------------------------------------------- }

Procedure SetAllOpt(On: Boolean);
Var K: Integer;
Begin
 For K:=1 To 12 Do AO.Opt[K]:=On;
End;

Function CodeGenerated: Boolean;
Begin
 CodeGenerated:=(SecLen[0]>0) Or (SecLen[1]>0) Or (SecLen[2]>0);
End;

Procedure BadOption;
Begin
 Err3('invalid option','Option invalide','Ungueltige Option');
End;

Procedure SetFormat(F: Integer);
Begin
 If CodeGenerated Then Begin
  Err3('option must be at start','L''option doit etre au debut',
    'Option muss am Anfang stehen');Exit;
 End;
 If (F<>0) And (F<>6) And (F<>2) And (F<>7) And (F<>1) Then Begin
  Err3('linker format restriction','Format d''edition de liens non gere',
    'Linker-Format nicht unterstuetzt');
  Exit;
 End;
 AO.Fmt:=F;
End;

{ une option de OPT ; T est en majuscules }
Procedure OptOne(Const T0: String);
Var T: String; On,HasSign: Boolean; N,K,C: Integer; Co,Co2,CoPro: String;
Begin
 T:=T0;
 On:=True;HasSign:=False;
 If T='' Then Exit;
 If T[Length(T)]='+' Then Begin Delete(T,Length(T),1);HasSign:=True;End
 Else If T[Length(T)]='-' Then Begin
   Delete(T,Length(T),1);On:=False;HasSign:=True;End;
 If T='' Then Begin BadOption;Exit;End;
 { P=type[/copro] }
 If (Length(T)>=2) And (T[1]='P') And (T[2]='=') Then Begin
  Co:=Copy(T,3,40);
  K:=Pos('/',Co);
  CoPro:='';
  If K>0 Then Begin CoPro:=Copy(Co,K,40);Co:=Copy(Co,1,K-1);End;
  AO.FPU:=False;AO.MMU:=False;
  While CoPro<>'' Do Begin
   Delete(CoPro,1,1);
   K:=Pos('/',CoPro);
   If K>0 Then Begin Co2:=Copy(CoPro,1,K-1);CoPro:=Copy(CoPro,K,40);End Else
     Begin Co2:=CoPro;CoPro:='';End;
   If (Co2='68881') Or (Co2='68882') Then AO.FPU:=True
   Else If Co2='68851' Then AO.MMU:=True
   Else BadOption;
  End;
  If (Co='68000') Or (Co='68008') Then AO.Proc:=68000
  Else If Co='68010' Then AO.Proc:=68010
  Else If Co='68020' Then AO.Proc:=68020
  Else If Co='68030' Then AO.Proc:=68030
  Else If Co='68040' Then AO.Proc:=68040
  Else If (Co='68332') Or (Co='CPU32') Then AO.Proc:=68332
  Else BadOption;
  Exit;
 End;
 If T='D' Then Begin OptDebug:=On;AO.XDebug:=AO0.XDebug;Exit;End;
 If T='DEBUG' Then Begin OptDebug:=True;AO.XDebug:=AO0.XDebug;Exit;End;
 If T='NODEBUG' Then Begin OptDebug:=False;Exit;End;
 If (T='X') Or (T='XDEBUG') Then Begin OptDebug:=On;AO.XDebug:=On;Exit;End;
 If T='LINE' Then Begin AO.Line:=True;Exit;End;
 If T='NOLINE' Then Begin AO.Line:=False;Exit;End;
 If T='HCLN' Then Begin AO.Hcln:=True;Exit;End;
 If T='NOHCLN' Then Begin AO.Hcln:=False;Exit;End;
 If T='C' Then Begin OptCase:=On;Exit;End;
 If T='CASE' Then Begin OptCase:=True;Exit;End;
 If T='NOCASE' Then Begin OptCase:=False;Exit;End;
 If (T[1]='C') And (Length(T)>=2) And (T[2]>='0') And (T[2]<='9') Then Begin
  Val(Copy(T,2,5),N,C);
  If (C<>0) Or (N<8) Or (N>127) Then Begin BadOption;Exit;End;
  AO.SymLen:=N;
  If HasSign Then OptCase:=On;
  Exit;
 End;
 If (T='W') Or (T='WARN') Then Begin OptWarnings:=On;Exit;End;
 If T='NOWARN' Then Begin OptWarnings:=False;Exit;End;
 If T='L' Then Begin If On Then SetFormat(1) Else SetFormat(0);Exit;End;
 If (T[1]='L') And (Length(T)=2) And (T[2]>='0') And (T[2]<='9') Then Begin
  C:=Ord(T[2])-48;
  If (C=0) Or (C=1) Or (C=2) Or (C=6) Or (C=7) Then SetFormat(C) Else BadOption;
  Exit;
 End;
 If T='ATARI' Then Begin SetFormat(0);Exit;End;
 If T='GST' Then Begin SetFormat(1);Exit;End;
 If T='DRI' Then Begin SetFormat(2);Exit;End;
 If T='SREC' Then Begin SetFormat(6);Exit;End;
 If T='LATTICE' Then Begin SetFormat(7);Exit;End;
 If T='GENSYM' Then Begin AO.Gensym:=True;Exit;End;
 { optimisations }
 If T='O' Then Begin SetAllOpt(On);Exit;End;
 If (T='OW') Then Begin
  For K:=0 To 12 Do AO.OW[K]:=On;
  Exit;
 End;
 If (Length(T)>=3) And (T[1]='O') And (T[2]='W') Then Begin
  Val(Copy(T,3,3),N,C);
  If (C<>0) Or (N<1) Or (N>12) Then Begin BadOption;Exit;End;
  AO.OW[N]:=On;
  If On Then AO.OW[0]:=True;
  Exit;
 End;
 If (Length(T)>=2) And (T[1]='O') And (T[2]>='0') And (T[2]<='9') Then Begin
  Val(Copy(T,2,3),N,C);
  If (C<>0) Or (N<1) Or (N>12) Then Begin BadOption;Exit;End;
  AO.Opt[N]:=On;
  If (N=1) And Not On Then OptOptimize:=False;
  Exit;
 End;
 If T='OLD' Then Begin AO.OldBra:=True;Exit;End;
 If (T='BRW') Then Begin AO.BrDef:=0;AO.OldBra:=False;Exit;End;
 If (T='BRB') Or (T='BRS') Then Begin AO.BrDef:=1;Exit;End;
 If T='BRL' Then Begin
  If AO.Proc<68020 Then
    Err3('wrong processor','Mauvais processeur','Falscher Prozessor')
  Else AO.BrDef:=3;
  Exit;
 End;
 If T='BDW' Then Begin AO.BdW:=True;Exit;End;
 If T='BDL' Then Begin AO.BdW:=False;Exit;End;
 If T='ODW' Then Begin AO.OdL:=False;Exit;End;
 If T='ODL' Then Begin AO.OdL:=True;Exit;End;
 If (T='MEX') Or (T='M') Then Begin AO.Mex:=On;Exit;End;
 If T='NOMEX' Then Begin AO.Mex:=False;Exit;End;
 If (T='SYMTAB') Or (T='S') Then Begin AO.Symtab:=On;Exit;End;
 If T='NOSYMTAB' Then Begin AO.Symtab:=False;Exit;End;
 If (T='LIST1') Or (T='Z') Then Begin AO.List1:=On;Exit;End;
 If T='NOLIST1' Then Begin AO.List1:=False;Exit;End;
 If T='TRACEIF' Then Begin AO.TraceIf:=True;Exit;End;
 If T='NOTRACEIF' Then Begin AO.TraceIf:=False;Exit;End;
 If T='ALLOWZERO' Then Begin AO.AllowZero:=True;Exit;End;
 If T='NOALLOWZERO' Then Begin AO.AllowZero:=False;Exit;End;
 If T='CHKBIT' Then Begin AO.ChkBit:=0;Exit;End;
 If T='NOCHKBIT' Then Begin AO.ChkBit:=1;Exit;End;
 If T='WARNBIT' Then Begin AO.ChkBit:=2;Exit;End;
 If (T='CHKIMM') Or (T='I') Then Begin AO.ChkImm:=On;Exit;End;
 If T='NOCHKIMM' Then Begin AO.ChkImm:=False;Exit;End;
 If (T='CHKPC') Or (T='P') Then Begin AO.ChkPC:=On;Exit;End;
 If T='NOCHKPC' Then Begin AO.ChkPC:=False;Exit;End;
 If (T='EVEN') Or (T='E') Then Begin AO.EvenChk:=On;Exit;End;
 If T='NOEVEN' Then Begin AO.EvenChk:=False;Exit;End;
 If (T='AUTOPC') Or (T='A') Then Begin AO.AutoPC:=On;Exit;End;
 If T='NOAUTOPC' Then Begin AO.AutoPC:=False;Exit;End;
 If T='INCONCE' Then Begin AO.Inconce:=True;Exit;End;
 If T='NOINCONCE' Then Begin AO.Inconce:=False;Exit;End;
 If (T='LOCALU') Or (T='U') Then Begin AO.LocalU:=On;Exit;End;
 If T='LOCALDOT' Then Begin AO.LocalU:=False;Exit;End;
 If T='NOTYPE' Then Begin AO.NoType:=True;Exit;End;
 If (T='TYPE') Or (T='T') Then Begin AO.NoType:=Not On;Exit;End;
 If T='USER' Then Begin AO.User:=True;Exit;End;
 If T='SUPER' Then Begin AO.User:=False;Exit;End;
 BadOption;
End;

Procedure DirOpt(Const Args: String);
Var P: Integer; S: String; First: Boolean;
Begin
 P:=1;First:=True;
 While NextOperand(Args,P,S) Do Begin
  S:=Upper(S);
  If S='' Then Begin
   If First And (Args<>'') Then BadOption;
   First:=False;Continue;
  End;
  First:=False;
  OptOne(S);
 End;
End;

{ GST : noms de sections libres (limites : deux sections nommees TEXT/DATA +
  BSS) }
{ GST : evenements dans l'ordre de la source (comme le vrai GenST) }
Const GEVMAX = 6000;
Var
 GEvN       : Integer;
 GEvK       : Array[1..GEVMAX] Of Byte;     { 0 octets, 1 XDEF, 2 section, 3
   commentaire }
 GEvS       : Array[1..GEVMAX] Of Integer;
 GEvA,GEvB  : Array[1..GEVMAX] Of LongInt;
 GEvTxt     : Array[1..40] Of String[80];
 GEvTxtN    : Integer;
 GSpanSect  : Integer;
 GSpanStart : LongInt;
 GXdefDone  : Array[1..2000] Of Boolean;
 LstSecId   : Array[0..2] Of Integer;
 LstSecN    : Integer;

Procedure GEvPush(K: Byte; S: Integer; A,B: LongInt);
Begin
 If GEvN<GEVMAX Then Begin
   Inc(GEvN);GEvK[GEvN]:=K;GEvS[GEvN]:=S;GEvA[GEvN]:=A;GEvB[GEvN]:=B;End;
End;

Procedure GSpanClose;
Var L: LongInt;
Begin
 L:=SecLen[GSpanSect];
 If L>GSpanStart Then GEvPush(0,GSpanSect,GSpanStart,L);
 GSpanStart:=L;
End;

Procedure GEvReset;
Begin
 GEvN:=0;GEvTxtN:=0;GSpanSect:=0;GSpanStart:=0;
 FillChar(GXdefDone,SizeOf(GXdefDone),0);
 FillChar(LstSecId,SizeOf(LstSecId),0);LstSecN:=1;LstSecId[0]:=1;
End;

{ numero de section GST pour le listing (ordre de premiere utilisation) }
Function GstListId(S: Integer): Integer;
Begin
 If (S<0) Or (S>2) Then Begin GstListId:=1;Exit;End;
 If LstSecId[S]=0 Then Begin Inc(LstSecN);LstSecId[S]:=LstSecN;End;
 GstListId:=LstSecId[S];
End;

Procedure GEvSection;
Begin
 GSpanClose;
 GEvPush(2,CurSect,0,0);
 If AbsMode Then GSpanSect:=0 Else GSpanSect:=CurSect;
 GSpanStart:=SecLen[GSpanSect];
End;

Procedure GEvXdef(K: Integer);
Begin
 If (K<1) Or (K>2000) Or GXdefDone[K] Then Exit;
 GXdefDone[K]:=True;
 GSpanClose;
 GEvPush(1,K,0,0);
End;

Procedure GEvCmt(Const T: String);
Begin
 If GEvTxtN>=40 Then Exit;
 GSpanClose;
 Inc(GEvTxtN);GEvTxt[GEvTxtN]:=Copy(T,1,80);
 GEvPush(3,GEvTxtN,0,0);
End;

Procedure GstSection(Const Op,N0: String);
Var N: String; S: Integer;
Begin
 N:=TrimS(N0);
 If (Op='TEXT') Or (Op='CODE') Or ((Op='SECTION') And ((Upper(N)='TEXT') Or
   (Upper(N)='CODE'))) Then Begin
  S:=0;If Op<>'SECTION' Then N:=Op;
  If Not GstSecCust[0] Then Begin
    GstSecName[0]:=Upper(N);GstSecCust[0]:=True;End;
  CurSect:=0;Exit;
 End;
 If (Op='DATA') Or ((Op='SECTION') And (Upper(N)='DATA')) Then Begin
  If Not GstSecCust[1] Then Begin GstSecName[1]:='DATA';GstSecCust[1]:=True;End;
  CurSect:=1;Exit;
 End;
 If (Op='BSS') Or ((Op='SECTION') And (Upper(N)='BSS')) Then Begin
   CurSect:=2;Exit;End;
 If N='' Then Begin
   Err3('invalid section specified','Section invalide',
   'Ungueltige Sektion');Exit;End;
 N:=Copy(Upper(N),1,32);
 For S:=0 To 1 Do
  If GstSecCust[S] And (GstSecName[S]=N) Then Begin CurSect:=S;Exit;End;
 For S:=0 To 1 Do
  If Not GstSecCust[S] Then Begin
    GstSecName[S]:=N;GstSecCust[S]:=True;CurSect:=S;Exit;End;
 Err3('invalid section name, TEXT assumed',
   'Nom de section invalide, TEXT suppose',
   'Ungueltiger Sektionsname, TEXT angenomme'+'n');
 CurSect:=SEC_TEXT;
End;

Procedure DirSection(Const Op,Args: String);
Var N,T: String; P: Integer;
Begin
 If AbsMode Then Exit;
 OffMode:=False;
 LastGlobal:='';
 If (AO.Fmt=1) And (Pos(',',Args)=0) Then Begin GstSection(Op,Args);Exit;End;
 If (Op='TEXT') Or (Op='CODE') Then CurSect:=SEC_TEXT
 Else If Op='DATA' Then CurSect:=SEC_DATA
 Else If Op='BSS' Then CurSect:=SEC_BSS
 Else Begin
  N:=Upper(TrimS(Args));
  P:=Pos(',',N);
  If P>0 Then Begin
   { SECTION nom,type (Amiga / Lattice) }
   T:=TrimS(Copy(N,P+1,40));
   If (AO.Fmt=7) And (Copy(T,1,4)<>'CODE') And (Copy(T,1,4)<>'DATA') And
     (Copy(T,1,3)<>'BSS') Then
    Err3('invalid section type','Type de section invalide',
      'Ungueltiger Sektionstyp');
   If Copy(T,1,4)='DATA' Then CurSect:=SEC_DATA
   Else If Copy(T,1,3)='BSS' Then CurSect:=SEC_BSS
   Else CurSect:=SEC_TEXT;
   Exit;
  End;
  If N='' Then Begin
    Err3('invalid section specified','Section invalide',
    'Ungueltige Sektion');Exit;End;
  If (N='TEXT') Or (N='CODE') Then CurSect:=SEC_TEXT
  Else If N='DATA' Then CurSect:=SEC_DATA
  Else If N='BSS' Then CurSect:=SEC_BSS
  Else Begin
   Err3('invalid section name, TEXT assumed',
     'Nom de section invalide, TEXT suppose',
     'Ungueltiger Sektionsname, TEXT angenomme'+'n');
   CurSect:=SEC_TEXT;
  End;
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

{ ---------------------------------------------------------------------- }
{ Directives de listing                                                   }
{ ---------------------------------------------------------------------- }

Procedure DirFormat(Const Args: String);
Var P: Integer; S: String;
Begin
 P:=1;
 While NextOperand(Args,P,S) Do Begin
  If (Length(S)<>2) Or (S[1]<'0') Or (S[1]>'2') Or ((S[2]<>'+') And
    (S[2]<>'-')) Then Begin
   Err3('invalid FORMAT parameter','Parametre FORMAT invalide',
     'Ungueltiger FORMAT-Parameter');
   Exit;
  End;
  ListFmt[Ord(S[1])-48]:=S[2]='+';
 End;
End;

Procedure DirListChar(Const Args: String);
Var P: Integer; S: String; R: TTV;
Begin
 P:=1;
 While NextOperand(Args,P,S) Do Begin
  If EvalStr(S,R) Then
   If (AsmPassNo=2) And ListOn Then Write(ListF,Chr(R.V And $FF));
 End;
End;

Function ListTextArg(Const Args: String): String;
Begin
 ListTextArg:=Copy(StrOperand(Args),1,80);
End;

{ ---------------------------------------------------------------------- }
{ Directive                                                               }
{ ---------------------------------------------------------------------- }

{ Traite une directive ; retourne True si Op en est une }
Function Directive(Const Lbl,Op,Args: String; Sz: Integer): Boolean;
Var R,R2: TTV; V: LongInt; Parts: Array[0..3] Of String; N,K: Integer; I:
  LongInt;
    FN,Full,S2,Nm: String; Lines: PLineArr; Cnt: LongInt; Cnt2: Integer; P:
      Pointer; Len: LongInt;
    SzB: Integer; Sy: PSym; Mk: LongInt; Pp: Integer; Ofs: LongInt; Ch: Char;
      EV: Extended;
Begin
 Directive:=True;
 If ((Op='DC') Or (Op='DS') Or (Op='DCB')) And (Sz>=8) Then Begin
   DirFloat(Op,Args,Sz);Exit;End;
 If Op='FEQU' Then Begin
  If Lbl='' Then Begin
    Err3('symbol expected','Etiquette attendue','Label erwartet');Exit;End;
  If (Sz=2) Or (Sz=4) Then Begin
   If Not EvalStr(Args,R) Then Begin R.V:=0;R.S:=SEC_ABS;End;
   DefSym(Lbl,R.V,R.S,0);Exit;
  End;
  If (Sz<8) Then Begin
    Err3('invalid size','Taille invalide','Ungueltige Groesse');Exit;End;
  If FequValue(Args,Sz,EV) Then FeqSet(Lbl,EV);
  Exit;
 End;
 If Op='FOPT' Then Begin
  Pp:=1;
  While NextOperand(Args,Pp,S2) Do Begin
   S2:=Upper(S2);
   If Copy(S2,1,3)='ID=' Then Begin
    If EvalStr(Copy(S2,4,20),R) Then Begin If (R.V<0) Or (R.V>7) Then BadOption
      Else AO.FpId:=R.V;End;
   End Else If (Copy(S2,1,6)='ROUND=') And (Length(S2)=7) And (S2[7] In
     ['N','Z','P','M']) Then Begin End
   Else If (Copy(S2,1,5)='PREC=') And (Length(S2)=6) And (S2[6] In
     ['X','S','D']) Then Begin End
   Else BadOption;
  End;
  Exit;
 End;
 If Sz=0 Then SzB:=2 Else If Sz=8 Then SzB:=1 Else SzB:=Sz;
 If Op='DC' Then Begin DirDC(Sz,Args);Exit;End;
 If Op='DS' Then Begin
  FwdRef:=False;
  If Not EvalStr(Args,R) Then R.V:=0;
  If FwdRef Then Begin
   Err3('absolute expression MUST evaluate',
     'L''expression absolue doit etre evaluabl'+'e',
     'Absoluter Ausdruck muss auswertbar sein');
   Exit;
  End;
  If R.S>=0 Then
    Err3('relative not allowed','Relatif interdit','Relativ nicht erlaubt');
  If R.X>0 Then
    Err3('imported label not allowed','Etiquette importee interdite',
    'Importiertes Label nicht erlaubt');
  If R.V<0 Then Begin
   Err3('DCB or DS count must not be negative','DCB/DS negatif',
     'DCB/DS negativ');R.V:=0;
  End;
  ReserveBytes(R.V*SzB);
  Exit;
 End;
 If Op='DCB' Then Begin
  N:=SplitTop(Args,Parts,4);
  If (N<1) Or (N>2) Then Begin
    Err3('expression mismatch','Operande attendue','Operand erwartet');Exit;End;
  FwdRef:=False;
  If Not EvalStr(Parts[0],R) Then R.V:=0;
  If FwdRef Then Begin
   Err3('absolute expression MUST evaluate',
     'L''expression absolue doit etre evaluabl'+'e',
     'Absoluter Ausdruck muss auswertbar sein');
   Exit;
  End;
  K:=R.V;
  If R.V<0 Then Begin
   Err3('DCB or DS count must not be negative','DCB/DS negatif',
     'DCB/DS negativ');K:=0;
  End;
  R.V:=0;R.S:=SEC_ABS;
  If N=2 Then If Not EvalStr(Parts[1],R) Then R.V:=0;
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
  If N<>2 Then Begin
    Err3('expression mismatch','Operande attendue','Operand erwartet');Exit;End;
  If Not EvalStr(Parts[0],R) Then R.V:=0;
  V:=R.V;
  If Not EvalStr(Parts[1],R) Then R.V:=1;
  If R.V<=0 Then R.V:=1;
  { le vrai GenST : alignement d'abord, puis ajout du decalage }
  N:=((CurPC+R.V-1) Div R.V)*R.V+V;
  While CurPC<N Do ReserveBytes(1);
  Exit;
 End;
 If Op='ORG' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If Not AbsMode And Not OffMode And (SecLen[1]=0) And (SecLen[2]=0) Then Begin
   AbsMode:=True;OrgAddr:=R.V-SecLen[0];
   If AO.Fmt=1 Then Begin GstOrgN:=1;GstOrgPos[1]:=0;GstOrgAddr[1]:=R.V;End;
  End Else If AbsMode And (AO.Fmt=1) Then Begin
   { GST : le ORG est transmis a l'editeur de liens }
   If GstOrgN<200 Then Begin
     Inc(GstOrgN);GstOrgPos[GstOrgN]:=SecLen[0];GstOrgAddr[GstOrgN]:=R.V;End;
   OrgAddr:=R.V-SecLen[0];
  End Else If AbsMode Then Begin
   { le vrai GenST ne remplit pas : le compteur change simplement }
   OrgAddr:=R.V-SecLen[0];
  End Else Err3('ORG/RORG not allowed','ORG doit etre la premiere instruction',
                'ORG muss die erste Anweisung sein');
  Exit;
 End;
 If Op='RORG' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If OffMode Or (CurSect=SEC_BSS) Then
    Err3('ORG/RORG not allowed','ORG/RORG nicht erlaubt',
    'ORG/RORG nicht erlaubt')
  Else Begin
   K:=0;
   If AbsMode Then V:=R.V-CurPC Else V:=R.V-SecLen[CurSect];
   If V<0 Then
     Err3('ORG/RORG not allowed','RORG recule','RORG geht rueckwaerts')
   Else Begin
    If (AO.Fmt=1) And (V>0) And (GstGapN<200) Then Begin
     { GST : pas de remplissage, directive OFFSET vers l'editeur de liens }
     Inc(GstGapN);GstGapSec[GstGapN]:=CurSect;GstGapPos[GstGapN]:=SecLen[CurSect
       ];GstGapEnd[GstGapN]:=SecLen[CurSect]+V;
     If AbsMode Then Begin
       GstGapSec[GstGapN]:=0;GstGapPos[GstGapN]:=SecLen[0];GstGapEnd[GstGapN]:=
       SecLen[0]+V;End;
    End;
    ReserveBytes(V);
   End;
  End;
  Exit;
 End;
 If Op='OFFSET' Then Begin
  If Not AbsMode Then Begin
   OffMode:=True;
   If TrimS(Args)<>'' Then Begin
    If EvalStr(Args,R) Then OffPC:=R.V;
   End;
  End Else
    Err3('ORG/RORG not allowed','OFFSET interdit apres ORG',
    'OFFSET nach ORG nicht erlaubt');
  Exit;
 End;
 If (Op='SECTION') Or (Op='TEXT') Or (Op='DATA') Or (Op='BSS') Then Begin
  DirSection(Op,Args);Exit;
 End;
 If (Op='EQU') Or (Op='=') Or (Op='SET') Then Begin
  If Lbl='' Then Begin
    Err3('symbol expected','Etiquette attendue','Label erwartet');Exit;End;
  FwdRef:=False;
  If IsLocalName(Lbl) Then Begin
    Err3('local not allowed','Etiquette locale non permise',
    'Lokales Label nicht erlaubt');Exit;End;
  If Not EvalStr(Args,R) Then Begin R.V:=0;R.S:=SEC_ABS;End
  Else If R.X>0 Then Begin
    Err3('imported label not allowed','Etiquette importee interdite',
    'Importiertes Label nicht erlaubt');R.V:=0;R.S:=SEC_ABS;End
  Else If FwdRef And (Op<>'SET') Then Begin
    Err3('forward reference','Reference en avant','Vorwaertsreferenz');Exit;End;
  ListIsEqu:=True;ListEquVal:=R.V;
  If Op='SET' Then DefSym(Lbl,R.V,R.S,1) Else DefSym(Lbl,R.V,R.S,0);
  Exit;
 End;
 If Op='EQUR' Then Begin
  If Lbl='' Then Begin
    Err3('symbol expected','Etiquette attendue','Label erwartet');Exit;End;
  K:=RegOf(Upper(TrimS(Args)));
  If (K<0) Or (K>15) Then Begin
    Err3('register expected','Registre attendu','Register erwartet');Exit;End;
  S2:=Upper(Lbl);
  N:=1;
  While (N<=EqurN) And (EqurName[N]<>S2) Do Inc(N);
  If N>EqurN Then Begin
   If EqurN>=64 Then Begin
     Err3('out of memory','Trop de synonymes','Zu viele Synonyme');Exit;End;
   Inc(EqurN);
  End Else If (AsmPassNo=1) And (Pass1Idx=0) Then Begin
   Err3('symbol defined twice','Symbole deja defini',
     'Symbol bereits definiert');Exit;
  End;
  EqurName[N]:=Copy(S2,1,40);EqurReg[N]:=K;
  Exit;
 End;
 If Op='EQUENV' Then Begin
  If Lbl='' Then Begin
    Err3('symbol expected','Etiquette attendue','Label erwartet');Exit;End;
  S2:=GetEnv(TrimS(Args));
  If S2='' Then Begin
   Err3('undefined symbol: '+TrimS(Args),'Symbole non defini : '+TrimS(Args),
     'Undefiniertes Symbol: '+TrimS(Args));
   Exit;
  End;
  If Not EvalStr(S2,R) Then Begin R.V:=0;R.S:=SEC_ABS;End;
  DefSym(Lbl,R.V,R.S,0);
  Exit;
 End;
 If Op='REG' Then Begin
  If Lbl='' Then Begin
    Err3('symbol expected','Etiquette attendue','Label erwartet');Exit;End;
  If Not ParseRegList(Upper(TrimS(Args)),Mk) Then Begin
   N:=RegOf(Upper(TrimS(Args)));
   If (N>=0) And (N<16) Then Mk:=LongInt(1) Shl N
   Else Begin
     Err3('invalid register list','Liste de registres incorrecte',
     'Falsche Registerliste');Exit;End;
  End;
  DefSym(Lbl,Mk,SEC_ABS,2);
  Exit;
 End;
 If Op='CARGS' Then Begin
  Ofs:=4;
  Pp:=1;
  If NextOperand(Args,Pp,S2) Then Begin
   Repeat
    If (S2<>'') And (S2[1]='#') Then Begin
     If EvalStr(Copy(S2,2,200),R) Then Ofs:=R.V;
    End Else If S2<>'' Then Begin
     K:=2;
     Nm:=S2;
     I:=Length(S2);
     If (I>2) And (S2[I-1]='.') Then Begin
      Ch:=UpCase(S2[I]);
      Nm:=Copy(S2,1,I-2);
      If Ch='L' Then K:=4 Else If (Ch='W') Or (Ch='B') Then K:=2
      Else Begin
        Nm:=S2;Err3('invalid size','Taille invalide','Ungueltige Groesse');End;
     End;
     DefSym(Nm,Ofs,SEC_ABS,0);
     Ofs:=Ofs+K;
    End;
   Until Not NextOperand(Args,Pp,S2);
  End;
  Exit;
 End;
 If Op='RSRESET' Then Begin CurRS:=0;Exit;End;
 If Op='RSSET' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  CurRS:=R.V;Exit;
 End;
 If Op='RS' Then Begin
  If Not EvalStr(Args,R) Then R.V:=0;
  If SzB>1 Then If Odd(CurRS) Then Inc(CurRS);
  ListIsEqu:=True;ListEquVal:=CurRS;
  If Lbl<>'' Then DefSym(Lbl,CurRS,SEC_ABS,0);
  CurRS:=CurRS+R.V*SzB;
  Exit;
 End;
 If Op='RADIX' Then Begin
  S2:=TrimS(Args);
  If (S2='2') Or (S2='4') Or (S2='8') Or (S2='10') Or (S2='16') Then
    NumRadix:=ToInt(S2)
  Else Err3('invalid radix','Base invalide','Ungueltige Basis');
  Exit;
 End;
 If Op='MACHINE' Then Begin
  S2:=Upper(TrimS(Args));
  If Copy(S2,1,2)='MC' Then Delete(S2,1,2);
  If S2='68000' Then AO.Proc:=68000 Else If S2='68008' Then AO.Proc:=68000
  Else If S2='68010' Then AO.Proc:=68010 Else If S2='68020' Then AO.Proc:=68020
  Else If S2='68030' Then AO.Proc:=68030 Else If S2='68040' Then AO.Proc:=68040
  Else If (S2='68332') Or (S2='CPU32') Then AO.Proc:=68332
  Else Err3('invalid option','Processeur invalide','Ungueltiger Prozessor');
  Exit;
 End;
 If (Length(Op)=7) And (Copy(Op,1,2)='MC') And (Copy(Op,3,5)<>'68881') And
   (Copy(Op,3,5)<>'68882') And
    (Copy(Op,3,3)='680') And (Op[6] In ['0'..'9']) Then Begin
  I:=ToInt(Copy(Op,3,5));
  If (I=68000) Or (I=68010) Or (I=68020) Or (I=68030) Or (I=68040) Then
    AO.Proc:=I
  Else Directive:=False;
  Exit;
 End;
 If Op='MODULE' Then Begin
  If (AO.Fmt=0) Or (AO.Fmt=6) Then
   Err3('linker format restriction','Format d''edition de liens non gere',
     'Linker-Format nicht unterstuetzt')
  Else Begin
   If AO.Fmt=1 Then GstNewModule(Copy(StrOperand(Args),1,32))
   Else ModName:=Copy(StrOperand(Args),1,32);
   For K:=1 To ModN Do If ModNames[K]=Upper(ModName) Then
     Err3('duplicate MODULE name','Nom de MODULE en double',
     'Doppelter MODULE-Name');
   If ModN<64 Then Begin
     Inc(ModN);ModNames[ModN]:=Copy(Upper(ModName),1,40);End;
  End;
  Exit;
 End;
 If (Op='IDNT') And (AO.Fmt=7) Then Begin
   ModName:=Copy(StrOperand(Args),1,32);Exit;End;
 If Op='XDEF' Then Begin
  If AO.Fmt<>0 Then Begin
   Pp:=1;
   While NextOperand(Args,Pp,S2) Do
    If (S2<>'') And (XdefN<2000) Then Begin
     K:=1;
     While (K<=XdefN) And (XdefNames[K]<>KeyOf(LocalName(S2))) Do Inc(K);
     If K>XdefN Then Begin
       Inc(XdefN);XdefNames[XdefN]:=Copy(KeyOf(LocalName(S2)),1,80);End;
     If (AsmPassNo=2) And (AO.Fmt=1) Then GEvXdef(K);
    End;
  End;
  Exit;
 End;
 If Op='XREF' Then Begin
  If (AO.Fmt=0) Or (AO.Fmt=6) Then Begin
   Err3('linker format restriction','Format d''edition de liens non gere',
     'Linker-Format nicht unterstuetzt');Exit;
  End;
  Pp:=1;
  While NextOperand(Args,Pp,S2) Do Begin
   If S2='' Then Continue;
   Sy:=LookupSym(ModKey(LocalName(S2)));
   If (Sy=Nil) And (ModIdx>0) Then Begin Sy:=FindSym(LocalName(S2));If
     (Sy<>Nil) And (Sy^.Kind=3) Then Sy:=Nil;End;
   If (Sy<>Nil) And Sy^.Defd And (Sy^.Pas=PassSerial) Then Begin
    If Sy^.Kind<>3 Then
      Err3('cannot import symbol','Symbole non importable',
      'Symbol nicht importierbar');
    Continue;
   End;
   If ImpN>=2000 Then Begin
     Err3('out of memory','Trop d''imports','Zu viele Importe');Continue;End;
   If Sy=Nil Then Sy:=AddSym(ModKey(LocalName(S2)));
   Inc(ImpN);ImpNames[ImpN]:=Copy(Sy^.Name,1,80);
   If Pos('^',ImpNames[ImpN])>0 Then
     ImpNames[ImpN]:=Copy(ImpNames[ImpN],1,Pos('^',ImpNames[ImpN])-1);
   Sy^.Value:=ImpN;Sy^.Kind:=3;Sy^.Defd:=True;Sy^.Pas:=PassSerial;
   If Sz=4 Then Sy^.Sect:=SEC_ABS Else Sy^.Sect:=SEC_EXT;
  End;
  Exit;
 End;
 If (Op='CSECT') And (AO.Fmt=7) Then Begin
  S2:=Upper(TrimS(Args));Pp:=Pos(',',S2);
  If Pp>0 Then Begin
   K:=ToInt(TrimS(Copy(S2,Pp+1,10)));
   If K=1 Then DirSection('DATA','') Else If K=2 Then DirSection('BSS','') Else
     DirSection('TEXT','');
  End Else DirSection('TEXT','');
  Exit;
 End;
 If (Op='INCLUDE') Or (Op='INCBIN') Then Begin
  FN:=StrOperand(Args);
  If (FN<>'') And (FN[1]='<') Then FN:=Copy(FN,2,Length(FN)-2);
  If FN='' Then Exit;
  If (Op='INCLUDE') And GsIsSeen(FN) Then Exit;
  Full:=FindInclude(FN);
  If Op='INCLUDE' Then Begin
   { fichier pre-assemble .GS de meme nom ? }
   S2:=ChangeExt(FN,'GS');
   Nm:=FindInclude(S2);
   If (Nm<>'') And (Full<>'') And (ExistCI(ChangeExt(Full,'GS'))<>'') Then
     Nm:=ExistCI(ChangeExt(Full,'GS'));
   If Nm<>'' Then Begin
    LoadGS(Nm);GsAddSeen(FN);
    Exit;
   End;
  End;
  If Full='' Then Begin
   If Op='INCLUDE' Then
     FatalErr3('file not found','Fichier introuvable : '+FN,
     'Datei nicht gefunden: '+FN)
   Else
     Err3('file not found','Fichier introuvable : '+FN,'Datei nicht gefunden: '+
     FN);
   Exit;
  End;
  If Op='INCLUDE' Then Begin
   If AO.Inconce Then Begin
    S2:=Upper(Full);
    For N:=1 To IncSeenN Do If IncSeen[N]=S2 Then Exit;
    If IncSeenN<200 Then Begin
      Inc(IncSeenN);IncSeen[IncSeenN]:=Copy(S2,1,120);End;
   End;
   If GsInclN<64 Then Begin Inc(GsInclN);GsIncl[GsInclN]:=Copy(FN,1,120);End;
   If LoadLinesBig(Full,Lines,Cnt) Then Begin
    If LongLines>0 Then Begin
     Err3('line malformed','Ligne trop longue','Zeile zu lang');LongLines:=0;
    End;
    PushSrc(0,Lines,Cnt,Full,True);
   End Else
     FatalErr3('include file read error','Erreur de lecture : '+FN,
     'Lesefehler: '+FN);
  End Else Begin
   EvenPC;
   If ReadFileBytes(Full,P,Len) Then Begin
    For I:=0 To Len-1 Do EmitByte(PByteAt(P,I));
    If P<>Nil Then FreeMem(P,Len);
   End Else
     FatalErr3('include file read error','Erreur de lecture : '+FN,
     'Lesefehler: '+FN);
  End;
  Exit;
 End;
 If Op='INCDIR' Then Begin
  AddIncDirs(Args);
  Exit;
 End;
 If Op='OPT' Then Begin DirOpt(Args);Exit;End;
 If Op='END' Then Begin EndFlag:=True;Exit;End;
 If Op='OUTPUT' Then Begin
  If OutFileName='' Then OutFileName:=StrOperand(Args);
  Exit;
 End;
 If Op='COMMENT' Then Begin
  S2:=TrimS(Args);
  If (Copy(S2,1,5)='HEAD=') And (AO.Fmt<>1) Then Begin
   If EvalStr(Copy(S2,6,200),R) Then Begin HeadFlags:=R.V;HeadSet:=True;End;
  End Else If (AO.Fmt=1) And (GstCmtN<40) And (S2<>'') Then Begin
   Inc(GstCmtN);GstCmt[GstCmtN]:=Copy(StrOperand(Args),1,80);
   If AsmPassNo=2 Then GEvCmt(TrimS(Args));
  End;
  Exit;
 End;
 If Op='FAIL' Then Begin
  Err3('user error','FAIL : '+Args,'FAIL: '+Args);Exit;
 End;
 If Op='MEXIT' Then Begin
  K:=SrcTop;
  While (K>0) And (Srcs[K].Kind<>1) Do Dec(K);
  If K>0 Then Begin
   CondTop:=Srcs[K].CondBase;SetCondActive;
   While SrcTop>=K Do PopSrc;
  End
  Else
    Err3('spurious ENDM or MEXIT','MEXIT hors macro','MEXIT ausserhalb Makro');
  Exit;
 End;
 If Op='REPT' Then Begin
  K:=SrcTop;
  While (K>0) And (Srcs[K].Kind<>2) Do Dec(K);
  If K>0 Then Begin
   LastErrLine:=0;
   Err3('cannot nest repeat loops','REPT imbriques interdits',
     'Verschachtelte REPT nicht erlaubt');
   Exit;
  End;
  FwdRef:=False;
  If Not EvalStr(Args,R) Then R.V:=0;
  If R.S>=0 Then
    Err3('relative not allowed','Relatif interdit','Relativ nicht erlaubt');
  If R.X>0 Then
    Err3('imported label not allowed','Etiquette importee interdite',
    'Importiertes Label nicht erlaubt')
  Else If FwdRef Then Begin
   Err3('absolute expression MUST evaluate',
     'L''expression absolue doit etre evaluabl'+'e',
     'Absoluter Ausdruck muss auswertbar sein');
   Exit;
  End;
  If ListWanted Then ListLine(LnText);
  Lines:=CollectBody('REPT','ENDR',Cnt2);
  ListDone:=True;
  If (R.V>0) And (Cnt2>0) Then Begin
   PushSrc(2,Lines,Cnt2,'REPT',True);
   Srcs[SrcTop].Reps:=R.V;
  End Else FreeLines(Lines,Cnt2);
  Exit;
 End;
 If Op='ENDR' Then Begin
   Err3('spurious ENDR','ENDR inattendu','ENDR unerwartet');Exit;End;
 If Op='ENDM' Then Begin
   Err3('spurious ENDM or MEXIT','ENDM inattendu','ENDM unerwartet');Exit;End;
 { listing }
 If Op='LIST' Then Begin
  S2:=TrimS(Args);
  If S2='+' Then Inc(ListCnt)
  Else If S2='-' Then Dec(ListCnt)
  Else ListCnt:=0;
  Exit;
 End;
 If Op='NOLIST' Then Begin ListCnt:=-1;Exit;End;
 If Op='PLEN' Then Begin
  If EvalStr(Args,R) Then Begin
   If (R.V<12) Or (R.V>255) Then
     Err3('data too large','Valeur hors limites','Wert ausserhalb des Bereichs')
   Else ListPLen:=R.V;
  End;
  Exit;
 End;
 If Op='LLEN' Then Begin
  If EvalStr(Args,R) Then Begin
   If (R.V<38) Or (R.V>255) Then
     Err3('data too large','Valeur hors limites','Wert ausserhalb des Bereichs')
   Else ListLLen:=R.V;
  End;
  Exit;
 End;
 If Op='TTL' Then Begin ListTitle:=ListTextArg(Args);Exit;End;
 If Op='SUBTTL' Then Begin ListSub:=ListTextArg(Args);Exit;End;
 If Op='SPC' Then Begin
  If EvalStr(Args,R) Then
   If R.V>0 Then ListSpc:=R.V;
  Exit;
 End;
 If Op='PAGE' Then Begin ListLineNo:=ListPLen;Exit;End;
 If Op='FORMAT' Then Begin DirFormat(Args);Exit;End;
 If Op='LISTCHAR' Then Begin DirListChar(Args);Exit;End;
 If (Op='IDNT') Or (Op='CSECT') Then Exit;
 If (Op='NOPAGE') Or (Op='PUBLIC') Or (Op='GLOBAL') Or (Op='EXPORT') Or
   (Op='IMPORT') Or (Op='ECHO') Or
    (Op='NOFORMAT') Or (Op='MASK2') Then Begin
  Warn3('directive ignored','Directive ignoree','Direktive ignoriert');Exit;
 End;
 Directive:=False;
End;

{ ---------------------------------------------------------------------- }
{ Traitement d'une ligne source                                           }
{ ---------------------------------------------------------------------- }

Var
 OptDebug0,OptOptimize0,OptCase0,OptWarnings0 : Boolean;
 OutPathFinal : String;
 OutIsTemp    : Boolean;
 ListDevOpen  : Boolean;

Function IsValueDirective(Const Op: String): Boolean;
Begin
 IsValueDirective:=(Op='FEQU') Or (Op='FOPT') Or (Op='EQU') Or (Op='=') Or
   (Op='SET') Or (Op='REG') Or
  (Op='EQUR') Or (Op='EQUENV') Or (Op='RS') Or (Op='RSSET') Or (Op='RSRESET')
    Or (Op='CARGS');
End;

Function ExpandTabs(Const S: String; Tab: Integer): String;
Var R: String; I: Integer;
Begin
 R:='';
 If Tab<1 Then Tab:=8;
 For I:=1 To Length(S) Do
  If S[I]=#9 Then Begin
   R:=R+' ';
   While (Length(R) Mod Tab)<>0 Do R:=R+' ';
  End Else R:=R+S[I];
 ExpandTabs:=R;
End;

Function TwoD(N: Integer): String;
Begin
 TwoD:=PadZero(N,2);
End;

Procedure ListHeader;
Var Y,Mo,D,Dw,H,Mi,Se,Hs: Word; T,L1: String;
Begin
 GetDate(Y,Mo,D,Dw);GetTime(H,Mi,Se,Hs);
 If ListTitle<>'' Then T:=ListTitle Else T:=ShortName(CurSrcName);
 If ListPage>0 Then Write(ListF,#12);
 Inc(ListPage);
 L1:=PadR(T,40)+'  '+TwoD(D)+'/'+TwoD(Mo)+'/'+TwoD(Y Mod
   100)+'  '+TwoD(H)+':'+TwoD(Mi)+':'+TwoD(Se)+'  Page '+IntStr(ListPage);
 WriteLn(ListF,Copy(L1,1,ListLLen));
 WriteLn(ListF,Copy(T,1,ListLLen));
 WriteLn(ListF,Copy(ListSub,1,ListLLen));
 WriteLn(ListF);
 ListLineNo:=4;
End;

Function ListEnabled: Boolean;
Begin
 ListEnabled:=ListOn And (ListCnt>=0);
End;

Procedure ListOut(Const Ln: String);
Var K: Integer; Rest: String;
Begin
 If (ListPage=0) And ListHold And (ListQN<8) Then Begin
  Inc(ListQN);ListQ[ListQN]:=Ln;Exit;
 End;
 If ListLineNo>=ListPLen Then ListHeader;
 For K:=1 To ListQN Do Begin
  WriteLn(ListF,Copy(ListQ[K],1,ListLLen));
  Inc(ListLineNo);
 End;
 ListQN:=0;
 { une ligne trop longue se poursuit sur la ligne suivante, comme dans le vrai
   GenST }
 Rest:=Ln;
 Repeat
  WriteLn(ListF,Copy(Rest,1,ListLLen));
  Inc(ListLineNo);
  Delete(Rest,1,ListLLen);
 Until Rest='';
End;

Procedure ListLine(Const S: String);
Var Ln,B,Scs: String; I: Integer; Sect: Integer; N: LongInt; MaxB: Integer; Sc:
  Char; Sep: Char; V: LongInt;
Begin
 If Not ListOn Then Exit;
 If ListCnt<0 Then Exit;
 For I:=1 To SrcTop Do If Srcs[I].Kind=2 Then Exit;
 If ListOnlyPass And Not LnHadMsg Then Exit;
 If ListSkip Then Begin
  While ListSpc>0 Do Begin ListOut('');Dec(ListSpc);End;
  Exit;
 End;
 If ListDone Then Exit;
 Sect:=CurSect;If AbsMode Then Sect:=0;
 If CurSect<>LnStartSect Then Sect:=LnStartSect;
 If ListLLen<80 Then MaxB:=6 Else MaxB:=20;
 N:=SecLen[Sect]-LnStartLen;
 If OffMode Or (Sect=SEC_BSS) Or (N<0) Or ListNoData Then N:=0;
 If N>MaxB Then N:=MaxB;
 Case CurSect Of
  0: Sc:='T';
  1: Sc:='D';
 Else Sc:='B';
 End;
 If AbsMode Then Sc:='T';
 If OffMode Then Sc:='O';
 If ListMacMark Then Sep:='+' Else Sep:=' ';
 Scs:=Sc+'  ';
 If AO.Fmt=1 Then Begin
  If AbsMode Then Scs:=Upper(HexN($10000-GstListId(0),2))+'.'
  Else Scs:=Upper(HexN($10000-GstListId(CurSect),2))+'.';
 End;
 Ln:='';
 If ListFmt[0] Then Ln:=PadL(IntStr(CurLineNo),5)+' ';
 If ListFmt[1] Then Begin
  If ListIsEqu Then Ln:=Ln+'  ='+Hex8(ListEquVal)+Sep
  Else If ListAfter Or ((CurSect<>LnStartSect) And Not AbsMode) Then
    Ln:=Ln+Scs+Hex8(CurPC)+Sep
  Else Ln:=Ln+Scs+Hex8(LnAddr)+Sep;
 End;
 If ListFmt[2] Then Begin
  B:='';
  For I:=0 To N-1 Do B:=B+Hex2(SecGet(Sect,LnStartLen+I));
  Ln:=Ln+PadR(B,MaxB*2+1);
 End;
 Ln:=Ln+ExpandTabs(S,OptTabSize);
 ListOut(Ln);
 While ListSpc>0 Do Begin ListOut('');Dec(ListSpc);End;
End;

Procedure ListMacEnd(Const Tx: String);
Begin
 If Not (ListWanted And AO.Mex) Then Exit;
 LnStartSect:=CurSect;
 LnStartLen:=SecLen[CurSect];
 If AbsMode Then LnStartLen:=SecLen[0];
 LnAddr:=CurPC;
 ListIsEqu:=False;ListSkip:=False;ListMacMark:=False;
 ListLine(Tx);
End;

Function InMacroExp: Boolean;
Var K: Integer;
Begin
 InMacroExp:=False;
 For K:=1 To SrcTop Do If Srcs[K].Kind=1 Then InMacroExp:=True;
End;

{ IIF expression instruction : coupe la ligne }
Procedure IIFParts(Const S: String; Var ExprS,Rest: String);
Var I,D: Integer; Q: Char; Tk: String;

 Procedure SkipB;
 Begin
  While (I<=Length(S)) And ((S[I]=' ') Or (S[I]=#9)) Do Inc(I);
 End;

Begin
 ExprS:='';Rest:='';I:=1;
 If (S<>'') And (S[1]<>' ') And (S[1]<>#9) Then Begin
  While (I<=Length(S)) And (S[I]<>' ') And (S[I]<>#9) Do Inc(I);
 End;
 SkipB;
 { etiquette indentee ? }
 Tk:='';
 While (I<=Length(S)) And (S[I]<>' ') And (S[I]<>#9) Do Begin
   Tk:=Tk+S[I];Inc(I);End;
 If (Tk<>'') And (Tk[Length(Tk)]=':') Then Begin
  SkipB;
  Tk:='';
  While (I<=Length(S)) And (S[I]<>' ') And (S[I]<>#9) Do Begin
    Tk:=Tk+S[I];Inc(I);End;
 End;
 SkipB;
 Q:=#0;D:=0;
 While I<=Length(S) Do Begin
  If Q<>#0 Then Begin ExprS:=ExprS+S[I];If S[I]=Q Then Q:=#0;Inc(I);End
  Else If (S[I]='''') Or (S[I]='"') Then Begin
    Q:=S[I];ExprS:=ExprS+S[I];Inc(I);End
  Else If S[I]='(' Then Begin Inc(D);ExprS:=ExprS+S[I];Inc(I);End
  Else If S[I]=')' Then Begin Dec(D);ExprS:=ExprS+S[I];Inc(I);End
  Else If ((S[I]=' ') Or (S[I]=#9)) And (D<=0) Then Break
  Else Begin ExprS:=ExprS+S[I];Inc(I);End;
 End;
 SkipB;
 Rest:=Copy(S,I,255);
End;

{ ---------------------------------------------------------------------- }
{ Informations de ligne (OPT LINE / OPT HCLN) : voir LINE_FORMAT.md        }
{ ---------------------------------------------------------------------- }

Var
 LnRecN,LnRecCap : LongInt;
 LnRecLine,LnRecAddr,LnRecFile : PLongArr;
 LnFiles : Array[1..64] Of String[120];
 LnFileN : Integer;

Procedure LnRecReset;
Begin
 LnRecN:=0;LnFileN:=0;
 If LnRecLine=Nil Then Begin
  LnRecCap:=4096;
  GetMem(LnRecLine,LnRecCap*4+8);GetMem(LnRecAddr,LnRecCap*4+
    8);GetMem(LnRecFile,LnRecCap*4+8);
 End;
End;

Procedure RecLineInfo;
Var Sect,K,Fi: Integer; A,B,C: PLongArr; NC: LongInt;
Begin
 If (AsmPassNo<>2) Or Not (AO.Line Or AO.Hcln) Or AbsMode Or OffMode Then Exit;
 Sect:=LnStartSect;
 If (Sect<0) Or (Sect>1) Then Exit;
 If SecLen[Sect]<=LnStartLen Then Exit;
 Fi:=0;
 For K:=1 To LnFileN Do If LnFiles[K]=CurSrcName Then Fi:=K;
 If Fi=0 Then Begin
  If LnFileN>=64 Then Exit;
  Inc(LnFileN);LnFiles[LnFileN]:=Copy(CurSrcName,1,120);Fi:=LnFileN;
 End;
 If LnRecN>=LnRecCap Then Begin
  NC:=LnRecCap*2;
  GetMem(A,NC*4+8);GetMem(B,NC*4+8);GetMem(C,NC*4+8);
  Move(LnRecLine^,A^,(LnRecN+1)*4);Move(LnRecAddr^,B^,(LnRecN+
    1)*4);Move(LnRecFile^,C^,(LnRecN+1)*4);
  FreeMem(LnRecLine,LnRecCap*4+8);FreeMem(LnRecAddr,LnRecCap*4+
    8);FreeMem(LnRecFile,LnRecCap*4+8);
  LnRecLine:=A;LnRecAddr:=B;LnRecFile:=C;LnRecCap:=NC;
 End;
 Inc(LnRecN);
 LnRecLine^[LnRecN]:=CurLineNo;
 LnRecAddr^[LnRecN]:=SecBase[Sect]+LnStartLen;
 LnRecFile^[LnRecN]:=Fi;
End;

Procedure ProcessLine(Const S: String); Forward;

Procedure ProcessLine0(Const S: String);
Var Lbl,Op,Suf,Args,Ex,Rest: String; Sz,M: Integer; Even,IsInstr,WasMac:
  Boolean; R: TTV;
Begin
 LnText:=S;
 LnStartSect:=CurSect;
 ListIsEqu:=False;ListSkip:=False;ListMacMark:=False;ListAfter:=False;ListNoData
   :=False;ListDone:=False;LnHadMsg:=False;
 WasMac:=InMacroExp;
 SplitLine(S,Lbl,Op,Suf,Args);
 ListSkip:=(Op='LIST') Or (Op='NOLIST') Or (Op='TTL') Or (Op='SUBTTL') Or
   (Op='SPC') Or (Op='PAGE') Or (Op='PLEN') Or (Op='LLEN');
 ListMacMark:=WasMac And AO.Mex;
 ListAfter:=(Op='EVEN') Or (Op='ORG') Or (Op='OFFSET') Or (Op='SECTION') Or
   (Op='TEXT') Or (Op='DATA') Or (Op='BSS') Or (Op='ALIGN') Or (Op='RORG');
 ListNoData:=(Op='DS') Or (Op='DCB') Or (Op='EVEN');
 ListHold:=(Op='TTL') Or (Op='SUBTTL') Or (Op='PLEN') Or (Op='LLEN') Or
   (Op='FORMAT');
 LnStartLen:=SecLen[CurSect];
 If AbsMode Then LnStartLen:=SecLen[0];
 LnAddr:=CurPC;
 If (Op<>'') And CondDirective(Op,Args) Then Begin
  If AO.TraceIf And (AsmPassNo=1) And (Pass1Idx=0) And ListOn Then
   ListOut(PadL(IntStr(CurLineNo),5)+'  '+PadR(Op,8)+' cond. level '+
     IntStr(CondTop)+' active='+IntStr(Ord(CondActive)));
  If ListWanted And (Not WasMac Or AO.Mex) Then ListLine(S);
  Exit;
 End;
 If Not CondActive Then Begin
  If ListWanted And (Not WasMac Or AO.Mex) Then Begin
    ListSkip:=False;ListLine(S);End;
  Exit;
 End;
 If Op='' Then Begin
  If Lbl<>'' Then DefLabel(Lbl);
  If ListWanted And (Not WasMac Or AO.Mex) Then ListLine(S);
  Exit;
 End;
 If (Op='IIF') And (FindMacro('IIF')=0) Then Begin
  IIFParts(S,Ex,Rest);
  If Ex='' Then Begin
    Err3('expression mismatch','Operande attendue','Operand erwartet');Exit;End;
  If Not EvalStr(Ex,R) Then R.V:=0;
  If R.V<>0 Then ProcessLine(Lbl+' '+Rest)
  Else If Lbl<>'' Then ProcessLine(Lbl);
  Exit;
 End;
 Sz:=0;
 If Suf<>'' Then Begin
  Case Suf[1] Of
   'B': Sz:=1;
   'W': Sz:=2;
   'L': Sz:=4;
   'S': Sz:=8;
   'D': Sz:=16;
   'X': Sz:=32;
   'P': Sz:=64;
  Else
    Err3('invalid size','Suffixe de taille incorrect','Falsche Groessenangabe');
  End;
  If Length(Suf)>1 Then
    Err3('invalid size','Suffixe de taille incorrect','Falsche Groessenangabe');
 End;
 LnSz:=Sz;
 LnArgs:=Args;
 If Op='MACRO' Then Begin
  If ListWanted Then ListLine(S);
  If Lbl<>'' Then DefineMacro(Lbl,Args,Suf) Else
    DefineMacro(TrimS(Args),'',Suf);
  Exit;
 End;
 M:=FindMacro(Op);
 { une macro ne remplace pas une directive (GenST 2.23 ignore aussi les macros
   de nom d'instruction ; ici elles restent prioritaires :
   SAMPLES/DEVPAC/shelscrp.s) }
 If (M<>0) And IsDirName(Op) Then M:=0;
 If IsValueDirective(Op) And (M=0) Then Begin
  Directive(Lbl,Op,Args,Sz);
  If ListWanted And (Not WasMac Or AO.Mex) Then ListLine(S);
  Exit;
 End;
 IsInstr:=IsMnemonic(Op) And (M=0);
 Even:=IsInstr Or (((Op='DC') Or (Op='DCB')) And ((Sz=2) Or (Sz=4) Or (Sz=0) Or
   (Sz>=8))) Or
       ((Op='DS') And ((Sz=2) Or (Sz=4) Or (Sz=0) Or (Sz>=8)));
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
  Err3('instruction not recognised','Code operation inconnu : '+Op,
    'Unbekannter Befehl: '+Op);
 If AsmPassNo=2 Then RecLineInfo;
 If ListWanted And (Not WasMac Or AO.Mex) And ((M=0) Or AO.Mex) Then Begin
  If M<>0 Then ListMacMark:=True;
  ListLine(S);
 End;
End;

Procedure ProcessLine(Const S: String);
Var L,O,Sf,A: String;
Begin
 ProcessLine0(S);
 If (AsmPassNo=2) And (AO.Fmt=1) And Not AbsMode Then Begin
  SplitLine(S,L,O,Sf,A);
  If (O='SECTION') Or (O='TEXT') Or (O='DATA') Or (O='BSS') Or (O='CODE') Then
   If CondActive Then GEvSection;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Passes                                                                  }
{ ---------------------------------------------------------------------- }

Function EvenUp(N: LongInt): LongInt;
Begin
 If Odd(N) Then EvenUp:=N+1 Else EvenUp:=N;
End;

{ Symboles de la ligne de commande (-E, /DEF:) : a=expr,b }
Procedure ApplyCmdSyms;
Var P,K: Integer; S,Nm: String; R: TTV;
Begin
 If CmdSyms='' Then Exit;
 P:=1;
 While NextOperand(CmdSyms,P,S) Do Begin
  If S='' Then Continue;
  K:=Pos('=',S);
  If K>0 Then Begin
   Nm:=TrimS(Copy(S,1,K-1));
   If EvalStr(Copy(S,K+1,200),R) Then DefSym(Nm,R.V,R.S,0)
   Else
     Err3('error in command line symbol',
     'Erreur de symbole en ligne de commande','Fehler im Kommandozeilensymbol');
  End Else DefSym(TrimS(S),1,SEC_ABS,0);
 End;
End;

Procedure RunPass(Lines: PLineArr; Count: LongInt);
Var S: String; I: Integer; Q: Integer;
Begin
 Inc(PassSerial);
 For I:=0 To 2 Do SecLen[I]:=0;
 CurSect:=SEC_TEXT;AbsMode:=False;OrgAddr:=0;OffMode:=False;OffPC:=0;
 RelocN:=0;DecIdx:=0;CondTop:=0;CondActive:=True;SrcTop:=0;
 FreeMacros;
 EndFlag:=False;CurRS:=0;LastGlobal:='';MacUniq:=0;LastErrLine:=0;LastWarnLine:=
   0;
 NumRadix:=10;EqurN:=0;FeqN:=0;ModN:=0;ModIdx:=0;GstGapN:=0;GstOrgN:=0;GstCmtN:=
   0;GstSecName[0]:='TEXT';GstSecName[1]:='DATA';GstSecName[2]:='BSS';GstSecCust
   [0]:=False;GstSecCust[1]:=False;GstSecCust[2]:=False;ErrOvr:='';IncSeenN:=0;
   GsSeenN:=0;GsInclN:=0;OptCount:=0;OptSaved:=0;ImpN:=0;XdefN:=0;ModName:='';
   IncDirN:=0;HeadSet:=False;HeadFlags:=0;
 AO:=AO0;
 LnRecReset;
 OptDebug:=OptDebug0;OptOptimize:=OptOptimize0;OptCase:=OptCase0;OptWarnings:=
   OptWarnings0;
 OutFileName:='';
 AsmLines:=0;
 If OptIncPath<>'' Then AddIncDirs(OptIncPath);
 If OptIncList<>'' Then AddIncDirs(OptIncList);
 If OptListing Then ListCnt:=0 Else ListCnt:=-1;
 ListPLen:=60;ListLLen:=132;ListPage:=0;ListLineNo:=ListPLen;
 ListTitle:='';ListSub:='';ListSpc:=0;ListQN:=0;ListHold:=False;
 For Q:=0 To 2 Do ListFmt[Q]:=True;
 PushSrc(0,Lines,Count,AsmFileName,False);
 CurSrcName:=AsmFileName;
 If CmdOpts<>'' Then DirOpt(CmdOpts);
 ApplyCmdSyms;
 If CmdHeaders<>'' Then LoadHeaders(CmdHeaders);
 While (Not EndFlag) And (Not AsmFatal) And NextLine(S) Do Begin
  Inc(AsmLines);
  JoinContinuation(S);
  ProcessLine(S);
 End;
 While SrcTop>0 Do PopSrc;
 If (CondTop>0) And Not CondActive And (Not AsmFatal) Then Begin
  { IF inactif jamais ferme : erreur fatale du vrai GenST }
  CurLineNo:=CondLn[1];CurSrcName:=AsmFileName;LnText:='';
  FatalErr3('source expired prematurely','Fin de fichier inattendue',
    'Unerwartetes Dateiende');
 End Else If (AsmPassNo=2) And (CondTop>0) Then Begin
  CurLineNo:=CondLn[1];CurSrcName:=AsmFileName;LnText:='';
  Err3('missing ENDC','ENDC manquant','ENDC fehlt');
  LastErrLine:=0;
  Err3('missing ENDC','ENDC manquant','ENDC fehlt');
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
 If AmigaMode Or AbsMode Or (AO.Fmt=1) Or (AO.Fmt=2) Or (AO.Fmt=7) Then Begin
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

Var OutFail: Boolean;

Procedure OutFlush;
Begin
 {$I-}
 If OPos>0 Then BlockWrite(OutF,OBuf,OPos);
 If IOResult<>0 Then OutFail:=True;
 {$I+}
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
 OPos:=0;OutFail:=False;
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
 { le vrai GenST : tous les symboles sont definis+globaux ($A000), valeur
   relative a la section }
 T:=$A000;
 Case P^.Sect Of
  0: T:=T Or $0200;
  1: T:=T Or $0400;
  2: T:=T Or $0100;
 End;
 If AbsMode Then V:=P^.Value+SecBase[P^.Sect] Else V:=P^.Value;
 SymTypeOf:=True;
End;

Type
 TSymPtrArr = Array[0..30000] Of PSym;
 PSymPtrArr = ^TSymPtrArr;

Var
 PrgSyms : PSymPtrArr;
 PrgSymN : LongInt;

{ liste triee (longueur du nom puis ordre ASCII) comme le vrai GenST }
Var PrgSymCap: LongInt;

Procedure AllocSymPtrs;
Var H: Integer; P: PSym; N: LongInt;
Begin
 N:=0;
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin Inc(N);P:=P^.Next;End;
 End;
 PrgSymCap:=N+2;
 GetMem(PrgSyms,PrgSymCap*SizeOf(PSym));
End;

Procedure FreeSymPtrs;
Begin
 If PrgSyms<>Nil Then FreeMem(PrgSyms,PrgSymCap*SizeOf(PSym));
 PrgSyms:=Nil;
End;

Procedure SortSymPtrs;
Var X: PSym; Gap,I,J: LongInt; Lt: Boolean;
Begin
 Gap:=PrgSymN Div 2;
 While Gap>0 Do Begin
  For I:=Gap To PrgSymN-1 Do Begin
   X:=PrgSyms^[I];J:=I;
   Repeat
    If J<Gap Then Lt:=False
    Else If Length(PrgSyms^[J-Gap]^.Name)<>Length(X^.Name) Then
      Lt:=Length(PrgSyms^[J-Gap]^.Name)>Length(X^.Name)
    Else Lt:=PrgSyms^[J-Gap]^.Name>X^.Name;
    If Lt Then Begin PrgSyms^[J]:=PrgSyms^[J-Gap];J:=J-Gap;End;
   Until Not Lt;
   PrgSyms^[J]:=X;
  End;
  Gap:=Gap Div 2;
 End;
End;

Procedure CollectPrgSyms;
Var H: Integer; P: PSym; T: Word; V: LongInt;
Begin
 PrgSymN:=0;
 AllocSymPtrs;
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin
   If (PrgSymN<PrgSymCap) And SymTypeOf(P,T,V) Then Begin
    PrgSyms^[PrgSymN]:=P;Inc(PrgSymN);
   End;
   P:=P^.Next;
  End;
 End;
 SortSymPtrs;
End;

Function PrgSymbolBytes: LongInt;
Var I: Integer; N: LongInt;
Begin
 N:=PrgSymN;
 If AO.XDebug Then
  For I:=0 To PrgSymN-1 Do If Length(PrgSyms^[I]^.Name)>8 Then Inc(N);
 PrgSymbolBytes:=N*14;
End;

Procedure SortLongs(Var A: TLongArr; N: LongInt);
Var Gap,I,J: LongInt; T: LongInt;
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

{ ordre des enregistrements de ligne : (fichier, deplacement, rang) }
Function LnLess(I,J: LongInt): Boolean;
Begin
 If LnRecFile^[I]<>LnRecFile^[J] Then LnLess:=LnRecFile^[I]<LnRecFile^[J]
 Else If LnRecAddr^[I]<>LnRecAddr^[J] Then LnLess:=LnRecAddr^[I]<LnRecAddr^[J]
 Else LnLess:=I<J;
End;

Procedure OutBytes(Const S: String);
Var I: Integer;
Begin
 For I:=1 To Length(S) Do OutByte(Ord(S[I]));
End;

Procedure WriteLineSections;
Var Idx: PLongArr; Gap,I,J,T,K,F,N,St,Cnt,PrevA,PrevL,D: LongInt; Len: LongInt;
    Nm: String; Pass: Integer; Hc: Boolean;

 Procedure Entry(Ix: LongInt);
 Begin
  D:=LnRecAddr^[Ix]-PrevA;
  If D<=250 Then OutByte(D)
  Else If D<=65535 Then Begin OutByte(251);OutWord(D);End
  Else Begin OutByte(252);OutLong(D);End;
  D:=LnRecLine^[Ix]-PrevL;
  If (D>=-127) And (D<=127) Then OutByte(D And $FF)
  Else Begin OutByte($80);OutLong(D);End;
  PrevA:=LnRecAddr^[Ix];PrevL:=LnRecLine^[Ix];
 End;

Begin
 If (LnRecN=0) Or Not (AO.Line Or AO.Hcln) Then Exit;
 GetMem(Idx,(LnRecN+2)*4);
 For I:=1 To LnRecN Do Idx^[I]:=I;
 Gap:=LnRecN Div 2;
 While Gap>0 Do Begin
  For I:=Gap+1 To LnRecN Do Begin
   T:=Idx^[I];J:=I;
   While (J>Gap) And LnLess(T,Idx^[J-Gap]) Do Begin
     Idx^[J]:=Idx^[J-Gap];J:=J-Gap;End;
   Idx^[J]:=T;
  End;
  Gap:=Gap Div 2;
 End;
 For Pass:=0 To 1 Do Begin
  If (Pass=0) And Not AO.Line Then Continue;
  If (Pass=1) And Not AO.Hcln Then Continue;
  Hc:=Pass=1;
  { longueur de la charge utile }
  Len:=0;
  For F:=1 To LnFileN Do Begin
   Cnt:=0;
   For I:=1 To LnRecN Do If LnRecFile^[I]=F Then Inc(Cnt);
   If Cnt=0 Then Continue;
   Nm:=LnFiles[F];
   If Not Hc Then Len:=Len+4+((Length(Nm)+4) Div 4)*4+4+Cnt*8
   Else Len:=Len+2+Length(Nm)+3*((Cnt+65534) Div 65535)+Cnt*2;
  End;
  If Hc Then Begin
   { les extensions d'entree dependent des valeurs : on ecrit dans un tampon
     pour connaitre la taille }
   Len:=0;
  End;
  If Hc Then Begin
   { passe de mesure : calcul exact en simulant }
   For F:=1 To LnFileN Do Begin
    Cnt:=0;PrevA:=0;PrevL:=0;
    For K:=1 To LnRecN Do Begin
     I:=Idx^[K];
     If LnRecFile^[I]<>F Then Continue;
     If Cnt=0 Then Len:=Len+2+Length(LnFiles[F]);
     If (Cnt Mod 65535)=0 Then Len:=Len+3;
     Inc(Cnt);
     D:=LnRecAddr^[I]-PrevA;
     If D<=250 Then Len:=Len+1 Else If D<=65535 Then Len:=Len+3 Else Len:=Len+5;
     D:=LnRecLine^[I]-PrevL;
     If (D>=-127) And (D<=127) Then Len:=Len+1 Else Len:=Len+5;
     PrevA:=LnRecAddr^[I];PrevL:=LnRecLine^[I];
    End;
   End;
   Len:=Len+1;
  End;
  If Hc Then OutBytes('HCLN') Else OutBytes('LINE');
  OutLong(Len);
  For F:=1 To LnFileN Do Begin
   Cnt:=0;
   For I:=1 To LnRecN Do If LnRecFile^[I]=F Then Inc(Cnt);
   If Cnt=0 Then Continue;
   Nm:=LnFiles[F];
   If Not Hc Then Begin
    OutLong((Length(Nm)+4) Div 4);
    OutBytes(Nm);
    For I:=1 To ((Length(Nm)+4) Div 4)*4-Length(Nm) Do OutByte(0);
    OutLong(Cnt);
    For K:=1 To LnRecN Do Begin
     I:=Idx^[K];
     If LnRecFile^[I]=F Then Begin
       OutLong(LnRecLine^[I]);OutLong(LnRecAddr^[I]);End;
    End;
   End Else Begin
    OutByte(1);OutByte(Length(Nm));OutBytes(Nm);
    PrevA:=0;PrevL:=0;St:=0;
    For K:=1 To LnRecN Do Begin
     I:=Idx^[K];
     If LnRecFile^[I]<>F Then Continue;
     If (St Mod 65535)=0 Then Begin
      N:=Cnt-St;If N>65535 Then N:=65535;
      OutByte(2);OutWord(N);
     End;
     Entry(I);
     Inc(St);
    End;
   End;
  End;
  If Hc Then OutByte(0);
 End;
 FreeMem(Idx,(LnRecN+2)*4);
End;

Function WritePRG(Const Name: String): Boolean;
Var TS,DS,BS,SS,I,J: LongInt; P: PSym; H: Integer; T: Word; V: LongInt;
    RO: PLongArr; Prev,D: LongInt; Nm: String;
Begin
 WritePRG:=False;
 If Not OpenOut(Name) Then Exit;
 TS:=EvenUp(SecLen[0]);DS:=EvenUp(SecLen[1]);BS:=EvenUp(SecLen[2]);
 PrgSymN:=0;PrgSyms:=Nil;
 If OptDebug Then Begin CollectPrgSyms;SS:=PrgSymbolBytes;End Else SS:=0;
 OutWord($601A);OutLong(TS);OutLong(DS);OutLong(BS);OutLong(SS);
 OutLong(0);
 If HeadSet Then OutLong(HeadFlags) Else OutLong(0);
 OutWord(0);
 For I:=0 To TS-1 Do OutByte(SecGet(0,I));
 For I:=0 To DS-1 Do OutByte(SecGet(1,I));
 If OptDebug Then Begin
  For H:=0 To PrgSymN-1 Do Begin
   P:=PrgSyms^[H];
   If SymTypeOf(P,T,V) Then Begin
    Nm:=P^.Name;
    If Not AO.XDebug Then Nm:=Copy(Nm,1,8);
    If Length(Nm)>8 Then T:=T Or $0048;
    For J:=1 To 8 Do If J<=Length(Nm) Then OutByte(Ord(Nm[J])) Else OutByte(0);
    OutWord(T);OutLong(V);
    If Length(Nm)>8 Then Begin
     For J:=9 To 22 Do If J<=Length(Nm) Then OutByte(Ord(Nm[J])) Else
       OutByte(0);
    End;
   End;
  End;
  FreeSymPtrs;PrgSyms:=Nil;
 End;
 { table de relocation }
 GetMem(RO,(RelocN+2)*4);
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
 FreeMem(RO,(RelocN+2)*4);
 WriteLineSections;
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
Var Hn: Array[0..2] Of Integer; NH,S,T: Integer; I,J,K,Cnt: LongInt; Sz:
  LongInt; P: PSym; H: Integer;
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
     If P^.Defd And (P^.Kind=0) And (P^.Sect=S) And (Pos('~',P^.Name)=0) Then
       Inc(K);
     P:=P^.Next;
    End;
   End;
   If K>0 Then Begin
    OutLong($3F0);
    For H:=0 To HASHSZ-1 Do Begin
     P:=Hash[H];
     While P<>Nil Do Begin
      If P^.Defd And (P^.Kind=0) And (P^.Sect=S) And (Pos('~',P^.Name)=0) Then
        Begin
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

{ S-records Motorola (OPT SREC, -L6) : module S0, donnees S1/S2/S3 (28 octets
  par ligne), S9/S8/S7 }
Function WriteSrec(Const Name: String): Boolean;
Var T: Text; I,K,N,AL: LongInt; Base,Last: LongInt; Ln,Mod0: String; Ty: Char;

 Function Rec(Ty: Char; Addr: LongInt; Alen: Integer; Const Data: String):
   String;
 Var R: String; C,Sm: LongInt; J: Integer;
 Begin
  C:=Alen+Length(Data) Div 2+1;
  Sm:=C;
  R:='S'+Ty+Hex2(C);
  For J:=Alen-1 DownTo 0 Do Begin
   R:=R+Hex2(ShrL(Addr,J*8) And $FF);
   Sm:=Sm+(ShrL(Addr,J*8) And $FF);
  End;
  R:=R+Data;
  For J:=0 To Length(Data) Div 2-1 Do
   Sm:=Sm+(HexVal(Data[J*2+1])*16+HexVal(Data[J*2+2]));
  R:=R+Hex2((Not Sm) And $FF);
  Rec:=R;
 End;

Begin
 WriteSrec:=False;
 Assign(T,Name);
 {$I-}
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 Base:=0;
 If AbsMode Then Base:=OrgAddr;
 Last:=Base+SecLen[0]-1;
 If Last>$FFFFFF Then AL:=4 Else If Last>$FFFF Then AL:=3 Else AL:=2;
 Mod0:=Upper(ShortName(ChangeExt(AsmFileName,'X')));
 Mod0:=Copy(Mod0,1,Length(Mod0)-2);
 Ln:='';
 For I:=1 To Length(Mod0) Do Ln:=Ln+Hex2(Ord(Mod0[I]));
 Write(T,Rec('0',0,2,Ln)+#13#10);
 If AL=2 Then Ty:='1' Else If AL=3 Then Ty:='2' Else Ty:='3';
 I:=0;
 While I<SecLen[0] Do Begin
  N:=SecLen[0]-I;
  If N>28 Then N:=28;
  Ln:='';
  For K:=0 To N-1 Do Ln:=Ln+Hex2(SecGet(0,I+K));
  Write(T,Rec(Ty,Base+I,AL,Ln)+#13#10);
  I:=I+N;
 End;
 If AL=2 Then Ty:='9' Else If AL=3 Then Ty:='8' Else Ty:='7';
 Write(T,Rec(Ty,Base,AL,'')+#13#10);
 Close(T);
 WriteSrec:=True;
End;

{ Imprime la table des symboles dans le listing }
Type
 TSymArr = Array[1..1] Of PSym;
 PSymArr = ^TSymArr;

Procedure PrintSymbols;
Var Arr: PSymArr; N,I,J,Gap: LongInt; P: PSym; T: PSym; H: Integer;
    Sc,Md: String; Gst: Boolean;
Begin
 AllocSymPtrs;
 N:=0;
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin
   If P^.Defd And (P^.Kind<>2) And (Pos('~',P^.Name)=0) And (N<PrgSymCap-1)
     Then Begin PrgSyms^[N]:=P;Inc(N);End;
   P:=P^.Next;
  End;
 End;
 Gap:=N Div 2;
 While Gap>0 Do Begin
  For I:=Gap To N-1 Do Begin
   T:=PrgSyms^[I];J:=I;
   While (J>=Gap) And (PrgSyms^[J-Gap]^.Name>T^.Name) Do Begin
     PrgSyms^[J]:=PrgSyms^[J-Gap];J:=J-Gap;End;
   PrgSyms^[J]:=T;
  End;
  Gap:=Gap Div 2;
 End;
 Gst:=AO.Fmt=1;
 { format du vrai GenST : symboles absolus, puis symboles relogeables du module
   }
 ListOut('');
 ListOut(#9+'GLOBAL SYMBOLS');
 ListOut('');
 For I:=0 To N-1 Do
  If PrgSyms^[I]^.Sect<0 Then
    ListOut(Hex8(PrgSyms^[I]^.Value)+'     A  '+PrgSyms^[I]^.Name);
 ListOut('');
 If (AO.Fmt=1) Or (AO.Fmt=2) Then Begin
  If ModName='' Then Md:='ANON_MODULE' Else Md:=Upper(ModName);
  Md:=Md+#9;
 End Else Md:='';
 ListOut(#9+'MODULE '+Md);
 ListOut('');
 For I:=0 To N-1 Do
  If PrgSyms^[I]^.Sect>=0 Then Begin
   If Gst Then Begin
    Case PrgSyms^[I]^.Sect Of
     0: Sc:='FF.R';
     1: Sc:='FE.R';
    Else Sc:='FD.R';
    End;
   End Else Begin
    Case PrgSyms^[I]^.Sect Of
     0: Sc:='T  R';
     1: Sc:='D  R';
    Else Sc:='B  R';
    End;
   End;
   ListOut(Hex8(PrgSyms^[I]^.Value)+'  '+Sc+'  '+PrgSyms^[I]^.Name);
  End;
 ListOut('');
 Write(ListF,#12);
 FreeSymPtrs;
End;

{ Ecrit un fichier de symboles pre-assemble (.GS) : symboles absolus, listes
  REG, macros }
Function WriteGS(Const Name: String): Boolean;
Var T: Text; H,I,J: Integer; P: PSym; Pa: String;
Begin
 WriteGS:=False;
 Assign(T,Name);
 {$I-}
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Exit;
 WriteLn(T,'DEVPAC-GS 1');
 For I:=1 To GsInclN Do WriteLn(T,'I ',GsIncl[I]);
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin
   If P^.Defd And (P^.Sect<0) And (Pos('~',P^.Name)=0) And ((P^.Kind=0) Or
     (P^.Kind=2)) Then Begin
    If P^.Kind=2 Then Write(T,'R ') Else Write(T,'S ');
    WriteLn(T,P^.Name,' ',Hex8(P^.Value));
   End;
   P:=P^.Next;
  End;
 End;
 For I:=1 To MacCount Do Begin
  Pa:='0 ';
  If Macros[I].Even Then Pa:='1 ';
  WriteLn(T,'M ',Macros[I].Name,' ',Pa,Macros[I].PNames);
  For J:=1 To Macros[I].Count Do WriteLn(T,'L ',Macros[I].Body^[J]^);
  WriteLn(T,'E');
 End;
 Close(T);
 WriteGS:=True;
End;

{ ---------------------------------------------------------------------- }
{ Formats lies : DRI (.O, L2) et Lattice (hunks Amiga .O, L7)             }
{ Formats reconstruits d'apres les specifications publiques (DRI CP/M-68K }
{ pour DRI, AmigaDOS hunks pour Lattice) : le manuel ne les decrit pas.    }
{ ---------------------------------------------------------------------- }

Function IsXdef(Const N: String): Boolean;
Var K: Integer;
Begin
 IsXdef:=False;
 For K:=1 To XdefN Do If XdefNames[K]=N Then IsXdef:=True;
End;

Function SecFlag(S: Integer): Word;
Begin
 Case S Of
  0: SecFlag:=$0200;
  1: SecFlag:=$0400;
  2: SecFlag:=$0100;
 Else SecFlag:=0;
 End;
End;

Procedure OutName8(Const N: String);
Var J: Integer;
Begin
 For J:=1 To 8 Do If J<=Length(N) Then OutByte(Ord(N[J])) Else OutByte(0);
End;

Function WriteDRI(Const Name: String): Boolean;
Var TS,DS,BS,SS,I,J,NSym,W: LongInt; P: PSym; H: Integer; TR,DR: PByteArr; X,K:
  LongInt; Fl: Word;
    Dst: LongInt;

 Procedure SetW(Arr: PByteArr; Idx: LongInt; V: LongInt);
 Begin
  Arr^[Idx*2]:=(V Shr 8) And $FF;Arr^[Idx*2+1]:=V And $FF;
 End;

 Function IsExp(P: PSym): Boolean;
 Begin
  IsExp:=P^.Defd And (P^.Kind=0) And (Pos('~',P^.Name)=0) And IsXdef(P^.Name);
 End;
 Function IsLoc(P: PSym): Boolean;
 Begin
  IsLoc:=P^.Defd And (P^.Kind=0) And (Pos('~',P^.Name)=0) And Not
    IsXdef(P^.Name) And OptDebug And (P^.Sect>=0);
 End;

Begin
 WriteDRI:=False;
 If Not OpenOut(Name) Then Exit;
 TS:=EvenUp(SecLen[0]);DS:=EvenUp(SecLen[1]);BS:=SecLen[2];
 NSym:=ImpN;
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin
   If IsExp(P) Or IsLoc(P) Then Inc(NSym);
   P:=P^.Next;
  End;
 End;
 SS:=NSym*14;
 OutWord($601A);OutLong(TS);OutLong(DS);OutLong(BS);OutLong(SS);
 OutLong(0);OutLong(0);OutWord(0);
 For I:=0 To TS-1 Do OutByte(SecGet(0,I));
 For I:=0 To DS-1 Do OutByte(SecGet(1,I));
 { symboles : imports d'abord (index = numero d'import-1), puis exports, puis
   locaux }
 For I:=1 To ImpN Do Begin OutName8(ImpNames[I]);OutWord($8800);OutLong(0);End;
 PrgSymN:=0;AllocSymPtrs;
 For H:=0 To HASHSZ-1 Do Begin
  P:=Hash[H];
  While P<>Nil Do Begin
   If (IsExp(P) Or IsLoc(P)) And (PrgSymN<PrgSymCap) Then Begin
     PrgSyms^[PrgSymN]:=P;Inc(PrgSymN);End;
   P:=P^.Next;
  End;
 End;
 SortSymPtrs;
 For H:=0 To PrgSymN-1 Do Begin
  P:=PrgSyms^[H];
  If P^.Sect<0 Then Fl:=$E000
  Else If IsExp(P) Then Fl:=$A000 Or SecFlag(P^.Sect)
  Else Fl:=$8000 Or SecFlag(P^.Sect);
  OutName8(P^.Name);OutWord(Fl);OutLong(P^.Value);
 End;
 FreeSymPtrs;PrgSyms:=Nil;
 { relocation : un mot par mot de TEXT puis de DATA }
 GetMem(TR,TS+4);GetMem(DR,DS+4);
 FillChar(TR^,TS+4,0);FillChar(DR^,DS+4,0);
 For I:=1 To RelocN Do Begin
  Dst:=RelocDst^[I];
  W:=RelocPos^[I] Div 2;
  If RelocSrc^[I]=0 Then Begin
   If Dst<RELIMP Then Begin
    SetW(TR,W,5);
    Case Dst Of 0: SetW(TR,W+1,2); 1: SetW(TR,W+1,1); 2: SetW(TR,W+1,3); End;
   End Else Begin
    X:=(Dst-RELIMP) Div 4-1;K:=(Dst-RELIMP) Mod 4;
    If K=0 Then Begin SetW(TR,W,5);SetW(TR,W+1,(X Shl 3) Or 4);End
    Else If K=1 Then SetW(TR,W,(X Shl 3) Or 4) Else SetW(TR,W,(X Shl 3) Or 6);
   End;
  End Else If RelocSrc^[I]=1 Then Begin
   If Dst<RELIMP Then Begin
    SetW(DR,W,5);
    Case Dst Of 0: SetW(DR,W+1,2); 1: SetW(DR,W+1,1); 2: SetW(DR,W+1,3); End;
   End Else Begin
    X:=(Dst-RELIMP) Div 4-1;K:=(Dst-RELIMP) Mod 4;
    If K=0 Then Begin SetW(DR,W,5);SetW(DR,W+1,(X Shl 3) Or 4);End
    Else If K=1 Then SetW(DR,W,(X Shl 3) Or 4) Else SetW(DR,W,(X Shl 3) Or 6);
   End;
  End;
 End;
 For I:=0 To TS-1 Do OutByte(TR^[I]);
 For I:=0 To DS-1 Do OutByte(DR^[I]);
 FreeMem(TR,TS+4);FreeMem(DR,DS+4);
 CloseOut;
 WriteDRI:=True;
End;

{ Lattice : hunks Amiga (HUNK_UNIT, CODE/DATA/BSS, RELOC32, EXT, SYMBOL, END) }
Procedure OutPadName(Const N: String; Typ: LongInt);
Var J,L: LongInt;
Begin
 L:=(Length(N)+3) Div 4;
 OutLong((Typ Shl 24) Or L);
 For J:=1 To L*4 Do If J<=Length(N) Then OutByte(Ord(N[J])) Else OutByte(0);
End;

Function WriteLattice(Const Name: String): Boolean;
Var Hn: Array[0..2] Of Integer; NH,S,T,Kk: Integer; I,K,Cnt,Sz,X: LongInt; P:
  PSym; H: Integer; Any: Boolean;
    Dst: LongInt;
Begin
 WriteLattice:=False;
 If Not OpenOut(Name) Then Exit;
 NH:=0;
 For S:=0 To 2 Do
  If (S=0) Or (SecLen[S]>0) Then Begin Hn[S]:=NH;Inc(NH);End Else Hn[S]:=-1;
 If ModName='' Then
   ModName:=Copy(Upper(ShortName(ChangeExt(AsmFileName,'X'))),1,255);
 OutLong($3E7);
 OutPadName(ModName,0);
 { HUNK_UNIT : le type est dans les 24 bits hauts de rien : on reecrit
   proprement }
 For S:=0 To 2 Do Begin
  If Hn[S]<0 Then Continue;
  Sz:=(SecLen[S]+3) Div 4;
  If S=0 Then OutLong($3E9) Else If S=1 Then OutLong($3EA) Else OutLong($3EB);
  OutLong(Sz);
  If S<2 Then
   For I:=0 To Sz*4-1 Do If I<SecLen[S] Then OutByte(SecGet(S,I)) Else
     OutByte(0);
  { RELOC32 vers les sections }
  Any:=False;
  For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]<RELIMP) Then
    Any:=True;
  If Any Then Begin
   OutLong($3EC);
   For T:=0 To 2 Do Begin
    If Hn[T]<0 Then Continue;
    Cnt:=0;
    For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]=T) Then
      Inc(Cnt);
    If Cnt>0 Then Begin
     OutLong(Cnt);OutLong(Hn[T]);
     For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]=T) Then
       OutLong(RelocPos^[I]);
    End;
   End;
   OutLong(0);
  End;
  { EXT : definitions (XDEF) et references (XREF) }
  Any:=(ImpN>0) And (S=0);
  For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]>=RELIMP) Then
    Any:=True;
  For H:=0 To HASHSZ-1 Do Begin
   P:=Hash[H];
   While P<>Nil Do Begin
    If P^.Defd And (P^.Kind=0) And IsXdef(P^.Name) And ((P^.Sect=S) Or
      ((P^.Sect<0) And (S=0))) Then Any:=True;
    P:=P^.Next;
   End;
  End;
  If Any Then Begin
   OutLong($3EF);
   For H:=0 To HASHSZ-1 Do Begin
    P:=Hash[H];
    While P<>Nil Do Begin
     If P^.Defd And (P^.Kind=0) And IsXdef(P^.Name) And (Pos('~',P^.Name)=0)
       Then Begin
      If P^.Sect=S Then Begin OutPadName(P^.Name,1);OutLong(P^.Value);End
      Else If (P^.Sect<0) And (S=0) Then Begin
        OutPadName(P^.Name,2);OutLong(P^.Value);End;
     End;
     P:=P^.Next;
    End;
   End;
   For X:=1 To ImpN Do
    For Kk:=0 To 2 Do Begin
     Cnt:=0;
     For I:=1 To RelocN Do If (RelocSrc^[I]=S) And (RelocDst^[I]=RELIMP+X*4+Kk)
       Then Inc(Cnt);
     If Cnt>0 Then Begin
      If Kk=0 Then OutPadName(ImpNames[X],129) Else If Kk=1 Then
        OutPadName(ImpNames[X],134)
      Else OutPadName(ImpNames[X],131);
      OutLong(Cnt);
      For I:=1 To RelocN Do If (RelocSrc^[I]=S) And
        (RelocDst^[I]=RELIMP+X*4+Kk) Then OutLong(RelocPos^[I]);
     End;
    End;
   OutLong(0);
  End;
  { symboles de debug (OPT DEBUG : tous les relatifs ; XDEBUG : seulement les
    XDEF) }
  If OptDebug Then Begin
   K:=0;
   For H:=0 To HASHSZ-1 Do Begin
    P:=Hash[H];
    While P<>Nil Do Begin
     If P^.Defd And (P^.Kind=0) And (P^.Sect=S) And (Pos('~',P^.Name)=0) And
       (Not AO.XDebug Or IsXdef(P^.Name)) Then Inc(K);
     P:=P^.Next;
    End;
   End;
   If K>0 Then Begin
    OutLong($3F0);
    For H:=0 To HASHSZ-1 Do Begin
     P:=Hash[H];
     While P<>Nil Do Begin
      If P^.Defd And (P^.Kind=0) And (P^.Sect=S) And (Pos('~',P^.Name)=0) And
        (Not AO.XDebug Or IsXdef(P^.Name)) Then Begin
       OutPadName(P^.Name,0);OutLong(P^.Value);
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
 WriteLattice:=True;
End;

{ ---------------------------------------------------------------------- }
{ Format GST (SROFF, Sinclair relocatable binary) : OPT GST, -L1, .BIN       }
{ Specification : annexe B du manuel du linker QL (SROFF_ocr.txt)          }
{ ---------------------------------------------------------------------- }

Var
 GstBuf : PByteArr;
 GstLen,GstCap : LongInt;

Procedure GAdd(B: Byte);
Var N: PByteArr;
Begin
 If GstBuf=Nil Then Begin GstCap:=65536;GetMem(GstBuf,GstCap);GstLen:=0;End;
 If GstLen>=GstCap Then Begin
  GetMem(N,GstCap*2);Move(GstBuf^,N^,GstLen);FreeMem(GstBuf,
    GstCap);GstBuf:=N;GstCap:=GstCap*2;
 End;
 GstBuf^[GstLen]:=B;Inc(GstLen);
End;

Procedure GWord(V: LongInt);
Begin
 GAdd((V Shr 8) And $FF);GAdd(V And $FF);
End;

Procedure GLong(V: LongInt);
Begin
 GAdd(ShrL(V,24) And $FF);GAdd(ShrL(V,16) And $FF);GAdd(ShrL(V,8) And
   $FF);GAdd(V And $FF);
End;

Procedure GStr(Const S: String);
Var I: Integer;
Begin
 GAdd(Length(S));
 For I:=1 To Length(S) Do GAdd(Ord(S[I]));
End;

Procedure GDir(N: Byte);
Begin
 GAdd($FB);GAdd(N);
End;

{ nom de symbole GST : sans suffixe de module, 32 caracteres au plus }
Function GstName(Const N: String): String;
Var K: Integer; S: String;
Begin
 S:=N;K:=Pos('^',S);
 If K>0 Then S:=Copy(S,1,K-1);
 GstName:=Copy(S,1,80);
End;

Function SymInModule(P: PSym): Boolean;
Var K: Integer;
Begin
 K:=Pos('^',P^.Name);
 If ModIdx=0 Then SymInModule:=K=0
 Else SymInModule:=(K>0) And (Copy(P^.Name,K+1,10)=IntStr(ModIdx));
End;

{ ecrit le module courant dans le tampon GST : evenements dans l'ordre de la
  source }
Procedure GstFlushModule;
Var SecId: Array[0..2] Of LongInt; Have: Array[0..2] Of Boolean; Ord3:
  Array[1..3] Of Integer; NId: Integer;
    E,I,J,K,H,Pos0,Cnt,T,Gap,Pe: LongInt; P: PSym; Nm: String;
    Dst,D,NS,X,Kk: LongInt; Sz: Integer; Rule: Integer; Term: LongInt; Done:
      Boolean; OrgI,S: Integer; Ok: Boolean;
    Idx: Array[0..2] Of PLongArr; ICnt: Array[0..2] Of LongInt; Cur:
      Array[0..2] Of LongInt;
    ImpOrd: Array[1..2001] Of Integer;

 Procedure Assign(Sc: Integer);
 Begin
  If (Sc<0) Or (Sc>2) Then Exit;
  If Not Have[Sc] Then Begin
   Have[Sc]:=True;Inc(NId);SecId[Sc]:=$10000-NId;Ord3[NId]:=Sc;
  End;
 End;

 Procedure EmitSpan(Sc: Integer; A,B: LongInt);
 Var GapI: Integer;
 Begin
  Pos0:=A;
  If Sc=2 Then Begin
   While Pos0<B Do Begin GAdd(0);Inc(Pos0);End;
   Exit;
  End;
  While Pos0<B Do Begin
   If AbsMode And (Sc=0) Then
    While (OrgI<=GstOrgN) And (GstOrgPos[OrgI]=Pos0) Do Begin
      GDir(3);GLong(GstOrgAddr[OrgI]);Inc(OrgI);End;
   Done:=False;
   For GapI:=1 To GstGapN Do
    If (Not Done) And (GstGapSec[GapI]=Sc) And (GstGapPos[GapI]=Pos0) Then Begin
     GDir(5);GLong(GstGapEnd[GapI]);Pos0:=GstGapEnd[GapI];Done:=True;
    End;
   If Done Then Continue;
   While (Cur[Sc]<=ICnt[Sc]) And (RelocPos^[Idx[Sc]^[Cur[Sc]]]<Pos0) Do
     Inc(Cur[Sc]);
   If (Cur[Sc]<=ICnt[Sc]) And (RelocPos^[Idx[Sc]^[Cur[Sc]]]=Pos0) Then Begin
    Dst:=RelocDst^[Idx[Sc]^[Cur[Sc]]];Inc(Cur[Sc]);
    NS:=0;
    If Dst<=-10 Then Begin Sz:=2;Rule:=$2A;D:=-10-Dst;X:=0;End
    Else Begin
     NS:=Dst Div 100000;D:=Dst Mod 100000;
     If D>=RELIMP Then Begin
      X:=(D-RELIMP) Div 4;Kk:=(D-RELIMP) Mod 4;
      If Kk=0 Then Begin Sz:=4;If NS>0 Then Rule:=$14 Else Rule:=$54;End
      Else If Kk=1 Then Begin Sz:=2;Rule:=2;End Else Begin Sz:=2;Rule:=$2A;End;
     End Else Begin Sz:=4;If NS>0 Then Rule:=$14 Else Rule:=$54;X:=0;End;
    End;
    If Sz=4 Then Term:=(LongInt(SecGet(Sc,Pos0)) Shl 24) Or
      (LongInt(SecGet(Sc,Pos0+1)) Shl 16) Or (LongInt(SecGet(Sc,Pos0+2)) Shl 8)
      Or SecGet(Sc,Pos0+3)
    Else Begin
     Term:=(LongInt(SecGet(Sc,Pos0)) Shl 8) Or SecGet(Sc,Pos0+1);
     If Term>=32768 Then Term:=Term-65536;
    End;
    GDir(7);GLong(Term);GAdd(Rule);
    If (NS>0) And (Dst>-10) And (D>=RELIMP) Then Begin
      GAdd($2D);GWord(SecId[NS-1]);End;
    GAdd($2B);
    If (Dst<=-10) Or (D<RELIMP) Then GWord(SecId[D]) Else GWord(X);
    If (NS>0) And ((Dst<=-10) Or (D<RELIMP)) Then Begin
      GAdd($2D);GWord(SecId[NS-1]);End;
    GAdd($FB);
    Inc(Pos0,Sz);
   End Else Begin
    GAdd(SecGet(Sc,Pos0));
    If SecGet(Sc,Pos0)=$FB Then GAdd($FB);
    Inc(Pos0);
   End;
  End;
 End;

Begin
 GSpanClose;
 { module vide : rien n'est ecrit }
 If (GEvN=0) And (ImpN=0) And (SecLen[0]=0) And (SecLen[1]=0) And (SecLen[2]=0)
   Then Exit;
 If ModName='' Then Nm:='ANON_MODULE' Else Nm:=Upper(ModName);
 If Copy(Nm,Length(Nm)-1,2)='.X' Then Nm:=Copy(Nm,1,Length(Nm)-2);
 GDir(1);GStr(Copy(Nm,1,80));
 { identifiants de sections : dans l'ordre de premiere utilisation, TEXT
   d'abord }
 For S:=0 To 2 Do Have[S]:=False;
 NId:=0;
 Assign(0);
 For E:=1 To GEvN Do If GEvK[E]=2 Then Assign(GEvS[E]);
 For E:=1 To GEvN Do If GEvK[E]=0 Then Assign(GEvS[E]);
 For K:=1 To XdefN Do Begin
  P:=FindSym(XdefNames[K]);
  If (P<>Nil) And P^.Defd And (P^.Kind=0) And (P^.Sect>=0) Then Assign(P^.Sect);
 End;
 For I:=1 To RelocN Do Begin
  Dst:=RelocDst^[I];
  If Dst<=-10 Then Assign(-10-Dst)
  Else Begin
   NS:=Dst Div 100000;D:=Dst Mod 100000;
   If NS>0 Then Assign(NS-1);
   If D<RELIMP Then Assign(D);
  End;
 End;
 If OptDebug Then
  For H:=0 To HASHSZ-1 Do Begin
   P:=Hash[H];
   While P<>Nil Do Begin
    If P^.Defd And (P^.Kind=0) And (P^.Sect>=0) And (Pos('~',P^.Name)=0) And
      SymInModule(P) Then Assign(P^.Sect);
    P:=P^.Next;
   End;
  End;
 For K:=1 To NId Do Begin
  GDir($10);GWord(SecId[Ord3[K]]);GStr(GstSecName[Ord3[K]]);
 End;
 { symboles importes : identifiants positifs }
 Cnt:=0;
 For I:=1 To ImpN Do Begin
  { ordre : longueur du nom puis ordre ASCII (comme le vrai GenST) }
  J:=0;
  For K:=1 To ImpN Do
   If (Length(GstName(ImpNames[K]))<Length(GstName(ImpNames[I]))) Or
      ((Length(GstName(ImpNames[K]))=Length(GstName(ImpNames[I]))) And
        (GstName(ImpNames[K])<GstName(ImpNames[I]))) Or
      ((GstName(ImpNames[K])=GstName(ImpNames[I])) And (K<I)) Then Inc(J);
  ImpOrd[J+1]:=I;
 End;
 For I:=1 To ImpN Do Begin
   GDir($10);GWord(ImpOrd[I]);GStr(GstName(ImpNames[ImpOrd[I]]));End;
 { index des relogements par section, tries par position }
 For S:=0 To 2 Do Begin
  GetMem(Idx[S],(RelocN+2)*4);ICnt[S]:=0;Cur[S]:=1;
  For I:=1 To RelocN Do If RelocSrc^[I]=S Then Begin
    Inc(ICnt[S]);Idx[S]^[ICnt[S]]:=I;End;
  Gap:=ICnt[S] Div 2;
  While Gap>0 Do Begin
   For I:=Gap+1 To ICnt[S] Do Begin
    T:=Idx[S]^[I];J:=I;
    While (J>Gap) And (RelocPos^[Idx[S]^[J-Gap]]>RelocPos^[T]) Do Begin
      Idx[S]^[J]:=Idx[S]^[J-Gap];J:=J-Gap;End;
    Idx[S]^[J]:=T;
   End;
   Gap:=Gap Div 2;
  End;
 End;
 OrgI:=1;
 GDir(4);GWord(SecId[0]);
 For E:=1 To GEvN Do Begin
  Case GEvK[E] Of
   0: EmitSpan(GEvS[E],GEvA[E],GEvB[E]);
   1: Begin
       P:=FindSym(XdefNames[GEvS[E]]);
       If (P<>Nil) And P^.Defd And (P^.Kind=0) Then Begin
        GDir(6);GStr(GstName(XdefNames[GEvS[E]]));GLong(P^.Value);
        If P^.Sect<0 Then GWord(0) Else GWord(SecId[P^.Sect]);
       End;
      End;
   2: Begin GDir(4);GWord(SecId[GEvS[E]]);End;
   3: Begin GDir(2);GStr(GEvTxt[GEvS[E]]);End;
  End;
 End;
 For S:=0 To 2 Do FreeMem(Idx[S],(RelocN+2)*4);
 { OPT D : symboles non exportes, en fin de module, tries (longueur, nom) }
 If OptDebug Then Begin
  PrgSymN:=0;AllocSymPtrs;
  For H:=0 To HASHSZ-1 Do Begin
   P:=Hash[H];
   While P<>Nil Do Begin
    If P^.Defd And (P^.Kind=0) And (P^.Sect>=0) And (Pos('~',P^.Name)=0) And
      SymInModule(P) And (PrgSymN<PrgSymCap) Then Begin
     Ok:=True;
     For K:=1 To XdefN Do If FindSym(XdefNames[K])=P Then Ok:=False;
     If Ok Then Begin PrgSyms^[PrgSymN]:=P;Inc(PrgSymN);End;
    End;
    P:=P^.Next;
   End;
  End;
  SortSymPtrs;
  For K:=0 To PrgSymN-1 Do Begin
   P:=PrgSyms^[K];
   GDir(6);GStr(GstName(P^.Name));GLong(P^.Value);GWord(SecId[P^.Sect]);
  End;
  FreeSymPtrs;
 End;
 GDir($13);
End;

{ nouveau module (MODULE) : ecrit le module courant s'il n'est pas vide, puis
  repart a zero }
Procedure GstNewModule(Const N: String);
Var Empty: Boolean;
Begin
 Empty:=(SecLen[0]=0) And (SecLen[1]=0) And (SecLen[2]=0) And (XdefN=0) And
   (ImpN=0) And (GstCmtN=0);
 If Empty Then Begin ModName:=N;Exit;End;
 If AsmPassNo=2 Then GstFlushModule;
 GEvReset;
 FreeSections;
 SecLen[0]:=0;SecLen[1]:=0;SecLen[2]:=0;
 CurSect:=SEC_TEXT;AbsMode:=False;OffMode:=False;OffPC:=0;
 RelocN:=0;ImpN:=0;XdefN:=0;GstGapN:=0;GstOrgN:=0;GstCmtN:=0;
 GstSecName[0]:='TEXT';GstSecName[1]:='DATA';GstSecName[2]:='BSS';
 GstSecCust[0]:=False;GstSecCust[1]:=False;GstSecCust[2]:=False;
 LastGlobal:='';
 Inc(ModIdx);
 ModName:=N;
End;

Function WriteGst(Const Name: String): Boolean;
Var I: LongInt;
Begin
 WriteGst:=False;
 If Not OpenOut(Name) Then Exit;
 For I:=0 To GstLen-1 Do OutByte(GstBuf^[I]);
 CloseOut;
 WriteGst:=True;
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

Procedure DefaultAsmOpts(Var O: TAsmOpts);
Var K: Integer;
Begin
 FillChar(O,SizeOf(O),0);
 O.SymLen:=127;O.EvenChk:=True;O.Proc:=68000;O.FpId:=1;O.ChkBit:=1;
 For K:=0 To 12 Do O.OW[K]:=True;
End;

Procedure InitAsmTables;
Var I: Integer;
Begin
 For I:=0 TO HASHSZ-1 Do Hash[I]:=Nil;
 SymCount:=0;MacCount:=0;SrcTop:=0;CondTop:=0;
 FillChar(Chunks,SizeOf(Chunks),0);
 If RelocPos=Nil Then Begin
  RelocCap:=RELOCINIT;
  GetMem(RelocPos,RelocCap*4+8);GetMem(RelocSrc,RelocCap*4+8);GetMem(RelocDst,
    RelocCap*4+8);
  GetMem(Decs,DECCAP);New(TmpBody);
 End;
 OptListing:=False;OptSymbols:=False;OptToDisk:=True;OptOptimize:=False;
 OptCase:=True;OptDebug:=False;OptWarnings:=True;
 OptOutName:='';OptIncPath:='';OptListName:='';OptTabSize:=8;
 CmdOpts:='';CmdSyms:='';CmdHeaders:='';NoBinary:=False;OptCheckOnly:=False;
 OptFormatSel:=0;OptIncList:='';
 DefaultAsmOpts(AO);DefaultAsmOpts(AO0);
 AsmLogN:=0;AmigaMode:=AmigaMode;
End;

{ nom de peripherique de listing : PRN: AUX: CON: ou fichier }
Function ListDevName(Const N,Def: String): String;
Var U: String;
Begin
 U:=Upper(N);
 If N='' Then ListDevName:=Def
 Else If (U='CON:') Or (U='SCREEN:') Or (U='SCR:') Or (U='CON') Then
   ListDevName:=''
 Else If (U='PRN:') Or (U='PAR:') Or (U='LPT1:') Then Begin
  {$IFDEF UNIX} ListDevName:='/dev/lp0'; {$ELSE} ListDevName:='PRN'; {$ENDIF}
 End Else If (U='AUX:') Or (U='SER:') Or (U='COM1:') Then Begin
  {$IFDEF UNIX} ListDevName:='/dev/ttyS0'; {$ELSE} ListDevName:='AUX'; {$ENDIF}
 End Else ListDevName:=N;
End;

{ Assemble Lines[1..Count] ; True si aucune erreur }
Function AssembleSource(Const Name: String; Lines: PLineArr; Count: LongInt):
  Boolean;
Var Prev,Cur: LongInt; N: Integer; Ext,Expl: String; L: LongInt; WriteIt:
  Boolean;
Begin
 AssembleSource:=False;
 LogClear;
 FreeSyms;FreeSections;
 AsmErrors:=0;AsmWarns:=0;AsmErrCnt:=0;AsmFatal:=False;
 AsmFileName:=Name;CurSrcName:=Name;CurLineNo:=0;LastErrLine:=-1;LastWarnLine:=-
   1;
 PassSerial:=0;RelocN:=0;
 FillChar(SecLen,SizeOf(SecLen),0);
 FillChar(SecBase,SizeOf(SecBase),0);
 OptDebug0:=OptDebug;OptOptimize0:=OptOptimize;OptCase0:=OptCase;OptWarnings0:=
   OptWarnings;
 DefaultAsmOpts(AO0);
 AO0.Fmt:=OptFormatSel;
 AO0.XDebug:=OptDebug;
 Expl:=OptOutName;
 LogLine(AsmName+T3(' Macro Assembler  Version ',' Macro-assembleur  Version ',
   ' Makro-Assembler  Version ')+VERSION_TEXT);
 LogLine(T3('DEV-COOLS clone of HiSoft Devpac',
   'Clone DEV-COOLS de HiSoft Devpac','DEV-COOLS-Klon von HiSoft Devpac'));
 LogLine('');
 FillChar(Decs^,DECCAP,0);
 If LongLines>0 Then Begin
  AsmPassNo:=2;LnText:='';
  Err3('line malformed','Ligne trop longue (255 caracteres maximu'+'m)',
    'Zeile zu lang');
  LongLines:=0;
 End;
 If (AO0.Fmt<>0) And (AO0.Fmt<>6) And (AO0.Fmt<>2) And (AO0.Fmt<>7) And
   (AO0.Fmt<>1) Then Begin
  AsmPassNo:=2;LnText:='';
  Err3('linker format restriction','Format d''edition de liens non gere',
    'Linker-Format nicht unterstuetzt');
  AsmFatal:=True;
 End;
 ListOn:=False;SkipPass2:=False;
 If Not AsmFatal Then Begin
  ListDevOpen:=False;
  If OptListing Then Begin
   Assign(ListF,ListDevName(OptListName,ChangeExt(Name,'LST')));
   {$I-}
   Rewrite(ListF);
   {$I+}
   ListOn:=IOResult=0;
  End Else Begin
   { LIST sans destination : ecran }
   Assign(ListF,'');
   {$I-}
   Rewrite(ListF);
   {$I+}
   ListOn:=IOResult=0;
  End;
  ListDevOpen:=ListOn;
  If Not ListOn And (OptListing) Then Begin
   AsmPassNo:=2;LnText:='';CurLineNo:=0;LastErrLine:=-1;
   Err3('error during listing output','Erreur de listing',
     'Fehler bei Listing-Ausgabe');
  End;
 End;
 { passe 1 repetee jusqu'a stabilisation des symboles }
 Prev:=-1;N:=0;
 If Not AsmFatal Then
 Repeat
  AsmPassNo:=1;Pass1Idx:=N;
  If N=0 Then LogLine('Pass 1') ;
  RunPass(Lines,Count);
  If (N=0) And (AsmErrCnt>0) Then SkipPass2:=True;
  ComputeBases;
  Cur:=SymChecksum;
  Inc(N);
  If AsmFatal Or SkipPass2 Then Break;
  If Cur=Prev Then Break;
  Prev:=Cur;
 Until N>=8;
 { passe 2 : generation }
 AsmPassNo:=2;
 If Not AsmFatal And Not SkipPass2 Then Begin
  LogLine('Pass 2');
  FreeSections;
  GstLen:=0;
  GEvReset;
  RunPass(Lines,Count);
  If ListOn Then Begin
   If (AO.Symtab Or OptSymbols) And (ListCnt>=0) Then PrintSymbols;
  End;
 End Else If SkipPass2 And ListOn And Not AsmFatal Then Begin
  { erreurs de syntaxe : le vrai GenST produit tout de meme le listing }
  ListOnlyPass:=True;
  FreeSections;
  GstLen:=0;
  RunPass(Lines,Count);
  ListOnlyPass:=False;
 End;
 If ListOn Then Begin Flush(ListF);Close(ListF);ListOn:=False;End;
 LogLine('');
 LogLine('CODE '+IntStr(SecLen[0])+'  DATA '+IntStr(SecLen[1])+'  BSS '+
   IntStr(SecLen[2])+
         T3(' bytes',' octets',' Bytes'));
 If OptCount>0 Then
   LogLine(IntStr(OptCount)+T3(' optimisation(s) made, ',' optimisation(s), ',
   ' Optimierung(en), ')+IntStr(OptSaved)+T3(' byte(s) saved',
   ' octet(s) gagne(s)',' Byte(s) gespart'));
 If AsmWarns>0 Then
   LogLine(IntStr(AsmWarns)+T3(' warning(s)',' avertissement(s)',
   ' Warnung(en)'));
 If (AsmErrCnt=0) And (AO.Fmt=6) And Not AbsMode Then Begin
  LnText:='';CurLineNo:=0;AsmPassNo:=2;
  Warn3('no ORG specified','Pas de ORG specifie','Kein ORG angegeben');
 End;
 If (AsmErrCnt=0) And Not OptToDisk And (AO.Fmt<>0) And (GsOutName='') Then
   Begin
  LnText:='';CurLineNo:=0;AsmPassNo:=2;LastErrLine:=-1;
  Err3('executable code only','Seul du code executable peut etre assemb'+
    'le en memoire','Nur ausfuehrbarer Code im Speicher moegl'+'ich');
 End;
 If (AsmErrCnt=0) And ((GsOutName<>'') Or AO.Gensym) And
   (SecLen[0]+SecLen[1]+SecLen[2]>0) Then Begin
  LnText:='';CurLineNo:=0;AsmPassNo:=2;
  Err3('cannot export symbol','Un fichier pre-assemble ne doit pas gene'+
    'rer de code','Vorassemblierte Datei darf keinen Code e'+'rzeugen');
 End;
 { le vrai GenST ecrit le fichier de sortie meme si la passe 2 a signale des
   erreurs }
 WriteIt:=(AsmErrCnt=0) Or (OptToDisk And Not SkipPass2 And Not AsmFatal And
   Not NoBinary And Not OptCheckOnly And (GsOutName='') And Not AO.Gensym);
 If WriteIt Then Begin
  If AsmErrCnt=0 Then LogLine(T3('No errors','Aucune erreur','Keine Fehler'))
  Else LogLine(IntStr(AsmErrCnt)+T3(' error(s)',' erreur(s)',' Fehler'));
  { fichier de sortie }
  If (GsOutName<>'') Or AO.Gensym Then Begin
   If GsOutName<>'' Then OutPathFinal:=GsOutName Else
     OutPathFinal:=ChangeExt(Name,'GS');
   OutIsTemp:=False;
   If WriteGS(OutPathFinal) Then HaveOutput:=True;
  End Else If NoBinary Or OptCheckOnly Then Begin
   HaveOutput:=True;OutPathFinal:='';OutIsTemp:=False;
  End Else Begin
   If Not OptToDisk Then Begin
    OutPathFinal:=PathOf(Name)+'DEVPAC.TMP';OutIsTemp:=True;
   End Else Begin
    OutIsTemp:=False;
    If Expl<>'' Then OutPathFinal:=Expl
    Else If OutFileName<>'' Then Begin
     If OutFileName[1]='.' Then
       OutPathFinal:=ChangeExt(Name,Copy(OutFileName,2,10))
     Else OutPathFinal:=OutFileName;
    End
    Else If AO.Fmt=6 Then OutPathFinal:=ChangeExt(Name,'MX')
    Else If AO.Fmt=1 Then OutPathFinal:=ChangeExt(Name,'BIN')
    Else If (AO.Fmt=2) Or (AO.Fmt=7) Then OutPathFinal:=ChangeExt(Name,'O')
    Else If AmigaMode Then OutPathFinal:=StripExt(Name)
    Else OutPathFinal:=ChangeExt(Name,'PRG');
   End;
   If AO.Fmt=1 Then Begin
    GstFlushModule;
    If WriteGst(OutPathFinal) Then HaveOutput:=True;
   End Else If AO.Fmt=2 Then Begin
    If WriteDRI(OutPathFinal) Then HaveOutput:=True;
   End Else If AO.Fmt=7 Then Begin
    If WriteLattice(OutPathFinal) Then HaveOutput:=True;
   End Else If AO.Fmt=6 Then Begin
    If WriteSrec(OutPathFinal) Then HaveOutput:=True;
   End Else If AmigaMode Then Begin
    If WriteHunk(OutPathFinal) Then HaveOutput:=True;
   End Else Begin
    If WritePRG(OutPathFinal) Then HaveOutput:=True;
   End;
  End;
  If HaveOutput And OutFail Then Begin
   LogLine(T3('error during writing binary file',
     'Erreur d''ecriture du fichier binaire',
     'Fehler beim Schreiben der Binaerdatei'));
   HaveOutput:=False;
  End Else
  If Not HaveOutput Then Begin
   LogLine(T3('cannot create binary file ','Impossible d''ecrire le fichier ',
     'Ausgabedatei nicht schreibbar ')+OutPathFinal);
   Inc(AsmErrCnt);
  End Else If OptToDisk And (OutPathFinal<>'') Then
    LogLine(T3('Output: ','Sortie : ','Ausgabe: ')+OutPathFinal);
 End Else Begin
  LogLine(IntStr(AsmErrCnt)+T3(' error(s)',' erreur(s)',' Fehler'));
  HaveOutput:=False;
 End;
 FreeMacros;
 AssembleSource:=(AsmErrCnt=0) And HaveOutput;
End;

{ � Output Symbols � : assemble Src sans fichier binaire et ecrit Dst (fichier
  .GS) ;
  False si erreur d'assemblage (AsmErrors/ErrLn/ErrTx renseignes) }
Function AsmOutputSymbols(Const Src,Dst: String): Boolean;
Var Arr: PLineArr; Cnt: LongInt; SvNB,SvAmi: Boolean; Ok: Boolean;
Begin
 AsmOutputSymbols:=False;
 LongLines:=0;
 If Not LoadLinesBig(Src,Arr,Cnt) Then Begin
  LogClear;AsmErrors:=0;AsmErrCnt:=0;AsmWarns:=0;AsmFatal:=False;
  LogLine(T3('file not found: ','Impossible d''ouvrir ','Kann nicht oeffnen: ')+
    Src);
  Exit;
 End;
 GsOutName:=Dst;
 HaveOutput:=False;
 AsmFromEditor:=False;
 Ok:=AssembleSource(Src,Arr,Cnt);
 GsOutName:='';
 FreeLinesBig(Arr,Cnt);
 AsmOutputSymbols:=Ok;
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

Function HwRd8(A: LongInt): Byte; Forward;     { ROM / registres materiels ST :
  voir p20 }

Function Rd8(A: LongInt): Byte;
Var P: ^Byte;
Begin
 A:=A And $FFFFFF;
 If A>=MemSize Then Begin
  If A<$FC0000 Then Begin BusErr:=True;BusAddr:=A;Rd8:=0;End
  Else Rd8:=HwRd8(A);
  Exit;
 End;
 {$IFDEF FPC}
 P:=PageTab[A Shr 12];
 Inc(P,A And 4095);
 {$ELSE}
 P:=PtrAdd(PageTab[A Shr 12],A And 4095);
 {$ENDIF}
 Rd8:=P^;
End;

Procedure HwWr8(A: LongInt; V: Byte); Forward;     { registres materiels ST
  (ecriture) : voir p20 }

Procedure Wr8(A: LongInt; V: Byte);
Var P: ^Byte;
Begin
 A:=A And $FFFFFF;
 If A>=MemSize Then Begin
  If A<$FF0000 Then Begin BusErr:=True;BusAddr:=A;End
  Else If A>=$FF8000 Then HwWr8(A,V);
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
  If Upper(DbgSyms^[I].Name)=U Then Begin
    A:=DbgSyms^[I].Addr;DbgByName:=True;Exit;End;
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
 DisMon : Boolean;     { moniteur : marque les symboles (#1 nom #2), symboles
   immediats }
 DisRel : Boolean;     { moniteur : offsets relatifs symbole(An) }
 DisExt : Boolean;     { moniteur : jeu 68010/68020/68030/68040/68881 }
 DisZAn : Boolean;     { moniteur : affiche ZAn / ZPC (base supprimee) }
 DisAn  : Array[0..7] Of LongInt;   { valeurs de A0-A7 pour DisRel }

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

Function DSym(Const S: String): String;
Begin
 If DisMon Then DSym:=#1+S+#2 Else DSym:=S;
End;

Function SymOrHex(A: LongInt): String;
Var S: String;
Begin
 S:=DbgFind(A);
 If S<>'' Then SymOrHex:=DSym(S) Else SymOrHex:=HexS(A);
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

{ Mot d'extension 68020 : brief (avec echelle) ou complet ; Base = 'A3', 'PC'
  ... }
Function ExtEA(Ext: LongInt; Const Base: String): String;
Var S,XR,Bd,Od,Res: String; Sc,Bs,Isx,Bds,Iis: Integer;
Begin
 If (Ext And $8000)<>0 Then XR:='A' Else XR:='D';
 XR:=XR+IntStr((Ext Shr 12) And 7);
 If (Ext And $800)<>0 Then XR:=XR+'.L' Else XR:=XR+'.W';
 Sc:=(Ext Shr 9) And 3;
 If Sc<>0 Then XR:=XR+'*'+IntStr(1 Shl Sc);
 If (Ext And $100)=0 Then Begin
  ExtEA:=SgnHex(SX8(Ext))+'('+Base+','+XR+')';
  Exit;
 End;
 Bs:=(Ext Shr 7) And 1;Isx:=(Ext Shr 6) And 1;Bds:=(Ext Shr 4) And 3;Iis:=Ext
   And 7;
 Bd:='';Od:='';
 If Bds=2 Then Bd:=SgnHex(SX16(DNextW))
 Else If Bds=3 Then Bd:=SgnHex(DNextL);
 If (Iis And 3)=2 Then Od:=SgnHex(SX16(DNextW))
 Else If (Iis And 3)=3 Then Od:=SgnHex(DNextL);
 If Bs=1 Then Begin
  If DisZAn Then Begin If Base='PC' Then S:='ZPC' Else S:='Z'+Base;End Else
    S:='';
 End Else S:=Base;
 If Isx=1 Then XR:='';
 If Iis=0 Then Begin
  { pas d'indirection memoire }
  Res:=Bd;
  If S<>'' Then Begin If Res<>'' Then Res:=Res+',';Res:=Res+S;End;
  If XR<>'' Then Begin If Res<>'' Then Res:=Res+',';Res:=Res+XR;End;
  ExtEA:='('+Res+')';
 End Else Begin
  If Iis<4 Then Begin
   { pre-indexe : ([bd,An,Xn],od) }
   If XR<>'' Then Begin If S<>'' Then S:=S+',';S:=S+XR;End;
   Res:=Bd;
   If S<>'' Then Begin If Res<>'' Then Res:=Res+',';Res:=Res+S;End;
   Res:='(['+Res+']';
   If Od<>'' Then Res:=Res+','+Od;
   ExtEA:=Res+')';
  End Else Begin
   { post-indexe : ([bd,An],Xn,od) }
   Res:=Bd;
   If S<>'' Then Begin If Res<>'' Then Res:=Res+',';Res:=Res+S;End;
   Res:='(['+Res+']';
   If XR<>'' Then Res:=Res+','+XR;
   If Od<>'' Then Res:=Res+','+Od;
   ExtEA:=Res+')';
  End;
 End;
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
      S:='';
      If DisMon And DisRel Then S:=DbgFind(DisAn[Reg]+D);
      If S<>'' Then DEA:=DSym(S)+'(A'+IntStr(Reg)+')'
      Else DEA:=SgnHex(D)+'(A'+IntStr(Reg)+')';
     End;
  6: Begin
      Ext:=DNextW;
      If DisExt Then DEA:=ExtEA(Ext,'A'+IntStr(Reg))
      Else Begin
      D:=SX8(Ext);
      If (Ext And $8000)<>0 Then XR:='A' Else XR:='D';
      XR:=XR+IntStr((Ext Shr 12) And 7);
      If (Ext And $800)<>0 Then XR:=XR+'.L' Else XR:=XR+'.W';
      DEA:=SgnHex(D)+'(A'+IntStr(Reg)+','+XR+')';
      End;
     End;
  7: Case Reg Of
      0: Begin W:=SX16(DNextW);DEA:=SymOrHex(W)+'.W';End;
      1: Begin D:=DNextL;DEA:=SymOrHex(D);End;
      2: Begin
          W:=DPC;D:=SX16(DNextW);
          S:=DbgFind(W+D);
          If S<>'' Then DEA:=DSym(S)+'(PC)' Else DEA:=SgnHex(D)+'(PC)';
         End;
      3: Begin
          W:=DPC;
          Ext:=DNextW;
          If DisExt Then Begin DEA:=ExtEA(Ext,'PC');Exit;End;
          D:=SX8(Ext);
          If (Ext And $8000)<>0 Then XR:='A' Else XR:='D';
          XR:=XR+IntStr((Ext Shr 12) And 7);
          If (Ext And $800)<>0 Then XR:=XR+'.L' Else XR:=XR+'.W';
          DEA:=SgnHex(D)+'(PC,'+XR+')';
         End;
      4: Begin
          If Sz=2 Then D:=DNextL
          Else Begin D:=DNextW;If Sz=0 Then D:=D And $FF;End;
          S:='';
          If DisMon And (Sz=2) And (D>=$100) Then S:=DbgFind(D);
          If S<>'' Then DEA:='#'+DSym(S) Else DEA:=ImmText(D);
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
  For I:=0 To 15 Do If (Mask And (LongInt(1) Shl I))<>0 Then M:=M Or
    (LongInt(1) Shl (15-I));
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
  ('T','F','HI','LS','CC','CS','NE','EQ','VC','VS','PL','MI','GE','LT','GT',
    'LE');

Function Pad8(Const S: String): String;
Begin
 If Length(S)>=8 Then Pad8:=S+' ' Else Pad8:=PadR(S,8);
End;

{ ---------------------------------------------------------------------- }
{ Jeu etendu : 68010, 68020/30, 68040 (CINV, CPUSH, MOVE16), 68881/82     }
{ ---------------------------------------------------------------------- }

Const
 FpCond : Array[0..31] Of String[4] =
  ('F','EQ','OGT','OGE','OLT','OLE','OGL','OR','UN','UEQ','UGT','UGE','ULT',
    'ULE','NE','T',
   'SF','SEQ','GT','GE','LT','LE','GL','GLE','NGLE','NGL','NLE','NLT','NGE',
     'NGT','SNE','ST');
 FpFmtCh : String[8] = 'LSXPWDBP';

Function FpOpName(M: Integer): String;
Begin
 Case M Of
  $00: FpOpName:='FMOVE'; $01: FpOpName:='FINT'; $02: FpOpName:='FSINH'; $03:
    FpOpName:='FINTRZ';
  $04: FpOpName:='FSQRT'; $06: FpOpName:='FLOGNP1'; $08: FpOpName:='FETOXM1';
    $09: FpOpName:='FTANH';
  $0A: FpOpName:='FATAN'; $0C: FpOpName:='FASIN'; $0D: FpOpName:='FATANH'; $0E:
    FpOpName:='FSIN';
  $0F: FpOpName:='FTAN'; $10: FpOpName:='FETOX'; $11: FpOpName:='FTWOTOX'; $12:
    FpOpName:='FTENTOX';
  $14: FpOpName:='FLOGN'; $15: FpOpName:='FLOG10'; $16: FpOpName:='FLOG2'; $18:
    FpOpName:='FABS';
  $19: FpOpName:='FCOSH'; $1A: FpOpName:='FNEG'; $1C: FpOpName:='FACOS'; $1D:
    FpOpName:='FCOS';
  $1E: FpOpName:='FGETEXP'; $1F: FpOpName:='FGETMAN'; $20: FpOpName:='FDIV';
    $21: FpOpName:='FMOD';
  $22: FpOpName:='FADD'; $23: FpOpName:='FMUL'; $24: FpOpName:='FSGLDIV'; $25:
    FpOpName:='FREM';
  $26: FpOpName:='FSCALE'; $27: FpOpName:='FSGLMUL'; $28: FpOpName:='FSUB';
    $38: FpOpName:='FCMP';
  $3A: FpOpName:='FTST';
  $40: FpOpName:='FSMOVE'; $41: FpOpName:='FSSQRT'; $44: FpOpName:='FDMOVE';
    $45: FpOpName:='FDSQRT';
  $58: FpOpName:='FSABS'; $5A: FpOpName:='FSNEG'; $5C: FpOpName:='FDABS'; $5E:
    FpOpName:='FDNEG';
  $60: FpOpName:='FSDIV'; $62: FpOpName:='FSADD'; $63: FpOpName:='FSMUL'; $64:
    FpOpName:='FDDIV';
  $66: FpOpName:='FDADD'; $67: FpOpName:='FDMUL'; $68: FpOpName:='FSSUB'; $6C:
    FpOpName:='FDSUB';
 Else FpOpName:='';
 End;
End;

{ Liste de registres FP : Rev = bit0 = FP0 (predecrement), sinon bit7 = FP0 }
Function FpList(Mask: LongInt; Rev: Boolean): String;
Var I,J: Integer; S: String;
 Function Has(N: Integer): Boolean;
 Begin
  If Rev Then Has:=(Mask And (1 Shl N))<>0 Else Has:=(Mask And (1 Shl
    (7-N)))<>0;
 End;
Begin
 S:='';I:=0;
 While I<8 Do Begin
  If Has(I) Then Begin
   J:=I;
   While (J<7) And Has(J+1) Do Inc(J);
   If S<>'' Then S:=S+'/';
   If J>I Then S:=S+'FP'+IntStr(I)+'-FP'+IntStr(J) Else S:=S+'FP'+IntStr(I);
   I:=J+1;
  End Else Inc(I);
 End;
 FpList:=S;
End;

Function FpEA(Mode,Reg,Fmt: Integer): String;
Var S: String; I: Integer; Lo,Hi,Mi: LongInt;
Begin
 If (Mode=7) And (Reg=4) Then Begin
  Case Fmt Of
   0: FpEA:='#'+HexS(DNextL);
   1: FpEA:='#$'+Hex8(DNextL);
   4: FpEA:=DEA(Mode,Reg,1);
   6: FpEA:=DEA(Mode,Reg,0);
   5: Begin Hi:=DNextL;Lo:=DNextL;FpEA:='#$'+Hex8(Hi)+Hex8(Lo);End;
  Else Begin
    Hi:=DNextL;Mi:=DNextL;Lo:=DNextL;FpEA:='#$'+Hex8(Hi)+Hex8(Mi)+Hex8(Lo);End;
  End;
 End Else FpEA:=DEA(Mode,Reg,2);
End;

Function DisFpu(Op,PCIn: LongInt; Var R: String): Boolean;
Var E,Mode,Reg,Ty,Cc,Fmt,Rm,Src,Dst,OpM,K: LongInt; S1,S2,Sx: String; D:
  LongInt;
Begin
 DisFpu:=False;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 Ty:=(Op Shr 6) And 7;
 Case Ty Of
  0: Begin
      E:=DNextW;
      Rm:=(E Shr 13) And 7;
      Src:=(E Shr 10) And 7;Dst:=(E Shr 7) And 7;OpM:=E And $7F;
      If (Rm=0) Or (Rm=2) Then Begin
       If (Rm=2) And (Src=7) Then Begin
        R:=Pad8('FMOVECR')+'#$'+Hex2(OpM)+',FP'+IntStr(Dst);DisFpu:=True;Exit;
       End;
       Sx:=FpOpName(OpM);
       If (OpM>=$30) And (OpM<=$37) Then Sx:='FSINCOS';
       If Sx='' Then Exit;
       If Rm=0 Then Begin
        S1:='FP'+IntStr(Src);
        Sx:=Sx+'.X';
       End Else Begin
        Sx:=Sx+'.'+FpFmtCh[Src+1];
        S1:=FpEA(Mode,Reg,Src);
       End;
       If OpM=$3A Then R:=Pad8(Sx)+S1
       Else If Sx[1]='F' Then Begin
        If (OpM>=$30) And (OpM<=$37) Then R:=Pad8(Sx)+S1+',FP'+IntStr(E And
          7)+':FP'+IntStr(Dst)
        Else R:=Pad8(Sx)+S1+',FP'+IntStr(Dst);
       End;
       DisFpu:=True;Exit;
      End;
      If Rm=3 Then Begin
       Fmt:=Src;
       Sx:='FMOVE.'+FpFmtCh[Fmt+1];
       S2:=FpEA(Mode,Reg,Fmt);
       If Fmt=3 Then Begin K:=E And $7F;If K>63 Then
         K:=K-128;S2:=S2+'{#'+IntStr(K)+'}';End
       Else If Fmt=7 Then S2:=S2+'{D'+IntStr((E Shr 4) And 7)+'}';
       R:=Pad8(Sx)+'FP'+IntStr(Dst)+','+S2;
       DisFpu:=True;Exit;
      End;
      If (Rm=4) Or (Rm=5) Then Begin
       S1:='';
       If (E And $1000)<>0 Then S1:='FPCR';
       If (E And $0800)<>0 Then Begin If S1<>'' Then
         S1:=S1+'/';S1:=S1+'FPSR';End;
       If (E And $0400)<>0 Then Begin If S1<>'' Then
         S1:=S1+'/';S1:=S1+'FPIAR';End;
       If S1='' Then Exit;
       If Pos('/',S1)>0 Then Sx:='FMOVEM.L' Else Sx:='FMOVE.L';
       If Rm=4 Then R:=Pad8(Sx)+DEA(Mode,Reg,2)+','+S1
       Else R:=Pad8(Sx)+S1+','+DEA(Mode,Reg,2);
       DisFpu:=True;Exit;
      End;
      If (Rm=6) Or (Rm=7) Then Begin
       { FMOVEM registres de donnees }
       If (E And $0800)<>0 Then S1:='D'+IntStr((E Shr 4) And 7)
       Else S1:=FpList(E And $FF,((E Shr 11) And 3)=0);
       If Rm=6 Then R:=Pad8('FMOVEM.X')+DEA(Mode,Reg,2)+','+S1
       Else R:=Pad8('FMOVEM.X')+S1+','+DEA(Mode,Reg,2);
       DisFpu:=True;Exit;
      End;
     End;
  1: Begin
      E:=DNextW;
      Cc:=E And $3F;
      If Cc>31 Then Exit;
      If Mode=1 Then Begin
       D:=SX16(DNextW);
       R:=Pad8('FDB'+FpCond[Cc])+'D'+IntStr(Reg)+','+SymOrHex(PCIn+4+D);
      End Else If (Mode=7) And (Reg>=2) And (Reg<=4) Then Begin
       If Reg=2 Then R:=Pad8('FTRAP'+FpCond[Cc]+'.W')+'#'+HexS(DNextW)
       Else If Reg=3 Then R:=Pad8('FTRAP'+FpCond[Cc]+'.L')+'#'+HexS(DNextL)
       Else R:='FTRAP'+FpCond[Cc];
      End Else R:=Pad8('FS'+FpCond[Cc])+DEA(Mode,Reg,0);
      DisFpu:=True;Exit;
     End;
  2,3: Begin
      Cc:=Op And $3F;
      If Cc>31 Then Exit;
      If Ty=2 Then Begin
       D:=SX16(DNextW);
       If (Cc=0) And (D=0) Then R:='FNOP'
       Else R:=Pad8('FB'+FpCond[Cc]+'.W')+SymOrHex(PCIn+2+D);
      End Else Begin
       D:=DNextL;
       R:=Pad8('FB'+FpCond[Cc]+'.L')+SymOrHex(PCIn+2+D);
      End;
      DisFpu:=True;Exit;
     End;
  4: Begin R:=Pad8('FSAVE')+DEA(Mode,Reg,2);DisFpu:=True;Exit;End;
  5: Begin R:=Pad8('FRESTORE')+DEA(Mode,Reg,2);DisFpu:=True;Exit;End;
 End;
End;

{ Retourne True si l'opcode a ete decode (DPC = fin de l'instruction) }
Function DisExtOp(Op,PCIn: LongInt; Var R: String): Boolean;
Var Mode,Reg,Sz,E,E2,D: LongInt; G: Integer; S1,S2,Sx: String; Cc: Integer;
    Ty,Do_,Dw: LongInt;
 Function RegName(V: LongInt): String;
 Begin
  If (V And $8000)<>0 Then RegName:='A'+IntStr((V Shr 12) And 7)
  Else RegName:='D'+IntStr((V Shr 12) And 7);
 End;
Begin
 DisExtOp:=False;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 G:=(Op Shr 12) And 15;
 Case G Of
  0: Begin
      Sz:=(Op Shr 9) And 3;
      If ((Op And $F9C0)=$00C0) And (Sz<3) Then Begin
       E:=DNextW;
       If (E And $07FF)=0 Then Begin
        If (E And $0800)<>0 Then Sx:='CHK2' Else Sx:='CMP2';
        R:=Pad8(Sx+'.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+','+RegName(E);
        DisExtOp:=True;
       End;
       Exit;
      End;
      If (Op=$0CFC) Or (Op=$0EFC) Then Begin
       E:=DNextW;E2:=DNextW;
       If (Op=$0CFC) Then Sz:=1 Else Sz:=2;
       R:=Pad8('CAS2.'+DSizeCh(Sz))+'D'+IntStr(E And 7)+':D'+IntStr(E2 And
         7)+',D'+IntStr((E Shr 6) And 7)+
          ':D'+IntStr((E2 Shr 6) And 7)+',('+RegName(E)+'):('+RegName(E2)+')';
       DisExtOp:=True;Exit;
      End;
      If ((Op And $F9C0)=$08C0) And (Sz<>0) Then Begin
       E:=DNextW;
       Case Sz Of 1: Sz:=0; 2: Sz:=1; Else Sz:=2; End;
       R:=Pad8('CAS.'+DSizeCh(Sz))+'D'+IntStr(E And 7)+',D'+IntStr((E Shr 6)
         And 7)+','+DEA(Mode,Reg,Sz);
       DisExtOp:=True;Exit;
      End;
      If ((Op And $FF00)=$0E00) And (((Op Shr 6) And 3)<3) Then Begin
       E:=DNextW;
       Sz:=(Op Shr 6) And 3;
       If (E And $0800)<>0 Then
         R:=Pad8('MOVES.'+DSizeCh(Sz))+RegName(E)+','+DEA(Mode,Reg,Sz)
       Else R:=Pad8('MOVES.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+','+RegName(E);
       DisExtOp:=True;Exit;
      End;
     End;
  4: Begin
      If (Op And $FFF8)=$49C0 Then Begin
        R:=Pad8('EXTB.L')+'D'+IntStr(Reg);DisExtOp:=True;Exit;End;
      If (Op And $FFF8)=$4808 Then Begin
       D:=DNextL;R:=Pad8('LINK.L')+'A'+IntStr(Reg)+',#'+
         SgnHex(D);DisExtOp:=True;Exit;
      End;
      If (Op And $FFF8)=$4848 Then Begin
        R:=Pad8('BKPT')+'#'+IntStr(Reg);DisExtOp:=True;Exit;End;
      If (Op And $F1C0)=$4100 Then Begin
       R:=Pad8('CHK.L')+DEA(Mode,Reg,2)+',D'+IntStr((Op Shr 9) And
         7);DisExtOp:=True;Exit;
      End;
      If ((Op And $FFC0)=$4C00) Or ((Op And $FFC0)=$4C40) Then Begin
       E:=DNextW;
       If (Op And $40)=0 Then Begin
        { MULU.L / MULS.L }
        If (E And $0800)<>0 Then Sx:='MULS.L' Else Sx:='MULU.L';
        If (E And $0400)<>0 Then S2:='D'+IntStr(E And 7)+':D'+IntStr((E Shr 12)
          And 7)
        Else S2:='D'+IntStr((E Shr 12) And 7);
        R:=Pad8(Sx)+DEA(Mode,Reg,2)+','+S2;
       End Else Begin
        If (E And $0800)<>0 Then Sx:='DIVS' Else Sx:='DIVU';
        If (E And $0400)<>0 Then Begin
         R:=Pad8(Sx+'.L')+DEA(Mode,Reg,2)+',D'+IntStr(E And 7)+':D'+IntStr((E
           Shr 12) And 7);
        End Else If (E And 7)<>((E Shr 12) And 7) Then
         R:=Pad8(Sx+'L.L')+DEA(Mode,Reg,2)+',D'+IntStr(E And 7)+':D'+IntStr((E
           Shr 12) And 7)
        Else R:=Pad8(Sx+'.L')+DEA(Mode,Reg,2)+',D'+IntStr((E Shr 12) And 7);
       End;
       DisExtOp:=True;Exit;
      End;
      If (Op=$4E7A) Or (Op=$4E7B) Then Begin
       E:=DNextW;
       Case E And $FFF Of
        $000: S1:='SFC'; $001: S1:='DFC'; $002: S1:='CACR'; $800: S1:='USP';
          $801: S1:='VBR';
        $802: S1:='CAAR'; $803: S1:='MSP'; $804: S1:='ISP';
        $003: S1:='TC'; $004: S1:='ITT0'; $005: S1:='ITT1'; $006: S1:='DTT0';
          $007: S1:='DTT1';
        $805: S1:='MMUSR'; $806: S1:='URP'; $807: S1:='SRP';
       Else S1:='$'+Hex4(E And $FFF);
       End;
       If Op=$4E7A Then R:=Pad8('MOVEC')+S1+','+RegName(E)
       Else R:=Pad8('MOVEC')+RegName(E)+','+S1;
       DisExtOp:=True;Exit;
      End;
      If Op=$4E74 Then Begin
        R:=Pad8('RTD')+'#'+SgnHex(SX16(DNextW));DisExtOp:=True;Exit;End;
     End;
  5: Begin
      If ((Op And $F0F8)=$50F8) And (Reg>=2) And (Reg<=4) Then Begin
       Cc:=(Op Shr 8) And 15;
       If Reg=2 Then R:=Pad8('TRAP'+CCText[Cc]+'.W')+'#'+HexS(DNextW)
       Else If Reg=3 Then R:=Pad8('TRAP'+CCText[Cc]+'.L')+'#'+HexS(DNextL)
       Else R:='TRAP'+CCText[Cc];
       DisExtOp:=True;
      End;
     End;
  6: Begin
      If (Op And $FF)=$FF Then Begin
       D:=DNextL;
       Cc:=(Op Shr 8) And 15;
       If Cc=0 Then Sx:='BRA' Else If Cc=1 Then Sx:='BSR' Else
         Sx:='B'+CCText[Cc];
       R:=Pad8(Sx+'.L')+SymOrHex(PCIn+2+D);
       DisExtOp:=True;
      End;
     End;
  8: Begin
      If ((Op And $F1F0)=$8140) Or ((Op And $F1F0)=$8180) Then Begin
       If (Op And $40)<>0 Then Sx:='PACK' Else Sx:='UNPK';
       E:=DNextW;
       If (Op And 8)=0 Then S1:='D'+IntStr(Reg)+',D'+IntStr((Op Shr 9) And 7)
       Else S1:='-(A'+IntStr(Reg)+'),-(A'+IntStr((Op Shr 9) And 7)+')';
       R:=Pad8(Sx)+S1+',#'+HexS(E);
       DisExtOp:=True;
      End;
     End;
  14: Begin
      If (Op And $F8C0)=$E8C0 Then Begin
       E:=DNextW;
       Ty:=(Op Shr 8) And 7;
       Case Ty Of
        0: Sx:='BFTST'; 1: Sx:='BFEXTU'; 2: Sx:='BFCHG'; 3: Sx:='BFEXTS';
        4: Sx:='BFCLR'; 5: Sx:='BFFFO'; 6: Sx:='BFSET'; Else Sx:='BFINS';
       End;
       If (E And $0800)<>0 Then S1:='D'+IntStr((E Shr 6) And 7) Else
         S1:=IntStr((E Shr 6) And 31);
       If (E And $0020)<>0 Then S2:='D'+IntStr(E And 7) Else Begin
        D:=E And 31;If D=0 Then D:=32;S2:=IntStr(D);
       End;
       Sx:=Pad8(Sx);
       If Ty=7 Then R:=Sx+'D'+IntStr((E Shr 12) And
         7)+','+DEA(Mode,Reg,0)+'{'+S1+':'+S2+'}'
       Else Begin
        R:=Sx+DEA(Mode,Reg,0)+'{'+S1+':'+S2+'}';
        If (Ty=1) Or (Ty=3) Or (Ty=5) Then R:=R+',D'+IntStr((E Shr 12) And 7);
       End;
       DisExtOp:=True;
      End;
     End;
  15: Begin
      If ((Op Shr 9) And 7)=1 Then Begin DisExtOp:=DisFpu(Op,PCIn,R);Exit;End;
      { 68040 : CINV, CPUSH, MOVE16 }
      If (Op And $FF20)=$F400 Then Begin
       Case (Op Shr 3) And 3 Of
        1: Sx:='L'; 2: Sx:='P'; 3: Sx:='A'; Else Sx:='';
       End;
       If Sx<>'' Then Begin
        Case (Op Shr 6) And 3 Of 1: S1:='DC'; 2: S1:='IC'; 3: S1:='BC'; Else
          S1:='NC'; End;
        If Sx='A' Then R:=Pad8('CINVA')+S1 Else
          R:=Pad8('CINV'+Sx)+S1+',(A'+IntStr(Reg)+')';
        DisExtOp:=True;
       End;
       Exit;
      End;
      If (Op And $FF20)=$F420 Then Begin
       Case (Op Shr 3) And 3 Of
        1: Sx:='L'; 2: Sx:='P'; 3: Sx:='A'; Else Sx:='';
       End;
       If Sx<>'' Then Begin
        Case (Op Shr 6) And 3 Of 1: S1:='DC'; 2: S1:='IC'; 3: S1:='BC'; Else
          S1:='NC'; End;
        If Sx='A' Then R:=Pad8('CPUSHA')+S1 Else
          R:=Pad8('CPUSH'+Sx)+S1+',(A'+IntStr(Reg)+')';
        DisExtOp:=True;
       End;
       Exit;
      End;
      If (Op And $FFE0)=$F600 Then Begin
       Case (Op Shr 3) And 3 Of
        0: Begin R:=Pad8('MOVE16')+'(A'+IntStr(Reg)+')+,'+HexS(DNextL);End;
        1: Begin R:=Pad8('MOVE16')+HexS(DNextL)+',(A'+IntStr(Reg)+')+';End;
        2: Begin R:=Pad8('MOVE16')+'(A'+IntStr(Reg)+'),'+HexS(DNextL);End;
       Else R:=Pad8('MOVE16')+HexS(DNextL)+',(A'+IntStr(Reg)+')';
       End;
       If (Op And $18)=0 Then Begin End;
       DisExtOp:=True;Exit;
      End;
      If (Op And $FFF8)=$F620 Then Begin
       E:=DNextW;
       R:=Pad8('MOVE16')+'(A'+IntStr(Reg)+')+,(A'+IntStr((E Shr 12) And 7)+')+';
       DisExtOp:=True;Exit;
      End;
     End;
 End;
End;

Function Dis(PCIn: LongInt; Var Len: Integer): String;
Var Op,Mode,Reg,Sz,Ty,Cnt,Rg: LongInt; R,S1,S2: String; T,D: LongInt;
    Mk: LongInt;
Begin
 DPC:=PCIn;
 Op:=DNextW;
 If DisExt Then Begin
  If DisExtOp(Op,PCIn,R) Then Begin Len:=Integer(DPC-PCIn);Dis:=R;Exit;End;
  DPC:=PCIn+2;
 End;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;Sz:=(Op Shr 6) And 3;Rg:=(Op Shr 9) And 7;
 R:='DC.W    '+HexS(Op);
 Case (Op Shr 12) And 15 Of
  0: Begin
      If (Op And $F138)=$0108 Then Begin
       D:=SX16(DNextW);
       If (Op And $80)<>0 Then
        R:=Pad8('MOVEP.'+DSizeCh(((Op Shr 6) And
          1)+1))+'D'+IntStr(Rg)+','+SgnHex(D)+'(A'+IntStr(Reg)+')'
       Else
        R:=Pad8('MOVEP.'+DSizeCh(((Op Shr 6) And
          1)+1))+SgnHex(D)+'(A'+IntStr(Reg)+'),D'+IntStr(Rg);
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
           If Sz=2 Then T:=DNextL Else Begin T:=DNextW;If Sz=0 Then T:=T And
             $FF;End;
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
           If Mode=4 Then S1:=RegListText(Mk,True) Else
             S1:=RegListText(Mk,False);
           R:=Pad8('MOVEM.'+DSizeCh(((Op Shr 6) And
             1)+1))+S1+','+DEA(Mode,Reg,2);
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
           R:=Pad8('MOVEM.'+DSizeCh(((Op Shr 6) And
             1)+1))+S1+','+RegListText(Mk,False);
          End;
         End;
        $0E00: Begin
          If (Op And $FFF0)=$4E40 Then R:=Pad8('TRAP')+'#'+IntStr(Op And 15)
          Else If (Op And $FFF8)=$4E50 Then Begin
           D:=SX16(DNextW);R:=Pad8('LINK')+'A'+IntStr(Reg)+',#'+SgnHex(D);
          End Else If (Op And $FFF8)=$4E58 Then R:=Pad8('UNLK')+'A'+IntStr(Reg)
          Else If (Op And $FFF8)=$4E60 Then
            R:=Pad8('MOVE')+'A'+IntStr(Reg)+',USP'
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
        R:=Pad8('DB'+CCText[(Op Shr 8) And
          15])+'D'+IntStr(Reg)+','+SymOrHex(PCIn+2+D);
        If ((Op Shr 8) And 15)=1 Then
          R:=Pad8('DBRA')+'D'+IntStr(Reg)+','+SymOrHex(PCIn+2+D);
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
      End Else If ((Op Shr 12) And 15=12) And (((Op And $F1F8)=$C140) Or ((Op
        And $F1F8)=$C148) Or
                  ((Op And $F1F8)=$C188)) Then Begin
       If (Op And $F1F8)=$C140 Then
         R:=Pad8('EXG')+'D'+IntStr(Rg)+',D'+IntStr(Reg)
       Else If (Op And $F1F8)=$C148 Then
         R:=Pad8('EXG')+'A'+IntStr(Rg)+',A'+IntStr(Reg)
       Else R:=Pad8('EXG')+'D'+IntStr(Rg)+',A'+IntStr(Reg);
      End Else If ((Op Shr 12) And 15=11) And (Sz=3) Then Begin
       If (Op And $100)<>0 Then Sz:=2 Else Sz:=1;
       R:=Pad8('CMPA.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+',A'+IntStr(Rg);
      End Else If ((Op Shr 12) And 15=11) And ((Op And $100)<>0) And (Mode=1)
        And (Sz<>3) Then
       R:=Pad8('CMPM.'+DSizeCh(Sz))+'(A'+IntStr(Reg)+')+,(A'+IntStr(Rg)+')+'
      Else If ((Op Shr 12) And 15=11) And ((Op And $100)<>0) Then
       R:=Pad8('EOR.'+DSizeCh(Sz))+'D'+IntStr(Rg)+','+DEA(Mode,Reg,Sz)
      Else If (((Op Shr 12) And 15=9) Or ((Op Shr 12) And 15=13)) And (Sz=3)
        Then Begin
       If (Op And $100)<>0 Then Sz:=2 Else Sz:=1;
       R:=Pad8(S1+'A.'+DSizeCh(Sz))+DEA(Mode,Reg,Sz)+',A'+IntStr(Rg);
      End Else If (((Op Shr 12) And 15=9) Or ((Op Shr 12) And 15=13)) And ((Op
        And $130)=$100) Then Begin
       If Mode=0 Then
         R:=Pad8(S1+'X.'+DSizeCh(Sz))+'D'+IntStr(Reg)+',D'+IntStr(Rg)
       Else
         R:=Pad8(S1+'X.'+DSizeCh(Sz))+'-(A'+IntStr(Reg)+'),-(A'+IntStr(Rg)+')';
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
       If (Op And $20)<>0 Then
         R:=Pad8(S1+'.'+DSizeCh(Sz))+'D'+IntStr(Rg)+',D'+IntStr(Reg)
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
 { exceptions : gestionnaires du programme (vecteurs en memoire basse) }
 MonTrap    : Boolean;      { le moniteur intercepte d'abord les exceptions }
 PendVec    : Integer;      { exception interceptee, a livrer au gestionnaire
   (-1 : aucune) }
 PendPC     : LongInt;
 PendAddr   : LongInt;
 PendIR     : LongInt;
 PendHnd    : LongInt;
 ExcTaken   : Boolean;      { une exception a ete prise pendant l'instruction }
 LastAccA   : LongInt;      { derniere adresse d'acces fautive }
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

{ Gestionnaire valide du vecteur Vec (0 si aucun) }
Function ExcHandler(Vec: Integer): LongInt;
Var H: LongInt;
Begin
 H:=Rd32(Vec*4);
 ExcHandler:=H;
 If (H=0) Or Odd(H) Or ((H And $FFFFFF)>=MemSize) Then ExcHandler:=0
 Else If (Vec>=32) And (H<$400) Then ExcHandler:=0;
End;

{ Vecteurs que Mon intercepte (tableau du manuel : "trapped" / "breakpoint") }
Function MonTraps(Vec: Integer): Boolean;
Begin
 MonTraps:=((Vec>=2) And (Vec<=8)) Or ((Vec>=11) And (Vec<=14)) Or (Vec=24) Or
           (Vec=32) Or ((Vec>=35) And (Vec<=44)) Or (Vec=47);
End;

{ Traitement d'exception du 68000 : cadre de 6 octets (SR, PC) ou de 14 octets
  (groupe 0 : bus / address error), passage en superviseur, T efface }
Procedure ClrBusAddrErr;
Begin
 BusErr:=False;AddrErr:=False;
End;

Procedure TakeExc(Vec: Integer; SPc,Hnd: LongInt; Grp0: Boolean; Addr,IR:
  LongInt);
Var OldSR,St: LongInt;
Begin
 OldSR:=SRv;
 SetSR((SRv Or SR_S) And $7FFF);
 PushL(SPc);
 PushW(OldSR);
 If Grp0 Then Begin
  PushW(IR);
  PushL(Addr);
  If (OldSR And SR_S)<>0 Then St:=$15 Else St:=$11;   { FC=donnees, R/W=lecture
    }
  PushW(St);
 End;
 PC:=Hnd;
 ExcTaken:=True;
 ClrBusAddrErr;
End;

Procedure RaiseExcX(Vec: Integer; Grp0: Boolean; Addr: LongInt);
Var Hnd,SPc,IR: LongInt; Names: String;
Begin
 Hnd:=ExcHandler(Vec);
 Case Vec Of
  2,3: SPc:=CurOpPC+2;
  4,8,10,11: SPc:=CurOpPC;
 Else SPc:=PC;
 End;
 IR:=Rd16(CurOpPC);
 ClrBusAddrErr;
 If (Hnd<>0) And Not (MonTrap And MonTraps(Vec)) Then Begin
  TakeExc(Vec,SPc,Hnd,Grp0,Addr,IR);
  Exit;
 End;
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
 If Hnd<>0 Then Begin
  { intercepte par le moniteur : sera livre au gestionnaire a la reprise }
  PendVec:=Vec;PendPC:=SPc;PendAddr:=Addr;PendIR:=IR;PendHnd:=Hnd;
 End;
 PC:=CurOpPC;   { le moniteur affiche l'instruction fautive }
 If Vec=2 Then Halt68(Names+' at $'+Hex6(Addr)+' (PC=$'+Hex6(CurOpPC)+')')
 Else Halt68(Names+' at $'+Hex6(CurOpPC));
End;

Procedure RaiseExc(Vec: Integer);
Begin
 RaiseExcX(Vec,False,0);
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
      If (Reg=7) And (Sz=1) Then Rg[8+Reg]:=Rg[8+Reg]+2 Else
        Rg[8+Reg]:=Rg[8+Reg]+Sz;
     End;
  4: Begin
      If (Reg=7) And (Sz=1) Then Rg[8+Reg]:=Rg[8+Reg]-2 Else
        Rg[8+Reg]:=Rg[8+Reg]-Sz;
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
     Else Begin
       EAK:=3;EAA:=0;Halt68('Illegal addressing mode at $'+Hex6(CurOpPC));End;
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

Function AluAdd(S,D: LongInt; Sz: Integer; WithX: Boolean; SetX: Boolean):
  LongInt;
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
Function AluSub(S,D: LongInt; Sz: Integer; WithX: Boolean; SetX: Boolean):
  LongInt;
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
Function Shift(Ty: Integer; Left: Boolean; V: LongInt; Cnt: Integer; Sz:
  Integer): LongInt;
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
   If (Op And $40)=0 Then Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or (LongInt(Rd8(A))
     Shl 8) Or Rd8(A+2)
   Else Rg[Rn]:=(LongInt(Rd8(A)) Shl 24) Or (LongInt(Rd8(A+2)) Shl 16) Or
     (LongInt(Rd8(A+4)) Shl 8) Or Rd8(A+6);
  End Else Begin
   If (Op And $40)=0 Then Begin Wr8(A,ShrL(Rg[Rn],8) And $FF);Wr8(A+2,Rg[Rn]
     And $FF);End
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
      $0400: Begin CalcEA(Mode,Reg,2);V:=ReadEA(2);SetSR((SRv And $FF00) Or (V
        And $FF));End;
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
    If Op=$4AFC Then Begin RaiseExc(4);Exit;End;
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
  If Den=0 Then Begin RaiseExc(5);Exit;End;
  Num:=Rg[Rn];
  If (Op And $100)=0 Then Begin
   Q:=DivU32(Num,Den,Rem);
   If (Q<0) Or (Q>$FFFF) Then Begin SetF(SR_V,True);SetF(SR_C,False);Exit;End;
   Rg[Rn]:=((Rem And $FFFF) Shl 16) Or (Q And $FFFF);
   SetF(SR_V,False);SetF(SR_C,False);SetNZ(Q,2);
  End Else Begin
   Den:=SExt(Den,2);
   If (Num=Low32) And (Den=-1) Then Begin
     SetF(SR_V,True);SetF(SR_C,False);Exit;End;
   Q:=Num Div Den;Rem:=Num Mod Den;
   If (Q<-32768) Or (Q>32767) Then Begin
     SetF(SR_V,True);SetF(SR_C,False);Exit;End;
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
  If IsAdd Then R:=AluAdd(V,Rg[Rn],Sz,False,True) Else
    R:=AluSub(V,Rg[Rn],Sz,False,True);
  Case Sz Of
   1: Rg[Rn]:=(Rg[Rn] And (Not $FF)) Or R;
   2: Rg[Rn]:=(Rg[Rn] And (Not $FFFF)) Or R;
  Else Rg[Rn]:=R;
  End;
 End Else Begin
  V:=ReadEA(Sz);
  If IsAdd Then R:=AluAdd(Rg[Rn],V,Sz,False,True) Else
    R:=AluSub(Rg[Rn],V,Sz,False,True);
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
 If (Op And $F1F8)=$C140 Then Begin
   T:=Rg[Rn];Rg[Rn]:=Rg[Reg];Rg[Reg]:=T;Exit;End;
 If (Op And $F1F8)=$C148 Then Begin
   T:=Rg[8+Rn];Rg[8+Rn]:=Rg[8+Reg];Rg[8+Reg]:=T;Exit;End;
 If (Op And $F1F8)=$C188 Then Begin
   T:=Rg[Rn];Rg[Rn]:=Rg[8+Reg];Rg[8+Reg]:=T;Exit;End;
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
 PendVec:=-1;ExcTaken:=False;
End;

Procedure Step;
Var Op: LongInt; Tr: Boolean;
Begin
 CurOpPC:=PC;
 If PendVec>=0 Then Begin
  { exception interceptee par le moniteur : on l'envoie au gestionnaire du
    programme }
  TakeExc(PendVec,PendPC,PendHnd,(PendVec=2) Or (PendVec=3),PendAddr,PendIR);
  PendVec:=-1;
  Exit;
 End;
 HleLibCheck;
 If StopReason<>STOP_NONE Then Exit;
 CurOpPC:=PC;
 Tr:=(SRv And SR_T)<>0;
 ExcTaken:=False;
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
 Else RaiseExc(11);
 End;
 If AddrErr Then Begin
  LastAccA:=BusAddr;
  RaiseExcX(3,True,BusAddr);
 End Else If BusErr Then Begin
  LastAccA:=BusAddr;
  RaiseExcX(2,True,BusAddr);
 End;
 If StopReason=STOP_FAULT Then PC:=CurOpPC   { PC = instruction fautive
   (moniteur) }
 Else If Tr And Not ExcTaken And (StopReason=STOP_NONE) And (PendVec<0) Then
   Begin
  { bit Trace : exception 9 apres l'instruction (ignoree sans gestionnaire) }
  Op:=ExcHandler(9);
  If Op<>0 Then TakeExc(9,PC,Op,False,0,0);
 End;
End;

Function IsBreakpoint(A: LongInt): Boolean;
Var I: Integer;
Begin
 IsBreakpoint:=False;
 For I:=1 To NBps Do If Bps[I]=A Then Begin IsBreakpoint:=True;Exit;End;
End;

{ Execute au plus Max instructions ; s'arrete sur un point d'arret }
Procedure IrqCheck; Forward;     { interruptions MFP / VBL livrees aux
  gestionnaires installes par le programme (p20) }

Procedure RunCpu(Max: LongInt);
Var N: LongInt;
Begin
 N:=0;
 While (StopReason=STOP_NONE) And (N<Max) Do Begin
  Step;
  Inc(N);
  If (N And 511)=0 Then IrqCheck;
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
{ Police 8x8 integree (celle de la police BGI) : sert en mode batch (/EMUL, /B)
  ou BuildFont ne peut pas la relever a l'ecran }
Const
 Font8Emb : Array[0..255,0..7] Of Byte = (
  ($00,$00,$00,$00,$00,$00,$00,$00),($7E,$81,$A5,$81,$BD,$99,$81,$7E),
  ($7E,$FF,$DB,$FF,$C3,$E7,$FF,$7E),($6C,$FE,$FE,$FE,$7C,$38,$10,$00),
  ($10,$38,$7C,$FE,$7C,$38,$10,$00),($38,$7C,$38,$FE,$FE,$7C,$38,$7C),
  ($10,$10,$38,$7C,$FE,$7C,$38,$7C),($00,$00,$18,$3C,$3C,$18,$00,$00),
  ($FF,$FF,$E7,$C3,$C3,$E7,$FF,$FF),($00,$3C,$66,$42,$42,$66,$3C,$00),
  ($FF,$C3,$99,$BD,$BD,$99,$C3,$FF),($0F,$07,$0F,$7D,$CC,$CC,$CC,$78),
  ($3C,$66,$66,$66,$3C,$18,$7E,$18),($3F,$33,$3F,$30,$30,$70,$F0,$E0),
  ($7F,$63,$7F,$63,$63,$67,$E6,$C0),($99,$5A,$3C,$E7,$E7,$3C,$5A,$99),
  ($80,$E0,$F8,$FE,$F8,$E0,$80,$00),($02,$0E,$3E,$FE,$3E,$0E,$02,$00),
  ($18,$3C,$7E,$18,$18,$7E,$3C,$18),($66,$66,$66,$66,$66,$00,$66,$00),
  ($7F,$DB,$DB,$7B,$1B,$1B,$1B,$00),($3E,$63,$38,$6C,$6C,$38,$CC,$78),
  ($00,$00,$00,$00,$7E,$7E,$7E,$00),($18,$3C,$7E,$18,$7E,$3C,$18,$FF),
  ($18,$3C,$7E,$18,$18,$18,$18,$00),($18,$18,$18,$18,$7E,$3C,$18,$00),
  ($00,$18,$0C,$FE,$0C,$18,$00,$00),($00,$30,$60,$FE,$60,$30,$00,$00),
  ($00,$00,$C0,$C0,$C0,$FE,$00,$00),($00,$24,$66,$FF,$66,$24,$00,$00),
  ($00,$18,$3C,$7E,$FF,$FF,$00,$00),($00,$FF,$FF,$7E,$3C,$18,$00,$00),
  ($00,$00,$00,$00,$00,$00,$00,$00),($30,$78,$78,$78,$30,$00,$30,$00),
  ($6C,$6C,$6C,$00,$00,$00,$00,$00),($6C,$6C,$FE,$6C,$FE,$6C,$6C,$00),
  ($30,$7C,$C0,$78,$0C,$F8,$30,$00),($00,$C6,$CC,$18,$30,$66,$C6,$00),
  ($38,$6C,$38,$76,$DC,$CC,$76,$00),($60,$60,$C0,$00,$00,$00,$00,$00),
  ($18,$30,$60,$60,$60,$30,$18,$00),($60,$30,$18,$18,$18,$30,$60,$00),
  ($00,$66,$3C,$FF,$3C,$66,$00,$00),($00,$30,$30,$FC,$30,$30,$00,$00),
  ($00,$00,$00,$00,$00,$30,$30,$60),($00,$00,$00,$FC,$00,$00,$00,$00),
  ($00,$00,$00,$00,$00,$30,$30,$00),($06,$0C,$18,$30,$60,$C0,$80,$00),
  ($7C,$C6,$C6,$C6,$C6,$C6,$7C,$00),($30,$70,$30,$30,$30,$30,$FC,$00),
  ($78,$CC,$0C,$38,$60,$CC,$FC,$00),($78,$CC,$0C,$38,$0C,$CC,$78,$00),
  ($1C,$3C,$6C,$CC,$FE,$0C,$1E,$00),($FC,$C0,$F8,$0C,$0C,$CC,$78,$00),
  ($38,$60,$C0,$F8,$CC,$CC,$78,$00),($FC,$CC,$0C,$18,$30,$30,$30,$00),
  ($78,$CC,$CC,$78,$CC,$CC,$78,$00),($78,$CC,$CC,$7C,$0C,$18,$70,$00),
  ($00,$30,$30,$00,$00,$30,$30,$00),($00,$30,$30,$00,$00,$30,$30,$60),
  ($18,$30,$60,$C0,$60,$30,$18,$00),($00,$00,$FC,$00,$00,$FC,$00,$00),
  ($60,$30,$18,$0C,$18,$30,$60,$00),($78,$CC,$0C,$18,$30,$00,$30,$00),
  ($7C,$C6,$DE,$DE,$DE,$C0,$78,$00),($38,$6C,$C6,$C6,$FE,$C6,$C6,$00),
  ($FC,$C6,$C6,$FC,$C6,$C6,$FC,$00),($7C,$C6,$C6,$C0,$C0,$C6,$7C,$00),
  ($F8,$CC,$C6,$C6,$C6,$CC,$F8,$00),($FE,$C0,$C0,$FC,$C0,$C0,$FE,$00),
  ($FE,$C0,$C0,$FC,$C0,$C0,$C0,$00),($7C,$C6,$C0,$CE,$C6,$C6,$7E,$00),
  ($C6,$C6,$C6,$FE,$C6,$C6,$C6,$00),($78,$30,$30,$30,$30,$30,$78,$00),
  ($1E,$06,$06,$06,$C6,$C6,$7C,$00),($C6,$CC,$D8,$F0,$D8,$CC,$C6,$00),
  ($C0,$C0,$C0,$C0,$C0,$C0,$FE,$00),($C6,$EE,$FE,$D6,$C6,$C6,$C6,$00),
  ($C6,$E6,$F6,$DE,$CE,$C6,$C6,$00),($7C,$C6,$C6,$C6,$C6,$C6,$7C,$00),
  ($FC,$C6,$C6,$FC,$C0,$C0,$C0,$00),($7C,$C6,$C6,$C6,$C6,$C6,$7C,$06),
  ($FC,$C6,$C6,$FC,$C6,$C6,$C6,$00),($78,$CC,$60,$30,$18,$CC,$78,$00),
  ($FC,$30,$30,$30,$30,$30,$30,$00),($C6,$C6,$C6,$C6,$C6,$C6,$7C,$00),
  ($C6,$C6,$C6,$C6,$C6,$6C,$38,$00),($C6,$C6,$C6,$D6,$FE,$EE,$C6,$00),
  ($C6,$C6,$6C,$38,$6C,$C6,$C6,$00),($C3,$C3,$66,$3C,$18,$18,$18,$00),
  ($FE,$0C,$18,$30,$60,$C0,$FE,$00),($3C,$30,$30,$30,$30,$30,$3C,$00),
  ($C0,$60,$30,$18,$0C,$06,$03,$00),($3C,$0C,$0C,$0C,$0C,$0C,$3C,$00),
  ($00,$38,$6C,$C6,$00,$00,$00,$00),($00,$00,$00,$00,$00,$00,$00,$FF),
  ($30,$30,$18,$00,$00,$00,$00,$00),($00,$00,$7C,$06,$7E,$C6,$7E,$00),
  ($C0,$C0,$FC,$C6,$C6,$E6,$DC,$00),($00,$00,$7C,$C6,$C0,$C0,$7E,$00),
  ($06,$06,$7E,$C6,$C6,$CE,$76,$00),($00,$00,$7C,$C6,$FE,$C0,$7E,$00),
  ($1E,$30,$7C,$30,$30,$30,$30,$00),($00,$00,$7E,$C6,$CE,$76,$06,$7C),
  ($C0,$C0,$FC,$C6,$C6,$C6,$C6,$00),($18,$00,$38,$18,$18,$18,$3C,$00),
  ($18,$00,$38,$18,$18,$18,$18,$F0),($C0,$C0,$CC,$D8,$F0,$D8,$CC,$00),
  ($38,$18,$18,$18,$18,$18,$3C,$00),($00,$00,$CC,$FE,$D6,$C6,$C6,$00),
  ($00,$00,$FC,$C6,$C6,$C6,$C6,$00),($00,$00,$7C,$C6,$C6,$C6,$7C,$00),
  ($00,$00,$FC,$C6,$C6,$E6,$DC,$C0),($00,$00,$7E,$C6,$C6,$CE,$76,$06),
  ($00,$00,$6E,$70,$60,$60,$60,$00),($00,$00,$7C,$C0,$7C,$06,$FC,$00),
  ($30,$30,$7C,$30,$30,$30,$1C,$00),($00,$00,$C6,$C6,$C6,$C6,$7E,$00),
  ($00,$00,$C6,$C6,$C6,$6C,$38,$00),($00,$00,$C6,$C6,$D6,$FE,$6C,$00),
  ($00,$00,$C6,$6C,$38,$6C,$C6,$00),($00,$00,$C6,$C6,$CE,$76,$06,$7C),
  ($00,$00,$FC,$18,$30,$60,$FC,$00),($1C,$30,$30,$E0,$30,$30,$1C,$00),
  ($18,$18,$18,$00,$18,$18,$18,$00),($E0,$30,$30,$1C,$30,$30,$E0,$00),
  ($76,$DC,$00,$00,$00,$00,$00,$00),($00,$10,$38,$6C,$C6,$C6,$FE,$00),
  ($78,$CC,$C0,$CC,$78,$18,$0C,$78),($00,$CC,$00,$CC,$CC,$CC,$7E,$00),
  ($1C,$00,$78,$CC,$FC,$C0,$78,$00),($7E,$C3,$3C,$06,$3E,$66,$3F,$00),
  ($CC,$00,$78,$0C,$7C,$CC,$7E,$00),($E0,$00,$78,$0C,$7C,$CC,$7E,$00),
  ($30,$30,$78,$0C,$7C,$CC,$7E,$00),($00,$00,$78,$C0,$C0,$78,$0C,$38),
  ($7E,$C3,$3C,$66,$7E,$60,$3C,$00),($CC,$00,$78,$CC,$FC,$C0,$78,$00),
  ($E0,$00,$78,$CC,$FC,$C0,$78,$00),($CC,$00,$70,$30,$30,$30,$78,$00),
  ($7C,$C6,$38,$18,$18,$18,$3C,$00),($E0,$00,$70,$30,$30,$30,$78,$00),
  ($C6,$38,$6C,$C6,$FE,$C6,$C6,$00),($30,$30,$00,$78,$CC,$FC,$CC,$00),
  ($1C,$00,$FC,$60,$78,$60,$FC,$00),($00,$00,$7F,$0C,$7F,$CC,$7F,$00),
  ($3E,$6C,$CC,$FE,$CC,$CC,$CE,$00),($78,$CC,$00,$78,$CC,$CC,$78,$00),
  ($00,$CC,$00,$78,$CC,$CC,$78,$00),($00,$E0,$00,$78,$CC,$CC,$78,$00),
  ($78,$CC,$00,$CC,$CC,$CC,$7E,$00),($00,$E0,$00,$CC,$CC,$CC,$7E,$00),
  ($00,$CC,$00,$CC,$CC,$7C,$0C,$F8),($C3,$18,$3C,$66,$66,$3C,$18,$00),
  ($CC,$00,$CC,$CC,$CC,$CC,$78,$00),($18,$18,$7E,$C0,$C0,$7E,$18,$18),
  ($38,$6C,$64,$F0,$60,$E6,$FC,$00),($CC,$CC,$78,$FC,$30,$FC,$30,$30),
  ($F8,$CC,$CC,$FA,$C6,$CF,$C6,$C7),($0E,$1B,$18,$3C,$18,$18,$D8,$70),
  ($1C,$00,$78,$0C,$7C,$CC,$7E,$00),($38,$00,$70,$30,$30,$30,$78,$00),
  ($00,$1C,$00,$78,$CC,$CC,$78,$00),($00,$1C,$00,$CC,$CC,$CC,$7E,$00),
  ($00,$F8,$00,$F8,$CC,$CC,$CC,$00),($FC,$00,$CC,$EC,$FC,$DC,$CC,$00),
  ($3C,$6C,$6C,$3E,$00,$7E,$00,$00),($38,$6C,$6C,$38,$00,$7C,$00,$00),
  ($30,$00,$30,$60,$C0,$CC,$78,$00),($00,$00,$00,$FC,$C0,$C0,$00,$00),
  ($00,$00,$00,$FC,$0C,$0C,$00,$00),($C3,$C6,$CC,$DE,$33,$66,$CC,$0F),
  ($C3,$C6,$CC,$DB,$37,$6F,$CF,$03),($18,$18,$00,$18,$18,$18,$18,$00),
  ($00,$33,$66,$CC,$66,$33,$00,$00),($00,$CC,$66,$33,$66,$CC,$00,$00),
  ($22,$88,$22,$88,$22,$88,$22,$88),($55,$AA,$55,$AA,$55,$AA,$55,$AA),
  ($DB,$77,$DB,$EE,$DB,$77,$DB,$EE),($18,$18,$18,$18,$18,$18,$18,$18),
  ($18,$18,$18,$18,$F8,$18,$18,$18),($18,$18,$F8,$18,$F8,$18,$18,$18),
  ($36,$36,$36,$36,$F6,$36,$36,$36),($00,$00,$00,$00,$FE,$36,$36,$36),
  ($00,$00,$F8,$18,$F8,$18,$18,$18),($36,$36,$F6,$06,$F6,$36,$36,$36),
  ($36,$36,$36,$36,$36,$36,$36,$36),($00,$00,$FE,$06,$F6,$36,$36,$36),
  ($36,$36,$F6,$06,$FE,$00,$00,$00),($36,$36,$36,$36,$FE,$00,$00,$00),
  ($18,$18,$F8,$18,$F8,$00,$00,$00),($00,$00,$00,$00,$F8,$18,$18,$18),
  ($18,$18,$18,$18,$1F,$00,$00,$00),($18,$18,$18,$18,$FF,$00,$00,$00),
  ($00,$00,$00,$00,$FF,$18,$18,$18),($18,$18,$18,$18,$1F,$18,$18,$18),
  ($00,$00,$00,$00,$FF,$00,$00,$00),($18,$18,$18,$18,$FF,$18,$18,$18),
  ($18,$18,$1F,$18,$1F,$18,$18,$18),($36,$36,$36,$36,$37,$36,$36,$36),
  ($36,$36,$37,$30,$3F,$00,$00,$00),($00,$00,$3F,$30,$37,$36,$36,$36),
  ($36,$36,$F7,$00,$FF,$00,$00,$00),($00,$00,$FF,$00,$F7,$36,$36,$36),
  ($36,$36,$37,$30,$37,$36,$36,$36),($00,$00,$FF,$00,$FF,$00,$00,$00),
  ($36,$36,$F7,$00,$F7,$36,$36,$36),($18,$18,$FF,$00,$FF,$00,$00,$00),
  ($36,$36,$36,$36,$FF,$00,$00,$00),($00,$00,$FF,$00,$FF,$18,$18,$18),
  ($00,$00,$00,$00,$FF,$36,$36,$36),($36,$36,$36,$36,$3F,$00,$00,$00),
  ($18,$18,$1F,$18,$1F,$00,$00,$00),($00,$00,$1F,$18,$1F,$18,$18,$18),
  ($00,$00,$00,$00,$3F,$36,$36,$36),($36,$36,$36,$36,$FF,$36,$36,$36),
  ($18,$18,$FF,$18,$FF,$18,$18,$18),($18,$18,$18,$18,$F8,$00,$00,$00),
  ($00,$00,$00,$00,$1F,$18,$18,$18),($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF),
  ($00,$00,$00,$00,$FF,$FF,$FF,$FF),($F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0),
  ($0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F),($FF,$FF,$FF,$FF,$00,$00,$00,$00),
  ($00,$00,$76,$DC,$C8,$DC,$76,$00),($00,$78,$CC,$F8,$CC,$F8,$C0,$C0),
  ($00,$FC,$CC,$C0,$C0,$C0,$C0,$00),($00,$FE,$6C,$6C,$6C,$6C,$6C,$00),
  ($FC,$CC,$60,$30,$60,$CC,$FC,$00),($00,$00,$7E,$D8,$D8,$D8,$70,$00),
  ($00,$66,$66,$66,$66,$7C,$60,$C0),($00,$76,$DC,$18,$18,$18,$18,$00),
  ($FC,$30,$78,$CC,$CC,$78,$30,$FC),($38,$6C,$C6,$FE,$C6,$6C,$38,$00),
  ($38,$6C,$C6,$C6,$6C,$6C,$EE,$00),($1C,$30,$18,$7C,$CC,$CC,$78,$00),
  ($00,$00,$7E,$DB,$DB,$7E,$00,$00),($06,$0C,$7E,$DB,$DB,$7E,$60,$C0),
  ($38,$60,$C0,$F8,$C0,$60,$38,$00),($78,$CC,$CC,$CC,$CC,$CC,$CC,$00),
  ($00,$FC,$00,$FC,$00,$FC,$00,$00),($30,$30,$FC,$30,$30,$00,$FC,$00),
  ($60,$30,$18,$30,$60,$00,$FC,$00),($18,$30,$60,$30,$18,$00,$FC,$00),
  ($0E,$1B,$1B,$18,$18,$18,$18,$18),($18,$18,$18,$18,$18,$D8,$D8,$70),
  ($30,$30,$00,$FC,$00,$30,$30,$00),($00,$76,$DC,$00,$76,$DC,$00,$00),
  ($38,$6C,$6C,$38,$00,$00,$00,$00),($00,$00,$00,$18,$18,$00,$00,$00),
  ($00,$00,$00,$00,$18,$00,$00,$00),($0F,$0C,$0C,$0C,$EC,$6C,$3C,$1C),
  ($78,$6C,$6C,$6C,$6C,$00,$00,$00),($70,$18,$30,$60,$78,$00,$00,$00),
  ($00,$00,$3C,$3C,$3C,$3C,$00,$00),($00,$00,$00,$00,$00,$00,$00,$00)
 );

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
Procedure SoundBell; Forward;

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
             While ConCol<CON_COLS Do Begin
               ConGlyph(ConRow,ConCol,32,False);Inc(ConCol);End;
             ConCol:=0;
            End;
       'K': Begin
             While ConCol<CON_COLS Do Begin
               ConGlyph(ConRow,ConCol,32,False);Inc(ConCol);End;
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
      If (Integer(B)-32>=0) And (Integer(B)-32<CON_COLS) Then
        ConCol:=Integer(B)-32;
     End;
  4: ConState:=0;
 Else
  Case B Of
   27: ConState:=1;
   13: ConCol:=0;
   10: Begin If ConRow>=CON_ROWS-1 Then ConScroll Else Inc(ConRow);End;
   8: If ConCol>0 Then Dec(ConCol);
   9: Begin ConCol:=(ConCol+8) And Not 7;If ConCol>=CON_COLS Then
     ConNewLine;End;
   7: SoundBell;
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

Var ScrForceFull : Boolean;     { base video changee : prochain affichage
  complet (efface l'ancien ecran) }

Procedure BlitScreen(Full: Boolean);
Var Y,XB,Bit: Integer; A: LongInt; B,O: Byte; Lo,Hi: Integer;
Begin
 If BatchMode Or Not GfxOn Then Exit;
 If MonActive And Not EmuVisible And Not Full Then Exit;
 If ScrForceFull Then Begin Full:=True;ScrForceFull:=False;End;
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
Procedure SoundTick; Forward;
Procedure IkDrain; Forward;

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
{ horloges systeme TOS : _hz_200 ($4BA), _vbclock ($462), _frclock ($466) }
Procedure TickSysVars;
Var T: LongInt;
Begin
 T:=MsNow Div 5;
 Wr32($4BA,T);Wr32($462,T Div 4);Wr32($466,T Div 4);
End;

Procedure PollKeys;
Var Ch: Char; K: Word; Scan,Asc: Integer;
Begin
 TickSysVars;
 SoundTick;
 IkDrain;
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

Procedure IrqNested; Forward;    { p20 : interruptions pendant une attente
  bloquante du systeme }

Procedure EmuIdle;
Begin
 PollKeys;
 IrqNested;
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
  On,Changed,RO,Virt : Boolean;
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

 { generateur sonore YM2149 / Dosound }
 SndPos,SndWait,SndLast,SndFreq : LongInt;
 SndTemp,SndSlReg,SndSlInc,SndSlEnd : Integer;
 SndSlide : Boolean;
 SndLogOpen,SndLogTried : Boolean;
 SndLog : Text;
 MfpEnable : LongInt;
 XbVec : Array[0..31] Of LongInt;

{ ---------------------------------------------------------------------- }
{ Son : la sortie utilise l'API Windows (Beep de kernel32, declaree ici sans  }
{ unite) ; ailleurs, Sound / NoSound de l'unite Crt                          }
{ ---------------------------------------------------------------------- }

{$IFDEF WINDOWS}
Function WinBeep(Freq,Dur: LongWord): LongInt; StdCall; External 'kernel32.dll'
  Name 'Beep';
{$ENDIF}

Procedure SoundOut(Freq: LongInt; Ms: Integer);
Begin
 If BatchMode Then Exit;
 {$IFDEF WINDOWS}
 If Freq>0 Then Begin
  If Freq<37 Then Freq:=37;
  If Freq>32767 Then Freq:=32767;
  If WinBeep(Freq,Ms)=0 Then Begin End;
 End;
 {$ELSE}
 If Freq>0 Then Sound(Freq) Else NoSound;
 {$ENDIF}
End;

Procedure SoundBell;
Begin
 If BatchMode Then Exit;
 {$IFDEF WINDOWS}
 SoundOut(880,80);
 {$ELSE}
 SoundOut(880,80);Delay(80);SoundOut(0,0);
 {$ENDIF}
End;

{ trace des notes jouees si la variable DEVPAC_SNDLOG nomme un fichier }
Procedure SndLogNote(F: LongInt);
Begin
 If Not SndLogTried Then Begin
  SndLogTried:=True;
  If GetEnv('DEVPAC_SNDLOG')<>'' Then Begin
   Assign(SndLog,GetEnv('DEVPAC_SNDLOG'));
   {$I-}
   Rewrite(SndLog);
   {$I+}
   SndLogOpen:=IOResult=0;
  End;
 End;
 If SndLogOpen Then Begin
  WriteLn(SndLog,F);
  Flush(SndLog);
 End;
End;

{ frequence jouee d'apres les registres du YM2149 (la voie la plus forte) }
Function SndRegsFreq: LongInt;
Var C,Vol,Best: Integer; F: LongInt; Per: LongInt;
Begin
 F:=0;Best:=0;
 For C:=0 To 2 Do Begin
  Vol:=GiRegs[8+C] And $1F;
  If (Vol>Best) Then Begin
   If (GiRegs[7] And (1 Shl C))=0 Then Begin
    Per:=GiRegs[C*2]+LongInt(GiRegs[C*2+1] And 15)*256;
    If Per<1 Then Per:=1;
    F:=125000 Div Per;Best:=Vol;
   End Else If (GiRegs[7] And (8 Shl C))=0 Then Begin
    { bruit : approxime par une note aigue }
    Per:=GiRegs[6] And 31;
    If Per<1 Then Per:=1;
    F:=125000 Div (Per*8);Best:=Vol;
   End;
  End;
 End;
 SndRegsFreq:=F;
End;

Procedure SoundOff;
Begin
 SoundOut(0,0);
 SndFreq:=0;SndPos:=0;SndSlide:=False;
End;

Procedure DosoundStart(P: LongInt);
Begin
 SndPos:=P;SndWait:=0;SndSlide:=False;SndTemp:=0;
End;

{ un pas (1/50 s) du sequenceur Dosound }
Procedure SndStep;
Var C,N,Guard,V: Integer;
 Function Nxt: Integer;
 Begin
  Nxt:=Rd8(SndPos);Inc(SndPos);
 End;
Begin
 If SndSlide Then Begin
  V:=GiRegs[SndSlReg And 15]+SndSlInc;
  GiRegs[SndSlReg And 15]:=V And $FF;
  If ((SndSlInc>0) And (V>=SndSlEnd)) Or ((SndSlInc<=0) And (V<=SndSlEnd)) Then
    Begin
   GiRegs[SndSlReg And 15]:=SndSlEnd And $FF;SndSlide:=False;
  End;
  Exit;
 End;
 If SndWait>0 Then Begin Dec(SndWait);If SndWait>0 Then Exit;End;
 Guard:=0;
 While (SndPos<>0) And (Guard<256) Do Begin
  Inc(Guard);
  C:=Nxt;
  If C<=15 Then GiRegs[C]:=Nxt And $FF
  Else If C=$80 Then SndTemp:=Nxt
  Else If C=$81 Then Begin
   SndSlReg:=Nxt;SndSlInc:=Nxt;If SndSlInc>127 Then SndSlInc:=SndSlInc-256;
   SndSlEnd:=Nxt;
   GiRegs[SndSlReg And 15]:=SndTemp And $FF;
   SndSlide:=True;Exit;
  End Else If C>=$82 Then Begin
   N:=Nxt;
   If N=0 Then Begin SndPos:=0;GiRegs[8]:=0;GiRegs[9]:=0;GiRegs[10]:=0;End
   Else Begin SndWait:=N;Exit;End;
  End;
 End;
End;

{ appele souvent : avance le sequenceur a 50 Hz et pilote le haut-parleur }
Procedure SoundTick;
Var T,F: LongInt;
Begin
 T:=MsNow;
 If T-SndLast<20 Then Exit;
 If T-SndLast>200 Then SndLast:=T-20;
 SndLast:=SndLast+20;
 If (SndPos<>0) Or SndSlide Then SndStep;
 F:=SndRegsFreq;
 If F<>SndFreq Then Begin
  SndLogNote(F);
  {$IFNDEF WINDOWS}
  SoundOut(F,20);
  {$ENDIF}
  SndFreq:=F;
 End;
 {$IFDEF WINDOWS}
 If F>0 Then SoundOut(F,20);
 {$ENDIF}
End;

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

Function DevIn(Var F: File; Var Opened,Tried: Boolean; Const Name: String; Var
  B: Byte): Boolean;
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

Function DevAvail(Var F: File; Var Opened,Tried: Boolean; Const Name: String):
  Boolean;
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
 SoundOff;
 {$I-}
 If AuxOutOpen Then Close(AuxOutF);
 If MidiOutOpen Then Close(MidiOutF);
 If PrnOutOpen Then Close(PrnOutF);
 If AuxInOpen Then Close(AuxInF);
 If MidiInOpen Then Close(MidiInF);
 {$I+}
 If IOResult<>0 Then Begin End;
 AuxOutOpen:=False;MidiOutOpen:=False;PrnOutOpen:=False;AuxInOpen:=False;
   MidiInOpen:=False;
 AuxInTried:=False;MidiInTried:=False;
End;

{ ---------------------------------------------------------------------- }
{ Images de disquettes (secteurs de 512 octets)                            }
{ ---------------------------------------------------------------------- }

Procedure FlpClose(D: Integer);
Begin
 If Flp[D].On Then Begin
  If Not Flp[D].Virt Then Begin
   {$I-}
   Close(Flp[D].F);
   {$I+}
   If IOResult<>0 Then Begin End;
  End;
  Flp[D].On:=False;Flp[D].Virt:=False;
 End;
End;

{ Disquette vierge formatee 720 Ko (9 secteurs, 2 faces, 80 pistes) }
Type TSec = Array[0..511] Of Byte;

Procedure BlankSector(Lsn: LongInt; Var B: TSec);
Const Oem : String[6] = 'DEVPAC';
Var I: Integer;
Begin
 FillChar(B,SizeOf(B),0);
 If Lsn=0 Then Begin
  B[0]:=$60;B[1]:=$1C;
  For I:=1 To 6 Do B[1+I]:=Ord(Oem[I]);
  B[11]:=0;B[12]:=2;B[13]:=2;B[14]:=1;B[15]:=0;B[16]:=2;B[17]:=112;B[18]:=0;
  B[19]:=$A0;B[20]:=$05;B[21]:=$F9;B[22]:=5;B[23]:=0;B[24]:=9;B[25]:=0;B[26]:=2;
    B[27]:=0;
 End Else If (Lsn=1) Or (Lsn=6) Then Begin
  B[0]:=$F9;B[1]:=$FF;B[2]:=$FF;
 End;
End;

{ Monte une disquette vierge : aucun fichier n'existe tant qu'on n'y ecrit pas }
Procedure FlpMountBlank(D: Integer; Const Name: String);
Begin
 FlpClose(D);
 Flp[D].On:=True;Flp[D].Virt:=True;Flp[D].RO:=False;Flp[D].Changed:=True;
 Flp[D].Name:=Name;Flp[D].Size:=737280;Flp[D].Spt:=9;Flp[D].Sides:=2;Flp[D].
   Tracks:=80;
End;

{ Cree le fichier image d'une disquette vierge lors de la premiere ecriture }
Function FlpMaterialize(D: Integer): Boolean;
Var B: TSec; L: LongInt; Got: LongInt;
Begin
 FlpMaterialize:=False;
 Assign(Flp[D].F,Flp[D].Name);
 {$I-}
 Rewrite(Flp[D].F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 For L:=0 To 1439 Do Begin
  BlankSector(L,B);
  {$I-}
  BlockWrite(Flp[D].F,B,512,Got);
  {$I+}
  If IOResult<>0 Then Begin Close(Flp[D].F);Exit;End;
 End;
 {$I-}
 Close(Flp[D].F);
 FileMode:=2;
 Reset(Flp[D].F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 Flp[D].Virt:=False;
 FlpMaterialize:=True;
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
 Flp[D].On:=True;Flp[D].Virt:=False;Flp[D].Changed:=True;Flp[D].Name:=Name;
 Flp[D].Size:=FileSize(Flp[D].F);
 FillChar(B,SizeOf(B),0);
 {$I-}
 BlockRead(Flp[D].F,B,32,Got);
 {$I+}
 If IOResult<>0 Then Begin End;
 Bps:=B[11]+B[12]*256;Spt:=B[24]+B[25]*256;Sd:=B[26]+B[27]*256;Tot:=B[19]+
   B[20]*256;
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
Function FlpRW(D: Integer; Lsn,Count: LongInt; Buf: LongInt; Wr: Boolean):
  Integer;
Var I,J: LongInt; Tmp: TSec; Got: LongInt;
Begin
 FlpRW:=E_NOTRDY;
 If (D<0) Or (D>3) Or Not Flp[D].On Then Exit;
 If Wr And Flp[D].RO Then Begin FlpRW:=E_WRPRO;Exit;End;
 If (Lsn<0) Or ((Lsn+Count)*512>Flp[D].Size) Then Begin FlpRW:=E_RNF;Exit;End;
 If Flp[D].Virt Then Begin
  If Wr Then Begin
   If Not FlpMaterialize(D) Then Begin FlpRW:=E_WRITF;Exit;End;
  End Else Begin
   For I:=0 To Count-1 Do Begin
    BlankSector(Lsn+I,Tmp);
    For J:=0 To 511 Do Wr8(Buf+I*512+J,Tmp[J]);
   End;
   FlpRW:=E_OK;Exit;
  End;
 End;
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
  If IOResult<>0 Then Begin If Wr Then FlpRW:=E_WRITF Else
    FlpRW:=E_READF;Exit;End;
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
 SndPos:=0;MfpEnable:=0;FlpRate:=2;
 For I:=0 To 3 Do Begin
  If FlpImage[I]<>'' Then Begin
   If FileExists(FlpImage[I]) Then FlpMount(I,FlpImage[I])
   Else FlpMountBlank(I,FlpImage[I]);
  End Else Begin
   If FileExists('DISK'+Chr(65+I)+'.ST') Then FlpMount(I,'DISK'+Chr(65+I)+'.ST')
   Else If FileExists('disk'+Chr(97+I)+'.st') Then
     FlpMount(I,'disk'+Chr(97+I)+'.st')
   Else If I=0 Then FlpMountBlank(0,'DISKA.ST');
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
 PexBp : LongInt;            { base page du fils Pexec en cours }
 MBase,MSize,MOwn : Array[1..64] Of LongInt;   { blocs Malloc : adresse,
   taille, proprietaire (page de base) }
 CurOwn      : LongInt;           { page de base du processus en cours (0 =
   programme principal) }
 MCnt        : Integer;
 DtaAddr     : LongInt;
 FHUsed      : Array[6..MAXFH] Of Boolean;
 FHs         : Array[6..MAXFH] Of File;
 FScratch    : File;                { Fdelete / Frename : ne doit jamais reutiliser un fichier ouvert }
 DtaSR       : SearchRec;
 DtaActive   : Boolean;
 AmigaRun    : Boolean;
 UnknownCall : String;
 VdiLineCol,VdiFillInt,VdiFillCol,VdiTextCol,VdiFillStyle : Integer;
 RandSeed68  : LongInt;
 ProgName    : String;
 ProgCmd     : String;
 DosTrace    : Boolean;
 DosUserSP   : LongInt;        { pile utilisateur memorisee par Super(pile) }
 VdiTrace    : Boolean;        { DEVPAC_TRACE=2 : trace detaillee VDI/objets }

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

{ ---------------------------------------------------------------------- }
{ Systeme de fichiers virtuel GEMDOS : la racine du lecteur est le        }
{ dossier hote courant au lancement de l'emulation (jamais la racine de   }
{ l'hote) ; les noms sont insensibles a la casse (comme sur disque ST).   }
{ ---------------------------------------------------------------------- }
Const
 DOS_MAXSRCH = 16;
 DOS_MAXENT  = 400;
 {$IFDEF FPC}
 {$IFDEF UNIX}
 HSEP = '/';
 {$ELSE}
 HSEP = '\';
 {$ENDIF}
 {$ELSE}
 HSEP = '\';
 {$ENDIF}

Type
 TDosEnt = Record Nm: String[12]; At: Byte; Sz: LongInt; Tm: LongInt; End;
 TDosSrch = Record N: Integer; Ent: Array[1..DOS_MAXENT] Of TDosEnt; End;
 PDosSrch = ^TDosSrch;

Var
 DosRoot : String;         { dossier hote de la racine, separateur final }
 DosCur  : String;         { repertoire courant virtuel : A\B (vide = racine) }
 DosDrv  : Integer;        { lecteur courant : 0=A ... 2=C }
 DosSrch : Array[0..DOS_MAXSRCH-1] Of PDosSrch;
 DosSrchNext : Integer;

{ la racine est le dossier hote courant (il peut etre change par le lanceur :
  « dossier d'execution ») }
Function DosRootNow: String;
Var S: String;
Begin
 GetDir(0,S);
 If (S<>'') And (S[Length(S)]<>HSEP) Then S:=S+HSEP;
 DosRoot:=S;
 DosRootNow:=S;
End;

Procedure DosInit;
Begin
 DosRootNow;DosCur:='';DosDrv:=2;
 DosSrchNext:=0;
End;

{ chemin TOS -> composants normalises (casse conservee) : A\B\C ; Abs=True si
  lecteur/'\' initial }
Function DosVirt(Const S0: String): String;
Var S,Base,Cur,Res: String; I: Integer;
 Procedure Flush1;
 Var P: Integer;
 Begin
  If Cur='' Then Exit;
  If Cur='.' Then Begin Cur:='';Exit;End;
  If Cur='..' Then Begin
   P:=Length(Res);
   While (P>0) And (Res[P]<>'\') Do Dec(P);
   If P>0 Then Res:=Copy(Res,1,P-1) Else Res:='';
   Cur:='';Exit;
  End;
  If Res<>'' Then Res:=Res+'\';
  Res:=Res+Cur;Cur:='';
 End;
Begin
 S:=S0;
 If (Length(S)>=2) And (S[2]=':') Then S:=Copy(S,3,255);
 If (S<>'') And ((S[1]='\') Or (S[1]='/')) Then Res:=''
 Else Res:=DosCur;
 Cur:='';
 For I:=1 To Length(S) Do
  If (S[I]='\') Or (S[I]='/') Then Flush1 Else Cur:=Cur+S[I];
 Flush1;
 DosVirt:=Res;
End;

Function DosIsHostAbs(Const S: String): Boolean;
Begin
 {$IFDEF FPC}
 {$IFDEF UNIX}
 DosIsHostAbs:=(S<>'') And (S[1]='/');
 {$ELSE}
 DosIsHostAbs:=False;
 {$ENDIF}
 {$ELSE}
 DosIsHostAbs:=False;
 {$ENDIF}
End;

{ cherche Nm (insensible a la casse) dans le dossier hote Dir ; renvoie le nom
  reel et l'attribut }
Function DosLookup(Const Dir,Nm: String; Var Real_: String; Var At: Integer):
  Boolean;
Var SR: SearchRec; U: String; Found: Boolean;
Begin
 Found:=False;
 U:=Upper(Nm);
 FindFirst(Dir+'*',AnyFile,SR);
 While DosError=0 Do Begin
  If Upper(SR.Name)=U Then Begin
    Real_:=SR.Name;At:=SR.Attr;Found:=True;Break;End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 DosLookup:=Found;
End;

{ chemin TOS -> chemin hote ; Dir=True : tout le chemin est un repertoire
  (sinon le dernier composant
  peut ne pas exister et garde la casse donnee). DirOk indique que le
    repertoire existe. }
Function DosHost(Const S1: String; Var HostDir,Last: String): Boolean;
Var V,H,C,R,S0: String; P,At: Integer; Ok: Boolean;
Begin
 Ok:=True;
 { les programmes Pascal (OSS) transmettent des noms completes par des blancs : ils sont ignores }
 S0:=S1;
 While (S0<>'') And (S0[Length(S0)]=' ') Do Dec(S0[0]);
 If DosIsHostAbs(S0) Then Begin
  P:=Length(S0);
  While (P>0) And (S0[P]<>'/') Do Dec(P);
  HostDir:=Copy(S0,1,P);Last:=Copy(S0,P+1,255);
  DosHost:=True;Exit;
 End;
 V:=DosVirt(S0);
 { dernier composant }
 P:=Length(V);
 While (P>0) And (V[P]<>'\') Do Dec(P);
 Last:=Copy(V,P+1,255);
 V:=Copy(V,1,P);               { avec '\' final }
 H:=DosRootNow;
 While (V<>'') Do Begin
  P:=Pos('\',V);
  C:=Copy(V,1,P-1);V:=Copy(V,P+1,255);
  If DosLookup(H,C,R,At) And ((At And Directory)<>0) Then H:=H+R+HSEP
  Else Begin H:=H+C+HSEP;Ok:=False;End;
 End;
 HostDir:=H;
 DosHost:=Ok;
End;

{ nom hote complet (le dernier composant est cherche sans tenir compte de la
  casse) }
Function TosPath(Const S0: String): String;
Var H,L,R: String; At: Integer;
Begin
 If (S0='') Or (S0='.') Then Begin DosHost('.',H,L);TosPath:=H+L;Exit;End;
 If DosHost(S0,H,L) Then Begin
  If (L<>'') And DosLookup(H,L,R,At) Then L:=R;
 End;
 TosPath:=H+L;
End;

Function DosIsDir(Const S: String): Boolean;
Var H,L,R: String; At: Integer;
Begin
 DosIsDir:=False;
 If Not DosHost(S,H,L) Then Exit;
 If L='' Then Begin DosIsDir:=True;Exit;End;
 If DosLookup(H,L,R,At) Then DosIsDir:=(At And Directory)<>0;
End;

{ jokers TOS : * et ? sur le nom et l'extension separement }
Function DosWild(Const Pt,Nm: String): Boolean;
 Function M(Const P,N: String; I,J: Integer): Boolean;
 Begin
  If I>Length(P) Then M:=J>Length(N)
  Else If P[I]='*' Then Begin
   M:=M(P,N,I+1,J) Or ((J<=Length(N)) And M(P,N,I,J+1));
  End Else If J>Length(N) Then M:=False
  Else If (P[I]='?') Or (P[I]=N[J]) Then M:=M(P,N,I+1,J+1)
  Else M:=False;
 End;
Var PB,PE,NB,NE,P0,N0: String; I: Integer;
Begin
 P0:=Upper(Pt);N0:=Upper(Nm);
 I:=Pos('.',P0);
 If I>0 Then Begin PB:=Copy(P0,1,I-1);PE:=Copy(P0,I+1,20);End Else Begin
   PB:=P0;PE:='*';End;
 I:=Pos('.',N0);
 If (I>0) And (N0<>'.') And (N0<>'..') Then Begin
   NB:=Copy(N0,1,I-1);NE:=Copy(N0,I+1,20);End Else Begin NB:=N0;NE:='';End;
 DosWild:=M(PB,NB,1,1) And M(PE,NE,1,1);
End;

{ nom hote acceptable comme nom 8.3 TOS ? }
Function DosName83(Const N: String): Boolean;
Var P: Integer;
Begin
 DosName83:=False;
 If (N='.') Or (N='..') Then Begin DosName83:=True;Exit;End;
 If (N='') Or (N[1]='.') Then Exit;
 P:=Pos('.',N);
 If P=0 Then Begin DosName83:=Length(N)<=8;Exit;End;
 If (P>9) Or (Length(N)-P>3) Or (Pos('.',Copy(N,P+1,20))>0) Then Exit;
 DosName83:=True;
End;

Function DosSrchSlot: Integer;
Var K: Integer;
Begin
 K:=DosSrchNext;
 DosSrchNext:=(DosSrchNext+1) Mod DOS_MAXSRCH;
 If DosSrch[K]=Nil Then New(DosSrch[K]);
 DosSrchSlot:=K;
End;

{ Fsfirst : remplit la recherche ; retourne le numero de slot ou -1 }
Function DosSearch(Const Spec: String; Attr: Integer): Integer;
Var H,L: String; SR: SearchRec; K,I,J: Integer; D: PDosSrch; E: TDosEnt; N:
  String; Ok,InRoot: Boolean;
    V: String;
Begin
 DosSearch:=-1;
 If Not DosHost(Spec,H,L) Then Exit;
 V:=DosVirt(Spec);
 InRoot:=Pos('\',V)=0;
 K:=DosSrchSlot;D:=DosSrch[K];D^.N:=0;
 FindFirst(H+'*',AnyFile,SR);
 While (DosError=0) And (D^.N<DOS_MAXENT) Do Begin
  N:=Upper(SR.Name);
  Ok:=DosName83(N) And DosWild(L,N);
  If Ok And InRoot And ((N='.') Or (N='..')) Then Ok:=False;
  If Ok Then Begin
   E.At:=SR.Attr And $37;
   If (SR.Attr And Directory)<>0 Then E.At:=E.At Or $10 Else E.At:=E.At Or $20;
   E.At:=E.At And $3F;
   If (N='.') Or (N='..') Then E.At:=$10;
   { attributs demandes : cachee/systeme/repertoire seulement sur demande }
   If ((E.At And $16) And Not Attr)<>0 Then Ok:=False;
   If (Attr=8) Then Ok:=False;
   If Ok Then Begin
    E.Nm:=N;E.Sz:=SR.Size;E.Tm:=SR.Time;
    If (SR.Attr And Directory)<>0 Then E.Sz:=0;
    Inc(D^.N);D^.Ent[D^.N]:=E;
   End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}
 FindClose(SR);
 {$ENDIF}
 { tri alphabetique (noms), '.' et '..' en tete }
 For I:=2 To D^.N Do Begin
  E:=D^.Ent[I];J:=I-1;
  While (J>=1) And (D^.Ent[J].Nm>E.Nm) Do Begin
    D^.Ent[J+1]:=D^.Ent[J];Dec(J);End;
  D^.Ent[J+1]:=E;
 End;
 If D^.N=0 Then DosSearch:=-1 Else DosSearch:=K;
End;

{ Dgetpath : repertoire courant virtuel, en majuscules, avec '\' initial (vide
  a la racine) }
Function DosCurPath: String;
Begin
 If DosCur='' Then DosCurPath:='' Else DosCurPath:='\'+Upper(DosCur);
End;

{ chemin TOS complet (avec lecteur) a partir d'un repertoire virtuel }
Function DosDriveLetter: Char;
Begin
 DosDriveLetter:=Chr(65+DosDrv);
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
  Inc(MCnt);MBase[MCnt]:=A;MSize[MCnt]:=N;MOwn[MCnt]:=CurOwn;
 End;
 DoMalloc:=A;
End;

Function DoMfree(A: LongInt): LongInt;
Var I,J: Integer;
Begin
 DoMfree:=-40;
 For I:=1 To MCnt Do
  If MBase[I]=A Then Begin
   For J:=I To MCnt-1 Do Begin
     MBase[J]:=MBase[J+1];MSize[J]:=MSize[J+1];MOwn[J]:=MOwn[J+1];End;
   Dec(MCnt);
   DoMfree:=0;Exit;
  End;
End;

{ libere tous les blocs appartenant au processus de page de base Bp (fin d'un
  fils) }
Procedure FreeOwned(Bp: LongInt);
Var I,J: Integer;
Begin
 I:=1;
 While I<=MCnt Do Begin
  If MOwn[I]=Bp Then Begin
   For J:=I To MCnt-1 Do Begin
     MBase[J]:=MBase[J+1];MSize[J]:=MSize[J+1];MOwn[J]:=MOwn[J+1];End;
   Dec(MCnt);
  End Else Inc(I);
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

Procedure FillDtaEnt(Const E: TDosEnt);
Var I: Integer;
Begin
 Wr8(DtaAddr+21,E.At And $FF);
 Wr16(DtaAddr+22,E.Tm And $FFFF);
 Wr16(DtaAddr+24,ShrL(E.Tm,16) And $FFFF);
 Wr32(DtaAddr+26,E.Sz);
 For I:=0 To 13 Do Wr8(DtaAddr+30+I,0);
 For I:=1 To Length(E.Nm) Do If I<=13 Then Wr8(DtaAddr+29+I,Ord(E.Nm[I]));
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
Var Fn: LongInt; R: LongInt; H: Integer; I,N: LongInt; S: String; K: LongInt;
  Buf: Array[0..4095] Of Byte;
    Cnt,Got,A,Off: LongInt; Bb: Byte; Y,Mo,D,Dw,Hh,Mi,Se,Hs: Word; Fp: LongInt;
    FPtr: ^File;
Begin
 Fn:=PW(0);
 R:=0;
 If DosTrace Then Begin
   WriteLn(ConOut,'GEMDOS $',Hex2(Fn),' ',Hex8(PL(2)),' ',Hex8(PL(6)),' ',
   Hex8(PL(10)),' pc=',Hex8(PC),' sp=',Hex8(Rg[15]));Flush(ConOut);End;
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
  $0E: Begin DosDrv:=PW(2) And 15;R:=4;End;
  $10: R:=-1;
  $11: R:=-1;
  $12: Begin If AuxAvail Then R:=-1 Else R:=0;End;
  $13: R:=-1;
  $19: R:=DosDrv;
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
        End Else If (SRv And SR_S)=0 Then Begin
         { mode utilisateur -> superviseur avec une nouvelle pile superviseur
           (ex. MonST) }
         DosUserSP:=Rg[15];R:=SSPv;
         SRv:=SRv Or SR_S;
         Rg[15]:=A;SSPv:=A;
        End Else Begin
         { superviseur -> utilisateur : on restitue la pile utilisateur si elle
           avait ete changee }
         SRv:=SRv And (Not SR_S);
         If DosUserSP<>0 Then Begin Rg[15]:=DosUserSP;DosUserSP:=0;End;
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
  $39: Begin
        S:=TosPath(RdStr(PL(2),200));
        {$I-}
        MkDir(S);
        {$I+}
        If IOResult<>0 Then R:=-36 Else R:=0;
       End;
  $3A: Begin
        S:=TosPath(RdStr(PL(2),200));
        {$I-}
        RmDir(S);
        {$I+}
        If IOResult<>0 Then R:=-36 Else R:=0;
       End;
  $3B: Begin
        S:=RdStr(PL(2),200);
        If DosIsDir(S) Then DosCur:=Upper(DosVirt(S)) Else R:=-34;
       End;
  $3C,$3D: Begin
        S:=TosPath(RdStr(PL(2),200));
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
          If H=1 Then ConPut(Rd8(A+I)) Else If H=2 Then AuxPut(Rd8(A+I)) Else
            PrnPut(Rd8(A+I));
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
        S:=TosPath(RdStr(PL(2),200));
        Assign(FScratch,S);
        {$I-}
        Erase(FScratch);
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
  $43: Begin
        S:=RdStr(PL(2),200);
        If DosIsDir(S) Then R:=$10
        Else Begin
         I:=DosSearch(S,$17);
         If I<0 Then R:=-33 Else R:=DosSrch[I]^.Ent[1].At And $27;
        End;
       End;
  $45: R:=-36;
  $47: Begin
        A:=PL(2);S:=DosCurPath;
        For I:=1 To Length(S) Do Wr8(A+I-1,Ord(S[I]));
        Wr8(A+Length(S),0);
       End;
  $48: R:=DoMalloc(PL(2));
  $49: R:=DoMfree(PL(2));
  $4A: Begin
        A:=PL(4);N:=PL(8);
        R:=-40;
        { bloc obtenu par Malloc / Pexec(5) : on le reduit }
        For I:=1 To MCnt Do
         If MBase[I]=A Then Begin
          If (N>=0) And (N<MSize[I]) Then MSize[I]:=(N+1) And (Not 1);
          R:=0;
         End;
        If (R<>0) And ((A=BP_ADDR) Or (A=PexBp)) Then Begin
         HeapLo:=A+((N+1) And (Not 1));
         If HeapLo>HeapHi Then HeapLo:=HeapHi;
         R:=0;
        End;
       End;
  $4B: R:=DoPexec(PW(2),PL(4),PL(8),PL(12));
  $4E: Begin
        I:=DosSearch(RdStr(PL(2),200),PW(6));
        If I<0 Then R:=-33
        Else Begin
         Wr16(DtaAddr,$4000+I);Wr16(DtaAddr+2,1);
         FillDtaEnt(DosSrch[I]^.Ent[1]);R:=0;
        End;
       End;
  $4F: Begin
        I:=Rd16(DtaAddr)-$4000;
        If (I<0) Or (I>=DOS_MAXSRCH) Or (DosSrch[I]=Nil) Then R:=-33
        Else Begin
         N:=Rd16(DtaAddr+2)+1;
         If N>DosSrch[I]^.N Then R:=-49
         Else Begin
          Wr16(DtaAddr+2,N);FillDtaEnt(DosSrch[I]^.Ent[N]);R:=0;
         End;
        End;
       End;
  $56: Begin
        S:=TosPath(RdStr(PL(4),200));
        Assign(FScratch,S);
        {$I-}
        Rename(FScratch,TosPath(RdStr(PL(8),200)));
        {$I+}
        If IOResult<>0 Then R:=-33 Else R:=0;
       End;
  $57: Begin
        H:=PW(6);
        If (PW(8)=0) And (H>=6) And (H<=MAXFH) And FHUsed[H] Then Begin
         {$I-}
         GetFTime(FHs[H],Fp);
         {$I+}
         If IOResult<>0 Then Fp:=0;
         Wr16(PL(2),Fp And $FFFF);Wr16(PL(2)+2,ShrL(Fp,16) And $FFFF);
        End Else If (PW(8)<>0) And (H>=6) And (H<=MAXFH) And FHUsed[H] Then
          Begin
         Fp:=Rd16(PL(2)) Or (LongInt(Rd16(PL(2)+2)) Shl 16);
         {$I-}
         SetFTime(FHs[H],Fp);
         {$I+}
         If IOResult<>0 Then Begin End;
        End Else R:=-37;
       End;
 Else Begin
   UnknownCall:='GEMDOS $'+Hex2(Fn);
   R:=-32;
  End;
 End;
 If DosTrace And Not ((Fn=$02) Or (Fn=$09) Or (Fn=$06) Or (Fn=$0B)) Then Begin
   WriteLn(ConOut,'   -> ',R,' ($',Hex8(R),')');Flush(ConOut);End;
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
  (1,27,27),(2,49,33),(3,50,64),(4,51,35),(5,52,36),(6,53,37),(7,54,94),(8,55,
    38),(9,56,42),(10,57,40),
  (11,48,41),(12,45,95),(13,61,43),(14,8,8),(15,9,9),(26,91,123),(27,93,125),
    (28,13,13),(39,59,58),(40,39,34),
  (41,96,126),(43,92,124),(51,44,60),(52,46,62),(53,47,63),(57,32,32),(83,127,
    127),(74,45,45),(78,43,43),(99,40,40),
  (100,41,41),(101,47,47),(102,42,42),(103,55,55),(104,56,56),(105,57,57),(106,
    52,52),(107,53,53),(108,54,54),(109,49,49),
  (110,50,50),(111,51,51),(112,48,48),(113,46,46),(114,13,13),(0,0,0));
 L1 : String[10] = 'qwertyuiop';
 L2 : String[9]  = 'asdfghjkl';
 L3 : String[7]  = 'zxcvbnm';
Var I: Integer; C: Char;
Begin
 For I:=0 To 127 Do Begin
   Wr8(KT_UNSH+I,0);Wr8(KT_SHIFT+I,0);Wr8(KT_CAPS+I,0);End;
 For I:=0 To 44 Do Begin
  Wr8(KT_UNSH+Rows[I,0],Rows[I,1]);Wr8(KT_SHIFT+Rows[I,0],Rows[I,
    2]);Wr8(KT_CAPS+Rows[I,0],Rows[I,1]);
 End;
 For I:=1 To 10 Do Begin
  Wr8(KT_UNSH+15+I,Ord(L1[I]));Wr8(KT_SHIFT+15+I,
    Ord(UpCase(L1[I])));Wr8(KT_CAPS+15+I,Ord(UpCase(L1[I])));
 End;
 For I:=1 To 9 Do Begin
  Wr8(KT_UNSH+29+I,Ord(L2[I]));Wr8(KT_SHIFT+29+I,
    Ord(UpCase(L2[I])));Wr8(KT_CAPS+29+I,Ord(UpCase(L2[I])));
 End;
 For I:=1 To 7 Do Begin
  Wr8(KT_UNSH+43+I,Ord(L3[I]));Wr8(KT_SHIFT+43+I,
    Ord(UpCase(L3[I])));Wr8(KT_CAPS+43+I,Ord(UpCase(L3[I])));
 End;
 Wr32(KT_PTRS,KT_UNSH);Wr32(KT_PTRS+4,KT_SHIFT);Wr32(KT_PTRS+8,KT_CAPS);
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
  2: If ((Y Mod 4)=0) And (((Y Mod 100)<>0) Or ((Y Mod 400)=0)) Then DaysIn:=29
    Else DaysIn:=28;
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
  If D>DaysIn(Y,Mo) Then Begin D:=1;Inc(Mo);If Mo>12 Then Begin
    Mo:=1;Inc(Y);End;End;
 End;
 H:=T Div 3600;Mi:=(T Mod 3600) Div 60;S:=T Mod 60;
 PackedAdd:=(LongInt((Y-1980) Shl 9 Or (Mo Shl 5) Or D) Shl 16) Or LongInt((H
   Shl 11) Or (Mi Shl 5) Or (S Div 2));
End;

Function HostPacked: LongInt;
Var Y,Mo,D,Dw,H,Mi,S,Hs: Word;
Begin
 GetDate(Y,Mo,D,Dw);GetTime(H,Mi,S,Hs);
 HostPacked:=(LongInt((Y-1980) Shl 9 Or (Mo Shl 5) Or D) Shl 16) Or LongInt((H
   Shl 11) Or (Mi Shl 5) Or (S Div 2));
End;

Function MfpEndAddr: LongInt;
Begin
 MfpEndAddr:=0;
End;

Procedure ProtoBootSector(Buf: LongInt; Serial: LongInt; DiskType: Integer;
  Exec: Integer);
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
  Wr8(Buf+8,ShrL(Serial,16) And $FF);Wr8(Buf+9,ShrL(Serial,8) And
    $FF);Wr8(Buf+10,Serial And $FF);
  Wr8(Buf+11,0);Wr8(Buf+12,2);Wr8(Buf+13,Spc);Wr8(Buf+14,1);Wr8(Buf+15,0);
  Wr8(Buf+16,2);Wr8(Buf+17,Nroot And $FF);Wr8(Buf+18,Nroot Shr 8);
  Wr8(Buf+19,Tot And $FF);Wr8(Buf+20,Tot Shr 8);Wr8(Buf+21,Media);
  Wr8(Buf+22,Spf);Wr8(Buf+23,0);Wr8(Buf+24,9);Wr8(Buf+25,0);Wr8(Buf+26,
    Sides);Wr8(Buf+27,0);
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
 If EnvPathS<>'' Then Add('PATH='+EnvPathS) Else Add('PATH=A:\;C:\');
 If EnvClinkS<>'' Then Add('CLINKWITH='+EnvClinkS);
 If EnvLibsS<>'' Then Add('LIBS='+EnvLibsS);
 Add('TERM=st52');
 Add('HOME=C:\');
 S:=GetEnv('LANGUAGE');
 If S<>'' Then Add('LANGUAGE='+S);
 Wr8(A,0);Wr8(A+1,0);
End;

{ ====================================================================== }
{              CLAVIER INTELLIGENT (IKBD) : COMMANDES ET PAQUETS           }
{ ====================================================================== }

Const
 IKBD_PKT = $8340;
 IK_STAT = 12; IK_MOUSE = 16; IK_CLOCK = 20; IK_JOY = 24;

Var
 IkMouseOn,IkPaused,IkYBottom,IkClockSet : Boolean;
 IkMouseMode : Integer;          { 1 relatif, 2 absolu, 3 touches du curseur }
 IkBtnAct : Integer;
 IkThrX,IkThrY,IkScX,IkScY,IkKeyDx,IkKeyDy : Integer;
 IkXMax,IkYMax : Integer;
 IkAbsX,IkAbsY,IkAccX,IkAccY,IkLastX,IkLastY : LongInt;
 IkJoyMode : Integer;
 IkClockPacked,IkClockBase : LongInt;
 IkRam : Array[0..127] Of Byte;
 IkBuf : Array[0..127] Of Byte;
 IkN : Integer;
 IkTmp : Array[0..15] Of Byte;
 IkQN : Integer;
 IkQVec,IkQLen : Array[0..15] Of Integer;
 IkQPkt : Array[0..15,0..15] Of Byte;

Procedure IkQueue(Vec,Len: Integer);
Begin
 If IkQN>=16 Then Exit;
 IkQVec[IkQN]:=Vec;IkQLen[IkQN]:=Len;
 Move(IkTmp,IkQPkt[IkQN],16);
 Inc(IkQN);
End;

Procedure IkReset;
Begin
 IkMouseOn:=True;IkPaused:=False;IkYBottom:=False;IkMouseMode:=1;IkBtnAct:=0;
 IkThrX:=1;IkThrY:=1;IkScX:=1;IkScY:=1;IkKeyDx:=1;IkKeyDy:=1;
 IkXMax:=639;IkYMax:=399;IkAbsX:=0;IkAbsY:=0;IkAccX:=0;IkAccY:=0;IkJoyMode:=0;
   IkN:=0;
End;

Function BcdToI(B: Integer): Integer;
Begin
 BcdToI:=((B Shr 4) And 15)*10+(B And 15);
End;

Function IToBcd(V: Integer): Integer;
Begin
 IToBcd:=((V Div 10) Shl 4) Or (V Mod 10);
End;

Procedure IkSendAbs(Flags: Integer);
Begin
 IkTmp[0]:=$F7;IkTmp[1]:=Flags And $FF;
 IkTmp[2]:=(IkAbsX Shr 8) And $FF;IkTmp[3]:=IkAbsX And $FF;
 IkTmp[4]:=(IkAbsY Shr 8) And $FF;IkTmp[5]:=IkAbsY And $FF;
 IkQueue(IK_MOUSE,6);
End;

{ Evenement souris vu par le clavier intelligent : position et boutons ecran
  (bit 0 gauche, bit 1 droit) avant / apres }
Procedure IkMouseEvent(AX,AY,NewB,OldB: LongInt);
Var Dx,Dy,Bt,Cx,Cy,Fl,P: Integer;
Begin
 Dx:=AX-IkLastX;Dy:=AY-IkLastY;IkLastX:=AX;IkLastY:=AY;
 If (Not IkMouseOn) Or IkPaused Then Exit;
 { bit 0 = bouton droit, bit 1 = bouton gauche dans les paquets IKBD }
 Bt:=((NewB And 1) Shl 1) Or ((NewB And 2) Shr 1);
 Case IkMouseMode Of
  1: Begin
      IkAccX:=IkAccX+Dx;IkAccY:=IkAccY+Dy;
      While (NewB<>OldB) Or (Abs(IkAccX)>=IkThrX) Or (Abs(IkAccY)>=IkThrY) Do
        Begin
       Cx:=Clamp(IkAccX,-128,127);Cy:=Clamp(IkAccY,-128,127);
       If (Abs(IkAccX)<IkThrX) And (Abs(IkAccY)<IkThrY) Then Begin
         Cx:=0;Cy:=0;End;
       IkTmp[0]:=$F8 Or Bt;IkTmp[1]:=Cx And $FF;IkTmp[2]:=Cy And $FF;
       IkQueue(IK_MOUSE,3);
       IkAccX:=IkAccX-Cx;IkAccY:=IkAccY-Cy;OldB:=NewB;
       If (Abs(IkAccX)<IkThrX) And (Abs(IkAccY)<IkThrY) Then Break;
      End;
     End;
  2: Begin
      IkAbsX:=Clamp(AX Div Max2(IkScX,1),0,IkXMax);
      If IkYBottom Then IkAbsY:=Clamp((399-AY) Div Max2(IkScY,1),0,IkYMax)
      Else IkAbsY:=Clamp(AY Div Max2(IkScY,1),0,IkYMax);
      If NewB<>OldB Then Begin
       Fl:=0;
       P:=((OldB And 1) Shl 1) Or ((OldB And 2) Shr 1);
       If ((Bt And 1)<>0) And ((P And 1)=0) And ((IkBtnAct And 1)<>0) Then
         Fl:=Fl Or 1;
       If ((Bt And 1)=0) And ((P And 1)<>0) And ((IkBtnAct And 2)<>0) Then
         Fl:=Fl Or 2;
       If ((Bt And 2)<>0) And ((P And 2)=0) And ((IkBtnAct And 1)<>0) Then
         Fl:=Fl Or 4;
       If ((Bt And 2)=0) And ((P And 2)<>0) And ((IkBtnAct And 2)<>0) Then
         Fl:=Fl Or 8;
       If Fl<>0 Then IkSendAbs(Fl);
      End;
     End;
  3: Begin
      IkAccX:=IkAccX+Dx;IkAccY:=IkAccY+Dy;
      While IkAccX>=IkKeyDx Do Begin KQPush(LongInt(77) Shl
        16);IkAccX:=IkAccX-IkKeyDx;End;
      While IkAccX<=-IkKeyDx Do Begin KQPush(LongInt(75) Shl
        16);IkAccX:=IkAccX+IkKeyDx;End;
      While IkAccY>=IkKeyDy Do Begin KQPush(LongInt(80) Shl
        16);IkAccY:=IkAccY-IkKeyDy;End;
      While IkAccY<=-IkKeyDy Do Begin KQPush(LongInt(72) Shl
        16);IkAccY:=IkAccY+IkKeyDy;End;
     End;
 End;
End;

Procedure IkStatus(Cmd,B1,B2,B3,B4,B5,B6: Integer);
Begin
 FillChar(IkTmp,SizeOf(IkTmp),0);
 IkTmp[0]:=$F6;IkTmp[1]:=Cmd;IkTmp[2]:=B1;IkTmp[3]:=B2;IkTmp[4]:=B3;IkTmp[5]:=B4
   ;IkTmp[6]:=B5;IkTmp[7]:=B6;
 IkQueue(IK_STAT,8);
End;

{ Execute une commande complete }
Procedure IkExec(Len: Integer);
Var C,Y,Mo,D,H,Mi,S,I,A,N: Integer; P: LongInt; Yw,Mow,Dw,Dow: Word;
Begin
 C:=IkBuf[0];
 Case C Of
  $80: If IkBuf[1]=1 Then IkReset;
  $07: IkBtnAct:=IkBuf[1];
  $08: Begin IkMouseMode:=1;IkAccX:=0;IkAccY:=0;End;
  $09: Begin
        IkMouseMode:=2;IkXMax:=IkBuf[1]*256+IkBuf[2];IkYMax:=IkBuf[3]*256+
          IkBuf[4];
        IkAbsX:=Clamp(IkLastX,0,IkXMax);IkAbsY:=Clamp(IkLastY,0,IkYMax);
       End;
  $0A: Begin
    IkMouseMode:=3;IkKeyDx:=Max2(IkBuf[1],1);IkKeyDy:=Max2(IkBuf[2],
    1);IkAccX:=0;IkAccY:=0;End;
  $0B: Begin IkThrX:=Max2(IkBuf[1],1);IkThrY:=Max2(IkBuf[2],1);End;
  $0C: Begin IkScX:=Max2(IkBuf[1],1);IkScY:=Max2(IkBuf[2],1);End;
  $0D: Begin
        IkAbsX:=Clamp(IkLastX Div Max2(IkScX,1),0,IkXMax);
        If IkYBottom Then IkAbsY:=Clamp((399-IkLastY) Div
          Max2(IkScY,1),0,IkYMax)
        Else IkAbsY:=Clamp(IkLastY Div Max2(IkScY,1),0,IkYMax);
        IkSendAbs(0);
       End;
  $0E: Begin
    IkAbsX:=Clamp(IkBuf[2]*256+IkBuf[3],0,IkXMax);IkAbsY:=Clamp(IkBuf[4]*256+
    IkBuf[5],0,IkYMax);End;
  $0F: IkYBottom:=True;
  $10: IkYBottom:=False;
  $11: Begin IkPaused:=False;IkMouseOn:=True;End;
  $12: IkMouseOn:=False;
  $13: IkPaused:=True;
  $14: IkJoyMode:=0;
  $15: IkJoyMode:=1;
  $16: Begin
        { interrogation des manettes : aucune manette n'est branchee }
        IkTmp[0]:=$FD;IkTmp[1]:=0;IkTmp[2]:=0;IkQueue(IK_JOY,3);
       End;
  $17: IkJoyMode:=2;
  $18: IkJoyMode:=3;
  $19: IkJoyMode:=4;
  $1A: IkJoyMode:=5;
  $1B: Begin
        Y:=BcdToI(IkBuf[1]);If Y<80 Then Y:=Y+2000 Else Y:=Y+1900;
        Mo:=BcdToI(IkBuf[2]);D:=BcdToI(IkBuf[3]);H:=BcdToI(IkBuf[4]);Mi:=BcdToI(
          IkBuf[5]);S:=BcdToI(IkBuf[6]);
        If (Mo<1) Or (Mo>12) Then Mo:=1;If (D<1) Or (D>31) Then D:=1;
        IkClockPacked:=(LongInt((Y-1980) Shl 9 Or (Mo Shl 5) Or D) Shl 16) Or
          LongInt((H Shl 11) Or (Mi Shl 5) Or (S Div 2));
        IkClockBase:=MsNow Div 1000;IkClockSet:=True;
       End;
  $1C: Begin
        If IkClockSet Then P:=PackedAdd(IkClockPacked,(MsNow Div
          1000)-IkClockBase) Else P:=HostPacked;
        PackedToSec(P,Y,Mo,D,H,Mi,S);
        IkTmp[0]:=$FC;IkTmp[1]:=IToBcd(Y Mod
          100);IkTmp[2]:=IToBcd(Mo);IkTmp[3]:=IToBcd(D);
        IkTmp[4]:=IToBcd(H);IkTmp[5]:=IToBcd(Mi);IkTmp[6]:=IToBcd(S);
        IkQueue(IK_CLOCK,7);
       End;
  $20: Begin
        A:=IkBuf[1]*256+IkBuf[2];N:=IkBuf[3];
        For I:=0 To N-1 Do
         If (A+I>=$80) And (A+I<=$FF) Then IkRam[A+I-$80]:=IkBuf[4+I];
       End;
  $21: Begin
        A:=IkBuf[1]*256+IkBuf[2];
        FillChar(IkTmp,SizeOf(IkTmp),0);
        IkTmp[0]:=$F6;IkTmp[1]:=$20;
        For I:=0 To 5 Do If (A+I>=$80) And (A+I<=$FF) Then
          IkTmp[2+I]:=IkRam[A+I-$80];
        IkQueue(IK_STAT,8);
       End;
  $22: Begin End;
  { demandes d'etat }
  $87: IkStatus($07,IkBtnAct,0,0,0,0,0);
  $88: IkStatus($08,0,0,0,0,0,0);
  $89: IkStatus($09,IkXMax Shr 8,IkXMax And $FF,IkYMax Shr 8,IkYMax And
    $FF,0,0);
  $8A: IkStatus($0A,IkKeyDx,IkKeyDy,0,0,0,0);
  $8B: IkStatus($0B,IkThrX,IkThrY,0,0,0,0);
  $8C: IkStatus($0C,IkScX,IkScY,0,0,0,0);
  $8F: If IkYBottom Then IkStatus($0F,0,0,0,0,0,0);
  $90: If Not IkYBottom Then IkStatus($10,0,0,0,0,0,0);
  $92: If IkMouseOn Then IkStatus($00,0,0,0,0,0,0) Else
    IkStatus($12,0,0,0,0,0,0);
  $94: IkStatus($14,0,0,0,0,0,0);
  $95: IkStatus($15,0,0,0,0,0,0);
  $99: IkStatus($19,0,0,0,0,0,0);
  $9A: IkStatus($1A,0,0,0,0,0,0);
 End;
End;

{ Longueur d'une commande IKBD d'apres son premier octet }
Function IkCmdLen(C: Integer): Integer;
Begin
 Case C Of
  $80,$07,$17: IkCmdLen:=2;
  $09: IkCmdLen:=5;
  $0A,$0B,$0C,$21,$22: IkCmdLen:=3;
  $0E: IkCmdLen:=6;
  $19,$1B: IkCmdLen:=7;
  $20: IkCmdLen:=4;
 Else IkCmdLen:=1;
 End;
End;

Procedure IkByte(B: Integer);
Var L: Integer;
Begin
 If IkN<128 Then Begin IkBuf[IkN]:=B;Inc(IkN);End;
 L:=IkCmdLen(IkBuf[0]);
 If (IkBuf[0]=$20) And (IkN>=4) Then L:=4+IkBuf[3];
 If IkN>=L Then Begin
  IkExec(L);
  IkN:=0;
 End;
End;

{ Initialise les structures systeme (vecteurs clavier, tables de touches) }
Procedure SysTablesInit;
Var I: Integer;
Begin
 Wr16(STUB_RTS,$4E75);
 KeyTables;
 For I:=0 To 8 Do Wr32(KBDVECS+I*4,STUB_RTS);
 IkReset;IkQN:=0;IkClockSet:=False;
 Wr32(ZERO_WORD,0);
 IorecInit:=False;
 MouseVecUser:=0;
End;


{ ---------------------------------------------------------------------- }
{ Zone systeme TOS : ROM (en-tete OS) et registres materiels (lecture)     }
{ ---------------------------------------------------------------------- }
Const
 OS_ROM = $FC0000;      { TOS 1.0 : ROM en $FC0000 }

Function HwRd8(A: LongInt): Byte;
Var I: Integer; V: Word;
Begin
 HwRd8:=0;
 If (A>=OS_ROM) And (A<OS_ROM+$40) Then Begin
  { en-tete du systeme (os_base) }
  Case A-OS_ROM Of
   0: HwRd8:=$60;  1: HwRd8:=$1E;           { bra.s }
   2: HwRd8:=$01;  3: HwRd8:=$00;           { os_version : TOS 1.00 }
   4: HwRd8:=$00;  5: HwRd8:=$FC;  6: HwRd8:=$00;  7: HwRd8:=$20;   { reseth }
   8: HwRd8:=$00;  9: HwRd8:=$FC;  10: HwRd8:=$00; 11: HwRd8:=$00;  { os_beg }
   12: HwRd8:=$00; 13: HwRd8:=$FF; 14: HwRd8:=$00; 15: HwRd8:=$00;  { os_end }
   20: HwRd8:=$87; 21: HwRd8:=$65; 22: HwRd8:=$43; 23: HwRd8:=$21;  { os_magic }
   24: HwRd8:=$11; 25: HwRd8:=$20; 26: HwRd8:=$19; 27: HwRd8:=$85;  { os_date :
     20/11/1985 }
   29: HwRd8:=$01;                          { os_conf : PAL / Royaume-Uni }
   30: HwRd8:=$0A; 31: HwRd8:=$74;          { os_dosdate }
  End;
  Exit;
 End;
 Case A Of
  $FF8201: HwRd8:=(ScrBase Shr 16) And $FF;       { base video }
  $FF8203: HwRd8:=(ScrBase Shr 8) And $FF;
  $FF8205: HwRd8:=(ScrBase Shr 16) And $FF;       { compteur video }
  $FF8207: HwRd8:=(ScrBase Shr 8) And $FF;
  $FF8209: HwRd8:=ScrBase And $FF;
  $FF820A: HwRd8:=2;                              { synchro 50 Hz }
  $FF8260: HwRd8:=2;                              { resolution : monochrome }
  $FFFA01: HwRd8:=$7F;                            { MFP gpip : bit 7 a 0 =
    moniteur monochrome }
  $FFFC00: HwRd8:=2;                              { ACIA clavier : emetteur
    libre }
  $FFFC02: HwRd8:=0;
 Else
  If (A>=$FF8240) And (A<$FF8260) Then Begin
   I:=(A-$FF8240) Shr 1;V:=Palette68[I];
   If Odd(A) Then HwRd8:=V And $FF Else HwRd8:=V Shr 8;
  End;
 End;
End;


{ Ecriture dans les registres materiels : base video (le debogueur MonST change
  d'ecran) }
Var HwVidHi,HwVidMid: Integer;
 IrqLastC,IrqLastV: LongInt;

Procedure HwWr8(A: LongInt; V: Byte);
Var NB: LongInt;
Begin
 If DosTrace And (A>=$FF8000) And (A<$FF8300) Then Begin
   WriteLn(ConOut,'HWWR ',Hex8(A),' <- ',Hex2(V),' pc=',Hex8(CurOpPC),
   ' scrbase=',Hex8(ScrBase),' drawbase=',Hex8(DrawBase));Flush(ConOut);End;
 If (A=$FF8201) Or (A=$FF8203) Then Begin
  If A=$FF8201 Then HwVidHi:=V Else HwVidMid:=V;
  NB:=(LongInt(HwVidHi) Shl 16) Or (LongInt(HwVidMid) Shl 8);
  If (NB<>ScrBase) And (NB+SCR_BYTES<=MemSize) And (NB>=$1000) Then Begin
   ScrBase:=NB;
   ScrDirtyLo:=0;ScrDirtyHi:=399;
   ScrForceFull:=True;
  End;
 End;
End;

{ Variables systeme de la page basse (TOS 1.0) }
Procedure SysVarsInit;
Begin
 Wr32(0,$0006E000);Wr32(4,OS_ROM+$20);
 Wr32($420,$752019F3);Wr32($43A,$237698AA);Wr32($51A,$5555AAAA);   { memvalid,
   memval2, memval3 }
 Wr32($426,0);Wr32($42A,0);
 Wr32($42E,MemSize);                      { phystop }
 Wr32($432,BP_ADDR);Wr32($436,HitPa);     { _membot, _memtop }
 Wr8($44C,2);                             { sshiftmd : haute resolution }
 Wr32($44E,ScrBase);                      { _v_bas_ad }
 Wr16($446,2);                            { _bootdev : C: }
 Wr16($454,1);                            { nvbls }
 Wr16($4A6,2);                            { _nflops }
 Wr32($4C2,4);                            { _drvbits }
 Wr32($4F2,OS_ROM);                       { _sysbase }
 Wr32($4F6,OS_ROM);                       { _shell_p (approx.) }
 Wr32($4FA,OS_ROM+$40000);                { _end_os }
 Wr32($4FE,OS_ROM);                       { _exec_os }
 Wr16($484,7);                            { conterm }
 Wr32($4BA,0);Wr32($462,0);Wr32($466,0);
 IrqLastC:=MsNow Div 5;IrqLastV:=MsNow Div 20;
 Wr16($0452,$4E73);Wr32(69*4,$0452);Wr32(28*4,$0452);   { Timer C et VBL : RTE
   par defaut (chainage des gestionnaires) }
 HwVidHi:=(ScrBase Shr 16) And $FF;HwVidMid:=(ScrBase Shr 8) And $FF;
End;

{ ---------------------------------------------------------------------- }
{ Interruptions : Timer C (200 Hz, vecteur 69, niveau 6) et VBL (vecteur   }
{ 28, niveau 4), livrees seulement si le programme a installe un          }
{ gestionnaire (Setexc ou ecriture directe) ; MonST s'en sert pour la     }
{ commutation d'ecran temporisee.                                         }
{ ---------------------------------------------------------------------- }
Const IRQ_RET = $0450;
      IRQ_RTE = $0452;     { gestionnaire par defaut : RTE }

{ Choisit l'interruption due : retourne le vecteur (0 si aucune) et son niveau }
Function IrqDue(Var Lvl: Integer): Integer;
Var T: LongInt; Mk: Integer;
Begin
 IrqDue:=0;
 If (Rd32(69*4)=IRQ_RTE) And (Rd32(28*4)=IRQ_RTE) Then Exit;
 Mk:=(SRv Shr 8) And 7;
 T:=MsNow Div 5;
 If (T<>IrqLastC) And (ExcHandler(69)<>0) And (Rd32(69*4)<>IRQ_RTE) Then Begin
  If Mk<6 Then Begin IrqLastC:=T;IrqDue:=69;Lvl:=6;Exit;End;
 End;
 If ((T Div 4)<>IrqLastV) And (ExcHandler(28)<>0) And (Rd32(28*4)<>IRQ_RTE)
   Then Begin
  If Mk<4 Then Begin IrqLastV:=T Div 4;IrqDue:=28;Lvl:=4;End;
 End;
End;

Var IrqCnt: Integer;

Procedure IrqCheck;
Var V,L: Integer;
Begin
 Inc(IrqCnt);
 If (IrqCnt And 7)=0 Then TickSysVars;       { _frclock/_hz_200 evoluent meme
   si le programme boucle sans appel systeme }
 If (StopReason<>STOP_NONE) Or (PendVec>=0) Then Exit;
 L:=0;V:=IrqDue(L);
 If V=0 Then Exit;
 TakeExc(V,PC,ExcHandler(V),False,0,0);
 SetSR((SRv And $F8FF) Or (LongInt(L) Shl 8));
End;

{ Pendant qu'une fonction systeme native attend (Cconin...), le processeur ne
  tourne pas :
  on execute le gestionnaire d'interruption "en passant" puis on restaure
    l'etat }
Procedure IrqNested;
Var V,L,N: Integer; SvRg: Array[0..15] Of LongInt; SvPC,SvSR,SvUSP,SvSSP,SvOp:
  LongInt; SvExc: Boolean; SvStop: Integer;
Begin
 If ((StopReason<>STOP_NONE) And (StopReason<>7)) Or (PendVec>=0) Then Exit;
 L:=0;V:=IrqDue(L);
 If V=0 Then Exit;
 Move(Rg,SvRg,SizeOf(Rg));
 SvPC:=PC;SvSR:=SRv;SvUSP:=USPv;SvSSP:=SSPv;SvOp:=CurOpPC;SvExc:=ExcTaken;SvStop
   :=StopReason;StopReason:=STOP_NONE;
 If DosTrace Then Begin
   WriteLn(ConOut,'IRQ nested start pc=',Hex8(PC),' sr=',Hex4(SRv),' sp=',
   Hex8(Rg[15]),' h=',Hex8(ExcHandler(V)));Flush(ConOut);End;
 TakeExc(V,IRQ_RET,ExcHandler(V),False,0,0);
 SetSR((SRv And $F8FF) Or (LongInt(L) Shl 8));
 N:=0;
 While (PC<>IRQ_RET) And (StopReason=STOP_NONE) And (N<400000) Do Begin
  Step;Inc(N);
  If (N And 255)=0 Then TickSysVars;
 End;
 If StopReason=STOP_NONE Then Begin
  Move(SvRg,Rg,SizeOf(Rg));
  PC:=SvPC;SRv:=SvSR;USPv:=SvUSP;SSPv:=SvSSP;CurOpPC:=SvOp;ExcTaken:=SvExc;
    StopReason:=SvStop;
 End;
 If DosTrace Then Begin
   WriteLn(ConOut,'IRQ nested vec ',V,' steps ',N,' stop=',StopReason,' pc=',
   Hex8(PC));Flush(ConOut);End;
End;


Procedure Bios;
Var Fn: LongInt; R,K,Cnt,Rec: LongInt; Dev,I: Integer; B: Byte; Sec: Integer;
  Bp,Boot: LongInt;
    Bps,Spc,Res,Nfat,Nroot,Tot,Spf,Rdlen,Datrec,Ncl: LongInt; Tmp: Array[0..31]
      Of Byte;
Begin
 Fn:=PW(0);
 R:=0;
 If DosTrace Then Begin
   WriteLn(ConOut,'BIOS ',Fn,' ',Hex8(PL(2)),' ',Hex8(PL(6)));Flush(ConOut);End;
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
        Bps:=Tmp[11]+Tmp[12]*256;Spc:=Tmp[13];Res:=Tmp[14]+
          Tmp[15]*256;Nfat:=Tmp[16];
        Nroot:=Tmp[17]+Tmp[18]*256;Tot:=Tmp[19]+Tmp[20]*256;Spf:=Tmp[22]+
          Tmp[23]*256;
        If (Bps<>512) Or (Spc=0) Or (Nfat=0) Then Begin
         Bps:=512;Spc:=2;Res:=1;Nfat:=2;Nroot:=112;Spf:=5;Tot:=Flp[Dev].Size
           Div 512;
        End;
        Rdlen:=(Nroot*32+511) Div 512;
        Datrec:=Res+Nfat*Spf+Rdlen;
        Ncl:=(Tot-Datrec) Div Spc;
        Wr16(Boot,Bps);Wr16(Boot+2,Spc);Wr16(Boot+4,Bps*Spc);Wr16(Boot+6,Rdlen);
        Wr16(Boot+8,Spf);Wr16(Boot+10,Res+Spf);Wr16(Boot+12,Datrec);Wr16(Boot+
          14,Ncl);
        If Ncl>4086 Then Wr16(Boot+16,1) Else Wr16(Boot+16,0);
        Flp[Dev].Changed:=False;
        R:=Boot;
       End;
      End;
     End;
  8: Begin
      Dev:=PW(2);
      If Dev=1 Then R:=-1 Else If Dev=0 Then R:=-1 Else If Dev=3 Then R:=-1
        Else R:=-1;
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
Var Fn: LongInt; R,A,B,L: LongInt; Hh,Mi,Se,Hs,Y,Mo,D,Dw: Word;
  Dev,Sec,Trk,Sd,Cnt,I: Integer; Lsn: LongInt;
    Tmp: Byte; Old: LongInt; V: LongInt;
Begin
 Fn:=PW(0);
 R:=0;
 If DosTrace Then Begin
   WriteLn(ConOut,'XBIOS ',Fn,' ',Hex8(PL(2)),' ',
   Hex8(PL(6)));Flush(ConOut);End;
 Case Fn Of
  0: Begin
      { Initmous(type,param,vecteur) }
      MouseVecUser:=PL(8);
      If MouseVecUser<>0 Then Wr32(KBDVECS+16,MouseVecUser) Else
        Wr32(KBDVECS+16,STUB_RTS);
      A:=PL(4);
      Case PW(2) Of
       0: IkMouseOn:=False;
       1: Begin
           IkMouseOn:=True;IkPaused:=False;IkMouseMode:=1;IkAccX:=0;IkAccY:=0;
           If A<>0 Then Begin
            IkBtnAct:=Rd8(A+1);IkThrX:=Max2(Rd8(A+2),1);IkThrY:=Max2(Rd8(A+3),
              1);
           End;
          End;
       2: Begin
           IkMouseOn:=True;IkPaused:=False;IkMouseMode:=2;
           If A<>0 Then Begin
            IkBtnAct:=Rd8(A+1);IkXMax:=Rd16(A+2);IkYMax:=Rd16(A+4);
            IkAbsX:=Clamp(Rd16(A+6),0,IkXMax);IkAbsY:=Clamp(Rd16(A+8),0,IkYMax);
           End;
          End;
       4: Begin
           IkMouseOn:=True;IkPaused:=False;IkMouseMode:=3;IkAccX:=0;IkAccY:=0;
           If A<>0 Then Begin
             IkKeyDx:=Max2(Rd8(A+2),1);IkKeyDy:=Max2(Rd8(A+3),1);End;
          End;
      End;
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
       ScrForceFull:=True;
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
        Else If (Sd>=Flp[Dev].Sides) Or (Trk>=Flp[Dev].Tracks) Or (Sec<1) Or
          (Sec>Flp[Dev].Spt) Then R:=E_RNF
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
        RsConfig[1]:=PW(6);RsConfig[2]:=PW(8);RsConfig[3]:=PW(10);RsConfig[4]:=
          PW(12);
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
       { Ikbdws : commandes du clavier intelligent }
       Cnt:=PW(2)+1;A:=PL(4);
       For I:=0 To Cnt-1 Do IkByte(Rd8(A+I));
      End;
  26: Begin MfpEnable:=MfpEnable And Not (LongInt(1) Shl (PW(2) And 31));End;
  27: Begin MfpEnable:=MfpEnable Or (LongInt(1) Shl (PW(2) And 31));End;
  28: Begin
       I:=PW(4);
       If (I And $80)<>0 Then Begin GiRegs[I And 15]:=PW(2) And $FF;R:=GiRegs[I
         And 15];End
       Else R:=GiRegs[I And 15];
      End;
  29: Begin GiRegs[14]:=GiRegs[14] And (PW(2) And $FF);End;
  30: Begin GiRegs[14]:=GiRegs[14] Or (PW(2) And $FF);End;
  31: Begin
       I:=PW(2) And 3;
       XbVec[16+I]:=PL(8);
       Wr32($134+I*4,PL(8));
      End;
  32: Begin
       { Dosound : lance (ou arrete) une sequence YM2149 ; renvoie la position
         courante }
       R:=SndPos;
       If PL(2)=0 Then SoundOff Else If PL(2)<>-1 Then DosoundStart(PL(2));
      End;
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
 MAXDI  = 40;

 { Types d'elements de dialogue }
 DK_LABEL  = 1;
 DK_EDIT   = 2;
 DK_RADIO  = 3;
 DK_BUTTON = 4;
 DK_BOXED  = 5;
 DK_ICON   = 6;
 DK_HLINE  = 7;
 DK_CHECK  = 8;           { case a cocher : Txt = libelle, Sel = 0/1 }
 DK_POPUP  = 9;           { menu local : Txt = 'a|b|c', Sel = choix, W =
   largeur }
 DK_LIST   = 10;          { liste a boutons Add / Remove : Id = numero de
   liste, Max = lignes visibles }
 LST_MAX   = 16;
 LST_ROWH  = 14;

Type
 TDItem = Record
  Kind : Byte;
  X,Y,W : Integer;       { position en cellules }
  Txt  : String[120];
  Val  : String[60];
  Sel  : Integer;
  Id   : Integer;
  Def  : Boolean;
  Max  : Integer;
  Cur  : Integer;        { position du curseur dans un champ (0..Length) }
  Flt  : Byte;           { filtre de saisie : 0 tout, 1 chiffres }
 End;

 TDIArr = Array[1..MAXDI] Of TDItem;

Var
 DI      : TDIArr;
 DN      : Integer;
 DCols,DRows : Integer;
 DFocus  : Integer;
 DTitle  : String;
 LastClickT : LongInt;
 LastClickX,LastClickY : LongInt;
 TickCount  : LongInt;

Procedure DrawAll; Forward;
Function InputDlg(Const Title,Prompt: String; Var S: String; MaxLen: Integer):
  Boolean; Forward;

Procedure DlgReset(Cols,Rows: Integer);
Begin
 DN:=0;DCols:=Cols;DRows:=Rows;DFocus:=0;DTitle:='';
End;

Function DlgAdd(K: Byte; X,Y,W: Integer; Const Txt: String): Integer;
Begin
 If DN<MAXDI Then Begin
  Inc(DN);
  FillChar(DI[DN],SizeOf(TDItem),0);
  DI[DN].Kind:=K;DI[DN].X:=X;DI[DN].Y:=Y;DI[DN].W:=W;DI[DN].Txt:=Copy(Txt,1,
    120);
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
 DI[N].Val:=Val;DI[N].Cur:=Length(Val);
 DlgEdit:=N;
End;

{ champ de saisie dont la longueur maximale (M) depasse la largeur affichee }
Function DlgEditX(X,Y,W,M: Integer; Const Val: String): Integer;
Var N: Integer;
Begin
 N:=DlgEdit(X,Y,W,Val);
 If M>60 Then M:=60;
 DI[N].Max:=M;
 DlgEditX:=N;
End;

Function DlgCheck(X,Y: Integer; Const Txt: String; On: Boolean): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_CHECK,X,Y,(Length(Txt)*8+22) Div 8,Txt);
 DI[N].Sel:=Ord(On);
 DlgCheck:=N;
End;

Function DlgPopup(X,Y,W: Integer; Const Opts: String; Sel: Integer): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_POPUP,X,Y,W,Opts);
 DI[N].Sel:=Sel;
 DlgPopup:=N;
End;

Function DlgRadio(X,Y: Integer; Const Opts: String; Sel: Integer): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_RADIO,X,Y,0,Opts);
 DI[N].Sel:=Sel;
 DlgRadio:=N;
End;

Function DlgButton(X,Y,W: Integer; Const Txt: String; Id: Integer; Def:
  Boolean): Integer;
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

Var
 LstCnt : Array[1..4] Of Integer;
 LstTxt : Array[1..4,1..LST_MAX] Of String[60];
 LstSel : Array[1..4] Of Integer;
 LstTop : Array[1..4] Of Integer;

{ hauteur en cellules d'une liste de R lignes (cadre + boutons) }
Function ListCells(R: Integer): Integer;
Begin
 ListCells:=(R*LST_ROWH+2+6+18+CELL_H-1) Div CELL_H;
End;

Function DlgList(X,Y,W,Rows,Num: Integer): Integer;
Var N: Integer;
Begin
 N:=DlgAdd(DK_LIST,X,Y,W,'');
 DI[N].Max:=Rows;DI[N].Id:=Num;
 DlgList:=N;
End;

Procedure ListClear(Num: Integer);
Begin
 LstCnt[Num]:=0;LstSel[Num]:=0;LstTop[Num]:=1;
End;

Procedure ListAdd(Num: Integer; Const S: String);
Begin
 If (S<>'') And (LstCnt[Num]<LST_MAX) Then Begin
  Inc(LstCnt[Num]);LstTxt[Num,LstCnt[Num]]:=Copy(S,1,60);
 End;
End;

{ elements de la liste, separes par des virgules }
Function ListJoin(Num: Integer): String;
Var I: Integer; R: String;
Begin
 R:='';
 For I:=1 To LstCnt[Num] Do Begin
  If R<>'' Then R:=R+',';
  R:=R+LstTxt[Num,I];
 End;
 ListJoin:=R;
End;

Procedure ListSplit(Num: Integer; Const S: String);
Var P,I: Integer; Cur: String;
Begin
 ListClear(Num);
 Cur:='';
 For I:=1 To Length(S)+1 Do Begin
  If (I>Length(S)) Or (S[I]=',') Then Begin ListAdd(Num,Cur);Cur:='';End
  Else Cur:=Cur+S[I];
 End;
 If P=0 Then Begin End;
End;

{ lettre de la touche Alt-A..Alt-Z (code etendu K = 256+scan) ; #0 sinon }
Function AltLetter(K: Word): Char;
Var I: Integer;
Begin
 AltLetter:=#0;
 If (K<256) Or (K>=512) Then Exit;
 For I:=0 To 25 Do If K=256+AltScan[I] Then AltLetter:=Chr(65+I);
End;

Function IsFocusKind(K: Byte): Boolean;
Begin
 IsFocusKind:=(K=DK_EDIT) Or (K=DK_CHECK) Or (K=DK_POPUP);
End;

{ debut de la partie visible d'un champ dont le curseur est en C }
Function EditViewStart(I: Integer): Integer;
Begin
 If DI[I].Cur>=DI[I].W Then EditViewStart:=DI[I].Cur-DI[I].W+1 Else
   EditViewStart:=0;
End;

Procedure DotRect(X1,Y1,X2,Y2: Integer);
Begin
 SetColor(INK);
 SetLineStyle(UserBitLn,$AAAA,1);
 Rectangle(X1,Y1,X2,Y2);
 SetLineStyle(SolidLn,0,1);
End;

Procedure DlgDraw;
Var X0,Y0,I,K,N,PX,PY,W,OX,VS,X2: Integer; S: String;
    Pt: Array[1..3] Of PointType;
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
             VS:=EditViewStart(I);
             S:=Copy(DI[I].Val,VS+1,DI[I].W);
             PText(PX,PY+4,S);
             SetColor(INK);
             SetLineStyle(UserBitLn,$AAAA,1);
             Line(PX,PY+14,PX+DI[I].W*CELL_W-1,PY+14);
             SetLineStyle(SolidLn,0,1);
             If I=DFocus Then Begin
              OX:=PX+(DI[I].Cur-VS)*8;
              Line(OX,PY+2,OX,PY+13);
             End;
            End;
   DK_CHECK: Begin
              Frame(PX,PY+2,PX+11,PY+13);
              If DI[I].Sel=1 Then Begin
               SetColor(INK);
               Line(PX+2,PY+4,PX+9,PY+11);Line(PX+9,PY+4,PX+2,PY+11);
              End;
              PText(PX+18,PY+4,DI[I].Txt);
              If I=DFocus Then
                DotRect(PX-2,PY,PX+19+Length(DI[I].Txt)*8,PY+CELL_H-1);
             End;
   DK_POPUP: Begin
              X2:=PX+DI[I].W*CELL_W;
              Box(PX+2,PY+2,X2+2,PY+CELL_H+2,INK);
              Box(PX,PY,X2,PY+CELL_H,PAPER);
              Frame(PX,PY,X2,PY+CELL_H);
              PText(PX+6,PY+5,Copy(RadioOptStr(DI[I].Txt,DI[I].Sel),1,
                DI[I].W-2));
              Pt[1].X:=X2-12;Pt[1].Y:=PY+5;Pt[2].X:=X2-4;Pt[2].Y:=PY+
                5;Pt[3].X:=X2-8;Pt[3].Y:=PY+11;
              SetFillStyle(SolidFill,INK);SetColor(INK);
              FillPoly(3,Pt);
              If I=DFocus Then DotRect(PX-3,PY-3,X2+3,PY+CELL_H+3);
             End;
   DK_LIST: Begin
             X2:=PX+DI[I].W*CELL_W;
             N:=DI[I].Id;
             Box(PX,PY,X2,PY+DI[I].Max*LST_ROWH+1,PAPER);
             Frame(PX,PY,X2,PY+DI[I].Max*LST_ROWH+1);
             For K:=1 To DI[I].Max Do Begin
              W:=LstTop[N]+K-1;
              If W<=LstCnt[N] Then Begin
               If W=LstSel[N] Then Begin
                Box(PX+1,PY+1+(K-1)*LST_ROWH,X2-14,PY+K*LST_ROWH,INK);
                WText(PX+4,PY+4+(K-1)*LST_ROWH,Copy(LstTxt[N,W],1,DI[I].W-3));
               End Else
                 PText(PX+4,PY+4+(K-1)*LST_ROWH,Copy(LstTxt[N,W],1,DI[I].W-3));
              End;
             End;
             ArrowBox(X2-13,PY+1,X2-1,PY+13,1);
             ArrowBox(X2-13,PY+DI[I].Max*LST_ROWH-12,X2-1,PY+DI[I].Max*LST_ROWH,
               2);
             GButton(PX,PY+DI[I].Max*LST_ROWH+6,PX+7*CELL_W,PY+
               DI[I].Max*LST_ROWH+22,'Add',False,False);
             GButton(PX+9*CELL_W,PY+DI[I].Max*LST_ROWH+6,PX+17*CELL_W,PY+
               DI[I].Max*LST_ROWH+22,'Remove',False,False);
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
   DK_BUTTON: Begin
               GButton(PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H+2,DI[I].Txt,DI[I].Def,
                 False);
               { lettre d'acces Alt-<lettre> soulignee pour les boutons non par
                 defaut }
               If (Not DI[I].Def) And (DI[I].Txt<>'') Then Begin
                OX:=(PX+PX+DI[I].W*CELL_W+1-TextW(DI[I].Txt)) Div 2;
                SetColor(INK);
                Line(OX,PY+CELL_H-1,OX+7,PY+CELL_H-1);
               End;
              End;
  End;
 End;
 ShowMouse;
End;

Function DlgHit(MX1,MY1: LongInt; Var Sub: Integer): Integer;
Var X0,Y0,I,K,N,PX,PY,W,OX,X2: Integer; S: String;
Begin
 DlgHit:=0;Sub:=0;
 X0:=DlgX0;Y0:=DlgY0;
 For I:=1 To DN Do Begin
  PX:=X0+8+DI[I].X*CELL_W;PY:=Y0+8+DI[I].Y*CELL_H;
  Case DI[I].Kind Of
   DK_EDIT: If InBox(MX1,MY1,PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H) Then DlgHit:=I;
   DK_CHECK: If InBox(MX1,MY1,PX,PY,PX+19+Length(DI[I].Txt)*8,PY+CELL_H) Then
     DlgHit:=I;
   DK_POPUP: If InBox(MX1,MY1,PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H) Then DlgHit:=I;
   DK_BUTTON: If InBox(MX1,MY1,PX,PY,PX+DI[I].W*CELL_W,PY+CELL_H+2) Then
     DlgHit:=I;
   DK_LIST: Begin
             X2:=PX+DI[I].W*CELL_W;
             If InBox(MX1,MY1,X2-13,PY+1,X2-1,PY+13) Then Begin
               DlgHit:=I;Sub:=101;End
             Else If
               InBox(MX1,MY1,X2-13,PY+DI[I].Max*LST_ROWH-12,X2-1,PY+
               DI[I].Max*LST_ROWH) Then Begin DlgHit:=I;Sub:=102;End
             Else If InBox(MX1,MY1,PX,PY+1,X2-14,PY+DI[I].Max*LST_ROWH) Then
               Begin
              DlgHit:=I;Sub:=(MY1-PY-1) Div LST_ROWH+1;
             End Else If
               InBox(MX1,MY1,PX,PY+DI[I].Max*LST_ROWH+6,PX+7*CELL_W,PY+
               DI[I].Max*LST_ROWH+22) Then Begin DlgHit:=I;Sub:=103;End
             Else If
               InBox(MX1,MY1,PX+9*CELL_W,PY+DI[I].Max*LST_ROWH+6,PX+17*CELL_W,
               PY+DI[I].Max*LST_ROWH+22) Then Begin DlgHit:=I;Sub:=104;End;
            End;
   DK_RADIO: Begin
              N:=RadioCount(DI[I].Txt);OX:=PX;
              For K:=1 To N Do Begin
               S:=RadioOptStr(DI[I].Txt,K);
               W:=Length(S)*8+16;
               If InBox(MX1,MY1,OX,PY,OX+W,PY+CELL_H+1) Then Begin
                 DlgHit:=I;Sub:=K;End;
               OX:=OX+W;
              End;
             End;
  End;
 End;
End;

{ Menu local (pop-up) : appui prolonge, relacher dehors = annuler ; un simple
  clic laisse la liste ouverte (second clic = choix) }
Procedure RunPopup(I: Integer);
Var PX,PY,X1,Y1,X2,Y2,N,H,Hi,K: Integer; E: TEvent; Buf: Pointer; Sz: LongInt;
    Done,Sticky,Moved: Boolean; T0: LongInt;
 Procedure Paint;
 Var J,Y: Integer;
 Begin
  HideMouse;
  Box(X1+3,Y1+3,X2+3,Y2+3,INK);
  Box(X1,Y1,X2,Y2,PAPER);
  Frame(X1,Y1,X2,Y2);
  For J:=1 To N Do Begin
   Y:=Y1+2+(J-1)*CELL_H;
   If J=Hi Then Begin
    Box(X1+1,Y,X2-1,Y+CELL_H-1,INK);
    WText(X1+6,Y+4,RadioOptStr(DI[I].Txt,J));
   End Else PText(X1+6,Y+4,RadioOptStr(DI[I].Txt,J));
  End;
  ShowMouse;
 End;
 Function HitItem(X,Y: LongInt): Integer;
 Var R: Integer;
 Begin
  R:=0;
  If InBox(X,Y,X1,Y1+2,X2,Y2-2) Then Begin
   R:=(Y-Y1-2) Div CELL_H+1;
   If R>N Then R:=N;
  End;
  HitItem:=R;
 End;
Begin
 N:=RadioCount(DI[I].Txt);
 PX:=DlgX0+8+DI[I].X*CELL_W;PY:=DlgY0+8+DI[I].Y*CELL_H;
 X1:=PX;X2:=PX+DI[I].W*CELL_W;
 Y1:=PY-(DI[I].Sel-1)*CELL_H-2;
 Y2:=Y1+N*CELL_H+4;
 If Y2>SCR_H-6 Then Begin Y1:=Y1-(Y2-(SCR_H-6));Y2:=SCR_H-6;End;
 If Y1<2 Then Begin Y2:=Y2+(2-Y1);Y1:=2;End;
 Sz:=ImageSize(X1,Y1,X2+4,Y2+4);
 GetMem(Buf,Sz);
 HideMouse;
 GetImage(X1,Y1,X2+4,Y2+4,Buf^);
 ShowMouse;
 Hi:=DI[I].Sel;
 Paint;
 Done:=False;Sticky:=False;Moved:=False;T0:=MsNow;
 Repeat
  PollEvent(E);
  Case E.Kind Of
   4: Begin
       H:=HitItem(E.X,E.Y);
       If H<>Hi Then Begin Hi:=H;Paint;End;
       Moved:=True;
      End;
   3: Begin
       H:=HitItem(E.X,E.Y);
       If (Not Moved) And (Not Sticky) And (MsNow-T0<600) Then Sticky:=True
       Else Begin
        If H>0 Then DI[I].Sel:=H;
        Done:=True;
       End;
      End;
   2: If Sticky Then Begin
       H:=HitItem(E.X,E.Y);
       If H>0 Then DI[I].Sel:=H;
       Done:=True;
      End;
   1: Case E.Key Of
       K_ESC: Done:=True;
       K_UP: Begin If Hi>1 Then Dec(Hi) Else Hi:=N;Paint;End;
       K_DOWN: Begin If (Hi<N) And (Hi>0) Then Inc(Hi) Else Hi:=1;Paint;End;
       K_ENTER: Begin If Hi>0 Then DI[I].Sel:=Hi;Done:=True;End;
      End;
  End;
 Until Done;
 HideMouse;
 PutImage(X1,Y1,Buf^,NormalPut);
 ShowMouse;
 FreeMem(Buf,Sz);
End;

{ Table ASCII : fenetre a la position de la souris ; un clic (ou Entree)
  choisit un
  caractere (les caracteres de controle sont grises) ; False si abandon }
Function AsciiPick(Var Res: Integer): Boolean;
Const CW = 16; CHT = 14;
Var X0,Y0,Sel,H: Integer; E: TEvent; Buf: Pointer; Sz: LongInt; Done,Ok:
  Boolean;
 Function Valid(C: Integer): Boolean;
 Begin
  Valid:=(C>=32) And (C<>127);
 End;
 Procedure Paint;
 Var J,Cx,Cy: Integer;
 Begin
  HideMouse;
  Box(X0-4,Y0-4,X0+16*CW+3,Y0+16*CHT+3,PAPER);
  Frame(X0-4,Y0-4,X0+16*CW+3,Y0+16*CHT+3);
  Frame(X0-3,Y0-3,X0+16*CW+2,Y0+16*CHT+2);
  For J:=0 To 255 Do Begin
   Cx:=X0+(J Mod 16)*CW;Cy:=Y0+(J Div 16)*CHT;
   If J=Sel Then Box(Cx,Cy,Cx+CW-1,Cy+CHT-1,INK);
   If Not Valid(J) Then GreyText(Cx+4,Cy+3,'.')
   Else If J=Sel Then WText(Cx+4,Cy+3,Chr(J)) Else PText(Cx+4,Cy+3,Chr(J));
  End;
  ShowMouse;
 End;
Begin
 Ok:=False;
 X0:=MX-8;Y0:=MY-8;
 If X0>SCR_W-16*CW-8 Then X0:=SCR_W-16*CW-8;
 If Y0>SCR_H-16*CHT-8 Then Y0:=SCR_H-16*CHT-8;
 If X0<8 Then X0:=8;
 If Y0<MENU_H+8 Then Y0:=MENU_H+8;
 Sz:=ImageSize(X0-4,Y0-4,X0+16*CW+3,Y0+16*CHT+3);
 GetMem(Buf,Sz);
 HideMouse;
 GetImage(X0-4,Y0-4,X0+16*CW+3,Y0+16*CHT+3,Buf^);
 ShowMouse;
 Sel:=65;
 Paint;
 Done:=False;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ESC: Done:=True;
    K_LEFT: If Sel>0 Then Begin Dec(Sel);Paint;End;
    K_RIGHT: If Sel<255 Then Begin Inc(Sel);Paint;End;
    K_UP: If Sel>=16 Then Begin Dec(Sel,16);Paint;End;
    K_DOWN: If Sel<240 Then Begin Inc(Sel,16);Paint;End;
    K_ENTER: Begin
              If Valid(Sel) Then Begin Res:=Sel;Ok:=True;End;
              Done:=True;
             End;
   End;
  End Else If E.Kind=4 Then Begin
   If InBox(E.X,E.Y,X0,Y0,X0+16*CW-1,Y0+16*CHT-1) Then Begin
    H:=((E.Y-Y0) Div CHT)*16+(E.X-X0) Div CW;
    If H<>Sel Then Begin Sel:=H;Paint;End;
   End;
  End Else If E.Kind=2 Then Begin
   If InBox(E.X,E.Y,X0,Y0,X0+16*CW-1,Y0+16*CHT-1) Then Begin
    H:=((E.Y-Y0) Div CHT)*16+(E.X-X0) Div CW;
    If Valid(H) Then Begin Res:=H;Ok:=True;Done:=True;End;
   End Else Done:=True;
  End;
 Until Done;
 HideMouse;
 PutImage(X0-4,Y0-4,Buf^,NormalPut);
 ShowMouse;
 FreeMem(Buf,Sz);
 AsciiPick:=Ok;
End;

Var ListClkT : LongInt;
    ListClkI : Integer;

{ clic dans une liste : selection, double-clic = edition, glisser = reordonner,
  Add / Remove, fleches de defilement }
Procedure ListClick(I,Sub: Integer);
Var N,Row,Idx,T,J: Integer; E: TEvent; S,Sv: String; Saved: TDIArr;
    SN,SC,SR,SF: Integer; Done: Boolean; Tmp: String[60];
Begin
 N:=DI[I].Id;
 If Sub=101 Then Begin If LstTop[N]>1 Then Dec(LstTop[N]);DlgDraw;Exit;End;
 If Sub=102 Then Begin If LstTop[N]+DI[I].Max<=LstCnt[N] Then
   Inc(LstTop[N]);DlgDraw;Exit;End;
 If Sub=104 Then Begin
  Idx:=LstSel[N];
  If (Idx>=1) And (Idx<=LstCnt[N]) Then Begin
   For J:=Idx To LstCnt[N]-1 Do LstTxt[N,J]:=LstTxt[N,J+1];
   Dec(LstCnt[N]);
   If LstSel[N]>LstCnt[N] Then LstSel[N]:=LstCnt[N];
   If (LstTop[N]>1) And (LstTop[N]>LstCnt[N]) Then Dec(LstTop[N]);
  End;
  DlgDraw;Exit;
 End;
 If (Sub=103) Or ((Sub>=1) And (Sub<=DI[I].Max) And
   (LstTop[N]+Sub-1<=LstCnt[N]) And (ListClkI=I) And (MsNow-ListClkT<400)) Then
   Begin
  { Add, ou double-clic sur un element : saisie du texte (boite imbriquee) }
  If Sub=103 Then Begin
   If LstCnt[N]>=LST_MAX Then Exit;
   S:='';
  End Else S:=LstTxt[N,LstTop[N]+Sub-1];
  Saved:=DI;SN:=DN;SC:=DCols;SR:=DRows;SF:=DFocus;
  If InputDlg(T3('List item','Element de la liste','Listeneintrag'),'',S,40)
    Then Begin
   DI:=Saved;DN:=SN;DCols:=SC;DRows:=SR;DFocus:=SF;
   If Sub=103 Then Begin
    ListAdd(N,S);
    LstSel[N]:=LstCnt[N];
    If LstSel[N]>=LstTop[N]+DI[I].Max Then LstTop[N]:=LstSel[N]-DI[I].Max+1;
   End Else If S<>'' Then LstTxt[N,LstTop[N]+Sub-1]:=Copy(S,1,60);
  End Else Begin DI:=Saved;DN:=SN;DCols:=SC;DRows:=SR;DFocus:=SF;End;
  ListClkI:=0;
  DlgDraw;Exit;
 End;
 If (Sub>=1) And (Sub<=DI[I].Max) Then Begin
  Idx:=LstTop[N]+Sub-1;
  If Idx<=LstCnt[N] Then Begin
   LstSel[N]:=Idx;
   ListClkT:=MsNow;ListClkI:=I;
   DlgDraw;
   { glisser-deposer : l'element suit la souris, relache = nouvelle place }
   Done:=False;Row:=Sub;
   Repeat
    PollEvent(E);
    If E.Kind=4 Then Begin
     T:=(E.Y-(DlgY0+8+DI[I].Y*CELL_H)-1) Div LST_ROWH+1;
     If T<1 Then T:=1;
     If T>DI[I].Max Then T:=DI[I].Max;
     If T<>Row Then Begin
      J:=LstTop[N]+T-1;
      If J<=LstCnt[N] Then Begin
       Tmp:=LstTxt[N,LstSel[N]];
       If J<LstSel[N] Then Begin
        { vers le haut }
        Idx:=LstSel[N];
        While Idx>J Do Begin LstTxt[N,Idx]:=LstTxt[N,Idx-1];Dec(Idx);End;
       End Else Begin
        Idx:=LstSel[N];
        While Idx<J Do Begin LstTxt[N,Idx]:=LstTxt[N,Idx+1];Inc(Idx);End;
       End;
       LstTxt[N,J]:=Tmp;LstSel[N]:=J;Row:=T;
       ListClkI:=0;
       DlgDraw;
      End;
     End;
    End Else If E.Kind=3 Then Done:=True;
   Until Done;
  End;
 End;
End;

Procedure DlgFocusMove(Dir: Integer);
Var F: Integer;
Begin
 If DFocus=0 Then Exit;
 F:=DFocus;
 Repeat
  F:=F+Dir;
  If F>DN Then F:=1;
  If F<1 Then F:=DN;
 Until IsFocusKind(DI[F].Kind) Or (F=DFocus);
 DFocus:=F;
End;

{ Boucle d'un dialogue : retourne l'Id du bouton choisi (0 si Echap) }
Function DlgRun: Integer;
Var E: TEvent; Done: Boolean; Res,I,Sub,F,DefId,K,VS,P,AC: Integer;
    L: Char; S: String;
Begin
 DefId:=0;
 For I:=1 To DN Do
  If (DI[I].Kind=DK_BUTTON) And DI[I].Def Then DefId:=DI[I].Id;
 DFocus:=0;
 For I:=DN Downto 1 Do If IsFocusKind(DI[I].Kind) Then DFocus:=I;
 For I:=DN Downto 1 Do If DI[I].Kind=DK_EDIT Then DFocus:=I;
 DlgDraw;
 Done:=False;Res:=0;
 Repeat
  PollEvent(E);
  If E.Kind=1 Then Begin
   K:=E.Key;
   If K=K_ENTER Then Begin Res:=DefId;Done:=True;End
   Else If K=K_ESC Then Begin
    { Echap vide le champ en cours ; sur un champ vide ou sans champ : annule }
    If (DFocus>0) And (DI[DFocus].Kind=DK_EDIT) And (DI[DFocus].Val<>'') Then
      Begin
     DI[DFocus].Val:='';DI[DFocus].Cur:=0;DlgDraw;
    End Else Begin Res:=0;Done:=True;End;
   End
   Else If ((K=K_TAB) And ((KeyMods And KM_CTRL)=0)) Or (K=K_DOWN) Then Begin
     DlgFocusMove(1);DlgDraw;End
   Else If (K=K_STAB) Or (K=K_UP) Then Begin DlgFocusMove(-1);DlgDraw;End
   Else If DFocus>0 Then Begin
    F:=DFocus;
    If DI[F].Kind=DK_EDIT Then Begin
     S:=DI[F].Val;P:=DI[F].Cur;
     { Maj-Inser : table ASCII ; Ctrl-I : tabulation }
     If (K=K_INS) And ((KeyMods And KM_SHIFT)<>0) Then Begin
      If AsciiPick(AC) Then Begin
       If (Length(S)<DI[F].Max) And (DI[F].Flt<>1) Then Begin
         Insert(Chr(AC),S,P+1);Inc(P);End;
      End;
      DI[F].Val:=S;DI[F].Cur:=P;DlgDraw;
     End Else If (K=9) And ((KeyMods And KM_CTRL)<>0) Then Begin
      If (Length(S)<DI[F].Max) And (DI[F].Flt<>1) Then Begin
        Insert(#9,S,P+1);Inc(P);End;
      DI[F].Val:=S;DI[F].Cur:=P;DlgDraw;
     End Else
     If (K=K_LEFT) And (P>0) Then Dec(P)
     Else If (K=K_RIGHT) And (P<Length(S)) Then Inc(P)
     Else If K=K_HOME Then P:=0
     Else If K=K_END Then P:=Length(S)
     Else If (K=K_BKSP) And (P>0) Then Begin Delete(S,P,1);Dec(P);End
     Else If (K=K_DEL) And (P<Length(S)) Then Delete(S,P+1,1)
     Else If (K>=32) And (K<=255) And (Length(S)<DI[F].Max) Then Begin
      If (DI[F].Flt<>1) Or ((K>=48) And (K<=57)) Then Begin
       Insert(Chr(K),S,P+1);Inc(P);
      End;
     End;
     DI[F].Val:=S;DI[F].Cur:=P;
     DlgDraw;
    End Else If DI[F].Kind=DK_CHECK Then Begin
     If K=32 Then Begin DI[F].Sel:=1-DI[F].Sel;DlgDraw;End;
    End Else If DI[F].Kind=DK_POPUP Then Begin
     P:=RadioCount(DI[F].Txt);
     If (K=32) Or (K=K_RIGHT) Then Begin
      Inc(DI[F].Sel);If DI[F].Sel>P Then DI[F].Sel:=1;DlgDraw;
     End Else If K=K_LEFT Then Begin
      Dec(DI[F].Sel);If DI[F].Sel<1 Then DI[F].Sel:=P;DlgDraw;
     End;
    End;
   End;
   { Alt-<premiere lettre> : bouton non par defaut }
   L:=AltLetter(K);
   If L<>#0 Then
    For I:=1 To DN Do
     If Not Done Then
      If (DI[I].Kind=DK_BUTTON) And (Not DI[I].Def) And (DI[I].Txt<>'') Then
       If UpCase(DI[I].Txt[1])=L Then Begin Res:=DI[I].Id;Done:=True;End;
  End Else If E.Kind=2 Then Begin
   I:=DlgHit(E.X,E.Y,Sub);
   If I>0 Then Begin
    Case DI[I].Kind Of
     DK_EDIT: Begin
               DFocus:=I;
               VS:=EditViewStart(I);
               P:=VS+(E.X-(DlgX0+8+DI[I].X*CELL_W)+4) Div 8;
               If P>Length(DI[I].Val) Then P:=Length(DI[I].Val);
               If P<0 Then P:=0;
               DI[I].Cur:=P;
               DlgDraw;
              End;
     DK_CHECK: Begin DFocus:=I;DI[I].Sel:=1-DI[I].Sel;DlgDraw;End;
     DK_POPUP: Begin DFocus:=I;DlgDraw;RunPopup(I);DlgDraw;End;
     DK_RADIO: Begin DI[I].Sel:=Sub;DlgDraw;End;
     DK_LIST: ListClick(I,Sub);
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
Var Lines: Array[1..8] Of String; NL,I,W,NB,BW,X,TxtX: Integer; S,B: String;
  P,K: Integer;
    BT: Array[1..4] Of String[20]; IdMap: Array[1..4] Of Integer; R: Integer;
Begin
 NL:=0;S:=Txt;
 While (S<>'') And (NL<8) Do Begin
  P:=Pos('|',S);Inc(NL);
  If P=0 Then Begin Lines[NL]:=S;S:='';End Else Begin
    Lines[NL]:=Copy(S,1,P-1);Delete(S,1,P);End;
 End;
 NB:=0;S:=Btns;
 While (S<>'') And (NB<4) Do Begin
  P:=Pos('|',S);Inc(NB);
  If P=0 Then Begin BT[NB]:=S;S:='';End Else Begin
    BT[NB]:=Copy(S,1,P-1);Delete(S,1,P);End;
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
  For I:=1 To NB Do If (BT[I]=T3('Cancel','Annuler','Abbruch')) Or
    (BT[I]='Cancel') Then R:=I;
  If R=0 Then R:=NB;
 End;
 AlertBox:=R;
End;

Procedure Alert1(Icon: Integer; Const Txt: String);
Var R: Integer;
Begin
 R:=AlertBox(Icon,Txt,'OK',1);
End;

Function InputDlgF(Const Title,Prompt: String; Var S: String; MaxLen: Integer;
  Flt: Byte): Boolean;
Var W,R,E: Integer;
Begin
 W:=Length(Prompt)+MaxLen+4;
 If W<Length(Title)+6 Then W:=Length(Title)+6;
 DlgReset(W,4);
 DlgLabel(1,0,Title);
 DlgLabel(1,1,Prompt);
 E:=DlgEdit(2+Length(Prompt),1,MaxLen,S);
 DI[E].Flt:=Flt;
 DlgButton(W-24,2,10,'OK',1,True);
 DlgButton(W-12,2,10,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R=1 Then Begin S:=DI[E].Val;InputDlgF:=True;End Else InputDlgF:=False;
End;

Function InputDlg(Const Title,Prompt: String; Var S: String; MaxLen: Integer):
  Boolean;
Begin
 InputDlg:=InputDlgF(Title,Prompt,S,MaxLen,0);
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
 FSDirMode : Boolean;      { selection d'un repertoire (Change Directory) }

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
  If ((SR.Attr And Directory)<>0) And (SR.Name<>'.') And (SR.Name<>'..') Then
    Begin
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
  While (J>=1) And (Upper(FSList[J])>Upper(T)) And (FSList[J]<>DirSep+'..') Do
    Begin
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
    Done,Ok,Redraw: Boolean; P: Integer; K: LongInt; FullS: String; DblT:
      LongInt;
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
  PText(X0+16,Y0+30,T3('Directory: ','Repertoire : ','Verzeichnis: ')+Copy(Dir+
    Msk,1,48));
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
  Else Begin
    SetColor(INK);Line(LX+88+Length(S)*8,LY+FS_ROWS*16+23,LX+88+24*8,LY+
    FS_ROWS*16+23);End;
  GButton(LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56,'OK',True,False);
  GButton(LX+16+100,LY+FS_ROWS*16+36,LX+16+100+80,LY+FS_ROWS*16+56,T3('Cancel',
    'Annuler','Abbruch'),False,False);
  ShowMouse;
 End;
 Procedure Accept;
 Begin
  If FSDirMode Then Begin
   If (Sel<>'') And (Sel[1]=DirSep) And (Sel<>DirSep+'..') Then
     Path:=Dir+Copy(Sel,2,80)+DirSep
   Else Path:=Dir;
   Ok:=True;Done:=True;
  End Else If Sel<>'' Then Begin
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
    K_ESC,256+46: Done:=True;
    K_UP: If Cur>1 Then Begin Dec(Cur);Sel:=FSList[Cur];Redraw:=True;End
          Else If Cur=0 Then If FSN>0 Then Begin
            Cur:=1;Sel:=FSList[1];Redraw:=True;End;
    K_DOWN: If Cur<FSN Then Begin Inc(Cur);Sel:=FSList[Cur];Redraw:=True;End;
    K_PGUP: Begin Cur:=Max2(1,Cur-FS_ROWS);If FSN>0 Then
      Sel:=FSList[Cur];Redraw:=True;End;
    K_PGDN: Begin Cur:=Min2(FSN,Cur+FS_ROWS);If FSN>0 Then
      Sel:=FSList[Cur];Redraw:=True;End;
    K_BKSP: If Length(Sel)>0 Then Begin Dec(Sel[0]);Cur:=0;Redraw:=True;End;
    32..255: If E.Key<>K_DEL Then Begin
              If Length(Sel)<40 Then Begin
                Sel:=Sel+Chr(E.Key);Cur:=0;Redraw:=True;End;
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
   End Else If InBox(E.X,E.Y,LX+LW+8,LY+FS_ROWS*16-14,LX+LW+24,LY+FS_ROWS*16+2)
     Then Begin
    If Top+FS_ROWS<=FSN Then Inc(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY+17,LX+LW+24,LY+FS_ROWS*16-15) Then Begin
    If E.Y<LY+FS_ROWS*8 Then Top:=Max2(1,Top-FS_ROWS) Else
      Top:=Max2(1,Min2(FSN-FS_ROWS+1,Top+FS_ROWS));
    Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56)
     Then Accept
   Else If InBox(E.X,E.Y,LX+16+100,LY+FS_ROWS*16+36,LX+16+180,LY+FS_ROWS*16+56)
     Then Done:=True;
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
 NMENU = 8;
 MTitle : Array[1..NMENU] Of String[40] =
  ('Desk~Bureau~Desk','File~Fichier~Datei','Edit~Edition~Bearbeiten',
    'Block~Bloc~Block',
   'Search~Recherche~Suchen','Options~Options~Optionen',
     'Tools~Outils~Werkzeuge',
   'Program~Programme~Programm');

 { Identifiants de commandes : les menus, les touches et les sous-menus s'y
   referent (DoCmd, p13). 0 = separateur. }
 CM_NONE    = 0;
 CM_ABOUT   = 1;  CM_HELP    = 2;  CM_MEMORY  = 3;
 CM_NEW     = 10; CM_LOAD    = 11; CM_INSERT  = 12; CM_REVERT  = 13; CM_CLOSE
   = 14;
 CM_SAVEAS  = 15; CM_SAVE    = 16; CM_DELFILE = 17; CM_CHDIR   = 18; CM_QUIT
   = 19;
 CM_CUT     = 20; CM_COPY    = 21; CM_PASTE   = 22; CM_SELALL  = 23; CM_ASCII
   = 24;
 CM_TOP     = 25; CM_BOTTOM  = 26; CM_GOTO    = 27; CM_ARRANGE = 28; CM_CYCLE
   = 29;
 CM_WINDOW  = 47;
 CM_BSTART  = 30; CM_BEND    = 31; CM_BSAVE   = 32; CM_BCOPY   = 33; CM_BDEL
   = 34;
 CM_BREM    = 35; CM_BPASTE  = 36; CM_BPRINT  = 37;
 CM_FIND    = 40; CM_FNEXT   = 41; CM_FPREV   = 42; CM_REPL    = 43; CM_REPLALL
   = 44;
 CM_SETBM   = 45; CM_GOTOBM  = 46;
 CM_PREFS   = 50; CM_ASMOPT  = 51; CM_RUNOPT  = 52; CM_SAVEPREF= 53;
   CM_LOADPREF= 54;
 CM_FONTS   = 55; CM_ENVIRON = 56; CM_RESIDENT= 57; CM_ASMLST  = 63; CM_ASMOPTS
   = 64;
 CM_ASMOPTI = 65; CM_DBGOPT  = 66; CM_RUNSHELL= 61; CM_TOOLCFG = 62;
 CM_TOOL1   = 100;           { 100..119 : outils 1 a 20 }
 CM_RUNOTHER= 60;
 CM_ASM     = 70; CM_CHECK   = 71; CM_RUN     = 72; CM_DEBUG   = 73; CM_MON
   = 74;
 CM_RUNDIR  = 75; CM_GEM     = 76; CM_PREVERR = 77; CM_JUMPERR = 78;
 CM_NEXTERR = 79; CM_OUTSYM  = 80;

Var
 PickMods        : Byte;          { modificateurs au moment ou une commande de
   menu est choisie }
 MenuOpen,MenuHi : Integer;
 SubOpen,SubHi   : Integer;       { sous-menu ouvert (identifiant) et element
   en surbrillance }
 OptRunGem       : Boolean;
 RunDirMode      : Integer;       { 1 repertoire courant, 2 repertoire de la
   fenetre du haut }

Function CmdEnabled(Id: Integer): Boolean; Forward;
{ libelle de l'outil N dans le menu Tools (defini dans p13) }
Function ToolMenuLabel(N: Integer): String; Forward;

Function SubEnabled(Id,J: Integer): Boolean; Forward;
Procedure DoSub(Id,J: Integer); Forward;

Function MCount(M: Integer): Integer;
Begin
 Case M Of
  1: MCount:=4;
  2: MCount:=13;
  3: MCount:=13;
  4: MCount:=8;
  5: MCount:=8;
  6: MCount:=14;
  7: MCount:=24;
  8: MCount:=13;
 Else MCount:=0;
 End;
End;

{ commande de l'element I du menu M (CM_NONE = separateur) }
Function MItem(M,I: Integer): Integer;
Begin
 MItem:=CM_NONE;
 Case M Of
  1: Case I Of 1: MItem:=CM_ABOUT; 3: MItem:=CM_HELP; 4: MItem:=CM_MEMORY; End;
  2: Case I Of
      1: MItem:=CM_NEW; 2: MItem:=CM_LOAD; 3: MItem:=CM_INSERT; 4:
        MItem:=CM_REVERT;
      5: MItem:=CM_CLOSE; 7: MItem:=CM_SAVEAS; 8: MItem:=CM_SAVE;
      10: MItem:=CM_DELFILE; 11: MItem:=CM_CHDIR; 13: MItem:=CM_QUIT;
     End;
  3: Case I Of
      1: MItem:=CM_CUT; 2: MItem:=CM_COPY; 3: MItem:=CM_PASTE; 4:
        MItem:=CM_SELALL;
      5: MItem:=CM_ASCII; 7: MItem:=CM_TOP; 8: MItem:=CM_BOTTOM; 9:
        MItem:=CM_GOTO;
      11: MItem:=CM_ARRANGE; 12: MItem:=CM_CYCLE; 13: MItem:=CM_WINDOW;
     End;
  4: MItem:=CM_BSTART+I-1;
  5: Case I Of
      1: MItem:=CM_FIND; 2: MItem:=CM_FNEXT; 3: MItem:=CM_FPREV; 4:
        MItem:=CM_REPL;
      5: MItem:=CM_REPLALL; 7: MItem:=CM_SETBM; 8: MItem:=CM_GOTOBM;
     End;
  6: Case I Of
      1: MItem:=CM_ASMOPT; 2: MItem:=CM_ASMLST; 3: MItem:=CM_ASMOPTS; 4:
        MItem:=CM_ASMOPTI;
      5: MItem:=CM_DBGOPT; 7: MItem:=CM_PREFS; 8: MItem:=CM_RESIDENT; 9:
        MItem:=CM_FONTS;
      10: MItem:=CM_ENVIRON; 11: MItem:=CM_RUNOPT; 13: MItem:=CM_SAVEPREF; 14:
        MItem:=CM_LOADPREF;
     End;
  7: If I<=20 Then MItem:=CM_TOOL1+I-1
     Else Case I Of 22: MItem:=CM_RUNOTHER; 23: MItem:=CM_RUNSHELL; 24:
       MItem:=CM_TOOLCFG; End;
  8: Case I Of
      1: MItem:=CM_ASM; 2: MItem:=CM_CHECK; 3: MItem:=CM_OUTSYM; 5:
        MItem:=CM_RUN; 6: MItem:=CM_DEBUG;
      7: MItem:=CM_MON; 9: MItem:=CM_RUNDIR; 10: MItem:=CM_GEM;
      12: MItem:=CM_PREVERR; 13: MItem:=CM_JUMPERR;
     End;
 End;
End;

{ Libelle d'une commande : "texte|raccourci" }
Function CmdLabel(Id: Integer): String;
Begin
 CmdLabel:='';
 Case Id Of
  CM_ABOUT: CmdLabel:=T3('About ','A propos de ','Ueber ')+'Devpac...';
  CM_HELP: CmdLabel:=T3('Help...|Alt-H','Aide...|Alt-H','Hilfe...|Alt-H');
  CM_MEMORY: CmdLabel:=T3('Memory...','Memoire...','Speicher...');
  CM_NEW: CmdLabel:=T3('New','Nouveau','Neu');
  CM_LOAD: CmdLabel:=T3('Load...|Alt-L','Charger...|Alt-L','Laden...|Alt-L');
  CM_INSERT:
    CmdLabel:=T3('Insert File...|Alt-I','Inserer fichier...|Alt-I',
    'Datei einfuegen...|Alt-I');
  CM_REVERT: CmdLabel:=T3('Revert','Recharger','Zuruecksetzen');
  CM_CLOSE: CmdLabel:=T3('Close|^W','Fermer|^W','Schliessen|^W');
  CM_SAVEAS:
    CmdLabel:=T3('Save As...|Alt-S','Sauver sous...|Alt-S',
    'Sichern als...|Alt-S');
  CM_SAVE: CmdLabel:=T3('Save|F8','Sauver|F8','Sichern|F8');
  CM_DELFILE:
    CmdLabel:=T3('Delete File...','Effacer fichier...','Datei loeschen...');
  CM_CHDIR:
    CmdLabel:=T3('Change Directory...','Changer de repertoire...',
    'Verzeichnis wechseln...');
  CM_QUIT: CmdLabel:=T3('Quit|Alt-Q','Quitter|Alt-Q','Ende|Alt-Q');
  CM_CUT:
    CmdLabel:=T3('Cut|Shift-F5','Couper|Shift-F5','Ausschneiden|Shift-F5');
  CM_COPY: CmdLabel:=T3('Copy|Shift-F4','Copier|Shift-F4','Kopieren|Shift-F4');
  CM_PASTE: CmdLabel:=T3('Paste|F5','Coller|F5','Einfuegen|F5');
  CM_SELALL: CmdLabel:=T3('Select All','Tout selectionner','Alles auswaehlen');
  CM_ASCII:
    CmdLabel:=T3('ASCII Table...|Alt-C','Table ASCII...|Alt-C',
    'ASCII-Tabelle...|Alt-C');
  CM_TOP:
    CmdLabel:=T3('Goto Top|Alt-T','Aller en haut|Alt-T','Zum Anfang|Alt-T');
  CM_BOTTOM:
    CmdLabel:=T3('Goto Bottom|Alt-B','Aller en bas|Alt-B','Zum Ende|Alt-B');
  CM_GOTO: CmdLabel:=T3('Goto...|Alt-G','Aller a...|Alt-G','Gehe zu...|Alt-G');
  CM_ARRANGE:
    CmdLabel:=T3('Arrange Windows','Disposer les fenetres','Fenster anordnen');
  CM_CYCLE:
    CmdLabel:=T3('Cycle Windows|^V','Fenetre suivante|^V',
    'Naechstes Fenster|^V');
  CM_WINDOW: CmdLabel:=T3('Window','Fenetre','Fenster');
  CM_BSTART: CmdLabel:=T3('Block Start|F1','Debut de bloc|F1','Blockanfang|F1');
  CM_BEND: CmdLabel:=T3('Block End|F2','Fin de bloc|F2','Blockende|F2');
  CM_BSAVE:
    CmdLabel:=T3('Save Block...|F3','Sauver le bloc...|F3',
    'Block sichern...|F3');
  CM_BCOPY:
    CmdLabel:=T3('Copy Block|F4','Copier le bloc|F4','Block kopieren|F4');
  CM_BDEL:
    CmdLabel:=T3('Delete Block|Shift-F5','Effacer le bloc|Shift-F5',
    'Block loeschen|Shift-F5');
  CM_BREM:
    CmdLabel:=T3('Remember Block|Shift-F4','Memoriser le bloc|Shift-F4',
    'Block merken|Shift-F4');
  CM_BPASTE:
    CmdLabel:=T3('Paste Block|F5','Coller le bloc|F5','Block einfuegen|F5');
  CM_BPRINT:
    CmdLabel:=T3('Print Block|Alt-W','Imprimer le bloc|Alt-W',
    'Block drucken|Alt-W');
  CM_FIND: CmdLabel:=T3('Find...|Alt-F','Chercher...|Alt-F','Suchen...|Alt-F');
  CM_FNEXT:
    CmdLabel:=T3('Find Next|Alt-N','Suivant|Alt-N','Weitersuchen|Alt-N');
  CM_FPREV:
    CmdLabel:=T3('Find Previous|Alt-P','Precedent|Alt-P','Rueckwaerts|Alt-P');
  CM_REPL: CmdLabel:=T3('Replace|Alt-R','Remplacer|Alt-R','Ersetzen|Alt-R');
  CM_REPLALL: CmdLabel:=T3('Replace All','Tout remplacer','Alle ersetzen');
  CM_SETBM: CmdLabel:=T3('Set Bookmark','Poser un signet','Lesezeichen setzen');
  CM_GOTOBM:
    CmdLabel:=T3('Goto Bookmark','Aller au signet','Gehe zu Lesezeichen');
  CM_PREFS: CmdLabel:=T3('Preferences...','Preferences...','Einstellungen...');
  CM_ASMOPT: CmdLabel:=T3('Control...','Controle...','Steuerung...');
  CM_ASMLST: CmdLabel:=T3('Listing...','Listing...','Listing...');
  CM_ASMOPTS: CmdLabel:=T3('Options...','Options...','Optionen...');
  CM_ASMOPTI:
    CmdLabel:=T3('Optimisations...','Optimisations...','Optimierungen...');
  CM_DBGOPT: CmdLabel:=T3('Debugger...','Debogueur...','Debugger...');
  CM_RESIDENT: CmdLabel:=T3('Resident...','Residents...','Resident...');
  CM_ENVIRON: CmdLabel:=T3('Environment...','Environnement...','Umgebung...');
  CM_RUNSHELL:
    CmdLabel:=T3('Run with Shell|Sh-Alt-0','Executer via shell|Sh-Alt-0',
    'Mit Shell starten|Sh-Alt-0');
  CM_TOOLCFG:
    CmdLabel:=T3('Configure tools...','Configurer les outils...',
    'Werkzeuge einrichten...');
  CM_RUNOPT:
    CmdLabel:=T3('Run options...','Options d''execution...',
    'Start-Optionen...');
  CM_FONTS: CmdLabel:=T3('Fonts...|^G','Polices...|^G','Schriften...|^G');
  CM_SAVEPREF:
    CmdLabel:=T3('Save preferences','Sauver preferences',
    'Einstellungen sichern');
  CM_LOADPREF:
    CmdLabel:=T3('Load preferences','Charger preferences',
    'Einstellungen laden');
  CM_TOOL1..CM_TOOL1+19: CmdLabel:=ToolMenuLabel(Id-CM_TOOL1+1);
  CM_RUNOTHER:
    CmdLabel:=T3('Run Other...|Alt-0','Executer autre...|Alt-0',
    'Anderes starten...|Alt-0');
  CM_ASM: CmdLabel:=T3('Assemble|Alt-A','Assembler|Alt-A','Assemblieren|Alt-A');
  CM_OUTSYM:
    CmdLabel:=T3('Output Symbols...','Sortie des symboles...',
    'Symbole ausgeben...');
  CM_CHECK: CmdLabel:=T3('Check|Alt-Y','Verifier|Alt-Y','Pruefen|Alt-Y');
  CM_RUN: CmdLabel:=T3('Run|Alt-X','Executer|Alt-X','Starten|Alt-X');
  CM_DEBUG: CmdLabel:=T3('Debug|Alt-D','Deboguer|Alt-D','Debuggen|Alt-D');
  CM_MON: CmdLabel:=MonName+'|Alt-M';
  CM_RUNDIR: CmdLabel:=T3('Directory','Repertoire','Verzeichnis');
  CM_GEM: If AmigaMode Then
    CmdLabel:=T3('Run as CLI|Alt-K','Executer en CLI|Alt-K',
    'Als CLI starten|Alt-K')
          Else
            CmdLabel:=T3('Run with GEM|Alt-K','Executer avec GEM|Alt-K',
            'Mit GEM starten|Alt-K');
  CM_PREVERR:
    CmdLabel:=T3('Previous error|^J','Erreur precedente|^J',
    'Voriger Fehler|^J');
  CM_JUMPERR:
    CmdLabel:=T3('Jump to Error|Alt-J','Aller a l''erreur|Alt-J',
    'Zum Fehler|Alt-J');
 End;
End;

{ fenetres de l'editeur (definies dans p13) }
Function WinUsedN(J: Integer): Boolean; Forward;
Function WinTitleN(J: Integer): String; Forward;
Function WinIsFront(J: Integer): Boolean; Forward;
Function LayoutIsKept(J: Integer): Boolean; Forward;

Function SubCount(Id: Integer): Integer;
Begin
 Case Id Of
  CM_SETBM,CM_GOTOBM: SubCount:=8;
  CM_RUNDIR: SubCount:=2;
  CM_ARRANGE: SubCount:=5;
  CM_WINDOW: SubCount:=7;
 Else SubCount:=0;
 End;
End;

Function SubLabel(Id,J: Integer): String;
Begin
 SubLabel:='';
 Case Id Of
  CM_SETBM: SubLabel:=T3('Set ','Poser ','Setze ')+IntStr(J)+'|Alt-F'+IntStr(J);
  CM_GOTOBM:
    SubLabel:=T3('Goto ','Aller ','Gehe zu ')+IntStr(J)+'|Ctrl-F'+IntStr(J);
  CM_RUNDIR: If J=1 Then SubLabel:=T3('Current','Courant','Aktuell')
             Else
               SubLabel:=T3('Top Window','Fenetre du haut','Oberstes Fenster');
  CM_ARRANGE: Case J Of
               1: SubLabel:=T3('Overlap','Cascade','Ueberlappen');
               2: SubLabel:=T3('Tile','Mosaique','Kacheln');
               3: SubLabel:=T3('Vertical','Verticale','Vertikal');
               4: SubLabel:='-';
               5: SubLabel:=T3('Keep layout','Disposition permanente',
                 'Anordnung beibehalten');
              End;
  CM_WINDOW: SubLabel:=IntStr(J)+' '+Copy(WinTitleN(J),1,22)+'|Alt-'+IntStr(J);
 End;
End;

Function SubChecked(Id,J: Integer): Boolean;
Begin
 SubChecked:=((Id=CM_RUNDIR) And (J=RunDirMode)) Or ((Id=CM_WINDOW) And
   WinIsFront(J)) Or
  ((Id=CM_ARRANGE) And LayoutIsKept(J));
End;

{ Panneaux : P = 1..NMENU menu principal ; P = 100+commande = sous-menu }
Function PCount(P: Integer): Integer;
Begin
 If P<100 Then PCount:=MCount(P) Else PCount:=SubCount(P-100);
End;

Function PLabel(P,I: Integer): String;
Begin
 If P<100 Then Begin
  If MItem(P,I)=CM_NONE Then PLabel:='-' Else PLabel:=CmdLabel(MItem(P,I));
 End Else PLabel:=SubLabel(P-100,I);
End;

Function PSubOf(P,I: Integer): Integer;
Var Id: Integer;
Begin
 PSubOf:=0;
 If P<100 Then Begin
  Id:=MItem(P,I);
  If (Id=CM_SETBM) Or (Id=CM_GOTOBM) Or (Id=CM_RUNDIR) Or (Id=CM_ARRANGE) Or
    (Id=CM_WINDOW) Then PSubOf:=Id;
 End;
End;

Function MEnabled(M,I: Integer): Boolean; Forward;

Function PEnabled(P,I: Integer): Boolean;
Begin
 If P<100 Then PEnabled:=MEnabled(P,I) Else PEnabled:=SubEnabled(P-100,I);
End;

Function PChecked(P,I: Integer): Boolean;
Begin
 If P<100 Then PChecked:=(MItem(P,I)=CM_GEM) And OptRunGem
 Else PChecked:=SubChecked(P-100,I);
End;

Function PIsSep(P,I: Integer): Boolean;
Begin
 PIsSep:=PLabel(P,I)='-';
End;

Function MT(I: Integer): String;
Begin
 MT:=Part3(MTitle[I],Lang);
End;

Function MenuX(M: Integer): Integer;
Var I,X: Integer;
Begin
 X:=16;
 For I:=1 To M-1 Do X:=X+Length(MT(I))*8+16;
 MenuX:=X;
End;

Function PItemH(P,I: Integer): Integer;
Begin
 If PIsSep(P,I) Then PItemH:=8 Else PItemH:=16;
End;

Function PItemY(P,I,Y1: Integer): Integer;
Var K,Y: Integer;
Begin
 Y:=Y1+2;
 For K:=1 To I-1 Do Y:=Y+PItemH(P,K);
 PItemY:=Y;
End;

{ rectangle d'un panneau dont le bord haut est Top et le bord gauche XPref }
Procedure PanelRect(P,Top,XPref: Integer; Var X1,Y1,X2,Y2: Integer);
Var I,W,L,Q: Integer; S: String;
Begin
 W:=0;Y2:=Top+2;
 For I:=1 To PCount(P) Do Begin
  S:=PLabel(P,I);
  Q:=Pos('|',S);
  If Q>0 Then L:=(Q-1)*8+24+(Length(S)-Q)*8 Else L:=Length(S)*8;
  If PSubOf(P,I)<>0 Then L:=L+16;
  If L>W Then W:=L;
  Y2:=Y2+PItemH(P,I);
 End;
 X1:=XPref;
 X2:=X1+W+40;
 Y1:=Top;
 Y2:=Y2+2;
End;

Procedure DropRect(M: Integer; Var X1,Y1,X2,Y2: Integer);
Begin
 PanelRect(M,MENU_H,MenuX(M)-8,X1,Y1,X2,Y2);
 If X2>SCR_W-4 Then Begin X1:=X1-(X2-(SCR_W-4));X2:=SCR_W-4;End;
End;

{ rectangle du sous-menu Id ouvert depuis l'element I du menu M }
Procedure SubRect(M,I,Id: Integer; Var X1,Y1,X2,Y2: Integer);
Var PX1,PY1,PX2,PY2,W: Integer;
Begin
 DropRect(M,PX1,PY1,PX2,PY2);
 PanelRect(100+Id,PItemY(M,I,PY1)-2,PX2,X1,Y1,X2,Y2);
 If X2>SCR_W-4 Then Begin
  W:=X2-X1;
  X1:=PX1-W;X2:=PX1;
 End;
End;

Function PanelHit(P,X1,Y1,X2,Y2: Integer; X,Y: LongInt): Integer;
Var I: Integer;
Begin
 PanelHit:=0;
 If Not InBox(X,Y,X1,Y1,X2,Y2) Then Exit;
 For I:=1 To PCount(P) Do
  If (Y>=PItemY(P,I,Y1)) And (Y<PItemY(P,I,Y1)+PItemH(P,I)) Then PanelHit:=I;
End;

Function DropHit(M: Integer; X,Y: LongInt): Integer;
Var X1,Y1,X2,Y2: Integer;
Begin
 DropRect(M,X1,Y1,X2,Y2);
 DropHit:=PanelHit(M,X1,Y1,X2,Y2,X,Y);
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

Procedure DrawPanel(P,X1,Y1,X2,Y2,Hi: Integer);
Var I,Y,Q: Integer; S,Sc,Lb: String; H,En: Boolean;
Begin
 Box(X1+3,Y1+3,X2+3,Y2+3,INK);
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 For I:=1 To PCount(P) Do Begin
  S:=PLabel(P,I);
  Y:=PItemY(P,I,Y1);
  If S='-' Then Begin
   SetLineStyle(UserBitLn,$AAAA,1);
   SetColor(INK);
   Line(X1+2,Y+3,X2-2,Y+3);
   SetLineStyle(SolidLn,0,1);
  End Else Begin
   Q:=Pos('|',S);
   If Q>0 Then Begin Lb:=Copy(S,1,Q-1);Sc:=Copy(S,Q+1,20);End Else Begin
     Lb:=S;Sc:='';End;
   En:=PEnabled(P,I);
   H:=(I=Hi) And En;
   If H Then Box(X1+1,Y,X2-1,Y+15,INK);
   If PChecked(P,I) Then Begin
    If H Then WText(X1+6,Y+4,#251) Else PText(X1+6,Y+4,#251);
   End;
   If Not En Then Begin
    GreyText(X1+24,Y+4,Lb);
    If Sc<>'' Then GreyText(X2-8-Length(Sc)*8,Y+4,Sc);
    If PSubOf(P,I)<>0 Then GreyText(X2-18,Y+4,#16);
   End Else If H Then Begin
    WText(X1+24,Y+4,Lb);
    If Sc<>'' Then WText(X2-8-Length(Sc)*8,Y+4,Sc);
    If PSubOf(P,I)<>0 Then WText(X2-18,Y+4,#16);
   End Else Begin
    PText(X1+24,Y+4,Lb);
    If Sc<>'' Then PText(X2-8-Length(Sc)*8,Y+4,Sc);
    If PSubOf(P,I)<>0 Then PText(X2-18,Y+4,#16);
   End;
  End;
 End;
End;

Procedure DrawDropDown;
Var X1,Y1,X2,Y2: Integer;
Begin
 If MenuOpen=0 Then Exit;
 DropRect(MenuOpen,X1,Y1,X2,Y2);
 DrawPanel(MenuOpen,X1,Y1,X2,Y2,MenuHi);
 If (SubOpen<>0) And (MenuHi<>0) Then Begin
  SubRect(MenuOpen,MenuHi,SubOpen,X1,Y1,X2,Y2);
  DrawPanel(100+SubOpen,X1,Y1,X2,Y2,SubHi);
 End;
End;

{ element suivant (Dir=1) ou precedent (Dir=-1) utilisable du panneau P }
Function PNext(P,From,Dir: Integer): Integer;
Var I,N,K: Integer;
Begin
 N:=PCount(P);I:=From;
 For K:=1 To N+1 Do Begin
  I:=I+Dir;
  If I<1 Then I:=N;
  If I>N Then I:=1;
  If (Not PIsSep(P,I)) And PEnabled(P,I) Then Begin
    PNext:=I;Exit;End;
 End;
 PNext:=From;
End;

Procedure DoMenu(M,I: Integer); Forward;

Procedure RunMenu(StartM: Integer; ByMouse: Boolean);
Var M,Hi,H,T,SubWant,PickId,PickSubH: Integer; E: TEvent;
    Done,Pick,PickSub,Redraw,InSub: Boolean; SubT: LongInt;
    X1,Y1,X2,Y2,SX1,SY1,SX2,SY2: Integer;
Begin
 M:=StartM;Hi:=0;SubWant:=0;SubOpen:=0;SubHi:=0;SubT:=0;PickId:=0;PickSubH:=0;
 If Not ByMouse Then Hi:=PNext(M,0,1);
 MenuOpen:=M;MenuHi:=Hi;
 DrawAll;
 Done:=False;Pick:=False;PickSub:=False;
 Repeat
  PollEvent(E);
  Redraw:=False;
  { ouverture differee du sous-menu }
  If (SubOpen=0) And (SubWant<>0) And (MsNow-SubT>=250) Then Begin
   SubOpen:=SubWant;SubHi:=0;Redraw:=True;
  End;
  Case E.Kind Of
   4,2: Begin
         InSub:=False;
         DropRect(M,X1,Y1,X2,Y2);
         If SubOpen<>0 Then Begin
          SubRect(M,Hi,SubOpen,SX1,SY1,SX2,SY2);
          If InBox(E.X,E.Y,SX1,SY1,SX2,SY2) Then Begin
           InSub:=True;
           H:=PanelHit(100+SubOpen,SX1,SY1,SX2,SY2,E.X,E.Y);
           If (H<>0) And (PIsSep(100+SubOpen,H) Or Not PEnabled(100+SubOpen,H))
             Then H:=0;
           If H<>SubHi Then Begin SubHi:=H;Redraw:=True;End;
           If (E.Kind=2) And (SubHi<>0) Then Begin
            PickSub:=True;PickId:=SubOpen;PickSubH:=SubHi;Done:=True;
           End;
          End;
         End;
         If Not InSub Then Begin
          T:=TitleHit(E.X,E.Y);
          If (T>0) And (T<>M) Then Begin
           M:=T;Hi:=0;SubOpen:=0;SubWant:=0;Redraw:=True;
          End Else Begin
           H:=PanelHit(M,X1,Y1,X2,Y2,E.X,E.Y);
           If (H<>0) And (PIsSep(M,H) Or Not PEnabled(M,H)) Then H:=0;
           If H<>Hi Then Begin
            Hi:=H;SubOpen:=0;SubHi:=0;
            If H<>0 Then SubWant:=PSubOf(M,H) Else SubWant:=0;
            SubT:=MsNow;
            Redraw:=True;
           End;
          End;
          If E.Kind=2 Then Begin
           If PanelHit(M,X1,Y1,X2,Y2,E.X,E.Y)=0 Then Begin
            If TitleHit(E.X,E.Y)=0 Then Done:=True;
           End Else If Hi<>0 Then Begin
            If PSubOf(M,Hi)<>0 Then Begin
             SubOpen:=PSubOf(M,Hi);SubHi:=0;Redraw:=True;
            End Else Begin Pick:=True;Done:=True;End;
           End;
          End;
         End;
        End;
   3: Begin
       DropRect(M,X1,Y1,X2,Y2);
       If SubOpen<>0 Then Begin
        SubRect(M,Hi,SubOpen,SX1,SY1,SX2,SY2);
        H:=PanelHit(100+SubOpen,SX1,SY1,SX2,SY2,E.X,E.Y);
        If (H<>0) And (H=SubHi) Then Begin
         PickSub:=True;PickId:=SubOpen;PickSubH:=SubHi;Done:=True;
        End;
       End;
       If Not Done Then Begin
        H:=PanelHit(M,X1,Y1,X2,Y2,E.X,E.Y);
        If (H<>0) And (Hi=H) And (PSubOf(M,H)=0) Then Begin
          Pick:=True;Done:=True;End;
       End;
      End;
   1: Case E.Key Of
       K_ESC: If SubOpen<>0 Then Begin SubOpen:=0;SubWant:=0;Redraw:=True;End
         Else Done:=True;
       K_LEFT: If SubOpen<>0 Then Begin SubOpen:=0;SubWant:=0;Redraw:=True;End
               Else Begin
                Dec(M);If M<1 Then M:=NMENU;
                Hi:=PNext(M,0,1);SubWant:=0;Redraw:=True;
               End;
       K_RIGHT: If (SubOpen=0) And (Hi<>0) And (PSubOf(M,Hi)<>0) Then Begin
                 SubOpen:=PSubOf(M,Hi);SubHi:=PNext(100+SubOpen,0,
                   1);Redraw:=True;
                End Else If SubOpen=0 Then Begin
                 Inc(M);If M>NMENU Then M:=1;
                 Hi:=PNext(M,0,1);SubWant:=0;Redraw:=True;
                End;
       K_UP: Begin
              If SubOpen<>0 Then SubHi:=PNext(100+SubOpen,SubHi,-1)
              Else Begin Hi:=PNext(M,Hi,-1);SubWant:=0;End;
              Redraw:=True;
             End;
       K_DOWN: Begin
                If SubOpen<>0 Then SubHi:=PNext(100+SubOpen,SubHi,1)
                Else Begin Hi:=PNext(M,Hi,1);SubWant:=0;End;
                Redraw:=True;
               End;
       K_ENTER: Begin
                 If SubOpen<>0 Then Begin
                  If SubHi<>0 Then Begin
                   PickSub:=True;PickId:=SubOpen;PickSubH:=SubHi;Done:=True;
                  End;
                 End Else If Hi<>0 Then Begin
                  If PSubOf(M,Hi)<>0 Then Begin
                   SubOpen:=PSubOf(M,Hi);SubHi:=PNext(100+SubOpen,0,
                     1);Redraw:=True;
                  End Else Begin Pick:=True;Done:=True;End;
                 End;
                End;
      End;
  End;
  If Redraw Then Begin MenuOpen:=M;MenuHi:=Hi;DrawAll;End;
 Until Done;
 MenuOpen:=0;MenuHi:=0;SubOpen:=0;
 DrawAll;
 PickMods:=ModsNow;
 If PickSub Then DoSub(PickId,PickSubH)
 Else If Pick And (Hi>0) Then DoMenu(M,Hi);
End;

{ Barre de titre GEM (hachuree) }
Var TitleInactive : Boolean;     { fenetre non active : barre de titre sans
  hachures }

Procedure GemTitleBar(X1,Y1,X2,Y2: Integer; Const Title: String; HasFull:
  Boolean);
Var Y,TX,TW: Integer; T: String;
Begin
 Box(X1,Y1,X2,Y2,PAPER);
 Frame(X1,Y1,X2,Y2);
 SetColor(INK);
 If Not TitleInactive Then Begin
  Y:=Y1+2;
  While Y<=Y2-2 Do Begin Line(X1+19,Y,X2-19,Y);Inc(Y,2);End;
 End;
 T:=Copy(Title,1,(X2-X1-60) Div 8);
 TW:=Length(T)*8+16;
 TX:=(X1+X2-TW) Div 2;
 If TX<X1+20 Then TX:=X1+20;
 Box(TX,Y1+1,TX+TW,Y2-1,PAPER);
 PText(TX+8,Y1+((Y2-Y1)-7) Div 2+1,T);
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
 BufL:=(BufB(P,I) Shl 24) Or (BufB(P,I+1) Shl 16) Or (BufB(P,I+2) Shl 8) Or
   BufB(P,I+3);
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
 VdiInMd   : Array[1..4] Of Integer;
 { routines utilisateur vex_* }
 VexTim,VexBut,VexMot,VexCur : LongInt;
 VexTimLast  : LongInt;
 InVex       : Boolean;
 KbdPrevX,KbdPrevY,KbdPrevB : LongInt;

{ Installe une forme de curseur de souris definie par un bloc MFORM en memoire
  invite : x et y du point chaud, plans, couleurs, 16 mots de masque, 16 de
    dessin
  (graf_mouse 255 et vsc_form) }
Procedure ApplyMouseForm(A: LongInt);
Var I: Integer;
Begin
 CurHotX:=Clamp(SExt(Rd16(A),2),0,15);CurHotY:=Clamp(SExt(Rd16(A+2),2),0,15);
 For I:=0 To 15 Do Begin
  CurMask[I]:=Rd16(A+10+I*2);CurData[I]:=Rd16(A+42+I*2);
 End;
 {$IFDEF FPC}
 If GfxOn Then Begin If MouseHidden>0 Then HideMouse Else CursorDraw(MX,MY);End;
 {$ENDIF}
End;

Procedure VdiInitTables;
Const B : Array[0..15] Of Byte = (0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);
      C : Array[1..8] Of Byte = (1,2,4,6,8,10,12,14);
Var I: Integer;
Begin
 For I:=0 To 15 Do BayerM[I Div 4,I Mod 4]:=B[I];
 For I:=1 To 8 Do BayerCnt[I]:=C[I];
 For I:=1 To 4 Do VdiInMd[I]:=1;
End;

Procedure VdiDefaults(Var V: TVdi);
Var I: Integer;
Begin
 V.WrMode:=WM_REPL;
 V.LineType:=1;V.LineCol:=1;V.LineWidth:=1;V.LineEnd0:=0;V.LineEnd1:=0;V.LineUd
   :=$FFFF;
 V.MarkType:=3;V.MarkCol:=1;V.MarkH:=8;
 V.TxtFont:=1;V.TxtCol:=1;V.TxtRot:=0;V.TxtEff:=0;V.TxtHAl:=0;V.TxtVAl:=0;V.
   TxtCell:=16;
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
  CX1:=Max2(0,VP^.Cx1);CY1:=Max2(0,VP^.Cy1);CX2:=Min2(SW-1,
    VP^.Cx2);CY2:=Min2(SH-1,VP^.Cy2);
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
   If Xor_ Then Wr8(A+XB,Rd8(A+XB) Xor $FF) Else If Col Then Wr8(A+XB,$FF) Else
     Wr8(A+XB,0);
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
 If (VP^.FillInt=1) And (VP^.WrMode=WM_REPL) Then Begin
   FastSpan(Y,X1,X2,Col,False);Exit;End;
 If (VP^.FillInt=1) And (VP^.WrMode=WM_XOR) Then Begin
   FastSpan(Y,X1,X2,Col,True);Exit;End;
 If (VP^.FillInt=0) And (VP^.WrMode=WM_REPL) Then Begin
   FastSpan(Y,X1,X2,False,False);Exit;End;
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

Procedure PolyFillPts(N: Integer; Var XS,YS: TPoly; UseFillAttr: Boolean);
  Forward;

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
Var W: Integer; Col: Boolean; DXf,DYf,L,NX,NY: Real; QX,QY: TPoly; Sv,SvC,SvW:
  Integer;
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
Var Y,MinY,MaxY,I,J,K,Cnt: Integer; Xi: Array[0..127] Of Integer;
  X1,Y1,X2,Y2,T: Integer;
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

Function ArcPoints(CXx,CYy,RX,RY,A0,A1: Integer; Var XS,YS: TPoly; Start:
  Integer): Integer;
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
  0: Begin
    N:=ArcPoints(CXx,CYy,RX,RY,A0,A1,PX,PY,0);PolyOutline(N,PX,PY,False);End;
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
  3: Begin
    VLine(X-H,Y,X+H,Y);VLine(X,Y-H,X,Y+H);VLine(X-H,Y-H,X+H,Y+H);VLine(X-H,Y+H,
    X+H,Y-H);End;
  4: Begin
    VLine(X-H,Y-H,X+H,Y-H);VLine(X+H,Y-H,X+H,Y+H);VLine(X+H,Y+H,X-H,Y+
    H);VLine(X-H,Y+H,X-H,Y-H);End;
  5: Begin VLine(X-H,Y-H,X+H,Y+H);VLine(X-H,Y+H,X+H,Y-H);End;
  6: Begin
    VLine(X,Y-H,X+H,Y);VLine(X+H,Y,X,Y+H);VLine(X,Y+H,X-H,Y);VLine(X-H,Y,X,
    Y-H);End;
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
 W:=Length(S)*CellW(VP^.TxtCell);    { le gras epaissit le trait dans la
   cellule : l'avance reste celle de la police }
 TextWidthPx:=W;
End;

Procedure DrawGlyph(OX,OY: Integer; Ch: Integer; Rot: Integer; RX,RY: Integer;
  Pass: Integer);
Var Gx,Gy,Cw,Ch2,DX,DY,TX,TY,Sh,Sx,X0,X1: Integer; On_,Col: Boolean; Bl:
  Integer;
Begin
 Cw:=CellW(VP^.TxtCell);Ch2:=VP^.TxtCell;
 If Ch2<6 Then Ch2:=6;
 Col:=ColBit(VP^.TxtCol);
 Bl:=BaseLine(Ch2);
 For Gy:=0 To Ch2-1 Do Begin
  { italique : la ligne du haut reste en place, les lignes du bas glissent vers
    la gauche (jusqu'a
    -7 pixels pour la police 8x16, comme le parallelogramme que 1st Word efface
      avant de tracer) ;
    la partie qui sort de la cellule (Pass=1) est tracee sans effacer la lettre
      voisine }
  Sh:=0;
  If (VP^.TxtEff And 4)<>0 Then Sh:=-(Gy Div 2);
  If Pass=0 Then Begin X0:=0;X1:=Cw-1;End Else Begin X0:=Sh;X1:=-1;End;
  For Gx:=X0 To X1 Do Begin
   Sx:=Gx-Sh;
   On_:=GlyphPix(Ch2,Ch,Sx,Gy);
   If (VP^.TxtEff And 1)<>0 Then
    On_:=On_ Or GlyphPix(Ch2,Ch,Sx-1,Gy);
   If (VP^.TxtEff And 16)<>0 Then Begin
    { contour : on ne garde que l'anneau autour de la lettre }
    If On_ Then On_:=False
    Else On_:=GlyphPix(Ch2,Ch,Sx-1,Gy) Or GlyphPix(Ch2,Ch,Sx+1,Gy) Or
              GlyphPix(Ch2,Ch,Sx,Gy-1) Or GlyphPix(Ch2,Ch,Sx,Gy+1);
   End;
   If (VP^.TxtEff And 2)<>0 Then
    If On_ And (((OX+Gx+OY+Gy) And 1)=1) Then On_:=False;
   If (VP^.TxtEff And 8)<>0 Then If Gy=Bl+1 Then On_:=True;
   DX:=OX+Gx-RX;DY:=OY+Gy-RY;
   Case Rot Of
    1: Begin TX:=DY;TY:=-DX;End;
    2: Begin TX:=-DX;TY:=-DY;End;
    3: Begin TX:=-DY;TY:=DX;End;
   Else Begin TX:=DX;TY:=DY;End;
   End;
   If (VP^.WrMode=WM_REPL) And (Pass=0) Then PlotPat(RX+TX,RY+TY,On_,Col)
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
 Adv:=Cw;
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
  DrawGlyph(OX+(I-1)*Adv,OY,Ord(S[I]),Rot,X,Y,0);
 If (VP^.TxtEff And 4)<>0 Then
  For I:=1 To Length(S) Do
   DrawGlyph(OX+(I-1)*Adv,OY,Ord(S[I]),Rot,X,Y,1);
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

Procedure CopyRaster(Const Src,Dst: TMfdb; SX1,SY1,SX2,SY2,DX1,DY1: Integer;
  Mode: Integer;
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
Var Stack: Array[0..511,0..1] Of Integer; SP: Integer; L,R,I,XX: Integer; Seed:
  Boolean;
 Function Stop(Xp,Yp: Integer): Boolean;
 Begin
  If Border>=0 Then Stop:=BGet(Xp,Yp)=ColBit(Border) Else
    Stop:=BGet(Xp,Yp)<>Seed;
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
  If (Border<0) And (VP^.FillInt=1) And (Seed=ColBit(VP^.FillCol)) Then
    Continue;
  L:=XX;R:=XX;
  While (L>CX1) And Not Stop(L-1,Y) Do Dec(L);
  While (R<CX2) And Not Stop(R+1,Y) Do Inc(R);
  FillSpanPat(Y,L,R);
  For I:=L To R Do Begin
   If SP>=510 Then Break;
   If (Y>CY1) And Not Stop(I,Y-1) And ((I=L) Or Stop(I-1,Y-1)) Then Begin
     Stack[SP,0]:=I;Stack[SP,1]:=Y-1;Inc(SP);End;
   If (Y<CY2) And Not Stop(I,Y+1) And ((I=L) Or Stop(I-1,Y+1)) Then Begin
     Stack[SP,0]:=I;Stack[SP,1]:=Y+1;Inc(SP);End;
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
 If H>=11 Then Begin
   VP^.TxtCell:=16;TxtOutW:=8;TxtOutH:=13;TxtOutCW:=8;TxtOutCH:=16;End
 Else Begin VP^.TxtCell:=8;TxtOutW:=8;TxtOutH:=7;TxtOutCW:=8;TxtOutCH:=8;End;
   { ST mono : seulement les polices 8x16 et 8x8 }
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
  { en mode batch : police integree }
  Move(Font8Emb,Font8,SizeOf(Font8));
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
 If AesTrace And VdiTrace Then Begin
  Write(ConOut,'VDI ',Op,' sub=',Sub,' h=',H,' n=',N,' ni=',NI,' in=');
  For I:=0 To Min2(NI,3)-1 Do Write(ConOut,SExt(Rd16(Ii+I*2),2),' ');
  Write(ConOut,' pts=');
  For I:=0 To Min2(N*2,12)-1 Do Write(ConOut,SExt(Rd16(Pi+I*2),2),' ');
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
   Vd[Hn].FillInt:=Clamp(IntIn(7),0,
     4);Vd[Hn].FillSty:=IntIn(8);Vd[Hn].FillCol:=IntIn(9);
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
           ConRow:=Clamp(IntIn(0)-1,0,CON_ROWS-1);ConCol:=Clamp(IntIn(1)-1,0,
             CON_COLS-1);
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
      If AesTrace And VdiTrace Then Begin
        WriteLn(ConOut,'  gtext [',S,'] at ',PtsX(Pi,0),',',PtsY(Pi,0),' cell=',
        VP^.TxtCell,' eff=',VP^.TxtEff,' font=',VP^.TxtFont,' hal=',VP^.TxtHAl,
        ' val=',VP^.TxtVAl,' wm=',VP^.WrMode,' clip=',CX1,',',CY1,',',CX2,',',
        CY2);Flush(ConOut);End;
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
           PlotSolid(X1+(I Mod N)*(X2-X1+1) Div N,Y1+(I Div N)*(Y2-Y1+1) Div
             J,True);
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
            For I:=2 To NI-1 Do If Length(S)<250 Then S:=S+Chr(Rd16(Ii+I*2) And
              $FF);
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
  12: Begin SetCellFromHeight(PtsY(Pi,0));ReturnText;End;
  13: Begin V:=IntIn(0);V:=((V+450) Div 900)*900;V:=V Mod 3600;If V<0 Then
    V:=0;VP^.TxtRot:=V;SetOut(0,V);RetI(1);End;
  14: Begin SetOut(0,IntIn(0));RetI(1);End;
  15: Begin
    VP^.LineType:=Clamp(IntIn(0),1,7);SetOut(0,VP^.LineType);RetI(1);End;
  16: Begin
       V:=PtsX(Pi,0);If V<1 Then V:=1;If Not Odd(V) Then Dec(V,0);
       If V>39 Then V:=39;
       VP^.LineWidth:=V;SetPts(0,V);SetPts(1,0);RetP(1);
      End;
  17: Begin VP^.LineCol:=IntIn(0);SetOut(0,IntIn(0));RetI(1);End;
  18: Begin
    VP^.MarkType:=Clamp(IntIn(0),1,6);SetOut(0,VP^.MarkType);RetI(1);End;
  19: Begin
    VP^.MarkH:=Max2(1,PtsY(Pi,1));SetPts(0,VP^.MarkH);SetPts(1,
    VP^.MarkH);RetP(1);End;
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
       V:=IntIn(0);If (V<1) Or (V>4) Then
         V:=1;VP^.WrMode:=V;SetOut(0,V);RetI(1);
      End;
  27: Begin
       { vq_cellarray : echantillonne l'ecran sur une grille }
       X1:=PtsX(Pi,0);Y1:=PtsY(Pi,0);X2:=PtsX(Pi,1);Y2:=PtsY(Pi,1);
       If X2<X1 Then Begin V:=X1;X1:=X2;X2:=V;End;
       If Y2<Y1 Then Begin V:=Y1;Y1:=Y2;Y2:=V;End;
       I:=Clamp(IntIn(0),1,64);J:=Clamp(IntIn(1),1,64);
       For Mode:=0 To J-1 Do
        For Hn:=0 To I-1 Do
         SetOut(3+Mode*I+Hn,Ord(BGet(X1+((Hn*2+1)*(X2-X1+1)) Div
           (2*I),Y1+((Mode*2+1)*(Y2-Y1+1)) Div (2*J))));
       SetOut(0,I);SetOut(1,J);SetOut(2,0);
       RetI(3+I*J);
      End;
  33: Begin
       V:=IntIn(0);
       If (V>=1) And (V<=4) Then VdiInMd[V]:=Clamp(IntIn(1),1,2);
       SetOut(0,IntIn(1));RetI(1);
      End;
  111: Begin
        { vsc_form : forme du curseur de la souris }
        ApplyMouseForm(Ii);
       End;
  115: Begin
        { vqin_mode : mode d'entree courant du peripherique }
        V:=IntIn(0);
        If (V>=1) And (V<=4) Then SetOut(0,VdiInMd[V]) Else SetOut(0,1);
        RetI(1);
       End;
  35: Begin
       SetOut(0,VP^.LineType);SetOut(1,VP^.LineCol);SetOut(2,VP^.WrMode);
       SetOut(3,VP^.LineEnd0);SetOut(4,VP^.LineEnd1);RetI(5);
       SetPts(0,VP^.LineWidth);SetPts(1,0);RetP(1);
      End;
  36: Begin
       SetOut(0,VP^.MarkType);SetOut(1,VP^.MarkCol);SetOut(2,
         VP^.WrMode);RetI(3);
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
         SetOut(0,1);SetOut(1,2);SetOut(2,63);SetOut(3,0);SetOut(4,1);SetOut(5,
           0);
         SetOut(6,2000);SetOut(7,1);SetOut(8,1);SetOut(9,4);SetOut(10,
           1);SetOut(11,1);
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
        If V>=10 Then SetCellFromHeight(16) Else SetCellFromHeight(8);
        SetOut(0,V);RetI(1);ReturnText;
       End;
  108: Begin
    VP^.LineEnd0:=IntIn(0);VP^.LineEnd1:=IntIn(1);SetOut(0,
    VP^.LineEnd0);SetOut(1,VP^.LineEnd1);RetI(2);End;
  109,121: Begin
        ReadMfdb(Rd32(Ctl+14),Src);ReadMfdb(Rd32(Ctl+18),Dst);
        If Op=109 Then Begin
         Mode:=IntIn(0);
         CopyRaster(Src,Dst,PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),PtsX(Pi,
           2),PtsY(Pi,2),Mode,False,1,0);
        End Else
         CopyRaster(Src,Dst,PtsX(Pi,0),PtsY(Pi,0),PtsX(Pi,1),PtsY(Pi,1),PtsX(Pi,
           2),PtsY(Pi,2),
                    Clamp(IntIn(0),1,4),True,IntIn(1),IntIn(2));
       End;
  110: Begin
        ReadMfdb(Rd32(Ctl+14),Src);ReadMfdb(Rd32(Ctl+18),Dst);
        If (Src.Addr<>0) And (Dst.Addr<>0) And (Src.Addr<>Dst.Addr) Then
         For I:=0 To Src.WW*2*Src.H*Src.Planes-1 Do
           Wr8(Dst.Addr+I,Rd8(Src.Addr+I));
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
        SetPts(0,CellW(VP^.TxtCell));SetPts(1,0);SetPts(2,0);SetPts(3,
          0);SetPts(4,0);SetPts(5,0);RetP(3);
        SetOut(0,IntIn(0));RetI(1);
       End;
  118: Begin
        Wr32(Ctl+18,VexTim);VexTim:=Rd32(Ctl+14);VexTimLast:=MsNow;
        SetOut(0,20);RetI(1);
       End;
  119: Begin SetOut(0,0);RetI(1);End;
  120: Begin End;
  122: Begin
        If IntIn(0)<>0 Then MouseHidden:=0 Else If MouseHidden>0 Then
          Dec(MouseHidden);
       End;
  123: Inc(MouseHidden);
  124: Begin
    SetOut(0,GMouseB);RetI(1);SetPts(0,GMouseX);SetPts(1,GMouseY);RetP(1);End;
  125: Begin Wr32(Ctl+18,VexBut);VexBut:=Rd32(Ctl+14);End;
  126: Begin Wr32(Ctl+18,VexMot);VexMot:=Rd32(Ctl+14);End;
  127: Begin
        Wr32(Ctl+18,VexCur);VexCur:=Rd32(Ctl+14);
        UserCursor:=VexCur<>STUB_RTS;
       End;
  128: Begin SetOut(0,0);RetI(1);End;
  129: Begin
        VP^.ClipOn:=IntIn(0)<>0;
        VP^.Cx1:=PtsX(Pi,0);VP^.Cy1:=PtsY(Pi,0);VP^.Cx2:=PtsX(Pi,
          1);VP^.Cy2:=PtsY(Pi,1);
        SetOut(0,0);
       End;
  130: Begin
        SetOut(0,1);
        S:='Atari System Font';
        For I:=1 To 32 Do If I<=Length(S) Then SetOut(I,Ord(S[I])) Else
          SetOut(I,0);
        SetOut(33,0);RetI(34);
       End;
  131: Begin
        If VP^.TxtCell<6 Then VP^.TxtCell:=6;
        SetOut(0,32);SetOut(1,255);RetI(2);
        I:=BaseLine(VP^.TxtCell);
        SetPts(0,CellW(VP^.TxtCell));SetPts(1,VP^.TxtCell-1-I);SetPts(2,
          CellW(VP^.TxtCell));SetPts(3,0);
        SetPts(4,0);SetPts(5,VP^.TxtCell-1-I);SetPts(6,0);SetPts(7,I Div
          2);SetPts(8,0);SetPts(9,I);
        RetP(5);
       End;
 Else Begin
   { code VDI inconnu (le code 34 n'est pas une fonction VDI documentee) : sans
     sortie, signale dans le moniteur }
   Str(Op,S);UnknownCall:='VDI '+S;
   If AesTrace Then Begin
     WriteLn(ConOut,'VDI unsupported opcode ',Op);Flush(ConOut);End;
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
Var SvRg: Array[0..15] Of LongInt; SvPC,SvSR,SvUSP,SvSSP,SvOp: LongInt; N:
  LongInt; SvStop: Integer;
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
 VP^.WrMode:=WM_REPL;VP^.FillPer:=0;VP^.LineWidth:=1;VP^.LineType:=1;VP^.LineCol
   :=1;
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

Procedure OText(X,Y: Integer; Const S: String; Cell: Integer; ColIdx: Integer;
  Repl: Boolean);
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

Procedure ObjDrawOne(T: LongInt; I: Integer; AX,AY: Integer; Const
  ClipX1,ClipY1,ClipX2,ClipY2: Integer);
Var Ty,St,Fl,W,H,Th,Cw,Ch,Fi,Pat,Ic,Bc,Tc,Just,Fnt,Cell: Integer; Sp,Ted,Pr:
  LongInt;
    Col: Word; S,Tm: String; Ch1: Char; TXx,TYy,Rx,K,J,XX,YY: Integer; Repl:
      Boolean;
    Ib: LongInt; Wb,Hl,Wi,Hi,Xi,Yi,Bx,By: Integer; PrevSt: Integer; Rv:
      LongInt; Tw: Integer;
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
    Ic:=Col And 15;Pat:=(Col Shr 4) And 7;Tc:=(Col Shr 8) And 15;Bc:=(Col Shr
      12) And 15;
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
    Col:=Rd16(Ted+18);Fnt:=Rd16(Ted+12);Just:=Rd16(Ted+16);Th:=SExt(Rd16(Ted+
      22),2);
    Ic:=Col And 15;Pat:=(Col Shr 4) And 7;Tc:=(Col Shr 8) And 15;Bc:=(Col Shr
      12) And 15;
    Repl:=(Col And $80)<>0;
    Cell:=CellOfFont(Fnt);
    If (Ty=G_BOXTEXT) Or (Ty=G_FBOXTEXT) Then Begin
     OFill(AX,AY,AX+W-1,AY+H-1,Pat,Ic);
     OBorder(AX,AY,W,H,Th,Bc);
    End Else If Repl Then OFill(AX,AY,AX+W-1,AY+H-1,Pat,Ic);
    S:=RdStr(Rd32(Ted),120);
    If (Ty=G_FTEXT) Or (Ty=G_FBOXTEXT) Then
      S:=FtextDisplay(RdStr(Rd32(Ted+4),120),S);
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
    { le fond blanc ne doit pas ecraser le cadre interieur du parent (chaines
      pleine largeur) }
    Th:=0;Pr:=OParent(T,I);
    If (Ty=G_STRING) And (Pr>=0) Then Begin
     K:=OType(T,Pr);
     If (K=G_BOX) Or (K=G_BOXCHAR) Then Th:=SExt((OSpec(T,Pr) Shr 16) And
       $FF,1);
     If Th<0 Then Th:=0;
    End;
    If Th>0 Then Begin
     Rx:=AX-OX(T,I);   { origine absolue du parent }
     K:=AY-OY(T,I);
     OFill(Max2(AX,Rx+Th),Max2(AY,K+Th),Min2(AX+W-1,Rx+OW(T,Pr)-1-Th),Min2(AY+
       H-1,K+OH(T,Pr)-1-Th),0,0);
    End Else OFill(AX,AY,AX+W-1,AY+H-1,0,0);
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
      If (Rd8(Rd32(Pb)+LongInt(YY)*Wb+(XX Shr 3)) And (128 Shr (XX And 7)))<>0
        Then
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
      If (Rd8(Rd32(Ib)+LongInt(YY)*K+(XX Shr 3)) And (128 Shr (XX And 7)))<>0
        Then Begin
       If (Rd8(Rd32(Ib+4)+LongInt(YY)*K+(XX Shr 3)) And (128 Shr (XX And
         7)))<>0 Then
        PlotSolid(AX+Xi+XX,AY+Yi+YY,True)
       Else PlotSolid(AX+Xi+XX,AY+Yi+YY,False);
      End;
     End;
    S:=RdStr(Rd32(Ib+8),40);
    Tw:=SExt(Rd16(Ib+30),2);
    OFill(AX+SExt(Rd16(Ib+26),2),AY+SExt(Rd16(Ib+28),2),AX+SExt(Rd16(Ib+26),2)+
      Tw-1,
          AY+SExt(Rd16(Ib+28),2)+SExt(Rd16(Ib+32),2)-1,0,0);
    OText(AX+SExt(Rd16(Ib+26),2)+(Tw-Length(S)*8) Div
      2,AY+SExt(Rd16(Ib+28),2),S,8,1,False);
    If Rd16(Ib+12)<>0 Then
     OText(AX+SExt(Rd16(Ib+14),2),AY+SExt(Rd16(Ib+16),2),Chr(Rd16(Ib+12) And
       $FF),8,1,False);
    OSetup;SetClip(ClipX1,ClipY1,ClipX2,ClipY2);
    If (St And OS_SELECTED)<>0 Then Begin
     { icone et texte inverses, sans le reste de l'objet }
     VP^.FillInt:=1;VP^.WrMode:=WM_XOR;VP^.FillCol:=1;
     VBar(AX+Xi,AY+Yi,AX+Xi+Wi-1,AY+Yi+Hi-1);
     VBar(AX+SExt(Rd16(Ib+26),2),AY+SExt(Rd16(Ib+28),2),AX+SExt(Rd16(Ib+26),2)+
       Tw-1,
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
    Wr16(Pb+18,ClipX1);Wr16(Pb+20,ClipY1);Wr16(Pb+22,ClipX2-ClipX1+1);Wr16(Pb+
      24,ClipY2-ClipY1+1);
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
 If (MXx>=AX) And (MXx<AX+OW(T,I)) And (MYy>=AY) And (MYy<AY+OH(T,I)) Then
   Hit:=I
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
  'a': ValidChar:=((Ch>='a') And (Ch<='z')) Or ((Ch>='A') And (Ch<='Z')) Or
    (Ch=' ');
  'A': ValidChar:=((Ch>='A') And (Ch<='Z')) Or (Ch=' ');
  'n': ValidChar:=((Ch>='a') And (Ch<='z')) Or ((Ch>='A') And (Ch<='Z')) Or
    ((Ch>='0') And (Ch<='9')) Or (Ch=' ');
  'N': ValidChar:=((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or
    (Ch=' ');
  'F': ValidChar:=((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or
    (Ch='?') Or (Ch='*') Or (Ch=':') Or (Ch='.') Or (Ch='_');
  'f': ValidChar:=(Ch>' ') And (Ch<>'\') And (Ch<>'/');
  'P': ValidChar:=((Ch>='A') And (Ch<='Z')) Or ((Ch>='0') And (Ch<='9')) Or
    (Ch='\') Or (Ch=':') Or (Ch='.') Or (Ch='_') Or (Ch='?') Or (Ch='*');
  'p': ValidChar:=(Ch>=' ');
  'X': ValidChar:=Ch>=' ';
 Else ValidChar:=Ch>=' ';
 End;
End;

{ Position en pixels du curseur d'edition (dans le champ) }
Function EditCursorX(T: LongInt; Obj,Idx: Integer): Integer;
Var Ted: LongInt; Tm: String; I,K: Integer; X,Y: Integer; Just,W,Tw,TX:
  Integer; S: String;
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
Function ObjEdit(T: LongInt; Obj: Integer; Key: LongInt; Var Idx: Integer;
  Kind: Integer): Integer;
Var Ted,Txt,Vp: LongInt; S,Vl: String; Mx: Integer; Ch: Char; Scan,Asc:
  Integer; Ok: Boolean;
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
      If Asc=27 Then Begin S:='';Idx:=0;Ok:=True;End   { Esc efface le champ
        (GEM) }
      Else If (Asc=8) Or (Asc=127) Then Begin
       If (Asc=8) And (Idx>0) Then Begin Delete(S,Idx,1);Dec(Idx);Ok:=True;End
       Else If (Asc=127) And (Idx<Length(S)) Then Begin
         Delete(S,Idx+1,1);Ok:=True;End;
      End Else If (Asc=0) And (Scan=$4B) Then Begin If Idx>0 Then
        Dec(Idx);Ok:=True;End
      Else If (Asc=0) And (Scan=$4D) Then Begin If Idx<Length(S) Then
        Inc(Idx);Ok:=True;End
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
         If ValidChar(Vl[Length(Vl)],Ch) Then Begin
           Insert(Ch,S,Idx+1);Inc(Idx);Ok:=True;End;
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
 RscOwned   : Boolean;

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

{ Relocalise un fichier ressource charge en memoire invite a l'adresse B :
  les decalages deviennent des adresses et les coordonnees des pixels }
Procedure RscFixup(B: LongInt);
Var Nobs,Nted,Nib,Nbb,Nstr,Nimg,Ntree,Oobj,Oted,Oib,Obb,Ofrs,Ofri,Otri: LongInt;
    A: LongInt; Ty,I: Integer;
Begin
 Oobj:=Rd16(B+2);Oted:=Rd16(B+4);Oib:=Rd16(B+6);Obb:=Rd16(B+8);Ofrs:=Rd16(B+10);
 Ofri:=Rd16(B+16);Otri:=Rd16(B+18);
 Nobs:=Rd16(B+20);Ntree:=Rd16(B+22);Nted:=Rd16(B+24);Nib:=Rd16(B+
   26);Nbb:=Rd16(B+28);
 Nstr:=Rd16(B+30);Nimg:=Rd16(B+32);
 { objets }
 For I:=0 To Nobs-1 Do Begin
  A:=B+Oobj+I*24;
  Ty:=Rd16(A+6) And $FF;
  If (Ty<>G_BOX) And (Ty<>G_IBOX) And (Ty<>G_BOXCHAR) Then
    Wr32(A+12,Rd32(A+12)+B);
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
End;

Function RscLoad(Const Name: String): Boolean;
Var P: Pointer;
  Len,B,I,J,Nobs,Nted,Nib,Nbb,Nstr,Nimg,Ntree,Oobj,Oted,Oib,Obb,Ofrs,Ofri,Otri:
  LongInt;
    A: LongInt; Ty: Integer; F: String;
Begin
 RscLoad:=False;
 F:=TosPath(Name);
 If Not ReadFileBytes(F,P,Len) Then Begin
  F:=HostPath(PathOf(ProgName)+ShortName(Name));
  If Not ReadFileBytes(F,P,Len) Then Exit;
 End;
 If Len<36 Then Begin FreeMem(P,Len);Exit;End;
 Oobj:=BufW(P,2);Oted:=BufW(P,4);Oib:=BufW(P,6);Obb:=BufW(P,8);Ofrs:=BufW(P,10);
 Ofri:=BufW(P,16);Otri:=BufW(P,18);
 Nobs:=BufW(P,20);Ntree:=BufW(P,22);Nted:=BufW(P,24);Nib:=BufW(P,
   26);Nbb:=BufW(P,28);
 Nstr:=BufW(P,30);Nimg:=BufW(P,32);
 RscSize:=BufW(P,34);
 If RscSize<Len Then RscSize:=Len;
 B:=DoMalloc(RscSize+16);
 If B=0 Then Begin FreeMem(P,Len);Exit;End;
 For I:=0 To Len-1 Do Wr8(B+I,BufB(P,I));
 FreeMem(P,Len);
 RscBase:=B;RscLoaded:=True;
 RscOwned:=True;
 RscFixup(B);
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
  5,15: If Idx<Rd16(B+30) Then Begin
    Addr:=Rd32(B+Ofrs+Idx*4);RscGaddr:=True;End;
  6,16: If Idx<Rd16(B+32) Then Begin
    Addr:=Rd32(B+Ofri+Idx*4);RscGaddr:=True;End;
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
 ButtonTaken : Boolean;      { le clic courant a ete consomme par le
   gestionnaire }
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
 BvDisk,BvHard : LongInt;
 SearchPos   : Integer;
 ObjSysV     : Array[1..6,0..1] Of Integer;
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
  ('X...............','XX..............','XoX.............','XooX............',
    'XoooX...........',
   'XooooX..........','XoooooX.........','XooooooX........','XoooooooX.......',
     'XooooXXXXX......',
   'XooXooX.........','XoX.XooX........','XX..XooX........','X....XooX.......',
     '.....XooX.......',
   '......XX........'),
  { 1 curseur de texte }
  ('................','..XXX.XXX.......','....XoX.........','....XoX.........',
    '....XoX.........',
   '....XoX.........','....XoX.........','....XoX.........','....XoX.........',
     '....XoX.........',
   '....XoX.........','....XoX.........','....XoX.........','..XXX.XXX.......',
     '................',
   '................'),
  { 2 abeille / sablier }
  ('..XXXXXXXXXX....','..XooooooooX....','...XoooooooX....','....XooooooX....',
    '.....XooooX.....',
   '......XooX......','.......XX.......','......XooX......','.....XooooX.....',
     '....XooooooX....',
   '...XoooooooX....','..XooooooooX....','..XXXXXXXXXX....','................',
     '................',
   '................'),
  { 3 main pointant }
  ('.....XX.........','....XooX........','....XooX........','....XooX........',
    '....XooXXX......',
   '....XooXooXXX...','.XX.XooXooXooX..','XooXXooooooooX..','XooooooooooooX..',
     '.XooooooooooooX.',
   '..XoooooooooooX.','..XoooooooooooX.','...XooooooooooX.','...XXooooooooX..',
     '....XXooooooX...',
   '.....XXXXXXXX...'),
  { 4 main plate }
  ('......XX........','..XX.XooXXX.....','.XooXXooXooXX...','.XooXXooXooXooX.',
    '..XooXooXooXooX.',
   '..XooXooXooXooX.','XXXooooooooooooX','XooXooooooooooX.','XooooooooooooX..',
     '.XoooooooooooX..',
   '..XooooooooooX..','..XooooooooooX..','...XooooooooX...','....XooooooX....',
     '....XXXXXXXX....',
   '................'),
  { 5 croix fine }
  ('.......XX.......','.......XX.......','.......XX.......','.......XX.......',
    '.......XX.......',
   '.......XX.......','.......XX.......','XXXXXX.....XXXXX','XXXXXX.....XXXXX',
     '.......XX.......',
   '.......XX.......','.......XX.......','.......XX.......','.......XX.......',
     '.......XX.......',
   '.......XX.......'),
  { 6 croix epaisse }
  ('.......XX.......','.......XX.......','.......XX.......','.......XX.......',
    '.......XX.......',
   '.......XX.......','.......XX.......','XXXXXXXXXXXXXXXX','XXXXXXXXXXXXXXXX',
     '.......XX.......',
   '.......XX.......','.......XX.......','.......XX.......','.......XX.......',
     '.......XX.......',
   '.......XX.......'),
  { 7 croix evidee }
  ('......XooX......','......XooX......','......XooX......','......XooX......',
    '......XooX......',
   '......XooX......','XXXXXXXooXXXXXXX','XooooooooooooooX','XooooooooooooooX',
     'XXXXXXXooXXXXXXX',
   '......XooX......','......XooX......','......XooX......','......XooX......',
     '......XooX......',
   '......XooX......'));
 CurHot : Array[0..7,0..1] Of Byte =
   ((0,0),(5,7),(7,6),(7,0),(7,0),(7,7),(7,7),(7,7));

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
 If AesTrace Then Begin Write(ConOut,'  MSG to ',P,':');For I:=0 To 7 Do
   Write(ConOut,' ',Procs[P].Q[1,I]);WriteLn(ConOut);Flush(ConOut);End;
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
Var I,K,Z,Cnt: Integer; Cur: Array[1..64] Of TRect; N,M: Integer; B,A,P: TRect;
  Tmp: Array[1..64] Of TRect;
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
  Else Begin
    VP^.FillInt:=1;VP^.FillCol:=1;VBar(CXp+3-I,CYp-I,CXp+3-I,CYp+I);End;
  End;
 End;
End;

Procedure DrawWinFrame(H: Integer);
Var W: ^TWin; R,Wk: TRect; K,X1,Y1,X2,Y2,I,TX,Tw: Integer; S: String; Top:
  Boolean;
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
   For I:=0 To WTITLE_H-4 Do If Odd(I) Then
     FastSpan(Y1+2+I,X1+2,X2-2,True,False);
  End;
  FastSpan(Y1+WTITLE_H,X1,X2,True,False);
  TX:=X1+1;
  If (K And CLOSER_)<>0 Then Begin
   AFill(X1+1,Y1+1,X1+WSCROLL-1,Y1+WTITLE_H-1,0,0);ABox(X1+1,Y1+1,X1+WSCROLL-1,
     Y1+WTITLE_H-1);
   ABox(X1+5,Y1+5,X1+WSCROLL-5,Y1+WTITLE_H-5);
   TX:=X1+WSCROLL;
  End;
  Tw:=X2-1;
  If (K And FULLER_)<>0 Then Begin
   AFill(X2-WSCROLL+1,Y1+1,X2-1,Y1+WTITLE_H-1,0,0);ABox(X2-WSCROLL+1,Y1+1,X2-1,
     Y1+WTITLE_H-1);
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
   If AesTrace And VdiTrace Then Begin
     WriteLn(ConOut,'  info line [',S,']');Flush(ConOut);End;
   OText(X1+6,I+(WINFO_H-8) Div 2-1,Copy(S,1,(R.W-12) Div 8),8,1,False);
  End;
  FastSpan(I+WINFO_H-1,X1,X2,True,False);
 End;
 { barres de defilement }
 If HasVBar(K) Then Begin
  X1:=Wk.X+Wk.W;
  AFill(X1,Wk.Y,X1+WSCROLL-1,Wk.Y+Wk.H+Ord(HasHBar(K))*WSCROLL-1,0,0);
  OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VBar(X1,Wk.Y,X1,Wk.Y+Wk.H-1+
    Ord(HasHBar(K))*WSCROLL);
  Y1:=Wk.Y;Y2:=Wk.Y+Wk.H-1;
  If (K And UPARROW_)<>0 Then Begin
    AArrow(X1+1,Y1,WSCROLL-1,WSCROLL,0);Y1:=Y1+WSCROLL;End;
  If (K And DNARROW_)<>0 Then Begin
    AArrow(X1+1,Y2-WSCROLL+1,WSCROLL-1,WSCROLL,1);Y2:=Y2-WSCROLL;End;
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
   If W^.VSz<=0 Then SlLen:=TrackLen Else SlLen:=Max2(WSCROLL,TrackLen*W^.VSz
     Div 1000);
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
  If (K And LFARROW_)<>0 Then Begin
    AArrow(X1,Y1+1,WSCROLL,WSCROLL-1,2);X1:=X1+WSCROLL;End;
  If (K And RTARROW_)<>0 Then Begin
    AArrow(X2-WSCROLL+1,Y1+1,WSCROLL,WSCROLL-1,3);X2:=X2-WSCROLL;End;
  If (K And HSLIDE_)<>0 Then Begin
   OSetup;
   For I:=X1 To X2 Do Begin
    VP^.FillInt:=2;VP^.FillSty:=4;VP^.FillCol:=1;VBar(I,Y1+1,I,Y1+WSCROLL-1);
   End;
   TrackLen:=X2-X1+1;
   If W^.HSz<=0 Then SlLen:=TrackLen Else SlLen:=Max2(WSCROLL,TrackLen*W^.HSz
     Div 1000);
   SlPos:=(TrackLen-SlLen)*Clamp(W^.HSl,0,1000) Div 1000;
   AFill(X1+SlPos,Y1+1,X1+SlPos+SlLen-1,Y1+WSCROLL-1,0,0);
   ABox(X1+SlPos,Y1+1,X1+SlPos+SlLen-1,Y1+WSCROLL-1);
  End;
 End;
 If ((K And SIZER_)<>0) Then Begin
  X1:=Wk.X+Wk.W;Y1:=Wk.Y+Wk.H;
  If HasVBar(K) And HasHBar(K) Then Begin
   AFill(X1,Y1,X1+WSCROLL-1,Y1+WSCROLL-1,0,0);ABox(X1,Y1,X1+WSCROLL-1,Y1+
     WSCROLL-1);
   ABox(X1+4,Y1+4,X1+WSCROLL-4,Y1+WSCROLL-4);
  End;
 End;
End;

{ Redessine seulement le cadre de la fenetre H (titre, info, barres) dans ses
  zones visibles :
  ni le bureau ni la zone de travail ne sont touches (wind_set des curseurs,
    titre...) }
Procedure RedrawFrame(H: Integer);
Var I,N,SvN,SvPos: Integer; L,Sv: Array[1..64] Of TRect;
Begin
 { l'application peut etre en train de parcourir la liste (wind_get
   FIRST/NEXTXYWH) : on la preserve }
 SvN:=RectN;SvPos:=RectPos;
 For I:=1 To SvN Do Sv[I]:=RectList[I];
 VisibleRects(H,Wins[H].R);
 N:=RectN;
 For I:=1 To N Do L[I]:=RectList[I];
 RectN:=SvN;RectPos:=SvPos;
 For I:=1 To SvN Do RectList[I]:=Sv[I];
 For I:=1 To N Do Begin
  OSetup;SetClip(L[I].X,L[I].Y,L[I].X+L[I].W-1,L[I].Y+L[I].H-1);
  DrawWinFrame(H);
 End;
 SetClip(0,0,SW-1,SH-1);
End;

{ Fond du bureau }
Procedure DrawDesktopRect(X1,Y1,X2,Y2: Integer);
Var X,Y: Integer;
Begin
 OSetup;
 SetClip(X1,Y1,X2,Y2);
 If DeskTree<>0 Then Begin
  ObjDrawRec(DeskTree,DeskStart,8,OX(DeskTree,DeskStart),OY(DeskTree,DeskStart),
    X1,Y1,X2,Y2);
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

{ Livre au programme invite les paquets du clavier intelligent en attente }
Procedure IkDrain;
Var K,L: Integer; V,O0,O1: LongInt;
Begin
 While (IkQN>0) And Not InVex Do Begin
  For K:=0 To 15 Do Wr8(IKBD_PKT+K,IkQPkt[0,K]);
  V:=Rd32(KBDVECS+IkQVec[0]);
  For L:=1 To IkQN-1 Do Begin
   IkQVec[L-1]:=IkQVec[L];IkQLen[L-1]:=IkQLen[L];Move(IkQPkt[L],IkQPkt[L-1],16);
  End;
  Dec(IkQN);
  If (V<>0) And (V<>STUB_RTS) Then Begin
   InVex:=True;
   CallGuestEx(V,0,0,0,IKBD_PKT,O0,O1);
   InVex:=False;
  End;
 End;
End;

{ Enregistrement d'evenements (appl_trecord) : 0 minuterie, 1 bouton, 2 souris,
  3 clavier }
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
       If MsNow-PlayDeadline>=0 Then Begin
         PlayWait:=False;Inc(PlayPos);Continue;End;
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
 { fin : la souris synthetique est liberee apres la prise en compte du dernier
   etat }
 SynthRel:=SynthMouse;PlayMem:=0;
End;

{ Lit clavier et souris hotes ; met a jour l'etat GEM }
Procedure PollInput;
Var NX,NY,NB,T,O0,O1: LongInt; Moved,BtnChg: Boolean;
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
   GMouseX:=Clamp(SExt(O0 And $FFFF,2),0,SW-1);GMouseY:=Clamp(SExt(O1 And
     $FFFF,2),0,SH-1);
  End;
  If UserCursor Then VexCall(VexCur,GMouseX,GMouseY,O0,O1);
 End;
 { clavier intelligent : paquets souris selon le mode (Initmous, Ikbdws) }
 If Moved Or BtnChg Then Begin
  IkMouseEvent(GMouseX,GMouseY,GMouseB,KbdPrevB);
  IkDrain;
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
   If (T-BtnLastTime>=0) And (T-BtnLastTime<LongInt(DClickSpeed)*80) Then
     Inc(ClickCount)
   Else ClickCount:=1;
   BtnLastTime:=T;
  End;
 End;
 PrevB:=GMouseB;
End;

Procedure GemIdle;
Begin
 PollInput;
 IrqNested;      { le processeur ne tourne pas pendant une attente AES : on
   livre les interruptions (MonST) }
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
 TickSysVars;
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
  ObjDrawRec(MenuTree,MenuBar,4,OX(MenuTree,MenuBar)+OX(MenuTree,0),OY(MenuTree,
    MenuBar)+OY(MenuTree,0),
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
 PopScroll : Integer;

Function FindAttach(T: LongInt; Item: Integer): Integer;
Var K: Integer;
Begin
 FindAttach:=0;
 For K:=1 To AttachN Do
  If (AttachTree[K]=T) And (AttachItem[K]=Item) Then Begin
    FindAttach:=K;Exit;End;
End;

Function PopItemFromPoint(T: LongInt; Menu,PX,PY: Integer): Integer;
Var I: Integer;
Begin
 I:=ObjFind(T,Menu,1,PX,PY);
 If (I<=0) Or (I=Menu) Or Not ItemSelectable(T,I) Then I:=-1;
 PopItemFromPoint:=I;
End;

{ Affiche le menu Menu de l'arbre T en (X,Y) ; True si un element est choisi.
  Hover : la souris sortant du menu l'annule (sous-menus de la barre).
  PopScroll (entree) <> 0 : le menu defile s'il a plus d'elements que
  MenuSet[4] (hauteur) ; en sortie PopScroll = premier element visible. }
Function PopupMenu(T: LongInt; Menu,X0,Y0: Integer; Var Item: Integer; Hover:
  Boolean): Boolean;
Var Sv: TScrSave; BoxR,TopRow,BotRow: TRect;
  W,H,H0,X,Y,Ax,Ay,OldX,OldY,Cur,I,K,Sc: Integer;
    Done,Sel,WasDown,Pressed,Opened,SubDone,Scroll: Boolean; Kq: LongInt;
      HoverT,ScrT: LongInt; SubItem: Integer;
    ItY,LMx,LMy: Integer; N,V,F,Rh,ScrollReq,ScrDelay: Integer;
    Ch,SaveY,SaveFl: Array[0..255] Of Integer;
 Procedure Light(I: Integer; On_: Boolean);
 Begin
  If I<0 Then Exit;
  If On_ Then SetOState(T,I,OState(T,I) Or OS_SELECTED)
  Else SetOState(T,I,OState(T,I) And Not OS_SELECTED);
  ObjRedraw(T,I);
 End;
 Function IdxOf(C: Integer): Integer;
 Var J: Integer;
 Begin
  IdxOf:=-1;
  For J:=0 To N-1 Do If Ch[J]=C Then Begin IdxOf:=J;Exit;End;
 End;
 { positions et visibilite des elements selon le premier element visible F }
 Procedure Layout;
 Var J: Integer;
 Begin
  If Not Scroll Then Exit;
  For J:=0 To N-1 Do Begin
   If (J>=F) And (J<F+V) Then Begin
    Wr16(OA(T,Ch[J])+18,((J-F+1)*Rh) And $FFFF);
    Wr16(OA(T,Ch[J])+8,SaveFl[J] And Not OF_HIDETREE);
   End Else Wr16(OA(T,Ch[J])+8,SaveFl[J] Or OF_HIDETREE);
  End;
 End;
 Procedure Arrow(Const R: TRect; Up: Boolean);
 Var J,Cx,Cy: Integer;
 Begin
  Cx:=R.X+R.W Div 2;Cy:=R.Y+R.H Div 2;
  For J:=0 To 4 Do
   If Up Then OFill(Cx-J,Cy-3+J,Cx+J,Cy-3+J,7,1)
   Else OFill(Cx-J,Cy+3-J,Cx+J,Cy+3-J,7,1);
 End;
 Procedure Render;
 Begin
  Layout;
  ObjDrawRec(T,Menu,8,X,Y,X-2,Y-2,X+W+4,Y+H+4);
  OSetup;
  If Scroll Then Begin
   If F>0 Then Arrow(TopRow,True);
   If F<N-V Then Arrow(BotRow,False);
  End;
  OFrameRect(X,Y,X+W-1,Y+H-1,1);
  OFill(X+3,Y+H,X+W+2,Y+H+2,7,1);
  OFill(X+W,Y+3,X+W+2,Y+H-1,7,1);
  SetClip(0,0,SW-1,SH-1);
 End;
 Procedure ScrollTo(NewF: Integer);
 Begin
  NewF:=Clamp(NewF,0,Max2(0,N-V));
  If NewF=F Then Exit;
  If Cur>=0 Then Begin SetOState(T,Cur,OState(T,Cur) And Not
    OS_SELECTED);Cur:=-1;End;
  F:=NewF;ScrT:=MsNow;LMx:=-1;
  Render;
 End;
 Procedure Nav(Dir: Integer);
 Var L: Array[0..255] Of Integer; M,P,C,Idx: Integer;
 Begin
  M:=0;P:=-1;
  For C:=0 To N-1 Do
   If ItemSelectable(T,Ch[C]) Then Begin
    If Ch[C]=Cur Then P:=M;
    L[M]:=Ch[C];Inc(M);
   End;
  If M=0 Then Exit;
  If P<0 Then Begin If Dir>0 Then P:=0 Else P:=M-1;End
  Else P:=(P+Dir+M) Mod M;
  If Cur>=0 Then Light(Cur,False);
  Cur:=L[P];
  If Scroll Then Begin
   Idx:=IdxOf(Cur);
   If Idx<F Then Begin F:=Idx;Render;End
   Else If Idx>=F+V Then Begin F:=Idx-V+1;Render;End;
  End;
  Light(Cur,True);HoverT:=MsNow;
 End;
Begin
 PopupMenu:=False;PopSel:=-1;SubDone:=False;LMx:=-1;LMy:=-1;PopTree:=T;
   PopMenuIdx:=Menu;
 ScrollReq:=PopScroll;PopScroll:=0;
 { liste des elements }
 N:=0;K:=OHead(T,Menu);
 While (K>=0) And (N<256) Do Begin
  Ch[N]:=K;SaveY[N]:=SExt(Rd16(OA(T,K)+18),2);SaveFl[N]:=Rd16(OA(T,K)+8);Inc(N);
  If K=OTail(T,Menu) Then Break;
  K:=ONext(T,K);
 End;
 W:=OW(T,Menu);H0:=OH(T,Menu);H:=H0;
 Scroll:=False;V:=N;F:=0;Rh:=0;
 If N>0 Then Rh:=OH(T,Ch[0]);
 If (ScrollReq<>0) And (Rh>0) Then Begin
  V:=Min2(Clamp(MenuSet[4],3,64),((SH-MenuH-8) Div Rh)-2);
  If V<3 Then V:=3;
  If N>V Then Begin
   Scroll:=True;H:=(V+2)*Rh;
   If Item>0 Then Begin K:=IdxOf(Item);If K>=0 Then F:=Clamp(K-V Div
     2,0,N-V);End;
  End;
 End;
 ScrDelay:=MenuSet[3];If ScrDelay<=0 Then ScrDelay:=50;
 X:=Clamp(X0,0,Max2(0,SW-W-4));Y:=Clamp(Y0,MenuH,Max2(MenuH,SH-H-4));
 OldX:=SExt(Rd16(OA(T,Menu)+16),2);OldY:=SExt(Rd16(OA(T,Menu)+18),2);
 ObjOffset(T,Menu,Ax,Ay);
 Wr16(OA(T,Menu)+16,(OldX+X-Ax) And $FFFF);Wr16(OA(T,Menu)+18,(OldY+Y-Ay) And
   $FFFF);
 If Scroll Then Wr16(OA(T,Menu)+22,H And $FFFF);
 BoxR:=RectMake(X,Y,W,H);
 TopRow:=RectMake(X,Y,W,Rh);BotRow:=RectMake(X,Y+H-Rh,W,Rh);
 ScrSave(X-2,Y-2,X+W+4,Y+H+4,Sv);
 Render;
 Cur:=-1;Done:=False;Sel:=False;WasDown:=(GMouseB And
   1)<>0;Opened:=False;HoverT:=MsNow;ScrT:=MsNow;
 If (Item>0) And (Not Scroll Or ((IdxOf(Item)>=F) And (IdxOf(Item)<F+V))) Then
   Begin Cur:=Item;Light(Cur,True);End;
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
  { defilement : la souris sur la fleche haute ou basse }
  If Scroll And (MsNow-ScrT>=ScrDelay) Then Begin
   If InRect(GMouseX,GMouseY,TopRow) And (F>0) Then ScrollTo(F-1)
   Else If InRect(GMouseX,GMouseY,BotRow) And (F<N-V) Then ScrollTo(F+1);
  End;
  { clavier }
  While Not KQEmpty Do Begin
   Kq:=KQPop;Sc:=(Kq Shr 16) And $FF;
   Case Sc Of
    1: Begin Done:=True;Sel:=False;Cur:=-1;End;
    28,114: If Cur>=0 Then Begin Sel:=True;Done:=True;End;
    72: Nav(-1);
    80: Nav(1);
    73: If Scroll Then ScrollTo(F-V);
    81: If Scroll Then ScrollTo(F+V);
   End;
  End;
  Pressed:=(GMouseB And 1)<>0;
  If Cur>=0 Then Begin
   If (Pressed And Not WasDown) Or ((Not Pressed) And WasDown And
     InRect(GMouseX,GMouseY,BoxR) And
      (Not Hover Or (MsNow-HoverT>150))) Then Begin Sel:=True;Done:=True;End;
  End;
  { sous-menu attache a l'element }
  If (Not Done) And (Cur>=0) Then Begin
   K:=FindAttach(T,Cur);
   If (K>0) And ((MsNow-HoverT>=MenuSet[0]) Or (Pressed And Not WasDown)) Then
     Begin
    ObjOffset(T,Cur,Ax,ItY);
    SubItem:=AttachSubItem[K];
    If PopupMenu(AttachSub[K],AttachBox[K],X+W-3,ItY,SubItem,True) Then Begin
     Sel:=True;Done:=True;SubDone:=True;
    End Else HoverT:=MsNow;
    Pressed:=(GMouseB And 1)<>0;
   End;
  End;
  If Done And Sel And Not SubDone And (Cur>=0) And (FindAttach(T,Cur)>0) Then
    Begin Done:=False;Sel:=False;End;
  If (Not Hover) And (Pressed And Not WasDown) And Not
    InRect(GMouseX,GMouseY,BoxR) Then Begin Done:=True;Sel:=False;End;
  WasDown:=Pressed;
  If Not NoBlit Then BlitScreen(False);
  If Not Done Then Delay(1);
 Until Done Or UserBreak;
 If Cur>=0 Then SetOState(T,Cur,OState(T,Cur) And Not OS_SELECTED);
 ScrRestore(Sv);
 { remet l'arbre dans son etat d'origine }
 If Scroll Then Begin
  For K:=0 To N-1 Do Begin
   Wr16(OA(T,Ch[K])+18,SaveY[K] And $FFFF);Wr16(OA(T,Ch[K])+8,SaveFl[K]);
  End;
  Wr16(OA(T,Menu)+22,H0 And $FFFF);
 End;
 Wr16(OA(T,Menu)+16,OldX And $FFFF);Wr16(OA(T,Menu)+18,OldY And $FFFF);
 If Sel And (Cur>=0) Then Begin
  If Not SubDone Then Begin PopTree:=T;PopSel:=Cur;PopMenuIdx:=Menu;End;
  Item:=PopSel;PopupMenu:=True;
 End Else Begin Item:=-1;End;
 PopScroll:=F;
 If Sel Then Begin While ((GMouseB And 1)<>0) And Not UserBreak Do GemIdle;End;
End;

Procedure MenuTrack;
Var Active,Box,Item,T,I,Screen,Prev: Integer; Sv: TScrSave;
  Saved,Done,Selected,InBar,InBox,WasDown,SubSel: Boolean;
    HoverItem,SubItem,Ak,Ix,Iy: Integer; HoverT: LongInt;
    BoxR: TRect; MXp,MYp: Integer; X,Y: Integer; Target: Integer; Slot,Ac:
      Integer;
 Procedure CloseBox;
 Begin
  If Saved Then Begin ScrRestore(Sv);Saved:=False;End;
  If Item>=0 Then Begin SetOState(MenuTree,Item,OState(MenuTree,Item) And Not
    OS_SELECTED);Item:=-1;End;
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
 Active:=-1;Box:=-1;Item:=-1;Saved:=False;Done:=False;Selected:=False;SubSel:=
   False;HoverItem:=-1;HoverT:=MsNow;
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
     SetOState(MenuTree,Item,OState(MenuTree,Item) And Not
       OS_SELECTED);ObjRedraw(MenuTree,Item);
    End;
    Item:=I;
    If Item>=0 Then Begin
     SetOState(MenuTree,Item,OState(MenuTree,Item) Or
       OS_SELECTED);ObjRedraw(MenuTree,Item);
    End;
   End;
  End;
  If Item<>HoverItem Then Begin HoverItem:=Item;HoverT:=MsNow;End;
  If (Item>=0) And (AttachN>0) Then Begin
   Ak:=FindAttach(MenuTree,Item);
   If (Ak>0) And ((MsNow-HoverT>=MenuSet[0]) Or (((GMouseB And 1)<>0) And Not
     WasDown)) Then Begin
    ObjOffset(MenuTree,Item,Ix,Iy);
    SubItem:=AttachSubItem[Ak];PopScroll:=0;
    If PopupMenu(AttachSub[Ak],AttachBox[Ak],BoxR.X+BoxR.W-3,Iy,SubItem,True)
      Then Begin
     SubSel:=True;Selected:=True;Done:=True;
    End Else Begin HoverT:=MsNow;WasDown:=(GMouseB And 1)<>0;End;
   End;
  End;
  If (Item>=0) And Not Done And (AttachN>0) And (FindAttach(MenuTree,Item)>0)
    Then Begin End
  Else If Item>=0 Then Begin
   If ((GMouseB And 1)<>0) And Not WasDown Then Begin
     Selected:=True;Done:=True;End;
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
   If SubSel Then PostMsg(MenuOwner,MN_SELECTED,Active,PopSel,PopTree Shr
     16,PopTree And $FFFF,PopMenuIdx,0)
   Else PostMsg(MenuOwner,MN_SELECTED,Active,Item,MenuTree Shr 16,MenuTree And
     $FFFF,Box,0);
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
 If Vh=0 Then Begin Den:=Pw-Ow_;If Den<=0 Then SlideBox:=0 Else
   SlideBox:=((Cx-Px)*1000+Den Div 2) Div Den;End
 Else Begin Den:=Ph-Oh_;If Den<=0 Then SlideBox:=0 Else
   SlideBox:=((Cy-Py)*1000+Den Div 2) Div Den;End;
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

{ Bouton de fenetre : inverse tant que le bouton est enfonce ; True si relache
  dedans }
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
 If Was Then Begin
   OSetup;VP^.FillInt:=1;VP^.FillCol:=1;VP^.WrMode:=WM_XOR;VBar(X,Y,X+W-1,Y+
   H-1);End;
 OSetup;
 WatchBoxRect:=Was;
End;

Procedure SliderMsg(H: Integer; Vert: Boolean);
Var W: ^TWin; Wk: TRect; K,X1,Y1,X2,Y2,Track,SlLen,SlPos,Pos0,Off,Sz: Integer;
  Pos: LongInt; Start: Integer;
    Done: Boolean; DX,DY: Integer; NewPos: Integer;
Begin
 W:=@Wins[H];Wk:=WinWork(H);K:=W^.Kind;
 If Vert Then Begin
  Y1:=Wk.Y;Y2:=Wk.Y+Wk.H-1;
  If (K And UPARROW_)<>0 Then Y1:=Y1+WSCROLL;
  If (K And DNARROW_)<>0 Then Y2:=Y2-WSCROLL;
  Track:=Y2-Y1+1;
  If W^.VSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.VSz Div
    1000);
  SlPos:=(Track-SlLen)*Clamp(W^.VSl,0,1000) Div 1000;
  Off:=GMouseY-(Y1+SlPos);
  Start:=GMouseY;
 End Else Begin
  X1:=Wk.X;X2:=Wk.X+Wk.W-1;
  If (K And LFARROW_)<>0 Then X1:=X1+WSCROLL;
  If (K And RTARROW_)<>0 Then X2:=X2-WSCROLL;
  Track:=X2-X1+1;
  If W^.HSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.HSz Div
    1000);
  SlPos:=(Track-SlLen)*Clamp(W^.HSl,0,1000) Div 1000;
  Off:=GMouseX-(X1+SlPos);
 End;
 While ((GMouseB And 1)<>0) And Not UserBreak Do GemIdle;
 If Vert Then Begin
  Pos:=GMouseY-Off-Y1;
  If Track-SlLen>0 Then NewPos:=Clamp(Pos*1000 Div (Track-SlLen),0,1000) Else
    NewPos:=0;
  PostMsg(W^.Owner,WM_VSLID,H,NewPos,0,0,0,0);
 End Else Begin
  Pos:=GMouseX-Off-X1;
  If Track-SlLen>0 Then NewPos:=Clamp(Pos*1000 Div (Track-SlLen),0,1000) Else
    NewPos:=0;
  PostMsg(W^.Owner,WM_HSLID,H,NewPos,0,0,0,0);
 End;
End;

{ Traite un appui sur le bouton gauche ; retourne True si le clic est consomme }
Function ScreenManagerClick: Boolean;
Var H,K,Z: Integer; W: ^TWin; R,Wk: TRect; X,Y,NX,NY,NW,NH,RW,RH: Integer;
  Bound: TRect; Ok: Boolean;
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
 If HasVBar(K) And (X>=Wk.X+Wk.W) And (X<Wk.X+Wk.W+WSCROLL) And (Y>=Wk.Y) And
   (Y<Wk.Y+Wk.H) Then Begin
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
   If W^.VSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.VSz Div
     1000);
   SlPos:=(Track-SlLen)*Clamp(W^.VSl,0,1000) Div 1000;
   If (Y>=Y1+SlPos) And (Y<Y1+SlPos+SlLen) Then SliderMsg(H,True)
   Else If Y<Y1+SlPos Then PostMsg(Own,WM_ARROWED,H,0,0,0,0,0)
   Else PostMsg(Own,WM_ARROWED,H,1,0,0,0,0);
   WaitButtonRelease;
  End;
  Exit;
 End;
 If HasHBar(K) And (Y>=Wk.Y+Wk.H) And (Y<Wk.Y+Wk.H+WSCROLL) And (X>=Wk.X) And
   (X<Wk.X+Wk.W) Then Begin
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
   If W^.HSz<=0 Then SlLen:=Track Else SlLen:=Max2(WSCROLL,Track*W^.HSz Div
     1000);
   SlPos:=(Track-SlLen)*Clamp(W^.HSl,0,1000) Div 1000;
   If (X>=X1+SlPos) And (X<X1+SlPos+SlLen) Then SliderMsg(H,False)
   Else If X<X1+SlPos Then PostMsg(Own,WM_ARROWED,H,4,0,0,0,0)
   Else PostMsg(Own,WM_ARROWED,H,5,0,0,0,0);
   WaitButtonRelease;
  End;
  Exit;
 End;
 { coin de redimensionnement }
 If ((K And SIZER_)<>0) And (X>=R.X+R.W-WSCROLL) And (Y>=R.Y+R.H-WSCROLL) Then
   Begin
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
      VLine(X+16,Y+2,X+2,Y+30);VLine(X+16,Y+2,X+30,Y+30);VLine(X+2,Y+30,X+30,Y+
        30);
      VP^.LineWidth:=1;
      OText(X+12,Y+14,'!',16,1,False);
     End;
  2: Begin
      VP^.FillInt:=0;VP^.FillPer:=1;VArc(X+16,Y+16,15,15,0,3600,
        2);VP^.FillPer:=0;
      OText(X+12,Y+8,'?',16,1,False);
     End;
  3: Begin
      VP^.FillInt:=1;VP^.FillCol:=1;
      PX[0]:=X+10;PY[0]:=Y;PX[1]:=X+22;PY[1]:=Y;PX[2]:=X+32;PY[2]:=Y+
        10;PX[3]:=X+32;PY[3]:=Y+22;
      PX[4]:=X+22;PY[4]:=Y+32;PX[5]:=X+10;PY[5]:=Y+32;PX[6]:=X;PY[6]:=Y+
        22;PX[7]:=X;PY[7]:=Y+10;
      PolyFillPts(8,PX,PY,True);
      OText(X+12,Y+8,'X',16,0,False);
     End;
 End;
End;

Function FormAlert(Def: Integer; Const Txt: String): Integer;
Var Lines: Array[1..6] Of String; Btns: Array[1..4] Of String;
  NL,NB,I,P,Ic,W,H,X0,Y0,BW,TX,BX,Sel,Res: Integer;
    S,Cur: String; Part: Integer; Sv: TScrSave; Done: Boolean; K: LongInt;
      PrevDown: Boolean;
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
        If P=0 Then Begin Lines[NL]:=Cur;Cur:='';End Else Begin
          Lines[NL]:=Copy(Cur,1,P-1);Delete(Cur,1,P);End;
       End;
    3: While (Cur<>'') And (NB<4) Do Begin
        P:=Pos('|',Cur);Inc(NB);
        If P=0 Then Begin Btns[NB]:=Cur;Cur:='';End Else Begin
          Btns[NB]:=Copy(Cur,1,P-1);Delete(Cur,1,P);End;
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
  If I=Def Then OBorder(Rc[I].X,Rc[I].Y,Rc[I].W,Rc[I].H,3,1) Else
    OBorder(Rc[I].X,Rc[I].Y,Rc[I].W,Rc[I].H,1,1);
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
  2,18:
    FormErrorText:='[1][This application cannot find the|fol'+
    'der or file you tried to access.][ OK ]';
  3: FormErrorText:='[1][This application cannot find the|fol'+
    'der you tried to access.][ OK ]';
  4: FormErrorText:='[1][This application has run out of|file handles.][ OK ]';
  5: FormErrorText:='[1][You cannot access this item.][ OK ]';
  8: FormErrorText:='[1][There is not enough memory to|run th'+
    'is application.][ OK ]';
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
  If (Cur>=0) And ((OFlags(T,Cur) And OF_EDITABLE)<>0) And ((OFlags(T,Cur) And
    OF_HIDETREE)=0) Then Begin
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

{ Objet par defaut (OF_DEFAULT) d'un arbre, -1 s'il n'y en a pas }
Function DefaultObj(T: LongInt): Integer;
Var I: Integer;
Begin
 DefaultObj:=-1;
 For I:=0 To 2000 Do Begin
  If ((OFlags(T,I) And OF_DEFAULT)<>0) And ((OFlags(T,I) And OF_HIDETREE)=0)
    Then Begin DefaultObj:=I;Exit;End;
  If (OFlags(T,I) And OF_LASTOB)<>0 Then Break;
 End;
End;

{ form_keybd : traite une touche (scan*256+ascii) dans un formulaire.
  Renvoie 1 pour continuer, 0 si un objet de sortie a ete declenche (Return sur
  l'objet par defaut).  NewObj : nouvel objet d'edition (ou objet de sortie) ;
  KeyOut : touche restant a traiter (0 si consommee) }
Function FormKeybd(T: LongInt; Edit: Integer; Key: LongInt; Var NewObj:
  Integer; Var KeyOut: LongInt): Integer;
Var Asc,Scan,Def,Nx: Integer;
Begin
 Asc:=Key And $FF;Scan:=(Key Shr 8) And $FF;
 NewObj:=Edit;KeyOut:=Key;FormKeybd:=1;
 If (Asc=13) Or (Scan=$1C) Or (Scan=$72) Then Begin
  Def:=DefaultObj(T);
  If (Def>0) And ((OState(T,Def) And OS_DISABLED)=0) Then Begin
   SetOState(T,Def,OState(T,Def) Or OS_SELECTED);ObjRedraw(T,Def);
   NewObj:=Def;KeyOut:=0;FormKeybd:=0;
  End;
  Exit;
 End;
 If (Asc=9) Or ((Asc=0) And (Scan=$50)) Then Begin
  Nx:=NextEditable(T,Edit,1);
  If Nx>0 Then NewObj:=Nx;
  KeyOut:=0;Exit;
 End;
 If (Asc=0) And (Scan=$48) Then Begin
  Nx:=NextEditable(T,Edit,-1);
  If Nx>0 Then NewObj:=Nx;
  KeyOut:=0;Exit;
 End;
End;

{ form_button : traite un clic sur l'objet Obj d'un formulaire (boutons radio,
  cases, objets de sortie).  Renvoie 1 pour continuer, 0 si un objet de sortie
  est declenche ; NextObj : objet (bit 15 = double-clic) }
Function FormButton(T: LongInt; Obj,Clicks: Integer; Var NextObj: Integer):
  Integer;
Var Fl,St,P,Sib: Integer; Inside: Boolean;
Begin
 FormButton:=1;NextObj:=Obj;
 If (Obj<=0) Or ((OState(T,Obj) And OS_DISABLED)<>0) Or ((OFlags(T,Obj) And
   OF_HIDETREE)<>0) Then Exit;
 Fl:=OFlags(T,Obj);
 If (Fl And OF_SELECTABLE)<>0 Then Begin
  If (Fl And OF_RBUTTON)<>0 Then Begin
   If (OState(T,Obj) And OS_SELECTED)=0 Then Begin
    P:=OParent(T,Obj);
    If P>=0 Then Begin
     Sib:=OHead(T,P);
     While Sib>=0 Do Begin
      If (Sib<>Obj) And ((OFlags(T,Sib) And OF_RBUTTON)<>0) And ((OState(T,Sib)
        And OS_SELECTED)<>0) Then Begin
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
    If Not Inside Then SetOState(T,Obj,St) Else SetOState(T,Obj,St Xor
      OS_SELECTED);
    ObjRedraw(T,Obj);
   End;
  End;
 End;
 If ((Fl And OF_EXIT)<>0) Or ((Fl And OF_TOUCHEXIT)<>0) Then Begin
  If ((Fl And OF_SELECTABLE)=0) Or ((OState(T,Obj) And OS_SELECTED)<>0) Or ((Fl
    And OF_TOUCHEXIT)<>0) Then Begin
   If Clicks>=2 Then NextObj:=Obj Or $8000;
   FormButton:=0;
  End;
 End;
End;

Function FormDo(T: LongInt; Start: Integer): Integer;
Var Cur,Idx,Obj,Res,Nx,Cont: Integer; K,Ko: LongInt; Fl: Integer; Done:
  Boolean; PrevDown: Boolean;
    X,Y: Integer;
Begin
 Inc(ModalLevel);
 Cur:=-1;
 If (Start>0) And ((OFlags(T,Start) And OF_EDITABLE)<>0) Then Cur:=Start
 Else Cur:=NextEditable(T,0,1);
 If (Cur=0) Then Cur:=-1;
 If Cur>0 Then ObjEdit(T,Cur,0,Idx,0);
 Done:=False;Res:=0;PrevDown:=True;
 If BatchMode Then Begin
  Res:=DefaultObj(T);If Res<0 Then Res:=0;
  Done:=True;
 End;
 While Not Done And Not UserBreak Do Begin
  GemIdle;
  If Not KQEmpty Then Begin
   K:=KQPop;
   K:=(((K Shr 16) And $FF) Shl 8) Or (K And $FF);
   Cont:=FormKeybd(T,Cur,K,Nx,Ko);
   If Cont=0 Then Begin Res:=Nx;Done:=True;End
   Else Begin
    If (Nx<>Cur) And (Nx>0) Then Begin
     If Cur>0 Then ObjEdit(T,Cur,0,Idx,3);
     Cur:=Nx;ObjEdit(T,Cur,0,Idx,0);
    End;
    If (Ko<>0) And (Cur>0) Then ObjEdit(T,Cur,Ko,Idx,1);
   End;
  End;
  If ((GMouseB And 1)<>0) And Not PrevDown Then Begin
   Obj:=ObjFind(T,0,8,GMouseX,GMouseY);
   If (Obj>0) And ((OState(T,Obj) And OS_DISABLED)=0) Then Begin
    Fl:=OFlags(T,Obj);
    If (Fl And OF_EDITABLE)<>0 Then Begin
     { le curseur d'edition suit le clic }
     If Cur>0 Then ObjEdit(T,Cur,0,Idx,3);
     Cur:=Obj;ObjEdit(T,Cur,0,Idx,0);
     If (Fl And (OF_SELECTABLE Or OF_EXIT Or OF_TOUCHEXIT))=0 Then Begin
      ObjOffset(T,Obj,X,Y);
      Idx:=Clamp((GMouseX-EditCursorX(T,Obj,0)) Div 8,0,Idx);
      ObjRedraw(T,Obj);EditDrawCursor(T,Obj,Idx);
     End;
    End;
    Cont:=FormButton(T,Obj,ClickCount,Nx);
    If Cont=0 Then Begin Res:=Nx;Done:=True;End;
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

{ Selecteur d'objets GEM : travaille dans l'espace de noms TOS (lecteur C:\...)
  }
Procedure FselScan(Const Dir,Mask: String);
Var I,J,K: Integer; D: PDosSrch; T: String[40]; Nd: Integer;
Begin
 FSN:=0;
 If Pos('\',DosVirt(Dir))>0 Then Begin Inc(FSN);FSList[FSN]:='\..';End
 Else If DosVirt(Dir)<>'' Then Begin Inc(FSN);FSList[FSN]:='\..';End;
 K:=DosSearch(Dir+'\*.*',$10);
 If K>=0 Then Begin
  D:=DosSrch[K];
  For I:=1 To D^.N Do
   If ((D^.Ent[I].At And $10)<>0) And (D^.Ent[I].Nm<>'.') And
     (D^.Ent[I].Nm<>'..') And (FSN<FS_MAX) Then Begin
    Inc(FSN);FSList[FSN]:='\'+D^.Ent[I].Nm;
   End;
 End;
 Nd:=FSN;
 K:=DosSearch(Dir+'\'+Mask,0);
 If K>=0 Then Begin
  D:=DosSrch[K];
  For I:=1 To D^.N Do
   If ((D^.Ent[I].At And $10)=0) And (FSN<FS_MAX) Then Begin
    Inc(FSN);FSList[FSN]:=D^.Ent[I].Nm;
   End;
 End;
End;

{ Dir : chemin TOS sans '\' final (ex. C:\DOCS), Msk : masque, Sel : nom choisi
  }
Function DosFileSel(Const Title: String; Var Dr,Dir,Msk,Sel: String): Boolean;
Var Top,Cur,I,X0,Y0,LX,LY,LW,Row,Foc,Nd,P: Integer; E: TEvent;
  Done,Ok,Redraw,Drag: Boolean;
    K,DblT: LongInt; LastIdx: Integer; V: String;
 Function DirStr: String;
 Begin
  V:=DosVirt(Dir);
  If V='' Then DirStr:=Dr+':\' Else DirStr:=Dr+':\'+Upper(V)+'\';
 End;
 Procedure Rescan;
 Begin
  FselScan(Dir,Msk);Top:=1;Cur:=0;
  Nd:=0;
  While (Nd<FSN) And (FSList[Nd+1][1]='\') Do Inc(Nd);
 End;
 Procedure Enter(Const D: String);
 Begin
  If D='\..' Then Dir:='\'+DosVirt(Dir+'\..') Else
    Dir:='\'+DosVirt(Dir+'\'+Copy(D,2,40));
  Sel:='';Rescan;
 End;
 Function ThumbH: Integer;
 Var Tr,H: Integer;
 Begin
  Tr:=FS_ROWS*16-32-1;
  If FSN<=FS_ROWS Then ThumbH:=Tr
  Else Begin H:=(Tr*FS_ROWS) Div FSN;If H<12 Then H:=12;ThumbH:=H;End;
 End;
 Function ThumbTop: Integer;
 Var Tr: Integer;
 Begin
  Tr:=FS_ROWS*16-32-1;
  If FSN<=FS_ROWS Then ThumbTop:=0 Else ThumbTop:=((Top-1)*(Tr-ThumbH)) Div
    (FSN-FS_ROWS);
 End;
 Procedure DrawFS;
 Var R,Idx,Y,Tt,Th: Integer; S: String;
 Begin
  HideMouse;
  GemFrame(X0,Y0,X0+16+62*8-1,Y0+16+19*16-1);
  PText(X0+16,Y0+10,Title);
  PText(X0+16,Y0+30,T3('Directory: ','Repertoire : ','Verzeichnis: ')+
    Copy(DirStr+Msk,1,48));
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
  Th:=ThumbH;Tt:=LY+17+ThumbTop;
  Box(LX+LW+8,Tt,LX+LW+8+16,Tt+Th,PAPER);
  Frame(LX+LW+8,Tt,LX+LW+8+16,Tt+Th);
  PText(LX,LY+FS_ROWS*16+14,T3('Selection: ','Selection : ','Auswahl: '));
  S:=Sel;
  PText(LX+88,LY+FS_ROWS*16+14,S);
  If Foc=1 Then PText(LX+88+Length(S)*8,LY+FS_ROWS*16+14,'_')
  Else Begin
    SetColor(INK);Line(LX+88+Length(S)*8,LY+FS_ROWS*16+23,LX+88+24*8,LY+
    FS_ROWS*16+23);End;
  GButton(LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56,'OK',True,False);
  GButton(LX+16+100,LY+FS_ROWS*16+36,LX+16+100+80,LY+FS_ROWS*16+56,T3('Cancel',
    'Annuler','Abbruch'),False,False);
  ShowMouse;
 End;
 Procedure Accept;
 Var Q: Integer; N2: String;
 Begin
  If (Pos('*',Sel)>0) Or (Pos('?',Sel)>0) Then Begin
    Msk:=Sel;Sel:='';Rescan;Exit;End;
  If Sel='' Then Exit;
  Q:=Length(Sel);
  While (Q>0) And (Sel[Q]<>'\') And (Sel[Q]<>':') Do Dec(Q);
  If Q>0 Then Begin
   N2:=Copy(Sel,1,Q);
   If (Length(N2)>=2) And (N2[2]=':') Then Dr:=Upcase(N2[1]);
   If DosIsDir(N2) Then Dir:='\'+DosVirt(N2) Else Begin Sel:='';Exit;End;
   Sel:=Copy(Sel,Q+1,40);
   Rescan;
   If Sel='' Then Exit;
  End;
  Ok:=True;Done:=True;
 End;
Begin
 DosFileSel:=False;
 X0:=(SCR_W-(16+62*8)) Div 2;Y0:=(SCR_H-(16+19*16)) Div 2;
 Rescan;
 Foc:=1;Done:=False;Ok:=False;LastIdx:=0;DblT:=0;Drag:=False;
 DrawFS;
 Repeat
  PollEvent(E);
  Redraw:=False;
  If E.Kind=1 Then Begin
   Case E.Key Of
    K_ENTER: Begin
              If (Cur>0) And (Sel='') Then Sel:=FSList[Cur];
              If (Sel<>'') And (Sel[1]='\') Then Begin
                Enter(Sel);Redraw:=True;End
              Else Begin Accept;Redraw:=True;End;
             End;
    K_ESC,256+46: Done:=True;
    K_UP: If Cur>1 Then Begin Dec(Cur);Sel:=FSList[Cur];Redraw:=True;End
          Else If Cur=0 Then If FSN>0 Then Begin
            Cur:=1;Sel:=FSList[1];Redraw:=True;End;
    K_DOWN: If Cur<FSN Then Begin Inc(Cur);Sel:=FSList[Cur];Redraw:=True;End;
    K_PGUP: Begin Cur:=Max2(1,Cur-FS_ROWS);If FSN>0 Then
      Sel:=FSList[Cur];Redraw:=True;End;
    K_PGDN: Begin Cur:=Min2(FSN,Cur+FS_ROWS);If FSN>0 Then
      Sel:=FSList[Cur];Redraw:=True;End;
    K_BKSP: If Length(Sel)>0 Then Begin Dec(Sel[0]);Cur:=0;Redraw:=True;End;
    32..255: If E.Key<>K_DEL Then Begin
              If Length(Sel)<40 Then Begin
                Sel:=Sel+Upcase(Chr(E.Key));Cur:=0;Redraw:=True;End;
             End;
   End;
   If (Cur>0) And (Cur<Top) Then Top:=Cur;
   If (Cur>=Top+FS_ROWS) Then Top:=Cur-FS_ROWS+1;
  End Else If E.Kind=3 Then Drag:=False
  Else If (E.Kind=4) And Drag Then Begin
   If FSN>FS_ROWS Then Begin
    I:=1+((E.Y-LY-17-ThumbH Div 2)*(FSN-FS_ROWS)) Div (FS_ROWS*16-32-1-ThumbH);
    Top:=Clamp(I,1,FSN-FS_ROWS+1);Redraw:=True;
   End;
  End Else If E.Kind=2 Then Begin
   LX:=X0+16;LY:=Y0+54;LW:=50*8;
   If InBox(E.X,E.Y,LX,LY,LX+LW,LY+FS_ROWS*16+2) Then Begin
    Row:=(E.Y-LY-2) Div 16;
    I:=Top+Row;
    If (I>=1) And (I<=FSN) Then Begin
     K:=TickCount;
     If (I=LastIdx) And (K-DblT<40) Then Begin
      Sel:=FSList[I];
      If Sel[1]='\' Then Enter(Sel) Else Accept;
     End Else Begin Cur:=I;Sel:=FSList[I];End;
     LastIdx:=I;DblT:=K;
     Redraw:=True;
    End;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY,LX+LW+24,LY+16) Then Begin
    If Top>1 Then Dec(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY+FS_ROWS*16-14,LX+LW+24,LY+FS_ROWS*16+2)
     Then Begin
    If Top+FS_ROWS<=FSN Then Inc(Top);Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+LW+8,LY+17,LX+LW+24,LY+FS_ROWS*16-15) Then Begin
    If (E.Y>=LY+17+ThumbTop) And (E.Y<=LY+17+ThumbTop+ThumbH) Then Drag:=True
    Else If E.Y<LY+17+ThumbTop Then Top:=Max2(1,Top-FS_ROWS)
    Else Top:=Max2(1,Min2(FSN-FS_ROWS+1,Top+FS_ROWS));
    Redraw:=True;
   End Else If InBox(E.X,E.Y,LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56)
     Then Begin Accept;Redraw:=True;End
   Else If InBox(E.X,E.Y,LX+16+100,LY+FS_ROWS*16+36,LX+16+180,LY+FS_ROWS*16+56)
     Then Done:=True;
  End;
  If Redraw And Not Done Then DrawFS;
 Until Done;
 DosFileSel:=Ok;
 NeedDraw:=True;
End;

Function AesFsel(PathAddr,FileAddr: LongInt; Const Title: String): Boolean;
Var Path,Sel,Mask,Dir,Spec,Dr: String; P: Integer; Ok_: Boolean;
Begin
 AesFsel:=False;
 If BatchMode Then Exit;
 Path:=RdStr(PathAddr,120);
 Sel:=Upper(RdStr(FileAddr,14));
 If AesTrace Then Begin
   WriteLn(ConOut,'  fsel_input path=[',Path,'] sel=[',Sel,
   ']');Flush(ConOut);End;
 P:=Length(Path);
 While (P>0) And (Path[P]<>'\') And (Path[P]<>'/') And (Path[P]<>':') Do Dec(P);
 Dir:=Copy(Path,1,P);Mask:=Upper(Copy(Path,P+1,40));
 If Mask='' Then Mask:='*.*';
 Dr:=DosDriveLetter;
 If (Length(Dir)>=2) And (Dir[2]=':') Then Begin
   Dr:=Upcase(Dir[1]);Dir:=Copy(Dir,3,120);End;
 If (Dir<>'') And ((Dir[Length(Dir)]='\') Or (Dir[Length(Dir)]='/')) Then
   Dec(Dir[0]);
 If Dir='' Then Dir:=DosCurPath;
 If Not DosIsDir(Dir+'\') Then Dir:='';
 Dir:='\'+DosVirt(Dir+'\');
 BlitScreen(True);
 HideMouse;
 Ok_:=DosFileSel(Title,Dr,Dir,Mask,Sel);
 BlitScreen(True);
 If Ok_ Then Begin
  Spec:=Dr+':'+Dir;
  If Spec[Length(Spec)]<>'\' Then Spec:=Spec+'\';
  WrStr(PathAddr,Spec+Mask);
  WrStr(FileAddr,Sel);
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
 BvDisk:=3;BvHard:=0;SearchPos:=-1;RscOwned:=False;
 For I:=1 To 6 Do Begin ObjSysV[I,0]:=0;ObjSysV[I,1]:=0;End;
 ObjSysV[6,0]:=1;ObjSysV[6,1]:=1;
 VexTim:=STUB_RTS;VexBut:=STUB_RTS;VexMot:=STUB_RTS;VexCur:=STUB_RTS;VexTimLast
   :=0;InVex:=False;
 KbdPrevX:=-1;KbdPrevY:=-1;KbdPrevB:=0;
 RecActive:=False;RecMem:=0;PlayMem:=0;SynthMouse:=False;SynthRel:=False;
   PlayWait:=False;
 MenuSet[0]:=200;MenuSet[1]:=10000;MenuSet[2]:=250;MenuSet[3]:=0;MenuSet[4]:=16;
   AttachN:=0;IStartN:=0;
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
    SetOState(MenuTree,AccSlots[K],OState(MenuTree,AccSlots[K]) And Not
      OS_DISABLED);
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
 KeyOwnerWants:=Procs[P].Used And Procs[P].Blocked And ((Procs[P].WFlags And
   1)<>0);
End;

{ processus qui recoit les touches }
Function KeyOwner: Integer;
Var H,I: Integer;
Begin
 KeyOwner:=-1;
 H:=TopWin;
 If (H>0) And KeyOwnerWants(Wins[H].Owner) Then Begin
   KeyOwner:=Wins[H].Owner;Exit;End;
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
Var Pr: ^TProc; Fl,Got,Cl: Integer; Io,Ai: LongInt; K: LongInt; Inside:
  Boolean; Now: LongInt;
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
  If (Fl And 256)<>0 Then Got:=Got Or 256;
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
      Else If (MsNow-BtnLastTime>LongInt(DClickSpeed)*80) Or ((GMouseB And
        Pr^.WMask)<>Pr^.WState) Then Begin
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
  If (Fl And 256)<>0 Then Got:=Got Or 256;
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
  17: Out(0,1);
  15: Begin Out(0,RecPos);RecActive:=False;RecMem:=0;End;
 Else Begin
   Out(0,Got);Out(1,GMouseX);Out(2,GMouseY);Out(3,Btn);Out(4,0);Out(5,
     KeyV);Out(6,Cl);
  End;
 End;
End;

Procedure ScreenManager;
Var Down: Boolean;
Begin
 If BatchMode Then Exit;
 If AesTrace And ((GMouseX<>PrevDbgX) Or (GMouseY<>PrevDbgY)) Then Begin
  PrevDbgX:=GMouseX;PrevDbgY:=GMouseY;
  WriteLn(ConOut,'MOUSE ',GMouseX,' ',GMouseY,' b=',GMouseB,' menuH=',MenuH,
    ' tree=',Hex8(MenuTree),' title=',MouseOnTitle);Flush(ConOut);
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
   IrqNested;     { interruptions (MonST : commutation d'ecran temporisee)
     pendant l'attente }
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
 { WF_TOP : le numero de fenetre passe est ignore (les applications passent
   n'importe quoi) }
 If Fld=10 Then Begin
  Wr16(Io+2,TopWin);If TopWin>0 Then Wr16(Io+4,Wins[TopWin].Owner) Else
    Wr16(Io+4,0);
  Exit;
 End;
 If (H<0) Or (H>=MAXWIN) Then Begin Wr16(Io,0);Exit;End;
 W:=@Wins[H];
 If H=0 Then Begin
  Case Fld Of
   4,5,7,17: SetR(RectMake(0,MenuH,SW,SH-MenuH));
   10: Begin Wr16(Io+2,TopWin);If TopWin>0 Then Wr16(Io+4,Wins[TopWin].Owner)
     Else Wr16(Io+4,0);End;
   14: Begin Wr16(Io+2,DeskTree Shr 16);Wr16(Io+4,DeskTree And
     $FFFF);Wr16(Io+6,DeskStart);End;
  End;
  If Fld=11 Then Begin
   VisibleRects(0,RectMake(0,MenuH,SW,SH-MenuH));
   If RectN>0 Then Begin SetR(RectList[1]);RectPos:=2;End Else Begin
     SetR(RectMake(0,0,0,0));End;
  End Else If Fld=12 Then Begin
   If RectPos<=RectN Then Begin SetR(RectList[RectPos]);Inc(RectPos);End Else
     SetR(RectMake(0,0,0,0));
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
  10: Begin Wr16(Io+2,TopWin);If TopWin>0 Then
    Wr16(Io+4,Wins[TopWin].Owner);End;
  11: Begin
       R:=WinWork(H);
       VisibleRects(H,R);
       If RectN>0 Then Begin SetR(RectList[1]);RectPos:=2;End Else
         SetR(RectMake(0,0,0,0));
      End;
  12: Begin
       If RectPos<=RectN Then Begin SetR(RectList[RectPos]);Inc(RectPos);End
         Else SetR(RectMake(0,0,0,0));
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
  2: Begin W^.Name:=(LongInt(Rd16(Ii+4)) Shl 16) Or Rd16(Ii+6);If W^.Open Then
    RedrawFrame(H);End;
  3: Begin W^.Info:=(LongInt(Rd16(Ii+4)) Shl 16) Or Rd16(Ii+6);If AesTrace Then
    Begin
    WriteLn(ConOut,'  wind_set INFO [',RdStr(W^.Info,100),
    ']');Flush(ConOut);End;If W^.Open Then RedrawFrame(H);End;
  5: Begin
      R:=RectMake(I(2),I(3),I(4),I(5));
      If R.W<80 Then R.W:=80;If R.H<60 Then R.H:=60;
      If R.Y<MenuH Then R.Y:=MenuH;
      WinSetRect(H,R);
     End;
  7: W^.Full:=RectMake(I(2),I(3),I(4),I(5));
  8: Begin W^.HSl:=Clamp(I(2),0,1000);If W^.Open Then RedrawFrame(H);End;
  9: Begin W^.VSl:=Clamp(I(2),0,1000);If W^.Open Then RedrawFrame(H);End;
  10: WinTop(H);
  15: Begin W^.HSz:=I(2);If W^.Open Then RedrawFrame(H);End;
  16: Begin W^.VSz:=I(2);If W^.Open Then RedrawFrame(H);End;
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
  If (Upper(Copy(SR.Name,1,6))='SCRAP.') And ((SR.Attr And Directory)=0) Then
    Begin
   {$I-}
   Assign(Ef,D+HostSep+SR.Name);Erase(Ef);
   {$I+}
   If IOResult<>0 Then Begin End;
  End;
  FindNext(SR);
 End;
 {$IFDEF FPC}FindClose(SR);{$ENDIF}
End;

{ cherche une variable d'environnement invite (bloc ENV_BLK) ; renvoie
  l'adresse de la valeur }
Function EnvLookup(Const Name: String): LongInt;
Var A,B: LongInt; S: String;
Begin
 EnvLookup:=0;
 A:=ENV_BLK;
 While (Rd8(A)<>0) And (A<ENV_BLK+ENV_SIZE-2) Do Begin
  S:=RdStr(A,120);
  B:=A+Length(S)+1;
  If (Pos('=',Name)>0) And (Upper(Copy(S,1,Length(Name)))=Upper(Name)) Then
    Begin
   EnvLookup:=A+Length(Name);Exit;
  End;
  If (Pos('=',Name)=0) And (Upper(Copy(S,1,Length(Name)+1))=Upper(Name)+'=')
    Then Begin
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
 For K:=1 To IStartN Do If (IStartTree[K]=T) And (IStartMenu[K]=Menu) Then
   IStartFind:=K;
End;

Function NProcsUsed: Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=0 To MAXPROC-1 Do If Procs[I].Used Then Inc(N);
 NProcsUsed:=N;
End;

Procedure Aes(Pb: LongInt);
Var Ctl,Glb,Ii,Io,Ai,Ao: LongInt; Op,I,J,K,H: Integer; S: String; T: LongInt;
  R,R2: TRect;
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
 Ctl:=Rd32(Pb);Glb:=Rd32(Pb+4);Ii:=Rd32(Pb+8);Io:=Rd32(Pb+12);Ai:=Rd32(Pb+
   16);Ao:=Rd32(Pb+20);
 Op:=Rd16(Ctl);
 OV(0,1);
 If AesTrace Then Begin
  Write(ConOut,'AES ',Op,' [');
  For I:=0 To 7 Do Write(ConOut,SExt(Rd16(Ii+I*2),2),' ');
  WriteLn(ConOut,'] a0=',Hex8(Rd32(Ai)),' pc=',Hex8(PC));
  Flush(ConOut);
 End;
 Case Op Of
  10: Begin
       If Not Procs[CurProc].Used Then Begin
        K:=NewProc(ProgName,False);If K>=0 Then CurProc:=K;
       End;
       If Procs[CurProc].Fresh Then Begin
        { premier appl_init d'un fils de Pexec : il remplace la barre de menus
          et le bureau }
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
        PostMsg(K,Rd16(A),Rd16(A+6),Rd16(A+8),Rd16(A+10),Rd16(A+12),Rd16(A+14),
          CurProc);
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
        PlayMem:=A;PlayCnt:=Cl;PlayPos:=0;PlayScale:=Max2(1,
          IV(1));PlayWait:=False;
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
  16: Begin
       { appl_bvset : unites disponibles pour le selecteur de fichiers }
       BvDisk:=Rd16(Ii) Or (LongInt(Rd16(Ii+2)) Shl 16);
       BvHard:=Rd16(Ii+4) Or (LongInt(Rd16(Ii+6)) Shl 16);
       OV(0,1);
      End;
  17: Wait(256);
  18: Begin
       { appl_search(mode,nom,type,id) : parcourt les applications }
       K:=IV(0);
       If K=2 Then Begin OV(0,0);End
       Else Begin
        If K=0 Then SearchPos:=-1;
        J:=-1;
        For I:=SearchPos+1 To MAXPROC-1 Do
         If Procs[I].Used And (J<0) Then J:=I;
        If J<0 Then Begin SearchPos:=-1;OV(0,0);End
        Else Begin
         SearchPos:=J;
         S:=Procs[J].Name;
         While Length(S)<8 Do S:=S+' ';
         WrStr(AI_(0),S);
         If Procs[J].IsAcc Then OV(1,4) Else OV(1,2);
         OV(2,J);OV(0,1);
        End;
       End;
      End;
  19: OV(0,1);
  20: Wait(1);
  21: Begin
       Wait(2);
       Procs[CurProc].WClicks:=IV(0);Procs[CurProc].WMask:=IV(1);Procs[CurProc].
         WState:=IV(2);
      End;
  22: Begin
       Wait(Ord(IV(0)=0)*4+Ord(IV(0)<>0)*4);
       Procs[CurProc].WM1F:=IV(0);Procs[CurProc].WM1:=RectMake(IV(1),IV(2),
         IV(3),IV(4));
      End;
  23: Wait(16);
  24: Begin
       Wait(32);
       Procs[CurProc].WDeadline:=MsNow+((LongInt(Rd16(Ii+2)) Shl 16) Or
         Rd16(Ii));
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
            If MenuTree<>0 Then Begin
              MenuTree:=0;Repaint(RectMake(0,0,SW,MenuH),True);End;
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
       If IV(1)<>0 Then SetOState(T,I,OState(T,I) Or OS_CHECKED) Else
         SetOState(T,I,OState(T,I) And Not OS_CHECKED);
       OV(0,1);
      End;
  32: Begin
       T:=AI_(0);I:=IV(0);
       If IV(1)<>0 Then SetOState(T,I,OState(T,I) And Not OS_DISABLED) Else
         SetOState(T,I,OState(T,I) Or OS_DISABLED);
       OV(0,1);
      End;
  33: Begin
       T:=AI_(0);I:=IV(0);
       If IV(1)<>0 Then SetOState(T,I,OState(T,I) And Not OS_SELECTED) Else
         SetOState(T,I,OState(T,I) Or OS_SELECTED);
       If T=MenuTree Then Begin DrawMenuBarNow;If Not BatchMode Then
         BlitScreen(False);End;
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
        PopScroll:=SExt(Rd16(A+8),2);
        If PopupMenu(T,I,IV(0),IV(1),K,False) Then Begin
         If B<>0 Then CopyMenuStruct(B,PopTree,PopMenuIdx,PopSel,PopScroll);
         OV(0,1);
        End Else Begin
         If B<>0 Then CopyMenuStruct(B,T,I,-1,PopScroll);
         OV(0,0);
        End;
       End Else Begin
        { menu_unregister }
        K:=IV(0);
        If K=-1 Then K:=Procs[CurProc].MenuId;
        If (K>=0) And (K<=5) Then Begin
         AccProc[K]:=-1;AccStr[K]:=0;
         If (MenuTree<>0) And (AccSlots[K]>=0) Then
          SetOState(MenuTree,AccSlots[K],OState(MenuTree,AccSlots[K]) Or
            OS_DISABLED);
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
            CopyMenuStruct(B,AttachSub[J],AttachBox[J],AttachSubItem[J],0);OV(0,
              1);
           End;
        1: If B=0 Then Begin
            If J>0 Then Begin
             AttachTree[J]:=AttachTree[AttachN];AttachItem[J]:=AttachItem[
               AttachN];AttachSub[J]:=AttachSub[AttachN];
             AttachBox[J]:=AttachBox[AttachN];AttachSubItem[J]:=AttachSubItem[
               AttachN];Dec(AttachN);
            End;
            OV(0,1);
           End Else Begin
            If J=0 Then Begin
             If AttachN<16 Then Begin Inc(AttachN);J:=AttachN;End;
            End;
            If J>0 Then Begin
             AttachTree[J]:=T;AttachItem[J]:=I;AttachSub[J]:=Rd32(B);
             AttachBox[J]:=SExt(Rd16(B+4),2);AttachSubItem[J]:=SExt(Rd16(B+6),
               2);
             OV(0,1);
            End;
           End;
        2: If J>0 Then Begin
            AttachTree[J]:=AttachTree[AttachN];AttachItem[J]:=AttachItem[AttachN
              ];AttachSub[J]:=AttachSub[AttachN];
            AttachBox[J]:=AttachBox[AttachN];AttachSubItem[J]:=AttachSubItem[
              AttachN];Dec(AttachN);
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
        If J=0 Then Begin If IStartN<16 Then Begin
          Inc(IStartN);J:=IStartN;End;End;
        If J>0 Then Begin
          IStartTree[J]:=T;IStartMenu[J]:=I;IStartItem[J]:=IV(2);OV(0,
          IV(2));End Else OV(0,0);
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
       If AesTrace And VdiTrace Then Begin
        For I:=0 To 40 Do Begin
         WriteLn(ConOut,'  obj ',I,' nx=',OA(AI_(0),I)-AI_(0),' ty=',
           OType(AI_(0),I),' fl=',OFlags(AI_(0),I),' st=',OState(AI_(0),I),
           ' sp=',Hex8(OSpec(AI_(0),I)),' ',OX(AI_(0),I),',',OY(AI_(0),I),' ',
           OW(AI_(0),I),'x',OH(AI_(0),I),' nxt=',ONext(AI_(0),I),' hd=',
           OHead(AI_(0),I),' tl=',OTail(AI_(0),I));
         If (OFlags(AI_(0),I) And 32)<>0 Then Break;
        End;
        Flush(ConOut);
       End;
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
  48: Begin
       { objc_sysvar(mode,quoi,val1,val2) }
       K:=IV(1);
       If (K<1) Or (K>6) Then OV(0,0)
       Else Begin
        If IV(0)=1 Then Begin ObjSysV[K,0]:=IV(2);ObjSysV[K,1]:=IV(3);End;
        OV(0,1);OV(1,ObjSysV[K,0]);OV(2,ObjSysV[K,1]);
       End;
      End;
  50: OV(0,FormDo(AI_(0),IV(0)));
  51: Begin
       Case IV(0) Of
        0: Begin End;
        1: GrowShrink(RectMake(IV(1),IV(2),IV(3),IV(4)),RectMake(IV(5),IV(6),
          IV(7),IV(8)));
        2: GrowShrink(RectMake(IV(5),IV(6),IV(7),IV(8)),RectMake(IV(1),IV(2),
          IV(3),IV(4)));
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
  55: Begin
       { form_keybd(arbre,objet,touche,suivant) }
       Fl:=FormKeybd(AI_(0),IV(0),LongInt(IV(1)) And $FFFF,I,T);
       OV(0,Fl);OV(1,I);OV(2,T And $FFFF);
      End;
  56: Begin
       { form_button(arbre,objet,clics) }
       Fl:=FormButton(AI_(0),IV(0),IV(1),I);
       OV(0,Fl);OV(1,I);
      End;
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
  72: Begin
    GrowShrink(RectMake(IV(0),IV(1),IV(2),IV(3)),RectMake(IV(4),IV(5),IV(2),
    IV(3)));OV(0,1);End;
  73: Begin
    GrowShrink(RectMake(IV(0),IV(1),IV(2),IV(3)),RectMake(IV(4),IV(5),IV(6),
    IV(7)));OV(0,1);End;
  74: Begin
    GrowShrink(RectMake(IV(4),IV(5),IV(6),IV(7)),RectMake(IV(0),IV(1),IV(2),
    IV(3)));OV(0,1);End;
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
        255: ApplyMouseForm(AI_(0));
       Else SetMouseShape(K);
       End;
       {$IFDEF FPC}
       If GfxOn Then Begin If MouseHidden>0 Then HideMouse Else
         CursorDraw(MX,MY);End;
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
       S:=T3('Item Selector','Selecteur d''objets','Objektauswahl');
       If Op=91 Then S:=RdStr(AI_(2),40);
       If AesFsel(AI_(0),AI_(1),S) Then Begin OV(0,1);OV(1,1);End Else Begin
         OV(0,1);OV(1,0);End;
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
        If AesTrace Then Begin
          WriteLn(ConOut,'rsrc_load [',S,'] ',Hex8(AI_(0)));Flush(ConOut);End;
        If RscLoad(S) Then Begin
         OV(0,1);
         Wr32(Glb+10,RscBase+Rd16(RscBase+18));
        End Else OV(0,0);
       End;
  111: Begin
        If RscLoaded And RscOwned Then DoMfree(RscBase);
        RscLoaded:=False;RscOwned:=False;OV(0,1);
       End;
  112: Begin
        If RscGaddr(IV(0),IV(1),A) Then Begin Wr32(Ao,A);OV(0,1);End Else Begin
          Wr32(Ao,0);OV(0,0);End;
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
  115: Begin
        { rsrc_rcfix : ressource deja en memoire }
        A:=AI_(0);
        If A=0 Then OV(0,0)
        Else Begin
         RscFixup(A);
         RscBase:=A;RscLoaded:=True;RscOwned:=False;
         Wr32(Glb+10,A+Rd16(A+18));
         OV(0,1);
        End;
       End;
  { ---- shell ---- }
  130: Begin
        { appl_getinfo(type) : renseignements sur l'AES }
        OV(0,1);OV(1,0);OV(2,0);OV(3,0);OV(4,0);
        Case IV(0) Of
         0: Begin OV(1,10);OV(2,1);OV(3,0);End;       { grande police : 10
           points, systeme }
         1: Begin OV(1,8);OV(2,1);OV(3,0);End;        { petite police : 8
           points }
         2: Begin OV(1,2);OV(2,0);OV(3,0);End;        { nombre de couleurs }
         3: Begin
             If Lang=0 Then OV(1,0) Else If Lang=2 Then OV(1,1) Else OV(1,2);
            End;
         4: Begin OV(1,0);OV(2,1);OV(3,1);OV(4,1);End; { coop., appl_find,
           appl_search, rsrc_rcfix }
         5: Begin OV(1,0);OV(2,0);OV(3,0);OV(4,1);End; { shel_rdef/wdef }
         6: OV(1,13);                                  { dernier type connu }
         7: Begin OV(1,1);OV(2,0);OV(3,0);OV(4,0);End; { formes de souris
           utilisateur }
         8: Begin OV(1,1);OV(2,1);OV(3,1);OV(4,1);End; { popup, attach, istart,
           settings }
         9: Begin OV(1,0);OV(2,0);OV(3,0);OV(4,0);End;
         10: Begin OV(1,$FFF);OV(2,0);OV(3,0);OV(4,0);End;
         11: Begin OV(1,$FFF);OV(2,0);OV(3,0);OV(4,0);End;
         12: Begin OV(1,0);OV(2,0);OV(3,0);OV(4,0);End; { pas d'objets 3D }
         13: Begin OV(1,0);OV(2,0);OV(3,0);OV(4,0);End;
        Else OV(0,0);
        End;
       End;
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
        If FileExists(TosPath(S)) Or FileExists(TosPath(ShortName(S))) Or
          FileExists(HostPath(S)) Then OV(0,1) Else OV(0,0);
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
  RscOk,RscOwn : Boolean;
  PName,PCmd : String;
  Child : Integer;
 End;

{ Cree le processus AES du fils : il aura son propre ap_id, sa propre barre de
  menus, ses fenetres et son fichier ressource ; le contexte du pere est
  sauvegarde et restitue a la fin }
Procedure GemChildEnter(Var S: TGemSave; Const Name,Cmd: String);
Var K: Integer;
Begin
 S.Proc:=CurProc;S.MTree:=MenuTree;S.DTree:=DeskTree;S.MOwner:=MenuOwner;S.MBar
   :=MenuBar;
 S.MH:=MenuH;S.DStart:=DeskStart;S.Rsc:=RscBase;S.RscOk:=RscLoaded;S.RscOwn:=
   RscOwned;S.PName:=ProgName;S.PCmd:=ProgCmd;
 S.Child:=-1;
 If Name<>'' Then ProgName:=Name;
 ProgCmd:=Cmd;
 RscLoaded:=False;
 If Emu_GEM And AesActive Then Begin
  K:=NewProc(ProgName,False);
  If K>=0 Then Begin
   Procs[K].Started:=True;
   S.Child:=K;CurProc:=K;
   { la barre de menus et le bureau du pere ne sont retires qu'au appl_init du
     fils }
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
  For I:=2 To MAXVWK Do If Vd[I].Used And (Vd[I].Owner=K) Then
    Vd[I].Used:=False;
  For I:=0 To 5 Do
   If AccProc[I]=K Then Begin AccProc[I]:=-1;AccStr[I]:=0;End;
  If MCtrlOwner=K Then Begin MCtrlLevel:=0;MCtrlOwner:=-1;End;
  If MenuOwner=K Then MenuTree:=0;
  Procs[K].Used:=False;Procs[K].Blocked:=False;
  If LastRun=K Then LastRun:=S.Proc;
 End;
 If RscLoaded Then Begin
  If (RscBase<>S.Rsc) And RscOwned Then DoMfree(RscBase);
 End;
 RscBase:=S.Rsc;RscLoaded:=S.RscOk;RscOwned:=S.RscOwn;
 CurProc:=S.Proc;
 MenuTree:=S.MTree;DeskTree:=S.DTree;MenuOwner:=S.MOwner;MenuBar:=S.MBar;MenuH:=
   S.MH;DeskStart:=S.DStart;
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
      Else If (Rg[0] And $FFFF)=$73 Then Begin
        VdiOwnerProc:=CurProc;Vdi(Rg[1]);End
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

{ Polices systeme au format TOS (en-tete de 88 octets + forme), pour Line-A
  $A000 : tableau de
  3 pointeurs (6x6, 8x8, 8x16) retourne en A1.  Les glyphes viennent de la
    table Font8. }
Const
 LA_FONTS = $9000;          { tableau de pointeurs }
 LA_FH    = $9010;          { 3 en-tetes de 88 octets }
 LA_F8DAT = $9400;          { forme 8x8  : 256 x 8  octets }
 LA_F16DAT= $9C00;          { forme 8x16 : 256 x 16 octets }

Procedure LineAFontHeader(A: LongInt; Id,Pt: Integer; Const Nm: String;
  Top,Asc,Half,Desc,Bot,CellH: Integer; Dat: LongInt);
Var I: Integer;
Begin
 For I:=0 To 87 Do Wr8(A+I,0);
 Wr16(A,Id);Wr16(A+2,Pt);
 For I:=1 To Length(Nm) Do If I<=31 Then Wr8(A+3+I,Ord(Nm[I]));
 Wr16(A+36,0);Wr16(A+38,255);
 Wr16(A+40,Top);Wr16(A+42,Asc);Wr16(A+44,Half);Wr16(A+46,Desc);Wr16(A+48,Bot);
 Wr16(A+50,8);Wr16(A+52,8);
 Wr16(A+58,1);Wr16(A+60,1);
 Wr16(A+62,$5555);Wr16(A+64,$5555);
 Wr16(A+66,$0001 Or $0008);        { police systeme, a chasse fixe }
 Wr32(A+68,0);Wr32(A+72,LA_F8DAT-$200+0);  { off_table : renseignee plus bas }
 Wr32(A+76,Dat);Wr16(A+80,256);Wr16(A+82,CellH);Wr32(A+84,0);
End;

Procedure LineAFonts;
Var C,R: Integer; B: Byte;
Begin
 CheckFonts;
 For C:=0 To 255 Do
  For R:=0 To 7 Do Begin
   B:=Font8[C,R];
   Wr8(LA_F8DAT+LongInt(R)*256+C,B);
   Wr8(LA_F16DAT+LongInt(R*2)*256+C,B);
   Wr8(LA_F16DAT+LongInt(R*2+1)*256+C,B);
  End;
 { table des decalages : caractere c a l'abscisse 8*c (257 mots) }
 For C:=0 To 256 Do Wr16(LA_FONTS+$120+C*2,C*8);
 LineAFontHeader(LA_FH,1,4,'6x6 system font',5,5,3,1,1,8,LA_F8DAT);
 LineAFontHeader(LA_FH+88,1,9,'8x8 system font',6,6,4,1,1,8,LA_F8DAT);
 LineAFontHeader(LA_FH+176,1,10,'8x16 system font',12,12,8,3,3,16,LA_F16DAT);
 For C:=0 To 2 Do Begin
  Wr32(LA_FH+C*88+72,LA_FONTS+$120);
  Wr32(LA_FONTS+C*4,LA_FH+C*88);
 End;
 Wr32(LA_FH+84,LA_FH+88);Wr32(LA_FH+88+84,LA_FH+176);
End;

Procedure LineAInit;
Var I: Integer;
Begin
 For I:=0 To 130 Do Wr8(LINEA_VARS+I,0);
 For I:=1 To $2F Do Wr8(LINEA_VARS-I,0);
 Wr16(LINEA_VARS,1);Wr16(LINEA_VARS+2,80);
 Wr32(LINEA_VARS+4,LA_CONTRL);Wr32(LINEA_VARS+8,LA_INTIN);Wr32(LINEA_VARS+12,
   LA_PTSIN);
 Wr32(LINEA_VARS+16,LA_INTIN+$40);Wr32(LINEA_VARS+20,LA_PTSIN+$40);
 Wr16(LINEA_VARS+24,1);Wr16(LINEA_VARS+34,$FFFF);Wr16(LINEA_VARS+36,0);
 Wr16(LINEA_VARS+56,0);Wr16(LINEA_VARS+58,0);Wr16(LINEA_VARS+60,
   639);Wr16(LINEA_VARS+62,399);
 LineAFonts;
 { police courante : 8x16 ; texte : premier plan 1, fond 0 }
 Wr32(LINEA_VARS+84,LA_F16DAT);Wr16(LINEA_VARS+88,256);
 Wr16(LINEA_VARS+106,1);Wr16(LINEA_VARS+114,0);
 { variables a decalage negatif (V_CEL_HT ... BYTES_LIN) }
 Wr16(LINEA_VARS-$2E,16);Wr16(LINEA_VARS-$2C,79);Wr16(LINEA_VARS-$2A,24);Wr16(LINEA_VARS-$28,1280);
 Wr16(LINEA_VARS-$26,0);Wr16(LINEA_VARS-$24,1);Wr32(LINEA_VARS-$22,DrawBase);
 Wr32(LINEA_VARS-$16,LA_F16DAT);Wr16(LINEA_VARS-$12,255);Wr16(LINEA_VARS-$10,0);Wr16(LINEA_VARS-$E,256);
 Wr16(LINEA_VARS-$C,640);Wr32(LINEA_VARS-$A,LA_FONTS+$120);Wr16(LINEA_VARS-4,400);Wr16(LINEA_VARS-2,80);
 Rg[0]:=LINEA_VARS;Rg[8]:=LINEA_VARS;
 Rg[9]:=LA_FONTS;Rg[10]:=LINEA_VARS+$200;
End;

{ ---------------------------------------------------------------------- }
{ Ligne A : primitives (pixel, ligne, rectangle, polygone, BITBLT, TEXTBLT   }
{ avec tous les effets, lutins, copie raster, remplissage par germe)        }
{ ---------------------------------------------------------------------- }

Var LaXor: Boolean;

Procedure LaOPlot(X,Y: LongInt; C: Integer);
Begin
 If (X<0) Or (X>=640) Or (Y<0) Or (Y>=400) Then Exit;
 If LaXor Then Begin If C<>0 Then BPix(X,Y,Not BGet(X,Y));End
 Else BPix(X,Y,C<>0);
End;

Function LaOGet(X,Y: LongInt): Integer;
Begin
 LaOGet:=Ord(BGet(X,Y));
End;

Function LaRop(Op,S,D: LongInt): LongInt;
Begin
 LaRop:=Ord(RopBit(Op,S<>0,D<>0));
End;

Function LaW(Off: Integer): Integer;
Begin LaW:=SmallInt(Rd16(LINEA_VARS+Off)); End;

Function LaClip(X,Y: LongInt): Boolean;
{ True si le point est visible (rectangle d'ecran et fenetre de clipping) }
Begin
 LaClip:=False;
 If (X<0) Or (Y<0) Or (X>639) Or (Y>399) Then Exit;
 If LaW(54)<>0 Then
  If (X<LaW(56)) Or (Y<LaW(58)) Or (X>LaW(60)) Or (Y>LaW(62)) Then Exit;
 LaClip:=True;
End;

{ pixel selon le mode d'ecriture (0 remplace, 1 transparent, 2 xor, 3 transparent inverse) ;
  Fg : le pixel fait partie du motif ; Col : couleur du premier plan }
Procedure LaPix(X,Y: LongInt; Fg: Boolean; Col: Integer);
Var C: Byte;
Begin
 If Not LaClip(X,Y) Then Exit;
 If (Col And 1)<>0 Then C:=1 Else C:=0;
 Case LaW(36) Of
  1: If Fg Then LaOPlot(X,Y,C);
  2: If Fg And (C<>0) Then Begin LaXor:=True;LaOPlot(X,Y,1);LaXor:=False;End;
  3: If Not Fg Then LaOPlot(X,Y,C);
 Else
  If Fg Then LaOPlot(X,Y,C) Else LaOPlot(X,Y,0);
 End;
End;

Procedure LaPut(X,Y: LongInt; C: Integer);
Begin
 LaPix(X,Y,True,C);
End;

{ bit du motif de remplissage en (X,Y) }
Function LaPat(X,Y: LongInt): Boolean;
Var P: LongInt; W: Word; M: Integer;
Begin
 P:=Rd32(LINEA_VARS+46);
 If P=0 Then Begin LaPat:=True;Exit;End;
 M:=LaW(50);
 W:=Rd16(P+2*(Y And M));
 LaPat:=((W Shr (15-(X And 15))) And 1)<>0;
End;

Procedure LaHLine(X1,X2,Y: LongInt);
Var X,T: LongInt;
Begin
 If X1>X2 Then Begin T:=X1;X1:=X2;X2:=T;End;
 For X:=X1 To X2 Do LaPix(X,Y,LaPat(X,Y),LaW(24));
End;

Procedure LaLine(X1,Y1,X2,Y2: LongInt);
Var DX,DY,SX,SY,Err,E2,N: LongInt; Mask: Word;
Begin
 Mask:=Word(LaW(34));
 DX:=Abs(X2-X1);DY:=Abs(Y2-Y1);
 If X1<X2 Then SX:=1 Else SX:=-1;
 If Y1<Y2 Then SY:=1 Else SY:=-1;
 Err:=DX-DY;N:=0;
 Repeat
  LaPix(X1,Y1,((Mask Shr (15-(N And 15))) And 1)<>0,LaW(24));
  Inc(N);
  If (X1=X2) And (Y1=Y2) Then Break;
  E2:=2*Err;
  If E2>-DY Then Begin Err:=Err-DY;X1:=X1+SX;End;
  If E2<DX Then Begin Err:=Err+DX;Y1:=Y1+SY;End;
 Until False;
End;

Procedure LaSpriteMouse(Form: LongInt);
Var I: Integer;
Begin
 CurHotX:=Clamp(SExt(Rd16(Form),2),0,15);CurHotY:=Clamp(SExt(Rd16(Form+2),2),0,15);
 For I:=0 To 15 Do Begin CurMask[I]:=Rd16(Form+10+I*2);CurData[I]:=Rd16(Form+42+I*2);End;
End;

{ TEXTBLT : un caractere de la forme de police vers l'ecran avec tous les effets
  (gras, clair, italique, souligne, contour, ombre), l'echelle et la rotation }
Procedure LaTextBlt;
Const OFSX = 40; MAXC = 160;
Var Fb,Fw: LongInt; SX,SY,DX,DY,W,H,I,J,K,R,C,Sty,Wt,Lm,Sk,Ro,Lo,Fg,Bg,Up,Mode: Integer;
    G1,G2: Array[0..95,0..MAXC-1] Of Byte;       { lignes x colonnes (decalage OFSX) }
    Wn: Integer; Mk: Word; Sh,Cnt,Dir,Yd,Xd,Kx,Ky,Ry: Integer; Inc_,AccX,AccY: LongInt; B: Byte;
    DstW,DstH,ExL,ExR: Integer;
 Function Src(Jj,Ii: Integer): Byte;
 Begin
  If (Ii<0) Or (Ii>=W) Or (Jj<0) Or (Jj>=H) Then Begin Src:=0;Exit;End;
  Src:=Ord((Rd8(Fb+(SY+Jj)*Fw+((SX+Ii) Shr 3)) And (128 Shr ((SX+Ii) And 7)))<>0);
 End;
 Procedure Emit(Xo,Yo: Integer; V: Byte);
 { ecrit le point (colonne Xo, ligne Yo) du glyphe compose, en tenant compte de la rotation }
 Var PxX,PxY: Integer;
 Begin
  Case LaW(104) Of
   900: Begin PxX:=DX+Yo;PxY:=DY-Xo;End;
   1800: Begin PxX:=DX-Xo;PxY:=DY-Yo;End;
   2700: Begin PxX:=DX-Yo;PxY:=DY+Xo;End;
  Else Begin PxX:=DX+Xo;PxY:=DY+Yo;End;
  End;
  If Not LaClip(PxX,PxY) Then Exit;
  Case LaW(36) Of
   1: If V<>0 Then LaOPlot(PxX,PxY,Fg And 1);
   2: If (V<>0) And ((Fg And 1)<>0) Then Begin LaXor:=True;LaOPlot(PxX,PxY,1);LaXor:=False;End;
   3: If V=0 Then LaOPlot(PxX,PxY,Fg And 1);
  Else
   If V<>0 Then LaOPlot(PxX,PxY,Fg And 1) Else LaOPlot(PxX,PxY,Bg And 1);
  End;
 End;
Begin
 Fb:=Rd32(LINEA_VARS+84);Fw:=LaW(88);
 SX:=LaW(72);SY:=LaW(74);DX:=LaW(76);DY:=LaW(78);W:=LaW(80);H:=LaW(82);
 Sty:=LaW(90);Wt:=LaW(96);Lm:=LaW(92);Sk:=LaW(94);Ro:=LaW(98);Lo:=LaW(100);
 Fg:=LaW(106);Bg:=LaW(114);
 If (W<=0) Or (H<=0) Or (W>64) Or (H>64) Then Exit;
 FillChar(G1,SizeOf(G1),0);FillChar(G2,SizeOf(G2),0);
 { etendue de la cellule : -LOFF .. largeur + epaisseur + ROFF (+1 de chaque cote pour le contour, +1 a droite pour l'ombre) }
 If (Sty And 1)=0 Then Wt:=0;
 If Ro<0 Then Ro:=0;
 If Lo<0 Then Lo:=0;
 ExL:=-Lo;ExR:=W+Wt+Ro;
 If (Sty And 16)<>0 Then Begin Dec(ExL);Inc(ExR);End;
 If (Sty And 32)<>0 Then Inc(ExR);
 If ExL<-OFSX+1 Then ExL:=-OFSX+1;
 If ExR>MAXC-OFSX-1 Then ExR:=MAXC-OFSX-1;
 { 1. glyphe source }
 For J:=0 To H-1 Do For I:=0 To W-1 Do G1[J,I+OFSX]:=Src(J,I);
 { 2. gras : chaque point est repete sur Wt colonnes a sa droite }
 If (Sty And 1)<>0 Then Begin
  If Wt<0 Then Wt:=0;
  For J:=0 To H-1 Do
   For I:=0 To MAXC-1 Do
    If G1[J,I]<>0 Then
     For K:=0 To Wt Do If I+K<MAXC Then G2[J,I+K]:=1;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 3. clair : masque tourne d'un bit a chaque ligne }
 If (Sty And 2)<>0 Then Begin
  Mk:=Word(Lm);
  For J:=0 To H-1 Do Begin
   For I:=0 To MAXC-1 Do
    If ((Mk Shr (15-((I-OFSX+16000) And 15))) And 1)=0 Then G1[J,I]:=0;
   Mk:=Word((Mk Shl 1) Or (Mk Shr 15));
  End;
 End;
 { 4. italique : decalage par ligne, de Ro au sommet vers -Lo en bas }
 If (Sty And 4)<>0 Then Begin
  Mk:=Word(Sk);Sh:=Ro;
  For J:=0 To H-1 Do Begin
   For I:=0 To MAXC-1 Do
    If G1[J,I]<>0 Then Begin
     K:=I+Sh;
     If (K>=0) And (K<MAXC) Then G2[J,K]:=1;
    End;
   If (Mk And $8000)<>0 Then Dec(Sh);
   Mk:=Word((Mk Shl 1) Or (Mk Shr 15));
  End;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 5. contour : bord du glyphe seulement }
 If (Sty And 16)<>0 Then Begin
  For J:=0 To H-1 Do
   For I:=1 To MAXC-2 Do
    If G1[J,I]=0 Then Begin
     Cnt:=0;
     For R:=-1 To 1 Do For C:=-1 To 1 Do
      If (J+R>=0) And (J+R<H) And (G1[J+R,I+C]<>0) Then Cnt:=1;
     G2[J,I]:=Cnt;
    End;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 6. ombre : copie decalee d'un point, en trame }
 If (Sty And 32)<>0 Then Begin
  For J:=0 To H-1 Do
   For I:=0 To MAXC-1 Do Begin
    G2[J,I]:=G1[J,I];
    If (J>0) And (I>0) And (G1[J-1,I-1]<>0) And (G1[J,I]=0) And (((I+J) And 1)=0) Then G2[J,I]:=1;
   End;
  G1:=G2;FillChar(G2,SizeOf(G2),0);
 End;
 { 7. souligne : derniere ligne }
 If (Sty And 8)<>0 Then For I:=0 To MAXC-1 Do If (I>=OFSX-Lo) And (I<OFSX+W+Wt+Ro) Then G1[H-1,I]:=1;
 { 8. ecriture avec echelle (accumulateur DDA) }
 DstH:=0;
 If LaW(102)=0 Then Begin
  For J:=0 To H-1 Do
   For I:=ExL To ExR-1 Do Emit(I,J,G1[J,I+OFSX]);
 End Else Begin
  Dir:=LaW(68);Inc_:=LaW(66) And $FFFF;
  Yd:=0;AccY:=LaW(64) And $FFFF;
  For J:=0 To H-1 Do Begin
   AccY:=AccY+Inc_;
   If AccY>65535 Then Begin AccY:=AccY-65536;Ky:=1;End Else Ky:=0;
   If Dir=0 Then Ky:=1+Ky Else Ky:=1-Ky;
   For Ry:=1 To Ky Do Begin
    Xd:=ExL;AccX:=LaW(64) And $FFFF;
    For I:=ExL To ExR-1 Do Begin
     B:=G1[J,I+OFSX];
     AccX:=AccX+Inc_;
     If AccX>65535 Then Begin AccX:=AccX-65536;Kx:=1;End Else Kx:=0;
     If Dir=0 Then Kx:=1+Kx Else Kx:=1-Kx;
     For R:=1 To Kx Do Begin Emit(Xd,Yd,B);Inc(Xd);End;
    End;
    Inc(Yd);
   End;
  End;
 End;
 
End;

Procedure LaDispatch(Fn: Integer);
Var X1,Y1,X2,Y2,X,Y,I,J,K,N: LongInt; Pt,Pn,Ct: LongInt; Col: Integer; B: LongInt;
    W,H,SF,DF,SNL,DNL,SNW,DNW,SX,SY,DX,DY,Opr,S,D,R: LongInt; Fg,Bg: Integer;
    XI: Array[0..63] Of LongInt; Cnt: Integer; Mf1,Mf2,Fb,Fw: LongInt; Sv: Integer;
    SrcM,DstM: TMfdb; Sa,Sb,Sl: LongInt; Fm: LongInt; Mk,Dt: Word; PA,PNL,PMK: LongInt;
 Function SrcBit(Frm,Nxw,Nxl,PX,PY: LongInt): Integer;
 Var A: LongInt;
 Begin
  A:=Frm+PY*Nxl+(PX Shr 4)*Nxw+((PX And 15) Shr 3);
  SrcBit:=Ord((Rd8(A) And (128 Shr (PX And 7)))<>0);
 End;
 Procedure PutBit(Frm,Nxw,Nxl,PX,PY: LongInt; V: Integer);
 Var A: LongInt;
 Begin
  A:=Frm+PY*Nxl+(PX Shr 4)*Nxw+((PX And 15) Shr 3);
  If V<>0 Then Wr8(A,Rd8(A) Or (128 Shr (PX And 7))) Else Wr8(A,Rd8(A) And (Not (128 Shr (PX And 7))));
 End;
Begin
 Case Fn Of
  0: LineAInit;
  1: Begin
      Pt:=Rd32(LINEA_VARS+12);Pn:=Rd32(LINEA_VARS+8);
      LaPix(SmallInt(Rd16(Pt)),SmallInt(Rd16(Pt+2)),True,SmallInt(Rd16(Pn)));
     End;
  2: Begin
      Pt:=Rd32(LINEA_VARS+12);
      Rg[0]:=LaOGet(SmallInt(Rd16(Pt)),SmallInt(Rd16(Pt+2)));
     End;
  3: LaLine(LaW(38),LaW(40),LaW(42),LaW(44));
  4: LaHLine(LaW(38),LaW(42),LaW(40));
  5: Begin
      Y1:=LaW(40);Y2:=LaW(44);
      If Y1>Y2 Then Begin Y:=Y1;Y1:=Y2;Y2:=Y;End;
      For Y:=Y1 To Y2 Do LaHLine(LaW(38),LaW(42),Y);
     End;
  6: Begin
      { une ligne de balayage (Y1) d'un polygone : points dans PTSIN }
      Ct:=Rd32(LINEA_VARS+4);Pt:=Rd32(LINEA_VARS+12);
      Cnt:=SmallInt(Rd16(Ct+2));
      If Cnt>60 Then Cnt:=60;
      Y:=LaW(40);N:=0;
      For I:=0 To Cnt-1 Do Begin
       J:=I+1;If J>=Cnt Then J:=0;
       X1:=SmallInt(Rd16(Pt+I*4));Y1:=SmallInt(Rd16(Pt+I*4+2));
       X2:=SmallInt(Rd16(Pt+J*4));Y2:=SmallInt(Rd16(Pt+J*4+2));
       If ((Y1<=Y) And (Y2>Y)) Or ((Y2<=Y) And (Y1>Y)) Then Begin
        If N<63 Then Begin XI[N]:=Round(X1+(Y-Y1)*(X2-X1)/(Y2-Y1));Inc(N);End;
       End;
      End;
      For I:=1 To N-1 Do Begin
       K:=XI[I];J:=I-1;
       While (J>=0) And (XI[J]>K) Do Begin XI[J+1]:=XI[J];Dec(J);End;
       XI[J+1]:=K;
      End;
      I:=0;
      While I+1<N Do Begin LaHLine(XI[I],XI[I+1],Y);Inc(I,2);End;
     End;
  7: Begin
      { BITBLT : bloc de parametres en A6 (un plan) }
      B:=Rg[14];
      W:=SmallInt(Rd16(B));H:=SmallInt(Rd16(B+2));
      Fg:=SmallInt(Rd16(B+6)) And 1;Bg:=SmallInt(Rd16(B+8)) And 1;
      SX:=SmallInt(Rd16(B+14));SY:=SmallInt(Rd16(B+16));SF:=Rd32(B+18);SNW:=SmallInt(Rd16(B+22));SNL:=SmallInt(Rd16(B+24));
      DX:=SmallInt(Rd16(B+28));DY:=SmallInt(Rd16(B+30));DF:=Rd32(B+32);DNW:=SmallInt(Rd16(B+36));DNL:=SmallInt(Rd16(B+38));
      Opr:=Rd8(B+10+(Fg Shl 1)+Bg);
      { demi-teinte : la source est combinee (ET) au motif }
      PA:=Rd32(B+42);PNL:=SmallInt(Rd16(B+46));PMK:=Rd16(B+50);
      { sens de copie choisi pour que le recouvrement ne detruise pas la source :
        lignes en sens inverse si on descend, colonnes en sens inverse si on va a droite sur la meme ligne }
      For K:=0 To H-1 Do Begin
       If DY>SY Then J:=H-1-K Else J:=K;
       For N:=0 To W-1 Do Begin
        If (DY=SY) And (DX>SX) Then I:=W-1-N Else I:=N;
        S:=SrcBit(SF,SNW,SNL,SX+I,SY+J);D:=SrcBit(DF,DNW,DNL,DX+I,DY+J);
        If PA<>0 Then S:=S And ((Rd16(PA+PNL*((DY+J) And PMK)) Shr (15-((DX+I) And 15))) And 1);
        PutBit(DF,DNW,DNL,DX+I,DY+J,LaRop(Opr,S,D));
       End;
      End;
      
     End;
  8: LaTextBlt;
  9: MouseHidden:=Max2(0,MouseHidden-1);
  10: Inc(MouseHidden);
  11: Begin
       { transformation du curseur de souris : formulaire dans INTIN }
       LaSpriteMouse(Rd32(LINEA_VARS+8));
      End;
  12: Begin
       { efface un lutin : tampon en A2 (x, y, nombre de lignes, fond) }
       Sa:=Rg[10];
       If Rd16(Sa+4)<>0 Then Begin
        X:=SmallInt(Rd16(Sa));Y:=SmallInt(Rd16(Sa+2));N:=Rd16(Sa+4);
        For J:=0 To N-1 Do
         For I:=0 To 15 Do
          If LaClip(X+I,Y+J) Then LaOPlot(X+I,Y+J,(Rd16(Sa+6+J*2) Shr (15-I)) And 1);
        Wr16(Sa+4,0);
        
       End;
      End;
  13: Begin
       { dessine un lutin : D0=x, D1=y, A0=formulaire, A2=tampon de sauvegarde }
       Fm:=Rg[8];Sa:=Rg[10];
       X:=SmallInt(Rg[0] And $FFFF)-SmallInt(Rd16(Fm));Y:=SmallInt(Rg[1] And $FFFF)-SmallInt(Rd16(Fm+2));
       { +6 : couleur du masque (fond), +8 : couleur des donnees (premier plan) }
       Bg:=SmallInt(Rd16(Fm+6)) And 1;Fg:=SmallInt(Rd16(Fm+8)) And 1;
       Wr16(Sa,X);Wr16(Sa+2,Y);Wr16(Sa+4,16);
       For J:=0 To 15 Do Begin
        Mk:=0;
        For I:=0 To 15 Do If LaClip(X+I,Y+J) Then Mk:=Mk Or (Word(LaOGet(X+I,Y+J)) Shl (15-I));
        Wr16(Sa+6+J*2,Mk);
       End;
       For J:=0 To 15 Do Begin
        Mk:=Rd16(Fm+10+J*4);Dt:=Rd16(Fm+12+J*4);
        For I:=0 To 15 Do
         If ((Mk Shr (15-I)) And 1)<>0 Then
          If LaClip(X+I,Y+J) Then Begin
           If ((Dt Shr (15-I)) And 1)<>0 Then LaOPlot(X+I,Y+J,Fg) Else LaOPlot(X+I,Y+J,Bg);
          End;
       End;
       
      End;
  14: Begin
       { copie de formulaire raster (comme vro_cpyfm / vrt_cpyfm) }
       Ct:=Rd32(LINEA_VARS+4);Pn:=Rd32(LINEA_VARS+8);Pt:=Rd32(LINEA_VARS+12);
       ReadMfdb(Rd32(Ct+14),SrcM);ReadMfdb(Rd32(Ct+18),DstM);
       SetClip(0,0,SW-1,SH-1);
       If LaW(54)<>0 Then SetClip(LaW(56),LaW(58),LaW(60),LaW(62));
       CopyRaster(SrcM,DstM,SExt(Rd16(Pt),2),SExt(Rd16(Pt+2),2),SExt(Rd16(Pt+4),2),SExt(Rd16(Pt+6),2),
         SExt(Rd16(Pt+8),2),SExt(Rd16(Pt+10),2),SExt(Rd16(Pn),2),LaW(116)<>0,LaW(106),LaW(114));
      End;
  15: Begin
       { remplissage par germe : point dans PTSIN }
       Pt:=Rd32(LINEA_VARS+12);
       VP^.FillInt:=1;VP^.FillCol:=LaW(24) And 1;VP^.FillPer:=0;
       SetClip(0,0,SW-1,SH-1);
       If LaW(54)<>0 Then SetClip(LaW(56),LaW(58),LaW(60),LaW(62));
       FloodFill(SExt(Rd16(Pt),2),SExt(Rd16(Pt+2),2),-1);
      End;
 End;
End;

Procedure DoLineA(Op: LongInt);
Var F: Integer; Col: Integer;
Begin
 If (ExcHandler(10)<>0) And Not AmigaRun Then Begin RaiseExc(10);Exit;End;   { vecteur 10 installe par le programme }
 F:=Op And $FFF;
 If DosTrace Then Begin
   WriteLn(ConOut,'LINEA ',F,' pc=',Hex8(CurOpPC));Flush(ConOut);End;
 SelVdi(0);
 If F>0 Then CheckFonts;
 LaXor:=False;
 LaDispatch(F);
 SetClip(0,0,SW-1,SH-1);
 VP^.WrMode:=WM_REPL;
End;

{ ---------------------------------------------------------------------- }
{ AmigaOS simplifie : exec.library, dos.library                           }
{ ---------------------------------------------------------------------- }

Procedure AmigaCall(Base: LongInt; Off: LongInt);
Var Lib: Integer; R,A,N: LongInt; S: String; I: LongInt; Buf: Array[0..4095] Of
  Byte; Got: LongInt; H: Integer;
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
          If Rg[2]=1006 Then Rewrite(FHs[H],1) Else Begin
            FileMode:=0;Reset(FHs[H],1);End;
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
         Assign(FScratch,S);
         {$I-}
         Erase(FScratch);
         {$I+}
         If IOResult=0 Then R:=-1 Else R:=0;
        End;
   -144: Begin StopReason:=STOP_EXIT;ExitCode:=Rg[1];End;
   -198: Delay(Rg[1]*20);
   -948: Begin
          A:=Rg[1];N:=0;
          While (Rd8(A+N)<>0) And (N<30000) Do Begin
            ConPut(Rd8(A+N));Inc(N);End;
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
 MCnt:=0;CurOwn:=0;DosUserSP:=0;DtaAddr:=BP_ADDR+$80;DtaActive:=False;
 CloseAllFiles;
 ConRow:=0;ConCol:=0;ConRev:=False;ConWrap:=True;ConCurOn:=True;ConState:=0;
 KQHead:=0;KQTail:=0;UserBreak:=False;
 NBps:=0;DbgN:=0;UnknownCall:='';
 AmigaRun:=False;
 DosTrace:=GetEnv('DEVPAC_TRACE')<>'';
 VdiTrace:=GetEnv('DEVPAC_TRACE')='2';
 DosInit;
 GemReset;
 DevInitAll;EnvInit;
 SysTablesInit;
 SysVarsInit;
 UserCursor:=False;RecActive:=False;
 ScrDirtyLo:=0;ScrDirtyHi:=399;
 { stub de sortie : clr.w -(sp) ; trap #1 }
 Wr16(STUB_EXIT,$4267);Wr16(STUB_EXIT+2,$4E41);
 { stub Supexec : andi #$DFFF,sr ; rts }
 Wr16(STUB_USER,$027C);Wr16(STUB_USER+2,$DFFF);Wr16(STUB_USER+4,$4E75);
 FillChar(ScrShadow,SizeOf(ScrShadow),$FF);
End;

{ Charge une image PRG dans la page de base Bp ; TB = debut du texte, EndA =
  fin du BSS }
Function LoadPRGImage(P: Pointer; Len: LongInt; Const CmdLine: String; Bp:
  LongInt;
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
    For J:=0 To 13 Do If BufB(P,Sym+14+J)<>0 Then
      Name:=Name+Chr(BufB(P,Sym+14+J));
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
Var Pos,NH,First,Last,I,Cur,T,Sz,N,Dst,Base,Nm: LongInt; HAddr,HSize:
  Array[0..15] Of LongInt;
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
           For J:=0 To N*4-1 Do If BufB(P,Pos+J)<>0 Then
             Name:=Name+Chr(BufB(P,Pos+J));
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
 Wr16(STUB_EXIT,$3F00);Wr16(STUB_EXIT+2,$3F3C);Wr16(STUB_EXIT+4,
   $004C);Wr16(STUB_EXIT+6,$4E41);
 Rg[15]:=Sp;USPv:=Sp;SSPv:=$7000;
 Rg[0]:=Length(CmdLine);Rg[8]:=BP_ADDR+$80;Rg[14]:=EXECBASE;
 PC:=HAddr[0];SRv:=0;
 LoadHunk:=True;
End;


{ Pexec GEMDOS : charge et execute un programme fils }
Function DoPexec(Mode: Integer; NameP,CmdP,EnvP: LongInt): LongInt;
Var Nm,Cmd: String; P: Pointer; Len,Bp,TB,EndA,TSz,Top,SvHeap,Code: LongInt;
  Ok: Boolean;
    SvRg: Array[0..15] Of LongInt; SvPC,SvSR,SvUSP,SvSSP,SvOp,SvPexBp,SvOwn:
      LongInt; I: Integer; SvProc: Integer;
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
   PollInput;
   If Not BatchMode Then BlitScreen(False);
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
     { cree une page de base : le fils recoit toute la memoire libre (a reduire
       par Mshrink) }
     Top:=DoMalloc(-1);
     If Top<$400 Then Begin DoPexec:=-39;Exit;End;
     Bp:=DoMalloc(Top);
     If Bp=0 Then Begin DoPexec:=-39;Exit;End;
     For I:=0 To 255 Do Wr8(Bp+I,0);
     Wr32(Bp,Bp);Wr32(Bp+4,Bp+Top);Wr32(Bp+8,Bp+$100);Wr32(Bp+36,
       BP_ADDR);Wr32(Bp+44,ENV_BLK);
     Wr32(Bp+32,Bp+$80);
     If CmdP<>0 Then Begin
      For I:=0 To Rd8(CmdP) Do Wr8(Bp+$80+I,Rd8(CmdP+I));
     End;
     DoPexec:=Bp;Exit;
    End;
    Nm:=TosPath(RdStr(NameP,200));
    If CmdP<>0 Then Cmd:=RdStr(CmdP+1,Rd8(CmdP)) Else Cmd:='';
    If Not ReadFileBytes(Nm,P,Len) Then Exit;
    { comme TOS : le fils recoit le plus grand bloc libre (TPA) et doit le
      restituer par Mshrink }
    Top:=DoMalloc(-1);
    If (Top<Len+$1000) Or (Top<$2000) Then Begin
     If P<>Nil Then FreeMem(P,Len);
     DoPexec:=-39;Exit;
    End;
    Bp:=DoMalloc(Top);
    If Bp=0 Then Begin
     If P<>Nil Then FreeMem(P,Len);
     DoPexec:=-39;Exit;
    End;
    Ok:=LoadPRGImage(P,Len,Cmd,Bp,False,TB,EndA,TSz);
    If P<>Nil Then FreeMem(P,Len);
    If (Not Ok) Or (EndA+$400>Bp+Top) Then Begin
      DoMfree(Bp);DoPexec:=-66;Exit;End;
    Wr32(Bp+4,Bp+Top);
    If Mode=3 Then Begin DoPexec:=Bp;Exit;End;
    SvPexBp:=PexBp;PexBp:=Bp;
    SvOwn:=CurOwn;CurOwn:=Bp;
    RunChild(Bp,Nm,Cmd);
    CurOwn:=SvOwn;
    PexBp:=SvPexBp;
    FreeOwned(Bp);DoMfree(Bp);
    DoPexec:=Code;
   End;
  4,6: Begin
    Bp:=CmdP;
    SvHeap:=HeapLo;
    SvPexBp:=PexBp;PexBp:=Bp;
    SvOwn:=CurOwn;CurOwn:=Bp;
    RunChild(Bp,'',RdStr(Bp+$81,Rd8(Bp+$80)));
    CurOwn:=SvOwn;
    PexBp:=SvPexBp;
    FreeOwned(Bp);
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
 TITLE_H = 18;
 INFO_H  = 13;
 SB_W    = 17;
 EMAXWIN  = 7;                   { fenetres de l'editeur }
 DESK_Y  = MENU_H+1;            { haut du bureau }

Var
 { geometrie de la fenetre active (recalculee par ESetGeom) }
 WX1,WY1,WX2,WY2 : Integer;
 INFO_Y,TX0,TY0,TXT_X2,TXT_Y2,TXT_ROWS,TXT_COLS : Integer;
 { police de l'editeur : 0 Normal 8x16, 1 Small 8x8, 2 Tiny 6x7, 3 8x10
   (historique) }
 FontKind,FontCW,FontLH : Integer;
 CurV : Integer;                { colonnes virtuelles au dela de la fin de
   ligne }
 DrawingAct : Boolean;          { la fenetre en cours de dessin est la fenetre
   active }

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
 { bloc : debut et fin poses separement (ordre libre) ; valide si debut < fin }
 BlkSL,BlkSC,BlkEL,BlkEC : Integer;
 BlkSOk,BlkEOk : Boolean;
 ClipLn  : PLineArr;
 ClipN   : Integer;
 FindStr,ReplStr : String;
 FindCase : Boolean;
 CursorOn : Boolean;
 DragSel  : Boolean;
 AnchL,AnchC : Integer;
 StatusMsg : String;             { message d'erreur de la ligne d'etat }
 HiOn     : Boolean;             { chaine trouvee affichee en inverse }
 HiL,HiC,HiLen : Integer;
 FoundL,FoundC : Integer;        { derniere position trouvee (0 = aucune) }
 EditLine : Integer;             { ligne en cours de modification (blocs non
   affiches) }
 BkL,BkC  : Array[1..8] Of Integer;   { signets }
 BkOn     : Array[1..8] Of Boolean;
 UndelS   : String;              { derniere ligne supprimee (Ctrl-Y / Ctrl-@) }
 UndelOk,UndelEnd : Boolean;
 MouseHid : Boolean;
 { Preferences }
 PrefTab,PrefBuf : LongInt;
 PrefNumPad,PrefBackup,PrefIndent,PrefFlash,PrefLoadMon : Integer;
 PrefAutoSave,PrefHideMouse,PrefMatch,PrefStopEol : Integer;
 PrefSaveQuit,PrefSaveRun : Integer;     { 1 oui, 2 non, 3 demander }
 CfgFile  : String;              { fichier de reglages charge (ou '') }
 ErrJump  : Integer;
 ErrCur   : Integer;             { dernier numero d'erreur affiche (0 = aucun) }
 ErrWin   : Array[1..MAXERR] Of Byte;   { fenetre contenant chaque erreur (0 =
   aucune) }
 CfgOutName,CfgListName : String;   { noms de sortie / listing choisis par
   l'utilisateur }
 DragMode : Integer;             { 0 caractere, 1 ligne (marge) }
 ScrollOnly : Boolean;           { la fenetre a ete defilee a la souris : le
   curseur peut sortir de la vue }
 LastClkT : LongInt;             { double-clic : instant et position du dernier
   clic }
 LastClkL,LastClkC : Integer;

Procedure ShowMouseU;
Begin
 If Not MouseHid Then ShowMouse;
End;

Procedure ClearBlock;
Begin
 BlkSOk:=False;BlkEOk:=False;
End;

Procedure ClearBookmarks;
Var I: Integer;
Begin
 For I:=1 To 8 Do BkOn[I]:=False;
End;

Procedure EdInit;
Begin
 If Ed=Nil Then New(Ed);
 If ClipLn=Nil Then New(ClipLn);
 EdN:=1;
 Ed^[1]:=NewStr('');
 CurL:=1;CurC:=1;TopL:=1;LeftV:=0;WantV:=0;EdMod:=False;EdMem:=0;
 ClearBlock;ClearBookmarks;EdIns:=True;
 StatusMsg:='';HiOn:=False;EditLine:=0;FoundL:=0;FoundC:=0;
End;

Procedure EdClear;
Var I: Integer;
Begin
 For I:=1 To EdN Do FreeStr(Ed^[I]);
 EdN:=0;
 EdInit;
End;

{ ---------------------------------------------------------------------- }
{ Police de l'editeur et geometrie de la fenetre active                    }
{ ---------------------------------------------------------------------- }

Procedure ESetFont(K: Integer);
Begin
 FontKind:=K;
 Case K Of
  0: Begin FontCW:=8;FontLH:=16;End;
  1: Begin FontCW:=8;FontLH:=8;End;
  2: Begin FontCW:=6;FontLH:=7;End;
 Else Begin FontKind:=3;FontCW:=8;FontLH:=10;End;
 End;
End;

Procedure ESetGeom(X1,Y1,X2,Y2: Integer);
Begin
 WX1:=X1;WY1:=Y1;WX2:=X2;WY2:=Y2;
 INFO_Y:=WY1+TITLE_H;
 TX0:=WX1+8;
 TY0:=INFO_Y+INFO_H+2;
 TXT_X2:=WX2-SB_W-1;
 TXT_Y2:=WY2-SB_W-1;
 TXT_ROWS:=(TXT_Y2-TY0+1) Div FontLH;
 If TXT_ROWS<1 Then TXT_ROWS:=1;
 TXT_COLS:=(TXT_X2-TX0) Div FontCW;
 If TXT_COLS<1 Then TXT_COLS:=1;
End;

Var
 Font6   : Array[0..255,0..5] Of Byte;    { police Tiny 6x6 : reduction de la
   8x8 }
 Font6Ok : Boolean;

Procedure BuildFont6;
Const SrcR : Array[0..5] Of Integer = (0,2,3,4,5,6);
      SrcC : Array[0..5] Of Integer = (0,1,2,4,5,6);
Var C,R,K: Integer; B: Byte;
Begin
 For C:=0 To 255 Do
  For R:=0 To 5 Do Begin
   B:=0;
   For K:=0 To 5 Do
    If (Font8[C,SrcR[R]] And (128 Shr SrcC[K]))<>0 Then B:=B Or (128 Shr K);
   Font6[C,R]:=B;
  End;
 Font6Ok:=True;
End;

{ Texte de l'editeur dans la police choisie (coin haut gauche X,Y ; couleur
  Col) }
Procedure EText(X,Y: Integer; Const S: String; Col: Integer);
Var I,GY,GX,Cx,Ch: Integer; B: Byte;
Begin
 If FontKind=3 Then Begin
  SetColor(Col);OutTextXY(X,Y+1,S);Exit;
 End;
 For I:=1 To Length(S) Do Begin
  Ch:=Ord(S[I]);
  If Ch<>32 Then Begin
   Cx:=X+(I-1)*FontCW;
   Case FontKind Of
    0: For GY:=0 To 15 Do Begin
        B:=Font8[Ch,GY Shr 1];
        If B<>0 Then
         For GX:=0 To 7 Do If (B And (128 Shr GX))<>0 Then
           PutPixel(Cx+GX,Y+GY,Col);
       End;
    1: For GY:=0 To 7 Do Begin
        B:=Font8[Ch,GY];
        If B<>0 Then
         For GX:=0 To 7 Do If (B And (128 Shr GX))<>0 Then
           PutPixel(Cx+GX,Y+GY,Col);
       End;
    2: Begin
        If Not Font6Ok Then BuildFont6;
        For GY:=0 To 5 Do Begin
         B:=Font6[Ch,GY];
         If B<>0 Then
          For GX:=0 To 5 Do If (B And (128 Shr GX))<>0 Then
            PutPixel(Cx+GX,Y+GY,Col);
        End;
       End;
   End;
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Fenetres de l'editeur (jusqu'a 7)                                         }
{ La fenetre du dessus est la fenetre active : ses donnees sont dans les   }
{ variables globales (Ed, EdN, CurL...). Les autres sont rangees dans      }
{ EWins[]. EWinStore / EWinLoad echangent les deux.                           }
{ ---------------------------------------------------------------------- }

Type
 TEdWin = Record
  Used : Boolean;
  PEd  : PLineArr;
  N,L,C,Top,Left,Want : Integer;
  Fil  : String;
  Modf : Boolean;
  Mem  : LongInt;
  BSL,BSC,BEL,BEC : Integer;
  BSOk,BEOk : Boolean;
  BkLine,BkCol : Array[1..8] Of Integer;
  BkSet : Array[1..8] Of Boolean;
  X1,Y1,X2,Y2 : Integer;
  Full : Boolean;
  SX1,SY1,SX2,SY2 : Integer;
 End;

Var
 EWins : Array[1..EMAXWIN] Of TEdWin;
 EZOrd : Array[1..EMAXWIN] Of Integer;      { ordre d'empilement : EZOrd[ENWin]
   = dessus }
 ENWin,EActW : Integer;
 ELayoutKeep : Integer;                     { disposition permanente : 0
   aucune, 1 overlap, 2 tile, 3 vertical }

Procedure EWinStore(I: Integer);
Var K: Integer;
Begin
 EWins[I].PEd:=Ed;EWins[I].N:=EdN;EWins[I].L:=CurL;EWins[I].C:=CurC;
 EWins[I].Top:=TopL;EWins[I].Left:=LeftV;EWins[I].Want:=WantV;
 EWins[I].Fil:=EdFile;EWins[I].Modf:=EdMod;EWins[I].Mem:=EdMem;
 EWins[I].BSL:=BlkSL;EWins[I].BSC:=BlkSC;EWins[I].BEL:=BlkEL;EWins[I].BEC:=BlkEC
   ;
 EWins[I].BSOk:=BlkSOk;EWins[I].BEOk:=BlkEOk;
 For K:=1 To 8 Do Begin
  EWins[I].BkLine[K]:=BkL[K];EWins[I].BkCol[K]:=BkC[K];EWins[I].BkSet[K]:=BkOn[K
    ];
 End;
End;

Procedure EWinLoad(I: Integer);
Var K: Integer;
Begin
 Ed:=EWins[I].PEd;EdN:=EWins[I].N;CurL:=EWins[I].L;CurC:=EWins[I].C;
 TopL:=EWins[I].Top;LeftV:=EWins[I].Left;WantV:=EWins[I].Want;
 EdFile:=EWins[I].Fil;EdMod:=EWins[I].Modf;EdMem:=EWins[I].Mem;
 BlkSL:=EWins[I].BSL;BlkSC:=EWins[I].BSC;BlkEL:=EWins[I].BEL;BlkEC:=EWins[I].BEC
   ;
 BlkSOk:=EWins[I].BSOk;BlkEOk:=EWins[I].BEOk;
 For K:=1 To 8 Do Begin
  BkL[K]:=EWins[I].BkLine[K];BkC[K]:=EWins[I].BkCol[K];BkOn[K]:=EWins[I].BkSet[K
    ];
 End;
 ESetGeom(EWins[I].X1,EWins[I].Y1,EWins[I].X2,EWins[I].Y2);
End;

{ les erreurs d'assemblage de la fenetre W ne sont plus suivies }
Procedure ErrForget(W: Integer);
Var I: Integer;
Begin
 For I:=1 To MAXERR Do If ErrWin[I]=W Then ErrWin[I]:=0;
End;

{ premiere fenetre (apres EdInit) : plein ecran }
Procedure EWinInit;
Var I: Integer;
Begin
 For I:=1 To EMAXWIN Do Begin EWins[I].Used:=False;EWins[I].Full:=False;End;
 EWins[1].Used:=True;
 EWins[1].X1:=0;EWins[1].Y1:=DESK_Y;EWins[1].X2:=SCR_W-1;EWins[1].Y2:=SCR_H-1;
 EZOrd[1]:=1;ENWin:=1;EActW:=1;
 ESetGeom(0,DESK_Y,SCR_W-1,SCR_H-1);
End;

{ place la fenetre I au dessus de la pile et la rend active }
Procedure EWinActivate(I: Integer);
Var Z,K: Integer;
Begin
 If (I<1) Or (I>EMAXWIN) Or Not EWins[I].Used Then Exit;
 If I<>EActW Then Begin
  EWinStore(EActW);
  Z:=1;
  While (Z<=ENWin) And (EZOrd[Z]<>I) Do Inc(Z);
  For K:=Z To ENWin-1 Do EZOrd[K]:=EZOrd[K+1];
  EZOrd[ENWin]:=I;
  EWinLoad(I);
  EActW:=I;
  HiOn:=False;EditLine:=0;FoundL:=0;DragSel:=False;CurV:=0;
 End;
End;

{ numero de la fenetre contenant le fichier Name (comparaison du nom court), 0
  si aucune }
Function EWinFindFile(Const Name: String): Integer;
Var I,R: Integer; N: String;
Begin
 R:=0;
 N:=Upper(ShortName(Name));
 For I:=1 To EMAXWIN Do
  If EWins[I].Used Then Begin
   If I=EActW Then Begin
    If (EdFile<>'') And (Upper(ShortName(EdFile))=N) Then R:=I;
   End Else If (EWins[I].Fil<>'') And (Upper(ShortName(EWins[I].Fil))=N) Then
     R:=I;
  End;
 EWinFindFile:=R;
End;

Procedure EArrange(Kind: Integer);
Var I,Z,N,Cols,Rows,CW,CH,K,W,H: Integer;
Begin
 If Kind<1 Then Exit;
 EWinStore(EActW);
 N:=ENWin;
 W:=SCR_W;H:=SCR_H-DESK_Y;
 Case Kind Of
  1: Begin
      CW:=W-(N-1)*24-24;If CW<240 Then CW:=240;
      CH:=H-(N-1)*20-20;If CH<160 Then CH:=160;
      For Z:=1 To N Do Begin
       I:=EZOrd[Z];
       EWins[I].X1:=(Z-1)*24;EWins[I].Y1:=DESK_Y+(Z-1)*20;
       EWins[I].X2:=EWins[I].X1+CW-1;EWins[I].Y2:=EWins[I].Y1+CH-1;
       If EWins[I].X2>SCR_W-1 Then EWins[I].X2:=SCR_W-1;
       If EWins[I].Y2>SCR_H-1 Then EWins[I].Y2:=SCR_H-1;
       EWins[I].Full:=False;
      End;
     End;
  2: Begin
      Cols:=1;
      While Cols*Cols<N Do Inc(Cols);
      Rows:=(N+Cols-1) Div Cols;
      K:=0;
      For I:=1 To EMAXWIN Do
       If EWins[I].Used Then Begin
        EWins[I].X1:=(K Mod Cols)*(W Div Cols);
        EWins[I].Y1:=DESK_Y+(K Div Cols)*(H Div Rows);
        EWins[I].X2:=EWins[I].X1+(W Div Cols)-1;
        EWins[I].Y2:=EWins[I].Y1+(H Div Rows)-1;
        EWins[I].Full:=False;
        Inc(K);
       End;
     End;
  3: Begin
      K:=0;
      For I:=1 To EMAXWIN Do
       If EWins[I].Used Then Begin
        EWins[I].X1:=0;EWins[I].X2:=W-1;
        EWins[I].Y1:=DESK_Y+K*(H Div N);
        EWins[I].Y2:=EWins[I].Y1+(H Div N)-1;
        EWins[I].Full:=False;
        Inc(K);
       End;
     End;
 End;
 EWinLoad(EActW);
End;

{ cree une fenetre vide qui devient la fenetre active ; False si plus de place }
Function EWinAlloc: Boolean;
Var I,N: Integer;
Begin
 EWinAlloc:=False;
 I:=0;
 For N:=1 To EMAXWIN Do If (I=0) And Not EWins[N].Used Then I:=N;
 If I=0 Then Exit;
 {$IFNDEF FPC}
 If MaxAvail<SizeOf(TLineArr)+8192 Then Exit;
 {$ENDIF}
 EWinStore(EActW);
 Ed:=Nil;
 EdInit;
 EdFile:='';
 EWins[I].Used:=True;
 N:=ENWin;
 EWins[I].X1:=(N*24) Mod 120;EWins[I].Y1:=DESK_Y+(N*20) Mod 100;
 EWins[I].X2:=SCR_W-1-((N*24) Mod 60);EWins[I].Y2:=SCR_H-1-((N*20) Mod 60);
 EWins[I].Full:=False;
 Inc(ENWin);EZOrd[ENWin]:=I;EActW:=I;
 ESetGeom(EWins[I].X1,EWins[I].Y1,EWins[I].X2,EWins[I].Y2);
 If ELayoutKeep>0 Then EArrange(ELayoutKeep);
 EWinAlloc:=True;
End;

{ ferme la fenetre I (le texte est perdu) ; il reste toujours une fenetre }
Procedure EWinClose(I: Integer);
Var K,Z: Integer;
Begin
 If (I<1) Or (I>EMAXWIN) Or Not EWins[I].Used Then Exit;
 ErrForget(I);
 If I=EActW Then Begin
  For K:=1 To EdN Do FreeStr(Ed^[K]);
  Dispose(Ed);Ed:=Nil;
 End Else Begin
  For K:=1 To EWins[I].N Do FreeStr(EWins[I].PEd^[K]);
  Dispose(EWins[I].PEd);EWins[I].PEd:=Nil;
 End;
 EWins[I].Used:=False;
 Z:=1;
 While (Z<=ENWin) And (EZOrd[Z]<>I) Do Inc(Z);
 For K:=Z To ENWin-1 Do EZOrd[K]:=EZOrd[K+1];
 Dec(ENWin);
 If ENWin=0 Then Begin
  { derniere fenetre : on la remplace par une fenetre vide }
  EdInit;EdFile:='';
  EWins[I].Used:=True;
  EWins[I].X1:=0;EWins[I].Y1:=DESK_Y;EWins[I].X2:=SCR_W-1;EWins[I].Y2:=SCR_H-1;
    EWins[I].Full:=False;
  EZOrd[1]:=I;ENWin:=1;EActW:=I;
  ESetGeom(0,DESK_Y,SCR_W-1,SCR_H-1);
 End Else If I=EActW Then Begin
  EActW:=EZOrd[ENWin];
  EWinLoad(EActW);
  HiOn:=False;EditLine:=0;
 End;
 If (ELayoutKeep>0) And (ENWin>1) Then EArrange(ELayoutKeep);
End;

{ Cycle Windows (Ctrl-V) : la fenetre du dessous passe au dessus }
Procedure EWinCycle;
Begin
 If ENWin>1 Then EWinActivate(EZOrd[1]);
End;

{ change la taille / position de la fenetre I }
Procedure EWinSetRect(I,X1,Y1,X2,Y2: Integer);
Begin
 EWinStore(EActW);
 EWins[I].X1:=X1;EWins[I].Y1:=Y1;EWins[I].X2:=X2;EWins[I].Y2:=Y2;
 EWins[I].Full:=False;
 EWinLoad(EActW);
End;

Procedure EWinToggleFull(I: Integer);
Begin
 EWinStore(EActW);
 If EWins[I].Full Then Begin
  EWins[I].X1:=EWins[I].SX1;EWins[I].Y1:=EWins[I].SY1;EWins[I].X2:=EWins[I].SX2;
    EWins[I].Y2:=EWins[I].SY2;
  EWins[I].Full:=False;
 End Else Begin
  EWins[I].SX1:=EWins[I].X1;EWins[I].SY1:=EWins[I].Y1;EWins[I].SX2:=EWins[I].X2;
    EWins[I].SY2:=EWins[I].Y2;
  EWins[I].X1:=0;EWins[I].Y1:=DESK_Y;EWins[I].X2:=SCR_W-1;EWins[I].Y2:=SCR_H-1;
  EWins[I].Full:=True;
 End;
 EWinLoad(EActW);
End;

{ nouvelle police : on recalcule la geometrie de toutes les fenetres }
Procedure EApplyFont(K: Integer);
Begin
 ESetFont(K);
 ESetGeom(WX1,WY1,WX2,WY2);
End;


{ Message dans la ligne d'etat, accompagne d'un bip ; efface a la touche
  suivante }
Procedure StatusErr(Const S: String);
Begin
 StatusMsg:=S;
 NeedDraw:=True;
 SoundBell;
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

{ ---------------------------------------------------------------------- }
{ Reperes de position (blocs, signets, erreurs) suivant les modifications  }
{ ---------------------------------------------------------------------- }

{ texte insere en (L,C) : NL lignes, la derniere ayant LastLen caracteres
  inseres }
Procedure AdjIns(Var PL,PC: Integer; L,C,NL,LastLen: Integer);
Begin
 If PL<L Then Exit;
 If PL=L Then Begin
  If PC>=C Then Begin
   PL:=PL+NL-1;
   If NL=1 Then PC:=PC+LastLen Else PC:=PC-C+LastLen+1;
  End;
 End Else PL:=PL+NL-1;
End;

{ texte supprime de (L1,C1) inclus a (L2,C2) exclu }
Procedure AdjDel(Var PL,PC: Integer; L1,C1,L2,C2: Integer);
Begin
 If (PL<L1) Or ((PL=L1) And (PC<=C1)) Then Exit;
 If (PL<L2) Or ((PL=L2) And (PC<C2)) Then Begin PL:=L1;PC:=C1;Exit;End;
 If PL=L2 Then Begin PL:=L1;PC:=PC-C2+C1;End Else PL:=PL-(L2-L1);
End;

Procedure EdAdjIns(L,C,NL,LastLen: Integer);
Var I,T,C0: Integer;
Begin
 If BlkSOk Then AdjIns(BlkSL,BlkSC,L,C,NL,LastLen);
 If BlkEOk Then AdjIns(BlkEL,BlkEC,L,C,NL,LastLen);
 For I:=1 To 8 Do If BkOn[I] Then AdjIns(BkL[I],BkC[I],L,C,NL,LastLen);
 For I:=1 To AsmErrors Do If I<=MAXERR Then If ErrWin[I]=EActW Then Begin
  T:=ErrLn[I];C0:=1;
  AdjIns(T,C0,L,C,NL,LastLen);
  ErrLn[I]:=T;
 End;
End;

Procedure EdAdjDel(L1,C1,L2,C2: Integer);
Var I,T,C0: Integer;
Begin
 If BlkSOk Then AdjDel(BlkSL,BlkSC,L1,C1,L2,C2);
 If BlkEOk Then AdjDel(BlkEL,BlkEC,L1,C1,L2,C2);
 For I:=1 To 8 Do If BkOn[I] Then AdjDel(BkL[I],BkC[I],L1,C1,L2,C2);
 For I:=1 To AsmErrors Do If I<=MAXERR Then If ErrWin[I]=EActW Then Begin
  T:=ErrLn[I];C0:=1;
  AdjDel(T,C0,L1,C1,L2,C2);
  ErrLn[I]:=T;
 End;
End;

Function SetLine(I: Integer; Const S: String): Boolean;
Var Delta: LongInt;
Begin
 Delta:=Length(S)-Length(Ed^[I]^);
 If (Delta>0) And (Delta>MemFree) Then Begin
  Alert1(3,T3('Out of text memory|Increase the text buf'+
    'fer|in Options|Preferences',
              'Memoire texte pleine|Augmentez le tampon'+
                ' texte|dans Options|Preferences',
              'Textspeicher voll|Textpuffer erhoehen|in'+
                ' Optionen|Einstellungen'));
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
  Alert1(3,T3('Out of text memory','Memoire texte pleine',
    'Textspeicher voll'));Exit;
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
 If CurC<=Length(Ed^[CurL]^) Then CurV:=0;
 V:=V+CurV;
 If V<LeftV Then LeftV:=V;
 If V>=LeftV+TXT_COLS Then LeftV:=V-TXT_COLS+1;
 If LeftV<0 Then LeftV:=0;
End;

{ 0 : pas de bloc ; 1 : bloc valide ; 2 : debut apres la fin }
Function BlockState: Integer;
Begin
 If Not (BlkSOk And BlkEOk) Then BlockState:=0
 Else If (BlkSL=BlkEL) And (BlkSC=BlkEC) Then BlockState:=0
 Else If (BlkSL>BlkEL) Or ((BlkSL=BlkEL) And (BlkSC>BlkEC)) Then BlockState:=2
 Else BlockState:=1;
End;

Function BlockOk: Boolean;
Begin
 BlockOk:=BlockState=1;
End;

{ True si le bloc est utilisable ; sinon message dans la ligne d'etat }
Function BlockCheck: Boolean;
Var S: Integer;
Begin
 S:=BlockState;
 BlockCheck:=S=1;
 If S=0 Then StatusErr(T3('What blocks!','Quel bloc !','Welcher Block!'))
 Else If S=2 Then
   StatusErr(T3('Invalid block!','Bloc invalide !','Ungueltiger Block!'));
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
 InfoText:='Line:'+PadL(IntStr(CurL),4)+' Col:'+PadL(IntStr(VisOf(Ed^[CurL]^,
   CurC)+CurV+1),3)+
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
Var L: Integer; S,E,Seg: String; Y,V1,V2,SL,SC,EL,EC,X1,X2: Integer; Vis:
  String;
 { surbrillance de la zone (SL,SC)-(EL,EC) sur la ligne L }
 Procedure Hilite(SL,SC,EL,EC: Integer);
 Begin
  If (L>=SL) And (L<=EL) Then Begin
   If L=SL Then V1:=VisOf(S,SC) Else V1:=0;
   If L=EL Then V2:=VisOf(S,EC) Else V2:=Length(E)+1;
   If (L<EL) And (V2<=V1) Then V2:=V1+1;
   X1:=V1-LeftV;X2:=V2-LeftV;
   If X1<0 Then X1:=0;
   If X2>TXT_COLS Then X2:=TXT_COLS;
   If X2>X1 Then Begin
    Box(TX0+X1*FontCW,Y,TX0+X2*FontCW-1,Y+FontLH-1,INK);
    Seg:=Copy(E+' ',LeftV+X1+1,X2-X1);
    EText(TX0+X1*FontCW,Y,Seg,PAPER);
   End;
  End;
 End;
Begin
 Y:=TY0+Row*FontLH;
 Box(WX1+1,Y,TXT_X2,Y+FontLH-1,PAPER);
 L:=TopL+Row;
 If L>EdN Then Exit;
 S:=Ed^[L]^;
 E:=Expand(S);
 Vis:=Copy(E,LeftV+1,TXT_COLS);
 EText(TX0,Y,Vis,INK);
 If BlockOk And ((L<>EditLine) Or Not DrawingAct) Then Begin
  BlockOrder(SL,SC,EL,EC);
  Hilite(SL,SC,EL,EC);
 End;
 If HiOn And DrawingAct And (L=HiL) Then Hilite(HiL,HiC,HiL,HiC+HiLen);
End;

Procedure DrawCursor(On: Boolean);
Var Row,V,X,Y: Integer; Ch: String;
Begin
 Row:=CurL-TopL;
 If (Row<0) Or (Row>=TXT_ROWS) Then Exit;
 V:=VisOf(Ed^[CurL]^,CurC)+CurV-LeftV;
 If (V<0) Or (V>=TXT_COLS) Then Exit;
 X:=TX0+V*FontCW;Y:=TY0+Row*FontLH;
 HideMouse;
 If On Then Begin
  Ch:=Copy(Ed^[CurL]^,CurC,1);
  If (Ch=#9) Or (Ch='') Then Ch:=' ';
  If Not EdIns Then Begin
   Box(X,Y+FontLH-3,X+FontCW-1,Y+FontLH-1,INK);
  End Else If (PrefFlash=2) Or (PrefFlash=4) Then Begin
   Box(X,Y,X+1,Y+FontLH-1,INK);
  End Else Begin
   Box(X,Y,X+FontCW-1,Y+FontLH-1,INK);
   EText(X,Y,Ch,PAPER);
  End;
 End Else DrawTextLine(Row);
 ShowMouseU;
End;

{ dessine la fenetre dont les donnees sont dans les variables globales }
Procedure DrawWindow(Active: Boolean);
Var R,MW: Integer; T,M: String;
Begin
 DrawingAct:=Active;
 If Active And (EditLine<>0) And (EditLine<>CurL) Then EditLine:=0;
 Box(WX1,WY1,WX2,WY2,PAPER);
 If EdFile<>'' Then T:=EdFile Else T:=T3('Untitled','Sans titre','Ohne Titel');
 TitleInactive:=Not Active;
 GemTitleBar(WX1,WY1,WX2,WY1+TITLE_H-1,T,True);
 TitleInactive:=False;
 { ligne d'information : Line / Col / Mem puis messages }
 Box(WX1,INFO_Y,WX2,INFO_Y+INFO_H,PAPER);
 If Active And (StatusMsg<>'') Then Begin
  { message : a droite de Line/Col ; s'il est long il prend la place de Mem }
  M:=InfoText+'  ';
  MW:=(WX2-WX1-16) Div 8;
  If Length(StatusMsg)>MW-Length(M)-1 Then M:=Copy(M,1,17)+'  ';
  PText(WX1+8,INFO_Y+3,M);
  R:=MW-Length(M)-1;
  If Length(StatusMsg)>R Then
    PText(WX1+8+Length(M)*8,INFO_Y+3,Copy(StatusMsg,1,R-3)+'...')
  Else PText(WX1+8+Length(M)*8,INFO_Y+3,StatusMsg);
 End Else Begin
  PText(WX1+8,INFO_Y+3,InfoText);
  If EdMod Then PText(WX2-90,INFO_Y+3,T3('modified','modifie','geaendert'));
  If (Not EdIns) And Active Then PText(WX2-170,INFO_Y+3,'OVR');
 End;
 SetColor(INK);
 Line(WX1,INFO_Y+INFO_H,WX2,INFO_Y+INFO_H);
 Frame(WX1,WY1,WX2,WY2);
 For R:=0 To TXT_ROWS-1 Do DrawTextLine(R);
 DrawScrollBars;
End;

{ bureau + toutes les fenetres, de l'arriere vers l'avant }
Procedure DrawEditor;
Var Z: Integer;
Begin
 If (ENWin=1) And (EWins[EZOrd[1]].X1=0) And (EWins[EZOrd[1]].X2=SCR_W-1) And
   (EWins[EZOrd[1]].Y1<=DESK_Y) And
    (EWins[EZOrd[1]].Y2>=SCR_H-1) Then Begin
  DrawWindow(True);
  Exit;
 End;
 PatBar(0,MENU_H,SCR_W-1,SCR_H-1,PatGrey);
 EWinStore(EActW);
 For Z:=1 To ENWin Do Begin
  EWinLoad(EZOrd[Z]);
  DrawWindow(Z=ENWin);
 End;
 EWinLoad(EActW);
 DrawingAct:=True;
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
Var S: String; Ins: Boolean;
Begin
 S:=Ed^[CurL]^;
 If Length(S)>=250 Then Begin
  StatusErr(T3('Line too long','Ligne trop longue','Zeile zu lang'));Exit;
 End;
 EditLine:=CurL;
 Ins:=EdIns Or (CurC>Length(S));
 If Ins Then Insert(Ch,S,CurC) Else S[CurC]:=Ch;
 If SetLine(CurL,S) Then Begin
  If Ins Then EdAdjIns(CurL,CurC,1,1);
  Inc(CurC);
 End;
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
  While (I<=Length(S)) And ((S[I]=' ') Or (S[I]=#9)) Do Begin
    Ind:=Ind+S[I];Inc(I);End;
 End;
 If Not SetLine(CurL,S) Then Exit;
 If Not InsLineAt(CurL+1,Ind+Rest) Then Exit;
 EdAdjIns(CurL,CurC,2,Length(Ind));
 Inc(CurL);CurC:=Length(Ind)+1;
 EnsureVisible;
 WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure DoBackspace;
Var S: String; P: String;
Begin
 EditLine:=CurL;
 If CurC>1 Then Begin
  S:=Ed^[CurL]^;
  Delete(S,CurC-1,1);
  If SetLine(CurL,S) Then Begin EdAdjDel(CurL,CurC-1,CurL,CurC);Dec(CurC);End;
 End Else If CurL>1 Then Begin
  P:=Ed^[CurL-1]^;
  S:=Ed^[CurL]^;
  If Length(P)+Length(S)>250 Then Begin
   StatusErr(T3('Line too long','Ligne trop longue','Zeile zu lang'));Exit;
  End;
  Dec(CurL);
  CurC:=Length(P)+1;
  If SetLine(CurL,P+S) Then Begin
   DelLineAt(CurL+1);
   EdAdjDel(CurL,CurC,CurL+1,1);
  End;
 End;
 EnsureVisible;
 WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure DoDelete;
Var S: String;
Begin
 EditLine:=CurL;
 S:=Ed^[CurL]^;
 If CurC<=Length(S) Then Begin
  Delete(S,CurC,1);
  If SetLine(CurL,S) Then EdAdjDel(CurL,CurC,CurL,CurC+1);
 End Else If CurL<EdN Then Begin
  S:=S+Ed^[CurL+1]^;
  If Length(S)>250 Then Begin
   StatusErr(T3('Line too long','Ligne trop longue','Zeile zu lang'));Exit;
  End;
  If SetLine(CurL,S) Then Begin
   DelLineAt(CurL+1);
   EdAdjDel(CurL,CurC,CurL+1,1);
  End;
 End;
 EnsureVisible;
End;

Procedure DoTab;
Var S: String; V: Integer;
Begin
 EditLine:=CurL;
 S:=Ed^[CurL]^;
 If Length(S)>=250 Then Begin
  StatusErr(T3('Line too long','Ligne trop longue','Zeile zu lang'));Exit;
 End;
 Insert(#9,S,CurC);
 If SetLine(CurL,S) Then Begin EdAdjIns(CurL,CurC,1,1);Inc(CurC);End;
 EnsureVisible;
 V:=0;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

{ Ctrl-Y : supprime la ligne courante (conservee pour Ctrl-U) }
Procedure DeleteCurLine;
Var Len: Integer;
Begin
 UndelS:=Ed^[CurL]^;UndelOk:=True;UndelEnd:=(CurL=EdN) And (EdN>1);
 Len:=Length(Ed^[CurL]^);
 If CurL<EdN Then EdAdjDel(CurL,1,CurL+1,1)
 Else If CurL>1 Then EdAdjDel(CurL-1,Length(Ed^[CurL-1]^)+1,CurL,Len+1)
 Else EdAdjDel(1,1,1,Len+1);
 DelLineAt(CurL);
 If CurL>EdN Then CurL:=EdN;
 CurC:=1;
 EnsureVisible;
 WantV:=0;
End;

{ Ctrl-@ : supprime du curseur a la fin de la ligne (conserve pour Ctrl-U) }
Procedure DeleteToEol;
Var S: String;
Begin
 S:=Ed^[CurL]^;
 If CurC>Length(S) Then Exit;
 UndelS:=Copy(S,CurC,255);UndelOk:=True;UndelEnd:=False;
 EditLine:=CurL;
 If SetLine(CurL,Copy(S,1,CurC-1)) Then EdAdjDel(CurL,CurC,CurL,Length(S)+1);
 EnsureVisible;
End;

{ Ctrl-U / Undo : reinsere la derniere ligne supprimee a la position du curseur
  }
Procedure UndeleteLine;
Begin
 If Not UndelOk Then Exit;
 If UndelEnd And (CurL=EdN) Then Begin
  If Not InsLineAt(CurL+1,UndelS) Then Exit;
  Inc(CurL);
 End Else Begin
  If Not InsLineAt(CurL,UndelS) Then Exit;
  EdAdjIns(CurL,1,2,0);
 End;
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

{ Deplacements du curseur avec les messages Top of file / End of file }
{ apres un deplacement vertical : si la colonne souhaitee depasse la fin de
  ligne, le curseur reste
  a droite du texte (colonnes virtuelles) }
Procedure SetVirt;
Begin
 If CurC>Length(Ed^[CurL]^) Then Begin
  CurV:=WantV-VisOf(Ed^[CurL]^,CurC);
  If CurV<0 Then CurV:=0;
 End Else CurV:=0;
End;

Procedure CurUp;
Begin
 If CurL>1 Then Begin
  Dec(CurL);CurC:=CharOfVis(Ed^[CurL]^,WantV);
  SetVirt;
  EnsureVisible;
 End Else StatusErr(T3('Top of file','Debut du fichier','Dateianfang'));
End;

Procedure CurDown;
Begin
 If CurL<EdN Then Begin
  Inc(CurL);CurC:=CharOfVis(Ed^[CurL]^,WantV);
  SetVirt;
  EnsureVisible;
 End Else StatusErr(T3('End of file','Fin du fichier','Dateiende'));
End;

Procedure CurLeft;
Begin
 If CurC>1 Then Dec(CurC)
 Else If (PrefStopEol=0) And (CurL>1) Then Begin
   Dec(CurL);CurC:=Length(Ed^[CurL]^)+1;End;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure CurRight;
Begin
 If CurC<=Length(Ed^[CurL]^) Then Inc(CurC)
 Else If (PrefStopEol=0) And (CurL<EdN) Then Begin Inc(CurL);CurC:=1;End;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

Procedure CurPageUp;
Begin
 CurL:=Max2(1,CurL-TXT_ROWS+1);TopL:=Max2(1,TopL-TXT_ROWS+1);
 CurC:=CharOfVis(Ed^[CurL]^,WantV);SetVirt;EnsureVisible;
End;

Procedure CurPageDown;
Begin
 CurL:=Min2(EdN,CurL+TXT_ROWS-1);
 If TopL+TXT_ROWS-1<EdN Then TopL:=Min2(EdN,TopL+TXT_ROWS-1);
 CurC:=CharOfVis(Ed^[CurL]^,WantV);SetVirt;EnsureVisible;
End;

{ ")" tape : le curseur saute un instant sur la "(" correspondante }
Procedure ShowMatchingParen;
Var L,C,D: Integer; S: String; Found: Boolean; SL,SC: Integer;
Begin
 SL:=CurL;SC:=CurC;
 L:=CurL;C:=CurC-2;D:=0;Found:=False;
 While (L>=1) And (L>=CurL-100) And Not Found Do Begin
  S:=Ed^[L]^;
  If L<>CurL Then C:=Length(S);
  While (C>=1) And Not Found Do Begin
   If S[C]=')' Then Inc(D)
   Else If S[C]='(' Then Begin
    If D=0 Then Found:=True Else Dec(D);
   End;
   If Not Found Then Dec(C);
  End;
  If Not Found Then Dec(L);
 End;
 If Found Then Begin
  MoveCur(L,C);
  DrawAll;
  Delay(350);
  MoveCur(SL,SC);
  NeedDraw:=True;
 End;
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

{ Place le texte du bloc (valide) dans Arr[1..N] }
Procedure ExtractBlock(Arr: PLineArr; Var N: Integer);
Var SL,SC,EL,EC,L: Integer; S: String;
Begin
 BlockOrder(SL,SC,EL,EC);
 N:=0;
 For L:=SL To EL Do Begin
  S:=Ed^[L]^;
  If L=EL Then S:=Copy(S,1,EC-1);
  If L=SL Then S:=Copy(S,SC,255);
  If N<MAXLN Then Begin Inc(N);Arr^[N]:=NewStr(S);End;
 End;
End;

{ Remember Block / Copy : le bloc va dans le presse-papiers }
Procedure CopyBlock;
Begin
 If Not BlockCheck Then Exit;
 ClipFree;
 ExtractBlock(ClipLn,ClipN);
End;

{ Delete Block / Cut : le bloc est supprime et conserve dans le presse-papiers }
Procedure DeleteBlock;
Var SL,SC,EL,EC,L: Integer; S: String;
Begin
 If Not BlockCheck Then Exit;
 ClipFree;
 ExtractBlock(ClipLn,ClipN);
 BlockOrder(SL,SC,EL,EC);
 S:=Copy(Ed^[SL]^,1,SC-1)+Copy(Ed^[EL]^,EC,255);
 If SetLine(SL,S) Then Begin
  For L:=EL Downto SL+1 Do DelLineAt(L);
  EdAdjDel(SL,SC,EL,EC);
  CurL:=SL;CurC:=SC;
 End;
 ClearBlock;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
End;

{ Insere les lignes Arr[1..N] a la position du curseur }
Function InsertLinesAtCursor(Arr: PLineArr; N: Integer): Boolean;
Var I: Integer; S,Tail: String; LastLen: Integer;
Begin
 InsertLinesAtCursor:=False;
 If N=0 Then Exit;
 S:=Ed^[CurL]^;
 Tail:=Copy(S,CurC,255);
 LastLen:=Length(Arr^[N]^);
 If N=1 Then Begin
  If Length(S)+LastLen>250 Then Begin
   StatusErr(T3('Line too long','Ligne trop longue','Zeile zu lang'));Exit;
  End;
  S:=Copy(S,1,CurC-1)+Arr^[1]^+Tail;
  If Not SetLine(CurL,S) Then Exit;
  EdAdjIns(CurL,CurC,1,LastLen);
  CurC:=CurC+LastLen;
 End Else Begin
  If Not SetLine(CurL,Copy(S,1,CurC-1)+Arr^[1]^) Then Exit;
  For I:=2 To N-1 Do
   If Not InsLineAt(CurL+I-1,Arr^[I]^) Then Exit;
  If Not InsLineAt(CurL+N-1,Arr^[N]^+Tail) Then Exit;
  EdAdjIns(CurL,CurC,N,LastLen);
  CurL:=CurL+N-1;
  CurC:=LastLen+1;
 End;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
 InsertLinesAtCursor:=True;
End;

{ Paste Block : le contenu du presse-papiers est insere au curseur }
Procedure PasteBlock;
Begin
 If ClipN=0 Then Begin
  StatusErr(T3('Block buffer is empty','Le tampon de bloc est vide',
    'Blockpuffer ist leer'));Exit;
 End;
 EditLine:=CurL;
 InsertLinesAtCursor(ClipLn,ClipN);
End;

{ Copy Block (F4) : copie du bloc a la position du curseur (presse-papiers
  intact) }
Procedure DupBlock;
Var SL,SC,EL,EC,N,I: Integer; Tmp: PLineArr;
Begin
 If Not BlockCheck Then Exit;
 BlockOrder(SL,SC,EL,EC);
 If ((CurL>SL) Or ((CurL=SL) And (CurC>SC))) And ((CurL<EL) Or ((CurL=EL) And
   (CurC<EC))) Then Begin
  StatusErr(T3('Invalid block!','Bloc invalide !','Ungueltiger Block!'));Exit;
 End;
 New(Tmp);
 ExtractBlock(Tmp,N);
 EditLine:=CurL;
 InsertLinesAtCursor(Tmp,N);
 For I:=1 To N Do FreeStr(Tmp^[I]);
 Dispose(Tmp);
End;

Procedure SelectAll;
Begin
 BlkSL:=1;BlkSC:=1;BlkEL:=EdN;BlkEC:=Length(Ed^[EdN]^)+1;
 BlkSOk:=True;BlkEOk:=True;
End;

Procedure SetBlockStart;
Begin
 BlkSL:=CurL;BlkSC:=CurC;BlkSOk:=True;
End;

Procedure SetBlockEnd;
Begin
 BlkEL:=CurL;BlkEC:=CurC;BlkEOk:=True;
End;

{ Print Block : le bloc (ou tout le fichier) est envoye a PRINTER.OUT }
Procedure PrintBlock;
Var T: Text; I,N: Integer; SL,SC,EL,EC: Integer; S: String;
Begin
 If BlkSOk Or BlkEOk Then Begin
  If Not BlockCheck Then Exit;
 End;
 If AlertBox(2,T3('Print the block ?|(whole file if no bloc'+'k)',
   'Imprimer le bloc ?|(tout le fichier sans'+' bloc)',
   'Block drucken ?|(ganze Datei ohne Block)'),
   T3('Cancel|OK','Annuler|OK','Abbruch|OK'),2)<>2 Then Exit;
 Assign(T,'PRINTER.OUT');
 {$I-}
 Append(T);
 If IOResult<>0 Then Rewrite(T);
 {$I+}
 If IOResult<>0 Then Begin
   StatusErr(T3('Cannot print','Impression impossible',
   'Drucken nicht moeglich'));Exit;End;
 If BlockOk Then BlockOrder(SL,SC,EL,EC) Else Begin
   SL:=1;SC:=1;EL:=EdN;EC:=Length(Ed^[EdN]^)+1;End;
 If (EC=1) And (EL>SL) Then Begin Dec(EL);EC:=Length(Ed^[EL]^)+1;End;
 For I:=SL To EL Do Begin
  N:=1;
  If I=SL Then N:=SC;
  S:=Copy(Ed^[I]^,N,255);
  If I=EL Then S:=Copy(S,1,EC-N);
  WriteLn(T,Expand(S));
 End;
 Close(T);
End;

{ ---------------------------------------------------------------------- }
{ Fichiers                                                                 }
{ ---------------------------------------------------------------------- }

{ Append=False : remplace le texte (Load) ; Append=True : insere le fichier a la
  position du curseur (Insert File) }
Function EdLoadFile(Const Name: String; Append: Boolean): Boolean;
Var Arr: PLineArr; Cnt,I: Integer; Tot: LongInt;
Begin
 EdLoadFile:=False;
 If Not LoadLines(Name,Arr,Cnt) Then Begin
  Alert1(3,T3('Cannot open file|','Impossible d''ouvrir le fichier|',
    'Datei nicht lesbar|')+ShortName(Name));
  Exit;
 End;
 Tot:=0;
 For I:=1 To Cnt Do Tot:=Tot+Length(Arr^[I]^)+1;
 If Tot>PrefBuf-12-EdMem Then Begin
  Alert1(3,T3('File too large for the text buffer|Incre'+
    'ase it in Options|Preferences',
              'Fichier trop grand pour le tampon texte|'+
                'Augmentez-le dans Options|Preferences',
              'Datei zu gross fuer den Textpuffer|In Op'+
                'tionen erhoehen|Einstellungen'));
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
  ErrForget(EActW);
 End Else Begin
  InsertLinesAtCursor(Arr,Cnt);
  FreeLines(Arr,Cnt);
 End;
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
  Alert1(3,T3('Cannot write file|','Impossible d''ecrire le fichier|',
    'Datei nicht schreibbar|')+ShortName(Name));
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

{ Save Block : le bloc est ecrit tel quel (pas de sauvegarde .BAK,
  presse-papiers intact) }
Function SaveBlockFile(Const Name: String): Boolean;
Var F: File; I,N: Integer; S: String; Tmp: PLineArr;
Begin
 SaveBlockFile:=False;
 If Not BlockCheck Then Exit;
 Assign(F,Name);
 {$I-}
 Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Exit;
 New(Tmp);
 ExtractBlock(Tmp,N);
 For I:=1 To N Do Begin
  S:=Tmp^[I]^+#13#10;
  BlockWrite(F,S[1],Length(S));
  FreeStr(Tmp^[I]);
 End;
 Dispose(Tmp);
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

{ derniere occurrence commencant strictement avant (L,C) }
Function FindBack(L,C: Integer; Const Pat: String; Var FL,FC: Integer): Boolean;
Var S,P: String; I,K,Lim: Integer;
Begin
 FindBack:=False;
 If Pat='' Then Exit;
 If FindCase Then P:=Pat Else P:=Upper(Pat);
 For I:=L Downto 1 Do Begin
  S:=Ed^[I]^;
  If Not FindCase Then S:=Upper(S);
  If I=L Then Lim:=C-1 Else Lim:=Length(S)+1;
  If Lim>Length(S)-Length(P)+1 Then Lim:=Length(S)-Length(P)+1;
  For K:=Lim Downto 1 Do
   If Copy(S,K,Length(P))=P Then Begin FL:=I;FC:=K;FindBack:=True;Exit;End;
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

Procedure ShowFound(FL,FC: Integer);
Begin
 MoveCur(FL,FC);
 If (FL<TopL) Or (FL>=TopL+TXT_ROWS) Then Begin
  TopL:=FL-TXT_ROWS Div 2;If TopL<1 Then TopL:=1;
 End;
 EnsureVisible;
 HiOn:=True;HiL:=FL;HiC:=FC;HiLen:=Length(FindStr);
 FoundL:=FL;FoundC:=FC;
End;

{ Find Next / dialogue Find : Incl = la recherche part du curseur lui-meme }
Procedure FindForward(Incl: Boolean);
Var FL,FC,SC: Integer;
Begin
 If FindStr='' Then Exit;
 SC:=CurC;
 If Incl And (FoundL=CurL) And (FoundC=CurC) Then Incl:=False;
 If Not Incl Then Inc(SC);
 If FindFrom(CurL,SC,FindStr,FL,FC) Then ShowFound(FL,FC)
 Else StatusErr(T3('Not found','Introuvable','Nicht gefunden'));
End;

Procedure FindPrevious;
Var FL,FC: Integer;
Begin
 If FindStr='' Then Exit;
 If FindBack(CurL,CurC,FindStr,FL,FC) Then ShowFound(FL,FC)
 Else StatusErr(T3('Not found','Introuvable','Nicht gefunden'));
End;

Procedure DoFindNext;
Begin
 FindForward(False);
End;

{ Dialogue Find / Replace (Alt-F) : champs Find et Replace, casse,
  Cancel/Previous/Next }
Procedure DoFind;
Var R,F,Rp,Pc: Integer;
Begin
 DlgReset(62,7);
 DlgLabel(1,0,T3('Find','Chercher','Suchen'));
 DlgLabel(1,1,T3('Find:','Chercher:','Suchen:'));
 F:=DlgEditX(10,1,48,60,FindStr);
 DlgLabel(1,2,T3('Replace:','Remplacer:','Ersetzen:'));
 Rp:=DlgEditX(10,2,48,60,ReplStr);
 DlgLabel(1,4,T3('Casing:','Casse:','Gr/Kl:'));
 Pc:=DlgPopup(10,4,14,'test=Test|test<>Test',1+Ord(FindCase));
 DlgButton(2,6,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(24,6,12,T3('Previous','Precedent','Vorheriges'),2,False);
 DlgButton(42,6,12,T3('Next','Suivant','Weiter'),1,True);
 R:=DlgRun;
 If R=0 Then Exit;
 FindStr:=DI[F].Val;
 ReplStr:=DI[Rp].Val;
 FindCase:=DI[Pc].Sel=2;
 If R=1 Then FindForward(True) Else FindPrevious;
End;

Function MatchAt(L,C: Integer): Boolean;
Var S,P: String;
Begin
 MatchAt:=False;
 If FindStr='' Then Exit;
 S:=Copy(Ed^[L]^,C,Length(FindStr));
 P:=FindStr;
 If Not FindCase Then Begin S:=Upper(S);P:=Upper(P);End;
 MatchAt:=(S=P) And (Length(S)=Length(FindStr));
End;

{ remplace l'occurrence (FL,FC) ; True si possible }
Function ReplaceAt(FL,FC: Integer): Boolean;
Var S: String;
Begin
 ReplaceAt:=False;
 S:=Ed^[FL]^;
 Delete(S,FC,Length(FindStr));
 Insert(ReplStr,S,FC);
 If Length(S)>250 Then Begin
  StatusErr(T3('Line too long','Ligne trop longue','Zeile zu lang'));Exit;
 End;
 If Not SetLine(FL,S) Then Exit;
 EdAdjDel(FL,FC,FL,FC+Length(FindStr));
 If ReplStr<>'' Then EdAdjIns(FL,FC,1,Length(ReplStr));
 ReplaceAt:=True;
End;

{ Replace (Alt-R) : remplace l'occurrence trouvee puis cherche la suivante }
Procedure DoReplace;
Var FL,FC: Integer;
Begin
 If FindStr='' Then Begin DoFind;Exit;End;
 If MatchAt(CurL,CurC) Then Begin
  If ReplaceAt(CurL,CurC) Then Begin
   CurC:=CurC+Length(ReplStr);
   EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
   If FindFrom(CurL,CurC,FindStr,FL,FC) Then ShowFound(FL,FC)
   Else StatusErr(T3('Not found','Introuvable','Nicht gefunden'));
  End;
 End Else FindForward(True);
End;

{ Replace All : a partir du curseur ; Echap abandonne ; le nombre de
  remplacements est indique dans la ligne d'etat }
Procedure DoReplaceAll;
Var FL,FC,N: Integer; Esc: Boolean; Ch: Char;
Begin
 If FindStr='' Then Begin DoFind;Exit;End;
 N:=0;Esc:=False;
 FL:=CurL;FC:=CurC;
 While (Not Esc) And FindFrom(FL,FC,FindStr,FL,FC) Do Begin
  If Not ReplaceAt(FL,FC) Then Break;
  Inc(N);
  FC:=FC+Length(ReplStr);
  CurL:=FL;CurC:=FC;
  If KeyPressed Then Begin
   Ch:=ReadKey;
   If Ch=#27 Then Esc:=True Else If Ch=#0 Then Ch:=ReadKey;
  End;
 End;
 EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);
 If N=0 Then StatusErr(T3('Not found','Introuvable','Nicht gefunden'))
 Else Begin
  StatusMsg:=IntStr(N)+T3(' replacement(s)',' remplacement(s)',
    ' Ersetzung(en)');
  If Esc Then SoundBell;
 End;
 NeedDraw:=True;
End;

Procedure DoGotoLine;
Var S: String; V: LongInt;
Begin
 S:='';
 If InputDlgF(T3('Goto line','Aller a la ligne','Gehe zu Zeile'),T3('Line:',
   'Ligne :','Zeile:'),S,6,1) Then Begin
  V:=ToInt(S);
  If V>EdN Then StatusErr(T3('End of file','Fin du fichier','Dateiende'))
  Else GotoLine(V);
 End;
End;

{ ---------------------------------------------------------------------- }
{ Signets                                                                   }
{ ---------------------------------------------------------------------- }

Procedure SetBookmark(N: Integer);
Begin
 If (N<1) Or (N>8) Then Exit;
 BkL[N]:=CurL;BkC[N]:=CurC;BkOn[N]:=True;
End;

Procedure GotoBookmark(N: Integer);
Begin
 If (N<1) Or (N>8) Then Exit;
 If Not BkOn[N] Then Exit;
 MoveCur(BkL[N],BkC[N]);
 If (CurL<TopL) Or (CurL>=TopL+TXT_ROWS) Then Begin
  TopL:=CurL-TXT_ROWS Div 2;If TopL<1 Then TopL:=1;
 End;
 EnsureVisible;
End;

{ ---------------------------------------------------------------------- }
{ Preferences et fichier de configuration                                   }
{ ---------------------------------------------------------------------- }

Const
 CFG_NAME = 'HISOFTED.INF';
 CFG_OLD  = 'DEVPAC.INF';

{ reglages supplementaires geres par p13 (police, fenetres, outils,
  environnement...) }
Procedure CfgWriteExtra(Var T: Text); Forward;
Function CfgReadExtra(Const K,V: String): Boolean; Forward;

Procedure PrefDefaults;
Begin
 PrefTab:=8;PrefBuf:=60000;PrefNumPad:=1;PrefBackup:=1;PrefIndent:=1;
 PrefFlash:=1;PrefLoadMon:=2;
 PrefAutoSave:=0;PrefHideMouse:=0;PrefMatch:=0;PrefStopEol:=0;
 PrefSaveQuit:=3;PrefSaveRun:=3;
End;

{ Cherche un fichier de reglages : repertoire courant, repertoire du programme,
  puis les repertoires de la variable PATH ; '' si introuvable }
Function FindCfg(Const Name: String): String;
Var P,D: String; I: Integer; Sep: Char;
Begin
 FindCfg:='';
 If FileExists(Name) Then Begin FindCfg:=Name;Exit;End;
 D:=PathOf(ParamStr(0));
 If (D<>'') And FileExists(D+Name) Then Begin FindCfg:=D+Name;Exit;End;
 P:=GetEnv('PATH');
 {$IFDEF UNIX}
 Sep:=':';
 {$ELSE}
 Sep:=';';
 {$ENDIF}
 While P<>'' Do Begin
  I:=Pos(Sep,P);
  If I=0 Then Begin D:=P;P:='';End Else Begin
    D:=Copy(P,1,I-1);Delete(P,1,I);End;
  If D<>'' Then Begin
   D:=NormDir(D);
   If FileExists(D+Name) Then Begin FindCfg:=D+Name;Exit;End;
  End;
 End;
End;

Procedure SavePrefsTo(Const Name: String);
Var T: Text;
Begin
 Assign(T,Name);
 {$I-}
 Rewrite(T);
 {$I+}
 If IOResult<>0 Then Begin
  Alert1(3,T3('Cannot write file|','Impossible d''ecrire le fichier|',
    'Datei nicht schreibbar|')+ShortName(Name));
  Exit;
 End;
 WriteLn(T,'TAB=',PrefTab);
 WriteLn(T,'BUFFER=',PrefBuf);
 WriteLn(T,'KEYPAD=',PrefNumPad);
 WriteLn(T,'BACKUP=',PrefBackup);
 WriteLn(T,'INDENT=',PrefIndent);
 WriteLn(T,'CURSOR=',PrefFlash);
 WriteLn(T,'AUTOSAVE=',PrefAutoSave);
 WriteLn(T,'HIDEMOUSE=',PrefHideMouse);
 WriteLn(T,'MATCH=',PrefMatch);
 WriteLn(T,'STOPEOL=',PrefStopEol);
 WriteLn(T,'SAVEQUIT=',PrefSaveQuit);
 WriteLn(T,'SAVERUN=',PrefSaveRun);
 WriteLn(T,'TODISK=',Ord(OptToDisk));
 WriteLn(T,'DEBUG=',Ord(OptDebug));
 WriteLn(T,'LISTING=',Ord(OptListing));
 WriteLn(T,'OPTIMIZE=',Ord(OptOptimize));
 WriteLn(T,'CASE=',Ord(OptCase));
 WriteLn(T,'RUNGEM=',Ord(OptRunGem));
 WriteLn(T,'ACC=',Ord(OptAccs));
 WriteLn(T,'INCPATH=',OptIncPath);
 WriteLn(T,'RUNDIR=',RunDirMode);
 WriteLn(T,'OUTNAME=',CfgOutName);
 WriteLn(T,'LISTNAME=',CfgListName);
 WriteLn(T,'WARN=',Ord(OptWarnings));
 WriteLn(T,'ASMTAB=',OptTabSize);
 CfgWriteExtra(T);
 Close(T);
End;

{ Save preferences : le fichier est ecrit la ou il a ete trouve, sinon dans le
  repertoire courant }
Procedure SavePrefs;
Begin
 If CfgFile='' Then CfgFile:=CFG_NAME;
 SavePrefsTo(CfgFile);
End;

Function Flag01(Const V: String): Integer;
Begin
 If ToInt(V)<>0 Then Flag01:=1 Else Flag01:=0;
End;

Procedure LoadPrefsFrom(Const Name: String);
Var T: Text; S,K,V: String; P: Integer; Legacy: Boolean;
Begin
 Legacy:=Upper(ShortName(Name))=CFG_OLD;
 Assign(T,Name);
 {$I-}
 Reset(T);
 {$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(T) Do Begin
  ReadLn(T,S);
  P:=Pos('=',S);
  If P>0 Then Begin
   K:=Upper(Copy(S,1,P-1));V:=Copy(S,P+1,200);
   If K='TAB' Then PrefTab:=Clamp(ToInt(V),2,16)
   Else If K='BUFFER' Then PrefBuf:=Clamp(ToInt(V),4000,999000)
   Else If K='KEYPAD' Then PrefNumPad:=Flag01(V)
   Else If K='BACKUP' Then PrefBackup:=Flag01(V)
   Else If K='INDENT' Then PrefIndent:=Flag01(V)
   Else If K='CURSOR' Then Begin
    PrefFlash:=Clamp(ToInt(V),1,4);
    If Legacy And (PrefFlash=2) Then PrefFlash:=3;
   End
   Else If K='AUTOSAVE' Then PrefAutoSave:=Flag01(V)
   Else If K='HIDEMOUSE' Then PrefHideMouse:=Flag01(V)
   Else If K='MATCH' Then PrefMatch:=Flag01(V)
   Else If K='STOPEOL' Then PrefStopEol:=Flag01(V)
   Else If K='SAVEQUIT' Then PrefSaveQuit:=Clamp(ToInt(V),1,3)
   Else If K='SAVERUN' Then PrefSaveRun:=Clamp(ToInt(V),1,3)
   Else If K='TODISK' Then OptToDisk:=ToInt(V)=1
   Else If K='DEBUG' Then OptDebug:=ToInt(V)=1
   Else If K='LISTING' Then OptListing:=ToInt(V)=1
   Else If K='OPTIMIZE' Then OptOptimize:=ToInt(V)=1
   Else If K='CASE' Then OptCase:=ToInt(V)=1
   Else If K='RUNGEM' Then OptRunGem:=ToInt(V)=1
   Else If K='ACC' Then OptAccs:=ToInt(V)=1
   Else If K='INCPATH' Then OptIncPath:=V
   Else If K='RUNDIR' Then RunDirMode:=Clamp(ToInt(V),1,2)
   Else If K='OUTNAME' Then Begin CfgOutName:=V;OptOutName:=V;End
   Else If K='LISTNAME' Then Begin CfgListName:=V;OptListName:=V;End
   Else If K='WARN' Then OptWarnings:=ToInt(V)=1
   Else If K='ASMTAB' Then OptTabSize:=Clamp(ToInt(V),2,16)
   Else If CfgReadExtra(K,V) Then Begin End;
  End;
 End;
 Close(T);
End;

{ Chargement au demarrage : HISOFTED.INF (repertoire courant, repertoire du
  programme, PATH), a defaut l'ancien DEVPAC.INF }
Procedure LoadPrefs;
Var N: String;
Begin
 N:=FindCfg(CFG_NAME);
 If N='' Then N:=FindCfg(CFG_OLD);
 If N='' Then Exit;
 LoadPrefsFrom(N);
 If Upper(ShortName(N))=CFG_NAME Then CfgFile:=N Else CfgFile:='';
End;

{ Dialogue Preferences (Options) : voir le chapitre 2 du manuel Devpac 3 }
Procedure EditorPrefsDlg;
Var R,cInd,cAuto,cPad,cHide,cBak,cMatch,cStop,pQuit,pRun,eTab,eBuf,pCur:
  Integer;
    P: String; NB: LongInt;
 Procedure ReadBack;
 Begin
  PrefIndent:=DI[cInd].Sel;PrefAutoSave:=DI[cAuto].Sel;PrefNumPad:=DI[cPad].Sel;
  PrefHideMouse:=DI[cHide].Sel;PrefBackup:=DI[cBak].Sel;PrefMatch:=DI[cMatch].
    Sel;
  PrefStopEol:=DI[cStop].Sel;
  PrefSaveQuit:=DI[pQuit].Sel;PrefSaveRun:=DI[pRun].Sel;
  PrefFlash:=DI[pCur].Sel;
  PrefTab:=Clamp(ToInt(DI[eTab].Val),2,16);
  NB:=Clamp(ToInt(DI[eBuf].Val),4000,999000);
 End;
Begin
 Repeat
  DlgReset(72,13);
  DlgLabel(2,0,T3('Preferences','Preferences','Einstellungen'));
  cInd:=DlgCheck(2,2,T3('Auto-indent lines','Auto-retrait des lignes',
    'Zeilen automatisch einruecken'),PrefIndent=1);
  cBak:=DlgCheck(40,2,T3('Make backups','Faire des sauvegardes',
    'Sicherungen anlegen'),PrefBackup=1);
  cAuto:=DlgCheck(2,3,T3('Auto-save configuration','Sauver la configuration',
    'Einstellungen autom. sichern'),PrefAutoSave=1);
  cMatch:=DlgCheck(40,3,T3('Show matching parentheses','Parentheses assorties',
    'Passende Klammern zeigen'),PrefMatch=1);
  cPad:=DlgCheck(2,4,T3('Cursor mode numeric keypad','Pave numerique = curseur',
    'Zehnerblock = Cursor'),PrefNumPad=1);
  cStop:=DlgCheck(40,4,T3('Stop at end of line','Arret en fin de ligne',
    'Am Zeilenende stoppen'),PrefStopEol=1);
  cHide:=DlgCheck(2,5,T3('Hide mouse when typing','Cacher la souris en tapant',
    'Maus beim Tippen verbergen'),PrefHideMouse=1);
  DlgLabel(2,7,T3('Save files on Quit','Sauver en quittant',
    'Beim Beenden sichern'));
  pQuit:=DlgPopup(24,7,6,T3('Yes|No|Ask','Oui|Non|Demander','Ja|Nein|Fragen'),
    PrefSaveQuit);
  DlgLabel(34,7,T3('Save files on Run Other','Sauver avant Run Other',
    'Vor Run Other sichern'));
  pRun:=DlgPopup(60,7,6,T3('Yes|No|Ask','Oui|Non|Demander','Ja|Nein|Fragen'),
    PrefSaveRun);
  DlgLabel(2,9,T3('Tab setting:','Tabulation :','Tabulator :'));
  eTab:=DlgEdit(16,9,3,IntStr(PrefTab));DI[eTab].Flt:=1;
  DlgLabel(22,9,T3('Text Buffer:','Tampon texte :','Textpuffer :'));
  eBuf:=DlgEdit(36,9,6,IntStr(PrefBuf));DI[eBuf].Flt:=1;
  DlgLabel(45,9,'Cursor');
  pCur:=DlgPopup(52,9,18,T3('Flashing block|Flashing line|Still block'+
    '|Still line',
    'Bloc clignotant|Barre clignotante|Bloc f'+'ixe|Barre fixe',
      'Block blinkend|Strich blinkend|Block fes'+'t|Strich fest'),PrefFlash);
  DlgButton(2,11,10,'Load...',2,False);
  DlgButton(14,11,12,T3('Save as...','Sauver sous...','Sichern als...'),3,
    False);
  DlgButton(28,11,9,'Reset',4,False);
  DlgButton(46,11,10,T3('Cancel','Annuler','Abbruch'),0,False);
  DlgButton(58,11,10,'OK',1,True);
  R:=DlgRun;
  If R=0 Then Exit;
  If R=4 Then Begin PrefDefaults;NB:=PrefBuf;End
  Else ReadBack;
  Case R Of
   2: Begin
       P:=CFG_NAME;
       If FileSelect(T3('Load settings','Charger les reglages',
         'Einstellungen laden'),'*.INF',P) Then
        If FileExists(P) Then LoadPrefsFrom(P);
       NB:=PrefBuf;
      End;
   3: Begin
       P:=CFG_NAME;
       If FileSelect(T3('Save settings as','Sauver les reglages sous',
         'Einstellungen sichern als'),'*.INF',P) Then Begin
        If Pos('.',ShortName(P))=0 Then P:=P+'.INF';
        SavePrefsTo(P);
       End;
      End;
  End;
 Until R=1;
 { taille du tampon : refusee si le texte actuel n'y tient pas }
 If NB<>PrefBuf Then Begin
  If NB<EdMem+12 Then
   Alert1(3,T3('Text buffer too small|for the current te'+'xt',
     'Tampon trop petit|pour le texte actuel',
     'Textpuffer zu klein|fuer den aktuellen T'+'ext'))
  Else PrefBuf:=NB;
 End;
 EnsureVisible;
End;

{ ====================================================================== }
{          MONITEUR / DEBOGUEUR Mon (Devpac 3) : ecran a fenetres         }
{ ====================================================================== }

Const
 MAXLE   = 12000;              { entrees LINE/HCLN }
 MAXSF   = 12;                 { fichiers sources }
 NWIN    = 5;                  { fenetres 1..5 }
 MAXVIEW = 6;                  { vues empilees par fenetre }
 MAXMB   = 8;                  { points d'arret (8 selon le manuel) }
 HMAX    = 10;                 { entrees de l'historique }
 MMAXSRC  = 8;                  { fichiers ASCII charges }
 MCW   = 8;                  { largeur d'une cellule de texte }
 VK_REG  = 0;
 VK_DIS  = 1;
 VK_MEM  = 2;
 VK_SRC  = 3;
 BK_SIMPLE = 1;
 BK_STOP   = 2;
 BK_COUNT  = 3;
 BK_PERM   = 4;
 BK_COND   = 5;
 PV_NONE = 0;                  { types de controle de saisie }
 PV_EXPR = 1;
 PV_EXPR0= 2;                  { expression ou vide }
 PV_BP   = 3;
 PV_REG  = 4;
 PV_FREE = 5;
 PV_EXPRL= 6;                  { liste d'expressions }

Type
 TMView = Record
  Kind : Byte;
  Addr : LongInt;              { adresse de depart (ou 1re ligne pour VK_SRC) }
  Lock : String[63];           { expression de verrouillage }
  Src  : Integer;              { index dans MSrc (VK_SRC) }
 End;
 TMWin = Record
  NV,Top : Integer;
  V      : Array[1..MAXVIEW] Of TMView;
  X,Y,W,H: Integer;            { rectangle en cellules }
 End;
 TMBp = Record
  Addr : LongInt;
  Kind : Byte;
  N,Cnt: LongInt;
  Expr : String[63];
 End;
 THist = Record
  R   : Array[0..15] Of LongInt;
  PCv : LongInt;
  SRx : LongInt;
 End;
 TMSrc = Record
  Name : String[80];
  Arr  : PLineArr;
  Cnt  : Integer;
  Fil  : Integer;              { fichier de la table de lignes (0 : simple
    fichier ASCII) }
 End;

Var
 MW        : Array[1..NWIN] Of TMWin;
 MCur      : Integer;          { fenetre courante }
 MZoom     : Boolean;
 RegRows   : Integer;          { hauteur de la fenetre 1 (titre compris) }
 SplL,SplR : Integer;          { etats des frontieres verticales (colonnes
   gauche/droite) }
 ColSt     : Integer;          { largeur de la colonne gauche (en cellules) }
 CellH     : Integer;          { hauteur d'une cellule : 10 ou 8 }
 NRows     : Integer;
 MMem      : Array[0..9] Of LongInt;   { registres memoire M0..M9 }
 MBp       : Array[1..MAXMB] Of TMBp;
 NMB       : Integer;
 BdosBp    : Integer;
 Hist      : Array[0..HMAX-1] Of THist;
 HHead,HCnt: Integer;
 MsgText   : String;
 MsgExtra  : String;
 MonLoaded : Boolean;
 ProgDead  : Boolean;
 MonQuit   : Boolean;
 MonSeen   : Boolean;
 MonFromEd : Boolean;
 PendKey   : LongInt;          { touche a re-traiter (apres Help) }
 EditOn    : Boolean;
 EditAsc   : Boolean;
 EditNib   : Integer;
 EditAddr  : LongInt;
 MSrc      : Array[1..MMAXSRC] Of TMSrc;
 NSrc      : Integer;
 { recherche }
 SrchKind  : Char;
 SrchBuf   : String;
 SrchAlign : Integer;
 SrchCase  : Boolean;
 { preferences }
 PfRel,PfIgnCase,PfAutoPre,PfAutoSrc,PfZAn,PfTimer,PfTraps,PfCart,PfTrapExc :
   Boolean;
 PfSymLen  : Integer;
 PfLabel   : String;
 PfLines   : Integer;          { 0 aucun, 1 decimal, 2 hexa }
 PfTopRam  : LongInt;
 LastFault : LongInt;
 TabSrc4   : Boolean;
 ExprErr   : Integer;

Procedure ClrErr;
Begin
 BusErr:=False;AddrErr:=False;
End;

Function Rdbl(A: LongInt): Boolean;
Begin
 A:=A And $FFFFFF;
 Rdbl:=A<MemSize;
End;

Function HexStr8(V: LongInt): String;
Begin
 HexStr8:=Hex8(V);
End;

Function RdB(A: LongInt): Integer;
Begin
 If Rdbl(A) Then RdB:=Rd8(A) Else RdB:=-1;
 ClrErr;
End;

{ ---------------------------------------------------------------------- }
{ Segments du programme, symboles                                          }
{ ---------------------------------------------------------------------- }

Function SegAddr(N: Integer): LongInt;      { 0 text, 1 data, 2 bss, 3 end }
Begin
 SegAddr:=0;
 If Not MonLoaded Then Exit;
 Case N Of
  0: SegAddr:=Rd32(BP_ADDR+8);
  1: SegAddr:=Rd32(BP_ADDR+16);
  2: SegAddr:=Rd32(BP_ADDR+24);
  3: SegAddr:=Rd32(BP_ADDR+24)+Rd32(BP_ADDR+28);
 End;
 ClrErr;
End;

Function SegLen(N: Integer): LongInt;
Begin
 SegLen:=0;
 If Not MonLoaded Then Exit;
 Case N Of
  0: SegLen:=Rd32(BP_ADDR+12);
  1: SegLen:=Rd32(BP_ADDR+20);
  2: SegLen:=Rd32(BP_ADDR+28);
 End;
 ClrErr;
End;

{ ---------------------------------------------------------------------- }
{ Informations de ligne (OPT LINE / OPT HCLN) : debogage source           }
{ ---------------------------------------------------------------------- }

Var
 LtN    : Integer;                          { nombre d'entrees, triees par
   adresse }
 LtAddr : Array[1..MAXLE] Of LongInt;
 LtLine : Array[1..MAXLE] Of LongInt;
 LtFil  : Array[1..MAXLE] Of Byte;
 MSfN    : Integer;
 MSfName : Array[1..MAXSF] Of String[80];
 MSfSrc  : Array[1..MAXSF] Of Integer;       { index dans MSrc (0 : pas encore
   charge) }
 MSfEnd  : LongInt;                          { fin du code (TEXT+DATA) }

Function MSfAdd(Const Nm: String): Integer;
Var I: Integer;
Begin
 For I:=1 To MSfN Do If MSfName[I]=Nm Then Begin MSfAdd:=I;Exit;End;
 If MSfN<MAXSF Then Begin
   Inc(MSfN);MSfName[MSfN]:=Nm;MSfSrc[MSfN]:=0;MSfAdd:=MSfN;End
 Else MSfAdd:=MSfN;
End;

Procedure LtAdd(F: Integer; Line,Addr: LongInt);
Begin
 If LtN<MAXLE Then Begin
  Inc(LtN);LtAddr[LtN]:=Addr;LtLine[LtN]:=Line;LtFil[LtN]:=F;
 End;
End;

{ Tri par adresse (Shell), stable en pratique pour les memes adresses }
Procedure LtSort;
Var Gap,I,J: Integer; A,L: LongInt; F: Byte; Seq: Array[1..1] Of Byte;
Begin
 Gap:=LtN Div 2;
 While Gap>0 Do Begin
  For I:=Gap+1 To LtN Do Begin
   A:=LtAddr[I];L:=LtLine[I];F:=LtFil[I];
   J:=I;
   While (J>Gap) And (LtAddr[J-Gap]>A) Do Begin
    LtAddr[J]:=LtAddr[J-Gap];LtLine[J]:=LtLine[J-Gap];LtFil[J]:=LtFil[J-Gap];
    J:=J-Gap;
   End;
   LtAddr[J]:=A;LtLine[J]:=L;LtFil[J]:=F;
  End;
  Gap:=Gap Div 2;
 End;
End;

Procedure MParseLineSec(P: Pointer; Q,E,TB: LongInt);
Var Nn,Cnt,I,F: LongInt; Nm: String;
Begin
 While Q+8<=E Do Begin
  Nn:=BufL(P,Q)*4;Inc(Q,4);
  Nm:='';
  For I:=0 To Nn-1 Do If BufB(P,Q+I)<>0 Then Nm:=Nm+Chr(BufB(P,Q+I));
  Inc(Q,Nn);
  F:=MSfAdd(Nm);
  Cnt:=BufL(P,Q);Inc(Q,4);
  For I:=1 To Cnt Do Begin
   If Q+8>E Then Break;
   LtAdd(F,BufL(P,Q),BufL(P,Q+4)+TB);
   Inc(Q,8);
  End;
 End;
End;

Procedure MParseHclnSec(P: Pointer; Q,E,TB: LongInt);
Var B,L,N,I,A,D,Ad,Ln,F: LongInt; Nm: String;
Begin
 F:=1;Ad:=0;Ln:=0;
 While Q<E Do Begin
  B:=BufB(P,Q);Inc(Q);
  If B=0 Then Break;
  If B=1 Then Begin
   L:=BufB(P,Q);Inc(Q);
   Nm:='';
   For I:=0 To L-1 Do Nm:=Nm+Chr(BufB(P,Q+I));
   Inc(Q,L);
   F:=MSfAdd(Nm);Ad:=0;Ln:=0;
  End Else If B=2 Then Begin
   N:=BufW(P,Q);Inc(Q,2);
   For I:=1 To N Do Begin
    A:=BufB(P,Q);Inc(Q);
    If A=251 Then Begin A:=BufW(P,Q);Inc(Q,2);End
    Else If A=252 Then Begin A:=BufL(P,Q);Inc(Q,4);End;
    D:=BufB(P,Q);Inc(Q);
    If D=$80 Then Begin D:=BufL(P,Q);Inc(Q,4);End Else D:=SExt(D,1);
    Ad:=Ad+A;Ln:=Ln+D;
    LtAdd(F,Ln,Ad+TB);
   End;
  End Else Break;
 End;
End;

{ Lit les sections LINE / HCLN qui suivent la table de relocation du .PRG }
Procedure MLoadLineInfo(Const Name: String);
Var P: Pointer; Len,TS,DS,SS,Q,M,SL,HcQ,HcL,TB: LongInt; HaveLine: Boolean;
Begin
 LtN:=0;MSfN:=0;MSfEnd:=0;
 If Not ReadAll(Name,P,Len) Then Exit;
 If (Len<32) Or (BufW(P,0)<>$601A) Then Begin FreeMem(P,Len);Exit;End;
 TS:=BufL(P,2);DS:=BufL(P,6);SS:=BufL(P,14);
 Q:=28+TS+DS+SS;
 If Q+4>Len Then Begin FreeMem(P,Len);Exit;End;
 If BufL(P,Q)=0 Then Inc(Q,4)
 Else Begin
  Inc(Q,4);
  While (Q<Len) And (BufB(P,Q)<>0) Do Inc(Q);
  Inc(Q);
 End;
 TB:=SegAddr(0);
 MSfEnd:=TB+TS+DS+2;
 HaveLine:=False;HcQ:=0;HcL:=0;
 While Q+8<=Len Do Begin
  M:=BufL(P,Q);SL:=BufL(P,Q+4);
  If (SL<0) Or (Q+8+SL>Len) Then Break;
  If M=$4C494E45 Then Begin MParseLineSec(P,Q+8,Q+8+SL,TB);HaveLine:=True;End
  Else If M=$48434C4E Then Begin HcQ:=Q+8;HcL:=SL;End;
  Q:=Q+8+SL;
 End;
 If (Not HaveLine) And (HcQ>0) Then MParseHclnSec(P,HcQ,HcQ+HcL,TB);
 FreeMem(P,Len);
 LtSort;
End;

{ Index de l'entree dont l'adresse est la plus grande <= A (0 si aucune) }
Function MLineIdx(A: LongInt): Integer;
Var Lo,Hi,Mi: Integer;
Begin
 MLineIdx:=0;
 If (LtN=0) Or (A<LtAddr[1]) Or (A>=MSfEnd) Then Exit;
 Lo:=1;Hi:=LtN;
 While Lo<Hi Do Begin
  Mi:=(Lo+Hi+1) Div 2;
  If LtAddr[Mi]<=A Then Lo:=Mi Else Hi:=Mi-1;
 End;
 MLineIdx:=Lo;
End;

Function MAddrLine(A: LongInt; Var F: Integer; Var L: LongInt): Boolean;
Var I: Integer;
Begin
 I:=MLineIdx(A);
 If I=0 Then Begin MAddrLine:=False;F:=0;L:=0;End
 Else Begin MAddrLine:=True;F:=LtFil[I];L:=LtLine[I];End;
End;

{ Adresse de la ligne L du fichier F ; Exact vrai si la ligne produit du code.
  Sinon : la ligne suivante qui en produit, ou la derniere ligne }
Function MLineAddr(F: Integer; L: LongInt; Var Exact: Boolean): LongInt;
Var I,BestN,BestL: Integer; MinGt,MaxL: LongInt; AGt,ALast: LongInt;
Begin
 Exact:=False;MLineAddr:=0;
 MinGt:=$7FFFFFFF;MaxL:=-1;AGt:=0;ALast:=0;
 For I:=1 To LtN Do
  If LtFil[I]=F Then Begin
   If LtLine[I]=L Then Begin MLineAddr:=LtAddr[I];Exact:=True;Exit;End;
   If (LtLine[I]>L) And (LtLine[I]<MinGt) Then Begin
     MinGt:=LtLine[I];AGt:=LtAddr[I];End;
   If LtLine[I]>MaxL Then Begin MaxL:=LtLine[I];ALast:=LtAddr[I];End;
  End;
 If MinGt<>$7FFFFFFF Then MLineAddr:=AGt Else MLineAddr:=ALast;
End;

{ Fichier source "courant" pour les operateurs # et ? : celui de la fenetre
  courante si c'est une fenetre source, sinon la premiere fenetre source, sinon
    celui du PC }
Function SrcFileOfView(Const V: TMView): Integer;
Begin
 SrcFileOfView:=0;
 If (V.Kind=VK_SRC) And (V.Src>=1) And (V.Src<=NSrc) Then
   SrcFileOfView:=MSrc[V.Src].Fil;
End;

Function CurSrcFile: Integer;
Var I,F: Integer; L: LongInt;
Begin
 CurSrcFile:=0;
 If (MCur>=1) And (MCur<=NWIN) Then Begin
  F:=SrcFileOfView(MW[MCur].V[MW[MCur].Top]);
  If F>0 Then Begin CurSrcFile:=F;Exit;End;
 End;
 For I:=2 To NWIN Do Begin
  F:=SrcFileOfView(MW[I].V[MW[I].Top]);
  If F>0 Then Begin CurSrcFile:=F;Exit;End;
 End;
 If MAddrLine(PC,F,L) Then CurSrcFile:=F Else If MSfN>0 Then CurSrcFile:=1;
End;

{ Recherche d'un symbole par son nom (options : casse, prefixe, longueur) }
Function SymMatch(Const A,B: String): Boolean;
Var X,Y: String;
Begin
 X:=A;Y:=B;
 If Length(X)>PfSymLen Then X:=Copy(X,1,PfSymLen);
 If Length(Y)>PfSymLen Then Y:=Copy(Y,1,PfSymLen);
 If PfIgnCase Then SymMatch:=Upper(X)=Upper(Y) Else SymMatch:=X=Y;
End;

Function MSymByName(Const N: String; Var A: LongInt): Boolean;
Var I: Integer;
Begin
 MSymByName:=False;
 If (DbgSyms=Nil) Or (DbgN=0) Then Exit;
 For I:=1 To DbgN Do
  If SymMatch(DbgSyms^[I].Name,N) Then Begin
    A:=DbgSyms^[I].Addr;MSymByName:=True;Exit;End;
 If PfAutoPre Then Begin
  For I:=1 To DbgN Do
   If SymMatch(DbgSyms^[I].Name,'_'+N) Or SymMatch(DbgSyms^[I].Name,'@'+N) Then
     Begin
    A:=DbgSyms^[I].Addr;MSymByName:=True;Exit;
   End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Evaluation d'expression : hexadecimal par defaut, priorites du manuel    }
{ ---------------------------------------------------------------------- }

Var MS: String; MP: Integer; MErr: Boolean;

Function WinAddrOf(N: Integer): LongInt; Forward;
Procedure SetWinAddr(N: Integer; NewV: LongInt); Forward;
Function ExprCmp: LongInt; Forward;

Procedure MSkip;
Begin
 While (MP<=Length(MS)) And (MS[MP]=' ') Do Inc(MP);
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

Function SymCh(C: Char): Boolean;
Begin
 SymCh:=((C>='A') And (C<='Z')) Or ((C>='a') And (C<='z')) Or (C='_') Or
        (C='.') Or (C='@') Or ((C>='0') And (C<='9'));
End;

Function RegValue(Const U: String; Var V: LongInt): Boolean;
Var R: Integer;
Begin
 RegValue:=True;
 If (Length(U)=2) And (U[1]='M') And (U[2]>='0') And (U[2]<='9') Then Begin
  R:=Ord(U[2])-48;
  If (R>=1) And (R<=5) Then V:=WinAddrOf(R) Else V:=MMem[R];
  Exit;
 End;
 If U='SSP' Then Begin V:=SSPv;Exit;End;
 If U='USP' Then Begin V:=USPv;Exit;End;
 If U='CCR' Then Begin V:=SRv And $FF;Exit;End;
 If U='TEXT' Then Begin V:=SegAddr(0);Exit;End;
 If U='DATA' Then Begin V:=SegAddr(1);Exit;End;
 If U='BSS' Then Begin V:=SegAddr(2);Exit;End;
 If U='END' Then Begin V:=SegAddr(3);Exit;End;
 R:=RegOf(U);
 If (R>=0) And (R<16) Then Begin V:=Rg[R];Exit;End;
 If R=20 Then Begin V:=SRv;Exit;End;
 If R=23 Then Begin V:=PC;Exit;End;
 RegValue:=False;
End;

Function ExprPrim: LongInt;
Var V,A: LongInt; Tk,U: String; C: Char; Sz: Char; Ok: Boolean;
Begin
 V:=0;
 MSkip;
 If MP>Length(MS) Then Begin MErr:=True;ExprPrim:=0;Exit;End;
 C:=MS[MP];
 If C='(' Then Begin
  Inc(MP);V:=ExprCmp;MSkip;
  If (MP<=Length(MS)) And (MS[MP]=')') Then Inc(MP) Else MErr:=True;
  ExprPrim:=V;Exit;
 End;
 If C='{' Then Begin
  Inc(MP);A:=ExprCmp;MSkip;
  If (MP<=Length(MS)) And (MS[MP]='}') Then Inc(MP) Else MErr:=True;
  Sz:='L';
  If (MP+1<=Length(MS)) And (MS[MP]='.') And (UpCase(MS[MP+1]) In
    ['B','W','L']) Then Begin
   Sz:=UpCase(MS[MP+1]);Inc(MP,2);
  End;
  If MErr Then Begin ExprPrim:=0;Exit;End;
  Case Sz Of
   'B': Begin
         If Not Rdbl(A) Then MErr:=True Else V:=Rd8(A);
        End;
   'W': Begin
         If Odd(A) Or Not Rdbl(A) Or Not Rdbl(A+1) Then MErr:=True Else
           V:=Rd16(A);
        End;
  Else Begin
         If Odd(A) Or Not Rdbl(A) Or Not Rdbl(A+3) Then MErr:=True Else
           V:=Rd32(A);
       End;
  End;
  ClrErr;
  ExprPrim:=V;Exit;
 End;
 If C='\' Then Begin
  Inc(MP);Ok:=False;
  While (MP<=Length(MS)) And (MS[MP]>='0') And (MS[MP]<='9') Do Begin
   V:=V*10+Ord(MS[MP])-48;Inc(MP);Ok:=True;
  End;
  If Not Ok Then MErr:=True;
  ExprPrim:=V;Exit;
 End;
 If C='%' Then Begin
  Inc(MP);Ok:=False;
  While (MP<=Length(MS)) And (MS[MP] In ['0','1']) Do Begin
    V:=V*2+Ord(MS[MP])-48;Inc(MP);Ok:=True;End;
  If Not Ok Then MErr:=True;
  ExprPrim:=V;Exit;
 End;
 If C='''' Then Begin
  Inc(MP);
  While (MP<=Length(MS)) And (MS[MP]<>'''') Do Begin V:=(V Shl 8) Or
    Ord(MS[MP]);Inc(MP);End;
  If MP<=Length(MS) Then Inc(MP) Else MErr:=True;
  ExprPrim:=V;Exit;
 End;
 If C='$' Then Begin
  Inc(MP);Tk:='';
  While (MP<=Length(MS)) And IsHexCh(MS[MP]) Do Begin Tk:=Tk+MS[MP];Inc(MP);End;
  If (Tk='') Or Not ParseHexVal(Tk,V) Then MErr:=True;
  ExprPrim:=V;Exit;
 End;
 Tk:='';
 While (MP<=Length(MS)) And SymCh(MS[MP]) Do Begin Tk:=Tk+MS[MP];Inc(MP);End;
 If Tk='' Then Begin MErr:=True;ExprPrim:=0;Exit;End;
 U:=Upper(Tk);
 If (C>='0') And (C<='9') Then Begin
  If ParseHexVal(Tk,V) Then Begin ExprPrim:=V;Exit;End;
  MErr:=True;ExprPrim:=0;Exit;
 End;
 If RegValue(U,V) Then Begin ExprPrim:=V;Exit;End;
 If MSymByName(Tk,A) Then Begin ExprPrim:=A;Exit;End;
 If ParseHexVal(Tk,V) Then Begin ExprPrim:=V;Exit;End;
 MErr:=True;
 ExprPrim:=0;
End;

Function ExprUn: LongInt;
Var C: Char; V,L: LongInt; F,F2: Integer; Ex: Boolean;
Begin
 MSkip;
 If MP>Length(MS) Then Begin MErr:=True;ExprUn:=0;Exit;End;
 If MS[MP]='-' Then Begin Inc(MP);ExprUn:=-ExprUn;Exit;End;
 If MS[MP]='+' Then Begin Inc(MP);ExprUn:=ExprUn;Exit;End;
 If (MS[MP]='#') Or (MS[MP]='?') Then Begin
  { operateurs source : numero de ligne -> adresse (#), adresse -> numero de
    ligne (?) }
  C:=MS[MP];Inc(MP);
  V:=ExprUn;
  If LtN=0 Then Begin MErr:=True;ExprUn:=0;Exit;End;
  F:=CurSrcFile;
  If F=0 Then Begin ExprUn:=0;Exit;End;
  If C='#' Then ExprUn:=MLineAddr(F,V,Ex)
  Else Begin
   If MAddrLine(V,F2,L) And (F2=F) Then ExprUn:=L Else ExprUn:=0;
  End;
  Exit;
 End;
 ExprUn:=ExprPrim;
End;

Function ExprNot: LongInt;
Begin
 MSkip;
 If (MP<=Length(MS)) And (MS[MP]='~') Then Begin Inc(MP);ExprNot:=Not
   ExprNot;Exit;End;
 ExprNot:=ExprUn;
End;

Function ExprShift: LongInt;
Var V,W: LongInt;
Begin
 V:=ExprNot;
 While Not MErr Do Begin
  MSkip;
  If (MP+1<=Length(MS)) And (MS[MP]='<') And (MS[MP+1]='<') Then Begin
   Inc(MP,2);W:=ExprNot;
   If (W<0) Or (W>31) Then V:=0 Else V:=V Shl W;
  End Else If (MP+1<=Length(MS)) And (MS[MP]='>') And (MS[MP+1]='>') Then Begin
   Inc(MP,2);W:=ExprNot;
   If (W<0) Or (W>31) Then V:=0 Else V:=ShrL(V,W);
  End Else Break;
 End;
 ExprShift:=V;
End;

Function ExprBit: LongInt;
Var V,W: LongInt; Op: Char;
Begin
 V:=ExprShift;
 While Not MErr Do Begin
  MSkip;
  If MP>Length(MS) Then Break;
  Op:=MS[MP];
  If (Op='!') And (MP<Length(MS)) And (MS[MP+1]='=') Then Break;
  If (Op='&') Or (Op='!') Or (Op='^') Then Begin
   Inc(MP);W:=ExprShift;
   Case Op Of
    '&': V:=V And W;
    '!': V:=V Or W;
   Else V:=V Xor W;
   End;
  End Else Break;
 End;
 ExprBit:=V;
End;

Function ExprMul: LongInt;
Var V,W: LongInt; Op: Char;
Begin
 V:=ExprBit;
 While Not MErr Do Begin
  MSkip;
  If MP>Length(MS) Then Break;
  Op:=MS[MP];
  If (Op='*') Or (Op='/') Then Begin
   Inc(MP);W:=ExprBit;
   If Op='*' Then V:=V*W
   Else If W<>0 Then V:=V Div W Else MErr:=True;
  End Else Break;
 End;
 ExprMul:=V;
End;

Function ExprAdd: LongInt;
Var V,W: LongInt; Op: Char;
Begin
 V:=ExprMul;
 While Not MErr Do Begin
  MSkip;
  If MP>Length(MS) Then Break;
  Op:=MS[MP];
  If (Op='+') Or (Op='-') Then Begin
   Inc(MP);W:=ExprMul;
   If Op='+' Then V:=V+W Else V:=V-W;
  End Else Break;
 End;
 ExprAdd:=V;
End;

Function ExprCmp: LongInt;
Var V,W: LongInt; Op: String[2]; T: Boolean;
Begin
 V:=ExprAdd;
 While Not MErr Do Begin
  MSkip;
  If MP>Length(MS) Then Break;
  Op:='';
  If (MP<Length(MS)) And (Copy(MS,MP,2)='<>') Then Op:='<>'
  Else If (MP<Length(MS)) And (Copy(MS,MP,2)='!=') Then Op:='<>'
  Else If (MP<Length(MS)) And (Copy(MS,MP,2)='<=') Then Op:='<='
  Else If (MP<Length(MS)) And (Copy(MS,MP,2)='>=') Then Op:='>='
  Else If MS[MP]='=' Then Op:='='
  Else If MS[MP]='<' Then Op:='<'
  Else If MS[MP]='>' Then Op:='>';
  If Op='' Then Break;
  If Op='=' Then Inc(MP) Else If Length(Op)=1 Then Inc(MP) Else Inc(MP,2);
  If (Op='=') And (MP<=Length(MS)) And (MS[MP]='=') Then Inc(MP);
  W:=ExprAdd;
  Case Op[1] Of
   '=': T:=V=W;
   '<': If Op='<>' Then T:=V<>W Else If Op='<=' Then T:=V<=W Else T:=V<W;
  Else If Op='>=' Then T:=V>=W Else T:=V>W;
  End;
  If T Then V:=-1 Else V:=0;
 End;
 ExprCmp:=V;
End;

Function MonEval(Const S: String; Var V: LongInt): Boolean;
Var SvS: String; SvP: Integer; SvE: Boolean;
Begin
 SvS:=MS;SvP:=MP;SvE:=MErr;
 MS:=S;MP:=1;MErr:=False;
 V:=ExprCmp;
 MSkip;
 MonEval:=Not MErr And (MP>Length(MS)) And (Length(TrimS(S))>0);
 MS:=SvS;MP:=SvP;MErr:=SvE;
End;

{ ---------------------------------------------------------------------- }
{ Desassemblage au format du moniteur                                      }
{ ---------------------------------------------------------------------- }

Function MDis(A: LongInt; Var Len: Integer): String;
Var R,O: String; I: Integer; InSym,Hx: Boolean; C: Char;
Begin
 For I:=0 To 7 Do DisAn[I]:=Rg[8+I];
 DisMon:=True;DisRel:=PfRel;DisExt:=True;DisZAn:=PfZAn;
 R:=Dis(A,Len);
 DisMon:=False;
 ClrErr;
 O:='';InSym:=False;Hx:=False;
 For I:=1 To Length(R) Do Begin
  C:=R[I];
  If C=#1 Then InSym:=True
  Else If C=#2 Then InSym:=False
  Else If InSym Then O:=O+C
  Else Begin
   If C='$' Then Hx:=True
   Else If Hx And Not IsHexCh(C) Then Hx:=False;
   If C=' ' Then Begin
    If (O<>'') And (O[Length(O)]<>' ') Then O:=O+C;
   End Else If Hx Then O:=O+C
   Else If (C>='A') And (C<='Z') Then O:=O+Chr(Ord(C)+32)
   Else O:=O+C;
  End;
 End;
 While (O<>'') And (O[Length(O)]=' ') Do Dec(O[0]);
 If Copy(O,1,5)='movem' Then Begin
  I:=2;
  While I<Length(O)-1 Do Begin
   If (O[I]='-') And (O[I-1]>='0') And (O[I-1]<='9') And ((O[I+1]='a') Or
     (O[I+1]='d')) And
      (O[I+2]>='0') And (O[I+2]<='9') Then Delete(O,I+1,1);
   Inc(I);
  End;
 End;
 MDis:=O;
End;

{ Mot d'extension 68020 (brief avec echelle, ou complet) : adresse effective }
Procedure ExtAddr(Ext,BaseV: LongInt; Var P: LongInt; Var Addr: LongInt);
Var X,Bd,Od,Sc,Iis: LongInt;
Begin
 If (Ext And $8000)<>0 Then X:=Rg[8+((Ext Shr 12) And 7)] Else X:=Rg[(Ext Shr
   12) And 7];
 If (Ext And $800)=0 Then X:=SExt(X,2);
 Sc:=(Ext Shr 9) And 3;
 X:=X Shl Sc;
 If (Ext And $100)=0 Then Begin
  Addr:=BaseV+SExt(Ext,1)+X;Exit;
 End;
 Bd:=0;Od:=0;
 Case (Ext Shr 4) And 3 Of
  2: Begin Bd:=SExt(Rd16(P),2);Inc(P,2);End;
  3: Begin Bd:=Rd32(P);Inc(P,4);End;
 End;
 Iis:=Ext And 7;
 Case Iis And 3 Of
  2: Begin Od:=SExt(Rd16(P),2);Inc(P,2);End;
  3: Begin Od:=Rd32(P);Inc(P,4);End;
 End;
 If (Ext And $80)<>0 Then BaseV:=0;
 If (Ext And $40)<>0 Then X:=0;
 If Iis=0 Then Addr:=BaseV+Bd+X
 Else If Iis<4 Then Addr:=Rd32(BaseV+Bd+X)+Od
 Else Addr:=Rd32(BaseV+Bd)+X+Od;
End;

{ Adresse effective du champ (Mode,Reg) ; P = adresse du mot d'extension }
Function EAAddr(Mode,Reg,Sz: Integer; Var P: LongInt; Var Addr: LongInt):
  Boolean;
Var Ext,D: LongInt; X: LongInt;
Begin
 EAAddr:=True;
 Case Mode Of
  2: Addr:=Rg[8+Reg];
  3: Addr:=Rg[8+Reg];
  4: Addr:=Rg[8+Reg]-Sz;
  5: Begin Addr:=Rg[8+Reg]+SExt(Rd16(P),2);Inc(P,2);End;
  6: Begin
      Ext:=Rd16(P);Inc(P,2);
      ExtAddr(Ext,Rg[8+Reg],P,Addr);
     End;
  7: Case Reg Of
      0: Begin Addr:=SExt(Rd16(P),2);Inc(P,2);End;
      1: Begin Addr:=Rd32(P);Inc(P,4);End;
      2: Begin Addr:=P+SExt(Rd16(P),2);Inc(P,2);End;
      3: Begin
          Ext:=Rd16(P);D:=P;Inc(P,2);
          ExtAddr(Ext,D,P,Addr);
         End;
      4: Begin If Sz=4 Then Inc(P,4) Else Inc(P,2);EAAddr:=False;End;
     Else EAAddr:=False;
     End;
 Else EAAddr:=False;
 End;
End;

Function EAData(A: LongInt; Sz: Integer): String;
Var S: String; I: Integer; B: Integer;
Begin
 S:='';
 If Sz>8 Then Sz:=8;
 If Sz<1 Then Sz:=1;
 For I:=0 To Sz-1 Do Begin
  B:=RdB(A+I);
  If B<0 Then S:=S+'**' Else S:=S+Hex2(B);
  If (Sz>1) And Odd(I) And (I<Sz-1) Then S:=S+' ';
 End;
 EAData:=S;
End;

{ Adresses effectives de l'instruction a PCa : "; 00001FAE 0F01 > 0002AC08
  FFFF" }
Function EAInfo(PCa: LongInt): String;
Var Op,P,A1,A2: LongInt; Sz,S1,S2,Mode,Reg,G: Integer; Has1,Has2: Boolean; R:
  String;
    Skip: Integer; AddrOnly: Boolean;
Begin
 EAInfo:='';
 Has1:=False;Has2:=False;A1:=0;A2:=0;S1:=2;S2:=2;AddrOnly:=False;
 Op:=Rd16(PCa);ClrErr;
 P:=PCa+2;
 G:=(Op Shr 12) And 15;
 Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
 Sz:=(Op Shr 6) And 3;
 Case G Of
  0: Begin
      If (Op And $F138)=$0108 Then Begin End
      Else If (Op And $0100)<>0 Then Begin
       If Mode>=2 Then Begin Has1:=EAAddr(Mode,Reg,1,P,A1);S1:=1;End;
      End Else Case (Op Shr 8) And 15 Of
       0,2,4,6,10,12: Begin
         If (Op=$003C) Or (Op=$023C) Or (Op=$0A3C) Or (Op=$007C) Or (Op=$027C)
           Or (Op=$0A7C) Then Begin End
         Else If Sz<3 Then Begin
          If Sz=2 Then Inc(P,4) Else Inc(P,2);
          If Mode>=2 Then Begin
           Case Sz Of 0: S1:=1; 1: S1:=2; Else S1:=4; End;
           Has1:=EAAddr(Mode,Reg,S1,P,A1);
          End;
         End;
        End;
       8: Begin
         Inc(P,2);
         If Mode>=2 Then Begin Has1:=EAAddr(Mode,Reg,1,P,A1);S1:=1;End;
        End;
      End;
     End;
  1,2,3: Begin
      Case G Of 1: S1:=1; 3: S1:=2; Else S1:=4; End;
      S2:=S1;
      If Mode>=2 Then Has1:=EAAddr(Mode,Reg,S1,P,A1);
      If ((Op Shr 6) And 7)>=2 Then Has2:=EAAddr((Op Shr 6) And 7,(Op Shr 9)
        And 7,S2,P,A2);
     End;
  4: Begin
      If (Op And $F1C0)=$41C0 Then Begin
       If Mode>=2 Then Begin
         Has1:=EAAddr(Mode,Reg,2,P,A1);S1:=2;AddrOnly:=True;End;
      End Else If (Op And $F1C0)=$4180 Then Begin
       If Mode>=2 Then Begin Has1:=EAAddr(Mode,Reg,2,P,A1);S1:=2;End;
      End Else Case Op And $0F00 Of
       $0000,$0200,$0400,$0600: Begin
         If Mode>=2 Then Begin
          Case Sz Of 0: S1:=1; 3: S1:=2; 1: S1:=2; Else S1:=4; End;
          Has1:=EAAddr(Mode,Reg,S1,P,A1);
         End;
        End;
       $0800: Begin
         If (Op And $FFC0)=$4800 Then Begin
          If Mode>=2 Then Begin Has1:=EAAddr(Mode,Reg,1,P,A1);S1:=1;End;
         End Else If (Op And $FFC0)=$4840 Then Begin
          If Mode>=2 Then Begin
            Has1:=EAAddr(Mode,Reg,4,P,A1);S1:=2;AddrOnly:=True;End;
         End Else If (Op And $FF80)=$4880 Then Begin
          Inc(P,2);
          If Mode>=2 Then Begin Has1:=EAAddr(Mode,Reg,4,P,A1);S1:=8;End;
         End;
        End;
       $0A00: Begin
         If Op<>$4AFC Then If Mode>=2 Then Begin
          If Sz=3 Then S1:=1 Else Case Sz Of 0: S1:=1; 1: S1:=2; Else S1:=4;
            End;
          Has1:=EAAddr(Mode,Reg,S1,P,A1);
         End;
        End;
       $0C00: Begin
         If (Op And $FF80)=$4C80 Then Begin
          Inc(P,2);
          If Mode>=2 Then Begin Has1:=EAAddr(Mode,Reg,4,P,A1);S1:=8;End;
         End;
        End;
       $0E00: Begin
         If ((Op And $FFC0)=$4E80) Or ((Op And $FFC0)=$4EC0) Then Begin
          If Mode>=2 Then Begin
            Has1:=EAAddr(Mode,Reg,2,P,A1);S1:=2;AddrOnly:=True;End;
         End;
        End;
      End;
     End;
  5: Begin
      If Sz=3 Then Begin
       If Mode<>1 Then If Mode>=2 Then Begin
         Has1:=EAAddr(Mode,Reg,1,P,A1);S1:=1;End;
      End Else If Mode>=2 Then Begin
       Case Sz Of 0: S1:=1; 1: S1:=2; Else S1:=4; End;
       Has1:=EAAddr(Mode,Reg,S1,P,A1);
      End;
     End;
  8,9,11,12,13: Begin
      If Mode>=2 Then Begin
       If Sz=3 Then Begin
        If (G=9) Or (G=13) Or (G=11) Then Begin
         If (Op And $100)<>0 Then S1:=4 Else S1:=2;
        End Else S1:=2;
       End Else Case Sz Of 0: S1:=1; 1: S1:=2; Else S1:=4; End;
       If Not ((G=12) And ((Op And $1F0)=$100)) And Not ((G=8) And ((Op And
         $1F0)=$100)) Then
        Has1:=EAAddr(Mode,Reg,S1,P,A1);
      End;
     End;
  14: Begin
      If (Sz=3) And (Mode>=2) Then Begin
        Has1:=EAAddr(Mode,Reg,2,P,A1);S1:=2;End;
     End;
 End;
 ClrErr;
 If Has2 Then Begin MMem[0]:=A2;End Else If Has1 Then MMem[0]:=A1;
 If Not (Has1 Or Has2) Then Exit;
 R:='  ;';
 If Has1 Then Begin
  R:=R+Hex8(A1);
  If Not AddrOnly Then R:=R+' '+EAData(A1,S1) Else R:=R+' '+EAData(A1,2);
 End;
 If Has2 Then Begin
  If Has1 Then R:=R+' > ' Else R:=R+' ';
  R:=R+Hex8(A2)+' '+EAData(A2,S2);
 End;
 EAInfo:=R;
End;

{ ---------------------------------------------------------------------- }
{ Modele des fenetres                                                      }
{ ---------------------------------------------------------------------- }

{ Charge (une fois) le fichier source F de la table de lignes ; retourne son
  index MSrc }
Function LoadSrcFile(F: Integer): Integer;
Var Cand: Array[1..8] Of String; NC,I,K,Cnt: Integer; Nm,Base,Dir: String; Arr:
  PLineArr; Ok: Boolean;
Begin
 LoadSrcFile:=0;
 If (F<1) Or (F>MSfN) Then Exit;
 If MSfSrc[F]>0 Then Begin LoadSrcFile:=MSfSrc[F];Exit;End;
 If NSrc>=MMAXSRC Then Exit;
 Nm:=MSfName[F];
 Base:=Nm;
 For I:=1 To Length(Base) Do If Base[I]='\' Then Base[I]:='/';
 While Pos('/',Base)>0 Do Delete(Base,1,Pos('/',Base));
 Dir:=ProgName;
 For I:=1 To Length(Dir) Do If Dir[I]='\' Then Dir[I]:='/';
 K:=0;
 For I:=1 To Length(Dir) Do If Dir[I]='/' Then K:=I;
 Dir:=Copy(Dir,1,K);
 NC:=0;
 Inc(NC);Cand[NC]:=Nm;
 Inc(NC);Cand[NC]:=HostPath(Nm);
 Inc(NC);Cand[NC]:=Dir+Nm;
 Inc(NC);Cand[NC]:=Dir+Base;
 Inc(NC);Cand[NC]:=Base;
 Inc(NC);Cand[NC]:=Dir+LowerStr(Base);
 Inc(NC);Cand[NC]:=LowerStr(Base);
 Inc(NC);Cand[NC]:=LowerStr(HostPath(Nm));
 Ok:=False;
 For I:=1 To NC Do
  If (Cand[I]<>'') And FileExists(Cand[I]) Then
   If LoadLines(Cand[I],Arr,Cnt) Then Begin Ok:=True;Break;End;
 If Not Ok Then Exit;
 Inc(NSrc);
 MSrc[NSrc].Name:=Base;MSrc[NSrc].Arr:=Arr;MSrc[NSrc].Cnt:=Cnt;MSrc[NSrc].Fil:=F
   ;
 MSfSrc[F]:=NSrc;
 LoadSrcFile:=NSrc;
End;

{ Positionne la vue J de la fenetre I pour montrer l'adresse A ; Top = ligne en
  haut.
  Keep : ne bouge pas si la ligne est deja visible (verrou sur le PC) }
Function SrcApply(I,J: Integer; A: LongInt; Keep: Boolean): Boolean;
Var F: Integer; L: LongInt; S,Rows: Integer;
Begin
 SrcApply:=False;
 If Not MAddrLine(A,F,L) Then Exit;
 With MW[I].V[J] Do Begin
  If (Src<1) Or (MSrc[Src].Fil<>F) Then Begin
   S:=LoadSrcFile(F);
   If S=0 Then Exit;
   Src:=S;Addr:=1;Keep:=False;
  End;
  Rows:=MW[I].H-1;
  If Rows<3 Then Rows:=10;
  If Keep And (L>=Addr) And (L<Addr+Rows) Then Begin SrcApply:=True;Exit;End;
  If Keep Then Addr:=L-Rows Div 3 Else Addr:=L;
  If Addr<1 Then Addr:=1;
 End;
 SrcApply:=True;
End;

Function WinAddrOf(N: Integer): LongInt;
Var Ex: Boolean;
Begin
 If (N<1) Or (N>NWIN) Then Begin WinAddrOf:=0;Exit;End;
 With MW[N] Do Begin
  If (N=1) And (V[Top].Kind=VK_REG) Then WinAddrOf:=MMem[1]
  Else If (V[Top].Kind=VK_SRC) And (V[Top].Src>=1) And (MSrc[V[Top].Src].Fil>0)
    Then
   WinAddrOf:=MLineAddr(MSrc[V[Top].Src].Fil,V[Top].Addr,Ex)
  Else WinAddrOf:=V[Top].Addr;
 End;
End;

Procedure SetWinAddr(N: Integer; NewV: LongInt);
Begin
 If (N<1) Or (N>NWIN) Then Exit;
 With MW[N] Do Begin
  If (N=1) And (V[Top].Kind=VK_REG) Then MMem[1]:=NewV
  Else If (V[Top].Kind=VK_SRC) And (V[Top].Src>=1) And (MSrc[V[Top].Src].Fil>0)
    Then Begin
   If SrcApply(N,Top,NewV,False) Then Begin End;
  End
  Else V[Top].Addr:=NewV;
 End;
End;

Function AllowedKind(N,K: Integer): Boolean;
Begin
 Case N Of
  1: AllowedKind:=True;
  3,5: AllowedKind:=K=VK_MEM;
 Else AllowedKind:=K<>VK_REG;
 End;
End;

Procedure InitView(Var V: TMView; K: Integer; A: LongInt);
Begin
 V.Kind:=K;V.Addr:=A;V.Lock:='';V.Src:=0;
End;

Procedure InitWindows;
Var I: Integer;
Begin
 For I:=1 To NWIN Do Begin
  MW[I].NV:=1;MW[I].Top:=1;
  InitView(MW[I].V[1],VK_MEM,0);
 End;
 InitView(MW[1].V[1],VK_REG,0);
 InitView(MW[2].V[1],VK_DIS,0);MW[2].V[1].Lock:='pc';
 InitView(MW[3].V[1],VK_MEM,0);MW[3].V[1].Lock:='';
 InitView(MW[4].V[1],VK_DIS,0);
 InitView(MW[5].V[1],VK_MEM,0);
 MCur:=2;MZoom:=False;RegRows:=11;
 SplL:=0;SplR:=0;ColSt:=0;
 CellH:=10;NRows:=SCR_H Div CellH;
 EditOn:=False;EditAsc:=False;EditNib:=0;
 FillChar(MMem,SizeOf(MMem),0);
End;

Procedure UpdateLocks;
Var I,J,P: Integer; V: LongInt;
Begin
 For P:=1 To 2 Do
  For I:=1 To NWIN Do
   For J:=1 To MW[I].NV Do
    If MW[I].V[J].Lock<>'' Then
     If MonEval(MW[I].V[J].Lock,V) Then Begin
      If (MW[I].V[J].Kind=VK_SRC) And (LtN>0) Then Begin
       If SrcApply(I,J,V,True) Then Begin End;
      End Else MW[I].V[J].Addr:=V;
     End;
 ClrErr;
End;

Const
 LeftWs : Array[0..4] Of Integer = (40,56,80,24,0);
 TopNum : Array[0..3] Of Integer = (4,2,1,3);

Procedure Layout;
Var HB,R1,LW,RH,TL,TR,I: Integer;
Begin
 NRows:=SCR_H Div CellH;
 HB:=NRows-2;
 R1:=RegRows;
 If R1<2 Then R1:=2;
 If R1>HB-4 Then R1:=HB-4;
 For I:=1 To NWIN Do Begin MW[I].X:=0;MW[I].Y:=0;MW[I].W:=0;MW[I].H:=0;End;
 If MZoom Then Begin
  MW[MCur].X:=0;MW[MCur].Y:=0;MW[MCur].W:=80;MW[MCur].H:=HB;
  Exit;
 End;
 MW[1].W:=80;MW[1].H:=R1;
 RH:=HB-R1;
 LW:=LeftWs[ColSt];
 TL:=(RH*TopNum[SplL]) Div 4;
 TR:=(RH*TopNum[SplR]) Div 4;
 If LW>=8 Then Begin
  MW[2].X:=0;MW[2].Y:=R1;MW[2].W:=LW;MW[2].H:=TL;
  MW[4].X:=0;MW[4].Y:=R1+TL;MW[4].W:=LW;MW[4].H:=RH-TL;
 End;
 If 80-LW>=8 Then Begin
  MW[3].X:=LW;MW[3].Y:=R1;MW[3].W:=80-LW;MW[3].H:=TR;
  MW[5].X:=LW;MW[5].Y:=R1+TR;MW[5].W:=80-LW;MW[5].H:=RH-TR;
 End;
 For I:=2 To NWIN Do
  If (MW[I].H<2) Or (MW[I].W<8) Then Begin MW[I].W:=0;MW[I].H:=0;End;
End;

{ ---------------------------------------------------------------------- }
{ Primitives d'affichage en cellules                                       }
{ ---------------------------------------------------------------------- }

Procedure CT(C,R,W: Integer; Const S0: String; Inv: Boolean);
Var S: String; X,Y,Yo: Integer;
Begin
 If W<=0 Then Exit;
 S:=S0;
 If Length(S)>W Then S:=Copy(S,1,W);
 While Length(S)<W Do S:=S+' ';
 X:=C*MCW;Y:=R*CellH;Yo:=(CellH-8) Div 2;
 If Inv Then Begin
  Box(X,Y,X+W*MCW-1,Y+CellH-1,INK);WText(X,Y+Yo,S);
 End Else Begin
  Box(X,Y,X+W*MCW-1,Y+CellH-1,PAPER);PText(X,Y+Yo,S);
 End;
End;

Function PrintCh(B: Integer): Char;
Begin
 If B<0 Then PrintCh:='*'
 Else If (B>=32) And (B<127) Then PrintCh:=Chr(B)
 Else PrintCh:='.';
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

{ Mots pointes : 5 mots + ASCII }
Function PtrDump(A: LongInt): String;
Var S,Asc: String; I,B: Integer;
Begin
 S:='';Asc:='';
 For I:=0 To 9 Do Begin
  B:=RdB(A+I);
  If B<0 Then S:=S+'**' Else S:=S+Hex2(B);
  Asc:=Asc+PrintCh(B);
  If Odd(I) Then S:=S+' ';
 End;
 PtrDump:=S+Asc;
End;

Function RegLine(L: Integer): String;
Var S: String; I,Len: Integer; V: LongInt;
Begin
 S:='';
 If L<=7 Then Begin
  V:=Rg[L];
  S:='d'+IntStr(L)+' = '+Hex8(V)+' '+PrintCh((V Shr 24) And 255)+PrintCh((V Shr
    16) And 255)+
     PrintCh((V Shr 8) And 255)+PrintCh(V And 255)+'  ';
  S:=S+'a'+IntStr(L)+' = '+Hex8(Rg[8+L])+' '+PtrDump(Rg[8+L]);
 End Else If L=8 Then Begin
  S:='sr = '+Hex4(SRv)+' ';
  If (SRv And SR_S)<>0 Then S:=S+'S' Else S:=S+'U';
  If (SRv And SR_T)<>0 Then S:=S+' T' Else S:=S+' -';
  S:=S+' i'+IntStr((SRv Shr 8) And 7)+'  '+FlagStr;
 End Else If L=9 Then Begin
  S:='PC:'+Hex8(PC)+' ';
  If Rdbl(PC) Then S:=S+MDis(PC,Len)+EAInfo(PC) Else S:=S+'**';
 End Else If L=11 Then S:='ssp = '+Hex8(SSPv)
 Else If L=12 Then S:='usp = '+Hex8(USPv)
 Else If (L>=14) And (L<=23) Then Begin
  I:=L-14;
  If (I>=1) And (I<=5) Then V:=WinAddrOf(I) Else V:=MMem[I];
  S:='m'+IntStr(I)+' = '+Hex8(V)+' '+PtrDump(V);
 End;
 RegLine:=S;
End;

Function MemBpl(Wd: Integer): Integer;
Var N: Integer;
Begin
 N:=((Wd-9) Div 7)*2;
 If N>16 Then N:=16;
 If N<2 Then N:=2;
 MemBpl:=N;
End;

Function MemRow(A: LongInt; Bpl: Integer): String;
Var S,Asc: String; I,B: Integer;
Begin
 S:=Hex8(A)+' ';Asc:='';
 For I:=0 To Bpl-1 Do Begin
  B:=RdB(A+I);
  If B<0 Then S:=S+'**' Else S:=S+Hex2(B);
  If Odd(I) Then S:=S+' ';
  Asc:=Asc+PrintCh(B);
 End;
 MemRow:=S+Asc;
End;

Function BpMark(A: LongInt): String;
Var I: Integer;
Begin
 BpMark:='';
 For I:=1 To NMB Do
  If MBp[I].Addr=A Then Begin
   Case MBp[I].Kind Of
    BK_SIMPLE: BpMark:=' [1]';
    BK_STOP: BpMark:=' ['+IntStr(MBp[I].N)+']';
    BK_COUNT: BpMark:=' [='+IntStr(MBp[I].Cnt)+']';
    BK_PERM: BpMark:=' [*]';
    BK_COND: BpMark:=' [?'+Copy(MBp[I].Expr,1,10)+']';
   End;
   Exit;
  End;
End;

Function DisRow(A: LongInt; Wd: Integer; Var Len: Integer): String;
Var Sym,Lead,T,M: String;
Begin
 Len:=2;
 If Not Rdbl(A) Then Begin DisRow:=Hex8(A)+' ****';Exit;End;
 T:=MDis(A,Len);
 Sym:=DbgFind(A);
 If A=PC Then M:='>' Else M:=' ';
 If (Wd<64) And (Sym<>'') Then Lead:=PadR(Copy(Sym,1,8),8)
 Else Lead:=Hex8(A);
 DisRow:=Lead+M;
 If (Wd>=64) And (Sym<>'') Then DisRow:=Lead+M+PadR(Sym,14)+T+BpMark(A)
 Else If Wd>=64 Then DisRow:=Lead+M+PadR('',14)+T+BpMark(A)
 Else DisRow:=Lead+M+T+BpMark(A);
End;

Function TabExpand(Const S: String; Tb: Integer): String;
Var R: String; I: Integer;
Begin
 R:='';
 For I:=1 To Length(S) Do
  If S[I]=#9 Then Begin
   Repeat R:=R+' ';Until (Length(R) Mod Tb)=0;
  End Else R:=R+S[I];
 TabExpand:=R;
End;

{ La ligne source (fichier F, ligne L) contient-elle le PC ? }
Function IsPcLine(F: Integer; L: LongInt): Boolean;
Var F2: Integer; L2: LongInt;
Begin
 IsPcLine:=MAddrLine(PC,F2,L2) And (F2=F) And (L2=L);
End;

Function SrcPcRow(Const V: TMView; R: Integer): Boolean;
Begin
 SrcPcRow:=False;
 If (V.Src<1) Or (V.Src>NSrc) Or (MSrc[V.Src].Fil=0) Then Exit;
 SrcPcRow:=IsPcLine(MSrc[V.Src].Fil,V.Addr+R);
End;

Function SrcRow(Const V: TMView; R: Integer): String;
Var L,A: LongInt; S,N,Pre,Bm: String; Ex: Boolean;
Begin
 SrcRow:='';
 If (V.Src<1) Or (V.Src>NSrc) Then Exit;
 L:=V.Addr+R;
 If (L<1) Or (L>MSrc[V.Src].Cnt) Then Exit;
 S:=MSrc[V.Src].Arr^[L]^;
 If TabSrc4 Then S:=TabExpand(S,4) Else S:=TabExpand(S,8);
 N:='';
 If PfLines=1 Then N:=PadL(IntStr(L),5)+' '
 Else If PfLines=2 Then N:=PadL(Hex4(L),5)+' ';
 Pre:='';Bm:='';
 If MSrc[V.Src].Fil>0 Then Begin
  If IsPcLine(MSrc[V.Src].Fil,L) Then Pre:='>' Else Pre:=' ';
  A:=MLineAddr(MSrc[V.Src].Fil,L,Ex);
  If Ex Then Bm:=BpMark(A);
 End;
 SrcRow:=Pre+N+S+Bm;
End;

Function KindName(K: Integer; Const V: TMView): String;
Begin
 Case K Of
  VK_REG: KindName:=T3('Registers','Registres','Register');
  VK_DIS: KindName:=T3('Disassembly','Desassemblage','Disassembler');
  VK_MEM: KindName:=T3('Memory','Memoire','Speicher');
 Else Begin
   If (V.Src>=1) And (V.Src<=NSrc) Then KindName:=MSrc[V.Src].Name Else
     KindName:='Source';
  End;
 End;
End;

Function WinTitle(I: Integer): String;
Var S,Pn: String;
Begin
 With MW[I] Do Begin
  S:=IntStr(I);
  If NV>1 Then S:=S+Chr(96+Top);
  S:=S+' '+KindName(V[Top].Kind,V[Top]);
  If V[Top].Lock<>'' Then S:=S+'  ['+V[Top].Lock+']';
  If (I=1) And (V[Top].Kind=VK_REG) And (ProgName<>'') Then Begin
   Pn:=ProgName;
   While Pos('/',Pn)>0 Do Delete(Pn,1,Pos('/',Pn));
   While Pos('\',Pn)>0 Do Delete(Pn,1,Pos('\',Pn));
   S:=S+'   '+Pn;
  End;
 End;
 WinTitle:=S;
End;

{ Texte de la ligne R (0..H-2) du contenu de la fenetre I }
Function WinRow(I,R: Integer; Var Len: Integer): String;
Var A: LongInt; N,K,Bpl,J: Integer; Kd: Integer;
Begin
 Len:=0;
 WinRow:='';
 With MW[I] Do Begin
  Kd:=V[Top].Kind;
  N:=H-1;
  Case Kd Of
   VK_REG: Begin
     If MZoom Or (N>=10) Then K:=R
     Else If R<N-2 Then K:=R
     Else If R=N-2 Then K:=8
     Else K:=9;
     If N=1 Then K:=9;
     WinRow:=RegLine(K);
    End;
   VK_MEM: Begin
     Bpl:=MemBpl(W);
     WinRow:=MemRow(V[Top].Addr+R*Bpl,Bpl);
    End;
   VK_DIS: Begin
     A:=V[Top].Addr;
     For J:=1 To R Do Begin
      DisRow(A,W,Len);
      A:=A+Len;
     End;
     WinRow:=DisRow(A,W,Len);
    End;
  Else WinRow:=SrcRow(V[Top],R);
  End;
 End;
End;

Procedure DrawWin(I: Integer);
Var R,Len,CX,Rw,Bpl,K,Col: Integer; A: LongInt; S: String; Inv: Boolean;
Begin
 With MW[I] Do Begin
  If (W<=0) Or (H<2) Then Exit;
  Inv:=I=MCur;
  CT(X,Y,W,WinTitle(I),Inv);
  If Not Inv Then Begin
   SetColor(INK);
   Line(X*MCW,Y*CellH+CellH-1,(X+W)*MCW-1,Y*CellH+CellH-1);
  End;
  If V[Top].Kind=VK_DIS Then Begin
   { une seule passe : les adresses des lignes se suivent }
   A:=V[Top].Addr;
   For R:=0 To H-2 Do Begin
    S:=DisRow(A,W,Len);
    CT(X,Y+1+R,W,S,False);
    A:=A+Len;
   End;
  End Else Begin
   For R:=0 To H-2 Do Begin
    S:=WinRow(I,R,Len);
    CT(X,Y+1+R,W,S,(V[Top].Kind=VK_SRC) And SrcPcRow(V[Top],R));
   End;
  End;
  { curseur d'edition }
  If EditOn And (I=MCur) And (V[Top].Kind=VK_MEM) Then Begin
   Bpl:=MemBpl(W);
   K:=EditAddr-V[Top].Addr;
   If (K>=0) And (K<Bpl*(H-1)) Then Begin
    Rw:=K Div Bpl;Col:=K Mod Bpl;
    S:=MemRow(V[Top].Addr+Rw*Bpl,Bpl);
    If EditAsc Then Begin
     CX:=X+9+(Bpl Div 2)*5+Col;
     CT(CX,Y+1+Rw,1,Copy(S,10+(Bpl Div 2)*5+Col,1),True);
    End Else Begin
     CX:=X+9+(Col Div 2)*5+(Col Mod 2)*2;
     CT(CX,Y+1+Rw,2,Copy(S,10+(Col Div 2)*5+(Col Mod 2)*2,2),True);
    End;
   End;
  End;
  If X>0 Then Begin
   SetColor(INK);
   Line(X*MCW,Y*CellH,X*MCW,(Y+H)*CellH-1);
  End;
 End;
End;

Procedure DrawMonitor;
Var I,Ro: Integer; S: String;
Begin
 HideMouse;
 Layout;
 If MZoom Then DrawWin(MCur)
 Else For I:=1 To NWIN Do DrawWin(I);
 Ro:=NRows-2;
 S:=MsgText;
 If MsgExtra<>'' Then S:=S+'   '+MsgExtra;
 CT(0,Ro,80,' '+S,False);
 If EditOn Then
  S:=T3(' EDIT: hex digits or ASCII, Tab = switch'+
    ' hex/ASCII, cursor keys move, Esc = end',
    ' EDITION : chiffres hexa ou ASCII, Tab ='+
    ' hexa/ASCII, curseurs, Esc = fin',
    ' EDITIEREN: Hex-Ziffern oder ASCII, Tab '+
    '= Hex/ASCII umschalten, Cursortasten bew'+'egen, Esc = Ende')
 Else
  S:=T3(' ^Z Step ^T Trace ^R Run ^C Quit  Alt-A '+
    'addr B brk E edit Z zoom  V scr  F1 help',
       ' ^Z Pas ^T Trace ^R Exec ^C Fin  Alt-A a'+
         'dr B arret E edit Z zoom  V ecran  F1 ai'+'de',
       ' ^Z Schr ^T Trace ^R Los ^C Ende  Alt-A '+
         'Adr B Halt E Edit Z Zoom  V Bild F1 Hilf'+'e');
 CT(0,Ro+1,80,S,True);
 ShowMouse;
End;

{ ---------------------------------------------------------------------- }
{ Points d'arret                                                           }
{ ---------------------------------------------------------------------- }

Function BpFindAt(A: LongInt): Integer;
Var I: Integer;
Begin
 BpFindAt:=0;
 For I:=1 To NMB Do If MBp[I].Addr=A Then Begin BpFindAt:=I;Exit;End;
End;

Procedure BpDel(I: Integer);
Var J: Integer;
Begin
 For J:=I To NMB-1 Do MBp[J]:=MBp[J+1];
 If NMB>0 Then Dec(NMB);
End;

Procedure MonAlert(Const Msg: String); Forward;

{ Pose le point d'arret simple en A ; retourne False si la table est pleine }
Function BpAddSimple(A: LongInt): Boolean;
Var I: Integer;
Begin
 BpAddSimple:=True;
 I:=BpFindAt(A);
 If I=0 Then Begin
  If NMB>=MAXMB Then Begin BpAddSimple:=False;Exit;End;
  Inc(NMB);I:=NMB;
 End;
 MBp[I].Addr:=A;MBp[I].Kind:=BK_SIMPLE;MBp[I].N:=1;MBp[I].Cnt:=0;MBp[I].Expr:=''
   ;
End;

{ "<adresse>[,<specificateur>]" : Apply=False controle seulement la syntaxe }
Function BpParse(Const S: String; Apply: Boolean): Boolean;
Var P,I: Integer; A,V: LongInt; Ad,Rest,Ex: String; K: Integer;
Begin
 BpParse:=False;
 P:=Pos(',',S);
 If P>0 Then Begin Ad:=TrimS(Copy(S,1,P-1));Rest:=TrimS(Copy(S,P+1,100));End
 Else Begin Ad:=TrimS(S);Rest:='';End;
 If Not MonEval(Ad,A) Then Exit;
 If Odd(A) Or Not Rdbl(A) Then Exit;
 K:=BK_SIMPLE;V:=1;Ex:='';
 If Rest='' Then Begin End
 Else If Rest='-' Then K:=0
 Else If Rest='=' Then K:=BK_COUNT
 Else If Rest='*' Then K:=BK_PERM
 Else If Rest[1]='?' Then Begin
  K:=BK_COND;Ex:=TrimS(Copy(Rest,2,60));
  If Not MonEval(Ex,V) Then Exit;
 End Else Begin
  If Not MonEval(Rest,V) Then Exit;
  If V<1 Then Exit;
  If V=1 Then K:=BK_SIMPLE Else K:=BK_STOP;
 End;
 If Not Apply Then Begin BpParse:=True;Exit;End;
 I:=BpFindAt(A);
 If K=0 Then Begin
  If I>0 Then BpDel(I);
  BpParse:=True;Exit;
 End;
 If I=0 Then Begin
  If NMB>=MAXMB Then Begin
   MonAlert(T3('Too many breakpoints','Trop de points d''arret',
     'Zu viele Haltepunkte'));
   BpParse:=True;Exit;
  End;
  Inc(NMB);I:=NMB;
 End;
 MBp[I].Addr:=A;MBp[I].Kind:=K;MBp[I].N:=V;MBp[I].Cnt:=0;MBp[I].Expr:=Ex;
 If K<>BK_STOP Then MBp[I].N:=1;
 BpParse:=True;
End;

{ Appele apres chaque instruction (PC = adresse a executer) : vrai si arret }
Function BpCheck: Boolean;
Var I: Integer; V: LongInt;
Begin
 BpCheck:=False;
 For I:=1 To NMB Do
  If MBp[I].Addr=PC Then Begin
   Case MBp[I].Kind Of
    BK_SIMPLE,BK_STOP: Begin
      Dec(MBp[I].N);
      If MBp[I].N<=0 Then Begin BpDel(I);BpCheck:=True;Exit;End;
     End;
    BK_COUNT: Inc(MBp[I].Cnt);
    BK_PERM: Begin BpCheck:=True;Exit;End;
    BK_COND: Begin
      If MonEval(MBp[I].Expr,V) Then If V<>0 Then Begin BpCheck:=True;Exit;End;
      ClrErr;
     End;
   End;
   Exit;
  End;
End;

{ ---------------------------------------------------------------------- }
{ Historique                                                               }
{ ---------------------------------------------------------------------- }

Procedure HistPush;
Var I: Integer;
Begin
 HHead:=(HHead+1) Mod HMAX;
 If HCnt<HMAX Then Inc(HCnt);
 For I:=0 To 15 Do Hist[HHead].R[I]:=Rg[I];
 Hist[HHead].PCv:=PC;Hist[HHead].SRx:=SRv;
End;

{ ---------------------------------------------------------------------- }
{ Dialogues Mon                                                            }
{ ---------------------------------------------------------------------- }

Procedure DlgFrame(Const Prm,Ln2: String; Var C0,R0,Wd: Integer; Inv: Boolean);
Var Ab: String;
Begin
 Wd:=64;C0:=8;R0:=NRows Div 2-2;
 Ab:=' '+T3('ESC to abort','ESC pour abandonner','ESC zum Abbrechen')+' ';
 CT(C0,R0-1,Length(Ab),Ab,True);
 Box(C0*MCW-4,R0*CellH-2,(C0+Wd)*MCW+3,(R0+2)*CellH+1,PAPER);
 SetColor(INK);
 Rectangle(C0*MCW-4,R0*CellH-2,(C0+Wd)*MCW+3,(R0+2)*CellH+1);
 CT(C0,R0,Wd,' '+Prm,Inv);
 CT(C0,R0+1,Wd,' '+Ln2,Inv);
End;

Procedure MnDlgDraw(Const Prm,S: String; Cur: Integer; Inv: Boolean);
Var C0,R0,Wd: Integer; Ch: String;
Begin
 HideMouse;
 DlgFrame(Prm,S,C0,R0,Wd,Inv);
 If Cur<Length(S) Then Ch:=S[Cur+1] Else Ch:=' ';
 If Not Inv Then CT(C0+1+Cur,R0+1,1,Ch,True);
 ShowMouse;
End;

Procedure FlashDlg(Const Prm,S: String; Cur: Integer);
Begin
 MnDlgDraw(Prm,S,Cur,True);
 Delay(70);
 MnDlgDraw(Prm,S,Cur,False);
End;

Function RegAssign(Const S: String; Apply: Boolean): Boolean; Forward;
Function ListOk(Const S: String): Boolean; Forward;

Function PromptValid(Kind: Integer; Const S: String): Boolean;
Var V: LongInt;
Begin
 Case Kind Of
  PV_EXPR: PromptValid:=MonEval(S,V);
  PV_EXPR0: PromptValid:=(TrimS(S)='') Or MonEval(S,V);
  PV_BP: PromptValid:=BpParse(S,False);
  PV_REG: PromptValid:=RegAssign(S,False);
  PV_EXPRL: PromptValid:=ListOk(S);
 Else PromptValid:=True;
 End;
 ClrErr;
End;

Function MonPrompt(Const Prm: String; Var S: String; Kind: Integer): Boolean;
Var E: TEvent; Cur: Integer; Done: Boolean;
Begin
 MonPrompt:=False;
 Cur:=Length(S);Done:=False;
 Repeat
  MnDlgDraw(Prm,S,Cur,False);
  Repeat PollEvent(E);Until E.Kind=1;
  Case E.Key Of
   K_ESC: Begin Done:=True;MonPrompt:=False;End;
   K_ENTER: Begin
     If PromptValid(Kind,S) Then Begin Done:=True;MonPrompt:=True;End
     Else FlashDlg(Prm,S,Cur);
    End;
   K_BKSP: If Cur>0 Then Begin Delete(S,Cur,1);Dec(Cur);End;
   K_DEL: If Cur<Length(S) Then Delete(S,Cur+1,1);
   K_LEFT: If Cur>0 Then Dec(Cur);
   K_RIGHT: If Cur<Length(S) Then Inc(Cur);
   K_HOME,K_CLEFT: Cur:=0;
   K_END,K_CRIGHT: Cur:=Length(S);
   256+45: Begin S:='';Cur:=0;End;
   32..126: If Length(S)<60 Then Begin Insert(Chr(E.Key),S,Cur+1);Inc(Cur);End;
  End;
 Until Done;
End;

{ Message d'erreur : "Return" ferme la boite }
Procedure MonAlert(Const Msg: String);
Var E: TEvent; C0,R0,Wd: Integer;
Begin
 HideMouse;
 DlgFrame(Msg,'Return',C0,R0,Wd,False);
 CT(C0+1,R0+1,6,'Return',True);
 ShowMouse;
 Repeat PollEvent(E);Until (E.Kind=1) And ((E.Key=K_ENTER) Or (E.Key=K_ESC));
End;

{ Question a reponse par une touche ; #0 si Esc, #13 si Return autorise }
Function MonAskKey(Const Prm,Allowed: String): Char;
Var E: TEvent; C: Char; Done: Boolean;
Begin
 MonAskKey:=#0;Done:=False;
 MnDlgDraw(Prm,'',0,False);
 Repeat
  Repeat PollEvent(E);Until E.Kind=1;
  If E.Key=K_ESC Then Done:=True
  Else If E.Key<256 Then Begin
   C:=UpCase(Chr(E.Key));
   If ((C='J') Or (C='O')) And (Pos('Y',Allowed)>0) And (Pos(C,Allowed)=0) Then
     C:='Y';
   If Pos(C,Allowed)>0 Then Begin MonAskKey:=C;Done:=True;End;
  End;
 Until Done;
End;

{ ---------------------------------------------------------------------- }
{ Messages                                                                 }
{ ---------------------------------------------------------------------- }

Procedure SetMsg(Const S: String);
Begin
 MsgText:=S;MsgExtra:='';
End;

Function FaultName(Const M: String): String;
Var V,I: Integer;
Begin
 If Copy(M,1,13)='Address error' Then
   FaultName:=T3('Address Error','Erreur d''adresse','Adressfehler')
 Else If Copy(M,1,9)='Bus error' Then
   FaultName:=T3('Bus Error','Erreur de bus','Busfehler')
 Else If Copy(M,1,19)='Illegal instruction' Then
   FaultName:=T3('Illegal Instruction','Instruction illegale',
   'Illegaler Befehl')
 Else If Copy(M,1,19)='Privilege violation' Then
   FaultName:=T3('Privilege Violation','Violation de privilege',
   'Privilegverletzung')
 Else If Copy(M,1,14)='Divide by zero' Then
   FaultName:=T3('Divide by Zero','Division par zero','Division durch Null')
 Else If Copy(M,1,13)='CHK exception' Then
   FaultName:=T3('CHK Instruction','Instruction CHK','CHK-Befehl')
 Else If Copy(M,1,16)='TRAPV exception' Then
   FaultName:=T3('TRAPV Instruction','Instruction TRAPV','TRAPV-Befehl')
 Else If Copy(M,1,15)='Line F emulator' Then
   FaultName:=T3('Line 1111 Emulator','Emulateur ligne 1111',
   'Line-1111-Emulator')
 Else If Copy(M,1,11)='Exception #' Then Begin
  V:=0;
  Val(Copy(M,12,3),V,I);
  If (V>=32) And (V<=47) Then FaultName:='TRAP #'+IntStr(V-32)
  Else If V=10 Then
    FaultName:=T3('Line 1010 Emulator','Emulateur ligne 1010',
    'Line-1010-Emulator')
  Else If V=24 Then
    FaultName:=T3('Spurious Interrupt','Interruption parasite',
    'Unechter Interrupt')
  Else If (V>=12) And (V<=14) Then
    FaultName:=T3('Reserved / Format Error','Reserve / erreur de format',
    'Reserviert / Formatfehler')
  Else FaultName:=M;
 End Else FaultName:=M;
End;

{ ---------------------------------------------------------------------- }
{ Execution                                                                }
{ ---------------------------------------------------------------------- }

Const
 W_NONE  = 0;
 W_BP    = 1;
 W_TEMP  = 2;
 W_COUNT = 3;
 W_COND  = 4;
 W_BDOS  = 5;
 EX_GO    = 0;
 EX_SLOW  = 1;
 EX_COUNT = 2;
 EX_UNTIL = 3;

Procedure MonYield;
Begin
 EmuVisible:=True;
 BlitScreen(True);
 GemDispatch;
 EmuVisible:=False;
End;

Function CanRun: Boolean;
Begin
 CanRun:=False;
 If Not MonLoaded Then Begin
  SetMsg(T3('No program loaded','Aucun programme charge',
    'Kein Programm geladen'));Exit;
 End;
 If ProgDead Then Begin
  SetMsg(T3('Program Terminated','Programme termine','Programm beendet'));Exit;
 End;
 CanRun:=True;
End;

{ Analyse de l'etat apres un arret }
Procedure AfterStop(Why: Integer);
Begin
 SetMsg('');
 Case StopReason Of
  STOP_EXIT: Begin
    ProgDead:=True;
    SetMsg(T3('Program Terminated','Programme termine','Programm beendet'));
    MsgExtra:=T3('exit code ','code de sortie ','Rueckgabecode ')+
      IntStr(ExitCode);
   End;
  STOP_FAULT: Begin
    SetMsg(FaultName(StopMsg));
    LastFault:=BusAddr;
    If Pos('Bus error',StopMsg)=1 Then
      MsgExtra:=T3('access at $','acces a $','Zugriff auf $')+Hex6(BusAddr);
    If PendVec>=0 Then
     MsgExtra:=T3('handler at $','gestionnaire en $','Handler bei $')+
       Hex6(PendHnd)+T3(' (Ctrl-R / Ctrl-Z enter it)',
       ' (Ctrl-R / Ctrl-Z y entrent)',' (Ctrl-R / Ctrl-Z springen hinein)');
   End;
  STOP_STOP: SetMsg(T3('STOP instruction','Instruction STOP','STOP-Befehl'));
  STOP_USER: SetMsg(T3('Interrupted','Interrompu','Unterbrochen'));
 Else Case Why Of
   W_BP,W_BDOS: SetMsg(T3('Breakpoint','Point d''arret','Haltepunkt'));
   W_COND: SetMsg(T3('Condition true','Condition vraie','Bedingung erfuellt'));
   W_COUNT: SetMsg('');
  End;
 End;
 If UnknownCall<>'' Then Begin
  MsgExtra:=T3('Unsupported call: ','Appel non gere : ',
    'Nicht unterstuetzter Aufruf: ')+UnknownCall;
  UnknownCall:='';
 End;
 If StopReason<>STOP_EXIT Then StopReason:=STOP_NONE;
End;

Function EscInKQ: Boolean;
Var I: Integer;
Begin
 EscInKQ:=False;
 I:=KQHead;
 While I<>KQTail Do Begin
  If (KQ[I] And $FFFF)=27 Then Begin EscInKQ:=True;KQHead:=KQTail;Exit;End;
  I:=(I+1) Mod KQ_SIZE;
 End;
End;

Procedure ExecRun(Mode: Integer; Count: LongInt; Const Cond: String; Watch:
  Boolean;
                  TempA,TempSP: LongInt);
Var N,Poll,Every,LastDraw,T,T0,Thr: LongInt; Why: Integer; V: LongInt;
  ShowProg,WantProg,Slow: Boolean;
Begin
 If Not CanRun Then Exit;
 StopReason:=STOP_NONE;StopMsg:='';
 { ecran du programme : affiche apres 20 ms d'execution si "Screen timer" est
   actif }
 WantProg:=(Mode=EX_GO) Or Not Watch;
 Slow:=(Mode=EX_SLOW) Or ((Mode<>EX_GO) And Watch);   { vitesse reduite }
 ShowProg:=False;Thr:=0;
 UserBreak:=False;
 SetMsg(T3('Running... (Esc or Ctrl-C to interrupt)',
   'Execution... (Esc ou Ctrl-C interrompt)',
   'Laeuft... (Esc oder Ctrl-C unterbricht)'));
 DrawMonitor;
 T0:=MsNow;
 Why:=W_NONE;N:=0;Poll:=0;
 If Mode=EX_GO Then Every:=4096
 Else If Watch Then Every:=48
 Else Every:=512;
 LastDraw:=MsNow;
 Repeat
  If Mode<>EX_GO Then HistPush;
  Step;
  Inc(N);Inc(Poll);
  If EmuVisible And Not ShowProg Then ShowProg:=True;   { le programme attend
    une touche }
  If Slow Then Begin
   Inc(Thr);
   If Thr>=8 Then Begin Thr:=0;Delay(1);End;
  End;
  If StopReason=STOP_YIELD Then Begin
   If EmuVisible Then GemDispatch Else MonYield;
  End;
  If StopReason<>STOP_NONE Then Break;
  If (TempA<>-1) And (PC=TempA) And (Rg[15]>=TempSP) Then Begin
    Why:=W_TEMP;Break;End;
  If NMB>0 Then If BpCheck Then Begin Why:=W_BP;Break;End;
  If BdosBp>=0 Then
   If (Rd16(PC)=$4E41) And (Rd16(Rg[15])=BdosBp) Then Begin
     Why:=W_BDOS;Break;End;
  If Mode=EX_COUNT Then If N>=Count Then Begin Why:=W_COUNT;Break;End;
  If Mode=EX_UNTIL Then Begin
   If MonEval(Cond,V) Then If V<>0 Then Begin Why:=W_COND;Break;End;
  End;
  If Poll>=Every Then Begin
   Poll:=0;
   PollInput;
   If UserBreak Then Begin StopReason:=STOP_USER;Break;End;
   If EscInKQ Then Begin StopReason:=STOP_USER;Break;End;
   T:=MsNow;
   If WantProg And PfTimer And Not ShowProg And ((T-T0>=20) Or (T<T0)) Then
     Begin
    ShowProg:=True;EmuVisible:=True;BlitScreen(True);
   End;
   If Not ShowProg Then Begin
    If (T-LastDraw>=60) Or (T<LastDraw) Then Begin DrawMonitor;LastDraw:=T;End;
   End Else BlitScreen(False);
  End;
 Until False;
 ClrErr;
 EmuVisible:=False;
 UserBreak:=False;
 KQHead:=0;KQTail:=0;
 HistPush;
 AfterStop(Why);
 UpdateLocks;
End;

{ La fenetre courante est une fenetre source avec informations de ligne : pas
  par ligne }
Function SrcLevel: Boolean;
Begin
 SrcLevel:=(LtN>0) And (MW[MCur].V[MW[MCur].Top].Kind=VK_SRC) And
           (SrcFileOfView(MW[MCur].V[MW[MCur].Top])>0);
End;

{ Pas a pas au niveau source : execute jusqu'au debut d'une autre ligne source.
  Over : les BSR/JSR sont executes en bloc }
Procedure ExecSrcStep(Over: Boolean);
Var N,Ret,SPb,StartPC,Cnt: LongInt; Op: LongInt; Len: Integer; T: String; F0,F:
  Integer; L0,L: LongInt;
    Have,Call: Boolean; Why,Idx: Integer;
Begin
 If Not CanRun Then Exit;
 StopReason:=STOP_NONE;StopMsg:='';
 UserBreak:=False;
 HistPush;
 StartPC:=PC;
 Have:=MAddrLine(PC,F0,L0);
 Why:=W_NONE;N:=0;
 Repeat
  Op:=Rd16(PC);ClrErr;
  Call:=Over And (((Op And $FFC0)=$4E80) Or ((Op And $FF00)=$6100));
  If Call Then Begin
   T:=MDis(PC,Len);Ret:=PC+Len;SPb:=Rg[15];
  End;
  Step;
  Inc(N);
  If StopReason=STOP_YIELD Then MonYield;
  If Call And (StopReason=STOP_NONE) Then Begin
   { execute le sous-programme en bloc : retour a Ret avec la pile d'origine }
   Cnt:=0;
   While (StopReason=STOP_NONE) And Not ((PC=Ret) And (Rg[15]>=SPb)) Do Begin
    Step;Inc(Cnt);
    If StopReason=STOP_YIELD Then MonYield;
    If (StopReason=STOP_NONE) And (NMB>0) Then If BpCheck Then Begin
      Why:=W_BP;Break;End;
    If (Cnt And 4095)=0 Then Begin
     PollInput;
     If UserBreak Or EscInKQ Then Begin StopReason:=STOP_USER;Break;End;
    End;
   End;
   If Why<>W_NONE Then Break;
  End;
  If StopReason<>STOP_NONE Then Break;
  If (NMB>0) Then If BpCheck Then Begin Why:=W_BP;Break;End;
  Idx:=MLineIdx(PC);
  If Idx>0 Then
   If LtAddr[Idx]=PC Then Begin
    If (Not Have) Or (LtFil[Idx]<>F0) Or (LtLine[Idx]<>L0) Or (PC<=StartPC)
      Then Break;
   End;
  If (N And 4095)=0 Then Begin
   PollInput;
   If UserBreak Or EscInKQ Then Begin StopReason:=STOP_USER;Break;End;
  End;
 Until False;
 ClrErr;
 EmuVisible:=False;
 UserBreak:=False;
 KQHead:=0;KQTail:=0;
 AfterStop(Why);
 UpdateLocks;
End;

Procedure ExecStep1;
Begin
 If SrcLevel Then Begin ExecSrcStep(False);Exit;End;
 If Not CanRun Then Exit;
 StopReason:=STOP_NONE;StopMsg:='';
 UserBreak:=False;
 HistPush;
 Step;
 If StopReason=STOP_YIELD Then MonYield;
 ClrErr;
 EmuVisible:=False;
 If UserBreak Then StopReason:=STOP_USER;
 UserBreak:=False;
 AfterStop(W_NONE);
 UpdateLocks;
End;

Procedure ExecTrace;
Var Op: LongInt; Len: Integer; T: String;
Begin
 If SrcLevel Then Begin ExecSrcStep(True);Exit;End;
 If Not CanRun Then Exit;
 Op:=Rd16(PC);ClrErr;
 If ((Op And $FFC0)=$4E80) Or ((Op And $FF00)=$6100) Then Begin
  T:=MDis(PC,Len);
  ExecRun(EX_GO,0,'',False,PC+Len,Rg[15]);
 End Else ExecStep1;
End;

Procedure ExecSkip;
Var Len: Integer; T: String;
Begin
 If Not CanRun Then Exit;
 T:=MDis(PC,Len);
 PC:=PC+Len;
 PendVec:=-1;
 SetMsg('');
 UpdateLocks;
End;

{ ---------------------------------------------------------------------- }
{ Utilitaires de commandes                                                 }
{ ---------------------------------------------------------------------- }

Function RegAssign(Const S: String; Apply: Boolean): Boolean;
Var P: Integer; U: String; V: LongInt; R,M: Integer; Ok: Boolean;
Begin
 RegAssign:=False;
 P:=Pos('=',S);
 If P<2 Then Exit;
 U:=Upper(TrimS(Copy(S,1,P-1)));
 If Not MonEval(Copy(S,P+1,100),V) Then Exit;
 R:=RegOf(U);
 M:=-1;
 If (Length(U)=2) And (U[1]='M') And (U[2]>='0') And (U[2]<='9') Then
   M:=Ord(U[2])-48;
 Ok:=(R>=0) Or (U='SSP') Or (M>=0);
 If Not Ok Then Exit;
 If Not Apply Then Begin RegAssign:=True;Exit;End;
 If (R>=0) And (R<16) Then Rg[R]:=V
 Else If R=20 Then SetSR(V)
 Else If R=21 Then SetSR((SRv And $FF00) Or (V And $FF))
 Else If R=22 Then USPv:=V
 Else If R=23 Then Begin PC:=V;PendVec:=-1;End
 Else If U='SSP' Then SSPv:=V
 Else If M>=0 Then Begin
  If (M>=1) And (M<=5) Then SetWinAddr(M,V) Else MMem[M]:=V;
 End;
 RegAssign:=True;
End;

Function SplitList(Const S: String; Var P: Array Of String; Max: Integer):
  Integer;
Begin
 SplitList:=SplitTop(S,P,Max);
End;

Function IsSizeTok(Const S: String): Boolean;
Begin
 IsSizeTok:=(S='W') Or (S='w') Or (S='L') Or (S='l');
End;

Function ListOk(Const S: String): Boolean;
Var P: Array[0..15] Of String; N,I: Integer; V: LongInt;
Begin
 ListOk:=False;
 N:=SplitList(S,P,16);
 If N=0 Then Exit;
 For I:=0 To N-1 Do Begin
  If (I>0) And (I=N-1) And IsSizeTok(P[I]) Then Begin End
  Else If Not MonEval(P[I],V) Then Exit;
 End;
 ClrErr;
 ListOk:=True;
End;

Function SymNear(V: LongInt): String;
Var I,Best: Integer; D: LongInt;
Begin
 SymNear:='';Best:=0;
 If (DbgSyms=Nil) Or (DbgN=0) Then Exit;
 For I:=1 To DbgN Do
  If DbgSyms^[I].Addr<=V Then
   If (Best=0) Or (DbgSyms^[I].Addr>DbgSyms^[Best].Addr) Then Best:=I;
 If Best=0 Then Exit;
 D:=V-DbgSyms^[Best].Addr;
 If D>$FFFF Then Exit;
 If D=0 Then SymNear:=DbgSyms^[Best].Name
 Else SymNear:=DbgSyms^[Best].Name+'+'+HexS(D);
End;

{ Fenetre cible des recherches / adresses : la courante, sinon la 3 }
Function TargetWin: Integer;
Begin
 TargetWin:=MCur;
 If (MCur=1) And (MW[1].V[MW[1].Top].Kind=VK_REG) Then TargetWin:=3;
End;

{ ---------------------------------------------------------------------- }
{ Pages d'information                                                      }
{ ---------------------------------------------------------------------- }

Var
 Pg  : Array[1..120] Of String[80];
 PgN : Integer;

Procedure PgAdd(Const S: String);
Begin
 If PgN<120 Then Begin Inc(PgN);Pg[PgN]:=S;End;
End;

Procedure ShowPager(Const Title: String);
Var Top,Rows,I: Integer; E: TEvent;
Begin
 Rows:=NRows-2;
 Top:=1;
 Repeat
  HideMouse;
  Box(0,0,SCR_W-1,SCR_H-1,PAPER);
  CT(0,0,80,' '+Title,True);
  For I:=0 To Rows-2 Do If Top+I<=PgN Then CT(0,1+I,80,Pg[Top+I],False);
  CT(0,NRows-1,80,T3(' Any key = next page, Esc = end',
    ' Une touche = page suivante, Esc = fin',
    ' Beliebige Taste = naechste Seite, Esc ='+' Ende'),True);
  ShowMouse;
  Repeat PollEvent(E);Until E.Kind=1;
  If E.Key=K_ESC Then Break;
  If E.Key>=256 Then PendKey:=E.Key;
  Top:=Top+Rows-1;
  If Top>PgN Then Break;
 Until False;
End;

Procedure MCmdHelp;
Var I: Integer; T: String;
Begin
 PgN:=0;
 PgAdd(T3(' Segments:',' Segments :',' Segmente:'));
 PgAdd('  TEXT $'+Hex8(SegAddr(0))+'  '+T3('length','longueur','Laenge')+' $'+
   Hex8(SegLen(0)));
 PgAdd('  DATA $'+Hex8(SegAddr(1))+'  '+T3('length','longueur','Laenge')+' $'+
   Hex8(SegLen(1)));
 PgAdd('  BSS  $'+Hex8(SegAddr(2))+'  '+T3('length','longueur','Laenge')+' $'+
   Hex8(SegLen(2)));
 PgAdd('');
 PgAdd(T3(' Breakpoints:',' Points d''arret :',' Haltepunkte:'));
 If NMB=0 Then PgAdd('  '+T3('none','aucun','keine'));
 For I:=1 To NMB Do Begin
  T:=BpMark(MBp[I].Addr);
  If MBp[I].Kind=BK_STOP Then
    T:=T+'  '+T3('count','compte','Zaehler')+' '+IntStr(MBp[I].N);
  If MBp[I].Kind=BK_COND Then T:=T+'  '+MBp[I].Expr;
  PgAdd('  $'+Hex8(MBp[I].Addr)+T+'   '+DbgFind(MBp[I].Addr));
 End;
 If BdosBp>=0 Then PgAdd('  BDOS $'+Hex4(BdosBp));
 PgAdd('');
 PgAdd(T3(' Window commands (Alt-):',' Commandes de fenetre (Alt-) :',
   ' Fensterbefehle (Alt-):'));
 PgAdd(T3('  A/M address  B breakpoint  E edit  F f'+
   'ont  G goto line  L lock  O/0 bases',
  '  A/M adr  B arret  E edition  F police  G ligne  L verrou  O/0 bases',
  '  A/M Adr  B Halt  E Editieren  F Zeichen  G Zeile  L Binden  O/0 Basen'));
 PgAdd(T3('  P print  R register set  S split  T type  W widen  Z zoom',
  '  P imprimer  R registre  S diviser  T type  W elargir  Z zoom',
  '  P Drucken  R Register  S Teilen  T Typ  W Verbreitern  Z Zoom'));
 PgAdd(T3('  1-5 / Tab: current window   > < open/c'+
   'lose view   . , next/prev view',
  '  1-5/Tab : fenetre   > < ouvrir/fermer une vue   . , vue suiv./prec.',
  '  1-5/Tab: Fenster   > < Ansicht oeffnen/schliessen   . , naechste/vorige'));
 PgAdd(T3('  Ctrl-Up/Down or Ctrl-Left/Right: regis'+
   'ter window height   Alt-Up/Down: page',
  '  Ctrl-Haut/Bas : hauteur des registres   Alt-Haut/Bas : page',
  '  Ctrl-Auf/Ab: Hoehe der Register   Alt-Auf/Ab: Seite'));
 PgAdd(T3('  Esc: update all windows / end zoom',
  '  Esc : met a jour toutes les fenetres / quitte le zoom',
  '  Esc: alle Fenster aktualisieren / Zoom beenden'));
 PgAdd('');
 PgAdd(T3(' Execution (Ctrl-):',' Execution (Ctrl-) :',
   ' Ausfuehrung (Ctrl-):'));
 PgAdd(T3('  R run   Z/Y/W step   T trace   S skip   A breakpoint after',
  '  R executer   Z/Y/W pas   T tracer   S sauter   A point d''arret apres',
  '  R Starten  Z/Y/W Einzelschritt  T Trace  S Ueberspringen  A Halt danach'));
 PgAdd(T3('  B simple breakpoint here   K kill breakpoints   D BDOS breakpoint',
  '  B point d''arret ici   K effacer les p'+
    'oints d''arret   D point d''arret BDOS',
  '  B einfacher Haltepunkt hier   K Haltep'+
    'unkte loeschen   D BDOS-Haltepunkt'));
 PgAdd(T3('  L load program  P preferences  C termi'+
   'nate  E exceptions  F7 F8 F9 = Z T R',
  '  L charger   P preferences   C terminer   E exceptions   F7 F8 F9 = Z T R',
  '  L Laden   P Einstellungen   C Beenden   E Exceptions   F7 F8 F9 = Z T R'));
 PgAdd('');
 PgAdd(T3(' Other commands:',' Autres commandes :',' Weitere Befehle:'));
 PgAdd(T3('  R run (various)  U run until  G search  N next  C compare  I copy',
  '  R executer (divers)  U jusqu''a  G che'+
    'rcher  N suivant  C comparer  I copier',
  '  R Starten (diverse)  U bis  G Suchen  '+
    'N Weiter  C Vergleichen  I Kopieren'));
 PgAdd(T3('  W fill  Q query port  T transfer to po'+
   'rt  A load ASCII  B load binary',
  '  W remplir  Q lire port  T ecrire port  A charger ASCII  B charger binaire',
  '  W Fuellen  Q Port lesen  T Port schrei'+
    'ben  A ASCII laden  B Binaer laden'));
 PgAdd(T3('  S save binary  E exe symbols  H histor'+
   'y  L list labels  P disassemble',
  '  S sauver binaire  E symboles  H historique  L symboles  P desassembler',
  '  S Binaer speichern  E Symbole  H Verlauf  L Labels  P Disassemblieren'));
 PgAdd(T3('  D change directory  V view program scr'+
   'een  M modify address  0 other bases',
  '  D repertoire  V ecran du programme  M adresse  0 autres bases',
  '  D Verzeichnis  V Programmbildschirm  M Adresse  0 andere Basen'));
 PgAdd(T3('  :  text command line (T S G B D M ? reg=value)',
  '  :  ligne de commande texte (T S G B D M ? reg=valeur)',
  '  :  Textbefehlszeile (T S G B D M ? Reg=Wert)'));
 ShowPager(T3('Help, segments and breakpoints',
   'Aide, segments et points d''arret','Hilfe, Segmente und Haltepunkte'));
End;

Procedure MCmdHistory;
Var I,K,Len: Integer; S: String; E: Integer;
Begin
 PgN:=0;
 If HCnt=0 Then
   PgAdd(' '+T3('History buffer is empty','L''historique est vide',
   'Der Verlaufspuffer ist leer'));
 For I:=0 To HCnt-1 Do Begin
  E:=((HHead-I) Mod HMAX+HMAX) Mod HMAX;
  S:=' d';
  For K:=0 To 7 Do S:=S+' '+Hex8(Hist[E].R[K]);
  PgAdd(S);
  S:=' a';
  For K:=8 To 15 Do S:=S+' '+Hex8(Hist[E].R[K]);
  PgAdd(S);
  S:=' sr='+Hex4(Hist[E].SRx)+'  pc='+Hex8(Hist[E].PCv)+'  ';
  If Rdbl(Hist[E].PCv) Then S:=S+MDis(Hist[E].PCv,Len)+BpMark(Hist[E].PCv);
  PgAdd(S);
  PgAdd('');
 End;
 ShowPager(T3('History buffer (newest first)',
   'Tampon d''historique (le plus recent d'''+'abord)',
   'Verlaufspuffer (neuester zuerst)'));
End;

Procedure MCmdListLabels;
Var Cols,Rows,I,J,K,Pgs: Integer; E: TEvent; Top: Integer;
Begin
 If DbgN=0 Then Begin
   MonAlert(T3('No symbols loaded','Aucun symbole charge',
   'Keine Symbole geladen'));Exit;End;
 Rows:=NRows-3;Cols:=3;
 Top:=1;
 Repeat
  HideMouse;
  Box(0,0,SCR_W-1,SCR_H-1,PAPER);
  CT(0,0,80,' '+T3('Labels','Symboles','Labels')+' ('+IntStr(DbgN)+')',True);
  For J:=0 To Cols-1 Do
   For I:=0 To Rows-1 Do Begin
    K:=Top+J*Rows+I;
    If K<=DbgN Then
      CT(J*27,1+I,26,Hex8(DbgSyms^[K].Addr)+' '+DbgSyms^[K].Name,False);
   End;
  CT(0,NRows-1,80,T3(' Any key = next page, Esc = end',
    ' Une touche = page suivante, Esc = fin',
    ' Beliebige Taste = naechste Seite, Esc ='+' Ende'),True);
  ShowMouse;
  Repeat PollEvent(E);Until E.Kind=1;
  If E.Key=K_ESC Then Break;
  Top:=Top+Rows*Cols;
  If Top>DbgN Then Break;
 Until False;
 Pgs:=0;
End;

{ ---------------------------------------------------------------------- }
{ Commandes de fenetre                                                     }
{ ---------------------------------------------------------------------- }

Function CurKind: Integer;
Begin
 CurKind:=MW[MCur].V[MW[MCur].Top].Kind;
End;

Procedure MCmdSetAddr;
Var S: String; V: LongInt;
Begin
 If CurKind=VK_REG Then Exit;
 If (CurKind=VK_SRC) And (SrcFileOfView(MW[MCur].V[MW[MCur].Top])=0) Then Exit;
 S:='';
 If MonPrompt(T3('Window start address?','Adresse de debut de la fenetre ?',
   'Startadresse des Fensters?'),S,PV_EXPR) Then
  If MonEval(S,V) Then SetWinAddr(MCur,V);
 ClrErr;
End;

Procedure MCmdGotoLine;
Var S: String; V: LongInt;
Begin
 If CurKind<>VK_SRC Then Exit;
 S:='';
 If MonPrompt(T3('Goto line?','Aller a la ligne ?','Gehe zu Zeile?'),S,PV_EXPR)
   Then
  If MonEval(S,V) Then Begin
   If V<1 Then V:=1;
   With MW[MCur].V[MW[MCur].Top] Do
    If (Src>=1) And (V>MSrc[Src].Cnt) Then V:=MSrc[Src].Cnt;
   SetWinAddr(MCur,V);
  End;
End;

Procedure MCmdRegSet;
Var S: String;
Begin
 S:='';
 If MonPrompt(T3('Register set (reg=value)?',
   'Affecter un registre (reg=valeur) ?','Register setzen (Reg=Wert)?'),S,
   PV_REG) Then Begin
  RegAssign(S,True);
  UpdateLocks;
 End;
End;

Procedure MCmdEdit;
Begin
 Case CurKind Of
  VK_MEM: Begin
    EditOn:=True;EditAsc:=False;EditNib:=0;
    EditAddr:=MW[MCur].V[MW[MCur].Top].Addr;
   End;
  VK_REG: MCmdRegSet;
  VK_SRC: TabSrc4:=Not TabSrc4;
 End;
End;

Procedure EditKey(K: LongInt);
Var Bpl,B,D,Rows: Integer;
Begin
 With MW[MCur] Do Begin
  Bpl:=MemBpl(W);
  If W=0 Then Bpl:=MemBpl(80);
  Rows:=H-1;
  If Rows<1 Then Rows:=1;
  Case K Of
   K_ESC: Begin EditOn:=False;Exit;End;
   K_TAB: Begin EditAsc:=Not EditAsc;EditNib:=0;End;
   K_LEFT: Begin Dec(EditAddr);EditNib:=0;End;
   K_RIGHT: Begin Inc(EditAddr);EditNib:=0;End;
   K_UP: Dec(EditAddr,Bpl);
   K_DOWN: Inc(EditAddr,Bpl);
   K_PGUP: Dec(EditAddr,Bpl*Rows);
   K_PGDN: Inc(EditAddr,Bpl*Rows);
  Else Begin
    If EditAsc Then Begin
     If (K>=32) And (K<=255) Then Begin
      Wr8(EditAddr,K And $FF);ClrErr;Inc(EditAddr);
     End;
    End Else If (K<256) And IsHexCh(Chr(K)) Then Begin
     D:=HexVal(Chr(K));
     B:=RdB(EditAddr);
     If B<0 Then B:=0;
     If EditNib=0 Then Begin B:=(B And $0F) Or (D Shl
       4);EditNib:=1;Wr8(EditAddr,B);End
     Else Begin B:=(B And $F0) Or
       D;EditNib:=0;Wr8(EditAddr,B);Inc(EditAddr);End;
     ClrErr;
    End;
   End;
  End;
  If EditAddr<0 Then EditAddr:=0;
  If EditAddr<V[Top].Addr Then V[Top].Addr:=EditAddr-(EditAddr Mod Bpl)
  Else If EditAddr>=V[Top].Addr+Bpl*Rows Then
   V[Top].Addr:=EditAddr-(EditAddr Mod Bpl)-Bpl*(Rows-1);
  If V[Top].Addr<0 Then V[Top].Addr:=0;
 End;
End;

Procedure MCmdFont;
Begin
 If CellH=10 Then CellH:=8 Else CellH:=10;
 NRows:=SCR_H Div CellH;
 If CellH=8 Then RegRows:=RegRows+2 Else If RegRows>2 Then RegRows:=RegRows-2;
 If RegRows<3 Then RegRows:=3;
End;

Procedure MCmdLock;
Var S: String;
Begin
 With MW[MCur] Do Begin
  If V[Top].Kind=VK_REG Then Exit;
  S:=V[Top].Lock;
  If MonPrompt(T3('Lock to expression?','Verrouiller sur l''expression ?',
    'An Ausdruck binden?'),S,PV_EXPR0) Then Begin
   V[Top].Lock:=TrimS(S);
   UpdateLocks;
  End;
 End;
End;

Procedure MCmdSplit;
Begin
 If MCur=1 Then Exit;
 If (MCur=2) Or (MCur=4) Then SplL:=(SplL+1) Mod 4 Else SplR:=(SplR+1) Mod 4;
End;

Procedure MCmdWiden;
Begin
 If MCur=1 Then Exit;
 If (MCur=2) Or (MCur=4) Then Begin
  If ColSt=0 Then ColSt:=1 Else If ColSt=1 Then ColSt:=2 Else ColSt:=0;
 End Else Begin
  If ColSt=0 Then ColSt:=3 Else If ColSt=3 Then ColSt:=4 Else ColSt:=0;
 End;
End;

Procedure MCmdType;
Var K,N: Integer;
Begin
 If (MCur=3) Or (MCur=5) Then Exit;
 With MW[MCur] Do Begin
  K:=V[Top].Kind;
  For N:=1 To 4 Do Begin
   K:=(K+1) Mod 4;
   If AllowedKind(MCur,K) And ((K<>VK_SRC) Or (NSrc>0)) Then Break;
  End;
  If (V[Top].Kind=VK_REG) And (K<>VK_REG) Then V[Top].Addr:=MMem[1];
  If K=VK_REG Then MMem[1]:=V[Top].Addr;
  V[Top].Kind:=K;
  If K=VK_SRC Then Begin
   V[Top].Src:=0;V[Top].Addr:=1;
   If (LtN>0) And SrcApply(MCur,Top,PC,False) Then V[Top].Lock:='pc'   { source
     assemble : verrouille sur le PC }
   Else Begin V[Top].Src:=1;V[Top].Addr:=1;V[Top].Lock:='';End;
  End;
  If K<>VK_DIS Then If K<>VK_MEM Then If K<>VK_SRC Then V[Top].Lock:='';
 End;
End;

Procedure MCmdZoom;
Begin
 MZoom:=Not MZoom;
End;

Procedure MCmdOpenView;
Begin
 If MZoom Then Exit;
 With MW[MCur] Do Begin
  If NV>=MAXVIEW Then Exit;
  Inc(NV);
  V[NV]:=V[Top];
  Top:=NV;
 End;
End;

Procedure MCmdCloseView;
Var J: Integer;
Begin
 If MZoom Then Exit;
 With MW[MCur] Do Begin
  If NV<=1 Then Exit;
  For J:=Top To NV-1 Do V[J]:=V[J+1];
  Dec(NV);
  If Top>NV Then Top:=NV;
 End;
End;

Procedure MCmdNextView(Dir: Integer);
Begin
 If MZoom Then Exit;
 With MW[MCur] Do Begin
  Top:=Top+Dir;
  If Top>NV Then Top:=1;
  If Top<1 Then Top:=NV;
 End;
End;

Procedure SelectWin(N: Integer);
Begin
 If (N<1) Or (N>NWIN) Then Exit;
 MCur:=N;
 EditOn:=False;
 Layout;
 If (N>1) And (MW[N].W=0) And Not MZoom Then
  SetMsg(T3('Window ','Fenetre ','Fenster ')+IntStr(N)+
    T3(' is hidden (Alt-S / Alt-W / Alt-Z)',
    ' est masquee (Alt-S / Alt-W / Alt-Z)',
    ' ist verdeckt (Alt-S / Alt-W / Alt-Z)'));
End;

{ Rend visible la fenetre N (chargement d'un fichier source) }
Procedure RevealWin(N: Integer);
Begin
 Layout;
 If (N<2) Or (MW[N].W>0) Then Exit;
 If (N=2) Or (N=4) Then Begin
  If LeftWs[ColSt]<8 Then ColSt:=0;
  If N=2 Then SplL:=0 Else SplL:=1;
 End Else Begin
  If 80-LeftWs[ColSt]<8 Then ColSt:=0;
  If N=3 Then SplR:=0 Else SplR:=1;
 End;
 Layout;
End;

Function PrevInstr(A: LongInt): LongInt;
Var K,L: Integer; T: String;
Begin
 PrevInstr:=A-2;
 K:=2;
 While K<=10 Do Begin
  T:=Dis(A-K,L);ClrErr;
  If L=K Then Begin PrevInstr:=A-K;Exit;End;
  Inc(K,2);
 End;
End;

Procedure CursorKey(K: LongInt);
Var Bpl,Len,I,Rows: Integer; A: LongInt; T: String;
Begin
 With MW[MCur] Do Begin
  Rows:=H-1;
  If Rows<1 Then Rows:=1;
  A:=V[Top].Addr;
  Case V[Top].Kind Of
   VK_MEM: Begin
     Bpl:=MemBpl(W);
     Case K Of
      K_LEFT: A:=A-1;
      K_RIGHT: A:=A+1;
      K_UP: A:=A-Bpl;
      K_DOWN: A:=A+Bpl;
      K_PGUP: A:=A-Bpl*Rows;
      K_PGDN: A:=A+Bpl*Rows;
     End;
    End;
   VK_DIS: Begin
     Case K Of
      K_LEFT: A:=A-2;
      K_RIGHT: A:=A+2;
      K_UP: A:=PrevInstr(A);
      K_DOWN: Begin T:=Dis(A,Len);ClrErr;A:=A+Len;End;
      K_PGUP: For I:=1 To Rows-1 Do A:=PrevInstr(A);
      K_PGDN: For I:=1 To Rows-1 Do Begin T:=Dis(A,Len);ClrErr;A:=A+Len;End;
     End;
    End;
   VK_SRC: Begin
     Case K Of
      K_UP,K_LEFT: A:=A-1;
      K_DOWN,K_RIGHT: A:=A+1;
      K_PGUP: A:=A-Rows;
      K_PGDN: A:=A+Rows;
     End;
     If A<1 Then A:=1;
     If (V[Top].Src>=1) And (A>MSrc[V[Top].Src].Cnt) Then
       A:=MSrc[V[Top].Src].Cnt;
    End;
  End;
  If V[Top].Kind<>VK_REG Then Begin
   If A<0 Then A:=0;
   SetWinAddr(MCur,A);
  End;
 End;
End;

{ ---------------------------------------------------------------------- }
{ Impression                                                               }
{ ---------------------------------------------------------------------- }

Var PrnF: Text; PrnFile: Boolean;

Procedure PrnLine(Const S: String);
Var I: Integer;
Begin
 If PrnFile Then WriteLn(PrnF,S)
 Else Begin
  For I:=1 To Length(S) Do PrnPut(Ord(S[I]));
  PrnPut(13);PrnPut(10);
 End;
End;

Function PrnOpen(Const Name: String): Boolean;
Begin
 PrnOpen:=True;
 PrnFile:=Name<>'';
 If PrnFile Then Begin
  Assign(PrnF,Name);
  {$I-}
  Rewrite(PrnF);
  {$I+}
  If IOResult<>0 Then Begin PrnOpen:=False;PrnFile:=False;End;
 End;
End;

Procedure PrnClose;
Begin
 If PrnFile Then Begin
  {$I-}
  Close(PrnF);
  {$I+}
  If IOResult<>0 Then Begin End;
 End;
End;

Procedure MCmdPrint;
Var S: String; R,Len: Integer;
Begin
 S:='';
 If Not
   MonPrompt(T3('Print window to file (blank = printer)?',
   'Imprimer la fenetre dans le fichier (vid'+'e = imprimante) ?',
   'Fenster in Datei drucken (leer = Drucker'+')?'),S,PV_FREE) Then Exit;
 If Not PrnOpen(TrimS(S)) Then Begin
   MonAlert(T3('Cannot create the file','Impossible de creer le fichier',
   'Datei kann nicht erzeugt werden'));Exit;End;
 Layout;
 PrnLine(WinTitle(MCur));
 With MW[MCur] Do
  For R:=0 To H-2 Do PrnLine(WinRow(MCur,R,Len));
 PrnClose;
 SetMsg(T3('Window printed','Fenetre imprimee','Fenster gedruckt'));
End;

{ ---------------------------------------------------------------------- }
{ Points d'arret : commandes                                               }
{ ---------------------------------------------------------------------- }

Procedure MCmdBreak;
Var S: String;
Begin
 S:='';
 If MonPrompt(T3('Set breakpoint (address[,spec])?',
   'Point d''arret (adresse[,type]) ?','Haltepunkt setzen (Adresse[,Art])?'),S,
   PV_BP) Then
  BpParse(S,True);
End;

Procedure MCmdBpHere;
Var I: Integer; A: LongInt;
Begin
 If (CurKind<>VK_DIS) And (CurKind<>VK_SRC) Then Exit;
 A:=WinAddrOf(MCur);
 If (CurKind=VK_SRC) And (SrcFileOfView(MW[MCur].V[MW[MCur].Top])=0) Then Exit;
 If Odd(A) Or Not Rdbl(A) Then Exit;
 I:=BpFindAt(A);
 If I>0 Then BpDel(I)
 Else If Not BpAddSimple(A) Then
   MonAlert(T3('Too many breakpoints','Trop de points d''arret',
   'Zu viele Haltepunkte'));
End;

Procedure MCmdKill;
Begin
 NMB:=0;
 SetMsg(T3('Breakpoints cleared','Points d''arret effaces',
   'Haltepunkte geloescht'));
End;

Procedure MCmdBdos;
Var S: String; V: LongInt;
Begin
 S:='';
 If BdosBp>=0 Then S:=Hex2(BdosBp);
 If MonPrompt(T3('BDOS call number (blank = clear)?',
   'Numero d''appel BDOS (vide = effacer) ?',
   'BDOS-Funktionsnummer (leer = loeschen)?'),S,PV_EXPR0) Then Begin
  If TrimS(S)='' Then BdosBp:=-1
  Else If MonEval(S,V) Then BdosBp:=V And $FFFF;
 End;
End;

Procedure MCmdBreakAfter;
Var Len: Integer; T: String;
Begin
 If Not CanRun Then Exit;
 T:=MDis(PC,Len);
 If Not BpAddSimple(PC+Len) Then Begin
   MonAlert(T3('Too many breakpoints','Trop de points d''arret',
   'Zu viele Haltepunkte'));Exit;End;
 ExecRun(EX_GO,0,'',False,-1,0);
End;

Procedure MCmdUntil;
Var S: String;
Begin
 If Not CanRun Then Exit;
 S:='';
 If MonPrompt(T3('Run until address[,spec]?',
   'Executer jusqu''a adresse[,type] ?','Ausfuehren bis Adresse[,Art]?'),S,
   PV_BP) Then Begin
  BpParse(S,True);
  ExecRun(EX_GO,0,'',False,-1,0);
 End;
End;

Procedure MCmdRunVarious;
Var C,W: Char; S: String; V: LongInt; Cnt: LongInt; Mode: Integer;
Begin
 If Not CanRun Then Exit;
 C:=MonAskKey(T3('Run (G)o (S)lowly (I)nstruction (U)ntil?',
   'Executer (G)o (S)lowly (I)nstruction (U)'+'ntil ?',
   'Ausfuehren (G)o (S)lowly (I)nstruction ('+'U)ntil?'),'GSIU');
 If C=#0 Then Exit;
 If C='G' Then Begin ExecRun(EX_GO,0,'',False,-1,0);Exit;End;
 S:='';Cnt:=0;Mode:=EX_SLOW;
 If C='I' Then Begin
  If Not
    MonPrompt(T3('Number of instructions?','Nombre d''instructions ?',
    'Anzahl der Befehle?'),S,PV_EXPR) Then Exit;
  MonEval(S,Cnt);Mode:=EX_COUNT;
 End Else If C='U' Then Begin
  If Not
    MonPrompt(T3('Run until expression?','Executer jusqu''a l''expression ?',
    'Ausfuehren bis Ausdruck?'),S,PV_EXPR) Then Exit;
  Mode:=EX_UNTIL;
 End;
 W:=MonAskKey(T3('Watch Y/N?','Observer O/N ?','Beobachten J/N?'),'YNO');
 If W=#0 Then Exit;
 ExecRun(Mode,Cnt,S,(W='Y') Or (W='O'),-1,0);
End;

{ ---------------------------------------------------------------------- }
{ Autres commandes                                                         }
{ ---------------------------------------------------------------------- }

Procedure MCmdBases;
Var S,T: String; V: LongInt;
Begin
 S:='';
 If Not
   MonPrompt(T3('Enter expression','Entrez une expression','Ausdruck eingeben'),
   S,PV_EXPR) Then Exit;
 If Not MonEval(S,V) Then Exit;
 T:=SymNear(V);
 If T<>'' Then T:='  '+T;
 MonAlert('$'+Hex8(V)+'  \'+IntStr(V)+T);
End;

Procedure MCmdViewScreen;
Var E: TEvent;
Begin
 EmuVisible:=True;
 BlitScreen(True);
 Repeat PollEvent(E);Until E.Kind=1;
 EmuVisible:=False;
End;

Procedure MCmdTerminate;
Begin
 If MonLoaded And Not ProgDead Then Begin
  ProgDead:=True;
  CloseAllFiles;
  SetMsg(T3('Program Terminated','Programme termine','Programm beendet'));
 End Else MonQuit:=True;
End;

{ Chargement d'un programme (Ctrl-L, ligne de commande) }
Function DoLoad(Const Name,Cmd: String): Boolean;
Var I,F,S: Integer; A,L: LongInt;
Begin
 DoLoad:=False;
 If Not FileExists(Name) Then Begin
  MonAlert(T3('File not found: ','Fichier introuvable : ',
    'Datei nicht gefunden: ')+Name);Exit;
 End;
 If Not LoadProgram(Name,Cmd,OptRunGem) Then Begin
  MonLoaded:=False;
  MonAlert(T3('Invalid program load format','Format de programme invalide',
    'Ungueltiges Programmformat'));Exit;
 End;
 ClrErr;
 MonLoaded:=True;ProgDead:=False;ProgName:=Name;
 NMB:=0;BdosBp:=-1;HCnt:=0;HHead:=0;
 MMem[8]:=0;MMem[9]:=0;
 InitView(MW[2].V[1],VK_DIS,PC);MW[2].V[1].Lock:='pc';MW[2].NV:=1;MW[2].Top:=1;
 InitView(MW[3].V[1],VK_MEM,Rg[15]);MW[3].NV:=1;MW[3].Top:=1;
 InitView(MW[4].V[1],VK_DIS,SegAddr(0));MW[4].NV:=1;MW[4].Top:=1;
 InitView(MW[5].V[1],VK_MEM,SegAddr(1));MW[5].NV:=1;MW[5].Top:=1;
 MW[1].NV:=1;MW[1].Top:=1;InitView(MW[1].V[1],VK_REG,0);
 { informations de ligne : fenetre source (2) verrouillee sur le PC,
   desassemblage en 4 }
 For I:=1 To NSrc Do FreeLines(MSrc[I].Arr,MSrc[I].Cnt);
 NSrc:=0;
 MLoadLineInfo(Name);
 If (LtN>0) And PfAutoSrc Then Begin
  If Not MAddrLine(PC,F,L) Then F:=1;
  S:=LoadSrcFile(F);
  If S>0 Then Begin
   InitView(MW[2].V[1],VK_SRC,1);MW[2].V[1].Src:=S;MW[2].V[1].Lock:='pc';
   InitView(MW[4].V[1],VK_DIS,PC);MW[4].V[1].Lock:='pc';
   SplL:=1;ColSt:=1;MCur:=2;
  End;
 End;
 UpdateLocks;
 ConClear;
 If Emu_GEM Then GemBoot;
 ClrErr;
 EmuVisible:=False;
 SetMsg(T3('Breakpoint','Point d''arret','Haltepunkt'));
 If PfLabel<>'' Then Begin
  If MSymByName(PfLabel,A) Then Begin
   If A<>PC Then If BpAddSimple(A) Then ExecRun(EX_GO,0,'',False,-1,0);
  End;
 End;
 DoLoad:=True;
End;

Procedure MCmdLoadProg;
Var S,C: String;
Begin
 If MonLoaded And Not ProgDead Then Begin
  MonAlert(T3('A program is already loaded (Ctrl-C to t'+'erminate it)',
    'Un programme est deja charge (Ctrl-C pou'+'r le terminer)',
    'Ein Programm ist bereits geladen (Ctrl-C'+' beendet es)'));
  Exit;
 End;
 S:='';C:='';
 If Not
   MonPrompt(T3('Executable file to load','Fichier executable a charger',
   'Zu ladendes Programm'),S,PV_FREE) Then Exit;
 S:=TrimS(S);
 If S='' Then Exit;
 If MonPrompt(T3('Command line?','Ligne de commande ?','Kommandozeile?'),C,
   PV_FREE) Then Begin End Else C:='';
 DoLoad(S,C);
End;

{ Fichiers binaires }
Procedure MCmdLoadBin;
Var S,Nm: String; P: Integer; A,Len,I: LongInt; Buf: Pointer; Ad: String;
Begin
 S:='';
 If Not
   MonPrompt(T3('Load binary file[,address]?',
   'Charger le fichier binaire[,adresse] ?','Binaerdatei laden[,Adresse]?'),S,
   PV_FREE) Then Exit;
 P:=Pos(',',S);
 If P>0 Then Begin Nm:=TrimS(Copy(S,1,P-1));Ad:=TrimS(Copy(S,P+1,60));End
 Else Begin Nm:=TrimS(S);Ad:='';End;
 If Nm='' Then Exit;
 If Not ReadAll(Nm,Buf,Len) Then Begin
   MonAlert(T3('File not found: ','Fichier introuvable : ',
   'Datei nicht gefunden: ')+Nm);Exit;End;
 If Ad<>'' Then Begin
  If Not MonEval(Ad,A) Then Begin
   MonAlert(T3('Bad address','Adresse incorrecte','Falsche Adresse'));If
     Buf<>Nil Then FreeMem(Buf,Len);Exit;
  End;
 End Else Begin
  A:=(HeapLo+1) And (Not 1);
  If A+Len>HeapHi Then Begin
   MonAlert(T3('Not enough memory','Memoire insuffisante',
     'Nicht genug Speicher'));If Buf<>Nil Then FreeMem(Buf,Len);Exit;
  End;
  HeapLo:=A+Len;
 End;
 For I:=0 To Len-1 Do Wr8(A+I,BufB(Buf,I));
 ClrErr;
 If Buf<>Nil Then FreeMem(Buf,Len);
 MMem[8]:=A;MMem[9]:=A+Len-1;
 SetMsg(T3('Loaded $','Charge $','Geladen $')+Hex8(Len)+T3(' bytes at $',
   ' octets en $',' Bytes bei $')+Hex8(A));
End;

Procedure MCmdSaveBin;
Var S: String; P: Array[0..3] Of String; N: Integer; A,B,I: LongInt; F: File;
  Buf: Array[0..4095] Of Byte; K: Integer;
Begin
 S:='';
 If Not
   MonPrompt(T3('Save binary file,start,end?',
   'Sauver le fichier binaire,debut,fin ?','Binaerdatei speichern,Start,Ende?'),
   S,PV_FREE) Then Exit;
 N:=SplitList(S,P,4);
 If (N<3) Or Not MonEval(P[1],A) Or Not MonEval(P[2],B) Or (B<A) Then Begin
  MonAlert(T3('Bad parameters','Parametres incorrects',
    'Falsche Parameter'));Exit;
 End;
 Assign(F,P[0]);
 {$I-}
 Rewrite(F,1);
 {$I+}
 If IOResult<>0 Then Begin
   MonAlert(T3('Cannot create the file','Impossible de creer le fichier',
   'Datei kann nicht erzeugt werden'));Exit;End;
 I:=A;K:=0;
 While I<=B Do Begin
  Buf[K]:=Rd8(I);Inc(K);Inc(I);
  If K=4096 Then Begin BlockWrite(F,Buf,K);K:=0;End;
 End;
 If K>0 Then BlockWrite(F,Buf,K);
 Close(F);
 ClrErr;
 SetMsg(T3('Saved $','Sauve $','Gespeichert $')+Hex8(B-A+1)+T3(' bytes',
   ' octets',' Bytes'));
End;

Procedure MCmdLoadAscii;
Var S: String; Wn: Integer; C: Char; Arr: PLineArr; Cnt: Integer;
Begin
 S:='';
 If Not
   MonPrompt(T3('Load ASCII file?','Charger le fichier ASCII ?',
   'ASCII-Datei laden?'),S,PV_FREE) Then Exit;
 S:=TrimS(S);
 If S='' Then Exit;
 If NSrc>=MMAXSRC Then Begin
   MonAlert(T3('Too many files','Trop de fichiers',
   'Zu viele Dateien'));Exit;End;
 If Not LoadLines(S,Arr,Cnt) Then Begin
   MonAlert(T3('File not found: ','Fichier introuvable : ',
   'Datei nicht gefunden: ')+S);Exit;End;
 If (MCur=2) Or (MCur=4) Then Wn:=MCur
 Else Begin
  C:=MonAskKey(T3('Load into window 2 or 4?','Charger dans la fenetre 2 ou 4 ?',
    'In Fenster 2 oder 4 laden?'),'24');
  If C=#0 Then Begin FreeLines(Arr,Cnt);Exit;End;
  Wn:=Ord(C)-48;
 End;
 Inc(NSrc);
 MSrc[NSrc].Name:=S;MSrc[NSrc].Arr:=Arr;MSrc[NSrc].Cnt:=Cnt;MSrc[NSrc].Fil:=0;
 With MW[Wn] Do Begin
  If V[Top].Kind=VK_SRC Then Begin
   If NV<MAXVIEW Then Begin Inc(NV);Top:=NV;End;
  End;
  InitView(V[Top],VK_SRC,1);V[Top].Src:=NSrc;
 End;
 RevealWin(Wn);
 MCur:=Wn;
 SetMsg(S);
End;

Procedure MCmdExeSyms;
Var S,Nm: String; P: Integer; A,TB,TS,DS,SS,Sym,Off: LongInt; Buf: Pointer;
  Len: LongInt;
    Typ: LongInt; J: Integer; Name: String; Cnt: Integer;
Begin
 S:='';
 If Not
   MonPrompt(T3('Executable file to use[,text address]?',
   'Executable a utiliser[,adresse du texte]'+' ?',
   'Zu verwendendes Programm[,Textadresse]?'),S,PV_FREE) Then Exit;
 P:=Pos(',',S);
 If P>0 Then Begin Nm:=TrimS(Copy(S,1,P-1));If Not MonEval(Copy(S,P+1,60),TB)
   Then Exit;End
 Else Begin Nm:=TrimS(S);TB:=SegAddr(0);If TB=0 Then TB:=BP_ADDR+$100;End;
 If Not ReadAll(Nm,Buf,Len) Then Begin
   MonAlert(T3('File not found: ','Fichier introuvable : ',
   'Datei nicht gefunden: ')+Nm);Exit;End;
 If (Len<28) Or (BufW(Buf,0)<>$601A) Then Begin
  MonAlert(T3('Invalid program load format','Format de programme invalide',
    'Ungueltiges Programmformat'));
  If Buf<>Nil Then FreeMem(Buf,Len);Exit;
 End;
 TS:=BufL(Buf,2);DS:=BufL(Buf,6);SS:=BufL(Buf,14);
 Sym:=28+TS+DS;Cnt:=0;DbgN:=0;
 While (SS>=14) And (Sym+14<=28+TS+DS+SS) Do Begin
  Name:='';
  For J:=0 To 7 Do If BufB(Buf,Sym+J)<>0 Then Name:=Name+Chr(BufB(Buf,Sym+J));
  Typ:=BufW(Buf,Sym+8);
  If (Typ And $0048)=$0048 Then Begin
   For J:=0 To 13 Do If BufB(Buf,Sym+14+J)<>0 Then
     Name:=Name+Chr(BufB(Buf,Sym+14+J));
   DbgAdd(Name,BufL(Buf,Sym+10)+TB);Inc(Cnt);
   Inc(Sym,28);
  End Else Begin
   If (Typ And $8000)<>0 Then Begin
     DbgAdd(Name,BufL(Buf,Sym+10)+TB);Inc(Cnt);End;
   Inc(Sym,14);
  End;
 End;
 If Buf<>Nil Then FreeMem(Buf,Len);
 Off:=0;A:=0;
 SetMsg(IntStr(Cnt)+T3(' symbols loaded',' symboles charges',
   ' Symbole geladen'));
End;

{ Memoire : fill, copy, compare, ports }
Procedure Get3(Const S: String; Var A,B,C: LongInt; Var Ok: Boolean);
Var P: Array[0..3] Of String; N: Integer;
Begin
 N:=SplitList(S,P,4);
 Ok:=(N=3) And MonEval(P[0],A) And MonEval(P[1],B) And MonEval(P[2],C);
 ClrErr;
End;

Procedure MCmdFill;
Var S: String; A,B,C,I: LongInt; Ok: Boolean;
Begin
 S:='';
 If Not
   MonPrompt(T3('Fill start,end,byte?','Remplir debut,fin,octet ?',
   'Fuellen Start,Ende,Byte?'),S,PV_EXPRL) Then Exit;
 Get3(S,A,B,C,Ok);
 If Not Ok Or (B<A) Then Begin
   MonAlert(T3('Bad parameters','Parametres incorrects',
   'Falsche Parameter'));Exit;End;
 For I:=A To B Do Wr8(I,C And $FF);
 ClrErr;
End;

Procedure MCmdCopy;
Var S: String; A,B,C,I,N: LongInt; Ok: Boolean;
Begin
 S:='';
 If Not
   MonPrompt(T3('Copy start,end,destination?','Copier debut,fin,destination ?',
   'Kopieren Start,Ende,Ziel?'),S,PV_EXPRL) Then Exit;
 Get3(S,A,B,C,Ok);
 If Not Ok Or (B<A) Then Begin
   MonAlert(T3('Bad parameters','Parametres incorrects',
   'Falsche Parameter'));Exit;End;
 N:=B-A+1;
 If C<=A Then For I:=0 To N-1 Do Wr8(C+I,Rd8(A+I))
 Else For I:=N-1 DownTo 0 Do Wr8(C+I,Rd8(A+I));
 ClrErr;
End;

Procedure MCmdCompare;
Var S: String; A,B,C,I: LongInt; Ok: Boolean;
Begin
 S:='';
 If Not
   MonPrompt(T3('Compare start,end,other start?',
   'Comparer debut,fin,debut du second bloc '+'?',
   'Vergleichen Start,Ende,anderer Start?'),S,PV_EXPRL) Then Exit;
 Get3(S,A,B,C,Ok);
 If Not Ok Or (B<A) Then Begin
   MonAlert(T3('Bad parameters','Parametres incorrects',
   'Falsche Parameter'));Exit;End;
 For I:=0 To B-A Do
  If RdB(A+I)<>RdB(C+I) Then Begin
   SetWinAddr(2,A+I);SetWinAddr(3,A+I);SetWinAddr(4,C+I);SetWinAddr(5,C+I);
   SetMsg(T3('Difference at $','Difference en $','Unterschied bei $')+Hex8(A+
     I));
   Exit;
  End;
 SetMsg(T3('Memory areas are identical','Les zones sont identiques',
   'Die Speicherbereiche sind identisch'));
End;

Procedure MCmdQuery;
Var S: String; P: Array[0..3] Of String; N: Integer; A,V: LongInt; Sz: Integer;
  T: String;
Begin
 S:='';
 If Not
   MonPrompt(T3('Query port address[,W|L]?','Lire le port adresse[,W|L] ?',
   'Port lesen Adresse[,W|L]?'),S,PV_EXPRL) Then Exit;
 N:=SplitList(S,P,4);
 If (N<1) Or Not MonEval(P[0],A) Then Exit;
 Sz:=1;
 If (N>1) And ((P[1]='W') Or (P[1]='w')) Then Sz:=2;
 If (N>1) And ((P[1]='L') Or (P[1]='l')) Then Sz:=4;
 If Sz=1 Then Begin V:=Rd8(A);T:=Hex2(V);End
 Else If Sz=2 Then Begin V:=Rd16(A);T:=Hex4(V);End
 Else Begin V:=Rd32(A);T:=Hex8(V);End;
 ClrErr;
 MonAlert('$'+Hex8(A)+' = $'+T);
End;

Procedure MCmdTransfer;
Var S: String; P: Array[0..3] Of String; N: Integer; A,V: LongInt;
Begin
 S:='';
 If Not
   MonPrompt(T3('Transfer address,data[,W|L]?','Ecrire adresse,donnee[,W|L] ?',
   'Port schreiben Adresse,Daten[,W|L]?'),S,PV_EXPRL) Then Exit;
 N:=SplitList(S,P,4);
 If (N<2) Or Not MonEval(P[0],A) Or Not MonEval(P[1],V) Then Exit;
 If (N>2) And ((P[2]='W') Or (P[2]='w')) Then Wr16(A,V)
 Else If (N>2) And ((P[2]='L') Or (P[2]='l')) Then Wr32(A,V)
 Else Wr8(A,V And $FF);
 ClrErr;
End;

Procedure MCmdChDir;
Var S: String;
Begin
 S:='';
 If Not
   MonPrompt(T3('Change drive & directory to?',
   'Changer de lecteur et de repertoire ?',
   'Laufwerk und Verzeichnis wechseln nach?'),S,PV_FREE) Then Exit;
 S:=TrimS(S);
 If S='' Then Exit;
 {$I-}
 ChDir(S);
 {$I+}
 If IOResult<>0 Then
   MonAlert(T3('Cannot change directory','Impossible de changer de repertoire',
   'Verzeichnis kann nicht gewechselt werden'))
 Else SetMsg(S);
End;

{ ---------------------------------------------------------------------- }
{ Recherche                                                                }
{ ---------------------------------------------------------------------- }

Function EscPressed: Boolean;
Var E: TEvent;
Begin
 EscPressed:=False;
 While KeyPressed Do Begin
  PollEvent(E);
  If (E.Kind=1) And (E.Key=K_ESC) Then EscPressed:=True;
 End;
End;

{ Recherche de texte dans la fenetre source (courante, sinon la premiere) }
Procedure DoSrcSearch;
Var W,I: Integer; Cnt,L,N: LongInt; Pat,T: String; Found: Boolean;
Begin
 W:=0;
 If MW[MCur].V[MW[MCur].Top].Kind=VK_SRC Then W:=MCur
 Else For I:=2 To NWIN Do If (W=0) And (MW[I].V[MW[I].Top].Kind=VK_SRC) Then
   W:=I;
 If W=0 Then Exit;
 With MW[W].V[MW[W].Top] Do Begin
  If (Src<1) Or (Src>NSrc) Or (SrchBuf='') Then Exit;
  Pat:=SrchBuf;
  If Not SrchCase Then Pat:=Upper(Pat);
  Cnt:=MSrc[Src].Cnt;
  Found:=False;L:=Addr;N:=0;
  While N<Cnt Do Begin
   Inc(L);If L>Cnt Then L:=1;
   Inc(N);
   T:=MSrc[Src].Arr^[L]^;
   If Not SrchCase Then T:=Upper(T);
   If Pos(Pat,T)>0 Then Begin Found:=True;Break;End;
  End;
  If Found Then Begin
   Addr:=L;
   SetMsg(T3('Found at line ','Trouve a la ligne ','Gefunden in Zeile ')+
     IntStr(L));
  End Else SetMsg(T3('Not found','Non trouve','Nicht gefunden'));
 End;
End;

Procedure DoSearch(FromA: LongInt);
Var A,Start,Cnt: LongInt; I,Len,N: Integer; Found: Boolean; T,Pat: String;
  Step2: Integer;
Begin
 If SrchBuf='' Then Begin
   SetMsg(T3('Nothing to search for','Rien a chercher',
   'Nichts zu suchen'));Exit;End;
 If SrchKind='S' Then Begin DoSrcSearch;Exit;End;
 Start:=FromA+1;
 If (Start<0) Or (Start>=MemSize) Then Start:=0;
 Found:=False;A:=Start;Cnt:=0;
 Pat:=SrchBuf;
 If (SrchKind='T') And Not SrchCase Then Pat:=Upper(Pat);
 If (SrchKind='I') And Not SrchCase Then Pat:=Upper(Pat);
 Repeat
  If SrchKind='I' Then Begin
   If Not Odd(A) Then Begin
    T:=MDis(A,Len);
    If Not SrchCase Then T:=Upper(T);
    If Pos(Pat,T)>0 Then Found:=True;
    If (Cnt And 255)=0 Then If EscPressed Then Begin
      SetMsg(T3('Search aborted','Recherche interrompue',
      'Suche abgebrochen'));Exit;End;
   End;
  End Else Begin
   N:=Length(Pat);
   If (SrchAlign<=1) Or ((A Mod SrchAlign)=0) Then Begin
    I:=1;
    While I<=N Do Begin
     If SrchKind='T' Then Begin
      If SrchCase Then Begin If Chr(Rd8(A+I-1))<>Pat[I] Then Break;End
      Else If UpCase(Chr(Rd8(A+I-1)))<>Pat[I] Then Break;
     End Else If Rd8(A+I-1)<>Ord(Pat[I]) Then Break;
     Inc(I);
    End;
    If I>N Then Found:=True;
   End;
   If (Cnt And 65535)=0 Then If EscPressed Then Begin
     SetMsg(T3('Search aborted','Recherche interrompue',
     'Suche abgebrochen'));Exit;End;
  End;
  If Found Then Break;
  Inc(A);Inc(Cnt);
  If A>=MemSize Then A:=0;
 Until A=Start;
 ClrErr;
 If Found Then Begin
  SetWinAddr(TargetWin,A);
  SetMsg(T3('Found at $','Trouve en $','Gefunden bei $')+Hex8(A));
 End Else SetMsg(T3('Not found','Non trouve','Nicht gefunden'));
End;

Procedure MCmdSearch;
Var C,Cs: Char; S: String; P: Array[0..15] Of String; N,I,Sz,Last: Integer; V:
  LongInt; Buf: String; Al: Integer;
Begin
 If CurKind=VK_SRC Then Begin
  { fenetre source : recherche de texte automatique }
  S:='';
  If Not
    MonPrompt(T3('Search for text?','Chercher le texte ?','Suchen nach Text?'),
    S,PV_FREE) Then Exit;
  If S='' Then Exit;
  Cs:=MonAskKey(T3('Ignore case Y/N?','Ignorer la casse O/N ?',
    'Gross-/Kleinschreibung ignorieren J/N?'),'YNO');
  If Cs=#0 Then Exit;
  SrchBuf:=S;SrchKind:='S';SrchAlign:=1;SrchCase:=(Cs='N');
  DoSrcSearch;
  Exit;
 End;
 C:=MonAskKey(T3('Search for B/W/L/T/I?','Chercher B/W/L/T/I ?',
   'Suchen nach B/W/L/T/I?'),'BWLTI');
 If C=#0 Then Exit;
 S:='';
 If (C='B') Or (C='W') Or (C='L') Then Begin
  If Not
    MonPrompt(T3('Search for (numbers, comma separated)?',
    'Chercher (nombres separes par des virgul'+'es) ?',
    'Suchen nach (Zahlen, durch Komma getrenn'+'t)?'),S,PV_EXPRL) Then Exit;
  N:=SplitList(S,P,16);
  Al:=1;Last:=N-1;
  If (N>1) And IsSizeTok(P[N-1]) Then Begin
   If UpCase(P[N-1][1])='W' Then Al:=2 Else Al:=4;
   Last:=N-2;
  End;
  If C='B' Then Sz:=1 Else If C='W' Then Sz:=2 Else Sz:=4;
  Buf:='';
  For I:=0 To Last Do Begin
   If Not MonEval(P[I],V) Then Exit;
   If Sz=4 Then Begin Buf:=Buf+Chr((V Shr 24) And 255)+Chr((V Shr 16) And
     255);End;
   If Sz>=2 Then Buf:=Buf+Chr((V Shr 8) And 255);
   Buf:=Buf+Chr(V And 255);
  End;
  SrchBuf:=Buf;SrchAlign:=Al;SrchKind:='B';SrchCase:=True;
 End Else Begin
  If C='T' Then Begin
   If Not
     MonPrompt(T3('Search for text?','Chercher le texte ?','Suchen nach Text?'),
     S,PV_FREE) Then Exit;
  End Else Begin
   If Not
     MonPrompt(T3('Search for instruction text?',
     'Chercher le texte de l''instruction ?','Suchen nach Befehlstext?'),S,
     PV_FREE) Then Exit;
  End;
  If S='' Then Exit;
  Cs:=MonAskKey(T3('Ignore case Y/N?','Ignorer la casse O/N ?',
    'Gross-/Kleinschreibung ignorieren J/N?'),'YNO');
  If Cs=#0 Then Exit;
  SrchBuf:=S;SrchKind:=C;SrchAlign:=1;SrchCase:=(Cs='N');
 End;
 If (CurKind=VK_SRC) Then Begin End;
 DoSearch(WinAddrOf(TargetWin));
End;

Procedure MCmdFindNext;
Begin
 DoSearch(WinAddrOf(TargetWin));
End;

{ Desassemblage vers l'imprimante ou un fichier }
Const MAXXR = 3000;
Var XrT: Array[1..MAXXR] Of LongInt; XrN: Integer;

{ Cible d'un saut, branchement, LEA/PEA absolu ou relatif au PC (references
  croisees) }
Function XrefTarget(A: LongInt; Var T: LongInt): Boolean;
Var Op,P: LongInt; Mode,Reg: Integer;
Begin
 XrefTarget:=False;
 Op:=Rd16(A);
 If (Op And $F000)=$6000 Then Begin
  If (Op And $FF)=0 Then T:=A+2+SExt(Rd16(A+2),2) Else T:=A+2+SExt(Op And
    $FF,1);
  XrefTarget:=True;
 End Else If (Op And $F0F8)=$50C8 Then Begin
  T:=A+2+SExt(Rd16(A+2),2);XrefTarget:=True;
 End Else Begin
  Mode:=(Op Shr 3) And 7;Reg:=Op And 7;
  If (Mode=7) And (Reg<=2) And (((Op And $FFC0)=$4E80) Or ((Op And
    $FFC0)=$4EC0) Or
     ((Op And $F1C0)=$41C0) Or ((Op And $FFC0)=$4840)) Then Begin
   P:=A+2;
   XrefTarget:=EAAddr(7,Reg,2,P,T);
  End;
 End;
 ClrErr;
End;

Function XrefHas(T: LongInt): Boolean;
Var I: Integer;
Begin
 XrefHas:=False;
 For I:=1 To XrN Do If XrT[I]=T Then Begin XrefHas:=True;Exit;End;
End;

Procedure XrefAdd(T: LongInt);
Begin
 If (XrN<MAXXR) And Not XrefHas(T) Then Begin Inc(XrN);XrT[XrN]:=T;End;
End;

Procedure MCmdDisFile;
Var S,Fn,T,Sym,Ln: String; P: Array[0..3] Of String; N,Len,K,I: Integer;
  A,A1,A2,D1,D2: LongInt;
    Dsz: Integer; Ds: Array[1..8] Of Record A,B: LongInt; Sz: Integer; End; ND:
      Integer; Disk: Boolean;
    InData: Boolean; Aborted: Boolean; Xref: Boolean; Tg: LongInt; Hs: String;
      Xr0: String;
Begin
 S:='';
 If Not
   MonPrompt(T3('Disassemble start,end?','Desassembler debut,fin ?',
   'Disassemblieren Start,Ende?'),S,PV_EXPRL) Then Exit;
 N:=SplitList(S,P,4);
 If (N<2) Or Not MonEval(P[0],A1) Or Not MonEval(P[1],A2) Or (A2<A1) Then Begin
  MonAlert(T3('Bad parameters','Parametres incorrects',
    'Falsche Parameter'));Exit;
 End;
 S:='';
 If Not
   MonPrompt(T3('Cross-reference buffer start,end (blank '+'= none)?',
   'Tampon de references croisees debut,fin '+'(vide = aucun) ?',
   'Querverweis-Puffer Start,Ende (leer = ke'+'iner)?'),S,PV_FREE) Then Exit;
 Xr0:=S;
 ND:=0;
 Repeat
  S:='';
  If Not
    MonPrompt(T3('Data area start,end[,B|W|L] (blank = end'+')?',
    'Zone de donnees debut,fin[,B|W|L] (vide '+'= fin) ?',
    'Datenbereich Start,Ende[,B|W|L] (leer = '+'Ende)?'),S,PV_FREE) Then Exit;
  If TrimS(S)='' Then Break;
  N:=SplitList(S,P,4);
  If (N>=2) And MonEval(P[0],D1) And MonEval(P[1],D2) And (ND<8) Then Begin
   Inc(ND);Ds[ND].A:=D1;Ds[ND].B:=D2;Ds[ND].Sz:=4;
   If (N>2) And (UpCase(P[2][1])='B') Then Ds[ND].Sz:=1;
   If (N>2) And (UpCase(P[2][1])='W') Then Ds[ND].Sz:=2;
  End;
 Until False;
 { references croisees : labels automatiques Lxxxxxx pour les cibles sans
   symbole }
 XrN:=0;
 Xref:=TrimS(Xr0)<>'';
 If Xref Then Begin
  A:=A1;
  While A<=A2 Do Begin
   InData:=False;Dsz:=2;
   For K:=1 To ND Do If (A>=Ds[K].A) And (A<=Ds[K].B) Then Begin
     InData:=True;Dsz:=Ds[K].Sz;End;
   If InData Then Len:=Dsz
   Else Begin
    T:=Dis(A,Len);
    If XrefTarget(A,Tg) Then
     If (Tg>=A1) And (Tg<=A2) And Not Odd(Tg) And (DbgFind(Tg)='') Then
       XrefAdd(Tg);
   End;
   If Len<2 Then Len:=2;
   A:=A+Len;
  End;
  ClrErr;
 End;
 Fn:='';
 If Not
   MonPrompt(T3('Output file (blank = printer)?',
   'Fichier de sortie (vide = imprimante) ?','Ausgabedatei (leer = Drucker)?'),
   Fn,PV_FREE) Then Exit;
 Fn:=TrimS(Fn);
 Disk:=Fn<>'';
 If Not PrnOpen(Fn) Then Begin
   MonAlert(T3('Cannot create the file','Impossible de creer le fichier',
   'Datei kann nicht erzeugt werden'));Exit;End;
 A:=A1;Aborted:=False;
 While A<=A2 Do Begin
  Sym:=DbgFind(A);
  If (Sym='') And Xref And XrefHas(A) Then Sym:='L'+Hex6(A);
  InData:=False;Dsz:=2;
  For K:=1 To ND Do If (A>=Ds[K].A) And (A<=Ds[K].B) Then Begin
    InData:=True;Dsz:=Ds[K].Sz;End;
  If InData Then Begin
   Len:=Dsz;
   If Dsz=1 Then T:='dc.b'+#9+'$'+Hex2(Rd8(A))
   Else If Dsz=2 Then T:='dc.w'+#9+'$'+Hex4(Rd16(A))
   Else T:='dc.l'+#9+'$'+Hex8(Rd32(A));
  End Else Begin
   T:=MDis(A,Len);
   If Xref And XrefTarget(A,Tg) And XrefHas(Tg) Then Begin
    { remplace l'adresse de la cible par son label automatique }
    Hs:=HexS(Tg);
    K:=Pos(Hs,T);
    If (K>0) And ((K+Length(Hs)>Length(T)) Or Not IsHexCh(T[K+Length(Hs)]))
      Then Begin
     Delete(T,K,Length(Hs));Insert('L'+Hex6(Tg),T,K);
    End;
   End;
   K:=Pos(' ',T);
   If K>0 Then Begin T[K]:=#9;End;
  End;
  If Disk Then Ln:=Sym+#9+T
  Else Begin
   Ln:=Hex8(A);
   For I:=0 To 9 Do Begin
    If I<Len Then Ln:=Ln+Hex2(Rd8(A+I)) Else Ln:=Ln+'  ';
    If Odd(I) Then Ln:=Ln+' ';
   End;
   Ln:=Ln+' '+PadR(Copy(Sym,1,12),12)+' '+T;
  End;
  PrnLine(Ln);
  A:=A+Len;
  If EscPressed Then Begin Aborted:=True;Break;End;
 End;
 PrnClose;
 ClrErr;
 If Aborted Then SetMsg(T3('Aborted','Interrompu','Abgebrochen')) Else
   SetMsg(T3('Disassembly written','Desassemblage ecrit',
   'Disassemblierung geschrieben'));
End;

{ Ligne de commande texte (touche ":") pour les habitues }
Procedure MCmdTextLine;
Var S,Cmd,Arg: String; P: Integer; V: LongInt;
Begin
 S:='';
 If Not
   MonPrompt(T3('Command (T S G B D M ? reg=value)',
   'Commande (T S G B D M ? reg=valeur)','Befehl (T S G B D M ? Reg=Wert)'),S,
   PV_FREE) Then Exit;
 S:=TrimS(S);
 If S='' Then Exit;
 P:=Pos('=',S);
 If (P>1) And (RegAssign(S,False)) And (Pos(' ',Copy(S,1,P-1))=0) Then Begin
  RegAssign(S,True);UpdateLocks;Exit;
 End;
 P:=Pos(' ',S);
 If P>0 Then Begin Cmd:=Upper(Copy(S,1,P-1));Arg:=TrimS(Copy(S,P+1,100));End
 Else Begin Cmd:=Upper(S);Arg:='';End;
 If Cmd='?' Then Begin
  If MonEval(Arg,V) Then MonAlert('$'+Hex8(V)+'  \'+IntStr(V)) Else
    MonAlert(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else If (Cmd='T') Or (Cmd='Z') Then Begin
  V:=1;
  If Arg<>'' Then If Not MonEval(Arg,V) Then V:=1;
  ExecRun(EX_COUNT,V,'',False,-1,0);
 End Else If Cmd='S' Then ExecTrace
 Else If Cmd='G' Then Begin
  If Arg<>'' Then Begin
   If MonEval(Arg,V) Then PC:=V Else Begin
     MonAlert(T3('Bad expression','Expression incorrecte',
     'Falscher Ausdruck'));Exit;End;
  End;
  ExecRun(EX_GO,0,'',False,-1,0);
 End Else If Cmd='B' Then Begin
  If BpParse(Arg,False) Then BpParse(Arg,True) Else
    MonAlert(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else If Cmd='D' Then Begin
  If MonEval(Arg,V) Then SetWinAddr(2,V) Else
    MonAlert(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else If Cmd='M' Then Begin
  If MonEval(Arg,V) Then SetWinAddr(3,V) Else
    MonAlert(T3('Bad expression','Expression incorrecte','Falscher Ausdruck'));
 End Else
   MonAlert(T3('Unknown command','Commande inconnue','Unbekannter Befehl'));
 ClrErr;
End;

{ Preferences }
Procedure SaveMonInf;
Var F: Text; I: Integer;
Begin
 Assign(F,'MON.INF');
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult<>0 Then Begin
   MonAlert(T3('Cannot write MON.INF','Ecriture de MON.INF impossible',
   'MON.INF kann nicht geschrieben werden'));Exit;End;
 WriteLn(F,'REL=',Ord(PfRel));
 WriteLn(F,'CASE=',Ord(PfIgnCase));
 WriteLn(F,'PREFIX=',Ord(PfAutoPre));
 WriteLn(F,'AUTOSRC=',Ord(PfAutoSrc));
 WriteLn(F,'ZAN=',Ord(PfZAn));
 WriteLn(F,'TIMER=',Ord(PfTimer));
 WriteLn(F,'TRAPEXC=',Ord(PfTrapExc));
 WriteLn(F,'TRAPS=',Ord(PfTraps));
 WriteLn(F,'CART=',Ord(PfCart));
 WriteLn(F,'SYMLEN=',PfSymLen);
 WriteLn(F,'LABEL=',PfLabel);
 WriteLn(F,'LINES=',PfLines);
 WriteLn(F,'SPLL=',SplL);
 WriteLn(F,'SPLR=',SplR);
 WriteLn(F,'COLS=',ColSt);
 WriteLn(F,'REGROWS=',RegRows);
 WriteLn(F,'FONT=',CellH);
 For I:=1 To NWIN Do WriteLn(F,'W',I,'=',MW[I].V[MW[I].Top].Kind);
 Close(F);
End;

Procedure PfDefaults;
Begin
 PfRel:=True;PfIgnCase:=True;PfAutoPre:=True;PfAutoSrc:=True;PfZAn:=False;
 PfTimer:=True;PfTrapExc:=True;PfTraps:=False;PfCart:=False;PfSymLen:=22;PfLabel
   :='';PfLines:=0;
 PfTopRam:=0;
End;

Procedure LoadMonInf;
Var F: Text; L,K,V: String; P,N,Code,I: Integer;
Begin
 Assign(F,'MON.INF');
 {$I-}
 Reset(F);
 {$I+}
 If IOResult<>0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F,L);
  P:=Pos('=',L);
  If P>0 Then Begin
   K:=Upper(Copy(L,1,P-1));V:=Copy(L,P+1,100);
   Val(V,N,Code);
   If Code<>0 Then N:=0;
   If K='REL' Then PfRel:=N<>0
   Else If K='CASE' Then PfIgnCase:=N<>0
   Else If K='PREFIX' Then PfAutoPre:=N<>0
   Else If K='AUTOSRC' Then PfAutoSrc:=N<>0
   Else If K='ZAN' Then PfZAn:=N<>0
   Else If K='TIMER' Then PfTimer:=N<>0
   Else If K='TRAPEXC' Then PfTrapExc:=N<>0
   Else If K='TRAPS' Then PfTraps:=N<>0
   Else If K='CART' Then PfCart:=N<>0
   Else If K='SYMLEN' Then Begin If (N>=8) And (N<=24) Then PfSymLen:=N;End
   Else If K='LABEL' Then PfLabel:=V
   Else If K='LINES' Then PfLines:=N
   Else If K='SPLL' Then Begin If (N>=0) And (N<=3) Then SplL:=N;End
   Else If K='SPLR' Then Begin If (N>=0) And (N<=3) Then SplR:=N;End
   Else If K='COLS' Then Begin If (N>=0) And (N<=4) Then ColSt:=N;End
   Else If K='REGROWS' Then Begin If (N>=3) And (N<=30) Then RegRows:=N;End
   Else If K='FONT' Then Begin If N=8 Then CellH:=8 Else CellH:=10;NRows:=SCR_H
     Div CellH;End
   Else If (Length(K)=2) And (K[1]='W') And (K[2]>='1') And (K[2]<='5') Then
     Begin
    I:=Ord(K[2])-48;
    If AllowedKind(I,N) And (N<>VK_SRC) Then MW[I].V[1].Kind:=N;
   End;
  End;
 End;
 Close(F);
End;

Procedure MCmdPrefs;
Var C: Char; S: String; V: LongInt; Cur: String;
 Function YN(Const Q: String; B: Boolean): Boolean;
 Var Ch: Char; T: String;
 Begin
  If B Then T:='Y' Else T:='N';
  Ch:=MonAskKey(Q+' Y/N? ['+T+']','YN'+#13);
  YN:=B;
  If Ch='Y' Then YN:=True Else If Ch='N' Then YN:=False;
 End;
Begin
 PfTimer:=YN(T3('Screen timer','Temporisation d''ecran','Bildschirm-Timer'),
   PfTimer);
 PfTraps:=YN(T3('Follow traps','Suivre les traps','Traps verfolgen'),PfTraps);
 PfTrapExc:=YN(T3('Mon takes program exceptions',
   'Mon intercepte les exceptions du program'+'me',
   'Mon faengt Programm-Exceptions ab'),PfTrapExc);
 MonTrap:=PfTrapExc;
 PfRel:=YN(T3('Relative offsets','Offsets relatifs','Relative Offsets'),PfRel);
 PfIgnCase:=YN(T3('Ignore case','Ignorer la casse',
   'Gross-/Kleinschreibung ignorieren'),PfIgnCase);
 PfCart:=YN(T3('Ignore cartridge area','Ignorer la cartouche',
   'Modulschacht ignorieren'),PfCart);
 Case PfLines Of 1: Cur:='D'; 2: Cur:='H'; Else Cur:='N'; End;
 C:=MonAskKey(T3('Source line numbers N/D/H? [',
   'Numeros de ligne source N/D/H ? [','Quelltext-Zeilennummern N/D/H? [')+Cur+
   ']','NDH'+#13);
 If C='N' Then PfLines:=0 Else If C='D' Then PfLines:=1 Else If C='H' Then
   PfLines:=2;
 PfAutoSrc:=YN(T3('Auto load source','Chargement auto du source',
   'Quelltext automatisch laden'),PfAutoSrc);
 PfAutoPre:=YN(T3('Auto ''_'' or ''@'' prefix','Prefixe auto ''_'' ou ''@''',
   'Automatisches ''_'' oder ''@'' Praefix'),PfAutoPre);
 S:=PfLabel;
 If MonPrompt(T3('Start at label','Demarrer au label','Start bei Label'),S,
   PV_FREE) Then PfLabel:=TrimS(S);
 S:=IntStr(PfSymLen);
 If MonPrompt(T3('Symbol length (8-22)','Longueur des symboles (8-22)',
   'Symbollaenge (8-22)'),S,PV_EXPR) Then Begin
  If MonEval(S,V) Then Begin
   If V<8 Then V:=8;
   If V>22 Then V:=22;
   PfSymLen:=V;
  End;
 End;
 PfZAn:=YN(T3('Display ZAn in disassembly','Afficher ZAn dans le desassemblage',
   'ZAn im Disassembler anzeigen'),PfZAn);
 C:=MonAskKey(T3('Save preferences Y/N?','Sauver les preferences O/N ?',
   'Einstellungen speichern J/N?'),'YNO');
 If (C='Y') Or (C='O') Then SaveMonInf;
End;

{ ---------------------------------------------------------------------- }
{ Clavier                                                                  }
{ ---------------------------------------------------------------------- }

Function MonAltLetter(K: LongInt): Char;
Var I: Integer;
Begin
 MonAltLetter:=#0;
 If (K<256) Or (K>511) Then Exit;
 For I:=0 To 25 Do
  If AltScan[I]=K-256 Then Begin MonAltLetter:=Chr(65+I);Exit;End;
End;

Procedure MnHandleKey(K: LongInt);
Var Al,C: Char; I: Integer;
Begin
 If EditOn Then Begin EditKey(K);Exit;End;
 MsgText:='';MsgExtra:='';
 Al:=MonAltLetter(K);
 If Al<>#0 Then Begin
  Case Al Of
   'A': MCmdSetAddr;
   'B': MCmdBreak;
   'E': MCmdEdit;
   'F': MCmdFont;
   'G': MCmdGotoLine;
   'L': MCmdLock;
   'O': MCmdBases;
   'P': MCmdPrint;
   'R': MCmdRegSet;
   'S': MCmdSplit;
   'T': MCmdType;
   'W': MCmdWiden;
   'Z': MCmdZoom;
  End;
  Exit;
 End;
 If (K>=376) And (K<=380) Then Begin SelectWin(K-375);Exit;End;
 If K=385 Then Begin MCmdBases;Exit;End;
 Case K Of
  1: MCmdBreakAfter;
  2: MCmdBpHere;
  3: MCmdTerminate;
  4: MCmdBdos;
  5: Begin
      MonTrap:=True;PfTrapExc:=True;
      SetMsg(T3('Exceptions re-installed: Mon takes progr'+
        'am exceptions first','Exceptions reinstallees : Mon intercepte'+
        ' d''abord les exceptions du programme',
        'Exceptions neu installiert: Mon faengt P'+
        'rogramm-Exceptions zuerst ab'));
     End;
  11: MCmdKill;
  12: MCmdLoadProg;
  15: SetMsg(T3('Other screen mode: not available',
    'Autre mode d''ecran : non disponible',
    'Anderer Bildschirmmodus: nicht verfuegba'+'r'));
  16: MCmdPrefs;
  18,K_F9: ExecRun(EX_GO,0,'',False,-1,0);
  19: ExecSkip;
  20,K_F8: ExecTrace;
  23,25,26,K_F7: ExecStep1;
  24: Begin End;
  K_TAB: Begin
          Layout;
          I:=MCur;
          Repeat
           I:=I Mod NWIN+1;
          Until (MW[I].W>0) Or (I=MCur);
          SelectWin(I);
         End;
  K_ESC: Begin
          MZoom:=False;
          UpdateLocks;
         End;
  K_F1: MCmdHelp;
  K_F10: MCmdViewScreen;
  K_UP,K_DOWN,K_LEFT,K_RIGHT,K_PGUP,K_PGDN: CursorKey(K);
  K_CLEFT,256+141: Begin If RegRows>3 Then Dec(RegRows);End;
  K_CRIGHT,256+145: Begin If RegRows<NRows-8 Then Inc(RegRows);End;
  256+152: CursorKey(K_PGUP);
  256+160: CursorKey(K_PGDN);
  32..126: Begin
    C:=UpCase(Chr(K));
    Case C Of
     'A': MCmdLoadAscii;
     'B': MCmdLoadBin;
     'C': MCmdCompare;
     'D': MCmdChDir;
     'E': MCmdExeSyms;
     'G': MCmdSearch;
     'H': MCmdHistory;
     'I': MCmdCopy;
     'L': MCmdListLabels;
     'M': MCmdSetAddr;
     'N': MCmdFindNext;
     'P': MCmdDisFile;
     'Q': MCmdQuery;
     'R': MCmdRunVarious;
     'S': MCmdSaveBin;
     'T': MCmdTransfer;
     'U': MCmdUntil;
     'V': MCmdViewScreen;
     'W': MCmdFill;
     '0': MCmdBases;
     '.': MCmdNextView(1);
     ',': MCmdNextView(-1);
     '>': MCmdOpenView;
     '<': MCmdCloseView;
     ':': MCmdTextLine;
     '?': MCmdHelp;
    End;
   End;
 End;
End;

{ Boucle principale du moniteur }
Procedure RunMonitor(Const Prog: String; Prompt: Boolean);
Var E: TEvent; Dirty: Boolean; S,C: String; I,Cx,Ry: Integer;
    {$IFDEF FPC} OldKM: TKeyMode; {$ENDIF}
Begin
 {$IFDEF FPC}
 OldKM:=KeyMode;KeyMode:=kmFPWINCRT;   { Ctrl-haut/bas, Alt-fleches : codes
   etendus }
 {$ENDIF}
 MonActive:=True;MonQuit:=False;EmuVisible:=False;Dirty:=True;
 DisExt:=True;
 PfDefaults;
 InitWindows;
 LoadMonInf;
 MonTrap:=PfTrapExc;PendVec:=-1;
 NRows:=SCR_H Div CellH;
 LtN:=0;MSfN:=0;
 MonLoaded:=False;ProgDead:=False;NMB:=0;BdosBp:=-1;HCnt:=0;HHead:=0;
 MsgText:='';MsgExtra:='';PendKey:=0;NSrc:=0;
 SrchBuf:='';SrchKind:='B';SrchAlign:=1;SrchCase:=True;
 TabSrc4:=False;
 If Prog<>'' Then DoLoad(Prog,'')
 Else If Prompt Then Begin
  S:='';
  DrawMonitor;
  If MonPrompt(T3('Executable file to load','Fichier executable a charger',
    'Zu ladendes Programm'),S,PV_FREE) Then Begin
   S:=TrimS(S);
   If S<>'' Then Begin
    C:='';
    If Not
      MonPrompt(T3('Command line?','Ligne de commande ?','Kommandozeile?'),C,
      PV_FREE) Then C:='';
    DoLoad(S,C);
   End;
  End;
 End;
 If Not MonLoaded Then
   SetMsg(T3('No program loaded: Ctrl-L to load one, C'+'trl-C to quit',
   'Aucun programme charge : Ctrl-L pour en '+'charger un, Ctrl-C pour quitter',
   'Kein Programm geladen: Ctrl-L zum Laden,'+' Ctrl-C zum Beenden'));
 While Not MonQuit Do Begin
  If Dirty Then Begin
   Box(0,0,SCR_W-1,SCR_H-1,PAPER);
   DrawMonitor;Dirty:=False;
  End;
  PollEvent(E);
  If (E.Kind=1) Or (E.Kind=2) Then Dirty:=True;
  If E.Kind=2 Then Begin
   { un clic selectionne la fenetre sous le curseur }
   Layout;
   Cx:=E.X Div MCW;Ry:=E.Y Div CellH;
   For I:=1 To NWIN Do
    With MW[I] Do
     If (W>0) And (Cx>=X) And (Cx<X+W) And (Ry>=Y) And (Ry<Y+H) Then Begin
       MCur:=I;EditOn:=False;End;
  End;
  If E.Kind=1 Then Begin
   MnHandleKey(E.Key);
   While (PendKey<>0) And Not MonQuit Do Begin
    I:=PendKey;PendKey:=0;
    MnHandleKey(I);
   End;
   KQHead:=0;KQTail:=0;
  End;
 End;
 For I:=1 To NSrc Do FreeLines(MSrc[I].Arr,MSrc[I].Cnt);
 NSrc:=0;
 MonActive:=False;EmuVisible:=False;
 MonTrap:=False;PendVec:=-1;
 DisExt:=False;
 {$IFDEF FPC}
 KeyMode:=OldKM;
 {$ENDIF}
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
 StartAction: Char;            { ' ', 'A', 'X', 'D', 'M', 'E' }
 EmulPrg    : String;          { /EMUL:prg : programme a executer dans l'emulateur }
 EmulTail   : String;          { ligne de commande transmise au programme }
 EmulScr    : String;          { /SCR:fichier : copie de l'ecran logique a la fin }
 EmulDump   : String;          { /DUMP:adresse:longueur:fichier }
 EmulTime   : LongInt;          { /TIME:secondes : duree maximale (0 = illimitee) }
 EmulShow   : Boolean;          { /SHOW : avec /EMUL, affiche le programme dans la fenetre graphique }
 EmulT0     : LongInt;
 PreDefs    : Array[1..10] Of String[80];
 NPre       : Integer;
 LastAsmOk  : Boolean;

Procedure IdleTick;
Begin
 Inc(TickCount);
 If Not IdleOK Then Exit;
 If PrefFlash<=2 Then Begin
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
 If ScrollOnly Then ScrollOnly:=False Else EnsureVisible;
 DrawEditor;
 DrawMenuBar;
 DrawDropDown;
 CursorOn:=True;
 If MenuOpen=0 Then DrawCursor(True);
 ShowMouseU;
 NeedDraw:=False;
End;

{ Une commande est-elle utilisable (sinon element grise dans les menus) ? }
Function CmdEnabled(Id: Integer): Boolean;
Begin
 CmdEnabled:=True;
 Case Id Of
  CM_CUT,CM_COPY,CM_BDEL,CM_BREM,CM_BSAVE,CM_BCOPY: CmdEnabled:=BlockOk;
  CM_PASTE,CM_BPASTE: CmdEnabled:=ClipN>0;
  CM_FNEXT,CM_FPREV,CM_REPLALL: CmdEnabled:=FindStr<>'';
  CM_PREVERR,CM_JUMPERR,CM_NEXTERR: CmdEnabled:=AsmErrors>0;
  CM_REVERT: CmdEnabled:=(EdFile<>'') And FileExists(EdFile);
  CM_CYCLE: CmdEnabled:=ENWin>1;
 End;
End;

Function SubEnabled(Id,J: Integer): Boolean;
Begin
 SubEnabled:=True;
 If (Id=CM_GOTOBM) And (J>=1) And (J<=8) Then SubEnabled:=BkOn[J];
 If (Id=CM_WINDOW) And (J>=1) And (J<=EMAXWIN) Then SubEnabled:=EWins[J].Used;
End;

Function WinUsedN(J: Integer): Boolean;
Begin
 WinUsedN:=(J>=1) And (J<=EMAXWIN) And EWins[J].Used;
End;

Function WinTitleN(J: Integer): String;
Var N: String;
Begin
 If Not WinUsedN(J) Then Begin
   WinTitleN:=T3('(empty)','(vide)','(leer)');Exit;End;
 If J=EActW Then N:=EdFile Else N:=EWins[J].Fil;
 If N='' Then N:=T3('Untitled','Sans titre','Ohne Titel') Else N:=ShortName(N);
 WinTitleN:=N;
End;

Function WinIsFront(J: Integer): Boolean;
Begin
 WinIsFront:=J=EActW;
End;

Function LayoutIsKept(J: Integer): Boolean;
Begin
 LayoutIsKept:=(J=ELayoutKeep) Or ((J=5) And (ELayoutKeep>0));
End;

Function MEnabled(M,I: Integer): Boolean;
Begin
 MEnabled:=CmdEnabled(MItem(M,I));
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

Function PrepWindow: Boolean; Forward;

{ Affiche l'erreur K dans la ligne d'etat (le curseur va sur la ligne fautive ;
  on passe dans la fenetre qui contient le fichier) }
Procedure ShowError(K: Integer);
Var W,J: Integer; Nm: String;
Begin
 ErrCur:=K;
 W:=ErrWin[K];
 If (W=0) And (ErrNm[K]<>'') Then Begin
  { include non ouvert : on l'ouvre dans une fenetre }
  Nm:=ErrNm[K];
  If Not FileExists(Nm) Then Nm:=PathOf(MainFileName)+ErrNm[K];
  If FileExists(Nm) Then
   If PrepWindow Then
    If EdLoadFile(Nm,False) Then Begin
     For J:=1 To MAXERR Do If (ErrWin[J]=0) And (ErrNm[J]=ErrNm[K]) Then
       ErrWin[J]:=EActW;
     W:=EActW;
    End;
 End;
 If W>0 Then Begin
  EWinActivate(W);
  GotoLine(ErrLn[K]);
  StatusErr(ErrTx[K]);
 End Else
  StatusErr(ErrNm[K]+'('+IntStr(ErrLn[K])+'): '+ErrTx[K]);
End;

Function ErrCount: Integer;
Begin
 If AsmErrors>MAXERR Then ErrCount:=MAXERR Else ErrCount:=AsmErrors;
End;

{ Alt-J : erreur suivante (Dir=1) ; Ctrl-J : erreur precedente (Dir=-1) }
Procedure ErrorStep(Dir: Integer);
Var K,N: Integer;
Begin
 N:=ErrCount;
 If N=0 Then Begin
  StatusErr(T3('No errors','Aucune erreur','Keine Fehler'));Exit;
 End;
 If (ErrCur<1) Or (ErrCur>N) Then Begin
  If Dir>0 Then K:=1 Else K:=N;
 End Else Begin
  K:=ErrCur+Dir;
  If K>N Then K:=1;
  If K<1 Then K:=N;
 End;
 ShowError(K);
End;

{ Alt-U : premiere erreur du fichier courant apres le curseur }
Procedure NextErrorAfterCursor;
Var K,N,Best: Integer;
Begin
 N:=ErrCount;
 If N=0 Then Begin
  StatusErr(T3('No errors','Aucune erreur','Keine Fehler'));Exit;
 End;
 Best:=0;
 For K:=1 To N Do
  If ErrWin[K]=EActW Then
   If (ErrLn[K]>CurL) Or ((ErrLn[K]=CurL) And (K<>ErrCur)) Then
    If (Best=0) Or (ErrLn[K]<ErrLn[Best]) Then Best:=K;
 If Best=0 Then
   StatusErr(T3('No more errors','Plus d''erreur','Keine weiteren Fehler'))
 Else ShowError(Best);
End;

Procedure ApplyPreDefs;
Var I,P: Integer; V: LongInt;
Begin
 For I:=1 To NPre Do Begin
  P:=Pos('=',PreDefs[I]);
  If P>0 Then
    DefSym(Copy(PreDefs[I],1,P-1),ToInt(Copy(PreDefs[I],P+1,40)),SEC_ABS,1)
  Else DefSym(PreDefs[I],1,SEC_ABS,1);
 End;
End;

Var AsmWin : Integer;         { fenetre assemblee }

Procedure ApplyAsmCfg; Forward;

{ fenetre de chaque erreur d'assemblage }
Procedure MapErrWins;
Var K: Integer;
Begin
 For K:=1 To MAXERR Do ErrWin[K]:=0;
 For K:=1 To ErrCount Do
  If ErrNm[K]='' Then ErrWin[K]:=AsmWin Else ErrWin[K]:=EWinFindFile(ErrNm[K]);
End;

{ includes lus en memoire depuis les fenetres ouvertes (pas besoin de les
  sauver) }
Function MemInclude(Const Name: String; Var Arr: PLineArr; Var Count: LongInt):
  Boolean;
Var I,K,N: Integer; Full,F2: String; Src: PLineArr;
Begin
 MemInclude:=False;
 Full:=Upper(FExpand(Name));
 For I:=1 To EMAXWIN Do
  If EWins[I].Used And (I<>AsmWin) Then Begin
   If I=EActW Then F2:=EdFile Else F2:=EWins[I].Fil;
   If F2<>'' Then
    If Upper(FExpand(F2))=Full Then Begin
     If I=EActW Then Begin Src:=Ed;N:=EdN;End Else Begin
       Src:=EWins[I].PEd;N:=EWins[I].N;End;
     New(Arr);
     For K:=1 To N Do Arr^[K]:=NewStr(Src^[K]^);
     Count:=N;
     MemInclude:=True;
     Exit;
    End;
  End;
End;

{ Assemble le tampon de l'editeur ; affiche le compte rendu }
Function DoAssemble(ShowLog,ForRun: Boolean): Boolean;
Var Ok: Boolean; K: Integer;
Begin
 ErrCur:=0;
 OptOutName:=CfgOutName;OptListName:=CfgListName;
 ApplyAsmCfg;
 AsmFromEditor:=True;
 AsmWin:=EActW;
 HaveOutput:=False;
 If Not ForRun Then Begin End;
 MemFileHook:=TMemFileHook(@MemInclude);
 Ok:=AssembleSource(MainFileName,Ed,EdN);
 MemFileHook:=Nil;
 MapErrWins;
 LastAsmOk:=Ok;
 If ShowLog Or Not Ok Then ShowTextScreen(True);
 NeedDraw:=True;
 If Not Ok Then Begin
  ErrCur:=0;
  If AsmErrors>0 Then ErrorStep(1);
 End;
 DoAssemble:=Ok;
End;

Var SavedDir : String;
    InRunDir : Boolean;
    RunPause : Boolean;      { attendre une touche a la fin du programme }

{ Program > Directory > Top Window : le programme lance voit le repertoire du
  fichier edite comme repertoire courant }
Procedure RunDirEnter;
Var D: String;
Begin
 InRunDir:=False;
 If RunDirMode<>2 Then Exit;
 D:=PathOf(EdFile);
 If D='' Then Exit;
 GetDir(0,SavedDir);
 {$I-}
 ChDir(D);
 {$I+}
 If IOResult=0 Then InRunDir:=True;
End;

Procedure RunDirLeave;
Begin
 If InRunDir Then Begin
  {$I-}
  ChDir(SavedDir);
  {$I+}
  If IOResult<>0 Then Begin End;
 End;
 InRunDir:=False;
End;

{ Execute un programme dans l'emulateur avec affichage graphique }
Procedure RunProgramGUI(Const Name,Cmd: String);
Var Msg,Cur,Nxt: String; I: LongInt; EH,EM,ES,EC: Word;
Begin
 Cur:=Name;
 Repeat
  If Not LoadProgram(Cur,Cmd,OptRunGem) Then Begin
   Alert1(3,T3('Cannot load the program|','Impossible de charger le programme|',
     'Programm nicht ladbar|')+ShortName(Cur));
   Exit;
  End;
  RunDirEnter;
  HideMouse;
  MonActive:=False;EmuVisible:=True;
  ConClear;
  BlitScreen(True);
  UserBreak:=False;
  ShelNext:='';
  If Emu_GEM Then GemBoot;
  EmulT0:=0;
  While ((StopReason=STOP_NONE) Or (StopReason=STOP_YIELD)) And Not UserBreak
    Do Begin
   RunCpu(30000);
   If StopReason=STOP_YIELD Then GemDispatch;
   PollInput;
   BlitScreen(False);
   If (StartAction='E') And (EmulTime>0) Then Begin
    GetTime(EH,EM,ES,EC);
    If EmulT0=0 Then EmulT0:=LongInt(EH)*3600+EM*60+ES;
    If LongInt(EH)*3600+EM*60+ES-EmulT0>=EmulTime Then UserBreak:=True;
   End;
  End;
  If UserBreak Then Begin StopReason:=STOP_USER;StopMsg:='^C';End;
  RunDirLeave;
  Nxt:=ShelNext;
  If (Nxt<>'') And (StopReason=STOP_EXIT) Then Begin
   CloseAllFiles;
   Cur:=Nxt;
  End Else Nxt:='';
 Until Nxt='';
 Case StopReason Of
  STOP_EXIT:
    Msg:=T3('Program terminated, exit code ','Programme termine, code ',
    'Programm beendet, Code ')+IntStr(ExitCode);
  STOP_FAULT: Msg:=StopMsg;
  STOP_USER: Msg:=T3('Interrupted (^C)','Interrompu (^C)','Unterbrochen (^C)');
  STOP_STOP: Msg:='STOP';
 Else Msg:='';
 End;
 If UnknownCall<>'' Then Msg:=Msg+' ['+UnknownCall+']';
 If (Msg<>'') And (RunPause Or (StopReason<>STOP_EXIT)) Then Begin
  MouseHidden:=0;
  BText(0,384,PadR(' '+Msg+' - '+T3('press a key','appuyez sur une touche',
    'Taste druecken'),80),True);
  BlitScreen(False);
 End;
 KQHead:=0;KQTail:=0;UserBreak:=False;
 MouseHidden:=0;
 SetMouseShape(0);
 ShowMouse;
 If RunPause Or (StopReason<>STOP_EXIT) Then WaitAnyKey;
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

{ ---------------------------------------------------------------------- }
{ Fichiers                                                                 }
{ ---------------------------------------------------------------------- }

Procedure CmdSaveAs;
Var P: String;
Begin
 P:=EdFile;
 If FileSelect(T3('Save file as','Sauver le fichier sous','Datei sichern als'),
   '*.S',P) Then Begin
  If FileExists(P) And (P<>EdFile) Then
   If AlertBox(2,T3('File exists|Overwrite it ?',
     'Le fichier existe|Le remplacer ?','Datei existiert|Ueberschreiben ?'),
        T3('Cancel|Overwrite','Annuler|Remplacer','Abbruch|Ueberschr.'),1)<>2
          Then Begin NeedDraw:=True;Exit;End;
  EdSaveFile(P);
 End;
 NeedDraw:=True;
End;

Procedure CmdSave;
Begin
 If EdFile='' Then CmdSaveAs Else EdSaveFile(EdFile);
 NeedDraw:=True;
End;

{ Le texte a-t-il ete modifie ? Propose Save / Leave / Cancel ; False = abandon
  de la commande }
Function ConfirmChanges: Boolean;
Var R: Integer; N: String;
Begin
 ConfirmChanges:=True;
 If Not EdMod Then Exit;
 If EdFile<>'' Then N:=ShortName(EdFile) Else
   N:=T3('(untitled)','(sans titre)','(ohne Titel)');
 R:=AlertBox(2,N+'|'+T3('has been modified','a ete modifie','wurde geaendert'),
  T3('Save|Leave|Cancel','Sauver|Laisser|Annuler','Sichern|Verwerfen|Abbruch'),
    1);
 If R=1 Then Begin
  CmdSave;
  ConfirmChanges:=Not EdMod;
 End Else ConfirmChanges:=R=2;
End;

{ La fenetre active est-elle inutilisee (vide, sans titre, non modifiee) ? }
Function WinIsBlank: Boolean;
Begin
 WinIsBlank:=(EdFile='') And (Not EdMod) And (EdN=1) And (Length(Ed^[1]^)=0);
End;

{ Fournit une fenetre vide (la fenetre active si elle est inutilisee, sinon une
  nouvelle) ; avertit s'il n'y a plus de fenetre disponible }
Function PrepWindow: Boolean;
Begin
 PrepWindow:=True;
 If WinIsBlank Then Exit;
 If Not EWinAlloc Then Begin
  Alert1(1,T3('No more windows are available|Close one '+'first',
    'Plus de fenetre disponible|Fermez-en une',
    'Keine Fenster mehr frei|Erst eines schli'+'essen'));
  PrepWindow:=False;
 End;
End;

Procedure CmdNew;
Begin
 If Not EWinAlloc Then
  Alert1(1,T3('No more windows are available|Close one '+'first',
    'Plus de fenetre disponible|Fermez-en une',
    'Keine Fenster mehr frei|Erst eines schli'+'essen'));
 NeedDraw:=True;
End;

{ numero de la fenetre qui contient exactement le fichier P (chemins complets),
  0 sinon }
Function WinOfPath(Const P: String): Integer;
Var I: Integer; F2: String;
Begin
 WinOfPath:=0;
 For I:=1 To EMAXWIN Do
  If EWins[I].Used Then Begin
   If I=EActW Then F2:=EdFile Else F2:=EWins[I].Fil;
   If (F2<>'') And (Upper(FExpand(F2))=Upper(FExpand(P))) Then WinOfPath:=I;
  End;
End;

{ Charge P dans une fenetre ; si le fichier n'existe pas, propose de le creer }
Procedure LoadNamed(Const P: String);
Var F: File; R,W: Integer;
Begin
 W:=WinOfPath(P);
 If W>0 Then Begin EWinActivate(W);Exit;End;
 If FileExists(P) Then Begin
  If PrepWindow Then EdLoadFile(P,False);
  Exit;
 End;
 R:=AlertBox(2,T3('File not found|','Fichier introuvable|',
   'Datei nicht gefunden|')+ShortName(P)+'|'+
   T3('Create it ?','Le creer ?','Anlegen ?'),T3('Cancel|Create',
     'Annuler|Creer','Abbruch|Anlegen'),2);
 If R=2 Then Begin
  Assign(F,P);
  {$I-}
  Rewrite(F,1);
  {$I+}
  If IOResult=0 Then Begin
   Close(F);
   If PrepWindow Then Begin EdClear;EdFile:=P;EdMod:=False;End;
  End Else
    Alert1(3,T3('Cannot write file|','Impossible d''ecrire le fichier|',
    'Datei nicht schreibbar|')+ShortName(P));
 End;
End;

Procedure CmdLoad;
Var P: String;
Begin
 P:='';
 If FileSelect(T3('Load file','Charger un fichier','Datei laden'),'*.S',P) Then
   LoadNamed(P);
 NeedDraw:=True;
End;

Procedure CmdInsert;
Var P: String;
Begin
 P:='';
 If FileSelect(T3('Insert file','Inserer un fichier','Datei einfuegen'),'*.S',
   P) Then
  EdLoadFile(P,True);
 NeedDraw:=True;
End;

Procedure CmdRevert;
Var R: Integer;
Begin
 If (EdFile='') Or Not FileExists(EdFile) Then Exit;
 R:=AlertBox(3,T3('Revert will lose the changes|made to ',
   'Revert perdra les modifications|faites a'+' ',
   'Zuruecksetzen verwirft die Aenderungen|a'+'n ')+ShortName(EdFile),
   T3('Cancel|Revert','Annuler|Recharger','Abbruch|Zurueck'),1);
 If R=2 Then EdLoadFile(EdFile,False);
 NeedDraw:=True;
End;

Procedure CmdClose;
Begin
 If Not ConfirmChanges Then Exit;
 EWinClose(EActW);
 NeedDraw:=True;
End;

Procedure CmdDeleteFile;
Var P: String; F: File;
Begin
 P:='';
 If FileSelect(T3('Delete file','Effacer un fichier','Datei loeschen'),'*.*',P)
   Then Begin
  Assign(F,P);
  {$I-}
  Erase(F);
  {$I+}
  If IOResult<>0 Then
   Alert1(3,T3('Cannot delete file|','Impossible d''effacer le fichier|',
     'Datei nicht loeschbar|')+ShortName(P));
 End;
 NeedDraw:=True;
End;

Procedure CmdChDir;
Var P: String;
Begin
 P:='';
 FSDirMode:=True;
 If FileSelect(T3('Change directory','Changer de repertoire',
   'Verzeichnis wechseln'),'*.',P) Then Begin
  If (Length(P)>1) And (P[Length(P)]=DirSep) And (P[Length(P)-1]<>':') Then
    Dec(P[0]);
  {$I-}
  ChDir(P);
  {$I+}
  If IOResult<>0 Then
    Alert1(3,T3('Cannot change directory|',
    'Changement de repertoire impossible|',
    'Verzeichniswechsel nicht moeglich|')+P);
 End;
 FSDirMode:=False;
 NeedDraw:=True;
End;

Procedure CmdSaveBlock;
Var P: String;
Begin
 If Not BlockCheck Then Exit;
 P:='';
 If FileSelect(T3('Save block as','Sauver le bloc sous','Block sichern als'),
   '*.S',P) Then
  If Not SaveBlockFile(P) Then
   Alert1(3,T3('Cannot write file|','Impossible d''ecrire le fichier|',
     'Datei nicht schreibbar|')+ShortName(P));
 NeedDraw:=True;
End;

{ nombre de fenetres modifiees }
Function ModifiedCount: Integer;
Var I,N: Integer;
Begin
 N:=0;
 For I:=1 To EMAXWIN Do
  If EWins[I].Used Then Begin
   If I=EActW Then Begin If EdMod Then Inc(N);End
   Else If EWins[I].Modf Then Inc(N);
  End;
 ModifiedCount:=N;
End;

{ Sauve la fenetre I (elle devient la fenetre active) ; True si sauvee }
Function SaveWin(I: Integer): Boolean;
Begin
 EWinActivate(I);
 If EdFile='' Then CmdSaveAs Else EdSaveFile(EdFile);
 SaveWin:=Not EdMod;
End;

{ Dialogue de sortie : fichiers modifies, bouton Leave par fichier, case
  Backups,
  Save All / As Above / Leave All / Cancel (manuel p.32) ; True = on peut
    continuer }
Function SaveFilesDialog: Boolean;
Var R,I,J,NL: Integer; Ids: Array[1..EMAXWIN] Of Integer; Chk:
  Array[1..EMAXWIN] Of Integer;
    cBak: Integer; N: String;
Begin
 SaveFilesDialog:=False;
 NL:=0;
 For I:=1 To EMAXWIN Do
  If EWins[I].Used Then
   If ((I=EActW) And EdMod) Or ((I<>EActW) And EWins[I].Modf) Then Begin
     Inc(NL);Ids[NL]:=I;End;
 If NL=0 Then Begin SaveFilesDialog:=True;Exit;End;
 DlgReset(62,NL+7);
 DlgLabel(1,0,T3('These files have been changed:','Fichiers modifies :',
   'Geaenderte Dateien:'));
 For J:=1 To NL Do Begin
  Chk[J]:=DlgCheck(1,1+J,'Leave',False);
  If Ids[J]=EActW Then N:=EdFile Else N:=EWins[Ids[J]].Fil;
  If N='' Then N:=T3('(untitled)','(sans titre)','(ohne Titel)');
  If Length(N)>48 Then N:=Copy(N,Length(N)-47,48);
  DlgLabel(11,1+J,N);
 End;
 cBak:=DlgCheck(1,NL+3,'Backups',PrefBackup=1);
 DlgButton(1,NL+5,12,T3('Save All','Tout sauver','Alle sichern'),1,True);
 DlgButton(15,NL+5,12,T3('As Above','Comme ci-dessus','Wie oben'),2,False);
 DlgButton(29,NL+5,12,T3('Leave All','Tout laisser','Alle lassen'),3,False);
 DlgButton(43,NL+5,12,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R=0 Then Exit;
 PrefBackup:=DI[cBak].Sel;
 For J:=1 To NL Do
  If (R=1) Or ((R=2) And (DI[Chk[J]].Sel=0)) Then
   If Not SaveWin(Ids[J]) Then Exit;
 SaveFilesDialog:=True;
End;

{ sauve sans question toutes les fenetres modifiees (False si echec / abandon) }
Function SaveAllWin: Boolean;
Var I: Integer;
Begin
 SaveAllWin:=True;
 For I:=1 To EMAXWIN Do
  If EWins[I].Used Then
   If ((I=EActW) And EdMod) Or ((I<>EActW) And EWins[I].Modf) Then
    If Not SaveWin(I) Then Begin SaveAllWin:=False;Exit;End;
End;

Procedure CmdQuit;
Begin
 If ModifiedCount>0 Then Begin
  If PrefSaveQuit=1 Then Begin
   If Not SaveAllWin Then Exit;
  End Else If PrefSaveQuit=3 Then Begin
   If Not SaveFilesDialog Then Begin NeedDraw:=True;Exit;End;
  End;
 End;
 If PrefAutoSave=1 Then SavePrefs;
 Quit:=True;
End;

{ Table ASCII (Edit, Alt-C ou Maj-Ins) : un clic insere le caractere au curseur
  }
Procedure CmdAscii;
Var Ch: Integer;
Begin
 If AsciiPick(Ch) Then InsertChar(Chr(Ch));
 NeedDraw:=True;
End;

Procedure CmdLoadPrefs;
Begin
 If (FindCfg(CFG_NAME)='') And (FindCfg(CFG_OLD)='') Then
  StatusErr(T3('Cannot find ','Introuvable : ','Nicht gefunden: ')+CFG_NAME)
 Else Begin LoadPrefs;EnsureVisible;End;
End;

{ ---------------------------------------------------------------------- }
{ Programme                                                                 }
{ ---------------------------------------------------------------------- }

Procedure CmdAssemble;
Begin
 DoAssemble(True,False);
 CleanTemp;
End;

{ Check (Alt-Y) : comme Assemble, mais sans produire de sortie }
Procedure CmdCheck;
Begin
 OptCheckOnly:=True;
 DoAssemble(True,False);
 OptCheckOnly:=False;
 CleanTemp;
End;

{ Program > Output Symbols : produit le fichier .GS (symboles pre-assembles) du
  fichier edite }
Procedure CmdOutputSymbols;
Var Dst: String; Ok: Boolean;
Begin
 If EdFile='' Then Begin
  StatusErr(T3('Save the file first','Sauvez d''abord le fichier',
    'Erst die Datei sichern'));Exit;
 End;
 If EdMod Then If Not ConfirmChanges Then Exit;
 If EdMod Then Exit;
 Dst:=ChangeExt(EdFile,'GS');
 If Not
   FileSelect(T3('Output symbols to','Sortie des symboles vers',
   'Symbole ausgeben nach'),'*.GS',Dst) Then Begin NeedDraw:=True;Exit;End;
 If Pos('.',ShortName(Dst))=0 Then Dst:=Dst+'.GS';
 ErrCur:=0;
 ApplyAsmCfg;
 AsmWin:=EActW;
 MemFileHook:=TMemFileHook(@MemInclude);
 Ok:=AsmOutputSymbols(EdFile,Dst);
 MemFileHook:=Nil;
 MapErrWins;
 NeedDraw:=True;
 If Ok Then
   StatusMsg:=T3('Symbols written to ','Symboles ecrits dans ',
   'Symbole geschrieben nach ')+ShortName(Dst)
 Else Begin
  ShowTextScreen(True);
  If AsmErrors>0 Then Begin
   ErrorStep(1);
  End;
 End;
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

{ %. = nom complet du fichier edite ; %? = ce nom sans extension ; %% = un % }
Function ExpandCmdLine(Const S: String): String;
Var R,N: String; I,K: Integer;
Begin
 R:='';I:=1;
 While I<=Length(S) Do Begin
  If (S[I]='%') And (I<Length(S)) And (S[I+1]='.') Then Begin
    R:=R+EdFile;Inc(I,2);End
  Else If (S[I]='%') And (I<Length(S)) And (S[I+1]='?') Then Begin
   N:=EdFile;K:=Length(N);
   While (K>0) And (N[K]<>'.') And (N[K]<>'\') And (N[K]<>'/') Do Dec(K);
   If (K>0) And (N[K]='.') Then N:=Copy(N,1,K-1);
   R:=R+N;Inc(I,2);
  End
  Else If (S[I]='%') And (I<Length(S)) And (S[I+1]='%') Then Begin
    R:=R+'%';Inc(I,2);End
  Else Begin R:=R+S[I];Inc(I);End;
 End;
 ExpandCmdLine:=R;
End;

{ "Save files on Run Other" : False = commande abandonnee }
Function SaveBeforeRun: Boolean;
Begin
 SaveBeforeRun:=True;
 If ModifiedCount=0 Then Exit;
 If PrefSaveRun=1 Then SaveBeforeRun:=SaveAllWin
 Else If PrefSaveRun=3 Then SaveBeforeRun:=SaveFilesDialog;
End;

Procedure CmdRunOther;
Var R: Integer; S: String;
Begin
 If Not SaveBeforeRun Then Exit;
 DlgReset(60,6);
 DlgLabel(1,0,T3('Run other program','Executer un autre programme',
   'Anderes Programm starten'));
 DlgLabel(1,1,T3('Program     :','Programme    :','Programm     :'));
 DlgEditX(15,1,40,60,RunOther);
 DlgLabel(1,2,T3('Command line:','Ligne de cmd. :','Kommandozeile:'));
 DlgEditX(15,2,40,60,RunOtherArg);
 DlgButton(2,4,10,'OK',1,True);
 DlgButton(14,4,14,T3('Select...','Choisir...','Waehlen...'),2,False);
 DlgButton(30,4,12,T3('Cancel','Annuler','Abbruch'),0,False);
 R:=DlgRun;
 If R=2 Then Begin
  S:=RunOther;
  If FileSelect(T3('Program to run','Programme a executer','Programm'),'*.*',S)
    Then Begin
   RunOther:=S;
   RunProgramGUI(RunOther,ExpandCmdLine(RunOtherArg));
  End;
  Exit;
 End;
 If R=1 Then Begin
  RunOther:=DI[3].Val;RunOtherArg:=DI[5].Val;
  If RunOther<>'' Then RunProgramGUI(RunOther,ExpandCmdLine(RunOtherArg));
 End;
End;

Procedure CmdAbout;
Var R: Integer;
Begin
 DlgReset(52,14);
 DlgAdd(DK_BOXED,8,1,32,'  '+AsmName+' 68000 Editor/Assembler');
 DlgLabel(11,3,T3('DEV-COOLS clone, 2026','Clone DEV-COOLS, 2026',
   'DEV-COOLS-Klon, 2026'));
 DlgLabel(2,5,T3('Inspired by HiSoft Devpac v','Inspire de HiSoft Devpac v',
   'Nach HiSoft Devpac v')+VERSION_TEXT);
 DlgLabel(2,6,T3('Author: Sylvain Maltais','Auteur : Sylvain Maltais',
   'Autor: Sylvain Maltais'));
 DlgLabel(2,7,'www.gladir.com/dev-cools');
 DlgLabel(2,8,T3('Free text memory: ','Memoire texte libre : ',
   'Freier Textspeicher: ')+IntStr(MemFree)+T3(', used: ',', utilise : ',
   ', benutzt: ')+IntStr(EdMem));
 If AmigaMode Then
   DlgAdd(DK_BOXED,7,9,28,T3(' Mode: Commodore Amiga',' Mode : Commodore Amiga',
   ' Modus: Commodore Amiga'))
 Else
   DlgAdd(DK_BOXED,7,9,28,T3(' Mode: Atari ST',' Mode : Atari ST',
   ' Modus: Atari ST'));
 DlgButton(22,11,8,'OK',1,True);
 R:=DlgRun;
End;

{ Help (Alt-H) : touches des commandes que les menus n'indiquent pas }
Procedure CmdHelp;
Var R: Integer;
Begin
 DlgReset(74,16);
 DlgLabel(1,0,T3('Keys','Touches','Tasten'));
 DlgLabel(1,2,T3('F1 Block start  F2 Block end  F3 Save block  F4 Copy block',
  'F1 Debut bloc  F2 Fin bloc  F3 Sauver bloc  F4 Copier bloc',
  'F1 Blockanfang  F2 Blockende  F3 Block sichern  F4 Block kopieren'));
 DlgLabel(1,3,T3('F5 Paste  Shift-F4 Remember  Shift-F5 De'+
   'lete block  Alt-W Print',
  'F5 Coller  Maj-F4 Memoriser  Maj-F5 Effacer bloc  Alt-W Imprimer',
  'F5 Einfuegen  Sh-F4 Merken  Sh-F5 Block loeschen  Alt-W Drucken'));
 DlgLabel(1,4,T3('^A ^F word  ^Y delete line  ^@ delete to EOL  ^U undelete',
  '^A ^F mot  ^Y effacer ligne  ^@ effacer fin de ligne  ^U annuler',
  '^A ^F Wort  ^Y Zeile loeschen  ^@ Zeilenrest loeschen  ^U zurueck'));
 DlgLabel(1,5,T3('^S ^D ^E ^X cursor  ^R ^C page  Ctrl-lef'+
   't/right line start/end',
  '^S ^D ^E ^X curseur  ^R ^C page  Ctrl-gauche/droite debut/fin',
  '^S ^D ^E ^X Cursor  ^R ^C Seite  Strg-links/rechts Anfang/Ende'));
 DlgLabel(1,6,T3('Shift-left/right word  Shift-up/down pag'+
   'e  Shift-Ins ASCII table',
  'Maj-gauche/droite mot  Maj-haut/bas page  Maj-Ins table ASCII',
  'Sh-links/rechts Wort  Sh-hoch/runter Seite  Sh-Einfg ASCII-Tabelle'));
 DlgLabel(1,7,T3('Alt-A Assemble  Y Check  X Run  D Debug '+
   ' M Mon  K GEM  J Error',
  'Alt-A Assembler  Y Verifier  X Executer  D Deboguer  M Mon  J Erreur',
  'Alt-A Assembl.  Y Pruefen  X Starten  D Debug  M Mon  J Fehler'));
 DlgLabel(1,8,T3('Shift-Alt-J / Alt-U next error here  ^J previous error',
  'Maj-Alt-J / Alt-U erreur suivante ici  ^J erreur precedente',
  'Sh-Alt-J / Alt-U naechster Fehler hier  ^J voriger Fehler'));
 DlgLabel(1,9,T3('Alt-F Find  N Next  P Previous  R Replac'+
   'e  G Goto  T Top  B Bottom',
  'Alt-F Chercher  N Suivant  P Precedent  R Remplacer  G Aller  T Haut',
  'Alt-F Suchen  N Weiter  P Zurueck  R Ersetzen  G Gehe zu  T Anfang'));
 DlgLabel(1,10,T3('Ctrl-1..8 Goto bookmark  Ctrl-Shift-1..8 Set bookmark',
  'Ctrl-1..8 Aller au signet  Ctrl-Maj-1..8 Poser un signet',
  'Strg-1..8 Gehe zu Lesezeichen  Strg-Sh-1..8 Lesezeichen setzen'));
 DlgLabel(1,11,T3('Alt-L Load  S Save As (Shift: Save)  I I'+
   'nsert  Q Quit  H Help',
  'Alt-L Charger  S Sauver sous (Maj : Sauver)  I Inserer  Q Quitter',
  'Alt-L Laden  S Sichern als (Sh: Sichern)  I Einfuegen  Q Ende'));
 DlgLabel(1,12,T3('Alt-1..7 Window  Ctrl-V Cycle  Ctrl-W Close  Ctrl-G Fonts',
  'Alt-1..7 Fenetre  Ctrl-V Suivante  Ctrl-W Fermer  Ctrl-G Polices',
  'Alt-1..7 Fenster  Strg-V Naechstes  Strg-W Schliessen  Strg-G Schrift'));
 DlgLabel(1,13,T3('Alt-0 Other  Sh-Alt-0 Shell  Alt+keypad:'+
   ' tools (Ctrl-Alt: set up)',
  'Alt-0 Autre  Maj-Alt-0 Shell  Alt+pave : outils (Ctrl-Alt : regler)',
  'Alt-0 Anderes  Sh-Alt-0 Shell  Alt+Ziffernblock: Werkzeuge'));
 DlgLabel(1,14,T3('Free memory: ','Memoire libre : ','Freier Speicher: ')+
   IntStr(MemFree)+T3(' bytes, windows: ',' octets, fenetres : ',
   ' Bytes, Fenster: ')+IntStr(ENWin));
 DlgButton(63,14,8,'OK',1,True);
 R:=DlgRun;
End;

Procedure CmdMemory;
Begin
 Alert1(3-2,T3('Text buffer: ','Tampon texte : ','Textpuffer: ')+
   IntStr(PrefBuf)+T3(' bytes',' octets',' Bytes')+'|'+
   T3('Used       : ','Utilise      : ','Benutzt    : ')+IntStr(EdMem)+'|'+
   T3('Free       : ','Libre        : ','Frei       : ')+IntStr(MemFree)+'|'+
   T3('Lines      : ','Lignes       : ','Zeilen     : ')+IntStr(EdN)+'|'+
   T3('Emulated RAM: ','RAM emulee   : ','Emul. RAM : ')+IntStr(MemSize Div
     1024)+' KB');
End;

Procedure RunOptionsDlg;
Var R: Integer;
Begin
 DlgReset(46,9);
 DlgLabel(2,0,T3('Run / debug options','Options d''execution / debogage',
   'Start- / Debug-Optionen'));
 DlgLabel(2,2,T3('GEM        :','GEM         :','GEM         :'));
 DlgRadio(16,2,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptRunGem));
 DlgLabel(2,3,T3('Accessories:','Accessoires :','Accessories :'));
 DlgRadio(16,3,T3('Yes|No','Oui|Non','Ja|Nein'),2-Ord(OptAccs));
 DlgLabel(2,4,'           '+T3('(*.ACC from the program folder)',
   '(*.ACC du dossier du programme)','(*.ACC aus dem Programmordner)'));
 DlgButton(2,6,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(14,6,10,T3('Save','Sauver','Sichern'),2,False);
 DlgButton(26,6,10,'OK',1,True);
 R:=DlgRun;
 If R=0 Then Exit;
 OptRunGem:=DI[3].Sel=1;
 OptAccs:=DI[5].Sel=1;
 If R=2 Then SavePrefs;
End;

{ ---------------------------------------------------------------------- }
{ Dispatcheur de commandes (menus, touches, sous-menus)                     }
{ ---------------------------------------------------------------------- }

{ ---------------------------------------------------------------------- }
{ Menu Tools : jusqu'a 20 outils configurables (manuel p.37-44)            }
{ ---------------------------------------------------------------------- }

Const
 NTOOLS = 20;

Type
 TTool = Record
  Name     : String[20];
  Mode     : Integer;          { ligne de commande : 1 None, 2 Prompt, 3 As
    shown }
  Dir      : Integer;          { repertoire : 1 Tool's, 2 Top window, 3 Current
    }
  Save     : Integer;          { sauver les fichiers : 1 No, 2 Yes, 3 Ask }
  Cmd,Path : String[78];
  Pause,ReportAll,AsGem,Resident : Boolean;
 End;

Var
 Tools    : Array[1..NTOOLS] Of TTool;
 ResAsm,ResDbg : Boolean;       { Resident Tools (memorises, sans effet dans le
   clone) }
 ShellCmd : String;
 LastErrCode : LongInt;

Function ToolKeyName(N: Integer): String;
Begin
 Case N Of
  1..9: ToolKeyName:='Alt-KP'+IntStr(N);
  10: ToolKeyName:='Alt-KP.';
  11: ToolKeyName:='Alt-KP/';
  12: ToolKeyName:='Alt-KP*';
  13: ToolKeyName:='Alt-KP-';
  14: ToolKeyName:='Alt-KP+';
 Else ToolKeyName:='';
 End;
End;

Function ToolMenuLabel(N: Integer): String;
Var S: String;
Begin
 If (N<1) Or (N>NTOOLS) Then Begin ToolMenuLabel:='';Exit;End;
 If Tools[N].Name<>'' Then S:=Tools[N].Name Else
   S:=T3('Tool ','Outil ','Werkzeug ')+IntStr(N);
 If ToolKeyName(N)<>'' Then S:=S+'|'+ToolKeyName(N);
 ToolMenuLabel:=S;
End;

Procedure ToolsDefaults;
Var I: Integer;
Begin
 For I:=1 To NTOOLS Do Begin
  Tools[I].Name:='';Tools[I].Mode:=3;Tools[I].Dir:=1;Tools[I].Save:=2;
  Tools[I].Cmd:='';Tools[I].Path:='';
  Tools[I].Pause:=True;Tools[I].ReportAll:=False;Tools[I].AsGem:=False;Tools[I].
    Resident:=False;
 End;
 ResAsm:=True;ResDbg:=True;
End;

{ Dialogue de configuration d'un outil (Ctrl + clic ou Ctrl-Alt + touche du
  pave) }
Procedure ConfigTool(N: Integer);
Var R,eNum,eName,cRes,pMode,pDir,pSave,ePath,eCmd,cPause,cRep,rRun,N2: Integer;
  T: TTool; P: String;
Begin
 If (N<1) Or (N>NTOOLS) Then Exit;
 T:=Tools[N];
 Repeat
  DlgReset(70,12);
  DlgLabel(1,0,T3('Tool number:','Outil numero :','Werkzeug Nr.:'));
  eNum:=DlgEdit(15,0,2,IntStr(N));DI[eNum].Flt:=1;
  DlgLabel(20,0,T3('Menu entry:','Entree menu :','Menueeintrag:'));
  eName:=DlgEdit(32,0,20,T.Name);
  cRes:=DlgCheck(54,0,T3('Make resident','Rendre residant','Resident'),
    T.Resident);
  DlgLabel(1,2,T3('Command line','Ligne de cmd.','Kommandozeile'));
  pMode:=DlgPopup(1,3,13,T3('None|Prompt|As shown',
    'Aucune|Demander|Telle quelle','Keine|Fragen|Wie gezeigt'),T.Mode);
  DlgLabel(24,2,T3('Directory','Repertoire','Verzeichnis'));
  pDir:=DlgPopup(24,3,13,T3('Tool''s|Top window|Current',
    'Outil|Fenetre haut|Courant','Werkzeug|Oberstes Fenster|Aktuell'),T.Dir);
  DlgLabel(47,2,T3('Save files','Sauver fichiers','Dateien sichern'));
  pSave:=DlgPopup(47,3,13,T3('No|Yes|Ask...','Non|Oui|Demander...',
    'Nein|Ja|Fragen...'),T.Save);
  DlgLabel(1,5,'Path:');
  ePath:=DlgEditX(9,5,50,78,T.Path);
  DlgButton(61,5,7,'FSel',2,False);
  DlgLabel(1,6,T3('Command:','Commande :','Kommando:'));
  eCmd:=DlgEditX(10,6,58,78,T.Cmd);
  cPause:=DlgCheck(1,8,T3('Pause on return','Pause au retour',
    'Pause bei Rueckkehr'),T.Pause);
  cRep:=DlgCheck(24,8,T3('Report all errors','Signaler toutes les erreurs',
    'Alle Fehler melden'),T.ReportAll);
  rRun:=DlgRadio(50,8,'TOS|GEM',1+Ord(T.AsGem));
  DlgButton(2,10,10,T3('Cancel','Annuler','Abbruch'),0,False);
  DlgButton(56,10,10,'OK',1,True);
  R:=DlgRun;
  If R=0 Then Exit;
  T.Name:=DI[eName].Val;T.Resident:=DI[cRes].Sel=1;
  T.Mode:=DI[pMode].Sel;T.Dir:=DI[pDir].Sel;T.Save:=DI[pSave].Sel;
  T.Path:=DI[ePath].Val;T.Cmd:=DI[eCmd].Val;
  T.Pause:=DI[cPause].Sel=1;T.ReportAll:=DI[cRep].Sel=1;T.AsGem:=DI[rRun].Sel=2;
  N2:=ToInt(DI[eNum].Val);
  If (N2>=1) And (N2<=NTOOLS) Then N:=N2;
  If R=2 Then Begin
   P:=T.Path;
   If FileSelect(T3('Tool program','Programme de l''outil','Werkzeugprogramm'),
     '*.*',P) Then T.Path:=P;
  End;
 Until R=1;
 Tools[N]:=T;
End;

{ cherche un programme : repertoire courant puis variable PATH de
  l'environnement }
Function FindInEnvPath(Const Name: String): String;
Var P,D,X: String; I,K: Integer; Ext: Array[0..4] Of String[4];
Begin
 FindInEnvPath:='';
 Ext[0]:='';Ext[1]:='.PRG';Ext[2]:='.TTP';Ext[3]:='.TOS';Ext[4]:='.APP';
 If (Pos(DirSep,Name)>0) Or (Pos(':',Name)>0) Or (Pos('\',Name)>0) Or
   (Pos('/',Name)>0) Then Begin
  For K:=0 To 4 Do If FileExists(Name+Ext[K]) Then Begin
    FindInEnvPath:=Name+Ext[K];Exit;End;
  Exit;
 End;
 For K:=0 To 4 Do If FileExists(Name+Ext[K]) Then Begin
   FindInEnvPath:=Name+Ext[K];Exit;End;
 P:=EnvPathS;
 While P<>'' Do Begin
  I:=1;
  While (I<=Length(P)) And (P[I]<>',') And (P[I]<>';') Do Inc(I);
  D:=Copy(P,1,I-1);Delete(P,1,I);
  If D<>'' Then Begin
   D:=NormDir(D);
   For K:=0 To 4 Do Begin
    X:=D+Name+Ext[K];
    If FileExists(X) Then Begin FindInEnvPath:=X;Exit;End;
   End;
  End;
 End;
End;

Procedure RunReport(ReportAll: Boolean);
Begin
 If StopReason<>STOP_EXIT Then Exit;
 If (ExitCode<0) Or (ReportAll And (ExitCode<>0)) Then
  Alert1(1,T3('The program returned the error code ',
    'Le programme a rendu le code d''erreur ',
    'Das Programm lieferte den Fehlercode ')+IntStr(ExitCode));
End;

{ execute l'outil N }
Procedure RunTool(N: Integer);
Var T: TTool; Cl,Prog,Sv: String; SvGem,Ok: Boolean;
Begin
 If (N<1) Or (N>NTOOLS) Then Exit;
 T:=Tools[N];
 If T.Path='' Then Begin ConfigTool(N);Exit;End;
 Prog:=FindInEnvPath(T.Path);
 If Prog='' Then Begin
  Alert1(3,T3('Cannot find the tool|','Outil introuvable|',
    'Werkzeug nicht gefunden|')+T.Path);Exit;
 End;
 If T.Save=2 Then Begin If Not SaveAllWin Then Exit;End
 Else If T.Save=3 Then Begin If Not SaveFilesDialog Then Exit;End;
 Cl:='';
 If T.Mode=2 Then Begin
  Cl:=T.Cmd;
  If Not
    InputDlg(T3('Command line','Ligne de commande','Kommandozeile'),'',Cl,58)
    Then Exit;
  Cl:=ExpandCmdLine(Cl);
 End Else If T.Mode=3 Then Cl:=ExpandCmdLine(T.Cmd);
 GetDir(0,Sv);
 {$I-}
 If T.Dir=1 Then ChDir(PathOf(Prog))
 Else If (T.Dir=2) And (PathOf(EdFile)<>'') Then ChDir(PathOf(EdFile));
 {$I+}
 If IOResult<>0 Then Begin End;
 SvGem:=OptRunGem;OptRunGem:=T.AsGem;RunPause:=T.Pause;
 { le chemin est celui de la commande ; relatif au repertoire d'origine }
 RunProgramGUI(Prog,Cl);
 RunPause:=True;OptRunGem:=SvGem;
 {$I-}
 ChDir(Sv);
 {$I+}
 If IOResult<>0 Then Begin End;
 RunReport(T.ReportAll);
 NeedDraw:=True;
End;

{ Run with Shell (Shift-Alt-0) : ligne de commande libre, programme cherche
  dans PATH }
Procedure CmdRunShell;
Var S,Prog,Args: String; P: Integer;
Begin
 If Not SaveBeforeRun Then Exit;
 S:=ShellCmd;
 If Not
   InputDlg(T3('Run with Shell','Executer via le shell','Mit Shell starten'),
   T3('Command: ','Commande : ','Kommando: '),S,48) Then Exit;
 ShellCmd:=S;
 S:=ExpandCmdLine(TrimS(S));
 If S='' Then Exit;
 P:=Pos(' ',S);
 If P=0 Then Begin Prog:=S;Args:='';End Else Begin
   Prog:=Copy(S,1,P-1);Args:=TrimS(Copy(S,P+1,200));End;
 Prog:=FindInEnvPath(Prog);
 If Prog='' Then Begin
  Alert1(3,T3('Cannot find the program|','Programme introuvable|',
    'Programm nicht gefunden|')+Copy(S,1,40));Exit;
 End;
 RunProgramGUI(Prog,Args);
 NeedDraw:=True;
End;

{ Alt + touche du pave (D = 0..14) ; avec Ctrl : configurer l'outil }
Procedure ToolKeyPress(D: Integer; Cfg: Boolean);
Begin
 If D=0 Then Begin CmdRunOther;Exit;End;
 If Cfg Then ConfigTool(D) Else RunTool(D);
 NeedDraw:=True;
End;

Procedure CmdToolCfg;
Var S: String; N: Integer;
Begin
 S:='1';
 If InputDlgF(T3('Configure tool','Configurer un outil','Werkzeug einrichten'),
   T3('Number (1-20): ','Numero (1-20) : ','Nummer (1-20): '),S,2,1) Then Begin
  N:=ToInt(S);
  If (N>=1) And (N<=NTOOLS) Then ConfigTool(N);
 End;
End;

{ Options > Environment... : variables d'environnement des outils }
Procedure CmdEnviron;
Var R,eP,eC,eL: Integer;
Begin
 DlgReset(70,7);
 DlgLabel(1,0,T3('Environment','Environnement','Umgebung'));
 DlgLabel(1,2,'PATH=');
 eP:=DlgEditX(11,2,56,60,EnvPathS);
 DlgLabel(1,3,'CLINKWITH=');
 eC:=DlgEditX(11,3,56,60,EnvClinkS);
 DlgLabel(1,4,'LIBS=');
 eL:=DlgEditX(11,4,56,60,EnvLibsS);
 DlgButton(2,6,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(56,6,10,'OK',1,True);
 R:=DlgRun;
 If R=1 Then Begin
   EnvPathS:=DI[eP].Val;EnvClinkS:=DI[eC].Val;EnvLibsS:=DI[eL].Val;End;
End;

{ Options > Resident... : Assembler / Debugger (memorises ; le clone charge
  tout) }
Procedure CmdResident;
Var R,cA,cD: Integer;
Begin
 DlgReset(46,7);
 DlgLabel(1,0,T3('Resident Tools','Outils residents','Residente Werkzeuge'));
 cA:=DlgCheck(2,2,T3('Assembler','Assembleur','Assembler'),ResAsm);
 cD:=DlgCheck(2,3,T3('Debugger','Debogueur','Debugger'),ResDbg);
 DlgLabel(14,2,T3('(pre-loaded in memory; no effect here)',
   '(precharges ; sans effet ici)','(vorgeladen; hier ohne Wirkung)'));
 DlgButton(2,5,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(32,5,10,'OK',1,True);
 R:=DlgRun;
 If R=1 Then Begin ResAsm:=DI[cA].Sel=1;ResDbg:=DI[cD].Sel=1;End;
End;

{ ---------------------------------------------------------------------- }
{ Dialogues de l'assembleur (Options > Control / Listing / Options /        }
{ Optimisations) : manuel Devpac 3 pages 55-61. Toutes les valeurs sont     }
{ memorisees dans HISOFTED.INF et traduites en options OPT passees au moteur }
{ (CmdOpts) ou dans les variables Opt* existantes.                           }
{ ---------------------------------------------------------------------- }

Var
 AcIgnInc,AcLowMem,AcNoWarn : Boolean;
 AcDbg,AcLine,AcFmt : Integer;       { Debug symbols 1-3, Line debug 1-3,
   Format 1-6 }
 AcBufKB : Integer;                  { taille du tampon programme (Ko) }
 AcListDev,AcTab : Integer;          { Listing 1 None, 2 Screen, 3 Printer, 4
   Disk }
 AcList1,AcMex,AcCond,AcSym : Boolean;
 AcProc,AcBr,AcSig : Integer;        { processeur 1-6, branches 1 Word 2 Short
   3 Long, significance }
 AcFpu,AcMmu : Boolean;
 AcFlag  : Array[1..12] Of Boolean;  { cases de la boite Options (voir
   AcFlagOpt) }
 AcOpti  : Array[1..12] Of Integer;  { optimisations O1..O12 : 1 Y, 2 W, 3 N }
 CliOpts,CliSyms,CliHdr : String;    { options de la ligne de commande }

Function AcFlagOpt(I: Integer; On: Boolean): String;
Begin
 AcFlagOpt:='';
 Case I Of
  1: If On Then AcFlagOpt:='AUTOPC' Else AcFlagOpt:='NOAUTOPC';
  2: If On Then AcFlagOpt:='ALLOWZERO' Else AcFlagOpt:='NOALLOWZERO';
  3: If On Then AcFlagOpt:='BDW' Else AcFlagOpt:='BDL';
  4: If On Then AcFlagOpt:='NOCASE' Else AcFlagOpt:='CASE';
  5: If On Then AcFlagOpt:='CHKIMM' Else AcFlagOpt:='NOCHKIMM';
  6: If On Then AcFlagOpt:='CHKBIT' Else AcFlagOpt:='NOCHKBIT';
  7: If On Then AcFlagOpt:='CHKPC' Else AcFlagOpt:='NOCHKPC';
  8: If On Then AcFlagOpt:='NOEVEN' Else AcFlagOpt:='EVEN';
  9: If On Then AcFlagOpt:='NOTYPE' Else AcFlagOpt:='TYPE';
  10: If On Then AcFlagOpt:='USER' Else AcFlagOpt:='SUPER';
  11: If On Then AcFlagOpt:='ODL' Else AcFlagOpt:='ODW';
  12: If On Then AcFlagOpt:='LOCALU' Else AcFlagOpt:='LOCALDOT';
 End;
End;

Procedure AcDefaults;
Var I: Integer;
Begin
 AcIgnInc:=False;AcLowMem:=False;AcNoWarn:=False;
 AcDbg:=1;AcLine:=1;AcFmt:=1;AcBufKB:=401;
 AcListDev:=1;AcTab:=8;AcList1:=False;AcMex:=False;AcCond:=False;AcSym:=False;
 AcProc:=1;AcBr:=1;AcSig:=127;AcFpu:=False;AcMmu:=False;
 For I:=1 To 12 Do Begin AcFlag[I]:=False;AcOpti[I]:=3;End;
 AcFlag[6]:=True;                     { CHKBIT par defaut }
 ListClear(1);ListClear(2);ListClear(3);
End;

{ reprend dans les variables Ac* ce que la ligne de commande a deja decide }
Procedure AcFromOpts;
Begin
 If OptDebug And (AcDbg=1) Then AcDbg:=2;
 If OptListing And (AcListDev=1) Then AcListDev:=4;
 If Not OptWarnings Then AcNoWarn:=True;
 If Not OptToDisk Then AcFmt:=6;
 If OptOptimize And (AcOpti[1]=3) Then AcOpti[1]:=1;
 If Not OptCase Then AcFlag[4]:=True;
 If OptTabSize>0 Then AcTab:=OptTabSize;
 If CfgListName<>'' Then Begin
  If Upper(CfgListName)='PRINTER.OUT' Then AcListDev:=3 Else If AcListDev=1
    Then AcListDev:=4;
 End;
 CliOpts:=CmdOpts;CliSyms:=CmdSyms;CliHdr:=CmdHeaders;
End;

Function JoinC(Const A,B: String): String;
Begin
 If A='' Then JoinC:=B Else If B='' Then JoinC:=A Else JoinC:=A+','+B;
End;

{ traduit les dialogues en variables Opt* et en chaine OPT, avant un assemblage
  }
Procedure ApplyAsmCfg;
Var S: String; I: Integer;
Begin
 OptDebug:=AcDbg>=2;
 OptListing:=AcListDev>1;
 OptListDev:=AcListDev-1;
 If AcListDev=3 Then CfgListName:='PRINTER.OUT'
 Else If (AcListDev=4) And (Upper(CfgListName)='PRINTER.OUT') Then
   CfgListName:='';
 OptListName:=CfgListName;
 OptTabSize:=AcTab;
 OptWarnings:=Not AcNoWarn;
 OptCase:=Not AcFlag[4];
 OptOptimize:=AcOpti[1]<>3;
 Case AcFmt Of
  1,6: OptFormatSel:=0;
  2: OptFormatSel:=1;
  3: OptFormatSel:=2;
  4: OptFormatSel:=7;
  5: OptFormatSel:=6;
 End;
 OptToDisk:=AcFmt<>6;
 OptIncList:=ListJoin(2);
 CmdSyms:=JoinC(ListJoin(1),CliSyms);
 CmdHeaders:=JoinC(ListJoin(3),CliHdr);
 { chaine OPT : les options de la ligne de commande passent en dernier }
 S:='';
 Case AcDbg Of 1: S:='NODEBUG'; 2: S:='DEBUG'; 3: S:='XDEBUG'; End;
 Case AcLine Of 1: S:=JoinC(S,'NOLINE,NOHCLN'); 2: S:=JoinC(S,'LINE'); 3:
   S:=JoinC(S,'HCLN'); End;
 Case AcProc Of
  1: S:=JoinC(S,'P=68000'); 2: S:=JoinC(S,'P=68010'); 3: S:=JoinC(S,'P=68020');
  4: S:=JoinC(S,'P=68030'); 5: S:=JoinC(S,'P=68040'); 6: S:=JoinC(S,'P=68332');
 End;
 Case AcBr Of 1: S:=JoinC(S,'BRW'); 2: S:=JoinC(S,'BRB'); 3: S:=JoinC(S,'BRL');
   End;
 For I:=1 To 12 Do
  If I<>4 Then S:=JoinC(S,AcFlagOpt(I,AcFlag[I]));
 If AcSig<>127 Then S:=JoinC(S,'C'+IntStr(AcSig));
 For I:=1 To 12 Do Begin
  If AcOpti[I]=3 Then S:=JoinC(S,'O'+IntStr(I)+'-')
  Else Begin
   S:=JoinC(S,'O'+IntStr(I)+'+');
   If AcOpti[I]=2 Then S:=JoinC(S,'OW'+IntStr(I)+'+') Else
     S:=JoinC(S,'OW'+IntStr(I)+'-');
  End;
 End;
 If AcMex Then S:=JoinC(S,'MEX') Else S:=JoinC(S,'NOMEX');
 If AcSym Then S:=JoinC(S,'SYMTAB') Else S:=JoinC(S,'NOSYMTAB');
 If AcList1 Then S:=JoinC(S,'LIST1') Else S:=JoinC(S,'NOLIST1');
 If AcCond Then S:=JoinC(S,'TRACEIF') Else S:=JoinC(S,'NOTRACEIF');
 If AcIgnInc Then S:=JoinC(S,'INCONCE') Else S:=JoinC(S,'NOINCONCE');
 CmdOpts:=JoinC(S,CliOpts);
End;

{ --- boite Control ------------------------------------------------------- }
Procedure CmdAsmControl;
Var R,cIgn,cLow,cWarn,pDbg,pLine,pFmt,eOut,lEqu,lInc,lPre: Integer; S: String;
Begin
 Repeat
  DlgReset(76,23);
  DlgLabel(1,0,T3('Control','Controle','Steuerung'));
  cIgn:=DlgCheck(1,2,T3('Ignore multiple includes',
    'Ignorer les includes multiples','Mehrfache Includes ignorieren'),AcIgnInc);
  cLow:=DlgCheck(1,3,T3('Low memory assembly','Assemblage en memoire reduite',
    'Assemblieren mit wenig Speicher'),AcLowMem);
  cWarn:=DlgCheck(1,4,T3('No warnings','Pas d''avertissements',
    'Keine Warnungen'),AcNoWarn);
  DlgLabel(1,6,T3('Debug symbols','Symboles debug','Debug-Symbole'));
  pDbg:=DlgPopup(18,6,10,'None|Normal|Exports',AcDbg);
  DlgLabel(1,8,T3('Line debug','Debug de lignes','Zeilen-Debug'));
  pLine:=DlgPopup(18,8,12,'None|Standard|Compressed',AcLine);
  DlgLabel(1,10,'Format');
  pFmt:=DlgPopup(18,10,26,'Atari executable|GST linkable|DRI linkab'+
    'le|Lattice linkable|S-records|RAM (execu'+'table)',AcFmt);
  DlgButton(46,10,14,'Buffer size...',2,False);
  DlgLabel(38,1,'''EQU'' symbols');
  lEqu:=DlgList(38,2,36,4,1);
  DlgLabel(1,12,'''INCLUDE'' directories');
  lInc:=DlgList(1,13,35,3,2);
  DlgLabel(38,12,'Pre-assembled includes');
  lPre:=DlgList(38,13,36,3,3);
  DlgLabel(1,19,T3('Output to:','Sortie vers :','Ausgabe nach:'));
  eOut:=DlgEditX(13,19,60,60,CfgOutName);
  DlgButton(2,21,10,T3('Cancel','Annuler','Abbruch'),0,False);
  DlgButton(64,21,10,'OK',1,True);
  R:=DlgRun;
  If R=0 Then Exit;
  AcIgnInc:=DI[cIgn].Sel=1;AcLowMem:=DI[cLow].Sel=1;AcNoWarn:=DI[cWarn].Sel=1;
  AcDbg:=DI[pDbg].Sel;AcLine:=DI[pLine].Sel;AcFmt:=DI[pFmt].Sel;
  CfgOutName:=DI[eOut].Val;
  If R=2 Then Begin
   S:=IntStr(AcBufKB);
   If InputDlgF(T3('Buffer size','Taille du tampon','Puffergroesse'),
     T3('Maximum size (KB): ','Taille maximale (Ko) : ',
     'Maximale Groesse (KB): '),S,5,1) Then
    If ToInt(S)>0 Then AcBufKB:=ToInt(S);
  End;
 Until R=1;
 OptOutName:=CfgOutName;
End;

{ --- boite Listing ------------------------------------------------------- }
Procedure CmdAsmListing;
Var R,pLst,eTo,eTab,cF,cM,cC,cS: Integer;
Begin
 DlgReset(66,10);
 DlgLabel(1,0,'Listing');
 DlgLabel(1,2,'Listing');
 pLst:=DlgPopup(10,2,10,'None|Screen|Printer|Disk',AcListDev);
 DlgLabel(24,2,'List to:');
 eTo:=DlgEditX(33,2,30,60,CfgListName);
 DlgLabel(24,3,'Tab size:');
 eTab:=DlgEdit(33,3,3,IntStr(AcTab));DI[eTab].Flt:=1;
 cF:=DlgCheck(1,5,'First pass listing',AcList1);
 cM:=DlgCheck(34,5,'List macro expansions',AcMex);
 cC:=DlgCheck(1,6,'List conditionals only',AcCond);
 cS:=DlgCheck(34,6,'List symbol table',AcSym);
 DlgButton(2,8,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(54,8,10,'OK',1,True);
 R:=DlgRun;
 If R<>1 Then Exit;
 AcListDev:=DI[pLst].Sel;CfgListName:=DI[eTo].Val;
 AcTab:=Clamp(ToInt(DI[eTab].Val),2,16);
 AcList1:=DI[cF].Sel=1;AcMex:=DI[cM].Sel=1;AcCond:=DI[cC].Sel=1;AcSym:=DI[cS].
   Sel=1;
End;

{ --- boite Options ------------------------------------------------------- }
Procedure CmdAsmOptions;
Var R,I,pProc,pBr,eSig,cMmu,cFpu: Integer; C: Array[1..12] Of Integer;
Begin
 DlgReset(74,15);
 DlgLabel(1,0,'Options');
 cMmu:=DlgCheck(1,2,'68851 memory management unit',AcMmu);
 cFpu:=DlgCheck(1,3,'68881/2 maths coprocessor',AcFpu);
 C[1]:=DlgCheck(1,4,'Add automatic PC-relative',AcFlag[1]);
 C[2]:=DlgCheck(1,5,'Allow narrow zero operands',AcFlag[2]);
 C[3]:=DlgCheck(1,6,'Base displacement default word',AcFlag[3]);
 C[4]:=DlgCheck(1,7,'Case insensitive labels',AcFlag[4]);
 C[5]:=DlgCheck(1,8,'Check absolutes for missing #',AcFlag[5]);
 C[6]:=DlgCheck(38,2,'Check memory bitfield offsets',AcFlag[6]);
 C[7]:=DlgCheck(38,3,'Ensure PC-relative code',AcFlag[7]);
 C[8]:=DlgCheck(38,4,'No even indirection checking',AcFlag[8]);
 C[9]:=DlgCheck(38,5,'No expression type checking',AcFlag[9]);
 C[10]:=DlgCheck(38,6,'No supervisor instructions',AcFlag[10]);
 C[11]:=DlgCheck(38,7,'Outer displacement default long',AcFlag[11]);
 C[12]:=DlgCheck(38,8,'Underscore for local labels',AcFlag[12]);
 DlgLabel(1,10,'Processor');
 pProc:=DlgPopup(12,10,8,'68000|68010|68020|68030|68040|68332',AcProc);
 DlgLabel(24,10,'Default branch size');
 pBr:=DlgPopup(44,10,8,'Word|Short|Long',AcBr);
 DlgLabel(1,11,'Symbol significance:');
 eSig:=DlgEdit(22,11,3,IntStr(AcSig));DI[eSig].Flt:=1;
 DlgButton(2,13,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(62,13,10,'OK',1,True);
 R:=DlgRun;
 If R<>1 Then Exit;
 AcMmu:=DI[cMmu].Sel=1;AcFpu:=DI[cFpu].Sel=1;
 For I:=1 To 12 Do AcFlag[I]:=DI[C[I]].Sel=1;
 AcProc:=DI[pProc].Sel;AcBr:=DI[pBr].Sel;
 AcSig:=Clamp(ToInt(DI[eSig].Val),8,127);
End;

{ --- boite Optimisations ------------------------------------------------- }
Procedure CmdAsmOptim;
Const Ord12 : Array[1..12] Of Integer = (10,5,1,8,6,2,11,12,4,7,9,3);
Var R,I,K: Integer; Rd: Array[1..12] Of Integer; N: String;
Begin
 DlgReset(70,12);
 DlgLabel(1,0,'Optimisations');
 For I:=1 To 12 Do Begin
  K:=Ord12[I];
  Case K Of
   1: N:='Backward branches';
   2: N:='Indirect displacements';
   3: N:='Absolute to short word';
   4: N:='MOVE.L to MOVEQ';
   5: N:='ADD/SUB to ADDQ/SUBQ';
   6: N:='Forward branches';
   7: N:='Null branches to NOP';
   8: N:='Base displacements';
   9: N:='Outer displacements';
   10: N:='ADDA/SUBA to LEA';
   11: N:='LEA to ADDQ/SUBQ';
   12: N:='MOVEA.L to MOVEA.W';
  End;
  If I<=6 Then Begin
   Rd[K]:=DlgRadio(1,1+I,'Y|W|N',AcOpti[K]);
   DlgLabel(12,1+I,N);
  End Else Begin
   Rd[K]:=DlgRadio(37,I-5,'Y|W|N',AcOpti[K]);
   DlgLabel(48,I-5,N);
  End;
 End;
 DlgLabel(1,9,'Y = optimise   W = optimise with a warning   N = off');
 DlgButton(2,10,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(58,10,10,'OK',1,True);
 R:=DlgRun;
 If R<>1 Then Exit;
 For K:=1 To 12 Do AcOpti[K]:=DI[Rd[K]].Sel;
End;

{ --- Options > Debugger... : reglages de Mon (11 reglages, MON.INF) ------- }
Procedure CmdDebuggerOpts;
Var R,c1,c2,c3,c4,c5,c6,c7,c8,eSig,pLn,eLab: Integer; V: LongInt;
Begin
 PfDefaults;InitWindows;LoadMonInf;
 DlgReset(70,12);
 DlgLabel(1,0,T3('Debugger options','Options du debogueur',
   'Debugger-Optionen'));
 c1:=DlgCheck(1,2,'Auto ''@''/''_'' prefix labels',PfAutoPre);
 c2:=DlgCheck(1,3,'Auto-load source',PfAutoSrc);
 c3:=DlgCheck(1,4,'Display ''ZAn'' in disassembly',PfZAn);
 c4:=DlgCheck(1,5,'Enable timed screen switching',PfTimer);
 c5:=DlgCheck(37,2,'Follow TRAPs',PfTraps);
 c6:=DlgCheck(37,3,'Ignore cartridge area',PfCart);
 c7:=DlgCheck(37,4,'Ignore label case',PfIgnCase);
 c8:=DlgCheck(37,5,'Interpret relative offsets',PfRel);
 DlgLabel(1,7,'Symbol significance:');
 eSig:=DlgEdit(22,7,3,IntStr(PfSymLen));DI[eSig].Flt:=1;
 DlgLabel(37,7,'Source line numbers');
 pLn:=DlgPopup(57,7,8,'None|Dec|Hex',PfLines+1);
 DlgLabel(1,8,'Start at label:');
 eLab:=DlgEditX(18,8,30,40,PfLabel);
 DlgButton(2,10,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(58,10,10,'OK',1,True);
 R:=DlgRun;
 If R<>1 Then Exit;
 PfAutoPre:=DI[c1].Sel=1;PfAutoSrc:=DI[c2].Sel=1;PfZAn:=DI[c3].Sel=1;PfTimer:=DI
   [c4].Sel=1;
 PfTraps:=DI[c5].Sel=1;PfCart:=DI[c6].Sel=1;PfIgnCase:=DI[c7].Sel=1;PfRel:=DI[c8
   ].Sel=1;
 V:=ToInt(DI[eSig].Val);If V<8 Then V:=8;If V>24 Then V:=24;PfSymLen:=V;
 PfLines:=DI[pLn].Sel-1;PfLabel:=DI[eLab].Val;
 SaveMonInf;
End;

{ reglages Ac* dans HISOFTED.INF }
Procedure AcWrite(Var T: Text);
Var I: Integer;
Begin
 WriteLn(T,'AC_FLAGS=',Ord(AcIgnInc),Ord(AcLowMem),Ord(AcNoWarn),Ord(AcList1),
   Ord(AcMex),Ord(AcCond),Ord(AcSym),Ord(AcFpu),Ord(AcMmu));
 WriteLn(T,'AC_NUM=',AcDbg,',',AcLine,',',AcFmt,',',AcBufKB,',',AcListDev,',',
   AcTab,',',AcProc,',',AcBr,',',AcSig);
 Write(T,'AC_OPTS=');
 For I:=1 To 12 Do Write(T,Ord(AcFlag[I]));
 WriteLn(T);
 Write(T,'AC_OPTI=');
 For I:=1 To 12 Do Write(T,AcOpti[I]);
 WriteLn(T);
 WriteLn(T,'AC_EQU=',ListJoin(1));
 WriteLn(T,'AC_INC=',ListJoin(2));
 WriteLn(T,'AC_PRE=',ListJoin(3));
End;

Function AcRead(Const K,V: String): Boolean;
Var I,P,N: Integer; S: String; A: Array[1..9] Of Integer;
Begin
 AcRead:=True;
 If K='AC_FLAGS' Then Begin
  AcIgnInc:=Copy(V,1,1)='1';AcLowMem:=Copy(V,2,1)='1';AcNoWarn:=Copy(V,3,
    1)='1';AcList1:=Copy(V,4,1)='1';
  AcMex:=Copy(V,5,1)='1';AcCond:=Copy(V,6,1)='1';AcSym:=Copy(V,7,
    1)='1';AcFpu:=Copy(V,8,1)='1';AcMmu:=Copy(V,9,1)='1';
 End Else If K='AC_NUM' Then Begin
  S:=V;
  For N:=1 To 9 Do Begin
   P:=Pos(',',S);
   If P=0 Then Begin A[N]:=ToInt(S);S:='';End Else Begin
     A[N]:=ToInt(Copy(S,1,P-1));Delete(S,1,P);End;
  End;
  AcDbg:=Clamp(A[1],1,3);AcLine:=Clamp(A[2],1,3);AcFmt:=Clamp(A[3],1,
    6);AcBufKB:=Clamp(A[4],1,9999);
  AcListDev:=Clamp(A[5],1,4);AcTab:=Clamp(A[6],2,16);AcProc:=Clamp(A[7],1,
    6);AcBr:=Clamp(A[8],1,3);
  AcSig:=Clamp(A[9],8,127);
 End Else If K='AC_OPTS' Then Begin
  For I:=1 To 12 Do AcFlag[I]:=Copy(V,I,1)='1';
 End Else If K='AC_OPTI' Then Begin
  For I:=1 To 12 Do AcOpti[I]:=Clamp(ToInt(Copy(V,I,1)),1,3);
 End Else If K='AC_EQU' Then ListSplit(1,V)
 Else If K='AC_INC' Then ListSplit(2,V)
 Else If K='AC_PRE' Then ListSplit(3,V)
 Else AcRead:=False;
End;

{ Options > Fonts... (Ctrl-G) : police de l'editeur ; effet immediat }
Procedure CmdFonts;
Var R,Rf: Integer;
Begin
 DlgReset(54,8);
 DlgLabel(2,0,T3('Fonts','Polices','Schriften'));
 DlgLabel(2,2,T3('GEM Font','Police GEM','GEM-Schrift'));
 Rf:=DlgRadio(14,2,'Normal|Small|Tiny|8x10',FontKind+1);
 DlgLabel(2,4,T3('Normal 8x16, Small 8x8, Tiny 6x7 (the ed'+'itor text)',
   'Normal 8x16, Small 8x8, Tiny 6x7 (texte '+'de l''editeur)',
   'Normal 8x16, Small 8x8, Tiny 6x7 (Editor'+'text)'));
 DlgButton(2,6,10,T3('Cancel','Annuler','Abbruch'),0,False);
 DlgButton(40,6,10,'OK',1,True);
 R:=DlgRun;
 If R=1 Then EApplyFont(DI[Rf].Sel-1);
 NeedDraw:=True;
End;

{ ---------------------------------------------------------------------- }
{ Reglages supplementaires dans HISOFTED.INF                                }
{ ---------------------------------------------------------------------- }

Procedure CfgWriteExtra(Var T: Text);
Var I: Integer;
Begin
 WriteLn(T,'FONT=',FontKind);
 WriteLn(T,'LAYOUT=',ELayoutKeep);
 For I:=1 To NTOOLS Do
  If (Tools[I].Name<>'') Or (Tools[I].Path<>'') Then
   WriteLn(T,'TOOL',I,'=',Tools[I].Name,'|',Tools[I].Mode,'|',Tools[I].Dir,'|',
     Tools[I].Save,'|',
    Ord(Tools[I].Pause),'|',Ord(Tools[I].ReportAll),'|',Ord(Tools[I].AsGem),'|',
      Ord(Tools[I].Resident),'|',
    Tools[I].Path,'|',Tools[I].Cmd);
 WriteLn(T,'ENVPATH=',EnvPathS);
 WriteLn(T,'ENVCLINK=',EnvClinkS);
 WriteLn(T,'ENVLIBS=',EnvLibsS);
 WriteLn(T,'RESIDENT=',Ord(ResAsm),Ord(ResDbg));
 AcWrite(T);
End;

{ TOOLn=nom|mode|rep|save|pause|report|gem|resident|chemin|commande }
Procedure ReadTool(N: Integer; Const V: String);
Var F: Array[1..10] Of String; I,P,K: Integer; S: String;
Begin
 S:=V;
 For K:=1 To 10 Do F[K]:='';
 K:=1;
 While (S<>'') And (K<=10) Do Begin
  P:=Pos('|',S);
  If (P=0) Or (K=10) Then Begin F[K]:=S;S:='';End Else Begin
    F[K]:=Copy(S,1,P-1);Delete(S,1,P);End;
  Inc(K);
 End;
 Tools[N].Name:=Copy(F[1],1,20);
 Tools[N].Mode:=Clamp(ToInt(F[2]),1,3);Tools[N].Dir:=Clamp(ToInt(F[3]),1,
   3);Tools[N].Save:=Clamp(ToInt(F[4]),1,3);
 Tools[N].Pause:=ToInt(F[5])<>0;Tools[N].ReportAll:=ToInt(F[6])<>0;
 Tools[N].AsGem:=ToInt(F[7])<>0;Tools[N].Resident:=ToInt(F[8])<>0;
 Tools[N].Path:=Copy(F[9],1,78);Tools[N].Cmd:=Copy(F[10],1,78);
End;

Function CfgReadExtra(Const K,V: String): Boolean;
Begin
 CfgReadExtra:=True;
 If K='FONT' Then ESetFont(Clamp(ToInt(V),0,3))
 Else If K='LAYOUT' Then ELayoutKeep:=Clamp(ToInt(V),0,3)
 Else If K='ENVPATH' Then EnvPathS:=V
 Else If K='ENVCLINK' Then EnvClinkS:=V
 Else If K='ENVLIBS' Then EnvLibsS:=V
 Else If Copy(K,1,3)='AC_' Then CfgReadExtra:=AcRead(K,V)
 Else If K='RESIDENT' Then Begin
   ResAsm:=Copy(V,1,1)<>'0';ResDbg:=Copy(V,2,1)<>'0';End
 Else If (Copy(K,1,4)='TOOL') And (ToInt(Copy(K,5,3))>=1) And
   (ToInt(Copy(K,5,3))<=NTOOLS) Then ReadTool(ToInt(Copy(K,5,3)),V)
 Else CfgReadExtra:=False;
End;

Procedure DoCmd(Id: Integer);
Begin
 If MouseHid Then Begin MouseHid:=False;ShowMouse;End;
 Case Id Of
  CM_ABOUT: CmdAbout;
  CM_HELP: CmdHelp;
  CM_MEMORY: CmdMemory;
  CM_NEW: CmdNew;
  CM_LOAD: CmdLoad;
  CM_INSERT: CmdInsert;
  CM_REVERT: CmdRevert;
  CM_CLOSE: CmdClose;
  CM_SAVEAS: CmdSaveAs;
  CM_SAVE: CmdSave;
  CM_DELFILE: CmdDeleteFile;
  CM_CHDIR: CmdChDir;
  CM_QUIT: CmdQuit;
  CM_CUT: DeleteBlock;
  CM_COPY: CopyBlock;
  CM_PASTE: PasteBlock;
  CM_SELALL: SelectAll;
  CM_ASCII: CmdAscii;
  CM_TOP: GotoLine(1);
  CM_BOTTOM: GotoLine(EdN);
  CM_CYCLE: EWinCycle;
  CM_GOTO: DoGotoLine;
  CM_BSTART: SetBlockStart;
  CM_BEND: SetBlockEnd;
  CM_BSAVE: CmdSaveBlock;
  CM_BCOPY: DupBlock;
  CM_BDEL: DeleteBlock;
  CM_BREM: CopyBlock;
  CM_BPASTE: PasteBlock;
  CM_BPRINT: PrintBlock;
  CM_FIND: DoFind;
  CM_FNEXT: DoFindNext;
  CM_FPREV: FindPrevious;
  CM_REPL: DoReplace;
  CM_REPLALL: DoReplaceAll;
  CM_PREFS: EditorPrefsDlg;
  CM_ASMOPT: CmdAsmControl;
  CM_ASMLST: CmdAsmListing;
  CM_ASMOPTS: CmdAsmOptions;
  CM_ASMOPTI: CmdAsmOptim;
  CM_DBGOPT: CmdDebuggerOpts;
  CM_RUNOPT: RunOptionsDlg;
  CM_FONTS: CmdFonts;
  CM_SAVEPREF: SavePrefs;
  CM_LOADPREF: CmdLoadPrefs;
  CM_RUNOTHER: CmdRunOther;
  CM_RUNSHELL: CmdRunShell;
  CM_TOOLCFG: CmdToolCfg;
  CM_ENVIRON: CmdEnviron;
  CM_RESIDENT: CmdResident;
  CM_TOOL1..CM_TOOL1+19: If (PickMods And KM_CTRL)<>0 Then
    ConfigTool(Id-CM_TOOL1+1) Else RunTool(Id-CM_TOOL1+1);
  CM_ASM: CmdAssemble;
  CM_CHECK: CmdCheck;
  CM_OUTSYM: CmdOutputSymbols;
  CM_RUN: CmdRun;
  CM_DEBUG: CmdDebug;
  CM_MON: CmdMonitor;
  CM_GEM: OptRunGem:=Not OptRunGem;
  CM_PREVERR: ErrorStep(-1);
  CM_JUMPERR: ErrorStep(1);
  CM_NEXTERR: NextErrorAfterCursor;
 End;
 NeedDraw:=True;
End;

Procedure DoMenu(M,I: Integer);
Begin
 DoCmd(MItem(M,I));
End;

Var LastLayout : Integer;

Procedure ArrangeWinN(K: Integer);
Begin
 EArrange(K);
End;

Procedure DoSub(Id,J: Integer);
Begin
 Case Id Of
  CM_SETBM: SetBookmark(J);
  CM_GOTOBM: GotoBookmark(J);
  CM_RUNDIR: RunDirMode:=J;
  CM_WINDOW: EWinActivate(J);
  CM_ARRANGE: Begin
              If (J>=1) And (J<=3) Then Begin
               LastLayout:=J;
               ArrangeWinN(J);
               If (PickMods And KM_CTRL)<>0 Then ELayoutKeep:=J
               Else If ELayoutKeep>0 Then ELayoutKeep:=J;
              End Else If J=5 Then Begin
               If ELayoutKeep>0 Then ELayoutKeep:=0
               Else Begin
                If LastLayout=0 Then LastLayout:=1;
                ELayoutKeep:=LastLayout;ArrangeWinN(LastLayout);
               End;
              End;
             End;
 End;
 NeedDraw:=True;
End;

{ ---------------------------------------------------------------------- }
{ Clavier et souris                                                         }
{ ---------------------------------------------------------------------- }

{ Commandes Ctrl-lettre : touches du manuel Devpac et WordStar (^S ^D ^E ^X) }
Procedure CtrlCommand(K: Word);
Begin
 Case K Of
  1: WordLeft;                 { ^A mot a gauche }
  3: CurPageDown;              { ^C page vers le bas (WordStar) }
  4: CurRight;                 { ^D }
  5: CurUp;                    { ^E }
  6: WordRight;                { ^F mot a droite }
  7: DoCmd(CM_FONTS);          { ^G Fonts }
  22: DoCmd(CM_CYCLE);         { ^V Cycle Windows }
  10: DoCmd(CM_PREVERR);       { ^J erreur precedente }
  12: DoCmd(CM_LOAD);          { ^L (ancien raccourci du clone) }
  14: DoCmd(CM_NEW);           { ^N (ancien raccourci du clone) }
  15: DoCmd(CM_RUNOTHER);      { ^O (ancien raccourci du clone) }
  17: DoCmd(CM_QUIT);          { ^Q (ancien raccourci du clone) }
  18: CurPageUp;               { ^R page vers le haut (WordStar) }
  19: CurLeft;                 { ^S }
  21: UndeleteLine;            { ^U }
  23: DoCmd(CM_CLOSE);         { ^W fermer la fenetre }
  24: CurDown;                 { ^X }
  25: DeleteCurLine;           { ^Y }
 End;
End;

{ Alt-lettre : raccourcis des menus (Sh = Maj enfoncee) }
Procedure AltCommand(L: Char; Sh: Boolean);
Begin
 Case L Of
  'A': DoCmd(CM_ASM);
  'Y': DoCmd(CM_CHECK);
  'X': DoCmd(CM_RUN);
  'D': DoCmd(CM_DEBUG);
  'M': DoCmd(CM_MON);
  'K': DoCmd(CM_GEM);
  'J': If Sh Then DoCmd(CM_NEXTERR) Else DoCmd(CM_JUMPERR);
  'U': DoCmd(CM_NEXTERR);
  'L': DoCmd(CM_LOAD);
  'S': If Sh Then DoCmd(CM_SAVE) Else DoCmd(CM_SAVEAS);
  'I': DoCmd(CM_INSERT);
  'Q': DoCmd(CM_QUIT);
  'F': DoCmd(CM_FIND);
  'N': DoCmd(CM_FNEXT);
  'P': DoCmd(CM_FPREV);
  'R': DoCmd(CM_REPL);
  'G': DoCmd(CM_GOTO);
  'T': DoCmd(CM_TOP);
  'B': DoCmd(CM_BOTTOM);
  'H': DoCmd(CM_HELP);
  'W': DoCmd(CM_BPRINT);
  'C': DoCmd(CM_ASCII);
 End;
End;

Procedure HandleKey(K: Word);
Var L: Char; M: Byte; Sh,Ct,Al: Boolean;
Begin
 M:=KeyMods;
 If Not ((K=K_UP) Or (K=K_DOWN) Or (K=K_PGUP) Or (K=K_PGDN)) Then Begin
  If (K=K_BKSP) And (CurV>0) Then Begin
   CurV:=0;
   If Length(Ed^[CurL]^)=0 Then Begin NeedDraw:=True;Exit;End;
  End Else If (K=K_DEL) And (CurV>0) Then Begin NeedDraw:=True;Exit;End
  Else If (K=K_LEFT) And (CurV>0) Then Begin Dec(CurV);NeedDraw:=True;Exit;End
  Else CurV:=0;
 End;
 Sh:=(M And KM_SHIFT)<>0;Ct:=(M And KM_CTRL)<>0;Al:=(M And KM_ALT)<>0;
 If StatusMsg<>'' Then Begin StatusMsg:='';NeedDraw:=True;End;
 If HiOn Then Begin HiOn:=False;NeedDraw:=True;End;
 If (PrefHideMouse=1) And (Not MouseHid) And ((K>=32) And (K<=255) Or
   (K=K_BKSP) Or (K=K_ENTER) Or (K=K_TAB)) Then Begin
  HideMouse;MouseHid:=True;
 End;
 { Ctrl-chiffre : aller au signet ; Ctrl-Maj-chiffre : poser le signet }
 If Ct And (K>=48) And (K<=57) Then Begin
  If (K>=49) And (K<=56) Then Begin
   If Sh Then SetBookmark(K-48) Else GotoBookmark(K-48);
  End;
  NeedDraw:=True;Exit;
 End;
 If (K>=1) And (K<=26) And (K<>8) And (K<>9) And (K<>13) Then Begin
  CtrlCommand(K);NeedDraw:=True;Exit;
 End;
 L:=AltLetter(K);
 If L<>#0 Then Begin AltCommand(L,Sh);NeedDraw:=True;Exit;End;
 Case K Of
  K_F1: DoCmd(CM_BSTART);
  K_F2: DoCmd(CM_BEND);
  K_F3: DoCmd(CM_BSAVE);
  K_F4: DoCmd(CM_BCOPY);
  K_F5: DoCmd(CM_PASTE);
  256+87: DoCmd(CM_BREM);          { Shift-F4 }
  256+88: DoCmd(CM_BDEL);          { Shift-F5 }
  K_F8: DoCmd(CM_SAVE);
  K_F9: DoCmd(CM_RUN);
  K_F10: RunMenu(1,False);
  256+120..256+126: EWinActivate(K-256-119);  { Alt-1 .. Alt-7 : fenetres }
  256+129: If Sh Then DoCmd(CM_RUNSHELL) Else DoCmd(CM_RUNOTHER);     { Alt-0 /
    Maj-Alt-0 }
  256+240..256+254: ToolKeyPress(K-256-240,Ct);   { Alt + pave numerique :
    outils }
  256+94..256+101: GotoBookmark(K-256-93);     { Ctrl-F1..F8 }
  256+104..256+111: SetBookmark(K-256-103);    { Alt-F1..F8 }
  259: DeleteToEol;                { Ctrl-@ (Ctrl-Espace) }
  K_UP: If Sh Then CurPageUp Else CurUp;
  K_DOWN: If Sh Then CurPageDown Else CurDown;
  K_LEFT: If Sh Then WordLeft Else CurLeft;
  K_RIGHT: If Sh Then WordRight Else CurRight;
  K_CLEFT: Begin CurC:=1;EnsureVisible;WantV:=0;End;
  K_CRIGHT: Begin
    CurC:=Length(Ed^[CurL]^)+1;EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);End;
  K_HOME: Begin CurC:=1;EnsureVisible;WantV:=0;End;
  K_END: Begin
    CurC:=Length(Ed^[CurL]^)+1;EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);End;
  K_CHOME: Begin CurL:=1;CurC:=1;TopL:=1;EnsureVisible;WantV:=0;End;
  K_CEND: Begin
    CurL:=EdN;CurC:=Length(Ed^[CurL]^)+1;EnsureVisible;WantV:=VisOf(Ed^[CurL]^,
    CurC);End;
  K_PGUP: CurPageUp;
  K_PGDN: CurPageDown;
  K_INS: If Sh Then DoCmd(CM_ASCII) Else EdIns:=Not EdIns;
  K_DEL: DoDelete;
  K_BKSP: DoBackspace;
  K_ENTER: Begin EditLine:=CurL;NewLineAt;End;
  K_TAB: DoTab;
  32..255: Begin
            InsertChar(Chr(K));
            If (K=41) And (PrefMatch=1) Then ShowMatchingParen;
           End;
 End;
 NeedDraw:=True;
End;

Var PosV : Integer;          { colonne visuelle demandee par le dernier EdPosAt
  }

Procedure EdPosAt(X,Y: LongInt; Var L,C: Integer);
Var V: Integer;
Begin
 L:=TopL+((Y-TY0) Div FontLH);
 If Y<TY0 Then L:=TopL-1;
 If L<1 Then L:=1;
 If L>EdN Then L:=EdN;
 V:=LeftV+((X-TX0+FontCW Div 2) Div FontCW);
 If X<TX0 Then V:=LeftV-1;
 If V<0 Then V:=0;
 PosV:=V;
 C:=CharOfVis(Ed^[L]^,V);
End;

Procedure VScroll(D: Integer);
Begin
 ScrollOnly:=True;
 TopL:=Clamp(TopL+D,1,Max2(1,EdN-TXT_ROWS+1));
End;

Var DragThumb: Boolean;
    ThumbOff   : LongInt;

{ geometrie de l'ascenseur vertical : haut de la glissiere (Y1), hauteur utile
  (H), taille (Sz) et position (Pos) du curseur ; False s'il n'y a pas de
    defilement }
Function ThumbGeom(Var Y1,H,Sz,Pos: LongInt): Boolean;
Var Y2: LongInt;
Begin
 Y1:=TY0+SB_W-1;Y2:=TXT_Y2-SB_W+1;
 H:=Y2-Y1-2;
 ThumbGeom:=EdN>TXT_ROWS;
 If EdN<=TXT_ROWS Then Exit;
 Sz:=H*TXT_ROWS Div EdN;If Sz<12 Then Sz:=12;
 Pos:=(H-Sz)*(TopL-1) Div (EdN-TXT_ROWS);
 If Pos<0 Then Pos:=0;
End;

{ fenetre (numero) visible sous le point, 0 si c'est le bureau }
Function WinAtXY(X,Y: LongInt): Integer;
Var Z,I: Integer;
Begin
 WinAtXY:=0;
 For Z:=ENWin Downto 1 Do Begin
  I:=EZOrd[Z];
  If InBox(X,Y,EWins[I].X1,EWins[I].Y1,EWins[I].X2,EWins[I].Y2) Then Begin
    WinAtXY:=I;Exit;End;
 End;
End;

{ deplacement (Mode 1) ou changement de taille (Mode 2) de la fenetre active
  a la souris : un cadre en inversion suit le pointeur }
Procedure DragWindow(Mode: Integer);
Var E: TEvent; X1,Y1,X2,Y2,NX1,NY1,NX2,NY2,SX,SY,W,H: Integer; Done: Boolean;
 Procedure Outline;
 Begin
  HideMouse;
  SetWriteMode(XORPut);
  SetColor(15);
  Rectangle(NX1,NY1,NX2,NY2);
  Rectangle(NX1+1,NY1+1,NX2-1,NY2-1);
  SetWriteMode(NormalPut);
  ShowMouseU;
 End;
Begin
 X1:=WX1;Y1:=WY1;X2:=WX2;Y2:=WY2;
 SX:=MX;SY:=MY;W:=X2-X1;H:=Y2-Y1;
 NX1:=X1;NY1:=Y1;NX2:=X2;NY2:=Y2;
 Outline;
 Done:=False;
 Repeat
  PollEvent(E);
  If E.Kind=4 Then Begin
   Outline;
   If Mode=1 Then Begin
    NX1:=X1+E.X-SX;NY1:=Y1+E.Y-SY;
    If NX1<0 Then NX1:=0;
    If NX1>SCR_W-W-1 Then NX1:=SCR_W-W-1;
    If NY1<DESK_Y Then NY1:=DESK_Y;
    If NY1>SCR_H-TITLE_H-1 Then NY1:=SCR_H-TITLE_H-1;
    NX2:=NX1+W;NY2:=NY1+H;
   End Else Begin
    NX2:=X2+E.X-SX;NY2:=Y2+E.Y-SY;
    If NX2<X1+200 Then NX2:=X1+200;
    If NY2<Y1+TITLE_H+INFO_H+90 Then NY2:=Y1+TITLE_H+INFO_H+90;
    If NX2>SCR_W-1 Then NX2:=SCR_W-1;
    If NY2>SCR_H-1 Then NY2:=SCR_H-1;
   End;
   Outline;
  End Else If E.Kind=3 Then Done:=True;
 Until Done;
 Outline;
 EWinSetRect(EActW,NX1,NY1,NX2,NY2);
 NeedDraw:=True;
End;

Var LastTitleT : LongInt;
    DragWS,DragWE : Integer;      { mot de depart d'une selection mot par mot }

Procedure MouseDown(X,Y,B: LongInt);
Var T,L,C,W1,W2,WH: Integer; Y1,Y2,H,Sz,Pos: LongInt; S: String;
Begin
 T:=TitleHit(X,Y);
 If T>0 Then Begin RunMenu(T,True);Exit;End;
 If Y<DESK_Y Then Exit;
 If StatusMsg<>'' Then Begin StatusMsg:='';NeedDraw:=True;End;
 If HiOn Then Begin HiOn:=False;NeedDraw:=True;End;
 WH:=WinAtXY(X,Y);
 If WH=0 Then Exit;
 If WH<>EActW Then Begin EWinActivate(WH);NeedDraw:=True;Exit;End;
 { fenetre active : case de fermeture, plein ecran, barre de titre, coin de
   taille }
 If InBox(X,Y,WX1+1,WY1+1,WX1+17,WY1+TITLE_H-2) Then Begin
   DoCmd(CM_CLOSE);Exit;End;
 If InBox(X,Y,WX2-17,WY1+1,WX2-1,WY1+TITLE_H-2) Then Begin
   EWinToggleFull(EActW);NeedDraw:=True;Exit;End;
 If InBox(X,Y,WX1,WY1,WX2,WY1+TITLE_H-1) Then Begin
  If MsNow-LastTitleT<400 Then Begin
    EWinToggleFull(EActW);NeedDraw:=True;LastTitleT:=0;End
  Else Begin LastTitleT:=MsNow;If (WX1>0) Or (WX2<SCR_W-1) Or (WY1>DESK_Y) Or
    (WY2<SCR_H-1) Then DragWindow(1);End;
  Exit;
 End;
 If InBox(X,Y,TXT_X2+1,TXT_Y2+1,WX2,WY2) Then Begin DragWindow(2);Exit;End;
 If InBox(X,Y,WX1+1,TY0,TXT_X2,TXT_Y2) Then Begin
  EdPosAt(X,Y,L,C);
  MoveCur(L,C);
  CurV:=0;
  If C>Length(Ed^[L]^) Then Begin
   CurV:=PosV-VisOf(Ed^[L]^,C);
   If CurV<0 Then CurV:=0;
   EnsureVisible;
  End;
  DragSel:=True;AnchL:=L;AnchC:=C;DragMode:=0;
  If X<TX0 Then Begin
   { marge gauche : selection ligne par ligne }
   DragMode:=1;
   BlkSL:=L;BlkSC:=1;
   If L<EdN Then Begin BlkEL:=L+1;BlkEC:=1;End Else Begin
     BlkEL:=L;BlkEC:=Length(Ed^[L]^)+1;End;
   BlkSOk:=True;BlkEOk:=True;
  End Else If (MsNow-LastClkT<400) And (LastClkL=L) And (LastClkC=C) Then Begin
   { double-clic : le mot sous la souris devient le bloc }
   S:=Ed^[L]^;
   If C<=Length(S) Then Begin
    W1:=C;W2:=C;
    While (W1>1) And (S[W1-1]<>' ') And (S[W1-1]<>#9) Do Dec(W1);
    While (W2<=Length(S)) And (S[W2]<>' ') And (S[W2]<>#9) Do Inc(W2);
    BlkSL:=L;BlkSC:=W1;BlkEL:=L;BlkEC:=W2;BlkSOk:=True;BlkEOk:=True;
    DragMode:=2;DragWS:=W1;DragWE:=W2;AnchL:=L;
   End;
  End;
  LastClkT:=MsNow;LastClkL:=L;LastClkC:=C;
  NeedDraw:=True;
  Exit;
 End;
 If X>TXT_X2 Then Begin
  Y1:=TY0+SB_W-1;Y2:=TXT_Y2-SB_W+1;
  If InBox(X,Y,TXT_X2+1,TY0-1,WX2,TY0+SB_W-2) Then VScroll(-1)
  Else If InBox(X,Y,TXT_X2+1,TXT_Y2-SB_W+2,WX2,TXT_Y2+1) Then VScroll(1)
  Else If (Y>=Y1) And (Y<=Y2) Then Begin
   { zone grise : une page vers le haut ou vers le bas selon le curseur de
     l'ascenseur }
   If ThumbGeom(Y1,H,Sz,Pos) Then Begin
    If Y<Y1+1+Pos Then VScroll(-(TXT_ROWS-1))
    Else If Y>Y1+1+Pos+Sz Then VScroll(TXT_ROWS-1)
    Else Begin DragThumb:=True;ThumbOff:=Y-(Y1+1+Pos);End;
   End;
  End;
  NeedDraw:=True;Exit;
 End;
 If Y>TXT_Y2 Then Begin
  ScrollOnly:=True;
  If X<WX1+SB_W Then LeftV:=Max2(0,LeftV-4)
  Else If X>TXT_X2-SB_W Then LeftV:=LeftV+4
  Else If X<(WX1+TXT_X2) Div 2 Then LeftV:=Max2(0,LeftV-TXT_COLS Div 2)
  Else LeftV:=LeftV+TXT_COLS Div 2;
  NeedDraw:=True;
 End;
End;

Procedure MouseMove(X,Y: LongInt);
Var L,C,W1,W2: Integer; Y1,H,Sz,Pos: LongInt; S: String;
Begin
 If DragThumb And ((MB And 3)<>0) Then Begin
  If ThumbGeom(Y1,H,Sz,Pos) And (H>Sz) Then Begin
   Pos:=Y-ThumbOff-(Y1+1);
   If Pos<0 Then Pos:=0;
   If Pos>H-Sz Then Pos:=H-Sz;
   TopL:=Clamp(1+Pos*(EdN-TXT_ROWS) Div (H-Sz),1,Max2(1,EdN-TXT_ROWS+1));
   ScrollOnly:=True;NeedDraw:=True;
  End;
  Exit;
 End;
 If DragSel And ((MB And 3)<>0) Then Begin
  EdPosAt(X,Y,L,C);
  If DragMode=2 Then Begin
   { double-clic + glisser : selection mot par mot }
   S:=Ed^[L]^;
   W1:=C;W2:=C;
   If C<=Length(S) Then Begin
    While (W1>1) And (S[W1-1]<>' ') And (S[W1-1]<>#9) Do Dec(W1);
    While (W2<=Length(S)) And (S[W2]<>' ') And (S[W2]<>#9) Do Inc(W2);
   End;
   If (L<AnchL) Or ((L=AnchL) And (W1<DragWS)) Then Begin
    BlkSL:=L;BlkSC:=W1;BlkEL:=AnchL;BlkEC:=DragWE;
   End Else Begin
    BlkSL:=AnchL;BlkSC:=DragWS;BlkEL:=L;BlkEC:=W2;
   End;
   BlkSOk:=True;BlkEOk:=True;
   CurL:=L;CurC:=C;EnsureVisible;WantV:=VisOf(Ed^[CurL]^,CurC);NeedDraw:=True;
  End Else If DragMode=1 Then Begin
   { selection par lignes depuis la marge }
   If L>=AnchL Then Begin
    BlkSL:=AnchL;BlkSC:=1;
    If L<EdN Then Begin BlkEL:=L+1;BlkEC:=1;End Else Begin
      BlkEL:=L;BlkEC:=Length(Ed^[L]^)+1;End;
   End Else Begin
    BlkSL:=L;BlkSC:=1;
    If AnchL<EdN Then Begin BlkEL:=AnchL+1;BlkEC:=1;End Else Begin
      BlkEL:=AnchL;BlkEC:=Length(Ed^[AnchL]^)+1;End;
   End;
   BlkSOk:=True;BlkEOk:=True;
   If L<>CurL Then Begin
     CurL:=L;CurC:=1;EnsureVisible;WantV:=0;NeedDraw:=True;End;
  End Else If (L<>CurL) Or (C<>CurC) Then Begin
   CurL:=L;CurC:=C;
   If (AnchL<L) Or ((AnchL=L) And (AnchC<=C)) Then Begin
    BlkSL:=AnchL;BlkSC:=AnchC;BlkEL:=L;BlkEC:=C;
   End Else Begin
    BlkSL:=L;BlkSC:=C;BlkEL:=AnchL;BlkEC:=AnchC;
   End;
   BlkSOk:=True;BlkEOk:=True;
   EnsureVisible;
   WantV:=VisOf(Ed^[CurL]^,CurC);
   NeedDraw:=True;
  End;
 End;
End;

Procedure MouseUp;
Begin
 DragSel:=False;DragThumb:=False;
End;

Procedure MainLoop;
Var E: TEvent;
Begin
 Repeat
  If NeedDraw Then DrawAll;
  IdleOK:=True;
  PollEvent(E);
  IdleOK:=False;
  If MouseHid And (E.Kind>=2) Then Begin MouseHid:=False;ShowMouse;End;
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
 WriteLn(ConOut,'DEVPAC - '+T3('Clone of HiSoft Devpac (Atari ST / Commo'+
   'dore Amiga).',
   'Clone de HiSoft Devpac (Atari ST / Commo'+'dore Amiga).',
     'Klon von HiSoft Devpac (Atari ST / Commo'+'dore Amiga).'));
 WriteLn(ConOut);
 WriteLn(ConOut,T3('Usage : DEVPAC [options] [file.S ...]',
   'Syntaxe : DEVPAC [options] [fichier.S ..'+'.]',
   'Aufruf : DEVPAC [Optionen] [Datei.S ...]'));
 WriteLn(ConOut);
 WriteLn(ConOut,'  /ATARIST    '+T3('Atari ST mode: GenST, MonST, GEMDOS .PRG'+
   ' (default)','Mode Atari ST : GenST, MonST, .PRG GEMDO'+'S (defaut)',
   'Atari-ST-Modus: GenST, MonST, GEMDOS-.PR'+'G (Standard)'));
 WriteLn(ConOut,'  /AMIGA      '+T3('Amiga mode: GenAm, MonAm, Hunk executabl'+
   'e','Mode Amiga : GenAm, MonAm, executable Hu'+'nk',
   'Amiga-Modus: GenAm, MonAm, Hunk-Programm'));
 WriteLn(ConOut,'  /A          '+T3('assemble the file(s) at startup',
   'assemble le(s) fichier(s) au demarrage',
   'Datei(en) beim Start assemblieren'));
 WriteLn(ConOut,'  /X          '+T3('assemble then run the program',
   'assemble puis execute le programme','assemblieren und starten'));
 WriteLn(ConOut,'  /D          '+T3('assemble then debug (MonST/MonAm)',
   'assemble puis debogue (MonST/MonAm)','assemblieren und debuggen'));
 WriteLn(ConOut,'  /M          '+T3('start MonST/MonAm on the executable give'+
   'n','lance MonST/MonAm sur l''executable indi'+'que',
   'MonST/MonAm mit dem Programm starten'));
 WriteLn(ConOut,'  /B          '+T3('batch mode (no graphics): assemble, with'+
   ' /X run it','mode batch (sans graphisme) : assemble, '+'avec /X execute',
   'Batch-Modus (ohne Grafik): assemblieren,'+' mit /X starten'));
 WriteLn(ConOut,'  /EMUL:prg   '+T3('run a .PRG in the built-in emulator (no graphics; the remaining'+
   ' arguments form its command line)','execute un .PRG dans l''emulateur integre (sans graphisme ; les autres'+
   ' arguments forment sa ligne de commande)','ein .PRG im eingebauten Emulator starten (ohne Grafik)'));
 WriteLn(ConOut,'  /SHOW       '+T3('with /EMUL: display the program in the graphics window',
   'avec /EMUL: affiche le programme dans la fenetre graphique','mit /EMUL: Programm im Grafikfenster anzeigen'));
 WriteLn(ConOut,'  /TAIL:text  '+T3('with /EMUL: command line given to the program (may start with /)',
   'avec /EMUL: ligne de commande transmise au programme (peut commencer par /)','mit /EMUL: Kommandozeile des Programms'));
 WriteLn(ConOut,'  /SCR:file   '+T3('with /EMUL: write the 32000-byte logical screen at the end',
   'avec /EMUL: ecrit l''ecran logique (32000 octets) a la fin','mit /EMUL: logischen Bildschirm schreiben'));
 WriteLn(ConOut,'  /DUMP:a:n:f '+T3('with /EMUL: write n bytes of memory at hex address a to file f',
   'avec /EMUL: ecrit n octets de memoire a l''adresse hexa a dans le fichier f','mit /EMUL: Speicher in Datei schreiben'));
 WriteLn(ConOut,'  /TIME:s     '+T3('with /EMUL: maximum run time in seconds (default 60)',
   'avec /EMUL: duree maximale en secondes (defaut 60)','mit /EMUL: maximale Laufzeit in Sekunden'));
 WriteLn(ConOut,'  /L          '+T3('produce a listing file (.LST)',
   'produit un fichier de listing (.LST)','Listing-Datei (.LST) erzeugen'));
 WriteLn(ConOut,'  /S          '+T3('include the symbol table (debug) in the '+
   'executable','inclut la table des symboles (debug) dan'+'s l''executable',
   'Symboltabelle (Debug) im Programm'));
 WriteLn(ConOut,'  /O          '+T3('optimise branches (OPT O+)',
   'optimise les branchements (OPT O+)','Spruenge optimieren (OPT O+)'));
 WriteLn(ConOut,'  /OUT:file   '+T3('output file name',
   'nom du fichier de sortie','Name der Ausgabedatei'));
 WriteLn(ConOut,'  /INC:dir    '+T3('INCLUDE search directory',
   'repertoire de recherche des INCLUDE','Suchverzeichnis fuer INCLUDE'));
 WriteLn(ConOut,'  /DEF:n=v    '+T3('define the symbol n with the value v',
   'definit le symbole n avec la valeur v','Symbol n mit Wert v definieren'));
 WriteLn(ConOut,'  /NODISK     '+T3('assemble to memory only (no output file)',
   'assemble en memoire seulement (pas de fi'+'chier)',
   'nur im Speicher assemblieren'));
 WriteLn(ConOut,'  /FLA:file   '+T3('floppy image for drive A: (also /FLB: /F'+
   'LC: /FLD:; default DISKA.ST ...; a blank'+
   ' 720 KB disk is used and the file create'+'d on the first write)',
   'image de disquette du lecteur A: (aussi '+
   '/FLB: /FLC: /FLD: ; defaut DISKA.ST ... '+
   '; disquette vierge 720 Ko, fichier cree '+'a la premiere ecriture)',
   'Diskettenabbild fuer Laufwerk A: (auch /'+
   'FLB: /FLC: /FLD:; Standard DISKA.ST ...;'+
   ' leere 720-KB-Diskette, Datei wird beim '+'ersten Schreiben angelegt)'));
 WriteLn(ConOut,'  /NOGEM      '+T3('run programs without GEM (VDI/AES)',
   'execute sans GEM (VDI/AES)','ohne GEM (VDI/AES) starten'));
 WriteLn(ConOut,'  /OLDRC      '+T3('old return codes 0/1/2/3 (default: 0 OK,'+
   ' 5 warnings, 10 errors, 20 fatal)',
   'anciens codes retour 0/1/2/3 (defaut : 0'+
   ' OK, 5 avertissements, 10 erreurs, 20 fa'+'tal)',
   'alte Rueckgabecodes 0/1/2/3 (Standard: 0'+
   ' OK, 5 Warnungen, 10 Fehler, 20 fatal)'));
 WriteLn(ConOut);
 WriteLn(ConOut,T3('GEN.TTP style options (a command line us'+
   'ing them assembles without graphics):',
   'Options de style GEN.TTP (une ligne de c'+
     'ommande qui les utilise assemble sans gr'+'aphisme) :',
   'Optionen im GEN.TTP-Stil (eine Kommandoz'+
     'eile mit ihnen assembliert ohne Grafik):'));
 WriteLn(ConOut,'  -B          '+T3('no binary file','pas de fichier binaire',
   'keine Binaerdatei'));
 WriteLn(ConOut,'  -C          '+T3('case insensitive labels (+NOCASE)',
   'etiquettes insensibles a la casse (+NOCA'+'SE)',
   'Labels ohne Gross-/Kleinschreibung (+NOC'+'ASE)'));
 WriteLn(ConOut,'  -Esym=expr,sym2  '+
   T3('define symbols (value 1 if =expr omitted'+')',
   'definit des symboles (valeur 1 sans =exp'+'r)',
   'Symbole definieren (Wert 1 ohne =expr)'));
 WriteLn(ConOut,'  -Hfile      '+T3('pre-assembled header files (accepted, no'+
   't used)','fichiers d''en-tete pre-assembles (accep'+'tes, non utilises)',
   'vorassemblierte Header (akzeptiert, nich'+'t benutzt)'));
 WriteLn(ConOut,'  -Ipath      '+T3('include directory',
   'repertoire des INCLUDE','Include-Verzeichnis'));
 WriteLn(ConOut,'  -L[n]       '+T3('output format: -L1 GST, -L2 DRI, -L6 S-r'+
   'ecords, -L7 Lattice (all supported)',
   'format de sortie : -L1 GST, -L2 DRI, -L6'+
   ' S-records, -L7 Lattice (tous geres)',
   'Ausgabeformat: -L1 GST, -L2 DRI, -L6 S-R'+
   'ecords, -L7 Lattice (alle unterstuetzt)'));
 WriteLn(ConOut,'  -Ofile      '+T3('output file name',
   'nom du fichier de sortie','Name der Ausgabedatei'));
 WriteLn(ConOut,'  -Pfile      '+T3('listing file name (default source.LST)',
   'nom du listing (defaut source.LST)','Listing-Datei (Standard Quelle.LST)'));
 WriteLn(ConOut,'  -Q  -S  -Tn -Z  '+
   T3('pause at end, symbol table in listing, t'+'ab size, pass 1 listing',
   'pause a la fin, table des symboles au li'+
   'sting, tabulation, listing passe 1',
   'Pause am Ende, Symboltabelle im Listing,'+' Tabulator, Listing Pass 1'));
 WriteLn(ConOut,'  -Vopt  -Wfile  +OPTION  '+
   T3('OPT options, option file, long OPT name '+'(e.g. +DEBUG)',
   'options OPT, fichier d''options, nom lon'+'g OPT (ex. +DEBUG)',
   'OPT-Optionen, Optionsdatei, langer OPT-N'+'ame (z.B. +DEBUG)'));
 WriteLn(ConOut,'  '+T3('(the / forms above keep their historical'+
   ' meaning; -D -X -M -A are historical too'+')',
   '(les formes / ci-dessus gardent leur sen'+
   's historique ; -D -X -M -A aussi)',
   '(die /-Formen behalten ihre alte Bedeutu'+'ng; -D -X -M -A ebenfalls)'));
 WriteLn(ConOut,'  /?          '+T3('this help','cette aide','diese Hilfe'));
 WriteLn(ConOut);
 WriteLn(ConOut,T3('Language: French by default, LANGUAGE=EN'+
   ' for English, LANGUAGE=GR for German.',
   'Langue : francais par defaut, LANGUAGE=E'+
     'N pour l''anglais, LANGUAGE=GR pour l''a'+'llemand.',
   'Sprache: Franzoesisch als Standard, LANG'+
     'UAGE=EN fuer Englisch, LANGUAGE=GR fuer '+'Deutsch.'));
End;

Var
 GenMode    : Boolean;     { options de style GEN.TTP presentes }
 OldRc      : Boolean;     { /OLDRC : anciens codes retour 0/1/2/3 }
 PauseEnd   : Boolean;

Function IsGenOpt(Const A: String): Boolean;
Var C: Char;
Begin
 IsGenOpt:=False;
 If Length(A)<2 Then Exit;
 If A[1]='+' Then Begin IsGenOpt:=True;Exit;End;
 If A[1]<>'-' Then Exit;
 C:=UpCase(A[2]);
 If (C='H') And (Length(A)=2) Then Exit;
 IsGenOpt:=C In
   ['B','C','D','E','I','L','M','O','P','Q','S','T','V','W','X','Z','H'];
End;

Function IsOption(Const A: String): Boolean;
Var U: String;
Begin
 U:=Upper(A);
 If U='' Then Begin IsOption:=False;Exit;End;
 If IsGenOpt(A) Then Begin IsOption:=True;Exit;End;
 If (U[1]<>'/') And (U[1]<>'-') Then Begin IsOption:=False;Exit;End;
 U:=Copy(U,2,200);
 If (U<>'') And (U[1]='-') Then U:=Copy(U,2,200);
 IsOption:=(U='?') Or (U='H') Or (U='HELP') Or (U='ATARIST') Or (U='AMIGA') Or
   (U='A') Or
  (U='X') Or (U='D') Or (U='M') Or (U='B') Or (U='L') Or (U='S') Or (U='O') Or
  (U='NODISK') Or (U='NOGEM') Or (U='OLDRC') Or (Copy(U,1,4)='OUT:') Or
    (Copy(U,1,4)='INC:') Or
  (Copy(U,1,4)='DEF:') Or (U='EMUL') Or (Copy(U,1,5)='EMUL:') Or
  (U='SHOW') Or (Copy(U,1,5)='TAIL:') Or (Copy(U,1,4)='SCR:') Or (Copy(U,1,5)='DUMP:') Or (Copy(U,1,5)='TIME:') Or
  ((Copy(U,1,2)='FL') And (Length(U)>=5) And
    (U[3]>='A') And (U[3]<='D') And (U[4]=':'));
End;

Procedure AddCmdOpt(Const S: String);
Begin
 If CmdOpts<>'' Then CmdOpts:=CmdOpts+',';
 CmdOpts:=Copy(CmdOpts+S,1,250);
End;

Procedure AddCmdSym(Const S: String);
Begin
 If S='' Then Exit;
 If CmdSyms<>'' Then CmdSyms:=CmdSyms+',';
 CmdSyms:=Copy(CmdSyms+S,1,250);
End;

Procedure GenArg(Const A: String; Const NextArg: String; Var UsedNext:
  Boolean); Forward;

{ fichier d'options (-W) : un mot par element, separes par blancs/virgules }
Procedure ReadOptFile(Const Fn: String);
Var T: Text; L,Tk: String; I: Integer; Dummy: Boolean;
Begin
 Assign(T,Fn);
 {$I-}
 Reset(T);
 {$I+}
 If IOResult<>0 Then Begin
  WriteLn(ConOut,T3('Cannot open ','Impossible d''ouvrir ',
    'Kann nicht oeffnen: ')+Fn);
  Exit;
 End;
 While Not Eof(T) Do Begin
  ReadLn(T,L);
  L:=TrimS(L);
  Tk:='';
  For I:=1 To Length(L)+1 Do Begin
   If (I>Length(L)) Or (L[I]=' ') Or (L[I]=#9) Then Begin
    If Tk<>'' Then Begin
     If (Tk[1]='-') Or (Tk[1]='+') Then GenArg(Tk,'',Dummy)
     Else AddCmdOpt(Upper(Tk));
    End;
    Tk:='';
   End Else Tk:=Tk+L[I];
  End;
 End;
 Close(T);
End;

{ une option de style GEN.TTP : -B -C -Efoo=1 -Hfile -Ipath -L[n] -Ofile -Pfile
  -Q -S -Tn -Vopt -Wfile -Z +OPTION }
Procedure GenArg(Const A: String; Const NextArg: String; Var UsedNext: Boolean);
Var I: Integer; C: Char; Rest: String; V: Integer;
Begin
 UsedNext:=False;
 GenMode:=True;
 If A[1]='+' Then Begin AddCmdOpt(Upper(Copy(A,2,200)));Exit;End;
 I:=2;
 While I<=Length(A) Do Begin
  C:=UpCase(A[I]);
  Rest:=Copy(A,I+1,250);
  Case C Of
   'B': NoBinary:=True;
   'C': AddCmdOpt('NOCASE');
   'D': AddCmdOpt('DEBUG');
   'X': AddCmdOpt('XDEBUG');
   'M': Begin End;
   'Q': PauseEnd:=True;
   'S': AddCmdOpt('SYMTAB');
   'Z': AddCmdOpt('LIST1');
   'E','H','I','O','P','T','V','W': Begin
     If (Rest='') And (NextArg<>'') And (C<>'P') And (C<>'T') And Not
       IsOption(NextArg) Then Begin
      Rest:=NextArg;UsedNext:=True;
     End;
     Case C Of
      'E': AddCmdSym(Rest);
      'H': CmdHeaders:=Rest;
      'I': Begin If OptIncList<>'' Then
        OptIncList:=OptIncList+';';OptIncList:=Copy(OptIncList+Rest,1,250);End;
      'O': OptOutName:=Rest;
      'P': Begin OptListing:=True;If Rest<>'' Then OptListName:=Rest;End;
      'T': Begin V:=ToInt(Rest);If (V>=1) And (V<=64) Then OptTabSize:=V;End;
      'V': Begin
            AddCmdOpt(Upper(Rest));
           End;
      'W': ReadOptFile(Rest);
     End;
     Exit;
    End;
   'L': Begin
     If (Rest<>'') And (Rest[1]>='0') And (Rest[1]<='9') Then Begin
      OptFormatSel:=Ord(Rest[1])-48;
      Inc(I);
     End Else OptFormatSel:=1;
    End;
  End;
  Inc(I);
 End;
End;

Procedure ParseCommandLine;
Var I: Integer; A,U: String; HelpWanted,Used,BadCmd: Boolean;
Begin
 BadCmd:=False;HelpWanted:=False;NQueue:=0;StartAction:=' ';NPre:=0;
 EmulPrg:='';EmulScr:='';EmulDump:='';EmulTime:=60;EmulShow:=False;EmulTail:='';
 CmdOpts:='';CmdSyms:='';CmdHeaders:='';NoBinary:=False;OptFormatSel:=0;
   OptIncList:='';
 GenMode:=False;PauseEnd:=False;
 I:=0;
 While I<ParamCount Do Begin
  Inc(I);
  A:=ParamStr(I);
  If IsGenOpt(A) Then Begin
   If I<ParamCount Then GenArg(A,ParamStr(I+1),Used) Else GenArg(A,'',Used);
   If Used Then Inc(I);
  End Else If IsOption(A) Then Begin
   U:=Upper(Copy(A,2,200));
   If (U<>'') And (U[1]='-') Then U:=Copy(U,2,200);
   If (U='?') Or (U='H') Or (U='HELP') Then HelpWanted:=True
   Else If U='ATARIST' Then AmigaMode:=False
   Else If U='AMIGA' Then AmigaMode:=True
   Else If U='A' Then Begin If A[1]='-' Then BadCmd:=True Else
     StartAction:='A';End
   Else If U='X' Then StartAction:='X'
   Else If Copy(U,1,4)='EMUL' Then Begin
    { /EMUL:prog.prg ou /EMUL prog.prg : execute un programme dans l'emulateur
      integre, sans interface graphique }
    If Copy(U,1,5)='EMUL:' Then EmulPrg:=Copy(A,Pos(':',A)+1,200)
    Else If (U='EMUL') And (I<ParamCount) Then Begin Inc(I);EmulPrg:=ParamStr(I);End;
    If EmulPrg<>'' Then Begin StartAction:='E';BatchMode:=True;End;
   End
   Else If U='SHOW' Then EmulShow:=True
   Else If Copy(U,1,5)='TAIL:' Then EmulTail:=Copy(A,Pos(':',A)+1,200)
   Else If Copy(U,1,4)='SCR:' Then EmulScr:=Copy(A,Pos(':',A)+1,200)
   Else If Copy(U,1,5)='DUMP:' Then EmulDump:=Copy(A,Pos(':',A)+1,300)
   Else If Copy(U,1,5)='TIME:' Then EmulTime:=ToInt(Copy(A,Pos(':',A)+1,20))
   Else If U='D' Then StartAction:='D'
   Else If U='M' Then StartAction:='M'
   Else If U='B' Then BatchMode:=True
   Else If U='L' Then OptListing:=True
   Else If U='S' Then OptDebug:=True
   Else If U='O' Then OptOptimize:=True
   Else If U='NODISK' Then OptToDisk:=False
   Else If U='NOGEM' Then OptRunGem:=False
   Else If U='OLDRC' Then OldRc:=True
   Else If Copy(U,1,4)='OUT:' Then OptOutName:=Copy(A,Pos(':',A)+1,200)
   Else If Copy(U,1,4)='INC:' Then OptIncPath:=Copy(A,Pos(':',A)+1,200)
   Else If (Copy(U,1,2)='FL') And (Length(U)>=5) And (U[3]>='A') And
     (U[3]<='D') And (U[4]=':') Then
    FlpImage[Ord(U[3])-65]:=Copy(A,6,200)
   Else If Copy(U,1,4)='DEF:' Then Begin
    If NPre<10 Then Begin Inc(NPre);PreDefs[NPre]:=Copy(A,Pos(':',A)+1,80);End;
    AddCmdSym(Copy(A,Pos(':',A)+1,80));
   End;
  End Else If (Length(A)>1) And (A[1]='-') Then BadCmd:=True
  Else If NQueue<20 Then Begin
   Inc(NQueue);FileQueue[NQueue]:=A;
  End;
 End;
 If BadCmd Then Begin
  WriteLn(ConOut,'Invalid command line - see manual');
  Flush(ConOut);
  If OldRc Then Halt(2) Else Halt(100);
 End;
 If EmulShow And (StartAction='E') Then BatchMode:=False;
 { une ligne de commande de style GEN : assemblage sans interface graphique }
 If GenMode And (StartAction=' ') Then BatchMode:=True;
 If HelpWanted Then Begin
  ShowHelpLine;
  Flush(ConOut);
  Halt(0);
 End;
End;

{ Mode batch : assemble (et execute) sans interface graphique.
  Codes retour (manuel p.65) : 0 OK, 5 avertissement(s), 10 erreur(s), 20
    erreur fatale,
  100 echec d'initialisation (aucun fichier source) ; /OLDRC : anciens codes
    0/1/2/3. }
{ ecrit une zone de memoire dans un fichier (/SCR et /DUMP) }
Procedure EmulDumpMem(Addr,Len: LongInt; Const Fn: String);
Var F: File; Buf: Array[0..4095] Of Byte; N,K,I: LongInt;
Begin
 If (Addr<0) Or (Len<=0) Or (Addr+Len>MemSize) Then Exit;
 Assign(F,Fn);
 {$I-}Rewrite(F,1);{$I+}
 If IOResult<>0 Then Exit;
 K:=0;
 While K<Len Do Begin
  N:=Len-K;If N>4096 Then N:=4096;
  For I:=0 To N-1 Do Buf[I]:=Rd8(Addr+K+I);
  BlockWrite(F,Buf,N);
  Inc(K,N);
 End;
 Close(F);
End;

Procedure EmulDumps;
Var P1,P2,Ad,Ln,Cd: LongInt; A,L,Fn: String;
Begin
 If EmulScr<>'' Then EmulDumpMem(ScrBase,SCR_BYTES,EmulScr);
 If EmulDump<>'' Then Begin
  P1:=Pos(':',EmulDump);
  If P1>0 Then Begin
   A:=Copy(EmulDump,1,P1-1);Fn:=Copy(EmulDump,P1+1,300);
   P2:=Pos(':',Fn);
   If P2>0 Then Begin
    L:=Copy(Fn,1,P2-1);Fn:=Copy(Fn,P2+1,300);
    Ad:=0;
    For Cd:=1 To Length(A) Do Ad:=Ad*16+Pos(UpCase(A[Cd]),'0123456789ABCDEF')-1;
    Val(L,Ln,Cd);
    EmulDumpMem(Ad,Ln,Fn);
   End;
  End;
 End;
End;

{ execute un programme dans l'emulateur, sans interface graphique ; retourne le
  code de sortie (3 si le programme ne peut pas etre charge ou plante) }
Function BatchEmulate(Const Name,Tail: String): Integer;
Var Rc: Integer; H0,M0,S0,C0,H1,M1,S1,C1: Word; T0,T1: LongInt; Timeout: Boolean;
Begin
 Rc:=0;
 If LoadProgram(Name,Tail,OptRunGem) Then Begin
  EmuVisible:=False;MonActive:=False;
  If Emu_GEM Then GemBoot;
  GetTime(H0,M0,S0,C0);T0:=LongInt(H0)*3600+M0*60+S0;
  Timeout:=False;
  While (StopReason=STOP_NONE) Or (StopReason=STOP_YIELD) Do Begin
   RunCpu(100000);
   If StopReason=STOP_YIELD Then GemDispatch;
   If EmulTime>0 Then Begin
    GetTime(H1,M1,S1,C1);T1:=LongInt(H1)*3600+M1*60+S1;
    If T1<T0 Then T1:=T1+86400;
    If T1-T0>=EmulTime Then Begin Timeout:=True;Break;End;
   End;
  End;
  WriteLn(ConOut);
  If Timeout Then Begin WriteLn(ConOut,'Timeout');Rc:=4;End
  Else If StopReason=STOP_EXIT Then Rc:=ExitCode And $FF
  Else Begin WriteLn(ConOut,StopMsg);Rc:=3;End;
  If UnknownCall<>'' Then WriteLn(ConOut,'[',UnknownCall,']');
  EmulDumps;
 End Else Begin WriteLn(ConOut,'Cannot load ',Name);Rc:=3;End;
 BatchEmulate:=Rc;
End;

Function BatchRun: Integer;
Var Arr: PLineArr; Cnt: LongInt; I: Integer; Rc,R1: Integer; Name,Src: String;
Begin
 Rc:=0;
 If StartAction='E' Then Begin
  InitMemory(ST_MEMKB);
  For I:=1 To NQueue Do Begin
   If EmulTail<>'' Then EmulTail:=EmulTail+' ';
   EmulTail:=EmulTail+FileQueue[I];
  End;
  BatchRun:=BatchEmulate(EmulPrg,EmulTail);
  Exit;
 End;
 If NQueue=0 Then Begin
  WriteLn(ConOut,T3('No source file specified (DEVPAC /? for '+'help)',
    'Aucun fichier source indique (DEVPAC /? '+'pour l''aide)',
    'Keine Quelldatei angegeben (DEVPAC /? fu'+'er Hilfe)'));
  If OldRc Then BatchRun:=2 Else BatchRun:=100;
  Exit;
 End;
 InitMemory(ST_MEMKB);
 For I:=1 To NQueue Do Begin
  Name:=FileQueue[I];
  If (Not FileExists(Name)) And FileExists(Name+'.S') Then Name:=Name+'.S';
  If (Not FileExists(Name)) And FileExists(Name+'.s') Then Name:=Name+'.s';
  LongLines:=0;
  If Not LoadLinesBig(Name,Arr,Cnt) Then Begin
   WriteLn(ConOut,T3('file not found: ','Impossible d''ouvrir ',
     'Kann nicht oeffnen: ')+Name);
   If OldRc Then R1:=2 Else R1:=20;
   If R1>Rc Then Rc:=R1;
   Continue;
  End;
  AsmFromEditor:=False;
  HaveOutput:=False;
  If Not AssembleSource(Name,Arr,Cnt) Then Begin
   If OldRc Then R1:=1 Else If AsmFatal Then R1:=20 Else R1:=10;
   If R1>Rc Then Rc:=R1;
  End Else Begin
   If (AsmWarns>0) And Not OldRc And (Rc<5) Then Rc:=5;
   If StartAction='X' Then Begin
    Rc:=BatchEmulate(OutPathFinal,'');
   End;
  End;
  CleanTemp;
  FreeLinesBig(Arr,Cnt);
 End;
 If PauseEnd Then Begin
  WriteLn(ConOut,T3('Press Return','Appuyez sur Entree',
    'Eingabetaste druecken'));
  Flush(ConOut);
  If Not Eof(ConIn) Then ReadLn(ConIn);
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
 MenuOpen:=0;MenuHi:=0;SubOpen:=0;SubHi:=0;RunDirMode:=1;
 StatusMsg:='';HiOn:=False;MouseHid:=False;UndelOk:=False;UndelEnd:=False;
 ESetFont(3);ELayoutKeep:=0;DrawingAct:=True;ToolsDefaults;AcDefaults;RunPause:=
   True;LastLayout:=0;ShellCmd:='';
 ErrCur:=0;CfgFile:='';
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

Var I,K,NCr: Integer; Nm: String; StartCr: Array[1..EMAXWIN] Of String[120];
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
 CfgOutName:=OptOutName;CfgListName:=OptListName;
 AcFromOpts;
 InitializeGraphics;
 BuildFont;
 InitMemory(ST_MEMKB);
 ScrBase:=(MemSize-SCR_BYTES) And $FFFF00;DrawBase:=ScrBase;
 EdInit;
 EWinInit;
 If StartAction='E' Then Begin
  { /EMUL /SHOW : le programme s'affiche dans la fenetre graphique }
  For I:=1 To NQueue Do Begin
   If EmulTail<>'' Then EmulTail:=EmulTail+' ';
   EmulTail:=EmulTail+FileQueue[I];
  End;
  RunPause:=False;
  RunProgramGUI(EmulPrg,EmulTail);
  EmulDumps;
  HideMouse;
  DevCloseAll;
  CloseGraph;
  Halt(0);
 End;
 NCr:=0;
 If NQueue>0 Then Begin
  If (StartAction<>'M') Then Begin
   If StartAction=' ' Then Begin
    { jusqu'a 7 fichiers : chacun dans sa fenetre }
    K:=0;
    For I:=1 To NQueue Do
     If I<=EMAXWIN Then Begin
      Nm:=FileQueue[I];
      If (Not FileExists(Nm)) And FileExists(Nm+'.S') Then Nm:=Nm+'.S';
      If FileExists(Nm) Then Begin
       If (K>0) Or Not WinIsBlank Then EWinAlloc;
       If EdLoadFile(Nm,False) Then Inc(K);
      End Else Begin Inc(NCr);StartCr[NCr]:=Nm;End;
     End;
   End Else Begin
    If FileExists(FileQueue[1]) Then EdLoadFile(FileQueue[1],False)
    Else If FileExists(FileQueue[1]+'.S') Then
      EdLoadFile(FileQueue[1]+'.S',False)
    Else EdFile:=FileQueue[1];
   End;
  End;
 End;
 If EActW>0 Then If ENWin>1 Then EArrange(1);
 If MouseDriverFound Then ShowMouse;
 DrawAll;
 { fichiers absents de la ligne de commande : proposer de les creer }
 For I:=1 To NCr Do LoadNamed(StartCr[I]);
 StartupActions;
 MainLoop;
 HideMouse;
 DevCloseAll;
 CloseGraph;
END.
