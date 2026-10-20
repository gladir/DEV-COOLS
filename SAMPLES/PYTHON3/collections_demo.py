import collections, itertools, functools, operator, copy, enum, dataclasses, typing, abc, contextlib
from collections import OrderedDict, defaultdict, Counter, deque, namedtuple, ChainMap, UserDict, UserList, UserString
c = Counter('abracadabra'); print(c.most_common(3), c['a'], sorted(c.elements())[:5], c + Counter('aab'), c - Counter('aab'))
d = defaultdict(list); d['x'].append(1); d['y'].extend([2,3]); print(d, dict(d), d.default_factory)
dq = deque([1,2,3], maxlen=5); dq.rotate(1); dq.appendleft(0); dq.extend([7,8,9]); print(dq, dq.maxlen, dq[0], dq.pop(), dq.popleft())
P = namedtuple('P', 'x y z', defaults=[0]); p = P(1,2); print(p, p._asdict(), p._replace(x=5), P._fields, P._make([4,5,6]), p.x+p.y, len(p), p[1], tuple(p))
od = OrderedDict([(1,'a'),(2,'b')]); od.move_to_end(1); print(od, list(od.keys()), od.popitem(last=False), repr(od))
cm = ChainMap({'a':1},{'b':2,'a':3}); print(cm['a'], cm['b'], dict(cm), list(cm.maps), cm.parents)
ud = UserDict(a=1); ud['b']=2; print(ud, len(ud), 'a' in ud, ud.data)
ul = UserList([3,1,2]); ul.sort(); ul.append(4); print(ul, ul[1:3], ul + [9])
us = UserString('abc'); print(us.upper(), us + 'd', len(us), us[1:])
print(list(itertools.islice(itertools.count(5,2), 4)), list(itertools.chain([1],[2,3])), list(itertools.product('ab',repeat=2)),
 list(itertools.permutations(range(3),2)), list(itertools.combinations('abcd',2)), list(itertools.combinations_with_replacement('ab',2)),
 list(itertools.accumulate([1,2,3,4])), list(itertools.groupby('aabbbc')) and [(k,list(g)) for k,g in itertools.groupby('aabbbc')],
 list(itertools.zip_longest('ab','xyz',fillvalue='-')), list(itertools.starmap(pow,[(2,3),(3,2)])), list(itertools.takewhile(lambda x:x<3,range(10))),
 list(itertools.dropwhile(lambda x:x<3,range(6))), list(itertools.repeat('x',3)), list(itertools.compress('abcd',[1,0,1,0])), list(itertools.filterfalse(None,[0,1,2])),
 [list(t) for t in itertools.tee(range(3),2)], list(itertools.cycle('ab'))[:0] if False else 1)
@functools.lru_cache(maxsize=None)
def fib(n): return n if n<2 else fib(n-1)+fib(n-2)
print(fib(50), fib.cache_info())
print(functools.reduce(operator.add, range(10)), functools.partial(pow, 2)(10), functools.partial(int, base=2)('101'))
@functools.total_ordering
class V:
    def __init__(s,v): s.v=v
    def __eq__(s,o): return s.v==o.v
    def __lt__(s,o): return s.v<o.v
print(V(1)<V(2), V(2)>=V(1), V(1)<=V(1))
@functools.singledispatch
def f(x): return 'obj'
@f.register(int)
def _(x): return 'int'
print(f(1), f('a'), f(1.5))
print(sorted([(1,'b'),(1,'a'),(0,'z')], key=operator.itemgetter(0)), operator.attrgetter('real')(3), operator.methodcaller('upper')('a'), sorted(['bb','a','ccc'], key=len))
print(sorted(['b','A','c'], key=functools.cmp_to_key(lambda a,b:(a.lower()>b.lower())-(a.lower()<b.lower()))))
a=[1,[2,3],{'k':[4]}]; b=copy.deepcopy(a); a[1].append(9); c2=copy.copy(a); print(b, a, c2[1] is a[1])
class Color(enum.Enum):
    RED=1; GREEN=2; BLUE=3
    def describe(self): return self.name.lower()
print(Color.RED, Color(2), Color['BLUE'], list(Color), Color.RED.value, Color.GREEN.describe(), Color.RED == Color.RED, Color.RED is Color(1), repr(Color.RED))
class Perm(enum.Flag):
    R=4; W=2; X=1
print(Perm.R|Perm.W, Perm(7), Perm.R in (Perm.R|Perm.X), bool(Perm(0)))
class N(enum.IntEnum):
    A=1; B=2
print(N.A+1, N.B>N.A, int(N.B), sorted([N.B,N.A]))
print(list(enum.auto() and [] ), enum.unique)
@dataclasses.dataclass(order=True)
class DC:
    a: int
    b: str = 'x'
    c: list = dataclasses.field(default_factory=list)
x = DC(1); print(x, x==DC(1), x<DC(2), dataclasses.asdict(x), dataclasses.replace(x,a=5), [f.name for f in dataclasses.fields(x)])
@dataclasses.dataclass(frozen=True)
class FZ: q: int
try: FZ(1).q = 2
except dataclasses.FrozenInstanceError as e: print('frozen', e)
T = typing.TypeVar('T')
def g(x: typing.List[int], y: typing.Optional[str] = None) -> typing.Dict[str, int]: return {}
print(typing.get_type_hints(g), typing.List[int], typing.Union[int,str], typing.Optional[int], typing.Tuple[int,...], typing.Callable[[int],str])
class A(abc.ABC):
    @abc.abstractmethod
    def m(self): ...
try: A()
except TypeError as e: print(e)
class B(A):
    def m(self): return 1
print(B().m(), isinstance(B(), A), issubclass(B, A))
@contextlib.contextmanager
def cm1(): 
    print('in'); yield 1; print('out')
with cm1() as v, contextlib.suppress(ZeroDivisionError): print(v, 1/0)
with contextlib.ExitStack() as st: st.callback(print, 'bye')
print(contextlib.closing, contextlib.nullcontext(5).__enter__())
