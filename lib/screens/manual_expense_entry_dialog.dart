import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ManualExpenseEntryDialog extends StatefulWidget {
  final String userEmail;
  final Function(String category, double amount, String? description)? onExpenseAddedLocally;
  final List<String> categories;

  const ManualExpenseEntryDialog({
    Key? key,
    required this.userEmail,
    this.onExpenseAddedLocally,
    required this.categories,
  }) : super(key: key);

  @override
  State<ManualExpenseEntryDialog> createState() => _ManualExpenseEntryDialogState();
}

class _ManualExpenseEntryDialogState extends State<ManualExpenseEntryDialog> {
  String? _selectedCategory;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate = DateTime.now();

  Future<void> _addTaxClaimToServer() async {
    final String amount = _amountController.text;
    final String? category = _selectedCategory;
    final String description = _descriptionController.text.trim();
    final String date = _selectedDate?.toIso8601String().split('T')[0] ?? '';

    if (category != null && amount.isNotEmpty && date.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('http://10.41.190.149/add_tax_claim.php'),
          body: {
            'email': widget.userEmail,
            'category': category,
            'amount': amount,
            'description': description,
            'claim_date': date,
          },
        );

        if (response.statusCode == 200 && response.body.trim() == "success") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tax claim added successfully.")),
          );
          Navigator.of(context).pop();
          if (widget.onExpenseAddedLocally != null) {
            final double? parsedAmount = double.tryParse(amount);
            if (parsedAmount != null) {
              widget.onExpenseAddedLocally!(category, parsedAmount, description);
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to add tax claim. Status: ${response.statusCode}, Body: ${response.body}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Failed to connect to server.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category, enter the amount, and select a date.")),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Expense Manually'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: _selectedCategory,
              items: widget.categories.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
            ),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (RM)'),
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Claim Date:", style: TextStyle(fontSize: 16)),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: Text(
                    _selectedDate != null
                        ? "${_selectedDate!.toLocal()}".split(' ')[0]
                        : 'Pick a Date',
                    style: const TextStyle(fontSize: 16, color: Color(0xFFD4AF37)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _addTaxClaimToServer,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
