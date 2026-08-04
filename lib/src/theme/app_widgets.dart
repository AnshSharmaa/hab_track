import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Primary pill CTA used on add/edit forms.
class AppSaveButton extends StatelessWidget {
  const AppSaveButton({
    super.key,
    required this.saving,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final bool saving;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !saving;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: AppDecorations.pillButton(enabled: active),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.textPrimary,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: AppTextStyles.button.copyWith(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSubtle,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Labeled filled text field matching form screens.
class AppDarkField extends StatelessWidget {
  const AppDarkField({
    super.key,
    required this.controller,
    required this.label,
    required this.placeholder,
    this.maxLines = 1,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final int maxLines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          decoration: AppDecorations.field(hintText: placeholder),
        ),
      ],
    );
  }
}

/// Selectable day / filter chip.
class AppDayChip extends StatelessWidget {
  const AppDayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: AppDecorations.glassChip(selected: selected),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accentSoft : AppColors.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
