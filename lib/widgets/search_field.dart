import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.trailing,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fieldController = controller;
    if (fieldController == null) {
      return _field(context, suffix: trailing);
    }
    return ListenableBuilder(
      listenable: fieldController,
      builder: (context, _) {
        return _field(context, suffix: _suffix(fieldController));
      },
    );
  }

  Widget? _suffix(TextEditingController fieldController) {
    if (fieldController.text.isEmpty) return trailing;
    final clear = IconButton(
      key: const ValueKey('search-clear'),
      tooltip: 'Limpiar búsqueda',
      onPressed: () {
        fieldController.clear();
        onChanged('');
      },
      icon: const Icon(Icons.close, size: 18, color: AppColors.mutedText),
    );
    final extra = trailing;
    if (extra == null) return clear;
    return Row(mainAxisSize: MainAxisSize.min, children: [clear, extra]);
  }

  Widget _field(BuildContext context, {required Widget? suffix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.mutedText,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? AppColors.darkElevated : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          borderSide: const BorderSide(color: AppColors.terracotta),
        ),
      ),
    );
  }
}
