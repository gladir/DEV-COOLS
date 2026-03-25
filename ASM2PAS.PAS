{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpileur d'assembleur 8086/80386 (syntaxe MASM/TASM)
                en langage de programmation Pascal (Turbo Pascal)
}

{ TODO - Liste des 25 points a implementer pour le transpileur ASM vers Pascal :

  1.  [IMPLEMENTE] Infrastructure, options de ligne de commande et constantes globales.
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

  2.  [IMPLEMENTE] Analyseur lexical (tokenizer) du code assembleur.
      Lire le fichier .ASM ligne par ligne et decouper chaque
      ligne en tokens : labels (identificateur suivi de ':'),
      mnemoniques d'instructions, operandes (registres, memoire,
      immediats), virgules, crochets, operateurs (+, -, *),
      commentaires (';' jusqu'a fin de ligne), chaines entre
      guillemets simples ou doubles. Gerer les continuations
      de ligne avec '\'. Ignorer les lignes vides et les
      lignes ne contenant que des commentaires.

  3.  [IMPLEMENTE] Analyse des directives d'assemblage (segments et modeles).
      Reconnaitre les directives MASM/TASM : .MODEL (SMALL,
      COMPACT, MEDIUM, LARGE, HUGE, FLAT), .STACK, .CODE,
      .DATA, .DATA?, .CONST, .FARDATA, SEGMENT/ENDS avec
      attributs (PARA, PUBLIC, 'CLASS'), GROUP, ASSUME,
      .8086, .286, .386, .486, .586, OPTION CASEMAP:NONE.
      Determiner le mode 16 ou 32 bits a partir du modele
      memoire et des directives de processeur.

  4.  [IMPLEMENTE] Analyse des directives de donnees (DB, DW, DD, DQ, DT).
      Reconnaitre les declarations de donnees : DB (octet),
      DW (mot 16 bits), DD (double mot 32 bits), DQ (quad mot
      64 bits), DT (10 octets). Gerer les valeurs multiples
      separees par des virgules, les chaines entre guillemets,
      les expressions DUP (count DUP(valeur)), les operateurs
      OFFSET et SEG. Convertir en declarations Pascal :
      DB -> Byte, DW -> Word, DD -> LongInt, chaines -> String,
      tableaux -> Array[..] of Byte/Word/LongInt.

  5.  [IMPLEMENTE] Analyse des directives de procedures (PROC/ENDP).
      Reconnaitre les directives PROC et ENDP pour delimiter les
      procedures et fonctions assembleur. Gerer les attributs
      NEAR et FAR, les conventions d'appel (C, PASCAL, STDCALL),
      les parametres declares avec PROC (nom:type) en syntaxe
      MASM 6+. Detecter les variables locales declarees avec
      LOCAL. Associer chaque ENDP a son PROC correspondant.
      Determiner si une procedure retourne une valeur (fonction)
      en analysant l'utilisation de AX/EAX avant RET.

  6.  [IMPLEMENTE] Table des symboles et gestion des identificateurs.
      Maintenir une table des symboles globale contenant :
      labels (adresses de saut), noms de procedures, noms de
      variables (donnees), constantes (EQU, =), segments,
      parametres de procedures. Chaque entree stocke : nom,
      type (label, proc, var, const, segment, param), taille
      en octets, offset, segment d'appartenance. Gerer la
      portee : symboles globaux (PUBLIC) et locaux (@@, LOCAL).
      Verifier les doublons et les references non resolues.

  7.  [IMPLEMENTE] Analyse des operandes et modes d'adressage.
      Parser les operandes des instructions : registres 8 bits
      (AL..BH), 16 bits (AX..DI), 32 bits (EAX..EDI), de
      segment (CS,DS,ES,SS,FS,GS), immediats decimaux et
      hexadecimaux (0FFh, 0xFF, 255), memoire directe ([1234h]),
      memoire indexee ([BX+SI+4], [EBX+ECX*4+8]),
      BYTE PTR / WORD PTR / DWORD PTR, OFFSET label,
      SEG label. Construire un arbre d'operande avec le type
      (reg, mem, imm), la taille et la valeur ou l'expression.

  8.  [IMPLEMENTE] Inference de types pour les variables et les registres.
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

{$A-}

Const
 ASM2PAS_VERSION = '1.0';
 ASM2PAS_DATE    = '2026-03-25';

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
 OT_OFFSET  = 10;
 OT_SEG     = 11;

 { Modeles memoire }
 MM_NONE    = 0;
 MM_TINY    = 1;
 MM_SMALL   = 2;
 MM_COMPACT = 3;
 MM_MEDIUM  = 4;
 MM_LARGE   = 5;
 MM_HUGE    = 6;
 MM_FLAT    = 7;

 { Sections courantes }
 SEC_NONE    = 0;
 SEC_CODE    = 1;
 SEC_DATA    = 2;
 SEC_DATAQ   = 3;
 SEC_CONST   = 4;
 SEC_STACK   = 5;
 SEC_FARDATA = 6;

 { Niveaux de processeur }
 CPU_8086 = 0;
 CPU_186  = 1;
 CPU_286  = 2;
 CPU_386  = 3;
 CPU_486  = 4;
 CPU_586  = 5;

 MAX_SEGMENTS = 64;
 MAX_DATAVARS = 4096;
 MAX_DATAELEMS = 256;

 { Types de directives de donnees }
 DT_NONE = 0;
 DT_DB   = 1;
 DT_DW   = 2;
 DT_DD   = 3;
 DT_DQ   = 4;
 DT_DF   = 5;
 DT_DT   = 6;

 { Types d'elements de donnees }
 DE_NUMBER  = 0;
 DE_STRING  = 1;
 DE_DUP     = 2;
 DE_OFFSET  = 3;
 DE_SEG     = 4;
 DE_UNINIT  = 5;
 DE_EXPR    = 6;

 { Conventions d'appel (TODO 5) }
 CC_NONE    = 0;
 CC_C       = 1;
 CC_PASCAL  = 2;
 CC_STDCALL = 3;
 CC_BASIC   = 4;
 CC_FORTRAN = 5;
 CC_SYSCALL = 6;

 MAX_LOCALS = 64;

Type
 TProcParam = Record
  Name:String;
  TypeName:String;
  PascalType:Byte;
  Size:Word;
 End;

 TProcLocal = Record
  Name:String;
  TypeName:String;
  PascalType:Byte;
  Size:Word;
  Count:Word;
 End;

 TSegmentInfo = Record
  Name:String;
  ClassName:String;
  Align:String;
  Combine:String;
  Use32:Boolean;
  IsOpen:Boolean;
 End;

 TAssumeEntry = Record
  SegReg:String;
  SegName:String;
 End;
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
  { Champs memoire indexee (TODO 7) }
  BaseReg:String;
  IndexReg:String;
  Scale:Byte;
  Disp:LongInt;
  HasDisp:Boolean;
  SegOverride:String;
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
  Params:Array[1..MAX_PARAMS] of TProcParam;
  LocalCount:Byte;
  Locals:Array[1..MAX_LOCALS] of TProcLocal;
  LocalSize:Word;
  StartLine:LongInt;
  EndLine:LongInt;
  UsesAX:Boolean;
  IsPublic:Boolean;
 End;

 TDataElem = Record
  ElemType:Byte;
  NumValue:LongInt;
  StrValue:String;
  DupCount:LongInt;
  DupValue:LongInt;
  DupIsUninit:Boolean;
 End;

 TDataVar = Record
  Name:String;
  DirType:Byte;
  PascalType:Byte;
  ElemSize:Word;
  Elements:Array[1..MAX_DATAELEMS] of TDataElem;
  ElemCount:Integer;
  TotalSize:LongInt;
  Section:Byte;
  SrcLine:LongInt;
  IsPublic:Boolean;
 End;

 PStr = ^String;

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
 Tokens:Array[1..MAX_TOKENS] of TToken;
 TokenCount:Integer;
 SrcLines:Array[0..MAX_LINES-1] of PStr;
 SrcLineNums:Array[0..MAX_LINES-1] of LongInt;
 SrcLineCount:LongInt;
 { Etat des directives (TODO 3) }
 MemoryModel:Byte;
 CpuLevel:Byte;
 CurrentSection:Byte;
 StackSize:Word;
 CaseSensitive:Boolean;
 HasModelDirective:Boolean;
 EntryPoint:String;
 Segments:Array[1..MAX_SEGMENTS] of TSegmentInfo;
 SegmentCount:Integer;
 Assumes:Array[1..6] of TAssumeEntry;
 GroupName:String;
 GroupSegments:String;
 { Donnees (TODO 4) }
 DataVars:Array[1..MAX_DATAVARS] of TDataVar;
 DataVarCount:Integer;

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

Function HexDWord(D:LongInt):String;
Begin
 HexDWord:=HexWord(Word(D shr 16))+HexWord(Word(D and $FFFF));
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
  Analyseur lexical (tokenizer) - TODO 2
  ============================================================ }

Function IsIdentStart(C:Char):Boolean;
Begin
 IsIdentStart:=(C='_')or(C='.')or(C='@')or(C='?')or
  ((C>='A')and(C<='Z'))or((C>='a')and(C<='z'));
End;

Function IsIdentChar(C:Char):Boolean;
Begin
 IsIdentChar:=(C='_')or(C='@')or(C='?')or
  ((C>='A')and(C<='Z'))or((C>='a')and(C<='z'))or
  ((C>='0')and(C<='9'));
End;

Function IsDigit(C:Char):Boolean;
Begin
 IsDigit:=(C>='0')and(C<='9');
End;

Function IsHexDigit(C:Char):Boolean;
Var
 U:Char;
Begin
 U:=UpCase(C);
 IsHexDigit:=((U>='0')and(U<='9'))or((U>='A')and(U<='F'));
End;

Function IsRegister(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsRegister:=
  { Registres 8 bits }
  (U='AL')or(U='AH')or(U='BL')or(U='BH')or
  (U='CL')or(U='CH')or(U='DL')or(U='DH')or
  { Registres 16 bits }
  (U='AX')or(U='BX')or(U='CX')or(U='DX')or
  (U='SI')or(U='DI')or(U='BP')or(U='SP')or
  { Registres de segment }
  (U='CS')or(U='DS')or(U='ES')or(U='SS')or(U='FS')or(U='GS')or
  { Registres 32 bits }
  (U='EAX')or(U='EBX')or(U='ECX')or(U='EDX')or
  (U='ESI')or(U='EDI')or(U='EBP')or(U='ESP');
End;

Function IsMnemonic(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsMnemonic:=
  { Transfert de donnees }
  (U='MOV')or(U='MOVZX')or(U='MOVSX')or(U='XCHG')or
  (U='LEA')or(U='LDS')or(U='LES')or(U='LFS')or(U='LGS')or
  (U='CBW')or(U='CWD')or(U='CWDE')or(U='CDQ')or
  (U='LAHF')or(U='SAHF')or
  { Arithmetique }
  (U='ADD')or(U='ADC')or(U='SUB')or(U='SBB')or
  (U='INC')or(U='DEC')or(U='NEG')or
  (U='MUL')or(U='IMUL')or(U='DIV')or(U='IDIV')or
  (U='DAA')or(U='DAS')or(U='AAA')or(U='AAS')or(U='AAM')or(U='AAD')or
  { Logique }
  (U='AND')or(U='OR')or(U='XOR')or(U='NOT')or(U='TEST')or
  { Decalage et rotation }
  (U='SHL')or(U='SHR')or(U='SAL')or(U='SAR')or
  (U='ROL')or(U='ROR')or(U='RCL')or(U='RCR')or
  (U='SHLD')or(U='SHRD')or
  { Operations sur bits }
  (U='BT')or(U='BTS')or(U='BTR')or(U='BTC')or
  (U='BSF')or(U='BSR')or(U='BSWAP')or
  { Comparaison }
  (U='CMP')or
  { Sauts }
  (U='JMP')or(U='JE')or(U='JNE')or(U='JZ')or(U='JNZ')or
  (U='JA')or(U='JAE')or(U='JB')or(U='JBE')or
  (U='JG')or(U='JGE')or(U='JL')or(U='JLE')or
  (U='JNA')or(U='JNAE')or(U='JNB')or(U='JNBE')or
  (U='JNG')or(U='JNGE')or(U='JNL')or(U='JNLE')or
  (U='JC')or(U='JNC')or(U='JO')or(U='JNO')or
  (U='JS')or(U='JNS')or(U='JP')or(U='JNP')or
  (U='JPE')or(U='JPO')or(U='JCXZ')or(U='JECXZ')or
  { Boucles }
  (U='LOOP')or(U='LOOPE')or(U='LOOPZ')or
  (U='LOOPNE')or(U='LOOPNZ')or
  { Appels et retours }
  (U='CALL')or(U='RET')or(U='RETF')or(U='RETN')or(U='IRET')or
  { Pile }
  (U='PUSH')or(U='POP')or(U='PUSHA')or(U='POPA')or
  (U='PUSHAD')or(U='POPAD')or(U='PUSHF')or(U='POPF')or
  (U='PUSHFD')or(U='POPFD')or
  { Operations sur chaines }
  (U='MOVSB')or(U='MOVSW')or(U='MOVSD')or
  (U='CMPSB')or(U='CMPSW')or(U='CMPSD')or
  (U='LODSB')or(U='LODSW')or(U='LODSD')or
  (U='STOSB')or(U='STOSW')or(U='STOSD')or
  (U='SCASB')or(U='SCASW')or(U='SCASD')or
  { Prefixes }
  (U='REP')or(U='REPE')or(U='REPZ')or
  (U='REPNE')or(U='REPNZ')or(U='LOCK')or
  { Interruptions }
  (U='INT')or(U='INTO')or
  { Flags }
  (U='CLC')or(U='STC')or(U='CMC')or
  (U='CLD')or(U='STD')or(U='CLI')or(U='STI')or
  { Divers }
  (U='NOP')or(U='HLT')or(U='WAIT')or(U='FWAIT')or
  (U='ENTER')or(U='LEAVE')or(U='XLAT')or(U='XLATB')or
  { Entrees/Sorties }
  (U='IN')or(U='OUT')or(U='INSB')or(U='INSW')or
  (U='OUTSB')or(U='OUTSW')or
  { SETcc }
  (U='SETE')or(U='SETNE')or(U='SETZ')or(U='SETNZ')or
  (U='SETA')or(U='SETAE')or(U='SETB')or(U='SETBE')or
  (U='SETG')or(U='SETGE')or(U='SETL')or(U='SETLE')or
  (U='SETC')or(U='SETNC')or(U='SETO')or(U='SETNO')or
  (U='SETS')or(U='SETNS')or
  { CMOVcc }
  (U='CMOVE')or(U='CMOVNE')or(U='CMOVZ')or(U='CMOVNZ')or
  (U='CMOVA')or(U='CMOVAE')or(U='CMOVB')or(U='CMOVBE')or
  (U='CMOVG')or(U='CMOVGE')or(U='CMOVL')or(U='CMOVLE')or
  { Systeme }
  (U='CPUID')or(U='RDTSC')or(U='RDMSR')or(U='WRMSR')or
  (U='INVD')or(U='WBINVD')or
  { Echange }
  (U='XADD')or(U='CMPXCHG');
End;

Function IsDirective(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsDirective:=
  { Modeles et segments }
  (U='.MODEL')or(U='.STACK')or(U='.CODE')or
  (U='.DATA')or(U='.DATA?')or(U='.CONST')or
  (U='.FARDATA')or(U='.FARDATA?')or
  (U='SEGMENT')or(U='ENDS')or(U='GROUP')or(U='ASSUME')or
  { Processeur }
  (U='.8086')or(U='.186')or(U='.286')or(U='.286C')or(U='.286P')or
  (U='.386')or(U='.386C')or(U='.386P')or
  (U='.486')or(U='.486P')or(U='.586')or(U='.586P')or
  (U='OPTION')or
  { Procedures }
  (U='PROC')or(U='ENDP')or
  { Donnees }
  (U='DB')or(U='DW')or(U='DD')or(U='DQ')or(U='DF')or(U='DT')or
  (U='EQU')or
  { Visibilite }
  (U='PUBLIC')or(U='EXTRN')or(U='EXTERN')or
  { Inclusion }
  (U='INCLUDE')or(U='INCLUDELIB')or
  { Divers }
  (U='LOCAL')or(U='END')or(U='ORG')or(U='ALIGN')or(U='EVEN')or
  (U='TITLE')or(U='NAME')or(U='PAGE')or
  { Assemblage conditionnel }
  (U='IF')or(U='IFDEF')or(U='IFNDEF')or(U='ELSE')or(U='ENDIF')or
  { Macros }
  (U='MACRO')or(U='ENDM')or(U='REPT')or(U='IRP')or(U='IRPC');
End;

Function ClassifyIdent(S:String):Byte;
Begin
 If IsRegister(S) Then ClassifyIdent:=TK_REGISTER
 Else If IsDirective(S) Then ClassifyIdent:=TK_DIRECTIVE
 Else If IsMnemonic(S) Then ClassifyIdent:=TK_MNEMONIC
 Else ClassifyIdent:=TK_IDENT;
End;

Procedure AddToken(Kind:Byte;Value:String);
Begin
 If TokenCount<MAX_TOKENS Then Begin
  Inc(TokenCount);
  Tokens[TokenCount].Kind:=Kind;
  Tokens[TokenCount].Value:=Value;
 End;
End;

Procedure TokenizeLine(Line:String);
Var
 I:Integer;
 C:Char;
 S:String;
Begin
 TokenCount:=0;
 I:=1;
 While(I<=Length(Line))and(TokenCount<MAX_TOKENS)do Begin
  C:=Line[I];
  { Espace et tabulation }
  If(C=' ')or(C=#9)Then Begin
   Inc(I);
   Continue;
  End;
  { Commentaire : ';' jusqu'a la fin de ligne }
  If C=';' Then Begin
   AddToken(TK_COMMENT,Copy(Line,I+1,Length(Line)-I));
   Break;
  End;
  { Chaine entre guillemets simples }
  If C='''' Then Begin
   S:='';
   Inc(I);
   While I<=Length(Line) do Begin
    If Line[I]='''' Then Begin
     If(I<Length(Line))and(Line[I+1]='''')Then Begin
      S:=S+'''';
      Inc(I,2);
     End Else Begin
      Inc(I);
      Break;
     End;
    End Else Begin
     S:=S+Line[I];
     Inc(I);
    End;
   End;
   AddToken(TK_STRING,S);
   Continue;
  End;
  { Chaine entre guillemets doubles }
  If C='"' Then Begin
   S:='';
   Inc(I);
   While(I<=Length(Line))and(Line[I]<>'"')do Begin
    S:=S+Line[I];
    Inc(I);
   End;
   If I<=Length(Line) Then Inc(I);
   AddToken(TK_STRING,S);
   Continue;
  End;
  { Prefixe hexadecimal Pascal : $ABCD }
  If C='$' Then Begin
   If(I<Length(Line))and IsHexDigit(Line[I+1])Then Begin
    S:='$';
    Inc(I);
    While(I<=Length(Line))and IsHexDigit(Line[I])do Begin
     S:=S+Line[I];
     Inc(I);
    End;
    AddToken(TK_NUMBER,S);
   End Else Begin
    AddToken(TK_IDENT,'$');
    Inc(I);
   End;
   Continue;
  End;
  { Nombre : decimal, hex MASM (0FFh), hex C (0x1234) }
  If IsDigit(C) Then Begin
   S:='';
   If(C='0')and(I<Length(Line))and
     ((Line[I+1]='x')or(Line[I+1]='X'))Then Begin
    { Hex C : 0x1234 }
    S:='0x';
    Inc(I,2);
    While(I<=Length(Line))and IsHexDigit(Line[I])do Begin
     S:=S+Line[I];
     Inc(I);
    End;
   End Else Begin
    { Decimal ou hex MASM (0FFh) }
    While(I<=Length(Line))and IsHexDigit(Line[I])do Begin
     S:=S+Line[I];
     Inc(I);
    End;
    If(I<=Length(Line))and((Line[I]='h')or(Line[I]='H'))Then Begin
     S:=S+'h';
     Inc(I);
    End;
   End;
   AddToken(TK_NUMBER,S);
   Continue;
  End;
  { Identificateur, registre, mnemonique, directive, label }
  If IsIdentStart(C) Then Begin
   S:=C;
   Inc(I);
   While(I<=Length(Line))and IsIdentChar(Line[I])do Begin
    S:=S+Line[I];
    Inc(I);
   End;
   { Directives avec suffixe '?' (.DATA?, .FARDATA?) }
   If(Length(S)>1)and(S[1]='.')and
     (I<=Length(Line))and(Line[I]='?')Then Begin
    S:=S+'?';
    Inc(I);
   End;
   { Label : identificateur suivi de ':' }
   If(I<=Length(Line))and(Line[I]=':')Then Begin
    Inc(I);
    AddToken(TK_LABEL,S);
    Continue;
   End;
   { Classifier l'identificateur }
   AddToken(ClassifyIdent(S),S);
   Continue;
  End;
  { Operateurs et ponctuation }
  Case C of
   ',':AddToken(TK_COMMA,',');
   '[':AddToken(TK_LBRACKET,'[');
   ']':AddToken(TK_RBRACKET,']');
   '+':AddToken(TK_PLUS,'+');
   '-':AddToken(TK_MINUS,'-');
   '*':AddToken(TK_STAR,'*');
   ':':AddToken(TK_COLON,':');
  End;
  Inc(I);
 End;
End;

Function GetTokenName(Kind:Byte):String;
Begin
 Case Kind of
  TK_NONE:GetTokenName:='NONE';
  TK_IDENT:GetTokenName:='IDENT';
  TK_NUMBER:GetTokenName:='NUMBER';
  TK_STRING:GetTokenName:='STRING';
  TK_REGISTER:GetTokenName:='REGISTER';
  TK_MNEMONIC:GetTokenName:='MNEMONIC';
  TK_DIRECTIVE:GetTokenName:='DIRECTIVE';
  TK_LABEL:GetTokenName:='LABEL';
  TK_COMMA:GetTokenName:='COMMA';
  TK_LBRACKET:GetTokenName:='LBRACKET';
  TK_RBRACKET:GetTokenName:='RBRACKET';
  TK_PLUS:GetTokenName:='PLUS';
  TK_MINUS:GetTokenName:='MINUS';
  TK_STAR:GetTokenName:='STAR';
  TK_COLON:GetTokenName:='COLON';
  TK_COMMENT:GetTokenName:='COMMENT';
  TK_EOL:GetTokenName:='EOL';
  Else GetTokenName:='?';
 End;
End;

Procedure ReadASMFile;
Var
 Line,CurLine:String;
 FileLineNum:LongInt;
 HasContinuation:Boolean;
 LabelCnt,InstrCnt,DirCnt,CommentCnt:LongInt;
 I,NonComment:Integer;
Begin
 SrcLineCount:=0;
 LabelCnt:=0;
 InstrCnt:=0;
 DirCnt:=0;
 CommentCnt:=0;
 Assign(InFile,InFileName);
 {$I-}Reset(InFile);{$I+}
 If IoResult<>0 Then Begin
  WriteLn('Erreur : Impossible d''ouvrir ',InFileName);
  Halt(1);
 End;
 FileLineNum:=0;
 CurLine:='';
 HasContinuation:=False;
 While Not Eof(InFile) do Begin
  ReadLn(InFile,Line);
  Inc(FileLineNum);
  { Gestion des continuations de ligne avec '\' }
  If HasContinuation Then
   CurLine:=CurLine+' '+Trim(Line)
  Else
   CurLine:=Line;
  If(Length(CurLine)>0)and(CurLine[Length(CurLine)]='\')Then Begin
   CurLine:=Copy(CurLine,1,Length(CurLine)-1);
   HasContinuation:=True;
   Continue;
  End;
  HasContinuation:=False;
  { Tokeniser la ligne }
  TokenizeLine(CurLine);
  { Compter les tokens non-commentaires }
  NonComment:=0;
  For I:=1 to TokenCount do
   If Tokens[I].Kind<>TK_COMMENT Then Inc(NonComment);
  { Ignorer les lignes vides et les lignes de commentaire seul }
  If NonComment=0 Then Begin
   If TokenCount>0 Then Inc(CommentCnt);
   Continue;
  End;
  { Stocker la ligne source }
  If SrcLineCount<MAX_LINES Then Begin
   New(SrcLines[SrcLineCount]);
   SrcLines[SrcLineCount]^:=CurLine;
   SrcLineNums[SrcLineCount]:=FileLineNum;
   Inc(SrcLineCount);
   { Compter les statistiques par type de token }
   For I:=1 to TokenCount do Begin
    Case Tokens[I].Kind of
     TK_LABEL:Inc(LabelCnt);
     TK_MNEMONIC:Inc(InstrCnt);
     TK_DIRECTIVE:Inc(DirCnt);
    End;
   End;
  End;
 End;
 Close(InFile);
 WriteLn('Lecture de ',InFileName,' : ',FileLineNum,' lignes, ',
         SrcLineCount,' lignes utiles.');
 If Verbose Then Begin
  WriteLn('  Labels       : ',LabelCnt);
  WriteLn('  Instructions : ',InstrCnt);
  WriteLn('  Directives   : ',DirCnt);
  WriteLn('  Commentaires : ',CommentCnt);
 End;
End;

Procedure FreeSourceLines;
Var
 I:LongInt;
Begin
 For I:=0 to SrcLineCount-1 do Begin
  If SrcLines[I]<>Nil Then Dispose(SrcLines[I]);
  SrcLines[I]:=Nil;
 End;
 SrcLineCount:=0;
End;

{ ============================================================
  Analyse des directives d'assemblage - TODO 3
  ============================================================ }

Function ModelName(M:Byte):String;
Begin
 Case M of
  MM_TINY:ModelName:='TINY';
  MM_SMALL:ModelName:='SMALL';
  MM_COMPACT:ModelName:='COMPACT';
  MM_MEDIUM:ModelName:='MEDIUM';
  MM_LARGE:ModelName:='LARGE';
  MM_HUGE:ModelName:='HUGE';
  MM_FLAT:ModelName:='FLAT';
  Else ModelName:='NONE';
 End;
End;

Function SectionName(S:Byte):String;
Begin
 Case S of
  SEC_CODE:SectionName:='CODE';
  SEC_DATA:SectionName:='DATA';
  SEC_DATAQ:SectionName:='DATA?';
  SEC_CONST:SectionName:='CONST';
  SEC_STACK:SectionName:='STACK';
  SEC_FARDATA:SectionName:='FARDATA';
  Else SectionName:='NONE';
 End;
End;

Function CpuName(C:Byte):String;
Begin
 Case C of
  CPU_8086:CpuName:='8086';
  CPU_186:CpuName:='80186';
  CPU_286:CpuName:='80286';
  CPU_386:CpuName:='80386';
  CPU_486:CpuName:='80486';
  CPU_586:CpuName:='80586';
  Else CpuName:='8086';
 End;
End;

Procedure InitDirectiveState;
Var
 I:Integer;
Begin
 MemoryModel:=MM_NONE;
 CpuLevel:=CPU_8086;
 CurrentSection:=SEC_NONE;
 StackSize:=0;
 CaseSensitive:=False;
 HasModelDirective:=False;
 EntryPoint:='';
 SegmentCount:=0;
 GroupName:='';
 GroupSegments:='';
 For I:=1 to 6 do Begin
  Assumes[I].SegReg:='';
  Assumes[I].SegName:='';
 End;
End;

Function FindSegmentByName(Name:String):Integer;
Var
 I:Integer;
 U:String;
Begin
 U:=UpCaseStr(Name);
 FindSegmentByName:=0;
 For I:=1 to SegmentCount do
  If UpCaseStr(Segments[I].Name)=U Then Begin
   FindSegmentByName:=I;
   Exit;
  End;
End;

Procedure ProcessModelDirective;
{ Traite .MODEL SMALL, .MODEL FLAT, etc. }
Var
 I:Integer;
 U:String;
Begin
 If TokenCount<2 Then Exit;
 I:=2;
 While I<=TokenCount do Begin
  If Tokens[I].Kind=TK_COMMENT Then Break;
  If Tokens[I].Kind=TK_COMMA Then Begin
   Inc(I);
   Continue;
  End;
  U:=UpCaseStr(Tokens[I].Value);
  If U='TINY' Then MemoryModel:=MM_TINY
  Else If U='SMALL' Then MemoryModel:=MM_SMALL
  Else If U='COMPACT' Then MemoryModel:=MM_COMPACT
  Else If U='MEDIUM' Then MemoryModel:=MM_MEDIUM
  Else If U='LARGE' Then MemoryModel:=MM_LARGE
  Else If U='HUGE' Then MemoryModel:=MM_HUGE
  Else If U='FLAT' Then Begin
   MemoryModel:=MM_FLAT;
   Mode32:=True;
   If CpuLevel<CPU_386 Then CpuLevel:=CPU_386;
  End;
  Inc(I);
 End;
 HasModelDirective:=True;
 If Verbose Then
  WriteLn('  .MODEL ',ModelName(MemoryModel));
End;

Procedure ProcessProcessorDirective(Dir:String);
{ Traite .8086, .286, .386, .486, .586, etc. }
Var
 U:String;
Begin
 U:=UpCaseStr(Dir);
 If U='.8086' Then Begin
  CpuLevel:=CPU_8086;
  Mode32:=False;
 End
 Else If U='.186' Then Begin
  CpuLevel:=CPU_186;
  Mode32:=False;
 End
 Else If(U='.286')or(U='.286C')or(U='.286P')Then Begin
  CpuLevel:=CPU_286;
  Mode32:=False;
 End
 Else If(U='.386')or(U='.386C')or(U='.386P')Then Begin
  CpuLevel:=CPU_386;
  Mode32:=True;
 End
 Else If(U='.486')or(U='.486P')Then Begin
  CpuLevel:=CPU_486;
  Mode32:=True;
 End
 Else If(U='.586')or(U='.586P')Then Begin
  CpuLevel:=CPU_586;
  Mode32:=True;
 End;
 If Verbose Then
  WriteLn('  Processeur : ',CpuName(CpuLevel),
   ' (mode ',16+Ord(Mode32)*16,' bits)');
End;

Procedure ProcessSectionDirective(Dir:String);
{ Traite .CODE, .DATA, .DATA?, .CONST, .FARDATA, .STACK }
Var
 U:String;
 I:Integer;
Begin
 U:=UpCaseStr(Dir);
 If U='.CODE' Then CurrentSection:=SEC_CODE
 Else If U='.DATA' Then CurrentSection:=SEC_DATA
 Else If U='.DATA?' Then CurrentSection:=SEC_DATAQ
 Else If U='.CONST' Then CurrentSection:=SEC_CONST
 Else If U='.FARDATA' Then CurrentSection:=SEC_FARDATA
 Else If U='.FARDATA?' Then CurrentSection:=SEC_FARDATA
 Else If U='.STACK' Then Begin
  CurrentSection:=SEC_STACK;
  If(TokenCount>=2)and(Tokens[2].Kind=TK_NUMBER)Then Begin
   StackSize:=Word(HexToInt(Tokens[2].Value));
   If StackSize=0 Then Begin
    { Nombre decimal }
    Val(Tokens[2].Value,StackSize,I);
    If I<>0 Then StackSize:=256;
   End;
  End Else
   StackSize:=256;
  If Verbose Then
   WriteLn('  .STACK ',StackSize);
 End;
 If(U<>'.STACK')and Verbose Then
  WriteLn('  Section : ',SectionName(CurrentSection));
End;

Procedure ProcessSegmentDirective;
{ Traite: NomSeg SEGMENT [align] [combine] [use16/use32] ['class'] }
Var
 I,Idx:Integer;
 U,SegName_:String;
Begin
 If TokenCount<2 Then Exit;
 { Token 1 = nom du segment, Token 2 = SEGMENT }
 SegName_:=Tokens[1].Value;
 Idx:=FindSegmentByName(SegName_);
 If Idx=0 Then Begin
  If SegmentCount<MAX_SEGMENTS Then Begin
   Inc(SegmentCount);
   Idx:=SegmentCount;
   Segments[Idx].Name:=SegName_;
   Segments[Idx].ClassName:='';
   Segments[Idx].Align:='';
   Segments[Idx].Combine:='';
   Segments[Idx].Use32:=Mode32;
   Segments[Idx].IsOpen:=True;
  End Else Exit;
 End Else
  Segments[Idx].IsOpen:=True;
 { Parcourir les attributs }
 I:=3;
 While I<=TokenCount do Begin
  If Tokens[I].Kind=TK_COMMENT Then Break;
  U:=UpCaseStr(Tokens[I].Value);
  If(U='BYTE')or(U='WORD')or(U='DWORD')or(U='PARA')or(U='PAGE')Then
   Segments[Idx].Align:=U
  Else If(U='PUBLIC')or(U='COMMON')or(U='PRIVATE')or
        (U='STACK')or(U='MEMORY')or(U='AT')Then
   Segments[Idx].Combine:=U
  Else If U='USE16' Then
   Segments[Idx].Use32:=False
  Else If U='USE32' Then
   Segments[Idx].Use32:=True
  Else If Tokens[I].Kind=TK_STRING Then
   Segments[Idx].ClassName:=Tokens[I].Value;
  Inc(I);
 End;
 CurrentSection:=SEC_CODE;
 If Verbose Then Begin
  Write('  SEGMENT ',SegName_);
  If Segments[Idx].Align<>'' Then Write(' ',Segments[Idx].Align);
  If Segments[Idx].Combine<>'' Then Write(' ',Segments[Idx].Combine);
  If Segments[Idx].ClassName<>'' Then
   Write(' ''',Segments[Idx].ClassName,'''');
  If Segments[Idx].Use32 Then Write(' USE32')
                          Else Write(' USE16');
  WriteLn;
 End;
End;

Procedure ProcessEndsDirective;
{ Traite: NomSeg ENDS }
Var
 Idx:Integer;
Begin
 If TokenCount<2 Then Exit;
 Idx:=FindSegmentByName(Tokens[1].Value);
 If Idx>0 Then Begin
  Segments[Idx].IsOpen:=False;
  If Verbose Then
   WriteLn('  ENDS ',Segments[Idx].Name);
 End;
 CurrentSection:=SEC_NONE;
End;

Procedure ProcessAssumeDirective;
{ Traite: ASSUME CS:CSEG, DS:DSEG, ES:NOTHING, ... }
{ Note: CS:CSEG peut etre tokenise comme LABEL(CS) + IDENT(CSEG) }
{       ou REGISTER(CS) + COLON(:) + IDENT(CSEG) }
Var
 I,Idx:Integer;
 SegReg,SegTarget:String;
Begin
 I:=2;
 While I<=TokenCount do Begin
  If Tokens[I].Kind=TK_COMMENT Then Break;
  If Tokens[I].Kind=TK_COMMA Then Begin
   Inc(I);
   Continue;
  End;
  { Cas 1: tokenise comme LABEL(CS) suivi de IDENT(CSEG) }
  If Tokens[I].Kind=TK_LABEL Then Begin
   SegReg:=UpCaseStr(Tokens[I].Value);
   Idx:=0;
   If SegReg='CS' Then Idx:=1
   Else If SegReg='DS' Then Idx:=2
   Else If SegReg='ES' Then Idx:=3
   Else If SegReg='SS' Then Idx:=4
   Else If SegReg='FS' Then Idx:=5
   Else If SegReg='GS' Then Idx:=6;
   If(Idx>0)and(I+1<=TokenCount)Then Begin
    SegTarget:=UpCaseStr(Tokens[I+1].Value);
    Assumes[Idx].SegReg:=SegReg;
    If SegTarget='NOTHING' Then Assumes[Idx].SegName:=''
                           Else Assumes[Idx].SegName:=SegTarget;
    Inc(I,2);
   End Else
    Inc(I);
  End
  { Cas 2: tokenise comme REGISTER(CS) + COLON(:) + IDENT(CSEG) }
  Else If(I+2<=TokenCount)and(Tokens[I+1].Kind=TK_COLON)Then Begin
   SegReg:=UpCaseStr(Tokens[I].Value);
   SegTarget:=UpCaseStr(Tokens[I+2].Value);
   Idx:=0;
   If SegReg='CS' Then Idx:=1
   Else If SegReg='DS' Then Idx:=2
   Else If SegReg='ES' Then Idx:=3
   Else If SegReg='SS' Then Idx:=4
   Else If SegReg='FS' Then Idx:=5
   Else If SegReg='GS' Then Idx:=6;
   If Idx>0 Then Begin
    Assumes[Idx].SegReg:=SegReg;
    If SegTarget='NOTHING' Then Assumes[Idx].SegName:=''
                           Else Assumes[Idx].SegName:=SegTarget;
   End;
   Inc(I,3);
  End Else
   Inc(I);
 End;
 If Verbose Then Begin
  Write('  ASSUME');
  For Idx:=1 to 6 do
   If Assumes[Idx].SegReg<>'' Then Begin
    Write(' ',Assumes[Idx].SegReg,':');
    If Assumes[Idx].SegName<>'' Then Write(Assumes[Idx].SegName)
                                 Else Write('NOTHING');
   End;
  WriteLn;
 End;
End;

Procedure ProcessOptionDirective;
{ Traite: OPTION CASEMAP:NONE }
{ Note: CASEMAP:NONE peut etre tokenise comme LABEL(CASEMAP) + IDENT(NONE) }
{       ou IDENT(CASEMAP) + COLON(:) + IDENT(NONE) }
Var
 I:Integer;
 U:String;
Begin
 I:=2;
 While I<=TokenCount do Begin
  If Tokens[I].Kind=TK_COMMENT Then Break;
  { Cas 1: LABEL(CASEMAP) suivi de IDENT(NONE) }
  If(Tokens[I].Kind=TK_LABEL)and
    (UpCaseStr(Tokens[I].Value)='CASEMAP')Then Begin
   If(I+1<=TokenCount)and(UpCaseStr(Tokens[I+1].Value)='NONE')Then Begin
    CaseSensitive:=True;
    If Verbose Then
     WriteLn('  OPTION CASEMAP:NONE (sensible a la casse)');
   End;
   Inc(I,2);
   Continue;
  End;
  { Cas 2: IDENT(CASEMAP) + COLON(:) + IDENT(NONE) }
  U:=UpCaseStr(Tokens[I].Value);
  If U='CASEMAP' Then Begin
   If(I+2<=TokenCount)and(Tokens[I+1].Kind=TK_COLON)Then Begin
    If UpCaseStr(Tokens[I+2].Value)='NONE' Then Begin
     CaseSensitive:=True;
     If Verbose Then
      WriteLn('  OPTION CASEMAP:NONE (sensible a la casse)');
    End;
    Inc(I,3);
    Continue;
   End;
  End;
  Inc(I);
 End;
End;

Procedure ProcessGroupDirective;
{ Traite: DGROUP GROUP DSEG, SSEG }
Var
 I:Integer;
Begin
 If TokenCount<3 Then Exit;
 GroupName:=Tokens[1].Value;
 GroupSegments:='';
 I:=3;
 While I<=TokenCount do Begin
  If Tokens[I].Kind=TK_COMMENT Then Break;
  If Tokens[I].Kind<>TK_COMMA Then Begin
   If GroupSegments<>'' Then GroupSegments:=GroupSegments+', ';
   GroupSegments:=GroupSegments+Tokens[I].Value;
  End;
  Inc(I);
 End;
 If Verbose Then
  WriteLn('  GROUP ',GroupName,' = ',GroupSegments);
End;

Procedure ProcessEndDirective;
{ Traite: END [entry_point] }
Begin
 If(TokenCount>=2)and(Tokens[2].Kind<>TK_COMMENT)Then
  EntryPoint:=Tokens[2].Value;
 If Verbose Then Begin
  If EntryPoint<>'' Then WriteLn('  END ',EntryPoint)
                     Else WriteLn('  END');
 End;
End;

Procedure ProcessDirectives;
Var
 I:LongInt;
 U:String;
 DirCount,SegCount,SecCount:LongInt;
Begin
 InitDirectiveState;
 DirCount:=0;
 SegCount:=0;
 SecCount:=0;
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount=0 Then Continue;
  { Directives commencant par '.' }
  If(Tokens[1].Kind=TK_DIRECTIVE)and(Length(Tokens[1].Value)>0)and
    (Tokens[1].Value[1]='.')Then Begin
   U:=UpCaseStr(Tokens[1].Value);
   If U='.MODEL' Then Begin
    ProcessModelDirective;
    Inc(DirCount);
   End
   Else If(U='.8086')or(U='.186')or(U='.286')or(U='.286C')or
         (U='.286P')or(U='.386')or(U='.386C')or(U='.386P')or
         (U='.486')or(U='.486P')or(U='.586')or(U='.586P')Then Begin
    ProcessProcessorDirective(U);
    Inc(DirCount);
   End
   Else If(U='.CODE')or(U='.DATA')or(U='.DATA?')or(U='.CONST')or
         (U='.FARDATA')or(U='.FARDATA?')or(U='.STACK')Then Begin
    ProcessSectionDirective(U);
    Inc(DirCount);
    Inc(SecCount);
   End;
  End
  { Directives SEGMENT/ENDS/GROUP comme deuxieme token }
  Else If(TokenCount>=2)and(Tokens[2].Kind=TK_DIRECTIVE)Then Begin
   U:=UpCaseStr(Tokens[2].Value);
   If U='SEGMENT' Then Begin
    ProcessSegmentDirective;
    Inc(DirCount);
    Inc(SegCount);
   End
   Else If U='ENDS' Then Begin
    ProcessEndsDirective;
    Inc(DirCount);
   End
   Else If(U='GROUP')and(TokenCount>=3)Then Begin
    ProcessGroupDirective;
    Inc(DirCount);
   End;
  End
  { ASSUME, OPTION, GROUP, END comme premier token }
  Else If Tokens[1].Kind=TK_DIRECTIVE Then Begin
   U:=UpCaseStr(Tokens[1].Value);
   If U='ASSUME' Then Begin
    ProcessAssumeDirective;
    Inc(DirCount);
   End
   Else If U='OPTION' Then Begin
    ProcessOptionDirective;
    Inc(DirCount);
   End
   Else If U='END' Then Begin
    ProcessEndDirective;
    Inc(DirCount);
   End;
  End;
 End;
 WriteLn('Analyse des directives : ',DirCount,' directives traitees.');
 If Verbose Then Begin
  WriteLn('  Modele memoire : ',ModelName(MemoryModel));
  WriteLn('  Processeur     : ',CpuName(CpuLevel));
  WriteLn('  Mode           : ',16+Ord(Mode32)*16,' bits');
  WriteLn('  Segments       : ',SegmentCount);
  WriteLn('  Sections       : ',SecCount);
  If StackSize>0 Then WriteLn('  Pile           : ',StackSize,' octets');
  If CaseSensitive Then WriteLn('  Sensible a la casse');
  If EntryPoint<>'' Then WriteLn('  Point d''entree : ',EntryPoint);
  If GroupName<>'' Then WriteLn('  Groupe         : ',GroupName,' (',GroupSegments,')');
 End;
End;

{ ============================================================
  Analyse des directives de donnees - TODO 4
  ============================================================ }

Function IsDataDirective(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsDataDirective:=(U='DB')or(U='DW')or(U='DD')or
  (U='DQ')or(U='DF')or(U='DT');
End;

Function DataDirToType(S:String):Byte;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 If U='DB' Then DataDirToType:=DT_DB
 Else If U='DW' Then DataDirToType:=DT_DW
 Else If U='DD' Then DataDirToType:=DT_DD
 Else If U='DQ' Then DataDirToType:=DT_DQ
 Else If U='DF' Then DataDirToType:=DT_DF
 Else If U='DT' Then DataDirToType:=DT_DT
 Else DataDirToType:=DT_NONE;
End;

Function DataDirSize(DT:Byte):Word;
Begin
 Case DT of
  DT_DB:DataDirSize:=1;
  DT_DW:DataDirSize:=2;
  DT_DD:DataDirSize:=4;
  DT_DQ:DataDirSize:=8;
  DT_DF:DataDirSize:=6;
  DT_DT:DataDirSize:=10;
  Else DataDirSize:=1;
 End;
End;

Function DataDirToPascalType(DT:Byte):Byte;
Begin
 Case DT of
  DT_DB:DataDirToPascalType:=PT_BYTE;
  DT_DW:DataDirToPascalType:=PT_WORD;
  DT_DD:DataDirToPascalType:=PT_LONGINT;
  DT_DQ:DataDirToPascalType:=PT_ARRAY;
  DT_DF:DataDirToPascalType:=PT_ARRAY;
  DT_DT:DataDirToPascalType:=PT_ARRAY;
  Else DataDirToPascalType:=PT_BYTE;
 End;
End;

Function DataDirName(DT:Byte):String;
Begin
 Case DT of
  DT_DB:DataDirName:='DB';
  DT_DW:DataDirName:='DW';
  DT_DD:DataDirName:='DD';
  DT_DQ:DataDirName:='DQ';
  DT_DF:DataDirName:='DF';
  DT_DT:DataDirName:='DT';
  Else DataDirName:='??';
 End;
End;

Function PascalTypeName(PT:Byte):String;
Begin
 Case PT of
  PT_BYTE:PascalTypeName:='Byte';
  PT_SHORTINT:PascalTypeName:='ShortInt';
  PT_WORD:PascalTypeName:='Word';
  PT_INTEGER:PascalTypeName:='Integer';
  PT_LONGINT:PascalTypeName:='LongInt';
  PT_BOOLEAN:PascalTypeName:='Boolean';
  PT_CHAR:PascalTypeName:='Char';
  PT_STRING:PascalTypeName:='String';
  PT_POINTER:PascalTypeName:='Pointer';
  PT_PCHAR:PascalTypeName:='PChar';
  PT_ARRAY:PascalTypeName:='Array';
  Else PascalTypeName:='Byte';
 End;
End;

Function ParseNumericValue(S:String):LongInt;
{ Parse un nombre decimal, hexadecimal MASM (0FFh, 0xFF) ou Pascal ($FF) }
Var
 U:String;
 V:LongInt;
 Code:Integer;
Begin
 U:=UpCaseStr(Trim(S));
 ParseNumericValue:=0;
 If Length(U)=0 Then Exit;
 { Hex Pascal : $FF }
 If U[1]='$' Then Begin
  ParseNumericValue:=HexToInt(Copy(U,2,Length(U)-1));
  Exit;
 End;
 { Hex C : 0xFF }
 If(Length(U)>2)and(U[1]='0')and(U[2]='X')Then Begin
  ParseNumericValue:=HexToInt(Copy(U,3,Length(U)-2));
  Exit;
 End;
 { Hex MASM : 0FFh ou FFh }
 If(Length(U)>0)and(U[Length(U)]='H')Then Begin
  ParseNumericValue:=HexToInt(Copy(U,1,Length(U)-1));
  Exit;
 End;
 { Decimal }
 Val(U,V,Code);
 If Code=0 Then ParseNumericValue:=V;
End;

Procedure ParseDataLine(LineIdx:LongInt);
{ Parse une ligne de donnees : [nom] DB/DW/DD/DQ/DF/DT valeurs }
Var
 VarName:String;
 DirIdx:Integer;
 DT:Byte;
 I:Integer;
 U:String;
 Elem:TDataElem;
 DupCnt:LongInt;
Begin
 If TokenCount<2 Then Exit;
 { Determiner la position de la directive }
 VarName:='';
 DirIdx:=0;
 If(Tokens[1].Kind=TK_DIRECTIVE)and IsDataDirective(Tokens[1].Value)Then
  DirIdx:=1
 Else If(Tokens[1].Kind=TK_LABEL)Then Begin
  { label: DB ... }
  VarName:=Tokens[1].Value;
  If(TokenCount>=2)and(Tokens[2].Kind=TK_DIRECTIVE)and
    IsDataDirective(Tokens[2].Value)Then
   DirIdx:=2;
 End
 Else If(Tokens[1].Kind=TK_IDENT)Then Begin
  { nom DB ... }
  If(TokenCount>=2)and(Tokens[2].Kind=TK_DIRECTIVE)and
    IsDataDirective(Tokens[2].Value)Then Begin
   VarName:=Tokens[1].Value;
   DirIdx:=2;
  End;
 End;
 If DirIdx=0 Then Exit;
 DT:=DataDirToType(Tokens[DirIdx].Value);
 If DT=DT_NONE Then Exit;
 { Ajouter la variable }
 If DataVarCount>=MAX_DATAVARS Then Exit;
 Inc(DataVarCount);
 DataVars[DataVarCount].Name:=VarName;
 DataVars[DataVarCount].DirType:=DT;
 DataVars[DataVarCount].ElemSize:=DataDirSize(DT);
 DataVars[DataVarCount].ElemCount:=0;
 DataVars[DataVarCount].TotalSize:=0;
 DataVars[DataVarCount].Section:=CurrentSection;
 DataVars[DataVarCount].SrcLine:=LineIdx;
 DataVars[DataVarCount].IsPublic:=False;
 { Determiner le type Pascal initial }
 DataVars[DataVarCount].PascalType:=DataDirToPascalType(DT);
 { Parcourir les valeurs apres la directive }
 I:=DirIdx+1;
 While(I<=TokenCount)and(DataVars[DataVarCount].ElemCount<MAX_DATAELEMS)do Begin
  If Tokens[I].Kind=TK_COMMENT Then Break;
  If Tokens[I].Kind=TK_COMMA Then Begin
   Inc(I);
   Continue;
  End;
  { Initialiser l'element }
  Elem.ElemType:=DE_NUMBER;
  Elem.NumValue:=0;
  Elem.StrValue:='';
  Elem.DupCount:=0;
  Elem.DupValue:=0;
  Elem.DupIsUninit:=False;
  U:=UpCaseStr(Tokens[I].Value);
  { Valeur non-initialisee : ? }
  If Tokens[I].Value='?' Then Begin
   Elem.ElemType:=DE_UNINIT;
   Inc(I);
  End
  { Chaine de caracteres }
  Else If Tokens[I].Kind=TK_STRING Then Begin
   Elem.ElemType:=DE_STRING;
   Elem.StrValue:=Tokens[I].Value;
   { Pour DB, une chaine de N chars occupe N octets }
   If DT=DT_DB Then
    DataVars[DataVarCount].PascalType:=PT_STRING;
   Inc(I);
  End
  { OFFSET label }
  Else If U='OFFSET' Then Begin
   Elem.ElemType:=DE_OFFSET;
   Inc(I);
   If I<=TokenCount Then Begin
    Elem.StrValue:=Tokens[I].Value;
    Inc(I);
   End;
  End
  { SEG label }
  Else If U='SEG' Then Begin
   Elem.ElemType:=DE_SEG;
   Inc(I);
   If I<=TokenCount Then Begin
    Elem.StrValue:=Tokens[I].Value;
    Inc(I);
   End;
  End
  { nombre suivi de DUP(...) }
  Else If(Tokens[I].Kind=TK_NUMBER)Then Begin
   DupCnt:=ParseNumericValue(Tokens[I].Value);
   { Verifier si suivi de DUP }
   If(I+1<=TokenCount)and(UpCaseStr(Tokens[I+1].Value)='DUP')Then Begin
    Elem.ElemType:=DE_DUP;
    Elem.DupCount:=DupCnt;
    Inc(I,2);
    { Sauter le '(' ouvrante si present - NOTE: le tokenizer ne gere
      pas les parentheses comme tokens separes, elles font partie du
      flux de tokens. On cherche la valeur dans les tokens suivants. }
    { Chercher la valeur entre parentheses }
    If(I<=TokenCount)Then Begin
     U:=Tokens[I].Value;
     { Enlever les parentheses si presentes }
     If(Length(U)>0)and(U[1]='(')Then
      U:=Copy(U,2,Length(U)-1);
     If(Length(U)>0)and(U[Length(U)]=')')Then
      U:=Copy(U,1,Length(U)-1);
     U:=Trim(U);
     If U='?' Then
      Elem.DupIsUninit:=True
     Else
      Elem.DupValue:=ParseNumericValue(U);
     Inc(I);
    End;
    { Verifier si ')' est un token separe suivant }
    If(I<=TokenCount)and(Tokens[I].Value=')')Then
     Inc(I);
   End
   Else Begin
    { Nombre simple }
    Elem.ElemType:=DE_NUMBER;
    Elem.NumValue:=DupCnt;
    Inc(I);
   End;
  End
  { Identificateur (reference a un label, etc.) }
  Else If(Tokens[I].Kind=TK_IDENT)or(Tokens[I].Kind=TK_LABEL)Then Begin
   { DUP seul ne devrait pas arriver ici, mais verifier }
   If U='DUP' Then Begin
    Inc(I);
    Continue;
   End;
   Elem.ElemType:=DE_EXPR;
   Elem.StrValue:=Tokens[I].Value;
   Inc(I);
  End
  Else Begin
   { Token non reconnu, passer }
   Inc(I);
   Continue;
  End;
  { Stocker l'element }
  Inc(DataVars[DataVarCount].ElemCount);
  DataVars[DataVarCount].Elements[DataVars[DataVarCount].ElemCount]:=Elem;
 End;
 { Calculer la taille totale }
 With DataVars[DataVarCount] do Begin
  TotalSize:=0;
  For I:=1 to ElemCount do Begin
   Case Elements[I].ElemType of
    DE_NUMBER:TotalSize:=TotalSize+ElemSize;
    DE_STRING:Begin
     If DirType=DT_DB Then
      TotalSize:=TotalSize+Length(Elements[I].StrValue)
     Else
      TotalSize:=TotalSize+ElemSize;
    End;
    DE_DUP:TotalSize:=TotalSize+Elements[I].DupCount*ElemSize;
    DE_OFFSET:TotalSize:=TotalSize+ElemSize;
    DE_SEG:TotalSize:=TotalSize+2;
    DE_UNINIT:TotalSize:=TotalSize+ElemSize;
    DE_EXPR:TotalSize:=TotalSize+ElemSize;
   End;
  End;
  { Affiner le type Pascal }
  If(DirType=DT_DB)and(ElemCount=1)and
    (Elements[1].ElemType=DE_STRING)Then
   PascalType:=PT_STRING
  Else If(ElemCount>1)or((ElemCount=1)and
    (Elements[1].ElemType=DE_DUP))Then
   PascalType:=PT_ARRAY
  Else
   PascalType:=DataDirToPascalType(DirType);
 End;
 { Ajouter a la table des symboles si nomme }
 If VarName<>'' Then Begin
  If SymbolCount<MAX_SYMBOLS Then Begin
   Inc(SymbolCount);
   Symbols[SymbolCount].Name:=VarName;
   Symbols[SymbolCount].SymType:=SY_VAR;
   Symbols[SymbolCount].DataType:=DataVars[DataVarCount].PascalType;
   Symbols[SymbolCount].Size:=Word(DataVars[DataVarCount].TotalSize);
   Symbols[SymbolCount].Offset:=0;
   Symbols[SymbolCount].Segment:='';
   Symbols[SymbolCount].IsPublic:=False;
   Symbols[SymbolCount].IsExtern:=False;
   Inc(TotalVars);
  End;
 End;
End;

Procedure ProcessDataDirectives;
Var
 I:LongInt;
 HasData:Boolean;
 StringCount,DupCount,NumCount:LongInt;
 TotalBytes:LongInt;
 J:Integer;
Begin
 DataVarCount:=0;
 StringCount:=0;
 DupCount:=0;
 NumCount:=0;
 TotalBytes:=0;
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount<2 Then Continue;
  HasData:=False;
  { Cas 1: directive en premiere position (DB val) }
  If(Tokens[1].Kind=TK_DIRECTIVE)and IsDataDirective(Tokens[1].Value)Then
   HasData:=True
  { Cas 2: nom suivi de directive (msg DB 'Hello') }
  Else If(TokenCount>=2)and(Tokens[2].Kind=TK_DIRECTIVE)and
    IsDataDirective(Tokens[2].Value)Then
   HasData:=True;
  If HasData Then Begin
   ParseDataLine(I);
   { Statistiques }
   If DataVarCount>0 Then Begin
    TotalBytes:=TotalBytes+DataVars[DataVarCount].TotalSize;
    For J:=1 to DataVars[DataVarCount].ElemCount do
     Case DataVars[DataVarCount].Elements[J].ElemType of
      DE_STRING:Inc(StringCount);
      DE_DUP:Inc(DupCount);
      DE_NUMBER,DE_UNINIT:Inc(NumCount);
     End;
   End;
  End;
 End;
 WriteLn('Analyse des donnees : ',DataVarCount,' variables, ',
  TotalBytes,' octets.');
 If Verbose Then Begin
  WriteLn('  Chaines     : ',StringCount);
  WriteLn('  DUP         : ',DupCount);
  WriteLn('  Numeriques  : ',NumCount);
  If DataVarCount>0 Then Begin
   WriteLn('  Details :');
   For I:=1 to DataVarCount do Begin
    If DataVars[I].Name<>'' Then
     Write('    ',DataVars[I].Name)
    Else
     Write('    (anonyme)');
    Write(' ',DataDirName(DataVars[I].DirType));
    Write(' -> ',PascalTypeName(DataVars[I].PascalType));
    Write(' (',DataVars[I].TotalSize,' octets, ',
     DataVars[I].ElemCount,' elem)');
    WriteLn;
   End;
  End;
 End;
End;

{ ============================================================
  Analyse des directives de procedures - TODO 5
  ============================================================ }

Function ConventionName(C:Byte):String;
Begin
 Case C of
  CC_C:ConventionName:='C';
  CC_PASCAL:ConventionName:='PASCAL';
  CC_STDCALL:ConventionName:='STDCALL';
  CC_BASIC:ConventionName:='BASIC';
  CC_FORTRAN:ConventionName:='FORTRAN';
  CC_SYSCALL:ConventionName:='SYSCALL';
  Else ConventionName:='(defaut)';
 End;
End;

Function MasmTypeToPascalType(S:String):Byte;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 If(U='BYTE')or(U='DB')Then MasmTypeToPascalType:=PT_BYTE
 Else If U='SBYTE' Then MasmTypeToPascalType:=PT_SHORTINT
 Else If(U='WORD')or(U='DW')Then MasmTypeToPascalType:=PT_WORD
 Else If U='SWORD' Then MasmTypeToPascalType:=PT_INTEGER
 Else If(U='DWORD')or(U='DD')Then MasmTypeToPascalType:=PT_LONGINT
 Else If U='SDWORD' Then MasmTypeToPascalType:=PT_LONGINT
 Else If(U='FWORD')or(U='DF')Then MasmTypeToPascalType:=PT_POINTER
 Else If(U='QWORD')or(U='DQ')Then MasmTypeToPascalType:=PT_LONGINT
 Else If(U='TBYTE')or(U='DT')Then MasmTypeToPascalType:=PT_LONGINT
 Else If(U='PTR')or(U='NEAR')or(U='FAR')Then MasmTypeToPascalType:=PT_POINTER
 Else MasmTypeToPascalType:=PT_WORD;
End;

Function MasmTypeSize(S:String):Word;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 If(U='BYTE')or(U='DB')or(U='SBYTE')Then MasmTypeSize:=1
 Else If(U='WORD')or(U='DW')or(U='SWORD')Then MasmTypeSize:=2
 Else If(U='DWORD')or(U='DD')or(U='SDWORD')Then MasmTypeSize:=4
 Else If(U='FWORD')or(U='DF')Then MasmTypeSize:=6
 Else If(U='QWORD')or(U='DQ')Then MasmTypeSize:=8
 Else If(U='TBYTE')or(U='DT')Then MasmTypeSize:=10
 Else If(U='PTR')or(U='NEAR')Then Begin
  If Mode32 Then MasmTypeSize:=4
  Else MasmTypeSize:=2;
 End
 Else If U='FAR' Then Begin
  If Mode32 Then MasmTypeSize:=6
  Else MasmTypeSize:=4;
 End
 Else MasmTypeSize:=2;
End;

Function IsCallingConvention(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsCallingConvention:=(U='C')or(U='PASCAL')or(U='STDCALL')or
  (U='BASIC')or(U='FORTRAN')or(U='SYSCALL');
End;

Function ConventionFromName(S:String):Byte;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 If U='C' Then ConventionFromName:=CC_C
 Else If U='PASCAL' Then ConventionFromName:=CC_PASCAL
 Else If U='STDCALL' Then ConventionFromName:=CC_STDCALL
 Else If U='BASIC' Then ConventionFromName:=CC_BASIC
 Else If U='FORTRAN' Then ConventionFromName:=CC_FORTRAN
 Else If U='SYSCALL' Then ConventionFromName:=CC_SYSCALL
 Else ConventionFromName:=CC_NONE;
End;

Procedure ParseProcLine(LineIdx:LongInt);
{ Traite: name PROC [NEAR|FAR] [conv] [USES reg...] [,] [params] }
Var
 U:String;
 TokIdx:Integer;
 PName:String;
 InParams:Boolean;
 ParamName,ParamType:String;
Begin
 TokenizeLine(SrcLines[LineIdx]^);
 If TokenCount<2 Then Exit;
 { Le nom de la procedure est le premier token }
 PName:=Tokens[1].Value;
 { Verifier que le deuxieme token est PROC }
 If UpCaseStr(Tokens[2].Value)<>'PROC' Then Exit;
 { Verifier le nombre max }
 If ProcCount>=MAX_PROCS Then Exit;
 Inc(ProcCount);
 Procs[ProcCount].Name:=PName;
 Procs[ProcCount].IsFunction:=False;
 Procs[ProcCount].IsNear:=True;
 Procs[ProcCount].Convention:=CC_NONE;
 Procs[ProcCount].ParamCount:=0;
 Procs[ProcCount].LocalCount:=0;
 Procs[ProcCount].LocalSize:=0;
 Procs[ProcCount].StartLine:=LineIdx;
 Procs[ProcCount].EndLine:=-1;
 Procs[ProcCount].UsesAX:=False;
 Procs[ProcCount].IsPublic:=False;
 { Default: NEAR pour modeles SMALL/TINY/FLAT, FAR sinon }
 If(MemoryModel=MM_LARGE)or(MemoryModel=MM_HUGE)or
   (MemoryModel=MM_MEDIUM)Then
  Procs[ProcCount].IsNear:=False;
 { Parser les attributs apres PROC }
 TokIdx:=3;
 InParams:=False;
 While TokIdx<=TokenCount do Begin
  If Tokens[TokIdx].Kind=TK_COMMENT Then Break;
  U:=UpCaseStr(Tokens[TokIdx].Value);
  If U='NEAR' Then Begin
   Procs[ProcCount].IsNear:=True;
   Inc(TokIdx);
  End
  Else If U='FAR' Then Begin
   Procs[ProcCount].IsNear:=False;
   Inc(TokIdx);
  End
  Else If IsCallingConvention(U) Then Begin
   Procs[ProcCount].Convention:=ConventionFromName(U);
   Inc(TokIdx);
  End
  Else If U='USES' Then Begin
   { Sauter la liste des registres sauvegardes }
   Inc(TokIdx);
   While(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_REGISTER)do
    Inc(TokIdx);
   { Sauter une virgule eventuelle apres USES }
   If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_COMMA)Then
    Inc(TokIdx);
  End
  Else If Tokens[TokIdx].Kind=TK_COMMA Then Begin
   Inc(TokIdx);
  End
  Else Begin
   { On entre dans le mode parametres }
   InParams:=True;
   Break;
  End;
 End;
 { Parser les parametres si present }
 If InParams Then Begin
  While TokIdx<=TokenCount do Begin
   If Tokens[TokIdx].Kind=TK_COMMENT Then Break;
   If Tokens[TokIdx].Kind=TK_COMMA Then Begin
    Inc(TokIdx);
    Continue;
   End;
   { Lire le nom du parametre }
   ParamName:='';
   ParamType:='WORD';
   If Tokens[TokIdx].Kind=TK_LABEL Then Begin
    { Le tokenizer a consomme le ':' - param:TYPE }
    ParamName:=Tokens[TokIdx].Value;
    Inc(TokIdx);
    { Le prochain token est directement le type }
    If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind<>TK_COMMA)and
      (Tokens[TokIdx].Kind<>TK_COMMENT)Then Begin
     ParamType:=Tokens[TokIdx].Value;
     Inc(TokIdx);
     If(TokIdx<=TokenCount)and(UpCaseStr(Tokens[TokIdx].Value)='PTR')Then
      Inc(TokIdx);
    End;
   End
   Else If Tokens[TokIdx].Kind=TK_IDENT Then Begin
    ParamName:=Tokens[TokIdx].Value;
    Inc(TokIdx);
    { Lire ':' + type }
    If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_COLON)Then Begin
     Inc(TokIdx);
     If TokIdx<=TokenCount Then Begin
      ParamType:=Tokens[TokIdx].Value;
      Inc(TokIdx);
      If(TokIdx<=TokenCount)and(UpCaseStr(Tokens[TokIdx].Value)='PTR')Then
       Inc(TokIdx);
     End;
    End;
   End
   Else Begin
    Inc(TokIdx);
    Continue;
   End;
   If(Procs[ProcCount].ParamCount<MAX_PARAMS)and(ParamName<>'')Then Begin
    Inc(Procs[ProcCount].ParamCount);
    With Procs[ProcCount].Params[Procs[ProcCount].ParamCount] do Begin
     Name:=ParamName;
     TypeName:=ParamType;
     PascalType:=MasmTypeToPascalType(ParamType);
     Size:=MasmTypeSize(ParamType);
    End;
   End;
  End;
 End;
 { Ajouter a la table des symboles }
 If SymbolCount<MAX_SYMBOLS Then Begin
  Inc(SymbolCount);
  Symbols[SymbolCount].Name:=PName;
  Symbols[SymbolCount].SymType:=SY_PROC;
  Symbols[SymbolCount].DataType:=PT_WORD;
  Symbols[SymbolCount].Size:=0;
  Symbols[SymbolCount].Offset:=0;
  Symbols[SymbolCount].Segment:='';
  Symbols[SymbolCount].IsPublic:=False;
  Symbols[SymbolCount].IsExtern:=False;
  Inc(TotalProcs);
 End;
End;

Procedure ParseLocalLine(LineIdx:LongInt;ProcIdx:Integer);
{ Traite: LOCAL var1:TYPE [, var2:TYPE ...] }
{ Traite: LOCAL var1[count]:TYPE }
Var
 TokIdx:Integer;
 VarName,VarType:String;
 ArrCount:Word;
 VarSize:Word;
 V:LongInt;
 Code:Integer;
Begin
 TokenizeLine(SrcLines[LineIdx]^);
 If TokenCount<2 Then Exit;
 If UpCaseStr(Tokens[1].Value)<>'LOCAL' Then Exit;
 TokIdx:=2;
 While TokIdx<=TokenCount do Begin
  If Tokens[TokIdx].Kind=TK_COMMENT Then Break;
  If Tokens[TokIdx].Kind=TK_COMMA Then Begin
   Inc(TokIdx);
   Continue;
  End;
  VarName:='';
  VarType:='WORD';
  ArrCount:=1;
  { Lire le nom de la variable locale }
  If Tokens[TokIdx].Kind=TK_LABEL Then Begin
   { Le tokenizer a consomme le ':' - var:TYPE }
   VarName:=Tokens[TokIdx].Value;
   Inc(TokIdx);
   { Le prochain token est directement le type }
   If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind<>TK_COMMA)and
     (Tokens[TokIdx].Kind<>TK_COMMENT)Then Begin
    VarType:=Tokens[TokIdx].Value;
    Inc(TokIdx);
    If(TokIdx<=TokenCount)and(UpCaseStr(Tokens[TokIdx].Value)='PTR')Then
     Inc(TokIdx);
   End;
   If(ProcIdx>0)and(ProcIdx<=ProcCount)and(VarName<>'')Then Begin
    If Procs[ProcIdx].LocalCount<MAX_LOCALS Then Begin
     Inc(Procs[ProcIdx].LocalCount);
     With Procs[ProcIdx].Locals[Procs[ProcIdx].LocalCount] do Begin
      Name:=VarName;
      TypeName:=VarType;
      PascalType:=MasmTypeToPascalType(VarType);
      Size:=MasmTypeSize(VarType);
      Count:=ArrCount;
     End;
     VarSize:=MasmTypeSize(VarType)*ArrCount;
     Procs[ProcIdx].LocalSize:=Procs[ProcIdx].LocalSize+VarSize;
    End;
   End;
  End
  Else If Tokens[TokIdx].Kind=TK_IDENT Then Begin
   VarName:=Tokens[TokIdx].Value;
   Inc(TokIdx);
   { Verifier un compteur [n] }
   If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_LBRACKET)Then Begin
    Inc(TokIdx);
    If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_NUMBER)Then Begin
     Val(Tokens[TokIdx].Value,V,Code);
     If Code<>0 Then V:=ParseNumericValue(Tokens[TokIdx].Value);
     ArrCount:=Word(V);
     If ArrCount=0 Then ArrCount:=1;
     Inc(TokIdx);
    End;
    If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_RBRACKET)Then
     Inc(TokIdx);
   End;
   { Lire ':' + type }
   If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_COLON)Then Begin
    Inc(TokIdx);
    If TokIdx<=TokenCount Then Begin
     VarType:=Tokens[TokIdx].Value;
     Inc(TokIdx);
     If(TokIdx<=TokenCount)and(UpCaseStr(Tokens[TokIdx].Value)='PTR')Then
      Inc(TokIdx);
    End;
   End;
   If(ProcIdx>0)and(ProcIdx<=ProcCount)and(VarName<>'')Then Begin
    If Procs[ProcIdx].LocalCount<MAX_LOCALS Then Begin
     Inc(Procs[ProcIdx].LocalCount);
     With Procs[ProcIdx].Locals[Procs[ProcIdx].LocalCount] do Begin
      Name:=VarName;
      TypeName:=VarType;
      PascalType:=MasmTypeToPascalType(VarType);
      Size:=MasmTypeSize(VarType);
      Count:=ArrCount;
     End;
     VarSize:=MasmTypeSize(VarType)*ArrCount;
     Procs[ProcIdx].LocalSize:=Procs[ProcIdx].LocalSize+VarSize;
    End;
   End;
  End
  Else Inc(TokIdx);
 End;
End;

Procedure DetectFunctionReturn(ProcIdx:Integer);
{ Detecte si une procedure retourne une valeur en analysant
  l'utilisation de AX/EAX avant RET/RETN/RETF }
Var
 I:LongInt;
 U:String;
 HasMovAX:Boolean;
 StartL,EndL:LongInt;
Begin
 If(ProcIdx<1)or(ProcIdx>ProcCount)Then Exit;
 StartL:=Procs[ProcIdx].StartLine;
 EndL:=Procs[ProcIdx].EndLine;
 If EndL<0 Then EndL:=SrcLineCount-1;
 HasMovAX:=False;
 For I:=StartL to EndL do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount=0 Then Continue;
  If Tokens[1].Kind<>TK_MNEMONIC Then Continue;
  U:=UpCaseStr(Tokens[1].Value);
  { Detecter MOV AX,... ou MOV EAX,... }
  If(U='MOV')or(U='MOVZX')or(U='MOVSX')Then Begin
   If TokenCount>=2 Then Begin
    If(UpCaseStr(Tokens[2].Value)='AX')or
      (UpCaseStr(Tokens[2].Value)='EAX')Then Begin
     HasMovAX:=True;
     Procs[ProcIdx].UsesAX:=True;
    End;
   End;
  End
  { Detecter XOR AX,AX ou XOR EAX,EAX }
  Else If U='XOR' Then Begin
   If TokenCount>=4 Then Begin
    If((UpCaseStr(Tokens[2].Value)='AX')and
       (UpCaseStr(Tokens[4].Value)='AX'))or
      ((UpCaseStr(Tokens[2].Value)='EAX')and
       (UpCaseStr(Tokens[4].Value)='EAX'))Then Begin
     HasMovAX:=True;
     Procs[ProcIdx].UsesAX:=True;
    End;
   End;
  End
  { Detecter LEA AX,... ou LEA EAX,... }
  Else If U='LEA' Then Begin
   If TokenCount>=2 Then Begin
    If(UpCaseStr(Tokens[2].Value)='AX')or
      (UpCaseStr(Tokens[2].Value)='EAX')Then Begin
     HasMovAX:=True;
     Procs[ProcIdx].UsesAX:=True;
    End;
   End;
  End;
 End;
 Procs[ProcIdx].IsFunction:=HasMovAX;
End;

Procedure ProcessProcedureDirectives;
Var
 I:LongInt;
 U:String;
 CurrentProc:Integer;
 ProcDirCount:LongInt;
 NearCount,FarCount,FuncCount:LongInt;
 ParamTotal,LocalTotal:LongInt;
 UnmatchedCount:LongInt;
Begin
 ProcCount:=0;
 ProcDirCount:=0;
 NearCount:=0;
 FarCount:=0;
 FuncCount:=0;
 ParamTotal:=0;
 LocalTotal:=0;
 UnmatchedCount:=0;
 CurrentProc:=0;
 { Premiere passe : detecter PROC, ENDP et LOCAL }
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount<2 Then Begin
   { Verifier LOCAL comme premier token avec au moins 1 argument }
   If(TokenCount>=1)and(Tokens[1].Kind=TK_DIRECTIVE)and
     (UpCaseStr(Tokens[1].Value)='LOCAL')Then Begin
    If CurrentProc>0 Then
     ParseLocalLine(I,CurrentProc);
   End;
   Continue;
  End;
  U:=UpCaseStr(Tokens[2].Value);
  If(Tokens[2].Kind=TK_DIRECTIVE)and(U='PROC')Then Begin
   ParseProcLine(I);
   CurrentProc:=ProcCount;
   Inc(ProcDirCount);
  End
  Else If(Tokens[2].Kind=TK_DIRECTIVE)and(U='ENDP')Then Begin
   { Associer ENDP au PROC correspondant }
   If CurrentProc>0 Then Begin
    Procs[CurrentProc].EndLine:=I;
    CurrentProc:=0;
   End;
   Inc(ProcDirCount);
  End
  Else If(Tokens[1].Kind=TK_DIRECTIVE)and
        (UpCaseStr(Tokens[1].Value)='LOCAL')Then Begin
   { Traiter LOCAL dans la procedure courante }
   If CurrentProc>0 Then
    ParseLocalLine(I,CurrentProc);
  End;
 End;
 { Deuxieme passe : detecter les fonctions (retour AX/EAX) }
 For I:=1 to ProcCount do Begin
  DetectFunctionReturn(I);
  If Procs[I].IsNear Then Inc(NearCount) Else Inc(FarCount);
  If Procs[I].IsFunction Then Inc(FuncCount);
  ParamTotal:=ParamTotal+Procs[I].ParamCount;
  LocalTotal:=LocalTotal+Procs[I].LocalCount;
  If Procs[I].EndLine<0 Then Inc(UnmatchedCount);
 End;
 WriteLn('Analyse des procedures : ',ProcCount,' procedures, ',
  ProcDirCount,' directives.');
 If Verbose Then Begin
  WriteLn('  NEAR          : ',NearCount);
  WriteLn('  FAR           : ',FarCount);
  WriteLn('  Fonctions     : ',FuncCount);
  WriteLn('  Parametres    : ',ParamTotal);
  WriteLn('  Var. locales  : ',LocalTotal);
  If UnmatchedCount>0 Then
   WriteLn('  Non-fermes    : ',UnmatchedCount);
  If ProcCount>0 Then Begin
   WriteLn('  Details :');
   For I:=1 to ProcCount do Begin
    Write('    ',Procs[I].Name);
    If Procs[I].IsNear Then Write(' NEAR') Else Write(' FAR');
    If Procs[I].Convention<>CC_NONE Then
     Write(' ',ConventionName(Procs[I].Convention));
    If Procs[I].IsFunction Then Write(' (fonction)');
    If Procs[I].ParamCount>0 Then
     Write(' (',Procs[I].ParamCount,' params)');
    If Procs[I].LocalCount>0 Then
     Write(' (',Procs[I].LocalCount,' locales, ',
      Procs[I].LocalSize,' octets)');
    If Procs[I].EndLine<0 Then Write(' [SANS ENDP]');
    WriteLn;
   End;
  End;
 End;
End;

{ ============================================================
  Table des symboles et gestion des identificateurs - TODO 6
  ============================================================ }

Function SymbolTypeName(ST:Byte):String;
Begin
 Case ST of
  SY_LABEL:SymbolTypeName:='LABEL';
  SY_PROC:SymbolTypeName:='PROC';
  SY_VAR:SymbolTypeName:='VAR';
  SY_CONST:SymbolTypeName:='CONST';
  SY_SEGMENT:SymbolTypeName:='SEGMENT';
  SY_PARAM:SymbolTypeName:='PARAM';
  Else SymbolTypeName:='?';
 End;
End;

Function FindSymbol(Name:String):Integer;
{ Recherche un symbole par nom (case-insensitive). Retourne l'index ou 0. }
Var
 I:Integer;
 U:String;
Begin
 U:=UpCaseStr(Name);
 FindSymbol:=0;
 For I:=1 to SymbolCount do
  If UpCaseStr(Symbols[I].Name)=U Then Begin
   FindSymbol:=I;
   Exit;
  End;
End;

Function AddSymbol(AName:String;AType:Byte;ADataType:Byte;ASize:Word;
 AOffset:LongInt;ASegment:String;APublic,AExtern:Boolean):Integer;
{ Ajoute un symbole. Retourne l'index ou 0 si doublon ou table pleine. }
Var
 Idx:Integer;
Begin
 AddSymbol:=0;
 If AName='' Then Exit;
 { Verifier doublon }
 Idx:=FindSymbol(AName);
 If Idx>0 Then Begin
  { Mettre a jour les flags si necessaire }
  If APublic Then Symbols[Idx].IsPublic:=True;
  If AExtern Then Symbols[Idx].IsExtern:=True;
  { Mettre a jour le type si le precedent etait plus generique }
  If(Symbols[Idx].SymType=SY_LABEL)and(AType<>SY_LABEL)Then Begin
   Symbols[Idx].SymType:=AType;
   Symbols[Idx].DataType:=ADataType;
   Symbols[Idx].Size:=ASize;
  End;
  AddSymbol:=Idx;
  Exit;
 End;
 If SymbolCount>=MAX_SYMBOLS Then Exit;
 Inc(SymbolCount);
 Symbols[SymbolCount].Name:=AName;
 Symbols[SymbolCount].SymType:=AType;
 Symbols[SymbolCount].DataType:=ADataType;
 Symbols[SymbolCount].Size:=ASize;
 Symbols[SymbolCount].Offset:=AOffset;
 Symbols[SymbolCount].Segment:=ASegment;
 Symbols[SymbolCount].IsPublic:=APublic;
 Symbols[SymbolCount].IsExtern:=AExtern;
 AddSymbol:=SymbolCount;
End;

Function IsLocalLabel(Name:String):Boolean;
{ Detecte les labels locaux : @@xxx ou @xxx }
Begin
 IsLocalLabel:=False;
 If Length(Name)<2 Then Exit;
 IsLocalLabel:=(Name[1]='@');
End;

Procedure CollectLabels;
{ Parcourt les lignes source et collecte les labels (etiquettes avec ':') }
Var
 I:LongInt;
 LabelName:String;
Begin
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount=0 Then Continue;
  { Le tokenizer produit TK_LABEL pour les labels avec ':' }
  If Tokens[1].Kind=TK_LABEL Then Begin
   LabelName:=Tokens[1].Value;
   { Ne pas ajouter les labels locaux @@xxx comme globaux }
   If Not IsLocalLabel(LabelName) Then
    AddSymbol(LabelName,SY_LABEL,PT_WORD,0,I,'',False,False);
  End;
 End;
End;

Procedure CollectConstants;
{ Parcourt les lignes source et collecte les constantes (EQU, =) }
Var
 I:LongInt;
 J:Integer;
 U:String;
 CName:String;
 CValue:LongInt;
 HasEqu:Boolean;
Begin
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount<3 Then Continue;
  { Forme : name EQU value  ou  name = value }
  HasEqu:=False;
  If(Tokens[1].Kind=TK_IDENT)or(Tokens[1].Kind=TK_LABEL)Then Begin
   CName:=Tokens[1].Value;
   J:=2;
   { Skipper le token si TK_LABEL a consomme le ':' }
   If Tokens[1].Kind=TK_LABEL Then
    J:=2
   Else
    J:=2;
   If J<=TokenCount Then Begin
    U:=UpCaseStr(Tokens[J].Value);
    If(Tokens[J].Kind=TK_DIRECTIVE)and(U='EQU')Then
     HasEqu:=True
    Else If(U='=')Then
     HasEqu:=True;
   End;
   If HasEqu and(J<TokenCount)Then Begin
    { Evaluer la valeur (simplifie: premier nombre apres EQU/=) }
    CValue:=0;
    If(J+1<=TokenCount)and(Tokens[J+1].Kind=TK_NUMBER)Then
     CValue:=ParseNumericValue(Tokens[J+1].Value)
    Else If(J+1<=TokenCount)and(Tokens[J+1].Kind=TK_STRING)Then
     CValue:=0;
    AddSymbol(CName,SY_CONST,PT_LONGINT,4,CValue,'',False,False);
   End;
  End;
 End;
End;

Procedure CollectSegmentSymbols;
{ Ajoute les segments definis comme symboles dans la table }
Var
 I:Integer;
Begin
 For I:=1 to SegmentCount do
  AddSymbol(Segments[I].Name,SY_SEGMENT,PT_WORD,0,0,'',False,False);
End;

Procedure CollectProcParams;
{ Ajoute les parametres et locales des procedures comme symboles }
Var
 I:Integer;
 J:Byte;
 ParamOfs:LongInt;
Begin
 For I:=1 to ProcCount do Begin
  { Parametres }
  ParamOfs:=4; { BP+4 pour NEAR, BP+6 pour FAR }
  If Not Procs[I].IsNear Then ParamOfs:=6;
  For J:=1 to Procs[I].ParamCount do Begin
   AddSymbol(Procs[I].Params[J].Name,SY_PARAM,
    Procs[I].Params[J].PascalType,Procs[I].Params[J].Size,
    ParamOfs,Procs[I].Name,False,False);
   ParamOfs:=ParamOfs+Procs[I].Params[J].Size;
  End;
 End;
End;

Procedure CollectPublicExtern;
{ Parcourt les lignes source et traite PUBLIC et EXTRN/EXTERN }
Var
 I:LongInt;
 J:Integer;
 U:String;
 SymName:String;
 Idx:Integer;
Begin
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount<2 Then Continue;
  U:=UpCaseStr(Tokens[1].Value);
  If(Tokens[1].Kind=TK_DIRECTIVE)and(U='PUBLIC')Then Begin
   { PUBLIC sym1 [, sym2 ...] }
   J:=2;
   While J<=TokenCount do Begin
    If Tokens[J].Kind=TK_COMMENT Then Break;
    If Tokens[J].Kind=TK_COMMA Then Begin
     Inc(J);
     Continue;
    End;
    SymName:=Tokens[J].Value;
    If(SymName<>'')and(Tokens[J].Kind<>TK_COMMENT)Then Begin
     Idx:=FindSymbol(SymName);
     If Idx>0 Then
      Symbols[Idx].IsPublic:=True
     Else
      AddSymbol(SymName,SY_LABEL,PT_WORD,0,0,'',True,False);
    End;
    Inc(J);
   End;
  End
  Else If(Tokens[1].Kind=TK_DIRECTIVE)and
        ((U='EXTRN')or(U='EXTERN'))Then Begin
   { EXTRN sym:type [, sym:type ...] }
   J:=2;
   While J<=TokenCount do Begin
    If Tokens[J].Kind=TK_COMMENT Then Break;
    If Tokens[J].Kind=TK_COMMA Then Begin
     Inc(J);
     Continue;
    End;
    { Le nom peut etre TK_LABEL (tokenizer consomme ':') ou TK_IDENT }
    If Tokens[J].Kind=TK_LABEL Then Begin
     SymName:=Tokens[J].Value;
     Inc(J);
     { Sauter le type (NEAR, FAR, BYTE, WORD, DWORD, etc.) }
     If(J<=TokenCount)and(Tokens[J].Kind<>TK_COMMA)and
       (Tokens[J].Kind<>TK_COMMENT)Then
      Inc(J);
     AddSymbol(SymName,SY_LABEL,PT_WORD,0,0,'',False,True);
    End
    Else If Tokens[J].Kind=TK_IDENT Then Begin
     SymName:=Tokens[J].Value;
     Inc(J);
     { Sauter ':' + type si present }
     If(J<=TokenCount)and(Tokens[J].Kind=TK_COLON)Then Begin
      Inc(J);
      If J<=TokenCount Then Inc(J);
     End;
     AddSymbol(SymName,SY_LABEL,PT_WORD,0,0,'',False,True);
    End
    Else Inc(J);
   End;
  End;
 End;
End;

Procedure VerifySymbolTable;
{ Verifie la coherence de la table des symboles }
Var
 I,J:Integer;
 DupCount:Integer;
 UnresCount:Integer;
 U1,U2:String;
Begin
 DupCount:=0;
 UnresCount:=0;
 { Verifier les doublons (meme nom, meme type) }
 For I:=1 to SymbolCount-1 do Begin
  U1:=UpCaseStr(Symbols[I].Name);
  For J:=I+1 to SymbolCount do Begin
   U2:=UpCaseStr(Symbols[J].Name);
   If(U1=U2)and(Symbols[I].SymType=Symbols[J].SymType)Then Begin
    Inc(DupCount);
    If Verbose Then
     WriteLn('  Attention : doublon ',Symbols[I].Name,
      ' (',SymbolTypeName(Symbols[I].SymType),')');
   End;
  End;
 End;
 { Verifier les symboles externes non resolus }
 For I:=1 to SymbolCount do
  If Symbols[I].IsExtern and(Symbols[I].SymType=SY_LABEL)Then
   Inc(UnresCount);
 If DupCount>0 Then
  WriteLn('  Doublons detectes : ',DupCount);
 If UnresCount>0 Then
  WriteLn('  Symboles externes : ',UnresCount);
End;

Procedure BuildSymbolTable;
Var
 I:Integer;
 LabelCnt,ConstCnt,SegCnt,ParamCnt:Integer;
 ProcCnt,VarCnt,PubCnt,ExtCnt:Integer;
 OldCount:Integer;
Begin
 OldCount:=SymbolCount;
 { Collecter tous les symboles }
 CollectLabels;
 LabelCnt:=SymbolCount-OldCount;
 OldCount:=SymbolCount;
 CollectConstants;
 ConstCnt:=SymbolCount-OldCount;
 OldCount:=SymbolCount;
 CollectSegmentSymbols;
 SegCnt:=SymbolCount-OldCount;
 OldCount:=SymbolCount;
 CollectProcParams;
 ParamCnt:=SymbolCount-OldCount;
 OldCount:=SymbolCount;
 CollectPublicExtern;
 { Compter par type }
 ProcCnt:=0;
 VarCnt:=0;
 PubCnt:=0;
 ExtCnt:=0;
 For I:=1 to SymbolCount do Begin
  If Symbols[I].SymType=SY_PROC Then Inc(ProcCnt);
  If Symbols[I].SymType=SY_VAR Then Inc(VarCnt);
  If Symbols[I].IsPublic Then Inc(PubCnt);
  If Symbols[I].IsExtern Then Inc(ExtCnt);
 End;
 WriteLn('Table des symboles : ',SymbolCount,' symboles.');
 If Verbose Then Begin
  WriteLn('  Labels      : ',LabelCnt);
  WriteLn('  Constantes  : ',ConstCnt);
  WriteLn('  Variables   : ',VarCnt);
  WriteLn('  Procedures  : ',ProcCnt);
  WriteLn('  Segments    : ',SegCnt);
  WriteLn('  Parametres  : ',ParamCnt);
  WriteLn('  PUBLIC      : ',PubCnt);
  WriteLn('  EXTRN       : ',ExtCnt);
  { Verification }
  VerifySymbolTable;
  { Details }
  If SymbolCount>0 Then Begin
   WriteLn('  Details :');
   For I:=1 to SymbolCount do Begin
    Write('    ',Symbols[I].Name);
    Write(' [',SymbolTypeName(Symbols[I].SymType),']');
    Write(' ',PascalTypeName(Symbols[I].DataType));
    If Symbols[I].Size>0 Then Write(' (',Symbols[I].Size,' octets)');
    If Symbols[I].IsPublic Then Write(' PUBLIC');
    If Symbols[I].IsExtern Then Write(' EXTRN');
    If Symbols[I].Segment<>'' Then Write(' @',Symbols[I].Segment);
    WriteLn;
   End;
  End;
 End;
End;

{ ============================================================
  Analyse des operandes et modes d'adressage - TODO 7
  ============================================================ }

Function IsReg8(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsReg8:=(U='AL')or(U='AH')or(U='BL')or(U='BH')or
  (U='CL')or(U='CH')or(U='DL')or(U='DH');
End;

Function IsReg16(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsReg16:=(U='AX')or(U='BX')or(U='CX')or(U='DX')or
  (U='SI')or(U='DI')or(U='BP')or(U='SP');
End;

Function IsReg32(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsReg32:=(U='EAX')or(U='EBX')or(U='ECX')or(U='EDX')or
  (U='ESI')or(U='EDI')or(U='EBP')or(U='ESP');
End;

Function IsSegReg(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsSegReg:=(U='CS')or(U='DS')or(U='ES')or(U='SS')or
  (U='FS')or(U='GS');
End;

Function RegSize(S:String):Byte;
{ Retourne la taille d'un registre en octets (1, 2 ou 4) }
Begin
 If IsReg8(S) Then RegSize:=1
 Else If IsReg16(S) Then RegSize:=2
 Else If IsReg32(S) Then RegSize:=4
 Else If IsSegReg(S) Then RegSize:=2
 Else RegSize:=0;
End;

Function RegToOpType(S:String):Byte;
{ Determine le type d'operande pour un registre }
Begin
 If IsReg8(S) Then RegToOpType:=OT_REG8
 Else If IsReg16(S) Then RegToOpType:=OT_REG16
 Else If IsReg32(S) Then RegToOpType:=OT_REG32
 Else If IsSegReg(S) Then RegToOpType:=OT_SEGREG
 Else RegToOpType:=OT_NONE;
End;

Function IsSizePrefix(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsSizePrefix:=(U='BYTE')or(U='WORD')or(U='DWORD')or
  (U='FWORD')or(U='QWORD')or(U='TBYTE')or
  (U='NEAR')or(U='FAR')or(U='SHORT');
End;

Function SizePrefixToBytes(S:String):Byte;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 If U='BYTE' Then SizePrefixToBytes:=1
 Else If U='WORD' Then SizePrefixToBytes:=2
 Else If U='DWORD' Then SizePrefixToBytes:=4
 Else If U='FWORD' Then SizePrefixToBytes:=6
 Else If U='QWORD' Then SizePrefixToBytes:=8
 Else If U='TBYTE' Then SizePrefixToBytes:=10
 Else If U='NEAR' Then Begin
  If Mode32 Then SizePrefixToBytes:=4
  Else SizePrefixToBytes:=2;
 End
 Else If U='FAR' Then Begin
  If Mode32 Then SizePrefixToBytes:=6
  Else SizePrefixToBytes:=4;
 End
 Else If U='SHORT' Then SizePrefixToBytes:=1
 Else SizePrefixToBytes:=0;
End;

Procedure InitOperand(Var Op:TOperand);
Begin
 Op.OpType:=OT_NONE;
 Op.Reg:='';
 Op.Imm:=0;
 Op.MemExpr:='';
 Op.Size:=0;
 Op.LabelName:='';
 Op.BaseReg:='';
 Op.IndexReg:='';
 Op.Scale:=0;
 Op.Disp:=0;
 Op.HasDisp:=False;
 Op.SegOverride:='';
End;

Function IsMemBaseReg16(S:String):Boolean;
{ Registres valides comme base en mode 16 bits }
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsMemBaseReg16:=(U='BX')or(U='BP')or(U='SI')or(U='DI');
End;

Function IsMemIndexReg16(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsMemIndexReg16:=(U='SI')or(U='DI');
End;

Function IsMemBaseReg32(S:String):Boolean;
Var
 U:String;
Begin
 U:=UpCaseStr(S);
 IsMemBaseReg32:=(U='EAX')or(U='EBX')or(U='ECX')or(U='EDX')or
  (U='ESI')or(U='EDI')or(U='EBP')or(U='ESP');
End;

Procedure ParseMemoryOperand(Var Op:TOperand;StartTok,EndTok:Integer);
{ Parse le contenu entre crochets [StartTok..EndTok] }
Var
 I:Integer;
 U:String;
 Negate:Boolean;
 V:LongInt;
 Code:Integer;
Begin
 Op.OpType:=OT_MEM;
 Op.BaseReg:='';
 Op.IndexReg:='';
 Op.Scale:=0;
 Op.Disp:=0;
 Op.HasDisp:=False;
 Op.MemExpr:='';
 Negate:=False;
 I:=StartTok;
 While I<=EndTok do Begin
  { Construire MemExpr pour affichage }
  If Op.MemExpr<>'' Then Op.MemExpr:=Op.MemExpr+Tokens[I].Value
  Else Op.MemExpr:=Tokens[I].Value;
  If Tokens[I].Kind=TK_REGISTER Then Begin
   U:=UpCaseStr(Tokens[I].Value);
   { Verifier s'il y a un facteur d'echelle: REG*2, REG*4, REG*8 }
   If(I+2<=EndTok)and(Tokens[I+1].Kind=TK_STAR)and
     (Tokens[I+2].Kind=TK_NUMBER)Then Begin
    Op.IndexReg:=U;
    Val(Tokens[I+2].Value,V,Code);
    If Code=0 Then Op.Scale:=Byte(V)
    Else Op.Scale:=1;
    Op.MemExpr:=Op.MemExpr+Tokens[I+1].Value+Tokens[I+2].Value;
    Inc(I,2);
   End
   Else If Op.BaseReg='' Then
    Op.BaseReg:=U
   Else If Op.IndexReg='' Then Begin
    Op.IndexReg:=U;
    Op.Scale:=1;
   End;
  End
  Else If Tokens[I].Kind=TK_NUMBER Then Begin
   V:=ParseNumericValue(Tokens[I].Value);
   If Negate Then V:=-V;
   Op.Disp:=Op.Disp+V;
   Op.HasDisp:=True;
   Negate:=False;
  End
  Else If Tokens[I].Kind=TK_IDENT Then Begin
   { Symbole dans l'adressage memoire, ex: [myvar] ou [BX+myvar] }
   U:=Tokens[I].Value;
   Op.LabelName:=U;
   Op.HasDisp:=True;
  End
  Else If Tokens[I].Kind=TK_PLUS Then
   Negate:=False
  Else If Tokens[I].Kind=TK_MINUS Then
   Negate:=True;
  Inc(I);
 End;
 { Determiner la taille par defaut si pas de prefixe }
 If Op.Size=0 Then Begin
  If(Op.BaseReg<>'')and(IsReg32(Op.BaseReg))Then Op.Size:=4
  Else If(Op.BaseReg<>'')and(IsReg16(Op.BaseReg))Then Op.Size:=2;
 End;
End;

Function ParseOperand(Var TokIdx:Integer):TOperand;
{ Parse un operande a partir de la position TokIdx dans les tokens.
  Avance TokIdx apres le dernier token consomme. }
Var
 Op:TOperand;
 U:String;
 V:LongInt;
 BracketStart,BracketEnd:Integer;
 SzByte:Byte;
Begin
 InitOperand(Op);
 If(TokIdx<1)or(TokIdx>TokenCount)Then Begin
  ParseOperand:=Op;
  Exit;
 End;
 { Detecter prefixe de segment: CS: DS: etc. }
 If(Tokens[TokIdx].Kind=TK_REGISTER)and IsSegReg(Tokens[TokIdx].Value)Then Begin
  If(TokIdx+1<=TokenCount)and(Tokens[TokIdx+1].Kind=TK_COLON)Then Begin
   Op.SegOverride:=UpCaseStr(Tokens[TokIdx].Value);
   Inc(TokIdx,2);
   If TokIdx>TokenCount Then Begin
    ParseOperand:=Op;
    Exit;
   End;
  End;
 End;
 { Detecter BYTE PTR / WORD PTR / DWORD PTR }
 If(Tokens[TokIdx].Kind=TK_IDENT)or(Tokens[TokIdx].Kind=TK_REGISTER)Then Begin
  U:=UpCaseStr(Tokens[TokIdx].Value);
  If IsSizePrefix(U) Then Begin
   SzByte:=SizePrefixToBytes(U);
   Inc(TokIdx);
   { Sauter PTR s'il est present }
   If(TokIdx<=TokenCount)and(UpCaseStr(Tokens[TokIdx].Value)='PTR')Then
    Inc(TokIdx);
   Op.Size:=SzByte;
   If TokIdx>TokenCount Then Begin
    ParseOperand:=Op;
    Exit;
   End;
  End;
 End;
 { Detecter OFFSET label }
 If(Tokens[TokIdx].Kind=TK_IDENT)or(Tokens[TokIdx].Kind=TK_DIRECTIVE)Then Begin
  U:=UpCaseStr(Tokens[TokIdx].Value);
  If U='OFFSET' Then Begin
   Inc(TokIdx);
   If TokIdx<=TokenCount Then Begin
    If Tokens[TokIdx].Kind=TK_LABEL Then
     Op.LabelName:=Tokens[TokIdx].Value
    Else
     Op.LabelName:=Tokens[TokIdx].Value;
    Op.OpType:=OT_OFFSET;
    If Mode32 Then Op.Size:=4
    Else Op.Size:=2;
    Inc(TokIdx);
   End;
   ParseOperand:=Op;
   Exit;
  End;
  { Detecter SEG label }
  If U='SEG' Then Begin
   Inc(TokIdx);
   If TokIdx<=TokenCount Then Begin
    Op.LabelName:=Tokens[TokIdx].Value;
    Op.OpType:=OT_SEG;
    Op.Size:=2;
    Inc(TokIdx);
   End;
   ParseOperand:=Op;
   Exit;
  End;
 End;
 { Operande registre }
 If Tokens[TokIdx].Kind=TK_REGISTER Then Begin
  Op.Reg:=UpCaseStr(Tokens[TokIdx].Value);
  Op.OpType:=RegToOpType(Op.Reg);
  Op.Size:=RegSize(Op.Reg);
  Inc(TokIdx);
  ParseOperand:=Op;
  Exit;
 End;
 { Operande memoire entre crochets }
 If Tokens[TokIdx].Kind=TK_LBRACKET Then Begin
  BracketStart:=TokIdx+1;
  BracketEnd:=TokIdx+1;
  { Trouver le crochet fermant }
  While(BracketEnd<=TokenCount)and(Tokens[BracketEnd].Kind<>TK_RBRACKET)do
   Inc(BracketEnd);
  Dec(BracketEnd); { Pointe au dernier token avant ] }
  If BracketStart<=BracketEnd Then
   ParseMemoryOperand(Op,BracketStart,BracketEnd);
  { Avancer apres le crochet fermant }
  TokIdx:=BracketEnd+2;
  ParseOperand:=Op;
  Exit;
 End;
 { Operande immediat (nombre) }
 If Tokens[TokIdx].Kind=TK_NUMBER Then Begin
  V:=ParseNumericValue(Tokens[TokIdx].Value);
  Op.Imm:=V;
  If(V>=-128)and(V<=255)Then Begin
   Op.OpType:=OT_IMM8;
   If Op.Size=0 Then Op.Size:=1;
  End
  Else If(V>=-32768)and(V<=65535)Then Begin
   Op.OpType:=OT_IMM16;
   If Op.Size=0 Then Op.Size:=2;
  End
  Else Begin
   Op.OpType:=OT_IMM32;
   If Op.Size=0 Then Op.Size:=4;
  End;
  Inc(TokIdx);
  ParseOperand:=Op;
  Exit;
 End;
 { Immediat negatif: -nombre }
 If(Tokens[TokIdx].Kind=TK_MINUS)and(TokIdx<TokenCount)and
   (Tokens[TokIdx+1].Kind=TK_NUMBER)Then Begin
  V:=-ParseNumericValue(Tokens[TokIdx+1].Value);
  Op.Imm:=V;
  If(V>=-128)and(V<=127)Then Begin
   Op.OpType:=OT_IMM8;
   If Op.Size=0 Then Op.Size:=1;
  End
  Else If(V>=-32768)and(V<=32767)Then Begin
   Op.OpType:=OT_IMM16;
   If Op.Size=0 Then Op.Size:=2;
  End
  Else Begin
   Op.OpType:=OT_IMM32;
   If Op.Size=0 Then Op.Size:=4;
  End;
  Inc(TokIdx,2);
  ParseOperand:=Op;
  Exit;
 End;
 { Operande label/identifiant (reference memoire directe ou label de saut) }
 If(Tokens[TokIdx].Kind=TK_IDENT)or(Tokens[TokIdx].Kind=TK_LABEL)Then Begin
  Op.LabelName:=Tokens[TokIdx].Value;
  Op.OpType:=OT_LABEL;
  Inc(TokIdx);
  { Verifier si c'est suivi de crochets: var[BX] }
  If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_LBRACKET)Then Begin
   BracketStart:=TokIdx+1;
   BracketEnd:=TokIdx+1;
   While(BracketEnd<=TokenCount)and(Tokens[BracketEnd].Kind<>TK_RBRACKET)do
    Inc(BracketEnd);
   Dec(BracketEnd);
   If BracketStart<=BracketEnd Then
    ParseMemoryOperand(Op,BracketStart,BracketEnd);
   Op.OpType:=OT_MEM;
   TokIdx:=BracketEnd+2;
  End;
  ParseOperand:=Op;
  Exit;
 End;
 { Token non reconnu, avancer }
 Inc(TokIdx);
 ParseOperand:=Op;
End;

Function OperandTypeName(OT:Byte):String;
Begin
 Case OT of
  OT_NONE:OperandTypeName:='NONE';
  OT_REG8:OperandTypeName:='REG8';
  OT_REG16:OperandTypeName:='REG16';
  OT_REG32:OperandTypeName:='REG32';
  OT_SEGREG:OperandTypeName:='SEGREG';
  OT_MEM:OperandTypeName:='MEM';
  OT_IMM8:OperandTypeName:='IMM8';
  OT_IMM16:OperandTypeName:='IMM16';
  OT_IMM32:OperandTypeName:='IMM32';
  OT_LABEL:OperandTypeName:='LABEL';
  OT_OFFSET:OperandTypeName:='OFFSET';
  OT_SEG:OperandTypeName:='SEG';
  Else OperandTypeName:='?';
 End;
End;

Procedure ParseInstructionLine(LineIdx:LongInt;Var AsmL:TAsmLine);
{ Parse une ligne d'instruction ASM en ses composants }
Var
 TokIdx:Integer;
 U:String;
Begin
 AsmL.LabelStr:='';
 AsmL.Mnemonic:='';
 InitOperand(AsmL.Op1);
 InitOperand(AsmL.Op2);
 AsmL.Comment:='';
 AsmL.LineNum:=LineIdx;
 AsmL.IsDirective:=False;
 AsmL.IsTranslated:=False;
 TokenizeLine(SrcLines[LineIdx]^);
 If TokenCount=0 Then Exit;
 TokIdx:=1;
 { Extraire le label si present }
 If Tokens[TokIdx].Kind=TK_LABEL Then Begin
  AsmL.LabelStr:=Tokens[TokIdx].Value;
  Inc(TokIdx);
  If TokIdx>TokenCount Then Exit;
 End;
 { Extraire le commentaire de fin si present }
 If Tokens[TokenCount].Kind=TK_COMMENT Then
  AsmL.Comment:=Tokens[TokenCount].Value;
 { Directive ? }
 If Tokens[TokIdx].Kind=TK_DIRECTIVE Then Begin
  AsmL.IsDirective:=True;
  AsmL.Mnemonic:=UpCaseStr(Tokens[TokIdx].Value);
  Exit;
 End;
 { Mnemonique }
 If Tokens[TokIdx].Kind=TK_MNEMONIC Then Begin
  AsmL.Mnemonic:=UpCaseStr(Tokens[TokIdx].Value);
  Inc(TokIdx);
 End
 Else If Tokens[TokIdx].Kind=TK_IDENT Then Begin
  { Peut etre un identifiant suivi d'une directive (ex: myvar DB ...) }
  U:=UpCaseStr(Tokens[TokIdx].Value);
  If(TokIdx<TokenCount)and(Tokens[TokIdx+1].Kind=TK_DIRECTIVE)Then Begin
   AsmL.IsDirective:=True;
   AsmL.LabelStr:=Tokens[TokIdx].Value;
   AsmL.Mnemonic:=UpCaseStr(Tokens[TokIdx+1].Value);
   Exit;
  End;
  { Sinon traiter comme mnemonique inconnu }
  AsmL.Mnemonic:=U;
  Inc(TokIdx);
 End
 Else Exit;
 { Parser le premier operande }
 If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind<>TK_COMMENT)Then
  AsmL.Op1:=ParseOperand(TokIdx);
 { Sauter la virgule }
 If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_COMMA)Then
  Inc(TokIdx);
 { Parser le deuxieme operande }
 If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind<>TK_COMMENT)Then
  AsmL.Op2:=ParseOperand(TokIdx);
End;

Procedure ProcessOperands;
{ Orchestrateur : parse toutes les lignes d'instructions et collecte les statistiques }
Var
 I:LongInt;
 AsmL:TAsmLine;
 InstrCount:LongInt;
 RegCount,MemCount,ImmCount,LabelCount:LongInt;
 OffsetCount,SegCount:LongInt;

 Procedure CountOperand(Var Op:TOperand);
 Begin
  Case Op.OpType of
   OT_REG8,OT_REG16,OT_REG32,OT_SEGREG:Inc(RegCount);
   OT_MEM:Inc(MemCount);
   OT_IMM8,OT_IMM16,OT_IMM32:Inc(ImmCount);
   OT_LABEL:Inc(LabelCount);
   OT_OFFSET:Inc(OffsetCount);
   OT_SEG:Inc(SegCount);
  End;
 End;

Begin
 InstrCount:=0;
 RegCount:=0;
 MemCount:=0;
 ImmCount:=0;
 LabelCount:=0;
 OffsetCount:=0;
 SegCount:=0;
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount=0 Then Continue;
  { Ignorer les lignes de directives pures }
  If(Tokens[1].Kind=TK_DIRECTIVE)Then Continue;
  If(Tokens[1].Kind=TK_LABEL)and(TokenCount>=2)and
    (Tokens[2].Kind=TK_DIRECTIVE)Then Continue;
  If(Tokens[1].Kind=TK_IDENT)and(TokenCount>=2)and
    (Tokens[2].Kind=TK_DIRECTIVE)Then Continue;
  { Parser les lignes avec mnemonique }
  If(Tokens[1].Kind=TK_MNEMONIC)or
    ((Tokens[1].Kind=TK_LABEL)and(TokenCount>=2)and
     (Tokens[2].Kind=TK_MNEMONIC))Then Begin
   ParseInstructionLine(I,AsmL);
   If AsmL.Mnemonic<>'' Then Begin
    Inc(InstrCount);
    CountOperand(AsmL.Op1);
    CountOperand(AsmL.Op2);
   End;
  End;
 End;
 WriteLn('Analyse des operandes : ',InstrCount,' instructions.');
 If Verbose Then Begin
  WriteLn('  Registres  : ',RegCount);
  WriteLn('  Memoire    : ',MemCount);
  WriteLn('  Immediats  : ',ImmCount);
  WriteLn('  Labels     : ',LabelCount);
  WriteLn('  OFFSET     : ',OffsetCount);
  WriteLn('  SEG        : ',SegCount);
 End;
End;

{ ============================================================
  Inference de types pour les variables et registres - TODO 8
  ============================================================ }

Function InferTypeFromSize(Size:Word):Byte;
{ Deduit un type Pascal par defaut a partir de la taille en octets }
Begin
 Case Size of
  1:InferTypeFromSize:=PT_BYTE;
  2:InferTypeFromSize:=PT_WORD;
  4:InferTypeFromSize:=PT_LONGINT;
  6:InferTypeFromSize:=PT_POINTER;
  Else InferTypeFromSize:=PT_ARRAY;
 End;
End;

Function IsSignedMnemonic(M:String):Boolean;
{ Mnemoniques qui impliquent un traitement signe }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsSignedMnemonic:=(U='IMUL')or(U='IDIV')or(U='MOVSX')or
  (U='CBW')or(U='CWD')or(U='CWDE')or(U='CDQ')or
  (U='SAR')or(U='JS')or(U='JNS')or(U='JG')or(U='JGE')or
  (U='JL')or(U='JLE')or(U='JNG')or(U='JNGE')or
  (U='JNL')or(U='JNLE')or(U='SETG')or(U='SETGE')or
  (U='SETL')or(U='SETLE')or(U='CMOVG')or(U='CMOVGE')or
  (U='CMOVL')or(U='CMOVLE');
End;

Function IsUnsignedMnemonic(M:String):Boolean;
{ Mnemoniques qui impliquent un traitement non signe }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsUnsignedMnemonic:=(U='MUL')or(U='DIV')or(U='MOVZX')or
  (U='SHR')or(U='JA')or(U='JAE')or(U='JB')or(U='JBE')or
  (U='JNA')or(U='JNAE')or(U='JNB')or(U='JNBE')or
  (U='SETA')or(U='SETAE')or(U='SETB')or(U='SETBE')or
  (U='CMOVA')or(U='CMOVAE')or(U='CMOVB')or(U='CMOVBE');
End;

Function IsStringMnemonic(M:String):Boolean;
{ Mnemoniques d'operations sur chaines }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsStringMnemonic:=(U='MOVSB')or(U='MOVSW')or(U='MOVSD')or
  (U='CMPSB')or(U='CMPSW')or(U='CMPSD')or
  (U='LODSB')or(U='LODSW')or(U='LODSD')or
  (U='STOSB')or(U='STOSW')or(U='STOSD')or
  (U='SCASB')or(U='SCASW')or(U='SCASD')or
  (U='REP')or(U='REPE')or(U='REPZ')or
  (U='REPNE')or(U='REPNZ');
End;

Function IsCharContext(M:String;Var Op1,Op2:TOperand):Boolean;
{ Detecte si une instruction utilise un contexte de caractere }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsCharContext:=False;
 { CMP reg8, imm dans la plage ASCII imprimable }
 If(U='CMP')and(Op1.OpType=OT_REG8)Then Begin
  If(Op2.OpType in [OT_IMM8,OT_IMM16])and
    (Op2.Imm>=32)and(Op2.Imm<=126)Then
   IsCharContext:=True;
 End;
 { MOV reg8, imm ASCII }
 If(U='MOV')and(Op1.OpType=OT_REG8)Then Begin
  If(Op2.OpType in [OT_IMM8,OT_IMM16])and
    (Op2.Imm>=32)and(Op2.Imm<=126)Then
   IsCharContext:=True;
 End;
End;

Function IsBooleanContext(M:String;Var Op1,Op2:TOperand):Boolean;
{ Detecte si une instruction utilise un contexte booleen }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsBooleanContext:=False;
 { CMP var, 0 ou CMP var, 1 }
 If U='CMP' Then Begin
  If(Op2.OpType in [OT_IMM8,OT_IMM16,OT_IMM32])and
    ((Op2.Imm=0)or(Op2.Imm=1))Then Begin
   If(Op1.OpType=OT_MEM)or(Op1.OpType=OT_LABEL)Then
    IsBooleanContext:=True;
  End;
 End;
 { TEST reg, reg (auto-test) }
 If U='TEST' Then Begin
  If(Op1.OpType in [OT_REG8,OT_REG16,OT_REG32])and
    (Op2.OpType in [OT_REG8,OT_REG16,OT_REG32])and
    (UpCaseStr(Op1.Reg)=UpCaseStr(Op2.Reg))Then
   IsBooleanContext:=True;
 End;
End;

Function IsPointerContext(M:String;Var Op1,Op2:TOperand):Boolean;
{ Detecte si une instruction utilise un contexte de pointeur }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsPointerContext:=False;
 { LDS/LES/LFS/LGS => pointeur FAR }
 If(U='LDS')or(U='LES')or(U='LFS')or(U='LGS')Then
  IsPointerContext:=True;
 { LEA => adresse }
 If U='LEA' Then IsPointerContext:=True;
 { MOV reg, OFFSET => pointeur }
 If(U='MOV')and(Op2.OpType=OT_OFFSET)Then
  IsPointerContext:=True;
End;

Procedure RefineSymbolType(SymIdx:Integer;NewType:Byte);
{ Raffine le type d'un symbole si le nouveau type est plus specifique }
Begin
 If(SymIdx<1)or(SymIdx>SymbolCount)Then Exit;
 { Ne pas degrader un type deja specifique }
 Case Symbols[SymIdx].DataType of
  PT_BOOLEAN,PT_CHAR,PT_STRING,PT_PCHAR,PT_POINTER:Exit;
 End;
 { Promouvoir vers un type plus specifique }
 Case NewType of
  PT_BOOLEAN,PT_CHAR,PT_STRING,PT_PCHAR,PT_POINTER:
   Symbols[SymIdx].DataType:=NewType;
  PT_SHORTINT:
   If Symbols[SymIdx].DataType=PT_BYTE Then
    Symbols[SymIdx].DataType:=PT_SHORTINT;
  PT_INTEGER:
   If Symbols[SymIdx].DataType=PT_WORD Then
    Symbols[SymIdx].DataType:=PT_INTEGER;
 End;
End;

Procedure InferFromInstruction(Var AsmL:TAsmLine;
 Var SignedCount,UnsignedCount,BoolCount,CharCount,
     PtrCount,StrCount:LongInt);
{ Analyse une instruction pour inferer des types }
Var
 U:String;
 Idx:Integer;
Begin
 U:=AsmL.Mnemonic;
 { Compter les contextes signes / non-signes }
 If IsSignedMnemonic(U) Then Begin
  Inc(SignedCount);
  { Raffiner les operandes memoire/label vers signe }
  If(AsmL.Op1.OpType=OT_LABEL)or(AsmL.Op1.OpType=OT_MEM)Then Begin
   Idx:=FindSymbol(AsmL.Op1.LabelName);
   If Idx>0 Then Begin
    If Symbols[Idx].Size=1 Then RefineSymbolType(Idx,PT_SHORTINT)
    Else If Symbols[Idx].Size=2 Then RefineSymbolType(Idx,PT_INTEGER);
   End;
  End;
 End;
 If IsUnsignedMnemonic(U) Then Inc(UnsignedCount);
 { Contexte chaine }
 If IsStringMnemonic(U) Then Begin
  Inc(StrCount);
  { SI/DI pointent vers des donnees de chaine }
 End;
 { Contexte booleen : CMP var, 0/1 }
 If IsBooleanContext(U,AsmL.Op1,AsmL.Op2) Then Begin
  Inc(BoolCount);
  If(AsmL.Op1.OpType=OT_LABEL)or(AsmL.Op1.OpType=OT_MEM)Then Begin
   Idx:=FindSymbol(AsmL.Op1.LabelName);
   If Idx>0 Then Begin
    If Symbols[Idx].Size=1 Then
     RefineSymbolType(Idx,PT_BOOLEAN);
   End;
  End;
 End;
 { Contexte caractere }
 If IsCharContext(U,AsmL.Op1,AsmL.Op2) Then Begin
  Inc(CharCount);
  { Si l'operande memoire est DB, raffiner en Char }
  If(AsmL.Op1.OpType=OT_LABEL)or(AsmL.Op1.OpType=OT_MEM)Then Begin
   Idx:=FindSymbol(AsmL.Op1.LabelName);
   If Idx>0 Then Begin
    If Symbols[Idx].Size=1 Then
     RefineSymbolType(Idx,PT_CHAR);
   End;
  End;
 End;
 { Contexte pointeur }
 If IsPointerContext(U,AsmL.Op1,AsmL.Op2) Then Begin
  Inc(PtrCount);
  { LDS/LES/LFS/LGS : l'operande memoire est un Pointer }
  If(UpCaseStr(U)='LDS')or(UpCaseStr(U)='LES')or
    (UpCaseStr(U)='LFS')or(UpCaseStr(U)='LGS')Then Begin
   If(AsmL.Op2.OpType=OT_LABEL)or(AsmL.Op2.OpType=OT_MEM)Then Begin
    Idx:=FindSymbol(AsmL.Op2.LabelName);
    If Idx>0 Then RefineSymbolType(Idx,PT_POINTER);
   End;
  End;
 End;
 { MOV avec OFFSET => la source est un pointeur/PChar }
 If(UpCaseStr(U)='MOV')and(AsmL.Op2.OpType=OT_OFFSET)Then Begin
  Idx:=FindSymbol(AsmL.Op2.LabelName);
  If Idx>0 Then Begin
   { Si la cible est une variable de type DB string, c'est un PChar }
   If Symbols[Idx].DataType=PT_STRING Then
    RefineSymbolType(Idx,PT_PCHAR)
   Else If Symbols[Idx].DataType=PT_ARRAY Then
    RefineSymbolType(Idx,PT_PCHAR);
  End;
 End;
End;

Procedure RefineDataVarTypes;
{ Raffine le type des variables de donnees a partir de leur contenu }
Var
 I:Integer;
 DV:TDataVar;
Begin
 For I:=1 to DataVarCount do Begin
  DV:=DataVars[I];
  { DB avec une seule chaine => PChar ou String }
  If(DV.DirType=DT_DB)and(DV.ElemCount>=1)Then Begin
   If(DV.ElemCount=1)and(DV.Elements[1].ElemType=DE_STRING)Then Begin
    { Chaine seule => String }
    DataVars[I].PascalType:=PT_STRING;
    { Mettre a jour le symbole }
    If FindSymbol(DV.Name)>0 Then
     Symbols[FindSymbol(DV.Name)].DataType:=PT_STRING;
   End
   Else If(DV.ElemCount=2)and(DV.Elements[1].ElemType=DE_STRING)and
     (DV.Elements[2].ElemType=DE_NUMBER)and(DV.Elements[2].NumValue=0)Then Begin
    { Chaine + 0 terminateur => PChar }
    DataVars[I].PascalType:=PT_PCHAR;
    If FindSymbol(DV.Name)>0 Then
     Symbols[FindSymbol(DV.Name)].DataType:=PT_PCHAR;
   End
   Else If(DV.ElemCount>=2)and(DV.Elements[1].ElemType=DE_STRING)Then Begin
    { Chaine + donnees => PChar }
    DataVars[I].PascalType:=PT_PCHAR;
    If FindSymbol(DV.Name)>0 Then
     Symbols[FindSymbol(DV.Name)].DataType:=PT_PCHAR;
   End;
  End;
  { DB avec un seul octet 0 ou 1 => potentiellement Boolean }
  If(DV.DirType=DT_DB)and(DV.ElemCount=1)and
    (DV.Elements[1].ElemType=DE_NUMBER)Then Begin
   If(DV.Elements[1].NumValue=0)or(DV.Elements[1].NumValue=1)Then Begin
    DataVars[I].PascalType:=PT_BOOLEAN;
    If FindSymbol(DV.Name)>0 Then
     Symbols[FindSymbol(DV.Name)].DataType:=PT_BOOLEAN;
   End;
  End;
  { DD avec OFFSET => Pointer }
  If(DV.DirType=DT_DD)and(DV.ElemCount=1)and
    (DV.Elements[1].ElemType=DE_OFFSET)Then Begin
   DataVars[I].PascalType:=PT_POINTER;
   If FindSymbol(DV.Name)>0 Then
    Symbols[FindSymbol(DV.Name)].DataType:=PT_POINTER;
  End;
  { DF (6 octets) => Pointer FAR 48 bits }
  If DV.DirType=DT_DF Then Begin
   DataVars[I].PascalType:=PT_POINTER;
   If FindSymbol(DV.Name)>0 Then
    Symbols[FindSymbol(DV.Name)].DataType:=PT_POINTER;
  End;
 End;
End;

Procedure ProcessTypeInference;
{ Orchestrateur : infere les types des variables et registres }
Var
 I:LongInt;
 AsmL:TAsmLine;
 InstrCount:LongInt;
 SignedCount,UnsignedCount:LongInt;
 BoolCount,CharCount,PtrCount,StrCount:LongInt;
 RefinedCount:LongInt;
 OldType:Byte;
Begin
 SignedCount:=0;
 UnsignedCount:=0;
 BoolCount:=0;
 CharCount:=0;
 PtrCount:=0;
 StrCount:=0;
 InstrCount:=0;
 { Passe 1 : Raffiner les types des variables de donnees (contenu) }
 RefineDataVarTypes;
 { Passe 2 : Analyser les instructions pour inferer les types }
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount=0 Then Continue;
  If(Tokens[1].Kind=TK_DIRECTIVE)Then Continue;
  If(Tokens[1].Kind=TK_LABEL)and(TokenCount>=2)and
    (Tokens[2].Kind=TK_DIRECTIVE)Then Continue;
  If(Tokens[1].Kind=TK_IDENT)and(TokenCount>=2)and
    (Tokens[2].Kind=TK_DIRECTIVE)Then Continue;
  If(Tokens[1].Kind=TK_MNEMONIC)or
    ((Tokens[1].Kind=TK_LABEL)and(TokenCount>=2)and
     (Tokens[2].Kind=TK_MNEMONIC))Then Begin
   ParseInstructionLine(I,AsmL);
   If AsmL.Mnemonic<>'' Then Begin
    Inc(InstrCount);
    InferFromInstruction(AsmL,SignedCount,UnsignedCount,
     BoolCount,CharCount,PtrCount,StrCount);
   End;
  End;
 End;
 { Compter combien de symboles ont ete raffines }
 RefinedCount:=0;
 For I:=1 to SymbolCount do Begin
  OldType:=InferTypeFromSize(Symbols[I].Size);
  If Symbols[I].DataType<>OldType Then Inc(RefinedCount);
 End;
 WriteLn('Inference de types : ',InstrCount,' instructions analysees.');
 If Verbose Then Begin
  WriteLn('  Contextes signes   : ',SignedCount);
  WriteLn('  Contextes non-sign : ',UnsignedCount);
  WriteLn('  Contextes booleen  : ',BoolCount);
  WriteLn('  Contextes char     : ',CharCount);
  WriteLn('  Contextes pointeur : ',PtrCount);
  WriteLn('  Contextes chaine   : ',StrCount);
  WriteLn('  Symboles raffines  : ',RefinedCount);
 End;
End;

Procedure ShowHelp;
Begin
 WriteLn('ASM2PAS v',ASM2PAS_VERSION,' - Transpileur d''Assembleur 8086/80386 vers Pascal');
 WriteLn('Usage : ASM2PAS [options] fichier.ASM [fichier.PAS]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -16         Forcer le mode 16 bits (8086)');
 WriteLn('  -32         Forcer le mode 32 bits (80386)');
 WriteLn('  -o file     Nom du fichier .PAS de sortie');
 WriteLn('  -inline     Garder le code non-traduisible en ASM inline (defaut)');
 WriteLn('  -noinline   Ne pas utiliser d''ASM inline');
 WriteLn('  -comments   Inclure le code ASM original en commentaire');
 WriteLn('  -v          Mode verbeux');
 WriteLn('  -h, --help  Afficher cette aide');
 Halt(0);
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
 I:=1;
 While I<=ParamCount do Begin
  Param:=ParamStr(I);
  If(Param='-h')or(Param='--help')or(Param='/?')Then Begin
   ShowHelp;
   Halt(0);
  End
  Else If Param='-16' Then Mode32:=False
  Else If Param='-32' Then Mode32:=True
  Else If Param='-inline' Then UseInline:=True
  Else If Param='-noinline' Then UseInline:=False
  Else If Param='-comments' Then AddComments:=True
  Else If Param='-v' Then Verbose:=True
  Else If(Param='-o')and(I<ParamCount)Then Begin
   Inc(I);
   OutFileName:=ParamStr(I);
  End
  Else If(Length(Param)>0)and(Param[1]='-')Then Begin
   WriteLn('Option inconnue : ',Param);
   Halt(1);
  End
  Else If InFileName='' Then InFileName:=Param
  Else If OutFileName='' Then OutFileName:=Param;
  Inc(I);
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
 WriteLn('ASM2PAS v',ASM2PAS_VERSION,' (',ASM2PAS_DATE,')');
 WriteLn('Transpileur Assembleur 8086/80386 (MASM/TASM) vers Pascal');
 WriteLn;
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
  WriteLn('Fichier source    : ',InFileName);
  WriteLn('Fichier de sortie : ',OutFileName);
  If Mode32 Then WriteLn('Mode : 32 bits (80386)')
            Else WriteLn('Mode : 16 bits (8086)');
  If UseInline Then WriteLn('ASM inline : active')
               Else WriteLn('ASM inline : desactive');
  If AddComments Then WriteLn('Commentaires ASM : actifs');
 End;
 { Analyseur lexical (TODO 2) }
 ReadASMFile;
 { Analyse des directives (TODO 3) }
 ProcessDirectives;
 { Analyse des donnees (TODO 4) }
 ProcessDataDirectives;
 { Analyse des procedures (TODO 5) }
 ProcessProcedureDirectives;
 { Table des symboles (TODO 6) }
 BuildSymbolTable;
 { Analyse des operandes (TODO 7) }
 ProcessOperands;
 { Inference de types (TODO 8) }
 ProcessTypeInference;
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
 FreeSourceLines;
 WriteLn('Transpilation terminee.');
END.
