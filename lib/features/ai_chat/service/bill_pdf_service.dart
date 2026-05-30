import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'branding_storage_service.dart';

enum BillTemplate { classic, modern, minimal }

// ─── Rupee symbol safe helper ─────────────────────────────────────────────────
// NotoSans does NOT contain ₹ (U+20B9). We replace it with "Rs." for PDF safety.
String _rs(dynamic v, [String fallback = '0.00']) {
  if (v == null) return 'Rs.$fallback';
  final s = v.toString().replaceAll('₹', '').trim();
  return 'Rs.${s.isEmpty ? fallback : s}';
}

// Read numeric value from "₹123.0" or 123.0
double _d(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) {
    return double.tryParse(
            v.replaceAll('₹', '').replaceAll('Rs.', '').replaceAll(',', '').trim()) ??
        fallback;
  }
  return fallback;
}

String _clean(dynamic v, [String fb = '-']) =>
    (v?.toString().trim().isNotEmpty == true) ? v.toString().trim() : fb;

// ─── Item key resolver (handles both 'Item' and 'item', 'Qty' and 'qty' etc) ─
String _itemVal(Map<String, dynamic> m, String key) {
  final lower = key.toLowerCase();
  // Try exact, then title-case, then lowercase
  return _clean(m[key] ?? m[key[0].toUpperCase() + key.substring(1)] ?? m[lower]);
}

// ─── Amount in words ──────────────────────────────────────────────────────────
String _amountInWords(double amount) {
  if (amount <= 0) return 'Zero Rupees Only';
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
    'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];
  String words(int n) {
    if (n == 0) return '';
    if (n < 20) return ones[n];
    if (n < 100) return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${ones[n % 10]}' : ''}';
    if (n < 1000) return '${ones[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${words(n % 100)}' : ''}';
    if (n < 100000) return '${words(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${words(n % 1000)}' : ''}';
    if (n < 10000000) return '${words(n ~/ 100000)} Lakh${n % 100000 != 0 ? ' ${words(n % 100000)}' : ''}';
    return '${words(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ${words(n % 10000000)}' : ''}';
  }
  final r = amount.floor();
  final p = ((amount - r) * 100).round();
  return '${words(r)} Rupees${p > 0 ? ' and ${words(p)} Paisa' : ''} Only';
}

// ─── Colors (HTML template exact match) ──────────────────────────────────────
const _lavender   = PdfColor.fromInt(0xFFE6E6FA);
const _darkText   = PdfColor.fromInt(0xFF1A1A2E);
const _greyText   = PdfColor.fromInt(0xFF555555);
const _borderCol  = PdfColor.fromInt(0xFFCCCCCC);
const _white      = PdfColors.white;
const _tableAlt   = PdfColor.fromInt(0xFFF8F8FF);
const _redBadge   = PdfColor.fromInt(0xFFDC2626);
const _greenBadge = PdfColor.fromInt(0xFF16A34A);

