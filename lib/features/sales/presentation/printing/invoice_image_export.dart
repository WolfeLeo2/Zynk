import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceImageExport {
  static Future<String> saveFirstPageAsPng({
    required pw.Document document,
    required String fileName,
    bool share = true,
  }) async {
    final pdfBytes = await document.save();
    final pages = Printing.raster(pdfBytes, pages: const [0], dpi: 180);
    final page = await pages.first;
    final pngBytes = await page.toPng();

    final directory = await getApplicationDocumentsDirectory();
    final safeFileName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .toLowerCase();
    final file = File('${directory.path}/$safeFileName.png');
    await file.writeAsBytes(pngBytes, flush: true);

    if (share) {
      await Share.shareXFiles([XFile(file.path)], text: 'Invoice');
    }

    return file.path;
  }
}
