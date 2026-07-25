import 'package:flutter/widgets.dart';

class S {
  S(this.context);
  final BuildContext context;
  bool get vi => Localizations.localeOf(context).languageCode == 'vi';

  String get chooseLanguage => vi ? 'Chọn ngôn ngữ' : 'Choose language';
  String get chooseLanguageCopy => vi
      ? 'Chọn ngôn ngữ để bắt đầu. Tiếng Việt được chọn sẵn.'
      : 'Choose a language to start. Vietnamese is preselected.';
  String get continueLabel => vi ? 'Tiếp tục' : 'Continue';
  String get communityMap => vi ? 'Bản đồ SOS cộng đồng' : 'Community SOS map';
  String get search => vi ? 'Focus nhanh · chọn SOS' : 'Quick focus · pick SOS';
  String get searchTitle => vi ? 'Tìm trên bản đồ' : 'Search the map';
  String get focusTitle => vi ? 'Focus bản đồ' : 'Map focus';
  String get focusSubtitle => vi
      ? 'Chạm một ca gần bạn — không cần nhớ mã SOS.'
      : 'Tap a nearby case — no need to remember SOS codes.';
  String get focusNearest => vi ? 'Gần nhất' : 'Nearest';
  String get focusAllSos => vi ? 'Tất cả SOS' : 'All SOS';
  String get focusHazards => vi ? 'Cảnh báo' : 'Alerts';
  String get focusOverview => vi ? 'Toàn cảnh' : 'Overview';
  String get focusFilterHint => vi
      ? 'Lọc theo loại, tên hoặc mã (tuỳ chọn)'
      : 'Filter by type, name or code (optional)';
  String activeSosList(int n) => vi ? 'SOS đang hoạt động ($n)' : 'Active SOS ($n)';
  String roadAlertsList(int n) => vi ? 'Cảnh báo đường ($n)' : 'Road alerts ($n)';
  String get noActiveSos => vi ? 'Chưa có SOS công khai gần đây.' : 'No public SOS nearby yet.';
  String get searchHint => vi
      ? 'Nhập mã SOS (vd: AD-742819) hoặc mô tả cảnh báo đường.'
      : 'Enter an SOS code (e.g. AD-742819) or a road alert label.';
  String get searchPlaceholder =>
      vi ? 'Ví dụ: AD-742819 hoặc ngập' : 'e.g. AD-742819 or flood';
  String get searchAction => vi ? 'Tìm trên bản đồ' : 'Find on map';
  String get searchNotFound => vi
      ? 'Không khớp kết quả nào.'
      : 'No matching results.';
  String get reportRoad => vi ? 'Báo đường' : 'Report road';
  String get holdSos => vi ? 'Giữ để SOS' : 'Hold for SOS';
  String get nearby => vi ? 'Gần bạn' : 'Nearby';
  String get routes => vi ? 'Tuyến đường' : 'Routes';
  String get details => vi ? 'Chi tiết' : 'Details';
  String get compass => vi ? 'La bàn' : 'Compass';
  String get profile => vi ? 'Hồ sơ SOS' : 'SOS profile';
  String get saveProfile => vi ? 'Lưu trên thiết bị' : 'Save on device';
  String get profileSaved => vi
      ? 'Đã lưu trên thiết bị. Chỉ chia sẻ khi bạn phát SOS.'
      : 'Saved on device. Shared only when you send SOS.';
  String get language => vi ? 'Ngôn ngữ' : 'Language';
  String get privacy => vi ? 'Quyền riêng tư' : 'Privacy';
  String get privacyTitle => vi ? 'Riêng tư và dữ liệu' : 'Privacy and data';
  String get privacyBody => vi
      ? 'Vị trí không được chia sẻ khi bạn chỉ mở bản đồ. Nó chỉ gửi khi bạn phát SOS hoặc chủ động hỗ trợ một ca và bắt đầu dẫn đường.\n\nTrên thiết bị: hồ sơ tùy chọn, báo cáo chờ mạng.\nKhi SOS: tọa độ, thời gian, độ chính xác GPS, pin và thông tin liên hệ bạn đã chọn.\n\nAn Đồ không thay thế tổng đài khẩn cấp 112.'
      : 'Location is not shared when you only open the map. It is sent only when you start SOS or accept a case and begin navigation.\n\nOn device: optional profile, queued reports.\nDuring SOS: coordinates, time, GPS accuracy, battery, and contact details you chose.\n\nAn Đồ does not replace emergency number 112.';
  String get offlineMap => vi ? 'Bản đồ offline (sắp có)' : 'Offline map (coming soon)';
  String get offlineComingSoon => vi
      ? 'Tải khu vực bản đồ để dùng khi mất mạng sẽ có ở phiên bản mở rộng.'
      : 'Downloading map areas for offline use comes in a later release.';
  String get gotIt => vi ? 'Đã hiểu' : 'Got it';
  String get sosActive => vi ? 'SOS đang hoạt động' : 'SOS is active';
  String get stopSos => vi ? 'Tôi đã an toàn' : 'I am safe';
  String get call112 => vi ? 'Gọi 112' : 'Call 112';
  String get helpThis => vi ? 'Hỗ trợ ca này' : 'Help this case';
  String helpersWatching(int n) => n <= 0
      ? (vi
          ? 'Chưa có ai theo dõi phiên SOS'
          : 'No one is watching your SOS yet')
      : (vi
          ? (n == 1
              ? '1 người đang hỗ trợ bạn'
              : '$n người đang hỗ trợ bạn')
          : (n == 1
              ? '1 person is helping you'
              : '$n people are helping you'));
  String helperJoined(int n) => vi
      ? (n == 1
          ? 'Có 1 người vừa bắt đầu hỗ trợ bạn.'
          : 'Có $n người đang để ý đến bạn.')
      : (n == 1
          ? 'Someone just started helping you.'
          : '$n people are now watching your SOS.');
  String get cannotHelpOwnSos =>
      vi ? 'Đây là phiên SOS của bạn.' : 'This is your own SOS session.';
  String get chatHelpersTitle =>
      vi ? 'Người đang hỗ trợ bạn' : 'People helping you';
  String get chatHelpersSubtitle => vi
      ? 'Chọn một người để nhắn tin hoặc gửi audio.'
      : 'Pick someone to message or send audio.';
  String get helperLabel => vi ? 'Người hỗ trợ' : 'Helper';
  String get chatEmptyThread =>
      vi ? 'Chưa có tin nhắn' : 'No messages yet';
  String get chatEmptyHint => vi
      ? 'Giữ mic để nói nhanh khi đang di chuyển. Hoặc gõ tin nhắn bên dưới.'
      : 'Hold the mic to talk while moving. Or type a message below.';
  String get chatHint => vi ? 'Nhắn tin…' : 'Message…';
  String get chatRecording =>
      vi ? 'Đang ghi… thả để gửi · kéo lên để hủy' : 'Recording… release to send · swipe up to cancel';
  String get chatReleaseToCancel =>
      vi ? 'Thả để hủy' : 'Release to cancel';
  String get micPermissionDenied => vi
      ? 'Cần quyền micro để gửi tin audio.'
      : 'Microphone permission is required for audio messages.';
  String get messageVictim => vi ? 'Nhắn nạn nhân' : 'Message victim';
  String get openChat => vi ? 'Nhắn hỗ trợ' : 'Message helpers';
  String get victimLabel => vi ? 'Người cần cứu hộ' : 'Person in need';
  String get helpingThis => vi ? 'Đang hỗ trợ ca này' : 'Helping this case';
  String get optional => vi ? 'Không bắt buộc' : 'Optional';
  String get sendSos => vi ? 'Phát SOS ngay' : 'Send SOS now';
  String get name => vi ? 'Tên' : 'Name';
  String get phone => vi ? 'Số điện thoại' : 'Phone';
  String get email => 'Email';
  String get description => vi ? 'Mô tả ngắn' : 'Short description';
  String get people => vi ? 'Số người cần giúp' : 'People needing help';
  String get addPhoto => vi ? 'Chụp hoặc chọn ảnh' : 'Take or choose a photo';
  String get sendReport => vi ? 'Gửi cảnh báo' : 'Send warning';
  String get saveProfileHint => vi
      ? 'Thông tin giúp đội cứu hộ liên hệ nhanh hơn. Bạn có thể bỏ qua và vẫn phát SOS.'
      : 'Contact information helps rescuers reach you. You can skip it and still send SOS.';

