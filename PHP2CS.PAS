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

  TODO 02 - LEXEUR PHP (TOKENS) [A FAIRE]
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

  TODO 03 - RECONNAISSANCE DES MOTS-CLES PHP [A FAIRE]
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

  TODO 04 - TABLE DES SYMBOLES ET GESTION DES TYPES [A FAIRE]
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

  TODO 05 - GESTION DES SCOPES ET NAMESPACES PHP [A FAIRE]
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

  TODO 06 - TRANSPILATION : DECLARATIONS DE VARIABLES PHP ($var) [A FAIRE]
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

  TODO 07 - TRANSPILATION : EXPRESSIONS [A FAIRE]
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

  TODO 08 - TRANSPILATION : CHAINES ET INTERPOLATION [A FAIRE]
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

  TODO 09 - TRANSPILATION : STRUCTURES DE CONTROLE [A FAIRE]
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

  TODO 10 - TRANSPILATION : BOUCLES [A FAIRE]
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

  TODO 11 - TRANSPILATION : SWITCH ET MATCH [A FAIRE]
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

  { Token courant }
  CurTok     : TToken;

  { Etat du lexeur }
  LexLine    : Integer;
  LexCol     : Integer;
  LexCh      : Char;
  LexEOF     : Boolean;

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
  TODO 02 - LEXEUR PHP (A FAIRE)
  TODO 03 - MOTS-CLES PHP (A FAIRE)
  TODO 04 - TABLE DES SYMBOLES ET TYPES (A FAIRE)
  TODO 05 - GESTION DES SCOPES ET NAMESPACES (A FAIRE)
  TODO 06 - DECLARATIONS DE VARIABLES PHP (A FAIRE)
  TODO 07 - EXPRESSIONS (A FAIRE)
  TODO 08 - CHAINES ET INTERPOLATION (A FAIRE)
  TODO 09 - STRUCTURES DE CONTROLE (A FAIRE)
  TODO 10 - BOUCLES (A FAIRE)
  TODO 11 - SWITCH ET MATCH (A FAIRE)
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

Procedure Run;
Begin
  { TODO 02 : LexInit(Opts.SrcFile) }
  { TODO 24 : EmitHeader }
  { TODO 25 : boucle principale de transpilation }
  { TODO 25 : EmitClose }
  WarnMsg('transpilation non encore implementee (TODOs 02-25 a faire)');
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
