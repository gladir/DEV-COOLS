{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026-07-03
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur X++ (Axapta / Microsoft Dynamics AX) vers
                assembleur 80386 pour Windows 32 bits
  @output: Win32 PE .EXE par defaut, COFF i386 .OBJ sur demande (-obj),
           .ASM 80386 optionnel sur demande explicite (-asm)
  @license: MIT
}

Program XPPCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

{ TODO XPPCW32 - Compilateur X++ (Axapta) vers 80386/Win32

  TODO 01 - INFRASTRUCTURE, PIPELINE ET OPTIONS DE LIGNE DE COMMANDE
            Definir le pipeline complet : source .xpp -> lexer -> parser ->
            tables semantiques (classes/interfaces/tables) -> IR -> ASM
            80386 optionnel -> OBJ COFF i386 -> EXE PE32 par defaut.
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode).
            ParseArgs : argv source.xpp [-o out] [-v] [-d] [-w] [-obj]
              [-asm] [-h].
            Par defaut : produire un .EXE PE Win32 ; -obj : produire
              uniquement un .OBJ COFF (pas d'.EXE) ; -asm : produire en
              plus un .ASM 80386 lisible (jamais emis sans le parametre).
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE.
            Detecter l'extension .xpp.

  TODO 02 - MODELE CIBLE WIN32 ET CONSTANTES PE/COFF
            Mode plat 32 bits, sections .text/.data/.bss, alignements,
            convention d'appel interne (registres/pile), prologues et
            epilogues 80386.
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000), PE_SEC_ALIGN
              (4096), PE_FILE_ALIGN (512), PE_SUBSYS_CUI.
            Limites : MAX_SYM, MAX_CLASS, MAX_METHOD, MAX_LOCAL,
              MAX_PARAM, MAX_LABEL, MAX_STR, MAX_ERRORS.
            Prefixes ASM : _XPP_ (variable globale), _XPPF_ (methode),
              _XPPC_ (classe/vtable), _XPPK_ (chaine litterale),
              _XPPRT_ (runtime), _XPPL_ (label), _XPPT_ (table).

  TODO 03 - LEXER X++ (TOKENISEUR)
            LexInit, LexClose, LexNextChar, LexPeekChar, LexNextToken.
            Identificateurs (lettres, chiffres, _), sensibles a la casse.
            Litteraux numeriques (entiers, reels, notation scientifique),
              chaines "..." avec echappements, caracteres, dates
              'jj/mm/aaaa'.
            Commentaires // (fin de ligne) et /* ... */ (bloc).
            Operateurs : + - * / div mod ++ -- += -= *= /= == != < > <=
              >= && || ! & | ^ ~ << >> = -> :: .. et ponctuation
              { } ( ) [ ] ; , : .

  TODO 04 - MOTS-CLES ET TYPES DE BASE X++
            IsKeyword : class interface extends implements public
              private protected static void new this super if else
              switch case default break continue while do for return
              try catch throw finally delegate container select
              while select insert update delete ttsbegin ttscommit
              ttsabort order by group by exists join.
            Types scalaires : int, real, str, boolean, date, guid,
              anytype, void, container, enum.

  TODO 05 - DECLARATIONS DE CLASSES ET D'INTERFACES (PARSER)
            class Nom [extends Parent] [implements Iface1, Iface2] { },
            interface Nom { signatures de methodes; }, champs typés,
            methodes public/private/protected/static, constructeur
            new(parametres).

  TODO 06 - TABLE DES SYMBOLES ET PORTEES
            Portee globale, classe, methode, bloc ; resolution des
            membres herites, detection des doublons et des membres non
            definis, verification de la compatibilite extends/implements.

  TODO 07 - TYPES COMPOSES : TABLEAUX, CONTAINERS, ENUMS
            int/str/... tab[N] (tableaux fixes 1-indexes), container
            (liste heterogene, operateur +=, con2Str, conLen, conPeek,
            conIns, conDel), enum (valeurs nommees accedees via ::,
            ex. CustVendorBlocked::No).

  TODO 08 - VARIABLES, CONSTANTES ET ALLOCATION
            Declaration de variables locales (offsets EBP) et de champs
            de classe (offsets d'instance), valeurs par defaut (0, "",
            false, date nulle), litteraux, evaluation constante simple.

  TODO 09 - EXPRESSIONS ET OPERATEURS
            Priorites X++ (assignation, logique, comparaison, bit,
            additif, multiplicatif, unaire, acces membre/indexation),
            evaluation en IR typee, promotion int<->real.

  TODO 10 - INSTRUCTIONS DE BASE ET IF/ELSE
            Bloc { }, affectation, appel de methode, instruction vide
            (;), if/else if/else, evaluation paresseuse de && et ||.

  TODO 11 - SWITCH/CASE
            switch(expr) { case val: ... break; case v1: case v2: ...
            default: } avec enchainement explicite (fall-through) et
            verification des valeurs constantes de case.

  TODO 12 - BOUCLES WHILE, DO-WHILE, FOR
            while(cond) { }, do { } while(cond);, for(init; cond;
            incr) { }, break, continue, boucles imbriquees.

  TODO 13 - METHODES ET PARAMETRES
            Declaration de methodes (public/private/static), parametres
            typés, valeur de retour, recursion, verification d'arite et
            de types a chaque appel.

  TODO 14 - HERITAGE (EXTENDS) ET POLYMORPHISME
            extends, super(...), redefinition de methode, resolution
            dynamique via une table de methodes virtuelles par classe,
            appel du constructeur parent.

  TODO 15 - INTERFACES (IMPLEMENTS)
            Declaration d'interface, implements multiple, verification
            que toutes les methodes de l'interface sont implementees,
            appel polymorphe via une variable typee interface.

  TODO 16 - GESTION DES EXCEPTIONS (TRY/CATCH/THROW)
            try { } catch (Exception::Xxx) { } catch { }, throw
            error("msg"), Exception::Error/Warning/Internal, deroulement
            de pile (unwind) lors de la propagation.

  TODO 17 - DELEGATES ET GESTIONNAIRES D'EVENEMENTS
            delegate void Nom(params) { }, appel this.Nom(...), attribut
            [SubscribesTo(classStr(Classe), delegateStr(Classe, Nom))]
            sur une methode static, table de liaison delegate->abonnes
            generee au link-time, invocation de tous les abonnes.

  TODO 18 - MODELE DE TABLE (AOT SIMULE) ET METADONNEES
            Definition interne minimale des tables standard utilisees
            par les samples (CustTable, CustGroup : champs et cles),
            tableNum/fieldNum, representation memoire d'un buffer
            d'enregistrement (recordbuffer).

  TODO 19 - WHILE SELECT / SELECT ET REQUETES SIMPLES
            while select var [order by champ] [where condition] { },
            select [forUpdate] var where condition;, traduction en
            boucle d'iteration sur un stockage de table interne
            (tableau/fichier en memoire).

  TODO 20 - CRUD ET TRANSACTIONS (INSERT/UPDATE/DELETE/TTS)
            .insert()/.update()/.delete()/.clear(), delete_from ...
            where ..., ttsBegin/ttsCommit/ttsAbort avec pile de
            transactions imbricables et retour arriere en memoire.

  TODO 21 - QUERY, QUERYBUILDDATASOURCE, QUERYRUN
            new Query(), addDataSource(tableNum), addRange(fieldNum),
            .value(), new QueryRun(query), .next(), .get(tableNum),
            SysQuery::valueNotEmpty minimal.

  TODO 22 - COLLECTIONS RUNTIME : MAP ET LIST
            new Map(Types::X, Types::Y) / new List(Types::X),
            insert/addEnd, getEnumerator, MapEnumerator/ListEnumerator,
            moveNext/current/currentKey/currentValue, elements().

  TODO 23 - FONCTIONS RUNTIME NATIVES (STR/DATE/DIVERS)
            strFmt, strLen, strUpr, strLwr, subStr, strFind, strDel,
            strIns, strLTrim, strRTrim, con2Str, str2Date, today,
            mthOfYr, mthName, newGuid, guid2Str, info(), print/pause
            herites d'Axapta 2.x.

  TODO 24 - GENERATION ASM 80386, OBJ COFF ET LIEN EXE
            Writer ASM 80386 optionnel (labels stables, sections
            .text/.data/.bss, commentaires de diagnostic), writer OBJ
            COFF i386 minimal (sections, table de symboles, relocations
            REL32/DIR32), lien .OBJ -> .EXE PE32 par defaut avec point
            d'entree et imports minimaux (kernel32/msvcrt ou runtime
            interne).

  TODO 25 - SUITE DE VALIDATION SAMPLES\XPP\* ET STABILISATION
            Compiler et executer les 20 fichiers SAMPLES\XPP\*.xpp
            (01_hello.xpp a 20_map_and_list.xpp), verifier le
            comportement par defaut (.EXE), -obj (.OBJ seul) et -asm
            (.ASM produit en plus), comparer les sorties info()
            attendues, garantir la compatibilite Turbo Pascal/Free
            Pascal {$MODE TP} et corriger les regressions.
}
