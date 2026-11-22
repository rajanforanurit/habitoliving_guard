import 'json.dart';

class CallContact {
  const CallContact({
    required this.userId,
    required this.name,
    required this.role,
    this.label,
  });

  factory CallContact.fromJson(Map<String, dynamic> json) => CallContact(
    userId: asString(json['userId']),
    name: asString(json['name'], fallback: 'User'),
    role: asString(json['role'], fallback: 'RESIDENT'),
    label: asStringOrNull(json['label']),
  );

  final String userId;
  final String name;

  /// `RESIDENT`, `GUARD` or `SOCIETY_ADMIN`.
  final String role;

  /// Flat for residents, gate for guards, designation for admins.
  final String? label;

  String get roleLabel => switch (role) {
    'RESIDENT' => 'Resident',
    'GUARD' => 'Security guard',
    'SOCIETY_ADMIN' => 'Society admin',
    _ => humanize(role),
  };
}

class CallRecord {
  const CallRecord({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.status,
    this.callerName,
    this.calleeName,
    this.callerLabel,
    this.calleeLabel,
    this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: asString(json['id']),
    callerId: asString(json['callerId']),
    calleeId: asString(json['calleeId']),
    status: asString(json['status'], fallback: 'RINGING').toUpperCase(),
    callerName: asStringOrNull(json['callerName']),
    calleeName: asStringOrNull(json['calleeName']),
    callerLabel: asStringOrNull(json['callerLabel']),
    calleeLabel: asStringOrNull(json['calleeLabel']),
    createdAt: asDateOrNull(json['createdAt']),
    answeredAt: asDateOrNull(json['answeredAt']),
    endedAt: asDateOrNull(json['endedAt']),
  );

  final String id;
  final String callerId;
  final String calleeId;
  final String status;
  final String? callerName;
  final String? calleeName;
  final String? callerLabel;
  final String? calleeLabel;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  Duration? get duration => (answeredAt != null && endedAt != null)
      ? endedAt!.difference(answeredAt!)
      : null;
}

class IceConfig {
  const IceConfig({required this.iceServers, required this.ringSeconds});

  factory IceConfig.fromJson(Map<String, dynamic> json) => IceConfig(
    iceServers: asMapList(json['iceServers']),
    ringSeconds: asInt(json['ringSeconds'], fallback: 45),
  );

  final List<Map<String, dynamic>> iceServers;
  final int ringSeconds;
}
