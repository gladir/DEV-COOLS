{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpileur d'assembleur 8086/80386 (syntaxe MASM/TASM)
                en langage de programmation Pascal (Turbo Pascal)
}

{ TODO - Liste des 25 points a implementer pour le transpileur ASM vers Pascal :

  1.  [A FAIRE] Infrastructure, options de ligne de commande et constantes globales.
      Programme principal ASM2PAS en Turbo Pascal / Free Pascal.
      Analyse des options : nom du fichier .ASM en entree, nom du
      fichier .PAS en sortie (par defaut meme nom avec extension .PAS),
      options -16 (mode 16 bits), -32 (mode 32 bits), -inline (garder
      le code non-traduisible en ASM inline), -v (verbose),
      -comments (inclure le code ASM original en commentaire).
      Constantes de dimensionnement : MAX_SYMBOLS, MAX_LABELS,
      MAX_PROCS, MAX_LINES, MAX_VARS, MAX_PARAMS.
      Fonctions utilitaires : UpCaseStr, Trim, HexToInt,
      IntToStr, FileExists, ChangeFileExt.

  2.  [A FAIRE] Analyseur lexical (tokenizer) du code assembleur.
      Lire le fichier .ASM ligne par ligne et decouper chaque
      ligne en tokens : labels (identificateur suivi de ':'),
      mnemoniques d'instructions, operandes (registres, memoire,
      immediats), virgules, crochets, operateurs (+, -, *),
      commentaires (';' jusqu'a fin de ligne), chaines entre
      guillemets simples ou doubles. Gerer les continuations
      de ligne avec '\'. Ignorer les lignes vides et les
      lignes ne contenant que des commentaires.

  3.  [A FAIRE] Analyse des directives d'assemblage (segments et modeles).
      Reconnaitre les directives MASM/TASM : .MODEL (SMALL,
      COMPACT, MEDIUM, LARGE, HUGE, FLAT), .STACK, .CODE,
      .DATA, .DATA?, .CONST, .FARDATA, SEGMENT/ENDS avec
      attributs (PARA, PUBLIC, 'CLASS'), GROUP, ASSUME,
      .8086, .286, .386, .486, .586, OPTION CASEMAP:NONE.
      Determiner le mode 16 ou 32 bits a partir du modele
      memoire et des directives de processeur.

  4.  [A FAIRE] Analyse des directives de donnees (DB, DW, DD, DQ, DT).
      Reconnaitre les declarations de donnees : DB (octet),
      DW (mot 16 bits), DD (double mot 32 bits), DQ (quad mot
      64 bits), DT (10 octets). Gerer les valeurs multiples
      separees par des virgules, les chaines entre guillemets,
      les expressions DUP (count DUP(valeur)), les operateurs
      OFFSET et SEG. Convertir en declarations Pascal :
      DB -> Byte, DW -> Word, DD -> LongInt, chaines -> String,
      tableaux -> Array[..] of Byte/Word/LongInt.

  5.  [A FAIRE] Analyse des directives de procedures (PROC/ENDP).
      Reconnaitre les directives PROC et ENDP pour delimiter les
      procedures et fonctions assembleur. Gerer les attributs
      NEAR et FAR, les conventions d'appel (C, PASCAL, STDCALL),
      les parametres declares avec PROC (nom:type) en syntaxe
      MASM 6+. Detecter les variables locales declarees avec
      LOCAL. Associer chaque ENDP a son PROC correspondant.
      Determiner si une procedure retourne une valeur (fonction)
      en analysant l'utilisation de AX/EAX avant RET.

  6.  [A FAIRE] Table des symboles et gestion des identificateurs.
      Maintenir une table des symboles globale contenant :
      labels (adresses de saut), noms de procedures, noms de
      variables (donnees), constantes (EQU, =), segments,
      parametres de procedures. Chaque entree stocke : nom,
      type (label, proc, var, const, segment, param), taille
      en octets, offset, segment d'appartenance. Gerer la
      portee : symboles globaux (PUBLIC) et locaux (@@, LOCAL).
      Verifier les doublons et les references non resolues.

  7.  [A FAIRE] Analyse des operandes et modes d'adressage.
      Parser les operandes des instructions : registres 8 bits
      (AL..BH), 16 bits (AX..DI), 32 bits (EAX..EDI), de
      segment (CS,DS,ES,SS,FS,GS), immediats decimaux et
      hexadecimaux (0FFh, 0xFF, 255), memoire directe ([1234h]),
      memoire indexee ([BX+SI+4], [EBX+ECX*4+8]),
      BYTE PTR / WORD PTR / DWORD PTR, OFFSET label,
      SEG label. Construire un arbre d'operande avec le type
      (reg, mem, imm), la taille et la valeur ou l'expression.

  8.  [A FAIRE] Inference de types pour les variables et les registres.
      Determiner le type Pascal optimal pour chaque variable et
      registre : Byte (8 bits non signe), ShortInt (8 bits signe),
      Word (16 bits non signe), Integer (16 bits signe),
      LongInt (32 bits signe), Boolean (flags), Char (caracteres),
      Pointer (adresses FAR), PChar (pointeurs de chaines).
      Analyser l'utilisation des variables dans le code pour
      affiner le type : CMP avec 0/1 -> Boolean, MOVSB/LODSB
      avec boucle -> String, MUL/IMUL -> distinguer signe/non-signe.

  9.  [A FAIRE] Traduction des registres en variables Pascal.
      Mapper les registres CPU vers des variables Pascal :
      AX/EAX -> RegAX:Word/RegEAX:LongInt, etc.
      Gerer les sous-registres : AL = Lo(RegAX), AH = Hi(RegAX).
      Detecter quand un registre est utilise comme variable locale
      temporaire et le remplacer par une variable Pascal nommee.
      Gerer le registre FLAGS comme un ensemble de booleens
      (FlagCF, FlagZF, FlagSF, FlagOF). Mapper le pointeur de
      pile SP/ESP et le registre de base BP/EBP pour l'acces
      aux parametres et variables locales sur la pile.

  10. [A FAIRE] Traduction des instructions de transfert de donnees.
      Convertir MOV dest,src -> dest := src (affectation Pascal).
      XCHG a,b -> Begin tmp:=a; a:=b; b:=tmp End.
      LEA reg,[expr] -> reg := Addr(expr) ou @expr.
      LDS/LES/LFS/LGS reg,[mem] -> chargement segment:offset.
      MOVZX -> affectation avec extension non signee.
      MOVSX -> affectation avec extension signee (ShortInt/Integer).
      CBW -> AX := Integer(ShortInt(AL)).
      CWD -> DX:AX := LongInt(Integer(AX)).
      CWDE -> EAX := LongInt(Integer(AX)).
      CDQ -> EDX:EAX := extension de signe de EAX.

  11. [A FAIRE] Traduction des instructions arithmetiques.
      ADD dest,src -> dest := dest + src.
      ADC dest,src -> dest := dest + src + Ord(FlagCF).
      SUB dest,src -> dest := dest - src.
      SBB dest,src -> dest := dest - src - Ord(FlagCF).
      INC dest -> Inc(dest). DEC dest -> Dec(dest).
      NEG dest -> dest := -dest (complement a deux).
      MUL src -> DX:AX := Word(AX) * Word(src) (non signe).
      IMUL src -> DX:AX := Integer(AX) * Integer(src) (signe).
      DIV src -> AX := DX:AX div src; DX := DX:AX mod src.
      IDIV src -> idem avec division signee.
      Mettre a jour les flags apres chaque operation.

  12. [A FAIRE] Traduction des instructions logiques et de decalage.
      AND dest,src -> dest := dest and src.
      OR dest,src -> dest := dest or src.
      XOR dest,src -> dest := dest xor src.
      NOT dest -> dest := not dest.
      TEST a,b -> positionner flags selon a and b.
      SHL/SAL dest,n -> dest := dest shl n.
      SHR dest,n -> dest := dest shr n.
      SAR dest,n -> decalage arithmetique a droite (signe).
      ROL/ROR/RCL/RCR -> rotations (Rol/Ror ou code inline).
      BT/BTS/BTR/BTC -> test, set, reset, complement de bit :
      BT base,bit -> FlagCF := (base shr bit) and 1 = 1.

  13. [A FAIRE] Traduction des comparaisons et sauts conditionnels en IF/THEN/ELSE.
      CMP a,b -> positionner les flags (ZF, CF, SF, OF).
      Reconnaitre les patterns CMP + Jcc et les traduire en
      structures IF..THEN..ELSE Pascal :
      CMP a,b / JE label -> If a = b Then Goto label.
      JNE -> <>, JL/JNGE -> <, JG/JNLE -> >,
      JLE/JNG -> <=, JGE/JNL -> >=,
      JB/JNAE -> < (non signe), JA/JNBE -> > (non signe),
      JBE/JNA -> <= (non signe), JAE/JNB -> >= (non signe).
      Detecter les structures if-then-else completes et les
      boucles while/repeat pour eviter les Goto.

  14. [A FAIRE] Traduction des sauts inconditionnels et detection de boucles.
      JMP label -> Goto label (avec declaration Label en Pascal).
      Detecter les patterns de boucles pour generer du code
      structure : JMP arriere -> Repeat..Until ou While..Do.
      LOOP label -> Dec(CX); If CX <> 0 Then Goto label,
      ou mieux : For I := CX DownTo 1 Do Begin..End.
      LOOPE/LOOPZ -> Dec(CX); If (CX<>0) and FlagZF Then...
      LOOPNE/LOOPNZ -> Dec(CX); If (CX<>0) and not FlagZF Then...
      JCXZ/JECXZ -> If CX = 0 Then Goto label.
      Analyser le graphe de flux pour detecter les boucles
      naturelles (back-edges dans le CFG) et les traduire
      en While/Repeat au lieu de Goto.

  15. [A FAIRE] Traduction des appels de procedures (CALL/RET).
      CALL label -> appel de procedure/fonction Pascal.
      Si la procedure est connue (dans la table des symboles),
      generer un appel Pascal avec les parametres detectes.
      Analyser les PUSH avant CALL pour identifier les parametres
      selon la convention d'appel : C (droite a gauche, appelant
      nettoie), PASCAL (gauche a droite, appele nettoie), STDCALL
      (droite a gauche, appele nettoie). RET -> Exit ou fin de
      procedure. RET n -> sortie avec nettoyage de pile.
      CALL FAR -> appel inter-segment.

  16. [A FAIRE] Traduction des operations de pile (PUSH/POP).
      PUSH reg/mem/imm -> empiler sur la pile simulee ou passer
      comme parametre a la prochaine procedure appelee.
      POP reg/mem -> depiler. PUSHA/PUSHAD -> sauvegarder tous
      les registres. POPA/POPAD -> restaurer tous les registres.
      PUSHF/POPF -> sauvegarder/restaurer les flags.
      Quand les PUSH/POP encadrent un CALL, les convertir en
      parametres de la procedure appelee. Quand ils servent a
      sauvegarder/restaurer des registres, les convertir en
      variables temporaires locales.

  17. [A FAIRE] Traduction des instructions de chaine (string operations).
      MOVSB/MOVSW/MOVSD -> Move(Src^, Dst^, Count).
      CMPSB/CMPSW/CMPSD -> comparaison de blocs memoire.
      LODSB -> AL := Mem[DS:SI]; Inc(SI).
      LODSW -> AX := MemW[DS:SI]; Inc(SI, 2).
      STOSB -> Mem[ES:DI] := AL; Inc(DI).
      STOSW -> MemW[ES:DI] := AX; Inc(DI, 2).
      SCASB/SCASW -> comparaison AL/AX avec [ES:DI].
      Avec prefixe REP : boucle CX fois -> FillChar, Move.
      Avec REPE/REPNE : boucle avec condition -> recherche.
      Detecter les patterns connus : copie de chaine, recherche
      de caractere, comparaison de chaines, remplissage.

  18. [A FAIRE] Traduction des appels systeme (INT 21h DOS, INT 10h BIOS, etc.).
      Reconnaitre les interruptions logicielles et les traduire
      en appels de fonctions Pascal equivalentes :
      INT 21h/AH=01 -> ReadKey (lecture caractere clavier).
      INT 21h/AH=02 -> Write(Chr(DL)) (afficher caractere).
      INT 21h/AH=09 -> Write(chaine$) (afficher chaine).
      INT 21h/AH=3Ch -> Rewrite (creer fichier).
      INT 21h/AH=3Dh -> Reset (ouvrir fichier).
      INT 21h/AH=3Fh -> BlockRead (lire fichier).
      INT 21h/AH=40h -> BlockWrite (ecrire fichier).
      INT 21h/AH=4Ch -> Halt (terminer programme).
      INT 10h -> fonctions BIOS video (GotoXY, TextColor, etc.).
      INT 16h -> fonctions BIOS clavier (KeyPressed, ReadKey).
      Interruptions inconnues -> appel Intr() ou inline ASM.

  19. [A FAIRE] Traduction des modes d'adressage en syntaxe Pascal.
      [BX+SI+disp] -> Mem[Seg:Ofs] ou acces tableau.
      [BP+n] avec n > 0 -> parametre de procedure (ParamN).
      [BP-n] -> variable locale (LocalN).
      [BX+disp] ou [SI+disp] -> acces a un tableau ou record.
      [EBX+ECX*4] -> tableau indexe : Tab[Index].
      WORD PTR [addr] -> MemW[Seg:Ofs] ou variable typee.
      DWORD PTR [addr] -> MemL[Seg:Ofs] ou pointeur.
      Detecter les patterns d'acces a des structures (records)
      et generer des types Record Pascal correspondants quand
      des offsets fixes sont utilises de facon repetee.

  20. [A FAIRE] Gestion des extensions 80386 en mode 32 bits.
      Gerer les registres 32 bits (EAX..EDI) comme LongInt.
      Prefixe 66h : basculement taille d'operande 16/32 bits.
      Prefixe 67h : basculement taille d'adresse 16/32 bits.
      Instructions specifiques 386+ : MOVZX, MOVSX, CWDE, CDQ,
      BSWAP (inversion endianness), BSF/BSR (recherche de bit),
      SETcc (positionner octet selon condition),
      CMOVcc (deplacement conditionnel), XADD, CMPXCHG,
      SHLD/SHRD (decalage double precision).
      Mode FLAT : pas de segments, adresses lineaires 32 bits,
      traduire en mode Protected avec uses Dos, WinAPI, etc.

  21. [A FAIRE] Generation du code Pascal : en-tete, uses, types et declarations.
      Emettre l'en-tete du fichier Pascal : Program <nom>;
      clause Uses (Dos, Crt, etc. selon les INT detectees),
      section Type (records pour les structures detectees,
      tableaux pour les zones de donnees), section Const
      (constantes EQU et donnees en lecture seule), section
      Var (variables globales pour les registres simules et
      les donnees du segment DATA). Generer les declarations
      Label pour les Goto encore necessaires apres l'analyse
      de flux de controle.

  22. [A FAIRE] Generation du code Pascal : corps des procedures et fonctions.
      Pour chaque procedure ASM, generer une procedure ou
      fonction Pascal avec ses parametres et variables locales.
      Emettre le code traduit instruction par instruction dans
      le corps de la procedure. Gerer la valeur de retour :
      si AX/EAX est charge avant RET, generer une Function
      avec Result := RegAX. Imbriquer les structures de controle
      detectees (If/Then/Else, While, Repeat, For, Case).
      Generer le bloc BEGIN..END principal pour le point
      d'entree du programme.

  23. [A FAIRE] Fallback ASM inline pour les instructions non-traduisibles.
      Pour les instructions qui n'ont pas d'equivalent Pascal
      direct (CLI, STI, HLT, IN, OUT, CPUID, RDTSC, instructions
      FPU x87, etc.), generer un bloc ASM inline Turbo Pascal :
      asm ... end; ou directive ASMMODE INTEL pour Free Pascal.
      Regrouper les instructions inline consecutives dans un seul
      bloc asm. Inserer un commentaire avertissant que le code
      n'a pas pu etre traduit. Gerer les interruptions non
      reconnues avec Intr(IntNo, Regs) en utilisant les Registers.

  24. [A FAIRE] Passes d'optimisation sur le code Pascal genere.
      Optimiser le code Pascal genere en plusieurs passes :
      (a) Elimination des variables de registre inutilisees.
      (b) Propagation des constantes (RegAX := 0; x := RegAX -> x := 0).
      (c) Simplification des expressions (x := x + 0 -> rien,
      x := x + 1 -> Inc(x), x := x - 1 -> Dec(x)).
      (d) Remplacement des Goto par des structures de controle
      quand le graphe de flux le permet.
      (e) Fusion des affectations de sous-registres
      (Lo(RegAX) := val; Hi(RegAX) := 0 -> RegAX := Word(val)).
      (f) Detection de patterns idiomatiques connus (XOR AX,AX -> := 0).

  25. [A FAIRE] Options de sortie, verification finale et rapport.
      Verifier la coherence du fichier .PAS genere : toutes les
      references sont resolues, les procedures ont un ENDP
      correspondant, les types sont coherents. Afficher un rapport
      final : nombre d'instructions traduites, nombre de procedures
      generees, nombre de variables declarees, nombre d'instructions
      en ASM inline (non traduites), pourcentage de traduction
      reussie. Si -v est active, afficher des statistiques
      detaillees. Gerer le code de retour (0=succes, 1=erreur).
}

