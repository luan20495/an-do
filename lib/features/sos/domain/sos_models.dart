class SosProfile {
  const SosProfile({this.name = '', this.phone = '', this.email = ''});
  final String name;
  final String phone;
  final String email;

  Map<String, Object?> toJson() => {'name': name, 'phone': phone, 'email': email};
  factory SosProfile.fromJson(Map<String, Object?> json) => SosProfile(
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
  );
}

class SosSession {
  const SosSession({
    required this.id,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.type = 'other',
    this.peopleCount = 1,
    this.description = '',
    this.profile = const SosProfile(),
    this.batteryPercent = 100,
    this.accuracyMeters = 0,
    this.active = true,
  });
  final String id, ownerId, type, description;
  final double latitude, longitude, accuracyMeters;
  final int peopleCount, batteryPercent;
  final DateTime updatedAt;
  final SosProfile profile;
  final bool active;

  Map<String, Object?> toJson() => {
    'id': id, 'ownerId': ownerId, 'type': type, 'peopleCount': peopleCount,
    'description': description, 'profile': profile.toJson(), 'active': active,
    'latitude': latitude, 'longitude': longitude, 'accuracyMeters': accuracyMeters,
    'batteryPercent': batteryPercent, 'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory SosSession.fromJson(String id, Map<Object?, Object?> json) {
    final p = Map<String, Object?>.from((json['profile'] as Map?) ?? const {});
    return SosSession(
      id: id,
      ownerId: json['ownerId'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      peopleCount: (json['peopleCount'] as num?)?.toInt() ?? 1,
      description: json['description'] as String? ?? '',
      profile: SosProfile.fromJson(p),
      active: json['active'] as bool? ?? true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 100,
      updatedAt: DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num?)?.toInt() ?? 0),
    );
  }
}
