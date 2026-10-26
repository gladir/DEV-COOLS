Exemple d'utilisation de NOCODE (clone de Snowman)
==================================================

1. Compiler NOCODE.PAS :

     fpc -Mtp NOCODE.PAS

2. Produire un executable a decompiler (Linux x86-64) :

     gcc -O0 -fcf-protection=none -fno-stack-protector -o exemple exemple.c

3. Afficher les informations et le code reconstruit :

     nocode --print-sections --print-symbols exemple
     nocode --print-instructions --from=0x1150 --to=0x1190 exemple
     nocode --print-cxx=exemple_decompile.c exemple
     nocode --print-cfg=cfg.dot --print-ir=ir.dot --print-regions=reg.dot exemple
     dot -Tpng cfg.dot -o cfg.png

Extrait du code C reconstruit (--print-cxx) pour fib() et collatz() :

     int32_t fib(int32_t edi) {
         int32_t local_1c;
         int32_t eax;

         local_1c = edi;
         if (local_1c <= 1) {
             eax = local_1c;
         } else {
             eax = fib(local_1c - 2) + fib(local_1c - 1);
         }
         return eax;
     }

     int32_t collatz(int32_t edi) {
         int32_t local_1c;
         int32_t local_c;
         int32_t eax;

         local_1c = edi;
         local_c = 0;
         while (local_1c != 1) {
             eax = local_1c & 1;
             if (eax == 0) {
                 local_1c = (uint32_t)local_1c >> 1;
             } else {
                 local_1c = local_1c + local_1c + local_1c + 1;
             }
             local_c++;
         }
         return local_c;
     }

La fonction classify() (instruction switch) est reconstruite avec sa table de
saut :

     switch ((uint32_t)local_c) {
         case 0: ... break;
         case 1: ... break;
         ...
     }

NOCODE accepte aussi les executables 32 bits (ELF i386), Windows (PE32/PE32+)
et DOS (EXE MZ, COM), par exemple les fichiers des dossiers WIN32 et BIN16 :

     nocode WIN32/8080z80.exe
