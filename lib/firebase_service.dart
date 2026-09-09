import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// FirebaseService wraps all Firestore reads/writes.
///
/// Data structure:
///   households/{householdId}/
///     config          (document)  – roomName, roommates[], inviteCode
///     expenses/       (collection)
///     settlements/    (collection)
///     chores/         (collection)
///     chore_templates/(collection)
///     grocery/        (collection)
///     meta            (document)  – lastGeneratedWeek, joinedBy{}
///
///   users/{uid}/
///     fcmTokens       (array)     – FCM registration tokens for this user
class FirebaseService {
  static const _uuid = Uuid();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Auth ────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Sends a verification email to the currently signed-in user.
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Re-fetches the user profile from Firebase and returns whether the
  /// email address has been verified.
  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Stores "householdId:roommateId" in the user's displayName, then
  /// force-refreshes the ID token so the new name is immediately available
  /// to Firestore security rules.
  Future<void> linkUserToHousehold(
      String householdId, String roommateId) async {
    await _auth.currentUser?.updateDisplayName('$householdId:$roommateId');
    await _auth.currentUser?.getIdToken(true); // force token refresh
  }

  /// Returns [householdId, roommateId] or null if not linked.
  List<String>? get currentUserBinding {
    final dn = _auth.currentUser?.displayName;
    if (dn == null || !dn.contains(':')) return null;
    return dn.split(':');
  }

  // ── Household Setup ─────────────────────────────────────────────

  static String generateId() => _uuid.v4();

