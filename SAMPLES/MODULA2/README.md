# MOD2CW32 — utilisation et validation

## Compilation

Depuis la racine du dépôt :

```powershell
fpc MOD2CW32.PAS
.\MOD2CW32.exe SAMPLES\MODULA2\hello_m2.mod
.\MOD2CW32.exe -c SAMPLES\MODULA2\hello_m2.mod
.\MOD2CW32.exe -S SAMPLES\MODULA2\hello_m2.mod
```

- Sans option, le compilateur produit un `.obj` COFF i386 et un `.exe` PE32.
- `-c` arrête le pipeline après le `.obj`.
- `-S` conserve aussi l’assembleur 80386 lisible.
- `-o fichier` choisit le nom de sortie.

Les chemins DOS/Windows (`\`), Unix (`/`) et les préfixes de lecteur (`C:`)
sont reconnus par les fonctions de nommage internes. Les noms complets sont
limités à 250 caractères afin de réserver la place des extensions dans les
chaînes courtes Pascal employées.

## Validation

```powershell
.\SAMPLES\MODULA2\validate.ps1
```

Le script compile tous les `.mod` dans les trois modes, vérifie les artefacts
et les en-têtes binaires, puis exécute `hello_m2.exe` et `arith_m2.exe` et
compare leurs sorties.

## Portabilité Pascal

`MOD2CW32.PAS` n’utilise aucune unité FPC (`SysUtils`, `Classes`, etc.). Les
tableaux ont des bornes statiques, les chaînes restent des `ShortString`, et
les fichiers binaires utilisent `File`, `BlockWrite`, `FilePos` et des types
Pascal classiques (`Byte`, `Word`, `LongInt`).

Sous Free Pascal, le source force les chaînes courtes. La compilation de
référence est FPC 3.2 en cible Win32/i386. Au démarrage, le compilateur vérifie
que `Byte`, `Word` et `LongInt` occupent respectivement 1, 2 et 4 octets.

Le source demeure orienté Turbo Pascal 7 autant que possible et évite les
tableaux dynamiques ainsi que les unités propres à FPC. Une compilation DOS
TP7 complète n’est toutefois pas garantie : les grandes tables statiques
dépassent aisément la mémoire conventionnelle et quelques contrôles de flux
modernes restent acceptés par FPC. Cette limite de l’hôte n’affecte pas la
compatibilité des formats produits.

## Endianess

COFF i386 et PE32 sont toujours écrits explicitement en little-endian, octet
par octet, par `WriteRawWordLE` et `WriteRawDWordLE`. Le résultat ne dépend
donc pas de l’endianess de la machine qui exécute le compilateur.

La validation contrôle notamment :

- la signature `MZ` des exécutables ;
- la signature `PE\0\0` à l’offset indiqué par l’en-tête DOS ;
- la machine COFF i386 `4C 01` dans les `.obj`.
