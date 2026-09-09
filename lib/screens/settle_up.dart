import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart' hide AppConstants;

String formatGHSFull(double v) =>
    '₵${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

class SettleUpTab extends StatelessWidget {
  final AppState state;
  const SettleUpTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.roommates.isEmpty) {
      return const EmptyState(
        emoji: '💰',
        title: 'No roommates',
        subtitle: 'Add roommates first to track balances',
      );
    }

    final debts = state.simplifiedDebts;
    final currentId = state.currentRoommateId ?? '';
    final awaitingMyConfirmation = state.settlementsAwaitingMyConfirmation;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Awaiting your confirmation ───────────────────────────────
        if (awaitingMyConfirmation.isNotEmpty) ...[
          Text('Awaiting Your Confirmation',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'These roommates say they\'ve paid you. Confirm you actually received it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...awaitingMyConfirmation.map(
            (s) => _PendingConfirmationCard(settlement: s, state: state),
          ),
          const SizedBox(height: 24),
        ],

        // ── Balances card ──────────────────────────────────────────────
        Text('Balances', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.shadowCard,
          ),
          child: Column(
            children: state.roommates.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final isLast = i == state.roommates.length - 1;
              final isPositive = r.balance >= 0.01;
              final isZero = r.balance.abs() < 0.01;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        RoommateAvatar(roommate: r, size: 40, colorIndex: i),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              Text(
                                isZero
                                    ? 'All settled'
                                    : isPositive
                                        ? 'Is owed money'
                                        : 'Owes money',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        BalanceBadge(amount: r.balance),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, indent: 68),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // ── Suggested settlements ──────────────────────────────────────
        if (debts.isNotEmpty) ...[
          Text('Suggested Settlements',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Simplest way to settle all debts',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          ...debts.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final from = state.getRoommateById(d['fromId'] as String);
            final to = state.getRoommateById(d['toId'] as String);
            final amount = d['amount'] as double;
            if (from == null || to == null) return const SizedBox.shrink();

            final fromIdx = state.roommates.indexWhere((r) => r.id == from.id);
            final toIdx = state.roommates.indexWhere((r) => r.id == to.id);

            final isMyDebt = d['fromId'] == currentId;
            final isCreditor = d['toId'] == currentId;
            final pending = state.pendingSettlementBetween(from.id, to.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: isMyDebt
                      ? AppTheme.danger.withValues(alpha: 0.3)
                      : AppTheme.divider,
                ),
                boxShadow: AppTheme.shadowCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      RoommateAvatar(
                          roommate: from,
                          size: 38,
                          colorIndex: fromIdx < 0 ? 0 : fromIdx),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            const Icon(Icons.arrow_forward_rounded,
                                color: AppTheme.primary, size: 18),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySurface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                formatGHSFull(amount),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RoommateAvatar(
                          roommate: to,
                          size: 38,
                          colorIndex: toIdx < 0 ? 0 : toIdx),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${from.name.split(' ').first} pays ${to.name.split(' ').first}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      // ── Status badge ──
                      if (pending != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSurface,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                                color: AppTheme.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            isCreditor
                                ? 'Confirm\nbelow ↑'
                                : 'Awaiting\nconfirmation',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.accent, fontSize: 10),
                          ),
                        )
                      else if (!isMyDebt)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Text(
                            'Pending',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppTheme.textTertiary, fontSize: 10),
                          ),
                        ),
                    ],
                  ),

                  // ── Mark as Paid — only the debtor sees this, and only
                  // when there's no pending claim already awaiting the
                  // creditor's response ──
                  if (isMyDebt && pending == null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _openMarkPaidSheet(context, from, to, amount, state),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 16),
                      label: const Text('Mark as Paid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate(delay: (i * 50).ms).fadeIn();
          }),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.successSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border:
                  Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Text('🎉', style: TextStyle(fontSize: 28)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All settled up!',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success)),
                      SizedBox(height: 2),
                      Text('No outstanding balances.',
                          style:
                              TextStyle(color: AppTheme.success, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openMarkPaidSheet(
    BuildContext context,
    Roommate from,
    Roommate to,
    double amount,
    AppState state,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MarkPaidSheet(
        from: from,
        to: to,
        suggestedAmount: amount,
        state: state,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Card shown to the creditor for a settlement awaiting their confirmation.
// ─────────────────────────────────────────────────────────────────────────
class _PendingConfirmationCard extends StatefulWidget {
  final Settlement settlement;
  final AppState state;
  const _PendingConfirmationCard(
      {required this.settlement, required this.state});

  @override
  State<_PendingConfirmationCard> createState() =>
      _PendingConfirmationCardState();
}

class _PendingConfirmationCardState extends State<_PendingConfirmationCard> {
  bool _busy = false;

  Future<void> _respond(bool confirm) async {
    setState(() => _busy = true);
    try {
      if (confirm) {
        await widget.state.confirmSettlement(widget.settlement.id);
      } else {
        await widget.state.rejectSettlement(widget.settlement.id);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.state.getRoommateById(widget.settlement.fromId);
    if (from == null) return const SizedBox.shrink();
    final fromIdx = widget.state.roommates.indexWhere((r) => r.id == from.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RoommateAvatar(
                  roommate: from,
                  size: 38,
                  colorIndex: fromIdx < 0 ? 0 : fromIdx),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: from.name.split(' ').first,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' says they paid you '),
                      TextSpan(
                        text: formatGHSFull(widget.settlement.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (widget.settlement.note != null &&
              widget.settlement.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${widget.settlement.note}"',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(
                        color: AppTheme.danger.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Didn\'t receive it'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _respond(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm received'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MarkPaidSheet — debtor marks a debt as paid (replaces PaystackSettleSheet)
// ─────────────────────────────────────────────────────────────────────────
class MarkPaidSheet extends StatefulWidget {
  final Roommate from; // debtor — the one paying
  final Roommate to; // creditor — the one receiving
  final double suggestedAmount;
  final AppState state;

  const MarkPaidSheet({
    super.key,
    required this.from,
    required this.to,
    required this.suggestedAmount,
    required this.state,
  });

  @override
  State<MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<MarkPaidSheet> {
  late final TextEditingController _amtCtrl;
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(
      text: widget.suggestedAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.state.proposeSettlement(
        widget.from.id,
        widget.to.id,
        amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Waiting for ${widget.to.name.split(' ').first} to confirm they received it.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromIdx =
        widget.state.roommates.indexWhere((r) => r.id == widget.from.id);
    final toIdx =
        widget.state.roommates.indexWhere((r) => r.id == widget.to.id);
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius2xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),

          // ── Header ─────────────────────────────────────────────────
          Text('Mark as Paid', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${widget.to.name.split(' ').first} will need to confirm they received this before it clears.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // ── From → To visual ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RoommateAvatar(
                  roommate: widget.from,
                  size: 48,
                  colorIndex: fromIdx < 0 ? 0 : fromIdx,
                  showName: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_forward_rounded,
                          color: AppTheme.primary, size: 22),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formatGHSFull(widget.suggestedAmount),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                RoommateAvatar(
                  roommate: widget.to,
                  size: 48,
                  colorIndex: toIdx < 0 ? 0 : toIdx,
                  showName: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Amount ─────────────────────────────────────────────────
          TextField(
            controller: _amtCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount (GHS)',
              prefixText: '₵ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
          ),

          const SizedBox(height: 12),

          // ── Note ───────────────────────────────────────────────────
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.note_outlined),
              hintText: 'e.g. Paid via MoMo just now',
            ),
          ),

          // ── Error banner ───────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.dangerSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.danger, size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Submit button ─────────────────────────────────────────
          LoadingButton(
            isLoading: _loading,
            onPressed: _submit,
            label: 'Mark as Paid',
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 12, color: AppTheme.textTertiary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Handle the actual payment (cash, MoMo, bank transfer) outside the app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
