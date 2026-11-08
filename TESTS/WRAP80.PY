#!/usr/bin/env python3
"""Coupe les lignes de plus de 80 caracteres d'un source Pascal sans changer sa signification.
Coupures : espaces (ou apres ',' / ';') hors chaines, dans le code ou dans un commentaire ; blocs ASM laisses
tels quels (sauf commentaires) ; chaine trop longue : decoupee en 'a' + 'b'."""
import sys, re

LIMIT = 80

def scan(line, st):
    """Etat de chaque caractere : 'D' code, 'S' chaine, 'C' commentaire ({ } ou (* *)), 'L' commentaire // ; st = etat en debut de ligne
    ('', '{', '(*'). Rend (ctx, etat_fin)."""
    ctx = []
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if st == '{':
            ctx.append('C')
            if c == '}': st = ''
            i += 1
        elif st == '(*':
            ctx.append('C')
            if c == '*' and i + 1 < n and line[i + 1] == ')':
                ctx.append('C'); i += 2; st = ''
            else:
                i += 1
        else:
            if c == "'":
                j = i + 1
                while j < n:
                    if line[j] == "'":
                        if j + 1 < n and line[j + 1] == "'":
                            j += 2; continue
                        break
                    j += 1
                end = min(j, n - 1)
                ctx.extend('S' * (end - i + 1))
                i = end + 1
            elif c == '{':
                st = '{'; ctx.append('C'); i += 1
                # directive {$...}
            elif c == '(' and i + 1 < n and line[i + 1] == '*':
                st = '(*'; ctx.append('C'); ctx.append('C'); i += 2
            elif c == '/' and i + 1 < n and line[i + 1] == '/':
                ctx.extend('L' * (n - i)); i = n
            else:
                ctx.append('D'); i += 1
    return ctx, st

def words(line, ctx):
    return [(m.group(0).lower(), m.start()) for m in re.finditer(r'[A-Za-z_][A-Za-z_0-9]*', line) if ctx[m.start()] == 'D']

def wrap_line(line, st, asm, limit=LIMIT):
    """Rend la liste des lignes (sans EOL) et l'etat de fin (st, asm)."""
    out = []
    cur = line
    while True:
        ctx, st_end = scan(cur, st)
        # etat asm en fin de la ligne courante
        a = asm
        for w, pos in words(cur, ctx):
            if w == 'asm' and not a: a = True
            elif w == 'end' and a: a = False
        if len(cur) <= limit:
            out.append(cur); return out, st_end, a
        indent = len(cur) - len(cur.lstrip(' \t'))
        cands = []
        for k in range(indent + 1, min(len(cur), limit + 1)):
            if cur[k] == ' ' and ctx[k] in ('D', 'C') and ctx[k - 1] in ('D', 'C', 'S'):
                if asm and ctx[k] == 'D': continue
                # ne pas couper dans une directive {$...}
                if ctx[k] == 'C' and '{$' in cur[:k] and cur.rfind('{$', 0, k) > cur.rfind('}', 0, k): continue
                cands.append(k)
            elif cur[k - 1] in ',;' and ctx[k - 1] == 'D' and not asm and k > indent + 1 and cur[k] != ' ':
                cands.append(k - 0.5)
            elif (cur[k - 1] in '+-*/=' and ctx[k - 1] == 'D' and ctx[k] == 'D' and not asm and k > indent + 2
                  and cur[k] not in ' =>' and not (cur[k - 1] in '+-' and cur[k - 2] in 'Ee' and cur[k - 3:k - 2].isdigit())
                  and not (cur[k - 1] == '=' and cur[k] == '=')):
                cands.append(k + 0.25)
        if not cands:
            m = re.match(r'(\s*)(DB|DW)\s', cur, re.I)
            if asm and m:
                # table DB / DW trop longue : une seconde instruction DB / DW
                cut = None
                for k in range(min(len(cur) - 1, limit), indent + 6, -1):
                    if cur[k] == ',' and ctx[k] == 'D':
                        cut = k; break
                if cut is not None:
                    out.append(cur[:cut])
                    cur = m.group(1) + m.group(2) + ' ' + cur[cut + 1:]
                    continue
            # chaine trop longue : decouper a un espace interne
            if not asm:
                for k in range(min(len(cur) - 1, limit - 3), indent + 3, -1):
                    if cur[k] in ' ,' and ctx[k] == 'S' and ctx[k - 1] == 'S' and ctx[k + 1] == 'S' and cur[k + 1] != "'":
                        # a l'interieur d'une chaine : "abc def" -> "abc " + "def"
                        head = cur[:k + 1] + "' +"
                        tail = ' ' * (indent + 2) + "'" + cur[k + 1:]
                        cur2 = head
                        if len(head) <= limit:
                            ctxh, _ = scan(head, st)
                            out.append(head); cur = tail; asm = asm
                            break
                else:
                    out.append(cur); return out, st_end, a   # impossible a couper
                continue
            out.append(cur); return out, st_end, a
        # preference : apres ; ou , puis tout espace
        best = None
        if asm and not cands:
            pass
        for k in sorted(cands, reverse=True):
            kk = int(k + 0.5) if isinstance(k, float) else k
            prev = cur[kk - 1] if not isinstance(k, float) else cur[int(k - 0.5)]
            if (isinstance(k, float) and (k % 1) == 0.5) or (not isinstance(k, float) and cur[kk - 1] in ',;'):
                best = k; break
        if best is None:
            spaces = [k for k in cands if not isinstance(k, float)]
            best = max(spaces) if spaces else max(cands)
        if isinstance(best, float):
            cut = int(best + 0.5) if (best % 1) == 0.5 else int(best)
            head = cur[:cut]; tail = cur[cut:]
        else:
            head = cur[:best].rstrip(' '); tail = cur[best + 1:]
        # la ligne de suite garde l'indentation + 2 (dans un commentaire : indentation + 2 aussi)
        newline = ' ' * (indent + 2) + tail.lstrip(' ')
        hctx, hst = scan(head, st)
        out.append(head)
        for w, pos in words(head, hctx):
            if w == 'asm' and not asm: asm = True
            elif w == 'end' and asm: asm = False
        st = hst
        cur = newline

def process(path):
    raw = open(path, 'rb').read()
    try:
        text = raw.decode('utf-8'); enc = 'utf-8'
    except UnicodeDecodeError:
        text = raw.decode('latin-1'); enc = 'latin-1'
    crlf = '\r\n' in text
    eol = '\r\n' if crlf else '\n'
    lines = text.split('\n')
    res = []; st = ''; asm = False; changed = 0; stuck = 0
    for ln in lines:
        had_cr = ln.endswith('\r')
        body = ln[:-1] if had_cr else ln
        wl, st, asm = wrap_line(body, st, asm)
        if len(wl) > 1: changed += 1
        for x in wl:
            if len(x) > LIMIT: stuck += 1
        res.extend(x + ('\r' if had_cr else '') for x in wl)
    new = '\n'.join(res)
    if new != text:
        open(path, 'wb').write(new.encode(enc))
    return changed, stuck

if __name__ == '__main__':
    for p in sys.argv[1:]:
        c, s = process(p)
        print(p, 'lignes coupees:', c, 'restant >80:', s)
