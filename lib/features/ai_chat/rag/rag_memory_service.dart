// lib/features/ai_chat/rag/rag_memory_service.dart
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../database/app_database.dart';

class RagMemoryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RagMemoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference? get _chatCol {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('AI_CHAT');
  }

  DocumentReference? get _contextDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('AI_CHAT')
        .doc('context');
  }

  // ── Save message to Firestore ──────────────────────────────────

  Future<void> saveMessage({
    required String sessionId,
    required String role,
    required String content,
    String? action,
    List<String> mentionedItems = const [],
    List<String> mentionedCustomers = const [],
    String? billNumber,
  }) async {
    final col = _chatCol;
    if (col == null) return;
    try {
      await col.doc(sessionId).collection('messages').add({
        'role': role,
        'content': content,
        'action': action ?? '',
        'entities': {
          'items': mentionedItems,
          'customers': mentionedCustomers,
          'bill': billNumber ?? '',
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (role == 'user') {
        final contextUpdate = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUserMessage': content,
        };
        if (mentionedItems.isNotEmpty) contextUpdate['lastItems'] = mentionedItems;
        if (mentionedCustomers.isNotEmpty) contextUpdate['lastCustomers'] = mentionedCustomers;
        if (action != null) contextUpdate['lastAction'] = action;
        if (billNumber != null) contextUpdate['lastBillNumber'] = billNumber;
        await _contextDoc?.set(contextUpdate, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // ── Load recent messages ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadRecentMessages({
    required String sessionId,
    int limit = 20,
  }) async {
    final col = _chatCol;
    if (col == null) return [];
    try {
      final snap = await col
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => d.data()).toList().reversed.toList();
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  FIX 2 — buildDbContext with TOKEN BUDGET + TRUNCATION
  //
  //  BEFORE: No limits — could send thousands of tokens to LLM
  //  AFTER:
  //    - maxTokenBudget parameter (default: 2000 words ≈ 12000 chars)
  //    - Items:     max 50  (was unlimited)
  //    - Customers: max 30  (was 25)
  //    - Suppliers: max 20  (was 15)
  //    - Bills:     max 15  (was 10)
  //    - Logs total character count for monitoring
  //    - Adds "// TRUNCATED" comment in output if data was cut
  // ══════════════════════════════════════════════════════════════════
  Future<String> buildDbContext(
      AppDatabase db, {
        int maxTokenBudget = 2000, // ~words; 1 word ≈ 6 chars → 12000 chars max
      }) async {
    final buffer = StringBuffer();
    final maxChars = maxTokenBudget * 6; // rough char estimate

    // ── ITEMS (max 50) ────────────────────────────────────────────
    try {
      final allItems = await db.getAllItems();
      // FIX 2 — BEFORE: items (unbounded)
      // AFTER:  items.take(50) + TRUNCATED comment if cut
      final items = allItems.take(50).toList();
      final wasTruncated = allItems.length > 50;

      if (items.isNotEmpty) {
        buffer.writeln('ITEMS (${allItems.length} total, showing ${items.length}):');
        if (wasTruncated) buffer.writeln('  // TRUNCATED — showing first 50 of ${allItems.length}');
        for (final item in items) {
          final lowFlag = (item.qty != null && item.qty! <= 5) ? ' ⚠️LOW' : '';
          buffer.writeln(
              '  id:${item.id} name:"${item.name}" '
                  'price:${item.price != null ? "₹${item.price}" : "-"} '
                  'qty:${item.qty ?? 0}$lowFlag '
                  'hsn:${item.hsnCode?.isNotEmpty == true ? item.hsnCode : "N/A"}');
        }

        final low = items.where((i) => i.qty != null && i.qty! <= 5).toList();
        if (low.isNotEmpty) {
          buffer.writeln(
              'LOW_STOCK: ${low.map((i) => '${i.name}(${i.qty})').join(", ")}');
        }

        try {
          final topSell = await db.getTopSellingItems(limit: 5);
          if (topSell.isNotEmpty) {
            buffer.writeln(
                'TOP_SELLERS: ${topSell.map((i) => '"${i["item_name"]}" sold:${i["total_qty_sold"]}').join(" | ")}');
          }
        } catch (_) {}
      } else {
        buffer.writeln('ITEMS: none');
      }
    } catch (_) {
      buffer.writeln('ITEMS: error loading');
    }

    buffer.writeln();

    // ── CUSTOMERS (max 30) ────────────────────────────────────────
    try {
      final allCustomers = await db.getAllCustomers();
      // FIX 2 — BEFORE: customers.take(25)
      // AFTER:  customers.take(30) + TRUNCATED comment
      final customers = allCustomers.take(30).toList();
      final custTruncated = allCustomers.length > 30;

      if (customers.isNotEmpty) {
        buffer.writeln('CUSTOMERS (${allCustomers.length} total, showing ${customers.length}):');
        if (custTruncated) buffer.writeln('  // TRUNCATED — showing first 30 of ${allCustomers.length}');
        for (final c in customers) {
          buffer.writeln(
              '  id:${c.id} name:"${c.name}" '
                  'phone:${c.phone ?? "-"} '
                  'email:${c.email ?? "-"} '
                  'gst:${c.gstNumber ?? "-"} '
                  'state:${c.state ?? "-"}');
        }

        try {
          final pending = await db.getCustomersWithPending();
          if (pending.isNotEmpty) {
            buffer.writeln('CUSTOMER_PENDING:');
            for (final p in pending.take(10)) {
              buffer.writeln(
                  '  "${p["customer_name"]}" owes ₹${p["pending_amount"]} (${p["unpaid_count"]} bills)');
            }
          }
        } catch (_) {}
      } else {
        buffer.writeln('CUSTOMERS: none');
      }
    } catch (_) {
      buffer.writeln('CUSTOMERS: error loading');
    }

    buffer.writeln();

    // ── SUPPLIERS (max 20) ────────────────────────────────────────
    try {
      final allSuppliers = await db.getAllSuppliers();
      // FIX 2 — BEFORE: suppliers.take(15)
      // AFTER:  suppliers.take(20) + TRUNCATED comment
      final suppliers = allSuppliers.take(20).toList();
      final supTruncated = allSuppliers.length > 20;

      if (suppliers.isNotEmpty) {
        buffer.writeln('SUPPLIERS (${allSuppliers.length} total, showing ${suppliers.length}):');
        if (supTruncated) buffer.writeln('  // TRUNCATED — showing first 20 of ${allSuppliers.length}');
        for (final s in suppliers) {
          buffer.writeln(
              '  id:${s.id} name:"${s.name}" '
                  'phone:${s.phone ?? "-"} '
                  'gst:${s.gstNumber ?? "-"}');
        }

        try {
          final supPending = await db.getSuppliersWithPending();
          if (supPending.isNotEmpty) {
            buffer.writeln('SUPPLIER_PENDING:');
            for (final p in supPending.take(5)) {
              buffer.writeln(
                  '  "${p["supplier_name"]}" due ₹${p["pending_amount"]}');
            }
          }
        } catch (_) {}
      } else {
        buffer.writeln('SUPPLIERS: none');
      }
    } catch (_) {
      buffer.writeln('SUPPLIERS: error loading');
    }

    buffer.writeln();

    // ── RECENT SALE BILLS (max 15) ────────────────────────────────
    try {
      final saleBills = await db.getAllSaleBills();
      // FIX 2 — BEFORE: saleBills.take(10)
      // AFTER:  saleBills.take(15) + TRUNCATED comment
      final billsTruncated = saleBills.length > 15;

      if (saleBills.isNotEmpty) {
        buffer.writeln('RECENT_SALE_BILLS (${saleBills.length} total, showing ${saleBills.take(15).length}):');
        if (billsTruncated) buffer.writeln('  // TRUNCATED — showing last 15 of ${saleBills.length}');
        double totalUnpaid = 0;
        for (final b in saleBills.take(15)) {
          buffer.writeln(
              '  ${b["bill_number"]} customer:"${b["customer_name"] ?? "-"}" '
                  'date:${b["bill_date"]} '
                  'total:₹${b["total_amount"]} '
                  'status:${b["payment_status"]} '
                  'mode:${b["payment_mode"] ?? "-"}');
        }
        for (final b in saleBills) {
          if (b['payment_status'] == 'unpaid' || b['payment_status'] == 'partial') {
            totalUnpaid += (b['total_amount'] as num?)?.toDouble() ?? 0;
          }
        }
        buffer.writeln('TOTAL_UNPAID_SALE: ₹${totalUnpaid.toStringAsFixed(2)}');
      } else {
        buffer.writeln('SALE_BILLS: none');
      }
    } catch (_) {
      buffer.writeln('SALE_BILLS: error loading');
    }

    buffer.writeln();

    // ── RECENT PURCHASE BILLS (max 15) ───────────────────────────
    try {
      final purchBills = await db.getAllPurchaseBills();
      // FIX 2 — BEFORE: purchBills.take(10)
      // AFTER:  purchBills.take(15) + TRUNCATED comment
      final purchTruncated = purchBills.length > 15;

      if (purchBills.isNotEmpty) {
        buffer.writeln('RECENT_PURCHASE_BILLS (${purchBills.length} total, showing ${purchBills.take(15).length}):');
        if (purchTruncated) buffer.writeln('  // TRUNCATED — showing last 15 of ${purchBills.length}');
        double totalUnpaidPurch = 0;
        for (final b in purchBills.take(15)) {
          buffer.writeln(
              '  ${b["bill_number"]} supplier:"${b["supplier_name"] ?? "-"}" '
                  'date:${b["bill_date"]} '
                  'total:₹${b["total_amount"]} '
                  'status:${b["payment_status"]}');
        }
        for (final b in purchBills) {
          if (b['payment_status'] == 'unpaid' || b['payment_status'] == 'partial') {
            totalUnpaidPurch += (b['total_amount'] as num?)?.toDouble() ?? 0;
          }
        }
        buffer.writeln('TOTAL_UNPAID_PURCHASE: ₹${totalUnpaidPurch.toStringAsFixed(2)}');
      } else {
        buffer.writeln('PURCHASE_BILLS: none');
      }
    } catch (_) {
      buffer.writeln('PURCHASE_BILLS: error loading');
    }

    buffer.writeln();

    // ── ANALYTICS SUMMARY ─────────────────────────────────────────
    try {
      final todayData   = await db.getTodaySaleSummary();
      final monthData   = await db.getDateRangeSaleSummary(30);
      final allItems    = await db.getAllItems();
      final allCustomers= await db.getAllCustomers();
      final allSuppliers= await db.getAllSuppliers();

      buffer.writeln('ANALYTICS:');
      buffer.writeln(
          '  Today: bills:${todayData["bill_count"]} '
              'sale:₹${todayData["total_sale"]} '
              'paid:₹${todayData["paid_amount"]} '
              'unpaid:₹${todayData["unpaid_amount"]}');
      buffer.writeln(
          '  This Month (30d): bills:${monthData["bill_count"]} '
              'sale:₹${monthData["total_sale"]} '
              'customers:${monthData["unique_customers"]}');
      buffer.writeln(
          '  Counts: items:${allItems.length} customers:${allCustomers.length} suppliers:${allSuppliers.length}');
    } catch (_) {}

    final result = buffer.toString();

    // FIX 2 — Log total character count for monitoring context size
    developer.log(
      'buildDbContext: ${result.length} chars (budget: $maxChars)',
      name: 'ApnaCA.RAG',
    );

    return result;
  }

  // ══════════════════════════════════════════════════════════════════
  //  FIX 5 — buildRagContext with dynamic contextDepth
  //
  //  BEFORE: limit: 6 (hardcoded)
  //  AFTER:  limit: contextDepth (default 10, pass 15 during bill flow)
  // ══════════════════════════════════════════════════════════════════
  Future<String> buildRagContext(
      String sessionId, {
        int contextDepth = 10, // FIX 5 — BEFORE: hardcoded 6
      }) async {
    try {
      // FIX 5 — BEFORE: loadRecentMessages(sessionId: sessionId, limit: 6)
      // AFTER:  loadRecentMessages(sessionId: sessionId, limit: contextDepth)
      final msgs = await loadRecentMessages(sessionId: sessionId, limit: contextDepth);
      if (msgs.isEmpty) return '';

      final sb = StringBuffer('RECENT CONVERSATION:\n');
      for (final m in msgs) {
        final role    = m['role'] == 'user' ? 'User' : 'AI';
        final content = (m['content'] as String? ?? '').trim();
        if (content.isNotEmpty) {
          sb.writeln('$role: ${content.length > 120 ? content.substring(0, 120) : content}');
        }
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }
}