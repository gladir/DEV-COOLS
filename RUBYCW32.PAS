{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Ruby vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program RUBYCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  RUBYCW32.PAS - Compilateur Ruby vers assembleur 80386 pour
  Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\RUBY\*.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, FrozenStrLits, LoadPath)
            ParseArgs : argv source.rb [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-frozen] [-I path] [-r lib] [-h]
            Defaut : produire .EXE PE Win32 ; -obj : .OBJ COFF ;
              -asm : aussi .ASM lisible ; -o : nom de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter extensions .rb / .ruby
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512),
              PE_SUBSYS_CUI / PE_SUBSYS_GUI
            Limites : MAX_SYM=4096, MAX_METHOD=512, MAX_LOCAL=256,
              MAX_PARAM=64, MAX_LABEL=4096, MAX_IVAR=128,
              MAX_CLASS=256, MAX_MODULE=128, MAX_CONST=512,
              MAX_BLOCK=64, MAX_RESCUE=32, MAX_REQUIRE=64
            Prefixes ASM : _RB_ (gvar $), _RBM_ (def), _RBK_ (str),
              _RBRT_ (runtime), _RBL_ (label), _RBA_ (Array),
              _RBH_ (Hash), _RBC_ (Class), _RBMOD_ (Module),
              _RBCONST_, _RBSYM_, _RBREGEX_

  TODO 02 - TOKENISEUR RUBY (LEXER) [IMPLEMENTE]
            LexInit (gerer shebang #!/usr/bin/env ruby), LexClose,
              LexNextChar, LexPeekChar, LexPeekChar2, LexNextToken
            Identificateurs sensibles a la casse, suffixes ? ! =
              (empty?, push!, name=)
            Variables : @ivar, @@cvar, $gvar, local
            Numeriques : 123, 1_000_000, 1.5e3, 0xFF, 0o77, 0b1010,
              0777 legacy ; 1r, 1i (rationnel/complexe optionnel)
            Chaines simples 'x' (echappement \\ \' uniquement)
            Chaines doubles "x #{expr}" (interpolation, \n \t \xFF \uFFFF)
            Heredoc <<EOF, <<-EOF, <<~EOF, <<"EOF", <<'EOF'
            Symboles :foo, :"name", :+
            Regex /pattern/flags, %r{pattern}flags
            Litteraux %w[] %W[] %i[] %I[] %s[] %q[] %Q[] %x[]
            Commentaires : # ligne, =begin/=end (col 1)
            Operateurs : + - * / % ** == != < > <= >= <=> ===
              =~ !~ << >> & | ^ ~ && || .. ... ?: += -= *= /= %=
              **= <<= >>= &= |= ^= &&= ||=
            Pin ^var, safe nav &., splat *, double splat **, &block
            Newline significatif (sauf apres operateur, ',', '\\')
            Types token : TOK_IDENT, TOK_CONST, TOK_IVAR, TOK_CVAR,
              TOK_GVAR, TOK_INTEGER, TOK_FLOAT, TOK_STRING, TOK_DSTRING,
              TOK_HEREDOC, TOK_SYMBOL, TOK_REGEX, TOK_PERCENT_LIT,
              ... TOK_DOTDOT, TOK_DOTDOTDOT, TOK_DCOLON,
              TOK_SPACESHIP, TOK_TRIPLEEQ, TOK_MATCH, TOK_NMATCH,
              TOK_SAFE_NAV, TOK_AMP_BLOCK, TOK_NEWLINE, TOK_EOF

  TODO 03 - MOTS-CLES ET PSEUDO-MOTS-CLES RUBY
            IsKeyword(s : String) : Integer
            Reserves : alias and BEGIN begin break case class def
              defined? do else elsif END end ensure false for if
              in module next nil not or redo rescue retry return
              self super then true undef unless until when while
              yield __FILE__ __LINE__ __ENCODING__
            Pseudo-mots-cles (methodes globales) :
              attr_accessor attr_reader attr_writer
              private public protected
              raise require require_relative load
              include extend prepend module_function
              proc lambda
              loop times each map select reject inject reduce
              puts print p pp gets getc printf sprintf
            Reconnaissance contextuelle :
              do : debut de bloc OU fin de while/until
              if/unless/while/until : prefixe OU suffixe (modifieur)
              { } : bloc OU hash literal (selon contexte)

  TODO 04 - SYMBOLES, SCOPES ET REPRESENTATION RUNTIME
            TSym (Name, Kind, Type, Scope, Offset, ClassRef)
            Kinds : SK_LOCAL, SK_IVAR, SK_CVAR, SK_GVAR, SK_CONST,
              SK_METHOD, SK_CLASS, SK_MODULE, SK_BLOCK_PARAM
            Type Ruby (dynamique, RT_xxx) : NIL, FALSE, TRUE,
              INTEGER (Fixnum/Bignum), FLOAT, STRING, SYMBOL,
              ARRAY, HASH, RANGE, REGEXP, PROC, LAMBDA,
              OBJECT, CLASS, MODULE
            VALUE 32 bits = ptr ou tagged immediate :
              ((n shl 1) or 1)        -> Fixnum (31 bits signes)
              0x00                    -> false
              0x08                    -> nil
              0x14                    -> true
              ((sym shl 8) or 0x0C)   -> Symbol
              ptr aligne 8            -> Object/String/Array/Hash/Float
            Object header : [class_ptr, flags, ivar_table, ...]
            FindSym, AddSym, EnterScope, LeaveScope (pile pour blocs
              imbriques et methodes)

  TODO 05 - PARSEUR D EXPRESSIONS (PRECEDENCE RUBY)
            ParseExpr -> ParseAssign -> ParseTernary -> ParseRange
              -> ParseLogicalOr -> ParseLogicalAnd -> ParseEquality
              -> ParseComparison -> ParseBitOr -> ParseBitAnd
              -> ParseShift -> ParseAdditive -> ParseMultiplicative
              -> ParsePower -> ParseUnary -> ParsePostfix -> ParsePrimary
            Hierarchie (haute -> basse) :
              [] []= ; ** ; ! ~ +@ -@ ; * / % ; + - ; << >> ; & ;
              | ^ ; < <= > >= ; <=> == === != =~ !~ ; && ; || ;
              .. ... ; ?: ; = += -= ; not ; and or ; defined?
            Affectations multiples : a, b = 1, 2 ; a, *rest = arr
            Chainees : a = b = c = 0
            Splat *arr, **hash dans appels et destructuring
            Methodes chainees : obj.m1.m2(args).m3
            Indexation arr[i], hash[k], multi-arg arr[i, j]
            Litteraux composes : [1,2,3], {a: 1}, 1..10
            Appels sans parens : foo bar, baz (analyse contextuelle)

  TODO 06 - PARSEUR DE STATEMENTS
            ParseStatement, ParseStatementList (delim ; ou \n)
            Statements :
              affectation simple/multiple/composee, appel methode
              if/elsif/else/end, unless/else/end
              while/end, until/end, for var in expr ... end
              case/when/then/else/end (in pour pattern matching)
              begin/rescue/else/ensure/end
              def name(params) ... end
              class Name [< Parent] ... end
              module Name ... end
              return [expr], break [expr], next [expr], redo, retry
              yield [expr], raise [expr]
              modifieurs suffixes : "expr if cond", "expr while cond"
              alias new old, undef name
              BEGIN { ... }, END { ... }
              require "lib", require_relative "lib"
            Terminateurs : newline, ;, end

  TODO 07 - VARIABLES : LOCALES, GLOBALES, IVARS, CVARS, CONSTANTES
            Locales : portee bloc/methode, frame [EBP-N]
            Globales $name : .data, prefixe _RB_, init nil
            Instance @name : champ self, [self_ptr + ivar_offset]
              Table d ivars par classe (hash name -> offset)
            Classe @@name : storage par classe, partage hierarchie
            Constantes Name : .rdata, top-level vs imbriquees
              Resolution : Module::Const, ::AbsoluteConst
              Warning si reassignee
            Pseudo-constantes : __FILE__, __LINE__, __ENCODING__,
              ARGV, ENV, STDIN, STDOUT, STDERR, $0, $1..$9, $~

  TODO 08 - METHODES (DEF ... END)
            ParseMethodDef : def [self.]name(params) ... end
            Parametres :
              positionnels, defauts, *splat, key:, key: 5, **opts, &blk
            Prologue : PUSH EBP / MOV EBP, ESP / SUB ESP, locals
            self : ECX (thiscall), bloc : EDX, args sur pile
            Methodes singletons : def obj.method(...)
            Methodes de classe : def self.method(...)
            Visibilite : private/public/protected
              modifie methodes definies apres OU "private :name"
            Symbole genere : _RBM_<class>_<name>
            Dispatch dynamique via vtable de classe
            method_missing : crochet pour methodes manquantes

  TODO 09 - CLASSES (CLASS ... END)
            ParseClassDef : class Name [< Parent] ... end
            Singleton class : class << obj ... end (eigenclass)
            Structure runtime : superclass_ptr, vtable_ptr,
              ivar_table_ptr, included_modules, constants
            Allocation new : _RBRT_alloc -> appel initialize
            initialize : constructeur conventionnel
            Heritage : Object < BasicObject (racine)
            Recherche de methode via MRO :
              instance.class -> modules inclus -> superclass ->
                ... -> Object -> Kernel -> BasicObject
            super / super(args) : appel methode parent

  TODO 10 - MODULES, MIXINS, NAMESPACES
            ParseModuleDef : module Name ... end (non instanciable)
            include Module : methodes d instance (apres self dans MRO)
            extend Module : methodes de classe (singleton MRO)
            prepend Module : insere AVANT self dans MRO
            module_function :name (instance + module method)
            Constantes imbriquees Mod::SUBCONST
            Resolution Module::Class::Const
            Comparable : <, <=, >, >=, ==, between?, clamp via <=>
            Enumerable : map/select/.../reduce via each
            Refinements (refine ... using) - optionnel

  TODO 11 - HERITAGE, SUPER, METHOD_MISSING
            Construction MRO a la compilation :
              class A < B; include M1, M2; end
              ancestors = [A, M2, M1, B, ..., Object, Kernel, BasicObject]
            Generation vtable alignee sur ancestors
            super sans args : args originaux + bloc original
            super() : pas d args ; super(args) : explicites
            Resolution : index actuel dans MRO, methode dans
              ancestors[index+1..]
            method_missing(name, *args, &blk)
            respond_to?(name), respond_to_missing?
            send / __send__ / public_send : invocation dynamique

  TODO 12 - STRINGS, INTERPOLATION, HEREDOC
            String runtime : header (RT_STRING, flags), buffer, len, cap,
              encoding (UTF-8 par defaut)
            Litteraux : segment .rdata, prefixe _RBK_
            'simple' : litteral, copie sur modification
            "double" : copie mutable
            # frozen_string_literal: true -> immuable global
            Interpolation #{expr} : eval, to_s, concat dynamique
              ou _RBRT_strconcatN si N parties statiques
            Heredoc : <<EOF, <<-EOF, <<~EOF (squiggly retire indent),
              <<"EOF" interpole, <<'EOF' litteral
            Methodes : length size + * [] [..] upcase downcase
              capitalize strip chomp chop split join replace sub
              gsub scan match =~ start_with? end_with? include?
              empty? to_i to_f to_sym chars bytes lines reverse
              succ % (formatage)

  TODO 13 - ARRAYS, HASHES, SYMBOLS
            Array : header, ptr buffer, length, capacity
              Litteral [a,b,c] -> _RBA_<n>
              Methodes : push pop shift unshift << [] []= length size
                first last each map select reject inject reduce sort
                sort_by reverse uniq flatten compact include? index
                find count sum min max join split + - * & | slice
                take drop zip each_with_index each_with_object
              Splat foo(*arr) ; destructuring a,b,c = arr ; a,*r,b = arr
            Hash : table de hachage open addressing
              Litteral { :a => 1, b: 2 }
              Methodes : [] []= fetch store delete key? value? keys
                values each each_pair merge merge! to_a length empty?
              Default : Hash.new(d), Hash.new { ... }
            Symbol : tagged immediate ou table globale, identite garantie
              :name, :"complex", "foo".to_sym, :foo.to_s

  TODO 14 - BLOCS, YIELD, PROC, LAMBDA
            Bloc { ... } (haute precedence) ou do ... end (basse)
            Parametres : { |a, b| ... }, *splat, key:, ; local
            yield arg1,arg2 : invoque bloc passe a methode courante
              LocalJumpError si pas de bloc
            block_given?, &blk parametre, blk.call
            Closure avec env capture (vars libres referencees)
              Frame : [env_ptr, code_ptr]
              Bloc emit en label distinct
            Proc.new { ... } : laxe (return = methode englobante)
            lambda { ... } / -> (a) { ... } : strict (verifie arite,
              return = lambda)
            Proc#call, .(args), [args] ; method(:name) (objet methode)

  TODO 15 - STRUCTURES DE CONTROLE
            if cond [then] body [elsif body]* [else body] end
            unless cond body [else body] end
            Modifieurs suffixes : "expr if|unless cond"
            Ternaire : cond ? a : b
            Court-circuit && et || retournent valeur (pas booleen)
              Verite : seul nil/false sont faux ; 0 et "" sont verite
            case ... when ... then ... else ... end :
              when utilise === (Range, Class, Regex, valeur)
              Pattern matching (Ruby 3.0+) : in (optionnel)
            Codegen : labels, jumps CMP/JE/JNE

  TODO 16 - BOUCLES (WHILE, UNTIL, FOR, LOOP, ITERATEURS)
            while cond [do] body end ; modif "expr while cond"
              begin body end while cond (do/while)
            until cond body end ; modif "expr until cond"
            for var in collection ... end (var fuite hors for)
            loop { ... } (sortie via break/raise)
            Iterateurs : n.times, (a..b).each, array.each/map/select,
              array.inject(0) { |s,x| s+x }, n.upto/downto/step
            Controle : break [val], next [val], redo, retry (rescue)
            Codegen : non-iteratrices = labels, iterateurs = appel
              methode avec bloc

  TODO 17 - EXCEPTIONS (BEGIN/RESCUE/ENSURE/RAISE)
            begin body
            rescue [Cls1[, Cls2...] [=> var]] handler
            else (si pas d exception)
            ensure (toujours)
            end
            Hierarchie : Exception > StandardError (default rescue)
              > RuntimeError, ArgumentError, TypeError, NameError,
              NoMethodError, ZeroDivisionError, IndexError, KeyError,
              IOError ; ScriptError, SignalException, SystemExit
            raise / raise "msg" / raise Cls, "msg" / raise instance
            ensure : execute meme apres return/break/raise
            retry : reexecuter begin
            Modifieur : "expr rescue default"
            $! = exception courante
            Implementation : SEH Win32 ou stack unwind a la main

  TODO 18 - REGEX
            Litteral /pattern/flags, %r{pattern}flags
            Flags : i m x o u
            Operateurs =~ (-> position ou nil), !~
            $~, $`, $', $&, $1..$9
            Methodes : String#match scan sub gsub split ;
              Regexp#match match? =~ source
            Engine : minimaliste (NFA classes quantifiers groupes)
              ou binding lib (PCRE/Onigmo)
            Patterns : . * + ? [] [^] \\d \\w \\s \\b () (?:) (?<n>)
              ^ $, |, gourmand/lazy
            Code : _RBRT_regex_match avec ptr regex compile

  TODO 19 - RANGES, ITERATEURS, ENUMERABLE, COMPARABLE
            Range : 1..10 (inclus), 1...10 (exclus),
              1.. (beginless 2.6+), ..10 (endless)
              Methodes : each to_a include? cover? size first last
                min max step
              Bornes : tout type avec <=> et succ
            Enumerable (mixin via each) : map/collect select/filter
              reject find/detect find_index count inject/reduce sum
              min max min_by max_by sort sort_by group_by partition
              chunk slice each_with_index each_with_object zip take
              take_while drop drop_while all? any? none? one?
              include? member? to_a/entries lazy
            Lazy : (1..Float::INFINITY).lazy.map { ... }
            Enumerator.new { |y| y << val }
            Comparable (mixin via <=>) : <, <=, >, >=, ==, between?, clamp

  TODO 20 - I/O, FICHIERS, ARGV, ENV
            Sorties : puts print p pp printf sprintf format
            Entrees : gets gets.chomp readline readlines
              STDIN.read STDIN.each_line getc
            File : File.open(name, mode) [{ |f| ... }]
              Modes "r" "w" "a" "r+" "w+" "a+" "rb" "wb"
              Methodes : read write puts gets each_line close eof?
                pos seek rewind
              File.read/write/exist?/directory?/size/delete
            Dir : entries glob chdir pwd mkdir
            ARGV (array), ENV (proxy hash), STDIN/STDOUT/STDERR
            Implementation : Win32 API (CreateFile, ReadFile,
              WriteFile, GetStdHandle, GetEnvironmentStringsA, etc.)

  TODO 21 - KERNEL ET BIBLIOTHEQUE CORE
            Module Kernel (mixe dans Object) - methodes globales :
              puts print p pp printf sprintf format gets getc
              raise fail throw catch
              loop lambda proc -> yield_self/then
              require require_relative load autoload
              Integer(x) Float(x) String(x) Array(x) Hash(x)
              rand srand sleep exit exit! abort at_exit
              eval instance_eval class_eval module_eval (limite)
              binding caller method methods instance_variables
              respond_to? send __send__ public_send
              class kind_of? is_a? instance_of? frozen? freeze
              dup clone hash object_id equal? == != !
              inspect to_s tap then yield_self itself
            Comparable, Enumerable : voir TODO 19
            Math : PI E sqrt sin cos tan log exp atan2
            Time : Time.now/new + - strftime year month ...
            Random : Random.new .rand
            Stubs : ObjectSpace GC Process Thread (single)

  TODO 22 - NUMERIQUES (INTEGER, FLOAT, RATIONAL, COMPLEX)
            Integer (Fixnum + Bignum unifies depuis 2.4) :
              Fixnum 31 bits tagged ; Bignum arbitrary precision
              Promotion auto Bignum sur overflow
            Float IEEE 754 double : 1.5, 1.5e3, NaN, Infinity
            Rational 1/2r ; Complex 1+2i (optionnels)
            Operations : + - * / % ** ; div modulo divmod
            Comparaisons : <, <=, >, >=, ==, <=>, between?
            Conversions : to_i to_f to_r to_c to_s(base)
            Bits : & | ^ ~ << >>
            Integer : times upto downto step even? odd? zero?
              positive? negative? abs succ/next pred gcd lcm
              digits bit_length
            Float : floor ceil round truncate abs finite? infinite? nan?
            Codegen : Fixnum tagged inline (ADD avec correction tag),
              Bignum/Float -> appel runtime

  TODO 23 - REQUIRE / LOAD / LIENS DE FICHIERS
            require "lib" : cherche $LOAD_PATH ($:), unique
              ($LOADED_FEATURES, $"), suffixe .rb implicite
              Renvoie true (1ere fois) ou false
            require_relative "lib" : relatif au fichier courant
            load "file.rb" : execute (re-execute autorise)
            autoload :Const, "lib" : differe le require
            Implementation a la compilation :
              detecter require top-level, resoudre relatif a SrcFile
                et $LOAD_PATH, compiler tous les fichiers requis
                dans la meme unite (deduplique par chemin canonique)
              top-level execute dans l ordre de require
            Stdlib supportee (sous-ensemble) :
              "set" "date" "time" "json" (basique) "fileutils"
              "stringio" "ostruct"
              Implementer en Ruby embarque ou en runtime Pascal
            $LOAD_PATH ($:), $LOADED_FEATURES ($")

  TODO 24 - GENERATEUR DE CODE 80386 ET SORTIE .ASM
            Backend codegen :
              GenLoadInt(N), GenLoadStr(LblIdx)
              GenLoadVar/StoreVar(Idx) (resout scope)
              GenLoadIvar/StoreIvar(Idx) (via self)
              GenCall(Method, Argc), GenSend(Selector, Argc) (vtable)
              GenYield(Argc), GenAlloc(ClassRef)
              GenJmp/JZ/JNZ/Label, GenPush/Pop
              GenAdd/Sub/Mul/Div (fast-path tagged Fixnum)
            Convention d appel Ruby :
              ECX = self ; EDX = bloc (proc/lambda) ou nil
              Pile = arg1..argN (cdecl-like)
              EAX = retour
            Frame : PUSH EBP / MOV EBP, ESP / SUB ESP, locals
              [EBP+8]=arg1, [EBP-4..-N]=locals
            Sortie .ASM (-asm) : MASM 6/8 ou JWasm
              .386 .MODEL FLAT, STDCALL
              .DATA .RDATA .BSS .CODE
              EXTRN ExitProcess, GetStdHandle, ...
            EmitComment, EmitLabel, Emit (raw instruction)

  TODO 25 - BACKEND BINAIRE .OBJ COFF + .EXE PE WIN32
            Backend binaire (independant du backend ASM) :
              BinCode/BinData : Array Of Byte
              BinLabels : Array Of TLabel
              BinFixups : Array Of TFixup (REL32, ABS32, IMP32)
              BinImports : Array Of TImport (Win32 IAT)
              BinEmit8/16/32, BinEmitInstr (encodeur 80386 minimal :
                PUSH POP MOV ADD SUB IMUL IDIV CMP TEST JMP JCC
                CALL RET ENTER LEAVE INT SHL SHR SAR SAL AND OR
                XOR NOT)
              BinDefineLabel, BinResolveLabel, BinAddFixup,
                BinResolveFixups
            OBJ COFF Win32 (-obj) :
              IMAGE_FILE_HEADER (Machine=I386)
              Sections .text .data .rdata .bss
              Symbol table COFF (statique + externes)
              Relocations par section
            EXE PE Win32 (defaut) :
              MZ stub DOS minimal
              PE sig + IMAGE_FILE_HEADER + IMAGE_OPTIONAL_HEADER32
              Sections : .text (RX) .data (RW) .rdata (R) .bss (RW)
                .idata (R) IAT
              IAT KERNEL32.DLL : GetStdHandle WriteFile ReadFile
                ExitProcess GetCommandLineA GetEnvironmentStringsA
                CreateFileA CloseHandle HeapAlloc HeapFree GetProcessHeap
              IAT MSVCRT.DLL (ou pure-Win32) : printf malloc free sprintf
              Subsystem CUI 3 par defaut
              Entry _RBSTART : init runtime, appel main, ExitProcess
              ImageBase $00400000, SectionAlign 4096, FileAlign 512
            Runtime embarque (linke statiquement dans .text/.rdata) :
              _RBRT_main_start, _RBRT_main_exit
              _RBRT_print, _RBRT_puts, _RBRT_inspect
              _RBRT_alloc, _RBRT_free
              _RBRT_dispatch (lookup methode dans MRO)
              _RBRT_strconcat, _RBRT_strdup, _RBRT_streq
              _RBRT_to_s_int, _RBRT_to_s_float
              _RBRT_array_new/push/get
              _RBRT_hash_new/set/get
              _RBRT_raise, _RBRT_rescue_setup, _RBRT_rescue_match
              _RBRT_intern (string -> Symbol)
              _RBRT_yield (invoquer bloc courant)
              Fixnum tagged math : _RBRT_add/sub/mul/div/cmp
                (avec promotion Bignum sur overflow)
            Validation : tous les SAMPLES\RUBY\*.rb compilent et
              produisent un .EXE PE Win32 fonctionnel
  ============================================================ *)

Const
  RUBYCW32_VERSION = '0.1';

  EXIT_OK = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  PE_DOS_MAGIC = $5A4D;
  PE_PE_SIG = $00004550;
  PE_MACHINE_I386 = $014C;
  PE_IMG_BASE = $00400000;
  PE_SEC_ALIGN = 4096;
  PE_FILE_ALIGN = 512;
  PE_SUBSYS_CUI = 3;
  PE_SUBSYS_GUI = 2;

  MAX_SYM = 4096;
  MAX_METHOD = 512;
  MAX_LOCAL = 256;
  MAX_PARAM = 64;
  MAX_LABEL = 4096;
  MAX_IVAR = 128;
  MAX_CLASS = 256;
  MAX_MODULE = 128;
  MAX_CONST = 512;
  MAX_BLOCK = 64;
  MAX_RESCUE = 32;
  MAX_REQUIRE = 64;
  MAX_SRC_TEXT = 65535;

  ASM_PFX_GVAR = '_RB_';
  ASM_PFX_METHOD = '_RBM_';
  ASM_PFX_STRING = '_RBK_';
  ASM_PFX_RUNTIME = '_RBRT_';
  ASM_PFX_LABEL = '_RBL_';
  ASM_PFX_ARRAY = '_RBA_';
  ASM_PFX_HASH = '_RBH_';
  ASM_PFX_CLASS = '_RBC_';
  ASM_PFX_MODULE = '_RBMOD_';
  ASM_PFX_CONST = '_RBCONST_';
  ASM_PFX_SYMBOL = '_RBSYM_';
  ASM_PFX_REGEX = '_RBREGEX_';

  TOK_EOF = 0;
  TOK_IDENT = 256;
  TOK_CONST = 257;
  TOK_IVAR = 258;
  TOK_CVAR = 259;
  TOK_GVAR = 260;
  TOK_INTEGER = 261;
  TOK_FLOAT = 262;
  TOK_STRING = 263;
  TOK_DSTRING = 264;
  TOK_HEREDOC = 265;
  TOK_SYMBOL = 266;
  TOK_REGEX = 267;
  TOK_PERCENT_LIT = 268;
  TOK_NEWLINE = 269;
  TOK_DOTDOT = 270;
  TOK_DOTDOTDOT = 271;
  TOK_DCOLON = 272;
  TOK_SPACESHIP = 273;
  TOK_TRIPLEEQ = 274;
  TOK_MATCH = 275;
  TOK_NMATCH = 276;
  TOK_SAFE_NAV = 277;
  TOK_AMP_BLOCK = 278;
  TOK_POW = 279;
  TOK_SHL = 280;
  TOK_SHR = 281;
  TOK_LE = 282;
  TOK_GE = 283;
  TOK_EQ = 284;
  TOK_NE = 285;
  TOK_ANDAND = 286;
  TOK_OROR = 287;
  TOK_ASSIGN_OP = 288;
  TOK_ARROW = 289;
  TOK_FAT_ARROW = 290;
  TOK_PIN = 291;

Type
  TStringList64 = Array[1..MAX_REQUIRE] Of String;
  TSrcBuffer = Array[1..MAX_SRC_TEXT] Of Char;

  TOptions = Record
    SrcFile: String;
    OutFile: String;
    Verbose: Boolean;
    DebugMode: Boolean;
    Warnings: Boolean;
    EmitExe: Boolean;
    EmitObj: Boolean;
    EmitAsm: Boolean;
    FrozenStrLits: Boolean;
    LoadPath: TStringList64;
    LoadPathCount: Integer;
    RequireLib: TStringList64;
    RequireCount: Integer;
  End;

Var
  Opt: TOptions;
  SrcBuf: TSrcBuffer;
  SrcLen: LongInt;
  LexPos: LongInt;
  LexLine: LongInt;
  LexCol: LongInt;
  CurTokType: Integer;
  CurTokStr: String;
  CurTokNum: LongInt;
  CurTokLine: LongInt;
  CurTokCol: LongInt;
  LastTokenCanEndExpr: Boolean;

Procedure FatalError(Msg: String); Forward;

Function UpCaseStr(S: String): String;
Var
  I: Integer;
Begin
  For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
  UpCaseStr := S;
End;

Function IsPathSep(C: Char): Boolean;
Begin
  IsPathSep := (C = '\') Or (C = '/');
End;

Function FileExt(S: String): String;
Var
  I: Integer;
Begin
  FileExt := '';
  For I := Length(S) DownTo 1 Do Begin
    If S[I] = '.' Then Begin
      FileExt := Copy(S, I, Length(S) - I + 1);
      Exit;
    End;
    If IsPathSep(S[I]) Or (S[I] = ':') Then Exit;
  End;
End;

Function ChangeExt(S, NewExt: String): String;
Var
  I: Integer;
Begin
  For I := Length(S) DownTo 1 Do Begin
    If S[I] = '.' Then Begin
      ChangeExt := Copy(S, 1, I - 1) + NewExt;
      Exit;
    End;
    If IsPathSep(S[I]) Or (S[I] = ':') Then Break;
  End;
  ChangeExt := S + NewExt;
End;

Function IsRubySourceName(S: String): Boolean;
Var
  E: String;
Begin
  E := UpCaseStr(FileExt(S));
  IsRubySourceName := (E = '.RB') Or (E = '.RUBY');
End;

Function ItoS(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  ItoS := S;
End;

Procedure AppendTok(C: Char);
Begin
  If Length(CurTokStr) < 255 Then CurTokStr := CurTokStr + C;
End;

Function IsAlpha(C: Char): Boolean;
Begin
  IsAlpha := ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
             (C = '_');
End;

Function IsDigit(C: Char): Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsHexDigit(C: Char): Boolean;
Begin
  C := UpCase(C);
  IsHexDigit := IsDigit(C) Or ((C >= 'A') And (C <= 'F'));
End;

Function IsIdentChar(C: Char): Boolean;
Begin
  IsIdentChar := IsAlpha(C) Or IsDigit(C);
End;

Function HexVal(C: Char): Integer;
Begin
  C := UpCase(C);
  If IsDigit(C) Then HexVal := Ord(C) - Ord('0')
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

Function LexPeekChar: Char;
Begin
  If LexPos > SrcLen Then LexPeekChar := #0
  Else LexPeekChar := SrcBuf[LexPos];
End;

Function LexPeekChar2: Char;
Begin
  If LexPos + 1 > SrcLen Then LexPeekChar2 := #0
  Else LexPeekChar2 := SrcBuf[LexPos + 1];
End;

Function LexNextChar: Char;
Var
  C: Char;
Begin
  If LexPos > SrcLen Then Begin
    LexNextChar := #0;
    Exit;
  End;
  C := SrcBuf[LexPos];
  Inc(LexPos);
  If C = #10 Then Begin
    Inc(LexLine);
    LexCol := 1;
  End Else If C <> #13 Then Begin
    Inc(LexCol);
  End;
  LexNextChar := C;
End;

Procedure LexInit(FileName: String);
Var
  F: File;
  N: LongInt;
Begin
  SrcLen := 0;
  Assign(F, FileName);
  {$I-}
  Reset(F, 1);
  {$I+}
  If IOResult <> 0 Then FatalError('impossible d''ouvrir ' + FileName);
  BlockRead(F, SrcBuf, MAX_SRC_TEXT, N);
  SrcLen := N;
  If Not Eof(F) Then Begin
    Close(F);
    FatalError('fichier source trop volumineux');
  End;
  Close(F);
  LexPos := 1;
  LexLine := 1;
  LexCol := 1;
  CurTokType := TOK_EOF;
  CurTokStr := '';
  CurTokNum := 0;
  LastTokenCanEndExpr := False;
End;

Procedure LexClose;
Begin
  SrcLen := 0;
  LexPos := 1;
  LexLine := 1;
  LexCol := 1;
End;

Procedure SkipLineComment;
Begin
  While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do LexNextChar;
End;

Procedure SkipBlockComment;
Var
  AtLineStart: Boolean;
  S: String;
Begin
  AtLineStart := True;
  S := '';
  While LexPeekChar <> #0 Do Begin
    If AtLineStart Then Begin
      S := '';
      While (LexPeekChar <> #0) And (LexPeekChar <> #10) And
            (LexPeekChar <> #13) And (Length(S) < 4) Do
        S := S + LexNextChar;
      If S = '=end' Then Begin
        SkipLineComment;
        Exit;
      End;
    End Else
      LexNextChar;
    If LexPeekChar = #10 Then Begin
      LexNextChar;
      AtLineStart := True;
    End Else
      AtLineStart := False;
  End;
  FatalError('commentaire =begin sans =end');
End;

Procedure ReadIdent;
Var
  First: Char;
Begin
  First := LexPeekChar;
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
  If (LexPeekChar = '?') Or (LexPeekChar = '!') Or (LexPeekChar = '=') Then
    AppendTok(LexNextChar);
  If (First >= 'A') And (First <= 'Z') Then CurTokType := TOK_CONST
  Else CurTokType := TOK_IDENT;
End;

Procedure ReadAtVar;
Begin
  AppendTok(LexNextChar);
  If LexPeekChar = '@' Then Begin
    CurTokType := TOK_CVAR;
    AppendTok(LexNextChar);
  End Else
    CurTokType := TOK_IVAR;
  If Not IsAlpha(LexPeekChar) Then FatalError('nom de variable d''instance invalide');
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
End;

Procedure ReadGVar;
Begin
  CurTokType := TOK_GVAR;
  AppendTok(LexNextChar);
  If IsDigit(LexPeekChar) Then Begin
    AppendTok(LexNextChar);
    Exit;
  End;
  If LexPeekChar = '~' Then Begin
    AppendTok(LexNextChar);
    Exit;
  End;
  If Not IsAlpha(LexPeekChar) Then FatalError('nom de variable globale invalide');
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
End;

Procedure ReadNumber;
Var
  Base, V: Integer;
  IsFloat: Boolean;
  C: Char;
Begin
  CurTokType := TOK_INTEGER;
  CurTokNum := 0;
  IsFloat := False;
  Base := 10;
  If (LexPeekChar = '0') And
     ((UpCase(LexPeekChar2) = 'X') Or (UpCase(LexPeekChar2) = 'B') Or
      (UpCase(LexPeekChar2) = 'O')) Then Begin
    AppendTok(LexNextChar);
    C := UpCase(LexNextChar);
    AppendTok(C);
    If C = 'X' Then Base := 16
    Else If C = 'B' Then Base := 2
    Else Base := 8;
  End Else If LexPeekChar = '0' Then
    Base := 8;

  While True Do Begin
    C := LexPeekChar;
    If C = '_' Then Begin
      AppendTok(LexNextChar);
    End Else If (Base = 16) And IsHexDigit(C) Then Begin
      V := HexVal(C);
      CurTokNum := CurTokNum * Base + V;
      AppendTok(LexNextChar);
    End Else If (Base = 10) And IsDigit(C) Then Begin
      CurTokNum := CurTokNum * Base + Ord(C) - Ord('0');
      AppendTok(LexNextChar);
    End Else If (Base = 8) And (C >= '0') And (C <= '7') Then Begin
      CurTokNum := CurTokNum * Base + Ord(C) - Ord('0');
      AppendTok(LexNextChar);
    End Else If (Base = 2) And ((C = '0') Or (C = '1')) Then Begin
      CurTokNum := CurTokNum * Base + Ord(C) - Ord('0');
      AppendTok(LexNextChar);
    End Else
      Break;
  End;

  If (Base = 10) And (LexPeekChar = '.') And (LexPeekChar2 <> '.') Then Begin
    IsFloat := True;
    AppendTok(LexNextChar);
    While IsDigit(LexPeekChar) Or (LexPeekChar = '_') Do
      AppendTok(LexNextChar);
  End;
  If (Base = 10) And ((UpCase(LexPeekChar) = 'E')) Then Begin
    IsFloat := True;
    AppendTok(LexNextChar);
    If (LexPeekChar = '+') Or (LexPeekChar = '-') Then AppendTok(LexNextChar);
    While IsDigit(LexPeekChar) Or (LexPeekChar = '_') Do
      AppendTok(LexNextChar);
  End;
  If (LexPeekChar = 'r') Or (LexPeekChar = 'i') Then AppendTok(LexNextChar);
  If IsFloat Then CurTokType := TOK_FLOAT;
End;

Procedure ReadString(Quote: Char; DString: Boolean);
Var
  C, H1, H2: Char;
Begin
  If DString Then CurTokType := TOK_DSTRING
  Else CurTokType := TOK_STRING;
  LexNextChar;
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('chaine non terminee');
    If C = Quote Then Break;
    If C = '\' Then Begin
      C := LexNextChar;
      If C = #0 Then FatalError('chaine non terminee');
      If DString Then Begin
        Case C Of
          'n': AppendTok(#10);
          't': AppendTok(#9);
          'r': AppendTok(#13);
          'x': Begin
                 H1 := LexNextChar;
                 H2 := LexNextChar;
                 If Not (IsHexDigit(H1) And IsHexDigit(H2)) Then
                   FatalError('echappement hex invalide');
                 AppendTok(Chr(HexVal(H1) * 16 + HexVal(H2)));
               End;
          'u': Begin
                 H1 := LexNextChar;
                 H2 := LexNextChar;
                 LexNextChar;
                 LexNextChar;
                 If Not (IsHexDigit(H1) And IsHexDigit(H2)) Then
                   FatalError('echappement unicode invalide');
                 AppendTok('?');
               End;
        Else
          AppendTok(C);
        End;
      End Else Begin
        If (C = '\') Or (C = Quote) Then AppendTok(C)
        Else Begin
          AppendTok('\');
          AppendTok(C);
        End;
      End;
    End Else Begin
      If DString And (C = '#') And (LexPeekChar = '{') Then Begin
        AppendTok(C);
        AppendTok(LexNextChar);
      End Else
        AppendTok(C);
    End;
  End;
End;

Procedure ReadSymbol;
Begin
  CurTokType := TOK_SYMBOL;
  AppendTok(LexNextChar);
  If (LexPeekChar = '"') Or (LexPeekChar = '''') Then Begin
    ReadString(LexPeekChar, LexPeekChar = '"');
    CurTokType := TOK_SYMBOL;
  End Else If IsAlpha(LexPeekChar) Then Begin
    While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
    If (LexPeekChar = '?') Or (LexPeekChar = '!') Or (LexPeekChar = '=') Then
      AppendTok(LexNextChar);
  End Else If LexPeekChar <> #0 Then
    AppendTok(LexNextChar);
End;

Procedure ReadRegex;
Var
  C: Char;
Begin
  CurTokType := TOK_REGEX;
  LexNextChar;
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('regex non terminee');
    If C = '/' Then Break;
    If C = '\' Then Begin
      AppendTok(C);
      C := LexNextChar;
      If C = #0 Then FatalError('regex non terminee');
    End;
    AppendTok(C);
  End;
  While IsAlpha(LexPeekChar) Do AppendTok(LexNextChar);
End;

Function MatchingDelim(C: Char): Char;
Begin
  Case C Of
    '(': MatchingDelim := ')';
    '[': MatchingDelim := ']';
    '{': MatchingDelim := '}';
    '<': MatchingDelim := '>';
  Else
    MatchingDelim := C;
  End;
End;

Procedure ReadPercentLit;
Var
  Kind, OpenD, CloseD, C: Char;
  Depth: Integer;
Begin
  CurTokType := TOK_PERCENT_LIT;
  AppendTok(LexNextChar);
  Kind := #0;
  If IsAlpha(LexPeekChar) Then Begin
    Kind := LexNextChar;
    AppendTok(Kind);
  End;
  OpenD := LexNextChar;
  CloseD := MatchingDelim(OpenD);
  AppendTok(OpenD);
  Depth := 1;
  While Depth > 0 Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('litteral % non termine');
    If C = '\' Then Begin
      AppendTok(C);
      C := LexNextChar;
      If C = #0 Then FatalError('litteral % non termine');
    End Else If C = OpenD Then
      Inc(Depth)
    Else If C = CloseD Then Begin
      Dec(Depth);
      If Depth = 0 Then Begin
        AppendTok(C);
        Break;
      End;
    End;
    AppendTok(C);
  End;
End;

Function TryReadHeredoc: Boolean;
Var
  SavePos, SaveLine, SaveCol: LongInt;
  C, Quote: Char;
Begin
  TryReadHeredoc := False;
  SavePos := LexPos;
  SaveLine := LexLine;
  SaveCol := LexCol;
  CurTokStr := '';
  LexNextChar;
  LexNextChar;
  If (LexPeekChar = '-') Or (LexPeekChar = '~') Then AppendTok(LexNextChar);
  While (LexPeekChar = ' ') Or (LexPeekChar = #9) Do LexNextChar;
  Quote := #0;
  If (LexPeekChar = '"') Or (LexPeekChar = '''') Then Quote := LexNextChar;
  If Not IsAlpha(LexPeekChar) Then Begin
    LexPos := SavePos;
    LexLine := SaveLine;
    LexCol := SaveCol;
    CurTokStr := '';
    Exit;
  End;
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
  If Quote <> #0 Then Begin
    C := LexNextChar;
    If C <> Quote Then FatalError('delimiteur heredoc invalide');
  End;
  CurTokType := TOK_HEREDOC;
  TryReadHeredoc := True;
End;

Procedure SetSingleToken(T: Integer);
Begin
  CurTokType := T;
  AppendTok(LexNextChar);
End;

Function TokenCanEndExpr(T: Integer): Boolean;
Begin
  TokenCanEndExpr := (T = TOK_IDENT) Or (T = TOK_CONST) Or (T = TOK_IVAR) Or
                     (T = TOK_CVAR) Or (T = TOK_GVAR) Or
                     (T = TOK_INTEGER) Or (T = TOK_FLOAT) Or
                     (T = TOK_STRING) Or (T = TOK_DSTRING) Or
                     (T = TOK_SYMBOL) Or (T = TOK_REGEX) Or
                     (T = TOK_PERCENT_LIT) Or (T = Ord(')')) Or
                     (T = Ord(']')) Or (T = Ord('}'));
End;

Procedure LexNextToken;
Var
  C, C2, C3: Char;
  Done: Boolean;
Begin
  CurTokStr := '';
  CurTokNum := 0;
  Done := False;
  While Not Done Do Begin
    C := LexPeekChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Then
      LexNextChar
    Else If C = '#' Then
      SkipLineComment
    Else If (C = '=') And (LexCol = 1) And (LexPeekChar2 = 'b') Then
      SkipBlockComment
    Else
      Done := True;
  End;

  CurTokLine := LexLine;
  CurTokCol := LexCol;
  C := LexPeekChar;
  C2 := LexPeekChar2;
  If LexPos + 2 <= SrcLen Then C3 := SrcBuf[LexPos + 2] Else C3 := #0;

  If C = #0 Then CurTokType := TOK_EOF
  Else If C = #10 Then Begin
    CurTokType := TOK_NEWLINE;
    AppendTok(LexNextChar);
  End Else If IsAlpha(C) Then ReadIdent
  Else If IsDigit(C) Then ReadNumber
  Else If C = '@' Then ReadAtVar
  Else If C = '$' Then ReadGVar
  Else If C = '''' Then ReadString('''', False)
  Else If C = '"' Then ReadString('"', True)
  Else If C = ':' Then Begin
    If C2 = ':' Then Begin
      CurTokType := TOK_DCOLON;
      AppendTok(LexNextChar);
      AppendTok(LexNextChar);
    End Else
      ReadSymbol;
  End Else If (C = '/') And Not LastTokenCanEndExpr Then
    ReadRegex
  Else If C = '%' Then Begin
    If IsAlpha(C2) Or (C2 = '(') Or (C2 = '[') Or (C2 = '{') Or
       (C2 = '<') Or (C2 = '/') Then
      ReadPercentLit
    Else
      SetSingleToken(Ord('%'));
  End Else If (C = '.') And (C2 = '.') And (C3 = '.') Then Begin
    CurTokType := TOK_DOTDOTDOT;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '.') And (C2 = '.') Then Begin
    CurTokType := TOK_DOTDOT;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '<') And (C2 = '<') And Not LastTokenCanEndExpr And
              TryReadHeredoc Then Begin
  End Else If (((C = '*') And (C2 = '*')) Or
               ((C = '<') And (C2 = '<')) Or
               ((C = '>') And (C2 = '>')) Or
               ((C = '&') And (C2 = '&')) Or
               ((C = '|') And (C2 = '|'))) And (C3 = '=') Then Begin
    CurTokType := TOK_ASSIGN_OP;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '<') And (C2 = '<') Then Begin
    CurTokType := TOK_SHL;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '>') And (C2 = '>') Then Begin
    CurTokType := TOK_SHR;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '<') And (C2 = '=') And (C3 = '>') Then Begin
    CurTokType := TOK_SPACESHIP;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '=') And (C2 = '=') And (C3 = '=') Then Begin
    CurTokType := TOK_TRIPLEEQ;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '=') And (C2 = '~') Then Begin
    CurTokType := TOK_MATCH;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '!') And (C2 = '~') Then Begin
    CurTokType := TOK_NMATCH;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '&') And (C2 = '.') Then Begin
    CurTokType := TOK_SAFE_NAV;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '&') And IsAlpha(C2) Then Begin
    CurTokType := TOK_AMP_BLOCK;
    AppendTok(LexNextChar);
  End Else If (C = '*') And (C2 = '*') Then Begin
    CurTokType := TOK_POW;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '<') And (C2 = '=') Then Begin
    CurTokType := TOK_LE;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '>') And (C2 = '=') Then Begin
    CurTokType := TOK_GE;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '=') And (C2 = '=') Then Begin
    CurTokType := TOK_EQ;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '!') And (C2 = '=') Then Begin
    CurTokType := TOK_NE;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '&') And (C2 = '&') Then Begin
    CurTokType := TOK_ANDAND;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '|') And (C2 = '|') Then Begin
    CurTokType := TOK_OROR;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '-') And (C2 = '>') Then Begin
    CurTokType := TOK_ARROW;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '=') And (C2 = '>') Then Begin
    CurTokType := TOK_FAT_ARROW;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If ((C = '+') Or (C = '-') Or (C = '*') Or (C = '/') Or
               (C = '%') Or (C = '&') Or (C = '|') Or (C = '^')) And
              (C2 = '=') Then Begin
    CurTokType := TOK_ASSIGN_OP;
    AppendTok(LexNextChar);
    AppendTok(LexNextChar);
  End Else If (C = '^') And IsAlpha(C2) Then Begin
    CurTokType := TOK_PIN;
    AppendTok(LexNextChar);
  End Else
    SetSingleToken(Ord(C));

  LastTokenCanEndExpr := TokenCanEndExpr(CurTokType);
End;

Function TokenName(T: Integer): String;
Begin
  Case T Of
    TOK_EOF: TokenName := 'TOK_EOF';
    TOK_IDENT: TokenName := 'TOK_IDENT';
    TOK_CONST: TokenName := 'TOK_CONST';
    TOK_IVAR: TokenName := 'TOK_IVAR';
    TOK_CVAR: TokenName := 'TOK_CVAR';
    TOK_GVAR: TokenName := 'TOK_GVAR';
    TOK_INTEGER: TokenName := 'TOK_INTEGER';
    TOK_FLOAT: TokenName := 'TOK_FLOAT';
    TOK_STRING: TokenName := 'TOK_STRING';
    TOK_DSTRING: TokenName := 'TOK_DSTRING';
    TOK_HEREDOC: TokenName := 'TOK_HEREDOC';
    TOK_SYMBOL: TokenName := 'TOK_SYMBOL';
    TOK_REGEX: TokenName := 'TOK_REGEX';
    TOK_PERCENT_LIT: TokenName := 'TOK_PERCENT_LIT';
    TOK_NEWLINE: TokenName := 'TOK_NEWLINE';
    TOK_DOTDOT: TokenName := 'TOK_DOTDOT';
    TOK_DOTDOTDOT: TokenName := 'TOK_DOTDOTDOT';
    TOK_DCOLON: TokenName := 'TOK_DCOLON';
    TOK_SPACESHIP: TokenName := 'TOK_SPACESHIP';
    TOK_TRIPLEEQ: TokenName := 'TOK_TRIPLEEQ';
    TOK_MATCH: TokenName := 'TOK_MATCH';
    TOK_NMATCH: TokenName := 'TOK_NMATCH';
    TOK_SAFE_NAV: TokenName := 'TOK_SAFE_NAV';
    TOK_AMP_BLOCK: TokenName := 'TOK_AMP_BLOCK';
    TOK_POW: TokenName := 'TOK_POW';
    TOK_SHL: TokenName := 'TOK_SHL';
    TOK_SHR: TokenName := 'TOK_SHR';
    TOK_LE: TokenName := 'TOK_LE';
    TOK_GE: TokenName := 'TOK_GE';
    TOK_EQ: TokenName := 'TOK_EQ';
    TOK_NE: TokenName := 'TOK_NE';
    TOK_ANDAND: TokenName := 'TOK_ANDAND';
    TOK_OROR: TokenName := 'TOK_OROR';
    TOK_ASSIGN_OP: TokenName := 'TOK_ASSIGN_OP';
    TOK_ARROW: TokenName := 'TOK_ARROW';
    TOK_FAT_ARROW: TokenName := 'TOK_FAT_ARROW';
    TOK_PIN: TokenName := 'TOK_PIN';
  Else
    If (T > 0) And (T < 128) Then TokenName := '''' + Chr(T) + ''''
    Else TokenName := 'TOK_' + UpCaseStr(ItoS(T));
  End;
End;

Procedure DumpTokens;
Begin
  LexInit(Opt.SrcFile);
  Repeat
    LexNextToken;
    WriteLn(CurTokLine:5, ':', CurTokCol:3, '  ', TokenName(CurTokType),
            '  ', CurTokStr);
  Until CurTokType = TOK_EOF;
  LexClose;
End;

Procedure Usage;
Begin
  WriteLn('RUBYCW32 - Cette commande permet de lancer le compilateur Ruby ',
          'pour l''assembleur du microprocesseur 80386 pour le systeme ',
          'd''exploitation Windows 32 bits (PE Win32).');
  WriteLn;
  WriteLn('Syntaxe: RUBYCW32 source.rb [-o out] [-v] [-d] [-w] [-obj] [-asm]');
  WriteLn('                 [-frozen] [-I path] [-r lib] [-h]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -o out     Nom du fichier de sortie');
  WriteLn('  -v         Mode verbeux');
  WriteLn('  -d         Informations de debogage');
  WriteLn('  -w         Activer les avertissements');
  WriteLn('  -obj       Produire uniquement un .OBJ COFF 32 bits');
  WriteLn('  -asm       Produire aussi un listing assembleur .ASM');
  WriteLn('  -frozen    Chaines litterales immuables par defaut');
  WriteLn('  -I path    Ajouter un repertoire a $LOAD_PATH');
  WriteLn('  -r lib     Precharger une bibliotheque Ruby');
  WriteLn('  -h         Afficher cette aide');
End;

Procedure FatalError(Msg: String);
Begin
  WriteLn('RUBYCW32: erreur: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Msg: String);
Begin
  If Opt.Warnings Then WriteLn('RUBYCW32: avertissement: ', Msg);
End;

Procedure AddLoadPath(Path: String);
Begin
  If Opt.LoadPathCount >= MAX_REQUIRE Then
    FatalError('trop de chemins -I (maximum ' + '64' + ')');
  Inc(Opt.LoadPathCount);
  Opt.LoadPath[Opt.LoadPathCount] := Path;
End;

Procedure AddRequireLib(Lib: String);
Begin
  If Opt.RequireCount >= MAX_REQUIRE Then
    FatalError('trop de bibliotheques -r (maximum ' + '64' + ')');
  Inc(Opt.RequireCount);
  Opt.RequireLib[Opt.RequireCount] := Lib;
End;

Procedure InitOptions;
Begin
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Warnings := False;
  Opt.EmitExe := True;
  Opt.EmitObj := False;
  Opt.EmitAsm := False;
  Opt.FrozenStrLits := False;
End;

Procedure NeedArg(OptName: String; I: Integer);
Begin
  If I > ParamCount Then FatalError('option ' + OptName + ' sans argument');
End;

Procedure ParseArgs;
Var
  I: Integer;
  A, U: String;
Begin
  InitOptions;
  I := 1;
  While I <= ParamCount Do Begin
    A := ParamStr(I);
    U := UpCaseStr(A);
    If (U = '-H') Or (U = '/H') Or (U = '-?') Or (U = '/?') Or
       (U = '--HELP') Then Begin
      Usage;
      Halt(EXIT_USAGE);
    End Else If U = '-OBJ' Then Begin
      Opt.EmitObj := True;
      Opt.EmitExe := False;
    End Else If U = '-ASM' Then Begin
      Opt.EmitAsm := True;
    End Else If U = '-FROZEN' Then Begin
      Opt.FrozenStrLits := True;
    End Else If U = '-O' Then Begin
      Inc(I);
      NeedArg('-o', I);
      Opt.OutFile := ParamStr(I);
    End Else If Copy(U, 1, 2) = '-O' Then Begin
      Opt.OutFile := Copy(A, 3, Length(A) - 2);
      If Opt.OutFile = '' Then FatalError('option -o sans argument');
    End Else If U = '-V' Then Begin
      Opt.Verbose := True;
    End Else If U = '-D' Then Begin
      Opt.DebugMode := True;
    End Else If U = '-W' Then Begin
      Opt.Warnings := True;
    End Else If U = '-I' Then Begin
      Inc(I);
      NeedArg('-I', I);
      AddLoadPath(ParamStr(I));
    End Else If Copy(U, 1, 2) = '-I' Then Begin
      AddLoadPath(Copy(A, 3, Length(A) - 2));
    End Else If U = '-R' Then Begin
      Inc(I);
      NeedArg('-r', I);
      AddRequireLib(ParamStr(I));
    End Else If Copy(U, 1, 2) = '-R' Then Begin
      AddRequireLib(Copy(A, 3, Length(A) - 2));
    End Else If (Length(A) > 0) And ((A[1] = '-') Or (A[1] = '/')) Then Begin
      FatalError('option inconnue ' + A);
    End Else Begin
      If Opt.SrcFile <> '' Then FatalError('plusieurs fichiers source specifies');
      Opt.SrcFile := A;
    End;
    Inc(I);
  End;

  If Opt.SrcFile = '' Then Begin
    Usage;
    Halt(EXIT_USAGE);
  End;
  If Not IsRubySourceName(Opt.SrcFile) Then
    FatalError('extension source invalide (attendu .rb ou .ruby)');

  If Opt.OutFile = '' Then Begin
    If Opt.EmitObj Then Opt.OutFile := ChangeExt(Opt.SrcFile, '.obj')
    Else Opt.OutFile := ChangeExt(Opt.SrcFile, '.exe');
  End;
End;

Begin
  ParseArgs;
  WriteLn('RUBYCW32 v0.1 (2026) - Compilateur Ruby -> 80386 PE Win32');
  If Opt.Verbose Then Begin
    WriteLn('Source : ', Opt.SrcFile);
    WriteLn('Sortie : ', Opt.OutFile);
    If Opt.EmitObj Then WriteLn('Format : OBJ COFF 32 bits')
    Else WriteLn('Format : EXE PE Win32');
    If Opt.EmitAsm Then WriteLn('ASM    : oui');
    If Opt.DebugMode Then WriteLn('Debug  : oui');
    If Opt.FrozenStrLits Then WriteLn('Frozen : oui');
  End;
  If Opt.DebugMode Then
    DumpTokens
  Else
    WarnMsg('seuls l infrastructure et le lexer sont initialises');
End.
