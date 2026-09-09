import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart' hide AppConstants;
import '../models/models.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  final VoidCallback onSettings;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final config = state.roomConfig!;
    final me = state.currentRoommate;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, state, config, me),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                if (me != null) ...[
                  _buildMyBalanceCard(context, state, me),
                  const SizedBox(height: 20),
                  _buildMyQuickStats(context, state),
                  const SizedBox(height: 28),
                  _buildMyChores(context, state),
                  const SizedBox(height: 28),
                  _buildMyExpenses(context, state, me),
                  const SizedBox(height: 28),
                ],
                _buildHouseholdSection(context, state),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────
  Widget _buildAppBar(
      BuildContext context, AppState state, RoomConfig config, Roommate? me) {
    final greeting = _greeting();
    final now = DateTime.now();

    return SliverAppBar(
      expandedHeight: 130,
      floating: true,
      snap: true,
      backgroundColor: AppTheme.primaryDark,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryDark,
                AppTheme.primary,
                AppTheme.primaryLight
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Avatar (tappable) ──
                  if (me != null)
                    GestureDetector(
                      onTap: () {
                        final idx =
                            state.roommates.indexWhere((r) => r.id == me.id);
                        _showRoommateProfile(
                            context, state, me, idx < 0 ? 0 : idx);
                      },
                      child: _buildHeaderAvatar(me),
                    ),
                  if (me != null) const SizedBox(width: 14),

                  // ── Greeting + Date ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          me != null
                              ? '$greeting, ${me.name.split(' ').first} ${me.emoji}'
                              : greeting,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.home_rounded,
                                color: Colors.white54, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              config.roomName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '  ·  ${DateFormat('EEE, d MMM').format(now)}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Settings ──
                  GestureDetector(
                    onTap: onSettings,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(Roommate me) {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: Text(me.emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── My Balance Card ────────────────────────────────────────────────
  Widget _buildMyBalanceCard(
      BuildContext context, AppState state, Roommate me) {
    final balance = me.balance;
    final isOwed = balance > 0.01;
    final isOwing = balance < -0.01;
    final isSettled = balance.abs() < 0.01;

    final cardColor = isOwed
        ? AppTheme.success
        : isOwing
            ? AppTheme.danger
            : AppTheme.primary;
    final cardBg = isOwed
        ? AppTheme.successSurface
        : isOwing
            ? AppTheme.dangerSurface
            : AppTheme.primarySurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: cardColor.withValues(alpha: 0.25)),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOwed
                  ? Icons.arrow_downward_rounded
                  : isOwing
                      ? Icons.arrow_upward_rounded
                      : Icons.check_circle_rounded,
              color: cardColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSettled
                      ? 'You\'re all settled up!'
                      : isOwed
                          ? 'You\'re owed'
                          : 'You owe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cardColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (!isSettled) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatGHSFull(balance.abs()),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: cardColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.5,
                        ),
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  Text(
                    'No pending balances 🎉',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cardColor.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onNavigate(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                'Details',
                style: TextStyle(
                  color: cardColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ── My Quick Stats ─────────────────────────────────────────────────
  Widget _buildMyQuickStats(BuildContext context, AppState state) {
    final myChoresDue = state.myPendingChores.length;
    final myOverdue = state.myPendingChores.where((c) => c.isOverdue).length;
    final myExpenses = state.myExpenses.length;
    final unpurchased = state.unpurchasedCount;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onNavigate(2),
            child: _QuickStatTile(
              icon: Icons.checklist_rounded,
              value: '$myChoresDue',
              label: myOverdue > 0 ? '$myOverdue overdue' : 'Chores',
              color: myOverdue > 0 ? AppTheme.danger : AppTheme.accent,
            ).animate().fadeIn(delay: 60.ms),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onNavigate(1),
            child: _QuickStatTile(
              icon: Icons.receipt_outlined,
              value: '$myExpenses',
              label: 'Expenses',
              color: AppTheme.info,
            ).animate().fadeIn(delay: 110.ms),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onNavigate(3),
            child: _QuickStatTile(
              icon: Icons.shopping_basket_outlined,
              value: '$unpurchased',
              label: 'To Buy',
              color: AppTheme.primary,
            ).animate().fadeIn(delay: 160.ms),
          ),
        ),
      ],
    );
  }

  // ── My Chores ──────────────────────────────────────────────────────
  Widget _buildMyChores(BuildContext context, AppState state) {
    final myChores = state.myPendingChores.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Your Chores',
          actionLabel: state.myPendingChores.length > 3 ? 'See all' : null,
          onAction: () => onNavigate(2),
        ),
        const SizedBox(height: 10),
        if (myChores.isEmpty)
          _EmptyCard(
            emoji: '✅',
            text: 'All caught up! No chores assigned to you.',
            color: AppTheme.success,
          ).animate().fadeIn()
        else
          ...myChores.asMap().entries.map((entry) {
            final i = entry.key;
            final chore = entry.value;
            return GestureDetector(
              onTap: () => onNavigate(2),
              child: _ChoreCard(chore: chore)
                  .animate(delay: (i * 55).ms)
                  .fadeIn()
                  .slideX(begin: 0.03, end: 0),
            );
          }),
      ],
    );
  }

  // ── My Expenses ────────────────────────────────────────────────────
  Widget _buildMyExpenses(BuildContext context, AppState state, Roommate me) {
    final recent = state.myExpenses.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Your Expenses',
          actionLabel: state.myExpenses.length > 3 ? 'See all' : null,
          onAction: () => onNavigate(1),
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          GestureDetector(
            onTap: () => onNavigate(1),
            child: _EmptyCard(
              emoji: '💸',
              text: 'No expenses yet. Tap to add one.',
              color: AppTheme.info,
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textTertiary, size: 14),
            ),
          ).animate().fadeIn()
        else
          ...recent.asMap().entries.map((entry) {
            final i = entry.key;
            final expense = entry.value;
            final isPayer = expense.paidById == me.id;
            final payer = state.getRoommateById(expense.paidById);
            return GestureDetector(
              onTap: () => onNavigate(1),
              child: _ExpenseRow(
                expense: expense,
                isPayer: isPayer,
                payerName: payer?.name.split(' ').first ?? 'Someone',
              ).animate(delay: (i * 50).ms).fadeIn(),
            );
          }),
      ],
    );
  }

  // ── Household Section ──────────────────────────────────────────────
  Widget _buildHouseholdSection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Household',
          actionLabel: 'Expenses',
          onAction: () => onNavigate(1),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigate(1),
                child: StatCard(
                  label: 'Total Expenses',
                  value: formatGHS(state.totalExpenses),
                  icon: Icons.receipt_long_outlined,
                  color: AppTheme.info,
                ).animate().fadeIn(delay: 80.ms),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigate(2),
                child: StatCard(
                  label: 'Pending Chores',
                  value: '${state.pendingChoresCount}',
                  icon: Icons.checklist_rtl_rounded,
                  color: AppTheme.accent,
                ).animate().fadeIn(delay: 120.ms),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onNavigate(3),
                child: StatCard(
                  label: 'To Buy',
                  value: '${state.unpurchasedCount}',
                  icon: Icons.shopping_basket_outlined,
                  color: AppTheme.primary,
                ).animate().fadeIn(delay: 160.ms),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildRoommateBalances(context, state),
      ],
    );
  }

  Widget _buildRoommateBalances(BuildContext context, AppState state) {
    final roommates = state.roommates;
    if (roommates.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balances',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.shadowCard,
          ),
          child: Column(
            children: roommates.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final isMe = r.id == state.currentRoommateId;
              final isLast = i == roommates.length - 1;

              return Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    onTap: () => _showRoommateProfile(context, state, r, i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          RoommateAvatar(roommate: r, size: 38, colorIndex: i),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  r.name.split(' ').first,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontSize: 14),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primarySurface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'you',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          BalanceBadge(amount: r.balance, compact: true),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppTheme.textTertiary, size: 16),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 66, endIndent: 0),
                ],
              );
            }).toList(),
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Roommate Profile Sheet ─────────────────────────────────────────
  void _showRoommateProfile(
      BuildContext context, AppState state, Roommate r, int colorIndex) {
    final isMe = r.id == state.currentRoommateId;
    final color = AppTheme.roomColors[colorIndex % AppTheme.roomColors.length];
    final theirChores =
        state.chores.where((c) => c.assignedToId == r.id).toList();
    final theirExpenses = state.expenses
        .where((e) => e.paidById == r.id || e.splitBetween.contains(r.id))
        .toList();
    final completedCount = theirChores.where((c) => c.isCompleted).length;
    final pendingCount = theirChores.where((c) => !c.isCompleted).length;
    final totalPaid = theirExpenses
        .where((e) => e.paidById == r.id)
        .fold(0.0, (s, e) => s + e.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.card,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            children: [
              const SheetHandle(),
              const SizedBox(height: 24),

              // ── Profile header ──
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Center(
                      child:
                          Text(r.emoji, style: const TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(r.name,
                                style: Theme.of(context).textTheme.titleLarge),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (r.email != null) ...[
                          const SizedBox(height: 3),
                          Text(r.email!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                        const SizedBox(height: 8),
                        BalanceBadge(amount: r.balance),
                      ],
                    ),
                  ),
                  if (isMe)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom),
                            child: _EditProfileSheet(
                              roommate: r,
                              colorIndex: colorIndex,
                              state: state,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // ── Stats ──
              Row(
                children: [
                  _ProfileStat(
                      label: 'Total Paid',
                      value: formatGHSFull(totalPaid),
                      icon: Icons.payments_outlined,
                      color: AppTheme.success),
                  const SizedBox(width: 10),
                  _ProfileStat(
                      label: 'Done',
                      value: '$completedCount',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppTheme.primary),
                  const SizedBox(width: 10),
                  _ProfileStat(
                      label: 'Pending',
                      value: '$pendingCount',
                      icon: Icons.pending_outlined,
                      color: AppTheme.accent),
                ],
              ),

              const SizedBox(height: 24),

              // ── Recent Chores ──
              if (theirChores.isNotEmpty) ...[
                Text('Chores', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...theirChores.take(4).map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Text(AppConstants.choreEmojis[c.category] ?? '✅',
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(c.title,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                          if (c.isCompleted)
                            const Icon(Icons.check_rounded,
                                color: AppTheme.success, size: 16)
                          else if (c.isOverdue)
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.danger, size: 16),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],

              // ── Recent Expenses ──
              if (theirExpenses.isNotEmpty) ...[
                Text('Recent Expenses',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ...theirExpenses.take(4).map((e) {
                  final paid = e.paidById == r.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        Text(AppConstants.categoryEmojis[e.category] ?? '💰',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              Text(paid ? 'Paid' : 'Owes share',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(
                          paid
                              ? '+${formatGHSFull(e.amount)}'
                              : '-${formatGHSFull(e.sharePerPerson)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: paid ? AppTheme.success : AppTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Quick Stat Tile ────────────────────────────────────────────────
class _QuickStatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Chore Card ─────────────────────────────────────────────────────
class _ChoreCard extends StatelessWidget {
  final Chore chore;
  const _ChoreCard({required this.chore});

  @override
  Widget build(BuildContext context) {
    final overdue = chore.isOverdue;
    final color = overdue ? AppTheme.danger : AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: overdue
              ? AppTheme.danger.withValues(alpha: 0.35)
              : AppTheme.divider,
        ),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Center(
              child: Text(
                AppConstants.choreEmojis[chore.category] ?? '✅',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chore.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontSize: 14),
                ),
                Text(
                  chore.category,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _ChoreDueBadge(chore: chore),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textTertiary, size: 16),
        ],
      ),
    );
  }
}

// ── Chore Due Badge ────────────────────────────────────────────────
class _ChoreDueBadge extends StatelessWidget {
  final Chore chore;
  const _ChoreDueBadge({required this.chore});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (chore.isOverdue) {
      color = AppTheme.danger;
      label = 'Overdue';
    } else if (chore.isDueToday) {
      color = AppTheme.accent;
      label = 'Today';
    } else {
      color = AppTheme.textTertiary;
      label = DateFormat('MMM d').format(chore.dueDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Expense Row ────────────────────────────────────────────────────
class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final bool isPayer;
  final String payerName;

  const _ExpenseRow({
    required this.expense,
    required this.isPayer,
    required this.payerName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isPayer ? AppTheme.primary : AppTheme.danger)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Center(
              child: Text(
                AppConstants.categoryEmojis[expense.category] ?? '💰',
                style: const TextStyle(fontSize: 18),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isPayer
                      ? 'You paid · ${expense.splitBetween.length} people'
                      : 'Paid by $payerName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isPayer
                    ? '+${formatGHSFull(expense.amount)}'
                    : '-${formatGHSFull(expense.sharePerPerson)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isPayer ? AppTheme.success : AppTheme.danger,
                ),
              ),
              Text(
                isPayer ? 'you paid' : 'your share',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textTertiary, size: 16),
        ],
      ),
    );
  }
}

// ── Empty Card ─────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;
  final Widget? trailing;

  const _EmptyCard({
    required this.emoji,
    required this.text,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Profile Stat ───────────────────────────────────────────────────
class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Profile Sheet ─────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final Roommate roommate;
  final int colorIndex;
  final AppState state;

  const _EditProfileSheet({
    required this.roommate,
    required this.colorIndex,
    required this.state,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late String _selectedEmoji;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.roommate.name);
    _selectedEmoji = widget.roommate.emoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated =
          widget.roommate.copyWith(name: name, emoji: _selectedEmoji);
      await widget.state.updateRoommate(updated);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _error = 'Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        AppTheme.roomColors[widget.colorIndex % AppTheme.roomColors.length];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Changes are visible to all roommates.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Center(
            child: GestureDetector(
              onTap: () => _showEmojiPicker(context),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: color.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(_selectedEmoji,
                          style: const TextStyle(fontSize: 40)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.card, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _showEmojiPicker(context),
              child: const Text('Change Avatar'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            InfoBanner(
              message: _error!,
              icon: Icons.error_outline_rounded,
              color: AppTheme.danger,
            ),
          ],
          const SizedBox(height: 24),
          LoadingButton(
            isLoading: _saving,
            onPressed: _save,
            label: 'Save Changes',
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Text('Choose Avatar',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppConstants.avatarEmojis.map((e) {
                final selected = _selectedEmoji == e;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedEmoji = e);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          selected ? AppTheme.primarySurface : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.divider,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
