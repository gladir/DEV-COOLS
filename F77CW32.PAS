{ @author: Sylvain Maltais
  @created: 2026-06-17
  @version: 2.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Fortran 77 vers assembleur 80386 / Windows 32 bits
  @output: Win32 PE .EXE par defaut, COFF i386 .OBJ sur demande,
           .ASM 80386 optionnel sur demande explicite
  @license: MIT
}

{ TODO F77CW32 - Compilateur Fortran 77 vers 80386/Win32

  DONE 01 - Cible F77CW32 renomme et isolee, avec metadata d'en-tete indiquant
            Fortran 77 -> assembleur 80386 / Windows 32 bits.

  DONE 02 - Modes de sortie definis:
            par defaut produire un .EXE Windows 32 bits;
            avec option -c produire seulement un .OBJ;
            avec option -S produire un .ASM uniquement sur demande explicite.

  TODO 03 - Concevoir le pipeline complet:
            source .F -> lexer -> parser -> tables semantiques -> IR simple
            -> ASM 80386 optionnel -> OBJ COFF -> EXE PE32.

  TODO 04 - Adapter les conventions d'appel du generateur 8086 vers 80386:
            pile 32 bits, registres EAX/EBX/ECX/EDX/ESI/EDI/EBP/ESP,
            prologue/epilogue Win32, arguments passes par adresse Fortran.

  TODO 05 - Remplacer le modele memoire SMALL/segments 8086 par un modele plat
            32 bits: .text, .data, .bss, alignements et labels compatibles Win32.

  TODO 06 - Choisir et documenter le format objet cible:
            COFF i386 pour linker Windows, avec table de symboles, relocations
            et sections minimales.

  TODO 07 - Implementer ou reutiliser un writer OBJ COFF minimal capable de
            contenir code, donnees statiques, chaines, COMMON et relocations.

  TODO 08 - Ajouter l'etape de linkage .OBJ -> .EXE par defaut:
            soit via linker externe configure, soit via generation PE32 minimale
            si le projet choisit une sortie autonome.

  TODO 09 - Prevoir les options ligne de commande:
            -c pour .OBJ seulement, -S pour conserver/generer .ASM,
            -o nom_sortie, -v version, -h aide, et mode diagnostic.

  TODO 10 - Adapter l'emission assembleur 80386:
            MOV/PUSH/CALL/RET/JMP/CMP/Jcc/IMUL/IDIV 32 bits,
            labels internes, labels Fortran numeriques et appels runtime.

  TODO 11 - Definir les tailles Win32 des types Fortran supportes au depart:
            INTEGER en 32 bits, LOGICAL en 32 bits, CHARACTER fixe,
            puis preparer REAL/DOUBLE pour une phase ulterieure.

  TODO 12 - Valider le lexer Fortran 77 fixe:
            colonnes 1-5 labels, colonne 6 continuation,
            commentaires C/* en colonne 1, lignes jusqu'a 72 colonnes utiles.

  TODO 13 - Valider le parser des unites de programme:
            PROGRAM, SUBROUTINE, END, RETURN, declarations INTEGER,
            appels CALL et portees separees par unite.

  TODO 14 - Implementer le typage implicite Fortran 77:
            I-N INTEGER par defaut, autres REAL si non declare,
            tout en permettant INTEGER explicite pour les samples actuels.

  TODO 15 - Finaliser la table des symboles 32 bits:
            variables locales, variables statiques si necessaire,
            parametres dummy passes par adresse, procedures et labels.

  TODO 16 - Implementer les affectations scalaires INTEGER:
            constantes entieres, variables, copies par adresse pour parametres,
            et stockage correct dans les variables locales.

  TODO 17 - Implementer les expressions INTEGER minimales:
            +, -, *, parentheses, variables, constantes,
            evaluation avec pile ou registres 80386.

  TODO 18 - Implementer les comparaisons relationnelles Fortran:
            .EQ., .NE., .LT., .LE., .GT., .GE.,
            necessaires notamment pour IF (N .LE. 1) GOTO label.

  TODO 19 - Implementer GOTO numerique et resolution des labels:
            labels definis/references, erreurs sur label inconnu,
            emission JMP/Jcc vers labels ASM stables.

  TODO 20 - Implementer IF arithmetique/logique minimal:
            au minimum IF (expr relationnelle) GOTO label
            pour couvrir fibo.f, puis etendre vers IF complet F77.

  TODO 21 - Implementer DO label var = debut, fin[, pas]:
            compteur INTEGER 32 bits, borne finale, increment,
            branchement vers label de fin, compatibilite avec CONTINUE.

  TODO 22 - Implementer CONTINUE comme label/emission no-op,
            utilisable comme terminaison de boucle DO numerique.

  TODO 23 - Implementer CALL SUBROUTINE avec arguments par reference:
            ordre d'empilement documente, nettoyage de pile,
            liaison interne PROGRAM/SUBROUTINE dans le meme fichier.

  TODO 24 - Implementer le runtime console minimal Win32:
            PRINT *, chaine litterale;
            PRINT *, variable INTEGER;
            conversion entier -> texte;
            sortie via API Win32 ou runtime C selon strategie de linkage.

  TODO 25 - Creer la batterie de validation SAMPLES\F77:
            hello.f, arith.f, do_test.f, sub_test.f, fibo.f;
            compiler en .EXE par defaut, tester option .OBJ seul,
            tester option .ASM explicite, comparer sorties attendues.
}

Program F77CW32;

Const
 F77CW32_VERSION = '2.0';

Type
 TOutputMode = (OM_EXE, OM_OBJ);

 TCompilerOptions = Record
  SourceName : String;
  OutputName : String;
  OutputMode : TOutputMode;
  EmitAsm    : Boolean;
  Verbose    : Boolean;
 End;

Var
 Options : TCompilerOptions;

Function UpperStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S)Do S[I]:=UpCase(S[I]);
 UpperStr:=S;
End;

Function DefaultOutputExt:String;
Begin
 If Options.OutputMode=OM_OBJ Then DefaultOutputExt:='.obj'
  Else DefaultOutputExt:='.exe';
End;

Function HasExtension(S:String):Boolean;
Var
 I:Integer;
Begin
 HasExtension:=False;
 For I:=Length(S) DownTo 1 Do Begin
  If S[I]='.' Then Begin
   HasExtension:=True;
   Exit;
  End;
  If(S[I]='\')or(S[I]='/')or(S[I]=':')Then Exit;
 End;
End;

Function DefaultOutputName(SourceName:String):String;
Var
 I,LastDot:Integer;
Begin
 LastDot:=0;
 For I:=Length(SourceName) DownTo 1 Do Begin
  If SourceName[I]='.' Then Begin
   LastDot:=I;
   Break;
  End;
  If(SourceName[I]='\')or(SourceName[I]='/')or(SourceName[I]=':')Then Break;
 End;
 If LastDot>0 Then DefaultOutputName:=Copy(SourceName,1,LastDot-1)+DefaultOutputExt
  Else DefaultOutputName:=SourceName+DefaultOutputExt;
End;

Procedure PrintUsage;Begin
 WriteLn('F77CW32 - Cette commande permet de ',
         'lancer le compilateur Fortran 77 pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : F77CW32 <source.f77> [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -c            : produire seulement un fichier objet COFF i386 .OBJ');
 WriteLn('  -S            : produire/conserver aussi le fichier assembleur .ASM');
 WriteLn('  -o <fichier>  : specifier le nom du fichier de sortie');
 WriteLn('  -v            : mode verbeux');
 WriteLn('  -h, --help    : afficher cette aide');
 WriteLn('  --version     : afficher la version');
End;

Procedure PrintVersion;Begin
 WriteLn('F77CW32 ',F77CW32_VERSION);
End;

Procedure InitOptions;Begin
 Options.SourceName:='';
 Options.OutputName:='';
 Options.OutputMode:=OM_EXE;
 Options.EmitAsm:=False;
 Options.Verbose:=False;
End;

Function IsHelpSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsHelpSwitch:=(S='/?')or(S='--HELP')or(S='-H')or(S='/H');
End;

Function IsVersionSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsVersionSwitch:=(S='--VERSION')or(S='-VERSION');
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 S:String;
Begin
 I:=1;
 While I<=ParamCount Do Begin
  S:=ParamStr(I);
  If IsHelpSwitch(S)Then Begin
   PrintUsage;
   Halt;
  End
  Else If IsVersionSwitch(S)Then Begin
   PrintVersion;
   Halt;
  End
  Else If UpperStr(S)='-C' Then Options.OutputMode:=OM_OBJ
  Else If UpperStr(S)='-S' Then Options.EmitAsm:=True
  Else If UpperStr(S)='-V' Then Options.Verbose:=True
  Else If UpperStr(S)='-O' Then Begin
   Inc(I);
   If I>ParamCount Then Begin
    WriteLn('Erreur: option -o sans nom de fichier.');
    Halt(1);
   End;
   Options.OutputName:=ParamStr(I);
  End
  Else If(Length(S)>0)and(S[1]='-')Then Begin
   WriteLn('Erreur: option inconnue: ',S);
   Halt(1);
  End
  Else If Options.SourceName='' Then Options.SourceName:=S
  Else Begin
   WriteLn('Erreur: fichier source en trop: ',S);
   Halt(1);
  End;
  Inc(I);
 End;

 If Options.SourceName='' Then Begin
  PrintUsage;
  Halt(1);
 End;

 If Options.OutputName='' Then Options.OutputName:=DefaultOutputName(Options.SourceName)
  Else If Not HasExtension(Options.OutputName)Then
   Options.OutputName:=Options.OutputName+DefaultOutputExt;
End;

Procedure PrintSelectedOutputs;
Begin
 If Not Options.Verbose Then Exit;
 WriteLn('Source : ',Options.SourceName);
 If Options.OutputMode=OM_OBJ Then WriteLn('Mode   : OBJ seulement')
  Else WriteLn('Mode   : EXE Win32 par defaut');
 WriteLn('Sortie : ',Options.OutputName);
 If Options.EmitAsm Then WriteLn('ASM    : oui')
  Else WriteLn('ASM    : non');
End;

BEGIN
 InitOptions;
 ParseCommandLine;
 PrintSelectedOutputs;
END.
