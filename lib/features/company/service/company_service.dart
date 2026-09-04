// lib/features/company/service/company_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../model/company_model.dart';
import '../../../database/app_database.dart';
import '../../../core/services/sync_service.dart';
import '../../subscription/service/subscription_service.dart';

class CompanyResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;
  const CompanyResult._({this.data, this.error});
  factory CompanyResult.ok(T? data) => CompanyResult._(data: data);
  factory CompanyResult.err(String msg) => CompanyResult._(error: msg);
}

class CompanyService {
  static final CompanyService instance = CompanyService._();
  CompanyService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  static const _uuid = Uuid();

  String get _uid => _auth.currentUser!.uid;

  // ════════════════════════════════════════════════════════
  //  CREATE DEFAULT COMPANY — signup pe call karo
  //  Har naye user ki pehli company ye banata hai
  //  Gold plan ki zaroorat NAHI — ye free/default company hai
  // ════════════════════════════════════════════════════════
  Future<void> createDefaultCompany({
    required String uid,
    required String companyName,
  }) async {
    try {
      // Check agar already company hai (re-signup edge case)
      final snap = await _firestore
          .collection('companies')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      String companyId;

      if (snap.docs.isNotEmpty) {
        // Already exists — just use it
        companyId = snap.docs.first.id;
      } else {
        // Naya company banao
        companyId = _uuid.v4();
        final company = CompanyModel(
          id:        companyId,
          ownerUid:  uid,
          name:      companyName.trim(),
          createdAt: DateTime.now(),
        );
        await _firestore
            .collection('companies')
            .doc(companyId)
            .set(company.toMap());

        // Subscription doc mein companies_count = 1
        await _firestore.collection('subscriptions').doc(uid).set(
          {'companies_count': 1},
          SetOptions(merge: true),
        );
      }

      // Switch SQLite DB to this company
      // billnex_{uid}.db → billnex_{uid}_{companyId}.db
      await AppDatabase.switchUser(uid);
      await AppDatabase.switchCompany(companyId);

      // Save as last active company
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_company_$uid', companyId);

      print('✅ Default company ready: $companyId');
    } catch (e) {
      print('❌ createDefaultCompany error: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  GET MY COMPANIES
  // ════════════════════════════════════════════════════════
  Future<List<CompanyModel>> getMyCompanies() async {
    try {
      final snap = await _firestore
          .collection('companies')
          .where('ownerUid', isEqualTo: _uid)
          .get();
      final list = snap.docs
          .map((d) => CompanyModel.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
  //  CREATE ADDITIONAL COMPANY
  //  Gold plan only — 2nd, 3rd... company ke liye
  // ════════════════════════════════════════════════════════
  Future<CompanyResult<CompanyModel>> createCompany({
    required String name,
    String? address,
    String? gstin,
    String? phone,
    String? email,
  }) async {
    final sub = await SubscriptionService.instance.getSubscription();

    final existing = await getMyCompanies();

    // Pehli company (index 0) already signup pe bani — koi plan check nahi
    // 2nd company se Gold plan check
    if (existing.length >= 1 && !sub.hasMultiCompany) {
      return CompanyResult.err(
        'Adding a second company requires Gold Plan.\n'
            'You are currently on ${sub.planName} plan.',
      );
    }

    if (existing.length >= sub.maxCompanies) {
      return CompanyResult.err(
        'Maximum ${sub.maxCompanies} companies allowed.\n'
            'You already have ${existing.length} companies.',
      );
    }

    final duplicate = existing.any(
          (c) => c.name.toLowerCase().trim() == name.toLowerCase().trim(),
    );
    if (duplicate) {
      return CompanyResult.err('A company named "$name" already exists.');
    }

    try {
      final id = _uuid.v4();
      final company = CompanyModel(
        id:        id,
        ownerUid:  _uid,
        name:      name.trim(),
        address:   address?.trim(),
        gstin:     gstin?.trim(),
        phone:     phone?.trim(),
        email:     email?.trim(),
        createdAt: DateTime.now(),
      );
      await _firestore.collection('companies').doc(id).set(company.toMap());
      await _firestore
          .collection('subscriptions')
          .doc(_uid)
          .update({'companies_count': FieldValue.increment(1)});

      return CompanyResult.ok(company);
    } catch (e) {
      return CompanyResult.err('Failed to create company: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  SWITCH COMPANY
  // ════════════════════════════════════════════════════════
  Future<void> switchToCompany(String? companyId) async {
    final uid = _uid;

    // 1. Upload current DB
    try {
      await FirebaseSyncService.uploadDatabase()
          .timeout(const Duration(seconds: 5));
    } catch (_) {}

    // 2. Switch SQLite file
    await AppDatabase.switchCompany(companyId);

    // 3. Download target DB
    try {
      if (companyId != null) {
        await FirebaseSyncService.downloadCompanyDb(uid, companyId)
            .timeout(const Duration(seconds: 8));
      } else {
        await FirebaseSyncService.downloadDatabase()
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {}

    // 4. Persist
    final prefs = await SharedPreferences.getInstance();
    if (companyId != null) {
      await prefs.setString('active_company_$uid', companyId);
    } else {
      await prefs.remove('active_company_$uid');
    }
  }

  Future<void> switchToDefault() => switchToCompany(null);

  // ════════════════════════════════════════════════════════
  //  UPDATE COMPANY
  // ════════════════════════════════════════════════════════
  Future<CompanyResult<void>> updateCompany(CompanyModel company) async {
    if (company.ownerUid != _uid) {
      return CompanyResult.err('Only the owner can edit this company.');
    }
    try {
      await _firestore.collection('companies').doc(company.id).update({
        'name':    company.name,
        'address': company.address,
        'gstin':   company.gstin,
        'phone':   company.phone,
        'email':   company.email,
      });
      return CompanyResult.ok(null);
    } catch (e) {
      return CompanyResult.err('Update failed: $e');
    }
  }

  // ════════════════════════════════════════════════════════
  //  DELETE COMPANY
  // ════════════════════════════════════════════════════════
  Future<CompanyResult<void>> deleteCompany(String companyId) async {
    try {
      final members = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('team_members')
          .get();

      final batch = _firestore.batch();
      for (final m in members.docs) {
        final memberUid = m.data()['memberUid'] as String?;
        if (memberUid != null) {
          batch.delete(_firestore.collection('team_access').doc(memberUid));
        }
        batch.delete(m.reference);
      }
      batch.delete(_firestore.collection('companies').doc(companyId));
      await batch.commit();

      await _firestore
          .collection('subscriptions')
          .doc(_uid)
          .update({'companies_count': FieldValue.increment(-1)});

      // Clear from prefs if it was the active company
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('active_company_$_uid');
      if (saved == companyId) await prefs.remove('active_company_$_uid');

      return CompanyResult.ok(null);
    } catch (e) {
      return CompanyResult.err('Delete failed: $e');
    }
  }
}