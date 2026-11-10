from math import sqrt
from fluids.safety_valve import API520_A_g, API520_A_l, API520_Kv, API520_C, API520_F2, API526_A, API526_letters, API520_round_size
print('API526 in2', [round(a/0.00064516,4) for a in API526_A])
# Ex1 critical
A1=API520_A_g(m=24270/3600., T=348., Z=0.90, MW=51., k=1.11, P1=670E3, Kb=1, Kc=1)
print('Ex1 A mm2', A1*1e6, API526_letters[API526_A.index(API520_round_size(A1))], 'C', API520_C(1.11))
A2=API520_A_g(m=24270/3600., T=348., Z=0.90, MW=51., k=1.11, P1=670E3, P2=532E3, Kd=0.975, Kb=1, Kc=1)
print('Ex2 A mm2', A2*1e6, API526_letters[API526_A.index(API520_round_size(A2))], 'F2', API520_F2(1.11,670,532))
# bellows ammonia: 5000 kg/h, T 40C, Z 0.95, M 17.03, k 1.31, set 16 barg 10%, Kb 0.9 Kc 0.9, backpressure 4 barg -> P2/P1 subcrit? 
P1=16e5*1.1+101325; P2=4e5+101325
A3=API520_A_g(m=5000/3600, T=313.15, Z=0.95, MW=17.03, k=1.31, P1=P1, P2=101325, Kd=0.975, Kb=0.9, Kc=0.9)
print('bellows NH3 A mm2', A3*1e6, 'P2/P1', P2/P1, API526_letters[API526_A.index(API520_round_size(A3))])
# Ex5 liquid with Kw 0.97, Kv per API procedure on next orifice
Q=6814/60000; G=0.9; rho=G*999.0107539518483; m=rho*Q
Pd=1724e3; P1=1.1*Pd+101325; P2=0.2*Pd+101325
A0=API520_A_l(m=m, rho=rho, P1=P1, P2=P2, overpressure=0.1, Kd=0.65, Kw=0.97, Kc=1.0, Kv=1.0)
Aorif=API520_round_size(A0); print('Ex5 A0 mm2', A0*1e6, 'next', API526_letters[API526_A.index(Aorif)], Aorif*1e6)
Re=6814*18800*G/(388*sqrt(Aorif*1e6)); Kv=API520_Kv(Re,'10E'); print('Re',Re,'Kv',Kv,'A',A0*1e6/Kv)
# fluids own convention (Re on preliminary area, mu given)
Af=API520_A_l(m=m, rho=rho, P1=P1, P2=P2, overpressure=0.1, Kd=0.65, Kw=0.97, Kc=1.0, Kv=None, mu=0.388)
print('fluids-convention A', Af*1e6)
# water conventional: 1000 L/min, G 1, set 10 barg, 10 %, pb 0
Q=1000/60000; rho=999.0107539518483; P1=11e5+101325; P2=101325
Aw=API520_A_l(m=rho*Q, rho=rho, P1=P1, P2=P2, overpressure=0.1, Kd=0.65, Kw=1, Kc=1, Kv=1)
print('water A', Aw*1e6, API526_letters[API526_A.index(API520_round_size(Aw))])
