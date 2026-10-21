import itertools
def mk(kind, ctx, body_exc):
    # builds function source
    lines = ["def f(n):", "    out = []", "    for i in range(3):"]
    ind = "        "
    def block(inner):
        if ctx == 'try_finally':
            return [ind+"try:"] + [ind+"    "+l for l in inner] + [ind+"finally:", ind+"    out.append('fin%d' % i)"]
        if ctx == 'try_except':
            return [ind+"try:"] + [ind+"    "+l for l in inner] + [ind+"except ValueError as e:", ind+"    out.append('exc')"]
        if ctx == 'except_body':
            return [ind+"try:", ind+"    raise ValueError(i)", ind+"except ValueError as e:"] + [ind+"    "+l for l in inner]
        if ctx == 'except_bare':
            return [ind+"try:", ind+"    raise ValueError(i)", ind+"except:"] + [ind+"    "+l for l in inner]
        if ctx == 'with':
            return [ind+"with CM(out):"] + [ind+"    "+l for l in inner]
        if ctx == 'finally_body':
            return [ind+"try:", ind+"    pass", ind+"finally:"] + [ind+"    "+l for l in inner]
        if ctx == 'else':
            return [ind+"try:", ind+"    pass", ind+"except ValueError:", ind+"    pass", ind+"else:"] + [ind+"    "+l for l in inner]
    act = {'ret': ["return ('r', i, out)"], 'brk': ["if i == 1: break", "out.append('x%d' % i)"],
           'cont': ["if i == 1: continue", "out.append('x%d' % i)"], 'raise': ["if i == 1: raise KeyError('k')", "out.append('x%d' % i)"],
           'none': ["out.append('x%d' % i)"]}[kind]
    lines += block([ind+"    "+a for a in act] if False else [a for a in act])
    lines += ["    return ('end', out)"]
    return "\n".join(lines)
class CM:
    def __init__(self, out): self.out = out
    def __enter__(self): self.out.append('enter'); return self
    def __exit__(self, *a): self.out.append('exit'); return False
src_all = []
for kind in ['ret','brk','cont','raise','none']:
    for ctx in ['try_finally','try_except','except_body','except_bare','with','finally_body','else']:
        src = mk(kind, ctx, False)
        # fix indentation: inner lines need base indent
        src = src.replace("\n"+"        "+"    ", "\n"+"        "+"    ")
        ns = {'CM': CM}
        try:
            exec(src, ns)
        except SyntaxError as e:
            print(kind, ctx, 'SYNTAX', e); continue
        try: print(kind, ctx, ns['f'](0))
        except BaseException as e: print(kind, ctx, 'EXC', type(e).__name__, e)
