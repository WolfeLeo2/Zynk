import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/widgets/charts.dart');
  final lines = file.readAsLinesSync();

  // Keep lines 0..9 (indices), insert placeholder, keep lines from 527 to end
  final newLines = [
    ...lines.sublist(0, 10),
    '// REVENUE BAR CHART PLACEHOLDER',
    ...lines.sublist(527),
  ];

  file.writeAsStringSync(newLines.join('\n') + '\n');
  print('Done modifying charts.dart');
}
