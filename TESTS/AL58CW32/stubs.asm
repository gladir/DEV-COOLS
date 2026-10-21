bits 32
org 0x20000000
%macro SLOT 0
  times (64 - (($ - $$) % 64)) % 64 db 0xCC
%endmacro
GetStdHandle:
  mov eax, -10
  sub eax, [esp+4]
  ret 4
SLOT
WriteFile:
  push ebx
  mov ebx, [esp+8]
  mov ecx, [esp+12]
  mov edx, [esp+16]
  mov eax, 4
  int 0x80
  mov ecx, [esp+20]
  test ecx, ecx
  jz .nw
  mov [ecx], eax
.nw:
  pop ebx
  mov eax, 1
  ret 20
SLOT
ReadFile:
  push ebx
  mov ebx, [esp+8]
  mov ecx, [esp+12]
  mov edx, [esp+16]
  mov eax, 3
  int 0x80
  test eax, eax
  jns .ok
  xor eax, eax
.ok:
  mov ecx, [esp+20]
  test ecx, ecx
  jz .nr
  mov [ecx], eax
.nr:
  pop ebx
  mov eax, 1
  ret 20
SLOT
ExitProcess:
  mov ebx, [esp+4]
  mov eax, 252
  int 0x80
SLOT
GetProcessHeap:
  mov eax, 1
  ret
SLOT
HeapAlloc:
  mov ecx, [esp+12]
  add ecx, 7
  and ecx, -8
  mov eax, [0x28000000]
  add [0x28000000], ecx
  ret 12
SLOT
Unknown:
  mov ebx, 99
  mov eax, 252
  int 0x80
SLOT
