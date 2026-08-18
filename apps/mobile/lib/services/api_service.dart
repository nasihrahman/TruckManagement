import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/driver.dart';
import '../models/expense.dart';
import '../models/truck.dart';
import '../models/owner.dart';
import '../models/material.dart';
import '../models/supplier.dart';
import '../models/hitachi_job.dart';

class ApiService {
  ApiService({required this.baseUrl});

  final String baseUrl;
  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshFuture;

  /// Called when the refresh token is missing/invalid and the user needs to log in again.
  void Function()? onSessionExpired;

  Future<void> _loadTokens() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> saveTokens(
    String accessToken,
    String refreshToken, {
    String? role,
    bool? mustChangePassword,
  }) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    if (role != null) await prefs.setString('user_role', role);
    if (mustChangePassword != null) await prefs.setBool('must_change_password', mustChangePassword);
  }

  /// Whether a saved session exists on this device — checked at app startup
  /// so a valid login survives an app restart / page reload instead of
  /// always bouncing back to the login screen.
  Future<bool> hasStoredSession() async {
    await _loadTokens();
    return _refreshToken != null;
  }

  Future<String?> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<bool> getStoredMustChangePassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('must_change_password') ?? false;
  }

  Future<void> markPasswordChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('must_change_password', false);
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
    await prefs.remove('must_change_password');
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    if (auth) {
      await _loadTokens();
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Sends an authenticated request, transparently refreshing the access token
  /// and retrying once if the server responds 401 (access token expired).
  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) requestFn, {
    bool auth = true,
  }) async {
    var headers = await _headers(auth: auth);
    var response = await requestFn(headers);
    if (auth && response.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        headers = await _headers(auth: auth);
        response = await requestFn(headers);
      } else {
        onSessionExpired?.call();
      }
    }
    return response;
  }

  /// Guesses an image MIME type from a filename extension. `MultipartFile`
  /// defaults to `application/octet-stream` when no contentType is given,
  /// which the backend's image-only filter rejects — so this can't be skipped.
  MediaType _imageMediaType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'gif':
        return MediaType('image', 'gif');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  /// Uploads an image (already compressed client-side by the caller) and
  /// returns its hosted URL. Built separately from `_send` since multipart
  /// requests need their own Content-Type (with boundary), not the JSON one
  /// `_headers` always sets.
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    Future<http.StreamedResponse> attempt() async {
      await _loadTokens();
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _imageMediaType(filename),
      ));
      return request.send();
    }

    var streamed = await attempt();
    if (streamed.statusCode == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        streamed = await attempt();
      } else {
        onSessionExpired?.call();
      }
    }
    final response = await http.Response.fromStream(streamed);
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Image upload failed');
    }
    return body['url'] as String;
  }

  Future<bool> _refreshAccessToken() {
    return _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<bool> _doRefresh() async {
    await _loadTokens();
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode >= 400) {
        await clearToken();
        return false;
      }
      final body = jsonDecode(response.body);
      await saveTokens(body['accessToken'], body['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'emailOrPhone': email, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Login failed');
    }
    await saveTokens(
      body['accessToken'],
      body['refreshToken'],
      role: body['role']?.toString(),
      mustChangePassword: body['mustChangePassword'] == true,
    );
    return body;
  }

  Future<List<Trip>> fetchTrips() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/trips'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch trips');
    }
    if (data is List) {
      return data.map((item) => Trip.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Trip> createTrip({
    String? driverId,
    String? truckId,
    DateTime? scheduledAt,
    String? materialId,
    String? supplierId,
    double? qtyCf,
    String? customerName,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/trips'),
        headers: headers,
        body: jsonEncode({
          if (driverId != null) 'driverId': driverId,
          if (truckId != null) 'truckId': truckId,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
          if (materialId != null) 'materialId': materialId,
          if (supplierId != null) 'supplierId': supplierId,
          if (qtyCf != null) 'qtyCf': qtyCf,
          if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create trip');
    }
    return Trip.fromJson(body);
  }

  Future<Trip> updateTrip(
    String tripId, {
    String? driverId,
    String? truckId,
    DateTime? scheduledAt,
    String? materialId,
    String? supplierId,
    double? qtyCf,
    String? customerName,
  }) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: headers,
        body: jsonEncode({
          if (driverId != null) 'driverId': driverId,
          if (truckId != null) 'truckId': truckId,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
          if (materialId != null) 'materialId': materialId,
          if (supplierId != null) 'supplierId': supplierId,
          if (qtyCf != null) 'qtyCf': qtyCf,
          if (customerName != null) 'customerName': customerName,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to update trip');
    }
    return Trip.fromJson(body);
  }

  Future<Trip> updateTripStatus(String tripId, String status) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/trips/$tripId/status'),
        headers: headers,
        body: jsonEncode({'status': status}),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to update trip status');
    }
    return Trip.fromJson(body);
  }

  Future<void> deleteTrip(String tripId) async {
    final response = await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/trips/$tripId'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to delete trip');
    }
  }

  Future<List<CargoMaterial>> fetchCargoMaterials() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/materials'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch materials');
    }
    if (data is List) {
      return data.map((item) => CargoMaterial.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<CargoMaterial> createCargoMaterial(String name) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/materials'),
        headers: headers,
        body: jsonEncode({'name': name}),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create material');
    }
    return CargoMaterial.fromJson(body);
  }

  Future<void> deleteCargoMaterial(String id) async {
    final response = await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/materials/$id'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Unable to delete material');
    }
  }

  Future<List<String>> fetchTripCustomerNames() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/trips/customer-names'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch customer names');
    }
    if (data is List) {
      return data.map((item) => item.toString()).toList();
    }
    return [];
  }

  Future<List<Supplier>> fetchSuppliers() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/suppliers'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch suppliers');
    }
    if (data is List) {
      return data.map((item) => Supplier.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Supplier> createSupplier(String name) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/suppliers'),
        headers: headers,
        body: jsonEncode({'name': name}),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create supplier');
    }
    return Supplier.fromJson(body);
  }

  Future<void> deleteSupplier(String id) async {
    final response = await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/suppliers/$id'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Unable to delete supplier');
    }
  }

  Future<Uint8List> exportTripsByTruckExcel({String? period, DateTime? date}) async {
    final query = {
      if (period != null) 'period': period,
      if (date != null) 'date': date.toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/trips/export-by-truck.xlsx').replace(queryParameters: query.isEmpty ? null : query);
    final response = await _send((headers) => http.get(uri, headers: headers));
    if (response.statusCode >= 400) {
      throw Exception('Unable to export trips by truck');
    }
    return response.bodyBytes;
  }

  Future<List<Driver>> fetchDrivers() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/drivers'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch drivers');
    }
    if (data is List) {
      return data.map((item) => Driver.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<Truck>> fetchTrucks() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/trucks'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch trucks');
    }
    if (data is List) {
      return data.map((item) => Truck.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Truck> createTruck({required String plate, required String brand, String? vin}) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/trucks'),
        headers: headers,
        body: jsonEncode({
          'plate': plate,
          'brand': brand,
          if (vin != null && vin.isNotEmpty) 'vin': vin,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create truck');
    }
    return Truck.fromJson(body);
  }

  Future<Truck> updateTruck(String id, {required String plate, required String brand, String? vin}) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/trucks/$id'),
        headers: headers,
        body: jsonEncode({
          'plate': plate,
          'brand': brand,
          if (vin != null && vin.isNotEmpty) 'vin': vin,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to update truck');
    }
    return Truck.fromJson(body);
  }

  Future<void> deleteTruck(String id) async {
    final response = await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/trucks/$id'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Unable to delete truck');
    }
  }

  Future<Map<String, dynamic>> createDriver({
    required String name,
    required String phone,
    String? email,
    String? licenseNumber,
    String? initialPassword,
    String? defaultTruckId,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/drivers'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'licenseNumber': licenseNumber,
          'initialPassword': initialPassword,
          if (defaultTruckId != null) 'defaultTruckId': defaultTruckId,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create driver');
    }
    return body;
  }

  Future<Driver> updateDriver(
    String id, {
    required String name,
    required String phone,
    String? email,
    String? licenseNumber,
    String? defaultTruckId,
  }) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/drivers/$id'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'licenseNumber': licenseNumber,
          if (defaultTruckId != null) 'defaultTruckId': defaultTruckId,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to update driver');
    }
    return Driver.fromJson(body);
  }

  Future<void> deactivateDriver(String id) async {
    final response = await _send(
      (headers) => http.patch(Uri.parse('$baseUrl/drivers/$id/deactivate'), headers: headers),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to deactivate driver');
    }
  }

  Future<void> reactivateDriver(String id) async {
    final response = await _send(
      (headers) => http.patch(Uri.parse('$baseUrl/drivers/$id/reactivate'), headers: headers),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to reactivate driver');
    }
  }

  Future<String> resetDriverPassword(String id) async {
    final response = await _send(
      (headers) => http.patch(Uri.parse('$baseUrl/drivers/$id/reset-password'), headers: headers),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to reset password');
    }
    return body['tempPassword'] as String;
  }

  Future<List<Owner>> fetchOwners() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/owners'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch owners');
    }
    if (data is List) {
      return data.map((item) => Owner.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<String> createOwner({
    required String name,
    required String phone,
    String? email,
    String? initialPassword,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/owners'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          if (initialPassword != null && initialPassword.isNotEmpty) 'initialPassword': initialPassword,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create owner');
    }
    return body['tempPassword'] as String;
  }

  Future<void> goOnline() async {
    final response = await _send(
      (headers) => http.post(Uri.parse('$baseUrl/drivers/me/go-online'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to go online');
    }
  }

  Future<void> goOffline() async {
    final response = await _send(
      (headers) => http.post(Uri.parse('$baseUrl/drivers/me/go-offline'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to go offline');
    }
  }

  Future<Map<String, dynamic>> fetchMyDriverProfile() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/drivers/me'), headers: headers),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to load profile');
    }
    return body as Map<String, dynamic>;
  }

  Future<void> pingLocation(double latitude, double longitude) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/drivers/me/location'),
        headers: headers,
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      ),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to send location');
    }
  }

  Future<List<Map<String, dynamic>>> fetchOnlineLocations() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/drivers/online-locations'), headers: headers),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception('Unable to load online drivers');
    }
    return (body as List).cast<Map<String, dynamic>>();
  }

  Future<void> changePassword(String newPassword) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: headers,
        body: jsonEncode({'newPassword': newPassword}),
      ),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to update password');
    }
  }

  Future<Map<String, dynamic>> fetchOperationsReport({required String period, DateTime? date}) async {
    final query = {
      'period': period,
      if (date != null) 'date': date.toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/reports/operations').replace(queryParameters: query);
    final response = await _send((headers) => http.get(uri, headers: headers));
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to load report');
    }
    return body as Map<String, dynamic>;
  }

  Future<Uint8List> exportOperationsReport({required String period, DateTime? date}) async {
    final query = {
      'period': period,
      if (date != null) 'date': date.toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/reports/operations.xlsx').replace(queryParameters: query);
    final response = await _send((headers) => http.get(uri, headers: headers));
    if (response.statusCode >= 400) {
      throw Exception('Unable to export report');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> exportOperationsDetail({required String period, DateTime? date}) async {
    final query = {
      'period': period,
      if (date != null) 'date': date.toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/reports/operations-detail.xlsx').replace(queryParameters: query);
    final response = await _send((headers) => http.get(uri, headers: headers));
    if (response.statusCode >= 400) {
      throw Exception('Unable to export report');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> exportTripsExcel() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/trips/export.xlsx'), headers: headers),
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to export trips');
    }
    return response.bodyBytes;
  }

  Future<List<HitachiJob>> fetchHitachiJobs() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/hitachi-jobs'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch Hitachi jobs');
    }
    if (data is List) {
      return data.map((item) => HitachiJob.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Map<String, dynamic> _hitachiJobBody({
    required DateTime date,
    String? customerName,
    String? place,
    double? totalHours,
    double? paymentReceived,
    HitachiPayer? paymentReceivedBy,
    double? nDieselExpense,
    HitachiPayer? nDieselPaidBy,
    double? hDieselExpense,
    HitachiPayer? hDieselPaidBy,
    double? opBata,
    HitachiPayer? opBataPaidBy,
    double? otherExpenseM,
    double? otherExpenseJ,
    double? salaryAdvance,
    String? photoUrl,
  }) {
    return {
      'date': date.toIso8601String(),
      if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
      if (place != null && place.isNotEmpty) 'place': place,
      if (totalHours != null) 'totalHours': totalHours,
      if (paymentReceived != null) 'paymentReceived': paymentReceived,
      if (paymentReceivedBy != null) 'paymentReceivedBy': hitachiPayerToJson(paymentReceivedBy),
      if (nDieselExpense != null) 'nDieselExpense': nDieselExpense,
      if (nDieselPaidBy != null) 'nDieselPaidBy': hitachiPayerToJson(nDieselPaidBy),
      if (hDieselExpense != null) 'hDieselExpense': hDieselExpense,
      if (hDieselPaidBy != null) 'hDieselPaidBy': hitachiPayerToJson(hDieselPaidBy),
      if (opBata != null) 'opBata': opBata,
      if (opBataPaidBy != null) 'opBataPaidBy': hitachiPayerToJson(opBataPaidBy),
      if (otherExpenseM != null) 'otherExpenseM': otherExpenseM,
      if (otherExpenseJ != null) 'otherExpenseJ': otherExpenseJ,
      if (salaryAdvance != null) 'salaryAdvance': salaryAdvance,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    };
  }

  Future<HitachiJob> createHitachiJob({
    required DateTime date,
    String? customerName,
    String? place,
    double? totalHours,
    double? paymentReceived,
    HitachiPayer? paymentReceivedBy,
    double? nDieselExpense,
    HitachiPayer? nDieselPaidBy,
    double? hDieselExpense,
    HitachiPayer? hDieselPaidBy,
    double? opBata,
    HitachiPayer? opBataPaidBy,
    double? otherExpenseM,
    double? otherExpenseJ,
    double? salaryAdvance,
    String? photoUrl,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/hitachi-jobs'),
        headers: headers,
        body: jsonEncode(_hitachiJobBody(
          date: date,
          customerName: customerName,
          place: place,
          totalHours: totalHours,
          paymentReceived: paymentReceived,
          paymentReceivedBy: paymentReceivedBy,
          nDieselExpense: nDieselExpense,
          nDieselPaidBy: nDieselPaidBy,
          hDieselExpense: hDieselExpense,
          hDieselPaidBy: hDieselPaidBy,
          opBata: opBata,
          opBataPaidBy: opBataPaidBy,
          otherExpenseM: otherExpenseM,
          otherExpenseJ: otherExpenseJ,
          salaryAdvance: salaryAdvance,
          photoUrl: photoUrl,
        )),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to log Hitachi job');
    }
    return HitachiJob.fromJson(body);
  }

  Future<HitachiJob> updateHitachiJob(
    String id, {
    required DateTime date,
    String? customerName,
    String? place,
    double? totalHours,
    double? paymentReceived,
    HitachiPayer? paymentReceivedBy,
    double? nDieselExpense,
    HitachiPayer? nDieselPaidBy,
    double? hDieselExpense,
    HitachiPayer? hDieselPaidBy,
    double? opBata,
    HitachiPayer? opBataPaidBy,
    double? otherExpenseM,
    double? otherExpenseJ,
    double? salaryAdvance,
    String? photoUrl,
  }) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/hitachi-jobs/$id'),
        headers: headers,
        body: jsonEncode(_hitachiJobBody(
          date: date,
          customerName: customerName,
          place: place,
          totalHours: totalHours,
          paymentReceived: paymentReceived,
          paymentReceivedBy: paymentReceivedBy,
          nDieselExpense: nDieselExpense,
          nDieselPaidBy: nDieselPaidBy,
          hDieselExpense: hDieselExpense,
          hDieselPaidBy: hDieselPaidBy,
          opBata: opBata,
          opBataPaidBy: opBataPaidBy,
          otherExpenseM: otherExpenseM,
          otherExpenseJ: otherExpenseJ,
          salaryAdvance: salaryAdvance,
          photoUrl: photoUrl,
        )),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to update Hitachi job');
    }
    return HitachiJob.fromJson(body);
  }

  Future<Uint8List> exportHitachiJobs({String? period, DateTime? date}) async {
    final query = {
      if (period != null) 'period': period,
      if (date != null) 'date': date.toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/hitachi-jobs/export.xlsx').replace(queryParameters: query.isEmpty ? null : query);
    final response = await _send((headers) => http.get(uri, headers: headers));
    if (response.statusCode >= 400) {
      throw Exception('Unable to export Hitachi jobs');
    }
    return response.bodyBytes;
  }

  Future<void> deleteHitachiJob(String id) async {
    final response = await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/hitachi-jobs/$id'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Unable to delete Hitachi job');
    }
  }

  Future<List<Expense>> fetchExpenses(String tripId) async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/trips/$tripId/expenses'), headers: headers),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Unable to fetch expenses');
    }
    if (data is List) {
      return data.map((item) => Expense.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Expense> createExpense(
    String tripId, {
    required ExpenseCategory category,
    required double amount,
    int? odometer,
    String? reason,
    String? notes,
    String? photoUrl,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/trips/$tripId/expenses'),
        headers: headers,
        body: jsonEncode({
          'category': expenseCategoryToJson(category),
          'amount': amount,
          if (odometer != null) 'odometer': odometer,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to log expense');
    }
    return Expense.fromJson(body);
  }

  Future<Expense> updateExpense(
    String tripId,
    String expenseId, {
    required ExpenseCategory category,
    required double amount,
    int? odometer,
    String? reason,
    String? notes,
    String? photoUrl,
  }) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'),
        headers: headers,
        body: jsonEncode({
          'category': expenseCategoryToJson(category),
          'amount': amount,
          'odometer': odometer,
          'reason': reason,
          'notes': notes,
          if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        }),
      ),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to update expense');
    }
    return Expense.fromJson(body);
  }

  Future<void> deleteExpense(String tripId, String expenseId) async {
    final response = await _send(
      (headers) => http.delete(Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'), headers: headers),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to delete expense');
    }
  }
}
