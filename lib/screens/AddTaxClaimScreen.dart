import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class AddTaxClaimScreen extends StatefulWidget {
  final String userEmail;

  const AddTaxClaimScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<AddTaxClaimScreen> createState() => _AddTaxClaimScreenState();
}

class _AddTaxClaimScreenState extends State<AddTaxClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'Medical Expenses';
  File? _receiptImage;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Medical Expenses',
    'Lifestyle',
    'Education Fees',
    'Childcare Fees',
    'Other',
  ];

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _receiptImage = File(picked.path);
      });
    }
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _receiptImage = File(picked.path);
      });
      // Simulate OCR and autofill
      _amountController.text = '123.45'; // Simulated OCR
      _descriptionController.text = 'Scanned Receipt'; // Simulated OCR
    }
  }

  Future<void> _submitTaxClaim() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      var uri = Uri.parse('http://192.168.0.24/add_tax_claim.php');
      var request = http.MultipartRequest('POST', uri);

      request.fields['email'] = widget.userEmail;
      request.fields['amount'] = _amountController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['category'] = _selectedCategory;
      request.fields['date'] = DateTime.now().toIso8601String();
      request.fields['claim_id'] = const Uuid().v4();

      if (_receiptImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'receipt',
          _receiptImage!.path,
        ));
      }

      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax claim submitted successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed. Status: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error submitting tax claim.')),
      );
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Tax Claim'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (RM)'),
                keyboardType: TextInputType.number,
                validator: (value) =>
                value == null || value.isEmpty ? 'Please enter an amount' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              if (_receiptImage != null)
                Image.file(_receiptImage!, height: 150),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _scanReceipt,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan Receipt"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTaxClaim,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Tax Claim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
