import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/schema_models.dart';

/// Generates a professional A4 invoice PDF.
///
/// Inspired by modern invoice templates:
/// - Clean header with business info
/// - "INVOICE" heading with number and dates
/// - Bill-to section
/// - Detailed item table with alternating row shading
/// - Totals summary
/// - Payment info and terms
class InvoiceTemplate {
  // Brand color for the header accent
  static const PdfColor accentColor = PdfColor.fromInt(0xFF6C63FF);
  static const PdfColor headerBg = PdfColor.fromInt(0xFF1A1A2E);
  static const PdfColor lightGrey = PdfColor.fromInt(0xFFF8F8FA);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);

  static pw.Document generate({
    required Sale sale,
    required List<SaleItem> items,
    required List<Payment> payments,
    required Tenant tenant,
    Branch? branch,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? salespersonName,
    pw.MemoryImage? logoImage,
  }) {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        header: (context) =>
            _buildHeader(tenant, branch, sale, dateFormat, logoImage),
        footer: (context) => _buildFooter(context, tenant),
        build: (context) => [
          pw.SizedBox(height: 20),

          // ── Bill To / Ship To ──
          _buildBillTo(
            customerName: customerName,
            customerAddress: customerAddress,
            customerPhone: customerPhone,
            salespersonName: salespersonName,
            sale: sale,
            dateFormat: dateFormat,
          ),

          pw.SizedBox(height: 24),

          // ── Items Table ──
          _buildItemsTable(items, currencyFormat),

          pw.SizedBox(height: 16),

          // ── Totals ──
          _buildTotals(sale, currencyFormat),

          pw.SizedBox(height: 24),

          // ── Payments Section ──
          if (payments.isNotEmpty) ...[
            _buildPaymentsSection(payments, currencyFormat, dateFormat),
            pw.SizedBox(height: 24),
          ],

          // ── Notes ──
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Notes',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    sale.notes!,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(
    Tenant tenant,
    Branch? branch,
    Sale sale,
    DateFormat dateFormat,
    pw.MemoryImage? logoImage,
  ) {
    // Prefer branch contact info, fall back to tenant
    final displayAddress = branch?.address ?? tenant.address;
    final displayPhone = branch?.phone ?? tenant.phone;
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: headerBg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Business Info
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) ...[
                pw.Image(logoImage, height: 40, fit: pw.BoxFit.contain),
                pw.SizedBox(height: 8),
              ],
              pw.Text(
                tenant.name.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              if (displayAddress != null)
                pw.Text(
                  displayAddress,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey400,
                  ),
                ),
              if (displayPhone != null)
                pw.Text(
                  'Tel: $displayPhone',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey400,
                  ),
                ),
            ],
          ),

          // Invoice details
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: accentColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  sale.saleType == 'pos_sale' ? 'RECEIPT' : 'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                sale.invoiceNumber ?? '---',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date: ${dateFormat.format((sale.createdAt ?? DateTime.now()).toLocal())}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey400,
                ),
              ),
              if (sale.dueDate != null)
                pw.Text(
                  'Due: ${dateFormat.format(sale.dueDate!)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBillTo({
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? salespersonName,
    required Sale sale,
    required DateFormat dateFormat,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                customerName ?? 'Walk-in Customer',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (customerAddress != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  customerAddress,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
              if (customerPhone != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  customerPhone,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (sale.salespersonId != null)
                _infoRow(
                  'Salesperson',
                  (salespersonName ?? sale.salespersonId!).trim(),
                ),
              _infoRow(
                'Payment',
                sale.paymentMethod?.toUpperCase() ?? 'PENDING',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            '$label: ',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    List<SaleItem> items,
    NumberFormat currencyFormat,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: headerBg),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 28,
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(85),
      },
      oddRowDecoration: const pw.BoxDecoration(color: lightGrey),
      headers: ['#', 'Item', 'Qty', 'Unit Price', 'Total'],
      data: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return [
          '${i + 1}',
          item.productName ?? 'Item',
          '${item.quantity}',
          'Ksh ${currencyFormat.format(item.unitPrice)}',
          'Ksh ${currencyFormat.format(item.total)}',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildTotals(Sale sale, NumberFormat currencyFormat) {
    return pw.Row(
      children: [
        pw.Spacer(flex: 3),
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                _summaryRow(
                  'Subtotal',
                  'Ksh ${currencyFormat.format(sale.subtotal)}',
                ),
                if (sale.discountAmount > 0)
                  _summaryRow(
                    'Discount',
                    '-Ksh ${currencyFormat.format(sale.discountAmount)}',
                  ),
                pw.Divider(color: borderColor, height: 8),
                _summaryRow(
                  'Grand Total',
                  'Ksh ${currencyFormat.format(sale.grandTotal)}',
                  bold: true,
                  fontSize: 12,
                ),
                pw.SizedBox(height: 4),
                _summaryRow(
                  'Amount Paid',
                  'Ksh ${currencyFormat.format(sale.amountPaid)}',
                  valueColor: PdfColors.green800,
                ),
                if (sale.remainingBalance > 0)
                  _summaryRow(
                    'Balance Due',
                    'Ksh ${currencyFormat.format(sale.remainingBalance)}',
                    bold: true,
                    valueColor: PdfColors.red800,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 9,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPaymentsSection(
    List<Payment> payments,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PAYMENT HISTORY',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          headerDecoration: const pw.BoxDecoration(color: lightGrey),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellHeight: 24,
          headers: ['Date', 'Method', 'Reference', 'Amount'],
          data: payments.map((p) {
            return [
              dateFormat.format((p.createdAt ?? DateTime.now()).toLocal()),
              p.paymentMethod,
              p.referenceNumber ?? '—',
              'Ksh ${currencyFormat.format(p.amount)}',
            ];
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, Tenant tenant) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }
}
