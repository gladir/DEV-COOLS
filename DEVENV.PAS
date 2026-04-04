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

  TODO 09 - EDITEUR DE TEXTE : EDITION DE BASE [A FAIRE]
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

  TODO 10 - EDITEUR DE TEXTE : SELECTION, PRESSE-PAPIER, ANNULER [A FAIRE]
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

  TODO 11 - MOTEUR DE COLORATION SYNTAXIQUE [A FAIRE]
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

  TODO 12 - COLORATION SYNTAXIQUE C# [A FAIRE]
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

  TODO 13 - COLORATION SYNTAXIQUE VB.NET [A FAIRE]
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

  TODO 14 - COLORATION SYNTAXIQUE PASCAL [A FAIRE]
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

  TODO 15 - PARSEUR DE FICHIERS SOLUTION (.SLN) [A FAIRE]
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

  TODO 16 - PARSEUR DE FICHIERS PROJET (.CSPROJ, .VBPROJ, .DPPROJ) [A FAIRE]
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

  TODO 17 - EXPLORATEUR DE SOLUTION (PANNEAU DROIT) [A FAIRE]
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

  TODO 18 - PANNEAU DE PROPRIETES [A FAIRE]
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

  TODO 19 - PANNEAU DE SORTIE (OUTPUT) [A FAIRE]
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

  TODO 20 - PANNEAU LISTE D ERREURS (ERROR LIST) [A FAIRE]
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

  TODO 21 - BOITES DE DIALOGUE : FICHIERS [A FAIRE]
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

  TODO 22 - BOITES DE DIALOGUE : PROJET ET SOLUTION [A FAIRE]
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

  TODO 23 - BOITES DE DIALOGUE : OPTIONS DE L IDE [A FAIRE]
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

  TODO 24 - RECHERCHER ET REMPLACER [A FAIRE]
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

  TODO 25 - INTEGRATION COMPILATEUR C# (CSCW32/CSC86) [A FAIRE]
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

  TODO 26 - INTEGRATION COMPILATEUR VB.NET (VBCW32/VBC86) [A FAIRE]
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

  TODO 27 - INTEGRATION COMPILATEUR PASCAL (TPCW32/VAXPAS86) [A FAIRE]
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

  TODO 28 - SYSTEME DE BUILD ET CONFIGURATION [A FAIRE]
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

  TODO 29 - SUPPORT DU DEBOGAGE ET POINTS D ARRET [A FAIRE]
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

  TODO 30 - BARRE D ETAT, INTEGRATION FINALE ET POLISSAGE [A FAIRE]
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

 { Onglets de fenetres d edition }
 TAB_HEIGHT            = 22;      { hauteur d un onglet            }
 TAB_MAX_WIDTH         = 160;     { largeur max d un onglet        }
 TAB_CLOSE_SIZE        = 12;      { taille bouton fermeture (X)    }
 TAB_PADDING           = 8;       { marge interne d un onglet      }

 { Dimensions de l interface en pixels }
 TOOLBAR_HEIGHT        = 28;
 MENUBAR_HEIGHT        = 20;
 STATUSBAR_HEIGHT      = 20;
 EXPLORER_WIDTH        = 220;
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

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
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

{ --- Dessin de tous les widgets --- }

Procedure DrawAllWidgets;
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

{ --- Distribution des evenements --- }

Procedure DispatchEvent(Var Ev: TEvent);
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

BEGIN
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
 { Boucle principale a venir (TODO 09+) }
 ShutdownGraphics;
END.