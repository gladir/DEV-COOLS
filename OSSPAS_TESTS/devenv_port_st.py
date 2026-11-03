#!/usr/bin/env python3
"""Porte dans DEVENV.PAS l'emulateur Atari ST / GEM de DEVPAC.PAS (processeur, TOS, VDI, AES, ligne A, console VT52,
clavier, souris, disquettes) sous forme d'un onglet d'emulation : identifiants prefixes St_, aucune unite ni fichier
supplementaire.

  python3 OSSPAS_TESTS/devenv_port_st.py DEVPAC.PAS DEVENV.PAS

Seules les declarations de DEVPAC.PAS atteignables depuis les points d'entree sont reprises (fermeture transitive) ;
les routines qui dessinent sur l'ecran hote (BlitScreen, curseur, son) sont remplacees : l'emulation tourne dans un
fil d'execution, le dessin est fait par DEVENV (St_TabDraw) a partir de la memoire video emulee.
Le noyau M68K_* d'origine, partage par Amiga et -C68000, n'est pas touche. Relancer le script remplace le bloc.
"""
import re,sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pascal_prefix
BEGIN_MARK='{ ===== DEBUT EMULATEUR ATARI ST / GEM (St_, porte de DEVPAC.PAS par devenv_port_st.py) ===== }'
END_MARK='{ ===== FIN EMULATEUR ATARI ST / GEM ===== }'
ROOTS=['LoadProgram','DoTrap','GemDispatch','GemBoot','GemReset','GemIdle','PollInput','RunCpu','Vdi','Aes','InitMemory',
       'KQPush','KQPop','KQEmpty','ConClear','ConPut','NewProc','CheckFonts','ScanOfChar','CpuReset','SetSR','Hex8','Rd8',
       'RepaintAll','CloseAllFiles','AssembleSource_NEVER']