  String sosType(String type) => switch (type) {
        'flood' => vi ? 'Ngập lụt' : 'Flood',
        'lost' => vi ? 'Bị lạc' : 'Lost',
        'injury' => vi ? 'Bị thương' : 'Injury',
        'vehicle' => vi ? 'Hỏng phương tiện' : 'Vehicle failure',
        _ => vi ? 'Nguy hiểm khác' : 'Other hazard',
      };

  String sosCount(int n) => vi ? '$n SOS' : '$n SOS';
  String alertCount(int n) => vi ? '$n cảnh báo' : '$n alerts';
  String teamsNearby(int n) => vi ? '$n đội gần' : '$n teams nearby';
  String get clearSelection => vi ? 'Bỏ chọn' : 'Clear selection';
  String get backToList => vi ? 'Danh sách SOS' : 'SOS list';
  String get roadAlert => vi ? 'Cảnh báo đường' : 'Road alert';
  String hazardType(String type) => switch (type) {
        'flood' => vi ? 'Ngập' : 'Flood',
        'fallen_tree' => vi ? 'Cây đổ' : 'Fallen tree',
        'landslide' => vi ? 'Sạt lở' : 'Landslide',
        'accident' => vi ? 'Tai nạn' : 'Accident',
        _ => vi ? 'Nguy hiểm khác' : 'Other hazard',
      };
  String severityLabel(String severity) => switch (severity) {
        'high' => vi ? 'Mức cao' : 'High',
        'medium' => vi ? 'Mức trung bình' : 'Medium',
        'low' => vi ? 'Mức thấp' : 'Low',
        _ => severity,
      };
}
