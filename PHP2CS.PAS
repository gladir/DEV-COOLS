{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Transpileur PHP vers C# (C Sharp) avec support
                des versions C# specifiques et des frameworks cibles
  @license: MIT
}

(* ============================================================
  PHP2CS.PAS - Transpileur PHP vers C# (C Sharp)
  Turbo Pascal / Free Pascal (-Mtp)
  Source : PHP 5.x / PHP 7.x / PHP 8.x
  Cible  : C# 6.0 / 7.0 / 8.0 / 9.0 / 10.0 / 11.0 / 12.0

  Produit un fichier .cs compatible avec la version C# cible
  choisie via l option -cs-version (defaut : C# 10.0).

  Frameworks cibles supportes (option -framework) :
    none            : C# pur (System, System.Collections.Generic)
    ef              : Entity Framework 6.x
    efcore          : Entity Framework Core 6/7/8
    aspnet          : ASP.NET Core (MVC/Razor Pages)
    blazor          : Blazor (Server ou WebAssembly)
    dapper          : Dapper (micro-ORM)
    adonet          : ADO.NET direct (SqlConnection, etc.)
    winforms        : Windows Forms (.NET 5+)
    wpf             : WPF (.NET 5+)
    maui            : .NET MAUI

  PLAN DE DEVELOPPEMENT - 25 TODOS
  =================================

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
            Constantes de version PHP2CS_VERSION / PHP2CS_DATE.
            Constantes de versions C# cibles :
              CS_VER_60  = '6.0'  (C# 6,  .NET 4.6 / Core 1.0)
              CS_VER_70  = '7.0'  (C# 7,  .NET 4.7 / Core 2.0)
              CS_VER_80  = '8.0'  (C# 8,  .NET Core 3.0 / Standard 2.1)
              CS_VER_90  = '9.0'  (C# 9,  .NET 5)
              CS_VER_100 = '10.0' (C# 10, .NET 6)
              CS_VER_110 = '11.0' (C# 11, .NET 7)
              CS_VER_120 = '12.0' (C# 12, .NET 8)
            Constantes de frameworks cibles :
              FW_NONE     = 0  (C# pur, pas de framework)
              FW_EF       = 1  (Entity Framework 6.x)
              FW_EFCORE   = 2  (Entity Framework Core)
              FW_ASPNET   = 3  (ASP.NET Core MVC)
              FW_BLAZOR   = 4  (Blazor)
              FW_DAPPER   = 5  (Dapper)
              FW_ADONET   = 6  (ADO.NET)
              FW_WINFORMS = 7  (Windows Forms)
              FW_WPF      = 8  (WPF)
              FW_MAUI     = 9  (.NET MAUI)
            Codes de sortie : EXIT_OK=0, EXIT_ERROR=1, EXIT_USAGE=2.
            TOptions : SrcFile, OutFile, Verbose, StrictTypes,
              CsVersion (chaine 'X.Y'), Framework (entier FW_xxx),
              EmitRegion, UseNullable, UseRecords, UseFileScopedNs.
            ParseArgs : analyser argv
              (source.php [sortie.cs] [-v] [-strict]
               [-cs-version X.Y] [-framework nom]
               [-nullable] [-records] [-file-ns] [-region])
            FatalError, WarnMsg, ItoS, UpStr, TrimStr, ChangeExt.
            ShowHelp, ShowBanner, ShowStats.
            Detecter l extension .php du fichier source.
            Programme principal : validation et appel Run.

  TODO 02 - LEXEUR PHP (TOKENS) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_OPEN_PHP (<?php), TK_CLOSE_PHP (?>),
              TK_INTEGER, TK_FLOAT, TK_STRING_SQ (chaine apostrophe),
              TK_STRING_DQ (chaine guillemets, interpolation),
              TK_HEREDOC, TK_NOWDOC, TK_IDENT, TK_KEYWORD, TK_VAR ($ident),
              TK_OP, TK_PUNCT, TK_COMMENT_LINE (//), TK_COMMENT_BLOCK (/* */),
              TK_COMMENT_DOC (/** **/), TK_HASH_COMMENT (#).
            TToken : Kind, Val (String[255]), IntVal (LongInt),
              FloatVal (Real), Line, Col.
            LexInit(Filename) : ouvrir fichier, initialiser etat lexeur.
            LexClose : fermer fichier source.
            LexNextChar / LexPeekChar : avancer / espionner caractere.
            LexNextToken : dispatcher selon premier caractere.
            LexScanIdent : lettres/chiffres/_ → TK_IDENT ou TK_KEYWORD.
            LexScanNumber : entier ou flottant (0x pour hexa, 0b binaire,
              0o octal, separateur _ numerique PHP 7.4+).
            LexScanStringSQ : 'texte' (echappement \\ et \').
            LexScanStringDQ : "texte $var {$expr}" (interpolation marquee).
            LexScanHeredoc / LexScanNowdoc : <<<LABEL / <<<'LABEL'.
            Operateurs PHP multi-chars : == === != !== <= >= <=> &&
              || ! ?? ??= -> => :: ++ -- += -= *= /= .= %= **= &= |= ^=
              <<= >>= -> ?-> (nullsafe).
            Ponctuation : ( ) [ ] { } ; , . : ? ~ @ & | ^ %.
            Mode debug (-v) : affichage de chaque token avec position.

  TODO 03 - RECONNAISSANCE DES MOTS-CLES PHP [IMPLEMENTE]
            Function IsKeyword(Const S: String): Integer
            Retourne l indice dans le tableau de mots-cles ou 0.
            Mots-cles PHP complets a reconnaitre :
              abstract array as break callable case catch class clone
              const continue declare default do echo else elseif empty
              enddeclare endfor endforeach endif endswitch endwhile enum
              eval exit extends final finally fn for foreach function
              global goto if implements include include_once instanceof
              insteadof interface isset list match namespace new null
              print private protected public readonly require require_once
              return static switch throw trait try unset use var while
              yield yield from
            Pseudo-mots-cles : false true self parent static __CLASS__
              __DIR__ __FILE__ __FUNCTION__ __LINE__ __METHOD__
              __NAMESPACE__ __TRAIT__
            Types primitifs PHP : int float string bool array object
              null void never mixed iterable callable
            Attributs PHP 8.0 : #[Attribute] (reconnaissance du #[)
            Modificateurs de visibilite : public protected private
              readonly abstract final static

  TODO 04 - TABLE DES SYMBOLES ET GESTION DES TYPES [IMPLEMENTE]
            TPhpType : PT_INT, PT_FLOAT, PT_STRING, PT_BOOL, PT_NULL,
              PT_ARRAY, PT_OBJECT, PT_MIXED, PT_VOID, PT_NEVER,
              PT_ITERABLE, PT_CALLABLE, PT_UNION (type union PHP 8.0),
              PT_INTERSECTION (type intersection PHP 8.1),
              PT_NULLABLE (prefixe ? sur type)
            TSymKind : SK_VAR, SK_PARAM, SK_GLOBAL, SK_CONST,
              SK_FUNCTION, SK_CLASS, SK_INTERFACE, SK_TRAIT,
              SK_ENUM, SK_NAMESPACE
            TSymRec : Name (String), CsName (nom C# genere), Kind,
              PhpType, Nullable, IsRef (passage par reference &$p),
              Scope (index de scope), DeclLine.
            SymAdd, SymFind, SymFindLocal, SymFindGlobal.
            TypePhpToCS(T, CsVer, Fw) : convertir type PHP en type C#
              selon la version cible et le framework :
              int  -> int / long (selon PHP_INT_SIZE)
              float -> double (PHP float = double IEEE 754)
              string -> string
              bool -> bool
              array -> List<object> ou T[] selon contexte
              null -> null (C# nullable reference types si CS 8+)
              object -> object
              mixed -> object (ou dynamic si CS 4+)
            Constantes PHP MAX_SYM, MAX_FN, MAX_CLASS, MAX_SCOPE,
              MAX_PARAM, MAX_FIELD, MAX_METHOD, MAX_USE, MAX_ERRORS.

  TODO 05 - GESTION DES SCOPES ET NAMESPACES PHP [IMPLEMENTE]
            TScope : SK_GLOBAL, SK_FUNCTION, SK_METHOD, SK_CLASS,
              SK_NAMESPACE, SK_CLOSURE, SK_ARROW_FN
            ScopeStack[1..MAX_SCOPE] : pile de scopes actifs.
            ScopeTop : sommet courant de la pile.
            ScopeEnter(Kind, Name) : empiler un nouveau scope.
            ScopeLeave : depiler le scope courant.
            ScopeCurrentName : nom du scope courant.
            ScopeIsGlobal : vrai si scope global.
            ScopeIsMethod : vrai si dans une methode de classe.
            Gestion des variables globales PHP (global $var;) :
              declare la variable comme appartenant au scope global
              meme si referencee dans une fonction.
            Gestion des variables statiques de fonction (static $var;).
            Namespaces PHP : use Foo\Bar; use Foo\Bar as Alias;
              Conversion : Foo\Bar -> Foo.Bar en C#.
            Table des use declarations : UseTable[1..MAX_USE].
            UseAdd(FqName, Alias), UseFind(Alias).

  TODO 06 - TRANSPILATION : DECLARATIONS DE VARIABLES PHP ($var) [IMPLEMENTE]
            Reconnaître les declarations de variables PHP :
              $var = expr;            -> var nom = expr; (ou type explicite)
              $var = null;            -> type? nom = null; (CS 8+ nullable)
              list($a, $b) = expr;    -> var (a, b) = expr; (CS 7+ tuples)
              [$a, $b] = expr;        -> var (a, b) = ... (CS 7+)
            Inférence de type PHP -> C# :
              Si RHS est entier literal -> int
              Si RHS est flottant -> double
              Si RHS est chaine -> string
              Si RHS est bool (true/false) -> bool
              Si RHS est null -> object? (nullable)
              Sinon -> var (inference automatique C#)
            Gestion des declarations avec type hint PHP 7+ :
              int $var = ...; float $var = ...;
            Transpilation des variables statiques de fonction :
              static $var = val; -> champ statique prive de la classe
              englobante ou propriete statique d une classe helper.
            Variables superglobales PHP :
              $_GET -> HttpContext.Request.Query (ASP.NET)
                    -> Dictionary<string,string> (C# pur)
              $_POST -> HttpContext.Request.Form (ASP.NET)
              $_SESSION -> HttpContext.Session (ASP.NET)
              $_COOKIE -> HttpContext.Request.Cookies (ASP.NET)
              $_SERVER -> stub Dictionary<string,string>
              $_ENV -> Environment.GetEnvironmentVariable(...)
              $_FILES -> IFormFile (ASP.NET)
              $GLOBALS -> stub (champ statique de classe)

  TODO 07 - TRANSPILATION : EXPRESSIONS [IMPLEMENTE]
            Parseur d expressions PHP avec precedence complete :
              Niveau 1  : yield / yield from
              Niveau 2  : ternaire ? :, ternaire court ?:
              Niveau 3  : operateur null-coalescing ?? et ??=
              Niveau 4  : or / and / xor (mots-cles)
              Niveau 5  : || &&
              Niveau 6  : | ^ &
              Niveau 7  : == === != !== <=>
              Niveau 8  : < <= > >=
              Niveau 9  : << >>
              Niveau 10 : + - .
              Niveau 11 : * / %
              Niveau 12 : ** (puissance)
              Niveau 13 : instanceof, cast, ++/-- (unaires), ! ~ -
            Transpilation des operateurs :
              .  (concat.) -> + (C#)
              === -> == (C#, avec avertissement si types differents)
              !== -> != (C#)
              <=> -> Comparer.Compare (stub ou expression)
              ** -> Math.Pow(...) (C#, double)
              ??  -> ?? (C# 6+ null-coalescing)
              ??= -> ??= (C# 8+ null-coalescing assignment)
              ?-> -> ?. (C# 6+ null-conditional)
              @ (suppresseur d erreur) -> ignorer (commentaire C#)
            Casts PHP :
              (int) -> (int)
              (float) -> (double)
              (string) -> .ToString()
              (bool) -> (bool) ou != 0 selon contexte
              (array) -> wrapper List<object>
              (object) -> stub
            Constantes magiques :
              __LINE__ -> numero de ligne source (int literal)
              __FILE__ -> chemin du fichier source (string)
              __CLASS__ -> nom de classe courant (nameof(ClassName))
              __METHOD__ -> nom de methode courant (nameof(Method))
              __FUNCTION__ -> nom de fonction courant (nameof(Fn))

  TODO 08 - TRANSPILATION : CHAINES ET INTERPOLATION [IMPLEMENTE]
            Chaines simples '' : LexScanStringSQ → "@'...'" ou "..."
              Echappements reconnus : \\ \' (autres passes tel quel).
            Chaines doubles "" avec interpolation :
              LexScanStringDQ : detecter $var et {$expr} dans la chaine.
              Decomposer la chaine en segments texte + expressions.
              Generer une expression de concatenation C# :
                "debut" + var + "milieu" + expr + "fin"
              Ou utiliser l interpolation C# $"..." si CS 6+ :
                $"debut{var}milieu{expr}fin"
            Heredoc <<<EOT...EOT : traiter comme chaine double.
            Nowdoc <<<'EOT'...EOT : traiter comme chaine simple.
            Sequences d echappement dans chaines doubles :
              \n -> \n, \t -> \t, \r -> \r, \$ -> (literal $),
              \\ -> \\, \" -> \", \0 -> \0, \xHH -> \xHH,
              \uHHHH -> \uHHHH (PHP 7+), \e -> (ESC, 0x1B).
            Fonctions de format PHP :
              sprintf(fmt, ...) -> string.Format(fmt_cs, ...) ou
                $"..." interpole (selon complexite du format)
              printf(fmt, ...) -> Console.Write(string.Format(...))
              number_format(n, dec) -> n.ToString("F{dec}")
              str_pad -> PadLeft / PadRight
              wordwrap -> stub commentaire

  TODO 09 - TRANSPILATION : STRUCTURES DE CONTROLE [IMPLEMENTE]
            Transpilation de if / elseif / else / endif :
              PHP : if(expr): ... elseif(expr): ... else: ... endif;
              C# : if(expr){...} else if(expr){...} else{...}
              Syntaxe alternative PHP (: ... endif) supportee.
            Transpilation de match (PHP 8.0) :
              PHP : match(expr){ val => expr, default => expr }
              C# : switch expression (CS 8+) :
                expr switch { val => expr, _ => expr }
              Si CS < 8 : if/else chain.
            Transpilation de declare(strict_types=1) :
              Ajouter commentaire // strict_types=1 en tete CS.
              Activer le mode StrictTypes dans TOptions.
            Transpilation de declare(ticks=N) : commentaire stub.
            Transpilation de declare(encoding='X') : commentaire stub.
            Transpilation de goto label; et label: :
              C# : goto label; label: (si CS supporte)
              Avertissement sur usage de goto.

  TODO 10 - TRANSPILATION : BOUCLES [IMPLEMENTE]
            Transpilation de for($i=0; $i<n; $i++) :
              C# : for(int i=0; i<n; i++) (avec inference de type)
            Transpilation de foreach($arr as $val) :
              C# : foreach(var val in arr)
            Transpilation de foreach($arr as $key => $val) :
              Si tableau associatif (Dictionary) :
                foreach(var kvp in arr) { var key=kvp.Key; var val=kvp.Value; }
              Si List<T> : foreach(var val in arr) avec index manuel.
            Transpilation de while(expr) / do...while(expr).
            Transpilation de break N (break avec profondeur PHP) :
              break 1; -> break; (C#)
              break 2; -> break; avec label goto si N>1 (stub)
              Avertissement si N>1.
            Transpilation de continue N : similaire a break N.
            Syntaxe alternative PHP (endfor, endforeach, endwhile) :
              Convertir vers accolades C# normales.

  TODO 11 - TRANSPILATION : SWITCH ET MATCH [IMPLEMENTE]
            Transpilation de switch($var) / case val: / default: :
              C# : switch(var){ case val: ... break; default: ... }
              Detecter le fall-through PHP (absence de break) :
                Avertissement + ajout de goto case val; en C#
                  ou commentaire // fall-through.
              switch avec chaines : convertir literaux string PHP.
            Transpilation de match PHP 8.0 :
              match($x){ 1,2 => 'a', default => 'b' }
              Si CS >= 8.0 : switch expression
                x switch { 1 or 2 => "a", _ => "b" }
              Si CS < 8.0 : switch statement avec return.
            Transpilation de match sans default :
              C# : switch expression sans _ (UnmatchedValueException)
              Avertissement si pas de default/_.

  TODO 12 - TRANSPILATION : FONCTIONS PHP [A FAIRE]
            Transpilation de function foo($a, $b) { ... } :
              C# : static RetType Foo(ParamType a, ParamType b) { ... }
              Inference du type de retour si possible.
              Type hint PHP 7+ : function foo(int $a): string { ... }
                -> string Foo(int a) { ... }
            Transpilation des parametres :
              Valeurs par defaut : $a = 0 -> int a = 0
              Reference : &$a -> ref T a (avertissement C# limitations)
              Variadiques : ...$args -> params object[] args
              Type union PHP 8+ : int|string $a -> object a (avec stub)
              Named arguments PHP 8 : foo(name: $val) -> foo(name: val)
            Transpilation de return $val; / return; :
              C# : return val; / return;
            Fonctions anonymes PHP (closures) :
              $fn = function($x) use ($y) { return $x+$y; };
              C# : var fn = (int x) => x + y; (CS 3+ lambda)
              use ($y) : capture de variable externe (closure) :
                Variables capturees par valeur -> variables locales capturees.
                Variables capturees par reference (&$y) -> ref capture stub.
            Arrow functions PHP 7.4 :
              $fn = fn($x) => $x * 2;
              C# : var fn = (int x) => x * 2; (expression lambda)
            Fonctions generatrices (yield) : stub avec commentaire.

  TODO 13 - TRANSPILATION : CLASSES PHP (OOP) [A FAIRE]
            Transpilation de class Foo extends Bar implements Baz :
              C# : class Foo : Bar, Baz { ... }
              Modificateurs : abstract class -> abstract class,
                final class -> sealed class (C#),
                readonly class PHP 8.2 -> readonly class (C# 10+)
                  ou class classique si CS < 10.
            Proprietes de classe (champs PHP) :
              public $prop = val; -> public Type Prop { get; set; }
              protected/private $prop : visibilite conservee.
              Type hint : public string $name; -> public string Name { ... }
              Proprietes readonly PHP 8.1 :
                public readonly string $name; -> public string Name { get; init; }
                ou : public readonly string Name; (CS 9+)
            Methodes de classe :
              public function foo() : -> public RetType Foo()
              static function foo() : -> public static RetType Foo()
              abstract function foo() : -> public abstract RetType Foo();
              final function foo() : -> pas d equivalent direct (commentaire)
              Constructeur __construct() -> constructeur C# ClassName()
              Destructeur __destruct() -> Dispose() / finalizer ~ClassName()
            Constantes de classe : const FOO = val; -> public const Type FOO = val;
            Proprietes statiques : static $count; -> public static int Count;
            Methodes magiques :
              __toString -> override string ToString()
              __get / __set -> indexeur ou propriete (stub)
              __invoke -> operateur () (stub ou delegate)
              __clone -> MemberwiseClone() (Clone() interface)
            Classe anonyme PHP 7+ : new class{...} -> stub avec commentaire.

  TODO 14 - TRANSPILATION : INTERFACES ET TRAITS PHP [A FAIRE]
            Transpilation d interface :
              interface Foo extends Bar, Baz { ... }
              C# : interface IFoo : IBar, IBaz { ... }
              Convention : ajouter prefixe I au nom d interface.
              Constantes d interface PHP -> const dans interface C#.
              Methodes d interface avec corps PHP 8 (default method) :
                -> methode d extension ou abstract class (stub + commentaire).
            Transpilation de trait :
              trait Foo { use Bar; ... }
              C# : pas d equivalent direct.
              Strategie de transpilation des traits :
                Generer une classe abstraite partielle helper :
                  partial class __Trait_Foo { ... }
                Injecter les membres dans les classes qui font use Foo.
              use Foo, Bar insteadof Baz : commentaire de resolution de conflit.
              use Foo { method as alias; } : renommage de methode.
              Avertissement sur l utilisation des traits (C# n a pas d equivalent).
            Transpilation d enum PHP 8.1 :
              enum Status { case Active; case Inactive; }
              C# : enum Status { Active, Inactive } (CS 5+)
              enum backed PHP : enum Color: string { case Red = 'red'; }
                C# : pas d enum backed natif ; generer classe statique :
                  static class Color { public const string Red = "red"; ... }
                  ou record struct (CS 9+) selon version cible.

  TODO 15 - TRANSPILATION : TABLEAUX PHP (array / []) [A FAIRE]
            Tableaux indexes PHP :
              $arr = [1, 2, 3]; -> var arr = new List<int>{1,2,3};
                ou int[] arr = {1,2,3}; selon contexte (CS 12 : [1,2,3])
              $arr[] = val; -> arr.Add(val);
              $arr[i] -> arr[i]
              count($arr) -> arr.Count
              array_push($arr, val) -> arr.Add(val)
              array_pop($arr) -> arr[arr.Count-1] + arr.RemoveAt(...)
              array_shift / array_unshift -> arr.RemoveAt(0) / arr.Insert(0,v)
              array_reverse($arr) -> arr.Reverse() / LINQ .Reverse()
              array_slice($arr, off, len) -> arr.GetRange(off,len)
              sort($arr) -> arr.Sort()
              rsort($arr) -> arr.Sort(); arr.Reverse()
              in_array($v,$arr) -> arr.Contains(v)
              array_search($v,$arr) -> arr.IndexOf(v)
              array_unique($arr) -> arr.Distinct().ToList() (LINQ)
              array_merge($a,$b) -> a.Concat(b).ToList()
              array_map($fn,$arr) -> arr.Select(fn).ToList() (LINQ)
              array_filter($arr,$fn) -> arr.Where(fn).ToList() (LINQ)
              array_reduce($arr,$fn,$init) -> arr.Aggregate(init,fn) (LINQ)
            Tableaux associatifs PHP :
              $arr = ['key' => val]; -> var arr = new Dictionary<string,object>{{"key",val}};
              $arr['key'] -> arr["key"]
              $arr['key'] = val; -> arr["key"] = val;
              array_keys($arr) -> arr.Keys.ToList()
              array_values($arr) -> arr.Values.ToList()
              isset($arr['key']) -> arr.ContainsKey("key")
              unset($arr['key']) -> arr.Remove("key")
            Tableaux multidimensionnels : List<List<T>> ou T[,] selon forme.
            Transpilation de list() et destructuration [] (voir TODO 06).
            Fonctions utilitaires additionnelles :
              implode / join -> string.Join(sep, arr)
              explode -> str.Split(sep)
              array_chunk -> Chunk (CS 6+) ou stub boucle

  TODO 16 - TRANSPILATION : FONCTIONS DE CHAINES PHP [A FAIRE]
            Fonctions de longueur et sous-chaines :
              strlen($s) -> s.Length
              substr($s, start) -> s.Substring(start) ou s[start..] (CS 8+)
              substr($s, start, len) -> s.Substring(start,len)
              strpos($s, $needle) -> s.IndexOf(needle)
              strrpos($s, $needle) -> s.LastIndexOf(needle)
              str_contains($s, $needle) -> s.Contains(needle) (CS)
              str_starts_with / str_ends_with -> StartsWith / EndsWith
            Fonctions de modification :
              strtolower -> s.ToLower() / s.ToLowerInvariant()
              strtoupper -> s.ToUpper() / s.ToUpperInvariant()
              ucfirst -> char.ToUpper(s[0]) + s.Substring(1) (helper)
              lcfirst -> char.ToLower(s[0]) + s.Substring(1) (helper)
              ucwords -> helper CultureInfo.TextInfo.ToTitleCase
              trim / ltrim / rtrim -> s.Trim() / TrimStart / TrimEnd
              str_replace($search,$repl,$subj) -> subj.Replace(search,repl)
              str_ireplace -> Regex.Replace(..., RegexOptions.IgnoreCase)
              str_repeat($s, n) -> new string(s[0],n) ou string.Concat(Enumerable.Repeat(s,n))
              str_pad -> PadLeft / PadRight avec caractere de remplissage
              chunk_split -> helper boucle
              wordwrap -> helper boucle
              nl2br($s) -> s.Replace("\n","<br />\n") (HTML)
            Fonctions de recherche et remplacement avancees :
              preg_match($pat, $subj, $matches) -> Regex.Match stub
              preg_replace($pat, $repl, $subj) -> Regex.Replace stub
              preg_split($pat, $subj) -> Regex.Split stub
              preg_match_all -> Regex.Matches stub
            Fonctions de conversion :
              ord($s) -> (int)s[0]
              chr($n) -> ((char)n).ToString()
              bin2hex / hex2bin -> Convert.ToHexString / FromHexString
              base64_encode / base64_decode -> Convert.ToBase64String / FromBase64String
              md5 / sha1 -> System.Security.Cryptography stubs
              crc32 -> stub avec commentaire
            Fonctions d affichage : echo / print :
              echo $val; -> Console.Write(val);
              echo "$a $b"; -> Console.Write($"{a} {b}"); (CS 6+)
              print $val; -> Console.Write(val);
              print_r / var_dump -> commentaire stub + Console.WriteLine

  TODO 17 - TRANSPILATION : FONCTIONS MATHEMATIQUES ET DATE/HEURE [A FAIRE]
            Fonctions mathematiques PHP -> System.Math :
              abs($x) -> Math.Abs(x)
              ceil($x) -> Math.Ceiling(x)
              floor($x) -> Math.Floor(x)
              round($x, n) -> Math.Round(x, n)
              sqrt($x) -> Math.Sqrt(x)
              pow($x, $y) -> Math.Pow(x, y)
              max($a, $b) -> Math.Max(a, b)
              min($a, $b) -> Math.Min(a, b)
              fmod($x, $y) -> x % y (double)
              intdiv($a, $b) -> (int)(a / b)
              pi() -> Math.PI
              exp($x) -> Math.Exp(x)
              log($x) -> Math.Log(x)
              log10($x) -> Math.Log10(x)
              sin/cos/tan -> Math.Sin/Cos/Tan
              asin/acos/atan/atan2 -> Math.Asin/Acos/Atan/Atan2
              rand($min,$max) -> new Random().Next(min,max+1)
              mt_rand($min,$max) -> new Random().Next(min,max+1)
              number_format voir TODO 08.
            Fonctions date/heure PHP -> System.DateTime / DateTimeOffset :
              time() -> DateTimeOffset.UtcNow.ToUnixTimeSeconds()
              microtime(true) -> (double)DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0
              date($fmt, $ts) -> DateTimeOffset.FromUnixTimeSeconds(ts).ToString(fmt_cs)
              mktime(...) -> new DateTime(...) + ToUnixTimeSeconds()
              strtotime($s) -> DateTime.Parse(s) stub
              date_create / date_diff -> DateTime stubs
              checkdate($m,$d,$y) -> DateTime.TryParse stub

  TODO 18 - TRANSPILATION : GESTION DES EXCEPTIONS [A FAIRE]
            Transpilation de try / catch / finally / throw :
              PHP : try { ... } catch(ExType $e) { ... } finally { ... }
              C# : try { ... } catch(ExType e) { ... } finally { ... }
              Exceptions PHP standards -> exceptions C# equivalentes :
                Exception -> Exception
                RuntimeException -> RuntimeException (ou Exception)
                InvalidArgumentException -> ArgumentException
                LogicException -> InvalidOperationException
                BadFunctionCallException -> NotSupportedException
                OutOfRangeException -> ArgumentOutOfRangeException
                OverflowException -> OverflowException
                DomainException -> InvalidOperationException
                TypeError -> InvalidCastException
                ValueError -> ArgumentException
                Error (PHP 7+) -> Exception ou Error classe custom
                ParseError -> FormatException
                ArithmeticError -> ArithmeticException
                DivisionByZeroError -> DivideByZeroException
              Bloc catch multiple PHP 8.0 (catch(TypeA|TypeB $e)) :
                CS 6+ : catch(Exception e) when (e is TypeA or TypeB)
                CS < 6 : deux blocs catch separates.
              Transpilation de throw $e; -> throw e;
              Throw expression PHP 8.0 ($x ??= throw new E()) :
                CS 7+ : throw expression native.
                CS < 7 : extraire dans instruction separee.
              set_exception_handler / restore_exception_handler : stubs.
              set_error_handler : stub avec commentaire.

  TODO 19 - TRANSPILATION : NAMESPACES ET IMPORTS PHP [A FAIRE]
            Transpilation de namespace Foo\Bar; :
              C# : namespace Foo.Bar (ou namespace Foo.Bar; si CS 10+ et -file-ns)
              Remplacer \ par . dans les noms de namespace.
            Transpilation de use Foo\Bar; :
              C# : using Foo.Bar; (en tete du fichier C#)
            Transpilation de use Foo\Bar as Baz; :
              C# : using Baz = Foo.Bar;
            Transpilation de use function Foo\bar; : commentaire stub.
            Transpilation de use const Foo\BAR; : commentaire stub.
            Transpilation de use Foo\{ Bar, Baz }; (PHP 7, group use) :
              Generer un using par element du groupe.
            Espaces de noms imbriques PHP :
              namespace Foo\Bar\Baz; -> namespace Foo.Bar.Baz;
            Ajout automatique des using selon framework cible
              (voir TODO 24 pour la generation de l en-tete complet) :
              none    : using System; using System.Collections.Generic;
              ef      : + using System.Data.Entity;
              efcore  : + using Microsoft.EntityFrameworkCore;
              aspnet  : + using Microsoft.AspNetCore.Mvc;
              blazor  : + using Microsoft.AspNetCore.Components;
              dapper  : + using Dapper; + using System.Data;
              adonet  : + using System.Data; + using System.Data.SqlClient;
              winforms: + using System.Windows.Forms;
              wpf     : + using System.Windows; + using System.Windows.Controls;
              maui    : + using Microsoft.Maui; + using Microsoft.Maui.Controls;

  TODO 20 - TRANSPILATION : INCLUDE / REQUIRE PHP [A FAIRE]
            include 'fichier.php' / include_once 'fichier.php' :
              C# : commentaire // #include "fichier.php" + stub
              Option : traiter l include de facon recursive
                (charger le fichier inclus et le transpiler aussi).
            require 'fichier.php' / require_once 'fichier.php' :
              Identique a include mais signaler une erreur fatale
              si le fichier n est pas trouve (commentaire TODO).
            Autoloading PHP (spl_autoload_register) : stub commentaire.
            Transpilation des fichiers PHP multi-fichiers :
              Generer un fichier .cs par fichier .php source.
              Ou concatener tout dans un seul .cs (option -single).
            Gestion du marqueur PHP <?php ... ?> :
              Reconnaitre l ouverture <?php et la fermeture ?>.
              Code HTML hors balises PHP :
                Generer Console.Write("...html..."); (mode CLI).
                Ou : Response.Write("...") pour ASP.NET.
                Ou : commentaire stub avec avertissement.
            Short echo tag <?= expr ?> :
              C# : Console.Write(expr); ou Response.Write(expr);

  TODO 21 - CIBLE FRAMEWORK : ENTITY FRAMEWORK / EF CORE [A FAIRE]
            Mode active par -framework ef ou -framework efcore.
            Reconnaitre les patterns PHP typiques d acces BD :
              PDO / mysqli / pg_connect / mysql_connect stubs.
            Transpiler la logique d acces aux donnees PHP vers EF/EF Core :
              Classe derivee de DbContext :
                class AppDbContext : DbContext { ... }
              DbSet<T> properties pour chaque entite detectee.
              Methodes CRUD generiques :
                Create -> context.Entity.Add(obj); context.SaveChanges();
                Read   -> context.Entity.Find(id) ou LINQ
                Update -> context.Entry(obj).State = EntityState.Modified;
                Delete -> context.Entity.Remove(obj); context.SaveChanges();
              Transactions PHP -> using(var tx = ctx.Database.BeginTransaction())
            Patterns PDO -> EF Core :
              $pdo->query($sql) -> context.Database.ExecuteSqlRaw(sql)
              $stmt->fetchAll() -> context.Entity.FromSqlRaw(sql).ToList()
              $pdo->prepare($sql) -> parametre SqlParameter stub
            Annotations/attributs EF Core (CS 8+) :
              [Key], [Required], [MaxLength(n)], [Column("col")],
              [Table("tab")], [ForeignKey("col")], [Index("col")]
            Migrations EF Core : stub commentaire avec instructions.
            EF6 vs EF Core : differences d API gerees selon -framework ef|efcore.

  TODO 22 - CIBLE FRAMEWORK : ASP.NET CORE / BLAZOR [A FAIRE]
            Mode active par -framework aspnet ou -framework blazor.
            Transpilation des fonctions PHP web vers ASP.NET Core :
              header('Content-Type: ...')
                -> Response.ContentType = "..."
              header('Location: url')
                -> return Redirect("url");
              session_start() -> services.AddSession() stub
              $_SESSION['key'] -> HttpContext.Session.GetString("key")
              setcookie($name,$val,$exp) -> Response.Cookies.Append(...)
              $_COOKIE['key'] -> Request.Cookies["key"]
              ob_start / ob_get_clean -> stub StringWriter
            Structure MVC pour -framework aspnet :
              Classe controller derivee de ControllerBase ou Controller :
                [ApiController] ou [Controller]
                [Route("[controller]")]
              Actions HTTP : [HttpGet], [HttpPost], [HttpPut], [HttpDelete]
              Parametres de route : [Route("{id}")]
              Model binding : [FromBody], [FromQuery], [FromRoute]
              IActionResult : Ok(), NotFound(), BadRequest(), etc.
            Structure Blazor pour -framework blazor :
              Composants .razor (generes comme classes C# avec attributs Blazor).
              @inject, @code, @bind stubs.
              EventCallback, StateHasChanged, InvokeAsync stubs.
            Validation de modele :
              PHP : if(empty($name)) ... -> [Required] + ModelState.IsValid
            Authentification / autorisation :
              PHP sessions -> [Authorize] attribute stub.

  TODO 23 - CIBLE FRAMEWORK : DAPPER ET ADO.NET [A FAIRE]
            Mode active par -framework dapper ou -framework adonet.
            Transpilation des requetes SQL PHP inline :
              Reconnaitre les chaines SQL dans le code PHP :
                $sql = "SELECT * FROM users WHERE id = $id";
                $sql = sprintf("INSERT INTO t VALUES(%d)", $v);
              Parametrisation C# :
                Dapper : connection.Query<T>("SELECT...", new { id })
                ADO.NET : SqlCommand avec SqlParameter (anti-injection)
              Avertissement sur concatenation de chaines SQL (injection).
            Pattern Dapper typique :
              using(var conn = new SqlConnection(cs))
              {
                var results = conn.Query<T>("SELECT...", params).ToList();
              }
            Pattern ADO.NET :
              using(var conn = new SqlConnection(cs))
              using(var cmd = new SqlCommand(sql, conn))
              {
                conn.Open();
                cmd.Parameters.AddWithValue("@p", val);
                using(var rdr = cmd.ExecuteReader()) { ... }
              }
            Fonctions PHP mysqli / PDO -> ADO.NET :
              $conn = new PDO($dsn, $user, $pass)
                -> new SqlConnection(connectionString)
              $stmt = $pdo->prepare($sql) -> new SqlCommand(sql, conn)
              $stmt->bindParam(':p', $val) -> cmd.Parameters.AddWithValue
              $stmt->execute() -> cmd.ExecuteNonQuery()
              $stmt->fetchAll() -> SqlDataReader while(rdr.Read())
              $stmt->rowCount() -> cmd.ExecuteNonQuery() (affected rows)
            Chaine de connexion : generer stub avec TODO commentaire.
            Support de MySQL (MySqlConnection), PostgreSQL (NpgsqlConnection),
              SQLite (SqliteConnection) selon indicateur de DSN detecte.

  TODO 24 - GENERATION DE L EN-TETE C# ET CONFIGURABILITE [A FAIRE]
            EmitHeader(Opts) : generer l en-tete complet du fichier C# cible.
            Contenu de l en-tete selon version C# et framework :
              Commentaire d en-tete : // Generated by PHP2CS vX.Y
              Commentaire source : // Source: fichier.php
              Commentaire version : // Target: C# X.Y
              Commentaire framework si applicable.
            Directives using selon framework (voir TODO 19).
            Directive nullable pour CS 8+ :
              #nullable enable (si -nullable et CS >= 8.0)
            Directive implicit usings pour CS 10+ :
              generer un fichier GlobalUsings.cs stub si -implicit-usings.
            Directive langversion pour projet .csproj :
              Generer un fichier .csproj minimal si -emit-csproj :
                <Project Sdk="Microsoft.NET.Sdk">
                  <PropertyGroup>
                    <OutputType>Exe / Library</OutputType>
                    <TargetFramework>netX.Y</TargetFramework>
                    <LangVersion>X.Y</LangVersion>
                    <Nullable>enable</Nullable>
                  </PropertyGroup>
                  <ItemGroup> (PackageReference pour EF/Dapper/etc.) </ItemGroup>
                </Project>
            Version C# -> Target Framework mapping :
              CS 6.0  -> net46 / netstandard2.0
              CS 7.0  -> net47 / netstandard2.0
              CS 8.0  -> netcoreapp3.1 / netstandard2.1
              CS 9.0  -> net5.0
              CS 10.0 -> net6.0
              CS 11.0 -> net7.0
              CS 12.0 -> net8.0
            PackageReference selon framework cible :
              ef      : EntityFramework 6.x
              efcore  : Microsoft.EntityFrameworkCore + provider
              aspnet  : Microsoft.AspNetCore.App (metapackage)
              blazor  : Microsoft.AspNetCore.Components.Web
              dapper  : Dapper
              adonet  : System.Data.SqlClient ou Microsoft.Data.SqlClient
              winforms: Microsoft.WindowsDesktop.App.WindowsForms
              wpf     : Microsoft.WindowsDesktop.App.WPF
              maui    : Microsoft.Maui.Controls
            EmitRegion(Name) / EmitEndRegion : balises #region si -region.
            EmitFileNs : namespace au niveau fichier (CS 10+ si -file-ns).

  TODO 25 - FINALISATION, RAPPORT ET EXEMPLES [A FAIRE]
            Finalisation de la generation C# :
              EmitClose : fermer le fichier de sortie .cs.
              Fermer les blocs ouverts (namespace, class) si necessaire.
              Detecter et signaler les blocs non fermes (avertissement).
            Rapport de transpilation (si -v) :
              Nombre de lignes PHP lues.
              Nombre de lignes C# emises.
              Nombre de fonctions transpirees.
              Nombre de classes transpirees.
              Nombre d avertissements emis.
              Nombre d erreurs rencontrees.
              Version C# cible utilisee.
              Framework cible utilise.
              Fonctionnalites PHP non transpirees (stub list).
            Gestion de la sortie standard si pas de fichier de sortie :
              Ecrire le C# genere dans stdout (UNIX pipe friendly).
            Fichiers d exemples a creer dans SAMPLES\PHP2CS\ :
              hello.php    -> hello.cs (echo Hello World)
              class.php    -> class.cs (classe simple OOP)
              array.php    -> array.cs (manipulations de tableaux)
              pdo.php      -> pdo_ef.cs (acces BD via PDO → EF Core)
              web.php      -> web.cs (formulaire HTML → ASP.NET Core)
            Tests de regression :
              Verifier que les exemples compilent avec csc / dotnet build.
              Suite de tests TDD dans TESTS\PHP2CS\ :
                test_vars.php, test_funcs.php, test_classes.php,
                test_arrays.php, test_strings.php, test_loops.php,
                test_exceptions.php, test_namespaces.php
            Documentation :
              DOC\TODO\PHP2CS.txt : feuille de route detaillee.
              README de PHP2CS dans le fichier source (commentaires).
  ============================================================ *)

Program PHP2CS;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

Const
  PHP2CS_VERSION = '0.1';
  PHP2CS_DATE    = '2026';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Versions C# cibles }
  CS_VER_60  = '6.0';
  CS_VER_70  = '7.0';
  CS_VER_80  = '8.0';
  CS_VER_90  = '9.0';
  CS_VER_100 = '10.0';
  CS_VER_110 = '11.0';
  CS_VER_120 = '12.0';
  CS_VER_DEF = CS_VER_100; { Version C# cible par defaut }

  { Frameworks cibles }
  FW_NONE     = 0;  { C# pur, pas de framework          }
  FW_EF       = 1;  { Entity Framework 6.x              }
  FW_EFCORE   = 2;  { Entity Framework Core             }
  FW_ASPNET   = 3;  { ASP.NET Core MVC                  }
  FW_BLAZOR   = 4;  { Blazor                            }
  FW_DAPPER   = 5;  { Dapper                            }
  FW_ADONET   = 6;  { ADO.NET                           }
  FW_WINFORMS = 7;  { Windows Forms                     }
  FW_WPF      = 8;  { WPF                               }
  FW_MAUI     = 9;  { .NET MAUI                         }

  { Limites des tables internes }
  MAX_SYM    = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_FN     = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_CLASS  = {$IFDEF FPC}128{$ELSE}16{$ENDIF};
  MAX_SCOPE  = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PARAM  = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_FIELD  = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_METHOD = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_USE    = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_ERRORS = {$IFDEF FPC}100{$ELSE}20{$ENDIF};
  MAX_STR    = 255;

{ ============================================================
  TYPES
  ============================================================ }

Type
  TString = String[MAX_STR];

  { Options du transpileur }
  TOptions = Record
    SrcFile      : TString;   { fichier PHP source                    }
    OutFile      : TString;   { fichier C# de sortie                  }
    Verbose      : Boolean;   { mode verbeux (-v)                     }
    StrictTypes  : Boolean;   { strict_types=1 force (-strict)        }
    CsVersion    : TString;   { version C# cible (ex: '10.0')         }
    Framework    : Integer;   { framework cible (FW_*)                }
    EmitRegion   : Boolean;   { emettre #region / #endregion (-region)}
    UseNullable  : Boolean;   { #nullable enable (-nullable)          }
    UseRecords   : Boolean;   { utiliser les records CS 9+ (-records) }
    UseFileScopedNs: Boolean; { namespace au niveau fichier (-file-ns)}
    EmitCsproj   : Boolean;   { generer un .csproj minimal (-csproj)  }
    SingleFile   : Boolean;   { tout dans un seul .cs (-single)       }
  End;

  { Type PHP }
  TPhpType = (
    PT_INT,          { int                                            }
    PT_FLOAT,        { float (double IEEE 754)                        }
    PT_STRING,       { string                                         }
    PT_BOOL,         { bool                                           }
    PT_NULL,         { null                                           }
    PT_ARRAY,        { array                                          }
    PT_OBJECT,       { object                                         }
    PT_MIXED,        { mixed                                          }
    PT_VOID,         { void                                           }
    PT_NEVER,        { never (PHP 8.1)                               }
    PT_ITERABLE,     { iterable                                       }
    PT_CALLABLE,     { callable                                       }
    PT_UNION,        { type union  int|string  (PHP 8.0)             }
    PT_INTERSECTION, { type intersection A&B   (PHP 8.1)             }
    PT_NULLABLE,     { type nullable ?T         (prefixe ?)           }
    PT_UNKNOWN       { type non determine                             }
  );

  { Categorie de symbole }
  TSymKind = (
    SK_VAR,        { variable locale $var                             }
    SK_PARAM,      { parametre de fonction                            }
    SK_GLOBAL,     { variable globale (global $var)                   }
    SK_STATIC_VAR, { variable statique de fonction (static $var)      }
    SK_CONST,      { constante PHP (define/const)                     }
    SK_FUNCTION,   { fonction PHP                                     }
    SK_CLASS,      { classe PHP                                       }
    SK_INTERFACE,  { interface PHP                                     }
    SK_TRAIT,      { trait PHP                                        }
    SK_ENUM,       { enum PHP 8.1                                     }
    SK_NAMESPACE   { namespace PHP                                     }
  );

  { Enregistrement symbole }
  TSymRec = Record
    Name     : TString;   { nom PHP (sans $)                          }
    CsName   : TString;   { nom C# genere                             }
    Kind     : TSymKind;
    PhpType  : TPhpType;
    Nullable : Boolean;   { type nullable (?T)                        }
    IsRef    : Boolean;   { parametre par reference (&$p)             }
    Scope    : Integer;   { indice du scope parent                    }
    DeclLine : Integer;   { ligne de declaration dans la source PHP   }
  End;

  { Token PHP }
  TTokenKind = (
    TK_EOF,
    TK_OPEN_PHP,    { <?php ou <?                                     }
    TK_CLOSE_PHP,   { ?>                                              }
    TK_INTEGER,     { litteral entier                                 }
    TK_FLOAT,       { litteral flottant                               }
    TK_STRING_SQ,   { 'chaine simple'                                 }
    TK_STRING_DQ,   { "chaine double avec $interpolation"             }
    TK_HEREDOC,     { <<<EOT...EOT                                    }
    TK_NOWDOC,      { <<<'EOT'...EOT                                  }
    TK_IDENT,       { identificateur                                  }
    TK_KEYWORD,     { mot-cle PHP                                     }
    TK_VAR,         { variable $ident                                 }
    TK_OP,          { operateur                                       }
    TK_PUNCT,       { ponctuation                                     }
    TK_COMMENT_LINE,  { // ou #                                       }
    TK_COMMENT_BLOCK, { /* ... */                                     }
    TK_COMMENT_DOC    { /** ... */                                    }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;
    IntVal   : LongInt;
    FloatVal : Real;
    Line     : Integer;
    Col      : Integer;
  End;

  { Scope PHP }
  TScopeKind = (
    SCK_GLOBAL,
    SCK_FUNCTION,
    SCK_METHOD,
    SCK_CLASS,
    SCK_NAMESPACE,
    SCK_CLOSURE,
    SCK_ARROW_FN
  );

  TScopeRec = Record
    Kind : TScopeKind;
    Name : TString;
  End;

  { Declaration use PHP : use Foo\Bar; ou use Foo\Bar as Alias; }
  TUseRec = Record
    FqName : TString;   { nom pleinement qualifie PHP (Foo\Bar)       }
    Alias  : TString;   { alias (Bar par defaut, ou alias explicite)  }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }

Var
  Opts       : TOptions;
  SrcF       : Text;       { fichier PHP source ouvert               }
  OutF       : Text;       { fichier C# de sortie ouvert             }
  OutFOpen   : Boolean;

  { Table des symboles }
  SymTab     : Array[1..MAX_SYM] of TSymRec;
  SymCount   : Integer;

  { Pile de scopes }
  ScopeStack : Array[1..MAX_SCOPE] of TScopeRec;
  ScopeTop   : Integer;

  { Table des declarations use PHP }
  UseTable   : Array[1..MAX_USE] of TUseRec;
  UseCount   : Integer;

  { Namespace courant (vide si aucun) }
  CurrentNs  : TString;

  { Token courant }
  CurTok     : TToken;

  { Etat du lexeur }
  LexLine    : Integer;
  LexCol     : Integer;
  LexCh      : Char;
  LexEOF     : Boolean;
  LexPeekCh  : Char;    { caractere espion (un niveau de lookahead)      }
  LexHasPeek : Boolean; { True si LexPeekCh est valide                  }

  { Statistiques }
  ErrorCount : Integer;
  WarnCount  : Integer;
  LinesRead  : Integer;
  LinesEmit  : Integer;
  FnCount    : Integer;
  ClassCount : Integer;

{ ============================================================
  UTILITAIRES GENERAUX
  ============================================================ }

Function ItoS(N: LongInt): TString;
Var S: TString;
Begin
  Str(N, S);
  ItoS := S;
End;

Function UpStr(S: TString): TString;
Var I: Integer;
Begin
  For I := 1 To Length(S) Do
    If (S[I] >= 'a') And (S[I] <= 'z') Then
      S[I] := Chr(Ord(S[I]) - 32);
  UpStr := S;
End;

Function LowStr(S: TString): TString;
Var I: Integer;
Begin
  For I := 1 To Length(S) Do
    If (S[I] >= 'A') And (S[I] <= 'Z') Then
      S[I] := Chr(Ord(S[I]) + 32);
  LowStr := S;
End;

Function TrimStr(S: TString): TString;
Var B, E: Integer;
Begin
  B := 1;
  E := Length(S);
  While (B <= E) And (S[B] <= ' ') Do Inc(B);
  While (E >= B) And (S[E] <= ' ') Do Dec(E);
  If B > E Then TrimStr := ''
           Else TrimStr := Copy(S, B, E - B + 1);
End;

Function ChangeExt(S, NewExt: TString): TString;
Var I: Integer;
Begin
  I := Length(S);
  While (I > 0) And (S[I] <> '.') And (S[I] <> '\') And (S[I] <> '/') Do
    Dec(I);
  If (I > 0) And (S[I] = '.') Then
    ChangeExt := Copy(S, 1, I - 1) + NewExt
  Else
    ChangeExt := S + NewExt;
End;

Function ExtractExt(S: TString): TString;
Var I: Integer;
Begin
  I := Length(S);
  While (I > 0) And (S[I] <> '.') And (S[I] <> '\') And (S[I] <> '/') Do
    Dec(I);
  If (I > 0) And (S[I] = '.') Then
    ExtractExt := Copy(S, I, Length(S) - I + 1)
  Else
    ExtractExt := '';
End;

Function FileExists(Const Name: TString): Boolean;
Var F: File;
Begin
  Assign(F, Name);
  {$I-}
  Reset(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

{ ============================================================
  GESTION DES ERREURS
  ============================================================ }

Procedure FatalError(Const Msg: TString);
Begin
  WriteLn('PHP2CS: erreur fatale: ', Msg);
  Inc(ErrorCount);
  If OutFOpen Then Close(OutF);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg: TString);
Begin
  WriteLn('PHP2CS: avertissement: ', Msg);
  Inc(WarnCount);
End;

{ ============================================================
  AFFICHAGE
  ============================================================ }

Function FrameworkName(FW: Integer): TString;
Begin
  Case FW Of
    FW_NONE    : FrameworkName := 'none';
    FW_EF      : FrameworkName := 'ef';
    FW_EFCORE  : FrameworkName := 'efcore';
    FW_ASPNET  : FrameworkName := 'aspnet';
    FW_BLAZOR  : FrameworkName := 'blazor';
    FW_DAPPER  : FrameworkName := 'dapper';
    FW_ADONET  : FrameworkName := 'adonet';
    FW_WINFORMS: FrameworkName := 'winforms';
    FW_WPF     : FrameworkName := 'wpf';
    FW_MAUI    : FrameworkName := 'maui';
  Else
    FrameworkName := 'inconnu';
  End;
End;

Function CsVersionValid(Const V: TString): Boolean;
Begin
  CsVersionValid := (V = CS_VER_60) Or (V = CS_VER_70) Or
                    (V = CS_VER_80) Or (V = CS_VER_90) Or
                    (V = CS_VER_100) Or (V = CS_VER_110) Or
                    (V = CS_VER_120);
End;

Procedure ShowBanner;
Begin
  WriteLn('PHP2CS v', PHP2CS_VERSION, ' (', PHP2CS_DATE, ')');
  WriteLn('Transpileur PHP vers C# ', Opts.CsVersion,
          ' (framework: ', FrameworkName(Opts.Framework), ')');
  WriteLn;
End;

Procedure ShowHelp;
Begin
  WriteLn('PHP2CS - Transpileur PHP vers C#');
  WriteLn;
  WriteLn('Syntaxe : PHP2CS source.php [sortie.cs] [options]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -v                Mode verbeux');
  WriteLn('  -strict           Activer strict_types');
  WriteLn('  -cs-version X.Y   Version C# cible (defaut: ', CS_VER_DEF, ')');
  WriteLn('                    Valeurs: 6.0 7.0 8.0 9.0 10.0 11.0 12.0');
  WriteLn('  -framework nom    Framework cible (defaut: none)');
  WriteLn('                    Valeurs: none ef efcore aspnet blazor');
  WriteLn('                             dapper adonet winforms wpf maui');
  WriteLn('  -nullable         Activer #nullable enable (CS 8+)');
  WriteLn('  -records          Utiliser les records C# (CS 9+)');
  WriteLn('  -file-ns          Namespace au niveau fichier (CS 10+)');
  WriteLn('  -region           Emettre #region / #endregion');
  WriteLn('  -csproj           Generer un fichier .csproj minimal');
  WriteLn('  -single           Tout generer dans un seul fichier .cs');
  WriteLn('  -h /?             Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  PHP2CS hello.php hello.cs');
  WriteLn('  PHP2CS app.php app.cs -cs-version 10.0 -framework efcore -nullable');
  WriteLn('  PHP2CS web.php web.cs -framework aspnet -cs-version 8.0');
End;

Procedure ShowStats;
Begin
  WriteLn('PHP2CS: --- Rapport de transpilation ---');
  WriteLn('PHP2CS: lignes PHP lues   : ', LinesRead);
  WriteLn('PHP2CS: lignes C# emises  : ', LinesEmit);
  WriteLn('PHP2CS: fonctions         : ', FnCount);
  WriteLn('PHP2CS: classes           : ', ClassCount);
  WriteLn('PHP2CS: avertissements    : ', WarnCount);
  WriteLn('PHP2CS: erreurs           : ', ErrorCount);
  WriteLn('PHP2CS: version C# cible  : ', Opts.CsVersion);
  WriteLn('PHP2CS: framework cible   : ', FrameworkName(Opts.Framework));
End;

{ ============================================================
  ANALYSE DES ARGUMENTS
  ============================================================ }

Procedure ParseArgs;
Var I: Integer; S: TString;
Begin
  Opts.SrcFile       := '';
  Opts.OutFile       := '';
  Opts.Verbose       := False;
  Opts.StrictTypes   := False;
  Opts.CsVersion     := CS_VER_DEF;
  Opts.Framework     := FW_NONE;
  Opts.EmitRegion    := False;
  Opts.UseNullable   := False;
  Opts.UseRecords    := False;
  Opts.UseFileScopedNs := False;
  Opts.EmitCsproj    := False;
  Opts.SingleFile    := False;

  I := 1;
  While I <= ParamCount Do
  Begin
    S := ParamStr(I);
    If (S = '-v') Or (S = '--verbose') Then
      Opts.Verbose := True
    Else If (S = '-strict') Then
      Opts.StrictTypes := True
    Else If (S = '-nullable') Then
      Opts.UseNullable := True
    Else If (S = '-records') Then
      Opts.UseRecords := True
    Else If (S = '-file-ns') Then
      Opts.UseFileScopedNs := True
    Else If (S = '-region') Then
      Opts.EmitRegion := True
    Else If (S = '-csproj') Then
      Opts.EmitCsproj := True
    Else If (S = '-single') Then
      Opts.SingleFile := True
    Else If (S = '-cs-version') And (I < ParamCount) Then
    Begin
      Inc(I);
      Opts.CsVersion := ParamStr(I);
    End
    Else If (S = '-framework') And (I < ParamCount) Then
    Begin
      Inc(I);
      S := UpStr(ParamStr(I));
      If S = 'NONE'     Then Opts.Framework := FW_NONE
      Else If S = 'EF'       Then Opts.Framework := FW_EF
      Else If S = 'EFCORE'   Then Opts.Framework := FW_EFCORE
      Else If S = 'ASPNET'   Then Opts.Framework := FW_ASPNET
      Else If S = 'BLAZOR'   Then Opts.Framework := FW_BLAZOR
      Else If S = 'DAPPER'   Then Opts.Framework := FW_DAPPER
      Else If S = 'ADONET'   Then Opts.Framework := FW_ADONET
      Else If S = 'WINFORMS' Then Opts.Framework := FW_WINFORMS
      Else If S = 'WPF'      Then Opts.Framework := FW_WPF
      Else If S = 'MAUI'     Then Opts.Framework := FW_MAUI
      Else WarnMsg('framework inconnu: ' + ParamStr(I));
    End
    Else If (Length(S) > 0) And (S[1] <> '-') Then
    Begin
      If Opts.SrcFile = '' Then Opts.SrcFile := S
      Else If Opts.OutFile = '' Then Opts.OutFile := S;
    End;
    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    ShowHelp;
    Halt(EXIT_USAGE);
  End;

  { Verifier l extension .php du fichier source }
  If UpStr(ExtractExt(Opts.SrcFile)) <> '.PHP' Then
    WarnMsg('le fichier source n a pas l extension .php: ' + Opts.SrcFile);

  { Verifier l existence du fichier source }
  If Not FileExists(Opts.SrcFile) Then
    FatalError('fichier source introuvable: ' + Opts.SrcFile);

  { Valider la version C# cible }
  If Not CsVersionValid(Opts.CsVersion) Then
  Begin
    WarnMsg('version C# inconnue: ' + Opts.CsVersion +
            ', defaut utilise: ' + CS_VER_DEF);
    Opts.CsVersion := CS_VER_DEF;
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ChangeExt(Opts.SrcFile, '.cs');
End;

{ ============================================================
  TODO 02 - LEXEUR PHP (TOKENS) [IMPLEMENTE]
  ============================================================ }

{ ============================================================
  TODO 03 - RECONNAISSANCE DES MOTS-CLES PHP [IMPLEMENTE]
  ============================================================ }

Const
  PHP_KW_COUNT  = 88;   { nombre total de mots-cles PHP reconnus        }
  PHP_KW_MAXLEN = 15;   { longueur max d un mot-cle (__namespace__ = 13) }

{ Tableau trie des mots-cles PHP (casse minuscule) pour recherche binaire }
Const
  PhpKeywords : Array[1..PHP_KW_COUNT] of String[PHP_KW_MAXLEN] = (
    { __ magiques }
    '__class__',    '__dir__',      '__file__',     '__function__',
    '__line__',     '__method__',   '__namespace__','__trait__',
    { a }
    'abstract',     'array',        'as',
    { b }
    'bool',         'break',
    { c }
    'callable',     'case',         'catch',        'class',
    'clone',        'const',        'continue',
    { d }
    'declare',      'default',      'do',
    { e }
    'echo',         'else',         'elseif',       'empty',
    'enddeclare',   'endfor',       'endforeach',   'endif',
    'endswitch',    'endwhile',     'enum',         'eval',
    'exit',         'extends',
    { f }
    'false',        'final',        'finally',      'float',
    'fn',           'for',          'foreach',      'function',
    { g }
    'global',       'goto',
    { i }
    'if',           'implements',   'include',      'include_once',
    'instanceof',   'insteadof',    'int',          'interface',
    'isset',        'iterable',
    { l }
    'list',
    { m }
    'match',        'mixed',
    { n }
    'namespace',    'never',        'new',          'null',
    { o }
    'object',
    { p }
    'parent',       'print',        'private',      'protected',
    'public',
    { r }
    'readonly',     'require',      'require_once', 'return',
    { s }
    'self',         'static',       'string',       'switch',
    { t }
    'throw',        'trait',        'true',         'try',
    { u }
    'unset',        'use',
    { v }
    'var',          'void',
    { w }
    'while',
    { y }
    'yield'
  );

{ IsKeyword : retourne l indice (1..PHP_KW_COUNT) du mot-cle, ou 0 si absent.
  La comparaison est insensible a la casse (normalisation en minuscules).
  Utilise une recherche binaire sur le tableau trie PhpKeywords.           }
Function IsKeyword(Const S: TString): Integer;
Var
  Lo, Hi, Mid : Integer;
  LS           : TString;
Begin
  If Length(S) > PHP_KW_MAXLEN Then
  Begin
    IsKeyword := 0;
    Exit;
  End;
  LS := LowStr(S);
  Lo := 1;
  Hi := PHP_KW_COUNT;
  While Lo <= Hi Do
  Begin
    Mid := (Lo + Hi) Div 2;
    If PhpKeywords[Mid] = LS Then
    Begin
      IsKeyword := Mid;
      Exit;
    End
    Else If PhpKeywords[Mid] < LS Then
      Lo := Mid + 1
    Else
      Hi := Mid - 1;
  End;
  IsKeyword := 0;
End;

Function TokenKindStr(K: TTokenKind): TString;
Begin
  Case K Of
    TK_EOF          : TokenKindStr := 'EOF';
    TK_OPEN_PHP     : TokenKindStr := 'OPEN_PHP';
    TK_CLOSE_PHP    : TokenKindStr := 'CLOSE_PHP';
    TK_INTEGER      : TokenKindStr := 'INTEGER';
    TK_FLOAT        : TokenKindStr := 'FLOAT';
    TK_STRING_SQ    : TokenKindStr := 'STRING_SQ';
    TK_STRING_DQ    : TokenKindStr := 'STRING_DQ';
    TK_HEREDOC      : TokenKindStr := 'HEREDOC';
    TK_NOWDOC       : TokenKindStr := 'NOWDOC';
    TK_IDENT        : TokenKindStr := 'IDENT';
    TK_KEYWORD      : TokenKindStr := 'KEYWORD';
    TK_VAR          : TokenKindStr := 'VAR';
    TK_OP           : TokenKindStr := 'OP';
    TK_PUNCT        : TokenKindStr := 'PUNCT';
    TK_COMMENT_LINE : TokenKindStr := 'COMMENT_LINE';
    TK_COMMENT_BLOCK: TokenKindStr := 'COMMENT_BLOCK';
    TK_COMMENT_DOC  : TokenKindStr := 'COMMENT_DOC';
  Else
    TokenKindStr := '?';
  End;
End;

Procedure LexNextChar;
Var Ch: Char;
Begin
  If LexHasPeek Then
  Begin
    Ch := LexPeekCh;
    LexHasPeek := False;
  End
  Else If EOF(SrcF) Then
  Begin
    LexEOF := True;
    LexCh  := #0;
    Exit;
  End
  Else
    Read(SrcF, Ch);
  LexCh := Ch;
  If Ch = #10 Then
  Begin
    Inc(LexLine);
    LexCol := 0;
    Inc(LinesRead);
  End
  Else If Ch <> #13 Then
    Inc(LexCol);
End;

Function LexPeekChar: Char;
Begin
  If LexHasPeek Then
    LexPeekChar := LexPeekCh
  Else If EOF(SrcF) Then
    LexPeekChar := #0
  Else
  Begin
    Read(SrcF, LexPeekCh);
    LexHasPeek := True;
    LexPeekChar := LexPeekCh;
  End;
End;

Procedure LexScanIdent;
Var S: TString; KwIdx: Integer;
Begin
  S := '';
  While LexCh In ['a'..'z','A'..'Z','0'..'9','_'] Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCh;
    LexNextChar;
  End;
  KwIdx := IsKeyword(S);
  CurTok.Val := S;
  If KwIdx > 0 Then
    CurTok.Kind := TK_KEYWORD
  Else
    CurTok.Kind := TK_IDENT;
End;

Procedure LexScanNumber;
Var S: TString; IsFloat: Boolean; ErrCode: Integer;
Begin
  S := '';
  IsFloat := False;
  { Prefixes 0x (hexa), 0b (binaire), 0o (octal) }
  If (LexCh = '0') And (LexPeekChar In ['x','X','b','B','o','O']) Then
  Begin
    S := '0';
    LexNextChar;
    If Length(S) < MAX_STR Then S := S + LexCh;
    LexNextChar;
    While LexCh In ['0'..'9','a'..'f','A'..'F','_'] Do
    Begin
      If LexCh <> '_' Then
        If Length(S) < MAX_STR Then S := S + LexCh;
      LexNextChar;
    End;
  End
  Else
  Begin
    While LexCh In ['0'..'9','_'] Do
    Begin
      If LexCh <> '_' Then
        If Length(S) < MAX_STR Then S := S + LexCh;
      LexNextChar;
    End;
    { Partie decimale }
    If (LexCh = '.') And (LexPeekChar In ['0'..'9']) Then
    Begin
      IsFloat := True;
      If Length(S) < MAX_STR Then S := S + '.';
      LexNextChar;
      While LexCh In ['0'..'9','_'] Do
      Begin
        If LexCh <> '_' Then
          If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End;
    End;
    { Exposant e/E }
    If LexCh In ['e','E'] Then
    Begin
      IsFloat := True;
      If Length(S) < MAX_STR Then S := S + LexCh;
      LexNextChar;
      If LexCh In ['+','-'] Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End;
      While LexCh In ['0'..'9'] Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End;
    End;
  End;
  CurTok.Val := S;
  If IsFloat Then
  Begin
    CurTok.Kind := TK_FLOAT;
    Val(S, CurTok.FloatVal, ErrCode);
    If ErrCode <> 0 Then CurTok.FloatVal := 0.0;
  End
  Else
  Begin
    CurTok.Kind := TK_INTEGER;
    Val(S, CurTok.IntVal, ErrCode);
    If ErrCode <> 0 Then CurTok.IntVal := 0;
  End;
End;

Procedure LexScanStringSQ;
Var S: TString;
Begin
  S := '';
  LexNextChar; { ignore guillemet ouvrant ' }
  While (Not LexEOF) And (LexCh <> '''') Do
  Begin
    If LexCh = '\' Then
    Begin
      If LexPeekChar In ['''','\'] Then
      Begin
        LexNextChar; { ignore \ }
        If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + LexCh;
      LexNextChar;
    End;
  End;
  If Not LexEOF Then LexNextChar; { ignore guillemet fermant ' }
  CurTok.Kind := TK_STRING_SQ;
  CurTok.Val  := S;
End;

Procedure LexScanStringDQ;
Var S: TString;
Begin
  S := '';
  LexNextChar; { ignore guillemet ouvrant " }
  While (Not LexEOF) And (LexCh <> '"') Do
  Begin
    If LexCh = '\' Then
    Begin
      If Length(S) < MAX_STR Then S := S + '\';
      LexNextChar;
      If Not LexEOF Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + LexCh;
      LexNextChar;
    End;
  End;
  If Not LexEOF Then LexNextChar; { ignore guillemet fermant " }
  CurTok.Kind := TK_STRING_DQ;
  CurTok.Val  := S;
End;

Procedure LexScanHeredocNowdoc;
Var
  HLabel   : TString;
  IsNowdoc : Boolean;
  S, HLine : TString;
Begin
  IsNowdoc := False;
  HLabel   := '';
  While LexCh In [' ',#9] Do LexNextChar; { espace apres <<< }
  If LexCh = '''' Then
  Begin
    IsNowdoc := True;
    LexNextChar; { ignore ' ouvrant }
  End
  Else If LexCh = '"' Then
    LexNextChar; { ignore " ouvrant optionnel }
  While LexCh In ['a'..'z','A'..'Z','0'..'9','_'] Do
  Begin
    If Length(HLabel) < MAX_STR Then HLabel := HLabel + LexCh;
    LexNextChar;
  End;
  If IsNowdoc And (LexCh = '''') Then LexNextChar; { ignore ' fermant }
  While (Not LexEOF) And (LexCh <> #10) Do LexNextChar; { fin de ligne }
  If Not LexEOF Then LexNextChar; { ignore le saut de ligne }
  S := '';
  While Not LexEOF Do
  Begin
    HLine := '';
    While (Not LexEOF) And (LexCh <> #10) Do
    Begin
      If Length(HLine) < MAX_STR Then HLine := HLine + LexCh;
      LexNextChar;
    End;
    If Not LexEOF Then LexNextChar; { ignore le saut de ligne }
    { Terminateur : label seul ou label suivi de ; }
    If (HLine = HLabel) Or (HLine = HLabel + ';') Then Break;
    If S <> '' Then
      If Length(S) < MAX_STR Then S := S + #10;
    If Length(S) + Length(HLine) <= MAX_STR Then
      S := S + HLine;
  End;
  CurTok.Val := S;
  If IsNowdoc Then
    CurTok.Kind := TK_NOWDOC
  Else
    CurTok.Kind := TK_HEREDOC;
End;

Procedure LexNextToken;
Var S: TString; Peek: Char;
Begin
  While (Not LexEOF) And (LexCh In [' ',#9,#10,#13]) Do
    LexNextChar;
  CurTok.Line    := LexLine;
  CurTok.Col     := LexCol;
  CurTok.IntVal  := 0;
  CurTok.FloatVal := 0.0;
  CurTok.Val     := '';
  If LexEOF Then
  Begin
    CurTok.Kind := TK_EOF;
    If Opts.Verbose Then
      WriteLn('[Lex] EOF at ', CurTok.Line, ':', CurTok.Col);
    Exit;
  End;
  Peek := LexPeekChar;
  Case LexCh Of
    '<': Begin
      If Peek = '?' Then
      Begin
        LexNextChar; LexNextChar; { apres <? }
        If LexCh In ['p','P'] Then
          If LexPeekChar In ['h','H'] Then
          Begin
            LexNextChar; { h }
            If LexPeekChar In ['p','P'] Then
              LexNextChar; { p }
            LexNextChar; { avance apres php }
          End;
        If LexCh = '=' Then LexNextChar; { <?= }
        CurTok.Kind := TK_OPEN_PHP;
        CurTok.Val  := '<?php';
      End
      Else If Peek = '<' Then
      Begin
        LexNextChar; { deuxieme < }
        If LexPeekChar = '<' Then
        Begin
          LexNextChar; { troisieme < }
          LexNextChar; { avance vers le label }
          LexScanHeredocNowdoc;
        End
        Else If LexPeekChar = '=' Then
        Begin
          LexNextChar; LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '<<=';
        End
        Else
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '<<';
        End;
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '>' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '<=>';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '<=';
        End;
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '<';
      End;
    End;
    '>': Begin
      If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '>=';
      End
      Else If Peek = '>' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '=' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '>>=';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '>>';
        End;
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '>';
      End;
    End;
    '=': Begin
      If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '=' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '===';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '==';
        End;
      End
      Else If Peek = '>' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '=>';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '=';
      End;
    End;
    '!': Begin
      If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '=' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '!==';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '!=';
        End;
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '!';
      End;
    End;
    '&': Begin
      If Peek = '&' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '&&';
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '&=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '&';
      End;
    End;
    '|': Begin
      If Peek = '|' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '||';
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '|=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '|';
      End;
    End;
    '^': Begin
      If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '^=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '^';
      End;
    End;
    '+': Begin
      If Peek = '+' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '++';
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '+=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '+';
      End;
    End;
    '-': Begin
      If Peek = '-' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '--';
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '-=';
      End
      Else If Peek = '>' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '->';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '-';
      End;
    End;
    '*': Begin
      If Peek = '*' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '=' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '**=';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '**';
        End;
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '*=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '*';
      End;
    End;
    '/': Begin
      If Peek = '/' Then
      Begin
        LexNextChar; LexNextChar; { ignore // }
        S := '//';
        While (Not LexEOF) And (LexCh <> #10) Do
        Begin
          If Length(S) < MAX_STR Then S := S + LexCh;
          LexNextChar;
        End;
        CurTok.Kind := TK_COMMENT_LINE;
        CurTok.Val  := S;
      End
      Else If Peek = '*' Then
      Begin
        LexNextChar; LexNextChar; { ignore /* }
        If LexCh = '*' Then
        Begin
          S := '/**';
          LexNextChar;
          CurTok.Kind := TK_COMMENT_DOC;
        End
        Else
        Begin
          S := '/*';
          CurTok.Kind := TK_COMMENT_BLOCK;
        End;
        While Not LexEOF Do
        Begin
          If (LexCh = '*') And (LexPeekChar = '/') Then
          Begin
            LexNextChar; LexNextChar; { ignore */ }
            Break;
          End;
          If Length(S) < MAX_STR Then S := S + LexCh;
          LexNextChar;
        End;
        CurTok.Val := S;
      End
      Else If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '/=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '/';
      End;
    End;
    '%': Begin
      If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '%=';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '%';
      End;
    End;
    '.': Begin
      If Peek = '=' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '.=';
      End
      Else If Peek = '.' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '.' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '...';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '..';
        End;
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '.';
      End;
    End;
    ':': Begin
      If Peek = ':' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_OP; CurTok.Val := '::';
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := ':';
      End;
    End;
    '?': Begin
      If Peek = '>' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_CLOSE_PHP; CurTok.Val := '?>';
      End
      Else If Peek = '?' Then
      Begin
        LexNextChar; LexNextChar;
        If LexCh = '=' Then
        Begin
          LexNextChar;
          CurTok.Kind := TK_OP; CurTok.Val := '??=';
        End
        Else
        Begin
          CurTok.Kind := TK_OP; CurTok.Val := '??';
        End;
      End
      Else If Peek = '-' Then
      Begin
        { ?-> operateur nullsafe : consume ? et -, puis verifie > }
        LexNextChar; { LexCh = '-' }
        If LexPeekChar = '>' Then
        Begin
          LexNextChar; LexNextChar; { ignore > }
          CurTok.Kind := TK_OP; CurTok.Val := '?->';
        End
        Else
        Begin
          { Pas ?-> : produire ? et laisser - pour le prochain token }
          CurTok.Kind := TK_PUNCT; CurTok.Val := '?';
        End;
      End
      Else
      Begin
        LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '?';
      End;
    End;
    '#': Begin
      If Peek = '[' Then
      Begin
        LexNextChar; LexNextChar;
        CurTok.Kind := TK_PUNCT; CurTok.Val := '#[';
      End
      Else
      Begin
        LexNextChar;
        S := '#';
        While (Not LexEOF) And (LexCh <> #10) Do
        Begin
          If Length(S) < MAX_STR Then S := S + LexCh;
          LexNextChar;
        End;
        CurTok.Kind := TK_COMMENT_LINE;
        CurTok.Val  := S;
      End;
    End;
    '$': Begin
      LexNextChar; { ignore $ }
      S := '';
      While LexCh In ['a'..'z','A'..'Z','0'..'9','_'] Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCh;
        LexNextChar;
      End;
      CurTok.Kind := TK_VAR;
      CurTok.Val  := S;
    End;
    '''': LexScanStringSQ;
    '"' : LexScanStringDQ;
    '0'..'9': LexScanNumber;
    'a'..'z','A'..'Z','_': LexScanIdent;
    '(': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := '('; End;
    ')': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := ')'; End;
    '[': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := '['; End;
    ']': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := ']'; End;
    '{': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := '{'; End;
    '}': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := '}'; End;
    ';': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := ';'; End;
    ',': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := ','; End;
    '~': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := '~'; End;
    '@': Begin LexNextChar; CurTok.Kind := TK_PUNCT; CurTok.Val := '@'; End;
  Else
    LexNextChar; { caractere inconnu : ignorer }
    LexNextToken; { recommencer }
    Exit;
  End;
  If Opts.Verbose Then
    WriteLn('[Lex] ', TokenKindStr(CurTok.Kind), '(', CurTok.Val,
            ') at ', CurTok.Line, ':', CurTok.Col);
End;

Procedure LexInit(Const Filename: TString);
Begin
  Assign(SrcF, Filename);
  Reset(SrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier: ' + Filename);
  LexLine    := 1;
  LexCol     := 0;
  LexEOF     := False;
  LexHasPeek := False;
  LexPeekCh  := #0;
  LexNextChar; { lire le premier caractere dans LexCh }
End;

Procedure LexClose;
Begin
  If Not LexEOF Then
  Begin
    Close(SrcF);
    LexEOF := True;
  End;
End;

{ ============================================================
  TODO 03 - MOTS-CLES PHP (IMPLEMENTE)
  TODO 04 - TABLE DES SYMBOLES ET TYPES (IMPLEMENTE)
  TODO 05 - GESTION DES SCOPES ET NAMESPACES (IMPLEMENTE)
  TODO 06 - DECLARATIONS DE VARIABLES PHP (IMPLEMENTE)
  TODO 07 - EXPRESSIONS (IMPLEMENTE)
  TODO 08 - CHAINES ET INTERPOLATION (IMPLEMENTE)
  TODO 09 - STRUCTURES DE CONTROLE (IMPLEMENTE)
  TODO 10 - BOUCLES (IMPLEMENTE)
  TODO 11 - SWITCH ET MATCH (IMPLEMENTE)
  TODO 12 - FONCTIONS PHP (A FAIRE)
  TODO 13 - CLASSES PHP (A FAIRE)
  TODO 14 - INTERFACES ET TRAITS PHP (A FAIRE)
  TODO 15 - TABLEAUX PHP (A FAIRE)
  TODO 16 - FONCTIONS DE CHAINES (A FAIRE)
  TODO 17 - FONCTIONS MATH ET DATE/HEURE (A FAIRE)
  TODO 18 - GESTION DES EXCEPTIONS (A FAIRE)
  TODO 19 - NAMESPACES ET IMPORTS (A FAIRE)
  TODO 20 - INCLUDE / REQUIRE (A FAIRE)
  TODO 21 - CIBLE : ENTITY FRAMEWORK / EF CORE (A FAIRE)
  TODO 22 - CIBLE : ASP.NET CORE / BLAZOR (A FAIRE)
  TODO 23 - CIBLE : DAPPER ET ADO.NET (A FAIRE)
  TODO 24 - GENERATION DE L EN-TETE C# (A FAIRE)
  TODO 25 - FINALISATION, RAPPORT ET EXEMPLES (A FAIRE)
  ============================================================ }

{ ============================================================
  TODO 04 - TABLE DES SYMBOLES ET GESTION DES TYPES [IMPLEMENTE]
  ============================================================ }

{ Retourne un ordinal numerique pour une version C# afin de la comparer }
Function CsVerOrdinal(Const V: TString): Integer;
Begin
  If      V = CS_VER_60  Then CsVerOrdinal := 60
  Else If V = CS_VER_70  Then CsVerOrdinal := 70
  Else If V = CS_VER_80  Then CsVerOrdinal := 80
  Else If V = CS_VER_90  Then CsVerOrdinal := 90
  Else If V = CS_VER_100 Then CsVerOrdinal := 100
  Else If V = CS_VER_110 Then CsVerOrdinal := 110
  Else If V = CS_VER_120 Then CsVerOrdinal := 120
  Else                        CsVerOrdinal := 0;
End;

{ Retourne vrai si la version V est >= la version minimale Min }
Function CsVersionGE(Const V, Min: TString): Boolean;
Begin
  CsVersionGE := CsVerOrdinal(V) >= CsVerOrdinal(Min);
End;

{ Convertit un nom PHP (snake_case / mixte) en PascalCase C# }
Function MakeCsName(Const PhpName: TString): TString;
Var
  I   : Integer;
  Cap : Boolean;
  S, R: TString;
Begin
  S   := PhpName;
  R   := '';
  Cap := True;
  For I := 1 To Length(S) Do
  Begin
    If S[I] = '_' Then
      Cap := True
    Else
    Begin
      If Cap Then
      Begin
        If Length(R) < MAX_STR Then
          R := R + UpStr(Copy(S, I, 1));
        Cap := False;
      End
      Else
        If Length(R) < MAX_STR Then
          R := R + S[I];
    End;
  End;
  If R = '' Then R := S;
  MakeCsName := R;
End;

{ Retourne le TPhpType correspondant au nom de type PHP (insensible casse) }
Function PhpTypeFromStr(Const S: TString): TPhpType;
Var LS: TString;
Begin
  LS := LowStr(S);
  If      LS = 'int'       Then PhpTypeFromStr := PT_INT
  Else If LS = 'integer'   Then PhpTypeFromStr := PT_INT
  Else If LS = 'float'     Then PhpTypeFromStr := PT_FLOAT
  Else If LS = 'double'    Then PhpTypeFromStr := PT_FLOAT
  Else If LS = 'string'    Then PhpTypeFromStr := PT_STRING
  Else If LS = 'bool'      Then PhpTypeFromStr := PT_BOOL
  Else If LS = 'boolean'   Then PhpTypeFromStr := PT_BOOL
  Else If LS = 'null'      Then PhpTypeFromStr := PT_NULL
  Else If LS = 'array'     Then PhpTypeFromStr := PT_ARRAY
  Else If LS = 'object'    Then PhpTypeFromStr := PT_OBJECT
  Else If LS = 'mixed'     Then PhpTypeFromStr := PT_MIXED
  Else If LS = 'void'      Then PhpTypeFromStr := PT_VOID
  Else If LS = 'never'     Then PhpTypeFromStr := PT_NEVER
  Else If LS = 'iterable'  Then PhpTypeFromStr := PT_ITERABLE
  Else If LS = 'callable'  Then PhpTypeFromStr := PT_CALLABLE
  Else                          PhpTypeFromStr := PT_UNKNOWN;
End;

{ Convertit un type PHP en type C# selon la version cible et le framework.
  Nullable=True ajoute le ? pour les types valeur (int?,bool?,double?) en
  C# 8+ et pour les types reference en C# 8+ (nullable reference types). }
Function TypePhpToCS(T: TPhpType; Nullable: Boolean;
                     Const CsVer: TString; Fw: Integer): TString;
Var Base: TString;
Begin
  Case T Of
    PT_INT        : Base := 'int';
    PT_FLOAT      : Base := 'double';    { PHP float = IEEE 754 double   }
    PT_STRING     : Base := 'string';
    PT_BOOL       : Base := 'bool';
    PT_NULL       : Base := 'null';
    PT_ARRAY      : Base := 'List<object>';
    PT_OBJECT     : Base := 'object';
    PT_VOID       : Base := 'void';
    PT_NEVER      : Base := 'void';      { pas d equivalent exact en C#  }
    PT_ITERABLE   : Base := 'IEnumerable<object>';
    PT_CALLABLE   : Base := 'Func<object>';
    PT_MIXED      : Base := 'dynamic';   { dynamic disponible depuis C#4 }
    PT_UNION,
    PT_INTERSECTION: Base := 'object';  { types complexes : simplification }
    PT_NULLABLE   : Base := 'object';   { resoudre le type interne en amont }
  Else
    Base := 'object';
  End;
  { Ajout du suffixe nullable en C# 8+ }
  If Nullable And CsVersionGE(CsVer, CS_VER_80) Then
  Begin
    If (Base = 'void') Or (Base = 'null') Then
      TypePhpToCS := Base              { void/null ne prennent pas ? }
    Else
      TypePhpToCS := Base + '?';
  End
  Else
    TypePhpToCS := Base;
End;

{ Ajoute un symbole dans la table ; retourne son indice (1-base) ou 0 si pleine }
Function SymAdd(Const Name: TString; Kind: TSymKind; PhpType: TPhpType;
                Nullable, IsRef: Boolean; Scope, DeclLine: Integer): Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' + ItoS(MAX_SYM) + ')');
    SymAdd := 0;
    Exit;
  End;
  Inc(SymCount);
  SymTab[SymCount].Name     := Name;
  SymTab[SymCount].CsName   := MakeCsName(Name);
  SymTab[SymCount].Kind     := Kind;
  SymTab[SymCount].PhpType  := PhpType;
  SymTab[SymCount].Nullable := Nullable;
  SymTab[SymCount].IsRef    := IsRef;
  SymTab[SymCount].Scope    := Scope;
  SymTab[SymCount].DeclLine := DeclLine;
  SymAdd := SymCount;
End;

{ Cherche un symbole par nom strictement dans le scope indique ;
  retourne l indice dans SymTab (1-base) ou 0 si non trouve }
Function SymFindLocal(Const Name: TString; Scope: Integer): Integer;
Var I: Integer;
Begin
  For I := 1 To SymCount Do
    If (SymTab[I].Name = Name) And (SymTab[I].Scope = Scope) Then
    Begin
      SymFindLocal := I;
      Exit;
    End;
  SymFindLocal := 0;
End;

{ Cherche un symbole dans le scope global (Scope=0) }
Function SymFindGlobal(Const Name: TString): Integer;
Begin
  SymFindGlobal := SymFindLocal(Name, 0);
End;

{ Cherche un symbole d abord dans le scope local, puis dans le scope global }
Function SymFind(Const Name: TString; Scope: Integer): Integer;
Var Idx: Integer;
Begin
  Idx := SymFindLocal(Name, Scope);
  If Idx > 0 Then
    SymFind := Idx
  Else
    SymFind := SymFindGlobal(Name);
End;

{ ============================================================
  TODO 05 - GESTION DES SCOPES ET NAMESPACES PHP [IMPLEMENTE]
  ============================================================ }

{ Retourne l indice du scope courant (utilise comme Scope dans SymAdd) }
Function ScopeCurrentIndex: Integer;
Begin
  ScopeCurrentIndex := ScopeTop;
End;

{ Retourne le nom du scope courant ('' si scope global) }
Function ScopeCurrentName: TString;
Begin
  If ScopeTop > 0 Then
    ScopeCurrentName := ScopeStack[ScopeTop].Name
  Else
    ScopeCurrentName := '';
End;

{ Retourne vrai si on est au niveau global (aucun scope empile) }
Function ScopeIsGlobal: Boolean;
Begin
  ScopeIsGlobal := ScopeTop = 0;
End;

{ Retourne vrai si le scope courant est une methode de classe }
Function ScopeIsMethod: Boolean;
Begin
  ScopeIsMethod := (ScopeTop > 0) And
                   (ScopeStack[ScopeTop].Kind = SCK_METHOD);
End;

{ Empile un nouveau scope }
Procedure ScopeEnter(Kind: TScopeKind; Const Name: TString);
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    WarnMsg('pile de scopes pleine (MAX_SCOPE=' + ItoS(MAX_SCOPE) + ')');
    Exit;
  End;
  Inc(ScopeTop);
  ScopeStack[ScopeTop].Kind := Kind;
  ScopeStack[ScopeTop].Name := Name;
End;

{ Depile le scope courant }
Procedure ScopeLeave;
Begin
  If ScopeTop > 0 Then
    Dec(ScopeTop)
  Else
    WarnMsg('ScopeLeave : pile de scopes vide');
End;

{ Convertit un nom de namespace PHP (Foo\Bar\Baz) en nom C# (Foo.Bar.Baz) }
Function NsPhpToCS(Const S: TString): TString;
Var I: Integer; R: TString;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    If S[I] = '\' Then
    Begin
      If Length(R) < MAX_STR Then R := R + '.';
    End
    Else
      If Length(R) < MAX_STR Then R := R + S[I];
  End;
  NsPhpToCS := R;
End;

{ Retourne le dernier segment d un nom qualifie (Foo\Bar -> Bar) }
Function LastSegment(Const S: TString): TString;
Var I: Integer; Seg: TString;
Begin
  Seg := '';
  For I := 1 To Length(S) Do
  Begin
    If S[I] = '\' Then
      Seg := ''
    Else
      If Length(Seg) < MAX_STR Then Seg := Seg + S[I];
  End;
  If Seg = '' Then LastSegment := S
              Else LastSegment := Seg;
End;

{ Ajoute une declaration use dans UseTable ; retourne son indice ou 0 si pleine.
  Si Alias est vide, l alias par defaut est le dernier segment du FqName. }
Function UseAdd(Const FqName, Alias: TString): Integer;
Var EffAlias: TString;
Begin
  If UseCount >= MAX_USE Then
  Begin
    WarnMsg('table use pleine (MAX_USE=' + ItoS(MAX_USE) + ')');
    UseAdd := 0;
    Exit;
  End;
  If Alias = '' Then
    EffAlias := LastSegment(FqName)
  Else
    EffAlias := Alias;
  Inc(UseCount);
  UseTable[UseCount].FqName := FqName;
  UseTable[UseCount].Alias  := EffAlias;
  UseAdd := UseCount;
End;

{ Cherche un alias dans UseTable ; retourne le FqName ou '' si non trouve }
Function UseFind(Const Alias: TString): TString;
Var I: Integer;
Begin
  For I := 1 To UseCount Do
    If UseTable[I].Alias = Alias Then
    Begin
      UseFind := UseTable[I].FqName;
      Exit;
    End;
  UseFind := '';
End;

{ Retourne le nom C# genere pour un alias use (derive du FqName en C#) }
Function UseCsName(Const Alias: TString): TString;
Var FqN: TString;
Begin
  FqN := UseFind(Alias);
  If FqN = '' Then
    UseCsName := MakeCsName(Alias)
  Else
    UseCsName := MakeCsName(LastSegment(FqN));
End;

{ ============================================================
  TODO 06 - TRANSPILATION : DECLARATIONS DE VARIABLES PHP [IMPLEMENTE]
  ============================================================ }

{ Declaration anticipee pour TODO 07 (recursion avec TODO 06) }
Function ParseExprStr: TString; Forward;

{ Declarations anticipees pour TODO 09 (structures de controle) }
Function  ParseMatchExpr(Indent: Integer): TString; Forward;
Procedure ParseDeclareStmt(Indent: Integer); Forward;
Procedure ParseGotoStmt(Indent: Integer); Forward;
Procedure ParseIfStmt(Indent: Integer); Forward;

{ Declarations anticipees pour TODO 10 (boucles) }
Procedure ParseForStmt(Indent: Integer); Forward;
Procedure ParseForeachStmt(Indent: Integer); Forward;
Procedure ParseWhileStmt(Indent: Integer); Forward;
Procedure ParseDoWhileStmt(Indent: Integer); Forward;
Procedure ParseBreakStmt(Indent: Integer); Forward;
Procedure ParseContinueStmt(Indent: Integer); Forward;

{ Declarations anticipees pour TODO 11 (switch/match) }
Procedure ParseSwitchStmt(Indent: Integer); Forward;

{ Declarations anticipees pour TODO 08 (utilisees par TokToCS et ParseExprPrimary) }
Function SqContentToCS(Const S: TString): TString; Forward;
Function NowDocContentToCS(Const S: TString): TString; Forward;
Function DqEscSeq(Const S: TString; Var I: Integer): TString; Forward;
Function DqContentToCS(Const S: TString): TString; Forward;
Function PhpStringToCS(Kind: TTokenKind; Const S: TString): TString; Forward;
Function SprintfSpecToCS(Const S: TString; Var I, ArgIdx: Integer): TString; Forward;
Function SprintfFmtToCS(Const Fmt: TString): TString; Forward;
Function ParseSprintfCall(IsWrite: Boolean): TString; Forward;
Function ParseNumberFormatCall: TString; Forward;
Function ParseStrPadCall: TString; Forward;

{ Supprime le '$' initial d un nom de variable PHP }
Function VarPhpName(Const S: TString): TString;
Begin
  If (Length(S) > 0) And (S[1] = '$') Then
    VarPhpName := Copy(S, 2, Length(S) - 1)
  Else
    VarPhpName := S;
End;

{ Emet une ligne dans le fichier C# de sortie }
Procedure EmitLine(Const S: TString);
Begin
  If OutFOpen Then
  Begin
    WriteLn(OutF, S);
    Inc(LinesEmit);
  End;
End;

{ Emet un bloc d indentation (2 espaces par niveau) }
Function IndentStr(Level: Integer): TString;
Var I: Integer; R: TString;
Begin
  R := '';
  For I := 1 To Level * 2 Do
    If Length(R) < MAX_STR Then R := R + ' ';
  IndentStr := R;
End;

{ Infere le type PHP a partir d un token RHS (literal) }
Function VarInferType(Const Tok: TToken): TPhpType;
Begin
  Case Tok.Kind Of
    TK_INTEGER    : VarInferType := PT_INT;
    TK_FLOAT      : VarInferType := PT_FLOAT;
    TK_STRING_SQ,
    TK_STRING_DQ,
    TK_HEREDOC,
    TK_NOWDOC     : VarInferType := PT_STRING;
    TK_KEYWORD    :
    Begin
      If (LowStr(Tok.Val) = 'true') Or (LowStr(Tok.Val) = 'false') Then
        VarInferType := PT_BOOL
      Else If LowStr(Tok.Val) = 'null' Then
        VarInferType := PT_NULL
      Else
        VarInferType := PT_UNKNOWN;
    End;
  Else
    VarInferType := PT_UNKNOWN;
  End;
End;

{ Retourne la representation C# d une superglobale PHP selon le framework }
Function SuperGlobalCS(Const Name: TString; Fw: Integer): TString;
Var N: TString;
Begin
  N := LowStr(Name);
  If N = '$_get' Then
  Begin
    If Fw = FW_ASPNET Then SuperGlobalCS := 'HttpContext.Request.Query'
    Else SuperGlobalCS := 'new Dictionary<string, string>() /* $_GET */';
  End
  Else If N = '$_post' Then
  Begin
    If Fw = FW_ASPNET Then SuperGlobalCS := 'HttpContext.Request.Form'
    Else SuperGlobalCS := 'new Dictionary<string, string>() /* $_POST */';
  End
  Else If N = '$_session' Then
  Begin
    If Fw = FW_ASPNET Then SuperGlobalCS := 'HttpContext.Session'
    Else SuperGlobalCS := 'new Dictionary<string, object>() /* $_SESSION */';
  End
  Else If N = '$_cookie' Then
  Begin
    If Fw = FW_ASPNET Then SuperGlobalCS := 'HttpContext.Request.Cookies'
    Else SuperGlobalCS := 'new Dictionary<string, string>() /* $_COOKIE */';
  End
  Else If N = '$_server' Then
    SuperGlobalCS := 'new Dictionary<string, string>() /* $_SERVER */'
  Else If N = '$_env' Then
    SuperGlobalCS := 'Environment.GetEnvironmentVariables() /* $_ENV */'
  Else If N = '$_files' Then
  Begin
    If Fw = FW_ASPNET Then SuperGlobalCS := 'HttpContext.Request.Form.Files /* $_FILES */'
    Else SuperGlobalCS := 'new List<object>() /* $_FILES */';
  End
  Else If N = '$globals' Then
    SuperGlobalCS := '/* $GLOBALS: utiliser des champs statiques */'
  Else
    SuperGlobalCS := '';
End;

{ Retourne vrai si le nom de variable est une superglobale PHP }
Function IsSuperGlobal(Const Name: TString): Boolean;
Var N: TString;
Begin
  N := LowStr(Name);
  IsSuperGlobal := (N = '$_get') Or (N = '$_post') Or (N = '$_session') Or
                   (N = '$_cookie') Or (N = '$_server') Or (N = '$_env') Or
                   (N = '$_files') Or (N = '$globals') Or (N = '$_request');
End;

{ Emet une declaration de variable C# dans le fichier de sortie.
  PhpName : nom PHP sans $ ; CsType : type C# ('' -> var) ;
  Nullable : ajoute le ? (C# 8+) ; RhsCs : RHS deja traduit ;
  IsStatic : emettre un champ statique prive ; Indent : niveau }
Procedure EmitVarDecl(Const PhpName, CsType, RhsCs: TString;
                      Nullable, IsStatic: Boolean;
                      Indent: Integer);
Var
  CsName, TypeStr, Prefix, Line: TString;
Begin
  CsName := MakeCsName(PhpName);
  If CsType = '' Then
    TypeStr := 'var'
  Else If Nullable And (CsType <> 'object') And
          CsVersionGE(Opts.CsVersion, CS_VER_80) Then
    TypeStr := CsType + '?'
  Else
    TypeStr := CsType;

  If IsStatic Then
    Prefix := 'private static '
  Else
    Prefix := '';

  Line := IndentStr(Indent) + Prefix + TypeStr + ' ' + CsName;
  If RhsCs <> '' Then
    Line := Line + ' = ' + RhsCs + ';'
  Else
    Line := Line + ';';
  EmitLine(Line);
End;

{ Convertit un token literal en sa representation C# string }
Function TokToCS(Const Tok: TToken): TString;
Begin
  Case Tok.Kind Of
    TK_INTEGER : TokToCS := ItoS(Tok.IntVal);
    TK_FLOAT   :
    Begin
      { Conversion simple : utiliser la valeur textuelle du token }
      TokToCS := Tok.Val;
    End;
    TK_STRING_SQ,
    TK_STRING_DQ,
    TK_HEREDOC,
    TK_NOWDOC    : TokToCS := PhpStringToCS(Tok.Kind, Tok.Val);
    TK_KEYWORD   :
    Begin
      If LowStr(Tok.Val) = 'true'  Then TokToCS := 'true'
      Else If LowStr(Tok.Val) = 'false' Then TokToCS := 'false'
      Else If LowStr(Tok.Val) = 'null'  Then TokToCS := 'null'
      Else TokToCS := Tok.Val;
    End;
    TK_VAR : TokToCS := MakeCsName(VarPhpName(Tok.Val));
    TK_IDENT : TokToCS := MakeCsName(Tok.Val);
  Else
    TokToCS := Tok.Val;
  End;
End;

{ Parse et emet une declaration de variable simple :
    $var = expr;   -> var CsName = rhsCs;
    $var = null;   -> object? CsName = null; (C# 8+)
  Suppose que CurTok est le token TK_VAR apres le $.
  Consomme jusqu au ';' inclus. Retourne vrai si parsee. }
Function ParseSimpleVarDecl(Indent: Integer): Boolean;
Var
  PhpName, RhsCs, CsType: TString;
  Inferred: TPhpType;
  Nullable: Boolean;
Begin
  ParseSimpleVarDecl := False;
  If CurTok.Kind <> TK_VAR Then Exit;

  PhpName := VarPhpName(CurTok.Val);

  { Superglobales : ne pas generer de declaration locale }
  If IsSuperGlobal(CurTok.Val) Then
  Begin
    { On consomme jusqu au ; }
    Repeat
      LexNextToken;
    Until (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Or
          (CurTok.Kind = TK_EOF);
    ParseSimpleVarDecl := True;
    Exit;
  End;

  { Lire le '=' }
  LexNextToken;
  If Not ((CurTok.Kind = TK_OP) And (CurTok.Val = '=')) Then
    Exit;

  { Lire le RHS (token suivant = premier token du RHS) }
  LexNextToken;
  Inferred := VarInferType(CurTok);
  Nullable := (Inferred = PT_NULL);
  RhsCs    := ParseExprStr;
  { CurTok est maintenant le token stop (';') }

  { Determiner le type C# }
  Case Inferred Of
    PT_INT    : CsType := 'int';
    PT_FLOAT  : CsType := 'double';
    PT_STRING : CsType := 'string';
    PT_BOOL   : CsType := 'bool';
    PT_NULL   :
    Begin
      If CsVersionGE(Opts.CsVersion, CS_VER_80) Then CsType := 'object'
      Else CsType := 'object';
    End;
  Else
    CsType := '';   { -> var }
  End;

  { Enregistrer dans SymTab }
  SymAdd(PhpName, SK_VAR, Inferred, Nullable, False,
         ScopeCurrentIndex, CurTok.Line);

  EmitVarDecl(PhpName, CsType, RhsCs, Nullable, False, Indent);
  ParseSimpleVarDecl := True;
End;

{ Parse et emet une declaration de variable statique :
    static $var = val;  ->  private static type CsName = val; }
Function ParseStaticVarDecl(Indent: Integer): Boolean;
Var
  PhpName, RhsCs, CsType: TString;
  Inferred: TPhpType;
Begin
  ParseStaticVarDecl := False;
  { CurTok doit etre le mot-cle 'static' }
  If Not ((CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'static')) Then
    Exit;

  LexNextToken;
  If CurTok.Kind <> TK_VAR Then Exit;

  PhpName := VarPhpName(CurTok.Val);

  LexNextToken;
  If Not ((CurTok.Kind = TK_OP) And (CurTok.Val = '=')) Then
  Begin
    { pas d initialisation : static $var; }
    EmitVarDecl(PhpName, '', '', False, True, Indent);
    ParseStaticVarDecl := True;
    Exit;
  End;

  LexNextToken;
  Inferred := VarInferType(CurTok);
  RhsCs    := ParseExprStr;
  { CurTok est maintenant le token stop (';') }

  Case Inferred Of
    PT_INT    : CsType := 'int';
    PT_FLOAT  : CsType := 'double';
    PT_STRING : CsType := 'string';
    PT_BOOL   : CsType := 'bool';
  Else
    CsType := '';
  End;

  SymAdd(PhpName, SK_STATIC_VAR, Inferred, False, False,
         ScopeCurrentIndex, CurTok.Line);

  EmitVarDecl(PhpName, CsType, RhsCs, False, True, Indent);
  ParseStaticVarDecl := True;
End;

{ Extrait les noms de variables d une liste list($a, $b) ou [$a, $b]
  jusqu au ')' ou ']'. Retourne la liste des CsNames separee par virgules.
  CurTok doit pointer sur '(' ou '[' a l entree. }
Function ParseDestructList(CloseCh: Char): TString;
Var Result: TString;
Begin
  Result := '';
  LexNextToken; { consommer '(' ou '[' }
  While Not (CurTok.Kind = TK_EOF) Do
  Begin
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = CloseCh) Then Break;
    If CurTok.Kind = TK_VAR Then
    Begin
      If Result <> '' Then
        If Length(Result) < MAX_STR Then Result := Result + ', ';
      If Length(Result) < MAX_STR Then
        Result := Result + MakeCsName(VarPhpName(CurTok.Val));
    End;
    LexNextToken;
  End;
  ParseDestructList := Result;
End;

{ Parse list($a, $b) = expr; ou [$a, $b] = expr;
  -> var (a, b) = expr; (C# 7+)
  CurTok doit etre 'list' ou '[' a l entree. }
Function ParseDestructDecl(Indent: Integer): Boolean;
Var
  Names, RhsCs, Line: TString;
  IsListKw: Boolean;
Begin
  ParseDestructDecl := False;
  IsListKw := (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'list');

  If IsListKw Then
  Begin
    LexNextToken; { '(' }
    If Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(')) Then Exit;
    Names := ParseDestructList(')');
    LexNextToken; { consommer ')' -> token apres }
  End
  Else If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '[') Then
  Begin
    Names := ParseDestructList(']');
    LexNextToken; { consommer ']' -> token apres }
  End
  Else
    Exit;

  { Lire '=' }
  If Not ((CurTok.Kind = TK_OP) And (CurTok.Val = '=')) Then Exit;

  LexNextToken;
  RhsCs := ParseExprStr;
  { CurTok est maintenant le token stop (';') }

  { Emettre seulement si C# 7+ supporte les tuples }
  If CsVersionGE(Opts.CsVersion, CS_VER_70) Then
  Begin
    Line := IndentStr(Indent) + 'var (' + Names + ') = ' + RhsCs + ';';
    EmitLine(Line);
  End
  Else
  Begin
    { Fallback : declarer chaque variable separement comme var }
    EmitLine(IndentStr(Indent) + '/* destructuration non supportee < C# 7 */');
  End;
  ParseDestructDecl := True;
End;

{ ============================================================
  TODO 07 - TRANSPILATION : EXPRESSIONS PHP [IMPLEMENTE]
  ============================================================ }

{ Retourne vrai si le nom est un type de cast PHP reconnu }
Function IsCastType(Const S: TString): Boolean;
Var L: TString;
Begin
  L := LowStr(S);
  IsCastType := (L = 'int') Or (L = 'integer') Or
                (L = 'float') Or (L = 'double') Or (L = 'real') Or
                (L = 'bool') Or (L = 'boolean') Or
                (L = 'string') Or (L = 'array') Or
                (L = 'object') Or (L = 'unset');
End;

{ Retourne la representation C# d un operateur binaire PHP }
Function PhpBinOpToCS(Const Op: TString): TString;
Var L: TString;
Begin
  L := LowStr(Op);
  If      Op = '.'   Then PhpBinOpToCS := '+'
  Else If Op = '===' Then PhpBinOpToCS := '=='
  Else If Op = '!==' Then PhpBinOpToCS := '!='
  Else If Op = '<>'  Then PhpBinOpToCS := '!='
  Else If Op = '?->' Then PhpBinOpToCS := '?.'
  Else If Op = '->'  Then PhpBinOpToCS := '.'
  Else If Op = '::'  Then PhpBinOpToCS := '.'
  Else If L  = 'and' Then PhpBinOpToCS := '&&'
  Else If L  = 'or'  Then PhpBinOpToCS := '||'
  Else If L  = 'xor' Then PhpBinOpToCS := '^'
  Else If Op = '.='  Then PhpBinOpToCS := '+='
  Else                    PhpBinOpToCS := Op;
End;

{ Retourne la representation C# d un cast PHP }
Function PhpCastToCS(Const CastName: TString): TString;
Var L: TString;
Begin
  L := LowStr(TrimStr(CastName));
  If (L = 'int') Or (L = 'integer') Then
    PhpCastToCS := '(int)'
  Else If (L = 'float') Or (L = 'double') Or (L = 'real') Then
    PhpCastToCS := '(double)'
  Else If (L = 'bool') Or (L = 'boolean') Then
    PhpCastToCS := '(bool)'
  Else If L = 'string' Then
    PhpCastToCS := '' { handled by .ToString() suffix }
  Else If L = 'array' Then
    PhpCastToCS := '' { handled specially }
  Else If L = 'object' Then
    PhpCastToCS := '(object)'
  Else If L = 'unset' Then
    PhpCastToCS := '' { PHP unset cast }
  Else
    PhpCastToCS := '(' + CastName + ')';
End;

{ Retourne la representation C# d une constante magique PHP }
Function PhpMagicConstToCS(Const Name: TString; SrcLine: Integer): TString;
Var L: TString;
Begin
  L := LowStr(Name);
  If      L = '__line__'      Then PhpMagicConstToCS := ItoS(SrcLine)
  Else If L = '__file__'      Then PhpMagicConstToCS := '"' + Opts.SrcFile + '"'
  Else If L = '__class__'     Then PhpMagicConstToCS := 'nameof(' + ScopeCurrentName + ')'
  Else If L = '__method__'    Then PhpMagicConstToCS := 'nameof(' + ScopeCurrentName + ')'
  Else If L = '__function__'  Then PhpMagicConstToCS := 'nameof(' + ScopeCurrentName + ')'
  Else If L = '__namespace__' Then PhpMagicConstToCS := '"' + NsPhpToCS(CurrentNs) + '"'
  Else If L = '__dir__'       Then
    PhpMagicConstToCS := 'System.IO.Path.GetDirectoryName("' + Opts.SrcFile + '")'
  Else If L = '__trait__'     Then PhpMagicConstToCS := 'nameof(' + ScopeCurrentName + ')'
  Else                             PhpMagicConstToCS := '"' + Name + '"';
End;

{ Concatenation securisee : tronque avec avertissement si > MAX_STR }
Function ExprAppend(Const A, B: TString): TString;
Begin
  If Length(A) + Length(B) <= MAX_STR Then
    ExprAppend := A + B
  Else
  Begin
    WarnMsg('expression C# trop longue, tronquee');
    ExprAppend := Copy(A + B, 1, MAX_STR);
  End;
End;

{ Retourne vrai si CurTok est un token qui termine une expression }
Function IsExprStop: Boolean;
Begin
  IsExprStop :=
    (CurTok.Kind = TK_EOF) Or
    ((CurTok.Kind = TK_PUNCT) And
      ((CurTok.Val = ';') Or (CurTok.Val = ')') Or
       (CurTok.Val = ']') Or (CurTok.Val = '}') Or
       (CurTok.Val = ',')));
End;

{ Parse les arguments d un appel de fonction : FnCs '(' arg1, arg2, ... ')'
  Pre: CurTok pointe sur '('. Post: CurTok pointe sur le token apres ')'. }
Function ParseFnCallArgs(Const FnCs: TString): TString;
Var R: TString;
Begin
  R := ExprAppend(FnCs, '(');
  LexNextToken; { past '(' }
  While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')')) And
        (CurTok.Kind <> TK_EOF) Do
  Begin
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ',') Then
    Begin
      R := ExprAppend(R, ', ');
      LexNextToken;
    End
    Else If (CurTok.Kind = TK_OP) And (CurTok.Val = '...') Then
    Begin
      { spread operator ...args }
      LexNextToken;
      R := ExprAppend(R, ParseExprStr);
      R := ExprAppend(R, '.ToArray()');
    End
    Else If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '&') Then
    Begin
      { reference argument &$x }
      LexNextToken; { skip '&' }
      R := ExprAppend(R, 'ref ');
      R := ExprAppend(R, ParseExprStr);
    End
    Else
      R := ExprAppend(R, ParseExprStr);
  End;
  R := ExprAppend(R, ')');
  LexNextToken; { past ')' }
  ParseFnCallArgs := R;
End;

{ Niveau 14 - Primaire : literal, variable, (expr), [array], appel, new, cast }
Function ParseExprPrimary: TString;
Var R, CastName, MemberName, Op, FnLow: TString;
Begin
  R := '';
  Case CurTok.Kind Of
    TK_INTEGER :
    Begin
      R := ItoS(CurTok.IntVal);
      LexNextToken;
    End;
    TK_FLOAT :
    Begin
      R := CurTok.Val;
      LexNextToken;
    End;
    TK_STRING_SQ, TK_STRING_DQ, TK_HEREDOC, TK_NOWDOC :
    Begin
      R := PhpStringToCS(CurTok.Kind, CurTok.Val);
      LexNextToken;
    End;
    TK_VAR :
    Begin
      If IsSuperGlobal(CurTok.Val) Then
        R := SuperGlobalCS(CurTok.Val, Opts.Framework)
      Else
        R := MakeCsName(VarPhpName(CurTok.Val));
      LexNextToken;
      { post ++/-- }
      If (CurTok.Kind = TK_OP) And
         ((CurTok.Val = '++') Or (CurTok.Val = '--')) Then
      Begin
        R := ExprAppend(R, CurTok.Val);
        LexNextToken;
      End;
      { member access ->, ::, ?-> et acces tableau [] }
      While ((CurTok.Kind = TK_OP) And
             ((CurTok.Val = '->') Or (CurTok.Val = '::') Or
              (CurTok.Val = '?->'))) Or
            ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = '[')) Do
      Begin
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '[') Then
        Begin
          LexNextToken;
          R := ExprAppend(R, '[');
          R := ExprAppend(R, ParseExprStr);
          { CurTok = ']' }
          R := ExprAppend(R, ']');
          LexNextToken; { past ']' }
        End
        Else
        Begin
          Op := CurTok.Val;
          LexNextToken; { member name }
          MemberName := MakeCsName(CurTok.Val);
          LexNextToken;
          If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
            R := ParseFnCallArgs(ExprAppend(R, PhpBinOpToCS(Op) + MemberName))
          Else
            R := ExprAppend(R, PhpBinOpToCS(Op) + MemberName);
        End;
      End;
    End;
    TK_IDENT :
    Begin
      FnLow := LowStr(CurTok.Val);
      R := MakeCsName(CurTok.Val);
      LexNextToken;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
      Begin
        If (FnLow = 'sprintf') Or (FnLow = 'vsprintf') Then
          R := ParseSprintfCall(False)
        Else If FnLow = 'printf' Then
          R := ParseSprintfCall(True)
        Else If FnLow = 'number_format' Then
          R := ParseNumberFormatCall
        Else If FnLow = 'str_pad' Then
          R := ParseStrPadCall
        Else If FnLow = 'wordwrap' Then
          R := ExprAppend('/* wordwrap */ ', ParseFnCallArgs(R))
        Else
          R := ParseFnCallArgs(R);
      End
      Else
      Begin
        { member access via :: }
        While (CurTok.Kind = TK_OP) And
              ((CurTok.Val = '::') Or (CurTok.Val = '->')) Do
        Begin
          Op := CurTok.Val;
          LexNextToken;
          MemberName := MakeCsName(CurTok.Val);
          LexNextToken;
          If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
            R := ParseFnCallArgs(ExprAppend(R, '.' + MemberName))
          Else
            R := ExprAppend(R, '.' + MemberName);
        End;
        { acces tableau }
        While (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '[') Do
        Begin
          LexNextToken;
          R := ExprAppend(R, '[');
          R := ExprAppend(R, ParseExprStr);
          R := ExprAppend(R, ']');
          LexNextToken; { past ']' }
        End;
      End;
    End;
    TK_KEYWORD :
    Begin
      If LowStr(CurTok.Val) = 'true' Then
      Begin
        R := 'true'; LexNextToken;
      End
      Else If LowStr(CurTok.Val) = 'false' Then
      Begin
        R := 'false'; LexNextToken;
      End
      Else If LowStr(CurTok.Val) = 'null' Then
      Begin
        R := 'null'; LexNextToken;
      End
      Else If LowStr(CurTok.Val) = 'new' Then
      Begin
        LexNextToken; { class name }
        R := 'new ' + MakeCsName(CurTok.Val);
        LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
          R := ParseFnCallArgs(R);
      End
      Else If (LowStr(CurTok.Val) = '__line__')   Or
              (LowStr(CurTok.Val) = '__file__')   Or
              (LowStr(CurTok.Val) = '__class__')  Or
              (LowStr(CurTok.Val) = '__method__') Or
              (LowStr(CurTok.Val) = '__function__') Or
              (LowStr(CurTok.Val) = '__namespace__') Or
              (LowStr(CurTok.Val) = '__dir__')    Or
              (LowStr(CurTok.Val) = '__trait__') Then
      Begin
        R := PhpMagicConstToCS(CurTok.Val, CurTok.Line);
        LexNextToken;
      End
      Else If LowStr(CurTok.Val) = 'match' Then
        R := ParseMatchExpr(0)
      Else
      Begin
        R := MakeCsName(CurTok.Val);
        LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
          R := ParseFnCallArgs(R);
      End;
    End;
    TK_PUNCT :
    Begin
      If CurTok.Val = '(' Then
      Begin
        LexNextToken; { past '(' }
        { Detecter un cast PHP : (int), (float), (string), etc. }
        If (CurTok.Kind = TK_KEYWORD) And IsCastType(CurTok.Val) Then
        Begin
          CastName := CurTok.Val;
          LexNextToken; { past type keyword }
          If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
          Begin
            { C est un cast }
            LexNextToken; { past ')' }
            If LowStr(CastName) = 'string' Then
            Begin
              { (string)expr -> expr.ToString() }
              R := ExprAppend(ParseExprPrimary, '.ToString()');
            End
            Else If LowStr(CastName) = 'array' Then
            Begin
              { cast array : List<object> wrapper }
              R := ExprAppend('new List<object> { ', ParseExprPrimary);
              R := ExprAppend(R, ' }');
            End
            Else
              R := ExprAppend(PhpCastToCS(CastName), ParseExprPrimary);
          End
          Else
          Begin
            { Pas un cast pur : expression parenthesee commencant par le mot-cle }
            R := '(' + MakeCsName(CastName);
            R := ExprAppend(R, ParseExprStr);
            R := ExprAppend(R, ')');
            LexNextToken; { past ')' }
          End;
        End
        Else
        Begin
          { Expression parenthesee ordinaire }
          R := '(' + ParseExprStr + ')';
          { CurTok = ')' }
          LexNextToken; { past ')' }
        End;
      End
      Else If CurTok.Val = '[' Then
      Begin
        { Tableau litteral [v1, v2, ...] }
        R := 'new object[] {';
        LexNextToken;
        While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ']')) And
              (CurTok.Kind <> TK_EOF) Do
        Begin
          If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ',') Then
          Begin
            R := ExprAppend(R, ', '); LexNextToken;
          End
          Else
            R := ExprAppend(R, ParseExprStr);
        End;
        R := ExprAppend(R, '}');
        LexNextToken; { past ']' }
      End
      Else If CurTok.Val = '&' Then
      Begin
        { reference &$var ou & expression }
        LexNextToken; { skip '&' }
        R := ParseExprPrimary;
      End;
    End;
    TK_OP :
    Begin
      { @ suppresseur d erreur : ignorer }
      If CurTok.Val = '@' Then
      Begin
        LexNextToken;
        R := ParseExprPrimary;
      End;
    End;
  Else
    { Token inconnu : consommer et retourner vide }
    LexNextToken;
  End;
  ParseExprPrimary := R;
End;

{ Niveau 13 - Unaires : ! ~ - + pre++/-- instanceof }
Function ParseExprUnary: TString;
Var Op, Operand: TString;
Begin
  If (CurTok.Kind = TK_OP) And
     ((CurTok.Val = '!') Or (CurTok.Val = '~') Or
      (CurTok.Val = '-') Or (CurTok.Val = '+')) Then
  Begin
    Op := CurTok.Val;
    LexNextToken;
    Operand := ParseExprUnary;
    ParseExprUnary := ExprAppend(Op, Operand);
  End
  Else If (CurTok.Kind = TK_OP) And
          ((CurTok.Val = '++') Or (CurTok.Val = '--')) Then
  Begin
    Op := CurTok.Val;
    LexNextToken;
    Operand := ParseExprUnary;
    ParseExprUnary := ExprAppend(Op, Operand);
  End
  Else
  Begin
    Operand := ParseExprPrimary;
    { instanceof -> is (C#) }
    If (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'instanceof') Then
    Begin
      LexNextToken; { class name }
      Operand := ExprAppend(Operand, ' is ');
      Operand := ExprAppend(Operand, MakeCsName(CurTok.Val));
      LexNextToken;
    End;
    ParseExprUnary := Operand;
  End;
End;

{ Niveau 12 - Puissance : ** -> Math.Pow(...) }
Function ParseExprPow: TString;
Var L, R: TString;
Begin
  L := ParseExprUnary;
  While (CurTok.Kind = TK_OP) And (CurTok.Val = '**') Do
  Begin
    LexNextToken;
    R := ParseExprUnary;
    L := ExprAppend('Math.Pow(' + L + ', ', ExprAppend(R, ')'));
  End;
  ParseExprPow := L;
End;

{ Niveau 11 - * / % }
Function ParseExprMulDiv: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprPow;
  While (CurTok.Kind = TK_OP) And
        ((CurTok.Val = '*') Or (CurTok.Val = '/') Or (CurTok.Val = '%')) Do
  Begin
    Op := CurTok.Val;
    LexNextToken;
    R := ParseExprPow;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprMulDiv := L;
End;

{ Niveau 10 - + - . (concat) }
Function ParseExprAddSub: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprMulDiv;
  While ((CurTok.Kind = TK_OP) And
         ((CurTok.Val = '+') Or (CurTok.Val = '-'))) Or
        ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = '.')) Do
  Begin
    Op := PhpBinOpToCS(CurTok.Val);  { '.' -> '+' }
    LexNextToken;
    R := ParseExprMulDiv;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprAddSub := L;
End;

{ Niveau 9 - << >> }
Function ParseExprShift: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprAddSub;
  While (CurTok.Kind = TK_OP) And
        ((CurTok.Val = '<<') Or (CurTok.Val = '>>')) Do
  Begin
    Op := CurTok.Val;
    LexNextToken;
    R := ParseExprAddSub;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprShift := L;
End;

{ Niveau 8 - < <= > >= }
Function ParseExprComparison: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprShift;
  While (CurTok.Kind = TK_OP) And
        ((CurTok.Val = '<') Or (CurTok.Val = '<=') Or
         (CurTok.Val = '>') Or (CurTok.Val = '>=')) Do
  Begin
    Op := CurTok.Val;
    LexNextToken;
    R := ParseExprShift;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprComparison := L;
End;

{ Niveau 7 - == === != !== <> <=> }
Function ParseExprEquality: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprComparison;
  While (CurTok.Kind = TK_OP) And
        ((CurTok.Val = '==') Or (CurTok.Val = '===') Or
         (CurTok.Val = '!=') Or (CurTok.Val = '<>') Or
         (CurTok.Val = '!==') Or (CurTok.Val = '<=>')) Do
  Begin
    If CurTok.Val = '===' Then
      WarnMsg('operateur === converti en == (verification de type ignoree)');
    If CurTok.Val = '<=>' Then
    Begin
      LexNextToken;
      R := ParseExprComparison;
      L := ExprAppend('Comparer<object>.Default.Compare(' + L + ', ',
                       ExprAppend(R, ')'));
    End
    Else
    Begin
      Op := PhpBinOpToCS(CurTok.Val);
      LexNextToken;
      R := ParseExprComparison;
      L := ExprAppend(L, ' ' + Op + ' ');
      L := ExprAppend(L, R);
    End;
  End;
  ParseExprEquality := L;
End;

{ Niveau 6 - | ^ & (bitwise, TK_PUNCT standalone) }
Function ParseExprBitwise: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprEquality;
  While ((CurTok.Kind = TK_PUNCT) And
         ((CurTok.Val = '|') Or (CurTok.Val = '^') Or
          (CurTok.Val = '&'))) Do
  Begin
    Op := CurTok.Val;
    LexNextToken;
    R := ParseExprEquality;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprBitwise := L;
End;

{ Niveau 5 - || && (TK_OP) }
Function ParseExprLogic: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprBitwise;
  While (CurTok.Kind = TK_OP) And
        ((CurTok.Val = '||') Or (CurTok.Val = '&&')) Do
  Begin
    Op := CurTok.Val;
    LexNextToken;
    R := ParseExprBitwise;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprLogic := L;
End;

{ Niveau 4 - or and xor (mots-cles) }
Function ParseExprLogicKw: TString;
Var L, R, Op: TString;
Begin
  L := ParseExprLogic;
  While (CurTok.Kind = TK_KEYWORD) And
        ((LowStr(CurTok.Val) = 'or') Or
         (LowStr(CurTok.Val) = 'and') Or
         (LowStr(CurTok.Val) = 'xor')) Do
  Begin
    Op := PhpBinOpToCS(CurTok.Val);
    LexNextToken;
    R := ParseExprLogic;
    L := ExprAppend(L, ' ' + Op + ' ');
    L := ExprAppend(L, R);
  End;
  ParseExprLogicKw := L;
End;

{ Niveau 3 - ?? et ??= (null-coalescing) }
Function ParseExprNullCoalesce: TString;
Var L, R: TString;
Begin
  L := ParseExprLogicKw;
  While (CurTok.Kind = TK_OP) And
        ((CurTok.Val = '??') Or (CurTok.Val = '??=')) Do
  Begin
    If CurTok.Val = '??=' Then
    Begin
      LexNextToken;
      R := ParseExprLogicKw;
      If CsVersionGE(Opts.CsVersion, CS_VER_80) Then
      Begin
        L := ExprAppend(L, ' ??= ');
        L := ExprAppend(L, R);
      End
      Else
      Begin
        L := ExprAppend(L + ' = ' + L + ' ?? ', R);
      End;
    End
    Else
    Begin
      LexNextToken;
      R := ParseExprLogicKw;
      If CsVersionGE(Opts.CsVersion, CS_VER_60) Then
      Begin
        L := ExprAppend(L, ' ?? ');
        L := ExprAppend(L, R);
      End
      Else
      Begin
        L := ExprAppend('(' + L + ' != null) ? ' + L + ' : ', R);
      End;
    End;
  End;
  ParseExprNullCoalesce := L;
End;

{ Niveau 2 - Ternaire ? : et Elvis ?: }
Function ParseExprTernary: TString;
Var Cond, ThenExpr, ElseExpr: TString;
Begin
  Cond := ParseExprNullCoalesce;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '?') Then
  Begin
    LexNextToken; { past '?' }
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
    Begin
      { Operateur Elvis ?: }
      LexNextToken; { past ':' }
      ElseExpr := ParseExprNullCoalesce;
      ParseExprTernary := ExprAppend(
        '(' + Cond + ' != null) ? ' + Cond + ' : ', ElseExpr);
    End
    Else
    Begin
      { Ternaire complet ? then : else }
      ThenExpr := ParseExprNullCoalesce;
      { CurTok doit etre ':' }
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
        LexNextToken; { past ':' }
      ElseExpr := ParseExprNullCoalesce;
      ParseExprTernary := ExprAppend(
        ExprAppend('(' + Cond + ') ? ', ExprAppend(ThenExpr, ' : ')),
        ElseExpr);
    End;
  End
  Else
    ParseExprTernary := Cond;
End;

{ Niveau 1 - yield / yield from }
Function ParseExprYield: TString;
Var E: TString;
Begin
  If (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'yield') Then
  Begin
    LexNextToken;
    If (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'from') Then
    Begin
      { yield from -> IEnumerable iteration stub }
      LexNextToken;
      E := ParseExprTernary;
      ParseExprYield := ExprAppend(
        '/* yield from */ foreach(var _y in ', ExprAppend(E, ') yield return _y'));
    End
    Else If Not IsExprStop Then
    Begin
      E := ParseExprTernary;
      ParseExprYield := ExprAppend('yield return ', E);
    End
    Else
      ParseExprYield := 'yield break';
  End
  Else
    ParseExprYield := ParseExprTernary;
End;

{ Point d entree du parseur d expressions PHP.
  Pre-condition  : CurTok pointe sur le premier token de l expression.
  Post-condition : CurTok pointe sur le premier token APRES l expression
                   (token stop : point-virgule, parenthese, crochet, virgule).
  Retourne la chaine C# equivalente. }
Function ParseExprStr: TString;
Begin
  If IsExprStop Then
    ParseExprStr := ''
  Else
    ParseExprStr := ParseExprYield;
End;

{ ============================================================
  TODO 08 - TRANSPILATION : CHAINES ET INTERPOLATION PHP [IMPLEMENTE]
  ============================================================ }

{ Convertit le contenu brut d une chaine SQ PHP en contenu C# sans guillemets.
  Le lexeur a deja traite : \\ -> \ et \' -> '.
  Ici on re-echappe pour C# : \ -> \\, " -> \", #10 -> \n, #13 -> \r. }
Function SqContentToCS(Const S: TString): TString;
Var I: Integer; R: TString;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    If S[I] = '\' Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\\';
    End
    Else If S[I] = '"' Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\"';
    End
    Else If S[I] = #10 Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\n';
    End
    Else If S[I] = #13 Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\r';
    End
    Else
    Begin
      If Length(R) < MAX_STR Then R := R + S[I];
    End;
  End;
  SqContentToCS := R;
End;

{ Convertit le contenu brut d une chaine Nowdoc (verbatim multi-ligne) en
  contenu pour @"..." C# : seule sequence speciale = " -> "". }
Function NowDocContentToCS(Const S: TString): TString;
Var I: Integer; R: TString;
Begin
  R := '';
  For I := 1 To Length(S) Do
  Begin
    If S[I] = '"' Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '""';
    End
    Else
    Begin
      If Length(R) < MAX_STR Then R := R + S[I];
    End;
  End;
  NowDocContentToCS := R;
End;

{ Convertit une sequence d echappement PHP \X a partir de la position I dans S
  (I pointe sur le caractere apres le backslash). Avance I. }
Function DqEscSeq(Const S: TString; Var I: Integer): TString;
Var
  Hex  : TString;
  NbHex: Integer;
Begin
  If I > Length(S) Then Begin DqEscSeq := '\'; Exit; End;
  Case S[I] Of
    'n': Begin DqEscSeq := '\n';   Inc(I); End;
    't': Begin DqEscSeq := '\t';   Inc(I); End;
    'r': Begin DqEscSeq := '\r';   Inc(I); End;
    '\': Begin DqEscSeq := '\\';  Inc(I); End;
    '"': Begin DqEscSeq := '\"';  Inc(I); End;
    '$': Begin DqEscSeq := '$';   Inc(I); End;
    '0': Begin DqEscSeq := '\0';  Inc(I); End;
    'v': Begin DqEscSeq := '\v';  Inc(I); End;
    'f': Begin DqEscSeq := '\f';  Inc(I); End;
    'e': Begin DqEscSeq := '\x1B'; Inc(I); End;
    'x': Begin
      Hex := '\x'; Inc(I); NbHex := 0;
      While (I <= Length(S)) And (NbHex < 2) And
            (((S[I] >= '0') And (S[I] <= '9')) Or
             ((S[I] >= 'a') And (S[I] <= 'f')) Or
             ((S[I] >= 'A') And (S[I] <= 'F'))) Do
      Begin
        If Length(Hex) < MAX_STR Then Hex := Hex + S[I];
        Inc(I); Inc(NbHex);
      End;
      DqEscSeq := Hex;
    End;
    'u': Begin
      Inc(I);
      If (I <= Length(S)) And (S[I] = '{') Then
      Begin
        Inc(I); { saute '{' }
        Hex := '\u'; NbHex := 0;
        While (I <= Length(S)) And (S[I] <> '}') And (NbHex < 4) Do
        Begin
          If Length(Hex) < MAX_STR Then Hex := Hex + S[I];
          Inc(I); Inc(NbHex);
        End;
        If I <= Length(S) Then Inc(I); { saute accolade fermante }
        DqEscSeq := Hex;
      End
      Else
      Begin
        Hex := '\u'; NbHex := 0;
        While (I <= Length(S)) And (NbHex < 4) And
              (((S[I] >= '0') And (S[I] <= '9')) Or
               ((S[I] >= 'a') And (S[I] <= 'f')) Or
               ((S[I] >= 'A') And (S[I] <= 'F'))) Do
        Begin
          If Length(Hex) < MAX_STR Then Hex := Hex + S[I];
          Inc(I); Inc(NbHex);
        End;
        DqEscSeq := Hex;
      End;
    End;
  Else
    DqEscSeq := '\' + S[I]; Inc(I);
  End;
End;

{ Convertit le contenu brut d une chaine DQ PHP (ou Heredoc) en contenu C#.
  Sequences d echappement converties, $var et dollar-var interpolation traitees.
  Si C# >= 6 : retourne le contenu pour $"..." (interpolation C# native).
  Sinon : retourne une expression de concatenation "..." + Var + "...". }
Function DqContentToCS(Const S: TString): TString;
Var
  I        : Integer;
  Ch       : Char;
  R        : TString;
  VarN     : TString;
  UseInterp: Boolean;
Begin
  UseInterp := CsVersionGE(Opts.CsVersion, CS_VER_60);
  R := '';
  I := 1;
  While I <= Length(S) Do
  Begin
    Ch := S[I];
    If Ch = '\' Then
    Begin
      Inc(I);
      If Length(R) < MAX_STR - 5 Then
        R := R + DqEscSeq(S, I);
    End
    Else If Ch = #10 Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\n';
      Inc(I);
    End
    Else If Ch = #13 Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\r';
      Inc(I);
    End
    Else If (Ch = '{') And (I < Length(S)) And (S[I + 1] = '$') Then
    Begin
      { interpolation avec accolades : dollar-var entre accolades }
      Inc(I); Inc(I); { saute '{' et '$' }
      VarN := '';
      While (I <= Length(S)) And
            (((S[I] >= 'a') And (S[I] <= 'z')) Or
             ((S[I] >= 'A') And (S[I] <= 'Z')) Or
             ((S[I] >= '0') And (S[I] <= '9')) Or
             (S[I] = '_')) Do
      Begin
        If Length(VarN) < MAX_STR Then VarN := VarN + S[I];
        Inc(I);
      End;
      While (I <= Length(S)) And (S[I] <> '}') Do Inc(I);
      If I <= Length(S) Then Inc(I); { saute accolade fermante }
      If VarN <> '' Then
      Begin
        If UseInterp Then
        Begin
          If Length(R) < MAX_STR - 2 Then
            R := R + '{' + MakeCsName(VarN) + '}';
        End
        Else
        Begin
          If Length(R) < MAX_STR - 10 Then
            R := R + '" + ' + MakeCsName(VarN) + ' + "';
        End;
      End;
    End
    Else If Ch = '{' Then
    Begin
      If UseInterp Then
      Begin
        If Length(R) < MAX_STR - 1 Then R := R + '{{';
      End
      Else
      Begin
        If Length(R) < MAX_STR Then R := R + '{';
      End;
      Inc(I);
    End
    Else If Ch = '}' Then
    Begin
      If UseInterp Then
      Begin
        If Length(R) < MAX_STR - 1 Then R := R + '}}';
      End
      Else
      Begin
        If Length(R) < MAX_STR Then R := R + '}';
      End;
      Inc(I);
    End
    Else If (Ch = '$') And (I < Length(S)) And
            (((S[I + 1] >= 'a') And (S[I + 1] <= 'z')) Or
             ((S[I + 1] >= 'A') And (S[I + 1] <= 'Z')) Or
             (S[I + 1] = '_')) Then
    Begin
      Inc(I); { saute '$' }
      VarN := '';
      While (I <= Length(S)) And
            (((S[I] >= 'a') And (S[I] <= 'z')) Or
             ((S[I] >= 'A') And (S[I] <= 'Z')) Or
             ((S[I] >= '0') And (S[I] <= '9')) Or
             (S[I] = '_')) Do
      Begin
        If Length(VarN) < MAX_STR Then VarN := VarN + S[I];
        Inc(I);
      End;
      If UseInterp Then
      Begin
        If Length(R) < MAX_STR - 2 Then
          R := R + '{' + MakeCsName(VarN) + '}';
      End
      Else
      Begin
        If Length(R) < MAX_STR - 10 Then
          R := R + '" + ' + MakeCsName(VarN) + ' + "';
      End;
    End
    Else If Ch = '"' Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\"';
      Inc(I);
    End
    Else
    Begin
      If Length(R) < MAX_STR Then R := R + Ch;
      Inc(I);
    End;
  End;
  DqContentToCS := R;
End;

{ Convertit un token de chaine PHP en expression C# complete (avec guillemets) :
  TK_STRING_SQ  -> "contenu" (avec re-echappement)
  TK_STRING_DQ  -> interpolation $"..." (C# 6+) ou concatenation
  TK_HEREDOC    -> comme TK_STRING_DQ
  TK_NOWDOC     -> @"contenu" (verbatim, multi-ligne) }
Function PhpStringToCS(Kind: TTokenKind; Const S: TString): TString;
Var Content: TString;
Begin
  Case Kind Of
    TK_STRING_SQ :
    Begin
      Content := SqContentToCS(S);
      PhpStringToCS := '"' + Content + '"';
    End;
    TK_STRING_DQ, TK_HEREDOC :
    Begin
      Content := DqContentToCS(S);
      If CsVersionGE(Opts.CsVersion, CS_VER_60) Then
        PhpStringToCS := '$"' + Content + '"'
      Else
        PhpStringToCS := '"' + Content + '"';
    End;
    TK_NOWDOC :
    Begin
      Content := NowDocContentToCS(S);
      PhpStringToCS := '@"' + Content + '"';
    End;
  Else
    PhpStringToCS := '"' + S + '"';
  End;
End;

{ Convertit un specifieur de format PHP printf (char apres %) en specifieur
  C# string.Format. I pointe sur le char apres %, ArgIdx = prochain argument. }
Function SprintfSpecToCS(Const S: TString; Var I, ArgIdx: Integer): TString;
Var
  Width, Prec: TString;
  Ch         : Char;
  IdxStr     : TString;
Begin
  Width := ''; Prec := '';
  { Drapeaux optionnels : -, +, 0, espace, ' }
  While (I <= Length(S)) And (S[I] In ['-', '+', '0', ' ', '''']) Do
  Begin
    Inc(I);
  End;
  { Largeur minimale }
  While (I <= Length(S)) And (S[I] >= '0') And (S[I] <= '9') Do
  Begin
    Width := Width + S[I]; Inc(I);
  End;
  { Precision }
  If (I <= Length(S)) And (S[I] = '.') Then
  Begin
    Inc(I);
    While (I <= Length(S)) And (S[I] >= '0') And (S[I] <= '9') Do
    Begin
      Prec := Prec + S[I]; Inc(I);
    End;
  End;
  If I > Length(S) Then
  Begin
    SprintfSpecToCS := '{' + ItoS(ArgIdx) + '}';
    Inc(ArgIdx);
    Exit;
  End;
  Ch := S[I]; Inc(I);
  IdxStr := ItoS(ArgIdx);
  Case Ch Of
    's', 'b': Begin SprintfSpecToCS := '{' + IdxStr + '}'; Inc(ArgIdx); End;
    'd', 'i', 'u':
    Begin
      If Width <> '' Then
        SprintfSpecToCS := '{' + IdxStr + ':D' + Width + '}'
      Else
        SprintfSpecToCS := '{' + IdxStr + ':D}';
      Inc(ArgIdx);
    End;
    'f':
    Begin
      If Prec <> '' Then
        SprintfSpecToCS := '{' + IdxStr + ':F' + Prec + '}'
      Else
        SprintfSpecToCS := '{' + IdxStr + ':F}';
      Inc(ArgIdx);
    End;
    'e': Begin SprintfSpecToCS := '{' + IdxStr + ':e}'; Inc(ArgIdx); End;
    'E': Begin SprintfSpecToCS := '{' + IdxStr + ':E}'; Inc(ArgIdx); End;
    'g', 'G': Begin SprintfSpecToCS := '{' + IdxStr + ':G}'; Inc(ArgIdx); End;
    'x': Begin SprintfSpecToCS := '{' + IdxStr + ':x}'; Inc(ArgIdx); End;
    'X': Begin SprintfSpecToCS := '{' + IdxStr + ':X}'; Inc(ArgIdx); End;
    'o': Begin SprintfSpecToCS := '/* octal */{' + IdxStr + '}'; Inc(ArgIdx); End;
    'c': Begin SprintfSpecToCS := '{' + IdxStr + '}'; Inc(ArgIdx); End;
    '%': SprintfSpecToCS := '%'; { "%%" -> "%" dans le format }
  Else
    SprintfSpecToCS := '{' + IdxStr + '}'; Inc(ArgIdx);
  End;
End;

{ Convertit une chaine de format PHP sprintf en chaine de format C# string.Format.
  Remplace %s par arg-0, %d par arg-0:D, %.2f par arg-0:F2, etc. }
Function SprintfFmtToCS(Const Fmt: TString): TString;
Var
  I, ArgIdx: Integer;
  R: TString;
Begin
  R := ''; ArgIdx := 0; I := 1;
  While I <= Length(Fmt) Do
  Begin
    If Fmt[I] = '%' Then
    Begin
      Inc(I);
      If Length(R) < MAX_STR - 20 Then
        R := R + SprintfSpecToCS(Fmt, I, ArgIdx);
    End
    Else If Fmt[I] = '{' Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '{{';
      Inc(I);
    End
    Else If Fmt[I] = '}' Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '}}';
      Inc(I);
    End
    Else If Fmt[I] = #10 Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\n';
      Inc(I);
    End
    Else If Fmt[I] = #13 Then
    Begin
      If Length(R) < MAX_STR - 1 Then R := R + '\r';
      Inc(I);
    End
    Else
    Begin
      If Length(R) < MAX_STR Then R := R + Fmt[I];
      Inc(I);
    End;
  End;
  SprintfFmtToCS := R;
End;

{ Parse un appel sprintf(fmt, ...) ou printf(fmt, ...) et le convertit en
  string.Format(...) ou Console.Write(string.Format(...)).
  IsWrite=True pour printf. CurTok doit pointer sur '(' a l entree. }
Function ParseSprintfCall(IsWrite: Boolean): TString;
Var
  FmtTok  : TToken;
  FmtCS   : TString;
  CsArgs  : TString;
  ConvFmt : TString;
Begin
  LexNextToken; { saute '(' }
  FmtTok := CurTok;
  FmtCS  := ParseExprStr; { parse l expression de format }
  CsArgs := '';
  While (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ',') Do
  Begin
    LexNextToken;
    If CsArgs <> '' Then CsArgs := CsArgs + ', ';
    CsArgs := CsArgs + ParseExprStr;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
    LexNextToken;
  { Convertir le format si c est un litteral SQ ou DQ }
  If FmtTok.Kind In [TK_STRING_SQ, TK_STRING_DQ, TK_HEREDOC] Then
    ConvFmt := '"' + SprintfFmtToCS(FmtTok.Val) + '"'
  Else
    ConvFmt := FmtCS;
  If IsWrite Then
  Begin
    If CsArgs <> '' Then
      ParseSprintfCall :=
        'Console.Write(string.Format(' + ConvFmt + ', ' + CsArgs + '))'
    Else
      ParseSprintfCall := 'Console.Write(' + ConvFmt + ')';
  End
  Else
  Begin
    If CsArgs <> '' Then
      ParseSprintfCall := 'string.Format(' + ConvFmt + ', ' + CsArgs + ')'
    Else
      ParseSprintfCall := ConvFmt;
  End;
End;

{ Parse un appel number_format(n, dec [, dec_point [, thousands_sep]]) et le
  convertit en n.ToString("F" + dec). CurTok doit pointer sur '('. }
Function ParseNumberFormatCall: TString;
Var
  Args    : Array[1..4] Of TString;
  ArgCount: Integer;
  N, Dec  : TString;
  AllDig  : Boolean;
  K       : Integer;
Begin
  LexNextToken; { saute '(' }
  ArgCount := 0;
  While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')')) And
        (CurTok.Kind <> TK_EOF) And (ArgCount < 4) Do
  Begin
    Inc(ArgCount);
    Args[ArgCount] := ParseExprStr;
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ',') Then
      LexNextToken;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
    LexNextToken;
  N   := '';
  Dec := '';
  If ArgCount >= 1 Then N   := Args[1];
  If ArgCount >= 2 Then Dec := Args[2];
  { Verifier si Dec est un litteral entier }
  AllDig := (Dec <> '');
  For K := 1 To Length(Dec) Do
    If (Dec[K] < '0') Or (Dec[K] > '9') Then AllDig := False;
  If Dec = '' Then
    ParseNumberFormatCall := N + '.ToString()'
  Else If AllDig Then
    ParseNumberFormatCall := N + '.ToString("F' + Dec + '")'
  Else
    ParseNumberFormatCall :=
      N + '.ToString("F" + (' + Dec + ').ToString())';
End;

{ Parse un appel str_pad(s, len [, pad_str [, pad_type]]) et le convertit en
  s.PadRight(len) ou s.PadLeft(len). CurTok doit pointer sur '('. }
Function ParseStrPadCall: TString;
Var
  Args    : Array[1..4] Of TString;
  ArgCount: Integer;
  S, Len  : TString;
  PadType : TString;
  IsLeft  : Boolean;
Begin
  LexNextToken; { saute '(' }
  ArgCount := 0;
  While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')')) And
        (CurTok.Kind <> TK_EOF) And (ArgCount < 4) Do
  Begin
    Inc(ArgCount);
    Args[ArgCount] := ParseExprStr;
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ',') Then
      LexNextToken;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
    LexNextToken;
  S := ''; Len := ''; PadType := '';
  If ArgCount >= 1 Then S       := Args[1];
  If ArgCount >= 2 Then Len     := Args[2];
  If ArgCount >= 4 Then PadType := Args[4];
  { PHP : STR_PAD_RIGHT=1 (defaut), STR_PAD_LEFT=0, STR_PAD_BOTH=2 }
  IsLeft := (PadType = '0') Or (LowStr(PadType) = 'str_pad_left');
  If IsLeft Then
    ParseStrPadCall := S + '.PadLeft(' + Len + ')'
  Else
    ParseStrPadCall := S + '.PadRight(' + Len + ')';
End;

{ ============================================================
  TODO 09 - TRANSPILATION : STRUCTURES DE CONTROLE PHP [IMPLEMENTE]
  ============================================================ }

{ Convertit un nom PHP en label C# valide (supprime $ initial si present) }
Function PhpLabelToCS(Const S: TString): TString;
Begin
  If (Length(S) > 0) And (S[1] = '$') Then
    PhpLabelToCS := MakeCsName(Copy(S, 2, Length(S) - 1))
  Else
    PhpLabelToCS := MakeCsName(S);
End;

{ Parse declare(strict_types=1|0), declare(ticks=N), declare(encoding='X').
  CurTok doit etre le mot-cle 'declare'. }
Procedure ParseDeclareStmt(Indent: Integer);
Var DirName, DirVal: TString;
Begin
  LexNextToken; { saute 'declare' }
  If Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(')) Then Exit;
  LexNextToken; { saute '(' }
  DirName := '';
  DirVal  := '';
  If CurTok.Kind = TK_IDENT Then
  Begin
    DirName := LowStr(CurTok.Val);
    LexNextToken;
    If (CurTok.Kind = TK_OP) And (CurTok.Val = '=') Then
    Begin
      LexNextToken;
      DirVal := CurTok.Val;
      LexNextToken;
    End;
  End;
  { consommer jusqu a ')' }
  While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')')) And
        (CurTok.Kind <> TK_EOF) Do
    LexNextToken;
  If Not (CurTok.Kind = TK_EOF) Then LexNextToken; { saute ')' }
  { consommer ';' si present }
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
  If DirName = 'strict_types' Then
  Begin
    EmitLine(IndentStr(Indent) + '// strict_types=' + DirVal);
    If DirVal = '1' Then
      Opts.StrictTypes := True;
  End
  Else If DirName = 'ticks' Then
    EmitLine(IndentStr(Indent) + '// declare(ticks=' + DirVal + ')')
  Else If DirName = 'encoding' Then
    EmitLine(IndentStr(Indent) + '// declare(encoding=' + DirVal + ')')
  Else
    EmitLine(IndentStr(Indent) + '// declare(' + DirName + '=' + DirVal + ')');
End;

{ Parse goto label; et emet goto CsLabel; avec avertissement.
  CurTok doit etre le mot-cle 'goto'. }
Procedure ParseGotoStmt(Indent: Integer);
Var LabelName: TString;
Begin
  LexNextToken; { saute 'goto' }
  LabelName := '';
  If CurTok.Kind = TK_IDENT Then
  Begin
    LabelName := PhpLabelToCS(CurTok.Val);
    LexNextToken;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
  WarnMsg('goto utilise (ligne ' + ItoS(CurTok.Line) + ')');
  EmitLine(IndentStr(Indent) + 'goto ' + LabelName + ';');
End;

{ Parse un bloc d instructions PHP entre accolades ou en syntaxe alternative.
  Emet les instructions du bloc. EndKw = mot-cle de fermeture (ex. 'endif')
  pour la syntaxe alternative; valeur vide = mode accolades. }
Procedure ParseBlock(Indent: Integer; Const EndKw: TString); Forward;

{ Parse une expression match(expr) et retourne la chaine C#.
  CurTok doit etre le mot-cle 'match'.
  En C# 8+ : genere une switch expression.
  Sinon : genere une chaine if/else. }
Function ParseMatchExpr(Indent: Integer): TString;
Var
  SubjCS   : TString;
  ArmCS    : TString;
  ValCS    : TString;
  Branches : Array[1..64] Of TString;
  Values   : Array[1..64] Of TString;
  DefBranch: TString;
  Count    : Integer;
  IsDefault: Boolean;
  R        : TString;
  I        : Integer;
Begin
  LexNextToken; { saute 'match' }
  SubjCS := '';
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
  Begin
    LexNextToken;
    SubjCS := ParseExprStr;
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
      LexNextToken;
  End;
  { consommer '{' }
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
    LexNextToken;
  Count := 0; DefBranch := '';
  While Not (CurTok.Kind = TK_EOF) And
        Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = '}')) Do
  Begin
    IsDefault := (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'default');
    If IsDefault Then
    Begin
      LexNextToken; { saute 'default' }
      If (CurTok.Kind = TK_OP) And (CurTok.Val = '=>') Then
        LexNextToken;
      DefBranch := ParseExprStr;
    End
    Else
    Begin
      ValCS := ParseExprStr;
      If (CurTok.Kind = TK_OP) And (CurTok.Val = '=>') Then
        LexNextToken;
      ArmCS := ParseExprStr;
      If Count < 64 Then
      Begin
        Inc(Count);
        Values[Count]   := ValCS;
        Branches[Count] := ArmCS;
      End;
    End;
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ',') Then
      LexNextToken;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '}') Then
    LexNextToken;
  { Generer C# }
  If CsVersionGE(Opts.CsVersion, CS_VER_80) Then
  Begin
    R := SubjCS + ' switch { ';
    For I := 1 To Count Do
    Begin
      If Length(R) < MAX_STR - 20 Then
        R := R + Values[I] + ' => ' + Branches[I] + ', ';
    End;
    If DefBranch <> '' Then
      If Length(R) < MAX_STR - 10 Then
        R := R + '_ => ' + DefBranch;
    If Length(R) < MAX_STR Then R := R + ' }';
    ParseMatchExpr := R;
  End
  Else
  Begin
    { if/else chain : generer comme expression ternaire imbriquee }
    R := '';
    For I := Count DownTo 1 Do
    Begin
      If R = '' Then
        R := Branches[I]
      Else
        R := SubjCS + ' == ' + Values[I] + ' ? ' + Branches[I] + ' : ' + R;
    End;
    If DefBranch <> '' Then
      R := SubjCS + ' == ' + Values[1] + ' ? ' + Branches[1] + ' : ' + DefBranch;
    ParseMatchExpr := R;
  End;
End;

{ Parse un bloc PHP : accolades ou syntaxe alternative.
  Indent : niveau d indentation du contenu.
  EndKw  : mot-cle de fin (ex 'endif') pour syntaxe alternative, '' pour accolades. }
Procedure ParseBlock(Indent: Integer; Const EndKw: TString);
Var
  UseAlt   : Boolean;
  KwLow    : TString;
  SaveTok  : TToken;
Begin
  UseAlt := (EndKw <> '');
  If Not UseAlt Then
  Begin
    { accolades : on a deja consomme l accolade ouvrante }
  End;
  { Boucle sur les instructions du bloc }
  While Not (CurTok.Kind = TK_EOF) Do
  Begin
    { Fin de bloc }
    If Not UseAlt Then
    Begin
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '}') Then
      Begin
        LexNextToken; { consommer accolade fermante }
        Break;
      End;
    End
    Else
    Begin
      If (CurTok.Kind = TK_KEYWORD) And
         (LowStr(CurTok.Val) = EndKw) Then
      Begin
        LexNextToken; { consommer le mot-cle endXxx }
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
        Break;
      End;
      { Pour if : sortir sur elseif / else / endif }
      If EndKw = 'endif' Then
      Begin
        KwLow := LowStr(CurTok.Val);
        If (CurTok.Kind = TK_KEYWORD) And
           ((KwLow = 'elseif') Or (KwLow = 'else')) Then
          Break;
      End;
    End;
    { Dispatcher les instructions }
    KwLow := '';
    If CurTok.Kind = TK_KEYWORD Then KwLow := LowStr(CurTok.Val);
    If KwLow = 'if' Then
      ParseIfStmt(Indent)
    Else If KwLow = 'declare' Then
      ParseDeclareStmt(Indent)
    Else If KwLow = 'goto' Then
      ParseGotoStmt(Indent)
    Else If KwLow = 'for' Then
      ParseForStmt(Indent)
    Else If KwLow = 'foreach' Then
      ParseForeachStmt(Indent)
    Else If KwLow = 'while' Then
      ParseWhileStmt(Indent)
    Else If KwLow = 'do' Then
      ParseDoWhileStmt(Indent)
    Else If KwLow = 'break' Then
      ParseBreakStmt(Indent)
    Else If KwLow = 'continue' Then
      ParseContinueStmt(Indent)
    Else If KwLow = 'switch' Then
      ParseSwitchStmt(Indent)
    Else If (CurTok.Kind = TK_IDENT) And (CurTok.Kind <> TK_EOF) Then
    Begin
      { Label : ident suivi de ':' (sans espace entre les deux) }
      SaveTok := CurTok;
      LexNextToken;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
      Begin
        EmitLine(IndentStr(Indent - 1) +
                 PhpLabelToCS(SaveTok.Val) + ':');
        LexNextToken;
      End
      Else
      Begin
        { Consomme l instruction jusqu au ';' }
        While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';')) And
              Not (CurTok.Kind = TK_EOF) Do
          LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End;
    End
    Else If CurTok.Kind = TK_VAR Then
    Begin
      If Not ParseSimpleVarDecl(Indent) Then
      Begin
        While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';')) And
              Not (CurTok.Kind = TK_EOF) Do
          LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End
      Else
      Begin
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End;
    End
    Else
    Begin
      { Instruction inconnue : consomme jusqu au ';' }
      LexNextToken;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
        LexNextToken;
    End;
  End;
End;

{ Parse une instruction if/elseif/else/endif.
  CurTok doit etre le mot-cle 'if'. }
Procedure ParseIfStmt(Indent: Integer);
Var
  CondCS : TString;
  KwLow  : TString;
  First  : Boolean;
Begin
  First  := True;
  { Boucle sur if / elseif }
  While True Do
  Begin
    KwLow := '';
    If CurTok.Kind = TK_KEYWORD Then KwLow := LowStr(CurTok.Val);
    If (KwLow <> 'if') And (KwLow <> 'elseif') Then Break;
    LexNextToken; { saute 'if' ou 'elseif' }
    CondCS := '';
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
    Begin
      LexNextToken;
      CondCS := ParseExprStr;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
        LexNextToken;
    End;
    If First Then
    Begin
      EmitLine(IndentStr(Indent) + 'if (' + CondCS + ')');
      First := False;
    End
    Else
      EmitLine(IndentStr(Indent) + 'else if (' + CondCS + ')');
    EmitLine(IndentStr(Indent) + '{');
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
    Begin
      LexNextToken; { saute ':' }
      { ParseBlock sort sur elseif/else ou consomme endif }
      ParseBlock(Indent + 1, 'endif');
    End
    Else
    Begin
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
        LexNextToken;
      ParseBlock(Indent + 1, '');
    End;
    EmitLine(IndentStr(Indent) + '}');
    { Verifier si elseif ou else suivent }
    KwLow := '';
    If CurTok.Kind = TK_KEYWORD Then KwLow := LowStr(CurTok.Val);
    If (KwLow <> 'elseif') And (KwLow <> 'else') Then Break;
    If KwLow = 'else' Then Break;
  End;
  { else ? }
  If (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'else') Then
  Begin
    LexNextToken; { saute 'else' }
    EmitLine(IndentStr(Indent) + 'else');
    EmitLine(IndentStr(Indent) + '{');
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
    Begin
      LexNextToken;
      ParseBlock(Indent + 1, 'endif');
    End
    Else
    Begin
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
        LexNextToken;
      ParseBlock(Indent + 1, '');
    End;
    EmitLine(IndentStr(Indent) + '}');
  End;
End;

{ ============================================================
  TODO 10 - TRANSPILATION : BOUCLES PHP [IMPLEMENTE]
  ============================================================ }

{ Parse et emet une instruction for PHP.
  CurTok doit etre le mot-cle 'for'.
  Syntaxes supportees :
    for($i=0; $i<n; $i++) begin...end
    for($i=0; $i<n; $i++): ... endfor; }
Procedure ParseForStmt(Indent: Integer);
Var
  InitCS  : TString;
  CondCS  : TString;
  IncrCS  : TString;
  VarName : TString;
  Op      : TString;
  Inferred: TPhpType;
  CsType  : TString;
  UseAlt  : Boolean;
Begin
  LexNextToken; { saute 'for' }
  InitCS := ''; CondCS := ''; IncrCS := '';
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
    LexNextToken;
  { -- Partie init : $var = expr ou expression simple -- }
  If Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';')) Then
  Begin
    If CurTok.Kind = TK_VAR Then
    Begin
      VarName := MakeCsName(VarPhpName(CurTok.Val));
      LexNextToken;
      If (CurTok.Kind = TK_OP) And (CurTok.Val = '=') Then
      Begin
        LexNextToken;
        Inferred := VarInferType(CurTok);
        Case Inferred Of
          PT_INT    : CsType := 'int';
          PT_FLOAT  : CsType := 'double';
          PT_STRING : CsType := 'string';
          PT_BOOL   : CsType := 'bool';
        Else
          CsType := 'var';
        End;
        InitCS := CsType + ' ' + VarName + ' = ' + ParseExprStr;
      End
      Else If (CurTok.Kind = TK_OP) And
              ((CurTok.Val = '++') Or (CurTok.Val = '--')) Then
      Begin
        InitCS := VarName + CurTok.Val;
        LexNextToken;
      End
      Else
        InitCS := VarName;
    End
    Else
      InitCS := ParseExprStr;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
  { -- Partie condition -- }
  CondCS := ParseExprStr;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
  { -- Partie increment : $var++ / $var-- / $var op= expr / pre-incr -- }
  If Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')')) Then
  Begin
    If (CurTok.Kind = TK_OP) And
       ((CurTok.Val = '++') Or (CurTok.Val = '--')) Then
    Begin
      Op := CurTok.Val;
      LexNextToken;
      If CurTok.Kind = TK_VAR Then
      Begin
        VarName := MakeCsName(VarPhpName(CurTok.Val));
        LexNextToken;
        IncrCS := Op + VarName;
      End
      Else
        IncrCS := Op;
    End
    Else If CurTok.Kind = TK_VAR Then
    Begin
      VarName := MakeCsName(VarPhpName(CurTok.Val));
      LexNextToken;
      If (CurTok.Kind = TK_OP) And
         ((CurTok.Val = '++') Or (CurTok.Val = '--')) Then
      Begin
        IncrCS := VarName + CurTok.Val;
        LexNextToken;
      End
      Else If (CurTok.Kind = TK_OP) And
              ((CurTok.Val = '+=') Or (CurTok.Val = '-=') Or
               (CurTok.Val = '*=') Or (CurTok.Val = '/=')) Then
      Begin
        Op := CurTok.Val;
        LexNextToken;
        IncrCS := VarName + ' ' + Op + ' ' + ParseExprStr;
      End
      Else If (CurTok.Kind = TK_OP) And (CurTok.Val = '=') Then
      Begin
        LexNextToken;
        IncrCS := VarName + ' = ' + ParseExprStr;
      End
      Else
        IncrCS := VarName;
    End
    Else
      IncrCS := ParseExprStr;
  End;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
    LexNextToken;
  EmitLine(IndentStr(Indent) + 'for (' + InitCS + '; ' + CondCS + '; ' + IncrCS + ')');
  EmitLine(IndentStr(Indent) + '{');
  UseAlt := (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':');
  If UseAlt Then
  Begin
    LexNextToken;
    ParseBlock(Indent + 1, 'endfor');
  End
  Else
  Begin
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
      LexNextToken;
    ParseBlock(Indent + 1, '');
  End;
  EmitLine(IndentStr(Indent) + '}');
End;

{ Parse et emet une instruction foreach PHP.
  CurTok doit etre le mot-cle 'foreach'.
  Syntaxes supportees :
    foreach($arr as $val) begin...end
    foreach($arr as $key => $val) begin...end
    foreach($arr as $val): ... endforeach; }
Procedure ParseForeachStmt(Indent: Integer);
Var
  ArrCS  : TString;
  KeyCS  : TString;
  ValCS  : TString;
  HasKey : Boolean;
  UseAlt : Boolean;
Begin
  LexNextToken; { saute 'foreach' }
  ArrCS := ''; KeyCS := ''; ValCS := '';
  HasKey := False;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
    LexNextToken;
  { Expression de tableau : s arrete sur le mot-cle 'as' }
  ArrCS := ParseExprStr;
  { Consomme 'as' }
  If (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'as') Then
    LexNextToken;
  { Premiere variable : key ou val }
  KeyCS := ParseExprStr;
  If (CurTok.Kind = TK_OP) And (CurTok.Val = '=>') Then
  Begin
    HasKey := True;
    LexNextToken; { saute '=>' }
    ValCS := ParseExprStr;
  End
  Else
    ValCS := KeyCS;
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
    LexNextToken;
  { Generer C# }
  If HasKey Then
  Begin
    EmitLine(IndentStr(Indent) + 'foreach (var _kvp in ' + ArrCS + ')');
    EmitLine(IndentStr(Indent) + '{');
    EmitLine(IndentStr(Indent + 1) + 'var ' + KeyCS + ' = _kvp.Key;');
    EmitLine(IndentStr(Indent + 1) + 'var ' + ValCS + ' = _kvp.Value;');
  End
  Else
  Begin
    EmitLine(IndentStr(Indent) + 'foreach (var ' + ValCS + ' in ' + ArrCS + ')');
    EmitLine(IndentStr(Indent) + '{');
  End;
  UseAlt := (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':');
  If UseAlt Then
  Begin
    LexNextToken;
    ParseBlock(Indent + 1, 'endforeach');
  End
  Else
  Begin
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
      LexNextToken;
    ParseBlock(Indent + 1, '');
  End;
  EmitLine(IndentStr(Indent) + '}');
End;

{ Parse et emet une instruction while PHP.
  CurTok doit etre le mot-cle 'while'.
  Syntaxes supportees :
    while(expr) begin...end
    while(expr): ... endwhile; }
Procedure ParseWhileStmt(Indent: Integer);
Var
  CondCS : TString;
  UseAlt : Boolean;
Begin
  LexNextToken; { saute 'while' }
  CondCS := '';
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
  Begin
    LexNextToken;
    CondCS := ParseExprStr;
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
      LexNextToken;
  End;
  EmitLine(IndentStr(Indent) + 'while (' + CondCS + ')');
  EmitLine(IndentStr(Indent) + '{');
  UseAlt := (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':');
  If UseAlt Then
  Begin
    LexNextToken;
    ParseBlock(Indent + 1, 'endwhile');
  End
  Else
  Begin
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
      LexNextToken;
    ParseBlock(Indent + 1, '');
  End;
  EmitLine(IndentStr(Indent) + '}');
End;

{ Parse et emet une instruction do...while PHP.
  CurTok doit etre le mot-cle 'do'. }
Procedure ParseDoWhileStmt(Indent: Integer);
Var
  CondCS : TString;
Begin
  LexNextToken; { saute 'do' }
  EmitLine(IndentStr(Indent) + 'do');
  EmitLine(IndentStr(Indent) + '{');
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
    LexNextToken;
  ParseBlock(Indent + 1, '');
  { ParseBlock a deja consomme l accolade fermante du do }
  CondCS := '';
  If (CurTok.Kind = TK_KEYWORD) And (LowStr(CurTok.Val) = 'while') Then
  Begin
    LexNextToken; { saute 'while' }
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
    Begin
      LexNextToken;
      CondCS := ParseExprStr;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
        LexNextToken;
    End;
  End;
  EmitLine(IndentStr(Indent) + '} while (' + CondCS + ');');
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
End;

{ Parse et emet une instruction break PHP.
  CurTok doit etre le mot-cle 'break'.
    break;   -> break;
    break N; -> break; (avertissement si N>1) }
Procedure ParseBreakStmt(Indent: Integer);
Var N: LongInt;
Begin
  LexNextToken; { saute 'break' }
  N := 1;
  If CurTok.Kind = TK_INTEGER Then
  Begin
    N := CurTok.IntVal;
    LexNextToken;
  End;
  If N > 1 Then
    WarnMsg('break ' + ItoS(N) + ' converti en break simple (profondeur > 1)');
  EmitLine(IndentStr(Indent) + 'break;');
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
End;

{ Parse et emet une instruction continue PHP.
  CurTok doit etre le mot-cle 'continue'.
    continue;   -> continue;
    continue N; -> continue; (avertissement si N>1) }
Procedure ParseContinueStmt(Indent: Integer);
Var N: LongInt;
Begin
  LexNextToken; { saute 'continue' }
  N := 1;
  If CurTok.Kind = TK_INTEGER Then
  Begin
    N := CurTok.IntVal;
    LexNextToken;
  End;
  If N > 1 Then
    WarnMsg('continue ' + ItoS(N) + ' converti en continue simple (profondeur > 1)');
  EmitLine(IndentStr(Indent) + 'continue;');
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
    LexNextToken;
End;

{ ============================================================
  TODO 11 - TRANSPILATION : SWITCH ET MATCH PHP [IMPLEMENTE]
  ============================================================ }

{ Parse et emet une instruction switch PHP.
  CurTok doit etre le mot-cle 'switch'.
  Syntaxes supportees :
    switch($var) begin case ... end
    switch($var): ... endswitch;
  Fall-through detecte : avertissement + goto case/goto default.
  Le match PHP 8.0 est deja gere par ParseMatchExpr dans les expressions. }
Procedure ParseSwitchStmt(Indent: Integer);
Var
  SubjCS     : TString;
  KwLow      : TString;
  ValCS      : TString;
  UseAlt     : Boolean;
  HadBreak   : Boolean;
  FirstCase  : Boolean;

Begin
  LexNextToken; { saute 'switch' }
  SubjCS := '';
  If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '(') Then
  Begin
    LexNextToken;
    SubjCS := ParseExprStr;
    If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ')') Then
      LexNextToken;
  End;
  { Determiner le mode accolades vs syntaxe alternative }
  UseAlt := (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':');
  If UseAlt Then
    LexNextToken
  Else If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '{') Then
    LexNextToken;

  EmitLine(IndentStr(Indent) + 'switch (' + SubjCS + ')');
  EmitLine(IndentStr(Indent) + '{');

  { Boucle principale : emettre case par case }
  FirstCase  := True;
  HadBreak   := True;  { avant le premier case : pas de fall-through }

  While Not (CurTok.Kind = TK_EOF) Do
  Begin
    { Fin du switch }
    If Not UseAlt Then
    Begin
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = '}') Then
      Begin
        LexNextToken;
        Break;
      End;
    End
    Else
    Begin
      If (CurTok.Kind = TK_KEYWORD) And
         (LowStr(CurTok.Val) = 'endswitch') Then
      Begin
        LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
        Break;
      End;
    End;

    KwLow := '';
    If CurTok.Kind = TK_KEYWORD Then KwLow := LowStr(CurTok.Val);

    If KwLow = 'case' Then
    Begin
      LexNextToken; { saute 'case' }
      ValCS := ParseExprStr;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
        LexNextToken;
      { Fall-through detecte : le cas precedent n avait pas de break }
      If Not HadBreak And Not FirstCase Then
      Begin
        WarnMsg('fall-through PHP detecte avant case ' + ValCS + ' (ligne ' + ItoS(CurTok.Line) + ')');
        EmitLine(IndentStr(Indent + 2) + 'goto case ' + ValCS + ';');
      End;
      FirstCase := False;
      HadBreak  := False;
      EmitLine(IndentStr(Indent + 1) + 'case ' + ValCS + ':');
    End
    Else If KwLow = 'default' Then
    Begin
      LexNextToken; { saute 'default' }
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ':') Then
        LexNextToken;
      If Not HadBreak And Not FirstCase Then
      Begin
        WarnMsg('fall-through PHP detecte avant default (ligne ' + ItoS(CurTok.Line) + ')');
        EmitLine(IndentStr(Indent + 2) + 'goto default;');
      End;
      FirstCase := False;
      HadBreak  := False;
      EmitLine(IndentStr(Indent + 1) + 'default:');
    End
    Else If KwLow = 'break' Then
    Begin
      LexNextToken;
      If CurTok.Kind = TK_INTEGER Then
        LexNextToken; { ignorer le niveau }
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
        LexNextToken;
      EmitLine(IndentStr(Indent + 2) + 'break;');
      HadBreak := True;
    End
    Else If KwLow = 'return' Then
    Begin
      LexNextToken;
      If Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';')) Then
      Begin
        ValCS := ParseExprStr;
        EmitLine(IndentStr(Indent + 2) + 'return ' + ValCS + ';');
      End
      Else
        EmitLine(IndentStr(Indent + 2) + 'return;');
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
        LexNextToken;
      HadBreak := True;
    End
    Else If KwLow = 'if' Then
    Begin
      ParseIfStmt(Indent + 2);
    End
    Else If KwLow = 'for' Then
      ParseForStmt(Indent + 2)
    Else If KwLow = 'foreach' Then
      ParseForeachStmt(Indent + 2)
    Else If KwLow = 'while' Then
      ParseWhileStmt(Indent + 2)
    Else If KwLow = 'do' Then
      ParseDoWhileStmt(Indent + 2)
    Else If KwLow = 'continue' Then
    Begin
      LexNextToken;
      If CurTok.Kind = TK_INTEGER Then LexNextToken;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
        LexNextToken;
      EmitLine(IndentStr(Indent + 2) + 'continue;');
    End
    Else If CurTok.Kind = TK_VAR Then
    Begin
      If Not ParseSimpleVarDecl(Indent + 2) Then
      Begin
        While Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';')) And
              Not (CurTok.Kind = TK_EOF) Do
          LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End
      Else
      Begin
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End;
    End
    Else
    Begin
      { Expression-instruction : emettre jusqu au ';' }
      If Not ((CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';')) Then
      Begin
        ValCS := ParseExprStr;
        If ValCS <> '' Then
          EmitLine(IndentStr(Indent + 2) + ValCS + ';');
      End;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
        LexNextToken;
    End;
  End;

  EmitLine(IndentStr(Indent) + '}');
End;

Procedure Run;
Var KwLow: TString;
Begin
  { Ouvrir le fichier de sortie }
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('impossible d ouvrir le fichier de sortie : ' + Opts.OutFile);
    Exit;
  End;
  OutFOpen := True;
  LexInit(Opts.SrcFile);
  LexNextToken; { charger le premier token }
  { Consommer l ouverture PHP }
  If CurTok.Kind = TK_OPEN_PHP Then LexNextToken;
  { Boucle principale de transpilation }
  While CurTok.Kind <> TK_EOF Do
  Begin
    KwLow := '';
    If CurTok.Kind = TK_KEYWORD Then KwLow := LowStr(CurTok.Val);
    If KwLow = 'declare' Then
      ParseDeclareStmt(0)
    Else If KwLow = 'if' Then
      ParseIfStmt(0)
    Else If KwLow = 'goto' Then
      ParseGotoStmt(0)
    Else If KwLow = 'for' Then
      ParseForStmt(0)
    Else If KwLow = 'foreach' Then
      ParseForeachStmt(0)
    Else If KwLow = 'while' Then
      ParseWhileStmt(0)
    Else If KwLow = 'do' Then
      ParseDoWhileStmt(0)
    Else If KwLow = 'break' Then
      ParseBreakStmt(0)
    Else If KwLow = 'continue' Then
      ParseContinueStmt(0)
    Else If KwLow = 'switch' Then
      ParseSwitchStmt(0)
    Else If KwLow = 'static' Then
    Begin
      If Not ParseStaticVarDecl(0) Then
      Begin
        LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End
      Else
      Begin
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End;
    End
    Else If CurTok.Kind = TK_VAR Then
    Begin
      If Not ParseSimpleVarDecl(0) Then
      Begin
        LexNextToken;
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End
      Else
      Begin
        If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
          LexNextToken;
      End;
    End
    Else If CurTok.Kind = TK_CLOSE_PHP Then
      LexNextToken
    Else
    Begin
      { Instruction non encore traitee : avancer }
      LexNextToken;
      If (CurTok.Kind = TK_PUNCT) And (CurTok.Val = ';') Then
        LexNextToken;
    End;
  End;
  LexClose;
  WarnMsg('transpilation non encore implementee (TODOs 12-25 a faire)');
End;

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
  If (ParamCount > 0) And
     ((ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  ErrorCount := 0;
  WarnCount  := 0;
  LinesRead  := 0;
  LinesEmit  := 0;
  FnCount    := 0;
  ClassCount := 0;
  SymCount   := 0;
  ScopeTop   := 0;
  UseCount   := 0;
  CurrentNs  := '';
  OutFOpen   := False;

  ParseArgs;
  If Opts.Verbose Then ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
