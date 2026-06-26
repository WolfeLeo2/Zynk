library phosphor_flutter;

import 'package:flutter/widgets.dart';

class PhosphorIconData {
  final IconData iconData;

  const PhosphorIconData(this.iconData);
}

class PhosphorFlatIconData extends PhosphorIconData {
  const PhosphorFlatIconData(IconData iconData) : super(iconData);
}

class PhosphorDuotoneIconData extends PhosphorIconData {
  final PhosphorIconData secondary;

  const PhosphorDuotoneIconData(IconData iconData, this.secondary)
      : super(iconData);
}
