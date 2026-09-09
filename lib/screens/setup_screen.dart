import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _mode; // null | 'create' | 'join'

  @override
  Widget build(BuildContext context) {
    if (_mode == 'create') {
      return _CreateHouseholdFlow(onBack: () => setState(() => _mode = null));
    }
    if (_mode == 'join') {
      return _JoinHouseholdScreen(onBack: () => setState(() => _mode = null));
    }
    return _buildLanding();
  }

  Widget _buildLanding() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏠',
                style: TextStyle(fontSize: 72),
              ).animate().fadeIn().scale(begin: const Offset(0.6, 0.6)),
              const SizedBox(height: 20),
              Text(
                'Set Up Your\nShared Home',
                style: Theme.of(context).textTheme.displayLarge,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 10),
              Text(
                'Create a household or join one\nyour roommate already set up.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _mode = 'create'),
                  icon: const Icon(Icons.add_home_rounded),
                  label: const Text('Create New Household'),
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = 'join'),
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Join with Invite Code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppTheme.primary),
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 28),
              Center(
                child: TextButton(
                  onPressed: () => context.read<AppState>().signOut(),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// JOIN HOUSEHOLD
// ══════════════════════════════════════════════════════════════════
class _JoinHouseholdScreen extends StatefulWidget {
  final VoidCallback onBack;
  const _JoinHouseholdScreen({required this.onBack});
  @override
  State<_JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends State<_JoinHouseholdScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Roommate>? _roommates;
  String? _pickedId;

  /// Roommate IDs that are already taken by another user
  Set<String> _claimedIds = {};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _findHousehold() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = 'Enter a 6-character code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('households')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        setState(() => _error = 'No household found with that code.');
        return;
      }

      final householdId = snap.docs.first.id;
      final config = RoomConfig.fromJson(snap.docs.first.data());

      // Load which slots are already claimed
      final metaSnap = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('meta')
          .doc('data')
          .get();

      final rawJoinedBy =
          (metaSnap.data()?['joinedBy'] as Map<String, dynamic>? ?? {});
      final joinedBy = rawJoinedBy.map((k, v) => MapEntry(k, v as String));

      // Current user's own uid — if they already claimed a slot, allow re-selecting
      if (!mounted) return;
      final myUid = context.read<AppState>().currentUid;
      final claimed = joinedBy.entries
          .where((e) => e.value != myUid)
          .map((e) => e.key)
          .toSet();

      // Pick the first available slot by default
      final available =
          config.roommates.where((r) => !claimed.contains(r.id)).toList();

      setState(() {
        _roommates = config.roommates;
        _claimedIds = claimed;
        _pickedId = available.isNotEmpty ? available.first.id : null;
      });
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    if (_pickedId == null) return;
    setState(() => _loading = true);
    try {
      final ok = await context.read<AppState>().joinHousehold(
            _ctrl.text.trim(),
            _pickedId!,
          );
      if (!ok && mounted) {
        setState(() => _error = 'Failed to join. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCount =
        (_roommates?.where((r) => !_claimedIds.contains(r.id)).length ?? 0);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Join Household'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👥', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Enter Invite Code',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask whoever set up the household to share the 6-character code.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'e.g. AB3X9Z',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              enabled: _roommates == null,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              ),
            ],
            if (_roommates != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Which one are you?',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const Spacer(),
                  if (_claimedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$availableCount slot${availableCount == 1 ? '' : 's'} available',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ..._roommates!.asMap().entries.map((e) {
                final r = e.value;
                final color =
                    AppTheme.roomColors[e.key % AppTheme.roomColors.length];
                final sel = _pickedId == r.id;
                final isClaimed = _claimedIds.contains(r.id);

                return GestureDetector(
                  onTap:
                      isClaimed ? null : () => setState(() => _pickedId = r.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isClaimed
                          ? AppTheme.surface
                          : sel
                              ? color.withValues(alpha: 0.1)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isClaimed
                            ? AppTheme.divider
                            : sel
                                ? color
                                : AppTheme.divider,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          r.emoji,
                          style: TextStyle(
                            fontSize: 28,
                            color: isClaimed ? null : null,
                          ), // dimmed via opacity below
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: isClaimed
                                          ? AppTheme.textSecondary
                                          : sel
                                              ? color
                                              : AppTheme.textPrimary,
                                    ),
                              ),
                              if (isClaimed)
                                const Text(
                                  'Already joined',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isClaimed)
                          const Icon(
                            Icons.lock_rounded,
                            color: AppTheme.textSecondary,
                            size: 18,
                          )
                        else if (sel)
                          Icon(Icons.check_circle_rounded, color: color),
                      ],
                    ),
                  ),
                );
              }),
              if (_pickedId == null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.danger,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All slots are taken. Ask your roommate to add more people.',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _pickedId == null) ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Let's Go! 🎉"),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _findHousehold,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Find Household →'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CREATE HOUSEHOLD (3-step wizard)
// ══════════════════════════════════════════════════════════════════
class _CreateHouseholdFlow extends StatefulWidget {
  final VoidCallback onBack;
  const _CreateHouseholdFlow({required this.onBack});
  @override
  State<_CreateHouseholdFlow> createState() => _CreateHouseholdFlowState();
}

class _CreateHouseholdFlowState extends State<_CreateHouseholdFlow> {
  int _step = 0, _selectedSize = 2;
  final _roomNameCtrl = TextEditingController(text: 'Our Room');
  final List<TextEditingController> _nameCtrl = [];
  final List<String> _emojis = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  void _rebuild() {
    for (final c in _nameCtrl) {
      c.dispose();
    }
    _nameCtrl.clear();
    _emojis.clear();
    for (int i = 0; i < _selectedSize; i++) {
      _nameCtrl.add(TextEditingController(text: 'Roommate ${i + 1}'));
      _emojis.add(
        AppConstants.avatarEmojis[i % AppConstants.avatarEmojis.length],
      );
    }
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    for (final c in _nameCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectSize(int s) => setState(() {
        _selectedSize = s;
        _rebuild();
      });
  void _next() {
    if (_step < 2) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      widget.onBack();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final roommates = List.generate(
      _selectedSize,
      (i) => Roommate(
        id: AppState.generateId(),
        name: _nameCtrl[i].text.trim().isEmpty
            ? 'Roommate ${i + 1}'
            : _nameCtrl[i].text.trim(),
        emoji: _emojis[i],
      ),
    );
    try {
      await context.read<AppState>().createHousehold(
            _roomNameCtrl.text.trim().isEmpty
                ? 'Our Room'
                : _roomNameCtrl.text.trim(),
            roommates,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _progressBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (c, a) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: _buildStep(),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    const t = ['How many roommates?', 'Name your room', 'Meet your roommates'];
    const s = [
      'Select the number of people sharing this space',
      'Give your shared space a name',
      "Enter everyone's name and pick an avatar",
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏠', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'Step ${_step + 1} of 3',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t[_step],
            style: Theme.of(context).textTheme.displayMedium,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            s[_step],
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
          ).animate().fadeIn(delay: 100.ms),
        ],
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= _step ? AppTheme.primary : AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _sizeStep();
      case 1:
        return _nameStep();
      case 2:
        return _roommatesStep();
      default:
        return const SizedBox();
    }
  }

  Widget _sizeStep() {
    return SingleChildScrollView(
      key: const ValueKey('s0'),
      padding: const EdgeInsets.all(24),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: List.generate(6, (i) {
          final sz = i + 2, sel = _selectedSize == sz;
          final c = AppTheme.roomColors[i % AppTheme.roomColors.length];
          return GestureDetector(
            onTap: () => _selectSize(sz),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: sel ? c : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? c : AppTheme.divider,
                  width: sel ? 2 : 1,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_ic(sz), style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    '$sz people',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: sel ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    _lbl(sz),
                    style: TextStyle(
                      fontSize: 11,
                      color: sel
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate(delay: (i * 60).ms)
              .fadeIn()
              .scale(begin: const Offset(0.9, 0.9));
        }),
      ),
    );
  }

  String _ic(int n) {
    const ic = ['🧑', '👩', '👨', '🧔', '👩‍🦱', '👨‍🦱', '🧑‍🦲'];
    return List.generate(n > 4 ? 4 : n, (i) => ic[i % ic.length]).join('');
  }

  String _lbl(int n) {
    const m = {
      2: 'Couple/Duo',
      3: 'Small group',
      4: 'Quad room',
      5: 'Five-share',
      6: 'Six-share',
    };
    return m[n] ?? '';
  }

  Widget _nameStep() {
    return SingleChildScrollView(
      key: const ValueKey('s1'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text('🏠', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 20),
                TextField(
                  controller: _roomNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'e.g. The Nest, Casa Nova...',
                  ),
                  textCapitalization: TextCapitalization.words,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.95, 0.95)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children:
                ['The Nest', 'Casa Nova', 'Home Base', 'The Pad', 'Our Place']
                    .map(
                      (n) => ActionChip(
                        label: Text(n),
                        onPressed: () => _roomNameCtrl.text = n,
                      ),
                    )
                    .toList(),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _roommatesStep() {
    return ListView.separated(
      key: const ValueKey('s2'),
      padding: const EdgeInsets.all(24),
      itemCount: _selectedSize,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final c = AppTheme.roomColors[i % AppTheme.roomColors.length];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _emojiPicker(i),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _nameCtrl[i],
                  decoration: InputDecoration(
                    labelText: 'Roommate ${i + 1} name',
                    hintText: 'Enter name',
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: (i * 80).ms).fadeIn().slideX(begin: 0.1, end: 0);
      },
    );
  }

  void _emojiPicker(int idx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick an avatar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppConstants.avatarEmojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () {
                        setState(() => _emojis[idx] = e);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _emojis[idx] == e
                                ? AppTheme.primary
                                : AppTheme.divider,
                            width: _emojis[idx] == e ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: AppTheme.divider),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saving ? null : (_step < 2 ? _next : _finish),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_step < 2 ? 'Continue →' : "Let's Go! 🎉"),
            ),
          ),
        ],
      ),
    );
  }
}
