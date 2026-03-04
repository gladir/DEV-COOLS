{ ================================================================
  MASM.PAS - Macro Assembleur 8086 compatible MASM 5.x
  ================================================================

  Clone de Microsoft Macro Assembler (MASM) pour DOS 8086.
  Produit des fichiers .OBJ au format Intel Object Module Format
  (OMF) compatibles avec :
    - Microsoft LINK (MASM 5.x / 6.x)
    - IBM Macro Assembler
    - Turbo C / Turbo Pascal TLINK
    - Borland TLINK
    - Watcom WLINK
  L'assembleur effectue un assemblage en deux passes pour
  resoudre toutes les references avant.

  @author:   Sylvain Maltais (support@gladir.com)
  @created:  2026
  @website:  https://www.gladir.com/dev-cools
  @abstract: Target: Turbo Pascal 7 / Free Pascal 3.2 (-Mtp)
  @output:   Intel OMF .OBJ (MASM 5.x compatible)

  ================================================================
  PLAN D IMPLEMENTATION - 25 TODOS
  ================================================================

  TODO 01 - INFRASTRUCTURE DE BASE
    Types fondamentaux : TString (String[127]), TByte, TWord,
    TLong (LongInt). Constantes : VERSION='1.0', MAX_SYM=4096,
    MAX_SEG=16, MAX_GRP=8, MAX_FIXUP=8192, MAX_MACRO=256,
    MAX_STRUCT=64, MAX_IF_DEPTH=32. Enumerations TTokenKind
    (TK_IDENT, TK_NUMBER, TK_STRING, TK_PUNCT, TK_NEWLINE,
    TK_EOF), TSymKind (SK_LABEL, SK_PUBLIC, SK_EXTERN, SK_EQU,
    SK_GROUP, SK_SEG, SK_MACRO, SK_STRUCT), TDataSize
    (DS_BYTE, DS_WORD, DS_DWORD, DS_QWORD, DS_TBYTE, DS_UNKNOWN).
    Record TToken (kind, val, num_val, line_num). Tableaux globaux
    sym_table, seg_table, grp_table. Variables globales :
    pass_num (1 ou 2), err_count, warn_count, lc (location counter),
    cur_seg (indice segment courant). Procedure InitTables.
    Procedure ErrorMsg / WarnMsg. Programme principal stub.

  TODO 02 - LECTEUR DE SOURCE ET GESTIONNAIRE D INCLUSION
    Pile d inclusion : max 8 niveaux (INCLUDE imbriques).
    SrcPush(fname) : ouvre le fichier, empile context (File,
    lineno, fname). SrcPop : depile et ferme. SrcReadLine :
    retourne la prochaine ligne sans le CR/LF ; gere la
    continuation de ligne (barre oblique en dernier caractere
    non-espace). SrcAtEnd : True si pile vide. Compteur
    phys_lineno global pour messages d erreur. Pre-traitement :
    supprimer le commentaire (point-virgule jusqu a fin de ligne)
    de chaque ligne lue, SAUF dans les chaines litterales et les
    operateurs de texte entre chevrons.

  TODO 03 - LEXER (ANALYSEUR LEXICAL)
    LexInit, LexNext, LexPeek. Tokens produits : identificateurs
    (alphanumeriques + _ $), nombres (decimaux 123, hex 0ABCh /
    0xABC, octal 777o/777q, binaire 1010b), chaines litterales
    simple ou double guillemets, operateurs et ponctuations
    ( ) [ ] + - * / . : , < > = & | ^ ~ ! ?). Suffixes
    de base numerique : H/h hex, B/b binaire, O/Q/o/q octal,
    D/d decimal, 0x prefixe hex. Nombres flottants reconnus mais
    non supportes en phase 1 (warning). LexIsDirective : teste
    si le token est une directive MASM connue (liste de 80+
    directives). LexIsRegister : AX BX CX DX SI DI SP BP
    AL AH BL BH CL CH DL DH CS DS ES SS. Retourne toujours
    en majuscules (mode case-insensitive par defaut).

  TODO 04 - TABLE DES SYMBOLES
    SymFind(name) -> index ou 0. SymEnter(name, kind, seg,
    offset, size) -> index. SymSetValue(idx, val). Verification
    de doublon en passe 1 (warning si redefini). Symboles
    predetermines : @DATA, @CODE, @STACK, @FILENAME, @VERSION,
    @CURSEG, @WORDSIZE, @MODEL, TRUE (-1), FALSE (0),
    OFFSET et SEG comme operateurs (non symboles). Hachage
    simple (modulo MAX_SYM) pour performance. Verification
    reference avant en passe 1 : marquer SK_UNDEF ; en passe 2
    verifier que tous les SK_UNDEF ont ete resolus. Gestion
    des alias (ALIAS directive) et des etiquettes locales
    prefixees par @@ (portee : jusqu au prochain label global).

  TODO 05 - FORMAT .OBJ INTEL OMF (RECORDS DE BASE)
    Structure d un fichier .OBJ : suite de records OMF.
    Chaque record = TypeByte + Length:Word + Data[] + Checksum.
    Checksum = 256 - (TypeByte + L_lo + L_hi + somme Data) mod 256.
    Buffer de sortie : tableau de Byte (max 65536), flushe dans
    out_file a la fin. Procedures d emission :
      ObjByte(b), ObjWord(w), ObjDWord(d), ObjBeginRecord(typ),
      ObjEndRecord (calcule longueur + checksum, ecrit le record).
    Types de records de base :
      80h THEADR  : nom du module source
      88h COMENT  : commentaire (date, compilateur, info)
      8Ah MODEND  : fin du module (bit 6 = main entry point)
      96h LNAMES  : liste de noms de segments/groupes (index 1..N)
      98h SEGDEF  : definition de segment (USE16, combine, align, nom)
      9Ah GRPDEF  : definition de groupe (ex : DGROUP = .DATA+.BSS)
      90h PUBDEF  : symboles publics (nom, offset, type index)
      8Ch EXTDEF  : symboles externes (nom, type index)

  TODO 06 - FORMAT .OBJ INTEL OMF (DONNEES ET FIXUPS)
    Records de donnees et de relocation :
      A0h LEDATA  : donnees objets locales (seg index, offset, data)
      A2h LIDATA  : donnees repetees (iterated data - DB 100 DUP(0))
      9Ch FIXUPP  : enregistrements de correction d adresse
    Structure FIXUPP : liste de Thread et de Fixup.
    Fixup comprend LOCAT (LOBYTE/OFFSET/BASE/...), FIX_DAT,
    et Target (SEG/GRP/EXT index + displacement).
    Gestion du buffer LEDATA : max 1024 octets par record ; si
    plein, fermer le record courant et en ouvrir un nouveau.
    FlushLEDATA : ecrire le buffer courant.
    GenFixup(type, is_seg_relative, seg_or_ext_idx, displacement).

  TODO 07 - GESTION DES SEGMENTS ET DES MODELES MEMOIRE
    Directives de modele : .MODEL TINY/SMALL/COMPACT/MEDIUM/
    LARGE/HUGE. Effets : taille du groupe DGROUP, type de CALL
    (NEAR/FAR), type de PTR par defaut. Segments standards
    crees automatiquement selon le modele :
      _TEXT  : code (combine PUBLIC, align WORD)
      _DATA  : donnees initialisees (combine PUBLIC, align WORD)
      _BSS   : donnees non initialisees (combine PUBLIC, align WORD)
      STACK  : pile (combine STACK, align PARA, size 512)
      CONST  : constantes en lecture seule
    Directives .CODE [nom], .DATA, .DATA?, .CONST, .STACK [size].
    SEGMENT nom [align] [combine] [class] ... ENDS nom :
    segments explicites (compatibilite MASM 5).
    ASSUME reg:seg : association registre/segment pour encodage
    des prefixes de segment (generes automatiquement si besoin).
    Directive ORG val : positionner le LC dans le segment courant.

  TODO 08 - EXPRESSIONS ET CALCUL D ADRESSES
    Evaluateur d expressions complet (deux passes).
    Operandes : literal numerique, identificateur (symbole),
    $ (LC courant), SEG sym, OFFSET sym, TYPE sym, SIZE sym,
    LENGTH sym, SHORT expr, NEAR PTR expr, FAR PTR expr,
    BYTE PTR expr, WORD PTR expr, DWORD PTR expr.
    Operateurs par ordre de priorite decroissante :
      1. Parentheses, crochets (groupement, indirection)
      2. OFFSET SEG TYPE SIZE LENGTH (operateurs unaires)
      3. PTR (transtypage de pointeur)
      4. * / MOD SHL SHR (multiplicatifs)
      5. + - unaire et binaire (additifs)
      6. NOT (complement bitwise)
      7. AND OR XOR (logiques bitwise)
      8. EQ NE LT LE GT GE (relationnels, resultat -1 ou 0)
    TExpr = Record val:LongInt; is_relocatable:Boolean;
      seg_idx:Integer pour gerer les expressions relocalisables.
    EvalExpr -> TExpr. Erreur si non evaluable en passe 1
    sauf si contient une reference avant (reporter en passe 2).

  TODO 09 - DIRECTIVES DE DONNEES (DB DW DD DQ DT)
    Directives DB (byte), DW (word), DD (dword), DQ (qword),
    DT (tbyte = 10 octets). Syntaxe :
      [label] Dx val [, val, ...]
      [label] Dx N DUP(val [, val, ...])
      [label] DB 'chaine ASCII'
    val peut etre : expression, ?, liste dans DUP,
    chaine litterale (DB uniquement, chaque octet = code ASCII).
    N DUP(?) : allouer N*size octets sans initialisation
    (utiliser LIDATA record OMF pour les blocs nuls repetes).
    Emettre les octets via EmitByte/EmitWord/EmitDWord.
    DUP imbriques supportes (max 8 niveaux).
    Mettre a jour le LC et la taille du segment courant.
    Alignement : ALIGN n (pad 90h NOP en .CODE, 00h en .DATA).

  TODO 10 - DIRECTIVES SYMBOLIQUES (EQU = LABEL ORG)
    EQU : nom EQU expr -> valeur constante (non reassignable).
    = : nom = expr -> valeur constante reassignable (equate).
    LABEL : nom LABEL type -> creer un label du type donne
    sans emettre de donnees (alias a la position courante).
    ORG : ORG expr -> repositionner le LC (aucun fixup emis).
    EVEN : aligner sur word (equivalent ALIGN 2 en .CODE).
    ALIGN n : n = 1, 2, 4, 8, 16, 256.
    $ : symbole dollar = LC courant dans le segment courant.
    LOCAL label [, label ...] dans MACRO : noms uniques
      generes a chaque expansion (suffixe @@0000, @@0001...).
    RECORD nom : definition de structure de bits ; champs emballes
    dans un BYTE ou WORD, masques et decalages calcules auto.

  TODO 11 - DIRECTIVES DE VISIBILITE (PUBLIC EXTRN GLOBAL)
    PUBLIC nom [, nom ...] : exporter le symbole dans le
    fichier .OBJ (record PUBDEF). Peut apparaitre avant ou
    apres la definition du symbole (reference avant valide).
    EXTRN nom:type [, nom:type ...] : declarer un symbole
    externe (record EXTDEF). type = BYTE WORD DWORD NEAR FAR
    ABS PROC. Plusieurs EXTRN dans le meme fichier : OK.
    GLOBAL nom:type [, ...] : PUBLIC si defini localement,
    EXTRN si non defini (MASM 6.x seulement).
    Enregistrements PUBDEF : un par segment, groupes par SEGDEF.
    Gestion des fixups vers les EXTRN : FIXUPP avec
    Target = EXT + index EXTDEF.
    COMM nom:type[:count] : variable commune (BSS non initialisee)
    pour link commun style C (COMDEF record, type B ou F).

  TODO 12 - ENCODAGE DES INSTRUCTIONS 8086 (MOV ADD SUB AND OR)
    Encodage binaire complet des instructions 8086 de base.
    Modes d adressage : registre (r/r), immediat (r/imm),
    memoire directe (r/[addr]), indirecte (r/[BX+SI+disp]).
    Octet ModRM : mod(2 bits) reg(3 bits) r/m(3 bits).
      mod=00 : [r/m] (sauf r/m=110 -> disp16 direct)
      mod=01 : [r/m + disp8 signe]
      mod=10 : [r/m + disp16]
      mod=11 : registre direct
    Table d adressage 8086 : [BX+SI]=0, [BX+DI]=1, [BP+SI]=2,
    [BP+DI]=3, [SI]=4, [DI]=5, [disp16]=6, [BX]=7.
    Prefixes de segment (26h=ES 2Eh=CS 36h=SS 3Eh=DS).
    Instructions : MOV r,r/m/imm ; ADD/SUB/AND/OR/XOR/CMP r,r/m/imm ;
    INC/DEC/NOT/NEG r/m ; XCHG r,r/m ; LEA r,m ; LDS/LES r,m.
    TEST r/m,r/imm. Encodage sign-extend (83h) si imm8 signe.

  TODO 13 - ENCODAGE DES SAUTS ET APPELS (JMP CALL RET)
    JMP SHORT label    : EBh + cb (deplacement 8 bits signe)
    JMP NEAR PTR label : E9h + cw (deplacement 16 bits signe)
    JMP FAR PTR label  : EAh + ptr16:16 (segment:offset)
    JMP r/m16          : FFh /4
    CALL NEAR PTR label: E8h + cw
    CALL FAR PTR label : 9Ah + ptr16:16
    CALL r/m16         : FFh /2
    RET [n]  : C3h ou C2h + iw (NEAR)
    RETF [n] : CBh ou CAh + iw (FAR)
    Sauts conditionnels Jcc label : 70h..7Fh + cb (SHORT seulement
    en 8086 ; NEAR necessite inversion + JMP SHORT autour).
    JCXZ label : E3h + cb.
    LOOP/LOOPE/LOOPNE label : E2/E1/E0 + cb.
    Resolution des forwards : en passe 1, reserver 2 octets NOP ;
    en passe 2, calculer le deplacement et patcher le buffer.

  TODO 14 - ENCODAGE DES INSTRUCTIONS ARITHMETIQUES ET LOGIQUES
    MUL r/m8 : F6h /4     IMUL r/m8 : F6h /5
    MUL r/m16: F7h /4     IMUL r/m16: F7h /5
    IMUL r16,imm (186+, pas 8086 pur) : warning si .8086 actif.
    DIV r/m8 : F6h /6     IDIV r/m8 : F6h /7
    DIV r/m16: F7h /6     IDIV r/m16: F7h /7
    CBW : 98h   CWD : 99h
    AAA : 37h   AAS : 3Fh   DAA : 27h   DAS : 2Fh
    AAM : D4h 0Ah  AAD : D5h 0Ah
    ROL/ROR/RCL/RCR/SHL/SAL/SHR/SAR : D0h-D3h selon operandes
      (D0=r/m8,1 ; D1=r/m16,1 ; D2=r/m8,CL ; D3=r/m16,CL).
    Shifts par imm8 (D0/D1 + 0Ch) pour 80186+ (warning).
    Instructions flag : STC CLC CMC STD CLD STI CLI.
    PUSHF : 9Ch   POPF : 9Dh   SAHF : 9Eh   LAHF : 9Fh.
    XLAT : D7h.

  TODO 15 - ENCODAGE PILE, CHAINES ET E/S
    PUSH r16 : 50h+r    POP r16 : 58h+r
    PUSH r/m16 : FFh /6  POP r/m16 : 8Fh /0
    PUSH imm (186+, warning) : encodage sign-extend si imm8.
    PUSH CS/DS/ES/SS : 0E/1E/06/16  POP DS/ES/SS : 1F/07/17
    PUSHA/POPA (80186+, warning en mode .8086).
    PUSHF : 9Ch   POPF : 9Dh.
    Instructions de chaines (prefixes REP/REPE/REPZ/REPNE/REPNZ):
      MOVSB/MOVSW : A4h/A5h
      CMPSB/CMPSW : A6h/A7h
      SCASB/SCASW : AEh/AFh
      STOSB/STOSW : AAh/ABh
      LODSB/LODSW : ACh/ADh
    Ports E/S : IN AL,imm8 ; IN AL,DX ; IN AX,DX ;
      OUT imm8,AL ; OUT DX,AL ; OUT DX,AX (E4/E5/EC/ED/EE/EF).
    INT n : CDh n.  INT3 : CCh.  INTO : CEh.  IRET : CFh.
    HLT : F4h.  NOP : 90h.  WAIT : 9Bh.  LOCK : F0h.
    XCHG AX,r16 : 90h+r (encode comme NOP pour AX,AX).
    ESC cop,src : D8h-DFh (interface coprocesseur 8087).

  TODO 16 - STRUCTURES (STRUC / ENDS)
    Syntaxe :
      nom STRUC
        champ1 DB/DW/DD valeur_par_defaut
        champ2 DB/DW/DD ?
      nom ENDS
    Enregistrement dans struct_table : nom, liste de champs
    (nom, offset, taille, valeur par defaut). Calcul de
    SIZE nom (= total octets), OFFSET nom.champ.
    Instanciation : var_name nom <val1, val2, ...>.
      val peut etre vide (valeur par defaut) ou une expression.
      Emettre les octets initialises.
    Tableau de structures : var_name nom N DUP(<>).
    Acces a un champ : [BX].champ -> [BX + offset_champ].
    RECORD (structure de bits) : champs de bits emballes dans
    un BYTE ou WORD, masques et decalages calcules automatiquement.

  TODO 17 - MACROS (MACRO ENDM LOCAL EXITM PURGE)
    Syntaxe :
      nom MACRO [param1 [, param2 ...]]
        corps de la macro
      ENDM
    Stockage du corps dans macro_table (liste de lignes texte).
    Substitution des parametres : &param dans le corps de macro.
    LOCAL label : generer un label unique par expansion
    (@@0000, @@0001 ..., incrementes globalement).
    Expansion recursive : appel de macro dans une macro
    (profondeur max configurable, ex 32 niveaux).
    Directives a l interieur d une macro :
      EXITM : sortir de la macro en cours d expansion.
      REPT n ... ENDM : repeter n fois le corps du bloc.
      IRP param, <liste> ... ENDM : iterer sur une liste.
      IRPC param, chaine ... ENDM : iterer sur chaque char.
    PURGE nom [, nom ...] : supprimer une macro existante.
    Operateurs de substitution d arguments :
      & (concatenation), % (evaluation expression), ! (escape).

  TODO 18 - ASSEMBLAGE CONDITIONNEL (IF IFDEF ELSE ENDIF)
    Blocs conditionnels (jusqu a IF_DEPTH = 32 niveaux):
      IF expr     : si expr <> 0, assembler le bloc
      IFE expr    : si expr = 0
      IFDEF nom   : si nom est defini (non SK_UNDEF)
      IFNDEF nom  : si nom n est pas defini
      IFB <arg>   : si argument macro est vide
      IFNB <arg>  : si argument macro n est pas vide
      IFIDN <a>,<b> / IFIDNI <a>,<b> (insensible a la casse)
      IFDIF <a>,<b>
      IF1 / IF2   : vrai en passe 1 uniquement / passe 2 uniquement
      ELSE / ELSEIF expr
      ENDIF
    En passe 1, les blocs false doivent quand meme etre empiles
    pour maintenir la profondeur de nidification correcte.
    Directives d erreur d assemblage conditionnel :
    .ERR .ERR1 .ERR2 .ERRDEF .ERRNDEF .ERRB .ERRNB
    .ERRIDN .ERRDIF .ERRGE .ERRLE .ERRGT .ERRLT .ERRE .ERRNZ.

  TODO 19 - PROCEDURES ET CONVENTIONS D APPEL (PROC ENDP)
    Syntaxe MASM 5.x de base :
      nom PROC [NEAR | FAR]
        corps de la procedure
      nom ENDP
    Extensions MASM 6.x (optionnelles) :
      nom PROC [NEAR|FAR] [LANG: C | PASCAL | FORTRAN | SYSCALL]
               [USES reg1 reg2 ...]
               [param1:TYPE [, param2:TYPE ...]]
    Effets de USES : emettre PUSH reg... en entree / POP reg... en sortie.
    Effets des parametres (ARG) : creer labels locaux avec offset BP
    selon la convention d appel (C = ordre inverse, PASCAL = ordre direct).
    ENTER n,0 et LEAVE (80186+, warning en mode .8086).
    Verification que ENDP correspond au dernier PROC ouvert.
    Symbole associe : type = NEAR ou FAR, SK_LABEL. Si declare PUBLIC
    avant ou apres le PROC, enregistrer dans PUBDEF.
    INVOKE (MASM 6.x) : generer automatiquement le code d appel
    en empilant les arguments selon la convention de la procedure.

  TODO 20 - DEUX PASSES D ASSEMBLAGE ET GESTION DES FIXUPS
    Passe 1 : lire tout le source sans emettre dans le .OBJ ;
    construire la table des symboles, calculer les offsets (LC)
    de tous les labels. Pour les references avant, noter la
    position et le type de fixup attendu dans une table interne.
    Resultat : table des symboles complete (sauf EXTRN).
    Passe 2 : re-lire le source ; emettre les octets du code
    et des donnees dans les buffers LEDATA par segment ; calculer
    toutes les expressions ; remplir les records FIXUPP. Pour
    les sauts SHORT, verifier que le deplacement tient en 8 bits
    signe ; sinon promouvoir en NEAR (modifie le LC -> relancer
    la passe 2 si necessaire, max 3 iterations pour convergence).
    Table de fixups interne : liste de [offset_dans_ledata,
    type (OFFSET/SEG/SHORT), symbole_cible]. Emit FIXUPP OMF a
    la fin de chaque LEDATA si la table n est pas vide.
    Fixups pour EXTRN : FIXUPP avec Target = EXT + index EXTDEF.

  TODO 21 - FICHIER DE LISTING (.LST)
    Option /L ou ligne de commande 4eme parametre : generer .LST.
    Format du listing (compatible MASM 5.x) :
      [numero_ligne] [offset hexa] [octets hex max 8] [source]
    Continuer sur la ligne suivante si plus de 8 octets generes.
    Sections supplementaires en fin de listing :
      Table des symboles : nom, type, valeur, segment, portee.
      Table des macros : nom, nb parametres, nb expansions.
      Statistiques : lignes lues, erreurs, avertissements,
      octets de code, octets de donnees.
    Directives de listing :
      .LIST / .NOLIST : activer/desactiver l emission du listing.
      .LISTALL : lister aussi les blocs conditionnels inactifs.
      .XLIST : synonyme de .NOLIST.
      PAGE [lignes],[colonnes] : saut de page / dimensionnement.
      TITLE texte / SUBTTL texte : titres et sous-titres de page.
    Option /X : lister les expansions de macros (MASM 5.x).
    Option /C : lister les cross-references symboles/lignes.

  TODO 22 - GESTION DES GROUPES (GROUP ASSUME)
    GROUP nom, seg1 [, seg2 ...] : regrouper plusieurs segments
    en un seul groupe (meme valeur de registre de segment).
    Groupe standard DGROUP = _DATA + _BSS + CONST + STACK.
    Emission du record GRPDEF OMF.
    ASSUME reg:group/seg/NOTHING : indiquer a l assembleur
    quel segment est associe a DS/CS/ES/SS pour calcul
    automatique des prefixes de segment.
    Calcul du deplacement d un symbole par rapport a son groupe
    (OFFSET dans DGROUP vs OFFSET dans _DATA).
    Fixup de type GROUP dans FIXUPP : target = GRP + index.
    Verification de coherence : si un symbole est dans un segment
    faisant partie d un groupe, son offset dans PUBDEF doit etre
    relatif au debut du groupe.
    @STACK, @DATA, @CODE : symboles predefinis representant la
    base des groupes correspondants dans le modele memoire courant.

  TODO 23 - DIRECTIVE INCLUDE ET SYMBOLES PREDEFINIS
    INCLUDE fichier : inserer le fichier a la position courante
    (SrcPush). Recherche dans : repertoire courant, puis les
    repertoires /I specifies sur la ligne de commande, puis
    la variable d environnement INCLUDE. Max 8 niveaux.
    Symboles predetermines du contexte d assemblage :
      @CUR_LINE   : numero de ligne courante
      @FILENAME   : nom du fichier source courant
      @DATE       : date de l assemblage (ex 'MM/DD/YY')
      @TIME       : heure de l assemblage (ex 'HH:MM:SS')
      @CURSEG     : nom du segment courant (chaine)
      @WORDSIZE   : 2 (16-bit) ou 4 (32-bit, extension)
    Directives de module :
      INCLUDELIB nom : emettre un record COMENT OMF type A3h
        contenant le nom de la librairie .LIB a passer a LINK.
      OPTION CASEMAP:NONE/ALL/NOTPUBLIC (MASM 6.x).
      NAME module_name : remplacer THEADR par le nom fourni.
    .RADIX n : changer la base de numerotation par defaut
    (2 a 16) pour les litteraux numeriques sans suffixe.

  TODO 24 - TRAITEMENT DE LA LIGNE DE COMMANDE ET OPTIONS
    Syntaxe :
      MASM [options] source[.ASM] [obj[.OBJ] [lst[.LST] [crf[.CRF]]]]
    Options MASM 5.x (compatibilite) :
      /A      : trier les segments par ordre alphabetique
      /B n    : taille du buffer source (parametre ignore)
      /C      : generer une table de cross-reference (.CRF)
      /D      : mode double-pass (toujours actif dans MASM.PAS)
      /L      : generer un fichier listing (.LST)
      /ML     : labels sensibles a la casse (garder min/maj)
      /MU     : convertir tout en majuscules (comportement defaut)
      /MX     : symboles publics et externes sensibles a la casse
      /N      : supprimer les tables de symboles du listing
      /S      : trier les segments par ordre de definition (defaut)
      /T      : mode silencieux (pas d affichage sauf erreurs)
      /W0 /W1 /W2 : niveau d avertissement (0=aucun, 2=tous)
      /X      : lister les blocs conditionnels inactifs
      /Z      : afficher les lignes sources avec erreur en sortie
      /Zi /Zd : infos CodeView dans le .OBJ (records de debug)
      /I chem : ajouter repertoire de recherche pour INCLUDE
      /Dsym[=val] : definir un symbole sur la ligne de commande
    ParseArgs : analyser ParamStr(1..ParamCount).
    Si aucun parametre ou /? : afficher l aide et terminer.

  TODO 25 - INTEGRATION FINALE, VALIDATION ET TESTS
    Programme principal : ParseArgs -> Passe1 -> Passe2 -> EcritOBJ.
    Ecriture du fichier .OBJ dans l ordre OMF standard :
      1. THEADR  (nom module derive du nom de fichier source)
      2. COMENT  (date, version de l assembleur)
      3. LNAMES  (noms de segments et de classes)
      4. SEGDEF  (un record par segment defini)
      5. GRPDEF  (DGROUP et autres groupes)
      6. EXTDEF  (symboles externes EXTRN)
      7. PUBDEF  (symboles publics PUBLIC par segment)
      8. LEDATA + FIXUPP (donnees + relocations par segment)
      9. MODEND  (point d entree si END label, sinon terminaison)
    Fichiers de test a assembler et valider :
      hello.asm   : .MODEL SMALL / .CODE + .DATA / INT 21h / INT 20h
      arith.asm   : ADD SUB MUL DIV, resultats stockes en memoire
      callsub.asm : PROC/ENDP, CALL/RET, convention C avec USES
      macro.asm   : MACRO, LOCAL, expansion multiple avec REPT/IRP
      extern.asm  : PUBLIC/EXTRN, FIXUPP vers sous-programme externe
      fibo.asm    : boucle LOOP, etiquettes locales @@
    Validation : linker avec TLINK (Turbo C 2.0) et LINK 3.x/4.x.
    Rapport de fin : lignes, symboles, octets code/data,
    erreurs, avertissements, temps d assemblage approximatif.

  ================================================================ }

