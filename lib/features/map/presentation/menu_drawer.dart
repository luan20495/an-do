import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({
    required this.language,
    required this.onReportRoad,
    required this.onProfile,
    required this.onOffline,
    required this.onPrivacy,
    super.key,
  });

  final AppLanguageController language;
  final VoidCallback onReportRoad;
  final VoidCallback onProfile;
  final VoidCallback onOffline;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.brand,
                child: Text(
                  'AĐ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: Text(
                'An Đồ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('Biết nguy hiểm. Tìm đường an toàn.'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: Text(strings.reportRoad),
              subtitle: Text(
                strings.vi
                    ? 'Chụp ảnh đoạn đường nguy hiểm'
                    : 'Photo a hazardous road segment',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onReportRoad();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(strings.profile),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(strings.offlineMap),
              subtitle: Text(
                strings.vi ? 'Phiên bản mở rộng' : 'Later release',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onOffline();
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(strings.language),
              trailing: DropdownButton<String>(
                value: language.locale.languageCode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'vi', child: Text('VI')),
                  DropdownMenuItem(value: 'en', child: Text('EN')),
                ],
                onChanged: (value) {
                  if (value != null) language.change(value);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(strings.privacy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onPrivacy();
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                strings.vi
                    ? 'Vị trí chỉ được chia sẻ khi bạn chủ động phát SOS. '
                        'An Đồ không thay thế tổng đài khẩn cấp 112.'
                    : 'Location is shared only when you actively send SOS. '
                        'An Đồ does not replace emergency number 112.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
