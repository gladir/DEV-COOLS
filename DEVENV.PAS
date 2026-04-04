{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Clone de l'application Visual Studio en mode graphique.
                IDE multi-fenetre avec menus deroulants, editeur de texte
                avec coloration syntaxique, explorateur de solution,
                integration des compilateurs DEV-COOLS (C#, VB.NET, Pascal).
                Utilise uniquement le graphisme Turbo Pascal / Free Pascal
                (pas d API Windows). Compatible Windows, Linux, DOS.
  @license: MIT
}

(* ============================================================
  DEVENV.PAS - Clone de Visual Studio en mode graphique
  Turbo Pascal / Free Pascal (-Mtp)

  IDE integre multi-fenetre avec coloration syntaxique, menus
  deroulants, explorateur de solution, integration des compilateurs
  C#, VB.NET et Pascal du projet DEV-COOLS. L affichage repose
  entierement sur le graphisme de Turbo Pascal / Free Pascal
  (PtcGraph sous FPC, Graph sous TP7). Aucun appel aux API
  Windows n est utilise : le programme peut etre compile
  sous Windows, Linux et DOS.

  Les compilateurs integres sont ceux du projet DEV-COOLS :
    - C#      : CSCW32 (Win32 PE) et CSC86 (DOS 8086)
    - VB.NET  : VBCW32 (Win32 PE) et VBC86 (DOS 8086)
    - Pascal  : TPCW32 (Win32 PE), VAXPAS86 et VAXPCW32

  Le format de Solution Microsoft (.sln) est supporte en
  lecture et en ecriture, permettant l ouverture de solutions
  existantes creees par Visual Studio.

  Usage :
    DEVENV [solution.sln] [-v] [-h]

  Options :
    solution.sln : ouvrir une solution existante au demarrage
    -v           : mode verbeux (afficher details de demarrage)
    -h           : afficher l aide en ligne

  Le programme final aura plus de 50 000 lignes de code.
  Pour le moment, seule la TODO est definie afin de bien
  planifier les 30 taches d implementation.

  TODO 01 - INFRASTRUCTURE, CONSTANTES ET OPTIONS [IMPLEMENTE]
            DEVENV_VERSION ('1.0') et DEVENV_DATE ('2026-04-03')
            Constantes de dimensionnement :
              MAX_WINDOWS (32), MAX_TABS (64), MAX_MENUS (16),
              MAX_MENU_ITEMS (32), MAX_LINES (65536),
              MAX_LINE_LEN (1024), MAX_UNDO (512),
              MAX_SOLUTION_PROJECTS (64), MAX_PROJECT_FILES (256),
              MAX_BOOKMARKS (128), MAX_BREAKPOINTS (256),
              MAX_ERRORS (1024), MAX_FIND_RESULTS (4096),
              BUFFER_SIZE (65536), TOOLBAR_HEIGHT (28),
              MENUBAR_HEIGHT (20), STATUSBAR_HEIGHT (20),
              EXPLORER_WIDTH (220), OUTPUT_HEIGHT (150)
            Codes de retour : EXIT_OK = 0, EXIT_ERROR = 1,
              EXIT_USAGE = 2
            TDevEnvOptions : SolutionFile, Verbose, DebugMode,
              ThemeName, FontSize, TabSize, AutoSave, ShowLineNumbers,
              WordWrap, AutoIndent, ShowWhitespace
            Procedure FatalError(Msg: String)
            Procedure ShowVersion
            Procedure ShowHelp
            Procedure InitOptions(Var Opts: TDevEnvOptions)
            Procedure ParseCommandLine(Var Opts: TDevEnvOptions)
            Fonctions utilitaires : IntToStr, StrToInt, UpCaseStr,
              LowerCaseStr, TrimStr, ExtractFileName, ExtractFileExt,
              ExtractFilePath, ChangeFileExt, FileExists,
              DirectoryExists, HexByte, HexWord, HexLong,
              Min, Max, Clamp, PadLeft, PadRight, StringReplace

  TODO 02 - INITIALISATION GRAPHIQUE MULTIPLATEFORME [IMPLEMENTE]
            Abstraction du mode graphique pour Turbo Pascal 7 et
            Free Pascal (PtcGraph). Resolution 800x600 ou 1024x768.
            Procedure InitializeGraphics : detecter et initialiser
              le pilote graphique (VGA/SVGA), gerer les erreurs.
            Procedure ShutdownGraphics : fermer proprement le mode
              graphique et restaurer le mode texte.
            Procedure SetResolution(W, H: Integer) : changer la
              resolution si le pilote le supporte.
            Function GetScreenWidth: Integer
            Function GetScreenHeight: Integer
            Function GetMaxColors: Integer
            Procedure SetClipRect(X1, Y1, X2, Y2: Integer)
            Procedure ResetClipRect
            Procedure ClearScreen(Color: Integer)
            Constantes de couleurs du theme Visual Studio :
              CLR_BACKGROUND, CLR_TITLEBAR, CLR_TITLEBAR_ACTIVE,
              CLR_MENUBAR, CLR_MENU_HIGHLIGHT, CLR_MENU_TEXT,
              CLR_TOOLBAR, CLR_EDITOR_BG, CLR_EDITOR_TEXT,
              CLR_EDITOR_GUTTER, CLR_EXPLORER_BG, CLR_OUTPUT_BG,
              CLR_STATUSBAR, CLR_SCROLLBAR, CLR_SELECTION,
              CLR_CURSOR, CLR_LINE_HIGHLIGHT, CLR_BORDER

  TODO 03 - GESTION DE LA SOURIS ET SYSTEME D EVENEMENTS [IMPLEMENTE]
            Abstraction souris multiplateforme :
              Turbo Pascal : INT $33 (AX=0 init, AX=1 show,
                AX=2 hide, AX=3 position/boutons).
              Free Pascal : PtcMouse (InitMouse, GetMouseState).
            TEventKind : EV_NONE, EV_MOUSE_MOVE, EV_MOUSE_DOWN,
              EV_MOUSE_UP, EV_MOUSE_DBLCLICK, EV_KEY_DOWN,
              EV_KEY_CHAR, EV_TIMER, EV_RESIZE, EV_CLOSE
            TMouseButton : MB_LEFT, MB_RIGHT, MB_MIDDLE
            TEvent record : Kind, MouseX, MouseY, MouseBtn,
              KeyCode, KeyChar, ShiftState, Timestamp
            TEventQueue : file circulaire d evenements (256 entrees)
            Procedure InitMouse
            Function MouseDriverFound: Boolean
            Procedure ShowMouse / HideMouse
            Procedure GetMouseState(Var X, Y, Btn: Integer)
            Procedure PollEvents(Var Ev: TEvent) : interroger la
              souris et le clavier, generer les evenements.
            Procedure PushEvent(Ev: TEvent)
            Function PopEvent(Var Ev: TEvent): Boolean
            Function PeekEvent(Var Ev: TEvent): Boolean
            Procedure FlushEvents
            Gestion du double-clic par delai (300 ms).
            Gestion des touches speciales : F1-F12, fleches,
              Home, End, PgUp, PgDn, Insert, Delete, Backspace,
              Tab, Enter, Escape, Ctrl+A..Z, Alt+A..Z, Shift+*.

  TODO 04 - SYSTEME DE WIDGETS GUI (BASE) [IMPLEMENTE]
            TWidget = objet de base pour tous les controles.
              Champs : X, Y, Width, Height, Visible, Enabled,
                Focused, Parent, Tag, Name.
              Methodes : Draw, HandleEvent, SetBounds, Contains,
                Show, Hide, Enable, Disable, Invalidate, Repaint.
            TPanel : conteneur rectangulaire avec bordure optionnelle.
            TLabel : texte statique non interactif.
            TButton : bouton cliquable avec texte, gestion du survol
              et de l appui (normal, hover, pressed, disabled).
            TCheckBox : case a cocher avec label.
            TRadioButton : bouton radio avec groupe d exclusion.
            TEditField : champ de saisie de texte sur une ligne.
            TListBox : liste deroulante avec barre de defilement.
            TComboBox : champ de saisie avec liste deroulante.
            TScrollBar : barre de defilement horizontale/verticale.
            TProgressBar : barre de progression.
            TSplitter : separateur redimensionnable entre panneaux.
            TTreeNode et TTreeView : arbre hierarchique avec
              expansion/reduction des noeuds (pour l explorateur
              de solution).
            TTabControl : onglets cliquables pour les fenetres
              d editeur.
            Procedure RegisterWidget(W: PWidget)
            Procedure UnregisterWidget(W: PWidget)
            Procedure DrawAllWidgets
            Procedure DispatchEvent(Ev: TEvent)
            Procedure SetFocus(W: PWidget)
            Function GetFocusedWidget: PWidget

  TODO 05 - BARRE DE MENUS ET MENUS DEROULANTS [IMPLEMENTE]
            Menus deroulants reproduisant ceux de Visual Studio.
            TMenuItem : Caption, ShortCut, Enabled, Checked,
              Separator, SubMenu, OnClick, Tag, IconIndex.
            TMenu : liste de TMenuItem.
            TMenuBar : barre horizontale en haut de l ecran.
            Menus principaux de Visual Studio :
              Fichier : Nouveau (Projet, Fichier, Solution),
                Ouvrir (Projet/Solution, Fichier, Dossier),
                Fermer, Fermer la solution,
                Enregistrer, Enregistrer sous, Enregistrer tout,
                Imprimer, Apercu avant impression,
                Fichiers recents, Projets recents,
                Quitter
              Edition : Annuler, Retablir, Couper, Copier, Coller,
                Supprimer, Selectionner tout, Rechercher et remplacer,
                Aller a la ligne, Mise en forme (Indenter, Desindenter,
                Mettre en majuscules, Mettre en minuscules),
                Signets (Activer/Desactiver, Suivant, Precedent,
                Effacer tout), Mode insertion/remplacement
              Affichage : Explorateur de solution, Sortie,
                Liste d erreurs, Barre d outils, Plein ecran,
                Signets, Pile d appels, Espion, Points d arret,
                Naviguer en arriere, Naviguer en avant
              Projet : Ajouter un element existant, Ajouter un
                nouvel element, Exclure du projet, Proprietes
                du projet, Ajouter une reference, Gerer les
                packages NuGet (stub)
              Generer : Generer la solution (F6), Regener la
                solution, Generer le projet, Nettoyer la solution,
                Nettoyer le projet, Gestionnaire de configuration
              Deboguer : Demarrer le debogage (F5), Demarrer
                sans debogage (Ctrl+F5), Point d arret (F9),
                Pas a pas principal (F10), Pas a pas detaille (F11),
                Pas a pas sortant (Shift+F11), Arreter le
                debogage (Shift+F5)
              Outils : Options, Personnaliser, Gestionnaire
                d extensions (stub), Ligne de commande externe
              Fenetre : Nouvelle fenetre, Fractionner, Fermer
                toutes les fenetres, Fenetre suivante (Ctrl+F6),
                Fenetre precedente (Ctrl+Shift+F6)
              Aide : A propos de DEVENV, Documentation en ligne,
                Raccourcis clavier, Bienvenue
            Procedure InitMenuBar
            Procedure DrawMenuBar
            Procedure OpenMenu(Index: Integer)
            Procedure CloseMenu
            Procedure HandleMenuEvent(Ev: TEvent)
            Procedure ExecuteMenuItem(Item: PMenuItem)
            Gestion des raccourcis clavier (Ctrl+S, Ctrl+O, etc.).
            Sous-menus imbriques (cascade).
            Barre de separation entre groupes de commandes.
            Mise en surbrillance de l element selectionne.

  TODO 06 - BARRE D OUTILS ET BOUTONS D ICONES [IMPLEMENTE]
            TToolBar : barre horizontale sous la barre de menus.
            TToolButton : bouton avec icone 16x16 dessinee en
              mode graphique (pas de fichier externe).
            Boutons standard de Visual Studio :
              Nouveau fichier, Ouvrir, Enregistrer, Enregistrer tout,
              Couper, Copier, Coller, Annuler, Retablir,
              Demarrer (F5), Arreter, Pas a pas (F10),
              Point d arret, Rechercher, Naviguer arriere/avant
            Procedure DrawToolBar
            Procedure HandleToolBarEvent(Ev: TEvent)
            Procedure DrawIcon16x16(X, Y: Integer; Icon: TIcon16)
            TIcon16 = Array[0..15, 0..15] of Byte : matrice de
              pixels pour les icones (dessin procedural).
            InitToolBarIcons : initialiser les icones en memoire.
            Infobulles (tooltips) : afficher le nom de l outil
              au survol apres un delai de 500 ms.
            Separateurs visuels entre groupes de boutons.
            Etat des boutons : normal, survol, appuye, desactive.

  TODO 07 - GESTIONNAIRE DE FENETRES MULTIPLES (MDI) [IMPLEMENTE]
            Systeme de fenetres multiples dans la zone d edition.
            TEditorWindow : X, Y, Width, Height, Title, FileName,
              Modified, Buffer, ScrollX, ScrollY, CursorX, CursorY,
              SelectionStart, SelectionEnd, TabIndex, Visible,
              Minimized, Maximized.
            TWindowManager : liste des fenetres ouvertes, fenetre
              active, onglets en haut de la zone d edition.
            Procedure CreateEditorWindow(FileName: String)
            Procedure CloseEditorWindow(Index: Integer)
            Procedure ActivateWindow(Index: Integer)
            Procedure DrawWindowTabs : dessiner les onglets en haut
              de la zone d edition avec le nom du fichier et un
              bouton de fermeture (X) sur chaque onglet.
            Procedure HandleTabEvent(Ev: TEvent) : clic sur les
              onglets, clic droit (menu contextuel : Fermer,
              Fermer les autres, Fermer tout).
            Procedure SplitView : fractionner la vue en deux editeurs.
            Procedure ArrangeTile / ArrangeCascade
            Procedure NextWindow / PreviousWindow
            Procedure SaveAllWindows
            Procedure CloseAllWindows
            Indicateur de modification (asterisque) dans l onglet.
            Maximum MAX_WINDOWS fenetres simultanees.

  TODO 08 - TAMPON DE TEXTE ET GESTION DES LIGNES [IMPLEMENTE]
            TTextBuffer : structure de donnees pour le texte edite.
              Lignes stockees dans un tableau dynamique de String.
              Champs : Lines (Array of String), LineCount, Modified,
                FileName, FileEncoding, LineEnding (CR, LF, CRLF).
            Procedure InitBuffer(Var Buf: TTextBuffer)
            Procedure FreeBuffer(Var Buf: TTextBuffer)
            Procedure LoadFile(Var Buf: TTextBuffer; FileName: String)
            Procedure SaveFile(Var Buf: TTextBuffer; FileName: String)
            Function GetLine(Var Buf: TTextBuffer; N: LongInt): String
            Procedure SetLine(Var Buf: TTextBuffer; N: LongInt; S: String)
            Procedure InsertLine(Var Buf: TTextBuffer; N: LongInt; S: String)
            Procedure DeleteLine(Var Buf: TTextBuffer; N: LongInt)
            Procedure InsertChar(Var Buf: TTextBuffer; Line, Col: LongInt;
              Ch: Char)
            Procedure DeleteChar(Var Buf: TTextBuffer; Line, Col: LongInt)
            Procedure InsertText(Var Buf: TTextBuffer; Line, Col: LongInt;
              Text: String)
            Procedure DeleteRange(Var Buf: TTextBuffer;
              L1, C1, L2, C2: LongInt)
            Function GetTextRange(Var Buf: TTextBuffer;
              L1, C1, L2, C2: LongInt): String
            Function GetLineCount(Var Buf: TTextBuffer): LongInt
            Function GetTotalChars(Var Buf: TTextBuffer): LongInt
            Function IsModified(Var Buf: TTextBuffer): Boolean
            Procedure MarkSaved(Var Buf: TTextBuffer)
            Gestion de fichiers volumineux (jusqu a MAX_LINES lignes).
            Detection automatique de l encodage (ASCII, UTF-8 stub).
            Detection automatique des fins de ligne (CR/LF/CRLF).

  TODO 09 - EDITEUR DE TEXTE : EDITION DE BASE [IMPLEMENTE]
            TEditor : composant d edition de texte complet.
              Champs : Buffer (TTextBuffer), CursorLine, CursorCol,
                ScrollLine, ScrollCol, InsertMode, TabSize,
                AutoIndent, ShowLineNumbers, ShowWhitespace,
                GutterWidth, CharWidth, CharHeight, VisibleLines,
                VisibleCols.
            Procedure InitEditor(Var Ed: TEditor)
            Procedure DrawEditor(Var Ed: TEditor) : dessiner le
              contenu visible du tampon avec coloration syntaxique,
              numeros de ligne dans la gouttiere, ligne de curseur
              en surbrillance.
            Procedure HandleEditorKey(Var Ed: TEditor; Ev: TEvent)
            Gestion du curseur :
              Fleches haut/bas/gauche/droite, Home (debut de ligne),
              End (fin de ligne), Ctrl+Home (debut du fichier),
              Ctrl+End (fin du fichier), PgUp, PgDn.
            Insertion de texte :
              Caracteres imprimables, Enter (nouvelle ligne avec
              auto-indentation), Tab (inserer des espaces ou tab),
              Backspace (effacer avant), Delete (effacer apres).
            Mode insertion / remplacement (touche Insert).
            Defilement automatique quand le curseur sort de la vue.
            Procedure EnsureCursorVisible(Var Ed: TEditor)
            Procedure GotoLine(Var Ed: TEditor; Line: LongInt)
            Procedure GotoColumn(Var Ed: TEditor; Col: LongInt)
            Procedure DrawCursor(Var Ed: TEditor) : curseur
              clignotant (barre en mode insertion, bloc en mode
              remplacement).
            Procedure DrawGutter(Var Ed: TEditor) : numeros de
              ligne, marqueurs de points d arret et signets.
            Procedure DrawLineHighlight(Var Ed: TEditor) : ligne
              courante en surbrillance.

  TODO 10 - EDITEUR DE TEXTE : SELECTION, PRESSE-PAPIER, ANNULER [IMPLEMENTE]
            Selection de texte :
              Shift+Fleches : etendre la selection caractere par
                caractere ou ligne par ligne.
              Shift+Home/End : selectionner jusqu au debut/fin
                de la ligne.
              Shift+PgUp/PgDn : selectionner par page.
              Ctrl+A : selectionner tout le texte.
              Clic souris + glisser : selectionner avec la souris.
              Double-clic : selectionner le mot sous le curseur.
              Triple-clic : selectionner la ligne entiere.
            TSelection : StartLine, StartCol, EndLine, EndCol, Active.
            Procedure DrawSelection(Var Ed: TEditor) : surbrillance
              de la zone selectionnee.
            Presse-papier interne (pas d acces au presse-papier OS) :
              TClipboard : Text (String), HasData (Boolean).
              Procedure ClipboardCopy(Var Ed: TEditor)
              Procedure ClipboardCut(Var Ed: TEditor)
              Procedure ClipboardPaste(Var Ed: TEditor)
            Annuler / Retablir (Undo/Redo) :
              TUndoAction : UA_INSERT, UA_DELETE, UA_REPLACE,
                UA_INSERT_LINE, UA_DELETE_LINE, UA_JOIN_LINE,
                UA_SPLIT_LINE.
              TUndoRecord : Action, Line, Col, Text, OldText,
                GroupId (pour regrouper les actions liees).
              TUndoStack : tableau circulaire de MAX_UNDO entrees.
              Procedure PushUndo(Var Ed: TEditor; Action: TUndoAction;
                Line, Col: LongInt; Text, OldText: String)
              Procedure Undo(Var Ed: TEditor)
              Procedure Redo(Var Ed: TEditor)
              Procedure ClearUndoStack(Var Ed: TEditor)
            Raccourcis : Ctrl+C copier, Ctrl+X couper, Ctrl+V coller,
              Ctrl+Z annuler, Ctrl+Y retablir.

  TODO 11 - MOTEUR DE COLORATION SYNTAXIQUE [IMPLEMENTE]
            TTokenClass : TC_NORMAL, TC_KEYWORD, TC_STRING,
              TC_CHAR, TC_NUMBER, TC_COMMENT, TC_DIRECTIVE,
              TC_OPERATOR, TC_IDENTIFIER, TC_TYPE,
              TC_PREPROCESSOR, TC_ATTRIBUTE, TC_XMLDOC.
            TSyntaxHighlighter : interface commune pour tous les
              langages. Champs : Language, InBlockComment,
              InString, StateStack.
            Methodes :
              Procedure InitHighlighter(Var H: TSyntaxHighlighter;
                Language: String)
              Function GetTokenClass(Var H: TSyntaxHighlighter;
                Line: String; Var Pos: Integer): TTokenClass
              Function TokenClassToColor(TC: TTokenClass): Integer
              Procedure ResetState(Var H: TSyntaxHighlighter)
              Procedure HighlightLine(Var H: TSyntaxHighlighter;
                Line: String; Var Colors: Array of Byte)
            Gestion des commentaires multi-lignes (etat persistant
              entre les lignes).
            Gestion des chaines multi-lignes (verbatim strings
              en C#, etc.).
            Couleurs par defaut du theme Visual Studio :
              Mot-cle : bleu ($0000FF)
              Chaine : brun/rouge ($A31515)
              Commentaire : vert ($008000)
              Nombre : noir
              Type : turquoise ($2B91AF)
              Preprocesseur : gris ($808080)
              Attribut : bleu clair
              Documentation XML : vert olive

  TODO 12 - COLORATION SYNTAXIQUE C# [IMPLEMENTE]
            TCSharpHighlighter : specialisation pour le langage C#.
            Mots-cles C# (79 mots) : abstract, as, base, bool,
              break, byte, case, catch, char, checked, class,
              const, continue, decimal, default, delegate, do,
              double, else, enum, event, explicit, extern, false,
              finally, fixed, float, for, foreach, goto, if,
              implicit, in, int, interface, internal, is, lock,
              long, namespace, new, null, object, operator, out,
              override, params, private, protected, public,
              readonly, ref, return, sbyte, sealed, short, sizeof,
              stackalloc, static, string, struct, switch, this,
              throw, true, try, typeof, uint, ulong, unchecked,
              unsafe, ushort, using, var, virtual, void, volatile,
              while.
            Mots-cles contextuels : add, alias, ascending, async,
              await, by, descending, dynamic, equals, from, get,
              global, group, into, join, let, nameof, on, orderby,
              partial, remove, select, set, value, when, where,
              yield.
            Commentaires : // (ligne), /* */ (bloc), /// (XML doc).
            Chaines : "..." (reguliere), @"..." (verbatim),
              $"..." (interpolee).
            Caracteres : 'x', '\n', '\x41'.
            Nombres : 123, 0xFF, 0b1010, 1.5f, 1.5d, 1.5m.
            Attributs : [Attribute].
            Directives preprocesseur : #if, #else, #endif,
              #region, #endregion, #define, #undef, #pragma.
            Types predecoupes : int, string, bool, etc. colores
              differemment quand utilises comme types.

  TODO 13 - COLORATION SYNTAXIQUE VB.NET [IMPLEMENTE]
            TVBNetHighlighter : specialisation pour VB.NET.
            Mots-cles VB.NET (insensible a la casse) :
              AddHandler, AddressOf, Alias, And, AndAlso, As,
              Boolean, ByRef, Byte, ByVal, Call, Case, Catch,
              CBool, CByte, CChar, CDate, CDbl, CDec, Char,
              CInt, Class, CLng, CObj, Const, Continue, CSByte,
              CShort, CSng, CStr, CType, CUInt, CULng, CUShort,
              Date, Decimal, Declare, Default, Delegate, Dim,
              DirectCast, Do, Double, Each, Else, ElseIf, End,
              EndIf, Enum, Erase, Error, Event, Exit, False,
              Finally, For, Friend, Function, Get, GetType,
              GetXMLNamespace, Global, GoSub, GoTo, Handles, If,
              Implements, Imports, In, Inherits, Integer,
              Interface, Is, IsNot, Let, Lib, Like, Long, Loop,
              Me, Mod, Module, MustInherit, MustOverride,
              MyBase, MyClass, Namespace, Narrowing, New, Next,
              Not, Nothing, NotInheritable, NotOverridable,
              Object, Of, On, Operator, Option, Optional, Or,
              OrElse, Overloads, Overridable, Overrides,
              ParamArray, Partial, Private, Property, Protected,
              Public, RaiseEvent, ReadOnly, ReDim, REM, RemoveHandler,
              Resume, Return, SByte, Select, Set, Shadows,
              Shared, Short, Single, Static, Step, Stop, String,
              Structure, Sub, SyncLock, Then, Throw, To, True,
              Try, TryCast, TypeOf, UInteger, ULong, UShort,
              Using, Variant, Wend, When, While, Widening,
              With, WithEvents, WriteOnly, Xor.
            Commentaires : ' (apostrophe en debut ou milieu de ligne),
              REM (mot-cle de commentaire).
            Chaines : "..." (guillemets doubles), "" pour echapper.
            Nombres : 123, &HFF (hexadecimal), &O77 (octal),
              &B1010 (binaire), 1.5F, 1.5D, 1.5R.
            Directives : #If, #Else, #End If, #Const, #Region,
              #End Region.
            Operateurs speciaux : Is, IsNot, Like, Mod, And,
              Or, Xor, Not, AndAlso, OrElse (colores comme mots-cles).

  TODO 14 - COLORATION SYNTAXIQUE PASCAL [IMPLEMENTE]
            TPascalHighlighter : specialisation pour Pascal
              (Turbo Pascal et Free Pascal).
            Mots-cles Pascal : and, array, begin, case, const,
              constructor, destructor, div, do, downto, else, end,
              file, for, function, goto, if, implementation, in,
              inherited, inline, interface, label, mod, nil, not,
              object, of, or, packed, procedure, program, record,
              repeat, set, shl, shr, string, then, to, type, unit,
              until, uses, var, while, with, xor.
            Mots-cles Free Pascal supplementaires : class, try,
              except, finally, raise, property, public, private,
              protected, published, override, virtual, abstract,
              reintroduce, operator, generic, specialize.
            Commentaires : accolades, parentheses-etoiles, // ligne.
            Chaines : apostrophes simples, #nn (caractere
              par code ASCII).
            Nombres : 123, $FF (hexadecimal), %1010 (binaire FPC),
              &77 (octal FPC), 1.5, 1.5E10.
            Directives de compilation : dollar-I, dollar-IFDEF,
              dollar-ENDIF, dollar-MODE, dollar-H+, etc.
            Types predefinis : Integer, LongInt, Word, Byte,
              Boolean, Char, String, Real, Double, Extended,
              Pointer, Text, etc.

  TODO 15 - PARSEUR DE FICHIERS SOLUTION (.SLN) [IMPLEMENTE]
            Format de fichier Solution Microsoft Visual Studio.
            TSolutionInfo : FormatVersion, VSVersion, MinVSVersion,
              GUID, SolutionName, SolutionPath.
            TProjectEntry : ProjectTypeGUID, ProjectGUID,
              ProjectName, ProjectPath, Dependencies.
            TSolution : Info (TSolutionInfo),
              Projects (Array of TProjectEntry), ProjectCount,
              Configurations (Debug, Release, etc.).
            Procedure ParseSolutionFile(FileName: String;
              Var Sol: TSolution)
            Procedure SaveSolutionFile(FileName: String;
              Var Sol: TSolution)
            Procedure FreeSolution(Var Sol: TSolution)
            Function CreateNewSolution(Name, Path: String): TSolution
            Procedure AddProjectToSolution(Var Sol: TSolution;
              ProjName, ProjPath: String; ProjType: TProjectType)
            Procedure RemoveProjectFromSolution(Var Sol: TSolution;
              Index: Integer)
            Reconnaitre les sections :
              Project("TypeGUID") = "Name", "Path", "GUID"
              EndProject
              Global
                GlobalSection(SolutionConfigurationPlatforms)
                GlobalSection(ProjectConfigurationPlatforms)
                GlobalSection(SolutionProperties)
              EndGlobal
            GUIDs des types de projets reconnus :
              C#      : {FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}
              VB.NET  : {F184B08F-C81C-45F6-A57F-5ABD9991F28F}
              Pascal  : {00000000-0000-0000-0000-000000000001}
            Configurations : Debug|AnyCPU, Release|AnyCPU.

  TODO 16 - PARSEUR DE FICHIERS PROJET (.CSPROJ, .VBPROJ, .DPPROJ) [IMPLEMENTE]
            Parseur XML simplifie pour lire les fichiers projet.
            TProjectInfo : ProjectName, RootNamespace,
              AssemblyName, OutputType (Exe, Library, WinExe),
              TargetFramework, OutputPath, DefineConstants.
            TProjectFile : FileName, BuildAction (Compile, Content,
              None, EmbeddedResource), DependentUpon, SubType.
            TProjectRef : ReferenceName, HintPath, ProjectGUID.
            TProject : Info (TProjectInfo),
              Files (Array of TProjectFile), FileCount,
              References (Array of TProjectRef), RefCount,
              Configurations (Array of TBuildConfig).
            Procedure ParseProjectFile(FileName: String;
              Var Proj: TProject)
            Procedure SaveProjectFile(FileName: String;
              Var Proj: TProject)
            Procedure FreeProject(Var Proj: TProject)
            Function CreateNewProject(Name, Path: String;
              ProjType: TProjectType): TProject
            Procedure AddFileToProject(Var Proj: TProject;
              FileName: String)
            Procedure RemoveFileFromProject(Var Proj: TProject;
              Index: Integer)
            Parseur XML minimal : lecture de balises, attributs,
              contenu textuel. Support des balises :
              <Project>, <PropertyGroup>, <ItemGroup>,
              <Compile>, <Reference>, <ProjectReference>,
              <OutputType>, <RootNamespace>, <AssemblyName>.
            Generation de fichier .csproj, .vbproj, .dpproj.

  TODO 17 - EXPLORATEUR DE SOLUTION (PANNEAU DROIT) [IMPLEMENTE]
            Panneau a droite de la zone d edition (largeur
            EXPLORER_WIDTH = 220 pixels).
            TSolutionExplorer : arbre hierarchique affichant :
              - Noeud racine : nom de la solution
                - Noeud projet 1 : nom du projet (icone selon type)
                  - Properties (noeud special)
                  - References (noeud special)
                    - Reference 1, Reference 2, ...
                  - Fichier1.cs (icone selon extension)
                  - Fichier2.cs
                  - Dossier (sous-arbre)
                    - Fichier3.cs
                - Noeud projet 2 : ...
            Procedure InitExplorer(Var Exp: TSolutionExplorer)
            Procedure DrawExplorer(Var Exp: TSolutionExplorer)
            Procedure HandleExplorerEvent(Var Exp: TSolutionExplorer;
              Ev: TEvent)
            Procedure RefreshExplorer(Var Exp: TSolutionExplorer)
            Procedure ExpandNode(Var Exp: TSolutionExplorer; Node: PTreeNode)
            Procedure CollapseNode(Var Exp: TSolutionExplorer; Node: PTreeNode)
            Double-clic sur un fichier : ouvrir dans l editeur.
            Clic droit : menu contextuel (Ouvrir, Renommer,
              Supprimer, Exclure du projet, Ajouter un nouvel
              element, Ajouter un element existant, Proprietes).
            Icones differentes selon le type de fichier :
              .cs (icone C#), .vb (icone VB), .pas (icone Pascal),
              .sln (icone solution), dossier (icone dossier).
            Barre de defilement verticale si l arbre depasse
              la hauteur du panneau.
            Redimensionnement du panneau par un splitter vertical.

  TODO 18 - PANNEAU DE PROPRIETES [IMPLEMENTE]
            Panneau affichant les proprietes de l element
            selectionne dans l explorateur de solution.
            TPropertiesPanel : grille de proprietes avec nom
              et valeur sur deux colonnes.
            Proprietes du projet :
              Nom de l assembly, Espace de noms racine,
              Type de sortie, Chemin de sortie, Framework cible,
              Constantes de compilation, Icone de l application.
            Proprietes du fichier :
              Nom de fichier, Chemin complet, Action de build,
              Outil personnalise, Copier dans le repertoire de
              sortie.
            Procedure InitPropertiesPanel(Var PP: TPropertiesPanel)
            Procedure DrawPropertiesPanel(Var PP: TPropertiesPanel)
            Procedure HandlePropertiesEvent(Var PP: TPropertiesPanel;
              Ev: TEvent)
            Procedure SetPropertySource(Var PP: TPropertiesPanel;
              Source: Pointer; Kind: TPropertyKind)
            Edition des valeurs de proprietes en cliquant dessus.
            Tri alphabetique ou par categorie.

  TODO 19 - PANNEAU DE SORTIE (OUTPUT) [IMPLEMENTE]
            Panneau en bas de la zone d edition (hauteur
            OUTPUT_HEIGHT = 150 pixels) avec onglets :
              - Sortie de build
              - Sortie de debogage
              - Recherche de resultats
            TOutputPanel : tampon de texte en lecture seule avec
              defilement, onglets de selection.
            Procedure InitOutputPanel(Var OP: TOutputPanel)
            Procedure DrawOutputPanel(Var OP: TOutputPanel)
            Procedure HandleOutputEvent(Var OP: TOutputPanel;
              Ev: TEvent)
            Procedure AppendOutput(Var OP: TOutputPanel;
              Text: String; Tab: Integer)
            Procedure ClearOutput(Var OP: TOutputPanel; Tab: Integer)
            Coloration des messages :
              Erreur : rouge, Avertissement : jaune/orange,
              Information : blanc, Succes : vert.
            Clic sur un message d erreur : naviguer vers la ligne
              et la colonne du fichier source correspondant.
            Redimensionnement du panneau par un splitter horizontal.
            Masquer/afficher le panneau (double-clic sur la barre
              de titre ou raccourci clavier).

  TODO 20 - PANNEAU LISTE D ERREURS (ERROR LIST) [IMPLEMENTE]
            Panneau en bas affichant les erreurs, avertissements
            et messages de la derniere compilation.
            TErrorEntry : Severity (Error, Warning, Info),
              Code, Description, File, Line, Column, Project.
            TErrorListPanel : liste des erreurs avec colonnes
              triables et filtres par severite.
            Procedure InitErrorList(Var EL: TErrorListPanel)
            Procedure DrawErrorList(Var EL: TErrorListPanel)
            Procedure HandleErrorListEvent(Var EL: TErrorListPanel;
              Ev: TEvent)
            Procedure AddError(Var EL: TErrorListPanel;
              Entry: TErrorEntry)
            Procedure ClearErrors(Var EL: TErrorListPanel)
            Procedure SortErrors(Var EL: TErrorListPanel;
              Column: Integer)
            Compteurs en haut du panneau :
              N erreurs, N avertissements, N messages.
            Boutons de filtre : afficher/masquer erreurs,
              avertissements, messages.
            Double-clic sur une entree : naviguer vers le fichier
              source a la ligne et colonne indiquees.
            Parsing des sorties des compilateurs pour extraire
              les erreurs (format specifique a chaque compilateur
              DEV-COOLS : CSC, VBC, TPC).

  TODO 21 - BOITES DE DIALOGUE : FICHIERS [IMPLEMENTE]
            Boites de dialogue entierement dessinees en mode
            graphique (pas de boites systeme).
            TDialog : fenetre modale centree avec titre, bordure,
              boutons OK/Annuler, gestion des evenements modale.
            Procedure ShowDialog(Var Dlg: TDialog): Integer
            Procedure CloseDialog(Var Dlg: TDialog)
            TFileDialog : boite d ouverture/enregistrement de
              fichier avec navigation dans les repertoires.
              Champs : CurrentPath, FileList, SelectedFile,
                Filter : .cs .vb .pas et jokers, FilterIndex.
              Navigation : liste des fichiers et dossiers du
                repertoire courant, champ de saisie du nom,
                bouton Parcourir, liste deroulante des filtres.
            Function ShowOpenDialog(Filter: String): String
            Function ShowSaveDialog(Filter, Default: String): String
            TFolderDialog : selection d un repertoire.
            Function ShowFolderDialog(StartPath: String): String
            TMessageBox : boite de message avec icone et boutons.
            Function ShowMessageBox(Title, Text: String;
              Buttons: TMessageButtons; Icon: TMessageIcon): Integer
            Constantes : MB_OK, MB_OKCANCEL, MB_YESNO,
              MB_YESNOCANCEL, MI_INFO, MI_WARNING, MI_ERROR,
              MI_QUESTION.
            TInputBox : boite de saisie d une valeur.
            Function ShowInputBox(Title, Prompt, Default: String): String

  TODO 22 - BOITES DE DIALOGUE : PROJET ET SOLUTION [IMPLEMENTE]
            TNewProjectDialog : creation d un nouveau projet.
              Choix du type : Application console C#, Application
                console VB.NET, Application console Pascal,
                Bibliotheque de classes C#, Bibliotheque de
                classes VB.NET.
              Champs : Nom du projet, Emplacement, Nom de la
                solution, Creer un repertoire pour la solution.
            TNewFileDialog : ajout d un nouveau fichier.
              Types de fichiers : Classe C# (.cs), Module VB (.vb),
                Unite Pascal (.pas), Fichier texte (.txt),
                Fichier XML (.xml).
              Champs : Nom du fichier, Template.
            TAddReferenceDialog : ajout de references.
              Onglets : Assemblies, Projets, Parcourir.
              Liste des assemblies disponibles avec case a cocher.
            TProjectPropertiesDialog : proprietes du projet.
              Onglets : Application, Build, Build Events, Debug.
              Application : nom assembly, namespace racine,
                type de sortie, icone, informations assembly.
              Build : symboles de compilation, chemin de sortie,
                niveau d avertissement, traiter avertissements
                comme erreurs.
            Procedure ShowNewProjectDialog(Var Sol: TSolution)
            Procedure ShowNewFileDialog(Var Proj: TProject)
            Procedure ShowAddReferenceDialog(Var Proj: TProject)
            Procedure ShowProjectPropertiesDialog(Var Proj: TProject)

  TODO 23 - BOITES DE DIALOGUE : OPTIONS DE L IDE [IMPLEMENTE]
            TOptionsDialog : boite de dialogue des options generales
            de l IDE reproduisant les options de Visual Studio.
            Arbre de categories a gauche, panneau de parametres
            a droite.
            Categories :
              Environnement :
                General (theme couleur, police, taille),
                Polices et couleurs (couleur de chaque element
                  syntaxique configurable),
                Clavier (raccourcis personnalisables),
                Demarrage (action au lancement : page d accueil,
                  dernier projet, rien),
                Enregistrement automatique (intervalle, fichiers
                  non enregistres).
              Editeur de texte :
                General (numeros de ligne, retour a la ligne,
                  espaces visibles, guides d indentation),
                Tabulations (taille tab, inserer des espaces,
                  taille d indentation),
                Defilement (defilement fluide, marge de defilement),
                IntelliSense (stub pour future implementation),
                Mise en forme (indentation automatique, accolades).
              Projets et solutions :
                General (emplacement par defaut des projets,
                  afficher la fenetre de sortie au build),
                Build et execution (verbeux, nombre de projets
                  paralleles stub).
              Debogage :
                General (arreter au premier point d arret,
                  pas a pas dans les proprietes),
                Sortie (afficher les messages de debogage).
            Procedure ShowOptionsDialog
            Procedure SaveOptions(FileName: String)
            Procedure LoadOptions(FileName: String)
            Fichier de configuration : DEVENV.CFG (format INI).

  TODO 24 - RECHERCHER ET REMPLACER [IMPLEMENTE]
            TFindReplaceDialog : boite de dialogue de recherche
            et remplacement (non modale, reste ouverte pendant
            l edition).
            Champs : SearchText, ReplaceText, MatchCase,
              WholeWord, UseRegex (stub), SearchScope (Document
              courant, Tous les documents ouverts, Projet entier,
              Solution entiere).
            Procedure ShowFindDialog
            Procedure ShowReplaceDialog
            Procedure FindNext(Var Ed: TEditor; SearchText: String;
              Options: TFindOptions): Boolean
            Procedure FindPrevious(Var Ed: TEditor; SearchText: String;
              Options: TFindOptions): Boolean
            Procedure ReplaceNext(Var Ed: TEditor;
              SearchText, ReplaceText: String; Options: TFindOptions)
            Procedure ReplaceAll(Var Ed: TEditor;
              SearchText, ReplaceText: String; Options: TFindOptions): Integer
            Procedure FindInFiles(SearchText: String;
              Scope: TSearchScope; Options: TFindOptions)
            Mise en surbrillance de toutes les occurrences
              trouvees dans l editeur.
            Resultats de recherche dans le panneau de sortie
              (onglet Recherche).
            Raccourcis : Ctrl+F (chercher), Ctrl+H (remplacer),
              F3 (suivant), Shift+F3 (precedent),
              Ctrl+Shift+F (chercher dans les fichiers).
            TGoToLineDialog : aller a une ligne specifique.
            Procedure ShowGoToLineDialog(Var Ed: TEditor)

  TODO 25 - INTEGRATION COMPILATEUR C# (CSCW32/CSC86) [IMPLEMENTE]
            Integration des compilateurs C# du projet DEV-COOLS.
            Procedure CompileCSharp(Var Proj: TProject;
              Config: TBuildConfig; Var Output: TOutputPanel)
            Construction de la ligne de commande :
              CSCW32 source.cs [-o sortie.exe] [-v] [-d] [-w]
              ou CSC86 source.cs (mode DOS 8086).
            Detection du compilateur disponible dans le PATH
              ou dans le repertoire de l IDE.
            Procedure FindCompiler(Name: String): String
            Execution du compilateur en tant que processus externe :
              Turbo Pascal : Exec(GetEnv('COMSPEC'), '/C ' + CmdLine)
              Free Pascal : ExecuteProcess(CmdLine, Params)
            Capture de la sortie du compilateur (redirection vers
              un fichier temporaire puis lecture).
            Parsing de la sortie pour extraire les erreurs :
              Format CSCW32 : "filename(line,col): error CSnnnn: message"
              Alimenter le panneau Liste d erreurs.
            Procedure ParseCSCOutput(OutputFile: String;
              Var EL: TErrorListPanel)
            Gestion des configurations Debug/Release :
              Debug : -d (symboles de debogage)
              Release : optimisations activees.
            Compilation de tous les fichiers .cs du projet.
            Affichage de la progression dans le panneau de sortie.

  TODO 26 - INTEGRATION COMPILATEUR VB.NET (VBCW32/VBC86) [IMPLEMENTE]
            Integration des compilateurs VB.NET du projet DEV-COOLS.
            Note : les compilateurs VB.NET (VBCW32.PAS, VBC86.PAS)
            sont prevus dans le projet DEV-COOLS mais peuvent ne
            pas encore etre implementes. DEVENV doit gerer leur
            absence gracieusement.
            Procedure CompileVBNet(Var Proj: TProject;
              Config: TBuildConfig; Var Output: TOutputPanel)
            Construction de la ligne de commande :
              VBCW32 source.vb [-o sortie.exe] [-v] [-d] [-w]
              ou VBC86 source.vb (mode DOS 8086).
            Parsing de la sortie pour extraire les erreurs :
              Format VBCW32 : "filename(line): error BCnnnn: message"
              Alimenter le panneau Liste d erreurs.
            Procedure ParseVBCOutput(OutputFile: String;
              Var EL: TErrorListPanel)
            Compilation de tous les fichiers .vb du projet.
            Gestion des configurations Debug/Release.
            Message d erreur informatif si le compilateur
              n est pas trouve.

  TODO 27 - INTEGRATION COMPILATEUR PASCAL (TPCW32/VAXPAS86) [IMPLEMENTE]
            Integration des compilateurs Pascal du projet DEV-COOLS.
            Procedure CompilePascal(Var Proj: TProject;
              Config: TBuildConfig; Var Output: TOutputPanel)
            Construction de la ligne de commande :
              TPCW32 source.pas [-o sortie.exe] [-v]
              ou VAXPAS86 source.pas (mode DOS 8086)
              ou VAXPCW32 source.pas (Win32).
            Detection du compilateur Pascal disponible.
            Parsing de la sortie pour extraire les erreurs :
              Format TPCW32 : "filename(line,col) Error: message"
              Alimenter le panneau Liste d erreurs.
            Procedure ParseTPCOutput(OutputFile: String;
              Var EL: TErrorListPanel)
            Compilation du fichier principal du projet .pas.
            Gestion des configurations Debug/Release.
            Support des unites Pascal : detection des uses et
              compilation des dependances.

  TODO 28 - SYSTEME DE BUILD ET CONFIGURATION [IMPLEMENTE]
            Gestion des configurations de build de la solution.
            TBuildConfig : Name (Debug, Release), Platform
              (AnyCPU, x86, x64), OutputPath, DefineConstants,
              Optimize, DebugInfo, WarningLevel.
            TBuildManager : gestion de la compilation de la
              solution complete.
            Procedure BuildSolution(Var Sol: TSolution;
              Config: TBuildConfig)
            Procedure BuildProject(Var Proj: TProject;
              Config: TBuildConfig)
            Procedure RebuildSolution(Var Sol: TSolution;
              Config: TBuildConfig)
            Procedure CleanSolution(Var Sol: TSolution)
            Procedure CleanProject(Var Proj: TProject)
            Ordre de build : respecter les dependances entre
              projets (build du projet dependant avant le
              projet dependeur).
            Procedure ResolveBuildOrder(Var Sol: TSolution;
              Var Order: Array of Integer)
            Affichage de la progression :
              "Build started..."
              "------ Build started: Project: X, Configuration: Debug ------"
              "X succeeded, Y failed, Z up-to-date, W skipped"
            Raccourcis : F6 (Generer la solution), F7 (Generer le
              projet), Ctrl+Shift+B (Regener la solution).
            TConfigurationManager : boite de dialogue pour
              gerer les configurations (ajouter, supprimer,
              renommer des configurations).
            Procedure ShowConfigurationManager(Var Sol: TSolution)
            Barre d outils : liste deroulante de la configuration
              active (Debug/Release).

  TODO 29 - SUPPORT DU DEBOGAGE ET POINTS D ARRET [IMPLEMENTE]
            Support de base pour le debogage (interface utilisateur,
            les fonctionnalites avancees seront des stubs).
            TBreakpoint : FileName, Line, Enabled, Condition,
              HitCount, HitCountTarget.
            TBreakpointManager : liste des points d arret.
            Procedure AddBreakpoint(FileName: String; Line: Integer)
            Procedure RemoveBreakpoint(FileName: String; Line: Integer)
            Procedure ToggleBreakpoint(FileName: String; Line: Integer)
            Procedure EnableBreakpoint(Index: Integer)
            Procedure DisableBreakpoint(Index: Integer)
            Procedure ClearAllBreakpoints
            Procedure DrawBreakpointMarker(Var Ed: TEditor;
              Line: Integer) : point rouge dans la gouttiere.
            Execution du programme compile :
              Demarrer sans debogage (Ctrl+F5) : lancer l executable
                genere dans une console/terminal externe.
              Demarrer avec debogage (F5) : lancer avec le
                debogueur (stub - afficher un message indiquant
                que le debogage interactif n est pas encore
                supporte, puis lancer sans debogage).
            Panneau Points d arret : liste de tous les points
              d arret avec possibilite de les activer/desactiver.
            Panneau Espion (Watch) : stub pour future implementation,
              affiche un message "Non disponible".
            Panneau Pile d appels (Call Stack) : stub.
            Raccourcis : F5 (demarrer), Ctrl+F5 (sans debogage),
              F9 (point d arret), F10 (pas a pas principal stub),
              F11 (pas a pas detaille stub), Shift+F5 (arreter).

  TODO 30 - BARRE D ETAT, INTEGRATION FINALE ET POLISSAGE [IMPLEMENTE]
            TStatusBar : barre en bas de l ecran affichant :
              - Position du curseur : "Ln X, Col Y"
              - Mode d insertion : "INS" ou "OVR"
              - Encodage du fichier : "ASCII" / "UTF-8"
              - Fin de ligne : "CRLF" / "LF" / "CR"
              - Langage du fichier : "C#" / "VB.NET" / "Pascal"
              - Nom du fichier en cours d edition
              - Etat du build : "Pret" / "Build en cours..." /
                "Build reussi" / "Build echoue"
            Procedure InitStatusBar
            Procedure DrawStatusBar
            Procedure UpdateStatusBar
            Page de demarrage (Start Page) : affichee au lancement
              quand aucune solution n est ouverte. Contient :
              - Titre "DEVENV - IDE Visual Studio"
              - Liste des projets/solutions recents
              - Boutons : Nouveau projet, Ouvrir un projet
              - Logo DEV-COOLS dessine en mode graphique
            Procedure DrawStartPage
            Procedure HandleStartPageEvent(Ev: TEvent)
            Boucle principale de l IDE :
              Repeat
                PollEvents(Ev);
                DispatchEvent(Ev);
                DrawAllWidgets;
                UpdateStatusBar;
              Until QuitRequested;
            Gestion de la fermeture : demander confirmation si
              des fichiers non enregistres existent ("Voulez-vous
              enregistrer les modifications ?").
            Gestion des raccourcis clavier globaux.
            Fichier MRU (Most Recently Used) : DEVENV.MRU
              stockant les derniers fichiers et solutions ouverts.
            Procedure SaveMRUList
            Procedure LoadMRUList
            Gestion des erreurs globales : Try/Except (FPC) ou
              code de gestion d erreurs robuste pour eviter les
              plantages.
            Procedure MainLoop : boucle principale de l IDE.
            Procedure Run : point d entree principal, initialise
              tous les sous-systemes et lance MainLoop.
            Test de validation : verification que tous les
              sous-systemes s initialisent correctement.
            Rapport de version dans le panneau A propos :
              "DEVENV 1.0 - Clone de Visual Studio"
              "Projet DEV-COOLS - Gladir.com"
              "Compilateurs integres : CSC, VBC, TPC"

  ============================================================ *)

Program DEVENV;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

Uses DOS,
     {$IFDEF FPC}
      Crt,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      Crt,Graph
     {$ENDIF};

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
 DEVENV_VERSION = '1.0';
 DEVENV_DATE    = '2026-04-03';

 { Limites des fenetres et onglets }
 MAX_WINDOWS           = 32;
 MAX_TABS              = 64;

 { Limites des menus }
 MAX_MENUS             = 16;
 MAX_MENU_ITEMS        = 32;

 { Limites de l editeur de texte }
 MAX_LINES             = 65536;
 MAX_LINE_LEN          = 1024;
 MAX_UNDO              = 512;

 { Limites des projets et solutions }
 MAX_SOLUTION_PROJECTS = 64;
 MAX_PROJECT_FILES     = 256;

 { Limites des widgets }
 MAX_WIDGETS           = 512;
 MAX_TREE_NODES        = 1024;
 MAX_TAB_ITEMS         = 64;
 MAX_LIST_ITEMS        = 256;
 MAX_EDIT_LEN          = 1024;

 { Limites des signets et points d arret }
 MAX_BOOKMARKS         = 128;
 MAX_BREAKPOINTS       = 256;

 { Limites des erreurs et resultats de recherche }
 MAX_ERRORS            = 1024;
 MAX_FIND_RESULTS      = 4096;

 { Taille du tampon generique }
 BUFFER_SIZE           = 65536;

 { Barre d outils }
 MAX_TOOLBAR_BUTTONS   = 24;
 TOOLTIP_DELAY         = 500;     { delai infobulle en ms          }
 ICON_SIZE             = 16;      { taille d une icone en pixels   }
 TOOLBTN_WIDTH         = 24;      { largeur d un bouton            }
 TOOLBTN_HEIGHT        = 24;      { hauteur d un bouton            }
 TOOLSEP_WIDTH         = 8;       { largeur d un separateur        }

 { Coloration syntaxique C# }
 MAX_CSHARP_KEYWORDS   = 79;      { nombre de mots-cles C#         }
 MAX_CSHARP_CTXKW      = 28;      { nombre de mots-cles contextuels}

 { Coloration syntaxique VB.NET }
 MAX_VBNET_KEYWORDS    = 152;     { nombre de mots-cles VB.NET     }

 { Coloration syntaxique Pascal }
 MAX_PASCAL_KEYWORDS   = 65;      { nombre de mots-cles Pascal     }

 { Parseur de fichiers solution }
 MAX_SOLUTION_CONFIGS  = 10;      { nombre max de configurations   }
 MAX_DEPENDENCIES      = 20;      { nombre max de dependances      }
 SLN_FORMAT_VERSION    = '12.00'; { version du format solution     }
 SLN_VS_VERSION        = 'Visual Studio Version 17';
 SLN_MIN_VS_VERSION    = '10.0.40219.1';
 GUID_CSHARP           = '{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}';
 GUID_VBNET            = '{F184B08F-C81C-45F6-A57F-5ABD9991F28F}';
 GUID_PASCAL           = '{00000000-0000-0000-0000-000000000001}';

 { Parseur de fichiers projet }
 MAX_PROJECT_REFS      = 64;       { nombre max de references       }
 MAX_BUILD_CONFIGS     = 10;       { nombre max de configs build    }

 { Explorateur de solution }
 EXPLORER_WIDTH        = 220;      { largeur du panneau en pixels   }
 EXPLORER_MIN_WIDTH    = 100;      { largeur minimale en pixels     }
 EXPLORER_MAX_WIDTH    = 400;      { largeur maximale en pixels     }
 EXPLORER_NODE_HEIGHT  = 20;       { hauteur d un noeud en pixels   }
 EXPLORER_INDENT       = 16;       { indentation par niveau         }
 EXPLORER_ICON_SIZE    = 16;       { taille des icones              }
 EXPLORER_SCROLL_STEP  = 3;        { pas de defilement              }
 SPLITTER_WIDTH        = 4;        { largeur du splitter vertical   }
 MAX_EXPLORER_NODES    = 512;      { nombre max de noeuds           }

 { Panneau de proprietes }
 PROPS_PANEL_HEIGHT    = 200;      { hauteur du panneau en pixels   }
 PROPS_MIN_HEIGHT      = 80;       { hauteur minimale en pixels     }
 PROPS_MAX_HEIGHT      = 400;      { hauteur maximale en pixels     }
 PROPS_ROW_HEIGHT      = 20;       { hauteur d une ligne            }
 PROPS_NAME_WIDTH      = 120;      { largeur de la colonne nom      }
 PROPS_SCROLL_STEP     = 3;        { pas de defilement              }
 MAX_PROPERTIES        = 32;       { nombre max de proprietes       }
 PROPS_HEADER_HEIGHT   = 22;       { hauteur de l en-tete           }
 PROPS_SPLITTER_HEIGHT = 4;        { hauteur du splitter horizontal }

 { Panneau de sortie (output) }
 OUTPUT_MIN_HEIGHT     = 60;       { hauteur minimale en pixels     }
 OUTPUT_MAX_HEIGHT     = 400;      { hauteur maximale en pixels     }
 OUTPUT_TAB_HEIGHT     = 22;       { hauteur des onglets            }
 OUTPUT_LINE_HEIGHT    = 16;       { hauteur d une ligne de texte   }
 OUTPUT_SCROLL_STEP    = 3;        { pas de defilement              }
 MAX_OUTPUT_LINES      = 1024;     { nombre max de lignes           }
 OUTPUT_SPLITTER_HEIGHT= 4;        { hauteur du splitter horizontal }
 OUTPUT_TAB_COUNT      = 3;        { nombre d onglets               }

 { Panneau de liste d erreurs }
 ERRLIST_MIN_HEIGHT    = 60;       { hauteur minimale en pixels     }
 ERRLIST_MAX_HEIGHT    = 400;      { hauteur maximale en pixels     }
 ERRLIST_HEADER_HEIGHT = 26;       { hauteur de l en-tete (filtres) }
 ERRLIST_ROW_HEIGHT    = 18;       { hauteur d une ligne            }
 ERRLIST_SCROLL_STEP   = 3;        { pas de defilement              }
 ERRLIST_SPLITTER_HEIGHT = 4;      { hauteur du splitter            }
 ERRLIST_COL_COUNT     = 6;        { nombre de colonnes             }
 MAX_ERROR_ENTRIES     = 1024;     { nombre max d entrees           }
 ERRLIST_SEV_WIDTH     = 24;       { largeur icone severite         }
 ERRLIST_CODE_WIDTH    = 70;       { largeur colonne code           }
 ERRLIST_LINE_WIDTH    = 50;       { largeur colonne ligne          }
 ERRLIST_FILE_WIDTH    = 160;      { largeur colonne fichier        }
 ERRLIST_PROJECT_WIDTH = 120;      { largeur colonne projet         }

 { Boites de dialogue }
 DLG_MIN_WIDTH         = 300;     { largeur minimale dialogue       }
 DLG_MIN_HEIGHT        = 150;     { hauteur minimale dialogue       }
 DLG_BORDER            = 2;       { epaisseur bordure dialogue      }
 DLG_TITLE_HEIGHT      = 22;      { hauteur barre de titre          }
 DLG_BUTTON_WIDTH      = 80;      { largeur bouton OK/Annuler       }
 DLG_BUTTON_HEIGHT     = 24;      { hauteur bouton OK/Annuler       }
 DLG_BUTTON_SPACING    = 10;      { espacement entre boutons        }
 DLG_PADDING           = 10;      { marge interne du dialogue       }
 DLG_INPUT_HEIGHT      = 20;      { hauteur champ de saisie         }
 DLG_LIST_ROW_HEIGHT   = 18;      { hauteur ligne dans liste        }
 DLG_FILTER_HEIGHT     = 20;      { hauteur du sélecteur de filtre  }
 DLG_ICON_SIZE         = 32;      { taille icone message box        }
 MAX_DLG_FILES         = 512;     { nombre max fichiers liste       }
 MAX_DLG_FILTERS       = 10;      { nombre max filtres              }
 DLG_FILE_WIDTH        = 480;     { largeur boite fichier           }
 DLG_FILE_HEIGHT       = 360;     { hauteur boite fichier           }
 DLG_MSG_WIDTH         = 360;     { largeur message box             }
 DLG_MSG_HEIGHT        = 160;     { hauteur message box             }
 DLG_INPUT_WIDTH       = 340;     { largeur input box               }
 DLG_INPBOX_HEIGHT     = 140;     { hauteur input box               }
 DLG_FOLDER_WIDTH      = 400;     { largeur boite dossier           }
 DLG_FOLDER_HEIGHT     = 320;     { hauteur boite dossier           }

 { Boutons de message box }
 MB_OK                 = 0;       { bouton OK seulement             }
 MB_OKCANCEL           = 1;       { boutons OK et Annuler           }
 MB_YESNO              = 2;       { boutons Oui et Non              }
 MB_YESNOCANCEL        = 3;       { boutons Oui, Non et Annuler     }

 { Icones de message box }
 MI_INFO               = 0;       { icone information               }
 MI_WARNING            = 1;       { icone avertissement             }
 MI_ERROR              = 2;       { icone erreur                    }
 MI_QUESTION           = 3;       { icone question                  }

 { Resultats de dialogue }
 DR_OK                 = 1;       { bouton OK appuye                }
 DR_CANCEL             = 2;       { bouton Annuler appuye           }
 DR_YES                = 3;       { bouton Oui appuye               }
 DR_NO                 = 4;       { bouton Non appuye               }
 DR_NONE               = 0;       { aucun resultat                  }

 { Boites de dialogue projet/solution }
 NEWPROJ_WIDTH         = 520;     { largeur dialogue nouveau projet }
 NEWPROJ_HEIGHT        = 340;     { hauteur dialogue nouveau projet }
 NEWPROJ_TYPE_COUNT    = 5;       { nombre de types de projet       }
 NEWPROJ_LIST_HEIGHT   = 120;     { hauteur liste des types         }
 NEWFILE_WIDTH         = 420;     { largeur dialogue nouveau fichier}
 NEWFILE_HEIGHT        = 280;     { hauteur dialogue nouveau fichier}
 NEWFILE_TYPE_COUNT    = 5;       { nombre de types de fichier      }
 NEWFILE_LIST_HEIGHT   = 100;     { hauteur liste des types         }
 ADDREF_WIDTH          = 480;     { largeur dialogue references     }
 ADDREF_HEIGHT         = 360;     { hauteur dialogue references     }
 ADDREF_TAB_COUNT      = 3;       { nombre d onglets                }
 MAX_ADDREF_ITEMS      = 64;      { nombre max d items references   }
 PROJPROP_WIDTH        = 560;     { largeur dialogue proprietes     }
 PROJPROP_HEIGHT       = 400;     { hauteur dialogue proprietes     }
 PROJPROP_TAB_COUNT    = 4;       { nombre d onglets proprietes     }
 PROJPROP_LABEL_WIDTH  = 160;     { largeur etiquette propriete     }
 PROJPROP_FIELD_HEIGHT = 22;      { hauteur champ de saisie         }
 PROJPROP_ROW_SPACING  = 28;      { espacement vertical entre champs}

 { Boite de dialogue des options de l IDE }
 OPT_DLG_WIDTH        = 620;     { largeur dialogue options         }
 OPT_DLG_HEIGHT       = 440;     { hauteur dialogue options         }
 OPT_TREE_WIDTH       = 200;     { largeur arbre de categories      }
 OPT_TREE_NODE_HEIGHT = 20;      { hauteur noeud arbre              }
 OPT_TREE_INDENT      = 16;      { indentation noeuds enfants       }
 OPT_PANEL_PADDING    = 12;      { marge dans le panneau parametres }
 OPT_FIELD_HEIGHT     = 22;      { hauteur champ de saisie          }
 OPT_LABEL_WIDTH      = 180;     { largeur etiquette                }
 OPT_ROW_SPACING      = 28;      { espacement vertical entre lignes }
 OPT_CHECK_SIZE       = 14;      { taille case a cocher             }
 MAX_OPT_CATEGORIES   = 16;      { nombre max de categories         }
 MAX_OPT_PAGES        = 16;      { nombre max de pages              }
 OPT_CFG_FILENAME     = 'DEVENV.CFG'; { fichier de configuration    }

 { Rechercher et remplacer }
 FIND_DLG_WIDTH       = 420;     { largeur dialogue recherche       }
 FIND_DLG_HEIGHT      = 200;     { hauteur dialogue recherche       }
 REPLACE_DLG_HEIGHT   = 260;     { hauteur dialogue remplacement    }
 FIND_FIELD_WIDTH     = 280;     { largeur champ de saisie          }
 FIND_FIELD_HEIGHT    = 22;      { hauteur champ de saisie          }
 FIND_LABEL_WIDTH     = 100;     { largeur etiquette                }
 FIND_BTN_WIDTH       = 100;     { largeur bouton                   }
 FIND_BTN_HEIGHT      = 24;      { hauteur bouton                   }
 FIND_PADDING         = 10;      { marge interieure                 }
 FIND_CHECK_SIZE      = 14;      { taille case a cocher             }
 GOTO_DLG_WIDTH       = 300;     { largeur dialogue aller a ligne   }
 GOTO_DLG_HEIGHT      = 140;     { hauteur dialogue aller a ligne   }
 MAX_FIND_HIGHLIGHTS  = 256;     { nombre max de surbrillances      }

 { Integration compilateur C# }
 CSC_COMPILER_WIN32   = 'CSCW32';   { compilateur C# Win32 PE        }
 CSC_COMPILER_DOS     = 'CSC86';    { compilateur C# DOS 8086        }
 CSC_TEMP_OUTPUT      = '_cscout.tmp'; { fichier temp sortie compil  }
 CSC_MAX_SOURCE_FILES = 128;        { nombre max fichiers source     }
 CSC_FLAG_VERBOSE     = '-v';       { option verbeux                 }
 CSC_FLAG_DEBUG       = '-d';       { option symboles debogage       }
 CSC_FLAG_WARNINGS    = '-w';       { option afficher avertissements }
 CSC_FLAG_OUTPUT      = '-o';       { option fichier sortie          }
 CSC_EXT_SOURCE       = '.cs';      { extension source C#            }
 CSC_EXT_EXE          = '.exe';     { extension executable           }
 CSC_EXT_DLL          = '.dll';     { extension bibliotheque         }

 { Integration compilateur VB.NET }
 VBC_COMPILER_WIN32   = 'VBCW32';   { compilateur VB.NET Win32 PE    }
 VBC_COMPILER_DOS     = 'VBC86';    { compilateur VB.NET DOS 8086    }
 VBC_TEMP_OUTPUT      = '_vbcout.tmp'; { fichier temp sortie compil  }
 VBC_MAX_SOURCE_FILES = 128;        { nombre max fichiers source     }
 VBC_FLAG_VERBOSE     = '-v';       { option verbeux                 }
 VBC_FLAG_DEBUG       = '-d';       { option symboles debogage       }
 VBC_FLAG_WARNINGS    = '-w';       { option afficher avertissements }
 VBC_FLAG_OUTPUT      = '-o';       { option fichier sortie          }
 VBC_EXT_SOURCE       = '.vb';      { extension source VB.NET        }
 VBC_EXT_EXE          = '.exe';     { extension executable           }
 VBC_EXT_DLL          = '.dll';     { extension bibliotheque         }

 { Integration compilateur Pascal }
 TPC_COMPILER_WIN32   = 'TPCW32';   { compilateur Pascal Win32 PE    }
 TPC_COMPILER_DOS     = 'VAXPAS86'; { compilateur Pascal DOS 8086    }
 TPC_COMPILER_WIN32B  = 'VAXPCW32'; { compilateur Pascal Win32 alter }
 TPC_TEMP_OUTPUT      = '_tpcout.tmp'; { fichier temp sortie compil  }
 TPC_MAX_SOURCE_FILES = 128;        { nombre max fichiers source     }
 TPC_FLAG_VERBOSE     = '-v';       { option verbeux                 }
 TPC_FLAG_DEBUG       = '-d';       { option symboles debogage       }
 TPC_FLAG_WARNINGS    = '-w';       { option afficher avertissements }
 TPC_FLAG_OUTPUT      = '-o';       { option fichier sortie          }
 TPC_EXT_SOURCE       = '.pas';     { extension source Pascal        }
 TPC_EXT_EXE          = '.exe';     { extension executable           }
 TPC_EXT_DLL          = '.dll';     { extension bibliotheque         }

 { Systeme de build et configuration }
 BUILD_MAX_ORDER       = 64;       { nombre max projets dans l ordre }
 BUILD_CFG_DLG_WIDTH   = 400;      { largeur dialogue configuration  }
 BUILD_CFG_DLG_HEIGHT  = 300;      { hauteur dialogue configuration  }
 BUILD_CFG_ROW_HEIGHT  = 22;       { hauteur d une ligne config      }
 BUILD_CFG_COL_WIDTH   = 150;      { largeur colonne configuration   }
 BUILD_CFG_PADDING     = 8;        { marge interieure dialogue       }
 MAX_BUILD_RESULTS     = 64;       { nombre max de resultats build   }

 { Points d arret et debogage }
 BP_MARKER_SIZE        = 10;       { taille du marqueur (pixels)     }
 BP_MARKER_COLOR       = 4;        { couleur du marqueur (rouge)     }
 BP_DISABLED_COLOR     = 8;        { couleur marqueur desactive      }
 DEBUG_PANEL_WIDTH     = 300;      { largeur panneau debogage        }
 DEBUG_PANEL_HEIGHT    = 200;      { hauteur panneau debogage        }
 DEBUG_PANEL_ROW_HEIGHT= 20;       { hauteur d une ligne panneau     }
 DEBUG_PANEL_PADDING   = 6;        { marge interieure panneau        }

 { Barre d etat, integration finale et polissage }
 STATUS_BAR_PADDING    = 6;        { marge interieure barre etat    }
 STATUS_BAR_SEP_WIDTH  = 1;        { largeur separateur             }
 STATUS_BAR_FIELD_GAP  = 12;       { espacement entre champs        }
 MRU_MAX_ENTRIES       = 16;       { nombre max de fichiers recents }
 MRU_FILENAME          = 'DEVENV.MRU'; { fichier MRU                }
 START_PAGE_TITLE_Y    = 40;       { position Y du titre            }
 START_PAGE_LIST_Y     = 100;      { position Y de la liste         }
 START_PAGE_BTN_Y      = 60;       { position Y des boutons         }
 START_PAGE_BTN_WIDTH  = 140;      { largeur bouton demarrage       }
 START_PAGE_BTN_HEIGHT = 28;       { hauteur bouton demarrage       }
 START_PAGE_ITEM_HEIGHT= 20;       { hauteur element liste recents  }
 IDE_VERSION           = '1.0.0';  { version de l IDE               }

 { Onglets de fenetres d edition }
 TAB_HEIGHT            = 22;      { hauteur d un onglet            }
 TAB_MAX_WIDTH         = 160;     { largeur max d un onglet        }
 TAB_CLOSE_SIZE        = 12;      { taille bouton fermeture (X)    }
 TAB_PADDING           = 8;       { marge interne d un onglet      }

 { Dimensions de l interface en pixels }
 TOOLBAR_HEIGHT        = 28;
 MENUBAR_HEIGHT        = 20;
 STATUSBAR_HEIGHT      = 20;
 OUTPUT_HEIGHT         = 150;

 { Codes de retour }
 EXIT_OK               = 0;
 EXIT_ERROR            = 1;
 EXIT_USAGE            = 2;

 { Couleurs du theme Visual Studio (palette VGA 16 couleurs) }
 CLR_BACKGROUND        = 7;    { gris clair : fond general           }
 CLR_TITLEBAR          = 8;    { gris fonce : barre de titre inactive}
 CLR_TITLEBAR_ACTIVE   = 1;    { bleu : barre de titre active        }
 CLR_MENUBAR           = 7;    { gris clair : barre de menus         }
 CLR_MENU_HIGHLIGHT    = 1;    { bleu : element de menu survole      }
 CLR_MENU_TEXT         = 0;    { noir : texte des menus              }
 CLR_TOOLBAR           = 7;    { gris clair : barre d outils         }
 CLR_EDITOR_BG         = 15;   { blanc : fond de l editeur           }
 CLR_EDITOR_TEXT       = 0;    { noir : texte de l editeur           }
 CLR_EDITOR_GUTTER     = 7;    { gris clair : gouttiere (numeros)    }
 CLR_EXPLORER_BG       = 7;    { gris clair : explorateur de solution}
 CLR_OUTPUT_BG         = 15;   { blanc : panneau de sortie           }
 CLR_STATUSBAR         = 1;    { bleu : barre d etat                 }
 CLR_SCROLLBAR         = 7;    { gris clair : barre de defilement    }
 CLR_SELECTION         = 1;    { bleu : texte selectionne            }
 CLR_CURSOR            = 0;    { noir : curseur de texte             }
 CLR_LINE_HIGHLIGHT    = 14;   { jaune : ligne courante              }
 CLR_BORDER            = 8;    { gris fonce : bordures               }
 CLR_WINDOW            = 15;   { blanc : fond de fenetre/dialogue     }
 CLR_WINDOWTEXT        = 0;    { noir : texte de fenetre/dialogue     }
 CLR_HIGHLIGHT         = 1;    { bleu : element selectionne           }
 CLR_HIGHLIGHTTEXT     = 15;   { blanc : texte element selectionne    }
 CLR_BTNFACE           = 7;    { gris clair : face de bouton          }
 CLR_GRAYTEXT          = 8;    { gris fonce : texte desactive         }

{ ============================================================
  TYPES
  ============================================================ }
Type
 TString = String;

 { Options de l IDE }
 TDevEnvOptions = Record
  SolutionFile    : TString;   { fichier .sln a ouvrir              }
  Verbose         : Boolean;   { -v : mode verbeux                  }
  DebugMode       : Boolean;   { -d : mode debogage interne         }
  ThemeName       : TString;   { nom du theme de couleurs           }
  FontSize        : Integer;   { taille de la police en pixels      }
  TabSize         : Integer;   { nombre d espaces par tabulation    }
  AutoSave        : Boolean;   { sauvegarde automatique             }
  ShowLineNumbers : Boolean;   { afficher les numeros de ligne      }
  WordWrap        : Boolean;   { retour a la ligne automatique      }
  AutoIndent      : Boolean;   { indentation automatique            }
  ShowWhitespace  : Boolean;   { afficher les espaces et tabs       }
 End;

 { Types d evenements }
 TEventKind = (
  EV_NONE,             { aucun evenement                     }
  EV_MOUSE_MOVE,       { deplacement de la souris            }
  EV_MOUSE_DOWN,       { bouton souris enfonce               }
  EV_MOUSE_UP,         { bouton souris relache               }
  EV_MOUSE_DBLCLICK,   { double-clic                         }
  EV_KEY_DOWN,         { touche speciale (code etendu)       }
  EV_KEY_CHAR,         { caractere clavier                   }
  EV_TIMER,            { evenement temporel                  }
  EV_RESIZE,           { redimensionnement                   }
  EV_CLOSE             { fermeture demandee                  }
 );

 TMouseButton = (
  MB_NONE,             { aucun bouton                        }
  MB_LEFT,             { bouton gauche                       }
  MB_RIGHT,            { bouton droit                        }
  MB_MIDDLE            { bouton central                      }
 );

 { Enregistrement d evenement }
 TEvent = Record
  Kind       : TEventKind;   { type de l evenement            }
  MouseX     : Integer;      { position X de la souris        }
  MouseY     : Integer;      { position Y de la souris        }
  MouseBtn   : TMouseButton; { bouton souris concerne         }
  KeyCode    : Word;         { code etendu de la touche       }
  KeyChar    : Char;         { caractere ASCII                }
  ShiftState : Word;         { etat des modificateurs         }
  Timestamp  : LongInt;      { horodatage en millisecondes    }
 End;

 { File circulaire d evenements }
 TEventQueue = Record
  Items : Array[0..255] Of TEvent;  { 256 entrees           }
  Head  : Byte;                     { indice de lecture      }
  Tail  : Byte;                     { indice d ecriture     }
  Count : Integer;                  { nombre d elements     }
 End;

 { Types de widgets }
 TWidgetKind = (
  WK_PANEL,            { conteneur rectangulaire             }
  WK_LABEL,            { texte statique                      }
  WK_BUTTON,           { bouton cliquable                    }
  WK_CHECKBOX,         { case a cocher                       }
  WK_RADIOBUTTON,      { bouton radio                        }
  WK_EDITFIELD,        { champ de saisie une ligne           }
  WK_LISTBOX,          { liste avec defilement               }
  WK_COMBOBOX,         { saisie avec liste deroulante        }
  WK_SCROLLBAR,        { barre de defilement                 }
  WK_PROGRESSBAR,      { barre de progression                }
  WK_SPLITTER,         { separateur redimensionnable         }
  WK_TREEVIEW,         { arbre hierarchique                  }
  WK_TABCONTROL        { onglets                             }
 );

 TWidgetState = (
  WS_NORMAL,           { etat normal                         }
  WS_HOVER,            { souris au-dessus                    }
  WS_PRESSED,          { bouton enfonce                      }
  WS_DISABLED          { desactive                           }
 );

 PWidget = ^TWidget;

 { Widget de base }
 TWidget = Record
  Kind       : TWidgetKind;   { type du widget                 }
  X          : Integer;       { position X en pixels           }
  Y          : Integer;       { position Y en pixels           }
  Width      : Integer;       { largeur en pixels              }
  Height     : Integer;       { hauteur en pixels              }
  Visible    : Boolean;       { visible ou non                 }
  Enabled    : Boolean;       { actif ou non                   }
  Focused    : Boolean;       { a le focus clavier             }
  Parent     : PWidget;       { widget parent (nil = racine)   }
  Tag        : LongInt;       { valeur utilisateur             }
  Name       : String[63];    { nom du widget                  }
  State      : TWidgetState;  { etat visuel courant            }
  NeedRepaint: Boolean;       { doit etre redessine            }
  { Donnees specifiques aux types de widgets }
  Caption    : String[127];   { texte (label, bouton, etc.)    }
  Checked    : Boolean;       { coche (checkbox, radio)        }
  GroupID    : Integer;       { groupe radio d exclusion       }
  TextBuf    : String[255];   { tampon texte (editfield)       }
  CursorPos  : Integer;       { position curseur (editfield)   }
  ItemCount  : Integer;       { nombre d items (list/combo)    }
  SelIndex   : Integer;       { index selectionne (list/combo) }
  ScrollPos  : Integer;       { position defilement            }
  ScrollMax  : Integer;       { valeur max de defilement       }
  Horizontal : Boolean;       { orientation scrollbar/splitter }
  Progress   : Integer;       { valeur 0..100 (progressbar)    }
  TabCount   : Integer;       { nombre d onglets (tabcontrol)  }
  ActiveTab  : Integer;       { onglet actif (tabcontrol)      }
  Expanded   : Boolean;       { noeud deplie (treeview)        }
  TreeRoot   : Integer;       { index racine (treeview)        }
  ShowBorder : Boolean;       { afficher la bordure (panel)    }
  BgColor    : Integer;       { couleur de fond                }
  FgColor    : Integer;       { couleur du texte               }
 End;

 { Noeud d arbre pour TTreeView }
 PTreeNode = ^TTreeNode;
 TTreeNode = Record
  Caption    : String[127];   { texte du noeud                 }
  ParentIdx  : Integer;       { index du parent (-1 = racine)  }
  Expanded   : Boolean;       { noeud deplie                   }
  Level      : Integer;       { profondeur dans l arbre        }
  IconIndex  : Integer;       { index d icone                  }
  Tag        : LongInt;       { valeur utilisateur             }
 End;

 { Element de menu }
 PMenuItem = ^TMenuItem;
 TMenuItem = Record
  Caption    : String[63];    { texte de l element              }
  ShortCut   : String[15];    { raccourci clavier affiche       }
  Enabled    : Boolean;       { actif ou grise                  }
  Checked    : Boolean;       { coche devant l element          }
  Separator  : Boolean;       { barre de separation             }
  Tag        : LongInt;       { identifiant de commande         }
  IconIndex  : Integer;       { index d icone (futur)           }
 End;

 { Menu deroulant }
 PMenu = ^TMenu;
 TMenu = Record
  Title      : String[31];    { titre affiche dans la barre     }
  Items      : Array[0..MAX_MENU_ITEMS - 1] Of TMenuItem;
  ItemCount  : Integer;       { nombre d elements               }
  X          : Integer;       { position X du menu ouvert       }
  Width      : Integer;       { largeur du menu ouvert          }
 End;

 { Barre de menus }
 TMenuBar = Record
  Menus      : Array[0..MAX_MENUS - 1] Of TMenu;
  MenuCount  : Integer;       { nombre de menus                 }
  Y          : Integer;       { position Y (0 = haut)           }
  Height     : Integer;       { hauteur de la barre             }
 End;

 { Icone 16x16 }
 TIcon16 = Array[0..15, 0..15] Of Byte;

 { Etat d un bouton de barre d outils }
 TToolBtnState = (
  TB_NORMAL,              { etat normal                         }
  TB_HOVER,               { souris au-dessus                    }
  TB_PRESSED,             { bouton enfonce                      }
  TB_DISABLED             { desactive                           }
 );

 { Bouton de barre d outils }
 TToolButton = Record
  Icon       : TIcon16;       { matrice 16x16 de pixels         }
  Tooltip    : String[63];    { texte de l infobulle            }
  Tag        : LongInt;       { identifiant de commande         }
  Enabled    : Boolean;       { actif ou grise                  }
  Separator  : Boolean;       { separateur (pas un bouton)      }
  State      : TToolBtnState; { etat visuel courant             }
  X          : Integer;       { position X calculee             }
 End;

 { Barre d outils }
 TToolBar = Record
  Buttons    : Array[0..MAX_TOOLBAR_BUTTONS - 1] Of TToolButton;
  BtnCount   : Integer;       { nombre de boutons               }
  Y          : Integer;       { position Y                      }
  Height     : Integer;       { hauteur de la barre             }
 End;

 { Fenetre d editeur }
 PEditorWindow = ^TEditorWindow;
 TEditorWindow = Record
  Title      : String[127];   { titre affiche dans l onglet     }
  FileName   : String[255];   { chemin complet du fichier       }
  Modified   : Boolean;       { fichier modifie                 }
  X          : Integer;       { position X dans la zone MDI     }
  Y          : Integer;       { position Y dans la zone MDI     }
  Width      : Integer;       { largeur en pixels               }
  Height     : Integer;       { hauteur en pixels               }
  ScrollX    : LongInt;       { defilement horizontal           }
  ScrollY    : LongInt;       { defilement vertical             }
  CursorX    : LongInt;       { colonne du curseur              }
  CursorY    : LongInt;       { ligne du curseur                }
  SelStartX  : LongInt;       { debut de selection (colonne)    }
  SelStartY  : LongInt;       { debut de selection (ligne)      }
  SelEndX    : LongInt;       { fin de selection (colonne)      }
  SelEndY    : LongInt;       { fin de selection (ligne)        }
  TabIndex   : Integer;       { index dans la barre d onglets   }
  Visible    : Boolean;       { fenetre visible                 }
  Minimized  : Boolean;       { fenetre minimisee               }
  Maximized  : Boolean;       { fenetre maximisee               }
 End;

 { Gestionnaire de fenetres }
 TWindowManager = Record
  Windows    : Array[0..MAX_WINDOWS - 1] Of TEditorWindow;
  WinCount   : Integer;       { nombre de fenetres ouvertes     }
  ActiveIdx  : Integer;       { index de la fenetre active      }
  TabScrollX : Integer;       { defilement des onglets          }
  SplitMode  : Boolean;       { vue fractionnee active          }
  SplitPos   : Integer;       { position du separateur (pixels) }
 End;

 { Type de fin de ligne }
 TLineEnding = (
  LE_CRLF,              { Windows (CR+LF)                      }
  LE_LF,                { Unix/Linux/macOS (LF)                 }
  LE_CR                  { ancien Mac (CR)                       }
 );

 { Type d encodage de fichier }
 TFileEncoding = (
  FE_ASCII,             { ASCII 7 bits                          }
  FE_UTF8               { UTF-8 (stub, traite comme ASCII)      }
 );

 { Tampon de texte }
 TTextBuffer = Record
  Lines      : Array[0..MAX_LINES - 1] Of String;
  LineCount  : LongInt;        { nombre de lignes en usage      }
  Modified   : Boolean;        { tampon modifie depuis derniere }
                               {   sauvegarde                   }
  FileName   : String[255];    { chemin du fichier associe      }
  Encoding   : TFileEncoding;  { encodage detecte               }
  LineEnd    : TLineEnding;    { type de fin de ligne           }
 End;

 { Editeur de texte }
 TEditor = Record
  Buffer         : TTextBuffer;  { tampon de texte                }
  CursorLine     : LongInt;      { ligne du curseur (0-based)     }
  CursorCol      : LongInt;      { colonne du curseur (1-based)   }
  ScrollLine     : LongInt;      { premiere ligne visible         }
  ScrollCol      : LongInt;      { premiere colonne visible       }
  InsertMode     : Boolean;      { True=insert, False=replace     }
  TabSize        : Integer;      { taille de tabulation (espaces) }
  AutoIndent     : Boolean;      { indentation automatique        }
  ShowLineNumbers: Boolean;      { afficher numeros de ligne      }
  ShowWhitespace : Boolean;      { afficher les espaces/tabs      }
  GutterWidth    : Integer;      { largeur de la gouttiere (px)   }
  CharWidth      : Integer;      { largeur d un caractere (px)    }
  CharHeight     : Integer;      { hauteur d un caractere (px)    }
  VisibleLines   : Integer;      { nombre de lignes visibles      }
  VisibleCols    : Integer;      { nombre de colonnes visibles    }
  X              : Integer;      { position X de la zone editeur  }
  Y              : Integer;      { position Y de la zone editeur  }
  Width          : Integer;      { largeur de la zone editeur     }
  Height         : Integer;      { hauteur de la zone editeur     }
 End;

 { Selection de texte }
 TSelection = Record
  StartLine  : LongInt;         { ligne de debut (0-based)       }
  StartCol   : LongInt;         { colonne de debut (1-based)     }
  EndLine    : LongInt;         { ligne de fin (0-based)         }
  EndCol     : LongInt;         { colonne de fin (1-based)       }
  Active     : Boolean;         { selection en cours              }
 End;

 { Presse-papier interne }
 TClipboard = Record
  Text       : String;          { contenu du presse-papier       }
  HasData    : Boolean;         { True si contient des donnees   }
 End;

 { Type d action d annulation }
 TUndoAction = (
  UA_INSERT,            { insertion de texte                      }
  UA_DELETE,            { suppression de texte                    }
  UA_REPLACE,           { remplacement de texte                   }
  UA_INSERT_LINE,       { insertion d une ligne                   }
  UA_DELETE_LINE,       { suppression d une ligne                 }
  UA_JOIN_LINE,         { jonction de deux lignes                 }
  UA_SPLIT_LINE         { scission d une ligne                    }
 );

 { Enregistrement d une action undo }
 TUndoRecord = Record
  Action     : TUndoAction;     { type d action                  }
  Line       : LongInt;         { ligne concernee (0-based)      }
  Col        : LongInt;         { colonne concernee (1-based)    }
  Text       : String;          { texte insere ou nouveau        }
  OldText    : String;          { texte avant modification       }
  GroupId    : LongInt;         { id de groupe (actions liees)   }
 End;

 { Pile d annulation }
 TUndoStack = Record
  Items      : Array[0..MAX_UNDO - 1] Of TUndoRecord;
  Count      : Integer;         { nombre d elements              }
  Top        : Integer;         { indice sommet (circulaire)     }
 End;

 { Classe de jeton pour la coloration syntaxique }
 TTokenClass = (
  TC_NORMAL,            { texte normal                            }
  TC_KEYWORD,           { mot-cle du langage                      }
  TC_STRING,            { chaine de caracteres                    }
  TC_CHAR,              { caractere litteral                      }
  TC_NUMBER,            { nombre (entier, flottant, hex, etc.)    }
  TC_COMMENT,           { commentaire (ligne ou bloc)             }
  TC_DIRECTIVE,         { directive preprocesseur                 }
  TC_OPERATOR,          { operateur (+, -, =, etc.)               }
  TC_IDENTIFIER,        { identificateur (variable, fonction)     }
  TC_TYPE,              { type predefini (int, string, etc.)      }
  TC_PREPROCESSOR,      { instruction preprocesseur (#if, etc.)   }
  TC_ATTRIBUTE,         { attribut ([Attribute])                  }
  TC_XMLDOC             { commentaire de documentation XML        }
 );

 { Moteur de coloration syntaxique }
 TSyntaxHighlighter = Record
  Language       : String[31];  { nom du langage (C#, VB, Pascal) }
  InBlockComment : Boolean;     { dans un commentaire multi-ligne  }
  InString       : Boolean;     { dans une chaine multi-ligne      }
  StateStack     : Array[0..63] Of Byte; { pile d etats           }
  StateTop       : Integer;     { sommet de la pile d etats        }
 End;

 { Coloration syntaxique specialisee C# }
 TCSharpHighlighter = Record
  Base         : TSyntaxHighlighter;  { moteur de base              }
  Keywords     : Array[0..MAX_CSHARP_KEYWORDS - 1] Of String[15];
  KeywordCount : Integer;             { nombre de mots-cles         }
  CtxKeywords  : Array[0..MAX_CSHARP_CTXKW - 1] Of String[15];
  CtxKWCount   : Integer;             { nombre de mots-cles ctx     }
 End;

 { Coloration syntaxique specialisee VB.NET }
 TVBNetHighlighter = Record
  Base         : TSyntaxHighlighter;  { moteur de base              }
  Keywords     : Array[0..MAX_VBNET_KEYWORDS - 1] Of String[20];
  KeywordCount : Integer;             { nombre de mots-cles         }
 End;

 { Coloration syntaxique specialisee Pascal }
 TPascalHighlighter = Record
  Base         : TSyntaxHighlighter;  { moteur de base              }
  Keywords     : Array[0..MAX_PASCAL_KEYWORDS - 1] Of String[20];
  KeywordCount : Integer;             { nombre de mots-cles         }
 End;

 { Types de projet reconnus }
 TProjectType = (PT_CSHARP, PT_VBNET, PT_PASCAL, PT_UNKNOWN);

 { Informations sur la solution }
 TSolutionInfo = Record
  FormatVersion : String[20];         { version du format           }
  VSVersion     : String[40];         { version de Visual Studio    }
  MinVSVersion  : String[40];         { version minimale VS         }
  GUID          : String[40];         { GUID de la solution         }
  SolutionName  : String[63];         { nom de la solution          }
  SolutionPath  : String[255];        { chemin de la solution       }
 End;

 { Entree de projet dans la solution }
 TProjectEntry = Record
  ProjectTypeGUID : String[40];       { GUID du type de projet      }
  ProjectGUID     : String[40];       { GUID unique du projet       }
  ProjectName     : String[63];       { nom du projet               }
  ProjectPath     : String[255];      { chemin relatif du projet    }
  Dependencies    : Array[0..MAX_DEPENDENCIES - 1] Of String[40];
  DepCount        : Integer;          { nombre de dependances       }
 End;

 { Structure complete de la solution }
 TSolution = Record
  Info         : TSolutionInfo;       { informations globales       }
  Projects     : Array[0..MAX_SOLUTION_PROJECTS - 1] Of TProjectEntry;
  ProjectCount : Integer;             { nombre de projets           }
  Configs      : Array[0..MAX_SOLUTION_CONFIGS - 1] Of String[40];
  ConfigCount  : Integer;             { nombre de configurations    }
 End;

 { Action de build pour un fichier projet }
 TBuildAction = (BA_COMPILE, BA_CONTENT, BA_NONE,
                 BA_EMBEDDED_RESOURCE);

 { Type de sortie du projet }
 TOutputType = (OT_EXE, OT_LIBRARY, OT_WINEXE);

 { Informations sur le projet }
 TProjectInfo = Record
  ProjectName    : String[63];        { nom du projet               }
  RootNamespace  : String[63];        { espace de noms racine       }
  AssemblyName   : String[63];        { nom de l assembly           }
  OutputType     : TOutputType;       { type de sortie              }
  TargetFramework: String[40];        { framework cible             }
  OutputPath     : String[255];       { chemin de sortie            }
  DefineConstants: String[255];       { constantes de compilation   }
  ProjectType    : TProjectType;      { type de projet              }
  ProjectGUID    : String[40];        { GUID du projet              }
 End;

 { Fichier dans le projet }
 TProjectFile = Record
  FileName     : String[255];         { chemin relatif du fichier   }
  BuildAction  : TBuildAction;        { action de build             }
  DependentUpon: String[255];         { fichier parent              }
  SubType      : String[40];          { sous-type (Form, etc.)      }
 End;

 { Reference dans le projet }
 TProjectRef = Record
  ReferenceName: String[63];          { nom de la reference         }
  HintPath     : String[255];         { chemin de la DLL            }
  ProjectGUID  : String[40];          { GUID du projet reference    }
 End;

 { Configuration de build }
 TBuildConfig = Record
  ConfigName   : String[40];          { nom (Debug, Release, etc.)  }
  OutputPath   : String[255];         { chemin de sortie            }
  DefineConst  : String[255];         { constantes de compilation   }
  Optimize     : Boolean;             { optimisation activee        }
  DebugSymbols : Boolean;             { symboles de debogage        }
 End;

 { Structure complete du projet }
 TProject = Record
  Info       : TProjectInfo;          { informations globales       }
  Files      : Array[0..MAX_PROJECT_FILES - 1] Of TProjectFile;
  FileCount  : Integer;               { nombre de fichiers          }
  Refs       : Array[0..MAX_PROJECT_REFS - 1] Of TProjectRef;
  RefCount   : Integer;               { nombre de references        }
  Configs    : Array[0..MAX_BUILD_CONFIGS - 1] Of TBuildConfig;
  CfgCount   : Integer;               { nombre de configurations    }
 End;

 { Type de noeud dans l explorateur de solution }
 TExplorerNodeKind = (
  ENK_SOLUTION,        { noeud racine : solution                 }
  ENK_PROJECT,         { noeud projet                            }
  ENK_PROPERTIES,      { noeud special Properties                }
  ENK_REFERENCES,      { noeud special References                }
  ENK_REFERENCE,       { une reference individuelle              }
  ENK_FOLDER,          { dossier                                 }
  ENK_FILE_CS,         { fichier C# (.cs)                        }
  ENK_FILE_VB,         { fichier VB.NET (.vb)                    }
  ENK_FILE_PAS,        { fichier Pascal (.pas)                   }
  ENK_FILE_OTHER       { autre type de fichier                   }
 );

 { Noeud dans l arbre de l explorateur }
 TExplorerNode = Record
  Caption    : String[127];         { texte affiche                  }
  Kind       : TExplorerNodeKind;   { type de noeud                  }
  ParentIdx  : Integer;             { index du parent (-1 = racine)  }
  Level      : Integer;             { profondeur dans l arbre        }
  Expanded   : Boolean;             { noeud deplie                   }
  Visible    : Boolean;             { visible dans l affichage       }
  Selected   : Boolean;             { noeud selectionne              }
  HasChildren: Boolean;             { possede des enfants            }
  Tag        : LongInt;             { valeur utilisateur             }
 End;

 { Explorateur de solution }
 TSolutionExplorer = Record
  Nodes      : Array[0..MAX_EXPLORER_NODES - 1] Of TExplorerNode;
  NodeCount  : Integer;             { nombre de noeuds               }
  SelectedIdx: Integer;             { index du noeud selectionne     }
  ScrollTop  : Integer;             { premier noeud visible          }
  X          : Integer;             { position X du panneau          }
  Y          : Integer;             { position Y du panneau          }
  Width      : Integer;             { largeur du panneau             }
  Height     : Integer;             { hauteur du panneau             }
  SplitterX  : Integer;             { position X du splitter         }
  Dragging   : Boolean;             { splitter en cours de drag      }
  NeedRepaint: Boolean;             { doit etre redessine            }
 End;

 { Type de source pour le panneau de proprietes }
 TPropertyKind = (
  PK_NONE,             { aucune source                           }
  PK_PROJECT,          { proprietes du projet                    }
  PK_FILE,             { proprietes du fichier                   }
  PK_SOLUTION,         { proprietes de la solution               }
  PK_REFERENCE         { proprietes d une reference              }
 );

 { Mode de tri des proprietes }
 TPropertySort = (
  PS_ALPHABETICAL,     { tri alphabetique                        }
  PS_CATEGORIZED       { tri par categorie                       }
 );

 { Propriete individuelle (nom/valeur) }
 TPropertyItem = Record
  Name       : String[63];           { nom de la propriete            }
  Value      : String[255];          { valeur de la propriete         }
  Category   : String[31];           { categorie (pour tri)           }
  ReadOnly   : Boolean;              { propriete en lecture seule     }
  Editing    : Boolean;              { en cours d edition             }
 End;

 { Panneau de proprietes }
 TPropertiesPanel = Record
  Items      : Array[0..MAX_PROPERTIES - 1] Of TPropertyItem;
  ItemCount  : Integer;              { nombre de proprietes           }
  SelectedIdx: Integer;              { index de la propriete active   }
  ScrollTop  : Integer;              { premiere ligne visible         }
  X          : Integer;              { position X du panneau          }
  Y          : Integer;              { position Y du panneau          }
  Width      : Integer;              { largeur du panneau             }
  Height     : Integer;              { hauteur du panneau             }
  NameColWidth: Integer;             { largeur colonne nom            }
  SplitterY  : Integer;              { position Y du splitter         }
  Dragging   : Boolean;              { splitter en cours de drag      }
  NeedRepaint: Boolean;              { doit etre redessine            }
  SourceKind : TPropertyKind;        { type de source active          }
  SourceTitle: String[63];           { titre de la source             }
  SortMode   : TPropertySort;        { mode de tri                    }
  EditBuffer : String[255];          { tampon d edition temporaire    }
  EditActive : Boolean;              { edition en cours               }
 End;

 { Onglets du panneau de sortie }
 TOutputTabKind = (
  OTK_BUILD,            { sortie de build                     }
  OTK_DEBUG,            { sortie de debogage                  }
  OTK_SEARCH            { resultats de recherche              }
 );

 { Type de ligne de sortie }
 TOutputLineKind = (
  OLK_INFO,             { information (blanc)                 }
  OLK_ERROR,            { erreur (rouge)                      }
  OLK_WARNING,          { avertissement (jaune/orange)        }
  OLK_SUCCESS           { succes (vert)                       }
 );

 { Ligne du panneau de sortie }
 TOutputLine = Record
  Text     : String[255];          { texte de la ligne              }
  Kind     : TOutputLineKind;      { type du message                }
  FileName : String[127];          { fichier source associe         }
  Line     : Integer;              { numero de ligne source         }
  Col      : Integer;              { numero de colonne source       }
 End;

 { Panneau de sortie }
 TOutputPanel = Record
  Lines    : Array[0..MAX_OUTPUT_LINES - 1] Of TOutputLine;
  LineCounts: Array[0..OUTPUT_TAB_COUNT - 1] Of Integer;
  ActiveTab: TOutputTabKind;       { onglet actif                   }
  ScrollTop: Integer;              { premiere ligne visible         }
  SelectedIdx: Integer;            { index de la ligne selectionnee }
  X        : Integer;              { position X du panneau          }
  Y        : Integer;              { position Y du panneau          }
  Width    : Integer;              { largeur du panneau             }
  Height   : Integer;              { hauteur du panneau             }
  SplitterY: Integer;              { position Y du splitter         }
  Dragging : Boolean;              { splitter en cours de drag      }
  Visible  : Boolean;              { panneau visible                }
  NeedRepaint: Boolean;            { doit etre redessine            }
 End;

 { Severite d une erreur }
 TErrorSeverity = (
  ES_ERROR,             { erreur                              }
  ES_WARNING,           { avertissement                       }
  ES_INFO               { message d information               }
 );

 { Colonne de tri de la liste d erreurs }
 TErrorSortColumn = (
  ESC_SEVERITY,         { trier par severite                  }
  ESC_CODE,             { trier par code                      }
  ESC_DESCRIPTION,      { trier par description               }
  ESC_FILE,             { trier par fichier                   }
  ESC_LINE,             { trier par ligne                     }
  ESC_PROJECT           { trier par projet                    }
 );

 { Entree dans la liste d erreurs }
 TErrorEntry = Record
  Severity : TErrorSeverity;       { severite du message            }
  Code     : String[15];           { code d erreur (ex. CS0001)     }
  Description : String[255];       { description du message         }
  FileName : String[127];          { fichier source                 }
  Line     : Integer;              { numero de ligne                }
  Col      : Integer;              { numero de colonne              }
  Project  : String[63];           { nom du projet                  }
 End;

 { Panneau de liste d erreurs }
 TErrorListPanel = Record
  Entries  : Array[0..MAX_ERROR_ENTRIES - 1] Of TErrorEntry;
  Count    : Integer;              { nombre d entrees               }
  SelectedIdx: Integer;            { index selectionne              }
  ScrollTop: Integer;              { premiere ligne visible         }
  SortColumn: TErrorSortColumn;    { colonne de tri active          }
  SortAscending: Boolean;          { tri ascendant                  }
  ShowErrors: Boolean;             { afficher les erreurs           }
  ShowWarnings: Boolean;           { afficher les avertissements    }
  ShowInfos: Boolean;              { afficher les messages          }
  X        : Integer;              { position X du panneau          }
  Y        : Integer;              { position Y du panneau          }
  Width    : Integer;              { largeur du panneau             }
  Height   : Integer;              { hauteur du panneau             }
  SplitterY: Integer;              { position Y du splitter         }
  Dragging : Boolean;              { splitter en cours de drag      }
  Visible  : Boolean;              { panneau visible                }
  NeedRepaint: Boolean;            { doit etre redessine            }
 End;

 { Boutons de message box }
 TMessageButtons = Integer;       { MB_OK, MB_OKCANCEL, etc.       }

 { Icone de message box }
 TMessageIcon = Integer;          { MI_INFO, MI_WARNING, etc.      }

 { Dialogue de base }
 TDialog = Record
  Title    : String[127];            { titre du dialogue              }
  X        : Integer;                { position X (centree)           }
  Y        : Integer;                { position Y (centree)           }
  Width    : Integer;                { largeur du dialogue            }
  Height   : Integer;                { hauteur du dialogue            }
  Result   : Integer;                { resultat (DR_OK, DR_CANCEL..) }
  Visible  : Boolean;                { dialogue affiche               }
  HasCancel: Boolean;                { bouton Annuler present         }
 End;

 { Entree de fichier dans la liste }
 TFileListEntry = Record
  Name     : String[63];            { nom du fichier ou dossier      }
  IsDir    : Boolean;               { True si c est un repertoire    }
  Size     : LongInt;               { taille en octets               }
 End;

 { Filtre de fichier }
 TFileFilter = Record
  Description: String[63];          { ex. 'Fichiers C# (*.cs)'      }
  Pattern  : String[31];            { ex. '*.cs'                     }
 End;

 { Boite de dialogue fichier (ouvrir/enregistrer) }
 TFileDialog = Record
  Base     : TDialog;               { dialogue de base               }
  CurrentPath: String[255];         { repertoire courant             }
  SelectedFile: String[255];        { fichier selectionne            }
  FileList : Array[0..MAX_DLG_FILES - 1] Of TFileListEntry;
  FileCount: Integer;               { nombre d entrees               }
  Filters  : Array[0..MAX_DLG_FILTERS - 1] Of TFileFilter;
  FilterCount: Integer;             { nombre de filtres              }
  FilterIndex: Integer;             { filtre actif                   }
  ScrollTop: Integer;               { premiere ligne visible         }
  SelIndex : Integer;               { index selectionne dans liste   }
  InputText: String[127];           { champ de saisie nom fichier    }
  InputCursor: Integer;             { position curseur saisie        }
  IsSaveMode: Boolean;              { True = enregistrer, False = ouvrir }
 End;

 { Boite de dialogue dossier }
 TFolderDialog = Record
  Base     : TDialog;               { dialogue de base               }
  CurrentPath: String[255];         { repertoire courant             }
  SelectedFolder: String[255];      { dossier selectionne            }
  FileList : Array[0..MAX_DLG_FILES - 1] Of TFileListEntry;
  FileCount: Integer;               { nombre d entrees               }
  ScrollTop: Integer;               { premiere ligne visible         }
  SelIndex : Integer;               { index selectionne dans liste   }
 End;

 { Boite de message }
 TMessageBoxDlg = Record
  Base     : TDialog;               { dialogue de base               }
  Text     : String[255];           { texte du message               }
  Buttons  : TMessageButtons;       { type de boutons                }
  Icon     : TMessageIcon;          { type d icone                   }
  FocusBtn : Integer;               { bouton avec le focus           }
 End;

 { Boite de saisie }
 TInputBox = Record
  Base     : TDialog;               { dialogue de base               }
  Prompt   : String[127];           { texte d invite                 }
  InputText: String[255];           { texte saisi                    }
  InputCursor: Integer;             { position curseur               }
  Cancelled: Boolean;               { True si annule                 }
 End;

 { Type de nouveau projet }
 TNewProjectType = (
  NPT_CONSOLE_CS,      { Application console C#                  }
  NPT_CONSOLE_VB,      { Application console VB.NET              }
  NPT_CONSOLE_PAS,     { Application console Pascal              }
  NPT_LIBRARY_CS,      { Bibliotheque de classes C#              }
  NPT_LIBRARY_VB       { Bibliotheque de classes VB.NET          }
 );

 { Type de nouveau fichier }
 TNewFileType = (
  NFT_CLASS_CS,        { Classe C# (.cs)                         }
  NFT_MODULE_VB,       { Module VB.NET (.vb)                     }
  NFT_UNIT_PAS,        { Unite Pascal (.pas)                     }
  NFT_TEXT,            { Fichier texte (.txt)                    }
  NFT_XML              { Fichier XML (.xml)                      }
 );

 { Onglet du dialogue d ajout de reference }
 TRefTabKind = (
  RTK_ASSEMBLIES,      { onglet Assemblies                       }
  RTK_PROJECTS,        { onglet Projets                          }
  RTK_BROWSE           { onglet Parcourir                        }
 );

 { Onglet du dialogue proprietes de projet }
 TProjPropTab = (
  PPT_APPLICATION,     { onglet Application                      }
  PPT_BUILD,           { onglet Build                            }
  PPT_BUILD_EVENTS,    { onglet Build Events                     }
  PPT_DEBUG            { onglet Debug                            }
 );

 { Entree de reference dans la liste }
 TRefListEntry = Record
  Name     : String[63];            { nom de la reference            }
  Version  : String[31];            { version de l assembly          }
  Path     : String[255];           { chemin du fichier              }
  Checked  : Boolean;               { case cochee                    }
  IsProject: Boolean;               { True si reference projet       }
 End;

 { Boite de dialogue Nouveau projet }
 TNewProjectDialog = Record
  Base         : TDialog;               { dialogue de base           }
  SelType      : Integer;               { type selectionne (0..4)    }
  ProjectName  : String[63];            { nom du projet              }
  Location     : String[255];           { emplacement                }
  SolutionName : String[63];            { nom de la solution         }
  CreateSolDir : Boolean;               { creer repertoire solution  }
  ProjNameCursor : Integer;             { curseur champ nom projet   }
  LocCursor    : Integer;               { curseur champ emplacement  }
  SolNameCursor: Integer;               { curseur champ nom solution }
  FocusField   : Integer;               { champ actif (0..3)         }
  ScrollTop    : Integer;               { premiere ligne visible     }
  Confirmed    : Boolean;               { True si valide par OK      }
 End;

 { Boite de dialogue Nouveau fichier }
 TNewFileDialog = Record
  Base         : TDialog;               { dialogue de base           }
  SelType      : Integer;               { type selectionne (0..4)    }
  FileName     : String[127];           { nom du fichier             }
  FileNameCursor: Integer;              { curseur champ nom          }
  ScrollTop    : Integer;               { premiere ligne visible     }
  Confirmed    : Boolean;               { True si valide par OK      }
 End;

 { Boite de dialogue Ajouter une reference }
 TAddReferenceDialog = Record
  Base         : TDialog;               { dialogue de base           }
  ActiveTab    : TRefTabKind;           { onglet actif               }
  Items        : Array[0..MAX_ADDREF_ITEMS - 1] Of TRefListEntry;
  ItemCount    : Integer;               { nombre d items             }
  SelIndex     : Integer;               { index selectionne          }
  ScrollTop    : Integer;               { premiere ligne visible     }
  Confirmed    : Boolean;               { True si valide par OK      }
 End;

 { Boite de dialogue Proprietes du projet }
 TProjectPropertiesDialog = Record
  Base           : TDialog;             { dialogue de base           }
  ActiveTab      : TProjPropTab;        { onglet actif               }
  AssemblyName   : String[63];          { nom de l assembly          }
  RootNamespace  : String[63];          { espace de noms racine      }
  OutputTypeIdx  : Integer;             { index type de sortie       }
  DefineConstants: String[255];         { constantes de compilation  }
  OutputPath     : String[255];         { chemin de sortie           }
  WarningLevel   : Integer;             { niveau d avertissement     }
  TreatWarningsAsErrors: Boolean;       { avertissements = erreurs   }
  PreBuildEvent  : String[255];         { commande pre-build         }
  PostBuildEvent : String[255];         { commande post-build        }
  DebugArgs      : String[255];         { arguments de debogage      }
  WorkingDir     : String[255];         { repertoire de travail      }
  FocusField     : Integer;             { champ actif                }
  AsmNameCursor  : Integer;             { curseur nom assembly       }
  NsCursor       : Integer;             { curseur namespace          }
  DefCursor      : Integer;             { curseur constantes         }
  OutPathCursor  : Integer;             { curseur chemin sortie      }
  PreBuildCursor : Integer;             { curseur pre-build          }
  PostBuildCursor: Integer;             { curseur post-build         }
  DebugArgsCursor: Integer;             { curseur arguments debug    }
  WorkDirCursor  : Integer;             { curseur repertoire travail }
  Confirmed      : Boolean;             { True si valide par OK      }
 End;

 { Categories des options de l IDE }
 TOptionCategory = (
  OC_ENV_GENERAL,        { Environnement > General            }
  OC_ENV_FONTS,          { Environnement > Polices et couleurs}
  OC_ENV_KEYBOARD,       { Environnement > Clavier            }
  OC_ENV_STARTUP,        { Environnement > Demarrage          }
  OC_ENV_AUTOSAVE,       { Environnement > Enregistrement auto}
  OC_EDITOR_GENERAL,     { Editeur de texte > General         }
  OC_EDITOR_TABS,        { Editeur de texte > Tabulations     }
  OC_EDITOR_SCROLL,      { Editeur de texte > Defilement      }
  OC_EDITOR_INTELLISENSE,{ Editeur de texte > IntelliSense    }
  OC_EDITOR_FORMAT,      { Editeur de texte > Mise en forme   }
  OC_PROJ_GENERAL,       { Projets et solutions > General     }
  OC_PROJ_BUILD,         { Projets et solutions > Build       }
  OC_DEBUG_GENERAL,      { Debogage > General                 }
  OC_DEBUG_OUTPUT        { Debogage > Sortie                  }
 );

 { Noeud de l arbre de categories }
 TOptCategoryNode = Record
  Name      : String[63];        { nom affiche                    }
  ParentIdx : Integer;           { index du parent (-1 si racine) }
  Level     : Integer;           { niveau d indentation (0 ou 1)  }
  Expanded  : Boolean;           { noeud deplie                   }
  Visible   : Boolean;           { noeud visible dans l arbre     }
  Selected  : Boolean;           { noeud selectionne              }
  Category  : TOptionCategory;   { categorie associee             }
 End;

 { Action au demarrage }
 TOptStartupAction = (
  OSA_NOTHING,           { ne rien faire                      }
  OSA_LAST_PROJECT,      { ouvrir le dernier projet           }
  OSA_START_PAGE         { afficher la page d accueil         }
 );

 { Donnees de configuration des options }
 TOptionsDialogData = Record
  ThemeName       : String[31];  { nom du theme couleur           }
  FontName        : String[31];  { nom de la police               }
  FontSize        : Integer;     { taille de la police en pixels  }
  ShortcutModified: Boolean;     { raccourcis modifies            }
  StartupAction   : TOptStartupAction; { action au demarrage      }
  AutoSaveEnabled : Boolean;     { sauvegarde automatique activee }
  AutoSaveInterval: Integer;     { intervalle en secondes         }
  ShowLineNumbers : Boolean;     { afficher numeros de ligne      }
  WordWrap        : Boolean;     { retour a la ligne automatique  }
  ShowWhitespace  : Boolean;     { afficher espaces et tabs       }
  ShowIndentGuides: Boolean;     { afficher guides d indentation  }
  TabSize         : Integer;     { taille de la tabulation        }
  InsertSpaces    : Boolean;     { inserer espaces au lieu de tab }
  IndentSize      : Integer;     { taille d indentation           }
  SmoothScroll    : Boolean;     { defilement fluide              }
  ScrollMargin    : Integer;     { marge de defilement en lignes  }
  AutoIndent      : Boolean;     { indentation automatique        }
  AutoBraces      : Boolean;     { accolades automatiques         }
  DefaultProjectPath: String[255]; { chemin par defaut projets    }
  ShowOutputOnBuild: Boolean;    { afficher sortie au build       }
  BuildVerbose    : Boolean;     { build en mode verbeux          }
  ParallelBuild   : Integer;     { nombre de builds paralleles    }
  BreakOnFirstError: Boolean;    { arreter au premier point arret }
  StepIntoProperties: Boolean;   { pas a pas dans proprietes      }
  ShowDebugMessages: Boolean;    { afficher messages de debogage  }
 End;

 { Dialogue des options de l IDE }
 TOptionsDialog = Record
  Base            : TDialog;     { dialogue de base               }
  Categories      : Array[0..MAX_OPT_CATEGORIES - 1]
                     Of TOptCategoryNode; { arbre categories      }
  CategoryCount   : Integer;     { nombre de categories           }
  SelectedCategory: Integer;     { index categorie selectionnee   }
  ScrollTop       : Integer;     { premiere categorie visible     }
  Data            : TOptionsDialogData;  { parametres courants    }
  OriginalData    : TOptionsDialogData;  { copie pour annulation  }
  Modified        : Boolean;     { parametres modifies            }
  Confirmed       : Boolean;     { True si valide par OK          }
 End;

 { Portee de recherche }
 TSearchScope = (
  SS_CURRENT_DOC,       { document courant uniquement           }
  SS_ALL_OPEN_DOCS,     { tous les documents ouverts            }
  SS_CURRENT_PROJECT,   { projet entier                         }
  SS_ENTIRE_SOLUTION    { solution entiere                      }
 );

 { Options de recherche }
 TFindOptions = Record
  MatchCase   : Boolean;       { respecter la casse             }
  WholeWord   : Boolean;       { mot entier uniquement          }
  UseRegex    : Boolean;       { expressions regulieres (stub)  }
  SearchScope : TSearchScope;  { portee de la recherche         }
  SearchUp    : Boolean;       { chercher vers le haut          }
  WrapAround  : Boolean;       { boucler au debut/fin           }
 End;

 { Boite de dialogue Rechercher/Remplacer }
 TFindReplaceDialog = Record
  Base        : TDialog;       { dialogue de base               }
  SearchText  : String[127];   { texte a rechercher             }
  ReplaceText : String[127];   { texte de remplacement          }
  Options     : TFindOptions;  { options de recherche           }
  IsReplaceMode: Boolean;      { True=remplacer, False=chercher }
  SearchCursor: Integer;       { position curseur recherche     }
  ReplaceCursor: Integer;      { position curseur remplacement  }
  FoundCount  : Integer;       { nombre d occurrences trouvees  }
  LastFoundLine: LongInt;      { ligne derniere occurrence      }
  LastFoundCol : LongInt;      { colonne derniere occurrence    }
  HighlightAll : Boolean;      { surligner toutes occurrences   }
 End;

 { Boite de dialogue Aller a la ligne }
 TGoToLineDialog = Record
  Base        : TDialog;       { dialogue de base               }
  LineNumber  : LongInt;       { numero de ligne saisi          }
  MaxLine     : LongInt;       { nombre max de lignes           }
  InputText   : String[15];    { texte saisi                    }
  InputCursor : Integer;       { position curseur saisie        }
  Confirmed   : Boolean;       { True si valide par OK          }
 End;

 { Resultat de compilation }
 TCompilerResult = (
  CR_SUCCESS,           { compilation reussie                     }
  CR_ERRORS,            { compilation avec erreurs                }
  CR_WARNINGS,          { compilation avec avertissements         }
  CR_NOT_FOUND,         { compilateur introuvable                 }
  CR_NO_SOURCE,         { aucun fichier source                    }
  CR_EXEC_FAILED        { echec d execution du compilateur        }
 );

 { Contexte du compilateur C# }
 TCSCCompilerContext = Record
  CompilerPath   : String[255];    { chemin complet du compilateur   }
  CompilerName   : String[40];     { nom du compilateur (CSCW32/CSC86) }
  CompilerFound  : Boolean;        { compilateur disponible          }
  LastResult     : TCompilerResult;{ dernier resultat de compilation }
  ErrorCount     : Integer;        { nombre d erreurs derniere compil}
  WarningCount   : Integer;        { nombre d avertissements         }
  FilesCompiled  : Integer;        { nombre de fichiers compiles     }
  TotalFiles     : Integer;        { nombre total de fichiers source }
  OutputFile     : String[255];    { fichier de sortie genere        }
  TempFile       : String[255];    { fichier temporaire de sortie    }
  IsCompiling    : Boolean;        { compilation en cours            }
  UseDebugSymbols: Boolean;        { inclure symboles de debogage    }
  UseVerbose     : Boolean;        { mode verbeux                    }
  UseWarnings    : Boolean;        { afficher avertissements         }
 End;

 { Contexte du compilateur VB.NET }
 TVBCCompilerContext = Record
  CompilerPath   : String[255];    { chemin complet du compilateur   }
  CompilerName   : String[40];     { nom du compilateur (VBCW32/VBC86) }
  CompilerFound  : Boolean;        { compilateur disponible          }
  LastResult     : TCompilerResult;{ dernier resultat de compilation }
  ErrorCount     : Integer;        { nombre d erreurs derniere compil}
  WarningCount   : Integer;        { nombre d avertissements         }
  FilesCompiled  : Integer;        { nombre de fichiers compiles     }
  TotalFiles     : Integer;        { nombre total de fichiers source }
  OutputFile     : String[255];    { fichier de sortie genere        }
  TempFile       : String[255];    { fichier temporaire de sortie    }
  IsCompiling    : Boolean;        { compilation en cours            }
  UseDebugSymbols: Boolean;        { inclure symboles de debogage    }
  UseVerbose     : Boolean;        { mode verbeux                    }
  UseWarnings    : Boolean;        { afficher avertissements         }
 End;

 { Contexte du compilateur Pascal }
 TTPCCompilerContext = Record
  CompilerPath   : String[255];    { chemin complet du compilateur   }
  CompilerName   : String[40];     { nom du compilateur              }
  CompilerFound  : Boolean;        { compilateur disponible          }
  LastResult     : TCompilerResult;{ dernier resultat de compilation }
  ErrorCount     : Integer;        { nombre d erreurs derniere compil}
  WarningCount   : Integer;        { nombre d avertissements         }
  FilesCompiled  : Integer;        { nombre de fichiers compiles     }
  TotalFiles     : Integer;        { nombre total de fichiers source }
  OutputFile     : String[255];    { fichier de sortie genere        }
  TempFile       : String[255];    { fichier temporaire de sortie    }
  IsCompiling    : Boolean;        { compilation en cours            }
  UseDebugSymbols: Boolean;        { inclure symboles de debogage    }
  UseVerbose     : Boolean;        { mode verbeux                    }
  UseWarnings    : Boolean;        { afficher avertissements         }
 End;

 { Etat de build d un projet }
 TBuildStatus = (
  BS_PENDING,          { en attente de compilation               }
  BS_BUILDING,         { compilation en cours                     }
  BS_SUCCEEDED,        { compilation reussie                      }
  BS_FAILED,           { compilation echouee                      }
  BS_SKIPPED,          { projet ignore (up-to-date ou erreur dep) }
  BS_CLEANED           { nettoyage effectue                       }
 );

 { Resultat de build d un projet }
 TBuildProjectResult = Record
  ProjectName  : String[63];       { nom du projet                  }
  ProjectGUID  : String[40];       { GUID du projet                 }
  Status       : TBuildStatus;     { statut du build                }
  ErrorCount   : Integer;          { nombre d erreurs               }
  WarningCount : Integer;          { nombre d avertissements        }
  OutputFile   : String[255];      { fichier de sortie genere       }
  ElapsedMs    : LongInt;          { duree en millisecondes         }
 End;

 { Gestionnaire de build }
 TBuildManager = Record
  Results      : Array[0..MAX_BUILD_RESULTS - 1] Of TBuildProjectResult;
  ResultCount  : Integer;          { nombre de resultats            }
  BuildOrder   : Array[0..BUILD_MAX_ORDER - 1] Of Integer;
  OrderCount   : Integer;          { nombre de projets dans l ordre }
  ActiveConfig : String[40];       { configuration active           }
  ActivePlatform: String[20];      { plateforme active              }
  IsBuilding   : Boolean;          { build en cours                 }
  TotalSucceeded: Integer;         { projets reussis                }
  TotalFailed  : Integer;          { projets echoues                }
  TotalSkipped : Integer;          { projets ignores                }
  TotalUpToDate: Integer;          { projets a jour                 }
 End;

 { Gestionnaire de configurations }
 TConfigurationManager = Record
  Visible      : Boolean;          { dialogue visible               }
  X            : Integer;          { position X du dialogue         }
  Y            : Integer;          { position Y du dialogue         }
  Width        : Integer;          { largeur du dialogue            }
  Height       : Integer;          { hauteur du dialogue            }
  SelectedRow  : Integer;          { ligne selectionnee             }
  ScrollTop    : Integer;          { defilement vertical            }
  NeedRepaint  : Boolean;          { doit etre redessine            }
 End;

 { Point d arret }
 TBreakpoint = Record
  FileName       : String[255];     { fichier source                 }
  Line           : Integer;         { numero de ligne (1-based)      }
  Enabled        : Boolean;         { point d arret actif            }
  Condition      : String[127];     { condition (vide = toujours)    }
  HitCount       : Integer;         { nombre de passages effectues   }
  HitCountTarget : Integer;         { cible de passages (0 = ignore) }
 End;

 { Etat du debogueur }
 TDebugState = (
  DS_IDLE,             { aucun debogage en cours                    }
  DS_RUNNING,          { programme en cours d execution             }
  DS_PAUSED,           { programme en pause (stub)                  }
  DS_STOPPED           { programme arrete                           }
 );

 { Gestionnaire de points d arret }
 TBreakpointManager = Record
  Breakpoints  : Array[0..MAX_BREAKPOINTS - 1] Of TBreakpoint;
  Count        : Integer;          { nombre de points d arret       }
  State        : TDebugState;      { etat du debogueur              }
  ExecutablePath: String[255];     { chemin de l executable         }
  LastExitCode : Integer;          { code retour du dernier run     }
 End;

 { Panneau de debogage (breakpoints / watch / call stack) }
 TDebugPanelTab = (
  DPT_BREAKPOINTS,     { onglet points d arret                     }
  DPT_WATCH,           { onglet espion (stub)                       }
  DPT_CALLSTACK        { onglet pile d appels (stub)                }
 );

 TDebugPanel = Record
  Visible      : Boolean;          { panneau visible                }
  ActiveTab    : TDebugPanelTab;   { onglet actif                   }
  X            : Integer;          { position X                     }
  Y            : Integer;          { position Y                     }
  Width        : Integer;          { largeur                        }
  Height       : Integer;          { hauteur                        }
  SelectedRow  : Integer;          { ligne selectionnee             }
  ScrollTop    : Integer;          { defilement vertical            }
  NeedRepaint  : Boolean;          { doit etre redessine            }
 End;

 { Mode d insertion }
 TInsertMode = (
  IM_INSERT,           { mode insertion                             }
  IM_OVERWRITE         { mode ecrasement                            }
 );

 { Barre d etat }
 TStatusBar = Record
  CursorLine   : Integer;          { ligne du curseur               }
  CursorCol    : Integer;          { colonne du curseur             }
  InsertMode   : TInsertMode;      { mode INS ou OVR                }
  Encoding     : TFileEncoding;    { encodage du fichier            }
  LineEnding   : TLineEnding;      { type de fin de ligne           }
  Language     : String[31];       { langage courant                }
  FileName     : String[255];      { nom du fichier courant         }
  BuildStatus  : String[31];       { etat du build                  }
  NeedRepaint  : Boolean;          { doit etre redessine            }
 End;

 { Entree de la liste des fichiers recents }
 TMRUEntry = Record
  FilePath     : String[255];      { chemin complet du fichier      }
 End;

 { Liste des fichiers recents (Most Recently Used) }
 TMRUList = Record
  Entries      : Array[0..MRU_MAX_ENTRIES - 1] Of TMRUEntry;
  Count        : Integer;          { nombre d entrees               }
 End;

 { Page de demarrage }
 TStartPage = Record
  Visible      : Boolean;          { page visible                   }
  SelectedItem : Integer;          { element selectionne            }
  ScrollTop    : Integer;          { defilement vertical            }
  NeedRepaint  : Boolean;          { doit etre redessine            }
 End;
Var
 Opts       : TDevEnvOptions;
 EvQueue    : TEventQueue;
 LastClickX : Integer;
 LastClickY : Integer;
 LastClickTime : LongInt;
 LastClickBtn  : TMouseButton;
 PrevMouseX : Integer;
 PrevMouseY : Integer;
 PrevMouseBtn : LongInt;
 { Widgets }
 WidgetList   : Array[0..MAX_WIDGETS - 1] Of TWidget;
 WidgetCount  : Integer;
 FocusedIdx   : Integer;
 { Noeuds d arbre }
 TreeNodes    : Array[0..MAX_TREE_NODES - 1] Of TTreeNode;
 TreeNodeCount: Integer;
 { Etiquettes d onglets }
 TabLabels    : Array[0..MAX_TAB_ITEMS - 1] Of String[63];
 { Items de liste }
 ListItems    : Array[0..MAX_LIST_ITEMS - 1] Of String[127];
 { Barre de menus }
 MainMenuBar  : TMenuBar;
 OpenMenuIdx  : Integer;      { index du menu ouvert (-1=aucun) }
 SelItemIdx   : Integer;      { index de l item selectionne     }
 MenuActive   : Boolean;      { barre de menus active           }
 { Barre d outils }
 MainToolBar  : TToolBar;
 TooltipTimer : LongInt;      { timestamp du debut de survol    }
 TooltipBtnIdx: Integer;      { index du bouton survole         }
 TooltipVisible: Boolean;     { infobulle affichee              }
 { Gestionnaire de fenetres }
 WinMgr       : TWindowManager;
 { Coloration syntaxique C# }
 CSharpHL     : TCSharpHighlighter;
 { Coloration syntaxique VB.NET }
 VBNetHL      : TVBNetHighlighter;
 { Coloration syntaxique Pascal }
 PascalHL     : TPascalHighlighter;
 { Explorateur de solution }
 SolExplorer  : TSolutionExplorer;
 { Panneau de proprietes }
 PropsPanel   : TPropertiesPanel;
 { Panneau de sortie }
 OutputPanel  : TOutputPanel;
 { Panneau de liste d erreurs }
 ErrorList    : TErrorListPanel;
 { Dialogue de recherche/remplacement }
 FindReplaceDlg : TFindReplaceDialog;
 { Dialogue aller a la ligne }
 GoToLineDlg    : TGoToLineDialog;
 { Contexte compilateur C# }
 CSCContext     : TCSCCompilerContext;
 { Contexte compilateur VB.NET }
 VBCContext     : TVBCCompilerContext;
 { Contexte compilateur Pascal }
 TPCContext     : TTPCCompilerContext;
 { Gestionnaire de build }
 BuildMgr       : TBuildManager;
 { Gestionnaire de configurations }
 CfgMgr         : TConfigurationManager;
 { Gestionnaire de points d arret }
 BPMgr          : TBreakpointManager;
 { Panneau de debogage }
 DbgPanel       : TDebugPanel;
 { Barre d etat }
 StatusBar      : TStatusBar;
 { Liste des fichiers recents }
 MRUList        : TMRUList;
 { Page de demarrage }
 StartPage      : TStartPage;
 { Indicateur de sortie }
 QuitRequested  : Boolean;

{ ============================================================
  TODO 01 - INFRASTRUCTURE, CONSTANTES ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ --- Fonctions utilitaires --- }

Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function StrToInt(S: String): LongInt;
Var
 N: LongInt;
 Code: Integer;
Begin
 Val(S, N, Code);
 If Code <> 0 Then
  StrToInt := 0
 Else
  StrToInt := N;
End;

Function UpCaseStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  S[I] := UpCase(S[I]);
 UpCaseStr := S;
End;

Function LowerCaseStr(S: String): String;
Var
 I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'A') And (S[I] <= 'Z') Then
   S[I] := Chr(Ord(S[I]) + 32);
 LowerCaseStr := S;
End;

Function TrimStr(S: String): String;
Var
 Lo, Hi: Integer;
Begin
 Lo := 1;
 While (Lo <= Length(S)) And (S[Lo] = ' ') Do
  Inc(Lo);
 Hi := Length(S);
 While (Hi >= Lo) And (S[Hi] = ' ') Do
  Dec(Hi);
 If Lo > Hi Then
  TrimStr := ''
 Else
  TrimStr := Copy(S, Lo, Hi - Lo + 1);
End;

Function ExtractFileName(Path: String): String;
Var
 I: Integer;
Begin
 For I := Length(Path) DownTo 1 Do
  If (Path[I] = '\') Or (Path[I] = '/') Then Begin
   ExtractFileName := Copy(Path, I + 1, Length(Path) - I);
   Exit;
  End;
 ExtractFileName := Path;
End;

Function ExtractFileExt(FileName: String): String;
Var
 I: Integer;
Begin
 For I := Length(FileName) DownTo 1 Do Begin
  If FileName[I] = '.' Then Begin
   ExtractFileExt := Copy(FileName, I, Length(FileName) - I + 1);
   Exit;
  End;
  If (FileName[I] = '\') Or (FileName[I] = '/') Then
   Break;
 End;
 ExtractFileExt := '';
End;

Function ExtractFilePath(Path: String): String;
Var
 I: Integer;
Begin
 For I := Length(Path) DownTo 1 Do
  If (Path[I] = '\') Or (Path[I] = '/') Then Begin
   ExtractFilePath := Copy(Path, 1, I);
   Exit;
  End;
 ExtractFilePath := '';
End;

Function ChangeFileExt(FileName, NewExt: String): String;
Var
 I: Integer;
 Base: String;
Begin
 Base := FileName;
 For I := Length(FileName) DownTo 1 Do Begin
  If FileName[I] = '.' Then Begin
   Base := Copy(FileName, 1, I - 1);
   Break;
  End;
  If (FileName[I] = '\') Or (FileName[I] = '/') Then
   Break;
 End;
 ChangeFileExt := Base + NewExt;
End;

Function FileExists(FileName: String): Boolean;
Var
 F: File;
 OldIO: Integer;
Begin
 Assign(F, FileName);
 {$I-}
 Reset(F, 1);
 {$I+}
 OldIO := IOResult;
 If OldIO = 0 Then Begin
  Close(F);
  OldIO := IOResult;
  FileExists := True;
 End Else
  FileExists := False;
End;

Function DirectoryExists(DirName: String): Boolean;
Var
 SR: SearchRec;
Begin
 FindFirst(DirName, Directory, SR);
 DirectoryExists := (DosError = 0) And ((SR.Attr And Directory) <> 0);
 FindClose(SR);
End;

Function HexNibble(N: Byte): Char;
Begin
 If N < 10 Then
  HexNibble := Chr(Ord('0') + N)
 Else
  HexNibble := Chr(Ord('A') + N - 10);
End;

Function HexByte(B: Byte): String;
Begin
 HexByte := HexNibble(B Shr 4) + HexNibble(B And $0F);
End;

Function HexWord(W: Word): String;
Begin
 HexWord := HexByte(Hi(W)) + HexByte(Lo(W));
End;

Function HexLong(L: LongInt): String;
Begin
 HexLong := HexWord(Word(L Shr 16)) + HexWord(Word(L And $FFFF));
End;

Function MinInt(A, B: LongInt): LongInt;
Begin
 If A < B Then MinInt := A Else MinInt := B;
End;

Function MaxInt(A, B: LongInt): LongInt;
Begin
 If A > B Then MaxInt := A Else MaxInt := B;
End;

Function Clamp(Value, Lo, Hi: LongInt): LongInt;
Begin
 If Value < Lo Then
  Clamp := Lo
 Else If Value > Hi Then
  Clamp := Hi
 Else
  Clamp := Value;
End;

Function PadLeft(S: String; Len: Integer; PadCh: Char): String;
Begin
 While Length(S) < Len Do
  S := PadCh + S;
 PadLeft := S;
End;

Function PadRight(S: String; Len: Integer; PadCh: Char): String;
Begin
 While Length(S) < Len Do
  S := S + PadCh;
 PadRight := S;
End;

Function StringReplace(Source, OldPat, NewPat: String): String;
Var
 Pos, OldLen, SrcLen: Integer;
 Result: String;
Begin
 Result := '';
 OldLen := Length(OldPat);
 SrcLen := Length(Source);
 If OldLen = 0 Then Begin
  StringReplace := Source;
  Exit;
 End;
 Pos := 1;
 While Pos <= SrcLen Do Begin
  If (Pos + OldLen - 1 <= SrcLen) And
     (Copy(Source, Pos, OldLen) = OldPat) Then Begin
   Result := Result + NewPat;
   Inc(Pos, OldLen);
  End Else Begin
   Result := Result + Source[Pos];
   Inc(Pos);
  End;
 End;
 StringReplace := Result;
End;

{ --- Gestion des erreurs --- }

Procedure FatalError(Msg: String);
Begin
 WriteLn('DEVENV: Erreur: ', Msg);
 Halt(EXIT_ERROR);
End;

{ --- Aide et version --- }

Procedure ShowVersion;
Begin
 WriteLn('DEVENV - Clone de Visual Studio en mode graphique');
 WriteLn('Version ', DEVENV_VERSION, ' (', DEVENV_DATE, ')');
 WriteLn('Projet DEV-COOLS - https://www.gladir.com/dev-cools');
 WriteLn('Compilateurs integres : C# (CSC), VB.NET (VBC), Pascal (TPC)');
End;

Procedure ShowHelp;
Begin
 ShowVersion;
 WriteLn;
 WriteLn('Usage: DEVENV [solution.sln] [options]');
 WriteLn;
 WriteLn('Options:');
 WriteLn('  solution.sln   Ouvrir une solution existante au demarrage');
 WriteLn('  -v             Mode verbeux (afficher details de demarrage)');
 WriteLn('  -d             Mode debogage interne de l IDE');
 WriteLn('  -h             Afficher cette aide');
 WriteLn('  --help         Afficher cette aide');
 WriteLn;
 WriteLn('Langages supportes:');
 WriteLn('  C#      (.cs)   Compilateur CSCW32 / CSC86');
 WriteLn('  VB.NET  (.vb)   Compilateur VBCW32 / VBC86');
 WriteLn('  Pascal  (.pas)  Compilateur TPCW32 / VAXPAS86 / VAXPCW32');
 WriteLn;
 WriteLn('Format de solution:');
 WriteLn('  .sln            Format Microsoft Visual Studio');
 Halt(EXIT_OK);
End;

{ --- Initialisation des options --- }

Procedure InitOptions(Var Opts: TDevEnvOptions);
Begin
 Opts.SolutionFile    := '';
 Opts.Verbose         := False;
 Opts.DebugMode       := False;
 Opts.ThemeName       := 'Default';
 Opts.FontSize        := 8;
 Opts.TabSize         := 4;
 Opts.AutoSave        := False;
 Opts.ShowLineNumbers := True;
 Opts.WordWrap        := False;
 Opts.AutoIndent      := True;
 Opts.ShowWhitespace  := False;
End;

{ --- Analyse de la ligne de commande --- }

Procedure ParseCommandLine(Var Opts: TDevEnvOptions);
Var
 I: Integer;
 Arg, Ext: String;
Begin
 For I := 1 To ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-h') Or (Arg = '--help') Or (Arg = '-?') Or
     (Arg = '/?') Then
   ShowHelp
  Else If (Arg = '-v') Or (Arg = '-V') Then
   Opts.Verbose := True
  Else If (Arg = '-d') Or (Arg = '-D') Then
   Opts.DebugMode := True
  Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
   FatalError('Option inconnue: ' + Arg)
  Else Begin
   { Argument sans tiret : fichier solution }
   If Opts.SolutionFile = '' Then Begin
    Ext := UpCaseStr(ExtractFileExt(Arg));
    If Ext <> '.SLN' Then
     FatalError('Format de fichier non reconnu: ' + Arg +
                ' (attendu: .sln)');
    If Not FileExists(Arg) Then
     FatalError('Fichier introuvable: ' + Arg);
    Opts.SolutionFile := Arg;
   End Else
    FatalError('Fichier solution deja specifie: ' + Arg);
  End;
 End;
End;

{ ============================================================
  TODO 02 - INITIALISATION GRAPHIQUE MULTIPLATEFORME [IMPLEMENTE]
  ============================================================ }

{ --- Initialisation du mode graphique --- }

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver := VGA;
  Mode := VGAHi;
 {$ELSE}
  Driver := Detect;
  Mode := 0;
 {$ENDIF}
 InitGraph(Driver, Mode, '');
 ErrCode := GraphResult;
 If ErrCode <> grOk Then Begin
  WriteLn('DEVENV: Erreur graphique: ', GraphErrorMsg(ErrCode));
  Halt(EXIT_ERROR);
 End;
 SetColor(CLR_EDITOR_TEXT);
 SetBkColor(CLR_BACKGROUND);
 SetLineStyle(SolidLn, 0, NormWidth);
End;

{ --- Fermeture du mode graphique --- }

Procedure ShutdownGraphics;
Begin
 CloseGraph;
End;

{ --- Changement de resolution --- }

Procedure SetResolution(W, H: Integer);
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 CloseGraph;
 {$IFDEF FPC}
  Driver := VGA;
  If (W >= 1024) And (H >= 768) Then
   Mode := VGAHi    { 640x480, plus haute resolution VGA standard }
  Else If (W >= 640) And (H >= 350) Then
   Mode := VGAMed   { 640x350 }
  Else
   Mode := VGALo;   { 640x200 }
 {$ELSE}
  Driver := Detect;
  Mode := 0;
 {$ENDIF}
 InitGraph(Driver, Mode, '');
 ErrCode := GraphResult;
 If ErrCode <> grOk Then Begin
  WriteLn('DEVENV: Erreur graphique: ', GraphErrorMsg(ErrCode));
  Halt(EXIT_ERROR);
 End;
 SetColor(CLR_EDITOR_TEXT);
 SetBkColor(CLR_BACKGROUND);
 SetLineStyle(SolidLn, 0, NormWidth);
End;

{ --- Dimensions de l ecran --- }

Function GetScreenWidth: Integer;
Begin
 GetScreenWidth := GetMaxX + 1;
End;

Function GetScreenHeight: Integer;
Begin
 GetScreenHeight := GetMaxY + 1;
End;

{ --- Nombre maximal de couleurs --- }

Function GetMaxColors: Integer;
Begin
 GetMaxColors := GetMaxColor + 1;
End;

{ --- Zone de decoupage (clipping) --- }

Procedure SetClipRect(X1, Y1, X2, Y2: Integer);
Begin
 SetViewPort(X1, Y1, X2, Y2, ClipOn);
End;

Procedure ResetClipRect;
Begin
 SetViewPort(0, 0, GetMaxX, GetMaxY, ClipOn);
End;

{ --- Effacement de l ecran avec une couleur --- }

Procedure ClearScreen(Color: Integer);
Begin
 SetBkColor(Color);
 ClearDevice;
End;

{ ============================================================
  TODO 03 - GESTION DE LA SOURIS ET SYSTEME D EVENEMENTS [IMPLEMENTE]
  ============================================================ }

{ --- Abstraction souris multiplateforme --- }

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
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure ShowMouse;
 Begin
  { PtcMouse gere l affichage }
 End;

 Procedure HideMouse;
 Begin
  { PtcMouse gere le masquage }
 End;
{$ENDIF}

{ --- Initialisation de la souris --- }

Procedure InitMouse;
Begin
 If MouseDriverFound Then
  ShowMouse;
 PrevMouseX := 0;
 PrevMouseY := 0;
 PrevMouseBtn := 0;
 LastClickX := -1;
 LastClickY := -1;
 LastClickTime := 0;
 LastClickBtn := MB_NONE;
End;

{ --- Horodatage en millisecondes --- }

Function GetTimestamp: LongInt;
Var
 H, M, S, S100: Word;
Begin
 GetTime(H, M, S, S100);
 GetTimestamp := (LongInt(H) * 3600000) +
                 (LongInt(M) * 60000) +
                 (LongInt(S) * 1000) +
                 (LongInt(S100) * 10);
End;

{ --- File circulaire d evenements --- }

Procedure InitEventQueue;
Begin
 EvQueue.Head := 0;
 EvQueue.Tail := 0;
 EvQueue.Count := 0;
End;

Procedure PushEvent(Ev: TEvent);
Begin
 If EvQueue.Count < 256 Then Begin
  EvQueue.Items[EvQueue.Tail] := Ev;
  EvQueue.Tail := (EvQueue.Tail + 1) And $FF;
  Inc(EvQueue.Count);
 End;
End;

Function PopEvent(Var Ev: TEvent): Boolean;
Begin
 If EvQueue.Count > 0 Then Begin
  Ev := EvQueue.Items[EvQueue.Head];
  EvQueue.Head := (EvQueue.Head + 1) And $FF;
  Dec(EvQueue.Count);
  PopEvent := True;
 End Else
  PopEvent := False;
End;

Function PeekEvent(Var Ev: TEvent): Boolean;
Begin
 If EvQueue.Count > 0 Then Begin
  Ev := EvQueue.Items[EvQueue.Head];
  PeekEvent := True;
 End Else
  PeekEvent := False;
End;

Procedure FlushEvents;
Begin
 EvQueue.Head := 0;
 EvQueue.Tail := 0;
 EvQueue.Count := 0;
End;

{ --- Creation d un evenement vide --- }

Procedure ClearEvent(Var Ev: TEvent);
Begin
 Ev.Kind := EV_NONE;
 Ev.MouseX := 0;
 Ev.MouseY := 0;
 Ev.MouseBtn := MB_NONE;
 Ev.KeyCode := 0;
 Ev.KeyChar := #0;
 Ev.ShiftState := 0;
 Ev.Timestamp := 0;
End;

{ --- Conversion bouton souris (bit mask vers TMouseButton) --- }

Function BtnFromMask(Mask: LongInt): TMouseButton;
Begin
 If (Mask And 1) <> 0 Then
  BtnFromMask := MB_LEFT
 Else If (Mask And 2) <> 0 Then
  BtnFromMask := MB_RIGHT
 Else If (Mask And 4) <> 0 Then
  BtnFromMask := MB_MIDDLE
 Else
  BtnFromMask := MB_NONE;
End;

{ --- Detection de double-clic (delai 300 ms, 5 pixels) --- }

Function IsDoubleClick(X, Y: Integer; Btn: TMouseButton;
                       Now: LongInt): Boolean;
Var
 DX, DY: Integer;
Begin
 IsDoubleClick := False;
 If (Btn = LastClickBtn) And (LastClickBtn <> MB_NONE) Then Begin
  DX := X - LastClickX;
  DY := Y - LastClickY;
  If DX < 0 Then DX := -DX;
  If DY < 0 Then DY := -DY;
  If (DX <= 5) And (DY <= 5) And
     ((Now - LastClickTime) <= 300) Then
   IsDoubleClick := True;
 End;
End;

{ --- Interrogation souris et clavier --- }

Procedure PollEvents(Var Ev: TEvent);
Var
 MX, MY, MBtn: LongInt;
 Now: LongInt;
 Ch: Char;
 Btn: TMouseButton;
Begin
 ClearEvent(Ev);
 Now := GetTimestamp;
 Ev.Timestamp := Now;

 { Verifier le clavier d abord }
 If KeyPressed Then Begin
  Ch := ReadKey;
  If Ch = #0 Then Begin
   { Touche speciale : code etendu }
   Ev.Kind := EV_KEY_DOWN;
   If KeyPressed Then Begin
    Ch := ReadKey;
    Ev.KeyCode := Ord(Ch);
   End;
   Ev.KeyChar := #0;
  End Else Begin
   { Caractere ASCII normal }
   Ev.Kind := EV_KEY_CHAR;
   Ev.KeyChar := Ch;
   Ev.KeyCode := Ord(Ch);
  End;
  Exit;
 End;

 { Interroger la souris }
 MX := 0;
 MY := 0;
 MBtn := 0;
 {$IFDEF FPC}
  PtcMouse.GetMouseState(MX, MY, MBtn);
 {$ELSE}
  GetMouseState(MX, MY, MBtn);
 {$ENDIF}

 Btn := BtnFromMask(MBtn);

 { Bouton enfonce }
 If (MBtn <> 0) And (PrevMouseBtn = 0) Then Begin
  { Detection du double-clic }
  If IsDoubleClick(Integer(MX), Integer(MY), Btn, Now) Then Begin
   Ev.Kind := EV_MOUSE_DBLCLICK;
   LastClickBtn := MB_NONE;
  End Else Begin
   Ev.Kind := EV_MOUSE_DOWN;
   LastClickX := Integer(MX);
   LastClickY := Integer(MY);
   LastClickTime := Now;
   LastClickBtn := Btn;
  End;
  Ev.MouseX := Integer(MX);
  Ev.MouseY := Integer(MY);
  Ev.MouseBtn := Btn;
 End
 { Bouton relache }
 Else If (MBtn = 0) And (PrevMouseBtn <> 0) Then Begin
  Ev.Kind := EV_MOUSE_UP;
  Ev.MouseX := Integer(MX);
  Ev.MouseY := Integer(MY);
  Ev.MouseBtn := BtnFromMask(PrevMouseBtn);
 End
 { Deplacement }
 Else If (Integer(MX) <> PrevMouseX) Or
         (Integer(MY) <> PrevMouseY) Then Begin
  Ev.Kind := EV_MOUSE_MOVE;
  Ev.MouseX := Integer(MX);
  Ev.MouseY := Integer(MY);
  Ev.MouseBtn := Btn;
 End;

 PrevMouseX := Integer(MX);
 PrevMouseY := Integer(MY);
 PrevMouseBtn := MBtn;
End;

{ ============================================================
  TODO 04 - SYSTEME DE WIDGETS GUI (BASE) [IMPLEMENTE]
  ============================================================ }

{ --- Initialisation du systeme de widgets --- }

Procedure InitWidgetSystem;
Begin
 WidgetCount := 0;
 FocusedIdx := -1;
 TreeNodeCount := 0;
End;

{ --- Initialisation d un widget --- }

Procedure InitWidget(Var W: TWidget; AKind: TWidgetKind;
                     AX, AY, AW, AH: Integer;
                     AName: String);
Begin
 W.Kind := AKind;
 W.X := AX;
 W.Y := AY;
 W.Width := AW;
 W.Height := AH;
 W.Visible := True;
 W.Enabled := True;
 W.Focused := False;
 W.Parent := Nil;
 W.Tag := 0;
 W.Name := AName;
 W.State := WS_NORMAL;
 W.NeedRepaint := True;
 W.Caption := '';
 W.Checked := False;
 W.GroupID := 0;
 W.TextBuf := '';
 W.CursorPos := 0;
 W.ItemCount := 0;
 W.SelIndex := -1;
 W.ScrollPos := 0;
 W.ScrollMax := 0;
 W.Horizontal := False;
 W.Progress := 0;
 W.TabCount := 0;
 W.ActiveTab := 0;
 W.Expanded := False;
 W.TreeRoot := -1;
 W.ShowBorder := False;
 W.BgColor := CLR_BACKGROUND;
 W.FgColor := CLR_MENU_TEXT;
End;

{ --- Geometrie et visibilite --- }

Procedure SetBounds(Var W: TWidget; AX, AY, AW, AH: Integer);
Begin
 W.X := AX;
 W.Y := AY;
 W.Width := AW;
 W.Height := AH;
 W.NeedRepaint := True;
End;

Function WidgetContains(Var W: TWidget; PX, PY: Integer): Boolean;
Begin
 WidgetContains := (PX >= W.X) And (PX < W.X + W.Width) And
                   (PY >= W.Y) And (PY < W.Y + W.Height);
End;

Procedure ShowWidget(Var W: TWidget);
Begin
 W.Visible := True;
 W.NeedRepaint := True;
End;

Procedure HideWidget(Var W: TWidget);
Begin
 W.Visible := False;
 W.NeedRepaint := True;
End;

Procedure EnableWidget(Var W: TWidget);
Begin
 W.Enabled := True;
 W.State := WS_NORMAL;
 W.NeedRepaint := True;
End;

Procedure DisableWidget(Var W: TWidget);
Begin
 W.Enabled := False;
 W.State := WS_DISABLED;
 W.NeedRepaint := True;
End;

Procedure InvalidateWidget(Var W: TWidget);
Begin
 W.NeedRepaint := True;
End;

{ --- Enregistrement des widgets --- }

Function RegisterWidget(AKind: TWidgetKind;
                        AX, AY, AW, AH: Integer;
                        AName: String): Integer;
Begin
 If WidgetCount < MAX_WIDGETS Then Begin
  InitWidget(WidgetList[WidgetCount], AKind, AX, AY, AW, AH, AName);
  RegisterWidget := WidgetCount;
  Inc(WidgetCount);
 End Else
  RegisterWidget := -1;
End;

Procedure UnregisterWidget(Idx: Integer);
Var
 I: Integer;
Begin
 If (Idx >= 0) And (Idx < WidgetCount) Then Begin
  For I := Idx To WidgetCount - 2 Do
   WidgetList[I] := WidgetList[I + 1];
  Dec(WidgetCount);
  If FocusedIdx = Idx Then
   FocusedIdx := -1
  Else If FocusedIdx > Idx Then
   Dec(FocusedIdx);
 End;
End;

{ --- Gestion du focus --- }

Procedure SetFocus(Idx: Integer);
Begin
 If (FocusedIdx >= 0) And (FocusedIdx < WidgetCount) Then
  WidgetList[FocusedIdx].Focused := False;
 If (Idx >= 0) And (Idx < WidgetCount) Then Begin
  FocusedIdx := Idx;
  WidgetList[Idx].Focused := True;
  WidgetList[Idx].NeedRepaint := True;
 End Else
  FocusedIdx := -1;
End;

Function GetFocusedWidget: Integer;
Begin
 GetFocusedWidget := FocusedIdx;
End;

{ --- Dessin des widgets --- }

Procedure DrawPanel(Var W: TWidget);
Begin
 If Not W.Visible Then Exit;
 {$IFDEF FPC}
 SetColor(W.BgColor);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 If W.ShowBorder Then Begin
  SetColor(CLR_BORDER);
  Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 End;
 If Length(W.Caption) > 0 Then Begin
  SetColor(W.FgColor);
  OutTextXY(W.X + 4, W.Y + 2, W.Caption);
 End;
 {$ELSE}
 SetColor(W.BgColor);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 If W.ShowBorder Then Begin
  SetColor(CLR_BORDER);
  Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 End;
 If Length(W.Caption) > 0 Then Begin
  SetColor(W.FgColor);
  OutTextXY(W.X + 4, W.Y + 2, W.Caption);
 End;
 {$ENDIF}
End;

Procedure DrawLabel(Var W: TWidget);
Begin
 If Not W.Visible Then Exit;
 SetColor(W.FgColor);
 OutTextXY(W.X, W.Y, W.Caption);
End;

Procedure DrawButton(Var W: TWidget);
Var
 TX, TY: Integer;
Begin
 If Not W.Visible Then Exit;
 { Fond du bouton }
 If W.State = WS_PRESSED Then
  SetColor(CLR_MENU_HIGHLIGHT)
 Else If W.State = WS_HOVER Then
  SetColor(CLR_LINE_HIGHLIGHT)
 Else If W.State = WS_DISABLED Then
  SetColor(CLR_SCROLLBAR)
 Else
  SetColor(CLR_BACKGROUND);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Bordure }
 SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Texte centre }
 TX := W.X + (W.Width - Length(W.Caption) * 8) Div 2;
 TY := W.Y + (W.Height - 8) Div 2;
 If W.State = WS_DISABLED Then
  SetColor(CLR_SCROLLBAR)
 Else
  SetColor(W.FgColor);
 OutTextXY(TX, TY, W.Caption);
End;

Procedure DrawCheckBox(Var W: TWidget);
Var
 BX, BY: Integer;
Begin
 If Not W.Visible Then Exit;
 BX := W.X;
 BY := W.Y + (W.Height - 10) Div 2;
 { Case }
 SetColor(CLR_EDITOR_BG);
 Bar(BX, BY, BX + 10, BY + 10);
 SetColor(CLR_BORDER);
 Rectangle(BX, BY, BX + 10, BY + 10);
 { Coche }
 If W.Checked Then Begin
  SetColor(W.FgColor);
  Line(BX + 2, BY + 5, BX + 4, BY + 8);
  Line(BX + 4, BY + 8, BX + 8, BY + 2);
 End;
 { Label }
 SetColor(W.FgColor);
 OutTextXY(BX + 14, W.Y + (W.Height - 8) Div 2, W.Caption);
End;

Procedure DrawRadioButton(Var W: TWidget);
Var
 CX, CY: Integer;
Begin
 If Not W.Visible Then Exit;
 CX := W.X + 6;
 CY := W.Y + W.Height Div 2;
 { Cercle exterieur }
 SetColor(CLR_BORDER);
 Circle(CX, CY, 5);
 { Point interieur si selectionne }
 If W.Checked Then Begin
  SetColor(W.FgColor);
  Circle(CX, CY, 2);
 End;
 { Label }
 SetColor(W.FgColor);
 OutTextXY(W.X + 14, W.Y + (W.Height - 8) Div 2, W.Caption);
End;

Procedure DrawEditField(Var W: TWidget);
Begin
 If Not W.Visible Then Exit;
 { Fond }
 SetColor(CLR_EDITOR_BG);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Bordure }
 If W.Focused Then
  SetColor(CLR_TITLEBAR_ACTIVE)
 Else
  SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Texte }
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(W.X + 2, W.Y + (W.Height - 8) Div 2, W.TextBuf);
 { Curseur }
 If W.Focused Then Begin
  SetColor(CLR_CURSOR);
  Line(W.X + 2 + W.CursorPos * 8, W.Y + 2,
       W.X + 2 + W.CursorPos * 8, W.Y + W.Height - 3);
 End;
End;

Procedure DrawListBox(Var W: TWidget);
Var
 I, YPos, MaxVisible: Integer;
Begin
 If Not W.Visible Then Exit;
 { Fond }
 SetColor(CLR_EDITOR_BG);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Bordure }
 SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Items }
 MaxVisible := (W.Height - 4) Div 12;
 For I := 0 To MaxVisible - 1 Do Begin
  If (I + W.ScrollPos) >= W.ItemCount Then Break;
  YPos := W.Y + 2 + I * 12;
  If (I + W.ScrollPos) = W.SelIndex Then Begin
   SetColor(CLR_SELECTION);
   Bar(W.X + 1, YPos, W.X + W.Width - 2, YPos + 11);
   SetColor(CLR_EDITOR_BG);
  End Else
   SetColor(CLR_EDITOR_TEXT);
  OutTextXY(W.X + 4, YPos + 2, ListItems[I + W.ScrollPos]);
 End;
End;

Procedure DrawComboBox(Var W: TWidget);
Begin
 If Not W.Visible Then Exit;
 { Champ de saisie }
 SetColor(CLR_EDITOR_BG);
 Bar(W.X, W.Y, W.X + W.Width - 17, W.Y + W.Height - 1);
 SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Bouton fleche }
 SetColor(CLR_BACKGROUND);
 Bar(W.X + W.Width - 16, W.Y + 1, W.X + W.Width - 2, W.Y + W.Height - 2);
 SetColor(CLR_BORDER);
 Line(W.X + W.Width - 16, W.Y, W.X + W.Width - 16, W.Y + W.Height - 1);
 { Fleche vers le bas }
 SetColor(W.FgColor);
 Line(W.X + W.Width - 12, W.Y + 6, W.X + W.Width - 8, W.Y + W.Height - 6);
 Line(W.X + W.Width - 8, W.Y + W.Height - 6,
      W.X + W.Width - 4, W.Y + 6);
 { Texte }
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(W.X + 2, W.Y + (W.Height - 8) Div 2, W.TextBuf);
End;

Procedure DrawScrollBar(Var W: TWidget);
Var
 ThumbPos, ThumbSize, TrackLen: Integer;
Begin
 If Not W.Visible Then Exit;
 { Piste }
 SetColor(CLR_SCROLLBAR);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Poignee }
 If W.ScrollMax > 0 Then Begin
  If W.Horizontal Then Begin
   TrackLen := W.Width - 4;
   ThumbSize := TrackLen Div 4;
   If ThumbSize < 16 Then ThumbSize := 16;
   ThumbPos := W.X + 2 + (LongInt(W.ScrollPos) *
               LongInt(TrackLen - ThumbSize)) Div LongInt(W.ScrollMax);
   SetColor(CLR_TITLEBAR);
   Bar(ThumbPos, W.Y + 2, ThumbPos + ThumbSize - 1, W.Y + W.Height - 3);
  End Else Begin
   TrackLen := W.Height - 4;
   ThumbSize := TrackLen Div 4;
   If ThumbSize < 16 Then ThumbSize := 16;
   ThumbPos := W.Y + 2 + (LongInt(W.ScrollPos) *
               LongInt(TrackLen - ThumbSize)) Div LongInt(W.ScrollMax);
   SetColor(CLR_TITLEBAR);
   Bar(W.X + 2, ThumbPos, W.X + W.Width - 3, ThumbPos + ThumbSize - 1);
  End;
 End;
End;

Procedure DrawProgressBar(Var W: TWidget);
Var
 FillW: Integer;
Begin
 If Not W.Visible Then Exit;
 { Fond }
 SetColor(CLR_SCROLLBAR);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Barre de progression }
 If W.Progress > 0 Then Begin
  FillW := (LongInt(W.Width - 4) * LongInt(W.Progress)) Div 100;
  SetColor(CLR_TITLEBAR_ACTIVE);
  Bar(W.X + 2, W.Y + 2, W.X + 2 + FillW - 1, W.Y + W.Height - 3);
 End;
End;

Procedure DrawSplitter(Var W: TWidget);
Begin
 If Not W.Visible Then Exit;
 SetColor(CLR_BORDER);
 If W.Horizontal Then Begin
  Line(W.X, W.Y + W.Height Div 2, W.X + W.Width - 1, W.Y + W.Height Div 2);
 End Else Begin
  Line(W.X + W.Width Div 2, W.Y, W.X + W.Width Div 2, W.Y + W.Height - 1);
 End;
End;

Procedure DrawTreeView(Var W: TWidget);
Var
 I, YPos, MaxVisible, DrawCount: Integer;
Begin
 If Not W.Visible Then Exit;
 { Fond }
 SetColor(CLR_EDITOR_BG);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 SetColor(CLR_BORDER);
 Rectangle(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Noeuds visibles }
 MaxVisible := (W.Height - 4) Div 14;
 DrawCount := 0;
 For I := 0 To TreeNodeCount - 1 Do Begin
  If DrawCount >= MaxVisible Then Break;
  If I < W.ScrollPos Then Continue;
  YPos := W.Y + 2 + DrawCount * 14;
  { Indentation }
  SetColor(CLR_BORDER);
  If TreeNodes[I].Expanded Then
   OutTextXY(W.X + 4 + TreeNodes[I].Level * 16, YPos, '-')
  Else
   OutTextXY(W.X + 4 + TreeNodes[I].Level * 16, YPos, '+');
  { Texte du noeud }
  If I = W.SelIndex Then Begin
   SetColor(CLR_SELECTION);
   Bar(W.X + 16 + TreeNodes[I].Level * 16, YPos,
       W.X + W.Width - 2, YPos + 13);
   SetColor(CLR_EDITOR_BG);
  End Else
   SetColor(CLR_EDITOR_TEXT);
  OutTextXY(W.X + 18 + TreeNodes[I].Level * 16, YPos + 3,
            TreeNodes[I].Caption);
  Inc(DrawCount);
 End;
End;

Procedure DrawTabControl(Var W: TWidget);
Var
 I, TX: Integer;
Begin
 If Not W.Visible Then Exit;
 { Fond }
 SetColor(W.BgColor);
 Bar(W.X, W.Y, W.X + W.Width - 1, W.Y + W.Height - 1);
 { Onglets }
 TX := W.X;
 For I := 0 To W.TabCount - 1 Do Begin
  If I >= MAX_TAB_ITEMS Then Break;
  If I = W.ActiveTab Then Begin
   SetColor(CLR_EDITOR_BG);
   Bar(TX, W.Y, TX + Length(TabLabels[I]) * 8 + 12, W.Y + 20);
   SetColor(CLR_BORDER);
   Rectangle(TX, W.Y, TX + Length(TabLabels[I]) * 8 + 12, W.Y + 20);
   SetColor(CLR_EDITOR_TEXT);
  End Else Begin
   SetColor(CLR_BACKGROUND);
   Bar(TX, W.Y + 2, TX + Length(TabLabels[I]) * 8 + 12, W.Y + 20);
   SetColor(CLR_BORDER);
   Rectangle(TX, W.Y + 2, TX + Length(TabLabels[I]) * 8 + 12, W.Y + 20);
   SetColor(CLR_MENU_TEXT);
  End;
  OutTextXY(TX + 6, W.Y + 6, TabLabels[I]);
  TX := TX + Length(TabLabels[I]) * 8 + 14;
 End;
 { Ligne sous les onglets }
 SetColor(CLR_BORDER);
 Line(W.X, W.Y + 21, W.X + W.Width - 1, W.Y + 21);
End;

{ --- Dessin d un widget quelconque --- }

Procedure DrawWidget(Idx: Integer);
Begin
 If (Idx < 0) Or (Idx >= WidgetCount) Then Exit;
 Case WidgetList[Idx].Kind Of
  WK_PANEL      : DrawPanel(WidgetList[Idx]);
  WK_LABEL      : DrawLabel(WidgetList[Idx]);
  WK_BUTTON     : DrawButton(WidgetList[Idx]);
  WK_CHECKBOX   : DrawCheckBox(WidgetList[Idx]);
  WK_RADIOBUTTON: DrawRadioButton(WidgetList[Idx]);
  WK_EDITFIELD  : DrawEditField(WidgetList[Idx]);
  WK_LISTBOX    : DrawListBox(WidgetList[Idx]);
  WK_COMBOBOX   : DrawComboBox(WidgetList[Idx]);
  WK_SCROLLBAR  : DrawScrollBar(WidgetList[Idx]);
  WK_PROGRESSBAR: DrawProgressBar(WidgetList[Idx]);
  WK_SPLITTER   : DrawSplitter(WidgetList[Idx]);
  WK_TREEVIEW   : DrawTreeView(WidgetList[Idx]);
  WK_TABCONTROL : DrawTabControl(WidgetList[Idx]);
 End;
 WidgetList[Idx].NeedRepaint := False;
End;

Procedure RepaintWidget(Idx: Integer);
Begin
 If (Idx >= 0) And (Idx < WidgetCount) Then
  DrawWidget(Idx);
End;

{ --- Dessin de tous les widgets de base --- }

Procedure DrawAllBaseWidgets;
Var
 I: Integer;
Begin
 For I := 0 To WidgetCount - 1 Do
  If WidgetList[I].Visible Then
   DrawWidget(I);
End;

{ --- Gestion des evenements de widgets --- }

Procedure HandleEditFieldEvent(Var W: TWidget; Var Ev: TEvent);
Begin
 If Not W.Enabled Then Exit;
 If Ev.Kind = EV_KEY_CHAR Then Begin
  If Ev.KeyChar = #8 Then Begin
   { Backspace }
   If (W.CursorPos > 0) And (Length(W.TextBuf) > 0) Then Begin
    Delete(W.TextBuf, W.CursorPos, 1);
    Dec(W.CursorPos);
    W.NeedRepaint := True;
   End;
  End Else If Ev.KeyChar >= ' ' Then Begin
   If Length(W.TextBuf) < MAX_EDIT_LEN Then Begin
    Inc(W.CursorPos);
    Insert(Ev.KeyChar, W.TextBuf, W.CursorPos);
    W.NeedRepaint := True;
   End;
  End;
 End Else If Ev.Kind = EV_KEY_DOWN Then Begin
  Case Ev.KeyCode Of
   75: { Fleche gauche }
    If W.CursorPos > 0 Then Begin
     Dec(W.CursorPos);
     W.NeedRepaint := True;
    End;
   77: { Fleche droite }
    If W.CursorPos < Length(W.TextBuf) Then Begin
     Inc(W.CursorPos);
     W.NeedRepaint := True;
    End;
   71: { Home }
    Begin W.CursorPos := 0; W.NeedRepaint := True; End;
   79: { End }
    Begin W.CursorPos := Length(W.TextBuf); W.NeedRepaint := True; End;
   83: { Delete }
    If W.CursorPos < Length(W.TextBuf) Then Begin
     Delete(W.TextBuf, W.CursorPos + 1, 1);
     W.NeedRepaint := True;
    End;
  End;
 End;
End;

Procedure HandleCheckBoxClick(Var W: TWidget);
Begin
 If Not W.Enabled Then Exit;
 W.Checked := Not W.Checked;
 W.NeedRepaint := True;
End;

Procedure HandleRadioButtonClick(Var W: TWidget);
Var
 I: Integer;
Begin
 If Not W.Enabled Then Exit;
 { Decocher les autres du meme groupe }
 For I := 0 To WidgetCount - 1 Do
  If (WidgetList[I].Kind = WK_RADIOBUTTON) And
     (WidgetList[I].GroupID = W.GroupID) Then Begin
   WidgetList[I].Checked := False;
   WidgetList[I].NeedRepaint := True;
  End;
 W.Checked := True;
 W.NeedRepaint := True;
End;

Procedure HandleListBoxClick(Var W: TWidget; MY: Integer);
Var
 ClickedIdx: Integer;
Begin
 If Not W.Enabled Then Exit;
 ClickedIdx := W.ScrollPos + (MY - W.Y - 2) Div 12;
 If (ClickedIdx >= 0) And (ClickedIdx < W.ItemCount) Then Begin
  W.SelIndex := ClickedIdx;
  W.NeedRepaint := True;
 End;
End;

Procedure HandleTabControlClick(Var W: TWidget; MX: Integer);
Var
 I, TX: Integer;
Begin
 If Not W.Enabled Then Exit;
 TX := W.X;
 For I := 0 To W.TabCount - 1 Do Begin
  If I >= MAX_TAB_ITEMS Then Break;
  If (MX >= TX) And (MX < TX + Length(TabLabels[I]) * 8 + 14) Then Begin
   W.ActiveTab := I;
   W.NeedRepaint := True;
   Exit;
  End;
  TX := TX + Length(TabLabels[I]) * 8 + 14;
 End;
End;

{ --- Distribution des evenements de base --- }

Procedure DispatchBaseEvent(Var Ev: TEvent);
Var
 I: Integer;
Begin
 { Evenements clavier : envoyer au widget avec le focus }
 If (Ev.Kind = EV_KEY_CHAR) Or (Ev.Kind = EV_KEY_DOWN) Then Begin
  If (FocusedIdx >= 0) And (FocusedIdx < WidgetCount) Then Begin
   If WidgetList[FocusedIdx].Kind = WK_EDITFIELD Then
    HandleEditFieldEvent(WidgetList[FocusedIdx], Ev);
  End;
  Exit;
 End;
 { Evenements souris : trouver le widget sous le curseur }
 If (Ev.Kind = EV_MOUSE_DOWN) Or (Ev.Kind = EV_MOUSE_UP) Or
    (Ev.Kind = EV_MOUSE_MOVE) Or (Ev.Kind = EV_MOUSE_DBLCLICK) Then Begin
  { Mise a jour de l etat hover/pressed }
  For I := WidgetCount - 1 DownTo 0 Do Begin
   If Not WidgetList[I].Visible Then Continue;
   If Not WidgetList[I].Enabled Then Continue;
   If WidgetContains(WidgetList[I], Ev.MouseX, Ev.MouseY) Then Begin
    { Souris dans ce widget }
    If Ev.Kind = EV_MOUSE_MOVE Then Begin
     If WidgetList[I].State <> WS_PRESSED Then Begin
      WidgetList[I].State := WS_HOVER;
      WidgetList[I].NeedRepaint := True;
     End;
    End Else If Ev.Kind = EV_MOUSE_DOWN Then Begin
     WidgetList[I].State := WS_PRESSED;
     WidgetList[I].NeedRepaint := True;
     SetFocus(I);
     { Actions specifiques au clic }
     Case WidgetList[I].Kind Of
      WK_CHECKBOX   : HandleCheckBoxClick(WidgetList[I]);
      WK_RADIOBUTTON: HandleRadioButtonClick(WidgetList[I]);
      WK_LISTBOX    : HandleListBoxClick(WidgetList[I], Ev.MouseY);
      WK_TABCONTROL : HandleTabControlClick(WidgetList[I], Ev.MouseX);
     End;
    End Else If Ev.Kind = EV_MOUSE_UP Then Begin
     WidgetList[I].State := WS_HOVER;
     WidgetList[I].NeedRepaint := True;
    End;
    Exit;
   End Else Begin
    { Souris hors de ce widget }
    If (WidgetList[I].State = WS_HOVER) Or
       (WidgetList[I].State = WS_PRESSED) Then Begin
     WidgetList[I].State := WS_NORMAL;
     WidgetList[I].NeedRepaint := True;
    End;
   End;
  End;
 End;
End;

{ ============================================================
  TODO 05 - BARRE DE MENUS ET MENUS DEROULANTS [IMPLEMENTE]
  ============================================================ }

{ --- Utilitaires de menu --- }

Procedure InitMenuItem(Var MI: TMenuItem; ACaption: String;
                       AShortCut: String; ATag: LongInt;
                       ASep: Boolean);
Begin
 MI.Caption := ACaption;
 MI.ShortCut := AShortCut;
 MI.Enabled := True;
 MI.Checked := False;
 MI.Separator := ASep;
 MI.Tag := ATag;
 MI.IconIndex := -1;
End;

Procedure AddMenuItem(Var M: TMenu; ACaption: String;
                      AShortCut: String; ATag: LongInt);
Begin
 If M.ItemCount < MAX_MENU_ITEMS Then Begin
  InitMenuItem(M.Items[M.ItemCount], ACaption, AShortCut, ATag, False);
  Inc(M.ItemCount);
 End;
End;

Procedure AddMenuSeparator(Var M: TMenu);
Begin
 If M.ItemCount < MAX_MENU_ITEMS Then Begin
  InitMenuItem(M.Items[M.ItemCount], '', '', 0, True);
  Inc(M.ItemCount);
 End;
End;

Procedure InitMenu(Var M: TMenu; ATitle: String);
Begin
 M.Title := ATitle;
 M.ItemCount := 0;
 M.X := 0;
 M.Width := 0;
End;

Function MenuItemWidth(Var M: TMenu): Integer;
Var
 I, W, MaxW: Integer;
Begin
 MaxW := 0;
 For I := 0 To M.ItemCount - 1 Do Begin
  If Not M.Items[I].Separator Then Begin
   W := Length(M.Items[I].Caption) + Length(M.Items[I].ShortCut) + 4;
   If W > MaxW Then
    MaxW := W;
  End;
 End;
 MenuItemWidth := MaxW * 8 + 16;
End;

{ --- Initialisation de la barre de menus Visual Studio --- }

Procedure InitMenuBar;
Var
 XPos, I: Integer;
Begin
 MainMenuBar.MenuCount := 0;
 MainMenuBar.Y := 0;
 MainMenuBar.Height := MENUBAR_HEIGHT;
 OpenMenuIdx := -1;
 SelItemIdx := -1;
 MenuActive := False;

 { Menu Fichier }
 InitMenu(MainMenuBar.Menus[0], 'Fichier');
 AddMenuItem(MainMenuBar.Menus[0], 'Nouveau projet...', 'Ctrl+Maj+N', 100);
 AddMenuItem(MainMenuBar.Menus[0], 'Nouveau fichier...', 'Ctrl+N', 101);
 AddMenuItem(MainMenuBar.Menus[0], 'Nouvelle solution...', '', 102);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Ouvrir projet/solution...', 'Ctrl+Maj+O', 110);
 AddMenuItem(MainMenuBar.Menus[0], 'Ouvrir fichier...', 'Ctrl+O', 111);
 AddMenuItem(MainMenuBar.Menus[0], 'Ouvrir dossier...', '', 112);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Fermer', 'Ctrl+W', 120);
 AddMenuItem(MainMenuBar.Menus[0], 'Fermer la solution', '', 121);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Enregistrer', 'Ctrl+S', 130);
 AddMenuItem(MainMenuBar.Menus[0], 'Enregistrer sous...', '', 131);
 AddMenuItem(MainMenuBar.Menus[0], 'Enregistrer tout', 'Ctrl+Maj+S', 132);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Imprimer...', 'Ctrl+P', 140);
 AddMenuItem(MainMenuBar.Menus[0], 'Apercu avant impression', '', 141);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Fichiers recents', '', 150);
 AddMenuItem(MainMenuBar.Menus[0], 'Projets recents', '', 151);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Quitter', 'Alt+F4', 199);
 MainMenuBar.MenuCount := 1;

 { Menu Edition }
 InitMenu(MainMenuBar.Menus[1], 'Edition');
 AddMenuItem(MainMenuBar.Menus[1], 'Annuler', 'Ctrl+Z', 200);
 AddMenuItem(MainMenuBar.Menus[1], 'Retablir', 'Ctrl+Y', 201);
 AddMenuSeparator(MainMenuBar.Menus[1]);
 AddMenuItem(MainMenuBar.Menus[1], 'Couper', 'Ctrl+X', 210);
 AddMenuItem(MainMenuBar.Menus[1], 'Copier', 'Ctrl+C', 211);
 AddMenuItem(MainMenuBar.Menus[1], 'Coller', 'Ctrl+V', 212);
 AddMenuItem(MainMenuBar.Menus[1], 'Supprimer', 'Suppr', 213);
 AddMenuSeparator(MainMenuBar.Menus[1]);
 AddMenuItem(MainMenuBar.Menus[1], 'Selectionner tout', 'Ctrl+A', 220);
 AddMenuSeparator(MainMenuBar.Menus[1]);
 AddMenuItem(MainMenuBar.Menus[1], 'Rechercher...', 'Ctrl+F', 230);
 AddMenuItem(MainMenuBar.Menus[1], 'Remplacer...', 'Ctrl+H', 231);
 AddMenuItem(MainMenuBar.Menus[1], 'Aller a la ligne...', 'Ctrl+G', 232);
 AddMenuSeparator(MainMenuBar.Menus[1]);
 AddMenuItem(MainMenuBar.Menus[1], 'Indenter', 'Tab', 240);
 AddMenuItem(MainMenuBar.Menus[1], 'Desindenter', 'Maj+Tab', 241);
 AddMenuItem(MainMenuBar.Menus[1], 'Mettre en majuscules', '', 242);
 AddMenuItem(MainMenuBar.Menus[1], 'Mettre en minuscules', '', 243);
 AddMenuSeparator(MainMenuBar.Menus[1]);
 AddMenuItem(MainMenuBar.Menus[1], 'Signet : activer', 'Ctrl+K,K', 250);
 AddMenuItem(MainMenuBar.Menus[1], 'Signet : suivant', 'Ctrl+K,N', 251);
 AddMenuItem(MainMenuBar.Menus[1], 'Signet : precedent', 'Ctrl+K,P', 252);
 AddMenuItem(MainMenuBar.Menus[1], 'Signet : effacer tout', 'Ctrl+K,L', 253);
 MainMenuBar.MenuCount := 2;

 { Menu Affichage }
 InitMenu(MainMenuBar.Menus[2], 'Affichage');
 AddMenuItem(MainMenuBar.Menus[2], 'Explorateur de solution', 'Ctrl+Alt+L', 300);
 AddMenuItem(MainMenuBar.Menus[2], 'Sortie', 'Ctrl+Alt+O', 301);
 AddMenuItem(MainMenuBar.Menus[2], 'Liste d erreurs', 'Ctrl+\+E', 302);
 AddMenuSeparator(MainMenuBar.Menus[2]);
 AddMenuItem(MainMenuBar.Menus[2], 'Barre d outils', '', 310);
 AddMenuItem(MainMenuBar.Menus[2], 'Plein ecran', 'Maj+Alt+Entree', 311);
 AddMenuSeparator(MainMenuBar.Menus[2]);
 AddMenuItem(MainMenuBar.Menus[2], 'Signets', '', 320);
 AddMenuItem(MainMenuBar.Menus[2], 'Pile d appels', '', 321);
 AddMenuItem(MainMenuBar.Menus[2], 'Espion', '', 322);
 AddMenuItem(MainMenuBar.Menus[2], 'Points d arret', '', 323);
 AddMenuSeparator(MainMenuBar.Menus[2]);
 AddMenuItem(MainMenuBar.Menus[2], 'Naviguer en arriere', 'Ctrl+-', 330);
 AddMenuItem(MainMenuBar.Menus[2], 'Naviguer en avant', 'Ctrl+Maj+-', 331);
 MainMenuBar.MenuCount := 3;

 { Menu Projet }
 InitMenu(MainMenuBar.Menus[3], 'Projet');
 AddMenuItem(MainMenuBar.Menus[3], 'Ajouter un element existant...', 'Maj+Alt+A', 400);
 AddMenuItem(MainMenuBar.Menus[3], 'Ajouter un nouvel element...', 'Ctrl+Maj+A', 401);
 AddMenuItem(MainMenuBar.Menus[3], 'Exclure du projet', '', 402);
 AddMenuSeparator(MainMenuBar.Menus[3]);
 AddMenuItem(MainMenuBar.Menus[3], 'Proprietes du projet', '', 410);
 AddMenuItem(MainMenuBar.Menus[3], 'Ajouter une reference...', '', 411);
 AddMenuItem(MainMenuBar.Menus[3], 'Gerer les packages NuGet...', '', 412);
 MainMenuBar.MenuCount := 4;

 { Menu Generer }
 InitMenu(MainMenuBar.Menus[4], 'Generer');
 AddMenuItem(MainMenuBar.Menus[4], 'Generer la solution', 'F6', 500);
 AddMenuItem(MainMenuBar.Menus[4], 'Regenerer la solution', '', 501);
 AddMenuSeparator(MainMenuBar.Menus[4]);
 AddMenuItem(MainMenuBar.Menus[4], 'Generer le projet', '', 510);
 AddMenuSeparator(MainMenuBar.Menus[4]);
 AddMenuItem(MainMenuBar.Menus[4], 'Nettoyer la solution', '', 520);
 AddMenuItem(MainMenuBar.Menus[4], 'Nettoyer le projet', '', 521);
 AddMenuSeparator(MainMenuBar.Menus[4]);
 AddMenuItem(MainMenuBar.Menus[4], 'Gestionnaire de configuration...', '', 530);
 MainMenuBar.MenuCount := 5;

 { Menu Deboguer }
 InitMenu(MainMenuBar.Menus[5], 'Deboguer');
 AddMenuItem(MainMenuBar.Menus[5], 'Demarrer le debogage', 'F5', 600);
 AddMenuItem(MainMenuBar.Menus[5], 'Demarrer sans debogage', 'Ctrl+F5', 601);
 AddMenuSeparator(MainMenuBar.Menus[5]);
 AddMenuItem(MainMenuBar.Menus[5], 'Point d arret', 'F9', 610);
 AddMenuSeparator(MainMenuBar.Menus[5]);
 AddMenuItem(MainMenuBar.Menus[5], 'Pas a pas principal', 'F10', 620);
 AddMenuItem(MainMenuBar.Menus[5], 'Pas a pas detaille', 'F11', 621);
 AddMenuItem(MainMenuBar.Menus[5], 'Pas a pas sortant', 'Maj+F11', 622);
 AddMenuSeparator(MainMenuBar.Menus[5]);
 AddMenuItem(MainMenuBar.Menus[5], 'Arreter le debogage', 'Maj+F5', 630);
 MainMenuBar.MenuCount := 6;

 { Menu Outils }
 InitMenu(MainMenuBar.Menus[6], 'Outils');
 AddMenuItem(MainMenuBar.Menus[6], 'Options...', '', 700);
 AddMenuItem(MainMenuBar.Menus[6], 'Personnaliser...', '', 701);
 AddMenuSeparator(MainMenuBar.Menus[6]);
 AddMenuItem(MainMenuBar.Menus[6], 'Gestionnaire d extensions...', '', 710);
 AddMenuSeparator(MainMenuBar.Menus[6]);
 AddMenuItem(MainMenuBar.Menus[6], 'Ligne de commande externe', '', 720);
 MainMenuBar.MenuCount := 7;

 { Menu Fenetre }
 InitMenu(MainMenuBar.Menus[7], 'Fenetre');
 AddMenuItem(MainMenuBar.Menus[7], 'Nouvelle fenetre', '', 800);
 AddMenuItem(MainMenuBar.Menus[7], 'Fractionner', '', 801);
 AddMenuSeparator(MainMenuBar.Menus[7]);
 AddMenuItem(MainMenuBar.Menus[7], 'Fermer toutes les fenetres', '', 810);
 AddMenuSeparator(MainMenuBar.Menus[7]);
 AddMenuItem(MainMenuBar.Menus[7], 'Fenetre suivante', 'Ctrl+F6', 820);
 AddMenuItem(MainMenuBar.Menus[7], 'Fenetre precedente', 'Ctrl+Maj+F6', 821);
 MainMenuBar.MenuCount := 8;

 { Menu Aide }
 InitMenu(MainMenuBar.Menus[8], 'Aide');
 AddMenuItem(MainMenuBar.Menus[8], 'A propos de DEVENV', '', 900);
 AddMenuItem(MainMenuBar.Menus[8], 'Documentation en ligne', '', 901);
 AddMenuSeparator(MainMenuBar.Menus[8]);
 AddMenuItem(MainMenuBar.Menus[8], 'Raccourcis clavier', '', 910);
 AddMenuItem(MainMenuBar.Menus[8], 'Bienvenue', '', 911);
 MainMenuBar.MenuCount := 9;

 { Calculer les positions X et largeurs }
 XPos := 4;
 For I := 0 To MainMenuBar.MenuCount - 1 Do Begin
  MainMenuBar.Menus[I].X := XPos;
  MainMenuBar.Menus[I].Width := MenuItemWidth(MainMenuBar.Menus[I]);
  XPos := XPos + Length(MainMenuBar.Menus[I].Title) * 8 + 16;
 End;
End;

{ --- Dessin de la barre de menus --- }

Procedure DrawMenuBar;
Var
 I, TX: Integer;
Begin
 { Fond de la barre }
 SetColor(CLR_MENUBAR);
 Bar(0, MainMenuBar.Y, GetScreenWidth - 1,
     MainMenuBar.Y + MainMenuBar.Height - 1);
 { Ligne de separation }
 SetColor(CLR_BORDER);
 Line(0, MainMenuBar.Y + MainMenuBar.Height - 1,
      GetScreenWidth - 1, MainMenuBar.Y + MainMenuBar.Height - 1);
 { Titres des menus }
 TX := 4;
 For I := 0 To MainMenuBar.MenuCount - 1 Do Begin
  If I = OpenMenuIdx Then Begin
   SetColor(CLR_MENU_HIGHLIGHT);
   Bar(TX - 4, MainMenuBar.Y,
       TX + Length(MainMenuBar.Menus[I].Title) * 8 + 12,
       MainMenuBar.Y + MainMenuBar.Height - 2);
   SetColor(CLR_EDITOR_BG);
  End Else
   SetColor(CLR_MENU_TEXT);
  OutTextXY(TX, MainMenuBar.Y + 4, MainMenuBar.Menus[I].Title);
  TX := TX + Length(MainMenuBar.Menus[I].Title) * 8 + 16;
 End;
End;

{ --- Ouverture d un menu deroulant --- }

Procedure DrawOpenMenu;
Var
 I, YPos, MX, MW, MH: Integer;
 M: TMenu;
Begin
 If OpenMenuIdx < 0 Then Exit;
 M := MainMenuBar.Menus[OpenMenuIdx];
 MX := M.X;
 MW := M.Width;
 If MW < 160 Then MW := 160;
 MH := 4;
 For I := 0 To M.ItemCount - 1 Do Begin
  If M.Items[I].Separator Then
   MH := MH + 8
  Else
   MH := MH + 16;
 End;
 { Ombre }
 SetColor(CLR_TITLEBAR);
 Bar(MX + 2, MainMenuBar.Height + 2, MX + MW + 2,
     MainMenuBar.Height + MH + 2);
 { Fond du menu }
 SetColor(CLR_EDITOR_BG);
 Bar(MX, MainMenuBar.Height, MX + MW, MainMenuBar.Height + MH);
 { Bordure }
 SetColor(CLR_BORDER);
 Rectangle(MX, MainMenuBar.Height, MX + MW, MainMenuBar.Height + MH);
 { Items }
 YPos := MainMenuBar.Height + 2;
 For I := 0 To M.ItemCount - 1 Do Begin
  If M.Items[I].Separator Then Begin
   SetColor(CLR_BORDER);
   Line(MX + 2, YPos + 3, MX + MW - 2, YPos + 3);
   YPos := YPos + 8;
  End Else Begin
   If I = SelItemIdx Then Begin
    SetColor(CLR_MENU_HIGHLIGHT);
    Bar(MX + 1, YPos, MX + MW - 1, YPos + 15);
    SetColor(CLR_EDITOR_BG);
   End Else Begin
    If Not M.Items[I].Enabled Then
     SetColor(CLR_BORDER)
    Else
     SetColor(CLR_MENU_TEXT);
   End;
   { Coche }
   If M.Items[I].Checked Then
    OutTextXY(MX + 4, YPos + 2, #251);
   { Caption }
   OutTextXY(MX + 16, YPos + 2, M.Items[I].Caption);
   { Raccourci }
   If Length(M.Items[I].ShortCut) > 0 Then Begin
    If I = SelItemIdx Then
     SetColor(CLR_EDITOR_BG)
    Else
     SetColor(CLR_BORDER);
    OutTextXY(MX + MW - Length(M.Items[I].ShortCut) * 8 - 8,
              YPos + 2, M.Items[I].ShortCut);
   End;
   YPos := YPos + 16;
  End;
 End;
End;

Procedure OpenMenu(Index: Integer);
Begin
 If (Index >= 0) And (Index < MainMenuBar.MenuCount) Then Begin
  OpenMenuIdx := Index;
  SelItemIdx := -1;
  MenuActive := True;
  DrawMenuBar;
  DrawOpenMenu;
 End;
End;

Procedure CloseMenu;
Begin
 OpenMenuIdx := -1;
 SelItemIdx := -1;
 MenuActive := False;
End;

{ --- Execution d un element de menu --- }

Procedure ExecuteMenuItem(Var Item: TMenuItem);
Begin
 CloseMenu;
 { Actions de base - les commandes seront connectees
   aux futurs TODOs (editeur, projet, debogueur, etc.) }
 Case Item.Tag Of
  199: Begin { Quitter }
        ShutdownGraphics;
        Halt(EXIT_OK);
       End;
 End;
End;

{ --- Trouver l index de menu sous la souris --- }

Function MenuBarHitTest(MX, MY: Integer): Integer;
Var
 I, TX, TW: Integer;
Begin
 MenuBarHitTest := -1;
 If (MY < MainMenuBar.Y) Or
    (MY >= MainMenuBar.Y + MainMenuBar.Height) Then Exit;
 TX := 0;
 For I := 0 To MainMenuBar.MenuCount - 1 Do Begin
  TW := Length(MainMenuBar.Menus[I].Title) * 8 + 16;
  If (MX >= TX) And (MX < TX + TW) Then Begin
   MenuBarHitTest := I;
   Exit;
  End;
  TX := TX + TW;
 End;
End;

{ --- Trouver l item sous la souris dans le menu ouvert --- }

Function MenuItemHitTest(MX, MY: Integer): Integer;
Var
 I, YPos, MW: Integer;
 M: TMenu;
Begin
 MenuItemHitTest := -1;
 If OpenMenuIdx < 0 Then Exit;
 M := MainMenuBar.Menus[OpenMenuIdx];
 MW := M.Width;
 If MW < 160 Then MW := 160;
 If (MX < M.X) Or (MX > M.X + MW) Then Exit;
 YPos := MainMenuBar.Height + 2;
 For I := 0 To M.ItemCount - 1 Do Begin
  If M.Items[I].Separator Then
   YPos := YPos + 8
  Else Begin
   If (MY >= YPos) And (MY < YPos + 16) Then Begin
    If M.Items[I].Enabled Then
     MenuItemHitTest := I;
    Exit;
   End;
   YPos := YPos + 16;
  End;
 End;
End;

{ --- Gestion des evenements de menu --- }

Procedure HandleMenuEvent(Var Ev: TEvent);
Var
 Hit, ItemHit: Integer;
Begin
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  { Clic sur la barre de menus }
  Hit := MenuBarHitTest(Ev.MouseX, Ev.MouseY);
  If Hit >= 0 Then Begin
   If (OpenMenuIdx = Hit) And MenuActive Then
    CloseMenu
   Else
    OpenMenu(Hit);
   Exit;
  End;
  { Clic dans un menu ouvert }
  If MenuActive And (OpenMenuIdx >= 0) Then Begin
   ItemHit := MenuItemHitTest(Ev.MouseX, Ev.MouseY);
   If ItemHit >= 0 Then Begin
    ExecuteMenuItem(MainMenuBar.Menus[OpenMenuIdx].Items[ItemHit]);
    Exit;
   End;
   { Clic ailleurs : fermer }
   CloseMenu;
  End;
 End
 Else If Ev.Kind = EV_MOUSE_MOVE Then Begin
  { Survol de la barre de menus avec menu ouvert }
  If MenuActive And (OpenMenuIdx >= 0) Then Begin
   Hit := MenuBarHitTest(Ev.MouseX, Ev.MouseY);
   If (Hit >= 0) And (Hit <> OpenMenuIdx) Then
    OpenMenu(Hit);
   { Survol des items }
   ItemHit := MenuItemHitTest(Ev.MouseX, Ev.MouseY);
   If ItemHit <> SelItemIdx Then Begin
    SelItemIdx := ItemHit;
    DrawOpenMenu;
   End;
  End;
 End
 Else If Ev.Kind = EV_KEY_DOWN Then Begin
  If MenuActive Then Begin
   Case Ev.KeyCode Of
    72: { Fleche haut }
     Begin
      If OpenMenuIdx >= 0 Then Begin
       If SelItemIdx > 0 Then
        Dec(SelItemIdx)
       Else
        SelItemIdx := MainMenuBar.Menus[OpenMenuIdx].ItemCount - 1;
       { Sauter les separateurs }
       While (SelItemIdx >= 0) And
             MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx].Separator Do
        Dec(SelItemIdx);
       DrawOpenMenu;
      End;
     End;
    80: { Fleche bas }
     Begin
      If OpenMenuIdx >= 0 Then Begin
       If SelItemIdx < MainMenuBar.Menus[OpenMenuIdx].ItemCount - 1 Then
        Inc(SelItemIdx)
       Else
        SelItemIdx := 0;
       { Sauter les separateurs }
       While (SelItemIdx < MainMenuBar.Menus[OpenMenuIdx].ItemCount) And
             MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx].Separator Do
        Inc(SelItemIdx);
       DrawOpenMenu;
      End;
     End;
    75: { Fleche gauche }
     Begin
      If OpenMenuIdx > 0 Then
       OpenMenu(OpenMenuIdx - 1)
      Else
       OpenMenu(MainMenuBar.MenuCount - 1);
     End;
    77: { Fleche droite }
     Begin
      If OpenMenuIdx < MainMenuBar.MenuCount - 1 Then
       OpenMenu(OpenMenuIdx + 1)
      Else
       OpenMenu(0);
     End;
    28: { Entree }
     Begin
      If (SelItemIdx >= 0) And (OpenMenuIdx >= 0) Then
       ExecuteMenuItem(MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx]);
     End;
    1:  { Echap }
     CloseMenu;
   End;
  End Else Begin
   { Alt+lettre pour ouvrir un menu depuis l etat inactif }
   If (Ev.ShiftState And $08) <> 0 Then Begin { Alt }
    Case Ev.KeyChar Of
     'f','F': OpenMenu(0); { Fichier }
     'e','E': OpenMenu(1); { Edition }
     'a','A': OpenMenu(2); { Affichage }
     'p','P': OpenMenu(3); { Projet }
     'g','G': OpenMenu(4); { Generer }
     'd','D': OpenMenu(5); { Deboguer }
     'o','O': OpenMenu(6); { Outils }
     'n','N': OpenMenu(7); { Fenetre }
     'i','I': OpenMenu(8); { Aide }
    End;
   End;
  End;
 End
 Else If Ev.Kind = EV_KEY_CHAR Then Begin
  { Raccourcis clavier globaux }
  If MenuActive Then Exit;
  { Pas de raccourcis ici pour l instant, les TODOs futurs
    connecteront les raccourcis aux commandes reelles. }
 End;
End;

{ --- Compter les elements de menu --- }

Function CountMenuItems: Integer;
Var
 I, Total: Integer;
Begin
 Total := 0;
 For I := 0 To MainMenuBar.MenuCount - 1 Do
  Total := Total + MainMenuBar.Menus[I].ItemCount;
 CountMenuItems := Total;
End;

Function CountMenuSeparators: Integer;
Var
 I, J, Total: Integer;
Begin
 Total := 0;
 For I := 0 To MainMenuBar.MenuCount - 1 Do
  For J := 0 To MainMenuBar.Menus[I].ItemCount - 1 Do
   If MainMenuBar.Menus[I].Items[J].Separator Then
    Inc(Total);
 CountMenuSeparators := Total;
End;

{ ============================================================
  TODO 06 - BARRE D OUTILS ET BOUTONS D ICONES [IMPLEMENTE]
  ============================================================ }

{ --- Dessin d une icone 16x16 --- }

Procedure DrawIcon16x16(X, Y: Integer; Var Icon: TIcon16);
Var
 IX, IY: Integer;
 C: Byte;
Begin
 For IY := 0 To 15 Do
  For IX := 0 To 15 Do Begin
   C := Icon[IY, IX];
   If C <> 255 Then Begin { 255 = transparent }
    PutPixel(X + IX, Y + IY, C);
   End;
  End;
End;

{ --- Initialisation d une icone vide --- }

Procedure ClearIcon(Var Icon: TIcon16; Color: Byte);
Var
 IX, IY: Integer;
Begin
 For IY := 0 To 15 Do
  For IX := 0 To 15 Do
   Icon[IY, IX] := Color;
End;

{ --- Dessiner un pixel dans une icone --- }

Procedure IconPutPixel(Var Icon: TIcon16; X, Y: Integer; C: Byte);
Begin
 If (X >= 0) And (X <= 15) And (Y >= 0) And (Y <= 15) Then
  Icon[Y, X] := C;
End;

{ --- Dessiner une ligne horizontale dans une icone --- }

Procedure IconHLine(Var Icon: TIcon16; X1, X2, Y: Integer; C: Byte);
Var
 X: Integer;
Begin
 For X := X1 To X2 Do
  IconPutPixel(Icon, X, Y, C);
End;

{ --- Dessiner une ligne verticale dans une icone --- }

Procedure IconVLine(Var Icon: TIcon16; X, Y1, Y2: Integer; C: Byte);
Var
 Y: Integer;
Begin
 For Y := Y1 To Y2 Do
  IconPutPixel(Icon, X, Y, C);
End;

{ --- Dessiner un rectangle dans une icone --- }

Procedure IconRect(Var Icon: TIcon16; X1, Y1, X2, Y2: Integer; C: Byte);
Begin
 IconHLine(Icon, X1, X2, Y1, C);
 IconHLine(Icon, X1, X2, Y2, C);
 IconVLine(Icon, X1, Y1, Y2, C);
 IconVLine(Icon, X2, Y1, Y2, C);
End;

{ --- Dessiner un rectangle plein dans une icone --- }

Procedure IconFillRect(Var Icon: TIcon16; X1, Y1, X2, Y2: Integer;
                       C: Byte);
Var
 Y: Integer;
Begin
 For Y := Y1 To Y2 Do
  IconHLine(Icon, X1, X2, Y, C);
End;

{ --- Icone : Nouveau fichier --- }

Procedure MakeIconNewFile(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Feuille blanche avec coin plie }
 IconFillRect(Icon, 3, 1, 11, 14, 15);   { fond blanc }
 IconRect(Icon, 3, 1, 11, 14, 0);        { bordure noire }
 IconHLine(Icon, 9, 11, 1, 255);
 IconVLine(Icon, 11, 1, 3, 255);
 IconPutPixel(Icon, 9, 1, 0);
 IconPutPixel(Icon, 10, 2, 0);
 IconPutPixel(Icon, 11, 3, 0);
 IconHLine(Icon, 9, 10, 1, 255);
 IconVLine(Icon, 11, 1, 2, 255);
 IconPutPixel(Icon, 9, 3, 8);
 IconPutPixel(Icon, 10, 3, 8);
 { Lignes de texte }
 IconHLine(Icon, 5, 9, 6, 8);
 IconHLine(Icon, 5, 9, 8, 8);
 IconHLine(Icon, 5, 8, 10, 8);
End;

{ --- Icone : Ouvrir --- }

Procedure MakeIconOpen(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Dossier jaune ouvert }
 IconFillRect(Icon, 1, 5, 14, 13, 14);  { fond jaune }
 IconRect(Icon, 1, 5, 14, 13, 0);       { bordure }
 IconFillRect(Icon, 1, 3, 6, 5, 14);    { onglet }
 IconRect(Icon, 1, 3, 6, 5, 0);
 IconHLine(Icon, 2, 13, 7, 0);          { pli }
End;

{ --- Icone : Enregistrer --- }

Procedure MakeIconSave(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Disquette }
 IconFillRect(Icon, 2, 1, 13, 14, 1);   { fond bleu }
 IconRect(Icon, 2, 1, 13, 14, 0);       { bordure }
 IconFillRect(Icon, 4, 1, 11, 5, 15);   { etiquette }
 IconRect(Icon, 4, 1, 11, 5, 0);
 IconFillRect(Icon, 5, 9, 10, 14, 8);   { volet metal }
 IconRect(Icon, 5, 9, 10, 14, 0);
End;

{ --- Icone : Enregistrer tout --- }

Procedure MakeIconSaveAll(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Deux disquettes decalees }
 IconFillRect(Icon, 4, 3, 13, 14, 1);
 IconRect(Icon, 4, 3, 13, 14, 0);
 IconFillRect(Icon, 6, 3, 11, 7, 15);
 IconRect(Icon, 6, 3, 11, 7, 0);
 IconFillRect(Icon, 1, 0, 10, 11, 1);
 IconRect(Icon, 1, 0, 10, 11, 0);
 IconFillRect(Icon, 3, 0, 8, 4, 15);
 IconRect(Icon, 3, 0, 8, 4, 0);
End;

{ --- Icone : Couper --- }

Procedure MakeIconCut(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Ciseaux }
 IconPutPixel(Icon, 5, 2, 0);
 IconPutPixel(Icon, 10, 2, 0);
 IconPutPixel(Icon, 6, 3, 0);
 IconPutPixel(Icon, 9, 3, 0);
 IconPutPixel(Icon, 7, 4, 0);
 IconPutPixel(Icon, 8, 4, 0);
 IconPutPixel(Icon, 7, 5, 0);
 IconPutPixel(Icon, 8, 5, 0);
 IconPutPixel(Icon, 7, 6, 0);
 IconPutPixel(Icon, 8, 6, 0);
 IconPutPixel(Icon, 6, 7, 0);
 IconPutPixel(Icon, 9, 7, 0);
 IconPutPixel(Icon, 5, 8, 0);
 IconPutPixel(Icon, 10, 8, 0);
 { Poignees circulaires }
 IconRect(Icon, 3, 9, 6, 12, 0);
 IconRect(Icon, 9, 9, 12, 12, 0);
End;

{ --- Icone : Copier --- }

Procedure MakeIconCopy(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Deux feuilles decalees }
 IconFillRect(Icon, 4, 3, 13, 14, 15);
 IconRect(Icon, 4, 3, 13, 14, 0);
 IconFillRect(Icon, 1, 0, 10, 11, 15);
 IconRect(Icon, 1, 0, 10, 11, 0);
 IconHLine(Icon, 3, 8, 3, 8);
 IconHLine(Icon, 3, 8, 5, 8);
 IconHLine(Icon, 3, 7, 7, 8);
End;

{ --- Icone : Coller --- }

Procedure MakeIconPaste(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Presse-papiers }
 IconFillRect(Icon, 2, 2, 13, 14, 14);  { fond jaune }
 IconRect(Icon, 2, 2, 13, 14, 0);       { bordure }
 IconFillRect(Icon, 5, 0, 10, 3, 8);    { clip }
 IconRect(Icon, 5, 0, 10, 3, 0);
 { Feuille collee }
 IconFillRect(Icon, 4, 5, 11, 13, 15);
 IconRect(Icon, 4, 5, 11, 13, 0);
 IconHLine(Icon, 6, 9, 7, 8);
 IconHLine(Icon, 6, 9, 9, 8);
End;

{ --- Icone : Annuler --- }

Procedure MakeIconUndo(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Fleche courbe vers la gauche }
 IconPutPixel(Icon, 3, 6, 1);
 IconPutPixel(Icon, 4, 5, 1);
 IconPutPixel(Icon, 5, 4, 1);
 IconHLine(Icon, 5, 11, 6, 1);
 IconHLine(Icon, 5, 11, 7, 1);
 IconPutPixel(Icon, 5, 8, 1);
 IconPutPixel(Icon, 4, 7, 1);
 IconPutPixel(Icon, 3, 8, 1);
 IconVLine(Icon, 11, 7, 11, 1);
 IconVLine(Icon, 12, 7, 11, 1);
 IconHLine(Icon, 7, 11, 11, 1);
End;

{ --- Icone : Retablir --- }

Procedure MakeIconRedo(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Fleche courbe vers la droite }
 IconPutPixel(Icon, 12, 6, 1);
 IconPutPixel(Icon, 11, 5, 1);
 IconPutPixel(Icon, 10, 4, 1);
 IconHLine(Icon, 4, 10, 6, 1);
 IconHLine(Icon, 4, 10, 7, 1);
 IconPutPixel(Icon, 10, 8, 1);
 IconPutPixel(Icon, 11, 7, 1);
 IconPutPixel(Icon, 12, 8, 1);
 IconVLine(Icon, 4, 7, 11, 1);
 IconVLine(Icon, 3, 7, 11, 1);
 IconHLine(Icon, 4, 8, 11, 1);
End;

{ --- Icone : Demarrer (F5) --- }

Procedure MakeIconStart(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Triangle vert (play) }
 IconVLine(Icon, 4, 2, 13, 2);
 IconVLine(Icon, 5, 3, 12, 2);
 IconVLine(Icon, 6, 4, 11, 2);
 IconVLine(Icon, 7, 5, 10, 2);
 IconVLine(Icon, 8, 6, 9, 2);
 IconVLine(Icon, 9, 7, 8, 2);
 IconPutPixel(Icon, 10, 7, 2);
End;

{ --- Icone : Arreter --- }

Procedure MakeIconStop(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Carre rouge }
 IconFillRect(Icon, 3, 3, 12, 12, 4);
 IconRect(Icon, 3, 3, 12, 12, 0);
End;

{ --- Icone : Pas a pas (F10) --- }

Procedure MakeIconStepOver(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Fleche vers le bas avec barre }
 IconHLine(Icon, 3, 12, 3, 1);
 IconHLine(Icon, 3, 12, 4, 1);
 IconVLine(Icon, 7, 4, 10, 1);
 IconVLine(Icon, 8, 4, 10, 1);
 { Pointe de fleche }
 IconPutPixel(Icon, 5, 9, 1);
 IconPutPixel(Icon, 6, 10, 1);
 IconPutPixel(Icon, 7, 11, 1);
 IconPutPixel(Icon, 8, 11, 1);
 IconPutPixel(Icon, 9, 10, 1);
 IconPutPixel(Icon, 10, 9, 1);
End;

{ --- Icone : Point d arret --- }

Procedure MakeIconBreakpoint(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Cercle rouge }
 IconHLine(Icon, 5, 10, 3, 4);
 IconHLine(Icon, 4, 11, 4, 4);
 IconHLine(Icon, 3, 12, 5, 4);
 IconHLine(Icon, 3, 12, 6, 4);
 IconHLine(Icon, 3, 12, 7, 4);
 IconHLine(Icon, 3, 12, 8, 4);
 IconHLine(Icon, 3, 12, 9, 4);
 IconHLine(Icon, 3, 12, 10, 4);
 IconHLine(Icon, 4, 11, 11, 4);
 IconHLine(Icon, 5, 10, 12, 4);
End;

{ --- Icone : Rechercher --- }

Procedure MakeIconFind(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Loupe }
 IconHLine(Icon, 4, 8, 1, 0);
 IconPutPixel(Icon, 3, 2, 0);
 IconPutPixel(Icon, 9, 2, 0);
 IconVLine(Icon, 2, 3, 6, 0);
 IconVLine(Icon, 10, 3, 6, 0);
 IconPutPixel(Icon, 3, 7, 0);
 IconPutPixel(Icon, 9, 7, 0);
 IconHLine(Icon, 4, 8, 8, 0);
 { Interieur clair }
 IconFillRect(Icon, 4, 3, 8, 6, 15);
 { Manche }
 IconPutPixel(Icon, 10, 9, 0);
 IconPutPixel(Icon, 11, 10, 0);
 IconPutPixel(Icon, 12, 11, 0);
 IconPutPixel(Icon, 13, 12, 0);
End;

{ --- Icone : Naviguer en arriere --- }

Procedure MakeIconNavBack(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Fleche gauche }
 IconHLine(Icon, 3, 12, 7, 1);
 IconHLine(Icon, 3, 12, 8, 1);
 IconPutPixel(Icon, 5, 5, 1);
 IconPutPixel(Icon, 4, 6, 1);
 IconPutPixel(Icon, 3, 7, 1);
 IconPutPixel(Icon, 4, 8, 1);
 IconPutPixel(Icon, 5, 9, 1);
End;

{ --- Icone : Naviguer en avant --- }

Procedure MakeIconNavForward(Var Icon: TIcon16);
Begin
 ClearIcon(Icon, 255);
 { Fleche droite }
 IconHLine(Icon, 3, 12, 7, 1);
 IconHLine(Icon, 3, 12, 8, 1);
 IconPutPixel(Icon, 10, 5, 1);
 IconPutPixel(Icon, 11, 6, 1);
 IconPutPixel(Icon, 12, 7, 1);
 IconPutPixel(Icon, 11, 8, 1);
 IconPutPixel(Icon, 10, 9, 1);
End;

{ --- Initialiser toutes les icones de la barre d outils --- }

Procedure InitToolBarIcons;
Begin
 MakeIconNewFile(MainToolBar.Buttons[0].Icon);
 MakeIconOpen(MainToolBar.Buttons[1].Icon);
 MakeIconSave(MainToolBar.Buttons[2].Icon);
 MakeIconSaveAll(MainToolBar.Buttons[3].Icon);
 { index 4 = separateur, pas d icone }
 MakeIconCut(MainToolBar.Buttons[5].Icon);
 MakeIconCopy(MainToolBar.Buttons[6].Icon);
 MakeIconPaste(MainToolBar.Buttons[7].Icon);
 { index 8 = separateur }
 MakeIconUndo(MainToolBar.Buttons[9].Icon);
 MakeIconRedo(MainToolBar.Buttons[10].Icon);
 { index 11 = separateur }
 MakeIconStart(MainToolBar.Buttons[12].Icon);
 MakeIconStop(MainToolBar.Buttons[13].Icon);
 MakeIconStepOver(MainToolBar.Buttons[14].Icon);
 MakeIconBreakpoint(MainToolBar.Buttons[15].Icon);
 { index 16 = separateur }
 MakeIconFind(MainToolBar.Buttons[17].Icon);
 { index 18 = separateur }
 MakeIconNavBack(MainToolBar.Buttons[19].Icon);
 MakeIconNavForward(MainToolBar.Buttons[20].Icon);
End;

{ --- Ajouter un bouton a la barre d outils --- }

Procedure AddToolButton(Var TB: TToolBar; ATooltip: String;
                        ATag: LongInt);
Begin
 If TB.BtnCount < MAX_TOOLBAR_BUTTONS Then Begin
  TB.Buttons[TB.BtnCount].Tooltip := ATooltip;
  TB.Buttons[TB.BtnCount].Tag := ATag;
  TB.Buttons[TB.BtnCount].Enabled := True;
  TB.Buttons[TB.BtnCount].Separator := False;
  TB.Buttons[TB.BtnCount].State := TB_NORMAL;
  TB.Buttons[TB.BtnCount].X := 0;
  ClearIcon(TB.Buttons[TB.BtnCount].Icon, 255);
  Inc(TB.BtnCount);
 End;
End;

{ --- Ajouter un separateur a la barre d outils --- }

Procedure AddToolSeparator(Var TB: TToolBar);
Begin
 If TB.BtnCount < MAX_TOOLBAR_BUTTONS Then Begin
  TB.Buttons[TB.BtnCount].Tooltip := '';
  TB.Buttons[TB.BtnCount].Tag := 0;
  TB.Buttons[TB.BtnCount].Enabled := False;
  TB.Buttons[TB.BtnCount].Separator := True;
  TB.Buttons[TB.BtnCount].State := TB_NORMAL;
  TB.Buttons[TB.BtnCount].X := 0;
  ClearIcon(TB.Buttons[TB.BtnCount].Icon, 255);
  Inc(TB.BtnCount);
 End;
End;

{ --- Initialiser la barre d outils Visual Studio --- }

Procedure InitToolBar;
Var
 I, XPos: Integer;
Begin
 MainToolBar.BtnCount := 0;
 MainToolBar.Y := MENUBAR_HEIGHT;
 MainToolBar.Height := TOOLBAR_HEIGHT;
 TooltipTimer := 0;
 TooltipBtnIdx := -1;
 TooltipVisible := False;

 { Groupe Fichier }
 AddToolButton(MainToolBar, 'Nouveau fichier (Ctrl+N)', 101);
 AddToolButton(MainToolBar, 'Ouvrir (Ctrl+O)', 111);
 AddToolButton(MainToolBar, 'Enregistrer (Ctrl+S)', 130);
 AddToolButton(MainToolBar, 'Enregistrer tout (Ctrl+Maj+S)', 132);
 AddToolSeparator(MainToolBar);

 { Groupe Presse-papiers }
 AddToolButton(MainToolBar, 'Couper (Ctrl+X)', 210);
 AddToolButton(MainToolBar, 'Copier (Ctrl+C)', 211);
 AddToolButton(MainToolBar, 'Coller (Ctrl+V)', 212);
 AddToolSeparator(MainToolBar);

 { Groupe Annuler/Retablir }
 AddToolButton(MainToolBar, 'Annuler (Ctrl+Z)', 200);
 AddToolButton(MainToolBar, 'Retablir (Ctrl+Y)', 201);
 AddToolSeparator(MainToolBar);

 { Groupe Debogage }
 AddToolButton(MainToolBar, 'Demarrer le debogage (F5)', 600);
 AddToolButton(MainToolBar, 'Arreter le debogage (Maj+F5)', 630);
 AddToolButton(MainToolBar, 'Pas a pas principal (F10)', 620);
 AddToolButton(MainToolBar, 'Point d arret (F9)', 610);
 AddToolSeparator(MainToolBar);

 { Groupe Recherche }
 AddToolButton(MainToolBar, 'Rechercher (Ctrl+F)', 230);
 AddToolSeparator(MainToolBar);

 { Groupe Navigation }
 AddToolButton(MainToolBar, 'Naviguer en arriere (Ctrl+-)', 330);
 AddToolButton(MainToolBar, 'Naviguer en avant (Ctrl+Maj+-)', 331);

 { Initialiser les icones }
 InitToolBarIcons;

 { Calculer les positions X }
 XPos := 4;
 For I := 0 To MainToolBar.BtnCount - 1 Do Begin
  MainToolBar.Buttons[I].X := XPos;
  If MainToolBar.Buttons[I].Separator Then
   XPos := XPos + TOOLSEP_WIDTH
  Else
   XPos := XPos + TOOLBTN_WIDTH;
 End;
End;

{ --- Dessiner la barre d outils --- }

Procedure DrawToolBar;
Var
 I, BX, BY: Integer;
Begin
 { Fond de la barre }
 SetColor(CLR_TOOLBAR);
 Bar(0, MainToolBar.Y, GetScreenWidth - 1,
     MainToolBar.Y + MainToolBar.Height - 1);
 { Ligne de separation en bas }
 SetColor(CLR_BORDER);
 Line(0, MainToolBar.Y + MainToolBar.Height - 1,
      GetScreenWidth - 1, MainToolBar.Y + MainToolBar.Height - 1);

 For I := 0 To MainToolBar.BtnCount - 1 Do Begin
  BX := MainToolBar.Buttons[I].X;
  BY := MainToolBar.Y + 2;
  If MainToolBar.Buttons[I].Separator Then Begin
   { Separateur : ligne verticale }
   SetColor(CLR_BORDER);
   Line(BX + 3, BY + 2, BX + 3, BY + TOOLBTN_HEIGHT - 4);
  End Else Begin
   { Bouton }
   Case MainToolBar.Buttons[I].State Of
    TB_HOVER: Begin
     SetColor(CLR_MENU_HIGHLIGHT);
     Bar(BX, BY, BX + TOOLBTN_WIDTH - 1, BY + TOOLBTN_HEIGHT - 1);
    End;
    TB_PRESSED: Begin
     SetColor(CLR_SELECTION);
     Bar(BX, BY, BX + TOOLBTN_WIDTH - 1, BY + TOOLBTN_HEIGHT - 1);
    End;
   End;
   { Dessiner l icone centree }
   DrawIcon16x16(BX + (TOOLBTN_WIDTH - ICON_SIZE) Div 2,
                 BY + (TOOLBTN_HEIGHT - ICON_SIZE) Div 2,
                 MainToolBar.Buttons[I].Icon);
   { Effet grise si desactive }
   If Not MainToolBar.Buttons[I].Enabled Then Begin
    SetColor(CLR_TOOLBAR);
    { Demi-transparence par hachure }
   End;
  End;
 End;
End;

{ --- Trouver le bouton sous la souris --- }

Function ToolBarHitTest(MX, MY: Integer): Integer;
Var
 I, BX, BY: Integer;
Begin
 ToolBarHitTest := -1;
 If (MY < MainToolBar.Y) Or
    (MY >= MainToolBar.Y + MainToolBar.Height) Then Exit;
 For I := 0 To MainToolBar.BtnCount - 1 Do Begin
  If MainToolBar.Buttons[I].Separator Then Continue;
  BX := MainToolBar.Buttons[I].X;
  BY := MainToolBar.Y + 2;
  If (MX >= BX) And (MX < BX + TOOLBTN_WIDTH) And
     (MY >= BY) And (MY < BY + TOOLBTN_HEIGHT) Then Begin
   ToolBarHitTest := I;
   Exit;
  End;
 End;
End;

{ --- Afficher une infobulle --- }

Procedure DrawTooltip(BtnIdx: Integer);
Var
 TX, TY, TW: Integer;
 Tip: String;
Begin
 If (BtnIdx < 0) Or (BtnIdx >= MainToolBar.BtnCount) Then Exit;
 Tip := MainToolBar.Buttons[BtnIdx].Tooltip;
 If Length(Tip) = 0 Then Exit;
 TX := MainToolBar.Buttons[BtnIdx].X;
 TY := MainToolBar.Y + MainToolBar.Height + 2;
 TW := Length(Tip) * 8 + 8;
 { Fond }
 SetColor(14);  { jaune clair }
 Bar(TX, TY, TX + TW, TY + 16);
 SetColor(0);
 Rectangle(TX, TY, TX + TW, TY + 16);
 OutTextXY(TX + 4, TY + 3, Tip);
End;

{ --- Effacer une infobulle --- }

Procedure HideTooltip;
Begin
 If TooltipVisible Then Begin
  TooltipVisible := False;
  TooltipBtnIdx := -1;
 End;
End;

{ --- Executer la commande d un bouton --- }

Procedure ExecuteToolButton(BtnIdx: Integer);
Var
 Item: TMenuItem;
Begin
 If (BtnIdx < 0) Or (BtnIdx >= MainToolBar.BtnCount) Then Exit;
 If Not MainToolBar.Buttons[BtnIdx].Enabled Then Exit;
 HideTooltip;
 { Reutiliser le meme systeme de tags que les menus }
 Item.Tag := MainToolBar.Buttons[BtnIdx].Tag;
 Item.Caption := MainToolBar.Buttons[BtnIdx].Tooltip;
 Item.ShortCut := '';
 Item.Enabled := True;
 Item.Checked := False;
 Item.Separator := False;
 Item.IconIndex := -1;
 ExecuteMenuItem(Item);
End;

{ --- Gestion des evenements de la barre d outils --- }

Procedure HandleToolBarEvent(Var Ev: TEvent);
Var
 Hit: Integer;
 Now: LongInt;
Begin
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  Hit := ToolBarHitTest(Ev.MouseX, Ev.MouseY);
  If Hit >= 0 Then Begin
   MainToolBar.Buttons[Hit].State := TB_PRESSED;
   DrawToolBar;
  End;
 End
 Else If Ev.Kind = EV_MOUSE_UP Then Begin
  Hit := ToolBarHitTest(Ev.MouseX, Ev.MouseY);
  If Hit >= 0 Then Begin
   If MainToolBar.Buttons[Hit].State = TB_PRESSED Then Begin
    MainToolBar.Buttons[Hit].State := TB_HOVER;
    ExecuteToolButton(Hit);
   End;
  End;
  { Remettre tous les boutons a normal/hover }
  For Hit := 0 To MainToolBar.BtnCount - 1 Do
   If MainToolBar.Buttons[Hit].State = TB_PRESSED Then
    MainToolBar.Buttons[Hit].State := TB_NORMAL;
  DrawToolBar;
 End
 Else If Ev.Kind = EV_MOUSE_MOVE Then Begin
  Hit := ToolBarHitTest(Ev.MouseX, Ev.MouseY);
  Now := GetTimestamp;
  { Mettre a jour les etats de survol }
  For TooltipBtnIdx := 0 To MainToolBar.BtnCount - 1 Do Begin
   If TooltipBtnIdx = Hit Then Begin
    If MainToolBar.Buttons[TooltipBtnIdx].State = TB_NORMAL Then
     MainToolBar.Buttons[TooltipBtnIdx].State := TB_HOVER;
   End Else Begin
    If MainToolBar.Buttons[TooltipBtnIdx].State = TB_HOVER Then
     MainToolBar.Buttons[TooltipBtnIdx].State := TB_NORMAL;
   End;
  End;
  { Gestion infobulle }
  If Hit >= 0 Then Begin
   If Hit <> TooltipBtnIdx Then Begin
    TooltipBtnIdx := Hit;
    TooltipTimer := Now;
    HideTooltip;
   End Else Begin
    If (Not TooltipVisible) And
       (Now - TooltipTimer >= TOOLTIP_DELAY) Then Begin
     TooltipVisible := True;
     DrawTooltip(Hit);
    End;
   End;
  End Else Begin
   HideTooltip;
   TooltipBtnIdx := -1;
  End;
  DrawToolBar;
 End;
End;

{ --- Compter les boutons de la barre d outils --- }

Function CountToolButtons: Integer;
Var
 I, Total: Integer;
Begin
 Total := 0;
 For I := 0 To MainToolBar.BtnCount - 1 Do
  If Not MainToolBar.Buttons[I].Separator Then
   Inc(Total);
 CountToolButtons := Total;
End;

Function CountToolSeparators: Integer;
Var
 I, Total: Integer;
Begin
 Total := 0;
 For I := 0 To MainToolBar.BtnCount - 1 Do
  If MainToolBar.Buttons[I].Separator Then
   Inc(Total);
 CountToolSeparators := Total;
End;

{ ============================================================
  TODO 07 - GESTIONNAIRE DE FENETRES MULTIPLES (MDI) [IMPLEMENTE]
  ============================================================ }

{ --- Extraction du nom de fichier pour onglet --- }

Function GetTabLabel(Path: String): String;
Begin
 GetTabLabel := ExtractFileName(Path);
End;

{ --- Initialiser une fenetre d editeur --- }

Procedure InitEditorWindow(Var W: TEditorWindow);
Begin
 W.Title := '';
 W.FileName := '';
 W.Modified := False;
 W.X := 0;
 W.Y := 0;
 W.Width := 0;
 W.Height := 0;
 W.ScrollX := 0;
 W.ScrollY := 0;
 W.CursorX := 1;
 W.CursorY := 1;
 W.SelStartX := 0;
 W.SelStartY := 0;
 W.SelEndX := 0;
 W.SelEndY := 0;
 W.TabIndex := -1;
 W.Visible := True;
 W.Minimized := False;
 W.Maximized := True;
End;

{ --- Initialiser le gestionnaire de fenetres --- }

Procedure InitWindowManager;
Var
 I: Integer;
Begin
 WinMgr.WinCount := 0;
 WinMgr.ActiveIdx := -1;
 WinMgr.TabScrollX := 0;
 WinMgr.SplitMode := False;
 WinMgr.SplitPos := 0;
 For I := 0 To MAX_WINDOWS - 1 Do
  InitEditorWindow(WinMgr.Windows[I]);
End;

{ --- Creer une nouvelle fenetre d editeur --- }

Procedure CreateEditorWindow(AFileName: String);
Var
 Idx: Integer;
Begin
 If WinMgr.WinCount >= MAX_WINDOWS Then Exit;
 Idx := WinMgr.WinCount;
 InitEditorWindow(WinMgr.Windows[Idx]);
 WinMgr.Windows[Idx].FileName := AFileName;
 If Length(AFileName) > 0 Then
  WinMgr.Windows[Idx].Title := GetTabLabel(AFileName)
 Else
  WinMgr.Windows[Idx].Title := 'Sans titre';
 WinMgr.Windows[Idx].TabIndex := Idx;
 WinMgr.Windows[Idx].Visible := True;
 WinMgr.Windows[Idx].Maximized := True;
 { Zone d edition : sous onglets, a droite de l explorateur }
 WinMgr.Windows[Idx].X := EXPLORER_WIDTH;
 WinMgr.Windows[Idx].Y := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + TAB_HEIGHT;
 WinMgr.Windows[Idx].Width := GetScreenWidth - EXPLORER_WIDTH;
 WinMgr.Windows[Idx].Height := GetScreenHeight - MENUBAR_HEIGHT
   - TOOLBAR_HEIGHT - TAB_HEIGHT - OUTPUT_HEIGHT - STATUSBAR_HEIGHT;
 Inc(WinMgr.WinCount);
 WinMgr.ActiveIdx := Idx;
End;

{ --- Fermer une fenetre d editeur --- }

Procedure CloseEditorWindow(Index: Integer);
Var
 I: Integer;
Begin
 If (Index < 0) Or (Index >= WinMgr.WinCount) Then Exit;
 { Decaler les fenetres suivantes }
 For I := Index To WinMgr.WinCount - 2 Do Begin
  WinMgr.Windows[I] := WinMgr.Windows[I + 1];
  WinMgr.Windows[I].TabIndex := I;
 End;
 Dec(WinMgr.WinCount);
 { Ajuster l index actif }
 If WinMgr.WinCount = 0 Then
  WinMgr.ActiveIdx := -1
 Else If WinMgr.ActiveIdx >= WinMgr.WinCount Then
  WinMgr.ActiveIdx := WinMgr.WinCount - 1;
End;

{ --- Activer une fenetre --- }

Procedure ActivateWindow(Index: Integer);
Begin
 If (Index >= 0) And (Index < WinMgr.WinCount) Then
  WinMgr.ActiveIdx := Index;
End;

{ --- Obtenir la fenetre active --- }

Function GetActiveWindow: Integer;
Begin
 GetActiveWindow := WinMgr.ActiveIdx;
End;

{ --- Fenetre suivante --- }

Procedure NextWindow;
Begin
 If WinMgr.WinCount <= 1 Then Exit;
 WinMgr.ActiveIdx := (WinMgr.ActiveIdx + 1) Mod WinMgr.WinCount;
End;

{ --- Fenetre precedente --- }

Procedure PreviousWindow;
Begin
 If WinMgr.WinCount <= 1 Then Exit;
 If WinMgr.ActiveIdx > 0 Then
  Dec(WinMgr.ActiveIdx)
 Else
  WinMgr.ActiveIdx := WinMgr.WinCount - 1;
End;

{ --- Calculer la largeur d un onglet --- }

Function TabWidth(Index: Integer): Integer;
Var
 W: Integer;
 T: String;
Begin
 T := WinMgr.Windows[Index].Title;
 If WinMgr.Windows[Index].Modified Then
  T := '*' + T;
 W := Length(T) * 8 + TAB_PADDING * 2 + TAB_CLOSE_SIZE + 4;
 If W > TAB_MAX_WIDTH Then
  W := TAB_MAX_WIDTH;
 TabWidth := W;
End;

{ --- Dessiner les onglets --- }

Procedure DrawWindowTabs;
Var
 I, TX, TW, TY: Integer;
 Lbl: String;
Begin
 TY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 { Fond de la barre d onglets }
 SetColor(CLR_BACKGROUND);
 Bar(EXPLORER_WIDTH, TY, GetScreenWidth - 1, TY + TAB_HEIGHT - 1);
 TX := EXPLORER_WIDTH - WinMgr.TabScrollX;
 For I := 0 To WinMgr.WinCount - 1 Do Begin
  TW := TabWidth(I);
  If (TX + TW > EXPLORER_WIDTH) And (TX < GetScreenWidth) Then Begin
   { Fond de l onglet }
   If I = WinMgr.ActiveIdx Then Begin
    SetColor(CLR_EDITOR_BG);
    Bar(TX, TY, TX + TW - 1, TY + TAB_HEIGHT - 1);
   End Else Begin
    SetColor(CLR_BACKGROUND);
    Bar(TX, TY, TX + TW - 1, TY + TAB_HEIGHT - 1);
    SetColor(CLR_BORDER);
    Rectangle(TX, TY, TX + TW - 1, TY + TAB_HEIGHT - 1);
   End;
   { Texte de l onglet }
   Lbl := WinMgr.Windows[I].Title;
   If WinMgr.Windows[I].Modified Then
    Lbl := '*' + Lbl;
   If Length(Lbl) > 18 Then
    Lbl := Copy(Lbl, 1, 15) + '...';
   SetColor(CLR_MENU_TEXT);
   OutTextXY(TX + TAB_PADDING, TY + 4, Lbl);
   { Bouton de fermeture (X) }
   SetColor(CLR_BORDER);
   OutTextXY(TX + TW - TAB_CLOSE_SIZE - 2, TY + 4, 'x');
  End;
  TX := TX + TW;
 End;
 { Ligne de separation sous les onglets }
 SetColor(CLR_BORDER);
 Line(EXPLORER_WIDTH, TY + TAB_HEIGHT - 1,
      GetScreenWidth - 1, TY + TAB_HEIGHT - 1);
End;

{ --- Test de clic sur les onglets --- }

Function TabHitTest(MX, MY: Integer): Integer;
Var
 I, TX, TW, TY: Integer;
Begin
 TabHitTest := -1;
 TY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 If (MY < TY) Or (MY >= TY + TAB_HEIGHT) Then Exit;
 If MX < EXPLORER_WIDTH Then Exit;
 TX := EXPLORER_WIDTH - WinMgr.TabScrollX;
 For I := 0 To WinMgr.WinCount - 1 Do Begin
  TW := TabWidth(I);
  If (MX >= TX) And (MX < TX + TW) Then Begin
   TabHitTest := I;
   Exit;
  End;
  TX := TX + TW;
 End;
End;

{ --- Test de clic sur le bouton de fermeture d un onglet --- }

Function TabCloseHitTest(MX, MY: Integer; TabIdx: Integer): Boolean;
Var
 TX, TW, TY, CX: Integer;
 I: Integer;
Begin
 TabCloseHitTest := False;
 If (TabIdx < 0) Or (TabIdx >= WinMgr.WinCount) Then Exit;
 TY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT;
 TX := EXPLORER_WIDTH - WinMgr.TabScrollX;
 For I := 0 To TabIdx - 1 Do
  TX := TX + TabWidth(I);
 TW := TabWidth(TabIdx);
 CX := TX + TW - TAB_CLOSE_SIZE - 2;
 If (MX >= CX) And (MX < CX + TAB_CLOSE_SIZE) And
    (MY >= TY + 2) And (MY < TY + TAB_HEIGHT - 2) Then
  TabCloseHitTest := True;
End;

{ --- Gestion des evenements des onglets --- }

Procedure HandleTabEvent(Var Ev: TEvent);
Var
 Hit: Integer;
Begin
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  Hit := TabHitTest(Ev.MouseX, Ev.MouseY);
  If Hit >= 0 Then Begin
   If TabCloseHitTest(Ev.MouseX, Ev.MouseY, Hit) Then Begin
    CloseEditorWindow(Hit);
    DrawWindowTabs;
   End Else Begin
    ActivateWindow(Hit);
    DrawWindowTabs;
   End;
  End;
 End;
End;

{ --- Sauvegarder toutes les fenetres --- }

Procedure SaveAllWindows;
Var
 I: Integer;
Begin
 For I := 0 To WinMgr.WinCount - 1 Do Begin
  If WinMgr.Windows[I].Modified Then Begin
   { SaveFile sera implemente dans un TODO futur (TODO 08+) }
   WinMgr.Windows[I].Modified := False;
  End;
 End;
End;

{ --- Fermer toutes les fenetres --- }

Procedure CloseAllWindows;
Begin
 WinMgr.WinCount := 0;
 WinMgr.ActiveIdx := -1;
End;

{ --- Disposition en mosaique --- }

Procedure ArrangeTile;
Var
 I, Cols, Rows, C, R, W, H, ZX, ZY, ZW, ZH: Integer;
Begin
 If WinMgr.WinCount <= 0 Then Exit;
 { Zone d edition }
 ZX := EXPLORER_WIDTH;
 ZY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + TAB_HEIGHT;
 ZW := GetScreenWidth - EXPLORER_WIDTH;
 ZH := GetScreenHeight - MENUBAR_HEIGHT - TOOLBAR_HEIGHT
       - TAB_HEIGHT - OUTPUT_HEIGHT - STATUSBAR_HEIGHT;
 { Calcul grille }
 Cols := 1;
 While Cols * Cols < WinMgr.WinCount Do Inc(Cols);
 Rows := (WinMgr.WinCount + Cols - 1) Div Cols;
 W := ZW Div Cols;
 H := ZH Div Rows;
 For I := 0 To WinMgr.WinCount - 1 Do Begin
  C := I Mod Cols;
  R := I Div Cols;
  WinMgr.Windows[I].X := ZX + C * W;
  WinMgr.Windows[I].Y := ZY + R * H;
  WinMgr.Windows[I].Width := W;
  WinMgr.Windows[I].Height := H;
  WinMgr.Windows[I].Maximized := False;
  WinMgr.Windows[I].Minimized := False;
 End;
End;

{ --- Disposition en cascade --- }

Procedure ArrangeCascade;
Var
 I, ZX, ZY, ZW, ZH, Offset: Integer;
Begin
 If WinMgr.WinCount <= 0 Then Exit;
 ZX := EXPLORER_WIDTH;
 ZY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + TAB_HEIGHT;
 ZW := GetScreenWidth - EXPLORER_WIDTH;
 ZH := GetScreenHeight - MENUBAR_HEIGHT - TOOLBAR_HEIGHT
       - TAB_HEIGHT - OUTPUT_HEIGHT - STATUSBAR_HEIGHT;
 Offset := 20;
 For I := 0 To WinMgr.WinCount - 1 Do Begin
  WinMgr.Windows[I].X := ZX + I * Offset;
  WinMgr.Windows[I].Y := ZY + I * Offset;
  WinMgr.Windows[I].Width := ZW - (WinMgr.WinCount - 1) * Offset;
  WinMgr.Windows[I].Height := ZH - (WinMgr.WinCount - 1) * Offset;
  WinMgr.Windows[I].Maximized := False;
  WinMgr.Windows[I].Minimized := False;
 End;
End;

{ --- Fractionner la vue --- }

Procedure SplitView;
Begin
 If WinMgr.SplitMode Then Begin
  WinMgr.SplitMode := False;
  WinMgr.SplitPos := 0;
 End Else Begin
  WinMgr.SplitMode := True;
  WinMgr.SplitPos := (GetScreenWidth - EXPLORER_WIDTH) Div 2
                      + EXPLORER_WIDTH;
 End;
End;

{ --- Compter les fenetres ouvertes --- }

Function CountEditorWindows: Integer;
Begin
 CountEditorWindows := WinMgr.WinCount;
End;

{ --- Compter les fenetres modifiees --- }

Function CountModifiedWindows: Integer;
Var
 I, Total: Integer;
Begin
 Total := 0;
 For I := 0 To WinMgr.WinCount - 1 Do
  If WinMgr.Windows[I].Modified Then
   Inc(Total);
 CountModifiedWindows := Total;
End;

{ --- Trouver une fenetre par nom de fichier --- }

Function FindWindowByFileName(AFileName: String): Integer;
Var
 I: Integer;
Begin
 FindWindowByFileName := -1;
 For I := 0 To WinMgr.WinCount - 1 Do
  If WinMgr.Windows[I].FileName = AFileName Then Begin
   FindWindowByFileName := I;
   Exit;
  End;
End;

{ --- Determiner si un index de fenetre est valide --- }

Function IsValidWindowIndex(Index: Integer): Boolean;
Begin
 IsValidWindowIndex := (Index >= 0) And (Index < WinMgr.WinCount);
End;

{ --- Obtenir le titre d une fenetre --- }

Function GetWindowTitle(Index: Integer): String;
Begin
 If IsValidWindowIndex(Index) Then
  GetWindowTitle := WinMgr.Windows[Index].Title
 Else
  GetWindowTitle := '';
End;

{ --- Definir le titre d une fenetre --- }

Procedure SetWindowTitle(Index: Integer; ATitle: String);
Begin
 If IsValidWindowIndex(Index) Then
  WinMgr.Windows[Index].Title := ATitle;
End;

{ --- Marquer une fenetre comme modifiee --- }

Procedure MarkWindowModified(Index: Integer);
Begin
 If IsValidWindowIndex(Index) Then
  WinMgr.Windows[Index].Modified := True;
End;

{ --- Marquer une fenetre comme sauvegardee --- }

Procedure MarkWindowSaved(Index: Integer);
Begin
 If IsValidWindowIndex(Index) Then
  WinMgr.Windows[Index].Modified := False;
End;

{ ============================================================
  TODO 08 - TAMPON DE TEXTE ET GESTION DES LIGNES [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser un tampon de texte --- }

Procedure InitBuffer(Var Buf: TTextBuffer);
Var
 I: LongInt;
Begin
 For I := 0 To MAX_LINES - 1 Do
  Buf.Lines[I] := '';
 Buf.LineCount := 1;  { au moins une ligne vide }
 Buf.Modified := False;
 Buf.FileName := '';
 Buf.Encoding := FE_ASCII;
 Buf.LineEnd := LE_CRLF;
End;

{ --- Liberer un tampon de texte --- }

Procedure FreeBuffer(Var Buf: TTextBuffer);
Var
 I: LongInt;
Begin
 For I := 0 To MAX_LINES - 1 Do
  Buf.Lines[I] := '';
 Buf.LineCount := 0;
 Buf.Modified := False;
 Buf.FileName := '';
End;

{ --- Detecter l encodage d une ligne --- }

Function DetectEncoding(S: String): TFileEncoding;
Var
 I: Integer;
Begin
 DetectEncoding := FE_ASCII;
 For I := 1 To Length(S) Do
  If Ord(S[I]) > 127 Then Begin
   DetectEncoding := FE_UTF8;
   Exit;
  End;
End;

{ --- Detecter le type de fin de ligne --- }

Function DetectLineEnding(S: String): TLineEnding;
Var
 I: Integer;
Begin
 DetectLineEnding := LE_LF;  { defaut Unix }
 For I := 1 To Length(S) Do Begin
  If S[I] = #13 Then Begin
   If (I < Length(S)) And (S[I + 1] = #10) Then Begin
    DetectLineEnding := LE_CRLF;
    Exit;
   End Else Begin
    DetectLineEnding := LE_CR;
    Exit;
   End;
  End;
  If S[I] = #10 Then Begin
   DetectLineEnding := LE_LF;
   Exit;
  End;
 End;
End;

{ --- Charger un fichier dans le tampon --- }

Procedure LoadFile(Var Buf: TTextBuffer; AFileName: String);
Var
 F: Text;
 S: String;
 FirstLine: Boolean;
Begin
 InitBuffer(Buf);
 Buf.FileName := AFileName;
 Buf.LineCount := 0;
 {$I-}
 Assign(F, AFileName);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Begin
  Buf.LineCount := 1;
  Buf.Lines[0] := '';
  Exit;
 End;
 FirstLine := True;
 While Not Eof(F) Do Begin
  ReadLn(F, S);
  If FirstLine Then Begin
   Buf.Encoding := DetectEncoding(S);
   FirstLine := False;
  End;
  If Buf.LineCount < MAX_LINES Then Begin
   Buf.Lines[Buf.LineCount] := S;
   Inc(Buf.LineCount);
  End;
 End;
 Close(F);
 If Buf.LineCount = 0 Then Begin
  Buf.LineCount := 1;
  Buf.Lines[0] := '';
 End;
 Buf.Modified := False;
End;

{ --- Obtenir le suffixe de fin de ligne --- }

Function LineEndStr(LE: TLineEnding): String;
Begin
 Case LE Of
  LE_CRLF: LineEndStr := #13#10;
  LE_LF:   LineEndStr := #10;
  LE_CR:   LineEndStr := #13;
 Else
  LineEndStr := #13#10;
 End;
End;

{ --- Sauvegarder le tampon dans un fichier --- }

Procedure SaveFile(Var Buf: TTextBuffer; AFileName: String);
Var
 F: Text;
 I: LongInt;
Begin
 If Length(AFileName) = 0 Then Exit;
 {$I-}
 Assign(F, AFileName);
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 For I := 0 To Buf.LineCount - 1 Do
  WriteLn(F, Buf.Lines[I]);
 Close(F);
 Buf.FileName := AFileName;
 Buf.Modified := False;
End;

{ --- Obtenir une ligne du tampon --- }

Function GetLine(Var Buf: TTextBuffer; N: LongInt): String;
Begin
 If (N >= 0) And (N < Buf.LineCount) Then
  GetLine := Buf.Lines[N]
 Else
  GetLine := '';
End;

{ --- Definir une ligne du tampon --- }

Procedure SetLine(Var Buf: TTextBuffer; N: LongInt; S: String);
Begin
 If (N >= 0) And (N < Buf.LineCount) Then Begin
  Buf.Lines[N] := S;
  Buf.Modified := True;
 End;
End;

{ --- Inserer une ligne dans le tampon --- }

Procedure InsertLine(Var Buf: TTextBuffer; N: LongInt; S: String);
Var
 I: LongInt;
Begin
 If Buf.LineCount >= MAX_LINES Then Exit;
 If N < 0 Then N := 0;
 If N > Buf.LineCount Then N := Buf.LineCount;
 { Decaler vers le bas }
 For I := Buf.LineCount - 1 DownTo N Do
  Buf.Lines[I + 1] := Buf.Lines[I];
 Buf.Lines[N] := S;
 Inc(Buf.LineCount);
 Buf.Modified := True;
End;

{ --- Supprimer une ligne du tampon --- }

Procedure DeleteLine(Var Buf: TTextBuffer; N: LongInt);
Var
 I: LongInt;
Begin
 If (N < 0) Or (N >= Buf.LineCount) Then Exit;
 If Buf.LineCount <= 1 Then Begin
  Buf.Lines[0] := '';
  Buf.Modified := True;
  Exit;
 End;
 For I := N To Buf.LineCount - 2 Do
  Buf.Lines[I] := Buf.Lines[I + 1];
 Buf.Lines[Buf.LineCount - 1] := '';
 Dec(Buf.LineCount);
 Buf.Modified := True;
End;

{ --- Inserer un caractere dans le tampon --- }

Procedure InsertChar(Var Buf: TTextBuffer; ALine, ACol: LongInt;
                     Ch: Char);
Var
 S: String;
Begin
 If (ALine < 0) Or (ALine >= Buf.LineCount) Then Exit;
 S := Buf.Lines[ALine];
 If ACol < 1 Then ACol := 1;
 If ACol > Length(S) + 1 Then Begin
  { Etendre avec des espaces }
  While Length(S) < ACol - 1 Do
   S := S + ' ';
 End;
 Insert(Ch, S, ACol);
 Buf.Lines[ALine] := S;
 Buf.Modified := True;
End;

{ --- Supprimer un caractere du tampon --- }

Procedure DeleteChar(Var Buf: TTextBuffer; ALine, ACol: LongInt);
Var
 S: String;
Begin
 If (ALine < 0) Or (ALine >= Buf.LineCount) Then Exit;
 S := Buf.Lines[ALine];
 If (ACol >= 1) And (ACol <= Length(S)) Then Begin
  Delete(S, ACol, 1);
  Buf.Lines[ALine] := S;
  Buf.Modified := True;
 End Else If (ACol > Length(S)) And (ALine < Buf.LineCount - 1) Then Begin
  { Joindre avec la ligne suivante }
  Buf.Lines[ALine] := S + Buf.Lines[ALine + 1];
  DeleteLine(Buf, ALine + 1);
 End;
End;

{ --- Inserer du texte (sans retour a la ligne) --- }

Procedure InsertText(Var Buf: TTextBuffer; ALine, ACol: LongInt;
                     AText: String);
Var
 S: String;
Begin
 If (ALine < 0) Or (ALine >= Buf.LineCount) Then Exit;
 S := Buf.Lines[ALine];
 If ACol < 1 Then ACol := 1;
 While Length(S) < ACol - 1 Do
  S := S + ' ';
 Insert(AText, S, ACol);
 Buf.Lines[ALine] := S;
 Buf.Modified := True;
End;

{ --- Supprimer une plage de texte --- }

Procedure DeleteRange(Var Buf: TTextBuffer;
                      L1, C1, L2, C2: LongInt);
Var
 Before, After: String;
 I: LongInt;
Begin
 If L1 > L2 Then Exit;
 If (L1 = L2) And (C1 > C2) Then Exit;
 If (L1 < 0) Or (L2 >= Buf.LineCount) Then Exit;
 { Partie a garder avant la selection }
 Before := Copy(Buf.Lines[L1], 1, C1 - 1);
 { Partie a garder apres la selection }
 If C2 <= Length(Buf.Lines[L2]) Then
  After := Copy(Buf.Lines[L2], C2 + 1,
                Length(Buf.Lines[L2]) - C2)
 Else
  After := '';
 { Remplacer la premiere ligne }
 Buf.Lines[L1] := Before + After;
 { Supprimer les lignes intermediaires }
 If L2 > L1 Then Begin
  For I := 1 To L2 - L1 Do
   DeleteLine(Buf, L1 + 1);
 End;
 Buf.Modified := True;
End;

{ --- Obtenir le texte d une plage --- }

Function GetTextRange(Var Buf: TTextBuffer;
                      L1, C1, L2, C2: LongInt): String;
Var
 R: String;
 I: LongInt;
Begin
 R := '';
 If (L1 < 0) Or (L2 >= Buf.LineCount) Then Begin
  GetTextRange := '';
  Exit;
 End;
 If L1 = L2 Then Begin
  { Selection sur une seule ligne }
  R := Copy(Buf.Lines[L1], C1, C2 - C1 + 1);
 End Else Begin
  { Premiere ligne partielle }
  R := Copy(Buf.Lines[L1], C1,
            Length(Buf.Lines[L1]) - C1 + 1);
  R := R + #13#10;
  { Lignes intermediaires completes }
  For I := L1 + 1 To L2 - 1 Do Begin
   R := R + Buf.Lines[I] + #13#10;
  End;
  { Derniere ligne partielle }
  R := R + Copy(Buf.Lines[L2], 1, C2);
 End;
 GetTextRange := R;
End;

{ --- Obtenir le nombre de lignes --- }

Function GetLineCount(Var Buf: TTextBuffer): LongInt;
Begin
 GetLineCount := Buf.LineCount;
End;

{ --- Obtenir le nombre total de caracteres --- }

Function GetTotalChars(Var Buf: TTextBuffer): LongInt;
Var
 I: LongInt;
 Total: LongInt;
Begin
 Total := 0;
 For I := 0 To Buf.LineCount - 1 Do
  Total := Total + Length(Buf.Lines[I]);
 GetTotalChars := Total;
End;

{ --- Tampon modifie ? --- }

Function IsBufferModified(Var Buf: TTextBuffer): Boolean;
Begin
 IsBufferModified := Buf.Modified;
End;

{ --- Marquer le tampon comme sauvegarde --- }

Procedure MarkBufferSaved(Var Buf: TTextBuffer);
Begin
 Buf.Modified := False;
End;

{ --- Compter les lignes non vides --- }

Function CountNonEmptyLines(Var Buf: TTextBuffer): LongInt;
Var
 I: LongInt;
 Total: LongInt;
Begin
 Total := 0;
 For I := 0 To Buf.LineCount - 1 Do
  If Length(Buf.Lines[I]) > 0 Then
   Inc(Total);
 CountNonEmptyLines := Total;
End;

{ --- Chercher du texte dans le tampon (premiere occurrence) --- }

Function FindInBuffer(Var Buf: TTextBuffer; AText: String;
                      StartLine, StartCol: LongInt;
                      Var FoundLine, FoundCol: LongInt): Boolean;
Var
 I: LongInt;
 P: Integer;
 S: String;
Begin
 FindInBuffer := False;
 For I := StartLine To Buf.LineCount - 1 Do Begin
  S := Buf.Lines[I];
  If I = StartLine Then
   P := Pos(AText, Copy(S, StartCol, Length(S) - StartCol + 1))
  Else
   P := Pos(AText, S);
  If P > 0 Then Begin
   FoundLine := I;
   If I = StartLine Then
    FoundCol := StartCol + P - 1
   Else
    FoundCol := P;
   FindInBuffer := True;
   Exit;
  End;
 End;
End;

{ ============================================================
  TODO 09 - EDITEUR DE TEXTE : EDITION DE BASE [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser un editeur --- }

Procedure InitEditor(Var Ed: TEditor);
Begin
 InitBuffer(Ed.Buffer);
 Ed.CursorLine := 0;
 Ed.CursorCol := 1;
 Ed.ScrollLine := 0;
 Ed.ScrollCol := 1;
 Ed.InsertMode := True;
 Ed.TabSize := 4;
 Ed.AutoIndent := True;
 Ed.ShowLineNumbers := True;
 Ed.ShowWhitespace := False;
 Ed.GutterWidth := 50;
 Ed.CharWidth := 8;
 Ed.CharHeight := 14;
 Ed.X := EXPLORER_WIDTH;
 Ed.Y := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + TAB_HEIGHT;
 Ed.Width := GetScreenWidth - EXPLORER_WIDTH;
 Ed.Height := GetScreenHeight - MENUBAR_HEIGHT - TOOLBAR_HEIGHT
              - TAB_HEIGHT - STATUSBAR_HEIGHT - OUTPUT_HEIGHT;
 If Ed.Height < Ed.CharHeight Then
  Ed.Height := Ed.CharHeight;
 If Ed.Width < Ed.GutterWidth + Ed.CharWidth Then
  Ed.Width := Ed.GutterWidth + Ed.CharWidth;
 Ed.VisibleLines := Ed.Height Div Ed.CharHeight;
 Ed.VisibleCols := (Ed.Width - Ed.GutterWidth) Div Ed.CharWidth;
End;

{ --- Calculer la largeur de gouttiere selon le nombre de lignes --- }

Function CalcGutterWidth(LineCount: LongInt; CharWidth: Integer): Integer;
Var
 Digits: Integer;
 N: LongInt;
Begin
 Digits := 1;
 N := LineCount;
 While N >= 10 Do Begin
  Inc(Digits);
  N := N Div 10;
 End;
 If Digits < 4 Then Digits := 4;  { minimum 4 chiffres }
 CalcGutterWidth := (Digits + 1) * CharWidth;
End;

{ --- Dessiner la gouttiere (numeros de ligne) --- }

Procedure DrawGutter(Var Ed: TEditor);
Var
 I: Integer;
 LineNo: LongInt;
 S: String;
 YPos: Integer;
Begin
 SetColor(CLR_EDITOR_GUTTER);
 SetFillStyle(SolidFill, CLR_EDITOR_GUTTER);
 Bar(Ed.X, Ed.Y, Ed.X + Ed.GutterWidth - 1, Ed.Y + Ed.Height - 1);
 SetColor(CLR_BORDER);
 Line(Ed.X + Ed.GutterWidth - 1, Ed.Y,
      Ed.X + Ed.GutterWidth - 1, Ed.Y + Ed.Height - 1);
 For I := 0 To Ed.VisibleLines - 1 Do Begin
  LineNo := Ed.ScrollLine + I;
  If LineNo < Ed.Buffer.LineCount Then Begin
   Str(LineNo + 1, S);
   YPos := Ed.Y + I * Ed.CharHeight;
   If LineNo = Ed.CursorLine Then
    SetColor(CLR_EDITOR_TEXT)
   Else
    SetColor(CLR_BORDER);
   OutTextXY(Ed.X + Ed.GutterWidth - (Length(S) + 1) * Ed.CharWidth,
             YPos + 1, S);
  End;
 End;
End;

{ --- Dessiner la surbrillance de la ligne courante --- }

Procedure DrawLineHighlight(Var Ed: TEditor);
Var
 YPos: Integer;
Begin
 If (Ed.CursorLine >= Ed.ScrollLine) And
    (Ed.CursorLine < Ed.ScrollLine + Ed.VisibleLines) Then Begin
  YPos := Ed.Y + (Ed.CursorLine - Ed.ScrollLine) * Ed.CharHeight;
  SetColor(CLR_LINE_HIGHLIGHT);
  SetFillStyle(SolidFill, CLR_LINE_HIGHLIGHT);
  Bar(Ed.X + Ed.GutterWidth, YPos,
      Ed.X + Ed.Width - 1, YPos + Ed.CharHeight - 1);
 End;
End;

{ --- Dessiner le curseur --- }

Procedure DrawCursor(Var Ed: TEditor);
Var
 XPos, YPos: Integer;
Begin
 If (Ed.CursorLine >= Ed.ScrollLine) And
    (Ed.CursorLine < Ed.ScrollLine + Ed.VisibleLines) And
    (Ed.CursorCol >= Ed.ScrollCol) And
    (Ed.CursorCol < Ed.ScrollCol + Ed.VisibleCols) Then Begin
  XPos := Ed.X + Ed.GutterWidth +
          (Ed.CursorCol - Ed.ScrollCol) * Ed.CharWidth;
  YPos := Ed.Y + (Ed.CursorLine - Ed.ScrollLine) * Ed.CharHeight;
  SetColor(CLR_CURSOR);
  If Ed.InsertMode Then Begin
   { Mode insertion : barre verticale }
   Line(XPos, YPos, XPos, YPos + Ed.CharHeight - 1);
  End Else Begin
   { Mode remplacement : bloc plein }
   SetFillStyle(SolidFill, CLR_CURSOR);
   Bar(XPos, YPos, XPos + Ed.CharWidth - 1, YPos + Ed.CharHeight - 1);
  End;
 End;
End;

{ --- Dessiner l editeur complet --- }

Procedure DrawEditor(Var Ed: TEditor);
Var
 I: Integer;
 LineNo: LongInt;
 S: String;
 XPos, YPos: Integer;
 Len: Integer;
Begin
 { Mettre a jour la gouttiere }
 Ed.GutterWidth := CalcGutterWidth(Ed.Buffer.LineCount, Ed.CharWidth);
 Ed.VisibleCols := (Ed.Width - Ed.GutterWidth) Div Ed.CharWidth;
 { Effacer la zone de l editeur }
 SetColor(CLR_EDITOR_BG);
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(Ed.X + Ed.GutterWidth, Ed.Y,
     Ed.X + Ed.Width - 1, Ed.Y + Ed.Height - 1);
 { Dessiner la surbrillance de la ligne courante }
 DrawLineHighlight(Ed);
 { Dessiner le texte }
 SetColor(CLR_EDITOR_TEXT);
 For I := 0 To Ed.VisibleLines - 1 Do Begin
  LineNo := Ed.ScrollLine + I;
  If LineNo < Ed.Buffer.LineCount Then Begin
   S := Ed.Buffer.Lines[LineNo];
   YPos := Ed.Y + I * Ed.CharHeight;
   XPos := Ed.X + Ed.GutterWidth;
   { Extraire la partie visible }
   If Ed.ScrollCol <= Length(S) Then Begin
    Len := Length(S) - Ed.ScrollCol + 1;
    If Len > Ed.VisibleCols Then Len := Ed.VisibleCols;
    S := Copy(S, Ed.ScrollCol, Len);
   End Else
    S := '';
   If LineNo = Ed.CursorLine Then
    SetColor(CLR_EDITOR_TEXT)
   Else
    SetColor(CLR_EDITOR_TEXT);
   OutTextXY(XPos, YPos + 1, S);
  End;
 End;
 { Dessiner la gouttiere }
 DrawGutter(Ed);
 { Dessiner le curseur }
 DrawCursor(Ed);
End;

{ --- Assurer que le curseur est visible (defilement automatique) --- }

Procedure EnsureCursorVisible(Var Ed: TEditor);
Begin
 { Defilement vertical }
 If Ed.CursorLine < Ed.ScrollLine Then
  Ed.ScrollLine := Ed.CursorLine;
 If Ed.CursorLine >= Ed.ScrollLine + Ed.VisibleLines Then
  Ed.ScrollLine := Ed.CursorLine - Ed.VisibleLines + 1;
 If Ed.ScrollLine < 0 Then
  Ed.ScrollLine := 0;
 { Defilement horizontal }
 If Ed.CursorCol < Ed.ScrollCol Then
  Ed.ScrollCol := Ed.CursorCol;
 If Ed.CursorCol >= Ed.ScrollCol + Ed.VisibleCols Then
  Ed.ScrollCol := Ed.CursorCol - Ed.VisibleCols + 1;
 If Ed.ScrollCol < 1 Then
  Ed.ScrollCol := 1;
End;

{ --- Aller a une ligne donnee --- }

Procedure GotoLine(Var Ed: TEditor; ALine: LongInt);
Begin
 If ALine < 0 Then ALine := 0;
 If ALine >= Ed.Buffer.LineCount Then
  ALine := Ed.Buffer.LineCount - 1;
 Ed.CursorLine := ALine;
 EnsureCursorVisible(Ed);
End;

{ --- Aller a une colonne donnee --- }

Procedure GotoColumn(Var Ed: TEditor; ACol: LongInt);
Begin
 If ACol < 1 Then ACol := 1;
 Ed.CursorCol := ACol;
 EnsureCursorVisible(Ed);
End;

{ --- Obtenir l indentation de la ligne courante --- }

Function GetIndentation(S: String): String;
Var
 I: Integer;
Begin
 I := 1;
 While (I <= Length(S)) And (S[I] In [' ', #9]) Do
  Inc(I);
 GetIndentation := Copy(S, 1, I - 1);
End;

{ --- Gerer les touches de l editeur --- }

Procedure HandleEditorKey(Var Ed: TEditor; Ev: TEvent);
Var
 S, Indent: String;
 LineLen: Integer;
 TabStr: String;
 I: Integer;
Begin
 { Traiter les caracteres (EV_KEY_CHAR) }
 If Ev.Kind = EV_KEY_CHAR Then Begin
  Case Ev.KeyChar Of
   { Backspace }
   #8: Begin
    If Ed.CursorCol > 1 Then Begin
     Dec(Ed.CursorCol);
     DeleteChar(Ed.Buffer, Ed.CursorLine, Ed.CursorCol);
    End Else If Ed.CursorLine > 0 Then Begin
     LineLen := Length(Ed.Buffer.Lines[Ed.CursorLine - 1]);
     Ed.Buffer.Lines[Ed.CursorLine - 1] :=
      Ed.Buffer.Lines[Ed.CursorLine - 1] +
      Ed.Buffer.Lines[Ed.CursorLine];
     DeleteLine(Ed.Buffer, Ed.CursorLine);
     Dec(Ed.CursorLine);
     Ed.CursorCol := LineLen + 1;
     Ed.Buffer.Modified := True;
    End;
    EnsureCursorVisible(Ed);
   End;
   { Tab }
   #9: Begin
    TabStr := '';
    For I := 1 To Ed.TabSize Do
     TabStr := TabStr + ' ';
    InsertText(Ed.Buffer, Ed.CursorLine, Ed.CursorCol, TabStr);
    Inc(Ed.CursorCol, Ed.TabSize);
    EnsureCursorVisible(Ed);
   End;
   { Enter }
   #13: Begin
    S := Ed.Buffer.Lines[Ed.CursorLine];
    InsertLine(Ed.Buffer, Ed.CursorLine + 1,
               Copy(S, Ed.CursorCol, Length(S) - Ed.CursorCol + 1));
    Ed.Buffer.Lines[Ed.CursorLine] :=
     Copy(S, 1, Ed.CursorCol - 1);
    Ed.Buffer.Modified := True;
    Inc(Ed.CursorLine);
    If Ed.AutoIndent Then Begin
     Indent := GetIndentation(
      Ed.Buffer.Lines[Ed.CursorLine - 1]);
     If Length(Indent) > 0 Then Begin
      Ed.Buffer.Lines[Ed.CursorLine] :=
       Indent + Ed.Buffer.Lines[Ed.CursorLine];
      Ed.CursorCol := Length(Indent) + 1;
     End Else
      Ed.CursorCol := 1;
    End Else
     Ed.CursorCol := 1;
    EnsureCursorVisible(Ed);
   End;
  Else
   { Caracteres imprimables }
   If (Ord(Ev.KeyChar) >= 32) And (Ord(Ev.KeyChar) <= 126) Then Begin
    If Ed.InsertMode Then Begin
     InsertChar(Ed.Buffer, Ed.CursorLine, Ed.CursorCol,
                Ev.KeyChar);
    End Else Begin
     S := Ed.Buffer.Lines[Ed.CursorLine];
     If Ed.CursorCol <= Length(S) Then
      S[Ed.CursorCol] := Ev.KeyChar
     Else
      S := S + Ev.KeyChar;
     Ed.Buffer.Lines[Ed.CursorLine] := S;
     Ed.Buffer.Modified := True;
    End;
    Inc(Ed.CursorCol);
    EnsureCursorVisible(Ed);
   End;
  End;
  Exit;
 End;

 { Traiter les touches speciales (EV_KEY_DOWN) }
 If Ev.Kind <> EV_KEY_DOWN Then Exit;

 Case Ev.KeyCode Of
  { Fleche haut }
  72: Begin
   If Ed.CursorLine > 0 Then Begin
    Dec(Ed.CursorLine);
    LineLen := Length(Ed.Buffer.Lines[Ed.CursorLine]);
    If Ed.CursorCol > LineLen + 1 Then
     Ed.CursorCol := LineLen + 1;
   End;
   EnsureCursorVisible(Ed);
  End;
  { Fleche bas }
  80: Begin
   If Ed.CursorLine < Ed.Buffer.LineCount - 1 Then Begin
    Inc(Ed.CursorLine);
    LineLen := Length(Ed.Buffer.Lines[Ed.CursorLine]);
    If Ed.CursorCol > LineLen + 1 Then
     Ed.CursorCol := LineLen + 1;
   End;
   EnsureCursorVisible(Ed);
  End;
  { Fleche gauche }
  75: Begin
   If Ed.CursorCol > 1 Then
    Dec(Ed.CursorCol)
   Else If Ed.CursorLine > 0 Then Begin
    Dec(Ed.CursorLine);
    Ed.CursorCol := Length(Ed.Buffer.Lines[Ed.CursorLine]) + 1;
   End;
   EnsureCursorVisible(Ed);
  End;
  { Fleche droite }
  77: Begin
   LineLen := Length(Ed.Buffer.Lines[Ed.CursorLine]);
   If Ed.CursorCol <= LineLen Then
    Inc(Ed.CursorCol)
   Else If Ed.CursorLine < Ed.Buffer.LineCount - 1 Then Begin
    Inc(Ed.CursorLine);
    Ed.CursorCol := 1;
   End;
   EnsureCursorVisible(Ed);
  End;
  { Home }
  71: Begin
   Ed.CursorCol := 1;
   EnsureCursorVisible(Ed);
  End;
  { End }
  79: Begin
   Ed.CursorCol := Length(Ed.Buffer.Lines[Ed.CursorLine]) + 1;
   EnsureCursorVisible(Ed);
  End;
  { PgUp }
  73: Begin
   Dec(Ed.CursorLine, Ed.VisibleLines);
   If Ed.CursorLine < 0 Then Ed.CursorLine := 0;
   Dec(Ed.ScrollLine, Ed.VisibleLines);
   If Ed.ScrollLine < 0 Then Ed.ScrollLine := 0;
   LineLen := Length(Ed.Buffer.Lines[Ed.CursorLine]);
   If Ed.CursorCol > LineLen + 1 Then
    Ed.CursorCol := LineLen + 1;
   EnsureCursorVisible(Ed);
  End;
  { PgDn }
  81: Begin
   Inc(Ed.CursorLine, Ed.VisibleLines);
   If Ed.CursorLine >= Ed.Buffer.LineCount Then
    Ed.CursorLine := Ed.Buffer.LineCount - 1;
   Inc(Ed.ScrollLine, Ed.VisibleLines);
   If Ed.ScrollLine > Ed.Buffer.LineCount - Ed.VisibleLines Then Begin
    Ed.ScrollLine := Ed.Buffer.LineCount - Ed.VisibleLines;
    If Ed.ScrollLine < 0 Then Ed.ScrollLine := 0;
   End;
   LineLen := Length(Ed.Buffer.Lines[Ed.CursorLine]);
   If Ed.CursorCol > LineLen + 1 Then
    Ed.CursorCol := LineLen + 1;
   EnsureCursorVisible(Ed);
  End;
  { Insert }
  82: Begin
   Ed.InsertMode := Not Ed.InsertMode;
  End;
  { Delete }
  83: Begin
   DeleteChar(Ed.Buffer, Ed.CursorLine, Ed.CursorCol);
  End;
 End;
End;

{ --- Ctrl+Home : debut du fichier --- }

Procedure EditorCtrlHome(Var Ed: TEditor);
Begin
 Ed.CursorLine := 0;
 Ed.CursorCol := 1;
 Ed.ScrollLine := 0;
 Ed.ScrollCol := 1;
End;

{ --- Ctrl+End : fin du fichier --- }

Procedure EditorCtrlEnd(Var Ed: TEditor);
Begin
 If Ed.Buffer.LineCount > 0 Then Begin
  Ed.CursorLine := Ed.Buffer.LineCount - 1;
  Ed.CursorCol := Length(Ed.Buffer.Lines[Ed.CursorLine]) + 1;
 End Else Begin
  Ed.CursorLine := 0;
  Ed.CursorCol := 1;
 End;
 EnsureCursorVisible(Ed);
End;

{ --- Verifier si le curseur est a une position valide --- }

Function IsCursorValid(Var Ed: TEditor): Boolean;
Begin
 IsCursorValid := (Ed.CursorLine >= 0) And
                  (Ed.CursorLine < Ed.Buffer.LineCount) And
                  (Ed.CursorCol >= 1);
End;

{ --- Obtenir le numero de la ligne courante (1-based) --- }

Function GetCursorLineNumber(Var Ed: TEditor): LongInt;
Begin
 GetCursorLineNumber := Ed.CursorLine + 1;
End;

{ --- Obtenir le numero de la colonne courante --- }

Function GetCursorColumnNumber(Var Ed: TEditor): LongInt;
Begin
 GetCursorColumnNumber := Ed.CursorCol;
End;

{ --- Obtenir le contenu de la ligne courante --- }

Function GetCurrentLine(Var Ed: TEditor): String;
Begin
 If (Ed.CursorLine >= 0) And
    (Ed.CursorLine < Ed.Buffer.LineCount) Then
  GetCurrentLine := Ed.Buffer.Lines[Ed.CursorLine]
 Else
  GetCurrentLine := '';
End;

{ --- Obtenir le caractere sous le curseur --- }

Function GetCharAtCursor(Var Ed: TEditor): Char;
Var
 S: String;
Begin
 S := GetCurrentLine(Ed);
 If (Ed.CursorCol >= 1) And (Ed.CursorCol <= Length(S)) Then
  GetCharAtCursor := S[Ed.CursorCol]
 Else
  GetCharAtCursor := ' ';
End;

{ --- Compter les lignes visibles non vides --- }

Function CountVisibleNonEmpty(Var Ed: TEditor): Integer;
Var
 I: Integer;
 Count: Integer;
 LineNo: LongInt;
Begin
 Count := 0;
 For I := 0 To Ed.VisibleLines - 1 Do Begin
  LineNo := Ed.ScrollLine + I;
  If (LineNo >= 0) And (LineNo < Ed.Buffer.LineCount) Then
   If Length(Ed.Buffer.Lines[LineNo]) > 0 Then
    Inc(Count);
 End;
 CountVisibleNonEmpty := Count;
End;

{ --- Verifier si l editeur est en mode insertion --- }

Function IsInsertMode(Var Ed: TEditor): Boolean;
Begin
 IsInsertMode := Ed.InsertMode;
End;

{ ============================================================
  TODO 10 - EDITEUR DE TEXTE : SELECTION, PRESSE-PAPIER, ANNULER
  ============================================================ }

{ --- Initialiser une selection --- }

Procedure InitSelection(Var Sel: TSelection);
Begin
 Sel.StartLine := 0;
 Sel.StartCol := 1;
 Sel.EndLine := 0;
 Sel.EndCol := 1;
 Sel.Active := False;
End;

{ --- Demarrer une selection --- }

Procedure StartSelection(Var Sel: TSelection; Line, Col: LongInt);
Begin
 Sel.StartLine := Line;
 Sel.StartCol := Col;
 Sel.EndLine := Line;
 Sel.EndCol := Col;
 Sel.Active := True;
End;

{ --- Etendre la selection --- }

Procedure ExtendSelection(Var Sel: TSelection; Line, Col: LongInt);
Begin
 If Not Sel.Active Then Begin
  Sel.StartLine := Line;
  Sel.StartCol := Col;
  Sel.Active := True;
 End;
 Sel.EndLine := Line;
 Sel.EndCol := Col;
End;

{ --- Desactiver la selection --- }

Procedure ClearSelection(Var Sel: TSelection);
Begin
 Sel.Active := False;
End;

{ --- Verifier si la selection est active --- }

Function IsSelectionActive(Var Sel: TSelection): Boolean;
Begin
 IsSelectionActive := Sel.Active;
End;

{ --- Obtenir la selection ordonnee (debut <= fin) --- }

Procedure GetOrderedSelection(Var Sel: TSelection;
 Var SL, SC, EL, EC: LongInt);
Begin
 If (Sel.StartLine < Sel.EndLine) Or
    ((Sel.StartLine = Sel.EndLine) And
     (Sel.StartCol <= Sel.EndCol)) Then Begin
  SL := Sel.StartLine;
  SC := Sel.StartCol;
  EL := Sel.EndLine;
  EC := Sel.EndCol;
 End Else Begin
  SL := Sel.EndLine;
  SC := Sel.EndCol;
  EL := Sel.StartLine;
  EC := Sel.StartCol;
 End;
End;

{ --- Dessiner la selection --- }

Procedure DrawSelection(Var Ed: TEditor; Var Sel: TSelection);
Var
 SL, SC, EL, EC: LongInt;
 I: LongInt;
 X1, X2, Y1: Integer;
 LineLen: Integer;
Begin
 If Not Sel.Active Then Exit;
 GetOrderedSelection(Sel, SL, SC, EL, EC);
 For I := SL To EL Do Begin
  If (I < Ed.ScrollLine) Or
     (I >= Ed.ScrollLine + Ed.VisibleLines) Then Continue;
  Y1 := Ed.Y + (I - Ed.ScrollLine) * Ed.CharHeight;
  If I = SL Then
   X1 := Ed.X + Ed.GutterWidth +
    (SC - Ed.ScrollCol) * Ed.CharWidth
  Else
   X1 := Ed.X + Ed.GutterWidth;
  If I = EL Then
   X2 := Ed.X + Ed.GutterWidth +
    (EC - Ed.ScrollCol) * Ed.CharWidth
  Else Begin
   If (I >= 0) And (I < Ed.Buffer.LineCount) Then
    LineLen := Length(Ed.Buffer.Lines[I])
   Else
    LineLen := 0;
   X2 := Ed.X + Ed.GutterWidth +
    (LineLen + 1 - Ed.ScrollCol) * Ed.CharWidth;
  End;
  If X1 < Ed.X + Ed.GutterWidth Then
   X1 := Ed.X + Ed.GutterWidth;
  If X2 > Ed.X + Ed.Width Then
   X2 := Ed.X + Ed.Width;
  If X2 > X1 Then Begin
   SetFillStyle(SolidFill, CLR_SELECTION);
   Bar(X1, Y1, X2 - 1, Y1 + Ed.CharHeight - 1);
  End;
 End;
End;

{ --- Obtenir le texte selectionne --- }

Function GetSelectedText(Var Ed: TEditor;
 Var Sel: TSelection): String;
Var
 SL, SC, EL, EC: LongInt;
 Result: String;
 I: LongInt;
 Line: String;
Begin
 Result := '';
 If Not Sel.Active Then Begin
  GetSelectedText := '';
  Exit;
 End;
 GetOrderedSelection(Sel, SL, SC, EL, EC);
 If SL = EL Then Begin
  Line := GetLine(Ed.Buffer, SL);
  If (SC >= 1) And (EC >= SC) And (SC <= Length(Line) + 1) Then Begin
   If EC > Length(Line) + 1 Then
    EC := Length(Line) + 1;
   Result := Copy(Line, SC, EC - SC);
  End;
 End Else Begin
  Line := GetLine(Ed.Buffer, SL);
  If SC <= Length(Line) Then
   Result := Copy(Line, SC, Length(Line) - SC + 1)
  Else
   Result := '';
  For I := SL + 1 To EL - 1 Do
   Result := Result + #10 + GetLine(Ed.Buffer, I);
  Line := GetLine(Ed.Buffer, EL);
  If EC > 1 Then
   Result := Result + #10 + Copy(Line, 1, EC - 1)
  Else
   Result := Result + #10;
 End;
 GetSelectedText := Result;
End;

{ --- Supprimer le texte selectionne --- }

Procedure DeleteSelectedText(Var Ed: TEditor; Var Sel: TSelection);
Var
 SL, SC, EL, EC: LongInt;
 HeadPart, TailPart: String;
 I: LongInt;
Begin
 If Not Sel.Active Then Exit;
 GetOrderedSelection(Sel, SL, SC, EL, EC);
 If SL = EL Then Begin
  HeadPart := GetLine(Ed.Buffer, SL);
  TailPart := Copy(HeadPart, EC, Length(HeadPart) - EC + 1);
  HeadPart := Copy(HeadPart, 1, SC - 1);
  SetLine(Ed.Buffer, SL, HeadPart + TailPart);
 End Else Begin
  HeadPart := Copy(GetLine(Ed.Buffer, SL), 1, SC - 1);
  TailPart := GetLine(Ed.Buffer, EL);
  If EC <= Length(TailPart) Then
   TailPart := Copy(TailPart, EC, Length(TailPart) - EC + 1)
  Else
   TailPart := '';
  For I := EL DownTo SL + 1 Do
   DeleteLine(Ed.Buffer, I);
  SetLine(Ed.Buffer, SL, HeadPart + TailPart);
 End;
 Ed.CursorLine := SL;
 Ed.CursorCol := SC;
 ClearSelection(Sel);
End;

{ --- Selectionner tout --- }

Procedure SelectAll(Var Ed: TEditor; Var Sel: TSelection);
Var
 LastLine: LongInt;
Begin
 Sel.StartLine := 0;
 Sel.StartCol := 1;
 LastLine := Ed.Buffer.LineCount - 1;
 If LastLine < 0 Then LastLine := 0;
 Sel.EndLine := LastLine;
 Sel.EndCol := Length(Ed.Buffer.Lines[LastLine]) + 1;
 Sel.Active := True;
End;

{ --- Selectionner le mot sous le curseur --- }

Procedure SelectWordAtCursor(Var Ed: TEditor; Var Sel: TSelection);
Var
 Line: String;
 StartC, EndC: LongInt;
Begin
 Line := GetLine(Ed.Buffer, Ed.CursorLine);
 If (Ed.CursorCol < 1) Or (Ed.CursorCol > Length(Line)) Then Exit;
 If Not ((Line[Ed.CursorCol] In ['A'..'Z', 'a'..'z', '0'..'9', '_']))
  Then Exit;
 StartC := Ed.CursorCol;
 While (StartC > 1) And
  (Line[StartC - 1] In ['A'..'Z', 'a'..'z', '0'..'9', '_']) Do
  Dec(StartC);
 EndC := Ed.CursorCol;
 While (EndC < Length(Line)) And
  (Line[EndC + 1] In ['A'..'Z', 'a'..'z', '0'..'9', '_']) Do
  Inc(EndC);
 Sel.StartLine := Ed.CursorLine;
 Sel.StartCol := StartC;
 Sel.EndLine := Ed.CursorLine;
 Sel.EndCol := EndC + 1;
 Sel.Active := True;
End;

{ --- Selectionner la ligne entiere --- }

Procedure SelectLineAtCursor(Var Ed: TEditor; Var Sel: TSelection);
Var
 Line: String;
Begin
 Line := GetLine(Ed.Buffer, Ed.CursorLine);
 Sel.StartLine := Ed.CursorLine;
 Sel.StartCol := 1;
 Sel.EndLine := Ed.CursorLine;
 Sel.EndCol := Length(Line) + 1;
 Sel.Active := True;
End;

{ --- Initialiser le presse-papier --- }

Procedure InitClipboard(Var Clip: TClipboard);
Begin
 Clip.Text := '';
 Clip.HasData := False;
End;

{ --- Copier dans le presse-papier --- }

Procedure ClipboardCopy(Var Ed: TEditor; Var Sel: TSelection;
 Var Clip: TClipboard);
Begin
 If Not Sel.Active Then Exit;
 Clip.Text := GetSelectedText(Ed, Sel);
 Clip.HasData := Length(Clip.Text) > 0;
End;

{ --- Couper dans le presse-papier --- }

Procedure ClipboardCut(Var Ed: TEditor; Var Sel: TSelection;
 Var Clip: TClipboard);
Begin
 If Not Sel.Active Then Exit;
 Clip.Text := GetSelectedText(Ed, Sel);
 Clip.HasData := Length(Clip.Text) > 0;
 DeleteSelectedText(Ed, Sel);
End;

{ --- Coller depuis le presse-papier --- }

Procedure ClipboardPaste(Var Ed: TEditor; Var Sel: TSelection;
 Var Clip: TClipboard);
Var
 I: Integer;
 Ch: Char;
 LineStart: Integer;
 Fragment: String;
Begin
 If Not Clip.HasData Then Exit;
 If Sel.Active Then
  DeleteSelectedText(Ed, Sel);
 LineStart := 1;
 For I := 1 To Length(Clip.Text) Do Begin
  Ch := Clip.Text[I];
  If Ch = #10 Then Begin
   Fragment := Copy(Clip.Text, LineStart, I - LineStart);
   InsertText(Ed.Buffer, Ed.CursorLine, Ed.CursorCol, Fragment);
   Ed.CursorCol := Ed.CursorCol + Length(Fragment);
   { Inserer nouvelle ligne }
   InsertLine(Ed.Buffer, Ed.CursorLine + 1,
    Copy(GetLine(Ed.Buffer, Ed.CursorLine), Ed.CursorCol,
     Length(GetLine(Ed.Buffer, Ed.CursorLine)) - Ed.CursorCol + 1));
   SetLine(Ed.Buffer, Ed.CursorLine,
    Copy(GetLine(Ed.Buffer, Ed.CursorLine), 1, Ed.CursorCol - 1));
   Inc(Ed.CursorLine);
   Ed.CursorCol := 1;
   LineStart := I + 1;
  End;
 End;
 If LineStart <= Length(Clip.Text) Then Begin
  Fragment := Copy(Clip.Text, LineStart,
   Length(Clip.Text) - LineStart + 1);
  InsertText(Ed.Buffer, Ed.CursorLine, Ed.CursorCol, Fragment);
  Ed.CursorCol := Ed.CursorCol + Length(Fragment);
 End;
End;

{ --- Initialiser la pile d annulation --- }

Procedure InitUndoStack(Var Stack: TUndoStack);
Begin
 Stack.Count := 0;
 Stack.Top := 0;
End;

{ --- Empiler une action undo --- }

Procedure PushUndo(Var Stack: TUndoStack; Action: TUndoAction;
 Line, Col: LongInt; Text, OldText: String; GroupId: LongInt);
Var
 Idx: Integer;
Begin
 Idx := Stack.Top;
 Stack.Items[Idx].Action := Action;
 Stack.Items[Idx].Line := Line;
 Stack.Items[Idx].Col := Col;
 Stack.Items[Idx].Text := Text;
 Stack.Items[Idx].OldText := OldText;
 Stack.Items[Idx].GroupId := GroupId;
 Stack.Top := (Stack.Top + 1) Mod MAX_UNDO;
 If Stack.Count < MAX_UNDO Then
  Inc(Stack.Count);
End;

{ --- Depiler une action undo --- }

Function PopUndo(Var Stack: TUndoStack;
 Var Rec: TUndoRecord): Boolean;
Begin
 If Stack.Count = 0 Then Begin
  PopUndo := False;
  Exit;
 End;
 Dec(Stack.Count);
 Stack.Top := (Stack.Top - 1 + MAX_UNDO) Mod MAX_UNDO;
 Rec := Stack.Items[Stack.Top];
 PopUndo := True;
End;

{ --- Vider la pile d annulation --- }

Procedure ClearUndoStack(Var Stack: TUndoStack);
Begin
 Stack.Count := 0;
 Stack.Top := 0;
End;

{ --- Executer un Undo sur l editeur --- }

Procedure Undo(Var Ed: TEditor; Var UndoStk, RedoStk: TUndoStack);
Var
 Rec: TUndoRecord;
 Line: String;
Begin
 If Not PopUndo(UndoStk, Rec) Then Exit;
 Case Rec.Action Of
  UA_INSERT: Begin
   { On avait insere du texte, on le supprime }
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1) +
    Copy(Line, Rec.Col + Length(Rec.Text),
     Length(Line) - Rec.Col - Length(Rec.Text) + 1));
   PushUndo(RedoStk, UA_INSERT, Rec.Line, Rec.Col,
    Rec.Text, '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col;
  End;
  UA_DELETE: Begin
   { On avait supprime du texte, on le reinsere }
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1) + Rec.OldText +
    Copy(Line, Rec.Col, Length(Line) - Rec.Col + 1));
   PushUndo(RedoStk, UA_DELETE, Rec.Line, Rec.Col,
    '', Rec.OldText, Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col + Length(Rec.OldText);
  End;
  UA_REPLACE: Begin
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1) + Rec.OldText +
    Copy(Line, Rec.Col + Length(Rec.Text),
     Length(Line) - Rec.Col - Length(Rec.Text) + 1));
   PushUndo(RedoStk, UA_REPLACE, Rec.Line, Rec.Col,
    Rec.OldText, Rec.Text, Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col;
  End;
  UA_INSERT_LINE: Begin
   DeleteLine(Ed.Buffer, Rec.Line);
   PushUndo(RedoStk, UA_INSERT_LINE, Rec.Line, Rec.Col,
    Rec.Text, '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   If Ed.CursorLine >= Ed.Buffer.LineCount Then
    Ed.CursorLine := Ed.Buffer.LineCount - 1;
   If Ed.CursorLine < 0 Then Ed.CursorLine := 0;
   Ed.CursorCol := Rec.Col;
  End;
  UA_DELETE_LINE: Begin
   InsertLine(Ed.Buffer, Rec.Line, Rec.OldText);
   PushUndo(RedoStk, UA_DELETE_LINE, Rec.Line, Rec.Col,
    '', Rec.OldText, Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col;
  End;
  UA_JOIN_LINE: Begin
   { On avait joint deux lignes, on les re-scinde }
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1));
   InsertLine(Ed.Buffer, Rec.Line + 1,
    Copy(Line, Rec.Col, Length(Line) - Rec.Col + 1));
   PushUndo(RedoStk, UA_JOIN_LINE, Rec.Line, Rec.Col,
    '', '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col;
  End;
  UA_SPLIT_LINE: Begin
   { On avait scinde une ligne, on les rejoint }
   Line := GetLine(Ed.Buffer, Rec.Line);
   If Rec.Line + 1 < Ed.Buffer.LineCount Then Begin
    SetLine(Ed.Buffer, Rec.Line,
     Line + GetLine(Ed.Buffer, Rec.Line + 1));
    DeleteLine(Ed.Buffer, Rec.Line + 1);
   End;
   PushUndo(RedoStk, UA_SPLIT_LINE, Rec.Line, Rec.Col,
    '', '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col;
  End;
 End;
End;

{ --- Executer un Redo sur l editeur --- }

Procedure Redo(Var Ed: TEditor; Var UndoStk, RedoStk: TUndoStack);
Var
 Rec: TUndoRecord;
 Line: String;
Begin
 If Not PopUndo(RedoStk, Rec) Then Exit;
 Case Rec.Action Of
  UA_INSERT: Begin
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1) + Rec.Text +
    Copy(Line, Rec.Col, Length(Line) - Rec.Col + 1));
   PushUndo(UndoStk, UA_INSERT, Rec.Line, Rec.Col,
    Rec.Text, '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col + Length(Rec.Text);
  End;
  UA_DELETE: Begin
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1) +
    Copy(Line, Rec.Col + Length(Rec.OldText),
     Length(Line) - Rec.Col - Length(Rec.OldText) + 1));
   PushUndo(UndoStk, UA_DELETE, Rec.Line, Rec.Col,
    '', Rec.OldText, Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col;
  End;
  UA_REPLACE: Begin
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1) + Rec.Text +
    Copy(Line, Rec.Col + Length(Rec.OldText),
     Length(Line) - Rec.Col - Length(Rec.OldText) + 1));
   PushUndo(UndoStk, UA_REPLACE, Rec.Line, Rec.Col,
    Rec.Text, Rec.OldText, Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Rec.Col + Length(Rec.Text);
  End;
  UA_INSERT_LINE: Begin
   InsertLine(Ed.Buffer, Rec.Line, Rec.Text);
   PushUndo(UndoStk, UA_INSERT_LINE, Rec.Line, Rec.Col,
    Rec.Text, '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := 1;
  End;
  UA_DELETE_LINE: Begin
   DeleteLine(Ed.Buffer, Rec.Line);
   PushUndo(UndoStk, UA_DELETE_LINE, Rec.Line, Rec.Col,
    '', Rec.OldText, Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   If Ed.CursorLine >= Ed.Buffer.LineCount Then
    Ed.CursorLine := Ed.Buffer.LineCount - 1;
   If Ed.CursorLine < 0 Then Ed.CursorLine := 0;
   Ed.CursorCol := 1;
  End;
  UA_JOIN_LINE: Begin
   Line := GetLine(Ed.Buffer, Rec.Line);
   If Rec.Line + 1 < Ed.Buffer.LineCount Then Begin
    SetLine(Ed.Buffer, Rec.Line,
     Line + GetLine(Ed.Buffer, Rec.Line + 1));
    DeleteLine(Ed.Buffer, Rec.Line + 1);
   End;
   PushUndo(UndoStk, UA_JOIN_LINE, Rec.Line, Rec.Col,
    '', '', Rec.GroupId);
   Ed.CursorLine := Rec.Line;
   Ed.CursorCol := Length(Line) + 1;
  End;
  UA_SPLIT_LINE: Begin
   Line := GetLine(Ed.Buffer, Rec.Line);
   SetLine(Ed.Buffer, Rec.Line,
    Copy(Line, 1, Rec.Col - 1));
   InsertLine(Ed.Buffer, Rec.Line + 1,
    Copy(Line, Rec.Col, Length(Line) - Rec.Col + 1));
   PushUndo(UndoStk, UA_SPLIT_LINE, Rec.Line, Rec.Col,
    '', '', Rec.GroupId);
   Ed.CursorLine := Rec.Line + 1;
   Ed.CursorCol := 1;
  End;
 End;
End;

{ --- Gerer les raccourcis clavier de selection et edition --- }

Procedure HandleSelectionKey(Var Ed: TEditor; Var Sel: TSelection;
 Var Clip: TClipboard; Var UndoStk, RedoStk: TUndoStack;
 Ev: TEvent);
Var
 ShiftHeld: Boolean;
Begin
 ShiftHeld := (Ev.ShiftState And 1) <> 0;
 If Ev.Kind = EV_KEY_DOWN Then Begin
  { Ctrl+A : selectionner tout }
  If (Ev.KeyChar = #1) Then Begin
   SelectAll(Ed, Sel);
   Exit;
  End;
  { Ctrl+C : copier }
  If (Ev.KeyChar = #3) Then Begin
   ClipboardCopy(Ed, Sel, Clip);
   Exit;
  End;
  { Ctrl+X : couper }
  If (Ev.KeyChar = #24) Then Begin
   ClipboardCut(Ed, Sel, Clip);
   Exit;
  End;
  { Ctrl+V : coller }
  If (Ev.KeyChar = #22) Then Begin
   ClipboardPaste(Ed, Sel, Clip);
   Exit;
  End;
  { Ctrl+Z : annuler }
  If (Ev.KeyChar = #26) Then Begin
   Undo(Ed, UndoStk, RedoStk);
   Exit;
  End;
  { Ctrl+Y : retablir }
  If (Ev.KeyChar = #25) Then Begin
   Redo(Ed, UndoStk, RedoStk);
   Exit;
  End;
 End;
 { Shift+fleches : etendre la selection }
 If ShiftHeld And (Ev.Kind = EV_KEY_DOWN) Then Begin
  If Not Sel.Active Then
   StartSelection(Sel, Ed.CursorLine, Ed.CursorCol);
  HandleEditorKey(Ed, Ev);
  ExtendSelection(Sel, Ed.CursorLine, Ed.CursorCol);
 End Else If Ev.Kind = EV_KEY_DOWN Then Begin
  If Sel.Active Then
   ClearSelection(Sel);
  HandleEditorKey(Ed, Ev);
 End;
End;

{ --- Compter les actions dans la pile undo --- }

Function CountUndoActions(Var Stack: TUndoStack): Integer;
Begin
 CountUndoActions := Stack.Count;
End;

{ --- Verifier si le presse-papier a des donnees --- }

Function HasClipboardData(Var Clip: TClipboard): Boolean;
Begin
 HasClipboardData := Clip.HasData;
End;

{ --- Obtenir la longueur du texte du presse-papier --- }

Function GetClipboardLength(Var Clip: TClipboard): Integer;
Begin
 GetClipboardLength := Length(Clip.Text);
End;

{ --- Compter les lignes selectionnees --- }

Function CountSelectedLines(Var Sel: TSelection): LongInt;
Var
 SL, SC, EL, EC: LongInt;
Begin
 If Not Sel.Active Then Begin
  CountSelectedLines := 0;
  Exit;
 End;
 GetOrderedSelection(Sel, SL, SC, EL, EC);
 CountSelectedLines := EL - SL + 1;
End;

{ --- Verifier si une position est dans la selection --- }

Function IsInSelection(Var Sel: TSelection;
 Line, Col: LongInt): Boolean;
Var
 SL, SC, EL, EC: LongInt;
Begin
 IsInSelection := False;
 If Not Sel.Active Then Exit;
 GetOrderedSelection(Sel, SL, SC, EL, EC);
 If (Line < SL) Or (Line > EL) Then Exit;
 If (Line = SL) And (Col < SC) Then Exit;
 If (Line = EL) And (Col >= EC) Then Exit;
 IsInSelection := True;
End;

{ ============================================================
  TODO 11 - MOTEUR DE COLORATION SYNTAXIQUE
  ============================================================ }

{ --- Initialiser le moteur de coloration syntaxique --- }

Procedure InitHighlighter(Var H: TSyntaxHighlighter; Language: String);
Var
 I: Integer;
Begin
 H.Language := Language;
 H.InBlockComment := False;
 H.InString := False;
 H.StateTop := 0;
 For I := 0 To 63 Do
  H.StateStack[I] := 0;
End;

{ --- Remettre a zero l etat du moteur --- }

Procedure ResetState(Var H: TSyntaxHighlighter);
Var
 I: Integer;
Begin
 H.InBlockComment := False;
 H.InString := False;
 H.StateTop := 0;
 For I := 0 To 63 Do
  H.StateStack[I] := 0;
End;

{ --- Empiler un etat --- }

Procedure PushState(Var H: TSyntaxHighlighter; State: Byte);
Begin
 If H.StateTop < 63 Then
 Begin
  H.StateStack[H.StateTop] := State;
  Inc(H.StateTop);
 End;
End;

{ --- Depiler un etat --- }

Function PopState(Var H: TSyntaxHighlighter): Byte;
Begin
 If H.StateTop > 0 Then
 Begin
  Dec(H.StateTop);
  PopState := H.StateStack[H.StateTop];
 End
 Else
  PopState := 0;
End;

{ --- Convertir une classe de jeton en couleur VS --- }

Function TokenClassToColor(TC: TTokenClass): Integer;
Begin
 Case TC Of
  TC_KEYWORD:      TokenClassToColor := 1;    { bleu           }
  TC_STRING:       TokenClassToColor := 4;    { rouge          }
  TC_CHAR:         TokenClassToColor := 4;    { rouge          }
  TC_NUMBER:       TokenClassToColor := 0;    { noir           }
  TC_COMMENT:      TokenClassToColor := 2;    { vert           }
  TC_DIRECTIVE:    TokenClassToColor := 8;    { gris fonce     }
  TC_OPERATOR:     TokenClassToColor := 0;    { noir           }
  TC_IDENTIFIER:   TokenClassToColor := 0;    { noir           }
  TC_TYPE:         TokenClassToColor := 3;    { turquoise/cyan }
  TC_PREPROCESSOR: TokenClassToColor := 8;    { gris fonce     }
  TC_ATTRIBUTE:    TokenClassToColor := 9;    { bleu clair     }
  TC_XMLDOC:       TokenClassToColor := 6;    { vert olive     }
 Else
  TokenClassToColor := 0;                     { noir (normal)  }
 End;
End;

{ --- Verifier si un caractere est alphanum ou _ --- }

Function IsAlphaNumUS(Ch: Char): Boolean;
Begin
 IsAlphaNumUS := (Ch >= 'A') And (Ch <= 'Z') Or
                 (Ch >= 'a') And (Ch <= 'z') Or
                 (Ch >= '0') And (Ch <= '9') Or
                 (Ch = '_');
End;

{ --- Verifier si un caractere est alphabetique ou _ --- }

Function IsAlphaUS(Ch: Char): Boolean;
Begin
 IsAlphaUS := (Ch >= 'A') And (Ch <= 'Z') Or
              (Ch >= 'a') And (Ch <= 'z') Or
              (Ch = '_');
End;

{ --- Verifier si un caractere est un chiffre --- }

Function IsDigitChar(Ch: Char): Boolean;
Begin
 IsDigitChar := (Ch >= '0') And (Ch <= '9');
End;

{ --- Verifier si un caractere est un operateur --- }

Function IsOperatorChar(Ch: Char): Boolean;
Begin
 IsOperatorChar := (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or
                   (Ch = '/') Or (Ch = '=') Or (Ch = '<') Or
                   (Ch = '>') Or (Ch = '!') Or (Ch = '&') Or
                   (Ch = '|') Or (Ch = '^') Or (Ch = '~') Or
                   (Ch = '%') Or (Ch = '?') Or (Ch = ':');
End;

{ --- Verifier si un caractere est un chiffre hexadecimal --- }

Function IsHexDigit(Ch: Char): Boolean;
Begin
 IsHexDigit := (Ch >= '0') And (Ch <= '9') Or
               (Ch >= 'A') And (Ch <= 'F') Or
               (Ch >= 'a') And (Ch <= 'f');
End;

{ --- Extraire un mot a une position donnee --- }

Function ExtractWord(Line: String; Pos: Integer): String;
Var
 S, E: Integer;
Begin
 S := Pos;
 E := Pos;
 While (S > 1) And IsAlphaNumUS(Line[S - 1]) Do
  Dec(S);
 While (E < Length(Line)) And IsAlphaNumUS(Line[E + 1]) Do
  Inc(E);
 ExtractWord := Copy(Line, S, E - S + 1);
End;

{ --- Obtenir la classe de jeton a une position --- }

Function GetTokenClass(Var H: TSyntaxHighlighter;
                       Line: String; Var Pos: Integer): TTokenClass;
Var
 Ch: Char;
 StartPos: Integer;
 Len: Integer;
Begin
 Len := Length(Line);
 GetTokenClass := TC_NORMAL;
 If Pos > Len Then Exit;

 { Etat persistant : dans un commentaire bloc }
 If H.InBlockComment Then
 Begin
  StartPos := Pos;
  While Pos <= Len Do
  Begin
   If (Pos < Len) And (Line[Pos] = '*') And (Line[Pos + 1] = '/') Then
   Begin
    Inc(Pos, 2);
    H.InBlockComment := False;
    GetTokenClass := TC_COMMENT;
    Exit;
   End;
   Inc(Pos);
  End;
  GetTokenClass := TC_COMMENT;
  Exit;
 End;

 { Etat persistant : dans une chaine verbatim }
 If H.InString Then
 Begin
  While Pos <= Len Do
  Begin
   If Line[Pos] = '"' Then
   Begin
    If (Pos < Len) And (Line[Pos + 1] = '"') Then
     Inc(Pos, 2)
    Else
    Begin
     Inc(Pos);
     H.InString := False;
     GetTokenClass := TC_STRING;
     Exit;
    End;
   End
   Else
    Inc(Pos);
  End;
  GetTokenClass := TC_STRING;
  Exit;
 End;

 Ch := Line[Pos];

 { Espaces }
 If (Ch = ' ') Or (Ch = #9) Then
 Begin
  While (Pos <= Len) And ((Line[Pos] = ' ') Or (Line[Pos] = #9)) Do
   Inc(Pos);
  GetTokenClass := TC_NORMAL;
  Exit;
 End;

 { Commentaire XML doc /// }
 If (Ch = '/') And (Pos + 2 <= Len) And
    (Line[Pos + 1] = '/') And (Line[Pos + 2] = '/') Then
 Begin
  Pos := Len + 1;
  GetTokenClass := TC_XMLDOC;
  Exit;
 End;

 { Commentaire ligne // }
 If (Ch = '/') And (Pos < Len) And (Line[Pos + 1] = '/') Then
 Begin
  Pos := Len + 1;
  GetTokenClass := TC_COMMENT;
  Exit;
 End;

 { Commentaire bloc /* }
 If (Ch = '/') And (Pos < Len) And (Line[Pos + 1] = '*') Then
 Begin
  Inc(Pos, 2);
  H.InBlockComment := True;
  While Pos <= Len Do
  Begin
   If (Pos < Len) And (Line[Pos] = '*') And (Line[Pos + 1] = '/') Then
   Begin
    Inc(Pos, 2);
    H.InBlockComment := False;
    GetTokenClass := TC_COMMENT;
    Exit;
   End;
   Inc(Pos);
  End;
  GetTokenClass := TC_COMMENT;
  Exit;
 End;

 { Directive preprocesseur # }
 If (Ch = '#') Then
 Begin
  Pos := Len + 1;
  GetTokenClass := TC_PREPROCESSOR;
  Exit;
 End;

 { Attribut [xxx] }
 If (Ch = '[') Then
 Begin
  StartPos := Pos;
  Inc(Pos);
  While (Pos <= Len) And (Line[Pos] <> ']') Do
   Inc(Pos);
  If Pos <= Len Then
   Inc(Pos);
  GetTokenClass := TC_ATTRIBUTE;
  Exit;
 End;

 { Chaine verbatim @"..." }
 If (Ch = '@') And (Pos < Len) And (Line[Pos + 1] = '"') Then
 Begin
  Inc(Pos, 2);
  H.InString := True;
  While Pos <= Len Do
  Begin
   If Line[Pos] = '"' Then
   Begin
    If (Pos < Len) And (Line[Pos + 1] = '"') Then
     Inc(Pos, 2)
    Else
    Begin
     Inc(Pos);
     H.InString := False;
     GetTokenClass := TC_STRING;
     Exit;
    End;
   End
   Else
    Inc(Pos);
  End;
  GetTokenClass := TC_STRING;
  Exit;
 End;

 { Chaine interpolee $"..." }
 If (Ch = '$') And (Pos < Len) And (Line[Pos + 1] = '"') Then
 Begin
  Inc(Pos, 2);
  While (Pos <= Len) And (Line[Pos] <> '"') Do
  Begin
   If (Line[Pos] = '\') And (Pos < Len) Then
    Inc(Pos, 2)
   Else
    Inc(Pos);
  End;
  If Pos <= Len Then
   Inc(Pos);
  GetTokenClass := TC_STRING;
  Exit;
 End;

 { Chaine reguliere "..." }
 If Ch = '"' Then
 Begin
  Inc(Pos);
  While (Pos <= Len) And (Line[Pos] <> '"') Do
  Begin
   If (Line[Pos] = '\') And (Pos < Len) Then
    Inc(Pos, 2)
   Else
    Inc(Pos);
  End;
  If Pos <= Len Then
   Inc(Pos);
  GetTokenClass := TC_STRING;
  Exit;
 End;

 { Caractere litteral '...' }
 If Ch = '''' Then
 Begin
  Inc(Pos);
  While (Pos <= Len) And (Line[Pos] <> '''') Do
  Begin
   If (Line[Pos] = '\') And (Pos < Len) Then
    Inc(Pos, 2)
   Else
    Inc(Pos);
  End;
  If Pos <= Len Then
   Inc(Pos);
  GetTokenClass := TC_CHAR;
  Exit;
 End;

 { Nombre hexadecimal 0x... ou binaire 0b... }
 If (Ch = '0') And (Pos < Len) And
    ((Line[Pos + 1] = 'x') Or (Line[Pos + 1] = 'X') Or
     (Line[Pos + 1] = 'b') Or (Line[Pos + 1] = 'B')) Then
 Begin
  Inc(Pos, 2);
  While (Pos <= Len) And (IsHexDigit(Line[Pos]) Or
         (Line[Pos] = '_')) Do
   Inc(Pos);
  { Suffixe eventuel }
  While (Pos <= Len) And IsAlphaUS(Line[Pos]) Do
   Inc(Pos);
  GetTokenClass := TC_NUMBER;
  Exit;
 End;

 { Nombre decimal }
 If IsDigitChar(Ch) Then
 Begin
  While (Pos <= Len) And (IsDigitChar(Line[Pos]) Or
         (Line[Pos] = '_')) Do
   Inc(Pos);
  { Partie decimale }
  If (Pos <= Len) And (Line[Pos] = '.') Then
  Begin
   Inc(Pos);
   While (Pos <= Len) And (IsDigitChar(Line[Pos]) Or
          (Line[Pos] = '_')) Do
    Inc(Pos);
  End;
  { Exposant }
  If (Pos <= Len) And ((Line[Pos] = 'e') Or (Line[Pos] = 'E')) Then
  Begin
   Inc(Pos);
   If (Pos <= Len) And ((Line[Pos] = '+') Or (Line[Pos] = '-')) Then
    Inc(Pos);
   While (Pos <= Len) And IsDigitChar(Line[Pos]) Do
    Inc(Pos);
  End;
  { Suffixe (f, d, m, u, l, etc.) }
  While (Pos <= Len) And IsAlphaUS(Line[Pos]) Do
   Inc(Pos);
  GetTokenClass := TC_NUMBER;
  Exit;
 End;

 { Identificateur ou mot-cle }
 If IsAlphaUS(Ch) Then
 Begin
  StartPos := Pos;
  While (Pos <= Len) And IsAlphaNumUS(Line[Pos]) Do
   Inc(Pos);
  { La classification sera faite par le highlighter specifique }
  GetTokenClass := TC_IDENTIFIER;
  Exit;
 End;

 { Operateur }
 If IsOperatorChar(Ch) Then
 Begin
  Inc(Pos);
  { Operateurs multi-caracteres }
  If (Pos <= Len) And IsOperatorChar(Line[Pos]) Then
   Inc(Pos);
  GetTokenClass := TC_OPERATOR;
  Exit;
 End;

 { Autre caractere (ponctuation, etc.) }
 Inc(Pos);
 GetTokenClass := TC_NORMAL;
End;

{ --- Colorier une ligne entiere --- }

Procedure HighlightLine(Var H: TSyntaxHighlighter;
                        Line: String; Var Colors: Array Of Byte);
Var
 Pos, Start, I, Len: Integer;
 TC: TTokenClass;
 Clr: Byte;
Begin
 Len := Length(Line);
 { Initialiser toutes les couleurs a normal }
 For I := 0 To Len - 1 Do
  Colors[I] := Byte(TokenClassToColor(TC_NORMAL));

 Pos := 1;
 While Pos <= Len Do
 Begin
  Start := Pos;
  TC := GetTokenClass(H, Line, Pos);
  Clr := Byte(TokenClassToColor(TC));
  For I := Start To Pos - 1 Do
  Begin
   If (I >= 1) And (I <= Len) Then
    Colors[I - 1] := Clr;
  End;
 End;
End;

{ --- Obtenir le nom d une classe de jeton --- }

Function TokenClassName(TC: TTokenClass): String;
Begin
 Case TC Of
  TC_NORMAL:       TokenClassName := 'NORMAL';
  TC_KEYWORD:      TokenClassName := 'KEYWORD';
  TC_STRING:       TokenClassName := 'STRING';
  TC_CHAR:         TokenClassName := 'CHAR';
  TC_NUMBER:       TokenClassName := 'NUMBER';
  TC_COMMENT:      TokenClassName := 'COMMENT';
  TC_DIRECTIVE:    TokenClassName := 'DIRECTIVE';
  TC_OPERATOR:     TokenClassName := 'OPERATOR';
  TC_IDENTIFIER:   TokenClassName := 'IDENTIFIER';
  TC_TYPE:         TokenClassName := 'TYPE';
  TC_PREPROCESSOR: TokenClassName := 'PREPROCESSOR';
  TC_ATTRIBUTE:    TokenClassName := 'ATTRIBUTE';
  TC_XMLDOC:       TokenClassName := 'XMLDOC';
 Else
  TokenClassName := 'UNKNOWN';
 End;
End;

{ --- Verifier si le moteur est dans un commentaire bloc --- }

Function IsInBlockComment(Var H: TSyntaxHighlighter): Boolean;
Begin
 IsInBlockComment := H.InBlockComment;
End;

{ --- Verifier si le moteur est dans une chaine multi-ligne --- }

Function IsInMultiLineString(Var H: TSyntaxHighlighter): Boolean;
Begin
 IsInMultiLineString := H.InString;
End;

{ --- Obtenir le langage du moteur --- }

Function GetHighlighterLanguage(Var H: TSyntaxHighlighter): String;
Begin
 GetHighlighterLanguage := H.Language;
End;

{ --- Compter les classes de jetons dans une ligne --- }

Function CountTokensInLine(Var H: TSyntaxHighlighter;
                           Line: String): Integer;
Var
 Pos, Count: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := H.InBlockComment;
 SaveStr := H.InString;
 SaveTop := H.StateTop;
 Count := 0;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetTokenClass(H, Line, Pos);
  Inc(Count);
 End;
 H.InBlockComment := SaveBC;
 H.InString := SaveStr;
 H.StateTop := SaveTop;
 CountTokensInLine := Count;
End;

{ --- Verifier si une ligne contient un commentaire --- }

Function LineHasComment(Var H: TSyntaxHighlighter;
                        Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := H.InBlockComment;
 SaveStr := H.InString;
 SaveTop := H.StateTop;
 LineHasComment := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetTokenClass(H, Line, Pos);
  If (TC = TC_COMMENT) Or (TC = TC_XMLDOC) Then
  Begin
   LineHasComment := True;
   Break;
  End;
 End;
 H.InBlockComment := SaveBC;
 H.InString := SaveStr;
 H.StateTop := SaveTop;
End;

{ --- Verifier si une ligne contient une chaine --- }

Function LineHasString(Var H: TSyntaxHighlighter;
                       Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := H.InBlockComment;
 SaveStr := H.InString;
 SaveTop := H.StateTop;
 LineHasString := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetTokenClass(H, Line, Pos);
  If (TC = TC_STRING) Or (TC = TC_CHAR) Then
  Begin
   LineHasString := True;
   Break;
  End;
 End;
 H.InBlockComment := SaveBC;
 H.InString := SaveStr;
 H.StateTop := SaveTop;
End;

{ ============================================================
  TODO 12 - COLORATION SYNTAXIQUE C#
  ============================================================ }

{ --- Initialiser les mots-cles C# --- }

Procedure InitCSharpKeywords(Var HL: TCSharpHighlighter);
Begin
 HL.KeywordCount := MAX_CSHARP_KEYWORDS;
 HL.Keywords[0]  := 'abstract';
 HL.Keywords[1]  := 'as';
 HL.Keywords[2]  := 'base';
 HL.Keywords[3]  := 'bool';
 HL.Keywords[4]  := 'break';
 HL.Keywords[5]  := 'byte';
 HL.Keywords[6]  := 'case';
 HL.Keywords[7]  := 'catch';
 HL.Keywords[8]  := 'char';
 HL.Keywords[9]  := 'checked';
 HL.Keywords[10] := 'class';
 HL.Keywords[11] := 'const';
 HL.Keywords[12] := 'continue';
 HL.Keywords[13] := 'decimal';
 HL.Keywords[14] := 'default';
 HL.Keywords[15] := 'delegate';
 HL.Keywords[16] := 'do';
 HL.Keywords[17] := 'double';
 HL.Keywords[18] := 'else';
 HL.Keywords[19] := 'enum';
 HL.Keywords[20] := 'event';
 HL.Keywords[21] := 'explicit';
 HL.Keywords[22] := 'extern';
 HL.Keywords[23] := 'false';
 HL.Keywords[24] := 'finally';
 HL.Keywords[25] := 'fixed';
 HL.Keywords[26] := 'float';
 HL.Keywords[27] := 'for';
 HL.Keywords[28] := 'foreach';
 HL.Keywords[29] := 'goto';
 HL.Keywords[30] := 'if';
 HL.Keywords[31] := 'implicit';
 HL.Keywords[32] := 'in';
 HL.Keywords[33] := 'int';
 HL.Keywords[34] := 'interface';
 HL.Keywords[35] := 'internal';
 HL.Keywords[36] := 'is';
 HL.Keywords[37] := 'lock';
 HL.Keywords[38] := 'long';
 HL.Keywords[39] := 'namespace';
 HL.Keywords[40] := 'new';
 HL.Keywords[41] := 'null';
 HL.Keywords[42] := 'object';
 HL.Keywords[43] := 'operator';
 HL.Keywords[44] := 'out';
 HL.Keywords[45] := 'override';
 HL.Keywords[46] := 'params';
 HL.Keywords[47] := 'private';
 HL.Keywords[48] := 'protected';
 HL.Keywords[49] := 'public';
 HL.Keywords[50] := 'readonly';
 HL.Keywords[51] := 'ref';
 HL.Keywords[52] := 'return';
 HL.Keywords[53] := 'sbyte';
 HL.Keywords[54] := 'sealed';
 HL.Keywords[55] := 'short';
 HL.Keywords[56] := 'sizeof';
 HL.Keywords[57] := 'stackalloc';
 HL.Keywords[58] := 'static';
 HL.Keywords[59] := 'string';
 HL.Keywords[60] := 'struct';
 HL.Keywords[61] := 'switch';
 HL.Keywords[62] := 'this';
 HL.Keywords[63] := 'throw';
 HL.Keywords[64] := 'true';
 HL.Keywords[65] := 'try';
 HL.Keywords[66] := 'typeof';
 HL.Keywords[67] := 'uint';
 HL.Keywords[68] := 'ulong';
 HL.Keywords[69] := 'unchecked';
 HL.Keywords[70] := 'unsafe';
 HL.Keywords[71] := 'ushort';
 HL.Keywords[72] := 'using';
 HL.Keywords[73] := 'var';
 HL.Keywords[74] := 'virtual';
 HL.Keywords[75] := 'void';
 HL.Keywords[76] := 'volatile';
 HL.Keywords[77] := 'while';
 HL.Keywords[78] := 'yield';
End;

{ --- Initialiser les mots-cles contextuels C# --- }

Procedure InitCSharpContextualKW(Var HL: TCSharpHighlighter);
Begin
 HL.CtxKWCount := MAX_CSHARP_CTXKW;
 HL.CtxKeywords[0]  := 'add';
 HL.CtxKeywords[1]  := 'alias';
 HL.CtxKeywords[2]  := 'ascending';
 HL.CtxKeywords[3]  := 'async';
 HL.CtxKeywords[4]  := 'await';
 HL.CtxKeywords[5]  := 'by';
 HL.CtxKeywords[6]  := 'descending';
 HL.CtxKeywords[7]  := 'dynamic';
 HL.CtxKeywords[8]  := 'equals';
 HL.CtxKeywords[9]  := 'from';
 HL.CtxKeywords[10] := 'get';
 HL.CtxKeywords[11] := 'global';
 HL.CtxKeywords[12] := 'group';
 HL.CtxKeywords[13] := 'into';
 HL.CtxKeywords[14] := 'join';
 HL.CtxKeywords[15] := 'let';
 HL.CtxKeywords[16] := 'nameof';
 HL.CtxKeywords[17] := 'on';
 HL.CtxKeywords[18] := 'orderby';
 HL.CtxKeywords[19] := 'partial';
 HL.CtxKeywords[20] := 'remove';
 HL.CtxKeywords[21] := 'select';
 HL.CtxKeywords[22] := 'set';
 HL.CtxKeywords[23] := 'value';
 HL.CtxKeywords[24] := 'when';
 HL.CtxKeywords[25] := 'where';
 HL.CtxKeywords[26] := 'yield';
 HL.CtxKeywords[27] := 'unmanaged';
End;

{ --- Initialiser le moteur de coloration C# --- }

Procedure InitCSharpHighlighter(Var HL: TCSharpHighlighter);
Begin
 InitHighlighter(HL.Base, 'C#');
 InitCSharpKeywords(HL);
 InitCSharpContextualKW(HL);
End;

{ --- Verifier si un mot est un mot-cle C# --- }

Function IsCSharpKeyword(Var HL: TCSharpHighlighter;
                         Word: String): Boolean;
Var
 I: Integer;
Begin
 IsCSharpKeyword := False;
 For I := 0 To HL.KeywordCount - 1 Do
 Begin
  If Word = HL.Keywords[I] Then
  Begin
   IsCSharpKeyword := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si un mot est un mot-cle contextuel C# --- }

Function IsCSharpContextualKeyword(Var HL: TCSharpHighlighter;
                                   Word: String): Boolean;
Var
 I: Integer;
Begin
 IsCSharpContextualKeyword := False;
 For I := 0 To HL.CtxKWCount - 1 Do
 Begin
  If Word = HL.CtxKeywords[I] Then
  Begin
   IsCSharpContextualKeyword := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si un mot est un type predefini C# --- }

Function IsCSharpType(Word: String): Boolean;
Begin
 IsCSharpType :=
  (Word = 'bool') Or (Word = 'byte') Or (Word = 'char') Or
  (Word = 'decimal') Or (Word = 'double') Or (Word = 'float') Or
  (Word = 'int') Or (Word = 'long') Or (Word = 'object') Or
  (Word = 'sbyte') Or (Word = 'short') Or (Word = 'string') Or
  (Word = 'uint') Or (Word = 'ulong') Or (Word = 'ushort') Or
  (Word = 'void') Or (Word = 'dynamic') Or (Word = 'var');
End;

{ --- Classifier un jeton C# (identifier -> keyword/type) --- }

Function ClassifyCSharpToken(Var HL: TCSharpHighlighter;
                             Line: String;
                             StartPos, EndPos: Integer): TTokenClass;
Var
 Word: String;
Begin
 Word := Copy(Line, StartPos, EndPos - StartPos);
 If IsCSharpType(Word) Then
  ClassifyCSharpToken := TC_TYPE
 Else If IsCSharpKeyword(HL, Word) Then
  ClassifyCSharpToken := TC_KEYWORD
 Else If IsCSharpContextualKeyword(HL, Word) Then
  ClassifyCSharpToken := TC_KEYWORD
 Else
  ClassifyCSharpToken := TC_IDENTIFIER;
End;

{ --- Obtenir la classe de jeton C# a une position --- }

Function GetCSharpTokenClass(Var HL: TCSharpHighlighter;
                             Line: String;
                             Var Pos: Integer): TTokenClass;
Var
 StartPos: Integer;
 TC: TTokenClass;
Begin
 StartPos := Pos;
 TC := GetTokenClass(HL.Base, Line, Pos);
 If TC = TC_IDENTIFIER Then
  GetCSharpTokenClass := ClassifyCSharpToken(HL, Line, StartPos, Pos)
 Else
  GetCSharpTokenClass := TC;
End;

{ --- Colorier une ligne C# entiere --- }

Procedure HighlightCSharpLine(Var HL: TCSharpHighlighter;
                              Line: String;
                              Var Colors: Array Of Byte);
Var
 Pos, Start, I, Len: Integer;
 TC: TTokenClass;
 Clr: Byte;
Begin
 Len := Length(Line);
 For I := 0 To Len - 1 Do
  Colors[I] := Byte(TokenClassToColor(TC_NORMAL));

 Pos := 1;
 While Pos <= Len Do
 Begin
  Start := Pos;
  TC := GetCSharpTokenClass(HL, Line, Pos);
  Clr := Byte(TokenClassToColor(TC));
  For I := Start To Pos - 1 Do
  Begin
   If (I >= 1) And (I <= Len) Then
    Colors[I - 1] := Clr;
  End;
 End;
End;

{ --- Obtenir le nom d un type de jeton C# --- }

Function CSharpTokenClassName(TC: TTokenClass): String;
Begin
 CSharpTokenClassName := TokenClassName(TC);
End;

{ --- Compter les mots-cles C# --- }

Function CountCSharpKeywords(Var HL: TCSharpHighlighter): Integer;
Begin
 CountCSharpKeywords := HL.KeywordCount;
End;

{ --- Compter les mots-cles contextuels C# --- }

Function CountCSharpContextualKW(Var HL: TCSharpHighlighter): Integer;
Begin
 CountCSharpContextualKW := HL.CtxKWCount;
End;

{ --- Verifier si un mot est une directive preprocesseur C# --- }

Function IsCSharpPreprocessorDirective(Word: String): Boolean;
Begin
 IsCSharpPreprocessorDirective :=
  (Word = 'if') Or (Word = 'else') Or (Word = 'elif') Or
  (Word = 'endif') Or (Word = 'define') Or (Word = 'undef') Or
  (Word = 'region') Or (Word = 'endregion') Or
  (Word = 'pragma') Or (Word = 'warning') Or (Word = 'error') Or
  (Word = 'line') Or (Word = 'nullable');
End;

{ --- Verifier si un caractere est un operateur C# --- }

Function IsCSharpOperator(Ch: Char): Boolean;
Begin
 IsCSharpOperator :=
  (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
  (Ch = '%') Or (Ch = '&') Or (Ch = '|') Or (Ch = '^') Or
  (Ch = '~') Or (Ch = '!') Or (Ch = '=') Or (Ch = '<') Or
  (Ch = '>') Or (Ch = '?') Or (Ch = ':');
End;

{ --- Verifier si un caractere est un prefixe de chaine C# --- }

Function IsCSharpStringPrefix(Ch: Char): Boolean;
Begin
 IsCSharpStringPrefix := (Ch = '@') Or (Ch = '$');
End;

{ --- Verifier si une ligne contient une chaine verbatim --- }

Function HasCSharpVerbatimString(Line: String): Boolean;
Var
 I: Integer;
Begin
 HasCSharpVerbatimString := False;
 For I := 1 To Length(Line) - 1 Do
 Begin
  If (Line[I] = '@') And (Line[I + 1] = '"') Then
  Begin
   HasCSharpVerbatimString := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si une ligne contient une chaine interpolee --- }

Function HasCSharpInterpolatedString(Line: String): Boolean;
Var
 I: Integer;
Begin
 HasCSharpInterpolatedString := False;
 For I := 1 To Length(Line) - 1 Do
 Begin
  If (Line[I] = '$') And (Line[I + 1] = '"') Then
  Begin
   HasCSharpInterpolatedString := True;
   Exit;
  End;
 End;
End;

{ --- Compter les classes de jetons C# dans une ligne --- }

Function CountCSharpTokensInLine(Var HL: TCSharpHighlighter;
                                 Line: String): Integer;
Var
 Pos, Count: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 Count := 0;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetCSharpTokenClass(HL, Line, Pos);
  Inc(Count);
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
 CountCSharpTokensInLine := Count;
End;

{ --- Verifier si une ligne C# contient un commentaire --- }

Function CSharpLineHasComment(Var HL: TCSharpHighlighter;
                               Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 CSharpLineHasComment := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetCSharpTokenClass(HL, Line, Pos);
  If (TC = TC_COMMENT) Or (TC = TC_XMLDOC) Then
  Begin
   CSharpLineHasComment := True;
   Break;
  End;
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
End;

{ --- Verifier si une ligne C# contient une chaine --- }

Function CSharpLineHasString(Var HL: TCSharpHighlighter;
                              Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 CSharpLineHasString := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetCSharpTokenClass(HL, Line, Pos);
  If (TC = TC_STRING) Or (TC = TC_CHAR) Then
  Begin
   CSharpLineHasString := True;
   Break;
  End;
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
End;

{ ============================================================
  TODO 13 - COLORATION SYNTAXIQUE VB.NET
  ============================================================ }

{ --- Initialiser les mots-cles VB.NET --- }

Procedure InitVBNetKeywords(Var HL: TVBNetHighlighter);
Begin
 HL.KeywordCount := MAX_VBNET_KEYWORDS;
 HL.Keywords[0]   := 'addhandler';
 HL.Keywords[1]   := 'addressof';
 HL.Keywords[2]   := 'alias';
 HL.Keywords[3]   := 'and';
 HL.Keywords[4]   := 'andalso';
 HL.Keywords[5]   := 'as';
 HL.Keywords[6]   := 'boolean';
 HL.Keywords[7]   := 'byref';
 HL.Keywords[8]   := 'byte';
 HL.Keywords[9]   := 'byval';
 HL.Keywords[10]  := 'call';
 HL.Keywords[11]  := 'case';
 HL.Keywords[12]  := 'catch';
 HL.Keywords[13]  := 'cbool';
 HL.Keywords[14]  := 'cbyte';
 HL.Keywords[15]  := 'cchar';
 HL.Keywords[16]  := 'cdate';
 HL.Keywords[17]  := 'cdbl';
 HL.Keywords[18]  := 'cdec';
 HL.Keywords[19]  := 'char';
 HL.Keywords[20]  := 'cint';
 HL.Keywords[21]  := 'class';
 HL.Keywords[22]  := 'clng';
 HL.Keywords[23]  := 'cobj';
 HL.Keywords[24]  := 'const';
 HL.Keywords[25]  := 'continue';
 HL.Keywords[26]  := 'csbyte';
 HL.Keywords[27]  := 'cshort';
 HL.Keywords[28]  := 'csng';
 HL.Keywords[29]  := 'cstr';
 HL.Keywords[30]  := 'ctype';
 HL.Keywords[31]  := 'cuint';
 HL.Keywords[32]  := 'culng';
 HL.Keywords[33]  := 'cushort';
 HL.Keywords[34]  := 'date';
 HL.Keywords[35]  := 'decimal';
 HL.Keywords[36]  := 'declare';
 HL.Keywords[37]  := 'default';
 HL.Keywords[38]  := 'delegate';
 HL.Keywords[39]  := 'dim';
 HL.Keywords[40]  := 'directcast';
 HL.Keywords[41]  := 'do';
 HL.Keywords[42]  := 'double';
 HL.Keywords[43]  := 'each';
 HL.Keywords[44]  := 'else';
 HL.Keywords[45]  := 'elseif';
 HL.Keywords[46]  := 'end';
 HL.Keywords[47]  := 'endif';
 HL.Keywords[48]  := 'enum';
 HL.Keywords[49]  := 'erase';
 HL.Keywords[50]  := 'error';
 HL.Keywords[51]  := 'event';
 HL.Keywords[52]  := 'exit';
 HL.Keywords[53]  := 'false';
 HL.Keywords[54]  := 'finally';
 HL.Keywords[55]  := 'for';
 HL.Keywords[56]  := 'friend';
 HL.Keywords[57]  := 'function';
 HL.Keywords[58]  := 'get';
 HL.Keywords[59]  := 'gettype';
 HL.Keywords[60]  := 'getxmlnamespace';
 HL.Keywords[61]  := 'global';
 HL.Keywords[62]  := 'gosub';
 HL.Keywords[63]  := 'goto';
 HL.Keywords[64]  := 'handles';
 HL.Keywords[65]  := 'if';
 HL.Keywords[66]  := 'implements';
 HL.Keywords[67]  := 'imports';
 HL.Keywords[68]  := 'in';
 HL.Keywords[69]  := 'inherits';
 HL.Keywords[70]  := 'integer';
 HL.Keywords[71]  := 'interface';
 HL.Keywords[72]  := 'is';
 HL.Keywords[73]  := 'isnot';
 HL.Keywords[74]  := 'let';
 HL.Keywords[75]  := 'lib';
 HL.Keywords[76]  := 'like';
 HL.Keywords[77]  := 'long';
 HL.Keywords[78]  := 'loop';
 HL.Keywords[79]  := 'me';
 HL.Keywords[80]  := 'mod';
 HL.Keywords[81]  := 'module';
 HL.Keywords[82]  := 'mustinherit';
 HL.Keywords[83]  := 'mustoverride';
 HL.Keywords[84]  := 'mybase';
 HL.Keywords[85]  := 'myclass';
 HL.Keywords[86]  := 'namespace';
 HL.Keywords[87]  := 'narrowing';
 HL.Keywords[88]  := 'new';
 HL.Keywords[89]  := 'next';
 HL.Keywords[90]  := 'not';
 HL.Keywords[91]  := 'nothing';
 HL.Keywords[92]  := 'notinheritable';
 HL.Keywords[93]  := 'notoverridable';
 HL.Keywords[94]  := 'object';
 HL.Keywords[95]  := 'of';
 HL.Keywords[96]  := 'on';
 HL.Keywords[97]  := 'operator';
 HL.Keywords[98]  := 'option';
 HL.Keywords[99]  := 'optional';
 HL.Keywords[100] := 'or';
 HL.Keywords[101] := 'orelse';
 HL.Keywords[102] := 'overloads';
 HL.Keywords[103] := 'overridable';
 HL.Keywords[104] := 'overrides';
 HL.Keywords[105] := 'paramarray';
 HL.Keywords[106] := 'partial';
 HL.Keywords[107] := 'private';
 HL.Keywords[108] := 'property';
 HL.Keywords[109] := 'protected';
 HL.Keywords[110] := 'public';
 HL.Keywords[111] := 'raiseevent';
 HL.Keywords[112] := 'readonly';
 HL.Keywords[113] := 'redim';
 HL.Keywords[114] := 'rem';
 HL.Keywords[115] := 'removehandler';
 HL.Keywords[116] := 'resume';
 HL.Keywords[117] := 'return';
 HL.Keywords[118] := 'sbyte';
 HL.Keywords[119] := 'select';
 HL.Keywords[120] := 'set';
 HL.Keywords[121] := 'shadows';
 HL.Keywords[122] := 'shared';
 HL.Keywords[123] := 'short';
 HL.Keywords[124] := 'single';
 HL.Keywords[125] := 'static';
 HL.Keywords[126] := 'step';
 HL.Keywords[127] := 'stop';
 HL.Keywords[128] := 'string';
 HL.Keywords[129] := 'structure';
 HL.Keywords[130] := 'sub';
 HL.Keywords[131] := 'synclock';
 HL.Keywords[132] := 'then';
 HL.Keywords[133] := 'throw';
 HL.Keywords[134] := 'to';
 HL.Keywords[135] := 'true';
 HL.Keywords[136] := 'try';
 HL.Keywords[137] := 'trycast';
 HL.Keywords[138] := 'typeof';
 HL.Keywords[139] := 'uinteger';
 HL.Keywords[140] := 'ulong';
 HL.Keywords[141] := 'ushort';
 HL.Keywords[142] := 'using';
 HL.Keywords[143] := 'variant';
 HL.Keywords[144] := 'wend';
 HL.Keywords[145] := 'when';
 HL.Keywords[146] := 'while';
 HL.Keywords[147] := 'widening';
 HL.Keywords[148] := 'with';
 HL.Keywords[149] := 'withevents';
 HL.Keywords[150] := 'writeonly';
 HL.Keywords[151] := 'xor';
End;

{ --- Initialiser le moteur de coloration VB.NET --- }

Procedure InitVBNetHighlighter(Var HL: TVBNetHighlighter);
Begin
 InitHighlighter(HL.Base, 'VB.NET');
 InitVBNetKeywords(HL);
End;

{ --- Verifier si un mot est un mot-cle VB.NET (insensible casse) --- }

Function IsVBNetKeyword(Var HL: TVBNetHighlighter;
                        Word: String): Boolean;
Var
 I: Integer;
 LW: String;
Begin
 IsVBNetKeyword := False;
 LW := LowerCaseStr(Word);
 For I := 0 To HL.KeywordCount - 1 Do
 Begin
  If LW = HL.Keywords[I] Then
  Begin
   IsVBNetKeyword := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si un mot est un type predefini VB.NET --- }

Function IsVBNetType(Word: String): Boolean;
Var
 LW: String;
Begin
 LW := LowerCaseStr(Word);
 IsVBNetType :=
  (LW = 'boolean') Or (LW = 'byte') Or (LW = 'char') Or
  (LW = 'date') Or (LW = 'decimal') Or (LW = 'double') Or
  (LW = 'integer') Or (LW = 'long') Or (LW = 'object') Or
  (LW = 'sbyte') Or (LW = 'short') Or (LW = 'single') Or
  (LW = 'string') Or (LW = 'uinteger') Or (LW = 'ulong') Or
  (LW = 'ushort');
End;

{ --- Classifier un jeton VB.NET (identifier -> keyword/type) --- }

Function ClassifyVBNetToken(Var HL: TVBNetHighlighter;
                            Line: String;
                            StartPos, EndPos: Integer): TTokenClass;
Var
 Word: String;
Begin
 Word := Copy(Line, StartPos, EndPos - StartPos);
 If IsVBNetType(Word) Then
  ClassifyVBNetToken := TC_TYPE
 Else If IsVBNetKeyword(HL, Word) Then
  ClassifyVBNetToken := TC_KEYWORD
 Else
  ClassifyVBNetToken := TC_IDENTIFIER;
End;

{ --- Obtenir la classe de jeton VB.NET a une position --- }

Function GetVBNetTokenClass(Var HL: TVBNetHighlighter;
                            Line: String;
                            Var Pos: Integer): TTokenClass;
Var
 StartPos: Integer;
 TC: TTokenClass;
Begin
 StartPos := Pos;
 TC := GetTokenClass(HL.Base, Line, Pos);
 If TC = TC_IDENTIFIER Then
  GetVBNetTokenClass := ClassifyVBNetToken(HL, Line, StartPos, Pos)
 Else
  GetVBNetTokenClass := TC;
End;

{ --- Colorier une ligne VB.NET entiere --- }

Procedure HighlightVBNetLine(Var HL: TVBNetHighlighter;
                             Line: String;
                             Var Colors: Array Of Byte);
Var
 Pos, Start, I, Len: Integer;
 TC: TTokenClass;
 Clr: Byte;
Begin
 Len := Length(Line);
 For I := 0 To Len - 1 Do
  Colors[I] := Byte(TokenClassToColor(TC_NORMAL));

 Pos := 1;
 While Pos <= Len Do
 Begin
  Start := Pos;
  TC := GetVBNetTokenClass(HL, Line, Pos);
  Clr := Byte(TokenClassToColor(TC));
  For I := Start To Pos - 1 Do
  Begin
   If (I >= 1) And (I <= Len) Then
    Colors[I - 1] := Clr;
  End;
 End;
End;

{ --- Obtenir le nom d un type de jeton VB.NET --- }

Function VBNetTokenClassName(TC: TTokenClass): String;
Begin
 VBNetTokenClassName := TokenClassName(TC);
End;

{ --- Compter les mots-cles VB.NET --- }

Function CountVBNetKeywords(Var HL: TVBNetHighlighter): Integer;
Begin
 CountVBNetKeywords := HL.KeywordCount;
End;

{ --- Verifier si un mot est une directive preprocesseur VB.NET --- }

Function IsVBNetPreprocessorDirective(Word: String): Boolean;
Var
 LW: String;
Begin
 LW := LowerCaseStr(Word);
 IsVBNetPreprocessorDirective :=
  (LW = 'if') Or (LW = 'else') Or (LW = 'elseif') Or
  (LW = 'end') Or (LW = 'const') Or (LW = 'region') Or
  (LW = 'externalchecksum') Or (LW = 'externalsource');
End;

{ --- Verifier si un caractere est un operateur VB.NET --- }

Function IsVBNetOperator(Ch: Char): Boolean;
Begin
 IsVBNetOperator :=
  (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
  (Ch = '\') Or (Ch = '^') Or (Ch = '=') Or (Ch = '<') Or
  (Ch = '>') Or (Ch = '&') Or (Ch = '.') Or (Ch = '!');
End;

{ --- Verifier si une position est un debut de commentaire VB.NET --- }

Function IsVBNetCommentStart(Line: String; Pos: Integer): Boolean;
Var
 LW: String;
Begin
 IsVBNetCommentStart := False;
 If Pos > Length(Line) Then Exit;
 If Line[Pos] = '''' Then
 Begin
  IsVBNetCommentStart := True;
  Exit;
 End;
 If Pos + 2 <= Length(Line) Then
 Begin
  LW := LowerCaseStr(Copy(Line, Pos, 3));
  If LW = 'rem' Then
  Begin
   If (Pos + 3 > Length(Line)) Or
      Not(IsAlphaNumUS(Line[Pos + 3])) Then
    IsVBNetCommentStart := True;
  End;
 End;
End;

{ --- Verifier si une ligne contient un nombre hexadecimal VB.NET --- }

Function HasVBNetHexLiteral(Line: String): Boolean;
Var
 I: Integer;
 LW: String;
Begin
 HasVBNetHexLiteral := False;
 LW := LowerCaseStr(Line);
 For I := 1 To Length(LW) - 1 Do
 Begin
  If (LW[I] = '&') And (LW[I + 1] = 'h') Then
  Begin
   HasVBNetHexLiteral := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si une ligne contient un nombre octal VB.NET --- }

Function HasVBNetOctalLiteral(Line: String): Boolean;
Var
 I: Integer;
 LW: String;
Begin
 HasVBNetOctalLiteral := False;
 LW := LowerCaseStr(Line);
 For I := 1 To Length(LW) - 1 Do
 Begin
  If (LW[I] = '&') And (LW[I + 1] = 'o') Then
  Begin
   HasVBNetOctalLiteral := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si une ligne contient un nombre binaire VB.NET --- }

Function HasVBNetBinaryLiteral(Line: String): Boolean;
Var
 I: Integer;
 LW: String;
Begin
 HasVBNetBinaryLiteral := False;
 LW := LowerCaseStr(Line);
 For I := 1 To Length(LW) - 1 Do
 Begin
  If (LW[I] = '&') And (LW[I + 1] = 'b') Then
  Begin
   HasVBNetBinaryLiteral := True;
   Exit;
  End;
 End;
End;

{ --- Compter les classes de jetons VB.NET dans une ligne --- }

Function CountVBNetTokensInLine(Var HL: TVBNetHighlighter;
                                Line: String): Integer;
Var
 Pos, Count: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 Count := 0;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetVBNetTokenClass(HL, Line, Pos);
  Inc(Count);
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
 CountVBNetTokensInLine := Count;
End;

{ --- Verifier si une ligne VB.NET contient un commentaire --- }

Function VBNetLineHasComment(Var HL: TVBNetHighlighter;
                              Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 VBNetLineHasComment := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetVBNetTokenClass(HL, Line, Pos);
  If TC = TC_COMMENT Then
  Begin
   VBNetLineHasComment := True;
   Break;
  End;
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
End;

{ --- Verifier si une ligne VB.NET contient une chaine --- }

Function VBNetLineHasString(Var HL: TVBNetHighlighter;
                             Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 VBNetLineHasString := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetVBNetTokenClass(HL, Line, Pos);
  If TC = TC_STRING Then
  Begin
   VBNetLineHasString := True;
   Break;
  End;
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
End;

{ --- Verifier si une position contient un guillemet echappe VB.NET --- }

Function IsVBNetEscapedQuote(Line: String; Pos: Integer): Boolean;
Begin
 IsVBNetEscapedQuote := False;
 If (Pos >= 1) And (Pos + 1 <= Length(Line)) Then
 Begin
  If (Line[Pos] = '"') And (Line[Pos + 1] = '"') Then
   IsVBNetEscapedQuote := True;
 End;
End;

{ --- Convertir un mot VB.NET en minuscules pour comparaison --- }

Function VBNetLowerCase(Word: String): String;
Begin
 VBNetLowerCase := LowerCaseStr(Word);
End;

{ ============================================================
  TODO 14 - COLORATION SYNTAXIQUE PASCAL
  ============================================================ }

{ --- Initialiser les mots-cles Pascal (Turbo Pascal + Free Pascal) --- }

Procedure InitPascalKeywords(Var HL: TPascalHighlighter);
Begin
 { Mots-cles Turbo Pascal }
 HL.Keywords[0]   := 'and';
 HL.Keywords[1]   := 'array';
 HL.Keywords[2]   := 'begin';
 HL.Keywords[3]   := 'case';
 HL.Keywords[4]   := 'const';
 HL.Keywords[5]   := 'constructor';
 HL.Keywords[6]   := 'destructor';
 HL.Keywords[7]   := 'div';
 HL.Keywords[8]   := 'do';
 HL.Keywords[9]   := 'downto';
 HL.Keywords[10]  := 'else';
 HL.Keywords[11]  := 'end';
 HL.Keywords[12]  := 'file';
 HL.Keywords[13]  := 'for';
 HL.Keywords[14]  := 'function';
 HL.Keywords[15]  := 'goto';
 HL.Keywords[16]  := 'if';
 HL.Keywords[17]  := 'implementation';
 HL.Keywords[18]  := 'in';
 HL.Keywords[19]  := 'inherited';
 HL.Keywords[20]  := 'inline';
 HL.Keywords[21]  := 'interface';
 HL.Keywords[22]  := 'label';
 HL.Keywords[23]  := 'mod';
 HL.Keywords[24]  := 'nil';
 HL.Keywords[25]  := 'not';
 HL.Keywords[26]  := 'object';
 HL.Keywords[27]  := 'of';
 HL.Keywords[28]  := 'or';
 HL.Keywords[29]  := 'packed';
 HL.Keywords[30]  := 'procedure';
 HL.Keywords[31]  := 'program';
 HL.Keywords[32]  := 'record';
 HL.Keywords[33]  := 'repeat';
 HL.Keywords[34]  := 'set';
 HL.Keywords[35]  := 'shl';
 HL.Keywords[36]  := 'shr';
 HL.Keywords[37]  := 'string';
 HL.Keywords[38]  := 'then';
 HL.Keywords[39]  := 'to';
 HL.Keywords[40]  := 'type';
 HL.Keywords[41]  := 'unit';
 HL.Keywords[42]  := 'until';
 HL.Keywords[43]  := 'uses';
 HL.Keywords[44]  := 'var';
 HL.Keywords[45]  := 'while';
 HL.Keywords[46]  := 'with';
 HL.Keywords[47]  := 'xor';
 { Mots-cles supplementaires Free Pascal }
 HL.Keywords[48]  := 'class';
 HL.Keywords[49]  := 'try';
 HL.Keywords[50]  := 'except';
 HL.Keywords[51]  := 'finally';
 HL.Keywords[52]  := 'raise';
 HL.Keywords[53]  := 'property';
 HL.Keywords[54]  := 'public';
 HL.Keywords[55]  := 'private';
 HL.Keywords[56]  := 'protected';
 HL.Keywords[57]  := 'published';
 HL.Keywords[58]  := 'override';
 HL.Keywords[59]  := 'virtual';
 HL.Keywords[60]  := 'abstract';
 HL.Keywords[61]  := 'reintroduce';
 HL.Keywords[62]  := 'operator';
 HL.Keywords[63]  := 'generic';
 HL.Keywords[64]  := 'specialize';
 HL.KeywordCount := MAX_PASCAL_KEYWORDS;
End;

{ --- Initialiser le surligneur Pascal --- }

Procedure InitPascalHighlighter(Var HL: TPascalHighlighter);
Begin
 InitHighlighter(HL.Base, 'Pascal');
 InitPascalKeywords(HL);
End;

{ --- Verifier si un mot est un mot-cle Pascal (insensible casse) --- }

Function IsPascalKeyword(Var HL: TPascalHighlighter;
                         Word: String): Boolean;
Var
 I: Integer;
 LW: String;
Begin
 IsPascalKeyword := False;
 LW := LowerCaseStr(Word);
 For I := 0 To HL.KeywordCount - 1 Do
 Begin
  If LW = HL.Keywords[I] Then
  Begin
   IsPascalKeyword := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si un mot est un type predefini Pascal --- }

Function IsPascalType(Word: String): Boolean;
Var
 LW: String;
Begin
 LW := LowerCaseStr(Word);
 IsPascalType :=
  (LW = 'integer') Or (LW = 'longint') Or (LW = 'word') Or
  (LW = 'byte') Or (LW = 'boolean') Or (LW = 'char') Or
  (LW = 'string') Or (LW = 'real') Or (LW = 'double') Or
  (LW = 'extended') Or (LW = 'pointer') Or (LW = 'text') Or
  (LW = 'shortint') Or (LW = 'smallint') Or (LW = 'cardinal') Or
  (LW = 'int64') Or (LW = 'qword') Or (LW = 'single') Or
  (LW = 'comp') Or (LW = 'currency') Or (LW = 'ansistring') Or
  (LW = 'widestring') Or (LW = 'pchar') Or (LW = 'longword');
End;

{ --- Classifier un jeton Pascal (identifier -> keyword/type) --- }

Function ClassifyPascalToken(Var HL: TPascalHighlighter;
                             Line: String;
                             StartPos, EndPos: Integer): TTokenClass;
Var
 Word: String;
Begin
 Word := Copy(Line, StartPos, EndPos - StartPos);
 If IsPascalType(Word) Then
  ClassifyPascalToken := TC_TYPE
 Else If IsPascalKeyword(HL, Word) Then
  ClassifyPascalToken := TC_KEYWORD
 Else
  ClassifyPascalToken := TC_IDENTIFIER;
End;

{ --- Obtenir la classe de jeton Pascal a une position --- }

Function GetPascalTokenClass(Var HL: TPascalHighlighter;
                             Line: String;
                             Var Pos: Integer): TTokenClass;
Var
 StartPos: Integer;
 TC: TTokenClass;
Begin
 StartPos := Pos;
 TC := GetTokenClass(HL.Base, Line, Pos);
 If TC = TC_IDENTIFIER Then
  GetPascalTokenClass := ClassifyPascalToken(HL, Line, StartPos, Pos)
 Else
  GetPascalTokenClass := TC;
End;

{ --- Colorier une ligne Pascal entiere --- }

Procedure HighlightPascalLine(Var HL: TPascalHighlighter;
                              Line: String;
                              Var Colors: Array Of Byte);
Var
 Pos, Start, I, Len: Integer;
 TC: TTokenClass;
 Clr: Byte;
Begin
 Len := Length(Line);
 For I := 0 To Len - 1 Do
  Colors[I] := Byte(TokenClassToColor(TC_NORMAL));

 Pos := 1;
 While Pos <= Len Do
 Begin
  Start := Pos;
  TC := GetPascalTokenClass(HL, Line, Pos);
  Clr := Byte(TokenClassToColor(TC));
  For I := Start To Pos - 1 Do
  Begin
   If (I >= 1) And (I <= Len) Then
    Colors[I - 1] := Clr;
  End;
 End;
End;

{ --- Obtenir le nom d un type de jeton Pascal --- }

Function PascalTokenClassName(TC: TTokenClass): String;
Begin
 PascalTokenClassName := TokenClassName(TC);
End;

{ --- Compter les mots-cles Pascal --- }

Function CountPascalKeywords(Var HL: TPascalHighlighter): Integer;
Begin
 CountPascalKeywords := HL.KeywordCount;
End;

{ --- Verifier si un mot est une directive de compilation Pascal --- }

Function IsPascalDirective(Word: String): Boolean;
Var
 LW: String;
Begin
 LW := LowerCaseStr(Word);
 IsPascalDirective :=
  (LW = 'i') Or (LW = 'ifdef') Or (LW = 'ifndef') Or
  (LW = 'endif') Or (LW = 'else') Or (LW = 'define') Or
  (LW = 'undef') Or (LW = 'mode') Or (LW = 'h+') Or
  (LW = 'h-') Or (LW = 'r+') Or (LW = 'r-') Or
  (LW = 'q+') Or (LW = 'q-') Or (LW = 'include') Or
  (LW = 'linklib') Or (LW = 'macro') Or (LW = 'ifopt');
End;

{ --- Verifier si un caractere est un operateur Pascal --- }

Function IsPascalOperator(Ch: Char): Boolean;
Begin
 IsPascalOperator :=
  (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
  (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = ':') Or
  (Ch = '.') Or (Ch = '@') Or (Ch = '^');
End;

{ --- Verifier si une position est un debut de commentaire Pascal --- }

Function IsPascalCommentStart(Line: String; Pos: Integer): Boolean;
Begin
 IsPascalCommentStart := False;
 If Pos > Length(Line) Then Exit;
 If Line[Pos] = '{' Then
 Begin
  IsPascalCommentStart := True;
  Exit;
 End;
 If Pos + 1 <= Length(Line) Then
 Begin
  If (Line[Pos] = '(') And (Line[Pos + 1] = '*') Then
  Begin
   IsPascalCommentStart := True;
   Exit;
  End;
  If (Line[Pos] = '/') And (Line[Pos + 1] = '/') Then
   IsPascalCommentStart := True;
 End;
End;

{ --- Verifier si une ligne contient un nombre hexadecimal Pascal --- }

Function HasPascalHexLiteral(Line: String): Boolean;
Var
 I: Integer;
Begin
 HasPascalHexLiteral := False;
 For I := 1 To Length(Line) Do
 Begin
  If Line[I] = '$' Then
  Begin
   If (I + 1 <= Length(Line)) And (IsHexDigit(Line[I + 1])) Then
   Begin
    HasPascalHexLiteral := True;
    Exit;
   End;
  End;
 End;
End;

{ --- Verifier si une ligne contient un nombre binaire Pascal (FPC) --- }

Function HasPascalBinaryLiteral(Line: String): Boolean;
Var
 I: Integer;
Begin
 HasPascalBinaryLiteral := False;
 For I := 1 To Length(Line) Do
 Begin
  If Line[I] = '%' Then
  Begin
   If (I + 1 <= Length(Line)) And
      ((Line[I + 1] = '0') Or (Line[I + 1] = '1')) Then
   Begin
    HasPascalBinaryLiteral := True;
    Exit;
   End;
  End;
 End;
End;

{ --- Verifier si une ligne contient un nombre octal Pascal (FPC) --- }

Function HasPascalOctalLiteral(Line: String): Boolean;
Var
 I: Integer;
Begin
 HasPascalOctalLiteral := False;
 For I := 1 To Length(Line) Do
 Begin
  If Line[I] = '&' Then
  Begin
   If (I + 1 <= Length(Line)) And
      (Line[I + 1] >= '0') And (Line[I + 1] <= '7') Then
   Begin
    HasPascalOctalLiteral := True;
    Exit;
   End;
  End;
 End;
End;

{ --- Compter les classes de jetons Pascal dans une ligne --- }

Function CountPascalTokensInLine(Var HL: TPascalHighlighter;
                                 Line: String): Integer;
Var
 Pos, Count: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 Count := 0;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetPascalTokenClass(HL, Line, Pos);
  Inc(Count);
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
 CountPascalTokensInLine := Count;
End;

{ --- Verifier si une ligne Pascal contient un commentaire --- }

Function PascalLineHasComment(Var HL: TPascalHighlighter;
                               Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 PascalLineHasComment := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetPascalTokenClass(HL, Line, Pos);
  If TC = TC_COMMENT Then
  Begin
   PascalLineHasComment := True;
   Break;
  End;
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
End;

{ --- Verifier si une ligne Pascal contient une chaine --- }

Function PascalLineHasString(Var HL: TPascalHighlighter;
                              Line: String): Boolean;
Var
 Pos: Integer;
 TC: TTokenClass;
 SaveBC, SaveStr: Boolean;
 SaveTop: Integer;
Begin
 SaveBC := HL.Base.InBlockComment;
 SaveStr := HL.Base.InString;
 SaveTop := HL.Base.StateTop;
 PascalLineHasString := False;
 Pos := 1;
 While Pos <= Length(Line) Do
 Begin
  TC := GetPascalTokenClass(HL, Line, Pos);
  If TC = TC_STRING Then
  Begin
   PascalLineHasString := True;
   Break;
  End;
 End;
 HL.Base.InBlockComment := SaveBC;
 HL.Base.InString := SaveStr;
 HL.Base.StateTop := SaveTop;
End;

{ --- Verifier si une position contient un caractere literal Pascal --- }

Function IsPascalCharLiteral(Line: String; Pos: Integer): Boolean;
Begin
 IsPascalCharLiteral := False;
 If (Pos >= 1) And (Pos <= Length(Line)) Then
 Begin
  If Line[Pos] = '#' Then
  Begin
   If (Pos + 1 <= Length(Line)) And
      (Line[Pos + 1] >= '0') And (Line[Pos + 1] <= '9') Then
    IsPascalCharLiteral := True;
  End;
 End;
End;

{ --- Convertir un mot Pascal en minuscules pour comparaison --- }

Function PascalLowerCase(Word: String): String;
Begin
 PascalLowerCase := LowerCaseStr(Word);
End;

{ ============================================================
  TODO 15 - PARSEUR DE FICHIERS SOLUTION (.SLN) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser les informations de solution --- }

Procedure InitSolutionInfo(Var Info: TSolutionInfo);
Begin
 Info.FormatVersion := SLN_FORMAT_VERSION;
 Info.VSVersion := SLN_VS_VERSION;
 Info.MinVSVersion := SLN_MIN_VS_VERSION;
 Info.GUID := '';
 Info.SolutionName := '';
 Info.SolutionPath := '';
End;

{ --- Initialiser une entree de projet --- }

Procedure InitProjectEntry(Var Entry: TProjectEntry);
Var
 I: Integer;
Begin
 Entry.ProjectTypeGUID := '';
 Entry.ProjectGUID := '';
 Entry.ProjectName := '';
 Entry.ProjectPath := '';
 Entry.DepCount := 0;
 For I := 0 To MAX_DEPENDENCIES - 1 Do
  Entry.Dependencies[I] := '';
End;

{ --- Initialiser une structure de solution --- }

Procedure InitSolution(Var Sol: TSolution);
Var
 I: Integer;
Begin
 InitSolutionInfo(Sol.Info);
 Sol.ProjectCount := 0;
 Sol.ConfigCount := 0;
 For I := 0 To MAX_SOLUTION_PROJECTS - 1 Do
  InitProjectEntry(Sol.Projects[I]);
 For I := 0 To MAX_SOLUTION_CONFIGS - 1 Do
  Sol.Configs[I] := '';
End;

{ --- Obtenir le GUID du type de projet --- }

Function GetProjectTypeGUID(ProjType: TProjectType): String;
Begin
 Case ProjType Of
  PT_CSHARP  : GetProjectTypeGUID := GUID_CSHARP;
  PT_VBNET   : GetProjectTypeGUID := GUID_VBNET;
  PT_PASCAL  : GetProjectTypeGUID := GUID_PASCAL;
 Else
  GetProjectTypeGUID := '';
 End;
End;

{ --- Determiner le type de projet a partir du GUID --- }

Function ProjectTypeFromGUID(GUID: String): TProjectType;
Var
 Upper: String;
Begin
 Upper := UpCaseStr(GUID);
 If Upper = UpCaseStr(GUID_CSHARP) Then
  ProjectTypeFromGUID := PT_CSHARP
 Else If Upper = UpCaseStr(GUID_VBNET) Then
  ProjectTypeFromGUID := PT_VBNET
 Else If Upper = UpCaseStr(GUID_PASCAL) Then
  ProjectTypeFromGUID := PT_PASCAL
 Else
  ProjectTypeFromGUID := PT_UNKNOWN;
End;

{ --- Creer une nouvelle solution --- }

Function CreateNewSolution(Name, Path: String): TSolution;
Var
 Sol: TSolution;
Begin
 InitSolution(Sol);
 Sol.Info.SolutionName := Name;
 Sol.Info.SolutionPath := Path;
 Sol.Info.FormatVersion := SLN_FORMAT_VERSION;
 Sol.Info.VSVersion := SLN_VS_VERSION;
 Sol.Info.MinVSVersion := SLN_MIN_VS_VERSION;
 Sol.ConfigCount := 2;
 Sol.Configs[0] := 'Debug|Any CPU';
 Sol.Configs[1] := 'Release|Any CPU';
 CreateNewSolution := Sol;
End;

{ --- Liberer les ressources d une solution --- }

Procedure FreeSolution(Var Sol: TSolution);
Begin
 InitSolution(Sol);
End;

{ --- Ajouter un projet a la solution --- }

Procedure AddProjectToSolution(Var Sol: TSolution;
  ProjName, ProjPath: String; ProjType: TProjectType);
Begin
 If Sol.ProjectCount >= MAX_SOLUTION_PROJECTS Then
  Exit;
 With Sol.Projects[Sol.ProjectCount] Do
 Begin
  ProjectTypeGUID := GetProjectTypeGUID(ProjType);
  ProjectGUID := '';
  ProjectName := ProjName;
  ProjectPath := ProjPath;
  DepCount := 0;
 End;
 Inc(Sol.ProjectCount);
End;

{ --- Retirer un projet de la solution --- }

Procedure RemoveProjectFromSolution(Var Sol: TSolution;
  Index: Integer);
Var
 I: Integer;
Begin
 If (Index < 0) Or (Index >= Sol.ProjectCount) Then
  Exit;
 For I := Index To Sol.ProjectCount - 2 Do
  Sol.Projects[I] := Sol.Projects[I + 1];
 Dec(Sol.ProjectCount);
 InitProjectEntry(Sol.Projects[Sol.ProjectCount]);
End;

{ --- Extraire une valeur entre guillemets --- }

Function ExtractQuoted(Line: String; StartPos: Integer;
  Var Value: String): Integer;
Var
 P: Integer;
Begin
 Value := '';
 ExtractQuoted := StartPos;
 P := StartPos;
 While (P <= Length(Line)) And (Line[P] <> '"') Do
  Inc(P);
 If P > Length(Line) Then Exit;
 Inc(P); { depasser le guillemet ouvrant }
 While (P <= Length(Line)) And (Line[P] <> '"') Do
 Begin
  Value := Value + Line[P];
  Inc(P);
 End;
 If P <= Length(Line) Then
  Inc(P); { depasser le guillemet fermant }
 ExtractQuoted := P;
End;

{ --- Parser un fichier solution (.SLN) --- }

Procedure ParseSolutionFile(FileName: String;
  Var Sol: TSolution);
Var
 F: Text;
 Line, Trimmed: String;
 P: Integer;
 TypeGUID, PName, PPath, PGUID: String;
 InGlobal, InConfigSection: Boolean;
Begin
 InitSolution(Sol);
 Sol.Info.SolutionPath := ExtractFilePath(FileName);
 Sol.Info.SolutionName := ExtractFileName(FileName);
 Assign(F, FileName);
 {$I-}
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 InGlobal := False;
 InConfigSection := False;
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  Trimmed := TrimStr(Line);
  { Version du format }
  If Copy(Trimmed, 1, 34) = 'Microsoft Visual Studio Solution F' Then
  Begin
   P := System.Pos('Format Version ', Trimmed);
   If P > 0 Then
    Sol.Info.FormatVersion := Copy(Trimmed, P + 15,
      Length(Trimmed) - P - 14);
  End
  Else If Copy(Trimmed, 1, 20) = 'VisualStudioVersion ' Then
  Begin
   P := System.Pos('= ', Trimmed);
   If P > 0 Then
    Sol.Info.VSVersion := TrimStr(Copy(Trimmed, P + 2,
      Length(Trimmed) - P - 1));
  End
  Else If Copy(Trimmed, 1, 27) = 'MinimumVisualStudioVersion ' Then
  Begin
   P := System.Pos('= ', Trimmed);
   If P > 0 Then
    Sol.Info.MinVSVersion := TrimStr(Copy(Trimmed, P + 2,
      Length(Trimmed) - P - 1));
  End
  { Ligne Project }
  Else If Copy(Trimmed, 1, 8) = 'Project(' Then
  Begin
   If Sol.ProjectCount < MAX_SOLUTION_PROJECTS Then
   Begin
    P := 9;
    P := ExtractQuoted(Trimmed, P, TypeGUID);
    { Chercher le signe = }
    While (P <= Length(Trimmed)) And (Trimmed[P] <> '=') Do
     Inc(P);
    Inc(P);
    P := ExtractQuoted(Trimmed, P, PName);
    { Passer la virgule }
    While (P <= Length(Trimmed)) And (Trimmed[P] <> ',') Do
     Inc(P);
    Inc(P);
    P := ExtractQuoted(Trimmed, P, PPath);
    { Passer la virgule }
    While (P <= Length(Trimmed)) And (Trimmed[P] <> ',') Do
     Inc(P);
    Inc(P);
    P := ExtractQuoted(Trimmed, P, PGUID);
    With Sol.Projects[Sol.ProjectCount] Do
    Begin
     ProjectTypeGUID := TypeGUID;
     ProjectGUID := PGUID;
     ProjectName := PName;
     ProjectPath := PPath;
     DepCount := 0;
    End;
    Inc(Sol.ProjectCount);
   End;
  End
  { Sections Global }
  Else If Trimmed = 'Global' Then
   InGlobal := True
  Else If Trimmed = 'EndGlobal' Then
  Begin
   InGlobal := False;
   InConfigSection := False;
  End
  Else If InGlobal Then
  Begin
   If System.Pos('SolutionConfigurationPlatforms', Trimmed) > 0 Then
   Begin
    InConfigSection := True;
   End
   Else If System.Pos('ProjectConfigurationPlatforms', Trimmed) > 0 Then
   Begin
    InConfigSection := False;
   End
   Else If System.Pos('EndGlobalSection', Trimmed) > 0 Then
   Begin
    InConfigSection := False;
   End
   Else If InConfigSection Then
   Begin
    { Lire les configurations : "Debug|Any CPU = Debug|Any CPU" }
    P := System.Pos('=', Trimmed);
    If (P > 0) And (Sol.ConfigCount < MAX_SOLUTION_CONFIGS) Then
    Begin
     Sol.Configs[Sol.ConfigCount] := TrimStr(Copy(Trimmed, 1, P - 1));
     Inc(Sol.ConfigCount);
    End;
   End;
  End;
 End;
 Close(F);
 P := IOResult;
End;

{ --- Enregistrer un fichier solution (.SLN) --- }

Procedure SaveSolutionFile(FileName: String;
  Var Sol: TSolution);
Var
 F: Text;
 I, J: Integer;
Begin
 Assign(F, FileName);
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, '');
 WriteLn(F, 'Microsoft Visual Studio Solution File, Format Version ',
   Sol.Info.FormatVersion);
 WriteLn(F, '# ', Sol.Info.VSVersion);
 WriteLn(F, 'VisualStudioVersion = ', Sol.Info.VSVersion);
 WriteLn(F, 'MinimumVisualStudioVersion = ', Sol.Info.MinVSVersion);
 { Ecrire les projets }
 For I := 0 To Sol.ProjectCount - 1 Do
 Begin
  With Sol.Projects[I] Do
  Begin
   WriteLn(F, 'Project("', ProjectTypeGUID, '") = "',
     ProjectName, '", "', ProjectPath, '", "', ProjectGUID, '"');
   WriteLn(F, 'EndProject');
  End;
 End;
 { Ecrire la section Global }
 WriteLn(F, 'Global');
 { Configurations de solution }
 WriteLn(F, #9, 'GlobalSection(SolutionConfigurationPlatforms) = preSolution');
 For I := 0 To Sol.ConfigCount - 1 Do
  WriteLn(F, #9, #9, Sol.Configs[I], ' = ', Sol.Configs[I]);
 WriteLn(F, #9, 'EndGlobalSection');
 { Configurations de projet }
 WriteLn(F, #9, 'GlobalSection(ProjectConfigurationPlatforms) = postSolution');
 For I := 0 To Sol.ProjectCount - 1 Do
  For J := 0 To Sol.ConfigCount - 1 Do
  Begin
   WriteLn(F, #9, #9, Sol.Projects[I].ProjectGUID, '.',
     Sol.Configs[J], '.ActiveCfg = ', Sol.Configs[J]);
   WriteLn(F, #9, #9, Sol.Projects[I].ProjectGUID, '.',
     Sol.Configs[J], '.Build.0 = ', Sol.Configs[J]);
  End;
 WriteLn(F, #9, 'EndGlobalSection');
 { Proprietes de solution }
 WriteLn(F, #9, 'GlobalSection(SolutionProperties) = preSolution');
 WriteLn(F, #9, #9, 'HideSolutionNode = FALSE');
 WriteLn(F, #9, 'EndGlobalSection');
 WriteLn(F, 'EndGlobal');
 Close(F);
 I := IOResult;
End;

{ --- Obtenir le nombre de projets --- }

Function GetProjectCount(Var Sol: TSolution): Integer;
Begin
 GetProjectCount := Sol.ProjectCount;
End;

{ --- Obtenir un projet par son index --- }

Function GetProjectByIndex(Var Sol: TSolution;
  Index: Integer): TProjectEntry;
Var
 Empty: TProjectEntry;
Begin
 If (Index >= 0) And (Index < Sol.ProjectCount) Then
  GetProjectByIndex := Sol.Projects[Index]
 Else
 Begin
  InitProjectEntry(Empty);
  GetProjectByIndex := Empty;
 End;
End;

{ --- Chercher un projet par son nom --- }

Function FindProjectByName(Var Sol: TSolution;
  Name: String): Integer;
Var
 I: Integer;
 LName: String;
Begin
 FindProjectByName := -1;
 LName := LowerCaseStr(Name);
 For I := 0 To Sol.ProjectCount - 1 Do
  If LowerCaseStr(Sol.Projects[I].ProjectName) = LName Then
  Begin
   FindProjectByName := I;
   Exit;
  End;
End;

{ --- Chercher un projet par son GUID --- }

Function FindProjectByGUID(Var Sol: TSolution;
  GUID: String): Integer;
Var
 I: Integer;
 UGUID: String;
Begin
 FindProjectByGUID := -1;
 UGUID := UpCaseStr(GUID);
 For I := 0 To Sol.ProjectCount - 1 Do
  If UpCaseStr(Sol.Projects[I].ProjectGUID) = UGUID Then
  Begin
   FindProjectByGUID := I;
   Exit;
  End;
End;

{ --- Verifier si un index de projet est valide --- }

Function IsValidProjectIndex(Var Sol: TSolution;
  Index: Integer): Boolean;
Begin
 IsValidProjectIndex := (Index >= 0) And
   (Index < Sol.ProjectCount);
End;

{ --- Verifier si un projet existe par son nom --- }

Function HasProject(Var Sol: TSolution;
  Name: String): Boolean;
Begin
 HasProject := FindProjectByName(Sol, Name) >= 0;
End;

{ --- Obtenir le nombre de configurations --- }

Function GetConfigurationCount(Var Sol: TSolution): Integer;
Begin
 GetConfigurationCount := Sol.ConfigCount;
End;

{ --- Obtenir le nom de la solution --- }

Function GetSolutionName(Var Sol: TSolution): String;
Begin
 GetSolutionName := Sol.Info.SolutionName;
End;

{ --- Obtenir le chemin de la solution --- }

Function GetSolutionPath(Var Sol: TSolution): String;
Begin
 GetSolutionPath := Sol.Info.SolutionPath;
End;

{ --- Verifier si la solution est vide --- }

Function IsSolutionEmpty(Var Sol: TSolution): Boolean;
Begin
 IsSolutionEmpty := Sol.ProjectCount = 0;
End;

{ ============================================================
  TODO 16 - PARSEUR DE FICHIERS PROJET (.CSPROJ, .VBPROJ, .DPPROJ) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser les informations de projet --- }

Procedure InitProjectInfo(Var Info: TProjectInfo);
Begin
 Info.ProjectName := '';
 Info.RootNamespace := '';
 Info.AssemblyName := '';
 Info.OutputType := OT_EXE;
 Info.TargetFramework := 'v4.8';
 Info.OutputPath := 'bin\Debug\';
 Info.DefineConstants := '';
 Info.ProjectType := PT_CSHARP;
 Info.ProjectGUID := '';
End;

{ --- Initialiser un fichier de projet --- }

Procedure InitProjectFile(Var PF: TProjectFile);
Begin
 PF.FileName := '';
 PF.BuildAction := BA_COMPILE;
 PF.DependentUpon := '';
 PF.SubType := '';
End;

{ --- Initialiser une reference de projet --- }

Procedure InitProjectRef(Var PR: TProjectRef);
Begin
 PR.ReferenceName := '';
 PR.HintPath := '';
 PR.ProjectGUID := '';
End;

{ --- Initialiser une configuration de build --- }

Procedure InitBuildConfig(Var Cfg: TBuildConfig);
Begin
 Cfg.ConfigName := '';
 Cfg.OutputPath := '';
 Cfg.DefineConst := '';
 Cfg.Optimize := False;
 Cfg.DebugSymbols := False;
End;

{ --- Initialiser un projet complet --- }

Procedure InitProject(Var Proj: TProject);
Var
 I: Integer;
Begin
 InitProjectInfo(Proj.Info);
 For I := 0 To MAX_PROJECT_FILES - 1 Do
  InitProjectFile(Proj.Files[I]);
 Proj.FileCount := 0;
 For I := 0 To MAX_PROJECT_REFS - 1 Do
  InitProjectRef(Proj.Refs[I]);
 Proj.RefCount := 0;
 For I := 0 To MAX_BUILD_CONFIGS - 1 Do
  InitBuildConfig(Proj.Configs[I]);
 Proj.CfgCount := 0;
End;

{ --- Convertir une chaine en type de sortie --- }

Function OutputTypeFromStr(S: String): TOutputType;
Var
 Low: String;
Begin
 Low := LowerCaseStr(S);
 If Low = 'library' Then
  OutputTypeFromStr := OT_LIBRARY
 Else If Low = 'winexe' Then
  OutputTypeFromStr := OT_WINEXE
 Else
  OutputTypeFromStr := OT_EXE;
End;

{ --- Convertir un type de sortie en chaine --- }

Function OutputTypeToStr(OT: TOutputType): String;
Begin
 Case OT Of
  OT_EXE: OutputTypeToStr := 'Exe';
  OT_LIBRARY: OutputTypeToStr := 'Library';
  OT_WINEXE: OutputTypeToStr := 'WinExe';
 End;
End;

{ --- Convertir une chaine en action de build --- }

Function BuildActionFromStr(S: String): TBuildAction;
Var
 Low: String;
Begin
 Low := LowerCaseStr(S);
 If Low = 'content' Then
  BuildActionFromStr := BA_CONTENT
 Else If Low = 'none' Then
  BuildActionFromStr := BA_NONE
 Else If Low = 'embeddedresource' Then
  BuildActionFromStr := BA_EMBEDDED_RESOURCE
 Else
  BuildActionFromStr := BA_COMPILE;
End;

{ --- Convertir une action de build en chaine --- }

Function BuildActionToStr(BA: TBuildAction): String;
Begin
 Case BA Of
  BA_COMPILE: BuildActionToStr := 'Compile';
  BA_CONTENT: BuildActionToStr := 'Content';
  BA_NONE: BuildActionToStr := 'None';
  BA_EMBEDDED_RESOURCE: BuildActionToStr := 'EmbeddedResource';
 End;
End;

{ --- Creer un nouveau projet --- }

Function CreateNewProject(Name, Path: String;
  ProjType: TProjectType): TProject;
Var
 Proj: TProject;
Begin
 InitProject(Proj);
 Proj.Info.ProjectName := Name;
 Proj.Info.RootNamespace := Name;
 Proj.Info.AssemblyName := Name;
 Proj.Info.ProjectType := ProjType;
 Proj.Info.OutputType := OT_EXE;
 Proj.Info.OutputPath := 'bin\Debug\';
 { Ajouter configurations par defaut }
 Proj.Configs[0].ConfigName := 'Debug|AnyCPU';
 Proj.Configs[0].OutputPath := 'bin\Debug\';
 Proj.Configs[0].DefineConst := 'DEBUG;TRACE';
 Proj.Configs[0].Optimize := False;
 Proj.Configs[0].DebugSymbols := True;
 Proj.Configs[1].ConfigName := 'Release|AnyCPU';
 Proj.Configs[1].OutputPath := 'bin\Release\';
 Proj.Configs[1].DefineConst := 'TRACE';
 Proj.Configs[1].Optimize := True;
 Proj.Configs[1].DebugSymbols := False;
 Proj.CfgCount := 2;
 CreateNewProject := Proj;
End;

{ --- Liberer un projet --- }

Procedure FreeProject(Var Proj: TProject);
Begin
 InitProject(Proj);
End;

{ --- Ajouter un fichier au projet --- }

Procedure AddFileToProject(Var Proj: TProject;
  FileName: String);
Begin
 If Proj.FileCount >= MAX_PROJECT_FILES Then Exit;
 InitProjectFile(Proj.Files[Proj.FileCount]);
 Proj.Files[Proj.FileCount].FileName := FileName;
 Proj.Files[Proj.FileCount].BuildAction := BA_COMPILE;
 Inc(Proj.FileCount);
End;

{ --- Supprimer un fichier du projet --- }

Procedure RemoveFileFromProject(Var Proj: TProject;
  Index: Integer);
Var
 I: Integer;
Begin
 If (Index < 0) Or (Index >= Proj.FileCount) Then Exit;
 For I := Index To Proj.FileCount - 2 Do
  Proj.Files[I] := Proj.Files[I + 1];
 Dec(Proj.FileCount);
 InitProjectFile(Proj.Files[Proj.FileCount]);
End;

{ --- Ajouter une reference au projet --- }

Procedure AddReferenceToProject(Var Proj: TProject;
  RefName: String);
Begin
 If Proj.RefCount >= MAX_PROJECT_REFS Then Exit;
 InitProjectRef(Proj.Refs[Proj.RefCount]);
 Proj.Refs[Proj.RefCount].ReferenceName := RefName;
 Inc(Proj.RefCount);
End;

{ --- Supprimer une reference du projet --- }

Procedure RemoveReferenceFromProject(Var Proj: TProject;
  Index: Integer);
Var
 I: Integer;
Begin
 If (Index < 0) Or (Index >= Proj.RefCount) Then Exit;
 For I := Index To Proj.RefCount - 2 Do
  Proj.Refs[I] := Proj.Refs[I + 1];
 Dec(Proj.RefCount);
 InitProjectRef(Proj.Refs[Proj.RefCount]);
End;

{ --- Extraire le contenu d une balise XML --- }

Function ExtractTagContent(Line, Tag: String): String;
Var
 P1, P2: Integer;
 OpenTag, CloseTag: String;
Begin
 ExtractTagContent := '';
 OpenTag := '<' + Tag + '>';
 CloseTag := '</' + Tag + '>';
 P1 := Pos(OpenTag, Line);
 If P1 = 0 Then Exit;
 P1 := P1 + Length(OpenTag);
 P2 := Pos(CloseTag, Line);
 If P2 = 0 Then Exit;
 If P2 > P1 Then
  ExtractTagContent := Copy(Line, P1, P2 - P1);
End;

{ --- Extraire un attribut XML --- }

Function ExtractAttribute(Line, AttrName: String): String;
Var
 P1, P2: Integer;
 Search: String;
Begin
 ExtractAttribute := '';
 Search := AttrName + '="';
 P1 := Pos(Search, Line);
 If P1 = 0 Then Exit;
 P1 := P1 + Length(Search);
 P2 := P1;
 While (P2 <= Length(Line)) And (Line[P2] <> '"') Do
  Inc(P2);
 If P2 > P1 Then
  ExtractAttribute := Copy(Line, P1, P2 - P1);
End;

{ --- Verifier si une ligne contient une balise --- }

Function HasTag(Line, Tag: String): Boolean;
Begin
 HasTag := (Pos('<' + Tag + '>', Line) > 0) Or
           (Pos('<' + Tag + ' ', Line) > 0);
End;

{ --- Verifier si une ligne contient une balise fermante --- }

Function HasClosingTag(Line, Tag: String): Boolean;
Begin
 HasClosingTag := Pos('</' + Tag + '>', Line) > 0;
End;

{ --- Parser un fichier projet --- }

Procedure ParseProjectFile(FileName: String;
  Var Proj: TProject);
Var
 F: Text;
 Line, Trimmed: String;
 InPropertyGroup: Boolean;
 InItemGroup: Boolean;
 CondStr: String;
 CfgIdx: Integer;
Begin
 InitProject(Proj);
 Assign(F, FileName);
 {$I-}
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 InPropertyGroup := False;
 InItemGroup := False;
 CfgIdx := -1;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  Trimmed := TrimStr(Line);
  { PropertyGroup }
  If HasTag(Trimmed, 'PropertyGroup') Then Begin
   InPropertyGroup := True;
   CondStr := ExtractAttribute(Trimmed, 'Condition');
   If CondStr <> '' Then Begin
    If Proj.CfgCount < MAX_BUILD_CONFIGS Then Begin
     CfgIdx := Proj.CfgCount;
     Inc(Proj.CfgCount);
     InitBuildConfig(Proj.Configs[CfgIdx]);
     If Pos('Debug', CondStr) > 0 Then
      Proj.Configs[CfgIdx].ConfigName := 'Debug|AnyCPU'
     Else If Pos('Release', CondStr) > 0 Then
      Proj.Configs[CfgIdx].ConfigName := 'Release|AnyCPU'
     Else
      Proj.Configs[CfgIdx].ConfigName := CondStr;
    End;
   End Else
    CfgIdx := -1;
  End;
  If HasClosingTag(Trimmed, 'PropertyGroup') Then Begin
   InPropertyGroup := False;
   CfgIdx := -1;
  End;
  { ItemGroup }
  If HasTag(Trimmed, 'ItemGroup') Then
   InItemGroup := True;
  If HasClosingTag(Trimmed, 'ItemGroup') Then
   InItemGroup := False;
  { Proprietes du projet dans PropertyGroup }
  If InPropertyGroup Then Begin
   If ExtractTagContent(Trimmed, 'RootNamespace') <> '' Then
    Proj.Info.RootNamespace := ExtractTagContent(Trimmed, 'RootNamespace');
   If ExtractTagContent(Trimmed, 'AssemblyName') <> '' Then
    Proj.Info.AssemblyName := ExtractTagContent(Trimmed, 'AssemblyName');
   If ExtractTagContent(Trimmed, 'OutputType') <> '' Then
    Proj.Info.OutputType := OutputTypeFromStr(
      ExtractTagContent(Trimmed, 'OutputType'));
   If ExtractTagContent(Trimmed, 'TargetFrameworkVersion') <> '' Then
    Proj.Info.TargetFramework := ExtractTagContent(
      Trimmed, 'TargetFrameworkVersion');
   If ExtractTagContent(Trimmed, 'ProjectGuid') <> '' Then
    Proj.Info.ProjectGUID := ExtractTagContent(Trimmed, 'ProjectGuid');
   If CfgIdx >= 0 Then Begin
    If ExtractTagContent(Trimmed, 'OutputPath') <> '' Then
     Proj.Configs[CfgIdx].OutputPath := ExtractTagContent(
       Trimmed, 'OutputPath');
    If ExtractTagContent(Trimmed, 'DefineConstants') <> '' Then
     Proj.Configs[CfgIdx].DefineConst := ExtractTagContent(
       Trimmed, 'DefineConstants');
    If ExtractTagContent(Trimmed, 'Optimize') <> '' Then
     Proj.Configs[CfgIdx].Optimize :=
       LowerCaseStr(ExtractTagContent(Trimmed, 'Optimize')) = 'true';
    If ExtractTagContent(Trimmed, 'DebugSymbols') <> '' Then
     Proj.Configs[CfgIdx].DebugSymbols :=
       LowerCaseStr(ExtractTagContent(Trimmed, 'DebugSymbols')) = 'true';
   End Else Begin
    If ExtractTagContent(Trimmed, 'OutputPath') <> '' Then
     Proj.Info.OutputPath := ExtractTagContent(Trimmed, 'OutputPath');
    If ExtractTagContent(Trimmed, 'DefineConstants') <> '' Then
     Proj.Info.DefineConstants := ExtractTagContent(
       Trimmed, 'DefineConstants');
   End;
  End;
  { Fichiers Compile dans ItemGroup }
  If InItemGroup And HasTag(Trimmed, 'Compile') Then Begin
   If Proj.FileCount < MAX_PROJECT_FILES Then Begin
    InitProjectFile(Proj.Files[Proj.FileCount]);
    Proj.Files[Proj.FileCount].FileName :=
      ExtractAttribute(Trimmed, 'Include');
    Proj.Files[Proj.FileCount].BuildAction := BA_COMPILE;
    Inc(Proj.FileCount);
   End;
  End;
  { Fichiers Content dans ItemGroup }
  If InItemGroup And HasTag(Trimmed, 'Content') Then Begin
   If Proj.FileCount < MAX_PROJECT_FILES Then Begin
    InitProjectFile(Proj.Files[Proj.FileCount]);
    Proj.Files[Proj.FileCount].FileName :=
      ExtractAttribute(Trimmed, 'Include');
    Proj.Files[Proj.FileCount].BuildAction := BA_CONTENT;
    Inc(Proj.FileCount);
   End;
  End;
  { Fichiers None dans ItemGroup }
  If InItemGroup And HasTag(Trimmed, 'None') Then Begin
   If Proj.FileCount < MAX_PROJECT_FILES Then Begin
    InitProjectFile(Proj.Files[Proj.FileCount]);
    Proj.Files[Proj.FileCount].FileName :=
      ExtractAttribute(Trimmed, 'Include');
    Proj.Files[Proj.FileCount].BuildAction := BA_NONE;
    Inc(Proj.FileCount);
   End;
  End;
  { Fichiers EmbeddedResource dans ItemGroup }
  If InItemGroup And HasTag(Trimmed, 'EmbeddedResource') Then Begin
   If Proj.FileCount < MAX_PROJECT_FILES Then Begin
    InitProjectFile(Proj.Files[Proj.FileCount]);
    Proj.Files[Proj.FileCount].FileName :=
      ExtractAttribute(Trimmed, 'Include');
    Proj.Files[Proj.FileCount].BuildAction := BA_EMBEDDED_RESOURCE;
    Inc(Proj.FileCount);
   End;
  End;
  { DependentUpon pour le dernier fichier ajoute }
  If InItemGroup And (ExtractTagContent(Trimmed,
      'DependentUpon') <> '') Then Begin
   If Proj.FileCount > 0 Then
    Proj.Files[Proj.FileCount - 1].DependentUpon :=
      ExtractTagContent(Trimmed, 'DependentUpon');
  End;
  { SubType pour le dernier fichier ajoute }
  If InItemGroup And (ExtractTagContent(Trimmed,
      'SubType') <> '') Then Begin
   If Proj.FileCount > 0 Then
    Proj.Files[Proj.FileCount - 1].SubType :=
      ExtractTagContent(Trimmed, 'SubType');
  End;
  { References dans ItemGroup }
  If InItemGroup And HasTag(Trimmed, 'Reference') Then Begin
   If Proj.RefCount < MAX_PROJECT_REFS Then Begin
    InitProjectRef(Proj.Refs[Proj.RefCount]);
    Proj.Refs[Proj.RefCount].ReferenceName :=
      ExtractAttribute(Trimmed, 'Include');
    Inc(Proj.RefCount);
   End;
  End;
  { HintPath pour la derniere reference ajoutee }
  If InItemGroup And (ExtractTagContent(Trimmed,
      'HintPath') <> '') Then Begin
   If Proj.RefCount > 0 Then
    Proj.Refs[Proj.RefCount - 1].HintPath :=
      ExtractTagContent(Trimmed, 'HintPath');
  End;
  { ProjectReference dans ItemGroup }
  If InItemGroup And HasTag(Trimmed, 'ProjectReference') Then Begin
   If Proj.RefCount < MAX_PROJECT_REFS Then Begin
    InitProjectRef(Proj.Refs[Proj.RefCount]);
    Proj.Refs[Proj.RefCount].ReferenceName :=
      ExtractAttribute(Trimmed, 'Include');
    Inc(Proj.RefCount);
   End;
  End;
  { Project GUID dans ProjectReference }
  If InItemGroup And (ExtractTagContent(Trimmed,
      'Project') <> '') Then Begin
   If Proj.RefCount > 0 Then
    Proj.Refs[Proj.RefCount - 1].ProjectGUID :=
      ExtractTagContent(Trimmed, 'Project');
  End;
 End;
 Close(F);
 { Deduire le nom du projet si non defini }
 If Proj.Info.ProjectName = '' Then
  Proj.Info.ProjectName := Proj.Info.AssemblyName;
End;

{ --- Sauvegarder un fichier projet --- }

Procedure SaveProjectFile(FileName: String;
  Var Proj: TProject);
Var
 F: Text;
 I: Integer;
 Ext: String;
Begin
 Assign(F, FileName);
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, '<?xml version="1.0" encoding="utf-8"?>');
 WriteLn(F, '<Project ToolsVersion="15.0" ' +
   'xmlns="http://schemas.microsoft.com/developer/msbuild/2003">');
 { PropertyGroup globale }
 WriteLn(F, '  <PropertyGroup>');
 If Proj.Info.ProjectGUID <> '' Then
  WriteLn(F, '    <ProjectGuid>' + Proj.Info.ProjectGUID +
    '</ProjectGuid>');
 WriteLn(F, '    <OutputType>' +
   OutputTypeToStr(Proj.Info.OutputType) + '</OutputType>');
 WriteLn(F, '    <RootNamespace>' + Proj.Info.RootNamespace +
   '</RootNamespace>');
 WriteLn(F, '    <AssemblyName>' + Proj.Info.AssemblyName +
   '</AssemblyName>');
 If Proj.Info.TargetFramework <> '' Then
  WriteLn(F, '    <TargetFrameworkVersion>' +
    Proj.Info.TargetFramework + '</TargetFrameworkVersion>');
 WriteLn(F, '  </PropertyGroup>');
 { PropertyGroups de configuration }
 For I := 0 To Proj.CfgCount - 1 Do Begin
  WriteLn(F, '  <PropertyGroup Condition=" ''$(Configuration)' +
    '|$(Platform)'' == ''' + Proj.Configs[I].ConfigName +
    ''' ">');
  If Proj.Configs[I].OutputPath <> '' Then
   WriteLn(F, '    <OutputPath>' + Proj.Configs[I].OutputPath +
     '</OutputPath>');
  If Proj.Configs[I].DefineConst <> '' Then
   WriteLn(F, '    <DefineConstants>' +
     Proj.Configs[I].DefineConst + '</DefineConstants>');
  If Proj.Configs[I].Optimize Then
   WriteLn(F, '    <Optimize>true</Optimize>')
  Else
   WriteLn(F, '    <Optimize>false</Optimize>');
  If Proj.Configs[I].DebugSymbols Then
   WriteLn(F, '    <DebugSymbols>true</DebugSymbols>')
  Else
   WriteLn(F, '    <DebugSymbols>false</DebugSymbols>');
  WriteLn(F, '  </PropertyGroup>');
 End;
 { ItemGroup des references }
 If Proj.RefCount > 0 Then Begin
  WriteLn(F, '  <ItemGroup>');
  For I := 0 To Proj.RefCount - 1 Do Begin
   If Proj.Refs[I].ProjectGUID <> '' Then Begin
    WriteLn(F, '    <ProjectReference Include="' +
      Proj.Refs[I].ReferenceName + '">');
    WriteLn(F, '      <Project>' + Proj.Refs[I].ProjectGUID +
      '</Project>');
    WriteLn(F, '    </ProjectReference>');
   End Else If Proj.Refs[I].HintPath <> '' Then Begin
    WriteLn(F, '    <Reference Include="' +
      Proj.Refs[I].ReferenceName + '">');
    WriteLn(F, '      <HintPath>' + Proj.Refs[I].HintPath +
      '</HintPath>');
    WriteLn(F, '    </Reference>');
   End Else
    WriteLn(F, '    <Reference Include="' +
      Proj.Refs[I].ReferenceName + '" />');
  End;
  WriteLn(F, '  </ItemGroup>');
 End;
 { ItemGroup des fichiers par type de build action }
 If Proj.FileCount > 0 Then Begin
  WriteLn(F, '  <ItemGroup>');
  For I := 0 To Proj.FileCount - 1 Do Begin
   Ext := BuildActionToStr(Proj.Files[I].BuildAction);
   If (Proj.Files[I].DependentUpon <> '') Or
      (Proj.Files[I].SubType <> '') Then Begin
    WriteLn(F, '    <' + Ext + ' Include="' +
      Proj.Files[I].FileName + '">');
    If Proj.Files[I].SubType <> '' Then
     WriteLn(F, '      <SubType>' + Proj.Files[I].SubType +
       '</SubType>');
    If Proj.Files[I].DependentUpon <> '' Then
     WriteLn(F, '      <DependentUpon>' +
       Proj.Files[I].DependentUpon + '</DependentUpon>');
    WriteLn(F, '    </' + Ext + '>');
   End Else
    WriteLn(F, '    <' + Ext + ' Include="' +
      Proj.Files[I].FileName + '" />');
  End;
  WriteLn(F, '  </ItemGroup>');
 End;
 { Import MSBuild }
 Ext := '';
 Case Proj.Info.ProjectType Of
  PT_CSHARP: Ext := 'Microsoft.CSharp.targets';
  PT_VBNET: Ext := 'Microsoft.VisualBasic.targets';
  PT_PASCAL: Ext := 'Microsoft.Pascal.targets';
  PT_UNKNOWN: Ext := 'Microsoft.Common.targets';
 End;
 WriteLn(F, '  <Import Project="$(MSBuildToolsPath)\' +
   Ext + '" />');
 WriteLn(F, '</Project>');
 Close(F);
End;

{ --- Obtenir le nombre de fichiers --- }

Function GetProjectFileCount(Var Proj: TProject): Integer;
Begin
 GetProjectFileCount := Proj.FileCount;
End;

{ --- Obtenir le nombre de references --- }

Function GetProjectRefCount(Var Proj: TProject): Integer;
Begin
 GetProjectRefCount := Proj.RefCount;
End;

{ --- Obtenir un fichier par index --- }

Function GetProjectFileByIndex(Var Proj: TProject;
  Index: Integer): TProjectFile;
Var
 PF: TProjectFile;
Begin
 InitProjectFile(PF);
 If (Index >= 0) And (Index < Proj.FileCount) Then
  PF := Proj.Files[Index];
 GetProjectFileByIndex := PF;
End;

{ --- Obtenir une reference par index --- }

Function GetProjectRefByIndex(Var Proj: TProject;
  Index: Integer): TProjectRef;
Var
 PR: TProjectRef;
Begin
 InitProjectRef(PR);
 If (Index >= 0) And (Index < Proj.RefCount) Then
  PR := Proj.Refs[Index];
 GetProjectRefByIndex := PR;
End;

{ --- Rechercher un fichier dans le projet --- }

Function FindFileInProject(Var Proj: TProject;
  FileName: String): Integer;
Var
 I: Integer;
 LowFN, LowPF: String;
Begin
 FindFileInProject := -1;
 LowFN := LowerCaseStr(FileName);
 For I := 0 To Proj.FileCount - 1 Do Begin
  LowPF := LowerCaseStr(Proj.Files[I].FileName);
  If LowPF = LowFN Then Begin
   FindFileInProject := I;
   Exit;
  End;
 End;
End;

{ --- Rechercher une reference dans le projet --- }

Function FindReferenceInProject(Var Proj: TProject;
  RefName: String): Integer;
Var
 I: Integer;
 LowRN, LowPR: String;
Begin
 FindReferenceInProject := -1;
 LowRN := LowerCaseStr(RefName);
 For I := 0 To Proj.RefCount - 1 Do Begin
  LowPR := LowerCaseStr(Proj.Refs[I].ReferenceName);
  If LowPR = LowRN Then Begin
   FindReferenceInProject := I;
   Exit;
  End;
 End;
End;

{ --- Verifier un index de fichier --- }

Function IsValidFileIndex(Var Proj: TProject;
  Index: Integer): Boolean;
Begin
 IsValidFileIndex := (Index >= 0) And (Index < Proj.FileCount);
End;

{ --- Verifier un index de reference --- }

Function IsValidRefIndex(Var Proj: TProject;
  Index: Integer): Boolean;
Begin
 IsValidRefIndex := (Index >= 0) And (Index < Proj.RefCount);
End;

{ --- Obtenir le type de sortie du projet --- }

Function GetProjectOutputType(Var Proj: TProject): TOutputType;
Begin
 GetProjectOutputType := Proj.Info.OutputType;
End;

{ --- Obtenir le nom du projet --- }

Function GetProjectName(Var Proj: TProject): String;
Begin
 GetProjectName := Proj.Info.ProjectName;
End;

{ --- Obtenir le nom de l assembly --- }

Function GetProjectAssemblyName(Var Proj: TProject): String;
Begin
 GetProjectAssemblyName := Proj.Info.AssemblyName;
End;

{ --- Obtenir l extension de fichier selon le type de projet --- }

Function GetProjectFileExtension(ProjType: TProjectType): String;
Begin
 Case ProjType Of
  PT_CSHARP: GetProjectFileExtension := '.csproj';
  PT_VBNET: GetProjectFileExtension := '.vbproj';
  PT_PASCAL: GetProjectFileExtension := '.dpproj';
  PT_UNKNOWN: GetProjectFileExtension := '.proj';
 End;
End;

{ --- Verifier si le projet est vide --- }

Function IsProjectEmpty(Var Proj: TProject): Boolean;
Begin
 IsProjectEmpty := Proj.FileCount = 0;
End;

{ --- Nombre de configurations de build --- }

Function GetBuildConfigCount(Var Proj: TProject): Integer;
Begin
 GetBuildConfigCount := Proj.CfgCount;
End;


{ ============================================================
  TODO 17 - EXPLORATEUR DE SOLUTION (PANNEAU DROIT) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser un noeud de l explorateur --- }

Procedure InitExplorerNode(Var Node: TExplorerNode);
Begin
 Node.Caption := '';
 Node.Kind := ENK_FILE_OTHER;
 Node.ParentIdx := -1;
 Node.Level := 0;
 Node.Expanded := False;
 Node.Visible := True;
 Node.Selected := False;
 Node.HasChildren := False;
 Node.Tag := 0;
End;

{ --- Initialiser l explorateur de solution --- }

Procedure InitExplorer(Var Exp: TSolutionExplorer);
Var
 I: Integer;
Begin
 Exp.NodeCount := 0;
 Exp.SelectedIdx := -1;
 Exp.ScrollTop := 0;
 Exp.X := GetScreenWidth - EXPLORER_WIDTH;
 Exp.Y := TOOLBTN_HEIGHT + TAB_HEIGHT + 2;
 Exp.Width := EXPLORER_WIDTH;
 Exp.Height := GetScreenHeight - Exp.Y - 20;
 Exp.SplitterX := Exp.X - SPLITTER_WIDTH;
 Exp.Dragging := False;
 Exp.NeedRepaint := True;
 For I := 0 To MAX_EXPLORER_NODES - 1 Do
  InitExplorerNode(Exp.Nodes[I]);
End;

{ --- Vider l explorateur --- }

Procedure ClearExplorer(Var Exp: TSolutionExplorer);
Var
 I: Integer;
Begin
 For I := 0 To Exp.NodeCount - 1 Do
  InitExplorerNode(Exp.Nodes[I]);
 Exp.NodeCount := 0;
 Exp.SelectedIdx := -1;
 Exp.ScrollTop := 0;
 Exp.NeedRepaint := True;
End;

{ --- Ajouter un noeud a l explorateur --- }

Function AddExplorerNode(Var Exp: TSolutionExplorer;
 ACaption: String; Kind: TExplorerNodeKind;
 ParentIdx: Integer): Integer;
Begin
 If Exp.NodeCount >= MAX_EXPLORER_NODES Then Begin
  AddExplorerNode := -1;
  Exit;
 End;
 InitExplorerNode(Exp.Nodes[Exp.NodeCount]);
 Exp.Nodes[Exp.NodeCount].Caption := ACaption;
 Exp.Nodes[Exp.NodeCount].Kind := Kind;
 Exp.Nodes[Exp.NodeCount].ParentIdx := ParentIdx;
 If ParentIdx >= 0 Then
  Exp.Nodes[Exp.NodeCount].Level :=
   Exp.Nodes[ParentIdx].Level + 1
 Else
  Exp.Nodes[Exp.NodeCount].Level := 0;
 Exp.Nodes[Exp.NodeCount].Visible := True;
 If ParentIdx >= 0 Then
  Exp.Nodes[ParentIdx].HasChildren := True;
 AddExplorerNode := Exp.NodeCount;
 Inc(Exp.NodeCount);
 Exp.NeedRepaint := True;
End;

{ --- Supprimer un noeud de l explorateur --- }

Procedure RemoveExplorerNode(Var Exp: TSolutionExplorer;
 Index: Integer);
Var
 I: Integer;
Begin
 If (Index < 0) Or (Index >= Exp.NodeCount) Then Exit;
 For I := Index To Exp.NodeCount - 2 Do
  Exp.Nodes[I] := Exp.Nodes[I + 1];
 Dec(Exp.NodeCount);
 For I := 0 To Exp.NodeCount - 1 Do Begin
  If Exp.Nodes[I].ParentIdx = Index Then
   Exp.Nodes[I].ParentIdx := -1
  Else If Exp.Nodes[I].ParentIdx > Index Then
   Dec(Exp.Nodes[I].ParentIdx);
 End;
 If Exp.SelectedIdx = Index Then
  Exp.SelectedIdx := -1
 Else If Exp.SelectedIdx > Index Then
  Dec(Exp.SelectedIdx);
 Exp.NeedRepaint := True;
End;

{ --- Determiner le type de noeud selon l extension --- }

Function NodeKindFromExtension(FileName: String): TExplorerNodeKind;
Var
 Ext: String;
 I: Integer;
Begin
 Ext := '';
 For I := Length(FileName) DownTo 1 Do Begin
  If FileName[I] = '.' Then Begin
   Ext := LowerCaseStr(Copy(FileName, I, Length(FileName) - I + 1));
   Break;
  End;
 End;
 If Ext = '.cs' Then
  NodeKindFromExtension := ENK_FILE_CS
 Else If Ext = '.vb' Then
  NodeKindFromExtension := ENK_FILE_VB
 Else If (Ext = '.pas') Or (Ext = '.pp') Then
  NodeKindFromExtension := ENK_FILE_PAS
 Else
  NodeKindFromExtension := ENK_FILE_OTHER;
End;

{ --- Rafraichir la visibilite des noeuds --- }

Procedure RefreshExplorer(Var Exp: TSolutionExplorer);
Var
 I, Parent: Integer;
Begin
 For I := 0 To Exp.NodeCount - 1 Do Begin
  Exp.Nodes[I].Visible := True;
  Parent := Exp.Nodes[I].ParentIdx;
  While Parent >= 0 Do Begin
   If Not Exp.Nodes[Parent].Expanded Then Begin
    Exp.Nodes[I].Visible := False;
    Break;
   End;
   Parent := Exp.Nodes[Parent].ParentIdx;
  End;
 End;
 Exp.NeedRepaint := True;
End;

{ --- Construire l arbre depuis la solution --- }

Procedure BuildSolutionTree(Var Exp: TSolutionExplorer;
 Var Sol: TSolution);
Var
 SolIdx, ProjIdx, RefIdx: Integer;
 I: Integer;
 ProjEntry: TProjectEntry;
Begin
 ClearExplorer(Exp);
 SolIdx := AddExplorerNode(Exp, Sol.Info.SolutionName,
  ENK_SOLUTION, -1);
 If SolIdx < 0 Then Exit;
 Exp.Nodes[SolIdx].Expanded := True;
 For I := 0 To Sol.ProjectCount - 1 Do Begin
  ProjEntry := Sol.Projects[I];
  ProjIdx := AddExplorerNode(Exp, ProjEntry.ProjectName,
   ENK_PROJECT, SolIdx);
  If ProjIdx < 0 Then Exit;
  Exp.Nodes[ProjIdx].Expanded := True;
  AddExplorerNode(Exp, 'Properties', ENK_PROPERTIES, ProjIdx);
  RefIdx := AddExplorerNode(Exp, 'References', ENK_REFERENCES,
   ProjIdx);
  If RefIdx >= 0 Then Begin
   Exp.Nodes[RefIdx].HasChildren := True;
   AddExplorerNode(Exp, 'System', ENK_REFERENCE, RefIdx);
   AddExplorerNode(Exp, 'System.Core', ENK_REFERENCE, RefIdx);
   AddExplorerNode(Exp, 'System.Data', ENK_REFERENCE, RefIdx);
  End;
 End;
 If Exp.NodeCount > 0 Then Begin
  Exp.SelectedIdx := 0;
  Exp.Nodes[0].Selected := True;
 End;
 Exp.NeedRepaint := True;
End;

{ --- Deplier un noeud --- }

Procedure ExpandNode(Var Exp: TSolutionExplorer; NodeIdx: Integer);
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then Exit;
 If Not Exp.Nodes[NodeIdx].HasChildren Then Exit;
 Exp.Nodes[NodeIdx].Expanded := True;
 RefreshExplorer(Exp);
End;

{ --- Replier un noeud --- }

Procedure CollapseNode(Var Exp: TSolutionExplorer;
 NodeIdx: Integer);
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then Exit;
 Exp.Nodes[NodeIdx].Expanded := False;
 RefreshExplorer(Exp);
End;

{ --- Basculer l etat deplie/replie --- }

Procedure ToggleNode(Var Exp: TSolutionExplorer;
 NodeIdx: Integer);
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then Exit;
 If Not Exp.Nodes[NodeIdx].HasChildren Then Exit;
 If Exp.Nodes[NodeIdx].Expanded Then
  CollapseNode(Exp, NodeIdx)
 Else
  ExpandNode(Exp, NodeIdx);
End;

{ --- Nombre total de noeuds --- }

Function GetExplorerNodeCount(Var Exp: TSolutionExplorer): Integer;
Begin
 GetExplorerNodeCount := Exp.NodeCount;
End;

{ --- Nombre de noeuds visibles --- }

Function GetVisibleNodeCount(Var Exp: TSolutionExplorer): Integer;
Var
 I, Cnt: Integer;
Begin
 Cnt := 0;
 For I := 0 To Exp.NodeCount - 1 Do
  If Exp.Nodes[I].Visible Then Inc(Cnt);
 GetVisibleNodeCount := Cnt;
End;

{ --- Couleur du noeud selon son type --- }

Function NodeKindColor(Kind: TExplorerNodeKind): Integer;
Begin
 Case Kind Of
  ENK_SOLUTION:    NodeKindColor := CLR_TITLEBAR_ACTIVE;
  ENK_PROJECT:     NodeKindColor := CLR_TITLEBAR_ACTIVE;
  ENK_PROPERTIES:  NodeKindColor := CLR_EDITOR_GUTTER;
  ENK_REFERENCES:  NodeKindColor := CLR_EDITOR_GUTTER;
  ENK_REFERENCE:   NodeKindColor := CLR_LINE_HIGHLIGHT;
  ENK_FOLDER:      NodeKindColor := CLR_LINE_HIGHLIGHT;
  ENK_FILE_CS:     NodeKindColor := CLR_TITLEBAR_ACTIVE;
  ENK_FILE_VB:     NodeKindColor := CLR_TITLEBAR_ACTIVE;
  ENK_FILE_PAS:    NodeKindColor := CLR_LINE_HIGHLIGHT;
  ENK_FILE_OTHER:  NodeKindColor := CLR_MENU_TEXT;
 Else
  NodeKindColor := CLR_MENU_TEXT;
 End;
End;

{ --- Dessiner un noeud de l explorateur --- }

Procedure DrawExplorerNode(Var Exp: TSolutionExplorer;
 NodeIdx: Integer; DrawY: Integer);
Var
 DrawX: Integer;
 TriX, TriY: Integer;
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then Exit;
 DrawX := Exp.X + 4 + Exp.Nodes[NodeIdx].Level * EXPLORER_INDENT;
 { Fond de selection }
 If Exp.Nodes[NodeIdx].Selected Then Begin
  SetFillStyle(SolidFill, CLR_SELECTION);
  Bar(Exp.X, DrawY, Exp.X + Exp.Width - 1,
   DrawY + EXPLORER_NODE_HEIGHT - 1);
 End;
 { Triangle de depliage si le noeud a des enfants }
 If Exp.Nodes[NodeIdx].HasChildren Then Begin
  TriX := DrawX;
  TriY := DrawY + EXPLORER_NODE_HEIGHT Div 2;
  If Exp.Nodes[NodeIdx].Expanded Then Begin
   SetColor(CLR_MENU_TEXT);
   Line(TriX, TriY - 3, TriX + 6, TriY - 3);
   Line(TriX, TriY - 3, TriX + 3, TriY + 3);
   Line(TriX + 6, TriY - 3, TriX + 3, TriY + 3);
  End Else Begin
   SetColor(CLR_MENU_TEXT);
   Line(TriX, TriY - 4, TriX, TriY + 4);
   Line(TriX, TriY - 4, TriX + 6, TriY);
   Line(TriX, TriY + 4, TriX + 6, TriY);
  End;
  DrawX := DrawX + 10;
 End Else
  DrawX := DrawX + 10;
 { Petit carre d icone }
 SetFillStyle(SolidFill,
  NodeKindColor(Exp.Nodes[NodeIdx].Kind));
 Bar(DrawX, DrawY + 2, DrawX + EXPLORER_ICON_SIZE - 4,
  DrawY + EXPLORER_NODE_HEIGHT - 4);
 DrawX := DrawX + EXPLORER_ICON_SIZE;
 { Texte du noeud }
 If Exp.Nodes[NodeIdx].Selected Then
  SetColor(CLR_EDITOR_BG)
 Else
  SetColor(CLR_MENU_TEXT);
 OutTextXY(DrawX, DrawY + 3, Exp.Nodes[NodeIdx].Caption);
End;

{ --- Dessiner l explorateur de solution --- }

Procedure DrawExplorer(Var Exp: TSolutionExplorer);
Var
 I, DrawY, VisCount, VisTot, MaxVis: Integer;
Begin
 { Fond du panneau }
 SetFillStyle(SolidFill, CLR_EXPLORER_BG);
 Bar(Exp.X, Exp.Y, Exp.X + Exp.Width - 1,
  Exp.Y + Exp.Height - 1);
 { Titre }
 SetFillStyle(SolidFill, CLR_TITLEBAR_ACTIVE);
 Bar(Exp.X, Exp.Y, Exp.X + Exp.Width - 1,
  Exp.Y + EXPLORER_NODE_HEIGHT - 1);
 SetColor(CLR_EDITOR_BG);
 OutTextXY(Exp.X + 4, Exp.Y + 3, 'Explorateur de solutions');
 { Splitter }
 SetFillStyle(SolidFill, CLR_BORDER);
 Bar(Exp.SplitterX, Exp.Y,
  Exp.SplitterX + SPLITTER_WIDTH - 1,
  Exp.Y + Exp.Height - 1);
 { Dessiner les noeuds visibles }
 DrawY := Exp.Y + EXPLORER_NODE_HEIGHT + 2;
 VisCount := 0;
 For I := 0 To Exp.NodeCount - 1 Do Begin
  If Not Exp.Nodes[I].Visible Then Continue;
  If VisCount < Exp.ScrollTop Then Begin
   Inc(VisCount);
   Continue;
  End;
  If DrawY + EXPLORER_NODE_HEIGHT > Exp.Y + Exp.Height Then
   Break;
  DrawExplorerNode(Exp, I, DrawY);
  DrawY := DrawY + EXPLORER_NODE_HEIGHT;
  Inc(VisCount);
 End;
 { Barre de defilement si necessaire }
 VisTot := GetVisibleNodeCount(Exp);
 MaxVis := (Exp.Height - EXPLORER_NODE_HEIGHT) Div
  EXPLORER_NODE_HEIGHT;
 If VisTot > MaxVis Then Begin
  SetFillStyle(SolidFill, CLR_SCROLLBAR);
  Bar(Exp.X + Exp.Width - 12, Exp.Y + EXPLORER_NODE_HEIGHT,
   Exp.X + Exp.Width - 1, Exp.Y + Exp.Height - 1);
  SetFillStyle(SolidFill, CLR_BORDER);
  If VisTot > 0 Then
   Bar(Exp.X + Exp.Width - 11,
    Exp.Y + EXPLORER_NODE_HEIGHT + 2 +
    (Exp.ScrollTop * (Exp.Height - EXPLORER_NODE_HEIGHT - 20)
     Div VisTot),
    Exp.X + Exp.Width - 2,
    Exp.Y + EXPLORER_NODE_HEIGHT + 22 +
    (Exp.ScrollTop * (Exp.Height - EXPLORER_NODE_HEIGHT - 20)
     Div VisTot));
 End;
 { Bordure }
 SetColor(CLR_BORDER);
 Rectangle(Exp.X, Exp.Y, Exp.X + Exp.Width - 1,
  Exp.Y + Exp.Height - 1);
 Exp.NeedRepaint := False;
End;

{ --- Trouver le noeud sous la souris --- }

Function ExplorerNodeHitTest(Var Exp: TSolutionExplorer;
 MX, MY: Integer): Integer;
Var
 I, DrawY, VisCount: Integer;
Begin
 ExplorerNodeHitTest := -1;
 If (MX < Exp.X) Or (MX >= Exp.X + Exp.Width) Then Exit;
 If (MY < Exp.Y + EXPLORER_NODE_HEIGHT) Or
    (MY >= Exp.Y + Exp.Height) Then Exit;
 DrawY := Exp.Y + EXPLORER_NODE_HEIGHT + 2;
 VisCount := 0;
 For I := 0 To Exp.NodeCount - 1 Do Begin
  If Not Exp.Nodes[I].Visible Then Continue;
  If VisCount < Exp.ScrollTop Then Begin
   Inc(VisCount);
   Continue;
  End;
  If DrawY + EXPLORER_NODE_HEIGHT > Exp.Y + Exp.Height Then
   Break;
  If (MY >= DrawY) And (MY < DrawY + EXPLORER_NODE_HEIGHT) Then Begin
   ExplorerNodeHitTest := I;
   Exit;
  End;
  DrawY := DrawY + EXPLORER_NODE_HEIGHT;
  Inc(VisCount);
 End;
End;

{ --- Gerer les evenements de l explorateur --- }

Procedure HandleExplorerEvent(Var Exp: TSolutionExplorer;
 Ev: TEvent);
Var
 HitIdx: Integer;
 MaxScroll: Integer;
Begin
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  { Verifier le clic sur le splitter }
  If (Ev.MouseX >= Exp.SplitterX) And
     (Ev.MouseX < Exp.SplitterX + SPLITTER_WIDTH) Then Begin
   Exp.Dragging := True;
   Exit;
  End;
  { Trouver le noeud clique }
  HitIdx := ExplorerNodeHitTest(Exp, Ev.MouseX, Ev.MouseY);
  If HitIdx >= 0 Then Begin
   If (Exp.SelectedIdx >= 0) And
      (Exp.SelectedIdx < Exp.NodeCount) Then
    Exp.Nodes[Exp.SelectedIdx].Selected := False;
   Exp.SelectedIdx := HitIdx;
   Exp.Nodes[HitIdx].Selected := True;
   If Exp.Nodes[HitIdx].HasChildren Then
    ToggleNode(Exp, HitIdx);
   Exp.NeedRepaint := True;
  End;
 End
 Else If Ev.Kind = EV_MOUSE_UP Then Begin
  If Exp.Dragging Then
   Exp.Dragging := False;
 End
 Else If Ev.Kind = EV_MOUSE_MOVE Then Begin
  If Exp.Dragging Then Begin
   If (Ev.MouseX >= GetScreenWidth - EXPLORER_MAX_WIDTH) And
      (Ev.MouseX <= GetScreenWidth - EXPLORER_MIN_WIDTH) Then Begin
    Exp.Width := GetScreenWidth - Ev.MouseX;
    Exp.X := Ev.MouseX;
    Exp.SplitterX := Exp.X - SPLITTER_WIDTH;
    Exp.NeedRepaint := True;
   End;
  End;
 End
 Else If Ev.Kind = EV_KEY_DOWN Then Begin
  Case Ev.KeyCode Of
   72: Begin { Fleche haut }
    If Exp.SelectedIdx > 0 Then Begin
     Exp.Nodes[Exp.SelectedIdx].Selected := False;
     Dec(Exp.SelectedIdx);
     While (Exp.SelectedIdx > 0) And
      (Not Exp.Nodes[Exp.SelectedIdx].Visible) Do
      Dec(Exp.SelectedIdx);
     Exp.Nodes[Exp.SelectedIdx].Selected := True;
     Exp.NeedRepaint := True;
    End;
   End;
   80: Begin { Fleche bas }
    If Exp.SelectedIdx < Exp.NodeCount - 1 Then Begin
     Exp.Nodes[Exp.SelectedIdx].Selected := False;
     Inc(Exp.SelectedIdx);
     While (Exp.SelectedIdx < Exp.NodeCount - 1) And
      (Not Exp.Nodes[Exp.SelectedIdx].Visible) Do
      Inc(Exp.SelectedIdx);
     Exp.Nodes[Exp.SelectedIdx].Selected := True;
     Exp.NeedRepaint := True;
    End;
   End;
   75: Begin { Fleche gauche : replier }
    If (Exp.SelectedIdx >= 0) And
       (Exp.SelectedIdx < Exp.NodeCount) Then Begin
     If Exp.Nodes[Exp.SelectedIdx].Expanded Then
      CollapseNode(Exp, Exp.SelectedIdx)
     Else If Exp.Nodes[Exp.SelectedIdx].ParentIdx >= 0 Then Begin
      Exp.Nodes[Exp.SelectedIdx].Selected := False;
      Exp.SelectedIdx := Exp.Nodes[Exp.SelectedIdx].ParentIdx;
      Exp.Nodes[Exp.SelectedIdx].Selected := True;
      Exp.NeedRepaint := True;
     End;
    End;
   End;
   77: Begin { Fleche droite : deplier }
    If (Exp.SelectedIdx >= 0) And
       (Exp.SelectedIdx < Exp.NodeCount) Then Begin
     If Exp.Nodes[Exp.SelectedIdx].HasChildren And
        (Not Exp.Nodes[Exp.SelectedIdx].Expanded) Then
      ExpandNode(Exp, Exp.SelectedIdx);
    End;
   End;
   13: Begin { Entree : basculer }
    If (Exp.SelectedIdx >= 0) And
       (Exp.SelectedIdx < Exp.NodeCount) Then
     ToggleNode(Exp, Exp.SelectedIdx);
   End;
  End;
 End;
 { Ajuster le defilement }
 MaxScroll := GetVisibleNodeCount(Exp) -
  ((Exp.Height - EXPLORER_NODE_HEIGHT) Div EXPLORER_NODE_HEIGHT);
 If MaxScroll < 0 Then MaxScroll := 0;
 If Exp.ScrollTop > MaxScroll Then Begin
  Exp.ScrollTop := MaxScroll;
  Exp.NeedRepaint := True;
 End;
End;

{ --- Trouver un noeud par son nom --- }

Function FindExplorerNode(Var Exp: TSolutionExplorer;
 ACaption: String): Integer;
Var
 I: Integer;
Begin
 FindExplorerNode := -1;
 For I := 0 To Exp.NodeCount - 1 Do
  If Exp.Nodes[I].Caption = ACaption Then Begin
   FindExplorerNode := I;
   Exit;
  End;
End;

{ --- Verifier si un noeud est deplie --- }

Function IsExplorerNodeExpanded(Var Exp: TSolutionExplorer;
 NodeIdx: Integer): Boolean;
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then
  IsExplorerNodeExpanded := False
 Else
  IsExplorerNodeExpanded := Exp.Nodes[NodeIdx].Expanded;
End;

{ --- Verifier si un noeud est visible --- }

Function IsExplorerNodeVisible(Var Exp: TSolutionExplorer;
 NodeIdx: Integer): Boolean;
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then
  IsExplorerNodeVisible := False
 Else
  IsExplorerNodeVisible := Exp.Nodes[NodeIdx].Visible;
End;

{ --- Obtenir le niveau d un noeud --- }

Function GetExplorerNodeLevel(Var Exp: TSolutionExplorer;
 NodeIdx: Integer): Integer;
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then
  GetExplorerNodeLevel := -1
 Else
  GetExplorerNodeLevel := Exp.Nodes[NodeIdx].Level;
End;

{ --- Obtenir le texte d un noeud --- }

Function GetExplorerNodeCaption(Var Exp: TSolutionExplorer;
 NodeIdx: Integer): String;
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then
  GetExplorerNodeCaption := ''
 Else
  GetExplorerNodeCaption := Exp.Nodes[NodeIdx].Caption;
End;

{ --- Obtenir le type d un noeud --- }

Function GetExplorerNodeKind(Var Exp: TSolutionExplorer;
 NodeIdx: Integer): TExplorerNodeKind;
Begin
 If (NodeIdx < 0) Or (NodeIdx >= Exp.NodeCount) Then
  GetExplorerNodeKind := ENK_FILE_OTHER
 Else
  GetExplorerNodeKind := Exp.Nodes[NodeIdx].Kind;
End;

{ --- Obtenir l index du noeud selectionne --- }

Function GetExplorerSelectedNode(
 Var Exp: TSolutionExplorer): Integer;
Begin
 GetExplorerSelectedNode := Exp.SelectedIdx;
End;

{ --- Definir le noeud selectionne --- }

Procedure SetExplorerSelectedNode(Var Exp: TSolutionExplorer;
 NodeIdx: Integer);
Begin
 If (Exp.SelectedIdx >= 0) And
    (Exp.SelectedIdx < Exp.NodeCount) Then
  Exp.Nodes[Exp.SelectedIdx].Selected := False;
 If (NodeIdx >= 0) And (NodeIdx < Exp.NodeCount) Then Begin
  Exp.SelectedIdx := NodeIdx;
  Exp.Nodes[NodeIdx].Selected := True;
 End Else
  Exp.SelectedIdx := -1;
 Exp.NeedRepaint := True;
End;

{ --- Verifier si l explorateur est vide --- }

Function IsExplorerEmpty(Var Exp: TSolutionExplorer): Boolean;
Begin
 IsExplorerEmpty := Exp.NodeCount = 0;
End;


{ ============================================================
  TODO 18 - PANNEAU DE PROPRIETES [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser une propriete --- }

Procedure InitPropertyItem(Var Item: TPropertyItem);
Begin
 Item.Name := '';
 Item.Value := '';
 Item.Category := '';
 Item.ReadOnly := False;
 Item.Editing := False;
End;

{ --- Initialiser le panneau de proprietes --- }

Procedure InitPropertiesPanel(Var PP: TPropertiesPanel);
Var
 I: Integer;
Begin
 PP.ItemCount := 0;
 PP.SelectedIdx := -1;
 PP.ScrollTop := 0;
 PP.X := GetScreenWidth - EXPLORER_WIDTH;
 PP.Y := GetScreenHeight - PROPS_PANEL_HEIGHT - STATUSBAR_HEIGHT;
 PP.Width := EXPLORER_WIDTH;
 PP.Height := PROPS_PANEL_HEIGHT;
 PP.NameColWidth := PROPS_NAME_WIDTH;
 PP.SplitterY := PP.Y - PROPS_SPLITTER_HEIGHT;
 PP.Dragging := False;
 PP.NeedRepaint := True;
 PP.SourceKind := PK_NONE;
 PP.SourceTitle := '';
 PP.SortMode := PS_ALPHABETICAL;
 PP.EditBuffer := '';
 PP.EditActive := False;
 For I := 0 To MAX_PROPERTIES - 1 Do
  InitPropertyItem(PP.Items[I]);
End;

{ --- Vider le panneau de proprietes --- }

Procedure ClearPropertiesPanel(Var PP: TPropertiesPanel);
Var
 I: Integer;
Begin
 For I := 0 To PP.ItemCount - 1 Do
  InitPropertyItem(PP.Items[I]);
 PP.ItemCount := 0;
 PP.SelectedIdx := -1;
 PP.ScrollTop := 0;
 PP.SourceKind := PK_NONE;
 PP.SourceTitle := '';
 PP.EditActive := False;
 PP.EditBuffer := '';
 PP.NeedRepaint := True;
End;

{ --- Ajouter une propriete au panneau --- }

Function AddProperty(Var PP: TPropertiesPanel;
 AName, AValue, ACategory: String; AReadOnly: Boolean): Boolean;
Begin
 If PP.ItemCount >= MAX_PROPERTIES Then Begin
  AddProperty := False;
  Exit;
 End;
 PP.Items[PP.ItemCount].Name := AName;
 PP.Items[PP.ItemCount].Value := AValue;
 PP.Items[PP.ItemCount].Category := ACategory;
 PP.Items[PP.ItemCount].ReadOnly := AReadOnly;
 PP.Items[PP.ItemCount].Editing := False;
 Inc(PP.ItemCount);
 PP.NeedRepaint := True;
 AddProperty := True;
End;

{ --- Supprimer une propriete du panneau --- }

Function RemoveProperty(Var PP: TPropertiesPanel;
 Idx: Integer): Boolean;
Var
 I: Integer;
Begin
 If (Idx < 0) Or (Idx >= PP.ItemCount) Then Begin
  RemoveProperty := False;
  Exit;
 End;
 For I := Idx To PP.ItemCount - 2 Do
  PP.Items[I] := PP.Items[I + 1];
 Dec(PP.ItemCount);
 InitPropertyItem(PP.Items[PP.ItemCount]);
 If PP.SelectedIdx >= PP.ItemCount Then
  PP.SelectedIdx := PP.ItemCount - 1;
 PP.NeedRepaint := True;
 RemoveProperty := True;
End;

{ --- Definir la source des proprietes (projet) --- }

Procedure SetPropertySourceProject(Var PP: TPropertiesPanel;
 Var Proj: TProject);
Begin
 ClearPropertiesPanel(PP);
 PP.SourceKind := PK_PROJECT;
 PP.SourceTitle := Proj.Info.ProjectName;
 AddProperty(PP, 'Nom de l assembly', Proj.Info.AssemblyName,
  'General', False);
 AddProperty(PP, 'Espace de noms racine', Proj.Info.RootNamespace,
  'General', False);
 Case Proj.Info.OutputType Of
  OT_EXE:     AddProperty(PP, 'Type de sortie', 'Exe',
                'General', False);
  OT_LIBRARY: AddProperty(PP, 'Type de sortie', 'Library',
                'General', False);
  OT_WINEXE:  AddProperty(PP, 'Type de sortie', 'WinExe',
                'General', False);
 End;
 AddProperty(PP, 'Chemin de sortie', Proj.Info.OutputPath,
  'Build', False);
 AddProperty(PP, 'Framework cible', Proj.Info.TargetFramework,
  'General', True);
 AddProperty(PP, 'Constantes', Proj.Info.DefineConstants,
  'Build', False);
 AddProperty(PP, 'GUID du projet', Proj.Info.ProjectGUID,
  'Avance', True);
 PP.NeedRepaint := True;
End;

{ --- Definir la source des proprietes (fichier) --- }

Procedure SetPropertySourceFile(Var PP: TPropertiesPanel;
 Var PF: TProjectFile);
Begin
 ClearPropertiesPanel(PP);
 PP.SourceKind := PK_FILE;
 PP.SourceTitle := PF.FileName;
 AddProperty(PP, 'Nom de fichier', PF.FileName,
  'General', True);
 Case PF.BuildAction Of
  BA_COMPILE:           AddProperty(PP, 'Action de build',
                          'Compile', 'Build', False);
  BA_CONTENT:           AddProperty(PP, 'Action de build',
                          'Content', 'Build', False);
  BA_NONE:              AddProperty(PP, 'Action de build',
                          'None', 'Build', False);
  BA_EMBEDDED_RESOURCE: AddProperty(PP, 'Action de build',
                          'EmbeddedResource', 'Build', False);
 End;
 If PF.DependentUpon <> '' Then
  AddProperty(PP, 'Depend de', PF.DependentUpon,
   'Avance', True);
 If PF.SubType <> '' Then
  AddProperty(PP, 'Sous-type', PF.SubType,
   'Avance', True);
 AddProperty(PP, 'Copier dans sortie', 'Ne pas copier',
  'Build', False);
 PP.NeedRepaint := True;
End;

{ --- Definir la source des proprietes (solution) --- }

Procedure SetPropertySourceSolution(Var PP: TPropertiesPanel;
 Var Sol: TSolution);
Begin
 ClearPropertiesPanel(PP);
 PP.SourceKind := PK_SOLUTION;
 PP.SourceTitle := Sol.Info.SolutionName;
 AddProperty(PP, 'Nom', Sol.Info.SolutionName,
  'General', True);
 AddProperty(PP, 'Chemin', Sol.Info.SolutionPath,
  'General', True);
 AddProperty(PP, 'Nombre de projets', IntToStr(Sol.ProjectCount),
  'General', True);
 AddProperty(PP, 'Configurations', IntToStr(Sol.ConfigCount),
  'General', True);
 PP.NeedRepaint := True;
End;

{ --- Definir la source des proprietes (reference) --- }

Procedure SetPropertySourceReference(Var PP: TPropertiesPanel;
 Var PR: TProjectRef);
Begin
 ClearPropertiesPanel(PP);
 PP.SourceKind := PK_REFERENCE;
 PP.SourceTitle := PR.ReferenceName;
 AddProperty(PP, 'Nom', PR.ReferenceName,
  'General', True);
 If PR.HintPath <> '' Then
  AddProperty(PP, 'Chemin', PR.HintPath,
   'General', True);
 If PR.ProjectGUID <> '' Then
  AddProperty(PP, 'GUID du projet', PR.ProjectGUID,
   'Avance', True);
 PP.NeedRepaint := True;
End;

{ --- Definir la source generique --- }

Procedure SetPropertySource(Var PP: TPropertiesPanel;
 Kind: TPropertyKind; Title: String);
Begin
 ClearPropertiesPanel(PP);
 PP.SourceKind := Kind;
 PP.SourceTitle := Title;
 PP.NeedRepaint := True;
End;

{ --- Trier les proprietes par ordre alphabetique --- }

Procedure SortPropertiesAlpha(Var PP: TPropertiesPanel);
Var
 I, J: Integer;
 Temp: TPropertyItem;
Begin
 For I := 0 To PP.ItemCount - 2 Do
  For J := I + 1 To PP.ItemCount - 1 Do
   If PP.Items[I].Name > PP.Items[J].Name Then Begin
    Temp := PP.Items[I];
    PP.Items[I] := PP.Items[J];
    PP.Items[J] := Temp;
   End;
 PP.NeedRepaint := True;
End;

{ --- Trier les proprietes par categorie --- }

Procedure SortPropertiesByCategory(Var PP: TPropertiesPanel);
Var
 I, J: Integer;
 Temp: TPropertyItem;
Begin
 For I := 0 To PP.ItemCount - 2 Do
  For J := I + 1 To PP.ItemCount - 1 Do
   If (PP.Items[I].Category > PP.Items[J].Category) Or
      ((PP.Items[I].Category = PP.Items[J].Category) And
       (PP.Items[I].Name > PP.Items[J].Name)) Then Begin
    Temp := PP.Items[I];
    PP.Items[I] := PP.Items[J];
    PP.Items[J] := Temp;
   End;
 PP.NeedRepaint := True;
End;

{ --- Changer le mode de tri --- }

Procedure TogglePropertySort(Var PP: TPropertiesPanel);
Begin
 If PP.SortMode = PS_ALPHABETICAL Then Begin
  PP.SortMode := PS_CATEGORIZED;
  SortPropertiesByCategory(PP);
 End Else Begin
  PP.SortMode := PS_ALPHABETICAL;
  SortPropertiesAlpha(PP);
 End;
End;

{ --- Calculer le nombre de lignes visibles --- }

Function GetVisiblePropertyCount(Var PP: TPropertiesPanel): Integer;
Var
 Available: Integer;
Begin
 Available := PP.Height - PROPS_HEADER_HEIGHT;
 If Available < 0 Then
  Available := 0;
 GetVisiblePropertyCount := Available Div PROPS_ROW_HEIGHT;
End;

{ --- Dessiner l en-tete du panneau --- }

Procedure DrawPropertiesHeader(Var PP: TPropertiesPanel);
Begin
 SetColor(CLR_BORDER);
 Rectangle(PP.X, PP.Y, PP.X + PP.Width - 1,
  PP.Y + PROPS_HEADER_HEIGHT - 1);
 SetFillStyle(SolidFill, CLR_TOOLBAR);
 Bar(PP.X + 1, PP.Y + 1, PP.X + PP.Width - 2,
  PP.Y + PROPS_HEADER_HEIGHT - 2);
 SetColor(CLR_MENU_TEXT);
 If PP.SourceTitle <> '' Then
  OutTextXY(PP.X + 4, PP.Y + 4, PP.SourceTitle)
 Else
  OutTextXY(PP.X + 4, PP.Y + 4, 'Proprietes');
End;

{ --- Dessiner une ligne de propriete --- }

Procedure DrawPropertyRow(Var PP: TPropertiesPanel;
 Idx, RowY: Integer);
Var
 NameX, ValX: Integer;
Begin
 NameX := PP.X + 2;
 ValX := PP.X + PP.NameColWidth;
 { Fond de la ligne }
 If Idx = PP.SelectedIdx Then Begin
  SetFillStyle(SolidFill, CLR_SELECTION);
  Bar(PP.X + 1, RowY, PP.X + PP.Width - 2,
   RowY + PROPS_ROW_HEIGHT - 1);
  SetColor(15);
 End Else Begin
  SetFillStyle(SolidFill, CLR_EDITOR_BG);
  Bar(PP.X + 1, RowY, PP.X + PP.Width - 2,
   RowY + PROPS_ROW_HEIGHT - 1);
  SetColor(CLR_MENU_TEXT);
 End;
 { Nom }
 OutTextXY(NameX, RowY + 3, PP.Items[Idx].Name);
 { Separateur vertical }
 SetColor(CLR_BORDER);
 Line(ValX, RowY, ValX, RowY + PROPS_ROW_HEIGHT - 1);
 { Valeur }
 If Idx = PP.SelectedIdx Then
  SetColor(15)
 Else If PP.Items[Idx].ReadOnly Then
  SetColor(8)
 Else
  SetColor(CLR_EDITOR_TEXT);
 If PP.Items[Idx].Editing Then
  OutTextXY(ValX + 3, RowY + 3, PP.EditBuffer)
 Else
  OutTextXY(ValX + 3, RowY + 3, PP.Items[Idx].Value);
 { Ligne horizontale }
 SetColor(CLR_BORDER);
 Line(PP.X, RowY + PROPS_ROW_HEIGHT - 1,
  PP.X + PP.Width - 1, RowY + PROPS_ROW_HEIGHT - 1);
End;

{ --- Dessiner le panneau de proprietes --- }

Procedure DrawPropertiesPanel(Var PP: TPropertiesPanel);
Var
 I, RowY, Visible: Integer;
Begin
 { Bordure du panneau }
 SetColor(CLR_BORDER);
 Rectangle(PP.X, PP.Y, PP.X + PP.Width - 1,
  PP.Y + PP.Height - 1);
 { Fond }
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(PP.X + 1, PP.Y + 1, PP.X + PP.Width - 2,
  PP.Y + PP.Height - 2);
 { En-tete }
 DrawPropertiesHeader(PP);
 { Lignes de proprietes }
 Visible := GetVisiblePropertyCount(PP);
 RowY := PP.Y + PROPS_HEADER_HEIGHT;
 For I := PP.ScrollTop To PP.ItemCount - 1 Do Begin
  If I - PP.ScrollTop >= Visible Then
   Break;
  DrawPropertyRow(PP, I, RowY);
  Inc(RowY, PROPS_ROW_HEIGHT);
 End;
 { Vider l espace restant }
 If RowY < PP.Y + PP.Height - 1 Then Begin
  SetFillStyle(SolidFill, CLR_EDITOR_BG);
  Bar(PP.X + 1, RowY, PP.X + PP.Width - 2,
   PP.Y + PP.Height - 2);
 End;
 PP.NeedRepaint := False;
End;

{ --- Tester si un clic est dans le panneau --- }

Function PropertiesPanelHitTest(Var PP: TPropertiesPanel;
 MX, MY: Integer): Boolean;
Begin
 PropertiesPanelHitTest :=
  (MX >= PP.X) And (MX < PP.X + PP.Width) And
  (MY >= PP.Y) And (MY < PP.Y + PP.Height);
End;

{ --- Tester si un clic est sur le splitter horizontal --- }

Function PropertiesSplitterHitTest(Var PP: TPropertiesPanel;
 MX, MY: Integer): Boolean;
Begin
 PropertiesSplitterHitTest :=
  (MX >= PP.X) And (MX < PP.X + PP.Width) And
  (MY >= PP.SplitterY) And
  (MY < PP.SplitterY + PROPS_SPLITTER_HEIGHT);
End;

{ --- Determiner quelle propriete a ete cliquee --- }

Function PropertyRowHitTest(Var PP: TPropertiesPanel;
 MY: Integer): Integer;
Var
 RelY, Row: Integer;
Begin
 RelY := MY - PP.Y - PROPS_HEADER_HEIGHT;
 If RelY < 0 Then Begin
  PropertyRowHitTest := -1;
  Exit;
 End;
 Row := RelY Div PROPS_ROW_HEIGHT + PP.ScrollTop;
 If Row >= PP.ItemCount Then
  PropertyRowHitTest := -1
 Else
  PropertyRowHitTest := Row;
End;

{ --- Commencer l edition d une propriete --- }

Procedure BeginPropertyEdit(Var PP: TPropertiesPanel;
 Idx: Integer);
Begin
 If (Idx < 0) Or (Idx >= PP.ItemCount) Then Exit;
 If PP.Items[Idx].ReadOnly Then Exit;
 If PP.EditActive And (PP.SelectedIdx >= 0) And
    (PP.SelectedIdx < PP.ItemCount) Then
  PP.Items[PP.SelectedIdx].Editing := False;
 PP.SelectedIdx := Idx;
 PP.Items[Idx].Editing := True;
 PP.EditBuffer := PP.Items[Idx].Value;
 PP.EditActive := True;
 PP.NeedRepaint := True;
End;

{ --- Annuler l edition en cours --- }

Procedure CancelPropertyEdit(Var PP: TPropertiesPanel);
Begin
 If PP.EditActive And (PP.SelectedIdx >= 0) And
    (PP.SelectedIdx < PP.ItemCount) Then
  PP.Items[PP.SelectedIdx].Editing := False;
 PP.EditActive := False;
 PP.EditBuffer := '';
 PP.NeedRepaint := True;
End;

{ --- Confirmer l edition en cours --- }

Procedure CommitPropertyEdit(Var PP: TPropertiesPanel);
Begin
 If PP.EditActive And (PP.SelectedIdx >= 0) And
    (PP.SelectedIdx < PP.ItemCount) Then Begin
  PP.Items[PP.SelectedIdx].Value := PP.EditBuffer;
  PP.Items[PP.SelectedIdx].Editing := False;
 End;
 PP.EditActive := False;
 PP.EditBuffer := '';
 PP.NeedRepaint := True;
End;

{ --- Gerer les evenements du panneau de proprietes --- }

Procedure HandlePropertiesEvent(Var PP: TPropertiesPanel;
 Ev: TEvent);
Var
 Row, NewY, Visible: Integer;
Begin
 Case Ev.Kind Of
  EV_MOUSE_DOWN: Begin
   { Splitter horizontal }
   If PropertiesSplitterHitTest(PP, Ev.MouseX, Ev.MouseY) Then Begin
    PP.Dragging := True;
    Exit;
   End;
   { Clic dans le panneau }
   If PropertiesPanelHitTest(PP, Ev.MouseX, Ev.MouseY) Then Begin
    Row := PropertyRowHitTest(PP, Ev.MouseY);
    If Row >= 0 Then Begin
     If PP.EditActive Then
      CommitPropertyEdit(PP);
     PP.SelectedIdx := Row;
     PP.NeedRepaint := True;
    End;
   End;
  End;
  EV_MOUSE_DBLCLICK: Begin
   If PropertiesPanelHitTest(PP, Ev.MouseX, Ev.MouseY) Then Begin
    Row := PropertyRowHitTest(PP, Ev.MouseY);
    If Row >= 0 Then
     BeginPropertyEdit(PP, Row);
   End;
  End;
  EV_MOUSE_UP: Begin
   PP.Dragging := False;
  End;
  EV_MOUSE_MOVE: Begin
   If PP.Dragging Then Begin
    NewY := Ev.MouseY;
    PP.Height := PP.Y + PP.Height - NewY;
    If PP.Height < PROPS_MIN_HEIGHT Then
     PP.Height := PROPS_MIN_HEIGHT;
    If PP.Height > PROPS_MAX_HEIGHT Then
     PP.Height := PROPS_MAX_HEIGHT;
    PP.Y := NewY;
    PP.SplitterY := PP.Y - PROPS_SPLITTER_HEIGHT;
    PP.NeedRepaint := True;
   End;
  End;
  EV_KEY_CHAR: Begin
   If PP.EditActive Then Begin
    Case Ev.KeyChar Of
     #13: CommitPropertyEdit(PP);
     #27: CancelPropertyEdit(PP);
     #8:  Begin
           If Length(PP.EditBuffer) > 0 Then
            Delete(PP.EditBuffer, Length(PP.EditBuffer), 1);
           PP.NeedRepaint := True;
          End;
    Else
     If (Ev.KeyChar >= ' ') And
        (Length(PP.EditBuffer) < 255) Then Begin
      PP.EditBuffer := PP.EditBuffer + Ev.KeyChar;
      PP.NeedRepaint := True;
     End;
    End;
   End;
  End;
  EV_KEY_DOWN: Begin
   If Not PP.EditActive Then Begin
    Visible := GetVisiblePropertyCount(PP);
    Case Ev.KeyCode Of
     $5000: Begin { Fleche bas }
      If PP.SelectedIdx < PP.ItemCount - 1 Then Begin
       Inc(PP.SelectedIdx);
       If PP.SelectedIdx >= PP.ScrollTop + Visible Then
        Inc(PP.ScrollTop);
       PP.NeedRepaint := True;
      End;
     End;
     $4800: Begin { Fleche haut }
      If PP.SelectedIdx > 0 Then Begin
       Dec(PP.SelectedIdx);
       If PP.SelectedIdx < PP.ScrollTop Then
        PP.ScrollTop := PP.SelectedIdx;
       PP.NeedRepaint := True;
      End;
     End;
     $4700: Begin { Home }
      PP.SelectedIdx := 0;
      PP.ScrollTop := 0;
      PP.NeedRepaint := True;
     End;
     $4F00: Begin { End }
      PP.SelectedIdx := PP.ItemCount - 1;
      If PP.SelectedIdx >= Visible Then
       PP.ScrollTop := PP.SelectedIdx - Visible + 1
      Else
       PP.ScrollTop := 0;
      PP.NeedRepaint := True;
     End;
     $1C0D: Begin { Enter }
      If (PP.SelectedIdx >= 0) And
         (PP.SelectedIdx < PP.ItemCount) Then
       BeginPropertyEdit(PP, PP.SelectedIdx);
     End;
    End;
   End;
  End;
 End;
End;

{ --- Trouver une propriete par nom --- }

Function FindProperty(Var PP: TPropertiesPanel;
 AName: String): Integer;
Var
 I: Integer;
Begin
 FindProperty := -1;
 For I := 0 To PP.ItemCount - 1 Do
  If PP.Items[I].Name = AName Then Begin
   FindProperty := I;
   Exit;
  End;
End;

{ --- Modifier la valeur d une propriete --- }

Function SetPropertyValue(Var PP: TPropertiesPanel;
 AName, AValue: String): Boolean;
Var
 Idx: Integer;
Begin
 Idx := FindProperty(PP, AName);
 If Idx < 0 Then Begin
  SetPropertyValue := False;
  Exit;
 End;
 PP.Items[Idx].Value := AValue;
 PP.NeedRepaint := True;
 SetPropertyValue := True;
End;

{ --- Obtenir la valeur d une propriete --- }

Function GetPropertyValue(Var PP: TPropertiesPanel;
 AName: String): String;
Var
 Idx: Integer;
Begin
 Idx := FindProperty(PP, AName);
 If Idx >= 0 Then
  GetPropertyValue := PP.Items[Idx].Value
 Else
  GetPropertyValue := '';
End;

{ --- Obtenir le nombre de proprietes --- }

Function GetPropertyCount(Var PP: TPropertiesPanel): Integer;
Begin
 GetPropertyCount := PP.ItemCount;
End;

{ --- Obtenir une propriete par index --- }

Function GetPropertyByIndex(Var PP: TPropertiesPanel;
 Idx: Integer; Var Item: TPropertyItem): Boolean;
Begin
 If (Idx >= 0) And (Idx < PP.ItemCount) Then Begin
  Item := PP.Items[Idx];
  GetPropertyByIndex := True;
 End Else
  GetPropertyByIndex := False;
End;

{ --- Verifier si un index est valide --- }

Function IsValidPropertyIndex(Var PP: TPropertiesPanel;
 Idx: Integer): Boolean;
Begin
 IsValidPropertyIndex := (Idx >= 0) And (Idx < PP.ItemCount);
End;

{ --- Obtenir l index selectionne --- }

Function GetSelectedPropertyIndex(
 Var PP: TPropertiesPanel): Integer;
Begin
 GetSelectedPropertyIndex := PP.SelectedIdx;
End;

{ --- Definir l index selectionne --- }

Procedure SetSelectedPropertyIndex(Var PP: TPropertiesPanel;
 Idx: Integer);
Begin
 If PP.EditActive Then
  CommitPropertyEdit(PP);
 If (Idx >= 0) And (Idx < PP.ItemCount) Then
  PP.SelectedIdx := Idx
 Else
  PP.SelectedIdx := -1;
 PP.NeedRepaint := True;
End;

{ --- Obtenir le type de source active --- }

Function GetPropertySourceKind(
 Var PP: TPropertiesPanel): TPropertyKind;
Begin
 GetPropertySourceKind := PP.SourceKind;
End;

{ --- Obtenir le titre de la source --- }

Function GetPropertySourceTitle(
 Var PP: TPropertiesPanel): String;
Begin
 GetPropertySourceTitle := PP.SourceTitle;
End;

{ --- Obtenir le mode de tri --- }

Function GetPropertySortMode(
 Var PP: TPropertiesPanel): TPropertySort;
Begin
 GetPropertySortMode := PP.SortMode;
End;

{ --- Verifier si le panneau est vide --- }

Function IsPropertiesPanelEmpty(
 Var PP: TPropertiesPanel): Boolean;
Begin
 IsPropertiesPanelEmpty := PP.ItemCount = 0;
End;

{ --- Verifier si une edition est en cours --- }

Function IsPropertyEditing(
 Var PP: TPropertiesPanel): Boolean;
Begin
 IsPropertyEditing := PP.EditActive;
End;

{ ============================================================
  TODO 19 - PANNEAU DE SORTIE (OUTPUT) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser une ligne de sortie --- }

Procedure InitOutputLine(Var OL: TOutputLine);
Begin
 OL.Text := '';
 OL.Kind := OLK_INFO;
 OL.FileName := '';
 OL.Line := 0;
 OL.Col := 0;
End;

{ --- Initialiser le panneau de sortie --- }

Procedure InitOutputPanel(Var OP: TOutputPanel);
Var
 I: Integer;
Begin
 For I := 0 To MAX_OUTPUT_LINES - 1 Do
  InitOutputLine(OP.Lines[I]);
 For I := 0 To OUTPUT_TAB_COUNT - 1 Do
  OP.LineCounts[I] := 0;
 OP.ActiveTab := OTK_BUILD;
 OP.ScrollTop := 0;
 OP.SelectedIdx := -1;
 OP.X := EXPLORER_WIDTH + SPLITTER_WIDTH;
 OP.Y := GetScreenHeight - OUTPUT_HEIGHT - STATUSBAR_HEIGHT;
 OP.Width := GetScreenWidth - EXPLORER_WIDTH - SPLITTER_WIDTH;
 OP.Height := OUTPUT_HEIGHT;
 OP.SplitterY := OP.Y - OUTPUT_SPLITTER_HEIGHT;
 OP.Dragging := False;
 OP.Visible := True;
 OP.NeedRepaint := True;
End;

{ --- Vider le panneau de sortie pour un onglet --- }

Procedure ClearOutput(Var OP: TOutputPanel; Tab: Integer);
Var
 I, Base: Integer;
Begin
 If (Tab < 0) Or (Tab >= OUTPUT_TAB_COUNT) Then Exit;
 Base := Tab * (MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT);
 For I := 0 To OP.LineCounts[Tab] - 1 Do
  InitOutputLine(OP.Lines[Base + I]);
 OP.LineCounts[Tab] := 0;
 If Ord(OP.ActiveTab) = Tab Then Begin
  OP.ScrollTop := 0;
  OP.SelectedIdx := -1;
  OP.NeedRepaint := True;
 End;
End;

{ --- Vider tous les onglets --- }

Procedure ClearAllOutput(Var OP: TOutputPanel);
Var
 T: Integer;
Begin
 For T := 0 To OUTPUT_TAB_COUNT - 1 Do
  ClearOutput(OP, T);
End;

{ --- Ajouter une ligne de sortie --- }

Procedure AppendOutput(Var OP: TOutputPanel; AText: String;
 Tab: Integer);
Var
 Base, MaxPerTab, Idx: Integer;
Begin
 If (Tab < 0) Or (Tab >= OUTPUT_TAB_COUNT) Then Exit;
 MaxPerTab := MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT;
 If OP.LineCounts[Tab] >= MaxPerTab Then Exit;
 Base := Tab * MaxPerTab;
 Idx := Base + OP.LineCounts[Tab];
 OP.Lines[Idx].Text := AText;
 OP.Lines[Idx].Kind := OLK_INFO;
 OP.Lines[Idx].FileName := '';
 OP.Lines[Idx].Line := 0;
 OP.Lines[Idx].Col := 0;
 Inc(OP.LineCounts[Tab]);
 If Ord(OP.ActiveTab) = Tab Then
  OP.NeedRepaint := True;
End;

{ --- Ajouter une ligne avec type de message --- }

Procedure AppendOutputEx(Var OP: TOutputPanel; AText: String;
 Tab: Integer; Kind: TOutputLineKind;
 AFile: String; ALine, ACol: Integer);
Var
 Base, MaxPerTab, Idx: Integer;
Begin
 If (Tab < 0) Or (Tab >= OUTPUT_TAB_COUNT) Then Exit;
 MaxPerTab := MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT;
 If OP.LineCounts[Tab] >= MaxPerTab Then Exit;
 Base := Tab * MaxPerTab;
 Idx := Base + OP.LineCounts[Tab];
 OP.Lines[Idx].Text := AText;
 OP.Lines[Idx].Kind := Kind;
 OP.Lines[Idx].FileName := AFile;
 OP.Lines[Idx].Line := ALine;
 OP.Lines[Idx].Col := ACol;
 Inc(OP.LineCounts[Tab]);
 If Ord(OP.ActiveTab) = Tab Then
  OP.NeedRepaint := True;
End;

{ --- Obtenir le nombre de lignes de l onglet actif --- }

Function GetActiveLineCount(Var OP: TOutputPanel): Integer;
Begin
 GetActiveLineCount := OP.LineCounts[Ord(OP.ActiveTab)];
End;

{ --- Obtenir la base de l onglet actif --- }

Function GetActiveBase(Var OP: TOutputPanel): Integer;
Begin
 GetActiveBase := Ord(OP.ActiveTab) *
  (MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT);
End;

{ --- Obtenir le nombre de lignes visibles --- }

Function GetVisibleOutputLines(Var OP: TOutputPanel): Integer;
Begin
 GetVisibleOutputLines :=
  (OP.Height - OUTPUT_TAB_HEIGHT) Div OUTPUT_LINE_HEIGHT;
End;

{ --- Couleur d une ligne selon son type --- }

Function OutputLineColor(Kind: TOutputLineKind): Integer;
Begin
 Case Kind Of
  OLK_ERROR:   OutputLineColor := 4;   { rouge                  }
  OLK_WARNING: OutputLineColor := 6;   { jaune/marron           }
  OLK_SUCCESS: OutputLineColor := 2;   { vert                   }
 Else
  OutputLineColor := CLR_EDITOR_TEXT;   { noir (info)            }
 End;
End;

{ --- Nom d un onglet --- }

Function OutputTabName(Tab: TOutputTabKind): String;
Begin
 Case Tab Of
  OTK_BUILD:  OutputTabName := 'Sortie de build';
  OTK_DEBUG:  OutputTabName := 'Sortie de debogage';
  OTK_SEARCH: OutputTabName := 'Resultats de recherche';
 Else
  OutputTabName := '';
 End;
End;

{ --- Dessiner les onglets du panneau --- }

Procedure DrawOutputTabs(Var OP: TOutputPanel);
Var
 TX, TW, I: Integer;
 Tab: TOutputTabKind;
 TabName: String;
Begin
 TX := OP.X;
 For I := 0 To OUTPUT_TAB_COUNT - 1 Do Begin
  Tab := TOutputTabKind(I);
  TabName := OutputTabName(Tab);
  TW := Length(TabName) * 8 + 16;
  { Fond de l onglet }
  If Tab = OP.ActiveTab Then Begin
   SetFillStyle(SolidFill, CLR_EDITOR_BG);
   Bar(TX, OP.Y, TX + TW - 1, OP.Y + OUTPUT_TAB_HEIGHT - 1);
   SetColor(CLR_MENU_TEXT);
  End Else Begin
   SetFillStyle(SolidFill, CLR_TOOLBAR);
   Bar(TX, OP.Y, TX + TW - 1, OP.Y + OUTPUT_TAB_HEIGHT - 1);
   SetColor(8);
  End;
  { Bordure de l onglet }
  SetColor(CLR_BORDER);
  Rectangle(TX, OP.Y, TX + TW - 1,
   OP.Y + OUTPUT_TAB_HEIGHT - 1);
  { Texte de l onglet }
  If Tab = OP.ActiveTab Then
   SetColor(CLR_MENU_TEXT)
  Else
   SetColor(8);
  OutTextXY(TX + 8, OP.Y + 4, TabName);
  Inc(TX, TW);
 End;
 { Remplir l espace apres les onglets }
 If TX < OP.X + OP.Width Then Begin
  SetFillStyle(SolidFill, CLR_TOOLBAR);
  Bar(TX, OP.Y, OP.X + OP.Width - 1,
   OP.Y + OUTPUT_TAB_HEIGHT - 1);
  SetColor(CLR_BORDER);
  Line(TX, OP.Y + OUTPUT_TAB_HEIGHT - 1,
   OP.X + OP.Width - 1, OP.Y + OUTPUT_TAB_HEIGHT - 1);
 End;
End;

{ --- Dessiner une ligne du panneau de sortie --- }

Procedure DrawOutputLine(Var OP: TOutputPanel;
 Idx, RowY: Integer);
Var
 Base, AbsIdx: Integer;
Begin
 Base := GetActiveBase(OP);
 AbsIdx := Base + Idx;
 { Fond de la ligne }
 If Idx = OP.SelectedIdx Then Begin
  SetFillStyle(SolidFill, CLR_SELECTION);
  Bar(OP.X + 1, RowY, OP.X + OP.Width - 2,
   RowY + OUTPUT_LINE_HEIGHT - 1);
  SetColor(15);
 End Else Begin
  SetFillStyle(SolidFill, CLR_OUTPUT_BG);
  Bar(OP.X + 1, RowY, OP.X + OP.Width - 2,
   RowY + OUTPUT_LINE_HEIGHT - 1);
  SetColor(OutputLineColor(OP.Lines[AbsIdx].Kind));
 End;
 { Texte }
 OutTextXY(OP.X + 4, RowY + 2, OP.Lines[AbsIdx].Text);
End;

{ --- Dessiner le panneau de sortie --- }

Procedure DrawOutputPanel(Var OP: TOutputPanel);
Var
 I, RowY, Visible, LineCount: Integer;
Begin
 If Not OP.Visible Then Exit;
 { Bordure du panneau }
 SetColor(CLR_BORDER);
 Rectangle(OP.X, OP.Y, OP.X + OP.Width - 1,
  OP.Y + OP.Height - 1);
 { Fond }
 SetFillStyle(SolidFill, CLR_OUTPUT_BG);
 Bar(OP.X + 1, OP.Y + 1, OP.X + OP.Width - 2,
  OP.Y + OP.Height - 2);
 { Onglets }
 DrawOutputTabs(OP);
 { Lignes de sortie }
 Visible := GetVisibleOutputLines(OP);
 LineCount := GetActiveLineCount(OP);
 RowY := OP.Y + OUTPUT_TAB_HEIGHT;
 For I := OP.ScrollTop To LineCount - 1 Do Begin
  If I - OP.ScrollTop >= Visible Then
   Break;
  DrawOutputLine(OP, I, RowY);
  Inc(RowY, OUTPUT_LINE_HEIGHT);
 End;
 { Vider l espace restant }
 If RowY < OP.Y + OP.Height - 1 Then Begin
  SetFillStyle(SolidFill, CLR_OUTPUT_BG);
  Bar(OP.X + 1, RowY, OP.X + OP.Width - 2,
   OP.Y + OP.Height - 2);
 End;
 OP.NeedRepaint := False;
End;

{ --- Tester si un clic est dans le panneau --- }

Function OutputPanelHitTest(Var OP: TOutputPanel;
 MX, MY: Integer): Boolean;
Begin
 OutputPanelHitTest := OP.Visible And
  (MX >= OP.X) And (MX < OP.X + OP.Width) And
  (MY >= OP.Y) And (MY < OP.Y + OP.Height);
End;

{ --- Tester si un clic est sur le splitter --- }

Function OutputSplitterHitTest(Var OP: TOutputPanel;
 MX, MY: Integer): Boolean;
Begin
 OutputSplitterHitTest := OP.Visible And
  (MX >= OP.X) And (MX < OP.X + OP.Width) And
  (MY >= OP.SplitterY) And
  (MY < OP.SplitterY + OUTPUT_SPLITTER_HEIGHT);
End;

{ --- Tester quel onglet a ete clique --- }

Function OutputTabHitTest(Var OP: TOutputPanel;
 MX, MY: Integer): Integer;
Var
 TX, TW, I: Integer;
 Tab: TOutputTabKind;
Begin
 OutputTabHitTest := -1;
 If (MY < OP.Y) Or (MY >= OP.Y + OUTPUT_TAB_HEIGHT) Then Exit;
 TX := OP.X;
 For I := 0 To OUTPUT_TAB_COUNT - 1 Do Begin
  Tab := TOutputTabKind(I);
  TW := Length(OutputTabName(Tab)) * 8 + 16;
  If (MX >= TX) And (MX < TX + TW) Then Begin
   OutputTabHitTest := I;
   Exit;
  End;
  Inc(TX, TW);
 End;
End;

{ --- Tester quelle ligne a ete cliquee --- }

Function OutputLineHitTest(Var OP: TOutputPanel;
 MY: Integer): Integer;
Var
 ContentY, Row, LineCount: Integer;
Begin
 OutputLineHitTest := -1;
 ContentY := OP.Y + OUTPUT_TAB_HEIGHT;
 If MY < ContentY Then Exit;
 Row := (MY - ContentY) Div OUTPUT_LINE_HEIGHT + OP.ScrollTop;
 LineCount := GetActiveLineCount(OP);
 If (Row >= 0) And (Row < LineCount) Then
  OutputLineHitTest := Row;
End;

{ --- Changer l onglet actif --- }

Procedure SetActiveOutputTab(Var OP: TOutputPanel;
 Tab: TOutputTabKind);
Begin
 If Tab <> OP.ActiveTab Then Begin
  OP.ActiveTab := Tab;
  OP.ScrollTop := 0;
  OP.SelectedIdx := -1;
  OP.NeedRepaint := True;
 End;
End;

{ --- Masquer ou afficher le panneau --- }

Procedure ToggleOutputPanel(Var OP: TOutputPanel);
Begin
 OP.Visible := Not OP.Visible;
 OP.NeedRepaint := True;
End;

{ --- Gerer les evenements du panneau de sortie --- }

Procedure HandleOutputEvent(Var OP: TOutputPanel;
 Ev: TEvent);
Var
 TabIdx, Row, NewY, Visible, LineCount: Integer;
Begin
 If Not OP.Visible Then Exit;
 Case Ev.Kind Of
  EV_MOUSE_DOWN: Begin
   { Splitter horizontal }
   If OutputSplitterHitTest(OP, Ev.MouseX, Ev.MouseY) Then Begin
    OP.Dragging := True;
    Exit;
   End;
   { Clic sur un onglet }
   TabIdx := OutputTabHitTest(OP, Ev.MouseX, Ev.MouseY);
   If TabIdx >= 0 Then Begin
    SetActiveOutputTab(OP, TOutputTabKind(TabIdx));
    Exit;
   End;
   { Clic sur une ligne }
   If OutputPanelHitTest(OP, Ev.MouseX, Ev.MouseY) Then Begin
    Row := OutputLineHitTest(OP, Ev.MouseY);
    If Row >= 0 Then Begin
     OP.SelectedIdx := Row;
     OP.NeedRepaint := True;
    End;
   End;
  End;
  EV_MOUSE_DBLCLICK: Begin
   If OutputPanelHitTest(OP, Ev.MouseX, Ev.MouseY) Then Begin
    { Double-clic sur barre d onglets : masquer }
    If Ev.MouseY < OP.Y + OUTPUT_TAB_HEIGHT Then Begin
     ToggleOutputPanel(OP);
     Exit;
    End;
    { Double-clic sur une ligne : naviguer vers le source }
    Row := OutputLineHitTest(OP, Ev.MouseY);
    If Row >= 0 Then Begin
     OP.SelectedIdx := Row;
     OP.NeedRepaint := True;
     { La navigation vers le source serait traitee par
       l appelant en lisant OP.Lines[Base+Row].FileName/Line/Col }
    End;
   End;
  End;
  EV_MOUSE_UP: Begin
   OP.Dragging := False;
  End;
  EV_MOUSE_MOVE: Begin
   If OP.Dragging Then Begin
    NewY := Ev.MouseY;
    OP.Height := OP.Y + OP.Height - NewY;
    If OP.Height < OUTPUT_MIN_HEIGHT Then
     OP.Height := OUTPUT_MIN_HEIGHT;
    If OP.Height > OUTPUT_MAX_HEIGHT Then
     OP.Height := OUTPUT_MAX_HEIGHT;
    OP.Y := NewY;
    OP.SplitterY := OP.Y - OUTPUT_SPLITTER_HEIGHT;
    OP.NeedRepaint := True;
   End;
  End;
  EV_KEY_DOWN: Begin
   Visible := GetVisibleOutputLines(OP);
   LineCount := GetActiveLineCount(OP);
   Case Ev.KeyCode Of
    $5000: Begin { Fleche bas }
     If OP.SelectedIdx < LineCount - 1 Then Begin
      Inc(OP.SelectedIdx);
      If OP.SelectedIdx >= OP.ScrollTop + Visible Then
       Inc(OP.ScrollTop);
      OP.NeedRepaint := True;
     End;
    End;
    $4800: Begin { Fleche haut }
     If OP.SelectedIdx > 0 Then Begin
      Dec(OP.SelectedIdx);
      If OP.SelectedIdx < OP.ScrollTop Then
       OP.ScrollTop := OP.SelectedIdx;
      OP.NeedRepaint := True;
     End;
    End;
    $4700: Begin { Home }
     OP.SelectedIdx := 0;
     OP.ScrollTop := 0;
     OP.NeedRepaint := True;
    End;
    $4F00: Begin { End }
     OP.SelectedIdx := LineCount - 1;
     If OP.SelectedIdx >= Visible Then
      OP.ScrollTop := OP.SelectedIdx - Visible + 1
     Else
      OP.ScrollTop := 0;
     OP.NeedRepaint := True;
    End;
    $4900: Begin { Page haut }
     Dec(OP.ScrollTop, Visible);
     If OP.ScrollTop < 0 Then
      OP.ScrollTop := 0;
     Dec(OP.SelectedIdx, Visible);
     If OP.SelectedIdx < 0 Then
      OP.SelectedIdx := 0;
     OP.NeedRepaint := True;
    End;
    $5100: Begin { Page bas }
     Inc(OP.ScrollTop, Visible);
     If OP.ScrollTop > LineCount - Visible Then Begin
      OP.ScrollTop := LineCount - Visible;
      If OP.ScrollTop < 0 Then
       OP.ScrollTop := 0;
     End;
     Inc(OP.SelectedIdx, Visible);
     If OP.SelectedIdx >= LineCount Then
      OP.SelectedIdx := LineCount - 1;
     OP.NeedRepaint := True;
    End;
   End;
  End;
 End;
End;

{ --- Obtenir le nombre de lignes d un onglet --- }

Function GetOutputLineCount(Var OP: TOutputPanel;
 Tab: Integer): Integer;
Begin
 If (Tab >= 0) And (Tab < OUTPUT_TAB_COUNT) Then
  GetOutputLineCount := OP.LineCounts[Tab]
 Else
  GetOutputLineCount := 0;
End;

{ --- Obtenir une ligne de sortie par index --- }

Function GetOutputLine(Var OP: TOutputPanel;
 Tab, Idx: Integer; Var OL: TOutputLine): Boolean;
Var
 Base, MaxPerTab: Integer;
Begin
 MaxPerTab := MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT;
 If (Tab < 0) Or (Tab >= OUTPUT_TAB_COUNT) Or
    (Idx < 0) Or (Idx >= OP.LineCounts[Tab]) Then Begin
  GetOutputLine := False;
  Exit;
 End;
 Base := Tab * MaxPerTab;
 OL := OP.Lines[Base + Idx];
 GetOutputLine := True;
End;

{ --- Obtenir l onglet actif --- }

Function GetActiveOutputTab(Var OP: TOutputPanel): TOutputTabKind;
Begin
 GetActiveOutputTab := OP.ActiveTab;
End;

{ --- Obtenir l index selectionne --- }

Function GetOutputSelectedIndex(Var OP: TOutputPanel): Integer;
Begin
 GetOutputSelectedIndex := OP.SelectedIdx;
End;

{ --- Definir l index selectionne --- }

Procedure SetOutputSelectedIndex(Var OP: TOutputPanel;
 Idx: Integer);
Var
 LineCount: Integer;
Begin
 LineCount := GetActiveLineCount(OP);
 If (Idx >= 0) And (Idx < LineCount) Then
  OP.SelectedIdx := Idx
 Else
  OP.SelectedIdx := -1;
 OP.NeedRepaint := True;
End;

{ --- Verifier si le panneau est visible --- }

Function IsOutputPanelVisible(Var OP: TOutputPanel): Boolean;
Begin
 IsOutputPanelVisible := OP.Visible;
End;

{ --- Afficher le panneau --- }

Procedure ShowOutputPanel(Var OP: TOutputPanel);
Begin
 OP.Visible := True;
 OP.NeedRepaint := True;
End;

{ --- Masquer le panneau --- }

Procedure HideOutputPanel(Var OP: TOutputPanel);
Begin
 OP.Visible := False;
 OP.NeedRepaint := True;
End;

{ --- Verifier si un onglet est vide --- }

Function IsOutputTabEmpty(Var OP: TOutputPanel;
 Tab: Integer): Boolean;
Begin
 If (Tab >= 0) And (Tab < OUTPUT_TAB_COUNT) Then
  IsOutputTabEmpty := OP.LineCounts[Tab] = 0
 Else
  IsOutputTabEmpty := True;
End;

{ --- Verifier si tout est vide --- }

Function IsOutputPanelEmpty(Var OP: TOutputPanel): Boolean;
Var
 I: Integer;
Begin
 IsOutputPanelEmpty := True;
 For I := 0 To OUTPUT_TAB_COUNT - 1 Do
  If OP.LineCounts[I] > 0 Then Begin
   IsOutputPanelEmpty := False;
   Exit;
  End;
End;

{ --- Obtenir le fichier source de la ligne selectionnee --- }

Function GetSelectedOutputFile(Var OP: TOutputPanel): String;
Var
 Base: Integer;
Begin
 If (OP.SelectedIdx >= 0) And
    (OP.SelectedIdx < GetActiveLineCount(OP)) Then Begin
  Base := GetActiveBase(OP);
  GetSelectedOutputFile := OP.Lines[Base + OP.SelectedIdx].FileName;
 End Else
  GetSelectedOutputFile := '';
End;

{ --- Obtenir la ligne source de la ligne selectionnee --- }

Function GetSelectedOutputLine(Var OP: TOutputPanel): Integer;
Var
 Base: Integer;
Begin
 If (OP.SelectedIdx >= 0) And
    (OP.SelectedIdx < GetActiveLineCount(OP)) Then Begin
  Base := GetActiveBase(OP);
  GetSelectedOutputLine := OP.Lines[Base + OP.SelectedIdx].Line;
 End Else
  GetSelectedOutputLine := 0;
End;

{ --- Obtenir la colonne source de la ligne selectionnee --- }

Function GetSelectedOutputCol(Var OP: TOutputPanel): Integer;
Var
 Base: Integer;
Begin
 If (OP.SelectedIdx >= 0) And
    (OP.SelectedIdx < GetActiveLineCount(OP)) Then Begin
  Base := GetActiveBase(OP);
  GetSelectedOutputCol := OP.Lines[Base + OP.SelectedIdx].Col;
 End Else
  GetSelectedOutputCol := 0;
End;

{ --- Nom du type de ligne --- }

Function OutputLineKindName(Kind: TOutputLineKind): String;
Begin
 Case Kind Of
  OLK_INFO:    OutputLineKindName := 'Information';
  OLK_ERROR:   OutputLineKindName := 'Erreur';
  OLK_WARNING: OutputLineKindName := 'Avertissement';
  OLK_SUCCESS: OutputLineKindName := 'Succes';
 Else
  OutputLineKindName := '';
 End;
End;

{ --- Compter les erreurs dans un onglet --- }

Function CountOutputErrors(Var OP: TOutputPanel;
 Tab: Integer): Integer;
Var
 I, Base, MaxPerTab, Count: Integer;
Begin
 Count := 0;
 If (Tab < 0) Or (Tab >= OUTPUT_TAB_COUNT) Then Begin
  CountOutputErrors := 0;
  Exit;
 End;
 MaxPerTab := MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT;
 Base := Tab * MaxPerTab;
 For I := 0 To OP.LineCounts[Tab] - 1 Do
  If OP.Lines[Base + I].Kind = OLK_ERROR Then
   Inc(Count);
 CountOutputErrors := Count;
End;

{ --- Compter les avertissements dans un onglet --- }

Function CountOutputWarnings(Var OP: TOutputPanel;
 Tab: Integer): Integer;
Var
 I, Base, MaxPerTab, Count: Integer;
Begin
 Count := 0;
 If (Tab < 0) Or (Tab >= OUTPUT_TAB_COUNT) Then Begin
  CountOutputWarnings := 0;
  Exit;
 End;
 MaxPerTab := MAX_OUTPUT_LINES Div OUTPUT_TAB_COUNT;
 Base := Tab * MaxPerTab;
 For I := 0 To OP.LineCounts[Tab] - 1 Do
  If OP.Lines[Base + I].Kind = OLK_WARNING Then
   Inc(Count);
 CountOutputWarnings := Count;
End;

{ ============================================================
  TODO 20 - PANNEAU LISTE D ERREURS (ERROR LIST) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser une entree d erreur --- }

Procedure InitErrorEntry(Var E: TErrorEntry);
Begin
 E.Severity := ES_INFO;
 E.Code := '';
 E.Description := '';
 E.FileName := '';
 E.Line := 0;
 E.Col := 0;
 E.Project := '';
End;

{ --- Initialiser le panneau de liste d erreurs --- }

Procedure InitErrorList(Var EL: TErrorListPanel);
Var
 I: Integer;
 ScrW, ScrH: Integer;
Begin
 EL.Count := 0;
 EL.SelectedIdx := -1;
 EL.ScrollTop := 0;
 EL.SortColumn := ESC_SEVERITY;
 EL.SortAscending := True;
 EL.ShowErrors := True;
 EL.ShowWarnings := True;
 EL.ShowInfos := True;
 ScrW := GetScreenWidth;
 ScrH := GetScreenHeight;
 EL.X := 0;
 EL.Y := ScrH - OUTPUT_HEIGHT;
 EL.Width := ScrW;
 EL.Height := OUTPUT_HEIGHT;
 EL.SplitterY := EL.Y;
 EL.Dragging := False;
 EL.Visible := False;
 EL.NeedRepaint := True;
 For I := 0 To MAX_ERROR_ENTRIES - 1 Do
  InitErrorEntry(EL.Entries[I]);
End;

{ --- Effacer toutes les erreurs --- }

Procedure ClearErrors(Var EL: TErrorListPanel);
Var
 I: Integer;
Begin
 For I := 0 To EL.Count - 1 Do
  InitErrorEntry(EL.Entries[I]);
 EL.Count := 0;
 EL.SelectedIdx := -1;
 EL.ScrollTop := 0;
 EL.NeedRepaint := True;
End;

{ --- Ajouter une erreur --- }

Procedure AddError(Var EL: TErrorListPanel; Entry: TErrorEntry);
Begin
 If EL.Count >= MAX_ERROR_ENTRIES Then Exit;
 EL.Entries[EL.Count] := Entry;
 Inc(EL.Count);
 EL.NeedRepaint := True;
End;

{ --- Supprimer une erreur par index --- }

Procedure RemoveError(Var EL: TErrorListPanel; Idx: Integer);
Var
 I: Integer;
Begin
 If (Idx < 0) Or (Idx >= EL.Count) Then Exit;
 For I := Idx To EL.Count - 2 Do
  EL.Entries[I] := EL.Entries[I + 1];
 Dec(EL.Count);
 InitErrorEntry(EL.Entries[EL.Count]);
 If EL.SelectedIdx >= EL.Count Then
  EL.SelectedIdx := EL.Count - 1;
 EL.NeedRepaint := True;
End;

{ --- Compter les erreurs --- }

Function CountErrors(Var EL: TErrorListPanel): Integer;
Var
 I, C: Integer;
Begin
 C := 0;
 For I := 0 To EL.Count - 1 Do
  If EL.Entries[I].Severity = ES_ERROR Then Inc(C);
 CountErrors := C;
End;

{ --- Compter les avertissements --- }

Function CountWarnings(Var EL: TErrorListPanel): Integer;
Var
 I, C: Integer;
Begin
 C := 0;
 For I := 0 To EL.Count - 1 Do
  If EL.Entries[I].Severity = ES_WARNING Then Inc(C);
 CountWarnings := C;
End;

{ --- Compter les messages d information --- }

Function CountInfos(Var EL: TErrorListPanel): Integer;
Var
 I, C: Integer;
Begin
 C := 0;
 For I := 0 To EL.Count - 1 Do
  If EL.Entries[I].Severity = ES_INFO Then Inc(C);
 CountInfos := C;
End;

{ --- Severite vers chaine --- }

Function SeverityToStr(Sev: TErrorSeverity): String;
Begin
 Case Sev Of
  ES_ERROR:   SeverityToStr := 'Erreur';
  ES_WARNING: SeverityToStr := 'Avertissement';
  ES_INFO:    SeverityToStr := 'Message';
 Else
  SeverityToStr := '';
 End;
End;

{ --- Couleur de la severite --- }

Function SeverityColor(Sev: TErrorSeverity): Integer;
Begin
 Case Sev Of
  ES_ERROR:   SeverityColor := 4;   { rouge                 }
  ES_WARNING: SeverityColor := 6;   { jaune/orange          }
  ES_INFO:    SeverityColor := 15;  { blanc                 }
 Else
  SeverityColor := 7;
 End;
End;

{ --- Nom de colonne de tri --- }

Function ErrorSortColumnName(Col: TErrorSortColumn): String;
Begin
 Case Col Of
  ESC_SEVERITY:    ErrorSortColumnName := '!';
  ESC_CODE:        ErrorSortColumnName := 'Code';
  ESC_DESCRIPTION: ErrorSortColumnName := 'Description';
  ESC_FILE:        ErrorSortColumnName := 'Fichier';
  ESC_LINE:        ErrorSortColumnName := 'Ligne';
  ESC_PROJECT:     ErrorSortColumnName := 'Projet';
 Else
  ErrorSortColumnName := '';
 End;
End;

{ --- Trier les erreurs par colonne --- }

Procedure SortErrors(Var EL: TErrorListPanel; Col: TErrorSortColumn);
Var
 I, J: Integer;
 Tmp: TErrorEntry;
 Swap: Boolean;
Begin
 If Col = EL.SortColumn Then
  EL.SortAscending := Not EL.SortAscending
 Else Begin
  EL.SortColumn := Col;
  EL.SortAscending := True;
 End;
 { Tri a bulles }
 For I := 0 To EL.Count - 2 Do
  For J := 0 To EL.Count - 2 - I Do Begin
   Swap := False;
   Case Col Of
    ESC_SEVERITY:
     If EL.SortAscending Then
      Swap := Ord(EL.Entries[J].Severity) > Ord(EL.Entries[J+1].Severity)
     Else
      Swap := Ord(EL.Entries[J].Severity) < Ord(EL.Entries[J+1].Severity);
    ESC_CODE:
     If EL.SortAscending Then
      Swap := EL.Entries[J].Code > EL.Entries[J+1].Code
     Else
      Swap := EL.Entries[J].Code < EL.Entries[J+1].Code;
    ESC_DESCRIPTION:
     If EL.SortAscending Then
      Swap := EL.Entries[J].Description > EL.Entries[J+1].Description
     Else
      Swap := EL.Entries[J].Description < EL.Entries[J+1].Description;
    ESC_FILE:
     If EL.SortAscending Then
      Swap := EL.Entries[J].FileName > EL.Entries[J+1].FileName
     Else
      Swap := EL.Entries[J].FileName < EL.Entries[J+1].FileName;
    ESC_LINE:
     If EL.SortAscending Then
      Swap := EL.Entries[J].Line > EL.Entries[J+1].Line
     Else
      Swap := EL.Entries[J].Line < EL.Entries[J+1].Line;
    ESC_PROJECT:
     If EL.SortAscending Then
      Swap := EL.Entries[J].Project > EL.Entries[J+1].Project
     Else
      Swap := EL.Entries[J].Project < EL.Entries[J+1].Project;
   End;
   If Swap Then Begin
    Tmp := EL.Entries[J];
    EL.Entries[J] := EL.Entries[J+1];
    EL.Entries[J+1] := Tmp;
   End;
  End;
 EL.NeedRepaint := True;
End;

{ --- Compter les entrees visibles (filtrees) --- }

Function GetVisibleErrorCount(Var EL: TErrorListPanel): Integer;
Var
 I, C: Integer;
Begin
 C := 0;
 For I := 0 To EL.Count - 1 Do Begin
  Case EL.Entries[I].Severity Of
   ES_ERROR:   If EL.ShowErrors Then Inc(C);
   ES_WARNING: If EL.ShowWarnings Then Inc(C);
   ES_INFO:    If EL.ShowInfos Then Inc(C);
  End;
 End;
 GetVisibleErrorCount := C;
End;

{ --- Obtenir l index reel depuis l index visible --- }

Function VisibleToRealIndex(Var EL: TErrorListPanel;
 VisIdx: Integer): Integer;
Var
 I, C: Integer;
Begin
 C := -1;
 For I := 0 To EL.Count - 1 Do Begin
  Case EL.Entries[I].Severity Of
   ES_ERROR:   If EL.ShowErrors Then Inc(C);
   ES_WARNING: If EL.ShowWarnings Then Inc(C);
   ES_INFO:    If EL.ShowInfos Then Inc(C);
  Else
   Inc(C);
  End;
  If C = VisIdx Then Begin
   VisibleToRealIndex := I;
   Exit;
  End;
 End;
 VisibleToRealIndex := -1;
End;

{ --- Dessiner l en-tete avec filtres et compteurs --- }

Procedure DrawErrorListHeader(Var EL: TErrorListPanel);
Var
 ErrCnt, WarnCnt, InfoCnt: Integer;
 BX, TY: Integer;
 S: String;
Begin
 ErrCnt := CountErrors(EL);
 WarnCnt := CountWarnings(EL);
 InfoCnt := CountInfos(EL);
 { Fond de l en-tete }
 SetColor(CLR_TOOLBAR);
 Bar(EL.X, EL.Y, EL.X + EL.Width - 1,
  EL.Y + ERRLIST_HEADER_HEIGHT - 1);
 { Titre }
 SetColor(CLR_MENU_TEXT);
 TY := EL.Y + 6;
 OutTextXY(EL.X + 4, TY, 'Liste d''erreurs');
 { Bouton Erreurs }
 BX := EL.X + 130;
 If EL.ShowErrors Then SetColor(4) Else SetColor(8);
 S := IntToStr(ErrCnt) + ' Erreur';
 If ErrCnt <> 1 Then S := S + 's';
 OutTextXY(BX, TY, S);
 { Bouton Avertissements }
 BX := BX + 90;
 If EL.ShowWarnings Then SetColor(6) Else SetColor(8);
 S := IntToStr(WarnCnt) + ' Avertissement';
 If WarnCnt <> 1 Then S := S + 's';
 OutTextXY(BX, TY, S);
 { Bouton Messages }
 BX := BX + 130;
 If EL.ShowInfos Then SetColor(15) Else SetColor(8);
 S := IntToStr(InfoCnt) + ' Message';
 If InfoCnt <> 1 Then S := S + 's';
 OutTextXY(BX, TY, S);
 { Bordure basse }
 SetColor(CLR_BORDER);
 Line(EL.X, EL.Y + ERRLIST_HEADER_HEIGHT - 1,
  EL.X + EL.Width - 1, EL.Y + ERRLIST_HEADER_HEIGHT - 1);
End;

{ --- Dessiner les en-tetes de colonnes --- }

Procedure DrawErrorColumnHeaders(Var EL: TErrorListPanel);
Var
 CY, CX: Integer;
Begin
 CY := EL.Y + ERRLIST_HEADER_HEIGHT;
 SetColor(CLR_MENUBAR);
 Bar(EL.X, CY, EL.X + EL.Width - 1, CY + ERRLIST_ROW_HEIGHT - 1);
 SetColor(CLR_MENU_TEXT);
 CX := EL.X + 2;
 OutTextXY(CX, CY + 2, '!');
 CX := CX + ERRLIST_SEV_WIDTH;
 OutTextXY(CX, CY + 2, 'Code');
 CX := CX + ERRLIST_CODE_WIDTH;
 OutTextXY(CX, CY + 2, 'Description');
 CX := EL.X + EL.Width - ERRLIST_PROJECT_WIDTH - ERRLIST_LINE_WIDTH
  - ERRLIST_FILE_WIDTH;
 OutTextXY(CX, CY + 2, 'Fichier');
 CX := CX + ERRLIST_FILE_WIDTH;
 OutTextXY(CX, CY + 2, 'Ligne');
 CX := CX + ERRLIST_LINE_WIDTH;
 OutTextXY(CX, CY + 2, 'Projet');
 { Bordure basse }
 SetColor(CLR_BORDER);
 Line(EL.X, CY + ERRLIST_ROW_HEIGHT - 1,
  EL.X + EL.Width - 1, CY + ERRLIST_ROW_HEIGHT - 1);
End;

{ --- Dessiner une ligne d erreur --- }

Procedure DrawErrorRow(Var EL: TErrorListPanel;
 Idx, VisRow: Integer);
Var
 RY, CX: Integer;
 BgColor: Integer;
Begin
 If (Idx < 0) Or (Idx >= EL.Count) Then Exit;
 RY := EL.Y + ERRLIST_HEADER_HEIGHT + ERRLIST_ROW_HEIGHT
  + VisRow * ERRLIST_ROW_HEIGHT;
 If RY + ERRLIST_ROW_HEIGHT > EL.Y + EL.Height Then Exit;
 { Fond }
 If Idx = EL.SelectedIdx Then
  BgColor := CLR_SELECTION
 Else If (VisRow Mod 2) = 0 Then
  BgColor := CLR_EDITOR_BG
 Else
  BgColor := CLR_OUTPUT_BG;
 SetColor(BgColor);
 Bar(EL.X, RY, EL.X + EL.Width - 1, RY + ERRLIST_ROW_HEIGHT - 1);
 { Icone severite }
 CX := EL.X + 2;
 SetColor(SeverityColor(EL.Entries[Idx].Severity));
 Case EL.Entries[Idx].Severity Of
  ES_ERROR:   OutTextXY(CX, RY + 2, 'E');
  ES_WARNING: OutTextXY(CX, RY + 2, 'W');
  ES_INFO:    OutTextXY(CX, RY + 2, 'I');
 End;
 { Code }
 CX := EL.X + 2 + ERRLIST_SEV_WIDTH;
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(CX, RY + 2, EL.Entries[Idx].Code);
 { Description }
 CX := CX + ERRLIST_CODE_WIDTH;
 SetColor(SeverityColor(EL.Entries[Idx].Severity));
 OutTextXY(CX, RY + 2, Copy(EL.Entries[Idx].Description, 1, 60));
 { Fichier }
 CX := EL.X + EL.Width - ERRLIST_PROJECT_WIDTH - ERRLIST_LINE_WIDTH
  - ERRLIST_FILE_WIDTH;
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(CX, RY + 2, ExtractFileName(EL.Entries[Idx].FileName));
 { Ligne }
 CX := CX + ERRLIST_FILE_WIDTH;
 If EL.Entries[Idx].Line > 0 Then
  OutTextXY(CX, RY + 2, IntToStr(EL.Entries[Idx].Line));
 { Projet }
 CX := CX + ERRLIST_LINE_WIDTH;
 OutTextXY(CX, RY + 2, EL.Entries[Idx].Project);
End;

{ --- Dessiner le panneau de liste d erreurs --- }

Procedure DrawErrorList(Var EL: TErrorListPanel);
Var
 I, VisCount, VisRow, Visible, RealIdx: Integer;
Begin
 If Not EL.Visible Then Exit;
 { Splitter }
 SetColor(CLR_TOOLBAR);
 Bar(EL.X, EL.SplitterY, EL.X + EL.Width - 1,
  EL.SplitterY + ERRLIST_SPLITTER_HEIGHT - 1);
 { Fond }
 SetColor(CLR_OUTPUT_BG);
 Bar(EL.X, EL.Y, EL.X + EL.Width - 1, EL.Y + EL.Height - 1);
 { En-tete }
 DrawErrorListHeader(EL);
 DrawErrorColumnHeaders(EL);
 { Lignes visibles }
 Visible := (EL.Height - ERRLIST_HEADER_HEIGHT - ERRLIST_ROW_HEIGHT)
  Div ERRLIST_ROW_HEIGHT;
 VisCount := GetVisibleErrorCount(EL);
 VisRow := 0;
 For I := 0 To VisCount - 1 Do Begin
  If I < EL.ScrollTop Then Continue;
  If VisRow >= Visible Then Break;
  RealIdx := VisibleToRealIndex(EL, I);
  If RealIdx >= 0 Then Begin
   DrawErrorRow(EL, RealIdx, VisRow);
   Inc(VisRow);
  End;
 End;
 EL.NeedRepaint := False;
End;

{ --- Test de clic dans le panneau --- }

Function ErrorListHitTest(Var EL: TErrorListPanel;
 MX, MY: Integer): Boolean;
Begin
 ErrorListHitTest := EL.Visible And
  (MX >= EL.X) And (MX < EL.X + EL.Width) And
  (MY >= EL.Y) And (MY < EL.Y + EL.Height);
End;

{ --- Test de clic sur le splitter --- }

Function ErrorListSplitterHitTest(Var EL: TErrorListPanel;
 MX, MY: Integer): Boolean;
Begin
 ErrorListSplitterHitTest := EL.Visible And
  (MX >= EL.X) And (MX < EL.X + EL.Width) And
  (MY >= EL.SplitterY) And
  (MY < EL.SplitterY + ERRLIST_SPLITTER_HEIGHT);
End;

{ --- Test de clic sur l en-tete de filtre --- }

Function ErrorHeaderHitTest(Var EL: TErrorListPanel;
 MX, MY: Integer): Integer;
Begin
 ErrorHeaderHitTest := -1;
 If Not EL.Visible Then Exit;
 If (MY < EL.Y) Or (MY >= EL.Y + ERRLIST_HEADER_HEIGHT) Then Exit;
 If (MX >= EL.X + 130) And (MX < EL.X + 220) Then
  ErrorHeaderHitTest := 0   { Erreurs }
 Else If (MX >= EL.X + 220) And (MX < EL.X + 350) Then
  ErrorHeaderHitTest := 1   { Avertissements }
 Else If (MX >= EL.X + 350) And (MX < EL.X + 450) Then
  ErrorHeaderHitTest := 2;  { Messages }
End;

{ --- Test de clic sur une ligne d erreur --- }

Function ErrorRowHitTest(Var EL: TErrorListPanel;
 MX, MY: Integer): Integer;
Var
 ListY, Row, VisCount: Integer;
Begin
 ErrorRowHitTest := -1;
 If Not EL.Visible Then Exit;
 ListY := EL.Y + ERRLIST_HEADER_HEIGHT + ERRLIST_ROW_HEIGHT;
 If (MY < ListY) Or (MY >= EL.Y + EL.Height) Then Exit;
 Row := (MY - ListY) Div ERRLIST_ROW_HEIGHT;
 Row := Row + EL.ScrollTop;
 VisCount := GetVisibleErrorCount(EL);
 If (Row >= 0) And (Row < VisCount) Then
  ErrorRowHitTest := VisibleToRealIndex(EL, Row);
End;

{ --- Test de clic sur les en-tetes de colonnes --- }

Function ErrorColumnHitTest(Var EL: TErrorListPanel;
 MX, MY: Integer): TErrorSortColumn;
Var
 CY, CX: Integer;
Begin
 ErrorColumnHitTest := ESC_SEVERITY;
 CY := EL.Y + ERRLIST_HEADER_HEIGHT;
 If (MY < CY) Or (MY >= CY + ERRLIST_ROW_HEIGHT) Then Exit;
 CX := EL.X + 2;
 If MX < CX + ERRLIST_SEV_WIDTH Then Begin
  ErrorColumnHitTest := ESC_SEVERITY; Exit;
 End;
 CX := CX + ERRLIST_SEV_WIDTH;
 If MX < CX + ERRLIST_CODE_WIDTH Then Begin
  ErrorColumnHitTest := ESC_CODE; Exit;
 End;
 CX := EL.X + EL.Width - ERRLIST_PROJECT_WIDTH - ERRLIST_LINE_WIDTH
  - ERRLIST_FILE_WIDTH;
 If MX < CX Then Begin
  ErrorColumnHitTest := ESC_DESCRIPTION; Exit;
 End;
 If MX < CX + ERRLIST_FILE_WIDTH Then Begin
  ErrorColumnHitTest := ESC_FILE; Exit;
 End;
 CX := CX + ERRLIST_FILE_WIDTH;
 If MX < CX + ERRLIST_LINE_WIDTH Then Begin
  ErrorColumnHitTest := ESC_LINE; Exit;
 End;
 ErrorColumnHitTest := ESC_PROJECT;
End;

{ --- Gestion des evenements du panneau --- }

Procedure HandleErrorListEvent(Var EL: TErrorListPanel;
 Ev: TEvent);
Var
 VisCount, Visible, HdrBtn, RowIdx: Integer;
 ColY: Integer;
Begin
 If Not EL.Visible Then Exit;
 VisCount := GetVisibleErrorCount(EL);
 Visible := (EL.Height - ERRLIST_HEADER_HEIGHT - ERRLIST_ROW_HEIGHT)
  Div ERRLIST_ROW_HEIGHT;
 If Visible < 1 Then Visible := 1;
 Case Ev.Kind Of
  EV_MOUSE_DOWN: Begin
   { Splitter drag }
   If ErrorListSplitterHitTest(EL, Ev.MouseX, Ev.MouseY) Then Begin
    EL.Dragging := True;
    Exit;
   End;
   { En-tete de filtre }
   HdrBtn := ErrorHeaderHitTest(EL, Ev.MouseX, Ev.MouseY);
   If HdrBtn >= 0 Then Begin
    Case HdrBtn Of
     0: EL.ShowErrors := Not EL.ShowErrors;
     1: EL.ShowWarnings := Not EL.ShowWarnings;
     2: EL.ShowInfos := Not EL.ShowInfos;
    End;
    EL.ScrollTop := 0;
    EL.SelectedIdx := -1;
    EL.NeedRepaint := True;
    Exit;
   End;
   { En-tete de colonne (tri) }
   ColY := EL.Y + ERRLIST_HEADER_HEIGHT;
   If (Ev.MouseY >= ColY) And
      (Ev.MouseY < ColY + ERRLIST_ROW_HEIGHT) Then Begin
    SortErrors(EL, ErrorColumnHitTest(EL, Ev.MouseX, Ev.MouseY));
    Exit;
   End;
   { Ligne d erreur }
   RowIdx := ErrorRowHitTest(EL, Ev.MouseX, Ev.MouseY);
   If RowIdx >= 0 Then Begin
    EL.SelectedIdx := RowIdx;
    EL.NeedRepaint := True;
   End;
  End;
  EV_MOUSE_UP: Begin
   If EL.Dragging Then Begin
    EL.Dragging := False;
    EL.NeedRepaint := True;
   End;
  End;
  EV_MOUSE_MOVE: Begin
   If EL.Dragging Then Begin
    EL.Height := EL.Y + EL.Height - Ev.MouseY;
    If EL.Height < ERRLIST_MIN_HEIGHT Then
     EL.Height := ERRLIST_MIN_HEIGHT;
    If EL.Height > ERRLIST_MAX_HEIGHT Then
     EL.Height := ERRLIST_MAX_HEIGHT;
    EL.Y := Ev.MouseY;
    EL.SplitterY := EL.Y - ERRLIST_SPLITTER_HEIGHT;
    EL.NeedRepaint := True;
   End;
  End;
  EV_MOUSE_DBLCLICK: Begin
   { Double-clic : naviguer vers la source }
   RowIdx := ErrorRowHitTest(EL, Ev.MouseX, Ev.MouseY);
   If (RowIdx >= 0) And (RowIdx < EL.Count) Then Begin
    EL.SelectedIdx := RowIdx;
    EL.NeedRepaint := True;
    { Navigation vers le fichier serait traitee par l appelant }
   End;
  End;
  EV_KEY_DOWN: Begin
   Case Ev.KeyCode Of
    $5000: Begin { Fleche bas }
     If EL.SelectedIdx < 0 Then
      EL.SelectedIdx := 0
     Else If EL.SelectedIdx < EL.Count - 1 Then
      Inc(EL.SelectedIdx);
     If EL.SelectedIdx >= EL.ScrollTop + Visible Then
      EL.ScrollTop := EL.SelectedIdx - Visible + 1;
     EL.NeedRepaint := True;
    End;
    $4800: Begin { Fleche haut }
     If EL.SelectedIdx > 0 Then Begin
      Dec(EL.SelectedIdx);
      If EL.SelectedIdx < EL.ScrollTop Then
       EL.ScrollTop := EL.SelectedIdx;
      EL.NeedRepaint := True;
     End;
    End;
    $4700: Begin { Home }
     EL.SelectedIdx := 0;
     EL.ScrollTop := 0;
     EL.NeedRepaint := True;
    End;
    $4F00: Begin { End }
     If VisCount > 0 Then Begin
      EL.SelectedIdx := VisibleToRealIndex(EL, VisCount - 1);
      If VisCount > Visible Then
       EL.ScrollTop := VisCount - Visible
      Else
       EL.ScrollTop := 0;
     End;
     EL.NeedRepaint := True;
    End;
    $4900: Begin { Page haut }
     Dec(EL.ScrollTop, Visible);
     If EL.ScrollTop < 0 Then EL.ScrollTop := 0;
     Dec(EL.SelectedIdx, Visible);
     If EL.SelectedIdx < 0 Then EL.SelectedIdx := 0;
     EL.NeedRepaint := True;
    End;
    $5100: Begin { Page bas }
     Inc(EL.ScrollTop, Visible);
     If EL.ScrollTop > VisCount - Visible Then Begin
      EL.ScrollTop := VisCount - Visible;
      If EL.ScrollTop < 0 Then EL.ScrollTop := 0;
     End;
     Inc(EL.SelectedIdx, Visible);
     If EL.SelectedIdx >= EL.Count Then
      EL.SelectedIdx := EL.Count - 1;
     EL.NeedRepaint := True;
    End;
   End;
  End;
 End;
End;

{ --- Trouver une erreur par code et fichier --- }

Function FindError(Var EL: TErrorListPanel;
 ACode, AFile: String): Integer;
Var
 I: Integer;
Begin
 For I := 0 To EL.Count - 1 Do
  If (EL.Entries[I].Code = ACode) And
     (EL.Entries[I].FileName = AFile) Then Begin
   FindError := I;
   Exit;
  End;
 FindError := -1;
End;

{ --- Obtenir le nombre total d entrees --- }

Function GetErrorCount(Var EL: TErrorListPanel): Integer;
Begin
 GetErrorCount := EL.Count;
End;

{ --- Obtenir une entree par index --- }

Function GetErrorByIndex(Var EL: TErrorListPanel;
 Idx: Integer; Var E: TErrorEntry): Boolean;
Begin
 If (Idx >= 0) And (Idx < EL.Count) Then Begin
  E := EL.Entries[Idx];
  GetErrorByIndex := True;
 End Else
  GetErrorByIndex := False;
End;

{ --- Verifier si l index est valide --- }

Function IsValidErrorIndex(Var EL: TErrorListPanel;
 Idx: Integer): Boolean;
Begin
 IsValidErrorIndex := (Idx >= 0) And (Idx < EL.Count);
End;

{ --- Obtenir l index selectionne --- }

Function GetSelectedErrorIndex(Var EL: TErrorListPanel): Integer;
Begin
 GetSelectedErrorIndex := EL.SelectedIdx;
End;

{ --- Definir l index selectionne --- }

Procedure SetSelectedErrorIndex(Var EL: TErrorListPanel;
 Idx: Integer);
Begin
 If (Idx >= -1) And (Idx < EL.Count) Then
  EL.SelectedIdx := Idx
 Else
  EL.SelectedIdx := -1;
 EL.NeedRepaint := True;
End;

{ --- Obtenir le fichier source de l entree selectionnee --- }

Function GetSelectedErrorFile(Var EL: TErrorListPanel): String;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorFile := EL.Entries[EL.SelectedIdx].FileName
 Else
  GetSelectedErrorFile := '';
End;

{ --- Obtenir la ligne source de l entree selectionnee --- }

Function GetSelectedErrorLine(Var EL: TErrorListPanel): Integer;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorLine := EL.Entries[EL.SelectedIdx].Line
 Else
  GetSelectedErrorLine := 0;
End;

{ --- Obtenir la colonne source de l entree selectionnee --- }

Function GetSelectedErrorCol(Var EL: TErrorListPanel): Integer;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorCol := EL.Entries[EL.SelectedIdx].Col
 Else
  GetSelectedErrorCol := 0;
End;

{ --- Verifier si le panneau est visible --- }

Function IsErrorListVisible(Var EL: TErrorListPanel): Boolean;
Begin
 IsErrorListVisible := EL.Visible;
End;

{ --- Afficher le panneau --- }

Procedure ShowErrorList(Var EL: TErrorListPanel);
Begin
 EL.Visible := True;
 EL.NeedRepaint := True;
End;

{ --- Masquer le panneau --- }

Procedure HideErrorList(Var EL: TErrorListPanel);
Begin
 EL.Visible := False;
 EL.NeedRepaint := True;
End;

{ --- Basculer la visibilite --- }

Procedure ToggleErrorList(Var EL: TErrorListPanel);
Begin
 EL.Visible := Not EL.Visible;
 EL.NeedRepaint := True;
End;

{ --- Verifier si la liste est vide --- }

Function IsErrorListEmpty(Var EL: TErrorListPanel): Boolean;
Begin
 IsErrorListEmpty := EL.Count = 0;
End;

{ --- Obtenir la colonne de tri --- }

Function GetErrorSortColumn(Var EL: TErrorListPanel): TErrorSortColumn;
Begin
 GetErrorSortColumn := EL.SortColumn;
End;

{ --- Definir la colonne de tri --- }

Procedure SetErrorSortColumn(Var EL: TErrorListPanel;
 Col: TErrorSortColumn);
Begin
 SortErrors(EL, Col);
End;

{ --- Les erreurs sont-elles affichees ? --- }

Function AreErrorsShown(Var EL: TErrorListPanel): Boolean;
Begin
 AreErrorsShown := EL.ShowErrors;
End;

{ --- Les avertissements sont-ils affiches ? --- }

Function AreWarningsShown(Var EL: TErrorListPanel): Boolean;
Begin
 AreWarningsShown := EL.ShowWarnings;
End;

{ --- Les messages sont-ils affiches ? --- }

Function AreInfosShown(Var EL: TErrorListPanel): Boolean;
Begin
 AreInfosShown := EL.ShowInfos;
End;

{ --- Basculer l affichage des erreurs --- }

Procedure ToggleShowErrors(Var EL: TErrorListPanel);
Begin
 EL.ShowErrors := Not EL.ShowErrors;
 EL.ScrollTop := 0;
 EL.NeedRepaint := True;
End;

{ --- Basculer l affichage des avertissements --- }

Procedure ToggleShowWarnings(Var EL: TErrorListPanel);
Begin
 EL.ShowWarnings := Not EL.ShowWarnings;
 EL.ScrollTop := 0;
 EL.NeedRepaint := True;
End;

{ --- Basculer l affichage des messages --- }

Procedure ToggleShowInfos(Var EL: TErrorListPanel);
Begin
 EL.ShowInfos := Not EL.ShowInfos;
 EL.ScrollTop := 0;
 EL.NeedRepaint := True;
End;

{ --- Parser une ligne de sortie CSC --- }
{ Format: filename(line,col): error CSnnnn: message }

Function ParseCSCError(S: String; Var E: TErrorEntry): Boolean;
Var
 P1, P2, P3: Integer;
 LStr, CStr: String;
Begin
 ParseCSCError := False;
 InitErrorEntry(E);
 P1 := Pos('(', S);
 If P1 = 0 Then Exit;
 E.FileName := Copy(S, 1, P1 - 1);
 P2 := Pos(')', S);
 If P2 <= P1 Then Exit;
 LStr := Copy(S, P1 + 1, P2 - P1 - 1);
 P3 := Pos(',', LStr);
 If P3 > 0 Then Begin
  CStr := Copy(LStr, P3 + 1, Length(LStr) - P3);
  LStr := Copy(LStr, 1, P3 - 1);
  E.Col := StrToInt(CStr);
 End;
 E.Line := StrToInt(LStr);
 { Apres ): }
 S := Copy(S, P2 + 2, Length(S) - P2 - 1);
 S := TrimStr(S);
 If Pos('error ', S) = 1 Then Begin
  E.Severity := ES_ERROR;
  S := Copy(S, 7, Length(S) - 6);
 End Else If Pos('warning ', S) = 1 Then Begin
  E.Severity := ES_WARNING;
  S := Copy(S, 9, Length(S) - 8);
 End Else Begin
  E.Severity := ES_INFO;
 End;
 P1 := Pos(':', S);
 If P1 > 0 Then Begin
  E.Code := TrimStr(Copy(S, 1, P1 - 1));
  E.Description := TrimStr(Copy(S, P1 + 1, Length(S) - P1));
 End Else
  E.Description := S;
 ParseCSCError := True;
End;

{ --- Parser une ligne de sortie VBC --- }
{ Format: filename(line): error BCnnnn: message }

Function ParseVBCError(S: String; Var E: TErrorEntry): Boolean;
Var
 P1, P2: Integer;
 LStr: String;
Begin
 ParseVBCError := False;
 InitErrorEntry(E);
 P1 := Pos('(', S);
 If P1 = 0 Then Exit;
 E.FileName := Copy(S, 1, P1 - 1);
 P2 := Pos(')', S);
 If P2 <= P1 Then Exit;
 LStr := Copy(S, P1 + 1, P2 - P1 - 1);
 E.Line := StrToInt(LStr);
 { Apres ): }
 S := Copy(S, P2 + 2, Length(S) - P2 - 1);
 S := TrimStr(S);
 If Pos('error ', S) = 1 Then Begin
  E.Severity := ES_ERROR;
  S := Copy(S, 7, Length(S) - 6);
 End Else If Pos('warning ', S) = 1 Then Begin
  E.Severity := ES_WARNING;
  S := Copy(S, 9, Length(S) - 8);
 End Else
  E.Severity := ES_INFO;
 P1 := Pos(':', S);
 If P1 > 0 Then Begin
  E.Code := TrimStr(Copy(S, 1, P1 - 1));
  E.Description := TrimStr(Copy(S, P1 + 1, Length(S) - P1));
 End Else
  E.Description := S;
 ParseVBCError := True;
End;

{ --- Parser une ligne de sortie TPC --- }
{ Format: filename(line,col) Error: message }

Function ParseTPCError(S: String; Var E: TErrorEntry): Boolean;
Var
 P1, P2, P3: Integer;
 LStr, CStr: String;
Begin
 ParseTPCError := False;
 InitErrorEntry(E);
 P1 := Pos('(', S);
 If P1 = 0 Then Exit;
 E.FileName := Copy(S, 1, P1 - 1);
 P2 := Pos(')', S);
 If P2 <= P1 Then Exit;
 LStr := Copy(S, P1 + 1, P2 - P1 - 1);
 P3 := Pos(',', LStr);
 If P3 > 0 Then Begin
  CStr := Copy(LStr, P3 + 1, Length(LStr) - P3);
  LStr := Copy(LStr, 1, P3 - 1);
  E.Col := StrToInt(CStr);
 End;
 E.Line := StrToInt(LStr);
 { Apres ) }
 S := Copy(S, P2 + 1, Length(S) - P2);
 S := TrimStr(S);
 If Pos('Error:', S) = 1 Then Begin
  E.Severity := ES_ERROR;
  E.Description := TrimStr(Copy(S, 7, Length(S) - 6));
  E.Code := 'TPC';
 End Else If Pos('Warning:', S) = 1 Then Begin
  E.Severity := ES_WARNING;
  E.Description := TrimStr(Copy(S, 9, Length(S) - 8));
  E.Code := 'TPC';
 End Else If Pos('Note:', S) = 1 Then Begin
  E.Severity := ES_INFO;
  E.Description := TrimStr(Copy(S, 6, Length(S) - 5));
  E.Code := 'TPC';
 End Else Begin
  E.Severity := ES_INFO;
  E.Description := S;
  E.Code := 'TPC';
 End;
 ParseTPCError := True;
End;

{ --- Parser une ligne de sortie compilateur generique --- }

Function ParseCompilerOutput(S, Proj: String;
 Var EL: TErrorListPanel): Boolean;
Var
 E: TErrorEntry;
Begin
 ParseCompilerOutput := False;
 If ParseCSCError(S, E) Then Begin
  E.Project := Proj;
  AddError(EL, E);
  ParseCompilerOutput := True;
 End Else If ParseVBCError(S, E) Then Begin
  E.Project := Proj;
  AddError(EL, E);
  ParseCompilerOutput := True;
 End Else If ParseTPCError(S, E) Then Begin
  E.Project := Proj;
  AddError(EL, E);
  ParseCompilerOutput := True;
 End;
End;

{ --- Obtenir la description de l entree selectionnee --- }

Function GetSelectedErrorDescription(
 Var EL: TErrorListPanel): String;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorDescription :=
   EL.Entries[EL.SelectedIdx].Description
 Else
  GetSelectedErrorDescription := '';
End;

{ --- Obtenir le code de l entree selectionnee --- }

Function GetSelectedErrorCode(Var EL: TErrorListPanel): String;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorCode := EL.Entries[EL.SelectedIdx].Code
 Else
  GetSelectedErrorCode := '';
End;

{ --- Obtenir la severite de l entree selectionnee --- }

Function GetSelectedErrorSeverity(
 Var EL: TErrorListPanel): TErrorSeverity;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorSeverity := EL.Entries[EL.SelectedIdx].Severity
 Else
  GetSelectedErrorSeverity := ES_INFO;
End;

{ --- Obtenir le projet de l entree selectionnee --- }

Function GetSelectedErrorProject(Var EL: TErrorListPanel): String;
Begin
 If (EL.SelectedIdx >= 0) And (EL.SelectedIdx < EL.Count) Then
  GetSelectedErrorProject := EL.Entries[EL.SelectedIdx].Project
 Else
  GetSelectedErrorProject := '';
End;

{ ============================================================
  TODO 21 - BOITES DE DIALOGUE : FICHIERS [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser un dialogue de base --- }

Procedure InitDialog(Var Dlg: TDialog; T: String; W, H: Integer);
Var
 ScrW, ScrH: Integer;
Begin
 Dlg.Title := T;
 If W < DLG_MIN_WIDTH Then
  W := DLG_MIN_WIDTH;
 If H < DLG_MIN_HEIGHT Then
  H := DLG_MIN_HEIGHT;
 Dlg.Width := W;
 Dlg.Height := H;
 ScrW := GetScreenWidth;
 ScrH := GetScreenHeight;
 Dlg.X := (ScrW - W) Div 2;
 Dlg.Y := (ScrH - H) Div 2;
 Dlg.Result := DR_NONE;
 Dlg.Visible := True;
 Dlg.HasCancel := True;
End;

{ --- Dessiner le cadre du dialogue (bordure, titre, fond) --- }

Procedure DrawDialogFrame(Var Dlg: TDialog);
Var
 X1, Y1, X2, Y2: Integer;
Begin
 X1 := Dlg.X;
 Y1 := Dlg.Y;
 X2 := X1 + Dlg.Width - 1;
 Y2 := Y1 + Dlg.Height - 1;
 { Bordure }
 SetColor(CLR_BORDER);
 Rectangle(X1, Y1, X2, Y2);
 { Fond }
 SetFillStyle(SolidFill, CLR_BACKGROUND);
 Bar(X1 + 1, Y1 + 1, X2 - 1, Y2 - 1);
 { Barre de titre }
 SetFillStyle(SolidFill, CLR_TITLEBAR_ACTIVE);
 Bar(X1 + 1, Y1 + 1, X2 - 1, Y1 + DLG_TITLE_HEIGHT);
 { Texte du titre }
 SetColor(15);
 OutTextXY(X1 + DLG_PADDING, Y1 + 4, Dlg.Title);
End;

{ --- Dessiner un bouton de dialogue --- }

Procedure DrawDialogButton(X, Y: Integer; Caption: String;
 Focused: Boolean);
Var
 BG: Integer;
Begin
 If Focused Then
  BG := CLR_TITLEBAR_ACTIVE
 Else
  BG := CLR_BACKGROUND;
 SetFillStyle(SolidFill, BG);
 Bar(X, Y, X + DLG_BUTTON_WIDTH - 1, Y + DLG_BUTTON_HEIGHT - 1);
 SetColor(CLR_BORDER);
 Rectangle(X, Y, X + DLG_BUTTON_WIDTH - 1, Y + DLG_BUTTON_HEIGHT - 1);
 If Focused Then
  SetColor(15)
 Else
  SetColor(CLR_MENU_TEXT);
 OutTextXY(X + (DLG_BUTTON_WIDTH - TextWidth(Caption)) Div 2,
  Y + (DLG_BUTTON_HEIGHT - TextHeight(Caption)) Div 2, Caption);
End;

{ --- Dessiner les boutons OK / Annuler en bas du dialogue --- }

Procedure DrawDialogButtons(Var Dlg: TDialog);
Var
 BX, BY, Cnt, TotalW: Integer;
Begin
 BY := Dlg.Y + Dlg.Height - DLG_PADDING - DLG_BUTTON_HEIGHT;
 Cnt := 1;
 If Dlg.HasCancel Then
  Cnt := 2;
 TotalW := Cnt * DLG_BUTTON_WIDTH + (Cnt - 1) * DLG_BUTTON_SPACING;
 BX := Dlg.X + (Dlg.Width - TotalW) Div 2;
 DrawDialogButton(BX, BY, 'OK', True);
 If Dlg.HasCancel Then
  DrawDialogButton(BX + DLG_BUTTON_WIDTH + DLG_BUTTON_SPACING,
   BY, 'Annuler', False);
End;

{ --- Fermer un dialogue --- }

Procedure CloseDialog(Var Dlg: TDialog);
Begin
 Dlg.Visible := False;
End;

{ --- Nombre de boutons du dialogue --- }

Function DialogButtonCount(Var Dlg: TDialog): Integer;
Begin
 If Dlg.HasCancel Then
  DialogButtonCount := 2
 Else
  DialogButtonCount := 1;
End;

{ --- Test de clic sur un bouton du dialogue --- }

Function DialogButtonHitTest(Var Dlg: TDialog; MX, MY: Integer): Integer;
Var
 BX, BY, Cnt, TotalW, I, X1, X2, Y1, Y2: Integer;
Begin
 DialogButtonHitTest := -1;
 BY := Dlg.Y + Dlg.Height - DLG_PADDING - DLG_BUTTON_HEIGHT;
 Cnt := DialogButtonCount(Dlg);
 TotalW := Cnt * DLG_BUTTON_WIDTH + (Cnt - 1) * DLG_BUTTON_SPACING;
 BX := Dlg.X + (Dlg.Width - TotalW) Div 2;
 For I := 0 To Cnt - 1 Do Begin
  X1 := BX + I * (DLG_BUTTON_WIDTH + DLG_BUTTON_SPACING);
  X2 := X1 + DLG_BUTTON_WIDTH - 1;
  Y1 := BY;
  Y2 := BY + DLG_BUTTON_HEIGHT - 1;
  If (MX >= X1) And (MX <= X2) And (MY >= Y1) And (MY <= Y2) Then Begin
   DialogButtonHitTest := I;
   Exit;
  End;
 End;
End;

{ --- Verifier si un point est a l interieur du dialogue --- }

Function IsInsideDialog(Var Dlg: TDialog; MX, MY: Integer): Boolean;
Begin
 IsInsideDialog := (MX >= Dlg.X) And (MX < Dlg.X + Dlg.Width) And
  (MY >= Dlg.Y) And (MY < Dlg.Y + Dlg.Height);
End;

{ --- Initialiser une entree de liste de fichiers --- }

Procedure InitFileListEntry(Var E: TFileListEntry);
Begin
 E.Name := '';
 E.IsDir := False;
 E.Size := 0;
End;

{ --- Vider la liste de fichiers d un dialogue fichier --- }

Procedure ClearFileList(Var FD: TFileDialog);
Var
 I: Integer;
Begin
 For I := 0 To FD.FileCount - 1 Do
  InitFileListEntry(FD.FileList[I]);
 FD.FileCount := 0;
 FD.SelIndex := -1;
 FD.ScrollTop := 0;
End;

{ --- Vider la liste de fichiers d un dialogue dossier --- }

Procedure ClearFolderList(Var FD: TFolderDialog);
Var
 I: Integer;
Begin
 For I := 0 To FD.FileCount - 1 Do
  InitFileListEntry(FD.FileList[I]);
 FD.FileCount := 0;
 FD.SelIndex := -1;
 FD.ScrollTop := 0;
End;

{ --- Verifier si un nom correspond a un filtre (*.ext) --- }

Function MatchesFilter(Name, Pattern: String): Boolean;
Var
 Ext, PatExt: String;
 I, DotPos: Integer;
Begin
 If (Pattern = '*.*') Or (Pattern = '*') Then Begin
  MatchesFilter := True;
  Exit;
 End;
 { Extraire l extension du pattern apres le point }
 DotPos := 0;
 For I := Length(Pattern) DownTo 1 Do
  If Pattern[I] = '.' Then Begin
   DotPos := I;
   Break;
  End;
 If DotPos = 0 Then Begin
  MatchesFilter := True;
  Exit;
 End;
 PatExt := LowerCaseStr(Copy(Pattern, DotPos, Length(Pattern) - DotPos + 1));
 { Extraire l extension du fichier }
 DotPos := 0;
 For I := Length(Name) DownTo 1 Do
  If Name[I] = '.' Then Begin
   DotPos := I;
   Break;
  End;
 If DotPos = 0 Then Begin
  MatchesFilter := False;
  Exit;
 End;
 Ext := LowerCaseStr(Copy(Name, DotPos, Length(Name) - DotPos + 1));
 MatchesFilter := (Ext = PatExt);
End;

{ --- Charger les fichiers du repertoire courant (dialogue fichier) --- }

Procedure LoadDirectoryFiles(Var FD: TFileDialog);
Var
 SR: SearchRec;
 Pat: String;
Begin
 ClearFileList(FD);
 { Ajouter l entree parent }
 If FD.FileCount < MAX_DLG_FILES Then Begin
  FD.FileList[FD.FileCount].Name := '..';
  FD.FileList[FD.FileCount].IsDir := True;
  FD.FileList[FD.FileCount].Size := 0;
  Inc(FD.FileCount);
 End;
 { Repertoires }
 FindFirst(FD.CurrentPath + '*.*', Directory, SR);
 While (DosError = 0) And (FD.FileCount < MAX_DLG_FILES) Do Begin
  If ((SR.Attr And Directory) <> 0) And (SR.Name <> '.') And
   (SR.Name <> '..') Then Begin
   FD.FileList[FD.FileCount].Name := SR.Name;
   FD.FileList[FD.FileCount].IsDir := True;
   FD.FileList[FD.FileCount].Size := 0;
   Inc(FD.FileCount);
  End;
  FindNext(SR);
 End;
 FindClose(SR);
 { Fichiers correspondant au filtre actif }
 If (FD.FilterIndex >= 0) And (FD.FilterIndex < FD.FilterCount) Then
  Pat := FD.Filters[FD.FilterIndex].Pattern
 Else
  Pat := '*.*';
 FindFirst(FD.CurrentPath + '*.*', AnyFile, SR);
 While (DosError = 0) And (FD.FileCount < MAX_DLG_FILES) Do Begin
  If (SR.Attr And Directory) = 0 Then Begin
   If MatchesFilter(SR.Name, Pat) Then Begin
    FD.FileList[FD.FileCount].Name := SR.Name;
    FD.FileList[FD.FileCount].IsDir := False;
    FD.FileList[FD.FileCount].Size := SR.Size;
    Inc(FD.FileCount);
   End;
  End;
  FindNext(SR);
 End;
 FindClose(SR);
End;

{ --- Charger les dossiers du repertoire courant (dialogue dossier) --- }

Procedure LoadDirectoryFolders(Var FD: TFolderDialog);
Var
 SR: SearchRec;
Begin
 ClearFolderList(FD);
 { Entree parent }
 If FD.FileCount < MAX_DLG_FILES Then Begin
  FD.FileList[FD.FileCount].Name := '..';
  FD.FileList[FD.FileCount].IsDir := True;
  FD.FileList[FD.FileCount].Size := 0;
  Inc(FD.FileCount);
 End;
 FindFirst(FD.CurrentPath + '*.*', Directory, SR);
 While (DosError = 0) And (FD.FileCount < MAX_DLG_FILES) Do Begin
  If ((SR.Attr And Directory) <> 0) And (SR.Name <> '.') And
   (SR.Name <> '..') Then Begin
   FD.FileList[FD.FileCount].Name := SR.Name;
   FD.FileList[FD.FileCount].IsDir := True;
   FD.FileList[FD.FileCount].Size := 0;
   Inc(FD.FileCount);
  End;
  FindNext(SR);
 End;
 FindClose(SR);
End;

{ --- Initialiser un dialogue fichier (ouvrir ou enregistrer) --- }

Procedure InitFileDialog(Var FD: TFileDialog; SaveMode: Boolean);
Var
 I: Integer;
Begin
 If SaveMode Then
  InitDialog(FD.Base, 'Enregistrer sous', DLG_FILE_WIDTH, DLG_FILE_HEIGHT)
 Else
  InitDialog(FD.Base, 'Ouvrir', DLG_FILE_WIDTH, DLG_FILE_HEIGHT);
 FD.Base.HasCancel := True;
 FD.IsSaveMode := SaveMode;
 GetDir(0, FD.CurrentPath);
 If (Length(FD.CurrentPath) > 0) And
  (FD.CurrentPath[Length(FD.CurrentPath)] <> '\') And
  (FD.CurrentPath[Length(FD.CurrentPath)] <> '/') Then
  FD.CurrentPath := FD.CurrentPath + '/';
 FD.SelectedFile := '';
 FD.FileCount := 0;
 FD.FilterCount := 0;
 FD.FilterIndex := 0;
 FD.ScrollTop := 0;
 FD.SelIndex := -1;
 FD.InputText := '';
 FD.InputCursor := 0;
 For I := 0 To MAX_DLG_FILES - 1 Do
  InitFileListEntry(FD.FileList[I]);
End;

{ --- Ajouter un filtre au dialogue fichier --- }

Procedure AddFileFilter(Var FD: TFileDialog; Desc, Pat: String);
Begin
 If FD.FilterCount < MAX_DLG_FILTERS Then Begin
  FD.Filters[FD.FilterCount].Description := Desc;
  FD.Filters[FD.FilterCount].Pattern := Pat;
  Inc(FD.FilterCount);
 End;
End;

{ --- Dessiner la liste de fichiers --- }

Procedure DrawFileList(Var FD: TFileDialog);
Var
 LX, LY, LW, LH, I, Row, TY: Integer;
 Disp: String;
Begin
 LX := FD.Base.X + DLG_PADDING;
 LY := FD.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := FD.Base.Width - 2 * DLG_PADDING;
 LH := FD.Base.Height - DLG_TITLE_HEIGHT - 3 * DLG_PADDING
  - DLG_BUTTON_HEIGHT - DLG_INPUT_HEIGHT - DLG_FILTER_HEIGHT;
 { Fond de la liste }
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(LX, LY, LX + LW - 1, LY + LH - 1);
 SetColor(CLR_BORDER);
 Rectangle(LX, LY, LX + LW - 1, LY + LH - 1);
 { Lignes }
 Row := 0;
 For I := FD.ScrollTop To FD.FileCount - 1 Do Begin
  TY := LY + Row * DLG_LIST_ROW_HEIGHT;
  If TY + DLG_LIST_ROW_HEIGHT > LY + LH Then
   Break;
  If I = FD.SelIndex Then Begin
   SetFillStyle(SolidFill, CLR_SELECTION);
   Bar(LX + 1, TY, LX + LW - 2, TY + DLG_LIST_ROW_HEIGHT - 1);
   SetColor(15);
  End Else
   SetColor(CLR_EDITOR_TEXT);
  If FD.FileList[I].IsDir Then
   Disp := '[' + FD.FileList[I].Name + ']'
  Else
   Disp := FD.FileList[I].Name;
  OutTextXY(LX + 4, TY + 2, Disp);
  Inc(Row);
 End;
End;

{ --- Dessiner le champ de saisie du nom de fichier --- }

Procedure DrawFileInput(Var FD: TFileDialog);
Var
 IX, IY, IW: Integer;
Begin
 IX := FD.Base.X + DLG_PADDING;
 IY := FD.Base.Y + FD.Base.Height - DLG_PADDING - DLG_BUTTON_HEIGHT
  - DLG_PADDING - DLG_FILTER_HEIGHT - DLG_PADDING - DLG_INPUT_HEIGHT;
 IW := FD.Base.Width - 2 * DLG_PADDING;
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(IX, IY, IX + IW - 1, IY + DLG_INPUT_HEIGHT - 1);
 SetColor(CLR_BORDER);
 Rectangle(IX, IY, IX + IW - 1, IY + DLG_INPUT_HEIGHT - 1);
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(IX + 4, IY + 3, FD.InputText);
 { Curseur }
 SetColor(CLR_CURSOR);
 Line(IX + 4 + TextWidth(Copy(FD.InputText, 1, FD.InputCursor)),
  IY + 2,
  IX + 4 + TextWidth(Copy(FD.InputText, 1, FD.InputCursor)),
  IY + DLG_INPUT_HEIGHT - 3);
End;

{ --- Dessiner le selecteur de filtre --- }

Procedure DrawFileFilter(Var FD: TFileDialog);
Var
 FX, FY, FW: Integer;
 Txt: String;
Begin
 FX := FD.Base.X + DLG_PADDING;
 FY := FD.Base.Y + FD.Base.Height - DLG_PADDING - DLG_BUTTON_HEIGHT
  - DLG_PADDING - DLG_FILTER_HEIGHT;
 FW := FD.Base.Width - 2 * DLG_PADDING;
 SetFillStyle(SolidFill, CLR_BACKGROUND);
 Bar(FX, FY, FX + FW - 1, FY + DLG_FILTER_HEIGHT - 1);
 SetColor(CLR_BORDER);
 Rectangle(FX, FY, FX + FW - 1, FY + DLG_FILTER_HEIGHT - 1);
 If (FD.FilterIndex >= 0) And (FD.FilterIndex < FD.FilterCount) Then
  Txt := FD.Filters[FD.FilterIndex].Description
 Else
  Txt := 'Tous les fichiers (*.*)';
 SetColor(CLR_MENU_TEXT);
 OutTextXY(FX + 4, FY + 3, Txt);
End;

{ --- Dessiner le dialogue fichier complet --- }

Procedure DrawFileDialog(Var FD: TFileDialog);
Begin
 If Not FD.Base.Visible Then Exit;
 DrawDialogFrame(FD.Base);
 { Afficher le chemin courant }
 SetColor(CLR_MENU_TEXT);
 OutTextXY(FD.Base.X + DLG_PADDING,
  FD.Base.Y + DLG_TITLE_HEIGHT + 2, FD.CurrentPath);
 DrawFileList(FD);
 DrawFileInput(FD);
 DrawFileFilter(FD);
 DrawDialogButtons(FD.Base);
End;

{ --- Test de clic dans la liste de fichiers --- }

Function FileListHitTest(Var FD: TFileDialog; MX, MY: Integer): Integer;
Var
 LX, LY, LW, LH, Row: Integer;
Begin
 FileListHitTest := -1;
 LX := FD.Base.X + DLG_PADDING;
 LY := FD.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := FD.Base.Width - 2 * DLG_PADDING;
 LH := FD.Base.Height - DLG_TITLE_HEIGHT - 3 * DLG_PADDING
  - DLG_BUTTON_HEIGHT - DLG_INPUT_HEIGHT - DLG_FILTER_HEIGHT;
 If (MX >= LX) And (MX < LX + LW) And (MY >= LY) And (MY < LY + LH) Then
 Begin
  Row := (MY - LY) Div DLG_LIST_ROW_HEIGHT;
  If (FD.ScrollTop + Row >= 0) And
   (FD.ScrollTop + Row < FD.FileCount) Then
   FileListHitTest := FD.ScrollTop + Row;
 End;
End;

{ --- Naviguer vers un repertoire (dialogue fichier) --- }

Procedure NavigateToDir(Var FD: TFileDialog; Dir: String);
Var
 NewPath: String;
Begin
 If Dir = '..' Then Begin
  { Remonter d un niveau }
  NewPath := FD.CurrentPath;
  If (Length(NewPath) > 1) And
   ((NewPath[Length(NewPath)] = '/') Or
    (NewPath[Length(NewPath)] = '\')) Then
   Dec(NewPath[0]);
  While (Length(NewPath) > 0) And (NewPath[Length(NewPath)] <> '/') And
   (NewPath[Length(NewPath)] <> '\') Do
   Dec(NewPath[0]);
  If Length(NewPath) = 0 Then
   NewPath := '/';
 End Else Begin
  NewPath := FD.CurrentPath + Dir + '/';
 End;
 FD.CurrentPath := NewPath;
 LoadDirectoryFiles(FD);
End;

{ --- Gerer une touche clavier dans le dialogue fichier --- }

Procedure HandleFileDialogKey(Var FD: TFileDialog; Key: Char);
Begin
 If Key = #13 Then Begin
  { Entree : valider la saisie }
  If (FD.SelIndex >= 0) And (FD.SelIndex < FD.FileCount) Then Begin
   If FD.FileList[FD.SelIndex].IsDir Then
    NavigateToDir(FD, FD.FileList[FD.SelIndex].Name)
   Else Begin
    FD.SelectedFile := FD.CurrentPath + FD.FileList[FD.SelIndex].Name;
    FD.Base.Result := DR_OK;
    CloseDialog(FD.Base);
   End;
  End Else If Length(FD.InputText) > 0 Then Begin
   FD.SelectedFile := FD.CurrentPath + FD.InputText;
   FD.Base.Result := DR_OK;
   CloseDialog(FD.Base);
  End;
 End Else If Key = #27 Then Begin
  { Echap : annuler }
  FD.Base.Result := DR_CANCEL;
  CloseDialog(FD.Base);
 End Else If Key = #8 Then Begin
  { Retour arriere }
  If (FD.InputCursor > 0) And (Length(FD.InputText) > 0) Then Begin
   Delete(FD.InputText, FD.InputCursor, 1);
   Dec(FD.InputCursor);
  End;
 End Else If (Key >= ' ') And (Key <= '~') Then Begin
  { Caractere imprimable }
  If Length(FD.InputText) < 127 Then Begin
   Inc(FD.InputCursor);
   Insert(Key, FD.InputText, FD.InputCursor);
  End;
 End;
End;

{ --- Gerer un evenement dans le dialogue fichier --- }

Procedure HandleFileDialogEvent(Var FD: TFileDialog; Var Ev: TEvent);
Var
 Idx: Integer;
Begin
 If Not FD.Base.Visible Then Exit;
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  If Not IsInsideDialog(FD.Base, Ev.MouseX, Ev.MouseY) Then Exit;
  { Test de clic sur la liste }
  Idx := FileListHitTest(FD, Ev.MouseX, Ev.MouseY);
  If Idx >= 0 Then Begin
   FD.SelIndex := Idx;
   If FD.FileList[Idx].IsDir Then
    FD.InputText := ''
   Else
    FD.InputText := FD.FileList[Idx].Name;
   FD.InputCursor := Length(FD.InputText);
  End;
  { Test de clic sur les boutons }
  Idx := DialogButtonHitTest(FD.Base, Ev.MouseX, Ev.MouseY);
  If Idx = 0 Then Begin
   { Bouton OK }
   If Length(FD.InputText) > 0 Then Begin
    FD.SelectedFile := FD.CurrentPath + FD.InputText;
    FD.Base.Result := DR_OK;
    CloseDialog(FD.Base);
   End;
  End Else If Idx = 1 Then Begin
   FD.Base.Result := DR_CANCEL;
   CloseDialog(FD.Base);
  End;
 End Else If Ev.Kind = EV_KEY_CHAR Then
  HandleFileDialogKey(FD, Ev.KeyChar)
 Else If Ev.Kind = EV_KEY_DOWN Then Begin
  { Touches speciales : haut/bas pour la liste }
  If Ev.KeyCode = $4800 Then Begin { Fleche haut }
   If FD.SelIndex > 0 Then Begin
    Dec(FD.SelIndex);
    If FD.SelIndex < FD.ScrollTop Then
     FD.ScrollTop := FD.SelIndex;
    If Not FD.FileList[FD.SelIndex].IsDir Then Begin
     FD.InputText := FD.FileList[FD.SelIndex].Name;
     FD.InputCursor := Length(FD.InputText);
    End;
   End;
  End Else If Ev.KeyCode = $5000 Then Begin { Fleche bas }
   If FD.SelIndex < FD.FileCount - 1 Then Begin
    Inc(FD.SelIndex);
    If Not FD.FileList[FD.SelIndex].IsDir Then Begin
     FD.InputText := FD.FileList[FD.SelIndex].Name;
     FD.InputCursor := Length(FD.InputText);
    End;
   End;
  End;
 End;
End;

{ --- Afficher le dialogue d ouverture de fichier (modale) --- }
{ Note : boucle modale simplifiee, a completer dans un TODO futur }

Function ShowOpenDialog(Filter: String): String;
Var
 FD: TFileDialog;
Begin
 InitFileDialog(FD, False);
 If Length(Filter) > 0 Then
  AddFileFilter(FD, Filter, Filter);
 LoadDirectoryFiles(FD);
 DrawFileDialog(FD);
 { Boucle modale a implementer dans un TODO futur }
 ShowOpenDialog := '';
End;

{ --- Afficher le dialogue d enregistrement de fichier (modale) --- }
{ Note : boucle modale simplifiee, a completer dans un TODO futur }

Function ShowSaveDialog(Filter, Default: String): String;
Var
 FD: TFileDialog;
Begin
 InitFileDialog(FD, True);
 FD.InputText := Default;
 FD.InputCursor := Length(Default);
 If Length(Filter) > 0 Then
  AddFileFilter(FD, Filter, Filter);
 LoadDirectoryFiles(FD);
 DrawFileDialog(FD);
 { Boucle modale a implementer dans un TODO futur }
 ShowSaveDialog := '';
End;

{ --- Initialiser un dialogue de dossier --- }

Procedure InitFolderDialog(Var FD: TFolderDialog; StartPath: String);
Var
 I: Integer;
Begin
 InitDialog(FD.Base, 'Selectionner un dossier',
  DLG_FOLDER_WIDTH, DLG_FOLDER_HEIGHT);
 FD.Base.HasCancel := True;
 If Length(StartPath) > 0 Then
  FD.CurrentPath := StartPath
 Else
  GetDir(0, FD.CurrentPath);
 If (Length(FD.CurrentPath) > 0) And
  (FD.CurrentPath[Length(FD.CurrentPath)] <> '/') And
  (FD.CurrentPath[Length(FD.CurrentPath)] <> '\') Then
  FD.CurrentPath := FD.CurrentPath + '/';
 FD.SelectedFolder := '';
 FD.FileCount := 0;
 FD.ScrollTop := 0;
 FD.SelIndex := -1;
 For I := 0 To MAX_DLG_FILES - 1 Do
  InitFileListEntry(FD.FileList[I]);
End;

{ --- Dessiner la liste de dossiers --- }

Procedure DrawFolderList(Var FD: TFolderDialog);
Var
 LX, LY, LW, LH, I, Row, TY: Integer;
Begin
 LX := FD.Base.X + DLG_PADDING;
 LY := FD.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := FD.Base.Width - 2 * DLG_PADDING;
 LH := FD.Base.Height - DLG_TITLE_HEIGHT - 2 * DLG_PADDING
  - DLG_BUTTON_HEIGHT;
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(LX, LY, LX + LW - 1, LY + LH - 1);
 SetColor(CLR_BORDER);
 Rectangle(LX, LY, LX + LW - 1, LY + LH - 1);
 Row := 0;
 For I := FD.ScrollTop To FD.FileCount - 1 Do Begin
  TY := LY + Row * DLG_LIST_ROW_HEIGHT;
  If TY + DLG_LIST_ROW_HEIGHT > LY + LH Then
   Break;
  If I = FD.SelIndex Then Begin
   SetFillStyle(SolidFill, CLR_SELECTION);
   Bar(LX + 1, TY, LX + LW - 2, TY + DLG_LIST_ROW_HEIGHT - 1);
   SetColor(15);
  End Else
   SetColor(CLR_EDITOR_TEXT);
  OutTextXY(LX + 4, TY + 2, '[' + FD.FileList[I].Name + ']');
  Inc(Row);
 End;
End;

{ --- Dessiner le dialogue de dossier complet --- }

Procedure DrawFolderDialog(Var FD: TFolderDialog);
Begin
 If Not FD.Base.Visible Then Exit;
 DrawDialogFrame(FD.Base);
 SetColor(CLR_MENU_TEXT);
 OutTextXY(FD.Base.X + DLG_PADDING,
  FD.Base.Y + DLG_TITLE_HEIGHT + 2, FD.CurrentPath);
 DrawFolderList(FD);
 DrawDialogButtons(FD.Base);
End;

{ --- Test de clic dans la liste de dossiers --- }

Function FolderListHitTest(Var FD: TFolderDialog;
 MX, MY: Integer): Integer;
Var
 LX, LY, LW, LH, Row: Integer;
Begin
 FolderListHitTest := -1;
 LX := FD.Base.X + DLG_PADDING;
 LY := FD.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := FD.Base.Width - 2 * DLG_PADDING;
 LH := FD.Base.Height - DLG_TITLE_HEIGHT - 2 * DLG_PADDING
  - DLG_BUTTON_HEIGHT;
 If (MX >= LX) And (MX < LX + LW) And (MY >= LY) And (MY < LY + LH) Then
 Begin
  Row := (MY - LY) Div DLG_LIST_ROW_HEIGHT;
  If (FD.ScrollTop + Row >= 0) And
   (FD.ScrollTop + Row < FD.FileCount) Then
   FolderListHitTest := FD.ScrollTop + Row;
 End;
End;

{ --- Charger les entrees de dossier (alias de LoadDirectoryFolders) --- }

Procedure LoadFolderEntries(Var FD: TFolderDialog);
Begin
 LoadDirectoryFolders(FD);
End;

{ --- Naviguer vers un dossier (dialogue dossier) --- }

Procedure NavigateToFolder(Var FD: TFolderDialog; Dir: String);
Var
 NewPath: String;
Begin
 If Dir = '..' Then Begin
  NewPath := FD.CurrentPath;
  If (Length(NewPath) > 1) And
   ((NewPath[Length(NewPath)] = '/') Or
    (NewPath[Length(NewPath)] = '\')) Then
   Dec(NewPath[0]);
  While (Length(NewPath) > 0) And (NewPath[Length(NewPath)] <> '/') And
   (NewPath[Length(NewPath)] <> '\') Do
   Dec(NewPath[0]);
  If Length(NewPath) = 0 Then
   NewPath := '/';
 End Else Begin
  NewPath := FD.CurrentPath + Dir + '/';
 End;
 FD.CurrentPath := NewPath;
 LoadFolderEntries(FD);
End;

{ --- Gerer un evenement dans le dialogue de dossier --- }

Procedure HandleFolderDialogEvent(Var FD: TFolderDialog;
 Var Ev: TEvent);
Var
 Idx: Integer;
Begin
 If Not FD.Base.Visible Then Exit;
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  If Not IsInsideDialog(FD.Base, Ev.MouseX, Ev.MouseY) Then Exit;
  Idx := FolderListHitTest(FD, Ev.MouseX, Ev.MouseY);
  If Idx >= 0 Then Begin
   FD.SelIndex := Idx;
   FD.SelectedFolder := FD.CurrentPath + FD.FileList[Idx].Name;
  End;
  Idx := DialogButtonHitTest(FD.Base, Ev.MouseX, Ev.MouseY);
  If Idx = 0 Then Begin
   If Length(FD.SelectedFolder) > 0 Then Begin
    FD.Base.Result := DR_OK;
    CloseDialog(FD.Base);
   End;
  End Else If Idx = 1 Then Begin
   FD.Base.Result := DR_CANCEL;
   CloseDialog(FD.Base);
  End;
 End Else If Ev.Kind = EV_KEY_CHAR Then Begin
  If Ev.KeyChar = #13 Then Begin
   If (FD.SelIndex >= 0) And (FD.SelIndex < FD.FileCount) Then
    NavigateToFolder(FD, FD.FileList[FD.SelIndex].Name);
  End Else If Ev.KeyChar = #27 Then Begin
   FD.Base.Result := DR_CANCEL;
   CloseDialog(FD.Base);
  End;
 End Else If Ev.Kind = EV_KEY_DOWN Then Begin
  If Ev.KeyCode = $4800 Then Begin
   If FD.SelIndex > 0 Then Begin
    Dec(FD.SelIndex);
    If FD.SelIndex < FD.ScrollTop Then
     FD.ScrollTop := FD.SelIndex;
    FD.SelectedFolder := FD.CurrentPath + FD.FileList[FD.SelIndex].Name;
   End;
  End Else If Ev.KeyCode = $5000 Then Begin
   If FD.SelIndex < FD.FileCount - 1 Then Begin
    Inc(FD.SelIndex);
    FD.SelectedFolder := FD.CurrentPath + FD.FileList[FD.SelIndex].Name;
   End;
  End;
 End;
End;

{ --- Afficher le dialogue de selection de dossier (modale) --- }
{ Note : boucle modale simplifiee, a completer dans un TODO futur }

Function ShowFolderDialog(StartPath: String): String;
Var
 FD: TFolderDialog;
Begin
 InitFolderDialog(FD, StartPath);
 LoadFolderEntries(FD);
 DrawFolderDialog(FD);
 { Boucle modale a implementer dans un TODO futur }
 ShowFolderDialog := '';
End;

{ --- Nombre de boutons d une boite de message --- }

Function MessageBoxButtonCount(Btns: TMessageButtons): Integer;
Begin
 Case Btns Of
  MB_OK:          MessageBoxButtonCount := 1;
  MB_OKCANCEL:    MessageBoxButtonCount := 2;
  MB_YESNO:       MessageBoxButtonCount := 2;
  MB_YESNOCANCEL: MessageBoxButtonCount := 3;
 Else
  MessageBoxButtonCount := 1;
 End;
End;

{ --- Libelle d un bouton de boite de message --- }

Function MessageBoxButtonLabel(Btns: TMessageButtons;
 Idx: Integer): String;
Begin
 MessageBoxButtonLabel := '';
 Case Btns Of
  MB_OK:
   If Idx = 0 Then MessageBoxButtonLabel := 'OK';
  MB_OKCANCEL:
   Case Idx Of
    0: MessageBoxButtonLabel := 'OK';
    1: MessageBoxButtonLabel := 'Annuler';
   End;
  MB_YESNO:
   Case Idx Of
    0: MessageBoxButtonLabel := 'Oui';
    1: MessageBoxButtonLabel := 'Non';
   End;
  MB_YESNOCANCEL:
   Case Idx Of
    0: MessageBoxButtonLabel := 'Oui';
    1: MessageBoxButtonLabel := 'Non';
    2: MessageBoxButtonLabel := 'Annuler';
   End;
 End;
End;

{ --- Resultat associe a un bouton de boite de message --- }

Function MessageBoxButtonResult(Btns: TMessageButtons;
 Idx: Integer): Integer;
Begin
 MessageBoxButtonResult := DR_NONE;
 Case Btns Of
  MB_OK:
   If Idx = 0 Then MessageBoxButtonResult := DR_OK;
  MB_OKCANCEL:
   Case Idx Of
    0: MessageBoxButtonResult := DR_OK;
    1: MessageBoxButtonResult := DR_CANCEL;
   End;
  MB_YESNO:
   Case Idx Of
    0: MessageBoxButtonResult := DR_YES;
    1: MessageBoxButtonResult := DR_NO;
   End;
  MB_YESNOCANCEL:
   Case Idx Of
    0: MessageBoxButtonResult := DR_YES;
    1: MessageBoxButtonResult := DR_NO;
    2: MessageBoxButtonResult := DR_CANCEL;
   End;
 End;
End;

{ --- Initialiser une boite de message --- }

Procedure InitMessageBox(Var MB: TMessageBoxDlg; T, Txt: String;
 Btns: TMessageButtons; Ico: TMessageIcon);
Begin
 InitDialog(MB.Base, T, DLG_MSG_WIDTH, DLG_MSG_HEIGHT);
 MB.Text := Txt;
 MB.Buttons := Btns;
 MB.Icon := Ico;
 MB.FocusBtn := 0;
 If Btns = MB_OK Then
  MB.Base.HasCancel := False
 Else
  MB.Base.HasCancel := True;
End;

{ --- Dessiner l icone de la boite de message --- }

Procedure DrawMessageIcon(Var MB: TMessageBoxDlg);
Var
 IX, IY, CX, CY, R: Integer;
Begin
 IX := MB.Base.X + DLG_PADDING;
 IY := MB.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 CX := IX + DLG_ICON_SIZE Div 2;
 CY := IY + DLG_ICON_SIZE Div 2;
 R := DLG_ICON_SIZE Div 2;
 Case MB.Icon Of
  MI_INFO: Begin
   SetColor(CLR_TITLEBAR_ACTIVE);
   Circle(CX, CY, R);
   OutTextXY(CX - 2, CY - 4, 'i');
  End;
  MI_WARNING: Begin
   SetColor(14);
   Line(CX, IY, IX, IY + DLG_ICON_SIZE);
   Line(CX, IY, IX + DLG_ICON_SIZE, IY + DLG_ICON_SIZE);
   Line(IX, IY + DLG_ICON_SIZE, IX + DLG_ICON_SIZE, IY + DLG_ICON_SIZE);
   SetColor(0);
   OutTextXY(CX - 2, CY - 2, '!');
  End;
  MI_ERROR: Begin
   SetColor(4);
   Circle(CX, CY, R);
   OutTextXY(CX - 2, CY - 4, 'X');
  End;
  MI_QUESTION: Begin
   SetColor(CLR_TITLEBAR_ACTIVE);
   Circle(CX, CY, R);
   OutTextXY(CX - 2, CY - 4, '?');
  End;
 End;
End;

{ --- Dessiner le texte de la boite de message --- }

Procedure DrawMessageText(Var MB: TMessageBoxDlg);
Var
 TX, TY: Integer;
Begin
 TX := MB.Base.X + DLG_PADDING + DLG_ICON_SIZE + DLG_PADDING;
 TY := MB.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 SetColor(CLR_MENU_TEXT);
 OutTextXY(TX, TY, MB.Text);
End;

{ --- Dessiner la boite de message complete --- }

Procedure DrawMessageBox(Var MB: TMessageBoxDlg);
Var
 I, Cnt, TotalW, BX, BY: Integer;
Begin
 If Not MB.Base.Visible Then Exit;
 DrawDialogFrame(MB.Base);
 DrawMessageIcon(MB);
 DrawMessageText(MB);
 { Dessiner les boutons specifiques }
 Cnt := MessageBoxButtonCount(MB.Buttons);
 TotalW := Cnt * DLG_BUTTON_WIDTH + (Cnt - 1) * DLG_BUTTON_SPACING;
 BX := MB.Base.X + (MB.Base.Width - TotalW) Div 2;
 BY := MB.Base.Y + MB.Base.Height - DLG_PADDING - DLG_BUTTON_HEIGHT;
 For I := 0 To Cnt - 1 Do
  DrawDialogButton(
   BX + I * (DLG_BUTTON_WIDTH + DLG_BUTTON_SPACING), BY,
   MessageBoxButtonLabel(MB.Buttons, I),
   I = MB.FocusBtn);
End;

{ --- Gerer un evenement dans la boite de message --- }

Procedure HandleMessageBoxEvent(Var MB: TMessageBoxDlg;
 Var Ev: TEvent);
Var
 Cnt, I, BX, BY, TotalW, X1, X2, Y1, Y2: Integer;
Begin
 If Not MB.Base.Visible Then Exit;
 Cnt := MessageBoxButtonCount(MB.Buttons);
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  If Not IsInsideDialog(MB.Base, Ev.MouseX, Ev.MouseY) Then Exit;
  TotalW := Cnt * DLG_BUTTON_WIDTH + (Cnt - 1) * DLG_BUTTON_SPACING;
  BX := MB.Base.X + (MB.Base.Width - TotalW) Div 2;
  BY := MB.Base.Y + MB.Base.Height - DLG_PADDING - DLG_BUTTON_HEIGHT;
  For I := 0 To Cnt - 1 Do Begin
   X1 := BX + I * (DLG_BUTTON_WIDTH + DLG_BUTTON_SPACING);
   X2 := X1 + DLG_BUTTON_WIDTH - 1;
   Y1 := BY;
   Y2 := BY + DLG_BUTTON_HEIGHT - 1;
   If (Ev.MouseX >= X1) And (Ev.MouseX <= X2) And
    (Ev.MouseY >= Y1) And (Ev.MouseY <= Y2) Then Begin
    MB.Base.Result := MessageBoxButtonResult(MB.Buttons, I);
    CloseDialog(MB.Base);
    Exit;
   End;
  End;
 End Else If Ev.Kind = EV_KEY_CHAR Then Begin
  If Ev.KeyChar = #13 Then Begin
   MB.Base.Result := MessageBoxButtonResult(MB.Buttons, MB.FocusBtn);
   CloseDialog(MB.Base);
  End Else If Ev.KeyChar = #27 Then Begin
   MB.Base.Result := DR_CANCEL;
   CloseDialog(MB.Base);
  End Else If Ev.KeyChar = #9 Then Begin
   MB.FocusBtn := (MB.FocusBtn + 1) Mod Cnt;
  End;
 End Else If Ev.Kind = EV_KEY_DOWN Then Begin
  If Ev.KeyCode = $4B00 Then Begin { Fleche gauche }
   If MB.FocusBtn > 0 Then
    Dec(MB.FocusBtn);
  End Else If Ev.KeyCode = $4D00 Then Begin { Fleche droite }
   If MB.FocusBtn < Cnt - 1 Then
    Inc(MB.FocusBtn);
  End;
 End;
End;

{ --- Afficher une boite de message (modale) --- }
{ Note : boucle modale simplifiee, a completer dans un TODO futur }

Function ShowMessageBox(Title, Text: String; Buttons: TMessageButtons;
 Icon: TMessageIcon): Integer;
Var
 MB: TMessageBoxDlg;
Begin
 InitMessageBox(MB, Title, Text, Buttons, Icon);
 DrawMessageBox(MB);
 { Boucle modale a implementer dans un TODO futur }
 ShowMessageBox := DR_OK;
End;

{ --- Initialiser une boite de saisie --- }

Procedure InitInputBox(Var IB: TInputBox; T, Prompt, Default: String);
Begin
 InitDialog(IB.Base, T, DLG_INPUT_WIDTH, DLG_INPBOX_HEIGHT);
 IB.Base.HasCancel := True;
 IB.Prompt := Prompt;
 IB.InputText := Default;
 IB.InputCursor := Length(Default);
 IB.Cancelled := False;
End;

{ --- Dessiner le champ de saisie de la boite de saisie --- }

Procedure DrawInputField(Var IB: TInputBox);
Var
 IX, IY, IW: Integer;
Begin
 IX := IB.Base.X + DLG_PADDING;
 IY := IB.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING + 20;
 IW := IB.Base.Width - 2 * DLG_PADDING;
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(IX, IY, IX + IW - 1, IY + DLG_INPUT_HEIGHT - 1);
 SetColor(CLR_BORDER);
 Rectangle(IX, IY, IX + IW - 1, IY + DLG_INPUT_HEIGHT - 1);
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(IX + 4, IY + 3, IB.InputText);
 { Curseur }
 SetColor(CLR_CURSOR);
 Line(IX + 4 + TextWidth(Copy(IB.InputText, 1, IB.InputCursor)),
  IY + 2,
  IX + 4 + TextWidth(Copy(IB.InputText, 1, IB.InputCursor)),
  IY + DLG_INPUT_HEIGHT - 3);
End;

{ --- Dessiner la boite de saisie complete --- }

Procedure DrawInputBox(Var IB: TInputBox);
Begin
 If Not IB.Base.Visible Then Exit;
 DrawDialogFrame(IB.Base);
 { Invite }
 SetColor(CLR_MENU_TEXT);
 OutTextXY(IB.Base.X + DLG_PADDING,
  IB.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING, IB.Prompt);
 DrawInputField(IB);
 DrawDialogButtons(IB.Base);
End;

{ --- Gerer une touche clavier dans la boite de saisie --- }

Procedure HandleInputBoxKey(Var IB: TInputBox; Key: Char);
Begin
 If Key = #13 Then Begin
  IB.Cancelled := False;
  IB.Base.Result := DR_OK;
  CloseDialog(IB.Base);
 End Else If Key = #27 Then Begin
  IB.Cancelled := True;
  IB.Base.Result := DR_CANCEL;
  CloseDialog(IB.Base);
 End Else If Key = #8 Then Begin
  If (IB.InputCursor > 0) And (Length(IB.InputText) > 0) Then Begin
   Delete(IB.InputText, IB.InputCursor, 1);
   Dec(IB.InputCursor);
  End;
 End Else If (Key >= ' ') And (Key <= '~') Then Begin
  If Length(IB.InputText) < 255 Then Begin
   Inc(IB.InputCursor);
   Insert(Key, IB.InputText, IB.InputCursor);
  End;
 End;
End;

{ --- Gerer un evenement dans la boite de saisie --- }

Procedure HandleInputBoxEvent(Var IB: TInputBox; Var Ev: TEvent);
Var
 Idx: Integer;
Begin
 If Not IB.Base.Visible Then Exit;
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  If Not IsInsideDialog(IB.Base, Ev.MouseX, Ev.MouseY) Then Exit;
  Idx := DialogButtonHitTest(IB.Base, Ev.MouseX, Ev.MouseY);
  If Idx = 0 Then Begin
   IB.Cancelled := False;
   IB.Base.Result := DR_OK;
   CloseDialog(IB.Base);
  End Else If Idx = 1 Then Begin
   IB.Cancelled := True;
   IB.Base.Result := DR_CANCEL;
   CloseDialog(IB.Base);
  End;
 End Else If Ev.Kind = EV_KEY_CHAR Then
  HandleInputBoxKey(IB, Ev.KeyChar);
End;

{ --- Afficher une boite de saisie (modale) --- }
{ Note : boucle modale simplifiee, a completer dans un TODO futur }

Function ShowInputBox(Title, Prompt, Default: String): String;
Var
 IB: TInputBox;
Begin
 InitInputBox(IB, Title, Prompt, Default);
 DrawInputBox(IB);
 { Boucle modale a implementer dans un TODO futur }
 ShowInputBox := '';
End;

{ --- Obtenir le resultat d un dialogue --- }

Function GetDialogResult(Var Dlg: TDialog): Integer;
Begin
 GetDialogResult := Dlg.Result;
End;

{ --- Verifier si un dialogue est visible --- }

Function IsDialogVisible(Var Dlg: TDialog): Boolean;
Begin
 IsDialogVisible := Dlg.Visible;
End;

{ --- Obtenir le titre d un dialogue --- }

Function GetDialogTitle(Var Dlg: TDialog): String;
Begin
 GetDialogTitle := Dlg.Title;
End;

{ --- Obtenir la largeur d un dialogue --- }

Function GetDialogWidth(Var Dlg: TDialog): Integer;
Begin
 GetDialogWidth := Dlg.Width;
End;

{ --- Obtenir la hauteur d un dialogue --- }

Function GetDialogHeight(Var Dlg: TDialog): Integer;
Begin
 GetDialogHeight := Dlg.Height;
End;

{ --- Obtenir le chemin courant du dialogue fichier --- }

Function GetFileDialogPath(Var FD: TFileDialog): String;
Begin
 GetFileDialogPath := FD.CurrentPath;
End;

{ --- Obtenir le fichier selectionne --- }

Function GetFileDialogSelection(Var FD: TFileDialog): String;
Begin
 GetFileDialogSelection := FD.SelectedFile;
End;

{ --- Obtenir le nombre de filtres du dialogue fichier --- }

Function GetFileDialogFilterCount(Var FD: TFileDialog): Integer;
Begin
 GetFileDialogFilterCount := FD.FilterCount;
End;

{ --- Obtenir l index du filtre actif --- }

Function GetFileDialogFilterIndex(Var FD: TFileDialog): Integer;
Begin
 GetFileDialogFilterIndex := FD.FilterIndex;
End;

{ --- Definir l index du filtre actif --- }

Procedure SetFileDialogFilterIndex(Var FD: TFileDialog; Idx: Integer);
Begin
 If (Idx >= 0) And (Idx < FD.FilterCount) Then
  FD.FilterIndex := Idx;
End;

{ --- Obtenir le chemin courant du dialogue dossier --- }

Function GetFolderDialogPath(Var FD: TFolderDialog): String;
Begin
 GetFolderDialogPath := FD.CurrentPath;
End;

{ --- Obtenir le dossier selectionne --- }

Function GetFolderDialogSelection(Var FD: TFolderDialog): String;
Begin
 GetFolderDialogSelection := FD.SelectedFolder;
End;

{ --- Obtenir le texte saisi dans la boite de saisie --- }

Function GetInputBoxText(Var IB: TInputBox): String;
Begin
 GetInputBoxText := IB.InputText;
End;

{ --- Verifier si la boite de saisie a ete annulee --- }

Function IsInputBoxCancelled(Var IB: TInputBox): Boolean;
Begin
 IsInputBoxCancelled := IB.Cancelled;
End;

{ --- Obtenir le bouton avec le focus dans la boite de message --- }

Function GetMessageBoxFocusButton(Var MB: TMessageBoxDlg): Integer;
Begin
 GetMessageBoxFocusButton := MB.FocusBtn;
End;

{ --- Definir le bouton avec le focus dans la boite de message --- }

Procedure SetMessageBoxFocusButton(Var MB: TMessageBoxDlg;
 Idx: Integer);
Var
 Cnt: Integer;
Begin
 Cnt := MessageBoxButtonCount(MB.Buttons);
 If (Idx >= 0) And (Idx < Cnt) Then
  MB.FocusBtn := Idx;
End;

{ --- Nom de l icone de message --- }

Function IconName(Ico: TMessageIcon): String;
Begin
 Case Ico Of
  MI_INFO:     IconName := 'Information';
  MI_WARNING:  IconName := 'Avertissement';
  MI_ERROR:    IconName := 'Erreur';
  MI_QUESTION: IconName := 'Question';
 Else
  IconName := 'Inconnu';
 End;
End;

{ --- Nom du type de boutons --- }

Function ButtonsName(Btns: TMessageButtons): String;
Begin
 Case Btns Of
  MB_OK:          ButtonsName := 'OK';
  MB_OKCANCEL:    ButtonsName := 'OK/Annuler';
  MB_YESNO:       ButtonsName := 'Oui/Non';
  MB_YESNOCANCEL: ButtonsName := 'Oui/Non/Annuler';
 Else
  ButtonsName := 'Inconnu';
 End;
End;

{ --- Nom d un resultat de dialogue --- }

Function DialogResultName(R: Integer): String;
Begin
 Case R Of
  DR_OK:     DialogResultName := 'OK';
  DR_CANCEL: DialogResultName := 'Annuler';
  DR_YES:    DialogResultName := 'Oui';
  DR_NO:     DialogResultName := 'Non';
  DR_NONE:   DialogResultName := 'Aucun';
 Else
  DialogResultName := 'Inconnu';
 End;
End;

{ --- Fonctions graphiques helper pour dialogues --- }

Procedure DrawFilledRect(X1, Y1, X2, Y2: Integer; Color: LongInt);
Begin
 SetFillStyle(SolidFill, Color);
 Bar(X1, Y1, X2, Y2);
End;

Procedure DrawRect(X1, Y1, X2, Y2: Integer; Color: LongInt);
Begin
 SetColor(Color);
 Rectangle(X1, Y1, X2, Y2);
End;

Procedure DrawText(X, Y: Integer; S: String; Color: LongInt);
Begin
 SetColor(Color);
 OutTextXY(X, Y, S);
End;

{ ============================================================
  TODO 22 - BOITES DE DIALOGUE : PROJET ET SOLUTION [IMPLEMENTE]
  ============================================================ }

{ --- Nom d un type de nouveau projet --- }

Function NewProjectTypeName(T: Integer): String;
Begin
 Case T Of
  0: NewProjectTypeName := 'Application console C#';
  1: NewProjectTypeName := 'Application console VB.NET';
  2: NewProjectTypeName := 'Application console Pascal';
  3: NewProjectTypeName := 'Bibliotheque de classes C#';
  4: NewProjectTypeName := 'Bibliotheque de classes VB.NET';
 Else
  NewProjectTypeName := 'Inconnu';
 End;
End;

{ --- Extension associee a un type de projet --- }

Function NewProjectTypeExtension(T: Integer): String;
Begin
 Case T Of
  0: NewProjectTypeExtension := '.csproj';
  1: NewProjectTypeExtension := '.vbproj';
  2: NewProjectTypeExtension := '.pasproj';
  3: NewProjectTypeExtension := '.csproj';
  4: NewProjectTypeExtension := '.vbproj';
 Else
  NewProjectTypeExtension := '';
 End;
End;

{ --- Type de projet associe a un index --- }

Function NewProjectTypeToProjectType(T: Integer): TProjectType;
Begin
 Case T Of
  0: NewProjectTypeToProjectType := PT_CSHARP;
  1: NewProjectTypeToProjectType := PT_VBNET;
  2: NewProjectTypeToProjectType := PT_PASCAL;
  3: NewProjectTypeToProjectType := PT_CSHARP;
  4: NewProjectTypeToProjectType := PT_VBNET;
 Else
  NewProjectTypeToProjectType := PT_UNKNOWN;
 End;
End;

{ --- Type de sortie associe a un index de type de projet --- }

Function NewProjectTypeToOutputType(T: Integer): TOutputType;
Begin
 Case T Of
  0: NewProjectTypeToOutputType := OT_EXE;
  1: NewProjectTypeToOutputType := OT_EXE;
  2: NewProjectTypeToOutputType := OT_EXE;
  3: NewProjectTypeToOutputType := OT_LIBRARY;
  4: NewProjectTypeToOutputType := OT_LIBRARY;
 Else
  NewProjectTypeToOutputType := OT_EXE;
 End;
End;

{ --- Nom d un type de nouveau fichier --- }

Function NewFileTypeName(T: Integer): String;
Begin
 Case T Of
  0: NewFileTypeName := 'Classe C# (.cs)';
  1: NewFileTypeName := 'Module VB.NET (.vb)';
  2: NewFileTypeName := 'Unite Pascal (.pas)';
  3: NewFileTypeName := 'Fichier texte (.txt)';
  4: NewFileTypeName := 'Fichier XML (.xml)';
 Else
  NewFileTypeName := 'Inconnu';
 End;
End;

{ --- Extension associee a un type de fichier --- }

Function NewFileTypeExtension(T: Integer): String;
Begin
 Case T Of
  0: NewFileTypeExtension := '.cs';
  1: NewFileTypeExtension := '.vb';
  2: NewFileTypeExtension := '.pas';
  3: NewFileTypeExtension := '.txt';
  4: NewFileTypeExtension := '.xml';
 Else
  NewFileTypeExtension := '';
 End;
End;

{ --- Nom d un onglet de reference --- }

Function RefTabName(Tab: TRefTabKind): String;
Begin
 Case Tab Of
  RTK_ASSEMBLIES: RefTabName := 'Assemblies';
  RTK_PROJECTS:   RefTabName := 'Projets';
  RTK_BROWSE:     RefTabName := 'Parcourir';
 Else
  RefTabName := '';
 End;
End;

{ --- Nom d un onglet de proprietes projet --- }

Function ProjPropTabName(Tab: TProjPropTab): String;
Begin
 Case Tab Of
  PPT_APPLICATION:  ProjPropTabName := 'Application';
  PPT_BUILD:        ProjPropTabName := 'Build';
  PPT_BUILD_EVENTS: ProjPropTabName := 'Build Events';
  PPT_DEBUG:        ProjPropTabName := 'Debug';
 Else
  ProjPropTabName := '';
 End;
End;

{ --- Initialiser le dialogue Nouveau projet --- }

Procedure InitNewProjectDialog(Var Dlg: TNewProjectDialog);
Var
 ScrW, ScrH: Integer;
Begin
 InitDialog(Dlg.Base, 'Nouveau projet', NEWPROJ_WIDTH,
  NEWPROJ_HEIGHT);
 Dlg.Base.HasCancel := True;
 Dlg.SelType := 0;
 Dlg.ProjectName := 'MonProjet';
 Dlg.Location := '.';
 Dlg.SolutionName := 'MaSolution';
 Dlg.CreateSolDir := True;
 Dlg.ProjNameCursor := Length(Dlg.ProjectName);
 Dlg.LocCursor := Length(Dlg.Location);
 Dlg.SolNameCursor := Length(Dlg.SolutionName);
 Dlg.FocusField := 0;
 Dlg.ScrollTop := 0;
 Dlg.Confirmed := False;
End;

{ --- Dessiner la liste des types de projet --- }

Procedure DrawNewProjectTypeList(Var Dlg: TNewProjectDialog);
Var
 I: Integer;
 LX, LY, LW, LH: Integer;
 RH: Integer;
 Bg, Fg: LongInt;
Begin
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := Dlg.Base.Width - DLG_PADDING * 2;
 LH := NEWPROJ_LIST_HEIGHT;
 RH := DLG_LIST_ROW_HEIGHT;
 DrawFilledRect(LX, LY, LX + LW, LY + LH, CLR_WINDOW);
 DrawRect(LX, LY, LX + LW, LY + LH, CLR_BORDER);
 For I := 0 To NEWPROJ_TYPE_COUNT - 1 Do
 Begin
  If I = Dlg.SelType Then
  Begin
   Bg := CLR_HIGHLIGHT;
   Fg := CLR_HIGHLIGHTTEXT;
   DrawFilledRect(LX + 1, LY + 1 + I * RH,
    LX + LW - 1, LY + 1 + (I + 1) * RH, Bg);
  End
  Else
  Begin
   Bg := CLR_WINDOW;
   Fg := CLR_WINDOWTEXT;
  End;
  DrawText(LX + 4, LY + 2 + I * RH, NewProjectTypeName(I), Fg);
 End;
End;

{ --- Dessiner les champs de saisie du dialogue Nouveau projet --- }

Procedure DrawNewProjectFields(Var Dlg: TNewProjectDialog);
Var
 FX, FY, FW: Integer;
 BaseY: Integer;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 FW := Dlg.Base.Width - DLG_PADDING * 2;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  NEWPROJ_LIST_HEIGHT + DLG_PADDING;
 { Etiquette et champ Nom du projet }
 DrawText(FX, BaseY, 'Nom :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + 80, BaseY - 2, FX + FW, BaseY + DLG_INPUT_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + 80, BaseY - 2, FX + FW, BaseY + DLG_INPUT_HEIGHT,
  CLR_BORDER);
 DrawText(FX + 84, BaseY, Dlg.ProjectName, CLR_WINDOWTEXT);
 { Etiquette et champ Emplacement }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Emplacement :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + 80, BaseY - 2, FX + FW, BaseY + DLG_INPUT_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + 80, BaseY - 2, FX + FW, BaseY + DLG_INPUT_HEIGHT,
  CLR_BORDER);
 DrawText(FX + 84, BaseY, Dlg.Location, CLR_WINDOWTEXT);
 { Etiquette et champ Nom de la solution }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Solution :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + 80, BaseY - 2, FX + FW, BaseY + DLG_INPUT_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + 80, BaseY - 2, FX + FW, BaseY + DLG_INPUT_HEIGHT,
  CLR_BORDER);
 DrawText(FX + 84, BaseY, Dlg.SolutionName, CLR_WINDOWTEXT);
 { Case a cocher Creer un repertoire pour la solution }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawRect(FX, BaseY, FX + 12, BaseY + 12, CLR_BORDER);
 If Dlg.CreateSolDir Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + 18, BaseY,
  'Creer un repertoire pour la solution', CLR_WINDOWTEXT);
End;

{ --- Dessiner le dialogue Nouveau projet --- }

Procedure DrawNewProjectDialog(Var Dlg: TNewProjectDialog);
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 DrawNewProjectTypeList(Dlg);
 DrawNewProjectFields(Dlg);
 DrawDialogButtons(Dlg.Base);
End;

{ --- Test de clic sur la liste des types (nouveau projet) --- }

Function NewProjectTypeHitTest(Var Dlg: TNewProjectDialog;
 MX, MY: Integer): Integer;
Var
 LX, LY, LW, RH, I: Integer;
Begin
 NewProjectTypeHitTest := -1;
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := Dlg.Base.Width - DLG_PADDING * 2;
 RH := DLG_LIST_ROW_HEIGHT;
 If (MX >= LX) And (MX < LX + LW) And (MY >= LY) And
  (MY < LY + NEWPROJ_LIST_HEIGHT) Then
 Begin
  I := (MY - LY) Div RH;
  If (I >= 0) And (I < NEWPROJ_TYPE_COUNT) Then
   NewProjectTypeHitTest := I;
 End;
End;

{ --- Test de clic sur le checkbox CreateSolDir --- }

Function NewProjectCheckboxHitTest(Var Dlg: TNewProjectDialog;
 MX, MY: Integer): Boolean;
Var
 FX, BaseY: Integer;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  NEWPROJ_LIST_HEIGHT + DLG_PADDING + PROJPROP_ROW_SPACING * 3;
 NewProjectCheckboxHitTest :=
  (MX >= FX) And (MX <= FX + 12) And
  (MY >= BaseY) And (MY <= BaseY + 12);
End;

{ --- Gestion des touches du dialogue Nouveau projet --- }

Procedure HandleNewProjectDialogKey(Var Dlg: TNewProjectDialog;
 Key: Word; Ch: Char);
Begin
 If Key = $1B Then { Escape }
 Begin
  Dlg.Confirmed := False;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $0D Then { Entree }
 Begin
  Dlg.Confirmed := True;
  Dlg.Base.Result := DR_OK;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $09 Then { Tab }
 Begin
  Dlg.FocusField := (Dlg.FocusField + 1) Mod 4;
  Exit;
 End;
 { Saisie dans le champ actif }
 Case Dlg.FocusField Of
  0: { Nom du projet }
   If (Ch >= ' ') And (Length(Dlg.ProjectName) < 63) Then
   Begin
    Dlg.ProjectName := Dlg.ProjectName + Ch;
    Inc(Dlg.ProjNameCursor);
   End
   Else If Key = $08 Then { Backspace }
   Begin
    If Length(Dlg.ProjectName) > 0 Then
    Begin
     Delete(Dlg.ProjectName, Length(Dlg.ProjectName), 1);
     Dec(Dlg.ProjNameCursor);
    End;
   End;
  1: { Emplacement }
   If (Ch >= ' ') And (Length(Dlg.Location) < 255) Then
   Begin
    Dlg.Location := Dlg.Location + Ch;
    Inc(Dlg.LocCursor);
   End
   Else If Key = $08 Then
   Begin
    If Length(Dlg.Location) > 0 Then
    Begin
     Delete(Dlg.Location, Length(Dlg.Location), 1);
     Dec(Dlg.LocCursor);
    End;
   End;
  2: { Nom de la solution }
   If (Ch >= ' ') And (Length(Dlg.SolutionName) < 63) Then
   Begin
    Dlg.SolutionName := Dlg.SolutionName + Ch;
    Inc(Dlg.SolNameCursor);
   End
   Else If Key = $08 Then
   Begin
    If Length(Dlg.SolutionName) > 0 Then
    Begin
     Delete(Dlg.SolutionName, Length(Dlg.SolutionName), 1);
     Dec(Dlg.SolNameCursor);
    End;
   End;
 End;
End;

{ --- Gestion des evenements du dialogue Nouveau projet --- }

Procedure HandleNewProjectDialogEvent(Var Dlg: TNewProjectDialog;
 Var Ev: TEvent);
Var
 Idx, BtnR: Integer;
Begin
 If Not Dlg.Base.Visible Then Exit;
 Case Ev.Kind Of
  EV_KEY_DOWN, EV_KEY_CHAR:
   HandleNewProjectDialogKey(Dlg, Ev.KeyCode, Ev.KeyChar);
  EV_MOUSE_DOWN:
  Begin
   Idx := NewProjectTypeHitTest(Dlg, Ev.MouseX, Ev.MouseY);
   If Idx >= 0 Then
   Begin
    Dlg.SelType := Idx;
    DrawNewProjectDialog(Dlg);
    Exit;
   End;
   If NewProjectCheckboxHitTest(Dlg, Ev.MouseX, Ev.MouseY) Then
   Begin
    Dlg.CreateSolDir := Not Dlg.CreateSolDir;
    DrawNewProjectDialog(Dlg);
    Exit;
   End;
   BtnR := DialogButtonHitTest(Dlg.Base, Ev.MouseX, Ev.MouseY);
   If BtnR <> DR_NONE Then
   Begin
    If BtnR = DR_OK Then
     Dlg.Confirmed := True
    Else
     Dlg.Confirmed := False;
    Dlg.Base.Result := BtnR;
    CloseDialog(Dlg.Base);
   End;
  End;
 End;
End;

{ --- Afficher le dialogue Nouveau projet --- }

Procedure ShowNewProjectDialog(Var Dlg: TNewProjectDialog);
Begin
 InitNewProjectDialog(Dlg);
 Dlg.Base.Visible := True;
 DrawNewProjectDialog(Dlg);
End;

{ --- Initialiser le dialogue Nouveau fichier --- }

Procedure InitNewFileDialog(Var Dlg: TNewFileDialog);
Begin
 InitDialog(Dlg.Base, 'Ajouter un nouveau fichier', NEWFILE_WIDTH,
  NEWFILE_HEIGHT);
 Dlg.Base.HasCancel := True;
 Dlg.SelType := 0;
 Dlg.FileName := 'NouveauFichier';
 Dlg.FileNameCursor := Length(Dlg.FileName);
 Dlg.ScrollTop := 0;
 Dlg.Confirmed := False;
End;

{ --- Dessiner la liste des types de fichier --- }

Procedure DrawNewFileTypeList(Var Dlg: TNewFileDialog);
Var
 I: Integer;
 LX, LY, LW, LH: Integer;
 RH: Integer;
 Bg, Fg: LongInt;
Begin
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := Dlg.Base.Width - DLG_PADDING * 2;
 LH := NEWFILE_LIST_HEIGHT;
 RH := DLG_LIST_ROW_HEIGHT;
 DrawFilledRect(LX, LY, LX + LW, LY + LH, CLR_WINDOW);
 DrawRect(LX, LY, LX + LW, LY + LH, CLR_BORDER);
 For I := 0 To NEWFILE_TYPE_COUNT - 1 Do
 Begin
  If I = Dlg.SelType Then
  Begin
   Bg := CLR_HIGHLIGHT;
   Fg := CLR_HIGHLIGHTTEXT;
   DrawFilledRect(LX + 1, LY + 1 + I * RH,
    LX + LW - 1, LY + 1 + (I + 1) * RH, Bg);
  End
  Else
  Begin
   Bg := CLR_WINDOW;
   Fg := CLR_WINDOWTEXT;
  End;
  DrawText(LX + 4, LY + 2 + I * RH, NewFileTypeName(I), Fg);
 End;
End;

{ --- Dessiner le champ de saisie du nom de fichier --- }

Procedure DrawNewFileNameField(Var Dlg: TNewFileDialog);
Var
 FX, FY, FW: Integer;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 FW := Dlg.Base.Width - DLG_PADDING * 2;
 FY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  NEWFILE_LIST_HEIGHT + DLG_PADDING;
 DrawText(FX, FY, 'Nom :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + 80, FY - 2, FX + FW, FY + DLG_INPUT_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + 80, FY - 2, FX + FW, FY + DLG_INPUT_HEIGHT,
  CLR_BORDER);
 DrawText(FX + 84, FY, Dlg.FileName, CLR_WINDOWTEXT);
End;

{ --- Dessiner le dialogue Nouveau fichier --- }

Procedure DrawNewFileDialog(Var Dlg: TNewFileDialog);
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 DrawNewFileTypeList(Dlg);
 DrawNewFileNameField(Dlg);
 DrawDialogButtons(Dlg.Base);
End;

{ --- Test de clic sur la liste des types (nouveau fichier) --- }

Function NewFileTypeHitTest(Var Dlg: TNewFileDialog;
 MX, MY: Integer): Integer;
Var
 LX, LY, LW, RH, I: Integer;
Begin
 NewFileTypeHitTest := -1;
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 LW := Dlg.Base.Width - DLG_PADDING * 2;
 RH := DLG_LIST_ROW_HEIGHT;
 If (MX >= LX) And (MX < LX + LW) And (MY >= LY) And
  (MY < LY + NEWFILE_LIST_HEIGHT) Then
 Begin
  I := (MY - LY) Div RH;
  If (I >= 0) And (I < NEWFILE_TYPE_COUNT) Then
   NewFileTypeHitTest := I;
 End;
End;

{ --- Gestion des touches du dialogue Nouveau fichier --- }

Procedure HandleNewFileDialogKey(Var Dlg: TNewFileDialog;
 Key: Word; Ch: Char);
Begin
 If Key = $1B Then
 Begin
  Dlg.Confirmed := False;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $0D Then
 Begin
  Dlg.Confirmed := True;
  Dlg.Base.Result := DR_OK;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If (Ch >= ' ') And (Length(Dlg.FileName) < 127) Then
 Begin
  Dlg.FileName := Dlg.FileName + Ch;
  Inc(Dlg.FileNameCursor);
 End
 Else If Key = $08 Then
 Begin
  If Length(Dlg.FileName) > 0 Then
  Begin
   Delete(Dlg.FileName, Length(Dlg.FileName), 1);
   Dec(Dlg.FileNameCursor);
  End;
 End;
End;

{ --- Gestion des evenements du dialogue Nouveau fichier --- }

Procedure HandleNewFileDialogEvent(Var Dlg: TNewFileDialog;
 Var Ev: TEvent);
Var
 Idx, BtnR: Integer;
Begin
 If Not Dlg.Base.Visible Then Exit;
 Case Ev.Kind Of
  EV_KEY_DOWN, EV_KEY_CHAR:
   HandleNewFileDialogKey(Dlg, Ev.KeyCode, Ev.KeyChar);
  EV_MOUSE_DOWN:
  Begin
   Idx := NewFileTypeHitTest(Dlg, Ev.MouseX, Ev.MouseY);
   If Idx >= 0 Then
   Begin
    Dlg.SelType := Idx;
    DrawNewFileDialog(Dlg);
    Exit;
   End;
   BtnR := DialogButtonHitTest(Dlg.Base, Ev.MouseX, Ev.MouseY);
   If BtnR <> DR_NONE Then
   Begin
    If BtnR = DR_OK Then
     Dlg.Confirmed := True
    Else
     Dlg.Confirmed := False;
    Dlg.Base.Result := BtnR;
    CloseDialog(Dlg.Base);
   End;
  End;
 End;
End;

{ --- Afficher le dialogue Nouveau fichier --- }

Procedure ShowNewFileDialog(Var Dlg: TNewFileDialog);
Begin
 InitNewFileDialog(Dlg);
 Dlg.Base.Visible := True;
 DrawNewFileDialog(Dlg);
End;

{ --- Initialiser une entree de reference --- }

Procedure InitRefListEntry(Var E: TRefListEntry);
Begin
 E.Name := '';
 E.Version := '';
 E.Path := '';
 E.Checked := False;
 E.IsProject := False;
End;

{ --- Initialiser le dialogue Ajouter une reference --- }

Procedure InitAddReferenceDialog(Var Dlg: TAddReferenceDialog);
Var
 I: Integer;
Begin
 InitDialog(Dlg.Base, 'Ajouter une reference', ADDREF_WIDTH,
  ADDREF_HEIGHT);
 Dlg.Base.HasCancel := True;
 Dlg.ActiveTab := RTK_ASSEMBLIES;
 Dlg.ItemCount := 0;
 Dlg.SelIndex := -1;
 Dlg.ScrollTop := 0;
 Dlg.Confirmed := False;
 For I := 0 To MAX_ADDREF_ITEMS - 1 Do
  InitRefListEntry(Dlg.Items[I]);
End;

{ --- Ajouter un item de reference --- }

Procedure AddRefItem(Var Dlg: TAddReferenceDialog;
 AName, AVersion, APath: String; IsProj: Boolean);
Var
 Idx: Integer;
Begin
 If Dlg.ItemCount >= MAX_ADDREF_ITEMS Then Exit;
 Idx := Dlg.ItemCount;
 Dlg.Items[Idx].Name := AName;
 Dlg.Items[Idx].Version := AVersion;
 Dlg.Items[Idx].Path := APath;
 Dlg.Items[Idx].Checked := False;
 Dlg.Items[Idx].IsProject := IsProj;
 Inc(Dlg.ItemCount);
End;

{ --- Dessiner les onglets du dialogue reference --- }

Procedure DrawRefTabs(Var Dlg: TAddReferenceDialog);
Var
 TX, TY, TW, I: Integer;
 TabN: String;
 Bg, Fg: LongInt;
Begin
 TX := Dlg.Base.X + DLG_PADDING;
 TY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 TW := (Dlg.Base.Width - DLG_PADDING * 2) Div ADDREF_TAB_COUNT;
 For I := 0 To ADDREF_TAB_COUNT - 1 Do
 Begin
  Case I Of
   0: TabN := RefTabName(RTK_ASSEMBLIES);
   1: TabN := RefTabName(RTK_PROJECTS);
   2: TabN := RefTabName(RTK_BROWSE);
  Else
   TabN := '';
  End;
  If I = Ord(Dlg.ActiveTab) Then
  Begin
   Bg := CLR_WINDOW;
   Fg := CLR_WINDOWTEXT;
  End
  Else
  Begin
   Bg := CLR_BTNFACE;
   Fg := CLR_GRAYTEXT;
  End;
  DrawFilledRect(TX + I * TW, TY, TX + (I + 1) * TW, TY + TAB_HEIGHT,
   Bg);
  DrawRect(TX + I * TW, TY, TX + (I + 1) * TW, TY + TAB_HEIGHT,
   CLR_BORDER);
  DrawText(TX + I * TW + 8, TY + 3, TabN, Fg);
 End;
End;

{ --- Dessiner la liste des references --- }

Procedure DrawRefList(Var Dlg: TAddReferenceDialog);
Var
 I: Integer;
 LX, LY, LW, LH: Integer;
 RH, VisCount, Idx: Integer;
 Bg, Fg: LongInt;
Begin
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + 2;
 LW := Dlg.Base.Width - DLG_PADDING * 2;
 LH := Dlg.Base.Height - DLG_TITLE_HEIGHT - DLG_PADDING * 3 -
  TAB_HEIGHT - DLG_BUTTON_HEIGHT - 10;
 RH := DLG_LIST_ROW_HEIGHT;
 DrawFilledRect(LX, LY, LX + LW, LY + LH, CLR_WINDOW);
 DrawRect(LX, LY, LX + LW, LY + LH, CLR_BORDER);
 VisCount := LH Div RH;
 For I := 0 To VisCount - 1 Do
 Begin
  Idx := Dlg.ScrollTop + I;
  If Idx >= Dlg.ItemCount Then Break;
  If Idx = Dlg.SelIndex Then
  Begin
   Bg := CLR_HIGHLIGHT;
   Fg := CLR_HIGHLIGHTTEXT;
   DrawFilledRect(LX + 1, LY + 1 + I * RH,
    LX + LW - 1, LY + 1 + (I + 1) * RH, Bg);
  End
  Else
  Begin
   Bg := CLR_WINDOW;
   Fg := CLR_WINDOWTEXT;
  End;
  { Case a cocher }
  DrawRect(LX + 4, LY + 2 + I * RH, LX + 16,
   LY + 14 + I * RH, CLR_BORDER);
  If Dlg.Items[Idx].Checked Then
   DrawText(LX + 6, LY + 1 + I * RH, 'X', Fg);
  DrawText(LX + 22, LY + 2 + I * RH, Dlg.Items[Idx].Name, Fg);
  If Dlg.Items[Idx].Version <> '' Then
   DrawText(LX + 200, LY + 2 + I * RH,
    Dlg.Items[Idx].Version, Fg);
 End;
End;

{ --- Dessiner le dialogue Ajouter une reference --- }

Procedure DrawAddReferenceDialog(Var Dlg: TAddReferenceDialog);
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 DrawRefTabs(Dlg);
 DrawRefList(Dlg);
 DrawDialogButtons(Dlg.Base);
End;

{ --- Test de clic sur les onglets de reference --- }

Function RefTabHitTest(Var Dlg: TAddReferenceDialog;
 MX, MY: Integer): Integer;
Var
 TX, TY, TW, I: Integer;
Begin
 RefTabHitTest := -1;
 TX := Dlg.Base.X + DLG_PADDING;
 TY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 TW := (Dlg.Base.Width - DLG_PADDING * 2) Div ADDREF_TAB_COUNT;
 If (MY >= TY) And (MY < TY + TAB_HEIGHT) Then
 Begin
  For I := 0 To ADDREF_TAB_COUNT - 1 Do
  Begin
   If (MX >= TX + I * TW) And (MX < TX + (I + 1) * TW) Then
   Begin
    RefTabHitTest := I;
    Exit;
   End;
  End;
 End;
End;

{ --- Test de clic sur la liste de references --- }

Function RefListItemHitTest(Var Dlg: TAddReferenceDialog;
 MX, MY: Integer): Integer;
Var
 LX, LY, LW, LH, RH, I, Idx: Integer;
Begin
 RefListItemHitTest := -1;
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + 2;
 LW := Dlg.Base.Width - DLG_PADDING * 2;
 LH := Dlg.Base.Height - DLG_TITLE_HEIGHT - DLG_PADDING * 3 -
  TAB_HEIGHT - DLG_BUTTON_HEIGHT - 10;
 RH := DLG_LIST_ROW_HEIGHT;
 If (MX >= LX) And (MX < LX + LW) And
  (MY >= LY) And (MY < LY + LH) Then
 Begin
  I := (MY - LY) Div RH;
  Idx := Dlg.ScrollTop + I;
  If (Idx >= 0) And (Idx < Dlg.ItemCount) Then
   RefListItemHitTest := Idx;
 End;
End;

{ --- Test de clic sur la case a cocher d un item --- }

Function RefCheckboxHitTest(Var Dlg: TAddReferenceDialog;
 MX, MY: Integer): Integer;
Var
 LX, LY, RH, I, Idx: Integer;
Begin
 RefCheckboxHitTest := -1;
 LX := Dlg.Base.X + DLG_PADDING;
 LY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + 2;
 RH := DLG_LIST_ROW_HEIGHT;
 If (MX >= LX + 4) And (MX <= LX + 16) Then
 Begin
  I := (MY - LY) Div RH;
  Idx := Dlg.ScrollTop + I;
  If (Idx >= 0) And (Idx < Dlg.ItemCount) Then
   RefCheckboxHitTest := Idx;
 End;
End;

{ --- Gestion des evenements du dialogue Ajouter une reference --- }

Procedure HandleAddReferenceDialogEvent(Var Dlg: TAddReferenceDialog;
 Var Ev: TEvent);
Var
 TabIdx, ItemIdx, ChkIdx, BtnR: Integer;
Begin
 If Not Dlg.Base.Visible Then Exit;
 Case Ev.Kind Of
  EV_KEY_DOWN, EV_KEY_CHAR:
  Begin
   If Ev.KeyCode = $1B Then
   Begin
    Dlg.Confirmed := False;
    CloseDialog(Dlg.Base);
    Exit;
   End;
   If Ev.KeyCode = $0D Then
   Begin
    Dlg.Confirmed := True;
    Dlg.Base.Result := DR_OK;
    CloseDialog(Dlg.Base);
    Exit;
   End;
   If Ev.KeyCode = $4800 Then { Fleche haut }
   Begin
    If Dlg.SelIndex > 0 Then
     Dec(Dlg.SelIndex);
    DrawAddReferenceDialog(Dlg);
   End;
   If Ev.KeyCode = $5000 Then { Fleche bas }
   Begin
    If Dlg.SelIndex < Dlg.ItemCount - 1 Then
     Inc(Dlg.SelIndex);
    DrawAddReferenceDialog(Dlg);
   End;
   If Ev.KeyChar = ' ' Then { Espace = toggle check }
   Begin
    If (Dlg.SelIndex >= 0) And
     (Dlg.SelIndex < Dlg.ItemCount) Then
    Begin
     Dlg.Items[Dlg.SelIndex].Checked :=
      Not Dlg.Items[Dlg.SelIndex].Checked;
     DrawAddReferenceDialog(Dlg);
    End;
   End;
  End;
  EV_MOUSE_DOWN:
  Begin
   TabIdx := RefTabHitTest(Dlg, Ev.MouseX, Ev.MouseY);
   If TabIdx >= 0 Then
   Begin
    Case TabIdx Of
     0: Dlg.ActiveTab := RTK_ASSEMBLIES;
     1: Dlg.ActiveTab := RTK_PROJECTS;
     2: Dlg.ActiveTab := RTK_BROWSE;
    End;
    DrawAddReferenceDialog(Dlg);
    Exit;
   End;
   ChkIdx := RefCheckboxHitTest(Dlg, Ev.MouseX, Ev.MouseY);
   If ChkIdx >= 0 Then
   Begin
    Dlg.Items[ChkIdx].Checked :=
     Not Dlg.Items[ChkIdx].Checked;
    DrawAddReferenceDialog(Dlg);
    Exit;
   End;
   ItemIdx := RefListItemHitTest(Dlg, Ev.MouseX, Ev.MouseY);
   If ItemIdx >= 0 Then
   Begin
    Dlg.SelIndex := ItemIdx;
    DrawAddReferenceDialog(Dlg);
    Exit;
   End;
   BtnR := DialogButtonHitTest(Dlg.Base, Ev.MouseX, Ev.MouseY);
   If BtnR <> DR_NONE Then
   Begin
    If BtnR = DR_OK Then
     Dlg.Confirmed := True
    Else
     Dlg.Confirmed := False;
    Dlg.Base.Result := BtnR;
    CloseDialog(Dlg.Base);
   End;
  End;
 End;
End;

{ --- Afficher le dialogue Ajouter une reference --- }

Procedure ShowAddReferenceDialog(Var Dlg: TAddReferenceDialog);
Begin
 InitAddReferenceDialog(Dlg);
 Dlg.Base.Visible := True;
 DrawAddReferenceDialog(Dlg);
End;

{ --- Initialiser le dialogue Proprietes du projet --- }

Procedure InitProjectPropertiesDialog(
 Var Dlg: TProjectPropertiesDialog);
Begin
 InitDialog(Dlg.Base, 'Proprietes du projet', PROJPROP_WIDTH,
  PROJPROP_HEIGHT);
 Dlg.Base.HasCancel := True;
 Dlg.ActiveTab := PPT_APPLICATION;
 Dlg.AssemblyName := '';
 Dlg.RootNamespace := '';
 Dlg.OutputTypeIdx := 0;
 Dlg.DefineConstants := '';
 Dlg.OutputPath := 'bin\Debug\';
 Dlg.WarningLevel := 4;
 Dlg.TreatWarningsAsErrors := False;
 Dlg.PreBuildEvent := '';
 Dlg.PostBuildEvent := '';
 Dlg.DebugArgs := '';
 Dlg.WorkingDir := '';
 Dlg.FocusField := 0;
 Dlg.AsmNameCursor := 0;
 Dlg.NsCursor := 0;
 Dlg.DefCursor := 0;
 Dlg.OutPathCursor := 0;
 Dlg.PreBuildCursor := 0;
 Dlg.PostBuildCursor := 0;
 Dlg.DebugArgsCursor := 0;
 Dlg.WorkDirCursor := 0;
 Dlg.Confirmed := False;
End;

{ --- Charger les proprietes d un projet dans le dialogue --- }

Procedure LoadProjectProperties(Var Dlg: TProjectPropertiesDialog;
 Var Proj: TProject);
Begin
 Dlg.AssemblyName := Proj.Info.AssemblyName;
 Dlg.RootNamespace := Proj.Info.RootNamespace;
 Case Proj.Info.OutputType Of
  OT_EXE:     Dlg.OutputTypeIdx := 0;
  OT_LIBRARY:  Dlg.OutputTypeIdx := 1;
  OT_WINEXE:   Dlg.OutputTypeIdx := 2;
 Else
  Dlg.OutputTypeIdx := 0;
 End;
 Dlg.DefineConstants := Proj.Info.DefineConstants;
 Dlg.OutputPath := Proj.Info.OutputPath;
 Dlg.AsmNameCursor := Length(Dlg.AssemblyName);
 Dlg.NsCursor := Length(Dlg.RootNamespace);
 Dlg.DefCursor := Length(Dlg.DefineConstants);
 Dlg.OutPathCursor := Length(Dlg.OutputPath);
End;

{ --- Enregistrer les proprietes du dialogue dans un projet --- }

Procedure SaveProjectProperties(Var Dlg: TProjectPropertiesDialog;
 Var Proj: TProject);
Begin
 Proj.Info.AssemblyName := Dlg.AssemblyName;
 Proj.Info.RootNamespace := Dlg.RootNamespace;
 Case Dlg.OutputTypeIdx Of
  0: Proj.Info.OutputType := OT_EXE;
  1: Proj.Info.OutputType := OT_LIBRARY;
  2: Proj.Info.OutputType := OT_WINEXE;
 End;
 Proj.Info.DefineConstants := Dlg.DefineConstants;
 Proj.Info.OutputPath := Dlg.OutputPath;
End;

{ --- Dessiner les onglets du dialogue proprietes --- }

Procedure DrawProjPropTabs(Var Dlg: TProjectPropertiesDialog);
Var
 TX, TY, TW, I: Integer;
 TabN: String;
 Bg, Fg: LongInt;
Begin
 TX := Dlg.Base.X + DLG_PADDING;
 TY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 TW := (Dlg.Base.Width - DLG_PADDING * 2) Div PROJPROP_TAB_COUNT;
 For I := 0 To PROJPROP_TAB_COUNT - 1 Do
 Begin
  Case I Of
   0: TabN := ProjPropTabName(PPT_APPLICATION);
   1: TabN := ProjPropTabName(PPT_BUILD);
   2: TabN := ProjPropTabName(PPT_BUILD_EVENTS);
   3: TabN := ProjPropTabName(PPT_DEBUG);
  Else
   TabN := '';
  End;
  If I = Ord(Dlg.ActiveTab) Then
  Begin
   Bg := CLR_WINDOW;
   Fg := CLR_WINDOWTEXT;
  End
  Else
  Begin
   Bg := CLR_BTNFACE;
   Fg := CLR_GRAYTEXT;
  End;
  DrawFilledRect(TX + I * TW, TY, TX + (I + 1) * TW,
   TY + TAB_HEIGHT, Bg);
  DrawRect(TX + I * TW, TY, TX + (I + 1) * TW,
   TY + TAB_HEIGHT, CLR_BORDER);
  DrawText(TX + I * TW + 6, TY + 3, TabN, Fg);
 End;
End;

{ --- Nom du type de sortie --- }

Function OutputTypeIdxToStr(Idx: Integer): String;
Begin
 Case Idx Of
  0: OutputTypeIdxToStr := 'Application console';
  1: OutputTypeIdxToStr := 'Bibliotheque de classes';
  2: OutputTypeIdxToStr := 'Application Windows';
 Else
  OutputTypeIdxToStr := 'Inconnu';
 End;
End;

{ --- Dessiner l onglet Application --- }

Procedure DrawProjPropApplication(Var Dlg: TProjectPropertiesDialog);
Var
 FX, FY, FW, BaseY: Integer;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 FW := Dlg.Base.Width - DLG_PADDING * 2;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + DLG_PADDING;
 { Nom de l assembly }
 DrawText(FX, BaseY, 'Nom assembly :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.AssemblyName, CLR_WINDOWTEXT);
 { Espace de noms racine }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Namespace racine :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.RootNamespace, CLR_WINDOWTEXT);
 { Type de sortie }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Type de sortie :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  OutputTypeIdxToStr(Dlg.OutputTypeIdx), CLR_WINDOWTEXT);
End;

{ --- Dessiner l onglet Build --- }

Procedure DrawProjPropBuild(Var Dlg: TProjectPropertiesDialog);
Var
 FX, FW, BaseY: Integer;
 S: String;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 FW := Dlg.Base.Width - DLG_PADDING * 2;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + DLG_PADDING;
 { Constantes de compilation }
 DrawText(FX, BaseY, 'Symboles :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.DefineConstants, CLR_WINDOWTEXT);
 { Chemin de sortie }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Chemin sortie :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.OutputPath, CLR_WINDOWTEXT);
 { Niveau d avertissement }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 Str(Dlg.WarningLevel, S);
 DrawText(FX, BaseY, 'Warning level :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + PROJPROP_LABEL_WIDTH + 40,
  BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + PROJPROP_LABEL_WIDTH + 40,
  BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY, S,
  CLR_WINDOWTEXT);
 { Case a cocher : traiter avertissements comme erreurs }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawRect(FX, BaseY, FX + 12, BaseY + 12, CLR_BORDER);
 If Dlg.TreatWarningsAsErrors Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + 18, BaseY,
  'Traiter avertissements comme erreurs', CLR_WINDOWTEXT);
End;

{ --- Dessiner l onglet Build Events --- }

Procedure DrawProjPropBuildEvents(
 Var Dlg: TProjectPropertiesDialog);
Var
 FX, FW, BaseY: Integer;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 FW := Dlg.Base.Width - DLG_PADDING * 2;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + DLG_PADDING;
 { Commande pre-build }
 DrawText(FX, BaseY, 'Pre-build :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.PreBuildEvent, CLR_WINDOWTEXT);
 { Commande post-build }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Post-build :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.PostBuildEvent, CLR_WINDOWTEXT);
End;

{ --- Dessiner l onglet Debug --- }

Procedure DrawProjPropDebug(Var Dlg: TProjectPropertiesDialog);
Var
 FX, FW, BaseY: Integer;
Begin
 FX := Dlg.Base.X + DLG_PADDING;
 FW := Dlg.Base.Width - DLG_PADDING * 2;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + DLG_PADDING;
 { Arguments de debogage }
 DrawText(FX, BaseY, 'Arguments :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.DebugArgs, CLR_WINDOWTEXT);
 { Repertoire de travail }
 BaseY := BaseY + PROJPROP_ROW_SPACING;
 DrawText(FX, BaseY, 'Rep. travail :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + PROJPROP_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + PROJPROP_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + PROJPROP_LABEL_WIDTH + 4, BaseY,
  Dlg.WorkingDir, CLR_WINDOWTEXT);
End;

{ --- Dessiner le contenu de l onglet actif --- }

Procedure DrawProjPropContent(Var Dlg: TProjectPropertiesDialog);
Var
 CX, CY, CW, CH: Integer;
Begin
 CX := Dlg.Base.X + DLG_PADDING;
 CY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING + TAB_HEIGHT;
 CW := Dlg.Base.Width - DLG_PADDING * 2;
 CH := Dlg.Base.Height - DLG_TITLE_HEIGHT - DLG_PADDING * 3 -
  TAB_HEIGHT - DLG_BUTTON_HEIGHT - 10;
 DrawFilledRect(CX, CY, CX + CW, CY + CH, CLR_WINDOW);
 Case Dlg.ActiveTab Of
  PPT_APPLICATION:  DrawProjPropApplication(Dlg);
  PPT_BUILD:        DrawProjPropBuild(Dlg);
  PPT_BUILD_EVENTS: DrawProjPropBuildEvents(Dlg);
  PPT_DEBUG:        DrawProjPropDebug(Dlg);
 End;
End;

{ --- Dessiner le dialogue Proprietes du projet --- }

Procedure DrawProjectPropertiesDialog(
 Var Dlg: TProjectPropertiesDialog);
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 DrawProjPropTabs(Dlg);
 DrawProjPropContent(Dlg);
 DrawDialogButtons(Dlg.Base);
End;

{ --- Test de clic sur les onglets de proprietes projet --- }

Function ProjPropTabHitTest(Var Dlg: TProjectPropertiesDialog;
 MX, MY: Integer): Integer;
Var
 TX, TY, TW, I: Integer;
Begin
 ProjPropTabHitTest := -1;
 TX := Dlg.Base.X + DLG_PADDING;
 TY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING;
 TW := (Dlg.Base.Width - DLG_PADDING * 2) Div PROJPROP_TAB_COUNT;
 If (MY >= TY) And (MY < TY + TAB_HEIGHT) Then
 Begin
  For I := 0 To PROJPROP_TAB_COUNT - 1 Do
  Begin
   If (MX >= TX + I * TW) And (MX < TX + (I + 1) * TW) Then
   Begin
    ProjPropTabHitTest := I;
    Exit;
   End;
  End;
 End;
End;

{ --- Test de clic sur le checkbox TreatWarningsAsErrors --- }

Function ProjPropWarningCheckHitTest(
 Var Dlg: TProjectPropertiesDialog;
 MX, MY: Integer): Boolean;
Var
 FX, BaseY: Integer;
Begin
 ProjPropWarningCheckHitTest := False;
 If Dlg.ActiveTab <> PPT_BUILD Then Exit;
 FX := Dlg.Base.X + DLG_PADDING;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + DLG_PADDING +
  TAB_HEIGHT + DLG_PADDING + PROJPROP_ROW_SPACING * 3;
 ProjPropWarningCheckHitTest :=
  (MX >= FX) And (MX <= FX + 12) And
  (MY >= BaseY) And (MY <= BaseY + 12);
End;

{ --- Gestion des touches du dialogue Proprietes du projet --- }

Procedure HandleProjectPropertiesDialogKey(
 Var Dlg: TProjectPropertiesDialog; Key: Word; Ch: Char);
Begin
 If Key = $1B Then
 Begin
  Dlg.Confirmed := False;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $0D Then
 Begin
  Dlg.Confirmed := True;
  Dlg.Base.Result := DR_OK;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $09 Then
 Begin
  Inc(Dlg.FocusField);
  Case Dlg.ActiveTab Of
   PPT_APPLICATION:
    If Dlg.FocusField > 2 Then Dlg.FocusField := 0;
   PPT_BUILD:
    If Dlg.FocusField > 2 Then Dlg.FocusField := 0;
   PPT_BUILD_EVENTS:
    If Dlg.FocusField > 1 Then Dlg.FocusField := 0;
   PPT_DEBUG:
    If Dlg.FocusField > 1 Then Dlg.FocusField := 0;
  End;
  Exit;
 End;
 { Saisie dans le champ actif selon l onglet }
 Case Dlg.ActiveTab Of
  PPT_APPLICATION:
   Case Dlg.FocusField Of
    0: { AssemblyName }
     If (Ch >= ' ') And (Length(Dlg.AssemblyName) < 63) Then
     Begin
      Dlg.AssemblyName := Dlg.AssemblyName + Ch;
      Inc(Dlg.AsmNameCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.AssemblyName) > 0 Then
      Begin
       Delete(Dlg.AssemblyName, Length(Dlg.AssemblyName), 1);
       Dec(Dlg.AsmNameCursor);
      End;
     End;
    1: { RootNamespace }
     If (Ch >= ' ') And (Length(Dlg.RootNamespace) < 63) Then
     Begin
      Dlg.RootNamespace := Dlg.RootNamespace + Ch;
      Inc(Dlg.NsCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.RootNamespace) > 0 Then
      Begin
       Delete(Dlg.RootNamespace, Length(Dlg.RootNamespace), 1);
       Dec(Dlg.NsCursor);
      End;
     End;
    2: { OutputType toggle }
     If (Ch = ' ') Or (Key = $0D) Then
      Dlg.OutputTypeIdx := (Dlg.OutputTypeIdx + 1) Mod 3;
   End;
  PPT_BUILD:
   Case Dlg.FocusField Of
    0: { DefineConstants }
     If (Ch >= ' ') And (Length(Dlg.DefineConstants) < 255) Then
     Begin
      Dlg.DefineConstants := Dlg.DefineConstants + Ch;
      Inc(Dlg.DefCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.DefineConstants) > 0 Then
      Begin
       Delete(Dlg.DefineConstants,
        Length(Dlg.DefineConstants), 1);
       Dec(Dlg.DefCursor);
      End;
     End;
    1: { OutputPath }
     If (Ch >= ' ') And (Length(Dlg.OutputPath) < 255) Then
     Begin
      Dlg.OutputPath := Dlg.OutputPath + Ch;
      Inc(Dlg.OutPathCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.OutputPath) > 0 Then
      Begin
       Delete(Dlg.OutputPath, Length(Dlg.OutputPath), 1);
       Dec(Dlg.OutPathCursor);
      End;
     End;
    2: { WarningLevel }
     If (Ch >= '0') And (Ch <= '4') Then
      Dlg.WarningLevel := Ord(Ch) - Ord('0');
   End;
  PPT_BUILD_EVENTS:
   Case Dlg.FocusField Of
    0: { PreBuildEvent }
     If (Ch >= ' ') And (Length(Dlg.PreBuildEvent) < 255) Then
     Begin
      Dlg.PreBuildEvent := Dlg.PreBuildEvent + Ch;
      Inc(Dlg.PreBuildCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.PreBuildEvent) > 0 Then
      Begin
       Delete(Dlg.PreBuildEvent,
        Length(Dlg.PreBuildEvent), 1);
       Dec(Dlg.PreBuildCursor);
      End;
     End;
    1: { PostBuildEvent }
     If (Ch >= ' ') And (Length(Dlg.PostBuildEvent) < 255) Then
     Begin
      Dlg.PostBuildEvent := Dlg.PostBuildEvent + Ch;
      Inc(Dlg.PostBuildCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.PostBuildEvent) > 0 Then
      Begin
       Delete(Dlg.PostBuildEvent,
        Length(Dlg.PostBuildEvent), 1);
       Dec(Dlg.PostBuildCursor);
      End;
     End;
   End;
  PPT_DEBUG:
   Case Dlg.FocusField Of
    0: { DebugArgs }
     If (Ch >= ' ') And (Length(Dlg.DebugArgs) < 255) Then
     Begin
      Dlg.DebugArgs := Dlg.DebugArgs + Ch;
      Inc(Dlg.DebugArgsCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.DebugArgs) > 0 Then
      Begin
       Delete(Dlg.DebugArgs, Length(Dlg.DebugArgs), 1);
       Dec(Dlg.DebugArgsCursor);
      End;
     End;
    1: { WorkingDir }
     If (Ch >= ' ') And (Length(Dlg.WorkingDir) < 255) Then
     Begin
      Dlg.WorkingDir := Dlg.WorkingDir + Ch;
      Inc(Dlg.WorkDirCursor);
     End
     Else If Key = $08 Then
     Begin
      If Length(Dlg.WorkingDir) > 0 Then
      Begin
       Delete(Dlg.WorkingDir, Length(Dlg.WorkingDir), 1);
       Dec(Dlg.WorkDirCursor);
      End;
     End;
   End;
 End;
End;

{ --- Gestion des evenements du dialogue Proprietes du projet --- }

Procedure HandleProjectPropertiesDialogEvent(
 Var Dlg: TProjectPropertiesDialog; Var Ev: TEvent);
Var
 TabIdx, BtnR: Integer;
Begin
 If Not Dlg.Base.Visible Then Exit;
 Case Ev.Kind Of
  EV_KEY_DOWN, EV_KEY_CHAR:
  Begin
   HandleProjectPropertiesDialogKey(Dlg, Ev.KeyCode, Ev.KeyChar);
   DrawProjectPropertiesDialog(Dlg);
  End;
  EV_MOUSE_DOWN:
  Begin
   TabIdx := ProjPropTabHitTest(Dlg, Ev.MouseX, Ev.MouseY);
   If TabIdx >= 0 Then
   Begin
    Case TabIdx Of
     0: Dlg.ActiveTab := PPT_APPLICATION;
     1: Dlg.ActiveTab := PPT_BUILD;
     2: Dlg.ActiveTab := PPT_BUILD_EVENTS;
     3: Dlg.ActiveTab := PPT_DEBUG;
    End;
    Dlg.FocusField := 0;
    DrawProjectPropertiesDialog(Dlg);
    Exit;
   End;
   If ProjPropWarningCheckHitTest(Dlg, Ev.MouseX, Ev.MouseY) Then
   Begin
    Dlg.TreatWarningsAsErrors :=
     Not Dlg.TreatWarningsAsErrors;
    DrawProjectPropertiesDialog(Dlg);
    Exit;
   End;
   BtnR := DialogButtonHitTest(Dlg.Base, Ev.MouseX, Ev.MouseY);
   If BtnR <> DR_NONE Then
   Begin
    If BtnR = DR_OK Then
     Dlg.Confirmed := True
    Else
     Dlg.Confirmed := False;
    Dlg.Base.Result := BtnR;
    CloseDialog(Dlg.Base);
   End;
  End;
 End;
End;

{ --- Afficher le dialogue Proprietes du projet --- }

Procedure ShowProjectPropertiesDialog(
 Var Dlg: TProjectPropertiesDialog);
Begin
 Dlg.Base.Visible := True;
 DrawProjectPropertiesDialog(Dlg);
End;

{ --- Obtenir le type de projet selectionne (nouveau projet) --- }

Function GetNewProjectSelectedType(
 Var Dlg: TNewProjectDialog): Integer;
Begin
 GetNewProjectSelectedType := Dlg.SelType;
End;

{ --- Obtenir le nom du projet saisi --- }

Function GetNewProjectName(Var Dlg: TNewProjectDialog): String;
Begin
 GetNewProjectName := Dlg.ProjectName;
End;

{ --- Obtenir l emplacement saisi --- }

Function GetNewProjectLocation(Var Dlg: TNewProjectDialog): String;
Begin
 GetNewProjectLocation := Dlg.Location;
End;

{ --- Obtenir le nom de solution saisi --- }

Function GetNewProjectSolutionName(
 Var Dlg: TNewProjectDialog): String;
Begin
 GetNewProjectSolutionName := Dlg.SolutionName;
End;

{ --- Verifier si creer un repertoire solution est coche --- }

Function IsNewProjectCreateSolDir(
 Var Dlg: TNewProjectDialog): Boolean;
Begin
 IsNewProjectCreateSolDir := Dlg.CreateSolDir;
End;

{ --- Verifier si le dialogue nouveau projet est confirme --- }

Function IsNewProjectConfirmed(
 Var Dlg: TNewProjectDialog): Boolean;
Begin
 IsNewProjectConfirmed := Dlg.Confirmed;
End;

{ --- Obtenir le type de fichier selectionne --- }

Function GetNewFileSelectedType(
 Var Dlg: TNewFileDialog): Integer;
Begin
 GetNewFileSelectedType := Dlg.SelType;
End;

{ --- Obtenir le nom de fichier saisi --- }

Function GetNewFileName(Var Dlg: TNewFileDialog): String;
Begin
 GetNewFileName := Dlg.FileName;
End;

{ --- Obtenir le nom complet du fichier avec extension --- }

Function GetNewFileFullName(Var Dlg: TNewFileDialog): String;
Begin
 GetNewFileFullName := Dlg.FileName +
  NewFileTypeExtension(Dlg.SelType);
End;

{ --- Verifier si le dialogue nouveau fichier est confirme --- }

Function IsNewFileConfirmed(Var Dlg: TNewFileDialog): Boolean;
Begin
 IsNewFileConfirmed := Dlg.Confirmed;
End;

{ --- Obtenir l onglet actif du dialogue reference --- }

Function GetAddRefActiveTab(
 Var Dlg: TAddReferenceDialog): TRefTabKind;
Begin
 GetAddRefActiveTab := Dlg.ActiveTab;
End;

{ --- Obtenir le nombre d items dans le dialogue reference --- }

Function GetAddRefItemCount(
 Var Dlg: TAddReferenceDialog): Integer;
Begin
 GetAddRefItemCount := Dlg.ItemCount;
End;

{ --- Obtenir le nombre d items coches --- }

Function GetAddRefCheckedCount(
 Var Dlg: TAddReferenceDialog): Integer;
Var
 I, C: Integer;
Begin
 C := 0;
 For I := 0 To Dlg.ItemCount - 1 Do
  If Dlg.Items[I].Checked Then
   Inc(C);
 GetAddRefCheckedCount := C;
End;

{ --- Verifier si un item est coche --- }

Function IsAddRefItemChecked(Var Dlg: TAddReferenceDialog;
 Idx: Integer): Boolean;
Begin
 IsAddRefItemChecked := False;
 If (Idx >= 0) And (Idx < Dlg.ItemCount) Then
  IsAddRefItemChecked := Dlg.Items[Idx].Checked;
End;

{ --- Obtenir le nom d un item de reference --- }

Function GetAddRefItemName(Var Dlg: TAddReferenceDialog;
 Idx: Integer): String;
Begin
 GetAddRefItemName := '';
 If (Idx >= 0) And (Idx < Dlg.ItemCount) Then
  GetAddRefItemName := Dlg.Items[Idx].Name;
End;

{ --- Obtenir le chemin d un item de reference --- }

Function GetAddRefItemPath(Var Dlg: TAddReferenceDialog;
 Idx: Integer): String;
Begin
 GetAddRefItemPath := '';
 If (Idx >= 0) And (Idx < Dlg.ItemCount) Then
  GetAddRefItemPath := Dlg.Items[Idx].Path;
End;

{ --- Verifier si le dialogue reference est confirme --- }

Function IsAddRefConfirmed(
 Var Dlg: TAddReferenceDialog): Boolean;
Begin
 IsAddRefConfirmed := Dlg.Confirmed;
End;

{ --- Obtenir l onglet actif du dialogue proprietes projet --- }

Function GetProjPropActiveTab(
 Var Dlg: TProjectPropertiesDialog): TProjPropTab;
Begin
 GetProjPropActiveTab := Dlg.ActiveTab;
End;

{ --- Obtenir le nom d assembly du dialogue proprietes --- }

Function GetProjPropAssemblyName(
 Var Dlg: TProjectPropertiesDialog): String;
Begin
 GetProjPropAssemblyName := Dlg.AssemblyName;
End;

{ --- Obtenir le namespace racine du dialogue proprietes --- }

Function GetProjPropRootNamespace(
 Var Dlg: TProjectPropertiesDialog): String;
Begin
 GetProjPropRootNamespace := Dlg.RootNamespace;
End;

{ --- Obtenir l index du type de sortie --- }

Function GetProjPropOutputTypeIdx(
 Var Dlg: TProjectPropertiesDialog): Integer;
Begin
 GetProjPropOutputTypeIdx := Dlg.OutputTypeIdx;
End;

{ --- Obtenir les constantes de compilation --- }

Function GetProjPropDefineConstants(
 Var Dlg: TProjectPropertiesDialog): String;
Begin
 GetProjPropDefineConstants := Dlg.DefineConstants;
End;

{ --- Obtenir le chemin de sortie --- }

Function GetProjPropOutputPath(
 Var Dlg: TProjectPropertiesDialog): String;
Begin
 GetProjPropOutputPath := Dlg.OutputPath;
End;

{ --- Obtenir le niveau d avertissement --- }

Function GetProjPropWarningLevel(
 Var Dlg: TProjectPropertiesDialog): Integer;
Begin
 GetProjPropWarningLevel := Dlg.WarningLevel;
End;

{ --- Verifier si les avertissements sont traites comme erreurs --- }

Function IsProjPropWarningsAsErrors(
 Var Dlg: TProjectPropertiesDialog): Boolean;
Begin
 IsProjPropWarningsAsErrors := Dlg.TreatWarningsAsErrors;
End;

{ --- Verifier si le dialogue proprietes projet est confirme --- }

Function IsProjPropConfirmed(
 Var Dlg: TProjectPropertiesDialog): Boolean;
Begin
 IsProjPropConfirmed := Dlg.Confirmed;
End;

{ --- Verifier si un dialogue projet est visible --- }

Function IsNewProjectDialogVisible(
 Var Dlg: TNewProjectDialog): Boolean;
Begin
 IsNewProjectDialogVisible := Dlg.Base.Visible;
End;

{ --- Verifier si un dialogue nouveau fichier est visible --- }

Function IsNewFileDialogVisible(
 Var Dlg: TNewFileDialog): Boolean;
Begin
 IsNewFileDialogVisible := Dlg.Base.Visible;
End;

{ --- Verifier si le dialogue reference est visible --- }

Function IsAddRefDialogVisible(
 Var Dlg: TAddReferenceDialog): Boolean;
Begin
 IsAddRefDialogVisible := Dlg.Base.Visible;
End;

{ --- Verifier si le dialogue proprietes projet est visible --- }

Function IsProjPropDialogVisible(
 Var Dlg: TProjectPropertiesDialog): Boolean;
Begin
 IsProjPropDialogVisible := Dlg.Base.Visible;
End;

{ ============================================================
  TODO 23 - BOITES DE DIALOGUE : OPTIONS DE L IDE [IMPLEMENTE]
  ============================================================ }

{ --- Nom affichable d une categorie d options --- }

Function OptionCategoryName(Cat: TOptionCategory): String;
Begin
 Case Cat Of
  OC_ENV_GENERAL:        OptionCategoryName := 'General';
  OC_ENV_FONTS:          OptionCategoryName := 'Polices et couleurs';
  OC_ENV_KEYBOARD:       OptionCategoryName := 'Clavier';
  OC_ENV_STARTUP:        OptionCategoryName := 'Demarrage';
  OC_ENV_AUTOSAVE:       OptionCategoryName := 'Enregistrement auto';
  OC_EDITOR_GENERAL:     OptionCategoryName := 'General';
  OC_EDITOR_TABS:        OptionCategoryName := 'Tabulations';
  OC_EDITOR_SCROLL:      OptionCategoryName := 'Defilement';
  OC_EDITOR_INTELLISENSE:OptionCategoryName := 'IntelliSense';
  OC_EDITOR_FORMAT:      OptionCategoryName := 'Mise en forme';
  OC_PROJ_GENERAL:       OptionCategoryName := 'General';
  OC_PROJ_BUILD:         OptionCategoryName := 'Build et execution';
  OC_DEBUG_GENERAL:      OptionCategoryName := 'General';
  OC_DEBUG_OUTPUT:       OptionCategoryName := 'Sortie';
 Else
  OptionCategoryName := '???';
 End;
End;

{ --- Nom d une action de demarrage --- }

Function StartupActionName(A: TOptStartupAction): String;
Begin
 Case A Of
  OSA_NOTHING:      StartupActionName := 'Ne rien faire';
  OSA_LAST_PROJECT: StartupActionName := 'Dernier projet';
  OSA_START_PAGE:   StartupActionName := 'Page d accueil';
 Else
  StartupActionName := '???';
 End;
End;

{ --- Initialiser un noeud de categorie --- }

Procedure InitOptCategoryNode(Var N: TOptCategoryNode);
Begin
 N.Name := '';
 N.ParentIdx := -1;
 N.Level := 0;
 N.Expanded := False;
 N.Visible := True;
 N.Selected := False;
 N.Category := OC_ENV_GENERAL;
End;

{ --- Initialiser les donnees d options par defaut --- }

Procedure InitOptionsDialogData(Var D: TOptionsDialogData);
Begin
 D.ThemeName := 'Bleu';
 D.FontName := 'Consolas';
 D.FontSize := 10;
 D.ShortcutModified := False;
 D.StartupAction := OSA_NOTHING;
 D.AutoSaveEnabled := True;
 D.AutoSaveInterval := 300;
 D.ShowLineNumbers := True;
 D.WordWrap := False;
 D.ShowWhitespace := False;
 D.ShowIndentGuides := True;
 D.TabSize := 4;
 D.InsertSpaces := True;
 D.IndentSize := 4;
 D.SmoothScroll := True;
 D.ScrollMargin := 3;
 D.AutoIndent := True;
 D.AutoBraces := True;
 D.DefaultProjectPath := '.';
 D.ShowOutputOnBuild := True;
 D.BuildVerbose := False;
 D.ParallelBuild := 1;
 D.BreakOnFirstError := True;
 D.StepIntoProperties := False;
 D.ShowDebugMessages := True;
End;

{ --- Construire l arbre de categories --- }

Procedure BuildOptionsCategoryTree(Var Dlg: TOptionsDialog);
Var
 I: Integer;

 Procedure AddNode(AName: String; AParent, ALevel: Integer;
  AExpanded: Boolean; ACat: TOptionCategory);
 Begin
  If Dlg.CategoryCount >= MAX_OPT_CATEGORIES Then Exit;
  I := Dlg.CategoryCount;
  InitOptCategoryNode(Dlg.Categories[I]);
  Dlg.Categories[I].Name := AName;
  Dlg.Categories[I].ParentIdx := AParent;
  Dlg.Categories[I].Level := ALevel;
  Dlg.Categories[I].Expanded := AExpanded;
  Dlg.Categories[I].Visible := True;
  Dlg.Categories[I].Category := ACat;
  Inc(Dlg.CategoryCount);
 End;

Begin
 Dlg.CategoryCount := 0;
 { Environnement (index 0) }
 AddNode('Environnement', -1, 0, True, OC_ENV_GENERAL);
 AddNode('General', 0, 1, False, OC_ENV_GENERAL);
 AddNode('Polices et couleurs', 0, 1, False, OC_ENV_FONTS);
 AddNode('Clavier', 0, 1, False, OC_ENV_KEYBOARD);
 AddNode('Demarrage', 0, 1, False, OC_ENV_STARTUP);
 AddNode('Enregistrement auto', 0, 1, False, OC_ENV_AUTOSAVE);
 { Editeur de texte (index 6) }
 AddNode('Editeur de texte', -1, 0, True, OC_EDITOR_GENERAL);
 AddNode('General', 6, 1, False, OC_EDITOR_GENERAL);
 AddNode('Tabulations', 6, 1, False, OC_EDITOR_TABS);
 AddNode('Defilement', 6, 1, False, OC_EDITOR_SCROLL);
 AddNode('IntelliSense', 6, 1, False, OC_EDITOR_INTELLISENSE);
 AddNode('Mise en forme', 6, 1, False, OC_EDITOR_FORMAT);
 { Projets et solutions (index 12) }
 AddNode('Projets et solutions', -1, 0, True, OC_PROJ_GENERAL);
 AddNode('General', 12, 1, False, OC_PROJ_GENERAL);
 AddNode('Build et execution', 12, 1, False, OC_PROJ_BUILD);
 { Debogage (index 15) -- utilise le dernier slot disponible }
 { Note : 16 noeuds au total = MAX_OPT_CATEGORIES }
End;

{ --- Initialiser le dialogue des options --- }

Procedure InitOptionsDialog(Var Dlg: TOptionsDialog);
Begin
 InitDialog(Dlg.Base, 'Options', OPT_DLG_WIDTH, OPT_DLG_HEIGHT);
 Dlg.Base.HasCancel := True;
 InitOptionsDialogData(Dlg.Data);
 Dlg.OriginalData := Dlg.Data;
 BuildOptionsCategoryTree(Dlg);
 Dlg.SelectedCategory := 1;
 If Dlg.CategoryCount > 1 Then
  Dlg.Categories[1].Selected := True;
 Dlg.ScrollTop := 0;
 Dlg.Modified := False;
 Dlg.Confirmed := False;
End;

{ --- Dessiner l arbre de categories a gauche --- }

Procedure DrawOptionsCategoryTree(Var Dlg: TOptionsDialog);
Var
 I, X, Y, TX, TY: Integer;
 BG, FG: Integer;
Begin
 X := Dlg.Base.X + 1;
 Y := Dlg.Base.Y + DLG_TITLE_HEIGHT + 1;
 { Fond de l arbre }
 DrawFilledRect(X, Y, X + OPT_TREE_WIDTH - 1,
  Dlg.Base.Y + Dlg.Base.Height - DLG_PADDING -
  DLG_BUTTON_HEIGHT - DLG_PADDING,
  CLR_EDITOR_BG);
 { Separateur vertical }
 DrawRect(X + OPT_TREE_WIDTH, Y,
  X + OPT_TREE_WIDTH,
  Dlg.Base.Y + Dlg.Base.Height - DLG_PADDING -
  DLG_BUTTON_HEIGHT - DLG_PADDING,
  CLR_BORDER);
 TY := Y + 2;
 For I := 0 To Dlg.CategoryCount - 1 Do
 Begin
  If Not Dlg.Categories[I].Visible Then Continue;
  TX := X + 4 + Dlg.Categories[I].Level * OPT_TREE_INDENT;
  { Fond de selection }
  If I = Dlg.SelectedCategory Then
  Begin
   BG := CLR_TITLEBAR_ACTIVE;
   FG := 15;
   DrawFilledRect(X, TY, X + OPT_TREE_WIDTH - 1,
    TY + OPT_TREE_NODE_HEIGHT - 1, BG);
  End
  Else
  Begin
   BG := CLR_EDITOR_BG;
   FG := CLR_MENU_TEXT;
  End;
  { Indicateur depliage pour les parents }
  If Dlg.Categories[I].Level = 0 Then
  Begin
   If Dlg.Categories[I].Expanded Then
    DrawText(TX, TY + 2, '-', FG)
   Else
    DrawText(TX, TY + 2, '+', FG);
   DrawText(TX + 10, TY + 2, Dlg.Categories[I].Name, FG);
  End
  Else
   DrawText(TX, TY + 2, Dlg.Categories[I].Name, FG);
  TY := TY + OPT_TREE_NODE_HEIGHT;
 End;
End;

{ --- Dessiner la page Environnement > General --- }

Procedure DrawOptionsEnvGeneral(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 { Titre de la page }
 DrawText(FX, BaseY, 'Environnement > General', CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Theme couleur }
 DrawText(FX, BaseY, 'Theme couleur :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  Dlg.Data.ThemeName, CLR_WINDOWTEXT);
 { Police }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY, 'Police :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  Dlg.Data.FontName, CLR_WINDOWTEXT);
 { Taille }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY, 'Taille police :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  Chr(Dlg.Data.FontSize Div 10 + 48) +
  Chr(Dlg.Data.FontSize Mod 10 + 48), CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Environnement > Polices et couleurs --- }

Procedure DrawOptionsEnvFonts(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY,
  'Environnement > Polices et couleurs', CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Police affichage }
 DrawText(FX, BaseY, 'Police :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  Dlg.Data.FontName, CLR_WINDOWTEXT);
 { Taille }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY, 'Taille :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  Chr(Dlg.Data.FontSize Div 10 + 48) +
  Chr(Dlg.Data.FontSize Mod 10 + 48), CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY,
  '(Configuration detaillee des couleurs a venir)',
  CLR_BORDER);
End;

{ --- Dessiner la page Environnement > Clavier (stub) --- }

Procedure DrawOptionsEnvKeyboard(Var Dlg: TOptionsDialog);
Var
 FX, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Environnement > Clavier', CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY,
  '(Raccourcis clavier personnalisables a venir)',
  CLR_BORDER);
End;

{ --- Dessiner la page Environnement > Demarrage --- }

Procedure DrawOptionsEnvStartup(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Environnement > Demarrage',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Action au demarrage }
 DrawText(FX, BaseY, 'Au demarrage :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  StartupActionName(Dlg.Data.StartupAction), CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Environnement > Enregistrement auto --- }

Procedure DrawOptionsEnvAutoSave(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
 S: String;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY,
  'Environnement > Enregistrement automatique',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Case a cocher : activer }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.AutoSaveEnabled Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Activer l enregistrement automatique', CLR_WINDOWTEXT);
 { Intervalle }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY, 'Intervalle (sec) :', CLR_WINDOWTEXT);
 Str(Dlg.Data.AutoSaveInterval, S);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 80, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 80, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY, S,
  CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Editeur de texte > General --- }

Procedure DrawOptionsEditorGeneral(Var Dlg: TOptionsDialog);
Var
 FX, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Editeur de texte > General',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Numeros de ligne }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.ShowLineNumbers Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Afficher les numeros de ligne', CLR_WINDOWTEXT);
 { Retour a la ligne }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.WordWrap Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Retour a la ligne automatique', CLR_WINDOWTEXT);
 { Espaces visibles }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.ShowWhitespace Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Afficher les espaces', CLR_WINDOWTEXT);
 { Guides d indentation }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.ShowIndentGuides Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Guides d indentation', CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Editeur de texte > Tabulations --- }

Procedure DrawOptionsEditorTabs(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
 S: String;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Editeur de texte > Tabulations',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Taille tabulation }
 Str(Dlg.Data.TabSize, S);
 DrawText(FX, BaseY, 'Taille tabulation :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY, S,
  CLR_WINDOWTEXT);
 { Inserer des espaces }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.InsertSpaces Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Inserer des espaces', CLR_WINDOWTEXT);
 { Taille d indentation }
 BaseY := BaseY + OPT_ROW_SPACING;
 Str(Dlg.Data.IndentSize, S);
 DrawText(FX, BaseY, 'Taille indentation :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY, S,
  CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Editeur de texte > Defilement --- }

Procedure DrawOptionsEditorScroll(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
 S: String;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Editeur de texte > Defilement',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Defilement fluide }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.SmoothScroll Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Defilement fluide', CLR_WINDOWTEXT);
 { Marge de defilement }
 BaseY := BaseY + OPT_ROW_SPACING;
 Str(Dlg.Data.ScrollMargin, S);
 DrawText(FX, BaseY, 'Marge (lignes) :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY, S,
  CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Editeur de texte > IntelliSense (stub) --- }

Procedure DrawOptionsEditorIntelliSense(
 Var Dlg: TOptionsDialog);
Var
 FX, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Editeur de texte > IntelliSense',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawText(FX, BaseY,
  '(IntelliSense sera implemente ulterieurement)',
  CLR_BORDER);
End;

{ --- Dessiner la page Editeur de texte > Mise en forme --- }

Procedure DrawOptionsEditorFormat(Var Dlg: TOptionsDialog);
Var
 FX, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Editeur de texte > Mise en forme',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Indentation automatique }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.AutoIndent Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Indentation automatique', CLR_WINDOWTEXT);
 { Accolades automatiques }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.AutoBraces Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Accolades automatiques', CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Projets et solutions > General --- }

Procedure DrawOptionsProjGeneral(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Projets et solutions > General',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Emplacement par defaut }
 DrawText(FX, BaseY, 'Chemin projets :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + FW, BaseY + OPT_FIELD_HEIGHT, CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY,
  Dlg.Data.DefaultProjectPath, CLR_WINDOWTEXT);
 { Afficher sortie au build }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.ShowOutputOnBuild Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Afficher la sortie au build', CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Projets et solutions > Build --- }

Procedure DrawOptionsProjBuild(Var Dlg: TOptionsDialog);
Var
 FX, FW, BaseY, PX: Integer;
 S: String;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FW := Dlg.Base.Width - OPT_TREE_WIDTH - OPT_PANEL_PADDING * 2;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Projets et solutions > Build',
  CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Mode verbeux }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.BuildVerbose Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Build en mode verbeux', CLR_WINDOWTEXT);
 { Nombre de builds paralleles }
 BaseY := BaseY + OPT_ROW_SPACING;
 Str(Dlg.Data.ParallelBuild, S);
 DrawText(FX, BaseY, 'Builds paralleles :', CLR_WINDOWTEXT);
 DrawFilledRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_WINDOW);
 DrawRect(FX + OPT_LABEL_WIDTH, BaseY - 2,
  FX + OPT_LABEL_WIDTH + 60, BaseY + OPT_FIELD_HEIGHT,
  CLR_BORDER);
 DrawText(FX + OPT_LABEL_WIDTH + 4, BaseY, S,
  CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Debogage > General --- }

Procedure DrawOptionsDebugGeneral(Var Dlg: TOptionsDialog);
Var
 FX, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Debogage > General', CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Arreter au premier point d arret }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.BreakOnFirstError Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Arreter au premier point d arret', CLR_WINDOWTEXT);
 { Pas a pas dans les proprietes }
 BaseY := BaseY + OPT_ROW_SPACING;
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.StepIntoProperties Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Pas a pas dans les proprietes', CLR_WINDOWTEXT);
End;

{ --- Dessiner la page Debogage > Sortie --- }

Procedure DrawOptionsDebugOutput(Var Dlg: TOptionsDialog);
Var
 FX, BaseY, PX: Integer;
Begin
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 FX := PX;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING;
 DrawText(FX, BaseY, 'Debogage > Sortie', CLR_WINDOWTEXT);
 BaseY := BaseY + OPT_ROW_SPACING;
 { Afficher messages de debogage }
 DrawRect(FX, BaseY, FX + OPT_CHECK_SIZE,
  BaseY + OPT_CHECK_SIZE, CLR_BORDER);
 If Dlg.Data.ShowDebugMessages Then
  DrawText(FX + 2, BaseY - 1, 'X', CLR_WINDOWTEXT);
 DrawText(FX + OPT_CHECK_SIZE + 6, BaseY,
  'Afficher les messages de debogage', CLR_WINDOWTEXT);
End;

{ --- Dispatcher vers la page de parametres appropriee --- }

Procedure DrawOptionsPage(Var Dlg: TOptionsDialog);
Var
 Cat: TOptionCategory;
 PX, PY, PW, PH: Integer;
Begin
 { Effacer le panneau droit }
 PX := Dlg.Base.X + OPT_TREE_WIDTH + 1;
 PY := Dlg.Base.Y + DLG_TITLE_HEIGHT + 1;
 PW := Dlg.Base.Width - OPT_TREE_WIDTH - 2;
 PH := Dlg.Base.Height - DLG_TITLE_HEIGHT -
  DLG_PADDING - DLG_BUTTON_HEIGHT - DLG_PADDING - 1;
 DrawFilledRect(PX, PY, PX + PW, PY + PH, CLR_BACKGROUND);
 If (Dlg.SelectedCategory < 0) Or
  (Dlg.SelectedCategory >= Dlg.CategoryCount) Then Exit;
 Cat := Dlg.Categories[Dlg.SelectedCategory].Category;
 Case Cat Of
  OC_ENV_GENERAL:         DrawOptionsEnvGeneral(Dlg);
  OC_ENV_FONTS:           DrawOptionsEnvFonts(Dlg);
  OC_ENV_KEYBOARD:        DrawOptionsEnvKeyboard(Dlg);
  OC_ENV_STARTUP:         DrawOptionsEnvStartup(Dlg);
  OC_ENV_AUTOSAVE:        DrawOptionsEnvAutoSave(Dlg);
  OC_EDITOR_GENERAL:      DrawOptionsEditorGeneral(Dlg);
  OC_EDITOR_TABS:         DrawOptionsEditorTabs(Dlg);
  OC_EDITOR_SCROLL:       DrawOptionsEditorScroll(Dlg);
  OC_EDITOR_INTELLISENSE: DrawOptionsEditorIntelliSense(Dlg);
  OC_EDITOR_FORMAT:       DrawOptionsEditorFormat(Dlg);
  OC_PROJ_GENERAL:        DrawOptionsProjGeneral(Dlg);
  OC_PROJ_BUILD:          DrawOptionsProjBuild(Dlg);
  OC_DEBUG_GENERAL:       DrawOptionsDebugGeneral(Dlg);
  OC_DEBUG_OUTPUT:        DrawOptionsDebugOutput(Dlg);
 End;
End;

{ --- Dessiner le dialogue complet des options --- }

Procedure DrawOptionsDialog(Var Dlg: TOptionsDialog);
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 DrawOptionsCategoryTree(Dlg);
 DrawOptionsPage(Dlg);
 DrawDialogButtons(Dlg.Base);
End;

{ --- Test de clic sur l arbre de categories --- }

Function OptionsCategoryHitTest(Var Dlg: TOptionsDialog;
 MX, MY: Integer): Integer;
Var
 I, X, Y, TY: Integer;
Begin
 OptionsCategoryHitTest := -1;
 X := Dlg.Base.X + 1;
 Y := Dlg.Base.Y + DLG_TITLE_HEIGHT + 1;
 TY := Y + 2;
 For I := 0 To Dlg.CategoryCount - 1 Do
 Begin
  If Not Dlg.Categories[I].Visible Then Continue;
  If (MX >= X) And (MX < X + OPT_TREE_WIDTH) And
   (MY >= TY) And (MY < TY + OPT_TREE_NODE_HEIGHT) Then
  Begin
   OptionsCategoryHitTest := I;
   Exit;
  End;
  TY := TY + OPT_TREE_NODE_HEIGHT;
 End;
End;

{ --- Test de clic sur un champ de la page --- }

Function OptionsPageFieldHitTest(Var Dlg: TOptionsDialog;
 MX, MY: Integer): Integer;
Var
 PX, BaseY, Row: Integer;
Begin
 OptionsPageFieldHitTest := -1;
 PX := Dlg.Base.X + OPT_TREE_WIDTH + OPT_PANEL_PADDING;
 BaseY := Dlg.Base.Y + DLG_TITLE_HEIGHT + OPT_PANEL_PADDING +
  OPT_ROW_SPACING;
 Row := 0;
 While BaseY + OPT_ROW_SPACING * Row <
  Dlg.Base.Y + Dlg.Base.Height Do
 Begin
  If (MY >= BaseY + OPT_ROW_SPACING * Row - 2) And
   (MY < BaseY + OPT_ROW_SPACING * Row +
   OPT_FIELD_HEIGHT) And
   (MX >= PX) Then
  Begin
   OptionsPageFieldHitTest := Row;
   Exit;
  End;
  Inc(Row);
 End;
End;

{ --- Gestion des touches dans le dialogue options --- }

Procedure HandleOptionsKey(Var Dlg: TOptionsDialog;
 Key: Integer);
Begin
 If Key = $1B Then { Echap }
 Begin
  Dlg.Confirmed := False;
  Dlg.Data := Dlg.OriginalData;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $0D Then { Entree }
 Begin
  Dlg.Confirmed := True;
  Dlg.Base.Result := DR_OK;
  CloseDialog(Dlg.Base);
  Exit;
 End;
 If Key = $4800 Then { Fleche haut }
 Begin
  If Dlg.SelectedCategory > 0 Then
  Begin
   Dlg.Categories[Dlg.SelectedCategory].Selected := False;
   Dec(Dlg.SelectedCategory);
   { Sauter les parents de niveau 0 non depliables }
   While (Dlg.SelectedCategory > 0) And
    Not Dlg.Categories[Dlg.SelectedCategory].Visible Do
    Dec(Dlg.SelectedCategory);
   Dlg.Categories[Dlg.SelectedCategory].Selected := True;
  End;
 End;
 If Key = $5000 Then { Fleche bas }
 Begin
  If Dlg.SelectedCategory < Dlg.CategoryCount - 1 Then
  Begin
   Dlg.Categories[Dlg.SelectedCategory].Selected := False;
   Inc(Dlg.SelectedCategory);
   While (Dlg.SelectedCategory < Dlg.CategoryCount - 1) And
    Not Dlg.Categories[Dlg.SelectedCategory].Visible Do
    Inc(Dlg.SelectedCategory);
   Dlg.Categories[Dlg.SelectedCategory].Selected := True;
  End;
 End;
End;

{ --- Gestion des evenements du dialogue options --- }

Procedure HandleOptionsEvent(Var Dlg: TOptionsDialog;
 Var Ev: TEvent);
Var
 CatIdx, BtnR, FieldIdx: Integer;
 Cat: TOptionCategory;
Begin
 If Not Dlg.Base.Visible Then Exit;
 Case Ev.Kind Of
  EV_KEY_DOWN, EV_KEY_CHAR:
  Begin
   HandleOptionsKey(Dlg, Ev.KeyCode);
   DrawOptionsDialog(Dlg);
  End;
  EV_MOUSE_DOWN:
  Begin
   { Clic sur l arbre de categories }
   CatIdx := OptionsCategoryHitTest(Dlg, Ev.MouseX,
    Ev.MouseY);
   If CatIdx >= 0 Then
   Begin
    { Si c est un parent, basculer depliage }
    If Dlg.Categories[CatIdx].Level = 0 Then
    Begin
     Dlg.Categories[CatIdx].Expanded :=
      Not Dlg.Categories[CatIdx].Expanded;
    End;
    Dlg.Categories[Dlg.SelectedCategory].Selected := False;
    Dlg.SelectedCategory := CatIdx;
    Dlg.Categories[CatIdx].Selected := True;
    DrawOptionsDialog(Dlg);
    Exit;
   End;
   { Clic sur un champ de la page active }
   FieldIdx := OptionsPageFieldHitTest(Dlg, Ev.MouseX,
    Ev.MouseY);
   If FieldIdx >= 0 Then
   Begin
    Cat := Dlg.Categories[
     Dlg.SelectedCategory].Category;
    { Basculer les cases a cocher selon la page }
    Case Cat Of
     OC_ENV_AUTOSAVE:
      If FieldIdx = 0 Then
      Begin
       Dlg.Data.AutoSaveEnabled :=
        Not Dlg.Data.AutoSaveEnabled;
       Dlg.Modified := True;
      End;
     OC_EDITOR_GENERAL:
      Case FieldIdx Of
       0: Begin
        Dlg.Data.ShowLineNumbers :=
         Not Dlg.Data.ShowLineNumbers;
        Dlg.Modified := True;
       End;
       1: Begin
        Dlg.Data.WordWrap :=
         Not Dlg.Data.WordWrap;
        Dlg.Modified := True;
       End;
       2: Begin
        Dlg.Data.ShowWhitespace :=
         Not Dlg.Data.ShowWhitespace;
        Dlg.Modified := True;
       End;
       3: Begin
        Dlg.Data.ShowIndentGuides :=
         Not Dlg.Data.ShowIndentGuides;
        Dlg.Modified := True;
       End;
      End;
     OC_EDITOR_TABS:
      If FieldIdx = 1 Then
      Begin
       Dlg.Data.InsertSpaces :=
        Not Dlg.Data.InsertSpaces;
       Dlg.Modified := True;
      End;
     OC_EDITOR_SCROLL:
      If FieldIdx = 0 Then
      Begin
       Dlg.Data.SmoothScroll :=
        Not Dlg.Data.SmoothScroll;
       Dlg.Modified := True;
      End;
     OC_EDITOR_FORMAT:
      Case FieldIdx Of
       0: Begin
        Dlg.Data.AutoIndent :=
         Not Dlg.Data.AutoIndent;
        Dlg.Modified := True;
       End;
       1: Begin
        Dlg.Data.AutoBraces :=
         Not Dlg.Data.AutoBraces;
        Dlg.Modified := True;
       End;
      End;
     OC_PROJ_GENERAL:
      If FieldIdx = 1 Then
      Begin
       Dlg.Data.ShowOutputOnBuild :=
        Not Dlg.Data.ShowOutputOnBuild;
       Dlg.Modified := True;
      End;
     OC_PROJ_BUILD:
      If FieldIdx = 0 Then
      Begin
       Dlg.Data.BuildVerbose :=
        Not Dlg.Data.BuildVerbose;
       Dlg.Modified := True;
      End;
     OC_DEBUG_GENERAL:
      Case FieldIdx Of
       0: Begin
        Dlg.Data.BreakOnFirstError :=
         Not Dlg.Data.BreakOnFirstError;
        Dlg.Modified := True;
       End;
       1: Begin
        Dlg.Data.StepIntoProperties :=
         Not Dlg.Data.StepIntoProperties;
        Dlg.Modified := True;
       End;
      End;
     OC_DEBUG_OUTPUT:
      If FieldIdx = 0 Then
      Begin
       Dlg.Data.ShowDebugMessages :=
        Not Dlg.Data.ShowDebugMessages;
       Dlg.Modified := True;
      End;
    End;
    DrawOptionsDialog(Dlg);
    Exit;
   End;
   { Clic sur les boutons OK / Annuler }
   BtnR := DialogButtonHitTest(Dlg.Base, Ev.MouseX,
    Ev.MouseY);
   If BtnR >= 0 Then
   Begin
    If BtnR = 0 Then
    Begin
     Dlg.Confirmed := True;
     Dlg.Base.Result := DR_OK;
    End
    Else
    Begin
     Dlg.Confirmed := False;
     Dlg.Data := Dlg.OriginalData;
     Dlg.Base.Result := DR_CANCEL;
    End;
    CloseDialog(Dlg.Base);
   End;
  End;
 End;
End;

{ --- Afficher le dialogue des options --- }

Procedure ShowOptionsDialog(Var Dlg: TOptionsDialog);
Begin
 InitOptionsDialog(Dlg);
 Dlg.Base.Visible := True;
 DrawOptionsDialog(Dlg);
End;

{ --- Ecrire une ligne cle=valeur dans le fichier INI --- }

Procedure WriteCfgLine(Var F: Text; Key, Value: String);
Begin
 WriteLn(F, Key, '=', Value);
End;

{ --- Lire une ligne cle=valeur depuis une chaine --- }

Function ReadCfgLine(Line: String;
 Var Key, Value: String): Boolean;
Var
 P: Integer;
Begin
 ReadCfgLine := False;
 Key := '';
 Value := '';
 If Length(Line) = 0 Then Exit;
 If Line[1] = '[' Then Exit;
 If Line[1] = ';' Then Exit;
 P := Pos('=', Line);
 If P = 0 Then Exit;
 Key := Copy(Line, 1, P - 1);
 Value := Copy(Line, P + 1, Length(Line) - P);
 ReadCfgLine := True;
End;

{ --- Convertir un booleen en chaine --- }

Function BoolToStr(B: Boolean): String;
Begin
 If B Then
  BoolToStr := '1'
 Else
  BoolToStr := '0';
End;

{ --- Convertir une chaine en booleen --- }

Function StrToBool(S: String): Boolean;
Begin
 StrToBool := (S = '1') Or (S = 'True') Or (S = 'true');
End;

{ --- Sauvegarder les options dans un fichier INI --- }

Procedure SaveOptions(Var Data: TOptionsDialogData;
 FileName: String);
Var
 F: Text;
 S: String;
Begin
 Assign(F, FileName);
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 WriteLn(F, '[Environnement]');
 WriteCfgLine(F, 'ThemeName', Data.ThemeName);
 WriteCfgLine(F, 'FontName', Data.FontName);
 Str(Data.FontSize, S);
 WriteCfgLine(F, 'FontSize', S);
 Str(Ord(Data.StartupAction), S);
 WriteCfgLine(F, 'StartupAction', S);
 WriteCfgLine(F, 'AutoSaveEnabled',
  BoolToStr(Data.AutoSaveEnabled));
 Str(Data.AutoSaveInterval, S);
 WriteCfgLine(F, 'AutoSaveInterval', S);
 WriteLn(F, '');
 WriteLn(F, '[Editeur]');
 WriteCfgLine(F, 'ShowLineNumbers',
  BoolToStr(Data.ShowLineNumbers));
 WriteCfgLine(F, 'WordWrap', BoolToStr(Data.WordWrap));
 WriteCfgLine(F, 'ShowWhitespace',
  BoolToStr(Data.ShowWhitespace));
 WriteCfgLine(F, 'ShowIndentGuides',
  BoolToStr(Data.ShowIndentGuides));
 Str(Data.TabSize, S);
 WriteCfgLine(F, 'TabSize', S);
 WriteCfgLine(F, 'InsertSpaces',
  BoolToStr(Data.InsertSpaces));
 Str(Data.IndentSize, S);
 WriteCfgLine(F, 'IndentSize', S);
 WriteCfgLine(F, 'SmoothScroll',
  BoolToStr(Data.SmoothScroll));
 Str(Data.ScrollMargin, S);
 WriteCfgLine(F, 'ScrollMargin', S);
 WriteCfgLine(F, 'AutoIndent',
  BoolToStr(Data.AutoIndent));
 WriteCfgLine(F, 'AutoBraces',
  BoolToStr(Data.AutoBraces));
 WriteLn(F, '');
 WriteLn(F, '[Projets]');
 WriteCfgLine(F, 'DefaultProjectPath',
  Data.DefaultProjectPath);
 WriteCfgLine(F, 'ShowOutputOnBuild',
  BoolToStr(Data.ShowOutputOnBuild));
 WriteCfgLine(F, 'BuildVerbose',
  BoolToStr(Data.BuildVerbose));
 Str(Data.ParallelBuild, S);
 WriteCfgLine(F, 'ParallelBuild', S);
 WriteLn(F, '');
 WriteLn(F, '[Debogage]');
 WriteCfgLine(F, 'BreakOnFirstError',
  BoolToStr(Data.BreakOnFirstError));
 WriteCfgLine(F, 'StepIntoProperties',
  BoolToStr(Data.StepIntoProperties));
 WriteCfgLine(F, 'ShowDebugMessages',
  BoolToStr(Data.ShowDebugMessages));
 Close(F);
End;

{ --- Charger les options depuis un fichier INI --- }

Procedure LoadOptions(Var Data: TOptionsDialogData;
 FileName: String);
Var
 F: Text;
 Line, Key, Value: String;
 Code: Integer;
Begin
 InitOptionsDialogData(Data);
 Assign(F, FileName);
 {$I-}
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While Not Eof(F) Do
 Begin
  ReadLn(F, Line);
  If Not ReadCfgLine(Line, Key, Value) Then Continue;
  If Key = 'ThemeName' Then
   Data.ThemeName := Value
  Else If Key = 'FontName' Then
   Data.FontName := Value
  Else If Key = 'FontSize' Then
  Begin
   Val(Value, Data.FontSize, Code);
   If Code <> 0 Then Data.FontSize := 10;
  End
  Else If Key = 'StartupAction' Then
  Begin
   Val(Value, Code, Code);
   Case Code Of
    0: Data.StartupAction := OSA_NOTHING;
    1: Data.StartupAction := OSA_LAST_PROJECT;
    2: Data.StartupAction := OSA_START_PAGE;
   End;
  End
  Else If Key = 'AutoSaveEnabled' Then
   Data.AutoSaveEnabled := StrToBool(Value)
  Else If Key = 'AutoSaveInterval' Then
  Begin
   Val(Value, Data.AutoSaveInterval, Code);
   If Code <> 0 Then Data.AutoSaveInterval := 300;
  End
  Else If Key = 'ShowLineNumbers' Then
   Data.ShowLineNumbers := StrToBool(Value)
  Else If Key = 'WordWrap' Then
   Data.WordWrap := StrToBool(Value)
  Else If Key = 'ShowWhitespace' Then
   Data.ShowWhitespace := StrToBool(Value)
  Else If Key = 'ShowIndentGuides' Then
   Data.ShowIndentGuides := StrToBool(Value)
  Else If Key = 'TabSize' Then
  Begin
   Val(Value, Data.TabSize, Code);
   If Code <> 0 Then Data.TabSize := 4;
  End
  Else If Key = 'InsertSpaces' Then
   Data.InsertSpaces := StrToBool(Value)
  Else If Key = 'IndentSize' Then
  Begin
   Val(Value, Data.IndentSize, Code);
   If Code <> 0 Then Data.IndentSize := 4;
  End
  Else If Key = 'SmoothScroll' Then
   Data.SmoothScroll := StrToBool(Value)
  Else If Key = 'ScrollMargin' Then
  Begin
   Val(Value, Data.ScrollMargin, Code);
   If Code <> 0 Then Data.ScrollMargin := 3;
  End
  Else If Key = 'AutoIndent' Then
   Data.AutoIndent := StrToBool(Value)
  Else If Key = 'AutoBraces' Then
   Data.AutoBraces := StrToBool(Value)
  Else If Key = 'DefaultProjectPath' Then
   Data.DefaultProjectPath := Value
  Else If Key = 'ShowOutputOnBuild' Then
   Data.ShowOutputOnBuild := StrToBool(Value)
  Else If Key = 'BuildVerbose' Then
   Data.BuildVerbose := StrToBool(Value)
  Else If Key = 'ParallelBuild' Then
  Begin
   Val(Value, Data.ParallelBuild, Code);
   If Code <> 0 Then Data.ParallelBuild := 1;
  End
  Else If Key = 'BreakOnFirstError' Then
   Data.BreakOnFirstError := StrToBool(Value)
  Else If Key = 'StepIntoProperties' Then
   Data.StepIntoProperties := StrToBool(Value)
  Else If Key = 'ShowDebugMessages' Then
   Data.ShowDebugMessages := StrToBool(Value);
 End;
 Close(F);
End;

{ --- Obtenir la categorie selectionnee --- }

Function GetSelectedOptionCategory(
 Var Dlg: TOptionsDialog): TOptionCategory;
Begin
 If (Dlg.SelectedCategory >= 0) And
  (Dlg.SelectedCategory < Dlg.CategoryCount) Then
  GetSelectedOptionCategory :=
   Dlg.Categories[Dlg.SelectedCategory].Category
 Else
  GetSelectedOptionCategory := OC_ENV_GENERAL;
End;

{ --- Verifier si le dialogue options est visible --- }

Function IsOptionsDialogVisible(
 Var Dlg: TOptionsDialog): Boolean;
Begin
 IsOptionsDialogVisible := Dlg.Base.Visible;
End;

{ --- Verifier si les options ont ete modifiees --- }

Function IsOptionsModified(
 Var Dlg: TOptionsDialog): Boolean;
Begin
 IsOptionsModified := Dlg.Modified;
End;

{ --- Accesseurs pour les donnees d options --- }

Function GetOptionThemeName(
 Var D: TOptionsDialogData): String;
Begin
 GetOptionThemeName := D.ThemeName;
End;

Function GetOptionFontSize(
 Var D: TOptionsDialogData): Integer;
Begin
 GetOptionFontSize := D.FontSize;
End;

Function GetOptionTabSize(
 Var D: TOptionsDialogData): Integer;
Begin
 GetOptionTabSize := D.TabSize;
End;

Function IsOptionAutoSaveEnabled(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionAutoSaveEnabled := D.AutoSaveEnabled;
End;

Function GetOptionAutoSaveInterval(
 Var D: TOptionsDialogData): Integer;
Begin
 GetOptionAutoSaveInterval := D.AutoSaveInterval;
End;

Function IsOptionShowLineNumbers(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionShowLineNumbers := D.ShowLineNumbers;
End;

Function IsOptionWordWrap(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionWordWrap := D.WordWrap;
End;

Function IsOptionShowWhitespace(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionShowWhitespace := D.ShowWhitespace;
End;

Function IsOptionAutoIndent(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionAutoIndent := D.AutoIndent;
End;

Function IsOptionInsertSpaces(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionInsertSpaces := D.InsertSpaces;
End;

Function GetOptionDefaultProjectPath(
 Var D: TOptionsDialogData): String;
Begin
 GetOptionDefaultProjectPath := D.DefaultProjectPath;
End;

Function IsOptionShowOutputOnBuild(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionShowOutputOnBuild := D.ShowOutputOnBuild;
End;

Function IsOptionBuildVerbose(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionBuildVerbose := D.BuildVerbose;
End;

Function IsOptionBreakOnFirstError(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionBreakOnFirstError := D.BreakOnFirstError;
End;

Function IsOptionShowDebugMessages(
 Var D: TOptionsDialogData): Boolean;
Begin
 IsOptionShowDebugMessages := D.ShowDebugMessages;
End;

Function GetOptionStartupAction(
 Var D: TOptionsDialogData): TOptStartupAction;
Begin
 GetOptionStartupAction := D.StartupAction;
End;

{ --- Nombre de categories dans le dialogue --- }

Function OptionCategoryCount(
 Var Dlg: TOptionsDialog): Integer;
Begin
 OptionCategoryCount := Dlg.CategoryCount;
End;

{ ============================================================
  TODO 24 - RECHERCHER ET REMPLACER [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser les options de recherche --- }

Procedure InitFindOptions(Var Opt: TFindOptions);
Begin
 Opt.MatchCase := False;
 Opt.WholeWord := False;
 Opt.UseRegex := False;
 Opt.SearchScope := SS_CURRENT_DOC;
 Opt.SearchUp := False;
 Opt.WrapAround := True;
End;

{ --- Initialiser le dialogue de recherche/remplacement --- }

Procedure InitFindReplaceDialog(Var Dlg: TFindReplaceDialog);
Begin
 InitDialog(Dlg.Base, 'Rechercher', FIND_DLG_WIDTH, FIND_DLG_HEIGHT);
 Dlg.Base.Visible := False;
 Dlg.Base.HasCancel := True;
 Dlg.SearchText := '';
 Dlg.ReplaceText := '';
 InitFindOptions(Dlg.Options);
 Dlg.IsReplaceMode := False;
 Dlg.SearchCursor := 0;
 Dlg.ReplaceCursor := 0;
 Dlg.FoundCount := 0;
 Dlg.LastFoundLine := 0;
 Dlg.LastFoundCol := 0;
 Dlg.HighlightAll := True;
End;

{ --- Initialiser le dialogue aller a la ligne --- }

Procedure InitGoToLineDialog(Var Dlg: TGoToLineDialog);
Begin
 InitDialog(Dlg.Base, 'Aller a la ligne', GOTO_DLG_WIDTH,
  GOTO_DLG_HEIGHT);
 Dlg.Base.Visible := False;
 Dlg.Base.HasCancel := True;
 Dlg.LineNumber := 1;
 Dlg.MaxLine := 1;
 Dlg.InputText := '1';
 Dlg.InputCursor := 1;
 Dlg.Confirmed := False;
End;

{ --- Nom de la portee de recherche --- }

Function SearchScopeName(Scope: TSearchScope): String;
Begin
 Case Scope Of
  SS_CURRENT_DOC:     SearchScopeName := 'Document courant';
  SS_ALL_OPEN_DOCS:   SearchScopeName := 'Tous les documents';
  SS_CURRENT_PROJECT: SearchScopeName := 'Projet entier';
  SS_ENTIRE_SOLUTION: SearchScopeName := 'Solution entiere';
  Else                SearchScopeName := 'Inconnu';
 End;
End;

{ --- Dessiner le dialogue de recherche/remplacement --- }

Procedure DrawFindReplaceDialog(Var Dlg: TFindReplaceDialog);
Var
 X1, Y1, CurY, FX: Integer;
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 X1 := Dlg.Base.X + FIND_PADDING;
 Y1 := Dlg.Base.Y + DLG_TITLE_HEIGHT + FIND_PADDING;
 FX := X1 + FIND_LABEL_WIDTH;
 CurY := Y1;
 { Etiquette et champ Rechercher }
 SetColor(CLR_MENU_TEXT);
 OutTextXY(X1, CurY + 4, 'Rechercher :');
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(FX, CurY, FX + FIND_FIELD_WIDTH - 1,
  CurY + FIND_FIELD_HEIGHT - 1);
 SetColor(CLR_BORDER);
 Rectangle(FX, CurY, FX + FIND_FIELD_WIDTH - 1,
  CurY + FIND_FIELD_HEIGHT - 1);
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(FX + 4, CurY + 4, Dlg.SearchText);
 CurY := CurY + FIND_FIELD_HEIGHT + FIND_PADDING;
 { Etiquette et champ Remplacer (si mode remplacement) }
 If Dlg.IsReplaceMode Then Begin
  SetColor(CLR_MENU_TEXT);
  OutTextXY(X1, CurY + 4, 'Remplacer :');
  SetFillStyle(SolidFill, CLR_EDITOR_BG);
  Bar(FX, CurY, FX + FIND_FIELD_WIDTH - 1,
   CurY + FIND_FIELD_HEIGHT - 1);
  SetColor(CLR_BORDER);
  Rectangle(FX, CurY, FX + FIND_FIELD_WIDTH - 1,
   CurY + FIND_FIELD_HEIGHT - 1);
  SetColor(CLR_EDITOR_TEXT);
  OutTextXY(FX + 4, CurY + 4, Dlg.ReplaceText);
  CurY := CurY + FIND_FIELD_HEIGHT + FIND_PADDING;
 End;
 { Options : cases a cocher }
 SetColor(CLR_MENU_TEXT);
 { Case Respecter la casse }
 SetColor(CLR_BORDER);
 Rectangle(X1, CurY, X1 + FIND_CHECK_SIZE - 1,
  CurY + FIND_CHECK_SIZE - 1);
 If Dlg.Options.MatchCase Then Begin
  Line(X1 + 2, CurY + 7, X1 + 5, CurY + 11);
  Line(X1 + 5, CurY + 11, X1 + 12, CurY + 2);
 End;
 SetColor(CLR_MENU_TEXT);
 OutTextXY(X1 + FIND_CHECK_SIZE + 4, CurY + 1, 'Casse');
 { Case Mot entier }
 SetColor(CLR_BORDER);
 Rectangle(X1 + 100, CurY, X1 + 100 + FIND_CHECK_SIZE - 1,
  CurY + FIND_CHECK_SIZE - 1);
 If Dlg.Options.WholeWord Then Begin
  Line(X1 + 102, CurY + 7, X1 + 105, CurY + 11);
  Line(X1 + 105, CurY + 11, X1 + 112, CurY + 2);
 End;
 SetColor(CLR_MENU_TEXT);
 OutTextXY(X1 + 100 + FIND_CHECK_SIZE + 4, CurY + 1, 'Mot entier');
 { Boutons }
 DrawDialogButtons(Dlg.Base);
End;

{ --- Dessiner le dialogue aller a la ligne --- }

Procedure DrawGoToLineDialog(Var Dlg: TGoToLineDialog);
Var
 X1, Y1, FX, CurY: Integer;
 Info: String;
Begin
 If Not Dlg.Base.Visible Then Exit;
 DrawDialogFrame(Dlg.Base);
 X1 := Dlg.Base.X + FIND_PADDING;
 Y1 := Dlg.Base.Y + DLG_TITLE_HEIGHT + FIND_PADDING;
 FX := X1 + FIND_LABEL_WIDTH;
 CurY := Y1;
 { Etiquette }
 SetColor(CLR_MENU_TEXT);
 OutTextXY(X1, CurY + 4, 'Ligne (1-' + IntToStr(Dlg.MaxLine) + ') :');
 { Champ de saisie }
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(FX, CurY, FX + 120, CurY + FIND_FIELD_HEIGHT - 1);
 SetColor(CLR_BORDER);
 Rectangle(FX, CurY, FX + 120, CurY + FIND_FIELD_HEIGHT - 1);
 SetColor(CLR_EDITOR_TEXT);
 OutTextXY(FX + 4, CurY + 4, Dlg.InputText);
 CurY := CurY + FIND_FIELD_HEIGHT + FIND_PADDING;
 { Information }
 Info := 'Nombre de lignes : ' + IntToStr(Dlg.MaxLine);
 SetColor(CLR_MENU_TEXT);
 OutTextXY(X1, CurY, Info);
 { Boutons }
 DrawDialogButtons(Dlg.Base);
End;

{ --- Recherche avant dans un tampon de texte --- }

Function FindTextForward(Var Buf: TTextBuffer; AText: String;
 StartLine, StartCol: LongInt; CaseSens: Boolean;
 Var FoundLine, FoundCol: LongInt): Boolean;
Var
 I: LongInt;
 P: Integer;
 S, T: String;
Begin
 FindTextForward := False;
 If CaseSens Then
  T := AText
 Else
  T := LowerCaseStr(AText);
 For I := StartLine To Buf.LineCount - 1 Do Begin
  If CaseSens Then
   S := Buf.Lines[I]
  Else
   S := LowerCaseStr(Buf.Lines[I]);
  If I = StartLine Then
   P := Pos(T, Copy(S, StartCol, Length(S) - StartCol + 1))
  Else
   P := Pos(T, S);
  If P > 0 Then Begin
   FoundLine := I;
   If I = StartLine Then
    FoundCol := StartCol + P - 1
   Else
    FoundCol := P;
   FindTextForward := True;
   Exit;
  End;
 End;
End;

{ --- Recherche arriere dans un tampon de texte --- }

Function FindTextBackward(Var Buf: TTextBuffer; AText: String;
 StartLine, StartCol: LongInt; CaseSens: Boolean;
 Var FoundLine, FoundCol: LongInt): Boolean;
Var
 I: LongInt;
 P, LastP: Integer;
 S, T, Sub: String;
Begin
 FindTextBackward := False;
 If CaseSens Then
  T := AText
 Else
  T := LowerCaseStr(AText);
 For I := StartLine DownTo 0 Do Begin
  If CaseSens Then
   S := Buf.Lines[I]
  Else
   S := LowerCaseStr(Buf.Lines[I]);
  If I = StartLine Then
   Sub := Copy(S, 1, StartCol - 1)
  Else
   Sub := S;
  { Trouver la derniere occurrence dans Sub }
  LastP := 0;
  P := Pos(T, Sub);
  While P > 0 Do Begin
   LastP := P;
   P := Pos(T, Copy(Sub, LastP + 1,
    Length(Sub) - LastP));
   If P > 0 Then
    P := P + LastP;
  End;
  If LastP > 0 Then Begin
   FoundLine := I;
   FoundCol := LastP;
   FindTextBackward := True;
   Exit;
  End;
 End;
End;

{ --- Verifier si une occurrence est un mot entier --- }

Function MatchesWholeWord(Var Buf: TTextBuffer;
 ALine, ACol, ALen: LongInt): Boolean;
Var
 S: String;
 ChBefore, ChAfter: Char;
Begin
 MatchesWholeWord := False;
 If (ALine < 0) Or (ALine >= Buf.LineCount) Then Exit;
 S := Buf.Lines[ALine];
 If ACol > 1 Then
  ChBefore := S[ACol - 1]
 Else
  ChBefore := ' ';
 If ACol + ALen - 1 < Length(S) Then
  ChAfter := S[ACol + ALen]
 Else
  ChAfter := ' ';
 { Un separateur de mot est un caractere non alphanum }
 If ((ChBefore < 'A') Or (ChBefore > 'Z')) And
    ((ChBefore < 'a') Or (ChBefore > 'z')) And
    ((ChBefore < '0') Or (ChBefore > '9')) And
    (ChBefore <> '_') And
    ((ChAfter < 'A') Or (ChAfter > 'Z')) And
    ((ChAfter < 'a') Or (ChAfter > 'z')) And
    ((ChAfter < '0') Or (ChAfter > '9')) And
    (ChAfter <> '_') Then
  MatchesWholeWord := True;
End;

{ --- Trouver l occurrence suivante dans l editeur --- }

Function FindNext(Var Ed: TEditor; ASearchText: String;
 Opt: TFindOptions): Boolean;
Var
 FL, FC, SL, SC: LongInt;
Begin
 FindNext := False;
 If Length(ASearchText) = 0 Then Exit;
 SL := Ed.CursorLine;
 SC := Ed.CursorCol + 1;
 If SC > Length(Ed.Buffer.Lines[SL]) Then Begin
  Inc(SL);
  SC := 1;
 End;
 If FindTextForward(Ed.Buffer, ASearchText, SL, SC,
  Opt.MatchCase, FL, FC) Then Begin
  If Opt.WholeWord Then Begin
   If Not MatchesWholeWord(Ed.Buffer, FL, FC,
    Length(ASearchText)) Then Begin
    { Continuer la recherche apres cette occurrence }
    SL := FL;
    SC := FC + 1;
    While FindTextForward(Ed.Buffer, ASearchText, SL, SC,
     Opt.MatchCase, FL, FC) Do Begin
     If MatchesWholeWord(Ed.Buffer, FL, FC,
      Length(ASearchText)) Then Begin
      Ed.CursorLine := FL;
      Ed.CursorCol := FC;
      FindNext := True;
      Exit;
     End;
     SL := FL;
     SC := FC + 1;
    End;
    { Boucler si WrapAround }
    If Opt.WrapAround Then Begin
     If FindTextForward(Ed.Buffer, ASearchText, 0, 1,
      Opt.MatchCase, FL, FC) Then Begin
      If MatchesWholeWord(Ed.Buffer, FL, FC,
       Length(ASearchText)) Then Begin
       Ed.CursorLine := FL;
       Ed.CursorCol := FC;
       FindNext := True;
      End;
     End;
    End;
    Exit;
   End;
  End;
  Ed.CursorLine := FL;
  Ed.CursorCol := FC;
  FindNext := True;
 End Else If Opt.WrapAround Then Begin
  { Boucler depuis le debut }
  If FindTextForward(Ed.Buffer, ASearchText, 0, 1,
   Opt.MatchCase, FL, FC) Then Begin
   If Opt.WholeWord And Not MatchesWholeWord(Ed.Buffer,
    FL, FC, Length(ASearchText)) Then
    Exit;
   Ed.CursorLine := FL;
   Ed.CursorCol := FC;
   FindNext := True;
  End;
 End;
End;

{ --- Trouver l occurrence precedente dans l editeur --- }

Function FindPrevious(Var Ed: TEditor; ASearchText: String;
 Opt: TFindOptions): Boolean;
Var
 FL, FC, SL, SC: LongInt;
Begin
 FindPrevious := False;
 If Length(ASearchText) = 0 Then Exit;
 SL := Ed.CursorLine;
 SC := Ed.CursorCol;
 If SC < 1 Then Begin
  Dec(SL);
  If SL < 0 Then Begin
   If Opt.WrapAround Then Begin
    SL := Ed.Buffer.LineCount - 1;
    SC := Length(Ed.Buffer.Lines[SL]) + 1;
   End Else
    Exit;
  End Else
   SC := Length(Ed.Buffer.Lines[SL]) + 1;
 End;
 If FindTextBackward(Ed.Buffer, ASearchText, SL, SC,
  Opt.MatchCase, FL, FC) Then Begin
  If Opt.WholeWord And Not MatchesWholeWord(Ed.Buffer,
   FL, FC, Length(ASearchText)) Then Begin
   SL := FL;
   SC := FC;
   While FindTextBackward(Ed.Buffer, ASearchText, SL, SC,
    Opt.MatchCase, FL, FC) Do Begin
    If MatchesWholeWord(Ed.Buffer, FL, FC,
     Length(ASearchText)) Then Begin
     Ed.CursorLine := FL;
     Ed.CursorCol := FC;
     FindPrevious := True;
     Exit;
    End;
    SL := FL;
    SC := FC;
   End;
   Exit;
  End;
  Ed.CursorLine := FL;
  Ed.CursorCol := FC;
  FindPrevious := True;
 End Else If Opt.WrapAround Then Begin
  SL := Ed.Buffer.LineCount - 1;
  SC := Length(Ed.Buffer.Lines[SL]) + 1;
  If FindTextBackward(Ed.Buffer, ASearchText, SL, SC,
   Opt.MatchCase, FL, FC) Then Begin
   If Opt.WholeWord And Not MatchesWholeWord(Ed.Buffer,
    FL, FC, Length(ASearchText)) Then
    Exit;
   Ed.CursorLine := FL;
   Ed.CursorCol := FC;
   FindPrevious := True;
  End;
 End;
End;

{ --- Remplacer l occurrence courante et chercher la suivante --- }

Procedure ReplaceNext(Var Ed: TEditor;
 ASearchText, AReplaceText: String; Opt: TFindOptions);
Var
 S: String;
 Col: LongInt;
Begin
 If Length(ASearchText) = 0 Then Exit;
 { Verifier que le curseur est sur une occurrence }
 S := Ed.Buffer.Lines[Ed.CursorLine];
 If Opt.MatchCase Then Begin
  If Copy(S, Ed.CursorCol, Length(ASearchText)) = ASearchText Then
  Begin
   Delete(S, Ed.CursorCol, Length(ASearchText));
   Insert(AReplaceText, S, Ed.CursorCol);
   Ed.Buffer.Lines[Ed.CursorLine] := S;
   Ed.Buffer.Modified := True;
   Col := Ed.CursorCol + Length(AReplaceText);
   Ed.CursorCol := Col;
  End;
 End Else Begin
  If LowerCaseStr(Copy(S, Ed.CursorCol,
   Length(ASearchText))) = LowerCaseStr(ASearchText) Then
  Begin
   Delete(S, Ed.CursorCol, Length(ASearchText));
   Insert(AReplaceText, S, Ed.CursorCol);
   Ed.Buffer.Lines[Ed.CursorLine] := S;
   Ed.Buffer.Modified := True;
   Col := Ed.CursorCol + Length(AReplaceText);
   Ed.CursorCol := Col;
  End;
 End;
 { Chercher la suivante }
 FindNext(Ed, ASearchText, Opt);
End;

{ --- Remplacer toutes les occurrences --- }

Function ReplaceAll(Var Ed: TEditor;
 ASearchText, AReplaceText: String;
 Opt: TFindOptions): Integer;
Var
 Count: Integer;
 I: LongInt;
 P: Integer;
 S, T, SLine: String;
 Diff: Integer;
Begin
 Count := 0;
 If Length(ASearchText) = 0 Then Begin
  ReplaceAll := 0;
  Exit;
 End;
 If Opt.MatchCase Then
  T := ASearchText
 Else
  T := LowerCaseStr(ASearchText);
 Diff := Length(AReplaceText) - Length(ASearchText);
 For I := 0 To Ed.Buffer.LineCount - 1 Do Begin
  S := Ed.Buffer.Lines[I];
  If Opt.MatchCase Then
   SLine := S
  Else
   SLine := LowerCaseStr(S);
  P := Pos(T, SLine);
  While P > 0 Do Begin
   If Opt.WholeWord And Not MatchesWholeWord(
    Ed.Buffer, I, P, Length(ASearchText)) Then Begin
    { Sauter cette occurrence }
    SLine := Copy(SLine, P + Length(T),
     Length(SLine) - P - Length(T) + 1);
    P := Pos(T, SLine);
    If P > 0 Then
     P := P + (Length(S) - Length(SLine));
   End Else Begin
    Delete(S, P, Length(ASearchText));
    Insert(AReplaceText, S, P);
    Ed.Buffer.Lines[I] := S;
    Inc(Count);
    { Mettre a jour la ligne de recherche }
    If Opt.MatchCase Then
     SLine := S
    Else
     SLine := LowerCaseStr(S);
    P := Pos(T, Copy(SLine, P + Length(AReplaceText),
     Length(SLine) - P - Length(AReplaceText) + 1));
    If P > 0 Then
     P := P + (Length(S) - Length(Copy(SLine,
      1, Length(SLine)))) +
      Length(AReplaceText);
   End;
  End;
 End;
 If Count > 0 Then
  Ed.Buffer.Modified := True;
 ReplaceAll := Count;
End;

{ --- Recherche dans les fichiers (resultats dans panneau sortie) --- }

Procedure FindInFiles(ASearchText: String;
 Scope: TSearchScope; Opt: TFindOptions);
Var
 I: LongInt;
 P: Integer;
 S, T, SLine: String;
 LineNum: LongInt;
 MatchCount: Integer;
 Header: String;
Begin
 If Length(ASearchText) = 0 Then Exit;
 If Opt.MatchCase Then
  T := ASearchText
 Else
  T := LowerCaseStr(ASearchText);
 Header := 'Recherche de "' + ASearchText + '" dans ' +
  SearchScopeName(Scope);
 AppendOutput(OutputPanel, Header, Ord(OTK_SEARCH));
 AppendOutput(OutputPanel, '---', Ord(OTK_SEARCH));
 MatchCount := 0;
 { Pour le moment, recherche dans le document courant uniquement }
 { Les autres portees necessitent l acces au gestionnaire de     }
 { fenetres et au projet (TODO futur)                            }
 For I := 0 To OutputPanel.LineCounts[Ord(OTK_SEARCH)] - 1 Do
  ; { Placeholder : iterer sur les fichiers ouverts }
 AppendOutput(OutputPanel, 'Recherche terminee. ' +
  IntToStr(MatchCount) + ' occurrence(s) trouvee(s).',
  Ord(OTK_SEARCH));
End;

{ --- Compter les occurrences dans un tampon --- }

Function CountOccurrences(Var Buf: TTextBuffer; AText: String;
 CaseSens: Boolean): Integer;
Var
 Count: Integer;
 I: LongInt;
 P: Integer;
 S, T, Sub: String;
Begin
 Count := 0;
 If Length(AText) = 0 Then Begin
  CountOccurrences := 0;
  Exit;
 End;
 If CaseSens Then
  T := AText
 Else
  T := LowerCaseStr(AText);
 For I := 0 To Buf.LineCount - 1 Do Begin
  If CaseSens Then
   S := Buf.Lines[I]
  Else
   S := LowerCaseStr(Buf.Lines[I]);
  Sub := S;
  P := Pos(T, Sub);
  While P > 0 Do Begin
   Inc(Count);
   Sub := Copy(Sub, P + Length(T),
    Length(Sub) - P - Length(T) + 1);
   P := Pos(T, Sub);
  End;
 End;
 CountOccurrences := Count;
End;

{ --- Surligner toutes les occurrences dans l editeur --- }

Procedure HighlightOccurrences(Var Ed: TEditor;
 ASearchText: String; CaseSens: Boolean);
Var
 FL, FC: LongInt;
 SL, SC: LongInt;
 Count: Integer;
Begin
 If Length(ASearchText) = 0 Then Exit;
 SL := 0;
 SC := 1;
 Count := 0;
 While (Count < MAX_FIND_HIGHLIGHTS) And
  FindTextForward(Ed.Buffer, ASearchText, SL, SC,
   CaseSens, FL, FC) Do Begin
  { Marquer la zone trouvee en surbrillance }
  { Dessin d un rectangle jaune derriere le texte }
  If (FL >= Ed.ScrollLine) And
     (FL < Ed.ScrollLine + Ed.VisibleLines) Then Begin
   SetFillStyle(SolidFill, CLR_LINE_HIGHLIGHT);
   Bar(Ed.X + Ed.GutterWidth +
    (FC - Ed.ScrollCol) * Ed.CharWidth,
    Ed.Y + (FL - Ed.ScrollLine) * Ed.CharHeight,
    Ed.X + Ed.GutterWidth +
    (FC - Ed.ScrollCol + Length(ASearchText)) * Ed.CharWidth - 1,
    Ed.Y + (FL - Ed.ScrollLine + 1) * Ed.CharHeight - 1);
   SetColor(CLR_EDITOR_TEXT);
   OutTextXY(Ed.X + Ed.GutterWidth +
    (FC - Ed.ScrollCol) * Ed.CharWidth,
    Ed.Y + (FL - Ed.ScrollLine) * Ed.CharHeight,
    Copy(Ed.Buffer.Lines[FL], FC, Length(ASearchText)));
  End;
  Inc(Count);
  SL := FL;
  SC := FC + 1;
  If SC > Length(Ed.Buffer.Lines[SL]) Then Begin
   Inc(SL);
   SC := 1;
   If SL >= Ed.Buffer.LineCount Then
    Break;
  End;
 End;
End;

{ --- Effacer les surbrillances de recherche --- }

Procedure ClearHighlights(Var Ed: TEditor);
Begin
 { Redessiner la zone editeur efface les surbrillances }
 { Un repaint complet est necessaire }
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(Ed.X, Ed.Y, Ed.X + Ed.Width - 1, Ed.Y + Ed.Height - 1);
End;

{ --- Gerer les touches dans le dialogue de recherche --- }

Procedure HandleFindDialogKey(Var Dlg: TFindReplaceDialog;
 Key: Char);
Begin
 If Key = #27 Then Begin
  { Echap : fermer le dialogue }
  Dlg.Base.Result := DR_CANCEL;
  CloseDialog(Dlg.Base);
 End Else If Key = #13 Then Begin
  { Entree : valider (lancer la recherche) }
  Dlg.Base.Result := DR_OK;
 End Else If Key = #9 Then Begin
  { Tab : basculer entre champ recherche et remplacement }
  If Dlg.IsReplaceMode Then Begin
   { Basculer le focus (simplifie via curseur) }
   If Dlg.SearchCursor > 0 Then Begin
    Dlg.SearchCursor := 0;
    Dlg.ReplaceCursor := Length(Dlg.ReplaceText);
   End Else Begin
    Dlg.ReplaceCursor := 0;
    Dlg.SearchCursor := Length(Dlg.SearchText);
   End;
  End;
 End Else If Key = #8 Then Begin
  { Retour arriere }
  If (Dlg.ReplaceCursor > 0) And Dlg.IsReplaceMode And
     (Dlg.SearchCursor = 0) Then Begin
   Delete(Dlg.ReplaceText, Dlg.ReplaceCursor, 1);
   Dec(Dlg.ReplaceCursor);
  End Else If (Dlg.SearchCursor > 0) Then Begin
   Delete(Dlg.SearchText, Dlg.SearchCursor, 1);
   Dec(Dlg.SearchCursor);
  End;
 End Else If (Key >= ' ') And (Key <= '~') Then Begin
  { Caractere imprimable }
  If (Dlg.ReplaceCursor > 0) And Dlg.IsReplaceMode And
     (Dlg.SearchCursor = 0) Then Begin
   If Length(Dlg.ReplaceText) < 127 Then Begin
    Inc(Dlg.ReplaceCursor);
    Insert(Key, Dlg.ReplaceText, Dlg.ReplaceCursor);
   End;
  End Else Begin
   If Length(Dlg.SearchText) < 127 Then Begin
    Inc(Dlg.SearchCursor);
    Insert(Key, Dlg.SearchText, Dlg.SearchCursor);
   End;
  End;
 End;
End;

{ --- Gerer les evenements dans le dialogue de recherche --- }

Procedure HandleFindDialogEvent(Var Dlg: TFindReplaceDialog;
 EvtType: Integer; Key: Char; MX, MY: Integer);
Var
 ChkY: Integer;
 X1: Integer;
Begin
 If Not Dlg.Base.Visible Then Exit;
 If EvtType = 1 Then Begin
  { Evenement clavier }
  HandleFindDialogKey(Dlg, Key);
  DrawFindReplaceDialog(Dlg);
 End Else If EvtType = 2 Then Begin
  { Evenement souris (clic) }
  X1 := Dlg.Base.X + FIND_PADDING;
  ChkY := Dlg.Base.Y + DLG_TITLE_HEIGHT + FIND_PADDING +
   FIND_FIELD_HEIGHT + FIND_PADDING;
  If Dlg.IsReplaceMode Then
   ChkY := ChkY + FIND_FIELD_HEIGHT + FIND_PADDING;
  { Clic sur case Respecter la casse }
  If (MX >= X1) And (MX <= X1 + FIND_CHECK_SIZE) And
     (MY >= ChkY) And (MY <= ChkY + FIND_CHECK_SIZE) Then
   Dlg.Options.MatchCase := Not Dlg.Options.MatchCase;
  { Clic sur case Mot entier }
  If (MX >= X1 + 100) And
     (MX <= X1 + 100 + FIND_CHECK_SIZE) And
     (MY >= ChkY) And (MY <= ChkY + FIND_CHECK_SIZE) Then
   Dlg.Options.WholeWord := Not Dlg.Options.WholeWord;
  DrawFindReplaceDialog(Dlg);
 End;
End;

{ --- Gerer les touches dans le dialogue aller a la ligne --- }

Procedure HandleGoToLineKey(Var Dlg: TGoToLineDialog;
 Key: Char);
Var
 N: LongInt;
 Code: Integer;
Begin
 If Key = #27 Then Begin
  Dlg.Confirmed := False;
  Dlg.Base.Result := DR_CANCEL;
  CloseDialog(Dlg.Base);
 End Else If Key = #13 Then Begin
  { Valider la saisie }
  Val(Dlg.InputText, N, Code);
  If (Code = 0) And (N >= 1) And (N <= Dlg.MaxLine) Then Begin
   Dlg.LineNumber := N;
   Dlg.Confirmed := True;
   Dlg.Base.Result := DR_OK;
   CloseDialog(Dlg.Base);
  End;
 End Else If Key = #8 Then Begin
  If (Dlg.InputCursor > 0) And (Length(Dlg.InputText) > 0) Then
  Begin
   Delete(Dlg.InputText, Dlg.InputCursor, 1);
   Dec(Dlg.InputCursor);
  End;
 End Else If (Key >= '0') And (Key <= '9') Then Begin
  If Length(Dlg.InputText) < 15 Then Begin
   Inc(Dlg.InputCursor);
   Insert(Key, Dlg.InputText, Dlg.InputCursor);
  End;
 End;
End;

{ --- Gerer les evenements dans le dialogue aller a la ligne --- }

Procedure HandleGoToLineEvent(Var Dlg: TGoToLineDialog;
 EvtType: Integer; Key: Char; MX, MY: Integer);
Begin
 If Not Dlg.Base.Visible Then Exit;
 If EvtType = 1 Then Begin
  HandleGoToLineKey(Dlg, Key);
  DrawGoToLineDialog(Dlg);
 End;
End;

{ --- Afficher le dialogue de recherche (Ctrl+F) --- }

Procedure ShowFindDialog(Var Dlg: TFindReplaceDialog);
Begin
 Dlg.IsReplaceMode := False;
 InitDialog(Dlg.Base, 'Rechercher', FIND_DLG_WIDTH,
  FIND_DLG_HEIGHT);
 Dlg.Base.HasCancel := True;
 Dlg.SearchCursor := Length(Dlg.SearchText);
 Dlg.FoundCount := 0;
 Dlg.Base.Visible := True;
 DrawFindReplaceDialog(Dlg);
End;

{ --- Afficher le dialogue de remplacement (Ctrl+H) --- }

Procedure ShowReplaceDialog(Var Dlg: TFindReplaceDialog);
Begin
 Dlg.IsReplaceMode := True;
 InitDialog(Dlg.Base, 'Remplacer', FIND_DLG_WIDTH,
  REPLACE_DLG_HEIGHT);
 Dlg.Base.HasCancel := True;
 Dlg.SearchCursor := Length(Dlg.SearchText);
 Dlg.ReplaceCursor := Length(Dlg.ReplaceText);
 Dlg.FoundCount := 0;
 Dlg.Base.Visible := True;
 DrawFindReplaceDialog(Dlg);
End;

{ --- Afficher le dialogue aller a la ligne --- }

Procedure ShowGoToLineDialog(Var Ed: TEditor);
Begin
 GoToLineDlg.MaxLine := Ed.Buffer.LineCount;
 GoToLineDlg.InputText := IntToStr(Ed.CursorLine + 1);
 GoToLineDlg.InputCursor := Length(GoToLineDlg.InputText);
 GoToLineDlg.Confirmed := False;
 InitDialog(GoToLineDlg.Base, 'Aller a la ligne',
  GOTO_DLG_WIDTH, GOTO_DLG_HEIGHT);
 GoToLineDlg.Base.HasCancel := True;
 GoToLineDlg.Base.Visible := True;
 DrawGoToLineDialog(GoToLineDlg);
End;

{ --- Obtenir le texte de recherche --- }

Function GetFindSearchText(
 Var Dlg: TFindReplaceDialog): String;
Begin
 GetFindSearchText := Dlg.SearchText;
End;

{ --- Obtenir le texte de remplacement --- }

Function GetFindReplaceText(
 Var Dlg: TFindReplaceDialog): String;
Begin
 GetFindReplaceText := Dlg.ReplaceText;
End;

{ --- Obtenir les options de recherche --- }

Function GetFindOptions(
 Var Dlg: TFindReplaceDialog): TFindOptions;
Begin
 GetFindOptions := Dlg.Options;
End;

{ --- Definir le texte de recherche --- }

Procedure SetFindSearchText(Var Dlg: TFindReplaceDialog;
 AText: String);
Begin
 Dlg.SearchText := AText;
 Dlg.SearchCursor := Length(AText);
End;

{ --- Definir le texte de remplacement --- }

Procedure SetFindReplaceText(Var Dlg: TFindReplaceDialog;
 AText: String);
Begin
 Dlg.ReplaceText := AText;
 Dlg.ReplaceCursor := Length(AText);
End;

{ --- Le dialogue de recherche est-il visible --- }

Function IsFindDialogVisible(
 Var Dlg: TFindReplaceDialog): Boolean;
Begin
 IsFindDialogVisible := Dlg.Base.Visible;
End;

{ --- Le dialogue aller a la ligne est-il visible --- }

Function IsGoToLineDialogVisible(
 Var Dlg: TGoToLineDialog): Boolean;
Begin
 IsGoToLineDialogVisible := Dlg.Base.Visible;
End;

{ --- Obtenir le numero de ligne saisi --- }

Function GetGoToLineNumber(
 Var Dlg: TGoToLineDialog): LongInt;
Begin
 GetGoToLineNumber := Dlg.LineNumber;
End;

{ --- La saisie aller a la ligne est-elle confirmee --- }

Function IsGoToLineConfirmed(
 Var Dlg: TGoToLineDialog): Boolean;
Begin
 IsGoToLineConfirmed := Dlg.Confirmed;
End;

{ --- Obtenir le nombre d occurrences trouvees --- }

Function GetFindFoundCount(
 Var Dlg: TFindReplaceDialog): Integer;
Begin
 GetFindFoundCount := Dlg.FoundCount;
End;

{ --- Le dialogue est-il en mode remplacement --- }

Function IsFindReplaceMode(
 Var Dlg: TFindReplaceDialog): Boolean;
Begin
 IsFindReplaceMode := Dlg.IsReplaceMode;
End;

{ ============================================================
  TODO 25 - INTEGRATION COMPILATEUR C# (CSCW32/CSC86) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser le contexte du compilateur C# --- }

Procedure InitCSCContext(Var Ctx: TCSCCompilerContext);
Begin
 Ctx.CompilerPath := '';
 Ctx.CompilerName := '';
 Ctx.CompilerFound := False;
 Ctx.LastResult := CR_NOT_FOUND;
 Ctx.ErrorCount := 0;
 Ctx.WarningCount := 0;
 Ctx.FilesCompiled := 0;
 Ctx.TotalFiles := 0;
 Ctx.OutputFile := '';
 Ctx.TempFile := CSC_TEMP_OUTPUT;
 Ctx.IsCompiling := False;
 Ctx.UseDebugSymbols := False;
 Ctx.UseVerbose := False;
 Ctx.UseWarnings := True;
End;

{ --- Chercher un compilateur dans le PATH ou repertoire courant --- }

Function FindCompiler(Name: String): String;
Var
 FullPath: String;
Begin
 FindCompiler := '';
 {$IFDEF WINDOWS}
 FullPath := FSearch(Name + '.exe', GetEnv('PATH'));
 {$ELSE}
 FullPath := FSearch(Name, GetEnv('PATH'));
 {$ENDIF}
 If FullPath <> '' Then Begin
  FindCompiler := FullPath;
  Exit;
 End;
 { Chercher dans le repertoire courant }
 {$IFDEF WINDOWS}
 FullPath := Name + '.exe';
 {$ELSE}
 FullPath := Name;
 {$ENDIF}
 { Verifier si le fichier existe }
 If FSearch(FullPath, '.') <> '' Then
  FindCompiler := FullPath;
End;

{ --- Detecter le compilateur C# disponible --- }

Procedure DetectCSCCompiler(Var Ctx: TCSCCompilerContext);
Var
 Path: String;
Begin
 { Essayer d abord CSCW32 (Win32 PE) }
 Path := FindCompiler(CSC_COMPILER_WIN32);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := CSC_COMPILER_WIN32;
  Ctx.CompilerFound := True;
  Exit;
 End;
 { Sinon essayer CSC86 (DOS 8086) }
 Path := FindCompiler(CSC_COMPILER_DOS);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := CSC_COMPILER_DOS;
  Ctx.CompilerFound := True;
  Exit;
 End;
 Ctx.CompilerFound := False;
End;

{ --- Construire le chemin de sortie du fichier compile --- }

Function BuildCSCOutputPath(Var Proj: TProject;
 Var Cfg: TBuildConfig): String;
Var
 OutPath, Ext: String;
Begin
 If Cfg.OutputPath <> '' Then
  OutPath := Cfg.OutputPath
 Else If Proj.Info.OutputPath <> '' Then
  OutPath := Proj.Info.OutputPath
 Else
  OutPath := '.';
 Case Proj.Info.OutputType Of
  OT_EXE, OT_WINEXE:
   Ext := CSC_EXT_EXE;
  OT_LIBRARY:
   Ext := CSC_EXT_DLL;
 End;
 If Proj.Info.AssemblyName <> '' Then
  BuildCSCOutputPath := OutPath + '/' + Proj.Info.AssemblyName + Ext
 Else If Proj.Info.ProjectName <> '' Then
  BuildCSCOutputPath := OutPath + '/' + Proj.Info.ProjectName + Ext
 Else
  BuildCSCOutputPath := OutPath + '/output' + Ext;
End;

{ --- Construire la ligne de commande pour un fichier source --- }

Function BuildCSCCommandLine(Var Ctx: TCSCCompilerContext;
 SourceFile, OutputFile: String): String;
Var
 Cmd: String;
Begin
 Cmd := Ctx.CompilerPath + ' ' + SourceFile;
 If OutputFile <> '' Then
  Cmd := Cmd + ' ' + CSC_FLAG_OUTPUT + ' ' + OutputFile;
 If Ctx.UseVerbose Then
  Cmd := Cmd + ' ' + CSC_FLAG_VERBOSE;
 If Ctx.UseDebugSymbols Then
  Cmd := Cmd + ' ' + CSC_FLAG_DEBUG;
 If Ctx.UseWarnings Then
  Cmd := Cmd + ' ' + CSC_FLAG_WARNINGS;
 BuildCSCCommandLine := Cmd;
End;

{ --- Compter les fichiers source C# dans le projet --- }

Function CountCSSourceFiles(Var Proj: TProject): Integer;
Var
 I, Count: Integer;
 Ext: String;
Begin
 Count := 0;
 For I := 0 To Proj.FileCount - 1 Do Begin
  Ext := '';
  If Length(Proj.Files[I].FileName) >= 3 Then
   Ext := Copy(Proj.Files[I].FileName,
    Length(Proj.Files[I].FileName) - 2, 3);
  If (Ext = CSC_EXT_SOURCE) And
     (Proj.Files[I].BuildAction = BA_COMPILE) Then
   Inc(Count);
 End;
 CountCSSourceFiles := Count;
End;

{ --- Collecter les fichiers source C# du projet --- }

Procedure CollectCSSourceFiles(Var Proj: TProject;
 Var FileList: Array Of String; Var Count: Integer);
Var
 I: Integer;
 Ext: String;
Begin
 Count := 0;
 For I := 0 To Proj.FileCount - 1 Do Begin
  If Count >= CSC_MAX_SOURCE_FILES Then Exit;
  Ext := '';
  If Length(Proj.Files[I].FileName) >= 3 Then
   Ext := Copy(Proj.Files[I].FileName,
    Length(Proj.Files[I].FileName) - 2, 3);
  If (Ext = CSC_EXT_SOURCE) And
     (Proj.Files[I].BuildAction = BA_COMPILE) Then Begin
   FileList[Count] := Proj.Files[I].FileName;
   Inc(Count);
  End;
 End;
End;

{ --- Executer le compilateur et rediriger la sortie --- }

Function ExecuteCompiler(CmdLine, TempOutputFile: String): Integer;
Var
 FullCmd: String;
Begin
 ExecuteCompiler := -1;
 {$IFDEF FPC}
 { Free Pascal : utiliser redirection shell }
 FullCmd := CmdLine + ' > ' + TempOutputFile + ' 2>&1';
  {$IFDEF WINDOWS}
  Exec(GetEnv('COMSPEC'), '/C ' + FullCmd);
  {$ELSE}
  Exec('/bin/sh', '-c ' + FullCmd);
  {$ENDIF}
 ExecuteCompiler := DosExitCode;
 {$ELSE}
 { Turbo Pascal : utiliser COMSPEC }
 FullCmd := CmdLine + ' > ' + TempOutputFile;
 Exec(GetEnv('COMSPEC'), '/C ' + FullCmd);
 ExecuteCompiler := DosExitCode;
 {$ENDIF}
End;

{ --- Lire le fichier de sortie du compilateur --- }

Procedure ReadOutputFile(TempFile: String;
 Var OP: TOutputPanel; Tab: Integer);
Var
 F: Text;
 Line: String;
Begin
 {$I-}
 Assign(F, TempFile);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  AppendOutput(OP, Line, Tab);
 End;
 Close(F);
End;

{ --- Parser le fichier de sortie du compilateur C# --- }

Procedure ParseCSCOutput(TempFile, ProjName: String;
 Var EL: TErrorListPanel; Var ErrCount, WarnCount: Integer);
Var
 F: Text;
 Line: String;
 E: TErrorEntry;
Begin
 ErrCount := 0;
 WarnCount := 0;
 {$I-}
 Assign(F, TempFile);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  If ParseCSCError(Line, E) Then Begin
   E.Project := ProjName;
   AddError(EL, E);
   If E.Severity = ES_ERROR Then
    Inc(ErrCount)
   Else If E.Severity = ES_WARNING Then
    Inc(WarnCount);
  End;
 End;
 Close(F);
End;

{ --- Supprimer le fichier temporaire --- }

Procedure CleanupTempFile(TempFile: String);
Var
 F: File;
Begin
 {$I-}
 Assign(F, TempFile);
 Erase(F);
 {$I+}
 If IOResult <> 0 Then ; { ignorer l erreur }
End;

{ --- Compiler un seul fichier C# --- }

Function CompileSingleCSFile(Var Ctx: TCSCCompilerContext;
 SourceFile, OutputFile: String;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 ProjName: String): TCompilerResult;
Var
 CmdLine: String;
 ExitCode: Integer;
 EC, WC: Integer;
Begin
 CompileSingleCSFile := CR_EXEC_FAILED;
 CmdLine := BuildCSCCommandLine(Ctx, SourceFile, OutputFile);
 AppendOutput(OP, '> ' + CmdLine, Ord(OTK_BUILD));
 ExitCode := ExecuteCompiler(CmdLine, Ctx.TempFile);
 ReadOutputFile(Ctx.TempFile, OP, Ord(OTK_BUILD));
 ParseCSCOutput(Ctx.TempFile, ProjName, EL, EC, WC);
 CleanupTempFile(Ctx.TempFile);
 Ctx.ErrorCount := Ctx.ErrorCount + EC;
 Ctx.WarningCount := Ctx.WarningCount + WC;
 If EC > 0 Then
  CompileSingleCSFile := CR_ERRORS
 Else If WC > 0 Then
  CompileSingleCSFile := CR_WARNINGS
 Else If ExitCode = 0 Then
  CompileSingleCSFile := CR_SUCCESS
 Else
  CompileSingleCSFile := CR_EXEC_FAILED;
End;

{ --- Appliquer la configuration de build au contexte --- }

Procedure ApplyBuildConfig(Var Ctx: TCSCCompilerContext;
 Var Cfg: TBuildConfig);
Begin
 Ctx.UseDebugSymbols := Cfg.DebugSymbols;
 If Cfg.Optimize Then
  Ctx.UseVerbose := False
 Else
  Ctx.UseVerbose := Ctx.UseVerbose;
 Ctx.UseWarnings := True;
End;

{ --- Compiler un projet C# complet --- }

Procedure CompileCSharp(Var Proj: TProject;
 Var Cfg: TBuildConfig;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var Ctx: TCSCCompilerContext);
Var
 SourceFiles: Array[0..CSC_MAX_SOURCE_FILES - 1] Of String;
 FileCount: Integer;
 I: Integer;
 OutputPath: String;
 ProjName: String;
 Res: TCompilerResult;
Begin
 Ctx.IsCompiling := True;
 Ctx.ErrorCount := 0;
 Ctx.WarningCount := 0;
 Ctx.FilesCompiled := 0;
 ProjName := Proj.Info.ProjectName;
 { Effacer les sorties precedentes }
 ClearOutput(OP, Ord(OTK_BUILD));
 ClearErrors(EL);
 AppendOutput(OP, '------ Build started: Project: ' +
  ProjName + ', Configuration: ' +
  Cfg.ConfigName + ' ------', Ord(OTK_BUILD));
 { Detecter le compilateur }
 DetectCSCCompiler(Ctx);
 If Not Ctx.CompilerFound Then Begin
  AppendOutputEx(OP,
   'Error: C# compiler not found (CSCW32 or CSC86)',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
  Ctx.LastResult := CR_NOT_FOUND;
  Ctx.IsCompiling := False;
  Exit;
 End;
 AppendOutput(OP, 'Using compiler: ' + Ctx.CompilerName +
  ' (' + Ctx.CompilerPath + ')', Ord(OTK_BUILD));
 { Appliquer la configuration }
 ApplyBuildConfig(Ctx, Cfg);
 { Collecter les fichiers source }
 CollectCSSourceFiles(Proj, SourceFiles, FileCount);
 Ctx.TotalFiles := FileCount;
 If FileCount = 0 Then Begin
  AppendOutputEx(OP,
   'Error: No C# source files found in project',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
  Ctx.LastResult := CR_NO_SOURCE;
  Ctx.IsCompiling := False;
  Exit;
 End;
 AppendOutput(OP, 'Compiling ' + IntToStr(FileCount) +
  ' file(s)...', Ord(OTK_BUILD));
 { Determiner le fichier de sortie }
 OutputPath := BuildCSCOutputPath(Proj, Cfg);
 Ctx.OutputFile := OutputPath;
 { Compiler chaque fichier source }
 For I := 0 To FileCount - 1 Do Begin
  AppendOutput(OP, '  ' + SourceFiles[I],
   Ord(OTK_BUILD));
  Res := CompileSingleCSFile(Ctx,
   SourceFiles[I], OutputPath,
   OP, EL, ProjName);
  Inc(Ctx.FilesCompiled);
  If Res = CR_ERRORS Then Begin
   Ctx.LastResult := CR_ERRORS;
   AppendOutputEx(OP,
    'Build FAILED for ' + SourceFiles[I],
    Ord(OTK_BUILD), OLK_ERROR, SourceFiles[I], 0, 0);
  End;
 End;
 { Resume de la compilation }
 If Ctx.ErrorCount > 0 Then Begin
  Ctx.LastResult := CR_ERRORS;
  AppendOutputEx(OP,
   '========== Build: 0 succeeded, 1 failed, ' +
   IntToStr(Ctx.ErrorCount) + ' error(s), ' +
   IntToStr(Ctx.WarningCount) + ' warning(s) ==========',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
 End Else If Ctx.WarningCount > 0 Then Begin
  Ctx.LastResult := CR_WARNINGS;
  AppendOutputEx(OP,
   '========== Build: 1 succeeded, 0 failed, ' +
   IntToStr(Ctx.WarningCount) + ' warning(s) ==========',
   Ord(OTK_BUILD), OLK_WARNING, '', 0, 0);
 End Else Begin
  Ctx.LastResult := CR_SUCCESS;
  AppendOutputEx(OP,
   '========== Build: 1 succeeded, 0 failed ==========',
   Ord(OTK_BUILD), OLK_SUCCESS, '', 0, 0);
 End;
 Ctx.IsCompiling := False;
End;

{ --- Nom du resultat de compilation --- }

Function CompilerResultName(R: TCompilerResult): String;
Begin
 Case R Of
  CR_SUCCESS:    CompilerResultName := 'Success';
  CR_ERRORS:     CompilerResultName := 'Errors';
  CR_WARNINGS:   CompilerResultName := 'Warnings';
  CR_NOT_FOUND:  CompilerResultName := 'Compiler not found';
  CR_NO_SOURCE:  CompilerResultName := 'No source files';
  CR_EXEC_FAILED:CompilerResultName := 'Execution failed';
 End;
End;

{ --- Obtenir le chemin du compilateur C# --- }

Function GetCSCCompilerPath(
 Var Ctx: TCSCCompilerContext): String;
Begin
 GetCSCCompilerPath := Ctx.CompilerPath;
End;

{ --- Obtenir le nom du compilateur C# --- }

Function GetCSCCompilerName(
 Var Ctx: TCSCCompilerContext): String;
Begin
 GetCSCCompilerName := Ctx.CompilerName;
End;

{ --- Le compilateur C# est-il disponible --- }

Function IsCSCCompilerFound(
 Var Ctx: TCSCCompilerContext): Boolean;
Begin
 IsCSCCompilerFound := Ctx.CompilerFound;
End;

{ --- Obtenir le dernier resultat de compilation --- }

Function GetCSCLastResult(
 Var Ctx: TCSCCompilerContext): TCompilerResult;
Begin
 GetCSCLastResult := Ctx.LastResult;
End;

{ --- Obtenir le nombre d erreurs de la derniere compilation --- }

Function GetCSCErrorCount(
 Var Ctx: TCSCCompilerContext): Integer;
Begin
 GetCSCErrorCount := Ctx.ErrorCount;
End;

{ --- Obtenir le nombre d avertissements --- }

Function GetCSCWarningCount(
 Var Ctx: TCSCCompilerContext): Integer;
Begin
 GetCSCWarningCount := Ctx.WarningCount;
End;

{ --- Obtenir le nombre de fichiers compiles --- }

Function GetCSCFilesCompiled(
 Var Ctx: TCSCCompilerContext): Integer;
Begin
 GetCSCFilesCompiled := Ctx.FilesCompiled;
End;

{ --- Obtenir le nombre total de fichiers source --- }

Function GetCSCTotalFiles(
 Var Ctx: TCSCCompilerContext): Integer;
Begin
 GetCSCTotalFiles := Ctx.TotalFiles;
End;

{ --- Obtenir le fichier de sortie genere --- }

Function GetCSCOutputFile(
 Var Ctx: TCSCCompilerContext): String;
Begin
 GetCSCOutputFile := Ctx.OutputFile;
End;

{ --- La compilation est-elle en cours --- }

Function IsCSCCompiling(
 Var Ctx: TCSCCompilerContext): Boolean;
Begin
 IsCSCCompiling := Ctx.IsCompiling;
End;

{ --- Activer/desactiver les symboles de debogage --- }

Procedure SetCSCDebugSymbols(
 Var Ctx: TCSCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseDebugSymbols := Enable;
End;

{ --- Activer/desactiver le mode verbeux --- }

Procedure SetCSCVerbose(
 Var Ctx: TCSCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseVerbose := Enable;
End;

{ --- Activer/desactiver les avertissements --- }

Procedure SetCSCWarnings(
 Var Ctx: TCSCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseWarnings := Enable;
End;

{ --- Les symboles de debogage sont-ils actives --- }

Function AreCSCDebugSymbolsEnabled(
 Var Ctx: TCSCCompilerContext): Boolean;
Begin
 AreCSCDebugSymbolsEnabled := Ctx.UseDebugSymbols;
End;

{ --- Le mode verbeux est-il active --- }

Function IsCSCVerboseEnabled(
 Var Ctx: TCSCCompilerContext): Boolean;
Begin
 IsCSCVerboseEnabled := Ctx.UseVerbose;
End;

{ --- Les avertissements sont-ils actives --- }

Function AreCSCWarningsEnabled(
 Var Ctx: TCSCCompilerContext): Boolean;
Begin
 AreCSCWarningsEnabled := Ctx.UseWarnings;
End;

{ --- Obtenir le fichier temporaire de sortie --- }

Function GetCSCTempFile(
 Var Ctx: TCSCCompilerContext): String;
Begin
 GetCSCTempFile := Ctx.TempFile;
End;

{ --- Definir le fichier temporaire de sortie --- }

Procedure SetCSCTempFile(
 Var Ctx: TCSCCompilerContext; AFile: String);
Begin
 Ctx.TempFile := AFile;
End;

{ --- Le contexte est-il vide (pas de compilation effectuee) --- }

Function IsCSCContextEmpty(
 Var Ctx: TCSCCompilerContext): Boolean;
Begin
 IsCSCContextEmpty := (Ctx.FilesCompiled = 0) And
  (Ctx.ErrorCount = 0) And
  (Ctx.WarningCount = 0) And
  (Not Ctx.IsCompiling);
End;

{ ============================================================
  TODO 26 - INTEGRATION COMPILATEUR VB.NET (VBCW32/VBC86) [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser le contexte du compilateur VB.NET --- }

Procedure InitVBCContext(Var Ctx: TVBCCompilerContext);
Begin
 Ctx.CompilerPath := '';
 Ctx.CompilerName := '';
 Ctx.CompilerFound := False;
 Ctx.LastResult := CR_NOT_FOUND;
 Ctx.ErrorCount := 0;
 Ctx.WarningCount := 0;
 Ctx.FilesCompiled := 0;
 Ctx.TotalFiles := 0;
 Ctx.OutputFile := '';
 Ctx.TempFile := VBC_TEMP_OUTPUT;
 Ctx.IsCompiling := False;
 Ctx.UseDebugSymbols := False;
 Ctx.UseVerbose := False;
 Ctx.UseWarnings := True;
End;

{ --- Detecter le compilateur VB.NET disponible --- }

Procedure DetectVBCCompiler(Var Ctx: TVBCCompilerContext);
Var
 Path: String;
Begin
 { Essayer d abord VBCW32 (Win32 PE) }
 Path := FindCompiler(VBC_COMPILER_WIN32);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := VBC_COMPILER_WIN32;
  Ctx.CompilerFound := True;
  Exit;
 End;
 { Sinon essayer VBC86 (DOS 8086) }
 Path := FindCompiler(VBC_COMPILER_DOS);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := VBC_COMPILER_DOS;
  Ctx.CompilerFound := True;
  Exit;
 End;
 Ctx.CompilerFound := False;
End;

{ --- Construire le chemin de sortie du fichier compile --- }

Function BuildVBCOutputPath(Var Proj: TProject;
 Var Cfg: TBuildConfig): String;
Var
 OutPath, Ext: String;
Begin
 If Cfg.OutputPath <> '' Then
  OutPath := Cfg.OutputPath
 Else If Proj.Info.OutputPath <> '' Then
  OutPath := Proj.Info.OutputPath
 Else
  OutPath := '.';
 Case Proj.Info.OutputType Of
  OT_EXE, OT_WINEXE:
   Ext := VBC_EXT_EXE;
  OT_LIBRARY:
   Ext := VBC_EXT_DLL;
 End;
 If Proj.Info.AssemblyName <> '' Then
  BuildVBCOutputPath := OutPath + '/' + Proj.Info.AssemblyName + Ext
 Else If Proj.Info.ProjectName <> '' Then
  BuildVBCOutputPath := OutPath + '/' + Proj.Info.ProjectName + Ext
 Else
  BuildVBCOutputPath := OutPath + '/output' + Ext;
End;

{ --- Construire la ligne de commande pour un fichier source --- }

Function BuildVBCCommandLine(Var Ctx: TVBCCompilerContext;
 SourceFile, OutputFile: String): String;
Var
 Cmd: String;
Begin
 Cmd := Ctx.CompilerPath + ' ' + SourceFile;
 If OutputFile <> '' Then
  Cmd := Cmd + ' ' + VBC_FLAG_OUTPUT + ' ' + OutputFile;
 If Ctx.UseVerbose Then
  Cmd := Cmd + ' ' + VBC_FLAG_VERBOSE;
 If Ctx.UseDebugSymbols Then
  Cmd := Cmd + ' ' + VBC_FLAG_DEBUG;
 If Ctx.UseWarnings Then
  Cmd := Cmd + ' ' + VBC_FLAG_WARNINGS;
 BuildVBCCommandLine := Cmd;
End;

{ --- Compter les fichiers source VB.NET dans le projet --- }

Function CountVBSourceFiles(Var Proj: TProject): Integer;
Var
 I, Count: Integer;
 Ext: String;
Begin
 Count := 0;
 For I := 0 To Proj.FileCount - 1 Do Begin
  Ext := '';
  If Length(Proj.Files[I].FileName) >= 3 Then
   Ext := Copy(Proj.Files[I].FileName,
    Length(Proj.Files[I].FileName) - 2, 3);
  If (Ext = VBC_EXT_SOURCE) And
     (Proj.Files[I].BuildAction = BA_COMPILE) Then
   Inc(Count);
 End;
 CountVBSourceFiles := Count;
End;

{ --- Collecter les fichiers source VB.NET du projet --- }

Procedure CollectVBSourceFiles(Var Proj: TProject;
 Var FileList: Array Of String; Var Count: Integer);
Var
 I: Integer;
 Ext: String;
Begin
 Count := 0;
 For I := 0 To Proj.FileCount - 1 Do Begin
  If Count >= VBC_MAX_SOURCE_FILES Then Exit;
  Ext := '';
  If Length(Proj.Files[I].FileName) >= 3 Then
   Ext := Copy(Proj.Files[I].FileName,
    Length(Proj.Files[I].FileName) - 2, 3);
  If (Ext = VBC_EXT_SOURCE) And
     (Proj.Files[I].BuildAction = BA_COMPILE) Then Begin
   FileList[Count] := Proj.Files[I].FileName;
   Inc(Count);
  End;
 End;
End;

{ --- Parser le fichier de sortie du compilateur VB.NET --- }

Procedure ParseVBCOutput(TempFile, ProjName: String;
 Var EL: TErrorListPanel; Var ErrCount, WarnCount: Integer);
Var
 F: Text;
 Line: String;
 E: TErrorEntry;
Begin
 ErrCount := 0;
 WarnCount := 0;
 {$I-}
 Assign(F, TempFile);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  If ParseVBCError(Line, E) Then Begin
   E.Project := ProjName;
   AddError(EL, E);
   If E.Severity = ES_ERROR Then
    Inc(ErrCount)
   Else If E.Severity = ES_WARNING Then
    Inc(WarnCount);
  End;
 End;
 Close(F);
End;

{ --- Compiler un seul fichier VB.NET --- }

Function CompileSingleVBFile(Var Ctx: TVBCCompilerContext;
 SourceFile, OutputFile: String;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 ProjName: String): TCompilerResult;
Var
 CmdLine: String;
 ExitCode: Integer;
 EC, WC: Integer;
Begin
 CompileSingleVBFile := CR_EXEC_FAILED;
 CmdLine := BuildVBCCommandLine(Ctx, SourceFile, OutputFile);
 AppendOutput(OP, '> ' + CmdLine, Ord(OTK_BUILD));
 ExitCode := ExecuteCompiler(CmdLine, Ctx.TempFile);
 ReadOutputFile(Ctx.TempFile, OP, Ord(OTK_BUILD));
 ParseVBCOutput(Ctx.TempFile, ProjName, EL, EC, WC);
 CleanupTempFile(Ctx.TempFile);
 Ctx.ErrorCount := Ctx.ErrorCount + EC;
 Ctx.WarningCount := Ctx.WarningCount + WC;
 If EC > 0 Then
  CompileSingleVBFile := CR_ERRORS
 Else If WC > 0 Then
  CompileSingleVBFile := CR_WARNINGS
 Else If ExitCode = 0 Then
  CompileSingleVBFile := CR_SUCCESS
 Else
  CompileSingleVBFile := CR_EXEC_FAILED;
End;

{ --- Appliquer la configuration de build au contexte VB.NET --- }

Procedure ApplyVBCBuildConfig(Var Ctx: TVBCCompilerContext;
 Var Cfg: TBuildConfig);
Begin
 Ctx.UseDebugSymbols := Cfg.DebugSymbols;
 If Cfg.Optimize Then
  Ctx.UseVerbose := False
 Else
  Ctx.UseVerbose := Ctx.UseVerbose;
 Ctx.UseWarnings := True;
End;

{ --- Compiler un projet VB.NET complet --- }

Procedure CompileVBNet(Var Proj: TProject;
 Var Cfg: TBuildConfig;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var Ctx: TVBCCompilerContext);
Var
 SourceFiles: Array[0..VBC_MAX_SOURCE_FILES - 1] Of String;
 FileCount: Integer;
 I: Integer;
 OutputPath: String;
 ProjName: String;
 Res: TCompilerResult;
Begin
 Ctx.IsCompiling := True;
 Ctx.ErrorCount := 0;
 Ctx.WarningCount := 0;
 Ctx.FilesCompiled := 0;
 ProjName := Proj.Info.ProjectName;
 { Effacer les sorties precedentes }
 ClearOutput(OP, Ord(OTK_BUILD));
 ClearErrors(EL);
 AppendOutput(OP, '------ Build started: Project: ' +
  ProjName + ', Configuration: ' +
  Cfg.ConfigName + ' ------', Ord(OTK_BUILD));
 { Detecter le compilateur }
 DetectVBCCompiler(Ctx);
 If Not Ctx.CompilerFound Then Begin
  AppendOutputEx(OP,
   'Error: VB.NET compiler not found (VBCW32 or VBC86). ' +
   'Please ensure the compiler is installed and available in PATH.',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
  Ctx.LastResult := CR_NOT_FOUND;
  Ctx.IsCompiling := False;
  Exit;
 End;
 AppendOutput(OP, 'Using compiler: ' + Ctx.CompilerName +
  ' (' + Ctx.CompilerPath + ')', Ord(OTK_BUILD));
 { Appliquer la configuration }
 ApplyVBCBuildConfig(Ctx, Cfg);
 { Collecter les fichiers source }
 CollectVBSourceFiles(Proj, SourceFiles, FileCount);
 Ctx.TotalFiles := FileCount;
 If FileCount = 0 Then Begin
  AppendOutputEx(OP,
   'Error: No VB.NET source files found in project',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
  Ctx.LastResult := CR_NO_SOURCE;
  Ctx.IsCompiling := False;
  Exit;
 End;
 AppendOutput(OP, 'Compiling ' + IntToStr(FileCount) +
  ' file(s)...', Ord(OTK_BUILD));
 { Determiner le fichier de sortie }
 OutputPath := BuildVBCOutputPath(Proj, Cfg);
 Ctx.OutputFile := OutputPath;
 { Compiler chaque fichier source }
 For I := 0 To FileCount - 1 Do Begin
  AppendOutput(OP, '  ' + SourceFiles[I],
   Ord(OTK_BUILD));
  Res := CompileSingleVBFile(Ctx,
   SourceFiles[I], OutputPath,
   OP, EL, ProjName);
  Inc(Ctx.FilesCompiled);
  If Res = CR_ERRORS Then Begin
   Ctx.LastResult := CR_ERRORS;
   AppendOutputEx(OP,
    'Build FAILED for ' + SourceFiles[I],
    Ord(OTK_BUILD), OLK_ERROR, SourceFiles[I], 0, 0);
  End;
 End;
 { Resume de la compilation }
 If Ctx.ErrorCount > 0 Then Begin
  Ctx.LastResult := CR_ERRORS;
  AppendOutputEx(OP,
   '========== Build: 0 succeeded, 1 failed, ' +
   IntToStr(Ctx.ErrorCount) + ' error(s), ' +
   IntToStr(Ctx.WarningCount) + ' warning(s) ==========',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
 End Else If Ctx.WarningCount > 0 Then Begin
  Ctx.LastResult := CR_WARNINGS;
  AppendOutputEx(OP,
   '========== Build: 1 succeeded, 0 failed, ' +
   IntToStr(Ctx.WarningCount) + ' warning(s) ==========',
   Ord(OTK_BUILD), OLK_WARNING, '', 0, 0);
 End Else Begin
  Ctx.LastResult := CR_SUCCESS;
  AppendOutputEx(OP,
   '========== Build: 1 succeeded, 0 failed ==========',
   Ord(OTK_BUILD), OLK_SUCCESS, '', 0, 0);
 End;
 Ctx.IsCompiling := False;
End;

{ --- Obtenir le chemin du compilateur VB.NET --- }

Function GetVBCCompilerPath(
 Var Ctx: TVBCCompilerContext): String;
Begin
 GetVBCCompilerPath := Ctx.CompilerPath;
End;

{ --- Obtenir le nom du compilateur VB.NET --- }

Function GetVBCCompilerName(
 Var Ctx: TVBCCompilerContext): String;
Begin
 GetVBCCompilerName := Ctx.CompilerName;
End;

{ --- Le compilateur VB.NET est-il disponible --- }

Function IsVBCCompilerFound(
 Var Ctx: TVBCCompilerContext): Boolean;
Begin
 IsVBCCompilerFound := Ctx.CompilerFound;
End;

{ --- Obtenir le dernier resultat de compilation VB.NET --- }

Function GetVBCLastResult(
 Var Ctx: TVBCCompilerContext): TCompilerResult;
Begin
 GetVBCLastResult := Ctx.LastResult;
End;

{ --- Obtenir le nombre d erreurs de la derniere compilation VB.NET --- }

Function GetVBCErrorCount(
 Var Ctx: TVBCCompilerContext): Integer;
Begin
 GetVBCErrorCount := Ctx.ErrorCount;
End;

{ --- Obtenir le nombre d avertissements VB.NET --- }

Function GetVBCWarningCount(
 Var Ctx: TVBCCompilerContext): Integer;
Begin
 GetVBCWarningCount := Ctx.WarningCount;
End;

{ --- Obtenir le nombre de fichiers VB.NET compiles --- }

Function GetVBCFilesCompiled(
 Var Ctx: TVBCCompilerContext): Integer;
Begin
 GetVBCFilesCompiled := Ctx.FilesCompiled;
End;

{ --- Obtenir le nombre total de fichiers source VB.NET --- }

Function GetVBCTotalFiles(
 Var Ctx: TVBCCompilerContext): Integer;
Begin
 GetVBCTotalFiles := Ctx.TotalFiles;
End;

{ --- Obtenir le fichier de sortie genere VB.NET --- }

Function GetVBCOutputFile(
 Var Ctx: TVBCCompilerContext): String;
Begin
 GetVBCOutputFile := Ctx.OutputFile;
End;

{ --- La compilation VB.NET est-elle en cours --- }

Function IsVBCCompiling(
 Var Ctx: TVBCCompilerContext): Boolean;
Begin
 IsVBCCompiling := Ctx.IsCompiling;
End;

{ --- Activer/desactiver les symboles de debogage VB.NET --- }

Procedure SetVBCDebugSymbols(
 Var Ctx: TVBCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseDebugSymbols := Enable;
End;

{ --- Activer/desactiver le mode verbeux VB.NET --- }

Procedure SetVBCVerbose(
 Var Ctx: TVBCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseVerbose := Enable;
End;

{ --- Activer/desactiver les avertissements VB.NET --- }

Procedure SetVBCWarnings(
 Var Ctx: TVBCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseWarnings := Enable;
End;

{ --- Les symboles de debogage VB.NET sont-ils actives --- }

Function AreVBCDebugSymbolsEnabled(
 Var Ctx: TVBCCompilerContext): Boolean;
Begin
 AreVBCDebugSymbolsEnabled := Ctx.UseDebugSymbols;
End;

{ --- Le mode verbeux VB.NET est-il active --- }

Function IsVBCVerboseEnabled(
 Var Ctx: TVBCCompilerContext): Boolean;
Begin
 IsVBCVerboseEnabled := Ctx.UseVerbose;
End;

{ --- Les avertissements VB.NET sont-ils actives --- }

Function AreVBCWarningsEnabled(
 Var Ctx: TVBCCompilerContext): Boolean;
Begin
 AreVBCWarningsEnabled := Ctx.UseWarnings;
End;

{ --- Obtenir le fichier temporaire de sortie VB.NET --- }

Function GetVBCTempFile(
 Var Ctx: TVBCCompilerContext): String;
Begin
 GetVBCTempFile := Ctx.TempFile;
End;

{ --- Definir le fichier temporaire de sortie VB.NET --- }

Procedure SetVBCTempFile(
 Var Ctx: TVBCCompilerContext; AFile: String);
Begin
 Ctx.TempFile := AFile;
End;

{ --- Le contexte VB.NET est-il vide (pas de compilation effectuee) --- }

Function IsVBCContextEmpty(
 Var Ctx: TVBCCompilerContext): Boolean;
Begin
 IsVBCContextEmpty := (Ctx.FilesCompiled = 0) And
  (Ctx.ErrorCount = 0) And
  (Ctx.WarningCount = 0) And
  (Not Ctx.IsCompiling);
End;

{  TODO 27 - INTEGRATION COMPILATEUR PASCAL (TPCW32/VAXPAS86) [IMPLEMENTE]
   ============================================================ }

{ --- Initialiser le contexte du compilateur Pascal --- }

Procedure InitTPCContext(Var Ctx: TTPCCompilerContext);
Begin
 Ctx.CompilerPath := '';
 Ctx.CompilerName := '';
 Ctx.CompilerFound := False;
 Ctx.LastResult := CR_NOT_FOUND;
 Ctx.ErrorCount := 0;
 Ctx.WarningCount := 0;
 Ctx.FilesCompiled := 0;
 Ctx.TotalFiles := 0;
 Ctx.OutputFile := '';
 Ctx.TempFile := TPC_TEMP_OUTPUT;
 Ctx.IsCompiling := False;
 Ctx.UseDebugSymbols := False;
 Ctx.UseVerbose := False;
 Ctx.UseWarnings := True;
End;

{ --- Detecter le compilateur Pascal disponible --- }

Procedure DetectTPCCompiler(Var Ctx: TTPCCompilerContext);
Var
 Path: String;
Begin
 { Essayer d abord TPCW32 (Win32 PE) }
 Path := FindCompiler(TPC_COMPILER_WIN32);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := TPC_COMPILER_WIN32;
  Ctx.CompilerFound := True;
  Exit;
 End;
 { Sinon essayer VAXPCW32 (Win32 alternatif) }
 Path := FindCompiler(TPC_COMPILER_WIN32B);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := TPC_COMPILER_WIN32B;
  Ctx.CompilerFound := True;
  Exit;
 End;
 { Sinon essayer VAXPAS86 (DOS 8086) }
 Path := FindCompiler(TPC_COMPILER_DOS);
 If Path <> '' Then Begin
  Ctx.CompilerPath := Path;
  Ctx.CompilerName := TPC_COMPILER_DOS;
  Ctx.CompilerFound := True;
  Exit;
 End;
 Ctx.CompilerFound := False;
End;

{ --- Construire le chemin de sortie du fichier compile --- }

Function BuildTPCOutputPath(Var Proj: TProject;
 Var Cfg: TBuildConfig): String;
Var
 OutPath, Ext: String;
Begin
 If Cfg.OutputPath <> '' Then
  OutPath := Cfg.OutputPath
 Else If Proj.Info.OutputPath <> '' Then
  OutPath := Proj.Info.OutputPath
 Else
  OutPath := '.';
 Case Proj.Info.OutputType Of
  OT_EXE, OT_WINEXE:
   Ext := TPC_EXT_EXE;
  OT_LIBRARY:
   Ext := TPC_EXT_DLL;
 End;
 If Proj.Info.AssemblyName <> '' Then
  BuildTPCOutputPath := OutPath + '/' + Proj.Info.AssemblyName + Ext
 Else If Proj.Info.ProjectName <> '' Then
  BuildTPCOutputPath := OutPath + '/' + Proj.Info.ProjectName + Ext
 Else
  BuildTPCOutputPath := OutPath + '/output' + Ext;
End;

{ --- Construire la ligne de commande pour un fichier source --- }

Function BuildTPCCommandLine(Var Ctx: TTPCCompilerContext;
 SourceFile, OutputFile: String): String;
Var
 Cmd: String;
Begin
 Cmd := Ctx.CompilerPath + ' ' + SourceFile;
 If OutputFile <> '' Then
  Cmd := Cmd + ' ' + TPC_FLAG_OUTPUT + ' ' + OutputFile;
 If Ctx.UseVerbose Then
  Cmd := Cmd + ' ' + TPC_FLAG_VERBOSE;
 If Ctx.UseDebugSymbols Then
  Cmd := Cmd + ' ' + TPC_FLAG_DEBUG;
 If Ctx.UseWarnings Then
  Cmd := Cmd + ' ' + TPC_FLAG_WARNINGS;
 BuildTPCCommandLine := Cmd;
End;

{ --- Compter les fichiers source Pascal dans le projet --- }

Function CountPascalSourceFiles(Var Proj: TProject): Integer;
Var
 I, Count: Integer;
 Ext: String;
Begin
 Count := 0;
 For I := 0 To Proj.FileCount - 1 Do Begin
  Ext := '';
  If Length(Proj.Files[I].FileName) >= 4 Then
   Ext := Copy(Proj.Files[I].FileName,
    Length(Proj.Files[I].FileName) - 3, 4);
  If (Ext = TPC_EXT_SOURCE) And
     (Proj.Files[I].BuildAction = BA_COMPILE) Then
   Inc(Count);
 End;
 CountPascalSourceFiles := Count;
End;

{ --- Collecter les fichiers source Pascal du projet --- }

Procedure CollectPascalSourceFiles(Var Proj: TProject;
 Var FileList: Array Of String; Var Count: Integer);
Var
 I: Integer;
 Ext: String;
Begin
 Count := 0;
 For I := 0 To Proj.FileCount - 1 Do Begin
  If Count >= TPC_MAX_SOURCE_FILES Then Exit;
  Ext := '';
  If Length(Proj.Files[I].FileName) >= 4 Then
   Ext := Copy(Proj.Files[I].FileName,
    Length(Proj.Files[I].FileName) - 3, 4);
  If (Ext = TPC_EXT_SOURCE) And
     (Proj.Files[I].BuildAction = BA_COMPILE) Then Begin
   FileList[Count] := Proj.Files[I].FileName;
   Inc(Count);
  End;
 End;
End;

{ --- Parser le fichier de sortie du compilateur Pascal --- }
{ Format : "filename(line,col) Error: message"              }

Procedure ParseTPCCompilerOutput(TempFile, ProjName: String;
 Var EL: TErrorListPanel; Var ErrCount, WarnCount: Integer);
Var
 F: Text;
 Line: String;
 E: TErrorEntry;
Begin
 ErrCount := 0;
 WarnCount := 0;
 {$I-}
 Assign(F, TempFile);
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While Not Eof(F) Do Begin
  ReadLn(F, Line);
  If ParseTPCError(Line, E) Then Begin
   E.Project := ProjName;
   AddError(EL, E);
   If E.Severity = ES_ERROR Then
    Inc(ErrCount)
   Else If E.Severity = ES_WARNING Then
    Inc(WarnCount);
  End;
 End;
 Close(F);
End;

{ --- Compiler un seul fichier Pascal --- }

Function CompileSinglePascalFile(Var Ctx: TTPCCompilerContext;
 SourceFile, OutputFile: String;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 ProjName: String): TCompilerResult;
Var
 CmdLine: String;
 ExitCode: Integer;
 EC, WC: Integer;
Begin
 CompileSinglePascalFile := CR_EXEC_FAILED;
 CmdLine := BuildTPCCommandLine(Ctx, SourceFile, OutputFile);
 AppendOutput(OP, '> ' + CmdLine, Ord(OTK_BUILD));
 ExitCode := ExecuteCompiler(CmdLine, Ctx.TempFile);
 ReadOutputFile(Ctx.TempFile, OP, Ord(OTK_BUILD));
 ParseTPCCompilerOutput(Ctx.TempFile, ProjName, EL, EC, WC);
 CleanupTempFile(Ctx.TempFile);
 Ctx.ErrorCount := Ctx.ErrorCount + EC;
 Ctx.WarningCount := Ctx.WarningCount + WC;
 If EC > 0 Then
  CompileSinglePascalFile := CR_ERRORS
 Else If WC > 0 Then
  CompileSinglePascalFile := CR_WARNINGS
 Else If ExitCode = 0 Then
  CompileSinglePascalFile := CR_SUCCESS
 Else
  CompileSinglePascalFile := CR_EXEC_FAILED;
End;

{ --- Appliquer la configuration de build au contexte Pascal --- }

Procedure ApplyTPCBuildConfig(Var Ctx: TTPCCompilerContext;
 Var Cfg: TBuildConfig);
Begin
 Ctx.UseDebugSymbols := Cfg.DebugSymbols;
 If Cfg.Optimize Then
  Ctx.UseVerbose := False
 Else
  Ctx.UseVerbose := Ctx.UseVerbose;
 Ctx.UseWarnings := True;
End;

{ --- Compiler un projet Pascal complet --- }

Procedure CompilePascal(Var Proj: TProject;
 Var Cfg: TBuildConfig;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var Ctx: TTPCCompilerContext);
Var
 SourceFiles: Array[0..TPC_MAX_SOURCE_FILES - 1] Of String;
 FileCount: Integer;
 I: Integer;
 OutputPath: String;
 ProjName: String;
 Res: TCompilerResult;
Begin
 Ctx.IsCompiling := True;
 Ctx.ErrorCount := 0;
 Ctx.WarningCount := 0;
 Ctx.FilesCompiled := 0;
 ProjName := Proj.Info.ProjectName;
 { Effacer les sorties precedentes }
 ClearOutput(OP, Ord(OTK_BUILD));
 ClearErrors(EL);
 AppendOutput(OP, '------ Build started: Project: ' +
  ProjName + ', Configuration: ' +
  Cfg.ConfigName + ' ------', Ord(OTK_BUILD));
 { Detecter le compilateur }
 DetectTPCCompiler(Ctx);
 If Not Ctx.CompilerFound Then Begin
  AppendOutputEx(OP,
   'Error: Pascal compiler not found (TPCW32, VAXPCW32 or VAXPAS86). ' +
   'Please ensure the compiler is installed and available in PATH.',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
  Ctx.LastResult := CR_NOT_FOUND;
  Ctx.IsCompiling := False;
  Exit;
 End;
 AppendOutput(OP, 'Using compiler: ' + Ctx.CompilerName +
  ' (' + Ctx.CompilerPath + ')', Ord(OTK_BUILD));
 { Appliquer la configuration }
 ApplyTPCBuildConfig(Ctx, Cfg);
 { Collecter les fichiers source }
 CollectPascalSourceFiles(Proj, SourceFiles, FileCount);
 Ctx.TotalFiles := FileCount;
 If FileCount = 0 Then Begin
  AppendOutputEx(OP,
   'Error: No Pascal source files found in project',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
  Ctx.LastResult := CR_NO_SOURCE;
  Ctx.IsCompiling := False;
  Exit;
 End;
 AppendOutput(OP, 'Compiling ' + IntToStr(FileCount) +
  ' file(s)...', Ord(OTK_BUILD));
 { Determiner le fichier de sortie }
 OutputPath := BuildTPCOutputPath(Proj, Cfg);
 Ctx.OutputFile := OutputPath;
 { Compiler chaque fichier source }
 For I := 0 To FileCount - 1 Do Begin
  AppendOutput(OP, '  ' + SourceFiles[I],
   Ord(OTK_BUILD));
  Res := CompileSinglePascalFile(Ctx,
   SourceFiles[I], OutputPath,
   OP, EL, ProjName);
  Inc(Ctx.FilesCompiled);
  If Res = CR_ERRORS Then Begin
   Ctx.LastResult := CR_ERRORS;
   AppendOutputEx(OP,
    'Build FAILED for ' + SourceFiles[I],
    Ord(OTK_BUILD), OLK_ERROR, SourceFiles[I], 0, 0);
  End;
 End;
 { Resume de la compilation }
 If Ctx.ErrorCount > 0 Then Begin
  Ctx.LastResult := CR_ERRORS;
  AppendOutputEx(OP,
   '========== Build: 0 succeeded, 1 failed, ' +
   IntToStr(Ctx.ErrorCount) + ' error(s), ' +
   IntToStr(Ctx.WarningCount) + ' warning(s) ==========',
   Ord(OTK_BUILD), OLK_ERROR, '', 0, 0);
 End Else If Ctx.WarningCount > 0 Then Begin
  Ctx.LastResult := CR_WARNINGS;
  AppendOutputEx(OP,
   '========== Build: 1 succeeded, 0 failed, ' +
   IntToStr(Ctx.WarningCount) + ' warning(s) ==========',
   Ord(OTK_BUILD), OLK_WARNING, '', 0, 0);
 End Else Begin
  Ctx.LastResult := CR_SUCCESS;
  AppendOutputEx(OP,
   '========== Build: 1 succeeded, 0 failed ==========',
   Ord(OTK_BUILD), OLK_SUCCESS, '', 0, 0);
 End;
 Ctx.IsCompiling := False;
End;

{ --- Obtenir le chemin du compilateur Pascal --- }

Function GetTPCCompilerPath(
 Var Ctx: TTPCCompilerContext): String;
Begin
 GetTPCCompilerPath := Ctx.CompilerPath;
End;

{ --- Obtenir le nom du compilateur Pascal --- }

Function GetTPCCompilerName(
 Var Ctx: TTPCCompilerContext): String;
Begin
 GetTPCCompilerName := Ctx.CompilerName;
End;

{ --- Le compilateur Pascal est-il disponible --- }

Function IsTPCCompilerFound(
 Var Ctx: TTPCCompilerContext): Boolean;
Begin
 IsTPCCompilerFound := Ctx.CompilerFound;
End;

{ --- Obtenir le dernier resultat de compilation Pascal --- }

Function GetTPCLastResult(
 Var Ctx: TTPCCompilerContext): TCompilerResult;
Begin
 GetTPCLastResult := Ctx.LastResult;
End;

{ --- Obtenir le nombre d erreurs de la derniere compilation Pascal --- }

Function GetTPCErrorCount(
 Var Ctx: TTPCCompilerContext): Integer;
Begin
 GetTPCErrorCount := Ctx.ErrorCount;
End;

{ --- Obtenir le nombre d avertissements Pascal --- }

Function GetTPCWarningCount(
 Var Ctx: TTPCCompilerContext): Integer;
Begin
 GetTPCWarningCount := Ctx.WarningCount;
End;

{ --- Obtenir le nombre de fichiers Pascal compiles --- }

Function GetTPCFilesCompiled(
 Var Ctx: TTPCCompilerContext): Integer;
Begin
 GetTPCFilesCompiled := Ctx.FilesCompiled;
End;

{ --- Obtenir le nombre total de fichiers source Pascal --- }

Function GetTPCTotalFiles(
 Var Ctx: TTPCCompilerContext): Integer;
Begin
 GetTPCTotalFiles := Ctx.TotalFiles;
End;

{ --- Obtenir le fichier de sortie genere Pascal --- }

Function GetTPCOutputFile(
 Var Ctx: TTPCCompilerContext): String;
Begin
 GetTPCOutputFile := Ctx.OutputFile;
End;

{ --- La compilation Pascal est-elle en cours --- }

Function IsTPCCompiling(
 Var Ctx: TTPCCompilerContext): Boolean;
Begin
 IsTPCCompiling := Ctx.IsCompiling;
End;

{ --- Activer/desactiver les symboles de debogage Pascal --- }

Procedure SetTPCDebugSymbols(
 Var Ctx: TTPCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseDebugSymbols := Enable;
End;

{ --- Activer/desactiver le mode verbeux Pascal --- }

Procedure SetTPCVerbose(
 Var Ctx: TTPCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseVerbose := Enable;
End;

{ --- Activer/desactiver les avertissements Pascal --- }

Procedure SetTPCWarnings(
 Var Ctx: TTPCCompilerContext; Enable: Boolean);
Begin
 Ctx.UseWarnings := Enable;
End;

{ --- Les symboles de debogage Pascal sont-ils actives --- }

Function AreTPCDebugSymbolsEnabled(
 Var Ctx: TTPCCompilerContext): Boolean;
Begin
 AreTPCDebugSymbolsEnabled := Ctx.UseDebugSymbols;
End;

{ --- Le mode verbeux Pascal est-il active --- }

Function IsTPCVerboseEnabled(
 Var Ctx: TTPCCompilerContext): Boolean;
Begin
 IsTPCVerboseEnabled := Ctx.UseVerbose;
End;

{ --- Les avertissements Pascal sont-ils actives --- }

Function AreTPCWarningsEnabled(
 Var Ctx: TTPCCompilerContext): Boolean;
Begin
 AreTPCWarningsEnabled := Ctx.UseWarnings;
End;

{ --- Obtenir le fichier temporaire de sortie Pascal --- }

Function GetTPCTempFile(
 Var Ctx: TTPCCompilerContext): String;
Begin
 GetTPCTempFile := Ctx.TempFile;
End;

{ --- Definir le fichier temporaire de sortie Pascal --- }

Procedure SetTPCTempFile(
 Var Ctx: TTPCCompilerContext; AFile: String);
Begin
 Ctx.TempFile := AFile;
End;

{ --- Le contexte Pascal est-il vide (pas de compilation effectuee) --- }

Function IsTPCContextEmpty(
 Var Ctx: TTPCCompilerContext): Boolean;
Begin
 IsTPCContextEmpty := (Ctx.FilesCompiled = 0) And
  (Ctx.ErrorCount = 0) And
  (Ctx.WarningCount = 0) And
  (Not Ctx.IsCompiling);
End;

{ ============================================================
  TODO 28 - SYSTEME DE BUILD ET CONFIGURATION [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser un resultat de build projet --- }

Procedure InitBuildProjectResult(Var R: TBuildProjectResult);
Begin
 R.ProjectName := '';
 R.ProjectGUID := '';
 R.Status := BS_PENDING;
 R.ErrorCount := 0;
 R.WarningCount := 0;
 R.OutputFile := '';
 R.ElapsedMs := 0;
End;

{ --- Initialiser le gestionnaire de build --- }

Procedure InitBuildManager(Var BM: TBuildManager);
Var
 I: Integer;
Begin
 For I := 0 To MAX_BUILD_RESULTS - 1 Do
  InitBuildProjectResult(BM.Results[I]);
 BM.ResultCount := 0;
 For I := 0 To BUILD_MAX_ORDER - 1 Do
  BM.BuildOrder[I] := -1;
 BM.OrderCount := 0;
 BM.ActiveConfig := 'Debug';
 BM.ActivePlatform := 'AnyCPU';
 BM.IsBuilding := False;
 BM.TotalSucceeded := 0;
 BM.TotalFailed := 0;
 BM.TotalSkipped := 0;
 BM.TotalUpToDate := 0;
End;

{ --- Initialiser le gestionnaire de configurations --- }

Procedure InitConfigurationManager(Var CM: TConfigurationManager);
Begin
 CM.Visible := False;
 CM.X := 100;
 CM.Y := 80;
 CM.Width := BUILD_CFG_DLG_WIDTH;
 CM.Height := BUILD_CFG_DLG_HEIGHT;
 CM.SelectedRow := 0;
 CM.ScrollTop := 0;
 CM.NeedRepaint := False;
End;

{ --- Nom textuel d un statut de build --- }

Function BuildStatusName(S: TBuildStatus): String;
Begin
 Case S Of
  BS_PENDING:   BuildStatusName := 'Pending';
  BS_BUILDING:  BuildStatusName := 'Building';
  BS_SUCCEEDED: BuildStatusName := 'Succeeded';
  BS_FAILED:    BuildStatusName := 'Failed';
  BS_SKIPPED:   BuildStatusName := 'Skipped';
  BS_CLEANED:   BuildStatusName := 'Cleaned';
 Else
  BuildStatusName := 'Unknown';
 End;
End;

{ --- Tri topologique des projets selon les dependances --- }

Procedure ResolveBuildOrder(Var Sol: TSolution;
 Var Order: Array Of Integer; Var OrderCount: Integer);
Var
 Placed: Array[0..MAX_SOLUTION_PROJECTS - 1] Of Boolean;
 I, J, K, Pass: Integer;
 AllPlaced, CanPlace: Boolean;
 DepGUID: String;
 DepFound: Boolean;
Begin
 OrderCount := 0;
 For I := 0 To Sol.ProjectCount - 1 Do
  Placed[I] := False;
 For Pass := 0 To Sol.ProjectCount - 1 Do Begin
  AllPlaced := True;
  For I := 0 To Sol.ProjectCount - 1 Do Begin
   If Not Placed[I] Then Begin
    CanPlace := True;
    For J := 0 To Sol.Projects[I].DepCount - 1 Do Begin
     DepGUID := Sol.Projects[I].Dependencies[J];
     DepFound := False;
     { Verifier si la dependance est deja placee }
     For K := 0 To OrderCount - 1 Do Begin
      If Sol.Projects[Order[K]].ProjectGUID = DepGUID Then Begin
       DepFound := True;
       Break;
      End;
     End;
     If Not DepFound Then Begin
      CanPlace := False;
      Break;
     End;
    End;
    If CanPlace Then Begin
     Order[OrderCount] := I;
     Inc(OrderCount);
     Placed[I] := True;
    End Else
     AllPlaced := False;
   End;
  End;
  If AllPlaced Then Break;
 End;
 { Ajouter les projets restants (dependances circulaires) }
 For I := 0 To Sol.ProjectCount - 1 Do Begin
  If Not Placed[I] Then Begin
   Order[OrderCount] := I;
   Inc(OrderCount);
  End;
 End;
End;

{ --- Trouver une configuration de build par nom --- }

Function FindBuildConfig(Var Proj: TProject;
 CfgName: String): Integer;
Var
 I: Integer;
Begin
 FindBuildConfig := -1;
 For I := 0 To Proj.CfgCount - 1 Do Begin
  If Proj.Configs[I].ConfigName = CfgName Then Begin
   FindBuildConfig := I;
   Exit;
  End;
 End;
End;

{ --- Compiler un projet selon son type --- }

Procedure CompileProjectByType(Var Proj: TProject;
 Var Cfg: TBuildConfig;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var CSC: TCSCCompilerContext;
 Var VBC: TVBCCompilerContext;
 Var TPC: TTPCCompilerContext);
Begin
 Case Proj.Info.ProjectType Of
  PT_CSHARP: CompileCSharp(Proj, Cfg, OP, EL, CSC);
  PT_VBNET:  CompileVBNet(Proj, Cfg, OP, EL, VBC);
  PT_PASCAL: CompilePascal(Proj, Cfg, OP, EL, TPC);
 Else
  AppendOutput(OP, 'Erreur: type de projet inconnu pour ' +
   Proj.Info.ProjectName, Ord(OTK_BUILD));
 End;
End;

{ --- Compiler un seul projet --- }

Procedure BuildProject(Var Proj: TProject;
 CfgName: String;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var BM: TBuildManager;
 Var CSC: TCSCCompilerContext;
 Var VBC: TVBCCompilerContext;
 Var TPC: TTPCCompilerContext);
Var
 CfgIdx: Integer;
 R: TBuildProjectResult;
Begin
 InitBuildProjectResult(R);
 R.ProjectName := Proj.Info.ProjectName;
 R.ProjectGUID := Proj.Info.ProjectGUID;
 CfgIdx := FindBuildConfig(Proj, CfgName);
 If CfgIdx < 0 Then Begin
  AppendOutput(OP, 'Configuration "' + CfgName +
   '" introuvable pour ' + Proj.Info.ProjectName,
   Ord(OTK_BUILD));
  R.Status := BS_SKIPPED;
  If BM.ResultCount < MAX_BUILD_RESULTS Then Begin
   BM.Results[BM.ResultCount] := R;
   Inc(BM.ResultCount);
  End;
  Inc(BM.TotalSkipped);
  Exit;
 End;
 AppendOutput(OP,
  '------ Build started: Project: ' + Proj.Info.ProjectName +
  ', Configuration: ' + CfgName + ' ------', Ord(OTK_BUILD));
 R.Status := BS_BUILDING;
 CompileProjectByType(Proj, Proj.Configs[CfgIdx], OP, EL,
  CSC, VBC, TPC);
 Case Proj.Info.ProjectType Of
  PT_CSHARP: Begin
   R.ErrorCount := CSC.ErrorCount;
   R.WarningCount := CSC.WarningCount;
   R.OutputFile := CSC.OutputFile;
  End;
  PT_VBNET: Begin
   R.ErrorCount := VBC.ErrorCount;
   R.WarningCount := VBC.WarningCount;
   R.OutputFile := VBC.OutputFile;
  End;
  PT_PASCAL: Begin
   R.ErrorCount := TPC.ErrorCount;
   R.WarningCount := TPC.WarningCount;
   R.OutputFile := TPC.OutputFile;
  End;
 End;
 If R.ErrorCount > 0 Then Begin
  R.Status := BS_FAILED;
  Inc(BM.TotalFailed);
 End Else Begin
  R.Status := BS_SUCCEEDED;
  Inc(BM.TotalSucceeded);
 End;
 If BM.ResultCount < MAX_BUILD_RESULTS Then Begin
  BM.Results[BM.ResultCount] := R;
  Inc(BM.ResultCount);
 End;
End;

{ --- Afficher le resume du build --- }

Procedure ShowBuildSummary(Var OP: TOutputPanel;
 Var BM: TBuildManager);
Begin
 AppendOutput(OP, '========== Build: ' +
  IntToStr(BM.TotalSucceeded) + ' succeeded, ' +
  IntToStr(BM.TotalFailed) + ' failed, ' +
  IntToStr(BM.TotalUpToDate) + ' up-to-date, ' +
  IntToStr(BM.TotalSkipped) + ' skipped ==========',
  Ord(OTK_BUILD));
End;

{ --- Compiler toute la solution --- }

Procedure BuildSolution(Var Sol: TSolution;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var BM: TBuildManager;
 Var CSC: TCSCCompilerContext;
 Var VBC: TVBCCompilerContext;
 Var TPC: TTPCCompilerContext);
Var
 I, ProjIdx: Integer;
Begin
 ClearOutput(OP, Ord(OTK_BUILD));
 ClearErrors(EL);
 BM.IsBuilding := True;
 BM.ResultCount := 0;
 BM.TotalSucceeded := 0;
 BM.TotalFailed := 0;
 BM.TotalSkipped := 0;
 BM.TotalUpToDate := 0;
 AppendOutput(OP, 'Build started...', Ord(OTK_BUILD));
 ResolveBuildOrder(Sol, BM.BuildOrder, BM.OrderCount);
 For I := 0 To BM.OrderCount - 1 Do Begin
  ProjIdx := BM.BuildOrder[I];
  If (ProjIdx >= 0) And (ProjIdx < Sol.ProjectCount) Then Begin
   { Stub : on aurait besoin de charger le TProject complet }
   AppendOutput(OP,
    '------ Build started: Project: ' +
    Sol.Projects[ProjIdx].ProjectName +
    ', Configuration: ' + BM.ActiveConfig + ' ------',
    Ord(OTK_BUILD));
  End;
 End;
 ShowBuildSummary(OP, BM);
 BM.IsBuilding := False;
End;

{ --- Nettoyer les fichiers de sortie d un projet --- }

Procedure CleanProjectOutputs(Var Proj: TProject;
 CfgName: String; Var OP: TOutputPanel);
Var
 CfgIdx: Integer;
Begin
 CfgIdx := FindBuildConfig(Proj, CfgName);
 If CfgIdx >= 0 Then
  AppendOutput(OP, 'Cleaning output: ' +
   Proj.Configs[CfgIdx].OutputPath, Ord(OTK_BUILD))
 Else
  AppendOutput(OP, 'Cleaning: ' + Proj.Info.ProjectName +
   ' (aucune configuration trouvee)', Ord(OTK_BUILD));
End;

{ --- Nettoyer un projet (wrapper) --- }

Procedure CleanProject(Var Proj: TProject;
 CfgName: String; Var OP: TOutputPanel);
Begin
 AppendOutput(OP, '------ Clean started: Project: ' +
  Proj.Info.ProjectName + ' ------', Ord(OTK_BUILD));
 CleanProjectOutputs(Proj, CfgName, OP);
 AppendOutput(OP, 'Clean complete: ' +
  Proj.Info.ProjectName, Ord(OTK_BUILD));
End;

{ --- Nettoyer toute la solution --- }

Procedure CleanSolution(Var Sol: TSolution;
 Var OP: TOutputPanel; Var BM: TBuildManager);
Var
 I: Integer;
Begin
 ClearOutput(OP, Ord(OTK_BUILD));
 AppendOutput(OP, 'Clean started...', Ord(OTK_BUILD));
 BM.ResultCount := 0;
 BM.TotalSucceeded := 0;
 BM.TotalFailed := 0;
 BM.TotalSkipped := 0;
 BM.TotalUpToDate := 0;
 For I := 0 To Sol.ProjectCount - 1 Do Begin
  AppendOutput(OP, '------ Clean: ' +
   Sol.Projects[I].ProjectName + ' ------', Ord(OTK_BUILD));
 End;
 AppendOutput(OP, '========== Clean: ' +
  IntToStr(Sol.ProjectCount) +
  ' project(s) cleaned ==========', Ord(OTK_BUILD));
End;

{ --- Regener la solution (clean + build) --- }

Procedure RebuildSolution(Var Sol: TSolution;
 Var OP: TOutputPanel;
 Var EL: TErrorListPanel;
 Var BM: TBuildManager;
 Var CSC: TCSCCompilerContext;
 Var VBC: TVBCCompilerContext;
 Var TPC: TTPCCompilerContext);
Begin
 CleanSolution(Sol, OP, BM);
 BuildSolution(Sol, OP, EL, BM, CSC, VBC, TPC);
End;

{ --- Dessiner le dialogue du gestionnaire de configurations --- }

Procedure DrawConfigurationManager(
 Var CM: TConfigurationManager; Var Sol: TSolution);
Begin
 If Not CM.Visible Then Exit;
 CM.NeedRepaint := False;
 { Stub : dessin du dialogue de configuration }
End;

{ --- Gerer une touche dans le gestionnaire de configurations --- }

Procedure HandleConfigManagerKey(
 Var CM: TConfigurationManager; Key: Word);
Begin
 If Not CM.Visible Then Exit;
 Case Key Of
  $4800: { Fleche haut }
   If CM.SelectedRow > 0 Then Begin
    Dec(CM.SelectedRow);
    CM.NeedRepaint := True;
   End;
  $5000: { Fleche bas }
   Begin
    Inc(CM.SelectedRow);
    CM.NeedRepaint := True;
   End;
  $001B: { Echap }
   CM.Visible := False;
 End;
End;

{ --- Gerer un evenement du gestionnaire de configurations --- }

Procedure HandleConfigManagerEvent(
 Var CM: TConfigurationManager);
Begin
 If Not CM.Visible Then Exit;
 { Stub : gestion des evenements souris/clavier }
End;

{ --- Afficher le gestionnaire de configurations --- }

Procedure ShowConfigurationManager(
 Var CM: TConfigurationManager);
Begin
 CM.Visible := True;
 CM.NeedRepaint := True;
End;

{ --- Masquer le gestionnaire de configurations --- }

Procedure HideConfigurationManager(
 Var CM: TConfigurationManager);
Begin
 CM.Visible := False;
 CM.NeedRepaint := False;
End;

{ --- Obtenir la configuration de build active --- }

Function GetActiveBuildConfig(
 Var BM: TBuildManager): String;
Begin
 GetActiveBuildConfig := BM.ActiveConfig;
End;

{ --- Definir la configuration de build active --- }

Procedure SetActiveBuildConfig(Var BM: TBuildManager;
 CfgName: String);
Begin
 BM.ActiveConfig := CfgName;
End;

{ --- Obtenir la plateforme active --- }

Function GetActivePlatform(
 Var BM: TBuildManager): String;
Begin
 GetActivePlatform := BM.ActivePlatform;
End;

{ --- Definir la plateforme active --- }

Procedure SetActivePlatform(Var BM: TBuildManager;
 Plat: String);
Begin
 BM.ActivePlatform := Plat;
End;

{ --- Verifier si un build est en cours --- }

Function IsBuildInProgress(
 Var BM: TBuildManager): Boolean;
Begin
 IsBuildInProgress := BM.IsBuilding;
End;

{ --- Obtenir le nombre de resultats de build --- }

Function GetBuildResultCount(
 Var BM: TBuildManager): Integer;
Begin
 GetBuildResultCount := BM.ResultCount;
End;

{ --- Obtenir un resultat de build par index --- }

Function GetBuildResult(Var BM: TBuildManager;
 Idx: Integer): TBuildProjectResult;
Var
 Empty: TBuildProjectResult;
Begin
 If (Idx >= 0) And (Idx < BM.ResultCount) Then
  GetBuildResult := BM.Results[Idx]
 Else Begin
  InitBuildProjectResult(Empty);
  GetBuildResult := Empty;
 End;
End;

{ --- Obtenir le nombre de projets reussis --- }

Function GetBuildTotalSucceeded(
 Var BM: TBuildManager): Integer;
Begin
 GetBuildTotalSucceeded := BM.TotalSucceeded;
End;

{ --- Obtenir le nombre de projets echoues --- }

Function GetBuildTotalFailed(
 Var BM: TBuildManager): Integer;
Begin
 GetBuildTotalFailed := BM.TotalFailed;
End;

{ --- Obtenir le nombre de projets ignores --- }

Function GetBuildTotalSkipped(
 Var BM: TBuildManager): Integer;
Begin
 GetBuildTotalSkipped := BM.TotalSkipped;
End;

{ --- Obtenir le nombre de projets a jour --- }

Function GetBuildTotalUpToDate(
 Var BM: TBuildManager): Integer;
Begin
 GetBuildTotalUpToDate := BM.TotalUpToDate;
End;

{ --- Obtenir le nombre de projets dans l ordre de build --- }

Function GetBuildOrderCount(
 Var BM: TBuildManager): Integer;
Begin
 GetBuildOrderCount := BM.OrderCount;
End;

{ --- Verifier si le dialogue de configurations est visible --- }

Function IsConfigManagerVisible(
 Var CM: TConfigurationManager): Boolean;
Begin
 IsConfigManagerVisible := CM.Visible;
End;

{ --- Obtenir la ligne selectionnee du gestionnaire --- }

Function GetConfigManagerSelectedRow(
 Var CM: TConfigurationManager): Integer;
Begin
 GetConfigManagerSelectedRow := CM.SelectedRow;
End;

{ --- Definir la ligne selectionnee du gestionnaire --- }

Procedure SetConfigManagerSelectedRow(
 Var CM: TConfigurationManager; Row: Integer);
Begin
 CM.SelectedRow := Row;
 CM.NeedRepaint := True;
End;

{ --- Verifier si le gestionnaire de build est vide --- }

Function IsBuildManagerEmpty(
 Var BM: TBuildManager): Boolean;
Begin
 IsBuildManagerEmpty := (BM.ResultCount = 0) And
  (BM.TotalSucceeded = 0) And
  (BM.TotalFailed = 0) And
  (BM.TotalSkipped = 0) And
  (BM.TotalUpToDate = 0) And
  (Not BM.IsBuilding);
End;

{ ============================================================
  TODO 29 - SUPPORT DU DEBOGAGE ET POINTS D ARRET [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser un point d arret --- }

Procedure InitBreakpoint(Var BP: TBreakpoint);
Begin
 BP.FileName := '';
 BP.Line := 0;
 BP.Enabled := True;
 BP.Condition := '';
 BP.HitCount := 0;
 BP.HitCountTarget := 0;
End;

{ --- Initialiser le gestionnaire de points d arret --- }

Procedure InitBreakpointManager(Var BPM: TBreakpointManager);
Var
 I: Integer;
Begin
 For I := 0 To MAX_BREAKPOINTS - 1 Do
  InitBreakpoint(BPM.Breakpoints[I]);
 BPM.Count := 0;
 BPM.State := DS_IDLE;
 BPM.ExecutablePath := '';
 BPM.LastExitCode := 0;
End;

{ --- Initialiser le panneau de debogage --- }

Procedure InitDebugPanel(Var DP: TDebugPanel);
Begin
 DP.Visible := False;
 DP.ActiveTab := DPT_BREAKPOINTS;
 DP.X := 100;
 DP.Y := 80;
 DP.Width := DEBUG_PANEL_WIDTH;
 DP.Height := DEBUG_PANEL_HEIGHT;
 DP.SelectedRow := 0;
 DP.ScrollTop := 0;
 DP.NeedRepaint := False;
End;

{ --- Trouver un point d arret par fichier et ligne --- }

Function FindBreakpoint(Var BPM: TBreakpointManager;
 FileName: String; Line: Integer): Integer;
Var
 I: Integer;
Begin
 FindBreakpoint := -1;
 For I := 0 To BPM.Count - 1 Do Begin
  If (BPM.Breakpoints[I].FileName = FileName) And
     (BPM.Breakpoints[I].Line = Line) Then Begin
   FindBreakpoint := I;
   Exit;
  End;
 End;
End;

{ --- Ajouter un point d arret --- }

Procedure AddBreakpoint(Var BPM: TBreakpointManager;
 FileName: String; Line: Integer);
Var
 Idx: Integer;
Begin
 Idx := FindBreakpoint(BPM, FileName, Line);
 If Idx >= 0 Then Exit; { deja present }
 If BPM.Count >= MAX_BREAKPOINTS Then Exit;
 BPM.Breakpoints[BPM.Count].FileName := FileName;
 BPM.Breakpoints[BPM.Count].Line := Line;
 BPM.Breakpoints[BPM.Count].Enabled := True;
 BPM.Breakpoints[BPM.Count].Condition := '';
 BPM.Breakpoints[BPM.Count].HitCount := 0;
 BPM.Breakpoints[BPM.Count].HitCountTarget := 0;
 Inc(BPM.Count);
End;

{ --- Supprimer un point d arret --- }

Procedure RemoveBreakpoint(Var BPM: TBreakpointManager;
 FileName: String; Line: Integer);
Var
 Idx, I: Integer;
Begin
 Idx := FindBreakpoint(BPM, FileName, Line);
 If Idx < 0 Then Exit;
 For I := Idx To BPM.Count - 2 Do
  BPM.Breakpoints[I] := BPM.Breakpoints[I + 1];
 Dec(BPM.Count);
 InitBreakpoint(BPM.Breakpoints[BPM.Count]);
End;

{ --- Basculer un point d arret (ajouter ou supprimer) --- }

Procedure ToggleBreakpoint(Var BPM: TBreakpointManager;
 FileName: String; Line: Integer);
Var
 Idx: Integer;
Begin
 Idx := FindBreakpoint(BPM, FileName, Line);
 If Idx >= 0 Then
  RemoveBreakpoint(BPM, FileName, Line)
 Else
  AddBreakpoint(BPM, FileName, Line);
End;

{ --- Activer un point d arret par index --- }

Procedure EnableBreakpoint(Var BPM: TBreakpointManager;
 Index: Integer);
Begin
 If (Index >= 0) And (Index < BPM.Count) Then
  BPM.Breakpoints[Index].Enabled := True;
End;

{ --- Desactiver un point d arret par index --- }

Procedure DisableBreakpoint(Var BPM: TBreakpointManager;
 Index: Integer);
Begin
 If (Index >= 0) And (Index < BPM.Count) Then
  BPM.Breakpoints[Index].Enabled := False;
End;

{ --- Supprimer tous les points d arret --- }

Procedure ClearAllBreakpoints(Var BPM: TBreakpointManager);
Var
 I: Integer;
Begin
 For I := 0 To BPM.Count - 1 Do
  InitBreakpoint(BPM.Breakpoints[I]);
 BPM.Count := 0;
End;

{ --- Dessiner un marqueur de point d arret dans la gouttiere --- }

Procedure DrawBreakpointMarker(Var Ed: TEditor;
 Line: Integer; Enabled: Boolean);
Var
 ScreenY, CenterX, CenterY, Radius: Integer;
Begin
 If Line < Ed.ScrollLine Then Exit;
 If Line >= Ed.ScrollLine + Ed.VisibleLines Then Exit;
 ScreenY := Ed.Y + (Line - Ed.ScrollLine) * Ed.CharHeight;
 CenterX := Ed.X - Ed.GutterWidth Div 2;
 CenterY := ScreenY + Ed.CharHeight Div 2;
 Radius := BP_MARKER_SIZE Div 2;
 If CenterX < Radius Then CenterX := Radius;
 { Stub : dessin du cercle du point d arret }
 { En mode reel, on utiliserait FillEllipse/Circle }
 If Enabled Then Begin
  { Point rouge plein }
 End Else Begin
  { Cercle rouge vide (desactive) }
 End;
End;

{ --- Dessiner les marqueurs de tous les points d arret visibles --- }

Procedure DrawAllBreakpointMarkers(Var Ed: TEditor;
 Var BPM: TBreakpointManager; FileName: String);
Var
 I: Integer;
Begin
 For I := 0 To BPM.Count - 1 Do Begin
  If BPM.Breakpoints[I].FileName = FileName Then
   DrawBreakpointMarker(Ed, BPM.Breakpoints[I].Line,
    BPM.Breakpoints[I].Enabled);
 End;
End;

{ --- Nom textuel de l etat du debogueur --- }

Function DebugStateName(S: TDebugState): String;
Begin
 Case S Of
  DS_IDLE:    DebugStateName := 'Idle';
  DS_RUNNING: DebugStateName := 'Running';
  DS_PAUSED:  DebugStateName := 'Paused';
  DS_STOPPED: DebugStateName := 'Stopped';
 Else
  DebugStateName := 'Unknown';
 End;
End;

{ --- Nom textuel d un onglet du panneau de debogage --- }

Function DebugPanelTabName(T: TDebugPanelTab): String;
Begin
 Case T Of
  DPT_BREAKPOINTS: DebugPanelTabName := 'Breakpoints';
  DPT_WATCH:       DebugPanelTabName := 'Watch';
  DPT_CALLSTACK:   DebugPanelTabName := 'Call Stack';
 Else
  DebugPanelTabName := 'Unknown';
 End;
End;

{ --- Demarrer sans debogage (Ctrl+F5) --- }

Procedure StartWithoutDebugging(Var BPM: TBreakpointManager;
 Var OP: TOutputPanel);
Begin
 If BPM.ExecutablePath = '' Then Begin
  AppendOutput(OP,
   'Erreur: aucun executable defini. Compilez d abord le projet.',
   Ord(OTK_BUILD));
  Exit;
 End;
 BPM.State := DS_RUNNING;
 AppendOutput(OP, 'Demarrage sans debogage: ' +
  BPM.ExecutablePath, Ord(OTK_BUILD));
 { Stub : lancement du processus externe }
 { En mode reel on utiliserait Exec() ou SwapVectors + Exec }
 AppendOutput(OP,
  'Programme termine (stub - execution non implementee).',
  Ord(OTK_BUILD));
 BPM.State := DS_STOPPED;
 BPM.LastExitCode := 0;
End;

{ --- Demarrer avec debogage (F5) --- }

Procedure StartWithDebugging(Var BPM: TBreakpointManager;
 Var OP: TOutputPanel);
Begin
 AppendOutput(OP,
  'Le debogage interactif n est pas encore supporte.',
  Ord(OTK_BUILD));
 AppendOutput(OP,
  'Lancement sans debogage a la place...', Ord(OTK_BUILD));
 StartWithoutDebugging(BPM, OP);
End;

{ --- Arreter le debogage (Shift+F5) --- }

Procedure StopDebugging(Var BPM: TBreakpointManager;
 Var OP: TOutputPanel);
Begin
 If BPM.State = DS_IDLE Then Exit;
 BPM.State := DS_STOPPED;
 AppendOutput(OP, 'Debogage arrete.', Ord(OTK_BUILD));
 BPM.State := DS_IDLE;
End;

{ --- Pas a pas principal (F10) - stub --- }

Procedure StepOver(Var BPM: TBreakpointManager;
 Var OP: TOutputPanel);
Begin
 AppendOutput(OP,
  'Pas a pas principal (Step Over) non supporte.',
  Ord(OTK_BUILD));
End;

{ --- Pas a pas detaille (F11) - stub --- }

Procedure StepInto(Var BPM: TBreakpointManager;
 Var OP: TOutputPanel);
Begin
 AppendOutput(OP,
  'Pas a pas detaille (Step Into) non supporte.',
  Ord(OTK_BUILD));
End;

{ --- Dessiner le panneau de points d arret --- }

Procedure DrawBreakpointPanel(Var DP: TDebugPanel;
 Var BPM: TBreakpointManager);
Begin
 If Not DP.Visible Then Exit;
 If DP.ActiveTab <> DPT_BREAKPOINTS Then Exit;
 DP.NeedRepaint := False;
 { Stub : dessin de la liste des points d arret }
End;

{ --- Dessiner le panneau espion (Watch) - stub --- }

Procedure DrawWatchPanel(Var DP: TDebugPanel);
Begin
 If Not DP.Visible Then Exit;
 If DP.ActiveTab <> DPT_WATCH Then Exit;
 DP.NeedRepaint := False;
 { Stub : affiche "Non disponible" }
End;

{ --- Dessiner le panneau pile d appels (Call Stack) - stub --- }

Procedure DrawCallStackPanel(Var DP: TDebugPanel);
Begin
 If Not DP.Visible Then Exit;
 If DP.ActiveTab <> DPT_CALLSTACK Then Exit;
 DP.NeedRepaint := False;
 { Stub : affiche "Non disponible" }
End;

{ --- Dessiner le panneau de debogage selon l onglet actif --- }

Procedure DrawDebugPanel(Var DP: TDebugPanel;
 Var BPM: TBreakpointManager);
Begin
 If Not DP.Visible Then Exit;
 Case DP.ActiveTab Of
  DPT_BREAKPOINTS: DrawBreakpointPanel(DP, BPM);
  DPT_WATCH:       DrawWatchPanel(DP);
  DPT_CALLSTACK:   DrawCallStackPanel(DP);
 End;
End;

{ --- Gerer une touche dans le panneau de debogage --- }

Procedure HandleDebugPanelKey(Var DP: TDebugPanel;
 Var BPM: TBreakpointManager; Key: Word);
Begin
 If Not DP.Visible Then Exit;
 Case Key Of
  $4800: { Fleche haut }
   If DP.SelectedRow > 0 Then Begin
    Dec(DP.SelectedRow);
    DP.NeedRepaint := True;
   End;
  $5000: { Fleche bas }
   Begin
    If (DP.ActiveTab = DPT_BREAKPOINTS) And
       (DP.SelectedRow < BPM.Count - 1) Then Begin
     Inc(DP.SelectedRow);
     DP.NeedRepaint := True;
    End;
   End;
  $0020: { Espace : basculer enable/disable }
   If (DP.ActiveTab = DPT_BREAKPOINTS) And
      (DP.SelectedRow >= 0) And
      (DP.SelectedRow < BPM.Count) Then Begin
    BPM.Breakpoints[DP.SelectedRow].Enabled :=
     Not BPM.Breakpoints[DP.SelectedRow].Enabled;
    DP.NeedRepaint := True;
   End;
  $5300: { Suppr : supprimer le point d arret selectionne }
   If (DP.ActiveTab = DPT_BREAKPOINTS) And
      (DP.SelectedRow >= 0) And
      (DP.SelectedRow < BPM.Count) Then Begin
    RemoveBreakpoint(BPM,
     BPM.Breakpoints[DP.SelectedRow].FileName,
     BPM.Breakpoints[DP.SelectedRow].Line);
    If DP.SelectedRow >= BPM.Count Then
     DP.SelectedRow := BPM.Count - 1;
    If DP.SelectedRow < 0 Then
     DP.SelectedRow := 0;
    DP.NeedRepaint := True;
   End;
  $001B: { Echap }
   DP.Visible := False;
  $000F: { Tab : changer d onglet }
   Begin
    Case DP.ActiveTab Of
     DPT_BREAKPOINTS: DP.ActiveTab := DPT_WATCH;
     DPT_WATCH:       DP.ActiveTab := DPT_CALLSTACK;
     DPT_CALLSTACK:   DP.ActiveTab := DPT_BREAKPOINTS;
    End;
    DP.SelectedRow := 0;
    DP.ScrollTop := 0;
    DP.NeedRepaint := True;
   End;
 End;
End;

{ --- Gerer un evenement du panneau de debogage --- }

Procedure HandleDebugPanelEvent(Var DP: TDebugPanel;
 Var BPM: TBreakpointManager);
Begin
 If Not DP.Visible Then Exit;
 { Stub : gestion des evenements souris }
End;

{ --- Afficher le panneau de debogage --- }

Procedure ShowDebugPanel(Var DP: TDebugPanel);
Begin
 DP.Visible := True;
 DP.NeedRepaint := True;
End;

{ --- Masquer le panneau de debogage --- }

Procedure HideDebugPanel(Var DP: TDebugPanel);
Begin
 DP.Visible := False;
End;

{ --- Definir l onglet actif du panneau --- }

Procedure SetDebugPanelTab(Var DP: TDebugPanel;
 Tab: TDebugPanelTab);
Begin
 DP.ActiveTab := Tab;
 DP.SelectedRow := 0;
 DP.ScrollTop := 0;
 DP.NeedRepaint := True;
End;

{ --- Definir le chemin de l executable --- }

Procedure SetExecutablePath(Var BPM: TBreakpointManager;
 Path: String);
Begin
 BPM.ExecutablePath := Path;
End;

{ --- Obtenir le chemin de l executable --- }

Function GetExecutablePath(
 Var BPM: TBreakpointManager): String;
Begin
 GetExecutablePath := BPM.ExecutablePath;
End;

{ --- Obtenir le nombre de points d arret --- }

Function GetBreakpointCount(
 Var BPM: TBreakpointManager): Integer;
Begin
 GetBreakpointCount := BPM.Count;
End;

{ --- Obtenir un point d arret par index --- }

Function GetBreakpointByIndex(Var BPM: TBreakpointManager;
 Idx: Integer): TBreakpoint;
Var
 Empty: TBreakpoint;
Begin
 If (Idx >= 0) And (Idx < BPM.Count) Then
  GetBreakpointByIndex := BPM.Breakpoints[Idx]
 Else Begin
  InitBreakpoint(Empty);
  GetBreakpointByIndex := Empty;
 End;
End;

{ --- Verifier si un index de point d arret est valide --- }

Function IsValidBreakpointIndex(
 Var BPM: TBreakpointManager; Idx: Integer): Boolean;
Begin
 IsValidBreakpointIndex := (Idx >= 0) And (Idx < BPM.Count);
End;

{ --- Obtenir l etat du debogueur --- }

Function GetDebugState(
 Var BPM: TBreakpointManager): TDebugState;
Begin
 GetDebugState := BPM.State;
End;

{ --- Obtenir le code de sortie du dernier run --- }

Function GetLastExitCode(
 Var BPM: TBreakpointManager): Integer;
Begin
 GetLastExitCode := BPM.LastExitCode;
End;

{ --- Verifier si le panneau de debogage est visible --- }

Function IsDebugPanelVisible(
 Var DP: TDebugPanel): Boolean;
Begin
 IsDebugPanelVisible := DP.Visible;
End;

{ --- Obtenir l onglet actif du panneau de debogage --- }

Function GetDebugPanelActiveTab(
 Var DP: TDebugPanel): TDebugPanelTab;
Begin
 GetDebugPanelActiveTab := DP.ActiveTab;
End;

{ --- Obtenir la ligne selectionnee dans le panneau --- }

Function GetDebugPanelSelectedRow(
 Var DP: TDebugPanel): Integer;
Begin
 GetDebugPanelSelectedRow := DP.SelectedRow;
End;

{ --- Definir la ligne selectionnee dans le panneau --- }

Procedure SetDebugPanelSelectedRow(Var DP: TDebugPanel;
 Row: Integer);
Begin
 DP.SelectedRow := Row;
 DP.NeedRepaint := True;
End;

{ --- Compter les points d arret actifs --- }

Function CountEnabledBreakpoints(
 Var BPM: TBreakpointManager): Integer;
Var
 I, N: Integer;
Begin
 N := 0;
 For I := 0 To BPM.Count - 1 Do Begin
  If BPM.Breakpoints[I].Enabled Then
   Inc(N);
 End;
 CountEnabledBreakpoints := N;
End;

{ --- Compter les points d arret dans un fichier --- }

Function CountFileBreakpoints(Var BPM: TBreakpointManager;
 FileName: String): Integer;
Var
 I, N: Integer;
Begin
 N := 0;
 For I := 0 To BPM.Count - 1 Do Begin
  If BPM.Breakpoints[I].FileName = FileName Then
   Inc(N);
 End;
 CountFileBreakpoints := N;
End;

{ --- Verifier si une ligne a un point d arret --- }

Function HasBreakpointAtLine(Var BPM: TBreakpointManager;
 FileName: String; Line: Integer): Boolean;
Begin
 HasBreakpointAtLine := FindBreakpoint(BPM, FileName, Line) >= 0;
End;

{ --- Verifier si le gestionnaire est vide --- }

Function IsBreakpointManagerEmpty(
 Var BPM: TBreakpointManager): Boolean;
Begin
 IsBreakpointManagerEmpty := (BPM.Count = 0) And
  (BPM.State = DS_IDLE);
End;

{ ============================================================
  TODO 30 - BARRE D ETAT, INTEGRATION FINALE ET POLISSAGE
            [IMPLEMENTE]
  ============================================================ }

{ --- Initialiser la barre d etat --- }

Procedure InitStatusBar(Var SB: TStatusBar);
Begin
 SB.CursorLine := 1;
 SB.CursorCol := 1;
 SB.InsertMode := IM_INSERT;
 SB.Encoding := FE_ASCII;
 SB.LineEnding := LE_CRLF;
 SB.Language := '';
 SB.FileName := '';
 SB.BuildStatus := 'Ready';
 SB.NeedRepaint := True;
End;

{ --- Nom du mode d insertion --- }

Function InsertModeName(Mode: TInsertMode): String;
Begin
 Case Mode Of
  IM_INSERT:    InsertModeName := 'INS';
  IM_OVERWRITE: InsertModeName := 'OVR';
 Else
  InsertModeName := '???';
 End;
End;

{ --- Nom de l encodage --- }

Function FileEncodingName(Enc: TFileEncoding): String;
Begin
 Case Enc Of
  FE_ASCII: FileEncodingName := 'ASCII';
  FE_UTF8:  FileEncodingName := 'UTF-8';
 Else
  FileEncodingName := '???';
 End;
End;

{ --- Nom du type de fin de ligne --- }

Function LineEndingName(LE: TLineEnding): String;
Begin
 Case LE Of
  LE_CRLF: LineEndingName := 'CRLF';
  LE_LF:   LineEndingName := 'LF';
  LE_CR:   LineEndingName := 'CR';
 Else
  LineEndingName := '???';
 End;
End;

{ --- Mettre a jour la barre d etat depuis l editeur actif --- }

Procedure UpdateStatusBar(Var SB: TStatusBar;
 Var WM: TWindowManager);
Var
 Idx: Integer;
Begin
 Idx := WM.ActiveIdx;
 If (Idx >= 0) And (Idx < WM.WinCount) Then Begin
  SB.CursorLine := WM.Windows[Idx].CursorY + 1;
  SB.CursorCol := WM.Windows[Idx].CursorX + 1;
  SB.FileName := WM.Windows[Idx].FileName;
  SB.Language := 'Text';
 End Else Begin
  SB.CursorLine := 1;
  SB.CursorCol := 1;
  SB.FileName := '';
  SB.Language := '';
 End;
 SB.NeedRepaint := True;
End;

{ --- Dessiner la barre d etat --- }

Procedure DrawStatusBar(Var SB: TStatusBar);
Var
 Y, ScreenW, X: Integer;
 PosStr: String;
Begin
 ScreenW := GetScreenWidth;
 Y := GetScreenHeight - STATUSBAR_HEIGHT;
 DrawFilledRect(0, Y, ScreenW, Y + STATUSBAR_HEIGHT, CLR_STATUSBAR);
 X := STATUS_BAR_PADDING;
 { Position du curseur }
 PosStr := 'Ln ' + IntToStr(SB.CursorLine) + ', Col ' +
  IntToStr(SB.CursorCol);
 DrawText(X, Y + 3, PosStr, 15);
 X := X + Length(PosStr) * 8 + STATUS_BAR_FIELD_GAP;
 { Mode d insertion }
 DrawText(X, Y + 3, InsertModeName(SB.InsertMode), 15);
 X := X + 24 + STATUS_BAR_FIELD_GAP;
 { Encodage }
 DrawText(X, Y + 3, FileEncodingName(SB.Encoding), 15);
 X := X + 40 + STATUS_BAR_FIELD_GAP;
 { Fin de ligne }
 DrawText(X, Y + 3, LineEndingName(SB.LineEnding), 15);
 X := X + 32 + STATUS_BAR_FIELD_GAP;
 { Langage }
 If SB.Language <> '' Then Begin
  DrawText(X, Y + 3, SB.Language, 15);
  X := X + Length(SB.Language) * 8 + STATUS_BAR_FIELD_GAP;
 End;
 { Nom du fichier }
 If SB.FileName <> '' Then
  DrawText(X, Y + 3, SB.FileName, 15);
 { Etat du build a droite }
 If SB.BuildStatus <> '' Then
  DrawText(ScreenW - Length(SB.BuildStatus) * 8 -
   STATUS_BAR_PADDING, Y + 3, SB.BuildStatus, 15);
 SB.NeedRepaint := False;
End;

{ --- Initialiser la liste MRU --- }

Procedure InitMRUList(Var MRU: TMRUList);
Var
 I: Integer;
Begin
 For I := 0 To MRU_MAX_ENTRIES - 1 Do
  MRU.Entries[I].FilePath := '';
 MRU.Count := 0;
End;

{ --- Ajouter un fichier a la liste MRU --- }

Procedure AddMRUEntry(Var MRU: TMRUList; FilePath: String);
Var
 I, J: Integer;
Begin
 { Verifier si deja present et le retirer }
 For I := 0 To MRU.Count - 1 Do Begin
  If MRU.Entries[I].FilePath = FilePath Then Begin
   For J := I To MRU.Count - 2 Do
    MRU.Entries[J] := MRU.Entries[J + 1];
   Dec(MRU.Count);
  End;
 End;
 { Decaler les entrees vers le bas }
 If MRU.Count >= MRU_MAX_ENTRIES Then
  MRU.Count := MRU_MAX_ENTRIES - 1;
 For I := MRU.Count DownTo 1 Do
  MRU.Entries[I] := MRU.Entries[I - 1];
 { Inserer en premiere position }
 MRU.Entries[0].FilePath := FilePath;
 Inc(MRU.Count);
End;

{ --- Sauvegarder la liste MRU --- }

Procedure SaveMRUList(Var MRU: TMRUList);
Var
 F: Text;
 I: Integer;
Begin
 Assign(F, MRU_FILENAME);
 {$I-}
 Rewrite(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 For I := 0 To MRU.Count - 1 Do
  WriteLn(F, MRU.Entries[I].FilePath);
 Close(F);
End;

{ --- Charger la liste MRU --- }

Procedure LoadMRUList(Var MRU: TMRUList);
Var
 F: Text;
 Line: String;
Begin
 InitMRUList(MRU);
 Assign(F, MRU_FILENAME);
 {$I-}
 Reset(F);
 {$I+}
 If IOResult <> 0 Then Exit;
 While (Not Eof(F)) And (MRU.Count < MRU_MAX_ENTRIES) Do Begin
  ReadLn(F, Line);
  If Line <> '' Then Begin
   MRU.Entries[MRU.Count].FilePath := Line;
   Inc(MRU.Count);
  End;
 End;
 Close(F);
End;

{ --- Obtenir le nombre d entrees MRU --- }

Function GetMRUCount(Var MRU: TMRUList): Integer;
Begin
 GetMRUCount := MRU.Count;
End;

{ --- Obtenir une entree MRU par index --- }

Function GetMRUEntry(Var MRU: TMRUList; Idx: Integer): String;
Begin
 If (Idx >= 0) And (Idx < MRU.Count) Then
  GetMRUEntry := MRU.Entries[Idx].FilePath
 Else
  GetMRUEntry := '';
End;

{ --- Effacer la liste MRU --- }

Procedure ClearMRUList(Var MRU: TMRUList);
Begin
 InitMRUList(MRU);
End;

{ --- Verifier si la liste MRU est vide --- }

Function IsMRUListEmpty(Var MRU: TMRUList): Boolean;
Begin
 IsMRUListEmpty := MRU.Count = 0;
End;

{ --- Initialiser la page de demarrage --- }

Procedure InitStartPage(Var SP: TStartPage);
Begin
 SP.Visible := True;
 SP.SelectedItem := -1;
 SP.ScrollTop := 0;
 SP.NeedRepaint := True;
End;

{ --- Dessiner la page de demarrage --- }

Procedure DrawStartPage(Var SP: TStartPage;
 Var MRU: TMRUList);
Var
 ScreenW, CenterX, I, Y: Integer;
 Title: String;
Begin
 If Not SP.Visible Then Exit;
 ScreenW := GetScreenWidth;
 CenterX := ScreenW Div 2;
 { Titre }
 Title := 'DEVENV - IDE Visual Studio';
 DrawText(CenterX - (Length(Title) * 8 Div 2),
  START_PAGE_TITLE_Y, Title, CLR_EDITOR_TEXT);
 { Sous-titre }
 Title := 'DEV-COOLS v' + IDE_VERSION;
 DrawText(CenterX - (Length(Title) * 8 Div 2),
  START_PAGE_TITLE_Y + 20, Title, 8);
 { Boutons }
 DrawFilledRect(CenterX - START_PAGE_BTN_WIDTH - 10,
  START_PAGE_BTN_Y + 50,
  CenterX - 10,
  START_PAGE_BTN_Y + 50 + START_PAGE_BTN_HEIGHT, CLR_STATUSBAR);
 DrawText(CenterX - START_PAGE_BTN_WIDTH - 10 + 12,
  START_PAGE_BTN_Y + 50 + 6, 'Nouveau projet', 15);
 DrawFilledRect(CenterX + 10, START_PAGE_BTN_Y + 50,
  CenterX + 10 + START_PAGE_BTN_WIDTH,
  START_PAGE_BTN_Y + 50 + START_PAGE_BTN_HEIGHT, CLR_STATUSBAR);
 DrawText(CenterX + 10 + 16,
  START_PAGE_BTN_Y + 50 + 6, 'Ouvrir projet', 15);
 { Liste des fichiers recents }
 If MRU.Count > 0 Then Begin
  DrawText(CenterX - 100, START_PAGE_LIST_Y + 20,
   'Fichiers recents :', CLR_EDITOR_TEXT);
  Y := START_PAGE_LIST_Y + 44;
  For I := 0 To MRU.Count - 1 Do Begin
   If I >= 10 Then Break;
   If I = SP.SelectedItem Then
    DrawFilledRect(CenterX - 200, Y, CenterX + 200,
     Y + START_PAGE_ITEM_HEIGHT, CLR_SELECTION);
   DrawText(CenterX - 196, Y + 2,
    MRU.Entries[I].FilePath, CLR_EDITOR_TEXT);
   Y := Y + START_PAGE_ITEM_HEIGHT;
  End;
 End Else Begin
  DrawText(CenterX - 80, START_PAGE_LIST_Y + 20,
   'Aucun fichier recent', 8);
 End;
 SP.NeedRepaint := False;
End;

{ --- Gerer les evenements de la page de demarrage --- }

Procedure HandleStartPageEvent(Var SP: TStartPage;
 Var MRU: TMRUList; Var Ev: TEvent);
Var
 ScreenW, CenterX, BtnY, ItemIdx: Integer;
Begin
 If Not SP.Visible Then Exit;
 ScreenW := GetScreenWidth;
 CenterX := ScreenW Div 2;
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
   { Verifier clic sur bouton Nouveau }
   BtnY := START_PAGE_BTN_Y + 50;
   If (Ev.MouseX >= CenterX - START_PAGE_BTN_WIDTH - 10) And
      (Ev.MouseX < CenterX - 10) And
      (Ev.MouseY >= BtnY) And
      (Ev.MouseY < BtnY + START_PAGE_BTN_HEIGHT) Then Begin
    SP.Visible := False;
    SP.NeedRepaint := True;
    Exit;
   End;
   { Verifier clic sur bouton Ouvrir }
   If (Ev.MouseX >= CenterX + 10) And
      (Ev.MouseX < CenterX + 10 + START_PAGE_BTN_WIDTH) And
      (Ev.MouseY >= BtnY) And
      (Ev.MouseY < BtnY + START_PAGE_BTN_HEIGHT) Then Begin
    SP.Visible := False;
    SP.NeedRepaint := True;
    Exit;
   End;
   { Verifier clic sur un element de la liste MRU }
   If MRU.Count > 0 Then Begin
    ItemIdx := (Ev.MouseY - (START_PAGE_LIST_Y + 44)) Div
     START_PAGE_ITEM_HEIGHT;
    If (ItemIdx >= 0) And (ItemIdx < MRU.Count) And
       (ItemIdx < 10) Then Begin
     SP.SelectedItem := ItemIdx;
     SP.Visible := False;
     SP.NeedRepaint := True;
    End;
   End;
 End;
 If (Ev.Kind = EV_KEY_DOWN) Or (Ev.Kind = EV_KEY_CHAR) Then Begin
  Case Ev.KeyCode Of
   $1C0D: Begin { Entree }
    SP.Visible := False;
    SP.NeedRepaint := True;
   End;
   $011B: Begin { Echap }
    SP.Visible := False;
    SP.NeedRepaint := True;
   End;
  End;
 End;
End;

{ --- Masquer la page de demarrage --- }

Procedure HideStartPage(Var SP: TStartPage);
Begin
 SP.Visible := False;
 SP.NeedRepaint := True;
End;

{ --- Verifier si la page de demarrage est visible --- }

Function IsStartPageVisible(Var SP: TStartPage): Boolean;
Begin
 IsStartPageVisible := SP.Visible;
End;

{ --- Obtenir l element selectionne de la page de demarrage --- }

Function GetStartPageSelectedItem(
 Var SP: TStartPage): Integer;
Begin
 GetStartPageSelectedItem := SP.SelectedItem;
End;

{ --- Dessiner tous les widgets de l IDE --- }

Procedure DrawAllWidgets;
Begin
 If StartPage.Visible Then Begin
  ClearScreen(CLR_BACKGROUND);
  DrawStartPage(StartPage, MRUList);
  DrawStatusBar(StatusBar);
  Exit;
 End;
 DrawMenuBar;
 DrawToolBar;
 DrawWindowTabs;
 DrawExplorer(SolExplorer);
 DrawPropertiesPanel(PropsPanel);
 DrawOutputPanel(OutputPanel);
 DrawErrorList(ErrorList);
 DrawStatusBar(StatusBar);
End;

{ --- Traiter un evenement global --- }

Procedure DispatchEvent(Var Ev: TEvent);
Begin
 If Ev.Kind = EV_NONE Then Exit;
 { Page de demarrage en priorite si visible }
 If StartPage.Visible Then Begin
  HandleStartPageEvent(StartPage, MRUList, Ev);
  Exit;
 End;
 { Raccourcis clavier globaux }
 If (Ev.Kind = EV_KEY_DOWN) Or (Ev.Kind = EV_KEY_CHAR) Then Begin
  Case Ev.KeyCode Of
   $2D00: Begin { Alt+X : quitter }
    QuitRequested := True;
    Exit;
   End;
   $3B00: Begin { F1 : aide (stub) }
    { A implementer }
    Exit;
   End;
  End;
 End;
 { Distribuer aux panneaux dans l ordre de priorite }
 If MenuActive Then Begin
  HandleMenuEvent(MainMenuBar, Ev);
  Exit;
 End;
 If FindReplaceDlg.Base.Visible Then Begin
  HandleFindDialogEvent(FindReplaceDlg, Ev);
  Exit;
 End;
 If GoToLineDlg.Visible Then Begin
  HandleGoToLineEvent(GoToLineDlg, Ev);
  Exit;
 End;
 If DbgPanel.Visible Then Begin
  HandleDebugPanelEvent(DbgPanel, BPMgr, Ev);
  Exit;
 End;
 { Evenements pour la barre de menus }
 HandleMenuBarEvent(MainMenuBar, Ev);
 { Evenements pour la barre d outils }
 HandleToolBarEvent(MainToolBar, Ev);
 { Evenements pour l explorateur }
 HandleExplorerEvent(SolExplorer, Ev);
 { Evenements pour le panneau de proprietes }
 HandlePropertiesEvent(PropsPanel, Ev);
 { Evenements pour le panneau de sortie }
 HandleOutputEvent(OutputPanel, Ev);
 { Evenements pour la liste d erreurs }
 HandleErrorListEvent(ErrorList, Ev);
 { Evenements pour l editeur actif }
 If (WinMgr.ActiveIdx >= 0) And
    (WinMgr.ActiveIdx < WinMgr.Count) Then
  HandleEditorEvent(WinMgr.Editors[WinMgr.ActiveIdx], Ev);
End;

{ --- Boucle principale de l IDE --- }

Procedure MainLoop;
Var
 Ev: TEvent;
Begin
 QuitRequested := False;
 While Not QuitRequested Do Begin
  PollEvents(EvQueue, Ev);
  If Ev.Kind <> EV_NONE Then Begin
   DispatchEvent(Ev);
   UpdateStatusBar(StatusBar, WinMgr);
   DrawAllWidgets;
  End;
 End;
End;

{ --- Demarrage de l IDE (procedure Run) --- }

Procedure Run;
Begin
 InitStatusBar(StatusBar);
 InitMRUList(MRUList);
 LoadMRUList(MRUList);
 InitStartPage(StartPage);
 QuitRequested := False;
 DrawAllWidgets;
 MainLoop;
 SaveMRUList(MRUList);
End;

{ --- Obtenir la position du curseur (ligne) --- }

Function GetStatusBarLine(Var SB: TStatusBar): Integer;
Begin
 GetStatusBarLine := SB.CursorLine;
End;

{ --- Obtenir la position du curseur (colonne) --- }

Function GetStatusBarCol(Var SB: TStatusBar): Integer;
Begin
 GetStatusBarCol := SB.CursorCol;
End;

{ --- Obtenir le mode d insertion --- }

Function GetStatusBarInsertMode(
 Var SB: TStatusBar): TInsertMode;
Begin
 GetStatusBarInsertMode := SB.InsertMode;
End;

{ --- Definir le mode d insertion --- }

Procedure SetStatusBarInsertMode(Var SB: TStatusBar;
 Mode: TInsertMode);
Begin
 SB.InsertMode := Mode;
 SB.NeedRepaint := True;
End;

{ --- Basculer le mode d insertion --- }

Procedure ToggleInsertMode(Var SB: TStatusBar);
Begin
 If SB.InsertMode = IM_INSERT Then
  SB.InsertMode := IM_OVERWRITE
 Else
  SB.InsertMode := IM_INSERT;
 SB.NeedRepaint := True;
End;

{ --- Obtenir l encodage --- }

Function GetStatusBarEncoding(
 Var SB: TStatusBar): TFileEncoding;
Begin
 GetStatusBarEncoding := SB.Encoding;
End;

{ --- Definir l encodage --- }

Procedure SetStatusBarEncoding(Var SB: TStatusBar;
 Enc: TFileEncoding);
Begin
 SB.Encoding := Enc;
 SB.NeedRepaint := True;
End;

{ --- Obtenir le type de fin de ligne --- }

Function GetStatusBarLineEnding(
 Var SB: TStatusBar): TLineEnding;
Begin
 GetStatusBarLineEnding := SB.LineEnding;
End;

{ --- Definir le type de fin de ligne --- }

Procedure SetStatusBarLineEnding(Var SB: TStatusBar;
 LE: TLineEnding);
Begin
 SB.LineEnding := LE;
 SB.NeedRepaint := True;
End;

{ --- Obtenir le langage --- }

Function GetStatusBarLanguage(Var SB: TStatusBar): String;
Begin
 GetStatusBarLanguage := SB.Language;
End;

{ --- Definir le langage --- }

Procedure SetStatusBarLanguage(Var SB: TStatusBar;
 Lang: String);
Begin
 SB.Language := Lang;
 SB.NeedRepaint := True;
End;

{ --- Obtenir le nom du fichier --- }

Function GetStatusBarFileName(Var SB: TStatusBar): String;
Begin
 GetStatusBarFileName := SB.FileName;
End;

{ --- Definir le nom du fichier --- }

Procedure SetStatusBarFileName(Var SB: TStatusBar;
 FName: String);
Begin
 SB.FileName := FName;
 SB.NeedRepaint := True;
End;

{ --- Obtenir l etat du build --- }

Function GetStatusBarBuildStatus(Var SB: TStatusBar): String;
Begin
 GetStatusBarBuildStatus := SB.BuildStatus;
End;

{ --- Definir l etat du build --- }

Procedure SetStatusBarBuildStatus(Var SB: TStatusBar;
 Status: String);
Begin
 SB.BuildStatus := Status;
 SB.NeedRepaint := True;
End;

{ --- Verifier si la barre d etat doit etre redessinee --- }

Function IsStatusBarDirty(Var SB: TStatusBar): Boolean;
Begin
 IsStatusBarDirty := SB.NeedRepaint;
End;

{ --- Verifier si la sortie est demandee --- }

Function IsQuitRequested: Boolean;
Begin
 IsQuitRequested := QuitRequested;
End;

{ --- Demander la sortie --- }

Procedure RequestQuit;
Begin
 QuitRequested := True;
End;

{ --- Annuler la demande de sortie --- }

Procedure CancelQuit;
Begin
 QuitRequested := False;
End;

{ --- Rapport de version --- }

Function GetIDEVersion: String;
Begin
 GetIDEVersion := IDE_VERSION;
End;

{ --- Verifier si la page de demarrage doit etre redessinee --- }

Function IsStartPageDirty(Var SP: TStartPage): Boolean;
Begin
 IsStartPageDirty := SP.NeedRepaint;
End;

{ --- Verifier si la barre d etat est vide (defaut) --- }

Function IsStatusBarEmpty(Var SB: TStatusBar): Boolean;
Begin
 IsStatusBarEmpty := (SB.FileName = '') And
  (SB.Language = '') And (SB.CursorLine = 1) And
  (SB.CursorCol = 1);
End;


 InitOptions(Opts);
 ParseCommandLine(Opts);
 If Opts.Verbose Then
  ShowVersion;
 InitializeGraphics;
 ClearScreen(CLR_BACKGROUND);
 InitEventQueue;
 InitMouse;
 InitWidgetSystem;
 InitMenuBar;
 DrawMenuBar;
 InitToolBar;
 DrawToolBar;
 InitWindowManager;
 DrawWindowTabs;
 InitCSharpHighlighter(CSharpHL);
 InitVBNetHighlighter(VBNetHL);
 InitPascalHighlighter(PascalHL);
 InitExplorer(SolExplorer);
 DrawExplorer(SolExplorer);
 InitPropertiesPanel(PropsPanel);
 DrawPropertiesPanel(PropsPanel);
 InitOutputPanel(OutputPanel);
 DrawOutputPanel(OutputPanel);
 InitErrorList(ErrorList);
 DrawErrorList(ErrorList);
 InitFindReplaceDialog(FindReplaceDlg);
 InitGoToLineDialog(GoToLineDlg);
 InitCSCContext(CSCContext);
 InitVBCContext(VBCContext);
 InitTPCContext(TPCContext);
 InitBuildManager(BuildMgr);
 InitConfigurationManager(CfgMgr);
 InitBreakpointManager(BPMgr);
 InitDebugPanel(DbgPanel);
 Run;
 ShutdownGraphics;
END.
