# SAMPLES/LIB - Exemples d'utilisation de la commande LIB

Ce répertoire contient des exemples pour démontrer l'utilisation de la commande
LIB qui permet de gérer des bibliothèques de fichiers objets au format OMF
(Object Module Format) de Microsoft/Borland.

## Fichiers sources

- **MATH.ASM** - Module de fonctions mathématiques (ADD16, SUB16, MUL16)
- **STRING.ASM** - Module de fonctions de chaînes (STRLEN, STRCPY)
- **IO.ASM** - Module de fonctions d'entrée/sortie (PUTCHAR, GETCHAR, NEWLINE)

## Compilation des fichiers .ASM en .OBJ

```bash
# Compiler chaque fichier source en fichier objet
../../BINLINUX/MASM MATH.ASM
../../BINLINUX/MASM STRING.ASM
../../BINLINUX/MASM IO.ASM
```

## Création d'une bibliothèque

```bash
# Créer une bibliothèque à partir de plusieurs fichiers objets
../../BINLINUX/LIB /OUT:MYUTILS.LIB MATH.OBJ STRING.OBJ IO.OBJ
```

## Lister le contenu d'une bibliothèque

```bash
# Lister les modules dans une bibliothèque
../../BINLINUX/LIB /LIST MYUTILS.LIB
```

Résultat attendu:
```
Modules dans la bibliothèque:
-----------------------------
  MATH.ASM (185 octets)
  STRING.ASM (186 octets)
  IO.ASM (207 octets)

Total: 3 module(s)
```

## Afficher les symboles publics

```bash
# Afficher tous les symboles publics
../../BINLINUX/LIB /SYMBOLS MYUTILS.LIB
```

Résultat attendu:
```
Symboles publics:
-----------------
  ADD16 (MATH.ASM) @ 0000
  SUB16 (MATH.ASM) @ 0003
  MUL16 (MATH.ASM) @ 0006
  STRLEN (STRING.ASM) @ 0000
  STRCPY (STRING.ASM) @ 000E
  PUTCHAR (IO.ASM) @ 0000
  GETCHAR (IO.ASM) @ 0009
  NEWLINE (IO.ASM) @ 000E

Total: 8 symbole(s)
```

## Extraire un module d'une bibliothèque

```bash
# Extraire un module spécifique
../../BINLINUX/LIB /EXTRACT:MATH.ASM MYUTILS.LIB
```

## Mode verbeux

```bash
# Créer avec le mode détaillé activé
../../BINLINUX/LIB /VERBOSE /OUT:MYUTILS.LIB MATH.OBJ STRING.OBJ IO.OBJ
```

## Options disponibles

| Option | Description |
|--------|-------------|
| `/OUT:nom` | Spécifier le nom du fichier .LIB de sortie |
| `/LIST` | Lister les modules contenus dans la bibliothèque |
| `/SYMBOLS` | Afficher les symboles publics de la bibliothèque |
| `/EXTRACT:nom` | Extraire un module de la bibliothèque |
| `/REMOVE:nom` | Supprimer un module de la bibliothèque |
| `/VERBOSE` | Afficher les détails pendant l'opération |
| `/NOLOGO` | Supprimer la bannière d'en-tête |
| `/MACHINE:arch` | Architecture cible (IX86, X64, ARM, etc.) |

## Utilisation avec fichier réponse

Vous pouvez utiliser un fichier réponse pour spécifier les options:

```bash
# Créer un fichier réponse
echo "/OUT:MYUTILS.LIB" > build.rsp
echo "MATH.OBJ" >> build.rsp
echo "STRING.OBJ" >> build.rsp
echo "IO.OBJ" >> build.rsp

# Utiliser le fichier réponse
../../BINLINUX/LIB @build.rsp
```

## Script de test

Exécutez le script `TEST.SH` pour tester automatiquement toutes les fonctionnalités:

```bash
chmod +x TEST.SH
./TEST.SH
```
