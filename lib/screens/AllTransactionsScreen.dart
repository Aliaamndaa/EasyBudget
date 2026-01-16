import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // for date formatting

class AllTransactionsScreen extends StatefulWidget {
  final String email;

  const AllTransactionsScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool isLoading = true;

  Future<void> _fetchAllTransactions() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/get_all_transactions.php'),
        body: {'email': widget.email},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        print('Failed to load all transactions');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching all transactions: $e');
      setState(() => isLoading = false);
    }
  }

  String getEmojiForCategory(String category, String type) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚇';
      case 'utilities':
        return '💡';
      case 'shopping':
        return '🛍️';
      case 'health':
        return '❤️';
      case 'entertainment':
        return '🍿';
      default:
        return type.toLowerCase() == 'income' ? '💸' : '💰';
    }
  }

  String formatDate(String rawDate) {
    try {
      final date = DateTime.parse(rawDate);
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return rawDate;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAllTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
          ? const Center(child: Text('No transactions found.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final txn = _transactions[index];
          final category = txn['category'] ?? 'Other';
          final type = txn['type'] ?? 'expense';
          final emoji = getEmojiForCategory(category, type);
          final date = formatDate(txn['date'] ?? '');
          final amount = txn['amount'] ?? '0.00';
          final title = txn['title'] ?? category;
          final amountColor = type == 'income' ? Colors.green : Colors.red;

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                date,
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Text(
                'RM$amount',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
