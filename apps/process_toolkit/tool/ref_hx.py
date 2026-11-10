from ht import LMTD, F_LMTD_Fakheri
for (thi,tho,tci,tco) in [(150,90,30,70),(150,100,50,100),(300,200,40,140),(120,60,20,60),(150,90,30,80)]:
    print((thi,tho,tci,tco),'LMTDcc',repr(LMTD(thi,tho,tci,tco,counterflow=True)),'LMTDco',repr(LMTD(thi,tho,tci,tco,counterflow=False)),
          'F12',repr(F_LMTD_Fakheri(Thi=thi,Tho=tho,Tci=tci,Tco=tco,shells=1)))
# condensing steam 150 C, water 30 -> 90
print('cond', repr(LMTD(150,150,30,90)))
