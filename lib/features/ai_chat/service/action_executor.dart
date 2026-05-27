import '../../../database/app_database.dart';
import '../../customer/model/customer_model.dart';
import '../../item/model/item_model.dart';
import '../../supplier/model/supplier_model.dart';
import '../../subscription/service/subscription_service.dart';
import '../model/bill_creation_state.dart';
import '../model/chat_models.dart';

class ActionExecutor {
  final AppDatabase _db;
  ActionExecutor({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<ActionResult> execute(ParsedAction action) async {
    switch (action.type) {

    // ══════════════════════════════════════════════════════
    //  ITEMS
    // ══════════════════════════════════════════════════════

      case AiActionType.createItem:
        final name = (action.data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) {
          return ActionResult.needsInput(question: 'Item ka naam kya rakha jaaye?', field: 'name');
        }
        final qty = _toInt(action.data['qty']);
        if (qty != null && qty < 0) {
          return ActionResult.error(message: '⚠️ Quantity negative nahi ho sakti. Sahi quantity batao.');
        }
        final price = _toDouble(action.data['price']);
        if (price != null && price <= 0) {
          return ActionResult.error(message: '⚠️ Price 0 ya negative nahi ho sakti. Sahi price batao.');
        }
        if (await _db.itemNameExists(name)) {
          return ActionResult.error(message: '⚠️ "$name" item pehle se exist karta hai. Update karna hai?');
        }
        if (qty == null) {
          return ActionResult.needsInput(question: '"$name" ki quantity kitni hai?', field: 'qty');
        }
        if (price == null) {
          return ActionResult.needsInput(question: '"$name" ki price kya hai?', field: 'price');
        }
        final id = await _db.insertItem(ItemModel(
          name: name, qty: qty, price: price,
          hsnCode: action.data['hsn_code'] as String?,
        ));
        return ActionResult.success(reply: action.reply, affectedId: id);

      case AiActionType.updateItem:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa item update karna hai? Naam batao.');
        final existing = await _db.getItemById(id);
        if (existing == null) return ActionResult.error(message: 'Item nahi mila.');
        final newQty = _toInt(action.data['qty']);
        if (newQty != null && newQty < 0) {
          return ActionResult.error(message: '⚠️ Quantity negative nahi ho sakti.');
        }
        final newPrice = _toDouble(action.data['price']);
        if (newPrice != null && newPrice <= 0) {
          return ActionResult.error(message: '⚠️ Price 0 ya negative nahi ho sakti.');
        }
        await _db.updateItem(existing.copyWith(
          name: action.data['name'] as String?,
          qty: newQty,
          price: newPrice,
          hsnCode: action.data['hsn_code'] as String?,
        ));
        return ActionResult.success(reply: action.reply);

      case AiActionType.deleteItem:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa item delete karna hai?');
        await _db.deleteItem(id);
        return ActionResult.success(reply: action.reply);

      case AiActionType.listItems:
        final items = await _db.getAllItems();
        if (items.isEmpty) return ActionResult.success(reply: 'Koi item nahi hai abhi.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${items.length} items:',
          tableData: items.map((i) => {
            'Name': i.name,
            'Stock': i.qty?.toString() ?? '-',
            'Price': i.price != null ? '₹${i.price}' : '-',
          }).toList(),
        );

      case AiActionType.showItemDetail:
        final name = action.data['name'] as String?;
        final id = _extractId(action.data);
        ItemModel? item;
        if (id != null) item = await _db.getItemById(id);
        else if (name != null) item = await _db.getItemByName(name) ?? await _db.getItemFuzzy(name);
        if (item == null) return ActionResult.error(message: 'Item nahi mila.');
        return ActionResult.success(reply: action.reply, detailCard: {
          'type': 'item',
          'Name': item.name,
          'Stock': item.qty?.toString() ?? '-',
          'Price': item.price != null ? '₹${item.price}' : '-',
          'HSN': item.hsnCode ?? '-',
        });

      case AiActionType.showItemTransactions:
        final name = action.data['name'] as String?;
        if (name == null || name.isEmpty) return ActionResult.error(message: 'Konsa item ka transaction dekhna hai?');
        final txns = await _db.getItemTransactions(name);
        if (txns.isEmpty) {
          return ActionResult.success(reply: '"$name" ka koi transaction nahi mila abhi.', tableData: []);
        }
        final totalSold = txns.fold<int>(0, (s, t) => s + ((t['qty'] as int?) ?? 0));
        final totalRevenue = txns.fold<double>(0, (s, t) => s + ((t['line_total'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(
          reply: '"$name" — ${txns.length} transactions | Sold: $totalSold units | Revenue: ₹${totalRevenue.toStringAsFixed(2)}',
          tableData: txns.map((t) => {
            'Bill': t['bill_number']?.toString() ?? '-',
            'Customer': t['customer_name']?.toString() ?? '-',
            'Date': t['bill_date']?.toString() ?? '-',
            'Qty': t['qty']?.toString() ?? '-',
            'Price': '₹${t['unit_price']}',
            'Total': '₹${t['line_total']}',
            'Status': t['payment_status']?.toString() ?? '-',
          }).toList(),
        );

    // ══════════════════════════════════════════════════════
    //  CUSTOMERS
    // ══════════════════════════════════════════════════════

      case AiActionType.createCustomer:
        final name = (action.data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return ActionResult.needsInput(question: 'Customer ka naam?', field: 'name');
        if (await _db.customerNameExists(name)) {
          return ActionResult.error(message: '⚠️ "$name" customer pehle se exist karta hai.');
        }
        final phone = action.data['phone'] as String?;
        if (phone != null && phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
          return ActionResult.error(message: '⚠️ Phone number 10 digits ka hona chahiye. "$phone" galat hai.');
        }
        final cId = await _db.insertCustomer(CustomerModel(
          name: name,
          email: action.data['email'] as String?,
          phone: phone,
          address: action.data['address'] as String?,
          gstNumber: action.data['gst_number'] as String?,
          state: action.data['state'] as String?,
        ));
        return ActionResult.success(reply: action.reply, affectedId: cId);

      case AiActionType.updateCustomer:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa customer update karna hai?');
        final existing = await _db.getCustomerById(id);
        if (existing == null) return ActionResult.error(message: 'Customer nahi mila.');
        final phone = action.data['phone'] as String?;
        if (phone != null && phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
          return ActionResult.error(message: '⚠️ Phone number 10 digits ka hona chahiye.');
        }
        await _db.updateCustomer(existing.copyWith(
          name: action.data['name'] as String?,
          email: action.data['email'] as String?,
          phone: phone,
          address: action.data['address'] as String?,
          gstNumber: action.data['gst_number'] as String?,
          state: action.data['state'] as String?,
        ));
        return ActionResult.success(reply: action.reply);

      case AiActionType.deleteCustomer:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa customer delete karna hai?');
        await _db.deleteCustomer(id);
        return ActionResult.success(reply: action.reply);

      case AiActionType.listCustomers:
        final customers = await _db.getAllCustomers();
        if (customers.isEmpty) return ActionResult.success(reply: 'Koi customer nahi hai.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${customers.length} customers:',
          tableData: customers.map((c) => {
            'Name': c.name,
            'Phone': c.phone ?? '-',
            'GST': c.gstNumber ?? '-',
            'State': c.state ?? '-',
          }).toList(),
        );

      case AiActionType.showCustomerDetail:
        final name = action.data['name'] as String?;
        final id = _extractId(action.data);
        CustomerModel? customer;
        if (id != null) customer = await _db.getCustomerById(id);
        else if (name != null) customer = await _db.getCustomerByName(name) ?? await _db.getCustomerFuzzy(name);
        if (customer == null) return ActionResult.error(message: 'Customer nahi mila.');
        return ActionResult.success(reply: action.reply, detailCard: {
          'type': 'customer',
          'Name': customer.name,
          'Phone': customer.phone ?? '-',
          'Email': customer.email ?? '-',
          'GST': customer.gstNumber ?? '-',
          'State': customer.state ?? '-',
          'Address': customer.address ?? '-',
        });

    // ══════════════════════════════════════════════════════
    //  SUPPLIERS
    // ══════════════════════════════════════════════════════

      case AiActionType.createSupplier:
        final name = (action.data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return ActionResult.needsInput(question: 'Supplier ka naam?', field: 'name');
        if (await _db.supplierNameExists(name)) {
          return ActionResult.error(message: '⚠️ "$name" supplier pehle se exist karta hai.');
        }
        final phone = action.data['phone'] as String?;
        if (phone != null && phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
          return ActionResult.error(message: '⚠️ Phone number 10 digits ka hona chahiye.');
        }
        final sId = await _db.insertSupplier(SupplierModel(
          name: name,
          email: action.data['email'] as String?,
          phone: phone,
          address: action.data['address'] as String?,
          gstNumber: action.data['gst_number'] as String?,
          state: action.data['state'] as String?,
        ));
        return ActionResult.success(reply: action.reply, affectedId: sId);

      case AiActionType.updateSupplier:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa supplier update karna hai?');
        final existing = await _db.getSupplierById(id);
        if (existing == null) return ActionResult.error(message: 'Supplier nahi mila.');
        await _db.updateSupplier(existing.copyWith(
          name: action.data['name'] as String?,
          email: action.data['email'] as String?,
          phone: action.data['phone'] as String?,
          address: action.data['address'] as String?,
          gstNumber: action.data['gst_number'] as String?,
          state: action.data['state'] as String?,
        ));
        return ActionResult.success(reply: action.reply);

      case AiActionType.deleteSupplier:
        final id = _extractId(action.data);
        if (id == null) return ActionResult.error(message: 'Konsa supplier delete karna hai?');
        await _db.deleteSupplier(id);
        return ActionResult.success(reply: action.reply);

      case AiActionType.listSuppliers:
        final suppliers = await _db.getAllSuppliers();
        if (suppliers.isEmpty) return ActionResult.success(reply: 'Koi supplier nahi hai.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${suppliers.length} suppliers:',
          tableData: suppliers.map((s) => {
            'Name': s.name,
            'Phone': s.phone ?? '-',
            'GST': s.gstNumber ?? '-',
            'State': s.state ?? '-',
          }).toList(),
        );

      case AiActionType.showSupplierDetail:
        final name = action.data['name'] as String?;
        final id = _extractId(action.data);
        SupplierModel? supplier;
        if (id != null) supplier = await _db.getSupplierById(id);
        else if (name != null) supplier = await _db.getSupplierByName(name) ?? await _db.getSupplierFuzzy(name);
        if (supplier == null) return ActionResult.error(message: 'Supplier nahi mila.');
        return ActionResult.success(reply: action.reply, detailCard: {
          'type': 'supplier',
          'Name': supplier.name,
          'Phone': supplier.phone ?? '-',
          'Email': supplier.email ?? '-',
          'GST': supplier.gstNumber ?? '-',
          'State': supplier.state ?? '-',
          'Address': supplier.address ?? '-',
        });

    // ══════════════════════════════════════════════════════
    //  SALE BILLS
    // ══════════════════════════════════════════════════════

      case AiActionType.createSaleBill:
        return await _initiateBillFlow(action);

      case AiActionType.listSaleBills:
        var bills = await _db.getAllSaleBills();
        final f = action.data;
        if (f['customer_name'] != null) {
          final cn = (f['customer_name'] as String).toLowerCase();
          bills = bills.where((b) =>
              (b['customer_name'] as String? ?? '').toLowerCase().contains(cn)).toList();
        }
        if (f['status_filter'] != null) {
          bills = bills.where((b) => b['payment_status'] == f['status_filter']).toList();
        }
        if (bills.isEmpty) return ActionResult.success(reply: 'Koi bill nahi mila.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${bills.length} bills:',
          tableData: bills.map((b) => {
            'Bill No': b['bill_number'],
            'Customer': b['customer_name'] ?? '-',
            'Date': b['bill_date'],
            'Total': '₹${b['total_amount']}',
            'Status': b['payment_status'],
          }).toList(),
        );

      case AiActionType.showSaleBillDetail:
        final billNumber = action.data['bill_number'] as String?;
        final billId = _extractId(action.data);
        final bill = billNumber != null
            ? await _db.getSaleBillByNumber(billNumber)
            : billId != null ? await _db.getSaleBillById(billId) : null;
        if (bill == null) return ActionResult.error(message: 'Bill nahi mila.');
        final lineItems = await _db.getSaleBillItems(bill['id'] as int);
        final discountAmt = (bill['discount_amount'] as num?)?.toDouble() ?? 0;
        return ActionResult.success(
          reply: action.reply,
          detailCard: {
            'type': 'sale_bill',
            'bill_id': bill['id'],
            'Bill No': bill['bill_number'],
            'Customer': bill['customer_name'] ?? '-',
            'Date': bill['bill_date'],
            'Tax Type': bill['tax_type'] ?? 'exclusive',
            'Subtotal': '₹${bill['subtotal']}',
            if (discountAmt > 0) 'Discount': '-₹$discountAmt',
            'GST': '₹${bill['gst_amount']}',
            'Total': '₹${bill['total_amount']}',
            'Payment': bill['payment_mode'] ?? '-',
            'Status': bill['payment_status'] ?? '-',
            if (bill['notes'] != null && bill['notes'].toString().isNotEmpty) 'Notes': bill['notes'],
          },
          tableData: lineItems.map((i) => {
            'Item': i['item_name'],
            'Qty': i['qty'].toString(),
            'Price': '₹${i['unit_price']}',
            'Tax': '${i['tax_rate']}%',
            'Total': '₹${i['line_total']}',
          }).toList(),
        );

      case AiActionType.updateSaleBillStatus:
        final billNumber = action.data['bill_number'] as String?;
        final status = action.data['payment_status'] as String?;
        if (status == null) return ActionResult.error(message: 'Status missing (paid/unpaid/partial).');
        int? billId = _extractId(action.data);
        if (billId == null && billNumber != null) {
          final bill = await _db.getSaleBillByNumber(billNumber);
          billId = bill?['id'] as int?;
        }
        if (billId == null) return ActionResult.error(message: 'Bill nahi mila. Bill number batao.');
        await _db.updateSaleBillStatus(billId, status);
        final emoji = status == 'paid' ? '✅' : status == 'partial' ? '🔄' : '⏳';
        return ActionResult.success(
            reply: '$emoji Bill ${billNumber ?? ''} $status mark ho gaya!');

    // ══════════════════════════════════════════════════════
    //  PURCHASE BILLS
    // ══════════════════════════════════════════════════════

      case AiActionType.createPurchaseBill:
        return await _initiatePurchaseBillFlow(action);

      case AiActionType.listPurchaseBills:
        final bills = await _db.getAllPurchaseBills();
        if (bills.isEmpty) return ActionResult.success(reply: 'Koi purchase bill nahi.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${bills.length} purchase bills:',
          tableData: bills.map((b) => {
            'Bill No': b['bill_number'],
            'Supplier': b['supplier_name'] ?? '-',
            'Date': b['bill_date'],
            'Total': '₹${b['total_amount']}',
            'Status': b['payment_status'],
          }).toList(),
        );

      case AiActionType.showPurchaseBillDetail:
        final billNumber = action.data['bill_number'] as String?;
        if (billNumber == null) return ActionResult.error(message: 'Purchase bill number batao.');
        final bill = await _db.getPurchaseBillByNumber(billNumber);
        if (bill == null) return ActionResult.error(message: 'Purchase bill nahi mila.');
        final lineItems = await _db.getPurchaseBillItems(bill['id'] as int);
        return ActionResult.success(
          reply: action.reply,
          detailCard: {
            'type': 'purchase_bill',
            'bill_id': bill['id'],
            'Bill No': bill['bill_number'],
            'Supplier': bill['supplier_name'] ?? '-',
            'Date': bill['bill_date'],
            'Subtotal': '₹${bill['subtotal']}',
            'GST': '₹${bill['tax_amount']}',
            'Total': '₹${bill['total_amount']}',
            'Payment': bill['payment_mode'] ?? '-',
            'Status': bill['payment_status'] ?? '-',
          },
          tableData: lineItems.map((i) => {
            'Item': i['item_name'],
            'Qty': i['qty'].toString(),
            'Price': '₹${i['unit_price']}',
            'Tax': '${i['tax_rate']}%',
            'Total': '₹${i['line_total']}',
          }).toList(),
        );

      case AiActionType.updatePurchaseBillStatus:
        final billNumber = action.data['bill_number'] as String?;
        final status = action.data['payment_status'] as String?;
        if (status == null) return ActionResult.error(message: 'Status missing (paid/unpaid/partial).');
        if (billNumber == null) return ActionResult.error(message: 'Purchase bill number batao.');
        final bill = await _db.getPurchaseBillByNumber(billNumber);
        if (bill == null) return ActionResult.error(message: 'Purchase bill nahi mila.');
        final billId = bill['id'] as int;
        await _db.updatePurchaseBillStatus(billId, status);
        final emoji = status == 'paid' ? '✅' : status == 'partial' ? '🔄' : '⏳';
        return ActionResult.success(
            reply: '$emoji Purchase Bill $billNumber $status mark ho gaya!');

    // ══════════════════════════════════════════════════════
    //  ANALYTICS
    // ══════════════════════════════════════════════════════

      case AiActionType.getAnalytics:
        return await _handleAnalytics(action.data['period'] as String? ?? 'today', action.reply);

    // ══════════════════════════════════════════════════════
    //  FLOW
    // ══════════════════════════════════════════════════════

      case AiActionType.ask:
        return ActionResult.needsInput(question: action.reply, field: action.askField ?? '');

      case AiActionType.confirm:
        return ActionResult.success(reply: action.reply);

      case AiActionType.clarify:
      case AiActionType.error:
        return ActionResult.error(message: action.reply);
    }
  }

  // ── Analytics handler ─────────────────────────────────────────────

  Future<ActionResult> _handleAnalytics(String period, String aiReply) async {
    switch (period) {
      case 'today':
        final data = await _db.getTodaySaleSummary();
        final count = data['bill_count'] ?? 0;
        final total = data['total_sale'] ?? 0;
        final paid = data['paid_amount'] ?? 0;
        final unpaid = data['unpaid_amount'] ?? 0;
        final label = aiReply.isNotEmpty ? aiReply : '📊 Aaj ki sale:';
        if ((count as int) == 0) {
          return ActionResult.success(reply: '$label\nAaj koi sale nahi hui abhi.');
        }
        return ActionResult.success(
          reply: label,
          detailCard: {
            'type': 'analytics',
            'Aaj ke Bills': count.toString(),
            'Total Sale': '₹$total',
            'Paid': '₹$paid',
            'Unpaid': '₹$unpaid',
          },
        );

      case 'week':
        final data = await _db.getDateRangeSaleSummary(7);
        final label = aiReply.isNotEmpty ? aiReply : '📊 Is hafte ki sale:';
        return ActionResult.success(
          reply: label,
          detailCard: {
            'type': 'analytics',
            'Period': 'Last 7 Days',
            'Total Bills': '${data['bill_count']}',
            'Total Sale': '₹${data['total_sale']}',
            'Paid': '₹${data['paid_amount']}',
            'Unpaid': '₹${data['unpaid_amount']}',
            'Customers': '${data['unique_customers']}',
          },
        );

      case 'month':
      case 'last_month':
        final days = period == 'last_month' ? 60 : 30;
        final data = await _db.getDateRangeSaleSummary(days);
        final monthly = await _db.getMonthlySaleBreakdown();
        final label = aiReply.isNotEmpty ? aiReply : '📊 Monthly sale:';
        return ActionResult.success(
          reply: label,
          detailCard: {
            'type': 'analytics',
            'Period': period == 'last_month' ? 'Last 60 Days' : 'Last 30 Days',
            'Total Bills': '${data['bill_count']}',
            'Total Sale': '₹${data['total_sale']}',
            'Paid': '₹${data['paid_amount']}',
            'Unpaid': '₹${data['unpaid_amount']}',
            'Unique Customers': '${data['unique_customers']}',
          },
          tableData: monthly.map((m) => {
            'Month': m['month'],
            'Bills': m['bill_count'].toString(),
            'Sale': '₹${m['total_sale']}',
            'Paid': '₹${m['paid_amount']}',
          }).toList(),
        );

      case 'year':
        final data = await _db.getDateRangeSaleSummary(365);
        final label = aiReply.isNotEmpty ? aiReply : '📊 Is saal ki sale:';
        return ActionResult.success(
          reply: label,
          detailCard: {
            'type': 'analytics',
            'Period': 'Last 365 Days',
            'Total Bills': '${data['bill_count']}',
            'Total Sale': '₹${data['total_sale']}',
            'Paid': '₹${data['paid_amount']}',
            'Unpaid': '₹${data['unpaid_amount']}',
            'Unique Customers': '${data['unique_customers']}',
          },
        );

      case 'unpaid':
        final bills = await _db.getUnpaidBills();
        final label = aiReply.isNotEmpty ? aiReply : '⏳ Unpaid bills:';
        if (bills.isEmpty) {
          return ActionResult.success(reply: '✅ Koi unpaid bill nahi! Sab clear hai.');
        }
        final totalUnpaid = bills.fold<double>(
            0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(
          reply: '$label\n${bills.length} bills pending — Total: ₹${totalUnpaid.toStringAsFixed(2)}',
          tableData: bills.map((b) => {
            'Bill': b['bill_number'],
            'Customer': b['customer_name'] ?? '-',
            'Date': b['bill_date'],
            'Amount': '₹${b['total_amount']}',
            'Mode': b['payment_mode'] ?? '-',
          }).toList(),
        );

      case 'top_items':
        final items = await _db.getTopSellingItems(limit: 10);
        final label = aiReply.isNotEmpty ? aiReply : '🏆 Top selling items:';
        if (items.isEmpty) return ActionResult.success(reply: 'Abhi koi sale nahi hui.');
        return ActionResult.success(
          reply: label,
          tableData: items.asMap().entries.map((e) => {
            '#': (e.key + 1).toString(),
            'Item': e.value['item_name'],
            'Qty Sold': e.value['total_qty_sold'].toString(),
            'Revenue': '₹${e.value['total_revenue']}',
          }).toList(),
        );

      case 'low_stock':
        final items = await _db.getLowStockItems(threshold: 10);
        final label = aiReply.isNotEmpty ? aiReply : '⚠️ Low stock items:';
        if (items.isEmpty) return ActionResult.success(reply: '✅ Sab items ka stock theek hai (>10 units).');
        return ActionResult.success(
          reply: '$label (${items.length} items)',
          tableData: items.map((i) => {
            'Name': i['name'],
            'Stock': i['qty'].toString(),
            'Price': '₹${i['price'] ?? "-"}',
          }).toList(),
        );

      case 'item_count':
        final items = await _db.getAllItems();
        final totalStock = items.fold<int>(0, (s, i) => s + (i.qty ?? 0));
        final totalValue = items.fold<double>(
            0, (s, i) => s + ((i.qty ?? 0) * (i.price ?? 0)));
        final label = aiReply.isNotEmpty ? aiReply : '📦 Item summary:';
        return ActionResult.success(
          reply: label,
          detailCard: {
            'type': 'analytics',
            'Total Items': '${items.length}',
            'Total Stock': totalStock.toString(),
            'Inventory Value': '₹${totalValue.toStringAsFixed(2)}',
          },
        );

      case 'customer_count':
        final customers = await _db.getAllCustomers();
        final label = aiReply.isNotEmpty ? aiReply : '👥 Customer summary:';
        return ActionResult.success(
          reply: label,
          detailCard: {
            'type': 'analytics',
            'Total Customers': '${customers.length}',
          },
        );

      case 'purchase_month':
        final bills = await _db.getAllPurchaseBills();
        final label = aiReply.isNotEmpty ? aiReply : '🛒 Purchase summary:';
        if (bills.isEmpty) {
          return ActionResult.success(reply: '$label\nKoi purchase bill nahi.');
        }
        final totalPurchase = bills.fold<double>(
            0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(
          reply: '$label\n${bills.length} purchase bills — Total: ₹${totalPurchase.toStringAsFixed(2)}',
          tableData: bills.take(10).map((b) => {
            'Bill': b['bill_number'],
            'Supplier': b['supplier_name'] ?? '-',
            'Date': b['bill_date'],
            'Total': '₹${b['total_amount']}',
            'Status': b['payment_status'],
          }).toList(),
        );

      default:
        return await _handleAnalytics('today', aiReply);
    }
  }

  // ── Initiate Sale Bill Flow ────────────────────────────────────────────

  Future<ActionResult> _initiateBillFlow(ParsedAction action) async {
    // ── SUBSCRIPTION CHECK ─────────────────────────────────────────────────
    final canCreate = await SubscriptionService.instance.canCreateBill();
    if (!canCreate) {
      return ActionResult.subscriptionRequired();
    }
    // ───────────────────────────────────────────────────────────────────────

    final data = action.data;
    final customerName = data['customer_name'] as String?;
    int? customerId = _toInt(data['customer_id']);

    if (customerId == null && customerName != null) {
      final c = await _db.getCustomerByName(customerName) ??
          await _db.getCustomerFuzzy(customerName);
      customerId = c?.id;
    }

    if (customerId == null) {
      final all = await _db.getAllCustomers();
      return ActionResult.customerNotFound(
        searchedName: customerName ?? '',
        customers: all.map((c) => {
          'name': c.name,
          'phone': c.phone ?? '-',
          'state': c.state ?? '-',
        }).toList(),
      );
    }

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems.map((r) {
      final m = r as Map<String, dynamic>;
      return {
        'name': (m['name'] as String? ?? '').trim(),
        'qty': _toInt(m['qty']) ?? 1,
        'price': _toDouble(m['price']),
        'tax_rate': _toDouble(m['tax_rate']) ?? 0.0,
        'discount_per_item': _toDouble(m['discount_per_item']) ?? 0.0,
      };
    }).where((i) => (i['name'] as String).isNotEmpty).toList();

    final customer = await _db.getCustomerById(customerId);

    // ── Extract all fields AI may have already provided ──────────────
    final aiDiscountType  = data['discount_type']  as String?;   // 'none','percent','amount'
    final aiDiscountValue = _toDouble(data['discount_value']) ?? _toDouble(data['discount_amount']);
    final aiTaxType       = data['tax_type']        as String?;   // 'inclusive','exclusive'
    final aiTaxRate       = _toDouble(data['tax_rate']) ?? _toDouble(data['gst_rate']);
    final aiPaymentMode   = data['payment_mode']    as String?;
    final aiPaymentStatus = data['payment_status']  as String?;

    return ActionResult.startBillFlow(
      customerName: customer?.name ?? customerName ?? '',
      items: items,
      discountType:   aiDiscountType,
      discountValue:  aiDiscountValue,
      taxType:        aiTaxType,
      taxRate:        aiTaxRate,
      paymentMode:    aiPaymentMode,
      paymentStatus:  aiPaymentStatus,
    );
  }

  // ── Create Bill from completed BillCreationState (Sale) ────────────────────

  Future<ActionResult> createBillFromState(BillCreationState state) async {
    // ── SUBSCRIPTION CHECK ─────────────────────────────────────────────────
    final canCreate = await SubscriptionService.instance.canCreateBill();
    if (!canCreate) {
      return ActionResult.subscriptionRequired();
    }
    // ───────────────────────────────────────────────────────────────────────

    final customerName = state.customerName ?? '';
    final c = await _db.getCustomerByName(customerName) ??
        await _db.getCustomerFuzzy(customerName);
    if (c == null) return ActionResult.error(message: 'Customer nahi mila.');

    final billLines = <Map<String, dynamic>>[];
    final stockIssues = <String>[];

    for (final itemData in state.items) {
      final name = itemData['name'] as String? ?? '';
      final item = await _db.getItemByName(name) ?? await _db.getItemFuzzy(name);
      if (item == null) {
        return ActionResult.error(message: '"$name" item nahi mila. Pehle item add karein.');
      }
      final qty = itemData['qty'] as int? ?? 1;
      if (qty <= 0) {
        return ActionResult.error(message: '"${item.name}" ki quantity 0 se zyada honi chahiye.');
      }
      final unitPrice = (itemData['price'] as double?) ?? item.price ?? 0.0;
      final taxRate = state.taxRate;
      final itemDiscount = (itemData['discount_per_item'] as double?) ?? 0.0;

      if (item.qty != null && item.qty! <= 0) {
        stockIssues.add(item.name);
        continue;
      }
      if (item.qty != null && item.qty! < qty) {
        return ActionResult.stockInsufficient(
            itemName: item.name, requested: qty, available: item.qty!);
      }

      final lineBase = unitPrice * qty - itemDiscount;
      double taxableAmount, taxAmount;
      if (state.taxType == 'inclusive') {
        taxableAmount = lineBase / (1 + taxRate / 100);
        taxAmount = lineBase - taxableAmount;
      } else {
        taxableAmount = lineBase;
        taxAmount = taxableAmount * (taxRate / 100);
      }
      final lineTotal = taxableAmount + taxAmount;

      billLines.add({
        'item_id': item.id,
        'item_name': item.name,
        'qty': qty,
        'unit_price': unitPrice,
        'discount_amount': itemDiscount,
        'tax_rate': taxRate,
        'tax_amount': double.parse(taxAmount.toStringAsFixed(2)),
        'line_total': double.parse(lineTotal.toStringAsFixed(2)),
      });
    }

    if (stockIssues.isNotEmpty) return ActionResult.stockZero(itemNames: stockIssues);
    if (billLines.isEmpty) return ActionResult.error(message: 'Koi valid item nahi mila.');

    final subtotalBase = billLines.fold<double>(
        0, (s, l) => s + (l['unit_price'] as double) * (l['qty'] as int));
    double billDiscount = 0;
    if (state.discountType == 'percent') {
      billDiscount = subtotalBase * ((state.discountValue ?? 0) / 100);
    } else if (state.discountType == 'amount') {
      billDiscount = state.discountValue ?? 0;
    }
    billDiscount = double.parse(billDiscount.toStringAsFixed(2));

    final subtotal = double.parse(subtotalBase.toStringAsFixed(2));
    final gstAmount = double.parse(
        billLines.fold<double>(0, (s, l) => s + (l['tax_amount'] as double))
            .toStringAsFixed(2));
    final totalAmount =
    double.parse((subtotal - billDiscount + gstAmount).toStringAsFixed(2));
    final billNumber = await _db.generateBillNumber();

    final billId = await _db.insertSaleBill({
      'bill_number': billNumber,
      'customer_id': c.id,
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'tax_type': state.taxType ?? 'exclusive',
      'discount_type': state.discountType ?? 'none',
      'discount_value': state.discountValue ?? 0,
      'discount_amount': billDiscount,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
      'payment_mode': state.paymentMode ?? 'cash',
      'payment_status': state.paymentStatus ?? 'unpaid',
    });

    for (final line in billLines) {
      await _db.insertSaleBillItem({...line, 'bill_id': billId});
      await _db.deductItemStock(line['item_id'] as int, line['qty'] as int);
    }

    // ── increment subscription bill count ──────────────────────────────────
    await SubscriptionService.instance.incrementBillCount();
    // ──────────────────────────────────────────────────────────────────────

    final discStr = billDiscount > 0 ? '\nDiscount: -₹$billDiscount' : '';
    final taxStr = '${state.taxType == 'inclusive' ? 'Inclusive' : 'Exclusive'} GST: ₹$gstAmount';

    return ActionResult.success(
      reply: '✅ Bill $billNumber bana diya!\n${c.name} | ${billLines.length} item(s)'
          '\nSubtotal: ₹$subtotal$discStr\n$taxStr\nTotal: ₹$totalAmount',
      detailCard: {
        'type': 'sale_bill',
        'bill_id': billId,
        'Bill No': billNumber,
        'Customer': c.name,
        'Date': DateTime.now().toIso8601String().split('T')[0],
        'Tax Type': state.taxType == 'inclusive' ? 'Inclusive' : 'Exclusive',
        'Subtotal': '₹$subtotal',
        if (billDiscount > 0) 'Discount': '-₹$billDiscount',
        'GST': '₹$gstAmount',
        'Total': '₹$totalAmount',
        'Payment': state.paymentMode ?? 'cash',
        'Status': state.paymentStatus ?? 'unpaid',
      },
      tableData: billLines.map((l) => {
        'Item': l['item_name'],
        'Qty': l['qty'].toString(),
        'Price': '₹${l['unit_price']}',
        'Tax': '${l['tax_rate']}%',
        'Total': '₹${l['line_total']}',
      }).toList(),
    );
  }

  // ── Purchase Bill Flow ─────────────────────────────────────────────────────

  Future<ActionResult> _initiatePurchaseBillFlow(ParsedAction action) async {
    // ── SUBSCRIPTION CHECK ─────────────────────────────────────────────────
    final canCreate = await SubscriptionService.instance.canCreateBill();
    if (!canCreate) {
      return ActionResult.subscriptionRequired();
    }
    // ───────────────────────────────────────────────────────────────────────

    final data = action.data;
    final supplierName = data['supplier_name'] as String?;

    SupplierModel? supplier;
    if (supplierName != null) {
      supplier = await _db.getSupplierByName(supplierName) ??
          await _db.getSupplierFuzzy(supplierName);
    }

    if (supplier == null) {
      final all = await _db.getAllSuppliers();
      return ActionResult.supplierNotFound(
        searchedName: supplierName ?? '',
        suppliers: all.map((s) => {
          'name': s.name, 'phone': s.phone ?? '-', 'state': s.state ?? '-'
        }).toList(),
      );
    }

    final rawItems = data['items'] as List<dynamic>? ?? [];
    if (rawItems.isEmpty) {
      return ActionResult.needsInput(
          question: 'Kaunsa item kharida aur kitna? Price bhi batao.\nExample: "apple 50qty 30rs"',
          field: 'items');
    }

    return await _createPurchaseBillNow(supplier, rawItems, data);
  }

  Future<ActionResult> _createPurchaseBillNow(
      SupplierModel supplier,
      List<dynamic> rawItems,
      Map<String, dynamic> data,
      ) async {
    final billLines = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      final m = raw as Map<String, dynamic>;
      final itemName = (m['name'] as String? ?? '').trim();
      if (itemName.isEmpty) continue;

      var item = await _db.getItemByName(itemName) ?? await _db.getItemFuzzy(itemName);
      if (item == null) {
        // Auto-create item in purchase flow
        final newId = await _db.insertItem(ItemModel(
          name: itemName, qty: 0, price: _toDouble(m['price']),
        ));
        item = await _db.getItemById(newId);
      }
      if (item == null) continue;

      final qty = _toInt(m['qty']) ?? 1;
      if (qty <= 0) {
        return ActionResult.error(message: '"${item.name}" ki quantity 0 se zyada honi chahiye.');
      }
      final unitPrice = _toDouble(m['price']) ?? 0.0;
      if (unitPrice <= 0) {
        return ActionResult.needsInput(
            question: '"${item.name}" ki purchase price kya hai?',
            field: 'price');
      }
      final taxRate = _toDouble(m['tax_rate']) ?? 0.0;
      final taxAmount = unitPrice * qty * (taxRate / 100);
      final lineTotal = unitPrice * qty + taxAmount;

      billLines.add({
        'item_id': item.id,
        'item_name': item.name,
        'qty': qty,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'tax_amount': double.parse(taxAmount.toStringAsFixed(2)),
        'line_total': double.parse(lineTotal.toStringAsFixed(2)),
      });
    }

    if (billLines.isEmpty) return ActionResult.error(message: 'Koi valid item nahi mila.');

    final subtotal = double.parse(
        billLines.fold<double>(0, (s, l) =>
        s + (l['unit_price'] as double) * (l['qty'] as int))
            .toStringAsFixed(2));
    final totalTax = double.parse(
        billLines.fold<double>(0, (s, l) => s + (l['tax_amount'] as double))
            .toStringAsFixed(2));
    final totalAmount = double.parse((subtotal + totalTax).toStringAsFixed(2));
    final billNumber = await _db.generatePurchaseBillNumber();

    final billId = await _db.insertPurchaseBill({
      'bill_number': billNumber,
      'supplier_id': supplier.id,
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'subtotal': subtotal,
      'tax_amount': totalTax,
      'total_amount': totalAmount,
      'payment_mode': data['payment_mode'] ?? 'cash',
      'payment_status': data['payment_status'] ?? 'unpaid',
      'notes': data['notes'],
    });

    for (final line in billLines) {
      await _db.insertPurchaseBillItem({...line, 'bill_id': billId});
      await _db.addItemStock(line['item_id'] as int, line['qty'] as int);
    }

    // ── increment subscription bill count ──────────────────────────────────
    await SubscriptionService.instance.incrementBillCount();
    // ──────────────────────────────────────────────────────────────────────

    return ActionResult.success(
      reply: '✅ Purchase Bill $billNumber bana diya!\n${supplier.name} | ${billLines.length} item(s)\nTotal: ₹$totalAmount\n(Stock updated ✓)',
      detailCard: {
        'type': 'purchase_bill',
        'bill_id': billId,
        'Bill No': billNumber,
        'Supplier': supplier.name,
        'Date': DateTime.now().toIso8601String().split('T')[0],
        'Subtotal': '₹$subtotal',
        'GST': '₹$totalTax',
        'Total': '₹$totalAmount',
        'Payment': data['payment_mode'] ?? 'cash',
        'Status': data['payment_status'] ?? 'unpaid',
      },
      tableData: billLines.map((l) => {
        'Item': l['item_name'],
        'Qty': l['qty'].toString(),
        'Price': '₹${l['unit_price']}',
        'Tax': '${l['tax_rate']}%',
        'Total': '₹${l['line_total']}',
      }).toList(),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

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
