import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/common_widget.dart' hide AppConstants;

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  String _categoryFilter = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allItems = state.groceryItems;
    final unpurchased = allItems.where((g) => !g.isPurchased).toList();
    final purchased = allItems.where((g) => g.isPurchased).toList();

    // Filter by category + search
    List<GroceryItem> filterItems(List<GroceryItem> items) {
      var result = items;
      if (_categoryFilter != 'All') {
        result = result.where((g) => g.category == _categoryFilter).toList();
      }
      if (_searchQuery.isNotEmpty) {
        result = result
            .where((g) => g.name.toLowerCase().contains(_searchQuery))
            .toList();
      }
      return result;
    }

    final filteredUnpurchased = filterItems(unpurchased);
    final filteredPurchased = filterItems(purchased);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery List'),
        actions: [
          if (purchased.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              color: AppTheme.danger,
              tooltip: 'Clear purchased',
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Clear Purchased',
                  message: 'Remove all ${purchased.length} purchased items?',
                );
                if (ok == true && context.mounted) {
                  context.read<AppState>().clearPurchasedItems();
                }
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppTheme.primary,
              size: 28,
            ),
            onPressed: () => _showAddItemSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ── Log Grocery Run button — visible when there are unpurchased items ──
      bottomNavigationBar: unpurchased.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_cart_checkout_rounded),
                  label: Text(
                    'Log Grocery Run  (${unpurchased.length} items)',
                  ),
                  onPressed: () => _showGroceryRunSheet(context, state),
                ),
              ),
            )
          : null,
      body: allItems.isEmpty
          ? EmptyState(
              emoji: '🛒',
              title: 'Grocery list is empty',
              subtitle: 'Add items you need to buy',
              buttonLabel: 'Add Item',
              onButton: () => _showAddItemSheet(context),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                // Category filter row
                _buildCategoryFilter(context, allItems),
                // Progress indicator
                _buildProgressBar(
                  context,
                  unpurchased.length,
                  purchased.length,
                ),
                // List
                Expanded(
                  child: (filteredUnpurchased.isEmpty &&
                          filteredPurchased.isEmpty)
                      ? const EmptyState(
                          emoji: '🔍',
                          title: 'No items found',
                          subtitle: 'Try a different search or category',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          children: [
                            if (filteredUnpurchased.isNotEmpty) ...[
                              _buildSectionHeader(
                                context,
                                'To Buy',
                                filteredUnpurchased.length,
                                AppTheme.primary,
                              ),
                              const SizedBox(height: 10),
                              ...filteredUnpurchased.asMap().entries.map(
                                    (e) => _buildGroceryTile(
                                      context,
                                      e.value,
                                      state,
                                      e.key,
                                    ),
                                  ),
                              const SizedBox(height: 16),
                            ],
                            if (filteredPurchased.isNotEmpty) ...[
                              _buildSectionHeader(
                                context,
                                'Purchased',
                                filteredPurchased.length,
                                AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 10),
                              ...filteredPurchased.asMap().entries.map(
                                    (e) => _buildGroceryTile(
                                      context,
                                      e.value,
                                      state,
                                      e.key,
                                    ),
                                  ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  // ── Log Grocery Run sheet ──────────────────────────────────────────
  void _showGroceryRunSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroceryRunSheet(state: state),
    );
  }

  Widget _buildCategoryFilter(BuildContext context, List<GroceryItem> items) {
    final usedCats = items.map((g) => g.category).toSet().toList()..sort();
    if (usedCats.length <= 1) return const SizedBox(height: 4);

    final cats = ['All', ...usedCats];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => CategoryChip(
          label: cats[i] == 'All'
              ? 'All'
              : '${AppConstants.groceryCategoryEmojis[cats[i]] ?? '🛒'} ${cats[i]}',
          isSelected: _categoryFilter == cats[i],
          onTap: () => setState(() => _categoryFilter = cats[i]),
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    int unpurchased,
    int purchased,
  ) {
    final total = unpurchased + purchased;
    if (total == 0) return const SizedBox();
    final progress = purchased / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$purchased of $total items checked',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          progress == 1.0 ? AppTheme.success : AppTheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.divider,
              color: progress == 1.0 ? AppTheme.success : AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    Color color,
  ) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroceryTile(
    BuildContext context,
    GroceryItem item,
    AppState state,
    int index,
  ) {
    final adder = state.getRoommateById(item.addedById);
    final adderIdx = state.roommates.indexWhere((r) => r.id == item.addedById);
    final catEmoji = AppConstants.groceryCategoryEmojis[item.category] ?? '🛒';

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.danger),
      ),
      onDismissed: (_) => context.read<AppState>().deleteGroceryItem(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isPurchased ? AppTheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => context.read<AppState>().toggleGroceryItem(item.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color:
                      item.isPurchased ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        item.isPurchased ? AppTheme.primary : AppTheme.divider,
                    width: 2,
                  ),
                ),
                child: item.isPurchased
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // Category emoji
            Text(catEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          decoration: item.isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isPurchased
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                  ),
                  if (adder != null)
                    Row(
                      children: [
                        if (adderIdx >= 0)
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.roomColors[
                                  adderIdx % AppTheme.roomColors.length],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                adder.emoji,
                                style: const TextStyle(fontSize: 8),
                              ),
                            ),
                          ),
                        Text(
                          '${adder.name.split(' ').first} · ${item.category}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Quantity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: item.isPurchased
                    ? AppTheme.surface
                    : AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.isPurchased
                      ? AppTheme.divider
                      : AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                '${item.quantity} ${item.unit}',
                style: TextStyle(
                  color: item.isPurchased
                      ? AppTheme.textSecondary
                      : AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 40).ms).fadeIn();
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddGroceryItemSheet(),
    );
  }
}

