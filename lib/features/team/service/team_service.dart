import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../model/team_member_model.dart';
import '../../../features/subscription/service/subscription_service.dart';
import '../../../firebase_options.dart';

class TeamService {
  static final TeamService instance = TeamService._internal();
  TeamService._internal();

  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;
  static const _uuid = Uuid();

  String get _myUid => _auth.currentUser!.uid;

  // ══════════════════════════════════════════════════════════════
  //  CREATE MEMBER ACCOUNT + ADD TO COMPANY
  //  Owner email + password dono set karta hai
  //  Secondary FirebaseApp se account create hota hai
  //  Owner ka session safe rehta hai
  // ══════════════════════════════════════════════════════════════
  Future<TeamServiceResult<TeamMemberModel>> addTeamMember({
    required String companyId,
    required String memberEmail,
    required String memberPassword,
    required String memberName,
    required TeamRole role,
    TeamPermissions? customPermissions,
    required int maxMembersAllowed,
  }) async {
    // ── Gold plan check ───────────────────────────────────────
    final sub = await SubscriptionService.instance.getSubscription();
    if (!sub.hasMultiUser) {
      return TeamServiceResult.error(
        'Team Members feature is only available on Gold Plan.\n'
            'You are currently on ${sub.planName} plan.',
      );
    }

    // ── Member limit check ────────────────────────────────────
    final currentMembers = await getCompanyMembers(companyId);
    if (currentMembers.length >= maxMembersAllowed) {
      return TeamServiceResult.error(
        'Maximum $maxMembersAllowed members allowed.\n'
            'Currently ${currentMembers.length} members.',
      );
    }

    // ── Duplicate email check ─────────────────────────────────
    final duplicate = currentMembers.any(
          (m) => m.memberEmail.toLowerCase() == memberEmail.toLowerCase().trim(),
    );
    if (duplicate) {
      return TeamServiceResult.error(
        '$memberEmail is already a member of this company.',
      );
    }

    // ── Password validation ───────────────────────────────────
    if (memberPassword.trim().length < 6) {
      return TeamServiceResult.error(
        'Password must be at least 6 characters.',
      );
    }

    // ── Create Firebase Auth account via Secondary App ────────
    // This does NOT affect the owner's current login session
    String memberUid;
    try {
      memberUid = await _createMemberAccount(
        email:    memberEmail.trim().toLowerCase(),
        password: memberPassword.trim(),
        name:     memberName.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Account already exists — fetch their UID from Firestore
        final existing = await _db
            .collection('users')
            .where('email', isEqualTo: memberEmail.toLowerCase().trim())
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          memberUid = existing.docs.first.id;
        } else {
          return TeamServiceResult.error(
            'This email is already registered but not found in users.\n'
                'Ask them to login with their existing password.',
          );
        }
      } else {
        return TeamServiceResult.error(
          'Failed to create account: ${e.message}',
        );
      }
    } catch (e) {
      return TeamServiceResult.error('Account creation failed: $e');
    }

    // ── Permissions ───────────────────────────────────────────
    final permissions = customPermissions ??
        (role == TeamRole.editor
            ? TeamPermissions.editorFull()
            : TeamPermissions.viewerDefault());

