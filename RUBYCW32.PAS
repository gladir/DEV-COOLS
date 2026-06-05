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

  TODO 03 - MOTS-CLES ET PSEUDO-MOTS-CLES RUBY [IMPLEMENTE]
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

  TODO 04 - SYMBOLES, SCOPES ET REPRESENTATION RUNTIME [IMPLEMENTE]
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

  TODO 05 - PARSEUR D EXPRESSIONS (PRECEDENCE RUBY) [IMPLEMENTE]
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

  TODO 06 - PARSEUR DE STATEMENTS [IMPLEMENTE]
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

  TODO 07 - VARIABLES : LOCALES, GLOBALES, IVARS, CVARS, CONSTANTES [IMPLEMENTE]
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

  TODO 08 - METHODES (DEF ... END) [IMPLEMENTE]
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

  TODO 09 - CLASSES (CLASS ... END) [IMPLEMENTE]
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

  TODO 10 - MODULES, MIXINS, NAMESPACES [IMPLEMENTE]
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

  TODO 11 - HERITAGE, SUPER, METHOD_MISSING [IMPLEMENTE]
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

  TODO 13 - ARRAYS, HASHES, SYMBOLS [IMPLEMENTE]
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

  TODO 14 - BLOCS, YIELD, PROC, LAMBDA [IMPLEMENTE]
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

  TODO 15 - STRUCTURES DE CONTROLE [IMPLEMENTE]
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

  TODO 16 - BOUCLES (WHILE, UNTIL, FOR, LOOP, ITERATEURS) [IMPLEMENTE]
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

  TODO 17 - EXCEPTIONS (BEGIN/RESCUE/ENSURE/RAISE) [IMPLEMENTE]
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

  TODO 18 - REGEX [IMPLEMENTE]
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

  TODO 19 - RANGES, ITERATEURS, ENUMERABLE, COMPARABLE [IMPLEMENTE]
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

  TODO 20 - I/O, FICHIERS, ARGV, ENV [IMPLEMENTE]
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

  TODO 21 - KERNEL ET BIBLIOTHEQUE CORE [IMPLEMENTE]
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

  TODO 22 - NUMERIQUES (INTEGER, FLOAT, RATIONAL, COMPLEX) [IMPLEMENTE]
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

  TODO 23 - REQUIRE / LOAD / LIENS DE FICHIERS [IMPLEMENTE]
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

  TODO 24 - GENERATEUR DE CODE 80386 ET SORTIE .ASM [IMPLEMENTE]
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

  TODO 25 - BACKEND BINAIRE .OBJ COFF + .EXE PE WIN32 [IMPLEMENTE]
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
  PE_OPT_MAGIC_PE32 = $010B;
  PE_SCN_CNT_CODE = $00000020;
  PE_SCN_CNT_INIT_DATA = $00000040;
  PE_SCN_CNT_UNINIT_DATA = $00000080;
  PE_SCN_MEM_EXECUTE = $20000000;
  PE_SCN_MEM_READ = $40000000;
  PE_SCN_MEM_WRITE = -2147483648;
  PE_SCN_ALIGN_4BYTES = $00300000;
  COFF_SYM_CLASS_EXTERNAL = 2;
  COFF_SYM_CLASS_STATIC = 3;
  COFF_REL_I386_DIR32 = $0006;
  COFF_REL_I386_REL32 = $0014;
  BIN_SEC_TEXT = 1;
  BIN_SEC_DATA = 2;
  BIN_SEC_RDATA = 3;
  BIN_SEC_BSS = 4;
  BIN_FIX_REL32 = 1;
  BIN_FIX_ABS32 = 2;
  BIN_FIX_IMP32 = 3;

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
  MAX_SCOPE = 80;
  MAX_AST = 8192;
  MAX_SRC_TEXT = 65535;
  MAX_MIXIN = 64;
  MAX_STRING_LIT = 1024;
  MAX_ARRAY_LIT = 1024;
  MAX_HASH_LIT = 1024;
  MAX_SYMBOL_LIT = 2048;
  MAX_REGEX_LIT = 512;
  MAX_RANGE_LIT = 512;
  MAX_NUM_LIT = 1024;
  MAX_IO_INFO = 64;
  MAX_REQUIRE_INFO = 256;
  MAX_CONTROL = 2048;
  MAX_BIN = 65536;
  MAX_BIN_LABEL = 1024;
  MAX_BIN_FIXUP = 2048;
  MAX_BIN_IMPORT = 128;

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

  KW_ALIAS = 1000;
  KW_AND = 1001;
  KW_BEGIN_UP = 1002;
  KW_BEGIN = 1003;
  KW_BREAK = 1004;
  KW_CASE = 1005;
  KW_CLASS = 1006;
  KW_DEF = 1007;
  KW_DEFINED = 1008;
  KW_DO = 1009;
  KW_ELSE = 1010;
  KW_ELSIF = 1011;
  KW_END_UP = 1012;
  KW_END = 1013;
  KW_ENSURE = 1014;
  KW_FALSE = 1015;
  KW_FOR = 1016;
  KW_IF = 1017;
  KW_IN = 1018;
  KW_MODULE = 1019;
  KW_NEXT = 1020;
  KW_NIL = 1021;
  KW_NOT = 1022;
  KW_OR = 1023;
  KW_REDO = 1024;
  KW_RESCUE = 1025;
  KW_RETRY = 1026;
  KW_RETURN = 1027;
  KW_SELF = 1028;
  KW_SUPER = 1029;
  KW_THEN = 1030;
  KW_TRUE = 1031;
  KW_UNDEF = 1032;
  KW_UNLESS = 1033;
  KW_UNTIL = 1034;
  KW_WHEN = 1035;
  KW_WHILE = 1036;
  KW_YIELD = 1037;
  KW_FILE = 1038;
  KW_LINE = 1039;
  KW_ENCODING = 1040;

  KW_ATTR_ACCESSOR = 1100;
  KW_ATTR_READER = 1101;
  KW_ATTR_WRITER = 1102;
  KW_PRIVATE = 1103;
  KW_PUBLIC = 1104;
  KW_PROTECTED = 1105;
  KW_RAISE = 1106;
  KW_REQUIRE = 1107;
  KW_REQUIRE_RELATIVE = 1108;
  KW_LOAD = 1109;
  KW_INCLUDE = 1110;
  KW_EXTEND = 1111;
  KW_PREPEND = 1112;
  KW_MODULE_FUNCTION = 1113;
  KW_PROC = 1114;
  KW_LAMBDA = 1115;
  KW_LOOP = 1116;
  KW_TIMES = 1117;
  KW_EACH = 1118;
  KW_MAP = 1119;
  KW_SELECT = 1120;
  KW_REJECT = 1121;
  KW_INJECT = 1122;
  KW_REDUCE = 1123;
  KW_PUTS = 1124;
  KW_PRINT = 1125;
  KW_P = 1126;
  KW_PP = 1127;
  KW_GETS = 1128;
  KW_GETC = 1129;
  KW_PRINTF = 1130;
  KW_SPRINTF = 1131;
  KW_FORMAT = 1132;
  KW_READLINE = 1133;
  KW_READLINES = 1134;

  CTX_NONE = 0;
  CTX_PREFIX = 1;
  CTX_MODIFIER = 2;
  CTX_DO_AFTER_EXPR = 3;
  CTX_DO_BEGIN = 4;
  CTX_BLOCK_BRACE = 5;
  CTX_HASH_BRACE = 6;

  SK_NONE = 0;
  SK_LOCAL = 1;
  SK_IVAR = 2;
  SK_CVAR = 3;
  SK_GVAR = 4;
  SK_CONST = 5;
  SK_METHOD = 6;
  SK_CLASS = 7;
  SK_MODULE = 8;
  SK_BLOCK_PARAM = 9;
  SK_PARAM = 10;

  SC_TOPLEVEL = 0;
  SC_BLOCK = 1;
  SC_METHOD = 2;
  SC_CLASS = 3;
  SC_MODULE = 4;

  RT_UNKNOWN = 0;
  RT_NIL = 1;
  RT_FALSE = 2;
  RT_TRUE = 3;
  RT_INTEGER = 4;
  RT_FLOAT = 5;
  RT_STRING = 6;
  RT_SYMBOL = 7;
  RT_ARRAY = 8;
  RT_HASH = 9;
  RT_RANGE = 10;
  RT_REGEXP = 11;
  RT_PROC = 12;
  RT_LAMBDA = 13;
  RT_OBJECT = 14;
  RT_CLASS = 15;
  RT_MODULE = 16;

  RV_FALSE = $00000000;
  RV_NIL = $00000008;
  RV_TRUE = $00000014;
  RV_FIXNUM_TAG = $00000001;
  RV_SYMBOL_TAG = $0000000C;
  RV_SYMBOL_SHIFT = 8;
  RV_PTR_ALIGN = 8;

  OBJ_HDR_CLASS = 0;
  OBJ_HDR_FLAGS = 4;
  OBJ_HDR_IVARS = 8;
  OBJ_HDR_SIZE = 12;

  NK_NONE = 0;
  NK_LITERAL = 1;
  NK_VAR = 2;
  NK_CONST = 3;
  NK_UNARY = 4;
  NK_BINARY = 5;
  NK_ASSIGN = 6;
  NK_TERNARY = 7;
  NK_RANGE = 8;
  NK_CALL = 9;
  NK_INDEX = 10;
  NK_ARRAY = 11;
  NK_HASH = 12;
  NK_PAIR = 13;
  NK_LIST = 14;
  NK_SPLAT = 15;
  NK_KW_SPLAT = 16;
  NK_STMT_LIST = 17;
  NK_IF = 18;
  NK_UNLESS = 19;
  NK_WHILE = 20;
  NK_UNTIL = 21;
  NK_FOR = 22;
  NK_CASE = 23;
  NK_WHEN = 24;
  NK_BEGIN = 25;
  NK_RESCUE = 26;
  NK_ENSURE = 27;
  NK_DEF = 28;
  NK_CLASS = 29;
  NK_MODULE = 30;
  NK_RETURN = 31;
  NK_BREAK = 32;
  NK_NEXT = 33;
  NK_REDO = 34;
  NK_RETRY = 35;
  NK_YIELD = 36;
  NK_RAISE = 37;
  NK_ALIAS = 38;
  NK_UNDEF = 39;
  NK_BEGIN_HOOK = 40;
  NK_END_HOOK = 41;
  NK_REQUIRE = 42;
  NK_EMPTY = 43;
  NK_VISIBILITY = 44;
  NK_PARAM = 45;
  NK_PARAM_DEFAULT = 46;
  NK_PARAM_SPLAT = 47;
  NK_PARAM_KEY = 48;
  NK_PARAM_KW_SPLAT = 49;
  NK_PARAM_BLOCK = 50;
  NK_MIXIN = 51;
  NK_MODULE_FUNCTION = 52;
  NK_SUPER = 53;
  NK_STRING = 54;
  NK_SYMBOL = 55;
  NK_BLOCK = 56;
  NK_PROC = 57;
  NK_LAMBDA = 58;
  NK_REGEX = 59;

  SF_CONST_ASSIGNED = $0001;
  SF_PSEUDO_CONST = $0002;
  SF_GLOBAL_STORAGE = $0004;
  SF_IVAR_STORAGE = $0008;
  SF_CVAR_STORAGE = $0010;
  SF_METHOD_PUBLIC = $0020;
  SF_METHOD_PRIVATE = $0040;
  SF_METHOD_PROTECTED = $0080;
  SF_METHOD_SINGLETON = $0100;
  SF_METHOD_CLASS = $0200;
  SF_PERSISTENT = $0400;
  SF_DEAD = $0800;
  SF_CLASS_SINGLETON = $1000;
  SF_CLASS_EIGEN = $2000;
  SF_MODULE_FUNCTION = $4000;

  STRF_FROZEN = $0001;
  STRF_MUTABLE = $0002;
  STRF_INTERP = $0004;
  STRF_HEREDOC = $0008;
  STRF_PERCENT = $0010;
  STRF_UTF8 = $0020;

  ARRF_HAS_SPLAT = $0001;
  HASHF_HAS_KW_SPLAT = $0001;

  REGF_IGNORECASE = $0001;
  REGF_MULTILINE = $0002;
  REGF_EXTENDED = $0004;
  REGF_ONCE = $0008;
  REGF_UTF8 = $0010;
  REGF_PERCENT = $0020;

  RANGEF_EXCLUSIVE = $0001;
  RANGEF_BEGINLESS = $0002;
  RANGEF_ENDLESS = $0004;

  NUMF_FIXNUM = $0001;
  NUMF_BIGNUM = $0002;
  NUMF_FLOAT = $0004;
  NUMF_RATIONAL = $0008;
  NUMF_COMPLEX = $0010;
  NUMF_BASE2 = $0020;
  NUMF_BASE8 = $0040;
  NUMF_BASE10 = $0080;
  NUMF_BASE16 = $0100;

  IOF_STDIN = $0001;
  IOF_STDOUT = $0002;
  IOF_STDERR = $0004;
  IOF_ARGV = $0008;
  IOF_ENV = $0010;
  IOF_FILE_CLASS = $0020;
  IOF_DIR_CLASS = $0040;
  IOF_READABLE = $0080;
  IOF_WRITABLE = $0100;
  IOF_MODE = $0200;

  REQF_REQUIRE = $0001;
  REQF_REQUIRE_RELATIVE = $0002;
  REQF_LOAD = $0004;
  REQF_AUTOLOAD = $0008;
  REQF_PRELOAD = $0010;
  REQF_STD_LIB = $0020;
  REQF_DEDUP = $0040;
  REQF_FOUND = $0080;
  REQF_MISSING = $0100;
  REQF_EXEC_EACH_TIME = $0200;

  BLOCKF_PROC = $0001;
  BLOCKF_LAMBDA = $0002;
  BLOCKF_DO_END = $0004;
  BLOCKF_HAS_PARAMS = $0008;

  CTRLF_UNLESS = $0001;
  CTRLF_MODIFIER = $0002;
  CTRLF_TERNARY = $0004;
  CTRLF_SHORT_CIRCUIT = $0008;
  CTRLF_CASE = $0010;
  CTRLF_PATTERN = $0020;
  CTRLF_LOOP = $0040;
  CTRLF_WHILE = $0080;
  CTRLF_UNTIL = $0100;
  CTRLF_FOR = $0200;
  CTRLF_LOOP_BLOCK = $0400;
  CTRLF_ITERATOR = $0800;
  CTRLF_POST_TEST = $1000;

  RESCF_HAS_RESCUE = $0001;
  RESCF_HAS_ELSE = $0002;
  RESCF_HAS_ENSURE = $0004;
  RESCF_MODIFIER = $0008;
  RESCF_DEFAULT = $0010;

  VIS_PUBLIC = 1;
  VIS_PRIVATE = 2;
  VIS_PROTECTED = 3;

Type
  TStringList64 = Array[1..MAX_REQUIRE] Of String;
  TSrcBuffer = Array[1..MAX_SRC_TEXT] Of Char;

  TSym = Record
    Name: String;
    Kind: Integer;
    RType: Integer;
    Scope: Integer;
    DeclScopeKind: Integer;
    Offset: Integer;
    ClassRef: Integer;
    Flags: Integer;
    AsmName: String;
    ParamCount: Integer;
    LocalSize: Integer;
    RuntimeRef: Integer;
    MethodName: String;
    OwnerMROIndex: Integer;
    SuperMethodRef: Integer;
    MissingFallbackRef: Integer;
  End;

  TSymTable = Array[1..MAX_SYM] Of TSym;
  TScopeStack = Array[0..MAX_SCOPE] Of Integer;
  TClassMRO = Array[1..MAX_CLASS] Of Integer;

  TStringLit = Record
    Text: String;
    AsmName: String;
    Len: Integer;
    Cap: Integer;
    Flags: Integer;
    SegmentCount: Integer;
  End;

  TStringLitTable = Array[1..MAX_STRING_LIT] Of TStringLit;

  TSymbolLit = Record
    Name: String;
    AsmName: String;
    Value: LongInt;
  End;

  TRegexLit = Record
    Pattern: String;
    Options: String;
    AsmName: String;
    Flags: Integer;
    CaptureCount: Integer;
  End;

  TRangeLit = Record
    AsmName: String;
    BeginNode: Integer;
    EndNode: Integer;
    Flags: Integer;
  End;

  TNumLit = Record
    Text: String;
    AsmName: String;
    RType: Integer;
    Flags: Integer;
    Base: Integer;
  End;

  TArrayLit = Record
    AsmName: String;
    Count: Integer;
    Cap: Integer;
    FirstNode: Integer;
    Flags: Integer;
  End;

  THashLit = Record
    AsmName: String;
    Count: Integer;
    Cap: Integer;
    FirstPair: Integer;
    Flags: Integer;
  End;

  TSymbolLitTable = Array[1..MAX_SYMBOL_LIT] Of TSymbolLit;
  TRegexLitTable = Array[1..MAX_REGEX_LIT] Of TRegexLit;
  TRangeLitTable = Array[1..MAX_RANGE_LIT] Of TRangeLit;
  TNumLitTable = Array[1..MAX_NUM_LIT] Of TNumLit;
  TArrayLitTable = Array[1..MAX_ARRAY_LIT] Of TArrayLit;
  THashLitTable = Array[1..MAX_HASH_LIT] Of THashLit;

  TBlockInfo = Record
    Kind: Integer;
    ParamsNode: Integer;
    BodyNode: Integer;
    ParamCount: Integer;
    CaptureCount: Integer;
    LabelName: String;
    Flags: Integer;
  End;

  TBlockTable = Array[1..MAX_BLOCK] Of TBlockInfo;

  TControlInfo = Record
    NodeRef: Integer;
    Kind: Integer;
    CondNode: Integer;
    ThenNode: Integer;
    ElseNode: Integer;
    ThenLabel: String;
    ElseLabel: String;
    EndLabel: String;
    WhenCount: Integer;
    Flags: Integer;
  End;

  TControlTable = Array[1..MAX_CONTROL] Of TControlInfo;

  TRescueInfo = Record
    NodeRef: Integer;
    BodyNode: Integer;
    RescueListNode: Integer;
    ElseNode: Integer;
    EnsureNode: Integer;
    CurrentExceptionSym: Integer;
    HandlerCount: Integer;
    BeginLabel: String;
    RescueLabel: String;
    ElseLabel: String;
    EnsureLabel: String;
    EndLabel: String;
    Flags: Integer;
  End;

  TRescueInfoTable = Array[1..MAX_RESCUE] Of TRescueInfo;

  TIOInfo = Record
    Name: String;
    Kind: Integer;
    SymRef: Integer;
    RuntimeName: String;
    Flags: Integer;
  End;

  TIOInfoTable = Array[1..MAX_IO_INFO] Of TIOInfo;

  TRequireInfo = Record
    Kind: Integer;
    LibName: String;
    ResolvedPath: String;
    CanonicalPath: String;
    BaseDir: String;
    NodeRef: Integer;
    StringNode: Integer;
    ConstNode: Integer;
    Flags: Integer;
  End;

  TRequireInfoTable = Array[1..MAX_REQUIRE_INFO] Of TRequireInfo;

  TBinBuffer = Array[0..MAX_BIN - 1] Of Byte;

  TBinLabel = Record
    Name: String;
    Section: Integer;
    Offset: LongInt;
    Defined: Boolean;
  End;

  TBinFixup = Record
    Section: Integer;
    Offset: LongInt;
    LabelRef: Integer;
    Kind: Integer;
  End;

  TBinImport = Record
    DllName: String;
    ProcName: String;
    Hint: Integer;
    IATRva: LongInt;
  End;

  TBinLabelTable = Array[1..MAX_BIN_LABEL] Of TBinLabel;
  TBinFixupTable = Array[1..MAX_BIN_FIXUP] Of TBinFixup;
  TBinImportTable = Array[1..MAX_BIN_IMPORT] Of TBinImport;

  TClassInfo = Record
    Name: String;
    SymRef: Integer;
    SuperRef: Integer;
    VTableRef: Integer;
    IvarCount: Integer;
    MethodCount: Integer;
    IncludedCount: Integer;
    IncludeList: TClassMRO;
    ExtendedCount: Integer;
    ExtendList: TClassMRO;
    PrependedCount: Integer;
    PrependList: TClassMRO;
    ConstCount: Integer;
    IsSingleton: Boolean;
    EigenOf: Integer;
    MROCount: Integer;
    MRO: TClassMRO;
    VTableCount: Integer;
    VTableMethods: TClassMRO;
  End;

  TClassTable = Array[1..MAX_CLASS] Of TClassInfo;

  TASTNode = Record
    Kind: Integer;
    Tok: Integer;
    Text: String;
    Left: Integer;
    Right: Integer;
    Third: Integer;
    FirstChild: Integer;
    NextSibling: Integer;
    SymRef: Integer;
  End;

  TASTTable = Array[1..MAX_AST] Of TASTNode;

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
  CurTokContext: Integer;
  LastTokenType: Integer;
  LastTokenCanEndExpr: Boolean;
  SymTable: TSymTable;
  SymCount: Integer;
  ScopeLevel: Integer;
  ScopeKind: TScopeStack;
  ScopeBase: TScopeStack;
  ScopeNextLocal: TScopeStack;
  ScopeOwnerClass: TScopeStack;
  CurrentClassRef: Integer;
  CurrentMethodSym: Integer;
  CurrentMethodName: String;
  CurrentVisibility: Integer;
  ClassTable: TClassTable;
  ClassCount: Integer;
  StringTable: TStringLitTable;
  StringCount: Integer;
  SymbolLitTable: TSymbolLitTable;
  SymbolLitCount: Integer;
  RegexLitTable: TRegexLitTable;
  RegexLitCount: Integer;
  RangeLitTable: TRangeLitTable;
  RangeLitCount: Integer;
  NumLitTable: TNumLitTable;
  NumLitCount: Integer;
  ArrayLitTable: TArrayLitTable;
  ArrayLitCount: Integer;
  HashLitTable: THashLitTable;
  HashLitCount: Integer;
  BlockTable: TBlockTable;
  BlockCount: Integer;
  ControlTable: TControlTable;
  ControlCount: Integer;
  LoopStack: Array[1..MAX_CONTROL] Of Integer;
  LoopDepth: Integer;
  RescueInfoTable: TRescueInfoTable;
  RescueInfoCount: Integer;
  RescueStack: Array[1..MAX_RESCUE] Of Integer;
  RescueDepth: Integer;
  IOInfoTable: TIOInfoTable;
  IOInfoCount: Integer;
  RequireInfoTable: TRequireInfoTable;
  RequireInfoCount: Integer;
  BinCode: TBinBuffer;
  BinData: TBinBuffer;
  BinRData: TBinBuffer;
  BinCodeSize: LongInt;
  BinDataSize: LongInt;
  BinRDataSize: LongInt;
  BinBssSize: LongInt;
  BinLabels: TBinLabelTable;
  BinLabelCount: Integer;
  BinFixups: TBinFixupTable;
  BinFixupCount: Integer;
  BinImports: TBinImportTable;
  BinImportCount: Integer;
  AstTable: TASTTable;
  AstCount: Integer;
  ParseErrors: Integer;
  ParseAllowCommaList: Boolean;
  ParseAllowDoBlock: Boolean;

Procedure FatalError(Msg: String); Forward;
Procedure WarnMsg(Msg: String); Forward;

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

Function DirName(Path: String): String;
Var
  I: Integer;
Begin
  DirName := '.';
  For I := Length(Path) DownTo 1 Do Begin
    If IsPathSep(Path[I]) Then Begin
      If I = 1 Then DirName := Copy(Path, 1, 1)
      Else DirName := Copy(Path, 1, I - 1);
      Exit;
    End;
  End;
End;

Function IsAbsPath(Path: String): Boolean;
Begin
  IsAbsPath := ((Length(Path) >= 2) And (Path[2] = ':')) Or
               ((Length(Path) >= 1) And IsPathSep(Path[1]));
End;

Function PathJoin(A, B: String): String;
Begin
  If A = '' Then PathJoin := B
  Else If B = '' Then PathJoin := A
  Else If IsAbsPath(B) Then PathJoin := B
  Else If IsPathSep(A[Length(A)]) Then PathJoin := A + B
  Else PathJoin := A + '\' + B;
End;

Function NormalizePath(Path: String): String;
Var
  I: Integer;
Begin
  For I := 1 To Length(Path) Do
    If Path[I] = '/' Then Path[I] := '\';
  NormalizePath := Path;
End;

Function CanonicalPath(Path: String): String;
Begin
  CanonicalPath := UpCaseStr(NormalizePath(Path));
End;

Function HasRubyExt(Path: String): Boolean;
Var
  E: String;
Begin
  E := UpCaseStr(FileExt(Path));
  HasRubyExt := (E = '.RB') Or (E = '.RUBY');
End;

Function AddRubyExt(Path: String): String;
Begin
  If FileExt(Path) = '' Then AddRubyExt := Path + '.rb'
  Else AddRubyExt := Path;
End;

Function FileExistsLocal(Path: String): Boolean;
Var
  F: File;
  Code: Integer;
Begin
  Assign(F, Path);
  {$I-}
  Reset(F);
  {$I+}
  Code := IOResult;
  FileExistsLocal := Code = 0;
  If Code = 0 Then Close(F);
End;

Function IsStdLibName(Name: String): Boolean;
Begin
  IsStdLibName := (Name = 'set') Or (Name = 'date') Or (Name = 'time') Or
                  (Name = 'json') Or (Name = 'fileutils') Or
                  (Name = 'stringio') Or (Name = 'ostruct');
End;

Function RequireFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And REQF_REQUIRE) <> 0 Then S := S + ' require';
  If (F And REQF_REQUIRE_RELATIVE) <> 0 Then S := S + ' relative';
  If (F And REQF_LOAD) <> 0 Then S := S + ' load';
  If (F And REQF_AUTOLOAD) <> 0 Then S := S + ' autoload';
  If (F And REQF_PRELOAD) <> 0 Then S := S + ' preload';
  If (F And REQF_STD_LIB) <> 0 Then S := S + ' stdlib';
  If (F And REQF_DEDUP) <> 0 Then S := S + ' dedup';
  If (F And REQF_FOUND) <> 0 Then S := S + ' found';
  If (F And REQF_MISSING) <> 0 Then S := S + ' missing';
  If (F And REQF_EXEC_EACH_TIME) <> 0 Then S := S + ' exec-each-time';
  RequireFlagsName := S;
End;

Function RequireKindName(K: Integer; F: Integer): String;
Begin
  If (F And REQF_AUTOLOAD) <> 0 Then RequireKindName := 'autoload'
  Else If K = KW_REQUIRE_RELATIVE Then RequireKindName := 'require_relative'
  Else If K = KW_LOAD Then RequireKindName := 'load'
  Else RequireKindName := 'require';
End;

Function NodeStringValue(N: Integer): String;
Begin
  NodeStringValue := '';
  If N = 0 Then Exit;
  If (AstTable[N].Kind = NK_STRING) Or
     ((AstTable[N].Kind = NK_LITERAL) And
      ((AstTable[N].Tok = TOK_STRING) Or (AstTable[N].Tok = TOK_DSTRING) Or
       (AstTable[N].Tok = TOK_HEREDOC))) Then
    NodeStringValue := AstTable[N].Text;
End;

Function FindRequireByCanonical(Canon: String): Integer;
Var
  I: Integer;
Begin
  FindRequireByCanonical := 0;
  If Canon = '' Then Exit;
  For I := 1 To RequireInfoCount Do
    If RequireInfoTable[I].CanonicalPath = Canon Then Begin
      FindRequireByCanonical := I;
      Exit;
    End;
End;

Function ResolveRequirePath(LibName: String; TokKind, ExtraFlags: Integer;
                            Var BaseDir, Resolved, Canon: String;
                            Var Flags: Integer): Boolean;
Var
  I: Integer;
  Candidate, WithExt: String;
Begin
  BaseDir := DirName(Opt.SrcFile);
  Resolved := '';
  Canon := '';
  Flags := ExtraFlags;
  If TokKind = KW_REQUIRE_RELATIVE Then Flags := Flags Or REQF_REQUIRE_RELATIVE
  Else If TokKind = KW_LOAD Then Flags := Flags Or REQF_LOAD Or REQF_EXEC_EACH_TIME
  Else If (ExtraFlags And REQF_AUTOLOAD) = 0 Then Flags := Flags Or REQF_REQUIRE;

  If ((Flags And (REQF_REQUIRE Or REQF_AUTOLOAD Or REQF_PRELOAD)) <> 0) And
     IsStdLibName(LibName) Then Begin
    Resolved := 'stdlib:' + LibName;
    Canon := UpCaseStr(Resolved);
    Flags := Flags Or REQF_STD_LIB Or REQF_FOUND;
    ResolveRequirePath := True;
    Exit;
  End;

  If (Flags And REQF_REQUIRE_RELATIVE) <> 0 Then Begin
    Candidate := PathJoin(BaseDir, LibName);
    WithExt := AddRubyExt(Candidate);
    If FileExistsLocal(WithExt) Then Candidate := WithExt;
  End Else If (Flags And REQF_LOAD) <> 0 Then Begin
    If IsAbsPath(LibName) Then Candidate := LibName
    Else Candidate := PathJoin(BaseDir, LibName);
    If (Not FileExistsLocal(Candidate)) And (FileExt(Candidate) = '') Then
      If FileExistsLocal(Candidate + '.rb') Then Candidate := Candidate + '.rb';
  End Else Begin
    Candidate := '';
    For I := 1 To Opt.LoadPathCount Do Begin
      WithExt := AddRubyExt(PathJoin(Opt.LoadPath[I], LibName));
      If FileExistsLocal(WithExt) Then Begin
        Candidate := WithExt;
        Break;
      End;
    End;
    If Candidate = '' Then Begin
      WithExt := AddRubyExt(PathJoin(BaseDir, LibName));
      If FileExistsLocal(WithExt) Then Candidate := WithExt;
    End;
    If Candidate = '' Then Begin
      WithExt := AddRubyExt(LibName);
      If FileExistsLocal(WithExt) Then Candidate := WithExt;
    End;
    If Candidate = '' Then Candidate := AddRubyExt(PathJoin(BaseDir, LibName));
  End;

  Resolved := NormalizePath(Candidate);
  Canon := CanonicalPath(Resolved);
  If FileExistsLocal(Resolved) Then Flags := Flags Or REQF_FOUND
  Else Flags := Flags Or REQF_MISSING;
  ResolveRequirePath := (Flags And REQF_FOUND) <> 0;
End;

Function AddRequireInfo(TokKind, NodeRef, StringNode, ConstNode: Integer;
                        LibName: String; ExtraFlags: Integer): Integer;
Var
  BaseDir, Resolved, Canon: String;
  Flags: Integer;
Begin
  If RequireInfoCount >= MAX_REQUIRE_INFO Then
    FatalError('table require/load pleine');
  Inc(RequireInfoCount);
  ResolveRequirePath(LibName, TokKind, ExtraFlags, BaseDir, Resolved, Canon, Flags);
  If ((Flags And REQF_LOAD) = 0) And (FindRequireByCanonical(Canon) <> 0) Then
    Flags := Flags Or REQF_DEDUP;
  RequireInfoTable[RequireInfoCount].Kind := TokKind;
  RequireInfoTable[RequireInfoCount].LibName := LibName;
  RequireInfoTable[RequireInfoCount].ResolvedPath := Resolved;
  RequireInfoTable[RequireInfoCount].CanonicalPath := Canon;
  RequireInfoTable[RequireInfoCount].BaseDir := BaseDir;
  RequireInfoTable[RequireInfoCount].NodeRef := NodeRef;
  RequireInfoTable[RequireInfoCount].StringNode := StringNode;
  RequireInfoTable[RequireInfoCount].ConstNode := ConstNode;
  RequireInfoTable[RequireInfoCount].Flags := Flags;
  AddRequireInfo := RequireInfoCount;
End;

Function RegisterAutoloadCall(N: Integer): Integer;
Var
  Target, Args, ConstNode, StringNode: Integer;
  LibName: String;
Begin
  RegisterAutoloadCall := 0;
  If (N = 0) Or (AstTable[N].Kind <> NK_CALL) Or
     (AstTable[N].Text <> 'bare-call') Then Exit;
  Target := AstTable[N].Left;
  Args := AstTable[N].Right;
  If (Target = 0) Or (AstTable[Target].Text <> 'autoload') Or
     (Args = 0) Or (AstTable[Args].Kind <> NK_LIST) Then Exit;
  ConstNode := AstTable[Args].FirstChild;
  If ConstNode = 0 Then Exit;
  StringNode := AstTable[ConstNode].NextSibling;
  LibName := NodeStringValue(StringNode);
  If LibName <> '' Then
    RegisterAutoloadCall := AddRequireInfo(0, N, StringNode, ConstNode, LibName,
                                           REQF_AUTOLOAD);
End;

