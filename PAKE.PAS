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

  TODO 02 - FONCTIONS UTILITAIRES [A FAIRE]
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

  TODO 03 - VALIDATION DE L'URL [A FAIRE]
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

  TODO 04 - DETECTION DU SYSTEME D'EXPLOITATION [A FAIRE]
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

  TODO 05 - CONFIGURATION DE LA FENETRE [A FAIRE]
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

  TODO 06 - GESTION DES ICONES [A FAIRE]
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

  TODO 07 - GENERATION DU NOM D'APPLICATION [A FAIRE]
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

  TODO 08 - CONFIGURATION TAURI [A FAIRE]
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

  TODO 09 - GENERATION DU CODE RUST PRINCIPAL [A FAIRE]
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

  TODO 10 - GESTION DES RACCOURCIS CLAVIER [A FAIRE]
            Type TShortcut : record
              Key       : String (ex: 'CmdOrCtrl+W')
              Action    : String (ex: 'close', 'minimize', 'reload')
              Enabled   : Boolean
            End
            Constantes de raccourcis par defaut :
              SHORTCUT_CLOSE    : CmdOrCtrl+W -> cacher fenetre
              SHORTCUT_QUIT     : CmdOrCtrl+Q -> quitter
              SHORTCUT_RELOAD   : CmdOrCtrl+R -> recharger page
              SHORTCUT_ZOOM_IN  : CmdOrCtrl+= -> zoom avant
              SHORTCUT_ZOOM_OUT : CmdOrCtrl+- -> zoom arriere
              SHORTCUT_ZOOM_RESET : CmdOrCtrl+0 -> reset zoom
              SHORTCUT_BACK     : CmdOrCtrl+[ -> page precedente
              SHORTCUT_FORWARD  : CmdOrCtrl+] -> page suivante
              SHORTCUT_DEVTOOLS : CmdOrCtrl+Shift+I -> DevTools
              SHORTCUT_FULLSCREEN : F11 -> plein ecran
            Function GenerateShortcutsRs(Const Opts: TOptions): String
              generer le code Rust pour les raccourcis clavier
              utiliser tauri::GlobalShortcut
            Procedure RegisterDefaultShortcuts(Var Shortcuts: Array Of TShortcut)
              initialiser la liste des raccourcis par defaut

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
  TODO 01 : INFRASTRUCTURE ET OPTIONS [A FAIRE]
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
  TODO 02 : FONCTIONS UTILITAIRES [A FAIRE]
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

{ ============================================================
  TODO 03 : VALIDATION DE L'URL [A FAIRE]
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

{ ============================================================
  TODO 04 : DETECTION DU SYSTEME D'EXPLOITATION [A FAIRE]
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

{ ============================================================
  TODO 05-25 : A IMPLEMENTER
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
  Domain: String;
Begin
  If O.Verbose Then
  Begin
    WriteLn('=== PAKE ', PAKE_VERSION, ' ===');
    WriteLn;
  End;

  { Extraire le nom de l'application si non specifie }
  If O.AppName = '' Then
  Begin
    Domain := ExtractDomain(O.Url);
    Domain := NormalizeDomain(Domain);
    { Capitaliser la premiere lettre }
    If Length(Domain) > 0 Then
    Begin
      Domain[1] := UpCase(Domain[1]);
      { Retirer l'extension de domaine }
      If Pos('.', Domain) > 0 Then
        O.AppName := Copy(Domain, 1, Pos('.', Domain) - 1)
      Else
        O.AppName := Domain;
    End;
  End;

  WriteLn('Application : ', O.AppName);
  WriteLn('URL         : ', O.Url);
  WriteLn('Fenetre     : ', O.Width, 'x', O.Height);
  WriteLn('Plateforme  : ', PlatformName(GetPlatform));
  WriteLn;

  { TODO: Implementer les TODOs 05-25 }
  WriteLn('*** NOTE: TODOs 01-04 partiellement implementes ***');
  WriteLn('*** Les TODOs 05-25 restent a implementer ***');
  WriteLn;
  WriteLn('Pour generer une application de bureau complete,');
  WriteLn('il faut implementer:');
  WriteLn('  - TODO 05: Configuration de la fenetre');
  WriteLn('  - TODO 06: Gestion des icones');
  WriteLn('  - TODO 07: Generation du nom d''application');
  WriteLn('  - TODO 08: Configuration Tauri');
  WriteLn('  - TODO 09: Generation du code Rust principal');
  WriteLn('  - TODO 10: Gestion des raccourcis clavier');
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