  Future<String> createHousehold(
      String roomName, List<Roommate> roommates) async {
    final householdId = generateId();
    final inviteCode = _generateInviteCode();

    await _db.collection('households').doc(householdId).set({
      'roomName': roomName,
      'numberOfRoommates': roommates.length,
      'roommates': roommates.map((r) => r.toJson()).toList(),
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _householdRef(householdId).collection('meta').doc('data').set({
      'lastGeneratedWeek': -1,
      'joinedBy': <String, String>{}, // roommateId -> uid
    });

    return householdId;
  }

  Future<String?> findHouseholdByInviteCode(String code) async {
    final snap = await _db
        .collection('households')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  // ── Streams ─────────────────────────────────────────────────────

  DocumentReference _householdRef(String hId) =>
      _db.collection('households').doc(hId);

  CollectionReference _col(String hId, String col) =>
      _householdRef(hId).collection(col);

  Stream<RoomConfig?> streamConfig(String householdId) {
    return _householdRef(householdId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return RoomConfig.fromJson(snap.data() as Map<String, dynamic>);
    });
  }

  Stream<List<Expense>> streamExpenses(String householdId) {
    return _col(householdId, 'expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Expense.fromJson(d.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<Settlement>> streamSettlements(String householdId) {
    return _col(householdId, 'settlements')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Settlement.fromJson(d.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<Chore>> streamChores(String householdId) {
    return _col(householdId, 'chores').orderBy('dueDate').snapshots().map(
        (snap) => snap.docs
            .map((d) => Chore.fromJson(d.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<ChoreTemplate>> streamChoreTemplates(String householdId) {
    return _col(householdId, 'chore_templates').snapshots().map((snap) => snap
        .docs
        .map((d) => ChoreTemplate.fromJson(d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<GroceryItem>> streamGrocery(String householdId) {
    return _col(householdId, 'grocery').orderBy('name').snapshots().map(
        (snap) => snap.docs
            .map((d) => GroceryItem.fromJson(d.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<int> streamLastGeneratedWeek(String householdId) {
    return _householdRef(householdId)
        .collection('meta')
        .doc('data')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return -1;
      return (snap.data())?['lastGeneratedWeek'] as int? ?? -1;
    });
  }

  /// Streams the joinedBy map: { roommateId: uid }
  Stream<Map<String, String>> streamJoinedBy(String householdId) {
    return _householdRef(householdId)
        .collection('meta')
        .doc('data')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return <String, String>{};
      final raw = (snap.data())?['joinedBy'] as Map<String, dynamic>? ?? {};
      return raw.map((k, v) => MapEntry(k, v as String));
    });
  }

  // ── FCM Token Management ──────────────────────────────────────────

  /// Saves [token] under users/{uid}/fcmTokens (array).
  /// Safe to call multiple times — uses arrayUnion so no duplicates.
  Future<void> saveFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token])
      },
      SetOptions(merge: true),
    );
  }

  /// Removes a stale [token] (call from onTokenRefresh before saving the new one).
  Future<void> removeFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update(
      {
        'fcmTokens': FieldValue.arrayRemove([token])
      },
    );
  }

  // ── Expense Writes ───────────────────────────────────────────────

  Future<void> addExpense(String householdId, Expense expense) async {
    await _col(householdId, 'expenses').doc(expense.id).set(expense.toJson());
  }

  Future<void> deleteExpense(String householdId, String expenseId) async {
    await _col(householdId, 'expenses').doc(expenseId).delete();
  }

  /// Called by a participant (not the payer) to confirm their share is correct.
  Future<void> confirmExpenseShare(
      String householdId, String expenseId, String roommateId) async {
    await _col(householdId, 'expenses').doc(expenseId).update({
      'confirmedBy': FieldValue.arrayUnion([roommateId]),
      'disputedBy': FieldValue.arrayRemove([roommateId]),
    });
  }

  /// Called by a participant to flag an expense as wrong.
  Future<void> disputeExpenseShare(
      String householdId, String expenseId, String roommateId) async {
    await _col(householdId, 'expenses').doc(expenseId).update({
      'disputedBy': FieldValue.arrayUnion([roommateId]),
      'confirmedBy': FieldValue.arrayRemove([roommateId]),
    });
  }

  // ── Settlement Writes ────────────────────────────────────────────

  /// Debtor proposes a settlement — starts out pending until the creditor acts.
  Future<void> addSettlement(String householdId, Settlement settlement) async {
    await _col(householdId, 'settlements')
        .doc(settlement.id)
        .set(settlement.toJson());
  }

  /// Creditor confirms they actually received the payment.
  Future<void> confirmSettlement(
      String householdId, String settlementId) async {
    await _col(householdId, 'settlements').doc(settlementId).update({
      'confirmedByCreditor': true,
      'rejectedByCreditor': false,
    });
  }

  /// Creditor disputes the debtor's "I paid" claim.
  Future<void> rejectSettlement(String householdId, String settlementId) async {
    await _col(householdId, 'settlements').doc(settlementId).update({
      'confirmedByCreditor': false,
      'rejectedByCreditor': true,
    });
  }

  Future<void> deleteSettlement(String householdId, String settlementId) async {
    await _col(householdId, 'settlements').doc(settlementId).delete();
  }

  // ── Chore Writes ─────────────────────────────────────────────────

  Future<void> addChore(String householdId, Chore chore) async {
    await _col(householdId, 'chores').doc(chore.id).set(chore.toJson());
  }

  Future<void> toggleChore(
      String householdId, String choreId, bool newValue) async {
    await _col(householdId, 'chores')
        .doc(choreId)
        .update({'isCompleted': newValue});
  }

  Future<void> deleteChore(String householdId, String choreId) async {
    await _col(householdId, 'chores').doc(choreId).delete();
  }

  Future<void> generateWeeklyChores(
    String householdId,
    List<Chore> newChores,
    int weekNumber,
  ) async {
    final batch = _db.batch();

    final existing = await _col(householdId, 'chores')
        .where('templateId', isNull: false)
        .where('isCompleted', isEqualTo: false)
        .get();

    for (final doc in existing.docs) {
      final chore = Chore.fromJson(doc.data() as Map<String, dynamic>);
      if (_isoWeek(chore.dueDate) == weekNumber) {
        batch.delete(doc.reference);
      }
    }

    for (final chore in newChores) {
      batch.set(_col(householdId, 'chores').doc(chore.id), chore.toJson());
    }

    batch.set(
      _householdRef(householdId).collection('meta').doc('data'),
      {'lastGeneratedWeek': weekNumber},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ── Chore Template Writes ─────────────────────────────────────────

  Future<void> addChoreTemplate(
      String householdId, ChoreTemplate template) async {
    await _col(householdId, 'chore_templates')
        .doc(template.id)
        .set(template.toJson());
  }

  Future<void> deleteChoreTemplate(
      String householdId, String templateId) async {
    await _col(householdId, 'chore_templates').doc(templateId).delete();
  }

  Future<void> updateChoreTemplate(
      String householdId, ChoreTemplate template) async {
    await _col(householdId, 'chore_templates')
        .doc(template.id)
        .set(template.toJson());
  }

  // ── Grocery Writes ────────────────────────────────────────────────

  Future<void> addGroceryItem(String householdId, GroceryItem item) async {
    await _col(householdId, 'grocery').doc(item.id).set(item.toJson());
  }

  Future<void> toggleGroceryItem(
      String householdId, String itemId, bool newValue) async {
    await _col(householdId, 'grocery')
        .doc(itemId)
        .update({'isPurchased': newValue});
  }

  Future<void> deleteGroceryItem(String householdId, String itemId) async {
    await _col(householdId, 'grocery').doc(itemId).delete();
  }

  Future<void> clearPurchasedItems(String householdId) async {
    final snap = await _col(householdId, 'grocery')
        .where('isPurchased', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Roommate Config Writes ────────────────────────────────────────

  Future<void> updateRoommateInConfig(
      String householdId, Roommate updated, List<Roommate> allRoommates) async {
    final idx = allRoommates.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    final list = List<Roommate>.from(allRoommates);
    list[idx] = updated;
    await _householdRef(householdId).update({
      'roommates': list.map((r) => r.toJson()).toList(),
    });
  }

  // ── joinedBy tracking ─────────────────────────────────────────────

  /// Records that the current user has claimed [roommateId].
  /// Also removes any previous claim this user had in the household.
  Future<void> claimRoommateSlot(String householdId, String roommateId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Read existing joinedBy to remove old claim by this uid
    final metaRef = _householdRef(householdId).collection('meta').doc('data');
    final snap = await metaRef.get();
    final raw = (snap.data()?['joinedBy'] as Map<String, dynamic>? ?? {});

    final updated = Map<String, dynamic>.from(raw);
    // Remove any old entry by this uid
    updated.removeWhere((_, v) => v == uid);
    // Set new claim
    updated[roommateId] = uid;

    await metaRef.set({'joinedBy': updated}, SetOptions(merge: true));
  }

  /// Returns a snapshot of which roommateIds are already claimed.
  Future<Map<String, String>> getJoinedBy(String householdId) async {
    final snap =
        await _householdRef(householdId).collection('meta').doc('data').get();
    if (!snap.exists) return {};
    final raw = (snap.data())?['joinedBy'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, v as String));
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = _uuid.v4().replaceAll('-', '');
    return List.generate(
        6, (i) => chars[int.parse(seed[i], radix: 16) % chars.length]).join();
  }

  static int _isoWeek(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}
