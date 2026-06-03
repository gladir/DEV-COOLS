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

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
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

  TODO 02 - TOKENISEUR RUBY (LEXER)
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
            Type Ruby (dynamique, RT_*) : NIL, FALSE, TRUE,
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

Begin
  WriteLn('RUBYCW32 v0.1 (2026) - Compilateur Ruby -> 80386 PE Win32');
End.