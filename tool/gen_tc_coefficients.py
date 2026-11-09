import thermocouples_reference.source_NIST as n
out=['// GENERATED from NIST ITS-90 Thermocouple Database (NIST SRD 60, public domain)',
'// by tool/gen_tc_coefficients.py — do not edit by hand.',
'// E(t) in mV, t in °C (ITS-90), reference junction at 0 °C.','',
"import 'nist_tc_model.dart';",'',
'const Map<String, TcReference> nistThermocouples = {']
for k in sorted(n.thermocouples):
    ref=n.thermocouples[k]; f=ref.func
    out.append(f"  '{k}': TcReference('{k}', '{ref.composition}', [")
    for lo,hi,coefs,ec in f.table:
        asc=list(coefs)[::-1]
        cs=', '.join(repr(float(c)) for c in asc)
        e = 'null' if ec is None else '('+', '.join(repr(float(x)) for x in ec)+')'
        out.append(f"    TcRange({float(lo)}, {float(hi)}, [{cs}], {e}),")
    out.append('  ]),')
out.append('};')
open('/mnt/storage/projects/engineering_apps/apps/instrument_toolkit/lib/tools/nist_tc_data.dart','w').write('\n'.join(out)+'\n')
