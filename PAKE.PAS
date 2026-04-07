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

  TODO 11 - MODE FENETRE IMMERSIVE [A FAIRE]
            Constantes de modes de fenetre :
              WINDOW_NORMAL = 0, WINDOW_FRAMELESS = 1,
              WINDOW_TRANSPARENT = 2, WINDOW_FULLSCREEN = 3
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

  TODO 12 - INJECTION CSS PERSONNALISE [A FAIRE]
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

  TODO 13 - INJECTION JAVASCRIPT PERSONNALISE [A FAIRE]
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

  TODO 14 - SUPPRESSION DES PUBS (ADBLOCK) [A FAIRE]
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

  TODO 15 - GESTION DES PERMISSIONS [A FAIRE]
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

  TODO 16 - CONFIGURATION DU BUILD [A FAIRE]
            Constantes de modes de build :
              BUILD_DEBUG = 0, BUILD_RELEASE = 1
            Function GenerateBuildCommand(Const Opts: TOptions): String
              generer la commande de build :
              cargo tauri build [options]
              --target si specifie
              --release pour production
            Procedure ExecuteBuild(Const WorkDir: String;
              Const Cmd: String; Verbose: Boolean)
              executer la commande de build
              capturer et afficher la sortie si Verbose
              gerer les erreurs de compilation
            Function GetBuildArtifactPath(Const WorkDir: String;
              Platform: Integer): String
              retourner le chemin de l artefact de build
            Procedure CopyBuildArtifacts(Const WorkDir, OutputDir: String;
              Platform: Integer)
              copier les artefacts vers le repertoire de sortie

  TODO 17 - GENERATION MACOS [A FAIRE]
            Constantes macOS :
              MACOS_APP_EXT = '.app', MACOS_DMG_EXT = '.dmg'
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

  TODO 18 - GENERATION WINDOWS [A FAIRE]
            Constantes Windows :
              WIN_EXE_EXT = '.exe', WIN_MSI_EXT = '.msi'
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

  TODO 19 - GENERATION LINUX [A FAIRE]
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

  TODO 20 - MULTI-URL [A FAIRE]
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

  TODO 21 - CONFIGURATION DU USER-AGENT [A FAIRE]
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
    Action  : String;
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
  Rs := Rs + '            window.eval(&format!("window.location.href = ''''{}'''''", url)).ok();' + #13#10;

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
  { Record pour un raccourci clavier }
  TShortcut = Record
    Key     : String[32];  { Combinaison de touches (ex: 'CmdOrCtrl+W') }
    Action  : Integer;     { Action a executer (KBD_ACTION_*) }
    Enabled : Boolean;     { Raccourci actif ou non }
  End;

  { Tableau de raccourcis }
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
  TODO 11-25 : A IMPLEMENTER
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

  WriteLn('Application : ', O.AppName);
  WriteLn('Identifiant : ', AppId);
  WriteLn('Package     : ', PkgName);
  WriteLn('URL         : ', O.Url);
  WriteLn('Fenetre     : ', O.Width, 'x', O.Height);
  WriteLn('Plateforme  : ', PlatformName(GetPlatform));
  WriteLn('Raccourcis  : ', GetKbdActiveCount, ' actifs');
  WriteLn;

  { TODO: Implementer les TODOs 11-25 }
  WriteLn('*** NOTE: TODOs 01-10 [IMPLEMENTE] ***');
  WriteLn('*** Les TODOs 11-25 restent a implementer ***');
  WriteLn;
  WriteLn('Pour generer une application de bureau complete,');
  WriteLn('il faut implementer:');
  WriteLn('  - TODO 11: Mode fenetre immersive');
  WriteLn('  - TODO 12: Injection CSS personnalise');
  WriteLn('  - TODO 13: Injection JavaScript personnalise');
  WriteLn('  - TODO 14: Suppression des pubs (AdBlock)');
  WriteLn('  - TODO 15: Gestion des permissions');
  WriteLn('  - TODO 16: Configuration du build');
  WriteLn('  - TODO 17: Generation macOS (.app, .dmg)');
  WriteLn('  - TODO 18: Generation Windows (.exe, .msi)');
  WriteLn('  - TODO 19: Generation Linux (.deb, .AppImage)');
  WriteLn('  - TODO 20: Multi-URL');
  WriteLn('  - TODO 21: Configuration du User-Agent');
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
