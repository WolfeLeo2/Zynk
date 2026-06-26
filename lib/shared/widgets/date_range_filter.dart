import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DateRangeFilter extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange?> onChanged;

  const DateRangeFilter({
    super.key,
    required this.selectedRange,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateFormat = DateFormat('dd MMM yy');

    String displayLabel;
    if (selectedRange == null) {
      displayLabel = 'All Time';
    } else {
      // If it's the same day
      if (selectedRange!.start.year == selectedRange!.end.year &&
          selectedRange!.start.month == selectedRange!.end.month &&
          selectedRange!.start.day == selectedRange!.end.day) {
        displayLabel = dateFormat.format(selectedRange!.start);
      } else {
        displayLabel =
            '${dateFormat.format(selectedRange!.start)} - ${dateFormat.format(selectedRange!.end)}';
      }
    }

    return InputChip(
      showCheckmark: false,
      avatar: PhosphorIcon(
        PhosphorIconsRegular.calendarBlank,
        size: 16,
        color: selectedRange == null
            ? colorScheme.onSurface
            : colorScheme.primary,
      ),
      label: Text(displayLabel),
      labelStyle: TextStyle(
        fontWeight: selectedRange == null ? FontWeight.normal : FontWeight.w600,
        color: selectedRange == null
            ? colorScheme.onSurface
            : colorScheme.primary,
      ),
      backgroundColor: selectedRange == null
          ? colorScheme.surface
          : colorScheme.primaryContainer.withValues(alpha: 0.3),

      onPressed: () async {
        final now = DateTime.now();
        final firstDate = DateTime(now.year - 5);
        final lastDate = DateTime(now.year + 1);

        final picked = await showDateRangePicker(
          context: context,
          firstDate: firstDate,
          lastDate: lastDate,
          initialDateRange:
              selectedRange ??
              DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: colorScheme.primary,
                  onPrimary: colorScheme.onPrimary,
                  surface: colorScheme.surface,
                  onSurface: colorScheme.onSurface,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          // Adjust end date to cover the entire day (23:59:59)
          final endOfLastDay = DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          );
          onChanged(DateTimeRange(start: picked.start, end: endOfLastDay));
        }
      },
      deleteIcon: selectedRange != null
          ? PhosphorIcon(PhosphorIconsRegular.x, size: 14)
          : null,
      onDeleted: selectedRange != null ? () => onChanged(null) : null,
    );
  }
}
