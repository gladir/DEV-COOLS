#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <libgen.h>

static uint32_t rd32(const uint8_t *p){ uint32_t v; memcpy(&v,p,4); return v; }
static uint16_t rd16(const uint8_t *p){ uint16_t v; memcpy(&v,p,2); return v; }

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: runpe prog.exe\n"); return 2; }
  FILE *f = fopen(argv[1], "rb");
  if (!f) { perror("open"); return 2; }
  fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
  uint8_t *buf = malloc(sz); if (fread(buf, 1, sz, f) != (size_t)sz) return 2; fclose(f);
  uint32_t pe = rd32(buf + 0x3C);
  if (rd32(buf + pe) != 0x4550) { fprintf(stderr, "pas un PE\n"); return 2; }
  uint8_t *coff = buf + pe + 4;
  int nsec = rd16(coff + 2);
  int optsz = rd16(coff + 16);
  uint8_t *opt = coff + 20;
  uint32_t entry = rd32(opt + 16), base = rd32(opt + 28), imgsz = rd32(opt + 56);
  uint32_t hdrsz = rd32(opt + 60);
  uint32_t impRva = rd32(opt + 96 + 8);
  uint8_t *sec = opt + optsz;
  uint8_t *img = mmap((void *)(uintptr_t)base, imgsz, PROT_READ|PROT_WRITE|PROT_EXEC,
                      MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0);
  if (img == MAP_FAILED || (uintptr_t)img != base) { perror("mmap image"); return 2; }
  memcpy(img, buf, hdrsz);
  for (int i = 0; i < nsec; i++) {
    uint8_t *s = sec + 40 * i;
    uint32_t va = rd32(s + 12), rawsz = rd32(s + 16), rawptr = rd32(s + 20);
    if (rawsz) memcpy(img + va, buf + rawptr, rawsz);
  }
  /* stubs */
  char path[4096]; strncpy(path, argv[0], sizeof(path) - 1); path[sizeof(path)-1] = 0;
  char *dir = dirname(path);
  char sp[4200]; snprintf(sp, sizeof sp, "%s/stubs.bin", dir);
  FILE *sf = fopen(sp, "rb"); if (!sf) { perror("stubs.bin"); return 2; }
  uint8_t *st = mmap((void *)0x20000000, 65536, PROT_READ|PROT_WRITE|PROT_EXEC,
                     MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0);
  if (st == MAP_FAILED) { perror("mmap stubs"); return 2; }
  size_t n = fread(st, 1, 65536, sf); fclose(sf); (void)n;
  uint8_t *heap = mmap((void *)0x28000000, 64u << 20, PROT_READ|PROT_WRITE,
                       MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0);
  if (heap == MAP_FAILED) { perror("mmap heap"); return 2; }
  *(uint32_t *)heap = 0x28000010;
  const char *names[] = {"GetStdHandle","WriteFile","ReadFile","ExitProcess","GetProcessHeap","HeapAlloc"};
  /* imports */
  if (impRva) {
    for (uint8_t *d = img + impRva; rd32(d + 12); d += 20) {
      uint32_t oft = rd32(d), ft = rd32(d + 16);
      uint32_t *thunk = (uint32_t *)(img + (oft ? oft : ft));
      uint32_t *iat = (uint32_t *)(img + ft);
      for (int k = 0; thunk[k]; k++) {
        const char *nm = (const char *)(img + thunk[k] + 2);
        int slot = 6;
        for (int j = 0; j < 6; j++) if (!strncmp(nm, names[j], strlen(names[j])) && (nm[strlen(names[j])]==0 || nm[strlen(names[j])]==0x40)) slot = j;
        if (slot == 6) fprintf(stderr, "import inconnu: %s\n", nm);
        iat[k] = 0x20000000u + 64u * slot;
      }
    }
  }
  uint8_t *stack = mmap((void *)0x30000000, 1u << 20, PROT_READ|PROT_WRITE,
                        MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0);
  if (stack == MAP_FAILED) { perror("mmap stack"); return 2; }
  uint64_t top = 0x30000000u + (1u << 20) - 16;
  *(uint32_t *)(uintptr_t)top = 0x20000000u + 64u * 3;   /* retour -> ExitProcess */
  uint64_t ep = (uint64_t)base + entry;
  fflush(stdout);
  __asm__ volatile(
    "mov $0x2b, %%eax\n\t"
    "mov %%eax, %%ds\n\t"
    "mov %%eax, %%es\n\t"
    "mov %0, %%rsp\n\t"
    "pushq $0x23\n\t"
    "pushq %1\n\t"
    "lretq\n\t"
    :: "r"(top), "r"(ep) : "rax", "memory");
  return 0;
}
