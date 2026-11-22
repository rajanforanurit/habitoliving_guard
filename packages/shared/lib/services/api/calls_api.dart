import '../../models/calls.dart';
import '../../models/json.dart';
import '../api_client.dart';

class CallsApi {
  CallsApi(this._api);

  final ApiClient _api;

  Future<IceConfig> iceServers() async {
    final data = await _api.get('/calls/ice-servers');
    return IceConfig.fromJson(reqMap(data, field: 'ice'));
  }

  Future<List<CallContact>> callContacts({String? role, String? search}) async {
    final data = await _api.get(
      '/calls/contacts',
      query: {
        'limit': '100',
        if (role != null && role.isNotEmpty) 'role': role,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return asMapList(data).map(CallContact.fromJson).toList(growable: false);
  }

  Future<PageResult<CallRecord>> callHistory({
    int page = 1,
    int limit = 30,
  }) async {
    final data = await _api.get(
      '/calls/history',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return PageResult.from(data, _api.lastMeta, CallRecord.fromJson);
  }

  Future<CallRecord> startCall(String calleeId) async {
    final data = await _api.post('/calls', body: {'calleeId': calleeId});
    return CallRecord.fromJson(reqMap(data, field: 'call'));
  }

  Future<CallRecord> callStatus(String id) async {
    final data = await _api.get('/calls/$id');
    return CallRecord.fromJson(reqMap(data, field: 'call'));
  }

  Future<void> acceptCall(String id) async => _api.post('/calls/$id/accept');
  Future<void> rejectCall(String id) async => _api.post('/calls/$id/reject');
  Future<void> cancelCall(String id) async => _api.post('/calls/$id/cancel');
  Future<void> endCall(String id) async => _api.post('/calls/$id/end');
}
