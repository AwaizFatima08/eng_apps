g=9.80665
# Pumps & Systems examples (2.31 ft/psi convention as printed)
print('PS ex2 lift', 33.957-0.7828-10-3.2, ' ex1 flooded', 33.957-0.7828+10-3.2)
# hand calcs
dp=5e5; rho=998.2; Q=100/3600
H=dp/(rho*g); Ph=Q*dp; print('H',H,'Ph',Ph,'shaft',Ph/0.75,'motor',Ph/0.75/0.95)
dp2=850*g*100; Q2=50/3600; print('dp2',dp2,'Ph2',Q2*dp2,'shaft2',Q2*dp2/0.7)
# boiling vessel: ps = pv -> NPSHa = z - hf
print('npsha boiling', 3-0.5, 'margin', 2.5-3, 'ratio', 2.5/3)
