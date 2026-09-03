import 'package:flutter/material.dart';

import 'style_family.dart';

/// Colour themes shown in the top-bar paint menu.
class ChromePalette {
  const ChromePalette({
    required this.family,
    required this.label,
    required this.blurb,
    required this.swatch,
  });

  final VisualStyleFamily family;
  final String label;
  final String blurb;
  final List<Color> swatch;
}

const kChromePalettes = <ChromePalette>[
  ChromePalette(
    family: VisualStyleFamily.quietFocus,
    label: 'Ink',
    blurb: 'Navy ink on cool paper',
    swatch: [Color(0xFF0B1220), Color(0xFF1E3A5F), Color(0xFFD7DEEA)],
  ),
  ChromePalette(
    family: VisualStyleFamily.signature,
    label: 'Paper',
    blurb: 'Warm cream and sepia',
    swatch: [Color(0xFFF7F1E3), Color(0xFFE8D9B8), Color(0xFF5C4633)],
  ),
  ChromePalette(
    family: VisualStyleFamily.aurora,
    label: 'Glass',
    blurb: 'Icy grey, translucent frost',
    swatch: [Color(0xFFE8EEF2), Color(0xFF9AADC0), Color(0xFF2A3340)],
  ),
  ChromePalette(
    family: VisualStyleFamily.naturalistic,
    label: 'Natural',
    blurb: 'Moss, terracotta, vine motif',
    swatch: [Color(0xFF2F4A38), Color(0xFFC4785A), Color(0xFFD8C4A8)],
  ),
  ChromePalette(
    family: VisualStyleFamily.softCute,
    label: 'Bloom',
    blurb: 'Lilac, blush, and petal cream',
    swatch: [Color(0xFFF7EEF4), Color(0xFFC9A0DC), Color(0xFF9B6BB0)],
  ),
  ChromePalette(
    family: VisualStyleFamily.neoBrutal,
    label: 'Bold',
    blurb: 'Hard ink edges, cream blocks',
    swatch: [Color(0xFF0A0A0A), Color(0xFFE8DCC8), Color(0xFFC4785A)],
  ),
  ChromePalette(
    family: VisualStyleFamily.dusk,
    label: 'Dusk',
    blurb: 'Twilight plum and amber',
    swatch: [Color(0xFF1A1428), Color(0xFF6B4E8A), Color(0xFFE0A86C)],
  ),
  ChromePalette(
    family: VisualStyleFamily.harbor,
    label: 'Harbor',
    blurb: 'Deep teal, sea glass, sand',
    swatch: [Color(0xFF12343C), Color(0xFF3E8A8A), Color(0xFFE4D4B8)],
  ),
];

ChromePalette chromePaletteFor(VisualStyleFamily family) {
  return kChromePalettes.firstWhere(
    (p) => p.family == family,
    orElse: () => kChromePalettes.first,
  );
}
