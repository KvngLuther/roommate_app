// ── Roommate Model ──────────────────────────────────────────────
class Roommate {
  final String id;
  String name;
  String emoji;
  String? email;
  double balance;

  Roommate({
    required this.id,
    required this.name,
    this.emoji = '🧑',
    this.email,
    this.balance = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'email': email,
        'balance': balance,
      };

  factory Roommate.fromJson(Map<String, dynamic> json) => Roommate(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '🧑',
        email: json['email'] as String?,
        balance: (json['balance'] as num? ?? 0.0).toDouble(),
      );

  Roommate copyWith({
    String? name,
    String? emoji,
    String? email,
    double? balance,
  }) =>
      Roommate(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        email: email ?? this.email,
        balance: balance ?? this.balance,
      );
}

// ── Expense Model ───────────────────────────────────────────────
class Expense {
  final String id;
  String title;
  double amount;
  String paidById;
  List<String> splitBetween;
  String category;
  DateTime date;
  String? note;

  /// roommateIds (excluding the payer) who have confirmed their share is correct.
  List<String> confirmedBy;

  /// roommateIds who have flagged this expense as wrong/disputed.
  List<String> disputedBy;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidById,
    required this.splitBetween,
    required this.category,
    required this.date,
    this.note,
    List<String>? confirmedBy,
    List<String>? disputedBy,
  })  : confirmedBy = confirmedBy ?? [],
        disputedBy = disputedBy ?? [];

  double get sharePerPerson =>
      splitBetween.isEmpty ? 0 : amount / splitBetween.length;

  /// Everyone who owes money on this expense (i.e. splitBetween minus the payer).
  List<String> get participantsOwing =>
      splitBetween.where((id) => id != paidById).toList();

  /// True once every participant (other than the payer) has confirmed.
  bool get isFullyConfirmed =>
      participantsOwing.every((id) => confirmedBy.contains(id));

  bool get isDisputed => disputedBy.isNotEmpty;

  /// Whether this expense currently counts toward real balances.
  bool get isSettledIntoBalance => isFullyConfirmed && !isDisputed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'paidById': paidById,
        'splitBetween': splitBetween,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
        'confirmedBy': confirmedBy,
        'disputedBy': disputedBy,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num? ?? 0.0).toDouble(),
        paidById: json['paidById'] as String,
        splitBetween: List<String>.from(json['splitBetween'] as List? ?? []),
        category: json['category'] as String? ?? 'Other',
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        confirmedBy: List<String>.from(json['confirmedBy'] as List? ?? []),
        disputedBy: List<String>.from(json['disputedBy'] as List? ?? []),
      );
}

// ── Settlement Model ────────────────────────────────────────────
class Settlement {
  final String id;
  final String fromId; // debtor  – the one who owes, proposes the settlement
  final String toId; // creditor – the one who is owed, must confirm it
  final double amount;
  final DateTime date;
  final String? note;

  /// True once the creditor (toId) has confirmed they actually received it.
  bool confirmedByCreditor;

  /// True if the creditor rejected the debtor's "I paid" claim.
  bool rejectedByCreditor;

  Settlement({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amount,
    required this.date,
    this.note,
    this.confirmedByCreditor = false,
    this.rejectedByCreditor = false,
  });

  /// Proposed by the debtor, not yet acted on by the creditor.
  bool get isPending => !confirmedByCreditor && !rejectedByCreditor;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'confirmedByCreditor': confirmedByCreditor,
        'rejectedByCreditor': rejectedByCreditor,
      };

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        fromId: json['fromId'] as String,
        toId: json['toId'] as String,
        amount: (json['amount'] as num? ?? 0.0).toDouble(),
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        confirmedByCreditor: json['confirmedByCreditor'] as bool? ?? false,
        rejectedByCreditor: json['rejectedByCreditor'] as bool? ?? false,
      );
}

// ── Chore Model ─────────────────────────────────────────────────
class Chore {
  final String id;
  String title;
  String category;
  String assignedToId;
  DateTime dueDate;
  bool isCompleted;
  String frequency;
  String? note;
  String? templateId;

  Chore({
    required this.id,
    required this.title,
    required this.category,
    required this.assignedToId,
    required this.dueDate,
    this.isCompleted = false,
    this.frequency = 'Weekly',
    this.note,
    this.templateId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'assignedToId': assignedToId,
        'dueDate': dueDate.toIso8601String(),
        'isCompleted': isCompleted,
        'frequency': frequency,
        'note': note,
        'templateId': templateId,
      };

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Other',
        assignedToId: json['assignedToId'] as String,
        dueDate: DateTime.parse(json['dueDate'] as String),
        isCompleted: json['isCompleted'] as bool? ?? false,
        frequency: json['frequency'] as String? ?? 'Weekly',
        note: json['note'] as String?,
        templateId: json['templateId'] as String?,
      );

  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());

  bool get isDueToday {
    final now = DateTime.now();
    return !isCompleted &&
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }
}

// ── Chore Template Model ────────────────────────────────────────
class ChoreTemplate {
  final String id;
  String title;
  String category;
  int rotationOffset;

  ChoreTemplate({
    required this.id,
    required this.title,
    required this.category,
    this.rotationOffset = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'rotationOffset': rotationOffset,
      };

  factory ChoreTemplate.fromJson(Map<String, dynamic> json) => ChoreTemplate(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Cleaning',
        rotationOffset: json['rotationOffset'] as int? ?? 0,
      );
}

// ── Grocery Item Model ──────────────────────────────────────────
class GroceryItem {
  final String id;
  String name;
  int quantity;
  String unit;
  bool isPurchased;
  String addedById;
  String? note;
  String category;

  /// Price paid — set during [AppState.settleGroceryRun] so the resulting
  /// Groceries expense note can itemise each item's cost. Not required for
  /// normal list use; defaults to null.
  double? price;

  GroceryItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = 'pcs',
    this.isPurchased = false,
    required this.addedById,
    this.note,
    this.category = 'General',
    this.price,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'isPurchased': isPurchased,
        'addedById': addedById,
        'note': note,
        'category': category,
        'price': price,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int? ?? 1,
        unit: json['unit'] as String? ?? 'pcs',
        isPurchased: json['isPurchased'] as bool? ?? false,
        addedById: json['addedById'] as String,
        note: json['note'] as String?,
        category: json['category'] as String? ?? 'General',
        price: (json['price'] as num?)?.toDouble(),
      );
}

// ── Room Config Model ───────────────────────────────────────────
class RoomConfig {
  String roomName;
  int numberOfRoommates;
  List<Roommate> roommates;
  String? inviteCode;

  RoomConfig({
    required this.roomName,
    required this.numberOfRoommates,
    required this.roommates,
    this.inviteCode,
  });

  Map<String, dynamic> toJson() => {
        'roomName': roomName,
        'numberOfRoommates': numberOfRoommates,
        'roommates': roommates.map((r) => r.toJson()).toList(),
        'inviteCode': inviteCode,
      };

  factory RoomConfig.fromJson(Map<String, dynamic> json) => RoomConfig(
        roomName: json['roomName'] as String? ?? 'My Room',
        numberOfRoommates: json['numberOfRoommates'] as int? ?? 2,
        roommates: (json['roommates'] as List<dynamic>? ?? [])
            .map((r) => Roommate.fromJson(r as Map<String, dynamic>))
            .toList(),
        inviteCode: json['inviteCode'] as String?,
      );
}
