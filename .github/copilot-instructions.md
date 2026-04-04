# Instructions Copilot

## Langue de communication

Les communications dans le clavardage sont toujours en français.

## Analyse de sécurité CodeQL pour Pascal

Le CodeQL de GitHub (`codeql_checker`) ne supporte **pas** le langage Pascal.
Pour l'analyse de sécurité des fichiers `.PAS`, utiliser le **CODEQL.PAS** situé
à la racine du projet DEV-COOLS, qui supporte `--language=pascal`.

### Compilation de CODEQL.PAS

```bash
fpc -Mtp CODEQL.PAS
```

### Utilisation pour analyser du code Pascal

1. Créer la base de données :
```bash
./CODEQL database create /tmp/codeql-db --source-root=. --language=pascal
```

2. Analyser la base de données :
```bash
./CODEQL database analyze /tmp/codeql-db --format=text
```

### Règle importante

Ne **pas** utiliser l'outil intégré `codeql_checker` pour les fichiers Pascal
(`.PAS`), car il ne supporte pas ce langage. Toujours utiliser le CODEQL.PAS
du projet à la place.

## Binaires Linux ELF

Lors de la compilation d'un fichier `*.PAS` en binaire Linux de format ELF,
le fichier exécutable généré doit être placé dans le dossier **BINLINUX** et
non pas laissé dans le répertoire racine du projet.

### Exemple de compilation

```bash
fpc -Mtp MONFICHIER.PAS -o./BINLINUX/MONFICHIER
```

Ou déplacer le binaire après compilation :

```bash
fpc -Mtp MONFICHIER.PAS
mv MONFICHIER ./BINLINUX/
```
