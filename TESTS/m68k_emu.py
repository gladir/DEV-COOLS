#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# =============================================================================
# m68k_emu.py - Emulateur minimal Motorola 68000
# =============================================================================
# Charge un fichier S-Record genere par ASM68 et execute le code.
# Supporte un sous-ensemble d'instructions suffisant pour valider
# les programmes de test.
#
# Convention TRAP #15 (Easy68k / ASM68 validation) :
#   D0=9  : terminer le programme (exit code 0 = succes)
#   D0=14 : afficher chaine pointee par A1 (ASCIZ, CR/LF termine)
#   D0=13 : afficher le contenu de D1 en entier decimal
#
# Usage : python3 m68k_emu.py fichier.S68 [--verbose] [--max-cycles N]
#
# Code retour :
#   0 = programme termine normalement (TRAP #15 avec D0=9)
#   1 = erreur d'execution (instruction illegale, boucle infinie, etc.)
# =============================================================================

import sys
import struct

# --- Constantes CPU ---
MEM_SIZE   = 0x100000   # 1 Mo de memoire
MAX_CYCLES = 100000     # Limite de cycles par defaut

# --- Drapeaux CCR ---
CCR_C = 0x01  # Carry
CCR_V = 0x02  # Overflow
CCR_Z = 0x04  # Zero
CCR_N = 0x08  # Negative
CCR_X = 0x10  # Extend

class M68KError(Exception):
    pass

