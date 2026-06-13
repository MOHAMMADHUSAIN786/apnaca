import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/barcode_scanner_screen.dart';
import 'printer_service.dart';

class HardwareService {
  HardwareService._internal();
  static final HardwareService instance = HardwareService._internal();

  /// Launch barcode scanner UI if [context] provided, otherwise return stubbed null.
  /// Returns scanned barcode string or null if cancelled.
  Future<String?> scanBarcode({BuildContext? context}) async {
    if (context != null) {
      final result = await Navigator.of(context).push<String?>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      return result;
    }
    // fallback stub
    await Future.delayed(const Duration(milliseconds: 300));
    return null; // stubbed
  }

  /// Stub: print a receipt. Accepts a simple text payload.
  Future<bool> printReceipt(String text) async {
    // Delegate to PrinterService for actual printing (stubbed).
    return await PrinterService.instance.printText(text);
  }

  /// Stub: open cash drawer via printer command or drawer API.
  Future<bool> openCashDrawer() async {
    // Try network printer drawer kick if configured, otherwise fallback to stub.
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('printer_ip');
      final port = prefs.getInt('printer_port') ?? 9100;
      if (ip != null && ip.isNotEmpty) {
        final bytes = PrinterService.instance.escposDrawerKick();
        final ok = await PrinterService.instance.printBytesToNetworkPrinter(ip, port, bytes);
        if (ok) return true;
      }
    } catch (_) {}
    return await PrinterService.instance.kickCashDrawer();
  }
}
