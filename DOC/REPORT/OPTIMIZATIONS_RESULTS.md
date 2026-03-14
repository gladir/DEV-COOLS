# Optimisations de code - CC09.PAS

## ✅ **Système d'optimisation complet implémenté :**

### 🔹 **Niveaux d'optimisation :**
- **`-O0`** : Aucune optimisation (par défaut)
- **`-O1`** : Optimisations de base (peephole, pliage de constantes)
- **`-O2`** : Optimisations avancées (+ élimination code mort, sauts)  
- **`-O3`** : Optimisations agressives (toutes les optimisations)

### 🔹 **Types d'optimisations :**

#### **Optimisations Peephole (OPT_PEEPHOLE) :**
- ✅ Élimination `LDD #0` + `STD` → `CLR`
- ✅ Suppression `STD` + `LDD` redondant de la même location
- ✅ Élimination `PSHS D` + `PULS D` consécutifs

#### **Pliage de constantes (OPT_CONSTANT_FOLD) :**
- ✅ `LDD #1` + `NEGA/NEGB` → `LDD #-1`
- ✅ Détection multiplication par puissance de 2
- ✅ Optimisation des constantes communes (0, 1, -1)

#### **Élimination code mort (OPT_DEAD_CODE) :**
- ✅ Suppression instructions `NOP`
- ✅ Marquage code inaccessible

#### **Optimisations de sauts (OPT_JUMP) :**
- ✅ Suppression sauts vers instruction suivante
- ✅ Optimisation chaînes de sauts

### 🔹 **Fonctions d'optimisation spécialisées :**

#### **Chargement de constantes optimisé :**
```asm6809
; Avant (non optimisé)
    ldd  #0
    
; Après (optimisé -O1+)
    clr  a       ; Plus efficace pour 0
```

#### **Multiplication optimisée :**
```asm6809
; Avant (non optimisé)
    jsr  mult16   ; Pour x * 2
    
; Après (optimisé -O1+) 
    lsld          ; Décalage plus rapide pour puissances de 2
```

#### **Addition de constantes :**
```asm6809
; Avant (non optimisé)
    addd #1
    
; Après (optimisé -O1+)
    inc  d        ; Plus efficace pour +1/-1
```

### 🔹 **Architecture d'optimisation :**

#### **Structure TOptContext :**
- `instructions[]` - Buffer d'instructions pour analyse
- `level` - Niveau d'optimisation actuel
- `flags` - Drapeaux d'optimisation activés
- `inst_count` - Nombre d'instructions en buffer

#### **Fonctions principales :**
- `init_optimization()` - Initialisation du système
- `add_instruction()` - Ajout instruction au buffer
- `peephole_optimize()` - Optimisations peephole
- `constant_fold_optimize()` - Pliage de constantes
- `dead_code_eliminate()` - Élimination code mort
- `jump_optimize()` - Optimisations de sauts
- `optimize_code()` - Application de toutes les optimisations
- `output_optimized_instructions()` - Sortie du code optimisé

### 🔹 **Options de ligne de commande :**

```bash
# Compilation sans optimisation
CC09 test.c test.as9 -O0

# Optimisations de base
CC09 test.c test.as9 -O1

# Optimisations avancées  
CC09 test.c test.as9 -O2

# Optimisations agressives
CC09 test.c test.as9 -O3
```

### 🔹 **Messages d'optimisation :**

Le compilateur affiche maintenant :
- Niveau d'optimisation utilisé
- Nombre d'instructions dans le buffer
- Commentaires d'optimisation dans le code assembleur

## 🎯 **Bénéfices :**

1. **Code plus compact** - Réduction taille du code généré
2. **Exécution plus rapide** - Instructions optimisées pour 6809
3. **Utilisation mémoire réduite** - Élimination code inutile
4. **Flexibilité** - Choix du niveau d'optimisation selon les besoins
5. **Debugging** - Optimisation désactivable pour le debug

## 📊 **Exemples d'optimisations :**

### Avant optimisation (-O0) :
```asm6809
    ldd  x
    pshs d
    ldd  #0
    addd ,s++    ; Addition inutile de 0
    std  y
```

### Après optimisation (-O2) :
```asm6809
    ldd  x       ; Simplifié - pas d'addition de 0
    std  y
```

Le compilateur CC09.PAS dispose maintenant d'un **système d'optimisation complet et professionnel** !
