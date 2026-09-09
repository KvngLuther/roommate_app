import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:roommate_manager/screens/settle_up.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart' hide AppConstants, formatGHSFull;

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'All';
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _showAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddExpenseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filtered = _filter == 'All'
        ? state.expenses
        : state.expenses.where((e) => e.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (_tab.index == 0)
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
              onPressed: _showAddExpenseSheet,
              tooltip: 'Add expense',
            ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Settle Up'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Expenses Tab
          Column(
            children: [
              _SummaryBanner(state: state),
              _CategoryFilterBar(
                filter: _filter,
                expenses: state.expenses,
                onChanged: (cat) => setState(() => _filter = cat),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        emoji: '💸',
                        title: 'No expenses yet',
                        subtitle: 'Tap + to log your first shared expense',
                        buttonLabel: 'Add Expense',
                        onButton: _showAddExpenseSheet,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _ExpenseCard(
                          key: ValueKey(filtered[i].id),
                          expense: filtered[i],
                          state: state,
                          animIndex: i,
                        ),
                      ),
              ),
            ],
          ),

          // ── Settle Up Tab ─────────────────────────────────────────
          SettleUpTab(state: state),
        ],
      ),
    );
  }
}

// ── Summary Banner ──────────────────────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final AppState state;
  const _SummaryBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final perPerson = state.roommates.isEmpty
        ? 0.0
        : state.totalExpenses / state.roommates.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
          stops: [0, 0.5, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.info.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Shared',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatGHSFull(state.totalExpenses),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Per person',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatGHSFull(perPerson),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (state.expensesByCategory.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: state.expensesByCategory.entries
                    .take(6)
                    .map(
                      (e) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppConstants.categoryEmojis[e.key] ?? '💰',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${e.key}  ${formatGHS(e.value)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Category Filter Bar ─────────────────────────────────────────────
class _CategoryFilterBar extends StatelessWidget {
  final String filter;
  final List<Expense> expenses;
  final ValueChanged<String> onChanged;

  const _CategoryFilterBar({
    required this.filter,
    required this.expenses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final usedCats = expenses.map((e) => e.category).toSet().toList()..sort();
    final cats = ['All', ...usedCats];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => CategoryChip(
          label: cats[i],
          isSelected: filter == cats[i],
          onTap: () => onChanged(cats[i]),
          color: AppTheme.info,
        ),
      ),
    );
  }
}

// ── Expense Card ─────────────────────────────────────────────────────
class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final AppState state;
  final int animIndex;

  const _ExpenseCard({
    super.key,
    required this.expense,
    required this.state,
    required this.animIndex,
  });

  @override
  Widget build(BuildContext context) {
    final payer = state.getRoommateById(expense.paidById);
    final payerIdx = state.roommates.indexWhere(
      (r) => r.id == expense.paidById,
    );
    final myId = state.currentRoommateId;
    final needsMyAction = myId != null &&
        expense.participantsOwing.contains(myId) &&
        !expense.confirmedBy.contains(myId) &&
        !expense.disputedBy.contains(myId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss_${expense.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.dangerSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              SizedBox(width: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) => showConfirmDialog(
          context,
          title: 'Delete Expense',
          message: 'Remove "${expense.title}"? This cannot be undone.',
        ),
        onDismissed: (_) => context.read<AppState>().deleteExpense(expense.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.shadowCard,
          ),
          child: Column(
            children: [
              // ── Main row ──
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        AppConstants.categoryEmojis[expense.category] ?? '💰',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${expense.category}  ·  ${DateFormat('d MMM, y').format(expense.date)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatGHSFull(expense.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.info,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Confirmation status ──
              if (expense.participantsOwing.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: expense.isDisputed
                          ? AppTheme.dangerSurface
                          : expense.isFullyConfirmed
                              ? AppTheme.successSurface
                              : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: expense.isDisputed
                            ? AppTheme.danger.withValues(alpha: 0.3)
                            : expense.isFullyConfirmed
                                ? AppTheme.success.withValues(alpha: 0.3)
                                : AppTheme.divider,
                      ),
                    ),
                    child: Text(
                      expense.isDisputed
                          ? 'Disputed'
                          : expense.isFullyConfirmed
                              ? 'Confirmed by everyone'
                              : '${expense.confirmedBy.length}/${expense.participantsOwing.length} confirmed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: expense.isDisputed
                            ? AppTheme.danger
                            : expense.isFullyConfirmed
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── Split row ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    if (payer != null) ...[
                      RoommateAvatar(
                        roommate: payer,
                        size: 26,
                        colorIndex: payerIdx < 0 ? 0 : payerIdx,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall,
                            children: [
                              TextSpan(
                                text: payer.name.split(' ').first,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const TextSpan(text: ' paid · split '),
                              TextSpan(
                                text: '${expense.splitBetween.length} ways',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.infoSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.info.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '${formatGHSFull(expense.sharePerPerson)}/ea',
                        style: const TextStyle(
                          color: AppTheme.info,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Participant emojis ──
              if (expense.splitBetween.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Split: ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: expense.splitBetween.map((id) {
                          final r = state.getRoommateById(id);
                          if (r == null) return const SizedBox.shrink();
                          final rIdx = state.roommates.indexWhere(
                            (rm) => rm.id == id,
                          );
                          return Text(
                            r.emoji,
                            style: TextStyle(
                              fontSize: 14,
                              color: rIdx >= 0
                                  ? AppTheme.roomColors[
                                      rIdx % AppTheme.roomColors.length]
                                  : AppTheme.textSecondary,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],

              // ── Note ──
              if (expense.note != null && expense.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.note_outlined,
                      size: 13,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        expense.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ],
                ),
              ],

              // ── Confirm / Dispute my share ──
              if (needsMyAction) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context
                            .read<AppState>()
                            .disputeExpenseShare(expense.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(
                              color: AppTheme.danger.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Dispute'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context
                            .read<AppState>()
                            .confirmExpenseShare(expense.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Confirm my share'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: (animIndex * 35).ms).fadeIn();
  }
}

// ── Add Expense Sheet ────────────────────────────────────────────────
class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet();

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _customTitleCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _category = 'Rent';
  String? _paidById;
  Set<String> _splitBetween = {};
  bool _splitAll = true;
  DateTime _date = DateTime.now();
  bool _saving = false;

  String get _effectiveTitle {
    if (_category == 'Other') return _customTitleCtrl.text.trim();
    return _category;
  }

  bool get _canSave {
    final amount = double.tryParse(_amtCtrl.text) ?? 0;
    final titleOk =
        _category != 'Other' || _customTitleCtrl.text.trim().isNotEmpty;
    return amount > 0 &&
        titleOk &&
        _paidById != null &&
        _splitBetween.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.roommates.isNotEmpty) {
        setState(() {
          _paidById = state.currentRoommateId ?? state.roommates.first.id;
          _splitBetween = state.roommates.map((r) => r.id).toSet();
        });
      }
    });
  }

  @override
  void dispose() {
    _customTitleCtrl.dispose();
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final amount = double.tryParse(_amtCtrl.text)!;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().addExpense(
            Expense(
              id: AppState.generateId(),
              title: _effectiveTitle,
              amount: amount,
              paidById: _paidById!,
              splitBetween: _splitBetween.toList(),
              category: _category,
              date: _date,
              note:
                  _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final amount = double.tryParse(_amtCtrl.text) ?? 0.0;
    final perPerson =
        _splitBetween.isEmpty ? 0.0 : amount / _splitBetween.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius2xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + pad),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Text('Add Expense', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),

            // ── Amount ──
            TextField(
              controller: _amtCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (₵)',
                prefixText: '₵ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // ── Category ──
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppConstants.categories
                  .map(
                    (cat) => CategoryChip(
                      label: '${AppConstants.categoryEmojis[cat] ?? '💰'} $cat',
                      isSelected: _category == cat,
                      color: AppTheme.info,
                      onTap: () => setState(() => _category = cat),
                    ),
                  )
                  .toList(),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _category == 'Other'
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: TextField(
                        controller: _customTitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'What is it for?',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                          hintText: 'e.g. Plumber, New kettle…',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // ── Date ──
            Text('Date', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('EEE, d MMM y').format(_date),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    const Text(
                      'Change',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Paid By ──
            Text('Paid by', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            RoommateSelectorRow(
              roommates: state.roommates,
              selectedId: _paidById,
              onSelect: (id) => setState(() => _paidById = id),
            ),

            const SizedBox(height: 16),

            // ── Split Between ──
            Row(
              children: [
                Text(
                  'Split between',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _splitAll = !_splitAll;
                    if (_splitAll) {
                      _splitBetween = state.roommates.map((r) => r.id).toSet();
                    }
                  }),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_splitAll ? 'Custom' : 'All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.roommates.map((r) {
                final isIn = _splitBetween.contains(r.id);
                return GestureDetector(
                  onTap: _splitAll
                      ? null
                      : () => setState(() {
                            if (isIn) {
                              _splitBetween.remove(r.id);
                            } else {
                              _splitBetween.add(r.id);
                            }
                          }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isIn ? AppTheme.primarySurface : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isIn ? AppTheme.primary : AppTheme.divider,
                        width: isIn ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          r.name.split(' ').first,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isIn
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (isIn) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Per-person preview ──
            if (amount > 0 && _splitBetween.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${formatGHSFull(amount)} ÷ ${_splitBetween.length} ${_splitBetween.length == 1 ? 'person' : 'people'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primary,
                            ),
                      ),
                    ),
                    Text(
                      '= ${formatGHSFull(perPerson)} each',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_splitBetween.length > 1 ||
                  !_splitBetween.contains(_paidById)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Everyone else in the split will need to confirm their share before it counts toward balances.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: 14),

            // ── Note ──
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),

            const SizedBox(height: 24),

            LoadingButton(
              isLoading: _saving,
              onPressed: _canSave ? _save : null,
              label: 'Add Expense',
            ),
          ],
        ),
      ),
    );
  }
}