Function IsKeyword(S: String): Integer;
Begin
  IsKeyword := 0;
  If S = 'alias' Then IsKeyword := KW_ALIAS
  Else If S = 'and' Then IsKeyword := KW_AND
  Else If S = 'BEGIN' Then IsKeyword := KW_BEGIN_UP
  Else If S = 'begin' Then IsKeyword := KW_BEGIN
  Else If S = 'break' Then IsKeyword := KW_BREAK
  Else If S = 'case' Then IsKeyword := KW_CASE
  Else If S = 'class' Then IsKeyword := KW_CLASS
  Else If S = 'def' Then IsKeyword := KW_DEF
  Else If S = 'defined?' Then IsKeyword := KW_DEFINED
  Else If S = 'do' Then IsKeyword := KW_DO
  Else If S = 'else' Then IsKeyword := KW_ELSE
  Else If S = 'elsif' Then IsKeyword := KW_ELSIF
  Else If S = 'END' Then IsKeyword := KW_END_UP
  Else If S = 'end' Then IsKeyword := KW_END
  Else If S = 'ensure' Then IsKeyword := KW_ENSURE
  Else If S = 'false' Then IsKeyword := KW_FALSE
  Else If S = 'for' Then IsKeyword := KW_FOR
  Else If S = 'if' Then IsKeyword := KW_IF
  Else If S = 'in' Then IsKeyword := KW_IN
  Else If S = 'module' Then IsKeyword := KW_MODULE
  Else If S = 'next' Then IsKeyword := KW_NEXT
  Else If S = 'nil' Then IsKeyword := KW_NIL
  Else If S = 'not' Then IsKeyword := KW_NOT
  Else If S = 'or' Then IsKeyword := KW_OR
  Else If S = 'redo' Then IsKeyword := KW_REDO
  Else If S = 'rescue' Then IsKeyword := KW_RESCUE
  Else If S = 'retry' Then IsKeyword := KW_RETRY
  Else If S = 'return' Then IsKeyword := KW_RETURN
  Else If S = 'self' Then IsKeyword := KW_SELF
  Else If S = 'super' Then IsKeyword := KW_SUPER
  Else If S = 'then' Then IsKeyword := KW_THEN
  Else If S = 'true' Then IsKeyword := KW_TRUE
  Else If S = 'undef' Then IsKeyword := KW_UNDEF
  Else If S = 'unless' Then IsKeyword := KW_UNLESS
  Else If S = 'until' Then IsKeyword := KW_UNTIL
  Else If S = 'when' Then IsKeyword := KW_WHEN
  Else If S = 'while' Then IsKeyword := KW_WHILE
  Else If S = 'yield' Then IsKeyword := KW_YIELD
  Else If S = '__FILE__' Then IsKeyword := KW_FILE
  Else If S = '__LINE__' Then IsKeyword := KW_LINE
  Else If S = '__ENCODING__' Then IsKeyword := KW_ENCODING
  Else If S = 'attr_accessor' Then IsKeyword := KW_ATTR_ACCESSOR
  Else If S = 'attr_reader' Then IsKeyword := KW_ATTR_READER
  Else If S = 'attr_writer' Then IsKeyword := KW_ATTR_WRITER
  Else If S = 'private' Then IsKeyword := KW_PRIVATE
  Else If S = 'public' Then IsKeyword := KW_PUBLIC
  Else If S = 'protected' Then IsKeyword := KW_PROTECTED
  Else If S = 'raise' Then IsKeyword := KW_RAISE
  Else If S = 'require' Then IsKeyword := KW_REQUIRE
  Else If S = 'require_relative' Then IsKeyword := KW_REQUIRE_RELATIVE
  Else If S = 'load' Then IsKeyword := KW_LOAD
  Else If S = 'include' Then IsKeyword := KW_INCLUDE
  Else If S = 'extend' Then IsKeyword := KW_EXTEND
  Else If S = 'prepend' Then IsKeyword := KW_PREPEND
  Else If S = 'module_function' Then IsKeyword := KW_MODULE_FUNCTION
  Else If S = 'proc' Then IsKeyword := KW_PROC
  Else If S = 'lambda' Then IsKeyword := KW_LAMBDA
  Else If S = 'loop' Then IsKeyword := KW_LOOP
  Else If S = 'times' Then IsKeyword := KW_TIMES
  Else If S = 'each' Then IsKeyword := KW_EACH
  Else If S = 'map' Then IsKeyword := KW_MAP
  Else If S = 'select' Then IsKeyword := KW_SELECT
  Else If S = 'reject' Then IsKeyword := KW_REJECT
  Else If S = 'inject' Then IsKeyword := KW_INJECT
  Else If S = 'reduce' Then IsKeyword := KW_REDUCE
  Else If S = 'puts' Then IsKeyword := KW_PUTS
  Else If S = 'print' Then IsKeyword := KW_PRINT
  Else If S = 'p' Then IsKeyword := KW_P
  Else If S = 'pp' Then IsKeyword := KW_PP
  Else If S = 'gets' Then IsKeyword := KW_GETS
  Else If S = 'getc' Then IsKeyword := KW_GETC
  Else If S = 'printf' Then IsKeyword := KW_PRINTF
  Else If S = 'sprintf' Then IsKeyword := KW_SPRINTF
  Else If S = 'format' Then IsKeyword := KW_FORMAT
  Else If S = 'readline' Then IsKeyword := KW_READLINE
  Else If S = 'readlines' Then IsKeyword := KW_READLINES;
End;

Function IsPseudoKeyword(T: Integer): Boolean;
Begin
  IsPseudoKeyword := (T >= KW_ATTR_ACCESSOR) And (T <= KW_READLINES);
End;

Function IsCoreMethodKeyword(T: Integer): Boolean;
Begin
  IsCoreMethodKeyword := (T = KW_CLASS) Or (T = KW_THEN) Or
                         (T = KW_RAISE) Or (T = KW_REQUIRE) Or
                         (T = KW_REQUIRE_RELATIVE) Or (T = KW_LOAD) Or
                         (T = KW_PROC) Or (T = KW_LAMBDA) Or
                         (T = KW_LOOP) Or (T = KW_NEXT);
End;

Function IsKernelBuiltinName(S: String): Boolean;
Begin
  IsKernelBuiltinName := (S = 'fail') Or (S = 'throw') Or (S = 'catch') Or
                         (S = 'autoload') Or (S = 'rand') Or
                         (S = 'srand') Or (S = 'sleep') Or
                         (S = 'exit') Or (S = 'exit!') Or
                         (S = 'abort') Or (S = 'at_exit') Or
                         (S = 'eval') Or (S = 'binding') Or
                         (S = 'caller') Or (S = 'method') Or
                         (S = 'methods') Or
                         (S = 'instance_variables') Or
                         (S = 'send') Or (S = '__send__') Or
                         (S = 'public_send') Or (S = 'respond_to?');
End;

Function IsKeywordLiteral(T: Integer): Boolean;
Begin
  IsKeywordLiteral := (T = KW_FALSE) Or (T = KW_NIL) Or (T = KW_SELF) Or
                      (T = KW_TRUE) Or (T = KW_FILE) Or (T = KW_LINE) Or
                      (T = KW_ENCODING);
End;

Function IsBlockStarterKeyword(T: Integer): Boolean;
Begin
  IsBlockStarterKeyword := (T = KW_BEGIN_UP) Or (T = KW_BEGIN) Or
                           (T = KW_CASE) Or (T = KW_CLASS) Or
                           (T = KW_DEF) Or (T = KW_DO) Or
                           (T = KW_FOR) Or (T = KW_IF) Or
                           (T = KW_MODULE) Or (T = KW_UNLESS) Or
                           (T = KW_UNTIL) Or (T = KW_WHILE);
End;

Function IsModifierKeyword(T: Integer): Boolean;
Begin
  IsModifierKeyword := (T = KW_IF) Or (T = KW_UNLESS) Or
                       (T = KW_WHILE) Or (T = KW_UNTIL) Or
                       (T = KW_RESCUE);
End;

Function ContextName(C: Integer): String;
Begin
  Case C Of
    CTX_PREFIX: ContextName := 'prefix';
    CTX_MODIFIER: ContextName := 'modifier';
    CTX_DO_AFTER_EXPR: ContextName := 'do-after-expr';
    CTX_DO_BEGIN: ContextName := 'do-begin';
    CTX_BLOCK_BRACE: ContextName := 'block-brace';
    CTX_HASH_BRACE: ContextName := 'hash-brace';
  Else
    ContextName := '';
  End;
End;

Function SymKindName(K: Integer): String;
Begin
  Case K Of
    SK_LOCAL: SymKindName := 'local';
    SK_IVAR: SymKindName := 'ivar';
    SK_CVAR: SymKindName := 'cvar';
    SK_GVAR: SymKindName := 'gvar';
    SK_CONST: SymKindName := 'const';
    SK_METHOD: SymKindName := 'method';
    SK_CLASS: SymKindName := 'class';
    SK_MODULE: SymKindName := 'module';
    SK_BLOCK_PARAM: SymKindName := 'block-param';
    SK_PARAM: SymKindName := 'param';
  Else
    SymKindName := 'none';
  End;
End;

Function RuntimeTypeName(T: Integer): String;
Begin
  Case T Of
    RT_NIL: RuntimeTypeName := 'nil';
    RT_FALSE: RuntimeTypeName := 'false';
    RT_TRUE: RuntimeTypeName := 'true';
    RT_INTEGER: RuntimeTypeName := 'integer';
    RT_FLOAT: RuntimeTypeName := 'float';
    RT_STRING: RuntimeTypeName := 'string';
    RT_SYMBOL: RuntimeTypeName := 'symbol';
    RT_ARRAY: RuntimeTypeName := 'array';
    RT_HASH: RuntimeTypeName := 'hash';
    RT_RANGE: RuntimeTypeName := 'range';
    RT_REGEXP: RuntimeTypeName := 'regexp';
    RT_PROC: RuntimeTypeName := 'proc';
    RT_LAMBDA: RuntimeTypeName := 'lambda';
    RT_OBJECT: RuntimeTypeName := 'object';
    RT_CLASS: RuntimeTypeName := 'class';
    RT_MODULE: RuntimeTypeName := 'module';
  Else
    RuntimeTypeName := 'unknown';
  End;
End;

Function SymFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And SF_CONST_ASSIGNED) <> 0 Then S := S + ' assigned';
  If (F And SF_PSEUDO_CONST) <> 0 Then S := S + ' pseudo';
  If (F And SF_GLOBAL_STORAGE) <> 0 Then S := S + ' global';
  If (F And SF_IVAR_STORAGE) <> 0 Then S := S + ' ivar';
  If (F And SF_CVAR_STORAGE) <> 0 Then S := S + ' cvar';
  If (F And SF_METHOD_PUBLIC) <> 0 Then S := S + ' public';
  If (F And SF_METHOD_PRIVATE) <> 0 Then S := S + ' private';
  If (F And SF_METHOD_PROTECTED) <> 0 Then S := S + ' protected';
  If (F And SF_METHOD_SINGLETON) <> 0 Then S := S + ' singleton';
  If (F And SF_METHOD_CLASS) <> 0 Then S := S + ' class-method';
  If (F And SF_PERSISTENT) <> 0 Then S := S + ' persistent';
  If (F And SF_DEAD) <> 0 Then S := S + ' dead';
  If (F And SF_CLASS_SINGLETON) <> 0 Then S := S + ' singleton-class';
  If (F And SF_CLASS_EIGEN) <> 0 Then S := S + ' eigenclass';
  If (F And SF_MODULE_FUNCTION) <> 0 Then S := S + ' module-function';
  SymFlagsName := S;
End;

Function VisibilityFlag(V: Integer): Integer;
Begin
  If V = VIS_PRIVATE Then VisibilityFlag := SF_METHOD_PRIVATE
  Else If V = VIS_PROTECTED Then VisibilityFlag := SF_METHOD_PROTECTED
  Else VisibilityFlag := SF_METHOD_PUBLIC;
End;

Function VisibilityName(V: Integer): String;
Begin
  If V = VIS_PRIVATE Then VisibilityName := 'private'
  Else If V = VIS_PROTECTED Then VisibilityName := 'protected'
  Else VisibilityName := 'public';
End;

Function AsmIdent(S: String): String;
Var
  I: Integer;
  C: Char;
  R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do Begin
    C := S[I];
    If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or (C = '_') Then
      R := R + C
    Else
      R := R + '_';
  End;
  If R = '' Then R := 'anon';
  AsmIdent := R;
End;

Function CurrentClassName: String;
Begin
  If (CurrentClassRef > 0) And (CurrentClassRef <= SymCount) Then
    CurrentClassName := SymTable[CurrentClassRef].Name
  Else
    CurrentClassName := 'Object';
End;

Function ScopeKindName(K: Integer): String;
Begin
  Case K Of
    SC_TOPLEVEL: ScopeKindName := 'toplevel';
    SC_BLOCK: ScopeKindName := 'block';
    SC_METHOD: ScopeKindName := 'method';
    SC_CLASS: ScopeKindName := 'class';
    SC_MODULE: ScopeKindName := 'module';
  Else
    ScopeKindName := 'scope';
  End;
End;

Function MakeFixnumValue(N: LongInt): LongInt;
Begin
  MakeFixnumValue := (N Shl 1) Or RV_FIXNUM_TAG;
End;

Function MakeSymbolValue(SymId: LongInt): LongInt;
Begin
  MakeSymbolValue := (SymId Shl RV_SYMBOL_SHIFT) Or RV_SYMBOL_TAG;
End;

Function IsImmediateValue(V: LongInt): Boolean;
Begin
  IsImmediateValue := ((V And RV_FIXNUM_TAG) = RV_FIXNUM_TAG) Or
                      (V = RV_FALSE) Or (V = RV_NIL) Or (V = RV_TRUE) Or
                      ((V And $000000FF) = RV_SYMBOL_TAG);
End;

Function FindSymInScope(Name: String; Scope: Integer): Integer;
Var
  I: Integer;
Begin
  FindSymInScope := 0;
  For I := SymCount DownTo 1 Do
    If (SymTable[I].Scope = Scope) And (SymTable[I].Name = Name) And
       ((SymTable[I].Flags And SF_DEAD) = 0) Then Begin
      FindSymInScope := I;
      Exit;
    End;
End;

Function FindSym(Name: String): Integer;
Var
  L, I: Integer;
Begin
  FindSym := 0;
  For L := ScopeLevel DownTo 0 Do Begin
    For I := SymCount DownTo 1 Do
      If (SymTable[I].Scope = L) And (SymTable[I].Name = Name) And
         ((SymTable[I].Flags And SF_DEAD) = 0) Then Begin
        FindSym := I;
        Exit;
      End;
  End;
End;

Function AllocSymOffset(Kind: Integer): Integer;
Begin
  AllocSymOffset := 0;
  If (Kind = SK_LOCAL) Or (Kind = SK_PARAM) Or (Kind = SK_BLOCK_PARAM) Then Begin
    Inc(ScopeNextLocal[ScopeLevel], 4);
    AllocSymOffset := -ScopeNextLocal[ScopeLevel];
  End Else If Kind = SK_GVAR Then
    AllocSymOffset := SymCount * 4
  Else If Kind = SK_IVAR Then
    AllocSymOffset := OBJ_HDR_SIZE + SymCount * 4;
End;

Function AddSym(Name: String; Kind, RType, ClassRef: Integer): Integer;
Var
  Existing: Integer;
Begin
  Existing := FindSymInScope(Name, ScopeLevel);
  If Existing <> 0 Then Begin
    AddSym := Existing;
    Exit;
  End;
  If SymCount >= MAX_SYM Then FatalError('table des symboles pleine');
  Inc(SymCount);
  SymTable[SymCount].Name := Name;
  SymTable[SymCount].Kind := Kind;
  SymTable[SymCount].RType := RType;
  SymTable[SymCount].Scope := ScopeLevel;
  SymTable[SymCount].DeclScopeKind := ScopeKind[ScopeLevel];
  SymTable[SymCount].Offset := AllocSymOffset(Kind);
  SymTable[SymCount].ClassRef := ClassRef;
  SymTable[SymCount].Flags := 0;
  If (Kind = SK_CONST) Or (Kind = SK_CLASS) Or (Kind = SK_MODULE) Then
    SymTable[SymCount].Flags := SymTable[SymCount].Flags Or SF_PERSISTENT;
  SymTable[SymCount].AsmName := '';
  SymTable[SymCount].ParamCount := 0;
  SymTable[SymCount].LocalSize := 0;
  SymTable[SymCount].RuntimeRef := 0;
  SymTable[SymCount].MethodName := '';
  SymTable[SymCount].OwnerMROIndex := 0;
  SymTable[SymCount].SuperMethodRef := 0;
  SymTable[SymCount].MissingFallbackRef := 0;
  AddSym := SymCount;
End;

Function FindClassBySym(SymRef: Integer): Integer;
Var
  I: Integer;
Begin
  FindClassBySym := 0;
  For I := 1 To ClassCount Do
    If ClassTable[I].SymRef = SymRef Then Begin
      FindClassBySym := I;
      Exit;
    End;
End;

Procedure BuildClassMRO(ClassIdx: Integer); Forward;

Function MethodShortName(FullName: String): String;
Var
  I: Integer;
Begin
  MethodShortName := FullName;
  For I := Length(FullName) DownTo 1 Do
    If (FullName[I] = '#') Or (FullName[I] = '.') Then Begin
      MethodShortName := Copy(FullName, I + 1, Length(FullName) - I);
      Exit;
    End;
End;

Function FindMethodOnOwner(OwnerSym: Integer; MethodName: String): Integer;
Var
  I: Integer;
  Prefix: String;
Begin
  FindMethodOnOwner := 0;
  If (OwnerSym <= 0) Or (OwnerSym > SymCount) Then Exit;
  Prefix := SymTable[OwnerSym].Name + '#';
  For I := SymCount DownTo 1 Do
    If (SymTable[I].Kind = SK_METHOD) And
       (SymTable[I].Name = Prefix + MethodName) And
       ((SymTable[I].Flags And SF_DEAD) = 0) Then Begin
      FindMethodOnOwner := I;
      Exit;
    End;
End;

Function FindMethodInMRO(ClassSym: Integer; MethodName: String;
                         StartIndex: Integer): Integer;
Var
  C, I, M: Integer;
Begin
  FindMethodInMRO := 0;
  C := FindClassBySym(ClassSym);
  If C = 0 Then Exit;
  If ClassTable[C].MROCount = 0 Then BuildClassMRO(C);
  If StartIndex < 1 Then StartIndex := 1;
  For I := StartIndex To ClassTable[C].MROCount Do Begin
    M := FindMethodOnOwner(ClassTable[C].MRO[I], MethodName);
    If M <> 0 Then Begin
      FindMethodInMRO := M;
      Exit;
    End;
  End;
End;

Procedure AddVTableMethod(ClassIdx, MethodSym: Integer);
Var
  I: Integer;
  ShortName: String;
Begin
  If (ClassIdx <= 0) Or (ClassIdx > ClassCount) Or
     (MethodSym <= 0) Or (MethodSym > SymCount) Then Exit;
  ShortName := SymTable[MethodSym].MethodName;
  If ShortName = '' Then ShortName := MethodShortName(SymTable[MethodSym].Name);
  For I := 1 To ClassTable[ClassIdx].VTableCount Do
    If SymTable[ClassTable[ClassIdx].VTableMethods[I]].MethodName = ShortName Then
      Exit;
  If ClassTable[ClassIdx].VTableCount < MAX_CLASS Then Begin
    Inc(ClassTable[ClassIdx].VTableCount);
    ClassTable[ClassIdx].VTableMethods[ClassTable[ClassIdx].VTableCount] := MethodSym;
  End;
End;

Procedure BuildClassVTable(ClassIdx: Integer);
Var
  I, J, OwnerSym: Integer;
Begin
  If (ClassIdx <= 0) Or (ClassIdx > ClassCount) Then Exit;
  ClassTable[ClassIdx].VTableCount := 0;
  If ClassTable[ClassIdx].MROCount = 0 Then BuildClassMRO(ClassIdx);
  For I := 1 To ClassTable[ClassIdx].MROCount Do Begin
    OwnerSym := ClassTable[ClassIdx].MRO[I];
    For J := 1 To SymCount Do
      If (SymTable[J].Kind = SK_METHOD) And
         (SymTable[J].ClassRef = OwnerSym) And
         ((SymTable[J].Flags And SF_METHOD_SINGLETON) = 0) And
         ((SymTable[J].Flags And SF_METHOD_CLASS) = 0) And
         ((SymTable[J].Flags And SF_DEAD) = 0) Then
        AddVTableMethod(ClassIdx, J);
  End;
End;

Procedure BuildAllVTables;
Var
  I: Integer;
Begin
  For I := 1 To ClassCount Do BuildClassVTable(I);
End;

Function ResolveSuperMethod: Integer;
Var
  StartAt, R: Integer;
Begin
  R := 0;
  If (CurrentMethodSym <= 0) Or (CurrentMethodSym > SymCount) Then Begin
    ResolveSuperMethod := 0;
    Exit;
  End;
  StartAt := SymTable[CurrentMethodSym].OwnerMROIndex + 1;
  If StartAt <= 1 Then StartAt := 2;
  R := FindMethodInMRO(CurrentClassRef, CurrentMethodName, StartAt);
  If R = 0 Then
    R := FindMethodInMRO(CurrentClassRef, 'method_missing', StartAt);
  ResolveSuperMethod := R;
End;

Procedure UpdateOwnerMethodsForClass(ClassIdx, OwnerSym: Integer);
Var
  I, J, OwnerIndex: Integer;
Begin
  If (ClassIdx <= 0) Or (ClassIdx > ClassCount) Or (OwnerSym = 0) Then Exit;
  OwnerIndex := 0;
  If ClassTable[ClassIdx].MROCount = 0 Then BuildClassMRO(ClassIdx);
  For I := 1 To ClassTable[ClassIdx].MROCount Do
    If ClassTable[ClassIdx].MRO[I] = OwnerSym Then Begin
      OwnerIndex := I;
      Break;
    End;
  If OwnerIndex = 0 Then Exit;
  For J := 1 To SymCount Do
    If (SymTable[J].Kind = SK_METHOD) And
       (SymTable[J].ClassRef = OwnerSym) And
       ((SymTable[J].Flags And SF_DEAD) = 0) Then Begin
      SymTable[J].OwnerMROIndex := OwnerIndex;
      SymTable[J].SuperMethodRef := FindMethodInMRO(ClassTable[ClassIdx].SymRef,
                                                    SymTable[J].MethodName,
                                                    OwnerIndex + 1);
      SymTable[J].MissingFallbackRef := FindMethodInMRO(ClassTable[ClassIdx].SymRef,
                                                        'method_missing', 1);
    End;
End;

Procedure AddMROEntry(ClassIdx, SymRef: Integer);
Var
  I: Integer;
Begin
  If (ClassIdx <= 0) Or (ClassIdx > ClassCount) Or (SymRef = 0) Then Exit;
  For I := 1 To ClassTable[ClassIdx].MROCount Do
    If ClassTable[ClassIdx].MRO[I] = SymRef Then Exit;
  If ClassTable[ClassIdx].MROCount < MAX_CLASS Then Begin
    Inc(ClassTable[ClassIdx].MROCount);
    ClassTable[ClassIdx].MRO[ClassTable[ClassIdx].MROCount] := SymRef;
  End;
End;

Procedure AddMROFromClass(ClassIdx, SourceIdx: Integer);
Var
  I: Integer;
Begin
  If (SourceIdx <= 0) Or (SourceIdx > ClassCount) Then Exit;
  If ClassTable[SourceIdx].MROCount = 0 Then BuildClassMRO(SourceIdx);
  For I := 1 To ClassTable[SourceIdx].MROCount Do
    AddMROEntry(ClassIdx, ClassTable[SourceIdx].MRO[I]);
End;

Procedure BuildClassMRO(ClassIdx: Integer);
Var
  I, SuperIdx, KernelIdx, ModuleIdx: Integer;
Begin
  If (ClassIdx <= 0) Or (ClassIdx > ClassCount) Then Exit;
  ClassTable[ClassIdx].MROCount := 0;
  For I := ClassTable[ClassIdx].PrependedCount DownTo 1 Do Begin
    ModuleIdx := FindClassBySym(ClassTable[ClassIdx].PrependList[I]);
    If ModuleIdx <> 0 Then AddMROFromClass(ClassIdx, ModuleIdx)
    Else AddMROEntry(ClassIdx, ClassTable[ClassIdx].PrependList[I]);
  End;
  AddMROEntry(ClassIdx, ClassTable[ClassIdx].SymRef);
  For I := ClassTable[ClassIdx].IncludedCount DownTo 1 Do Begin
    ModuleIdx := FindClassBySym(ClassTable[ClassIdx].IncludeList[I]);
    If ModuleIdx <> 0 Then AddMROFromClass(ClassIdx, ModuleIdx)
    Else AddMROEntry(ClassIdx, ClassTable[ClassIdx].IncludeList[I]);
  End;
  If ClassTable[ClassIdx].Name = 'Object' Then Begin
    KernelIdx := FindSym('Kernel');
    If KernelIdx <> 0 Then AddMROEntry(ClassIdx, KernelIdx);
  End;
  SuperIdx := FindClassBySym(ClassTable[ClassIdx].SuperRef);
  If SuperIdx <> 0 Then AddMROFromClass(ClassIdx, SuperIdx);
End;

Procedure AddMixinToClass(TargetSym, ModuleSym, Mode: Integer);
Var
  C, I: Integer;
  P: ^TClassMRO;
  Count: ^Integer;
Begin
  If TargetSym = 0 Then TargetSym := FindSym('Object');
  If (TargetSym = 0) Or (ModuleSym = 0) Then Exit;
  C := FindClassBySym(TargetSym);
  If C = 0 Then Exit;
  If Mode = KW_EXTEND Then Begin
    P := @ClassTable[C].ExtendList;
    Count := @ClassTable[C].ExtendedCount;
  End Else If Mode = KW_PREPEND Then Begin
    P := @ClassTable[C].PrependList;
    Count := @ClassTable[C].PrependedCount;
  End Else Begin
    P := @ClassTable[C].IncludeList;
    Count := @ClassTable[C].IncludedCount;
  End;
  For I := 1 To Count^ Do
    If P^[I] = ModuleSym Then Exit;
  If Count^ >= MAX_MIXIN Then FatalError('trop de mixins pour ' + ClassTable[C].Name);
  Inc(Count^);
  P^[Count^] := ModuleSym;
  BuildClassMRO(C);
  UpdateOwnerMethodsForClass(C, ClassTable[C].SymRef);
  UpdateOwnerMethodsForClass(C, ModuleSym);
End;

Function AddMethodSym(MethodName, OwnerName: String; Visibility, ParamCount: Integer;
                      IsSingleton, IsClassMethod: Boolean): Integer; Forward;

Procedure ApplyModuleFunction(MethodName: String);
Var
  InstSym, ClassSym: Integer;
Begin
  If MethodName = '' Then Exit;
  InstSym := FindSym(CurrentClassName + '#' + MethodName);
  If InstSym <> 0 Then
    SymTable[InstSym].Flags := SymTable[InstSym].Flags Or SF_MODULE_FUNCTION;
  ClassSym := AddMethodSym(MethodName, CurrentClassName, VIS_PUBLIC, 0, False, True);
  SymTable[ClassSym].Flags := SymTable[ClassSym].Flags Or SF_MODULE_FUNCTION;
End;

Function AddClassInfo(Name: String; SymRef, SuperRef: Integer;
                      IsSingleton: Boolean; EigenOf: Integer): Integer;
Var
  I: Integer;
Begin
  I := FindClassBySym(SymRef);
  If I <> 0 Then Begin
    ClassTable[I].SuperRef := SuperRef;
    ClassTable[I].IsSingleton := IsSingleton;
    ClassTable[I].EigenOf := EigenOf;
    BuildClassMRO(I);
    AddClassInfo := I;
    Exit;
  End;
  If ClassCount >= MAX_CLASS Then FatalError('table des classes pleine');
  Inc(ClassCount);
  ClassTable[ClassCount].Name := Name;
  ClassTable[ClassCount].SymRef := SymRef;
  ClassTable[ClassCount].SuperRef := SuperRef;
  ClassTable[ClassCount].VTableRef := 0;
  ClassTable[ClassCount].IvarCount := 0;
  ClassTable[ClassCount].MethodCount := 0;
  ClassTable[ClassCount].IncludedCount := 0;
  ClassTable[ClassCount].ExtendedCount := 0;
  ClassTable[ClassCount].PrependedCount := 0;
  ClassTable[ClassCount].ConstCount := 0;
  ClassTable[ClassCount].IsSingleton := IsSingleton;
  ClassTable[ClassCount].EigenOf := EigenOf;
  ClassTable[ClassCount].MROCount := 0;
  SymTable[SymRef].RuntimeRef := ClassCount;
  If IsSingleton Then
    SymTable[SymRef].Flags := SymTable[SymRef].Flags Or SF_CLASS_SINGLETON;
  If EigenOf <> 0 Then
    SymTable[SymRef].Flags := SymTable[SymRef].Flags Or SF_CLASS_EIGEN;
  BuildClassMRO(ClassCount);
  AddClassInfo := ClassCount;
End;

Procedure CountClassMembers;
Var
  I, C: Integer;
Begin
  For C := 1 To ClassCount Do Begin
    ClassTable[C].MethodCount := 0;
    ClassTable[C].IvarCount := 0;
    ClassTable[C].ConstCount := 0;
  End;
  For I := 1 To SymCount Do Begin
    C := FindClassBySym(SymTable[I].ClassRef);
    If C <> 0 Then Begin
      If SymTable[I].Kind = SK_METHOD Then Inc(ClassTable[C].MethodCount)
      Else If SymTable[I].Kind = SK_IVAR Then Inc(ClassTable[C].IvarCount)
      Else If SymTable[I].Kind = SK_CONST Then Inc(ClassTable[C].ConstCount);
    End;
  End;
End;

Function AddMethodSym(MethodName, OwnerName: String; Visibility, ParamCount: Integer;
                      IsSingleton, IsClassMethod: Boolean): Integer;
Var
  I, F, C, J: Integer;
  FullName: String;
Begin
  If OwnerName = '' Then OwnerName := CurrentClassName;
  FullName := OwnerName + '#' + MethodName;
  If IsSingleton Or IsClassMethod Then FullName := OwnerName + '.' + MethodName;
  I := AddSym(FullName, SK_METHOD, RT_UNKNOWN, CurrentClassRef);
  F := VisibilityFlag(Visibility);
  If IsSingleton Then F := F Or SF_METHOD_SINGLETON;
  If IsClassMethod Then F := F Or SF_METHOD_CLASS;
  F := F Or SF_PERSISTENT;
  SymTable[I].Flags := (SymTable[I].Flags And Not
    (SF_METHOD_PUBLIC Or SF_METHOD_PRIVATE Or SF_METHOD_PROTECTED)) Or F;
  SymTable[I].AsmName := ASM_PFX_METHOD + AsmIdent(OwnerName) + '_' +
                         AsmIdent(MethodName);
  SymTable[I].ParamCount := ParamCount;
  SymTable[I].MethodName := MethodName;
  SymTable[I].OwnerMROIndex := 0;
  C := FindClassBySym(CurrentClassRef);
  If C <> 0 Then Begin
    If ClassTable[C].MROCount = 0 Then BuildClassMRO(C);
    For J := 1 To ClassTable[C].MROCount Do
      If ClassTable[C].MRO[J] = CurrentClassRef Then Begin
        SymTable[I].OwnerMROIndex := J;
        Break;
      End;
  End;
  SymTable[I].SuperMethodRef := FindMethodInMRO(CurrentClassRef, MethodName,
                                                SymTable[I].OwnerMROIndex + 1);
  SymTable[I].MissingFallbackRef := FindMethodInMRO(CurrentClassRef,
                                                    'method_missing', 1);
  If C <> 0 Then
    For J := 1 To ClassTable[C].MROCount Do Begin
      If ClassTable[C].MRO[J] = CurrentClassRef Then Break;
      UpdateOwnerMethodsForClass(C, ClassTable[C].MRO[J]);
    End;
  AddMethodSym := I;
End;

Function AddPseudoConst(Name: String; RType: Integer): Integer;
Var
  I: Integer;
Begin
  I := AddSym(Name, SK_CONST, RType, 0);
  SymTable[I].Flags := SymTable[I].Flags Or SF_PSEUDO_CONST;
  AddPseudoConst := I;
End;

Function AddIOInfo(Name: String; Kind, SymRef, Flags: Integer): Integer;
Begin
  If IOInfoCount >= MAX_IO_INFO Then FatalError('table I/O pleine');
  Inc(IOInfoCount);
  IOInfoTable[IOInfoCount].Name := Name;
  IOInfoTable[IOInfoCount].Kind := Kind;
  IOInfoTable[IOInfoCount].SymRef := SymRef;
  IOInfoTable[IOInfoCount].RuntimeName := ASM_PFX_RUNTIME + 'io_' +
                                          AsmIdent(Name);
  IOInfoTable[IOInfoCount].Flags := Flags;
  AddIOInfo := IOInfoCount;
