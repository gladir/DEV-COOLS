# DEV-COOLS
Suite de commandes pour les développeur écrit en Pascal.

<h2>Liste des fichiers</h2>

Voici la liste des différents fichiers proposés dans DEV-COOLS :

<table>
		<tr>
			<th>Nom</th>
			<th>Description</th>	
		</tr>
		<tr>
			<td><b>ASC2BAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source BAS.</td>
		</tr>		
		<tr>
			<td><b>ASC2C.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source C.</td>
		</tr>
  	        <tr>
			<td><b>ASC2PAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier ASCII en code source Pascal.</td>
		</tr>
		<tr>
			<td><b>ASM6502.PAS</b></td>
			<td>Cette commande permet de lancer le compilateur de langage de programmation assembleur pour les microprocesseur 6502.</td>
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
			<td><b>BIN2BGI.PAS</b></td>
			<td>Cette programme permet l'écriture d'entête de la portion du pilote BGI.</td>
		</tr>
		<tr>
			<td><b>BIN2C.PAS</b></td>
			<td>Cette commande permet de convertir un fichier binaire en tableau de code source C.</td>
		</tr>
		<tr>
			<td><b>BIN2PAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier binaire en tableau de code source Pascal.</td>
		</tr>
    		<tr>
			<td><b>CV.PAS</b></td>
			<td>Cette commande permet de lancer un clone de CodeView. Cette utilitaire était fournit avec MASM, Microsoft C,...</td>
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
			<td><b>HEXDUMP.PAS</b></td>
			<td>Cette commande permet d'afficher le contenu d'un fichier en format hexadecimal et d'avoir des formats de sortie comme C, CSV, JSON, HTML, PASCAL, SQL, XML,... Cette commande est inspiré de la commande de Linux.</td>
		</tr>
		<tr>
			<td><b>HTML2TXT.PAS</b></td>
			<td>Cette commande permet de convertir un fichier en HTML en texte seulement (enlève le code HTML).</td>
		</tr>
	        <tr>
			<td><b>PMETER.PAS</b></td>
			<td>Cette commande permet de faire des tests de charge.</td>
		</tr>
    		<tr>
			<td><b>SYMDEB.PAS</b></td>
			<td>Cette commande permet de lancer le débogueur DOS. Cette commande est inspiré du SYMDEB du MASM.</td>
		</tr>
    		<tr>
			<td><b>TOKEN2BAS.PAS</b></td>
			<td>Cette commande permet de convertir un fichier de TOKEN (GWBASIC, CoCo,...) de BASIC en BASIC ASCII.</td>
		</tr>	
	</table>

<h2>Compilation</h2>
	
Les fichiers Pascal n'ont aucune dépendances, il suffit de télécharger le fichier désiré et de le compiler avec Free Pascal avec la syntaxe de commande  :

<pre><b>fpc</b> <i>LEFICHIER.PAS</i></pre>
	
Sinon, vous pouvez également le compiler avec le Turbo Pascal à l'aide de la syntaxe de commande suivante :	

<pre><b>tpc</b> <i>LEFICHIER.PAS</i></pre>
	
Par exemple, si vous voulez compiler CV.PAS, vous devrez tapez la commande suivante :

<pre><b>fpc</b> CV.PAS</pre>

<h2>Licence</h2>
<ul>
 <li>Le code source est publié sous la licence <a href="https://github.com/gladir/DEV-COOLS/blob/main/LICENSE">MIT</a>.</li>
 <li>Le paquet original est publié sous la licence <a href="https://github.com/gladir/DEV-COOLS/blob/main/LICENSE">MIT</a>.</li>
</ul>
