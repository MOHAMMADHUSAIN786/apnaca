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

        // Validation: name empty
        if (name.isEmpty) {
          return ActionResult.needsInput(
              question: 'Item ka naam kya rakha jaaye?', field: 'name');
        }
        // Validation: name cannot be pure number
        if (double.tryParse(name) != null) {
          return ActionResult.error(
              message: '⚠️ Item ka naam number nahi ho sakta. Sahi naam batao (e.g. "Apple").');
        }

        // Validation: negative qty
        final qty = _toInt(action.data['qty']);
        if (qty != null && qty < 0) {
          return ActionResult.error(
              message: '⚠️ Quantity negative nahi ho sakti. 0 ya zyada honi chahiye.');
        }

        // Validation: negative/zero price
        final price = _toDouble(action.data['price']);
        if (price != null && price <= 0) {
          return ActionResult.error(
              message: '⚠️ Price 0 ya negative nahi ho sakti. Sahi price batao.');
        }

        // Duplicate check
        if (await _db.itemNameExists(name)) {
          final existing2 = await _db.getItemByName(name);
          return ActionResult.error(
              message: '⚠️ "$name" naam ka item pehle se exist karta hai.'
                  'Stock: ${existing2?.qty ?? "-"} | Price: ₹${existing2?.price ?? "-"}'
                  'Update karna hai? Batao: "$name price 150 kar do" ya "$name stock 50 badha do"');
        }

        // Ask optional details only if user didn't already give all info
        final hasAllRequired = qty != null && price != null;
        final wantsOptional = action.data['ask_optional'] == true;

        if (!hasAllRequired) {
          // Missing required fields — ask one by one
          if (qty == null) {
            return ActionResult.needsInput(
                question: '"$name" ki quantity kitni hai?', field: 'qty');
          }
          if (price == null) {
            return ActionResult.needsInput(
                question: '"$name" ki price kya hai?', field: 'price');
          }
        }

        // All required info present — create item
        final newId = await _db.insertItem(ItemModel(
          name: name, qty: qty!, price: price!,
          hsnCode: action.data['hsn_code'] as String?,
        ));
        return ActionResult.success(reply: action.reply, affectedId: newId);

      case AiActionType.updateItem:
      // Try name-based lookup first (AI sends name, not id)
        final updateItemName = (action.data['name'] as String?)?.trim();
        final updateItemId   = _extractId(action.data);
        ItemModel? existingItem;

        if (updateItemName != null && updateItemName.isNotEmpty) {
          existingItem = await _db.getItemByName(updateItemName)
              ?? await _db.getItemFuzzy(updateItemName);
        }
        if (existingItem == null && updateItemId != null) {
          existingItem = await _db.getItemById(updateItemId);
        }
        if (existingItem == null) {
          final nameToSearch = updateItemName ?? 'unknown';
          // Check if any similar item exists
          final allI = await _db.getAllItems();
          final names = allI.map((i) => i.name).take(10).join(', ');
          return ActionResult.error(
              message: '⚠️ "$nameToSearch" naam ka item nahi mila.'
                  'Available items: $names');
        }

        // Validation: negative qty
        final qtyAdd = _toInt(action.data['qty_add']);
        final rawQty = _toInt(action.data['qty']);
        final newQty = qtyAdd != null && qtyAdd > 0
            ? (existingItem.qty ?? 0) + qtyAdd
            : rawQty;
        if (newQty != null && newQty < 0) {
          return ActionResult.error(message: '⚠️ Quantity negative nahi ho sakti.');
        }

        // Validation: negative/zero price
        final newPrice = _toDouble(action.data['price']);
        if (newPrice != null && newPrice <= 0) {
          return ActionResult.error(message: '⚠️ Price 0 ya negative nahi ho sakti.');
        }

        // Validation: new name not duplicate (if renaming)
        final newName = action.data['new_name'] as String?;
        if (newName != null && newName.isNotEmpty && newName != existingItem.name) {
          if (await _db.itemNameExists(newName)) {
            return ActionResult.error(message: '⚠️ "$newName" naam ka item pehle se exist karta hai.');
          }
        }

        await _db.updateItem(existingItem.copyWith(
          name: newName ?? existingItem.name,
          qty: newQty ?? existingItem.qty,
          price: newPrice ?? existingItem.price,
          hsnCode: (action.data['hsn_code'] as String?) ?? existingItem.hsnCode,
        ));
        return ActionResult.success(reply: action.reply);

      case AiActionType.deleteItem:
        final delItemName = (action.data['name'] as String?)?.trim();
        final delItemId   = _extractId(action.data);
        ItemModel? itemToDelete;

        if (delItemName != null && delItemName.isNotEmpty) {
          itemToDelete = await _db.getItemByName(delItemName)
              ?? await _db.getItemFuzzy(delItemName);
        }
        if (itemToDelete == null && delItemId != null) {
          itemToDelete = await _db.getItemById(delItemId);
        }
        if (itemToDelete == null) {
          return ActionResult.error(message: '⚠️ "${delItemName ?? ""}" naam ka item nahi mila.');
        }
        await _db.deleteItem(itemToDelete.id!);
        return ActionResult.success(
            reply: '🗑️ "${itemToDelete.name}" item delete ho gaya.');

      case AiActionType.listItems:
        final items = await _db.getAllItems();
        if (items.isEmpty) return ActionResult.success(
            reply: 'Koi item nahi hai abhi.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${items
              .length} items:',
          tableData: items.map((i) =>
          {
            'Name': i.name,
            'Stock': i.qty?.toString() ?? '-',
            'Price': i.price != null ? '₹${i.price}' : '-',
          }).toList(),
        );

      case AiActionType.showItemDetail:
        final detailName = (action.data['name'] as String?)?.trim();
        final detailId   = _extractId(action.data);
        ItemModel? detailItem;

        if (detailName != null && detailName.isNotEmpty) {
          detailItem = await _db.getItemByName(detailName)
              ?? await _db.getItemFuzzy(detailName);
        }
        if (detailItem == null && detailId != null) {
          detailItem = await _db.getItemById(detailId);
        }
        if (detailItem == null) {
          if (detailName == null || detailName.isEmpty) {
            return ActionResult.needsInput(
                question: 'Konsa item ki detail dekhni hai? Naam batao.', field: 'name');
          }
          return ActionResult.error(message: '⚠️ "$detailName" naam ka item nahi mila.');
        }
        // HSN check — inform clearly
        final hsnDisplay = (detailItem.hsnCode != null && detailItem.hsnCode!.isNotEmpty)
            ? detailItem.hsnCode!
            : 'HSN code add nahi kiya gaya';
        return ActionResult.success(reply: action.reply, detailCard: {
          'type': 'item',
          'Name': detailItem.name,
          'Stock': detailItem.qty?.toString() ?? '0',
          'Price': detailItem.price != null ? '₹${detailItem.price}' : '-',
          'HSN Code': hsnDisplay,
        });

      case AiActionType.showItemTransactions:
        final txnItemName = (action.data['name'] as String?)?.trim();
        if (txnItemName == null || txnItemName.isEmpty) {
          return ActionResult.needsInput(
              question: 'Konsa item ka transaction dekhna hai? Naam batao.', field: 'name');
        }
        // Check item exists first
        final txnItem = await _db.getItemByName(txnItemName) ?? await _db.getItemFuzzy(txnItemName);
        if (txnItem == null) {
          return ActionResult.error(message: '⚠️ "$txnItemName" naam ka item nahi mila. Sahi naam batao.');
        }
        final txns = await _db.getItemTransactions(txnItem.name);
        if (txns.isEmpty) {
          return ActionResult.success(
              reply: '"${txnItem.name}" ka abhi tak koi transaction nahi hua.'
                  'Stock: ${txnItem.qty ?? 0} | Price: ₹${txnItem.price ?? 0}',
              tableData: []);
        }
        final totalSold = txns.fold<int>(
            0, (s, t) => s + ((t['qty'] as int?) ?? 0));
        final totalRevenue = txns.fold<double>(
            0, (s, t) => s + ((t['line_total'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(
          reply: '"${txnItem.name}" — ${txns
              .length} transactions | Sold: $totalSold units | Revenue: ₹${totalRevenue
              .toStringAsFixed(2)}',
          tableData: txns.map((t) =>
          {
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
        if (name.isEmpty) return ActionResult.needsInput(
            question: 'Customer ka naam?', field: 'name');
        if (await _db.customerNameExists(name)) {
          return ActionResult.error(
              message: '⚠️ "$name" customer pehle se exist karta hai.');
        }
        final phone = action.data['phone'] as String?;
        if (phone != null && phone.isNotEmpty &&
            !RegExp(r'^\d{10}$').hasMatch(phone)) {
          return ActionResult.error(
              message: '⚠️ Phone number 10 digits ka hona chahiye. "$phone" galat hai.');
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
      // Name-based lookup first
        final updCustName = (action.data['name'] as String?)?.trim();
        final updCustId   = _extractId(action.data);
        CustomerModel? existingCust;

        if (updCustName != null && updCustName.isNotEmpty) {
          existingCust = await _db.getCustomerByName(updCustName)
              ?? await _db.getCustomerFuzzy(updCustName);
        }
        if (existingCust == null && updCustId != null) {
          existingCust = await _db.getCustomerById(updCustId);
        }
        if (existingCust == null) {
          return ActionResult.error(message: '⚠️ "${updCustName ?? ""}" naam ka customer nahi mila.');
        }

        final updPhone = action.data['phone'] as String?;
        if (updPhone != null && updPhone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(updPhone)) {
          return ActionResult.error(message: '⚠️ Phone number 10 digits ka hona chahiye. "$updPhone" galat hai.');
        }
        final updGst = action.data['gst_number'] as String?;
        if (updGst != null && updGst.isNotEmpty && updGst.length != 15) {
          return ActionResult.error(message: '⚠️ GST number 15 characters ka hona chahiye.');
        }
        await _db.updateCustomer(existingCust.copyWith(
          name:      action.data['new_name'] as String? ?? existingCust.name,
          email:     action.data['email']    as String? ?? existingCust.email,
          phone:     updPhone ?? existingCust.phone,
          address:   action.data['address']  as String? ?? existingCust.address,
          gstNumber: updGst   ?? existingCust.gstNumber,
          state:     action.data['state']    as String? ?? existingCust.state,
        ));
        return ActionResult.success(reply: action.reply);

      case AiActionType.deleteCustomer:
        final delCustName = (action.data['name'] as String?)?.trim();
        final delCustId   = _extractId(action.data);
        CustomerModel? custToDelete;

        if (delCustName != null && delCustName.isNotEmpty) {
          custToDelete = await _db.getCustomerByName(delCustName)
              ?? await _db.getCustomerFuzzy(delCustName);
        }
        if (custToDelete == null && delCustId != null) {
          custToDelete = await _db.getCustomerById(delCustId);
        }
        if (custToDelete == null) {
          return ActionResult.error(message: '⚠️ "${delCustName ?? ""}" naam ka customer nahi mila.');
        }
        await _db.deleteCustomer(custToDelete.id!);
        return ActionResult.success(reply: '🗑️ "${custToDelete.name}" customer delete ho gaya.');

      case AiActionType.listCustomers:
        final customers = await _db.getAllCustomers();
        if (customers.isEmpty) return ActionResult.success(
            reply: 'Koi customer nahi hai.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${customers
              .length} customers:',
          tableData: customers.map((c) =>
          {
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
        if (id != null)
          customer = await _db.getCustomerById(id);
        else if (name != null) customer = await _db.getCustomerByName(name) ??
            await _db.getCustomerFuzzy(name);
        if (customer == null)
          return ActionResult.error(message: 'Customer nahi mila.');
        // Also fetch transaction history
        final custTxns = await _db.getCustomerTransactions(customer.name);
        final custTotal = custTxns.fold<double>(
            0, (s, t) => s + ((t['total_amount'] as num?)?.toDouble() ?? 0));
        final custPending = custTxns.where((t) =>
        t['payment_status'] == 'unpaid' || t['payment_status'] == 'partial')
            .fold<double>(
            0, (s, t) => s + ((t['total_amount'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(reply: action.reply, detailCard: {
          'type': 'customer',
          'Name': customer.name,
          'Phone': customer.phone ?? '-',
          'Email': customer.email ?? '-',
          'GST': customer.gstNumber ?? '-',
          'State': customer.state ?? '-',
          'Address': customer.address ?? '-',
          'Total Bills': custTxns.length.toString(),
          'Total Business': '₹${custTotal.toStringAsFixed(2)}',
          'Pending': '₹${custPending.toStringAsFixed(2)}',
        }, tableData: custTxns.map((t) =>   // ✅ Always a list, even if empty
        {
          'Bill': t['bill_number']?.toString() ?? '-',
          'Date': t['bill_date']?.toString() ?? '-',
          'Items': t['items']?.toString() ?? '-',
          'Amount': '₹${t['total_amount']}',
          'Mode': t['payment_mode']?.toString() ?? '-',
          'Status': t['payment_status']?.toString() ?? '-',
        }).toList());

    // ══════════════════════════════════════════════════════
    //  SUPPLIERS
    // ══════════════════════════════════════════════════════

      case AiActionType.createSupplier:
        final name = (action.data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) return ActionResult.needsInput(
            question: 'Supplier ka naam?', field: 'name');
        if (await _db.supplierNameExists(name)) {
          return ActionResult.error(
              message: '⚠️ "$name" supplier pehle se exist karta hai.');
        }
        final phone = action.data['phone'] as String?;
        if (phone != null && phone.isNotEmpty &&
            !RegExp(r'^\d{10}$').hasMatch(phone)) {
          return ActionResult.error(
              message: '⚠️ Phone number 10 digits ka hona chahiye.');
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
        final updSupName = (action.data['name'] as String?)?.trim();
        final updSupId   = _extractId(action.data);
        SupplierModel? existingSup;

        if (updSupName != null && updSupName.isNotEmpty) {
          existingSup = await _db.getSupplierByName(updSupName)
              ?? await _db.getSupplierFuzzy(updSupName);
        }
        if (existingSup == null && updSupId != null) {
          existingSup = await _db.getSupplierById(updSupId);
        }
        if (existingSup == null) {
          return ActionResult.error(message: '⚠️ "${updSupName ?? ""}" naam ka supplier nahi mila.');
        }
        final updSupPhone = action.data['phone'] as String?;
        if (updSupPhone != null && updSupPhone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(updSupPhone)) {
          return ActionResult.error(message: '⚠️ Phone number 10 digits ka hona chahiye.');
        }
        await _db.updateSupplier(existingSup.copyWith(
          name:      action.data['new_name'] as String? ?? existingSup.name,
          email:     action.data['email']    as String? ?? existingSup.email,
          phone:     updSupPhone ?? existingSup.phone,
          address:   action.data['address']  as String? ?? existingSup.address,
          gstNumber: action.data['gst_number'] as String? ?? existingSup.gstNumber,
          state:     action.data['state']    as String? ?? existingSup.state,
        ));
        return ActionResult.success(reply: action.reply);

      case AiActionType.deleteSupplier:
        final delSupName = (action.data['name'] as String?)?.trim();
        final delSupId   = _extractId(action.data);
        SupplierModel? supToDelete;

        if (delSupName != null && delSupName.isNotEmpty) {
          supToDelete = await _db.getSupplierByName(delSupName)
              ?? await _db.getSupplierFuzzy(delSupName);
        }
        if (supToDelete == null && delSupId != null) {
          supToDelete = await _db.getSupplierById(delSupId);
        }
        if (supToDelete == null) {
          return ActionResult.error(message: '⚠️ "${delSupName ?? ""}" naam ka supplier nahi mila.');
        }
        await _db.deleteSupplier(supToDelete.id!);
        return ActionResult.success(reply: '🗑️ "${supToDelete.name}" supplier delete ho gaya.');

      case AiActionType.listSuppliers:
        final suppliers = await _db.getAllSuppliers();
        if (suppliers.isEmpty) return ActionResult.success(
            reply: 'Koi supplier nahi hai.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${suppliers
              .length} suppliers:',
          tableData: suppliers.map((s) =>
          {
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
        if (id != null)
          supplier = await _db.getSupplierById(id);
        else if (name != null) supplier = await _db.getSupplierByName(name) ??
            await _db.getSupplierFuzzy(name);
        if (supplier == null)
          return ActionResult.error(message: 'Supplier nahi mila.');
        final supTxns = await _db.getSupplierTransactions(supplier.name);
        final supTotal = supTxns.fold<double>(
            0, (s, t) => s + ((t['total_amount'] as num?)?.toDouble() ?? 0));
        final supPending = supTxns.where((t) =>
        t['payment_status'] == 'unpaid' || t['payment_status'] == 'partial')
            .fold<double>(
            0, (s, t) => s + ((t['total_amount'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(reply: action.reply, detailCard: {
          'type': 'supplier',
          'Name': supplier.name,
          'Phone': supplier.phone ?? '-',
          'Email': supplier.email ?? '-',
          'GST': supplier.gstNumber ?? '-',
          'State': supplier.state ?? '-',
          'Address': supplier.address ?? '-',
          'Total Bills': supTxns.length.toString(),
          'Total Purchased': '₹${supTotal.toStringAsFixed(2)}',
          'Due': '₹${supPending.toStringAsFixed(2)}',
        }, tableData: supTxns.map((t) =>   // ✅ Always list, never null
        {
          'Bill': t['bill_number']?.toString() ?? '-',
          'Date': t['bill_date']?.toString() ?? '-',
          'Items': t['items']?.toString() ?? '-',
          'Amount': '₹${t['total_amount']}',
          'Mode': t['payment_mode']?.toString() ?? '-',
          'Status': t['payment_status']?.toString() ?? '-',
        }).toList());

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
              (b['customer_name'] as String? ?? '').toLowerCase().contains(cn))
              .toList();
        }
        if (f['status_filter'] != null) {
          bills = bills
              .where((b) => b['payment_status'] == f['status_filter'])
              .toList();
        }
        if (bills.isEmpty) return ActionResult.success(
            reply: 'Koi bill nahi mila.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${bills
              .length} bills:',
          tableData: bills.map((b) =>
          {
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
            if (bill['notes'] != null && bill['notes']
                .toString()
                .isNotEmpty) 'Notes': bill['notes'],
          },
          tableData: lineItems.map((i) =>
          {
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
        if (status == null) return ActionResult.error(
            message: 'Status missing (paid/unpaid/partial).');
        int? billId = _extractId(action.data);
        if (billId == null && billNumber != null) {
          final bill = await _db.getSaleBillByNumber(billNumber);
          billId = bill?['id'] as int?;
        }
        if (billId == null) return ActionResult.error(
            message: 'Bill nahi mila. Bill number batao.');
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
        if (bills.isEmpty) return ActionResult.success(
            reply: 'Koi purchase bill nahi.', tableData: []);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '${bills
              .length} purchase bills:',
          tableData: bills.map((b) =>
          {
            'Bill No': b['bill_number'],
            'Supplier': b['supplier_name'] ?? '-',
            'Date': b['bill_date'],
            'Total': '₹${b['total_amount']}',
            'Status': b['payment_status'],
          }).toList(),
        );

      case AiActionType.showPurchaseBillDetail:
        final billNumber = action.data['bill_number'] as String?;
        if (billNumber == null)
          return ActionResult.error(message: 'Purchase bill number batao.');
        final bill = await _db.getPurchaseBillByNumber(billNumber);
        if (bill == null)
          return ActionResult.error(message: 'Purchase bill nahi mila.');
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
          tableData: lineItems.map((i) =>
          {
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
        if (status == null) return ActionResult.error(
            message: 'Status missing (paid/unpaid/partial).');
        if (billNumber == null)
          return ActionResult.error(message: 'Purchase bill number batao.');
        final bill = await _db.getPurchaseBillByNumber(billNumber);
        if (bill == null)
          return ActionResult.error(message: 'Purchase bill nahi mila.');
        final billId = bill['id'] as int;
        await _db.updatePurchaseBillStatus(billId, status);
        final emoji = status == 'paid' ? '✅' : status == 'partial' ? '🔄' : '⏳';
        return ActionResult.success(
            reply: '$emoji Purchase Bill $billNumber $status mark ho gaya!');

    // ══════════════════════════════════════════════════════
    //  ANALYTICS
    // ══════════════════════════════════════════════════════

      case AiActionType.getAnalytics:
        return await _handleAnalytics(
            action.data['period'] as String? ?? 'today', action.reply, data: action.data);

    // ══════════════════════════════════════════════════════
    //  FLOW
    // ══════════════════════════════════════════════════════


    // ══════════════════════════════════════════════════════
    //  EDIT SALE BILL (BUG3 + PART3 FIX)
    //  Supports: update_item_qty, update_item_price,
    //            add_item, remove_item, update_status, open
    // ══════════════════════════════════════════════════════

      case AiActionType.editSaleBill:
        return await _editSaleBill(action);

      case AiActionType.deleteSaleBill:
        final delBillNum = action.data['bill_number'] as String?;
        if (delBillNum == null || delBillNum.isEmpty) {
          return ActionResult.error(message: 'Bill number batao (jaise: SB-2026-0001)');
        }
        final delBillData = await _db.getSaleBillByNumber(delBillNum);
        if (delBillData == null) return ActionResult.error(message: '"$delBillNum" bill nahi mila.');
        final delBillId = delBillData['id'] as int;
        await _db.deleteSaleBillWithStockRestore(delBillId);
        return ActionResult.success(reply: '🗑️ Bill $delBillNum delete ho gaya. Stock restore ✓');

    // ══════════════════════════════════════════════════════
    //  EDIT PURCHASE BILL (PART3 FIX)
    // ══════════════════════════════════════════════════════

      case AiActionType.editPurchaseBill:
        return await _editPurchaseBill(action);

      case AiActionType.deletePurchaseBill:
        final delPBNum = action.data['bill_number'] as String?;
        if (delPBNum == null || delPBNum.isEmpty) {
          return ActionResult.error(message: 'Purchase bill number batao (jaise: PB-2026-0001)');
        }
        final delPBData = await _db.getPurchaseBillByNumber(delPBNum);
        if (delPBData == null) return ActionResult.error(message: '"$delPBNum" purchase bill nahi mila.');
        final delPBId = delPBData['id'] as int;
        await _db.deletePurchaseBillWithStockDeduct(delPBId);
        return ActionResult.success(reply: '🗑️ Purchase Bill $delPBNum delete ho gaya. Stock adjusted ✓');

    // ══════════════════════════════════════════════════════
    //  BULK UPDATE PRICES (PART3 FIX)
    // ══════════════════════════════════════════════════════

      case AiActionType.bulkUpdatePrices:
        return await _bulkUpdatePrices(action);

    // ══════════════════════════════════════════════════════
    //  MARK MULTIPLE BILLS PAID (PART3 FIX)
    // ══════════════════════════════════════════════════════

      case AiActionType.markMultipleBillsPaid:
        return await _markMultipleBillsPaid(action);

    // ══════════════════════════════════════════════════════
    //  SEARCH BILLS (PART3 FIX)
    // ══════════════════════════════════════════════════════

      case AiActionType.searchBills:
        return await _searchBills(action);

      case AiActionType.ask:
        return ActionResult.needsInput(
            question: action.reply, field: action.askField ?? '');

      case AiActionType.confirm:
        return ActionResult.success(reply: action.reply);

      case AiActionType.clarify:
      case AiActionType.error:
        return ActionResult.error(message: action.reply);
    }
  }

  // ── Analytics handler ─────────────────────────────────────────────

  Future<ActionResult> _handleAnalytics(String period, String aiReply, {Map<String, dynamic>? data}) async {
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

      case 'stock_check':
        final stockData = ((data?['item_name'] as String?) ?? '').trim();
        if (stockData.isEmpty) return ActionResult.error(message: 'Konsa item ka stock dekhna hai?');
        final stockInfo = await _db.getItemStock(stockData);
        if (stockInfo == null) return ActionResult.error(message: '"$stockData" item nahi mila.');
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '📦 Stock info:',
          detailCard: {
            'type': 'analytics',
            'Item': stockInfo['name'],
            'Current Stock': '${stockInfo['qty']} units',
            'Price': '₹${stockInfo['price']}',
            'Total Value': '₹${((stockInfo['qty'] as int) * (stockInfo['price'] as double)).toStringAsFixed(2)}',
          },
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

    // ── CUSTOMER ANALYTICS ─────────────────────────────────────
      case 'top_customers':
        final topCusts = await _db.getTopCustomers();
        final label9 = aiReply.isNotEmpty ? aiReply : '🏆 Top customers:';
        if (topCusts.isEmpty) return ActionResult.success(reply: 'Abhi koi sale nahi hui.');
        return ActionResult.success(
          reply: '$label9 (by purchase amount)',
          tableData: topCusts.asMap().entries.map((e) => {
            '#': (e.key + 1).toString(),
            'Customer': e.value['customer_name'] ?? '-',
            'Bills': e.value['bill_count'].toString(),
            'Total': '₹${(e.value['total_spent'] as num).toStringAsFixed(2)}',
            'Pending': '₹${(e.value['pending_amount'] as num).toStringAsFixed(2)}',
          }).toList(),
        );

      case 'customer_pending':
        final pendingCusts = await _db.getCustomersWithPending();
        final labelCp = aiReply.isNotEmpty ? aiReply : '⏳ Pending payment customers:';
        if (pendingCusts.isEmpty) return ActionResult.success(reply: '✅ Kisi bhi customer ka payment pending nahi!');
        final totalPending = pendingCusts.fold<double>(0, (s, c) => s + (c['pending_amount'] as num).toDouble());
        return ActionResult.success(
          reply: '$labelCp\nTotal pending: ₹${totalPending.toStringAsFixed(2)}',
          tableData: pendingCusts.map((c) => {
            'Customer': c['customer_name'] ?? '-',
            'Phone': c['phone'] ?? '-',
            'Pending': '₹${(c['pending_amount'] as num).toStringAsFixed(2)}',
            'Bills': c['unpaid_count'].toString(),
          }).toList(),
        );

      case 'customer_transaction':
        final custName = aiReply.isNotEmpty ? '' : '';
        // customer name comes from data, not aiReply
        return ActionResult.error(message: 'Konsa customer ka transaction dekhna hai? Naam batao.');

    // ── SUPPLIER ANALYTICS ─────────────────────────────────────
      case 'top_suppliers':
        final topSups = await _db.getTopSuppliers();
        final labelTs = aiReply.isNotEmpty ? aiReply : '🏭 Top suppliers:';
        if (topSups.isEmpty) return ActionResult.success(reply: 'Abhi koi purchase nahi hua.');
        return ActionResult.success(
          reply: '$labelTs (by purchase amount)',
          tableData: topSups.asMap().entries.map((e) => {
            '#': (e.key + 1).toString(),
            'Supplier': e.value['supplier_name'] ?? '-',
            'Bills': e.value['bill_count'].toString(),
            'Total': '₹${(e.value['total_purchased'] as num).toStringAsFixed(2)}',
            'Pending': '₹${(e.value['pending_amount'] as num).toStringAsFixed(2)}',
          }).toList(),
        );

      case 'supplier_pending':
        final pendingSups = await _db.getSuppliersWithPending();
        final labelSp = aiReply.isNotEmpty ? aiReply : '⏳ Supplier payment due:';
        if (pendingSups.isEmpty) return ActionResult.success(reply: '✅ Kisi bhi supplier ko payment dena nahi!');
        final totalSupPending = pendingSups.fold<double>(0, (s, x) => s + (x['pending_amount'] as num).toDouble());
        return ActionResult.success(
          reply: '$labelSp\nTotal due: ₹${totalSupPending.toStringAsFixed(2)}',
          tableData: pendingSups.map((s) => {
            'Supplier': s['supplier_name'] ?? '-',
            'Phone': s['phone'] ?? '-',
            'Due': '₹${(s['pending_amount'] as num).toStringAsFixed(2)}',
            'Bills': s['unpaid_count'].toString(),
          }).toList(),
        );

    // ── INVENTORY ──────────────────────────────────────────────
      case 'inventory_value':
        final allItems = await _db.getAllItems();
        final totalInvValue = allItems.fold<double>(0, (s, i) => s + ((i.qty ?? 0) * (i.price ?? 0)));
        final totalInvQty = allItems.fold<int>(0, (s, i) => s + (i.qty ?? 0));
        final labelIv = aiReply.isNotEmpty ? aiReply : '📦 Inventory valuation:';
        return ActionResult.success(
          reply: labelIv,
          detailCard: {
            'type': 'analytics',
            'Total Items': '${allItems.length}',
            'Total Stock Units': totalInvQty.toString(),
            'Total Inventory Value': '₹${totalInvValue.toStringAsFixed(2)}',
          },
          tableData: allItems.map((i) => {
            'Item': i.name,
            'Stock': (i.qty ?? 0).toString(),
            'Price': '₹${i.price ?? 0}',
            'Value': '₹${((i.qty ?? 0) * (i.price ?? 0)).toStringAsFixed(2)}',
          }).toList(),
        );

      case 'most_profitable':
        final profitItems = await _db.getMostProfitableItems();
        final labelMp = aiReply.isNotEmpty ? aiReply : '💰 Most profitable items:';
        if (profitItems.isEmpty) return ActionResult.success(reply: 'Abhi koi sale data nahi.');
        return ActionResult.success(
          reply: labelMp,
          tableData: profitItems.asMap().entries.map((e) => {
            '#': (e.key + 1).toString(),
            'Item': e.value['item_name'],
            'Sold': e.value['total_qty_sold'].toString(),
            'Revenue': '₹${(e.value['total_revenue'] as num).toStringAsFixed(2)}',
          }).toList(),
        );

    // ── PURCHASE ANALYTICS ─────────────────────────────────────
      case 'purchase_week':
        final pw7 = await _db.getPurchaseSummaryByDays(7);
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '🛒 Last 7 days purchase:',
          detailCard: {
            'type': 'analytics',
            'Period': 'Last 7 Days',
            'Purchase Bills': '${pw7['bill_count']}',
            'Total Purchase': '₹${pw7['total_purchase']}',
            'Paid': '₹${pw7['paid_amount']}',
            'Unpaid': '₹${pw7['unpaid_amount']}',
          },
        );

      case 'purchase_last_month':
        final plm = await _db.getPurchaseSummaryByDays(60);
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '🛒 Last month purchase:',
          detailCard: {
            'type': 'analytics',
            'Period': 'Last 60 Days',
            'Purchase Bills': '${plm['bill_count']}',
            'Total Purchase': '₹${plm['total_purchase']}',
            'Paid': '₹${plm['paid_amount']}',
            'Unpaid': '₹${plm['unpaid_amount']}',
          },
        );

      case 'unpaid_purchase':
        final upBills = await _db.getUnpaidPurchaseBills();
        final labelUp = aiReply.isNotEmpty ? aiReply : '⏳ Unpaid purchase bills:';
        if (upBills.isEmpty) return ActionResult.success(reply: '✅ Koi unpaid purchase bill nahi!');
        final totalUpAmount = upBills.fold<double>(0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0));
        return ActionResult.success(
          reply: '$labelUp\nTotal due: ₹${totalUpAmount.toStringAsFixed(2)}',
          tableData: upBills.map((b) => {
            'Bill': b['bill_number'],
            'Supplier': b['supplier_name'] ?? '-',
            'Date': b['bill_date'],
            'Amount': '₹${b['total_amount']}',
          }).toList(),
        );

    // ── BUSINESS SUMMARY ───────────────────────────────────────
      case 'business_summary':
        final bsToday = await _db.getTodaySaleSummary();
        final bsMonth = await _db.getDateRangeSaleSummary(30);
        final bsPurch = await _db.getPurchaseSummaryByDays(30);
        final bsUnpaid = await _db.getUnpaidBills();
        final bsLowStock = await _db.getLowStockItems(threshold: 10);
        final bsTopItems = await _db.getTopSellingItems(limit: 3);
        final totalUnpaidAmt = bsUnpaid.fold<double>(0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0));
        final labelBs = aiReply.isNotEmpty ? aiReply : '📊 Business Summary:';
        return ActionResult.success(
          reply: labelBs,
          detailCard: {
            'type': 'analytics',
            '🗓️ Aaj ki Sale': '₹${bsToday['total_sale']}',
            '📅 Is Month Sale': '₹${bsMonth['total_sale']}',
            '🛒 Is Month Purchase': '₹${bsPurch['total_purchase']}',
            '⏳ Pending Receivable': '₹${totalUnpaidAmt.toStringAsFixed(2)}',
            '⚠️ Low Stock Items': '${bsLowStock.length}',
            '🏆 Top Item': bsTopItems.isNotEmpty ? '${bsTopItems.first['item_name']}' : '-',
          },
        );

      case 'profit_summary':
        final saleSummary = await _db.getDateRangeSaleSummary(30);
        final purchSummary = await _db.getPurchaseSummaryByDays(30);
        final saleTotal = (saleSummary['total_sale'] as num?)?.toDouble() ?? 0;
        final purchTotal = (purchSummary['total_purchase'] as num?)?.toDouble() ?? 0;
        final profit = saleTotal - purchTotal;
        final labelPs = aiReply.isNotEmpty ? aiReply : '💰 Profit summary (30 days):';
        return ActionResult.success(
          reply: labelPs,
          detailCard: {
            'type': 'analytics',
            'Total Sales': '₹${saleTotal.toStringAsFixed(2)}',
            'Total Purchase': '₹${purchTotal.toStringAsFixed(2)}',
            'Gross Profit': '₹${profit.toStringAsFixed(2)}',
            'Profit %': saleTotal > 0 ? '${((profit / saleTotal) * 100).toStringAsFixed(1)}%' : '0%',
          },
        );

      case 'cash_vs_credit':
        final cashCredit = await _db.getCashVsCreditSales();
        final labelCc = aiReply.isNotEmpty ? aiReply : '💳 Cash vs Credit sales:';
        return ActionResult.success(
          reply: labelCc,
          detailCard: {
            'type': 'analytics',
            'Cash Sales': '₹${(cashCredit['cash_total'] as num?)?.toStringAsFixed(2) ?? '0'}',
            'UPI Sales': '₹${(cashCredit['upi_total'] as num?)?.toStringAsFixed(2) ?? '0'}',
            'Credit/Udhaar': '₹${(cashCredit['credit_total'] as num?)?.toStringAsFixed(2) ?? '0'}',
          },
        );

      case 'monthly_trend':
        final trend = await _db.getMonthlySaleBreakdown();
        final labelMt = aiReply.isNotEmpty ? aiReply : '📈 Monthly sales trend:';
        if (trend.isEmpty) return ActionResult.success(reply: 'Abhi koi data nahi.');
        return ActionResult.success(
          reply: labelMt,
          tableData: trend.map((m) => {
            'Month': m['month'],
            'Bills': m['bill_count'].toString(),
            'Sale': '₹${m['total_sale']}',
            'Paid': '₹${m['paid_amount']}',
          }).toList(),
        );

      case 'top_revenue_customer':
        final topRevCusts = await _db.getTopCustomers(limit: 1);
        if (topRevCusts.isEmpty) return ActionResult.success(reply: 'Abhi koi data nahi.');
        final top = topRevCusts.first;
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '🏆 Sabse jyada revenue customer:',
          detailCard: {
            'type': 'analytics',
            'Customer': top['customer_name'] ?? '-',
            'Total Purchase': '₹${(top['total_spent'] as num).toStringAsFixed(2)}',
            'Bills': top['bill_count'].toString(),
            'Pending': '₹${(top['pending_amount'] as num).toStringAsFixed(2)}',
          },
        );

      case 'max_outstanding_customer':
        final pendCusts = await _db.getCustomersWithPending();
        if (pendCusts.isEmpty) return ActionResult.success(reply: '✅ Kisi par bhi outstanding nahi!');
        pendCusts.sort((a, b) => (b['pending_amount'] as num).compareTo(a['pending_amount'] as num));
        final topPend = pendCusts.first;
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '⚠️ Highest outstanding customer:',
          detailCard: {
            'type': 'analytics',
            'Customer': topPend['customer_name'] ?? '-',
            'Outstanding': '₹${(topPend['pending_amount'] as num).toStringAsFixed(2)}',
            'Phone': topPend['phone'] ?? '-',
            'Unpaid Bills': topPend['unpaid_count'].toString(),
          },
        );

      case 'max_outstanding_supplier':
        final pendSups = await _db.getSuppliersWithPending();
        if (pendSups.isEmpty) return ActionResult.success(reply: '✅ Kisi bhi supplier ko dena nahi!');
        pendSups.sort((a, b) => (b['pending_amount'] as num).compareTo(a['pending_amount'] as num));
        final topSupPend = pendSups.first;
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '⚠️ Highest due supplier:',
          detailCard: {
            'type': 'analytics',
            'Supplier': topSupPend['supplier_name'] ?? '-',
            'Due': '₹${(topSupPend['pending_amount'] as num).toStringAsFixed(2)}',
            'Phone': topSupPend['phone'] ?? '-',
            'Unpaid Bills': topSupPend['unpaid_count'].toString(),
          },
        );

      case 'total_turnover':
        final saleTurnover = await _db.getDateRangeSaleSummary(365);
        final purchTurnover = await _db.getPurchaseSummaryByDays(365);
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '💼 Total turnover (1 year):',
          detailCard: {
            'type': 'analytics',
            'Sales Turnover': '₹${saleTurnover['total_sale']}',
            'Purchase Turnover': '₹${purchTurnover['total_purchase']}',
            'Net': '₹${((saleTurnover['total_sale'] as num).toDouble() - (purchTurnover['total_purchase'] as num).toDouble()).toStringAsFixed(2)}',
          },
        );

      case 'combined_report':
        final crLow = await _db.getLowStockItems(threshold: 10);
        final crUnpaid = await _db.getCustomersWithPending();
        final crSupPend = await _db.getSuppliersWithPending();
        final crUnpaidAmt = crUnpaid.fold<double>(0, (s, c) => s + (c['pending_amount'] as num).toDouble());
        final crSupAmt = crSupPend.fold<double>(0, (s, s2) => s + (s2['pending_amount'] as num).toDouble());
        return ActionResult.success(
          reply: aiReply.isNotEmpty ? aiReply : '📋 Combined report:',
          detailCard: {
            'type': 'analytics',
            '⚠️ Low Stock Items': '${crLow.length}',
            '⏳ Customer Pending': '₹${crUnpaidAmt.toStringAsFixed(2)} (${crUnpaid.length} customers)',
            '💸 Supplier Due': '₹${crSupAmt.toStringAsFixed(2)} (${crSupPend.length} suppliers)',
          },
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
        customers: all.map((c) =>
        {
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
    final aiDiscountType = data['discount_type'] as String?; // 'none','percent','amount'
    final aiDiscountValue = _toDouble(data['discount_value']) ??
        _toDouble(data['discount_amount']);
    final aiTaxType = data['tax_type'] as String?; // 'inclusive','exclusive'
    final aiTaxRate = _toDouble(data['tax_rate']) ??
        _toDouble(data['gst_rate']);
    final aiPaymentMode = data['payment_mode'] as String?;
    final aiPaymentStatus = data['payment_status'] as String?;

    return ActionResult.startBillFlow(
      customerName: customer?.name ?? customerName ?? '',
      items: items,
      discountType: aiDiscountType,
      discountValue: aiDiscountValue,
      taxType: aiTaxType,
      taxRate: aiTaxRate,
      paymentMode: aiPaymentMode,
      paymentStatus: aiPaymentStatus,
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
      final item = await _db.getItemByName(name) ??
          await _db.getItemFuzzy(name);
      if (item == null) {
        return ActionResult.error(
            message: '"$name" item nahi mila. Pehle item add karein.');
      }
      final qty = itemData['qty'] as int? ?? 1;
      if (qty <= 0) {
        return ActionResult.error(
            message: '"${item.name}" ki quantity 0 se zyada honi chahiye.');
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

    if (stockIssues.isNotEmpty)
      return ActionResult.stockZero(itemNames: stockIssues);
    if (billLines.isEmpty)
      return ActionResult.error(message: 'Koi valid item nahi mila.');

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
    final taxStr = '${state.taxType == 'inclusive'
        ? 'Inclusive'
        : 'Exclusive'} GST: ₹$gstAmount';

    return ActionResult.success(
      reply: '✅ Bill $billNumber bana diya!\n${c.name} | ${billLines
          .length} item(s)'
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
      tableData: billLines.map((l) =>
      {
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
        suppliers: all.map((s) =>
        {
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

  Future<ActionResult> _createPurchaseBillNow(SupplierModel supplier,
      List<dynamic> rawItems,
      Map<String, dynamic> data,) async {
    final billLines = <Map<String, dynamic>>[];

    for (final raw in rawItems) {
      final m = raw as Map<String, dynamic>;
      final itemName = (m['name'] as String? ?? '').trim();
      if (itemName.isEmpty) continue;

      var item = await _db.getItemByName(itemName) ??
          await _db.getItemFuzzy(itemName);
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
        return ActionResult.error(
            message: '"${item.name}" ki quantity 0 se zyada honi chahiye.');
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

    if (billLines.isEmpty)
      return ActionResult.error(message: 'Koi valid item nahi mila.');

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
      reply: '✅ Purchase Bill $billNumber bana diya!\n${supplier
          .name} | ${billLines
          .length} item(s)\nTotal: ₹$totalAmount\n(Stock updated ✓)',
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
      tableData: billLines.map((l) =>
      {
        'Item': l['item_name'],
        'Qty': l['qty'].toString(),
        'Price': '₹${l['unit_price']}',
        'Tax': '${l['tax_rate']}%',
        'Total': '₹${l['line_total']}',
      }).toList(),
    );
  }


  // ══════════════════════════════════════════════════════════════════════
  //  EDIT SALE BILL
  // ══════════════════════════════════════════════════════════════════════
  Future<ActionResult> _editSaleBill(ParsedAction action) async {
    final billNumber = action.data['bill_number'] as String?;
    final editType = action.data['edit_type'] as String? ?? 'open';

    // Resolve bill — "latest" = most recent bill
    Map<String, dynamic>? billData;
    if (billNumber == 'latest' || billNumber == null) {
      final allBills = await _db.getAllSaleBills();
      if (allBills.isEmpty) return ActionResult.error(message: 'Koi sale bill nahi mila.');
      billData = allBills.first;
    } else {
      billData = await _db.getSaleBillByNumber(billNumber);
    }
    if (billData == null) {
      return ActionResult.error(message: '"$billNumber" bill nahi mila. Sahi bill number batao.');
    }

    final billId = billData['id'] as int;
    final actualBillNum = billData['bill_number'] as String;

    switch (editType) {
      case 'update_status':
        final newStatus = action.data['payment_status'] as String? ?? 'paid';
        await _db.updateSaleBillStatus(billId, newStatus);
        return ActionResult.success(reply: '✅ $actualBillNum — status "$newStatus" ho gaya!');

      case 'update_item_qty':
        final itemName = (action.data['item_name'] as String?)?.trim();
        final newQty = _toInt(action.data['new_qty']);
        if (itemName == null || newQty == null) {
          return ActionResult.error(message: 'Item name aur new qty batao.');
        }
        final lineItems = await _db.getSaleBillItems(billId);
        final lineIdx = lineItems.indexWhere((l) =>
        (l['item_name'] as String).toLowerCase() == itemName.toLowerCase());
        if (lineIdx == -1) {
          return ActionResult.error(message: '"$itemName" is bill mein nahi mila.');
        }
        final oldQty = lineItems[lineIdx]['qty'] as int;
        final itemId = lineItems[lineIdx]['item_id'] as int?;

        // Adjust stock: return old qty, deduct new qty
        if (itemId != null) {
          await _db.restoreItemStock(itemId, oldQty);
          final item = await _db.getItemById(itemId);
          if (item != null && item.qty != null && item.qty! < newQty) {
            // Rollback
            await _db.deductItemStock(itemId, oldQty);
            return ActionResult.stockInsufficient(
                itemName: item.name, requested: newQty, available: item.qty!);
          }
          await _db.deductItemStock(itemId, newQty);
        }

        // Update line item qty + recalculate line_total
        final unitPrice = (lineItems[lineIdx]['unit_price'] as num).toDouble();
        final taxRate = (lineItems[lineIdx]['tax_rate'] as num?)?.toDouble() ?? 0.0;
        final newLineBase = unitPrice * newQty;
        final newTaxAmt = double.parse((newLineBase * taxRate / 100).toStringAsFixed(2));
        final newLineTotal = double.parse((newLineBase + newTaxAmt).toStringAsFixed(2));

        await (await _db.database).update(
          'sale_bill_items',
          {'qty': newQty, 'tax_amount': newTaxAmt, 'line_total': newLineTotal},
          where: 'bill_id = ? AND item_name = ?',
          whereArgs: [billId, lineItems[lineIdx]['item_name']],
        );
        await _recalculateSaleBillTotals(billId);
        return ActionResult.success(
            reply: '✅ $actualBillNum — "$itemName" qty $oldQty → $newQty. Total recalculated ✓');

      case 'update_item_price':
        final itemName = (action.data['item_name'] as String?)?.trim();
        final newPrice = _toDouble(action.data['new_price']);
        if (itemName == null || newPrice == null) {
          return ActionResult.error(message: 'Item name aur new price batao.');
        }
        final lineItems = await _db.getSaleBillItems(billId);
        final lineIdx = lineItems.indexWhere((l) =>
        (l['item_name'] as String).toLowerCase() == itemName.toLowerCase());
        if (lineIdx == -1) {
          return ActionResult.error(message: '"$itemName" is bill mein nahi mila.');
        }
        final qty = lineItems[lineIdx]['qty'] as int;
        final taxRate = (lineItems[lineIdx]['tax_rate'] as num?)?.toDouble() ?? 0.0;
        final newLineBase = newPrice * qty;
        final newTaxAmt = double.parse((newLineBase * taxRate / 100).toStringAsFixed(2));
        final newLineTotal = double.parse((newLineBase + newTaxAmt).toStringAsFixed(2));
        await (await _db.database).update(
          'sale_bill_items',
          {'unit_price': newPrice, 'tax_amount': newTaxAmt, 'line_total': newLineTotal},
          where: 'bill_id = ? AND item_name = ?',
          whereArgs: [billId, lineItems[lineIdx]['item_name']],
        );
        await _recalculateSaleBillTotals(billId);
        return ActionResult.success(
            reply: '✅ $actualBillNum — "$itemName" price → ₹$newPrice. Total recalculated ✓');

      case 'add_item':
        final addItemName = (action.data['item_name'] as String?)?.trim();
        final addQty = _toInt(action.data['qty']) ?? 1;
        if (addItemName == null || addItemName.isEmpty) {
          return ActionResult.error(message: 'Konsa item add karna hai?');
        }
        final addItem = await _db.getItemByName(addItemName) ??
            await _db.getItemFuzzy(addItemName);
        if (addItem == null) {
          return ActionResult.error(message: '"$addItemName" item DB mein nahi mila.');
        }
        if (addItem.qty != null && addItem.qty! < addQty) {
          return ActionResult.stockInsufficient(
              itemName: addItem.name, requested: addQty, available: addItem.qty!);
        }
        final addPrice = _toDouble(action.data['price']) ?? addItem.price ?? 0.0;
        final addTaxRate = _toDouble(action.data['tax_rate']) ?? 0.0;
        final addTaxAmt = double.parse((addPrice * addQty * addTaxRate / 100).toStringAsFixed(2));
        final addLineTotal = double.parse((addPrice * addQty + addTaxAmt).toStringAsFixed(2));
        await _db.insertSaleBillItem({
          'bill_id': billId,
          'item_id': addItem.id,
          'item_name': addItem.name,
          'qty': addQty,
          'unit_price': addPrice,
          'discount_amount': 0.0,
          'tax_rate': addTaxRate,
          'tax_amount': addTaxAmt,
          'line_total': addLineTotal,
        });
        if (addItem.id != null) await _db.deductItemStock(addItem.id!, addQty);
        await _recalculateSaleBillTotals(billId);
        return ActionResult.success(
            reply: '✅ $actualBillNum mein "${addItem.name}" x$addQty add ho gaya. Total recalculated ✓');

      case 'remove_item':
        final removeItemName = (action.data['item_name'] as String?)?.trim();
        if (removeItemName == null) {
          return ActionResult.error(message: 'Konsa item remove karna hai?');
        }
        final removeLines = await _db.getSaleBillItems(billId);
        final removeLine = removeLines.firstWhere(
              (l) => (l['item_name'] as String).toLowerCase() == removeItemName.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (removeLine.isEmpty) {
          return ActionResult.error(message: '"$removeItemName" is bill mein nahi mila.');
        }
        final removeItemId = removeLine['item_id'] as int?;
        final removeQty = removeLine['qty'] as int;
        if (removeItemId != null) await _db.restoreItemStock(removeItemId, removeQty);
        await (await _db.database).delete(
          'sale_bill_items',
          where: 'bill_id = ? AND item_name = ?',
          whereArgs: [billId, removeLine['item_name']],
        );
        await _recalculateSaleBillTotals(billId);
        return ActionResult.success(
            reply: '✅ $actualBillNum se "${removeLine["item_name"]}" remove ho gaya. Stock restored ✓');

      case 'open':
      default:
      // Show current bill for user to see before editing
        final lineItems = await _db.getSaleBillItems(billId);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '$actualBillNum — edit ke liye:',
          detailCard: {
            'type': 'sale_bill',
            'bill_id': billId,
            'Bill No': actualBillNum,
            'Customer': billData['customer_name'] ?? '-',
            'Date': billData['bill_date'] ?? '-',
            'Total': '₹${billData['total_amount']}',
            'Status': billData['payment_status'] ?? '-',
            'Payment': billData['payment_mode'] ?? '-',
          },
          tableData: lineItems.map((l) => {
            'Item': l['item_name'],
            'Qty': l['qty'].toString(),
            'Price': '₹${l['unit_price']}',
            'Tax': '${l['tax_rate']}%',
            'Total': '₹${l['line_total']}',
          }).toList(),
        );
    }
  }

  Future<void> _recalculateSaleBillTotals(int billId) async {
    final db = await _db.database;
    final lines = await _db.getSaleBillItems(billId);
    final subtotal = double.parse(
        lines.fold<double>(0, (s, l) => s + (l['unit_price'] as num).toDouble() * (l['qty'] as int))
            .toStringAsFixed(2));
    final gstAmount = double.parse(
        lines.fold<double>(0, (s, l) => s + (l['tax_amount'] as num).toDouble())
            .toStringAsFixed(2));
    // Get existing discount
    final billRow = await db.query('sale_bills', where: 'id = ?', whereArgs: [billId]);
    final discountAmt = billRow.isEmpty ? 0.0 : (billRow.first['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = double.parse((subtotal - discountAmt + gstAmount).toStringAsFixed(2));
    await db.update('sale_bills',
        {'subtotal': subtotal, 'gst_amount': gstAmount, 'total_amount': totalAmount},
        where: 'id = ?', whereArgs: [billId]);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  EDIT PURCHASE BILL
  // ══════════════════════════════════════════════════════════════════════
  Future<ActionResult> _editPurchaseBill(ParsedAction action) async {
    final billNumber = action.data['bill_number'] as String?;
    final editType = action.data['edit_type'] as String? ?? 'open';

    Map<String, dynamic>? billData;
    if (billNumber == null || billNumber == 'latest') {
      final allBills = await _db.getAllPurchaseBills();
      if (allBills.isEmpty) return ActionResult.error(message: 'Koi purchase bill nahi mila.');
      billData = allBills.first;
    } else {
      billData = await _db.getPurchaseBillByNumber(billNumber);
    }
    if (billData == null) {
      return ActionResult.error(message: '"$billNumber" purchase bill nahi mila.');
    }

    final billId = billData['id'] as int;
    final actualNum = billData['bill_number'] as String;

    switch (editType) {
      case 'update_status':
        final ns = action.data['payment_status'] as String? ?? 'paid';
        await _db.updatePurchaseBillStatus(billId, ns);
        return ActionResult.success(reply: '✅ $actualNum — "$ns" ho gaya!');

      case 'add_item':
        final addItemName = (action.data['item_name'] as String?)?.trim();
        final addQty = _toInt(action.data['qty']) ?? 1;
        final addPrice = _toDouble(action.data['price']) ?? 0.0;
        if (addItemName == null) return ActionResult.error(message: 'Item naam batao.');
        if (addPrice <= 0) return ActionResult.error(message: '"$addItemName" ki price batao.');
        var addItem = await _db.getItemByName(addItemName) ?? await _db.getItemFuzzy(addItemName);
        if (addItem == null) {
          // Auto-create item in purchase flow with given price
          final newId = await _db.insertItem(ItemModel(
            name: addItemName, qty: 0, price: addPrice,
          ));
          addItem = await _db.getItemById(newId);
        }
        if (addItem == null) return ActionResult.error(message: '"$addItemName" item nahi mila.');
        final taxRate = _toDouble(action.data['tax_rate']) ?? 0.0;
        final taxAmt = double.parse((addPrice * addQty * taxRate / 100).toStringAsFixed(2));
        final lineTotal = double.parse((addPrice * addQty + taxAmt).toStringAsFixed(2));
        await _db.insertPurchaseBillItem({
          'bill_id': billId, 'item_id': addItem.id, 'item_name': addItem.name,
          'qty': addQty, 'unit_price': addPrice,
          'tax_rate': taxRate, 'tax_amount': taxAmt, 'line_total': lineTotal,
        });
        if (addItem.id != null) await _db.addItemStock(addItem.id!, addQty);
        await _recalculatePurchaseBillTotals(billId);
        return ActionResult.success(reply: '✅ $actualNum mein "${addItem.name}" x$addQty add ✓');

      case 'remove_item':
        final removeItemName = (action.data['item_name'] as String?)?.trim();
        if (removeItemName == null) return ActionResult.error(message: 'Item naam batao.');
        final lines = await _db.getPurchaseBillItems(billId);
        final line = lines.firstWhere(
                (l) => (l['item_name'] as String).toLowerCase() == removeItemName.toLowerCase(),
            orElse: () => <String, dynamic>{});
        if (line.isEmpty) return ActionResult.error(message: '"$removeItemName" is bill mein nahi mila.');
        final rmItemId = line['item_id'] as int?;
        final rmQty = line['qty'] as int;
        if (rmItemId != null) await _db.deductItemStock(rmItemId, rmQty);
        await (await _db.database).delete('purchase_bill_items',
            where: 'bill_id = ? AND item_name = ?',
            whereArgs: [billId, line['item_name']]);
        await _recalculatePurchaseBillTotals(billId);
        return ActionResult.success(reply: '✅ $actualNum se "${line["item_name"]}" remove ✓');

      case 'open':
      default:
        final lineItems = await _db.getPurchaseBillItems(billId);
        return ActionResult.success(
          reply: action.reply.isNotEmpty ? action.reply : '$actualNum:',
          detailCard: {
            'type': 'purchase_bill', 'bill_id': billId, 'Bill No': actualNum,
            'Supplier': billData['supplier_name'] ?? '-',
            'Date': billData['bill_date'] ?? '-',
            'Total': '₹${billData['total_amount']}',
            'Status': billData['payment_status'] ?? '-',
          },
          tableData: lineItems.map((l) => {
            'Item': l['item_name'], 'Qty': l['qty'].toString(),
            'Price': '₹${l['unit_price']}', 'Tax': '${l['tax_rate']}%',
            'Total': '₹${l['line_total']}',
          }).toList(),
        );
    }
  }

  Future<void> _recalculatePurchaseBillTotals(int billId) async {
    final db = await _db.database;
    final lines = await _db.getPurchaseBillItems(billId);
    final subtotal = double.parse(
        lines.fold<double>(0, (s, l) => s + (l['unit_price'] as num).toDouble() * (l['qty'] as int))
            .toStringAsFixed(2));
    final taxAmount = double.parse(
        lines.fold<double>(0, (s, l) => s + (l['tax_amount'] as num).toDouble())
            .toStringAsFixed(2));
    final total = double.parse((subtotal + taxAmount).toStringAsFixed(2));
    await db.update('purchase_bills',
        {'subtotal': subtotal, 'tax_amount': taxAmount, 'total_amount': total},
        where: 'id = ?', whereArgs: [billId]);
  }

  // ══════════════════════════════════════════════════════════════════════
  //  BULK UPDATE PRICES
  // ══════════════════════════════════════════════════════════════════════
  Future<ActionResult> _bulkUpdatePrices(ParsedAction action) async {
    final changeType = action.data['change_type'] as String? ?? 'percent'; // 'percent' | 'amount'
    final changeValue = _toDouble(action.data['change_value']) ?? 0;
    final direction = action.data['direction'] as String? ?? 'increase'; // 'increase' | 'decrease'
    final targetNames = action.data['item_names'] as List<dynamic>?;

    if (changeValue <= 0) {
      return ActionResult.error(message: 'Change value batao. Example: "10% badha do" ya "50 rupee kam karo"');
    }

    final items = targetNames != null && targetNames.isNotEmpty
        ? await Future.wait(targetNames.map((n) async =>
    await _db.getItemByName(n.toString()) ?? await _db.getItemFuzzy(n.toString())))
        .then((list) => list.whereType<dynamic>().toList())
        : await _db.getAllItems();

    if (items.isEmpty) return ActionResult.error(message: 'Koi item nahi mila.');

    int updated = 0;
    for (final item in items) {
      if (item == null) continue;
      final currentPrice = item.price ?? 0.0;
      double newPrice;
      if (changeType == 'percent') {
        newPrice = direction == 'increase'
            ? currentPrice * (1 + changeValue / 100)
            : currentPrice * (1 - changeValue / 100);
      } else {
        newPrice = direction == 'increase'
            ? currentPrice + changeValue
            : currentPrice - changeValue;
      }
      if (newPrice <= 0) newPrice = 0.01;
      newPrice = double.parse(newPrice.toStringAsFixed(2));
      await _db.updateItem(item.copyWith(price: newPrice));
      updated++;
    }

    final op = direction == 'increase' ? '+' : '-';
    final unit = changeType == 'percent' ? '$changeValue%' : '₹$changeValue';
    return ActionResult.success(
        reply: '✅ $updated items ki price $op$unit kar diya gaya!');
  }

  // ══════════════════════════════════════════════════════════════════════
  //  MARK MULTIPLE BILLS PAID
  // ══════════════════════════════════════════════════════════════════════
  Future<ActionResult> _markMultipleBillsPaid(ParsedAction action) async {
    final customerName = action.data['customer_name'] as String?;
    final filter = action.data['filter'] as String? ?? 'all_unpaid'; // 'today', 'all_unpaid'

    var bills = await _db.getAllSaleBills();

    // Filter by customer
    if (customerName != null && customerName.isNotEmpty) {
      bills = bills.where((b) =>
          (b['customer_name'] as String? ?? '').toLowerCase().contains(customerName.toLowerCase()))
          .toList();
    }

    // Filter by date
    if (filter == 'today') {
      final today = DateTime.now().toIso8601String().split('T')[0];
      bills = bills.where((b) => b['bill_date'] == today).toList();
    }

    // Keep only unpaid/partial
    bills = bills.where((b) =>
    b['payment_status'] == 'unpaid' || b['payment_status'] == 'partial').toList();

    if (bills.isEmpty) {
      return ActionResult.success(
          reply: '✅ Koi unpaid bill nahi mila${customerName != null ? " ($customerName)" : ""}.');
    }

    for (final bill in bills) {
      await _db.updateSaleBillStatus(bill['id'] as int, 'paid');
    }

    final totalMarked = bills.length;
    final totalAmt = bills.fold<double>(0, (s, b) => s + ((b['total_amount'] as num?)?.toDouble() ?? 0));
    return ActionResult.success(
        reply: '✅ $totalMarked bills paid mark ho gaye! Total: ₹${totalAmt.toStringAsFixed(2)}',
        tableData: bills.map((b) => {
          'Bill': b['bill_number'],
          'Customer': b['customer_name'] ?? '-',
          'Amount': '₹${b['total_amount']}',
        }).toList());
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SEARCH BILLS
  // ══════════════════════════════════════════════════════════════════════
  Future<ActionResult> _searchBills(ParsedAction action) async {
    final billType = action.data['bill_type'] as String? ?? 'sale';
    final customerName = action.data['customer_name'] as String?;
    final supplierName = action.data['supplier_name'] as String?;
    final status = action.data['status'] as String?;
    final amountAround = _toDouble(action.data['amount_around']);
    final dateRange = action.data['date_range'] as String?;

    if (billType == 'purchase') {
      var bills = await _db.getAllPurchaseBills();
      if (supplierName != null) {
        bills = bills.where((b) => (b['supplier_name'] as String? ?? '').toLowerCase().contains(supplierName.toLowerCase())).toList();
      }
      if (status != null) bills = bills.where((b) => b['payment_status'] == status).toList();
      if (amountAround != null) {
        bills = bills.where((b) {
          final amt = (b['total_amount'] as num?)?.toDouble() ?? 0;
          return (amt - amountAround).abs() <= amountAround * 0.15;
        }).toList();
      }
      if (bills.isEmpty) return ActionResult.success(reply: 'Koi purchase bill nahi mila.', tableData: []);
      return ActionResult.success(
        reply: '${bills.length} purchase bill(s) mile:',
        tableData: bills.take(20).map((b) => {
          'Bill': b['bill_number'], 'Supplier': b['supplier_name'] ?? '-',
          'Date': b['bill_date'], 'Amount': '₹${b['total_amount']}',
          'Status': b['payment_status'],
        }).toList(),
      );
    }

    // Sale bills
    var bills = await _db.getAllSaleBills();

    if (customerName != null) {
      bills = bills.where((b) =>
          (b['customer_name'] as String? ?? '').toLowerCase().contains(customerName.toLowerCase()))
          .toList();
    }
    if (status != null) {
      bills = bills.where((b) => b['payment_status'] == status).toList();
    }
    if (amountAround != null) {
      bills = bills.where((b) {
        final amt = (b['total_amount'] as num?)?.toDouble() ?? 0;
        return (amt - amountAround).abs() <= amountAround * 0.15;
      }).toList();
    }
    if (dateRange == 'last_week') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
      bills = bills.where((b) => (b['bill_date'] ?? '') >= weekAgo).toList();
    } else if (dateRange == 'today') {
      final today = DateTime.now().toIso8601String().split('T')[0];
      bills = bills.where((b) => b['bill_date'] == today).toList();
    }

    if (bills.isEmpty) return ActionResult.success(reply: 'Koi bill nahi mila.', tableData: []);

    return ActionResult.success(
      reply: '${bills.length} bill(s) mile:',
      tableData: bills.take(20).map((b) => {
        'Bill': b['bill_number'], 'Customer': b['customer_name'] ?? '-',
        'Date': b['bill_date'], 'Amount': '₹${b['total_amount']}',
        'Status': b['payment_status'],
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