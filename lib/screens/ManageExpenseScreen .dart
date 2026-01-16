import 'package:flutter/material.dart';
import 'AddExpenseScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageExpenseScreen extends StatefulWidget {
  final String email;

  const ManageExpenseScreen({Key? key, required this.email}) : super(key: key);

  @override
  _ManageExpenseScreenState createState() => _ManageExpenseScreenState();
}

class _ManageExpenseScreenState extends State<ManageExpenseScreen> {
  List<dynamic> _expenses = [];

  @override
  void initState() {
    super.initState();
    fetchExpenses();
  }

  Future<void> fetchExpenses() async {
    final response = await http.post(
      Uri.parse('http://192.168.0.24/get_expenses.php'),
      body: {'email': widget.email},
    );

    if (response.statusCode == 200) {
      setState(() {
        _expenses = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load expenses');
    }
  }

  Future<void> deleteExpense(String id) async {
    final response = await http.post(
      Uri.parse('http://192.168.0.24/delete_expense.php'),
      body: {'id': id},
    );

    if (response.statusCode == 200) {
      fetchExpenses(); // Refresh after delete
    } else {
      throw Exception('Failed to delete expense');
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              deleteExpense(id);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Expenses'),
      ),
      body: ListView.builder(
        itemCount: _expenses.length,
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text(expense['description']),
              subtitle: Text('Amount: RM${expense['amount']} • Category: ${expense['category']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddExpenseScreen(
                            email: widget.email,
                           // isEditing: true,
                           // expenseData: expense,
                          ),
                        ),
                      ).then((_) => fetchExpenses());
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(expense['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                email: widget.email,
               // isEditing: false,
              ),
            ),
          ).then((_) => fetchExpenses());
        },
        child: Icon(Icons.add),
        tooltip: 'Add Expense',
      ),
    );
  }
}
