import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter/material.dart';

class SosDraft {
  const SosDraft({
    required this.type,
    required this.peopleCount,
    required this.description,
    required this.profile,
  });

  final String type;
  final int peopleCount;
  final String description;
  final SosProfile profile;
}

class SosForm extends StatefulWidget {
  const SosForm({required this.initialProfile, super.key});

  final SosProfile initialProfile;

  @override
  State<SosForm> createState() => _SosFormState();
}

class _SosFormState extends State<SosForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final TextEditingController _description = TextEditingController();
  String _type = 'other';
  int _peopleCount = 1;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialProfile.name);
    _phone = TextEditingController(text: widget.initialProfile.phone);
    _email = TextEditingController(text: widget.initialProfile.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _description.dispose();
    super.dispose();
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
            const Center(child: SizedBox(width: 40, child: Divider(thickness: 5))),
            const Text(
              'Phát SOS',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(strings.saveProfileHint),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'flood', child: Text('Ngập lụt')),
                DropdownMenuItem(value: 'lost', child: Text('Bị lạc')),
                DropdownMenuItem(value: 'injury', child: Text('Bị thương')),
                DropdownMenuItem(value: 'vehicle', child: Text('Hỏng phương tiện')),
                DropdownMenuItem(value: 'other', child: Text('Nguy hiểm khác')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'other'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: '${strings.name} · ${strings.optional}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '${strings.phone} · ${strings.optional}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: '${strings.email} · ${strings.optional}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '${strings.description} · ${strings.optional}',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(strings.people),
                const Spacer(),
                IconButton(
                  onPressed: _peopleCount > 1
                      ? () => setState(() => _peopleCount--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_peopleCount',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => setState(() => _peopleCount++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                onPressed: () => Navigator.pop(
                  context,
                  SosDraft(
                    type: _type,
                    peopleCount: _peopleCount,
                    description: _description.text.trim(),
                    profile: SosProfile(
                      name: _name.text.trim(),
                      phone: _phone.text.trim(),
                      email: _email.text.trim(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.sos),
                label: Text(
                  strings.sendSos,
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