FORWARDS=r"""
Procedure BlitScreen(Full: Boolean); Forward;
Procedure CursorDraw(X,Y: LongInt); Forward;
Procedure CursorErase; Forward;
Procedure ShowMouse; Forward;
Procedure HideMouse; Forward;
Procedure PollKeys; Forward;
Procedure Sound(Hz: Word); Forward;
Procedure NoSound; Forward;
Procedure SoundOut(Freq: LongInt; Ms: Integer); Forward;
Procedure SoundBell; Forward;
Procedure GetMouseState(Var X,Y,B: LongInt); Forward;
Function DosFileSel(Const Title: String; Var Dr,Dir,Msk,Sel: String): Boolean; Forward;
"""
OVERRIDES=r"""
{ ---- routines graphiques de l'hote remplacees : l'emulation tourne dans son propre fil, le dessin est fait par DEVENV ---- }
Procedure BlitScreen(Full: Boolean);
Begin
 ScrDirtyLo := 400; ScrDirtyHi := -1;
End;
Procedure CursorDraw(X,Y: LongInt);
Begin
End;
Procedure CursorErase;
Begin
End;
Procedure ShowMouse;
Begin
End;
Procedure HideMouse;
Begin
End;
Procedure Sound(Hz: Word);
Begin
End;
Procedure SoundOut(Freq: LongInt; Ms: Integer);      { DEVENV n'a pas de sortie sonore : l'emulation est muette }
Begin
End;
Procedure SoundBell;
Begin
End;
Procedure NoSound;
Begin
End;
Var
 StMX, StMY, StMB: LongInt;        { souris : coordonnees relatives a l'ecran emule (ecrites par DEVENV) }
 StEvQ: Array[0..63] Of LongInt;    { touches : file a un producteur (DEVENV) et un consommateur (fil de l'emulation) }
 StEvH, StEvT: Integer;
 StMQX, StMQY, StMQB: Array[0..63] Of LongInt;   { changements d'etat des boutons : un clic bref n'est jamais perdu }
 StMQH, StMQT: Integer;
 StMBRet: LongInt;                 { etat des boutons rendu a la derniere lecture }
Procedure GetMouseState(Var X,Y,B: LongInt);
Begin
 If StMQH <> StMQT Then Begin
  X := StMQX[StMQH]; Y := StMQY[StMQH] + EMU_Y0; StMBRet := StMQB[StMQH];
  StMQH := (StMQH + 1) And 63;
 End Else Begin
  X := StMX; Y := StMY + EMU_Y0;
 End;
 B := StMBRet;
End;
{ selecteur de fichiers (fsel_input) : meme comportement que celui de DEVPAC.PAS, mais dessine dans l'ecran emule
  (comme form_alert) et pilote par la file de touches et la souris de l'onglet, au lieu de l'ecran de l'hote }
Function DosFileSel(Const Title: String; Var Dr,Dir,Msk,Sel: String): Boolean;
Const FW = 512; FH = 320;
Var FTop, FCur, FX0, FY0, LX, LY, LW, FRow, FFoc, FNd, FQ, FLastIdx, FDblT: LongInt;
  FDone, FOk, FRedraw, FDrag, FPrevDown: Boolean;
  FK, FAsc, FScan, FI: LongInt; FV: String; FSv: TScrSave;
 Function DirStr: String;
 Begin
  FV:=DosVirt(Dir);
  If FV='' Then DirStr:=Dr+':\' Else DirStr:=Dr+':\'+Upper(FV)+'\';
 End;
 Procedure Rescan;
 Begin
  FselScan(Dir,Msk);FTop:=1;FCur:=0;
  FNd:=0;
  While (FNd<FSN) And (FSList[FNd+1][1]='\') Do Inc(FNd);
 End;
 Procedure Enter(Const D: String);
 Begin
  If D='\..' Then Dir:='\'+DosVirt(Dir+'\..') Else
    Dir:='\'+DosVirt(Dir+'\'+Copy(D,2,40));
  Sel:='';Rescan;
 End;
 Function ThumbH: LongInt;
 Var Tr,H: LongInt;
 Begin
  Tr:=FS_ROWS*16-32-1;
  If FSN<=FS_ROWS Then ThumbH:=Tr
  Else Begin H:=(Tr*FS_ROWS) Div FSN;If H<12 Then H:=12;ThumbH:=H;End;
 End;
 Function ThumbTop: LongInt;
 Var Tr: LongInt;
 Begin
  Tr:=FS_ROWS*16-32-1;
  If FSN<=FS_ROWS Then ThumbTop:=0 Else ThumbTop:=((FTop-1)*(Tr-ThumbH)) Div (FSN-FS_ROWS);
 End;
 Procedure FBtn(X1,Y1,X2,Y2: LongInt; Const Cap: String; Def: Boolean);
 Begin
  OFill(X1,Y1,X2,Y2,0,0);
  If Def Then OBorder(X1,Y1,X2-X1+1,Y2-Y1+1,3,1) Else OBorder(X1,Y1,X2-X1+1,Y2-Y1+1,1,1);
  OText((X1+X2+1-Length(Cap)*8) Div 2,Y1+3,Cap,16,1,False);
 End;
 Procedure DrawFS;
 Var R,Idx,Y,Tt,Th: LongInt; S: String;
 Begin
  OSetup;SetClip(0,0,SW-1,SH-1);
  OFill(FX0+4,FY0+4,FX0+FW+3,FY0+FH+3,7,1);
  OFill(FX0,FY0,FX0+FW-1,FY0+FH-1,0,0);
  OBorder(FX0,FY0,FW,FH,3,1);OBorder(FX0+4,FY0+4,FW-8,FH-8,1,1);
  OText(FX0+16,FY0+10,Title,16,1,False);
  OText(FX0+16,FY0+30,T3('Directory: ','Repertoire : ','Verzeichnis: ')+Copy(DirStr+Msk,1,48),16,1,False);
  LX:=FX0+16;LY:=FY0+54;LW:=50*8;
  OFill(LX,LY,LX+LW,LY+FS_ROWS*16+2,0,0);
  OBorder(LX,LY,LW+1,FS_ROWS*16+3,1,1);
  For R:=0 To FS_ROWS-1 Do Begin
   Idx:=FTop+R;
   If Idx<=FSN Then Begin
    Y:=LY+2+R*16;
    S:=FSList[Idx];
    If Idx=FCur Then Begin
     OFill(LX+1,Y,LX+LW-1,Y+15,7,1);
     OText(LX+8,Y,S,16,0,False);
    End Else OText(LX+8,Y,S,16,1,False);
   End;
  End;
  FBtn(LX+LW+8,LY,LX+LW+8+16,LY+16,Chr(1),False);
  FBtn(LX+LW+8,LY+FS_ROWS*16-14,LX+LW+8+16,LY+FS_ROWS*16+2,Chr(2),False);
  OFill(LX+LW+8,LY+17,LX+LW+8+16,LY+FS_ROWS*16-15,2,1);
  OBorder(LX+LW+8,LY+17,17,FS_ROWS*16-31,1,1);
  Th:=ThumbH;Tt:=LY+17+ThumbTop;
  OFill(LX+LW+8,Tt,LX+LW+8+16,Tt+Th,0,0);
  OBorder(LX+LW+8,Tt,17,Th+1,1,1);
  OText(LX,LY+FS_ROWS*16+10,T3('Selection: ','Selection : ','Auswahl: '),16,1,False);
  S:=Sel;
  OText(LX+88,LY+FS_ROWS*16+10,S,16,1,False);
  If FFoc=1 Then OText(LX+88+Length(S)*8,LY+FS_ROWS*16+10,'_',16,1,False);
  FBtn(LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56,'OK',True);
  FBtn(LX+16+100,LY+FS_ROWS*16+36,LX+16+100+80,LY+FS_ROWS*16+56,T3('Cancel','Annuler','Abbruch'),False);
 End;
 Procedure Accept;
 Var Q: LongInt; N2: String;
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
  FOk:=True;FDone:=True;
 End;
Begin
 DosFileSel:=False;
 FX0:=(SW-FW) Div 2;FY0:=(SH-FH) Div 2;
 ScrSave(FX0-2,FY0-2,FX0+FW+6,FY0+FH+6,FSv);
 Rescan;
 FFoc:=1;FDone:=False;FOk:=False;FLastIdx:=0;FDblT:=0;FDrag:=False;FPrevDown:=True;
 DrawFS;
 Inc(ModalLevel);
 While (Not FDone) And (Not UserBreak) Do Begin
  GemIdle;
  FRedraw:=False;
  While (Not KQEmpty) And (Not FDone) Do Begin
   FK:=KQPop;FAsc:=FK And $FF;FScan:=(FK Shr 16) And $FF;
   If FAsc=13 Then Begin
    If (FCur>0) And (Sel='') Then Sel:=FSList[FCur];
    If (Sel<>'') And (Sel[1]='\') Then Enter(Sel) Else Accept;
    FRedraw:=True;
   End Else If (FAsc=27) Or ((FAsc=127) And (FScan=83) And False) Then FDone:=True
   Else If FAsc=0 Then Begin
    Case FScan Of
     72: If FCur>1 Then Begin Dec(FCur);Sel:=FSList[FCur];FRedraw:=True;End
         Else If FCur=0 Then If FSN>0 Then Begin FCur:=1;Sel:=FSList[1];FRedraw:=True;End;
     80: If FCur<FSN Then Begin Inc(FCur);Sel:=FSList[FCur];FRedraw:=True;End;
     73: Begin FCur:=Max2(1,FCur-FS_ROWS);If FSN>0 Then Sel:=FSList[FCur];FRedraw:=True;End;
     81: Begin FCur:=Min2(FSN,FCur+FS_ROWS);If FSN>0 Then Sel:=FSList[FCur];FRedraw:=True;End;
    End;
   End Else If FAsc=8 Then Begin
    If Length(Sel)>0 Then Begin Dec(Sel[0]);FCur:=0;FRedraw:=True;End;
   End Else If (FAsc>=32) And (FAsc<>127) Then Begin
    If Length(Sel)<40 Then Begin Sel:=Sel+Upcase(Chr(FAsc));FCur:=0;FRedraw:=True;End;
   End;
   If (FCur>0) And (FCur<FTop) Then FTop:=FCur;
   If (FCur>=FTop+FS_ROWS) Then FTop:=FCur-FS_ROWS+1;
  End;
  If (GMouseB And 1)=0 Then Begin FDrag:=False;FPrevDown:=False;End
  Else If FDrag Then Begin
   If FSN>FS_ROWS Then Begin
    FI:=1+((GMouseY-LY-17-ThumbH Div 2)*(FSN-FS_ROWS)) Div (FS_ROWS*16-32-1-ThumbH);
    FTop:=Clamp(FI,1,FSN-FS_ROWS+1);FRedraw:=True;
   End;
  End Else If Not FPrevDown Then Begin
   FPrevDown:=True;
   LX:=FX0+16;LY:=FY0+54;LW:=50*8;
   If InBox(GMouseX,GMouseY,LX,LY,LX+LW,LY+FS_ROWS*16+2) Then Begin
    FRow:=(GMouseY-LY-2) Div 16;
    FI:=FTop+FRow;
    If (FI>=1) And (FI<=FSN) Then Begin
     FK:=MsNow;
     If (FI=FLastIdx) And (FK-FDblT<500) And (FK>=FDblT) Then Begin
      Sel:=FSList[FI];
      If Sel[1]='\' Then Enter(Sel) Else Accept;
     End Else Begin FCur:=FI;Sel:=FSList[FI];End;
     FLastIdx:=FI;FDblT:=FK;
     FRedraw:=True;
    End;
   End Else If InBox(GMouseX,GMouseY,LX+LW+8,LY,LX+LW+24,LY+16) Then Begin
    If FTop>1 Then Dec(FTop);FRedraw:=True;
   End Else If InBox(GMouseX,GMouseY,LX+LW+8,LY+FS_ROWS*16-14,LX+LW+24,LY+FS_ROWS*16+2) Then Begin
    If FTop+FS_ROWS<=FSN Then Inc(FTop);FRedraw:=True;
   End Else If InBox(GMouseX,GMouseY,LX+LW+8,LY+17,LX+LW+24,LY+FS_ROWS*16-15) Then Begin
    If (GMouseY>=LY+17+ThumbTop) And (GMouseY<=LY+17+ThumbTop+ThumbH) Then FDrag:=True
    Else If GMouseY<LY+17+ThumbTop Then FTop:=Max2(1,FTop-FS_ROWS)
    Else FTop:=Max2(1,Min2(FSN-FS_ROWS+1,FTop+FS_ROWS));
    FRedraw:=True;
   End Else If InBox(GMouseX,GMouseY,LX+16,LY+FS_ROWS*16+36,LX+16+80,LY+FS_ROWS*16+56) Then Begin
    Accept;FRedraw:=True;
   End Else If InBox(GMouseX,GMouseY,LX+16+100,LY+FS_ROWS*16+36,LX+16+180,LY+FS_ROWS*16+56) Then FDone:=True;
  End;
  If FRedraw And (Not FDone) Then DrawFS;
 End;
 Dec(ModalLevel);
 ScrRestore(FSv);
 DosFileSel:=FOk;
End;
Procedure PollKeys;
Begin
 TickSysVars;
 SoundTick;
 IkDrain;
 While StEvH <> StEvT Do Begin       { touches deposees par DEVENV }
  KQPush(StEvQ[StEvH]);
  StEvH := (StEvH + 1) And 63;
 End;
End;
"""
def gem_closure(src, region, provided, roots, extra_exclude=()):
    """Retourne le texte (dans l'ordre du source) des declarations de DEVPAC.PAS necessaires aux points d'entree `roots`,
    sans celles du noyau 68000 (region), ni celles fournies par ailleurs (provided : noms)."""
    U=pascal_prefix.units(src)
    ra=src.index(region[:200]); rb=ra+len(region)
    byname={}
    for k,u in enumerate(U):
        for nm in u[0]:
            if nm: byname.setdefault(nm.lower(),[]).append(k)
    prov={p.lower() for p in provided}|{p.lower() for p in extra_exclude}
    def inregion(k): return ra<=U[k][4]<rb
    need=set(); stack=[]
    for r in roots:
        stack+= [k for k in byname.get(r.lower(),[]) if not inregion(k)]
    while stack:
        k=stack.pop()
        if k in need or inregion(k): continue
        if any(n and n.lower() in prov for n in U[k][0]): continue
        need.add(k)
        for idn in U[k][3]:
            if idn.lower() in prov: continue
            for k2 in byname.get(idn.lower(),[]):
                if k2 not in need and not inregion(k2): stack.append(k2)
    sel=sorted(need)
    # regroupe en conservant l'ordre : const/type/var sous leur mot-cle
    out=[];sec=None
    for k in sel:
        names,kind,txt,ids,pos=U[k]
        if kind in('const','type','var'):
            if sec!=kind: out.append(kind.capitalize()); sec=kind
            out.append(' '+txt)
        else:
            sec=None; out.append(txt)
    return '\n'.join(out), [U[k][0][0] for k in sel]


