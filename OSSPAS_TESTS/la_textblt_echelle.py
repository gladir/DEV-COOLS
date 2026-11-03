import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
src=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'la_textblt.py')).read().split('# --- sans effet')[0]
exec(src)
g=glyph(65)
# agrandissement x2 exact
p=P(); tb(p,65,100,50,0,scale=1,inc=0xFFFF,dir=0); s=run(p,'sc2')
ok=all(s.px(100+x,50+y)==g[y//2][x//2] for x in range(16) for y in range(32)) and s.count()==4*sum(map(sum,g))
check('TEXTBLT echelle x2 (DDAINC=FFFF) : chaque point -> bloc 2x2',ok,s.art(98,48,20,36))
# reduction 1/2
p=P(); tb(p,65,100,50,0,scale=1,xdda=0x8000,inc=0x8000,dir=1); s=run(p,'sc3')
rows=[y for y in range(0,40) if s.count(90,50+y,40,1)>0]
cols=[x for x in range(0,40) if s.count(100+x,40,1,40)>0]
check('TEXTBLT reduction (SCALDIR=1) : environ moitie de la taille',s.count()>0 and len(rows)<=9 and max(cols)<=4 ,(rows,cols))
print(s.art(98,48,12,12))
# agrandissement x1.5 : taille entre
p=P(); tb(p,65,100,50,0,scale=1,xdda=0x8000,inc=0x8000,dir=0); s=run(p,'sc4')
rows=[y for y in range(0,60) if s.count(90,50+y,40,1)>0]
check('TEXTBLT agrandissement x1.5 (14 lignes non vides -> 21)',len(rows)==21,len(rows))
# echelle + rotation 90
p=P(); tb(p,65,200,200,0,scale=1,inc=0xFFFF,dir=0,chup=900); s=run(p,'sc5')
ok=all(s.px(200+y,200-x)==g[y//2][x//2] for x in range(16) for y in range(32))
check('TEXTBLT echelle x2 + rotation 90',ok)
# echelle + gras
p=P(); tb(p,65,100,50,1,scale=1,inc=0xFFFF,dir=0); s=run(p,'sc6')
cur,ofs=eff(g,1,1); ok=all(s.px(100+2*i+a,50+2*j+b)==cur[j][i+ofs] for j in range(16) for i in range(0,10) for a in (0,1) for b in (0,1))
check('TEXTBLT echelle x2 + gras',ok)
print('FAILS',FAIL)