Program ASM2PAS;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

Const
 MAX_SYMBOLS = 4096;
 MAX_LABELS  = 2048;
 MAX_PROCS   = 512;
 MAX_LINES   = 65536;
 MAX_VARS    = 2048;
 MAX_PARAMS  = 32;
 MAX_TOKENS  = 64;

 { Types de tokens }
 TK_NONE      = 0;
 TK_IDENT     = 1;
 TK_NUMBER    = 2;
 TK_STRING    = 3;
 TK_REGISTER  = 4;
 TK_MNEMONIC  = 5;
 TK_DIRECTIVE = 6;
 TK_LABEL     = 7;
 TK_COMMA     = 8;
 TK_LBRACKET  = 9;
 TK_RBRACKET  = 10;
 TK_PLUS      = 11;
 TK_MINUS     = 12;
 TK_STAR      = 13;
 TK_COLON     = 14;
 TK_COMMENT   = 15;
 TK_EOL       = 16;

 { Types de symboles }
 SY_LABEL   = 0;
 SY_PROC    = 1;
 SY_VAR     = 2;
 SY_CONST   = 3;
 SY_SEGMENT = 4;
 SY_PARAM   = 5;

 { Types de donnees Pascal }
 PT_BYTE     = 0;
 PT_SHORTINT = 1;
 PT_WORD     = 2;
 PT_INTEGER  = 3;
 PT_LONGINT  = 4;
 PT_BOOLEAN  = 5;
 PT_CHAR     = 6;
 PT_STRING   = 7;
 PT_POINTER  = 8;
 PT_PCHAR    = 9;
 PT_ARRAY    = 10;

 { Types d'operandes }
 OT_NONE    = 0;
 OT_REG8    = 1;
 OT_REG16   = 2;
 OT_REG32   = 3;
 OT_SEGREG  = 4;
 OT_MEM     = 5;
 OT_IMM8    = 6;
 OT_IMM16   = 7;
 OT_IMM32   = 8;
 OT_LABEL   = 9;

Type
 TToken = Record
  Kind:Byte;
  Value:String;
 End;

 TSymbol = Record
  Name:String;
  SymType:Byte;
  DataType:Byte;
  Size:Word;
  Offset:LongInt;
  Segment:String;
  IsPublic:Boolean;
  IsExtern:Boolean;
 End;

 TOperand = Record
  OpType:Byte;
  Reg:String;
  Imm:LongInt;
  MemExpr:String;
  Size:Byte;
  LabelName:String;
 End;

 TAsmLine = Record
  LabelStr:String;
  Mnemonic:String;
  Op1,Op2:TOperand;
  Comment:String;
  LineNum:LongInt;
  IsDirective:Boolean;
  IsTranslated:Boolean;
 End;

 TProcInfo = Record
  Name:String;
  IsFunction:Boolean;
  IsNear:Boolean;
  Convention:Byte;
  ParamCount:Byte;
  LocalSize:Word;
  StartLine:LongInt;
  EndLine:LongInt;
 End;

Var
 InFileName,OutFileName:String;
 Mode32:Boolean;
 UseInline:Boolean;
 Verbose:Boolean;
 AddComments:Boolean;
 InFile,OutFile:Text;
 Symbols:Array[1..MAX_SYMBOLS] of TSymbol;
 SymbolCount:Integer;
 Procs:Array[1..MAX_PROCS] of TProcInfo;
 ProcCount:Integer;
 TotalInstructions:LongInt;
 TranslatedInstructions:LongInt;
 InlineInstructions:LongInt;
 TotalProcs:LongInt;
 TotalVars:LongInt;
 TotalLabels:LongInt;

{ ============================================================
  Fonctions utilitaires
  ============================================================ }

Function UpCaseStr(S:String):String;
Var
 I:Integer;
 R:String;
Begin
 R:='';
 For I:=1 to Length(S) do R:=R+UpCase(S[I]);
 UpCaseStr:=R;
End;

Function Trim(S:String):String;
Var
 I,J:Integer;
Begin
 I:=1;
 While(I<=Length(S))and(S[I]=' ')do Inc(I);
 J:=Length(S);
 While(J>=1)and(J>=I)and(S[J]=' ')do Dec(J);
 Trim:=Copy(S,I,J-I+1);
End;

Function IntToStr(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntToStr:=S;
End;

Function HexByte(B:Byte):String;
Const
 HexChars:Array[0..15] of Char = '0123456789ABCDEF';
Begin
 HexByte:=HexChars[B shr 4]+HexChars[B and $0F];
End;

Function HexWord(W:Word):String;
Begin
 HexWord:=HexByte(Hi(W))+HexByte(Lo(W));
End;

Function HexToInt(S:String):LongInt;
Var
 I:Integer;
 R:LongInt;
 C:Char;
Begin
 R:=0;
 S:=UpCaseStr(S);
 For I:=1 to Length(S) do Begin
  C:=S[I];
  If(C>='0')and(C<='9')Then R:=R*16+Ord(C)-Ord('0')
  Else If(C>='A')and(C<='F')Then R:=R*16+Ord(C)-Ord('A')+10;
 End;
 HexToInt:=R;
End;

Function FileExists(FileName:String):Boolean;
Var
 F:File;
Begin
 Assign(F,FileName);
 {$I-}Reset(F);{$I+}
 If IoResult=0 Then Begin
  Close(F);
  FileExists:=True;
 End
 Else FileExists:=False;
End;

Function ChangeFileExt(FileName,NewExt:String):String;
Var
 I:Integer;
 Base:String;
Begin
 Base:=FileName;
 For I:=Length(FileName) downto 1 do Begin
  If FileName[I]='.' Then Begin
   Base:=Copy(FileName,1,I-1);
   Break;
  End;
  If(FileName[I]='\')or(FileName[I]='/')Then Break;
 End;
 ChangeFileExt:=Base+NewExt;
End;

{ ============================================================
  Programme principal
  ============================================================ }

Procedure ShowHelp;
Begin
 WriteLn('ASM2PAS : Transpileur d''Assembleur 8086/80386 vers Pascal (Turbo Pascal)');
 WriteLn;
 WriteLn('Syntaxe : ASM2PAS [options] fichier.ASM [fichier.PAS]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -16        Forcer le mode 16 bits (8086)');
 WriteLn('  -32        Forcer le mode 32 bits (80386)');
 WriteLn('  -inline    Garder le code non-traduisible en ASM inline');
 WriteLn('  -comments  Inclure le code ASM original en commentaire');
 WriteLn('  -v         Mode verbeux');
 WriteLn('  -h, --help Afficher cette aide');
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 Param:String;
Begin
 InFileName:='';
 OutFileName:='';
 Mode32:=False;
 UseInline:=True;
 Verbose:=False;
 AddComments:=False;
 For I:=1 to ParamCount do Begin
  Param:=ParamStr(I);
  If(Param='-h')or(Param='--help')or(Param='/?')Then Begin
   ShowHelp;
   Halt(0);
  End
  Else If Param='-16' Then Mode32:=False
  Else If Param='-32' Then Mode32:=True
  Else If Param='-inline' Then UseInline:=True
  Else If Param='-comments' Then AddComments:=True
  Else If Param='-v' Then Verbose:=True
  Else If InFileName='' Then InFileName:=Param
  Else If OutFileName='' Then OutFileName:=Param;
 End;
 If InFileName='' Then Begin
  ShowHelp;
  Halt(1);
 End;
 If OutFileName='' Then OutFileName:=ChangeFileExt(InFileName,'.PAS');
End;

{ ============================================================
  Point d'entree
  ============================================================ }

BEGIN
 ParseCommandLine;
 If Not FileExists(InFileName) Then Begin
  WriteLn('Erreur : Fichier introuvable : ',InFileName);
  Halt(1);
 End;
 { Initialisation }
 SymbolCount:=0;
 ProcCount:=0;
 TotalInstructions:=0;
 TranslatedInstructions:=0;
 InlineInstructions:=0;
 TotalProcs:=0;
 TotalVars:=0;
 TotalLabels:=0;
 If Verbose Then Begin
  WriteLn('ASM2PAS - Transpileur Assembleur 8086/80386 vers Pascal');
  WriteLn('Fichier source    : ',InFileName);
  WriteLn('Fichier de sortie : ',OutFileName);
  If Mode32 Then WriteLn('Mode : 32 bits (80386)')
            Else WriteLn('Mode : 16 bits (8086)');
 End;
 { TODO 2  - Analyseur lexical }
 { TODO 3  - Analyse des directives }
 { TODO 4  - Analyse des donnees }
 { TODO 5  - Analyse des procedures }
 { TODO 6  - Table des symboles }
 { TODO 7  - Analyse des operandes }
 { TODO 8  - Inference de types }
 { TODO 9  - Traduction des registres }
 { TODO 10 - Traduction des transferts }
 { TODO 11 - Traduction arithmetique }
 { TODO 12 - Traduction logique }
 { TODO 13 - Traduction comparaisons/sauts }
 { TODO 14 - Traduction boucles }
 { TODO 15 - Traduction CALL/RET }
 { TODO 16 - Traduction PUSH/POP }
 { TODO 17 - Traduction chaines }
 { TODO 18 - Traduction INT systeme }
 { TODO 19 - Traduction adressage }
 { TODO 20 - Extensions 80386 }
 { TODO 21 - Generation en-tete Pascal }
 { TODO 22 - Generation corps procedures }
 { TODO 23 - Fallback ASM inline }
 { TODO 24 - Optimisation }
 { TODO 25 - Verification et rapport }
 WriteLn('Transpilation terminee.');
END.
