# DEV-COOLS
Suite de commandes pour les développeur écrit en Pascal (Turbo Pascal ou Free Pascal) fonctionnant sous DOS et Windows.

Le projet DEV-COOLS se veut un peu comme une solution de remplacement de BINUTILS des distributions Linux en Pascal.

Il possède également des IDE, comme DEVENV :

<img width="639" height="479" alt="image" src="https://github.com/user-attachments/assets/bc6193a5-1ae5-471b-a9d5-54619b45407b" />

<ul>	
	<li>Lequel supporte un éditeur de texte avec les langages de programmations comme ABAP/4, Ada, Assembleur (8086, 80386, 68000), C, C#, Java, Lua, Modula-3, Pascal, Oberon, Perl, PHP, PL/1, Power FX, Python, Ruby, Rust, SAS, Snobol, Visual Basic 6, Visual Basic .NET, X++,...</li>
	<li>Lequel supporte un éditeur hexadécimal</li>
	<li>Lequel supporte un éditeur de formulaire (.FRM de Visual Basic 6,...).</li>
	<li>Lequel supporte un explorateur de solutions (fichier de solution .sln).</li>
	<li>Lequel supporte les terminals (CMD, PowerShell, Bash, AmigaDOS) en built-in). Les terminals support les disques d'images de fichiers montés pour les émulateurs.</li>
	<li>Le DEVENV possède un émulateur 8086, NES, Amiga, Cray 1, Apple II, Commodore 64, MSX, CoCo 3,... intégré pour les cibles n'étant pas Windows.</li>
	<li>Debogueur pour le 6502, 8086 intégré</li>
	<li>Support de la souris et du clavier</li>
	<li>Aide en ligne de plus de 1 Mo</li>
	<li>Supporte le mode pleine fenetre d'écran (-maxscreen).</li>
</ul>

Il possède également des éditeurs de ressources, comme WORKSHOP :

<img width="637" height="483" alt="image" src="https://github.com/user-attachments/assets/adb5e822-19f9-4aab-8604-0dfe0ff75615" />



<h2>Liste des fichiers</h2>

Voici la liste des différents fichiers proposés dans DEV-COOLS :

