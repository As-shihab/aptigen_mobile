import '../../../core/network/http_client.dart';
import '../models/stay_model.dart';

class StaysService {
  final ApiClient _client;
  StaysService(this._client);

  Future<List<StayModel>> getPublicStays() async {
    final data = await _client.get('public/stays', isV8: false);
    final List<dynamic> list = data is List
        ? data
        : (data as Map<String, dynamic>?)?['value'] as List<dynamic>? ?? [];
    return list
        .map((e) => StayModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
