class RoadReport {
  const RoadReport({required this.id, required this.ownerId, required this.type, required this.severity, required this.latitude, required this.longitude, required this.createdAt, this.note = '', this.photoUrl});
  final String id, ownerId, type, severity, note;
  final double latitude, longitude;
  final DateTime createdAt;
  final String? photoUrl;

  Map<String, Object?> toJson() => {
    'id': id, 'ownerId': ownerId, 'type': type, 'severity': severity, 'note': note,
    'latitude': latitude, 'longitude': longitude, 'createdAt': createdAt.millisecondsSinceEpoch,
    'photoUrl': photoUrl,
  };
}