GLUE=r"""
{ ---- onglet Atari ST : fil d'execution de l'emulateur, dessin dans le panneau, clavier et souris ----
  L'emulation (processeur, TOS, VDI, AES) tourne dans son propre fil : un appel AES bloquant (evnt_multi, form_do,
  menus...) attend dans ce fil sans geler DEVENV. Le fil ne s'execute que tant que l'onglet est affiche et actif
  (TabTick l'appelle a chaque tour de la boucle de DEVENV). Un seul onglet Atari ST est actif a la fois. }
Var
 StThread: TThreadID;
 StQuit, StPaused, StDone, StRunning, StShown, StFirst, StTrace: Boolean;
 StShadow: Array[0..31999] Of Byte;
 StCurX, StCurY: Integer;
 StStart, StTickAt, StMaxSteps, StTitleAt, StDrawAt, StCurSh: LongInt;

Procedure StKeyPut(K: LongInt);
Begin
 If ((StEvT + 1) And 63) <> StEvH Then Begin
  StEvQ[StEvT] := K;
  StEvT := (StEvT + 1) And 63;
 End;
End;

Function StWorker(P: Pointer): PtrInt;
Var Nxt: String;
Begin
 StWorker := 0;
 While Not StQuit Do Begin
  If StPaused Or (MsNow - StTickAt > 400) Or (MsNow < StTickAt) Then Delay(10)
  Else If (StopReason = STOP_NONE) Or (StopReason = STOP_YIELD) Then Begin
   RunCpu(30000);
   If StopReason = STOP_YIELD Then GemDispatch;
   PollInput;
   If (StMaxSteps > 0) And (InstrCount > StMaxSteps) And (StopReason = STOP_NONE) Then StopReason := STOP_USER;
   If UserBreak Then StopReason := STOP_USER;
  End Else Begin
   Nxt := ShelNext;
   If (Nxt <> '') And (StopReason = STOP_EXIT) Then Begin
    { shel_write / Pexec : le programme suivant remplace le courant (meme comportement que RunProgramGUI) }
    CloseAllFiles;
    ShelNext := '';
    If LoadProgram(Nxt, '', OptRunGem) Then Begin
     ConClear;
     If Emu_GEM Then GemBoot;
     StopReason := STOP_NONE;
    End Else StDone := True;
   End Else Begin StDone := True; Delay(20); End;
  End;
 End;
End;

Procedure TabStop;
Begin
 If StRunning Then Begin
  StQuit := True;
  UserBreak := True;
  WaitForThreadTerminate(StThread, 3000);
  StRunning := False;
  CloseAllFiles;
 End;
End;

Procedure TabClose;
Begin
 TabStop;
 StShown := False;
End;

Function TabStart(Var P: TEmulatorPanel; Const Prg, Tail: String): Boolean;
Begin
 TabStart := False;
 TabClose;
 P.Cols := 80; P.Rows := 25; P.CharW := 8; P.CharH := 16;      { zone de clic du panneau : EmuPanel_HitTest (640 x 400 points) }
 StQuit := False; StPaused := False; StDone := False; StFirst := True; StCurX := -100; StCurY := -100; StCurSh := 0; StTitleAt := 0; StDrawAt := 0;
 StMX := 0; StMY := 0; StMB := 0; StMBRet := 0; StMQH := 0; StMQT := 0; StEvH := 0; StEvT := 0; StMaxSteps := 0; StTrace := GetEnv('DEVENV_EMUTRACE') <> '';
 If GetEnv('DEVENV_EMUSTEPS') <> '' Then Val(GetEnv('DEVENV_EMUSTEPS'), StMaxSteps, StMaxSteps);
 BatchMode := False; GfxOn := True; AmigaMode := False; Lang := 1;
 OptRunGem := True; OptAccs := True; MonActive := False; EmuVisible := True;
 InitMemory(ST_MEMKB);
 ScrBase := (MemSize - SCR_BYTES) And $FFFF00; DrawBase := ScrBase;
 CheckFonts;
 If Not LoadProgram(Prg, Tail, GetEnv('DEVENV_EMUGEM') <> '0') Then Exit;      { DEVENV_EMUGEM=0 : sans GEM (tests) }
 ConClear;
 UserBreak := False; ShelNext := '';
 If Emu_GEM Then GemBoot;
 StopReason := STOP_NONE;
 FillChar(StShadow, SizeOf(StShadow), 0);
 StRunning := True; StShown := True;
 StStart := MsNow; StTickAt := MsNow;
 StThread := BeginThread(TThreadFunc(@StWorker), Nil);
 TabStart := True;
End;

{ dessin de l'ecran emule dans le panneau (octets modifies seulement ; tout si Full) et du curseur de souris.
  Le curseur n'est efface et redessine que s'il bouge, change de forme ou si un octet qu'il couvre change : sinon
  l'affichage de l'hote (qui peut etre presente a tout moment) le montrerait par intermittence. }
Function TabDraw(Var P: TEmulatorPanel; Full: Boolean): Boolean;
Var Y, XB, GX, GY, R, C: Integer; B, O: Byte; A: LongInt; MXd, MYd, Sig: LongInt; Show, CurDirty, Any: Boolean;
 Procedure PutByte(XB, Y: Integer; V: Byte);
 Var Bit: Integer;
 Begin
  For Bit := 0 To 7 Do
   If (V And (128 Shr Bit)) <> 0 Then PutPixel(GX + XB * 8 + Bit, GY + Y, CLR_EDITOR_TEXT)
   Else PutPixel(GX + XB * 8 + Bit, GY + Y, 15);
 End;
Begin
 TabDraw := StShown;
 If Not StShown Then Exit;
 If StTrace Then WriteLn(ErrOutput, 'draw full=', Full, ' t=', MsNow);
 If StFirst Then Full := True;
 P.PanelX := 0;
 P.PanelY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + TAB_HEIGHT;
 GX := P.PanelX; GY := P.PanelY + 12;
 { rien a dessiner : ni changement de l'ecran emule, ni curseur, ni titre a rafraichir }
 If Not Full Then Begin
  Any := (MsNow - StTitleAt >= 250) Or (MsNow < StTitleAt);
  Show := (MouseHidden <= 0) And (GMouseX >= 0);
  If Show <> (StCurX > -100) Then Any := True;
  MXd := GMouseX - CurHotX; MYd := GMouseY - CurHotY;
  If MXd < 0 Then MXd := 0;
  If MYd < 0 Then MYd := 0;
  If MXd > SW - 16 Then MXd := SW - 16;
  If MYd > SH - 16 Then MYd := SH - 16;
  If Show And ((StCurX <> MXd) Or (StCurY <> MYd)) Then Any := True;
  A := 0;
  While (Not Any) And (A < 32000) Do Begin
   If Rd8(ScrBase + A) <> StShadow[A] Then Any := True;
   Inc(A);
  End;
  If (Not Any) And (Not Show) Then Exit;
  If (Not Any) And Show Then Begin
   Sig := 0;
   For R := 0 To 15 Do Sig := Sig * 31 + CurMask[R] + 7 * CurData[R];
   If Sig = StCurSh Then Exit;
  End;
 End;
 If Full Then Begin
  DrawFilledRect(P.PanelX - 2, P.PanelY - 2, P.PanelX + SW + 2, P.PanelY + 12 + SH + 2, CLR_BACKGROUND);
  StFirst := False;
  StCurX := -100;
 End;
 If Full Or (MsNow - StTitleAt >= 250) Or (MsNow < StTitleAt) Then Begin
  DrawFilledRect(P.PanelX, P.PanelY, P.PanelX + SW, P.PanelY + 11, CLR_TITLEBAR_ACTIVE);
  DrawText(P.PanelX + 6, P.PanelY + 2, 'Atari ST 640x400   PC=$' + Hex8(PC), CLR_HIGHLIGHTTEXT);
  DrawText(P.PanelX + SW - 60, P.PanelY + 2, '[Esc]', CLR_HIGHLIGHTTEXT);
  StTitleAt := MsNow;
 End;
 { nouvelle position du curseur (forme definie par le programme, vst_mouse / graf_mouse) }
 Show := (MouseHidden <= 0) And (GMouseX >= 0);
 MXd := GMouseX - CurHotX; MYd := GMouseY - CurHotY;
 If MXd < 0 Then MXd := 0;
 If MYd < 0 Then MYd := 0;
 If MXd > SW - 16 Then MXd := SW - 16;
 If MYd > SH - 16 Then MYd := SH - 16;
 Sig := 0;
 For R := 0 To 15 Do Sig := Sig * 31 + CurMask[R] + 7 * CurData[R];
 CurDirty := Show <> (StCurX > -100);
 If Show And ((StCurX <> MXd) Or (StCurY <> MYd) Or (StCurSh <> Sig)) Then CurDirty := True;
 { ancien curseur : les octets qu'il couvrait sont redessines d'apres la memoire }
 If CurDirty And (StCurX > -100) Then
  For Y := StCurY To StCurY + 15 Do
   For XB := StCurX Shr 3 To (StCurX + 15) Shr 3 Do
    If (XB >= 0) And (XB < 80) And (Y >= 0) And (Y < SH) Then Begin
     B := Rd8(ScrBase + LongInt(Y) * 80 + XB);
     StShadow[Y * 80 + XB] := B;
     PutByte(XB, Y, B);
    End;
 A := ScrBase;
 For Y := 0 To SH - 1 Do
  For XB := 0 To 79 Do Begin
   B := Rd8(A + LongInt(Y) * 80 + XB);
   O := StShadow[Y * 80 + XB];
   If Full Then O := Not B;
   If B <> O Then Begin
    StShadow[Y * 80 + XB] := B;
    PutByte(XB, Y, B);
    If (StCurX > -100) And (Y >= StCurY) And (Y < StCurY + 16) And (XB >= StCurX Shr 3 - 1) And (XB <= (StCurX + 15) Shr 3 + 1) Then CurDirty := True;
   End;
  End;
 If CurDirty Then Begin
  If Show Then Begin
   For R := 0 To 15 Do
    For C := 0 To 15 Do
     If (CurMask[R] And ($8000 Shr C)) <> 0 Then Begin
      If (CurData[R] And ($8000 Shr C)) <> 0 Then PutPixel(GX + MXd + C, GY + MYd + R, CLR_EDITOR_TEXT)
      Else PutPixel(GX + MXd + C, GY + MYd + R, 15);
     End;
   StCurX := MXd; StCurY := MYd; StCurSh := Sig;
  End Else StCurX := -100;
 End;
 If StTrace Then WriteLn(ErrOutput, '  fin full=', Full, ' cur=', StCurX, ',', StCurY, ' dirty=', CurDirty, ' g=', GMouseX, ',', GMouseY, ' hot=', CurHotX, ',', CurHotY, ' m=', MXd, ',', MYd, ' hid=', MouseHidden);
 P.LastGridW := SW;
 P.LastGridH := 12 + SH;
End;

{ dump des zones memoire en mode test (DEVENV_EMUDUMP=adresse:longueur:fichier, DEVENV_EMUSCR=fichier) }
Procedure TestDumps;
Var S, A, L, Fn: String; P1, P2, Ad, Ln, K: LongInt; F: File; B: Array[0..4095] Of Byte; N: LongInt;
 Procedure Dump(Addr, Len: LongInt; Const Name: String);
 Var T, M, J: LongInt;
 Begin
  Assign(F, Name);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  T := 0;
  While T < Len Do Begin
   M := Len - T; If M > SizeOf(B) Then M := SizeOf(B);
   For J := 0 To M - 1 Do B[J] := Rd8(Addr + T + J);
   BlockWrite(F, B, M);
   Inc(T, M);
  End;
  Close(F);
 End;
Begin
 WriteLn(ErrOutput, 'ST: stop=', StopReason, ' msg=', StopMsg, ' exit=', ExitCode, ' pc=$', Hex8(PC), ' instr=', InstrCount, ' souris=', GMouseX, ',', GMouseY, ' cache=', MouseHidden, ' forme=$', Hex8(CurMask[0]), '/', Hex8(CurMask[2]));
 S := GetEnv('DEVENV_EMUSCR');
 If S <> '' Then Dump(ScrBase, 32000, S);
 S := GetEnv('DEVENV_EMUDUMP');
 If S <> '' Then Begin
  P1 := Pos(':', S);
  If P1 > 0 Then Begin
   A := Copy(S, 1, P1 - 1); Fn := Copy(S, P1 + 1, Length(S));
   P2 := Pos(':', Fn);
   If P2 > 0 Then Begin
    L := Copy(Fn, 1, P2 - 1); Fn := Copy(Fn, P2 + 1, Length(Fn));
    Ad := 0;
    For K := 1 To Length(A) Do Ad := Ad * 16 + Pos(UpCase(A[K]), '0123456789ABCDEF') - 1;
    Val(L, Ln, N);
    If (Ad >= 0) And (Ln > 0) And (Ad + Ln <= MemSize) Then Dump(Ad, Ln, Fn);
   End;
  End;
 End;
End;

{ appele a chaque tour de la boucle de DEVENV : horloge du fil, fin du programme, mode test, dessin }
Procedure TabTick(Var P: TEmulatorPanel; Active: Boolean);
Var Lim: LongInt;
Begin
 StPaused := Not Active;
 StTickAt := MsNow;
 If StDone And P.Running Then Begin
  P.Running := False;
  P.Fault := sfEndProgram;
  P.StatusMsg := 'Programme termine';
  TabDraw(P, False);
 End;
 If GetEnv('DEVENV_EMUQUIT') <> '' Then Begin
  Lim := 20;
  If GetEnv('DEVENV_EMUTIME') <> '' Then Val(GetEnv('DEVENV_EMUTIME'), Lim, Lim);
  If StDone Or ((MsNow - StStart) > Lim * 1000) Then Begin
   TabStop;
   TestDumps;
   Halt(0);
  End;
 End;
 If Active Then Begin
  If P.StatusMsg <> '' Then P.StatusMsg := '';
  If (MsNow - StDrawAt >= 20) Or (MsNow < StDrawAt) Then Begin      { au plus 50 images par seconde }
   TabDraw(P, False);
   StDrawAt := MsNow;
  End;
 End Else If P.StatusMsg = '' Then P.StatusMsg := 'En pause (cliquez sur l''ecran pour reprendre)';
End;

{ clavier et souris de l'onglet ; retourne False pour laisser DEVENV traiter l'evenement (Echap ferme l'onglet) }
Function TabEvent(Var P: TEmulatorPanel; Var Ev: TEvent): Boolean;
Var Sc: Integer; Asc: Integer; NB: LongInt;
Begin
 TabEvent := False;
 If Not StRunning Then Exit;
 Case Ev.Kind Of
  EV_MOUSE_MOVE, EV_MOUSE_DOWN, EV_MOUSE_UP: Begin
    If StTrace And (Ev.Kind <> EV_MOUSE_MOVE) Then WriteLn(ErrOutput, 'souris ', Ev.MouseX, ',', Ev.MouseY, ' kind=', Ord(Ev.Kind), ' btn=', Ord(Ev.MouseBtn));
    StMX := Ev.MouseX - P.PanelX;
    StMY := Ev.MouseY - (P.PanelY + 12);
    If Ev.Kind = EV_MOUSE_DOWN Then Begin
     If Ev.MouseBtn = MB_LEFT Then NB := StMB Or 1 Else NB := StMB Or 2;
    End Else If Ev.Kind = EV_MOUSE_UP Then Begin
     If Ev.MouseBtn = MB_LEFT Then NB := StMB And Not 1 Else NB := StMB And Not 2;
    End Else NB := StMB;
    If (NB <> StMB) And (((StMQT + 1) And 63) <> StMQH) Then Begin
     StMQX[StMQT] := StMX; StMQY[StMQT] := StMY; StMQB[StMQT] := NB;
     StMQT := (StMQT + 1) And 63;
    End;
    StMB := NB;
    TabEvent := True;
   End;
  EV_KEY_CHAR: Begin
    If Ev.KeyChar = #27 Then Exit;
    Asc := Ord(Ev.KeyChar);
    Sc := ScanOfChar(Ev.KeyChar);
    If Asc = 8 Then Sc := 14 Else If Asc = 9 Then Sc := 15 Else If Asc = 13 Then Sc := 28;
    StKeyPut((LongInt(Sc) Shl 16) Or Asc);
    TabEvent := True;
   End;
  EV_KEY_DOWN: Begin
    Sc := Ev.KeyCode And $FF;
    If Sc = $1B Then Exit;
    Asc := 0;
    If Sc = 83 Then Asc := 127;
    StKeyPut((LongInt(Sc) Shl 16) Or Asc);
    TabEvent := True;
   End;
 End;
End;
"""
FWD_HOOK=r"""{ Atari ST : onglet d'emulation complet (bloc St_ defini en fin de fichier) }
Function St_TabStart(Var P: TEmulatorPanel; Const Prg, Tail: String): Boolean; Forward;
Procedure St_TabStop; Forward;
Procedure St_TabClose; Forward;
Function St_TabDraw(Var P: TEmulatorPanel; Full: Boolean): Boolean; Forward;
Procedure St_TabTick(Var P: TEmulatorPanel; Active: Boolean); Forward;
Function St_TabEvent(Var P: TEmulatorPanel; Var Ev: TEvent): Boolean; Forward;
"""
# (ancre, remplacement) : chaque ancre doit exister une seule fois dans la version d'origine
HOOKS=[
 ("Procedure EmuVScr_PutChar(Var P: TEmulatorPanel; C: Char); Forward;\n",
  "Procedure EmuVScr_PutChar(Var P: TEmulatorPanel; C: Char); Forward;\n"+FWD_HOOK),
 (" ScrH := GetScreenHeight;\n { Mode NES : rendu pixel du framebuffer 256x240",
  " ScrH := GetScreenHeight;\n { Atari ST : ecran emule (onglet complet, bloc St_) }\n If P.TargetCPU = '-CATARIST' Then\n  If St_TabDraw(P, True) Then Exit;\n { Mode NES : rendu pixel du framebuffer 256x240"),
 (" If IsM68K Then Begin\n  { ----- Emulateur Motorola 68000 ----- }\n",
  " If IsM68K Then Begin\n  { ----- Atari ST : emulateur complet (processeur, TOS, VDI, AES), bloc St_ en fin de fichier ----- }\n"
  "  If TargetCPU = '-CATARIST' Then Begin\n"
  "   P.Loaded := True;\n   P.Running := True;\n   EmuHasFocus := True;\n   EmuLastActiveState := True;\n"
  "   If Not St_TabStart(P, BinaryPath, Args) Then Begin\n"
  "    P.CurFg := 12;\n    EmuVScr_WriteStr(P, 'Erreur : impossible de charger ' + BinaryPath);\n"
  "    P.CurFg := OldFg;\n    P.Running := False;\n    P.Fault := sfEndProgram;\n    P.StatusMsg := 'Echec chargement binaire Atari ST';\n"
  "   End;\n   DrawEmulatorPanel(P);\n   Exit;\n  End;\n"
  "  { ----- Emulateur Motorola 68000 ----- }\n"),
 (" If P.Loaded And ((P.TargetCPU = '-C68000') Or (P.TargetCPU = '-CATARIST') Or\n                   (P.TargetCPU = '-CAMIGA')) Then Begin\n  If Not P.Running Then Exit;\n",
  " If P.Loaded And ((P.TargetCPU = '-C68000') Or (P.TargetCPU = '-CATARIST') Or\n                   (P.TargetCPU = '-CAMIGA')) Then Begin\n  If Not P.Running Then Exit;\n"
  "  If P.TargetCPU = '-CATARIST' Then Begin\n   { Atari ST : l'emulation tourne dans son fil (bloc St_) ; ici : pause, dessin, fin }\n"
  "   St_TabTick(P, EmuHasFocus And Not MenuActive And Not CtxMenu.Visible);\n   Exit;\n  End;\n"),
 (" IsWin16Target := (P.TargetCPU = '-CWIN16');\n Case Ev.Kind Of\n  EV_KEY_CHAR:\n",
  " IsWin16Target := (P.TargetCPU = '-CWIN16');\n { Atari ST : clavier et souris vont a l'emulation (Echap ferme l'onglet comme pour les autres) }\n"
  " If P.TargetCPU = '-CATARIST' Then\n  If St_TabEvent(P, Ev) Then Exit;\n Case Ev.Kind Of\n  EV_KEY_CHAR:\n"),
 ("Procedure EmuPanel_Stop;\nBegin\n If EmuPanel.Base.Visible And EmuPanel.Loaded And EmuPanel.Running Then Begin\n",
  "Procedure EmuPanel_Stop;\nBegin\n If EmuPanel.Base.Visible And EmuPanel.Loaded And EmuPanel.Running Then Begin\n"
  "  If EmuPanel.TargetCPU = '-CATARIST' Then St_TabStop;\n"),
 ("  Else ClosingDOSCPU := Node^.EmuTab.TargetCPU;\n",
  "  Else ClosingDOSCPU := Node^.EmuTab.TargetCPU;\n  If ClosingDOSCPU = '-CATARIST' Then St_TabClose;\n"),
]
ANCHOR_BLOCK="Procedure M68K_RunOneChunk(Var P: TEmulatorPanel);\n"

