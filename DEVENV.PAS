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

  TODO 04 - SYSTEME DE WIDGETS GUI (BASE) [A FAIRE]
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

  TODO 05 - BARRE DE MENUS ET MENUS DEROULANTS [A FAIRE]
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

  TODO 06 - BARRE D OUTILS ET BOUTONS D ICONES [A FAIRE]
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

  TODO 07 - GESTIONNAIRE DE FENETRES MULTIPLES (MDI) [A FAIRE]
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

  TODO 08 - TAMPON DE TEXTE ET GESTION DES LIGNES [A FAIRE]
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

 { Limites des signets et points d arret }
 MAX_BOOKMARKS         = 128;
 MAX_BREAKPOINTS       = 256;

 { Limites des erreurs et resultats de recherche }
 MAX_ERRORS            = 1024;
 MAX_FIND_RESULTS      = 4096;

 { Taille du tampon generique }
 BUFFER_SIZE           = 65536;

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

BEGIN
 InitOptions(Opts);
 ParseCommandLine(Opts);
 If Opts.Verbose Then
  ShowVersion;
 InitializeGraphics;
 ClearScreen(CLR_BACKGROUND);
 InitEventQueue;
 InitMouse;
 { Boucle principale a venir (TODO 04+) }
 ShutdownGraphics;
END.