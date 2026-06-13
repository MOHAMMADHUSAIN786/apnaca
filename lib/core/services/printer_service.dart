import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// Lightweight printer abstraction. Currently a stub implementation that
/// formats and returns success. Replace with platform-specific ESC/POS or
/// network printer implementation as needed.
class PrinterService {
  PrinterService._internal();
  static final PrinterService instance = PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  /// Print a simple text receipt. Returns `true` when the (stub) print is done.
  Future<bool> printText(String text) async {
    // TODO: integrate actual printer SDK (esc_pos_printer, bluetooth, etc.)
    // For now simulate a short delay and log to debug consoles when available.
    await Future.delayed(const Duration(milliseconds: 400));
    // In real implementation send `text` to the printer.
    return true;
  }

  /// Kick the cash drawer via printer command or platform API.
  Future<bool> kickCashDrawer() async {
    // Try bluetooth first if connected
    final isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      final bytes = escposDrawerKick();
      for (final byte in bytes) {
        bluetooth.writeBytes(Uint8List.fromList([byte]));
      }
      return true;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  /// Helper for basic receipt formatting (plain text) for preview/testing.
  String formatReceipt({required String shopName, required String billNumber, required String date, required List<Map<String,dynamic>> items, required double subtotal, required double taxAmount, required double total}) {
    final sb = StringBuffer();
    sb.writeln(shopName);
    sb.writeln('Bill: $billNumber');
    sb.writeln('Date: $date');
    sb.writeln('-------------------------------');
    sb.writeln(_padCols(['Item', 'Qty', 'Rate', 'Total']));
    sb.writeln('-------------------------------');
    for (final it in items) {
      final name = (it['item_name'] ?? it['name'] ?? '').toString();
      final qty = (it['qty'] ?? 0).toString();
      final price = ((it['unit_price'] ?? 0) as num).toDouble().toStringAsFixed(2);
      final line = (((it['unit_price'] ?? 0) as num).toDouble() * (it['qty'] ?? 0)).toStringAsFixed(2);
      sb.writeln(_padCols([name, qty, price, line]));
    }
    sb.writeln('-------------------------------');
    sb.writeln(_padCols(['Subtotal', '', '', '₹' + subtotal.toStringAsFixed(2)]));
    sb.writeln(_padCols(['Tax', '', '', '₹' + taxAmount.toStringAsFixed(2)]));
    sb.writeln(_padCols(['TOTAL', '', '', '₹' + total.toStringAsFixed(2)]));
    sb.writeln('-------------------------------');
    return sb.toString();
  }

  String _padCols(List<String> cols, {int nameWidth = 18, int qtyWidth = 4, int rateWidth = 8, int totalWidth = 8}) {
    final name = cols[0].length > nameWidth ? cols[0].substring(0, nameWidth - 1) : cols[0];
    final qty = cols.length > 1 ? cols[1] : '';
    final rate = cols.length > 2 ? cols[2] : '';
    final tot = cols.length > 3 ? cols[3] : '';
    final a = name.padRight(nameWidth);
    final b = qty.padLeft(qtyWidth);
    final c = rate.padLeft(rateWidth);
    final d = tot.padLeft(totalWidth);
    return '$a $b $c $d';
  }

  /// Send raw text to a network (TCP) printer at [ip]:[port].
  /// Returns true if socket connect and write succeed.
  Future<bool> printToNetworkPrinter(String ip, int port, String text, {Duration timeout = const Duration(seconds:5)}) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.add(utf8.encode(text));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send raw bytes to a network (TCP) printer at [ip]:[port].
  Future<bool> printBytesToNetworkPrinter(String ip, int port, List<int> bytes, {Duration timeout = const Duration(seconds:5)}) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.add(Uint8List.fromList(bytes));
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Print raw bytes to the connected Bluetooth printer.
  Future<bool> printBytesToBluetooth(List<int> bytes) async {
    try {
      final isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
        // blue_thermal_printer writes Uint8List
        bluetooth.writeBytes(Uint8List.fromList(bytes));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ESC/POS helpers
  List<int> escposInit() => [0x1B, 0x40];
  List<int> escposNewLine([int n = 1]) => List<int>.filled(n, 0x0A);
  List<int> escposBoldOn() => [0x1B, 0x45, 1];
  List<int> escposBoldOff() => [0x1B, 0x45, 0];
  List<int> escposCut() => [0x1D, 0x56, 1];
  List<int> escposDrawerKick() => [0x1B, 0x70, 0x00, 0x3C, 0xFF];

  /// Format receipt bytes using simple ESC/POS sequences.
  List<int> formatReceiptBytes({required String shopName, required String billNumber, required String date, required List<Map<String,dynamic>> items, required double subtotal, required double taxAmount, required double total}) {
    final out = <int>[];
    out.addAll(escposInit());
    out.addAll(escposBoldOn());
    out.addAll(utf8.encode('$shopName\n'));
    out.addAll(escposBoldOff());
    out.addAll(utf8.encode('Bill: $billNumber\n'));
    out.addAll(utf8.encode('Date: $date\n'));
    out.addAll(utf8.encode('--------------------------------\n'));
    out.addAll(utf8.encode('${_padColsBytes(['Item','Qty','Rate','Total'])}\n'));
    out.addAll(utf8.encode('--------------------------------\n'));
    for (final it in items) {
      final name = (it['item_name'] ?? it['name'] ?? '').toString();
      final qty = (it['qty'] ?? 0).toString();
      final rate = ((it['unit_price'] ?? 0) as num).toDouble().toStringAsFixed(2);
      final lineTotal = (((it['unit_price'] ?? 0) as num).toDouble() * (it['qty'] ?? 0)).toStringAsFixed(2);
      out.addAll(utf8.encode('${_padColsBytes([name, qty, rate, lineTotal])}\n'));
    }
    out.addAll(utf8.encode('--------------------------------\n'));
    out.addAll(utf8.encode('${_padColsBytes(['Subtotal', '', '', '₹' + subtotal.toStringAsFixed(2)])}\n'));
    out.addAll(utf8.encode('${_padColsBytes(['Tax', '', '', '₹' + taxAmount.toStringAsFixed(2)])}\n'));
    out.addAll(utf8.encode('${_padColsBytes(['TOTAL', '', '', '₹' + total.toStringAsFixed(2)])}\n'));
    out.addAll(escposNewLine(3));
    out.addAll(escposCut());
    return out;
  }

  String _padColsBytes(List<String> cols, {int nameWidth = 18, int qtyWidth = 4, int rateWidth = 8, int totalWidth = 8}) {
    final name = cols[0].length > nameWidth ? cols[0].substring(0, nameWidth - 1) : cols[0];
    final qty = cols.length > 1 ? cols[1] : '';
    final rate = cols.length > 2 ? cols[2] : '';
    final tot = cols.length > 3 ? cols[3] : '';
    final a = name.padRight(nameWidth);
    final b = qty.padLeft(qtyWidth);
    final c = rate.padLeft(rateWidth);
    final d = tot.padLeft(totalWidth);
    return '$a $b $c $d';
  }
}