// ── Grocery Run Sheet ────────────────────────────────────────────────
// Lets a roommate log the total they spent on a grocery run.
// The total is split equally among all roommates and saved as a
// Groceries expense. All unpurchased items are then marked as purchased.
class _GroceryRunSheet extends StatefulWidget {
  final AppState state;
  const _GroceryRunSheet({required this.state});

  @override
  State<_GroceryRunSheet> createState() => _GroceryRunSheetState();
}

class _GroceryRunSheetState extends State<_GroceryRunSheet> {
  final _totalCtrl = TextEditingController();
  late String _buyerId;
  late List<String> _splitWith;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _buyerId =
        widget.state.currentRoommateId ?? widget.state.roommates.first.id;
    _splitWith = widget.state.roommates.map((r) => r.id).toList();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final total = double.tryParse(_totalCtrl.text.trim());
    if (total == null || total <= 0) return;

    setState(() => _saving = true);

    try {
      final unpurchased =
          widget.state.groceryItems.where((i) => !i.isPurchased).toList();

      // Distribute the entered total evenly across items so each
      // item carries a proportional price for the expense note.
      final priceEach = total / (unpurchased.isEmpty ? 1 : unpurchased.length);

      final pricedItems = unpurchased
          .map(
            (i) => GroceryItem(
              id: i.id,
              name: i.name,
              quantity: i.quantity,
              unit: i.unit,
              isPurchased: i.isPurchased,
              addedById: i.addedById,
              note: i.note,
              category: i.category,
              price: priceEach,
            ),
          )
          .toList();

      await widget.state.settleGroceryRun(
        buyerId: _buyerId,
        items: pricedItems,
        splitBetween: _splitWith,
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final unpurchased = state.groceryItems.where((i) => !i.isPurchased).length;
    final pad = MediaQuery.of(context).viewInsets.bottom;

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),

            Text(
              'Log Grocery Run',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '$unpurchased item${unpurchased == 1 ? '' : 's'} will be marked as purchased and split equally.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            // ── Who bought? ──
            Text('Who bought?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            RoommateSelectorRow(
              roommates: state.roommates,
              selectedId: _buyerId,
              onSelect: (id) => setState(() => _buyerId = id),
            ),

            const SizedBox(height: 16),

            // ── Total amount ──
            TextField(
              controller: _totalCtrl,
              decoration: const InputDecoration(
                labelText: 'Total spent (₵)',
                prefixText: '₵ ',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),

            // ── Per-person preview ──
            Builder(builder: (_) {
              final total = double.tryParse(_totalCtrl.text.trim()) ?? 0.0;
              if (total <= 0 || _splitWith.isEmpty) {
                return const SizedBox(height: 16);
              }
              final perPerson = total / _splitWith.length;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
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
                          '₵${total.toStringAsFixed(2)} ÷ ${_splitWith.length} people',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.primary),
                        ),
                      ),
                      Text(
                        '= ₵${perPerson.toStringAsFixed(2)} each',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            LoadingButton(
              isLoading: _saving,
              onPressed: (double.tryParse(_totalCtrl.text.trim()) ?? 0) > 0
                  ? _confirm
                  : null,
              label: 'Add to Expenses & Mark Purchased',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Grocery Item Sheet ───────────────────────────────────────
class AddGroceryItemSheet extends StatefulWidget {
  const AddGroceryItemSheet({super.key});

  @override
  State<AddGroceryItemSheet> createState() => _AddGroceryItemSheetState();
}

class _AddGroceryItemSheetState extends State<AddGroceryItemSheet> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  String _unit = 'pcs';
  String? _addedById;
  String _category = 'General';

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'L',
    'mL',
    'pack',
    'bottle',
    'box',
    'bag',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.roommates.isNotEmpty) {
        final currentId = state.currentRoommateId;
        setState(() => _addedById = currentId ?? state.roommates.first.id);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _addedById == null) return;
    final qty = int.tryParse(_qtyController.text) ?? 1;
    await context.read<AppState>().addGroceryItem(
          GroceryItem(
            id: AppState.generateId(),
            name: _nameController.text.trim(),
            quantity: qty,
            unit: _unit,
            addedById: _addedById!,
            category: _category,
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
            Text(
              'Add Grocery Item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: AppConstants.groceryCategories
                  .map(
                    (cat) => CategoryChip(
                      label:
                          '${AppConstants.groceryCategoryEmojis[cat] ?? '🛒'} $cat',
                      isSelected: _category == cat,
                      onTap: () => setState(() => _category = cat),
                      color: AppTheme.primary,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Added by',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            RoommateSelectorRow(
              roommates: state.roommates,
              selectedId: _addedById,
              onSelect: (id) => setState(() => _addedById = id),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Brand preference',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: const Text('Add to List'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
