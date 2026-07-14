{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Transpileur d'assembleur 8086/80386 (syntaxe MASM/TASM)
                en langage de programmation Pascal (Turbo Pascal)
}

{ TODO - Liste des 25 points a implementer pour le transpileur ASM vers Pascal :

  1.  [IMPLEMENTE] Infrastructure, options de ligne de commande et constantes globales.
      Programme principal ASM2PAS en Free Pascal.
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

  9.  [IMPLEMENTE] Traduction des registres en variables Pascal.
      Mapper les registres CPU vers des variables Pascal :
      AX/EAX -> RegAX:Word/RegEAX:LongInt, etc.
      Gerer les sous-registres : AL = Lo(RegAX), AH = Hi(RegAX).
      Detecter quand un registre est utilise comme variable locale
      temporaire et le remplacer par une variable Pascal nommee.
      Gerer le registre FLAGS comme un ensemble de booleens
      (FlagCF, FlagZF, FlagSF, FlagOF). Mapper le pointeur de
      pile SP/ESP et le registre de base BP/EBP pour l'acces
      aux parametres et variables locales sur la pile.

  10. [IMPLEMENTE] Traduction des instructions de transfert de donnees.
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

  11. [IMPLEMENTE] Traduction des instructions arithmetiques.
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

  12. [IMPLEMENTE] Traduction des instructions logiques et de decalage.
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

  13. [IMPLEMENTE] Traduction des comparaisons et sauts conditionnels en IF/THEN/ELSE.
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

  14. [IMPLEMENTE] Traduction des sauts inconditionnels et detection de boucles.
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

  15. [IMPLEMENTE] Traduction des appels de procedures (CALL/RET).
      CALL label -> appel de procedure/fonction Pascal.
      Si la procedure est connue (dans la table des symboles),
      generer un appel Pascal avec les parametres detectes.
      Analyser les PUSH avant CALL pour identifier les parametres
      selon la convention d'appel : C (droite a gauche, appelant
      nettoie), PASCAL (gauche a droite, appele nettoie), STDCALL
      (droite a gauche, appele nettoie). RET -> Exit ou fin de
      procedure. RET n -> sortie avec nettoyage de pile.
      CALL FAR -> appel inter-segment.

  16. [IMPLEMENTE] Traduction des operations de pile (PUSH/POP).
      PUSH reg/mem/imm -> empiler sur la pile simulee ou passer
      comme parametre a la prochaine procedure appelee.
      POP reg/mem -> depiler. PUSHA/PUSHAD -> sauvegarder tous
      les registres. POPA/POPAD -> restaurer tous les registres.
      PUSHF/POPF -> sauvegarder/restaurer les flags.
      Quand les PUSH/POP encadrent un CALL, les convertir en
      parametres de la procedure appelee. Quand ils servent a
      sauvegarder/restaurer des registres, les convertir en
      variables temporaires locales.

  17. [IMPLEMENTE] Traduction des instructions de chaine (string operations).
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

  18. [IMPLEMENTE] Traduction des appels systeme (INT 21h DOS, INT 10h BIOS, etc.).
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

  19. [IMPLEMENTE] Traduction des modes d'adressage en syntaxe Pascal.
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

  20. [IMPLEMENTE] Gestion des extensions 80386 en mode 32 bits.
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

  21. [IMPLEMENTE] Generation du code Pascal : en-tete, uses, types et declarations.
      Emettre l'en-tete du fichier Pascal : Program <nom>;
      clause Uses (Dos, Crt, etc. selon les INT detectees),
      section Type (records pour les structures detectees,
      tableaux pour les zones de donnees), section Const
      (constantes EQU et donnees en lecture seule), section
      Var (variables globales pour les registres simules et
      les donnees du segment DATA). Generer les declarations
      Label pour les Goto encore necessaires apres l'analyse
      de flux de controle.

  22. [IMPLEMENTE] Generation du code Pascal : corps des procedures et fonctions.
      Pour chaque procedure ASM, generer une procedure ou
      fonction Pascal avec ses parametres et variables locales.
      Emettre le code traduit instruction par instruction dans
      le corps de la procedure. Gerer la valeur de retour :
      si AX/EAX est charge avant RET, generer une Function
      avec Result := RegAX. Imbriquer les structures de controle
      detectees (If/Then/Else, While, Repeat, For, Case).
      Generer le bloc BEGIN..END principal pour le point
      d'entree du programme.

  23. [IMPLEMENTE] Fallback ASM inline pour les instructions non-traduisibles.
      Pour les instructions qui n'ont pas d'equivalent Pascal
      direct (CLI, STI, HLT, IN, OUT, CPUID, RDTSC, instructions
      FPU x87, etc.), generer un bloc ASM inline Turbo Pascal :
      asm ... end; ou directive ASMMODE INTEL pour Free Pascal.
      Regrouper les instructions inline consecutives dans un seul
      bloc asm. Inserer un commentaire avertissant que le code
      n'a pas pu etre traduit. Gerer les interruptions non
      reconnues avec Intr(IntNo, Regs) en utilisant les Registers.

  24. [IMPLEMENTE] Passes d'optimisation sur le code Pascal genere.
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

  25. [IMPLEMENTE] Options de sortie, verification finale et rapport.
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

 { Limite pour les labels optimises }
 MAX_OPT_LABELS = 256;

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
 OT_FAR     = 12; { Adresse FAR absolue seg:ofs (ex: CALL 00C9:02CDh) }

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
  { Champs pour variables locales issues d'acces memoire indexes }
  IsIndexedMem:Boolean;   { True si cree pour un acces [BaseReg+IndexReg+Offset] }
  IndexOffset:LongInt;    { Offset dans l'adressage indexe }
  IndexBaseReg:String;    { Registre de base (BX, BP, etc.) }
  IndexIndexReg:String;   { Registre d'index (SI, DI, etc.) }
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
  StringsReplacement:String;
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
 NeedWinDos:Boolean;
 NeedDosBool:Boolean;
 NeedStrings:Boolean;
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
 { Labels optimises (ne pas emettre dans ProcessBodyGeneration) }
 OptLabels:Array[1..MAX_OPT_LABELS] of String;
 OptLabelCount:Integer;

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
 If Code=0 Then ParseNumericValue:=V
 { Fallback : si echec decimal, essayer comme hex sans suffixe }
 { (ex: segment '00C9' dans 'CALL 00C9:02CDh') }
 Else ParseNumericValue:=HexToInt(U);
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
 PendingLabel:String;
Begin
 DataVarCount:=0;
 PendingLabel:='';
 StringCount:=0;
 DupCount:=0;
 NumCount:=0;
 TotalBytes:=0;
 For I:=0 to SrcLineCount-1 do Begin
  TokenizeLine(SrcLines[I]^);
  If TokenCount=0 Then Continue;

  { DISEXE emet les donnees sous la forme "label:" puis "DB ..." sur
    la ligne suivante. Memoriser ce label pour nommer la directive anonyme. }
  If(Tokens[1].Kind=TK_LABEL)and
    ((TokenCount=1)or((TokenCount=2)and(Tokens[2].Kind=TK_COMMENT)))Then Begin
   PendingLabel:=Tokens[1].Value;
   Continue;
  End;

  If TokenCount<2 Then Begin
   If Tokens[1].Kind<>TK_COMMENT Then PendingLabel:='';
   Continue;
  End;
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
   If(DataVarCount>0)and(DataVars[DataVarCount].Name='')and
     (PendingLabel<>'')Then Begin
    DataVars[DataVarCount].Name:=PendingLabel;
    { Enregistrer immediatement la variable. CollectLabels reutilisera ce
      symbole et ne la reclassera pas comme une etiquette de code. }
    If SymbolCount<MAX_SYMBOLS Then Begin
     Inc(SymbolCount);
     Symbols[SymbolCount].Name:=PendingLabel;
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
   PendingLabel:='';
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
  End Else If Tokens[1].Kind<>TK_COMMENT Then
   PendingLabel:='';
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
 Procs[ProcCount].StringsReplacement:='';
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
      IsIndexedMem:=False;
      IndexOffset:=0;
      IndexBaseReg:='';
      IndexIndexReg:='';
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
      IsIndexedMem:=False;
      IndexOffset:=0;
      IndexBaseReg:='';
      IndexIndexReg:='';
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
  { Verifier si c'est une adresse FAR: seg:ofs (ex: CALL 00C9:02CDh) }
  If(TokIdx<=TokenCount)and(Tokens[TokIdx].Kind=TK_COLON)and
    (TokIdx+1<=TokenCount)and(Tokens[TokIdx+1].Kind=TK_NUMBER)Then Begin
   Op.OpType:=OT_FAR;
   Op.Size:=4;
   Op.Disp:=ParseNumericValue(Tokens[TokIdx+1].Value);
   Op.HasDisp:=True;
   Inc(TokIdx,2);
  End;
  ParseOperand:=Op;
  Exit;
 End;
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
  Detection des fonctions implicites (sans PROC/ENDP)
  ============================================================ }

Function IsProcAlreadyDefined(Name:String):Boolean;
{ Verifie si un nom est deja defini comme procedure dans Procs[]. }
Var
 I:Integer;
Begin
 IsProcAlreadyDefined:=False;
 For I:=1 to ProcCount do
  If UpCaseStr(Procs[I].Name)=UpCaseStr(Name) Then Begin
   IsProcAlreadyDefined:=True;
   Exit;
  End;
End;

Function DetectImplicitFunctionPattern(LabelLine:LongInt;
 Var EndLine:LongInt;Var RetBytes:Word):Boolean;
{ Detecte le pattern de fonction implicite :
  - etiquette: (deja verifie par l'appelant)
  - PUSH BP
  - MOV BP, SP
  - ... corps de la fonction ...
  - POP BP
  - RET [nnnn]
  Retourne True si le pattern est detecte.
  EndLine contient la ligne du RET, RetBytes contient la valeur de RET n. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 M:String;
 Op1Str,Op2Str:String;
 HasPushBP,HasMovBPSP,HasPopBP:Boolean;
 Line1,Line2:LongInt;
 NextLabelLine:LongInt;
Begin
 DetectImplicitFunctionPattern:=False;
 EndLine:=-1;
 RetBytes:=0;
 HasPushBP:=False;
 HasMovBPSP:=False;
 HasPopBP:=False;
 Line1:=-1;
 Line2:=-1;
 
 { Chercher PUSH BP sur la meme ligne ou les lignes suivantes }
 I:=LabelLine;
 ParseInstructionLine(I,AsmL);
 { Si le label est seul sur sa ligne, verifier la ligne suivante }
 If AsmL.Mnemonic='' Then Inc(I);
 
 { Chercher jusqu'a 3 lignes pour PUSH BP et MOV BP, SP }
 While(I<=LabelLine+3)and(I<SrcLineCount)do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Begin Inc(I); Continue; End;
  If AsmL.IsDirective Then Break; { Fin si directive }
  M:=UpCaseStr(AsmL.Mnemonic);
  
  { Verifier PUSH BP }
  If(M='PUSH')and(Not HasPushBP)Then Begin
   If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
    Op1Str:=UpCaseStr(AsmL.Op1.Reg);
    If(Op1Str='BP')or(Op1Str='EBP')Then Begin
     HasPushBP:=True;
     Line1:=I;
    End;
   End;
  End;
  
  { Verifier MOV BP, SP }
  If(M='MOV')and HasPushBP and(Not HasMovBPSP)Then Begin
   If(AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32])and
     (AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32])Then Begin
    Op1Str:=UpCaseStr(AsmL.Op1.Reg);
    Op2Str:=UpCaseStr(AsmL.Op2.Reg);
    If((Op1Str='BP')or(Op1Str='EBP'))and
      ((Op2Str='SP')or(Op2Str='ESP'))Then Begin
     HasMovBPSP:=True;
     Line2:=I;
    End;
   End;
  End;
  
  { Si on a les deux, on a le debut du pattern }
  If HasPushBP and HasMovBPSP Then Break;
  Inc(I);
 End;
 
 { Verifier qu'on a trouve le debut du pattern }
 If Not(HasPushBP and HasMovBPSP)Then Exit;
 
 { Chercher le prochain label pour delimiter la recherche }
 NextLabelLine:=SrcLineCount;
 For I:=Line2+1 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.LabelStr<>'' Then Begin
   NextLabelLine:=I;
   Break;
  End;
 End;
 
 { Chercher POP BP et RET dans le corps }
 I:=Line2+1;
 While I<NextLabelLine do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Begin Inc(I); Continue; End;
  M:=UpCaseStr(AsmL.Mnemonic);
  
  { Verifier POP BP }
  If M='POP' Then Begin
   If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
    Op1Str:=UpCaseStr(AsmL.Op1.Reg);
    If(Op1Str='BP')or(Op1Str='EBP')Then
     HasPopBP:=True;
   End;
  End;
  
  { Verifier RET/RETN/RETF }
  If(M='RET')or(M='RETN')or(M='RETF')Then Begin
   If HasPopBP Then Begin
    { Pattern complet detecte! }
    DetectImplicitFunctionPattern:=True;
    EndLine:=I;
    { Extraire la valeur de RET n si presente }
    If AsmL.Op1.OpType in [OT_IMM8,OT_IMM16,OT_IMM32] Then
     RetBytes:=Word(AsmL.Op1.Imm)
    Else
     RetBytes:=0;
    Exit;
   End;
  End;
  
  Inc(I);
 End;
End;

Procedure DetectImplicitFunctions;
{ Detecte les fonctions implicites (sans directive PROC/ENDP) en
  recherchant le pattern PUSH BP / MOV BP,SP ... POP BP / RET n.
  Ajoute les fonctions detectees dans la table Procs[]. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 LabelName:String;
 LabelLine:LongInt;
 EndLine:LongInt;
 RetBytes:Word;
 ParamBytes:Word;
 ParamCount:Byte;
 ImplicitCount:Integer;
 J:Byte;
Begin
 ImplicitCount:=0;
 
 { Parcourir toutes les lignes pour trouver des labels }
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.LabelStr='' Then Continue;
  
  { Ignorer les labels locaux (@@xxx ou @xxx) }
  LabelName:=AsmL.LabelStr;
  If IsLocalLabel(LabelName) Then Continue;
  
  { Ignorer si deja defini comme procedure }
  If IsProcAlreadyDefined(LabelName) Then Continue;
  
  { Ignorer si c'est le point d'entree (START, _start, main, etc.) }
  If(UpCaseStr(LabelName)=UpCaseStr(EntryPoint))Then Continue;
  If(UpCaseStr(LabelName)='START')Then Continue;
  If(UpCaseStr(LabelName)='_START')Then Continue;
  
  { Tenter de detecter le pattern de fonction }
  LabelLine:=I;
  If DetectImplicitFunctionPattern(LabelLine,EndLine,RetBytes) Then Begin
   { Pattern detecte! Creer une entree TProcInfo }
   If ProcCount>=MAX_PROCS Then Continue;
   Inc(ProcCount);
   
   Procs[ProcCount].Name:=LabelName;
   Procs[ProcCount].IsFunction:=True;  { Assume fonction par defaut }
   Procs[ProcCount].IsNear:=True;
   Procs[ProcCount].Convention:=CC_PASCAL; { Convention Pascal par defaut (appele nettoie) }
   Procs[ProcCount].StartLine:=LabelLine;
   Procs[ProcCount].EndLine:=EndLine;
   Procs[ProcCount].UsesAX:=True; { Assume que la fonction retourne dans AX }
   Procs[ProcCount].IsPublic:=False;
   Procs[ProcCount].StringsReplacement:='';
   Procs[ProcCount].LocalCount:=0;
   Procs[ProcCount].LocalSize:=0;
   
   { Calculer le nombre de parametres a partir de RET n }
   { Pour convention PASCAL/STDCALL, RET n nettoie n octets de la pile }
   { Chaque parametre Word = 2 octets, donc n/2 parametres }
   If RetBytes>0 Then Begin
    ParamBytes:=RetBytes;
    If Mode32 Then
     ParamCount:=ParamBytes div 4 { Parametres 32 bits }
    Else
     ParamCount:=ParamBytes div 2; { Parametres 16 bits }
    If ParamCount>MAX_PARAMS Then ParamCount:=MAX_PARAMS;
   End
   Else
    ParamCount:=0;
   
   Procs[ProcCount].ParamCount:=ParamCount;
   
   { Creer des noms de parametres generiques }
   For J:=1 to ParamCount do Begin
    Procs[ProcCount].Params[J].Name:='Param'+IntToStr(J);
    If Mode32 Then Begin
     Procs[ProcCount].Params[J].TypeName:='DWORD';
     Procs[ProcCount].Params[J].PascalType:=PT_LONGINT;
     Procs[ProcCount].Params[J].Size:=4;
    End
    Else Begin
     Procs[ProcCount].Params[J].TypeName:='WORD';
     Procs[ProcCount].Params[J].PascalType:=PT_WORD;
     Procs[ProcCount].Params[J].Size:=2;
    End;
   End;
   
   { Detecter si c'est vraiment une fonction (utilise AX avant RET) }
   DetectFunctionReturn(ProcCount);
   
   Inc(ImplicitCount);
  End;
 End;
 
 { Afficher les resultats }
 WriteLn('Detection fonctions implicites : ',ImplicitCount,' fonction(s) detectee(s).');
 If Verbose and(ImplicitCount>0)Then Begin
  WriteLn('  Details :');
  For I:=ProcCount-ImplicitCount+1 to ProcCount do Begin
   Write('    ',Procs[I].Name);
   If Procs[I].IsFunction or Procs[I].UsesAX Then Write(' (fonction)')
   Else Write(' (procedure)');
   Write(' params:',Procs[I].ParamCount);
   WriteLn(' [',Procs[I].StartLine,'..',Procs[I].EndLine,']');
  End;
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
   If(DV.ElemCount=2)and
     (DV.Elements[1].ElemType=DE_NUMBER)and
     (DV.Elements[2].ElemType=DE_STRING)and
     (DV.Elements[1].NumValue=Length(DV.Elements[2].StrValue))Then Begin
    { Chaine Pascal courte : DB longueur,'texte' }
    DataVars[I].PascalType:=PT_STRING;
    If FindSymbol(DV.Name)>0 Then
     Symbols[FindSymbol(DV.Name)].DataType:=PT_STRING;
   End
   Else If(DV.ElemCount=1)and(DV.Elements[1].ElemType=DE_STRING)Then Begin
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

{ ============================================================
  Traduction des registres en variables Pascal - TODO 9
  ============================================================ }

Function RegToPascalVar(Reg:String):String;
{ Mapper un registre CPU vers un nom de variable Pascal.
  Gere les registres 8/16/32 bits et segments. }
Var
 U:String;
Begin
 U:=UpCaseStr(Reg);
 { Registres 32 bits }
 If U='EAX' Then RegToPascalVar:='RegEAX'
 Else If U='EBX' Then RegToPascalVar:='RegEBX'
 Else If U='ECX' Then RegToPascalVar:='RegECX'
 Else If U='EDX' Then RegToPascalVar:='RegEDX'
 Else If U='ESI' Then RegToPascalVar:='RegESI'
 Else If U='EDI' Then RegToPascalVar:='RegEDI'
 Else If U='EBP' Then RegToPascalVar:='RegEBP'
 Else If U='ESP' Then RegToPascalVar:='RegESP'
 { Registres 16 bits }
 Else If U='AX' Then RegToPascalVar:='RegAX'
 Else If U='BX' Then RegToPascalVar:='RegBX'
 Else If U='CX' Then RegToPascalVar:='RegCX'
 Else If U='DX' Then RegToPascalVar:='RegDX'
 Else If U='SI' Then RegToPascalVar:='RegSI'
 Else If U='DI' Then RegToPascalVar:='RegDI'
 Else If U='BP' Then RegToPascalVar:='RegBP'
 Else If U='SP' Then RegToPascalVar:='RegSP'
 { Registres 8 bits - variable du registre parent }
 Else If U='AL' Then RegToPascalVar:='RegAX'
 Else If U='AH' Then RegToPascalVar:='RegAX'
 Else If U='BL' Then RegToPascalVar:='RegBX'
 Else If U='BH' Then RegToPascalVar:='RegBX'
 Else If U='CL' Then RegToPascalVar:='RegCX'
 Else If U='CH' Then RegToPascalVar:='RegCX'
 Else If U='DL' Then RegToPascalVar:='RegDX'
 Else If U='DH' Then RegToPascalVar:='RegDX'
 { Registres de segment }
 Else If U='CS' Then RegToPascalVar:='RegCS'
 Else If U='DS' Then RegToPascalVar:='RegDS'
 Else If U='ES' Then RegToPascalVar:='RegES'
 Else If U='SS' Then RegToPascalVar:='RegSS'
 Else If U='FS' Then RegToPascalVar:='RegFS'
 Else If U='GS' Then RegToPascalVar:='RegGS'
 Else RegToPascalVar:='Reg_'+U;
End;

Function RegToPascalType(Reg:String):Byte;
{ Retourne le type Pascal correspondant a un registre }
Var
 U:String;
Begin
 U:=UpCaseStr(Reg);
 If IsReg8(U) Then RegToPascalType:=PT_BYTE
 Else If IsReg16(U) Then RegToPascalType:=PT_WORD
 Else If IsReg32(U) Then RegToPascalType:=PT_LONGINT
 Else If IsSegReg(U) Then RegToPascalType:=PT_WORD
 Else RegToPascalType:=PT_WORD;
End;

Function SubRegExpr(Reg:String):String;
{ Genere l'expression Pascal pour acceder a un sous-registre.
  AL = Lo(RegAX), AH = Hi(RegAX).
  En mode 32 bits, AX = Word(RegEAX). }
Var
 U:String;
Begin
 U:=UpCaseStr(Reg);
 { Sous-registres 8 bits bas (Lo) }
 If U='AL' Then SubRegExpr:='Lo(RegAX)'
 Else If U='BL' Then SubRegExpr:='Lo(RegBX)'
 Else If U='CL' Then SubRegExpr:='Lo(RegCX)'
 Else If U='DL' Then SubRegExpr:='Lo(RegDX)'
 { Sous-registres 8 bits haut (Hi) }
 Else If U='AH' Then SubRegExpr:='Hi(RegAX)'
 Else If U='BH' Then SubRegExpr:='Hi(RegBX)'
 Else If U='CH' Then SubRegExpr:='Hi(RegCX)'
 Else If U='DH' Then SubRegExpr:='Hi(RegDX)'
 { En mode 32 bits, les registres 16 bits sont des sous-registres }
 Else If Mode32 and(U='AX')Then SubRegExpr:='Word(RegEAX)'
 Else If Mode32 and(U='BX')Then SubRegExpr:='Word(RegEBX)'
 Else If Mode32 and(U='CX')Then SubRegExpr:='Word(RegECX)'
 Else If Mode32 and(U='DX')Then SubRegExpr:='Word(RegEDX)'
 Else If Mode32 and(U='SI')Then SubRegExpr:='Word(RegESI)'
 Else If Mode32 and(U='DI')Then SubRegExpr:='Word(RegEDI)'
 Else If Mode32 and(U='BP')Then SubRegExpr:='Word(RegEBP)'
 Else If Mode32 and(U='SP')Then SubRegExpr:='Word(RegESP)'
 { Registres complets : pas de sous-expression }
 Else SubRegExpr:=RegToPascalVar(U);
End;

Function IsSubReg(Reg:String):Boolean;
{ Determine si un registre est un sous-registre }
Var
 U:String;
Begin
 U:=UpCaseStr(Reg);
 IsSubReg:=IsReg8(U)or
  (Mode32 and IsReg16(U));
End;

Function FlagToPascalVar(Flag:String):String;
{ Mapper un flag du registre FLAGS vers un booleen Pascal }
Var
 U:String;
Begin
 U:=UpCaseStr(Flag);
 If U='CF' Then FlagToPascalVar:='FlagCF'
 Else If U='ZF' Then FlagToPascalVar:='FlagZF'
 Else If U='SF' Then FlagToPascalVar:='FlagSF'
 Else If U='OF' Then FlagToPascalVar:='FlagOF'
 Else If U='DF' Then FlagToPascalVar:='FlagDF'
 Else If U='PF' Then FlagToPascalVar:='FlagPF'
 Else If U='AF' Then FlagToPascalVar:='FlagAF'
 Else If U='IF' Then FlagToPascalVar:='FlagIF'
 Else If U='TF' Then FlagToPascalVar:='FlagTF'
 Else FlagToPascalVar:='Flag_'+U;
End;

Function MnemonicAffectsFlags(M:String):Boolean;
{ Verifie si un mnemonique modifie les flags }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 MnemonicAffectsFlags:=
  (U='ADD')or(U='SUB')or(U='CMP')or(U='AND')or(U='OR')or
  (U='XOR')or(U='TEST')or(U='NEG')or(U='NOT')or
  (U='INC')or(U='DEC')or(U='ADC')or(U='SBB')or
  (U='MUL')or(U='IMUL')or(U='DIV')or(U='IDIV')or
  (U='SHL')or(U='SHR')or(U='SAL')or(U='SAR')or
  (U='ROL')or(U='ROR')or(U='RCL')or(U='RCR')or
  (U='BT')or(U='BTS')or(U='BTR')or(U='BTC')or
  (U='BSF')or(U='BSR')or
  (U='STC')or(U='CLC')or(U='CMC')or(U='STD')or(U='CLD')or
  (U='STI')or(U='CLI')or
  (U='SAHF')or(U='LAHF')or
  (U='SCASB')or(U='SCASW')or(U='SCASD')or
  (U='CMPSB')or(U='CMPSW')or(U='CMPSD');
End;

Function MnemonicUsesFlags(M:String):Boolean;
{ Verifie si un mnemonique lit les flags }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 MnemonicUsesFlags:=
  (U='JC')or(U='JNC')or(U='JZ')or(U='JNZ')or(U='JE')or(U='JNE')or
  (U='JS')or(U='JNS')or(U='JO')or(U='JNO')or(U='JP')or(U='JNP')or
  (U='JA')or(U='JAE')or(U='JB')or(U='JBE')or
  (U='JG')or(U='JGE')or(U='JL')or(U='JLE')or
  (U='JNA')or(U='JNAE')or(U='JNB')or(U='JNBE')or
  (U='JNG')or(U='JNGE')or(U='JNL')or(U='JNLE')or
  (U='LOOPE')or(U='LOOPNE')or(U='LOOPZ')or(U='LOOPNZ')or
  (U='ADC')or(U='SBB')or(U='RCL')or(U='RCR')or
  (U='CMC')or(U='LAHF')or(U='PUSHF')or(U='PUSHFD')or
  (U='SETA')or(U='SETAE')or(U='SETB')or(U='SETBE')or
  (U='SETE')or(U='SETNE')or(U='SETG')or(U='SETGE')or
  (U='SETL')or(U='SETLE')or(U='SETS')or(U='SETNS')or
  (U='SETO')or(U='SETNO')or(U='SETP')or(U='SETNP')or
  (U='SETC')or(U='SETNC')or(U='SETZ')or(U='SETNZ')or
  (U='CMOVA')or(U='CMOVAE')or(U='CMOVB')or(U='CMOVBE')or
  (U='CMOVE')or(U='CMOVNE')or(U='CMOVG')or(U='CMOVGE')or
  (U='CMOVL')or(U='CMOVLE')or(U='CMOVS')or(U='CMOVNS')or
  (U='CMOVO')or(U='CMOVNO');
End;

Function StackAccessExpr(BaseReg:String;Offset:LongInt;
 ProcIdx:Integer):String;
{ Traduit un acces [BP+offset] ou [EBP+offset] en reference
  aux parametres ou variables locales de la procedure.
  Offset positif = parametre, offset negatif = variable locale. }
Var
 J:Integer;
 U:String;
 ParamOffset:Integer;
Begin
 U:=UpCaseStr(BaseReg);
 If(U<>'BP')and(U<>'EBP')Then Begin
  StackAccessExpr:='['+BaseReg+'+'+IntToStr(Offset)+']';
  Exit;
 End;
 If(ProcIdx>=1)and(ProcIdx<=ProcCount)Then Begin
  { Chercher dans les parametres (offset positif) }
  If Offset>0 Then Begin
   { Calculer quel parametre correspond a cet offset }
   { Convention NEAR : BP+0 = saved BP, BP+2 = retour, BP+4 = param1, BP+6 = param2 }
   { Convention FAR :  BP+0 = saved BP, BP+2 = retour off, BP+4 = retour seg, BP+6 = param1 }
   If Procs[ProcIdx].IsNear Then
    ParamOffset:=4
   Else
    ParamOffset:=6;
   
   For J:=1 to Procs[ProcIdx].ParamCount do Begin
    If Procs[ProcIdx].Params[J].Size>0 Then Begin
     { Verifier si l'offset correspond a ce parametre }
     If Offset=ParamOffset Then Begin
      StackAccessExpr:=Procs[ProcIdx].Params[J].Name;
      Exit;
     End;
     ParamOffset:=ParamOffset+Procs[ProcIdx].Params[J].Size;
    End;
   End;
  End;
  { Chercher dans les variables locales (offset negatif) }
  If Offset<0 Then Begin
   For J:=1 to Procs[ProcIdx].LocalCount do Begin
    If Procs[ProcIdx].Locals[J].Size>0 Then Begin
     StackAccessExpr:=Procs[ProcIdx].Locals[J].Name;
     Exit;
    End;
   End;
  End;
 End;
 { Pas trouve : generer une expression generique }
 If Offset>=0 Then
  StackAccessExpr:='Param_BP_'+IntToStr(Offset)
 Else
  StackAccessExpr:='Local_BP_'+IntToStr(-Offset);
End;

Function FindIndexedLocalByOffset(ProcIdx:Integer;BaseReg,IndexReg:String;
 Offset:LongInt):Integer;
{ Cherche une variable locale indexee par son offset et ses registres.
  Retourne l'index dans Procs[ProcIdx].Locals[] ou 0 si non trouve. }
Var
 J:Integer;
 UBase,UIndex:String;
Begin
 FindIndexedLocalByOffset:=0;
 If(ProcIdx<1)or(ProcIdx>ProcCount)Then Exit;
 UBase:=UpCaseStr(BaseReg);
 UIndex:=UpCaseStr(IndexReg);
 For J:=1 to Procs[ProcIdx].LocalCount do Begin
  With Procs[ProcIdx].Locals[J] do Begin
   If IsIndexedMem and (IndexOffset=Offset) and
      (UpCaseStr(IndexBaseReg)=UBase) and
      (UpCaseStr(IndexIndexReg)=UIndex) Then Begin
    FindIndexedLocalByOffset:=J;
    Exit;
   End;
  End;
 End;
End;

Const
 MAX_REGUSAGE = 30;

Type
 TRegUsage = Record
  RegName:String;
  ReadCount:LongInt;
  WriteCount:LongInt;
  IsTemp:Boolean;
  TempName:String;
 End;

Var
 RegUsages:Array[1..MAX_REGUSAGE] of TRegUsage;
 RegUsageCount:Integer;
 NeedFlags:Boolean;

Function FindRegUsage(Reg:String):Integer;
{ Trouve l'index d'un registre dans la table d'usage }
Var
 I:Integer;
 U:String;
Begin
 U:=UpCaseStr(Reg);
 FindRegUsage:=0;
 For I:=1 to RegUsageCount do
  If UpCaseStr(RegUsages[I].RegName)=U Then Begin
   FindRegUsage:=I;
   Exit;
  End;
End;

Procedure AddRegUsage(Reg:String;IsWrite:Boolean);
{ Ajoute ou met a jour l'usage d'un registre }
Var
 Idx:Integer;
 U:String;
Begin
 U:=UpCaseStr(Reg);
 If(U='')or(U='FLAGS')Then Exit;
 Idx:=FindRegUsage(U);
 If Idx=0 Then Begin
  If RegUsageCount>=MAX_REGUSAGE Then Exit;
  Inc(RegUsageCount);
  Idx:=RegUsageCount;
  RegUsages[Idx].RegName:=U;
  RegUsages[Idx].ReadCount:=0;
  RegUsages[Idx].WriteCount:=0;
  RegUsages[Idx].IsTemp:=False;
  RegUsages[Idx].TempName:='';
 End;
 If IsWrite Then Inc(RegUsages[Idx].WriteCount)
 Else Inc(RegUsages[Idx].ReadCount);
End;

Procedure AnalyzeRegisterUsage(Var AsmL:TAsmLine);
{ Analyse une instruction pour determiner les registres lus/ecrits }
Var
 U:String;
Begin
 U:=AsmL.Mnemonic;
 { Mnemoniques qui ecrivent dans op1 et lisent op2 }
 If(U='MOV')or(U='MOVZX')or(U='MOVSX')or(U='LEA')or
   (U='LDS')or(U='LES')or(U='LFS')or(U='LGS')Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op1.Reg,True);
  If AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op2.Reg,False);
 End
 { Mnemoniques qui lisent et ecrivent op1 }
 Else If(U='ADD')or(U='SUB')or(U='ADC')or(U='SBB')or
   (U='AND')or(U='OR')or(U='XOR')or(U='INC')or(U='DEC')or
   (U='NEG')or(U='NOT')or(U='SHL')or(U='SHR')or(U='SAL')or
   (U='SAR')or(U='ROL')or(U='ROR')or(U='RCL')or(U='RCR')Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
   AddRegUsage(AsmL.Op1.Reg,True);
   AddRegUsage(AsmL.Op1.Reg,False);
  End;
  If AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op2.Reg,False);
 End
 { CMP/TEST lisent les deux operandes }
 Else If(U='CMP')or(U='TEST')Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op1.Reg,False);
  If AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op2.Reg,False);
 End
 { PUSH lit le registre }
 Else If U='PUSH' Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32,OT_SEGREG] Then
   AddRegUsage(AsmL.Op1.Reg,False);
 End
 { POP ecrit dans le registre }
 Else If U='POP' Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32,OT_SEGREG] Then
   AddRegUsage(AsmL.Op1.Reg,True);
 End
 { XCHG lit et ecrit les deux }
 Else If U='XCHG' Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
   AddRegUsage(AsmL.Op1.Reg,True);
   AddRegUsage(AsmL.Op1.Reg,False);
  End;
  If AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
   AddRegUsage(AsmL.Op2.Reg,True);
   AddRegUsage(AsmL.Op2.Reg,False);
  End;
 End
 { MUL/IMUL implicitement ecrit dans AX/DX:AX ou EAX/EDX:EAX }
 Else If(U='MUL')or(U='IMUL')Then Begin
  If Mode32 Then Begin
   AddRegUsage('EAX',True);
   AddRegUsage('EDX',True);
  End Else Begin
   AddRegUsage('AX',True);
   AddRegUsage('DX',True);
  End;
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op1.Reg,False);
 End
 { DIV/IDIV implicitement lit et ecrit AX/DX }
 Else If(U='DIV')or(U='IDIV')Then Begin
  If Mode32 Then Begin
   AddRegUsage('EAX',True);
   AddRegUsage('EAX',False);
   AddRegUsage('EDX',True);
   AddRegUsage('EDX',False);
  End Else Begin
   AddRegUsage('AX',True);
   AddRegUsage('AX',False);
   AddRegUsage('DX',True);
   AddRegUsage('DX',False);
  End;
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op1.Reg,False);
 End
 { CBW/CWD/CWDE/CDQ : extensions de signe implicites }
 Else If U='CBW' Then Begin
  AddRegUsage('AX',True);AddRegUsage('AL',False);
 End
 Else If U='CWD' Then Begin
  AddRegUsage('DX',True);AddRegUsage('AX',False);
 End
 Else If U='CWDE' Then Begin
  AddRegUsage('EAX',True);AddRegUsage('AX',False);
 End
 Else If U='CDQ' Then Begin
  AddRegUsage('EDX',True);AddRegUsage('EAX',False);
 End
 { Instructions de chaine : utilisent SI/DI/CX implicitement }
 Else If(U='MOVSB')or(U='MOVSW')or(U='MOVSD')or
   (U='CMPSB')or(U='CMPSW')or(U='CMPSD')or
   (U='LODSB')or(U='LODSW')or(U='LODSD')or
   (U='STOSB')or(U='STOSW')or(U='STOSD')or
   (U='SCASB')or(U='SCASW')or(U='SCASD')Then Begin
  If Mode32 Then Begin
   AddRegUsage('ESI',False);AddRegUsage('EDI',False);
   AddRegUsage('ESI',True);AddRegUsage('EDI',True);
  End Else Begin
   AddRegUsage('SI',False);AddRegUsage('DI',False);
   AddRegUsage('SI',True);AddRegUsage('DI',True);
  End;
  If(U='LODSB')or(U='LODSW')or(U='LODSD')Then Begin
   If Mode32 Then AddRegUsage('EAX',True)
   Else AddRegUsage('AX',True);
  End;
  If(U='STOSB')or(U='STOSW')or(U='STOSD')Then Begin
   If Mode32 Then AddRegUsage('EAX',False)
   Else AddRegUsage('AX',False);
  End;
 End
 { Autres instructions avec operandes registres }
 Else Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op1.Reg,False);
  If AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
   AddRegUsage(AsmL.Op2.Reg,False);
 End;
 { Verifier si les flags sont necessaires }
 If MnemonicAffectsFlags(U) or MnemonicUsesFlags(U) Then
  NeedFlags:=True;
End;

Procedure DetectTempRegisters;
{ Detecte les registres utilises comme variables temporaires.
  Un registre est considere temporaire s'il est ecrit puis lu
  dans un contexte limite (pas un registre de travail global). }
Var
 I:Integer;
 TempIdx:Integer;
 U:String;
Begin
 TempIdx:=0;
 For I:=1 to RegUsageCount do Begin
  U:=UpCaseStr(RegUsages[I].RegName);
  { Ignorer les registres speciaux pile/base }
  If(U='SP')or(U='ESP')or(U='BP')or(U='EBP')Then Continue;
  { Ignorer les registres de segment }
  If IsSegReg(U) Then Continue;
  { Un registre utilise peu de fois, surtout en ecriture, est un temporaire }
  If(RegUsages[I].WriteCount>=1)and(RegUsages[I].WriteCount<=3)and
    (RegUsages[I].ReadCount>=1)and(RegUsages[I].ReadCount<=5)Then Begin
   { Les registres principaux AX/EAX ne sont pas temporaires
     sauf si le code est tres court }
   If(U='AX')or(U='EAX')Then Continue;
   Inc(TempIdx);
   RegUsages[I].IsTemp:=True;
   RegUsages[I].TempName:='Tmp'+Chr(Ord('A')+TempIdx-1);
   If TempIdx>26 Then
    RegUsages[I].TempName:='Tmp'+IntToStr(TempIdx);
  End;
 End;
End;

Procedure ProcessRegisterMapping;
{ Orchestrateur : analyse les registres et cree le mapping vers Pascal }
Var
 I:LongInt;
 AsmL:TAsmLine;
 InstrCount:LongInt;
 Reg16Used,Reg32Used:LongInt;
 Reg8Used,SegUsed:LongInt;
 TempCount:LongInt;
Begin
 RegUsageCount:=0;
 NeedFlags:=False;
 InstrCount:=0;
 { Scanner toutes les instructions }
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
    AnalyzeRegisterUsage(AsmL);
   End;
  End;
 End;
 { Detecter les registres temporaires }
 DetectTempRegisters;
 { Compter les categories }
 Reg8Used:=0;Reg16Used:=0;Reg32Used:=0;SegUsed:=0;TempCount:=0;
 For I:=1 to RegUsageCount do Begin
  If IsReg8(RegUsages[I].RegName) Then Inc(Reg8Used)
  Else If IsReg16(RegUsages[I].RegName) Then Inc(Reg16Used)
  Else If IsReg32(RegUsages[I].RegName) Then Inc(Reg32Used)
  Else If IsSegReg(RegUsages[I].RegName) Then Inc(SegUsed);
  If RegUsages[I].IsTemp Then Inc(TempCount);
 End;
 WriteLn('Mapping registres : ',RegUsageCount,' registres, ',
  InstrCount,' instructions.');
 If Verbose Then Begin
  WriteLn('  Registres 8 bits  : ',Reg8Used);
  WriteLn('  Registres 16 bits : ',Reg16Used);
  WriteLn('  Registres 32 bits : ',Reg32Used);
  WriteLn('  Registres segment : ',SegUsed);
  WriteLn('  Temporaires       : ',TempCount);
  If NeedFlags Then WriteLn('  Flags necessaires : oui')
  Else WriteLn('  Flags necessaires : non');
  { Details de chaque registre }
  For I:=1 to RegUsageCount do Begin
   Write('    ',RegUsages[I].RegName,' -> ',
    RegToPascalVar(RegUsages[I].RegName),':',
    PascalTypeName(RegToPascalType(RegUsages[I].RegName)));
   If IsSubReg(RegUsages[I].RegName) Then
    Write(' [',SubRegExpr(RegUsages[I].RegName),']');
   If RegUsages[I].IsTemp Then
    Write(' (temp: ',RegUsages[I].TempName,')');
   Write(' R=',RegUsages[I].ReadCount,' W=',RegUsages[I].WriteCount);
   WriteLn;
  End;
 End;
End;

{ ============================================================
  Traduction des instructions de transfert de donnees - TODO 10
  ============================================================ }

Const
 MAX_TRANSLATIONS = 32768;

Type
 TTranslation = Record
  SrcLine:LongInt;
  PascalCode:String;
  AsmComment:String;
  IsTranslated:Boolean;
 End;

Var
 Translations:Array[0..MAX_TRANSLATIONS-1] of TTranslation;
 TranslationCount:LongInt;

Procedure AddTranslation(Line:LongInt;Code,AsmCmt:String);
Begin
 If TranslationCount>=MAX_TRANSLATIONS Then Exit;
 Translations[TranslationCount].SrcLine:=Line;
 Translations[TranslationCount].PascalCode:=Code;
 Translations[TranslationCount].AsmComment:=AsmCmt;
 Translations[TranslationCount].IsTranslated:=True;
 Inc(TranslationCount);
End;

Function FindProcForLine(Line:LongInt):Integer;
{ Trouve l'index de procedure contenant une ligne donnee }
Var
 I:Integer;
Begin
 FindProcForLine:=0;
 For I:=1 to ProcCount do
  If(Line>=Procs[I].StartLine)and(Line<=Procs[I].EndLine)Then Begin
   FindProcForLine:=I;
   Exit;
  End;
End;

Function OperandToExpr(Var Op:TOperand;ProcIdx:Integer):String;
{ Convertit un TOperand en expression Pascal lisible.
  Gere les registres (avec sous-registres), la memoire,
  les immediats, les labels, OFFSET et SEG. }
Var
 U,Expr:String;
 SymIdx,LocalIdx:Integer;
Begin
 Case Op.OpType of
  OT_REG8,OT_REG16,OT_REG32:Begin
   U:=UpCaseStr(Op.Reg);
   If IsSubReg(U) Then
    OperandToExpr:=SubRegExpr(U)
   Else
    OperandToExpr:=RegToPascalVar(U);
  End;
  OT_SEGREG:
   OperandToExpr:=RegToPascalVar(Op.Reg);
  OT_MEM:Begin
   { Acces memoire : verifier si c'est un acces pile [BP+x] }
   U:=UpCaseStr(Op.BaseReg);
   If((U='BP')or(U='EBP'))and(Op.IndexReg='')Then
    OperandToExpr:=StackAccessExpr(U,Op.Disp,ProcIdx)
   Else If(Op.BaseReg<>'')and(Op.IndexReg<>'')Then Begin
    { Adressage base+index - chercher d'abord une variable locale }
    If Op.HasDisp Then
     LocalIdx:=FindIndexedLocalByOffset(ProcIdx,Op.BaseReg,Op.IndexReg,Op.Disp)
    Else
     LocalIdx:=FindIndexedLocalByOffset(ProcIdx,Op.BaseReg,Op.IndexReg,0);
    If LocalIdx>0 Then Begin
     { Variable locale trouvee - utiliser son nom }
     OperandToExpr:=Procs[ProcIdx].Locals[LocalIdx].Name;
    End
    Else Begin
     { Pas de variable locale - generer Mem[...] }
     Expr:=RegToPascalVar(Op.BaseReg)+'+'+RegToPascalVar(Op.IndexReg);
     If Op.Scale>1 Then
      Expr:=RegToPascalVar(Op.BaseReg)+'+'+
       RegToPascalVar(Op.IndexReg)+'*'+IntToStr(Op.Scale);
     If Op.HasDisp Then Begin
      If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
      Else Expr:=Expr+IntToStr(Op.Disp);
     End;
     OperandToExpr:='Mem['+Expr+']';
    End;
   End
   Else If Op.MemExpr<>'' Then Begin
    { Verifier si l'expression memoire est un symbole connu }
    SymIdx:=FindSymbol(Op.MemExpr);
    If SymIdx>0 Then
     OperandToExpr:=Symbols[SymIdx].Name
    Else
     OperandToExpr:='Mem['+Op.MemExpr+']';
   End
   Else If Op.BaseReg<>'' Then Begin
    Expr:=RegToPascalVar(Op.BaseReg);
    If Op.HasDisp Then Begin
     If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
     Else Expr:=Expr+IntToStr(Op.Disp);
    End;
    OperandToExpr:='Mem['+Expr+']';
   End
   Else If Op.HasDisp Then
    OperandToExpr:='Mem['+IntToStr(Op.Disp)+']'
   Else
    OperandToExpr:='Mem[0]';
  End;
  OT_IMM8:
   If(Op.Imm>=32)and(Op.Imm<=126)Then
    OperandToExpr:=IntToStr(Op.Imm)
   Else
    OperandToExpr:='$'+HexByte(Op.Imm);
  OT_IMM16:
   OperandToExpr:='$'+HexWord(Op.Imm);
  OT_IMM32:
   OperandToExpr:='$'+HexDWord(Op.Imm);
  OT_LABEL:Begin
   SymIdx:=FindSymbol(Op.LabelName);
   If SymIdx>0 Then
    OperandToExpr:=Symbols[SymIdx].Name
   Else
    OperandToExpr:=Op.LabelName;
  End;
  OT_OFFSET:Begin
   SymIdx:=FindSymbol(Op.LabelName);
   If SymIdx>0 Then
    OperandToExpr:='@'+Symbols[SymIdx].Name
   Else
    OperandToExpr:='@'+Op.LabelName;
  End;
  OT_SEG:Begin
   SymIdx:=FindSymbol(Op.LabelName);
   If SymIdx>0 Then
    OperandToExpr:='Seg('+Symbols[SymIdx].Name+')'
   Else
    OperandToExpr:='Seg('+Op.LabelName+')';
  End;
  OT_FAR:
   OperandToExpr:=HexWord(Word(Op.Imm))+'h:'+HexWord(Word(Op.Disp))+'h';
  Else
   OperandToExpr:='?';
 End;
End;

Function TranslateMOV(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ MOV dest,src -> dest := src
  Gere les cas speciaux : registres 8 bits, segments, memoire }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateMOV:=D+' := '+S+';';
End;

Function TranslateXCHG(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ XCHG a,b -> Begin TmpXchg:=a; a:=b; b:=TmpXchg End }
Var
 A,B:String;
Begin
 A:=OperandToExpr(AsmL.Op1,ProcIdx);
 B:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateXCHG:='Begin TmpXchg := '+A+'; '+A+' := '+B+'; '+
  B+' := TmpXchg; End;';
End;

Function TranslateLEA(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ LEA reg,[expr] -> reg := @expr ou reg := Addr(expr) }
Var
 D,S:String;
 SymIdx:Integer;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 { Pour LEA, l'operande source est une adresse, pas le contenu }
 If AsmL.Op2.MemExpr<>'' Then Begin
  SymIdx:=FindSymbol(AsmL.Op2.MemExpr);
  If SymIdx>0 Then
   S:='@'+Symbols[SymIdx].Name
  Else
   S:='@'+AsmL.Op2.MemExpr;
 End
 Else If(AsmL.Op2.BaseReg<>'')and(AsmL.Op2.IndexReg<>'')Then Begin
  S:=RegToPascalVar(AsmL.Op2.BaseReg)+'+'+
   RegToPascalVar(AsmL.Op2.IndexReg);
  If AsmL.Op2.Scale>1 Then
   S:=RegToPascalVar(AsmL.Op2.BaseReg)+'+'+
    RegToPascalVar(AsmL.Op2.IndexReg)+'*'+IntToStr(AsmL.Op2.Scale);
  If AsmL.Op2.HasDisp Then Begin
   If AsmL.Op2.Disp>=0 Then S:=S+'+'+IntToStr(AsmL.Op2.Disp)
   Else S:=S+IntToStr(AsmL.Op2.Disp);
  End;
 End
 Else If AsmL.Op2.BaseReg<>'' Then Begin
  S:=RegToPascalVar(AsmL.Op2.BaseReg);
  If AsmL.Op2.HasDisp Then Begin
   If AsmL.Op2.Disp>=0 Then S:=S+'+'+IntToStr(AsmL.Op2.Disp)
   Else S:=S+IntToStr(AsmL.Op2.Disp);
  End;
 End
 Else
  S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateLEA:=D+' := '+S+';';
End;

Function TranslateLDx(Var AsmL:TAsmLine;ProcIdx:Integer;
 SegName:String):String;
{ LDS/LES/LFS/LGS reg,[mem] ->
  RegXS := Seg(mem); reg := Ofs(mem)
  ou en une ligne : chargement du pointeur far }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op2.MemExpr<>'' Then
  S:=AsmL.Op2.MemExpr
 Else
  S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateLDx:='Reg'+SegName+' := MemW[Seg('+S+')]; '+
  D+' := Ofs('+S+');';
End;

Function TranslateMOVZX(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ MOVZX dest,src -> dest := Word(Byte(src)) ou LongInt(Word(src))
  Extension zero (non signee) }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 { Determiner le type de cast selon les tailles }
 If AsmL.Op2.OpType=OT_REG8 Then Begin
  If AsmL.Op1.OpType=OT_REG32 Then
   TranslateMOVZX:=D+' := LongInt(Byte('+S+'));'
  Else
   TranslateMOVZX:=D+' := Word(Byte('+S+'));';
 End
 Else If(AsmL.Op2.OpType=OT_REG16)or(AsmL.Op2.OpType=OT_MEM)Then
  TranslateMOVZX:=D+' := LongInt(Word('+S+'));'
 Else
  TranslateMOVZX:=D+' := '+S+';';
End;

Function TranslateMOVSX(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ MOVSX dest,src -> dest := Integer(ShortInt(src)) ou
  LongInt(Integer(src)) - Extension de signe }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 If AsmL.Op2.OpType=OT_REG8 Then Begin
  If AsmL.Op1.OpType=OT_REG32 Then
   TranslateMOVSX:=D+' := LongInt(ShortInt('+S+'));'
  Else
   TranslateMOVSX:=D+' := Integer(ShortInt('+S+'));';
 End
 Else If(AsmL.Op2.OpType=OT_REG16)or(AsmL.Op2.OpType=OT_MEM)Then
  TranslateMOVSX:=D+' := LongInt(Integer('+S+'));'
 Else
  TranslateMOVSX:=D+' := '+S+';';
End;

Function TranslateCBW_CWD(Mnem:String):String;
{ CBW -> RegAX := Integer(ShortInt(Lo(RegAX)));
  CWD -> Begin RegDX := Hi(RegAX) shr 7 * $FFFF; End;
       = paire DX:AX := LongInt(Integer(RegAX))
  CWDE -> RegEAX := LongInt(Integer(Word(RegEAX)));
  CDQ  -> RegEDX := LongInt(RegEAX) shr 31 * $FFFFFFFF;
       = paire EDX:EAX := extension de signe de EAX }
Var
 U:String;
Begin
 U:=UpCaseStr(Mnem);
 If U='CBW' Then
  TranslateCBW_CWD:='RegAX := Integer(ShortInt(Lo(RegAX)));'
 Else If U='CWD' Then
  TranslateCBW_CWD:=
   'LongRec(LongInt(Integer(RegAX))).Lo := RegAX; '+
   'RegDX := LongRec(LongInt(Integer(RegAX))).Hi;'
 Else If U='CWDE' Then
  TranslateCBW_CWD:='RegEAX := LongInt(Integer(Word(RegEAX)));'
 Else If U='CDQ' Then
  TranslateCBW_CWD:=
   'If RegEAX and $80000000 <> 0 Then RegEDX := LongInt(-1) '+
   'Else RegEDX := 0;'
 Else
  TranslateCBW_CWD:='{ '+U+' }';
End;

Function TranslateDataTransfer(Var AsmL:TAsmLine;
 ProcIdx:Integer):String;
{ Orchestre la traduction d'une instruction de transfert.
  Retourne la chaine Pascal correspondante, ou '' si non gere. }
Var
 M:String;
Begin
 M:=AsmL.Mnemonic;
 If M='MOV' Then
  TranslateDataTransfer:=TranslateMOV(AsmL,ProcIdx)
 Else If M='XCHG' Then
  TranslateDataTransfer:=TranslateXCHG(AsmL,ProcIdx)
 Else If M='LEA' Then
  TranslateDataTransfer:=TranslateLEA(AsmL,ProcIdx)
 Else If M='LDS' Then
  TranslateDataTransfer:=TranslateLDx(AsmL,ProcIdx,'DS')
 Else If M='LES' Then
  TranslateDataTransfer:=TranslateLDx(AsmL,ProcIdx,'ES')
 Else If M='LFS' Then
  TranslateDataTransfer:=TranslateLDx(AsmL,ProcIdx,'FS')
 Else If M='LGS' Then
  TranslateDataTransfer:=TranslateLDx(AsmL,ProcIdx,'GS')
 Else If M='MOVZX' Then
  TranslateDataTransfer:=TranslateMOVZX(AsmL,ProcIdx)
 Else If M='MOVSX' Then
  TranslateDataTransfer:=TranslateMOVSX(AsmL,ProcIdx)
 Else If(M='CBW')or(M='CWD')or(M='CWDE')or(M='CDQ')Then
  TranslateDataTransfer:=TranslateCBW_CWD(M)
 Else
  TranslateDataTransfer:='';
End;

Function IsDataTransferMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une instruction de transfert }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsDataTransferMnemonic:=
  (U='MOV')or(U='XCHG')or(U='LEA')or
  (U='LDS')or(U='LES')or(U='LFS')or(U='LGS')or
  (U='MOVZX')or(U='MOVSX')or
  (U='CBW')or(U='CWD')or(U='CWDE')or(U='CDQ');
End;

Procedure ProcessDataTransfers;
{ Parcourt les lignes source et traduit les instructions de transfert.
  Produit des statistiques detaillees. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 MovCount,XchgCount,LeaCount:LongInt;
 LdxCount,MovzxCount,MovsxCount:LongInt;
 CbwCount,TotalXfer:LongInt;
 M:String;
Begin
 TranslationCount:=0;
 MovCount:=0;XchgCount:=0;LeaCount:=0;
 LdxCount:=0;MovzxCount:=0;MovsxCount:=0;
 CbwCount:=0;TotalXfer:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=AsmL.Mnemonic;
  If Not IsDataTransferMnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:=TranslateDataTransfer(AsmL,ProcIdx);
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalXfer);
   If M='MOV' Then Inc(MovCount)
   Else If M='XCHG' Then Inc(XchgCount)
   Else If M='LEA' Then Inc(LeaCount)
   Else If(M='LDS')or(M='LES')or(M='LFS')or(M='LGS')Then
    Inc(LdxCount)
   Else If M='MOVZX' Then Inc(MovzxCount)
   Else If M='MOVSX' Then Inc(MovsxCount)
   Else If(M='CBW')or(M='CWD')or(M='CWDE')or(M='CDQ')Then
    Inc(CbwCount);
  End;
 End;
 WriteLn('Traduction transferts : ',TotalXfer,' instructions, ',
  TranslationCount,' traductions.');
 If Verbose Then Begin
  WriteLn('  MOV       : ',MovCount);
  WriteLn('  XCHG      : ',XchgCount);
  WriteLn('  LEA       : ',LeaCount);
  WriteLn('  LDS/LES   : ',LdxCount);
  WriteLn('  MOVZX     : ',MovzxCount);
  WriteLn('  MOVSX     : ',MovsxCount);
  WriteLn('  CBW/CWD   : ',CbwCount);
  If TranslationCount>0 Then Begin
   WriteLn('  Details :');
   For I:=0 to TranslationCount-1 do
    WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des instructions arithmetiques - TODO 11
  ============================================================ }

Function TranslateADD(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ ADD dest,src -> dest := dest + src }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateADD:=D+' := '+D+' + '+S+';';
End;

Function TranslateADC(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ ADC dest,src -> dest := dest + src + Ord(FlagCF) }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateADC:=D+' := '+D+' + '+S+' + Ord(FlagCF);';
End;

Function TranslateSUB(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ SUB dest,src -> dest := dest - src }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateSUB:=D+' := '+D+' - '+S+';';
End;

Function TranslateSBB(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ SBB dest,src -> dest := dest - src - Ord(FlagCF) }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateSBB:=D+' := '+D+' - '+S+' - Ord(FlagCF);';
End;

Function TranslateINC_DEC(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ INC dest -> Inc(dest); DEC dest -> Dec(dest) }
Var
 D:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Mnemonic='INC' Then
  TranslateINC_DEC:='Inc('+D+');'
 Else
  TranslateINC_DEC:='Dec('+D+');';
End;

Function TranslateNEG(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ NEG dest -> dest := -dest (complement a deux) }
Var
 D:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 TranslateNEG:=D+' := -'+D+';';
End;

Function TranslateMUL(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ MUL src (8 bits)  -> RegAX := Lo(RegAX) * Byte(src)
  MUL src (16 bits) -> LongRec: RegDX:RegAX := Word(RegAX) * Word(src)
  MUL src (32 bits) -> RegEDX:RegEAX := LongInt(RegEAX) * LongInt(src) }
Var
 S:String;
Begin
 S:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op1.OpType=OT_REG8 Then
  TranslateMUL:='RegAX := Word(Lo(RegAX)) * Word(Byte('+S+'));'
 Else If AsmL.Op1.OpType=OT_REG32 Then
  TranslateMUL:=
   'Begin TmpQ := Int64(LongInt(RegEAX)) * Int64(LongInt('+S+')); '+
   'RegEAX := LongInt(TmpQ and $FFFFFFFF); '+
   'RegEDX := LongInt(TmpQ shr 32); End;'
 Else
  TranslateMUL:=
   'Begin TmpL := LongInt(Word(RegAX)) * LongInt(Word('+S+')); '+
   'RegAX := Word(TmpL and $FFFF); '+
   'RegDX := Word(TmpL shr 16); End;';
End;

Function TranslateIMUL(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ IMUL src          -> DX:AX := Integer(AX) * Integer(src) (1 operande)
  IMUL dest,src     -> dest := dest * src (2 operandes, 386+)
  IMUL dest,src,imm -> dest := src * imm (3 operandes, 386+) }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 { Verifier si c'est une forme a 2 ou 3 operandes (386+) }
 If AsmL.Op2.OpType<>OT_NONE Then Begin
  S:=OperandToExpr(AsmL.Op2,ProcIdx);
  { IMUL dest,src -> dest := dest * src }
  TranslateIMUL:=D+' := '+D+' * '+S+';';
 End
 Else Begin
  { IMUL src -> DX:AX := Integer(AX) * Integer(src) (forme 1 op) }
  If AsmL.Op1.OpType=OT_REG8 Then
   TranslateIMUL:='RegAX := Integer(ShortInt(Lo(RegAX))) * '+
    'Integer(ShortInt('+D+'));'
  Else If AsmL.Op1.OpType=OT_REG32 Then
   TranslateIMUL:=
    'Begin TmpQ := Int64(LongInt(RegEAX)) * Int64(LongInt('+D+')); '+
    'RegEAX := LongInt(TmpQ and $FFFFFFFF); '+
    'RegEDX := LongInt(TmpQ shr 32); End;'
  Else
   TranslateIMUL:=
    'Begin TmpL := LongInt(Integer(RegAX)) * LongInt(Integer('+D+')); '+
    'RegAX := Word(TmpL and $FFFF); '+
    'RegDX := Word(TmpL shr 16); End;';
 End;
End;

Function TranslateDIV(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ DIV src (8 bits)  -> AL := AX div src; AH := AX mod src
  DIV src (16 bits) -> AX := DX:AX div src; DX := DX:AX mod src
  DIV src (32 bits) -> EAX := EDX:EAX div src; EDX := EDX:EAX mod src }
Var
 S:String;
Begin
 S:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op1.OpType=OT_REG8 Then
  TranslateDIV:=
   'Begin TmpW := RegAX; '+
   'RegAX := Word(Byte(TmpW div Byte('+S+'))) or '+
   '(Word(Byte(TmpW mod Byte('+S+'))) shl 8); End;'
 Else If AsmL.Op1.OpType=OT_REG32 Then
  TranslateDIV:=
   'Begin TmpQ := (Int64(LongInt(RegEDX)) shl 32) or '+
   'Int64(LongInt(RegEAX) and $FFFFFFFF); '+
   'RegEAX := LongInt(TmpQ div LongInt('+S+')); '+
   'RegEDX := LongInt(TmpQ mod LongInt('+S+')); End;'
 Else
  TranslateDIV:=
   'Begin TmpL := (LongInt(RegDX) shl 16) or LongInt(RegAX); '+
   'RegAX := Word(TmpL div Word('+S+')); '+
   'RegDX := Word(TmpL mod Word('+S+')); End;';
End;

Function TranslateIDIV(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ IDIV src (8 bits)  -> AL := AX sdiv src; AH := AX smod src
  IDIV src (16 bits) -> AX := DX:AX sdiv src; DX := DX:AX smod src
  IDIV src (32 bits) -> EAX := EDX:EAX sdiv src; EDX := EDX:EAX smod src }
Var
 S:String;
Begin
 S:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op1.OpType=OT_REG8 Then
  TranslateIDIV:=
   'Begin TmpI := Integer(RegAX); '+
   'RegAX := Word(Byte(ShortInt(TmpI div ShortInt('+S+')))) or '+
   '(Word(Byte(ShortInt(TmpI mod ShortInt('+S+')))) shl 8); End;'
 Else If AsmL.Op1.OpType=OT_REG32 Then
  TranslateIDIV:=
   'Begin TmpQ := (Int64(LongInt(RegEDX)) shl 32) or '+
   'Int64(LongInt(RegEAX) and $FFFFFFFF); '+
   'RegEAX := LongInt(TmpQ div LongInt('+S+')); '+
   'RegEDX := LongInt(TmpQ mod LongInt('+S+')); End;'
 Else
  TranslateIDIV:=
   'Begin TmpL := (LongInt(RegDX) shl 16) or LongInt(RegAX); '+
   'RegAX := Word(Integer(TmpL div Integer('+S+'))); '+
   'RegDX := Word(Integer(TmpL mod Integer('+S+'))); End;';
End;

Function TranslateArithmetic(Var AsmL:TAsmLine;
 ProcIdx:Integer):String;
{ Orchestre la traduction d'une instruction arithmetique.
  Retourne la chaine Pascal correspondante, ou '' si non gere. }
Var
 M:String;
Begin
 M:=AsmL.Mnemonic;
 If M='ADD' Then
  TranslateArithmetic:=TranslateADD(AsmL,ProcIdx)
 Else If M='ADC' Then
  TranslateArithmetic:=TranslateADC(AsmL,ProcIdx)
 Else If M='SUB' Then
  TranslateArithmetic:=TranslateSUB(AsmL,ProcIdx)
 Else If M='SBB' Then
  TranslateArithmetic:=TranslateSBB(AsmL,ProcIdx)
 Else If(M='INC')or(M='DEC')Then
  TranslateArithmetic:=TranslateINC_DEC(AsmL,ProcIdx)
 Else If M='NEG' Then
  TranslateArithmetic:=TranslateNEG(AsmL,ProcIdx)
 Else If M='MUL' Then
  TranslateArithmetic:=TranslateMUL(AsmL,ProcIdx)
 Else If M='IMUL' Then
  TranslateArithmetic:=TranslateIMUL(AsmL,ProcIdx)
 Else If M='DIV' Then
  TranslateArithmetic:=TranslateDIV(AsmL,ProcIdx)
 Else If M='IDIV' Then
  TranslateArithmetic:=TranslateIDIV(AsmL,ProcIdx)
 Else
  TranslateArithmetic:='';
End;

Function IsArithmeticMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une instruction arithmetique }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsArithmeticMnemonic:=
  (U='ADD')or(U='ADC')or(U='SUB')or(U='SBB')or
  (U='INC')or(U='DEC')or(U='NEG')or
  (U='MUL')or(U='IMUL')or(U='DIV')or(U='IDIV');
End;

Procedure ProcessArithmeticTranslations;
{ Parcourt les lignes source et traduit les instructions arithmetiques.
  Produit des statistiques detaillees. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 AddCount,AdcCount,SubCount,SbbCount:LongInt;
 IncDecCount,NegCount:LongInt;
 MulCount,ImulCount,DivCount,IdivCount:LongInt;
 TotalArith:LongInt;
 M:String;
Begin
 AddCount:=0;AdcCount:=0;SubCount:=0;SbbCount:=0;
 IncDecCount:=0;NegCount:=0;
 MulCount:=0;ImulCount:=0;DivCount:=0;IdivCount:=0;
 TotalArith:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=AsmL.Mnemonic;
  If Not IsArithmeticMnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:=TranslateArithmetic(AsmL,ProcIdx);
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalArith);
   If M='ADD' Then Inc(AddCount)
   Else If M='ADC' Then Inc(AdcCount)
   Else If M='SUB' Then Inc(SubCount)
   Else If M='SBB' Then Inc(SbbCount)
   Else If(M='INC')or(M='DEC')Then Inc(IncDecCount)
   Else If M='NEG' Then Inc(NegCount)
   Else If M='MUL' Then Inc(MulCount)
   Else If M='IMUL' Then Inc(ImulCount)
   Else If M='DIV' Then Inc(DivCount)
   Else If M='IDIV' Then Inc(IdivCount);
  End;
 End;
 WriteLn('Traduction arithmetique : ',TotalArith,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  ADD       : ',AddCount);
  WriteLn('  ADC       : ',AdcCount);
  WriteLn('  SUB       : ',SubCount);
  WriteLn('  SBB       : ',SbbCount);
  WriteLn('  INC/DEC   : ',IncDecCount);
  WriteLn('  NEG       : ',NegCount);
  WriteLn('  MUL       : ',MulCount);
  WriteLn('  IMUL      : ',ImulCount);
  WriteLn('  DIV       : ',DivCount);
  WriteLn('  IDIV      : ',IdivCount);
  If TotalArith>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalArith to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des instructions logiques et de decalage - TODO 12
  ============================================================ }

Function TranslateAND(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ AND dest,src -> dest := dest and src }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateAND:=D+' := '+D+' and '+S+';';
End;

Function TranslateOR(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ OR dest,src -> dest := dest or src }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateOR:=D+' := '+D+' or '+S+';';
End;

Function TranslateXOR(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ XOR dest,src -> dest := dest xor src }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateXOR:=D+' := '+D+' xor '+S+';';
End;

Function TranslateNOT(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ NOT dest -> dest := not dest }
Var
 D:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 TranslateNOT:=D+' := not '+D+';';
End;

Function TranslateTEST(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ TEST a,b -> positionner flags selon a and b (pas de stockage) }
Var
 A,B:String;
Begin
 A:=OperandToExpr(AsmL.Op1,ProcIdx);
 B:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateTEST:=
  'Begin FlagZF := ('+A+' and '+B+') = 0; '+
  'FlagSF := ('+A+' and '+B+') < 0; '+
  'FlagCF := False; FlagOF := False; End;';
End;

Function TranslateSHL(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ SHL/SAL dest,n -> dest := dest shl n }
Var
 D,N:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op2.OpType<>OT_NONE Then
  N:=OperandToExpr(AsmL.Op2,ProcIdx)
 Else
  N:='1';
 TranslateSHL:=D+' := '+D+' shl '+N+';';
End;

Function TranslateSHR(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ SHR dest,n -> dest := dest shr n (non signe) }
Var
 D,N:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op2.OpType<>OT_NONE Then
  N:=OperandToExpr(AsmL.Op2,ProcIdx)
 Else
  N:='1';
 TranslateSHR:=D+' := '+D+' shr '+N+';';
End;

Function TranslateSAR(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ SAR dest,n -> decalage arithmetique a droite (preserve le signe) }
Var
 D,N:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op2.OpType<>OT_NONE Then
  N:=OperandToExpr(AsmL.Op2,ProcIdx)
 Else
  N:='1';
 If AsmL.Op1.OpType=OT_REG32 Then
  TranslateSAR:=D+' := LongInt(LongInt('+D+') div (1 shl '+N+'));'
 Else If AsmL.Op1.OpType=OT_REG8 Then
  TranslateSAR:=D+' := Byte(ShortInt(ShortInt('+D+') div (1 shl '+N+')));'
 Else
  TranslateSAR:=D+' := Word(Integer(Integer('+D+') div (1 shl '+N+')));';
End;

Function TranslateROTATE(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ ROL/ROR/RCL/RCR dest,n -> rotations (pas d'equivalent direct en Pascal) }
Var
 D,N,M,Bits:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op2.OpType<>OT_NONE Then
  N:=OperandToExpr(AsmL.Op2,ProcIdx)
 Else
  N:='1';
 M:=AsmL.Mnemonic;
 If AsmL.Op1.OpType=OT_REG32 Then Bits:='32'
 Else If AsmL.Op1.OpType=OT_REG8 Then Bits:='8'
 Else Bits:='16';
 If M='ROL' Then
  TranslateROTATE:=D+' := ('+D+' shl '+N+') or ('+D+' shr ('+Bits+'-'+N+'));'
 Else If M='ROR' Then
  TranslateROTATE:=D+' := ('+D+' shr '+N+') or ('+D+' shl ('+Bits+'-'+N+'));'
 Else If M='RCL' Then
  TranslateROTATE:=
   'Begin FlagCF := ('+D+' shr ('+Bits+'-1)) and 1 = 1; '+
   D+' := ('+D+' shl '+N+') or Ord(FlagCF); End;'
 Else { RCR }
  TranslateROTATE:=
   'Begin FlagCF := '+D+' and 1 = 1; '+
   D+' := ('+D+' shr '+N+') or (Ord(FlagCF) shl ('+Bits+'-1)); End;';
End;

Function TranslateBIT(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ BT base,bit  -> FlagCF := (base shr bit) and 1 = 1
  BTS base,bit -> FlagCF := ...; base := base or (1 shl bit)
  BTR base,bit -> FlagCF := ...; base := base and not (1 shl bit)
  BTC base,bit -> FlagCF := ...; base := base xor (1 shl bit) }
Var
 D,B,M:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 B:=OperandToExpr(AsmL.Op2,ProcIdx);
 M:=AsmL.Mnemonic;
 If M='BT' Then
  TranslateBIT:='FlagCF := ('+D+' shr '+B+') and 1 = 1;'
 Else If M='BTS' Then
  TranslateBIT:=
   'Begin FlagCF := ('+D+' shr '+B+') and 1 = 1; '+
   D+' := '+D+' or (1 shl '+B+'); End;'
 Else If M='BTR' Then
  TranslateBIT:=
   'Begin FlagCF := ('+D+' shr '+B+') and 1 = 1; '+
   D+' := '+D+' and not (1 shl '+B+'); End;'
 Else { BTC }
  TranslateBIT:=
   'Begin FlagCF := ('+D+' shr '+B+') and 1 = 1; '+
   D+' := '+D+' xor (1 shl '+B+'); End;';
End;

Function TranslateLogical(Var AsmL:TAsmLine;
 ProcIdx:Integer):String;
{ Orchestre la traduction d'une instruction logique ou de decalage.
  Retourne la chaine Pascal correspondante, ou '' si non gere. }
Var
 M:String;
Begin
 M:=AsmL.Mnemonic;
 If M='AND' Then
  TranslateLogical:=TranslateAND(AsmL,ProcIdx)
 Else If M='OR' Then
  TranslateLogical:=TranslateOR(AsmL,ProcIdx)
 Else If M='XOR' Then
  TranslateLogical:=TranslateXOR(AsmL,ProcIdx)
 Else If M='NOT' Then
  TranslateLogical:=TranslateNOT(AsmL,ProcIdx)
 Else If M='TEST' Then
  TranslateLogical:=TranslateTEST(AsmL,ProcIdx)
 Else If(M='SHL')or(M='SAL')Then
  TranslateLogical:=TranslateSHL(AsmL,ProcIdx)
 Else If M='SHR' Then
  TranslateLogical:=TranslateSHR(AsmL,ProcIdx)
 Else If M='SAR' Then
  TranslateLogical:=TranslateSAR(AsmL,ProcIdx)
 Else If(M='ROL')or(M='ROR')or(M='RCL')or(M='RCR')Then
  TranslateLogical:=TranslateROTATE(AsmL,ProcIdx)
 Else If(M='BT')or(M='BTS')or(M='BTR')or(M='BTC')Then
  TranslateLogical:=TranslateBIT(AsmL,ProcIdx)
 Else
  TranslateLogical:='';
End;

Function IsLogicalMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une instruction logique ou de decalage }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsLogicalMnemonic:=
  (U='AND')or(U='OR')or(U='XOR')or(U='NOT')or(U='TEST')or
  (U='SHL')or(U='SAL')or(U='SHR')or(U='SAR')or
  (U='ROL')or(U='ROR')or(U='RCL')or(U='RCR')or
  (U='BT')or(U='BTS')or(U='BTR')or(U='BTC');
End;

Procedure ProcessLogicalTranslations;
{ Parcourt les lignes source et traduit les instructions logiques
  et de decalage. Produit des statistiques detaillees. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 AndCount,OrCount,XorCount,NotCount,TestCount:LongInt;
 ShlCount,ShrCount,SarCount:LongInt;
 RotCount,BitCount:LongInt;
 TotalLogic:LongInt;
 M:String;
Begin
 AndCount:=0;OrCount:=0;XorCount:=0;NotCount:=0;TestCount:=0;
 ShlCount:=0;ShrCount:=0;SarCount:=0;
 RotCount:=0;BitCount:=0;
 TotalLogic:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=AsmL.Mnemonic;
  If Not IsLogicalMnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:=TranslateLogical(AsmL,ProcIdx);
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalLogic);
   If M='AND' Then Inc(AndCount)
   Else If M='OR' Then Inc(OrCount)
   Else If M='XOR' Then Inc(XorCount)
   Else If M='NOT' Then Inc(NotCount)
   Else If M='TEST' Then Inc(TestCount)
   Else If(M='SHL')or(M='SAL')Then Inc(ShlCount)
   Else If M='SHR' Then Inc(ShrCount)
   Else If M='SAR' Then Inc(SarCount)
   Else If(M='ROL')or(M='ROR')or(M='RCL')or(M='RCR')Then Inc(RotCount)
   Else If(M='BT')or(M='BTS')or(M='BTR')or(M='BTC')Then Inc(BitCount);
  End;
 End;
 WriteLn('Traduction logique/decalage : ',TotalLogic,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  AND       : ',AndCount);
  WriteLn('  OR        : ',OrCount);
  WriteLn('  XOR       : ',XorCount);
  WriteLn('  NOT       : ',NotCount);
  WriteLn('  TEST      : ',TestCount);
  WriteLn('  SHL/SAL   : ',ShlCount);
  WriteLn('  SHR       : ',ShrCount);
  WriteLn('  SAR       : ',SarCount);
  WriteLn('  ROL/ROR/RCL/RCR : ',RotCount);
  WriteLn('  BT/BTS/BTR/BTC  : ',BitCount);
  If TotalLogic>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalLogic to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des comparaisons et sauts conditionnels - TODO 13
  ============================================================ }

Function TranslateCMP(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ CMP a,b -> positionner les flags de comparaison
  Stocke dans les variables FlagZF, FlagCF, FlagSF, FlagOF }
Var
 A,B:String;
Begin
 A:=OperandToExpr(AsmL.Op1,ProcIdx);
 B:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateCMP:=
  'Begin FlagZF := ('+A+') = ('+B+'); '+
  'FlagCF := ('+A+') < ('+B+'); '+
  'FlagSF := ('+A+') - ('+B+') < 0; '+
  'FlagOF := False; End;';
End;

Function JccToCondition(Mnem:String):String;
{ Convertit un mnemonique Jcc en operateur de comparaison Pascal.
  Sauts signes : JE/JZ = , JNE/JNZ <> , JL/JNGE < , JG/JNLE > ,
                 JLE/JNG <= , JGE/JNL >= .
  Sauts non signes : JB/JNAE/JC < , JA/JNBE > , JBE/JNA <= , JAE/JNB/JNC >= .
  Sauts sur flags : JS -> SF, JNS -> not SF, JO -> OF, JNO -> not OF,
                    JP/JPE -> PF, JNP/JPO -> not PF.
  Retourne '' si non reconnu. }
Var
 U:String;
Begin
 U:=UpCaseStr(Mnem);
 If(U='JE')or(U='JZ')Then JccToCondition:='='
 Else If(U='JNE')or(U='JNZ')Then JccToCondition:='<>'
 Else If(U='JL')or(U='JNGE')Then JccToCondition:='<'
 Else If(U='JG')or(U='JNLE')Then JccToCondition:='>'
 Else If(U='JLE')or(U='JNG')Then JccToCondition:='<='
 Else If(U='JGE')or(U='JNL')Then JccToCondition:='>='
 Else If(U='JB')or(U='JNAE')or(U='JC')Then JccToCondition:='<'
 Else If(U='JA')or(U='JNBE')Then JccToCondition:='>'
 Else If(U='JBE')or(U='JNA')Then JccToCondition:='<='
 Else If(U='JAE')or(U='JNB')or(U='JNC')Then JccToCondition:='>='
 Else JccToCondition:='';
End;

Function JccToFlagExpr(Mnem:String):String;
{ Convertit un mnemonique Jcc en expression sur les flags (quand pas de CMP).
  JS -> FlagSF, JNS -> not FlagSF, JO -> FlagOF, JNO -> not FlagOF,
  JP/JPE -> FlagPF, JNP/JPO -> not FlagPF,
  JZ/JE -> FlagZF, JNZ/JNE -> not FlagZF,
  JC/JB -> FlagCF, JNC/JAE -> not FlagCF.
  Retourne '' si non reconnu. }
Var
 U:String;
Begin
 U:=UpCaseStr(Mnem);
 If(U='JE')or(U='JZ')Then JccToFlagExpr:='FlagZF'
 Else If(U='JNE')or(U='JNZ')Then JccToFlagExpr:='not FlagZF'
 Else If U='JS' Then JccToFlagExpr:='FlagSF'
 Else If U='JNS' Then JccToFlagExpr:='not FlagSF'
 Else If U='JO' Then JccToFlagExpr:='FlagOF'
 Else If U='JNO' Then JccToFlagExpr:='not FlagOF'
 Else If(U='JP')or(U='JPE')Then JccToFlagExpr:='FlagPF'
 Else If(U='JNP')or(U='JPO')Then JccToFlagExpr:='not FlagPF'
 Else If(U='JC')or(U='JB')or(U='JNAE')Then JccToFlagExpr:='FlagCF'
 Else If(U='JNC')or(U='JAE')or(U='JNB')Then JccToFlagExpr:='not FlagCF'
 Else If(U='JA')or(U='JNBE')Then
  JccToFlagExpr:='(not FlagCF) and (not FlagZF)'
 Else If(U='JBE')or(U='JNA')Then
  JccToFlagExpr:='FlagCF or FlagZF'
 Else If(U='JG')or(U='JNLE')Then
  JccToFlagExpr:='(not FlagZF) and (FlagSF = FlagOF)'
 Else If(U='JGE')or(U='JNL')Then
  JccToFlagExpr:='FlagSF = FlagOF'
 Else If(U='JL')or(U='JNGE')Then
  JccToFlagExpr:='FlagSF <> FlagOF'
 Else If(U='JLE')or(U='JNG')Then
  JccToFlagExpr:='FlagZF or (FlagSF <> FlagOF)'
 Else JccToFlagExpr:='';
End;

Function IsConditionalJump(M:String):Boolean;
{ Verifie si un mnemonique est un saut conditionnel }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsConditionalJump:=
  (U='JE')or(U='JNE')or(U='JZ')or(U='JNZ')or
  (U='JA')or(U='JAE')or(U='JB')or(U='JBE')or
  (U='JG')or(U='JGE')or(U='JL')or(U='JLE')or
  (U='JNA')or(U='JNAE')or(U='JNB')or(U='JNBE')or
  (U='JNG')or(U='JNGE')or(U='JNL')or(U='JNLE')or
  (U='JC')or(U='JNC')or(U='JO')or(U='JNO')or
  (U='JS')or(U='JNS')or(U='JP')or(U='JNP')or
  (U='JPE')or(U='JPO');
End;

Function IsCompareJumpMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est CMP ou un saut conditionnel }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsCompareJumpMnemonic:=(U='CMP')or IsConditionalJump(U);
End;

Procedure ProcessCompareJumpTranslations;
{ Parcourt les lignes source et traduit les patterns CMP + Jcc
  en structures If..Then Goto label ou en expressions sur flags.
  Detecte les patterns CMP suivi de Jcc et combine les deux lignes
  en une seule traduction Pascal. Produit des statistiques. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 CmpCount,JccCount,CmpJccCount,FlagJccCount:LongInt;
 TotalCmpJcc:LongInt;
 M:String;
 Cond,FExpr:String;
 CmpA,CmpB:String;
 Target:String;
 CmpLine:LongInt;
 HasPendingCmp:Boolean;
 PendingA,PendingB:String;
Begin
 CmpCount:=0;JccCount:=0;CmpJccCount:=0;FlagJccCount:=0;
 TotalCmpJcc:=0;
 HasPendingCmp:=False;
 PendingA:='';PendingB:='';
 CmpLine:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=AsmL.Mnemonic;
  ProcIdx:=FindProcForLine(I);
  { Traiter CMP }
  If M='CMP' Then Begin
   CmpA:=OperandToExpr(AsmL.Op1,ProcIdx);
   CmpB:=OperandToExpr(AsmL.Op2,ProcIdx);
   Code:=TranslateCMP(AsmL,ProcIdx);
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(CmpCount);
   Inc(TotalCmpJcc);
   HasPendingCmp:=True;
   PendingA:=CmpA;
   PendingB:=CmpB;
   CmpLine:=I;
  End
  { Traiter les sauts conditionnels }
  Else If IsConditionalJump(M) Then Begin
   Target:=OperandToExpr(AsmL.Op1,ProcIdx);
   { Si CMP precede immediatement : generer If a op b Then Goto label }
   If HasPendingCmp and(I=CmpLine+1)Then Begin
    Cond:=JccToCondition(M);
    If Cond<>'' Then Begin
     Code:='If '+PendingA+' '+Cond+' '+PendingB+' Then Goto '+Target+';';
     AddTranslation(I,Code,SrcLines[I]^);
     Inc(CmpJccCount);
     Inc(TotalCmpJcc);
    End
    Else Begin
     { Sauts sur flags speciaux (JS/JO/JP) meme apres CMP }
     FExpr:=JccToFlagExpr(M);
     If FExpr<>'' Then Begin
      Code:='If '+FExpr+' Then Goto '+Target+';';
      AddTranslation(I,Code,SrcLines[I]^);
      Inc(FlagJccCount);
      Inc(TotalCmpJcc);
     End;
    End;
   End
   Else Begin
    { Pas de CMP precedent : utiliser les flags }
    FExpr:=JccToFlagExpr(M);
    If FExpr<>'' Then Begin
     Code:='If '+FExpr+' Then Goto '+Target+';';
     AddTranslation(I,Code,SrcLines[I]^);
     Inc(FlagJccCount);
     Inc(TotalCmpJcc);
    End;
   End;
   Inc(JccCount);
   HasPendingCmp:=False;
  End
  Else Begin
   { Toute autre instruction invalide le CMP en attente }
   HasPendingCmp:=False;
  End;
 End;
 WriteLn('Traduction comparaisons/sauts : ',TotalCmpJcc,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  CMP              : ',CmpCount);
  WriteLn('  Jcc total        : ',JccCount);
  WriteLn('  CMP+Jcc -> If op : ',CmpJccCount);
  WriteLn('  Jcc -> If flag   : ',FlagJccCount);
  If TotalCmpJcc>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalCmpJcc to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des sauts inconditionnels et boucles - TODO 14
  ============================================================ }

Function TranslateJMP(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ JMP label -> Goto label }
Var
 Target:String;
Begin
 Target:=OperandToExpr(AsmL.Op1,ProcIdx);
 TranslateJMP:='Goto '+Target+';';
End;

Function TranslateLOOP(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ LOOP label -> Begin Dec(RegCX); If RegCX <> 0 Then Goto label End }
Var
 Target,CxVar:String;
Begin
 Target:=OperandToExpr(AsmL.Op1,ProcIdx);
 If Mode32 Then CxVar:='RegECX'
 Else CxVar:='RegCX';
 TranslateLOOP:='Begin Dec('+CxVar+'); If '+CxVar+' <> 0 Then Goto '+Target+'; End;';
End;

Function TranslateLOOPE(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ LOOPE/LOOPZ label -> Begin Dec(RegCX); If (RegCX<>0) and FlagZF Then Goto label End }
Var
 Target,CxVar:String;
Begin
 Target:=OperandToExpr(AsmL.Op1,ProcIdx);
 If Mode32 Then CxVar:='RegECX'
 Else CxVar:='RegCX';
 TranslateLOOPE:='Begin Dec('+CxVar+'); If ('+CxVar+' <> 0) and FlagZF Then Goto '+Target+'; End;';
End;

Function TranslateLOOPNE(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ LOOPNE/LOOPNZ label -> Begin Dec(RegCX); If (RegCX<>0) and not FlagZF Then Goto label End }
Var
 Target,CxVar:String;
Begin
 Target:=OperandToExpr(AsmL.Op1,ProcIdx);
 If Mode32 Then CxVar:='RegECX'
 Else CxVar:='RegCX';
 TranslateLOOPNE:='Begin Dec('+CxVar+'); If ('+CxVar+' <> 0) and not FlagZF Then Goto '+Target+'; End;';
End;

Function TranslateJCXZ(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ JCXZ/JECXZ label -> If RegCX = 0 Then Goto label }
Var
 Target,CxVar:String;
Begin
 Target:=OperandToExpr(AsmL.Op1,ProcIdx);
 If Mode32 Then CxVar:='RegECX'
 Else CxVar:='RegCX';
 TranslateJCXZ:='If '+CxVar+' = 0 Then Goto '+Target+';';
End;

Function IsJumpLoopMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est un saut inconditionnel ou une instruction de boucle }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsJumpLoopMnemonic:=
  (U='JMP')or(U='LOOP')or(U='LOOPE')or(U='LOOPZ')or
  (U='LOOPNE')or(U='LOOPNZ')or(U='JCXZ')or(U='JECXZ');
End;

Function IsBackwardJump(JmpLine:LongInt;TargetLabel:String):Boolean;
{ Detecte si un JMP pointe en arriere (back-edge potentielle boucle).
  Cherche si le label cible est defini avant la ligne du JMP. }
Var
 I:LongInt;
 AsmT:TAsmLine;
Begin
 IsBackwardJump:=False;
 For I:=0 to JmpLine-1 do Begin
  ParseInstructionLine(I,AsmT);
  If UpCaseStr(AsmT.LabelStr)=UpCaseStr(TargetLabel) Then Begin
   IsBackwardJump:=True;
   Exit;
  End;
 End;
End;

Procedure ProcessJumpLoopTranslations;
{ Parcourt les lignes source et traduit les sauts inconditionnels
  et les instructions de boucle. Detecte les back-edges pour
  identifier les boucles potentielles. Produit des statistiques. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 JmpCount,LoopCount,LoopeCount,LoopneCount,JcxzCount:LongInt;
 BackJmpCount:LongInt;
 TotalJmpLoop:LongInt;
 M:String;
 Target:String;
Begin
 JmpCount:=0;LoopCount:=0;LoopeCount:=0;LoopneCount:=0;JcxzCount:=0;
 BackJmpCount:=0;
 TotalJmpLoop:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=AsmL.Mnemonic;
  If Not IsJumpLoopMnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:='';
  If M='JMP' Then Begin
   Code:=TranslateJMP(AsmL,ProcIdx);
   Inc(JmpCount);
   { Detecter les sauts arriere (boucles potentielles) }
   Target:=OperandToExpr(AsmL.Op1,ProcIdx);
   If IsBackwardJump(I,Target) Then
    Inc(BackJmpCount);
  End
  Else If M='LOOP' Then Begin
   Code:=TranslateLOOP(AsmL,ProcIdx);
   Inc(LoopCount);
  End
  Else If(M='LOOPE')or(M='LOOPZ')Then Begin
   Code:=TranslateLOOPE(AsmL,ProcIdx);
   Inc(LoopeCount);
  End
  Else If(M='LOOPNE')or(M='LOOPNZ')Then Begin
   Code:=TranslateLOOPNE(AsmL,ProcIdx);
   Inc(LoopneCount);
  End
  Else If(M='JCXZ')or(M='JECXZ')Then Begin
   Code:=TranslateJCXZ(AsmL,ProcIdx);
   Inc(JcxzCount);
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalJmpLoop);
  End;
 End;
 WriteLn('Traduction sauts/boucles : ',TotalJmpLoop,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  JMP              : ',JmpCount);
  WriteLn('    dont arriere   : ',BackJmpCount);
  WriteLn('  LOOP             : ',LoopCount);
  WriteLn('  LOOPE/LOOPZ      : ',LoopeCount);
  WriteLn('  LOOPNE/LOOPNZ    : ',LoopneCount);
  WriteLn('  JCXZ/JECXZ       : ',JcxzCount);
  If TotalJmpLoop>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalJmpLoop to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des appels de procedures (CALL/RET) - TODO 15
  ============================================================ }

Function FindProcByName(Name:String):Integer;
{ Recherche un index de procedure par nom (case-insensitive). Retourne 0 si non trouvee. }
Var
 I:Integer;
 U:String;
Begin
 U:=UpCaseStr(Name);
 FindProcByName:=0;
 For I:=1 to ProcCount do
  If UpCaseStr(Procs[I].Name)=U Then Begin
   FindProcByName:=I;
   Exit;
  End;
End;

Function CountPushesBeforeCall(CallLine:LongInt):Integer;
{ Compte les PUSH consecutifs immediatement avant un CALL.
  Remonte depuis CallLine-1 tant que l'instruction est un PUSH. }
Var
 I:LongInt;
 AsmT:TAsmLine;
 Count:Integer;
Begin
 Count:=0;
 I:=CallLine-1;
 While I>=0 do Begin
  ParseInstructionLine(I,AsmT);
  If AsmT.Mnemonic='' Then Begin Dec(I); Continue; End;
  If AsmT.IsDirective Then Begin Dec(I); Continue; End;
  If UpCaseStr(AsmT.Mnemonic)<>'PUSH' Then Break;
  Inc(Count);
  Dec(I);
 End;
 CountPushesBeforeCall:=Count;
End;

Function BuildCallArgs(CallLine:LongInt;ArgCount:Integer;
 Convention:Byte;ProcIdx:Integer):String;
{ Construit la liste des arguments Pascal pour un CALL.
  Pour la convention C (droite a gauche), les PUSH sont empiles
  dans l'ordre inverse : le dernier PUSH est le premier argument.
  Pour PASCAL (gauche a droite), l'ordre est direct.
  Pour STDCALL (droite a gauche), meme ordre que C. }
Var
 I,J:LongInt;
 AsmT:TAsmLine;
 Args:Array[1..32] of String;
 RealCount:Integer;
 Result:String;
Begin
 RealCount:=0;
 I:=CallLine-1;
 { Collecter les arguments depuis les PUSH avant le CALL }
 While(I>=0)and(RealCount<ArgCount)and(RealCount<32)do Begin
  ParseInstructionLine(I,AsmT);
  If AsmT.Mnemonic='' Then Begin Dec(I); Continue; End;
  If AsmT.IsDirective Then Begin Dec(I); Continue; End;
  If UpCaseStr(AsmT.Mnemonic)<>'PUSH' Then Break;
  Inc(RealCount);
  Args[RealCount]:=OperandToExpr(AsmT.Op1,ProcIdx);
  Dec(I);
 End;
 { Construire la chaine d'arguments }
 Result:='';
 If RealCount>0 Then Begin
  If(Convention=CC_PASCAL)or(Convention=CC_BASIC)or
    (Convention=CC_FORTRAN)Then Begin
   { Convention Pascal : arguments dans l'ordre inverse des PUSH }
   For J:=RealCount downto 1 do Begin
    If Result<>'' Then Result:=Result+', ';
    Result:=Result+Args[J];
   End;
  End
  Else Begin
   { Convention C / STDCALL : premier PUSH = dernier argument }
   For J:=RealCount downto 1 do Begin
    If Result<>'' Then Result:=Result+', ';
    Result:=Result+Args[J];
   End;
  End;
 End;
 BuildCallArgs:=Result;
End;

Function IsStringsCall(Name:String):Boolean;
{ Verifie si le nom correspond a une fonction C de manipulation de
  chaines, traduisible par l'unite Strings de Turbo Pascal.
  Reconnait les noms avec ou sans prefixe _ en majuscules/minuscules. }
Var U:String;
Begin
 U:=UpCaseStr(Name);
 If(Length(U)>1)and(U[1]='_')Then
  Delete(U,1,1);
 IsStringsCall:=
  (U='STRCMP')or(U='STRICMP')or(U='STRCASECMP')or
  (U='STRCAT')or(U='STRCPY')or(U='STRLEN')or
  (U='STRNCAT')or(U='STRNCPY')or
  (U='STRUPR')or(U='STRLWR')or
  (U='STRSTR')or(U='STRCHR')or(U='STRRCHR')or
  (U='STRMOV')or(U='STREND')or(U='STRNEW')or
  (U='STRDISPOSE')or(U='STRPAS')or(U='STRPCOPY');
End;

Function StringsFuncName(Name:String):String;
{ Retourne le nom de la fonction equivalente de l'unite Strings
  de Turbo Pascal pour une fonction C de chaines. }
Var U:String;
Begin
 U:=UpCaseStr(Name);
 If(Length(U)>1)and(U[1]='_')Then
  Delete(U,1,1);
 If U='STRCMP' Then StringsFuncName:='StrComp'
 Else If(U='STRICMP')or(U='STRCASECMP')Then
  StringsFuncName:='StrIComp'
 Else If U='STRCAT' Then StringsFuncName:='StrCat'
 Else If U='STRCPY' Then StringsFuncName:='StrCopy'
 Else If U='STRLEN' Then StringsFuncName:='StrLen'
 Else If U='STRNCAT' Then StringsFuncName:='StrLCat'
 Else If U='STRNCPY' Then StringsFuncName:='StrLCopy'
 Else If U='STRUPR' Then StringsFuncName:='StrUpper'
 Else If U='STRLWR' Then StringsFuncName:='StrLower'
 Else If U='STRSTR' Then StringsFuncName:='StrPos'
 Else If U='STRCHR' Then StringsFuncName:='StrScan'
 Else If U='STRRCHR' Then StringsFuncName:='StrRScan'
 Else If U='STRMOV' Then StringsFuncName:='StrMove'
 Else If U='STREND' Then StringsFuncName:='StrEnd'
 Else If U='STRNEW' Then StringsFuncName:='StrNew'
 Else If U='STRDISPOSE' Then StringsFuncName:='StrDispose'
 Else If U='STRPAS' Then StringsFuncName:='StrPas'
 Else If U='STRPCOPY' Then StringsFuncName:='StrPCopy'
 Else StringsFuncName:=Name;
End;

Function IsStringsReturnAX(Name:String):Boolean;
{ Verifie si une fonction Strings retourne une valeur entiere
  qui doit etre capturee dans RegAX (strcmp, stricmp, strlen). }
Var U:String;
Begin
 U:=UpCaseStr(Name);
 If(Length(U)>1)and(U[1]='_')Then
  Delete(U,1,1);
 IsStringsReturnAX:=
  (U='STRCMP')or(U='STRICMP')or(U='STRCASECMP')or
  (U='STRLEN');
End;

Function TranslateCALL(Var AsmL:TAsmLine;LineIdx:LongInt;
 ProcIdx:Integer):String;
{ CALL label -> NomProc(args) ou NomProc si pas de parametres.
  Si la procedure cible est connue, genere un appel avec parametres.
  Si c'est une fonction C de chaines (strcmp, strcat, ...), utilise
  l'equivalent de l'unite Strings de Turbo Pascal.
  Sinon, genere un appel simple au label. }
Var
 Target:String;
 TargetProc:Integer;
 PushCount:Integer;
 ArgCount:Integer;
 Args:String;
 Conv:Byte;
 R:String;
 PascalName:String;
Begin
 { CALL FAR avec adresse absolue: non traduisible, generer un commentaire }
 If AsmL.Op1.OpType=OT_FAR Then Begin
  TranslateCALL:='{ TODO: CALL FAR '+HexWord(Word(AsmL.Op1.Imm))+'h:'
   +HexWord(Word(AsmL.Op1.Disp))+'h }';
  Exit;
 End;
 Target:=OperandToExpr(AsmL.Op1,ProcIdx);
 TargetProc:=FindProcByName(Target);
 R:='';
 If TargetProc>0 Then Begin
  { Procedure connue : utiliser le nombre de parametres declares }
  ArgCount:=Procs[TargetProc].ParamCount;
  Conv:=Procs[TargetProc].Convention;
  If ArgCount>0 Then Begin
   PushCount:=CountPushesBeforeCall(LineIdx);
   If PushCount<ArgCount Then ArgCount:=PushCount;
   Args:=BuildCallArgs(LineIdx,ArgCount,Conv,ProcIdx);
   If Procs[TargetProc].IsFunction Then
    R:='RegAX := '+Target+'('+Args+')'
   Else
    R:=Target+'('+Args+')'
  End
  Else Begin
   If Procs[TargetProc].IsFunction Then
    R:='RegAX := '+Target
   Else
    R:=Target
  End;
 End
 Else If IsStringsCall(Target) Then Begin
  { Fonction C de chaines -> utiliser l'unite Strings }
  PascalName:=StringsFuncName(Target);
  PushCount:=CountPushesBeforeCall(LineIdx);
  If PushCount>0 Then Begin
   Args:=BuildCallArgs(LineIdx,PushCount,CC_C,ProcIdx);
   If IsStringsReturnAX(Target) Then
    R:='RegAX := '+PascalName+'('+Args+')'
   Else
    R:=PascalName+'('+Args+')'
  End
  Else Begin
   If IsStringsReturnAX(Target) Then
    R:='RegAX := '+PascalName
   Else
    R:=PascalName
  End
 End
 Else Begin
  { Procedure inconnue : verifier s'il y a des PUSH avant }
  PushCount:=CountPushesBeforeCall(LineIdx);
  If PushCount>0 Then Begin
   Args:=BuildCallArgs(LineIdx,PushCount,CC_C,ProcIdx);
   R:=Target+'('+Args+')'
  End
  Else
   R:=Target;
 End;
 TranslateCALL:=R+';';
End;

Function TranslateRET(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ RET -> Exit
  RET n -> Begin RegSP := RegSP + n; Exit; End
  RETF -> Exit (appel FAR)
  RETF n -> Begin RegSP := RegSP + n; Exit; End }
Var
 SpVar:String;
Begin
 If Mode32 Then SpVar:='RegESP'
 Else SpVar:='RegSP';
 If AsmL.Op1.OpType<>OT_NONE Then Begin
  { RET n : nettoyage de pile + sortie }
  TranslateRET:='Begin '+SpVar+' := '+SpVar+' + '+
   IntToStr(AsmL.Op1.Imm)+'; Exit; End;'
 End
 Else
  TranslateRET:='Exit;';
End;

Function IsCallRetMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est un appel ou un retour de procedure }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsCallRetMnemonic:=
  (U='CALL')or(U='RET')or(U='RETN')or(U='RETF');
End;

Procedure ProcessCallRetTranslations;
{ Parcourt les lignes source et traduit les instructions CALL et RET
  en appels de procedures et Exit Pascal. Identifie les parametres
  via les PUSH precedant un CALL. Produit des statistiques. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 CallCount,RetCount,RetNCount,CallFarCount:LongInt;
 CallKnownCount,CallUnknownCount,CallStringsCount:LongInt;
 TotalCallRet:LongInt;
 M:String;
 Target:String;
 TargetProc:Integer;
Begin
 CallCount:=0;RetCount:=0;RetNCount:=0;CallFarCount:=0;
 CallKnownCount:=0;CallUnknownCount:=0;CallStringsCount:=0;
 TotalCallRet:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=AsmL.Mnemonic;
  If Not IsCallRetMnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:='';
  If M='CALL' Then Begin
   Code:=TranslateCALL(AsmL,I,ProcIdx);
   Inc(CallCount);
   { Classifier : appel connu ou inconnu }
   Target:=OperandToExpr(AsmL.Op1,ProcIdx);
   TargetProc:=FindProcByName(Target);
   If TargetProc>0 Then
    Inc(CallKnownCount)
   Else
    Inc(CallUnknownCount);
   { Detecter les appels a des fonctions C de chaines -> unite Strings }
   If IsStringsCall(Target) Then Begin
    NeedStrings:=True;
    Inc(CallStringsCount);
   End;
   { Detecter les CALL FAR (operande memoire ou label FAR) }
   If(AsmL.Op1.OpType=OT_MEM)and(AsmL.Op1.SegOverride<>'')Then
    Inc(CallFarCount);
  End
  Else If(M='RET')or(M='RETN')Then Begin
   Code:=TranslateRET(AsmL,ProcIdx);
   Inc(RetCount);
   If AsmL.Op1.OpType<>OT_NONE Then
    Inc(RetNCount);
  End
  Else If M='RETF' Then Begin
   Code:=TranslateRET(AsmL,ProcIdx);
   Inc(RetCount);
   Inc(CallFarCount);
   If AsmL.Op1.OpType<>OT_NONE Then
    Inc(RetNCount);
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalCallRet);
  End;
 End;
 WriteLn('Traduction CALL/RET : ',TotalCallRet,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  CALL             : ',CallCount);
  WriteLn('    proc. connues  : ',CallKnownCount);
  WriteLn('    proc. inconnues: ',CallUnknownCount);
  WriteLn('    Strings unit   : ',CallStringsCount);
  WriteLn('    appels FAR     : ',CallFarCount);
  WriteLn('  RET/RETN/RETF    : ',RetCount);
  WriteLn('    RET n (pile)   : ',RetNCount);
  If TotalCallRet>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalCallRet to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des operations de pile (PUSH/POP) - TODO 16
  ============================================================ }

Function IsPushForCall(PushLine:LongInt):Boolean;
{ Verifie si un PUSH a la ligne PushLine sert de parametre a un
  CALL qui suit. Remonte ou descend pour trouver un CALL.
  Si oui, le PUSH est deja traite par TODO 15 (BuildCallArgs). }
Var
 I:LongInt;
 AsmT:TAsmLine;
 M:String;
Begin
 IsPushForCall:=False;
 { Chercher vers l'avant un CALL precedee uniquement de PUSH }
 I:=PushLine+1;
 While I<SrcLineCount do Begin
  ParseInstructionLine(I,AsmT);
  If AsmT.Mnemonic='' Then Begin Inc(I); Continue; End;
  If AsmT.IsDirective Then Begin Inc(I); Continue; End;
  M:=UpCaseStr(AsmT.Mnemonic);
  If M='PUSH' Then Begin Inc(I); Continue; End;
  If M='CALL' Then Begin IsPushForCall:=True; Exit; End;
  Break;
 End;
End;

Function FindMatchingPop(PushLine:LongInt;RegName:String):LongInt;
{ Cherche un POP du meme registre apres PushLine dans la meme
  procedure. Retourne l'index de la ligne du POP ou -1. }
Var
 I:LongInt;
 AsmT:TAsmLine;
 M,R:String;
 ProcIdx,ProcIdx2:Integer;
 Depth:Integer;
Begin
 FindMatchingPop:=-1;
 ProcIdx:=FindProcForLine(PushLine);
 Depth:=1;
 I:=PushLine+1;
 While I<SrcLineCount do Begin
  { Ne pas chercher au-dela de la procedure courante }
  ProcIdx2:=FindProcForLine(I);
  If(ProcIdx>0)and(ProcIdx2<>ProcIdx)Then Exit;
  ParseInstructionLine(I,AsmT);
  If AsmT.Mnemonic='' Then Begin Inc(I); Continue; End;
  If AsmT.IsDirective Then Begin Inc(I); Continue; End;
  M:=UpCaseStr(AsmT.Mnemonic);
  If M='PUSH' Then Begin
   R:='';
   If AsmT.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
    R:=UpCaseStr(AsmT.Op1.Reg);
   If R=UpCaseStr(RegName) Then Inc(Depth);
  End
  Else If M='POP' Then Begin
   R:='';
   If AsmT.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then
    R:=UpCaseStr(AsmT.Op1.Reg);
   If R=UpCaseStr(RegName) Then Begin
    Dec(Depth);
    If Depth=0 Then Begin
     FindMatchingPop:=I;
     Exit;
    End;
   End;
  End;
  Inc(I);
 End;
End;

Function TranslatePUSH(Var AsmL:TAsmLine;LineIdx:LongInt;
 ProcIdx:Integer):String;
{ PUSH reg -> SaveXX := RegXX (si PUSH/POP paire detectee)
  PUSH reg -> Dec(RegSP, 2); MemW[RegSS:RegSP] := RegXX (sinon)
  PUSH mem -> Dec(RegSP, N); Mem[RegSS:RegSP] := expr
  PUSH imm -> Dec(RegSP, 2); MemW[RegSS:RegSP] := value }
Var
 Expr,RegName,SpVar,SaveVar:String;
 OpSize:Integer;
 PopLine:LongInt;
Begin
 TranslatePUSH:='';
 If Mode32 Then SpVar:='RegESP'
 Else SpVar:='RegSP';
 Expr:=OperandToExpr(AsmL.Op1,ProcIdx);
 { Determiner la taille de l'operande }
 If AsmL.Op1.OpType=OT_REG32 Then OpSize:=4
 Else If AsmL.Op1.OpType=OT_REG16 Then OpSize:=2
 Else If AsmL.Op1.OpType=OT_REG8 Then OpSize:=1
 Else If Mode32 Then OpSize:=4
 Else OpSize:=2;
 { Verifier si c'est un PUSH qui alimente un CALL }
 If IsPushForCall(LineIdx) Then Begin
  { Deja traite par TODO 15 : marquer comme commentaire }
  TranslatePUSH:='{ PUSH '+Expr+' -> param CALL }';
  Exit;
 End;
 { Verifier si c'est une paire PUSH/POP de sauvegarde }
 If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
  RegName:=UpCaseStr(AsmL.Op1.Reg);
  PopLine:=FindMatchingPop(LineIdx,RegName);
  If PopLine>=0 Then Begin
   { Paire PUSH/POP detectee : utiliser une variable temporaire }
   SaveVar:='Save'+RegToPascalVar(RegName);
   TranslatePUSH:=SaveVar+' := '+Expr+';';
   Exit;
  End;
 End;
 { Pas de paire : simuler la pile }
 TranslatePUSH:='Begin Dec('+SpVar+', '+IntToStr(OpSize)+
  '); Mem['+SpVar+'] := '+Expr+'; End;';
End;

Function TranslatePOP(Var AsmL:TAsmLine;LineIdx:LongInt;
 ProcIdx:Integer):String;
{ POP reg -> RegXX := SaveXX (si PUSH/POP paire detectee)
  POP reg -> RegXX := Mem[RegSS:RegSP]; Inc(RegSP, 2) (sinon)
  POP mem -> expr := Mem[RegSS:RegSP]; Inc(RegSP, N) }
Var
 Expr,RegName,SpVar,SaveVar:String;
 OpSize:Integer;
 I:LongInt;
 AsmT:TAsmLine;
 M,R:String;
 Found:Boolean;
 ProcIdx2:Integer;
Begin
 TranslatePOP:='';
 If Mode32 Then SpVar:='RegESP'
 Else SpVar:='RegSP';
 Expr:=OperandToExpr(AsmL.Op1,ProcIdx);
 If AsmL.Op1.OpType=OT_REG32 Then OpSize:=4
 Else If AsmL.Op1.OpType=OT_REG16 Then OpSize:=2
 Else If AsmL.Op1.OpType=OT_REG8 Then OpSize:=1
 Else If Mode32 Then OpSize:=4
 Else OpSize:=2;
 { Verifier si un PUSH correspondant existe avant }
 If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
  RegName:=UpCaseStr(AsmL.Op1.Reg);
  Found:=False;
  I:=LineIdx-1;
  While I>=0 do Begin
   ProcIdx2:=FindProcForLine(I);
   If(ProcIdx>0)and(ProcIdx2<>ProcIdx)Then Break;
   ParseInstructionLine(I,AsmT);
   If AsmT.Mnemonic='' Then Begin Dec(I); Continue; End;
   If AsmT.IsDirective Then Begin Dec(I); Continue; End;
   M:=UpCaseStr(AsmT.Mnemonic);
   If M='PUSH' Then Begin
    If AsmT.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
     R:=UpCaseStr(AsmT.Op1.Reg);
     If R=RegName Then Begin
      { Verifier que ce PUSH a ce POP comme match }
      If FindMatchingPop(I,R)=LineIdx Then Begin
       Found:=True;
       Break;
      End;
     End;
    End;
   End;
   Dec(I);
  End;
  If Found Then Begin
   SaveVar:='Save'+RegToPascalVar(RegName);
   TranslatePOP:=Expr+' := '+SaveVar+';';
   Exit;
  End;
 End;
 { Pas de paire : simuler la pile }
 TranslatePOP:='Begin '+Expr+' := Mem['+SpVar+']; Inc('+
  SpVar+', '+IntToStr(OpSize)+'); End;';
End;

Function TranslatePUSHA(Var AsmL:TAsmLine):String;
{ PUSHA -> sauvegarder AX, CX, DX, BX, SP, BP, SI, DI
  PUSHAD -> sauvegarder EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI }
Var
 M:String;
Begin
 M:=UpCaseStr(AsmL.Mnemonic);
 If(M='PUSHAD')or(Mode32)Then
  TranslatePUSHA:='Begin SaveEAX := RegEAX; SaveECX := RegECX; '+
   'SaveEDX := RegEDX; SaveEBX := RegEBX; SaveESP := RegESP; '+
   'SaveEBP := RegEBP; SaveESI := RegESI; SaveEDI := RegEDI; End;'
 Else
  TranslatePUSHA:='Begin SaveAX := RegAX; SaveCX := RegCX; '+
   'SaveDX := RegDX; SaveBX := RegBX; SaveSP := RegSP; '+
   'SaveBP := RegBP; SaveSI := RegSI; SaveDI := RegDI; End;';
End;

Function TranslatePOPA(Var AsmL:TAsmLine):String;
{ POPA -> restaurer DI, SI, BP, (SP ignore), BX, DX, CX, AX
  POPAD -> restaurer EDI, ESI, EBP, (ESP ignore), EBX, EDX, ECX, EAX }
Var
 M:String;
Begin
 M:=UpCaseStr(AsmL.Mnemonic);
 If(M='POPAD')or(Mode32)Then
  TranslatePOPA:='Begin RegEDI := SaveEDI; RegESI := SaveESI; '+
   'RegEBP := SaveEBP; RegEBX := SaveEBX; '+
   'RegEDX := SaveEDX; RegECX := SaveECX; RegEAX := SaveEAX; End;'
 Else
  TranslatePOPA:='Begin RegDI := SaveDI; RegSI := SaveSI; '+
   'RegBP := SaveBP; RegBX := SaveBX; '+
   'RegDX := SaveDX; RegCX := SaveCX; RegAX := SaveAX; End;';
End;

Function TranslatePUSHF(Var AsmL:TAsmLine):String;
{ PUSHF -> sauvegarder tous les flags dans une variable }
Begin
 If Mode32 Or(UpCaseStr(AsmL.Mnemonic)='PUSHFD')Then
  TranslatePUSHF:='Begin SaveFlagCF := FlagCF; SaveFlagZF := FlagZF; '+
   'SaveFlagSF := FlagSF; SaveFlagOF := FlagOF; '+
   'SaveFlagDF := FlagDF; SaveFlagPF := FlagPF; '+
   'SaveFlagAF := FlagAF; End;'
 Else
  TranslatePUSHF:='Begin SaveFlagCF := FlagCF; SaveFlagZF := FlagZF; '+
   'SaveFlagSF := FlagSF; SaveFlagOF := FlagOF; '+
   'SaveFlagDF := FlagDF; SaveFlagPF := FlagPF; '+
   'SaveFlagAF := FlagAF; End;';
End;

Function TranslatePOPF(Var AsmL:TAsmLine):String;
{ POPF -> restaurer tous les flags depuis la variable }
Begin
 If Mode32 Or(UpCaseStr(AsmL.Mnemonic)='POPFD')Then
  TranslatePOPF:='Begin FlagCF := SaveFlagCF; FlagZF := SaveFlagZF; '+
   'FlagSF := SaveFlagSF; FlagOF := SaveFlagOF; '+
   'FlagDF := SaveFlagDF; FlagPF := SaveFlagPF; '+
   'FlagAF := SaveFlagAF; End;'
 Else
  TranslatePOPF:='Begin FlagCF := SaveFlagCF; FlagZF := SaveFlagZF; '+
   'FlagSF := SaveFlagSF; FlagOF := SaveFlagOF; '+
   'FlagDF := SaveFlagDF; FlagPF := SaveFlagPF; '+
   'FlagAF := SaveFlagAF; End;';
End;

Function IsPushPopMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une operation de pile }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsPushPopMnemonic:=
  (U='PUSH')or(U='POP')or
  (U='PUSHA')or(U='PUSHAD')or
  (U='POPA')or(U='POPAD')or
  (U='PUSHF')or(U='PUSHFD')or
  (U='POPF')or(U='POPFD');
End;

Procedure ProcessPushPopTranslations;
{ Parcourt les lignes source et traduit les instructions PUSH et POP
  en operations Pascal equivalentes. Detecte les paires de
  sauvegarde/restauration de registres et les convertit en
  variables temporaires. Produit des statistiques. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 M:String;
 PushCount,PopCount:LongInt;
 PushaCount,PopaCount:LongInt;
 PushfCount,PopfCount:LongInt;
 PushCallCount,PushSaveCount,PushStackCount:LongInt;
 PopRestoreCount,PopStackCount:LongInt;
 TotalPushPop:LongInt;
Begin
 PushCount:=0;PopCount:=0;
 PushaCount:=0;PopaCount:=0;
 PushfCount:=0;PopfCount:=0;
 PushCallCount:=0;PushSaveCount:=0;PushStackCount:=0;
 PopRestoreCount:=0;PopStackCount:=0;
 TotalPushPop:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=UpCaseStr(AsmL.Mnemonic);
  If Not IsPushPopMnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:='';
  If M='PUSH' Then Begin
   Code:=TranslatePUSH(AsmL,I,ProcIdx);
   Inc(PushCount);
   { Classifier le PUSH }
   If IsPushForCall(I) Then
    Inc(PushCallCount)
   Else If Pos('Save',Code)=1 Then
    Inc(PushSaveCount)
   Else
    Inc(PushStackCount);
  End
  Else If M='POP' Then Begin
   Code:=TranslatePOP(AsmL,I,ProcIdx);
   Inc(PopCount);
   { Classifier le POP }
   If Pos('Save',Code)>0 Then
    Inc(PopRestoreCount)
   Else
    Inc(PopStackCount);
  End
  Else If(M='PUSHA')or(M='PUSHAD')Then Begin
   Code:=TranslatePUSHA(AsmL);
   Inc(PushaCount);
  End
  Else If(M='POPA')or(M='POPAD')Then Begin
   Code:=TranslatePOPA(AsmL);
   Inc(PopaCount);
  End
  Else If(M='PUSHF')or(M='PUSHFD')Then Begin
   Code:=TranslatePUSHF(AsmL);
   Inc(PushfCount);
  End
  Else If(M='POPF')or(M='POPFD')Then Begin
   Code:=TranslatePOPF(AsmL);
   Inc(PopfCount);
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalPushPop);
  End;
 End;
 WriteLn('Traduction PUSH/POP : ',TotalPushPop,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  PUSH             : ',PushCount);
  WriteLn('    param. CALL    : ',PushCallCount);
  WriteLn('    sauvegarde reg : ',PushSaveCount);
  WriteLn('    pile simulee   : ',PushStackCount);
  WriteLn('  POP              : ',PopCount);
  WriteLn('    restaur. reg   : ',PopRestoreCount);
  WriteLn('    pile simulee   : ',PopStackCount);
  WriteLn('  PUSHA/PUSHAD     : ',PushaCount);
  WriteLn('  POPA/POPAD       : ',PopaCount);
  WriteLn('  PUSHF/PUSHFD     : ',PushfCount);
  WriteLn('  POPF/POPFD       : ',PopfCount);
  If TotalPushPop>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalPushPop to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des instructions de chaine - TODO 17
  ============================================================ }

Function IsRepPrefix(M:String):Boolean;
{ Verifie si un mnemonique est un prefixe de repetition }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsRepPrefix:=(U='REP')or(U='REPE')or(U='REPZ')or
  (U='REPNE')or(U='REPNZ');
End;

Function IsStringOpMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une operation de chaine pure
  (sans les prefixes REP) }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsStringOpMnemonic:=(U='MOVSB')or(U='MOVSW')or(U='MOVSD')or
  (U='CMPSB')or(U='CMPSW')or(U='CMPSD')or
  (U='LODSB')or(U='LODSW')or(U='LODSD')or
  (U='STOSB')or(U='STOSW')or(U='STOSD')or
  (U='SCASB')or(U='SCASW')or(U='SCASD');
End;

Function ExtractStringOp(LineIdx:LongInt):String;
{ Extraire l'instruction de chaine d'une ligne avec prefixe REP.
  Cherche dans le texte source un mnemonique de chaine. }
Var
 Line:String;
Begin
 ExtractStringOp:='';
 Line:=UpCaseStr(SrcLines[LineIdx]^);
 If Pos('MOVSD',Line)>0 Then Begin ExtractStringOp:='MOVSD'; Exit End;
 If Pos('MOVSW',Line)>0 Then Begin ExtractStringOp:='MOVSW'; Exit End;
 If Pos('MOVSB',Line)>0 Then Begin ExtractStringOp:='MOVSB'; Exit End;
 If Pos('CMPSD',Line)>0 Then Begin ExtractStringOp:='CMPSD'; Exit End;
 If Pos('CMPSW',Line)>0 Then Begin ExtractStringOp:='CMPSW'; Exit End;
 If Pos('CMPSB',Line)>0 Then Begin ExtractStringOp:='CMPSB'; Exit End;
 If Pos('LODSD',Line)>0 Then Begin ExtractStringOp:='LODSD'; Exit End;
 If Pos('LODSW',Line)>0 Then Begin ExtractStringOp:='LODSW'; Exit End;
 If Pos('LODSB',Line)>0 Then Begin ExtractStringOp:='LODSB'; Exit End;
 If Pos('STOSD',Line)>0 Then Begin ExtractStringOp:='STOSD'; Exit End;
 If Pos('STOSW',Line)>0 Then Begin ExtractStringOp:='STOSW'; Exit End;
 If Pos('STOSB',Line)>0 Then Begin ExtractStringOp:='STOSB'; Exit End;
 If Pos('SCASD',Line)>0 Then Begin ExtractStringOp:='SCASD'; Exit End;
 If Pos('SCASW',Line)>0 Then Begin ExtractStringOp:='SCASW'; Exit End;
 If Pos('SCASB',Line)>0 Then Begin ExtractStringOp:='SCASB'; Exit End;
End;

Function StringOpStep(StringOp:String):String;
{ Retourne le pas d'incrementation selon le suffixe B/W/D }
Begin
 If StringOp[Length(StringOp)]='B' Then StringOpStep:='1'
 Else If StringOp[Length(StringOp)]='W' Then StringOpStep:='2'
 Else StringOpStep:='4';
End;

Function StringOpMemPfx(StringOp:String):String;
{ Retourne Mem/MemW/MemL selon la taille de l'operation }
Begin
 If StringOp[Length(StringOp)]='B' Then StringOpMemPfx:='Mem'
 Else If StringOp[Length(StringOp)]='W' Then StringOpMemPfx:='MemW'
 Else StringOpMemPfx:='MemL';
End;

Function StringOpAccum(StringOp:String):String;
{ Retourne l'expression de l'accumulateur selon la taille }
Begin
 If StringOp[Length(StringOp)]='B' Then StringOpAccum:='Lo(RegAX)'
 Else If StringOp[Length(StringOp)]='W' Then StringOpAccum:='RegAX'
 Else StringOpAccum:='RegEAX';
End;

Function TranslateMOVS(StringOp,RepType:String):String;
{ MOVSx -> copie memoire [SI]->[DI] avec ajustement SI/DI.
  REP MOVSx -> Move(Mem[SI], Mem[DI], CX * step). }
Var
 SiVar,DiVar,CxVar,Step,MP:String;
Begin
 If Mode32 Then Begin
  SiVar:='RegESI'; DiVar:='RegEDI'; CxVar:='RegECX'
 End Else Begin
  SiVar:='RegSI'; DiVar:='RegDI'; CxVar:='RegCX'
 End;
 Step:=StringOpStep(StringOp);
 MP:=StringOpMemPfx(StringOp);
 If RepType<>'' Then Begin
  If Step='1' Then
   TranslateMOVS:='Begin Move('+MP+'['+SiVar+'], '+MP+'['+
    DiVar+'], '+CxVar+'); Inc('+SiVar+', '+CxVar+'); Inc('+
    DiVar+', '+CxVar+'); '+CxVar+' := 0; End;'
  Else
   TranslateMOVS:='Begin Move('+MP+'['+SiVar+'], '+MP+'['+
    DiVar+'], '+CxVar+' * '+Step+'); Inc('+SiVar+', '+CxVar+
    ' * '+Step+'); Inc('+DiVar+', '+CxVar+' * '+Step+'); '+
    CxVar+' := 0; End;';
 End
 Else Begin
  If Step='1' Then
   TranslateMOVS:='Begin '+MP+'['+DiVar+'] := '+MP+'['+SiVar+
    ']; If Not FlagDF Then Begin Inc('+SiVar+'); Inc('+DiVar+
    ') End Else Begin Dec('+SiVar+'); Dec('+DiVar+') End End'
  Else
   TranslateMOVS:='Begin '+MP+'['+DiVar+'] := '+MP+'['+SiVar+
    ']; If Not FlagDF Then Begin Inc('+SiVar+', '+Step+
    '); Inc('+DiVar+', '+Step+') End Else Begin Dec('+SiVar+
    ', '+Step+'); Dec('+DiVar+', '+Step+') End End';
 End;
End;

Function TranslateLODS(StringOp,RepType:String):String;
{ LODSx -> accumulateur := Mem[SI]; ajuster SI.
  REP LODSx -> boucle (rare mais valide). }
Var
 SiVar,CxVar,Step,MP,Acc:String;
Begin
 If Mode32 Then Begin SiVar:='RegESI'; CxVar:='RegECX' End
 Else Begin SiVar:='RegSI'; CxVar:='RegCX' End;
 Step:=StringOpStep(StringOp);
 MP:=StringOpMemPfx(StringOp);
 Acc:=StringOpAccum(StringOp);
 If RepType<>'' Then
  TranslateLODS:='Begin While '+CxVar+' > 0 do Begin '+Acc+
   ' := '+MP+'['+SiVar+']; If Not FlagDF Then Inc('+SiVar+
   ', '+Step+') Else Dec('+SiVar+', '+Step+'); Dec('+
   CxVar+') End End'
 Else Begin
  If Step='1' Then
   TranslateLODS:='Begin '+Acc+' := '+MP+'['+SiVar+
    ']; If Not FlagDF Then Inc('+SiVar+') Else Dec('+
    SiVar+') End'
  Else
   TranslateLODS:='Begin '+Acc+' := '+MP+'['+SiVar+
    ']; If Not FlagDF Then Inc('+SiVar+', '+Step+
    ') Else Dec('+SiVar+', '+Step+') End';
 End;
End;

Function TranslateSTOS(StringOp,RepType:String):String;
{ STOSx -> Mem[DI] := accumulateur; ajuster DI.
  REP STOSx -> FillChar/FillWord/FillDWord. }
Var
 DiVar,CxVar,Step,MP,Acc:String;
Begin
 If Mode32 Then Begin DiVar:='RegEDI'; CxVar:='RegECX' End
 Else Begin DiVar:='RegDI'; CxVar:='RegCX' End;
 Step:=StringOpStep(StringOp);
 MP:=StringOpMemPfx(StringOp);
 Acc:=StringOpAccum(StringOp);
 If RepType<>'' Then Begin
  If StringOp='STOSB' Then
   TranslateSTOS:='Begin FillChar('+MP+'['+DiVar+'], '+CxVar+
    ', '+Acc+'); Inc('+DiVar+', '+CxVar+'); '+CxVar+' := 0; End;'
  Else If StringOp='STOSW' Then
   TranslateSTOS:='Begin FillWord('+MP+'['+DiVar+'], '+CxVar+
    ', '+Acc+'); Inc('+DiVar+', '+CxVar+' * 2); '+
    CxVar+' := 0; End;'
  Else
   TranslateSTOS:='Begin FillDWord('+MP+'['+DiVar+'], '+CxVar+
    ', '+Acc+'); Inc('+DiVar+', '+CxVar+' * 4); '+
    CxVar+' := 0; End;';
 End
 Else Begin
  If Step='1' Then
   TranslateSTOS:='Begin '+MP+'['+DiVar+'] := '+Acc+
    '; If Not FlagDF Then Inc('+DiVar+') Else Dec('+
    DiVar+') End'
  Else
   TranslateSTOS:='Begin '+MP+'['+DiVar+'] := '+Acc+
    '; If Not FlagDF Then Inc('+DiVar+', '+Step+
    ') Else Dec('+DiVar+', '+Step+') End';
 End;
End;

Function TranslateCMPS(StringOp,RepType:String):String;
{ CMPSx -> comparer Mem[SI] avec Mem[DI], positionner flags.
  REPE CMPSx -> repeter tant que egal (trouver 1er different).
  REPNE CMPSx -> repeter tant que different (trouver 1er egal). }
Var
 SiVar,DiVar,CxVar,Step,MP:String;
Begin
 If Mode32 Then Begin
  SiVar:='RegESI'; DiVar:='RegEDI'; CxVar:='RegECX'
 End Else Begin
  SiVar:='RegSI'; DiVar:='RegDI'; CxVar:='RegCX'
 End;
 Step:=StringOpStep(StringOp);
 MP:=StringOpMemPfx(StringOp);
 If(RepType='REPE')or(RepType='REPZ')Then Begin
  If Step='1' Then
   TranslateCMPS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+MP+'['+SiVar+'] = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Begin Inc('+SiVar+'); Inc('+
    DiVar+') End Else Begin Dec('+SiVar+'); Dec('+DiVar+
    ') End; Dec('+CxVar+'); If Not FlagZF Then Break End End'
  Else
   TranslateCMPS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+MP+'['+SiVar+'] = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Begin Inc('+SiVar+', '+Step+
    '); Inc('+DiVar+', '+Step+') End Else Begin Dec('+
    SiVar+', '+Step+'); Dec('+DiVar+', '+Step+
    ') End; Dec('+CxVar+'); If Not FlagZF Then Break End End';
 End
 Else If(RepType='REPNE')or(RepType='REPNZ')Then Begin
  If Step='1' Then
   TranslateCMPS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+MP+'['+SiVar+'] = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Begin Inc('+SiVar+'); Inc('+
    DiVar+') End Else Begin Dec('+SiVar+'); Dec('+DiVar+
    ') End; Dec('+CxVar+'); If FlagZF Then Break End End'
  Else
   TranslateCMPS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+MP+'['+SiVar+'] = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Begin Inc('+SiVar+', '+Step+
    '); Inc('+DiVar+', '+Step+') End Else Begin Dec('+
    SiVar+', '+Step+'); Dec('+DiVar+', '+Step+
    ') End; Dec('+CxVar+'); If FlagZF Then Break End End';
 End
 Else Begin
  If Step='1' Then
   TranslateCMPS:='Begin FlagZF := ('+MP+'['+SiVar+'] = '+
    MP+'['+DiVar+']); FlagCF := ('+MP+'['+SiVar+'] < '+
    MP+'['+DiVar+']); If Not FlagDF Then Begin Inc('+SiVar+
    '); Inc('+DiVar+') End Else Begin Dec('+SiVar+
    '); Dec('+DiVar+') End End'
  Else
   TranslateCMPS:='Begin FlagZF := ('+MP+'['+SiVar+'] = '+
    MP+'['+DiVar+']); FlagCF := ('+MP+'['+SiVar+'] < '+
    MP+'['+DiVar+']); If Not FlagDF Then Begin Inc('+SiVar+
    ', '+Step+'); Inc('+DiVar+', '+Step+') End Else Begin Dec('+
    SiVar+', '+Step+'); Dec('+DiVar+', '+Step+') End End';
 End;
End;

Function TranslateSCAS(StringOp,RepType:String):String;
{ SCASx -> comparer accumulateur avec Mem[DI], positionner flags.
  REPE SCASx -> repeter tant que egal (chercher 1er different).
  REPNE SCASx -> repeter tant que different (chercher 1er egal). }
Var
 DiVar,CxVar,Step,MP,Acc:String;
Begin
 If Mode32 Then Begin DiVar:='RegEDI'; CxVar:='RegECX' End
 Else Begin DiVar:='RegDI'; CxVar:='RegCX' End;
 Step:=StringOpStep(StringOp);
 MP:=StringOpMemPfx(StringOp);
 Acc:=StringOpAccum(StringOp);
 If(RepType='REPE')or(RepType='REPZ')Then Begin
  If Step='1' Then
   TranslateSCAS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+Acc+' = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Inc('+DiVar+') Else Dec('+
    DiVar+'); Dec('+CxVar+'); If Not FlagZF Then Break End End'
  Else
   TranslateSCAS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+Acc+' = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Inc('+DiVar+', '+Step+
    ') Else Dec('+DiVar+', '+Step+'); Dec('+CxVar+
    '); If Not FlagZF Then Break End End';
 End
 Else If(RepType='REPNE')or(RepType='REPNZ')Then Begin
  If Step='1' Then
   TranslateSCAS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+Acc+' = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Inc('+DiVar+') Else Dec('+
    DiVar+'); Dec('+CxVar+'); If FlagZF Then Break End End'
  Else
   TranslateSCAS:='Begin While '+CxVar+' > 0 do Begin '+
    'FlagZF := ('+Acc+' = '+MP+'['+DiVar+
    ']); If Not FlagDF Then Inc('+DiVar+', '+Step+
    ') Else Dec('+DiVar+', '+Step+'); Dec('+CxVar+
    '); If FlagZF Then Break End End';
 End
 Else Begin
  If Step='1' Then
   TranslateSCAS:='Begin FlagZF := ('+Acc+' = '+MP+'['+DiVar+
    ']); FlagCF := ('+Acc+' < '+MP+'['+DiVar+
    ']); If Not FlagDF Then Inc('+DiVar+') Else Dec('+
    DiVar+') End'
  Else
   TranslateSCAS:='Begin FlagZF := ('+Acc+' = '+MP+'['+DiVar+
    ']); FlagCF := ('+Acc+' < '+MP+'['+DiVar+
    ']); If Not FlagDF Then Inc('+DiVar+', '+Step+
    ') Else Dec('+DiVar+', '+Step+') End';
 End;
End;

Procedure ProcessStringTranslations;
{ Parcourt les lignes source et traduit les instructions de chaine
  (MOVS, CMPS, LODS, STOS, SCAS) avec ou sans prefixe REP/REPE/REPNE
  en operations Pascal equivalentes. Produit des statistiques. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 Code:String;
 M,StringOp,RepType:String;
 MovsCount,CmpsCount,LodsCount,StosCount,ScasCount:LongInt;
 RepMovsCount,RepStosCount,RepLodsCount:LongInt;
 RepeCmpsCount,RepneCmpsCount:LongInt;
 RepeScasCount,RepneScasCount:LongInt;
 TotalString:LongInt;
Begin
 MovsCount:=0;CmpsCount:=0;LodsCount:=0;StosCount:=0;ScasCount:=0;
 RepMovsCount:=0;RepStosCount:=0;RepLodsCount:=0;
 RepeCmpsCount:=0;RepneCmpsCount:=0;
 RepeScasCount:=0;RepneScasCount:=0;
 TotalString:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=UpCaseStr(AsmL.Mnemonic);
  Code:='';
  RepType:='';
  StringOp:='';
  If IsStringOpMnemonic(M) Then
   StringOp:=M
  Else If IsRepPrefix(M) Then Begin
   RepType:=M;
   StringOp:=ExtractStringOp(I);
   If StringOp='' Then Continue;
  End
  Else Continue;
  If Copy(StringOp,1,4)='MOVS' Then Begin
   Code:=TranslateMOVS(StringOp,RepType);
   If RepType<>'' Then Inc(RepMovsCount)
   Else Inc(MovsCount);
  End
  Else If Copy(StringOp,1,4)='CMPS' Then Begin
   Code:=TranslateCMPS(StringOp,RepType);
   If(RepType='REPE')or(RepType='REPZ')Then Inc(RepeCmpsCount)
   Else If(RepType='REPNE')or(RepType='REPNZ')Then
    Inc(RepneCmpsCount)
   Else Inc(CmpsCount);
  End
  Else If Copy(StringOp,1,4)='LODS' Then Begin
   Code:=TranslateLODS(StringOp,RepType);
   If RepType<>'' Then Inc(RepLodsCount)
   Else Inc(LodsCount);
  End
  Else If Copy(StringOp,1,4)='STOS' Then Begin
   Code:=TranslateSTOS(StringOp,RepType);
   If RepType<>'' Then Inc(RepStosCount)
   Else Inc(StosCount);
  End
  Else If Copy(StringOp,1,4)='SCAS' Then Begin
   Code:=TranslateSCAS(StringOp,RepType);
   If(RepType='REPE')or(RepType='REPZ')Then Inc(RepeScasCount)
   Else If(RepType='REPNE')or(RepType='REPNZ')Then
    Inc(RepneScasCount)
   Else Inc(ScasCount);
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalString);
  End;
 End;
 WriteLn('Traduction chaines : ',TotalString,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  MOVS (sans REP)  : ',MovsCount);
  WriteLn('  REP MOVS         : ',RepMovsCount);
  WriteLn('  LODS (sans REP)  : ',LodsCount);
  WriteLn('  REP LODS         : ',RepLodsCount);
  WriteLn('  STOS (sans REP)  : ',StosCount);
  WriteLn('  REP STOS         : ',RepStosCount);
  WriteLn('  CMPS (sans REP)  : ',CmpsCount);
  WriteLn('  REPE CMPS        : ',RepeCmpsCount);
  WriteLn('  REPNE CMPS       : ',RepneCmpsCount);
  WriteLn('  SCAS (sans REP)  : ',ScasCount);
  WriteLn('  REPE SCAS        : ',RepeScasCount);
  WriteLn('  REPNE SCAS       : ',RepneScasCount);
  If TotalString>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalString to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des appels systeme (INT) - TODO 18
  ============================================================ }

Function IsIntMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une interruption logicielle }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsIntMnemonic:=(U='INT')or(U='INTO');
End;

Function FindPrevMovAH(LineIdx:LongInt):LongInt;
{ Recherche en arriere la derniere instruction MOV AH, imm
  avant la ligne LineIdx (dans une fenetre de 10 lignes).
  Retourne la valeur immediate chargee dans AH, ou -1 si non trouve. }
Var
 J:LongInt;
 AsmT:TAsmLine;
 MJ:String;
Begin
 FindPrevMovAH:=-1;
 For J:=LineIdx-1 downto 0 do Begin
  If LineIdx-J>10 Then Break;
  ParseInstructionLine(J,AsmT);
  If AsmT.Mnemonic='' Then Continue;
  MJ:=UpCaseStr(AsmT.Mnemonic);
  If(MJ='MOV')and(AsmT.Op1.OpType=OT_REG8)and
   (UpCaseStr(AsmT.Op1.Reg)='AH')and
   (AsmT.Op2.OpType=OT_IMM8)Then Begin
   FindPrevMovAH:=AsmT.Op2.Imm;
   Exit;
  End;
  { MOV AX, imm16 -> AH = Hi(imm16) }
  If(MJ='MOV')and(AsmT.Op1.OpType=OT_REG16)and
   (UpCaseStr(AsmT.Op1.Reg)='AX')and
   (AsmT.Op2.OpType=OT_IMM16)Then Begin
   FindPrevMovAH:=(AsmT.Op2.Imm shr 8) and $FF;
   Exit;
  End;
  { Si on rencontre un label ou un INT, on arrete }
  If AsmT.LabelStr<>'' Then Break;
  If MJ='INT' Then Break;
 End;
End;

Function FindPrevMovAL(LineIdx:LongInt):LongInt;
{ Recherche en arriere la derniere instruction MOV AL, imm
  avant la ligne LineIdx (dans une fenetre de 10 lignes).
  Retourne la valeur immediate chargee dans AL, ou -1 si non trouve. }
Var
 J:LongInt;
 AsmT:TAsmLine;
 MJ:String;
Begin
 FindPrevMovAL:=-1;
 For J:=LineIdx-1 downto 0 do Begin
  If LineIdx-J>10 Then Break;
  ParseInstructionLine(J,AsmT);
  If AsmT.Mnemonic='' Then Continue;
  MJ:=UpCaseStr(AsmT.Mnemonic);
  If(MJ='MOV')and(AsmT.Op1.OpType=OT_REG8)and
   (UpCaseStr(AsmT.Op1.Reg)='AL')and
   (AsmT.Op2.OpType=OT_IMM8)Then Begin
   FindPrevMovAL:=AsmT.Op2.Imm;
   Exit;
  End;
  { MOV AX, imm16 -> AL = Lo(imm16) }
  If(MJ='MOV')and(AsmT.Op1.OpType=OT_REG16)and
   (UpCaseStr(AsmT.Op1.Reg)='AX')and
   (AsmT.Op2.OpType=OT_IMM16)Then Begin
   FindPrevMovAL:=AsmT.Op2.Imm and $FF;
   Exit;
  End;
  If AsmT.LabelStr<>'' Then Break;
  If MJ='INT' Then Break;
 End;
End;

Function FindPrevDXLabel(LineIdx:LongInt):String;
{ Recherche en arriere un LEA DX, label ou MOV DX, OFFSET label
  avant la ligne LineIdx (dans une fenetre de 10 lignes).
  Retourne le nom du label, ou '' si non trouve. }
Var
 J:LongInt;
 AsmT:TAsmLine;
 MJ:String;
Begin
 FindPrevDXLabel:='';
 For J:=LineIdx-1 downto 0 do Begin
  If LineIdx-J>10 Then Break;
  ParseInstructionLine(J,AsmT);
  If AsmT.Mnemonic='' Then Continue;
  MJ:=UpCaseStr(AsmT.Mnemonic);
  { LEA DX, label }
  If(MJ='LEA')and(AsmT.Op1.OpType=OT_REG16)and
   (UpCaseStr(AsmT.Op1.Reg)='DX')and
   (AsmT.Op2.LabelName<>'')Then Begin
   FindPrevDXLabel:=AsmT.Op2.LabelName;
   Exit;
  End;
  { MOV DX, OFFSET label }
  If(MJ='MOV')and(AsmT.Op1.OpType=OT_REG16)and
   (UpCaseStr(AsmT.Op1.Reg)='DX')and
   (AsmT.Op2.OpType=OT_OFFSET)and
   (AsmT.Op2.LabelName<>'')Then Begin
   FindPrevDXLabel:=AsmT.Op2.LabelName;
   Exit;
  End;
  { MOV DX, label (reference directe) }
  If(MJ='MOV')and(AsmT.Op1.OpType=OT_REG16)and
   (UpCaseStr(AsmT.Op1.Reg)='DX')and
   (AsmT.Op2.OpType=OT_LABEL)and
   (AsmT.Op2.LabelName<>'')Then Begin
   FindPrevDXLabel:=AsmT.Op2.LabelName;
   Exit;
  End;
  If AsmT.LabelStr<>'' Then Break;
  If MJ='INT' Then Break;
 End;
End;

Function FindDataVarByName(Name:String):Integer;
{ Recherche une variable de donnees par nom (case-insensitive).
  Retourne l'index dans DataVars, ou 0 si non trouvee. }
Var
 I:Integer;
 U:String;
Begin
 U:=UpCaseStr(Name);
 FindDataVarByName:=0;
 For I:=1 to DataVarCount do
  If UpCaseStr(DataVars[I].Name)=U Then Begin
   FindDataVarByName:=I;
   Exit;
  End;
End;

Function GetDataVarString(VarIdx:Integer):String;
{ Extrait le contenu texte d'une variable DB.
  Concatene tous les elements DE_STRING, supprime le '$' terminal
  si present (convention DOS pour INT 21h/AH=09). }
Var
 I:Integer;
 S:String;
Begin
 S:='';
 If(VarIdx<1)or(VarIdx>DataVarCount)Then Begin
  GetDataVarString:='';
  Exit;
 End;
 If DataVars[VarIdx].DirType<>DT_DB Then Begin
  GetDataVarString:='';
  Exit;
 End;
 For I:=1 to DataVars[VarIdx].ElemCount do
  If DataVars[VarIdx].Elements[I].ElemType=DE_STRING Then
   S:=S+DataVars[VarIdx].Elements[I].StrValue;
 { Supprimer le '$' terminal (terminateur DOS) }
 If(Length(S)>0)and(S[Length(S)]='$')Then
  Delete(S,Length(S),1);
 { Supprimer les CR/LF terminaux si presents }
 While(Length(S)>0)and(S[Length(S)] in [#13,#10])do
  Delete(S,Length(S),1);
 GetDataVarString:=S;
End;

Function TranslateINT21h(FuncAH,FuncAL,LineIdx:LongInt):String;
{ Traduit les fonctions DOS INT 21h en equivalents Pascal.
  AH=01h -> ReadKey (lecture caractere clavier, echo)
  AH=02h -> Write(Chr(RegDL)) (afficher caractere)
  AH=06h -> Read/Write direct console
  AH=07h -> ReadKey sans echo (pas d'echo, pas de Ctrl-C)
  AH=08h -> ReadKey sans echo (pas d'echo)
  AH=09h -> Write(chaine terminee par $)
  AH=0Ah -> ReadLn (lecture tampon)
  AH=25h -> SetIntVec
  AH=2Ah -> GetDate
  AH=2Ch -> GetTime
  AH=2Eh -> SetVerify (Dos/WinDOS)
  AH=30h -> Lo(DosVersion)/Hi(DosVersion)
  AH=33h -> GetCBreak/SetCBreak (Dos/WinDOS)
  AH=35h -> GetIntVec
  AH=36h -> DiskFree/DiskSize (Dos/WinDOS)
  AH=39h -> CreateDir (WinDOS, creer repertoire)
  AH=3Ah -> RemoveDir (WinDOS, supprimer repertoire)
  AH=3Bh -> SetCurDir (WinDOS, changer repertoire)
  AH=3Ch -> Rewrite (creer fichier)
  AH=3Dh -> Reset (ouvrir fichier)
  AH=3Eh -> Close (fermer fichier)
  AH=3Fh -> BlockRead (lire fichier)
  AH=40h -> BlockWrite (ecrire fichier)
  AH=41h -> Erase (supprimer fichier)
  AH=43h -> GetFAttr/SetFAttr
  AH=4Ch -> Halt (terminer programme)
  AH=54h -> GetVerify (Dos/WinDOS)
  Autres -> Intr($21, Regs) }
Var
 DXLbl:String;
 VIdx:Integer;
 Str09:String;
Begin
 Case FuncAH of
  $01:TranslateINT21h:='RegAL := Ord(ReadKey); { INT 21h/AH=01 }';
  $02:TranslateINT21h:='Write(Chr(Lo(RegDX))); { INT 21h/AH=02 }';
  $06:TranslateINT21h:=
   'If Lo(RegDX) = $FF Then RegAL := Ord(ReadKey) '+
   'Else Write(Chr(Lo(RegDX))); { INT 21h/AH=06 }';
  $07:TranslateINT21h:='RegAL := Ord(ReadKey); { INT 21h/AH=07 }';
  $08:TranslateINT21h:='RegAL := Ord(ReadKey); { INT 21h/AH=08 }';
  $09:Begin
    { INT 21h/AH=09: afficher chaine a DS:DX (terminee par '$').
      On recherche la variable DB pointee par DX et on genere
      Write('...') avec le contenu de la chaine. }
    DXLbl:=FindPrevDXLabel(LineIdx);
    VIdx:=0;
    Str09:='';
    If DXLbl<>'' Then
     VIdx:=FindDataVarByName(DXLbl);
    If VIdx>0 Then
     Str09:=GetDataVarString(VIdx);
    If Str09<>'' Then
     TranslateINT21h:='Write('''+Str09+'''); { INT 21h/AH=09 }'
    Else If DXLbl<>'' Then
     TranslateINT21h:='Write('+DXLbl+'); { INT 21h/AH=09 }'
    Else
     TranslateINT21h:='Write(PChar(@Mem[RegDX])); { INT 21h/AH=09 }';
   End;
  $0A:TranslateINT21h:='ReadLn; (* INT 21h/AH=0Ah: Buffered input *)';
  $25:TranslateINT21h:=
   'SetIntVec(Lo(RegAX), Ptr(RegDS, RegDX)); { INT 21h/AH=25 }';
  $2A:TranslateINT21h:=
   'GetDate(Year, Month, Day, DayOfWeek); '+
   'RegCX := Year; Lo(RegDX) := Month; Hi(RegDX) := Day; '+
   'RegAL := DayOfWeek; { INT 21h/AH=2A }';
  $2C:TranslateINT21h:=
   'GetTime(Hour, Minute, Second, Sec100); '+
   'Hi(RegCX) := Hour; Lo(RegCX) := Minute; '+
   'Hi(RegDX) := Second; Lo(RegDX) := Sec100; { INT 21h/AH=2C }';
  $2E:TranslateINT21h:=
   'SetVerify(Boolean(Lo(RegAX))); { INT 21h/AH=2E }';
  $30:TranslateINT21h:=
   'RegAL := Lo(DosVersion); RegAH := Hi(DosVersion); '+
   '{ INT 21h/AH=30 }';
  $33:Begin
   If FuncAL=0 Then
    TranslateINT21h:=
     'GetCBreak(BoolTmp); { INT 21h/AX=3300 - resultat dans BoolTmp }'
   Else If FuncAL=1 Then
    TranslateINT21h:=
     'SetCBreak(Boolean(Lo(RegDX))); { INT 21h/AX=3301 }'
   Else
    TranslateINT21h:=
     'GetCBreak(BoolTmp); { INT 21h/AH=33 - resultat dans BoolTmp }';
  End;
  $35:TranslateINT21h:=
   'GetIntVec(Lo(RegAX), IntPtr); '+
   'RegBX := Ofs(IntPtr^); RegES := Seg(IntPtr^); { INT 21h/AH=35 }';
  $36:TranslateINT21h:=
   'TmpL := DiskFree(Lo(RegDX)); { INT 21h/AH=36 - DiskFree ou DiskSize }';
  $39:TranslateINT21h:=
   'CreateDir(DirBuf); { INT 21h/AH=39 creer repertoire (WinDOS) }';
  $3A:TranslateINT21h:=
   'RemoveDir(DirBuf); { INT 21h/AH=3A supprimer repertoire (WinDOS) }';
  $3B:TranslateINT21h:=
   'SetCurDir(DirBuf); { INT 21h/AH=3B changer repertoire (WinDOS) }';
  $3C:TranslateINT21h:=
   'Assign(F, ParamStr(RegDX)); Rewrite(F); { INT 21h/AH=3C creer }';
  $3D:TranslateINT21h:=
   'Assign(F, ParamStr(RegDX)); Reset(F); { INT 21h/AH=3D ouvrir }';
  $3E:TranslateINT21h:='Close(F); { INT 21h/AH=3E fermer }';
  $3F:TranslateINT21h:=
   'BlockRead(F, Buf, RegCX, RegAX); { INT 21h/AH=3F lire }';
  $40:TranslateINT21h:=
   'BlockWrite(F, Buf, RegCX, RegAX); { INT 21h/AH=40 ecrire }';
  $41:TranslateINT21h:=
   'Assign(F, ParamStr(RegDX)); Erase(F); { INT 21h/AH=41 suppr }';
  $43:TranslateINT21h:=
   'GetFAttr(F, RegCX); { INT 21h/AH=43 attributs }';
  $4C:TranslateINT21h:='Halt(Lo(RegAX)); { INT 21h/AH=4C }';
  $54:TranslateINT21h:=
   'GetVerify(BoolTmp); { INT 21h/AH=54 - resultat dans BoolTmp }';
 Else
  If FuncAH>=0 Then
   TranslateINT21h:=
    'Begin Regs.AH := $'+HexByte(Byte(FuncAH And $FF))+
    '; Intr($21, Regs); End; { INT 21h/AH='+
    HexByte(Byte(FuncAH And $FF))+' }'
  Else
   TranslateINT21h:=
    'Intr($21, Regs); { INT 21h - AH inconnu }';
 End;
End;

Function TranslateINT10h(FuncAH:LongInt):String;
{ Traduit les fonctions BIOS video INT 10h en equivalents Pascal.
  AH=00h -> TextMode/mode video
  AH=01h -> curseur
  AH=02h -> GotoXY
  AH=03h -> WhereX/WhereY
  AH=05h -> page active
  AH=06h -> ScrollUp (ClrScr si AL=0)
  AH=07h -> ScrollDown
  AH=09h -> ecrire caractere+attribut
  AH=0Eh -> Write(Chr(AL)) teletype
  AH=0Fh -> mode video courant
  AH=13h -> ecrire chaine
  Autres -> Intr($10, Regs) }
Begin
 Case FuncAH of
  $00:TranslateINT10h:=
   'TextMode(Lo(RegAX)); { INT 10h/AH=00 mode video }';
  $01:TranslateINT10h:=
   'Begin Regs.CX := RegCX; Regs.AH := $01; '+
   'Intr($10, Regs); End; { INT 10h/AH=01 curseur }';
  $02:TranslateINT10h:=
   'GotoXY(Lo(RegDX) + 1, Hi(RegDX) + 1); { INT 10h/AH=02 }';
  $03:TranslateINT10h:=
   'Lo(RegDX) := WhereX - 1; Hi(RegDX) := WhereY - 1; '+
   '{ INT 10h/AH=03 }';
  $05:TranslateINT10h:=
   'Begin Regs.AL := Lo(RegAX); Regs.AH := $05; '+
   'Intr($10, Regs); End; { INT 10h/AH=05 page }';
  $06:TranslateINT10h:=
   'If Lo(RegAX) = 0 Then ClrScr '+
   'Else Begin Regs.AX := RegAX; Regs.BH := Hi(RegBX); '+
   'Regs.CX := RegCX; Regs.DX := RegDX; '+
   'Intr($10, Regs); End; { INT 10h/AH=06 scroll }';
  $07:TranslateINT10h:=
   'Begin Regs.AX := RegAX; Regs.BH := Hi(RegBX); '+
   'Regs.CX := RegCX; Regs.DX := RegDX; '+
   'Intr($10, Regs); End; { INT 10h/AH=07 scroll down }';
  $09:TranslateINT10h:=
   'Begin TextAttr := Lo(RegBX); Write(Chr(Lo(RegAX))); '+
   'End; { INT 10h/AH=09 car+attr }';
  $0E:TranslateINT10h:=
   'Write(Chr(Lo(RegAX))); { INT 10h/AH=0E teletype }';
  $0F:TranslateINT10h:=
   'RegAL := LastMode; RegAH := 80; '+
   '{ INT 10h/AH=0F mode courant }';
  $13:TranslateINT10h:=
   'Begin Regs.AX := RegAX; Regs.BX := RegBX; '+
   'Regs.CX := RegCX; Regs.DX := RegDX; '+
   'Regs.ES := RegES; Regs.BP := RegBP; '+
   'Intr($10, Regs); End; { INT 10h/AH=13 chaine }';
 Else
  If FuncAH>=0 Then
   TranslateINT10h:=
    'Begin Regs.AH := $'+HexByte(Byte(FuncAH And $FF))+
    '; Intr($10, Regs); End; { INT 10h/AH='+
    HexByte(Byte(FuncAH And $FF))+' }'
  Else
   TranslateINT10h:=
    'Intr($10, Regs); { INT 10h - AH inconnu }';
 End;
End;

Function TranslateINT16h(FuncAH:LongInt):String;
{ Traduit les fonctions BIOS clavier INT 16h en equivalents Pascal.
  AH=00h -> ReadKey
  AH=01h -> KeyPressed
  AH=02h -> shift flags
  AH=10h -> ReadKey etendu
  AH=11h -> KeyPressed etendu
  Autres -> Intr($16, Regs) }
Begin
 Case FuncAH of
  $00:TranslateINT16h:=
   'RegAL := Ord(ReadKey); RegAH := 0; { INT 16h/AH=00 }';
  $01:TranslateINT16h:=
   'FlagZF := not KeyPressed; { INT 16h/AH=01 }';
  $02:TranslateINT16h:=
   'Begin Regs.AH := $02; Intr($16, Regs); '+
   'RegAL := Regs.AL; End; { INT 16h/AH=02 shift }';
  $10:TranslateINT16h:=
   'RegAL := Ord(ReadKey); If RegAL = 0 Then '+
   'RegAH := Ord(ReadKey); { INT 16h/AH=10 }';
  $11:TranslateINT16h:=
   'FlagZF := not KeyPressed; { INT 16h/AH=11 }';
 Else
  If FuncAH>=0 Then
   TranslateINT16h:=
    'Begin Regs.AH := $'+HexByte(Byte(FuncAH And $FF))+
    '; Intr($16, Regs); End; { INT 16h/AH='+
    HexByte(Byte(FuncAH And $FF))+' }'
  Else
   TranslateINT16h:=
    'Intr($16, Regs); { INT 16h - AH inconnu }';
 End;
End;

Function TranslateINT(IntNum,FuncAH,FuncAL,LineIdx:LongInt):String;
{ Traduit une instruction INT nn en code Pascal.
  Dispatche vers les traducteurs specialises pour les
  interruptions connues (21h, 10h, 16h).
  Pour les autres interruptions, genere un appel Intr(). }
Begin
 Case IntNum of
  $10:TranslateINT:=TranslateINT10h(FuncAH);
  $16:TranslateINT:=TranslateINT16h(FuncAH);
  $21:TranslateINT:=TranslateINT21h(FuncAH,FuncAL,LineIdx);
 Else
  If FuncAH>=0 Then
   TranslateINT:='Begin Regs.AH := $'+HexByte(Byte(FuncAH And $FF))+
    '; Intr($'+HexByte(Byte(IntNum And $FF))+', Regs); End; { INT '+
    HexByte(Byte(IntNum And $FF))+'h/AH='+HexByte(Byte(FuncAH And $FF))+' }'
  Else
   TranslateINT:='Intr($'+HexByte(Byte(IntNum And $FF))+
    ', Regs); { INT '+HexByte(Byte(IntNum And $FF))+'h }';
 End;
End;

Procedure ProcessIntTranslations;
{ Parcourt les lignes source et traduit les instructions INT
  en appels de fonctions Pascal equivalentes. Detecte les MOV AH, nn
  precedant un INT pour identifier la fonction appelee.
  Produit des statistiques par categorie d'interruption. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 Code:String;
 IntNum,FuncAH,FuncAL:LongInt;
 TotalInt:LongInt;
 Int21Count,Int10Count,Int16Count,IntOtherCount:LongInt;
 Int21Known,Int10Known,Int16Known:LongInt;
 IntoCount:LongInt;
 M:String;
Begin
 TotalInt:=0;
 Int21Count:=0;Int10Count:=0;Int16Count:=0;IntOtherCount:=0;
 Int21Known:=0;Int10Known:=0;Int16Known:=0;
 IntoCount:=0;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=UpCaseStr(AsmL.Mnemonic);
  If Not IsIntMnemonic(M) Then Continue;
  Code:='';
  If M='INTO' Then Begin
   Code:='If FlagOF Then Begin Regs.AH := 0; Intr($04, Regs); End;'+
    ' { INTO }';
   Inc(IntoCount);
  End
  Else If M='INT' Then Begin
   { Recuperer le numero d'interruption depuis l'operande }
   IntNum:=-1;
   If AsmL.Op1.OpType=OT_IMM8 Then
    IntNum:=AsmL.Op1.Imm
   Else If AsmL.Op1.OpType=OT_IMM16 Then
    IntNum:=AsmL.Op1.Imm
   Else If AsmL.Op1.OpType=OT_LABEL Then
    IntNum:=HexToInt(AsmL.Op1.LabelName);
   If IntNum<0 Then Continue;
   { Rechercher le MOV AH, nn et MOV AL, nn precedants }
   FuncAH:=FindPrevMovAH(I);
   FuncAL:=FindPrevMovAL(I);
   { Traduire selon le numero d'interruption }
   Code:=TranslateINT(IntNum,FuncAH,FuncAL,I);
   Case IntNum of
    $10:Begin
     Inc(Int10Count);
     If FuncAH>=0 Then Inc(Int10Known);
    End;
    $16:Begin
     Inc(Int16Count);
     If FuncAH>=0 Then Inc(Int16Known);
    End;
    $21:Begin
     Inc(Int21Count);
     If FuncAH>=0 Then Inc(Int21Known);
     If(FuncAH=$39)or(FuncAH=$3A)or(FuncAH=$3B)Then
      NeedWinDos:=True;
     If(FuncAH=$33)or(FuncAH=$54)Then
      NeedDosBool:=True;
    End;
   Else
    Inc(IntOtherCount);
   End;
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalInt);
  End;
 End;
 WriteLn('Traduction INT systeme : ',TotalInt,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  INT 21h (DOS)    : ',Int21Count);
  WriteLn('    func. connues  : ',Int21Known);
  WriteLn('  INT 10h (video)  : ',Int10Count);
  WriteLn('    func. connues  : ',Int10Known);
  WriteLn('  INT 16h (clavier): ',Int16Count);
  WriteLn('    func. connues  : ',Int16Known);
  WriteLn('  Autres INT       : ',IntOtherCount);
  WriteLn('  INTO             : ',IntoCount);
  If TotalInt>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalInt to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Traduction des modes d'adressage - TODO 19
  ============================================================ }

Const
 { Categories de modes d'adressage }
 AC_NONE    = 0;
 AC_STACK   = 1;  { [BP+n] ou [BP-n] }
 AC_ARRAY   = 2;  { [BX+SI+disp] ou [reg+index*scale] }
 AC_RECORD  = 3;  { [reg+offset fixe] acces champ de structure }
 AC_SEGOFS  = 4;  { segment:offset : Mem/MemW/MemL }
 AC_DIRECT  = 5;  { [addr] acces memoire direct }
 AC_INDEXED = 6;  { [EBX+ECX*4] tableau indexe }

 MAX_ADDR_FIELDS = 128;
 MAX_ADDR_STRUCTS = 32;
 MIN_STRUCT_REFS = 2;  { Nb minimum de refs pour detecter un record }

Type
 TAddrField = Record
  BaseReg:String;    { Registre de base utilise }
  Offset:LongInt;    { Deplacement fixe }
  Size:Byte;         { Taille de l'acces (1,2,4) }
  RefCount:Integer;  { Nb de references a cet offset }
  SrcLine:LongInt;   { Premiere ligne de reference }
 End;

 TAddrStruct = Record
  BaseReg:String;     { Registre de base commun }
  FieldCount:Integer;
  Fields:Array[1..16] of Record
   Offset:LongInt;
   Size:Byte;
   FieldName:String;
  End;
  RecordName:String;  { Nom genere pour le record }
  RefCount:Integer;   { Total de references }
 End;

Var
 AddrFields:Array[1..MAX_ADDR_FIELDS] of TAddrField;
 AddrFieldCount:Integer;
 AddrStructs:Array[1..MAX_ADDR_STRUCTS] of TAddrStruct;
 AddrStructCount:Integer;

Function AddrModeCategory(Var Op:TOperand):Byte;
{ Classifie le mode d'adressage d'un operande memoire.
  AC_STACK   = [BP+n] ou [EBP+n] : acces pile (params/locales)
  AC_INDEXED = [reg+index*scale] : tableau indexe
  AC_ARRAY   = [base+index+disp] : acces tableau/record
  AC_RECORD  = [base+disp fixe] sans index : champ de structure
  AC_SEGOFS  = avec override de segment explicite
  AC_DIRECT  = [imm] ou [label] seul
  AC_NONE    = pas un operande memoire }
Var
 U:String;
Begin
 If Op.OpType<>OT_MEM Then Begin
  AddrModeCategory:=AC_NONE;
  Exit;
 End;
 U:=UpCaseStr(Op.BaseReg);
 { [BP+n] ou [EBP+n] = acces pile }
 If((U='BP')or(U='EBP'))and(Op.IndexReg='')Then Begin
  AddrModeCategory:=AC_STACK;
  Exit;
 End;
 { [reg+index*scale] avec scale>1 = tableau indexe }
 If(Op.IndexReg<>'')and(Op.Scale>1)Then Begin
  AddrModeCategory:=AC_INDEXED;
  Exit;
 End;
 { Avec override de segment explicite }
 If Op.SegOverride<>'' Then Begin
  AddrModeCategory:=AC_SEGOFS;
  Exit;
 End;
 { [base+index+disp] = acces tableau }
 If(Op.BaseReg<>'')and(Op.IndexReg<>'')Then Begin
  AddrModeCategory:=AC_ARRAY;
  Exit;
 End;
 { [base+disp] sans index = potentiel champ de record }
 If(Op.BaseReg<>'')and(Op.HasDisp)and(Op.IndexReg='')Then Begin
  AddrModeCategory:=AC_RECORD;
  Exit;
 End;
 { [base] seul sans deplacement }
 If(Op.BaseReg<>'')and(Not Op.HasDisp)Then Begin
  AddrModeCategory:=AC_DIRECT;
  Exit;
 End;
 { [label] ou [imm] }
 If Op.HasDisp or(Op.LabelName<>'')Then Begin
  AddrModeCategory:=AC_DIRECT;
  Exit;
 End;
 AddrModeCategory:=AC_DIRECT;
End;

Function MemSizeToPrefix(Size:Byte):String;
{ Retourne le prefixe Mem/MemW/MemL selon la taille.
  1 byte  -> Mem   (Byte)
  2 bytes -> MemW  (Word)
  4 bytes -> MemL  (LongInt) }
Begin
 Case Size of
  1:MemSizeToPrefix:='Mem';
  2:MemSizeToPrefix:='MemW';
  4:MemSizeToPrefix:='MemL';
 Else
  MemSizeToPrefix:='Mem';
 End;
End;

Function MemSizeToType(Size:Byte):String;
{ Retourne le nom de type Pascal selon la taille.
  1 -> Byte, 2 -> Word, 4 -> LongInt }
Begin
 Case Size of
  1:MemSizeToType:='Byte';
  2:MemSizeToType:='Word';
  4:MemSizeToType:='LongInt';
 Else
  MemSizeToType:='Byte';
 End;
End;

Function RecordFieldName(Offset:LongInt;Size:Byte):String;
{ Genere un nom de champ de record a partir de l'offset et de la taille.
  Ex: offset 0, size 2 -> FieldW_00
      offset 4, size 1 -> FieldB_04
      offset 8, size 4 -> FieldL_08 }
Var
 Prefix:String;
 S:String;
Begin
 Case Size of
  1:Prefix:='FieldB_';
  2:Prefix:='FieldW_';
  4:Prefix:='FieldL_';
 Else
  Prefix:='Field_';
 End;
 Str(Abs(Offset),S);
 If Abs(Offset)<10 Then S:='0'+S;
 RecordFieldName:=Prefix+S;
End;

Procedure CollectAddrFields(Var Op:TOperand;SrcLine:LongInt);
{ Collecte les acces memoire [base+offset] pour la detection de
  patterns de structures. Chaque paire (baseReg, offset) unique
  est enregistree avec un compteur de references. }
Var
 I:Integer;
 U:String;
Begin
 If Op.OpType<>OT_MEM Then Exit;
 U:=UpCaseStr(Op.BaseReg);
 If U='' Then Exit;
 If(U='BP')or(U='EBP')Then Exit; { Pile, pas structure }
 If Op.IndexReg<>'' Then Exit;   { Avec index, pas struct }
 If Not Op.HasDisp Then Exit;    { Sans offset, pas struct }
 { Chercher si cette paire existe deja }
 For I:=1 to AddrFieldCount do Begin
  If(UpCaseStr(AddrFields[I].BaseReg)=U)and
    (AddrFields[I].Offset=Op.Disp)Then Begin
   Inc(AddrFields[I].RefCount);
   Exit;
  End;
 End;
 { Ajouter une nouvelle entree }
 If AddrFieldCount<MAX_ADDR_FIELDS Then Begin
  Inc(AddrFieldCount);
  AddrFields[AddrFieldCount].BaseReg:=U;
  AddrFields[AddrFieldCount].Offset:=Op.Disp;
  If Op.Size>0 Then AddrFields[AddrFieldCount].Size:=Op.Size
  Else AddrFields[AddrFieldCount].Size:=2;
  AddrFields[AddrFieldCount].RefCount:=1;
  AddrFields[AddrFieldCount].SrcLine:=SrcLine;
 End;
End;

Procedure DetectRecordPatterns;
{ Analyse les champs collectes pour detecter des patterns de
  structures/records. Un record est detecte quand un meme
  registre de base est utilise avec plusieurs offsets fixes
  de facon repetee. }
Var
 I,J,K:Integer;
 BaseRegs:Array[1..32] of String;
 BaseRegCount:Integer;
 U:String;
 Found:Boolean;
 FieldIdx:Integer;
 S:String;
Begin
 AddrStructCount:=0;
 { Collecter les registres de base uniques }
 BaseRegCount:=0;
 For I:=1 to 32 do BaseRegs[I]:='';
 For I:=1 to AddrFieldCount do Begin
  U:=AddrFields[I].BaseReg;
  Found:=False;
  For J:=1 to BaseRegCount do
   If BaseRegs[J]=U Then Begin Found:=True; Break; End;
  If(Not Found)and(BaseRegCount<32)Then Begin
   Inc(BaseRegCount);
   BaseRegs[BaseRegCount]:=U;
  End;
 End;
 { Pour chaque registre de base, trouver les offsets utilises }
 For I:=1 to BaseRegCount do Begin
  { Compter les offsets distincts pour ce registre }
  FieldIdx:=0;
  For J:=1 to AddrFieldCount do Begin
   If AddrFields[J].BaseReg=BaseRegs[I] Then
    Inc(FieldIdx);
  End;
  { Si au moins MIN_STRUCT_REFS offsets distincts, c'est un record }
  If FieldIdx>=MIN_STRUCT_REFS Then Begin
   If AddrStructCount<MAX_ADDR_STRUCTS Then Begin
    Inc(AddrStructCount);
    AddrStructs[AddrStructCount].BaseReg:=BaseRegs[I];
    AddrStructs[AddrStructCount].FieldCount:=0;
    AddrStructs[AddrStructCount].RefCount:=0;
    Str(AddrStructCount,S);
    AddrStructs[AddrStructCount].RecordName:='TStruct'+S;
    { Remplir les champs }
    For J:=1 to AddrFieldCount do Begin
     If AddrFields[J].BaseReg=BaseRegs[I] Then Begin
      K:=AddrStructs[AddrStructCount].FieldCount;
      If K<16 Then Begin
       Inc(K);
       AddrStructs[AddrStructCount].FieldCount:=K;
       AddrStructs[AddrStructCount].Fields[K].Offset:=AddrFields[J].Offset;
       AddrStructs[AddrStructCount].Fields[K].Size:=AddrFields[J].Size;
       AddrStructs[AddrStructCount].Fields[K].FieldName:=
        RecordFieldName(AddrFields[J].Offset,AddrFields[J].Size);
       Inc(AddrStructs[AddrStructCount].RefCount,AddrFields[J].RefCount);
      End;
     End;
    End;
   End;
  End;
 End;
End;

Function FindAddrStruct(BaseReg:String;Offset:LongInt):String;
{ Cherche si un acces [BaseReg+Offset] correspond a un champ
  d'une structure detectee. Retourne le nom du champ ou '' }
Var
 I,J:Integer;
 U:String;
Begin
 FindAddrStruct:='';
 U:=UpCaseStr(BaseReg);
 For I:=1 to AddrStructCount do Begin
  If AddrStructs[I].BaseReg=U Then Begin
   For J:=1 to AddrStructs[I].FieldCount do Begin
    If AddrStructs[I].Fields[J].Offset=Offset Then Begin
     FindAddrStruct:=AddrStructs[I].RecordName+'.'+
      AddrStructs[I].Fields[J].FieldName;
     Exit;
    End;
   End;
  End;
 End;
End;

Function TranslateMemAccess(Var Op:TOperand;ProcIdx:Integer):String;
{ Traduit un operande memoire en expression Pascal amelioree.
  Gere les differents modes d'adressage avec typage correct :
  - [BP+n]  -> param/local via StackAccessExpr
  - [BX+SI+disp] -> Variable locale si disponible, sinon Mem[...]
  - [EBX+ECX*4]  -> Tab[Index] ou MemL[base+index*scale]
  - WORD PTR [x] -> MemW[...]
  - DWORD PTR [x] -> MemL[...]
  - [reg+disp]   -> record field si detecte, sinon Mem[...] }
Var
 Cat:Byte;
 Pfx,Expr,FieldRef:String;
 U,SegStr:String;
 LocalIdx:Integer;
Begin
 Cat:=AddrModeCategory(Op);
 { Determiner le prefixe memoire selon la taille }
 If Op.Size>0 Then Pfx:=MemSizeToPrefix(Op.Size)
 Else Pfx:='Mem';
 Case Cat of
  AC_STACK:Begin
   { Pile : deleguer a StackAccessExpr }
   TranslateMemAccess:=StackAccessExpr(Op.BaseReg,Op.Disp,ProcIdx);
  End;
  AC_INDEXED:Begin
   { Tableau indexe : [base+index*scale+disp] }
   Expr:=RegToPascalVar(Op.BaseReg);
   If Op.IndexReg<>'' Then Begin
    Expr:=Expr+'+'+RegToPascalVar(Op.IndexReg);
    If Op.Scale>1 Then
     Expr:=RegToPascalVar(Op.BaseReg)+'+'+
      RegToPascalVar(Op.IndexReg)+'*'+IntToStr(Op.Scale);
   End;
   If Op.HasDisp Then Begin
    If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
    Else Expr:=Expr+IntToStr(Op.Disp);
   End;
   TranslateMemAccess:=Pfx+'['+Expr+']';
  End;
  AC_ARRAY:Begin
   { Base+index : [BX+SI+disp] }
   { Chercher d'abord une variable locale pour cet acces }
   If Op.HasDisp Then
    LocalIdx:=FindIndexedLocalByOffset(ProcIdx,Op.BaseReg,Op.IndexReg,Op.Disp)
   Else
    LocalIdx:=FindIndexedLocalByOffset(ProcIdx,Op.BaseReg,Op.IndexReg,0);
   If LocalIdx>0 Then Begin
    { Variable locale trouvee - utiliser son nom }
    TranslateMemAccess:=Procs[ProcIdx].Locals[LocalIdx].Name;
   End
   Else Begin
    { Pas de variable locale - generer l'acces memoire standard }
    U:=UpCaseStr(Op.BaseReg);
    If Op.SegOverride<>'' Then
     SegStr:=RegToPascalVar(Copy(Op.SegOverride,1,2))+':'
    Else If(U='BX')or(U='SI')or(U='DI')Then
     SegStr:='RegDS:'
    Else SegStr:='';
    Expr:=RegToPascalVar(Op.BaseReg)+'+'+RegToPascalVar(Op.IndexReg);
    If Op.HasDisp Then Begin
     If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
     Else Expr:=Expr+IntToStr(Op.Disp);
    End;
    TranslateMemAccess:=Pfx+'['+SegStr+Expr+']';
   End;
  End;
  AC_RECORD:Begin
   { Champ de structure potentiel : [reg+offset fixe] }
   U:=UpCaseStr(Op.BaseReg);
   { Verifier si c'est un champ de record detecte }
   FieldRef:=FindAddrStruct(U,Op.Disp);
   If FieldRef<>'' Then Begin
    { Acces via record : PtrReg^.FieldName }
    TranslateMemAccess:=Pfx+'['+RegToPascalVar(Op.BaseReg)+'+'+
     IntToStr(Op.Disp)+'] { '+FieldRef+' }';
   End
   Else Begin
    { Acces memoire simple avec offset }
    Expr:=RegToPascalVar(Op.BaseReg);
    If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
    Else Expr:=Expr+IntToStr(Op.Disp);
    TranslateMemAccess:=Pfx+'['+Expr+']';
   End;
  End;
  AC_SEGOFS:Begin
   { Segment:Offset explicite }
   SegStr:=RegToPascalVar(Copy(Op.SegOverride,1,2))+':';
   If(Op.BaseReg<>'')and(Op.IndexReg<>'')Then Begin
    Expr:=RegToPascalVar(Op.BaseReg)+'+'+RegToPascalVar(Op.IndexReg);
    If Op.Scale>1 Then
     Expr:=RegToPascalVar(Op.BaseReg)+'+'+
      RegToPascalVar(Op.IndexReg)+'*'+IntToStr(Op.Scale);
    If Op.HasDisp Then Begin
     If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
     Else Expr:=Expr+IntToStr(Op.Disp);
    End;
   End
   Else If Op.BaseReg<>'' Then Begin
    Expr:=RegToPascalVar(Op.BaseReg);
    If Op.HasDisp Then Begin
     If Op.Disp>=0 Then Expr:=Expr+'+'+IntToStr(Op.Disp)
     Else Expr:=Expr+IntToStr(Op.Disp);
    End;
   End
   Else If Op.LabelName<>'' Then
    Expr:=Op.LabelName
   Else If Op.HasDisp Then
    Expr:=IntToStr(Op.Disp)
   Else Expr:='0';
   TranslateMemAccess:=Pfx+'['+SegStr+Expr+']';
  End;
  AC_DIRECT:Begin
   { Acces memoire direct }
   If Op.LabelName<>'' Then Begin
    If FindSymbol(Op.LabelName)>0 Then
     TranslateMemAccess:=Symbols[FindSymbol(Op.LabelName)].Name
    Else
     TranslateMemAccess:=Pfx+'['+Op.LabelName+']';
   End
   Else If Op.BaseReg<>'' Then
    TranslateMemAccess:=Pfx+'['+RegToPascalVar(Op.BaseReg)+']'
   Else If Op.HasDisp Then
    TranslateMemAccess:=Pfx+'[$'+HexWord(Word(Op.Disp))+']'
   Else
    TranslateMemAccess:=Pfx+'[0]';
  End;
 Else
  TranslateMemAccess:='Mem[0]';
 End;
End;

Function IsAddrModeMnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une instruction qui utilise
  des operandes memoire necessitant une traduction d'adressage.
  Inclut les transferts, arithmetique, logique, comparaisons. }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsAddrModeMnemonic:=
  (U='MOV')or(U='MOVZX')or(U='MOVSX')or
  (U='LEA')or(U='LDS')or(U='LES')or(U='LFS')or(U='LGS')or(U='LSS')or
  (U='ADD')or(U='ADC')or(U='SUB')or(U='SBB')or
  (U='AND')or(U='OR')or(U='XOR')or(U='TEST')or(U='NOT')or(U='NEG')or
  (U='CMP')or(U='INC')or(U='DEC')or
  (U='MUL')or(U='IMUL')or(U='DIV')or(U='IDIV')or
  (U='SHL')or(U='SHR')or(U='SAR')or(U='SAL')or
  (U='ROL')or(U='ROR')or(U='RCL')or(U='RCR')or
  (U='XCHG')or(U='PUSH')or(U='POP')or
  (U='BT')or(U='BTS')or(U='BTR')or(U='BTC');
End;

Procedure ProcessAddressingTranslations;
{ Parcourt les lignes source pour traduire les modes d'adressage
  complexes en syntaxe Pascal. Detecte les patterns de structures
  (records) et genere des traductions typees (Mem/MemW/MemL).
  Phase 1: Collecte des acces memoire pour detection de structures.
  Phase 2: Traduction des operandes memoire avec typage correct.
  Produit des statistiques par categorie d'adressage. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 M,Code,Expr1,Expr2:String;
 Cat1,Cat2:Byte;
 TotalAddr:LongInt;
 StackCount,ArrayCount,IndexedCount:LongInt;
 RecordCount,SegOfsCount,DirectCount:LongInt;
 StructFieldRefs:LongInt;
Begin
 TotalAddr:=0;
 StackCount:=0;ArrayCount:=0;IndexedCount:=0;
 RecordCount:=0;SegOfsCount:=0;DirectCount:=0;
 StructFieldRefs:=0;
 AddrFieldCount:=0;
 AddrStructCount:=0;
 { Phase 1 : Collecter les acces memoire pour detection de records }
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=UpCaseStr(AsmL.Mnemonic);
  If Not IsAddrModeMnemonic(M) Then Continue;
  CollectAddrFields(AsmL.Op1,I);
  CollectAddrFields(AsmL.Op2,I);
 End;
 { Detecter les structures }
 DetectRecordPatterns;
 { Phase 2 : Traduire les operandes memoire }
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=UpCaseStr(AsmL.Mnemonic);
  If Not IsAddrModeMnemonic(M) Then Continue;
  { Verifier si au moins un operande est memoire }
  Cat1:=AddrModeCategory(AsmL.Op1);
  Cat2:=AddrModeCategory(AsmL.Op2);
  If(Cat1=AC_NONE)and(Cat2=AC_NONE)Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:='';
  { Traduire les deux operandes }
  If AsmL.Op1.OpType=OT_MEM Then
   Expr1:=TranslateMemAccess(AsmL.Op1,ProcIdx)
  Else
   Expr1:=OperandToExpr(AsmL.Op1,ProcIdx);
  If AsmL.Op2.OpType=OT_MEM Then
   Expr2:=TranslateMemAccess(AsmL.Op2,ProcIdx)
  Else
   Expr2:=OperandToExpr(AsmL.Op2,ProcIdx);
  { Generer le commentaire de traduction }
  If(Cat1<>AC_NONE)Then Begin
   Code:='{ addr: '+M+' '+Expr1;
   If AsmL.Op2.OpType<>OT_NONE Then
    Code:=Code+', '+Expr2;
   Code:=Code+' }';
  End
  Else If(Cat2<>AC_NONE)Then Begin
   Code:='{ addr: '+M+' '+Expr1+', '+Expr2+' }';
  End;
  { Compter les categories }
  If Cat1<>AC_NONE Then Begin
   Case Cat1 of
    AC_STACK:Inc(StackCount);
    AC_ARRAY:Inc(ArrayCount);
    AC_INDEXED:Inc(IndexedCount);
    AC_RECORD:Begin
     Inc(RecordCount);
     If FindAddrStruct(AsmL.Op1.BaseReg,AsmL.Op1.Disp)<>'' Then
      Inc(StructFieldRefs);
    End;
    AC_SEGOFS:Inc(SegOfsCount);
    AC_DIRECT:Inc(DirectCount);
   End;
  End;
  If Cat2<>AC_NONE Then Begin
   Case Cat2 of
    AC_STACK:Inc(StackCount);
    AC_ARRAY:Inc(ArrayCount);
    AC_INDEXED:Inc(IndexedCount);
    AC_RECORD:Begin
     Inc(RecordCount);
     If FindAddrStruct(AsmL.Op2.BaseReg,AsmL.Op2.Disp)<>'' Then
      Inc(StructFieldRefs);
    End;
    AC_SEGOFS:Inc(SegOfsCount);
    AC_DIRECT:Inc(DirectCount);
   End;
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(TotalAddr);
  End;
 End;
 WriteLn('Traduction adressage : ',TotalAddr,' operandes memoire, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  Pile [BP+n]       : ',StackCount);
  WriteLn('  Tableau [b+i+d]   : ',ArrayCount);
  WriteLn('  Indexe [r+i*s]    : ',IndexedCount);
  WriteLn('  Record [r+d]      : ',RecordCount);
  WriteLn('  Segment:Offset    : ',SegOfsCount);
  WriteLn('  Direct [addr]     : ',DirectCount);
  WriteLn('  Structures detect.: ',AddrStructCount);
  WriteLn('  Champs collectes  : ',AddrFieldCount);
  WriteLn('  Refs struct.      : ',StructFieldRefs);
  If AddrStructCount>0 Then Begin
   WriteLn('  Records detectes :');
   For I:=1 to AddrStructCount do Begin
    WriteLn('    ',AddrStructs[I].RecordName,' (base=',
     AddrStructs[I].BaseReg,', ',
     AddrStructs[I].FieldCount,' champs, ',
     AddrStructs[I].RefCount,' refs) :');
    For ProcIdx:=1 to AddrStructs[I].FieldCount do
     WriteLn('      ',
      AddrStructs[I].Fields[ProcIdx].FieldName,
      ' : ',MemSizeToType(AddrStructs[I].Fields[ProcIdx].Size),
      '; { offset ',AddrStructs[I].Fields[ProcIdx].Offset,' }');
   End;
  End;
  If TotalAddr>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-TotalAddr to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Gestion des extensions 80386 - TODO 20
  ============================================================ }

Function SETccSuffix(Mnem:String):String;
{ Extrait le suffixe de condition d'un mnemonique SETcc.
  SETE -> E, SETNE -> NE, SETG -> G, etc. }
Var
 U:String;
Begin
 U:=UpCaseStr(Mnem);
 If(Length(U)>3)and(Copy(U,1,3)='SET')Then
  SETccSuffix:=Copy(U,4,Length(U)-3)
 Else
  SETccSuffix:='';
End;

Function CMOVccSuffix(Mnem:String):String;
{ Extrait le suffixe de condition d'un mnemonique CMOVcc.
  CMOVE -> E, CMOVNE -> NE, CMOVG -> G, etc. }
Var
 U:String;
Begin
 U:=UpCaseStr(Mnem);
 If(Length(U)>4)and(Copy(U,1,4)='CMOV')Then
  CMOVccSuffix:=Copy(U,5,Length(U)-4)
 Else
  CMOVccSuffix:='';
End;

Function CcToFlagExpr(Suffix:String):String;
{ Convertit un suffixe de condition (E, NE, G, GE, L, LE, etc.)
  en expression booleenne Pascal sur les flags.
  Memes conditions que Jcc mais sans le prefixe J. }
Var
 U:String;
Begin
 U:=UpCaseStr(Suffix);
 If(U='E')or(U='Z')Then CcToFlagExpr:='FlagZF'
 Else If(U='NE')or(U='NZ')Then CcToFlagExpr:='not FlagZF'
 Else If U='S' Then CcToFlagExpr:='FlagSF'
 Else If U='NS' Then CcToFlagExpr:='not FlagSF'
 Else If U='O' Then CcToFlagExpr:='FlagOF'
 Else If U='NO' Then CcToFlagExpr:='not FlagOF'
 Else If(U='P')or(U='PE')Then CcToFlagExpr:='FlagPF'
 Else If(U='NP')or(U='PO')Then CcToFlagExpr:='not FlagPF'
 Else If(U='C')or(U='B')or(U='NAE')Then CcToFlagExpr:='FlagCF'
 Else If(U='NC')or(U='AE')or(U='NB')Then CcToFlagExpr:='not FlagCF'
 Else If(U='A')or(U='NBE')Then
  CcToFlagExpr:='(not FlagCF) and (not FlagZF)'
 Else If(U='BE')or(U='NA')Then
  CcToFlagExpr:='FlagCF or FlagZF'
 Else If(U='G')or(U='NLE')Then
  CcToFlagExpr:='(not FlagZF) and (FlagSF = FlagOF)'
 Else If(U='GE')or(U='NL')Then
  CcToFlagExpr:='FlagSF = FlagOF'
 Else If(U='L')or(U='NGE')Then
  CcToFlagExpr:='FlagSF <> FlagOF'
 Else If(U='LE')or(U='NG')Then
  CcToFlagExpr:='FlagZF or (FlagSF <> FlagOF)'
 Else CcToFlagExpr:='';
End;

Function ExtractThirdOp(SrcLine:String):String;
{ Pour les instructions a 3 operandes (SHLD, SHRD, IMUL),
  extrait le troisieme operande apres la deuxieme virgule. }
Var
 P1,P2:Integer;
 S:String;
Begin
 S:=SrcLine;
 P1:=Pos(',',S);
 If P1>0 Then Begin
  S:=Copy(S,P1+1,Length(S)-P1);
  P2:=Pos(',',S);
  If P2>0 Then Begin
   S:=Copy(S,P2+1,Length(S)-P2);
   P1:=Pos(';',S);
   If P1>0 Then S:=Copy(S,1,P1-1);
   ExtractThirdOp:=Trim(S);
  End
  Else ExtractThirdOp:='';
 End Else ExtractThirdOp:='';
End;

Function IsSETcc(M:String):Boolean;
{ Verifie si un mnemonique est une instruction SETcc }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsSETcc:=
  (U='SETE')or(U='SETNE')or(U='SETZ')or(U='SETNZ')or
  (U='SETA')or(U='SETAE')or(U='SETB')or(U='SETBE')or
  (U='SETG')or(U='SETGE')or(U='SETL')or(U='SETLE')or
  (U='SETC')or(U='SETNC')or(U='SETO')or(U='SETNO')or
  (U='SETS')or(U='SETNS')or(U='SETP')or(U='SETNP')or
  (U='SETPE')or(U='SETPO')or
  (U='SETNA')or(U='SETNAE')or(U='SETNB')or(U='SETNBE')or
  (U='SETNG')or(U='SETNGE')or(U='SETNL')or(U='SETNLE');
End;

Function IsCMOVcc(M:String):Boolean;
{ Verifie si un mnemonique est une instruction CMOVcc }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 IsCMOVcc:=
  (U='CMOVE')or(U='CMOVNE')or(U='CMOVZ')or(U='CMOVNZ')or
  (U='CMOVA')or(U='CMOVAE')or(U='CMOVB')or(U='CMOVBE')or
  (U='CMOVG')or(U='CMOVGE')or(U='CMOVL')or(U='CMOVLE')or
  (U='CMOVC')or(U='CMOVNC')or(U='CMOVO')or(U='CMOVNO')or
  (U='CMOVS')or(U='CMOVNS')or(U='CMOVP')or(U='CMOVNP')or
  (U='CMOVPE')or(U='CMOVPO')or
  (U='CMOVNA')or(U='CMOVNAE')or(U='CMOVNB')or(U='CMOVNBE')or
  (U='CMOVNG')or(U='CMOVNGE')or(U='CMOVNL')or(U='CMOVNLE');
End;

Function TranslateBSWAP(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ BSWAP reg32 -> inversion d'endianness (octets 0123 -> 3210)
  Requiert un registre 32 bits. }
Var
 D:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 TranslateBSWAP:=D+' := (('+D+' and $FF) shl 24) or '+
  '(('+D+' and $FF00) shl 8) or '+
  '(('+D+' shr 8) and $FF00) or '+
  '(('+D+' shr 24) and $FF);';
End;

Function TranslateBSF(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ BSF dest,src -> recherche du premier bit a 1 en partant du poids faible.
  Si src = 0, FlagZF := True. Sinon dest := index du bit, FlagZF := False. }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateBSF:='If '+S+' = 0 Then FlagZF := True Else Begin '+
  'FlagZF := False; '+D+' := 0; '+
  'While ('+S+' shr '+D+') and 1 = 0 do Inc('+D+'); End;';
End;

Function TranslateBSR(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ BSR dest,src -> recherche du dernier bit a 1 en partant du poids fort.
  Si src = 0, FlagZF := True. Sinon dest := index du bit, FlagZF := False. }
Var
 D,S,Bits:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 If AsmL.Op2.OpType=OT_REG32 Then Bits:='31'
 Else Bits:='15';
 TranslateBSR:='If '+S+' = 0 Then FlagZF := True Else Begin '+
  'FlagZF := False; '+D+' := '+Bits+'; '+
  'While ('+S+' shr '+D+') and 1 = 0 do Dec('+D+'); End;';
End;

Function TranslateSETcc(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ SETcc r/m8 -> positionner octet selon condition.
  Genere : dest := Ord(condition_flags); }
Var
 D,Cond,Suf:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 Suf:=SETccSuffix(AsmL.Mnemonic);
 Cond:=CcToFlagExpr(Suf);
 If Cond<>'' Then
  TranslateSETcc:=D+' := Ord('+Cond+');'
 Else
  TranslateSETcc:=D+' := Ord({'+UpCaseStr(AsmL.Mnemonic)+'});';
End;

Function TranslateCMOVcc(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ CMOVcc dest,src -> deplacement conditionnel.
  Genere : If condition Then dest := src; }
Var
 D,S,Cond,Suf:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 Suf:=CMOVccSuffix(AsmL.Mnemonic);
 Cond:=CcToFlagExpr(Suf);
 If Cond<>'' Then
  TranslateCMOVcc:='If '+Cond+' Then '+D+' := '+S+';'
 Else
  TranslateCMOVcc:='If {'+UpCaseStr(AsmL.Mnemonic)+'} Then '+D+' := '+S+';';
End;

Function TranslateXADD(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ XADD dest,src -> echange et addition.
  Semantique : temp := dest; dest := dest + src; src := temp;
  Modifie les flags comme ADD. }
Var
 D,S:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 TranslateXADD:='Begin SaveXADD := '+D+'; '+
  D+' := '+D+' + '+S+'; '+S+' := SaveXADD; End;';
End;

Function TranslateCMPXCHG(Var AsmL:TAsmLine;ProcIdx:Integer):String;
{ CMPXCHG dest,src -> comparer et echanger.
  Compare dest avec accumulateur (AL/AX/EAX selon taille).
  Si egal : FlagZF := True, dest := src.
  Sinon : FlagZF := False, accumulateur := dest. }
Var
 D,S,Acc:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 If AsmL.Op1.OpType=OT_REG32 Then Acc:='RegEAX'
 Else If AsmL.Op1.OpType=OT_REG8 Then Acc:='Lo(RegAX)'
 Else Acc:='RegAX';
 TranslateCMPXCHG:='If '+Acc+' = '+D+' Then Begin FlagZF := True; '+
  D+' := '+S+'; End Else Begin FlagZF := False; '+
  Acc+' := '+D+'; End;';
End;

Function TranslateSHLD(Var AsmL:TAsmLine;ProcIdx:Integer;
 CountStr:String):String;
{ SHLD dest,src,count -> decalage gauche double precision.
  Les bits sortant a gauche de dest sont remplaces par les bits
  de poids fort de src. }
Var
 D,S,N,Bits:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 If CountStr<>'' Then N:=CountStr
 Else N:='Lo(RegCX)';
 If AsmL.Op1.OpType=OT_REG32 Then Bits:='32'
 Else Bits:='16';
 TranslateSHLD:=D+' := ('+D+' shl '+N+') or '+
  '('+S+' shr ('+Bits+' - '+N+'));';
End;

Function TranslateSHRD(Var AsmL:TAsmLine;ProcIdx:Integer;
 CountStr:String):String;
{ SHRD dest,src,count -> decalage droit double precision.
  Les bits sortant a droite de dest sont remplaces par les bits
  de poids faible de src. }
Var
 D,S,N,Bits:String;
Begin
 D:=OperandToExpr(AsmL.Op1,ProcIdx);
 S:=OperandToExpr(AsmL.Op2,ProcIdx);
 If CountStr<>'' Then N:=CountStr
 Else N:='Lo(RegCX)';
 If AsmL.Op1.OpType=OT_REG32 Then Bits:='32'
 Else Bits:='16';
 TranslateSHRD:=D+' := ('+D+' shr '+N+') or '+
  '('+S+' shl ('+Bits+' - '+N+'));';
End;

Function Is386Mnemonic(M:String):Boolean;
{ Verifie si un mnemonique est une instruction specifique 386+
  (BSWAP, BSF, BSR, SETcc, CMOVcc, XADD, CMPXCHG, SHLD, SHRD). }
Var
 U:String;
Begin
 U:=UpCaseStr(M);
 Is386Mnemonic:=
  (U='BSWAP')or(U='BSF')or(U='BSR')or
  (U='XADD')or(U='CMPXCHG')or
  (U='SHLD')or(U='SHRD')or
  IsSETcc(M)or IsCMOVcc(M);
End;

Procedure Process386Translations;
{ Parcourt les lignes source et traduit les instructions specifiques
  au processeur 80386+ en code Pascal equivalent.
  Gere BSWAP, BSF/BSR, SETcc, CMOVcc, XADD, CMPXCHG, SHLD/SHRD.
  Detecte le mode FLAT et supprime les prefixes de segment inutiles.
  Produit des statistiques par categorie d'instruction. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 ProcIdx:Integer;
 Code:String;
 Total386:LongInt;
 BswapCount,BsfCount,BsrCount:LongInt;
 SetccCount,CmovccCount:LongInt;
 XaddCount,CmpxchgCount:LongInt;
 ShldCount,ShrdCount:LongInt;
 FlatModeCount:LongInt;
 M,CountStr:String;
Begin
 Total386:=0;
 BswapCount:=0;BsfCount:=0;BsrCount:=0;
 SetccCount:=0;CmovccCount:=0;
 XaddCount:=0;CmpxchgCount:=0;
 ShldCount:=0;ShrdCount:=0;
 FlatModeCount:=0;
 { Detecter le mode FLAT }
 If MemoryModel=MM_FLAT Then Begin
  FlatModeCount:=1;
  If Verbose Then
   WriteLn('  Mode FLAT detecte : segments ignores, adresses lineaires 32 bits.');
 End;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,AsmL);
  If AsmL.Mnemonic='' Then Continue;
  If AsmL.IsDirective Then Continue;
  M:=UpCaseStr(AsmL.Mnemonic);
  If Not Is386Mnemonic(M) Then Continue;
  ProcIdx:=FindProcForLine(I);
  Code:='';
  { BSWAP }
  If M='BSWAP' Then Begin
   Code:=TranslateBSWAP(AsmL,ProcIdx);
   Inc(BswapCount);
  End
  { BSF }
  Else If M='BSF' Then Begin
   Code:=TranslateBSF(AsmL,ProcIdx);
   Inc(BsfCount);
  End
  { BSR }
  Else If M='BSR' Then Begin
   Code:=TranslateBSR(AsmL,ProcIdx);
   Inc(BsrCount);
  End
  { SETcc }
  Else If IsSETcc(M) Then Begin
   Code:=TranslateSETcc(AsmL,ProcIdx);
   Inc(SetccCount);
  End
  { CMOVcc }
  Else If IsCMOVcc(M) Then Begin
   Code:=TranslateCMOVcc(AsmL,ProcIdx);
   Inc(CmovccCount);
  End
  { XADD }
  Else If M='XADD' Then Begin
   Code:=TranslateXADD(AsmL,ProcIdx);
   Inc(XaddCount);
  End
  { CMPXCHG }
  Else If M='CMPXCHG' Then Begin
   Code:=TranslateCMPXCHG(AsmL,ProcIdx);
   Inc(CmpxchgCount);
  End
  { SHLD }
  Else If M='SHLD' Then Begin
   CountStr:=ExtractThirdOp(SrcLines[I]^);
   If CountStr<>'' Then Begin
    If UpCaseStr(CountStr)='CL' Then CountStr:='Lo(RegCX)';
   End;
   Code:=TranslateSHLD(AsmL,ProcIdx,CountStr);
   Inc(ShldCount);
  End
  { SHRD }
  Else If M='SHRD' Then Begin
   CountStr:=ExtractThirdOp(SrcLines[I]^);
   If CountStr<>'' Then Begin
    If UpCaseStr(CountStr)='CL' Then CountStr:='Lo(RegCX)';
   End;
   Code:=TranslateSHRD(AsmL,ProcIdx,CountStr);
   Inc(ShrdCount);
  End;
  If Code<>'' Then Begin
   AddTranslation(I,Code,SrcLines[I]^);
   Inc(Total386);
  End;
 End;
 WriteLn('Traduction 386 : ',Total386,' instructions, ',
  TranslationCount,' traductions totales.');
 If Verbose Then Begin
  WriteLn('  BSWAP            : ',BswapCount);
  WriteLn('  BSF              : ',BsfCount);
  WriteLn('  BSR              : ',BsrCount);
  WriteLn('  SETcc            : ',SetccCount);
  WriteLn('  CMOVcc           : ',CmovccCount);
  WriteLn('  XADD             : ',XaddCount);
  WriteLn('  CMPXCHG          : ',CmpxchgCount);
  WriteLn('  SHLD             : ',ShldCount);
  WriteLn('  SHRD             : ',ShrdCount);
  If FlatModeCount>0 Then
   WriteLn('  Mode FLAT        : actif');
  If Total386>0 Then Begin
   WriteLn('  Details :');
   For I:=TranslationCount-Total386 to TranslationCount-1 do
    If I>=0 Then
     WriteLn('    ',Translations[I].PascalCode);
  End;
 End;
End;

{ ============================================================
  Generation de l'en-tete Pascal - TODO 21
  ============================================================ }

Function ExtractBaseName(Const FN:String):String;
{ Extrait le nom de base du fichier (sans chemin ni extension).
  Ex: '/path/to/HELLO.ASM' -> 'HELLO' }
Var
 S:String;
 I:Integer;
Begin
 S:=FN;
 { Enlever le chemin }
 For I:=Length(S) DownTo 1 do
  If(S[I]='/')or(S[I]='\')or(S[I]=':')Then Begin
   S:=Copy(S,I+1,Length(S)-I);
   Break;
  End;
 { Enlever l'extension }
 For I:=Length(S) DownTo 1 do
  If S[I]='.' Then Begin
   S:=Copy(S,1,I-1);
   Break;
  End;
 { S'assurer que le nom est un identificateur Pascal valide }
 If(Length(S)>0)and(S[1]>='0')and(S[1]<='9')Then
  S:='P'+S;
 If S='' Then S:='Program1';
 ExtractBaseName:=S;
End;

Function ScanForINTCall(Const IntHex:String):Boolean;
{ Parcourt les lignes sources pour detecter un appel INT xxh.
  IntHex doit etre '21H', '10H', '16H', etc. }
Var
 I:LongInt;
 U,Pat1,Pat2,Pat3:String;
Begin
 ScanForINTCall:=False;
 Pat1:='INT '+IntHex;
 Pat2:='INT '+Copy(IntHex,1,Length(IntHex)-1);
 Pat3:='INT $'+Copy(IntHex,1,Length(IntHex)-1);
 For I:=0 to SrcLineCount-1 do Begin
  If SrcLines[I]=Nil Then Continue;
  U:=UpCaseStr(Trim(SrcLines[I]^));
  If(Pos(Pat1,U)>0)or(Pos(Pat2,U)>0)or(Pos(Pat3,U)>0)Then Begin
   ScanForINTCall:=True;
   Exit;
  End;
 End;
End;

Function PascalTypeStr(PT:Byte):String;
{ Convertit une constante PT_* en nom de type Pascal.
  PT_BYTE -> 'Byte', PT_WORD -> 'Word', etc. }
Begin
 Case PT of
  PT_BYTE:     PascalTypeStr:='Byte';
  PT_SHORTINT: PascalTypeStr:='ShortInt';
  PT_WORD:     PascalTypeStr:='Word';
  PT_INTEGER:  PascalTypeStr:='Integer';
  PT_LONGINT:  PascalTypeStr:='LongInt';
  PT_BOOLEAN:  PascalTypeStr:='Boolean';
  PT_CHAR:     PascalTypeStr:='Char';
  PT_STRING:   PascalTypeStr:='String';
  PT_POINTER:  PascalTypeStr:='Pointer';
  PT_PCHAR:    PascalTypeStr:='PChar';
  PT_ARRAY:    PascalTypeStr:='Byte';
 Else
  PascalTypeStr:='Byte';
 End;
End;

Function DirTypeStr(DT:Byte):String;
{ Convertit un type de directive de donnees (DT_DB/DW/DD/DQ) en
  nom de type Pascal. }
Begin
 Case DT of
  DT_DB: DirTypeStr:='Byte';
  DT_DW: DirTypeStr:='Word';
  DT_DD: DirTypeStr:='LongInt';
  DT_DQ: DirTypeStr:='Comp';
  DT_DF: DirTypeStr:='Pointer';
  DT_DT: DirTypeStr:='Extended';
 Else
  DirTypeStr:='Byte';
 End;
End;

Function IsLengthPrefixedString(DataIdx:Integer):Boolean;
{ Reconnait une chaine Pascal courte emise par DISEXE :
  DB longueur,'contenu'. }
Begin
 IsLengthPrefixedString:=False;
 If(DataIdx<1)or(DataIdx>DataVarCount)Then Exit;
 With DataVars[DataIdx] do
  IsLengthPrefixedString:=(DirType=DT_DB)and(ElemCount=2)and
   (Elements[1].ElemType=DE_NUMBER)and
   (Elements[2].ElemType=DE_STRING)and
   (Elements[1].NumValue=Length(Elements[2].StrValue));
End;

Function QuotePascalString(S:String):String;
{ Entoure un texte d'apostrophes Pascal et double les apostrophes internes. }
Var
 I:Integer;
 R:String;
Begin
 R:='''';
 For I:=1 to Length(S) do Begin
  If S[I]='''' Then R:=R+'''';
  R:=R+S[I];
 End;
 QuotePascalString:=R+'''';
End;

{ Declaration forward pour IsLabelOptimized (definie dans TODO 24) }
Function IsLabelOptimized(Const LabelName:String):Boolean; Forward;

Function IsHeaderMnemonic(Const M:String):Boolean;
{ Indique si le mnemonique est gere par TODO 21
  (utilise pour verifier la completude des traductions). }
Begin
 IsHeaderMnemonic:=False; { TODO 21 ne gere pas de mnemoniques }
End;

Procedure ProcessHeaderGeneration;
{ Genere l'en-tete du fichier Pascal de sortie :
  - En-tete Program <nom>;
  - Clause Uses (Dos, Crt, etc. selon les INT detectees)
  - Section Type (records pour les structures detectees)
  - Section Const (constantes EQU et donnees en lecture seule)
  - Section Var (registres, flags, variables du segment DATA)
  - Declarations Label pour les Goto }
Var
 ProgName:String;
 NeedDos,NeedCrt:Boolean;
 I,J:Integer;
 HasConst,HasLabel,HasType:Boolean;
 UnitList:String;
 LabelCount,VarCount,ConstCount,TypeCount:Integer;
 First:Boolean;
 S:String;
Begin
 ProgName:=ExtractBaseName(InFileName);

 { Detecter les unites necessaires a partir des INT trouvees }
 NeedDos:=ScanForINTCall('21H');
 NeedCrt:=ScanForINTCall('10H') or ScanForINTCall('16H');

 { Ouvrir le fichier de sortie }
 Assign(OutFile,OutFileName);
 Rewrite(OutFile);

 { === En-tete du fichier === }
 WriteLn(OutFile,'{ Genere par ASM2PAS v',ASM2PAS_VERSION,
  ' a partir de ',InFileName,' }');
 WriteLn(OutFile,'Program ',ProgName,';');
 WriteLn(OutFile);

 { === Clause Uses === }
 UnitList:='';
 If NeedWinDos Then
  UnitList:='WinDos'
 Else If NeedDos Then
  UnitList:='Dos';
 If NeedCrt Then Begin
  If UnitList<>'' Then UnitList:=UnitList+', ';
  UnitList:=UnitList+'Crt';
 End;
 If NeedStrings Then Begin
  If UnitList<>'' Then UnitList:=UnitList+', ';
  UnitList:=UnitList+'Strings';
 End;
 If UnitList<>'' Then Begin
  WriteLn(OutFile,'Uses ',UnitList,';');
  WriteLn(OutFile);
 End;

 { === Section Type === }
 HasType:=False;
 TypeCount:=0;
 For I:=1 to AddrStructCount do
  If AddrStructs[I].FieldCount>0 Then Begin
   If Not HasType Then Begin
    WriteLn(OutFile,'Type');
    HasType:=True;
   End;
   WriteLn(OutFile,'  ',AddrStructs[I].RecordName,' = Record');
   For J:=1 to AddrStructs[I].FieldCount do
    WriteLn(OutFile,'    ',
     AddrStructs[I].Fields[J].FieldName,' : ',
     MemSizeToType(AddrStructs[I].Fields[J].Size),
     ';');
   WriteLn(OutFile,'  End;');
   Inc(TypeCount);
  End;
 If HasType Then WriteLn(OutFile);

 { === Section Const === }
 HasConst:=False;
 ConstCount:=0;
 { Constantes EQU (symboles de type SY_CONST) }
 For I:=1 to SymbolCount do
  If Symbols[I].SymType=SY_CONST Then Begin
   If Not HasConst Then Begin
    WriteLn(OutFile,'Const');
    HasConst:=True;
   End;
   WriteLn(OutFile,'  ',Symbols[I].Name,' = ',Symbols[I].Offset,';');
   Inc(ConstCount);
  End;
 { Donnees en lecture seule (section .CONST) }
 For I:=1 to DataVarCount do Begin
  If DataVars[I].Section<>SEC_CONST Then Continue;
  If DataVars[I].Name='' Then Continue;
  If Not HasConst Then Begin
   WriteLn(OutFile,'Const');
   HasConst:=True;
  End;
  If(DataVars[I].ElemCount=1)and
    (DataVars[I].Elements[1].ElemType=DE_NUMBER)Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : ',
    DirTypeStr(DataVars[I].DirType),' = ',
    DataVars[I].Elements[1].NumValue,';');
   Inc(ConstCount);
  End
  Else If(DataVars[I].ElemCount=1)and
    (DataVars[I].Elements[1].ElemType=DE_STRING)Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,
    ' : String = ''',
    DataVars[I].Elements[1].StrValue,''';');
   Inc(ConstCount);
  End
  Else If DataVars[I].ElemCount>1 Then Begin
   Write(OutFile,'  ',DataVars[I].Name,
    ' : Array[0..',DataVars[I].ElemCount-1,
    '] of ',DirTypeStr(DataVars[I].DirType),' = (');
   For J:=1 to DataVars[I].ElemCount do Begin
    If J>1 Then Write(OutFile,', ');
    If DataVars[I].Elements[J].ElemType=DE_NUMBER Then
     Write(OutFile,DataVars[I].Elements[J].NumValue)
    Else If DataVars[I].Elements[J].ElemType=DE_STRING Then
     Write(OutFile,'''',DataVars[I].Elements[J].StrValue,'''')
    Else
     Write(OutFile,'0');
   End;
   WriteLn(OutFile,');');
   Inc(ConstCount);
  End;
 End;
 If HasConst Then WriteLn(OutFile);

 { === Section Var === }
 VarCount:=0;
 WriteLn(OutFile,'Var');

 { Registres 16 bits }
 WriteLn(OutFile,'  { Registres 16 bits }');
 WriteLn(OutFile,'  RegAX, RegBX, RegCX, RegDX : Word;');
 WriteLn(OutFile,'  RegSI, RegDI, RegBP, RegSP : Word;');
 WriteLn(OutFile,'  RegDS, RegES, RegSS, RegCS : Word;');
 Inc(VarCount,12);

 { Registres 32 bits si mode 32 ou CPU >= 386 }
 If Mode32 or(CpuLevel>=CPU_386)Then Begin
  WriteLn(OutFile,'  { Registres 32 bits }');
  WriteLn(OutFile,'  RegEAX, RegEBX, RegECX, RegEDX : LongInt;');
  WriteLn(OutFile,'  RegESI, RegEDI, RegEBP, RegESP : LongInt;');
  WriteLn(OutFile,'  RegFS, RegGS : Word;');
  Inc(VarCount,10);
 End;

 { Flags du processeur }
 WriteLn(OutFile,'  { Flags }');
 WriteLn(OutFile,'  FlagCF, FlagZF, FlagSF, FlagOF : Boolean;');
 WriteLn(OutFile,'  FlagDF, FlagPF, FlagAF : Boolean;');
 Inc(VarCount,7);

 { Variables de sauvegarde pour les paires PUSH/POP }
 WriteLn(OutFile,'  { Variables de sauvegarde PUSH/POP }');
 WriteLn(OutFile,'  SaveRegAX, SaveRegBX, SaveRegCX, SaveRegDX : Word;');
 WriteLn(OutFile,'  SaveRegSI, SaveRegDI, SaveRegBP, SaveRegSP : Word;');
 WriteLn(OutFile,'  SaveFlags : Word;');
 WriteLn(OutFile,'  { Sauvegarde individuelle des flags (PUSHF/POPF) }');
 WriteLn(OutFile,'  SaveFlagCF, SaveFlagZF, SaveFlagSF, SaveFlagOF : Boolean;');
 WriteLn(OutFile,'  SaveFlagDF, SaveFlagPF, SaveFlagAF : Boolean;');
 Inc(VarCount,16);
 { Variables temporaires pour MUL/DIV et XCHG }
 WriteLn(OutFile,'  { Variables temporaires }');
 WriteLn(OutFile,'  TmpL : LongInt;');
 WriteLn(OutFile,'  TmpW : Word;');
 WriteLn(OutFile,'  { Simulation memoire pour acces Mem[] }');
 WriteLn(OutFile,'  Mem : Array[0..65535] of Byte;');
 WriteLn(OutFile,'  MemW : Array[0..32767] of Word absolute Mem;');
 Inc(VarCount,4);
 If Mode32 or(CpuLevel>=CPU_386)Then Begin
  WriteLn(OutFile,'  SaveRegEAX, SaveRegEBX, SaveRegECX, SaveRegEDX : LongInt;');
  WriteLn(OutFile,'  SaveRegESI, SaveRegEDI, SaveRegEBP, SaveRegESP : LongInt;');
  WriteLn(OutFile,'  SaveXADD : LongInt;');
  Inc(VarCount,9);
 End;
 If NeedWinDos Then Begin
  WriteLn(OutFile,'  { Tampon repertoire pour SetCurDir/CreateDir/RemoveDir }');
  WriteLn(OutFile,'  DirBuf : Array[0..255] of Char;');
  Inc(VarCount,1);
 End;
 If NeedDosBool Then Begin
  WriteLn(OutFile,'  { Variable temporaire pour GetCBreak/GetVerify }');
  WriteLn(OutFile,'  BoolTmp : Boolean;');
  Inc(VarCount,1);
 End;

 { Variables du segment DATA }
 For I:=1 to DataVarCount do Begin
  If DataVars[I].Section=SEC_CONST Then Continue;
  If DataVars[I].Name='' Then Continue;
  { DUP -> Array }
  If(DataVars[I].ElemCount=1)and
    (DataVars[I].Elements[1].ElemType=DE_DUP)Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : Array[0..',
    DataVars[I].Elements[1].DupCount-1,'] of ',
    DirTypeStr(DataVars[I].DirType),';');
   Inc(VarCount);
  End
  { Chaine Pascal courte (DB longueur,'texte') }
  Else If IsLengthPrefixedString(I) Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : String = ',
    QuotePascalString(DataVars[I].Elements[2].StrValue),';');
   Inc(VarCount);
  End
  { Chaine DB dont le premier element est du texte }
  Else If(DataVars[I].ElemCount>=1)and
    (DataVars[I].Elements[1].ElemType=DE_STRING)Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : String = ',
    QuotePascalString(DataVars[I].Elements[1].StrValue),';');
   Inc(VarCount);
  End
  { Valeur non initialisee }
  Else If(DataVars[I].ElemCount=1)and
    (DataVars[I].Elements[1].ElemType=DE_UNINIT)Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : ',
    DirTypeStr(DataVars[I].DirType),';');
   Inc(VarCount);
  End
  { Valeur simple initialisee -> const typee ou var }
  Else If(DataVars[I].ElemCount=1)and
    (DataVars[I].Elements[1].ElemType=DE_NUMBER)Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : ',
    DirTypeStr(DataVars[I].DirType),';');
   Inc(VarCount);
  End
  { Tableau de valeurs multiples }
  Else If DataVars[I].ElemCount>1 Then Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : Array[0..',
    DataVars[I].ElemCount-1,'] of ',
    DirTypeStr(DataVars[I].DirType),';');
   Inc(VarCount);
  End
  Else Begin
   WriteLn(OutFile,'  ',DataVars[I].Name,' : ',
    PascalTypeStr(DataVars[I].PascalType),';');
   Inc(VarCount);
  End;
 End;
 WriteLn(OutFile);

 { === Declarations Label === }
 HasLabel:=False;
 LabelCount:=0;
 First:=True;
 For I:=1 to SymbolCount do
  If Symbols[I].SymType=SY_LABEL Then Begin
   { Exclure les labels qui sont des noms de procedures }
   If IsProcAlreadyDefined(Symbols[I].Name) Then Continue;
   { Exclure les labels optimises (ex: boucles While) }
   If IsLabelOptimized(Symbols[I].Name) Then Continue;
   If Not HasLabel Then Begin
    Write(OutFile,'Label');
    HasLabel:=True;
   End;
   If Not First Then
    Write(OutFile,',');
   Write(OutFile,' ',Symbols[I].Name);
   First:=False;
   Inc(LabelCount);
   { Nouvelle ligne tous les 8 labels pour la lisibilite }
   If(LabelCount Mod 8=0)Then Begin
    WriteLn(OutFile);
    Write(OutFile,'     ');
   End;
  End;
 If HasLabel Then Begin
  WriteLn(OutFile,';');
  WriteLn(OutFile);
 End;

 { Le fichier reste ouvert pour TODO 22 (ProcessBodyGeneration) }

 { === Statistiques === }
 WriteLn('  Generation de l''en-tete Pascal :');
 WriteLn('    Fichier de sortie : ',OutFileName);
 If UnitList<>'' Then
  WriteLn('    Uses              : ',UnitList)
 Else
  WriteLn('    Uses              : (aucune unite)');
 WriteLn('    Types             : ',TypeCount,' record(s)');
 WriteLn('    Constantes        : ',ConstCount,' constante(s)');
 WriteLn('    Variables         : ',VarCount,' variable(s)');
 WriteLn('    Labels            : ',LabelCount,' label(s)');
 If Verbose Then Begin
  WriteLn('  Details :');
  WriteLn('    INT 21h detecte   : ',ScanForINTCall('21H'));
  WriteLn('    INT 10h detecte   : ',ScanForINTCall('10H'));
  WriteLn('    INT 16h detecte   : ',ScanForINTCall('16H'));
  WriteLn('    Mode              : ',
   Ord(Mode32)*32+(1-Ord(Mode32))*16,' bits');
  WriteLn('    CPU niveau        : ',CpuLevel);
  If MemoryModel<>0 Then Begin
   S:='';
   Case MemoryModel of
    MM_TINY:   S:='TINY';
    MM_SMALL:  S:='SMALL';
    MM_COMPACT:S:='COMPACT';
    MM_MEDIUM: S:='MEDIUM';
    MM_LARGE:  S:='LARGE';
    MM_HUGE:   S:='HUGE';
    MM_FLAT:   S:='FLAT';
   End;
   WriteLn('    Modele memoire    : ',S);
  End;
 End;
End;

{ ============================================================
  Generation du corps des procedures - TODO 22
  ============================================================ }

Function FindTranslationForLine(Line:LongInt):LongInt;
{ Cherche l'index de la traduction pour une ligne source donnee.
  Retourne -1 si aucune traduction n'existe pour cette ligne. }
Var
 I:LongInt;
Begin
 FindTranslationForLine:=-1;
 For I:=0 to TranslationCount-1 do
  If Translations[I].SrcLine=Line Then Begin
   FindTranslationForLine:=I;
   Exit;
  End;
End;

Function IsLineInAnyProc(Line:LongInt):Boolean;
{ Verifie si une ligne source appartient a une procedure. }
Begin
 IsLineInAnyProc:=(FindProcForLine(Line)<>0);
End;

Function ProcReturnType(ProcIdx:Integer):String;
{ Determine le type de retour d'une fonction.
  Si mode 32 bits, retourne LongInt, sinon Word. }
Begin
 If Mode32 Then
  ProcReturnType:='LongInt'
 Else
  ProcReturnType:='Word';
End;

Function IsBodyMnemonic(Const M:String):Boolean;
{ Indique si le mnemonique est gere par TODO 22
  (utilise pour les statistiques de completude). }
Begin
 IsBodyMnemonic:=False; { TODO 22 orchestre, ne traduit pas }
End;

Function IsLastRetInProc(LineIdx:LongInt;ProcIdx:Integer):Boolean;
{ Verifie si le RET a LineIdx est le dernier RET de la procedure.
  Si c'est le cas, il fait partie de l'epilogue et ne doit pas etre traduit.
  Si ce n'est pas le dernier RET, c'est une sortie anticipee qui doit
  etre traduite en Exit; pour permettre l'optimisation If-Then-Begin-End. }
Var
 J:LongInt;
 AsmL2:TAsmLine;
 M:String;
Begin
 IsLastRetInProc:=True;
 If(ProcIdx<1)or(ProcIdx>ProcCount)Then Exit;
 { Chercher un autre RET apres cette ligne dans la meme procedure }
 For J:=LineIdx+1 to Procs[ProcIdx].EndLine do Begin
  If(J<0)or(J>=SrcLineCount)Then Continue;
  If SrcLines[J]=Nil Then Continue;
  ParseInstructionLine(J,AsmL2);
  If AsmL2.IsDirective Then Continue;
  M:=UpCaseStr(AsmL2.Mnemonic);
  If(M='RET')or(M='RETN')or(M='RETF')Then Begin
   { Il y a un autre RET apres, donc ce n'est pas le dernier }
   IsLastRetInProc:=False;
   Exit;
  End;
 End;
 { Aucun autre RET trouve apres, c'est bien le dernier }
End;

Function IsPrologueEpilogueInstr(Var AsmL:TAsmLine;ProcIdx:Integer;
 LineIdx:LongInt):Boolean;
{ Detecte si l'instruction fait partie du prologue ou epilogue
  d'une fonction implicite : PUSH BP, MOV BP,SP, POP BP, RET n.
  Pour RET, seul le DERNIER RET de la procedure est considere comme
  epilogue. Les RET intermediaires sont des sorties anticipees qui
  doivent etre traduites en Exit; pour l'optimisation. }
Var
 M,Op1Str,Op2Str:String;
Begin
 IsPrologueEpilogueInstr:=False;
 If ProcIdx=0 Then Exit;
 M:=UpCaseStr(AsmL.Mnemonic);
 
 { PUSH BP / PUSH EBP }
 If M='PUSH' Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
   Op1Str:=UpCaseStr(AsmL.Op1.Reg);
   If(Op1Str='BP')or(Op1Str='EBP')Then Begin
    IsPrologueEpilogueInstr:=True;
    Exit;
   End;
  End;
 End;
 
 { MOV BP, SP / MOV EBP, ESP }
 If M='MOV' Then Begin
  If(AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32])and
    (AsmL.Op2.OpType in [OT_REG8,OT_REG16,OT_REG32])Then Begin
   Op1Str:=UpCaseStr(AsmL.Op1.Reg);
   Op2Str:=UpCaseStr(AsmL.Op2.Reg);
   If((Op1Str='BP')or(Op1Str='EBP'))and
     ((Op2Str='SP')or(Op2Str='ESP'))Then Begin
    IsPrologueEpilogueInstr:=True;
    Exit;
   End;
  End;
 End;
 
 { POP BP / POP EBP }
 If M='POP' Then Begin
  If AsmL.Op1.OpType in [OT_REG8,OT_REG16,OT_REG32] Then Begin
   Op1Str:=UpCaseStr(AsmL.Op1.Reg);
   If(Op1Str='BP')or(Op1Str='EBP')Then Begin
    IsPrologueEpilogueInstr:=True;
    Exit;
   End;
  End;
 End;
 
 { RET / RETN / RETF : seulement le dernier de la procedure est epilogue }
 If(M='RET')or(M='RETN')or(M='RETF')Then Begin
  { Verifier si c'est le dernier RET de la procedure }
  If IsLastRetInProc(LineIdx,ProcIdx)Then Begin
   IsPrologueEpilogueInstr:=True;
   Exit;
  End;
  { Ce n'est pas le dernier RET, donc c'est une sortie anticipee
    qui doit etre traduite en Exit; }
 End;
End;

Function ReplaceParamBPReferences(Code:String;ProcIdx:Integer):String;
{ Remplace les references Param_BP_N par les vrais noms de parametres.
  Pour convention NEAR:
    16 bits: Param_BP_4 -> Param1, Param_BP_6 -> Param2, etc.
    32 bits: Param_BP_8 -> Param1, Param_BP_12 -> Param2, etc.
  Note: utilise pour les cas non resolus par StackAccessExpr }
Var
 I:Integer;
 ParamName,SearchStr:String;
 Offset:Integer;
 P:Integer;
Begin
 ReplaceParamBPReferences:=Code;
 If ProcIdx=0 Then Exit;
 If Procs[ProcIdx].ParamCount=0 Then Exit;
 
 For I:=1 to Procs[ProcIdx].ParamCount do Begin
  { Calculer l'offset de ce parametre sur la pile (convention NEAR) }
  If Mode32 Then
   Offset:=8+(I-1)*4 { 32 bits: [EBP+8], [EBP+12], ... }
  Else
   Offset:=4+(I-1)*2; { 16 bits: [BP+4], [BP+6], ... }
  
  { Construire le pattern a rechercher }
  SearchStr:='Param_BP_'+IntToStr(Offset);
  ParamName:=Procs[ProcIdx].Params[I].Name;
  
  { Remplacer toutes les occurrences }
  P:=Pos(SearchStr,Code);
  While P>0 do Begin
   Code:=Copy(Code,1,P-1)+ParamName+Copy(Code,P+Length(SearchStr),255);
   P:=Pos(SearchStr,Code);
  End;
 End;
 
 ReplaceParamBPReferences:=Code;
End;

Procedure ProcessBodyGeneration;
{ Genere le corps des procedures et le bloc principal du fichier
  Pascal de sortie. Le fichier OutFile est deja ouvert par
  ProcessHeaderGeneration (TODO 21). }
Var
 I,J,K:Integer;
 ProcIdx:Integer;
 TrIdx:LongInt;
 AsmL:TAsmLine;
 ProcBodyCount:Integer;
 MainBodyCount:Integer;
 FuncCount:Integer;
 InstrInProc:Integer;
 InstrInMain:Integer;
 SrcText:String;
Begin
 ProcBodyCount:=0;
 MainBodyCount:=0;
 FuncCount:=0;
 InstrInProc:=0;
 InstrInMain:=0;

 { === Generation des procedures et fonctions === }
 For I:=1 to ProcCount do Begin
  { Determiner si c'est une fonction (AX/EAX utilise avant RET) }
  If Procs[I].IsFunction or Procs[I].UsesAX Then Begin
   { En-tete de fonction }
   Write(OutFile,'Function ',Procs[I].Name);
   If Procs[I].ParamCount>0 Then Begin
    Write(OutFile,'(');
    For J:=1 to Procs[I].ParamCount do Begin
     If J>1 Then Write(OutFile,'; ');
     Write(OutFile,Procs[I].Params[J].Name,' : ',
      PascalTypeStr(Procs[I].Params[J].PascalType));
    End;
    Write(OutFile,')');
   End;
   Write(OutFile,' : ',ProcReturnType(I),';');
   { Ajouter directive Near ou Far selon le type d'appel }
   If Procs[I].IsNear Then
    WriteLn(OutFile,' Near;')
   Else
    WriteLn(OutFile,' Far;');
   Inc(FuncCount);
  End
  Else Begin
   { En-tete de procedure }
   Write(OutFile,'Procedure ',Procs[I].Name);
   If Procs[I].ParamCount>0 Then Begin
    Write(OutFile,'(');
    For J:=1 to Procs[I].ParamCount do Begin
     If J>1 Then Write(OutFile,'; ');
     Write(OutFile,Procs[I].Params[J].Name,' : ',
      PascalTypeStr(Procs[I].Params[J].PascalType));
    End;
    Write(OutFile,')');
   End;
   Write(OutFile,';');
   { Ajouter directive Near ou Far selon le type d'appel }
   If Procs[I].IsNear Then
    WriteLn(OutFile,' Near;')
   Else
    WriteLn(OutFile,' Far;');
  End;

  { Variables locales }
  If Procs[I].LocalCount>0 Then Begin
   WriteLn(OutFile,'Var');
   For J:=1 to Procs[I].LocalCount do Begin
    If Procs[I].Locals[J].Count>1 Then
     WriteLn(OutFile,'  ',Procs[I].Locals[J].Name,
      ' : Array[0..',Procs[I].Locals[J].Count-1,
      '] of ',PascalTypeStr(Procs[I].Locals[J].PascalType),';')
    Else
     WriteLn(OutFile,'  ',Procs[I].Locals[J].Name,' : ',
      PascalTypeStr(Procs[I].Locals[J].PascalType),';');
   End;
  End;

  { Corps de la procedure }
  WriteLn(OutFile,'Begin');
  K:=0;

  { Verifier si la procedure doit etre remplacee par un appel Strings }
  If Procs[I].StringsReplacement<>'' Then Begin
   { Emettre le corps simplifie avec l'appel a l'unite Strings }
   WriteLn(OutFile,'  { Pattern assembleur remplace par ',
    Procs[I].StringsReplacement,' de l''unite Strings }');
   If Procs[I].StringsReplacement='StrCopy' Then Begin
    If Procs[I].ParamCount>=2 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(',
      Procs[I].Params[2].Name,', ',
      Procs[I].Params[1].Name,');')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(RegDI, RegSI);');
   End
   Else If Procs[I].StringsReplacement='StrLen' Then Begin
    If Procs[I].ParamCount>=1 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(',
      Procs[I].Params[1].Name,');')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(RegDI);');
   End
   Else If Procs[I].StringsReplacement='StrComp' Then Begin
    If Procs[I].ParamCount>=2 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(',
      Procs[I].Params[1].Name,', ',
      Procs[I].Params[2].Name,');')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(RegSI, RegDI);');
   End
   Else If Procs[I].StringsReplacement='StrCat' Then Begin
    If Procs[I].ParamCount>=2 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(',
      Procs[I].Params[2].Name,', ',
      Procs[I].Params[1].Name,');')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(RegDI, RegSI);');
   End
   Else If(Procs[I].StringsReplacement='StrLower')
        or(Procs[I].StringsReplacement='StrUpper')Then Begin
    If Procs[I].ParamCount>=1 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(',
      Procs[I].Params[1].Name,');')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(RegSI);');
   End
   Else If Procs[I].StringsReplacement='StrEnd' Then Begin
    If Procs[I].ParamCount>=1 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(',
      Procs[I].Params[1].Name,');')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := ',
      Procs[I].StringsReplacement,'(RegDI);');
   End
   Else Begin
    { Fonction Strings generique }
    WriteLn(OutFile,'  ',Procs[I].StringsReplacement,';');
   End;
   Inc(K);
  End
  Else Begin
   { Corps normal : traduction instruction par instruction }
   For J:=Procs[I].StartLine to Procs[I].EndLine do Begin
    If(J<0)or(J>=SrcLineCount)Then Continue;
    If SrcLines[J]=Nil Then Continue;

    { Parser la ligne pour extraire le label }
    ParseInstructionLine(J,AsmL);

    { Sauter les directives PROC/ENDP/DB/DW/etc. }
    If AsmL.IsDirective Then Continue;

    { Sauter le prologue/epilogue des fonctions implicites }
    If IsPrologueEpilogueInstr(AsmL,I,J) Then Continue;

    { Emettre le label s'il y en a un (sauf le nom de la proc et les labels optimises) }
    If(AsmL.LabelStr<>'')and
      (UpCaseStr(AsmL.LabelStr)<>UpCaseStr(Procs[I].Name))and
      (FindDataVarByName(AsmL.LabelStr)=0)and
      (Not IsLabelOptimized(AsmL.LabelStr))Then
     WriteLn(OutFile,'  ',AsmL.LabelStr,':');

    { Sauter les lignes sans instruction }
    If AsmL.Mnemonic='' Then Continue;

    { Chercher une traduction pour cette ligne }
    TrIdx:=FindTranslationForLine(J);
    If TrIdx>=0 Then Begin
     If Translations[TrIdx].PascalCode='' Then Continue;
     { Remplacer les references aux parametres }
     SrcText:=ReplaceParamBPReferences(Translations[TrIdx].PascalCode,I);
     If AddComments Then Begin
      If Length(SrcLines[J]^)>40 Then
       WriteLn(OutFile,'  ',SrcText,' { ',Copy(SrcLines[J]^,1,40),'... }')
      Else
       WriteLn(OutFile,'  ',SrcText,' { ',SrcLines[J]^,' }');
     End
     Else
      WriteLn(OutFile,'  ',SrcText);
     Inc(K);
    End
    Else Begin
     { Instruction non traduite : commentaire }
     If SrcLines[J]<>Nil Then
      WriteLn(OutFile,'  { Non traduit: ',SrcLines[J]^,' }');
    End;
   End;

   { Si c'est une fonction, emettre l'affectation du resultat }
   If Procs[I].IsFunction or Procs[I].UsesAX Then Begin
    If Mode32 Then
     WriteLn(OutFile,'  ',Procs[I].Name,' := RegEAX;')
    Else
     WriteLn(OutFile,'  ',Procs[I].Name,' := RegAX;');
   End;
  End;

  WriteLn(OutFile,'End;');
  WriteLn(OutFile);
  Inc(ProcBodyCount);
  Inc(InstrInProc,K);
 End;

 { === Bloc principal BEGIN..END === }
 WriteLn(OutFile,'BEGIN');
 K:=0;
 For I:=0 to SrcLineCount-1 do Begin
  If SrcLines[I]=Nil Then Continue;

  { Sauter les lignes a l'interieur des procedures }
  If IsLineInAnyProc(I) Then Continue;

  { Parser la ligne pour le label }
  ParseInstructionLine(I,AsmL);

  { Sauter les directives (DB/DW/MODEL/SEGMENT/etc.) }
  If AsmL.IsDirective Then Continue;

  { Emettre le label (sauf noms de procedures et donnees) }
  If AsmL.LabelStr<>'' Then Begin
   { Verifier que ce n'est pas un nom de procedure }
   ProcIdx:=0;
   For J:=1 to ProcCount do
    If UpCaseStr(AsmL.LabelStr)=UpCaseStr(Procs[J].Name) Then Begin
     ProcIdx:=J;
     Break;
    End;
   { N'emettre le label que s'il n'est pas un nom de proc et n'est pas optimise }
   If(ProcIdx=0)and(FindDataVarByName(AsmL.LabelStr)=0)and
     (Not IsLabelOptimized(AsmL.LabelStr))Then
    WriteLn(OutFile,'  ',AsmL.LabelStr,':');
  End;

  { Sauter les lignes sans instruction }
  If AsmL.Mnemonic='' Then Continue;

  { Chercher une traduction }
  TrIdx:=FindTranslationForLine(I);
  If TrIdx>=0 Then Begin
   If Translations[TrIdx].PascalCode='' Then Continue;
   If AddComments Then Begin
    SrcText:=SrcLines[I]^;
    If Length(SrcText)>40 Then
     SrcText:=Copy(SrcText,1,40)+'...';
    WriteLn(OutFile,'  ',Translations[TrIdx].PascalCode,
     ' { ',SrcText,' }');
   End
   Else
    WriteLn(OutFile,'  ',Translations[TrIdx].PascalCode);
   Inc(K);
  End
  Else Begin
   { Instruction non traduite : commentaire }
   WriteLn(OutFile,'  { Non traduit: ',SrcLines[I]^,' }');
  End;
 End;
 Inc(MainBodyCount);
 Inc(InstrInMain,K);

 WriteLn(OutFile,'END.');

 { Fermer le fichier de sortie }
 Close(OutFile);

 { === Statistiques === }
 WriteLn('  Generation du corps des procedures :');
 WriteLn('    Procedures        : ',ProcBodyCount);
 WriteLn('    Fonctions         : ',FuncCount);
 WriteLn('    Instr. dans procs : ',InstrInProc);
 WriteLn('    Instr. dans main  : ',InstrInMain);
 WriteLn('    Traductions total : ',TranslationCount);
 If Verbose Then Begin
  WriteLn('  Details par procedure :');
  For I:=1 to ProcCount do Begin
   If Procs[I].IsFunction or Procs[I].UsesAX Then
    Write('    Function ')
   Else
    Write('    Procedure ');
   Write(Procs[I].Name);
   If Procs[I].ParamCount>0 Then
    Write(' (',Procs[I].ParamCount,' params)');
   If Procs[I].LocalCount>0 Then
    Write(' (',Procs[I].LocalCount,' locals)');
   WriteLn(' [lignes ',Procs[I].StartLine,'..',Procs[I].EndLine,']');
  End;
 End;
End;

{ ============================================================
  Fallback ASM inline - TODO 23
  ============================================================ }

Function IsFPUMnemonic(Const M:String):Boolean;
{ Detecte les instructions x87 FPU (non traduisibles en Pascal). }
Var U:String;
Begin
 U:=UpCaseStr(M);
 IsFPUMnemonic:=
  (U='FADD')or(U='FADDP')or(U='FIADD')or
  (U='FSUB')or(U='FSUBP')or(U='FISUB')or
  (U='FSUBR')or(U='FSUBRP')or(U='FISUBR')or
  (U='FMUL')or(U='FMULP')or(U='FIMUL')or
  (U='FDIV')or(U='FDIVP')or(U='FIDIV')or
  (U='FDIVR')or(U='FDIVRP')or(U='FIDIVR')or
  (U='FLD')or(U='FILD')or(U='FBLD')or
  (U='FST')or(U='FSTP')or(U='FIST')or
  (U='FISTP')or(U='FBSTP')or
  (U='FXCH')or(U='FCOM')or(U='FCOMP')or(U='FCOMPP')or
  (U='FTST')or(U='FXAM')or
  (U='FSIN')or(U='FCOS')or(U='FSINCOS')or(U='FSQRT')or
  (U='FPTAN')or(U='FPATAN')or(U='FRNDINT')or
  (U='FABS')or(U='FCHS')or(U='FSCALE')or
  (U='FPREM')or(U='FPREM1')or
  (U='FYL2X')or(U='FYL2XP1')or(U='F2XM1')or
  (U='FLDZ')or(U='FLD1')or(U='FLDPI')or
  (U='FLDL2E')or(U='FLDL2T')or(U='FLDLG2')or(U='FLDLN2')or
  (U='FINIT')or(U='FNINIT')or(U='FCLEX')or(U='FNCLEX')or
  (U='FSAVE')or(U='FNSAVE')or(U='FRSTOR')or
  (U='FSTCW')or(U='FNSTCW')or(U='FLDCW')or
  (U='FSTSW')or(U='FNSTSW')or(U='FSTENV')or(U='FNSTENV')or
  (U='FLDENV')or(U='FNOP')or
  (U='FUCOM')or(U='FUCOMP')or(U='FUCOMPP')or
  (U='FUCOMI')or(U='FUCOMIP')or(U='FCOMI')or(U='FCOMIP')or
  (U='FDECSTP')or(U='FINCSTP')or(U='FFREE')or
  (U='FISTTP')or(U='FCMOVB')or(U='FCMOVE')or
  (U='FCMOVBE')or(U='FCMOVU')or(U='FCMOVNB')or
  (U='FCMOVNE')or(U='FCMOVNBE')or(U='FCMOVNU');
End;

Function IsIOPrivMnemonic(Const M:String):Boolean;
{ Detecte les instructions E/S et privilegiees non traduisibles. }
Var U:String;
Begin
 U:=UpCaseStr(M);
 IsIOPrivMnemonic:=
  (U='CLI')or(U='STI')or(U='HLT')or
  (U='IN')or(U='OUT')or
  (U='INSB')or(U='INSW')or(U='INSD')or
  (U='OUTSB')or(U='OUTSW')or(U='OUTSD')or
  (U='CPUID')or(U='RDTSC')or(U='RDMSR')or
  (U='WRMSR')or(U='RDPMC')or
  (U='LGDT')or(U='LIDT')or(U='LLDT')or
  (U='SGDT')or(U='SIDT')or(U='SLDT')or
  (U='INVLPG')or(U='WBINVD')or(U='INVD')or
  (U='CLTS')or(U='LMSW')or(U='SMSW')or
  (U='ARPL')or(U='VERR')or(U='VERW')or
  (U='LAR')or(U='LSL');
End;

Function AsmOperandStr(Var Op:TOperand):String;
{ Reconstruit le texte d'un operande pour ASM inline. }
Var S:String;
Begin
 If Op.Reg<>'' Then Begin
  AsmOperandStr:=Op.Reg;
  Exit;
 End;
 If Op.MemExpr<>'' Then Begin
  AsmOperandStr:='['+Op.MemExpr+']';
  Exit;
 End;
 { Adressage indexe : BaseReg+IndexReg ou BaseReg seul }
 If Op.BaseReg<>'' Then Begin
  S:='['+Op.BaseReg;
  If Op.IndexReg<>'' Then S:=S+'+'+Op.IndexReg;
  If Op.HasDisp Then Begin
   If Op.Disp>=0 Then S:=S+'+'+IntToStr(Op.Disp)
   Else S:=S+IntToStr(Op.Disp);
  End;
  S:=S+']';
  AsmOperandStr:=S;
  Exit;
 End;
 If Op.LabelName<>'' Then Begin
  AsmOperandStr:=Op.LabelName;
  Exit;
 End;
 If Op.OpType In [OT_IMM8,OT_IMM16,OT_IMM32] Then Begin
  AsmOperandStr:=IntToStr(Op.Imm);
  Exit;
 End;
 AsmOperandStr:='';
End;

Function AsmInlineInstr(Var AsmL:TAsmLine):String;
{ Reconstruit le texte d'instruction assembleur depuis TAsmLine.
  Retourne MNEMONIC OP1,OP2 ou MNEMONIC OP1 ou MNEMONIC.
  Si le mnemonique est inconnu (???), genere un commentaire. }
Var
 S,Op1S,Op2S:String;
Begin
 { Instruction non decodee : generer un commentaire }
 If AsmL.Mnemonic='???' Then Begin
  Op1S:=AsmOperandStr(AsmL.Op1);
  If Op1S<>'' Then
   AsmInlineInstr:='{ ??? '+Op1S+' }'
  Else
   AsmInlineInstr:='{ ??? }';
  Exit;
 End;
 S:=AsmL.Mnemonic;
 Op1S:=AsmOperandStr(AsmL.Op1);
 If Op1S<>'' Then Begin
  S:=S+' '+Op1S;
  Op2S:=AsmOperandStr(AsmL.Op2);
  If Op2S<>'' Then
   S:=S+','+Op2S;
 End;
 AsmInlineInstr:=S;
End;

Function IsInlineMnemonic(Const M:String):Boolean;
{ Indique si le mnemonique est gere par TODO 23
  (instruction necessitant un fallback ASM inline). }
Begin
 IsInlineMnemonic:=IsFPUMnemonic(M) or IsIOPrivMnemonic(M);
End;

Procedure ProcessInlineFallback;
{ Pour les instructions sans traduction Pascal directe,
  generer un fallback en ASM inline si UseInline est active.
  Regroupe les instructions consecutives dans un seul bloc asm.
  Insere un commentaire avertissant que le code n'a pas pu
  etre traduit. }
Var
 I,J:Integer;
 AsmL:TAsmLine;
 GroupStart,GroupEnd:Integer;
 InlineCount,GroupCount:Integer;
 FPUCount,IOPrivCount,OtherCount:Integer;
 Instr:String;
Begin
 If Not UseInline Then Begin
  WriteLn('  Fallback ASM inline : desactive (-noinline)');
  Exit;
 End;

 InlineCount:=0;
 GroupCount:=0;
 FPUCount:=0;
 IOPrivCount:=0;
 OtherCount:=0;

 I:=0;
 While I<SrcLineCount do Begin
  If SrcLines[I]=Nil Then Begin Inc(I); Continue; End;

  { Parser la ligne }
  ParseInstructionLine(I,AsmL);
  If AsmL.IsDirective or(AsmL.Mnemonic='')Then Begin
   Inc(I);
   Continue;
  End;

  { Verifier si cette instruction a deja une traduction }
  If FindTranslationForLine(I)>=0 Then Begin
   Inc(I);
   Continue;
  End;

  { Instruction non traduite trouvee - chercher la fin du groupe }
  GroupStart:=I;
  GroupEnd:=I;
  J:=I+1;
  While J<SrcLineCount do Begin
   If SrcLines[J]=Nil Then Break;
   ParseInstructionLine(J,AsmL);
   If AsmL.IsDirective or(AsmL.Mnemonic='')Then Break;
   If FindTranslationForLine(J)>=0 Then Break;
   GroupEnd:=J;
   Inc(J);
  End;

  { Generer les traductions ASM inline pour le groupe }
  If GroupStart=GroupEnd Then Begin
   { Instruction isolee : asm INSTR; end; sur une seule ligne }
   ParseInstructionLine(GroupStart,AsmL);
   Instr:=AsmInlineInstr(AsmL);
   { Instruction non decodee '???' : commentaire Pascal seul }
   If AsmL.Mnemonic='???' Then
    AddTranslation(GroupStart,Instr+';',AsmL.Mnemonic)
   Else
    AddTranslation(GroupStart,
     'asm '+Instr+'; end;',AsmL.Mnemonic);
   If IsFPUMnemonic(AsmL.Mnemonic) Then Inc(FPUCount)
   Else If IsIOPrivMnemonic(AsmL.Mnemonic) Then Inc(IOPrivCount)
   Else Inc(OtherCount);
   Inc(InlineCount);
  End
  Else Begin
   { Groupe de N instructions consecutives non traduites :
     Les instructions ??? sont des commentaires Pascal,
     les autres vont dans un ou des blocs asm...end. }
   Inc(GroupCount);
   For J:=GroupStart to GroupEnd do Begin
    ParseInstructionLine(J,AsmL);
    Instr:=AsmInlineInstr(AsmL);
    If IsFPUMnemonic(AsmL.Mnemonic) Then Inc(FPUCount)
    Else If IsIOPrivMnemonic(AsmL.Mnemonic) Then Inc(IOPrivCount)
    Else Inc(OtherCount);
    { Instruction non decodee '???' : commentaire Pascal seul }
    If AsmL.Mnemonic='???' Then
     AddTranslation(J,Instr+';',AsmL.Mnemonic)
    Else
     AddTranslation(J,'asm '+Instr+'; end;',AsmL.Mnemonic);
    Inc(InlineCount);
   End;
  End;

  I:=GroupEnd+1;
 End;

 { Statistiques }
 WriteLn('  Fallback ASM inline :');
 WriteLn('    Instructions inline : ',InlineCount);
 WriteLn('    Blocs groupes       : ',GroupCount);
 If Verbose Then Begin
  WriteLn('  Details par categorie :');
  WriteLn('    FPU x87        : ',FPUCount);
  WriteLn('    E/S et systeme : ',IOPrivCount);
  WriteLn('    Autres         : ',OtherCount);
 End;
End;

{ ============================================================
  Passes d'optimisation - TODO 24
  ============================================================ }

Function IsRegVar(Const S:String):Boolean;
{ Verifie si S est un nom de variable registre simule. }
Var U:String;
Begin
 U:=UpCaseStr(S);
 IsRegVar:=(U='REGAX')or(U='REGBX')or(U='REGCX')or(U='REGDX')
  or(U='REGSI')or(U='REGDI')or(U='REGBP')or(U='REGSP')
  or(U='REGEAX')or(U='REGEBX')or(U='REGECX')or(U='REGEDX')
  or(U='REGESI')or(U='REGEDI')or(U='REGEBP')or(U='REGESP');
End;

Function IsConstValue(Const S:String):Boolean;
{ Verifie si S est un litteral constant (entier, $hex, True, False). }
Var I:Integer; U:String;
Begin
 U:=Trim(S);
 If Length(U)=0 Then Begin IsConstValue:=False; Exit; End;
 If(U='True')or(U='False')Then Begin IsConstValue:=True; Exit; End;
 If U[1]='$' Then Begin
  IsConstValue:=True;
  For I:=2 to Length(U) do
   If Not(U[I] in ['0'..'9','A'..'F','a'..'f'])Then Begin
    IsConstValue:=False; Exit;
   End;
  If Length(U)<2 Then IsConstValue:=False;
  Exit;
 End;
 IsConstValue:=True;
 For I:=1 to Length(U) do
  If Not(U[I] in ['0'..'9'])Then Begin
   IsConstValue:=False; Exit;
  End;
End;

Function SplitAssign(Const Code:String; Var LHS,RHS:String):Boolean;
{ Separe 'LHS := RHS;' en ses deux parties. }
Var P:Integer; S:String;
Begin
 SplitAssign:=False;
 S:=Trim(Code);
 P:=Pos(':=',S);
 If P<2 Then Exit;
 LHS:=Trim(Copy(S,1,P-1));
 RHS:=Trim(Copy(S,P+2,255));
 If(Length(RHS)>0)and(RHS[Length(RHS)]=';')Then
  RHS:=Trim(Copy(RHS,1,Length(RHS)-1));
 SplitAssign:=(Length(LHS)>0)and(Length(RHS)>0);
End;

Function ReplaceInStr(Const S,Old,New:String):String;
{ Remplace la premiere occurrence de Old par New dans S. }
Var P:Integer;
Begin
 P:=Pos(Old,S);
 If P=0 Then ReplaceInStr:=S
 Else ReplaceInStr:=Copy(S,1,P-1)+New+Copy(S,P+Length(Old),255);
End;

Procedure OptIdiomatic(Var OptCount:Integer);
{ (f) Patterns idiomatiques : X xor X -> 0, X or X -> nop. }
Var
 I:Integer;
 LHS,RHS:String;
Begin
 OptCount:=0;
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  If Not SplitAssign(Translations[I].PascalCode,LHS,RHS)Then Continue;
  If RHS=LHS+' xor '+LHS Then Begin
   Translations[I].PascalCode:=LHS+' := 0;';
   Inc(OptCount);
  End
  Else If RHS=LHS+' or '+LHS Then Begin
   Translations[I].PascalCode:='{ opt: '+LHS+' or self = nop }';
   Inc(OptCount);
  End;
 End;
End;

Procedure OptConstProp(Var OptCount:Integer);
{ (b) Propagation de constantes entre traductions consecutives.
  RegAX := 0; x := RegAX -> x := 0 }
Var
 I,J,P:Integer;
 LHS1,RHS1,LHS2,RHS2,NewRHS:String;
Begin
 OptCount:=0;
 For I:=0 to TranslationCount-2 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  If Not SplitAssign(Translations[I].PascalCode,LHS1,RHS1)Then Continue;
  If Not IsRegVar(LHS1)Then Continue;
  If Not IsConstValue(RHS1)Then Continue;
  J:=I+1;
  If Not Translations[J].IsTranslated Then Continue;
  If Not SplitAssign(Translations[J].PascalCode,LHS2,RHS2)Then Continue;
  If UpCaseStr(LHS2)=UpCaseStr(LHS1)Then Continue;
  P:=Pos(LHS1,RHS2);
  If P>0 Then Begin
   NewRHS:=ReplaceInStr(RHS2,LHS1,RHS1);
   Translations[J].PascalCode:=LHS2+' := '+NewRHS+';';
   Inc(OptCount);
  End;
 End;
End;

Function IsZeroVal(Const S:String):Boolean;
{ Verifie si S represente zero (0, $0, $00, $0000, $00000000). }
Var U:String; I:Integer; AllZero:Boolean;
Begin
 U:=Trim(S);
 If U='0' Then Begin IsZeroVal:=True; Exit; End;
 If(Length(U)>1)and(U[1]='$')Then Begin
  AllZero:=True;
  For I:=2 to Length(U) do
   If U[I]<>'0' Then AllZero:=False;
  IsZeroVal:=AllZero and(Length(U)>=2);
  Exit;
 End;
 IsZeroVal:=False;
End;

Function IsOneVal(Const S:String):Boolean;
{ Verifie si S represente un (1, $1, $01, $0001, $00000001). }
Var U:String; I:Integer;
Begin
 U:=Trim(S);
 If U='1' Then Begin IsOneVal:=True; Exit; End;
 If(Length(U)>1)and(U[1]='$')Then Begin
  If U[Length(U)]<>'1' Then Begin IsOneVal:=False; Exit; End;
  For I:=2 to Length(U)-1 do
   If U[I]<>'0' Then Begin IsOneVal:=False; Exit; End;
  IsOneVal:=True;
  Exit;
 End;
 IsOneVal:=False;
End;

Procedure OptSimplify(Var OptCount:Integer);
{ (c) Simplification : x + 0 -> nop, x + 1 -> Inc(x),
  x - 0 -> nop, x - 1 -> Dec(x), x * 1 -> nop, x or 0 -> nop. }
Var
 I:Integer;
 LHS,RHS,Tail:String;
Begin
 OptCount:=0;
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  If Not SplitAssign(Translations[I].PascalCode,LHS,RHS)Then Continue;
  If Pos(LHS+' + ',RHS)=1 Then Begin
   Tail:=Trim(Copy(RHS,Length(LHS)+4,255));
   If IsZeroVal(Tail)Then Begin
    Translations[I].PascalCode:='{ opt: '+LHS+' + 0 = nop }';
    Inc(OptCount);
   End Else If IsOneVal(Tail)Then Begin
    Translations[I].PascalCode:='Inc('+LHS+');';
    Inc(OptCount);
   End;
  End
  Else If Pos(LHS+' - ',RHS)=1 Then Begin
   Tail:=Trim(Copy(RHS,Length(LHS)+4,255));
   If IsZeroVal(Tail)Then Begin
    Translations[I].PascalCode:='{ opt: '+LHS+' - 0 = nop }';
    Inc(OptCount);
   End Else If IsOneVal(Tail)Then Begin
    Translations[I].PascalCode:='Dec('+LHS+');';
    Inc(OptCount);
   End;
  End
  Else If Pos(LHS+' or ',RHS)=1 Then Begin
   Tail:=Trim(Copy(RHS,Length(LHS)+5,255));
   If IsZeroVal(Tail)Then Begin
    Translations[I].PascalCode:='{ opt: '+LHS+' or 0 = nop }';
    Inc(OptCount);
   End;
  End
  Else If(RHS=LHS+' and $FFFF')or(RHS=LHS+' and $FFFFFFFF')Then Begin
   Translations[I].PascalCode:='{ opt: '+LHS+' and max = nop }';
   Inc(OptCount);
  End
  Else If Pos(LHS+' * ',RHS)=1 Then Begin
   Tail:=Trim(Copy(RHS,Length(LHS)+4,255));
   If IsOneVal(Tail)Then Begin
    Translations[I].PascalCode:='{ opt: '+LHS+' * 1 = nop }';
    Inc(OptCount);
   End;
  End;
 End;
End;

Procedure AddOptLabel(Const LabelName:String);
{ Ajoute un label a la liste des labels optimises
  (qui ne doivent pas etre emis dans ProcessBodyGeneration). }
Begin
 If OptLabelCount>=MAX_OPT_LABELS Then Exit;
 Inc(OptLabelCount);
 OptLabels[OptLabelCount]:=LabelName;
End;

Function IsLabelOptimized(Const LabelName:String):Boolean;
{ Verifie si un label est dans la liste des labels optimises. }
Var
 I:Integer;
 U:String;
Begin
 IsLabelOptimized:=False;
 U:=UpCaseStr(LabelName);
 For I:=1 to OptLabelCount do
  If UpCaseStr(OptLabels[I])=U Then Begin
   IsLabelOptimized:=True;
   Exit;
  End;
End;

Function CountLabelReferences(Const LabelName:String):Integer;
{ Compte le nombre de references a un label dans les traductions.
  Exclut la declaration du label lui-meme. }
Var
 I:Integer;
 U:String;
 Count:Integer;
Begin
 Count:=0;
 U:=UpCaseStr(LabelName);
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  { Chercher "Goto label" ou "Then Goto label" }
  If Pos('Goto '+U,UpCaseStr(Translations[I].PascalCode))>0 Then
   Inc(Count);
 End;
 CountLabelReferences:=Count;
End;

Function FindLabelSrcLine(LabelName:String):LongInt;
{ Trouve la ligne source contenant un label donne.
  Retourne -1 si le label n'est pas trouve. }
Var
 I:LongInt;
 AsmL:TAsmLine;
Begin
 FindLabelSrcLine:=-1;
 For I:=0 to SrcLineCount-1 do Begin
  If SrcLines[I]=Nil Then Continue;
  ParseInstructionLine(I,AsmL);
  If UpCaseStr(AsmL.LabelStr)=UpCaseStr(LabelName) Then Begin
   FindLabelSrcLine:=I;
   Exit;
  End;
 End;
End;

Function InvertCondition(Const Cond:String):String;
{ Inverse une condition de comparaison Pascal.
  = -> <>, <> -> =, < -> >=, > -> <=, <= -> >, >= -> < }
Begin
 If Cond='=' Then InvertCondition:='<>'
 Else If Cond='<>' Then InvertCondition:='='
 Else If Cond='<' Then InvertCondition:='>='
 Else If Cond='>' Then InvertCondition:='<='
 Else If Cond='<=' Then InvertCondition:='>'
 Else If Cond='>=' Then InvertCondition:='<'
 Else InvertCondition:=Cond;
End;

Function InvertFlagExpr(Const FExpr:String):String;
{ Inverse une expression sur les flags.
  FlagXX -> not FlagXX, not FlagXX -> FlagXX }
Begin
 If Pos('not ',FExpr)=1 Then
  InvertFlagExpr:=Copy(FExpr,5,255)
 Else If(Length(FExpr)>0)and(FExpr[1]='(')Then
  InvertFlagExpr:='not '+FExpr
 Else
  InvertFlagExpr:='not ('+FExpr+')';
End;

Function ParseIfCondition(Const Code:String;Var CondA,CondOp,CondB:String):Boolean;
{ Parse une instruction If pour extraire la condition.
  Format: If A op B Then Goto label;
  Retourne True si le parsing a reussi. }
Var
 P1,P2:Integer;
 CondPart:String;
Begin
 ParseIfCondition:=False;
 CondA:=''; CondOp:=''; CondB:='';
 If Pos('If ',Code)<>1 Then Exit;
 P1:=Pos(' Then ',Code);
 If P1=0 Then Exit;
 CondPart:=Trim(Copy(Code,4,P1-4));
 { Chercher l'operateur de comparaison }
 P2:=Pos(' <> ',CondPart);
 If P2>0 Then Begin
  CondA:=Trim(Copy(CondPart,1,P2-1));
  CondOp:='<>';
  CondB:=Trim(Copy(CondPart,P2+4,255));
  ParseIfCondition:=True;
  Exit;
 End;
 P2:=Pos(' <= ',CondPart);
 If P2>0 Then Begin
  CondA:=Trim(Copy(CondPart,1,P2-1));
  CondOp:='<=';
  CondB:=Trim(Copy(CondPart,P2+4,255));
  ParseIfCondition:=True;
  Exit;
 End;
 P2:=Pos(' >= ',CondPart);
 If P2>0 Then Begin
  CondA:=Trim(Copy(CondPart,1,P2-1));
  CondOp:='>=';
  CondB:=Trim(Copy(CondPart,P2+4,255));
  ParseIfCondition:=True;
  Exit;
 End;
 P2:=Pos(' < ',CondPart);
 If P2>0 Then Begin
  CondA:=Trim(Copy(CondPart,1,P2-1));
  CondOp:='<';
  CondB:=Trim(Copy(CondPart,P2+3,255));
  ParseIfCondition:=True;
  Exit;
 End;
 P2:=Pos(' > ',CondPart);
 If P2>0 Then Begin
  CondA:=Trim(Copy(CondPart,1,P2-1));
  CondOp:='>';
  CondB:=Trim(Copy(CondPart,P2+3,255));
  ParseIfCondition:=True;
  Exit;
 End;
 P2:=Pos(' = ',CondPart);
 If P2>0 Then Begin
  CondA:=Trim(Copy(CondPart,1,P2-1));
  CondOp:='=';
  CondB:=Trim(Copy(CondPart,P2+3,255));
  ParseIfCondition:=True;
  Exit;
 End;
 { Expression sur flags (If FlagXX Then ou If not FlagXX Then) }
 If(Length(CondPart)>0)and(Pos('GOTO',UpCaseStr(CondPart))=0)Then Begin
  CondA:=CondPart;
  CondOp:='';
  CondB:='';
  ParseIfCondition:=True;
 End;
End;

Procedure OptGotoToIfBeginEnd(Var OptCount:Integer);
{ Transforme les patterns If...Then Goto label; suivi de code puis
  Exit; puis label: en bloc If (condition inversee) Then Begin...End.
  Cette optimisation produit un code Pascal plus lisible. }
Var
 I,J:LongInt;
 Code,Lbl:String;
 P:Integer;
 LabelLine:LongInt;
 ExitIdx:LongInt;
 CondA,CondOp,CondB:String;
 InvOp:String;
 NewCond:String;
 LastExitIdx:LongInt;
 LastExitLine:LongInt;
Begin
 OptCount:=0;
 I:=0;
 While I<TranslationCount do Begin
  If Not Translations[I].IsTranslated Then Begin
   Inc(I);
   Continue;
  End;
  Code:=Translations[I].PascalCode;
  { Chercher If ... Then Goto label; }
  If(Pos('If ',Code)=1)and(Pos('Then Goto ',Code)>0)Then Begin
   P:=Pos('Then Goto ',Code);
   Lbl:=Trim(Copy(Code,P+10,255));
   If(Length(Lbl)>0)and(Lbl[Length(Lbl)]=';')Then
    Lbl:=Copy(Lbl,1,Length(Lbl)-1);
   { Trouver la ligne source du label }
   LabelLine:=FindLabelSrcLine(Lbl);
   If LabelLine<0 Then Begin
    Inc(I);
    Continue;
   End;
   { Chercher le dernier Exit; dont la ligne source est AVANT le label }
   LastExitIdx:=-1;
   LastExitLine:=-1;
   For J:=I+1 to TranslationCount-1 do Begin
    If Not Translations[J].IsTranslated Then Continue;
    { Ne considerer que les traductions AVANT le label }
    If Translations[J].SrcLine>=LabelLine Then Continue;
    { Verifier si c'est Exit; }
    If Translations[J].PascalCode='Exit;' Then Begin
     { Garder le dernier Exit; avant le label (plus proche du label) }
     If Translations[J].SrcLine>LastExitLine Then Begin
      LastExitIdx:=J;
      LastExitLine:=Translations[J].SrcLine;
     End;
    End;
   End;
   { Si on a trouve un Exit; valide, effectuer la transformation }
   If LastExitIdx>I Then Begin
    ExitIdx:=LastExitIdx;
    { Parser la condition }
    If ParseIfCondition(Code,CondA,CondOp,CondB)Then Begin
     { Inverser la condition }
     If CondOp<>'' Then Begin
      InvOp:=InvertCondition(CondOp);
      NewCond:='If '+CondA+' '+InvOp+' '+CondB+' Then Begin';
     End Else Begin
      { Expression sur flags }
      NewCond:='If '+InvertFlagExpr(CondA)+' Then Begin';
     End;
     { Modifier la traduction du If }
     Translations[I].PascalCode:=NewCond;
     { Modifier Exit; en End; }
     Translations[ExitIdx].PascalCode:='End;';
     Inc(OptCount);
     { Verifier si le label n'est plus reference ailleurs
       et le marquer comme optimise pour ne pas l'emettre }
     If CountLabelReferences(Lbl)=0 Then
      AddOptLabel(Lbl);
    End;
   End;
  End;
  Inc(I);
 End;
End;

Procedure OptGotoDetect(Var CandidCount:Integer);
{ (d) Detecte les Goto pouvant etre remplaces par des structures. }
Var
 I,J,P:Integer;
 Code,Lbl:String;
Begin
 CandidCount:=0;
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  Code:=Translations[I].PascalCode;
  If(Pos('If ',Code)=1)and(Pos('Then Goto ',Code)>0)Then Begin
   P:=Pos('Then Goto ',Code);
   Lbl:=Trim(Copy(Code,P+10,255));
   If(Length(Lbl)>0)and(Lbl[Length(Lbl)]=';')Then
    Lbl:=Copy(Lbl,1,Length(Lbl)-1);
   For J:=I+1 to TranslationCount-1 do Begin
    If Not Translations[J].IsTranslated Then Continue;
    If Pos(Lbl+':',Translations[J].PascalCode)>0 Then Begin
     Inc(CandidCount);
     Break;
    End;
   End;
  End;
 End;
End;

Procedure OptSubRegFusion(Var OptCount:Integer);
{ (e) Fusion Lo/Hi : Lo(R) := v; Hi(R) := 0 -> R := Word(v). }
Var
 I,J,P1:Integer;
 Code1,Code2,RegN,LoVal:String;
Begin
 OptCount:=0;
 For I:=0 to TranslationCount-2 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  Code1:=Translations[I].PascalCode;
  If Pos('Lo(',Code1)<>1 Then Continue;
  P1:=Pos(') :=',Code1);
  If P1<5 Then Continue;
  RegN:=Copy(Code1,4,P1-4);
  If Not IsRegVar(RegN)Then Continue;
  LoVal:=Trim(Copy(Code1,P1+4,255));
  If(Length(LoVal)>0)and(LoVal[Length(LoVal)]=';')Then
   LoVal:=Trim(Copy(LoVal,1,Length(LoVal)-1));
  J:=I+1;
  If Not Translations[J].IsTranslated Then Continue;
  Code2:=Translations[J].PascalCode;
  If Code2='Hi('+RegN+') := 0;' Then Begin
   Translations[I].PascalCode:=RegN+' := Word('+LoVal+');';
   Translations[J].PascalCode:='{ opt: Hi('+RegN+') fusionne }';
   Inc(OptCount);
  End;
 End;
End;

Function IsLoopPattern(Const Code:String;
                       Var CxVar,Lbl,ExtraCond:String):Boolean;
{ Detecte si Code est un pattern de boucle LOOP traduit:
  - "Begin Dec(RegCX); If RegCX <> 0 Then Goto label; End;"
  - "Begin Dec(RegECX); If RegECX <> 0 Then Goto label; End;"
  - Variantes LOOPE/LOOPNE avec FlagZF
  Retourne True si detecte, avec le nom du registre CX, le label cible,
  et une eventuelle condition supplementaire (FlagZF). }
Var
 P1,P2,P3:Integer;
 TmpCx,TmpLbl:String;
Begin
 IsLoopPattern:=False;
 CxVar:='';
 Lbl:='';
 ExtraCond:='';
 
 { Verifier le debut "Begin Dec(" }
 If Pos('Begin Dec(',Code)<>1 Then Exit;
 
 { Trouver la fin du Dec() }
 P1:=Pos('); If ',Code);
 If P1<12 Then Exit;
 
 { Extraire le registre CX }
 TmpCx:=Copy(Code,11,P1-11);
 If(TmpCx<>'RegCX')and(TmpCx<>'RegECX')Then Exit;
 
 { Verifier la condition et extraire le label }
 P2:=Pos(' Then Goto ',Code);
 If P2<P1 Then Exit;
 
 { Trouver la fin du label }
 P3:=Pos('; End;',Code);
 If P3<P2 Then Exit;
 
 { Extraire le label }
 TmpLbl:=Trim(Copy(Code,P2+11,P3-P2-11));
 If Length(TmpLbl)=0 Then Exit;
 
 { Verifier la condition : <> 0 simple ou avec FlagZF }
 { Pattern simple: "If RegCX <> 0 Then Goto" }
 If Pos('If '+TmpCx+' <> 0 Then Goto',Code)>0 Then Begin
  CxVar:=TmpCx;
  Lbl:=TmpLbl;
  ExtraCond:='';
  IsLoopPattern:=True;
  Exit;
 End;
 
 { Pattern LOOPE: "If (RegCX <> 0) and FlagZF Then Goto" }
 If Pos('If ('+TmpCx+' <> 0) and FlagZF Then Goto',Code)>0 Then Begin
  CxVar:=TmpCx;
  Lbl:=TmpLbl;
  ExtraCond:=' and FlagZF';
  IsLoopPattern:=True;
  Exit;
 End;
 
 { Pattern LOOPNE: "If (RegCX <> 0) and not FlagZF Then Goto" }
 If Pos('If ('+TmpCx+' <> 0) and not FlagZF Then Goto',Code)>0 Then Begin
  CxVar:=TmpCx;
  Lbl:=TmpLbl;
  ExtraCond:=' and not FlagZF';
  IsLoopPattern:=True;
  Exit;
 End;
End;

Function FindFirstTranslationAfterLine(Line:LongInt):LongInt;
{ Trouve l'index de la premiere traduction dont la ligne source
  est >= Line. Retourne -1 si aucune trouvee. }
Var
 I:LongInt;
 BestIdx:LongInt;
 BestLine:LongInt;
Begin
 FindFirstTranslationAfterLine:=-1;
 BestIdx:=-1;
 BestLine:=MaxLongInt;
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  If(Translations[I].SrcLine>=Line)and(Translations[I].SrcLine<BestLine)Then Begin
   BestIdx:=I;
   BestLine:=Translations[I].SrcLine;
  End;
 End;
 FindFirstTranslationAfterLine:=BestIdx;
End;

Procedure OptLoopToWhile(Var OptCount:Integer);
{ Reconstruction des boucles While a partir des patterns LOOP:
  Begin Dec(RegCX); If RegCX <> 0 Then Goto label; End
  devient une structure While si le label est un saut arriere.
  
  Transformation:
  - Le label devient: While CxVar <> 0 do Begin
  - Les instructions entre label et LOOP restent intactes
  - Le LOOP devient: Dec(CxVar); End (* While *) }
Var
 I:LongInt;
 Code:String;
 CxVar,Lbl,ExtraCond:String;
 LabelSrcLine:LongInt;
 FirstTrIdx:LongInt;
 WhileCond:String;
Begin
 OptCount:=0;
 
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  Code:=Translations[I].PascalCode;
  
  { Detecter le pattern de boucle LOOP }
  If Not IsLoopPattern(Code,CxVar,Lbl,ExtraCond)Then Continue;
  
  { Chercher la ligne source du label (saut arriere) }
  LabelSrcLine:=FindLabelSrcLine(Lbl);
  If LabelSrcLine<0 Then Continue;
  
  { Verifier que le label est AVANT la traduction actuelle (saut arriere) }
  If LabelSrcLine>=Translations[I].SrcLine Then Continue;
  
  { Verifier que le label n'est pas reference ailleurs que par ce LOOP }
  { Pour simplifier, on accepte si le label est reference une seule fois }
  If CountLabelReferences(Lbl)>1 Then Continue;
  
  { Construire la condition While }
  If ExtraCond='' Then
   WhileCond:='While '+CxVar+' <> 0 do Begin'
  Else
   WhileCond:='While ('+CxVar+' <> 0)'+ExtraCond+' do Begin';
  
  { Trouver la premiere traduction apres le label (premiere instruction du corps) }
  FirstTrIdx:=FindFirstTranslationAfterLine(LabelSrcLine);
  If(FirstTrIdx>=0)and(FirstTrIdx<I)Then Begin
   { Prefixer cette traduction avec While ... do Begin }
   Translations[FirstTrIdx].PascalCode:=
    WhileCond+' '+Translations[FirstTrIdx].PascalCode;
  End
  Else Begin
   { Pas de traduction entre le label et le LOOP, cas rare }
   { On ne peut pas optimiser dans ce cas }
   Continue;
  End;
  
  { Modifier la traduction du LOOP : Dec() + End }
  Translations[I].PascalCode:='Dec('+CxVar+'); End; { While '+Lbl+' }';
  
  { Marquer le label comme optimise (ne pas generer le Label) }
  AddOptLabel(Lbl);
  
  Inc(OptCount);
 End;
End;

Procedure OptUnusedRegs(Var UnusedCount:Integer);
{ (a) Detecte les registres ecrits mais jamais lus. }
Const
 REG_NAMES:Array[1..16] of String[8] = (
  'RegAX','RegBX','RegCX','RegDX',
  'RegSI','RegDI','RegBP','RegSP',
  'RegEAX','RegEBX','RegECX','RegEDX',
  'RegESI','RegEDI','RegEBP','RegESP');
Var
 R,I:Integer;
 WrCount,RdCount:Integer;
 LHS,RHS:String;
Begin
 UnusedCount:=0;
 For R:=1 to 16 do Begin
  WrCount:=0;
  RdCount:=0;
  For I:=0 to TranslationCount-1 do Begin
   If Not Translations[I].IsTranslated Then Continue;
   If SplitAssign(Translations[I].PascalCode,LHS,RHS)Then Begin
    If LHS=REG_NAMES[R] Then Inc(WrCount);
    If Pos(REG_NAMES[R],RHS)>0 Then Inc(RdCount);
   End Else Begin
    If Pos(REG_NAMES[R],Translations[I].PascalCode)>0 Then
     Inc(RdCount);
   End;
  End;
  If(WrCount>0)and(RdCount=0)Then Inc(UnusedCount);
 End;
End;

Function IsOptMnemonic(Const M:String):Boolean;
{ Indique si le mnemonique est gere par TODO 24
  (l'optimisation agit sur les traductions, pas sur les mnemoniques). }
Begin
 IsOptMnemonic:=False;
End;

Procedure ProcessOptimization;
{ Passe d'optimisation sur les traductions Pascal generees. }
Var
 IdiomCount,ConstPropCount,SimplifyCount:Integer;
 SubRegCount,GotoCount,GotoBlockCount,UnusedCount,TotalOpt:Integer;
 LoopWhileCount:Integer;
Begin
 OptIdiomatic(IdiomCount);
 OptConstProp(ConstPropCount);
 OptSimplify(SimplifyCount);
 OptSubRegFusion(SubRegCount);
 OptLoopToWhile(LoopWhileCount);
 OptGotoToIfBeginEnd(GotoBlockCount);
 OptGotoDetect(GotoCount);
 OptUnusedRegs(UnusedCount);
 TotalOpt:=IdiomCount+ConstPropCount+SimplifyCount+SubRegCount+
  GotoBlockCount+LoopWhileCount;
 WriteLn('Optimisation : ',TotalOpt,' modifications, ',
  GotoCount,' Goto candidats, ',UnusedCount,' registres inutilises.');
 If Verbose Then Begin
  WriteLn('  Patterns idiom.  : ',IdiomCount);
  WriteLn('  Prop. constantes : ',ConstPropCount);
  WriteLn('  Simplifications  : ',SimplifyCount);
  WriteLn('  Fusion sous-reg  : ',SubRegCount);
  WriteLn('  Loop -> While    : ',LoopWhileCount);
  WriteLn('  If-Then-Begin-End: ',GotoBlockCount);
  WriteLn('  Goto remplacables: ',GotoCount);
  WriteLn('  Registres inutil.: ',UnusedCount);
 End;
End;

{ ============================================================
  Correction post-traitement des sous-registres et @DATA
  ============================================================ }

Procedure ProcessSubRegFixup;
{ Corrige les assignations invalides Hi(RegXX) := val et Lo(RegXX) := val
  en utilisant des operations de bits valides en Pascal.
  Corrige aussi les references @DATA invalides en Pascal.
  Corrige les assignations de variables String/Array a des registres Word
  avec Ofs(). }
Var
 I,J:Integer;
 Code:String;
 P,P2:Integer;
 RegName,Value,VarName:String;
 Fixed:Integer;
 IsStringOrArray:Boolean;
Begin
 Fixed:=0;
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  Code:=Translations[I].PascalCode;

  { Corriger Hi(RegXX) := val; -> RegXX := (RegXX and $00FF) or (Word(val) shl 8); }
  P:=Pos('Hi(',Code);
  If(P>0)Then Begin
   P2:=Pos(') :=',Code);
   If(P2>P)Then Begin
    RegName:=Copy(Code,P+3,P2-P-3);
    Value:=Trim(Copy(Code,P2+4,255));
    { Retirer le point-virgule terminal }
    If(Length(Value)>0)and(Value[Length(Value)]=';')Then
     Value:=Copy(Value,1,Length(Value)-1);
    Value:=Trim(Value);
    If Length(Value)>0 Then Begin
     Translations[I].PascalCode:=
      Copy(Code,1,P-1)+RegName+' := ('+RegName+
      ' and $00FF) or (Word('+Value+') shl 8);';
     Inc(Fixed);
    End;
   End;
  End;

  Code:=Translations[I].PascalCode;

  { Corriger Lo(RegXX) := val; -> RegXX := (RegXX and $FF00) or Word(val); }
  P:=Pos('Lo(',Code);
  If(P>0)Then Begin
   P2:=Pos(') :=',Code);
   If(P2>P)Then Begin
    RegName:=Copy(Code,P+3,P2-P-3);
    Value:=Trim(Copy(Code,P2+4,255));
    If(Length(Value)>0)and(Value[Length(Value)]=';')Then
     Value:=Copy(Value,1,Length(Value)-1);
    Value:=Trim(Value);
    If Length(Value)>0 Then Begin
     Translations[I].PascalCode:=
      Copy(Code,1,P-1)+RegName+' := ('+RegName+
      ' and $FF00) or Word('+Value+');';
     Inc(Fixed);
    End;
   End;
  End;

  Code:=Translations[I].PascalCode;

  { Corriger les references @DATA invalides en Pascal }
  P:=Pos('@DATA',Code);
  If P>0 Then Begin
   Translations[I].PascalCode:=
    Copy(Code,1,P-1)+'0 (* @DATA *)'+Copy(Code,P+5,255);
   Inc(Fixed);
  End;

  Code:=Translations[I].PascalCode;

  { Corriger les assignations de variables String/Array a des registres Word.
    Detecter le pattern: RegXX := VarName; ou VarName est String ou Array
    et le remplacer par RegXX := Ofs(VarName); }
  P:=Pos(':= ',Code);
  If P>0 Then Begin
   Value:=Trim(Copy(Code,P+3,255));
   If(Length(Value)>0)and(Value[Length(Value)]=';')Then Begin
    VarName:=Trim(Copy(Value,1,Length(Value)-1));
    { Verifier si le cote gauche est un registre et le cote droit une var String/Array }
    If(Pos('Reg',Code)=1)or(Pos(' Reg',Code)>0)Then Begin
     IsStringOrArray:=False;
     For J:=1 to DataVarCount do Begin
      If DataVars[J].Name=VarName Then Begin
       If(DataVars[J].ElemCount>=1)and
         (DataVars[J].Elements[1].ElemType=DE_STRING)Then
        IsStringOrArray:=True
       Else If(DataVars[J].ElemCount=1)and
         (DataVars[J].Elements[1].ElemType=DE_DUP)Then
        IsStringOrArray:=True
       Else If DataVars[J].ElemCount>1 Then
        IsStringOrArray:=True;
       Break;
      End;
     End;
     If IsStringOrArray Then Begin
      Translations[I].PascalCode:=
       Copy(Code,1,P+2)+'Ofs('+VarName+');';
      Inc(Fixed);
     End;
    End;
   End;
  End;
 End;

 If Verbose Then Begin
  WriteLn('  Correction sous-registres et @DATA :');
  WriteLn('    Corrections appliquees : ',Fixed);
 End;
End;

{ ============================================================
  Detection de patterns de procedures Strings
  ============================================================ }

Function DetectProcStringsPattern(ProcIdx:Integer):String;
{ Analyse le corps d'une procedure pour detecter les patterns
  assembleur correspondant a des fonctions de l'unite Strings.
  Retourne le nom de la fonction Strings (ex: 'StrCopy', 'StrLen',
  'StrCat', 'StrComp', 'StrLower', 'StrUpper', 'StrEnd') ou '' si
  aucun pattern n'est reconnu.

  Patterns detectes :
  - strcpy : REPNE SCASB + REP MOVSB + retour AX pointeur dest
  - strlen : REPNE SCASB + NEG CX/AX (ou NOT CX + DEC CX, ou SUB AX,CX) sans MOVSB
  - strend : REPNE SCASB + MOV AX,DI + DEC AX (retourne ptr fin de chaine)
  - strcmp : REPE CMPSB
  - strcat : 2x REPNE SCASB + REP MOVSB (cherche fin dest puis copie)
  - strlower : boucle char par char, compare 41h-5Ah, ADD 20h
  - strupper : boucle char par char, compare 61h-7Ah, SUB 20h
}
Var
 I:LongInt;
 Line:String;
 HasRepneScasb:Boolean;
 HasRepMovsb:Boolean;
 HasRepeCmpsb:Boolean;
 RepneScasbCount:Integer;
 HasNegCX:Boolean;
 HasNegAX:Boolean;
 HasNotCX:Boolean;
 HasMovsb:Boolean;
 Has41h:Boolean;
 Has5Ah:Boolean;
 HasAdd20h:Boolean;
 Has61h:Boolean;
 Has7Ah:Boolean;
 HasSub20h:Boolean;
 HasSubAXCX:Boolean;
 HasMovAXDI:Boolean;
 HasDecAX:Boolean;
 M:String;
Begin
 DetectProcStringsPattern:='';
 If ProcIdx<1 Then Exit;
 If ProcIdx>ProcCount Then Exit;
 If Procs[ProcIdx].StartLine<0 Then Exit;
 If Procs[ProcIdx].EndLine<0 Then Exit;
 HasRepneScasb:=False;
 HasRepMovsb:=False;
 HasRepeCmpsb:=False;
 RepneScasbCount:=0;
 HasNegCX:=False;
 HasNegAX:=False;
 HasNotCX:=False;
 HasMovsb:=False;
 Has41h:=False;
 Has5Ah:=False;
 HasAdd20h:=False;
 Has61h:=False;
 Has7Ah:=False;
 HasSub20h:=False;
 HasSubAXCX:=False;
 HasMovAXDI:=False;
 HasDecAX:=False;
 For I:=Procs[ProcIdx].StartLine to Procs[ProcIdx].EndLine do Begin
  If(I<0)or(I>=SrcLineCount)Then Continue;
  If SrcLines[I]=Nil Then Continue;
  Line:=UpCaseStr(SrcLines[I]^);
  { Detecter REPNE SCASB }
  If(Pos('REPNE',Line)>0)and(Pos('SCASB',Line)>0)Then Begin
   HasRepneScasb:=True;
   Inc(RepneScasbCount);
  End;
  { Detecter REP MOVSB }
  If(Pos('MOVSB',Line)>0)Then Begin
   HasMovsb:=True;
   If(Pos('REP ',Line)>0)or(Pos('REP'+Chr(9),Line)>0)Then Begin
    { Verifier que c'est REP et pas REPNE/REPE }
    If(Pos('REPNE',Line)=0)and(Pos('REPE',Line)=0)Then
     HasRepMovsb:=True;
   End;
  End;
  { Detecter REPE CMPSB }
  If(Pos('CMPSB',Line)>0)Then Begin
   If(Pos('REPE',Line)>0)or(Pos('REPZ',Line)>0)Then
    HasRepeCmpsb:=True;
  End;
  { Detecter NEG CX / NEG ECX }
  If(Pos('NEG',Line)>0)and((Pos('CX',Line)>0)or(Pos('ECX',Line)>0))Then
   HasNegCX:=True;
  { Detecter NEG AX / NEG EAX }
  If(Pos('NEG',Line)>0)and((Pos('AX',Line)>0)or(Pos('EAX',Line)>0))Then
   HasNegAX:=True;
  { Detecter NOT CX / NOT ECX }
  If(Pos('NOT',Line)>0)and((Pos('CX',Line)>0)or(Pos('ECX',Line)>0))Then
   HasNotCX:=True;
  { Detecter strlower pattern : 41H ('A'), 5AH ('Z'), 20H }
  If Pos('41H',Line)>0 Then Has41h:=True;
  If Pos('5AH',Line)>0 Then Has5Ah:=True;
  If Pos('20H',Line)>0 Then HasAdd20h:=True;
  { Detecter strupper pattern : 61H ('a'), 7AH ('z'), SUB+20H }
  If Pos('61H',Line)>0 Then Has61h:=True;
  If Pos('7AH',Line)>0 Then Has7Ah:=True;
  If(Pos('SUB',Line)>0)and(Pos('20H',Line)>0)Then HasSub20h:=True;
  { Detecter SUB AX,CX / SUB EAX,ECX (strlen variante SUB) }
  If(Pos('SUB',Line)>0)and
    ((Pos('AX',Line)>0)or(Pos('EAX',Line)>0))and
    ((Pos('CX',Line)>0)or(Pos('ECX',Line)>0))Then
   HasSubAXCX:=True;
   { Detecter MOV AX,DI (strend pattern) }
   If(Pos('MOV',Line)>0)and(Pos('AX',Line)>0)and(Pos('DI',Line)>0)Then
    HasMovAXDI:=True;
   { Detecter DEC AX (strend pattern) }
   If(Pos('DEC',Line)>0)and((Pos('AX',Line)>0)or(Pos('EAX',Line)>0))Then
    HasDecAX:=True;
 End;

 { Pattern strcmp : REPE CMPSB }
 If HasRepeCmpsb and(Not HasRepneScasb)and(Not HasRepMovsb)Then Begin
  DetectProcStringsPattern:='StrComp';
  Exit;
 End;

 { Pattern strcat : 2x REPNE SCASB + REP MOVSB }
 If(RepneScasbCount>=2)and HasRepMovsb Then Begin
  DetectProcStringsPattern:='StrCat';
  Exit;
 End;

 { Pattern strcpy : 1x REPNE SCASB + REP MOVSB }
 If HasRepneScasb and HasRepMovsb Then Begin
  DetectProcStringsPattern:='StrCopy';
  Exit;
 End;

 { Pattern strlen : REPNE SCASB + NEG/NOT CX ou NEG AX ou SUB AX,CX, sans MOVSB }
 If HasRepneScasb and(HasNegCX or HasNotCX or HasNegAX or HasSubAXCX)and(Not HasMovsb)Then Begin
  DetectProcStringsPattern:='StrLen';
  Exit;
 End;

 { Pattern strend : REPNE SCASB + MOV AX,DI + DEC AX, sans MOVSB ni NEG/NOT }
 If HasRepneScasb and HasMovAXDI and HasDecAX and
    (Not HasMovsb)and(Not HasNegCX)and(Not HasNotCX)and
    (Not HasNegAX)and(Not HasSubAXCX)Then Begin
  DetectProcStringsPattern:='StrEnd';
  Exit;
 End;

 { Pattern strlower : compare 'A'(41h)-'Z'(5Ah) + ADD 20h, sans SCASB }
 If Has41h and Has5Ah and HasAdd20h and
    (Not HasRepneScasb)and(Not HasRepeCmpsb)Then Begin
  DetectProcStringsPattern:='StrLower';
  Exit;
 End;

 { Pattern strupper : compare 'a'(61h)-'z'(7Ah) + SUB 20h, sans SCASB }
 If Has61h and Has7Ah and HasSub20h and
    (Not HasRepneScasb)and(Not HasRepeCmpsb)Then Begin
  DetectProcStringsPattern:='StrUpper';
  Exit;
 End;
End;

Procedure ProcessProcBodyPatterns;
{ Scanne les corps des procedures pour detecter les patterns
  assembleur correspondant a des fonctions de l'unite Strings.
  Met a jour StringsReplacement et NeedStrings. }
Var
 I:Integer;
 Pat:String;
 PatCount:Integer;
Begin
 PatCount:=0;
 For I:=1 to ProcCount do Begin
  Pat:=DetectProcStringsPattern(I);
  If Pat<>'' Then Begin
   Procs[I].StringsReplacement:=Pat;
   NeedStrings:=True;
   Inc(PatCount);
  End;
 End;
 WriteLn('  Detection de patterns Strings dans les procedures :');
 WriteLn('    Procedures analysees : ',ProcCount);
 WriteLn('    Patterns detectes    : ',PatCount);
 If Verbose Then Begin
  For I:=1 to ProcCount do Begin
   If Procs[I].StringsReplacement<>'' Then
    WriteLn('    ',Procs[I].Name,' -> ',Procs[I].StringsReplacement);
  End;
 End;
End;

Procedure SetTranslationForLine(Line:LongInt;Code:String);
{ Remplace une traduction existante ou en cree une. Une chaine vide marque
  une instruction absorbee par un pattern de plus haut niveau. }
Var
 Idx:LongInt;
Begin
 Idx:=FindTranslationForLine(Line);
 If Idx>=0 Then Begin
  Translations[Idx].PascalCode:=Code;
  Translations[Idx].IsTranslated:=True;
 End Else
  AddTranslation(Line,Code,'pattern runtime');
End;

Function IsRuntimeFarCall(Line:LongInt;RuntimeOffset:Word):Boolean;
Var
 A:TAsmLine;
Begin
 IsRuntimeFarCall:=False;
 If(Line<0)or(Line>=SrcLineCount)Then Exit;
 ParseInstructionLine(Line,A);
 IsRuntimeFarCall:=(UpCaseStr(A.Mnemonic)='CALL')and
  (A.Op1.OpType=OT_FAR)and(Word(A.Op1.Disp)=RuntimeOffset);
End;

Function IsSimpleRegInstruction(Line:LongInt;Mnem,Reg1,Reg2:String):Boolean;
Var
 A:TAsmLine;
Begin
 IsSimpleRegInstruction:=False;
 If(Line<0)or(Line>=SrcLineCount)Then Exit;
 ParseInstructionLine(Line,A);
 If UpCaseStr(A.Mnemonic)<>Mnem Then Exit;
 If UpCaseStr(A.Op1.Reg)<>Reg1 Then Exit;
 If Reg2<>'' Then Begin
  If UpCaseStr(A.Op2.Reg)<>Reg2 Then Exit;
 End;
 IsSimpleRegInstruction:=True;
End;

Procedure ProcessTurboPascalWriteLnPatterns;
{ Reconnait le code genere par le runtime Turbo Pascal 16 bits :
    MOV DI,088Ah / PUSH DS / PUSH DI       (fichier Output)
    MOV DI,OFFSET chaine / PUSH CS / PUSH DI / XOR AX,AX / PUSH AX
    CALL xxxx:08D3h                       (ecriture chaine)
    CALL xxxx:0840h                       (fin de ligne)
    [CALL xxxx:04F4h]                     (controle erreur E/S)
  Plusieurs appels 08D3h consecutifs sont fusionnes dans le meme WriteLn. }
Var
 I,J,K,EndLine,VIdx,PatternCount,FragmentCount:LongInt;
 A:TAsmLine;
 LabelName,Args,ItemExpr:String;
 Valid,MatchedItem:Boolean;
Begin
 PatternCount:=0;
 I:=0;
 While I<SrcLineCount-9 do Begin
  ParseInstructionLine(I,A);
  Valid:=(UpCaseStr(A.Mnemonic)='MOV')and
    (UpCaseStr(A.Op1.Reg)='DI')and(A.Op2.Imm=$088A);
  If Valid Then
   Valid:=IsSimpleRegInstruction(I+1,'PUSH','DS','') and
          IsSimpleRegInstruction(I+2,'PUSH','DI','');
  If Not Valid Then Begin Inc(I); Continue; End;

  J:=I+3;
  Args:='';
  FragmentCount:=0;
  While J+6<SrcLineCount do Begin
   MatchedItem:=False;
   ParseInstructionLine(J,A);

   { Chaine litterale ou shortstring situee a une adresse DS connue. }
   If(UpCaseStr(A.Mnemonic)='MOV')and(UpCaseStr(A.Op1.Reg)='DI')Then Begin
    ItemExpr:='';
    If A.Op2.OpType=OT_OFFSET Then Begin
     LabelName:=A.Op2.LabelName;
     VIdx:=FindDataVarByName(LabelName);
     If(VIdx>0)and IsLengthPrefixedString(VIdx)and
       IsSimpleRegInstruction(J+1,'PUSH','CS','')Then
      ItemExpr:=QuotePascalString(DataVars[VIdx].Elements[2].StrValue);
    End Else If A.Op2.OpType in [OT_IMM8,OT_IMM16,OT_IMM32] Then Begin
     If IsSimpleRegInstruction(J+1,'PUSH','DS','')Then
      ItemExpr:='PString(@Mem[$'+HexWord(Word(A.Op2.Imm))+'])^';
    End;
    If(ItemExpr<>'')and IsSimpleRegInstruction(J+2,'PUSH','DI','')and
      IsSimpleRegInstruction(J+3,'XOR','AX','AX')and
      IsSimpleRegInstruction(J+4,'PUSH','AX','')and
      IsRuntimeFarCall(J+5,$08D3)Then Begin
     MatchedItem:=True;
     J:=J+6;
    End;
   End;

   { Entier signe : MOV AX,[adresse] / CWD / PUSH DX:AX / largeur 0 /
     appel d'ecriture numerique 095Bh. }
   If Not MatchedItem Then Begin
    ParseInstructionLine(J,A);
    If(UpCaseStr(A.Mnemonic)='MOV')and(UpCaseStr(A.Op1.Reg)='AX')and
      (A.Op2.OpType=OT_MEM)and(A.Op2.BaseReg='')and
      (A.Op2.IndexReg='')and(A.Op2.HasDisp)and
      IsSimpleRegInstruction(J+1,'CWD','','')and
      IsSimpleRegInstruction(J+2,'PUSH','DX','')and
      IsSimpleRegInstruction(J+3,'PUSH','AX','')and
      IsSimpleRegInstruction(J+4,'XOR','AX','AX')and
      IsSimpleRegInstruction(J+5,'PUSH','AX','')and
      IsRuntimeFarCall(J+6,$095B)Then Begin
     ItemExpr:='SmallInt(PWord(@Mem[$'+HexWord(Word(A.Op2.Disp))+'])^)';
     MatchedItem:=True;
     J:=J+7;
    End;
   End;

   If Not MatchedItem Then Break;
   If Args<>'' Then Args:=Args+', ';
   Args:=Args+ItemExpr;
   Inc(FragmentCount);
  End;

  If Not IsRuntimeFarCall(J,$0840) Then Begin
   Inc(I);
   Continue;
  End;
  EndLine:=J;
  If IsRuntimeFarCall(J+1,$04F4) Then Inc(EndLine);

  If FragmentCount=0 Then
   SetTranslationForLine(I,'WriteLn;')
  Else
   SetTranslationForLine(I,'WriteLn('+Args+');');
  For K:=I+1 to EndLine do SetTranslationForLine(K,'');
  Inc(PatternCount);
  I:=EndLine+1;
 End;
 WriteLn('  Reconstruction WriteLn Turbo Pascal : ',PatternCount,
  ' bloc(s) detecte(s).');
End;

Procedure ProcessTurboPascalHaltPatterns;
{ Reconnait le terminateur du runtime Turbo Pascal 16 bits :
    XOR AX,AX / CALL xxxx:0116h  -> Halt;
    MOV AX,n  / CALL xxxx:0116h  -> Halt(n);
  AX porte le code de sortie transmis au runtime. }
Var
 I,PatternCount:LongInt;
 A:TAsmLine;
 ExitCode:LongInt;
 Matched:Boolean;
Begin
 PatternCount:=0;
 For I:=0 to SrcLineCount-2 do Begin
  If Not IsRuntimeFarCall(I+1,$0116) Then Continue;
  ParseInstructionLine(I,A);
  Matched:=False;
  ExitCode:=0;

  If(UpCaseStr(A.Mnemonic)='XOR')and
    (UpCaseStr(A.Op1.Reg)='AX')and(UpCaseStr(A.Op2.Reg)='AX')Then Begin
   ExitCode:=0;
   Matched:=True;
  End Else If(UpCaseStr(A.Mnemonic)='MOV')and
    (UpCaseStr(A.Op1.Reg)='AX')and
    (A.Op2.OpType in [OT_IMM8,OT_IMM16,OT_IMM32])Then Begin
   ExitCode:=A.Op2.Imm;
   Matched:=True;
  End;

  If Not Matched Then Continue;
  If ExitCode=0 Then
   SetTranslationForLine(I,'Halt;')
  Else
   SetTranslationForLine(I,'Halt('+IntToStr(ExitCode)+');');
  SetTranslationForLine(I+1,'');
  Inc(PatternCount);
 End;
 WriteLn('  Reconstruction Halt Turbo Pascal    : ',PatternCount,
  ' bloc(s) detecte(s).');
End;

Procedure ProcessTurboPascalParamCountIfPatterns;
{ Reconstruit la validation classique des arguments :
    CALL runtime ParamCount / CMP AX,n / JNL apres_bloc
    ... Halt(code)
  en If ParamCount < n Then Begin ... Halt(code); End; }
Var
 I,K,HaltLine,TrIdx,PatternCount:LongInt;
 CmpA,JmpA:TAsmLine;
 Code:String;
Begin
 PatternCount:=0;
 For I:=0 to SrcLineCount-3 do Begin
  If Not IsRuntimeFarCall(I,$0A9C) Then Continue;
  ParseInstructionLine(I+1,CmpA);
  ParseInstructionLine(I+2,JmpA);
  If(UpCaseStr(CmpA.Mnemonic)<>'CMP')or
    (UpCaseStr(CmpA.Op1.Reg)<>'AX')or
    Not (CmpA.Op2.OpType in [OT_IMM8,OT_IMM16,OT_IMM32])Then Continue;
  If(UpCaseStr(JmpA.Mnemonic)<>'JNL')and
    (UpCaseStr(JmpA.Mnemonic)<>'JGE')Then Continue;

  HaltLine:=-1;
  For K:=I+3 to I+48 do Begin
   If K>=SrcLineCount Then Break;
   TrIdx:=FindTranslationForLine(K);
   If(TrIdx>=0)and
     (Pos('HALT(',UpCaseStr(Translations[TrIdx].PascalCode))=1)Then Begin
    HaltLine:=K;
    Break;
   End;
  End;
  If HaltLine<0 Then Continue;

  SetTranslationForLine(I,'If ParamCount < '+
   IntToStr(CmpA.Op2.Imm)+' Then Begin');
  SetTranslationForLine(I+1,'');
  SetTranslationForLine(I+2,'');
  TrIdx:=FindTranslationForLine(HaltLine);
  Code:=Translations[TrIdx].PascalCode;
  Translations[TrIdx].PascalCode:=Code+#13#10+'  End;';

  For K:=I+3 to HaltLine do Begin
   TrIdx:=FindTranslationForLine(K);
   If(TrIdx>=0)and(Translations[TrIdx].PascalCode<>'')Then
    Translations[TrIdx].PascalCode:=' '+Translations[TrIdx].PascalCode;
  End;
  Inc(PatternCount);
 End;
 WriteLn('  Reconstruction If/ParamCount Turbo Pascal : ',PatternCount,
  ' bloc(s) detecte(s).');
End;

Procedure ProcessTurboPascalPositiveIfHaltPatterns;
{ Reconstruit CMP [variable],0 / JLE apres_bloc / ... / Halt(n) sous la
  forme If variable > 0 Then Begin ... Halt(n); End;. }
Var
 I,K,HaltLine,TrIdx,PatternCount:LongInt;
 CmpA,JmpA:TAsmLine;
 Code:String;
Begin
 PatternCount:=0;
 For I:=0 to SrcLineCount-3 do Begin
  ParseInstructionLine(I,CmpA);
  ParseInstructionLine(I+1,JmpA);
  If(UpCaseStr(CmpA.Mnemonic)<>'CMP')or
    (CmpA.Op1.OpType<>OT_MEM)or(CmpA.Op1.BaseReg<>'')or
    (CmpA.Op1.IndexReg<>'')or(Not CmpA.Op1.HasDisp)or
    (CmpA.Op2.Imm<>0)or(UpCaseStr(JmpA.Mnemonic)<>'JLE')Then Continue;

  HaltLine:=-1;
  For K:=I+2 to I+32 do Begin
   If K>=SrcLineCount Then Break;
   TrIdx:=FindTranslationForLine(K);
   If(TrIdx>=0)and
     (Pos('HALT(',UpCaseStr(Translations[TrIdx].PascalCode))=1)Then Begin
    HaltLine:=K;
    Break;
   End;
  End;
  If HaltLine<0 Then Continue;

  SetTranslationForLine(I,'If SmallInt(PWord(@Mem[$'+
   HexWord(Word(CmpA.Op1.Disp))+'])^) > 0 Then Begin');
  SetTranslationForLine(I+1,'');
  TrIdx:=FindTranslationForLine(HaltLine);
  Code:=Translations[TrIdx].PascalCode;
  Translations[TrIdx].PascalCode:=Code+#13#10+'  End;';
  For K:=I+2 to HaltLine do Begin
   TrIdx:=FindTranslationForLine(K);
   If(TrIdx>=0)and(Translations[TrIdx].PascalCode<>'')Then
    Translations[TrIdx].PascalCode:=' '+Translations[TrIdx].PascalCode;
  End;
  Inc(PatternCount);
 End;
 WriteLn('  Reconstruction If positif/Halt Turbo Pascal : ',PatternCount,
  ' bloc(s) detecte(s).');
End;

Function FindSourceLabelLine(LabelName:String):LongInt;
Var
 I:LongInt;
 A:TAsmLine;
Begin
 FindSourceLabelLine:=-1;
 For I:=0 to SrcLineCount-1 do Begin
  ParseInstructionLine(I,A);
  If UpCaseStr(A.LabelStr)=UpCaseStr(LabelName) Then Begin
   FindSourceLabelLine:=I;
   Exit;
  End;
 End;
End;

Procedure ProcessTurboPascalParamStrIfPatterns;
{ Reconstruit les chaines de comparaisons generees pour :
    If (ParamStr(n)='x') or (ParamStr(n)='y') Then Begin ... End;
  Runtime observe : 0A4Dh=ParamStr, 0CEFh=comparaison de shortstrings,
  chaque egalite sautant par JZ vers le meme corps. }
Var
 I,J,K,VIdx,ClauseCount,PatternCount:LongInt;
 A:TAsmLine;
 BodyLabel,NextLabel,ThisBody,OptText,Cond,Code:String;
 BodyLine,NextLine,HaltLine,TrIdx:LongInt;
 Valid:Boolean;
Begin
 PatternCount:=0;
 I:=0;
 While I<SrcLineCount-12 do Begin
  ParseInstructionLine(I,A);
  If UpCaseStr(A.Mnemonic)<>'LEA' Then Begin Inc(I); Continue; End;

  J:=I;
  ClauseCount:=0;
  BodyLabel:='';
  Cond:='';
  While J+10<SrcLineCount do Begin
   ParseInstructionLine(J,A);
   Valid:=(UpCaseStr(A.Mnemonic)='LEA') and
    IsSimpleRegInstruction(J+1,'PUSH','SS','') and
    IsSimpleRegInstruction(J+2,'PUSH','DI','');
   If Not Valid Then Break;

   ParseInstructionLine(J+3,A);
   If(UpCaseStr(A.Mnemonic)<>'MOV')or(UpCaseStr(A.Op1.Reg)<>'AX')or
     (A.Op2.Imm<>1)Then Break;
   If Not IsSimpleRegInstruction(J+4,'PUSH','AX','') Then Break;
   If Not IsRuntimeFarCall(J+5,$0A4D) Then Break;

   ParseInstructionLine(J+6,A);
   If(UpCaseStr(A.Mnemonic)<>'MOV')or(UpCaseStr(A.Op1.Reg)<>'DI')or
     (A.Op2.OpType<>OT_OFFSET)Then Break;
   VIdx:=FindDataVarByName(A.Op2.LabelName);
   If(VIdx=0)or(Not IsLengthPrefixedString(VIdx))Then Break;
   OptText:=DataVars[VIdx].Elements[2].StrValue;

   If Not IsSimpleRegInstruction(J+7,'PUSH','CS','') Then Break;
   If Not IsSimpleRegInstruction(J+8,'PUSH','DI','') Then Break;
   If Not IsRuntimeFarCall(J+9,$0CEF) Then Break;
   ParseInstructionLine(J+10,A);
   If UpCaseStr(A.Mnemonic)<>'JZ' Then Break;
   ThisBody:=A.Op1.LabelName;
   If ThisBody='' Then Break;
   If BodyLabel='' Then BodyLabel:=ThisBody
   Else If UpCaseStr(ThisBody)<>UpCaseStr(BodyLabel) Then Break;

   If Cond<>'' Then Cond:=Cond+' or ';
   Cond:=Cond+'(ParamStr(1)='+QuotePascalString(OptText)+')';
   Inc(ClauseCount);
   J:=J+11;
  End;

  If ClauseCount<2 Then Begin Inc(I); Continue; End;
  ParseInstructionLine(J,A);
  If(UpCaseStr(A.Mnemonic)<>'JMP')or(A.Op1.LabelName='')Then Begin
   Inc(I);
   Continue;
  End;
  NextLabel:=A.Op1.LabelName;
  BodyLine:=FindSourceLabelLine(BodyLabel);
  NextLine:=FindSourceLabelLine(NextLabel);
  If(BodyLine<0)or(NextLine<=BodyLine)Then Begin Inc(I); Continue; End;

  HaltLine:=-1;
  For K:=BodyLine+1 to NextLine-1 do Begin
   TrIdx:=FindTranslationForLine(K);
   If(TrIdx>=0)and(Translations[TrIdx].PascalCode='Halt;')Then
    HaltLine:=K;
  End;
  If HaltLine<0 Then Begin Inc(I); Continue; End;

  Code:='If '+Cond+' Then Begin';
  SetTranslationForLine(I,Code);
  For K:=I+1 to J do SetTranslationForLine(K,'');
  TrIdx:=FindTranslationForLine(HaltLine);
  If TrIdx>=0 Then
   Translations[TrIdx].PascalCode:='Halt;'+#13#10+'  End;';
  { ProcessBodyGeneration ajoute deja deux espaces. Ajouter un espace aux
    instructions du corps pour les decaler par rapport au If, tandis que
    le End inclus ci-dessus reste aligne sur le If. }
  For K:=BodyLine+1 to HaltLine do Begin
   TrIdx:=FindTranslationForLine(K);
   If(TrIdx>=0)and(Translations[TrIdx].PascalCode<>'')Then
    Translations[TrIdx].PascalCode:=' '+Translations[TrIdx].PascalCode;
  End;
  AddOptLabel(BodyLabel);
  AddOptLabel(NextLabel);
  Inc(PatternCount);
  I:=NextLine+1;
 End;
 WriteLn('  Reconstruction If/ParamStr Turbo Pascal : ',PatternCount,
  ' bloc(s) detecte(s).');
End;

{ ============================================================
  Collecte des acces memoire indexes pour creer des variables
  locales - Amelioration de la lisibilite du code genere
  ============================================================ }

Function AddIndexedLocal(ProcIdx:Integer;BaseReg,IndexReg:String;
 Offset:LongInt;DataSize:Byte):Integer;
{ Ajoute une variable locale pour un acces memoire indexe.
  Retourne l'index de la nouvelle variable ou 0 si echec. }
Var
 VarName:String;
 LocalIdx:Integer;
 LPascalType:Byte;
Begin
 AddIndexedLocal:=0;
 If(ProcIdx<1)or(ProcIdx>ProcCount)Then Exit;
 If Procs[ProcIdx].LocalCount>=MAX_LOCALS Then Exit;
 
 { Verifier si existe deja }
 LocalIdx:=FindIndexedLocalByOffset(ProcIdx,BaseReg,IndexReg,Offset);
 If LocalIdx>0 Then Begin
  AddIndexedLocal:=LocalIdx;
  Exit;
 End;
 
 { Creer un nom de variable lisible avec notation hexadecimale }
 If Offset>=0 Then
  VarName:='Idx'+HexWord(Word(Offset))+'h'
 Else
  VarName:='IdxN'+HexWord(Word(-Offset))+'h';
 
 { Determiner le type Pascal en fonction de la taille }
 Case DataSize of
  1:LPascalType:=PT_BYTE;
  2:LPascalType:=PT_WORD;
  4:LPascalType:=PT_LONGINT;
  Else LPascalType:=PT_WORD;
 End;
 
 Inc(Procs[ProcIdx].LocalCount);
 LocalIdx:=Procs[ProcIdx].LocalCount;
 With Procs[ProcIdx].Locals[LocalIdx] do Begin
  Name:=VarName;
  { TypeName doit correspondre au type Pascal }
  Case LPascalType of
   PT_BYTE:TypeName:='BYTE';
   PT_WORD:TypeName:='WORD';
   PT_LONGINT:TypeName:='DWORD';
   Else TypeName:='WORD';
  End;
  PascalType:=LPascalType;
  Size:=DataSize;
  Count:=1;
  IsIndexedMem:=True;
  IndexOffset:=Offset;
  IndexBaseReg:=UpCaseStr(BaseReg);
  IndexIndexReg:=UpCaseStr(IndexReg);
 End;
 
 AddIndexedLocal:=LocalIdx;
End;

Procedure CollectIndexedMemAccessInOp(ProcIdx:Integer;Var Op:TOperand);
{ Analyse un operande et collecte les acces memoire indexes. }
Var
 UBase,UIndex:String;
 DataSize:Byte;
Begin
 If Op.OpType<>OT_MEM Then Exit;
 
 { On s'interesse aux acces avec registre de base + registre d'index }
 If(Op.BaseReg='')or(Op.IndexReg='')Then Exit;
 
 UBase:=UpCaseStr(Op.BaseReg);
 UIndex:=UpCaseStr(Op.IndexReg);
 
 { Calculer la taille de donnees - Op.Size contient directement la taille }
 Case Op.Size of
  1:DataSize:=1;
  2:DataSize:=2;
  4:DataSize:=4;
  Else DataSize:=2;
 End;
 
 { Collecter si l'acces a un deplacement }
 If Op.HasDisp Then
  AddIndexedLocal(ProcIdx,UBase,UIndex,Op.Disp,DataSize)
 Else
  AddIndexedLocal(ProcIdx,UBase,UIndex,0,DataSize);
End;

Procedure CollectProcIndexedMemAccesses(ProcIdx:Integer);
{ Parcourt le code d'une procedure et collecte tous les acces
  memoire indexes pour creer des variables locales appropriees. }
Var
 I:LongInt;
 AsmL:TAsmLine;
 StartL,EndL:LongInt;
Begin
 If(ProcIdx<1)or(ProcIdx>ProcCount)Then Exit;
 
 StartL:=Procs[ProcIdx].StartLine;
 EndL:=Procs[ProcIdx].EndLine;
 
 If EndL<=StartL Then Exit;
 
 For I:=StartL to EndL do Begin
  If(I<0)or(I>=SrcLineCount)Then Continue;
  ParseInstructionLine(I,AsmL);
  If AsmL.IsDirective Then Continue;
  If AsmL.Mnemonic='' Then Continue;
  
  { Analyser les deux operandes }
  CollectIndexedMemAccessInOp(ProcIdx,AsmL.Op1);
  CollectIndexedMemAccessInOp(ProcIdx,AsmL.Op2);
 End;
End;

Procedure ProcessIndexedMemoryLocals;
{ Parcourt toutes les procedures et collecte les acces memoire indexes
  pour creer des variables locales plus lisibles. }
Var
 I:Integer;
 TotalLocals:Integer;
 InitLocals:Integer;
Begin
 TotalLocals:=0;
 
 For I:=1 to ProcCount do Begin
  InitLocals:=Procs[I].LocalCount;
  CollectProcIndexedMemAccesses(I);
  TotalLocals:=TotalLocals+(Procs[I].LocalCount-InitLocals);
 End;
 
 WriteLn('  Collecte acces memoire indexes :');
 WriteLn('    Procedures analysees : ',ProcCount);
 WriteLn('    Variables locales creees : ',TotalLocals);
End;

{ ============================================================
  Verification finale et rapport - TODO 25
  ============================================================ }

Function IsVerifyMnemonic(Const M:String):Boolean;
{ Indique si le mnemonique est gere par TODO 25
  (la verification agit sur les resultats globaux, pas sur les mnemoniques). }
Begin
 IsVerifyMnemonic:=False;
End;

Procedure ProcessVerificationReport;
{ Verification de coherence et rapport final de la transpilation. }
Var
 I,J,P:Integer;
 ErrorCount:Integer;
 WarnCount:Integer;
 LabelSymCount:Integer;
 ProcSymCount:Integer;
 VarSymCount:Integer;
 ConstSymCount:Integer;
 ExternCount:Integer;
 PublicCount:Integer;
 TransOK:LongInt;
 TransInline:LongInt;
 TransNone:LongInt;
 Pct:LongInt;
 UnmatchedProcs:Integer;
 GotoTargets:Integer;
 UnresolvedGotos:Integer;
 Code,Lbl:String;
 Found:Boolean;
 ExitCode:Integer;
Begin
 ErrorCount:=0;
 WarnCount:=0;

 { === Phase 1 : Comptage des symboles === }
 LabelSymCount:=0;
 ProcSymCount:=0;
 VarSymCount:=0;
 ConstSymCount:=0;
 ExternCount:=0;
 PublicCount:=0;
 For I:=1 to SymbolCount do Begin
  Case Symbols[I].SymType of
   SY_LABEL:Inc(LabelSymCount);
   SY_PROC:Inc(ProcSymCount);
   SY_VAR:Inc(VarSymCount);
   SY_CONST:Inc(ConstSymCount);
  End;
  If Symbols[I].IsExtern Then Inc(ExternCount);
  If Symbols[I].IsPublic Then Inc(PublicCount);
 End;

 { === Phase 2 : Verification des procedures (ENDP correspondant) === }
 UnmatchedProcs:=0;
 For I:=1 to ProcCount do Begin
  If Procs[I].EndLine<=Procs[I].StartLine Then Begin
   Inc(UnmatchedProcs);
   Inc(WarnCount);
  End;
 End;

 { === Phase 3 : Verification des references Goto === }
 GotoTargets:=0;
 UnresolvedGotos:=0;
 For I:=0 to TranslationCount-1 do Begin
  If Not Translations[I].IsTranslated Then Continue;
  Code:=Translations[I].PascalCode;
  P:=Pos('Goto ',Code);
  If P>0 Then Begin
   Lbl:=Trim(Copy(Code,P+5,255));
   { Retirer le point-virgule terminal }
   If(Length(Lbl)>0)and(Lbl[Length(Lbl)]=';')Then
    Lbl:=Trim(Copy(Lbl,1,Length(Lbl)-1));
   { Retirer 'End;' si present apres le label (ex: Begin ... Goto X; End;) }
   P:=Pos(' ',Lbl);
   If P>0 Then Lbl:=Copy(Lbl,1,P-1);
   If Length(Lbl)=0 Then Continue;
   Inc(GotoTargets);
   { Chercher le label comme cible dans les traductions }
   Found:=False;
   For J:=0 to TranslationCount-1 do Begin
    If Not Translations[J].IsTranslated Then Continue;
    If Pos(Lbl+':',Translations[J].PascalCode)>0 Then Begin
     Found:=True;
     Break;
    End;
   End;
   { Aussi verifier dans la table des symboles }
   If Not Found Then Begin
    If FindSymbol(Lbl)>0 Then Found:=True;
   End;
   If Not Found Then Begin
    Inc(UnresolvedGotos);
    Inc(WarnCount);
   End;
  End;
 End;

 { === Phase 4 : Comptage des traductions === }
 TransOK:=0;
 TransInline:=0;
 TransNone:=0;
 For I:=0 to TranslationCount-1 do Begin
  If Translations[I].IsTranslated Then Begin
   { Verifier si c'est du ASM inline }
   If(Pos('asm',Translations[I].PascalCode)>0)
    and(Pos('end;',Translations[I].PascalCode)>0)Then
    Inc(TransInline)
   Else
    Inc(TransOK);
  End Else
   Inc(TransNone);
 End;

 { === Phase 5 : Calcul du pourcentage de traduction === }
 If TranslationCount>0 Then
  Pct:=(TransOK*100) div TranslationCount
 Else
  Pct:=0;

 { === Phase 6 : Detection des erreurs graves === }
 If TranslationCount=0 Then Begin
  Inc(ErrorCount);
 End;
 If(ProcCount>0)and(UnmatchedProcs=ProcCount)Then Begin
  Inc(ErrorCount);
 End;

 { === Rapport final === }
 WriteLn;
 WriteLn('=== Rapport de transpilation ===');
 WriteLn('  Fichier source      : ',InFileName);
 WriteLn('  Fichier genere      : ',OutFileName);
 WriteLn('  Lignes source       : ',SrcLineCount);
 WriteLn('  Instructions totales: ',TranslationCount);
 WriteLn('  Traduites (Pascal)  : ',TransOK);
 WriteLn('  ASM inline          : ',TransInline);
 WriteLn('  Non traduites       : ',TransNone);
 WriteLn('  Pourcentage traduit : ',Pct,'%');
 WriteLn('  Procedures          : ',ProcCount);
 WriteLn('  Variables           : ',DataVarCount);
 WriteLn('  Symboles            : ',SymbolCount);

 If(UnmatchedProcs>0)Then
  WriteLn('  AVERTISSEMENT: ',UnmatchedProcs,
   ' procedure(s) sans ENDP correspondant.');
 If(UnresolvedGotos>0)Then
  WriteLn('  AVERTISSEMENT: ',UnresolvedGotos,
   ' reference(s) Goto non resolue(s) sur ',GotoTargets,' cible(s).');

 If Verbose Then Begin
  WriteLn('  Details des symboles :');
  WriteLn('    Labels       : ',LabelSymCount);
  WriteLn('    Procedures   : ',ProcSymCount);
  WriteLn('    Variables    : ',VarSymCount);
  WriteLn('    Constantes   : ',ConstSymCount);
  WriteLn('    Externes     : ',ExternCount);
  WriteLn('    Publics      : ',PublicCount);
  WriteLn('  Details des procedures :');
  For I:=1 to ProcCount do Begin
   Write('    ',Procs[I].Name);
   If Procs[I].IsFunction or Procs[I].UsesAX Then Write(' (Function)')
   Else Write(' (Procedure)');
   If Procs[I].IsNear Then Write(' NEAR') Else Write(' FAR');
   Write(' params:',Procs[I].ParamCount);
   Write(' locals:',Procs[I].LocalCount);
   WriteLn(' [',Procs[I].StartLine,'..',Procs[I].EndLine,']');
  End;
  WriteLn('  Details de la traduction :');
  WriteLn('    References Goto   : ',GotoTargets);
  WriteLn('    Goto resolus      : ',GotoTargets-UnresolvedGotos);
  WriteLn('    Goto non resolus  : ',UnresolvedGotos);
  WriteLn('    Proc. sans ENDP   : ',UnmatchedProcs);
  WriteLn('  Mode de traduction :');
  If Mode32 Then WriteLn('    Architecture : 80386 (32 bits)')
  Else WriteLn('    Architecture : 8086 (16 bits)');
  If UseInline Then WriteLn('    ASM inline   : active')
  Else WriteLn('    ASM inline   : desactive');
  If AddComments Then WriteLn('    Commentaires : actifs')
  Else WriteLn('    Commentaires : desactives');
 End;

 WriteLn('  Avertissements : ',WarnCount);
 WriteLn('  Erreurs         : ',ErrorCount);

 { === Code de retour === }
 If ErrorCount>0 Then ExitCode:=1
 Else ExitCode:=0;

 If ExitCode=0 Then
  WriteLn('Transpilation terminee avec succes.')
 Else
  WriteLn('Transpilation terminee avec des erreurs.');

 { Liberer la memoire }
 FreeSourceLines;

 Halt(ExitCode);
End;

Procedure ShowHelp;Begin
 WriteLn('ASM2PAS v',ASM2PAS_VERSION,' - Cette commande permet de ',
         'transpileur d''Assembleur 8086/80386 vers Pascal');
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
 NeedWinDos:=False;
 NeedDosBool:=False;
 NeedStrings:=False;
 TotalProcs:=0;
 TotalVars:=0;
 TotalLabels:=0;
 OptLabelCount:=0;
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
 { Detection des fonctions implicites (sans PROC/ENDP) }
 DetectImplicitFunctions;
 { Table des symboles (TODO 6) }
 BuildSymbolTable;
 { Analyse des operandes (TODO 7) }
 ProcessOperands;
 { Inference de types (TODO 8) }
 ProcessTypeInference;
 { Mapping des registres (TODO 9) }
 ProcessRegisterMapping;
 { Collecte des acces memoire indexes pour creer des variables locales }
 ProcessIndexedMemoryLocals;
 { Traduction des transferts (TODO 10) }
 ProcessDataTransfers;
 { TODO 11 - Traduction arithmetique }
 ProcessArithmeticTranslations;
 { TODO 12 - Traduction logique }
 ProcessLogicalTranslations;
 { TODO 13 - Traduction comparaisons/sauts }
 ProcessCompareJumpTranslations;
 { TODO 14 - Traduction boucles }
 ProcessJumpLoopTranslations;
 { TODO 15 - Traduction CALL/RET }
 ProcessCallRetTranslations;
 { TODO 16 - Traduction PUSH/POP }
 ProcessPushPopTranslations;
 { TODO 17 - Traduction chaines }
 ProcessStringTranslations;
 { TODO 18 - Traduction INT systeme }
 ProcessIntTranslations;
 { TODO 19 - Traduction adressage }
 ProcessAddressingTranslations;
 { TODO 20 - Extensions 80386 }
 Process386Translations;
 { TODO 23 - Fallback ASM inline (avant generation) }
 ProcessInlineFallback;
 { TODO 24 - Optimisation (avant generation) }
 ProcessOptimization;
 { Correction sous-registres Hi/Lo et @DATA }
 ProcessSubRegFixup;
 { Detection de patterns Strings dans les procedures }
 ProcessProcBodyPatterns;
 { Reconstruction des appels d'ecriture du runtime Turbo Pascal }
 ProcessTurboPascalWriteLnPatterns;
 { Reconstruction de la terminaison du runtime Turbo Pascal }
 ProcessTurboPascalHaltPatterns;
 { Reconstruction des tests positifs se terminant par Halt }
 ProcessTurboPascalPositiveIfHaltPatterns;
 { Reconstruction des validations fondees sur ParamCount }
 ProcessTurboPascalParamCountIfPatterns;
 { Reconstruction des tests d'options fondes sur ParamStr }
 ProcessTurboPascalParamStrIfPatterns;
 { TODO 21 - Generation en-tete Pascal }
 ProcessHeaderGeneration;
 { TODO 22 - Generation corps procedures }
 ProcessBodyGeneration;
 { TODO 25 - Verification et rapport }
 ProcessVerificationReport;
END.
