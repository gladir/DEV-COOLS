import sys, math
# classes & inheritance
class Base:
    count = 0
    def __init__(self, name): self.name = name; Base.count += 1
    def __repr__(self): return f'{type(self).__name__}({self.name!r})'
    def __str__(self): return f'<{self.name}>'
    def __eq__(self, o): return isinstance(o, Base) and self.name == o.name
    def __hash__(self): return hash(self.name)
    def __lt__(self, o): return self.name < o.name
    @property
    def upper(self): return self.name.upper()
    @upper.setter
    def upper(self, v): self.name = v.lower()
    @classmethod
    def make(cls, n): return cls(n)
    @staticmethod
    def helper(x): return x * 2
class Mixin:
    def hello(self): return 'hello ' + self.name
class Derived(Mixin, Base):
    def __init__(self, name, extra=0):
        super().__init__(name); self.extra = extra
    def __repr__(self): return super().__repr__() + f'[{self.extra}]'
d = Derived('abc', 3); b = Base.make('zzz')
print(d, repr(d), b, repr(b), d.hello(), d.upper, Base.count, Derived.__mro__, sorted([b, d]), {d: 1}[Derived('abc')], d == Derived('abc'), d != b)
d.upper = 'XYZ'; print(d.name, Base.helper(4), d.helper(5), isinstance(d, Mixin), issubclass(Derived, Base), type(d).__name__, d.__class__.__bases__)
print(hasattr(d, 'extra'), getattr(d, 'nope', 'dflt'), vars(d), d.__dict__ is vars(d), dir(d)[-3:], callable(d), id(d) == id(d))
# metaclass, descriptors, slots
class Meta(type):
    def __new__(m, n, b, ns):
        ns['tag'] = n.lower(); return super().__new__(m, n, b, ns)
    def __call__(cls, *a, **k):
        o = super().__call__(*a, **k); o.created = True; return o
class WithMeta(metaclass=Meta):
    def __init__(self, v=1): self.v = v
w = WithMeta(5); print(w.tag, w.created, w.v, type(WithMeta).__name__)
class Desc:
    def __set_name__(self, owner, name): self.n = '_' + name
    def __get__(self, obj, typ=None): return self if obj is None else getattr(obj, self.n, None)
    def __set__(self, obj, v): setattr(obj, self.n, v * 2)
class UD:
    x = Desc()
u = UD(); u.x = 21; print(u.x, UD.x.n, u.__dict__)
class Sl:
    __slots__ = ('a', 'b')
    def __init__(self): self.a = 1
s = Sl(); print(s.a, hasattr(s, 'b'), hasattr(s, '__dict__'))
try: s.c = 3
except AttributeError as e: print('AttributeError', e)
# operator overloading
class Vec:
    def __init__(self, *c): self.c = c
    def __add__(self, o): return Vec(*(a + b for a, b in zip(self.c, o.c)))
    def __mul__(self, k): return Vec(*(a * k for a in self.c))
    __rmul__ = __mul__
    def __neg__(self): return Vec(*(-a for a in self.c))
    def __abs__(self): return math.sqrt(sum(a * a for a in self.c))
    def __len__(self): return len(self.c)
    def __getitem__(self, i): return self.c[i]
    def __iter__(self): return iter(self.c)
    def __contains__(self, x): return x in self.c
    def __bool__(self): return any(self.c)
    def __repr__(self): return 'Vec' + repr(self.c)
    def __call__(self, *a): return sum(a)
    def __enter__(self): print('enter'); return self
    def __exit__(self, *e): print('exit', e[0].__name__ if e[0] else None); return True
v = Vec(1, 2, 3)
print(v + v, 2 * v, v * 3, -v, abs(Vec(3, 4)), len(v), v[1], list(v), 2 in v, bool(Vec(0, 0)), v(1, 2), v[1:], [x for x in reversed(v)] if hasattr(v, '__reversed__') else 'norev')
with v as vv: raise ValueError('swallowed')
# generators
def gen():
    x = yield 1
    print('got', x)
    try:
        y = yield 2
    except ValueError as e:
        print('caught', e); y = yield 99
    finally:
        print('fin')
    return y
g = gen(); print(next(g), g.send('A'), g.throw(ValueError('boom')), end=' ')
try: g.send('Z')
except StopIteration as e: print('stop', e.value)
def delegating():
    r = yield from gen2(); print('r', r); yield 'end'
def gen2():
    yield 'a'; yield 'b'; return 'ret'
print(list(delegating()))
print(list(x * x for x in range(5) if x % 2), {x: x * 2 for x in 'ab'}, {x % 3 for x in range(10)}, [(i, j) for i in range(3) for j in range(i)])
# closures / decorators
def counter():
    n = 0
    def inc(): nonlocal n; n += 1; return n
    return inc
c = counter(); print(c(), c(), c())
def deco(arg):
    def wrap(f):
        def inner(*a, **k): return f'{arg}:' + str(f(*a, **k))
        inner.__name__ = f.__name__; inner.__doc__ = f.__doc__; return inner
    return wrap
@deco('X')
def addone(x, *, y=1): "doc!"; return x + y
print(addone(1), addone(1, y=5), addone.__name__, addone.__doc__)
def kw(a, b=2, *args, c, d=4, **kwargs): return (a, b, args, c, d, kwargs)
print(kw(1, c=3), kw(1, 2, 3, 4, c=5, z=6), kw(*[1, 2], **{'c': 9}))
def pos(a, b, /, c): return a + b + c
print(pos(1, 2, c=3), (lambda *a, **k: (a, k))(1, 2, x=3))
