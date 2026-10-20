import sys, traceback, io
# exceptions
class MyErr(Exception):
    def __init__(self, msg, code=0): super().__init__(msg); self.code = code
def f(n):
    try:
        if n == 0: raise MyErr('zero', 5)
        if n == 1: raise KeyError('k')
        if n == 2: return 1 / 0
        if n == 3: int('x')
        if n == 4: [][1]
        if n == 5: None.foo
        if n == 6: raise
        return n
    except MyErr as e: return ('my', e.code, str(e), e.args)
    except (KeyError, ZeroDivisionError) as e: return (type(e).__name__, str(e), repr(e))
    except ValueError as e: return ('val', str(e))
    except Exception as e: return ('exc', type(e).__name__, str(e))
    else: return 'else'
    finally: print('fin', n)
for i in range(8): print(f(i))
def chain():
    try:
        try: 1 / 0
        except ZeroDivisionError as e: raise ValueError('wrapped') from e
    except ValueError as e: return repr(e.__cause__), e.__suppress_context__, e.__context__ is e.__cause__
print(chain())
try:
    try: raise KeyError('a')
    finally: print('cleanup')
except KeyError as e: print('outer', e)
def tb():
    try: f2()
    except Exception: return traceback.format_exc()
def f2(): g2()
def g2(): raise RuntimeError('deep')
print(tb())
try: raise SystemExit(3)
except SystemExit as e: print('exit', e.code)
e = Exception('a', 1); print(e.args, str(e), repr(e)); print(repr(KeyError()), str(KeyError('x')), str(OSError(2, 'No such')), repr(ValueError()))
try: open('/nonexistent/x')
except OSError as e: print(type(e).__name__, e.errno, e.strerror, e.filename, e)
try: assert 1 == 2, 'msg'
except AssertionError as e: print('assert', e)
try: raise StopIteration(5)
except StopIteration as e: print(e.value)
try: {}['a']
except LookupError as e: print(type(e).__name__, e)
print(issubclass(FileNotFoundError, OSError), ZeroDivisionError.__mro__)
import warnings
with warnings.catch_warnings(record=True) as w:
    warnings.simplefilter('always'); warnings.warn('hi', UserWarning); print(len(w), w[0].category.__name__, str(w[0].message))
# formatting
print('%5d|%-5d|%05d|%+d|%x|%X|%o|%e|%g|%10.3f|%s|%r|%c|%%|%5s|%-5s|' % (42, 42, 42, 42, 255, 255, 8, 12345.678, 0.0001234, 3.14159, 'a', 'a', 65, 'ab', 'ab'))
print('{:>8}|{:<8}|{:^8}|{:*^9}|{:08.3f}|{:,}|{:_}|{:b}|{:#x}|{:#o}|{:e}|{:%}|{:+.2f}|{!r}|{!s}|{0}{1}{0}'.format('r', 'l', 'c', 'm', 3.14159, 1234567, 1234567, 10, 255, 8, 1234.5, 0.256, 2.5, 'q', 'q', 'a', 'b'))
x = 3.14159; n = 42; s = 'hi'
print(f'{x:.2f} {n:5d} {s:>5} {n!r} {x=} {n*2} {s.upper()} {"nested"} {n:#b} {x:10.4e} {{literal}}')
print(f'{1_000_000:,}', f'{0.5:.0%}', f'{255:08b}', f'{"x":-^7}', f'{12345.6789:,.1f}')
print(str(1e16), str(1e-5), 1e15, 123456789012345678, 0.1 + 0.2, 1 / 3, 2 ** 0.5, 10 ** 20, 10 ** -2, -7 // 2, -7 % 3, 7 // -2, divmod(-7, 2), round(2.5), round(3.5), round(-0.5), round(1.2345, 2), int(-3.9), float('inf'), -float('inf'), float('nan'))
print(abs(-3), pow(2, 10), pow(2, -1), pow(3, 4, 5), 0b101, 0o17, 0xff, 1_0, 5 & 3, 5 | 3, 5 ^ 3, ~5, 1 << 10, -16 >> 2, 2 ** 100, (2 ** 100).bit_length(), int('ff', 16), int('0b11', 0), bin(10), oct(10), hex(255), chr(97), ord('a'))
print(1 == 1.0, 1 is 1, 'a' < 'b', [1, 2] < [1, 3], (1, 2) < (1, 2, 0), True + True, 3 > 2 > 1, not 0, 1 and 2, 0 or 'x', None is None, isinstance(True, int))
print(sorted([3, 1, 2], reverse=True), sorted('bca'), sorted([(2, 'a'), (1, 'b')]), sorted(['b', 'A', 'c'], key=str.lower), min(3, 1, 2), max('abc'), sum([1, 2, 3], 10), sum(x * x for x in range(4)), any([0, 1]), all([]), list(zip('ab', [1, 2], 'xy')), list(enumerate('ab', 1)), list(map(lambda a, b: a + b, [1, 2], [3, 4])), list(filter(None, [0, 1, '', 'a'])), list(reversed([1, 2, 3])))
print('abc'.upper(), 'ABC'.lower(), 'a b c'.split(), 'a,b,,c'.split(','), 'a  b'.split(' '), ' x '.strip(), 'xxhixx'.strip('x'), 'abc'.replace('b', 'B'), 'a-b-c'.rsplit('-', 1), 'abc'.startswith(('x', 'a')), 'abc'.find('c'), 'abcabc'.count('bc'), 'abc'.center(7, '*'), 'abc'.zfill(6), '-'.join(['a', 'b']), 'Hello World'.swapcase(), 'hello world'.title(), 'abc'.isalpha(), '123'.isdigit(), 'a\tb'.expandtabs(4), 'abc'[::-1], 'abc'[1:], 'line1\nline2'.splitlines(), 'x'.ljust(3, '.') + '|', 'ß'.upper(), 'İ'.lower() == 'i̇', 'abc'.partition('b'), 'a b'.encode(), 'été'.encode('utf-8'), len('日本語'), '日本語'.encode('utf-8'), 'é' == 'é', 'abc'.index('c'), 'x'.isidentifier(), 'a1'.isalnum(), 'AbC'.casefold(), 'tEsT'.capitalize())
