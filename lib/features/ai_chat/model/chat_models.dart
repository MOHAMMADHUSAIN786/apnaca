import 'bill_creation_state.dart';

class ChatMessage {
  final String role;
  final String content;
  final List<Map<String, dynamic>>? tableData;
  final Map<String, dynamic>? detailCard;
  final bool isCustomerNotFound;
  final StockIssue? stockIssue;
  final bool isSubscriptionRequired;

  const ChatMessage({
    required this.role,
    required this.content,
    this.tableData,
    this.detailCard,
    this.isCustomerNotFound = false,
    this.stockIssue,
    this.isSubscriptionRequired = false,
  });

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class StockIssue {
  final StockIssueType type;
  final String itemName;
  final int requested;
  final int available;

  const StockIssue({
    required this.type,
    required this.itemName,
    this.requested = 0,
    this.available = 0,
  });
}

enum StockIssueType { zero, insufficient }

enum AiActionType {
  // Items
  createItem, updateItem, deleteItem, listItems, showItemDetail, showItemTransactions,
  // Customers
  createCustomer, updateCustomer, deleteCustomer, listCustomers, showCustomerDetail,
  // Suppliers
  createSupplier, updateSupplier, deleteSupplier, listSuppliers, showSupplierDetail,
  // Sale Bills
  createSaleBill, listSaleBills, showSaleBillDetail, updateSaleBillStatus,
  // Purchase Bills
  createPurchaseBill, listPurchaseBills, showPurchaseBillDetail, updatePurchaseBillStatus,
  // Analytics
  getAnalytics,
  // Flow
  ask, confirm, clarify, error,
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

enum ActionResultType {
  success,
  needsInput,
  startBillFlow,
  customerNotFound,
  supplierNotFound,
  stockInsufficient,
  stockZero,
  subscriptionRequired,
  error,
}

class ActionResult {
  final ActionResultType type;
  final String reply;
  final List<Map<String, dynamic>>? tableData;
  final Map<String, dynamic>? detailCard;
  final int? affectedId;
  final String? askField;
  final String? searchedCustomerName;
  final String? searchedSupplierName;
  final BillCreationState? initialBillState;
  final StockIssue? stockIssue;

  const ActionResult._({
    required this.type,
    required this.reply,
    this.tableData,
    this.detailCard,
    this.affectedId,
    this.askField,
    this.searchedCustomerName,
    this.searchedSupplierName,
    this.initialBillState,
    this.stockIssue,
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

  factory ActionResult.startBillFlow({
    required String customerName,
    required List<Map<String, dynamic>> items,
    String? discountType,
    double? discountValue,
    String? taxType,
    double? taxRate,
    String? paymentMode,
    String? paymentStatus,
  }) {
    final hasItems = items.isNotEmpty;

    // Determine starting step — skip what AI already provided
    BillStep initialStep;
    if (!hasItems) {
      initialStep = BillStep.collectingItems;
    } else if (discountType == null) {
      // AI didn't specify discount → ask user
      initialStep = BillStep.askingDiscount;
    } else if (taxType == null && taxRate == null) {
      // Discount known, tax not → ask tax
      initialStep = BillStep.askingTax;
    } else if (paymentMode == null) {
      // Tax known, payment not → ask payment
      initialStep = BillStep.askingPayment;
    } else {
      // Everything provided → ready to create immediately
      initialStep = BillStep.ready;
    }

    return ActionResult._(
      type: ActionResultType.startBillFlow,
      reply: initialStep == BillStep.ready
          ? 'Bill bana raha hoon...'
          : initialStep == BillStep.collectingItems
              ? 'Kaunsa item aur kitni quantity?\n(Example: apple 5, mango 10)'
              : initialStep == BillStep.askingDiscount
                  ? 'Koi discount dena hai? (haan / nahi)'
                  : initialStep == BillStep.askingTax
                      ? 'Tax type aur rate? (e.g. exclusive 18% / no tax)'
                      : 'Payment kaise? (Cash / UPI / Udhaar)',
      initialBillState: BillCreationState(
        customerName: customerName,
        items: items,
        discountType:  discountType  ?? 'none',
        discountValue: discountValue ?? 0.0,
        taxType:       taxType       ?? 'exclusive',
        taxRate:       taxRate       ?? 0.0,
        paymentMode:   paymentMode,
        paymentStatus: paymentStatus,
        step:          initialStep,
      ),
    );
  }

  factory ActionResult.customerNotFound({
    required String searchedName,
    required List<Map<String, dynamic>> customers,
  }) =>
      ActionResult._(
        type: ActionResultType.customerNotFound,
        reply: customers.isEmpty
            ? '"$searchedName" naam ka customer nahi mila. Pehle customer add karein.'
            : '"$searchedName" naam ka customer nahi mila. Yeh rahe aapke customers:',
        tableData: customers,
        searchedCustomerName: searchedName,
      );

  factory ActionResult.supplierNotFound({
    required String searchedName,
    required List<Map<String, dynamic>> suppliers,
  }) =>
      ActionResult._(
        type: ActionResultType.supplierNotFound,
        reply: suppliers.isEmpty
            ? '"$searchedName" naam ka supplier nahi mila. Pehle supplier add karein.'
            : '"$searchedName" naam ka supplier nahi mila. Yeh rahe aapke suppliers:',
        tableData: suppliers,
        searchedSupplierName: searchedName,
      );

  factory ActionResult.stockZero({required List<String> itemNames}) =>
      ActionResult._(
        type: ActionResultType.stockZero,
        reply: '⚠️ ${itemNames.join(", ")} ka stock 0 hai.\n\nKya aap:\n1️⃣  Stock badhana chahte hain?\n2️⃣  Koi aur item choose karna chahte hain?',
        stockIssue: StockIssue(
          type: StockIssueType.zero,
          itemName: itemNames.first,
          available: 0,
        ),
      );

  factory ActionResult.stockInsufficient({
    required String itemName,
    required int requested,
    required int available,
  }) =>
      ActionResult._(
        type: ActionResultType.stockInsufficient,
        reply: '⚠️ $itemName ka stock sirf $available hai, aap $requested maang rahe hain.\n\nKya aap:\n1️⃣  Stock badhana chahte hain?\n2️⃣  Sirf $available piece ka bill banana chahte hain?\n3️⃣  Koi aur item?',
        stockIssue: StockIssue(
          type: StockIssueType.insufficient,
          itemName: itemName,
          requested: requested,
          available: available,
        ),
      );

  factory ActionResult.subscriptionRequired() =>
      ActionResult._(
        type: ActionResultType.subscriptionRequired,
        reply: '🔒 Aapki free limit (10 bills) khatam ho gayi hai. Unlimited bills ke liye upgrade karo!',
      );

  factory ActionResult.error({required String message}) =>
      ActionResult._(type: ActionResultType.error, reply: message);

  bool get hasTable => tableData != null && tableData!.isNotEmpty;
  bool get hasDetail => detailCard != null && detailCard!.isNotEmpty;
  bool get isCustomerNotFound => type == ActionResultType.customerNotFound;
  bool get isSupplierNotFound => type == ActionResultType.supplierNotFound;
  bool get hasStockIssue =>
      type == ActionResultType.stockZero || type == ActionResultType.stockInsufficient;
  bool get isSubscriptionRequired => type == ActionResultType.subscriptionRequired;
}
