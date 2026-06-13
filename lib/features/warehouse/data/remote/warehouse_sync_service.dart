import 'package:cloud_firestore/cloud_firestore.dart';

class WarehouseSyncService {
  WarehouseSyncService._internal();
  static final WarehouseSyncService instance = WarehouseSyncService._internal();

  final _fire = FirebaseFirestore.instance;

  Future<void> pushWarehouse(Map<String, dynamic> payload) async {
    final col = _fire.collection('warehouses');
    if (payload['id'] != null) {
      await col.doc(payload['id'].toString()).set(payload);
    } else {
      await col.add(payload);
    }
  }

  Future<void> pushTransfer(Map<String, dynamic> payload) async {
    final col = _fire.collection('stock_transfers');
    await col.add(payload);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWarehouses() => _fire.collection('warehouses').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransfers() => _fire.collection('stock_transfers').snapshots();
}
