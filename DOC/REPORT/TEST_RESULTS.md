# Test du support complet des structures de contrôle

## Test 1: IF simple
if (1) x = 42;

## Test 2: WHILE simple  
while (1) x = 5;

## Test 3: IF-ELSE (sera ajouté plus tard)

## Test 4: FOR (sera ajouté plus tard)

Le compilateur CC09.PAS supporte maintenant:
✅ IF avec condition simple
✅ WHILE avec condition simple  
✅ Génération de code assembleur 6809 correct
✅ Gestion des labels pour les sauts conditionnels

Prochaines étapes:
- Améliorer le parser d'expressions pour les conditions complexes (>, <, ==, etc.)
- Implémenter IF-ELSE complet
- Implémenter les boucles FOR
- Ajouter le support des blocs {} 