End;

Function ResolveLocal(Name: String): Integer;
Var
  I: Integer;
Begin
  I := FindSym(Name);
  If I = 0 Then I := AddSym(Name, SK_LOCAL, RT_UNKNOWN, CurrentClassRef);
  ResolveLocal := I;
End;

Function ResolveGlobal(Name: String): Integer;
Var
  I: Integer;
Begin
  I := FindSym(Name);
  If I = 0 Then I := AddSym(Name, SK_GVAR, RT_UNKNOWN, 0);
  SymTable[I].Flags := SymTable[I].Flags Or SF_GLOBAL_STORAGE;
  ResolveGlobal := I;
End;

Function ResolveIvar(Name: String): Integer;
Var
  I: Integer;
Begin
  I := FindSym(Name);
  If I = 0 Then I := AddSym(Name, SK_IVAR, RT_UNKNOWN, CurrentClassRef);
  SymTable[I].Flags := SymTable[I].Flags Or SF_IVAR_STORAGE;
  ResolveIvar := I;
End;

Function ResolveCvar(Name: String): Integer;
Var
  I: Integer;
Begin
  I := FindSym(Name);
  If I = 0 Then I := AddSym(Name, SK_CVAR, RT_UNKNOWN, CurrentClassRef);
  SymTable[I].Flags := SymTable[I].Flags Or SF_CVAR_STORAGE;
  ResolveCvar := I;
End;

Function ResolveConst(Name: String): Integer;
Var
  I: Integer;
Begin
  I := FindSym(Name);
  If I = 0 Then I := AddSym(Name, SK_CONST, RT_UNKNOWN, CurrentClassRef);
  ResolveConst := I;
End;

Function ResolveVarByToken(Tok: Integer; Name: String): Integer;
Begin
  If Tok = TOK_IVAR Then ResolveVarByToken := ResolveIvar(Name)
  Else If Tok = TOK_CVAR Then ResolveVarByToken := ResolveCvar(Name)
  Else If Tok = TOK_GVAR Then ResolveVarByToken := ResolveGlobal(Name)
  Else If Tok = TOK_CONST Then ResolveVarByToken := ResolveConst(Name)
  Else ResolveVarByToken := ResolveLocal(Name);
End;

Procedure MarkAssignedNode(N: Integer);
Var
  C, S: Integer;
Begin
  If N = 0 Then Exit;
  If AstTable[N].Kind = NK_LIST Then Begin
    C := AstTable[N].FirstChild;
    While C <> 0 Do Begin
      MarkAssignedNode(C);
      C := AstTable[C].NextSibling;
    End;
    Exit;
  End;
  S := AstTable[N].SymRef;
  If S = 0 Then Exit;
  If (SymTable[S].Kind = SK_CONST) And
     ((SymTable[S].Flags And SF_PSEUDO_CONST) <> 0) Then
    WarnMsg('affectation a une pseudo-constante ' + SymTable[S].Name)
  Else If (SymTable[S].Kind = SK_CONST) And
          ((SymTable[S].Flags And SF_CONST_ASSIGNED) <> 0) Then
    WarnMsg('constante deja assignee: ' + SymTable[S].Name);
  If SymTable[S].Kind = SK_CONST Then
    SymTable[S].Flags := SymTable[S].Flags Or SF_CONST_ASSIGNED;
End;

Procedure EnterScope(Kind: Integer);
Begin
  If ScopeLevel >= MAX_SCOPE Then FatalError('pile de scopes pleine');
  Inc(ScopeLevel);
  ScopeKind[ScopeLevel] := Kind;
  ScopeBase[ScopeLevel] := SymCount + 1;
  ScopeNextLocal[ScopeLevel] := 0;
  ScopeOwnerClass[ScopeLevel] := CurrentClassRef;
End;

Procedure LeaveScope;
Var
  OldOwner, Leaving, I: Integer;
Begin
  If ScopeLevel = 0 Then FatalError('impossible de quitter le scope racine');
  OldOwner := ScopeOwnerClass[ScopeLevel];
  Leaving := ScopeLevel;
  For I := 1 To SymCount Do
    If (SymTable[I].Scope = Leaving) And
       ((SymTable[I].Flags And SF_PERSISTENT) = 0) Then
      SymTable[I].Flags := SymTable[I].Flags Or SF_DEAD;
  Dec(ScopeLevel);
  CurrentClassRef := OldOwner;
End;

Procedure InitSymbols;
Var
  I, BasicSym, ObjectSym, KernelSym, ClassSym, ModuleClassSym, StringSym,
  ArraySym, HashSym, RangeSym, RegexpSym, EnumeratorSym, EnumerableSym,
  ComparableSym, IntegerSym,
  FloatSym, RationalSym, ComplexSym, NumericSym, MathSym, TimeSym, RandomSym,
  ObjectSpaceSym, GCSym, ProcessSym, ThreadSym, IOSym, FileSym, DirSym,
  ExceptionSym, StandardErrorSym,
  RuntimeErrorSym, ArgumentErrorSym, TypeErrorSym, NameErrorSym,
  NoMethodErrorSym, ZeroDivisionErrorSym, IndexErrorSym, KeyErrorSym,
  IOErrorSym, ScriptErrorSym, SignalExceptionSym, SystemExitSym,
  ArgvSym, EnvSym, StdInSym, StdOutSym, StdErrSym, PiSym, ESym: Integer;
  S: String;
