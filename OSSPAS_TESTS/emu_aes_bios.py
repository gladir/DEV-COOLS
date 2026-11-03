# Programmes assembleur (assembles par DEVPAC.PAS) qui appellent l'AES, le BIOS et le XBIOS de l'emulateur
# et ecrivent leurs resultats dans un fichier ; les valeurs attendues sont verifiees sur OSSPAS.PAS ou DEVPAC.PAS
# (OSSPAS_EMU=osspas|devpac).
import sys, os, struct; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
here=os.path.dirname(os.path.abspath(__file__))
def run_asm(src,name,resfile,gem=False):
    pp=asm(open(os.path.join(here,src)).read(),name)
    rp=os.path.join(WORK,resfile)
    if os.path.exists(rp): os.remove(rp)
    runprg(pp,name,gem=gem)
    return open(rp,'rb').read()
if not os.environ.get('OSSPAS_SKIP_AES'):
    # ---- AES : appl_getinfo, objc_sysvar, appl_search, scrp_*, shel_wdef/rdef, wind_new, appl_bvset -------------
    b=run_asm('emu_aes.s','AESTEST','AESRES.BIN',gem=True)
    rows=[struct.unpack('>8h',b[i:i+16]) for i in range(0,len(b),16)]
    rows=[r for r in rows[1:] ]       # la ligne 0 depend du numero d'application
    check('appl_getinfo(0) : police 10 points',rows[0][:3]==(1,10,1))
    check('objc_sysvar : ecriture puis lecture',rows[1][:3]==(1,7,9) and rows[2][:3]==(1,7,9))
    check('appl_search : application puis fin de liste',rows[3][:3]==(1,2,0) and rows[4][0]==0)
    check('scrp_write / scrp_read',rows[7][:3]==(1,67,83))
    check('shel_wdef / shel_rdef',rows[10][:3]==(1,68,67))


# ---- BIOS / XBIOS --------------------------------------------------------------------------------------------
b=run_asm('emu_bios.s','BXTEST','BXRES.BIN')
v=struct.unpack('>8L',b[:32])
check('Drvmap : lecteurs A: et C:',v[0]==5)
check('Setexc : ecriture puis lecture du vecteur',v[1]==0x1234)
check('Setcolor : ecriture puis lecture',v[2]==0x123)
check('Gettime : annee plausible',2024<=v[3]<=2100,v[3])
check('Iorec(1) : taille de tampon',v[4]==256)
check('Kbdvbase : pointeur non nul',v[5]==0xFFFFFFFF)
check('Giaccess : ecriture puis lecture d\'un registre',v[6]==0x55)
check('Kbrate',v[7]==0x0F0F)
print('FAILS',FAIL)
