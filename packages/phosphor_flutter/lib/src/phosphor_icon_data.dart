library phosphor_flutter;

import 'package:flutter/widgets.dart';

class PhosphorIconData {
  final int codePoint;
  final String style;

  const PhosphorIconData(this.codePoint, this.style);

  IconData get iconData => const IconData(
        codePoint,
        fontFamily: 'Phosphor$style',
        fontPackage: 'phosphor_flutter',
        matchTextDirection: true,
      );
}

class PhosphorFlatIconData extends PhosphorIconData {
  const PhosphorFlatIconData(int codePoint, String style)
      : super(codePoint, style);
}

class PhosphorDuotoneIconData extends PhosphorIconData {
  final PhosphorIconData secondary;

  const PhosphorDuotoneIconData(int codePoint, this.secondary)
      : super(codePoint, 'Duotone');
}
