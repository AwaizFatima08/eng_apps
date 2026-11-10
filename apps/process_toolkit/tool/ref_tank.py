from math import pi
from fluids.geometry import TANK
def T(D,L,horiz,side,**kw):
    args=dict(D=D,L=L,horizontal=horiz,sideA=side,sideB=side)
    if side=='ellipsoidal': args.update(sideA_a=D/4,sideB_a=D/4)
    if side=='spherical': args.update(sideA_a=D/2,sideB_a=D/2)
    if side=='torispherical': args.update(sideA_f=kw['f'],sideA_k=kw['k'],sideB_f=kw['f'],sideB_k=kw['k'])
    if side=='flat': args.update(sideA=None,sideB=None)
    return TANK(**args)
cases=[('v-ellip',2,5,False,'ellipsoidal',{},[0.3,1,4,5.8]),
       ('v-tori',2,5,False,'torispherical',dict(f=1,k=0.06),[0.2,0.35,3,5.5]),
       ('v-hemi',2,4,False,'spherical',{},[0.5,3,5.5]),
       ('h-ellip',2,5,True,'ellipsoidal',{},[0.5,1,1.7]),
       ('h-tori',3,8,True,'torispherical',dict(f=1,k=0.06),[0.4,1.5,2.6]),
       ('h-korb',3,8,True,'torispherical',dict(f=0.8,k=0.154),[0.9,2.2]),
       ('h-flat',2.5,6,True,'flat',{},[0.7]),
       ('v-flat',3,10,False,'flat',{},[4])]
for name,D,L,h,side,kw,levels in cases:
    t=T(D,L,h,side,**kw)
    print(name,'V_total',repr(t.V_total),'h_max',repr(t.h_max),'sideA_a',repr(t.sideA_a))
    for lv in levels: print('   h',lv,'V',repr(t.V_from_h(lv)))
t=T(3,8,True,'torispherical',f=1,k=0.06); print('h-tori h_from_V(30)',repr(t.h_from_V(30)))
t=T(2,5,False,'ellipsoidal'); print('v-ellip h_from_V(10)',repr(t.h_from_V(10)))
