import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'LoginPage.dart';
import 'AddExpenseScreen.dart';
import 'FinancialReportsScreen.dart';
import 'TaxAssistantScreen.dart';
import 'TransactionPerDayScreen.dart';
import 'ManageIncomeScreen.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final String email;

  const HomeScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  bool isLoading = true;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _upcomingBills = [];
  List<Map<String, dynamic>> _spendingInsights = []; // Changed from _spendingInsight (string) to list

  @override
  void initState() {
    super.initState();
    _fetchAllData(); // Call a single method to fetch all initial data
  }

  // New method to fetch all necessary data
  Future<void> _fetchAllData() async {
    setState(() {
      isLoading = true; // Set loading to true while all data is being fetched
    });
    // Use Future.wait to fetch all data concurrently for better performance
    await Future.wait([
      _fetchIncomeAndExpenses(),
      _fetchRecentTransactions(),
      _fetchUpcomingBills(),
      _fetchSpendingInsights(),
    ]);
   // await _checkPendingReminders(); // Call reminders after other fetches are done, and await them
    setState(() {
      isLoading = false; // Set loading to false once all data is fetched
    });
  }


  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email != oldWidget.email) {
      _fetchAllData(); // Re-fetch all data if email changes
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _fetchIncomeAndExpenses() async {
    try {
      final incomeResponse = await http.get(
        Uri.parse('http://192.168.0.24/get_income.php?email=${widget.email}'),
      );
      final expensesResponse = await http.get(
        Uri.parse('http://192.168.0.24/get_expenses.php?email=${widget.email}'),
      );

      if (incomeResponse.statusCode == 200 && expensesResponse.statusCode == 200) {
        try {
          final incomeData = json.decode(incomeResponse.body);
          final newTotalIncome = double.tryParse(incomeData['income'].toString()) ?? 0.0;
          final expensesData = json.decode(expensesResponse.body);
          final newTotalExpenses = double.tryParse(expensesData['expenses'].toString()) ?? 0.0;

          setState(() {
            totalIncome = newTotalIncome;
            totalExpenses = newTotalExpenses;
          });
        } catch (e) {
          print('Error decoding JSON for income/expenses: $e');
        }
      } else {
        print("Fetch failed for income/expenses: Status code ${incomeResponse.statusCode} or ${expensesResponse.statusCode}");
      }
    } catch (e) {
      print("Error fetching income/expenses: $e");
    }
  }

  Future<void> _fetchRecentTransactions() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/get_recent_transactions.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'email=${widget.email}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _recentTransactions = List<Map<String, dynamic>>.from(data);
          });
        } else {
          print('Unexpected data format for recent transactions: $data');
          setState(() {
            _recentTransactions = [];
          });
        }
      } else {
        print('Failed to load recent transactions: ${response.statusCode}');
        setState(() {
          _recentTransactions = [];
        });
      }
    } catch (e) {
      print('Error fetching recent transactions: $e');
      setState(() {
        _recentTransactions = [];
      });
    }
  }

  Future<void> _fetchUpcomingBills() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/get_upcoming_bills.php'),
        body: {'email': widget.email},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String monthKey = DateFormat('yyyy-MM').format(DateTime.now());

          List<Map<String, dynamic>> filtered = [];

          for (var bill in data) {
            String key = 'ack_${widget.email}_${bill['description']}_$monthKey';
            if (!(prefs.getBool(key) ?? false)) {
              filtered.add(Map<String, dynamic>.from(bill));
            }
          }

          setState(() {
            _upcomingBills = filtered;
          });
        }
      } else {
        print('Failed to load upcoming bills: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching bills: $e");
    }
  }

  Future<void> _checkPendingReminders() async {
    try {
      final response = await http.post(
        Uri.parse("http://192.168.0.24/get_pending_reminders.php"),
        body: {'email': widget.email},
      );

      if (response.statusCode == 200) {
        final List<dynamic> reminders = json.decode(response.body);
        final currentMonthAndYear = DateFormat('MMM, yyyy').format(DateTime.now()); // Get current month and year

        for (final reminder in reminders) {
          String reminderDay = 'N/A';
          if (reminder['date'] != null && reminder['date'].isNotEmpty) {
            try {
              DateTime tempDate = DateTime.parse(reminder['date']);
              reminderDay = DateFormat('d').format(tempDate); // Get only the day
            } catch (e) {
              print("Error parsing reminder date day: $e");
            }
          }

          // Format the reminder date to include the current month and the day from the reminder
          String displayedDate = '$currentMonthAndYear, $reminderDay';

          // Ensure dialogs are shown sequentially if multiple reminders
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Upcoming Bill Reminder"),
              content: Text("You have a bill due: ${reminder['description']} on $displayedDate"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      } else {
        print('Failed to load pending reminders: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching reminders: $e");
    }
  }
  Future<void> _handleBillAcknowledgment(Map<String, dynamic> bill, int index) async {
    final TextEditingController amountController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: Color(0xFFD4AF37)),
            SizedBox(width: 10),
            Text("Add Bill to Expenses"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bill['description'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _getFormattedUpcomingDueDate(bill['due_date']),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Bill Amount (RM)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: 'RM ',
                hintText: 'Enter amount',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final amount = amountController.text.trim();
              if (amount.isEmpty || double.tryParse(amount) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid amount")),
                );
                return;
              }
              Navigator.pop(context, {
                'amount': amount,
                'acknowledged': true,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check),
            label: const Text("Add Expense"),
          ),
        ],
      ),
    );

    if (result != null && result['acknowledged'] == true) {
      await _addBillAsExpense(bill, result['amount']!, index);
    }
  }

  Future<void> _addBillAsExpense(Map<String, dynamic> bill, String amount, int index) async {
    try {
      // Determine category based on bill description
      String category = _categorizeBill(bill['description']);

      final response = await http.post(
        Uri.parse('http://192.168.0.24/add_expense.php'),
        body: {
          'email': widget.email,
          'amount': amount,
          'category': category,
          'description': bill['description'],
          'date': DateTime.now().toIso8601String(), // Use current date instead of due date
        },
      );

      if (response.statusCode == 200 && response.body.trim() == "success") {
        // Mark as acknowledged in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String monthKey = DateFormat('yyyy-MM').format(DateTime.now());
        String key = 'ack_${widget.email}_${bill['description']}_$monthKey';
        await prefs.setBool(key, true);

        // Remove from the list
        setState(() {
          _upcomingBills.removeAt(index);
        });

        // Refresh data to update totals and recent transactions
        await _fetchIncomeAndExpenses();
        await _fetchRecentTransactions(); // Add this to refresh the transaction list

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✓ ${bill['description']} added as expense: RM$amount"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to add expense. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error adding bill as expense: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error connecting to server"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _categorizeBill(String description) {
    final lower = description.toLowerCase();

    if (lower.contains('tnb') || lower.contains('electric')) {
      return 'Utilities';
    } else if (lower.contains('syabas') || lower.contains('water')) {
      return 'Utilities';
    } else if (lower.contains('unifi') || lower.contains('internet')) {
      return 'Utilities';
    } else if (lower.contains('astro') || lower.contains('netflix')) {
      return 'Entertainment';
    } else if (lower.contains('maxis') || lower.contains('celcom')) {
      return 'Utilities';
    } else {
      return 'Other';
    }
  }

  Future<void> _fetchSpendingInsights() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/get_spending_insights.php'),
        headers: <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'email=${widget.email}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _spendingInsights = List<Map<String, dynamic>>.from(data);
          });
        } else {
          print('Unexpected data format for spending insights: $data');
          setState(() {
            _spendingInsights = [];
          });
        }
      } else {
        print('Failed to load spending insights with status code: ${response.statusCode}');
        setState(() {
          _spendingInsights = []; // Clear insights on failure
        });
      }
    } catch (e) {
      print('Error fetching spending insights: $e');
      setState(() {
        _spendingInsights = []; // Clear insights on error
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4AF37),
        elevation: 0,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 8),
            Text(
              'EASYBUDGET',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeBody(),
          TaxAssistantScreen(userEmail: widget.email),
          FinancialReportsScreen(email: widget.email),
        ],
      ),
      bottomNavigationBar: ConvexAppBar(
        initialActiveIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFFD4AF37),
        activeColor: Colors.black,
        color: Colors.white,
        style: TabStyle.react,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.receipt_long, title: 'Tax'),
          TabItem(icon: Icons.pie_chart, title: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center, // Center text
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center, // Center text
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String amount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (title == "Total Income" || title == "Total Expenses")
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 30,
                onPressed: () async {
                  if (title == "Total Income") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageIncomeScreen(email: widget.email),
                      ),
                    ).then((_) {
                      // Refresh all data after returning from a child screen
                      _fetchAllData();
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddExpenseScreen(email: widget.email),
                      ),
                    ).then((_) {
                      // Refresh all data after returning from a child screen
                      _fetchAllData();
                    });
                  }
                },
                icon: const Icon(Icons.add_circle, color: Color(0xD2000000)),
              ),
            ),
        ],
      ),
    );
  }

  // Helper function for upcoming bills display
  String _getFormattedUpcomingDueDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'N/A';
    }
    try {
      DateTime dueDate = DateTime.parse(dateString);
      DateTime now = DateTime.now();

      // Get the day from the actual due date
      String day = DateFormat('d').format(dueDate);

      // Get the current month and year
      String currentMonthYear = DateFormat('MMM, yyyy').format(now); // Corrected format for yyyy

      // Combine current month/year with the bill's day
      return "Due: $currentMonthYear, $day";
    } catch (e) {
      print("Error formatting upcoming bill due date: $e");
      return 'N/A';
    }
  }

  Widget _buildHomeBody() {
    final double currentBalance = totalIncome - totalExpenses;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildBalanceCard("Total Balance", "RM${currentBalance.toStringAsFixed(2)}"),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInfoCard("Total Expenses", "RM${totalExpenses.toStringAsFixed(2)}")),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoCard("Total Income", "RM${totalIncome.toStringAsFixed(2)}")),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _recentTransactions.isEmpty
              ? const Text('No recent transactions found.')
              : Column(
            children: _recentTransactions.map((txn) {
              String emoji = '💰';
              String category = (txn['category'] as String?) ?? 'Other';
              DateTime? parsedDate = DateTime.tryParse((txn['date'] as String?) ?? '');
              // Corrected DateFormat pattern for transactions
              String formattedDate = parsedDate != null ? DateFormat('MMM d, yyyy').format(parsedDate) : 'N/A'; // Corrected format for yyyy
              // Ensure amount is formatted to 2 decimal places
              String amount = (txn['amount'] != null ? 'RM${double.parse(txn['amount'].toString()).toStringAsFixed(2)}' : 'RM0.00');
              String type = (txn['type'] as String?) ?? 'Unknown';

              if (category.toLowerCase() == 'food') {
                emoji = '🍔';
              } else if (category.toLowerCase() == 'transport') {
                emoji = '🚇';
              } else if (category.toLowerCase() == 'utilities') {
                emoji = '💡';
              } else if (category.toLowerCase() == 'shopping') {
                emoji = '🛍️';
              } else if (category.toLowerCase() == 'health') {
                emoji = '❤️';
              } else if (category.toLowerCase() == 'entertainment') {
                emoji = '🍿';
              } else if (type == 'income') {
                emoji = '💸';
              }

              return _buildTransactionTile(emoji, category, formattedDate, amount, type);
            }).toList(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TransactionPerDayScreen(email: widget.email)),
                );
              },
              child: const Text('View All', style: TextStyle(color: Color(0xFFD4AF37))),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Upcoming Bills", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _upcomingBills.isEmpty
              ? const Text("No upcoming bills.")
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingBills.length,
            itemBuilder: (context, index) {
              final bill = _upcomingBills[index];
              return Card(
                child: ListTile(
                  title: Text(bill['description'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(_getFormattedUpcomingDueDate(bill['due_date']), style: const TextStyle(fontSize: 14, color: Colors.blueAccent)),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _handleBillAcknowledgment(bill, index),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Okay"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text("Spending Insights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _spendingInsights.isEmpty
              ? const Text("No insights found for last week.") // Updated message
              : Column(
            children: _spendingInsights.map((insight) {
              // Using a default color if primary list is exhausted or for consistency
              final int colorIndex = insight['message'].hashCode % Colors.primaries.length;
              Color cardColor = Colors.primaries[colorIndex].shade100;
              if (insight['icon'] == '⚠️') { // Specific color for warnings
                cardColor = Colors.orange.shade100;
              } else if (insight['icon'] == '🎉' || insight['icon'] == '💰' || insight['icon'] == '✨') { // Specific color for positives
                cardColor = Colors.green.shade100;
              }

              return Card(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Text(insight['icon'] ?? '💡', style: const TextStyle(fontSize: 24)),
                  title: Text(insight['message'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(String emoji, String category, String date, String amount, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(date, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: type == 'income' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
