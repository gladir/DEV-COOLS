{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Lua vers assembleur 80386, 32 bits, pour Windows 32 bits.

  TODO - feuille de route LUACW32.PAS
  01. Definir le pipeline canonique .LUA -> tokens -> AST/IR Lua -> ASM 80386 -> OBJ COFF -> EXE PE32, avec .EXE Windows produit par defaut.
  02. Ajouter le parsing des options de ligne de commande : mode EXE par defaut, mode OBJ seul, emission ASM seulement si un parametre explicite le demande, noms de sortie et mode verbose.
  03. Implementer le chargeur source Lua : chemins relatifs Windows, normalisation CR/LF, suivi ligne/colonne, diagnostics avec caret, et conservation des chaines brutes.
  04. Construire le lexer Lua complet : identifiants, mots-cles, nombres entiers/flottants, chaines courtes, chaines longues, commentaires courts/longs, operateurs et ponctuation.
  05. Supporter la grammaire des chunks/blocs Lua : listes d'instructions, separateurs optionnels, portee lexicale, blocs imbriques et fin de fichier propre.
  06. Parser les expressions Lua avec precedences exactes : or, and, comparaisons, concatenation, + - * / // %, unaire, puissance, longueur, parenthesage et associativite.
  07. Implementer le modele de valeurs runtime : nil, booleen, nombre, chaine, table, fonction, closure, coroutine, avec representation 32 bits coherente.
  08. Ajouter la table des symboles et des scopes : global, local, upvalue, parametre, vararg, labels internes, resolution des noms et duree de vie.
  09. Generer le code 80386 pour les variables locales/globales : chargement, stockage, initialisation a nil, affectations multiples et permutations sans ecrasement.
  10. Implementer les constantes et le pool de donnees : chaines, nombres flottants, tables de metadonnees, symboles importes et alignement COFF/PE.
  11. Generer les expressions numeriques et booleennes : operations arithmetiques, comparaisons, conversions truthy/falsy Lua et court-circuit de and/or.
  12. Implementer les chaines : allocation/stockage, concatenation, longueur, comparaison, echappements, impression et compatibilite avec SAMPLES\LUA\strings.lua et test_strings.lua.
  13. Implementer les tables Lua : creation {}, champs array/hash, indexation [], acces point, affectation, iteration, metatables de base et support de SAMPLES\LUA\tables.lua.
  14. Generer les structures de controle : if/elseif/else/end, while, repeat/until, for numerique, for generique, break, labels internes et sauts 80386 fiables.
  15. Implementer les fonctions : declarations locales/globales, appels, pile d'arguments, retour simple/multiple, varargs, tail calls simples et conventions d'appel internes.
  16. Ajouter les closures et upvalues : capture de variables, cellules partagees, duree de vie apres retour, appels de fonctions imbriquees et SAMPLES\LUA\closures.lua.
  17. Supporter les retours multiples Lua : propagation dans appels, affectations, return, appels imbriques et compatibilite avec test_multiret.lua.
  18. Implementer les built-ins/runtime essentiels : print, tostring, tonumber, type, assert, error, pcall, pairs, ipairs, next, select et fonctions math/string/table requises par les exemples.
  19. Ajouter la gestion d'erreurs Lua : erreurs runtime, pcall, propagation, messages lisibles, nettoyage de pile et support de errors.lua/test_errorhandling.lua.
  20. Implementer les coroutines minimales : create, resume, yield, status, wrapping de pile/contexte et compatibilite avec test_coroutines.lua.
  21. Construire le generateur ASM 80386 optionnel : syntaxe assembleur Windows 32 bits, sections .text/.data/.rdata, labels stables, commentaires utiles et emission seulement sur demande.
  22. Construire le generateur OBJ COFF : sections, relocations, symboles externes, imports runtime, compatibilite avec le linker interne et production OBJ seule si demandee.
  23. Construire le linker PE32 interne : entetes PE, sections alignees, table d'import kernel32/msvcrt ou runtime propre, point d'entree, sortie console et suppression des EXE perimes.
  24. Ajouter le harnais de validation : option -test, compilation de tous SAMPLES\LUA\*, execution/capture des sorties, comparaison stable, modes EXE/OBJ/ASM+OBJ et nettoyage des artefacts.
  25. Stabiliser la compatibilite Free Pascal/Turbo Pascal : types bornes, buffers, absence de dependances modernes, tests de regression, diagnostics finaux et documentation d'utilisation.
}
