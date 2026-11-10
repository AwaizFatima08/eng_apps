from iapws import IAPWS97
import CoolProp.CoolProp as CP
def cp_if97(out, a, av, b, bv): return CP.PropsSI(out, a, av, b, bv, 'IF97::Water')
print('--- saturation at 1.0 MPa, x=0.9')
L = IAPWS97(P=1.0, x=0); V = IAPWS97(P=1.0, x=1)
print('iapws Tsat K', L.T, 'hf', L.h, 'hg', V.h, 'sf', L.s, 'sg', V.s, 'vf', L.v, 'vg', V.v)
M = IAPWS97(P=1.0, x=0.9); print('iapws mix h s v', M.h, M.s, M.v)
print('CoolProp IF97 Tsat', cp_if97('T','P',1e6,'Q',0), 'hf', cp_if97('H','P',1e6,'Q',0)/1e3, 'hg', cp_if97('H','P',1e6,'Q',1)/1e3,
      'h x0.9', cp_if97('H','P',1e6,'Q',0.9)/1e3, 's x0.9', cp_if97('S','P',1e6,'Q',0.9)/1e3)
print('--- saturation at 150 C (satT)')
L = IAPWS97(T=423.15, x=0); V = IAPWS97(T=423.15, x=1)
print('iapws Psat MPa', L.P, 'hf', L.h, 'hg', V.h, 'hfg', V.h-L.h, 'vg', V.v)
print('CoolProp Psat', cp_if97('P','T',423.15,'Q',0), 'hfg', (cp_if97('H','T',423.15,'Q',1)-cp_if97('H','T',423.15,'Q',0))/1e3)
for (p, t) in [(4.0, 400), (10.5, 510), (0.5, 120)]:
    s = IAPWS97(P=p, T=t+273.15)
    print(f'--- P {p} MPa T {t} C region {s.region}: h {s.h} s {s.s} v {s.v} cp {s.cp} Tsat', IAPWS97(P=p, x=0).T - 273.15)
    print('   CoolProp IF97 h', cp_if97('H','P',p*1e6,'T',t+273.15)/1e3, 's', cp_if97('S','P',p*1e6,'T',t+273.15)/1e3,
          'v', 1/cp_if97('D','P',p*1e6,'T',t+273.15), 'cp', cp_if97('C','P',p*1e6,'T',t+273.15)/1e3)
