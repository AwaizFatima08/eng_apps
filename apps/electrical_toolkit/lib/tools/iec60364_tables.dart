// Transcribed from two independent copies (Top Cable's scan of the standard;
// TiSoft's typed tables), diffed value by value — see
// docs/electrical-toolkit-scope.md. Edit only after re-checking both.
// IEC 60364-5-52:2009 Annex B tabulated current-carrying capacities, in A,
// multi-core cables, ambient 30 °C in air / 20 °C in ground, soil 2.5 K·m/W.
// Resolved source disagreements (FFL validator to confirm):
//  • B.52.4 PVC Cu 3 loaded D1 120 mm²: scan shows 292 (misprint), 192 used.
//  • B.52.10 PVC Cu 3 loaded E 70/120 mm²: 196/276 (scan, Schneider C.52.1)
//    used; TiSoft has 198/278.

/// Nominal sizes, mm².
const List<double> cableSizes = [
  1.5,
  2.5,
  4,
  6,
  10,
  16,
  25,
  35,
  50,
  70,
  95,
  120,
  150,
  185,
  240,
  300,
];

/// key: 'insulation/conductor/loaded/method', e.g. 'XLPE/Cu/3/E' → A per size
/// (null where the table has no value, e.g. Al below 16 mm²).
const Map<String, List<double?>> iecAmpacity = {
  // B.52.2
  'PVC/Cu/2/C': [
    19.5,
    27,
    36,
    46,
    63,
    85,
    112,
    138,
    168,
    213,
    258,
    299,
    344,
    392,
    461,
    530,
  ],
  // B.52.10
  'PVC/Cu/2/E': [
    22,
    30,
    40,
    51,
    70,
    94,
    119,
    148,
    180,
    232,
    282,
    328,
    379,
    434,
    514,
    593,
  ],
  // B.52.2
  'PVC/Cu/2/D1': [
    22,
    29,
    37,
    46,
    60,
    78,
    99,
    119,
    140,
    173,
    204,
    231,
    261,
    292,
    336,
    379,
  ],
  // B.52.2
  'PVC/Cu/2/D2': [
    22,
    28,
    38,
    48,
    64,
    83,
    110,
    132,
    156,
    192,
    230,
    261,
    293,
    331,
    382,
    427,
  ],
  // B.52.4
  'PVC/Cu/3/C': [
    17.5,
    24,
    32,
    41,
    57,
    76,
    96,
    119,
    144,
    184,
    223,
    259,
    299,
    341,
    403,
    464,
  ],
  // B.52.10
  'PVC/Cu/3/E': [
    18.5,
    25,
    34,
    43,
    60,
    80,
    101,
    126,
    153,
    196,
    238,
    276,
    319,
    364,
    430,
    497,
  ],
  // B.52.4
  'PVC/Cu/3/D1': [
    18,
    24,
    30,
    38,
    50,
    64,
    82,
    98,
    116,
    143,
    169,
    192,
    217,
    243,
    280,
    316,
  ],
  // B.52.4
  'PVC/Cu/3/D2': [
    19,
    24,
    33,
    41,
    54,
    70,
    92,
    110,
    130,
    162,
    193,
    220,
    246,
    278,
    320,
    359,
  ],
  // B.52.2
  'PVC/Al/2/C': [
    null,
    null,
    null,
    null,
    null,
    66,
    83,
    103,
    125,
    160,
    195,
    226,
    261,
    298,
    352,
    406,
  ],
  // B.52.11
  'PVC/Al/2/E': [
    null,
    null,
    null,
    null,
    null,
    73,
    89,
    111,
    135,
    173,
    210,
    244,
    282,
    322,
    380,
    439,
  ],
  // B.52.2
  'PVC/Al/2/D1': [
    null,
    null,
    null,
    null,
    null,
    61,
    77,
    93,
    109,
    135,
    159,
    180,
    204,
    228,
    262,
    296,
  ],
  // B.52.2
  'PVC/Al/2/D2': [
    null,
    null,
    null,
    null,
    null,
    63,
    82,
    98,
    117,
    145,
    173,
    200,
    224,
    255,
    298,
    336,
  ],
  // B.52.4
  'PVC/Al/3/C': [
    null,
    null,
    null,
    null,
    null,
    59,
    73,
    90,
    110,
    140,
    170,
    197,
    227,
    259,
    305,
    351,
  ],
  // B.52.11
  'PVC/Al/3/E': [
    null,
    null,
    null,
    null,
    null,
    61,
    78,
    96,
    117,
    150,
    183,
    212,
    245,
    280,
    330,
    381,
  ],
  // B.52.4
  'PVC/Al/3/D1': [
    null,
    null,
    null,
    null,
    null,
    50,
    64,
    77,
    91,
    112,
    132,
    150,
    169,
    190,
    218,
    247,
  ],
  // B.52.4
  'PVC/Al/3/D2': [
    null,
    null,
    null,
    null,
    null,
    53,
    69,
    83,
    99,
    122,
    148,
    169,
    189,
    214,
    250,
    282,
  ],
  // B.52.3
  'XLPE/Cu/2/C': [
    24,
    33,
    45,
    58,
    80,
    107,
    138,
    171,
    209,
    269,
    328,
    382,
    441,
    506,
    599,
    693,
  ],
  // B.52.12
  'XLPE/Cu/2/E': [
    26,
    36,
    49,
    63,
    86,
    115,
    149,
    185,
    225,
    289,
    352,
    410,
    473,
    542,
    641,
    741,
  ],
  // B.52.3
  'XLPE/Cu/2/D1': [
    25,
    33,
    43,
    53,
    71,
    91,
    116,
    139,
    164,
    203,
    239,
    271,
    306,
    343,
    395,
    446,
  ],
  // B.52.3
  'XLPE/Cu/2/D2': [
    27,
    35,
    46,
    58,
    77,
    100,
    129,
    155,
    183,
    225,
    270,
    306,
    343,
    387,
    448,
    502,
  ],
  // B.52.5
  'XLPE/Cu/3/C': [
    22,
    30,
    40,
    52,
    71,
    96,
    119,
    147,
    179,
    229,
    278,
    322,
    371,
    424,
    500,
    576,
  ],
  // B.52.12
  'XLPE/Cu/3/E': [
    23,
    32,
    42,
    54,
    75,
    100,
    127,
    158,
    192,
    246,
    298,
    346,
    399,
    456,
    538,
    621,
  ],
  // B.52.5
  'XLPE/Cu/3/D1': [
    21,
    28,
    36,
    44,
    58,
    75,
    96,
    115,
    135,
    167,
    197,
    223,
    251,
    281,
    324,
    365,
  ],
  // B.52.5
  'XLPE/Cu/3/D2': [
    23,
    30,
    39,
    49,
    65,
    84,
    107,
    129,
    153,
    188,
    226,
    257,
    287,
    324,
    375,
    419,
  ],
  // B.52.3
  'XLPE/Al/2/C': [
    null,
    null,
    null,
    null,
    null,
    84,
    101,
    126,
    154,
    198,
    241,
    280,
    324,
    371,
    439,
    508,
  ],
  // B.52.13
  'XLPE/Al/2/E': [
    null,
    null,
    null,
    null,
    null,
    91,
    108,
    135,
    164,
    211,
    257,
    300,
    346,
    397,
    470,
    543,
  ],
  // B.52.3
  'XLPE/Al/2/D1': [
    null,
    null,
    null,
    null,
    null,
    71,
    90,
    108,
    128,
    158,
    186,
    211,
    238,
    267,
    307,
    346,
  ],
  // B.52.3
  'XLPE/Al/2/D2': [
    null,
    null,
    null,
    null,
    null,
    76,
    98,
    117,
    139,
    170,
    204,
    233,
    261,
    296,
    343,
    386,
  ],
  // B.52.5
  'XLPE/Al/3/C': [
    null,
    null,
    null,
    null,
    null,
    76,
    90,
    112,
    136,
    174,
    211,
    245,
    283,
    323,
    382,
    440,
  ],
  // B.52.13
  'XLPE/Al/3/E': [
    null,
    null,
    null,
    null,
    null,
    77,
    97,
    120,
    146,
    187,
    227,
    263,
    304,
    347,
    409,
    471,
  ],
  // B.52.5
  'XLPE/Al/3/D1': [
    null,
    null,
    null,
    null,
    null,
    59,
    75,
    90,
    106,
    130,
    154,
    174,
    197,
    220,
    253,
    286,
  ],
  // B.52.5
  'XLPE/Al/3/D2': [
    null,
    null,
    null,
    null,
    null,
    64,
    82,
    98,
    117,
    144,
    172,
    197,
    220,
    250,
    290,
    326,
  ],
};

