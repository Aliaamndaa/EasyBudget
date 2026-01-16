import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

// Model for Tax Categories
class TaxCategory {
  final String name;
  final int? limit; // Null for unlimited claims like Zakat

  TaxCategory({required this.name, this.limit});
}

class TaxAssistantScreen extends StatefulWidget {
  final String userEmail;

  const TaxAssistantScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<TaxAssistantScreen> createState() => _TaxAssistantScreenState();
}

class _TaxAssistantScreenState extends State<TaxAssistantScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _receiptNumberController = TextEditingController();
  final TextEditingController _merchantNameController = TextEditingController();
  final TextEditingController _beneficiaryController = TextEditingController(); // Assuming this will be added to DB later
  DateTime? _selectedDate;
  String? _selectedCategory; // Used for the main screen category selection
  String? _selectedPaymentMethod;

  List<Map<String, dynamic>> _trackedClaims = [];
  bool _isLoading = true;

  // Define the most-used tax relief categories
  final List<TaxCategory> _mustHaveCategories = [
    TaxCategory(name: 'EPF Contribution', limit: 4000),
    TaxCategory(name: 'SOCSO / EIS', limit: 350),
    TaxCategory(name: 'Medical (Self/Family)', limit: 8000),
    TaxCategory(name: 'Medical (Parents)', limit: 8000),
    TaxCategory(name: 'Education (Self)', limit: 7000),
    TaxCategory(name: 'Lifestyle', limit: 2500),
    TaxCategory(name: 'Zakat / Fitrah', limit: null), // Unlimited
  ];

  // List of payment methods
  final List<String> _paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'Bank Transfer',
    'E-Wallet',
    'Cheque',
    'Other',
  ];
  List<TaxCategory> _availableCategories = [];
  Map<String, double> _categoryClaimTotals = {}; // To store aggregated totals

  @override
  void initState() {
    super.initState();
    _availableCategories = List.from(_mustHaveCategories);
    _fetchTaxClaims();
    _fetchTrackedClaims();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _receiptNumberController.dispose();
    _merchantNameController.dispose();
    _beneficiaryController.dispose();
    super.dispose();
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _availableCategories = List.from(_mustHaveCategories);
      } else {
        _availableCategories = _mustHaveCategories
            .where((category) => category.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }
  // Method to calculate total claimed amounts for each category
  Map<String, double> _calculateCategoryClaimTotals() {
    Map<String, double> totals = {};
    // Initialize all categories to 0
    for (var category in _mustHaveCategories) {
      totals[category.name] = 0.0;
    }

    // Aggregate claims from _trackedClaims
    for (var claim in _trackedClaims) {
      String categoryName = claim['category'];
      double amount = double.tryParse(claim['amount'] ?? '0.0') ?? 0.0;
      totals[categoryName] = (totals[categoryName] ?? 0.0) + amount;
    }
    return totals;
  }

  // Helper to get a TaxCategory object by its name
  TaxCategory? _getCategoryByName(String name) {
    try {
      return (_mustHaveCategories).firstWhere((cat) => cat.name == name);
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchTaxClaims() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final now = DateTime.now();
      final String currentDateFormatted = DateFormat('yyyy-MM-dd').format(now);
      final response = await http.get(
        Uri.parse('http://192.168.0.24/get_tax_claims.php?email=${widget.userEmail}&date=$currentDateFormatted'),
      );
      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        if (decodedData is List) {
          setState(() {
            _trackedClaims = List<Map<String, dynamic>>.from(decodedData);
            _categoryClaimTotals = _calculateCategoryClaimTotals();
          });
        } else if (decodedData is Map && decodedData.containsKey('error')) {
          _showSnack('Server Error: ${decodedData['error']}');
          setState(() {
            _trackedClaims = [];
            _categoryClaimTotals = _calculateCategoryClaimTotals();
          });
        } else {
          _showSnack('Unexpected response format from server.');
          setState(() {
            _trackedClaims = [];
            _categoryClaimTotals = _calculateCategoryClaimTotals();
          });
        }
      } else {
        _showSnack('Failed to load tax claims. Status: ${response.statusCode}');
        setState(() {
          _trackedClaims = [];
          _categoryClaimTotals = _calculateCategoryClaimTotals();
        });
      }
    } catch (e) {
      _showSnack('Error fetching tax claims: $e');
      setState(() {
        _trackedClaims = [];
        _categoryClaimTotals = _calculateCategoryClaimTotals();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addTaxClaimToServer({
    required String amount,
    required String category,
    String? description,
    required DateTime date,
    String? receiptNumber,
    String? merchantName,
    String? paymentMethod,

  }) async {
    if (amount.isEmpty || category.isEmpty || date == null) {
      _showSnack('Please fill in all required fields.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/add_tax_claim.php'),
        body: {
          'email': widget.userEmail,
          'amount': amount,
          'category': category,
          'description': description ?? '',
          'date': DateFormat('yyyy-MM-dd').format(date),
          'receipt_number': receiptNumber ?? '',
          'merchant_name': merchantName ?? '',
          'payment_method': paymentMethod ?? '',
          // Removed beneficiary from body if not in DB
          // 'beneficiary': beneficiary ?? '',
        },
      );
      if (response.statusCode == 200 && response.body.trim() == "success") {
        _showSuccessDialog();
        await _fetchTaxClaims(); // Refresh list and totals
        _clearForm();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

      } else {
        _showSnack("Failed to add tax claim: ${response.body}");
      }
    } catch (e) {
      _showSnack("Error adding tax claim: $e");
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
          content: const Text('Tax added successfully from receipt.'),
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
  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _clearForm() {
    _amountController.clear();
    _descriptionController.clear();
    _receiptNumberController.clear();
    _merchantNameController.clear();
    _beneficiaryController.clear();
    setState(() {
      _selectedDate = null;
      _selectedCategory = null;
      _selectedPaymentMethod = null;
    });
  }
  Future<void> _updateTaxClaim(String claimId) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/update_tax_claim.php'),
        body: {
          'claim_id': claimId,
          'amount': _amountController.text,
          'category': _selectedCategory ?? '',
          'description': _descriptionController.text,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'receipt_number': _receiptNumberController.text,
          'merchant_name': _merchantNameController.text,
          'payment_method': _selectedPaymentMethod ?? '',
        },
      );
      if (response.statusCode == 200 && response.body.trim() == "success") {
        _showSnack("Claim updated.");
        await _fetchTaxClaims();
        Navigator.pop(context);
      } else {
        _showSnack("Failed to update claim.");
      }
    } catch (e) {
      _showSnack("Error: $e");
    }
  }

  Future<void> _deleteTaxClaim(String claimId) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.0.24/delete_tax_claim.php'),
        body: {'claim_id': claimId},
      );
      if (response.statusCode == 200 && response.body.trim() == "success") {
        _showSnack("Claim deleted.");
        await _fetchTaxClaims();
      } else {
        _showSnack("Failed to delete claim.");
      }
    } catch (e) {
      _showSnack("Error: $e");
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _scanReceiptForTaxClaim() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      await _processImageForTaxClaim(File(pickedFile.path));
    } else {
      _showSnack("No image selected.");
    }
  }

  Future<void> _uploadScreenshotForTaxClaim() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _processImageForTaxClaim(File(pickedFile.path));
    } else {
      _showSnack("No image selected.");
    }
  }

  Future<void> _processImageForTaxClaim(File imageFile) async {
    _showSnack("Processing image...");
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    final extractedText = recognizedText.text;

    print("Extracted Text:\n$extractedText");

    final String? amount = _extractAmountFromText(extractedText);
    final String? potentialCategory = _identifyTaxCategoryFromText(extractedText);
    final DateTime? recognizedDate = _extractDateFromText(extractedText);
    final String? recognizedReceiptNumber = _extractReceiptNumberFromText(extractedText);
    final String? recognizedMerchantName = _extractMerchantNameFromText(extractedText);
    final String? recognizedPaymentMethod = _extractPaymentMethodFromText(extractedText);
    final String? recognizedDescription = _extractDescriptionFromText(extractedText);
    final String? recognizedBeneficiary = _extractBeneficiaryFromText(extractedText);

    // Determine if this image came from gallery or camera for clearer user feedback
    bool isFromCamera = imageFile.path.contains("camera") || imageFile.path.contains("CAP");

    if (amount != null && potentialCategory != null && recognizedDate != null) {
      await _addTaxClaimToServer(
        amount: amount,
        category: potentialCategory,
        description: recognizedDescription ?? (isFromCamera ? "Scanned from receipt" : "Uploaded screenshot"),
        date: recognizedDate,
        receiptNumber: recognizedReceiptNumber ?? '',
        merchantName: recognizedMerchantName ?? '',
        paymentMethod: recognizedPaymentMethod ?? '',
      );

      _showSuccessDialogTax(
          "Success",
          isFromCamera
              ? "Your tax claim has been added from receipt."
              : "Your tax claim has been added from receipt."
      );
    } else {
      _showSnack("Could not fully extract details. Please review and fill manually.");
      _showAddClaimForm(
        initialAmount: amount,
        initialCategory: potentialCategory,
        initialDescription: recognizedDescription,
        initialDate: recognizedDate,
        initialReceiptNumber: recognizedReceiptNumber,
        initialMerchantName: recognizedMerchantName,
        initialPaymentMethod: recognizedPaymentMethod,
        initialBeneficiary: recognizedBeneficiary,
        isAutoFilled: true,
      );
    }

    await textRecognizer.close();
  }
  void _showSuccessDialogTax(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }


  String? _extractDescriptionFromText(String text) {
    final descKeywords = ['consultation', 'treatment', 'service', 'education', 'zakat', 'fees', 'payment'];
    final lines = text.split('\n');
    for (String line in lines) {
      if (descKeywords.any((word) => line.toLowerCase().contains(word))) {
        return line.trim();
      }
    }
    return null;
  }


  String? _identifyTaxCategoryFromText(String text) {
    text = text.toLowerCase();
    if (text.contains('epf') || text.contains('kwsp') || text.contains('employee provident fund')) {
      return 'EPF Contribution';
    } else if (text.contains('socso') || text.contains('eis') || text.contains('perkeso')) {
      return 'SOCSO / EIS';
    } else if (text.contains('medical') || text.contains('clinic') || text.contains('hospital') || text.contains('ubat') || text.contains('doctor') || text.contains('pharmacy')) {
      if (text.contains('parent') || text.contains('mother') || text.contains('father')) {
        return 'Medical (Parents)';
      }
      return 'Medical (Self/Family)';
    } else if (text.contains('zakat') || text.contains('fitrah') || text.contains('donation') && text.contains('islamic')) {
      return 'Zakat / Fitrah';
    } else if (text.contains('education') || text.contains('universiti') || text.contains('college') || text.contains('school fees') || text.contains('course fees')) {
      return 'Education (Self)';
    } else if (text.contains('lifestyle') || text.contains('sukan') || text.contains('sport equipment') || text.contains('internet subscription') || text.contains('books') || text.contains('journals') || text.contains('newspaper') || text.contains('pc') || text.contains('tablet') || text.contains('smartphone') || text.contains('fitness')) {
      if (text.contains('books') || text.contains('journal')) return 'Books/Journals';
      if (text.contains('sport') || text.contains('gym')) return 'Sport Equipment';
      return 'Lifestyle';
    } else if (text.contains('childcare') || text.contains('nursery') || text.contains('kindergarten')) {
      return 'Childcare Fees';
    } else if (text.contains('sspn')) {
      return 'Perlis Education Savings';
    } else if (text.contains('life insurance')) {
      return 'Life Insurance';
    } else if (text.contains('prs') || text.contains('private retirement scheme')) {
      return 'Individual Retirement Scheme (PRS)';
    } else if (text.contains('private school fees')) {
      return 'Private School Fees';
    } else if (text.contains('disability') || text.contains('oku')) {
      if (text.contains('parent')) return 'Parent with Disability';
      return 'Disability (Self)';
    } else if (text.contains('medical check-up')) {
      return 'Medical Check-up';
    } else if (text.contains('serious disease') || text.contains('critical illness') || text.contains('expensive treatment')) {
      return 'Medical / Treatment for Serious Diseases';
    } else if (text.contains('child support')) {
      return 'Child Support';
    }
    return null;
  }

  DateTime? _extractDateFromText(String text) {
    final dateRegexes = [
      RegExp(r'\b(\d{4}-\d{2}-\d{2})\b'), //YYYY-MM-DD
      RegExp(r'\b(\d{1,2}/\d{1,2}/\d{2,4})\b'), // DD/MM/YYYY or MM/DD/YYYY
      RegExp(r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})\b', caseSensitive: false), // DD MonYYYY
      RegExp(r'\b((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},\s+\d{4})\b', caseSensitive: false), // Mon DD, YYYY
    ];
    for (var regex in dateRegexes) {
      final match = regex.firstMatch(text);
      if (match != null) {
        String dateString = match.group(0)!;
        try {
          if (dateRegexes[0].hasMatch(dateString)) {
            return DateTime.parse(dateString);
          } else if (dateRegexes[1].hasMatch(dateString)) {
            final parts = dateString.split('/');
            if (parts.length == 3) {
              int day = int.parse(parts[0]);
              int month = int.parse(parts[1]);
              int year = parts[2].length == 2 ? 2000 + int.parse(parts[2]) : int.parse(parts[2]);
              if (day > 12) { // Assuming DD/MM/YYYY if day is > 12
                return DateTime(year, month, day);
              } else { // Try both DD/MM/YYYY and MM/DD/YYYY if day <= 12
                try { return DateTime(year, month, day); } catch (_) {}
                try { return DateTime(year, day, month); } catch (_) {}
              }
            }
          } else if (dateRegexes[2].hasMatch(dateString)) {
            return DateFormat('dd MMM yyyy', 'en_US').parse(dateString);
          } else if (dateRegexes[3].hasMatch(dateString)) {
            return DateFormat('MMM dd, yyyy', 'en_US').parse(dateString);
          }
        } catch (e) {
          print("Date parsing error for '$dateString': $e");
        }
      }
    }
    return DateTime.now(); // Fallback to current date
  }

  String? _extractReceiptNumberFromText(String text) {
    final regexes = [
      RegExp(r'(?:Receipt|Invoice|Ref|No\.?|Bill)[\s#:]*([A-Z0-9\-]{5,20})', caseSensitive: false),
      RegExp(r'\b([A-Z]{1,3}\d{5,10})\b'), // fallback
    ];

    for (var regex in regexes) {
      final match = regex.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }



  String? _extractMerchantNameFromText(String text) {
    final lines = text.split('\n');
    List<String> potentialNames = [];
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?$').hasMatch(line) ||
          RegExp(r'^\d+(\.\d{2})?$').hasMatch(line) ||
          RegExp(r'^(?:Tel|Phone|Fax|Email|Website|No|Tax|GST|SSM|Co\. Reg\.)[:\s]*', caseSensitive: false).hasMatch(line) ||
          line.toLowerCase().contains('total') ||
          line.toLowerCase().contains('subtotal') ||
          line.toLowerCase().contains('cashier') ||
          line.toLowerCase().contains('thank you') ||
          line.toLowerCase().contains('receipt') ||
          line.toLowerCase().contains('invoice') ||
          line.toLowerCase().contains('transaction') ||
          line.toLowerCase().contains('amount due') ||
          line.toLowerCase().contains('balance')) {
        continue;
      }
      if (line.length > 3 && RegExp(r'^[A-Za-z\s.,&()-]+$').hasMatch(line)) {
        potentialNames.add(line);
      }
    }

    if (potentialNames.isNotEmpty) {
      for (var name in potentialNames) {
        if (!name.contains(RegExp(r'\d{5}')) && !name.contains(RegExp(r'(street|road|jalan|lorong|taman|square|city)', caseSensitive: false))) {
          return name;
        }
      }
      return potentialNames.first;
    }
    return null;
  }

  String? _extractPaymentMethodFromText(String text) {
    text = text.toLowerCase();
    if (text.contains('cash')) return 'Cash';
    if (text.contains('credit card') || text.contains('visa') || text.contains('mastercard') || text.contains('card')) return 'Credit Card';
    if (text.contains('debit card')) return 'Debit Card';
    if (text.contains('bank transfer') || text.contains('online transfer') || text.contains('ibg')) return 'Bank Transfer';
    if (text.contains('e-wallet') || text.contains('tng') || text.contains('grabpay') || text.contains('boost') || text.contains('shopeepay')) return 'E-Wallet';
    if (text.contains('cheque')) return 'Cheque';
    return null;
  }

  String? _extractAmountFromText(String text) {
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


  String? _extractBeneficiaryFromText(String text) {
    text = text.toLowerCase();
    if (text.contains('self') || text.contains('my name')) return 'Self';
    if (text.contains('child') || text.contains('son') || text.contains('daughter') || text.contains('kid')) return 'Child';
    if (text.contains('parent') || text.contains('father') || text.contains('mother') || text.contains('mom') || text.contains('dad')) return 'Parent';
    if (text.contains('spouse') || text.contains('husband') || text.contains('wife')) return 'Spouse';
    final nameRegex = RegExp(r'(?:patient|recipient|beneficiary|name)[:\s]*([A-Za-z\s\.]+)');
    final match = nameRegex.firstMatch(text);
    if (match != null) {
      String? name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        if (name.length > 2 && !name.contains(RegExp(r'\d')) && !name.contains(RegExp(r'(mr|ms|dr|md|jr|sr)', caseSensitive: false))) {
          return name;
        }
      }
    }
    return null;
  }

  void _showAddClaimForm({
    String? initialAmount,
    String? initialCategory,
    String? initialDescription,
    DateTime? initialDate,
    String? initialReceiptNumber,
    String? initialMerchantName,
    String? initialPaymentMethod,
    String? initialBeneficiary,
    bool isAutoFilled = false,
  }) {
    _amountController.text = initialAmount ?? '';
    _descriptionController.text = initialDescription ?? '';
    _receiptNumberController.text = initialReceiptNumber ?? '';
    _merchantNameController.text = initialMerchantName ?? '';
    _beneficiaryController.text = initialBeneficiary ?? '';

    String? dialogSelectedCategory = initialCategory;
    DateTime? dialogSelectedDate = initialDate;
    String? dialogSelectedPaymentMethod = initialPaymentMethod;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        isAutoFilled ? "Review Auto-Filled Claim" : "Add New Tax Claim",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Essential Claim Details Section ---
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Essential Claim Details:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),

                            // Claim Category
                            const Text("Claim Category:", style: TextStyle(fontSize: 16)),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Select category',
                              ),
                              value: dialogSelectedCategory,
                              items: _mustHaveCategories.map((TaxCategory category) {
                                return DropdownMenuItem<String>(
                                  value: category.name,
                                  child: Text(category.name),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setModalState(() {
                                  dialogSelectedCategory = newValue!;
                                });
                              },
                              isExpanded: true,
                            ),
                            const SizedBox(height: 20),

                            // Amount
                            const Text("Amount (RM):", style: TextStyle(fontSize: 16)),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Enter amount'),
                            ),
                            const SizedBox(height: 20),

                            // Claim Date
                            const Text("Claim Date:", style: TextStyle(fontSize: 16)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dialogSelectedDate != null
                                      ? DateFormat('dd-MM-yyyy').format(dialogSelectedDate!)
                                      : 'No Date Selected',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: dialogSelectedDate ?? DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null && picked != dialogSelectedDate) {
                                      setModalState(() {
                                        dialogSelectedDate = picked;
                                      });
                                    }
                                  },
                                  child: const Text(
                                    'Pick a Date',
                                    style: TextStyle(fontSize: 16, color: Color(0xFFD4AF37)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Receipt Number
                            const Text("Receipt Number:", style: TextStyle(fontSize: 16)),
                            TextFormField(
                              controller: _receiptNumberController,
                            ),
                            const SizedBox(height: 20),

                            // Merchant Name
                            const Text("Merchant Name:", style: TextStyle(fontSize: 16)),
                            TextFormField(
                              controller: _merchantNameController,
                              decoration: const InputDecoration(labelText: 'exp: Klinik Mediviron'),
                            ),
                            const SizedBox(height: 20),

                            // Payment Method
                            const Text("Payment Method:", style: TextStyle(fontSize: 16)),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Select payment method',
                              ),
                              value: dialogSelectedPaymentMethod,
                              items: _paymentMethods.map((String method) {
                                return DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(method),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setModalState(() {
                                  dialogSelectedPaymentMethod = newValue!;
                                });
                              },
                              isExpanded: true,
                            ),
                            const SizedBox(height: 20),

                            // Description
                            const Text("Description:", style: TextStyle(fontSize: 16)),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),


                    const SizedBox(height: 30),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (dialogSelectedCategory == null || _amountController.text.isEmpty || dialogSelectedDate == null) {
                            _showSnack('Please fill in all required fields (Category, Amount, Date).');
                            return;
                          }

                          final double newAmount = double.tryParse(_amountController.text) ?? 0.0;
                          final TaxCategory? selectedTaxCategory = _getCategoryByName(dialogSelectedCategory!);

                          if (selectedTaxCategory != null && selectedTaxCategory.limit != null) {
                            final double currentTotalForCategory = _categoryClaimTotals[selectedTaxCategory.name] ?? 0.0;
                            final double projectedTotal = currentTotalForCategory + newAmount;

                            if (projectedTotal > selectedTaxCategory.limit!) {
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Limit Exceeded!'),
                                  content: Text(
                                    'Adding this claim will exceed the limit for "${selectedTaxCategory.name}".\n\n'
                                        'Current Claimed: RM${currentTotalForCategory.toStringAsFixed(2)}\n'
                                        'New Claim Amount: RM${newAmount.toStringAsFixed(2)}\n'
                                        'Projected Total: RM${projectedTotal.toStringAsFixed(2)}\n'
                                        'Category Limit: RM${selectedTaxCategory.limit!.toStringAsFixed(2)}\n\n'
                                        'Do you still want to add this claim?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Add Anyway'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == false) {
                                return;
                              }
                            }
                          }
                          // Call _addTaxClaimToServer with arguments matching your DB (NO beneficiary if not in DB)
                          _addTaxClaimToServer(
                            amount: _amountController.text,
                            category: dialogSelectedCategory!,
                            date: dialogSelectedDate!,
                          );

                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: const Text('Save Claim'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  String _formatDate(String? rawDate) {
    if (rawDate == null) return 'N/A';
    try {
      final date = DateTime.parse(rawDate);
      return DateFormat('yyyy-MM-dd').format(date); // Change format as needed
    } catch (e) {
      return rawDate; // fallback in case of format issues
    }
  }
  Map<int, double> _calculateTotalByClaimYear() {
    Map<int, double> yearlyTotals = {};
    for (var claim in _trackedClaims) {
      final claimDate = DateTime.tryParse(claim['claim_date'] ?? '');
      if (claimDate != null) {
        final year = claimDate.year;
        final amount = double.tryParse(claim['amount'] ?? '0.0') ?? 0.0;
        yearlyTotals[year] = (yearlyTotals[year] ?? 0.0) + amount;
      }
    }
    return yearlyTotals;
  }
  void _showUpdateAmountDialog(String claimId, String currentAmount) {
    final TextEditingController amountController = TextEditingController(text: currentAmount);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Update Claim Amount"),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "New Amount (RM)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newAmount = amountController.text.trim();
                if (newAmount.isEmpty) return;

                // ✅ Call update API
                final response = await http.post(
                  Uri.parse('http://192.168.0.24/update_tax_amount.php'),
                  body: {
                    'claim_id': claimId,
                    'amount': newAmount,
                  },
                );

                if (response.statusCode == 200 && response.body == 'success') {
                  Navigator.pop(context);
                  _fetchTrackedClaims(); // refresh the list
                  setState(() {});
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to update amount.")),
                  );
                }
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }
  void _fetchTrackedClaims() async {
    final response = await http.get(
      Uri.parse('http://192.168.0.24/get_tax_claims.php?email=${widget.userEmail}'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      setState(() {
        _trackedClaims = data.cast<Map<String, dynamic>>();
        _categoryClaimTotals = _calculateCategoryClaimTotals(); // For tax relief summary
      });
    } else {
      print("Failed to fetch claims: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {

    final Map<String, double> categoryClaimTotals = _calculateCategoryClaimTotals();
    final Map<int, double> yearlyTotals = _calculateTotalByClaimYear();
    final List<int> sortedYears = yearlyTotals.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tax Assistant"),
        backgroundColor: const Color(0xFFD4AF37),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.black),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.add_circle),
                        title: const Text('Add Manually'),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddClaimForm();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text('Scan Receipt'),
                        onTap: () {
                          Navigator.pop(context);
                          _scanReceiptForTaxClaim();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.upload_file),
                        title: const Text('Upload Screenshot'),
                        onTap: () {
                          Navigator.pop(context);
                          _uploadScreenshotForTaxClaim();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView( // Wrap the entire Column with SingleChildScrollView
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Annual Tax Summary:",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...sortedYears.map((year) {
                    final yaToFile = year + 1;
                    final total = yearlyTotals[year] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                          children: [
                            const TextSpan(text: "You can claim "),
                            TextSpan(
                              text: "RM${total.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const TextSpan(text: " in "),
                            TextSpan(
                              text: "$yaToFile",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const TextSpan(text: " based on your "),
                            TextSpan(
                              text: "$year",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const TextSpan(text: " expenses."),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Tax Relief Summary:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : SizedBox( // Fixed height for this section
              height: 450, // Adjust height to show 3-4 items
              child: ListView.builder(
                shrinkWrap: true, // Needed if the height is constrained
                physics: const AlwaysScrollableScrollPhysics(), // Ensures scrolling is always possible within this box
                itemCount: (_mustHaveCategories).length,
                itemBuilder: (context, index) {
                  final category = (_mustHaveCategories )[index];
                  final claimedAmount = categoryClaimTotals[category.name] ?? 0.0;
                  return _TaxReliefSummaryCard(
                    categoryName: category.name,
                    limit: category.limit,
                    claimedAmount: claimedAmount,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your Tracked Tax Claims:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : _trackedClaims.isEmpty
                ? const Center(child: Text('No tax claims tracked yet.'))
                : SizedBox( // Fixed height for this section
              height: 450, // Adjust height to show 3-4 items
              child: ListView.builder(
                shrinkWrap: true, // Needed if the height is constrained
                physics: const AlwaysScrollableScrollPhysics(), // Ensures scrolling is always possible within this box
                itemCount: _trackedClaims.length,
                itemBuilder: (context, index) {
                  final claim = _trackedClaims[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.lightGreen.withOpacity(0.2),
                        child: const Icon(Icons.receipt, color: Colors.lightGreen),
                      ),
                      title: Text(
                        claim['category'] ?? 'Unknown Category',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Date: ${_formatDate(claim['claim_date'])}",
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          Text(
                            "RM${double.parse(claim['amount'] ?? '0.0').toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      children: <Widget>[
                        if (claim['description'] != null && claim['description'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Description: ${claim['description']}",
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (claim['merchant_name'] != null && claim['merchant_name'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.store, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Merchant: ${claim['merchant_name']}",
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (claim['receipt_number'] != null && claim['receipt_number'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.numbers, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Receipt No.: ${claim['receipt_number']}",
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (claim['payment_method'] != null && claim['payment_method'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.payment, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Paid by: ${claim['payment_method']}",
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Only show beneficiary if you add it to your DB schema and fetch it
                        // if (claim['beneficiary'] != null && claim['beneficiary'].isNotEmpty)
                        //   Padding(
                        //     padding: const EdgeInsets.symmetric(vertical: 4.0),
                        //     child: Row(
                        //       children: [
                        //         const Icon(Icons.person, size: 18, color: Colors.grey),
                        //         const SizedBox(width: 8),
                        //         Expanded(
                        //           child: Text("Beneficiary: ${claim['beneficiary']}", style: const TextStyle(fontSize: 14)),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  final TextEditingController amountController =
                                  TextEditingController(text: claim['amount'] ?? '');

                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Update Claim Amount"),
                                      content: TextField(
                                        controller: amountController,
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: "New Amount (RM)",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final newAmount = amountController.text.trim();
                                            if (newAmount.isEmpty) return;

                                            // Send to backend
                                            final response = await http.post(
                                              Uri.parse('http://172.20.10.4/update_tax_amount.php'),
                                              body: {
                                                'claim_id': claim['claim_id'].toString(),
                                                'amount': newAmount,
                                              },
                                            );

                                            if (response.statusCode == 200 && response.body == 'success') {
                                              Navigator.pop(context);
                                              _fetchTrackedClaims(); // refresh list
                                            } else {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Failed to update amount.")),
                                              );
                                            }
                                          },
                                          child: const Text("Update"),
                                        ),
                                      ],
                                    ),
                                  );
                                },


                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Confirm Delete"),
                                      content: const Text("Are you sure you want to delete this claim?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _deleteTaxClaim(claim['claim_id'].toString());
                                  }
                                },

                              ),
                            ],
                          ),
                        )
                      ],
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

// --- TaxReliefSummaryCard Widget (now embedded in the same file) ---
class _TaxReliefSummaryCard extends StatelessWidget {
  final String categoryName;
  final int? limit;
  final double claimedAmount;

  const _TaxReliefSummaryCard({
    Key? key,
    required this.categoryName,
    this.limit,
    required this.claimedAmount,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // Calculate progress (capped at 1.0 if over limit)
    double percentage = 0.0;
    if (limit != null && limit! > 0) {
      percentage = (claimedAmount / limit!).clamp(0.0, 1.0); // Ensure it doesn't go above 1.0 for visual
    }

    Color progressColor;
    if (limit != null && claimedAmount > limit!) {
      progressColor = Colors.red; // Exceeded limit
    } else if (limit != null && percentage >= 0.75) {
      progressColor = Colors.orange; // Approaching limit
    } else {
      progressColor = Colors.green; // Within limit
    }

    bool hasLimit = limit != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Claimed: RM${claimedAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                if (hasLimit)
                  Text(
                    'Limit: RM${limit!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: progressColor, // Color the limit text based on progress
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const Text(
                    'Limit: N/A',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 5),
              Row( // Wrapped in a Row with Expanded to control text
                children: [
                  Expanded(
                    child: Text(
                      '${(percentage * 100).toStringAsFixed(1)}% of limit reached',
                      style: TextStyle(
                        fontSize: 12,
                        color: progressColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
            if (!hasLimit) ...[
              const SizedBox(height: 10),
              Row( // Wrapped in a Row with Expanded to control text
                children: [
                  Expanded(
                    child: const Text(
                      'No limit applies to this category.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}