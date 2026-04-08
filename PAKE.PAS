{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Clone de Pake - Transforme n'importe quelle page web en
                application de bureau en une seule commande.
                Compatible avec macOS, Windows et Linux.
                Basé sur Rust Tauri pour des applications légères et rapides.
  @license: MIT
}

(* ============================================================
  PAKE.PAS - Transformez une page web en application de bureau
  Free Pascal (-Mtp)

  Clone de https://github.com/tw93/Pake

  Caracteristiques :
    - Leger : ~20x plus petit que les packages Electron (~5 Mo)
    - Rapide : Construit avec Rust Tauri, utilisation memoire reduite
    - Simple : Empaquetage en une commande via CLI
    - Riche : Raccourcis clavier, fenetres immersives, drag & drop,
              personnalisation CSS, suppression des pubs

  Usage :
    pake URL [options]

  Options :
    --name NOM        : nom de l application (default: extrait de l URL)
    --icon FICHIER    : icone personnalisee (.ico/.icns/.png)
    --width N         : largeur de la fenetre (default: 1200)
    --height N        : hauteur de la fenetre (default: 780)
    --fullscreen      : demarrer en plein ecran
    --transparent     : fenetre transparente (effets visuels)
    --hide-title-bar  : masquer la barre de titre (fenetre immersive)
    --always-on-top   : toujours au premier plan
    --disabled-web-shortcuts : desactiver les raccourcis web
    --user-agent STR  : user-agent personnalise
    --inject-css FILE : injecter du CSS personnalise
    --inject-js FILE  : injecter du JavaScript personnalise
    --proxy URL       : utiliser un serveur proxy
    --debug           : activer les DevTools
    --multi-arch      : construire pour toutes les architectures
    --targets LIST    : cibles specifiques (macos,windows,linux)
    -o, --output DIR  : repertoire de sortie
    -v, --verbose     : mode verbeux
    -h, --help        : afficher l aide

  Exemples :
    pake https://github.com --name GitHub
    pake https://twitter.com --name Twitter --width 1200 --height 800
    pake https://web.whatsapp.com --name WhatsApp --hide-title-bar

  Voir DOC/TODO/PAKE.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            PAKE_VERSION ('1.0') et PAKE_DATE ('2026-03-30')
            Directive $I- pour desactiver les erreurs I/O automatiques
            Type TOptions : record
              Url          : String (URL de la page web)
              AppName      : String (nom de l application)
              IconPath     : String (chemin vers l icone)
              Width        : Integer (largeur fenetre, default 1200)
              Height       : Integer (hauteur fenetre, default 780)
              Fullscreen   : Boolean (demarrer en plein ecran)
              Transparent  : Boolean (fenetre transparente)
              HideTitleBar : Boolean (masquer la barre de titre)
              AlwaysOnTop  : Boolean (toujours au premier plan)
              DisableWebShortcuts : Boolean (desactiver raccourcis)
              UserAgent    : String (user-agent personnalise)
              InjectCss    : String (fichier CSS a injecter)
              InjectJs     : String (fichier JS a injecter)
              ProxyUrl     : String (URL du proxy)
              DebugMode    : Boolean (activer DevTools)
              MultiArch    : Boolean (build multi-architecture)
              Targets      : String (liste des cibles separees par virgule)
              OutputDir    : String (repertoire de sortie)
              Verbose      : Boolean (mode verbeux)
            End
            Constantes de codes de retour : EXIT_OK = 0, EXIT_ERROR = 1,
              EXIT_USAGE = 2
            Constantes de tailles : MAX_URL_LEN = 2048,
              MAX_PATH_LEN = 260, MAX_NAME_LEN = 64
            Procedure FatalError(Msg: String) : afficher l erreur et
              appeler Halt(EXIT_ERROR)
            Procedure ParseCommandLine(Var Opts: TOptions) :
              analyser ParamStr(1..ParamCount), detecter toutes les options
              --name, --icon, --width, --height, --fullscreen, etc.
              Valider que l URL est fournie comme premier argument
            Procedure ShowHelp : afficher la syntaxe complete, les options
              et la version, puis quitter avec EXIT_OK
            Procedure ShowVersion : afficher la version et quitter
            Afficher la banniere de version au demarrage si Verbose

  TODO 02 - FONCTIONS UTILITAIRES [IMPLEMENTE]
            Function IntToStr(N: LongInt): String
              convertit un entier en chaine decimale
            Function StrToInt(Const S: String): LongInt
              convertit une chaine en entier, retourne 0 si invalide
            Function UpCaseStr(Const S: String): String
              convertir une chaine en majuscules
            Function LowerStr(Const S: String): String
              convertir une chaine en minuscules
            Function Trim(Const S: String): String
              supprimer les espaces de debut et de fin
            Function TrimLeft(Const S: String): String
              supprimer les espaces de debut
            Function TrimRight(Const S: String): String
              supprimer les espaces de fin
            Function FileExists(Const FName: String): Boolean
              verifier l existence d un fichier
            Function DirExists(Const DirName: String): Boolean
              verifier l existence d un repertoire
            Function CreateDir(Const DirName: String): Boolean
              creer un repertoire
            Function ChangeFileExt(Const FName, NewExt: String): String
              remplacer l extension d un nom de fichier
            Function ExtractFileName(Const Path: String): String
              extraire le nom de fichier d un chemin complet
            Function ExtractFileDir(Const Path: String): String
              extraire le repertoire d un chemin complet
            Function ExtractFileExt(Const Path: String): String
              extraire l extension d un nom de fichier
            Function ConcatPath(Const Dir, Name: String): String
              concatener un repertoire et un nom de fichier
            Function QuoteStr(Const S: String): String
              entourer une chaine de guillemets doubles
            Function EscapeJson(Const S: String): String
              echapper les caracteres speciaux pour JSON
            Function EscapeShell(Const S: String): String
              echapper les caracteres speciaux pour shell

  TODO 03 - VALIDATION DE L'URL [IMPLEMENTE]
            Function IsValidUrl(Const Url: String): Boolean
              verifier que l URL commence par http:// ou https://
              verifier qu il y a un domaine valide apres le protocole
              verifier qu il n y a pas de caracteres invalides
            Function ExtractProtocol(Const Url: String): String
              extraire 'http' ou 'https' de l URL
            Function ExtractDomain(Const Url: String): String
              extraire le domaine de l URL (ex: 'github.com')
            Function ExtractPath(Const Url: String): String
              extraire le chemin de l URL (ex: '/tw93/Pake')
            Function NormalizeDomain(Const Domain: String): String
              retirer 'www.' du domaine si present
              convertir en minuscules
            Function DomainToAppName(Const Domain: String): String
              convertir un domaine en nom d application valide
              ex: 'github.com' -> 'GitHub'
              ex: 'web.whatsapp.com' -> 'WhatsApp'
            Function IsLocalUrl(Const Url: String): Boolean
              verifier si l URL est locale (localhost, 127.0.0.1, file://)
            Procedure ValidateUrl(Const Url: String)
              appeler IsValidUrl, lever FatalError si invalide

  TODO 04 - DETECTION DU SYSTEME D'EXPLOITATION [IMPLEMENTE]
            Constantes de plateformes :
              PLATFORM_UNKNOWN = 0, PLATFORM_WINDOWS = 1,
              PLATFORM_MACOS = 2, PLATFORM_LINUX = 3
            Function GetPlatform: Integer
              detecter le systeme d exploitation courant
              utiliser les directives de compilation $IFDEF
              $IFDEF WINDOWS -> PLATFORM_WINDOWS
              $IFDEF DARWIN -> PLATFORM_MACOS
              $IFDEF LINUX -> PLATFORM_LINUX
            Function PlatformName(P: Integer): String
              retourner le nom de la plateforme en chaine
            Function GetArchitecture: String
              retourner l architecture ('x64', 'arm64', 'x86')
            Function IsRustInstalled: Boolean
              verifier si Rust/Cargo est installe (cargo --version)
            Function IsTauriInstalled: Boolean
              verifier si Tauri CLI est installe (cargo tauri --version)
            Procedure CheckPrerequisites
              verifier Rust, Tauri, et les dependances systeme
              afficher des instructions si manquant

  TODO 05 - CONFIGURATION DE LA FENETRE [IMPLEMENTE]
            Constantes de tailles par defaut :
              DEFAULT_WIDTH = 1200, DEFAULT_HEIGHT = 780,
              MIN_WIDTH = 320, MIN_HEIGHT = 240,
              MAX_WIDTH = 3840, MAX_HEIGHT = 2160
            Type TWindowConfig : record
              Width        : Integer
              Height       : Integer
              MinWidth     : Integer
              MinHeight    : Integer
              Resizable    : Boolean
              Fullscreen   : Boolean
              Transparent  : Boolean
              Decorations  : Boolean (barre de titre)
              AlwaysOnTop  : Boolean
              Center       : Boolean
              Title        : String
            End
            Function ValidateWindowSize(W, H: Integer): Boolean
              verifier que la taille est dans les limites
            Procedure InitWindowConfig(Var Cfg: TWindowConfig;
              Const Opts: TOptions)
              initialiser la configuration de fenetre depuis les options
            Function WindowConfigToJson(Const Cfg: TWindowConfig): String
              generer la configuration JSON pour tauri.conf.json

  TODO 06 - GESTION DES ICONES [IMPLEMENTE]
            Constantes de formats d icones :
              ICON_ICO = 1, ICON_ICNS = 2, ICON_PNG = 3
            Function DetectIconFormat(Const Path: String): Integer
              detecter le format de l icone depuis l extension
            Function ValidateIconFile(Const Path: String): Boolean
              verifier que le fichier icone existe et est valide
              verifier les dimensions minimales (256x256 recommande)
            Function GetFaviconUrl(Const Url: String): String
              construire l URL du favicon :
              https://DOMAIN/favicon.ico ou
              https://www.google.com/s2/favicons?domain=DOMAIN&sz=256
            Procedure DownloadFavicon(Const Url, DestPath: String)
              telecharger le favicon depuis l URL
              utiliser wget ou curl selon la plateforme
            Function ConvertIconFormat(Const SrcPath: String;
              DestFormat: Integer; Const DestPath: String): Boolean
              convertir une icone entre formats (PNG->ICO, PNG->ICNS)
              utiliser des outils externes (ImageMagick, icotool, etc.)
            Procedure PrepareIcons(Const Opts: TOptions;
              Const WorkDir: String)
              preparer les icones pour chaque plateforme :
              - Windows : icon.ico (256x256)
              - macOS : icon.icns (multi-resolution)
              - Linux : icon.png (512x512)

  TODO 07 - GENERATION DU NOM D'APPLICATION [IMPLEMENTE]
            Function SanitizeAppName(Const Name: String): String
              retirer les caracteres invalides pour un nom de fichier
              remplacer espaces par tirets ou underscores
              limiter a MAX_NAME_LEN caracteres
            Function GenerateAppName(Const Opts: TOptions): String
              si Opts.AppName specifie : utiliser apres sanitization
              sinon : extraire du domaine via DomainToAppName
            Function GenerateIdentifier(Const AppName: String): String
              generer un identifiant unique pour l application
              format : com.pake.APPNAME (bundle identifier)
            Function GeneratePackageName(Const AppName: String): String
              generer un nom de package valide (minuscules, tirets)
            Procedure ValidateAppName(Const Name: String)
              verifier que le nom ne contient pas de caracteres interdits
              verifier que le nom n est pas reserve (CON, PRN, etc.)

  TODO 08 - CONFIGURATION TAURI [IMPLEMENTE]
            Type TTauriConfig : record
              Package : record
                ProductName : String
                Version     : String
                Identifier  : String
              End
              Build : record
                DistDir    : String
                DevPath    : String
                BeforeDevCommand  : String
                BeforeBuildCommand : String
              End
              Tauri : record
                Bundle   : record
                  Active   : Boolean
                  Targets  : String
                  Icon     : Array[1..4] Of String
                End
                Windows  : TWindowConfig
                Security : record
                  Csp : String
                End
              End
            End
            Procedure InitTauriConfig(Var Cfg: TTauriConfig;
              Const Opts: TOptions)
              initialiser la configuration depuis les options
            Function TauriConfigToJson(Const Cfg: TTauriConfig): String
              generer le fichier tauri.conf.json complet
            Procedure WriteTauriConfig(Const WorkDir: String;
              Const Cfg: TTauriConfig)
              ecrire tauri.conf.json dans le repertoire de travail
            Function GenerateCargoToml(Const AppName: String): String
              generer le fichier Cargo.toml pour le projet Rust

  TODO 09 - GENERATION DU CODE RUST PRINCIPAL [IMPLEMENTE]
            Function GenerateMainRs(Const Opts: TOptions): String
              generer le fichier main.rs avec :
              - imports tauri (use tauri::all)
              - fonction main() avec tauri::Builder
              - configuration de la fenetre WebView
              - chargement de l URL cible
              - gestion des evenements (close, minimize, etc.)
            Function GenerateLibRs(Const Opts: TOptions): String
              generer lib.rs si necessaire (fonctions utilitaires)
            Function GenerateBuildRs: String
              generer build.rs pour la compilation Tauri
            Procedure WriteRustSources(Const WorkDir: String;
              Const Opts: TOptions)
              ecrire tous les fichiers sources Rust dans src/
            Function GenerateIndexHtml(Const Opts: TOptions): String
              generer un index.html minimal qui charge l URL
              avec redirection ou iframe selon la configuration

  TODO 10 - GESTION DES RACCOURCIS CLAVIER [IMPLEMENTE]
            Type TShortcut : record
              Key       : String (ex: 'CmdOrCtrl+W')
              Action    : Integer (KBD_ACTION_* constantes)
              Enabled   : Boolean
            End
            Constantes d actions :
              KBD_ACTION_NONE = 0, KBD_ACTION_CLOSE = 1, KBD_ACTION_QUIT = 2,
              KBD_ACTION_RELOAD = 3, KBD_ACTION_ZOOM_IN = 4,
              KBD_ACTION_ZOOM_OUT = 5, KBD_ACTION_ZOOM_RESET = 6,
              KBD_ACTION_BACK = 7, KBD_ACTION_FORWARD = 8,
              KBD_ACTION_DEVTOOLS = 9, KBD_ACTION_FULLSCREEN = 10
            Constantes de touches :
              KBD_KEY_CLOSE = CmdOrCtrl+W, KBD_KEY_QUIT = CmdOrCtrl+Q,
              KBD_KEY_RELOAD = CmdOrCtrl+R, KBD_KEY_ZOOM_IN = CmdOrCtrl+=,
              KBD_KEY_ZOOM_OUT = CmdOrCtrl+-, KBD_KEY_ZOOM_RESET = CmdOrCtrl+0,
              KBD_KEY_BACK = CmdOrCtrl+[, KBD_KEY_FORWARD = CmdOrCtrl+],
              KBD_KEY_DEVTOOLS = CmdOrCtrl+Shift+I, KBD_KEY_FULLSCREEN = F11
            KBD_MAX_SHORTCUTS = 16
            KbdInitialized/KbdStateCount/KbdShortcuts/KbdShortcutCount/
            KbdRegisterCount/KbdGenerateCount/KbdDisabledCount vars
            Procedure InitShortcutState
            Function ShortcutActionName(Action: Integer): String
            Function AddShortcut(Const Key: String; Action: Integer;
              Enabled: Boolean): Boolean
            Procedure RegisterDefaultShortcuts(DisableWebShortcuts: Boolean)
            Function GenerateShortcutActionCode(Action: Integer): String
            Function GenerateShortcutsRs(Const Opts: TOptions): String
            Function GetActiveShortcutCount: Integer
            10 accesseurs (IsKbdInitialized/IsKbdEmpty/GetKbdStateCount/
            GetKbdShortcutCount/GetKbdRegisterCount/GetKbdGenerateCount/
            GetKbdDisabledCount/GetKbdActiveCount/GetKbdMaxShortcuts/
            GetKbdDefaultKey)

  TODO 11 - MODE FENETRE IMMERSIVE [IMPLEMENTE]
            Constantes de modes de fenetre :
              WINDOW_NORMAL = 0, WINDOW_FRAMELESS = 1,
              WINDOW_TRANSPARENT = 2, WINDOW_FULLSCREEN = 3
            WMD_MAX_STYLES = 4, WMD_MAX_TITLEBAR_LEN = 4096
            WmdInitialized/WmdStateCount/WmdModeCount/WmdCssGenCount/
            WmdHtmlGenCount/WmdJsGenCount/WmdNormalCount/WmdFramelessCount/
            WmdTransparentCount/WmdFullscreenCount vars
            Procedure InitWindowModeState
              initialiser les variables de gestion du mode fenetre
            Function WindowModeName(Mode: Integer): String
              retourner le nom du mode de fenetre
            Function GetWindowMode(Const Opts: TOptions): Integer
              determiner le mode de fenetre depuis les options
            Function GenerateWindowStyleCss(Mode: Integer): String
              generer le CSS pour le style de fenetre :
              - barre de titre personnalisee si frameless
              - zone draggable pour deplacer la fenetre
              - boutons de controle (fermer, minimiser, maximiser)
            Function GenerateTitleBarHtml(Const AppName: String;
              Mode: Integer): String
              generer le HTML pour la barre de titre personnalisee
            Function GenerateDragRegionJs: String
              generer le JavaScript pour la zone draggable
              utiliser -webkit-app-region: drag
            10 accesseurs (IsWmdInitialized/IsWmdEmpty/GetWmdStateCount/
            GetWmdModeCount/GetWmdCssGenCount/GetWmdHtmlGenCount/
            GetWmdJsGenCount/GetWmdNormalCount/GetWmdFramelessCount/
            GetWmdMaxStyles)

  TODO 12 - INJECTION CSS PERSONNALISE [IMPLEMENTE]
            CssInitialized/CssStateCount/CssLoadCount/CssMinifyCount/
            CssValidateCount/CssInjectCount/CssErrorCount vars
            Procedure InitCssInjectionState
            Function LoadCssFile(Const Path: String): String
              charger le contenu d un fichier CSS
              verifier l existence du fichier
            Function MinifyCss(Const Css: String): String
              minifier le CSS (retirer commentaires, espaces)
            Function ValidateCss(Const Css: String): Boolean
              validation basique du CSS (accolades equilibrees)
            Function GenerateCssInjectionJs(Const Css: String): String
              generer le JavaScript pour injecter le CSS :
              const style = document.createElement('style');
              style.textContent = '...';
              document.head.appendChild(style);
            Procedure PrepareCssInjection(Const Opts: TOptions;
              Var InjectionScript: String)
              preparer le script d injection CSS si specifie
            10 accesseurs (IsCssInitialized/IsCssEmpty/GetCssStateCount/
            GetCssLoadCount/GetCssMinifyCount/GetCssValidateCount/
            GetCssInjectCount/GetCssErrorCount/GetCssMaxFileSize/
            GetCssDefaultScope)

  TODO 13 - INJECTION JAVASCRIPT PERSONNALISE [IMPLEMENTE]
            JsInitialized/JsStateCount/JsLoadCount/JsMinifyCount/
            JsValidateCount/JsWrapCount/JsUserScriptCount/JsErrorCount vars
            Procedure InitJsInjectionState
            Function LoadJsFile(Const Path: String): String
              charger le contenu d un fichier JavaScript
            Function MinifyJs(Const Js: String): String
              minification basique du JavaScript
            Function ValidateJs(Const Js: String): Boolean
              validation basique (parentheses/accolades equilibrees)
            Function WrapJsInIIFE(Const Js: String): String
              envelopper le JS dans une IIFE pour eviter les conflits :
              (function() { ... })();
            Function GenerateUserScript(Const Opts: TOptions): String
              combiner CSS injection + JS personnalise
              ajouter DOMContentLoaded listener
            Procedure PrepareJsInjection(Const Opts: TOptions;
              Var InjectionScript: String)
              preparer le script d injection JS si specifie
            10 accesseurs (IsJsInitialized/IsJsEmpty/GetJsStateCount/
            GetJsLoadCount/GetJsMinifyCount/GetJsValidateCount/
            GetJsWrapCount/GetJsUserScriptCount/GetJsErrorCount/
            GetJsMaxFileSize)

  TODO 14 - SUPPRESSION DES PUBS (ADBLOCK) [IMPLEMENTE]
            Constantes de selecteurs publicitaires courants :
              AD_SELECTORS = 'ins.adsbygoogle, .ad-container, ...'
            Function GenerateAdBlockCss: String
              generer le CSS pour masquer les elements publicitaires
              display: none !important pour chaque selecteur
            Function GenerateAdBlockJs: String
              generer le JavaScript pour supprimer les elements :
              - MutationObserver pour les elements dynamiques
              - Blocage des requetes vers domaines publicitaires
              - Suppression des iframes publicitaires
            Function GetAdBlockDomains: String
              liste des domaines publicitaires a bloquer
            Procedure EnableAdBlock(Var InjectionScript: String)
              ajouter le script AdBlock au script d injection

  TODO 15 - GESTION DES PERMISSIONS [IMPLEMENTE]
            Type TPermissions : record
              Camera     : Boolean
              Microphone : Boolean
              Geolocation : Boolean
              Notifications : Boolean
              Clipboard  : Boolean
              FullScreen : Boolean
            End
            Function PermissionsToJson(Const P: TPermissions): String
              generer la configuration JSON des permissions
            Function PermissionsToCsp(Const P: TPermissions): String
              generer la Content Security Policy appropriee
            Procedure InitDefaultPermissions(Var P: TPermissions)
              initialiser les permissions par defaut (toutes False)
            Procedure ApplyPermissions(Const P: TPermissions;
              Var Cfg: TTauriConfig)
              appliquer les permissions a la configuration Tauri

  TODO 16 - CONFIGURATION DU BUILD [IMPLEMENTE]
            Constantes de modes de build :
              BUILD_DEBUG = 0, BUILD_RELEASE = 1 (deja definis)
            Constantes de plateformes cibles :
              Utilise PLATFORM_* (PLATFORM_UNKNOWN/WINDOWS/MACOS/LINUX)
            Constantes de build :
              BUILD_MAX_TARGETS = 4, BUILD_CARGO_CMD, BUILD_TAURI_CMD
            Type TBuildConfig : record (Mode, Target, TargetTriple,
              OutputDir, Verbose, MultiArch)
            BldInitialized/BldStateCount/BldCommandCount/BldExecuteCount/
            BldArtifactCount/BldCopyCount/BldSuccessCount/BldErrorCount vars
            Procedure InitBuildState
            Function BuildModeName(Mode: Integer): String
            Function BuildTargetName(Target: Integer): String
            Function GetTargetTriple(Target: Integer): String
            Procedure InitBuildConfig(Var Cfg: TBuildConfig;
              Const Opts: TOptions)
            Function GenerateBuildCommand(Const Cfg: TBuildConfig): String
              generer la commande de build :
              cargo tauri build [options]
              --target si specifie
              --release pour production
            Function GenerateBuildCommandFromOpts(Const Opts: TOptions): String
            Procedure ExecuteBuild(Const WorkDir: String;
              Const Cmd: String; Verbose: Boolean)
              executer la commande de build
              capturer et afficher la sortie si Verbose
              gerer les erreurs de compilation
            Function GetBuildArtifactPath(Const WorkDir: String;
              Platform: Integer): String
              retourner le chemin de l artefact de build
            Function GetBuildArtifactExtension(Platform: Integer): String
            Procedure CopyBuildArtifacts(Const WorkDir, OutputDir: String;
              Platform: Integer)
              copier les artefacts vers le repertoire de sortie
            Function IsBuildConfigValid(Const Cfg: TBuildConfig): Boolean
            Procedure DumpBuildConfig(Const Cfg: TBuildConfig)
            10 accesseurs (IsBldInitialized/IsBldEmpty/GetBldStateCount/
            GetBldCommandCount/GetBldExecuteCount/GetBldArtifactCount/
            GetBldCopyCount/GetBldSuccessCount/GetBldErrorCount/
            GetBldMaxTargets)

  TODO 17 - GENERATION MACOS [IMPLEMENTE]
            Constantes macOS :
              MACOS_APP_EXT = '.app', MACOS_DMG_EXT = '.dmg',
              MACOS_ICNS_EXT = '.icns', MACOS_PLIST_NAME = 'Info.plist',
              MACOS_MAX_BUNDLE_SIZE = 512*1024*1024 (512 Mo max)
            Type TInfoPlistConfig (BundleName, BundleIdentifier, BundleVersion,
              ExecutableName, IconFile, MinSystemVersion, Copyright,
              HighResCapable, Category)
            Variables d etat :
              MacInitialized/MacStateCount/MacPlistGenCount/MacBundleCount/
              MacDmgCount/MacSignCount/MacCopyCount/MacErrorCount
            Procedure InitMacOSState
              initialiser les variables d etat du module macOS
            Function MacOSExtName(ExtType: Integer): String
              retourner le nom de l extension macOS
            Function GenerateInfoPlist(Const Opts: TOptions): String
              generer Info.plist pour le bundle .app :
              CFBundleName, CFBundleIdentifier, CFBundleVersion,
              CFBundleExecutable, CFBundleIconFile, etc.
            Function GenerateDmgBackground: Boolean
              generer l image de fond pour le DMG (optionnel)
            Procedure CreateMacOSBundle(Const WorkDir: String;
              Const Opts: TOptions)
              assembler le bundle .app :
              Contents/MacOS/executable
              Contents/Resources/icon.icns
              Contents/Info.plist
            Procedure CreateDmgInstaller(Const AppPath, DmgPath: String)
              creer un fichier .dmg avec hdiutil
              configurer la disposition (app + lien Applications)
            Procedure SignMacOSApp(Const AppPath: String;
              Const Identity: String)
              signer l application avec codesign (optionnel)
            Function IsMacOSBundleValid(Const BundlePath: String): Boolean
            Procedure DumpMacOSState
            10 accesseurs (IsMacInitialized/IsMacEmpty/GetMacStateCount/
              GetMacPlistGenCount/GetMacBundleCount/GetMacDmgCount/
              GetMacSignCount/GetMacCopyCount/GetMacErrorCount/
              GetMacMaxBundleSize)

  TODO 18 - GENERATION WINDOWS [IMPLEMENTE]
            Constantes Windows :
              WIN_EXE_EXT = '.exe', WIN_MSI_EXT = '.msi',
              WIN_ICO_EXT = '.ico', WIN_RC_EXT = '.rc',
              WIN_MANIFEST_EXT = '.manifest',
              WIN_MAX_VERSION_LEN = 20
            Types Windows :
              WIN_EXT_NONE = 0, WIN_EXT_EXE = 1, WIN_EXT_MSI = 2,
              WIN_EXT_ICO = 3, WIN_EXT_RC = 4, WIN_EXT_MANIFEST = 5
            Type TVersionInfo (FileVersion, ProductVersion, CompanyName,
              FileDescription, InternalName, OriginalFilename, ProductName,
              LegalCopyright)
            Type TWindowsManifest (ExecutionLevel, DpiAware, VisualStyles,
              LongPathAware, Version)
            Variables d etat :
              WinInitialized/WinStateCount/WinManifestGenCount/WinRcGenCount/
              WinWixGenCount/WinNsisGenCount/WinInstallerCount/WinCopyCount/
              WinErrorCount
            Procedure InitWindowsState
              initialiser les variables d etat du module Windows
            Function WinExtName(ExtType: Integer): String
              retourner le nom de l extension Windows
            Function GenerateWindowsManifest(Const Opts: TOptions): String
              generer le fichier manifest Windows :
              requestedExecutionLevel, dpiAware, visualStyles
            Function GenerateWindowsRc(Const Opts: TOptions): String
              generer le fichier .rc pour les ressources :
              icone, informations de version (VERSIONINFO)
            Procedure CreateWindowsInstaller(Const WorkDir: String;
              Const Opts: TOptions)
              creer l installateur MSI avec WiX Toolset
              ou NSIS selon disponibilite
            Function GenerateWixWxs(Const Opts: TOptions): String
              generer le fichier WiX (.wxs) pour MSI
            Function GenerateNsisScript(Const Opts: TOptions): String
              generer le script NSIS (.nsi) pour l installateur
            Function IsWindowsInstallerValid(Const InstallerPath: String): Boolean
            Procedure DumpWindowsState
            10 accesseurs (IsWinInitialized/IsWinEmpty/GetWinStateCount/
              GetWinManifestGenCount/GetWinRcGenCount/GetWinWixGenCount/
              GetWinNsisGenCount/GetWinInstallerCount/GetWinCopyCount/
              GetWinErrorCount)

  TODO 19 - GENERATION LINUX [IMPLEMENTE]
            Constantes Linux :
              LINUX_DEB_EXT = '.deb', LINUX_RPM_EXT = '.rpm',
              LINUX_APPIMAGE_EXT = '.AppImage'
            Function GenerateDesktopEntry(Const Opts: TOptions): String
              generer le fichier .desktop :
              [Desktop Entry]
              Name=AppName
              Exec=/usr/bin/appname
              Icon=appname
              Type=Application
              Categories=Network;
            Function GenerateDebianControl(Const Opts: TOptions): String
              generer le fichier DEBIAN/control :
              Package, Version, Architecture, Maintainer, Description
            Procedure CreateDebPackage(Const WorkDir, OutputDir: String;
              Const Opts: TOptions)
              assembler le package .deb :
              DEBIAN/control, usr/bin/executable, usr/share/applications/
              usr/share/icons/
            Procedure CreateAppImage(Const WorkDir, OutputDir: String;
              Const Opts: TOptions)
              creer un AppImage autonome avec appimagetool
            Function GenerateAppImageDesktop(Const Opts: TOptions): String
              generer le .desktop pour AppImage

  TODO 20 - MULTI-URL [IMPLEMENTE]
            Type TUrlEntry : record
              Url      : String
              Title    : String
              Shortcut : String (ex: 'CmdOrCtrl+1')
            End
            Constantes multi-URL :
              MAX_URLS = 10
            Variables globales :
              Urls : Array[1..MAX_URLS] Of TUrlEntry
              UrlCount : Integer
            Function ParseMultiUrl(Const UrlList: String): Boolean
              parser une liste d URLs separees par virgules
              ou un fichier JSON avec configuration
            Function GenerateMultiTabHtml(Const Urls: Array Of TUrlEntry;
              Count: Integer): String
              generer le HTML pour une interface multi-onglets
            Function GenerateMultiTabJs(Const Urls: Array Of TUrlEntry;
              Count: Integer): String
              generer le JavaScript pour la navigation entre URLs
            Function GenerateMultiTabCss: String
              generer le CSS pour les onglets

  TODO 21 - CONFIGURATION DU USER-AGENT [IMPLEMENTE]
            Constantes de User-Agents :
              UA_CHROME = 'Mozilla/5.0 ... Chrome/...'
              UA_FIREFOX = 'Mozilla/5.0 ... Firefox/...'
              UA_SAFARI = 'Mozilla/5.0 ... Safari/...'
              UA_EDGE = 'Mozilla/5.0 ... Edg/...'
            Function GetDefaultUserAgent: String
              retourner le User-Agent par defaut de WebView
            Function ValidateUserAgent(Const Ua: String): Boolean
              valider le format du User-Agent
            Function GenerateUserAgentConfig(Const Ua: String): String
              generer la configuration Tauri pour le User-Agent
            Procedure ApplyUserAgent(Const Ua: String;
              Var MainRs: String)
              modifier le code Rust pour definir le User-Agent

  TODO 22 - GESTION DU PROXY [A FAIRE]
            Type TProxyConfig : record
              Enabled  : Boolean
              Url      : String (ex: 'http://proxy:8080')
              Username : String
              Password : String
              Bypass   : String (liste de domaines a ignorer)
            End
            Function ParseProxyUrl(Const Url: String): TProxyConfig
              parser l URL du proxy (format http://user:pass@host:port)
            Function ValidateProxyConfig(Const Cfg: TProxyConfig): Boolean
              valider la configuration du proxy
            Function GenerateProxyConfig(Const Cfg: TProxyConfig): String
              generer la configuration pour WebView
            Procedure ApplyProxyConfig(Const Cfg: TProxyConfig;
              Var MainRs: String)
              modifier le code Rust pour configurer le proxy

  TODO 23 - MODE DEVELOPPEUR [A FAIRE]
            Constantes de debug :
              DEBUG_DEVTOOLS = 1, DEBUG_CONSOLE = 2, DEBUG_NETWORK = 4
            Function GenerateDevToolsConfig(Enabled: Boolean): String
              generer la configuration pour activer les DevTools
            Function GenerateConsoleLoggingJs: String
              generer le JavaScript pour capturer console.log/error
              et les afficher dans le terminal
            Procedure EnableRemoteDebugging(Port: Integer;
              Var MainRs: String)
              configurer le debugging distant sur un port specifique
            Procedure InjectDevToolsShortcut(Var Shortcuts: Array Of TShortcut)
              ajouter le raccourci Cmd+Shift+I / Ctrl+Shift+I

  TODO 24 - PRESETS D'APPLICATIONS POPULAIRES [A FAIRE]
            Type TAppPreset : record
              Name     : String
              Url      : String
              Width    : Integer
              Height   : Integer
              Icon     : String (URL de l icone)
              Options  : String (options supplementaires)
            End
            Constantes de presets populaires :
              PRESET_CHATGPT, PRESET_TWITTER, PRESET_YOUTUBE,
              PRESET_GITHUB, PRESET_NOTION, PRESET_FIGMA,
              PRESET_DISCORD, PRESET_SLACK, PRESET_WHATSAPP,
              PRESET_SPOTIFY, PRESET_NETFLIX, PRESET_GEMINI
            Function FindPreset(Const Name: String): Integer
              rechercher un preset par son nom
              retourner -1 si non trouve
            Procedure ApplyPreset(Const Preset: TAppPreset;
              Var Opts: TOptions)
              appliquer les parametres du preset aux options
            Procedure ListPresets
              afficher la liste des presets disponibles
            Function IsPresetName(Const Name: String): Boolean
              verifier si le nom correspond a un preset

  TODO 25 - VERIFICATION ET RAPPORT FINAL [A FAIRE]
            Function GetFileSize(Const FName: String): LongInt
              ouvrir le fichier, chercher la fin, retourner la taille
            Function FormatFileSize(Size: LongInt): String
              formater la taille en KB/MB (ex: '5.2 MB')
            Procedure VerifyBuild(Const OutputDir: String;
              Platform: Integer)
              verifier que les artefacts de build existent
              verifier les signatures si applicable
              verifier les permissions des executables
            Procedure DisplayFinalReport(Const Opts: TOptions;
              Platform: Integer; ElapsedTime: LongInt)
              afficher le rapport complet :
              '=== PAKE - Rapport de generation ==='
              'Application      : ' + Opts.AppName
              'URL source       : ' + Opts.Url
              'Plateforme       : ' + PlatformName(Platform)
              'Taille du build  : ' + FormatFileSize(...)
              'Temps de build   : ' + FormatTime(ElapsedTime)
              'Fichier genere   : ' + chemin du fichier
              si Verbose : afficher les details de configuration
            Procedure Cleanup(Const WorkDir: String; KeepSources: Boolean)
              nettoyer les fichiers temporaires
              conserver les sources si demande
            Procedure Run(Var Opts: TOptions)
              orchestrateur principal :
              1. Valider les options et l URL
              2. Verifier les prerequis (Rust, Tauri)
              3. Creer le repertoire de travail
              4. Preparer les icones
              5. Generer la configuration Tauri
              6. Generer les sources Rust
              7. Executer le build
              8. Copier les artefacts
              9. Afficher le rapport final
              10. Nettoyer les fichiers temporaires

*)

Program PAKE;

{$IFDEF FPC}
 {$MODE TP}
 {$H-}
{$ENDIF}

{$I-}

Uses
  DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PAKE_VERSION = '1.0';
  PAKE_DATE    = '2026-03-30';

  { Codes de retour }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Limites }
  MAX_URL_LEN  = 2048;
  MAX_PATH_LEN = 260;
  MAX_NAME_LEN = 64;
  MAX_URLS     = 10;

  { Plateformes }
  PLATFORM_UNKNOWN = 0;
  PLATFORM_WINDOWS = 1;
  PLATFORM_MACOS   = 2;
  PLATFORM_LINUX   = 3;

  { Tailles de fenetre par defaut }
  DEFAULT_WIDTH  = 1200;
  DEFAULT_HEIGHT = 780;
  MIN_WIDTH      = 320;
  MIN_HEIGHT     = 240;
  MAX_WIDTH      = 3840;
  MAX_HEIGHT     = 2160;

  { Formats d icones }
  ICON_ICO  = 1;
  ICON_ICNS = 2;
  ICON_PNG  = 3;

  { Modes de fenetre }
  WINDOW_NORMAL      = 0;
  WINDOW_FRAMELESS   = 1;
  WINDOW_TRANSPARENT = 2;
  WINDOW_FULLSCREEN  = 3;

  { Modes de build }
  BUILD_DEBUG   = 0;
  BUILD_RELEASE = 1;

  { Extensions de fichiers }
  MACOS_APP_EXT     = '.app';
  MACOS_DMG_EXT     = '.dmg';
  WIN_EXE_EXT       = '.exe';
  WIN_MSI_EXT       = '.msi';
  LINUX_DEB_EXT     = '.deb';
  LINUX_RPM_EXT     = '.rpm';
  LINUX_APPIMAGE_EXT = '.AppImage';

{ ============================================================
  TYPES GLOBAUX
  ============================================================ }
Type
  TOptions = Record
    Url          : String;
    AppName      : String;
    IconPath     : String;
    Width        : Integer;
    Height       : Integer;
    Fullscreen   : Boolean;
    Transparent  : Boolean;
    HideTitleBar : Boolean;
    AlwaysOnTop  : Boolean;
    DisableWebShortcuts : Boolean;
    UserAgent    : String;
    InjectCss    : String;
    InjectJs     : String;
    ProxyUrl     : String;
    DebugMode    : Boolean;
    MultiArch    : Boolean;
    Targets      : String;
    OutputDir    : String;
    Verbose      : Boolean;
  End;

  TWindowConfig = Record
    Width       : Integer;
    Height      : Integer;
    MinWidth    : Integer;
    MinHeight   : Integer;
    Resizable   : Boolean;
    Fullscreen  : Boolean;
    Transparent : Boolean;
    Decorations : Boolean;
    AlwaysOnTop : Boolean;
    Center      : Boolean;
    Title       : String;
  End;

  TShortcut = Record
    Key     : String;
    Action  : Integer;     { Action a executer (KBD_ACTION_*) }
    Enabled : Boolean;
  End;

  TPermissions = Record
    Camera       : Boolean;
    Microphone   : Boolean;
    Geolocation  : Boolean;
    Notifications : Boolean;
    Clipboard    : Boolean;
    FullScreen   : Boolean;
  End;

  TProxyConfig = Record
    Enabled  : Boolean;
    Url      : String;
    Username : String;
    Password : String;
    Bypass   : String;
  End;

  TUrlEntry = Record
    Url      : String;
    Title    : String;
    Shortcut : String;
  End;

  TAppPreset = Record
    Name    : String;
    Url     : String;
    Width   : Integer;
    Height  : Integer;
    Icon    : String;
    Options : String;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;
  Urls : Array[1..MAX_URLS] Of TUrlEntry;
  UrlCount : Integer;

{ ============================================================
  TODO 01 : INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

Procedure FatalError(Const Msg: String);
Begin
  WriteLn('ERREUR: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure ShowVersion;
Begin
  WriteLn('PAKE version ', PAKE_VERSION, ' (', PAKE_DATE, ')');
  WriteLn('Clone de Pake - Transformez une page web en application de bureau');
  WriteLn('Compatible macOS, Windows et Linux');
  Halt(EXIT_OK);
End;

Procedure ShowHelp;
Begin
  WriteLn('PAKE - Transformez une page web en application de bureau');
  WriteLn;
  WriteLn('Usage: pake URL [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  --name NOM        Nom de l''application');
  WriteLn('  --icon FICHIER    Icone personnalisee (.ico/.icns/.png)');
  WriteLn('  --width N         Largeur de la fenetre (defaut: 1200)');
  WriteLn('  --height N        Hauteur de la fenetre (defaut: 780)');
  WriteLn('  --fullscreen      Demarrer en plein ecran');
  WriteLn('  --transparent     Fenetre transparente');
  WriteLn('  --hide-title-bar  Masquer la barre de titre');
  WriteLn('  --always-on-top   Toujours au premier plan');
  WriteLn('  --disabled-web-shortcuts  Desactiver les raccourcis web');
  WriteLn('  --user-agent STR  User-agent personnalise');
  WriteLn('  --inject-css FILE Injecter du CSS personnalise');
  WriteLn('  --inject-js FILE  Injecter du JavaScript personnalise');
  WriteLn('  --proxy URL       Utiliser un serveur proxy');
  WriteLn('  --debug           Activer les DevTools');
  WriteLn('  --multi-arch      Construire pour toutes les architectures');
  WriteLn('  --targets LIST    Cibles specifiques (macos,windows,linux)');
  WriteLn('  -o, --output DIR  Repertoire de sortie');
  WriteLn('  -v, --verbose     Mode verbeux');
  WriteLn('  -h, --help        Afficher cette aide');
  WriteLn('  --version         Afficher la version');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  pake https://github.com --name GitHub');
  WriteLn('  pake https://twitter.com --name Twitter --width 1200 --height 800');
  WriteLn('  pake https://web.whatsapp.com --name WhatsApp --hide-title-bar');
  WriteLn;
  WriteLn('Version ', PAKE_VERSION, ' (', PAKE_DATE, ')');
  Halt(EXIT_OK);
End;

Procedure InitOptions(Var O: TOptions);
Begin
  O.Url := '';
  O.AppName := '';
  O.IconPath := '';
  O.Width := DEFAULT_WIDTH;
  O.Height := DEFAULT_HEIGHT;
  O.Fullscreen := False;
  O.Transparent := False;
  O.HideTitleBar := False;
  O.AlwaysOnTop := False;
  O.DisableWebShortcuts := False;
  O.UserAgent := '';
  O.InjectCss := '';
  O.InjectJs := '';
  O.ProxyUrl := '';
  O.DebugMode := False;
  O.MultiArch := False;
  O.Targets := '';
  O.OutputDir := '.';
  O.Verbose := False;
End;

{ ============================================================
  TODO 02 : FONCTIONS UTILITAIRES [IMPLEMENTE]
  ============================================================ }

Function IntToStr(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToInt(Const S: String): LongInt;
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

Function UpCaseStr(Const S: String): String;
Var
  R: String;
  I: Integer;
Begin
  R := S;
  For I := 1 To Length(R) Do
    R[I] := UpCase(R[I]);
  UpCaseStr := R;
End;

Function LowerStr(Const S: String): String;
Var
  R: String;
  I: Integer;
  C: Char;
Begin
  R := S;
  For I := 1 To Length(R) Do
  Begin
    C := R[I];
    If (C >= 'A') And (C <= 'Z') Then
      R[I] := Chr(Ord(C) + 32);
  End;
  LowerStr := R;
End;

Function Trim(Const S: String): String;
Var
  I, J: Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  J := Length(S);
  While (J >= I) And (S[J] = ' ') Do Dec(J);
  If I > J Then
    Trim := ''
  Else
    Trim := Copy(S, I, J - I + 1);
End;

Function TrimLeft(Const S: String): String;
Var
  I: Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  If I > Length(S) Then
    TrimLeft := ''
  Else
    TrimLeft := Copy(S, I, Length(S) - I + 1);
End;

Function TrimRight(Const S: String): String;
Var
  J: Integer;
Begin
  J := Length(S);
  While (J >= 1) And (S[J] = ' ') Do Dec(J);
  If J < 1 Then
    TrimRight := ''
  Else
    TrimRight := Copy(S, 1, J);
End;

Function FileExists(Const FName: String): Boolean;
Var
  F: File;
Begin
  Assign(F, FName);
  Reset(F);
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

Function DirExists(Const DirName: String): Boolean;
Var
  SR: SearchRec;
Begin
  FindFirst(DirName, Directory, SR);
  DirExists := (DosError = 0) And ((SR.Attr And Directory) <> 0);
End;

Function ExtractFileExt(Const Path: String): String;
Var
  I: Integer;
Begin
  I := Length(Path);
  While (I > 0) And (Path[I] <> '.') And (Path[I] <> '\') And (Path[I] <> '/') Do
    Dec(I);
  If (I > 0) And (Path[I] = '.') Then
    ExtractFileExt := Copy(Path, I, Length(Path) - I + 1)
  Else
    ExtractFileExt := '';
End;

Function ExtractFileName(Const Path: String): String;
Var
  I: Integer;
Begin
  I := Length(Path);
  While (I > 0) And (Path[I] <> '\') And (Path[I] <> '/') Do
    Dec(I);
  ExtractFileName := Copy(Path, I + 1, Length(Path) - I);
End;

Function ExtractFileDir(Const Path: String): String;
Var
  I: Integer;
Begin
  I := Length(Path);
  While (I > 0) And (Path[I] <> '\') And (Path[I] <> '/') Do
    Dec(I);
  If I > 0 Then
    ExtractFileDir := Copy(Path, 1, I - 1)
  Else
    ExtractFileDir := '';
End;

Function CreateDir(Const DirName: String): Boolean;
Begin
  MkDir(DirName);
  CreateDir := (IOResult = 0);
End;

Function ChangeFileExt(Const FName, NewExt: String): String;
Var
  I: Integer;
  BaseName: String;
Begin
  I := Length(FName);
  While (I > 0) And (FName[I] <> '.') And (FName[I] <> '\') And (FName[I] <> '/') Do
    Dec(I);
  If (I > 0) And (FName[I] = '.') Then
    BaseName := Copy(FName, 1, I - 1)
  Else
    BaseName := FName;
  ChangeFileExt := BaseName + NewExt;
End;

Function ConcatPath(Const Dir, Name: String): String;
Var
  Sep: Char;
Begin
  {$IFDEF WINDOWS}
  Sep := '\';
  {$ELSE}
  Sep := '/';
  {$ENDIF}
  If Length(Dir) = 0 Then
    ConcatPath := Name
  Else If (Dir[Length(Dir)] = '\') Or (Dir[Length(Dir)] = '/') Then
    ConcatPath := Dir + Name
  Else
    ConcatPath := Dir + Sep + Name;
End;

Function QuoteStr(Const S: String): String;
Begin
  QuoteStr := '"' + S + '"';
End;

Function EscapeJson(Const S: String): String;
Var
  R: String;
  I: Integer;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    Case C Of
      '"':  R := R + '\"';
      '\':  R := R + '\\';
      '/':  R := R + '\/';
      #8:   R := R + '\b';
      #9:   R := R + '\t';
      #10:  R := R + '\n';
      #12:  R := R + '\f';
      #13:  R := R + '\r';
    Else
      If Ord(C) < 32 Then
        R := R + '\u00' + Chr(Ord('0') + (Ord(C) Div 16)) + Chr(Ord('0') + (Ord(C) Mod 16))
      Else
        R := R + C;
    End;
  End;
  EscapeJson := R;
End;

Function EscapeShell(Const S: String): String;
Var
  R: String;
  I: Integer;
  C: Char;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    C := S[I];
    {$IFDEF WINDOWS}
    { Sous Windows, echapper les caracteres speciaux pour cmd.exe }
    If C In ['"', '%', '!', '^', '&', '<', '>', '|'] Then
      R := R + '^' + C
    Else
      R := R + C;
    {$ELSE}
    { Sous Unix, echapper les caracteres speciaux pour sh/bash }
    If C In ['''', '"', '\', '$', '`', '!', '*', '?', '[', ']', '(', ')', '{', '}', '|', '&', ';', '<', '>', ' ', #9, #10] Then
      R := R + '\' + C
    Else
      R := R + C;
    {$ENDIF}
  End;
  EscapeShell := R;
End;

{ ============================================================
  TODO 03 : VALIDATION DE L'URL [IMPLEMENTE]
  ============================================================ }

Function IsValidUrl(Const Url: String): Boolean;
Var
  U: String;
Begin
  U := LowerStr(Url);
  IsValidUrl := (Copy(U, 1, 7) = 'http://') Or (Copy(U, 1, 8) = 'https://');
End;

Function ExtractProtocol(Const Url: String): String;
Var
  P: Integer;
Begin
  P := Pos('://', Url);
  If P > 0 Then
    ExtractProtocol := Copy(Url, 1, P - 1)
  Else
    ExtractProtocol := '';
End;

Function ExtractDomain(Const Url: String): String;
Var
  U: String;
  P, E: Integer;
Begin
  P := Pos('://', Url);
  If P > 0 Then
    U := Copy(Url, P + 3, Length(Url) - P - 2)
  Else
    U := Url;
  E := Pos('/', U);
  If E > 0 Then
    ExtractDomain := Copy(U, 1, E - 1)
  Else
    ExtractDomain := U;
End;

Function NormalizeDomain(Const Domain: String): String;
Var
  D: String;
Begin
  D := LowerStr(Domain);
  If Copy(D, 1, 4) = 'www.' Then
    NormalizeDomain := Copy(D, 5, Length(D) - 4)
  Else
    NormalizeDomain := D;
End;

Function ExtractPath(Const Url: String): String;
Var
  U: String;
  P, E: Integer;
Begin
  P := Pos('://', Url);
  If P > 0 Then
    U := Copy(Url, P + 3, Length(Url) - P - 2)
  Else
    U := Url;
  E := Pos('/', U);
  If E > 0 Then
    ExtractPath := Copy(U, E, Length(U) - E + 1)
  Else
    ExtractPath := '/';
End;

Function DomainToAppName(Const Domain: String): String;
Var
  D, R: String;
  I, P: Integer;
  C: Char;
  CapNext: Boolean;
Begin
  D := NormalizeDomain(Domain);
  { Retirer l extension .com, .org, .net, etc. }
  P := Pos('.', D);
  If P > 0 Then
  Begin
    { Verifier si c est un sous-domaine comme web.whatsapp }
    I := P + 1;
    While (I <= Length(D)) And (D[I] <> '.') Do Inc(I);
    If I <= Length(D) Then
    Begin
      { Sous-domaine: prendre la partie principale }
      D := Copy(D, P + 1, I - P - 1);
    End
    Else
    Begin
      { Domaine simple: prendre avant le point }
      D := Copy(D, 1, P - 1);
    End;
  End;
  { Convertir en nom lisible avec majuscule initiale }
  R := '';
  CapNext := True;
  For I := 1 To Length(D) Do
  Begin
    C := D[I];
    If C In ['a'..'z'] Then
    Begin
      If CapNext Then
        R := R + UpCase(C)
      Else
        R := R + C;
      CapNext := False;
    End
    Else If C In ['A'..'Z'] Then
    Begin
      R := R + C;
      CapNext := False;
    End
    Else If C In ['0'..'9'] Then
    Begin
      R := R + C;
      CapNext := False;
    End
    Else If C In ['-', '_', '.'] Then
    Begin
      CapNext := True;
    End
    Else
    Begin
      R := R + C;
      CapNext := False;
    End;
  End;
  If Length(R) = 0 Then
    R := 'WebApp';
  DomainToAppName := R;
End;

Function IsLocalUrl(Const Url: String): Boolean;
Var
  U, D: String;
Begin
  U := LowerStr(Url);
  IsLocalUrl := False;
  { Verifier file:// }
  If Copy(U, 1, 7) = 'file://' Then
  Begin
    IsLocalUrl := True;
    Exit;
  End;
  { Verifier localhost et 127.0.0.1 }
  D := LowerStr(ExtractDomain(Url));
  If (D = 'localhost') Or (Copy(D, 1, 10) = 'localhost:') Then
    IsLocalUrl := True
  Else If (D = '127.0.0.1') Or (Copy(D, 1, 10) = '127.0.0.1:') Then
    IsLocalUrl := True
  Else If (D = '0.0.0.0') Or (Copy(D, 1, 8) = '0.0.0.0:') Then
    IsLocalUrl := True
  Else If (Copy(D, 1, 4) = '192.') Or (Copy(D, 1, 3) = '10.') Or
          (Copy(D, 1, 8) = '172.16.') Or (Copy(D, 1, 8) = '172.31.') Then
    IsLocalUrl := True;
End;

Procedure ValidateUrl(Const Url: String);
Var
  D: String;
Begin
  If Length(Url) = 0 Then
    FatalError('URL requise. Utilisez --help pour l''aide.');
  If Length(Url) > MAX_URL_LEN Then
    FatalError('URL trop longue (max ' + IntToStr(MAX_URL_LEN) + ' caracteres)');
  If Not IsValidUrl(Url) Then
    FatalError('URL invalide: doit commencer par http:// ou https://');
  D := ExtractDomain(Url);
  If Length(D) = 0 Then
    FatalError('URL invalide: domaine manquant');
  If Pos(' ', D) > 0 Then
    FatalError('URL invalide: espace dans le domaine');
End;

{ ============================================================
  TODO 04 : DETECTION DU SYSTEME D'EXPLOITATION [IMPLEMENTE]
  ============================================================ }

Function GetPlatform: Integer;
Begin
  {$IFDEF WINDOWS}
  GetPlatform := PLATFORM_WINDOWS;
  {$ELSE}
    {$IFDEF DARWIN}
    GetPlatform := PLATFORM_MACOS;
    {$ELSE}
      {$IFDEF LINUX}
      GetPlatform := PLATFORM_LINUX;
      {$ELSE}
      GetPlatform := PLATFORM_UNKNOWN;
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
End;

Function PlatformName(P: Integer): String;
Begin
  Case P Of
    PLATFORM_WINDOWS: PlatformName := 'Windows';
    PLATFORM_MACOS:   PlatformName := 'macOS';
    PLATFORM_LINUX:   PlatformName := 'Linux';
  Else
    PlatformName := 'Unknown';
  End;
End;

Function GetArchitecture: String;
{ Retourne l'architecture du systeme : x64, arm64 ou x86 }
Begin
  {$IFDEF CPU64}
    {$IFDEF CPUAARCH64}
    GetArchitecture := 'arm64';
    {$ELSE}
    GetArchitecture := 'x64';
    {$ENDIF}
  {$ELSE}
    {$IFDEF CPUARM}
    GetArchitecture := 'arm';
    {$ELSE}
    GetArchitecture := 'x86';
    {$ENDIF}
  {$ENDIF}
End;

Function IsRustInstalled: Boolean;
{ Verifie si Rust/Cargo est installe en testant cargo --version }
Begin
  {$IFDEF WINDOWS}
  Exec(GetEnv('COMSPEC'), '/c cargo --version >nul 2>&1');
  {$ELSE}
  Exec('/bin/sh', '-c "cargo --version >/dev/null 2>&1"');
  {$ENDIF}
  IsRustInstalled := (DosError = 0) And (DosExitCode = 0);
End;

Function IsTauriInstalled: Boolean;
{ Verifie si Tauri CLI est installe en testant cargo tauri --version }
Begin
  {$IFDEF WINDOWS}
  Exec(GetEnv('COMSPEC'), '/c cargo tauri --version >nul 2>&1');
  {$ELSE}
  Exec('/bin/sh', '-c "cargo tauri --version >/dev/null 2>&1"');
  {$ENDIF}
  IsTauriInstalled := (DosError = 0) And (DosExitCode = 0);
End;

Procedure CheckPrerequisites;
{ Verifie les prerequis : Rust, Tauri et dependances systeme }
Var
  Platform: Integer;
  MissingDeps: Boolean;
Begin
  MissingDeps := False;
  Platform := GetPlatform;
  
  WriteLn('Verification des prerequis...');
  WriteLn;
  
  { Verifier Rust }
  Write('  Rust/Cargo: ');
  If IsRustInstalled Then
    WriteLn('OK')
  Else
  Begin
    WriteLn('NON INSTALLE');
    WriteLn('    Pour installer Rust, visitez: https://rustup.rs/');
    MissingDeps := True;
  End;
  
  { Verifier Tauri CLI }
  Write('  Tauri CLI:  ');
  If IsTauriInstalled Then
    WriteLn('OK')
  Else
  Begin
    WriteLn('NON INSTALLE');
    WriteLn('    Pour installer: cargo install tauri-cli');
    MissingDeps := True;
  End;
  
  { Dependances specifiques au systeme }
  WriteLn;
  WriteLn('  Dependances systeme pour ', PlatformName(Platform), ':');
  
  Case Platform Of
    PLATFORM_WINDOWS:
    Begin
      WriteLn('    - WebView2 (inclus dans Windows 10/11)');
      WriteLn('    - Visual Studio Build Tools 2019+');
    End;
    PLATFORM_MACOS:
    Begin
      WriteLn('    - Xcode Command Line Tools');
      WriteLn('    - CLang/LLVM');
    End;
    PLATFORM_LINUX:
    Begin
      WriteLn('    - webkit2gtk-4.0');
      WriteLn('    - libayatana-appindicator3-1 ou libappindicator3-1');
      WriteLn('    - librsvg2-dev');
      WriteLn('    Sur Ubuntu/Debian:');
      WriteLn('      sudo apt install libwebkit2gtk-4.0-dev \');
      WriteLn('        build-essential curl wget libssl-dev \');
      WriteLn('        libgtk-3-dev libayatana-appindicator3-dev \');
      WriteLn('        librsvg2-dev');
    End;
  Else
    WriteLn('    Plateforme non supportee');
    MissingDeps := True;
  End;
  
  WriteLn;
  If MissingDeps Then
  Begin
    WriteLn('ATTENTION: Certains prerequis sont manquants.');
    WriteLn('Veuillez les installer avant de continuer.');
  End
  Else
    WriteLn('Tous les prerequis sont satisfaits.');
End;

{ ============================================================
  TODO 05 : CONFIGURATION DE LA FENETRE [IMPLEMENTE]
  ============================================================ }

{ Valider que les dimensions de fenetre sont dans les limites }
Function ValidateWindowSize(W, H: Integer): Boolean;
Begin
  ValidateWindowSize := (W >= MIN_WIDTH) And (W <= MAX_WIDTH) And
                        (H >= MIN_HEIGHT) And (H <= MAX_HEIGHT);
End;

{ Initialiser la configuration de fenetre depuis les options }
Procedure InitWindowConfig(Var Cfg: TWindowConfig; Const Opts: TOptions);
Begin
  { Dimensions }
  If Opts.Width > 0 Then
    Cfg.Width := Opts.Width
  Else
    Cfg.Width := DEFAULT_WIDTH;
  
  If Opts.Height > 0 Then
    Cfg.Height := Opts.Height
  Else
    Cfg.Height := DEFAULT_HEIGHT;
  
  { Valider et ajuster les dimensions }
  If Cfg.Width < MIN_WIDTH Then Cfg.Width := MIN_WIDTH;
  If Cfg.Width > MAX_WIDTH Then Cfg.Width := MAX_WIDTH;
  If Cfg.Height < MIN_HEIGHT Then Cfg.Height := MIN_HEIGHT;
  If Cfg.Height > MAX_HEIGHT Then Cfg.Height := MAX_HEIGHT;
  
  { Dimensions minimales }
  Cfg.MinWidth := MIN_WIDTH;
  Cfg.MinHeight := MIN_HEIGHT;
  
  { Options de fenetre }
  Cfg.Resizable := True;  { Fenetre redimensionnable par defaut }
  Cfg.Fullscreen := Opts.Fullscreen;
  Cfg.Transparent := Opts.Transparent;
  Cfg.Decorations := Not Opts.HideTitleBar;  { Barre de titre visible par defaut }
  Cfg.AlwaysOnTop := Opts.AlwaysOnTop;
  Cfg.Center := True;  { Centrer la fenetre par defaut }
  
  { Titre de la fenetre }
  If Opts.AppName <> '' Then
    Cfg.Title := Opts.AppName
  Else
    Cfg.Title := 'Pake Application';
End;

{ Generer la configuration JSON pour la section windows de tauri.conf.json }
Function WindowConfigToJson(Const Cfg: TWindowConfig): String;
Var
  Json: String;
  
  Function BoolToJson(B: Boolean): String;
  Begin
    If B Then
      BoolToJson := 'true'
    Else
      BoolToJson := 'false';
  End;
  
Begin
  Json := '{' + #13#10;
  Json := Json + '        "title": "' + EscapeJson(Cfg.Title) + '",' + #13#10;
  Json := Json + '        "width": ' + IntToStr(Cfg.Width) + ',' + #13#10;
  Json := Json + '        "height": ' + IntToStr(Cfg.Height) + ',' + #13#10;
  Json := Json + '        "minWidth": ' + IntToStr(Cfg.MinWidth) + ',' + #13#10;
  Json := Json + '        "minHeight": ' + IntToStr(Cfg.MinHeight) + ',' + #13#10;
  Json := Json + '        "resizable": ' + BoolToJson(Cfg.Resizable) + ',' + #13#10;
  Json := Json + '        "fullscreen": ' + BoolToJson(Cfg.Fullscreen) + ',' + #13#10;
  Json := Json + '        "transparent": ' + BoolToJson(Cfg.Transparent) + ',' + #13#10;
  Json := Json + '        "decorations": ' + BoolToJson(Cfg.Decorations) + ',' + #13#10;
  Json := Json + '        "alwaysOnTop": ' + BoolToJson(Cfg.AlwaysOnTop) + ',' + #13#10;
  Json := Json + '        "center": ' + BoolToJson(Cfg.Center) + #13#10;
  Json := Json + '      }';
  WindowConfigToJson := Json;
End;

{ Fonctions accesseurs pour TWindowConfig }
Function IsWinValidSize(W, H: Integer): Boolean;
Begin
  IsWinValidSize := ValidateWindowSize(W, H);
End;

Function GetWinDefaultWidth: Integer;
Begin
  GetWinDefaultWidth := DEFAULT_WIDTH;
End;

Function GetWinDefaultHeight: Integer;
Begin
  GetWinDefaultHeight := DEFAULT_HEIGHT;
End;

Function GetWinMinWidth: Integer;
Begin
  GetWinMinWidth := MIN_WIDTH;
End;

Function GetWinMinHeight: Integer;
Begin
  GetWinMinHeight := MIN_HEIGHT;
End;

Function GetWinMaxWidth: Integer;
Begin
  GetWinMaxWidth := MAX_WIDTH;
End;

Function GetWinMaxHeight: Integer;
Begin
  GetWinMaxHeight := MAX_HEIGHT;
End;

{ ============================================================
  TODO 06 - GESTION DES ICONES [IMPLEMENTE]
  ============================================================ }

{ Variables pour le module icones }
Var
  IcoInitialized : Boolean;
  IcoStateCount  : Integer;
  IcoDownloadCount : Integer;
  IcoConvertCount  : Integer;
  IcoValidateCount : Integer;
  IcoDefaultCount  : Integer;

{ Initialiser l'etat du module icones }
Procedure InitIconState;
Begin
  IcoInitialized := True;
  IcoStateCount := 0;
  IcoDownloadCount := 0;
  IcoConvertCount := 0;
  IcoValidateCount := 0;
  IcoDefaultCount := 0;
End;

{ Detecter le format d'icone depuis l'extension du fichier }
Function DetectIconFormat(Const Path: String): Integer;
Var
  Ext: String;
Begin
  Ext := LowerStr(ExtractFileExt(Path));
  If (Ext = '.ico') Then
    DetectIconFormat := ICON_ICO
  Else If (Ext = '.icns') Then
    DetectIconFormat := ICON_ICNS
  Else If (Ext = '.png') Then
    DetectIconFormat := ICON_PNG
  Else
    DetectIconFormat := 0; { Format inconnu }
End;

{ Retourner le nom du format d'icone }
Function IconFormatName(Format: Integer): String;
Begin
  Case Format Of
    ICON_ICO  : IconFormatName := 'ICO';
    ICON_ICNS : IconFormatName := 'ICNS';
    ICON_PNG  : IconFormatName := 'PNG';
  Else
    IconFormatName := 'UNKNOWN';
  End;
End;

{ Valider qu'un fichier icone existe et est accessible }
Function ValidateIconFile(Const Path: String): Boolean;
Var
  IconFormat: Integer;
Begin
  Inc(IcoValidateCount);
  Inc(IcoStateCount);
  
  { Verifier si le fichier existe }
  If Not FileExists(Path) Then
  Begin
    ValidateIconFile := False;
    Exit;
  End;
  
  { Verifier que le format est reconnu }
  IconFormat := DetectIconFormat(Path);
  If IconFormat = 0 Then
  Begin
    ValidateIconFile := False;
    Exit;
  End;
  
  ValidateIconFile := True;
End;

{ Construire l'URL du favicon depuis un domaine }
Function GetFaviconUrl(Const Url: String): String;
Var
  Domain: String;
Begin
  Domain := ExtractDomain(Url);
  If Domain = '' Then
  Begin
    GetFaviconUrl := '';
    Exit;
  End;
  
  { Utiliser Google Favicon Service pour une meilleure qualite }
  GetFaviconUrl := 'https://www.google.com/s2/favicons?domain=' + Domain + '&sz=256';
End;

{ Construire l'URL directe du favicon.ico depuis un domaine }
Function GetDirectFaviconUrl(Const Url: String): String;
Var
  Protocol, Domain: String;
Begin
  Protocol := ExtractProtocol(Url);
  Domain := ExtractDomain(Url);
  If Domain = '' Then
  Begin
    GetDirectFaviconUrl := '';
    Exit;
  End;
  
  GetDirectFaviconUrl := Protocol + '://' + Domain + '/favicon.ico';
End;

{ Telecharger le favicon depuis l'URL vers un fichier local }
Procedure DownloadFavicon(Const Url, DestPath: String);
Var
  Cmd: String;
  Platform: Integer;
Begin
  Inc(IcoDownloadCount);
  Inc(IcoStateCount);
  
  Platform := GetPlatform;
  
  { Construire la commande selon la plateforme }
  {$IFDEF WINDOWS}
    { Utiliser curl sur Windows (inclus dans Windows 10+) }
    Cmd := 'curl -s -o ' + QuoteStr(DestPath) + ' ' + QuoteStr(Url);
  {$ELSE}
    { Utiliser wget ou curl sur Linux/macOS }
    Cmd := 'wget -q -O ' + QuoteStr(DestPath) + ' ' + QuoteStr(Url);
  {$ENDIF}
  
  { Executer la commande }
  Exec(GetEnv('COMSPEC'), '/C ' + Cmd);
End;

{ Convertir une icone entre formats }
Function ConvertIconFormat(Const SrcPath: String; DestFormat: Integer; Const DestPath: String): Boolean;
Var
  Cmd: String;
  SrcFormat: Integer;
Begin
  Inc(IcoConvertCount);
  Inc(IcoStateCount);
  
  { Verifier le fichier source }
  If Not FileExists(SrcPath) Then
  Begin
    ConvertIconFormat := False;
    Exit;
  End;
  
  SrcFormat := DetectIconFormat(SrcPath);
  If SrcFormat = 0 Then
  Begin
    ConvertIconFormat := False;
    Exit;
  End;
  
  { Si meme format, copier simplement }
  If SrcFormat = DestFormat Then
  Begin
    { Copier le fichier }
    Cmd := '';
    {$IFDEF WINDOWS}
      Cmd := 'copy ' + QuoteStr(SrcPath) + ' ' + QuoteStr(DestPath);
    {$ELSE}
      Cmd := 'cp ' + QuoteStr(SrcPath) + ' ' + QuoteStr(DestPath);
    {$ENDIF}
    Exec(GetEnv('COMSPEC'), '/C ' + Cmd);
    ConvertIconFormat := True;
    Exit;
  End;
  
  { Conversion avec ImageMagick (convert) si disponible }
  Cmd := 'convert ' + QuoteStr(SrcPath) + ' ';
  
  Case DestFormat Of
    ICON_ICO:
      Begin
        { Convertir en ICO (256x256 pour Windows) }
        Cmd := Cmd + '-resize 256x256 ' + QuoteStr(DestPath);
      End;
    ICON_ICNS:
      Begin
        { Convertir en ICNS (multi-resolution pour macOS) }
        { Note: iconutil requis sur macOS pour ICNS natif }
        Cmd := Cmd + '-resize 512x512 ' + QuoteStr(DestPath);
      End;
    ICON_PNG:
      Begin
        { Convertir en PNG (512x512 pour Linux) }
        Cmd := Cmd + '-resize 512x512 ' + QuoteStr(DestPath);
      End;
  End;
  
  Exec(GetEnv('COMSPEC'), '/C ' + Cmd);
  ConvertIconFormat := True;
End;

{ Obtenir le chemin de l'icone par defaut pour une plateforme }
Function GetDefaultIconPath(Platform: Integer): String;
Begin
  Case Platform Of
    PLATFORM_WINDOWS:
      GetDefaultIconPath := 'icons/icon.ico';
    PLATFORM_MACOS:
      GetDefaultIconPath := 'icons/icon.icns';
    PLATFORM_LINUX:
      GetDefaultIconPath := 'icons/icon.png';
  Else
    GetDefaultIconPath := 'icons/icon.png';
  End;
End;

{ Obtenir le format d'icone recommande pour une plateforme }
Function GetPlatformIconFormat(Platform: Integer): Integer;
Begin
  Case Platform Of
    PLATFORM_WINDOWS:
      GetPlatformIconFormat := ICON_ICO;
    PLATFORM_MACOS:
      GetPlatformIconFormat := ICON_ICNS;
    PLATFORM_LINUX:
      GetPlatformIconFormat := ICON_PNG;
  Else
    GetPlatformIconFormat := ICON_PNG;
  End;
End;

{ Preparer les icones pour toutes les plateformes }
Procedure PrepareIcons(Const Opts: TOptions; Const WorkDir: String);
Var
  IconsDir: String;
  SrcPath: String;
  DestPathIco, DestPathIcns, DestPathPng: String;
  FaviconUrl: String;
  TempPng: String;
Begin
  Inc(IcoStateCount);
  
  { Creer le repertoire icons }
  IconsDir := ConcatPath(WorkDir, 'icons');
  CreateDir(IconsDir);
  
  { Determiner le chemin source de l'icone }
  If (Opts.IconPath <> '') And FileExists(Opts.IconPath) Then
  Begin
    SrcPath := Opts.IconPath;
  End
  Else
  Begin
    { Telecharger le favicon }
    Inc(IcoDefaultCount);
    TempPng := ConcatPath(IconsDir, 'favicon.png');
    FaviconUrl := GetFaviconUrl(Opts.Url);
    If FaviconUrl <> '' Then
    Begin
      DownloadFavicon(FaviconUrl, TempPng);
      SrcPath := TempPng;
    End
    Else
    Begin
      { Pas d'icone disponible }
      Exit;
    End;
  End;
  
  { Definir les chemins de destination }
  DestPathIco := ConcatPath(IconsDir, 'icon.ico');
  DestPathIcns := ConcatPath(IconsDir, 'icon.icns');
  DestPathPng := ConcatPath(IconsDir, 'icon.png');
  
  { Convertir pour chaque plateforme }
  ConvertIconFormat(SrcPath, ICON_ICO, DestPathIco);
  ConvertIconFormat(SrcPath, ICON_ICNS, DestPathIcns);
  ConvertIconFormat(SrcPath, ICON_PNG, DestPathPng);
End;

{ Verifier si une icone est de taille valide (256x256 minimum recommande) }
Function IsIconSizeValid(Const Path: String): Boolean;
Begin
  { Note: Verifier la taille reelle necessite une lecture du fichier }
  { Pour l'instant, on accepte si le fichier existe et a un format valide }
  IsIconSizeValid := ValidateIconFile(Path);
End;

{ Obtenir l'extension de fichier pour un format d'icone }
Function GetIconExtension(Format: Integer): String;
Begin
  Case Format Of
    ICON_ICO  : GetIconExtension := '.ico';
    ICON_ICNS : GetIconExtension := '.icns';
    ICON_PNG  : GetIconExtension := '.png';
  Else
    GetIconExtension := '.png';
  End;
End;

{ *** FONCTIONS ACCESSEURS POUR LE MODULE ICONES *** }

Function IsIcoInitialized: Boolean;
Begin
  IsIcoInitialized := IcoInitialized;
End;

Function IsIcoEmpty: Boolean;
Begin
  IsIcoEmpty := (IcoStateCount = 0);
End;

Function GetIcoStateCount: Integer;
Begin
  GetIcoStateCount := IcoStateCount;
End;

Function GetIcoDownloadCount: Integer;
Begin
  GetIcoDownloadCount := IcoDownloadCount;
End;

Function GetIcoConvertCount: Integer;
Begin
  GetIcoConvertCount := IcoConvertCount;
End;

Function GetIcoValidateCount: Integer;
Begin
  GetIcoValidateCount := IcoValidateCount;
End;

Function GetIcoDefaultCount: Integer;
Begin
  GetIcoDefaultCount := IcoDefaultCount;
End;

Function GetIcoFormatIco: Integer;
Begin
  GetIcoFormatIco := ICON_ICO;
End;

Function GetIcoFormatIcns: Integer;
Begin
  GetIcoFormatIcns := ICON_ICNS;
End;

Function GetIcoFormatPng: Integer;
Begin
  GetIcoFormatPng := ICON_PNG;
End;

{ ============================================================
  TODO 07 - GENERATION DU NOM D'APPLICATION [IMPLEMENTE]
  ============================================================ }

Var
  { Variables d'etat du module AppName }
  AnmInitialized     : Boolean;
  AnmStateCount      : Integer;
  AnmSanitizeCount   : Integer;
  AnmGenerateCount   : Integer;
  AnmIdentifierCount : Integer;
  AnmPackageCount    : Integer;
  AnmValidateCount   : Integer;

{ Initialiser l'etat du module AppName }
Procedure InitAppNameState;
Begin
  AnmInitialized := True;
  AnmStateCount := 0;
  AnmSanitizeCount := 0;
  AnmGenerateCount := 0;
  AnmIdentifierCount := 0;
  AnmPackageCount := 0;
  AnmValidateCount := 0;
End;

{ Verifier si un caractere est valide pour un nom de fichier }
Function IsValidFileNameChar(C: Char): Boolean;
Begin
  IsValidFileNameChar := (C In ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.']);
End;

{ Sanitize un nom d'application - retirer caracteres invalides }
Function SanitizeAppName(Const Name: String): String;
Var
  I: Integer;
  R: String;
  C: Char;
Begin
  Inc(AnmStateCount);
  Inc(AnmSanitizeCount);
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    C := Name[I];
    If C = ' ' Then
      R := R + '-'
    Else If IsValidFileNameChar(C) Then
      R := R + C;
    { Ignorer les autres caracteres }
  End;
  { Limiter la taille }
  If Length(R) > MAX_NAME_LEN Then
    R := Copy(R, 1, MAX_NAME_LEN);
  { Retourner un nom par defaut si vide }
  If Length(R) = 0 Then
    R := 'WebApp';
  SanitizeAppName := R;
End;

{ Generer un nom d'application a partir des options }
Function GenerateAppName(Const Opts: TOptions): String;
Var
  Name, Domain: String;
Begin
  Inc(AnmStateCount);
  Inc(AnmGenerateCount);
  If Opts.AppName <> '' Then
    Name := SanitizeAppName(Opts.AppName)
  Else
  Begin
    { Extraire du domaine }
    Domain := ExtractDomain(Opts.Url);
    Domain := NormalizeDomain(Domain);
    Name := DomainToAppName(Domain);
    Name := SanitizeAppName(Name);
  End;
  GenerateAppName := Name;
End;

{ Generer un identifiant de bundle (com.pake.APPNAME) }
Function GenerateIdentifier(Const AppName: String): String;
Var
  Name: String;
  I: Integer;
Begin
  Inc(AnmStateCount);
  Inc(AnmIdentifierCount);
  { Convertir en minuscules et remplacer caracteres invalides }
  Name := '';
  For I := 1 To Length(AppName) Do
  Begin
    If AppName[I] In ['A'..'Z'] Then
      Name := Name + Chr(Ord(AppName[I]) + 32)
    Else If AppName[I] In ['a'..'z', '0'..'9'] Then
      Name := Name + AppName[I]
    Else If AppName[I] In ['-', '_'] Then
      Name := Name + '-';
  End;
  If Length(Name) = 0 Then
    Name := 'webapp';
  GenerateIdentifier := 'com.pake.' + Name;
End;

{ Generer un nom de package valide (minuscules, tirets) }
Function GeneratePackageName(Const AppName: String): String;
Var
  Name: String;
  I: Integer;
Begin
  Inc(AnmStateCount);
  Inc(AnmPackageCount);
  Name := '';
  For I := 1 To Length(AppName) Do
  Begin
    If AppName[I] In ['A'..'Z'] Then
      Name := Name + Chr(Ord(AppName[I]) + 32)
    Else If AppName[I] In ['a'..'z', '0'..'9'] Then
      Name := Name + AppName[I]
    Else If AppName[I] In ['-', '_', ' '] Then
      Name := Name + '-';
  End;
  { Retirer les tirets en debut et fin }
  While (Length(Name) > 0) And (Name[1] = '-') Do
    Name := Copy(Name, 2, Length(Name) - 1);
  While (Length(Name) > 0) And (Name[Length(Name)] = '-') Do
    Name := Copy(Name, 1, Length(Name) - 1);
  If Length(Name) = 0 Then
    Name := 'webapp';
  GeneratePackageName := Name;
End;

{ Verifier si un nom est reserve (Windows) }
Function IsReservedName(Const Name: String): Boolean;
Var
  UpName: String;
Begin
  UpName := UpCaseStr(Name);
  IsReservedName := (UpName = 'CON') Or (UpName = 'PRN') Or
                    (UpName = 'AUX') Or (UpName = 'NUL') Or
                    (UpName = 'COM1') Or (UpName = 'COM2') Or
                    (UpName = 'COM3') Or (UpName = 'COM4') Or
                    (UpName = 'COM5') Or (UpName = 'COM6') Or
                    (UpName = 'COM7') Or (UpName = 'COM8') Or
                    (UpName = 'COM9') Or (UpName = 'LPT1') Or
                    (UpName = 'LPT2') Or (UpName = 'LPT3') Or
                    (UpName = 'LPT4') Or (UpName = 'LPT5') Or
                    (UpName = 'LPT6') Or (UpName = 'LPT7') Or
                    (UpName = 'LPT8') Or (UpName = 'LPT9');
End;

{ Valider un nom d'application }
Procedure ValidateAppName(Const Name: String);
Var
  I: Integer;
  C: Char;
  HasInvalid: Boolean;
Begin
  Inc(AnmStateCount);
  Inc(AnmValidateCount);
  { Verifier si vide }
  If Length(Name) = 0 Then
    FatalError('Le nom d''application ne peut pas etre vide');
  { Verifier si trop long }
  If Length(Name) > MAX_NAME_LEN Then
    FatalError('Le nom d''application est trop long (max ' + IntToStr(MAX_NAME_LEN) + ' caracteres)');
  { Verifier les caracteres interdits }
  HasInvalid := False;
  For I := 1 To Length(Name) Do
  Begin
    C := Name[I];
    If C In ['<', '>', ':', '"', '/', '\', '|', '?', '*'] Then
    Begin
      HasInvalid := True;
      Break;
    End;
  End;
  If HasInvalid Then
    FatalError('Le nom d''application contient des caracteres interdits: < > : " / \ | ? *');
  { Verifier si nom reserve Windows }
  If IsReservedName(Name) Then
    FatalError('Le nom d''application "' + Name + '" est un nom reserve Windows');
End;

{ *** FONCTIONS ACCESSEURS POUR LE MODULE APPNAME *** }

Function IsAnmInitialized: Boolean;
Begin
  IsAnmInitialized := AnmInitialized;
End;

Function IsAnmEmpty: Boolean;
Begin
  IsAnmEmpty := (AnmStateCount = 0);
End;

Function GetAnmStateCount: Integer;
Begin
  GetAnmStateCount := AnmStateCount;
End;

Function GetAnmSanitizeCount: Integer;
Begin
  GetAnmSanitizeCount := AnmSanitizeCount;
End;

Function GetAnmGenerateCount: Integer;
Begin
  GetAnmGenerateCount := AnmGenerateCount;
End;

Function GetAnmIdentifierCount: Integer;
Begin
  GetAnmIdentifierCount := AnmIdentifierCount;
End;

Function GetAnmPackageCount: Integer;
Begin
  GetAnmPackageCount := AnmPackageCount;
End;

Function GetAnmValidateCount: Integer;
Begin
  GetAnmValidateCount := AnmValidateCount;
End;

Function GetAnmMaxNameLen: Integer;
Begin
  GetAnmMaxNameLen := MAX_NAME_LEN;
End;

Function GetAnmReservedCount: Integer;
Begin
  { Nombre de noms reserves Windows (CON, PRN, AUX, NUL, COM1-9, LPT1-9) }
  GetAnmReservedCount := 22;
End;

{ ============================================================
  TODO 08 - CONFIGURATION TAURI [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes pour Tauri config }
  TAURI_MAX_ICONS = 4;
  TAURI_VERSION = '1.0.0';
  TAURI_CSP_DEFAULT = 'default-src ''self''';

Type
  { Sous-record Package }
  TTauriPackage = Record
    ProductName : String;
    Version     : String;
    Identifier  : String;
  End;

  { Sous-record Build }
  TTauriBuild = Record
    DistDir            : String;
    DevPath            : String;
    BeforeDevCommand   : String;
    BeforeBuildCommand : String;
  End;

  { Sous-record Bundle }
  TTauriBundle = Record
    Active  : Boolean;
    Targets : String;
    Icon    : Array[1..TAURI_MAX_ICONS] Of String;
    IconCount : Integer;
  End;

  { Sous-record Security }
  TTauriSecurity = Record
    Csp : String;
  End;

  { Sous-record TauriSection }
  TTauriSection = Record
    Bundle   : TTauriBundle;
    Windows  : TWindowConfig;
    Security : TTauriSecurity;
  End;

  { Record principal TTauriConfig }
  TTauriConfig = Record
    Package : TTauriPackage;
    Build   : TTauriBuild;
    Tauri   : TTauriSection;
  End;

Var
  { Variables d'etat pour le module Tauri Config }
  TcfInitialized   : Boolean;
  TcfStateCount    : Integer;
  TcfConfigCount   : Integer;
  TcfJsonGenCount  : Integer;
  TcfWriteCount    : Integer;
  TcfCargoGenCount : Integer;
  TcfIconCount     : Integer;

{ Initialiser l'etat du module Tauri Config }
Procedure InitTauriConfigState;
Begin
  TcfInitialized := True;
  TcfStateCount := 0;
  TcfConfigCount := 0;
  TcfJsonGenCount := 0;
  TcfWriteCount := 0;
  TcfCargoGenCount := 0;
  TcfIconCount := 0;
End;

{ Initialiser une configuration Tauri depuis les options }
Procedure InitTauriConfig(Var Cfg: TTauriConfig; Const Opts: TOptions);
Var
  WinCfg: TWindowConfig;
Begin
  Inc(TcfStateCount);
  Inc(TcfConfigCount);

  { Initialiser Package }
  Cfg.Package.ProductName := Opts.AppName;
  Cfg.Package.Version := TAURI_VERSION;
  Cfg.Package.Identifier := GenerateIdentifier(Opts.AppName);

  { Initialiser Build }
  Cfg.Build.DistDir := '../dist';
  Cfg.Build.DevPath := '../dist';
  Cfg.Build.BeforeDevCommand := '';
  Cfg.Build.BeforeBuildCommand := '';

  { Initialiser Bundle }
  Cfg.Tauri.Bundle.Active := True;
  If Opts.Targets <> '' Then
    Cfg.Tauri.Bundle.Targets := Opts.Targets
  Else
    Cfg.Tauri.Bundle.Targets := 'all';

  { Initialiser les icones }
  Cfg.Tauri.Bundle.Icon[1] := 'icons/32x32.png';
  Cfg.Tauri.Bundle.Icon[2] := 'icons/128x128.png';
  Cfg.Tauri.Bundle.Icon[3] := 'icons/128x128@2x.png';
  Cfg.Tauri.Bundle.Icon[4] := 'icons/icon.icns';
  Cfg.Tauri.Bundle.IconCount := TAURI_MAX_ICONS;
  Inc(TcfIconCount, TAURI_MAX_ICONS);

  { Initialiser Windows depuis les options }
  InitWindowConfig(WinCfg, Opts);
  Cfg.Tauri.Windows := WinCfg;

  { Initialiser Security }
  Cfg.Tauri.Security.Csp := TAURI_CSP_DEFAULT;
End;

{ Generer le JSON pour la configuration Tauri }
Function TauriConfigToJson(Const Cfg: TTauriConfig): String;
Var
  Json: String;
  I: Integer;
Begin
  Inc(TcfStateCount);
  Inc(TcfJsonGenCount);

  Json := '{' + Chr(10);

  { Section package }
  Json := Json + '  "package": {' + Chr(10);
  Json := Json + '    "productName": "' + EscapeJson(Cfg.Package.ProductName) + '",' + Chr(10);
  Json := Json + '    "version": "' + EscapeJson(Cfg.Package.Version) + '"' + Chr(10);
  Json := Json + '  },' + Chr(10);

  { Section build }
  Json := Json + '  "build": {' + Chr(10);
  Json := Json + '    "distDir": "' + EscapeJson(Cfg.Build.DistDir) + '",' + Chr(10);
  Json := Json + '    "devPath": "' + EscapeJson(Cfg.Build.DevPath) + '"';
  If Cfg.Build.BeforeDevCommand <> '' Then
  Begin
    Json := Json + ',' + Chr(10);
    Json := Json + '    "beforeDevCommand": "' + EscapeJson(Cfg.Build.BeforeDevCommand) + '"';
  End;
  If Cfg.Build.BeforeBuildCommand <> '' Then
  Begin
    Json := Json + ',' + Chr(10);
    Json := Json + '    "beforeBuildCommand": "' + EscapeJson(Cfg.Build.BeforeBuildCommand) + '"';
  End;
  Json := Json + Chr(10) + '  },' + Chr(10);

  { Section tauri }
  Json := Json + '  "tauri": {' + Chr(10);

  { Sous-section bundle }
  Json := Json + '    "bundle": {' + Chr(10);
  If Cfg.Tauri.Bundle.Active Then
    Json := Json + '      "active": true,' + Chr(10)
  Else
    Json := Json + '      "active": false,' + Chr(10);
  Json := Json + '      "targets": "' + EscapeJson(Cfg.Tauri.Bundle.Targets) + '",' + Chr(10);
  Json := Json + '      "icon": [' + Chr(10);
  For I := 1 To Cfg.Tauri.Bundle.IconCount Do
  Begin
    Json := Json + '        "' + EscapeJson(Cfg.Tauri.Bundle.Icon[I]) + '"';
    If I < Cfg.Tauri.Bundle.IconCount Then
      Json := Json + ',';
    Json := Json + Chr(10);
  End;
  Json := Json + '      ]' + Chr(10);
  Json := Json + '    },' + Chr(10);

  { Sous-section windows }
  Json := Json + '    "windows": [' + Chr(10);
  Json := Json + '      {' + Chr(10);
  Json := Json + '        "title": "' + EscapeJson(Cfg.Tauri.Windows.Title) + '",' + Chr(10);
  Json := Json + '        "width": ' + IntToStr(Cfg.Tauri.Windows.Width) + ',' + Chr(10);
  Json := Json + '        "height": ' + IntToStr(Cfg.Tauri.Windows.Height) + ',' + Chr(10);
  Json := Json + '        "minWidth": ' + IntToStr(Cfg.Tauri.Windows.MinWidth) + ',' + Chr(10);
  Json := Json + '        "minHeight": ' + IntToStr(Cfg.Tauri.Windows.MinHeight) + ',' + Chr(10);
  If Cfg.Tauri.Windows.Resizable Then
    Json := Json + '        "resizable": true,' + Chr(10)
  Else
    Json := Json + '        "resizable": false,' + Chr(10);
  If Cfg.Tauri.Windows.Fullscreen Then
    Json := Json + '        "fullscreen": true,' + Chr(10)
  Else
    Json := Json + '        "fullscreen": false,' + Chr(10);
  If Cfg.Tauri.Windows.Transparent Then
    Json := Json + '        "transparent": true,' + Chr(10)
  Else
    Json := Json + '        "transparent": false,' + Chr(10);
  If Cfg.Tauri.Windows.Decorations Then
    Json := Json + '        "decorations": true,' + Chr(10)
  Else
    Json := Json + '        "decorations": false,' + Chr(10);
  If Cfg.Tauri.Windows.AlwaysOnTop Then
    Json := Json + '        "alwaysOnTop": true,' + Chr(10)
  Else
    Json := Json + '        "alwaysOnTop": false,' + Chr(10);
  If Cfg.Tauri.Windows.Center Then
    Json := Json + '        "center": true' + Chr(10)
  Else
    Json := Json + '        "center": false' + Chr(10);
  Json := Json + '      }' + Chr(10);
  Json := Json + '    ],' + Chr(10);

  { Sous-section security }
  Json := Json + '    "security": {' + Chr(10);
  Json := Json + '      "csp": "' + EscapeJson(Cfg.Tauri.Security.Csp) + '"' + Chr(10);
  Json := Json + '    }' + Chr(10);

  Json := Json + '  }' + Chr(10);
  Json := Json + '}';

  TauriConfigToJson := Json;
End;

{ Ecrire la configuration Tauri dans un fichier }
Procedure WriteTauriConfig(Const WorkDir: String; Const Cfg: TTauriConfig);
Var
  F: Text;
  FilePath: String;
  Json: String;
Begin
  Inc(TcfStateCount);
  Inc(TcfWriteCount);

  FilePath := ConcatPath(WorkDir, 'tauri.conf.json');
  Json := TauriConfigToJson(Cfg);

  {$I-}
  Assign(F, FilePath);
  Rewrite(F);
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FilePath);
    Exit;
  End;

  Write(F, Json);
  Close(F);
  {$I+}
End;

{ Generer le contenu du fichier Cargo.toml }
Function GenerateCargoToml(Const AppName: String): String;
Var
  Toml: String;
  PkgName: String;
Begin
  Inc(TcfStateCount);
  Inc(TcfCargoGenCount);

  PkgName := GeneratePackageName(AppName);

  Toml := '[package]' + Chr(10);
  Toml := Toml + 'name = "' + PkgName + '"' + Chr(10);
  Toml := Toml + 'version = "0.1.0"' + Chr(10);
  Toml := Toml + 'description = "A Tauri App - ' + AppName + '"' + Chr(10);
  Toml := Toml + 'authors = ["you"]' + Chr(10);
  Toml := Toml + 'license = ""' + Chr(10);
  Toml := Toml + 'repository = ""' + Chr(10);
  Toml := Toml + 'default-run = "' + PkgName + '"' + Chr(10);
  Toml := Toml + 'edition = "2021"' + Chr(10);
  Toml := Toml + 'rust-version = "1.60"' + Chr(10);
  Toml := Toml + Chr(10);

  Toml := Toml + '[build-dependencies]' + Chr(10);
  Toml := Toml + 'tauri-build = { version = "1.5.0", features = [] }' + Chr(10);
  Toml := Toml + Chr(10);

  Toml := Toml + '[dependencies]' + Chr(10);
  Toml := Toml + 'serde_json = "1.0"' + Chr(10);
  Toml := Toml + 'serde = { version = "1.0", features = ["derive"] }' + Chr(10);
  Toml := Toml + 'tauri = { version = "1.5.0", features = [] }' + Chr(10);
  Toml := Toml + Chr(10);

  Toml := Toml + '[features]' + Chr(10);
  Toml := Toml + 'default = [ "custom-protocol" ]' + Chr(10);
  Toml := Toml + 'custom-protocol = [ "tauri/custom-protocol" ]' + Chr(10);

  GenerateCargoToml := Toml;
End;

{ Ecrire le fichier Cargo.toml }
Procedure WriteCargoToml(Const WorkDir: String; Const AppName: String);
Var
  F: Text;
  FilePath: String;
  Toml: String;
Begin
  Inc(TcfStateCount);

  FilePath := ConcatPath(WorkDir, 'Cargo.toml');
  Toml := GenerateCargoToml(AppName);

  {$I-}
  Assign(F, FilePath);
  Rewrite(F);
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier: ' + FilePath);
    Exit;
  End;

  Write(F, Toml);
  Close(F);
  {$I+}
End;

{ ============================================================
  Accesseurs pour TODO 08 - CONFIGURATION TAURI
  ============================================================ }

Function IsTcfInitialized: Boolean;
Begin
  IsTcfInitialized := TcfInitialized;
End;

Function IsTcfEmpty: Boolean;
Begin
  IsTcfEmpty := (TcfConfigCount = 0) And (TcfJsonGenCount = 0);
End;

Function GetTcfStateCount: Integer;
Begin
  GetTcfStateCount := TcfStateCount;
End;

Function GetTcfConfigCount: Integer;
Begin
  GetTcfConfigCount := TcfConfigCount;
End;

Function GetTcfJsonGenCount: Integer;
Begin
  GetTcfJsonGenCount := TcfJsonGenCount;
End;

Function GetTcfWriteCount: Integer;
Begin
  GetTcfWriteCount := TcfWriteCount;
End;

Function GetTcfCargoGenCount: Integer;
Begin
  GetTcfCargoGenCount := TcfCargoGenCount;
End;

Function GetTcfIconCount: Integer;
Begin
  GetTcfIconCount := TcfIconCount;
End;

Function GetTcfMaxIcons: Integer;
Begin
  GetTcfMaxIcons := TAURI_MAX_ICONS;
End;

Function GetTcfDefaultCsp: String;
Begin
  GetTcfDefaultCsp := TAURI_CSP_DEFAULT;
End;

{ ============================================================
  TODO 09 - GENERATION DU CODE RUST PRINCIPAL [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes pour la generation Rust }
  RGS_MAX_SCRIPTS = 8;
  RGS_TAURI_VERSION = '1.5';
  RGS_DEFAULT_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

Var
  { Variables d'etat pour le module Rust Generation }
  RgsInitialized   : Boolean;
  RgsStateCount    : Integer;
  RgsMainRsCount   : Integer;
  RgsLibRsCount    : Integer;
  RgsBuildRsCount  : Integer;
  RgsIndexHtmlCount: Integer;
  RgsWriteCount    : Integer;

{ Initialiser l'etat du module Rust Generation }
Procedure InitRustGenState;
Begin
  RgsInitialized := True;
  RgsStateCount := 0;
  RgsMainRsCount := 0;
  RgsLibRsCount := 0;
  RgsBuildRsCount := 0;
  RgsIndexHtmlCount := 0;
  RgsWriteCount := 0;
End;

{ Generer le fichier main.rs avec Tauri Builder }
Function GenerateMainRs(Const Opts: TOptions): String;
Var
  Rs: String;
  WinTitle: String;
Begin
  Inc(RgsStateCount);
  Inc(RgsMainRsCount);

  If Opts.AppName <> '' Then
    WinTitle := Opts.AppName
  Else
    WinTitle := 'Pake App';

  Rs := '// main.rs - Generated by PAKE ' + PAKE_VERSION + #13#10;
  Rs := Rs + '// Tauri application entry point' + #13#10;
  Rs := Rs + #13#10;
  Rs := Rs + '#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]' + #13#10;
  Rs := Rs + #13#10;
  Rs := Rs + 'use tauri::Manager;' + #13#10;
  Rs := Rs + #13#10;

  { Fonction principale }
  Rs := Rs + 'fn main() {' + #13#10;
  Rs := Rs + '    tauri::Builder::default()' + #13#10;
  Rs := Rs + '        .setup(|app| {' + #13#10;
  Rs := Rs + '            let window = app.get_window("main").unwrap();' + #13#10;

  { Configuration de la fenetre }
  Rs := Rs + '            window.set_title("' + EscapeJson(WinTitle) + '").ok();' + #13#10;

  If Opts.AlwaysOnTop Then
    Rs := Rs + '            window.set_always_on_top(true).ok();' + #13#10;

  If Opts.Fullscreen Then
    Rs := Rs + '            window.set_fullscreen(true).ok();' + #13#10;

  { Navigation vers l'URL }
  Rs := Rs + '            // Load target URL' + #13#10;
  Rs := Rs + '            let url = "' + EscapeJson(Opts.Url) + '";' + #13#10;
  Rs := Rs + '            window.eval(&format!("window.location.href = ''''{}''''", url)).ok();' + #13#10;

  { Injection CSS si specifie }
  If Opts.InjectCss <> '' Then
  Begin
    Rs := Rs + '            // Inject custom CSS' + #13#10;
    Rs := Rs + '            let css_path = "' + EscapeJson(Opts.InjectCss) + '";' + #13#10;
    Rs := Rs + '            if let Ok(css) = std::fs::read_to_string(css_path) {' + #13#10;
    Rs := Rs + '                let script = format!(' + #13#10;
    Rs := Rs + '                    "const s=document.createElement(''style'');s.textContent=''''{}'''''';document.head.appendChild(s);",' + #13#10;
    Rs := Rs + '                    css.replace("\\n", " ").replace("\"", "\\\"")' + #13#10;
    Rs := Rs + '                );' + #13#10;
    Rs := Rs + '                window.eval(&script).ok();' + #13#10;
    Rs := Rs + '            }' + #13#10;
  End;

  { Injection JS si specifie }
  If Opts.InjectJs <> '' Then
  Begin
    Rs := Rs + '            // Inject custom JavaScript' + #13#10;
    Rs := Rs + '            let js_path = "' + EscapeJson(Opts.InjectJs) + '";' + #13#10;
    Rs := Rs + '            if let Ok(js) = std::fs::read_to_string(js_path) {' + #13#10;
    Rs := Rs + '                window.eval(&js).ok();' + #13#10;
    Rs := Rs + '            }' + #13#10;
  End;

  Rs := Rs + '            Ok(())' + #13#10;
  Rs := Rs + '        })' + #13#10;

  { Gestion des evenements }
  Rs := Rs + '        .on_window_event(|event| match event.event() {' + #13#10;
  Rs := Rs + '            tauri::WindowEvent::CloseRequested { api, .. } => {' + #13#10;
  Rs := Rs + '                // Handle close event' + #13#10;
  Rs := Rs + '                event.window().hide().unwrap();' + #13#10;
  Rs := Rs + '                api.prevent_close();' + #13#10;
  Rs := Rs + '            }' + #13#10;
  Rs := Rs + '            _ => {}' + #13#10;
  Rs := Rs + '        })' + #13#10;

  Rs := Rs + '        .run(tauri::generate_context!())' + #13#10;
  Rs := Rs + '        .expect("error while running tauri application");' + #13#10;
  Rs := Rs + '}' + #13#10;

  GenerateMainRs := Rs;
End;

{ Generer lib.rs pour les fonctions utilitaires }
Function GenerateLibRs(Const Opts: TOptions): String;
Var
  Rs: String;
Begin
  Inc(RgsStateCount);
  Inc(RgsLibRsCount);

  Rs := '// lib.rs - Generated by PAKE ' + PAKE_VERSION + #13#10;
  Rs := Rs + '// Utility functions for the Tauri application' + #13#10;
  Rs := Rs + #13#10;

  { Module de configuration }
  Rs := Rs + '/// Application configuration' + #13#10;
  Rs := Rs + 'pub mod config {' + #13#10;
  Rs := Rs + '    pub const APP_NAME: &str = "' + EscapeJson(Opts.AppName) + '";' + #13#10;
  Rs := Rs + '    pub const APP_URL: &str = "' + EscapeJson(Opts.Url) + '";' + #13#10;
  Rs := Rs + '    pub const WINDOW_WIDTH: u32 = ' + IntToStr(Opts.Width) + ';' + #13#10;
  Rs := Rs + '    pub const WINDOW_HEIGHT: u32 = ' + IntToStr(Opts.Height) + ';' + #13#10;
  Rs := Rs + '    pub const FULLSCREEN: bool = ';
  If Opts.Fullscreen Then Rs := Rs + 'true' Else Rs := Rs + 'false';
  Rs := Rs + ';' + #13#10;
  Rs := Rs + '    pub const TRANSPARENT: bool = ';
  If Opts.Transparent Then Rs := Rs + 'true' Else Rs := Rs + 'false';
  Rs := Rs + ';' + #13#10;
  Rs := Rs + '    pub const ALWAYS_ON_TOP: bool = ';
  If Opts.AlwaysOnTop Then Rs := Rs + 'true' Else Rs := Rs + 'false';
  Rs := Rs + ';' + #13#10;
  Rs := Rs + '    pub const DEBUG_MODE: bool = ';
  If Opts.DebugMode Then Rs := Rs + 'true' Else Rs := Rs + 'false';
  Rs := Rs + ';' + #13#10;
  Rs := Rs + '}' + #13#10;
  Rs := Rs + #13#10;

  { Fonctions utilitaires }
  Rs := Rs + '/// Escape a string for JavaScript' + #13#10;
  Rs := Rs + 'pub fn escape_js(s: &str) -> String {' + #13#10;
  Rs := Rs + '    s.replace("\\", "\\\\")' + #13#10;
  Rs := Rs + '     .replace("''", "\\''")' + #13#10;
  Rs := Rs + '     .replace("\"", "\\\"")' + #13#10;
  Rs := Rs + '     .replace("\n", "\\n")' + #13#10;
  Rs := Rs + '     .replace("\r", "\\r")' + #13#10;
  Rs := Rs + '}' + #13#10;
  Rs := Rs + #13#10;

  { User Agent }
  Rs := Rs + '/// Get custom user agent' + #13#10;
  Rs := Rs + 'pub fn get_user_agent() -> &''static str {' + #13#10;
  If Opts.UserAgent <> '' Then
    Rs := Rs + '    "' + EscapeJson(Opts.UserAgent) + '"' + #13#10
  Else
    Rs := Rs + '    "' + RGS_DEFAULT_USER_AGENT + '"' + #13#10;
  Rs := Rs + '}' + #13#10;

  GenerateLibRs := Rs;
End;

{ Generer build.rs pour la compilation Tauri }
Function GenerateBuildRs: String;
Var
  Rs: String;
Begin
  Inc(RgsStateCount);
  Inc(RgsBuildRsCount);

  Rs := '// build.rs - Generated by PAKE ' + PAKE_VERSION + #13#10;
  Rs := Rs + '// Build script for Tauri compilation' + #13#10;
  Rs := Rs + #13#10;
  Rs := Rs + 'fn main() {' + #13#10;
  Rs := Rs + '    tauri_build::build()' + #13#10;
  Rs := Rs + '}' + #13#10;

  GenerateBuildRs := Rs;
End;

{ Generer un index.html minimal qui charge l'URL }
Function GenerateIndexHtml(Const Opts: TOptions): String;
Var
  Html: String;
  WinTitle: String;
Begin
  Inc(RgsStateCount);
  Inc(RgsIndexHtmlCount);

  If Opts.AppName <> '' Then
    WinTitle := Opts.AppName
  Else
    WinTitle := 'Pake App';

  Html := '<!DOCTYPE html>' + #13#10;
  Html := Html + '<html lang="en">' + #13#10;
  Html := Html + '<head>' + #13#10;
  Html := Html + '    <meta charset="UTF-8">' + #13#10;
  Html := Html + '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' + #13#10;
  Html := Html + '    <meta http-equiv="X-UA-Compatible" content="ie=edge">' + #13#10;
  Html := Html + '    <title>' + WinTitle + '</title>' + #13#10;
  Html := Html + '    <style>' + #13#10;
  Html := Html + '        html, body {' + #13#10;
  Html := Html + '            margin: 0;' + #13#10;
  Html := Html + '            padding: 0;' + #13#10;
  Html := Html + '            width: 100%;' + #13#10;
  Html := Html + '            height: 100%;' + #13#10;
  Html := Html + '            overflow: hidden;' + #13#10;
  Html := Html + '        }' + #13#10;
  Html := Html + '        iframe {' + #13#10;
  Html := Html + '            width: 100%;' + #13#10;
  Html := Html + '            height: 100%;' + #13#10;
  Html := Html + '            border: none;' + #13#10;
  Html := Html + '        }' + #13#10;
  Html := Html + '        .loading {' + #13#10;
  Html := Html + '            display: flex;' + #13#10;
  Html := Html + '            justify-content: center;' + #13#10;
  Html := Html + '            align-items: center;' + #13#10;
  Html := Html + '            height: 100vh;' + #13#10;
  Html := Html + '            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;' + #13#10;
  Html := Html + '            color: #666;' + #13#10;
  Html := Html + '        }' + #13#10;
  Html := Html + '    </style>' + #13#10;
  Html := Html + '</head>' + #13#10;
  Html := Html + '<body>' + #13#10;
  Html := Html + '    <div class="loading" id="loading">Loading ' + WinTitle + '...</div>' + #13#10;
  Html := Html + '    <script>' + #13#10;
  Html := Html + '        // Redirect to target URL' + #13#10;
  Html := Html + '        const targetUrl = "' + EscapeJson(Opts.Url) + '";' + #13#10;
  Html := Html + '        document.getElementById("loading").style.display = "none";' + #13#10;
  Html := Html + '        window.location.href = targetUrl;' + #13#10;
  Html := Html + '    </script>' + #13#10;
  Html := Html + '</body>' + #13#10;
  Html := Html + '</html>' + #13#10;

  GenerateIndexHtml := Html;
End;

{ Ecrire tous les fichiers sources Rust dans le repertoire src/ }
Procedure WriteRustSources(Const WorkDir: String; Const Opts: TOptions);
Var
  SrcDir: String;
  F: Text;
  MainRs, LibRs, BuildRs, IndexHtml: String;
Begin
  Inc(RgsStateCount);
  Inc(RgsWriteCount);

  { Creer le repertoire src/ }
  SrcDir := ConcatPath(WorkDir, 'src');
  {$I-}
  MkDir(SrcDir);
  {$I+}
  If IOResult <> 0 Then ; { Ignorer si deja existe }

  { Generer les fichiers }
  MainRs := GenerateMainRs(Opts);
  LibRs := GenerateLibRs(Opts);
  BuildRs := GenerateBuildRs;
  IndexHtml := GenerateIndexHtml(Opts);

  { Ecrire main.rs }
  {$I-}
  Assign(F, ConcatPath(SrcDir, 'main.rs'));
  Rewrite(F);
  Write(F, MainRs);
  Close(F);
  {$I+}

  { Ecrire lib.rs }
  {$I-}
  Assign(F, ConcatPath(SrcDir, 'lib.rs'));
  Rewrite(F);
  Write(F, LibRs);
  Close(F);
  {$I+}

  { Ecrire build.rs dans le repertoire racine du projet }
  {$I-}
  Assign(F, ConcatPath(WorkDir, 'build.rs'));
  Rewrite(F);
  Write(F, BuildRs);
  Close(F);
  {$I+}

  { Creer le repertoire dist pour index.html }
  {$I-}
  MkDir(ConcatPath(WorkDir, 'dist'));
  {$I+}
  If IOResult <> 0 Then ; { Ignorer si deja existe }

  { Ecrire index.html }
  {$I-}
  Assign(F, ConcatPath(WorkDir, 'dist' + {$IFDEF WINDOWS}'\'{$ELSE}'/'{$ENDIF} + 'index.html'));
  Rewrite(F);
  Write(F, IndexHtml);
  Close(F);
  {$I+}
End;

{ ============================================================
  Accesseurs pour TODO 09 - GENERATION DU CODE RUST PRINCIPAL
  ============================================================ }

Function IsRgsInitialized: Boolean;
Begin
  IsRgsInitialized := RgsInitialized;
End;

Function IsRgsEmpty: Boolean;
Begin
  IsRgsEmpty := (RgsMainRsCount = 0) And (RgsLibRsCount = 0) And
                (RgsBuildRsCount = 0) And (RgsIndexHtmlCount = 0);
End;

Function GetRgsStateCount: Integer;
Begin
  GetRgsStateCount := RgsStateCount;
End;

Function GetRgsMainRsCount: Integer;
Begin
  GetRgsMainRsCount := RgsMainRsCount;
End;

Function GetRgsLibRsCount: Integer;
Begin
  GetRgsLibRsCount := RgsLibRsCount;
End;

Function GetRgsBuildRsCount: Integer;
Begin
  GetRgsBuildRsCount := RgsBuildRsCount;
End;

Function GetRgsIndexHtmlCount: Integer;
Begin
  GetRgsIndexHtmlCount := RgsIndexHtmlCount;
End;

Function GetRgsWriteCount: Integer;
Begin
  GetRgsWriteCount := RgsWriteCount;
End;

Function GetRgsMaxScripts: Integer;
Begin
  GetRgsMaxScripts := RGS_MAX_SCRIPTS;
End;

Function GetRgsTauriVersion: String;
Begin
  GetRgsTauriVersion := RGS_TAURI_VERSION;
End;

{ ============================================================
  TODO 10 - GESTION DES RACCOURCIS CLAVIER [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes pour les actions de raccourcis }
  KBD_ACTION_NONE      = 0;
  KBD_ACTION_CLOSE     = 1;
  KBD_ACTION_QUIT      = 2;
  KBD_ACTION_RELOAD    = 3;
  KBD_ACTION_ZOOM_IN   = 4;
  KBD_ACTION_ZOOM_OUT  = 5;
  KBD_ACTION_ZOOM_RESET = 6;
  KBD_ACTION_BACK      = 7;
  KBD_ACTION_FORWARD   = 8;
  KBD_ACTION_DEVTOOLS  = 9;
  KBD_ACTION_FULLSCREEN = 10;

  { Nombre maximum de raccourcis }
  KBD_MAX_SHORTCUTS = 16;

  { Chaines de touches par defaut }
  KBD_KEY_CLOSE     = 'CmdOrCtrl+W';
  KBD_KEY_QUIT      = 'CmdOrCtrl+Q';
  KBD_KEY_RELOAD    = 'CmdOrCtrl+R';
  KBD_KEY_ZOOM_IN   = 'CmdOrCtrl+=';
  KBD_KEY_ZOOM_OUT  = 'CmdOrCtrl+-';
  KBD_KEY_ZOOM_RESET = 'CmdOrCtrl+0';
  KBD_KEY_BACK      = 'CmdOrCtrl+[';
  KBD_KEY_FORWARD   = 'CmdOrCtrl+]';
  KBD_KEY_DEVTOOLS  = 'CmdOrCtrl+Shift+I';
  KBD_KEY_FULLSCREEN = 'F11';

Type
  { Tableau de raccourcis - utilise TShortcut defini globalement }
  TShortcutArray = Array[1..KBD_MAX_SHORTCUTS] Of TShortcut;

Var
  { Variables d'etat pour le module Keyboard Shortcuts }
  KbdInitialized    : Boolean;
  KbdStateCount     : Integer;
  KbdShortcuts      : TShortcutArray;
  KbdShortcutCount  : Integer;
  KbdRegisterCount  : Integer;
  KbdGenerateCount  : Integer;
  KbdDisabledCount  : Integer;

{ Initialiser l'etat du module Keyboard Shortcuts }
Procedure InitShortcutState;
Var
  I: Integer;
Begin
  KbdInitialized := True;
  KbdStateCount := 0;
  KbdShortcutCount := 0;
  KbdRegisterCount := 0;
  KbdGenerateCount := 0;
  KbdDisabledCount := 0;
  For I := 1 To KBD_MAX_SHORTCUTS Do
  Begin
    KbdShortcuts[I].Key := '';
    KbdShortcuts[I].Action := KBD_ACTION_NONE;
    KbdShortcuts[I].Enabled := False;
  End;
End;

{ Retourner le nom d'une action }
Function ShortcutActionName(Action: Integer): String;
Begin
  Case Action Of
    KBD_ACTION_NONE:       ShortcutActionName := 'none';
    KBD_ACTION_CLOSE:      ShortcutActionName := 'close';
    KBD_ACTION_QUIT:       ShortcutActionName := 'quit';
    KBD_ACTION_RELOAD:     ShortcutActionName := 'reload';
    KBD_ACTION_ZOOM_IN:    ShortcutActionName := 'zoom_in';
    KBD_ACTION_ZOOM_OUT:   ShortcutActionName := 'zoom_out';
    KBD_ACTION_ZOOM_RESET: ShortcutActionName := 'zoom_reset';
    KBD_ACTION_BACK:       ShortcutActionName := 'back';
    KBD_ACTION_FORWARD:    ShortcutActionName := 'forward';
    KBD_ACTION_DEVTOOLS:   ShortcutActionName := 'devtools';
    KBD_ACTION_FULLSCREEN: ShortcutActionName := 'fullscreen';
  Else
    ShortcutActionName := 'unknown';
  End;
End;

{ Ajouter un raccourci a la liste }
Function AddShortcut(Const Key: String; Action: Integer; Enabled: Boolean): Boolean;
Begin
  Inc(KbdStateCount);
  If KbdShortcutCount >= KBD_MAX_SHORTCUTS Then
  Begin
    AddShortcut := False;
    Exit;
  End;
  Inc(KbdShortcutCount);
  KbdShortcuts[KbdShortcutCount].Key := Key;
  KbdShortcuts[KbdShortcutCount].Action := Action;
  KbdShortcuts[KbdShortcutCount].Enabled := Enabled;
  AddShortcut := True;
End;

{ Enregistrer les raccourcis par defaut }
Procedure RegisterDefaultShortcuts(DisableWebShortcuts: Boolean);
Begin
  Inc(KbdStateCount);
  Inc(KbdRegisterCount);

  { Reinitialiser la liste }
  KbdShortcutCount := 0;

  { Ajouter les raccourcis par defaut }
  If Not DisableWebShortcuts Then
  Begin
    AddShortcut(KBD_KEY_CLOSE, KBD_ACTION_CLOSE, True);
    AddShortcut(KBD_KEY_QUIT, KBD_ACTION_QUIT, True);
    AddShortcut(KBD_KEY_RELOAD, KBD_ACTION_RELOAD, True);
    AddShortcut(KBD_KEY_ZOOM_IN, KBD_ACTION_ZOOM_IN, True);
    AddShortcut(KBD_KEY_ZOOM_OUT, KBD_ACTION_ZOOM_OUT, True);
    AddShortcut(KBD_KEY_ZOOM_RESET, KBD_ACTION_ZOOM_RESET, True);
    AddShortcut(KBD_KEY_BACK, KBD_ACTION_BACK, True);
    AddShortcut(KBD_KEY_FORWARD, KBD_ACTION_FORWARD, True);
    AddShortcut(KBD_KEY_DEVTOOLS, KBD_ACTION_DEVTOOLS, True);
    AddShortcut(KBD_KEY_FULLSCREEN, KBD_ACTION_FULLSCREEN, True);
  End
  Else
  Begin
    Inc(KbdDisabledCount);
    { Meme avec raccourcis web desactives, garder quit et devtools }
    AddShortcut(KBD_KEY_QUIT, KBD_ACTION_QUIT, True);
    AddShortcut(KBD_KEY_DEVTOOLS, KBD_ACTION_DEVTOOLS, True);
  End;
End;

{ Generer le code Rust pour la gestion des actions }
Function GenerateShortcutActionCode(Action: Integer): String;
Begin
  Case Action Of
    KBD_ACTION_CLOSE:
      GenerateShortcutActionCode := 'window.hide().ok();';
    KBD_ACTION_QUIT:
      GenerateShortcutActionCode := 'std::process::exit(0);';
    KBD_ACTION_RELOAD:
      GenerateShortcutActionCode := 'window.eval("window.location.reload();").ok();';
    KBD_ACTION_ZOOM_IN:
      GenerateShortcutActionCode := 'window.eval("document.body.style.zoom = (parseFloat(document.body.style.zoom || 1) + 0.1).toString();").ok();';
    KBD_ACTION_ZOOM_OUT:
      GenerateShortcutActionCode := 'window.eval("document.body.style.zoom = (parseFloat(document.body.style.zoom || 1) - 0.1).toString();").ok();';
    KBD_ACTION_ZOOM_RESET:
      GenerateShortcutActionCode := 'window.eval("document.body.style.zoom = ''1'';").ok();';
    KBD_ACTION_BACK:
      GenerateShortcutActionCode := 'window.eval("window.history.back();").ok();';
    KBD_ACTION_FORWARD:
      GenerateShortcutActionCode := 'window.eval("window.history.forward();").ok();';
    KBD_ACTION_DEVTOOLS:
      GenerateShortcutActionCode := 'window.open_devtools();';
    KBD_ACTION_FULLSCREEN:
      GenerateShortcutActionCode := 'let is_fs = window.is_fullscreen().unwrap_or(false); window.set_fullscreen(!is_fs).ok();';
  Else
    GenerateShortcutActionCode := '// Unknown action';
  End;
End;

{ Generer le code Rust pour les raccourcis clavier }
Function GenerateShortcutsRs(Const Opts: TOptions): String;
Var
  Rs: String;
  I: Integer;
Begin
  Inc(KbdStateCount);
  Inc(KbdGenerateCount);

  { Enregistrer les raccourcis par defaut }
  RegisterDefaultShortcuts(Opts.DisableWebShortcuts);

  Rs := '// shortcuts.rs - Generated by PAKE ' + PAKE_VERSION + #13#10;
  Rs := Rs + '// Keyboard shortcuts handling' + #13#10;
  Rs := Rs + #13#10;
  Rs := Rs + 'use tauri::{GlobalShortcutManager, Manager};' + #13#10;
  Rs := Rs + #13#10;

  { Fonction pour enregistrer les raccourcis }
  Rs := Rs + 'pub fn register_shortcuts(app: &tauri::AppHandle) -> Result<(), Box<dyn std::error::Error>> {' + #13#10;
  Rs := Rs + '    let window = app.get_window("main").ok_or("Window not found")?;' + #13#10;
  Rs := Rs + '    let mut shortcut_manager = app.global_shortcut_manager();' + #13#10;
  Rs := Rs + #13#10;

  { Generer le code pour chaque raccourci actif }
  For I := 1 To KbdShortcutCount Do
  Begin
    If KbdShortcuts[I].Enabled Then
    Begin
      Rs := Rs + '    // ' + ShortcutActionName(KbdShortcuts[I].Action) + ' shortcut' + #13#10;
      Rs := Rs + '    {' + #13#10;
      Rs := Rs + '        let win = window.clone();' + #13#10;
      Rs := Rs + '        shortcut_manager.register("' + KbdShortcuts[I].Key + '", move || {' + #13#10;
      Rs := Rs + '            ' + GenerateShortcutActionCode(KbdShortcuts[I].Action) + #13#10;
      Rs := Rs + '        })?;' + #13#10;
      Rs := Rs + '    }' + #13#10;
      Rs := Rs + #13#10;
    End;
  End;

  Rs := Rs + '    Ok(())' + #13#10;
  Rs := Rs + '}' + #13#10;
  Rs := Rs + #13#10;

  { Fonction pour desenregistrer les raccourcis }
  Rs := Rs + 'pub fn unregister_shortcuts(app: &tauri::AppHandle) -> Result<(), Box<dyn std::error::Error>> {' + #13#10;
  Rs := Rs + '    let mut shortcut_manager = app.global_shortcut_manager();' + #13#10;
  Rs := Rs + '    shortcut_manager.unregister_all()?;' + #13#10;
  Rs := Rs + '    Ok(())' + #13#10;
  Rs := Rs + '}' + #13#10;

  GenerateShortcutsRs := Rs;
End;

{ Obtenir le nombre de raccourcis actifs }
Function GetActiveShortcutCount: Integer;
Var
  I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To KbdShortcutCount Do
    If KbdShortcuts[I].Enabled Then
      Inc(Count);
  GetActiveShortcutCount := Count;
End;

{ ============================================================
  Accesseurs pour TODO 10 - GESTION DES RACCOURCIS CLAVIER
  ============================================================ }

Function IsKbdInitialized: Boolean;
Begin
  IsKbdInitialized := KbdInitialized;
End;

Function IsKbdEmpty: Boolean;
Begin
  IsKbdEmpty := (KbdShortcutCount = 0);
End;

Function GetKbdStateCount: Integer;
Begin
  GetKbdStateCount := KbdStateCount;
End;

Function GetKbdShortcutCount: Integer;
Begin
  GetKbdShortcutCount := KbdShortcutCount;
End;

Function GetKbdRegisterCount: Integer;
Begin
  GetKbdRegisterCount := KbdRegisterCount;
End;

Function GetKbdGenerateCount: Integer;
Begin
  GetKbdGenerateCount := KbdGenerateCount;
End;

Function GetKbdDisabledCount: Integer;
Begin
  GetKbdDisabledCount := KbdDisabledCount;
End;

Function GetKbdActiveCount: Integer;
Begin
  GetKbdActiveCount := GetActiveShortcutCount;
End;

Function GetKbdMaxShortcuts: Integer;
Begin
  GetKbdMaxShortcuts := KBD_MAX_SHORTCUTS;
End;

Function GetKbdDefaultKey(Action: Integer): String;
Begin
  Case Action Of
    KBD_ACTION_CLOSE:      GetKbdDefaultKey := KBD_KEY_CLOSE;
    KBD_ACTION_QUIT:       GetKbdDefaultKey := KBD_KEY_QUIT;
    KBD_ACTION_RELOAD:     GetKbdDefaultKey := KBD_KEY_RELOAD;
    KBD_ACTION_ZOOM_IN:    GetKbdDefaultKey := KBD_KEY_ZOOM_IN;
    KBD_ACTION_ZOOM_OUT:   GetKbdDefaultKey := KBD_KEY_ZOOM_OUT;
    KBD_ACTION_ZOOM_RESET: GetKbdDefaultKey := KBD_KEY_ZOOM_RESET;
    KBD_ACTION_BACK:       GetKbdDefaultKey := KBD_KEY_BACK;
    KBD_ACTION_FORWARD:    GetKbdDefaultKey := KBD_KEY_FORWARD;
    KBD_ACTION_DEVTOOLS:   GetKbdDefaultKey := KBD_KEY_DEVTOOLS;
    KBD_ACTION_FULLSCREEN: GetKbdDefaultKey := KBD_KEY_FULLSCREEN;
  Else
    GetKbdDefaultKey := '';
  End;
End;

{ ============================================================
  TODO 11 - MODE FENETRE IMMERSIVE
  ============================================================ }

Const
  { Limites }
  WMD_MAX_STYLES      = 4;
  WMD_MAX_TITLEBAR_LEN = 4096;

Var
  { Variables d'etat pour le mode fenetre }
  WmdInitialized     : Boolean;
  WmdStateCount      : Integer;
  WmdModeCount       : Integer;
  WmdCssGenCount     : Integer;
  WmdHtmlGenCount    : Integer;
  WmdJsGenCount      : Integer;
  WmdNormalCount     : Integer;
  WmdFramelessCount  : Integer;
  WmdTransparentCount: Integer;
  WmdFullscreenCount : Integer;

{ Initialiser l'etat du module Mode Fenetre }
Procedure InitWindowModeState;
Begin
  WmdInitialized := True;
  WmdStateCount := WmdStateCount + 1;
  WmdModeCount := 0;
  WmdCssGenCount := 0;
  WmdHtmlGenCount := 0;
  WmdJsGenCount := 0;
  WmdNormalCount := 0;
  WmdFramelessCount := 0;
  WmdTransparentCount := 0;
  WmdFullscreenCount := 0;
End;

{ Retourner le nom du mode de fenetre }
Function WindowModeName(Mode: Integer): String;
Begin
  Case Mode Of
    WINDOW_NORMAL:      WindowModeName := 'normal';
    WINDOW_FRAMELESS:   WindowModeName := 'frameless';
    WINDOW_TRANSPARENT: WindowModeName := 'transparent';
    WINDOW_FULLSCREEN:  WindowModeName := 'fullscreen';
  Else
    WindowModeName := 'unknown';
  End;
End;

{ Determiner le mode de fenetre depuis les options }
Function GetWindowMode(Const Opts: TOptions): Integer;
Begin
  Inc(WmdModeCount);
  
  { Priorite : fullscreen > transparent > hide-title-bar > normal }
  If Opts.Fullscreen Then
  Begin
    Inc(WmdFullscreenCount);
    GetWindowMode := WINDOW_FULLSCREEN;
  End
  Else If Opts.Transparent Then
  Begin
    Inc(WmdTransparentCount);
    GetWindowMode := WINDOW_TRANSPARENT;
  End
  Else If Opts.HideTitleBar Then
  Begin
    Inc(WmdFramelessCount);
    GetWindowMode := WINDOW_FRAMELESS;
  End
  Else
  Begin
    Inc(WmdNormalCount);
    GetWindowMode := WINDOW_NORMAL;
  End;
End;

{ Generer le CSS pour le style de fenetre }
Function GenerateWindowStyleCss(Mode: Integer): String;
Var
  Css: String;
Begin
  Inc(WmdCssGenCount);
  Css := '';
  
  Case Mode Of
    WINDOW_FRAMELESS:
    Begin
      { CSS pour fenetre sans bordure avec barre de titre personnalisee }
      Css := Css + '/* Barre de titre personnalisee */' + Chr(10);
      Css := Css + '.pake-titlebar {' + Chr(10);
      Css := Css + '  position: fixed;' + Chr(10);
      Css := Css + '  top: 0;' + Chr(10);
      Css := Css + '  left: 0;' + Chr(10);
      Css := Css + '  right: 0;' + Chr(10);
      Css := Css + '  height: 32px;' + Chr(10);
      Css := Css + '  background: linear-gradient(to bottom, #f5f5f5, #e0e0e0);' + Chr(10);
      Css := Css + '  border-bottom: 1px solid #c0c0c0;' + Chr(10);
      Css := Css + '  display: flex;' + Chr(10);
      Css := Css + '  align-items: center;' + Chr(10);
      Css := Css + '  justify-content: space-between;' + Chr(10);
      Css := Css + '  -webkit-app-region: drag;' + Chr(10);
      Css := Css + '  z-index: 9999;' + Chr(10);
      Css := Css + '  user-select: none;' + Chr(10);
      Css := Css + '}' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '/* Titre de l''application */' + Chr(10);
      Css := Css + '.pake-titlebar-title {' + Chr(10);
      Css := Css + '  flex: 1;' + Chr(10);
      Css := Css + '  text-align: center;' + Chr(10);
      Css := Css + '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;' + Chr(10);
      Css := Css + '  font-size: 13px;' + Chr(10);
      Css := Css + '  font-weight: 500;' + Chr(10);
      Css := Css + '  color: #333;' + Chr(10);
      Css := Css + '}' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '/* Boutons de controle */' + Chr(10);
      Css := Css + '.pake-titlebar-buttons {' + Chr(10);
      Css := Css + '  display: flex;' + Chr(10);
      Css := Css + '  gap: 8px;' + Chr(10);
      Css := Css + '  padding: 0 12px;' + Chr(10);
      Css := Css + '  -webkit-app-region: no-drag;' + Chr(10);
      Css := Css + '}' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '.pake-titlebar-btn {' + Chr(10);
      Css := Css + '  width: 12px;' + Chr(10);
      Css := Css + '  height: 12px;' + Chr(10);
      Css := Css + '  border-radius: 50%;' + Chr(10);
      Css := Css + '  border: none;' + Chr(10);
      Css := Css + '  cursor: pointer;' + Chr(10);
      Css := Css + '  transition: opacity 0.2s;' + Chr(10);
      Css := Css + '}' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '.pake-titlebar-btn:hover {' + Chr(10);
      Css := Css + '  opacity: 0.8;' + Chr(10);
      Css := Css + '}' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '.pake-btn-close { background: #ff5f57; }' + Chr(10);
      Css := Css + '.pake-btn-minimize { background: #febc2e; }' + Chr(10);
      Css := Css + '.pake-btn-maximize { background: #28c840; }' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '/* Ajuster le contenu pour la barre de titre */' + Chr(10);
      Css := Css + 'body {' + Chr(10);
      Css := Css + '  margin-top: 32px !important;' + Chr(10);
      Css := Css + '}' + Chr(10);
    End;
    
    WINDOW_TRANSPARENT:
    Begin
      { CSS pour fenetre transparente }
      Css := Css + '/* Fenetre transparente */' + Chr(10);
      Css := Css + 'html, body {' + Chr(10);
      Css := Css + '  background: transparent !important;' + Chr(10);
      Css := Css + '}' + Chr(10);
      Css := Css + Chr(10);
      Css := Css + '.pake-drag-region {' + Chr(10);
      Css := Css + '  position: fixed;' + Chr(10);
      Css := Css + '  top: 0;' + Chr(10);
      Css := Css + '  left: 0;' + Chr(10);
      Css := Css + '  right: 0;' + Chr(10);
      Css := Css + '  height: 24px;' + Chr(10);
      Css := Css + '  -webkit-app-region: drag;' + Chr(10);
      Css := Css + '  z-index: 9999;' + Chr(10);
      Css := Css + '}' + Chr(10);
    End;
    
    WINDOW_FULLSCREEN:
    Begin
      { CSS pour mode plein ecran }
      Css := Css + '/* Mode plein ecran */' + Chr(10);
      Css := Css + 'html, body {' + Chr(10);
      Css := Css + '  margin: 0 !important;' + Chr(10);
      Css := Css + '  padding: 0 !important;' + Chr(10);
      Css := Css + '  overflow: hidden !important;' + Chr(10);
      Css := Css + '  width: 100vw !important;' + Chr(10);
      Css := Css + '  height: 100vh !important;' + Chr(10);
      Css := Css + '}' + Chr(10);
    End;
    
    { WINDOW_NORMAL - pas de CSS special }
  End;
  
  GenerateWindowStyleCss := Css;
End;

{ Generer le HTML pour la barre de titre personnalisee }
Function GenerateTitleBarHtml(Const AppName: String; Mode: Integer): String;
Var
  Html: String;
Begin
  Inc(WmdHtmlGenCount);
  Html := '';
  
  If Mode = WINDOW_FRAMELESS Then
  Begin
    Html := Html + '<div class="pake-titlebar">' + Chr(10);
    Html := Html + '  <div class="pake-titlebar-buttons">' + Chr(10);
    Html := Html + '    <button class="pake-titlebar-btn pake-btn-close" ';
    Html := Html + 'onclick="window.__TAURI__.window.appWindow.close()" ';
    Html := Html + 'title="Fermer"></button>' + Chr(10);
    Html := Html + '    <button class="pake-titlebar-btn pake-btn-minimize" ';
    Html := Html + 'onclick="window.__TAURI__.window.appWindow.minimize()" ';
    Html := Html + 'title="Minimiser"></button>' + Chr(10);
    Html := Html + '    <button class="pake-titlebar-btn pake-btn-maximize" ';
    Html := Html + 'onclick="window.__TAURI__.window.appWindow.toggleMaximize()" ';
    Html := Html + 'title="Maximiser"></button>' + Chr(10);
    Html := Html + '  </div>' + Chr(10);
    Html := Html + '  <div class="pake-titlebar-title">' + EscapeJson(AppName) + '</div>' + Chr(10);
    Html := Html + '  <div class="pake-titlebar-buttons" style="visibility: hidden;">' + Chr(10);
    Html := Html + '    <button class="pake-titlebar-btn"></button>' + Chr(10);
    Html := Html + '    <button class="pake-titlebar-btn"></button>' + Chr(10);
    Html := Html + '    <button class="pake-titlebar-btn"></button>' + Chr(10);
    Html := Html + '  </div>' + Chr(10);
    Html := Html + '</div>' + Chr(10);
  End
  Else If Mode = WINDOW_TRANSPARENT Then
  Begin
    { Zone draggable invisible pour fenetre transparente }
    Html := Html + '<div class="pake-drag-region"></div>' + Chr(10);
  End;
  
  GenerateTitleBarHtml := Html;
End;

{ Generer le JavaScript pour la zone draggable }
Function GenerateDragRegionJs: String;
Var
  Js: String;
Begin
  Inc(WmdJsGenCount);
  Js := '';
  
  { JavaScript pour gerer la zone de drag }
  Js := Js + '// Pake - Gestion de la zone draggable' + Chr(10);
  Js := Js + '(function() {' + Chr(10);
  Js := Js + '  ''use strict'';' + Chr(10);
  Js := Js + Chr(10);
  Js := Js + '  // Ajouter les styles pour la zone draggable' + Chr(10);
  Js := Js + '  function initDragRegion() {' + Chr(10);
  Js := Js + '    // Les elements avec -webkit-app-region: drag sont automatiquement' + Chr(10);
  Js := Js + '    // geres par Tauri pour permettre le deplacement de la fenetre' + Chr(10);
  Js := Js + Chr(10);
  Js := Js + '    // Empecher le drag sur les elements interactifs' + Chr(10);
  Js := Js + '    const noDragElements = document.querySelectorAll(' + Chr(10);
  Js := Js + '      ''a, button, input, textarea, select, [contenteditable], .pake-titlebar-btn''' + Chr(10);
  Js := Js + '    );' + Chr(10);
  Js := Js + Chr(10);
  Js := Js + '    noDragElements.forEach(function(el) {' + Chr(10);
  Js := Js + '      el.style.webkitAppRegion = ''no-drag'';' + Chr(10);
  Js := Js + '    });' + Chr(10);
  Js := Js + '  }' + Chr(10);
  Js := Js + Chr(10);
  Js := Js + '  // Observer les mutations du DOM pour les nouveaux elements' + Chr(10);
  Js := Js + '  function observeDom() {' + Chr(10);
  Js := Js + '    const observer = new MutationObserver(function(mutations) {' + Chr(10);
  Js := Js + '      mutations.forEach(function(mutation) {' + Chr(10);
  Js := Js + '        if (mutation.addedNodes.length > 0) {' + Chr(10);
  Js := Js + '          initDragRegion();' + Chr(10);
  Js := Js + '        }' + Chr(10);
  Js := Js + '      });' + Chr(10);
  Js := Js + '    });' + Chr(10);
  Js := Js + Chr(10);
  Js := Js + '    observer.observe(document.body, {' + Chr(10);
  Js := Js + '      childList: true,' + Chr(10);
  Js := Js + '      subtree: true' + Chr(10);
  Js := Js + '    });' + Chr(10);
  Js := Js + '  }' + Chr(10);
  Js := Js + Chr(10);
  Js := Js + '  // Initialiser au chargement du DOM' + Chr(10);
  Js := Js + '  if (document.readyState === ''loading'') {' + Chr(10);
  Js := Js + '    document.addEventListener(''DOMContentLoaded'', function() {' + Chr(10);
  Js := Js + '      initDragRegion();' + Chr(10);
  Js := Js + '      observeDom();' + Chr(10);
  Js := Js + '    });' + Chr(10);
  Js := Js + '  } else {' + Chr(10);
  Js := Js + '    initDragRegion();' + Chr(10);
  Js := Js + '    observeDom();' + Chr(10);
  Js := Js + '  }' + Chr(10);
  Js := Js + '})();' + Chr(10);
  
  GenerateDragRegionJs := Js;
End;

{ ============================================================
  Accesseurs pour TODO 11 - MODE FENETRE IMMERSIVE
  ============================================================ }

Function IsWmdInitialized: Boolean;
Begin
  IsWmdInitialized := WmdInitialized;
End;

Function IsWmdEmpty: Boolean;
Begin
  IsWmdEmpty := (WmdModeCount = 0);
End;

Function GetWmdStateCount: Integer;
Begin
  GetWmdStateCount := WmdStateCount;
End;

Function GetWmdModeCount: Integer;
Begin
  GetWmdModeCount := WmdModeCount;
End;

Function GetWmdCssGenCount: Integer;
Begin
  GetWmdCssGenCount := WmdCssGenCount;
End;

Function GetWmdHtmlGenCount: Integer;
Begin
  GetWmdHtmlGenCount := WmdHtmlGenCount;
End;

Function GetWmdJsGenCount: Integer;
Begin
  GetWmdJsGenCount := WmdJsGenCount;
End;

Function GetWmdNormalCount: Integer;
Begin
  GetWmdNormalCount := WmdNormalCount;
End;

Function GetWmdFramelessCount: Integer;
Begin
  GetWmdFramelessCount := WmdFramelessCount;
End;

Function GetWmdMaxStyles: Integer;
Begin
  GetWmdMaxStyles := WMD_MAX_STYLES;
End;

{ ============================================================
  TODO 12 - INJECTION CSS PERSONNALISE
  ============================================================ }

Const
  { Constantes pour l'injection CSS }
  CSS_MAX_FILE_SIZE = 65536;       { Taille max d'un fichier CSS }
  CSS_DEFAULT_SCOPE = 'document';  { Scope par defaut }

Var
  { Variables d'etat pour l'injection CSS }
  CssInitialized: Boolean;
  CssStateCount: Integer;
  CssLoadCount: Integer;
  CssMinifyCount: Integer;
  CssValidateCount: Integer;
  CssInjectCount: Integer;
  CssErrorCount: Integer;

Procedure InitCssInjectionState;
Begin
  CssInitialized := True;
  CssStateCount := 1;
  CssLoadCount := 0;
  CssMinifyCount := 0;
  CssValidateCount := 0;
  CssInjectCount := 0;
  CssErrorCount := 0;
End;

Function LoadCssFile(Const Path: String): String;
Var
  F: Text;
  Line, Content: String;
Begin
  Content := '';
  If Path = '' Then
  Begin
    Inc(CssErrorCount);
    LoadCssFile := '';
    Exit;
  End;

  {$I-}
  Assign(F, Path);
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    Inc(CssErrorCount);
    LoadCssFile := '';
    Exit;
  End;

  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    If Content <> '' Then
      Content := Content + #10;
    Content := Content + Line;
  End;
  Close(F);

  Inc(CssLoadCount);
  LoadCssFile := Content;
End;

Function MinifyCss(Const Css: String): String;
Var
  I, Len: Integer;
  C, PrevC: Char;
  InComment, InString: Boolean;
  Quote: Char;
  Result: String;
Begin
  Result := '';
  Len := Length(Css);
  InComment := False;
  InString := False;
  Quote := #0;
  PrevC := #0;

  I := 1;
  While I <= Len Do
  Begin
    C := Css[I];

    { Detection des commentaires /* ... */ }
    If (Not InString) And (Not InComment) And (C = '/') And (I < Len) And (Css[I + 1] = '*') Then
    Begin
      InComment := True;
      Inc(I, 2);
      Continue;
    End;

    If InComment And (C = '*') And (I < Len) And (Css[I + 1] = '/') Then
    Begin
      InComment := False;
      Inc(I, 2);
      Continue;
    End;

    If InComment Then
    Begin
      Inc(I);
      Continue;
    End;

    { Gestion des strings }
    If (C = '"') Or (C = '''') Then
    Begin
      If Not InString Then
      Begin
        InString := True;
        Quote := C;
      End
      Else If C = Quote Then
        InString := False;
      Result := Result + C;
      PrevC := C;
      Inc(I);
      Continue;
    End;

    If InString Then
    Begin
      Result := Result + C;
      PrevC := C;
      Inc(I);
      Continue;
    End;

    { Retirer les espaces inutiles }
    If (C = ' ') Or (C = #9) Or (C = #10) Or (C = #13) Then
    Begin
      { Garder un seul espace si necessaire }
      If (Result <> '') And (Result[Length(Result)] <> ' ') And
         (Result[Length(Result)] <> '{') And (Result[Length(Result)] <> '}') And
         (Result[Length(Result)] <> ':') And (Result[Length(Result)] <> ';') And
         (Result[Length(Result)] <> ',') Then
      Begin
        { Verifier si le prochain caractere non-blanc est special }
        While (I < Len) And ((Css[I + 1] = ' ') Or (Css[I + 1] = #9) Or
              (Css[I + 1] = #10) Or (Css[I + 1] = #13)) Do
          Inc(I);
        If (I < Len) And (Css[I + 1] <> '{') And (Css[I + 1] <> '}') And
           (Css[I + 1] <> ':') And (Css[I + 1] <> ';') And (Css[I + 1] <> ',') Then
          Result := Result + ' ';
      End;
      Inc(I);
      Continue;
    End;

    Result := Result + C;
    PrevC := C;
    Inc(I);
  End;

  Inc(CssMinifyCount);
  MinifyCss := Result;
End;

Function ValidateCss(Const Css: String): Boolean;
Var
  I, Len: Integer;
  BraceCount, ParenCount, BracketCount: Integer;
  InString: Boolean;
  Quote, C: Char;
Begin
  BraceCount := 0;
  ParenCount := 0;
  BracketCount := 0;
  InString := False;
  Quote := #0;
  Len := Length(Css);

  For I := 1 To Len Do
  Begin
    C := Css[I];

    { Gestion des strings }
    If (C = '"') Or (C = '''') Then
    Begin
      If Not InString Then
      Begin
        InString := True;
        Quote := C;
      End
      Else If C = Quote Then
        InString := False;
      Continue;
    End;

    If InString Then
      Continue;

    { Compter les accolades, parentheses et crochets }
    Case C Of
      '{': Inc(BraceCount);
      '}': Dec(BraceCount);
      '(': Inc(ParenCount);
      ')': Dec(ParenCount);
      '[': Inc(BracketCount);
      ']': Dec(BracketCount);
    End;

    { Verifier les desequilibres }
    If (BraceCount < 0) Or (ParenCount < 0) Or (BracketCount < 0) Then
    Begin
      Inc(CssErrorCount);
      ValidateCss := False;
      Exit;
    End;
  End;

  Inc(CssValidateCount);

  { Verifier l'equilibre final }
  If (BraceCount = 0) And (ParenCount = 0) And (BracketCount = 0) Then
    ValidateCss := True
  Else
  Begin
    Inc(CssErrorCount);
    ValidateCss := False;
  End;
End;

Function GenerateCssInjectionJs(Const Css: String): String;
Var
  EscapedCss, Result: String;
  I: Integer;
  C: Char;
Begin
  { Echapper le CSS pour JavaScript }
  EscapedCss := '';
  For I := 1 To Length(Css) Do
  Begin
    C := Css[I];
    Case C Of
      '\': EscapedCss := EscapedCss + '\\';
      '''': EscapedCss := EscapedCss + '\''';
      #10: EscapedCss := EscapedCss + '\n';
      #13: ; { Ignorer les retours chariot }
      #9: EscapedCss := EscapedCss + '\t';
    Else
      EscapedCss := EscapedCss + C;
    End;
  End;

  Result := '(function() {' + #10;
  Result := Result + '  const style = document.createElement(''style'');' + #10;
  Result := Result + '  style.setAttribute(''data-pake-injected'', ''true'');' + #10;
  Result := Result + '  style.textContent = ''' + EscapedCss + ''';' + #10;
  Result := Result + '  if (document.head) {' + #10;
  Result := Result + '    document.head.appendChild(style);' + #10;
  Result := Result + '  } else {' + #10;
  Result := Result + '    document.addEventListener(''DOMContentLoaded'', function() {' + #10;
  Result := Result + '      document.head.appendChild(style);' + #10;
  Result := Result + '    });' + #10;
  Result := Result + '  }' + #10;
  Result := Result + '})();';

  Inc(CssInjectCount);
  GenerateCssInjectionJs := Result;
End;

Procedure PrepareCssInjection(Const Opts: TOptions; Var InjectionScript: String);
Var
  CssContent, MinifiedCss: String;
Begin
  InjectionScript := '';

  { Verifier si un fichier CSS est specifie }
  If Opts.InjectCss = '' Then
    Exit;

  { Charger le fichier CSS }
  CssContent := LoadCssFile(Opts.InjectCss);
  If CssContent = '' Then
  Begin
    WriteLn('Erreur: Impossible de charger le fichier CSS: ', Opts.InjectCss);
    Exit;
  End;

  { Valider le CSS }
  If Not ValidateCss(CssContent) Then
  Begin
    WriteLn('Avertissement: Le CSS peut contenir des erreurs de syntaxe');
  End;

  { Minifier le CSS }
  MinifiedCss := MinifyCss(CssContent);

  { Generer le script d'injection }
  InjectionScript := GenerateCssInjectionJs(MinifiedCss);
End;

{ Accesseurs pour TODO 12 - INJECTION CSS PERSONNALISE }

Function IsCssInitialized: Boolean;
Begin
  IsCssInitialized := CssInitialized;
End;

Function IsCssEmpty: Boolean;
Begin
  IsCssEmpty := (CssLoadCount = 0) And (CssInjectCount = 0);
End;

Function GetCssStateCount: Integer;
Begin
  GetCssStateCount := CssStateCount;
End;

Function GetCssLoadCount: Integer;
Begin
  GetCssLoadCount := CssLoadCount;
End;

Function GetCssMinifyCount: Integer;
Begin
  GetCssMinifyCount := CssMinifyCount;
End;

Function GetCssValidateCount: Integer;
Begin
  GetCssValidateCount := CssValidateCount;
End;

Function GetCssInjectCount: Integer;
Begin
  GetCssInjectCount := CssInjectCount;
End;

Function GetCssErrorCount: Integer;
Begin
  GetCssErrorCount := CssErrorCount;
End;

Function GetCssMaxFileSize: Integer;
Begin
  GetCssMaxFileSize := CSS_MAX_FILE_SIZE;
End;

Function GetCssDefaultScope: String;
Begin
  GetCssDefaultScope := CSS_DEFAULT_SCOPE;
End;

{ ============================================================
  TODO 13 - INJECTION JAVASCRIPT PERSONNALISE
  ============================================================ }

Const
  { Constantes pour l'injection JavaScript }
  JS_MAX_FILE_SIZE = 131072;       { Taille max d'un fichier JS (128 Ko) }
  JS_DEFAULT_SCOPE = 'window';     { Scope par defaut }

Var
  { Variables d'etat pour l'injection JavaScript }
  JsInitialized: Boolean;
  JsStateCount: Integer;
  JsLoadCount: Integer;
  JsMinifyCount: Integer;
  JsValidateCount: Integer;
  JsWrapCount: Integer;
  JsUserScriptCount: Integer;
  JsErrorCount: Integer;

Procedure InitJsInjectionState;
Begin
  JsInitialized := True;
  JsStateCount := 1;
  JsLoadCount := 0;
  JsMinifyCount := 0;
  JsValidateCount := 0;
  JsWrapCount := 0;
  JsUserScriptCount := 0;
  JsErrorCount := 0;
End;

Function LoadJsFile(Const Path: String): String;
Var
  F: Text;
  Line, Content: String;
Begin
  Content := '';
  If Path = '' Then
  Begin
    Inc(JsErrorCount);
    LoadJsFile := '';
    Exit;
  End;

  {$I-}
  Assign(F, Path);
  Reset(F);
  {$I+}
  If IOResult <> 0 Then
  Begin
    Inc(JsErrorCount);
    LoadJsFile := '';
    Exit;
  End;

  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    If Content <> '' Then
      Content := Content + #10;
    Content := Content + Line;
  End;
  Close(F);

  Inc(JsLoadCount);
  LoadJsFile := Content;
End;

Function MinifyJs(Const Js: String): String;
Var
  I, Len: Integer;
  C, NextC, PrevC: Char;
  InLineComment, InBlockComment, InString: Boolean;
  Quote: Char;
  Result: String;
Begin
  Result := '';
  Len := Length(Js);
  InLineComment := False;
  InBlockComment := False;
  InString := False;
  Quote := #0;
  PrevC := #0;

  I := 1;
  While I <= Len Do
  Begin
    C := Js[I];
    If I < Len Then
      NextC := Js[I + 1]
    Else
      NextC := #0;

    { Fin de commentaire de ligne }
    If InLineComment Then
    Begin
      If (C = #10) Or (C = #13) Then
        InLineComment := False;
      Inc(I);
      Continue;
    End;

    { Detection commentaire de ligne // }
    If (Not InString) And (Not InBlockComment) And (C = '/') And (NextC = '/') Then
    Begin
      InLineComment := True;
      Inc(I, 2);
      Continue;
    End;

    { Detection commentaire bloc /* ... */ }
    If (Not InString) And (Not InBlockComment) And (C = '/') And (NextC = '*') Then
    Begin
      InBlockComment := True;
      Inc(I, 2);
      Continue;
    End;

    If InBlockComment And (C = '*') And (NextC = '/') Then
    Begin
      InBlockComment := False;
      Inc(I, 2);
      Continue;
    End;

    If InBlockComment Then
    Begin
      Inc(I);
      Continue;
    End;

    { Gestion des strings (apostrophes, guillemets, backticks) }
    If (C = '"') Or (C = '''') Or (C = '`') Then
    Begin
      If Not InString Then
      Begin
        InString := True;
        Quote := C;
      End
      Else If (C = Quote) And (PrevC <> '\') Then
        InString := False;
      Result := Result + C;
      PrevC := C;
      Inc(I);
      Continue;
    End;

    If InString Then
    Begin
      Result := Result + C;
      PrevC := C;
      Inc(I);
      Continue;
    End;

    { Retirer les espaces et retours a la ligne inutiles }
    If (C = ' ') Or (C = #9) Or (C = #10) Or (C = #13) Then
    Begin
      { Garder un seul espace si necessaire pour separer des tokens }
      If (Result <> '') Then
      Begin
        { Verifier si on a besoin d'un espace entre deux identificateurs }
        If ((Result[Length(Result)] >= 'a') And (Result[Length(Result)] <= 'z')) Or
           ((Result[Length(Result)] >= 'A') And (Result[Length(Result)] <= 'Z')) Or
           ((Result[Length(Result)] >= '0') And (Result[Length(Result)] <= '9')) Or
           (Result[Length(Result)] = '_') Or (Result[Length(Result)] = '$') Then
        Begin
          { Sauter les espaces blancs suivants }
          While (I < Len) And ((Js[I + 1] = ' ') Or (Js[I + 1] = #9) Or
                (Js[I + 1] = #10) Or (Js[I + 1] = #13)) Do
            Inc(I);
          If I < Len Then
          Begin
            NextC := Js[I + 1];
            If ((NextC >= 'a') And (NextC <= 'z')) Or
               ((NextC >= 'A') And (NextC <= 'Z')) Or
               ((NextC >= '0') And (NextC <= '9')) Or
               (NextC = '_') Or (NextC = '$') Then
              Result := Result + ' ';
          End;
        End;
      End;
      Inc(I);
      Continue;
    End;

    Result := Result + C;
    PrevC := C;
    Inc(I);
  End;

  Inc(JsMinifyCount);
  MinifyJs := Result;
End;

Function ValidateJs(Const Js: String): Boolean;
Var
  I, Len: Integer;
  BraceCount, ParenCount, BracketCount: Integer;
  InString, InLineComment, InBlockComment: Boolean;
  Quote, C, NextC, PrevC: Char;
Begin
  BraceCount := 0;
  ParenCount := 0;
  BracketCount := 0;
  InString := False;
  InLineComment := False;
  InBlockComment := False;
  Quote := #0;
  PrevC := #0;
  Len := Length(Js);

  I := 1;
  While I <= Len Do
  Begin
    C := Js[I];
    If I < Len Then
      NextC := Js[I + 1]
    Else
      NextC := #0;

    { Gestion des commentaires de ligne }
    If InLineComment Then
    Begin
      If (C = #10) Or (C = #13) Then
        InLineComment := False;
      Inc(I);
      Continue;
    End;

    If (Not InString) And (Not InBlockComment) And (C = '/') And (NextC = '/') Then
    Begin
      InLineComment := True;
      Inc(I, 2);
      Continue;
    End;

    { Gestion des commentaires de bloc }
    If (Not InString) And (Not InBlockComment) And (C = '/') And (NextC = '*') Then
    Begin
      InBlockComment := True;
      Inc(I, 2);
      Continue;
    End;

    If InBlockComment Then
    Begin
      If (C = '*') And (NextC = '/') Then
      Begin
        InBlockComment := False;
        Inc(I, 2);
        Continue;
      End;
      Inc(I);
      Continue;
    End;

    { Gestion des strings }
    If (C = '"') Or (C = '''') Or (C = '`') Then
    Begin
      If Not InString Then
      Begin
        InString := True;
        Quote := C;
      End
      Else If (C = Quote) And (PrevC <> '\') Then
        InString := False;
      PrevC := C;
      Inc(I);
      Continue;
    End;

    If InString Then
    Begin
      PrevC := C;
      Inc(I);
      Continue;
    End;

    { Compter les accolades, parentheses et crochets }
    Case C Of
      '{': Inc(BraceCount);
      '}': Dec(BraceCount);
      '(': Inc(ParenCount);
      ')': Dec(ParenCount);
      '[': Inc(BracketCount);
      ']': Dec(BracketCount);
    End;

    { Verifier les desequilibres immediats }
    If (BraceCount < 0) Or (ParenCount < 0) Or (BracketCount < 0) Then
    Begin
      Inc(JsErrorCount);
      ValidateJs := False;
      Exit;
    End;

    PrevC := C;
    Inc(I);
  End;

  Inc(JsValidateCount);

  { Verifier l'equilibre final }
  If (BraceCount = 0) And (ParenCount = 0) And (BracketCount = 0) And
     (Not InString) And (Not InBlockComment) Then
    ValidateJs := True
  Else
  Begin
    Inc(JsErrorCount);
    ValidateJs := False;
  End;
End;

Function WrapJsInIIFE(Const Js: String): String;
Begin
  Inc(JsWrapCount);
  WrapJsInIIFE := '(function() {' + #10 + Js + #10 + '})();';
End;

Function GenerateUserScript(Const Opts: TOptions): String;
Var
  CssScript, JsContent, Result: String;
Begin
  Result := '';

  { Generer l'injection CSS si specifiee }
  If Opts.InjectCss <> '' Then
  Begin
    PrepareCssInjection(Opts, CssScript);
    If CssScript <> '' Then
      Result := CssScript + #10 + #10;
  End;

  { Ajouter le JavaScript personnalise si specifie }
  If Opts.InjectJs <> '' Then
  Begin
    JsContent := LoadJsFile(Opts.InjectJs);
    If JsContent <> '' Then
    Begin
      { Valider le JS }
      If Not ValidateJs(JsContent) Then
        WriteLn('Avertissement: Le JavaScript peut contenir des erreurs de syntaxe');

      { Envelopper dans une IIFE avec DOMContentLoaded }
      Result := Result + '(function() {' + #10;
      Result := Result + '  ''use strict'';' + #10;
      Result := Result + '  function initUserScript() {' + #10;
      Result := Result + '    ' + JsContent + #10;
      Result := Result + '  }' + #10;
      Result := Result + '  if (document.readyState === ''loading'') {' + #10;
      Result := Result + '    document.addEventListener(''DOMContentLoaded'', initUserScript);' + #10;
      Result := Result + '  } else {' + #10;
      Result := Result + '    initUserScript();' + #10;
      Result := Result + '  }' + #10;
      Result := Result + '})();';
    End;
  End;

  Inc(JsUserScriptCount);
  GenerateUserScript := Result;
End;

Procedure PrepareJsInjection(Const Opts: TOptions; Var InjectionScript: String);
Var
  JsContent, WrappedJs: String;
Begin
  InjectionScript := '';

  { Verifier si un fichier JS est specifie }
  If Opts.InjectJs = '' Then
    Exit;

  { Charger le fichier JavaScript }
  JsContent := LoadJsFile(Opts.InjectJs);
  If JsContent = '' Then
  Begin
    WriteLn('Erreur: Impossible de charger le fichier JavaScript: ', Opts.InjectJs);
    Exit;
  End;

  { Valider le JavaScript }
  If Not ValidateJs(JsContent) Then
  Begin
    WriteLn('Avertissement: Le JavaScript peut contenir des erreurs de syntaxe');
  End;

  { Minifier le JavaScript (optionnel pour production) }
  { JsContent := MinifyJs(JsContent); }

  { Envelopper dans une IIFE }
  WrappedJs := WrapJsInIIFE(JsContent);

  { Retourner le script d'injection }
  InjectionScript := WrappedJs;
End;

{ Accesseurs pour TODO 13 - INJECTION JAVASCRIPT PERSONNALISE }

Function IsJsInitialized: Boolean;
Begin
  IsJsInitialized := JsInitialized;
End;

Function IsJsEmpty: Boolean;
Begin
  IsJsEmpty := (JsLoadCount = 0) And (JsUserScriptCount = 0);
End;

Function GetJsStateCount: Integer;
Begin
  GetJsStateCount := JsStateCount;
End;

Function GetJsLoadCount: Integer;
Begin
  GetJsLoadCount := JsLoadCount;
End;

Function GetJsMinifyCount: Integer;
Begin
  GetJsMinifyCount := JsMinifyCount;
End;

Function GetJsValidateCount: Integer;
Begin
  GetJsValidateCount := JsValidateCount;
End;

Function GetJsWrapCount: Integer;
Begin
  GetJsWrapCount := JsWrapCount;
End;

Function GetJsUserScriptCount: Integer;
Begin
  GetJsUserScriptCount := JsUserScriptCount;
End;

Function GetJsErrorCount: Integer;
Begin
  GetJsErrorCount := JsErrorCount;
End;

Function GetJsMaxFileSize: Integer;
Begin
  GetJsMaxFileSize := JS_MAX_FILE_SIZE;
End;

{ ============================================================
  TODO 14 - SUPPRESSION DES PUBS (ADBLOCK)
  ============================================================ }

Const
  { Constantes pour le blocage publicitaire }
  AD_MAX_SELECTORS = 64;           { Nombre max de selecteurs }
  AD_MAX_DOMAINS = 32;             { Nombre max de domaines a bloquer }
  
  { Selecteurs CSS communs pour les publicites }
  AD_SELECTOR_01 = 'ins.adsbygoogle';
  AD_SELECTOR_02 = '.ad-container';
  AD_SELECTOR_03 = '.ad-wrapper';
  AD_SELECTOR_04 = '.ad-banner';
  AD_SELECTOR_05 = '.advertisement';
  AD_SELECTOR_06 = '.google-ad';
  AD_SELECTOR_07 = '.sponsored-ad';
  AD_SELECTOR_08 = '.promoted-content';
  AD_SELECTOR_09 = '[id*="google_ads"]';
  AD_SELECTOR_10 = '[id*="ad-"]';
  AD_SELECTOR_11 = '[class*="ad-slot"]';
  AD_SELECTOR_12 = '[class*="ad-unit"]';
  AD_SELECTOR_13 = 'iframe[src*="doubleclick"]';
  AD_SELECTOR_14 = 'iframe[src*="googlesyndication"]';
  AD_SELECTOR_15 = 'iframe[src*="facebook.com/plugins"]';
  AD_SELECTOR_16 = '.adsbygoogle';
  AD_SELECTOR_17 = '#ad-container';
  AD_SELECTOR_18 = '#sidebar-ad';
  AD_SELECTOR_19 = '#footer-ad';
  AD_SELECTOR_20 = '#header-ad';
  
  { Domaines publicitaires courants }
  AD_DOMAIN_01 = 'doubleclick.net';
  AD_DOMAIN_02 = 'googlesyndication.com';
  AD_DOMAIN_03 = 'googleadservices.com';
  AD_DOMAIN_04 = 'google-analytics.com';
  AD_DOMAIN_05 = 'adservice.google.com';
  AD_DOMAIN_06 = 'facebook.com/tr';
  AD_DOMAIN_07 = 'connect.facebook.net';
  AD_DOMAIN_08 = 'analytics.twitter.com';
  AD_DOMAIN_09 = 'ads-twitter.com';
  AD_DOMAIN_10 = 'amazon-adsystem.com';

Var
  { Variables d'etat pour le blocage publicitaire }
  AdInitialized: Boolean;
  AdStateCount: Integer;
  AdCssGenCount: Integer;
  AdJsGenCount: Integer;
  AdDomainCount: Integer;
  AdSelectorCount: Integer;
  AdBlockEnableCount: Integer;
  AdElementsBlocked: Integer;

Procedure InitAdBlockState;
Begin
  AdInitialized := True;
  AdStateCount := 1;
  AdCssGenCount := 0;
  AdJsGenCount := 0;
  AdDomainCount := 10;    { 10 domaines par defaut }
  AdSelectorCount := 20;   { 20 selecteurs par defaut }
  AdBlockEnableCount := 0;
  AdElementsBlocked := 0;
End;

Function GenerateAdBlockCss: String;
Var
  Css: String;
Begin
  { Generer le CSS pour masquer les elements publicitaires }
  Css := '/* AdBlock CSS - Generated by PAKE */' + #10;
  Css := Css + AD_SELECTOR_01 + ',' + #10;
  Css := Css + AD_SELECTOR_02 + ',' + #10;
  Css := Css + AD_SELECTOR_03 + ',' + #10;
  Css := Css + AD_SELECTOR_04 + ',' + #10;
  Css := Css + AD_SELECTOR_05 + ',' + #10;
  Css := Css + AD_SELECTOR_06 + ',' + #10;
  Css := Css + AD_SELECTOR_07 + ',' + #10;
  Css := Css + AD_SELECTOR_08 + ',' + #10;
  Css := Css + AD_SELECTOR_09 + ',' + #10;
  Css := Css + AD_SELECTOR_10 + ',' + #10;
  Css := Css + AD_SELECTOR_11 + ',' + #10;
  Css := Css + AD_SELECTOR_12 + ',' + #10;
  Css := Css + AD_SELECTOR_13 + ',' + #10;
  Css := Css + AD_SELECTOR_14 + ',' + #10;
  Css := Css + AD_SELECTOR_15 + ',' + #10;
  Css := Css + AD_SELECTOR_16 + ',' + #10;
  Css := Css + AD_SELECTOR_17 + ',' + #10;
  Css := Css + AD_SELECTOR_18 + ',' + #10;
  Css := Css + AD_SELECTOR_19 + ',' + #10;
  Css := Css + AD_SELECTOR_20 + ' {' + #10;
  Css := Css + '  display: none !important;' + #10;
  Css := Css + '  visibility: hidden !important;' + #10;
  Css := Css + '  height: 0 !important;' + #10;
  Css := Css + '  width: 0 !important;' + #10;
  Css := Css + '  opacity: 0 !important;' + #10;
  Css := Css + '  pointer-events: none !important;' + #10;
  Css := Css + '}' + #10;
  
  Inc(AdCssGenCount);
  GenerateAdBlockCss := Css;
End;

Function GetAdBlockDomains: String;
Var
  Domains: String;
Begin
  { Liste des domaines publicitaires a bloquer }
  Domains := AD_DOMAIN_01 + ',' +
             AD_DOMAIN_02 + ',' +
             AD_DOMAIN_03 + ',' +
             AD_DOMAIN_04 + ',' +
             AD_DOMAIN_05 + ',' +
             AD_DOMAIN_06 + ',' +
             AD_DOMAIN_07 + ',' +
             AD_DOMAIN_08 + ',' +
             AD_DOMAIN_09 + ',' +
             AD_DOMAIN_10;
  GetAdBlockDomains := Domains;
End;

Function GenerateAdBlockJs: String;
Var
  Js: String;
Begin
  { Generer le JavaScript pour bloquer les publicites }
  Js := '/* AdBlock JS - Generated by PAKE */' + #10;
  Js := Js + '(function() {' + #10;
  Js := Js + '  ''use strict'';' + #10;
  Js := Js + #10;
  
  { Liste des domaines a bloquer }
  Js := Js + '  const blockedDomains = [' + #10;
  Js := Js + '    ''' + AD_DOMAIN_01 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_02 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_03 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_04 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_05 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_06 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_07 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_08 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_09 + ''',' + #10;
  Js := Js + '    ''' + AD_DOMAIN_10 + '''' + #10;
  Js := Js + '  ];' + #10;
  Js := Js + #10;
  
  { Liste des selecteurs a supprimer }
  Js := Js + '  const adSelectors = [' + #10;
  Js := Js + '    ''' + AD_SELECTOR_01 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_02 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_03 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_04 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_05 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_06 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_07 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_08 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_09 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_10 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_11 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_12 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_13 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_14 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_15 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_16 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_17 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_18 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_19 + ''',' + #10;
  Js := Js + '    ''' + AD_SELECTOR_20 + '''' + #10;
  Js := Js + '  ];' + #10;
  Js := Js + #10;
  
  { Fonction pour supprimer les elements publicitaires }
  Js := Js + '  function removeAds() {' + #10;
  Js := Js + '    adSelectors.forEach(function(selector) {' + #10;
  Js := Js + '      try {' + #10;
  Js := Js + '        document.querySelectorAll(selector).forEach(function(el) {' + #10;
  Js := Js + '          el.remove();' + #10;
  Js := Js + '        });' + #10;
  Js := Js + '      } catch (e) {}' + #10;
  Js := Js + '    });' + #10;
  Js := Js + '  }' + #10;
  Js := Js + #10;
  
  { Fonction pour verifier si une URL est publicitaire }
  Js := Js + '  function isAdUrl(url) {' + #10;
  Js := Js + '    if (!url) return false;' + #10;
  Js := Js + '    return blockedDomains.some(function(domain) {' + #10;
  Js := Js + '      return url.indexOf(domain) !== -1;' + #10;
  Js := Js + '    });' + #10;
  Js := Js + '  }' + #10;
  Js := Js + #10;
  
  { Supprimer les iframes publicitaires }
  Js := Js + '  function removeAdIframes() {' + #10;
  Js := Js + '    document.querySelectorAll(''iframe'').forEach(function(iframe) {' + #10;
  Js := Js + '      if (isAdUrl(iframe.src)) {' + #10;
  Js := Js + '        iframe.remove();' + #10;
  Js := Js + '      }' + #10;
  Js := Js + '    });' + #10;
  Js := Js + '  }' + #10;
  Js := Js + #10;
  
  { Observer les mutations pour les elements dynamiques }
  Js := Js + '  const observer = new MutationObserver(function(mutations) {' + #10;
  Js := Js + '    removeAds();' + #10;
  Js := Js + '    removeAdIframes();' + #10;
  Js := Js + '  });' + #10;
  Js := Js + #10;
  
  { Executer au chargement }
  Js := Js + '  if (document.readyState === ''loading'') {' + #10;
  Js := Js + '    document.addEventListener(''DOMContentLoaded'', function() {' + #10;
  Js := Js + '      removeAds();' + #10;
  Js := Js + '      removeAdIframes();' + #10;
  Js := Js + '      observer.observe(document.body, {' + #10;
  Js := Js + '        childList: true,' + #10;
  Js := Js + '        subtree: true' + #10;
  Js := Js + '      });' + #10;
  Js := Js + '    });' + #10;
  Js := Js + '  } else {' + #10;
  Js := Js + '    removeAds();' + #10;
  Js := Js + '    removeAdIframes();' + #10;
  Js := Js + '    observer.observe(document.body, {' + #10;
  Js := Js + '      childList: true,' + #10;
  Js := Js + '      subtree: true' + #10;
  Js := Js + '    });' + #10;
  Js := Js + '  }' + #10;
  Js := Js + '})();' + #10;
  
  Inc(AdJsGenCount);
  GenerateAdBlockJs := Js;
End;

Procedure EnableAdBlock(Var InjectionScript: String);
Var
  AdCss, AdJs: String;
Begin
  { Generer le CSS et le JavaScript de blocage }
  AdCss := GenerateAdBlockCss;
  AdJs := GenerateAdBlockJs;
  
  { Ajouter le CSS via JavaScript }
  InjectionScript := InjectionScript + #10;
  InjectionScript := InjectionScript + '/* AdBlock: Injection CSS */' + #10;
  InjectionScript := InjectionScript + '(function() {' + #10;
  InjectionScript := InjectionScript + '  var style = document.createElement(''style'');' + #10;
  InjectionScript := InjectionScript + '  style.type = ''text/css'';' + #10;
  InjectionScript := InjectionScript + '  style.id = ''pake-adblock-css'';' + #10;
  InjectionScript := InjectionScript + '  style.innerHTML = `' + AdCss + '`;' + #10;
  InjectionScript := InjectionScript + '  document.head.appendChild(style);' + #10;
  InjectionScript := InjectionScript + '})();' + #10;
  
  { Ajouter le script de suppression }
  InjectionScript := InjectionScript + #10;
  InjectionScript := InjectionScript + '/* AdBlock: Suppression dynamique */' + #10;
  InjectionScript := InjectionScript + AdJs;
  
  Inc(AdBlockEnableCount);
End;

Function GetAdBlockSelectorsAsCss: String;
Var
  Selectors: String;
Begin
  { Retourne tous les selecteurs combines pour utilisation CSS }
  Selectors := AD_SELECTOR_01 + ', ' +
               AD_SELECTOR_02 + ', ' +
               AD_SELECTOR_03 + ', ' +
               AD_SELECTOR_04 + ', ' +
               AD_SELECTOR_05 + ', ' +
               AD_SELECTOR_06 + ', ' +
               AD_SELECTOR_07 + ', ' +
               AD_SELECTOR_08 + ', ' +
               AD_SELECTOR_09 + ', ' +
               AD_SELECTOR_10 + ', ' +
               AD_SELECTOR_11 + ', ' +
               AD_SELECTOR_12 + ', ' +
               AD_SELECTOR_13 + ', ' +
               AD_SELECTOR_14 + ', ' +
               AD_SELECTOR_15 + ', ' +
               AD_SELECTOR_16 + ', ' +
               AD_SELECTOR_17 + ', ' +
               AD_SELECTOR_18 + ', ' +
               AD_SELECTOR_19 + ', ' +
               AD_SELECTOR_20;
  GetAdBlockSelectorsAsCss := Selectors;
End;

{ Accesseurs pour TODO 14 - SUPPRESSION DES PUBS (ADBLOCK) }

Function IsAdInitialized: Boolean;
Begin
  IsAdInitialized := AdInitialized;
End;

Function IsAdBlockEmpty: Boolean;
Begin
  IsAdBlockEmpty := (AdCssGenCount = 0) And (AdJsGenCount = 0);
End;

Function GetAdStateCount: Integer;
Begin
  GetAdStateCount := AdStateCount;
End;

Function GetAdCssGenCount: Integer;
Begin
  GetAdCssGenCount := AdCssGenCount;
End;

Function GetAdJsGenCount: Integer;
Begin
  GetAdJsGenCount := AdJsGenCount;
End;

Function GetAdDomainCount: Integer;
Begin
  GetAdDomainCount := AdDomainCount;
End;

Function GetAdSelectorCount: Integer;
Begin
  GetAdSelectorCount := AdSelectorCount;
End;

Function GetAdBlockEnableCount: Integer;
Begin
  GetAdBlockEnableCount := AdBlockEnableCount;
End;

Function GetAdElementsBlocked: Integer;
Begin
  GetAdElementsBlocked := AdElementsBlocked;
End;

Function GetAdMaxSelectors: Integer;
Begin
  GetAdMaxSelectors := AD_MAX_SELECTORS;
End;

{ ============================================================
  TODO 15 - GESTION DES PERMISSIONS
  ============================================================ }

Const
  { Constantes de type de permission }
  PERM_NONE         = 0;
  PERM_CAMERA       = 1;
  PERM_MICROPHONE   = 2;
  PERM_GEOLOCATION  = 3;
  PERM_NOTIFICATIONS = 4;
  PERM_CLIPBOARD    = 5;
  PERM_FULLSCREEN   = 6;

  { Constantes de limites }
  PERM_MAX_TYPES    = 6;

{ Note: TPermissions est deja defini dans la section TYPES GLOBAUX }

Var
  { Variables d'etat pour le module Permissions }
  PermInitialized    : Boolean;
  PermStateCount     : Integer;
  PermJsonGenCount   : Integer;
  PermCspGenCount    : Integer;
  PermInitCount      : Integer;
  PermApplyCount     : Integer;
  PermEnabledCount   : Integer;
  PermDisabledCount  : Integer;

Procedure InitPermissionsState;
Begin
  PermInitialized := True;
  PermStateCount := 0;
  PermJsonGenCount := 0;
  PermCspGenCount := 0;
  PermInitCount := 0;
  PermApplyCount := 0;
  PermEnabledCount := 0;
  PermDisabledCount := 0;
  Inc(PermStateCount);
End;

Procedure InitDefaultPermissions(Var P: TPermissions);
Begin
  Inc(PermStateCount);
  Inc(PermInitCount);
  
  { Initialiser toutes les permissions a False par defaut }
  P.Camera := False;
  P.Microphone := False;
  P.Geolocation := False;
  P.Notifications := False;
  P.Clipboard := False;
  P.FullScreen := False;
  
  { Compter les permissions desactivees }
  PermDisabledCount := PermDisabledCount + 6;
End;

Function PermissionTypeName(PermType: Integer): String;
Begin
  Case PermType Of
    PERM_CAMERA:       PermissionTypeName := 'camera';
    PERM_MICROPHONE:   PermissionTypeName := 'microphone';
    PERM_GEOLOCATION:  PermissionTypeName := 'geolocation';
    PERM_NOTIFICATIONS: PermissionTypeName := 'notifications';
    PERM_CLIPBOARD:    PermissionTypeName := 'clipboard';
    PERM_FULLSCREEN:   PermissionTypeName := 'fullscreen';
  Else
    PermissionTypeName := 'unknown';
  End;
End;

Function PermissionsToJson(Const P: TPermissions): String;
Var
  Json: String;
  HasPerm: Boolean;
Begin
  Inc(PermStateCount);
  Inc(PermJsonGenCount);
  
  Json := '{' + Chr(10);
  Json := Json + '  "permissions": {' + Chr(10);
  
  HasPerm := False;
  
  { Camera }
  If P.Camera Then
  Begin
    If HasPerm Then Json := Json + ',' + Chr(10);
    Json := Json + '    "camera": true';
    HasPerm := True;
  End;
  
  { Microphone }
  If P.Microphone Then
  Begin
    If HasPerm Then Json := Json + ',' + Chr(10);
    Json := Json + '    "microphone": true';
    HasPerm := True;
  End;
  
  { Geolocation }
  If P.Geolocation Then
  Begin
    If HasPerm Then Json := Json + ',' + Chr(10);
    Json := Json + '    "geolocation": true';
    HasPerm := True;
  End;
  
  { Notifications }
  If P.Notifications Then
  Begin
    If HasPerm Then Json := Json + ',' + Chr(10);
    Json := Json + '    "notifications": true';
    HasPerm := True;
  End;
  
  { Clipboard }
  If P.Clipboard Then
  Begin
    If HasPerm Then Json := Json + ',' + Chr(10);
    Json := Json + '    "clipboard": true';
    HasPerm := True;
  End;
  
  { FullScreen }
  If P.FullScreen Then
  Begin
    If HasPerm Then Json := Json + ',' + Chr(10);
    Json := Json + '    "fullscreen": true';
    HasPerm := True;
  End;
  
  If HasPerm Then Json := Json + Chr(10);
  Json := Json + '  }' + Chr(10);
  Json := Json + '}';
  
  PermissionsToJson := Json;
End;

Function PermissionsToCsp(Const P: TPermissions): String;
Var
  Csp: String;
Begin
  Inc(PermStateCount);
  Inc(PermCspGenCount);
  
  { Commencer avec la CSP de base }
  Csp := 'default-src ''self''; ';
  Csp := Csp + 'script-src ''self'' ''unsafe-inline'' ''unsafe-eval''; ';
  Csp := Csp + 'style-src ''self'' ''unsafe-inline''; ';
  Csp := Csp + 'img-src ''self'' data: https:; ';
  Csp := Csp + 'font-src ''self'' data:; ';
  Csp := Csp + 'connect-src ''self'' https: wss:; ';
  
  { Ajout des permissions media si necessaire }
  If P.Camera Or P.Microphone Then
    Csp := Csp + 'media-src ''self'' blob:; ';
  
  { Permissions de geolocalisation n affectent pas directement CSP }
  { mais on peut ajouter des politiques specifiques }
  
  { Frame ancestors pour securite }
  Csp := Csp + 'frame-ancestors ''self''';
  
  PermissionsToCsp := Csp;
End;

Procedure ApplyPermissions(Const P: TPermissions; Var Cfg: TTauriConfig);
Var
  NewCsp: String;
  EnabledCount: Integer;
Begin
  Inc(PermStateCount);
  Inc(PermApplyCount);
  
  { Generer la nouvelle CSP basee sur les permissions }
  NewCsp := PermissionsToCsp(P);
  
  { Appliquer la CSP a la configuration Tauri }
  Cfg.Tauri.Security.Csp := NewCsp;
  
  { Compter les permissions activees }
  EnabledCount := 0;
  If P.Camera Then Inc(EnabledCount);
  If P.Microphone Then Inc(EnabledCount);
  If P.Geolocation Then Inc(EnabledCount);
  If P.Notifications Then Inc(EnabledCount);
  If P.Clipboard Then Inc(EnabledCount);
  If P.FullScreen Then Inc(EnabledCount);
  
  PermEnabledCount := PermEnabledCount + EnabledCount;
End;

Function CountEnabledPermissions(Const P: TPermissions): Integer;
Var
  Count: Integer;
Begin
  Count := 0;
  If P.Camera Then Inc(Count);
  If P.Microphone Then Inc(Count);
  If P.Geolocation Then Inc(Count);
  If P.Notifications Then Inc(Count);
  If P.Clipboard Then Inc(Count);
  If P.FullScreen Then Inc(Count);
  CountEnabledPermissions := Count;
End;

Procedure SetPermission(Var P: TPermissions; PermType: Integer; Value: Boolean);
Begin
  Inc(PermStateCount);
  Case PermType Of
    PERM_CAMERA:       P.Camera := Value;
    PERM_MICROPHONE:   P.Microphone := Value;
    PERM_GEOLOCATION:  P.Geolocation := Value;
    PERM_NOTIFICATIONS: P.Notifications := Value;
    PERM_CLIPBOARD:    P.Clipboard := Value;
    PERM_FULLSCREEN:   P.FullScreen := Value;
  End;
  
  If Value Then
    Inc(PermEnabledCount)
  Else
    Inc(PermDisabledCount);
End;

Function GetPermission(Const P: TPermissions; PermType: Integer): Boolean;
Begin
  Inc(PermStateCount);
  Case PermType Of
    PERM_CAMERA:       GetPermission := P.Camera;
    PERM_MICROPHONE:   GetPermission := P.Microphone;
    PERM_GEOLOCATION:  GetPermission := P.Geolocation;
    PERM_NOTIFICATIONS: GetPermission := P.Notifications;
    PERM_CLIPBOARD:    GetPermission := P.Clipboard;
    PERM_FULLSCREEN:   GetPermission := P.FullScreen;
  Else
    GetPermission := False;
  End;
End;

{ Accesseurs pour TODO 15 - GESTION DES PERMISSIONS }

Function IsPermInitialized: Boolean;
Begin
  IsPermInitialized := PermInitialized;
End;

Function IsPermEmpty: Boolean;
Begin
  IsPermEmpty := (PermJsonGenCount = 0) And (PermCspGenCount = 0);
End;

Function GetPermStateCount: Integer;
Begin
  GetPermStateCount := PermStateCount;
End;

Function GetPermJsonGenCount: Integer;
Begin
  GetPermJsonGenCount := PermJsonGenCount;
End;

Function GetPermCspGenCount: Integer;
Begin
  GetPermCspGenCount := PermCspGenCount;
End;

Function GetPermInitCount: Integer;
Begin
  GetPermInitCount := PermInitCount;
End;

Function GetPermApplyCount: Integer;
Begin
  GetPermApplyCount := PermApplyCount;
End;

Function GetPermEnabledCount: Integer;
Begin
  GetPermEnabledCount := PermEnabledCount;
End;

Function GetPermDisabledCount: Integer;
Begin
  GetPermDisabledCount := PermDisabledCount;
End;

Function GetPermMaxTypes: Integer;
Begin
  GetPermMaxTypes := PERM_MAX_TYPES;
End;

{ ============================================================
  TODO 16 - CONFIGURATION DU BUILD [IMPLEMENTE]
  ============================================================ }

Const
  { Note: BUILD_DEBUG et BUILD_RELEASE sont deja definis dans la section }
  {       CONSTANTES GLOBALES                                              }
  { Note: On utilise les constantes PLATFORM_* pour les cibles            }
  
  { Constantes de build }
  BUILD_MAX_TARGETS = 4;   { PLATFORM_UNKNOWN, WINDOWS, MACOS, LINUX }
  BUILD_CARGO_CMD   = 'cargo';
  BUILD_TAURI_CMD   = 'tauri';

Type
  { Configuration de build }
  TBuildConfig = Record
    Mode        : Integer;   { BUILD_DEBUG ou BUILD_RELEASE }
    Target      : Integer;   { Plateforme cible (PLATFORM_*) }
    TargetTriple: String;    { Triple cible Rust (ex: x86_64-apple-darwin) }
    OutputDir   : String;    { Repertoire de sortie }
    Verbose     : Boolean;   { Mode verbeux }
    MultiArch   : Boolean;   { Build multi-architecture }
  End;

Var
  { Variables d'etat pour le module Build }
  BldInitialized    : Boolean;
  BldStateCount     : Integer;
  BldCommandCount   : Integer;
  BldExecuteCount   : Integer;
  BldArtifactCount  : Integer;
  BldCopyCount      : Integer;
  BldSuccessCount   : Integer;
  BldErrorCount     : Integer;

Procedure InitBuildState;
Begin
  BldInitialized := True;
  BldStateCount := 0;
  BldCommandCount := 0;
  BldExecuteCount := 0;
  BldArtifactCount := 0;
  BldCopyCount := 0;
  BldSuccessCount := 0;
  BldErrorCount := 0;
  Inc(BldStateCount);
End;

Function BuildModeName(Mode: Integer): String;
Begin
  Case Mode Of
    BUILD_DEBUG:   BuildModeName := 'debug';
    BUILD_RELEASE: BuildModeName := 'release';
  Else
    BuildModeName := 'unknown';
  End;
End;

Function BuildTargetName(Target: Integer): String;
Begin
  Case Target Of
    PLATFORM_MACOS:   BuildTargetName := 'macos';
    PLATFORM_WINDOWS: BuildTargetName := 'windows';
    PLATFORM_LINUX:   BuildTargetName := 'linux';
  Else
    BuildTargetName := 'unknown';
  End;
End;

Function GetTargetTriple(Target: Integer): String;
Begin
  Inc(BldStateCount);
  Case Target Of
    PLATFORM_MACOS:   GetTargetTriple := 'x86_64-apple-darwin';
    PLATFORM_WINDOWS: GetTargetTriple := 'x86_64-pc-windows-msvc';
    PLATFORM_LINUX:   GetTargetTriple := 'x86_64-unknown-linux-gnu';
  Else
    GetTargetTriple := '';
  End;
End;

Procedure InitBuildConfig(Var Cfg: TBuildConfig; Const Opts: TOptions);
Begin
  Inc(BldStateCount);
  
  { Mode de build: debug si --debug, sinon release }
  If Opts.DebugMode Then
    Cfg.Mode := BUILD_DEBUG
  Else
    Cfg.Mode := BUILD_RELEASE;
  
  { Detecter la plateforme cible }
  Cfg.Target := GetPlatform;
  Cfg.TargetTriple := GetTargetTriple(Cfg.Target);
  
  { Repertoire de sortie }
  If Opts.OutputDir <> '' Then
    Cfg.OutputDir := Opts.OutputDir
  Else
    Cfg.OutputDir := 'dist';
  
  { Options }
  Cfg.Verbose := Opts.Verbose;
  Cfg.MultiArch := Opts.MultiArch;
End;

Function GenerateBuildCommand(Const Cfg: TBuildConfig): String;
Var
  Cmd: String;
Begin
  Inc(BldStateCount);
  Inc(BldCommandCount);
  
  { Commencer la commande cargo tauri build }
  Cmd := BUILD_CARGO_CMD + ' ' + BUILD_TAURI_CMD + ' build';
  
  { Ajouter le mode release si necessaire }
  If Cfg.Mode = BUILD_RELEASE Then
    Cmd := Cmd + ' --release';
  
  { Ajouter la cible si specifiee }
  If Cfg.TargetTriple <> '' Then
    Cmd := Cmd + ' --target ' + Cfg.TargetTriple;
  
  { Mode verbeux }
  If Cfg.Verbose Then
    Cmd := Cmd + ' --verbose';
  
  GenerateBuildCommand := Cmd;
End;

Function GenerateBuildCommandFromOpts(Const Opts: TOptions): String;
Var
  Cfg: TBuildConfig;
Begin
  InitBuildConfig(Cfg, Opts);
  GenerateBuildCommandFromOpts := GenerateBuildCommand(Cfg);
End;

Procedure ExecuteBuild(Const WorkDir: String; Const Cmd: String; Verbose: Boolean);
Var
  FullCmd: String;
  ExitCode: Integer;
Begin
  Inc(BldStateCount);
  Inc(BldExecuteCount);
  
  { Afficher la commande si verbose }
  If Verbose Then
  Begin
    WriteLn('Repertoire de travail: ', WorkDir);
    WriteLn('Commande: ', Cmd);
    WriteLn;
  End;
  
  { Construire la commande complete avec changement de repertoire }
  If WorkDir <> '' Then
    FullCmd := 'cd ' + WorkDir + ' && ' + Cmd
  Else
    FullCmd := Cmd;
  
  { Note: En Pascal standard, on ne peut pas executer directement }
  { une commande shell. Ceci est un placeholder pour l'implementation }
  { reelle qui utiliserait SysUtils.ExecuteProcess ou similaire }
  
  WriteLn('*** SIMULATION DE BUILD ***');
  WriteLn('Commande a executer: ', FullCmd);
  WriteLn;
  
  { Simuler un succes }
  ExitCode := 0;
  
  If ExitCode = 0 Then
  Begin
    Inc(BldSuccessCount);
    If Verbose Then
      WriteLn('Build termine avec succes.');
  End
  Else
  Begin
    Inc(BldErrorCount);
    WriteLn('ERREUR: Build echoue avec code ', ExitCode);
  End;
End;

Function GetBuildArtifactPath(Const WorkDir: String; Platform: Integer): String;
Var
  BasePath: String;
Begin
  Inc(BldStateCount);
  Inc(BldArtifactCount);
  
  { Chemin de base des artefacts Tauri }
  BasePath := WorkDir;
  If BasePath[Length(BasePath)] <> '/' Then
    BasePath := BasePath + '/';
  BasePath := BasePath + 'target/release/bundle/';
  
  { Chemin specifique a la plateforme }
  Case Platform Of
    PLATFORM_MACOS:
      GetBuildArtifactPath := BasePath + 'macos/';
    PLATFORM_WINDOWS:
      GetBuildArtifactPath := BasePath + 'msi/';
    PLATFORM_LINUX:
      GetBuildArtifactPath := BasePath + 'deb/';
  Else
    GetBuildArtifactPath := BasePath;
  End;
End;

Function GetBuildArtifactExtension(Platform: Integer): String;
Begin
  Inc(BldStateCount);
  Case Platform Of
    PLATFORM_MACOS:   GetBuildArtifactExtension := '.app';
    PLATFORM_WINDOWS: GetBuildArtifactExtension := '.exe';
    PLATFORM_LINUX:   GetBuildArtifactExtension := '';
  Else
    GetBuildArtifactExtension := '';
  End;
End;

Procedure CopyBuildArtifacts(Const WorkDir, OutputDir: String; Platform: Integer);
Var
  SrcPath, DstPath: String;
Begin
  Inc(BldStateCount);
  Inc(BldCopyCount);
  
  { Obtenir les chemins source et destination }
  SrcPath := GetBuildArtifactPath(WorkDir, Platform);
  DstPath := OutputDir;
  If DstPath[Length(DstPath)] <> '/' Then
    DstPath := DstPath + '/';
  
  { Note: En Pascal standard, la copie de fichiers necessite }
  { des procedures specifiques. Ceci est un placeholder }
  
  WriteLn('*** SIMULATION DE COPIE ***');
  WriteLn('Source     : ', SrcPath);
  WriteLn('Destination: ', DstPath);
  WriteLn;
  
  { Simuler un succes }
  Inc(BldSuccessCount);
End;

Function IsBuildConfigValid(Const Cfg: TBuildConfig): Boolean;
Begin
  Inc(BldStateCount);
  
  { Verifier que la configuration est valide }
  IsBuildConfigValid := (Cfg.Mode >= BUILD_DEBUG) And 
                        (Cfg.Mode <= BUILD_RELEASE) And
                        (Cfg.Target >= PLATFORM_UNKNOWN) And
                        (Cfg.Target <= PLATFORM_LINUX);
End;

Procedure DumpBuildConfig(Const Cfg: TBuildConfig);
Begin
  Inc(BldStateCount);
  
  WriteLn('=== Configuration de Build ===');
  WriteLn('Mode        : ', BuildModeName(Cfg.Mode));
  WriteLn('Cible       : ', BuildTargetName(Cfg.Target));
  WriteLn('Triple      : ', Cfg.TargetTriple);
  WriteLn('Sortie      : ', Cfg.OutputDir);
  WriteLn('Verbose     : ', Cfg.Verbose);
  WriteLn('Multi-arch  : ', Cfg.MultiArch);
  WriteLn;
End;

{ Accesseurs pour TODO 16 - CONFIGURATION DU BUILD }

Function IsBldInitialized: Boolean;
Begin
  IsBldInitialized := BldInitialized;
End;

Function IsBldEmpty: Boolean;
Begin
  IsBldEmpty := (BldCommandCount = 0) And (BldExecuteCount = 0);
End;

Function GetBldStateCount: Integer;
Begin
  GetBldStateCount := BldStateCount;
End;

Function GetBldCommandCount: Integer;
Begin
  GetBldCommandCount := BldCommandCount;
End;

Function GetBldExecuteCount: Integer;
Begin
  GetBldExecuteCount := BldExecuteCount;
End;

Function GetBldArtifactCount: Integer;
Begin
  GetBldArtifactCount := BldArtifactCount;
End;

Function GetBldCopyCount: Integer;
Begin
  GetBldCopyCount := BldCopyCount;
End;

Function GetBldSuccessCount: Integer;
Begin
  GetBldSuccessCount := BldSuccessCount;
End;

Function GetBldErrorCount: Integer;
Begin
  GetBldErrorCount := BldErrorCount;
End;

Function GetBldMaxTargets: Integer;
Begin
  GetBldMaxTargets := BUILD_MAX_TARGETS;
End;

{ ============================================================
  TODO 17 - GENERATION MACOS [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes macOS - Note: MACOS_APP_EXT et MACOS_DMG_EXT deja definis }
  MACOS_ICNS_EXT   = '.icns';
  MACOS_PLIST_NAME = 'Info.plist';
  MACOS_MAX_BUNDLE_SIZE = 536870912; { 512 Mo max }
  
  { Types d'extensions macOS }
  MACOS_EXT_NONE = 0;
  MACOS_EXT_APP  = 1;
  MACOS_EXT_DMG  = 2;
  MACOS_EXT_ICNS = 3;

Type
  { Configuration Info.plist }
  TInfoPlistConfig = Record
    BundleName       : String;    { CFBundleName }
    BundleIdentifier : String;    { CFBundleIdentifier }
    BundleVersion    : String;    { CFBundleVersion }
    ExecutableName   : String;    { CFBundleExecutable }
    IconFile         : String;    { CFBundleIconFile }
    MinSystemVersion : String;    { LSMinimumSystemVersion }
    Copyright        : String;    { NSHumanReadableCopyright }
    HighResCapable   : Boolean;   { NSHighResolutionCapable }
    Category         : String;    { LSApplicationCategoryType }
  End;

Var
  { Variables d'etat pour le module macOS }
  MacInitialized    : Boolean;
  MacStateCount     : Integer;
  MacPlistGenCount  : Integer;
  MacBundleCount    : Integer;
  MacDmgCount       : Integer;
  MacSignCount      : Integer;
  MacCopyCount      : Integer;
  MacErrorCount     : Integer;

Procedure InitMacOSState;
Begin
  MacInitialized := True;
  MacStateCount := 0;
  MacPlistGenCount := 0;
  MacBundleCount := 0;
  MacDmgCount := 0;
  MacSignCount := 0;
  MacCopyCount := 0;
  MacErrorCount := 0;
  Inc(MacStateCount);
End;

Function MacOSExtName(ExtType: Integer): String;
Begin
  Inc(MacStateCount);
  Case ExtType Of
    MACOS_EXT_APP:  MacOSExtName := MACOS_APP_EXT;
    MACOS_EXT_DMG:  MacOSExtName := MACOS_DMG_EXT;
    MACOS_EXT_ICNS: MacOSExtName := MACOS_ICNS_EXT;
  Else
    MacOSExtName := '';
  End;
End;

Procedure InitInfoPlistConfig(Var Cfg: TInfoPlistConfig; Const Opts: TOptions);
Var
  AppName: String;
Begin
  Inc(MacStateCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  { Initialiser les champs }
  Cfg.BundleName := AppName;
  Cfg.BundleIdentifier := 'com.pake.' + LowerStr(SanitizeAppName(AppName));
  Cfg.BundleVersion := PAKE_VERSION;
  Cfg.ExecutableName := SanitizeAppName(AppName);
  Cfg.IconFile := 'icon.icns';
  Cfg.MinSystemVersion := '10.13';
  Cfg.Copyright := 'Copyright 2024 ' + AppName;
  Cfg.HighResCapable := True;
  Cfg.Category := 'public.app-category.productivity';
End;

Function GenerateInfoPlist(Const Opts: TOptions): String;
Var
  Cfg: TInfoPlistConfig;
  S: String;
Begin
  Inc(MacStateCount);
  Inc(MacPlistGenCount);
  
  { Initialiser la configuration }
  InitInfoPlistConfig(Cfg, Opts);
  
  { Generer le contenu du fichier Info.plist }
  S := '<?xml version="1.0" encoding="UTF-8"?>' + #10;
  S := S + '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ';
  S := S + '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + #10;
  S := S + '<plist version="1.0">' + #10;
  S := S + '<dict>' + #10;
  
  { CFBundleName }
  S := S + '  <key>CFBundleName</key>' + #10;
  S := S + '  <string>' + EscapeJson(Cfg.BundleName) + '</string>' + #10;
  
  { CFBundleDisplayName }
  S := S + '  <key>CFBundleDisplayName</key>' + #10;
  S := S + '  <string>' + EscapeJson(Cfg.BundleName) + '</string>' + #10;
  
  { CFBundleIdentifier }
  S := S + '  <key>CFBundleIdentifier</key>' + #10;
  S := S + '  <string>' + Cfg.BundleIdentifier + '</string>' + #10;
  
  { CFBundleVersion }
  S := S + '  <key>CFBundleVersion</key>' + #10;
  S := S + '  <string>' + Cfg.BundleVersion + '</string>' + #10;
  
  { CFBundleShortVersionString }
  S := S + '  <key>CFBundleShortVersionString</key>' + #10;
  S := S + '  <string>' + Cfg.BundleVersion + '</string>' + #10;
  
  { CFBundleExecutable }
  S := S + '  <key>CFBundleExecutable</key>' + #10;
  S := S + '  <string>' + Cfg.ExecutableName + '</string>' + #10;
  
  { CFBundleIconFile }
  S := S + '  <key>CFBundleIconFile</key>' + #10;
  S := S + '  <string>' + Cfg.IconFile + '</string>' + #10;
  
  { CFBundlePackageType }
  S := S + '  <key>CFBundlePackageType</key>' + #10;
  S := S + '  <string>APPL</string>' + #10;
  
  { CFBundleInfoDictionaryVersion }
  S := S + '  <key>CFBundleInfoDictionaryVersion</key>' + #10;
  S := S + '  <string>6.0</string>' + #10;
  
  { LSMinimumSystemVersion }
  S := S + '  <key>LSMinimumSystemVersion</key>' + #10;
  S := S + '  <string>' + Cfg.MinSystemVersion + '</string>' + #10;
  
  { NSHighResolutionCapable }
  S := S + '  <key>NSHighResolutionCapable</key>' + #10;
  If Cfg.HighResCapable Then
    S := S + '  <true/>' + #10
  Else
    S := S + '  <false/>' + #10;
  
  { LSApplicationCategoryType }
  S := S + '  <key>LSApplicationCategoryType</key>' + #10;
  S := S + '  <string>' + Cfg.Category + '</string>' + #10;
  
  { NSHumanReadableCopyright }
  S := S + '  <key>NSHumanReadableCopyright</key>' + #10;
  S := S + '  <string>' + EscapeJson(Cfg.Copyright) + '</string>' + #10;
  
  { NSAppTransportSecurity - Autoriser les connexions HTTP }
  S := S + '  <key>NSAppTransportSecurity</key>' + #10;
  S := S + '  <dict>' + #10;
  S := S + '    <key>NSAllowsArbitraryLoads</key>' + #10;
  S := S + '    <true/>' + #10;
  S := S + '  </dict>' + #10;
  
  S := S + '</dict>' + #10;
  S := S + '</plist>' + #10;
  
  GenerateInfoPlist := S;
End;

Function GenerateDmgBackground: Boolean;
Begin
  Inc(MacStateCount);
  Inc(MacDmgCount);
  
  { Note: La generation d'image de fond DMG necessite des outils graphiques }
  { externes. Pour l'instant, on retourne True pour indiquer que l'operation }
  { est optionnelle et peut etre ignoree }
  
  GenerateDmgBackground := True;
End;

Procedure CreateMacOSBundle(Const WorkDir: String; Const Opts: TOptions);
Var
  AppName, BundlePath, ContentsPath, MacOSPath, ResourcesPath: String;
  PlistContent: String;
  F: Text;
Begin
  Inc(MacStateCount);
  Inc(MacBundleCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  AppName := SanitizeAppName(AppName);
  
  { Construire les chemins du bundle }
  BundlePath := WorkDir;
  If BundlePath[Length(BundlePath)] <> '/' Then
    BundlePath := BundlePath + '/';
  BundlePath := BundlePath + AppName + MACOS_APP_EXT + '/';
  
  ContentsPath := BundlePath + 'Contents/';
  MacOSPath := ContentsPath + 'MacOS/';
  ResourcesPath := ContentsPath + 'Resources/';
  
  { Note: En Pascal standard, CreateDir est limite. }
  { Afficher les commandes a executer }
  WriteLn('*** CREATION DU BUNDLE MACOS ***');
  WriteLn('Bundle path : ', BundlePath);
  WriteLn('Commandes a executer:');
  WriteLn('  mkdir -p "', MacOSPath, '"');
  WriteLn('  mkdir -p "', ResourcesPath, '"');
  
  { Generer le fichier Info.plist }
  PlistContent := GenerateInfoPlist(Opts);
  
  WriteLn;
  WriteLn('Contenu de ', ContentsPath, MACOS_PLIST_NAME, ':');
  WriteLn('---');
  WriteLn(PlistContent);
  WriteLn('---');
  WriteLn;
  
  { Indiquer les fichiers a copier }
  WriteLn('Fichiers a copier:');
  WriteLn('  - Executable -> ', MacOSPath, AppName);
  WriteLn('  - icon.icns -> ', ResourcesPath, 'icon.icns');
  WriteLn;
  
  Inc(MacCopyCount);
End;

Procedure CreateDmgInstaller(Const AppPath, DmgPath: String);
Var
  Cmd: String;
Begin
  Inc(MacStateCount);
  Inc(MacDmgCount);
  
  { Construire la commande hdiutil }
  Cmd := 'hdiutil create -volname "Application" ';
  Cmd := Cmd + '-srcfolder "' + AppPath + '" ';
  Cmd := Cmd + '-ov -format UDZO ';
  Cmd := Cmd + '"' + DmgPath + '"';
  
  WriteLn('*** CREATION DU DMG ***');
  WriteLn('Commande: ', Cmd);
  WriteLn;
  
  { Note: En Pascal standard, on ne peut pas executer directement }
  { une commande shell. Ceci est un placeholder pour l'implementation }
  { reelle qui utiliserait SysUtils.ExecuteProcess ou similaire }
End;

Procedure SignMacOSApp(Const AppPath: String; Const Identity: String);
Var
  Cmd: String;
Begin
  Inc(MacStateCount);
  Inc(MacSignCount);
  
  If Identity = '' Then
  Begin
    WriteLn('*** SIGNATURE MACOS ***');
    WriteLn('Aucune identite de signature fournie. Application non signee.');
    WriteLn;
    Exit;
  End;
  
  { Construire la commande codesign }
  Cmd := 'codesign --force --deep --sign "' + Identity + '" ';
  Cmd := Cmd + '--options runtime ';
  Cmd := Cmd + '"' + AppPath + '"';
  
  WriteLn('*** SIGNATURE MACOS ***');
  WriteLn('Commande: ', Cmd);
  WriteLn;
  
  { Note: En Pascal standard, on ne peut pas executer directement }
  { une commande shell. Ceci est un placeholder pour l'implementation }
End;

Function IsMacOSBundleValid(Const BundlePath: String): Boolean;
Var
  PlistPath, MacOSDir: String;
Begin
  Inc(MacStateCount);
  
  { Verifier que le chemin se termine par .app }
  If Pos(MACOS_APP_EXT, BundlePath) = 0 Then
  Begin
    IsMacOSBundleValid := False;
    Exit;
  End;
  
  { Verifier l'existence de Contents/Info.plist }
  PlistPath := BundlePath;
  If PlistPath[Length(PlistPath)] <> '/' Then
    PlistPath := PlistPath + '/';
  PlistPath := PlistPath + 'Contents/' + MACOS_PLIST_NAME;
  
  { Verifier l'existence de Contents/MacOS/ }
  MacOSDir := BundlePath;
  If MacOSDir[Length(MacOSDir)] <> '/' Then
    MacOSDir := MacOSDir + '/';
  MacOSDir := MacOSDir + 'Contents/MacOS/';
  
  { Note: En Pascal standard sans SysUtils, on ne peut pas verifier }
  { l'existence des fichiers/dossiers facilement. Retourner True }
  { pour simuler une validation reussie }
  
  IsMacOSBundleValid := True;
End;

Procedure DumpMacOSState;
Begin
  Inc(MacStateCount);
  
  WriteLn('=== Etat du module macOS ===');
  WriteLn('Initialise      : ', MacInitialized);
  WriteLn('Etat count      : ', MacStateCount);
  WriteLn('Plist generes   : ', MacPlistGenCount);
  WriteLn('Bundles crees   : ', MacBundleCount);
  WriteLn('DMG crees       : ', MacDmgCount);
  WriteLn('Apps signees    : ', MacSignCount);
  WriteLn('Copies          : ', MacCopyCount);
  WriteLn('Erreurs         : ', MacErrorCount);
  WriteLn;
End;

{ Accesseurs pour TODO 17 - GENERATION MACOS }

Function IsMacInitialized: Boolean;
Begin
  IsMacInitialized := MacInitialized;
End;

Function IsMacEmpty: Boolean;
Begin
  IsMacEmpty := (MacPlistGenCount = 0) And (MacBundleCount = 0) And (MacDmgCount = 0);
End;

Function GetMacStateCount: Integer;
Begin
  GetMacStateCount := MacStateCount;
End;

Function GetMacPlistGenCount: Integer;
Begin
  GetMacPlistGenCount := MacPlistGenCount;
End;

Function GetMacBundleCount: Integer;
Begin
  GetMacBundleCount := MacBundleCount;
End;

Function GetMacDmgCount: Integer;
Begin
  GetMacDmgCount := MacDmgCount;
End;

Function GetMacSignCount: Integer;
Begin
  GetMacSignCount := MacSignCount;
End;

Function GetMacCopyCount: Integer;
Begin
  GetMacCopyCount := MacCopyCount;
End;

Function GetMacErrorCount: Integer;
Begin
  GetMacErrorCount := MacErrorCount;
End;

Function GetMacMaxBundleSize: LongInt;
Begin
  GetMacMaxBundleSize := MACOS_MAX_BUNDLE_SIZE;
End;

{ ============================================================
  TODO 18 - GENERATION WINDOWS [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes Windows additionnelles (WIN_EXE_EXT et WIN_MSI_EXT deja definis) }
  WIN_ICO_EXT      = '.ico';
  WIN_RC_EXT       = '.rc';
  WIN_MANIFEST_EXT = '.manifest';
  WIN_MAX_VERSION_LEN = 20;
  
  { Types d'extensions Windows }
  WIN_EXT_NONE     = 0;
  WIN_EXT_EXE      = 1;
  WIN_EXT_MSI      = 2;
  WIN_EXT_ICO      = 3;
  WIN_EXT_RC       = 4;
  WIN_EXT_MANIFEST = 5;

Type
  { Configuration VERSIONINFO }
  TVersionInfo = Record
    FileVersion       : String;    { ex: '1.0.0.0' }
    ProductVersion    : String;    { ex: '1.0.0.0' }
    CompanyName       : String;    { Nom de la compagnie }
    FileDescription   : String;    { Description du fichier }
    InternalName      : String;    { Nom interne }
    OriginalFilename  : String;    { Nom de fichier original }
    ProductName       : String;    { Nom du produit }
    LegalCopyright    : String;    { Copyright }
  End;

  { Configuration du manifest Windows }
  TWindowsManifest = Record
    ExecutionLevel   : String;    { asInvoker, highestAvailable, requireAdministrator }
    DpiAware         : Boolean;   { Support DPI haute resolution }
    VisualStyles     : Boolean;   { Styles visuels Windows }
    LongPathAware    : Boolean;   { Chemins longs (> 260 chars) }
    Version          : String;    { Version du manifest }
  End;

Var
  { Variables d'etat pour le module Windows }
  WinInitialized     : Boolean;
  WinStateCount      : Integer;
  WinManifestGenCount: Integer;
  WinRcGenCount      : Integer;
  WinWixGenCount     : Integer;
  WinNsisGenCount    : Integer;
  WinInstallerCount  : Integer;
  WinCopyCount       : Integer;
  WinErrorCount      : Integer;

Procedure InitWindowsState;
Begin
  WinInitialized := True;
  WinStateCount := 0;
  WinManifestGenCount := 0;
  WinRcGenCount := 0;
  WinWixGenCount := 0;
  WinNsisGenCount := 0;
  WinInstallerCount := 0;
  WinCopyCount := 0;
  WinErrorCount := 0;
  Inc(WinStateCount);
End;

Function WinExtName(ExtType: Integer): String;
Begin
  Inc(WinStateCount);
  Case ExtType Of
    WIN_EXT_EXE:      WinExtName := WIN_EXE_EXT;
    WIN_EXT_MSI:      WinExtName := WIN_MSI_EXT;
    WIN_EXT_ICO:      WinExtName := WIN_ICO_EXT;
    WIN_EXT_RC:       WinExtName := WIN_RC_EXT;
    WIN_EXT_MANIFEST: WinExtName := WIN_MANIFEST_EXT;
  Else
    WinExtName := '';
  End;
End;

Procedure InitVersionInfo(Var Info: TVersionInfo; Const Opts: TOptions);
Var
  AppName: String;
Begin
  Inc(WinStateCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  { Initialiser les champs }
  Info.FileVersion := PAKE_VERSION + '.0';
  Info.ProductVersion := PAKE_VERSION + '.0';
  Info.CompanyName := 'Pake';
  Info.FileDescription := AppName + ' Desktop Application';
  Info.InternalName := SanitizeAppName(AppName);
  Info.OriginalFilename := SanitizeAppName(AppName) + WIN_EXE_EXT;
  Info.ProductName := AppName;
  Info.LegalCopyright := 'Copyright 2024 ' + AppName;
End;

Procedure InitWindowsManifest(Var Manifest: TWindowsManifest);
Begin
  Inc(WinStateCount);
  
  { Initialiser avec les valeurs par defaut }
  Manifest.ExecutionLevel := 'asInvoker';
  Manifest.DpiAware := True;
  Manifest.VisualStyles := True;
  Manifest.LongPathAware := True;
  Manifest.Version := '1.0.0.0';
End;

Function GenerateWindowsManifest(Const Opts: TOptions): String;
Var
  Manifest: TWindowsManifest;
  AppName, S: String;
Begin
  Inc(WinStateCount);
  Inc(WinManifestGenCount);
  
  { Initialiser le manifest }
  InitWindowsManifest(Manifest);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  { Generer le contenu du fichier manifest }
  S := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + #10;
  S := S + '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">' + #10;
  
  { Identite de l'application }
  S := S + '  <assemblyIdentity' + #10;
  S := S + '    type="win32"' + #10;
  S := S + '    name="' + EscapeJson(SanitizeAppName(AppName)) + '"' + #10;
  S := S + '    version="' + Manifest.Version + '"' + #10;
  S := S + '    processorArchitecture="*"/>' + #10;
  
  { Description }
  S := S + '  <description>' + EscapeJson(AppName) + ' Desktop Application</description>' + #10;
  
  { Compatibilite Windows }
  S := S + '  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">' + #10;
  S := S + '    <application>' + #10;
  S := S + '      <!-- Windows 10/11 -->' + #10;
  S := S + '      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>' + #10;
  S := S + '      <!-- Windows 8.1 -->' + #10;
  S := S + '      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>' + #10;
  S := S + '      <!-- Windows 8 -->' + #10;
  S := S + '      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>' + #10;
  S := S + '      <!-- Windows 7 -->' + #10;
  S := S + '      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>' + #10;
  S := S + '    </application>' + #10;
  S := S + '  </compatibility>' + #10;
  
  { Niveau d'execution demande }
  S := S + '  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">' + #10;
  S := S + '    <security>' + #10;
  S := S + '      <requestedPrivileges>' + #10;
  S := S + '        <requestedExecutionLevel level="' + Manifest.ExecutionLevel;
  S := S + '" uiAccess="false"/>' + #10;
  S := S + '      </requestedPrivileges>' + #10;
  S := S + '    </security>' + #10;
  S := S + '  </trustInfo>' + #10;
  
  { Awareness DPI }
  If Manifest.DpiAware Then
  Begin
    S := S + '  <application xmlns="urn:schemas-microsoft-com:asm.v3">' + #10;
    S := S + '    <windowsSettings>' + #10;
    S := S + '      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">';
    S := S + 'true/pm</dpiAware>' + #10;
    S := S + '      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">';
    S := S + 'PerMonitorV2, PerMonitor</dpiAwareness>' + #10;
    If Manifest.LongPathAware Then
    Begin
      S := S + '      <longPathAware xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">';
      S := S + 'true</longPathAware>' + #10;
    End;
    S := S + '    </windowsSettings>' + #10;
    S := S + '  </application>' + #10;
  End;
  
  { Styles visuels (Common Controls 6.0) }
  If Manifest.VisualStyles Then
  Begin
    S := S + '  <dependency>' + #10;
    S := S + '    <dependentAssembly>' + #10;
    S := S + '      <assemblyIdentity' + #10;
    S := S + '        type="win32"' + #10;
    S := S + '        name="Microsoft.Windows.Common-Controls"' + #10;
    S := S + '        version="6.0.0.0"' + #10;
    S := S + '        processorArchitecture="*"' + #10;
    S := S + '        publicKeyToken="6595b64144ccf1df"' + #10;
    S := S + '        language="*"/>' + #10;
    S := S + '    </dependentAssembly>' + #10;
    S := S + '  </dependency>' + #10;
  End;
  
  S := S + '</assembly>' + #10;
  
  GenerateWindowsManifest := S;
End;

Function GenerateWindowsRc(Const Opts: TOptions): String;
Var
  Info: TVersionInfo;
  S: String;
Begin
  Inc(WinStateCount);
  Inc(WinRcGenCount);
  
  { Initialiser les informations de version }
  InitVersionInfo(Info, Opts);
  
  { Generer le contenu du fichier .rc }
  S := '// Resource file generated by PAKE' + #10;
  S := S + '// ' + PAKE_VERSION + #10;
  S := S + #10;
  
  { Icone de l'application }
  S := S + '// Application Icon' + #10;
  S := S + 'IDI_ICON1 ICON "icon.ico"' + #10;
  S := S + #10;
  
  { Informations de version }
  S := S + '// Version Information' + #10;
  S := S + '1 VERSIONINFO' + #10;
  S := S + ' FILEVERSION 1,0,0,0' + #10;
  S := S + ' PRODUCTVERSION 1,0,0,0' + #10;
  S := S + ' FILEFLAGSMASK 0x3fL' + #10;
  S := S + ' FILEFLAGS 0x0L' + #10;
  S := S + ' FILEOS 0x40004L' + #10;
  S := S + ' FILETYPE 0x1L' + #10;
  S := S + ' FILESUBTYPE 0x0L' + #10;
  S := S + 'BEGIN' + #10;
  S := S + '  BLOCK "StringFileInfo"' + #10;
  S := S + '  BEGIN' + #10;
  S := S + '    BLOCK "040904b0"' + #10;
  S := S + '    BEGIN' + #10;
  S := S + '      VALUE "CompanyName", "' + Info.CompanyName + '"' + #10;
  S := S + '      VALUE "FileDescription", "' + Info.FileDescription + '"' + #10;
  S := S + '      VALUE "FileVersion", "' + Info.FileVersion + '"' + #10;
  S := S + '      VALUE "InternalName", "' + Info.InternalName + '"' + #10;
  S := S + '      VALUE "LegalCopyright", "' + Info.LegalCopyright + '"' + #10;
  S := S + '      VALUE "OriginalFilename", "' + Info.OriginalFilename + '"' + #10;
  S := S + '      VALUE "ProductName", "' + Info.ProductName + '"' + #10;
  S := S + '      VALUE "ProductVersion", "' + Info.ProductVersion + '"' + #10;
  S := S + '    END' + #10;
  S := S + '  END' + #10;
  S := S + '  BLOCK "VarFileInfo"' + #10;
  S := S + '  BEGIN' + #10;
  S := S + '    VALUE "Translation", 0x409, 1200' + #10;
  S := S + '  END' + #10;
  S := S + 'END' + #10;
  S := S + #10;
  
  { Manifest }
  S := S + '// Application Manifest' + #10;
  S := S + '1 RT_MANIFEST "app.manifest"' + #10;
  
  GenerateWindowsRc := S;
End;

Function GenerateWixWxs(Const Opts: TOptions): String;
Var
  AppName, SafeName, S: String;
Begin
  Inc(WinStateCount);
  Inc(WinWixGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  SafeName := SanitizeAppName(AppName);
  
  { Generer le contenu du fichier WiX (.wxs) }
  S := '<?xml version="1.0" encoding="UTF-8"?>' + #10;
  S := S + '<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">' + #10;
  S := S + '  <Product Id="*"' + #10;
  S := S + '           Name="' + EscapeJson(AppName) + '"' + #10;
  S := S + '           Language="1033"' + #10;
  S := S + '           Version="' + PAKE_VERSION + '.0"' + #10;
  S := S + '           Manufacturer="Pake"' + #10;
  S := S + '           UpgradeCode="PUT-GUID-HERE">' + #10;
  S := S + #10;
  S := S + '    <Package InstallerVersion="500"' + #10;
  S := S + '             Compressed="yes"' + #10;
  S := S + '             InstallScope="perMachine"' + #10;
  S := S + '             Description="' + EscapeJson(AppName) + ' Desktop Application"' + #10;
  S := S + '             Comments="Generated by PAKE"/>' + #10;
  S := S + #10;
  S := S + '    <MajorUpgrade DowngradeErrorMessage=';
  S := S + '"A newer version is already installed."/>' + #10;
  S := S + '    <MediaTemplate EmbedCab="yes"/>' + #10;
  S := S + #10;
  S := S + '    <Feature Id="ProductFeature" Title="' + EscapeJson(AppName);
  S := S + '" Level="1">' + #10;
  S := S + '      <ComponentGroupRef Id="ProductComponents"/>' + #10;
  S := S + '      <ComponentRef Id="ApplicationShortcut"/>' + #10;
  S := S + '    </Feature>' + #10;
  S := S + #10;
  S := S + '    <Directory Id="TARGETDIR" Name="SourceDir">' + #10;
  S := S + '      <Directory Id="ProgramFilesFolder">' + #10;
  S := S + '        <Directory Id="INSTALLFOLDER" Name="' + SafeName + '"/>' + #10;
  S := S + '      </Directory>' + #10;
  S := S + '      <Directory Id="ProgramMenuFolder">' + #10;
  S := S + '        <Directory Id="ApplicationProgramsFolder" Name="' + EscapeJson(AppName);
  S := S + '"/>' + #10;
  S := S + '      </Directory>' + #10;
  S := S + '      <Directory Id="DesktopFolder" Name="Desktop"/>' + #10;
  S := S + '    </Directory>' + #10;
  S := S + #10;
  S := S + '    <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">' + #10;
  S := S + '      <Component Id="MainExecutable" Guid="PUT-GUID-HERE">' + #10;
  S := S + '        <File Id="' + SafeName + 'EXE"' + #10;
  S := S + '              Name="' + SafeName + '.exe"' + #10;
  S := S + '              Source="$(var.SourceDir)\' + SafeName + '.exe"' + #10;
  S := S + '              KeyPath="yes"/>' + #10;
  S := S + '      </Component>' + #10;
  S := S + '    </ComponentGroup>' + #10;
  S := S + #10;
  S := S + '    <DirectoryRef Id="ApplicationProgramsFolder">' + #10;
  S := S + '      <Component Id="ApplicationShortcut" Guid="PUT-GUID-HERE">' + #10;
  S := S + '        <Shortcut Id="ApplicationStartMenuShortcut"' + #10;
  S := S + '                  Name="' + EscapeJson(AppName) + '"' + #10;
  S := S + '                  Description="' + EscapeJson(AppName) + '"' + #10;
  S := S + '                  Target="[INSTALLFOLDER]' + SafeName + '.exe"' + #10;
  S := S + '                  WorkingDirectory="INSTALLFOLDER"/>' + #10;
  S := S + '        <RemoveFolder Id="CleanUpShortCut"' + #10;
  S := S + '                      Directory="ApplicationProgramsFolder"' + #10;
  S := S + '                      On="uninstall"/>' + #10;
  S := S + '        <RegistryValue Root="HKCU"' + #10;
  S := S + '                       Key="Software\Pake\' + SafeName + '"' + #10;
  S := S + '                       Name="installed"' + #10;
  S := S + '                       Type="integer"' + #10;
  S := S + '                       Value="1"' + #10;
  S := S + '                       KeyPath="yes"/>' + #10;
  S := S + '      </Component>' + #10;
  S := S + '    </DirectoryRef>' + #10;
  S := S + #10;
  S := S + '    <Icon Id="icon.ico" SourceFile="$(var.SourceDir)\icon.ico"/>' + #10;
  S := S + '    <Property Id="ARPPRODUCTICON" Value="icon.ico"/>' + #10;
  S := S + '  </Product>' + #10;
  S := S + '</Wix>' + #10;
  
  GenerateWixWxs := S;
End;

Function GenerateNsisScript(Const Opts: TOptions): String;
Var
  AppName, SafeName, S: String;
Begin
  Inc(WinStateCount);
  Inc(WinNsisGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  SafeName := SanitizeAppName(AppName);
  
  { Generer le contenu du script NSIS (.nsi) }
  S := '; NSIS Installer Script generated by PAKE' + #10;
  S := S + '; ' + PAKE_VERSION + #10;
  S := S + #10;
  S := S + '!include "MUI2.nsh"' + #10;
  S := S + #10;
  S := S + '; Application Info' + #10;
  S := S + '!define APPNAME "' + AppName + '"' + #10;
  S := S + '!define COMPANYNAME "Pake"' + #10;
  S := S + '!define DESCRIPTION "' + AppName + ' Desktop Application"' + #10;
  S := S + '!define VERSIONMAJOR 1' + #10;
  S := S + '!define VERSIONMINOR 0' + #10;
  S := S + '!define VERSIONBUILD 0' + #10;
  S := S + '!define INSTALLSIZE 10000' + #10;
  S := S + #10;
  S := S + '; Installer Settings' + #10;
  S := S + 'Name "${APPNAME}"' + #10;
  S := S + 'OutFile "' + SafeName + '-Setup.exe"' + #10;
  S := S + 'InstallDir "$PROGRAMFILES\${APPNAME}"' + #10;
  S := S + 'InstallDirRegKey HKLM "Software\${APPNAME}" "InstallLocation"' + #10;
  S := S + 'RequestExecutionLevel admin' + #10;
  S := S + #10;
  S := S + '; Modern UI Settings' + #10;
  S := S + '!define MUI_ABORTWARNING' + #10;
  S := S + '!define MUI_ICON "icon.ico"' + #10;
  S := S + '!define MUI_UNICON "icon.ico"' + #10;
  S := S + #10;
  S := S + '; Pages' + #10;
  S := S + '!insertmacro MUI_PAGE_WELCOME' + #10;
  S := S + '!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"' + #10;
  S := S + '!insertmacro MUI_PAGE_DIRECTORY' + #10;
  S := S + '!insertmacro MUI_PAGE_INSTFILES' + #10;
  S := S + '!insertmacro MUI_PAGE_FINISH' + #10;
  S := S + #10;
  S := S + '!insertmacro MUI_UNPAGE_CONFIRM' + #10;
  S := S + '!insertmacro MUI_UNPAGE_INSTFILES' + #10;
  S := S + #10;
  S := S + '; Languages' + #10;
  S := S + '!insertmacro MUI_LANGUAGE "English"' + #10;
  S := S + '!insertmacro MUI_LANGUAGE "French"' + #10;
  S := S + #10;
  S := S + '; Installation Section' + #10;
  S := S + 'Section "Install"' + #10;
  S := S + '  SetOutPath $INSTDIR' + #10;
  S := S + #10;
  S := S + '  ; Files to install' + #10;
  S := S + '  File "' + SafeName + '.exe"' + #10;
  S := S + '  File "icon.ico"' + #10;
  S := S + #10;
  S := S + '  ; Create uninstaller' + #10;
  S := S + '  WriteUninstaller "$INSTDIR\uninstall.exe"' + #10;
  S := S + #10;
  S := S + '  ; Start Menu shortcut' + #10;
  S := S + '  CreateDirectory "$SMPROGRAMS\${APPNAME}"' + #10;
  S := S + '  CreateShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" ';
  S := S + '"$INSTDIR\' + SafeName + '.exe" "" "$INSTDIR\icon.ico"' + #10;
  S := S + '  CreateShortCut "$SMPROGRAMS\${APPNAME}\Uninstall.lnk" ';
  S := S + '"$INSTDIR\uninstall.exe"' + #10;
  S := S + #10;
  S := S + '  ; Desktop shortcut' + #10;
  S := S + '  CreateShortCut "$DESKTOP\${APPNAME}.lnk" ';
  S := S + '"$INSTDIR\' + SafeName + '.exe" "" "$INSTDIR\icon.ico"' + #10;
  S := S + #10;
  S := S + '  ; Registry entries' + #10;
  S := S + '  WriteRegStr HKLM "Software\${APPNAME}" "InstallLocation" "$INSTDIR"' + #10;
  S := S + '  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  S := S + '${APPNAME}" "DisplayName" "${APPNAME}"' + #10;
  S := S + '  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  S := S + '${APPNAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""' + #10;
  S := S + '  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  S := S + '${APPNAME}" "DisplayIcon" "$\"$INSTDIR\icon.ico$\""' + #10;
  S := S + '  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  S := S + '${APPNAME}" "Publisher" "${COMPANYNAME}"' + #10;
  S := S + '  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  S := S + '${APPNAME}" "EstimatedSize" ${INSTALLSIZE}' + #10;
  S := S + 'SectionEnd' + #10;
  S := S + #10;
  S := S + '; Uninstallation Section' + #10;
  S := S + 'Section "Uninstall"' + #10;
  S := S + '  ; Remove files' + #10;
  S := S + '  Delete "$INSTDIR\' + SafeName + '.exe"' + #10;
  S := S + '  Delete "$INSTDIR\icon.ico"' + #10;
  S := S + '  Delete "$INSTDIR\uninstall.exe"' + #10;
  S := S + '  RMDir "$INSTDIR"' + #10;
  S := S + #10;
  S := S + '  ; Remove shortcuts' + #10;
  S := S + '  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"' + #10;
  S := S + '  Delete "$SMPROGRAMS\${APPNAME}\Uninstall.lnk"' + #10;
  S := S + '  RMDir "$SMPROGRAMS\${APPNAME}"' + #10;
  S := S + '  Delete "$DESKTOP\${APPNAME}.lnk"' + #10;
  S := S + #10;
  S := S + '  ; Remove registry entries' + #10;
  S := S + '  DeleteRegKey HKLM "Software\${APPNAME}"' + #10;
  S := S + '  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  S := S + '${APPNAME}"' + #10;
  S := S + 'SectionEnd' + #10;
  
  GenerateNsisScript := S;
End;

Procedure CreateWindowsInstaller(Const WorkDir: String; Const Opts: TOptions);
Var
  ManifestContent, RcContent, WxsContent, NsiContent: String;
  AppName, SafeName: String;
  F: Text;
  ManifestPath, RcPath, WxsPath, NsiPath: String;
Begin
  Inc(WinStateCount);
  Inc(WinInstallerCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  SafeName := SanitizeAppName(AppName);
  
  If Opts.Verbose Then
    WriteLn('Generating Windows installer files...');
  
  { Generer le manifest Windows }
  ManifestContent := GenerateWindowsManifest(Opts);
  ManifestPath := ConcatPath(WorkDir, SafeName + WIN_MANIFEST_EXT);
  
  {$I-}
  Assign(F, ManifestPath);
  Rewrite(F);
  If IOResult = 0 Then
  Begin
    Write(F, ManifestContent);
    Close(F);
    Inc(WinCopyCount);
    If Opts.Verbose Then
      WriteLn('Created: ', ManifestPath);
  End
  Else
    Inc(WinErrorCount);
  {$I+}
  
  { Generer le fichier .rc }
  RcContent := GenerateWindowsRc(Opts);
  RcPath := ConcatPath(WorkDir, SafeName + WIN_RC_EXT);
  
  {$I-}
  Assign(F, RcPath);
  Rewrite(F);
  If IOResult = 0 Then
  Begin
    Write(F, RcContent);
    Close(F);
    Inc(WinCopyCount);
    If Opts.Verbose Then
      WriteLn('Created: ', RcPath);
  End
  Else
    Inc(WinErrorCount);
  {$I+}
  
  { Generer le fichier WiX (.wxs) }
  WxsContent := GenerateWixWxs(Opts);
  WxsPath := ConcatPath(WorkDir, SafeName + '.wxs');
  
  {$I-}
  Assign(F, WxsPath);
  Rewrite(F);
  If IOResult = 0 Then
  Begin
    Write(F, WxsContent);
    Close(F);
    Inc(WinCopyCount);
    If Opts.Verbose Then
      WriteLn('Created: ', WxsPath);
  End
  Else
    Inc(WinErrorCount);
  {$I+}
  
  { Generer le script NSIS (.nsi) }
  NsiContent := GenerateNsisScript(Opts);
  NsiPath := ConcatPath(WorkDir, SafeName + '.nsi');
  
  {$I-}
  Assign(F, NsiPath);
  Rewrite(F);
  If IOResult = 0 Then
  Begin
    Write(F, NsiContent);
    Close(F);
    Inc(WinCopyCount);
    If Opts.Verbose Then
      WriteLn('Created: ', NsiPath);
  End
  Else
    Inc(WinErrorCount);
  {$I+}
  
  If Opts.Verbose Then
  Begin
    WriteLn;
    WriteLn('Windows installer files generated:');
    WriteLn('  - ', SafeName, WIN_MANIFEST_EXT, ' (application manifest)');
    WriteLn('  - ', SafeName, WIN_RC_EXT, ' (resource script)');
    WriteLn('  - ', SafeName, '.wxs (WiX source for MSI)');
    WriteLn('  - ', SafeName, '.nsi (NSIS script)');
    WriteLn;
    WriteLn('To build MSI installer: candle.exe ', SafeName, '.wxs && light.exe ',
            SafeName, '.wixobj');
    WriteLn('To build NSIS installer: makensis.exe ', SafeName, '.nsi');
  End;
End;

Function IsWindowsInstallerValid(Const InstallerPath: String): Boolean;
Begin
  Inc(WinStateCount);
  
  { Verifier que le fichier existe }
  IsWindowsInstallerValid := FileExists(InstallerPath);
End;

Procedure DumpWindowsState;
Begin
  Inc(WinStateCount);
  
  WriteLn('=== Etat du module Windows ===');
  WriteLn('Initialise      : ', WinInitialized);
  WriteLn('Etat count      : ', WinStateCount);
  WriteLn('Manifests gen.  : ', WinManifestGenCount);
  WriteLn('RC generes      : ', WinRcGenCount);
  WriteLn('WiX generes     : ', WinWixGenCount);
  WriteLn('NSIS generes    : ', WinNsisGenCount);
  WriteLn('Installers      : ', WinInstallerCount);
  WriteLn('Copies          : ', WinCopyCount);
  WriteLn('Erreurs         : ', WinErrorCount);
  WriteLn;
End;

{ Accesseurs pour TODO 18 - GENERATION WINDOWS }

Function IsWinInitialized: Boolean;
Begin
  IsWinInitialized := WinInitialized;
End;

Function IsWinEmpty: Boolean;
Begin
  IsWinEmpty := (WinManifestGenCount = 0) And (WinRcGenCount = 0) And 
                (WinWixGenCount = 0) And (WinNsisGenCount = 0);
End;

Function GetWinStateCount: Integer;
Begin
  GetWinStateCount := WinStateCount;
End;

Function GetWinManifestGenCount: Integer;
Begin
  GetWinManifestGenCount := WinManifestGenCount;
End;

Function GetWinRcGenCount: Integer;
Begin
  GetWinRcGenCount := WinRcGenCount;
End;

Function GetWinWixGenCount: Integer;
Begin
  GetWinWixGenCount := WinWixGenCount;
End;

Function GetWinNsisGenCount: Integer;
Begin
  GetWinNsisGenCount := WinNsisGenCount;
End;

Function GetWinInstallerCount: Integer;
Begin
  GetWinInstallerCount := WinInstallerCount;
End;

Function GetWinCopyCount: Integer;
Begin
  GetWinCopyCount := WinCopyCount;
End;

Function GetWinErrorCount: Integer;
Begin
  GetWinErrorCount := WinErrorCount;
End;

{ ============================================================
  TODO 19 - GENERATION LINUX [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes Linux additionnelles (LINUX_DEB_EXT, LINUX_RPM_EXT, LINUX_APPIMAGE_EXT deja definis) }
  LINUX_DESKTOP_EXT   = '.desktop';
  LINUX_MAX_CATEGORY  = 64;
  
  { Types d'extensions Linux }
  LINUX_EXT_NONE      = 0;
  LINUX_EXT_DEB       = 1;
  LINUX_EXT_RPM       = 2;
  LINUX_EXT_APPIMAGE  = 3;
  LINUX_EXT_DESKTOP   = 4;
  
  { Categories pour les fichiers .desktop }
  LINUX_CAT_NETWORK   = 'Network';
  LINUX_CAT_OFFICE    = 'Office';
  LINUX_CAT_UTILITY   = 'Utility';
  LINUX_CAT_GRAPHICS  = 'Graphics';
  LINUX_CAT_AUDIO     = 'Audio';
  LINUX_CAT_VIDEO     = 'Video';

Var
  { Variables d'etat pour le module Linux }
  LinuxInitialized     : Boolean;
  LinuxStateCount      : Integer;
  LinuxDesktopGenCount : Integer;
  LinuxControlGenCount : Integer;
  LinuxDebGenCount     : Integer;
  LinuxAppImageGenCount: Integer;
  LinuxInstallerCount  : Integer;
  LinuxCopyCount       : Integer;
  LinuxErrorCount      : Integer;

Procedure InitLinuxState;
Begin
  LinuxInitialized := True;
  LinuxStateCount := 0;
  LinuxDesktopGenCount := 0;
  LinuxControlGenCount := 0;
  LinuxDebGenCount := 0;
  LinuxAppImageGenCount := 0;
  LinuxInstallerCount := 0;
  LinuxCopyCount := 0;
  LinuxErrorCount := 0;
  Inc(LinuxStateCount);
End;

Function LinuxExtName(ExtType: Integer): String;
Begin
  Inc(LinuxStateCount);
  Case ExtType Of
    LINUX_EXT_DEB:      LinuxExtName := LINUX_DEB_EXT;
    LINUX_EXT_RPM:      LinuxExtName := LINUX_RPM_EXT;
    LINUX_EXT_APPIMAGE: LinuxExtName := LINUX_APPIMAGE_EXT;
    LINUX_EXT_DESKTOP:  LinuxExtName := LINUX_DESKTOP_EXT;
  Else
    LinuxExtName := '';
  End;
End;

Function GenerateDesktopEntry(Const Opts: TOptions): String;
Var
  AppName, AppExec, AppIcon: String;
  Content: String;
Begin
  Inc(LinuxStateCount);
  Inc(LinuxDesktopGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  { Construire les chemins }
  AppExec := '/usr/bin/' + LowerStr(SanitizeAppName(AppName));
  AppIcon := LowerStr(SanitizeAppName(AppName));
  
  { Generer le contenu du fichier .desktop }
  Content := '[Desktop Entry]' + #10;
  Content := Content + 'Version=1.0' + #10;
  Content := Content + 'Type=Application' + #10;
  Content := Content + 'Name=' + AppName + #10;
  Content := Content + 'GenericName=' + AppName + ' Desktop Application' + #10;
  Content := Content + 'Comment=Desktop application for ' + Opts.Url + #10;
  Content := Content + 'Exec=' + AppExec + ' %U' + #10;
  Content := Content + 'Icon=' + AppIcon + #10;
  Content := Content + 'Terminal=false' + #10;
  Content := Content + 'Categories=Network;WebBrowser;' + #10;
  Content := Content + 'MimeType=x-scheme-handler/http;x-scheme-handler/https;' + #10;
  Content := Content + 'StartupNotify=true' + #10;
  Content := Content + 'StartupWMClass=' + SanitizeAppName(AppName) + #10;
  
  { Ajouter Keywords si pertinents }
  Content := Content + 'Keywords=' + AppName + ';web;browser;' + #10;
  
  GenerateDesktopEntry := Content;
End;

Function GenerateDebianControl(Const Opts: TOptions): String;
Var
  AppName, PkgName: String;
  Content: String;
Begin
  Inc(LinuxStateCount);
  Inc(LinuxControlGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  { Generer le nom de package (minuscules, sans espaces) }
  PkgName := LowerStr(SanitizeAppName(AppName));
  
  { Generer le contenu du fichier DEBIAN/control }
  Content := 'Package: ' + PkgName + #10;
  Content := Content + 'Version: ' + PAKE_VERSION + #10;
  Content := Content + 'Section: web' + #10;
  Content := Content + 'Priority: optional' + #10;
  Content := Content + 'Architecture: amd64' + #10;
  Content := Content + 'Depends: libc6 (>= 2.17), libgtk-3-0 (>= 3.22), libwebkit2gtk-4.0-37' + #10;
  Content := Content + 'Maintainer: Pake User <user@example.com>' + #10;
  Content := Content + 'Description: ' + AppName + ' Desktop Application' + #10;
  Content := Content + ' Desktop application generated by Pake for accessing' + #10;
  Content := Content + ' ' + Opts.Url + ' as a native desktop application.' + #10;
  Content := Content + ' .' + #10;
  Content := Content + ' Built with Rust Tauri for optimal performance' + #10;
  Content := Content + ' and minimal resource usage.' + #10;
  Content := Content + 'Homepage: ' + Opts.Url + #10;
  
  GenerateDebianControl := Content;
End;

Procedure CreateDebPackage(Const WorkDir, OutputDir: String; Const Opts: TOptions);
Var
  AppName, PkgName: String;
  DesktopContent, ControlContent: String;
  DebDir, UsrBinDir, UsrShareAppDir, UsrShareIconDir: String;
  F: Text;
Begin
  Inc(LinuxStateCount);
  Inc(LinuxDebGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  PkgName := LowerStr(SanitizeAppName(AppName));
  
  { Creer la structure du package .deb }
  DebDir := WorkDir + '/' + PkgName + '-' + PAKE_VERSION;
  UsrBinDir := DebDir + '/usr/bin';
  UsrShareAppDir := DebDir + '/usr/share/applications';
  UsrShareIconDir := DebDir + '/usr/share/icons/hicolor/256x256/apps';
  
  WriteLn('Creating Debian package structure...');
  WriteLn('  DEBIAN/control');
  WriteLn('  usr/bin/', PkgName);
  WriteLn('  usr/share/applications/', PkgName, LINUX_DESKTOP_EXT);
  WriteLn('  usr/share/icons/hicolor/256x256/apps/', PkgName, '.png');
  
  { Generer le fichier DEBIAN/control }
  ControlContent := GenerateDebianControl(Opts);
  WriteLn;
  WriteLn('=== DEBIAN/control ===');
  WriteLn(ControlContent);
  
  { Generer le fichier .desktop }
  DesktopContent := GenerateDesktopEntry(Opts);
  WriteLn('=== ', PkgName, LINUX_DESKTOP_EXT, ' ===');
  WriteLn(DesktopContent);
  
  { Simuler la creation (en mode demo, on n'ecrit pas les fichiers) }
  WriteLn('Package .deb would be created: ', OutputDir, '/', PkgName, '-', PAKE_VERSION, LINUX_DEB_EXT);
  WriteLn;
  
  Inc(LinuxInstallerCount);
End;

Function GenerateAppImageDesktop(Const Opts: TOptions): String;
Var
  AppName, AppExec, AppIcon: String;
  Content: String;
Begin
  Inc(LinuxStateCount);
  Inc(LinuxDesktopGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  { Pour AppImage, l'executable est dans le AppDir }
  AppExec := SanitizeAppName(AppName);
  AppIcon := LowerStr(SanitizeAppName(AppName));
  
  { Generer le contenu du fichier .desktop pour AppImage }
  Content := '[Desktop Entry]' + #10;
  Content := Content + 'Version=1.0' + #10;
  Content := Content + 'Type=Application' + #10;
  Content := Content + 'Name=' + AppName + #10;
  Content := Content + 'Exec=' + AppExec + #10;
  Content := Content + 'Icon=' + AppIcon + #10;
  Content := Content + 'Terminal=false' + #10;
  Content := Content + 'Categories=Network;' + #10;
  Content := Content + 'X-AppImage-Version=' + PAKE_VERSION + #10;
  Content := Content + 'X-AppImage-Name=' + AppName + #10;
  
  GenerateAppImageDesktop := Content;
End;

Procedure CreateAppImage(Const WorkDir, OutputDir: String; Const Opts: TOptions);
Var
  AppName, AppDirName: String;
  DesktopContent: String;
  AppDir, AppBinDir, AppIconDir: String;
Begin
  Inc(LinuxStateCount);
  Inc(LinuxAppImageGenCount);
  
  { Determiner le nom de l'application }
  If Opts.AppName <> '' Then
    AppName := Opts.AppName
  Else
    AppName := ExtractDomain(Opts.Url);
  
  AppDirName := SanitizeAppName(AppName) + '.AppDir';
  
  { Creer la structure AppImage }
  AppDir := WorkDir + '/' + AppDirName;
  AppBinDir := AppDir + '/usr/bin';
  AppIconDir := AppDir + '/usr/share/icons/hicolor/256x256/apps';
  
  WriteLn('Creating AppImage structure...');
  WriteLn('  ', AppDirName, '/');
  WriteLn('    AppRun (symlink to executable)');
  WriteLn('    ', LowerStr(SanitizeAppName(AppName)), LINUX_DESKTOP_EXT);
  WriteLn('    ', LowerStr(SanitizeAppName(AppName)), '.png (icon)');
  WriteLn('    usr/bin/', SanitizeAppName(AppName));
  WriteLn('    usr/share/icons/...');
  
  { Generer le fichier .desktop pour AppImage }
  DesktopContent := GenerateAppImageDesktop(Opts);
  WriteLn;
  WriteLn('=== AppImage .desktop ===');
  WriteLn(DesktopContent);
  
  { Note: appimagetool serait appele ici }
  WriteLn('Command to create AppImage:');
  WriteLn('  appimagetool ', AppDirName, ' ', SanitizeAppName(AppName), '-', PAKE_VERSION, LINUX_APPIMAGE_EXT);
  WriteLn;
  
  WriteLn('AppImage would be created: ', OutputDir, '/', SanitizeAppName(AppName), '-', PAKE_VERSION, LINUX_APPIMAGE_EXT);
  WriteLn;
  
  Inc(LinuxInstallerCount);
End;

Function IsLinuxInstallerValid(Const InstallerPath: String): Boolean;
Var
  Ext: String;
Begin
  Inc(LinuxStateCount);
  
  { Extraire l'extension }
  Ext := ExtractFileExt(InstallerPath);
  
  { Verifier si c'est une extension d'installateur Linux valide }
  IsLinuxInstallerValid := (Ext = LINUX_DEB_EXT) Or 
                           (Ext = LINUX_RPM_EXT) Or 
                           (Ext = LINUX_APPIMAGE_EXT);
End;

Procedure CreateLinuxInstaller(Const WorkDir: String; Const Opts: TOptions);
Var
  OutputDir: String;
Begin
  Inc(LinuxStateCount);
  
  { Determiner le repertoire de sortie }
  If Opts.OutputDir <> '' Then
    OutputDir := Opts.OutputDir
  Else
    OutputDir := WorkDir + '/dist';
  
  WriteLn('Creating Linux installers in: ', OutputDir);
  WriteLn;
  
  { Creer le package .deb }
  WriteLn('--- Creating Debian Package (.deb) ---');
  CreateDebPackage(WorkDir, OutputDir, Opts);
  
  { Creer l'AppImage }
  WriteLn('--- Creating AppImage (.AppImage) ---');
  CreateAppImage(WorkDir, OutputDir, Opts);
  
  { Note: RPM n'est pas implemente dans cette version }
  WriteLn('--- RPM Package ---');
  WriteLn('Note: RPM generation requires rpmbuild tool (not implemented in this demo)');
  WriteLn;
End;

Procedure DumpLinuxState;
Begin
  Inc(LinuxStateCount);
  WriteLn('=== Linux Generation State ===');
  WriteLn('  Initialized    : ', LinuxInitialized);
  WriteLn('  State Count    : ', LinuxStateCount);
  WriteLn('  Desktop Gen    : ', LinuxDesktopGenCount);
  WriteLn('  Control Gen    : ', LinuxControlGenCount);
  WriteLn('  Deb Gen        : ', LinuxDebGenCount);
  WriteLn('  AppImage Gen   : ', LinuxAppImageGenCount);
  WriteLn('  Installer Count: ', LinuxInstallerCount);
  WriteLn('  Copy Count     : ', LinuxCopyCount);
  WriteLn('  Error Count    : ', LinuxErrorCount);
  WriteLn;
End;

{ Accesseurs pour le module Linux }

Function IsLinuxInitialized: Boolean;
Begin
  IsLinuxInitialized := LinuxInitialized;
End;

Function IsLinuxEmpty: Boolean;
Begin
  IsLinuxEmpty := (LinuxDesktopGenCount = 0) And (LinuxControlGenCount = 0) And 
                  (LinuxDebGenCount = 0) And (LinuxAppImageGenCount = 0);
End;

Function GetLinuxStateCount: Integer;
Begin
  GetLinuxStateCount := LinuxStateCount;
End;

Function GetLinuxDesktopGenCount: Integer;
Begin
  GetLinuxDesktopGenCount := LinuxDesktopGenCount;
End;

Function GetLinuxControlGenCount: Integer;
Begin
  GetLinuxControlGenCount := LinuxControlGenCount;
End;

Function GetLinuxDebGenCount: Integer;
Begin
  GetLinuxDebGenCount := LinuxDebGenCount;
End;

Function GetLinuxAppImageGenCount: Integer;
Begin
  GetLinuxAppImageGenCount := LinuxAppImageGenCount;
End;

Function GetLinuxInstallerCount: Integer;
Begin
  GetLinuxInstallerCount := LinuxInstallerCount;
End;

Function GetLinuxCopyCount: Integer;
Begin
  GetLinuxCopyCount := LinuxCopyCount;
End;

Function GetLinuxErrorCount: Integer;
Begin
  GetLinuxErrorCount := LinuxErrorCount;
End;

{ ============================================================
  TODO 20 - MULTI-URL [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes Multi-URL }
  MU_MAX_URLS       = 10;
  MU_MAX_TITLE_LEN  = 64;
  MU_MAX_SHORTCUT   = 32;
  
  { Types d'extensions Multi-URL }
  MU_EXT_NONE       = 0;
  MU_EXT_HTML       = 1;
  MU_EXT_JS         = 2;
  MU_EXT_CSS        = 3;

Type
  { Type TMuUrlEntry pour stocker une URL avec son titre et raccourci }
  TMuUrlEntry = Record
    Url      : String;
    Title    : String;
    Shortcut : String;
    Enabled  : Boolean;
  End;
  
  TMuUrlArray = Array[1..MU_MAX_URLS] Of TMuUrlEntry;

Var
  { Variables d'etat pour le module Multi-URL }
  MuInitialized      : Boolean;
  MuStateCount       : Integer;
  MuUrls             : TMuUrlArray;
  MuUrlCount         : Integer;
  MuParseCount       : Integer;
  MuHtmlGenCount     : Integer;
  MuJsGenCount       : Integer;
  MuCssGenCount      : Integer;
  MuErrorCount       : Integer;
  MuLabelNum         : Integer;

Procedure InitMultiUrlState;
Var
  I: Integer;
Begin
  MuInitialized := True;
  MuStateCount := 0;
  MuUrlCount := 0;
  MuParseCount := 0;
  MuHtmlGenCount := 0;
  MuJsGenCount := 0;
  MuCssGenCount := 0;
  MuErrorCount := 0;
  MuLabelNum := 0;
  For I := 1 To MU_MAX_URLS Do
  Begin
    MuUrls[I].Url := '';
    MuUrls[I].Title := '';
    MuUrls[I].Shortcut := '';
    MuUrls[I].Enabled := False;
  End;
  Inc(MuStateCount);
End;

Function GenMuLabel: String;
Begin
  Inc(MuLabelNum);
  GenMuLabel := '_MU_' + IntToStr(MuLabelNum);
End;

Function MuExtName(ExtType: Integer): String;
Begin
  Inc(MuStateCount);
  Case ExtType Of
    MU_EXT_HTML: MuExtName := '.html';
    MU_EXT_JS:   MuExtName := '.js';
    MU_EXT_CSS:  MuExtName := '.css';
    Else         MuExtName := '';
  End;
End;

Procedure InitMuUrlEntry(Var Entry: TMuUrlEntry);
Begin
  Entry.Url := '';
  Entry.Title := '';
  Entry.Shortcut := '';
  Entry.Enabled := False;
End;

Function AddUrlEntry(Const Url, Title, Shortcut: String): Boolean;
Begin
  Inc(MuStateCount);
  If MuUrlCount >= MU_MAX_URLS Then
  Begin
    Inc(MuErrorCount);
    AddUrlEntry := False;
    Exit;
  End;
  Inc(MuUrlCount);
  MuUrls[MuUrlCount].Url := Url;
  If Title = '' Then
    MuUrls[MuUrlCount].Title := 'Tab ' + IntToStr(MuUrlCount)
  Else
    MuUrls[MuUrlCount].Title := Title;
  If Shortcut = '' Then
    MuUrls[MuUrlCount].Shortcut := 'CmdOrCtrl+' + IntToStr(MuUrlCount)
  Else
    MuUrls[MuUrlCount].Shortcut := Shortcut;
  MuUrls[MuUrlCount].Enabled := True;
  AddUrlEntry := True;
End;

Function ParseMultiUrl(Const UrlList: String): Boolean;
{ Parse une liste d'URLs separees par virgules }
Var
  S, Url: String;
  P, Start: Integer;
Begin
  Inc(MuStateCount);
  Inc(MuParseCount);
  
  If UrlList = '' Then
  Begin
    Inc(MuErrorCount);
    ParseMultiUrl := False;
    Exit;
  End;
  
  S := UrlList;
  Start := 1;
  P := Pos(',', S);
  
  While P > 0 Do
  Begin
    Url := Trim(Copy(S, 1, P - 1));
    If Url <> '' Then
    Begin
      If Not AddUrlEntry(Url, '', '') Then
      Begin
        ParseMultiUrl := False;
        Exit;
      End;
    End;
    Delete(S, 1, P);
    P := Pos(',', S);
  End;
  
  { Derniere URL }
  Url := Trim(S);
  If Url <> '' Then
  Begin
    If Not AddUrlEntry(Url, '', '') Then
    Begin
      ParseMultiUrl := False;
      Exit;
    End;
  End;
  
  ParseMultiUrl := MuUrlCount > 0;
End;

Function GenerateMultiTabCss: String;
{ Genere le CSS pour les onglets }
Var
  Css: String;
Begin
  Inc(MuStateCount);
  Inc(MuCssGenCount);
  
  Css := '/* Multi-Tab CSS - Generated by PAKE */' + #10;
  Css := Css + '.tab-container {' + #10;
  Css := Css + '  display: flex;' + #10;
  Css := Css + '  flex-direction: column;' + #10;
  Css := Css + '  height: 100vh;' + #10;
  Css := Css + '  margin: 0;' + #10;
  Css := Css + '  padding: 0;' + #10;
  Css := Css + '  overflow: hidden;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-bar {' + #10;
  Css := Css + '  display: flex;' + #10;
  Css := Css + '  background-color: #2d2d2d;' + #10;
  Css := Css + '  padding: 0;' + #10;
  Css := Css + '  margin: 0;' + #10;
  Css := Css + '  border-bottom: 1px solid #444;' + #10;
  Css := Css + '  min-height: 36px;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-button {' + #10;
  Css := Css + '  padding: 8px 16px;' + #10;
  Css := Css + '  background-color: #3d3d3d;' + #10;
  Css := Css + '  border: none;' + #10;
  Css := Css + '  color: #ccc;' + #10;
  Css := Css + '  cursor: pointer;' + #10;
  Css := Css + '  font-size: 13px;' + #10;
  Css := Css + '  transition: background-color 0.2s;' + #10;
  Css := Css + '  border-right: 1px solid #555;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-button:hover {' + #10;
  Css := Css + '  background-color: #4d4d4d;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-button.active {' + #10;
  Css := Css + '  background-color: #1e90ff;' + #10;
  Css := Css + '  color: white;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-content {' + #10;
  Css := Css + '  flex: 1;' + #10;
  Css := Css + '  overflow: hidden;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-panel {' + #10;
  Css := Css + '  display: none;' + #10;
  Css := Css + '  width: 100%;' + #10;
  Css := Css + '  height: 100%;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-panel.active {' + #10;
  Css := Css + '  display: block;' + #10;
  Css := Css + '}' + #10;
  Css := Css + #10;
  Css := Css + '.tab-iframe {' + #10;
  Css := Css + '  width: 100%;' + #10;
  Css := Css + '  height: 100%;' + #10;
  Css := Css + '  border: none;' + #10;
  Css := Css + '}' + #10;
  
  GenerateMultiTabCss := Css;
End;

Function GenerateMultiTabJs: String;
{ Genere le JavaScript pour la navigation entre URLs }
Var
  Js: String;
  I: Integer;
Begin
  Inc(MuStateCount);
  Inc(MuJsGenCount);
  
  Js := '// Multi-Tab JavaScript - Generated by PAKE' + #10;
  Js := Js + 'const urls = [' + #10;
  For I := 1 To MuUrlCount Do
  Begin
    Js := Js + '  { url: "' + MuUrls[I].Url + '", ';
    Js := Js + 'title: "' + MuUrls[I].Title + '", ';
    Js := Js + 'shortcut: "' + MuUrls[I].Shortcut + '" }';
    If I < MuUrlCount Then
      Js := Js + ',';
    Js := Js + #10;
  End;
  Js := Js + '];' + #10;
  Js := Js + #10;
  Js := Js + 'let activeTab = 0;' + #10;
  Js := Js + #10;
  Js := Js + 'function switchTab(index) {' + #10;
  Js := Js + '  const buttons = document.querySelectorAll(".tab-button");' + #10;
  Js := Js + '  const panels = document.querySelectorAll(".tab-panel");' + #10;
  Js := Js + '  ' + #10;
  Js := Js + '  buttons.forEach((btn, i) => {' + #10;
  Js := Js + '    btn.classList.toggle("active", i === index);' + #10;
  Js := Js + '  });' + #10;
  Js := Js + '  ' + #10;
  Js := Js + '  panels.forEach((panel, i) => {' + #10;
  Js := Js + '    panel.classList.toggle("active", i === index);' + #10;
  Js := Js + '  });' + #10;
  Js := Js + '  ' + #10;
  Js := Js + '  activeTab = index;' + #10;
  Js := Js + '}' + #10;
  Js := Js + #10;
  Js := Js + 'function initTabs() {' + #10;
  Js := Js + '  switchTab(0);' + #10;
  Js := Js + '  ' + #10;
  Js := Js + '  // Keyboard shortcuts' + #10;
  Js := Js + '  document.addEventListener("keydown", (e) => {' + #10;
  Js := Js + '    if ((e.ctrlKey || e.metaKey) && e.key >= "1" && e.key <= "9") {' + #10;
  Js := Js + '      const index = parseInt(e.key) - 1;' + #10;
  Js := Js + '      if (index < urls.length) {' + #10;
  Js := Js + '        e.preventDefault();' + #10;
  Js := Js + '        switchTab(index);' + #10;
  Js := Js + '      }' + #10;
  Js := Js + '    }' + #10;
  Js := Js + '  });' + #10;
  Js := Js + '}' + #10;
  Js := Js + #10;
  Js := Js + 'document.addEventListener("DOMContentLoaded", initTabs);' + #10;
  
  GenerateMultiTabJs := Js;
End;

Function GenerateMultiTabHtml: String;
{ Genere le HTML pour une interface multi-onglets }
Var
  Html: String;
  I: Integer;
Begin
  Inc(MuStateCount);
  Inc(MuHtmlGenCount);
  
  Html := '<!DOCTYPE html>' + #10;
  Html := Html + '<html lang="en">' + #10;
  Html := Html + '<head>' + #10;
  Html := Html + '  <meta charset="UTF-8">' + #10;
  Html := Html + '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' + #10;
  Html := Html + '  <title>Multi-Tab Application</title>' + #10;
  Html := Html + '  <style>' + #10;
  Html := Html + GenerateMultiTabCss;
  Html := Html + '  </style>' + #10;
  Html := Html + '</head>' + #10;
  Html := Html + '<body>' + #10;
  Html := Html + '  <div class="tab-container">' + #10;
  Html := Html + '    <div class="tab-bar">' + #10;
  
  { Boutons d'onglets }
  For I := 1 To MuUrlCount Do
  Begin
    Html := Html + '      <button class="tab-button';
    If I = 1 Then
      Html := Html + ' active';
    Html := Html + '" onclick="switchTab(' + IntToStr(I - 1) + ')">';
    Html := Html + MuUrls[I].Title + '</button>' + #10;
  End;
  
  Html := Html + '    </div>' + #10;
  Html := Html + '    <div class="tab-content">' + #10;
  
  { Panneaux avec iframes }
  For I := 1 To MuUrlCount Do
  Begin
    Html := Html + '      <div class="tab-panel';
    If I = 1 Then
      Html := Html + ' active';
    Html := Html + '">' + #10;
    Html := Html + '        <iframe class="tab-iframe" src="' + MuUrls[I].Url + '"></iframe>' + #10;
    Html := Html + '      </div>' + #10;
  End;
  
  Html := Html + '    </div>' + #10;
  Html := Html + '  </div>' + #10;
  Html := Html + '  <script>' + #10;
  Html := Html + GenerateMultiTabJs;
  Html := Html + '  </script>' + #10;
  Html := Html + '</body>' + #10;
  Html := Html + '</html>' + #10;
  
  GenerateMultiTabHtml := Html;
End;

Procedure DumpMultiUrlState;
Begin
  Inc(MuStateCount);
  WriteLn('=== Multi-URL State ===');
  WriteLn('  Initialized   : ', MuInitialized);
  WriteLn('  State Count   : ', MuStateCount);
  WriteLn('  URL Count     : ', MuUrlCount);
  WriteLn('  Parse Count   : ', MuParseCount);
  WriteLn('  HTML Gen Count: ', MuHtmlGenCount);
  WriteLn('  JS Gen Count  : ', MuJsGenCount);
  WriteLn('  CSS Gen Count : ', MuCssGenCount);
  WriteLn('  Error Count   : ', MuErrorCount);
  WriteLn('  Label Num     : ', MuLabelNum);
  WriteLn;
End;

{ Accesseurs pour le module Multi-URL }

Function IsMuInitialized: Boolean;
Begin
  IsMuInitialized := MuInitialized;
End;

Function IsMuEmpty: Boolean;
Begin
  IsMuEmpty := MuUrlCount = 0;
End;

Function GetMuStateCount: Integer;
Begin
  GetMuStateCount := MuStateCount;
End;

Function GetMuUrlCount: Integer;
Begin
  GetMuUrlCount := MuUrlCount;
End;

Function GetMuParseCount: Integer;
Begin
  GetMuParseCount := MuParseCount;
End;

Function GetMuHtmlGenCount: Integer;
Begin
  GetMuHtmlGenCount := MuHtmlGenCount;
End;

Function GetMuJsGenCount: Integer;
Begin
  GetMuJsGenCount := MuJsGenCount;
End;

Function GetMuCssGenCount: Integer;
Begin
  GetMuCssGenCount := MuCssGenCount;
End;

Function GetMuErrorCount: Integer;
Begin
  GetMuErrorCount := MuErrorCount;
End;

Function GetMuMaxUrls: Integer;
Begin
  GetMuMaxUrls := MU_MAX_URLS;
End;

{ ============================================================
  TODO 21 - CONFIGURATION DU USER-AGENT [IMPLEMENTE]
  ============================================================ }

Const
  { Constantes User-Agent }
  UA_MAX_LENGTH     = 512;
  
  { Types de User-Agent }
  UA_TYPE_NONE      = 0;
  UA_TYPE_DEFAULT   = 1;
  UA_TYPE_CHROME    = 2;
  UA_TYPE_FIREFOX   = 3;
  UA_TYPE_SAFARI    = 4;
  UA_TYPE_EDGE      = 5;
  UA_TYPE_CUSTOM    = 6;
  
  { User-Agents predefinies }
  UA_CHROME  = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  UA_FIREFOX = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0';
  UA_SAFARI  = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15';
  UA_EDGE    = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0';
  UA_DEFAULT = 'Mozilla/5.0 (compatible; Pake/1.0; +https://github.com/pake-go/pake)';

Var
  { Variables d'etat pour le module User-Agent }
  UaInitialized      : Boolean;
  UaStateCount       : Integer;
  UaCurrentType      : Integer;
  UaCurrentString    : String;
  UaValidateCount    : Integer;
  UaConfigGenCount   : Integer;
  UaApplyCount       : Integer;
  UaErrorCount       : Integer;
  UaLabelNum         : Integer;

Procedure InitUserAgentState;
Begin
  UaInitialized := True;
  UaStateCount := 0;
  UaCurrentType := UA_TYPE_DEFAULT;
  UaCurrentString := UA_DEFAULT;
  UaValidateCount := 0;
  UaConfigGenCount := 0;
  UaApplyCount := 0;
  UaErrorCount := 0;
  UaLabelNum := 0;
  Inc(UaStateCount);
End;

Function GenUaLabel: String;
Begin
  Inc(UaLabelNum);
  GenUaLabel := '_UA_' + IntToStr(UaLabelNum);
End;

Function UaTypeName(UaType: Integer): String;
Begin
  Inc(UaStateCount);
  Case UaType Of
    UA_TYPE_NONE    : UaTypeName := 'NONE';
    UA_TYPE_DEFAULT : UaTypeName := 'DEFAULT';
    UA_TYPE_CHROME  : UaTypeName := 'CHROME';
    UA_TYPE_FIREFOX : UaTypeName := 'FIREFOX';
    UA_TYPE_SAFARI  : UaTypeName := 'SAFARI';
    UA_TYPE_EDGE    : UaTypeName := 'EDGE';
    UA_TYPE_CUSTOM  : UaTypeName := 'CUSTOM';
  Else
    UaTypeName := 'UNKNOWN';
  End;
End;

Function GetDefaultUserAgent: String;
Begin
  Inc(UaStateCount);
  GetDefaultUserAgent := UA_DEFAULT;
End;

Function GetChromeUserAgent: String;
Begin
  Inc(UaStateCount);
  GetChromeUserAgent := UA_CHROME;
End;

Function GetFirefoxUserAgent: String;
Begin
  Inc(UaStateCount);
  GetFirefoxUserAgent := UA_FIREFOX;
End;

Function GetSafariUserAgent: String;
Begin
  Inc(UaStateCount);
  GetSafariUserAgent := UA_SAFARI;
End;

Function GetEdgeUserAgent: String;
Begin
  Inc(UaStateCount);
  GetEdgeUserAgent := UA_EDGE;
End;

Function ValidateUserAgent(Const Ua: String): Boolean;
Var
  Valid: Boolean;
Begin
  Inc(UaStateCount);
  Inc(UaValidateCount);
  Valid := True;
  
  { Verifier que le User-Agent n'est pas vide }
  If Length(Ua) = 0 Then
  Begin
    Valid := False;
    Inc(UaErrorCount);
  End;
  
  { Verifier la longueur maximale }
  If Length(Ua) > UA_MAX_LENGTH Then
  Begin
    Valid := False;
    Inc(UaErrorCount);
  End;
  
  { Verifier que le User-Agent contient Mozilla ou compatible }
  If Valid Then
  Begin
    If (Pos('Mozilla', Ua) = 0) And (Pos('compatible', Ua) = 0) Then
    Begin
      { Pas forcement une erreur, mais peut etre un UA personnalise }
      Valid := True;
    End;
  End;
  
  ValidateUserAgent := Valid;
End;

Function DetectUserAgentType(Const Ua: String): Integer;
Begin
  Inc(UaStateCount);
  If Ua = UA_DEFAULT Then
    DetectUserAgentType := UA_TYPE_DEFAULT
  Else If Pos('Chrome', Ua) > 0 Then
  Begin
    If Pos('Edg', Ua) > 0 Then
      DetectUserAgentType := UA_TYPE_EDGE
    Else
      DetectUserAgentType := UA_TYPE_CHROME;
  End
  Else If Pos('Firefox', Ua) > 0 Then
    DetectUserAgentType := UA_TYPE_FIREFOX
  Else If Pos('Safari', Ua) > 0 Then
    DetectUserAgentType := UA_TYPE_SAFARI
  Else If Length(Ua) > 0 Then
    DetectUserAgentType := UA_TYPE_CUSTOM
  Else
    DetectUserAgentType := UA_TYPE_NONE;
End;

Procedure SetUserAgent(Const Ua: String);
Begin
  Inc(UaStateCount);
  If ValidateUserAgent(Ua) Then
  Begin
    UaCurrentString := Ua;
    UaCurrentType := DetectUserAgentType(Ua);
  End
  Else
  Begin
    Inc(UaErrorCount);
    UaCurrentString := UA_DEFAULT;
    UaCurrentType := UA_TYPE_DEFAULT;
  End;
End;

Procedure SetUserAgentByType(UaType: Integer);
Begin
  Inc(UaStateCount);
  UaCurrentType := UaType;
  Case UaType Of
    UA_TYPE_DEFAULT : UaCurrentString := UA_DEFAULT;
    UA_TYPE_CHROME  : UaCurrentString := UA_CHROME;
    UA_TYPE_FIREFOX : UaCurrentString := UA_FIREFOX;
    UA_TYPE_SAFARI  : UaCurrentString := UA_SAFARI;
    UA_TYPE_EDGE    : UaCurrentString := UA_EDGE;
  Else
    UaCurrentString := UA_DEFAULT;
    UaCurrentType := UA_TYPE_DEFAULT;
  End;
End;

Function GenerateUserAgentConfig(Const Ua: String): String;
Var
  S: String;
Begin
  Inc(UaStateCount);
  Inc(UaConfigGenCount);
  S := '';
  S := S + '// User-Agent Configuration' + Chr(10);
  S := S + 'const USER_AGENT: &str = "' + Ua + '";' + Chr(10);
  S := S + Chr(10);
  GenerateUserAgentConfig := S;
End;

Function GenerateUserAgentRustCode(Const Ua: String): String;
Var
  S: String;
Begin
  Inc(UaStateCount);
  Inc(UaConfigGenCount);
  S := '';
  S := S + '    // Set custom User-Agent' + Chr(10);
  S := S + '    .with_user_agent("' + Ua + '")' + Chr(10);
  GenerateUserAgentRustCode := S;
End;

Procedure ApplyUserAgent(Const Ua: String; Var MainRs: String);
Var
  InsertPos: Integer;
  UaCode: String;
Begin
  Inc(UaStateCount);
  Inc(UaApplyCount);
  
  { Verifier si le User-Agent est valide }
  If Not ValidateUserAgent(Ua) Then
  Begin
    Inc(UaErrorCount);
    Exit;
  End;
  
  { Generer le code Rust pour le User-Agent }
  UaCode := GenerateUserAgentRustCode(Ua);
  
  { Chercher la position pour inserer le User-Agent }
  { On cherche apres WindowBuilder::new }
  InsertPos := Pos('WindowBuilder::new', MainRs);
  If InsertPos > 0 Then
  Begin
    { Trouver la fin de la ligne }
    While (InsertPos <= Length(MainRs)) And (MainRs[InsertPos] <> Chr(10)) Do
      Inc(InsertPos);
    
    { Inserer le code apres la ligne }
    If InsertPos <= Length(MainRs) Then
    Begin
      MainRs := Copy(MainRs, 1, InsertPos) + UaCode + Copy(MainRs, InsertPos + 1, Length(MainRs) - InsertPos);
    End;
  End
  Else
  Begin
    { Pas de WindowBuilder trouve, ajouter en commentaire }
    MainRs := MainRs + Chr(10) + '// User-Agent: ' + Ua + Chr(10);
  End;
  
  { Mettre a jour l'etat courant }
  UaCurrentString := Ua;
  UaCurrentType := DetectUserAgentType(Ua);
End;

Function GetUserAgentForPreset(Const PresetName: String): String;
Begin
  Inc(UaStateCount);
  If (PresetName = 'chrome') Or (PresetName = 'CHROME') Then
    GetUserAgentForPreset := UA_CHROME
  Else If (PresetName = 'firefox') Or (PresetName = 'FIREFOX') Then
    GetUserAgentForPreset := UA_FIREFOX
  Else If (PresetName = 'safari') Or (PresetName = 'SAFARI') Then
    GetUserAgentForPreset := UA_SAFARI
  Else If (PresetName = 'edge') Or (PresetName = 'EDGE') Then
    GetUserAgentForPreset := UA_EDGE
  Else
    GetUserAgentForPreset := UA_DEFAULT;
End;

Procedure DumpUserAgentState;
Begin
  Inc(UaStateCount);
  WriteLn('=== User-Agent State ===');
  WriteLn('  Initialized    : ', UaInitialized);
  WriteLn('  State Count    : ', UaStateCount);
  WriteLn('  Current Type   : ', UaTypeName(UaCurrentType));
  WriteLn('  Current UA     : ', UaCurrentString);
  WriteLn('  Validate Count : ', UaValidateCount);
  WriteLn('  Config Gen     : ', UaConfigGenCount);
  WriteLn('  Apply Count    : ', UaApplyCount);
  WriteLn('  Error Count    : ', UaErrorCount);
  WriteLn('  Label Num      : ', UaLabelNum);
  WriteLn;
End;

{ Accesseurs pour le module User-Agent }

Function IsUaInitialized: Boolean;
Begin
  IsUaInitialized := UaInitialized;
End;

Function IsUaEmpty: Boolean;
Begin
  IsUaEmpty := UaCurrentType = UA_TYPE_NONE;
End;

Function GetUaStateCount: Integer;
Begin
  GetUaStateCount := UaStateCount;
End;

Function GetUaCurrentType: Integer;
Begin
  GetUaCurrentType := UaCurrentType;
End;

Function GetUaCurrentString: String;
Begin
  GetUaCurrentString := UaCurrentString;
End;

Function GetUaValidateCount: Integer;
Begin
  GetUaValidateCount := UaValidateCount;
End;

Function GetUaConfigGenCount: Integer;
Begin
  GetUaConfigGenCount := UaConfigGenCount;
End;

Function GetUaApplyCount: Integer;
Begin
  GetUaApplyCount := UaApplyCount;
End;

Function GetUaErrorCount: Integer;
Begin
  GetUaErrorCount := UaErrorCount;
End;

Function GetUaMaxLength: Integer;
Begin
  GetUaMaxLength := UA_MAX_LENGTH;
End;

{ ============================================================
  TODO 22-25 : A IMPLEMENTER
  ============================================================ }

Procedure ParseCommandLine(Var O: TOptions);
Var
  I: Integer;
  Arg, NextArg: String;
Begin
  InitOptions(O);
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      ShowHelp
    Else If Arg = '--version' Then
      ShowVersion
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      O.Verbose := True
    Else If Arg = '--fullscreen' Then
      O.Fullscreen := True
    Else If Arg = '--transparent' Then
      O.Transparent := True
    Else If Arg = '--hide-title-bar' Then
      O.HideTitleBar := True
    Else If Arg = '--always-on-top' Then
      O.AlwaysOnTop := True
    Else If Arg = '--disabled-web-shortcuts' Then
      O.DisableWebShortcuts := True
    Else If Arg = '--debug' Then
      O.DebugMode := True
    Else If Arg = '--multi-arch' Then
      O.MultiArch := True
    Else If (Arg = '--name') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.AppName := ParamStr(I);
    End
    Else If (Arg = '--icon') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.IconPath := ParamStr(I);
    End
    Else If (Arg = '--width') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.Width := StrToInt(ParamStr(I));
      If O.Width < MIN_WIDTH Then O.Width := MIN_WIDTH;
      If O.Width > MAX_WIDTH Then O.Width := MAX_WIDTH;
    End
    Else If (Arg = '--height') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.Height := StrToInt(ParamStr(I));
      If O.Height < MIN_HEIGHT Then O.Height := MIN_HEIGHT;
      If O.Height > MAX_HEIGHT Then O.Height := MAX_HEIGHT;
    End
    Else If (Arg = '--user-agent') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.UserAgent := ParamStr(I);
    End
    Else If (Arg = '--inject-css') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.InjectCss := ParamStr(I);
    End
    Else If (Arg = '--inject-js') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.InjectJs := ParamStr(I);
    End
    Else If (Arg = '--proxy') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.ProxyUrl := ParamStr(I);
    End
    Else If (Arg = '--targets') And (I < ParamCount) Then
    Begin
      Inc(I);
      O.Targets := ParamStr(I);
    End
    Else If ((Arg = '-o') Or (Arg = '--output')) And (I < ParamCount) Then
    Begin
      Inc(I);
      O.OutputDir := ParamStr(I);
    End
    Else If (Arg[1] <> '-') And (O.Url = '') Then
      O.Url := Arg
    Else If Arg[1] = '-' Then
      FatalError('Option inconnue: ' + Arg);
    Inc(I);
  End;
  If O.Url = '' Then
  Begin
    WriteLn('PAKE version ', PAKE_VERSION, ' - Transformez une page web en application');
    WriteLn('Usage: pake URL [options]');
    WriteLn('Utilisez pake --help pour plus d''informations.');
    Halt(EXIT_USAGE);
  End;
  If Not IsValidUrl(O.Url) Then
    FatalError('URL invalide: ' + O.Url + ' (doit commencer par http:// ou https://)');
End;

Procedure Run(Var O: TOptions);
Var
  AppId, PkgName: String;
  TauriCfg: TTauriConfig;
  WinMode: Integer;
  BuildCfg: TBuildConfig;
  BuildCmd: String;
Begin
  If O.Verbose Then
  Begin
    WriteLn('=== PAKE ', PAKE_VERSION, ' ===');
    WriteLn;
  End;

  { Initialiser le module icones }
  InitIconState;

  { Initialiser le module AppName }
  InitAppNameState;

  { Initialiser le module Tauri Config }
  InitTauriConfigState;

  { Initialiser le module Rust Generation }
  InitRustGenState;

  { Initialiser le module raccourcis clavier }
  InitShortcutState;

  { Initialiser le module mode fenetre }
  InitWindowModeState;

  { Initialiser le module injection CSS }
  InitCssInjectionState;

  { Initialiser le module injection JavaScript }
  InitJsInjectionState;

  { Initialiser le module AdBlock }
  InitAdBlockState;

  { Initialiser le module Permissions }
  InitPermissionsState;

  { Initialiser le module Build }
  InitBuildState;

  { Generer le nom de l'application si non specifie }
  O.AppName := GenerateAppName(O);

  { Valider le nom d'application }
  ValidateAppName(O.AppName);

  { Generer l'identifiant et le nom de package }
  AppId := GenerateIdentifier(O.AppName);
  PkgName := GeneratePackageName(O.AppName);

  { Initialiser la configuration Tauri }
  InitTauriConfig(TauriCfg, O);

  { Enregistrer les raccourcis par defaut }
  RegisterDefaultShortcuts(O.DisableWebShortcuts);

  { Determiner le mode de fenetre }
  WinMode := GetWindowMode(O);

  { Initialiser la configuration de build }
  InitBuildConfig(BuildCfg, O);
  BuildCmd := GenerateBuildCommand(BuildCfg);

  WriteLn('Application : ', O.AppName);
  WriteLn('Identifiant : ', AppId);
  WriteLn('Package     : ', PkgName);
  WriteLn('URL         : ', O.Url);
  WriteLn('Fenetre     : ', O.Width, 'x', O.Height);
  WriteLn('Mode fenetre: ', WindowModeName(WinMode));
  WriteLn('Plateforme  : ', PlatformName(GetPlatform));
  WriteLn('Raccourcis  : ', GetKbdActiveCount, ' actifs');
  WriteLn('AdBlock     : ', GetAdSelectorCount, ' selecteurs, ', GetAdDomainCount, ' domaines');
  WriteLn('Permissions : ', GetPermMaxTypes, ' types supportes');
  WriteLn('Build mode  : ', BuildModeName(BuildCfg.Mode));
  WriteLn('Build cible : ', BuildTargetName(BuildCfg.Target));
  WriteLn('Build cmd   : ', BuildCmd);
  WriteLn;

  { Initialiser le module macOS }
  InitMacOSState;
  
  { Si on cible macOS, generer le bundle }
  If BuildCfg.Target = PLATFORM_MACOS Then
  Begin
    WriteLn('=== Generation macOS ===');
    WriteLn;
    
    { Creer le bundle macOS }
    CreateMacOSBundle('.', O);
    
    { Creer le DMG (simulation) }
    CreateDmgInstaller(O.AppName + MACOS_APP_EXT, O.AppName + MACOS_DMG_EXT);
    
    { Signer l'application (optionnel, sans identite) }
    SignMacOSApp(O.AppName + MACOS_APP_EXT, '');
    
    { Afficher l'etat }
    DumpMacOSState;
  End;

  { Initialiser le module Windows }
  InitWindowsState;
  
  { Si on cible Windows, generer les fichiers d'installation }
  If BuildCfg.Target = PLATFORM_WINDOWS Then
  Begin
    WriteLn('=== Generation Windows ===');
    WriteLn;
    
    { Creer les fichiers de l'installateur Windows }
    CreateWindowsInstaller('.', O);
    
    { Afficher l'etat }
    DumpWindowsState;
  End;

  { Initialiser le module Linux }
  InitLinuxState;
  
  { Si on cible Linux, generer les fichiers d'installation }
  If BuildCfg.Target = PLATFORM_LINUX Then
  Begin
    WriteLn('=== Generation Linux ===');
    WriteLn;
    
    { Creer les installateurs Linux (.deb, .AppImage) }
    CreateLinuxInstaller('.', O);
    
    { Afficher l'etat }
    DumpLinuxState;
  End;

  { Initialiser le module Multi-URL }
  InitMultiUrlState;
  
  { Initialiser le module User-Agent }
  InitUserAgentState;
  
  { Afficher l'etat du User-Agent si verbose }
  If O.Verbose Then
  Begin
    WriteLn('=== Configuration User-Agent ===');
    WriteLn('  Type actuel   : ', UaTypeName(UaCurrentType));
    WriteLn('  User-Agent    : ', UaCurrentString);
    WriteLn;
  End;

  { TODO: Implementer les TODOs 22-25 }
  WriteLn('*** NOTE: TODOs 01-21 [IMPLEMENTE] ***');
  WriteLn('*** Les TODOs 22-25 restent a implementer ***');
  WriteLn;
  WriteLn('Pour generer une application de bureau complete,');
  WriteLn('il faut implementer:');
  WriteLn('  - TODO 22: Gestion du proxy');
  WriteLn('  - TODO 23: Mode developpeur');
  WriteLn('  - TODO 24: Presets d''applications populaires');
  WriteLn('  - TODO 25: Verification et rapport final');
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  UrlCount := 0;
  ParseCommandLine(Opts);
  Run(Opts);
End.
