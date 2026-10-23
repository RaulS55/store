import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/expense.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snack_bar.dart';
import '../customers/customer_sheets.dart';

Future<Expense?> showExpenseForm(BuildContext context, {Expense? expense}) {
  return showWhiteSheet<Expense>(
    context: context,
    builder: (context) => _ExpenseFormSheet(expense: expense),
  );
}

Future<void> deleteExpenseWithConfirm({
  required BuildContext context,
  required Expense expense,
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Eliminar gasto',
    message: '¿Eliminar ${expense.displayName}?',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<AppStore>().deleteExpense(expense.id);
  } catch (error, stack) {
    debugPrint('Expense delete failed: $error');
    debugPrint('$stack');
    if (!context.mounted) return;
    AppSnackBar.show(context, content: Text('No se pudo eliminar el gasto.'));
    return;
  }
  if (!context.mounted) return;
  AppSnackBar.show(context, content: Text('Gasto eliminado'));
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({this.expense});

  final Expense? expense;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amount = TextEditingController(
      text: expense == null ? '' : MoneyFormat.grouped(expense.amount),
    );
    _note = TextEditingController(text: expense?.note ?? '');
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.expense != null;
    final canSave = MoneyFormat.parse(_amount.text) != null && !_saving;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Editar gasto' : 'Nuevo gasto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Viajes, sueldos y similares. El monto entra en otros gastos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('expense-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyFormat.inputFormatter],
              decoration: const InputDecoration(
                labelText: 'Monto',
                hintText: 'Ej. 50.000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('expense-note'),
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Ej. Viaje o sueldo',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('save-expense'),
              onPressed: canSave ? _save : null,
              child: const Text('Guardar gasto'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = MoneyFormat.parse(_amount.text);
    if (amount == null || amount <= 0 || _saving) return;
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final existing = widget.expense;
    try {
      final now = DateTime.now().toUtc();
      final expense = Expense(
        id: existing?.id ?? store.nextExpenseId(),
        amount: amount,
        note: _note.text.trim(),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: existing?.deletedAt,
      );
      await store.upsertExpense(expense);
      if (!mounted) return;
      Navigator.pop(context, store.expenseById(expense.id) ?? expense);
    } catch (error, stack) {
      debugPrint('Expense save failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.show(context, content: Text('No se pudo guardar el gasto.'));
    }
  }
}
