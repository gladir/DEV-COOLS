{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur PL/1 vers assembleur 80386, 32 bits, pour Windows 32 bits.
}

{TODO PL1CW32.PAS:
1. Definir le pipeline canonique du compilateur : source .PLI/.PL1 -> tokens -> AST/intermediaire -> assembleur 80386 -> OBJ COFF -> EXE PE Win32.
2. Ajouter les options de ligne de commande : fichier source, -o sortie, mode par defaut .EXE, -obj pour produire seulement un .OBJ, -asm pour generer/conserver explicitement le .ASM, -v, -h.
3. Definir les conventions de fichiers : accepter SAMPLES\PL1\*.PLI, produire .EXE par defaut, produire .OBJ final avec -obj, ne produire .ASM que si -asm est demande.
4. Mettre en place l'infrastructure commune : lecture source, suivi ligne/colonne, messages d'erreur clairs, codes de sortie, limites internes compatibles Turbo Pascal 7 et Free Pascal 3.2.
5. Implementer le scanner lexical PL/1 : identifiants, mots-cles, entiers, chaines, commentaires /* ... */, operateurs, parentheses, virgules, deux-points, points-virgules.
6. Construire la table des mots-cles necessaires aux exemples : PROCEDURE, OPTIONS, MAIN, DECLARE, FIXED, BINARY, INITIAL, STATIC, RETURNS, RETURN, DO, TO, END, PUT, LIST, SKIP, SELECT, WHEN, OTHERWISE, GOTO.
7. Parser les etiquettes PL/1 de procedure et de controle : MAIN:, ABSVAL:, FIN:, avec resolution des references avant/arriere pour GOTO.
8. Parser les declarations PROCEDURE, y compris OPTIONS(MAIN), listes de parametres, RETURNS(FIXED BINARY), corps de procedure et END nom optionnel.
9. Construire une table des symboles avec portees : procedures, parametres, variables locales, variables STATIC, tableaux, etiquettes et symboles runtime.
10. Parser les declarations DECLARE simples : FIXED BINARY, INITIAL(expr), STATIC, declarations multiples si ajoutees plus tard, et diagnostics de redeclaration.
11. Supporter les tableaux PL/1 unidimensionnels utilises par TEST2.PLI : DECLARE TAB(10) FIXED BINARY STATIC, indexation TAB(I), bornes 1..N.
12. Definir la representation 32 bits des types minimaux : FIXED BINARY comme entier signe 32 bits, tableaux d'entiers 32 bits, valeurs de retour dans EAX.
13. Implementer le parseur d'expressions avec precedence : litteraux, variables, tableaux, parentheses, appels, unaire -, *, / si prevu, +, -, comparaisons.
14. Implementer les built-ins requis : ABS, MAX, MIN, MOD, avec evaluation correcte dans les expressions et preparation a d'autres built-ins PL/1.
15. Generer le code des affectations : variable = expression, tableau(index) = expression, initialisation explicite, initialisation STATIC et locales.
16. Implementer DO I = debut TO fin ; ... END ; avec variable de controle, test de fin, increment implicite, labels 80386 uniques et imbrication.
17. Implementer SELECT(expr), WHEN(valeurs), OTHERWISE et END, en generation de comparaisons et branchements structures.
18. Implementer GOTO label et les etiquettes internes en emission ASM/OBJ, avec verification des labels inexistants ou dupliques.
19. Implementer RETURN(expr) pour les procedures avec RETURNS, prologue/epilogue propre et retour de valeur dans EAX.
20. Definir la convention d'appel interne 32 bits : parametres sur pile, frame EBP, sauvegarde minimale des registres, nettoyage de pile documente.
21. Generer les prologues/epilogues 80386 Win32 : allocation des locales, acces [EBP-offset] et [EBP+offset], alignement simple de pile.
22. Fournir le runtime console minimal : PUT LIST(expr) pour afficher les entiers, PUT SKIP pour nouvelle ligne, sortie propre via ExitProcess ou equivalent.
23. Implementer l'emission ASM optionnelle : syntaxe MASM 80386 lisible, sections .text/.data/.rdata, labels stables, commentaires utiles pour le debug.
24. Implementer l'emission OBJ COFF et le lien EXE PE Win32 par defaut, avec imports runtime necessaires et mode -obj qui s'arrete apres le fichier objet.
25. Creer une validation automatique compilant et executant tous les fichiers SAMPLES\PL1\*.PLI, en couvrant TEST.PLI et TEST2.PLI, avec verification des sorties attendues et des modes .EXE, .OBJ et .ASM optionnel.
}
