import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// RAG (Retrieval Augmented Generation) Memory Service
///
/// Firestore structure:
/// /users/{uid}/AI_CHAT/{sessionId}/messages/{msgId}
///   - role: 'user' | 'assistant'
///   - content: string
///   - action: string (what AI did)
///   - entities: {items:[], customers:[], bills:[]} (extracted entities)
///   - timestamp: serverTimestamp
///
/// /users/{uid}/AI_CHAT/context (single doc — running context summary)
///   - lastItems: [] recently mentioned items
///   - lastCustomers: [] recently mentioned customers
///   - lastBillNumber: string
///   - lastAction: string
///   - updatedAt: timestamp

class RagMemoryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RagMemoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Collection references ─────────────────────────────────────

  CollectionReference? get _chatCol {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('AI_CHAT');
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

  // ── Save message to Firestore ─────────────────────────────────

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
      // Save individual message
      await col
          .doc(sessionId)
          .collection('messages')
          .add({
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

      // Update running context doc
      if (role == 'user') {
        final contextUpdate = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUserMessage': content,
        };
        if (mentionedItems.isNotEmpty) {
          contextUpdate['lastItems'] = mentionedItems;
        }
        if (mentionedCustomers.isNotEmpty) {
          contextUpdate['lastCustomers'] = mentionedCustomers;
        }
        if (action != null) contextUpdate['lastAction'] = action;
        if (billNumber != null) contextUpdate['lastBillNumber'] = billNumber;

        await _contextDoc?.set(contextUpdate, SetOptions(merge: true));
      }
    } catch (_) {
      // Silent fail — logging should never break the app
    }
  }

  // ── Load last N messages for a session ───────────────────────

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

      return snap.docs
          .map((d) => d.data())
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Load running context (last known entities) ───────────────

  Future<RagContext> loadContext() async {
    try {
      final doc = await _contextDoc?.get();
      if (doc == null || !doc.exists) return RagContext.empty();
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return RagContext.empty();

      return RagContext(
        lastItems: List<String>.from(data['lastItems'] ?? []),
        lastCustomers: List<String>.from(data['lastCustomers'] ?? []),
        lastBillNumber: data['lastBillNumber'] as String? ?? '',
        lastAction: data['lastAction'] as String? ?? '',
        lastUserMessage: data['lastUserMessage'] as String? ?? '',
      );
    } catch (_) {
      return RagContext.empty();
    }
  }

  // ── Build RAG context string for injection into prompt ───────

  Future<String> buildRagContextString({
    required String sessionId,
  }) async {
    final ctx = await loadContext();
    final recentMsgs = await loadRecentMessages(
        sessionId: sessionId, limit: 10);

    final buffer = StringBuffer();
    buffer.writeln('══ MEMORY & CONTEXT ══');

    if (ctx.lastCustomers.isNotEmpty) {
      buffer.writeln(
          'Last mentioned customers: ${ctx.lastCustomers.join(", ")}');
    }
    if (ctx.lastItems.isNotEmpty) {
      buffer
          .writeln('Last mentioned items: ${ctx.lastItems.join(", ")}');
    }
    if (ctx.lastBillNumber.isNotEmpty) {
      buffer.writeln('Last bill number: ${ctx.lastBillNumber}');
    }
    if (ctx.lastAction.isNotEmpty) {
      buffer.writeln('Last action performed: ${ctx.lastAction}');
    }

    if (recentMsgs.isNotEmpty) {
      buffer.writeln('\n══ RECENT CONVERSATION (last 10) ══');
      for (final msg in recentMsgs) {
        final role = msg['role'] == 'user' ? 'User' : 'AI';
        buffer.writeln('$role: ${msg['content']}');
      }
    }

    return buffer.toString();
  }

  // ── Extract entities from user message ───────────────────────

  static EntityExtraction extractEntities(
      String message, List<String> knownItems, List<String> knownCustomers) {
    final lower = message.toLowerCase();

    final mentionedItems = knownItems
        .where((item) => lower.contains(item.toLowerCase()))
        .toList();

    final mentionedCustomers = knownCustomers
        .where((c) => lower.contains(c.toLowerCase()))
        .toList();

    return EntityExtraction(
      items: mentionedItems,
      customers: mentionedCustomers,
    );
  }

  // ── Delete session (on clear chat) ────────────────────────────

  Future<void> clearSession(String sessionId) async {
    try {
      final col = _chatCol;
      if (col == null) return;
      // Delete all messages in session
      final msgs = await col
          .doc(sessionId)
          .collection('messages')
          .get();
      for (final doc in msgs.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }
}

// ── Data classes ──────────────────────────────────────────────────

class RagContext {
  final List<String> lastItems;
  final List<String> lastCustomers;
  final String lastBillNumber;
  final String lastAction;
  final String lastUserMessage;

  const RagContext({
    required this.lastItems,
    required this.lastCustomers,
    required this.lastBillNumber,
    required this.lastAction,
    required this.lastUserMessage,
  });

  factory RagContext.empty() => const RagContext(
    lastItems: [],
    lastCustomers: [],
    lastBillNumber: '',
    lastAction: '',
    lastUserMessage: '',
  );
}

class EntityExtraction {
  final List<String> items;
  final List<String> customers;
  const EntityExtraction({required this.items, required this.customers});
}