    // ── Save to Firestore ─────────────────────────────────────
    try {
      final id = _uuid.v4();
      final member = TeamMemberModel(
        id:          id,
        companyId:   companyId,
        ownerUid:    _myUid,
        memberEmail: memberEmail.trim().toLowerCase(),
        memberName:  memberName.trim(),
        memberUid:   memberUid,
        role:        role,
        permissions: permissions,
        status:      'active',  // Direct active — account already created
        invitedAt:   DateTime.now(),
      );

      // Save member doc
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('members')
          .doc(id)
          .set(member.toMap());

      // Set team_access so member can login immediately
      await _setTeamAccess(memberUid, companyId, member);

      return TeamServiceResult.success(member);
    } catch (e) {
      return TeamServiceResult.error('Failed to save member: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  PRIVATE: Create Firebase Auth account via Secondary App
  //  Secondary app use karte hain taaki owner logout na ho
  // ══════════════════════════════════════════════════════════════
  Future<String> _createMemberAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    // Secondary Firebase App — unique name se init karo
    const secondaryAppName = 'SecondaryApp';

    FirebaseApp? secondaryApp;
    try {
      // Check if already initialized
      secondaryApp = Firebase.app(secondaryAppName);
    } catch (_) {
      // Not initialized yet — init karo
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    try {
      // Secondary app ka FirebaseAuth instance
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Create account
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email:    email,
        password: password,
      );

      final uid = credential.user!.uid;

      // Sign out from secondary app immediately
      await secondaryAuth.signOut();

      // Save user profile to Firestore
      // (member ka naam + email — basic profile)
      await _db.collection('users').doc(uid).set({
        'uid':        uid,
        'email':      email,
        'first_name': name,
        'last_name':  '',
        'company_name': '',
        'mobile':     '',
        'username':   email.split('@').first,
        'created_at': FieldValue.serverTimestamp(),
        'is_team_member': true, // flag to identify team members
      });

      return uid;
    } finally {
      // Secondary app delete karo — memory leak avoid karo
      try {
        await secondaryApp.delete();
      } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET COMPANY MEMBERS
  // ══════════════════════════════════════════════════════════════
  Future<List<TeamMemberModel>> getCompanyMembers(String companyId) async {
    try {
      final snap = await _db
          .collection('companies')
          .doc(companyId)
          .collection('members')
          .where('status', whereNotIn: ['removed'])
          .get();
      final list = snap.docs
          .map((d) => TeamMemberModel.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.invitedAt.compareTo(b.invitedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  UPDATE MEMBER PERMISSIONS / ROLE
  // ══════════════════════════════════════════════════════════════
  Future<TeamServiceResult<void>> updateMemberPermissions({
    required String companyId,
    required String memberId,
    required TeamRole newRole,
    required TeamPermissions newPermissions,
  }) async {
    try {
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('members')
          .doc(memberId)
          .update({
        'role':        newRole.name,
        'permissions': newPermissions.toMap(),
      });

      final memberDoc = await _db
          .collection('companies')
          .doc(companyId)
          .collection('members')
          .doc(memberId)
          .get();
      final memberUid = memberDoc.data()?['memberUid'] as String?;
      if (memberUid != null) {
        await _db.collection('team_access').doc(memberUid).update({
          'role':        newRole.name,
          'permissions': newPermissions.toMap(),
        });
      }
      return TeamServiceResult.success(null);
    } catch (e) {
      return TeamServiceResult.error('Update failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  REMOVE MEMBER
  // ══════════════════════════════════════════════════════════════
  Future<TeamServiceResult<void>> removeMember({
    required String companyId,
    required String memberId,
    required String? memberUid,
  }) async {
    try {
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('members')
          .doc(memberId)
          .update({'status': 'removed'});

      if (memberUid != null) {
        await _db.collection('team_access').doc(memberUid).delete();
      }
      return TeamServiceResult.success(null);
    } catch (e) {
      return TeamServiceResult.error('Remove failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  GET MY TEAM ACCESS (called at login by PermissionService)
  // ══════════════════════════════════════════════════════════════
  Future<TeamAccessInfo?> getMyTeamAccess() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    DocumentSnapshot<Map<String, dynamic>>? doc;

    // Try 1: Server fetch (fresh data)
    try {
      doc = await _db
          .collection('team_access')
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      print('✅ team_access fetched from server');
    } catch (e) {
      print('⚠️ Server fetch failed: $e — trying cache');
    }

    // Try 2: Cache fallback (works offline)
    if (doc == null || !doc.exists) {
      try {
        doc = await _db
            .collection('team_access')
            .doc(uid)
            .get(const GetOptions(source: Source.cache));
        if (doc.exists) {
          print('✅ team_access fetched from cache');
        } else {
          print('ℹ️ No team_access for uid=$uid — user is owner');
          return null;
        }
      } catch (e) {
        print('⚠️ Cache fetch also failed: $e');
        return null;
      }
    }

    if (!doc.exists || doc.data() == null) return null;

    final info = TeamAccessInfo.fromMap(doc.data()!);
    print('✅ TeamAccessInfo: member=${info.memberName} '
        'owner=${info.ownerUid} company=${info.companyId} '
        'role=${info.role.name}');
    return info;
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIVATE PENDING INVITE (legacy — kept for backwards compat)
  // ══════════════════════════════════════════════════════════════
  Future<void> activatePendingInvite(String uid, String email) async {
    try {
      final snap = await _db
          .collectionGroup('members')
          .where('memberEmail', isEqualTo: email.toLowerCase())
          .where('status', isEqualTo: 'invited')
          .get();

      for (final doc in snap.docs) {
        final member = TeamMemberModel.fromMap({...doc.data(), 'id': doc.id});
        await doc.reference.update({'memberUid': uid, 'status': 'active'});
        await _setTeamAccess(uid, member.companyId, member.copyWith(memberUid: uid));
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════
  Future<void> _setTeamAccess(
      String memberUid,
      String companyId,
      TeamMemberModel member,
      ) async {
    await _db.collection('team_access').doc(memberUid).set({
      'companyId':   companyId,
      'ownerUid':    member.ownerUid,
      'role':        member.role.name,
      'permissions': member.permissions.toMap(),
      'memberName':  member.memberName,
    });
  }
}