class M68KCPU:
    def __init__(self, verbose=False):
        self.D = [0] * 8       # D0-D7
        self.A = [0] * 8       # A0-A7 (A7 = SSP)
        self.PC = 0
        self.SR = 0x2000       # Supervisor mode
        self.mem = bytearray(MEM_SIZE)
        self.halted = False
        self.exit_code = 0
        self.verbose = verbose
        self.output = ""
        self.cycles = 0
        # A7 = stack pointer, initialise en haut de memoire
        self.A[7] = 0x0FF000

    # --- Acces memoire (big-endian) ---
    def read8(self, addr):
        addr &= 0xFFFFF
        return self.mem[addr]

    def read16(self, addr):
        addr &= 0xFFFFF
        return (self.mem[addr] << 8) | self.mem[addr + 1]

    def read32(self, addr):
        addr &= 0xFFFFF
        return (self.mem[addr] << 24) | (self.mem[addr+1] << 16) | \
               (self.mem[addr+2] << 8) | self.mem[addr+3]

    def write8(self, addr, val):
        addr &= 0xFFFFF
        self.mem[addr] = val & 0xFF

    def write16(self, addr, val):
        addr &= 0xFFFFF
        self.mem[addr]     = (val >> 8) & 0xFF
        self.mem[addr + 1] = val & 0xFF

    def write32(self, addr, val):
        addr &= 0xFFFFF
        self.mem[addr]     = (val >> 24) & 0xFF
        self.mem[addr + 1] = (val >> 16) & 0xFF
        self.mem[addr + 2] = (val >>  8) & 0xFF
        self.mem[addr + 3] = val & 0xFF

    # --- Registres avec masquage ---
    def get_d(self, n, size):
        v = self.D[n]
        if size == 1: return v & 0xFF
        if size == 2: return v & 0xFFFF
        return v & 0xFFFFFFFF

    def set_d(self, n, val, size):
        if size == 1:
            self.D[n] = (self.D[n] & 0xFFFFFF00) | (val & 0xFF)
        elif size == 2:
            self.D[n] = (self.D[n] & 0xFFFF0000) | (val & 0xFFFF)
        else:
            self.D[n] = val & 0xFFFFFFFF

    def sign_extend(self, val, size):
        if size == 1:
            if val & 0x80: return val | 0xFFFFFF00
            return val & 0xFF
        if size == 2:
            if val & 0x8000: return val | 0xFFFF0000
            return val & 0xFFFF
        if val & 0x80000000: return val - 0x100000000
        return val

    def to_signed(self, val, size):
        mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
        sign_bit = {1: 0x80, 2: 0x8000, 4: 0x80000000}[size]
        val = val & mask
        if val & sign_bit:
            return val - (mask + 1)
        return val

    # --- CCR ---
    def set_flags_nz(self, val, size):
        mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
        sign = {1: 0x80, 2: 0x8000, 4: 0x80000000}[size]
        v = val & mask
        self.SR &= ~(CCR_N | CCR_Z)
        if v == 0:
            self.SR |= CCR_Z
        if v & sign:
            self.SR |= CCR_N

    def set_flags_nzvc(self, result, size, carry=False, overflow=False):
        self.set_flags_nz(result, size)
        self.SR &= ~(CCR_V | CCR_C)
        if carry:
            self.SR |= CCR_C
        if overflow:
            self.SR |= CCR_V

    # --- Lecture d'un operande EA ---
    def fetch16(self):
        v = self.read16(self.PC)
        self.PC += 2
        return v

    def read_ea(self, mode, reg, size):
        """Lit la valeur d'un operande EA. Retourne (valeur, adresse_ou_None)."""
        if mode == 0:  # Dn
            return (self.get_d(reg, size), None)
        elif mode == 1:  # An
            return (self.A[reg] & 0xFFFFFFFF, None)
        elif mode == 2:  # (An)
            addr = self.A[reg]
            if size == 1: return (self.read8(addr), addr)
            if size == 2: return (self.read16(addr), addr)
            return (self.read32(addr), addr)
        elif mode == 3:  # (An)+
            addr = self.A[reg]
            if size == 1:
                v = self.read8(addr)
                inc = 2 if reg == 7 else 1  # SP always word-aligned
            elif size == 2:
                v = self.read16(addr)
                inc = 2
            else:
                v = self.read32(addr)
                inc = 4
            self.A[reg] = (self.A[reg] + inc) & 0xFFFFFFFF
            return (v, addr)
        elif mode == 4:  # -(An)
            if size == 1:
                dec = 2 if reg == 7 else 1
            elif size == 2:
                dec = 2
            else:
                dec = 4
            self.A[reg] = (self.A[reg] - dec) & 0xFFFFFFFF
            addr = self.A[reg]
            if size == 1: return (self.read8(addr), addr)
            if size == 2: return (self.read16(addr), addr)
            return (self.read32(addr), addr)
        elif mode == 5:  # d16(An)
            disp = self.sign_extend(self.fetch16(), 2)
            addr = (self.A[reg] + disp) & 0xFFFFFFFF
            if size == 1: return (self.read8(addr), addr)
            if size == 2: return (self.read16(addr), addr)
            return (self.read32(addr), addr)
        elif mode == 6:  # d8(An,Xn)
            ext = self.fetch16()
            disp = self.sign_extend(ext & 0xFF, 1)
            idx_reg = (ext >> 12) & 7
            idx_is_a = (ext >> 15) & 1
            idx_long = (ext >> 11) & 1
            if idx_is_a:
                idx_val = self.A[idx_reg]
            else:
                idx_val = self.D[idx_reg]
            if not idx_long:
                idx_val = self.sign_extend(idx_val & 0xFFFF, 2)
            addr = (self.A[reg] + disp + idx_val) & 0xFFFFFFFF
            if size == 1: return (self.read8(addr), addr)
            if size == 2: return (self.read16(addr), addr)
            return (self.read32(addr), addr)
        elif mode == 7:
            if reg == 0:  # xxx.W
                addr = self.sign_extend(self.fetch16(), 2) & 0xFFFFFFFF
                if size == 1: return (self.read8(addr), addr)
                if size == 2: return (self.read16(addr), addr)
                return (self.read32(addr), addr)
            elif reg == 1:  # xxx.L
                addr = (self.fetch16() << 16) | self.fetch16()
                if size == 1: return (self.read8(addr), addr)
                if size == 2: return (self.read16(addr), addr)
                return (self.read32(addr), addr)
            elif reg == 2:  # d16(PC)
                pc_save = self.PC
                disp = self.sign_extend(self.fetch16(), 2)
                addr = (pc_save + disp) & 0xFFFFFFFF
                if size == 1: return (self.read8(addr), addr)
                if size == 2: return (self.read16(addr), addr)
                return (self.read32(addr), addr)
            elif reg == 3:  # d8(PC,Xn)
                pc_save = self.PC
                ext = self.fetch16()
                disp = self.sign_extend(ext & 0xFF, 1)
                idx_reg = (ext >> 12) & 7
                idx_is_a = (ext >> 15) & 1
                idx_long = (ext >> 11) & 1
                if idx_is_a:
                    idx_val = self.A[idx_reg]
                else:
                    idx_val = self.D[idx_reg]
                if not idx_long:
                    idx_val = self.sign_extend(idx_val & 0xFFFF, 2)
                addr = (pc_save + disp + idx_val) & 0xFFFFFFFF
                if size == 1: return (self.read8(addr), addr)
                if size == 2: return (self.read16(addr), addr)
                return (self.read32(addr), addr)
            elif reg == 4:  # #imm
                if size == 1:
                    return (self.fetch16() & 0xFF, None)
                elif size == 2:
                    return (self.fetch16(), None)
                else:
                    v = (self.fetch16() << 16) | self.fetch16()
                    return (v, None)
        raise M68KError(f"Mode EA non supporte: mode={mode} reg={reg}")

    def write_ea(self, mode, reg, val, size):
        """Ecrit une valeur dans un operande EA."""
        if mode == 0:  # Dn
            self.set_d(reg, val, size)
        elif mode == 1:  # An
            self.A[reg] = val & 0xFFFFFFFF
        elif mode == 2:  # (An)
            addr = self.A[reg]
            if size == 1: self.write8(addr, val)
            elif size == 2: self.write16(addr, val)
            else: self.write32(addr, val)
        elif mode == 3:  # (An)+
            addr = self.A[reg]
            if size == 1:
                self.write8(addr, val)
                inc = 2 if reg == 7 else 1
            elif size == 2:
                self.write16(addr, val)
                inc = 2
            else:
                self.write32(addr, val)
                inc = 4
            self.A[reg] = (self.A[reg] + inc) & 0xFFFFFFFF
        elif mode == 4:  # -(An)
            if size == 1: dec = 2 if reg == 7 else 1
            elif size == 2: dec = 2
            else: dec = 4
            self.A[reg] = (self.A[reg] - dec) & 0xFFFFFFFF
            addr = self.A[reg]
            if size == 1: self.write8(addr, val)
            elif size == 2: self.write16(addr, val)
            else: self.write32(addr, val)
        elif mode == 5:  # d16(An)
            disp = self.sign_extend(self.fetch16(), 2)
            addr = (self.A[reg] + disp) & 0xFFFFFFFF
            if size == 1: self.write8(addr, val)
            elif size == 2: self.write16(addr, val)
            else: self.write32(addr, val)
        elif mode == 7:
            if reg == 0:  # xxx.W
                addr = self.sign_extend(self.fetch16(), 2) & 0xFFFFFFFF
            elif reg == 1:  # xxx.L
                addr = (self.fetch16() << 16) | self.fetch16()
            else:
                raise M68KError(f"Ecriture EA mode 7 reg {reg} non supportee")
            if size == 1: self.write8(addr, val)
            elif size == 2: self.write16(addr, val)
            else: self.write32(addr, val)
        else:
            raise M68KError(f"Ecriture EA mode={mode} reg={reg} non supportee")

    def calc_ea_addr(self, mode, reg):
        """Calcule l'adresse effective (pour LEA, PEA, JMP, JSR)."""
        if mode == 2:  # (An)
            return self.A[reg]
        elif mode == 5:  # d16(An)
            disp = self.sign_extend(self.fetch16(), 2)
            return (self.A[reg] + disp) & 0xFFFFFFFF
        elif mode == 6:  # d8(An,Xn)
            ext = self.fetch16()
            disp = self.sign_extend(ext & 0xFF, 1)
            idx_reg = (ext >> 12) & 7
            idx_is_a = (ext >> 15) & 1
            idx_long = (ext >> 11) & 1
            if idx_is_a:
                idx_val = self.A[idx_reg]
            else:
                idx_val = self.D[idx_reg]
            if not idx_long:
                idx_val = self.sign_extend(idx_val & 0xFFFF, 2)
            return (self.A[reg] + disp + idx_val) & 0xFFFFFFFF
        elif mode == 7:
            if reg == 0:  # xxx.W
                return self.sign_extend(self.fetch16(), 2) & 0xFFFFFFFF
            elif reg == 1:  # xxx.L
                return (self.fetch16() << 16) | self.fetch16()
            elif reg == 2:  # d16(PC)
                pc_save = self.PC
                disp = self.sign_extend(self.fetch16(), 2)
                return (pc_save + disp) & 0xFFFFFFFF
            elif reg == 3:  # d8(PC,Xn)
                pc_save = self.PC
                ext = self.fetch16()
                disp = self.sign_extend(ext & 0xFF, 1)
                idx_reg = (ext >> 12) & 7
                idx_is_a = (ext >> 15) & 1
                idx_long = (ext >> 11) & 1
                if idx_is_a:
                    idx_val = self.A[idx_reg]
                else:
                    idx_val = self.D[idx_reg]
                if not idx_long:
                    idx_val = self.sign_extend(idx_val & 0xFFFF, 2)
                return (pc_save + disp + idx_val) & 0xFFFFFFFF
        raise M68KError(f"calc_ea_addr: mode={mode} reg={reg} non supporte")

    # --- Evaluation des conditions ---
    def test_cc(self, cc):
        C = (self.SR & CCR_C) != 0
        V = (self.SR & CCR_V) != 0
        Z = (self.SR & CCR_Z) != 0
        N = (self.SR & CCR_N) != 0
        if cc == 0:  return True        # T
        if cc == 1:  return False       # F
        if cc == 2:  return not C and not Z  # HI
        if cc == 3:  return C or Z      # LS
        if cc == 4:  return not C       # CC/HS
        if cc == 5:  return C           # CS/LO
        if cc == 6:  return not Z       # NE
        if cc == 7:  return Z           # EQ
        if cc == 8:  return not V       # VC
        if cc == 9:  return V           # VS
        if cc == 10: return not N       # PL
        if cc == 11: return N           # MI
        if cc == 12: return N == V      # GE
        if cc == 13: return N != V      # LT
        if cc == 14: return not Z and (N == V)  # GT
        if cc == 15: return Z or (N != V)       # LE
        return False

    # --- Taille par champ de bits ---
    def op_size(self, bits):
        """Decode le champ size (2 bits): 00=B(1), 01=W(2), 10=L(4)"""
        if bits == 0: return 1
        if bits == 1: return 2
        if bits == 2: return 4
        raise M68KError(f"Taille invalide: {bits}")

    # --- Execution d'une instruction ---
    def step(self):
        if self.halted:
            return False
        self.cycles += 1
        pc_before = self.PC
        opcode = self.fetch16()

        if self.verbose:
            print(f"  PC=${pc_before:06X} op=${opcode:04X} D0=${self.D[0]:08X} "
                  f"D1=${self.D[1]:08X} A7=${self.A[7]:08X} SR=${self.SR:04X}")

        # Decode par les bits 15-12
        top4 = (opcode >> 12) & 0xF

        try:
            if opcode == 0x4E71:  # NOP
                return True

            if opcode == 0x4E75:  # RTS
                self.PC = self.read32(self.A[7])
                self.A[7] = (self.A[7] + 4) & 0xFFFFFFFF
                return True

            if opcode == 0x4E76:  # TRAPV
                if self.SR & CCR_V:
                    raise M68KError("TRAPV: overflow trap")
                return True

            if opcode == 0x4E77:  # RTR
                sr_low = self.read16(self.A[7])
                self.A[7] += 2
                self.SR = (self.SR & 0xFF00) | (sr_low & 0xFF)
                self.PC = self.read32(self.A[7])
                self.A[7] += 4
                return True

            if opcode == 0x4AFC:  # ILLEGAL
                raise M68KError("Instruction ILLEGAL executee")

            # --- TRAP #vector ---
            if (opcode & 0xFFF0) == 0x4E40:
                vector = opcode & 0xF
                return self.do_trap(vector)

            # --- MOVE (00xx) ---
            if top4 in (1, 2, 3):  # MOVE.B, MOVE.L, MOVE.W
                return self.exec_move(opcode)

            # --- Misc (0100) ---
            if top4 == 4:
                return self.exec_0100(opcode)

            # --- ADDQ/SUBQ/Scc/DBcc (0101) ---
            if top4 == 5:
                return self.exec_0101(opcode)

            # --- Bcc/BRA/BSR (0110) ---
            if top4 == 6:
                return self.exec_bcc(opcode)

            # --- MOVEQ (0111) ---
            if top4 == 7:
                reg = (opcode >> 9) & 7
                data = opcode & 0xFF
                if data & 0x80:
                    data = data | 0xFFFFFF00  # Sign extend
                self.D[reg] = data & 0xFFFFFFFF
                self.set_flags_nzvc(self.D[reg], 4)
                return True

            # --- OR/DIV/SBCD (1000) ---
            if top4 == 8:
                return self.exec_1000(opcode)

            # --- SUB/SUBA (1001) ---
            if top4 == 9:
                return self.exec_addsub(opcode, is_add=False)

            # --- (1010) - unassigned ---
            if top4 == 0xA:
                raise M68KError(f"Instruction A-line non supportee: ${opcode:04X}")

            # --- CMP/EOR (1011) ---
            if top4 == 0xB:
                return self.exec_1011(opcode)

            # --- AND/MUL/ABCD/EXG (1100) ---
            if top4 == 0xC:
                return self.exec_1100(opcode)

            # --- ADD/ADDA (1101) ---
            if top4 == 0xD:
                return self.exec_addsub(opcode, is_add=True)

            # --- Shift/Rotate (1110) ---
            if top4 == 0xE:
                return self.exec_shift(opcode)

            # --- Bit manip / MOVEP / Immediate (0000) ---
            if top4 == 0:
                return self.exec_0000(opcode)

            raise M68KError(f"Instruction non implementee: ${opcode:04X} a PC=${pc_before:06X}")

        except M68KError as e:
            print(f"Erreur CPU a PC=${pc_before:06X}: {e}")
            self.halted = True
            self.exit_code = 1
            return False

    # --- TRAP handler ---
    def do_trap(self, vector):
        if vector == 15:
            func = self.D[0] & 0xFF
            if func == 9:
                if self.verbose:
                    print("  TRAP #15: Fin du programme")
                self.halted = True
                self.exit_code = 0
                return True
            elif func == 14:
                # Afficher chaine a A1
                addr = self.A[0 + 1]  # A1
                s = []
                for i in range(4096):
                    c = self.read8(addr + i)
                    if c == 0: break
                    s.append(chr(c))
                text = ''.join(s)
                self.output += text
                if self.verbose:
                    print(f"  TRAP #15 D0=14: Print '{text.rstrip()}'")
                return True
            elif func == 13:
                # Afficher D1 en decimal
                val = self.to_signed(self.D[1], 4)
                text = str(val)
                self.output += text
                if self.verbose:
                    print(f"  TRAP #15 D0=13: PrintNum {val}")
                return True
            else:
                if self.verbose:
                    print(f"  TRAP #15 D0={func}: ignore")
                return True
        else:
            if self.verbose:
                print(f"  TRAP #{vector}: ignore")
            return True

    # --- MOVE (top4 = 1,2,3) ---
    def exec_move(self, opcode):
        top4 = (opcode >> 12) & 0xF
        if top4 == 1: size = 1    # MOVE.B
        elif top4 == 3: size = 2  # MOVE.W
        elif top4 == 2: size = 4  # MOVE.L
        else:
            raise M68KError(f"MOVE: taille invalide top4={top4}")

        src_mode = (opcode >> 3) & 7
        src_reg  = opcode & 7
        dst_reg  = (opcode >> 9) & 7
        dst_mode = (opcode >> 6) & 7

        val, _ = self.read_ea(src_mode, src_reg, size)

        # MOVEA ?
        if dst_mode == 1:
            # MOVEA - pas de flags
            if size == 2:
                val = self.sign_extend(val, 2) & 0xFFFFFFFF
            self.A[dst_reg] = val & 0xFFFFFFFF
        else:
            self.write_ea(dst_mode, dst_reg, val, size)
            self.set_flags_nzvc(val, size)
        return True

    # --- 0100xxxx (misc: CLR, NEG, NOT, EXT, SWAP, TST, LEA, PEA, etc.) ---
    def exec_0100(self, opcode):
        # LEA: 0100 rrr 111 EEE EEE
        if (opcode & 0xF1C0) == 0x41C0:
            reg = (opcode >> 9) & 7
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            addr = self.calc_ea_addr(ea_mode, ea_reg)
            self.A[reg] = addr & 0xFFFFFFFF
            return True

        # PEA: 0100 1000 01 EEE EEE
        if (opcode & 0xFFC0) == 0x4840:
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            addr = self.calc_ea_addr(ea_mode, ea_reg)
            self.A[7] = (self.A[7] - 4) & 0xFFFFFFFF
            self.write32(self.A[7], addr)
            return True

        # CLR: 0100 0010 ss EEE EEE
        if (opcode & 0xFF00) == 0x4200:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            self.write_ea(ea_mode, ea_reg, 0, size)
            self.SR = (self.SR & ~(CCR_N | CCR_V | CCR_C)) | CCR_Z
            return True

        # NEG: 0100 0100 ss EEE EEE
        if (opcode & 0xFF00) == 0x4400:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (-self.to_signed(val, size)) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size, carry=(result != 0))
            return True

        # NOT: 0100 0110 ss EEE EEE
        if (opcode & 0xFF00) == 0x4600:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (~val) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # TST: 0100 1010 ss EEE EEE
        if (opcode & 0xFF00) == 0x4A00:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            self.set_flags_nzvc(val, size)
            return True

        # EXT.W: 0100 1000 1000 0 rrr
        if (opcode & 0xFFF8) == 0x4880:
            reg = opcode & 7
            v = self.D[reg] & 0xFF
            if v & 0x80:
                v = v | 0xFF00
            self.D[reg] = (self.D[reg] & 0xFFFF0000) | (v & 0xFFFF)
            self.set_flags_nzvc(v, 2)
            return True

        # EXT.L: 0100 1000 1100 0 rrr
        if (opcode & 0xFFF8) == 0x48C0:
            reg = opcode & 7
            v = self.D[reg] & 0xFFFF
            if v & 0x8000:
                v = v | 0xFFFF0000
            self.D[reg] = v & 0xFFFFFFFF
            self.set_flags_nzvc(v, 4)
            return True

        # SWAP: 0100 1000 0100 0 rrr
        if (opcode & 0xFFF8) == 0x4840:
            reg = opcode & 7
            v = self.D[reg]
            self.D[reg] = ((v & 0xFFFF) << 16) | ((v >> 16) & 0xFFFF)
            self.set_flags_nzvc(self.D[reg], 4)
            return True

        # LINK: 0100 1110 0101 0 rrr
        if (opcode & 0xFFF8) == 0x4E50:
            reg = opcode & 7
            disp = self.sign_extend(self.fetch16(), 2)
            self.A[7] = (self.A[7] - 4) & 0xFFFFFFFF
            self.write32(self.A[7], self.A[reg])
            self.A[reg] = self.A[7]
            self.A[7] = (self.A[7] + disp) & 0xFFFFFFFF
            return True

        # UNLK: 0100 1110 0101 1 rrr
        if (opcode & 0xFFF8) == 0x4E58:
            reg = opcode & 7
            self.A[7] = self.A[reg]
            self.A[reg] = self.read32(self.A[7])
            self.A[7] = (self.A[7] + 4) & 0xFFFFFFFF
            return True

        # JMP: 0100 1110 11 EEE EEE
        if (opcode & 0xFFC0) == 0x4EC0:
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            self.PC = self.calc_ea_addr(ea_mode, ea_reg)
            return True

        # JSR: 0100 1110 10 EEE EEE
        if (opcode & 0xFFC0) == 0x4E80:
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            addr = self.calc_ea_addr(ea_mode, ea_reg)
            self.A[7] = (self.A[7] - 4) & 0xFFFFFFFF
            self.write32(self.A[7], self.PC)
            self.PC = addr
            return True

        # MOVEM: 0100 1x00 1s EEE EEE (register list)
        if (opcode & 0xFB80) == 0x4880:
            direction = (opcode >> 10) & 1  # 0=reg-to-mem, 1=mem-to-reg
            sz_bit = (opcode >> 6) & 1  # 0=W, 1=L
            size = 4 if sz_bit else 2
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            mask = self.fetch16()
            return self.exec_movem(direction, size, ea_mode, ea_reg, mask)

        # MOVE from SR: 0100 0000 11 EEE EEE
        if (opcode & 0xFFC0) == 0x40C0:
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            self.write_ea(ea_mode, ea_reg, self.SR, 2)
            return True

        # MOVE to CCR: 0100 0100 11 EEE EEE
        if (opcode & 0xFFC0) == 0x44C0:
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            self.SR = (self.SR & 0xFF00) | (val & 0xFF)
            return True

        # MOVE to SR: 0100 0110 11 EEE EEE
        if (opcode & 0xFFC0) == 0x46C0:
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            self.SR = val & 0xFFFF
            return True

        # CHK: 0100 rrr 110 EEE EEE
        if (opcode & 0xF1C0) == 0x4180:
            # Just skip for now
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            self.read_ea(ea_mode, ea_reg, 2)  # consume ext words
            return True

        raise M68KError(f"Instruction 0100 non implementee: ${opcode:04X}")

    def exec_movem(self, direction, size, ea_mode, ea_reg, mask):
        if direction == 0:  # Register to memory
            if ea_mode == 4:  # -(An) predecrement
                # Pour -(An), les bits sont inverses: A7..A0, D7..D0
                for i in range(15, -1, -1):
                    if mask & (1 << (15 - i)):
                        if i < 8:
                            val = self.D[i]
                        else:
                            val = self.A[i - 8]
                        self.A[ea_reg] = (self.A[ea_reg] - size) & 0xFFFFFFFF
                        if size == 2:
                            self.write16(self.A[ea_reg], val & 0xFFFF)
                        else:
                            self.write32(self.A[ea_reg], val)
            else:
                addr = self.calc_ea_addr(ea_mode, ea_reg)
                for i in range(16):
                    if mask & (1 << i):
                        if i < 8:
                            val = self.D[i]
                        else:
                            val = self.A[i - 8]
                        if size == 2:
                            self.write16(addr, val & 0xFFFF)
                        else:
                            self.write32(addr, val)
                        addr += size
        else:  # Memory to register
            if ea_mode == 3:  # (An)+ postincrement
                addr = self.A[ea_reg]
                for i in range(16):
                    if mask & (1 << i):
                        if size == 2:
                            val = self.sign_extend(self.read16(addr), 2)
                        else:
                            val = self.read32(addr)
                        if i < 8:
                            self.D[i] = val & 0xFFFFFFFF
                        else:
                            self.A[i - 8] = val & 0xFFFFFFFF
                        addr += size
                self.A[ea_reg] = addr & 0xFFFFFFFF
            else:
                addr = self.calc_ea_addr(ea_mode, ea_reg)
                for i in range(16):
                    if mask & (1 << i):
                        if size == 2:
                            val = self.sign_extend(self.read16(addr), 2)
                        else:
                            val = self.read32(addr)
                        if i < 8:
                            self.D[i] = val & 0xFFFFFFFF
                        else:
                            self.A[i - 8] = val & 0xFFFFFFFF
                        addr += size
        return True

    # --- ADDQ/SUBQ/Scc/DBcc (0101) ---
    def exec_0101(self, opcode):
        sz_bits = (opcode >> 6) & 3

        # Scc: 0101 cccc 11 EEE EEE
        if sz_bits == 3:
            cc = (opcode >> 8) & 0xF
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            # DBcc: 0101 cccc 11001 rrr
            if ea_mode == 1:
                # DBcc
                disp = self.sign_extend(self.fetch16(), 2)
                if not self.test_cc(cc):
                    dn = (self.D[ea_reg] & 0xFFFF) - 1
                    self.D[ea_reg] = (self.D[ea_reg] & 0xFFFF0000) | (dn & 0xFFFF)
                    if dn != -1:
                        self.PC = (self.PC - 2 + disp) & 0xFFFFFFFF
                return True
            else:
                # Scc
                val = 0xFF if self.test_cc(cc) else 0x00
                self.write_ea(ea_mode, ea_reg, val, 1)
                return True

        size = self.op_size(sz_bits)
        data3 = (opcode >> 9) & 7
        if data3 == 0: data3 = 8  # data 0 encodes 8
        is_sub = (opcode >> 8) & 1
        ea_mode = (opcode >> 3) & 7
        ea_reg  = opcode & 7

        if ea_mode == 1:
            # ADDQ/SUBQ to An - full 32-bit, no flags
            if is_sub:
                self.A[ea_reg] = (self.A[ea_reg] - data3) & 0xFFFFFFFF
            else:
                self.A[ea_reg] = (self.A[ea_reg] + data3) & 0xFFFFFFFF
            return True

        val, _ = self.read_ea(ea_mode, ea_reg, size)
        mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
        if is_sub:
            result = (val - data3) & mask
        else:
            result = (val + data3) & mask
        self.write_ea(ea_mode, ea_reg, result, size)
        self.set_flags_nzvc(result, size)
        return True

    # --- Bcc/BRA/BSR (0110) ---
    def exec_bcc(self, opcode):
        cc = (opcode >> 8) & 0xF
        disp8 = opcode & 0xFF

        if disp8 == 0:
            # Word displacement
            disp = self.sign_extend(self.fetch16(), 2)
        elif disp8 == 0xFF:
            # Long displacement (68020+), not supported
            raise M68KError("BCC long displacement non supporte")
        else:
            # Byte displacement
            disp = self.sign_extend(disp8, 1)

        if cc == 1:  # BSR
            self.A[7] = (self.A[7] - 4) & 0xFFFFFFFF
            self.write32(self.A[7], self.PC)
            self.PC = (self.PC - (0 if disp8 == 0 else 2) + disp) & 0xFFFFFFFF
            return True

        if self.test_cc(cc):
            self.PC = (self.PC - (0 if disp8 == 0 else 2) + disp) & 0xFFFFFFFF
        return True

    # --- OR/DIV/SBCD (1000) ---
    def exec_1000(self, opcode):
        reg = (opcode >> 9) & 7
        opmode = (opcode >> 6) & 7
        ea_mode = (opcode >> 3) & 7
        ea_reg  = opcode & 7

        # SBCD: 1000 rrr 10000 x rrr
        if (opcode & 0xF1F0) == 0x8100:
            # Simplified SBCD - just skip
            return True

        # DIVU: 1000 rrr 011 EEE EEE
        if opmode == 3:
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            if val == 0:
                raise M68KError("Division par zero (DIVU)")
            dividend = self.D[reg] & 0xFFFFFFFF
            quotient = dividend // val
            remainder = dividend % val
            if quotient > 0xFFFF:
                self.SR |= CCR_V
            else:
                self.D[reg] = ((remainder & 0xFFFF) << 16) | (quotient & 0xFFFF)
                self.set_flags_nzvc(quotient, 2)
            return True

        # DIVS: 1000 rrr 111 EEE EEE
        if opmode == 7:
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            val_s = self.to_signed(val, 2)
            if val_s == 0:
                raise M68KError("Division par zero (DIVS)")
            dividend = self.to_signed(self.D[reg], 4)
            quotient = int(dividend / val_s)  # truncate toward zero
            remainder = dividend - quotient * val_s
            if quotient < -32768 or quotient > 32767:
                self.SR |= CCR_V
            else:
                self.D[reg] = ((remainder & 0xFFFF) << 16) | (quotient & 0xFFFF)
                self.set_flags_nzvc(quotient & 0xFFFF, 2)
            return True

        # OR
        if opmode in (0, 1, 2):  # OR <ea>,Dn
            size = self.op_size(opmode)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (self.get_d(reg, size) | val) & mask
            self.set_d(reg, result, size)
            self.set_flags_nzvc(result, size)
            return True
        if opmode in (4, 5, 6):  # OR Dn,<ea>
            size = self.op_size(opmode - 4)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (self.get_d(reg, size) | val) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        raise M68KError(f"OR/DIV instruction non implementee: ${opcode:04X}")

    # --- ADD/SUB (1001/1101) ---
    def exec_addsub(self, opcode, is_add):
        reg = (opcode >> 9) & 7
        opmode = (opcode >> 6) & 7
        ea_mode = (opcode >> 3) & 7
        ea_reg  = opcode & 7

        # ADDA/SUBA: opmode 3 (word) or 7 (long)
        if opmode == 3 or opmode == 7:
            size = 2 if opmode == 3 else 4
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            if size == 2:
                val = self.sign_extend(val, 2)
            if is_add:
                self.A[reg] = (self.A[reg] + val) & 0xFFFFFFFF
            else:
                self.A[reg] = (self.A[reg] - val) & 0xFFFFFFFF
            return True

        # ADD/SUB <ea>,Dn (opmode 0,1,2)
        if opmode in (0, 1, 2):
            size = self.op_size(opmode)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            dn = self.get_d(reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            if is_add:
                result = (dn + val) & mask
            else:
                result = (dn - val) & mask
            self.set_d(reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # ADD/SUB Dn,<ea> (opmode 4,5,6)
        if opmode in (4, 5, 6):
            size = self.op_size(opmode - 4)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            dn = self.get_d(reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            if is_add:
                result = (val + dn) & mask
            else:
                result = (val - dn) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        raise M68KError(f"ADD/SUB non implemente: opmode={opmode}")

    # --- CMP/EOR (1011) ---
    def exec_1011(self, opcode):
        reg = (opcode >> 9) & 7
        opmode = (opcode >> 6) & 7
        ea_mode = (opcode >> 3) & 7
        ea_reg  = opcode & 7

        # CMPA: opmode 3 (word) or 7 (long)
        if opmode == 3 or opmode == 7:
            size = 2 if opmode == 3 else 4
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            if size == 2:
                val = self.sign_extend(val, 2)
            result = (self.A[reg] - val) & 0xFFFFFFFF
            self.set_flags_nzvc(result, 4)
            return True

        # CMP: opmode 0,1,2
        if opmode in (0, 1, 2):
            size = self.op_size(opmode)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            dn = self.get_d(reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (dn - val) & mask
            self.set_flags_nzvc(result, size)
            return True

        # EOR: opmode 4,5,6
        if opmode in (4, 5, 6):
            size = self.op_size(opmode - 4)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            dn = self.get_d(reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (dn ^ val) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        raise M68KError(f"CMP/EOR non implemente: opmode={opmode}")

    # --- AND/MUL/ABCD/EXG (1100) ---
    def exec_1100(self, opcode):
        reg = (opcode >> 9) & 7
        opmode = (opcode >> 6) & 7
        ea_mode = (opcode >> 3) & 7
        ea_reg  = opcode & 7

        # EXG: 1100 xxx 1 ooooo yyy
        if (opcode & 0xF130) == 0xC100:
            exg_mode = (opcode >> 3) & 0x1F
            if exg_mode == 0x08:  # Dx,Dy
                self.D[reg], self.D[ea_reg] = self.D[ea_reg], self.D[reg]
            elif exg_mode == 0x09:  # Ax,Ay
                self.A[reg], self.A[ea_reg] = self.A[ea_reg], self.A[ea_reg]
                self.A[reg], self.A[ea_reg] = self.A[ea_reg], self.A[reg]
                # Simplified: swap
                reg_a = reg
                reg_b = ea_reg
                self.A[reg_a], self.A[reg_b] = self.A[reg_b], self.A[reg_a]
            elif exg_mode == 0x11:  # Dx,Ay
                self.D[reg], self.A[ea_reg] = self.A[ea_reg], self.D[reg]
            return True

        # ABCD: 1100 rrr 10000 x rrr
        if (opcode & 0xF1F0) == 0xC100:
            return True  # simplified

        # MULU: 1100 rrr 011 EEE EEE
        if opmode == 3:
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            result = (self.D[reg] & 0xFFFF) * (val & 0xFFFF)
            self.D[reg] = result & 0xFFFFFFFF
            self.set_flags_nzvc(result, 4)
            return True

        # MULS: 1100 rrr 111 EEE EEE
        if opmode == 7:
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            a = self.to_signed(self.D[reg] & 0xFFFF, 2)
            b = self.to_signed(val & 0xFFFF, 2)
            result = (a * b) & 0xFFFFFFFF
            self.D[reg] = result
            self.set_flags_nzvc(result, 4)
            return True

        # AND <ea>,Dn (opmode 0,1,2)
        if opmode in (0, 1, 2):
            size = self.op_size(opmode)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (self.get_d(reg, size) & val) & mask
            self.set_d(reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # AND Dn,<ea> (opmode 4,5,6)
        if opmode in (4, 5, 6):
            size = self.op_size(opmode - 4)
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (self.get_d(reg, size) & val) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        raise M68KError(f"AND/MUL non implemente: ${opcode:04X}")

    # --- Shift/Rotate (1110) ---
    def exec_shift(self, opcode):
        if (opcode >> 6) & 3 == 3:
            # Memory shift/rotate (1 bit)
            direction = (opcode >> 8) & 1  # 0=right, 1=left
            stype = (opcode >> 9) & 3
            ea_mode = (opcode >> 3) & 7
            ea_reg  = opcode & 7
            val, _ = self.read_ea(ea_mode, ea_reg, 2)
            if direction == 0:  # right
                if stype == 0:  # ASR
                    carry = val & 1
                    result = (val >> 1) | (val & 0x8000)
                elif stype == 1:  # LSR
                    carry = val & 1
                    result = val >> 1
                elif stype == 2:  # ROXR
                    carry = val & 1
                    x = 1 if self.SR & CCR_X else 0
                    result = (val >> 1) | (x << 15)
                else:  # ROR
                    carry = val & 1
                    result = (val >> 1) | ((val & 1) << 15)
            else:  # left
                if stype == 0:  # ASL
                    carry = (val >> 15) & 1
                    result = (val << 1) & 0xFFFF
                elif stype == 1:  # LSL
                    carry = (val >> 15) & 1
                    result = (val << 1) & 0xFFFF
                elif stype == 2:  # ROXL
                    carry = (val >> 15) & 1
                    x = 1 if self.SR & CCR_X else 0
                    result = ((val << 1) | x) & 0xFFFF
                else:  # ROL
                    carry = (val >> 15) & 1
                    result = ((val << 1) | carry) & 0xFFFF
            self.write_ea(ea_mode, ea_reg, result, 2)
            self.set_flags_nzvc(result, 2, carry=bool(carry))
            return True

        # Register shift
        count_reg_flag = (opcode >> 5) & 1
        direction = (opcode >> 8) & 1  # 0=right, 1=left
        stype = (opcode >> 3) & 3
        sz_bits = (opcode >> 6) & 3
        size = self.op_size(sz_bits)
        reg = opcode & 7
        creg = (opcode >> 9) & 7

        if count_reg_flag:
            count = self.D[creg] & 63
        else:
            count = creg
            if count == 0: count = 8

        mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
        sign_bit = {1: 0x80, 2: 0x8000, 4: 0x80000000}[size]
        val = self.get_d(reg, size)
        carry = False

        for _ in range(count):
            if direction == 0:  # right
                carry = bool(val & 1)
                if stype == 0:  # ASR
                    val = (val >> 1) | (val & sign_bit)
                elif stype == 1:  # LSR
                    val = val >> 1
                elif stype == 2:  # ROXR
                    x = 1 if self.SR & CCR_X else 0
                    new_carry = val & 1
                    val = (val >> 1) | (x * sign_bit)
                    carry = bool(new_carry)
                else:  # ROR
                    c = val & 1
                    val = (val >> 1) | (c * sign_bit)
                    carry = bool(c)
            else:  # left
                carry = bool(val & sign_bit)
                if stype == 0:  # ASL
                    val = (val << 1) & mask
                elif stype == 1:  # LSL
                    val = (val << 1) & mask
                elif stype == 2:  # ROXL
                    x = 1 if self.SR & CCR_X else 0
                    new_carry = bool(val & sign_bit)
                    val = ((val << 1) | x) & mask
                    carry = new_carry
                else:  # ROL
                    c = 1 if (val & sign_bit) else 0
                    val = ((val << 1) | c) & mask
                    carry = bool(c)

        self.set_d(reg, val, size)
        self.set_flags_nzvc(val, size, carry=carry)
        return True

    # --- Immediate / Bit manip (0000) ---
    def exec_0000(self, opcode):
        ea_mode = (opcode >> 3) & 7
        ea_reg  = opcode & 7

        # ORI: 0000 0000 ss EEE EEE
        if (opcode & 0xFF00) == 0x0000:
            sz_bits = (opcode >> 6) & 3
            # ORI to CCR: 0000 0000 0011 1100
            if opcode == 0x003C:
                imm = self.fetch16() & 0xFF
                self.SR = (self.SR & 0xFF00) | ((self.SR | imm) & 0xFF)
                return True
            # ORI to SR: 0000 0000 0111 1100
            if opcode == 0x007C:
                imm = self.fetch16()
                self.SR |= imm
                return True
            size = self.op_size(sz_bits)
            if size <= 2:
                imm = self.fetch16()
                if size == 1: imm &= 0xFF
            else:
                imm = (self.fetch16() << 16) | self.fetch16()
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (val | imm) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # ANDI: 0000 0010 ss EEE EEE
        if (opcode & 0xFF00) == 0x0200:
            sz_bits = (opcode >> 6) & 3
            if opcode == 0x023C:  # ANDI to CCR
                imm = self.fetch16() & 0xFF
                self.SR = (self.SR & 0xFF00) | ((self.SR & imm) & 0xFF)
                return True
            if opcode == 0x027C:  # ANDI to SR
                imm = self.fetch16()
                self.SR &= imm
                return True
            size = self.op_size(sz_bits)
            if size <= 2:
                imm = self.fetch16()
                if size == 1: imm &= 0xFF
            else:
                imm = (self.fetch16() << 16) | self.fetch16()
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (val & imm) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # SUBI: 0000 0100 ss EEE EEE
        if (opcode & 0xFF00) == 0x0400:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            if size <= 2:
                imm = self.fetch16()
                if size == 1: imm &= 0xFF
            else:
                imm = (self.fetch16() << 16) | self.fetch16()
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (val - imm) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # ADDI: 0000 0110 ss EEE EEE
        if (opcode & 0xFF00) == 0x0600:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            if size <= 2:
                imm = self.fetch16()
                if size == 1: imm &= 0xFF
            else:
                imm = (self.fetch16() << 16) | self.fetch16()
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (val + imm) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # EORI: 0000 1010 ss EEE EEE
        if (opcode & 0xFF00) == 0x0A00:
            sz_bits = (opcode >> 6) & 3
            if opcode == 0x0A3C:  # EORI to CCR
                imm = self.fetch16() & 0xFF
                self.SR = (self.SR & 0xFF00) | ((self.SR ^ imm) & 0xFF)
                return True
            size = self.op_size(sz_bits)
            if size <= 2:
                imm = self.fetch16()
                if size == 1: imm &= 0xFF
            else:
                imm = (self.fetch16() << 16) | self.fetch16()
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (val ^ imm) & mask
            self.write_ea(ea_mode, ea_reg, result, size)
            self.set_flags_nzvc(result, size)
            return True

        # CMPI: 0000 1100 ss EEE EEE
        if (opcode & 0xFF00) == 0x0C00:
            sz_bits = (opcode >> 6) & 3
            size = self.op_size(sz_bits)
            if size <= 2:
                imm = self.fetch16()
                if size == 1: imm &= 0xFF
            else:
                imm = (self.fetch16() << 16) | self.fetch16()
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}[size]
            result = (val - imm) & mask
            self.set_flags_nzvc(result, size)
            return True

        # BTST/BCHG/BCLR/BSET with immediate bit number: 0000 1000 xx EEE EEE
        if (opcode & 0xFFC0) == 0x0800:  # BTST #imm
            bit = self.fetch16() & 0xFF
            val, _ = self.read_ea(ea_mode, ea_reg, 1 if ea_mode != 0 else 4)
            if val & (1 << (bit & (31 if ea_mode == 0 else 7))):
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            return True

        if (opcode & 0xFFC0) == 0x0840:  # BCHG #imm
            bit = self.fetch16() & 0xFF
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            result = val ^ mask_bit
            self.write_ea(ea_mode, ea_reg, result, size)
            return True

        if (opcode & 0xFFC0) == 0x0880:  # BCLR #imm
            bit = self.fetch16() & 0xFF
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            result = val & ~mask_bit
            self.write_ea(ea_mode, ea_reg, result, size)
            return True

        if (opcode & 0xFFC0) == 0x08C0:  # BSET #imm
            bit = self.fetch16() & 0xFF
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            result = val | mask_bit
            self.write_ea(ea_mode, ea_reg, result, size)
            return True

        # BTST Dn: 0000 rrr 100 EEE EEE
        if (opcode & 0xF1C0) == 0x0100:
            dreg = (opcode >> 9) & 7
            bit = self.D[dreg]
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            return True

        # BCHG Dn: 0000 rrr 101 EEE EEE
        if (opcode & 0xF1C0) == 0x0140:
            dreg = (opcode >> 9) & 7
            bit = self.D[dreg]
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            result = val ^ mask_bit
            self.write_ea(ea_mode, ea_reg, result, size)
            return True

        # BCLR Dn: 0000 rrr 110 EEE EEE
        if (opcode & 0xF1C0) == 0x0180:
            dreg = (opcode >> 9) & 7
            bit = self.D[dreg]
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            result = val & ~mask_bit
            self.write_ea(ea_mode, ea_reg, result, size)
            return True

        # BSET Dn: 0000 rrr 111 EEE EEE
        if (opcode & 0xF1C0) == 0x01C0:
            dreg = (opcode >> 9) & 7
            bit = self.D[dreg]
            size = 4 if ea_mode == 0 else 1
            val, _ = self.read_ea(ea_mode, ea_reg, size)
            mask_bit = 1 << (bit & (31 if ea_mode == 0 else 7))
            if val & mask_bit:
                self.SR &= ~CCR_Z
            else:
                self.SR |= CCR_Z
            result = val | mask_bit
            self.write_ea(ea_mode, ea_reg, result, size)
            return True

        # MOVEP: 0000 rrr 1xx 001 rrr
        if (opcode & 0xF138) == 0x0108:
            # Skip MOVEP for now
            self.fetch16()  # consume displacement
            return True

        raise M68KError(f"Instruction 0000 non implementee: ${opcode:04X}")

    # --- Execution ---
    def run(self, max_cycles=MAX_CYCLES):
        while not self.halted and self.cycles < max_cycles:
            if not self.step():
                break
        if not self.halted and self.cycles >= max_cycles:
            print(f"Erreur: limite de {max_cycles} cycles atteinte (boucle infinie?)")
            self.exit_code = 1
        return self.exit_code


# --- Chargement S-Record ---
def load_srecord(cpu, filename):
    """Charge un fichier S-Record en memoire."""
    entry_addr = None
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('S0'):
                continue  # Header
            if line.startswith('S1'):
                count = int(line[2:4], 16)
                addr = int(line[4:8], 16)
                data = bytes.fromhex(line[8:8+(count-3)*2])
                for i, b in enumerate(data):
                    cpu.mem[addr + i] = b
            elif line.startswith('S9'):
                entry_addr = int(line[4:8], 16)
            elif line.startswith('S5'):
                continue  # Record count
    return entry_addr


# --- Main ---
def main():
    verbose = '--verbose' in sys.argv or '-v' in sys.argv
    max_cycles = MAX_CYCLES

    # Parse --max-cycles
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    for i, a in enumerate(sys.argv[1:]):
        if a == '--max-cycles' and i + 2 < len(sys.argv):
            max_cycles = int(sys.argv[i + 2])

    if not args:
        print("Usage: python3 m68k_emu.py fichier.S68 [--verbose] [--max-cycles N]")
        sys.exit(1)

    filename = args[0]
    cpu = M68KCPU(verbose=verbose)
    entry = load_srecord(cpu, filename)

    if entry is None:
        print(f"Erreur: pas d'adresse d'entree (S9) dans {filename}")
        sys.exit(1)

    cpu.PC = entry
    if verbose:
        print(f"Chargement de {filename}, entree a ${entry:06X}")

    exit_code = cpu.run(max_cycles)

    if verbose:
        print(f"Cycles: {cpu.cycles}")
        print(f"D0=${cpu.D[0]:08X} D1=${cpu.D[1]:08X} D2=${cpu.D[2]:08X} D3=${cpu.D[3]:08X}")
        print(f"D4=${cpu.D[4]:08X} D5=${cpu.D[5]:08X} D6=${cpu.D[6]:08X} D7=${cpu.D[7]:08X}")
        print(f"A0=${cpu.A[0]:08X} A1=${cpu.A[1]:08X} A2=${cpu.A[2]:08X} A3=${cpu.A[3]:08X}")
        print(f"A4=${cpu.A[4]:08X} A5=${cpu.A[5]:08X} A6=${cpu.A[6]:08X} A7=${cpu.A[7]:08X}")

    if cpu.output:
        sys.stdout.write(cpu.output)

    sys.exit(exit_code)


if __name__ == '__main__':
    main()
