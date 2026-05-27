import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

enum BillTemplate { classic, modern, minimal }

class BillPdfService {
  // ── Fetch company info from Firestore ──────────────────────────
  static Future<Map<String, String>> _fetchCompanyInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return _defaultCompany();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return _defaultCompany();
      final data = doc.data()!;
      return {
        'company_name': data['company_name'] as String? ?? 'ApnaCA',
        'name': '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
        'email': data['email'] as String? ?? '',
        'mobile': data['mobile'] as String? ?? '',
        'username': data['username'] as String? ?? '',
      };
    } catch (_) {
      return _defaultCompany();
    }
  }

  static Map<String, String> _defaultCompany() => {
    'company_name': 'ApnaCA',
    'name': '',
    'email': '',
    'mobile': '',
    'username': '',
  };

  // ── Load font with fallback ────────────────────────────────────
  static Future<pw.Font?> _loadFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  // ── Main entry point ───────────────────────────────────────────
  static Future<void> generateAndShare({
    required Map<String, dynamic> billDetail,
    required List<Map<String, dynamic>> lineItems,
    BillTemplate template = BillTemplate.modern,
  }) async {
    final company = await _fetchCompanyInfo();
    final font = await _loadFont();
    // Detect purchase bill — use "Purchase Invoice" label
    final isPurchase = (billDetail['type'] == 'purchase_bill') ||
        (billDetail['Bill No']?.toString().startsWith('PB-') ?? false);

    switch (template) {
      case BillTemplate.classic:
        await _generateClassic(billDetail, lineItems, company, font, isPurchase: isPurchase);
        break;
      case BillTemplate.modern:
        await _generateModern(billDetail, lineItems, company, font, isPurchase: isPurchase);
        break;
      case BillTemplate.minimal:
        await _generateMinimal(billDetail, lineItems, company, font, isPurchase: isPurchase);
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // TEMPLATE 1: MODERN (Blue header, professional)
  // ══════════════════════════════════════════════════════════════
  static Future<void> _generateModern(
      Map<String, dynamic> detail,
      List<Map<String, dynamic>> items,
      Map<String, String> company,
      pw.Font? font, {
      bool isPurchase = false,
      }) async {
    final pdf = pw.Document();
    final primary = PdfColor.fromHex('#2563EB');
    final lightBlue = PdfColor.fromHex('#EFF6FF');
    final border = PdfColor.fromHex('#BFDBFE');
    final dark = PdfColor.fromHex('#1E293B');
    final grey = PdfColor.fromHex('#64748B');

    pw.TextStyle ts(double size, {PdfColor? color, bool bold = false}) =>
        pw.TextStyle(
          font: font,
          fontSize: size,
          color: color ?? dark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
                color: primary, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(company['company_name']!, style: ts(20, color: PdfColors.white, bold: true)),
                  if (company['mobile']!.isNotEmpty)
                    pw.Text(company['mobile']!, style: ts(9, color: PdfColors.white)),
                  if (company['email']!.isNotEmpty)
                    pw.Text(company['email']!, style: ts(9, color: PdfColors.white)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(detail['Bill No'] ?? '', style: ts(14, color: PdfColors.white, bold: true)),
                  pw.SizedBox(height: 4),
                  _statusBadge(detail['Status'] ?? '', font),
                  pw.Text('SALE INVOICE', style: ts(8, color: PdfColors.white)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // Bill info row
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: border)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              _infoCol('BILL TO', detail['Customer'] ?? '-', dark, grey, font),
              _infoCol('DATE', detail['Date'] ?? '-', dark, grey, font),
              _infoCol('PAYMENT', (detail['Payment'] ?? '-').toUpperCase(), dark, grey, font),
              _infoCol('TAX TYPE', detail['Tax Type'] ?? 'Exclusive', dark, grey, font),
            ]),
          ),
          pw.SizedBox(height: 14),
          // Items table
          _itemsTable(items, primary, dark, grey, font),
          pw.SizedBox(height: 10),
          // Totals
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 200,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: lightBlue, borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: border)),
              child: pw.Column(children: [
                _totLine('Subtotal', detail['Subtotal'] ?? '₹0', dark, grey, font),
                if (detail.containsKey('Discount')) ...[
                  pw.SizedBox(height: 3),
                  _totLine('Discount', detail['Discount'] ?? '', PdfColor.fromHex('#16A34A'), grey, font),
                ],
                pw.SizedBox(height: 3),
                _totLine('GST', detail['GST'] ?? '₹0', dark, grey, font),
                pw.Divider(height: 8, color: border),
                _totLine('TOTAL', detail['Total'] ?? '₹0', primary, primary, font, bold: true),
              ]),
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: border),
          pw.Center(child: pw.Text('${company['company_name']} • Thank you for your business!',
              style: ts(8, color: grey))),
        ],
      ),
    ));
    await _saveAndShare(pdf, detail['Bill No'] ?? 'bill');
  }

  // ══════════════════════════════════════════════════════════════
  // TEMPLATE 2: CLASSIC (Green header, traditional look)
  // ══════════════════════════════════════════════════════════════
  static Future<void> _generateClassic(
      Map<String, dynamic> detail,
      List<Map<String, dynamic>> items,
      Map<String, String> company,
      pw.Font? font, {
      bool isPurchase = false,
      }) async {
    final pdf = pw.Document();
    final primary = PdfColor.fromHex('#15803D');
    final light = PdfColor.fromHex('#F0FDF4');
    final border = PdfColor.fromHex('#BBF7D0');
    final dark = PdfColor.fromHex('#14532D');
    final grey = PdfColor.fromHex('#6B7280');

    pw.TextStyle ts(double size, {PdfColor? color, bool bold = false}) =>
        pw.TextStyle(font: font, fontSize: size, color: color ?? dark,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Classic header with two-tone
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(company['company_name']!, style: ts(22, color: primary, bold: true)),
              if (company['mobile']!.isNotEmpty) pw.Text('📞 ${company['mobile']}', style: ts(9, color: grey)),
              if (company['email']!.isNotEmpty) pw.Text('✉ ${company['email']}', style: ts(9, color: grey)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(isPurchase ? 'PURCHASE INVOICE' : 'TAX INVOICE', style: ts(16, bold: true)),
              pw.Text(detail['Bill No'] ?? '', style: ts(11, color: primary)),
              pw.Text(detail['Date'] ?? '', style: ts(9, color: grey)),
            ]),
          ]),
          pw.Divider(height: 16, color: primary, thickness: 2),
          // Bill to
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: light,
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Bill To:', style: ts(8, color: grey)),
                pw.Text(detail['Customer'] ?? '-', style: ts(12, bold: true)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Payment: ${(detail['Payment'] ?? '-').toUpperCase()}', style: ts(9)),
                pw.Text('Status: ${detail['Status'] ?? '-'}', style: ts(9, color: primary, bold: true)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 12),
          _itemsTable(items, primary, dark, grey, font),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 210,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: border)),
              child: pw.Column(children: [
                pw.Container(
                  color: primary, padding: const pw.EdgeInsets.all(6),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Description', style: ts(9, color: PdfColors.white, bold: true)),
                    pw.Text('Amount', style: ts(9, color: PdfColors.white, bold: true)),
                  ]),
                ),
                _classicTotRow('Subtotal', detail['Subtotal'] ?? '₹0', light, dark, grey, font),
                if (detail.containsKey('Discount'))
                  _classicTotRow('Discount', detail['Discount'] ?? '', light, PdfColor.fromHex('#16A34A'), grey, font),
                _classicTotRow('GST', detail['GST'] ?? '₹0', light, dark, grey, font),
                pw.Container(
                  color: primary, padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('TOTAL', style: ts(11, color: PdfColors.white, bold: true)),
                    pw.Text(detail['Total'] ?? '₹0', style: ts(11, color: PdfColors.white, bold: true)),
                  ]),
                ),
              ]),
            ),
          ),
          pw.Spacer(),
          pw.Center(child: pw.Text('Generated by ${company['company_name']} via ApnaCA', style: ts(8, color: grey))),
        ],
      ),
    ));
    await _saveAndShare(pdf, detail['Bill No'] ?? 'bill');
  }

  // ══════════════════════════════════════════════════════════════
  // TEMPLATE 3: MINIMAL (Clean, black & white, print-friendly)
  // ══════════════════════════════════════════════════════════════
  static Future<void> _generateMinimal(
      Map<String, dynamic> detail,
      List<Map<String, dynamic>> items,
      Map<String, String> company,
      pw.Font? font, {
      bool isPurchase = false,
      }) async {
    final pdf = pw.Document();
    final dark = PdfColor.fromHex('#111827');
    final grey = PdfColor.fromHex('#6B7280');
    final border = PdfColor.fromHex('#E5E7EB');

    pw.TextStyle ts(double size, {PdfColor? color, bool bold = false}) =>
        pw.TextStyle(font: font, fontSize: size, color: color ?? dark,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(company['company_name']!, style: ts(20, bold: true)),
            pw.Text(detail['Bill No'] ?? '', style: ts(14)),
          ]),
          pw.Text(company['email']!, style: ts(9, color: grey)),
          pw.Text(company['mobile']!, style: ts(9, color: grey)),
          pw.SizedBox(height: 4),
          pw.Divider(color: dark, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(isPurchase ? 'Supplier' : 'Bill To', style: ts(8, color: grey)),
              pw.Text(detail['Customer'] ?? '-', style: ts(11, bold: true)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Date: ${detail['Date'] ?? '-'}', style: ts(9)),
              pw.Text('Payment: ${detail['Payment'] ?? '-'}', style: ts(9)),
              pw.Text('Status: ${detail['Status'] ?? '-'}', style: ts(9, bold: true)),
            ]),
          ]),
          pw.SizedBox(height: 12),
          _itemsTable(items, dark, dark, grey, font),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 180,
              child: pw.Column(children: [
                _minTotLine('Subtotal', detail['Subtotal'] ?? '₹0', dark, grey, font),
                if (detail.containsKey('Discount'))
                  _minTotLine('Discount', detail['Discount'] ?? '', dark, grey, font),
                _minTotLine('GST', detail['GST'] ?? '₹0', dark, grey, font),
                pw.Divider(color: dark, thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL', style: ts(12, bold: true)),
                  pw.Text(detail['Total'] ?? '₹0', style: ts(12, bold: true)),
                ]),
              ]),
            ),
          ),
          pw.Spacer(),
          pw.Center(child: pw.Text('${company['company_name']}', style: ts(8, color: grey))),
        ],
      ),
    ));
    await _saveAndShare(pdf, detail['Bill No'] ?? 'bill');
  }

  // ── Shared helpers ─────────────────────────────────────────────

  static pw.Widget _itemsTable(List<Map<String, dynamic>> items,
      PdfColor primary, PdfColor dark, PdfColor grey, pw.Font? font) {
    pw.TextStyle ts(double sz, {PdfColor? c, bool bold = false}) =>
        pw.TextStyle(font: font, fontSize: sz, color: c ?? dark,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    final light = PdfColor.fromHex('#F8FAFC');
    final border = PdfColor.fromHex('#E2E8F0');

    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: primary,
        child: pw.Row(children: [
          pw.Expanded(flex: 4, child: pw.Text('ITEM', style: ts(8.5, c: PdfColors.white, bold: true))),
          pw.Expanded(flex: 1, child: pw.Text('QTY', style: ts(8.5, c: PdfColors.white, bold: true), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text('PRICE', style: ts(8.5, c: PdfColors.white, bold: true), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 1, child: pw.Text('TAX', style: ts(8.5, c: PdfColors.white, bold: true), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text('TOTAL', style: ts(8.5, c: PdfColors.white, bold: true), textAlign: pw.TextAlign.right)),
        ]),
      ),
      ...items.asMap().entries.map((e) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: e.key.isEven ? PdfColors.white : light,
        child: pw.Row(children: [
          pw.Expanded(flex: 4, child: pw.Text(e.value['item']?.toString() ?? '', style: ts(9))),
          pw.Expanded(flex: 1, child: pw.Text(e.value['qty']?.toString() ?? '', style: ts(9), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text(e.value['price']?.toString() ?? '', style: ts(9), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 1, child: pw.Text(e.value['tax']?.toString() ?? '', style: ts(8, c: grey), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text(e.value['total']?.toString() ?? '', style: ts(9, bold: true), textAlign: pw.TextAlign.right)),
        ]),
      )),
    ]);
  }

  static pw.Widget _statusBadge(String status, pw.Font? font) {
    PdfColor c;
    switch (status.toLowerCase()) {
      case 'paid':    c = PdfColor.fromHex('#16A34A'); break;
      case 'unpaid':  c = PdfColor.fromHex('#DC2626'); break;
      default:        c = PdfColor.fromHex('#EA580C');
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Text(status.toUpperCase(),
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _infoCol(String label, String value,
      PdfColor dark, PdfColor grey, pw.Font? font) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: 7, color: grey)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10, color: dark, fontWeight: pw.FontWeight.bold)),
    ]);
  }

  static pw.Widget _totLine(String label, String value,
      PdfColor labelColor, PdfColor _, pw.Font? font, {bool bold = false}) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: bold ? 11 : 9,
          color: labelColor, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(value, style: pw.TextStyle(font: font, fontSize: bold ? 11 : 9,
          color: labelColor, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ]);
  }

  static pw.Widget _classicTotRow(String label, String value,
      PdfColor bg, PdfColor valueColor, PdfColor grey, pw.Font? font) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: grey)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9, color: valueColor, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  static pw.Widget _minTotLine(String label, String value,
      PdfColor dark, PdfColor grey, pw.Font? font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9, color: grey)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9, color: dark)),
      ]),
    );
  }

  static Future<void> _saveAndShare(pw.Document pdf, String billNo) async {
    final dir = await getTemporaryDirectory();
    final fileName = 'ApnaCA_${billNo.replaceAll('-', '_')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Bill $billNo — ApnaCA',
    );
  }
}