import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:apnaca/core/services/printer_service.dart';

void main() {
  test('printBytesToNetworkPrinter sends bytes to TCP server', () async {
    // Start a local TCP server on loopback with ephemeral port
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

    final completer = Completer<List<int>>();

    server.listen((Socket client) {
      final buffer = <int>[];
      client.listen((data) {
        buffer.addAll(data);
      }, onDone: () {
        if (!completer.isCompleted) completer.complete(buffer);
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e!);
      });
    });

    final bytesToSend = <int>[0x1B, 0x40, 0x41, 0x42, 0x43]; // ESC @ + 'ABC'

    final sent = await PrinterService.instance.printBytesToNetworkPrinter(
      server.address.address,
      server.port,
      bytesToSend,
      timeout: const Duration(seconds: 2),
    );

    expect(sent, isTrue);

    final received = await completer.future.timeout(const Duration(seconds: 5));
    expect(received, equals(bytesToSend));

    await server.close();
  });
}
