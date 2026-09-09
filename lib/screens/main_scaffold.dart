import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart' hide AppConstants;
import 'home_screen.dart';
import 'chores_screen.dart';
import 'expenses_screen.dart';
import 'grocery_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  void _switchTab(int index) => setState(() => _currentIndex = index);

  static const _tabs = [
    _TabItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _TabItem(
        Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Expenses'),
    _TabItem(
        Icons.checklist_rtl_rounded, Icons.checklist_rtl_outlined, 'Chores'),
    _TabItem(Icons.shopping_basket_rounded, Icons.shopping_basket_outlined,
        'Grocery'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final screens = [
      HomeScreen(
          onNavigate: _switchTab, onSettings: () => _showSettings(context)),
      const ExpensesScreen(),
      const ChoresScreen(),
      const GroceryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildNav(state),
    );
  }

  Widget _buildNav(AppState state) {
    final badges = [
      null,
      null,
      state.overdueChoresCount > 0 ? state.overdueChoresCount : null,
      state.unpurchasedCount > 0 ? state.unpurchasedCount : null,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isSelected = _currentIndex == i;
              final badge = badges[i];
              return _NavItem(
                tab: tab,
                isSelected: isSelected,
                badge: badge,
                onTap: () => _switchTab(i),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────
class _TabItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  const _TabItem(this.activeIcon, this.inactiveIcon, this.label);
}

class _NavItem extends StatelessWidget {
  final _TabItem tab;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? tab.activeIcon : tab.inactiveIcon,
                    key: ValueKey(isSelected),
                    color:
                        isSelected ? AppTheme.primary : AppTheme.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color:
                        isSelected ? AppTheme.primary : AppTheme.textTertiary,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(tab.label),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.card, width: 1.5),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Settings Bottom Sheet ──────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final code = state.inviteCode;
    final me = state.currentRoommate;
    final myIndex =
        me != null ? state.roommates.indexWhere((r) => r.id == me.id) : 0;
    final myColor = AppTheme.roomColors[
        myIndex.clamp(0, AppTheme.roomColors.length - 1) %
            AppTheme.roomColors.length];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),

          // ── Header ──
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Center(
                    child: Text('🏠', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.roomConfig?.roomName ?? 'Your Household',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (state.currentUserEmail != null)
                      Text(
                        state.currentUserEmail!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── My Profile ──
          if (me != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: myColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: myColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(me.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.name,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text('Your profile',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _EditProfileSheet(
                        roommate: me,
                        colorIndex: myIndex,
                        state: state,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: myColor,
                    side: BorderSide(color: myColor.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // ── Invite code ──
          if (code != null) ...[
            Text('Invite Code',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            InviteCodeCard(code: code),
            const SizedBox(height: 8),
            Text(
              'Anyone with this code can join your household.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // ── Roommates ──
          Text(
            'Roommates  (${state.roommates.length})',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.roommates.asMap().entries.map((e) {
              final r = e.value;
              final color =
                  AppTheme.roomColors[e.key % AppTheme.roomColors.length];
              final isMe = r.id == state.currentRoommateId;
              final isClaimed = state.joinedBy.containsKey(r.id);
              return _RoommatePill(
                roommate: r,
                color: color,
                isMe: isMe,
                isClaimed: isClaimed,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // ── Sign Out ──  (FIX: confirm BEFORE popping)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Sign Out',
                  message: 'Are you sure you want to sign out?',
                  confirmLabel: 'Sign Out',
                  confirmColor: AppTheme.danger,
                );
                if (ok == true && context.mounted) {
                  Navigator.pop(context);
                  await context.read<AppState>().signOut();
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── Roommate Pill ─────────────────────────────────────────────────
class _RoommatePill extends StatelessWidget {
  final Roommate roommate;
  final Color color;
  final bool isMe;
  final bool isClaimed;

  const _RoommatePill({
    required this.roommate,
    required this.color,
    required this.isMe,
    required this.isClaimed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(roommate.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            roommate.name.split(' ').first,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
          if (isMe) ...[
            const SizedBox(width: 5),
            _Pill('you', color),
          ] else if (!isClaimed) ...[
            const SizedBox(width: 5),
            _Pill('not joined', AppTheme.textTertiary),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w600)),
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

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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

            // ── Avatar Picker ──
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

            // ── Name ──
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
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radius2xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
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
                        child: Text(e, style: const TextStyle(fontSize: 28))),
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
