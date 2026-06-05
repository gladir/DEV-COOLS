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
  MAX_SCOPE = 80;
  MAX_AST = 8192;
  MAX_SRC_TEXT = 65535;
  MAX_MIXIN = 64;
  MAX_STRING_LIT = 1024;
  MAX_ARRAY_LIT = 1024;
  MAX_HASH_LIT = 1024;
  MAX_SYMBOL_LIT = 2048;
  MAX_CONTROL = 2048;

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
  Else If S = 'sprintf' Then IsKeyword := KW_SPRINTF;
End;

Function IsPseudoKeyword(T: Integer): Boolean;
Begin
  IsPseudoKeyword := (T >= KW_ATTR_ACCESSOR) And (T <= KW_SPRINTF);
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
  I, BasicSym, ObjectSym, KernelSym, ExceptionSym, StandardErrorSym,
  RuntimeErrorSym, ArgumentErrorSym, TypeErrorSym, NameErrorSym,
  NoMethodErrorSym, ZeroDivisionErrorSym, IndexErrorSym, KeyErrorSym,
  IOErrorSym, ScriptErrorSym, SignalExceptionSym, SystemExitSym: Integer;
  S: String;
Begin
  FillChar(SymTable, SizeOf(SymTable), 0);
  FillChar(ScopeKind, SizeOf(ScopeKind), 0);
  FillChar(ScopeBase, SizeOf(ScopeBase), 0);
  FillChar(ScopeNextLocal, SizeOf(ScopeNextLocal), 0);
  FillChar(ScopeOwnerClass, SizeOf(ScopeOwnerClass), 0);
  FillChar(ClassTable, SizeOf(ClassTable), 0);
  SymCount := 0;
  ClassCount := 0;
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
  AddClassInfo('BasicObject', BasicSym, 0, False, 0);
  AddClassInfo('Object', ObjectSym, BasicSym, False, 0);
  AddClassInfo('Kernel', KernelSym, 0, False, 0);
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
  AddPseudoConst('ARGV', RT_ARRAY);
  AddPseudoConst('ENV', RT_HASH);
  AddPseudoConst('STDIN', RT_OBJECT);
  AddPseudoConst('STDOUT', RT_OBJECT);
  AddPseudoConst('STDERR', RT_OBJECT);
  ResolveGlobal('$0');
  ResolveGlobal('$~');
  ResolveGlobal('$!');
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
  If (LexPeekChar = '~') Or (LexPeekChar = '!') Then Begin
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
  Else
    NodeKindName := 'none';
  End;
End;

Procedure InitAST;
Begin
  FillChar(AstTable, SizeOf(AstTable), 0);
  FillChar(StringTable, SizeOf(StringTable), 0);
  FillChar(SymbolLitTable, SizeOf(SymbolLitTable), 0);
  FillChar(ArrayLitTable, SizeOf(ArrayLitTable), 0);
  FillChar(HashLitTable, SizeOf(HashLitTable), 0);
  FillChar(BlockTable, SizeOf(BlockTable), 0);
  FillChar(ControlTable, SizeOf(ControlTable), 0);
  FillChar(RescueInfoTable, SizeOf(RescueInfoTable), 0);
  AstCount := 0;
  StringCount := 0;
  SymbolLitCount := 0;
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
    TOK_INTEGER, TOK_FLOAT, TOK_REGEX,
    KW_NIL, KW_FALSE, KW_TRUE:
      Begin
        N := NewASTNode(NK_LITERAL, CurTokType, CurTokStr, 0, 0, 0);
        If CurTokType = TOK_INTEGER Then AstTable[N].Text := CurTokStr;
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
         IsPseudoKeyword(CurTokType) Then Begin
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
                IsCallArgStart(CurTokType) Then Begin
      Args := ParseBareArgList;
      N := NewASTNode(NK_CALL, 0, 'bare-call', N, Args, 0);
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
  L, R, T: Integer;
  S: String;
Begin
  L := ParseLogicalOr;
  If (CurTokType = TOK_DOTDOT) Or (CurTokType = TOK_DOTDOTDOT) Then Begin
    T := CurTokType; S := CurTokStr; NextTok;
    If Not IsExprEnd(CurTokType) Then R := ParseLogicalOr Else R := 0;
    L := NewASTNode(NK_RANGE, T, S, L, R, 0);
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
  Name: String;
Begin
  Name := CurTokStr;
  NextTok;
  ParseRequireStatement := NewASTNode(NK_REQUIRE, TokKind, Name,
                                      ParseOptionalExpr, 0, 0);
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
                          (S = 'select') Or (S = 'reject') Or
                          (S = 'inject') Or (S = 'reduce') Or
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
    If AstTable[N].Kind = NK_STRING Then
      WriteLn(Pad, '  str=', AstTable[N].SymRef:0)
    Else If AstTable[N].Kind = NK_SYMBOL Then
      WriteLn(Pad, '  symbol=', AstTable[N].SymRef:0)
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

Begin
  ParseArgs;
  InitSymbols;
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
    DumpSymbols;
    DumpClasses;
  End Else
    WarnMsg('infrastructure, lexer, symboles, variables, expressions, statements et classes initialises');
End.