Program MASM;

{ ============================================================
  TODO 01 - INFRASTRUCTURE DE BASE - IMPLEMENTE
  ============================================================ }

{ ---- Constantes generales ---- }
Const
  VERSION      = '1.0';
  MAX_SYM      = 4096; { max symboles (heap, compte seulement) }
  MAX_SEG      = 16;   { max segments definis }
  MAX_GRP      = 8;    { max groupes definis }
  MAX_FIXUP    = 8192; { max fixups internes par passe }
  MAX_MACRO    = 256;  { max macros definies }
  MAX_STRUCT   = 64;   { max structures STRUC }
  MAX_IF_DEPTH = 32;   { profondeur max des blocs IF imbriques }
  HASH_SIZE    = 256;  { buckets de la table de hachage symboles }
  INC_DEPTH    = 8;    { max niveaux d inclusion INCLUDE }

{ ---- Types de base ---- }
Type
  TString    = String[127]; { chaine generale (lignes source, noms) }
  TSymString = String[32];  { nom de symbole/segment (uppercase) }
  TByte      = Byte;
  TWord      = Word;
  TLong      = LongInt;

  { Genres de tokens produits par le lexer }
  TTokenKind = (
    TK_IDENT,    { identificateur ou mot-cle / directive / mnemonic }
    TK_NUMBER,   { literal numerique (dec/hex/oct/bin) }
    TK_STRING,   { chaine litterale delimitee par ' ou " }
    TK_PUNCT,    { operateur ou ponctuation ( ) [ ] + - * / . : , = }
    TK_NEWLINE,  { fin de ligne logique (separateur d instruction) }
    TK_EOF       { fin de fichier source }
  );

  { Genre d un symbole dans la table des symboles }
  TSymKind = (
    SK_UNDEF,    { reference avant non encore resolue }
    SK_LABEL,    { etiquette de code ou de donnee }
    SK_PUBLIC,   { symbole exporte (PUBLIC) }
    SK_EXTERN,   { symbole importe (EXTRN) }
    SK_EQU,      { constante EQU (non reassignable) ou = (reassignable) }
    SK_GROUP,    { nom de groupe (GROUP) }
    SK_SEG,      { nom de segment (SEGMENT) }
    SK_MACRO,    { macro (MACRO/ENDM) }
    SK_STRUCT    { structure de donnees (STRUC/ENDS) }
  );

  { Taille d un operande de donnee }
  TDataSize = (
    DS_BYTE,     { 1 octet  - DB }
    DS_WORD,     { 2 octets - DW }
    DS_DWORD,    { 4 octets - DD }
    DS_QWORD,    { 8 octets - DQ }
    DS_TBYTE,    { 10 octets - DT }
    DS_UNKNOWN   { taille non specifiee / non applicable }
  );

  { Token produit par le lexer }
  TToken = Record
    kind     : TTokenKind; { type de token }
    val      : TString;    { valeur textuelle (toujours en majuscules) }
    num_val  : TLong;      { valeur numerique (valide si TK_NUMBER) }
    line_num : Integer;    { numero de ligne source logique }
  End;

  { ------- Table des symboles (allocation dynamique sur le heap) ------- }
  PSymbol = ^TSymbol;
  TSymbol = Record
    name    : TSymString; { nom du symbole (uppercase) }
    kind    : TSymKind;   { genre du symbole }
    seg_idx : Integer;    { index dans seg_table (0 = absolu / externe) }
    offset  : TWord;      { offset dans le segment au moment de la def. }
    value   : TLong;      { valeur absolue (SK_EQU, SK_EXTERN, etc.) }
    size    : TWord;      { taille en octets (labels donnee, STRUC) }
    flags   : TByte;      { bit 0=is_public, bit 1=is_extern, bit 2=is_defined }
    next    : PSymbol;    { maillon suivant dans la chaine de hachage }
  End;

  { ------- Segments ------- }
  TSegCombine = (
    SC_PRIVATE, { segment prive (non fusionne par LINK) }
    SC_PUBLIC,  { fusionner avec segments de meme nom/classe }
    SC_COMMON,  { superposer (taille = max des tailles) }
    SC_STACK,   { pile (fusionner, combine = STACK) }
    SC_MEMORY,  { alias de SC_PUBLIC pour compatibilite }
    SC_AT       { segment absolu (AT valeur) }
  );
  TSegAlign = (
    SA_BYTE,    { aligner a l octet }
    SA_WORD,    { aligner au mot (2 octets) }
    SA_PARA,    { aligner au paragraphe (16 octets) }
    SA_PAGE,    { aligner a la page (256 octets) }
    SA_DWORD    { aligner au double-mot (4 octets) }
  );

  TSegInfo = Record
    name       : TSymString;  { nom du segment }
    class_name : TSymString;  { classe OMF (ex: 'CODE','DATA','STACK') }
    combine    : TSegCombine; { type de combinaison LINK }
    align      : TSegAlign;   { alignement OMF }
    size       : TWord;       { taille totale accumulee (octets) }
    cur_lc     : TWord;       { location counter courant dans ce segment }
    lnames_idx : Integer;     { index 1-base dans le record LNAMES OMF }
    defined    : Boolean;     { True si segment declare par SEGMENT ou .MODEL }
  End;

  { ------- Groupes ------- }
  TGrpInfo = Record
    name      : TSymString;              { nom du groupe (ex: DGROUP) }
    seg_count : Integer;                 { nb de segments appartenant au groupe }
    segs      : Array[1..MAX_SEG] Of Integer; { indices 1-base dans seg_table }
    defined   : Boolean;                 { True si groupe declare }
  End;

{ ---- Variables globales ---- }
Var
  { Tables de la chaine de hachage (symboles sur le heap) }
  hash_table : Array[0..HASH_SIZE-1] Of PSymbol;

  { Tables fixes (seg_table et grp_table sont petites, sur la pile globale) }
  seg_table  : Array[1..MAX_SEG] Of TSegInfo;
  grp_table  : Array[1..MAX_GRP] Of TGrpInfo;

  { Compteurs de tables }
  sym_count  : Integer;  { nb de PSymbol alloues sur le heap }
  seg_count  : Integer;  { nb de segments definis }
  grp_count  : Integer;  { nb de groupes definis }

  { Etat de l assemblage }
  pass_num   : Integer;  { passe courante : 1 ou 2 }
  err_count  : Integer;  { nb d erreurs detectees }
  warn_count : Integer;  { nb d avertissements }
  lc         : TWord;    { location counter courant (dans cur_seg) }
  cur_seg    : Integer;  { index segment courant dans seg_table (0=hors segment) }

  { Fichiers }
  src_fname  : TString;  { nom du fichier source .ASM }
  obj_fname  : TString;  { nom du fichier objet  .OBJ }
  lst_fname  : TString;  { nom du fichier listing .LST }
  do_listing : Boolean;  { True = generer le fichier .LST }

  { Ligne de source courante (pour messages d erreur) }
  cur_line   : TString;  { contenu de la ligne en cours d analyse }
  cur_lineno : Integer;  { numero de ligne logique (apres continuation) }

{ ============================================================
  Fonction de hachage djb2 adaptee (retourne 0..HASH_SIZE-1)
  ============================================================ }
Function HashName(Const s : TSymString) : Integer;
Var
  i : Integer;
  h : LongInt;
Begin
  h := 5381;
  For i := 1 To Length(s) Do
    h := ((h Shl 5) + h) Xor LongInt(Ord(s[i]));
  If h < 0 Then h := -h;
  HashName := Integer(h Mod HASH_SIZE);
End;

{ ============================================================
  InitTables : remettre toutes les tables a zero / nil / False
  ============================================================ }
Procedure InitTables;
Var
  i, j : Integer;
Begin
  { vider la table de hachage }
  For i := 0 To HASH_SIZE-1 Do
    hash_table[i] := Nil;

  { initialiser les segments }
  For i := 1 To MAX_SEG Do
  Begin
    With seg_table[i] Do
    Begin
      name       := '';
      class_name := '';
      combine    := SC_PRIVATE;
      align      := SA_PARA;
      size       := 0;
      cur_lc     := 0;
      lnames_idx := 0;
      defined    := False;
    End;
  End;

  { initialiser les groupes }
  For i := 1 To MAX_GRP Do
  Begin
    With grp_table[i] Do
    Begin
      name      := '';
      seg_count := 0;
      defined   := False;
      For j := 1 To MAX_SEG Do segs[j] := 0;
    End;
  End;

  sym_count  := 0;
  seg_count  := 0;
  grp_count  := 0;
  pass_num   := 0;
  err_count  := 0;
  warn_count := 0;
  lc         := 0;
  cur_seg    := 0;
  cur_lineno := 0;
  do_listing := False;
  src_fname  := '';
  obj_fname  := '';
  lst_fname  := '';
  cur_line   := '';
End;

{ ============================================================
  ErrorMsg : afficher un message d erreur (style MASM A2xxx)
  ============================================================ }
Procedure ErrorMsg(Const msg : TString);
Begin
  Inc(err_count);
  If src_fname <> '' Then
    Writeln(src_fname, '(', cur_lineno, ') : error A2',
            err_count:3, ': ', msg)
  Else
    Writeln('error A2', err_count:3, ': ', msg);
  If cur_line <> '' Then
    Writeln('  ', cur_line);
End;

{ ============================================================
  WarnMsg : afficher un avertissement (style MASM A4xxx)
  ============================================================ }
Procedure WarnMsg(Const msg : TString);
Begin
  Inc(warn_count);
  If src_fname <> '' Then
    Writeln(src_fname, '(', cur_lineno, ') : warning A4',
            warn_count:3, ': ', msg)
  Else
    Writeln('warning A4', warn_count:3, ': ', msg);
End;

{ ============================================================
  TODO 02 - LECTEUR DE SOURCE ET GESTIONNAIRE D INCLUSION
  ============================================================

  Principe :
    - Pile de max INC_DEPTH contextes de fichier (SrcPush/SrcPop).
    - SrcReadLine retourne la prochaine ligne logique (avec
      expansion des tabulations et suppression du commentaire ;).
    - La continuation de ligne est detectee si le dernier
      caractere non-espace est une barre oblique inverse \ ;
      dans ce cas les lignes suivantes sont concatenees jusqu a
      ce qu il n y en ait plus.
    - phys_lineno est incrementee a chaque ligne physique lue.
  ============================================================ }

{ ---- Types de la pile d inclusion ---- }
Type
  TSrcContext = Record
    f        : Text;         { fichier Pascal ouvert }
    fname    : TString;      { nom du fichier }
    lineno   : Integer;      { dernier numero de ligne physique lu }
    is_open  : Boolean;      { True si le fichier est ouvert }
  End;

{ ---- Variables du lecteur de source ---- }
Var
  src_stack  : Array[0..INC_DEPTH-1] Of TSrcContext; { pile d inclusion }
  src_top    : Integer;  { indice du contexte courant (-1 = vide) }
  phys_lineno: Integer;  { compteur de lignes physiques global }

  { Repertoires de recherche INCLUDE (/I sur la ligne de commande) }
  inc_dirs   : Array[0..15] Of TString;
  inc_dir_cnt: Integer;

{ ============================================================
  SrcInit : initialiser la pile d inclusion
  ============================================================ }
Procedure SrcInit;
Var
  i : Integer;
Begin
  src_top     := -1;
  phys_lineno := 0;
  inc_dir_cnt := 0;
  For i := 0 To INC_DEPTH-1 Do
  Begin
    src_stack[i].fname   := '';
    src_stack[i].lineno  := 0;
    src_stack[i].is_open := False;
  End;
  For i := 0 To 15 Do
    inc_dirs[i] := '';
End;

{ ============================================================
  SrcAtEnd : True si la pile est vide (plus rien a lire)
  ============================================================ }
Function SrcAtEnd : Boolean;
Begin
  SrcAtEnd := (src_top < 0);
End;

{ ============================================================
  SrcFindFile : chercher fname dans le repertoire courant puis
  dans inc_dirs ; retourne le chemin complet trouve ou fname
  si non trouve.
  ============================================================ }
Function SrcFindFile(Const fname : TString) : TString;
Var
  i    : Integer;
  path : TString;
  tmp  : Text;
Begin
  { 1. tel quel (absolu ou relatif au CWD) }
  Assign(tmp, fname);
  {$I-}
  Reset(tmp);
  {$I+}
  If IoResult = 0 Then
  Begin
    Close(tmp);
    SrcFindFile := fname;
    Exit;
  End;
  { 2. dans les repertoires /I }
  For i := 0 To inc_dir_cnt-1 Do
  Begin
    path := inc_dirs[i];
    If (Length(path) > 0) And (path[Length(path)] <> '\') Then
      path := path + '\';
    path := path + fname;
    Assign(tmp, path);
    {$I-}
    Reset(tmp);
    {$I+}
    If IoResult = 0 Then
    Begin
      Close(tmp);
      SrcFindFile := path;
      Exit;
    End;
  End;
  SrcFindFile := fname; { non trouve, retourner tel quel }
End;

{ ============================================================
  SrcPush : ouvrir un fichier et l empiler
  ============================================================ }
Procedure SrcPush(Const fn : TString);
Var
  rpath : TString;
Begin
  If src_top >= INC_DEPTH-1 Then
  Begin
    ErrorMsg('INCLUDE trop profond (max ' +
             Chr(Ord('0') + INC_DEPTH) + ' niveaux)');
    Exit;
  End;
  rpath := SrcFindFile(fn);
  Inc(src_top);
  With src_stack[src_top] Do
  Begin
    fname   := rpath;
    lineno  := 0;
    is_open     := False;
    Assign(f, rpath);
    {$I-}
    Reset(f);
    {$I+}
    If IoResult <> 0 Then
    Begin
      Dec(src_top);
      ErrorMsg('Impossible d ouvrir le fichier : ' + rpath);
      Exit;
    End;
    is_open := True;
  End;
  { mettre a jour src_fname avec le fichier courant }
  src_fname := src_stack[src_top].fname;
End;

{ ============================================================
  SrcPop : fermer le fichier courant et depiler
  ============================================================ }
Procedure SrcPop;
Begin
  If src_top < 0 Then Exit;
  With src_stack[src_top] Do
    If is_open Then
    Begin
      Close(f);
      is_open := False;
    End;
  Dec(src_top);
  If src_top >= 0 Then
    src_fname := src_stack[src_top].fname
  Else
    src_fname := '';
End;

{ ============================================================
  SrcStripComment : supprimer le commentaire (;) d une ligne,
  en respectant les chaines entre guillemets simples ou doubles.
  ============================================================ }
Function SrcStripComment(Const line : TString) : TString;
Var
  i      : Integer;
  in_sq  : Boolean; { dans une chaine simple quote }
  in_dq  : Boolean; { dans une chaine double quote }
  c      : Char;
  result : TString;
Begin
  in_sq  := False;
  in_dq  := False;
  result := '';
  For i := 1 To Length(line) Do
  Begin
    c := line[i];
    If (c = '''') And Not in_dq Then in_sq := Not in_sq
    Else If (c = '"') And Not in_sq Then in_dq := Not in_dq
    Else If (c = ';') And Not in_sq And Not in_dq Then
      Break; { debut du commentaire }
    result := result + c;
  End;
  { supprimer les espaces de fin }
  While (Length(result) > 0) And (result[Length(result)] = ' ') Do
    Delete(result, Length(result), 1);
  SrcStripComment := result;
End;

{ ============================================================
  SrcExpandTabs : remplacer les tabulations par des espaces
  (tabstop = 8).
  ============================================================ }
Function SrcExpandTabs(Const line : TString) : TString;
Var
  i      : Integer;
  col    : Integer;
  result : TString;
  spaces : Integer;
  j      : Integer;
Begin
  result := '';
  col    := 1;
  For i := 1 To Length(line) Do
  Begin
    If line[i] = #9 Then
    Begin
      spaces := 8 - ((col-1) Mod 8);
      For j := 1 To spaces Do
      Begin
        result := result + ' ';
        Inc(col);
      End;
    End
    Else
    Begin
      result := result + line[i];
      Inc(col);
    End;
  End;
  SrcExpandTabs := result;
End;

{ ============================================================
  SrcIsContinued : True si la ligne se termine par \ (continuation)
  Retire le \ de la fin de la chaine.
  ============================================================ }
Function SrcIsContinued(Var line : TString) : Boolean;
Var
  trimmed : TString;
  len     : Integer;
Begin
  trimmed := line;
  { retirer les espaces de fin }
  While (Length(trimmed) > 0) And (trimmed[Length(trimmed)] = ' ') Do
    Delete(trimmed, Length(trimmed), 1);
  len := Length(trimmed);
  If (len > 0) And (trimmed[len] = '\') Then
  Begin
    Delete(trimmed, len, 1);
    { retirer les espaces avant le \ }
    While (Length(trimmed) > 0) And (trimmed[Length(trimmed)] = ' ') Do
      Delete(trimmed, Length(trimmed), 1);
    line := trimmed;
    SrcIsContinued := True;
  End
  Else
  Begin
    line := trimmed;
    SrcIsContinued := False;
  End;
End;

{ ============================================================
  SrcReadLine : lire la prochaine ligne logique du fichier
  courant (avec continuation et pre-traitement).
  Retourne True si une ligne a ete lue, False si fin de fichier.
  La ligne resultante est stockee dans cur_line et cur_lineno.
  ============================================================ }
Function SrcReadLine : Boolean;
Var
  raw     : TString;
  logical : TString;
  cont    : Boolean;
Begin
  SrcReadLine := False;
  If SrcAtEnd Then Exit;

  logical := '';
  Repeat
    { si le fichier courant est epuise, depiler }
    While (src_top >= 0) And Eof(src_stack[src_top].f) Do
      SrcPop;
    If SrcAtEnd Then
    Begin
      { fin reelle de tous les fichiers }
      If logical <> '' Then
        Break; { retourner la ligne deja accumulee }
      Exit;
    End;

    { lire une ligne physique }
    ReadLn(src_stack[src_top].f, raw);
    Inc(src_stack[src_top].lineno);
    Inc(phys_lineno);

    { expansion des tabulations }
    raw := SrcExpandTabs(raw);

    { suppression du commentaire (;) }
    raw := SrcStripComment(raw);

    { gestion de la continuation }
    cont := SrcIsContinued(raw);
    If logical <> '' Then
      logical := logical + ' ' + raw
    Else
      logical := raw;
  Until Not cont;

  cur_lineno := src_stack[src_top].lineno;
  cur_line   := logical;
  SrcReadLine := True;
End;

{ ============================================================
  TODO 03 - LEXER (ANALYSEUR LEXICAL) - IMPLEMENTE
  ============================================================

  Le lexer travaille sur la ligne logique courante (lex_line).
  Quand la ligne est epuisee, il appelle SrcReadLine pour en
  obtenir une nouvelle et retourne TK_NEWLINE en separateur.
  Tous les identificateurs sont convertis en majuscules.
  ============================================================ }

{ ---- Variables du lexer ---- }
Var
  lex_line     : TString;  { copie de la ligne en cours de tokenisation }
  lex_pos      : Integer;  { position courante dans lex_line (1-based) }
  lex_tok      : TToken;   { token courant (rempli par LexNext) }
  lex_peek_tok : TToken;   { token de look-ahead }
  lex_has_peek : Boolean;  { True si lex_peek_tok est valide }
  lex_at_eol   : Boolean;  { True si on doit retourner TK_NEWLINE }

{ ============================================================
  LexUpperCase : convertir une TString en majuscules
  ============================================================ }
Function LexUpperCase(Const s : TString) : TString;
Var
  i   : Integer;
  res : TString;
  c   : Char;
Begin
  res := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (c >= 'a') And (c <= 'z') Then
      res := res + Chr(Ord(c) - 32)
    Else
      res := res + c;
  End;
  LexUpperCase := res;
End;

{ ============================================================
  LexIsAlpha : True si c est une lettre
  ============================================================ }
Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := ((c >= 'A') And (c <= 'Z')) Or
                ((c >= 'a') And (c <= 'z'));
End;

{ ============================================================
  LexIsDigit : True si c est un chiffre decimal
  ============================================================ }
Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c >= '0') And (c <= '9');
End;

{ ============================================================
  LexIsHexDigit : True si c est un chiffre hexadecimal
  ============================================================ }
Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := ((c >= '0') And (c <= '9')) Or
                   ((c >= 'A') And (c <= 'F')) Or
                   ((c >= 'a') And (c <= 'f'));
End;

{ ============================================================
  LexIsAlNum : True si c est alphanumerique ou _ ou $
  ============================================================ }
Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := LexIsAlpha(c) Or LexIsDigit(c) Or
                (c = '_') Or (c = '$') Or (c = '@') Or (c = '?');
End;

{ ============================================================
  LexHexVal : valeur numerique d un chiffre hex (0..15)
  ============================================================ }
Function LexHexVal(c : Char) : Integer;
Begin
  If (c >= '0') And (c <= '9') Then LexHexVal := Ord(c) - Ord('0')
  Else If (c >= 'a') And (c <= 'f') Then LexHexVal := Ord(c) - Ord('a') + 10
  Else LexHexVal := Ord(c) - Ord('A') + 10;
End;

{ ============================================================
  LexInit : initialiser le lexer
  ============================================================ }
Procedure LexInit;
Begin
  lex_line         := '';
  lex_pos          := 1;
  lex_has_peek     := False;
  lex_at_eol       := True; { forcer lecture de la 1ere ligne }
  lex_tok.kind     := TK_EOF;
  lex_tok.val      := '';
  lex_tok.num_val  := 0;
  lex_tok.line_num := 0;
  lex_peek_tok     := lex_tok;
End;

{ ============================================================
  LexSkipSpaces : sauter les espaces dans lex_line
  ============================================================ }
Procedure LexSkipSpaces;
Begin
  While (lex_pos <= Length(lex_line)) And
        (lex_line[lex_pos] = ' ') Do
    Inc(lex_pos);
End;

{ ============================================================
  LexReadNumber : lire un token numerique depuis lex_pos.
  Supporte : 0FFh (hex), 0x1AF (hex), 1010b (binaire),
             777q/777o (octal), 1234 (decimal).
  ============================================================ }
Procedure LexReadNumber(Var tok : TToken);
Var
  raw  : TString;
  suf  : Char;
  v    : TLong;
  i    : Integer;
  c    : Char;
  ok   : Boolean;
Begin
  raw := '';
  { cas 0x... (prefixe hexadecimal style C) }
  If (lex_pos + 1 <= Length(lex_line)) And
     (lex_line[lex_pos] = '0') And
     ((lex_line[lex_pos+1] = 'x') Or (lex_line[lex_pos+1] = 'X')) Then
  Begin
    Inc(lex_pos, 2); { sauter 0x }
    While (lex_pos <= Length(lex_line)) And
          LexIsHexDigit(lex_line[lex_pos]) Do
    Begin
      raw := raw + lex_line[lex_pos];
      Inc(lex_pos);
    End;
    v := 0;
    For i := 1 To Length(raw) Do
      v := v * 16 + LexHexVal(raw[i]);
    tok.kind    := TK_NUMBER;
    tok.val     := '0X' + LexUpperCase(raw);
    tok.num_val := v;
    Exit;
  End;

  { lire tous les alphanumeriques }
  While (lex_pos <= Length(lex_line)) And
        (LexIsHexDigit(lex_line[lex_pos]) Or
         (lex_line[lex_pos] = '_')) Do
  Begin
    raw := raw + lex_line[lex_pos];
    Inc(lex_pos);
  End;
  { lire suffixe eventuel (H B O Q D) }
  suf := ' ';
  If lex_pos <= Length(lex_line) Then
  Begin
    c := lex_line[lex_pos];
    If (c = 'h') Or (c = 'H') Then Begin suf := 'H'; Inc(lex_pos); End
    Else If (c = 'b') Or (c = 'B') Then Begin suf := 'B'; Inc(lex_pos); End
    Else If (c = 'o') Or (c = 'O') Then Begin suf := 'O'; Inc(lex_pos); End
    Else If (c = 'q') Or (c = 'Q') Then Begin suf := 'Q'; Inc(lex_pos); End
    Else If (c = 'd') Or (c = 'D') Then Begin suf := 'D'; Inc(lex_pos); End;
    { si le suffixe est suivi d un car alphanumerique, ce n est pas un nombre }
    If (suf <> ' ') And (lex_pos <= Length(lex_line)) And
       LexIsAlNum(lex_line[lex_pos]) Then
    Begin
      { reculer le suffixe - c etait en fait un identificateur }
      Dec(lex_pos);
      suf := ' ';
    End;
  End;

  v  := 0;
  ok := True;
  Case suf Of
    'H' : Begin
            For i := 1 To Length(raw) Do
            Begin
              If Not LexIsHexDigit(raw[i]) Then Begin ok := False; Break; End;
              v := v * 16 + LexHexVal(raw[i]);
            End;
          End;
    'B' : Begin
            For i := 1 To Length(raw) Do
            Begin
              If (raw[i] <> '0') And (raw[i] <> '1') Then
                Begin ok := False; Break; End;
              v := v * 2 + (Ord(raw[i]) - Ord('0'));
            End;
          End;
    'O','Q' : Begin
            For i := 1 To Length(raw) Do
            Begin
              If (raw[i] < '0') Or (raw[i] > '7') Then
                Begin ok := False; Break; End;
              v := v * 8 + (Ord(raw[i]) - Ord('0'));
            End;
          End;
    Else { decimal (y compris 'D') }
          Begin
            For i := 1 To Length(raw) Do
            Begin
              If Not LexIsDigit(raw[i]) Then
              Begin
                { contient des lettres -> probablement hex sans suffixe ou erreur }
                ok := False;
                Break;
              End;
              v := v * 10 + (Ord(raw[i]) - Ord('0'));
            End;
          End;
  End;
  If Not ok Then
  Begin
    WarnMsg('Litteral numerique invalide : ' + raw);
    v := 0;
  End;
  tok.kind    := TK_NUMBER;
  tok.val     := raw + suf;
  tok.num_val := v;
End;

{ ============================================================
  LexReadString : lire une chaine litterale (delimiteur = q)
  ============================================================ }
Procedure LexReadString(Var tok : TToken; q : Char);
Var
  s : TString;
Begin
  s := '';
  Inc(lex_pos); { sauter le guillemet ouvrant }
  While lex_pos <= Length(lex_line) Do
  Begin
    If lex_line[lex_pos] = q Then
    Begin
      Inc(lex_pos); { sauter le guillemet fermant }
      Break;
    End;
    s := s + lex_line[lex_pos];
    Inc(lex_pos);
  End;
  tok.kind    := TK_STRING;
  tok.val     := s;
  tok.num_val := 0;
End;

{ ============================================================
  LexReadIdent : lire un identificateur ou mot-cle.
  Retourne en MAJUSCULES.
  ============================================================ }
Procedure LexReadIdent(Var tok : TToken);
Var
  s : TString;
Begin
  s := '';
  While (lex_pos <= Length(lex_line)) And
        LexIsAlNum(lex_line[lex_pos]) Do
  Begin
    s := s + lex_line[lex_pos];
    Inc(lex_pos);
  End;
  tok.kind    := TK_IDENT;
  tok.val     := LexUpperCase(s);
  tok.num_val := 0;
End;

{ ============================================================
  LexNextRaw : lire le prochain token depuis lex_line
  (sans gestion du lookahead ni des nouvelles lignes)
  ============================================================ }
Procedure LexNextRaw(Var tok : TToken);
Var
  c : Char;
Begin
  tok.line_num := cur_lineno;
  tok.num_val  := 0;

  LexSkipSpaces;

  If lex_pos > Length(lex_line) Then
  Begin
    tok.kind := TK_NEWLINE;
    tok.val  := '';
    Exit;
  End;

  c := lex_line[lex_pos];

  { --- Nombre --- }
  If LexIsDigit(c) Then
  Begin
    LexReadNumber(tok);
    Exit;
  End;

  { --- Chaine litterale --- }
  If (c = '''') Or (c = '"') Then
  Begin
    LexReadString(tok, c);
    Exit;
  End;

  { --- Identificateur / mot-cle --- }
  If LexIsAlpha(c) Or (c = '_') Or (c = '$') Or (c = '@') Or (c = '?') Then
  Begin
    { un identif peut commencer par une lettre qui ressemble a un hex }
    { SAUF s il commence par un chiffre -> traite ci-dessus }
    LexReadIdent(tok);
    Exit;
  End;

  { --- Ponctuation et operateurs a 2 caracteres --- }
  Inc(lex_pos);
  tok.kind := TK_PUNCT;
  tok.val  := c;
  { operateurs a deux caracteres }
  If lex_pos <= Length(lex_line) Then
  Begin
    If (c = '<') And (lex_line[lex_pos] = '<') Then
      Begin tok.val := '<<'; Inc(lex_pos); End
    Else If (c = '>') And (lex_line[lex_pos] = '>') Then
      Begin tok.val := '>>'; Inc(lex_pos); End
    Else If (c = '<') And (lex_line[lex_pos] = '>') Then
      Begin tok.val := '<>'; Inc(lex_pos); End
    Else If (c = '=') And (lex_line[lex_pos] = '=') Then
      Begin tok.val := '=='; Inc(lex_pos); End;
  End;
End;

{ ============================================================
  LexNext : avancer d un token (remplir lex_tok).
  Gere les transitions de ligne (TK_NEWLINE) et la fin
  de fichier (TK_EOF).
  ============================================================ }
Procedure LexNext;
Begin
  { consommer le peek s il existe }
  If lex_has_peek Then
  Begin
    lex_tok      := lex_peek_tok;
    lex_has_peek := False;
    Exit;
  End;

  { si on etait a la fin de la ligne logique precedente }
  If lex_at_eol Then
  Begin
    lex_at_eol := False;
    { charger la prochaine ligne logique }
    If Not SrcReadLine Then
    Begin
      lex_tok.kind     := TK_EOF;
      lex_tok.val      := '';
      lex_tok.num_val  := 0;
      lex_tok.line_num := cur_lineno;
      Exit;
    End;
    lex_line := cur_line;
    lex_pos  := 1;
    { retourner un NEWLINE comme separateur entre lignes }
    lex_tok.kind     := TK_NEWLINE;
    lex_tok.val      := '';
    lex_tok.num_val  := 0;
    lex_tok.line_num := cur_lineno;
    Exit;
  End;

  LexNextRaw(lex_tok);

  { si on vient d atteindre la fin de la ligne }
  If lex_tok.kind = TK_NEWLINE Then
    lex_at_eol := True;
End;

{ ============================================================
  LexEnsurePeek : remplir lex_peek_tok si pas encore fait
  ============================================================ }
Procedure LexEnsurePeek;
Var
  saved_tok : TToken;
Begin
  If lex_has_peek Then Exit;
  saved_tok    := lex_tok;
  LexNext;
  lex_peek_tok := lex_tok;
  lex_tok      := saved_tok;
  lex_has_peek := True;
End;

{ ============================================================
  LexPeekKind : type du prochain token (sans le consommer)
  ============================================================ }
Function LexPeekKind : TTokenKind;
Begin
  LexEnsurePeek;
  LexPeekKind := lex_peek_tok.kind;
End;

{ ============================================================
  LexPeekVal : valeur textuelle du prochain token
  ============================================================ }
Function LexPeekVal : TString;
Begin
  LexEnsurePeek;
  LexPeekVal := lex_peek_tok.val;
End;

{ ============================================================
  LexIsDirective : True si s est une directive MASM connue
  ============================================================ }
Function LexIsDirective(Const s : TString) : Boolean;
Begin
  LexIsDirective :=
    (s = 'ASSUME')    Or (s = 'ALIGN')     Or (s = 'BYTE')     Or
    (s = 'CODE')      Or (s = 'COMM')      Or (s = 'COMMENT')  Or
    (s = 'CONST')     Or (s = 'DATA')      Or (s = 'DB')       Or
    (s = 'DD')        Or (s = 'DF')        Or (s = 'DQ')       Or
    (s = 'DT')        Or (s = 'DW')        Or (s = 'DWORD')    Or
    (s = 'ELSE')      Or (s = 'ELSEIF')    Or (s = 'END')      Or
    (s = 'ENDIF')     Or (s = 'ENDM')      Or (s = 'ENDP')     Or
    (s = 'ENDS')      Or (s = 'EQU')       Or (s = 'EVEN')     Or
    (s = 'EXITM')     Or (s = 'EXTERN')    Or (s = 'EXTRN')    Or
    (s = 'FAR')       Or (s = 'FWORD')     Or (s = 'GLOBAL')   Or
    (s = 'GROUP')     Or (s = 'IF')        Or (s = 'IF1')      Or
    (s = 'IF2')       Or (s = 'IFB')       Or (s = 'IFDEF')    Or
    (s = 'IFDIF')     Or (s = 'IFIDNI')    Or (s = 'IFIDN')    Or
    (s = 'IFNB')      Or (s = 'IFNDEF')    Or (s = 'IFE')      Or
    (s = 'INCLUDE')   Or (s = 'INCLUDELIB')Or (s = 'IRP')      Or
    (s = 'IRPC')      Or (s = 'LABEL')     Or (s = 'LENGTH')   Or
    (s = 'LOCAL')     Or (s = 'MACRO')     Or (s = 'MOD')      Or
    (s = 'MODEL')     Or (s = 'NAME')      Or (s = 'NEAR')     Or
    (s = 'NOT')       Or (s = 'OFFSET')    Or (s = 'OPTION')   Or
    (s = 'ORG')       Or (s = 'PAGE')      Or (s = 'PARA')     Or
    (s = 'PROC')      Or (s = 'PTR')       Or (s = 'PUBLIC')   Or
    (s = 'PURGE')     Or (s = 'QWORD')     Or (s = 'RECORD')   Or
    (s = 'REPT')      Or (s = 'SBYTE')     Or (s = 'SEG')      Or
    (s = 'SEGMENT')   Or (s = 'SHORT')     Or (s = 'SIZE')     Or
    (s = 'SIZEOF')    Or (s = 'SIZESTR')   Or (s = 'STACK')    Or
    (s = 'STRUC')     Or (s = 'STRUCT')    Or (s = 'SUBTTL')   Or
    (s = 'TBYTE')     Or (s = 'TEXTEQU')   Or (s = 'TITLE')    Or
    (s = 'TYPE')      Or (s = 'TYPEDEF')   Or (s = 'UNION')    Or
    (s = 'USES')      Or (s = 'WORD')      Or (s = '.CODE')    Or
    (s = '.DATA')     Or (s = '.MODEL')    Or (s = '.STACK')   Or
    (s = '.CONST')    Or (s = '.STARTUP')  Or (s = '.EXIT')    Or
    (s = '.LIST')     Or (s = '.NOLIST')   Or (s = '.XLIST')   Or
    (s = '.LISTALL')  Or (s = '.RADIX')    Or (s = '.286')     Or
    (s = '.286P')     Or (s = '.186')      Or (s = '.8086')    Or
    (s = '.ERR')      Or (s = '.ERRNZ')    Or (s = '.ERRE')    Or
    (s = 'AND')       Or (s = 'OR')        Or (s = 'XOR')      Or
    (s = 'SHL')       Or (s = 'SHR')       Or (s = 'HIGH')     Or
    (s = 'LOW')       Or (s = 'THIS')      Or (s = 'WIDTH')    Or
    (s = 'MASK')      Or (s = 'INVOKE')    Or (s = 'PROTO');
End;

{ ============================================================
  LexIsRegister : True si s est un nom de registre 8086
  ============================================================ }
Function LexIsRegister(Const s : TString) : Boolean;
Begin
  LexIsRegister :=
    { registres 16 bits }
    (s = 'AX') Or (s = 'BX') Or (s = 'CX') Or (s = 'DX') Or
    (s = 'SI') Or (s = 'DI') Or (s = 'SP') Or (s = 'BP') Or
    { registres 8 bits }
    (s = 'AL') Or (s = 'AH') Or (s = 'BL') Or (s = 'BH') Or
    (s = 'CL') Or (s = 'CH') Or (s = 'DL') Or (s = 'DH') Or
    { registres de segment }
    (s = 'CS') Or (s = 'DS') Or (s = 'ES') Or (s = 'SS') Or
    { registres speciaux / 80386+ }
    (s = 'IP') Or (s = 'FLAGS') Or (s = 'ST');
End;

{ ============================================================
  TODO 04 - TABLE DES SYMBOLES - IMPLEMENTE
  ============================================================

  Organisation : hash table HASH_SIZE buckets de listes chainees.
  Chaque noeud est un PSymbol alloue sur le tas (New).
  "Index" = pointeur PSymbol (Nil = non trouve).

  Symboles predefinis inseres par SymInit :
    TRUE (-1), FALSE (0), @WORDSIZE (2), @MODEL (0=non defini),
    @CURSEG (0), @DATA (0), @CODE (0), @STACK (0), @FILENAME.

  Flags dans TSymbol.flags :
    bit 0 = is_public   (declare PUBLIC)
    bit 1 = is_extern   (declare EXTRN)
    bit 2 = is_defined  (valeur connue)
    bit 3 = is_redefin  (EQU redefinissable via =)
  ============================================================ }

{ ============================================================
  SymFind : chercher un symbole par nom (uppercase).
  Retourne un PSymbol ou Nil si absent.
  ============================================================ }
Function SymFind(Const name : TSymString) : PSymbol;
Var
  h : Integer;
  p : PSymbol;
Begin
  h := HashName(name);
  p := hash_table[h];
  While p <> Nil Do
  Begin
    If p^.name = name Then
    Begin
      SymFind := p;
      Exit;
    End;
    p := p^.next;
  End;
  SymFind := Nil;
End;

{ ============================================================
  SymEnter : ajouter un nouveau symbole (sans verifier doublon).
  Retourne le PSymbol cree.
  Pour les doublons, appeler SymFind d abord.
  ============================================================ }
Function SymEnter(Const name : TSymString;
                  kind    : TSymKind;
                  seg_idx : Integer;
                  offset  : TWord;
                  size    : TWord) : PSymbol;
Var
  h : Integer;
  p : PSymbol;
Begin
  New(p);
  p^.name    := name;
  p^.kind    := kind;
  p^.seg_idx := seg_idx;
  p^.offset  := offset;
  p^.value   := 0;
  p^.size    := size;
  p^.flags   := 4; { bit 2 = is_defined par defaut }
  { inserer en tete de la chaine de hachage }
  h          := HashName(name);
  p^.next    := hash_table[h];
  hash_table[h] := p;
  Inc(sym_count);
  SymEnter := p;
End;

{ ============================================================
  SymSetValue : fixer la valeur absolue d un symbole
  ============================================================ }
Procedure SymSetValue(p : PSymbol; val : TLong);
Begin
  If p = Nil Then Exit;
  p^.value  := val;
  p^.offset := TWord(val And $FFFF);
  p^.flags  := p^.flags Or 4; { marquer is_defined }
End;

{ ============================================================
  SymSetPublic : marquer un symbole comme PUBLIC
  ============================================================ }
Procedure SymSetPublic(p : PSymbol);
Begin
  If p = Nil Then Exit;
  p^.flags := p^.flags Or 1;
  p^.kind  := SK_PUBLIC;
End;

{ ============================================================
  SymSetExtern : marquer un symbole comme EXTRN
  ============================================================ }
Procedure SymSetExtern(p : PSymbol);
Begin
  If p = Nil Then Exit;
  p^.flags := p^.flags Or 2;
  p^.kind  := SK_EXTERN;
End;

{ ============================================================
  SymLookupOrEnter : retourner le symbole existant ou en creer
  un nouveau de kind SK_UNDEF (reference avant).
  ============================================================ }
Function SymLookupOrEnter(Const name : TSymString) : PSymbol;
Var
  p : PSymbol;
Begin
  p := SymFind(name);
  If p = Nil Then
  Begin
    p := SymEnter(name, SK_UNDEF, 0, 0, 0);
    p^.flags := 0; { SK_UNDEF : pas encore defini }
  End;
  SymLookupOrEnter := p;
End;

{ ============================================================
  SymDefineLabel : definir un label a la position courante.
  En passe 1 : creer ou mettre a jour.
  En passe 2 : verifier coherence (phase error si offset change).
  ============================================================ }
Procedure SymDefineLabel(Const name : TSymString; seg_i : Integer;
                         off : TWord; sz : TWord);
Var
  p : PSymbol;
Begin
  p := SymFind(name);
  If p = Nil Then
  Begin
    p := SymEnter(name, SK_LABEL, seg_i, off, sz);
  End
  Else
  Begin
    If (p^.kind <> SK_UNDEF) And (p^.kind <> SK_LABEL) Then
    Begin
      ErrorMsg('Redefinition de symbole : ' + name);
      Exit;
    End;
    If (pass_num = 2) And (p^.offset <> off) Then
      WarnMsg('Erreur de phase pour : ' + name);
    p^.kind    := SK_LABEL;
    p^.seg_idx := seg_i;
    p^.offset  := off;
    p^.size    := sz;
    p^.flags   := p^.flags Or 4;
  End;
End;

{ ============================================================
  SymCheckUndefined : en passe 2, signaler les SK_UNDEF restants
  ============================================================ }
Procedure SymCheckUndefined;
Var
  i : Integer;
  p : PSymbol;
Begin
  For i := 0 To HASH_SIZE-1 Do
  Begin
    p := hash_table[i];
    While p <> Nil Do
    Begin
      If p^.kind = SK_UNDEF Then
        ErrorMsg('Symbole non defini : ' + p^.name);
      p := p^.next;
    End;
  End;
End;

{ ============================================================
  SymAddPredef : ajouter un symbole predefini (EQU absolu)
  ============================================================ }
Procedure SymAddPredef(Const name : TSymString; val : TLong);
Var
  p : PSymbol;
Begin
  p := SymEnter(name, SK_EQU, 0, 0, 2);
  SymSetValue(p, val);
  p^.flags := p^.flags And Not 8; { non redefinissable }
End;

{ ============================================================
  SymInit : inserer les symboles predefinis MASM
  ============================================================ }
Procedure SymInit;
Var
  p : PSymbol;
Begin
  { constantes booleennes MASM }
  SymAddPredef('TRUE',      -1);
  SymAddPredef('FALSE',      0);
  { informations de modele (mises a jour par .MODEL) }
  SymAddPredef('@MODEL',     0); { 0 = non encore fixe }
  SymAddPredef('@WORDSIZE',  2); { 16-bit par defaut }
  { bases de segments (mises a jour lors de la definition des segments) }
  SymAddPredef('@DATA',      0);
  SymAddPredef('@CODE',      0);
  SymAddPredef('@STACK',     0);
  { symbole de segment courant (mis a jour dynamiquement) }
  p := SymEnter('@CURSEG', SK_EQU, 0, 0, 0);
  p^.value := 0;
  { nom du fichier source : sera mis a jour apres ParseArgs }
  p := SymEnter('@FILENAME', SK_EQU, 0, 0, 0);
  p^.value := 0;
  { @VERSION : numero de version de l assembleur }
  SymAddPredef('@VERSION', 100); { 1.00 encode en entier }
End;

{ ============================================================
  SymDump : afficher la table des symboles (debug / listing)
  ============================================================ }
Procedure SymDump;
Var
  i   : Integer;
  p   : PSymbol;
  kn  : TString;
Begin
  Writeln('--- Table des symboles (', sym_count, ' entrees) ---');
  For i := 0 To HASH_SIZE-1 Do
  Begin
    p := hash_table[i];
    While p <> Nil Do
    Begin
      Case p^.kind Of
        SK_UNDEF  : kn := 'UNDEF ';
        SK_LABEL  : kn := 'LABEL ';
        SK_PUBLIC : kn := 'PUBLIC';
        SK_EXTERN : kn := 'EXTERN';
        SK_EQU    : kn := 'EQU   ';
        SK_GROUP  : kn := 'GROUP ';
        SK_SEG    : kn := 'SEG   ';
        SK_MACRO  : kn := 'MACRO ';
        SK_STRUCT : kn := 'STRUCT';
        Else        kn := '???   ';
      End;
      Writeln('  ', kn, '  seg=', p^.seg_idx:2,
              '  off=', p^.offset:5,
              '  val=', p^.value:8,
              '  ', p^.name);
      p := p^.next;
    End;
  End;
End;

{ ============================================================
  TODO 05 - FORMAT .OBJ INTEL OMF (RECORDS DE BASE) - IMPLEMENTE
  ============================================================

  Structure d un record OMF :
    Octet 0   : type du record (ex : 80h = THEADR)
    Octets 1-2: longueur du reste (data + checksum), little-endian
    Octets 3..: donnees
    Dernier   : checksum = 256 - (sum de tous les octets) mod 256

  On construit chaque record dans obj_rec_buf puis on
  l ecrit dans obj_f via ObjEndRecord.

  Table LNAMES : noms de segments/groupes accumules avant
  ecriture du bloc LNAMES, index 1-base.
  ============================================================ }

{ ---- Constantes des types de records OMF ---- }
Const
  OMF_THEADR  = $80; { nom du module source }
  OMF_COMENT  = $88; { commentaire }
  OMF_MODEND  = $8A; { fin du module }
  OMF_EXTDEF  = $8C; { symboles externes }
  OMF_PUBDEF  = $90; { symboles publics }
  OMF_LNAMES  = $96; { liste de noms (segments/groupes) }
  OMF_SEGDEF  = $98; { definition de segment }
  OMF_GRPDEF  = $9A; { definition de groupe }
  OMF_FIXUPP  = $9C; { corrections d adresse }
  OMF_LEDATA  = $A0; { donnees locales }
  OMF_LIDATA  = $A2; { donnees iterees (blocs repetes) }
  OMF_COMDEF  = $B0; { variables communes }

  OBJ_REC_MAX = 1024; { taille max des donnees d un record }
  LNAMES_MAX  = 128;  { max de noms dans la table LNAMES }

{ ---- Variables OBJ ---- }
Var
  obj_f        : File;          { fichier .OBJ en sortie }
  obj_is_open  : Boolean;       { True si obj_f est ouvert }
  obj_rec_buf  : Array[0..OBJ_REC_MAX-1] Of Byte; { buffer record courant }
  obj_rec_type : Byte;          { type du record en cours }
  obj_rec_pos  : Integer;       { position courante dans obj_rec_buf }

  { Table LNAMES - noms de segments et de groupes }
  lnames_table : Array[1..LNAMES_MAX] Of TSymString;
  lnames_count : Integer; { nombre de noms enregistres (index 1-base) }

{ ============================================================
  ObjWriteByte : ecrire un octet directement dans obj_f
  ============================================================ }
Procedure ObjWriteByte(b : Byte);
Begin
  If Not obj_is_open Then Exit;
  BlockWrite(obj_f, b, 1);
End;

{ ============================================================
  ObjBeginRecord : commencer un nouveau record OMF
  ============================================================ }
Procedure ObjBeginRecord(rtype : Byte);
Begin
  obj_rec_type := rtype;
  obj_rec_pos  := 0;
End;

{ ============================================================
  ObjPutByte : ajouter un octet au buffer du record courant
  ============================================================ }
Procedure ObjPutByte(b : Byte);
Begin
  If obj_rec_pos < OBJ_REC_MAX Then
  Begin
    obj_rec_buf[obj_rec_pos] := b;
    Inc(obj_rec_pos);
  End
  Else
    ErrorMsg('Record OMF trop grand (max 1024 octets de donnees)');
End;

{ ============================================================
  ObjPutWord : ajouter un mot 16 bits (little-endian)
  ============================================================ }
Procedure ObjPutWord(w : TWord);
Begin
  ObjPutByte(Byte(w And $FF));
  ObjPutByte(Byte((w Shr 8) And $FF));
End;

{ ============================================================
  ObjPutDWord : ajouter un double-mot 32 bits (little-endian)
  ============================================================ }
Procedure ObjPutDWord(d : TLong);
Begin
  ObjPutByte(Byte(d And $FF));
  ObjPutByte(Byte((d Shr 8) And $FF));
  ObjPutByte(Byte((d Shr 16) And $FF));
  ObjPutByte(Byte((d Shr 24) And $FF));
End;

{ ============================================================
  ObjPutStr : ajouter une chaine pascal (longueur + octets)
  ============================================================ }
Procedure ObjPutStr(Const s : TString);
Var
  i : Integer;
Begin
  ObjPutByte(Length(s));
  For i := 1 To Length(s) Do
    ObjPutByte(Ord(s[i]));
End;

{ ============================================================
  ObjPutIndex : encoder un index OMF (1 ou 2 octets)
    index < 128  -> 1 octet
    index >= 128 -> 2 octets (bit 7 du premier = 1)
  ============================================================ }
Procedure ObjPutIndex(idx : Integer);
Begin
  If idx < 128 Then
    ObjPutByte(Byte(idx))
  Else
  Begin
    ObjPutByte(Byte($80 Or ((idx Shr 8) And $7F)));
    ObjPutByte(Byte(idx And $FF));
  End;
End;

{ ============================================================
  ObjEndRecord : finaliser et ecrire le record dans obj_f
  Calcule la longueur et le checksum, puis ecrit tout.
  ============================================================ }
Procedure ObjEndRecord;
Var
  len    : Integer; { longueur des donnees + 1 (checksum) }
  sum    : Integer;
  i      : Integer;
  lo, hi : Byte;
  cksum  : Byte;
Begin
  If Not obj_is_open Then Exit;
  len := obj_rec_pos + 1; { +1 pour l octet de checksum }
  lo  := Byte(len And $FF);
  hi  := Byte((len Shr 8) And $FF);
  { calcul du checksum : somme de tous les octets du record }
  sum := obj_rec_type + lo + hi;
  For i := 0 To obj_rec_pos - 1 Do
    sum := sum + obj_rec_buf[i];
  cksum := Byte((256 - (sum And $FF)) And $FF);
  { ecriture : type + longueur + donnees + checksum }
  ObjWriteByte(obj_rec_type);
  ObjWriteByte(lo);
  ObjWriteByte(hi);
  For i := 0 To obj_rec_pos - 1 Do
    ObjWriteByte(obj_rec_buf[i]);
  ObjWriteByte(cksum);
End;

{ ============================================================
  ObjOpen : ouvrir le fichier .OBJ en sortie
  ============================================================ }
Procedure ObjOpen(Const fname : TString);
Begin
  Assign(obj_f, fname);
  {$I-}
  Rewrite(obj_f, 1);
  {$I+}
  If IoResult <> 0 Then
  Begin
    ErrorMsg('Impossible de creer le fichier OBJ : ' + fname);
    obj_is_open := False;
    Exit;
  End;
  obj_is_open := True;
  lnames_count := 0;
End;

{ ============================================================
  ObjClose : fermer le fichier .OBJ
  ============================================================ }
Procedure ObjClose;
Begin
  If obj_is_open Then
  Begin
    Close(obj_f);
    obj_is_open := False;
  End;
End;

{ ============================================================
  ObjInit : initialiser les variables OBJ
  ============================================================ }
Procedure ObjInit;
Begin
  obj_is_open  := False;
  obj_rec_type := 0;
  obj_rec_pos  := 0;
  lnames_count := 0;
End;

{ --- Records OMF de haut niveau --- }

{ ============================================================
  ObjTHEADR : ecrire le record THEADR (nom de module)
  ============================================================ }
Procedure ObjTHEADR(Const module_name : TString);
Begin
  ObjBeginRecord(OMF_THEADR);
  ObjPutStr(module_name);
  ObjEndRecord;
End;

{ ============================================================
  ObjCOMENT : ecrire un record COMENT
    attr      : attribut (80h = non-listable non-purgeable)
    com_class : classe de commentaire (0 = texte general)
    text      : texte du commentaire
  ============================================================ }
Procedure ObjCOMENT(attr : Byte; com_class : Byte; Const text : TString);
Var
  i : Integer;
Begin
  ObjBeginRecord(OMF_COMENT);
  ObjPutByte(attr);
  ObjPutByte(com_class);
  For i := 1 To Length(text) Do
    ObjPutByte(Ord(text[i]));
  ObjEndRecord;
End;

{ ============================================================
  ObjMODEND : ecrire le record MODEND
    is_main   : True si ce module contient le point d entree
    seg_idx   : index SEGDEF du segment de depart (0 si aucun)
    start_off : offset du point d entree dans le segment
  ============================================================ }
Procedure ObjMODEND(is_main : Boolean; seg_idx : Integer; start_off : TWord);
Begin
  ObjBeginRecord(OMF_MODEND);
  If is_main And (seg_idx > 0) Then
  Begin
    ObjPutByte($C1);          { bit 7 = main module, bit 6 = entry present }
    ObjPutByte($00);          { FRAME: segment (00h) }
    ObjPutIndex(seg_idx);     { index SEGDEF cible }
    ObjPutByte($00);          { TARGET: segment (00h) }
    ObjPutIndex(seg_idx);
    ObjPutWord(start_off);
  End
  Else If is_main Then
  Begin
    ObjPutByte($80);          { main module, pas d entry explicite }
  End
  Else
  Begin
    ObjPutByte($00);          { module secondaire }
  End;
  ObjEndRecord;
End;

{ ============================================================
  LNamesRegister : enregistrer un nom dans la table LNAMES
  et retourner son index 1-base. Si deja present, retourner
  l index existant.
  ============================================================ }
Function LNamesRegister(Const name : TSymString) : Integer;
Var
  i : Integer;
Begin
  { chercher si deja enregistre }
  For i := 1 To lnames_count Do
    If lnames_table[i] = name Then
    Begin
      LNamesRegister := i;
      Exit;
    End;
  { ajouter }
  If lnames_count < LNAMES_MAX Then
  Begin
    Inc(lnames_count);
    lnames_table[lnames_count] := name;
    LNamesRegister := lnames_count;
  End
  Else
  Begin
    ErrorMsg('Table LNAMES pleine (max ' +
             Chr(Ord('0') + LNAMES_MAX Div 100) +
             Chr(Ord('0') + (LNAMES_MAX Div 10) Mod 10) +
             Chr(Ord('0') + LNAMES_MAX Mod 10) + ' noms)');
    LNamesRegister := 1;
  End;
End;

{ ============================================================
  ObjLNAMES : ecrire le record LNAMES avec tous les noms
  accumules dans lnames_table[1..lnames_count].
  Un seul record suffit en general pour les petits modules.
  ============================================================ }
Procedure ObjLNAMES;
Var
  i : Integer;
Begin
  If lnames_count = 0 Then Exit;
  ObjBeginRecord(OMF_LNAMES);
  For i := 1 To lnames_count Do
    ObjPutStr(lnames_table[i]);
  ObjEndRecord;
End;

{ ============================================================
  ObjSEGDEF : ecrire un record SEGDEF pour un segment.
    align_byte : 0=abs,1=byte,2=word,3=para,4=page,5=dword
    combine    : 0=private,2=public,5=stack,6=common
    seg_size   : taille en octets du segment
    seg_name_i : index LNAMES du nom de segment
    cls_name_i : index LNAMES de la classe
    ovl_name_i : index LNAMES du nom du groupe d overlay (0)
  ============================================================ }
Procedure ObjSEGDEF(align_byte : Byte; combine : Byte;
                    seg_size : TWord;
                    seg_name_i : Integer; cls_name_i : Integer;
                    ovl_name_i : Integer);
Var
  acbp : Byte;
Begin
  ObjBeginRecord(OMF_SEGDEF);
  { ACBP : A(3bits) C(3bits) B(1bit) P(1bit) }
  { A = alignment : 1=byte 2=word 3=para 4=page 5=dword }
  { C = combine   : 0=private 2=public 5=stack 6=common }
  { B = big (seg_size=0 means 64K) }
  { P = USE16 (0) / USE32 (1) }
  acbp := ((align_byte And $07) Shl 5) Or
          ((combine    And $07) Shl 2) Or
          $00; { B=0, P=0 = USE16 }
  ObjPutByte(acbp);
  ObjPutWord(seg_size);    { taille du segment }
  ObjPutIndex(seg_name_i); { nom du segment }
  ObjPutIndex(cls_name_i); { classe }
  ObjPutIndex(ovl_name_i); { overlay name (0 = none) }
  ObjEndRecord;
End;

{ ============================================================
  ObjGRPDEF : ecrire un record GRPDEF
    grp_name_i : index LNAMES du nom de groupe (ex: DGROUP)
    seg_indices: tableau d indices SEGDEF des membres
    seg_count  : nombre de membres
  ============================================================ }
Procedure ObjGRPDEF(grp_name_i : Integer;
                    Var seg_indices : Array Of Integer;
                    seg_cnt : Integer);
Var
  i : Integer;
Begin
  ObjBeginRecord(OMF_GRPDEF);
  ObjPutIndex(grp_name_i);
  For i := 0 To seg_cnt - 1 Do
  Begin
    ObjPutByte($FF);               { composant = segment }
    ObjPutIndex(seg_indices[i]);   { index SEGDEF }
  End;
  ObjEndRecord;
End;

{ ============================================================
  ObjEXTDEF : ecrire un record EXTDEF pour un symbole externe
    ext_name : nom du symbole externe
    type_idx : index de type (0 = non specifie)
  ============================================================ }
Procedure ObjEXTDEF(Const ext_name : TString; type_idx : Integer);
Begin
  ObjBeginRecord(OMF_EXTDEF);
  ObjPutStr(ext_name);
  ObjPutIndex(type_idx);
  ObjEndRecord;
End;

{ ============================================================
  ObjPUBDEF : ecrire un record PUBDEF pour un symbole public
    base_grp_i : index GRPDEF de base (0 si aucun)
    base_seg_i : index SEGDEF du segment contenant le symbole
    pub_name   : nom du symbole public
    pub_offset : offset dans le segment
    type_idx   : index de type (0 = non specifie)
  ============================================================ }
Procedure ObjPUBDEF(base_grp_i : Integer; base_seg_i : Integer;
                    Const pub_name : TString;
                    pub_offset : TWord; type_idx : Integer);
Begin
  ObjBeginRecord(OMF_PUBDEF);
  ObjPutIndex(base_grp_i); { groupe de base (0 si aucun) }
  ObjPutIndex(base_seg_i); { segment de base }
  If base_seg_i = 0 Then
    ObjPutWord(0);          { base frame (segment absolu seulement) }
  ObjPutStr(pub_name);
  ObjPutWord(pub_offset);
  ObjPutIndex(type_idx);
  ObjEndRecord;
End;

{ ============================================================
  TODO 06 - FORMAT .OBJ INTEL OMF (DONNEES ET FIXUPS) - IMPLEMENTE
  ============================================================

  Gestion du buffer LEDATA :
    - Chaque segment possede un buffer de donnees (max 1024 o.).
    - FlushLEDATA : ecrit le buffer courant sous forme de record
      LEDATA, puis vide le buffer. Appele automatiquement quand
      le buffer est plein ou en fin d assemblage.
    - EmitByte/EmitWord/EmitDWord : ajouter un octet/mot/dword
      au segment courant (avec flush automatique si necessaire).

  Gestion des fixups :
    - Table de fixups internes (tableau fixup_table).
    - Chaque fixup memorise : offset dans LEDATA, type, et
      l index du symbole cible (SEGDEF ou EXTDEF).
    - ObjFIXUPP : serialise la table en records FIXUPP OMF.
  ============================================================ }

{ ---- Types et constantes pour les fixups ---- }
Const
  FIXUP_OFFSET  = 0; { relocation 16-bit offset dans segment }
  FIXUP_SEG     = 1; { relocation 16-bit valeur de segment }
  FIXUP_SHORT   = 2; { relocation 8-bit deplacement court (Jcc) }
  FIXUP_FAR     = 3; { relocation 32-bit seg:off (FAR PTR) }

  FIXUP_TARGET_SEG = 0; { cible = index SEGDEF }
  FIXUP_TARGET_EXT = 1; { cible = index EXTDEF }
  FIXUP_TARGET_GRP = 2; { cible = index GRPDEF }

{ Buffer LEDATA par segment }
Const
  LEDATA_BUF_MAX = 1020; { max octets de donnees par record LEDATA }

Type
  TFixupRec = Record
    ledata_offset : TWord;    { offset de l octet a patcher dans le LEDATA }
    fix_type      : Byte;     { FIXUP_OFFSET / FIXUP_SEG / FIXUP_SHORT / FIXUP_FAR }
    target_kind   : Byte;     { FIXUP_TARGET_SEG / EXT / GRP }
    target_idx    : Integer;  { index SEGDEF, EXTDEF ou GRPDEF (1-base) }
    displacement  : TWord;    { deplacement ajoute a la cible }
    is_seg_rel    : Boolean;  { True = relatif au segment (SELFREL=0), False = non }
  End;

Var
  { Buffer LEDATA courant }
  ledata_buf     : Array[0..LEDATA_BUF_MAX-1] Of Byte;
  ledata_buf_len : Integer;    { nb d octets dans le buffer }
  ledata_seg_idx : Integer;    { index SEGDEF du segment courant dans le buffer }
  ledata_start   : TWord;      { offset de debut du buffer dans le segment }

  { Table de fixups internes }
  fixup_table    : Array[0..MAX_FIXUP-1] Of TFixupRec;
  fixup_count    : Integer;

{ ============================================================
  FixupInit : vider la table de fixups
  ============================================================ }
Procedure FixupInit;
Begin
  fixup_count    := 0;
  ledata_buf_len := 0;
  ledata_seg_idx := 0;
  ledata_start   := 0;
End;

{ ============================================================
  ObjFIXUPP : ecrire les fixups accumules dans fixup_table
  en un ou plusieurs records FIXUPP OMF.
  Format simplifie : un fixup explicite par entree.
  ============================================================ }
Procedure ObjFIXUPP;
Var
  i      : Integer;
  locat  : TWord;
  fixdat : Byte;
  fr     : TFixupRec;
Begin
  If fixup_count = 0 Then Exit;
  ObjBeginRecord(OMF_FIXUPP);
  For i := 0 To fixup_count - 1 Do
  Begin
    fr := fixup_table[i];
    { LOCAT word :
        bit 15     = 1 (c est un Fixup, pas un Thread)
        bit 14     = 1 si SEGREL, 0 si SELFREL
        bits 13-10 = Location type :
                       0=lobyte, 1=offset16, 2=base, 3=pointer32
                       4=offset8 (SHORT), 5=loffset16
        bits 9-0   = data record offset de l octet dans le LEDATA }
    locat := $8000; { bit 15 = fixup }
    If fr.is_seg_rel Then
      locat := locat Or $4000;
    Case fr.fix_type Of
      FIXUP_SHORT  : locat := locat Or ($0 Shl 10); { lobyte = 0 }
      FIXUP_OFFSET : locat := locat Or ($1 Shl 10); { offset16 = 1 }
      FIXUP_SEG    : locat := locat Or ($2 Shl 10); { base16 = 2 }
      FIXUP_FAR    : locat := locat Or ($3 Shl 10); { pointer32 = 3 }
    End;
    locat := locat Or (fr.ledata_offset And $03FF);
    ObjPutWord(locat);
    { FIXDAT :
        bits 7-4 = F T (frame/target thread + method)
        F=0, frame_method=0 (segment index), T=0, target_method=0 (SEGDEF)
        si T=1, target_method=2 (EXTDEF) }
    fixdat := $00;
    Case fr.target_kind Of
      FIXUP_TARGET_SEG : fixdat := $00;  { target = SEGDEF }
      FIXUP_TARGET_GRP : fixdat := $01;  { target = GRPDEF }
      FIXUP_TARGET_EXT : fixdat := $02;  { target = EXTDEF }
    End;
    If fr.displacement = 0 Then
      fixdat := fixdat Or $04; { bit 2 = P : pas de champ displacement }
    ObjPutByte(fixdat);
    ObjPutIndex(fr.target_idx);
    If fr.displacement <> 0 Then
      ObjPutWord(fr.displacement);
  End;
  ObjEndRecord;
  fixup_count := 0;
End;

{ ============================================================
  FlushLEDATA : ecrire le buffer LEDATA courant en un record
  OMF, puis les fixups associes, et remettre le buffer a zero.
  ============================================================ }
Procedure FlushLEDATA;
Var
  i : Integer;
Begin
  If (ledata_buf_len = 0) Or (Not obj_is_open) Then Exit;
  ObjBeginRecord(OMF_LEDATA);
  ObjPutIndex(ledata_seg_idx);
  ObjPutWord(ledata_start);
  For i := 0 To ledata_buf_len - 1 Do
    ObjPutByte(ledata_buf[i]);
  ObjEndRecord;
  { ecrire les fixups correspondant a ce bloc de donnees }
  ObjFIXUPP;
  { avancer le pointeur de debut }
  ledata_start   := ledata_start + TWord(ledata_buf_len);
  ledata_buf_len := 0;
End;

{ ============================================================
  EmitByte : emettre un octet dans le segment courant
  ============================================================ }
Procedure EmitByte(b : Byte);
Begin
  If ledata_buf_len >= LEDATA_BUF_MAX Then
    FlushLEDATA;
  ledata_buf[ledata_buf_len] := b;
  Inc(ledata_buf_len);
  { mettre a jour le LC global }
  Inc(lc);
  { mettre a jour la taille du segment courant }
  If (cur_seg >= 1) And (cur_seg <= MAX_SEG) Then
  Begin
    If seg_table[cur_seg].cur_lc > seg_table[cur_seg].size Then
      seg_table[cur_seg].size := seg_table[cur_seg].cur_lc;
    Inc(seg_table[cur_seg].cur_lc);
    If seg_table[cur_seg].cur_lc > seg_table[cur_seg].size Then
      seg_table[cur_seg].size := seg_table[cur_seg].cur_lc;
  End;
End;

{ ============================================================
  EmitWord : emettre un mot 16 bits (little-endian)
  ============================================================ }
Procedure EmitWord(w : TWord);
Begin
  EmitByte(Byte(w And $FF));
  EmitByte(Byte((w Shr 8) And $FF));
End;

{ ============================================================
  EmitDWord : emettre un double-mot 32 bits (little-endian)
  ============================================================ }
Procedure EmitDWord(d : TLong);
Begin
  EmitByte(Byte(d And $FF));
  EmitByte(Byte((d Shr 8) And $FF));
  EmitByte(Byte((d Shr 16) And $FF));
  EmitByte(Byte((d Shr 24) And $FF));
End;

{ ============================================================
  EmitZeros : emettre n octets nuls (BSS, DUP(0))
  ============================================================ }
Procedure EmitZeros(n : Integer);
Var
  i : Integer;
Begin
  For i := 1 To n Do
    EmitByte(0);
End;

{ ============================================================
  GenFixup : enregistrer un fixup dans fixup_table.
    fix_type    : FIXUP_OFFSET / FIXUP_SEG / FIXUP_SHORT / FIXUP_FAR
    target_kind : FIXUP_TARGET_SEG / EXT / GRP
    target_idx  : index 1-base de la cible
    disp        : deplacement additionnel
    seg_rel     : True = correction par rapport au segment courant
  ============================================================ }
Procedure GenFixup(fix_type : Byte; target_kind : Byte;
                   target_idx : Integer; disp : TWord;
                   seg_rel : Boolean);
Var
  fr : TFixupRec;
Begin
  If fixup_count >= MAX_FIXUP Then
  Begin
    ErrorMsg('Table de fixups interne pleine - FlushLEDATA avant GenFixup');
    Exit;
  End;
  { l offset dans le LEDATA est la position courante du buffer }
  fr.ledata_offset := TWord(ledata_buf_len);
  fr.fix_type      := fix_type;
  fr.target_kind   := target_kind;
  fr.target_idx    := target_idx;
  fr.displacement  := disp;
  fr.is_seg_rel    := seg_rel;
  fixup_table[fixup_count] := fr;
  Inc(fixup_count);
End;

{ ============================================================
  ObjLIDATA : emettre un record LIDATA (donnees repetees)
  Utile pour : label DB n DUP(val)
    seg_i   : index SEGDEF
    offset  : offset de debut dans le segment
    repeat_count : nombre de repetitions
    data    : octets a repeter
    data_len: longueur du bloc de base
  ============================================================ }
Procedure ObjLIDATA(seg_i : Integer; off : TWord;
                    repeat_count : TWord;
                    Var data : Array Of Byte; data_len : Integer);
Var
  i : Integer;
Begin
  { s assurer que le buffer LEDATA precedent est vide }
  FlushLEDATA;
  ObjBeginRecord(OMF_LIDATA);
  ObjPutIndex(seg_i);
  ObjPutWord(off);
  { bloc LIDATA : repeat_count + block_count(=0) + literal }
  ObjPutWord(repeat_count);
  ObjPutWord(0);          { block_count = 0 : c est un literal }
  ObjPutByte(Byte(data_len)); { taille du literal }
  For i := 0 To data_len - 1 Do
    ObjPutByte(data[i]);
  ObjEndRecord;
End;

{ ============================================================
  SetSeg : changer le segment courant (flush LEDATA en cours)
  ============================================================ }
Procedure SetSeg(new_seg : Integer);
Begin
  If new_seg = cur_seg Then Exit;
  { sauvegarder le LEDATA du segment precedent }
  FlushLEDATA;
  cur_seg        := new_seg;
  ledata_seg_idx := new_seg;
  If (new_seg >= 1) And (new_seg <= MAX_SEG) Then
  Begin
    lc             := seg_table[new_seg].cur_lc;
    ledata_start   := lc;
  End
  Else
  Begin
    lc           := 0;
    ledata_start := 0;
  End;
  ledata_buf_len := 0;
End;

{ ============================================================
  TODO 07 - GESTION DES SEGMENTS ET DES MODELES MEMOIRE - IMPLEMENTE
  ============================================================

  Modeles memoire supportes (directive .MODEL) :
    TINY    : CS=DS=SS, tout dans un segment, .COM target
    SMALL   : CS=_TEXT, DS=SS=DGROUP (_DATA+_BSS)
    COMPACT : CS=_TEXT, DS multiples, SS=DGROUP
    MEDIUM  : CS multiples, DS=SS=DGROUP
    LARGE   : CS et DS multiples
    HUGE    : idem LARGE + tableaux > 64K

  Segments standards crees automatiquement :
    _TEXT  : code  (align WORD,  combine PUBLIC, classe 'CODE')
    _DATA  : data  (align WORD,  combine PUBLIC, classe 'DATA')
    _BSS   : bss   (align WORD,  combine PUBLIC, classe 'BSS')
    STACK  : pile  (align PARA,  combine STACK,  classe 'STACK')
    CONST  : cst   (align WORD,  combine PUBLIC, classe 'CONST')
    DGROUP : groupe = _DATA + _BSS + CONST + STACK
  ============================================================ }

{ ---- Variables du modele memoire ---- }
Var
  mem_model   : Integer;  { 0=none,1=TINY,2=SMALL,3=COMPACT,4=MEDIUM,5=LARGE,6=HUGE }
  model_name  : TString;  { nom textuel du modele }
  call_far    : Boolean;  { True si CALL FAR par defaut (MEDIUM/LARGE/HUGE) }
  data_far    : Boolean;  { True si DATA FAR par defaut (COMPACT/LARGE/HUGE) }

  { Indices des segments standards dans seg_table (0 = non defini) }
  seg_idx_text  : Integer;
  seg_idx_data  : Integer;
  seg_idx_bss   : Integer;
  seg_idx_stack : Integer;
  seg_idx_const : Integer;
  grp_idx_dgroup: Integer; { index dans grp_table du groupe DGROUP }

  { ASSUME : association registre/segment (index seg_table, 0=NOTHING) }
  assume_cs : Integer;
  assume_ds : Integer;
  assume_ss : Integer;
  assume_es : Integer;

  { Pile SEGMENT/ENDS ouverts }
  seg_open_stack : Array[0..8] Of Integer; { indices seg_table }
  seg_open_top   : Integer;  { -1 = aucun }

{ ============================================================
  SegFind : chercher un segment par nom. Retourne l index (1-base)
  dans seg_table ou 0 si non trouve.
  ============================================================ }
Function SegFind(Const name : TSymString) : Integer;
Var
  i : Integer;
Begin
  For i := 1 To seg_count Do
    If seg_table[i].name = name Then
    Begin
      SegFind := i;
      Exit;
    End;
  SegFind := 0;
End;

{ ============================================================
  SegEnter : definir un nouveau segment. Retourne l index 1-base.
  Si le segment existe deja, retourner son index sans creer.
  ============================================================ }
Function SegEnter(Const sname : TSymString; Const scls : TSymString;
                  comb : TSegCombine; aln : TSegAlign) : Integer;
Var
  idx  : Integer;
  p    : PSymbol;
  uname : TSymString;
Begin
  uname := LexUpperCase(sname);
  idx := SegFind(uname);
  If idx > 0 Then
  Begin
    SegEnter := idx;
    Exit;
  End;
  If seg_count >= MAX_SEG Then
  Begin
    ErrorMsg('Trop de segments');
    SegEnter := 1;
    Exit;
  End;
  Inc(seg_count);
  seg_table[seg_count].name       := uname;
  seg_table[seg_count].class_name := LexUpperCase(scls);
  seg_table[seg_count].combine    := comb;
  seg_table[seg_count].align      := aln;
  seg_table[seg_count].size       := 0;
  seg_table[seg_count].cur_lc     := 0;
  seg_table[seg_count].defined    := True;
  seg_table[seg_count].lnames_idx := LNamesRegister(uname);
  If scls <> '' Then
    LNamesRegister(LexUpperCase(scls));
  { creer un symbole de type SK_SEG dans la table des symboles }
  p := SymFind(uname);
  If p = Nil Then
  Begin
    p := SymEnter(uname, SK_SEG, seg_count, 0, 0);
    SymSetValue(p, 0);
  End;
  SegEnter := seg_count;
End;

{ ============================================================
  GrpEnter : definir ou trouver un groupe. Retourne l index (1-base).
  ============================================================ }
Function GrpEnter(Const name : TSymString) : Integer;
Var
  i   : Integer;
  p   : PSymbol;
Begin
  For i := 1 To grp_count Do
    If grp_table[i].name = name Then
    Begin
      GrpEnter := i;
      Exit;
    End;
  If grp_count >= MAX_GRP Then
  Begin
    ErrorMsg('Trop de groupes (max ' +
             Chr(Ord('0') + MAX_GRP) + ')');
    GrpEnter := 1;
    Exit;
  End;
  Inc(grp_count);
  With grp_table[grp_count] Do
  Begin
    name      := name;
    seg_count := 0;
    defined   := True;
  End;
  LNamesRegister(name);
  p := SymFind(name);
  If p = Nil Then
  Begin
    p := SymEnter(name, SK_GROUP, 0, 0, 0);
    SymSetValue(p, 0);
  End;
  GrpEnter := grp_count;
End;

{ ============================================================
  GrpAddSeg : ajouter un segment a un groupe
  ============================================================ }
Procedure GrpAddSeg(grp_i : Integer; seg_i : Integer);
Var
  j : Integer;
Begin
  If (grp_i < 1) Or (grp_i > grp_count) Then Exit;
  With grp_table[grp_i] Do
  Begin
    { verifier si deja present }
    For j := 1 To seg_count Do
      If segs[j] = seg_i Then Exit;
    If seg_count < MAX_SEG Then
    Begin
      Inc(seg_count);
      segs[seg_count] := seg_i;
    End;
  End;
End;

{ ============================================================
  ModelInit : initialiser les variables de modele
  ============================================================ }
Procedure ModelInit;
Begin
  mem_model      := 0;
  model_name     := '';
  call_far       := False;
  data_far       := False;
  seg_idx_text   := 0;
  seg_idx_data   := 0;
  seg_idx_bss    := 0;
  seg_idx_stack  := 0;
  seg_idx_const  := 0;
  grp_idx_dgroup := 0;
  assume_cs      := 0;
  assume_ds      := 0;
  assume_ss      := 0;
  assume_es      := 0;
  seg_open_top   := -1;
End;

{ ============================================================
  ParseModel : traiter la directive .MODEL nom
  Cree les segments standards et le groupe DGROUP.
  ============================================================ }
Procedure ParseModel(Const mname : TString);
Begin
  model_name := LexUpperCase(mname);
  call_far   := False;
  data_far   := False;
  If model_name = 'TINY'    Then mem_model := 1
  Else If model_name = 'SMALL'   Then mem_model := 2
  Else If model_name = 'COMPACT' Then Begin mem_model := 3; data_far := True; End
  Else If model_name = 'MEDIUM'  Then Begin mem_model := 4; call_far := True; End
  Else If model_name = 'LARGE'   Then Begin mem_model := 5; call_far := True; data_far := True; End
  Else If model_name = 'HUGE'    Then Begin mem_model := 6; call_far := True; data_far := True; End
  Else
  Begin
    ErrorMsg('Modele memoire inconnu : ' + mname);
    mem_model := 2; { defaut SMALL }
  End;

  { creer les segments standards }
  seg_idx_text  := SegEnter('_TEXT',  'CODE',  SC_PUBLIC, SA_WORD);
  seg_idx_data  := SegEnter('_DATA',  'DATA',  SC_PUBLIC, SA_WORD);
  seg_idx_bss   := SegEnter('_BSS',   'BSS',   SC_PUBLIC, SA_WORD);
  seg_idx_const := SegEnter('CONST',  'CONST', SC_PUBLIC, SA_WORD);
  seg_idx_stack := SegEnter('STACK',  'STACK', SC_STACK,  SA_PARA);
  { taille par defaut de la pile : 512 octets }
  seg_table[seg_idx_stack].size := 512;

  { creer le groupe DGROUP }
  grp_idx_dgroup := GrpEnter('DGROUP');
  GrpAddSeg(grp_idx_dgroup, seg_idx_data);
  GrpAddSeg(grp_idx_dgroup, seg_idx_bss);
  GrpAddSeg(grp_idx_dgroup, seg_idx_const);
  GrpAddSeg(grp_idx_dgroup, seg_idx_stack);

  { ASSUME par defaut }
  assume_cs := seg_idx_text;
  assume_ds := grp_idx_dgroup; { DS -> DGROUP }
  assume_ss := grp_idx_dgroup;
  assume_es := 0;

  { mettre a jour le symbole @MODEL }
  SymSetValue(SymFind('@MODEL'), mem_model);
  Writeln('.MODEL ', model_name, ' : segments crees.');
End;

{ ============================================================
  ParseDotCode : .CODE [nom]
  ============================================================ }
Procedure ParseDotCode(Const seg_name : TString);
Var
  sn  : TString;
  idx : Integer;
Begin
  If seg_name = '' Then sn := '_TEXT'
  Else sn := LexUpperCase(seg_name);
  idx := SegFind(sn);
  If idx = 0 Then
    idx := SegEnter(sn, 'CODE', SC_PUBLIC, SA_WORD);
  SetSeg(idx);
  assume_cs := idx;
  { mettre a jour @CURSEG }
  SymSetValue(SymFind('@CURSEG'), idx);
End;

{ ============================================================
  ParseDotData : .DATA / .DATA? / .CONST
  ============================================================ }
Procedure ParseDotData(Const kind : TString);
Var
  idx : Integer;
Begin
  If kind = '.CONST' Then
  Begin
    idx := seg_idx_const;
    If idx = 0 Then idx := SegEnter('CONST', 'CONST', SC_PUBLIC, SA_WORD);
  End
  Else If kind = '.DATA?' Then
  Begin
    idx := seg_idx_bss;
    If idx = 0 Then idx := SegEnter('_BSS', 'BSS', SC_PUBLIC, SA_WORD);
  End
  Else
  Begin
    idx := seg_idx_data;
    If idx = 0 Then idx := SegEnter('_DATA', 'DATA', SC_PUBLIC, SA_WORD);
  End;
  SetSeg(idx);
  SymSetValue(SymFind('@CURSEG'), idx);
End;

{ ============================================================
  ParseDotStack : .STACK [taille]
  ============================================================ }
Procedure ParseDotStack(size : TWord);
Begin
  If seg_idx_stack = 0 Then
    seg_idx_stack := SegEnter('STACK', 'STACK', SC_STACK, SA_PARA);
  If size > 0 Then
    seg_table[seg_idx_stack].size := size;
  SetSeg(seg_idx_stack);
  SymSetValue(SymFind('@CURSEG'), seg_idx_stack);
End;

{ ============================================================
  ParseSegment : SEGMENT nom [align] [combine] [class]
  Ouvre un segment utilisateur explicite.
  ============================================================ }
Procedure ParseSegment(Const name : TString;
                       aln : TSegAlign; comb : TSegCombine;
                       Const cls : TString);
Var
  idx : Integer;
Begin
  idx := SegFind(LexUpperCase(name));
  If idx = 0 Then
    idx := SegEnter(LexUpperCase(name), LexUpperCase(cls), comb, aln)
  Else
  Begin
    { re-ouverture d un segment existant : coherence des attributs }
    If seg_table[idx].combine <> comb Then
      WarnMsg('Attributs de segment incoherents : ' + name);
  End;
  { empiler le segment courant }
  If seg_open_top < 8 Then
  Begin
    Inc(seg_open_top);
    seg_open_stack[seg_open_top] := cur_seg;
  End;
  SetSeg(idx);
  SymSetValue(SymFind('@CURSEG'), idx);
End;

{ ============================================================
  ParseEnds : ENDS [nom] - fermer le segment courant
  ============================================================ }
Procedure ParseEnds(Const name : TString);
Var
  expected : TString;
Begin
  { verifier que le nom correspond au segment ouvert }
  If (cur_seg >= 1) And (cur_seg <= MAX_SEG) Then
    expected := seg_table[cur_seg].name
  Else
    expected := '';
  If (name <> '') And (LexUpperCase(name) <> expected) Then
    WarnMsg('ENDS ne correspond pas au segment ouvert : ' + name);
  FlushLEDATA;
  { depiler }
  If seg_open_top >= 0 Then
  Begin
    SetSeg(seg_open_stack[seg_open_top]);
    Dec(seg_open_top);
  End
  Else
    SetSeg(0);
  SymSetValue(SymFind('@CURSEG'), cur_seg);
End;

{ ============================================================
  ParseAssume : ASSUME reg:seg [, reg:seg ...]
  Syntaxe simplifiee : reg et seg deja identifies par l appelant.
  reg_name = 'CS'|'DS'|'SS'|'ES', seg_name = nom de segment ou groupe
  ============================================================ }
Procedure ParseAssume(Const reg_name : TString; Const seg_name : TString);
Var
  sidx  : Integer;
  gi    : Integer;
  gi2   : Integer;
  useg  : TSymString;
Begin
  useg := LexUpperCase(seg_name);
  If useg = 'NOTHING' Then
    sidx := 0
  Else
  Begin
    sidx := SegFind(useg);
    If sidx = 0 Then
    Begin
      { chercher dans les groupes }
      gi := 0;
      For gi2 := 1 To grp_count Do
        If grp_table[gi2].name = useg Then
        Begin
          gi := gi2;
          Break;
        End;
      If gi > 0 Then sidx := gi
      Else
        WarnMsg('ASSUME : segment ou groupe inconnu : ' + seg_name);
    End;
  End;
  If reg_name = 'CS' Then assume_cs := sidx
  Else If reg_name = 'DS' Then assume_ds := sidx
  Else If reg_name = 'SS' Then assume_ss := sidx
  Else If reg_name = 'ES' Then assume_es := sidx
  Else
    WarnMsg('ASSUME : registre de segment inconnu : ' + reg_name);
End;

{ ============================================================
  EmitAlignPad : aligner le LC sur un multiple de n octets.
  Code : remplir avec NOP (90h). Data : remplir avec 0.
  ============================================================ }
Procedure EmitAlignPad(n : Integer);
Var
  pad   : Integer;
  is_code : Boolean;
  i     : Integer;
Begin
  If n <= 1 Then Exit;
  pad := lc Mod n;
  If pad = 0 Then Exit;
  pad := n - pad;
  is_code := (cur_seg = seg_idx_text) Or (cur_seg = assume_cs);
  For i := 1 To pad Do
    If is_code Then EmitByte($90) { NOP }
    Else EmitByte($00);
End;

{ ============================================================
  GetSegAlignByte : convertir TSegAlign en octet ACBP pour OMF
  ============================================================ }
Function GetSegAlignByte(a : TSegAlign) : Byte;
Begin
  Case a Of
    SA_BYTE  : GetSegAlignByte := 1;
    SA_WORD  : GetSegAlignByte := 2;
    SA_PARA  : GetSegAlignByte := 3;
    SA_PAGE  : GetSegAlignByte := 4;
    SA_DWORD : GetSegAlignByte := 5;
    Else       GetSegAlignByte := 3; { defaut PARA }
  End;
End;

{ ============================================================
  GetSegCombByte : convertir TSegCombine en octet ACBP pour OMF
  ============================================================ }
Function GetSegCombByte(c : TSegCombine) : Byte;
Begin
  Case c Of
    SC_PRIVATE : GetSegCombByte := 0;
    SC_PUBLIC  : GetSegCombByte := 2;
    SC_STACK   : GetSegCombByte := 5;
    SC_COMMON  : GetSegCombByte := 6;
    SC_MEMORY  : GetSegCombByte := 2;
    Else         GetSegCombByte := 0;
  End;
End;

{ ============================================================
  WriteAllSegments : ecrire LNAMES + tous les SEGDEF + GRPDEF
  dans le fichier .OBJ. Appele apres la passe 2.
  ============================================================ }
Procedure WriteAllSegments;
Var
  i    : Integer;
  gi   : Integer;
  gj   : Integer;
  sni  : Integer;
  cni  : Integer;
  tmp  : Array[0..MAX_SEG] Of Integer;
  tcnt : Integer;
Begin
  { 1. ecrire LNAMES (accumules) }
  ObjLNAMES;

  { 2. ecrire un SEGDEF par segment }
  For i := 1 To seg_count Do
  Begin
    With seg_table[i] Do
    Begin
      sni := lnames_idx;
      If class_name <> '' Then
        cni := LNamesRegister(class_name)
      Else
        cni := 0;
      ObjSEGDEF(
        GetSegAlignByte(align),
        GetSegCombByte(combine),
        size,
        sni,
        cni,
        0   { pas d overlay }
      );
    End;
  End;

  { 3. ecrire un GRPDEF par groupe }
  For gi := 1 To grp_count Do
  Begin
    With grp_table[gi] Do
    Begin
      tcnt := grp_table[gi].seg_count;
      For gj := 1 To tcnt Do
        tmp[gj-1] := segs[gj];
      ObjGRPDEF(
        LNamesRegister(name),
        tmp,
        tcnt
      );
    End;
  End;
End;

{ ============================================================
  Programme principal (TODOs 08 a 25 a implementer)
  ============================================================ }
Begin
  Writeln('Microsoft Macro Assembler Version ', VERSION,
          ' (MASM.PAS - compatible MASM 5.x)');
  InitTables;
  ObjInit;
  FixupInit;
  ModelInit;
  SrcInit;
  LexInit;
  SymInit;
  Writeln('TODOs 01-07 complets (infra+src+lex+sym+OMF+LEDATA+segments).');
  Writeln('TODOs 08 a 25 a implementer.');
End.