NOT_DEVPAC=['i','k','msk','statusmsg','tevent','j']   # identifiants de la colle qui ne designent pas une declaration de DEVPAC.PAS
HSEP_OLD=" St_HSEP = '/';\n St_HSEP = '\\';\n St_HSEP = '\\';\n"
HSEP_NEW=" {$IFDEF UNIX}\n St_HSEP = '/';\n {$ELSE}\n St_HSEP = '\\';\n {$ENDIF}\n"

def build(devpac,base):
    s=open(devpac,encoding='latin-1').read()
    G_over=pascal_prefix.declared_globals(pascal_prefix.tokenize(FORWARDS+OVERRIDES+GLUE))
    # identifiants de la colle qui sont des declarations de DEVPAC.PAS : ajoutes aux points d'entree
    U=pascal_prefix.units(s)
    declared={n.lower() for u in U for n in u[0] if n}
    gl={v for k,v in pascal_prefix.tokenize(FORWARDS+OVERRIDES+GLUE) if k=='id'}
    extra=sorted(i for i in gl if i.lower() in declared and i.lower() not in {g.lower() for g in G_over} and i.lower() not in NOT_DEVPAC)
    print('identifiants de la colle repris de DEVPAC.PAS (verifier : pas une variable locale homonyme) :',' '.join(extra))
    gem,names=gem_closure(s,'',list(G_over)+['MemSize_NEVER'],ROOTS+extra)
    text=FORWARDS+gem+'\n'
    G=pascal_prefix.declared_globals(pascal_prefix.tokenize(text+OVERRIDES+GLUE))
    t1,_=pascal_prefix.rename(text,'St_',extra_skip=['Shift','TEvent'],G=G)
    # la colle utilise des champs d'enregistrements de DEVENV (P.StatusMsg, Ev.Kind...) : jamais renommes
    t2,_=pascal_prefix.rename(OVERRIDES+GLUE,'St_',extra_skip=['Shift','TEvent'],G=G,fields=False)
    t=t1+t2
    if HSEP_OLD not in t: raise SystemExit('HSEP introuvable')
    t=t.replace(HSEP_OLD,HSEP_NEW)
    import re as _re
    for bad in ('External','{$I ','{$INCLUDE','{$L ','{$LINK','{$MODE','{$DEFINE','{$MODESWITCH'):
        if bad.lower() in t.lower(): raise SystemExit('element interdit dans le bloc genere : '+bad)
    block=BEGIN_MARK+'\n{$PUSH}\n{$A-}\n{$I-}\n{$R-}\n{$Q-}\n'+t+'\n{$POP}\n'+END_MARK+'\n\n'
    d=base
    for old,new in HOOKS:
        if d.count(old)!=1: raise SystemExit('ancre introuvable ou multiple : '+old[:70])
        d=d.replace(old,new)
    if d.count(ANCHOR_BLOCK)!=1: raise SystemExit('ancre du bloc')
    d=d.replace(ANCHOR_BLOCK,block+ANCHOR_BLOCK)
    return d,len(t.split('\n')),len(G),len(names)

def main(devpac,devenv,basecommit='fcad7f4'):
    import subprocess
    base=subprocess.run(['git','show',basecommit+':DEVENV.PAS'],capture_output=True,check=True).stdout.decode('latin-1')
    d,nl,ni,nd=build(devpac,base)
    open(devenv,'w',encoding='latin-1',newline='').write(d)
    print('bloc insere :',nl,'lignes,',ni,'identifiants ;',nd,'declarations')
if __name__=='__main__':
    main(sys.argv[1],sys.argv[2])
