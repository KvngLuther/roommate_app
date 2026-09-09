import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart' hide AppConstants;

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index < 2
                ? IconButton(
                    icon: const Icon(Icons.add_circle_rounded,
                        color: AppTheme.primary, size: 28),
                    onPressed: () => _showAddChoreSheet(context),
                  )
                : const SizedBox(width: 8),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'Pending (${state.pendingChoresCount})'),
            const Tab(text: 'Completed'),
            const Tab(text: '🔄 Rotation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChoreList(context, state, completed: false),
          _buildChoreList(context, state, completed: true),
          _buildRotationTab(context, state),
        ],
      ),
    );
  }

  // ── Chore List Tab ─────────────────────────────────────────────

  Widget _buildChoreList(BuildContext context, AppState state,
      {required bool completed}) {
    final chores =
        state.chores.where((c) => c.isCompleted == completed).toList();

    if (chores.isEmpty) {
      return EmptyState(
        emoji: completed ? '✅' : '🧹',
        title: completed ? 'No completed chores' : 'No pending chores!',
        subtitle: completed
            ? 'Completed chores will appear here'
            : 'Chores are auto-assigned each week. Add manual ones with +',
        buttonLabel: completed ? null : 'Add Manual Chore',
        onButton: completed ? null : () => _showAddChoreSheet(context),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: chores.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _buildChoreCard(context, chores[i], state, i),
    );
  }

  Widget _buildChoreCard(
      BuildContext context, Chore chore, AppState state, int index) {
    final assignee = state.getRoommateById(chore.assignedToId);
    final assigneeIdx =
        state.roommates.indexWhere((r) => r.id == chore.assignedToId);
    final color = chore.isOverdue
        ? AppTheme.danger
        : chore.isDueToday
            ? AppTheme.accent
            : AppTheme.primary;

    return Dismissible(
      key: Key(chore.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.danger),
      ),
      confirmDismiss: (_) => showConfirmDialog(
        context,
        title: 'Delete Chore',
        message: 'Remove "${chore.title}"?',
      ),
      onDismissed: (_) => context.read<AppState>().deleteChore(chore.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: chore.isOverdue
                ? AppTheme.danger.withValues(alpha: 0.3)
                : AppTheme.divider,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.read<AppState>().toggleChore(chore.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color:
                      chore.isCompleted ? AppTheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        chore.isCompleted ? AppTheme.primary : AppTheme.divider,
                    width: 2,
                  ),
                ),
                child: chore.isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_choreEmoji(chore.category),
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chore.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 14,
                                    decoration: chore.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: chore.isCompleted
                                        ? AppTheme.textSecondary
                                        : AppTheme.textPrimary,
                                  ),
                        ),
                      ),
                      if (chore.templateId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('🔄 Auto',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (assignee != null) ...[
                        if (assigneeIdx >= 0)
                          RoommateAvatar(
                              roommate: assignee,
                              size: 16,
                              colorIndex: assigneeIdx),
                        const SizedBox(width: 4),
                        Text(
                          assignee.name.split(' ').first,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                        Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                                color: AppTheme.textSecondary,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        chore.frequency,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chore.isCompleted
                    ? 'Done'
                    : chore.isOverdue
                        ? 'Overdue'
                        : chore.isDueToday
                            ? 'Today'
                            : DateFormat('MMM d').format(chore.dueDate),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn().slideX(begin: 0.05, end: 0);
  }

  // ── Rotation Tab ───────────────────────────────────────────────

  Widget _buildRotationTab(BuildContext context, AppState state) {
    final preview = state.previewWeeklyAssignments();
    final weekGenerated = state.weeklyChoresGenerated;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Status Banner ─────────────────────────────────────
        _buildStatusBanner(context, state, weekGenerated),
        const SizedBox(height: 24),

        // ── How it works ──────────────────────────────────────
        if (state.choreTemplates.isNotEmpty) ...[
          _buildHowItWorks(context, state),
          const SizedBox(height: 24),
        ],

        // ── Recurring Chore Templates ─────────────────────────
        Row(
          children: [
            Expanded(
              child: Text('Recurring Chores',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            GestureDetector(
              onTap: () => _showAddTemplateSheet(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.primary, size: 16),
                    SizedBox(width: 4),
                    Text('Add Chore',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (state.choreTemplates.isEmpty)
          _buildEmptyTemplates(context)
        else ...[
          ...state.choreTemplates.asMap().entries.map((entry) {
            final i = entry.key;
            final template = entry.value;
            final assignedTo = preview[template.id];
            final assigneeIdx = assignedTo == null
                ? 0
                : state.roommates.indexWhere((r) => r.id == assignedTo.id);
            return _buildTemplateCard(
                    context, state, template, assignedTo, assigneeIdx, i)
                .animate(delay: (i * 60).ms)
                .fadeIn()
                .slideX(begin: 0.05, end: 0);
          }),
          const SizedBox(height: 20),

          // ── Upcoming Rotation Preview ─────────────────────
          _buildRotationPreview(context, state),
        ],
      ],
    );
  }

  Widget _buildStatusBanner(
      BuildContext context, AppState state, bool weekGenerated) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: weekGenerated
              ? [AppTheme.primary, AppTheme.primaryLight]
              : [const Color(0xFF4361EE), const Color(0xFF7209B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Week of ${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (weekGenerated)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('✓ Auto-assigned',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            weekGenerated
                ? 'This week\'s chores are assigned and rotating!'
                : state.choreTemplates.isEmpty
                    ? 'Add recurring chores below to enable auto-scheduling'
                    : '${state.choreTemplates.length} chore${state.choreTemplates.length == 1 ? '' : 's'} ready — tap to assign',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (state.choreTemplates.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Chores rotate automatically every week so no one gets stuck with the same task.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _confirmGenerate(
                    context, state, state.previewWeeklyAssignments()),
                child: Text(
                  weekGenerated
                      ? '🔄 Re-generate This Week'
                      : '✨ Assign Chores Now',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context, AppState state) {
    final n = state.roommates.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🔄', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How rotation works',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Each chore shifts one person forward every week across $n roommates. A full cycle takes $n weeks.',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTemplates(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const Text('🔄', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No recurring chores yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Add chores here and they\'ll be automatically and fairly assigned to a different roommate each week.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddTemplateSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add First Chore'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
      BuildContext context,
      AppState state,
      ChoreTemplate template,
      Roommate? assignedTo,
      int assigneeIdx,
      int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_choreEmoji(template.category),
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(template.category,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (assignedTo != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme
                    .roomColors[assigneeIdx % AppTheme.roomColors.length]
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme
                        .roomColors[assigneeIdx % AppTheme.roomColors.length]
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(assignedTo.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    assignedTo.name.split(' ').first,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.roomColors[
                            assigneeIdx % AppTheme.roomColors.length]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () async {
              final ok = await showConfirmDialog(context,
                  title: 'Remove Chore',
                  message: 'Remove "${template.title}" from the rotation?');
              if (ok == true && context.mounted) {
                context.read<AppState>().deleteChoreTemplate(template.id);
              }
            },
            child: const Icon(Icons.remove_circle_outline_rounded,
                color: AppTheme.danger, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationPreview(BuildContext context, AppState state) {
    if (state.roommates.length < 2) return const SizedBox();
    final n = state.roommates.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Rotation',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Full cycle: $n weeks, one person per chore per week',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: List.generate(n, (weekOffset) {
              final weekNum = state.currentWeekNumber + weekOffset;
              final isCurrentWeek = weekOffset == 0;
              final now = DateTime.now();
              final weekStart = now
                  .subtract(Duration(days: now.weekday - 1))
                  .add(Duration(days: weekOffset * 7));

              // Calculate assignments for this future week
              final byRoommate = <String, List<String>>{};
              for (var i = 0; i < state.choreTemplates.length; i++) {
                final template = state.choreTemplates[i];
                final idx = (template.rotationOffset + weekNum) % n;
                final roommateId = state.roommates[idx].id;
                byRoommate
                    .putIfAbsent(roommateId, () => [])
                    .add(template.title);
              }

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrentWeek
                          ? AppTheme.primary.withValues(alpha: 0.04)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentWeek
                                    ? 'This\nweek'
                                    : 'Week\n+$weekOffset',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrentWeek
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary),
                              ),
                              Text(
                                DateFormat('MMM d').format(weekStart),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: byRoommate.entries.map((e) {
                              final roommate = state.getRoommateById(e.key);
                              final rIdx = state.roommates
                                  .indexWhere((r) => r.id == e.key);
                              final color = AppTheme.roomColors[
                                  rIdx % AppTheme.roomColors.length];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  '${roommate?.emoji ?? '🧑'} ${roommate?.name.split(' ').first ?? ''}: ${e.value.join(', ')}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (weekOffset < n - 1) const Divider(height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Confirm & Generate ─────────────────────────────────────────

  Future<void> _confirmGenerate(BuildContext context, AppState state,
      Map<String, Roommate> preview) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GeneratePreviewSheet(state: state, preview: preview),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().generateWeeklyChores();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${state.choreTemplates.length} chores assigned for this week!'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showAddTemplateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddTemplateSheet(),
    );
  }

  void _showAddChoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddChoreSheet(),
    );
  }

  String _choreEmoji(String category) {
    const map = {
      'Cleaning': '🧹',
      'Cooking': '🍳',
      'Dishes': '🍽️',
      'Trash': '🗑️',
      'Laundry': '👕',
      'Groceries': '🛒',
      'Yard': '🌿',
      'Repairs': '🔧',
    };
    return map[category] ?? '✅';
  }
}

// ── Generate Preview Sheet ──────────────────────────────────────
class _GeneratePreviewSheet extends StatelessWidget {
  final AppState state;
  final Map<String, Roommate> preview;
  const _GeneratePreviewSheet({required this.state, required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text("This Week's Assignments",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'The following chores will be created and assigned:',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...state.choreTemplates.map((template) {
            final assignee = preview[template.id];
            final idx = assignee == null
                ? 0
                : state.roommates.indexWhere((r) => r.id == assignee.id);
            final color = AppTheme.roomColors[idx % AppTheme.roomColors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Text(_choreEmoji(template.category),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(template.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${assignee?.emoji ?? ''} ${assignee?.name.split(' ').first ?? 'Unknown'}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm & Assign'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _choreEmoji(String category) {
    const map = {
      'Cleaning': '🧹',
      'Cooking': '🍳',
      'Dishes': '🍽️',
      'Trash': '🗑️',
      'Laundry': '👕',
      'Groceries': '🛒',
      'Yard': '🌿',
      'Repairs': '🔧',
    };
    return map[category] ?? '✅';
  }
}

// ── Add Template Sheet ──────────────────────────────────────────
class _AddTemplateSheet extends StatefulWidget {
  const _AddTemplateSheet();

  @override
  State<_AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends State<_AddTemplateSheet> {
  final _titleController = TextEditingController();
  String _category = 'Cleaning';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    final state = context.read<AppState>();
    // Stagger so templates don't all start on the same person
    final offset = state.choreTemplates.length % state.roommates.length;
    await state.addChoreTemplate(ChoreTemplate(
      id: AppState.generateId(),
      title: _titleController.text.trim(),
      category: _category,
      rotationOffset: offset,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text('Add Recurring Chore',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'This chore will rotate automatically — a different roommate gets it each week.',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Chore name (e.g. Vacuum living room)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text('Category',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AppConstants.choreCategories
                .map((cat) => CategoryChip(
                      label: cat,
                      isSelected: _category == cat,
                      onTap: () => setState(() => _category = cat),
                      color: AppTheme.accent,
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Add to Rotation'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Manual Chore Sheet ──────────────────────────────────────
class AddChoreSheet extends StatefulWidget {
  const AddChoreSheet({super.key});

  @override
  State<AddChoreSheet> createState() => _AddChoreSheetState();
}

class _AddChoreSheetState extends State<AddChoreSheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = 'Cleaning';
  String? _assignedToId;
  String _frequency = 'Weekly';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.roommates.isNotEmpty) {
        setState(() => _assignedToId = state.roommates.first.id);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _assignedToId == null) {
      return;
    }
    await context.read<AppState>().addChore(
          Chore(
            id: AppState.generateId(),
            title: _titleController.text.trim(),
            category: _category,
            assignedToId: _assignedToId!,
            dueDate: _dueDate,
            frequency: _frequency,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Text('Add Chore', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Chore name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Text('Category',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppConstants.choreCategories
                  .map((cat) => CategoryChip(
                        label: cat,
                        isSelected: _category == cat,
                        onTap: () => setState(() => _category = cat),
                        color: AppTheme.accent,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Assign to',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            RoommateSelectorRow(
              roommates: state.roommates,
              selectedId: _assignedToId,
              onSelect: (id) => setState(() => _assignedToId = id),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frequency',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(),
                        items: AppConstants.choreFrequencies
                            .map((f) =>
                                DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) => setState(() => _frequency = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Due Date',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _dueDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(DateFormat('MMM d').format(_dueDate),
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Add Chore'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
