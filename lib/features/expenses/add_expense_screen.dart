import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import '../../../../theme/app_colors.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final List<TextEditingController> titleControllers = [];
  final List<TextEditingController> amountControllers = [];
  final List<String> selectedCategories = [];

  final ImagePicker _picker = ImagePicker();

  bool isScanning = false;

  final String geminiApiKey = "AIzaSyDoQbhL__7RW1-z31PDAHxeEAcalZTDw7k";

  final List<Map<String, dynamic>> categories = [
    {"name": "food", "icon": Icons.restaurant},
    {"name": "shopping", "icon": Icons.shopping_bag},
    {"name": "transport", "icon": Icons.directions_bus},
    {"name": "bills", "icon": Icons.receipt},
    {"name": "entertainment", "icon": Icons.movie},
    {"name": "health", "icon": Icons.favorite},
    {"name": "education", "icon": Icons.school},
    {"name": "travel", "icon": Icons.flight},
    {"name": "work", "icon": Icons.work},
    {"name": "gift", "icon": Icons.card_giftcard},
    {"name": "subscriptions", "icon": Icons.subscriptions},
    {"name": "other", "icon": Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _addNewItem();
  }

  void _addNewItem() {
    setState(() {
      titleControllers.add(TextEditingController());
      amountControllers.add(TextEditingController());
      selectedCategories.add(categories[0]["name"]);
    });
  }

  void _removeItem(int index) {
    if (titleControllers.length == 1) return;

    setState(() {
      titleControllers[index].dispose();
      amountControllers[index].dispose();

      titleControllers.removeAt(index);
      amountControllers.removeAt(index);
      selectedCategories.removeAt(index);
    });
  }

  double get _totalAmount {
    double total = 0;

    for (var c in amountControllers) {
      total += double.tryParse(c.text) ?? 0;
    }

    return total;
  }

  bool get _isValid {
    for (int i = 0; i < titleControllers.length; i++) {
      if (titleControllers[i].text.trim().isEmpty) return false;

      if ((double.tryParse(amountControllers[i].text) ?? 0) <= 0) {
        return false;
      }
    }

    return titleControllers.isNotEmpty;
  }



  Future<void> _scanReceipt() async {
    try {
      setState(() => isScanning = true);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() => isScanning = false);
        return;
      }

      final inputImage = InputImage.fromFile(File(image.path));

      final textRecognizer = TextRecognizer();

      final RecognizedText recognizedText =
      await textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text;

      await textRecognizer.close();

      if (extractedText.trim().isEmpty) {
        setState(() => isScanning = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text detected'),
          ),
        );

        return;
      }

      await _analyzeReceiptWithAI(extractedText);

      setState(() => isScanning = false);
    } catch (e) {
      setState(() => isScanning = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _analyzeReceiptWithAI(String receiptText) async {
    try {
      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey";

      final prompt = """
You are an AI receipt parser.

Extract:
- title
- total amount
- best category

Supported categories:
food, shopping, transport, bills, entertainment, health, education, travel, work, gift, subscriptions, other

Return ONLY valid JSON.

Receipt:
$receiptText
""";

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final text =
        data['candidates'][0]['content']['parts'][0]['text'];

        final cleanText = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final result = jsonDecode(cleanText);

        final title = result['title'] ?? 'Receipt';
        final amount = result['amount'].toString();
        final category = result['category'] ?? 'other';

        setState(() {
          titleControllers.add(
            TextEditingController(text: title),
          );

          amountControllers.add(
            TextEditingController(text: amount),
          );

          selectedCategories.add(category);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt scanned successfully'),
          ),
        );
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  Future<void> _submitAll() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields correctly'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final total = _totalAmount;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};

      double currentBalance =
      (data['totalBalance'] ?? 0).toDouble();

      double currentExpense =
      (data['totalExpense'] ?? 0).toDouble();

      if (total > currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient balance! You have only \$${currentBalance.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      final transactionsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions');

      for (int i = 0; i < titleControllers.length; i++) {
        final title = titleControllers[i].text.trim();

        final amount =
        double.parse(amountControllers[i].text);

        final category = selectedCategories[i];

        final docRef = transactionsRef.doc();

        batch.set(docRef, {
          'title': title,
          'amount': amount,
          'type': 'expense',
          'category': category,
          'date': Timestamp.now(),
        });
      }

      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid),
        {
          'totalBalance': currentBalance - total,
          'totalExpense': currentExpense + total,
        },
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${titleControllers.length} expenses (\$${total.toStringAsFixed(2)})',
            ),
          ),
        );

        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var c in titleControllers) {
      c.dispose();
    }

    for (var c in amountControllers) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Add Expenses',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '\$ ${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
                Text(
                  '${titleControllers.length} item(s)',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: titleControllers.length,
              itemBuilder: (context, index) =>
                  _buildItemCard(index),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: isScanning ? null : _scanReceipt,
                  icon: isScanning
                      ? SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                    ),
                  )
                      : const Icon(Icons.document_scanner),
                  label: Text(
                    isScanning
                        ? 'Scanning Receipt...'
                        : 'AI Receipt Scanner',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                    Size(double.infinity, 50.h),
                    side: const BorderSide(
                      color: AppColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                OutlinedButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Expense'),
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                    Size(double.infinity, 50.h),
                    side: const BorderSide(
                      color: AppColors.primary,
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                ElevatedButton.icon(
                  onPressed: _submitAll,
                  icon: const Icon(Icons.check),
                  label: Text(
                    'Submit All',
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    minimumSize:
                    Size(double.infinity, 50.h),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleControllers[index],
                    decoration: InputDecoration(
                      labelText:
                      'Item ${index + 1} Name',
                      prefixIcon:
                      const Icon(Icons.label_outline),
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: amountControllers[index],
                    keyboardType:
                    TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12.w),

                Expanded(
                  flex: 3,
                  child:
                  DropdownButtonFormField<String>(
                    value: selectedCategories[index],
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(12.r),
                      ),
                      contentPadding:
                      EdgeInsets.symmetric(
                        horizontal: 12.w,
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat["name"],
                        child: Row(
                          children: [
                            Icon(
                              cat["icon"],
                              size: 18.sp,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                cat["name"]
                                    .toUpperCase(),
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategories[index] =
                        value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}