Begin
  FillChar(SymTable, SizeOf(SymTable), 0);
  FillChar(ScopeKind, SizeOf(ScopeKind), 0);
  FillChar(ScopeBase, SizeOf(ScopeBase), 0);
  FillChar(ScopeNextLocal, SizeOf(ScopeNextLocal), 0);
  FillChar(ScopeOwnerClass, SizeOf(ScopeOwnerClass), 0);
  FillChar(ClassTable, SizeOf(ClassTable), 0);
  FillChar(IOInfoTable, SizeOf(IOInfoTable), 0);
  FillChar(RequireInfoTable, SizeOf(RequireInfoTable), 0);
  SymCount := 0;
  ClassCount := 0;
  IOInfoCount := 0;
  RequireInfoCount := 0;
  ScopeLevel := 0;
  ScopeKind[0] := SC_TOPLEVEL;
  ScopeBase[0] := 1;
  CurrentClassRef := 0;
  CurrentMethodSym := 0;
  CurrentMethodName := '';
  CurrentVisibility := VIS_PUBLIC;
  BasicSym := AddSym('BasicObject', SK_CLASS, RT_CLASS, 0);
  ObjectSym := AddSym('Object', SK_CLASS, RT_CLASS, BasicSym);
  KernelSym := AddSym('Kernel', SK_MODULE, RT_MODULE, 0);
  ModuleClassSym := AddSym('Module', SK_CLASS, RT_CLASS, ObjectSym);
  ClassSym := AddSym('Class', SK_CLASS, RT_CLASS, ModuleClassSym);
  StringSym := AddSym('String', SK_CLASS, RT_CLASS, ObjectSym);
  ArraySym := AddSym('Array', SK_CLASS, RT_CLASS, ObjectSym);
  HashSym := AddSym('Hash', SK_CLASS, RT_CLASS, ObjectSym);
  RangeSym := AddSym('Range', SK_CLASS, RT_CLASS, ObjectSym);
  RegexpSym := AddSym('Regexp', SK_CLASS, RT_CLASS, ObjectSym);
  EnumeratorSym := AddSym('Enumerator', SK_CLASS, RT_CLASS, ObjectSym);
  EnumerableSym := AddSym('Enumerable', SK_MODULE, RT_MODULE, 0);
  ComparableSym := AddSym('Comparable', SK_MODULE, RT_MODULE, 0);
  NumericSym := AddSym('Numeric', SK_CLASS, RT_CLASS, ObjectSym);
  IntegerSym := AddSym('Integer', SK_CLASS, RT_CLASS, NumericSym);
  FloatSym := AddSym('Float', SK_CLASS, RT_CLASS, NumericSym);
  RationalSym := AddSym('Rational', SK_CLASS, RT_CLASS, NumericSym);
  ComplexSym := AddSym('Complex', SK_CLASS, RT_CLASS, NumericSym);
  MathSym := AddSym('Math', SK_MODULE, RT_MODULE, 0);
  TimeSym := AddSym('Time', SK_CLASS, RT_CLASS, ObjectSym);
  RandomSym := AddSym('Random', SK_CLASS, RT_CLASS, ObjectSym);
  ObjectSpaceSym := AddSym('ObjectSpace', SK_MODULE, RT_MODULE, 0);
  GCSym := AddSym('GC', SK_MODULE, RT_MODULE, 0);
  ProcessSym := AddSym('Process', SK_MODULE, RT_MODULE, 0);
  ThreadSym := AddSym('Thread', SK_CLASS, RT_CLASS, ObjectSym);
  IOSym := AddSym('IO', SK_CLASS, RT_CLASS, ObjectSym);
  FileSym := AddSym('File', SK_CLASS, RT_CLASS, IOSym);
  DirSym := AddSym('Dir', SK_CLASS, RT_CLASS, ObjectSym);
  AddClassInfo('BasicObject', BasicSym, 0, False, 0);
  AddClassInfo('Object', ObjectSym, BasicSym, False, 0);
  AddClassInfo('Kernel', KernelSym, 0, False, 0);
  AddClassInfo('Module', ModuleClassSym, ObjectSym, False, 0);
  AddClassInfo('Class', ClassSym, ModuleClassSym, False, 0);
  AddClassInfo('String', StringSym, ObjectSym, False, 0);
  AddClassInfo('Array', ArraySym, ObjectSym, False, 0);
  AddClassInfo('Hash', HashSym, ObjectSym, False, 0);
  AddClassInfo('Range', RangeSym, ObjectSym, False, 0);
  AddClassInfo('Regexp', RegexpSym, ObjectSym, False, 0);
  AddClassInfo('Enumerator', EnumeratorSym, ObjectSym, False, 0);
  AddClassInfo('Enumerable', EnumerableSym, 0, False, 0);
  AddClassInfo('Comparable', ComparableSym, 0, False, 0);
  AddClassInfo('Numeric', NumericSym, ObjectSym, False, 0);
  AddClassInfo('Integer', IntegerSym, NumericSym, False, 0);
  AddClassInfo('Float', FloatSym, NumericSym, False, 0);
  AddClassInfo('Rational', RationalSym, NumericSym, False, 0);
  AddClassInfo('Complex', ComplexSym, NumericSym, False, 0);
  AddClassInfo('Math', MathSym, 0, False, 0);
  AddClassInfo('Time', TimeSym, ObjectSym, False, 0);
  AddClassInfo('Random', RandomSym, ObjectSym, False, 0);
  AddClassInfo('ObjectSpace', ObjectSpaceSym, 0, False, 0);
  AddClassInfo('GC', GCSym, 0, False, 0);
  AddClassInfo('Process', ProcessSym, 0, False, 0);
  AddClassInfo('Thread', ThreadSym, ObjectSym, False, 0);
  AddClassInfo('IO', IOSym, ObjectSym, False, 0);
  AddClassInfo('File', FileSym, IOSym, False, 0);
  AddClassInfo('Dir', DirSym, ObjectSym, False, 0);
  ExceptionSym := AddSym('Exception', SK_CLASS, RT_CLASS, ObjectSym);
  StandardErrorSym := AddSym('StandardError', SK_CLASS, RT_CLASS, ExceptionSym);
  RuntimeErrorSym := AddSym('RuntimeError', SK_CLASS, RT_CLASS, StandardErrorSym);
  ArgumentErrorSym := AddSym('ArgumentError', SK_CLASS, RT_CLASS, StandardErrorSym);
  TypeErrorSym := AddSym('TypeError', SK_CLASS, RT_CLASS, StandardErrorSym);
  NameErrorSym := AddSym('NameError', SK_CLASS, RT_CLASS, StandardErrorSym);
  NoMethodErrorSym := AddSym('NoMethodError', SK_CLASS, RT_CLASS, NameErrorSym);
  ZeroDivisionErrorSym := AddSym('ZeroDivisionError', SK_CLASS, RT_CLASS,
                                 StandardErrorSym);
  IndexErrorSym := AddSym('IndexError', SK_CLASS, RT_CLASS, StandardErrorSym);
  KeyErrorSym := AddSym('KeyError', SK_CLASS, RT_CLASS, IndexErrorSym);
  IOErrorSym := AddSym('IOError', SK_CLASS, RT_CLASS, StandardErrorSym);
  ScriptErrorSym := AddSym('ScriptError', SK_CLASS, RT_CLASS, ExceptionSym);
  SignalExceptionSym := AddSym('SignalException', SK_CLASS, RT_CLASS, ExceptionSym);
  SystemExitSym := AddSym('SystemExit', SK_CLASS, RT_CLASS, ExceptionSym);
  AddClassInfo('Exception', ExceptionSym, ObjectSym, False, 0);
  AddClassInfo('StandardError', StandardErrorSym, ExceptionSym, False, 0);
  AddClassInfo('RuntimeError', RuntimeErrorSym, StandardErrorSym, False, 0);
  AddClassInfo('ArgumentError', ArgumentErrorSym, StandardErrorSym, False, 0);
  AddClassInfo('TypeError', TypeErrorSym, StandardErrorSym, False, 0);
  AddClassInfo('NameError', NameErrorSym, StandardErrorSym, False, 0);
  AddClassInfo('NoMethodError', NoMethodErrorSym, NameErrorSym, False, 0);
  AddClassInfo('ZeroDivisionError', ZeroDivisionErrorSym, StandardErrorSym,
               False, 0);
  AddClassInfo('IndexError', IndexErrorSym, StandardErrorSym, False, 0);
  AddClassInfo('KeyError', KeyErrorSym, IndexErrorSym, False, 0);
  AddClassInfo('IOError', IOErrorSym, StandardErrorSym, False, 0);
  AddClassInfo('ScriptError', ScriptErrorSym, ExceptionSym, False, 0);
  AddClassInfo('SignalException', SignalExceptionSym, ExceptionSym, False, 0);
  AddClassInfo('SystemExit', SystemExitSym, ExceptionSym, False, 0);
  CurrentClassRef := KernelSym;
  AddMethodSym('method_missing', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('respond_to?', 'Kernel', VIS_PUBLIC, 1, False, False);
  AddMethodSym('respond_to_missing?', 'Kernel', VIS_PRIVATE, 1, False, False);
  AddMethodSym('send', 'Kernel', VIS_PUBLIC, -1, False, False);
  AddMethodSym('__send__', 'Kernel', VIS_PUBLIC, -1, False, False);
  AddMethodSym('public_send', 'Kernel', VIS_PUBLIC, -1, False, False);
  AddMethodSym('puts', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('print', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('p', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('pp', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('printf', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('sprintf', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('format', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('gets', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('getc', 'Kernel', VIS_PRIVATE, 0, False, False);
  AddMethodSym('readline', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('readlines', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('raise', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('fail', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('throw', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('catch', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('loop', 'Kernel', VIS_PRIVATE, 0, False, False);
  AddMethodSym('lambda', 'Kernel', VIS_PRIVATE, 0, False, False);
  AddMethodSym('proc', 'Kernel', VIS_PRIVATE, 0, False, False);
  AddMethodSym('require', 'Kernel', VIS_PRIVATE, 1, False, False);
  AddMethodSym('require_relative', 'Kernel', VIS_PRIVATE, 1, False, False);
  AddMethodSym('load', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('autoload', 'Kernel', VIS_PRIVATE, 2, False, False);
  AddMethodSym('Integer', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('Float', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('Rational', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('Complex', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('String', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('Array', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('Hash', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('rand', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('srand', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('sleep', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('exit', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('exit!', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('abort', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('at_exit', 'Kernel', VIS_PRIVATE, 0, False, False);
  AddMethodSym('eval', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('binding', 'Kernel', VIS_PRIVATE, 0, False, False);
  AddMethodSym('caller', 'Kernel', VIS_PRIVATE, -1, False, False);
  AddMethodSym('method', 'Kernel', VIS_PUBLIC, 1, False, False);
  AddMethodSym('methods', 'Kernel', VIS_PUBLIC, -1, False, False);
  AddMethodSym('instance_variables', 'Kernel', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := ObjectSym;
  AddMethodSym('class', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('kind_of?', 'Object', VIS_PUBLIC, 1, False, False);
  AddMethodSym('is_a?', 'Object', VIS_PUBLIC, 1, False, False);
  AddMethodSym('instance_of?', 'Object', VIS_PUBLIC, 1, False, False);
  AddMethodSym('frozen?', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('freeze', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('dup', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('clone', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('hash', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('object_id', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('equal?', 'Object', VIS_PUBLIC, 1, False, False);
  AddMethodSym('==', 'Object', VIS_PUBLIC, 1, False, False);
  AddMethodSym('!=', 'Object', VIS_PUBLIC, 1, False, False);
  AddMethodSym('!', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('inspect', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_s', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('tap', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('then', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('yield_self', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('itself', 'Object', VIS_PUBLIC, 0, False, False);
  AddMethodSym('instance_eval', 'Object', VIS_PUBLIC, -1, False, False);
  AddMethodSym('class_eval', 'Object', VIS_PUBLIC, -1, False, False);
  AddMethodSym('module_eval', 'Object', VIS_PUBLIC, -1, False, False);
  CurrentClassRef := ModuleClassSym;
  AddMethodSym('class_eval', 'Module', VIS_PUBLIC, -1, False, False);
  AddMethodSym('module_eval', 'Module', VIS_PUBLIC, -1, False, False);
  AddMethodSym('define_method', 'Module', VIS_PUBLIC, -1, False, False);
  AddMethodSym('method_defined?', 'Module', VIS_PUBLIC, 1, False, False);
  AddMethodSym('instance_methods', 'Module', VIS_PUBLIC, -1, False, False);
  AddMethodSym('constants', 'Module', VIS_PUBLIC, -1, False, False);
  CurrentClassRef := ClassSym;
  AddMethodSym('new', 'Class', VIS_PUBLIC, -1, False, False);
  AddMethodSym('allocate', 'Class', VIS_PUBLIC, 0, False, False);
  AddMethodSym('superclass', 'Class', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := EnumerableSym;
  AddMethodSym('map', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('collect', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('select', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('filter', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('reject', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('find', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('detect', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('find_index', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('count', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('inject', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('reduce', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('sum', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('min', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('max', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('min_by', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('max_by', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('sort', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('sort_by', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('group_by', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('partition', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('chunk', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('slice', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('each_with_index', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('each_with_object', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('zip', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('take', 'Enumerable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('take_while', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('drop', 'Enumerable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('drop_while', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('all?', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('any?', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('none?', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('one?', 'Enumerable', VIS_PUBLIC, -1, False, False);
  AddMethodSym('include?', 'Enumerable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('member?', 'Enumerable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('to_a', 'Enumerable', VIS_PUBLIC, 0, False, False);
  AddMethodSym('entries', 'Enumerable', VIS_PUBLIC, 0, False, False);
  AddMethodSym('lazy', 'Enumerable', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := ComparableSym;
  AddMethodSym('<', 'Comparable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('<=', 'Comparable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('>', 'Comparable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('>=', 'Comparable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('==', 'Comparable', VIS_PUBLIC, 1, False, False);
  AddMethodSym('between?', 'Comparable', VIS_PUBLIC, 2, False, False);
  AddMethodSym('clamp', 'Comparable', VIS_PUBLIC, -1, False, False);
  CurrentClassRef := NumericSym;
  AddMethodSym('+', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('-', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('*', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('/', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('%', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('**', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('<=>', 'Numeric', VIS_PUBLIC, 1, False, False);
  AddMethodSym('abs', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('zero?', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('positive?', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('negative?', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_i', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_f', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_r', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_c', 'Numeric', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_s', 'Numeric', VIS_PUBLIC, -1, False, False);
  CurrentClassRef := IntegerSym;
  AddMethodSym('&', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('|', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('^', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('~', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('<<', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('>>', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('div', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('modulo', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('divmod', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('times', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('upto', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('downto', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('step', 'Integer', VIS_PUBLIC, -1, False, False);
  AddMethodSym('even?', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('odd?', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('succ', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('next', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('pred', 'Integer', VIS_PUBLIC, 0, False, False);
  AddMethodSym('gcd', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('lcm', 'Integer', VIS_PUBLIC, 1, False, False);
  AddMethodSym('digits', 'Integer', VIS_PUBLIC, -1, False, False);
  AddMethodSym('bit_length', 'Integer', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := FloatSym;
  AddMethodSym('floor', 'Float', VIS_PUBLIC, -1, False, False);
  AddMethodSym('ceil', 'Float', VIS_PUBLIC, -1, False, False);
  AddMethodSym('round', 'Float', VIS_PUBLIC, -1, False, False);
  AddMethodSym('truncate', 'Float', VIS_PUBLIC, -1, False, False);
  AddMethodSym('finite?', 'Float', VIS_PUBLIC, 0, False, False);
  AddMethodSym('infinite?', 'Float', VIS_PUBLIC, 0, False, False);
  AddMethodSym('nan?', 'Float', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := RationalSym;
  AddMethodSym('new', 'Rational', VIS_PUBLIC, -1, False, True);
  AddMethodSym('numerator', 'Rational', VIS_PUBLIC, 0, False, False);
  AddMethodSym('denominator', 'Rational', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := ComplexSym;
  AddMethodSym('new', 'Complex', VIS_PUBLIC, -1, False, True);
  AddMethodSym('real', 'Complex', VIS_PUBLIC, 0, False, False);
  AddMethodSym('imaginary', 'Complex', VIS_PUBLIC, 0, False, False);
  AddMethodSym('imag', 'Complex', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := StringSym;
  AddMethodSym('match', 'String', VIS_PUBLIC, 1, False, False);
  AddMethodSym('scan', 'String', VIS_PUBLIC, 1, False, False);
  AddMethodSym('sub', 'String', VIS_PUBLIC, -1, False, False);
  AddMethodSym('gsub', 'String', VIS_PUBLIC, -1, False, False);
  AddMethodSym('split', 'String', VIS_PUBLIC, -1, False, False);
  AddMethodSym('<=>', 'String', VIS_PUBLIC, 1, False, False);
  CurrentClassRef := ArraySym;
  AddMethodSym('each', 'Array', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := HashSym;
  AddMethodSym('each', 'Hash', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := RangeSym;
  AddMethodSym('each', 'Range', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_a', 'Range', VIS_PUBLIC, 0, False, False);
  AddMethodSym('include?', 'Range', VIS_PUBLIC, 1, False, False);
  AddMethodSym('cover?', 'Range', VIS_PUBLIC, 1, False, False);
  AddMethodSym('size', 'Range', VIS_PUBLIC, 0, False, False);
  AddMethodSym('first', 'Range', VIS_PUBLIC, -1, False, False);
  AddMethodSym('last', 'Range', VIS_PUBLIC, -1, False, False);
  AddMethodSym('min', 'Range', VIS_PUBLIC, -1, False, False);
  AddMethodSym('max', 'Range', VIS_PUBLIC, -1, False, False);
  AddMethodSym('step', 'Range', VIS_PUBLIC, -1, False, False);
  CurrentClassRef := EnumeratorSym;
  AddMethodSym('each', 'Enumerator', VIS_PUBLIC, 0, False, False);
  AddMethodSym('new', 'Enumerator', VIS_PUBLIC, -1, False, True);
  CurrentClassRef := RegexpSym;
  AddMethodSym('match', 'Regexp', VIS_PUBLIC, 1, False, False);
  AddMethodSym('match?', 'Regexp', VIS_PUBLIC, 1, False, False);
  AddMethodSym('=~', 'Regexp', VIS_PUBLIC, 1, False, False);
  AddMethodSym('source', 'Regexp', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := MathSym;
  PiSym := AddSym('Math::PI', SK_CONST, RT_FLOAT, MathSym);
  ESym := AddSym('Math::E', SK_CONST, RT_FLOAT, MathSym);
  SymTable[PiSym].Flags := SymTable[PiSym].Flags Or SF_CONST_ASSIGNED;
  SymTable[ESym].Flags := SymTable[ESym].Flags Or SF_CONST_ASSIGNED;
  AddMethodSym('sqrt', 'Math', VIS_PUBLIC, 1, False, True);
  AddMethodSym('sin', 'Math', VIS_PUBLIC, 1, False, True);
  AddMethodSym('cos', 'Math', VIS_PUBLIC, 1, False, True);
  AddMethodSym('tan', 'Math', VIS_PUBLIC, 1, False, True);
  AddMethodSym('log', 'Math', VIS_PUBLIC, -1, False, True);
  AddMethodSym('exp', 'Math', VIS_PUBLIC, 1, False, True);
  AddMethodSym('atan2', 'Math', VIS_PUBLIC, 2, False, True);
  CurrentClassRef := TimeSym;
  AddMethodSym('now', 'Time', VIS_PUBLIC, 0, False, True);
  AddMethodSym('new', 'Time', VIS_PUBLIC, -1, False, True);
  AddMethodSym('+', 'Time', VIS_PUBLIC, 1, False, False);
  AddMethodSym('-', 'Time', VIS_PUBLIC, 1, False, False);
  AddMethodSym('strftime', 'Time', VIS_PUBLIC, 1, False, False);
  AddMethodSym('year', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('month', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('day', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('hour', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('min', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('sec', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_i', 'Time', VIS_PUBLIC, 0, False, False);
  AddMethodSym('to_f', 'Time', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := RandomSym;
  AddMethodSym('new', 'Random', VIS_PUBLIC, -1, False, True);
  AddMethodSym('rand', 'Random', VIS_PUBLIC, -1, False, True);
  AddMethodSym('rand', 'Random', VIS_PUBLIC, -1, False, False);
  AddMethodSym('srand', 'Random', VIS_PUBLIC, -1, False, True);
  CurrentClassRef := ObjectSpaceSym;
  AddMethodSym('each_object', 'ObjectSpace', VIS_PUBLIC, -1, False, True);
  AddMethodSym('count_objects', 'ObjectSpace', VIS_PUBLIC, -1, False, True);
  AddMethodSym('garbage_collect', 'ObjectSpace', VIS_PUBLIC, 0, False, True);
  CurrentClassRef := GCSym;
  AddMethodSym('start', 'GC', VIS_PUBLIC, -1, False, True);
  AddMethodSym('enable', 'GC', VIS_PUBLIC, 0, False, True);
  AddMethodSym('disable', 'GC', VIS_PUBLIC, 0, False, True);
  AddMethodSym('stat', 'GC', VIS_PUBLIC, 0, False, True);
  CurrentClassRef := ProcessSym;
  AddMethodSym('pid', 'Process', VIS_PUBLIC, 0, False, True);
  AddMethodSym('ppid', 'Process', VIS_PUBLIC, 0, False, True);
  AddMethodSym('exit', 'Process', VIS_PUBLIC, -1, False, True);
  AddMethodSym('exit!', 'Process', VIS_PUBLIC, -1, False, True);
  AddMethodSym('abort', 'Process', VIS_PUBLIC, -1, False, True);
  AddMethodSym('clock_gettime', 'Process', VIS_PUBLIC, -1, False, True);
  CurrentClassRef := ThreadSym;
  AddMethodSym('current', 'Thread', VIS_PUBLIC, 0, False, True);
  AddMethodSym('main', 'Thread', VIS_PUBLIC, 0, False, True);
  AddMethodSym('new', 'Thread', VIS_PUBLIC, -1, False, True);
  AddMethodSym('value', 'Thread', VIS_PUBLIC, 0, False, False);
  AddMethodSym('join', 'Thread', VIS_PUBLIC, -1, False, False);
  AddMethodSym('alive?', 'Thread', VIS_PUBLIC, 0, False, False);
  CurrentClassRef := IOSym;
  AddMethodSym('read', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('write', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('puts', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('gets', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('each_line', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('close', 'IO', VIS_PUBLIC, 0, False, False);
  AddMethodSym('eof?', 'IO', VIS_PUBLIC, 0, False, False);
  AddMethodSym('pos', 'IO', VIS_PUBLIC, 0, False, False);
  AddMethodSym('seek', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('rewind', 'IO', VIS_PUBLIC, 0, False, False);
  AddMethodSym('getc', 'IO', VIS_PUBLIC, 0, False, False);
  AddMethodSym('readline', 'IO', VIS_PUBLIC, -1, False, False);
  AddMethodSym('readlines', 'IO', VIS_PUBLIC, -1, False, False);
  CurrentClassRef := FileSym;
  AddMethodSym('open', 'File', VIS_PUBLIC, -1, False, True);
  AddMethodSym('read', 'File', VIS_PUBLIC, -1, False, True);
  AddMethodSym('write', 'File', VIS_PUBLIC, -1, False, True);
  AddMethodSym('exist?', 'File', VIS_PUBLIC, 1, False, True);
  AddMethodSym('directory?', 'File', VIS_PUBLIC, 1, False, True);
  AddMethodSym('size', 'File', VIS_PUBLIC, 1, False, True);
  AddMethodSym('delete', 'File', VIS_PUBLIC, -1, False, True);
  CurrentClassRef := DirSym;
  AddMethodSym('entries', 'Dir', VIS_PUBLIC, 1, False, True);
  AddMethodSym('glob', 'Dir', VIS_PUBLIC, -1, False, True);
  AddMethodSym('chdir', 'Dir', VIS_PUBLIC, -1, False, True);
  AddMethodSym('pwd', 'Dir', VIS_PUBLIC, 0, False, True);
  AddMethodSym('mkdir', 'Dir', VIS_PUBLIC, -1, False, True);
  AddMixinToClass(StringSym, ComparableSym, KW_INCLUDE);
  AddMixinToClass(NumericSym, ComparableSym, KW_INCLUDE);
  AddMixinToClass(IntegerSym, ComparableSym, KW_INCLUDE);
  AddMixinToClass(FloatSym, ComparableSym, KW_INCLUDE);
  AddMixinToClass(RationalSym, ComparableSym, KW_INCLUDE);
  AddMixinToClass(IntegerSym, EnumerableSym, KW_INCLUDE);
  AddMixinToClass(ArraySym, EnumerableSym, KW_INCLUDE);
  AddMixinToClass(HashSym, EnumerableSym, KW_INCLUDE);
  AddMixinToClass(RangeSym, EnumerableSym, KW_INCLUDE);
  AddMixinToClass(EnumeratorSym, EnumerableSym, KW_INCLUDE);
  AddMixinToClass(IOSym, EnumerableSym, KW_INCLUDE);
  ArgvSym := AddPseudoConst('ARGV', RT_ARRAY);
  EnvSym := AddPseudoConst('ENV', RT_HASH);
  StdInSym := AddPseudoConst('STDIN', RT_OBJECT);
  StdOutSym := AddPseudoConst('STDOUT', RT_OBJECT);
  StdErrSym := AddPseudoConst('STDERR', RT_OBJECT);
  AddIOInfo('ARGV', 0, ArgvSym, IOF_ARGV);
  AddIOInfo('ENV', 0, EnvSym, IOF_ENV);
  AddIOInfo('STDIN', 0, StdInSym, IOF_STDIN Or IOF_READABLE);
  AddIOInfo('STDOUT', 0, StdOutSym, IOF_STDOUT Or IOF_WRITABLE);
  AddIOInfo('STDERR', 0, StdErrSym, IOF_STDERR Or IOF_WRITABLE);
  AddIOInfo('File', 0, FileSym, IOF_FILE_CLASS Or IOF_READABLE Or
            IOF_WRITABLE);
  AddIOInfo('Dir', 0, DirSym, IOF_DIR_CLASS);
  AddIOInfo('mode:r', 1, 0, IOF_MODE Or IOF_READABLE);
  AddIOInfo('mode:w', 1, 0, IOF_MODE Or IOF_WRITABLE);
  AddIOInfo('mode:a', 1, 0, IOF_MODE Or IOF_WRITABLE);
  AddIOInfo('mode:r+', 1, 0, IOF_MODE Or IOF_READABLE Or IOF_WRITABLE);
  AddIOInfo('mode:w+', 1, 0, IOF_MODE Or IOF_READABLE Or IOF_WRITABLE);
  AddIOInfo('mode:a+', 1, 0, IOF_MODE Or IOF_READABLE Or IOF_WRITABLE);
  AddIOInfo('mode:rb', 1, 0, IOF_MODE Or IOF_READABLE);
  AddIOInfo('mode:wb', 1, 0, IOF_MODE Or IOF_WRITABLE);
  ResolveGlobal('$0');
  ResolveGlobal('$~');
  ResolveGlobal('$!');
  ResolveGlobal('$LOAD_PATH');
  ResolveGlobal('$:');
  ResolveGlobal('$LOADED_FEATURES');
  ResolveGlobal('$"');
  ResolveGlobal('$`');
  ResolveGlobal('$''');
  ResolveGlobal('$&');
  For I := 1 To 9 Do Begin
    Str(I, S);
    ResolveGlobal('$' + S);
  End;
  CurrentClassRef := ObjectSym;
  BuildClassMRO(FindClassBySym(ObjectSym));
End;

Procedure DumpSymbols;
Var
  I: Integer;
Begin
  CountClassMembers;
  WriteLn('Symboles: ', SymCount);
  For I := 1 To SymCount Do
    WriteLn(I:5, '  ', SymTable[I].Name,
            ' kind=', SymKindName(SymTable[I].Kind),
            ' type=', RuntimeTypeName(SymTable[I].RType),
            ' scope=', ScopeKindName(SymTable[I].DeclScopeKind),
            ' offset=', SymTable[I].Offset:0,
            ' class=', SymTable[I].ClassRef:0,
            ' flags=', SymFlagsName(SymTable[I].Flags),
            ' asm=', SymTable[I].AsmName,
            ' argc=', SymTable[I].ParamCount:0,
            ' locals=', SymTable[I].LocalSize:0,
            ' mroidx=', SymTable[I].OwnerMROIndex:0,
            ' super=', SymTable[I].SuperMethodRef:0,
            ' missing=', SymTable[I].MissingFallbackRef:0);
End;

Procedure DumpClasses;
Var
  I, J: Integer;
Begin
  CountClassMembers;
  BuildAllVTables;
  WriteLn('Classes: ', ClassCount);
  For I := 1 To ClassCount Do Begin
    Write('  ', I:0, ' ', ClassTable[I].Name,
          ' sym=', ClassTable[I].SymRef:0,
          ' super=', ClassTable[I].SuperRef:0,
          ' methods=', ClassTable[I].MethodCount:0,
          ' ivars=', ClassTable[I].IvarCount:0,
          ' include=', ClassTable[I].IncludedCount:0,
          ' extend=', ClassTable[I].ExtendedCount:0,
          ' prepend=', ClassTable[I].PrependedCount:0,
          ' vtable=', ClassTable[I].VTableCount:0,
          ' consts=', ClassTable[I].ConstCount:0);
    If ClassTable[I].IsSingleton Then Write(' singleton');
    If ClassTable[I].EigenOf <> 0 Then Write(' eigen-of=', ClassTable[I].EigenOf:0);
    Write(' mro=[');
    For J := 1 To ClassTable[I].MROCount Do Begin
      If J > 1 Then Write(',');
      If (ClassTable[I].MRO[J] > 0) And (ClassTable[I].MRO[J] <= SymCount) Then
        Write(SymTable[ClassTable[I].MRO[J]].Name)
      Else
        Write(ClassTable[I].MRO[J]:0);
    End;
    WriteLn(']');
  End;
End;

Function StringFlagsName(F: Integer): String; Forward;
Function RegexFlagsName(F: Integer): String; Forward;
Function RangeFlagsName(F: Integer): String; Forward;
Function NumFlagsName(F: Integer): String; Forward;
Function IOFlagsName(F: Integer): String; Forward;

Function NodeKindName(K: Integer): String; Forward;
Function BlockFlagsName(F: Integer): String; Forward;
Function ControlFlagsName(F: Integer): String; Forward;
Function RescueFlagsName(F: Integer): String; Forward;

Procedure DumpStrings;
Var
  I: Integer;
Begin
  WriteLn('Chaines: ', StringCount);
  For I := 1 To StringCount Do
    WriteLn(I:5, '  ', StringTable[I].AsmName,
            ' len=', StringTable[I].Len:0,
            ' cap=', StringTable[I].Cap:0,
            ' segments=', StringTable[I].SegmentCount:0,
            ' flags=', StringFlagsName(StringTable[I].Flags),
            ' text="', StringTable[I].Text, '"');
End;

Procedure DumpLiterals;
Var
  I: Integer;
Begin
  WriteLn('Symboles litteraux: ', SymbolLitCount);
  For I := 1 To SymbolLitCount Do
    WriteLn(I:5, '  ', SymbolLitTable[I].AsmName,
            ' value=', SymbolLitTable[I].Value:0,
            ' name=:', SymbolLitTable[I].Name);
  WriteLn('Regexps: ', RegexLitCount);
  For I := 1 To RegexLitCount Do
    WriteLn(I:5, '  ', RegexLitTable[I].AsmName,
            ' captures=', RegexLitTable[I].CaptureCount:0,
            ' flags=', RegexLitTable[I].Flags:0,
            RegexFlagsName(RegexLitTable[I].Flags),
            ' opts="', RegexLitTable[I].Options, '"',
            ' pattern="', RegexLitTable[I].Pattern, '"');
  WriteLn('Ranges: ', RangeLitCount);
  For I := 1 To RangeLitCount Do
    WriteLn(I:5, '  ', RangeLitTable[I].AsmName,
            ' begin=', RangeLitTable[I].BeginNode:0,
            ' end=', RangeLitTable[I].EndNode:0,
            ' flags=', RangeLitTable[I].Flags:0,
            RangeFlagsName(RangeLitTable[I].Flags));
  WriteLn('Numeriques: ', NumLitCount);
  For I := 1 To NumLitCount Do
    WriteLn(I:5, '  ', NumLitTable[I].AsmName,
            ' type=', RuntimeTypeName(NumLitTable[I].RType),
            ' base=', NumLitTable[I].Base:0,
            ' flags=', NumLitTable[I].Flags:0,
            NumFlagsName(NumLitTable[I].Flags),
            ' text="', NumLitTable[I].Text, '"');
  WriteLn('Arrays litteraux: ', ArrayLitCount);
  For I := 1 To ArrayLitCount Do
    WriteLn(I:5, '  ', ArrayLitTable[I].AsmName,
            ' count=', ArrayLitTable[I].Count:0,
            ' cap=', ArrayLitTable[I].Cap:0,
            ' first=', ArrayLitTable[I].FirstNode:0,
            ' flags=', ArrayLitTable[I].Flags:0);
  WriteLn('Hashes litteraux: ', HashLitCount);
  For I := 1 To HashLitCount Do
    WriteLn(I:5, '  ', HashLitTable[I].AsmName,
            ' count=', HashLitTable[I].Count:0,
            ' cap=', HashLitTable[I].Cap:0,
            ' first=', HashLitTable[I].FirstPair:0,
            ' flags=', HashLitTable[I].Flags:0);
End;

Procedure DumpIOInfos;
Var
  I: Integer;
Begin
  WriteLn('I/O: ', IOInfoCount);
  For I := 1 To IOInfoCount Do
    WriteLn(I:5, '  ', IOInfoTable[I].Name,
            ' kind=', IOInfoTable[I].Kind:0,
            ' sym=', IOInfoTable[I].SymRef:0,
            ' runtime=', IOInfoTable[I].RuntimeName,
            ' flags=', IOInfoTable[I].Flags:0,
            IOFlagsName(IOInfoTable[I].Flags));
End;

Procedure DumpRequireInfos;
Var
  I: Integer;
Begin
  WriteLn('Require/load: ', RequireInfoCount);
  For I := 1 To RequireInfoCount Do
    WriteLn(I:5, '  lib=', RequireInfoTable[I].LibName,
            ' kind=', RequireKindName(RequireInfoTable[I].Kind,
                                      RequireInfoTable[I].Flags),
            ' node=', RequireInfoTable[I].NodeRef:0,
            ' str=', RequireInfoTable[I].StringNode:0,
            ' const=', RequireInfoTable[I].ConstNode:0,
            ' base=', RequireInfoTable[I].BaseDir,
            ' resolved=', RequireInfoTable[I].ResolvedPath,
            ' canon=', RequireInfoTable[I].CanonicalPath,
            ' flags=', RequireInfoTable[I].Flags:0,
            RequireFlagsName(RequireInfoTable[I].Flags));
End;

Procedure DumpBlocks;
Var
  I: Integer;
Begin
  WriteLn('Blocs: ', BlockCount);
  For I := 1 To BlockCount Do
    WriteLn(I:5, '  ', BlockTable[I].LabelName,
            ' kind=', NodeKindName(BlockTable[I].Kind),
            ' params=', BlockTable[I].ParamsNode:0,
            ' body=', BlockTable[I].BodyNode:0,
            ' argc=', BlockTable[I].ParamCount:0,
            ' captures=', BlockTable[I].CaptureCount:0,
            ' flags=', BlockTable[I].Flags:0,
            BlockFlagsName(BlockTable[I].Flags));
End;

Procedure DumpControls;
Var
  I: Integer;
Begin
  WriteLn('Controles: ', ControlCount);
  For I := 1 To ControlCount Do
    WriteLn(I:5, '  kind=', NodeKindName(ControlTable[I].Kind),
            ' node=', ControlTable[I].NodeRef:0,
            ' cond=', ControlTable[I].CondNode:0,
            ' then=', ControlTable[I].ThenNode:0,
            ' else=', ControlTable[I].ElseNode:0,
            ' whens=', ControlTable[I].WhenCount:0,
            ' labels=[', ControlTable[I].ThenLabel, ',',
            ControlTable[I].ElseLabel, ',', ControlTable[I].EndLabel, ']',
            ' flags=', ControlTable[I].Flags:0,
            ControlFlagsName(ControlTable[I].Flags));
End;

Procedure DumpRescues;
Var
  I: Integer;
Begin
  WriteLn('Exceptions: ', RescueInfoCount);
  For I := 1 To RescueInfoCount Do
    WriteLn(I:5, '  node=', RescueInfoTable[I].NodeRef:0,
            ' body=', RescueInfoTable[I].BodyNode:0,
            ' rescues=', RescueInfoTable[I].RescueListNode:0,
            ' handlers=', RescueInfoTable[I].HandlerCount:0,
            ' else=', RescueInfoTable[I].ElseNode:0,
            ' ensure=', RescueInfoTable[I].EnsureNode:0,
            ' current=', RescueInfoTable[I].CurrentExceptionSym:0,
            ' labels=[', RescueInfoTable[I].BeginLabel, ',',
            RescueInfoTable[I].RescueLabel, ',',
            RescueInfoTable[I].ElseLabel, ',',
            RescueInfoTable[I].EnsureLabel, ',',
            RescueInfoTable[I].EndLabel, ']',
            ' flags=', RescueInfoTable[I].Flags:0,
            RescueFlagsName(RescueInfoTable[I].Flags));
End;

Function ItoS(N: LongInt): String;
Var
  S: String;
Begin
  Str(N, S);
  ItoS := S;
End;

Function CountInterpolations(S: String): Integer;
Var
  I, C: Integer;
Begin
  C := 0;
  I := 1;
  While I < Length(S) Do Begin
    If (S[I] = '#') And (S[I + 1] = '{') Then Begin
      Inc(C);
      Inc(I);
    End;
    Inc(I);
  End;
  CountInterpolations := C;
End;

Function StringFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And STRF_FROZEN) <> 0 Then S := S + ' frozen';
  If (F And STRF_MUTABLE) <> 0 Then S := S + ' mutable';
  If (F And STRF_INTERP) <> 0 Then S := S + ' interp';
  If (F And STRF_HEREDOC) <> 0 Then S := S + ' heredoc';
  If (F And STRF_PERCENT) <> 0 Then S := S + ' percent';
  If (F And STRF_UTF8) <> 0 Then S := S + ' utf8';
  StringFlagsName := S;
End;

Function RegexFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And REGF_IGNORECASE) <> 0 Then S := S + ' i';
  If (F And REGF_MULTILINE) <> 0 Then S := S + ' m';
  If (F And REGF_EXTENDED) <> 0 Then S := S + ' x';
  If (F And REGF_ONCE) <> 0 Then S := S + ' o';
  If (F And REGF_UTF8) <> 0 Then S := S + ' u';
  If (F And REGF_PERCENT) <> 0 Then S := S + ' percent';
  RegexFlagsName := S;
End;

Function RangeFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And RANGEF_EXCLUSIVE) <> 0 Then S := S + ' exclusive'
  Else S := S + ' inclusive';
  If (F And RANGEF_BEGINLESS) <> 0 Then S := S + ' beginless';
  If (F And RANGEF_ENDLESS) <> 0 Then S := S + ' endless';
  RangeFlagsName := S;
End;

Function IOFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And IOF_STDIN) <> 0 Then S := S + ' stdin';
  If (F And IOF_STDOUT) <> 0 Then S := S + ' stdout';
  If (F And IOF_STDERR) <> 0 Then S := S + ' stderr';
  If (F And IOF_ARGV) <> 0 Then S := S + ' argv';
  If (F And IOF_ENV) <> 0 Then S := S + ' env';
  If (F And IOF_FILE_CLASS) <> 0 Then S := S + ' file';
  If (F And IOF_DIR_CLASS) <> 0 Then S := S + ' dir';
  If (F And IOF_READABLE) <> 0 Then S := S + ' readable';
  If (F And IOF_WRITABLE) <> 0 Then S := S + ' writable';
  If (F And IOF_MODE) <> 0 Then S := S + ' mode';
  IOFlagsName := S;
End;

Function NumFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And NUMF_FIXNUM) <> 0 Then S := S + ' fixnum';
  If (F And NUMF_BIGNUM) <> 0 Then S := S + ' bignum';
  If (F And NUMF_FLOAT) <> 0 Then S := S + ' float';
  If (F And NUMF_RATIONAL) <> 0 Then S := S + ' rational';
  If (F And NUMF_COMPLEX) <> 0 Then S := S + ' complex';
  If (F And NUMF_BASE2) <> 0 Then S := S + ' base2';
  If (F And NUMF_BASE8) <> 0 Then S := S + ' base8';
  If (F And NUMF_BASE10) <> 0 Then S := S + ' base10';
  If (F And NUMF_BASE16) <> 0 Then S := S + ' base16';
  NumFlagsName := S;
End;

Function NumericBaseFromText(S: String): Integer;
Begin
  NumericBaseFromText := 10;
  If (Length(S) >= 2) And (S[1] = '0') Then Begin
    If UpCase(S[2]) = 'X' Then NumericBaseFromText := 16
    Else If UpCase(S[2]) = 'B' Then NumericBaseFromText := 2
    Else If UpCase(S[2]) = 'O' Then NumericBaseFromText := 8
    Else If (S[2] >= '0') And (S[2] <= '7') Then NumericBaseFromText := 8;
  End;
End;

Function NumericDigitCount(S: String): Integer;
Var
  I, C: Integer;
Begin
  C := 0;
  For I := 1 To Length(S) Do
    If ((S[I] >= '0') And (S[I] <= '9')) Or
       ((S[I] >= 'A') And (S[I] <= 'F')) Or
       ((S[I] >= 'a') And (S[I] <= 'f')) Then Inc(C);
  NumericDigitCount := C;
End;

Function AddNumLit(Text: String; TokKind: Integer): Integer;
Var
  I, F, B, R: Integer;
  Last: Char;
Begin
  For I := 1 To NumLitCount Do
    If NumLitTable[I].Text = Text Then Begin
      AddNumLit := I;
      Exit;
    End;
  If NumLitCount >= MAX_NUM_LIT Then FatalError('table numerique pleine');
  Inc(NumLitCount);
  B := NumericBaseFromText(Text);
  F := 0;
  If B = 2 Then F := F Or NUMF_BASE2
  Else If B = 8 Then F := F Or NUMF_BASE8
  Else If B = 16 Then F := F Or NUMF_BASE16
  Else F := F Or NUMF_BASE10;
  Last := #0;
  If Length(Text) > 0 Then Last := Text[Length(Text)];
  If Last = 'r' Then F := F Or NUMF_RATIONAL;
  If Last = 'i' Then F := F Or NUMF_COMPLEX;
  If TokKind = TOK_FLOAT Then F := F Or NUMF_FLOAT;
  If (F And NUMF_FLOAT) <> 0 Then R := RT_FLOAT
  Else If (F And NUMF_RATIONAL) <> 0 Then R := RT_OBJECT
  Else If (F And NUMF_COMPLEX) <> 0 Then R := RT_OBJECT
  Else R := RT_INTEGER;
  If R = RT_INTEGER Then Begin
    If (B = 10) And (NumericDigitCount(Text) > 9) Then
      F := F Or NUMF_BIGNUM
    Else
      F := F Or NUMF_FIXNUM;
  End;
  NumLitTable[NumLitCount].Text := Text;
  NumLitTable[NumLitCount].AsmName := ASM_PFX_RUNTIME + 'num_' +
                                      ItoS(NumLitCount);
  NumLitTable[NumLitCount].RType := R;
  NumLitTable[NumLitCount].Flags := F;
  NumLitTable[NumLitCount].Base := B;
  AddNumLit := NumLitCount;
End;

Function AddStringLit(Text: String; TokKind: Integer): Integer;
Var
  I, F, Segs: Integer;
Begin
  For I := 1 To StringCount Do
    If (StringTable[I].Text = Text) And
       ((StringTable[I].Flags And STRF_HEREDOC) = 0) And
       (TokKind <> TOK_HEREDOC) Then Begin
      AddStringLit := I;
      Exit;
    End;
  If StringCount >= MAX_STRING_LIT Then FatalError('table des chaines pleine');
  Inc(StringCount);
  F := STRF_UTF8;
  If Opt.FrozenStrLits Or (TokKind = TOK_STRING) Then
    F := F Or STRF_FROZEN
  Else
    F := F Or STRF_MUTABLE;
  If (TokKind = TOK_DSTRING) Or (TokKind = TOK_HEREDOC) Then Begin
    Segs := CountInterpolations(Text);
    If Segs > 0 Then F := F Or STRF_INTERP;
  End Else
    Segs := 0;
  If TokKind = TOK_HEREDOC Then F := F Or STRF_HEREDOC;
  If TokKind = TOK_PERCENT_LIT Then F := F Or STRF_PERCENT;
  StringTable[StringCount].Text := Text;
  StringTable[StringCount].AsmName := ASM_PFX_STRING + ItoS(StringCount);
  StringTable[StringCount].Len := Length(Text);
  StringTable[StringCount].Cap := Length(Text) + 1;
  StringTable[StringCount].Flags := F;
  StringTable[StringCount].SegmentCount := Segs + 1;
  AddStringLit := StringCount;
End;

Function NormalizeSymbolName(S: String): String;
Begin
  If (Length(S) > 0) And (S[1] = ':') Then
    Delete(S, 1, 1);
  NormalizeSymbolName := S;
End;

Function AddSymbolLit(Name: String): Integer;
Var
  I: Integer;
Begin
  Name := NormalizeSymbolName(Name);
  For I := 1 To SymbolLitCount Do
    If SymbolLitTable[I].Name = Name Then Begin
      AddSymbolLit := I;
      Exit;
    End;
  If SymbolLitCount >= MAX_SYMBOL_LIT Then FatalError('table des symboles litteraux pleine');
  Inc(SymbolLitCount);
  SymbolLitTable[SymbolLitCount].Name := Name;
  SymbolLitTable[SymbolLitCount].AsmName := ASM_PFX_SYMBOL + ItoS(SymbolLitCount);
  SymbolLitTable[SymbolLitCount].Value := MakeSymbolValue(SymbolLitCount);
  AddSymbolLit := SymbolLitCount;
End;

Function RegexFlagsFromOptions(Options: String; IsPercent: Boolean): Integer;
Var
  I, F: Integer;
  C: Char;
Begin
  F := 0;
  For I := 1 To Length(Options) Do Begin
    C := Options[I];
    If C = 'i' Then F := F Or REGF_IGNORECASE
    Else If C = 'm' Then F := F Or REGF_MULTILINE
    Else If C = 'x' Then F := F Or REGF_EXTENDED
    Else If C = 'o' Then F := F Or REGF_ONCE
    Else If C = 'u' Then F := F Or REGF_UTF8;
  End;
  If IsPercent Then F := F Or REGF_PERCENT;
  RegexFlagsFromOptions := F;
End;

Function CountRegexCaptures(Pattern: String): Integer;
Var
  I, C: Integer;
Begin
  C := 0;
  I := 1;
  While I <= Length(Pattern) Do Begin
    If Pattern[I] = '\' Then Inc(I)
    Else If Pattern[I] = '(' Then Begin
      If (I + 2 <= Length(Pattern)) And (Pattern[I + 1] = '?') And
         (Pattern[I + 2] = '<') Then
        Inc(C)
      Else If (I < Length(Pattern)) And (Pattern[I + 1] = '?') Then Begin
      End Else
        Inc(C);
    End;
    Inc(I);
  End;
  CountRegexCaptures := C;
End;

Function RegexMatchingDelim(C: Char): Char;
Begin
  Case C Of
    '(': RegexMatchingDelim := ')';
    '[': RegexMatchingDelim := ']';
    '{': RegexMatchingDelim := '}';
    '<': RegexMatchingDelim := '>';
  Else
    RegexMatchingDelim := C;
  End;
End;

Function IsRegexOptionChar(C: Char): Boolean;
Begin
  IsRegexOptionChar := ((C >= 'A') And (C <= 'Z')) Or
                       ((C >= 'a') And (C <= 'z'));
End;

Procedure SplitRegexToken(TokenText: String; Var Pattern, Options: String;
                          Var IsPercent: Boolean);
Var
  I, J, Depth: Integer;
  OpenD, CloseD, C: Char;
Begin
  Pattern := TokenText;
  Options := '';
  IsPercent := False;
  If (Length(TokenText) >= 3) And (TokenText[1] = '%') And
     ((TokenText[2] = 'r') Or (TokenText[2] = 'R')) Then Begin
    IsPercent := True;
    OpenD := TokenText[3];
    CloseD := RegexMatchingDelim(OpenD);
    I := 4;
    J := I;
    Depth := 1;
    While (J <= Length(TokenText)) And (Depth > 0) Do Begin
      C := TokenText[J];
      If C = '\' Then Inc(J)
      Else If C = OpenD Then Inc(Depth)
      Else If C = CloseD Then Dec(Depth);
      Inc(J);
    End;
    Pattern := Copy(TokenText, I, J - I - 1);
    Options := Copy(TokenText, J, Length(TokenText) - J + 1);
  End Else If (Length(TokenText) >= 2) And (TokenText[1] = '/') Then Begin
    I := Length(TokenText);
    While (I >= 1) And IsRegexOptionChar(TokenText[I]) Do Dec(I);
    If (I >= 2) And (TokenText[I] = '/') Then Begin
      Pattern := Copy(TokenText, 2, I - 2);
      Options := Copy(TokenText, I + 1, Length(TokenText) - I);
    End;
  End Else Begin
    I := Length(TokenText);
    While (I >= 1) And IsRegexOptionChar(TokenText[I]) Do Dec(I);
    Pattern := Copy(TokenText, 1, I);
    Options := Copy(TokenText, I + 1, Length(TokenText) - I);
  End;
End;

Function AddRegexLit(TokenText: String): Integer;
Var
  I, F, Caps: Integer;
  Pattern, Options: String;
  IsPercent: Boolean;
Begin
  SplitRegexToken(TokenText, Pattern, Options, IsPercent);
  F := RegexFlagsFromOptions(Options, IsPercent);
  Caps := CountRegexCaptures(Pattern);
  For I := 1 To RegexLitCount Do
    If (RegexLitTable[I].Pattern = Pattern) And
       (RegexLitTable[I].Options = Options) Then Begin
      AddRegexLit := I;
      Exit;
    End;
  If RegexLitCount >= MAX_REGEX_LIT Then FatalError('table des regex pleine');
  Inc(RegexLitCount);
  RegexLitTable[RegexLitCount].Pattern := Pattern;
  RegexLitTable[RegexLitCount].Options := Options;
  RegexLitTable[RegexLitCount].AsmName := ASM_PFX_REGEX + ItoS(RegexLitCount);
  RegexLitTable[RegexLitCount].Flags := F;
  RegexLitTable[RegexLitCount].CaptureCount := Caps;
  AddRegexLit := RegexLitCount;
End;

Function AddRangeLit(BeginNode, EndNode, Flags: Integer): Integer;
Var
  I: Integer;
Begin
  For I := 1 To RangeLitCount Do
    If (RangeLitTable[I].BeginNode = BeginNode) And
       (RangeLitTable[I].EndNode = EndNode) And
       (RangeLitTable[I].Flags = Flags) Then Begin
      AddRangeLit := I;
      Exit;
    End;
  If RangeLitCount >= MAX_RANGE_LIT Then FatalError('table des ranges pleine');
  Inc(RangeLitCount);
  RangeLitTable[RangeLitCount].AsmName := ASM_PFX_RUNTIME + 'range_' +
                                         ItoS(RangeLitCount);
  RangeLitTable[RangeLitCount].BeginNode := BeginNode;
  RangeLitTable[RangeLitCount].EndNode := EndNode;
  RangeLitTable[RangeLitCount].Flags := Flags;
  AddRangeLit := RangeLitCount;
End;

Function CountNodeChildren(FirstNode: Integer): Integer;
Var
  C, N: Integer;
Begin
  C := 0;
  N := FirstNode;
  While N <> 0 Do Begin
    Inc(C);
    N := AstTable[N].NextSibling;
  End;
  CountNodeChildren := C;
End;

Function AddArrayLit(ArrayNode: Integer): Integer;
Var
  C, F, N: Integer;
Begin
  If ArrayLitCount >= MAX_ARRAY_LIT Then FatalError('table des arrays litteraux pleine');
  Inc(ArrayLitCount);
  F := 0;
  N := AstTable[ArrayNode].FirstChild;
  While N <> 0 Do Begin
    If AstTable[N].Kind = NK_SPLAT Then F := F Or ARRF_HAS_SPLAT;
    N := AstTable[N].NextSibling;
  End;
  C := CountNodeChildren(AstTable[ArrayNode].FirstChild);
  ArrayLitTable[ArrayLitCount].AsmName := ASM_PFX_ARRAY + ItoS(ArrayLitCount);
  ArrayLitTable[ArrayLitCount].Count := C;
  ArrayLitTable[ArrayLitCount].Cap := C;
  If ArrayLitTable[ArrayLitCount].Cap = 0 Then ArrayLitTable[ArrayLitCount].Cap := 4;
  ArrayLitTable[ArrayLitCount].FirstNode := AstTable[ArrayNode].FirstChild;
  ArrayLitTable[ArrayLitCount].Flags := F;
  AddArrayLit := ArrayLitCount;
End;

Function AddHashLit(HashNode: Integer): Integer;
Var
  C, F, N: Integer;
Begin
  If HashLitCount >= MAX_HASH_LIT Then FatalError('table des hash litteraux pleine');
  Inc(HashLitCount);
  F := 0;
  N := AstTable[HashNode].FirstChild;
  While N <> 0 Do Begin
    If AstTable[N].Kind = NK_KW_SPLAT Then F := F Or HASHF_HAS_KW_SPLAT;
    N := AstTable[N].NextSibling;
  End;
  C := CountNodeChildren(AstTable[HashNode].FirstChild);
  HashLitTable[HashLitCount].AsmName := ASM_PFX_HASH + ItoS(HashLitCount);
  HashLitTable[HashLitCount].Count := C;
  HashLitTable[HashLitCount].Cap := C * 2;
  If HashLitTable[HashLitCount].Cap = 0 Then HashLitTable[HashLitCount].Cap := 8;
  HashLitTable[HashLitCount].FirstPair := AstTable[HashNode].FirstChild;
  HashLitTable[HashLitCount].Flags := F;
  AddHashLit := HashLitCount;
End;

Function BlockFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And BLOCKF_PROC) <> 0 Then S := S + ' proc';
  If (F And BLOCKF_LAMBDA) <> 0 Then S := S + ' lambda';
  If (F And BLOCKF_DO_END) <> 0 Then S := S + ' do-end';
  If (F And BLOCKF_HAS_PARAMS) <> 0 Then S := S + ' params';
  BlockFlagsName := S;
End;

Function AddBlockInfo(Kind, ParamsNode, BodyNode, Flags: Integer): Integer;
Begin
  If BlockCount >= MAX_BLOCK Then FatalError('table des blocs pleine');
  Inc(BlockCount);
  BlockTable[BlockCount].Kind := Kind;
  BlockTable[BlockCount].ParamsNode := ParamsNode;
  BlockTable[BlockCount].BodyNode := BodyNode;
  BlockTable[BlockCount].ParamCount := CountNodeChildren(AstTable[ParamsNode].FirstChild);
  BlockTable[BlockCount].CaptureCount := 0;
  BlockTable[BlockCount].LabelName := ASM_PFX_LABEL + 'BLK_' + ItoS(BlockCount);
  BlockTable[BlockCount].Flags := Flags;
  AddBlockInfo := BlockCount;
End;

Function ControlFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And CTRLF_UNLESS) <> 0 Then S := S + ' unless';
  If (F And CTRLF_MODIFIER) <> 0 Then S := S + ' modifier';
  If (F And CTRLF_TERNARY) <> 0 Then S := S + ' ternary';
  If (F And CTRLF_SHORT_CIRCUIT) <> 0 Then S := S + ' short-circuit';
  If (F And CTRLF_CASE) <> 0 Then S := S + ' case';
  If (F And CTRLF_PATTERN) <> 0 Then S := S + ' pattern';
  If (F And CTRLF_LOOP) <> 0 Then S := S + ' loop';
  If (F And CTRLF_WHILE) <> 0 Then S := S + ' while';
  If (F And CTRLF_UNTIL) <> 0 Then S := S + ' until';
  If (F And CTRLF_FOR) <> 0 Then S := S + ' for';
  If (F And CTRLF_LOOP_BLOCK) <> 0 Then S := S + ' loop-block';
  If (F And CTRLF_ITERATOR) <> 0 Then S := S + ' iterator';
  If (F And CTRLF_POST_TEST) <> 0 Then S := S + ' post-test';
  ControlFlagsName := S;
End;

Function RescueFlagsName(F: Integer): String;
Var
  S: String;
Begin
  S := '';
  If (F And RESCF_HAS_RESCUE) <> 0 Then S := S + ' rescue';
  If (F And RESCF_HAS_ELSE) <> 0 Then S := S + ' else';
  If (F And RESCF_HAS_ENSURE) <> 0 Then S := S + ' ensure';
  If (F And RESCF_MODIFIER) <> 0 Then S := S + ' modifier';
  If (F And RESCF_DEFAULT) <> 0 Then S := S + ' default';
  RescueFlagsName := S;
End;

Function CountCaseWhens(BodyNode: Integer): Integer;
Var
  C, N: Integer;
Begin
  C := 0;
  If BodyNode <> 0 Then Begin
    N := AstTable[BodyNode].FirstChild;
    While N <> 0 Do Begin
      If AstTable[N].Kind = NK_WHEN Then Inc(C);
      N := AstTable[N].NextSibling;
    End;
  End;
  CountCaseWhens := C;
End;

Function CaseHasPattern(BodyNode: Integer): Boolean;
Var
  N: Integer;
Begin
  CaseHasPattern := False;
  If BodyNode = 0 Then Exit;
  N := AstTable[BodyNode].FirstChild;
  While N <> 0 Do Begin
    If (AstTable[N].Kind = NK_WHEN) And (AstTable[N].Tok = KW_IN) Then Begin
      CaseHasPattern := True;
      Exit;
    End;
    N := AstTable[N].NextSibling;
  End;
End;

Function AddControlInfo(NodeRef, Kind, CondNode, ThenNode, ElseNode,
                        Flags: Integer): Integer;
Begin
  If ControlCount >= MAX_CONTROL Then FatalError('table des controles pleine');
  Inc(ControlCount);
  ControlTable[ControlCount].NodeRef := NodeRef;
  ControlTable[ControlCount].Kind := Kind;
  ControlTable[ControlCount].CondNode := CondNode;
  ControlTable[ControlCount].ThenNode := ThenNode;
  ControlTable[ControlCount].ElseNode := ElseNode;
  If (Flags And CTRLF_LOOP) <> 0 Then Begin
    ControlTable[ControlCount].ThenLabel := ASM_PFX_LABEL + 'CTL_' +
                                            ItoS(ControlCount) + '_START';
    ControlTable[ControlCount].ElseLabel := ASM_PFX_LABEL + 'CTL_' +
                                            ItoS(ControlCount) + '_NEXT';
  End Else Begin
    ControlTable[ControlCount].ThenLabel := ASM_PFX_LABEL + 'CTL_' +
                                            ItoS(ControlCount) + '_THEN';
    ControlTable[ControlCount].ElseLabel := ASM_PFX_LABEL + 'CTL_' +
                                            ItoS(ControlCount) + '_ELSE';
  End;
  ControlTable[ControlCount].EndLabel := ASM_PFX_LABEL + 'CTL_' +
                                         ItoS(ControlCount) + '_END';
  If Kind = NK_CASE Then ControlTable[ControlCount].WhenCount := CountCaseWhens(ThenNode)
  Else ControlTable[ControlCount].WhenCount := 0;
  ControlTable[ControlCount].Flags := Flags;
  AddControlInfo := ControlCount;
End;

Procedure PushLoop(ControlRef: Integer);
Begin
  If LoopDepth >= MAX_CONTROL Then FatalError('pile de boucles pleine');
  Inc(LoopDepth);
  LoopStack[LoopDepth] := ControlRef;
End;

Procedure PopLoop;
Begin
  If LoopDepth > 0 Then Dec(LoopDepth);
End;

Function CurrentLoopControl: Integer;
Begin
  If LoopDepth <= 0 Then CurrentLoopControl := 0
  Else CurrentLoopControl := LoopStack[LoopDepth];
End;

Function CountRescueHandlers(RescueListNode: Integer): Integer;
Begin
  If RescueListNode = 0 Then CountRescueHandlers := 0
  Else CountRescueHandlers :=
    CountNodeChildren(AstTable[RescueListNode].FirstChild);
End;

Function AddRescueInfo(NodeRef, BodyNode, RescueListNode, ElseNode,
                       EnsureNode, Flags: Integer): Integer;
Begin
  If RescueInfoCount >= MAX_RESCUE Then FatalError('table des exceptions pleine');
  Inc(RescueInfoCount);
  RescueInfoTable[RescueInfoCount].NodeRef := NodeRef;
  RescueInfoTable[RescueInfoCount].BodyNode := BodyNode;
  RescueInfoTable[RescueInfoCount].RescueListNode := RescueListNode;
  RescueInfoTable[RescueInfoCount].ElseNode := ElseNode;
  RescueInfoTable[RescueInfoCount].EnsureNode := EnsureNode;
  RescueInfoTable[RescueInfoCount].CurrentExceptionSym := ResolveGlobal('$!');
  RescueInfoTable[RescueInfoCount].HandlerCount :=
    CountRescueHandlers(RescueListNode);
  RescueInfoTable[RescueInfoCount].BeginLabel := ASM_PFX_LABEL + 'RESC_' +
                                                ItoS(RescueInfoCount) + '_BEGIN';
  RescueInfoTable[RescueInfoCount].RescueLabel := ASM_PFX_LABEL + 'RESC_' +
                                                 ItoS(RescueInfoCount) + '_HANDLER';
  RescueInfoTable[RescueInfoCount].ElseLabel := ASM_PFX_LABEL + 'RESC_' +
                                               ItoS(RescueInfoCount) + '_ELSE';
  RescueInfoTable[RescueInfoCount].EnsureLabel := ASM_PFX_LABEL + 'RESC_' +
                                                 ItoS(RescueInfoCount) + '_ENSURE';
  RescueInfoTable[RescueInfoCount].EndLabel := ASM_PFX_LABEL + 'RESC_' +
                                              ItoS(RescueInfoCount) + '_END';
  RescueInfoTable[RescueInfoCount].Flags := Flags;
  AddRescueInfo := RescueInfoCount;
End;

Procedure UpdateRescueInfo(RescueRef, NodeRef, BodyNode, RescueListNode,
                           ElseNode, EnsureNode, Flags: Integer);
Begin
  If (RescueRef <= 0) Or (RescueRef > RescueInfoCount) Then Exit;
  RescueInfoTable[RescueRef].NodeRef := NodeRef;
  RescueInfoTable[RescueRef].BodyNode := BodyNode;
  RescueInfoTable[RescueRef].RescueListNode := RescueListNode;
  RescueInfoTable[RescueRef].ElseNode := ElseNode;
  RescueInfoTable[RescueRef].EnsureNode := EnsureNode;
  RescueInfoTable[RescueRef].HandlerCount :=
    CountRescueHandlers(RescueListNode);
  RescueInfoTable[RescueRef].Flags := Flags;
End;

Procedure PushRescue(RescueRef: Integer);
Begin
  If RescueDepth >= MAX_RESCUE Then FatalError('pile des exceptions pleine');
  Inc(RescueDepth);
  RescueStack[RescueDepth] := RescueRef;
End;

Procedure PopRescue;
Begin
  If RescueDepth > 0 Then Dec(RescueDepth);
End;

Function CurrentRescueControl: Integer;
Begin
  If RescueDepth <= 0 Then CurrentRescueControl := 0
  Else CurrentRescueControl := RescueStack[RescueDepth];
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
  CurTokContext := CTX_NONE;
  LastTokenType := TOK_EOF;
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
  K: Integer;
Begin
  First := LexPeekChar;
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
  If (LexPeekChar = '?') Or (LexPeekChar = '!') Or (LexPeekChar = '=') Then
    AppendTok(LexNextChar);
  K := IsKeyword(CurTokStr);
  If K <> 0 Then
    CurTokType := K
  Else If (First >= 'A') And (First <= 'Z') Then
    CurTokType := TOK_CONST
  Else
    CurTokType := TOK_IDENT;
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
  If (LexPeekChar = '~') Or (LexPeekChar = '!') Or (LexPeekChar = '`') Or
     (LexPeekChar = '&') Or (LexPeekChar = ':') Or (LexPeekChar = '"') Or
     (Ord(LexPeekChar) = 39) Then Begin
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
  InClass: Boolean;
Begin
  CurTokType := TOK_REGEX;
  AppendTok(LexNextChar);
  InClass := False;
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('regex non terminee');
    If (C = '/') And Not InClass Then Begin
      AppendTok(C);
      Break;
    End;
    If C = '\' Then Begin
      AppendTok(C);
      C := LexNextChar;
      If C = #0 Then FatalError('regex non terminee');
    End Else If C = '[' Then
      InClass := True
    Else If C = ']' Then
      InClass := False;
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
  While IsAlpha(LexPeekChar) Do AppendTok(LexNextChar);
  If (Kind = 'r') Or (Kind = 'R') Then CurTokType := TOK_REGEX;
End;

Function TryReadHeredoc: Boolean;
Var
  SavePos, SaveLine, SaveCol: LongInt;
  C, Quote: Char;
  Delim, Line, CheckLine: String;
  AllowIndent: Boolean;

  Function LTrimSpaces(S: String): String;
  Begin
    While (Length(S) > 0) And ((S[1] = ' ') Or (S[1] = #9)) Do
      Delete(S, 1, 1);
    LTrimSpaces := S;
  End;

  Procedure AppendBody(S: String);
  Var
    I: Integer;
  Begin
    For I := 1 To Length(S) Do
      AppendTok(S[I]);
  End;
Begin
  TryReadHeredoc := False;
  SavePos := LexPos;
  SaveLine := LexLine;
  SaveCol := LexCol;
  CurTokStr := '';
  Delim := '';
  AllowIndent := False;
  LexNextChar;
  LexNextChar;
  If (LexPeekChar = '-') Or (LexPeekChar = '~') Then Begin
    AllowIndent := True;
    LexNextChar;
  End;
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
  While IsIdentChar(LexPeekChar) Do Begin
    C := LexNextChar;
    If Length(Delim) < 255 Then Delim := Delim + C;
  End;
  If Quote <> #0 Then Begin
    C := LexNextChar;
    If C <> Quote Then FatalError('delimiteur heredoc invalide');
  End;
  While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do LexNextChar;
  If LexPeekChar = #10 Then LexNextChar;
  CurTokStr := '';
  While True Do Begin
    Line := '';
    While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do Begin
      C := LexNextChar;
      If (C <> #13) And (Length(Line) < 255) Then Line := Line + C;
    End;
    CheckLine := Line;
    If AllowIndent Then CheckLine := LTrimSpaces(CheckLine);
    If CheckLine = Delim Then Begin
      If LexPeekChar = #10 Then LexNextChar;
      Break;
    End;
    AppendBody(Line);
    If LexPeekChar = #10 Then Begin
      AppendTok(#10);
      LexNextChar;
    End Else If LexPeekChar = #0 Then
      FatalError('heredoc non termine');
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
                     (T = TOK_STRING) Or (T = TOK_DSTRING) Or (T = TOK_HEREDOC) Or
                     (T = TOK_SYMBOL) Or (T = TOK_REGEX) Or
                     (T = TOK_PERCENT_LIT) Or (T = Ord(')')) Or
                     (T = Ord(']')) Or (T = Ord('}')) Or
                     IsKeywordLiteral(T);
End;

Procedure LexNextToken;
Var
  C, C2, C3: Char;
  Done: Boolean;
  PrevCanEndExpr: Boolean;
  PrevTokenType: Integer;
Begin
  CurTokStr := '';
  CurTokNum := 0;
  CurTokContext := CTX_NONE;
  PrevCanEndExpr := LastTokenCanEndExpr;
  PrevTokenType := LastTokenType;
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
    End Else If IsAlpha(C2) Or (C2 = '"') Or (C2 = '''') Or
                (C2 = '+') Or (C2 = '-') Or (C2 = '*') Or
                (C2 = '/') Or (C2 = '%') Or (C2 = '<') Or
                (C2 = '>') Or (C2 = '=') Or (C2 = '!') Then
      ReadSymbol
    Else
      SetSingleToken(Ord(':'));
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
              (LastTokenType <> KW_CLASS) And
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

  If IsModifierKeyword(CurTokType) Then Begin
    If PrevCanEndExpr Then CurTokContext := CTX_MODIFIER
    Else CurTokContext := CTX_PREFIX;
  End Else If CurTokType = KW_DO Then Begin
    If PrevCanEndExpr Then CurTokContext := CTX_DO_AFTER_EXPR
    Else CurTokContext := CTX_DO_BEGIN;
  End Else If CurTokType = Ord('{') Then Begin
    If PrevCanEndExpr Or (PrevTokenType = KW_BEGIN_UP) Or
       (PrevTokenType = KW_END_UP) Then CurTokContext := CTX_BLOCK_BRACE
    Else CurTokContext := CTX_HASH_BRACE;
  End;

  LastTokenType := CurTokType;
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
    KW_ALIAS: TokenName := 'KW_ALIAS';
    KW_AND: TokenName := 'KW_AND';
    KW_BEGIN_UP: TokenName := 'KW_BEGIN_UP';
    KW_BEGIN: TokenName := 'KW_BEGIN';
    KW_BREAK: TokenName := 'KW_BREAK';
    KW_CASE: TokenName := 'KW_CASE';
    KW_CLASS: TokenName := 'KW_CLASS';
    KW_DEF: TokenName := 'KW_DEF';
    KW_DEFINED: TokenName := 'KW_DEFINED';
    KW_DO: TokenName := 'KW_DO';
    KW_ELSE: TokenName := 'KW_ELSE';
    KW_ELSIF: TokenName := 'KW_ELSIF';
    KW_END_UP: TokenName := 'KW_END_UP';
    KW_END: TokenName := 'KW_END';
    KW_ENSURE: TokenName := 'KW_ENSURE';
    KW_FALSE: TokenName := 'KW_FALSE';
    KW_FOR: TokenName := 'KW_FOR';
    KW_IF: TokenName := 'KW_IF';
    KW_IN: TokenName := 'KW_IN';
    KW_MODULE: TokenName := 'KW_MODULE';
    KW_NEXT: TokenName := 'KW_NEXT';
    KW_NIL: TokenName := 'KW_NIL';
    KW_NOT: TokenName := 'KW_NOT';
    KW_OR: TokenName := 'KW_OR';
    KW_REDO: TokenName := 'KW_REDO';
    KW_RESCUE: TokenName := 'KW_RESCUE';
    KW_RETRY: TokenName := 'KW_RETRY';
    KW_RETURN: TokenName := 'KW_RETURN';
    KW_SELF: TokenName := 'KW_SELF';
    KW_SUPER: TokenName := 'KW_SUPER';
    KW_THEN: TokenName := 'KW_THEN';
    KW_TRUE: TokenName := 'KW_TRUE';
    KW_UNDEF: TokenName := 'KW_UNDEF';
    KW_UNLESS: TokenName := 'KW_UNLESS';
    KW_UNTIL: TokenName := 'KW_UNTIL';
    KW_WHEN: TokenName := 'KW_WHEN';
    KW_WHILE: TokenName := 'KW_WHILE';
    KW_YIELD: TokenName := 'KW_YIELD';
    KW_FILE: TokenName := 'KW_FILE';
    KW_LINE: TokenName := 'KW_LINE';
    KW_ENCODING: TokenName := 'KW_ENCODING';
    KW_ATTR_ACCESSOR: TokenName := 'KW_ATTR_ACCESSOR';
    KW_ATTR_READER: TokenName := 'KW_ATTR_READER';
    KW_ATTR_WRITER: TokenName := 'KW_ATTR_WRITER';
    KW_PRIVATE: TokenName := 'KW_PRIVATE';
    KW_PUBLIC: TokenName := 'KW_PUBLIC';
    KW_PROTECTED: TokenName := 'KW_PROTECTED';
    KW_RAISE: TokenName := 'KW_RAISE';
    KW_REQUIRE: TokenName := 'KW_REQUIRE';
    KW_REQUIRE_RELATIVE: TokenName := 'KW_REQUIRE_RELATIVE';
    KW_LOAD: TokenName := 'KW_LOAD';
    KW_INCLUDE: TokenName := 'KW_INCLUDE';
    KW_EXTEND: TokenName := 'KW_EXTEND';
    KW_PREPEND: TokenName := 'KW_PREPEND';
    KW_MODULE_FUNCTION: TokenName := 'KW_MODULE_FUNCTION';
    KW_PROC: TokenName := 'KW_PROC';
    KW_LAMBDA: TokenName := 'KW_LAMBDA';
    KW_LOOP: TokenName := 'KW_LOOP';
    KW_TIMES: TokenName := 'KW_TIMES';
    KW_EACH: TokenName := 'KW_EACH';
    KW_MAP: TokenName := 'KW_MAP';
    KW_SELECT: TokenName := 'KW_SELECT';
    KW_REJECT: TokenName := 'KW_REJECT';
    KW_INJECT: TokenName := 'KW_INJECT';
    KW_REDUCE: TokenName := 'KW_REDUCE';
    KW_PUTS: TokenName := 'KW_PUTS';
    KW_PRINT: TokenName := 'KW_PRINT';
    KW_P: TokenName := 'KW_P';
    KW_PP: TokenName := 'KW_PP';
    KW_GETS: TokenName := 'KW_GETS';
    KW_GETC: TokenName := 'KW_GETC';
    KW_PRINTF: TokenName := 'KW_PRINTF';
    KW_SPRINTF: TokenName := 'KW_SPRINTF';
    KW_FORMAT: TokenName := 'KW_FORMAT';
    KW_READLINE: TokenName := 'KW_READLINE';
    KW_READLINES: TokenName := 'KW_READLINES';
  Else
    If (T > 0) And (T < 128) Then TokenName := '''' + Chr(T) + ''''
    Else TokenName := 'TOK_' + UpCaseStr(ItoS(T));
  End;
End;

Function ParseExpr: Integer; Forward;
Function ParseStatementList(End1, End2, End3: Integer): Integer; Forward;
Function ParseBlockLiteral(BlockKind, StartTok: Integer): Integer; Forward;
Function ParseLambdaArrow: Integer; Forward;
Function NodeMethodName(N: Integer): String; Forward;
Function IsIteratorMethodName(S: String): Boolean; Forward;
Function ParseConditionExpr: Integer; Forward;

Function NodeKindName(K: Integer): String;
Begin
  Case K Of
    NK_LITERAL: NodeKindName := 'literal';
    NK_VAR: NodeKindName := 'var';
    NK_CONST: NodeKindName := 'const';
    NK_UNARY: NodeKindName := 'unary';
    NK_BINARY: NodeKindName := 'binary';
    NK_ASSIGN: NodeKindName := 'assign';
    NK_TERNARY: NodeKindName := 'ternary';
    NK_RANGE: NodeKindName := 'range';
    NK_CALL: NodeKindName := 'call';
    NK_INDEX: NodeKindName := 'index';
    NK_ARRAY: NodeKindName := 'array';
    NK_HASH: NodeKindName := 'hash';
    NK_PAIR: NodeKindName := 'pair';
    NK_LIST: NodeKindName := 'list';
    NK_SPLAT: NodeKindName := 'splat';
    NK_KW_SPLAT: NodeKindName := 'kw-splat';
    NK_STMT_LIST: NodeKindName := 'stmt-list';
    NK_IF: NodeKindName := 'if';
    NK_UNLESS: NodeKindName := 'unless';
    NK_WHILE: NodeKindName := 'while';
    NK_UNTIL: NodeKindName := 'until';
    NK_FOR: NodeKindName := 'for';
    NK_CASE: NodeKindName := 'case';
    NK_WHEN: NodeKindName := 'when';
    NK_BEGIN: NodeKindName := 'begin';
    NK_RESCUE: NodeKindName := 'rescue';
    NK_ENSURE: NodeKindName := 'ensure';
    NK_DEF: NodeKindName := 'def';
    NK_CLASS: NodeKindName := 'class';
    NK_MODULE: NodeKindName := 'module';
    NK_RETURN: NodeKindName := 'return';
    NK_BREAK: NodeKindName := 'break';
    NK_NEXT: NodeKindName := 'next';
    NK_REDO: NodeKindName := 'redo';
    NK_RETRY: NodeKindName := 'retry';
    NK_YIELD: NodeKindName := 'yield';
    NK_RAISE: NodeKindName := 'raise';
    NK_ALIAS: NodeKindName := 'alias';
    NK_UNDEF: NodeKindName := 'undef';
    NK_BEGIN_HOOK: NodeKindName := 'BEGIN';
    NK_END_HOOK: NodeKindName := 'END';
    NK_REQUIRE: NodeKindName := 'require';
    NK_EMPTY: NodeKindName := 'empty';
    NK_VISIBILITY: NodeKindName := 'visibility';
    NK_PARAM: NodeKindName := 'param';
    NK_PARAM_DEFAULT: NodeKindName := 'param-default';
    NK_PARAM_SPLAT: NodeKindName := 'param-splat';
    NK_PARAM_KEY: NodeKindName := 'param-key';
    NK_PARAM_KW_SPLAT: NodeKindName := 'param-kw-splat';
    NK_PARAM_BLOCK: NodeKindName := 'param-block';
    NK_MIXIN: NodeKindName := 'mixin';
    NK_MODULE_FUNCTION: NodeKindName := 'module-function';
    NK_SUPER: NodeKindName := 'super';
    NK_STRING: NodeKindName := 'string';
    NK_SYMBOL: NodeKindName := 'symbol';
    NK_BLOCK: NodeKindName := 'block';
    NK_PROC: NodeKindName := 'proc';
    NK_LAMBDA: NodeKindName := 'lambda';
    NK_REGEX: NodeKindName := 'regex';
  Else
    NodeKindName := 'none';
  End;
End;

Procedure InitAST;
Begin
  FillChar(AstTable, SizeOf(AstTable), 0);
  FillChar(StringTable, SizeOf(StringTable), 0);
  FillChar(SymbolLitTable, SizeOf(SymbolLitTable), 0);
  FillChar(RegexLitTable, SizeOf(RegexLitTable), 0);
  FillChar(RangeLitTable, SizeOf(RangeLitTable), 0);
  FillChar(NumLitTable, SizeOf(NumLitTable), 0);
  FillChar(ArrayLitTable, SizeOf(ArrayLitTable), 0);
  FillChar(HashLitTable, SizeOf(HashLitTable), 0);
  FillChar(BlockTable, SizeOf(BlockTable), 0);
  FillChar(ControlTable, SizeOf(ControlTable), 0);
  FillChar(RescueInfoTable, SizeOf(RescueInfoTable), 0);
  AstCount := 0;
  StringCount := 0;
  SymbolLitCount := 0;
  RegexLitCount := 0;
  RangeLitCount := 0;
  NumLitCount := 0;
  ArrayLitCount := 0;
  HashLitCount := 0;
  BlockCount := 0;
  ControlCount := 0;
  LoopDepth := 0;
  RescueInfoCount := 0;
  RescueDepth := 0;
  ParseErrors := 0;
  ParseAllowCommaList := True;
  ParseAllowDoBlock := True;
End;

Function NewASTNode(Kind, Tok: Integer; Text: String; Left, Right, Third: Integer): Integer;
Begin
  If AstCount >= MAX_AST Then FatalError('arbre d expressions trop grand');
  Inc(AstCount);
  AstTable[AstCount].Kind := Kind;
  AstTable[AstCount].Tok := Tok;
  AstTable[AstCount].Text := Text;
  AstTable[AstCount].Left := Left;
  AstTable[AstCount].Right := Right;
  AstTable[AstCount].Third := Third;
  AstTable[AstCount].FirstChild := 0;
  AstTable[AstCount].NextSibling := 0;
  AstTable[AstCount].SymRef := 0;
  NewASTNode := AstCount;
End;

Procedure AddChild(Parent, Child: Integer);
Var
  N: Integer;
Begin
  If (Parent = 0) Or (Child = 0) Then Exit;
  If AstTable[Parent].FirstChild = 0 Then
    AstTable[Parent].FirstChild := Child
  Else Begin
    N := AstTable[Parent].FirstChild;
    While AstTable[N].NextSibling <> 0 Do N := AstTable[N].NextSibling;
    AstTable[N].NextSibling := Child;
  End;
End;

Procedure ParseError(Msg: String);
Begin
  Inc(ParseErrors);
  WriteLn('RUBYCW32: parse: ', CurTokLine, ':', CurTokCol, ': ', Msg);
End;

Procedure NextTok;
Begin
  LexNextToken;
End;

Function IsExprEnd(T: Integer): Boolean;
Begin
  IsExprEnd := (T = TOK_EOF) Or (T = TOK_NEWLINE) Or (T = Ord(';')) Or
               (T = Ord(')')) Or (T = Ord(']')) Or (T = Ord('}')) Or
               (T = KW_END) Or (T = KW_ELSE) Or (T = KW_ELSIF) Or
               (T = KW_WHEN) Or (T = KW_RESCUE) Or (T = KW_ENSURE) Or
               (T = KW_THEN) Or (T = KW_DO);
End;

Procedure SkipExprNewlines;
Begin
  While CurTokType = TOK_NEWLINE Do NextTok;
End;

Function IsAssignTok(T: Integer): Boolean;
Begin
  IsAssignTok := (T = Ord('=')) Or (T = TOK_ASSIGN_OP);
End;

Function ParseListUntil(EndTok: Integer): Integer;
Var
  L, E: Integer;
  OldComma: Boolean;
Begin
  L := NewASTNode(NK_LIST, 0, '', 0, 0, 0);
  SkipExprNewlines;
  OldComma := ParseAllowCommaList;
  ParseAllowCommaList := False;
  While (CurTokType <> EndTok) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = Ord('*') Then Begin
      NextTok;
      E := NewASTNode(NK_SPLAT, Ord('*'), '*', ParseExpr, 0, 0);
    End Else If CurTokType = TOK_POW Then Begin
      NextTok;
      E := NewASTNode(NK_KW_SPLAT, TOK_POW, '**', ParseExpr, 0, 0);
    End Else
      E := ParseExpr;
    AddChild(L, E);
    SkipExprNewlines;
    If CurTokType = Ord(',') Then Begin
      NextTok;
      SkipExprNewlines;
    End Else
      Break;
  End;
  If CurTokType = EndTok Then NextTok
  Else ParseError('separateur fermant attendu: ' + TokenName(EndTok));
  ParseAllowCommaList := OldComma;
  ParseListUntil := L;
End;

Function IsCallArgStart(T: Integer): Boolean; Forward;
Function ParseBareArgList: Integer; Forward;

Function ParsePrimary: Integer;
Var
  N, K, Key, Val, Args, Tok: Integer;
  T, S: String;
  OldComma: Boolean;
Begin
  ParsePrimary := 0;
  SkipExprNewlines;
  If (CurTokType = KW_PROC) Or (CurTokType = KW_LAMBDA) Then Begin
    Tok := CurTokType;
    S := CurTokStr;
    NextTok;
    If (CurTokType = Ord('{')) Or (CurTokType = KW_DO) Then Begin
      If Tok = KW_PROC Then
        ParsePrimary := ParseBlockLiteral(NK_PROC, CurTokType)
      Else
        ParsePrimary := ParseBlockLiteral(NK_LAMBDA, CurTokType);
    End Else Begin
      N := NewASTNode(NK_VAR, Tok, S, 0, 0, 0);
      AstTable[N].SymRef := AddSym(S, SK_METHOD, RT_UNKNOWN, CurrentClassRef);
      ParsePrimary := N;
    End;
    Exit;
  End;
  If CurTokType = TOK_ARROW Then Begin
    ParsePrimary := ParseLambdaArrow;
    Exit;
  End;
  If IsPseudoKeyword(CurTokType) Then Begin
    S := CurTokStr;
    N := NewASTNode(NK_VAR, CurTokType, S, 0, 0, 0);
    AstTable[N].SymRef := AddSym(S, SK_METHOD, RT_UNKNOWN, CurrentClassRef);
    NextTok;
    ParsePrimary := N;
    Exit;
  End;
  Case CurTokType Of
    TOK_STRING, TOK_DSTRING, TOK_HEREDOC, TOK_PERCENT_LIT:
      Begin
        N := NewASTNode(NK_STRING, CurTokType, CurTokStr, 0, 0, 0);
        AstTable[N].SymRef := AddStringLit(CurTokStr, CurTokType);
        NextTok;
        ParsePrimary := N;
      End;
    TOK_SYMBOL:
      Begin
        S := NormalizeSymbolName(CurTokStr);
        N := NewASTNode(NK_SYMBOL, CurTokType, S, 0, 0, 0);
        AstTable[N].SymRef := AddSymbolLit(S);
        NextTok;
        ParsePrimary := N;
      End;
    TOK_REGEX:
      Begin
        N := NewASTNode(NK_REGEX, CurTokType, CurTokStr, 0, 0, 0);
        AstTable[N].SymRef := AddRegexLit(CurTokStr);
        NextTok;
        ParsePrimary := N;
      End;
    TOK_INTEGER, TOK_FLOAT,
    KW_NIL, KW_FALSE, KW_TRUE:
      Begin
        N := NewASTNode(NK_LITERAL, CurTokType, CurTokStr, 0, 0, 0);
        If (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_FLOAT) Then Begin
          AstTable[N].Text := CurTokStr;
          AstTable[N].SymRef := AddNumLit(CurTokStr, CurTokType);
        End;
        NextTok;
        ParsePrimary := N;
      End;
    KW_FILE, KW_LINE, KW_ENCODING:
      Begin
        If CurTokType = KW_FILE Then S := '__FILE__'
        Else If CurTokType = KW_LINE Then S := '__LINE__'
        Else S := '__ENCODING__';
        N := NewASTNode(NK_CONST, CurTokType, S, 0, 0, 0);
        AstTable[N].SymRef := AddPseudoConst(S, RT_STRING);
        If CurTokType = KW_LINE Then SymTable[AstTable[N].SymRef].RType := RT_INTEGER;
        NextTok;
        ParsePrimary := N;
      End;
    TOK_IDENT, TOK_IVAR, TOK_CVAR, TOK_GVAR:
      Begin
        S := CurTokStr;
        N := NewASTNode(NK_VAR, CurTokType, S, 0, 0, 0);
        K := SK_LOCAL;
        If CurTokType = TOK_IVAR Then K := SK_IVAR
        Else If CurTokType = TOK_CVAR Then K := SK_CVAR
        Else If CurTokType = TOK_GVAR Then K := SK_GVAR;
        If (CurTokType = TOK_IDENT) And IsKernelBuiltinName(S) Then
          AstTable[N].SymRef := AddSym(S, SK_METHOD, RT_UNKNOWN,
                                       CurrentClassRef)
        Else
          AstTable[N].SymRef := ResolveVarByToken(CurTokType, S);
        NextTok;
        ParsePrimary := N;
      End;
    TOK_CONST:
      Begin
        S := CurTokStr;
        N := NewASTNode(NK_CONST, CurTokType, S, 0, 0, 0);
        AstTable[N].SymRef := ResolveConst(S);
        NextTok;
        ParsePrimary := N;
      End;
    KW_SELF:
      Begin
        N := NewASTNode(NK_VAR, CurTokType, 'self', 0, 0, 0);
        NextTok;
        ParsePrimary := N;
      End;
    KW_SUPER:
      Begin
        NextTok;
        Args := 0;
        S := 'super';
        If CurTokType = Ord('(') Then Begin
          NextTok;
          Args := ParseListUntil(Ord(')'));
          S := 'super-explicit';
        End Else If IsCallArgStart(CurTokType) Then Begin
          Args := ParseBareArgList;
          S := 'super-explicit';
        End;
        N := NewASTNode(NK_SUPER, KW_SUPER, S, Args, 0, 0);
        AstTable[N].SymRef := ResolveSuperMethod;
        If (AstTable[N].SymRef = 0) And (CurrentMethodSym <> 0) And
           ((CurrentClassRef <= 0) Or
            (SymTable[CurrentClassRef].Kind <> SK_MODULE)) Then
          WarnMsg('super sans methode parente resolue dans ' + CurrentMethodName);
        ParsePrimary := N;
      End;
    Ord('('):
      Begin
        NextTok;
        ParsePrimary := ParseExpr;
        If CurTokType = Ord(')') Then NextTok
        Else ParseError(') attendu');
      End;
    Ord('['):
      Begin
        NextTok;
        N := NewASTNode(NK_ARRAY, 0, '', 0, 0, 0);
        K := ParseListUntil(Ord(']'));
        AstTable[N].FirstChild := AstTable[K].FirstChild;
        AstTable[N].SymRef := AddArrayLit(N);
        ParsePrimary := N;
      End;
    Ord('{'):
      Begin
        NextTok;
        N := NewASTNode(NK_HASH, 0, '', 0, 0, 0);
        OldComma := ParseAllowCommaList;
        ParseAllowCommaList := False;
        SkipExprNewlines;
        While (CurTokType <> Ord('}')) And (CurTokType <> TOK_EOF) Do Begin
          If CurTokType = TOK_POW Then Begin
            NextTok;
            AddChild(N, NewASTNode(NK_KW_SPLAT, TOK_POW, '**', ParseExpr, 0, 0));
            SkipExprNewlines;
            If CurTokType = Ord(',') Then Begin
              NextTok;
              SkipExprNewlines;
            End Else
              Break;
            Continue;
          End;
          Key := ParseExpr;
          If (CurTokType = TOK_FAT_ARROW) Or (CurTokType = Ord(':')) Then
          Begin
            If (CurTokType = Ord(':')) And
               ((AstTable[Key].Kind = NK_VAR) Or (AstTable[Key].Kind = NK_CONST)) Then Begin
              S := AstTable[Key].Text;
              AstTable[Key].Kind := NK_SYMBOL;
              AstTable[Key].Tok := TOK_SYMBOL;
              AstTable[Key].SymRef := AddSymbolLit(S);
            End;
            NextTok;
          End
          Else
            ParseError('=> ou : attendu dans hash');
          Val := ParseExpr;
          AddChild(N, NewASTNode(NK_PAIR, 0, '', Key, Val, 0));
          SkipExprNewlines;
          If CurTokType = Ord(',') Then Begin
            NextTok;
            SkipExprNewlines;
          End Else
            Break;
        End;
        If CurTokType = Ord('}') Then NextTok
        Else ParseError('} attendu');
        ParseAllowCommaList := OldComma;
        AstTable[N].SymRef := AddHashLit(N);
        ParsePrimary := N;
      End;
  Else
    T := TokenName(CurTokType);
    ParseError('expression attendue, trouve ' + T);
    If CurTokType <> TOK_EOF Then NextTok;
    ParsePrimary := NewASTNode(NK_LITERAL, TOK_EOF, 'nil', 0, 0, 0);
  End;
End;

Function ParseArgList: Integer;
Var
  L, A: Integer;
  OldComma: Boolean;
Begin
  L := NewASTNode(NK_LIST, 0, '', 0, 0, 0);
  If CurTokType = Ord('(') Then NextTok;
  SkipExprNewlines;
  OldComma := ParseAllowCommaList;
  ParseAllowCommaList := False;
  While (CurTokType <> Ord(')')) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = Ord('*') Then Begin
      NextTok;
      A := NewASTNode(NK_SPLAT, Ord('*'), '*', ParseExpr, 0, 0);
    End Else If CurTokType = TOK_POW Then Begin
      NextTok;
      A := NewASTNode(NK_KW_SPLAT, TOK_POW, '**', ParseExpr, 0, 0);
    End Else
      A := ParseExpr;
    AddChild(L, A);
    SkipExprNewlines;
    If CurTokType = Ord(',') Then Begin
      NextTok;
      SkipExprNewlines;
    End Else
      Break;
  End;
  If CurTokType = Ord(')') Then NextTok
  Else ParseError(') attendu dans appel');
  ParseAllowCommaList := OldComma;
  ParseArgList := L;
End;

Function IsCallArgStart(T: Integer): Boolean;
Begin
  IsCallArgStart := (T = TOK_IDENT) Or (T = TOK_CONST) Or (T = TOK_IVAR) Or
                    (T = TOK_CVAR) Or (T = TOK_GVAR) Or
                    (T = TOK_INTEGER) Or (T = TOK_FLOAT) Or
                    (T = TOK_STRING) Or (T = TOK_DSTRING) Or (T = TOK_HEREDOC) Or
                    (T = TOK_SYMBOL) Or (T = TOK_REGEX) Or
                    (T = TOK_PERCENT_LIT) Or (T = Ord('(')) Or
                    (T = Ord('[')) Or (T = Ord('{')) Or
                    (T = Ord('*')) Or (T = TOK_POW) Or
                    (T = KW_SUPER) Or (T = KW_SELF) Or
                    IsKeywordLiteral(T) Or IsPseudoKeyword(T);
End;

Function ParseBareArgList: Integer;
Var
  L, A: Integer;
  OldComma: Boolean;
Begin
  L := NewASTNode(NK_LIST, 0, '', 0, 0, 0);
  OldComma := ParseAllowCommaList;
  ParseAllowCommaList := False;
  While IsCallArgStart(CurTokType) Do Begin
    If CurTokType = Ord('*') Then Begin
      NextTok;
      A := NewASTNode(NK_SPLAT, Ord('*'), '*', ParseExpr, 0, 0);
    End Else If CurTokType = TOK_POW Then Begin
      NextTok;
      A := NewASTNode(NK_KW_SPLAT, TOK_POW, '**', ParseExpr, 0, 0);
    End Else
      A := ParseExpr;
    AddChild(L, A);
    If CurTokType = Ord(',') Then
      NextTok
    Else
      Break;
    SkipExprNewlines;
  End;
  ParseAllowCommaList := OldComma;
  ParseBareArgList := L;
End;

Function ParsePostfix: Integer;
Var
  N, Args, Name, Blk, Ctl: Integer;
  M: String;
  IsIter: Boolean;
Begin
  N := ParsePrimary;
  While True Do Begin
    If CurTokType = Ord('(') Then Begin
      Args := ParseArgList;
      N := NewASTNode(NK_CALL, Ord('('), 'call', N, Args, 0);
    End Else If CurTokType = Ord('[') Then Begin
      NextTok;
      Args := ParseListUntil(Ord(']'));
      N := NewASTNode(NK_INDEX, Ord('['), '[]', N, Args, 0);
    End Else If (CurTokType = Ord('.')) Or (CurTokType = TOK_SAFE_NAV) Then Begin
      If CurTokType = TOK_SAFE_NAV Then M := '&.' Else M := '.';
      NextTok;
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_CONST) Or
         IsPseudoKeyword(CurTokType) Or IsCoreMethodKeyword(CurTokType) Then Begin
        Name := NewASTNode(NK_LITERAL, CurTokType, CurTokStr, 0, 0, 0);
        NextTok;
        If CurTokType = Ord('(') Then Args := ParseArgList
        Else Args := NewASTNode(NK_LIST, 0, '', 0, 0, 0);
        N := NewASTNode(NK_CALL, 0, M, N, Args, Name);
      End Else
        ParseError('nom de methode attendu apres .');
    End Else If CurTokType = TOK_DCOLON Then Begin
      NextTok;
      If CurTokType = TOK_CONST Then Begin
        M := AstTable[N].Text + '::' + CurTokStr;
        Name := NewASTNode(NK_CONST, TOK_DCOLON, M, N, 0, 0);
        AstTable[Name].SymRef := ResolveConst(M);
        NextTok;
        N := Name;
      End Else
        ParseError('constante attendue apres ::');
    End Else If (CurTokType = Ord('{')) Or
                ((CurTokType = KW_DO) And ParseAllowDoBlock) Then Begin
      IsIter := (AstTable[N].Kind = NK_CALL) And (AstTable[N].Third <> 0) And
                IsIteratorMethodName(NodeMethodName(AstTable[N].Third));
      If IsIter Then Begin
        Ctl := AddControlInfo(N, NK_CALL, N, 0, 0,
                              CTRLF_LOOP Or CTRLF_ITERATOR);
        AstTable[N].SymRef := Ctl;
        PushLoop(Ctl);
      End Else
        Ctl := 0;
      Blk := ParseBlockLiteral(NK_BLOCK, CurTokType);
      If IsIter Then Begin
        PopLoop;
        ControlTable[Ctl].ThenNode := Blk;
      End;
      AddChild(N, Blk);
    End Else If ((AstTable[N].Kind = NK_VAR) Or (AstTable[N].Kind = NK_CONST)) And
                IsCallArgStart(CurTokType) And
                (CurTokType <> Ord('*')) And (CurTokType <> TOK_POW) Then Begin
      Args := ParseBareArgList;
      N := NewASTNode(NK_CALL, 0, 'bare-call', N, Args, 0);
      AstTable[N].SymRef := RegisterAutoloadCall(N);
    End Else
      Break;
  End;
  ParsePostfix := N;
End;

Function ParsePower: Integer;
Var
  L, R: Integer;
Begin
  L := ParsePostfix;
  If CurTokType = TOK_POW Then Begin
    NextTok;
    R := ParsePower;
    L := NewASTNode(NK_BINARY, TOK_POW, '**', L, R, 0);
  End;
  ParsePower := L;
End;

Function ParseUnary: Integer;
Var
  T: Integer;
  S: String;
Begin
  If (CurTokType = Ord('!')) Or (CurTokType = Ord('~')) Or
     (CurTokType = Ord('+')) Or (CurTokType = Ord('-')) Or
     (CurTokType = KW_NOT) Or (CurTokType = TOK_PIN) Then Begin
    T := CurTokType;
    S := CurTokStr;
    If S = '' Then S := TokenName(T);
    NextTok;
    ParseUnary := NewASTNode(NK_UNARY, T, S, ParseUnary, 0, 0);
  End Else
    ParseUnary := ParsePower;
End;

Function ParseMultiplicative: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseUnary;
  While (CurTokType = Ord('*')) Or (CurTokType = Ord('/')) Or
        (CurTokType = Ord('%')) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseUnary;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
  End;
  ParseMultiplicative := L;
End;

Function ParseAdditive: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseMultiplicative;
  While (CurTokType = Ord('+')) Or (CurTokType = Ord('-')) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseMultiplicative;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
  End;
  ParseAdditive := L;
End;

Function ParseShift: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseAdditive;
  While (CurTokType = TOK_SHL) Or (CurTokType = TOK_SHR) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseAdditive;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
  End;
  ParseShift := L;
End;

Function ParseBitAnd: Integer;
Var
  L, R: Integer;
Begin
  L := ParseShift;
  While CurTokType = Ord('&') Do Begin
    NextTok;
    R := ParseShift;
    L := NewASTNode(NK_BINARY, Ord('&'), '&', L, R, 0);
  End;
  ParseBitAnd := L;
End;

Function ParseBitOr: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseBitAnd;
  While (CurTokType = Ord('|')) Or (CurTokType = Ord('^')) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseBitAnd;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
  End;
  ParseBitOr := L;
End;

Function ParseComparison: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseBitOr;
  While (CurTokType = Ord('<')) Or (CurTokType = Ord('>')) Or
        (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Or
        (CurTokType = TOK_SPACESHIP) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseBitOr;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
  End;
  ParseComparison := L;
End;

Function ParseEquality: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseComparison;
  While (CurTokType = TOK_EQ) Or (CurTokType = TOK_TRIPLEEQ) Or
        (CurTokType = TOK_NE) Or (CurTokType = TOK_MATCH) Or
        (CurTokType = TOK_NMATCH) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseComparison;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
    If (T = TOK_MATCH) Or (T = TOK_NMATCH) Then
      AstTable[L].SymRef := ResolveGlobal('$~');
  End;
  ParseEquality := L;
End;

Function ParseLogicalAnd: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseEquality;
  While (CurTokType = TOK_ANDAND) Or (CurTokType = KW_AND) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseEquality;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
    AstTable[L].SymRef := AddControlInfo(L, NK_BINARY, AstTable[L].Left,
                                         AstTable[L].Right, 0,
                                         CTRLF_SHORT_CIRCUIT);
  End;
  ParseLogicalAnd := L;
End;

Function ParseLogicalOr: Integer;
Var
  L, R, T: Integer;
  S: String;
Begin
  L := ParseLogicalAnd;
  While (CurTokType = TOK_OROR) Or (CurTokType = KW_OR) Do Begin
    T := CurTokType; S := CurTokStr; NextTok;
    R := ParseLogicalAnd;
    L := NewASTNode(NK_BINARY, T, S, L, R, 0);
    AstTable[L].SymRef := AddControlInfo(L, NK_BINARY, AstTable[L].Left,
                                         AstTable[L].Right, 0,
                                         CTRLF_SHORT_CIRCUIT);
  End;
  ParseLogicalOr := L;
End;

Function ParseRange: Integer;
Var
  L, R, T, F: Integer;
  S: String;
Begin
  If (CurTokType = TOK_DOTDOT) Or (CurTokType = TOK_DOTDOTDOT) Then Begin
    T := CurTokType; S := CurTokStr; NextTok;
    F := RANGEF_BEGINLESS;
    If T = TOK_DOTDOTDOT Then F := F Or RANGEF_EXCLUSIVE;
    If Not IsExprEnd(CurTokType) Then R := ParseLogicalOr Else R := 0;
    L := NewASTNode(NK_RANGE, T, S, 0, R, 0);
    AstTable[L].SymRef := AddRangeLit(0, R, F);
    ParseRange := L;
    Exit;
  End;
  L := ParseLogicalOr;
  If (CurTokType = TOK_DOTDOT) Or (CurTokType = TOK_DOTDOTDOT) Then Begin
    T := CurTokType; S := CurTokStr; NextTok;
    F := 0;
    If T = TOK_DOTDOTDOT Then F := F Or RANGEF_EXCLUSIVE;
    If Not IsExprEnd(CurTokType) Then R := ParseLogicalOr Else R := 0;
    If R = 0 Then F := F Or RANGEF_ENDLESS;
    L := NewASTNode(NK_RANGE, T, S, L, R, 0);
    AstTable[L].SymRef := AddRangeLit(AstTable[L].Left, R, F);
  End;
  ParseRange := L;
End;

Function ParseTernary: Integer;
Var
  C, A, B: Integer;
Begin
  C := ParseRange;
  If CurTokType = Ord('?') Then Begin
    NextTok;
    A := ParseExpr;
    If CurTokType = Ord(':') Then NextTok
    Else ParseError(': attendu dans expression ternaire');
    B := ParseExpr;
    C := NewASTNode(NK_TERNARY, Ord('?'), '?:', C, A, B);
    AstTable[C].SymRef := AddControlInfo(C, NK_TERNARY, AstTable[C].Left,
                                         AstTable[C].Right, AstTable[C].Third,
                                         CTRLF_TERNARY);
  End;
  ParseTernary := C;
End;

Function ParseAssign: Integer;
Var
  L, R, OpTok: Integer;
  OpText: String;
Begin
  L := ParseTernary;
  If ParseAllowCommaList And (CurTokType = Ord(',')) Then Begin
    L := NewASTNode(NK_LIST, 0, '', L, 0, 0);
    AddChild(L, AstTable[L].Left);
    AstTable[L].Left := 0;
    While CurTokType = Ord(',') Do Begin
      NextTok;
      AddChild(L, ParseTernary);
    End;
  End;
  If IsAssignTok(CurTokType) Then Begin
    OpTok := CurTokType;
    OpText := CurTokStr;
    If OpText = '' Then OpText := '=';
    NextTok;
    R := ParseAssign;
    MarkAssignedNode(L);
    L := NewASTNode(NK_ASSIGN, OpTok, OpText, L, R, 0);
  End;
  ParseAssign := L;
End;

Function ParseExpr: Integer;
Begin
  ParseExpr := ParseAssign;
End;

Function ParseConditionExpr: Integer;
Var
  OldAllowDo: Boolean;
Begin
  OldAllowDo := ParseAllowDoBlock;
  ParseAllowDoBlock := False;
  ParseConditionExpr := ParseExpr;
  ParseAllowDoBlock := OldAllowDo;
End;

Procedure DumpASTNode(N, Indent: Integer); Forward;

Function IsStatementEndToken(T, End1, End2, End3: Integer): Boolean;
Begin
  IsStatementEndToken := (T = TOK_EOF) Or
                         ((End1 <> 0) And (T = End1)) Or
                         ((End2 <> 0) And (T = End2)) Or
                         ((End3 <> 0) And (T = End3)) Or
                         ((End1 = KW_RESCUE) And (End2 = KW_ELSE) And
                          (End3 = KW_ENSURE) And (T = KW_END)) Or
                         ((End1 = KW_WHEN) And (T = KW_IN));
End;

Procedure ConsumeStatementDelims;
Begin
  While (CurTokType = TOK_NEWLINE) Or (CurTokType = Ord(';')) Do
    NextTok;
End;

Function NewEmptyParamList(Name: String): Integer;
Begin
  NewEmptyParamList := NewASTNode(NK_LIST, 0, Name, 0, 0, 0);
End;

Function ParseBlockParamSeq(EndTok: Integer; ListName: String): Integer;
Var
  P, N, DefVal, ParamKind: Integer;
  Name: String;
  OldComma: Boolean;
Begin
  P := NewEmptyParamList(ListName);
  OldComma := ParseAllowCommaList;
  ParseAllowCommaList := False;
  While (CurTokType <> EndTok) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = Ord(';') Then Begin
      Repeat
        NextTok;
        If CurTokType = TOK_IDENT Then Begin
          AddSym(CurTokStr, SK_LOCAL, RT_UNKNOWN, CurrentClassRef);
          NextTok;
        End;
        If CurTokType = Ord(',') Then NextTok
        Else Break;
      Until (CurTokType = EndTok) Or (CurTokType = TOK_EOF);
      Break;
    End;
    ParamKind := NK_PARAM;
    DefVal := 0;
    If CurTokType = Ord('*') Then Begin
      ParamKind := NK_PARAM_SPLAT;
      NextTok;
    End Else If CurTokType = TOK_POW Then Begin
      ParamKind := NK_PARAM_KW_SPLAT;
      NextTok;
    End Else If CurTokType = TOK_AMP_BLOCK Then Begin
      ParamKind := NK_PARAM_BLOCK;
      NextTok;
    End;
    If CurTokType = TOK_IDENT Then Begin
      Name := CurTokStr;
      N := NewASTNode(ParamKind, CurTokType, Name, 0, 0, 0);
      AstTable[N].SymRef := AddSym(Name, SK_BLOCK_PARAM, RT_UNKNOWN, CurrentClassRef);
      NextTok;
      If CurTokType = Ord(':') Then Begin
        NextTok;
        AstTable[N].Kind := NK_PARAM_KEY;
        If (CurTokType <> Ord(',')) And (CurTokType <> EndTok) Then
          DefVal := ParseExpr;
        AstTable[N].Left := DefVal;
      End Else If CurTokType = Ord('=') Then Begin
        NextTok;
        DefVal := ParseExpr;
        AstTable[N].Kind := NK_PARAM_DEFAULT;
        AstTable[N].Left := DefVal;
      End;
      AddChild(P, N);
    End Else Begin
      ParseError('nom de parametre de bloc attendu');
      If CurTokType <> TOK_EOF Then NextTok;
    End;
    If CurTokType = Ord(',') Then NextTok
    Else Break;
  End;
  If CurTokType = EndTok Then NextTok
  Else ParseError(TokenName(EndTok) + ' attendu dans parametres de bloc');
  ParseAllowCommaList := OldComma;
  ParseBlockParamSeq := P;
End;

Function ParseBlockBody(BlockKind, StartTok, Params, Flags: Integer; ScopeOpen: Boolean): Integer;
Var
  EndTok, Body, N: Integer;
  Name: String;
Begin
  If StartTok = KW_DO Then Begin
    EndTok := KW_END;
    Flags := Flags Or BLOCKF_DO_END;
  End Else
    EndTok := Ord('}');
  If BlockKind = NK_PROC Then Begin
    Name := 'proc';
    Flags := Flags Or BLOCKF_PROC;
  End Else If BlockKind = NK_LAMBDA Then Begin
    Name := 'lambda';
    Flags := Flags Or BLOCKF_LAMBDA;
  End Else
    Name := 'block';
  If Not ScopeOpen Then EnterScope(SC_BLOCK);
  NextTok;
  If Params = 0 Then
    Params := NewEmptyParamList('block-params');
  If CurTokType = Ord('|') Then Begin
    NextTok;
    Params := ParseBlockParamSeq(Ord('|'), 'block-params');
    Flags := Flags Or BLOCKF_HAS_PARAMS;
  End Else If AstTable[Params].FirstChild <> 0 Then
    Flags := Flags Or BLOCKF_HAS_PARAMS;
  ConsumeStatementDelims;
  Body := ParseStatementList(EndTok, 0, 0);
  If CurTokType = EndTok Then NextTok
  Else ParseError(TokenName(EndTok) + ' attendu pour bloc');
  LeaveScope;
  N := NewASTNode(BlockKind, StartTok, Name, Params, Body, 0);
  AstTable[N].SymRef := AddBlockInfo(BlockKind, Params, Body, Flags);
  ParseBlockBody := N;
End;

Function ParseBlockLiteral(BlockKind, StartTok: Integer): Integer;
Begin
  ParseBlockLiteral := ParseBlockBody(BlockKind, StartTok, 0, 0, False);
End;

Function ParseLambdaArrow: Integer;
Var
  Params: Integer;
Begin
  NextTok;
  Params := 0;
  EnterScope(SC_BLOCK);
  If CurTokType = Ord('(') Then Begin
    NextTok;
    Params := ParseBlockParamSeq(Ord(')'), 'lambda-params');
  End;
  If (CurTokType = Ord('{')) Or (CurTokType = KW_DO) Then
    ParseLambdaArrow := ParseBlockBody(NK_LAMBDA, CurTokType, Params,
                                      BLOCKF_LAMBDA, True)
  Else Begin
    ParseError('bloc attendu apres ->');
    LeaveScope;
    ParseLambdaArrow := NewASTNode(NK_LAMBDA, TOK_ARROW, 'lambda', Params, 0, 0);
    AstTable[ParseLambdaArrow].SymRef :=
      AddBlockInfo(NK_LAMBDA, Params, 0, BLOCKF_LAMBDA);
  End;
End;

Procedure ConsumeOptionalThenDo;
Begin
  If (CurTokType = KW_THEN) Or (CurTokType = KW_DO) Then NextTok;
  ConsumeStatementDelims;
End;

Function ParseOptionalExpr: Integer;
Begin
  If IsExprEnd(CurTokType) Or (CurTokType = Ord(';')) Then
    ParseOptionalExpr := 0
  Else
    ParseOptionalExpr := ParseExpr;
End;

Function ParseControlValue(Kind: Integer; Name: String): Integer;
Begin
  NextTok;
  ParseControlValue := NewASTNode(Kind, 0, Name, ParseOptionalExpr, 0, 0);
End;

Function ParseYieldStatement: Integer;
Var
  Args: Integer;
Begin
  NextTok;
  If CurTokType = Ord('(') Then
    Args := ParseArgList
  Else If IsCallArgStart(CurTokType) Then
    Args := ParseBareArgList
  Else
    Args := NewASTNode(NK_LIST, 0, 'yield-args', 0, 0, 0);
  ParseYieldStatement := NewASTNode(NK_YIELD, KW_YIELD, 'yield', Args, 0, 0);
End;

Function ParseLoopStatement: Integer;
Var
  N, Ctl, Cond, Blk: Integer;
Begin
  NextTok;
  Cond := NewASTNode(NK_LITERAL, KW_TRUE, 'true', 0, 0, 0);
  N := NewASTNode(NK_WHILE, KW_LOOP, 'loop', Cond, 0, 0);
  Ctl := AddControlInfo(N, NK_WHILE, Cond, 0, 0,
                        CTRLF_LOOP Or CTRLF_LOOP_BLOCK Or CTRLF_ITERATOR);
  AstTable[N].SymRef := Ctl;
  PushLoop(Ctl);
  If (CurTokType = Ord('{')) Or (CurTokType = KW_DO) Then Begin
    Blk := ParseBlockLiteral(NK_BLOCK, CurTokType);
    AstTable[N].Right := Blk;
    ControlTable[Ctl].ThenNode := Blk;
  End Else
    ParseError('bloc attendu apres loop');
  PopLoop;
  ParseLoopStatement := N;
End;

Function ParseLoopControlStatement(Kind, Tok: Integer; Name: String): Integer;
Var
  N, Val, Cond, ModTok: Integer;
Begin
  NextTok;
  If IsExprEnd(CurTokType) Or IsModifierKeyword(CurTokType) Then
    Val := 0
  Else
    Val := ParseExpr;
  N := NewASTNode(Kind, Tok, Name, Val, 0, 0);
  AstTable[N].SymRef := CurrentLoopControl;
  If (AstTable[N].SymRef = 0) And ((Kind = NK_BREAK) Or
     (Kind = NK_NEXT) Or (Kind = NK_REDO)) Then
    WarnMsg(Name + ' hors boucle');
  If IsModifierKeyword(CurTokType) Then Begin
    ModTok := CurTokType;
    NextTok;
    Cond := ParseConditionExpr;
    If ModTok = KW_IF Then Begin
      N := NewASTNode(NK_IF, KW_IF, 'if-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_IF, Cond,
                                            AstTable[N].Right, 0,
                                            CTRLF_MODIFIER);
    End Else If ModTok = KW_UNLESS Then Begin
      N := NewASTNode(NK_UNLESS, KW_UNLESS, 'unless-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_UNLESS, Cond,
                                            AstTable[N].Right, 0,
                                            CTRLF_UNLESS Or CTRLF_MODIFIER);
    End Else If ModTok = KW_WHILE Then Begin
      N := NewASTNode(NK_WHILE, KW_WHILE, 'while-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_WHILE, Cond,
                                            AstTable[N].Right, 0,
                                            CTRLF_LOOP Or CTRLF_WHILE Or
                                            CTRLF_MODIFIER);
    End Else If ModTok = KW_UNTIL Then Begin
      N := NewASTNode(NK_UNTIL, KW_UNTIL, 'until-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_UNTIL, Cond,
                                            AstTable[N].Right, 0,
                                            CTRLF_LOOP Or CTRLF_UNTIL Or
                                            CTRLF_MODIFIER);
    End;
  End;
  ParseLoopControlStatement := N;
End;

Function ParseRaiseStatement: Integer;
Var
  Args, N: Integer;
Begin
  NextTok;
  If CurTokType = Ord('(') Then
    Args := ParseArgList
  Else If IsCallArgStart(CurTokType) Then
    Args := ParseBareArgList
  Else
    Args := NewASTNode(NK_LIST, 0, 'raise-args', 0, 0, 0);
  N := NewASTNode(NK_RAISE, KW_RAISE, 'raise', Args, 0, 0);
  AstTable[N].SymRef := ResolveConst('RuntimeError');
  ParseRaiseStatement := N;
End;

Function ParseRetryStatement: Integer;
Var
  N, Cond, ModTok: Integer;
Begin
  NextTok;
  N := NewASTNode(NK_RETRY, KW_RETRY, 'retry', 0, 0, 0);
  AstTable[N].SymRef := CurrentRescueControl;
  If AstTable[N].SymRef = 0 Then WarnMsg('retry hors rescue');
  If IsModifierKeyword(CurTokType) Then Begin
    ModTok := CurTokType;
    NextTok;
    Cond := ParseConditionExpr;
    If ModTok = KW_IF Then Begin
      N := NewASTNode(NK_IF, KW_IF, 'if-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_IF, Cond,
                                           AstTable[N].Right, 0,
                                           CTRLF_MODIFIER);
    End Else If ModTok = KW_UNLESS Then Begin
      N := NewASTNode(NK_UNLESS, KW_UNLESS, 'unless-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_UNLESS, Cond,
                                           AstTable[N].Right, 0,
                                           CTRLF_UNLESS Or CTRLF_MODIFIER);
    End Else If ModTok = KW_WHILE Then Begin
      N := NewASTNode(NK_WHILE, KW_WHILE, 'while-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_WHILE, Cond,
                                           AstTable[N].Right, 0,
                                           CTRLF_LOOP Or CTRLF_WHILE Or
                                           CTRLF_MODIFIER);
    End Else If ModTok = KW_UNTIL Then Begin
      N := NewASTNode(NK_UNTIL, KW_UNTIL, 'until-mod', Cond, N, 0);
      AstTable[N].SymRef := AddControlInfo(N, NK_UNTIL, Cond,
                                           AstTable[N].Right, 0,
                                           CTRLF_LOOP Or CTRLF_UNTIL Or
                                           CTRLF_MODIFIER);
    End;
  End;
  ParseRetryStatement := N;
End;

Function ParseAliasStatement: Integer;
Var
  A, B: Integer;
Begin
  NextTok;
  A := ParseOptionalExpr;
  B := ParseOptionalExpr;
  ParseAliasStatement := NewASTNode(NK_ALIAS, KW_ALIAS, 'alias', A, B, 0);
End;

Function ParseUndefStatement: Integer;
Begin
  NextTok;
  ParseUndefStatement := NewASTNode(NK_UNDEF, KW_UNDEF, 'undef',
                                    ParseOptionalExpr, 0, 0);
End;

Function ParseElsifChain: Integer;
Var
  Cond, ThenPart, ElsePart, N: Integer;
Begin
  NextTok;
  Cond := ParseConditionExpr;
  ConsumeOptionalThenDo;
  ThenPart := ParseStatementList(KW_ELSIF, KW_ELSE, KW_END);
  ElsePart := 0;
  If CurTokType = KW_ELSIF Then
    ElsePart := ParseElsifChain
  Else If CurTokType = KW_ELSE Then Begin
    NextTok;
    ConsumeStatementDelims;
    ElsePart := ParseStatementList(KW_END, 0, 0);
  End;
  N := NewASTNode(NK_IF, KW_IF, 'elsif', Cond, ThenPart, ElsePart);
  AstTable[N].SymRef := AddControlInfo(N, NK_IF, Cond, ThenPart, ElsePart, 0);
  ParseElsifChain := N;
End;

Function ParseRequireStatement(TokKind: Integer): Integer;
Var
  Name, LibName: String;
  Arg, N: Integer;
Begin
  Name := CurTokStr;
  NextTok;
  Arg := ParseOptionalExpr;
  N := NewASTNode(NK_REQUIRE, TokKind, Name, Arg, 0, 0);
  LibName := NodeStringValue(Arg);
  If LibName <> '' Then
    AstTable[N].SymRef := AddRequireInfo(TokKind, N, Arg, 0, LibName, 0);
  ParseRequireStatement := N;
End;

Function ParseVisibilityStatement(V: Integer): Integer;
Var
  Args, N, C, S: Integer;
Begin
  CurrentVisibility := V;
  NextTok;
  Args := 0;
  If Not IsExprEnd(CurTokType) Then Begin
    Args := ParseOptionalExpr;
    C := Args;
    If AstTable[Args].Kind = NK_LIST Then C := AstTable[Args].FirstChild;
    While C <> 0 Do Begin
      S := FindSym(CurrentClassName + '#' + Copy(AstTable[C].Text, 2, 255));
      If S <> 0 Then
        SymTable[S].Flags := (SymTable[S].Flags And Not
          (SF_METHOD_PUBLIC Or SF_METHOD_PRIVATE Or SF_METHOD_PROTECTED)) Or
          VisibilityFlag(V);
      C := AstTable[C].NextSibling;
      If AstTable[Args].Kind <> NK_LIST Then C := 0;
    End;
  End;
  N := NewASTNode(NK_VISIBILITY, 0, VisibilityName(V), Args, 0, 0);
  ParseVisibilityStatement := N;
End;

Function MixinModeName(Mode: Integer): String;
Begin
  If Mode = KW_EXTEND Then MixinModeName := 'extend'
  Else If Mode = KW_PREPEND Then MixinModeName := 'prepend'
  Else MixinModeName := 'include';
End;

Function NodeMethodName(N: Integer): String;
Var
  S: String;
Begin
  NodeMethodName := '';
  If N = 0 Then Exit;
  S := AstTable[N].Text;
  If (Length(S) > 0) And (S[1] = ':') Then
    S := Copy(S, 2, Length(S) - 1);
  NodeMethodName := S;
End;

Function IsIteratorMethodName(S: String): Boolean;
Begin
  IsIteratorMethodName := (S = 'times') Or (S = 'each') Or (S = 'map') Or
                          (S = 'collect') Or (S = 'select') Or
                          (S = 'filter') Or (S = 'reject') Or
                          (S = 'find') Or (S = 'detect') Or
                          (S = 'find_index') Or (S = 'inject') Or
                          (S = 'reduce') Or (S = 'min_by') Or
                          (S = 'max_by') Or (S = 'sort_by') Or
                          (S = 'group_by') Or (S = 'partition') Or
                          (S = 'chunk') Or (S = 'each_with_index') Or
                          (S = 'each_with_object') Or
                          (S = 'take_while') Or (S = 'drop_while') Or
                          (S = 'all?') Or (S = 'any?') Or
                          (S = 'none?') Or (S = 'one?') Or
                          (S = 'upto') Or (S = 'downto') Or (S = 'step');
End;

Function ParseMixinStatement(Mode: Integer): Integer;
Var
  Args, M: Integer;
Begin
  NextTok;
  Args := NewASTNode(NK_LIST, 0, 'modules', 0, 0, 0);
  If IsExprEnd(CurTokType) Then
    ParseError('module attendu apres ' + MixinModeName(Mode))
  Else Begin
    Repeat
      M := ParseExpr;
      AddChild(Args, M);
      If M <> 0 Then AddMixinToClass(CurrentClassRef, AstTable[M].SymRef, Mode);
      If CurTokType = Ord(',') Then NextTok
      Else Break;
    Until IsExprEnd(CurTokType);
  End;
  ParseMixinStatement := NewASTNode(NK_MIXIN, Mode, MixinModeName(Mode), Args, 0, 0);
End;

Function ParseModuleFunctionStatement: Integer;
Var
  Args, M: Integer;
Begin
  NextTok;
  Args := NewASTNode(NK_LIST, 0, 'module-functions', 0, 0, 0);
  If IsExprEnd(CurTokType) Then
    CurrentVisibility := VIS_PRIVATE
  Else Begin
    Repeat
      M := ParseExpr;
      AddChild(Args, M);
      ApplyModuleFunction(NodeMethodName(M));
      If CurTokType = Ord(',') Then NextTok
      Else Break;
    Until IsExprEnd(CurTokType);
  End;
  ParseModuleFunctionStatement := NewASTNode(NK_MODULE_FUNCTION,
                                            KW_MODULE_FUNCTION,
                                            'module_function', Args, 0, 0);
End;

Function ParseIfStatement(IsUnless: Boolean): Integer;
Var
  Cond, ThenPart, ElsePart, ThisIf, Chain: Integer;
Begin
  NextTok;
  Cond := ParseConditionExpr;
  ConsumeOptionalThenDo;
  ThenPart := ParseStatementList(KW_ELSIF, KW_ELSE, KW_END);
  ElsePart := 0;
  If (Not IsUnless) And (CurTokType = KW_ELSIF) Then Begin
    Chain := ParseElsifChain;
    ElsePart := Chain;
  End Else If CurTokType = KW_ELSE Then Begin
    NextTok;
    ConsumeStatementDelims;
    ElsePart := ParseStatementList(KW_END, 0, 0);
  End;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour if/unless');
  If IsUnless Then ThisIf := NewASTNode(NK_UNLESS, KW_UNLESS, 'unless',
                                       Cond, ThenPart, ElsePart)
  Else ThisIf := NewASTNode(NK_IF, KW_IF, 'if', Cond, ThenPart, ElsePart);
  If IsUnless Then
    AstTable[ThisIf].SymRef := AddControlInfo(ThisIf, NK_UNLESS, Cond,
                                              ThenPart, ElsePart,
                                              CTRLF_UNLESS)
  Else
    AstTable[ThisIf].SymRef := AddControlInfo(ThisIf, NK_IF, Cond,
                                              ThenPart, ElsePart, 0);
  ParseIfStatement := ThisIf;
End;

Function ParseWhileStatement(IsUntil: Boolean): Integer;
Var
  Cond, Body, N, Ctl: Integer;
Begin
  NextTok;
  Cond := ParseConditionExpr;
  ConsumeOptionalThenDo;
  If IsUntil Then Begin
    N := NewASTNode(NK_UNTIL, KW_UNTIL, 'until', Cond, 0, 0);
    Ctl := AddControlInfo(N, NK_UNTIL, Cond, 0, 0,
                          CTRLF_LOOP Or CTRLF_UNTIL);
  End Else Begin
    N := NewASTNode(NK_WHILE, KW_WHILE, 'while', Cond, 0, 0);
    Ctl := AddControlInfo(N, NK_WHILE, Cond, 0, 0,
                          CTRLF_LOOP Or CTRLF_WHILE);
  End;
  AstTable[N].SymRef := Ctl;
  PushLoop(Ctl);
  Body := ParseStatementList(KW_END, 0, 0);
  PopLoop;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour boucle');
  AstTable[N].Right := Body;
  ControlTable[Ctl].ThenNode := Body;
  ParseWhileStatement := N;
End;

Function ParseForStatement: Integer;
Var
  VarNode, InExpr, Body, N, Ctl: Integer;
Begin
  NextTok;
  VarNode := ParseExpr;
  If CurTokType = KW_IN Then NextTok
  Else ParseError('in attendu dans for');
  InExpr := ParseConditionExpr;
  ConsumeOptionalThenDo;
  N := NewASTNode(NK_FOR, KW_FOR, 'for', VarNode, InExpr, 0);
  Ctl := AddControlInfo(N, NK_FOR, InExpr, 0, 0,
                        CTRLF_LOOP Or CTRLF_FOR Or CTRLF_ITERATOR);
  AstTable[N].SymRef := Ctl;
  PushLoop(Ctl);
  Body := ParseStatementList(KW_END, 0, 0);
  PopLoop;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour for');
  AstTable[N].Third := Body;
  ControlTable[Ctl].ThenNode := Body;
  ParseForStatement := N;
End;

Function ParseCaseStatement: Integer;
Var
  CaseExpr, Body, W, Conds, WhenBody: Integer;
Begin
  NextTok;
  CaseExpr := ParseOptionalExpr;
  ConsumeStatementDelims;
  Body := NewASTNode(NK_STMT_LIST, 0, 'case-body', 0, 0, 0);
  While (CurTokType = KW_WHEN) Or (CurTokType = KW_IN) Do Begin
    If CurTokType = KW_IN Then Begin
      W := KW_IN;
      NextTok;
    End Else Begin
      W := KW_WHEN;
      NextTok;
    End;
    Conds := ParseExpr;
    If CurTokType = KW_THEN Then NextTok;
    ConsumeStatementDelims;
    WhenBody := ParseStatementList(KW_WHEN, KW_ELSE, KW_END);
    If W = KW_IN Then
      W := NewASTNode(NK_WHEN, KW_IN, 'in', Conds, WhenBody, 0)
    Else
      W := NewASTNode(NK_WHEN, KW_WHEN, 'when', Conds, WhenBody, 0);
    AddChild(Body, W);
  End;
  If CurTokType = KW_ELSE Then Begin
    NextTok;
    ConsumeStatementDelims;
    AddChild(Body, NewASTNode(NK_STMT_LIST, KW_ELSE, 'else',
                              ParseStatementList(KW_END, 0, 0), 0, 0));
  End;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour case');
  W := NewASTNode(NK_CASE, KW_CASE, 'case', CaseExpr, Body, 0);
  If CaseHasPattern(Body) Then
    AstTable[W].SymRef := AddControlInfo(W, NK_CASE, CaseExpr, Body, 0,
                                         CTRLF_CASE Or CTRLF_PATTERN)
  Else
    AstTable[W].SymRef := AddControlInfo(W, NK_CASE, CaseExpr, Body, 0,
                                         CTRLF_CASE);
  ParseCaseStatement := W;
End;

Function ParseBeginStatement: Integer;
Var
  Body, RescueList, ElsePart, EnsurePart, RBody, BeginNode, Cond, LoopNode,
  Ctl, ModTok, Region, Flags, RescueNode, HandlerBody, DefaultCls: Integer;
Begin
  NextTok;
  ConsumeStatementDelims;
  Body := ParseStatementList(KW_RESCUE, KW_ELSE, KW_ENSURE);
  RescueList := NewASTNode(NK_STMT_LIST, 0, 'rescues', 0, 0, 0);
  Flags := 0;
  Region := AddRescueInfo(0, Body, RescueList, 0, 0, 0);
  While CurTokType = KW_RESCUE Do Begin
    NextTok;
    If CurTokType = TOK_FAT_ARROW Then Begin
      DefaultCls := NewASTNode(NK_CONST, TOK_CONST, 'StandardError', 0, 0, 0);
      AstTable[DefaultCls].SymRef := ResolveConst('StandardError');
      NextTok;
      RBody := NewASTNode(NK_PAIR, TOK_FAT_ARROW, '=>', DefaultCls,
                          ParseOptionalExpr, 0);
      Flags := Flags Or RESCF_DEFAULT;
    End Else Begin
      RBody := ParseOptionalExpr;
      If CurTokType = TOK_FAT_ARROW Then Begin
        NextTok;
        If RBody = 0 Then Begin
          RBody := NewASTNode(NK_CONST, TOK_CONST, 'StandardError', 0, 0, 0);
          AstTable[RBody].SymRef := ResolveConst('StandardError');
          Flags := Flags Or RESCF_DEFAULT;
        End;
        RBody := NewASTNode(NK_PAIR, TOK_FAT_ARROW, '=>', RBody,
                            ParseOptionalExpr, 0);
      End Else If RBody = 0 Then Begin
        RBody := NewASTNode(NK_CONST, TOK_CONST, 'StandardError', 0, 0, 0);
        AstTable[RBody].SymRef := ResolveConst('StandardError');
        Flags := Flags Or RESCF_DEFAULT;
      End;
    End;
    ConsumeStatementDelims;
    PushRescue(Region);
    HandlerBody := ParseStatementList(KW_RESCUE, KW_ELSE, KW_ENSURE);
    PopRescue;
    RescueNode := NewASTNode(NK_RESCUE, KW_RESCUE, 'rescue', RBody,
                             HandlerBody, 0);
    AstTable[RescueNode].SymRef := Region;
    AddChild(RescueList, RescueNode);
    Flags := Flags Or RESCF_HAS_RESCUE;
  End;
  ElsePart := 0;
  If CurTokType = KW_ELSE Then Begin
    NextTok;
    ConsumeStatementDelims;
    ElsePart := ParseStatementList(KW_ENSURE, KW_END, 0);
    Flags := Flags Or RESCF_HAS_ELSE;
  End;
  EnsurePart := 0;
  If CurTokType = KW_ENSURE Then Begin
    NextTok;
    ConsumeStatementDelims;
    EnsurePart := ParseStatementList(KW_END, 0, 0);
    Flags := Flags Or RESCF_HAS_ENSURE;
  End;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour begin');
  BeginNode := NewASTNode(NK_BEGIN, KW_BEGIN, 'begin', Body, RescueList,
                          NewASTNode(NK_ENSURE, KW_ENSURE, 'tail',
                                     ElsePart, EnsurePart, 0));
  AstTable[BeginNode].SymRef := Region;
  UpdateRescueInfo(Region, BeginNode, Body, RescueList, ElsePart, EnsurePart,
                   Flags);
  If (CurTokType = KW_WHILE) Or (CurTokType = KW_UNTIL) Then Begin
    ModTok := CurTokType;
    NextTok;
    Cond := ParseConditionExpr;
    If ModTok = KW_UNTIL Then Begin
      LoopNode := NewASTNode(NK_UNTIL, KW_UNTIL, 'begin-until', Cond,
                             BeginNode, 0);
      Ctl := AddControlInfo(LoopNode, NK_UNTIL, Cond, BeginNode, 0,
                            CTRLF_LOOP Or CTRLF_UNTIL Or CTRLF_POST_TEST);
    End Else Begin
      LoopNode := NewASTNode(NK_WHILE, KW_WHILE, 'begin-while', Cond,
                             BeginNode, 0);
      Ctl := AddControlInfo(LoopNode, NK_WHILE, Cond, BeginNode, 0,
                            CTRLF_LOOP Or CTRLF_WHILE Or CTRLF_POST_TEST);
    End;
    AstTable[LoopNode].SymRef := Ctl;
    ParseBeginStatement := LoopNode;
  End Else
    ParseBeginStatement := BeginNode;
End;

Function ParseParamList: Integer;
Var
  P, N, DefVal, ParamKind: Integer;
  Name: String;
  OldComma: Boolean;
Begin
  P := NewASTNode(NK_LIST, 0, 'params', 0, 0, 0);
  OldComma := ParseAllowCommaList;
  ParseAllowCommaList := False;
  If CurTokType = Ord('(') Then Begin
    NextTok;
    While (CurTokType <> Ord(')')) And (CurTokType <> TOK_EOF) Do Begin
      ParamKind := NK_PARAM;
      DefVal := 0;
      If CurTokType = Ord('*') Then Begin
        ParamKind := NK_PARAM_SPLAT;
        NextTok;
      End Else If CurTokType = TOK_POW Then Begin
        ParamKind := NK_PARAM_KW_SPLAT;
        NextTok;
      End Else If CurTokType = TOK_AMP_BLOCK Then Begin
        ParamKind := NK_PARAM_BLOCK;
        NextTok;
      End;
      If CurTokType = TOK_IDENT Then Begin
        Name := CurTokStr;
        N := NewASTNode(ParamKind, CurTokType, Name, 0, 0, 0);
        AstTable[N].SymRef := AddSym(Name, SK_PARAM, RT_UNKNOWN, CurrentClassRef);
        NextTok;
        If CurTokType = Ord(':') Then Begin
          NextTok;
          ParamKind := NK_PARAM_KEY;
          AstTable[N].Kind := NK_PARAM_KEY;
          If (CurTokType <> Ord(',')) And (CurTokType <> Ord(')')) Then
            DefVal := ParseExpr;
          AstTable[N].Left := DefVal;
        End Else If CurTokType = Ord('=') Then Begin
          NextTok;
          DefVal := ParseExpr;
          AstTable[N].Kind := NK_PARAM_DEFAULT;
          AstTable[N].Left := DefVal;
        End;
        AddChild(P, N);
      End Else Begin
        ParseError('nom de parametre attendu');
        If CurTokType <> TOK_EOF Then NextTok;
      End;
      If CurTokType = Ord(',') Then NextTok
      Else Break;
    End;
    If CurTokType = Ord(')') Then NextTok
    Else ParseError(') attendu dans parametres');
  End;
  ParseAllowCommaList := OldComma;
  ParseParamList := P;
End;

Function ParseDefStatement: Integer;
Var
  NameNode, ReceiverNode, Params, Body, MethodSym, ParamCount, N: Integer;
  PrevMethodSym: Integer;
  MethodName, OwnerName: String;
  PrevMethodName: String;
  IsSingleton, IsClassMethod: Boolean;
Begin
  PrevMethodSym := CurrentMethodSym;
  PrevMethodName := CurrentMethodName;
  ReceiverNode := 0;
  MethodName := '';
  OwnerName := CurrentClassName;
  IsSingleton := False;
  IsClassMethod := False;
  NextTok;
  If (CurTokType = KW_SELF) Or (CurTokType = TOK_IDENT) Or
     (CurTokType = TOK_CONST) Then Begin
    ReceiverNode := NewASTNode(NK_LITERAL, CurTokType, CurTokStr, 0, 0, 0);
    If CurTokType = KW_SELF Then Begin
      OwnerName := CurrentClassName;
      IsClassMethod := True;
    End Else Begin
      OwnerName := CurTokStr;
      IsSingleton := True;
    End;
    NextTok;
    If CurTokType = Ord('.') Then NextTok
    Else Begin
      MethodName := AstTable[ReceiverNode].Text;
      ReceiverNode := 0;
      OwnerName := CurrentClassName;
      IsSingleton := False;
      IsClassMethod := False;
    End;
  End;
  If MethodName = '' Then Begin
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_CONST) Or
       IsPseudoKeyword(CurTokType) Then Begin
      MethodName := CurTokStr;
      NextTok;
    End Else Begin
      ParseError('nom de methode attendu');
      MethodName := 'anonymous';
    End;
  End;
  NameNode := NewASTNode(NK_LITERAL, TOK_IDENT, MethodName, ReceiverNode, 0, 0);
  If ReceiverNode <> 0 Then AstTable[NameNode].Left := ReceiverNode;
  MethodSym := AddMethodSym(MethodName, OwnerName, CurrentVisibility,
                            0, IsSingleton, IsClassMethod);
  AstTable[NameNode].SymRef := MethodSym;
  CurrentMethodSym := MethodSym;
  CurrentMethodName := MethodName;
  EnterScope(SC_METHOD);
  Params := ParseParamList;
  ParamCount := 0;
  N := AstTable[Params].FirstChild;
  While N <> 0 Do Begin
    Inc(ParamCount);
    N := AstTable[N].NextSibling;
  End;
  If (MethodSym > 0) And (MethodSym <= SymCount) Then
    SymTable[MethodSym].ParamCount := ParamCount;
  ConsumeStatementDelims;
  Body := ParseStatementList(KW_END, 0, 0);
  If (MethodSym > 0) And (MethodSym <= SymCount) Then
    SymTable[MethodSym].LocalSize := ScopeNextLocal[ScopeLevel];
  LeaveScope;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour def');
  CurrentMethodSym := PrevMethodSym;
  CurrentMethodName := PrevMethodName;
  ParseDefStatement := NewASTNode(NK_DEF, KW_DEF, 'def', NameNode, Params, Body);
End;

Function ParseClassModuleStatement(IsModule: Boolean): Integer;
Var
  NameNode, ParentNode, Body, Sym, PrevClassRef, PrevVisibility: Integer;
  ParentSym, ClassInfo, EigenOf: Integer;
  ClassName, BaseName: String;
Begin
  PrevClassRef := CurrentClassRef;
  PrevVisibility := CurrentVisibility;
  NextTok;
  If (Not IsModule) And (CurTokType = TOK_SHL) Then Begin
    NextTok;
    NameNode := ParseExpr;
    EigenOf := AstTable[NameNode].SymRef;
    If EigenOf = 0 Then EigenOf := PrevClassRef;
    ClassName := 'Eigen_' + ItoS(EigenOf);
    Sym := AddSym(ClassName, SK_CLASS, RT_CLASS, PrevClassRef);
    SymTable[Sym].Flags := SymTable[Sym].Flags Or SF_CLASS_SINGLETON Or
                           SF_CLASS_EIGEN;
    ClassInfo := AddClassInfo(ClassName, Sym, PrevClassRef, True, EigenOf);
    CurrentClassRef := Sym;
    ParentNode := 0;
  End Else If CurTokType = TOK_CONST Then Begin
    BaseName := CurTokStr;
    ClassName := BaseName;
    NameNode := NewASTNode(NK_CONST, CurTokType, BaseName, 0, 0, 0);
    NextTok;
    While CurTokType = TOK_DCOLON Do Begin
      NextTok;
      If CurTokType = TOK_CONST Then Begin
        ClassName := ClassName + '::' + CurTokStr;
        AstTable[NameNode].Text := ClassName;
        NextTok;
      End Else
        ParseError('constante attendue apres ::');
    End;
    If (Pos('::', ClassName) = 0) And
       (PrevClassRef > 0) And (CurrentClassName <> 'Object') Then Begin
      ClassName := CurrentClassName + '::' + ClassName;
      AstTable[NameNode].Text := ClassName;
    End;
    If IsModule Then Sym := AddSym(ClassName, SK_MODULE, RT_MODULE, PrevClassRef)
    Else Sym := AddSym(ClassName, SK_CLASS, RT_CLASS, FindSym('Object'));
    AstTable[NameNode].SymRef := Sym;
    CurrentClassRef := Sym;
    ParentNode := 0;
    ParentSym := FindSym('Object');
    If (Not IsModule) And (CurTokType = Ord('<')) Then Begin
      NextTok;
      ParentNode := ParseExpr;
      If ParentNode <> 0 Then ParentSym := AstTable[ParentNode].SymRef;
      If ParentSym = 0 Then ParentSym := FindSym('Object');
    End;
    If IsModule Then
      ClassInfo := AddClassInfo(ClassName, Sym, 0, False, 0)
    Else
      ClassInfo := AddClassInfo(ClassName, Sym, ParentSym, False, 0);
  End Else Begin
    ParseError('nom de classe/module attendu');
    NameNode := 0;
    ParentNode := 0;
    ClassInfo := 0;
  End;
  ConsumeStatementDelims;
  If IsModule Then EnterScope(SC_MODULE) Else EnterScope(SC_CLASS);
  Body := ParseStatementList(KW_END, 0, 0);
  LeaveScope;
  CurrentClassRef := PrevClassRef;
  CurrentVisibility := PrevVisibility;
  If CurTokType = KW_END Then NextTok
  Else ParseError('end attendu pour class/module');
  If IsModule Then
    ParseClassModuleStatement := NewASTNode(NK_MODULE, KW_MODULE, 'module', NameNode, Body, 0)
  Else If (ClassInfo <> 0) And ClassTable[ClassInfo].IsSingleton Then
    ParseClassModuleStatement := NewASTNode(NK_CLASS, KW_CLASS, 'class<<', NameNode, Body, 0)
  Else
    ParseClassModuleStatement := NewASTNode(NK_CLASS, KW_CLASS, 'class', NameNode, ParentNode, Body);
End;

Function ParseHookStatement(IsEndHook: Boolean): Integer;
Var
  Body, Kind: Integer;
Begin
  If IsEndHook Then Kind := NK_END_HOOK Else Kind := NK_BEGIN_HOOK;
  NextTok;
  If CurTokType = Ord('{') Then NextTok
  Else ParseError('{ attendu pour BEGIN/END');
  Body := ParseStatementList(Ord('}'), 0, 0);
  If CurTokType = Ord('}') Then NextTok
  Else ParseError('} attendu pour BEGIN/END');
  If IsEndHook Then ParseHookStatement := NewASTNode(Kind, KW_END_UP, 'END', Body, 0, 0)
  Else ParseHookStatement := NewASTNode(Kind, KW_BEGIN_UP, 'BEGIN', Body, 0, 0);
End;

Function ParseExpressionStatement: Integer;
Var
  Expr, Cond: Integer;
  ModTok: Integer;
Begin
  Expr := ParseExpr;
  If IsModifierKeyword(CurTokType) Then Begin
    ModTok := CurTokType;
    NextTok;
    Cond := ParseConditionExpr;
    If ModTok = KW_IF Then Begin
      Expr := NewASTNode(NK_IF, KW_IF, 'if-mod', Cond, Expr, 0);
      AstTable[Expr].SymRef := AddControlInfo(Expr, NK_IF, Cond,
                                              AstTable[Expr].Right, 0,
                                              CTRLF_MODIFIER);
    End
    Else If ModTok = KW_UNLESS Then Begin
      Expr := NewASTNode(NK_UNLESS, KW_UNLESS, 'unless-mod', Cond, Expr, 0);
      AstTable[Expr].SymRef := AddControlInfo(Expr, NK_UNLESS, Cond,
                                              AstTable[Expr].Right, 0,
                                              CTRLF_UNLESS Or CTRLF_MODIFIER);
    End
    Else If ModTok = KW_WHILE Then Begin
      Expr := NewASTNode(NK_WHILE, KW_WHILE, 'while-mod', Cond, Expr, 0);
      AstTable[Expr].SymRef := AddControlInfo(Expr, NK_WHILE, Cond,
                                              AstTable[Expr].Right, 0,
                                              CTRLF_LOOP Or CTRLF_WHILE Or
                                              CTRLF_MODIFIER);
    End
    Else If ModTok = KW_UNTIL Then Begin
      Expr := NewASTNode(NK_UNTIL, KW_UNTIL, 'until-mod', Cond, Expr, 0);
      AstTable[Expr].SymRef := AddControlInfo(Expr, NK_UNTIL, Cond,
                                              AstTable[Expr].Right, 0,
                                              CTRLF_LOOP Or CTRLF_UNTIL Or
                                              CTRLF_MODIFIER);
    End
    Else If ModTok = KW_RESCUE Then Begin
      Expr := NewASTNode(NK_RESCUE, KW_RESCUE, 'rescue-mod', Expr, Cond, 0);
      AstTable[Expr].SymRef := AddRescueInfo(Expr, AstTable[Expr].Left, 0,
                                             AstTable[Expr].Right, 0,
                                             RESCF_HAS_RESCUE Or
                                             RESCF_MODIFIER Or RESCF_DEFAULT);
    End;
  End;
  ParseExpressionStatement := Expr;
End;

Function ParseStatement: Integer;
Begin
  ConsumeStatementDelims;
  Case CurTokType Of
    KW_IF: ParseStatement := ParseIfStatement(False);
    KW_UNLESS: ParseStatement := ParseIfStatement(True);
    KW_WHILE: ParseStatement := ParseWhileStatement(False);
    KW_UNTIL: ParseStatement := ParseWhileStatement(True);
    KW_FOR: ParseStatement := ParseForStatement;
    KW_LOOP: ParseStatement := ParseLoopStatement;
    KW_CASE: ParseStatement := ParseCaseStatement;
    KW_BEGIN: ParseStatement := ParseBeginStatement;
    KW_DEF: ParseStatement := ParseDefStatement;
    KW_CLASS: ParseStatement := ParseClassModuleStatement(False);
    KW_MODULE: ParseStatement := ParseClassModuleStatement(True);
    KW_RETURN: ParseStatement := ParseControlValue(NK_RETURN, 'return');
    KW_BREAK: ParseStatement := ParseLoopControlStatement(NK_BREAK, KW_BREAK, 'break');
    KW_NEXT: ParseStatement := ParseLoopControlStatement(NK_NEXT, KW_NEXT, 'next');
    KW_REDO: ParseStatement := ParseLoopControlStatement(NK_REDO, KW_REDO, 'redo');
    KW_RETRY: ParseStatement := ParseRetryStatement;
    KW_YIELD: ParseStatement := ParseYieldStatement;
    KW_RAISE: ParseStatement := ParseRaiseStatement;
    KW_ALIAS: ParseStatement := ParseAliasStatement;
    KW_UNDEF: ParseStatement := ParseUndefStatement;
    KW_PRIVATE: ParseStatement := ParseVisibilityStatement(VIS_PRIVATE);
    KW_PUBLIC: ParseStatement := ParseVisibilityStatement(VIS_PUBLIC);
    KW_PROTECTED: ParseStatement := ParseVisibilityStatement(VIS_PROTECTED);
    KW_INCLUDE: ParseStatement := ParseMixinStatement(KW_INCLUDE);
    KW_EXTEND: ParseStatement := ParseMixinStatement(KW_EXTEND);
    KW_PREPEND: ParseStatement := ParseMixinStatement(KW_PREPEND);
    KW_MODULE_FUNCTION: ParseStatement := ParseModuleFunctionStatement;
    KW_BEGIN_UP: ParseStatement := ParseHookStatement(False);
    KW_END_UP: ParseStatement := ParseHookStatement(True);
    KW_REQUIRE, KW_REQUIRE_RELATIVE, KW_LOAD: ParseStatement := ParseRequireStatement(CurTokType);
  Else
    If IsExprEnd(CurTokType) Then
      ParseStatement := NewASTNode(NK_EMPTY, 0, '', 0, 0, 0)
    Else
      ParseStatement := ParseExpressionStatement;
  End;
End;

Function ParseStatementList(End1, End2, End3: Integer): Integer;
Var
  L, S: Integer;
Begin
  L := NewASTNode(NK_STMT_LIST, 0, 'stmts', 0, 0, 0);
  ConsumeStatementDelims;
  While Not IsStatementEndToken(CurTokType, End1, End2, End3) Do Begin
    S := ParseStatement;
    If AstTable[S].Kind <> NK_EMPTY Then AddChild(L, S);
    ConsumeStatementDelims;
  End;
  ParseStatementList := L;
End;

Function ParseProgram: Integer;
Begin
  InitAST;
  LexInit(Opt.SrcFile);
  NextTok;
  ParseProgram := ParseStatementList(TOK_EOF, 0, 0);
  LexClose;
End;

Procedure DumpProgram;
Var
  Root: Integer;
Begin
  Root := ParseProgram;
  WriteLn('Program AST:');
  DumpASTNode(Root, 2);
  If ParseErrors <> 0 Then
    WriteLn('Erreurs parse: ', ParseErrors);
End;

Procedure DumpASTNode(N, Indent: Integer);
Var
  I, C: Integer;
  Pad: String;
Begin
  If N = 0 Then Exit;
  Pad := '';
  For I := 1 To Indent Do Pad := Pad + ' ';
  WriteLn(Pad, N:0, ' ', NodeKindName(AstTable[N].Kind),
          ' tok=', TokenName(AstTable[N].Tok),
          ' text="', AstTable[N].Text, '"');
  If AstTable[N].SymRef <> 0 Then Begin
    If (AstTable[N].Kind = NK_LITERAL) And
       ((AstTable[N].Tok = TOK_INTEGER) Or
        (AstTable[N].Tok = TOK_FLOAT)) Then
      WriteLn(Pad, '  num=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_STRING Then
      WriteLn(Pad, '  str=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_SYMBOL Then
      WriteLn(Pad, '  symbol=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_REGEX Then
      WriteLn(Pad, '  regex=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_RANGE Then
      WriteLn(Pad, '  range=', AstTable[N].SymRef:0)
    Else If (AstTable[N].Kind = NK_BINARY) And
            ((AstTable[N].Tok = TOK_MATCH) Or
             (AstTable[N].Tok = TOK_NMATCH)) Then
      WriteLn(Pad, '  match-data=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_ARRAY Then
      WriteLn(Pad, '  array=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_HASH Then
      WriteLn(Pad, '  hash=', AstTable[N].SymRef:0)
    Else If (AstTable[N].Kind = NK_BLOCK) Or
            (AstTable[N].Kind = NK_PROC) Or
            (AstTable[N].Kind = NK_LAMBDA) Then
      WriteLn(Pad, '  block=', AstTable[N].SymRef:0)
    Else If (AstTable[N].Kind = NK_IF) Or
            (AstTable[N].Kind = NK_UNLESS) Or
            (AstTable[N].Kind = NK_WHILE) Or
            (AstTable[N].Kind = NK_UNTIL) Or
            (AstTable[N].Kind = NK_FOR) Or
            (AstTable[N].Kind = NK_CASE) Or
            (AstTable[N].Kind = NK_TERNARY) Or
            ((AstTable[N].Kind = NK_CALL) And
             (AstTable[N].SymRef <= ControlCount)) Or
            (((AstTable[N].Tok = TOK_ANDAND) Or (AstTable[N].Tok = TOK_OROR) Or
              (AstTable[N].Tok = KW_AND) Or (AstTable[N].Tok = KW_OR)) And
             (AstTable[N].Kind = NK_BINARY)) Then
      WriteLn(Pad, '  control=', AstTable[N].SymRef:0)
    Else If (AstTable[N].Kind = NK_BEGIN) Or
            (AstTable[N].Kind = NK_RESCUE) Then
      WriteLn(Pad, '  rescue=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_RAISE Then
      WriteLn(Pad, '  raise-class=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_RETRY Then
      WriteLn(Pad, '  retry-control=', AstTable[N].SymRef:0)
    Else If (AstTable[N].Kind = NK_BREAK) Or
            (AstTable[N].Kind = NK_NEXT) Or
            (AstTable[N].Kind = NK_REDO) Then
      WriteLn(Pad, '  loop-control=', AstTable[N].SymRef:0)
    Else
      WriteLn(Pad, '  sym=', AstTable[N].SymRef:0);
  End;
  DumpASTNode(AstTable[N].Left, Indent + 2);
  DumpASTNode(AstTable[N].Right, Indent + 2);
  DumpASTNode(AstTable[N].Third, Indent + 2);
  C := AstTable[N].FirstChild;
  While C <> 0 Do Begin
    DumpASTNode(C, Indent + 2);
    C := AstTable[C].NextSibling;
  End;
End;

Procedure DumpExpressions;
Var
  Root: Integer;
Begin
  InitAST;
  LexInit(Opt.SrcFile);
  NextTok;
  While CurTokType <> TOK_EOF Do Begin
    SkipExprNewlines;
    If CurTokType = TOK_EOF Then Break;
    If IsExprEnd(CurTokType) Then Begin
      NextTok;
    End Else Begin
      Root := ParseExpr;
      WriteLn('Expression AST:');
      DumpASTNode(Root, 2);
      While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_NEWLINE) Do
        NextTok;
    End;
  End;
  LexClose;
  If ParseErrors <> 0 Then
    WriteLn('Erreurs parse: ', ParseErrors);
End;

Var
  AsmOut: Text;
  AsmLabelSerial: Integer;

Function AsmOutputFileName: String;
Begin
  AsmOutputFileName := ChangeExt(Opt.OutFile, '.asm');
End;

Function SymDataAsmName(SymRef: Integer): String;
Begin
  If (SymRef <= 0) Or (SymRef > SymCount) Then Begin
    SymDataAsmName := ASM_PFX_RUNTIME + 'unknown';
    Exit;
  End;
  If SymTable[SymRef].AsmName <> '' Then Begin
    SymDataAsmName := SymTable[SymRef].AsmName;
    Exit;
  End;
  Case SymTable[SymRef].Kind Of
    SK_GVAR: SymDataAsmName := ASM_PFX_GVAR + ItoS(SymRef) + '_' +
                               AsmIdent(SymTable[SymRef].Name);
    SK_CONST: SymDataAsmName := ASM_PFX_CONST + ItoS(SymRef) + '_' +
                                AsmIdent(SymTable[SymRef].Name);
    SK_IVAR: SymDataAsmName := ASM_PFX_RUNTIME + 'ivar_' +
                               AsmIdent(SymTable[SymRef].Name);
    SK_CVAR: SymDataAsmName := ASM_PFX_RUNTIME + 'cvar_' +
                               AsmIdent(SymTable[SymRef].Name);
  Else
    SymDataAsmName := ASM_PFX_RUNTIME + 'sym_' + ItoS(SymRef);
  End;
End;

Function CodeLabel(Prefix: String): String;
Begin
  Inc(AsmLabelSerial);
  CodeLabel := ASM_PFX_LABEL + Prefix + '_' + ItoS(AsmLabelSerial);
End;

Procedure Emit(S: String);
Begin
  WriteLn(AsmOut, '    ', S);
End;

Procedure EmitRaw(S: String);
Begin
  WriteLn(AsmOut, S);
End;

Procedure EmitComment(S: String);
Begin
  WriteLn(AsmOut, '    ; ', S);
End;

Procedure EmitLabel(L: String);
Begin
  WriteLn(AsmOut, L, ':');
End;

Procedure GenPush;
Begin
  Emit('push eax');
End;

Procedure GenPop(RegName: String);
Begin
  Emit('pop ' + RegName);
End;

Function CleanIntegerText(S: String): String;
Var
  I: Integer;
  C: Char;
  R: String;
Begin
  R := '';
  For I := 1 To Length(S) Do Begin
    C := S[I];
    If (C <> '_') And (C <> 'r') And (C <> 'i') Then
      R := R + C;
  End;
  CleanIntegerText := R;
End;

Function IntLiteralValue(S: String): LongInt;
Var
  T: String;
  V: LongInt;
  Code: Integer;
Begin
  T := CleanIntegerText(S);
  Val(T, V, Code);
  If Code <> 0 Then V := 0;
  IntLiteralValue := V;
End;

Function FixnumValue(V: LongInt): LongInt;
Begin
  FixnumValue := (V Shl 1) Or RV_FIXNUM_TAG;
End;

Procedure GenLoadInt(V: LongInt);
Begin
  Emit('mov eax, ' + ItoS(FixnumValue(V)) + ' ; Fixnum ' + ItoS(V));
End;

Procedure GenLoadStr(LblIdx: Integer);
Begin
  If (LblIdx > 0) And (LblIdx <= StringCount) Then
    Emit('lea eax, ' + StringTable[LblIdx].AsmName)
  Else
    Emit('mov eax, ' + ItoS(RV_NIL));
End;

Procedure GenLoadVar(SymRef: Integer);
Begin
  If (SymRef <= 0) Or (SymRef > SymCount) Then Begin
    Emit('mov eax, ' + ItoS(RV_NIL));
    Exit;
  End;
  Case SymTable[SymRef].Kind Of
    SK_LOCAL, SK_PARAM, SK_BLOCK_PARAM:
      If SymTable[SymRef].Offset < 0 Then
        Emit('mov eax, [ebp' + ItoS(SymTable[SymRef].Offset) + ']')
      Else
        Emit('mov eax, [ebp+' + ItoS(SymTable[SymRef].Offset) + ']');
    SK_GVAR, SK_CONST, SK_CVAR:
      Emit('mov eax, [' + SymDataAsmName(SymRef) + ']');
    SK_IVAR:
      Emit('mov eax, [ecx+' + ItoS(SymTable[SymRef].Offset) + ']');
    SK_CLASS, SK_MODULE:
      Emit('lea eax, ' + SymDataAsmName(SymRef));
  Else
    Emit('mov eax, ' + ItoS(RV_NIL));
  End;
End;

Procedure GenStoreVar(SymRef: Integer);
Begin
  If (SymRef <= 0) Or (SymRef > SymCount) Then Exit;
  Case SymTable[SymRef].Kind Of
    SK_LOCAL, SK_PARAM, SK_BLOCK_PARAM:
      If SymTable[SymRef].Offset < 0 Then
        Emit('mov [ebp' + ItoS(SymTable[SymRef].Offset) + '], eax')
      Else
        Emit('mov [ebp+' + ItoS(SymTable[SymRef].Offset) + '], eax');
    SK_GVAR, SK_CONST, SK_CVAR:
      Emit('mov [' + SymDataAsmName(SymRef) + '], eax');
    SK_IVAR:
      Emit('mov [ecx+' + ItoS(SymTable[SymRef].Offset) + '], eax');
  End;
End;

Procedure GenLoadIvar(SymRef: Integer);
Begin
  If (SymRef > 0) And (SymRef <= SymCount) Then
    Emit('mov eax, [ecx+' + ItoS(SymTable[SymRef].Offset) + ']')
  Else
    Emit('mov eax, ' + ItoS(RV_NIL));
End;

Procedure GenStoreIvar(SymRef: Integer);
Begin
  If (SymRef > 0) And (SymRef <= SymCount) Then
    Emit('mov [ecx+' + ItoS(SymTable[SymRef].Offset) + '], eax');
End;

Procedure GenCall(MethodName: String; Argc: Integer);
Begin
  EmitComment('GenCall ' + MethodName + ' argc=' + ItoS(Argc));
  Emit('call ' + ASM_PFX_RUNTIME + 'call_' + AsmIdent(MethodName));
  If Argc > 0 Then Emit('add esp, ' + ItoS(Argc * 4));
End;

Procedure GenSend(Selector: String; Argc: Integer);
Begin
  EmitComment('GenSend ' + Selector + ' argc=' + ItoS(Argc) +
              ' ; ECX=self, EDX=block');
  Emit('push OFFSET ' + ASM_PFX_SYMBOL + 'sel_' + AsmIdent(Selector));
  Emit('call ' + ASM_PFX_RUNTIME + 'dispatch');
  If Argc > 0 Then Emit('add esp, ' + ItoS(Argc * 4));
End;

Procedure GenYield(Argc: Integer);
Begin
  EmitComment('GenYield argc=' + ItoS(Argc));
  Emit('call ' + ASM_PFX_RUNTIME + 'yield');
  If Argc > 0 Then Emit('add esp, ' + ItoS(Argc * 4));
End;

Procedure GenAlloc(ClassRef: Integer);
Begin
  Emit('push OFFSET ' + SymDataAsmName(ClassRef));
  Emit('call ' + ASM_PFX_RUNTIME + 'alloc');
End;

Procedure GenJmp(L: String);
Begin
  Emit('jmp ' + L);
End;

Procedure GenJZ(L: String);
Begin
  Emit('cmp eax, ' + ItoS(RV_FALSE));
  Emit('je ' + L);
  Emit('cmp eax, ' + ItoS(RV_NIL));
  Emit('je ' + L);
End;

Procedure GenJNZ(L: String);
Begin
  Emit('cmp eax, ' + ItoS(RV_FALSE));
  Emit('je SHORT $+7');
  Emit('cmp eax, ' + ItoS(RV_NIL));
  Emit('jne ' + L);
End;

Procedure GenAdd;
Begin
  GenPop('ebx');
  Emit('sub eax, ' + ItoS(RV_FIXNUM_TAG));
  Emit('add eax, ebx');
End;

Procedure GenSub;
Begin
  GenPop('ebx');
  Emit('sub ebx, eax');
  Emit('add ebx, ' + ItoS(RV_FIXNUM_TAG));
  Emit('mov eax, ebx');
End;

Procedure GenMul;
Begin
  GenPop('ebx');
  Emit('sar eax, 1');
  Emit('sar ebx, 1');
  Emit('imul eax, ebx');
  Emit('shl eax, 1');
  Emit('or eax, ' + ItoS(RV_FIXNUM_TAG));
End;

Procedure GenDiv;
Begin
  GenPop('ebx');
  Emit('sar eax, 1');
  Emit('sar ebx, 1');
  Emit('mov ecx, eax');
  Emit('mov eax, ebx');
  Emit('cdq');
  Emit('idiv ecx');
  Emit('shl eax, 1');
  Emit('or eax, ' + ItoS(RV_FIXNUM_TAG));
End;

Procedure GenNode(N: Integer); Forward;

Procedure GenArgs(Args: Integer; Var Argc: Integer);
Var
  C: Integer;
Begin
  If Args = 0 Then Exit;
  C := AstTable[Args].FirstChild;
  While C <> 0 Do Begin
    GenNode(C);
    GenPush;
    Inc(Argc);
    C := AstTable[C].NextSibling;
  End;
End;

Function CallName(N: Integer): String;
Var
  T: Integer;
Begin
  CallName := 'call';
  If N = 0 Then Exit;
  If AstTable[N].Third <> 0 Then Begin
    CallName := NodeMethodName(AstTable[N].Third);
    Exit;
  End;
  T := AstTable[N].Left;
  If T <> 0 Then CallName := AstTable[T].Text;
End;

Procedure GenComparison(OpText: String);
Var
  LTrue, LEnd: String;
Begin
  LTrue := CodeLabel('CMP_TRUE');
  LEnd := CodeLabel('CMP_END');
  GenPop('ebx');
  Emit('cmp ebx, eax');
  If OpText = '==' Then Emit('je ' + LTrue)
  Else If OpText = '!=' Then Emit('jne ' + LTrue)
  Else If OpText = '<' Then Emit('jl ' + LTrue)
  Else If OpText = '>' Then Emit('jg ' + LTrue)
  Else If OpText = '<=' Then Emit('jle ' + LTrue)
  Else If OpText = '>=' Then Emit('jge ' + LTrue)
  Else Emit('je ' + LTrue);
  Emit('mov eax, ' + ItoS(RV_FALSE));
  GenJmp(LEnd);
  EmitLabel(LTrue);
  Emit('mov eax, ' + ItoS(RV_TRUE));
  EmitLabel(LEnd);
End;

Procedure GenCallNode(N: Integer);
Var
  Argc: Integer;
  Name: String;
Begin
  Argc := 0;
  Name := CallName(N);
  If AstTable[N].Text = 'bare-call' Then Begin
    GenArgs(AstTable[N].Right, Argc);
    GenCall(Name, Argc);
  End Else Begin
    GenNode(AstTable[N].Left);
    Emit('mov ecx, eax');
    GenArgs(AstTable[N].Right, Argc);
    GenSend(Name, Argc);
  End;
End;

Procedure GenStmtList(N: Integer);
Var
  C: Integer;
Begin
  C := AstTable[N].FirstChild;
  While C <> 0 Do Begin
    GenNode(C);
    C := AstTable[C].NextSibling;
  End;
End;

Procedure GenIfNode(N: Integer; Invert: Boolean);
Var
  LElse, LEnd: String;
Begin
  LElse := CodeLabel('ELSE');
  LEnd := CodeLabel('ENDIF');
  GenNode(AstTable[N].Left);
  If Invert Then GenJNZ(LElse) Else GenJZ(LElse);
  GenNode(AstTable[N].Right);
  GenJmp(LEnd);
  EmitLabel(LElse);
  GenNode(AstTable[N].Third);
  EmitLabel(LEnd);
End;

Procedure GenWhileNode(N: Integer; Invert: Boolean);
Var
  LStart, LEnd: String;
Begin
  LStart := CodeLabel('LOOP');
  LEnd := CodeLabel('ENDLOOP');
  EmitLabel(LStart);
  GenNode(AstTable[N].Left);
  If Invert Then GenJNZ(LEnd) Else GenJZ(LEnd);
  GenNode(AstTable[N].Right);
  GenJmp(LStart);
  EmitLabel(LEnd);
End;

Procedure GenBinaryNode(N: Integer);
Begin
  GenNode(AstTable[N].Left);
  GenPush;
  GenNode(AstTable[N].Right);
  Case AstTable[N].Tok Of
    Ord('+'): GenAdd;
    Ord('-'): GenSub;
    Ord('*'): GenMul;
    Ord('/'): GenDiv;
    TOK_EQ: GenComparison('==');
    TOK_NE: GenComparison('!=');
    Ord('<'): GenComparison('<');
    Ord('>'): GenComparison('>');
    TOK_LE: GenComparison('<=');
    TOK_GE: GenComparison('>=');
  Else
    GenPop('ebx');
    EmitComment('operateur Ruby non specialise: ' + AstTable[N].Text);
    GenCall('binary_' + AsmIdent(AstTable[N].Text), 0);
  End;
End;

Procedure GenMethodNode(N: Integer);
Var
  MethodRef: Integer;
  MethodLabel: String;
Begin
  MethodRef := AstTable[N].SymRef;
  If (MethodRef > 0) And (MethodRef <= SymCount) And
     (SymTable[MethodRef].AsmName <> '') Then
    MethodLabel := SymTable[MethodRef].AsmName
  Else
    MethodLabel := ASM_PFX_METHOD + AsmIdent(AstTable[N].Text) + '_' +
                   ItoS(N);
  EmitRaw('');
  EmitRaw(MethodLabel + ' PROC');
  Emit('push ebp');
  Emit('mov ebp, esp');
  Emit('sub esp, 64');
  GenNode(AstTable[N].Third);
  Emit('mov esp, ebp');
  Emit('pop ebp');
  Emit('ret');
  EmitRaw(MethodLabel + ' ENDP');
End;

Procedure GenNode(N: Integer);
Begin
  If N = 0 Then Begin
    Emit('mov eax, ' + ItoS(RV_NIL));
    Exit;
  End;
  Case AstTable[N].Kind Of
    NK_STMT_LIST:
      GenStmtList(N);
    NK_LITERAL:
      If AstTable[N].Tok = TOK_INTEGER Then
        GenLoadInt(IntLiteralValue(AstTable[N].Text))
      Else If AstTable[N].Tok = TOK_FLOAT Then Begin
        EmitComment('float literal ' + AstTable[N].Text);
        Emit('lea eax, ' + NumLitTable[AstTable[N].SymRef].AsmName);
      End Else
        Emit('mov eax, ' + ItoS(RV_NIL));
    NK_STRING:
      GenLoadStr(AstTable[N].SymRef);
    NK_SYMBOL:
      If (AstTable[N].SymRef > 0) And (AstTable[N].SymRef <= SymbolLitCount) Then
        Emit('mov eax, ' + ItoS(SymbolLitTable[AstTable[N].SymRef].Value))
      Else
        Emit('mov eax, ' + ItoS(RV_NIL));
    NK_VAR, NK_CONST:
      GenLoadVar(AstTable[N].SymRef);
    NK_ASSIGN:
      Begin
        GenNode(AstTable[N].Right);
        If AstTable[AstTable[N].Left].Kind = NK_VAR Then
          GenStoreVar(AstTable[AstTable[N].Left].SymRef)
        Else
          EmitComment('affectation complexe non specialisee');
      End;
    NK_BINARY:
      GenBinaryNode(N);
    NK_CALL:
      GenCallNode(N);
    NK_IF:
      GenIfNode(N, False);
    NK_UNLESS:
      GenIfNode(N, True);
    NK_WHILE:
      GenWhileNode(N, False);
    NK_UNTIL:
      GenWhileNode(N, True);
    NK_RETURN:
      Begin
        GenNode(AstTable[N].Left);
        Emit('mov esp, ebp');
        Emit('pop ebp');
        Emit('ret');
      End;
    NK_YIELD:
      Begin
        EmitComment('yield');
        GenYield(0);
      End;
    NK_DEF:
      GenMethodNode(N);
    NK_CLASS, NK_MODULE:
      Begin
        EmitComment(NodeKindName(AstTable[N].Kind) + ' ' + AstTable[N].Text);
        GenNode(AstTable[N].Right);
      End;
    NK_REQUIRE:
      EmitComment('require/load ' + AstTable[N].Text);
    NK_EMPTY:
      Emit('mov eax, ' + ItoS(RV_NIL));
  Else
    EmitComment('noeud non encore codegen: ' + NodeKindName(AstTable[N].Kind));
    Emit('mov eax, ' + ItoS(RV_NIL));
  End;
End;

Procedure EmitAsmStringData;
Var
  I, J, Col: Integer;
Begin
  For I := 1 To StringCount Do Begin
    Write(AsmOut, StringTable[I].AsmName, ' DB ');
    Col := 0;
    For J := 1 To Length(StringTable[I].Text) Do Begin
      If Col > 0 Then Write(AsmOut, ',');
      Write(AsmOut, Ord(StringTable[I].Text[J]):0);
      Inc(Col);
      If (Col = 16) And (J < Length(StringTable[I].Text)) Then Begin
        WriteLn(AsmOut);
        Write(AsmOut, '    DB ');
        Col := 0;
      End;
    End;
    If Col > 0 Then Write(AsmOut, ',');
    WriteLn(AsmOut, '0');
  End;
End;

Procedure EmitAsmData;
Var
  I: Integer;
Begin
  EmitRaw('.DATA');
  EmitAsmStringData;
  For I := 1 To NumLitCount Do
    EmitRaw(NumLitTable[I].AsmName + ' DD 0 ; ' + NumLitTable[I].Text);
  For I := 1 To SymbolLitCount Do
    EmitRaw(SymbolLitTable[I].AsmName + ' DD ' +
            ItoS(SymbolLitTable[I].Value) + ' ; :' +
            SymbolLitTable[I].Name);
  For I := 1 To RegexLitCount Do
    EmitRaw(RegexLitTable[I].AsmName + ' DD 0 ; /' +
            RegexLitTable[I].Pattern + '/');
  For I := 1 To SymCount Do
    If SymTable[I].Kind = SK_GVAR Then
      EmitRaw(SymDataAsmName(I) + ' DD ' + ItoS(RV_NIL));
  EmitRaw('');
End;

Procedure EmitAsmHeader;
Begin
  EmitRaw('; RUBYCW32 - sortie assembleur generee');
  EmitRaw('; Source: ' + Opt.SrcFile);
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitRaw('OPTION CASEMAP:NONE');
  EmitRaw('');
  EmitRaw('ExitProcess PROTO :DWORD');
  EmitRaw('EXTRN ' + ASM_PFX_RUNTIME + 'main_start:PROC');
  EmitRaw('EXTRN ' + ASM_PFX_RUNTIME + 'dispatch:PROC');
  EmitRaw('EXTRN ' + ASM_PFX_RUNTIME + 'yield:PROC');
  EmitRaw('EXTRN ' + ASM_PFX_RUNTIME + 'alloc:PROC');
  EmitRaw('');
End;

Procedure EmitAsmMain(Root: Integer);
Begin
  EmitRaw('.CODE');
  EmitRaw('_RBSTART PROC');
  Emit('call ' + ASM_PFX_RUNTIME + 'main_start');
  Emit('call _RBMAIN');
  Emit('push 0');
  Emit('call ExitProcess');
  EmitRaw('_RBSTART ENDP');
  EmitRaw('');
  EmitRaw('_RBMAIN PROC');
  Emit('push ebp');
  Emit('mov ebp, esp');
  Emit('sub esp, 256');
  Emit('xor edx, edx ; bloc courant = nil');
  Emit('mov ecx, ' + ItoS(RV_NIL) + ' ; self top-level');
  GenNode(Root);
  Emit('mov esp, ebp');
  Emit('pop ebp');
  Emit('ret');
  EmitRaw('_RBMAIN ENDP');
  EmitRaw('');
  EmitRaw('END _RBSTART');
End;

Procedure GenerateAsm;
Var
  Root: Integer;
  FileName: String;
Begin
  Root := ParseProgram;
  If ParseErrors <> 0 Then
    FatalError('generation ASM impossible: erreurs parse');
  FileName := AsmOutputFileName;
  Assign(AsmOut, FileName);
  Rewrite(AsmOut);
  AsmLabelSerial := 0;
  EmitAsmHeader;
  EmitAsmData;
  EmitAsmMain(Root);
  Close(AsmOut);
  WriteLn('ASM genere : ', FileName);
End;

Function AlignUp(V, A: LongInt): LongInt;
Begin
  If A <= 0 Then AlignUp := V
  Else AlignUp := ((V + A - 1) Div A) * A;
End;

Procedure BinClear;
Begin
  FillChar(BinCode, SizeOf(BinCode), 0);
  FillChar(BinData, SizeOf(BinData), 0);
  FillChar(BinRData, SizeOf(BinRData), 0);
  FillChar(BinLabels, SizeOf(BinLabels), 0);
  FillChar(BinFixups, SizeOf(BinFixups), 0);
  FillChar(BinImports, SizeOf(BinImports), 0);
  BinCodeSize := 0;
  BinDataSize := 0;
  BinRDataSize := 0;
  BinBssSize := 0;
  BinLabelCount := 0;
  BinFixupCount := 0;
  BinImportCount := 0;
End;

Procedure BufEmit8(Var B: TBinBuffer; Var S: LongInt; V: Integer);
Begin
  If S >= MAX_BIN Then FatalError('buffer binaire plein');
  B[S] := V And $FF;
  Inc(S);
End;

Procedure BufEmit16(Var B: TBinBuffer; Var S: LongInt; V: LongInt);
Begin
  BufEmit8(B, S, V);
  BufEmit8(B, S, V Shr 8);
End;

Procedure BufEmit32(Var B: TBinBuffer; Var S: LongInt; V: LongInt);
Begin
  BufEmit8(B, S, V);
  BufEmit8(B, S, V Shr 8);
  BufEmit8(B, S, V Shr 16);
  BufEmit8(B, S, V Shr 24);
End;

Procedure BinEmit8(V: Integer);
Begin
  BufEmit8(BinCode, BinCodeSize, V);
End;

Procedure BinEmit16(V: LongInt);
Begin
  BufEmit16(BinCode, BinCodeSize, V);
End;

Procedure BinEmit32(V: LongInt);
Begin
  BufEmit32(BinCode, BinCodeSize, V);
End;

Procedure BinPatch32(Offset, V: LongInt);
Begin
  If (Offset < 0) Or (Offset + 3 >= MAX_BIN) Then
    FatalError('patch binaire hors limites');
  BinCode[Offset] := V And $FF;
  BinCode[Offset + 1] := (V Shr 8) And $FF;
  BinCode[Offset + 2] := (V Shr 16) And $FF;
  BinCode[Offset + 3] := (V Shr 24) And $FF;
End;

Function BinFindLabel(Name: String): Integer;
Var
  I: Integer;
Begin
  BinFindLabel := 0;
  For I := 1 To BinLabelCount Do
    If BinLabels[I].Name = Name Then Begin
      BinFindLabel := I;
      Exit;
    End;
End;

Function BinDefineLabel(Name: String): Integer;
Var
  I: Integer;
Begin
  I := BinFindLabel(Name);
  If I = 0 Then Begin
    If BinLabelCount >= MAX_BIN_LABEL Then FatalError('table labels binaire pleine');
    Inc(BinLabelCount);
    I := BinLabelCount;
    BinLabels[I].Name := Name;
  End;
  BinLabels[I].Section := BIN_SEC_TEXT;
  BinLabels[I].Offset := BinCodeSize;
  BinLabels[I].Defined := True;
  BinDefineLabel := I;
End;

Function BinAddLabel(Name: String): Integer;
Var
  I: Integer;
Begin
  I := BinFindLabel(Name);
  If I <> 0 Then Begin
    BinAddLabel := I;
    Exit;
  End;
  If BinLabelCount >= MAX_BIN_LABEL Then FatalError('table labels binaire pleine');
  Inc(BinLabelCount);
  BinLabels[BinLabelCount].Name := Name;
  BinLabels[BinLabelCount].Section := BIN_SEC_TEXT;
  BinLabels[BinLabelCount].Offset := 0;
  BinLabels[BinLabelCount].Defined := False;
  BinAddLabel := BinLabelCount;
End;

Procedure BinAddFixup(LabelRef, Kind: Integer; AtOffset: LongInt);
Begin
  If BinFixupCount >= MAX_BIN_FIXUP Then FatalError('table fixups binaire pleine');
  Inc(BinFixupCount);
  BinFixups[BinFixupCount].Section := BIN_SEC_TEXT;
  BinFixups[BinFixupCount].Offset := AtOffset;
  BinFixups[BinFixupCount].LabelRef := LabelRef;
  BinFixups[BinFixupCount].Kind := Kind;
End;

Procedure BinResolveFixups;
Var
  I, L: Integer;
  Target, Rel: LongInt;
Begin
  For I := 1 To BinFixupCount Do Begin
    L := BinFixups[I].LabelRef;
    If (L <= 0) Or (L > BinLabelCount) Or Not BinLabels[L].Defined Then
      FatalError('label binaire non resolu');
    Target := BinLabels[L].Offset;
    If BinFixups[I].Kind = BIN_FIX_REL32 Then Begin
      Rel := Target - (BinFixups[I].Offset + 4);
      BinPatch32(BinFixups[I].Offset, Rel);
    End Else
      BinPatch32(BinFixups[I].Offset, Target);
  End;
End;

Function BinAddImport(DllName, ProcName: String): Integer;
Begin
  If BinImportCount >= MAX_BIN_IMPORT Then FatalError('table imports pleine');
  Inc(BinImportCount);
  BinImports[BinImportCount].DllName := DllName;
  BinImports[BinImportCount].ProcName := ProcName;
  BinImports[BinImportCount].Hint := 0;
  BinImports[BinImportCount].IATRva := 0;
  BinAddImport := BinImportCount;
End;

Procedure BinEmitInstr(Mnemonic: String);
Begin
  If Mnemonic = 'RET' Then BinEmit8($C3)
  Else If Mnemonic = 'PUSH_EAX' Then BinEmit8($50)
  Else If Mnemonic = 'POP_EAX' Then BinEmit8($58)
  Else If Mnemonic = 'XOR_EAX_EAX' Then Begin BinEmit8($31); BinEmit8($C0); End
  Else If Mnemonic = 'CDQ' Then BinEmit8($99)
  Else If Mnemonic = 'LEAVE' Then BinEmit8($C9)
  Else FatalError('instruction binaire inconnue: ' + Mnemonic);
End;

Procedure BinEmitMovEAXImm32(V: LongInt);
Begin
  BinEmit8($B8);
  BinEmit32(V);
End;

Procedure BinEmitPushImm32(V: LongInt);
Begin
  BinEmit8($68);
  BinEmit32(V);
End;

Procedure BinEmitJmp(LabelName: String);
Var
  L: Integer;
  O: LongInt;
Begin
  L := BinAddLabel(LabelName);
  BinEmit8($E9);
  O := BinCodeSize;
  BinEmit32(0);
  BinAddFixup(L, BIN_FIX_REL32, O);
End;

Procedure BinEmitJZ(LabelName: String);
Var
  L: Integer;
  O: LongInt;
Begin
  L := BinAddLabel(LabelName);
  BinEmit8($0F);
  BinEmit8($84);
  O := BinCodeSize;
  BinEmit32(0);
  BinAddFixup(L, BIN_FIX_REL32, O);
End;

Procedure BinEmitJNZ(LabelName: String);
Var
  L: Integer;
  O: LongInt;
Begin
  L := BinAddLabel(LabelName);
  BinEmit8($0F);
  BinEmit8($85);
  O := BinCodeSize;
  BinEmit32(0);
  BinAddFixup(L, BIN_FIX_REL32, O);
End;

Procedure BinBuildRuntimeSkeleton;
Begin
  BinClear;
  BinAddImport('KERNEL32.DLL', 'ExitProcess');
  BinDefineLabel('_RBSTART');
  BinEmitInstr('XOR_EAX_EAX');
  BinEmitInstr('RET');
  BinResolveFixups;
End;

Procedure WriteByte(Var F: File; V: Integer);
Var
  B: Byte;
Begin
  B := V And $FF;
  BlockWrite(F, B, 1);
End;

Procedure WriteWordLE(Var F: File; V: LongInt);
Begin
  WriteByte(F, V);
  WriteByte(F, V Shr 8);
End;

Procedure WriteDWordLE(Var F: File; V: LongInt);
Begin
  WriteByte(F, V);
  WriteByte(F, V Shr 8);
  WriteByte(F, V Shr 16);
  WriteByte(F, V Shr 24);
End;

Procedure WriteZeros(Var F: File; Count: LongInt);
Var
  I: LongInt;
Begin
  For I := 1 To Count Do WriteByte(F, 0);
End;

Procedure WriteName8(Var F: File; Name: String);
Var
  I: Integer;
Begin
  For I := 1 To 8 Do
    If I <= Length(Name) Then WriteByte(F, Ord(Name[I]))
    Else WriteByte(F, 0);
End;

Procedure WriteBuffer(Var F: File; Var B: TBinBuffer; Count: LongInt);
Begin
  If Count > 0 Then BlockWrite(F, B, Count);
End;

Procedure WritePaddedBuffer(Var F: File; Var B: TBinBuffer; Count, AlignTo: LongInt);
Var
  Padded: LongInt;
Begin
  Padded := AlignUp(Count, AlignTo);
  WriteBuffer(F, B, Count);
  WriteZeros(F, Padded - Count);
End;

Procedure WriteCoffSectionHeader(Var F: File; Name: String; RawSize, RawPtr,
                                 RelPtr, RelCount, Flags: LongInt);
Begin
  WriteName8(F, Name);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, RawSize);
  WriteDWordLE(F, RawPtr);
  WriteDWordLE(F, RelPtr);
  WriteDWordLE(F, 0);
  WriteWordLE(F, RelCount);
  WriteWordLE(F, 0);
  WriteDWordLE(F, Flags);
End;

Procedure WriteCoffSymbol(Var F: File; Name: String; Value: LongInt;
                          SectionNumber, StorageClass: Integer);
Begin
  WriteName8(F, Name);
  WriteDWordLE(F, Value);
  WriteWordLE(F, SectionNumber);
  WriteWordLE(F, 0);
  WriteByte(F, StorageClass);
  WriteByte(F, 0);
End;

Procedure GenerateObj;
Var
  F: File;
  TextRaw, DataRaw, RDataRaw, SymPtr: LongInt;
  TextSize, DataSize, RDataSize, SymCountObj: LongInt;
Begin
  ParseProgram;
  If ParseErrors <> 0 Then FatalError('generation OBJ impossible: erreurs parse');
  BinBuildRuntimeSkeleton;
  TextSize := AlignUp(BinCodeSize, 4);
  DataSize := AlignUp(BinDataSize, 4);
  RDataSize := AlignUp(BinRDataSize, 4);
  TextRaw := 20 + 4 * 40;
  DataRaw := TextRaw + TextSize;
  RDataRaw := DataRaw + DataSize;
  SymPtr := RDataRaw + RDataSize;
  SymCountObj := 5;
  Assign(F, Opt.OutFile);
  Rewrite(F, 1);
  WriteWordLE(F, PE_MACHINE_I386);
  WriteWordLE(F, 4);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, SymPtr);
  WriteDWordLE(F, SymCountObj);
  WriteWordLE(F, 0);
  WriteWordLE(F, 0);
  WriteCoffSectionHeader(F, '.text', BinCodeSize, TextRaw, 0, 0,
    PE_SCN_CNT_CODE Or PE_SCN_ALIGN_4BYTES Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);
  WriteCoffSectionHeader(F, '.data', BinDataSize, DataRaw, 0, 0,
    PE_SCN_CNT_INIT_DATA Or PE_SCN_ALIGN_4BYTES Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);
  WriteCoffSectionHeader(F, '.rdata', BinRDataSize, RDataRaw, 0, 0,
    PE_SCN_CNT_INIT_DATA Or PE_SCN_ALIGN_4BYTES Or PE_SCN_MEM_READ);
  WriteCoffSectionHeader(F, '.bss', BinBssSize, 0, 0, 0,
    PE_SCN_CNT_UNINIT_DATA Or PE_SCN_ALIGN_4BYTES Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);
  WritePaddedBuffer(F, BinCode, BinCodeSize, 4);
  WritePaddedBuffer(F, BinData, BinDataSize, 4);
  WritePaddedBuffer(F, BinRData, BinRDataSize, 4);
  WriteCoffSymbol(F, '.text', 0, 1, COFF_SYM_CLASS_STATIC);
  WriteCoffSymbol(F, '.data', 0, 2, COFF_SYM_CLASS_STATIC);
  WriteCoffSymbol(F, '.rdata', 0, 3, COFF_SYM_CLASS_STATIC);
  WriteCoffSymbol(F, '.bss', 0, 4, COFF_SYM_CLASS_STATIC);
  WriteCoffSymbol(F, '_RBSTART', 0, 1, COFF_SYM_CLASS_EXTERNAL);
  WriteDWordLE(F, 4);
  Close(F);
  WriteLn('OBJ COFF genere : ', Opt.OutFile);
End;

Procedure WritePeSectionHeader(Var F: File; Name: String; VirtSize, VirtAddr,
                               RawSize, RawPtr, Flags: LongInt);
Begin
  WriteName8(F, Name);
  WriteDWordLE(F, VirtSize);
  WriteDWordLE(F, VirtAddr);
  WriteDWordLE(F, RawSize);
  WriteDWordLE(F, RawPtr);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, 0);
  WriteWordLE(F, 0);
  WriteWordLE(F, 0);
  WriteDWordLE(F, Flags);
End;

Procedure GenerateExe;
Var
  F: File;
  HeadersSize, TextRawSize, TextRva, ImageSize, I: LongInt;
Begin
  ParseProgram;
  If ParseErrors <> 0 Then FatalError('generation EXE impossible: erreurs parse');
  BinBuildRuntimeSkeleton;
  TextRva := PE_SEC_ALIGN;
  HeadersSize := AlignUp(128 + 4 + 20 + 224 + 40, PE_FILE_ALIGN);
  TextRawSize := AlignUp(BinCodeSize, PE_FILE_ALIGN);
  ImageSize := AlignUp(TextRva + AlignUp(BinCodeSize, PE_SEC_ALIGN), PE_SEC_ALIGN);
  Assign(F, Opt.OutFile);
  Rewrite(F, 1);
  WriteWordLE(F, PE_DOS_MAGIC);
  For I := 1 To 29 Do WriteWordLE(F, 0);
  WriteDWordLE(F, 128);
  WriteZeros(F, 128 - 64);
  WriteDWordLE(F, PE_PE_SIG);
  WriteWordLE(F, PE_MACHINE_I386);
  WriteWordLE(F, 1);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, 0);
  WriteWordLE(F, 224);
  WriteWordLE(F, $0102);
  WriteWordLE(F, PE_OPT_MAGIC_PE32);
  WriteByte(F, 0);
  WriteByte(F, 1);
  WriteDWordLE(F, TextRawSize);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, TextRva);
  WriteDWordLE(F, TextRva);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, PE_IMG_BASE);
  WriteDWordLE(F, PE_SEC_ALIGN);
  WriteDWordLE(F, PE_FILE_ALIGN);
  WriteWordLE(F, 4);
  WriteWordLE(F, 0);
  WriteWordLE(F, 0);
  WriteWordLE(F, 0);
  WriteWordLE(F, 4);
  WriteWordLE(F, 0);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, ImageSize);
  WriteDWordLE(F, HeadersSize);
  WriteDWordLE(F, 0);
  WriteWordLE(F, PE_SUBSYS_CUI);
  WriteWordLE(F, 0);
  WriteDWordLE(F, $00100000);
  WriteDWordLE(F, $00001000);
  WriteDWordLE(F, $00100000);
  WriteDWordLE(F, $00001000);
  WriteDWordLE(F, 0);
  WriteDWordLE(F, 16);
  For I := 1 To 16 Do Begin
    WriteDWordLE(F, 0);
    WriteDWordLE(F, 0);
  End;
  WritePeSectionHeader(F, '.text', BinCodeSize, TextRva, TextRawSize, HeadersSize,
    PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);
  WriteZeros(F, HeadersSize - (128 + 4 + 20 + 224 + 40));
  WritePaddedBuffer(F, BinCode, BinCodeSize, PE_FILE_ALIGN);
  Close(F);
  WriteLn('EXE PE genere : ', Opt.OutFile);
End;

Procedure GenerateBinary;
Begin
  If Opt.EmitObj Then GenerateObj
  Else If Opt.EmitExe Then GenerateExe;
End;

Procedure DumpTokens;
Begin
  LexInit(Opt.SrcFile);
  Repeat
    LexNextToken;
    WriteLn(CurTokLine:5, ':', CurTokCol:3, '  ', TokenName(CurTokType),
            '  ', CurTokStr);
    If CurTokContext <> CTX_NONE Then
      WriteLn('           contexte: ', ContextName(CurTokContext));
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

Procedure RegisterPreloadRequires;
Var
  I: Integer;
Begin
  For I := 1 To Opt.RequireCount Do
    AddRequireInfo(KW_REQUIRE, 0, 0, 0, Opt.RequireLib[I], REQF_PRELOAD);
End;

Begin
  ParseArgs;
  InitSymbols;
  RegisterPreloadRequires;
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
  If Opt.DebugMode Then Begin
    DumpTokens;
    DumpProgram;
    DumpStrings;
    DumpLiterals;
    DumpBlocks;
    DumpControls;
    DumpRescues;
    DumpIOInfos;
    DumpRequireInfos;
    DumpSymbols;
    DumpClasses;
    If Opt.EmitAsm Then GenerateAsm;
    GenerateBinary;
  End Else Begin
    If Opt.EmitAsm Then GenerateAsm;
    GenerateBinary;
  End;
End.
