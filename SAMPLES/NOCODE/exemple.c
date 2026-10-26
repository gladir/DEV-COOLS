/* Programme d'essai pour NOCODE :
     gcc -O0 -o exemple exemple.c -lm
     nocode exemple                         (code C reconstruit)
     nocode --print-cfg=cfg.dot exemple     (graphe de flot de controle)  */
#include <stdio.h>
#include <string.h>

static int fib(int n){ return n<2?n:fib(n-1)+fib(n-2); }

int sum(int *a, int n){ int s=0; for(int i=0;i<n;i++) s+=a[i]; return s; }

int classify(int x){
  switch(x){
    case 0: return 10;
    case 1: return 20;
    case 2: return 33;
    case 3: return 41;
    case 4: return 5;
    default: return -1;
  }
}

int collatz(unsigned n){ int c=0; while(n!=1){ if(n&1) n=3*n+1; else n>>=1; c++; } return c; }

int main(int argc,char**argv){
  int a[10]; for(int i=0;i<10;i++) a[i]=i*i;
  char buf[64]; strcpy(buf,"hello");
  printf("%d %d %s\n", fib(10), sum(a,10), buf);
  if(argc>2 && argv[1][0]=='x') puts("x");
  else if(argc==2) puts("deux");
  printf("%d %d\n", classify(argc), collatz(27));
  return strlen(buf)>3 ? 0 : 1;
}
