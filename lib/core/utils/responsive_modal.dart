import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileMaxWidth = 840;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }
}

Future<T?> showResponsiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool? showDragHandle,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  if (ResponsiveUtils.isMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      shape: shape,
      builder: builder,
    );
  } else {
    return showDialog<T>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
            child: builder(ctx),
          ),
        );
      },
    );
  }
}
