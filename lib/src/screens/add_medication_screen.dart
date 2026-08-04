import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../db/app_db.dart';
import '../repositories/medication_repository.dart';
import '../services/medication_notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.existingMedication,
    this.existingTimes,
  });
  final Medication? existingMedication;
  final List<String>? existingTimes;

  @override
  ConsumerState<AddMedicationScreen> createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final List<TimeOfDay> _times = [];
  bool _saving = false;

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    final existing = widget.existingMedication;
    if (existing != null) {
      _nameController.text = existing.name;
      _dosageController.text = existing.dosage ?? '';
      _notesController.text = existing.notes ?? '';
      for (final time in widget.existingTimes ?? const <String>[]) {
        final parts = time.split(':');
        if (parts.length == 2) {
          _times.add(
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = isPhoneWidth(context);
    final canSave = _nameController.text.trim().isNotEmpty && _times.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Medication',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderGlass),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          isPhone ? 16 : 24,
          isPhone ? 16 : 24,
          isPhone ? 16 : 24,
          24,
        ),
        children: [
          const _SectionLabel('MEDICATION DETAILS'),
          const SizedBox(height: 10),
          AppDarkField(
            controller: _nameController,
            label: 'Medicine name',
            placeholder: 'e.g. Vitamin D, Metformin…',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppDarkField(
            controller: _dosageController,
            label: 'Dosage',
            placeholder: 'e.g. 500mg, 1 tablet…',
          ),
          const SizedBox(height: 12),
          AppDarkField(
            controller: _notesController,
            label: 'Notes',
            placeholder: 'e.g. Take with food…',
            maxLines: 2,
          ),
          const SizedBox(height: 28),
          const _SectionLabel('DAILY REMINDER TIMES'),
          const SizedBox(height: 6),
          const Text(
            'Add each time you need to take this medicine.',
            style: TextStyle(color: AppColors.textSubtle, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Time chips
          if (_times.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _times
                    .map(
                      (t) => _TimeChip(
                        time: t,
                        onRemove: () => setState(() => _times.remove(t)),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Add time button
          GestureDetector(
            onTap: _addTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: AppDecorations.glassCard(),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Add reminder time',
                    style: TextStyle(
                      color: AppColors.accentSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          AppSaveButton(
            saving: _saving,
            enabled: canSave,
            label: widget.existingMedication == null
                ? 'Save & Schedule Reminders'
                : 'Save Changes',
            onTap: _save,
          ),
          if (!canSave &&
              _times.isEmpty &&
              _nameController.text.trim().isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Add at least one reminder time to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: AppTheme.pickerOverlay,
    );
    if (selected == null) {
      return;
    }
    if (_times.any(
      (t) => t.hour == selected.hour && t.minute == selected.minute,
    )) {
      return;
    }
    setState(() => _times.add(selected));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _times.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(medicationRepositoryProvider.future);
      final userId = ref.read(userIdProvider);
      final sortedTimes = [..._times]
        ..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );
      final times = sortedTimes.map(_fmt24).toList();

      if (widget.existingMedication == null) {
        final medication = await repo.addMedication(
          userId: userId,
          name: name,
          dosage: _dosageController.text.trim().isEmpty
              ? null
              : _dosageController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          times: times,
        );
        await MedicationNotificationService.instance.scheduleDailyMedication(
          MedicationWithTimes(medication: medication, times: times),
        );
      } else {
        final existingMedication = widget.existingMedication!;
        await MedicationNotificationService.instance.cancelMedicationSchedules(
          existingMedication.id,
          widget.existingTimes ?? const <String>[],
        );
        await repo.updateMedication(
          medication: existingMedication,
          name: name,
          dosage: _dosageController.text.trim().isEmpty
              ? null
              : _dosageController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          times: times,
        );
        await MedicationNotificationService.instance.scheduleDailyMedication(
          MedicationWithTimes(medication: existingMedication, times: times),
        );
      }

      ref.invalidate(medicationsProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save medication. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onRemove});
  final TimeOfDay time;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final label = '$displayHour:$minute $period';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: AppDecorations.glassChip(selected: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 13,
            color: AppColors.accentSoft,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accentSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// Shared form components (re-used from add_habit_screen but scoped here for clarity)
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
