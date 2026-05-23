import '../../../database/app_database.dart';
import '../../customer/model/customer_model.dart';
import '../../item/model/item_model.dart';
import '../model/chat_models.dart';

class ActionExecutor {
  final AppDatabase _db;
  ActionExecutor({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<ActionResult> execute(ParsedAction action) async {
    switch (action.type) {

      // ════════════════════════════════════════════════════
      //  ITEM ACTIONS
      // ════════════════════════════════════════════════════

      case AiActionType.createItem:
        final data = action.data;
        final name = (data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) {
          return ActionResult.needsInput(question: 'Item ka naam kya hai?', field: 'name');
        }
        final item = ItemModel(
          name: name,
          qty: _toInt(data['qty']),
          price: _toDouble(data['price']),
          hsnCode: data['hsn_code'] as String?,
        );
        final id = await _db.insertItem(item);
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.updateItem:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa item? ID ya naam batao.');
        final existing = await _db.getItemById(id);
        if (existing == null) return ActionResult.error(message: 'Item id:$id nahi mila.');
        await _db.updateItem(existing.copyWith(
          name: action.data['name'] as String?,
          qty: _toInt(action.data['qty']),
          price: _toDouble(action.data['price']),
          hsnCode: action.data['hsn_code'] as String?,
        ));
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.deleteItem:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa item delete karna hai?');
        await _db.deleteItem(id);
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.listItems:
        final items = await _db.getAllItems();
        if (items.isEmpty) return ActionResult.success(reply: 'Koi item nahi hai abhi.', tableData: []);
        return ActionResult.success(
          reply: action.reply,
          tableData: items.map((i) => {
            'id': i.id,
            'name': i.name,
            'qty': i.qty?.toString() ?? '-',
            'price': i.price != null ? '₹${i.price}' : '-',
            'hsn_code': i.hsnCode ?? '-',
          }).toList(),
        );

      case AiActionType.showItemDetail:
        // AI sends either id or name
        final id = _extractId(action.data);
        final name = action.data['name'] as String?;
        ItemModel? item;
        if (id != null) {
          item = await _db.getItemById(id);
        } else if (name != null) {
          item = await _db.getItemByName(name);
        }
        if (item == null) return ActionResult.error(message: 'Item nahi mila.');
        return ActionResult.success(
          reply: action.reply,
          detailCard: {
            'type': 'item',
            'ID': item.id.toString(),
            'Name': item.name,
            'Qty': item.qty?.toString() ?? '-',
            'Price': item.price != null ? '₹${item.price}' : '-',
            'HSN Code': item.hsnCode ?? '-',
          },
        );

      // ════════════════════════════════════════════════════
      //  CUSTOMER ACTIONS
      // ════════════════════════════════════════════════════

      case AiActionType.createCustomer:
        final name = (action.data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) {
          return ActionResult.needsInput(question: 'Customer ka naam kya hai?', field: 'name');
        }
        final customer = CustomerModel(
          name: name,
          email: action.data['email'] as String?,
          phone: action.data['phone'] as String?,
          address: action.data['address'] as String?,
          gstNumber: action.data['gst_number'] as String?,
          state: action.data['state'] as String?,
        );
        final id = await _db.insertCustomer(customer);
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.updateCustomer:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa customer? ID ya naam batao.');
        final existing = await _db.getCustomerById(id);
        if (existing == null) return ActionResult.error(message: 'Customer id:$id nahi mila.');
        await _db.updateCustomer(existing.copyWith(
          name: action.data['name'] as String?,
          email: action.data['email'] as String?,
          phone: action.data['phone'] as String?,
          address: action.data['address'] as String?,
          gstNumber: action.data['gst_number'] as String?,
          state: action.data['state'] as String?,
        ));
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.deleteCustomer:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa customer delete karna hai?');
        await _db.deleteCustomer(id);
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.listCustomers:
        final customers = await _db.getAllCustomers();
        if (customers.isEmpty) return ActionResult.success(reply: 'Koi customer nahi hai abhi.', tableData: []);
        return ActionResult.success(
          reply: action.reply,
          tableData: customers.map((c) => {
            'id': c.id,
            'name': c.name,
            'phone': c.phone ?? '-',
            'gst_number': c.gstNumber ?? '-',
            'state': c.state ?? '-',
          }).toList(),
        );

      case AiActionType.showCustomerDetail:
        final id = _extractId(action.data);
        final name = action.data['name'] as String?;
        CustomerModel? customer;
        if (id != null) {
          customer = await _db.getCustomerById(id);
        } else if (name != null) {
          customer = await _db.getCustomerByName(name);
        }
        if (customer == null) return ActionResult.error(message: 'Customer nahi mila.');
        return ActionResult.success(
          reply: action.reply,
          detailCard: {
            'type': 'customer',
            'ID': customer.id.toString(),
            'Name': customer.name,
            'Phone': customer.phone ?? '-',
            'Email': customer.email ?? '-',
            'GST': customer.gstNumber ?? '-',
            'State': customer.state ?? '-',
            'Address': customer.address ?? '-',
          },
        );

      // ════════════════════════════════════════════════════
      //  FLOW CONTROL
      // ════════════════════════════════════════════════════

      case AiActionType.ask:
        return ActionResult.needsInput(
          question: action.reply,
          field: action.askField ?? 'unknown',
        );

      case AiActionType.confirm:
        // AI is confirming optional fields — just show the message
        return ActionResult.success(reply: action.reply);

      case AiActionType.clarify:
      case AiActionType.error:
        return ActionResult.error(message: action.reply);
    }
  }

  // ── Helpers ─────────────────────────────────────────────

  int? _extractId(Map<String, dynamic> data) {
    final raw = data['id'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
