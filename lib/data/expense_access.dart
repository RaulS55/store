import '../models/expense.dart';

abstract class ExpenseAccess {
  String nextExpenseId(String companyId);

  Stream<List<Expense>> watchExpenses(String companyId);

  Future<void> saveExpense(String companyId, Expense expense);
}
