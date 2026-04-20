# Makefile pour les exemples LIB
# Utilisation: make all

BINDIR = ../../BINLINUX
MASM = $(BINDIR)/MASM
LIB = $(BINDIR)/LIB

# Fichiers sources
SOURCES = MATH.ASM STRING.ASM IO.ASM

# Fichiers objets
OBJECTS = MATH.OBJ STRING.OBJ IO.OBJ

# Bibliotheque de sortie
LIBRARY = MYUTILS.LIB

all: $(LIBRARY)

# Creer la bibliotheque
$(LIBRARY): $(OBJECTS)
	$(LIB) /OUT:$(LIBRARY) $(OBJECTS)

# Compiler les fichiers ASM en OBJ
%.OBJ: %.ASM
	$(MASM) $<

# Nettoyer les fichiers generes
clean:
	rm -f $(OBJECTS) $(LIBRARY) TEST.LIB

# Afficher le contenu de la bibliotheque
list: $(LIBRARY)
	$(LIB) /LIST $(LIBRARY)

# Afficher les symboles
symbols: $(LIBRARY)
	$(LIB) /SYMBOLS $(LIBRARY)

# Executer les tests
test: $(OBJECTS)
	./TEST.SH

.PHONY: all clean list symbols test
