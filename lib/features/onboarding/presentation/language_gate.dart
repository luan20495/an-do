import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class LanguageGate extends StatefulWidget {
  const LanguageGate({required this.language, super.key});
  final AppLanguageController language;

  @override
  State<LanguageGate> createState() => _LanguageGateState();
}

class _LanguageGateState extends State<LanguageGate> {
  String selected = 'vi';

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEDF6F2), Color(0xFFC8DDD5)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            elevation: 14,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.brand,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: const Text('AĐ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('An Đồ', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                      Text(s.communityMap),
                    ]),
                  ]),
                  const SizedBox(height: 26),
                  Text(s.chooseLanguage, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(s.chooseLanguageCopy, style: const TextStyle(color: Colors.black54, height: 1.4)),
                  const SizedBox(height: 16),
                  _LanguageTile(
                    flag: '🇻🇳', title: 'Tiếng Việt', subtitle: 'Ngôn ngữ mặc định', selected: selected == 'vi',
                    onTap: () => setState(() => selected = 'vi'),
                  ),
                  const SizedBox(height: 10),
                  _LanguageTile(
                    flag: '🇬🇧', title: 'English', subtitle: 'English language', selected: selected == 'en',
                    onTap: () => setState(() => selected = 'en'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => widget.language.choose(selected),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      child: Text(selected == 'vi' ? 'Tiếp tục' : 'Continue', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.flag, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String flag, title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFEAF7F2) : const Color(0xFFF3F7F5),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppTheme.brand : Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 27)),
          const SizedBox(width: 14),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ])),
          Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? AppTheme.brand : Colors.black26),
        ]),
      ),
    ),
  );
}