class BillPdfService {
  // ── Firestore company fetch (matches your Firestore structure) ─────────────
  static Future<Map<String, String>> _fetchCompanyInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return _defaultCompany();
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return _defaultCompany();
      final data = doc.data()!;
      return {
        'company_name': data['company_name'] as String? ?? 'ApnaCA',
        'first_name':   data['first_name']   as String? ?? '',
        'last_name':    data['last_name']    as String? ?? '',
        'email':        data['email']        as String? ?? '',
        'mobile':       data['mobile']       as String? ?? '',
        'address':      data['address']      as String? ?? '',
        'gst':          data['gst_number']   as String? ?? '',
        'username':     data['username']     as String? ?? '',
      };
    } catch (_) { return _defaultCompany(); }
  }

  static Map<String, String> _defaultCompany() => {
    'company_name': 'ApnaCA', 'first_name': '', 'last_name': '',
    'email': '', 'mobile': '', 'address': '', 'gst': '', 'username': '',
  };

  // ── Branding images fetch (logo + signature from Firebase Storage) ──────────
  /// Fetches logo and signature image bytes from Firebase Storage URLs.
  /// Returns map with 'logo' and 'signature' keys (Uint8List? values).
  /// Accepts optional pre-resolved URLs from BillCreationState to avoid
  /// double network calls.
  static Future<Map<String, Uint8List?>> _fetchBrandingImages({
    String? logoUrl,
    String? signatureUrl,
  }) async {
    // If URLs not provided, fetch from Storage
    if (logoUrl == null || signatureUrl == null) {
      final urls = await BrandingStorageService.checkBothUrls();
      logoUrl     ??= urls['logo'];
      signatureUrl ??= urls['signature'];
    }

    Future<Uint8List?> _download(String? url) async {
      if (url == null || url.isEmpty) return null;
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) return response.bodyBytes;
      } catch (_) {}
      return null;
    }

    final results = await Future.wait([
      _download(logoUrl),
      _download(signatureUrl),
    ]);
    return {'logo': results[0], 'signature': results[1]};
  }

  static Future<pw.Font?> _font(String asset) async {
    try {
      return pw.Font.ttf(await rootBundle.load(asset));
    } catch (_) { return null; }
  }

  // ── Main entry ─────────────────────────────────────────────────────────────
  static Future<void> generateAndShare({
    required Map<String, dynamic> billDetail,
    required List<Map<String, dynamic>> lineItems,
    BillTemplate template = BillTemplate.modern,
    String? companyLogoUrl,   // from BillCreationState (may be pre-resolved)
    String? signatureUrl,     // from BillCreationState (may be pre-resolved)
  }) async {
    final company  = await _fetchCompanyInfo();
    final regular  = await _font('assets/fonts/NotoSans-Regular.ttf');
    final bold     = await _font('assets/fonts/NotoSans-Bold.ttf');
    final isPurchase = billDetail['type'] == 'purchase_bill' ||
        (billDetail['Bill No']?.toString().startsWith('PB-') ?? false);

    // ── Fetch branding images (logo + signature) ─────────────────────────────
    final branding = await _fetchBrandingImages(
      logoUrl: companyLogoUrl,
      signatureUrl: signatureUrl,
    );
    final logoBytes = branding['logo'];
    final sigBytes  = branding['signature'];

    pw.Page page;
    switch (template) {
      case BillTemplate.modern:
        page = _buildModern(billDetail, lineItems, company, regular, bold, isPurchase, logoBytes: logoBytes, signatureBytes: sigBytes);
        break;
      case BillTemplate.classic:
        page = _buildClassic(billDetail, lineItems, company, regular, bold, isPurchase, logoBytes: logoBytes, signatureBytes: sigBytes);
        break;
      case BillTemplate.minimal:
        page = _buildMinimal(billDetail, lineItems, company, regular, bold, isPurchase, logoBytes: logoBytes, signatureBytes: sigBytes);
        break;
    }

    final doc = pw.Document();
    doc.addPage(page);
    final dir  = await getTemporaryDirectory();
    final name = 'ApnaCA_${(billDetail['Bill No'] ?? 'bill').toString().replaceAll('-', '_')}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Bill ${billDetail['Bill No'] ?? ''} — ApnaCA');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED: Items table — exactly like HTML template
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Widget _itemsTable(
    List<Map<String, dynamic>> items,
    pw.Font? regular,
    pw.Font? boldFont,
  ) {
    pw.TextStyle ts(double sz, {bool bold = false, PdfColor? c}) => pw.TextStyle(
      font: bold ? boldFont : regular,
      fontSize: sz,
      color: c ?? _darkText,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    // Header row — lavender like HTML
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _lavender),
      children: ['#', 'Item', 'HSN', 'QTY', 'Price/Unit', 'Discount', 'Tax', 'Total']
          .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: pw.Text(h, style: ts(8.5, bold: true)),
              ))
          .toList(),
    );

    // Item rows
    final itemRows = items.asMap().entries.map((e) {
      final i = e.key;
      final m = e.value;

      // Support both 'Item'/'item', 'Qty'/'qty', etc.
      final name  = _clean(m['Item']     ?? m['item']      ?? m['item_name']);
      final hsn   = _clean(m['HSN']      ?? m['hsn_code'],  '');
      final qty   = _clean(m['Qty']      ?? m['qty']);
      final price = _clean(m['Price']    ?? m['unit_price'] ?? m['price']);
      final disc  = _clean(m['Discount'] ?? m['discount_amount'], '0.00');
      final tax   = _clean(m['Tax']      ?? m['tax_rate']   ?? m['tax'], '0%');
      final total = _clean(m['Total']    ?? m['line_total'] ?? m['total']);

      // Format price and total with Rs prefix (no ₹)
      String fmtMoney(String v) {
        if (v == '-') return '-';
        final clean = v.replaceAll('₹', '').replaceAll('Rs.', '').trim();
        return 'Rs.$clean';
      }

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isEven ? _white : _tableAlt),
        children: [
          _tcell('${i + 1}', ts(9)),
          _tcellLeft(name, ts(9, bold: true)),
          _tcell(hsn, ts(8, c: _greyText)),
          _tcell(qty, ts(9)),
          _tcellRight(fmtMoney(price), ts(9)),
          _tcellRight(fmtMoney(disc), ts(9)),
          _tcellRight(tax.contains('%') ? tax : '$tax%', ts(8, c: _greyText)),
          _tcellRight(fmtMoney(total), ts(9, bold: true)),
        ],
      );
    }).toList();

    // Totals row — bold like HTML
    final totalQty = items.fold<double>(0, (s, m) =>
        s + _d(m['Qty'] ?? m['qty'] ?? 0));
    final totalDisc = items.fold<double>(0, (s, m) =>
        s + _d(m['Discount'] ?? m['discount_amount'] ?? 0));
    final totalTax = items.fold<double>(0, (s, m) =>
        s + _d(m['tax_amount'] ?? 0));
    final grandLine = items.fold<double>(0, (s, m) =>
        s + _d(m['Total'] ?? m['line_total'] ?? m['total'] ?? 0));

    final totalsRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _lavender),
      children: [
        _tcell('', ts(9, bold: true)),
        _tcellLeft('Total', ts(9, bold: true)),
        _tcell('', ts(9)),
        _tcell(totalQty.toStringAsFixed(2), ts(9, bold: true)),
        _tcell('', ts(9)),
        _tcellRight(totalDisc.toStringAsFixed(2), ts(9, bold: true)),
        _tcellRight(totalTax.toStringAsFixed(2), ts(9, bold: true)),
        _tcellRight('Rs.${grandLine.toStringAsFixed(2)}', ts(9, bold: true)),
      ],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _borderCol, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(18),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(52),
        3: const pw.FixedColumnWidth(36),
        4: const pw.FixedColumnWidth(58),
        5: const pw.FixedColumnWidth(50),
        6: const pw.FixedColumnWidth(36),
        7: const pw.FixedColumnWidth(58),
      },
      children: [headerRow, ...itemRows, totalsRow],
    );
  }

  // tfoot section — Sub Total / Discount / Tax / Grand Total / Paid / Balance
  static pw.Widget _tfoot(
    Map<String, dynamic> d,
    pw.Font? regular,
    pw.Font? boldFont,
  ) {
    pw.TextStyle ts(double sz, {bool bold = false, PdfColor? c}) => pw.TextStyle(
      font: bold ? boldFont : regular,
      fontSize: sz,
      color: c ?? _darkText,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    final subtotal  = _d(d['Subtotal']  ?? d['subtotal']);
    final discount  = _d(d['Discount']  ?? d['discount_amount']);
    final gst       = _d(d['GST']       ?? d['gst_amount'] ?? d['tax_amount']);
    final total     = _d(d['Total']     ?? d['total_amount']);
    final status    = _clean(d['Status'] ?? d['payment_status'], 'unpaid').toLowerCase();
    final paid      = status == 'paid' ? total : 0.0;
    final balance   = total - paid;
    final notes     = _clean(d['Notes'] ?? d['notes'], '');

    final rows = <pw.TableRow>[
      _footRow('Sub Total',  'Rs.${subtotal.toStringAsFixed(2)}',  ts, footnote: notes),
      _footRow('Discount',   'Rs.${discount.toStringAsFixed(2)}',  ts),
      _footRow('Tax',        'Rs.${gst.toStringAsFixed(2)}',       ts),
      _footRow('Round Off',  'Rs.0.00',                            ts),
    ];

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Table(
        border: pw.TableBorder.all(color: _borderCol, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FixedColumnWidth(80),
        },
        children: rows,
      ),
      // Amount in words + grand total
      pw.Table(
        border: pw.TableBorder.all(color: _borderCol, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FixedColumnWidth(80),
        },
        children: [
          pw.TableRow(children: [
            pw.TableRow(children: []).decoration == null
                ? pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Bill Amount in Words:', style: ts(8, bold: true)),
                      pw.SizedBox(height: 3),
                      pw.Text(_amountInWords(total), style: ts(8.5)),
                    ]),
                  )
                : pw.SizedBox(),
            _footCell('Grand Total',         ts, bold: true),
            _footCell('Rs.${total.toStringAsFixed(2)}', ts, bold: true),
          ]),
          pw.TableRow(children: [
            pw.SizedBox(),
            _footCell('Paid Amount', ts),
            _footCell('Rs.${paid.toStringAsFixed(2)}', ts),
          ]),
          pw.TableRow(children: [
            pw.SizedBox(),
            _footCell('Balance', ts),
            _footCell('Rs.${balance.toStringAsFixed(2)}', ts),
          ]),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 1: MODERN — matches apnahisab HTML exactly
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Page _buildModern(
    Map<String, dynamic> d,
    List<Map<String, dynamic>> items,
    Map<String, String> co,
    pw.Font? regular,
    pw.Font? boldFont,
    bool isPurchase, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    pw.TextStyle ts(double sz, {bool bold = false, PdfColor? c}) => pw.TextStyle(
      font: bold ? boldFont : regular,
      fontSize: sz, color: c ?? _darkText,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    final billNo   = _clean(d['Bill No'] ?? d['bill_number']);
    final date     = _clean(d['Date']    ?? d['bill_date']);
    final customer = _clean(d['Customer'] ?? d['Supplier'] ?? d['customer_name'] ?? d['supplier_name']);
    final status   = _clean(d['Status']  ?? d['payment_status'], 'unpaid');
    final payment  = _clean(d['Payment'] ?? d['payment_mode'], 'Cash');
    final invoiceTitle = isPurchase ? 'PURCHASE INVOICE' : 'TAX INVOICE';
    final billLabel    = isPurchase ? 'Supplier' : 'Bill To';
    final subtotal = _d(d['Subtotal'] ?? d['subtotal']);
    final discount = _d(d['Discount'] ?? d['discount_amount']);
    final gst      = _d(d['GST']      ?? d['gst_amount'] ?? d['tax_amount']);
    final total    = _d(d['Total']    ?? d['total_amount']);
    final paidAmt  = status.toLowerCase() == 'paid' ? total : 0.0;
    final balance  = total - paidAmt;
    final notes    = _clean(d['Notes'] ?? d['notes'], '');

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(20, 15, 20, 15),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [

        // ── HEADER TABLE: logo area | company info | bill info ─────
        pw.Table(children: [pw.TableRow(children: [
          // Logo area: show actual logo if available, else lavender placeholder
          logoBytes != null
              ? pw.Container(
                  width: 70, height: 70,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                )
              : pw.Container(
                  width: 70, height: 70,
                  color: _lavender,
                  child: pw.Center(child: pw.Text(co['company_name']![0],
                      style: ts(28, bold: true, c: _greyText))),
                ),
          // Company center
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text(co['company_name']!, style: ts(22, bold: true)),
              pw.SizedBox(height: 4),
              if ((co['address'] ?? '').isNotEmpty) pw.Text(co['address']!, style: ts(9, c: _greyText)),
              if ((co['mobile'] ?? '').isNotEmpty)  pw.Text('M: ${co['mobile']}',  style: ts(9, c: _greyText)),
              if ((co['email'] ?? '').isNotEmpty)   pw.Text('E: ${co['email']}',   style: ts(9, c: _greyText)),
              if ((co['gst'] ?? '').isNotEmpty)     pw.Text('GST: ${co['gst']}',   style: ts(9, c: _greyText)),
            ]),
          ),
          // Bill info right
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Bill #: $billNo', style: ts(16, bold: true)),
            pw.SizedBox(height: 3),
            pw.Text('Date: $date', style: ts(10)),
            pw.SizedBox(height: 3),
            _statusBadge(status, regular, boldFont),
          ]),
        ])]),

        pw.SizedBox(height: 10),
        pw.Divider(color: _borderCol, height: 1),
        pw.SizedBox(height: 8),

        // ── ADDRESSES: Bill To | Payment ──────────────────────────
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          children: [pw.TableRow(
            decoration: const pw.BoxDecoration(color: _lavender),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(billLabel, style: ts(10, bold: true)),
                  pw.SizedBox(height: 4),
                  pw.Text(customer, style: ts(13, bold: true)),
                ],
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(invoiceTitle, style: ts(10, bold: true)),
                  pw.SizedBox(height: 4),
                  pw.Text('Payment: $payment', style: ts(10)),
                  pw.Text('Status: ${status.toUpperCase()}', style: ts(10, bold: true,
                      c: status.toLowerCase() == 'paid' ? _greenBadge : _redBadge)),
                ],
              )),
            ],
          )],
        ),

        pw.SizedBox(height: 10),

        // ── ITEMS TABLE ────────────────────────────────────────────
        _itemsTable(items, regular, boldFont),

        pw.SizedBox(height: 0),

        // ── TFOOT: notes + subtotal/discount/tax/total/paid/balance ─
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('Note: $notes', style: ts(8))),
              _footCell('Sub Total',  ts),
              _footCell('Rs.${subtotal.toStringAsFixed(2)}', ts),
            ]),
            pw.TableRow(children: [
              pw.SizedBox(),
              _footCell('Discount', ts),
              _footCell('Rs.${discount.toStringAsFixed(2)}', ts),
            ]),
            pw.TableRow(children: [
              pw.SizedBox(),
              _footCell('Tax', ts),
              _footCell('Rs.${gst.toStringAsFixed(2)}', ts),
            ]),
            pw.TableRow(children: [
              pw.SizedBox(),
              _footCell('Round Off', ts),
              _footCell('Rs.0.00', ts),
            ]),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Bill Amount in Words:', style: ts(8, bold: true)),
                  pw.SizedBox(height: 3),
                  pw.Text(_amountInWords(total), style: ts(8.5)),
                ],
              )),
              _footCell('Grand Total',  ts, bold: true),
              _footCell('Rs.${total.toStringAsFixed(2)}', ts, bold: true),
            ]),
            pw.TableRow(children: [
              pw.SizedBox(),
              _footCell('Paid Amount', ts),
              _footCell('Rs.${paidAmt.toStringAsFixed(2)}', ts),
            ]),
            pw.TableRow(children: [
              pw.SizedBox(),
              _footCell('Balance', ts),
              _footCell('Rs.${balance.toStringAsFixed(2)}', ts),
            ]),
          ],
        ),

        pw.SizedBox(height: 14),

        // ── SIGNATURE ─────────────────────────────────────────────
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            // Signature image if available, else empty space
            signatureBytes != null
                ? pw.Container(
                    width: 100, height: 40,
                    child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                  )
                : pw.SizedBox(height: 28),
            pw.Container(
              width: 120,
              decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: _greyText, width: 0.5))),
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Column(children: [
                pw.Text(co['company_name']!, style: ts(10, bold: true)),
                pw.Text('Authorized Signatory', style: ts(8, c: _greyText)),
              ]),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 2: CLASSIC — Green, traditional
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Page _buildClassic(
    Map<String, dynamic> d,
    List<Map<String, dynamic>> items,
    Map<String, String> co,
    pw.Font? regular,
    pw.Font? boldFont,
    bool isPurchase, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    final green = PdfColor.fromInt(0xFF15803D);
    pw.TextStyle ts(double sz, {bool bold = false, PdfColor? c}) => pw.TextStyle(
      font: bold ? boldFont : regular, fontSize: sz, color: c ?? _darkText,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    final billNo   = _clean(d['Bill No'] ?? d['bill_number']);
    final date     = _clean(d['Date']    ?? d['bill_date']);
    final customer = _clean(d['Customer'] ?? d['Supplier'] ?? d['customer_name'] ?? d['supplier_name']);
    final status   = _clean(d['Status']  ?? d['payment_status'], 'unpaid');
    final payment  = _clean(d['Payment'] ?? d['payment_mode'], 'Cash');
    final invoiceTitle = isPurchase ? 'PURCHASE INVOICE' : 'TAX INVOICE';
    final billLabel    = isPurchase ? 'Supplier' : 'Bill To';
    final subtotal = _d(d['Subtotal'] ?? d['subtotal']);
    final discount = _d(d['Discount'] ?? d['discount_amount']);
    final gst      = _d(d['GST']      ?? d['gst_amount'] ?? d['tax_amount']);
    final total    = _d(d['Total']    ?? d['total_amount']);
    final paidAmt  = status.toLowerCase() == 'paid' ? total : 0.0;
    final balance  = total - paidAmt;
    final notes    = _clean(d['Notes'] ?? d['notes'], '');

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(20, 15, 20, 15),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(children: [
            // Logo (if available)
            if (logoBytes != null) ...[
              pw.Container(
                width: 55, height: 55,
                child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 8),
            ],
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(co['company_name']!, style: ts(22, bold: true, c: green)),
              if ((co['address'] ?? '').isNotEmpty) pw.Text(co['address']!, style: ts(9, c: _greyText)),
              if ((co['mobile'] ?? '').isNotEmpty)  pw.Text('M: ${co['mobile']}', style: ts(9, c: _greyText)),
              if ((co['email']  ?? '').isNotEmpty)  pw.Text('E: ${co['email']}',  style: ts(9, c: _greyText)),
              if ((co['gst']    ?? '').isNotEmpty)  pw.Text('GST: ${co['gst']}',  style: ts(9, c: _greyText)),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(invoiceTitle, style: ts(14, bold: true, c: green)),
            pw.Text('Bill #: $billNo', style: ts(12, bold: true)),
            pw.Text('Date: $date', style: ts(9, c: _greyText)),
            pw.SizedBox(height: 3),
            _statusBadge(status, regular, boldFont),
          ]),
        ]),
        pw.Divider(height: 12, color: green, thickness: 2),
        // Addresses
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          children: [pw.TableRow(
            decoration: const pw.BoxDecoration(color: _lavender),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(billLabel, style: ts(10, bold: true, c: green)),
                  pw.Text(customer, style: ts(13, bold: true)),
                ],
              )),
              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Payment Info', style: ts(10, bold: true, c: green)),
                  pw.Text('Mode: $payment', style: ts(10)),
                  pw.Text('Status: ${status.toUpperCase()}', style: ts(10, bold: true,
                      c: status.toLowerCase() == 'paid' ? _greenBadge : _redBadge)),
                ],
              )),
            ],
          )],
        ),
        pw.SizedBox(height: 10),
        _itemsTable(items, regular, boldFont),
        // Tfoot
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FixedColumnWidth(80) },
          children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Note: $notes', style: ts(8))), _footCell('Sub Total', ts), _footCell('Rs.${subtotal.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Discount', ts), _footCell('Rs.${discount.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Tax', ts), _footCell('Rs.${gst.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Round Off', ts), _footCell('Rs.0.00', ts)]),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FixedColumnWidth(80) },
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Bill Amount in Words:', style: ts(8, bold: true)),
                pw.SizedBox(height: 3),
                pw.Text(_amountInWords(total), style: ts(8.5)),
              ])),
              _footCell('Grand Total', ts, bold: true),
              _footCell('Rs.${total.toStringAsFixed(2)}', ts, bold: true),
            ]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Paid Amount', ts), _footCell('Rs.${paidAmt.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Balance', ts), _footCell('Rs.${balance.toStringAsFixed(2)}', ts)]),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            signatureBytes != null
                ? pw.Container(
                    width: 100, height: 40,
                    child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                  )
                : pw.SizedBox(height: 28),
            pw.Container(
              width: 120,
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: green, width: 0.8))),
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Column(children: [
                pw.Text(co['company_name']!, style: ts(10, bold: true, c: green)),
                pw.Text('Authorized Signatory', style: ts(8, c: _greyText)),
              ]),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 3: MINIMAL — Black & White, print-friendly
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Page _buildMinimal(
    Map<String, dynamic> d,
    List<Map<String, dynamic>> items,
    Map<String, String> co,
    pw.Font? regular,
    pw.Font? boldFont,
    bool isPurchase, {
    Uint8List? logoBytes,
    Uint8List? signatureBytes,
  }) {
    pw.TextStyle ts(double sz, {bool bold = false, PdfColor? c}) => pw.TextStyle(
      font: bold ? boldFont : regular, fontSize: sz, color: c ?? _darkText,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    final billNo   = _clean(d['Bill No'] ?? d['bill_number']);
    final date     = _clean(d['Date']    ?? d['bill_date']);
    final customer = _clean(d['Customer'] ?? d['Supplier'] ?? d['customer_name'] ?? d['supplier_name']);
    final status   = _clean(d['Status']  ?? d['payment_status'], 'unpaid');
    final payment  = _clean(d['Payment'] ?? d['payment_mode'], 'Cash');
    final billLabel = isPurchase ? 'Supplier' : 'Bill To';
    final subtotal = _d(d['Subtotal'] ?? d['subtotal']);
    final discount = _d(d['Discount'] ?? d['discount_amount']);
    final gst      = _d(d['GST']      ?? d['gst_amount'] ?? d['tax_amount']);
    final total    = _d(d['Total']    ?? d['total_amount']);
    final paidAmt  = status.toLowerCase() == 'paid' ? total : 0.0;
    final balance  = total - paidAmt;
    final notes    = _clean(d['Notes'] ?? d['notes'], '');

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(co['company_name']!, style: ts(20, bold: true)),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(isPurchase ? 'PURCHASE INVOICE' : 'TAX INVOICE', style: ts(13, bold: true)),
            pw.Text('Bill #: $billNo | $date', style: ts(9, c: _greyText)),
          ]),
        ]),
        if ((co['mobile'] ?? '').isNotEmpty) pw.Text('M: ${co['mobile']} | E: ${co['email']}', style: ts(9, c: _greyText)),
        pw.Divider(height: 10, color: _darkText, thickness: 0.8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(billLabel, style: ts(8, c: _greyText)),
            pw.Text(customer, style: ts(12, bold: true)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Payment: $payment', style: ts(9)),
            _statusBadge(status, regular, boldFont),
          ]),
        ]),
        pw.SizedBox(height: 10),
        _itemsTable(items, regular, boldFont),
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FixedColumnWidth(80) },
          children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Note: $notes', style: ts(8))), _footCell('Sub Total', ts), _footCell('Rs.${subtotal.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Discount', ts), _footCell('Rs.${discount.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Tax', ts), _footCell('Rs.${gst.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Round Off', ts), _footCell('Rs.0.00', ts)]),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _borderCol, width: 0.5),
          columnWidths: { 0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FixedColumnWidth(80) },
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Bill Amount in Words:', style: ts(8, bold: true)),
                pw.Text(_amountInWords(total), style: ts(8.5)),
              ])),
              _footCell('Grand Total', ts, bold: true),
              _footCell('Rs.${total.toStringAsFixed(2)}', ts, bold: true),
            ]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Paid Amount', ts), _footCell('Rs.${paidAmt.toStringAsFixed(2)}', ts)]),
            pw.TableRow(children: [pw.SizedBox(), _footCell('Balance', ts), _footCell('Rs.${balance.toStringAsFixed(2)}', ts)]),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            signatureBytes != null
                ? pw.Container(
                    width: 90, height: 36,
                    child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                  )
                : pw.SizedBox(height: 24),
            pw.Container(
              width: 110,
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _greyText, width: 0.5))),
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Column(children: [
                pw.Text(co['company_name']!, style: ts(9, bold: true)),
                pw.Text('Authorized Signatory', style: ts(8, c: _greyText)),
              ]),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ── Shared small helpers ───────────────────────────────────────────────────

  static pw.Widget _statusBadge(String status, pw.Font? regular, pw.Font? boldFont) {
    final c = status.toLowerCase() == 'paid' ? _greenBadge : _redBadge;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text(status.toUpperCase(),
          style: pw.TextStyle(font: boldFont, fontSize: 8, color: _white, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _tcell(String t, pw.TextStyle s) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Text(t, style: s, textAlign: pw.TextAlign.right));

  static pw.Widget _tcellRight(String t, pw.TextStyle s) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Text(t, style: s, textAlign: pw.TextAlign.right));

  static pw.Widget _tcellLeft(String t, pw.TextStyle s) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: pw.Text(t, style: s, textAlign: pw.TextAlign.left));

  static pw.TableRow _footRow(String label, String value,
      pw.TextStyle Function(double, {bool bold, PdfColor? c}) ts,
      {String? footnote}) {
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6),
          child: footnote != null ? pw.Text('Note: $footnote', style: ts(8)) : pw.SizedBox()),
      _footCell(label, ts),
      _footCell(value, ts),
    ]);
  }

  static pw.Widget _footCell(String t,
      pw.TextStyle Function(double, {bool bold, PdfColor? c}) ts,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(t,
          style: ts(bold ? 10 : 9, bold: bold),
          textAlign: pw.TextAlign.right),
    );
  }
}
