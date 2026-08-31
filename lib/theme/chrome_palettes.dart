import 'package:flutter/material.dart';

import 'style_family.dart';

/// Four colour themes shown in the top-bar paint menu.
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
];

ChromePalette chromePaletteFor(VisualStyleFamily family) {
  return kChromePalettes.firstWhere(
    (p) => p.family == family,
    orElse: () => kChromePalettes.first,
  );
}
