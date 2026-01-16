import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class TransactionPerDayScreen extends StatefulWidget {
  final String email;

  const TransactionPerDayScreen({Key? key, required this.email})
      : super(key: key);

  @override
  _TransactionPerDayScreenState createState() =>
      _TransactionPerDayScreenState();
}

class _TransactionPerDayScreenState extends State<TransactionPerDayScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;

  Future<void> _fetchTransactionsByDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _transactions = [];
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/get_transactions_by_date.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'email=${widget.email}&date=$formattedDate',
      );
      if (response.statusCode == 200) {
        try {
          final List<dynamic> data = json.decode(response.body);
          setState(() {
            _transactions = List<Map<String, dynamic>>.from(data);
          });
        } catch (e) {
          print('Error decoding JSON: $e');
        }
      } else {
        print('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching transactions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchTransactionsByDate(_selectedDate);
    }
  }

  String getEmojiForCategory(String category, String type) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚗';
      case 'utilities':
        return '💡';
      case 'grocery':
        return '🛒';
      case 'shopping':
        return '🛍️';
      case 'health':
        return '💊';
      case 'entertainment':
        return '🎬';
      case 'salary':
        return '💼';
      default:
        return type.toLowerCase() == 'income' ? '💸' : '💰';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTransactionsByDate(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions Per Day', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFD4AF37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showDatePicker,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Pick Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : _transactions.isEmpty
                ? const Expanded(
              child: Center(
                child: Text('No transactions found for this day.',
                    style: TextStyle(fontSize: 16)),
              ),
            )
                : Expanded(
              child: ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final txn = _transactions[index];
                  final category = txn['category'] ?? 'Other';
                  final date = txn['date'] ?? '';
                  final amount = txn['amount']?.toString() ?? '0.00';
                  final type = txn['type'] ?? 'expense';
                  final emoji = getEmojiForCategory(category, type);

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      title: Text(
                        category,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(date, style: const TextStyle(color: Colors.grey)),
                      trailing: Text(
                        'RM$amount',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: type == 'income' ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
