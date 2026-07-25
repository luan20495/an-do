import 'dart:io';

import 'package:an_do/core/i18n/strings.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportDraft {
  const ReportDraft({
    required this.type,
    required this.severity,
    required this.note,
    this.photo,
  });

  final String type;
  final String severity;
  final String note;
  final XFile? photo;
}

class ReportForm extends StatefulWidget {
  const ReportForm({super.key});

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final TextEditingController _note = TextEditingController();
  String _type = 'flood';
  String _severity = 'medium';
  XFile? _photo;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Báo đoạn đường',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7F5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black26),
                ),
                child: _photo == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_a_photo_outlined, size: 32),
                            const SizedBox(height: 6),
                            Text(strings.addPhoto),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Image.file(File(_photo!.path), fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'flood', child: Text('Ngập')),
                DropdownMenuItem(value: 'landslide', child: Text('Sạt lở')),
                DropdownMenuItem(value: 'tree', child: Text('Cây đổ')),
                DropdownMenuItem(value: 'blocked', child: Text('Đường bị chặn')),
                DropdownMenuItem(value: 'bridge', child: Text('Cầu hỏng')),
                DropdownMenuItem(value: 'other', child: Text('Khác')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'other'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _severity,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Nhẹ')),
                DropdownMenuItem(value: 'medium', child: Text('Đáng chú ý')),
                DropdownMenuItem(value: 'high', child: Text('Nguy hiểm')),
              ],
              onChanged: (value) => setState(
                () => _severity = value ?? 'medium',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '${strings.description} · ${strings.optional}',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  ReportDraft(
                    type: _type,
                    severity: _severity,
                    note: _note.text.trim(),
                    photo: _photo,
                  ),
                ),
                child: Text(
                  strings.sendReport,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
