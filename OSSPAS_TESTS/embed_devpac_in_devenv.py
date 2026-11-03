#!/usr/bin/env python3
"""Embarque l'emulateur Atari ST / GEM de DEVPAC.PAS dans DEVENV.PAS (fichier unique, sans unite).

  python3 OSSPAS_TESTS/embed_devpac_in_devenv.py DEVPAC.PAS DEVENV.PAS

* tous les identifiants globaux de DEVPAC.PAS sont prefixes par Dvp_ (voir pascal_prefix.py) ;
* le bloc est insere (ou remplace, s'il existe deja) entre deux marques, juste avant CreateEmulatorTab ;
* CreateEmulatorTab(..., '-CATARIST', ...) lance alors Dvp_EmulRun (emulateur complet, plein ecran modal)
  au lieu de l'ancien panneau texte ; l'unite Ptc est ajoutee a la clause Uses.
Relancer le script apres chaque amelioration de l'emulateur de DEVPAC.PAS.
"""
import re,sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pascal_prefix
BEGIN_MARK='{ ===== DEBUT EMULATEUR ATARI ST / GEM (genere par embed_devpac_in_devenv.py a partir de DEVPAC.PAS) ===== }'
END_MARK='{ ===== FIN EMULATEUR ATARI ST / GEM ===== }'
GLUE='''
{ ---------------------------------------------------------------------- }
{ Point d'entree : execute un programme Atari ST dans l'emulateur ST/GEM    }
{ complet issu de DEVPAC (CPU 68000, TOS, VDI, AES, ligne A, BIOS/XBIOS),    }
{ en plein ecran modal ; au retour DEVENV repeint son interface.            }
{ Variables d'environnement : DEVENV_EMUSCR (ecran logique), DEVENV_EMUDUMP   }
{ (adresse:longueur:fichier), DEVENV_EMUTIME (secondes), DEVENV_EMUGEM=0,     }
{ DEVENV_EMUQUIT=1 (quitter DEVENV a la fin du programme).                  }
{ ---------------------------------------------------------------------- }
Procedure Dvp_EmulRun(Const Prg,Tail: String);
Var S: String;
Begin
 { l'indice 0 de la palette est remappe par SetBkColor dans le reste de l'IDE : noir/blanc explicites }
 SetRGBPalette(0,0,0,0);
 SetRGBPalette(15,255,255,255);
 Dvp_InitApp;
 Dvp_AmigaMode:=False;
 Dvp_BatchMode:=False;
 Dvp_OptRunGem:=True;Dvp_OptAccs:=True;
 If GetEnv('DEVENV_EMUGEM')='0' Then Dvp_OptRunGem:=False;
 Dvp_EmulScr:=GetEnv('DEVENV_EMUSCR');
 Dvp_EmulDump:=GetEnv('DEVENV_EMUDUMP');
 Dvp_EmulTime:=0;
 S:=GetEnv('DEVENV_EMUTIME');
 If S<>'' Then Dvp_EmulTime:=Dvp_ToInt(S);
 Dvp_EmulTail:=Tail;
 Dvp_GfxOn:=True;
 Dvp_InitMemory(Dvp_ST_MEMKB);
 Dvp_ScrBase:=(Dvp_MemSize-Dvp_SCR_BYTES) And $FFFF00;Dvp_DrawBase:=Dvp_ScrBase;
 Dvp_CheckFonts;
 If Dvp_EmulTime>0 Then Dvp_StartAction:='E' Else Dvp_StartAction:=' ';
 Dvp_RunPause:=(Dvp_EmulTime=0);
 Dvp_RunProgramGUI(Prg,Tail);
 Dvp_EmulDumps;
 If GetEnv('DEVENV_EMUQUIT')<>'' Then Begin
  CloseGraph;
  Halt(0);
 End;
End;
'''
def main(devpac,devenv):
    s=open(devpac,encoding='latin-1').read()
    t,G=pascal_prefix.rename(s,'Dvp_',extra_skip=['Shift','GetMouseState'])
    a=t.index("{ ====================================================================== }\n{                              CONSTANTES")
    b=re.search(r"\nVar Dvp_I,Dvp_K,Dvp_NCr: Integer",t).start()
    body=t[a:b]
    # DEVENV est compile en mode TP : l'operateur As (interfaces Ptc) n'y existe pas
    body=body.replace('ME:=Ev As IPTCMouseEvent;','Ev.QueryInterface(IPTCMouseEvent,ME);').replace('KE:=Ev As IPTCKeyEvent;','Ev.QueryInterface(IPTCKeyEvent,KE);')
    assert ' As IPTC' not in body
    block=BEGIN_MARK+'\n{$PUSH}\n{$A-}\n{$I-}\n{$R-}\n{$Q-}\n'+body+GLUE+'{$POP}\n'+END_MARK+'\n\n'
    d=open(devenv,encoding='latin-1').read()
    if BEGIN_MARK in d:
        i=d.index(BEGIN_MARK); j=d.index(END_MARK)+len(END_MARK)+2
        d=d[:i]+block+d[j:]
    else:
        mark="Procedure CreateEmulatorTab(BinaryPath, TargetCPU: String; Args: String);\nVar\n Idx: Integer;"
        assert mark in d, 'CreateEmulatorTab introuvable'
        d=d.replace(mark,block+mark,1)
        hook="Begin\n SyncActiveWindowOut;\n Idx := WinMgr.WinCount;\n Node := AppendWindowNode;\n Node^.Win.Kind := WK_EMU;"
        assert hook in d
        d=d.replace(hook,"Begin\n { Atari ST : emulateur ST/GEM complet de DEVPAC (plein ecran, modal) }\n If TargetCPU = '-CATARIST' Then Begin\n  Dvp_EmulRun(BinaryPath, Args);\n  FullRepaintNeeded := True;\n  Exit;\n End;\n SyncActiveWindowOut;\n Idx := WinMgr.WinCount;\n Node := AppendWindowNode;\n Node^.Win.Kind := WK_EMU;",1)
        u='PtcGraph,PtcCrt,PtcMouse\n'
        assert u in d
        d=d.replace(u,'PtcGraph,PtcCrt,PtcMouse,Ptc\n',1)
    open(devenv,'w',encoding='latin-1').write(d)
    print('bloc embarque :',len(body.split('\n')),'lignes,',len(G),'identifiants prefixes')
if __name__=='__main__':
    main(sys.argv[1],sys.argv[2])
