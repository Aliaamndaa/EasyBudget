import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddTaxOptionScreen extends StatelessWidget {
  final Function onAddManual;
  final Function(File image) onScanReceipt;
  final Function(File image) onUploadScreenshot;

  const AddTaxOptionScreen({
    Key? key,
    required this.onAddManual,
    required this.onScanReceipt,
    required this.onUploadScreenshot,
  }) : super(key: key);

  Future<void> _handleScan(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      onScanReceipt(File(pickedFile.path));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image selected.")),
      );
    }
  }

  Future<void> _handleUpload(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      onUploadScreenshot(File(pickedFile.path));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No image selected.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Tax Claim'),
        backgroundColor: const Color(0xFFD4AF37),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Add Manually'),
            onTap: () {
              onAddManual();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Scan Receipt'),
            onTap: () => _handleScan(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload Screenshot'),
            onTap: () => _handleUpload(context),
          ),
        ],
      ),
    );
  }
}