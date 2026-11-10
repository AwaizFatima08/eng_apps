from math import pi
import fluids
from fluids.friction import Colebrook, friction_factor
from fluids.core import Reynolds, dP_from_K
g = 9.80665
def case(name, Q, D, L, eps, rho, mu, K=0, dz=0):
    A = pi/4*D*D; V = Q/A
    Re = Reynolds(V=V, D=D, rho=rho, mu=mu)
    f = friction_factor(Re=Re, eD=eps/D, Method='Colebrook')
    dpf = fluids.friction.dP_from_fd(fd=f, L=L, D=D, rho=rho, V=V) if hasattr(fluids.friction,'dP_from_fd') else f*L/D*rho*V*V/2
    dpk = dP_from_K(K=K, rho=rho, V=V)
    dpz = rho*g*dz
    print(f'{name}: V={V!r} Re={Re!r} f={f!r} dpf={dpf!r} dpk={dpk!r} dpz={dpz!r} total={dpf+dpk+dpz!r}')
    return Re, f
# 1 water 100 m3/h 6" sch40 CS
case('water6', 100/3600, 0.15405, 100, 0.045e-3, 998.2, 1.002e-3)
# 2 same with K=5 and +10 m
case('water6K', 100/3600, 0.15405, 100, 0.045e-3, 998.2, 1.002e-3, K=5, dz=10)
# 3 laminar oil: 5 m3/h, 2" (52.5mm), 50 m, 100 cP, 900 kg/m3
Q=5/3600; D=0.0525; mu=0.1; L=50
Re,f = case('oil2', Q, D, L, 0.045e-3, 900, mu)
print('  Hagen-Poiseuille dP =', 128*mu*L*Q/(pi*D**4))
# 4 galvanised 2" water 10 m3/h, 30 m
case('galv2', 10/3600, 0.0525, 30, 0.15e-3, 998.2, 1.002e-3)
# 5 gas: natural gas 5000 kg/h, 4" (102.26mm), 1000 m, rho 15.5, mu 0.011cP, p1 20 bar a
m=5000/3600; rho=15.5
case('gas4', m/rho, 0.10226, 1000, 0.045e-3, rho, 0.011e-3)
# 6 custom roughness 1 mm, 8" 202.72 mm, 300 m3/h water 500 m
case('rough8', 300/3600, 0.20272, 500, 1e-3, 998.2, 1.002e-3)
