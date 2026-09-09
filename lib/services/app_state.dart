import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roommate_manager/firebase_service.dart';
import '../models/models.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  final FirebaseService _fb = FirebaseService();

  // ── Identifiers ─────────────────────────────────────────────────
  String? _householdId;
  String? _currentRoommateId;

  String? get householdId => _householdId;
  String? get currentRoommateId => _currentRoommateId;

  // ── Stream subscriptions ─────────────────────────────────────────
  StreamSubscription<User?>? _authSub;
  StreamSubscription<RoomConfig?>? _configSub;
  StreamSubscription<List<Expense>>? _expensesSub;
  StreamSubscription<List<Settlement>>? _settlementsSub;
  StreamSubscription<List<Chore>>? _choresSub;
  StreamSubscription<List<ChoreTemplate>>? _templatesSub;
  StreamSubscription<List<GroceryItem>>? _grocerySub;
  StreamSubscription<int>? _weekSub;
  StreamSubscription<Map<String, String>>? _joinedBySub;

  // ── Local state mirrors ──────────────────────────────────────────
  RoomConfig? _roomConfig;
  List<Expense> _expenses = [];
  List<Settlement> _settlements = [];
  List<Chore> _chores = [];
  List<GroceryItem> _groceryItems = [];
  List<ChoreTemplate> _choreTemplates = [];
  int _lastGeneratedWeek = -1;
  bool _isLoading = true;
  bool _autoGenerating = false;
  bool _isAuthenticated = false;

  /// Maps roommateId → uid for all claimed slots.
  Map<String, String> _joinedBy = {};
  Map<String, String> get joinedBy => Map.unmodifiable(_joinedBy);

  // ── Getters ──────────────────────────────────────────────────────
  RoomConfig? get roomConfig => _roomConfig;
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<Settlement> get settlements => List.unmodifiable(_settlements);
  List<Chore> get chores => List.unmodifiable(_chores);
  List<GroceryItem> get groceryItems => List.unmodifiable(_groceryItems);
  List<ChoreTemplate> get choreTemplates => List.unmodifiable(_choreTemplates);
  bool get isLoading => _isLoading;
  bool get isSetup => _roomConfig != null && _householdId != null;
  bool get needsEmailVerification => _isAuthenticated && !_fb.isEmailVerified;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserEmail => _fb.currentUser?.email;
  String? get currentUid => _fb.currentUser?.uid;
  bool get isEmailVerified => _fb.isEmailVerified;

  List<Roommate> get roommates => _roomConfig?.roommates ?? [];
  String? get inviteCode => _roomConfig?.inviteCode;

  static String generateId() => FirebaseService.generateId();

  /// The Roommate object for the currently logged-in user.
  Roommate? get currentRoommate =>
      _currentRoommateId != null ? getRoommateById(_currentRoommateId!) : null;

  /// Returns the set of roommateIds that are already claimed by another user.
  Set<String> get claimedByOthers {
    final uid = currentUid;
    return _joinedBy.entries
        .where((e) => e.value != uid)
        .map((e) => e.key)
        .toSet();
  }

  // ── Initialization ───────────────────────────────────────────────

  AppState() {
    _init();
  }

  void _init() {
    _authSub = _fb.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    if (user == null) {
      _cancelHouseholdStreams();
      _isAuthenticated = false;
      _householdId = null;
      _currentRoommateId = null;
      _roomConfig = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isAuthenticated = true;
    _requestNotificationPermission(); // fire-and-forget
    final binding = _fb.currentUserBinding;
    if (binding != null && binding.length == 2) {
      _householdId = binding[0];
      _currentRoommateId = binding[1];
      _subscribeToHousehold(_householdId!);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Notification Permission ──────────────────────────────────────

  /// Asks for notification permission after sign-in. Errors are swallowed
  /// so they never break the auth flow.
  Future<void> _requestNotificationPermission() async {
    try {
      await NotificationService.requestPermission();
    } catch (e) {
      debugPrint('[Notifications] permission request failed: $e');
    }
  }

  void _subscribeToHousehold(String hId) {
    _cancelHouseholdStreams();

    _configSub = _fb.streamConfig(hId).listen(
      (config) {
        _roomConfig = config;
        _recalcBalances();
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[AppState] config stream error: $e');
        _isLoading = false;
        notifyListeners();
      },
    );

    _expensesSub = _fb.streamExpenses(hId).listen((list) {
      _expenses = list;
      _recalcBalances();
      notifyListeners();
    }, onError: (e) => debugPrint('[AppState] expenses stream error: $e'));

    _settlementsSub = _fb.streamSettlements(hId).listen((list) {
      _settlements = list;
      _recalcBalances();
      notifyListeners();
    }, onError: (e) => debugPrint('[AppState] settlements stream error: $e'));

    _choresSub = _fb.streamChores(hId).listen((list) {
      _chores = list;
      notifyListeners();
    }, onError: (e) => debugPrint('[AppState] chores stream error: $e'));

    _templatesSub = _fb.streamChoreTemplates(hId).listen((list) {
      _choreTemplates = list;
      notifyListeners();
    }, onError: (e) => debugPrint('[AppState] templates stream error: $e'));

    _grocerySub = _fb.streamGrocery(hId).listen((list) {
      _groceryItems = list;
      notifyListeners();
    }, onError: (e) => debugPrint('[AppState] grocery stream error: $e'));

    _weekSub = _fb.streamLastGeneratedWeek(hId).listen((week) {
      final prevWeek = _lastGeneratedWeek;
      _lastGeneratedWeek = week;
      notifyListeners();

      if (!_autoGenerating &&
          week != currentWeekNumber &&
          _choreTemplates.isNotEmpty) {
        _autoGenerate();
      } else if (!_autoGenerating &&
          prevWeek == -1 &&
          week == -1 &&
          _choreTemplates.isNotEmpty) {
        _autoGenerate();
      }
    }, onError: (e) => debugPrint('[AppState] week stream error: $e'));

    _joinedBySub = _fb.streamJoinedBy(hId).listen((map) {
      _joinedBy = map;
      notifyListeners();
    }, onError: (e) => debugPrint('[AppState] joinedBy stream error: $e'));
  }

  Future<void> _autoGenerate() async {
    if (_autoGenerating || _householdId == null) return;
    _autoGenerating = true;
    try {
      await generateWeeklyChores();
    } finally {
      _autoGenerating = false;
    }
  }

  void _cancelHouseholdStreams() {
    _configSub?.cancel();
    _expensesSub?.cancel();
    _settlementsSub?.cancel();
    _choresSub?.cancel();
    _templatesSub?.cancel();
    _grocerySub?.cancel();
    _weekSub?.cancel();
    _joinedBySub?.cancel();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelHouseholdStreams();
    super.dispose();
  }

  // ── Auth Methods ─────────────────────────────────────────────────

  Future<void> signUp(String email, String password) async {
    await _fb.signUp(email, password);
    // Send verification email immediately after account creation.
    await _fb.sendEmailVerification();
  }

  Future<void> sendEmailVerification() => _fb.sendEmailVerification();

  /// Re-checks Firebase to see if the email has been verified since last load.
  Future<bool> reloadAndCheckVerified() => _fb.reloadAndCheckVerified();

  Future<void> signIn(String email, String password) async {
    await _fb.signIn(email, password);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();

    await _authSub?.cancel();
    _cancelHouseholdStreams();

    _householdId = null;
    _currentRoommateId = null;
    _roomConfig = null;

    _expenses = [];
    _settlements = [];
    _chores = [];
    _groceryItems = [];
    _choreTemplates = [];
    _lastGeneratedWeek = -1;
    _joinedBy = {};
    _isAuthenticated = false;

    _isLoading = true;
    _autoGenerating = false;

    notifyListeners();

    _init();
  }

  Future<void> sendPasswordReset(String email) async {
    await _fb.sendPasswordReset(email);
  }

  // ── Room Setup ───────────────────────────────────────────────────

  Future<String> createHousehold(
    String roomName,
    List<Roommate> roommates,
  ) async {
    final hId = await _fb.createHousehold(roomName, roommates);
    final user = _fb.currentUser;
    String roommateId = roommates.first.id;
    if (user?.email != null) {
      final match = roommates
          .where((r) => r.email?.toLowerCase() == user!.email!.toLowerCase())
          .toList();
      if (match.isNotEmpty) roommateId = match.first.id;
    }

    await _fb.linkUserToHousehold(hId, roommateId);
    await _fb.claimRoommateSlot(hId, roommateId);
    _householdId = hId;
    _currentRoommateId = roommateId;
    _subscribeToHousehold(hId);
    notifyListeners();
    return hId;
  }

  Future<bool> joinHousehold(String inviteCode, String roommateId) async {
    final hId = await _fb.findHouseholdByInviteCode(inviteCode);
    if (hId == null) return false;

    await _fb.linkUserToHousehold(hId, roommateId);
    await _fb.claimRoommateSlot(hId, roommateId);

    _householdId = hId;
    _currentRoommateId = roommateId;
    _subscribeToHousehold(hId);
    notifyListeners();
    return true;
  }

  // ── Roommate Methods ──────────────────────────────────────────────

  Roommate? getRoommateById(String id) {
    try {
      return roommates.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateRoommate(Roommate updated) async {
    if (_householdId == null) return;
    await _fb.updateRoommateInConfig(_householdId!, updated, roommates);
  }

  // ── Expense Methods ───────────────────────────────────────────────

  Future<void> addExpense(Expense expense) async {
    if (_householdId == null) return;
    await _fb.addExpense(_householdId!, expense);
  }

  Future<void> deleteExpense(String id) async {
    if (_householdId == null) return;
    await _fb.deleteExpense(_householdId!, id);
  }

  /// Called by a participant (not the payer) to confirm their share is correct.
  Future<void> confirmExpenseShare(String expenseId) async {
    if (_householdId == null || _currentRoommateId == null) return;
    await _fb.confirmExpenseShare(
        _householdId!, expenseId, _currentRoommateId!);
  }

  /// Called by a participant to flag an expense as wrong.
  Future<void> disputeExpenseShare(String expenseId) async {
    if (_householdId == null || _currentRoommateId == null) return;
    await _fb.disputeExpenseShare(
        _householdId!, expenseId, _currentRoommateId!);
  }

  /// Expenses where the current user is a participant and hasn't yet
  /// confirmed or disputed their share.
  List<Expense> get expensesAwaitingMyConfirmation {
    if (_currentRoommateId == null) return [];
    return _expenses
        .where(
          (e) =>
              e.participantsOwing.contains(_currentRoommateId) &&
              !e.confirmedBy.contains(_currentRoommateId) &&
              !e.disputedBy.contains(_currentRoommateId),
        )
        .toList();
  }

  // ── Balance Calculation ───────────────────────────────────────────

  void _recalcBalances() {
    if (_roomConfig == null) return;
    for (final r in _roomConfig!.roommates) {
      r.balance = 0;
    }
    for (final expense in _expenses) {
      if (!expense.isSettledIntoBalance) {
        continue; // still pending confirmation / disputed
      }
      final payer = getRoommateById(expense.paidById);
      if (payer == null) continue;
      final share = expense.sharePerPerson;
      for (final memberId in expense.splitBetween) {
        if (memberId == expense.paidById) continue;
        payer.balance += share;
        final debtor = getRoommateById(memberId);
        debtor?.balance -= share;
      }
    }
    for (final s in _settlements) {
      if (!s.confirmedByCreditor) continue; // still pending / rejected
      final payer = getRoommateById(s.fromId);
      final receiver = getRoommateById(s.toId);
      if (payer != null) payer.balance += s.amount;
      if (receiver != null) receiver.balance -= s.amount;
    }
  }

  List<Map<String, dynamic>> get simplifiedDebts {
    final balances = <String, double>{};
    for (final r in roommates) {
      balances[r.id] = r.balance;
    }

    final debts = <Map<String, dynamic>>[];
    final creditors = balances.entries.where((e) => e.value > 0.01).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtors = balances.entries.where((e) => e.value < -0.01).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    int ci = 0, di = 0;
    final creditAmounts = creditors.map((e) => e.value).toList();
    final debtAmounts = debtors.map((e) => e.value.abs()).toList();

    while (ci < creditors.length && di < debtors.length) {
      final settle = creditAmounts[ci] < debtAmounts[di]
          ? creditAmounts[ci]
          : debtAmounts[di];
      debts.add({
        'fromId': debtors[di].key,
        'toId': creditors[ci].key,
        'amount': settle,
      });
      creditAmounts[ci] -= settle;
      debtAmounts[di] -= settle;
      if (creditAmounts[ci] < 0.01) ci++;
      if (debtAmounts[di] < 0.01) di++;
    }
    return debts;
  }

  /// Debtor marks a debt as paid — creates a pending settlement that the
  /// creditor must separately confirm before it affects real balances.
  Future<void> proposeSettlement(
    String fromId,
    String toId,
    double amount, {
    String? note,
  }) async {
    if (_householdId == null) return;
    final s = Settlement(
      id: generateId(),
      fromId: fromId,
      toId: toId,
      amount: amount,
      date: DateTime.now(),
      note: note,
    );
    await _fb.addSettlement(_householdId!, s);
  }

  /// Creditor confirms they actually received the payment.
  Future<void> confirmSettlement(String settlementId) async {
    if (_householdId == null) return;
    await _fb.confirmSettlement(_householdId!, settlementId);
  }

  /// Creditor disputes the debtor's "I paid" claim.
  Future<void> rejectSettlement(String settlementId) async {
    if (_householdId == null) return;
    await _fb.rejectSettlement(_householdId!, settlementId);
  }

  Future<void> deleteSettlement(String settlementId) async {
    if (_householdId == null) return;
    await _fb.deleteSettlement(_householdId!, settlementId);
  }

  /// The pending settlement (if any) already proposed between this pair.
  Settlement? pendingSettlementBetween(String fromId, String toId) {
    for (final s in _settlements) {
      if (s.fromId == fromId && s.toId == toId && s.isPending) return s;
    }
    return null;
  }

  /// Settlements where the current user is the creditor and still needs to act.
  List<Settlement> get settlementsAwaitingMyConfirmation {
    if (_currentRoommateId == null) return [];
    return _settlements
        .where((s) => s.toId == _currentRoommateId && s.isPending)
        .toList();
  }

  double get totalExpenses => _expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  // ── Chore Methods ─────────────────────────────────────────────────

  Future<void> addChore(Chore chore) async {
    if (_householdId == null) return;
    await _fb.addChore(_householdId!, chore);
  }

  Future<void> toggleChore(String id) async {
    if (_householdId == null) return;
    final chore = _chores.firstWhere((c) => c.id == id);
    await _fb.toggleChore(_householdId!, id, !chore.isCompleted);
  }

  Future<void> deleteChore(String id) async {
    if (_householdId == null) return;
    await _fb.deleteChore(_householdId!, id);
  }

  List<Chore> choresForRoommate(String roommateId) =>
      _chores.where((c) => c.assignedToId == roommateId).toList();

  int get pendingChoresCount => _chores.where((c) => !c.isCompleted).length;
  int get overdueChoresCount => _chores.where((c) => c.isOverdue).length;

  /// Pending chores assigned to the currently logged-in user.
  List<Chore> get myPendingChores {
    if (_currentRoommateId == null) return [];
    return _chores
        .where((c) => c.assignedToId == _currentRoommateId && !c.isCompleted)
        .toList();
  }

  /// Expenses the current user paid or is split into.
  List<Expense> get myExpenses {
    if (_currentRoommateId == null) return [];
    return _expenses
        .where(
          (e) =>
              e.paidById == _currentRoommateId ||
              e.splitBetween.contains(_currentRoommateId),
        )
        .toList();
  }

  // ── Chore Template Methods ────────────────────────────────────────

  Future<void> addChoreTemplate(ChoreTemplate template) async {
    if (_householdId == null) return;
    await _fb.addChoreTemplate(_householdId!, template);
  }

  Future<void> deleteChoreTemplate(String id) async {
    if (_householdId == null) return;
    await _fb.deleteChoreTemplate(_householdId!, id);
  }

  Future<void> updateChoreTemplate(ChoreTemplate updated) async {
    if (_householdId == null) return;
    await _fb.updateChoreTemplate(_householdId!, updated);
  }

  // ── Weekly Auto-Generation ────────────────────────────────────────

  static int _isoWeek(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  int get currentWeekNumber => _isoWeek(DateTime.now());
  bool get weeklyChoresGenerated => _lastGeneratedWeek == currentWeekNumber;

  Map<String, Roommate> previewWeeklyAssignments() {
    if (roommates.isEmpty || _choreTemplates.isEmpty) return {};
    final week = currentWeekNumber;
    final n = roommates.length;
    final result = <String, Roommate>{};
    for (var i = 0; i < _choreTemplates.length; i++) {
      final template = _choreTemplates[i];
      final idx = (template.rotationOffset + week) % n;
      result[template.id] = roommates[idx];
    }
    return result;
  }

  Future<List<Chore>> generateWeeklyChores({bool dryRun = false}) async {
    if (roommates.isEmpty || _choreTemplates.isEmpty) return [];

    final week = currentWeekNumber;
    final now = DateTime.now();
    final daysUntilSunday = 7 - now.weekday;
    final dueDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilSunday,
      23,
      59,
    );
    final n = roommates.length;

    final generated = <Chore>[];
    for (var i = 0; i < _choreTemplates.length; i++) {
      final template = _choreTemplates[i];
      final idx = (template.rotationOffset + week) % n;
      generated.add(
        Chore(
          id: generateId(),
          title: template.title,
          category: template.category,
          assignedToId: roommates[idx].id,
          dueDate: dueDate,
          frequency: 'Weekly',
          templateId: template.id,
        ),
      );
    }

    if (!dryRun && _householdId != null) {
      await _fb.generateWeeklyChores(_householdId!, generated, week);
    }

    return generated;
  }

  // ── Grocery Methods ───────────────────────────────────────────────

  Future<void> addGroceryItem(GroceryItem item) async {
    if (_householdId == null) return;
    await _fb.addGroceryItem(_householdId!, item);
  }

  Future<void> toggleGroceryItem(String id) async {
    if (_householdId == null) return;
    final item = _groceryItems.firstWhere((g) => g.id == id);
    await _fb.toggleGroceryItem(_householdId!, id, !item.isPurchased);
  }

  Future<void> deleteGroceryItem(String id) async {
    if (_householdId == null) return;
    await _fb.deleteGroceryItem(_householdId!, id);
  }

  Future<void> clearPurchasedItems() async {
    if (_householdId == null) return;
    await _fb.clearPurchasedItems(_householdId!);
  }

  int get unpurchasedCount => _groceryItems.where((g) => !g.isPurchased).length;

  Map<String, List<GroceryItem>> get groceryByCategory {
    final map = <String, List<GroceryItem>>{};
    for (final item in _groceryItems) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  // ── Grocery Run → Expense ─────────────────────────────────────────

  Future<void> settleGroceryRun({
    required String buyerId,
    required List<GroceryItem> items,
    required List<String> splitBetween,
  }) async {
    if (_householdId == null) return;

    final total = items.fold<double>(
      0.0,
      (sum, item) => sum + ((item.price ?? 0.0) * item.quantity),
    );

    if (total <= 0) return;

    final buyer = getRoommateById(buyerId);
    if (buyer == null) return;

    final itemSummary = items
        .where((i) => (i.price ?? 0) > 0)
        .map((i) => '${i.name} x${i.quantity}')
        .join(', ');

    final expense = Expense(
      id: generateId(),
      title: "${buyer.name.split(' ').first}'s grocery run",
      amount: total,
      paidById: buyerId,
      splitBetween: splitBetween,
      category: 'Groceries',
      date: DateTime.now(),
      note: itemSummary.isNotEmpty ? itemSummary : null,
    );

    await _fb.addExpense(_householdId!, expense);

    for (final item in items) {
      await _fb.toggleGroceryItem(_householdId!, item.id, true);
    }
  }
}