<table>
		<tr>
			<th>Nom</th>
			<th>Description</th>	
		</tr>
 		<tr>
		    <td><b>8080Z80.PAS</b></td>
		    <td>Cette commande permet de convertir un code source assembleur de microprocesseur 8080 en code source Z80.</td>
		</tr>	
		<tr>
			<td><b>ADA2BCPL.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage BCPL (.b).</td>
		</tr>
		<tr>
			<td><b>ADA2C.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage C ANSI/C99 (.c).</td>
		</tr>
		<tr>
			<td><b>ADA2DELP.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage Delphi (.pas).</td>
		</tr>
		<tr>
			<td><b>ADA2MOD2.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage Modula-2 (.mod).</td>
		</tr>
		<tr>
			<td><b>ADA2MOD3.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage Modula-3 (.m3).</td>
		</tr>
		<tr>
			<td><b>ADA2OBER.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage Oberon (.Mod).</td>
		</tr>
		<tr>
			<td><b>ADA2PAS.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage Turbo Pascal/Free Pascal.</td>
		</tr>
		<tr>
			<td><b>ADA2PSP.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage PSP - Pascal Server Pages (.psp).</td>
		</tr>
		<tr>
			<td><b>ADA2RUST.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Ada (.adb) vers le langage Rust (.rs).</td>
		</tr>
		<tr>
			<td><b>ADA86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Ada 83/95 pour de l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>ADACW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Ada 83/95 pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>ABAP86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur ABAP/4 pour de l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>ABAPCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur ABAP/4 pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>AL58C86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation Algol 58 pour l'assembleur des microprocesseurs 8086.</td>
		</tr>
		<tr>
			<td><b>AL60C86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Algol 60 pour l'assembleur du microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>AL68C86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Algol 68 pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>ASC2ABAP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source ABAP/4.</td>
		</tr>	
		<tr>
			<td><b>ASC2ADA.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source ADA.</td>
		</tr>	
		<tr>
			<td><b>ASC2AS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source ActionScript.</td>
		</tr>		
		<tr>
			<td><b>ASC2ASP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source ASP (Active Server Pages).</td>
		</tr>	
		<tr>
			<td><b>ASC2AWK.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source AWK.</td>
		</tr>
		<tr>
			<td><b>ASC2BAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source BAS.</td>
		</tr>	
		<tr>
			<td><b>ASC2BASH.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source BASH.</td>
		</tr>	
		<tr>
			<td><b>ASC2BCPL.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source BCPL.</td>
		</tr>	
		<tr>
			<td><b>ASC2C.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source C.</td>
		</tr>
		<tr>
			<td><b>ASC2CFM.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source ColdFusion.</td>
		</tr>
		<tr>
			<td><b>ASC2CPP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source C++.</td>
		</tr>	
		<tr>
			<td><b>ASC2CS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source C# (C Sharp).</td>
		</tr>
		<tr>
			<td><b>ASC2CSP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source CSP (C Server Pages).</td>
		</tr>
		<tr>
			<td><b>ASC2JAVA.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Java.</td>
		</tr>
		<tr>
			<td><b>ASC2JS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source JavaScript.</td>
		</tr>	
		<tr>
			<td><b>ASC2JSP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source JSP (Java Server Pages).</td>
		</tr>
		<tr>
			<td><b>ASC2LOGO.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Logo.</td>
		</tr>
		<tr>
			<td><b>ASC2LSS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source LotusScript.</td>
		</tr>
  	        <tr>
			<td><b>ASC2PAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Pascal.</td>
		</tr>
		<tr>			
			<td><b>ASC2PERL.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Perl.</td>
		</tr>	
		<tr>			
			<td><b>ASC2PHP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source PHP.</td>
		</tr>		
		<tr>
			<td><b>ASC2PSP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source PSP (Pascal Server Pages).</td>
		</tr>	
		<tr>			
			<td><b>ASC2PY.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Python.</td>
		</tr>
		<tr>
			<td><b>ASC2REXX.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source REXX.</td>
		</tr>
		<tr>
			<td><b>ASC2RUBY.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Ruby.</td>
		</tr>
		<tr>
			<td><b>ASC2SAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source SAS.</td>
		</tr>
		<tr>
			<td><b>ASM6502.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation assembleur pour les microprocesseur 6502.</td>
		</tr>
		<tr>
			<td><b>ASM68.PAS</b></td>
			<td>Cette commande permet de lancer le clone du Motorola Macro Assembler (ASM68). Assembleur pour la famille Motorola 68000.</td>
		</tr>
		<tr>
			<td><b>ASM8080.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation assembleur pour les microprocesseur 8080.</td>
		</tr>
		<tr>
			<td><b>ASM86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation assembleur pour les microprocesseur 8086. Cette commande est inspiré de la commande <a href="https://www.gladir.com/OS/CPM86/asm86.htm">ASM86</a> du système d'exploitation CP/M 86.</td>
		</tr>
		<tr>
			<td><b>ASMZ80.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation assembleur pour les microprocesseur Z80.</td>
		</tr>
		<tr>
			<td><b>AWK86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur AWK vers l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>AWKCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur AWK pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>BASIC.PAS</b></td>
			<td>Cette commande permet de lancer l'interpréteur de langage de programmation BASIC.</td>
		</tr>
		<tr>
			<td><b>BCPL86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur BCPL pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>BCPLCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur BCPL vers l'assembleur du microprocesseur 80386 pour Windows 32 bits (Win32 PE).</td>
		</tr>
        <tr>
			<td><b>BIN2BGI.PAS</b></td>
			<td>Cette programme permet l'écriture d'entête de la portion du pilote BGI.</td>
		</tr>
		<tr>
			<td><b>BIN2C.PAS</b></td>
			<td>Cette commande permet de convertir un fichier binaire en tableau de code source C.</td>
		</tr>
		<tr>
			<td><b>BIN2CSP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier binaire en tableau de code source CSP (C Server Pages).</td>
		</tr>	
		<tr>
			<td><b>BIN2PAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier binaire en tableau de code source Pascal.</td>
		</tr>
		<tr>
			<td><b>BIN2PSP.PAS</b></td>
			<td>Cette commande permet de convertir un fichier binaire en tableau de code source PSP (Pascal Server Pages).</td>
		</tr>	
		<tr>
			<td><b>BINLINE.PAS</b></td>
			<td>Cette commande permet de convertir un fichier BIN en code source Pascal Inline.</td>
		</tr>
		<tr>
			<td><b>BUGFIND.PAS</b></td>
			<td>Cette commande permet de rechercher des anomalies dans des fichiers.</td>
		</tr>
		<tr>
			<td><b>C.PAS</b></td>
			<td>Cette commande permet de lancer un interpréteur de langage de programmation C.</td>
		</tr>
		<tr>
			<td><b>C2DELPHI.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier «.C» en «.DPR» (Delphi).</td>
		</tr>
		<tr>
			<td><b>C2OBERON.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier «.C» en «.Mod» (Oberon).</td>
		</tr>
		<tr>
			<td><b>C2PAS.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier «.C» en «.PAS».</td>
		</tr>	
		<tr>
			<td><b>CC09.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C pour le microprocesseur 6809.</td>
		</tr>
		<tr>
			<td><b>CC6502.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C pour le microprocesseur 6502.</td>
		</tr>
		<tr>
			<td><b>CC8086.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C pour le microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>CCJASMIN.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C pour le JASMIN (JVM).</td>
		</tr>
		<tr>
			<td><b>CCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C pour l'assembleur du microprocesseur 80386 (en exécutable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>CF86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur ColdFusion pour l'assembleur du microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>CLIPPER86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Clipper pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>CLOJ86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Clojure pour de l'assembleur de microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>COBOL86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur COBOL pour 8086/8088.</td>
		</tr>
		<tr>
			<td><b>CODEQL.PAS</b></td>
			<td>Cette commande permet d'utiliser l'outil CodeQL en ligne de commande afin d'analyser automatiquement le code source d'un programme, de créer une base d'analyse et d'exécuter des requêtes permettant de détecter des vulnérabilités, des erreurs de programmation et des problèmes de qualité logicielle.</td>
		</tr>
		<tr>
			<td><b>COM2EXE.PAS</b></td>
			<td>Cette commande permet de convertir un fichier «.COM» en fichier «.EXE»</td>
		</tr>
		<tr>
			<td><b>COMMENT.PAS</b></td>
			<td>Cette commande permet d'ajouter des commentaires en francais dans un fichier source Pascal, C ou C# (champs, constantes, fonctions/procedures et leurs parametres) lorsqu il n y en a pas.</td>
		</tr>
		<tr>
			<td><b>CONVERT.PAS</b></td>
			<td>Cette commande permet de convertir un fichier de code source Pascal en minuscule, majuscule ou capitale. Cette commande est inspiré de la commande CONVERT du Pascal pour FLEX.</td>
		</tr>
		<tr>
			<td><b>CREF.PAS</b></td>
			<td>Cette commande permet de produire une liste de symboles croisés.</td>
		</tr>
		<tr>
			<td><b>CSC86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C# (C Sharp) pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>CSMITH.PAS</b></td>
			<td>Cette commande permet de lancer un générateur de code C aleatoire.</td>
		</tr>
		<tr>
			<td><b>CSCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur C# (C Sharp) pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>CSV2SQL.PAS</b></td>
			<td>Cette commande permet de convertir un fichier .CSV en format SQL.</td>
		</tr>	
    		<tr>
			<td><b>CV.PAS</b></td>
			<td>Cette commande permet de lancer un clone de CodeView. Cette utilitaire était fournit avec MASM, Microsoft C,...</td>
		</tr>
		<tr>
			<td><b>DBF2HTML.PAS</b></td>
			<td>Cette commande permet de convertir un fichier .DBF (DBase III) en format HTML.</td>
		</tr>
		<tr>
			<td><b>DBF2PAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier .DBF (DBase III) en format Pascal.</td>
		</tr>	
		<tr>
			<td><b>DBF2SQL.PAS</b></td>
			<td>Cette commande permet de convertir un fichier .DBF (DBase III) en format SQL.</td>
		</tr>
		<tr>
			<td><b>DBF2XML.PAS</b></td>
			<td>Cette commande permet de convertir un fichier .DBF (DBase III) en format XML.</td>
		</tr>
     		<tr>
			 <td><b>DEBUG.PAS</b></td>
			 <td>Cette commande permet de deboguer un programme.</td>
		</tr>
		<tr>
			<td><b>DIR.PAS</b></td>
			<td>Cette commande permet d'afficher les fichiers d'un répertoire et de transformer la sortie en CSV, JSON, HTML, PASCAL, SQL, XML,...</td>
		</tr>
		<tr>
			<td><b>DIS6502.PAS</b></td>
			<td>Cette commande permet de désassembler un code binaire de microprocesseur 6502 en langage de programmation assembleur 6502.</td>
		</tr>
		<tr>
			<td><b>DIS6809.PAS</b></td>
			<td>Cette commande permet de désassembler un code binaire de microprocesseur 6809 en langage de programmation assembleur 6809.</td>
		</tr>
		<tr>
			<td><b>DIS8080.PAS</b></td>
			<td>Cette commande permet de désassembler un code binaire de microprocesseur 8080 en langage de programmation assembleur 8080.</td>
		</tr>
		<tr>
			<td><b>DIS8086.PAS</b></td>
			<td>Cette commande permet de désassembler un code binaire de microprocesseur 8086 en langage de programmation assembleur 8086.</td>
		</tr>	
		<tr>
			<td><b>DISEXE.PAS</b></td>
			<td>Cette commande permet de lancer le désassembleur de fichiers EXE (MZ DOS 16 bits / PE Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>DISOBJ.PAS</b></td>
			<td>Cette commande permet d'analyser et de désassembler un fichier d'extension «.OBJ».</td>
		</tr>
		<tr>
			<td><b>DISPCODE.PAS</b></td>
			<td>Cette commande permet de lancer le désassembleur de p-Code UCSD p-System.</td>
		</tr>
		<tr>
			<td><b>DISPRG.PAS</b></td>
			<td>Cette commande permet de lancer le désassembler de fichiers .PRG du Atari ST.</td>
		</tr>
		<tr>
			<td><b>DISRES.PAS</b></td>
			<td>Cette commande permert de lancer le desassembleur de fichiers .RES (ressources Windows) vers .RC</td>
		</tr>
		<tr>
			<td><b>DISZ80.PAS</b></td>
			<td>Cette commande permet de désassembler un code binaire de microprocesseur Z80 en langage de programmation assembleur Z80.</td>
		</tr>
		<tr>
			<td><b>DOXYGEN.PAS</b></td>
			<td>Cette commande permet de lancer le générateur de documentation.</td>
		</tr>
		<tr>
			<td><b>DRAW2LGO.PAS</b></td>
			<td>Cette commande permet de convertir les chaines de caractères DRAW du langage de programmation BASIC en instruction du langage de programmation LOGO.</td>
		</tr>
		<tr>
			<td><b>FNT2PAS.PAS</b></td>
			<td>Cette commande permet de convertir des fichiers de polices de caractères .FNT en code source Pascal.</td>
		</tr>
		<tr>
			<td><b>F77C86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Fortran 77 pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>F77CW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Fortran 77 pour l'assembleur du microprocesseur 80386 pour Windows 32 bits.</td>
		</tr>
		<tr>
			<td><b>HC.PAS</b></td>
			<td>Cette commande permet de lancer le Help Compiler (HC).</td>
		</tr>
	    <tr>
			<td><b>HEXCOM.PAS</b></td>
	        <td>Cette commande permet de charger un HEX (fichier de vidage hexadécimal) et en fait un fichier de format  «.COM».</td>
        </tr>
		<tr>
			<td><b>HEXDUMP.PAS</b></td>
			<td>Cette commande permet d'afficher le contenu d'un fichier en format hexadecimal et d'avoir des formats de sortie comme C, CSV, JSON, HTML, PASCAL, SQL, XML,... Cette commande est inspiré de la commande de Linux.</td>
		</tr>
		<tr>
			<td><b>HTML2TXT.PAS</b></td>
			<td>Cette commande permet de convertir un fichier en HTML en texte seulement (enlève le code HTML).</td>
		</tr>
		<tr>
			<td><b>ICO2PAS.PAS</b></td>
			<td>Cette commande permet de transformer un icône (.ICO) en code source Pascal.</td>
		</tr>
		<tr>
			<td><b>JASMIN.PAS</b></td>
			<td>Cette commande permet d'assembler un fichier source Jasmin (.j) en fichier .class (bytecode Java) compatible avec la JVM.</td>
		</tr>
		<tr>
			<td><b>JAVA2CS.PAS</b></td>
			<td>Cette commande permet de lancer le transpilateur Java vers C#.</td>
		</tr>
		<tr>
			<td><b>JAVAC86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Java (Java-Lite) pour l'assembleur du microprocesseur 8086.</td>
		</tr>
	    <tr>
			<td><b>JAVACW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Java pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>JOVIAL86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Jovial 73 pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>JS86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur JavaScript pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>KOTLIN86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Kotlin pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>LIB.PAS</b></td>
			<td>Cette commande permet de lancer le gestionnaire de bibliothèques compatible Microsoft.</td>
		</tr>
		<tr>
			<td><b>LINK.PAS</b></td>
			<td>Cette commande permet de lancer le fabricant de liaison.</td>
		</tr>
		<tr>
			<td><b>LISP86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur LISP pour de l'assembleur du microprocesseur 8086/8088.</td>
		</tr>
		<tr>
			<td><b>LOGO.PAS</b></td>
			<td>Cette commande permet de lancer l'interpréteur de commande du langage de programmation LOGO. Il supporte aussi la tortue.</td>
		</tr>
		<tr>
			<td><b>LUA86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation Lua pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>LUACW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Lua vers un executable Windows 32 bits.</td>
		</tr>
		<tr>
			<td><b>MASM.PAS</b></td>
			<td>Cette commande permet de lancer le Macro Assembler (compilateur assembleur 8086 créant des fichiers .OBJ).</td>
		</tr>
		<tr>
			<td><b>ML.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Macro Assembler (ML.EXE) 80386/Win32.</td>
		</tr>
		<tr>
			<td><b>MOD2CW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Modula-2 pour l'assembleur du microprocesseur 80386 pour Windows 32 bits.</td>
		</tr>
		<tr>
			<td><b>MOD3CW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Modula-3 pour l'assembleur du microprocesseur 80386 pour Windows 32 bits.</td>
		</tr>
		<tr>
			<td><b>MODII86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Modula-2 pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>MODIII86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Modula-3 pour de l'assembleur de microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>NJS2CS.PAS</b></td>
			<td>Cette commande permet de lancer le transpilateur Node.js (JavaScript) vers C#.</td>
		</tr>
		<tr>
			<td><b>NJS2JAVA.PAS</b></td>
			<td>Cette commande permet de lancer le transpilateur Node.js (JavaScript) vers Java.</td>
		</tr>
		<tr>
			<td><b>OBERON86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Oberon pour l'assembleur du microprocesseur 8086.</td>
		</td>
		<tr>
			<td><b>OBERCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Oberon pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>OBJDUMP.PAS</b></td>
			<td>Cette commande permet d'analyser des fichiers objets, bibliothèques et exécutables afin d'afficher leurs entêtes, sections, symboles et code désassemblé.</td>
		</tr>
		<tr>
			<td><b>PAS2ADA.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Ada (.adb).</td>
		</tr>
		<tr>
			<td><b>PAS2MOD2.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Modula-2 (.mod).</td>
		</tr>
		<tr>
			<td><b>PAS2AL58.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Algol 58 (.a58).</td>
		</tr>
		<tr>
			<td><b>PAS2AL60.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Algol 60 (.a60).</td>
		</tr>
		<tr>
			<td><b>PAS2AL68.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Algol 68 (.a68).</td>
		</tr>
		<tr>
			<td><b>PAS2BCPL.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage BCPL (.b).</td>
		</tr>
		<tr>
			<td><b>PAS2C.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage C (.c).</td>
		</tr>
		<tr>
			<td><b>PAS2CS.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage C# (.cs).</td>
		</tr>
		<tr>
			<td><b>PAS2MOD3.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Modula-3 (.m3).</td>
		</tr>
		<tr>
			<td><b>PAS2HTML.PAS</b></td>
			<td>Cette commande permet de convertir un fichier de code source en syntaxe coloré HTML.</td>
		</tr>
		<tr>
			<td><b>PAS2JAVA.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Java (.java).</td>
		</tr>
		<tr>
			<td><b>PAS2OBER.PAS</b></td>
			<td>Cette commande permet de transpiler un fichier source Turbo Pascal/Free Pascal vers le langage Oberon (.obn).</td>
		</tr>
		<tr>
			<td><b>PAS2RSJ.PAS</b></td>
			<td>Cette commande permet de convertir des constantes Pascal en fichier de ressource RSJ.</td>
		</tr>
		<tr>
			<td><b>PASCHAT.PAS</b></td>
			<td>Cette commande permet de lancer l'agent conversationnel generateur de code Turbo Pascal.</td>
		<tr>
			<td><b>PC8086.PAS</b></td>
			<td>Cette commande permet de lancer un compilateur Pascal générant du code pour l'assembleur du microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>PERL86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Perl pour l'assembleur du microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>PERLCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Perl pour l'assembleur du microprocesseur 80386 pour le systeme d'exploitation Windows 32 bits (PE Win32).</td>
		</tr>
		<tr>
			<td><b>PHP2CS.PAS</b></td>
			<td>Cette commande permet de lancer le transpileur PHP vers C#.</td>
		</tr>
		<tr>
			<td><b>PHP86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur PHP pour l'assembleur du microprocesseur 8086 ou 8088.</td>
		</tr>
		<tr>
			<td><b>PHPCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur PHP pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>PL1CW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur PL/1 vers assembleur 80386, 32 bits, pour Windows 32 bits.</td>
		</tr>
		<tr>
			<td><b>PLI86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur PL/I pour 8086/8088.</td>
		</tr>
	    <tr>
			<td><b>PMETER.PAS</b></td>
			<td>Cette commande permet de faire des tests de charge.</td>
		</tr>
		<tr>
			<td><b>POWFXC32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Power FX pour assembleur du microprocesseur 80386 (Windows PE 32 bits).</td>
		<tr>
			<td><b>PPUINFO.PAS</b></td>
			<td>Cette commande permet de retourner les informations de version d'une unité Free Pascal.</td>
		</tr>
		<tr>
			<td><b>PSP86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de PSP (Pascal Server Pages) pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>PSPCW32.PAS</b></td>
			<td>Cette commande permet de compiler du PSP (Pascal Server Pages) pour de l'assembleur du microprocesseur 80386 (en véritable exécutable Windows 32 bits de format EXE PE Windows).</td>
		</tr>
		<tr>
			<td><b>PYTHCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Python pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>PYTHON86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de Python pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>QPUDEP.PAS</b></td>
			<td>Cette commande permet d'afficher les dépendances d'un unité QPU de QuickPascal.</td>
		</tr>
		<tr>
			<td><b>QPUINFO.PAS</b></td>
			<td>Cette commande permet d'afficher les informations sommaires d'un unité QPU de QuickPascal.</td>
		</tr>
		<tr>
			<td><b>QPU2PAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier .QPU de QuickPascal en code source Pascal.</td>
		</tr>
		<tr>
			<td><b>RC.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de ressources Windows (.RC -> .RES).</td>
		</tr>
		<tr>
			<td><b>READELF.PAS</b></td>
			<td>Cette commande permet d'afficher des informations sur un ELF.</td>
		</tr>
		<tr>
			<td><b>RGB2HTML.PAS</b></td>
			<td>Cette commande permet de convertir les trois valeurs RGB (RVB) en code couleur HTML.</td>
		</tr>
		<tr>
			<td><b>ROT13PAS.PAS</b></td>
			<td>Cette commande permet d'obscurcir le code Pascal en le transformant avec l'algorithme rot13 sur les identificateurs du programme.</td>
		</tr>
		<tr>
			<td><b>RUBYCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Ruby pour l'assembleur du microprocesseur 80386 pour le systeme d'exploitation Windows 32 bits (PE Win32).</td>
		</tr>
		<tr>
			<td><b>RUST86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Rust vers l'assembleur 8086.</td>
		</tr>
		<tr>
			<td><b>RUSTCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Rust pour l'assembleur du microprocesseur 80386 pour Windows (PE Win32).</td>
		</tr>
		<tr>
			<td><b>SAS86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur SAS vers l'assembleur du microprocesseur 8086 (MASM/TASM).</td>
		</tr>
		<tr>
			<td><b>SASCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur SAS pour l'assembleur du microprocesseur 80386 pour le systeme d'exploitation Windows 32 bits (PE Win32).</td>
		</tr>
		<tr>
			<td><b>SNOBCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur SNOBOL4 pour l'assembleur du microprocesseur 80386 pour le systeme d'exploitation Windows 32 bits (PE Win32).</td>
		</tr>	
		<tr>
			<td><b>SNOBOL86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Snobol 4 pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>SQLCMD.PAS</b></td>
			<td>Cette commande permet de lancer un clone SQL Server en ligne de commande. Lit directement dans un fichier «.MDF».</td>
		</tr>
		<tr>
			<td><b>SWIFT86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Swift pour l'assembleur du microprocesseur 8086.</td>
		</tr>
    	<tr>
			<td><b>SYMDEB.PAS</b></td>
			<td>Cette commande permet de lancer le débogueur DOS. Cette commande est inspiré du SYMDEB du MASM.</td>
		</tr>
    	<tr>
			<td><b>TOKEN2BAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier de TOKEN (GWBASIC, CoCo,...) de BASIC en BASIC ASCII.</td>
		</tr>
		<tr>
			<td><b>TPCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Turbo Pascal pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>TP2JS.PAS</b></td>
			<td>Cette commande permet de compiler un fichier Turbo Pascal en code JavaScript.</td>
		</tr>
		<tr>
			<td><b>TPUINFO.PAS</b></td>
			<td>Cette commande permet de retourner les informations de version d'une unité Turbo Pascal.</td>
		</tr>
		<tr>
			<td><b>TXT2INC.PAS</b></td>
			<td>Cette commande permet de convertir un texte en chaine de caractères entre guillemet pour Pascal.</td>
		</tr>
		<tr>
			<td><b>VAXPAS86.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur VAX Pascal pour l'assembleur du microprocesseur 8086.</td>
		</tr>
		<tr>
			<td><b>VAXPCW32.PAS</b></td>
			<td> Cette commande permet de lancer le compilateur de VAX Pascal pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>VBCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Visual Basic 6 pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>VBNCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur Visual Basic .NET pour l'assembleur du microprocesseur 80386 (en executable Windows 32 bits).</td>
		</tr>
		<tr>
			<td><b>WORKSHOP.PAS</b></td>
			<td>Cette commande permet de lancer l'editeur de ressources.</td>
		</tr>
		<tr>
			<td><b>XPPCW32.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur X++ (Axapta / Microsoft Dynamics AX) pour l'assembleur du microprocesseur 80386 pour le système d'exploitation Windows 32 bits (PE Win32).</td>
		</tr>
	</table>

<h2>Compilation</h2>
	
Les fichiers Pascal n'ont aucune dépendances, il suffit de télécharger le fichier désiré et de le compiler avec Free Pascal avec la syntaxe de commande  :

<pre><b>fpc</b> <i>LEFICHIER.PAS</i></pre>
	
Sinon, vous pouvez également le compiler avec le Turbo Pascal à l'aide de la syntaxe de commande suivante si le programme n'est pas trop gros :	

<pre><b>tpc</b> <i>LEFICHIER.PAS</i></pre>
	
Par exemple, si vous voulez compiler CV.PAS, vous devrez tapez la commande suivante :

<pre><b>fpc</b> CV.PAS</pre>

<h2>Licence</h2>
<ul>
 <li>Le code source est publié sous la licence <a href="https://github.com/gladir/DEV-COOLS/blob/main/LICENSE">MIT</a>.</li>
 <li>Le paquet original est publié sous la licence <a href="https://github.com/gladir/DEV-COOLS/blob/main/LICENSE">MIT</a>.</li>
</ul>
