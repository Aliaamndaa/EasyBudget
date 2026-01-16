import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:smartattendface/main.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  final String email;

  const AddExpenseScreen({Key? key, required this.email}) : super(key: key);

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // Your existing variables
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Utilities',
    'Shopping',
    'Health',
    'Entertainment',
    'Other'


  ];
  // Method to check if expense qualifies for tax deduction
  Map<String, dynamic>? _checkTaxEligibility(String category, String description) {
    final lower = description.toLowerCase();

    // Medical expenses
    if (category.toLowerCase() == 'health' ||
        ['medical', 'clinic', 'klinik', 'hospital', 'pharmacy', 'doctor', 'ubat', 'medicine'].any(lower.contains)) {

      // Check if it's for parents
      if (['parent', 'mother', 'father', 'mom', 'dad', 'ayah', 'ibu'].any(lower.contains)) {
        return {
          'category': 'Medical (Parents)',
          'eligible': true,
          'reason': 'Medical expenses for parents'
        };
      }
      return {
        'category': 'Medical (Self/Family)',
        'eligible': true,
        'reason': 'Medical expenses'
      };
    }

    // Education expenses
    if (['education', 'course', 'tuition', 'university', 'college', 'training', 'certificate', 'diploma', 'degree'].any(lower.contains)) {
      return {
        'category': 'Education (Self)',
        'eligible': true,
        'reason': 'Education/training fees'
      };
    }

    // Lifestyle (books, sports equipment, internet, etc.)
    if (['book', 'journal', 'magazine', 'newspaper', 'sport', 'gym', 'fitness', 'internet subscription',
      'broadband', 'smartphone', 'tablet', 'laptop', 'pc purchase'].any(lower.contains)) {
      return {
        'category': 'Lifestyle',
        'eligible': true,
        'reason': 'Lifestyle expenses (books, sports, internet, devices)'
      };
    }

    // Zakat/Fitrah
    if (['zakat', 'fitrah', 'sedekah', 'donation', 'derma'].any(lower.contains)) {
      return {
        'category': 'Zakat / Fitrah',
        'eligible': true,
        'reason': 'Religious contribution'
      };
    }

    // EPF voluntary contribution
    if (['epf', 'kwsp', 'employee provident'].any(lower.contains)) {
      return {
        'category': 'EPF Contribution',
        'eligible': true,
        'reason': 'EPF voluntary contribution'
      };
    }

    return null; // Not tax eligible
  }

  // Method to automatically add tax claim
  Future<void> _addTaxClaimAutomatically({
    required String amount,
    required String category,
    required String description,
    required DateTime date,
    String? merchantName,
    String? receiptNumber,
    String? paymentMethod,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/add_tax_claim.php'),
        body: {
          'email': widget.email,
          'amount': amount,
          'category': category,
          'description': description,
          'date': DateFormat('yyyy-MM-dd').format(date),
          'receipt_number': receiptNumber ?? '',
          'merchant_name': merchantName ?? '',
          'payment_method': paymentMethod ?? '',
        },
      );

      if (response.statusCode == 200 && response.body.trim() == "success") {
        print("Tax claim added automatically");
      } else {
        print("Failed to add tax claim: ${response.body}");
      }
    } catch (e) {
      print("Error adding tax claim: $e");
    }
  }

  Future<void> _addExpense({
    String? amount,
    String? category,
    String? description,
    DateTime? date,
  }) async {
    final String finalAmount = amount ?? _amountController.text;
    final String finalCategory = category ?? _selectedCategory ?? '';
    final String finalDescription = description ?? _notesController.text;
    final String finalDate = date?.toIso8601String() ?? DateTime.now().toIso8601String();

    if (finalAmount.isNotEmpty && finalCategory.isNotEmpty && finalDescription.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('http://192.168.0.24/add_expense.php'),
          body: {
            'email': widget.email,
            'amount': finalAmount,
            'category': finalCategory,
            'description': finalDescription,
            'date': finalDate,
          },
        );

        if (response.statusCode == 200 && response.body == "success") {
          final knownBills = ['tnb', 'syabas', 'unifi', 'astro', 'maxis', 'celcom', 'internet'];
          final lowerDesc = finalDescription.toLowerCase();
          final matchedBill = knownBills.firstWhere(
                (bill) => lowerDesc.contains(bill),
            orElse: () => '',
          );

          if (matchedBill.isNotEmpty) {
            final estimatedDue = DateTime.parse(finalDate).add(const Duration(days: 30));
            await _showBillReminderPrompt(matchedBill, estimatedDue);
          }

          _showSuccessDialog();

        } else {
          _showSnack("Failed to add expense.");
        }
      } catch (e) {
        _showSnack("Error: Failed to connect.");
      }
    } else {
      _showSnack("Missing data.");
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  Future<void> _showBillReminderPrompt(String billName, DateTime estimatedDueDate) async {
    final formattedDate = "${estimatedDueDate.day}/${estimatedDueDate.month}";

    final shouldSet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detected Bill: ${billName.toUpperCase()}'),
        content: Text('Would you like to set a reminder for this bill on $formattedDate?'),
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: const Text('Yes'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldSet == true) {
      await _scheduleReminder(billName, estimatedDueDate);
      _showSnack("Reminder set for $billName on $formattedDate.");
    }
  }

  Future<void> _scheduleReminder(String billName, DateTime date) async {
    final reminderDate = date.subtract(const Duration(days: 2));
    final id = reminderDate.millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Upcoming Bill: ${billName.toUpperCase()}',
      'Estimated due on ${date.day}/${date.month}. Don’t forget to pay!',
      tz.TZDateTime.from(reminderDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminder_channel',
          'Bill Reminders',
          channelDescription: 'Notifications for bill payments',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      await _processImage(File(pickedFile.path));
    } else {
      _showSnack("No image selected.");
    }
  }

  Future<void> _uploadScreenshot() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await _processImage(File(pickedFile.path));
    } else {
      _showSnack("No image selected.");
    }
  }

  Future<void> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

    final extractedText = recognizedText.text;
    print("Extracted Text:\n$extractedText");

    final amount = _extractAmount(extractedText);
    final predictedCategory = classifyCategory(extractedText);
    final extractedDate = extractDate(extractedText);
    final merchantName = _extractMerchantName(extractedText);
    final receiptNumber = _extractReceiptNumber(extractedText);
    final paymentMethod = _extractPaymentMethod(extractedText);

    final now = DateTime.now();
    final usedDate = extractedDate ?? now;

    if (amount != null) {
      final description = 'Scanned from receipt';
      final category = predictedCategory;

      // Pre-fill the form
      _amountController.text = amount;
      _notesController.text = description;
      _selectedCategory = category;
      _selectedDate = usedDate;

      // ✅ Check if expense is tax eligible
      final taxEligibility = _checkTaxEligibility(category, '$description $merchantName $extractedText');

      // Add expense to database
      await _addExpense(
        amount: amount,
        category: category,
        description: description,
        date: usedDate,
      );

      // ✅ If tax eligible, automatically add to tax claims
      if (taxEligibility != null && taxEligibility['eligible'] == true) {
        await _addTaxClaimAutomatically(
          amount: amount,
          category: taxEligibility['category'],
          description: '${taxEligibility['reason']} - $description',
          date: usedDate,
          merchantName: merchantName,
          receiptNumber: receiptNumber,
          paymentMethod: paymentMethod,
        );

        // Show success dialog with tax info
        _showSuccessDialogWithTax(taxEligibility['category'], taxEligibility['reason']);
      } else {
        // Show normal success dialog
        _showSuccessDialog();
      }
    } else {
      _showSnack("Could not extract amount. Please enter manually.");
    }
  }
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismiss by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: const Text('Expense added successfully from receipt.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.pop(context, true); // Go back to previous screen
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialogWithTax(String taxCategory, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense added successfully!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tax Deduction Detected! 🎉',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Category: $taxCategory',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reason: $reason',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This expense has been automatically added to your Tax Assistant for claim tracking.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context, true);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String? _extractMerchantName(String text) {
    final lines = text.split('\n');
    if (lines.isNotEmpty) {
      return lines.first.trim();
    }
    return null;
  }

  String? _extractReceiptNumber(String text) {
    final regex = RegExp(r'(?:Receipt|Invoice|Ref|No\.?)[\s#:]*([A-Z0-9\-]{5,20})', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1);
  }

  String? _extractPaymentMethod(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('cash')) return 'Cash';
    if (lower.contains('card') || lower.contains('visa') || lower.contains('mastercard')) return 'Credit Card';
    if (lower.contains('e-wallet') || lower.contains('tng') || lower.contains('grabpay')) return 'E-Wallet';
    return null;
  }

  DateTime? extractDate(String text) {
    final datePatterns = [
      RegExp(r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b'),        // Matches 01/06/2024 or 01-06-2024
      RegExp(r'\b(\d{4})[\/\-](\d{2})[\/\-](\d{2})\b'),        // Matches 2024-06-01 or 2024/06/01
      RegExp(r'\b([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})\b'),      // Matches June 1, 2024
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          return DateTime.parse(match.group(0)!.replaceAll('/', '-'));
        } catch (_) {}
      }
    }

    return null;
  }

  // --- REVISED _extractAmount function ---
  String? _extractAmount(String text) {
    final lines = text.split('\n');
    final commonTotalKeywords = [
      'grand total', 'total amount', 'total', 'balance due', 'amount due',
      'payable', 'sum', 'due', 'amount', 'harga', 'jumlah', 'bayar'
    ];
    final subtotalKeywords = ['subtotal', 'sub-total']; // Less definitive
    final paymentKeywords = ['cash', 'tender', 'paid', 'credit', 'debit', 'change']; // Often not the total amount

    // Regex to match monetary values.
    // Handles various formats: RM12.34, 12.34 RM, $12, 12,34 (comma as decimal), 1,234.50 (thousands comma/space).
    // Allows currency symbols (RM, MYR, $, €, £, ¥, Rp) before or after the number.
    final amountRegex = RegExp(
        r'(?:RM|MYR|\$|€|£|¥|Rp)?\s*(\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{1,2})?)(?:\s*(?:RM|MYR|\$|€|£|¥|Rp))?',
        caseSensitive: false);

    String? bestCandidate;
    double highestScore = -1.0; // Use a scoring system for confidence

    // Iterate lines from bottom up for higher relevance
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();

      // Score for this line's best match
      double currentLineBestScore = -1.0;
      String? currentLineBestAmount;

      // Find all potential amounts in the line
      final matches = amountRegex.allMatches(line);

      for (final match in matches) {
        final rawAmount = match.group(1); // The captured number part
        if (rawAmount == null) continue;

        // Clean the amount: remove thousands separators, standardize decimal to dot
        final cleanedAmount = rawAmount.replaceAll(RegExp(r'[,\s]'), '').replaceAll(',', '.');
        final value = double.tryParse(cleanedAmount);

        // Basic filtering for plausible amounts (not too small, not astronomically large)
        if (value == null || value <= 0.01 || value > 1000000.0) {
          continue;
        }

        double score = 0.0;

        // --- Scoring based on context ---

        // 1. Keyword presence (strongest indicator)
        if (commonTotalKeywords.any((keyword) => lowerLine.contains(keyword))) {
          score += 5.0; // High score for direct total keywords
          if (lowerLine.contains('grand total') || lowerLine.contains('amount due')) {
            score += 2.0; // Even higher for very specific total keywords
          }
        }

        // 2. Exclusion keywords (negative scoring)
        if (paymentKeywords.any((keyword) => lowerLine.contains(keyword))) {
          score -= 3.0; // Penalize if it's a payment-related term
        }
        if (subtotalKeywords.any((keyword) => lowerLine.contains(keyword))) {
          score -= 1.0; // Subtotal is usually not the final total
        }
        // Add more exclusion for item quantities, tax rates, etc.
        if (lowerLine.contains('qty') || lowerLine.contains('x') || lowerLine.contains('tax') || lowerLine.contains('gst')) {
          score -= 1.5;
        }

        // 3. Positional weighting (closer to bottom of receipt is better)
        score += (i / lines.length) * 1.0; // Lines further down get a slight boost

        // 4. Value Magnitude (often the largest relevant number)
        // This is tricky as other numbers can be large. Prioritize based on context first.
        // If it's a very large number and no keyword, might be less reliable.
        if (value > 100.0 && !commonTotalKeywords.any((keyword) => lowerLine.contains(keyword))) {
          // Heuristic: if it's a large value *without* a strong keyword, reduce its score slightly.
          // This tries to avoid picking up large item prices as the total.
          score -= 0.5;
        }


        // Update best match for this line
        if (score > currentLineBestScore) {
          currentLineBestScore = score;
          currentLineBestAmount = cleanedAmount;
        }
      }

      // If this line has a good candidate, compare it with the overall best
      if (currentLineBestAmount != null && currentLineBestScore > highestScore) {
        highestScore = currentLineBestScore;
        bestCandidate = currentLineBestAmount;
      }
    }

    print('DEBUG: Extracted amount: $bestCandidate with score: $highestScore');

    // Fallback: If no strong candidate was found, try the largest number from the whole text
    // as a last resort, but only if its plausible (e.g. not a date or phone number)
    if (bestCandidate == null) {
      double overallLargestAmount = 0.0;
      String? overallLargestCandidate;

      final allMatches = amountRegex.allMatches(text);
      for (final match in allMatches) {
        final rawAmount = match.group(1);
        if (rawAmount == null) continue;

        final cleanedAmount = rawAmount.replaceAll(RegExp(r'[,\s]'), '').replaceAll(',', '.');
        final value = double.tryParse(cleanedAmount);

        if (value != null && value > 0.01 && value < 1000000.0) {
          // Check if this number is likely an item quantity or similar
          final lineContainingMatch = lines.firstWhere((l) => l.contains(match.group(0)!), orElse: () => '');
          final lowerLineContainingMatch = lineContainingMatch.toLowerCase();

          if (!paymentKeywords.any((kw) => lowerLineContainingMatch.contains(kw)) &&
              !subtotalKeywords.any((kw) => lowerLineContainingMatch.contains(kw)) &&
              !lowerLineContainingMatch.contains('qty') &&
              !lowerLineContainingMatch.contains('x') &&
              !lowerLineContainingMatch.contains('tax') &&
              !lowerLineContainingMatch.contains('gst') &&
              !lowerLineContainingMatch.contains('phone') &&
              !lowerLineContainingMatch.contains('date')) {

            if (value > overallLargestAmount) {
              overallLargestAmount = value;
              overallLargestCandidate = cleanedAmount;
            }
          }
        }
      }
      if (overallLargestCandidate != null) {
        print('DEBUG: Falling back to overall largest plausible amount: $overallLargestCandidate');
        return overallLargestCandidate;
      }
    }

    return bestCandidate;
  }

  String classifyCategory(String text) {
    final lower = text.toLowerCase();
    if (['kfc', 'mcd', 'restaurant', 'food', 'coffee', 'cafe', 'starbucks', 'burger', 'dome', 'pizza', 'sushi', 'dine', 'eat', 'FamilyMart', 'OLDTOWN WHITE COFFE'].any(lower.contains)) return 'Food';
    if (['grab', 'uber', 'petrol', 'fuel', 'shell', 'petronas', 'rapidkl', 'touch n go', 'tng'].any(lower.contains)) return 'Transport';
    if (['tnb', 'electric', 'water', 'syabas', 'unifi', 'astro', 'maxis', 'celcom', 'digi', 'yes'].any(lower.contains)) return 'Utilities';
    if (['clinic', 'klinik', 'hospital', 'pharmacy', 'medicine', 'watsons', 'guardian', 'ubat', 'health', 'rawatan'].any(lower.contains)) return 'Health';
    if (['tesco', 'aeon', 'giant', 'mydin', 'zara', 'uniqlo', 'shopping', 'mall', 'mr diy', 'guardian', '7eleven', 'mini market'].any(lower.contains)) return 'Shopping';
    if (['netflix', 'spotify', 'cinema', 'entertainment', 'movie', 'show', 'event', 'GSC', 'TGV'].any(lower.contains)) return 'Entertainment';
    return 'Other';
  }


  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Expenses"),
        backgroundColor: const Color(0xFFD4AF37),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _scanReceipt,
                        icon: const Icon(Icons.camera_alt),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        label: const Text("Scan Receipt"),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _uploadScreenshot,
                        icon: const Icon(Icons.image),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        label: const Text("Upload Screenshot"),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text("Amount (RM):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter amount',
                ),
              ),
              const SizedBox(height: 20),
              const Text("Category:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select category',
                ),
                value: _selectedCategory,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 20),
              const Text("Description:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter description',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Select Date:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  TextButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFFD4AF37)),
                    label: Text(
                      _selectedDate != null
                          ? "${_selectedDate!.toLocal()}".split(' ')[0]
                          : 'Pick a Date',
                      style: const TextStyle(fontSize: 16, color: Color(0xFFD4AF37)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () => _addExpense(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                  ),
                  child: const Text(
                    "Add Expense",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
