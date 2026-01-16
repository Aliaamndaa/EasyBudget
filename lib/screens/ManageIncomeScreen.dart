// ManageIncomeScreen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManageIncomeScreen extends StatefulWidget {
  final String email;
  const ManageIncomeScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<ManageIncomeScreen> createState() => _ManageIncomeScreenState();
}

class _ManageIncomeScreenState extends State<ManageIncomeScreen> {
  static const _gold = Color(0xFFD4AF37);

  double _totalIncome = 0.0;
  bool _loadingTotal = true;

  bool _showList = false;
  bool _loadingList = false;
  List<Map<String, dynamic>> _incomes = [];

  @override
  void initState() {
    super.initState();
    _fetchTotalIncome();
  }

  Future<void> _fetchTotalIncome() async {
    setState(() => _loadingTotal = true);
    try {
      final res = await http.get(
          Uri.parse('http://192.168.0.24/get_income.php?email=${widget.email}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _totalIncome = double.tryParse(data['income'].toString()) ?? 0.0;
          _loadingTotal = false;
        });
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Total income error: $e');
      setState(() => _loadingTotal = false);
    }
  }

  Future<void> _fetchIncomeList() async {
    setState(() => _loadingList = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.0.24/get_income_list.php'),
        body: {'email': widget.email},
      );
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        setState(() {
          _incomes = List<Map<String, dynamic>>.from(decoded);
          _loadingList = false;
        });
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Income list error: $e');
      setState(() => _loadingList = false);
    }
  }

  Future<bool> _showConfirmationDialog(String message) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes'),
          ),
        ],
      ),
    )) ??
        false;
  }

  Future<void> _addOrEditIncome({Map<String, dynamic>? income}) async {
    final controller = TextEditingController(
        text: income != null ? income['amount'].toString() : '');
    DateTime selectedDateLocal =
    income != null ? DateTime.parse(income['date']) : DateTime.now();

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                income == null ? 'Add New Income' : 'Edit Income',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money),
                  labelText: 'Amount (RM)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDateLocal)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDateLocal,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedDateLocal = picked);
                      Navigator.pop(context); // Close and reopen to refresh UI
                      await _addOrEditIncome(income: income);
                    }
                  },
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: Icon(income == null ? Icons.add : Icons.save, color: Colors.black),
                label: Text(
                  income == null ? 'Add Income' : 'Update Income',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final input = controller.text.trim();
                  final amount = double.tryParse(input);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid positive amount.')),
                    );
                    return;
                  }

                  final confirmed = await _showConfirmationDialog(
                      income == null
                          ? 'Are you sure you want to add this income?'
                          : 'Are you sure you want to update this income?');

                  if (!confirmed) return;

                  final url = income == null
                      ? 'http://192.168.0.24/add_income.php'
                      : 'http://192.168.0.24/update_income.php';

                  final response = await http.post(Uri.parse(url), body: {
                    'email': widget.email,
                    'amount': amount.toString(),
                    'date': DateFormat('yyyy-MM-dd').format(selectedDateLocal),
                    if (income != null) 'id': income['id'].toString(),
                  });

                  if (response.statusCode == 200 && response.body.trim() == 'success') {
                    Navigator.pop(context);
                    await _fetchTotalIncome();
                    if (_showList) await _fetchIncomeList();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${response.body.trim()}')),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed =
    await _showConfirmationDialog('Are you sure you want to delete this income entry?');

    if (confirmed) {
      final res = await http.post(
        Uri.parse('http://192.168.0.24/delete_income.php'),
        body: {'id': id.toString(), 'email': widget.email},
      );
      if (res.statusCode == 200 && res.body.trim() == 'success') {
        await _fetchTotalIncome();
        await _fetchIncomeList();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: ${res.body}')));
      }
    }
  }

  Widget _buildTotalIncomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.15),
        border: Border.all(color: _gold, width: 1.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: _loadingTotal
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Total Income',
              style:
              TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('RM ${_totalIncome.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return OutlinedButton.icon(
      icon:
      Icon(_showList ? Icons.expand_less : Icons.expand_more, color: _gold),
      label: Text(_showList ? 'Hide Income List' : 'View Income List',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
          foregroundColor: _gold,
          side: const BorderSide(color: _gold),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
      onPressed: () async {
        setState(() => _showList = !_showList);
        if (_showList && _incomes.isEmpty) await _fetchIncomeList();
      },
    );
  }

  Widget _buildIncomeCard(Map<String, dynamic> inc) {
    final amount = inc['amount'];
    final date = DateFormat('yyyy-MM-dd').format(DateTime.parse(inc['date']));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text('RM $amount',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              onPressed: () => _addOrEditIncome(income: inc),
              icon: const Icon(Icons.edit, color: Colors.green),
            ),
            IconButton(
              onPressed: () => _confirmDelete(inc['id']),
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _gold,
        title: const Text('Manage Income',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _gold,
        onPressed: () => _addOrEditIncome(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTotalIncomeCard(),
            const SizedBox(height: 20),
            _buildToggleButton(),
            if (_showList) const SizedBox(height: 16),
            if (_showList)
              _loadingList
                  ? const Center(
                  child: CircularProgressIndicator(color: _gold))
                  : _incomes.isEmpty
                  ? const Text('No income records found.')
                  : ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _incomes.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
                itemBuilder: (ctx, i) =>
                    _buildIncomeCard(_incomes[i]),
              ),
          ],
        ),
      ),
    );
  }
}
