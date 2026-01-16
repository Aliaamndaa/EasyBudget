import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TransactionPerDayScreen extends StatefulWidget {
  final String email;

  const TransactionPerDayScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<TransactionPerDayScreen> createState() => _TransactionPerDayScreenState();
}

class _TransactionPerDayScreenState extends State<TransactionPerDayScreen> {
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    setState(() => isLoading = true);
    final formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    try {
      final response = await http.get(
        Uri.parse('http://192.168.0.37/get_daily_transactions.php?email=${widget.email}&date=$formattedDate'),
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          transactions = data.map<Map<String, dynamic>>((item) => {
            "category": item["category"],
            "description": item["description"],
            "amount": item["amount"],
            "date": item["date"]
          }).toList();
        });
      } else {
        setState(() => transactions = []);
      }
    } catch (e) {
      setState(() => transactions = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDisplayDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD4AF37),
        title: const Text("Daily Transactions"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Selected Date: $formattedDisplayDate", style: const TextStyle(fontSize: 16)),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: const Text("Change Date", style: TextStyle(color: Color(0xFFD4AF37))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : transactions.isEmpty
                ? const Center(child: Text("No transactions found for this date."))
                : Expanded(
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final item = transactions[index];
                  return ListTile(
                    leading: const Icon(Icons.monetization_on, color: Color(0xFFD4AF37)),
                    title: Text(item["category"] ?? "No category"),
                    subtitle: Text(item["description"] ?? "No description"),
                    trailing: Text("RM${item["amount"]}", style: const TextStyle(color: Color(0xFFD4AF37))),
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
