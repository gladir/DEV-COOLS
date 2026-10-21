#!/usr/bin/env python3
# chkenc.py fichier.lst : decode les octets de l'encodeur avec objdump et
# compare chaque instruction (mnemonique, longueur, operandes) au listing.
import re, subprocess, sys, tempfile, os

def parse_lst(path):
    ins = []
    for line in open(path, encoding='latin-1'):
        m = re.match(r'^([0-9A-F]{8})  ((?:[0-9A-F]{2} )+)\s*(.*)$', line.rstrip('\n'))
        if m:
            off = int(m.group(1), 16)
            bs = bytes.fromhex(m.group(2).replace(' ', ''))
            ins.append((off, bs, m.group(3).strip()))
    return ins

def objdump(code):
    with tempfile.NamedTemporaryFile(delete=False) as t:
        t.write(code); name = t.name
    out = subprocess.run(['objdump', '-D', '-b', 'binary', '-m', 'i386', '-M', 'intel', name],
                         capture_output=True, text=True).stdout
    os.unlink(name)
    res = {}
    cur = None
    for line in out.splitlines():
        m = re.match(r'^\s*([0-9a-f]+):\t((?:[0-9a-f]{2} )+)\s*(.*)$', line)
        if m:
            off = int(m.group(1), 16)
            bs = bytes.fromhex(m.group(2).replace(' ', ''))
            txt = m.group(3).strip()
            if txt == '' and cur is not None:   # ligne de continuation
                res[cur][0] += bs
            else:
                res[off] = [bs, txt]; cur = off
    return res

def num(s):
    s = s.strip()
    return int(s, 16) if s.lower().startswith(('0x', '-0x')) else int(s)

def canon_mem(expr):
    """expression entre crochets ou ds:0x.. -> (base, index, scale, disp)"""
    e = expr.strip().lower()
    e = re.sub(r'^(byte|word|dword|qword|tbyte) ptr ', '', e)
    m = re.match(r'^(?:ds|es):(0x[0-9a-f]+|-?\d+)$', e)
    if m: return ('mem', None, None, 1, num(m.group(1)))
    m = re.match(r'^(?:[ds]s:)?\[(.*)\]$', e)
    if not m: return None
    body = m.group(1).replace(' ', '')
    base = idx = None; sc = 1; disp = 0
    for sign, term in re.findall(r'([+-]?)([^+-]+)', body):
        sg = -1 if sign == '-' else 1
        if re.match(r'^(0x[0-9a-f]+|\d+)$', term):
            disp += sg * num(term)
        elif '*' in term:
            r, s_ = term.split('*'); idx = r; sc = int(s_)
        elif re.match(r'^[a-z]{2,3}$', term):
            if base is None and idx is None: base = term
            elif base is None: base = term
            else: idx = term
        else:
            pass  # symbole : remplace par son adresse (octets a zero)
    return ('mem', base, idx, sc, disp)

def canon_operand(o):
    o = o.strip().lower()
    o = re.sub(r'\s+', ' ', o)
    if o == 'st': o = 'st(0)'
    if re.match(r'^[a-z]{2,3}$', o) or re.match(r'^st(\(\d\))?$', o):
        return ('reg', o)
    if re.match(r'^(0x[0-9a-f]+|-?\d+)$', o):
        return ('imm', num(o) & 0xffffffff)
    if o.startswith('offset '):
        return ('imm', 0)
    m = canon_mem(o)
    if m: return m
    # [symbole+...]
    m2 = re.match(r'^(?:(?:byte|word|dword|qword|tbyte) ptr )?\[(.*)\]$', o)
    if m2: return canon_mem('[' + re.sub(r'^[a-z_][a-z0-9_]*(?=[+\]]|$)', '', m2.group(1)).lstrip('+') + ']') or ('mem', None, None, 1, 0)
    return ('lbl', o)

def split_ops(s):
    ops, depth, cur = [], 0, ''
    for ch in s:
        if ch == '[' or ch == '(': depth += 1
        if ch == ']' or ch == ')': depth -= 1
        if ch == ',' and depth == 0: ops.append(cur); cur = ''
        else: cur += ch
    if cur.strip(): ops.append(cur)
    return ops

def norm_ours(txt):
    t = txt.strip()
    m = re.match(r'^(\S+(?: STOSD)?)\s*(.*)$', t)
    mn = m.group(1).lower(); rest = m.group(2)
    return mn, [canon_operand(x) for x in split_ops(rest)]

def norm_obj(txt):
    t = re.sub(r'\s+', ' ', txt.strip())
    m = re.match(r'^(rep \S+|\S+)\s*(.*)$', t)
    mn = m.group(1); rest = m.group(2)
    ops = [canon_operand(x) for x in split_ops(rest)]
    return mn, ops

SYNONYM = {'rep stosd': 'rep stos', 'jmp': 'jmp'}

def main():
    ins = parse_lst(sys.argv[1])
    code = b''.join(b for _, b, _ in ins)
    # les octets doivent etre contigus
    exp = 0
    for off, b, _ in ins:
        if off != exp: print('trou/recouvrement a', hex(off), 'attendu', hex(exp)); return 1
        exp += len(b)
    dis = objdump(code)
    bad = 0
    for off, b, txt in ins:
        d = dis.get(off)
        if d is None or d[0] != b:
            print('DECALAGE %08X: ours=%s  obj=%s  [%s]' % (off, b.hex(), d, txt)); bad += 1
            if bad > 8: return 1
            continue
        mo, oo = norm_ours(txt); md, od = norm_obj(d[1])
        mo2 = SYNONYM.get(mo, mo)
        if mo2 != md and not (md.startswith(mo2)):
            print('MNEMO %08X: ours=%s obj=%s' % (off, txt, d[1])); bad += 1; continue
        if mo.startswith('j') or mo == 'call':
            if oo and oo[0][0] != 'lbl' and oo != od:
                print('OPS %08X: ours=%s obj=%s' % (off, txt, d[1])); bad += 1
            continue
        if mo.startswith('rep'): continue
        if mo == 'imul' and len(oo) == 2 and len(od) == 3 and od[0] == od[1]: od = od[1:]
        if len(oo) != len(od):
            print('NOPS %08X: ours=%s obj=%s' % (off, txt, d[1])); bad += 1; continue
        for a, b2 in zip(oo, od):
            if a != b2:
                print('OP %08X: ours=%s obj=%s   %s vs %s' % (off, txt, d[1], a, b2)); bad += 1; break
    print('%d instructions verifiees, %d ecart(s)' % (len(ins), bad))
    return 1 if bad else 0

sys.exit(main())
