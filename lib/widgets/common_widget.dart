import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../models/models.dart';

// ── Currency Helper ───────────────────────────────────────────────
/// Formats an amount in Ghana Cedis (₵).
/// e.g.  formatGHS(12.5)  →  "₵12.50"
String formatGHS(double amount, {bool showSign = false}) {
  final abs = amount.abs();
  final formatted = abs < 10
      ? abs.toStringAsFixed(2)
      : abs >= 1000
          ? '${(abs / 1000).toStringAsFixed(1)}k'
          : abs.toStringAsFixed(2);
  if (showSign && amount > 0.01) return '+₵$formatted';
  if (amount < -0.01) return '-₵$formatted';
  return '₵$formatted';
}

String formatGHSFull(double amount) => '₵${amount.abs().toStringAsFixed(2)}';

// ── AppConstants ───────────────────────────────────────────────────
class AppConstants {
  static const List<String> categories = [
    'Rent',
    'Utilities',
    'Groceries',
    'Cleaning',
    'Internet',
    'Laundry',
    'Transport',
    'Eating Out',
    'Entertainment',
    'Other',
  ];

  static const Map<String, String> categoryEmojis = {
    'Rent': '🏠',
    'Utilities': '💡',
    'Groceries': '🛒',
    'Cleaning': '🧹',
    'Internet': '📶',
    'Laundry': '👕',
    'Transport': '🚌',
    'Eating Out': '🍽️',
    'Entertainment': '🎉',
    'Other': '📦',
  };

  static const Map<String, String> choreEmojis = {
    'Cleaning': '🧹',
    'Kitchen': '🍳',
    'Bathroom': '🚿',
    'Trash': '🗑️',
    'Laundry': '👕',
    'Dishes': '🍽️',
    'Grocery': '🛒',
    'Garden': '🌿',
    'Other': '✅',
  };

  static const List<String> avatarEmojis = [
    '🧑',
    '👩',
    '👨',
    '🧔',
    '👱',
    '👩‍🦰',
    '👨‍🦰',
    '👩‍🦱',
    '👨‍🦱',
    '👩‍🦳',
    '👨‍🦳',
    '🧕',
    '👲',
    '🧑‍🦲',
    '😎',
    '🤓',
    '🥸',
    '🧑‍💻',
    '👩‍🎤',
    '👨‍🎤',
  ];
}

// ── Roommate Avatar ───────────────────────────────────────────────
class RoommateAvatar extends StatelessWidget {
  final Roommate roommate;
  final double size;
  final int colorIndex;
  final bool showName;

  const RoommateAvatar({
    super.key,
    required this.roommate,
    this.size = 40,
    this.colorIndex = 0,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.roomColors[colorIndex % AppTheme.roomColors.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              roommate.emoji,
              style: TextStyle(fontSize: size * 0.46),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 5),
          Text(
            roommate.name.split(' ').first,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.primary),
            ),
          ),
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Category Chip ──────────────────────────────────────────────────
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? activeColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.divider),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onButton, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Balance Badge ──────────────────────────────────────────────────
class BalanceBadge extends StatelessWidget {
  final double amount;
  final bool compact;

  const BalanceBadge({super.key, required this.amount, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isZero = amount.abs() < 0.01;
    final isPositive = amount > 0.01;

    final color = isZero
        ? AppTheme.textSecondary
        : isPositive
            ? AppTheme.success
            : AppTheme.danger;
    final bg = isZero
        ? AppTheme.surface
        : isPositive
            ? AppTheme.successSurface
            : AppTheme.dangerSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        isZero
            ? 'Settled'
            : isPositive
                ? '+${formatGHSFull(amount)}'
                : '-${formatGHSFull(amount)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ── Confirmation Dialog ────────────────────────────────────────────
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  Color confirmColor = AppTheme.danger,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

// ── Invite Code Card ───────────────────────────────────────────────
class InviteCodeCard extends StatefulWidget {
  final String code;
  const InviteCodeCard({super.key, required this.code});

  @override
  State<InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends State<InviteCodeCard> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Household Invite Code',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.code,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 10,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.code));
                  setState(() => _copied = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => _copied = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _copied
                        ? AppTheme.successSurface
                        : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: _copied
                          ? AppTheme.success.withValues(alpha: 0.3)
                          : AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    color: _copied ? AppTheme.success : AppTheme.primary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _copied ? '✓ Copied to clipboard' : 'Share with roommates to join',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _copied ? AppTheme.success : AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet Handle ───────────────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Roommate Selector Row ──────────────────────────────────────────
class RoommateSelectorRow extends StatelessWidget {
  final List<Roommate> roommates;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const RoommateSelectorRow({
    super.key,
    required this.roommates,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: roommates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = roommates[i];
          final isSelected = selectedId == r.id;
          final color = AppTheme.roomColors[i % AppTheme.roomColors.length];
          return GestureDetector(
            onTap: () => onSelect(r.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? color.withValues(alpha: 0.1) : AppTheme.card,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? color : AppTheme.divider,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 7),
                  Text(
                    r.name.split(' ').first,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isSelected ? color : AppTheme.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Info Banner ────────────────────────────────────────────────────
class InfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const InfoBanner({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading Button ─────────────────────────────────────────────────
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final Color? backgroundColor;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: backgroundColor != null
            ? ElevatedButton.styleFrom(backgroundColor: backgroundColor)
            : null,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
