import 'dart:async';

import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/resident.dart';
import '../../models/society.dart';
import '../api_client.dart';

/// Guard API client for routes under `/guard`.
///
/// The guard's job at the gate is fast lookup and clear decisions, so this
/// client keeps those actions one call each: lookup a flat, verify a pass,
/// record entry or exit, deny.
class GuardApi {
  GuardApi(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> profile() async {
    return reqMap(await _api.get('/guard/profile'), field: 'profile');
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    await _api.patch('/guard/profile', body: body);
  }

  Future<void> saveNotificationPreferences(Map<String, bool> prefs) async {
    await _api.put('/guard/notification-preferences', body: prefs);
  }

  /// Today's briefing: expected visitors, pending approvals, active alerts and
  /// the assigned gate.
  Future<GuardDashboard> dashboard() async {
    final data = await _api.get('/guard/dashboard');
    return GuardDashboard.fromJson(reqMap(data, field: 'dashboard'));
  }

  /// The gate this guard is assigned to.
  Future<String> myGate() async {
    final data = await _api.get('/guard/gate');
    return asString(
      reqMap(data, field: 'gate')['name'],
      fallback: 'Unassigned',
    );
  }

  /// Look up a destination flat by label. Returns the matching flats.
  Future<List<Map<String, dynamic>>> lookupFlat(String query) async {
    final data = await _api.get(
      '/guard/flats/lookup',
      query: {'q': query.trim(), 'limit': '15'},
    );
    return asMapList(data);
  }

  /// The society property layout: towers and the flats inside each tower.
  ///
  /// This is the guard's only read of the society structure; it intentionally
  /// carries unit IDs and labels.
  Future<SocietyPropertyInfo> societyInfo() async {
    final data = await _api.get('/guard/society-info');
    return SocietyPropertyInfo.fromJson(reqMap(data, field: 'societyInfo'));
  }

  /// Search visitor records (history and current).
  Future<PageResult<Visitor>> visitors({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final data = await _api.get(
      '/guard/visitors',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return PageResult.from(data, _api.lastMeta, Visitor.fromJson);
  }

  /// Visitors waiting for a resident decision.
  Future<List<Visitor>> pendingVisitors() async {
    final data = await _api.get('/guard/visitors/pending');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  /// Visitors currently inside the society.
  Future<List<Visitor>> activeVisitors() async {
    final data = await _api.get('/guard/visitors/active');
    return asMapList(data).map(Visitor.fromJson).toList(growable: false);
  }

  /// Pre-approved visitors expected today.
  Future<List<Visitor>> expectedVisitors() async {
    final data = await _api.get('/guard/visitors/expected');
    return asMapList(data)
        .map((item) => Visitor.fromJson({...item, 'status': 'EXPECTED'}))
        .toList(growable: false);
  }

  /// Register a walk-in visitor and ask the resident to approve.
  Future<Visitor> registerVisitor({
    required String name,
    required String flatId,
    String? phone,
    String? visitorType,
    String? purpose,
    String? company,
    String? vehicleNumber,
    String? photoFileId,
  }) async {
    final data = await _api.post(
      '/guard/visitors',
      body: {
        'name': name,
        'flatId': flatId,
        if (phone != null && phone.isNotEmpty) 'mobile': phone,
        if (visitorType != null && visitorType.isNotEmpty)
          'visitorType': visitorType,
        if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
        if (company != null && company.isNotEmpty) 'company': company,
        if (vehicleNumber != null && vehicleNumber.isNotEmpty)
          'vehicleNumber': vehicleNumber,
        if (photoFileId != null && photoFileId.isNotEmpty)
          'photoFileId': photoFileId,
      },
    );
    return Visitor.fromJson(reqMap(data, field: 'visitor'));
  }

  /// Verify a visitor pass by its OTP code or scanned QR token.
  Future<Visitor> verifyPass(String code, {String? qrToken}) async {
    final data = await _api.post(
      '/guard/visitors/verify',
      body: {
        if (code.isNotEmpty) 'code': code,
        if (qrToken != null && qrToken.isNotEmpty) 'qrToken': qrToken,
      },
    );
    return Visitor.fromJson(reqMap(data, field: 'visitor'));
  }

  /// Record an emergency entry (ambulance, fire, police). Bypasses approval.
  Future<Visitor> emergencyEntry({
    required String flatId,
    required String purpose,
    required String name,
    required String reason,
  }) async {
    final data = await _api.post(
      '/guard/visitors/emergency-entry',
      body: {
        'flatId': flatId,
        'name': name,
        'purpose': purpose,
        'visitorType': 'SERVICE_PROVIDER',
        'reason': reason,
      },
    );
    return Visitor.fromJson(reqMap(data, field: 'visitor'));
  }

  /// Re-contact the resident for an approval decision.
  Future<void> requestApproval(String visitorId) async {
    await _api.post('/guard/visitors/$visitorId/request-approval');
  }

  Future<void> recordEntry(String visitorId) async {
    await _api.post('/guard/visitors/$visitorId/entry');
  }

  Future<void> recordExit(String visitorId) async {
    await _api.post('/guard/visitors/$visitorId/exit');
  }

  Future<void> denyEntry(String visitorId, {String? reason}) async {
    await _api.post(
      '/guard/visitors/$visitorId/deny',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  // ------------------------------------------------------------ deliveries

  Future<PageResult<Delivery>> deliveries({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    final data = await _api.get(
      '/guard/deliveries',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return PageResult.from(data, _api.lastMeta, Delivery.fromJson);
  }

  /// Register delivery personnel and notify the resident.
  ///
  /// [courier]/[type] are the older call shape and are still accepted so the
  /// legacy delivery desk keeps working; the gate UI uses [company],
  /// [agentName] and [deliveryType], which match the backend schema.
  Future<Delivery> registerDelivery({
    required String flatId,
    String? courier,
    String? type,
    String? note,
    String? company,
    String? deliveryType,
    String? agentName,
    String? agentMobile,
    String? photoFileId,
  }) async {
    final resolvedCompany = company ?? courier;
    final resolvedType = deliveryType ?? type;
    final resolvedAgent = agentName ?? courier;
    final data = await _api.post(
      '/guard/deliveries',
      body: {
        'flatId': flatId,
        if (resolvedCompany != null && resolvedCompany.isNotEmpty)
          'company': resolvedCompany,
        if (resolvedType != null && resolvedType.isNotEmpty)
          'deliveryType': resolvedType,
        if (resolvedAgent != null && resolvedAgent.isNotEmpty)
          'agentName': resolvedAgent,
        if (agentMobile != null && agentMobile.isNotEmpty)
          'agentMobile': agentMobile,
        if (photoFileId != null && photoFileId.isNotEmpty)
          'photoFileId': photoFileId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Delivery.fromJson(reqMap(data, field: 'delivery'));
  }

  Future<void> requestDeliveryApproval(String deliveryId) async {
    await _api.post('/guard/deliveries/$deliveryId/request-approval');
  }

  Future<void> recordDeliveryEntry(String deliveryId) async {
    await _api.post('/guard/deliveries/$deliveryId/entry');
  }

  Future<void> recordDeliveryExit(String deliveryId) async {
    await _api.post('/guard/deliveries/$deliveryId/exit');
  }

  /// Accept a parcel at the gate and generate a collection OTP for the resident.
  Future<Map<String, dynamic>> leaveAtGate(String deliveryId) async {
    final data = await _api.post('/guard/deliveries/$deliveryId/leave-at-gate');
    return reqMap(data, field: 'delivery');
  }

  /// Hand a parcel over after the resident presents the OTP.
  Future<void> handOver(String deliveryId, {required String otp}) async {
    await _api.post(
      '/guard/deliveries/$deliveryId/handover',
      body: {'otp': otp},
    );
  }

  // ---------------------------------------------------------- domestic help

  /// Verify a domestic worker by their entry code.
  Future<Map<String, dynamic>> lookupHelper(String code) async {
    final data = await _api.post(
      '/guard/domestic-help/lookup',
      body: {'code': code},
    );
    return reqMap(data, field: 'helper');
  }

  Future<Map<String, dynamic>> checkInHelper(String code) async {
    final data = await _api.post(
      '/guard/domestic-help/check-in',
      body: {'code': code},
    );
    return reqMap(data, field: 'helper');
  }

  Future<Map<String, dynamic>> checkOutHelper(String code) async {
    final data = await _api.post(
      '/guard/domestic-help/check-out',
      body: {'code': code},
    );
    return reqMap(data, field: 'helper');
  }

  /// Verified domestic workers on today's roster.
  Future<List<ExpectedHelper>> expectedHelpers() async {
    final data = await _api.get('/guard/domestic-help/expected');
    return asMapList(data).map(ExpectedHelper.fromJson).toList(growable: false);
  }

  Future<void> reportUnauthorizedHelper({
    required String description,
    String? name,
  }) async {
    await _api.post(
      '/guard/domestic-help/unauthorized-report',
      body: {
        'description': description,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
  }

  // ---------------------------------------------------------------- alerts

  Future<List<EmergencyAlert>> activeAlerts() async {
    final data = await _api.get('/guard/alerts');
    return asMapList(data).map(EmergencyAlert.fromJson).toList(growable: false);
  }

  /// Raise an emergency alert (fire, medical, security).
  Future<EmergencyAlert> raiseAlert({
    required String type,
    String? location,
    String? message,
  }) async {
    final data = await _api.post(
      '/guard/alerts',
      body: {
        'type': type,
        if (location != null && location.isNotEmpty) 'location': location,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return EmergencyAlert.fromJson(reqMap(data, field: 'alert'));
  }

  /// Acknowledge or resolve an alert.
  Future<void> updateAlert(
    String id, {
    required String status,
    String? note,
  }) async {
    await _api.patch(
      '/guard/alerts/$id',
      body: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  // ------------------------------------------------------------- incidents

  Future<Incident> reportIncident({
    required String type,
    String? description,
    String? location,
  }) async {
    final data = await _api.post(
      '/guard/incidents',
      body: {
        'type': type,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );
    return Incident.fromJson(reqMap(data, field: 'incident'));
  }

  // -------------------------------------------------------- emergency contacts

  Future<PageResult<Incident>> incidents({int limit = 20}) async {
    final data = await _api.get('/guard/incidents', query: {'limit': '$limit'});
    return PageResult.from(data, _api.lastMeta, Incident.fromJson);
  }

  Future<List<EmergencyContact>> emergencyContacts() async {
    final data = await _api.get('/guard/emergency-contacts');
    return asMapList(
      data,
    ).map(EmergencyContact.fromJson).toList(growable: false);
  }

  Future<PageResult<ServiceProvider>> helpdesk({int page = 1}) async {
    final data = await _api.get('/guard/helpdesk', query: {'page': '$page'});
    return PageResult.from(data, _api.lastMeta, ServiceProvider.fromJson);
  }

  Future<void> reportLostAndFound({
    required String type,
    required String title,
    required String description,
    required String location,
  }) async {
    await _api.post(
      '/guard/lost-found',
      body: {
        'type': type,
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (location.isNotEmpty) 'locationFound': location,
      },
    );
  }

  // ------------------------------------------------------------ lost & found

  Future<PageResult<LostFoundItem>> lostAndFound({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    final data = await _api.get(
      '/guard/lost-found',
      query: {
        'page': '$page',
        'limit': '$limit',
        if (type != null) 'type': type,
      },
    );
    return PageResult.from(data, _api.lastMeta, LostFoundItem.fromJson);
  }
}
