import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/schema_models.dart';

/// Generates an 80mm thermal receipt PDF.
///
/// Inspired by standard POS receipt layouts:
/// - Centered business header
/// - Dashed dividers
/// - Item list with qty × price
/// - Totals block
/// - Footer with thank you message
class ReceiptTemplate {
  static const double paperWidth = 80 * PdfPageFormat.mm;
  static const double margin = 6 * PdfPageFormat.mm;

  static pw.Document generate({
    required Sale sale,
    required List<SaleItem> items,
    required Tenant tenant,
    Branch? branch,
    String? customerName,
    String? salespersonName,
    pw.MemoryImage? logoImage,
  }) {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat(
            paperWidth,
            double.infinity,
            marginAll: margin,
          ),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // ── Business Header ──
              if (logoImage != null) ...[
                pw.Image(logoImage, height: 40, fit: pw.BoxFit.contain),
                pw.SizedBox(height: 4),
              ],
              pw.Text(
                tenant.name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if ((branch?.address ?? tenant.address) != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  (branch?.address ?? tenant.address)!,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if ((branch?.phone ?? tenant.phone) != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  'Tel: ${(branch?.phone ?? tenant.phone)!}',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              pw.SizedBox(height: 4),
              _dashedDivider(),

              // ── Receipt Info ──
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    sale.invoiceNumber ?? '---',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format((sale.createdAt ?? DateTime.now()).toLocal()),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              if (sale.salespersonId != null) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text(
                      'Served by: ${salespersonName ?? sale.salespersonId}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ],
              if (customerName != null && customerName.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text(
                      'Customer: $customerName',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 4),
              _dashedDivider(),

              // ── Column Headers ──
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'ITEM',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 25,
                    child: pw.Text(
                      'QTY',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      'PRICE',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.SizedBox(
                    width: 45,
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              _thinDivider(),

              // ── Items ──
              pw.SizedBox(height: 2),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          item.productName ?? 'Item',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.SizedBox(
                        width: 25,
                        child: pw.Text(
                          '${item.quantity}',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(
                        width: 40,
                        child: pw.Text(
                          currencyFormat.format(item.unitPrice),
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(
                        width: 45,
                        child: pw.Text(
                          currencyFormat.format(item.total),
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              _dashedDivider(),

              // ── Totals ──
              pw.SizedBox(height: 4),
              _totalRow('Subtotal', currencyFormat.format(sale.subtotal)),
              if (sale.discountAmount > 0)
                _totalRow(
                  'Discount',
                  '-${currencyFormat.format(sale.discountAmount)}',
                ),
              pw.SizedBox(height: 3),
              _totalRow(
                'TOTAL',
                'Ksh ${currencyFormat.format(sale.grandTotal)}',
                bold: true,
                fontSize: 11,
              ),
              pw.SizedBox(height: 2),
              _totalRow(
                'Paid (${sale.paymentMethod?.toUpperCase() ?? "CASH"})',
                'Ksh ${currencyFormat.format(sale.amountPaid)}',
              ),
              if (sale.amountPaid > sale.grandTotal)
                _totalRow(
                  'Change',
                  'Ksh ${currencyFormat.format(sale.amountPaid - sale.grandTotal)}',
                ),
              if (sale.amountPaid < sale.grandTotal)
                _totalRow(
                  'Balance',
                  'Ksh ${currencyFormat.format(sale.grandTotal - sale.amountPaid)}',
                ),

              pw.SizedBox(height: 6),
              _dashedDivider(),

              // ── Footer ──
              pw.SizedBox(height: 6),
              pw.Text(
                'Thank you for your purchase!',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Goods once sold are not returnable',
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: sale.invoiceNumber ?? sale.id,
                width: paperWidth - (margin * 2),
                height: 30,
                drawText: false,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                sale.invoiceNumber ?? '',
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _dashedDivider() {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed),
        ),
      ),
    );
  }

  static pw.Widget _thinDivider() {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.3)),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
