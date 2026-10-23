import 'dart:async';

import 'package:store_app/data/expense_access.dart';
import 'package:store_app/models/expense.dart';

class FakeExpenseAccess implements ExpenseAccess {
  final expenses = <String, Map<String, Expense>>{};
  final _controllers = <String, StreamController<List<Expense>>>{};
  var _seq = 0;

  String _id() => 'e-fake-${++_seq}';

  StreamController<List<Expense>> _controller(String companyId) {
    return _controllers.putIfAbsent(
      companyId,
      StreamController<List<Expense>>.broadcast,
    );
  }

  List<Expense> _list(String companyId) {
    final list = [...?expenses[companyId]?.values];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  String nextExpenseId(String companyId) => _id();

  @override
  Stream<List<Expense>> watchExpenses(String companyId) async* {
    yield _list(companyId);
    yield* _controller(companyId).stream;
  }

  @override
  Future<void> saveExpense(String companyId, Expense expense) async {
    expenses.putIfAbsent(companyId, () => {})[expense.id] = expense;
    _controller(companyId).add(_list(companyId));
  }
}