/// IEC 60228 Table 2 (class 2 stranded), maximum DC resistance at 20 °C,
/// Ω/km, per size in [cableSizes]. Plain copper; aluminium only from 16 mm²
/// (the app's scope — small Al power cables are not used at FFL).
const List<double> r20Cu = [
  12.1, 7.41, 4.61, 3.08, 1.83, 1.15, 0.727, 0.524, 0.387, 0.268, 0.193, //
  0.153, 0.124, 0.0991, 0.0754, 0.0601,
];
const List<double?> r20Al = [
  null, null, null, null, null, 1.91, 1.20, 0.868, 0.641, 0.443, 0.320, //
  0.253, 0.206, 0.164, 0.125, 0.100,
];

/// Temperature coefficient of resistance at 20 °C, 1/K (IEC 60228 Annex B,
/// IEC 60287-1-1 Table 1).
const double alphaCu = 0.00393;
const double alphaAl = 0.00403;

/// B.52.14 — ambient air temperature other than 30 °C (°C → factor).
const Map<String, List<(double, double)>> kAirTemp = {
  'PVC': [
    (10, 1.22), (15, 1.17), (20, 1.12), (25, 1.06), (30, 1.00), (35, 0.94), //
    (40, 0.87), (45, 0.79), (50, 0.71), (55, 0.61), (60, 0.50),
  ],
  'XLPE': [
    (10, 1.15), (15, 1.12), (20, 1.08), (25, 1.04), (30, 1.00), (35, 0.96), //
    (40, 0.91), (45, 0.87), (50, 0.82), (55, 0.76), (60, 0.71), (65, 0.65),
    (70, 0.58), (75, 0.50), (80, 0.41),
  ],
};

