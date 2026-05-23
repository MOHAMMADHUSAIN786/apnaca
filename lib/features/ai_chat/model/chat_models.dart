// ── Chat message ──────────────────────────────────────────────────

class ChatMessage {
  final String role;
  final String content;
  final List<Map<String, dynamic>>? tableData;
  final Map<String, dynamic>? detailCard; // single item/customer detail

  const ChatMessage({
    required this.role,
    required this.content,
    this.tableData,
    this.detailCard,
  });

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ── Action types ──────────────────────────────────────────────────

enum AiActionType {
  // Item actions
  createItem,
  updateItem,
  deleteItem,
  listItems,
  showItemDetail,   // single item detail

  // Customer actions
  createCustomer,
  updateCustomer,
  deleteCustomer,
  listCustomers,
  showCustomerDetail,

  // Flow control
  ask,       // needs one more field
  confirm,   // yes/no confirmation (optional fields prompt)
  clarify,
  error,
}

class ParsedAction {
  final AiActionType type;
  final Map<String, dynamic> data;
  final String reply;
  final String? askField;

  const ParsedAction({
    required this.type,
    required this.data,
    required this.reply,
    this.askField,
  });
}

// ── Action result ─────────────────────────────────────────────────

enum ActionResultType { success, needsInput, needsConfirm, error }

class ActionResult {
  final ActionResultType type;
  final String reply;
  final List<Map<String, dynamic>>? tableData;
  final Map<String, dynamic>? detailCard;
  final int? affectedId;
  final String? askField;

  const ActionResult._({
    required this.type,
    required this.reply,
    this.tableData,
    this.detailCard,
    this.affectedId,
    this.askField,
  });

  factory ActionResult.success({
    required String reply,
    List<Map<String, dynamic>>? tableData,
    Map<String, dynamic>? detailCard,
    int? affectedId,
  }) =>
      ActionResult._(
        type: ActionResultType.success,
        reply: reply,
        tableData: tableData,
        detailCard: detailCard,
        affectedId: affectedId,
      );

  factory ActionResult.needsInput({
    required String question,
    required String field,
  }) =>
      ActionResult._(
        type: ActionResultType.needsInput,
        reply: question,
        askField: field,
      );

  factory ActionResult.error({required String message}) =>
      ActionResult._(type: ActionResultType.error, reply: message);

  bool get hasTable => tableData != null && tableData!.isNotEmpty;
  bool get hasDetail => detailCard != null && detailCard!.isNotEmpty;
}
