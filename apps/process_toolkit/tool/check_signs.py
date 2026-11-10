import re, sys
from decimal import Decimal
import iapws._iapws97Constants as C
txt = open(sys.argv[1]).read()
signs = {}
for m in re.finditer(r'(–\s*)?0\.(\d{3}) (\d{3}) (\d{3}) (\d{3}) (\d{2})', txt):
    signs.setdefault(''.join(m.groups()[1:]), set()).add(-1 if m.group(1) else 1)
def mant(x):
    s = '%.13e' % Decimal(repr(float(x))).copy_abs(); return s.split('e')[0].replace('.', '')[:14]
bad = 0
for name in ['Region1_n', 'Region2_n', 'Region2_cp0_no']:
    for x in getattr(C, name):
        sg = 1 if x > 0 else -1
        if sg not in signs[mant(x)]:
            bad += 1; print('sign mismatch', name, x)
print('sign mismatches:', bad)
# Table 11 exponents
I = [1,1,1,1,1,2,2,2,2,2,3,3,3,3,3,4,4,4,5,6,6,6,7,7,7,8,8,9,10,10,10,16,16,18,20,20,20,21,22,23,24,24,24]
J = [0,1,2,3,6,1,2,4,7,36,0,1,3,6,35,1,2,3,7,3,16,35,0,11,25,8,36,13,4,10,14,29,50,57,20,35,48,21,53,39,26,40,58]
print('Table 11 I/J match:', list(C.Region2_Li) == I and list(C.Region2_Lj) == J)
