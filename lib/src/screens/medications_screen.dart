import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../repositories/medication_repository.dart';
import '../services/medication_notification_service.dart';
import '../theme/app_theme.dart';
import 'add_medication_screen.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends ConsumerState<MedicationsScreen> {
  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final medsAsync = ref.watch(medicationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 16 : 28,
                isPhone ? 18 : 36,
                isPhone ? 16 : 28,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEDICATIONS',
                        style: TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daily reminders',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: isPhone ? 22 : 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  _AddButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AddMedicationScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isPhone ? 14 : 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
              child: medsAsync.when(
                data: (meds) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: AppDecorations.glassCard(elevated: true),
                  child: Row(
                    children: [
                      _StatPill(label: 'Total meds', value: '${meds.length}'),
                      const SizedBox(width: 8),
                      _StatPill(
                        label: 'Doses/day',
                        value:
                            '${meds.fold<int>(0, (sum, m) => sum + m.times.length)}',
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stack) => const SizedBox.shrink(),
              ),
            ),
            SizedBox(height: isPhone ? 12 : 16),

            Expanded(
              child: medsAsync.when(
                data: (meds) {
                  if (meds.isEmpty) {
                    return _EmptyState();
                  }
                  return ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isPhone ? 12 : 24,
                      0,
                      isPhone ? 12 : 24,
                      32,
                    ),
                    buildDefaultDragHandles: false,
                    itemCount: meds.length,
                    onReorder: (oldIndex, newIndex) async {
                      final repo = await ref.read(
                        medicationRepositoryProvider.future,
                      );
                      final reordered = [...meds];
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, item);
                      await repo.reorderMedications(
                        reordered.map((m) => m.medication.id).toList(),
                      );
                      ref.invalidate(medicationsProvider);
                    },
                    itemBuilder: (context, i) => Padding(
                      key: ValueKey(meds[i].medication.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReorderActivator(
                        index: i,
                        child: _MedCard(med: meds[i]),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
                error: (_, _) => const Center(
                  child: Text(
                    'Could not load medications.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedCard extends ConsumerWidget {
  const _MedCard({required this.med});
  final MedicationWithTimes med;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: AppDecorations.glassCard(
        elevated: true,
      ).copyWith(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.accentSoft.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.accentSoft,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.medication.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((med.medication.dosage ?? '').isNotEmpty)
                      Text(
                        med.medication.dosage!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                color: AppColors.surface,
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSubtle,
                  size: 18,
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    if (context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddMedicationScreen(
                            existingMedication: med.medication,
                            existingTimes: med.times,
                          ),
                        ),
                      );
                      ref.invalidate(medicationsProvider);
                    }
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text(
                          'Delete medication?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'This will remove it from your active list.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final repo = await ref.read(
                        medicationRepositoryProvider.future,
                      );
                      await MedicationNotificationService.instance
                          .cancelMedicationSchedules(
                            med.medication.id,
                            med.times,
                          );
                      await repo.deleteMedication(med.medication.id);
                      ref.invalidate(medicationsProvider);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: TextStyle(color: Colors.white)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((med.medication.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                med.medication.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.2,
                  height: 1.2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: med.times.map((t) => _TimeChip(time: t)).toList(),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.glassChip(selected: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 12,
            color: AppColors.accentSoft,
          ),
          const SizedBox(width: 5),
          Text(
            _formatTime(time),
            style: const TextStyle(
              color: AppColors.accentSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:$minute $period';
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: AppDecorations.glassChip(selected: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: AppDecorations.glassChip(selected: true),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.accentSoft),
            SizedBox(width: 4),
            Text(
              'Add med',
              style: TextStyle(
                color: AppColors.accentSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceGlass,
              border: Border.all(color: AppColors.borderGlass),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 16,
                  spreadRadius: -6,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.medication_rounded,
              size: 36,
              color: AppColors.textSubtle,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No medications yet',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first medicine to get daily reminders.',
            style: TextStyle(color: AppColors.textSubtle, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ReorderActivator extends StatelessWidget {
  const _ReorderActivator({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    if (isDesktop) {
      return ReorderableDragStartListener(index: index, child: child);
    }
    return ReorderableDelayedDragStartListener(index: index, child: child);
  }
}