/// B.52.15 — ground temperature other than 20 °C.
const Map<String, List<(double, double)>> kGroundTemp = {
  'PVC': [
    (10, 1.10), (15, 1.05), (20, 1.00), (25, 0.95), (30, 0.89), (35, 0.84), //
    (40, 0.77), (45, 0.71), (50, 0.63), (55, 0.55), (60, 0.45),
  ],
  'XLPE': [
    (10, 1.07), (15, 1.04), (20, 1.00), (25, 0.96), (30, 0.93), (35, 0.89), //
    (40, 0.85), (45, 0.80), (50, 0.76), (55, 0.71), (60, 0.65), (65, 0.60),
    (70, 0.53), (75, 0.46), (80, 0.38),
  ],
};

/// B.52.16 — soil thermal resistivity other than 2.5 K·m/W.
const List<(double, double)> kSoilDuct = [
  (0.5, 1.28), (0.7, 1.20), (1.0, 1.18), (1.5, 1.10), (2.0, 1.05), //
  (2.5, 1.00), (3.0, 0.96),
];
const List<(double, double)> kSoilDirect = [
  (0.5, 1.88), (0.7, 1.62), (1.0, 1.50), (1.5, 1.28), (2.0, 1.12), //
  (2.5, 1.00), (3.0, 0.90),
];

/// B.52.17 item 2 — single layer on wall, floor or unperforated tray
/// (method C), touching; index = number of circuits/cables − 1. No further
/// reduction beyond nine.
const List<double> kGroupC = [
  1.00,
  0.85,
  0.79,
  0.75,
  0.73,
  0.72,
  0.72,
  0.71,
  0.70,
];

/// B.52.20 — multi-core cables touching on one horizontal perforated tray
/// (method E). The table has columns for 1, 2, 3, 4, 6 and 9 cables only.
const List<(int, double)> kGroupTray = [
  (1, 1.00),
  (2, 0.88),
  (3, 0.82),
  (4, 0.79),
  (6, 0.76),
  (9, 0.73),
];

/// B.52.19 — multi-core cables in single-way ducts in ground, ducts
/// touching ("nil"); index = number of cables − 2.
const List<double> kGroupDuct = [0.85, 0.75, 0.70, 0.65, 0.60];

/// B.52.18 — cables laid directly in ground, touching ("nil" clearance);
/// index = number of circuits − 2.
const List<double> kGroupBuried = [0.75, 0.65, 0.60, 0.55, 0.50];

/// Linear interpolation in a sorted (x, y) table; null outside its range.
double? interpTable(List<(double, double)> t, double x) {
  if (x < t.first.$1 - 1e-9 || x > t.last.$1 + 1e-9) return null;
  for (var i = 0; i < t.length - 1; i++) {
    final (x0, y0) = t[i];
    final (x1, y1) = t[i + 1];
    if (x <= x1 + 1e-9) return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
  }
  return t.last.$2;
}
