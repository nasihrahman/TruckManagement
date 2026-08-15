import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/driver.dart';
import '../models/expense.dart';
import '../models/truck.dart';
import '../models/owner.dart';

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

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
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
    await saveTokens(body['accessToken'], body['refreshToken']);
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
    required String origin,
    required String destination,
    String? driverId,
    String? truckId,
    DateTime? scheduledAt,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl/trips'),
        headers: headers,
        body: jsonEncode({
          'origin': origin,
          'destination': destination,
          if (driverId != null) 'driverId': driverId,
          if (truckId != null) 'truckId': truckId,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
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
    String? origin,
    String? destination,
    String? driverId,
    String? truckId,
    DateTime? scheduledAt,
  }) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: headers,
        body: jsonEncode({
          if (origin != null) 'origin': origin,
          if (destination != null) 'destination': destination,
          if (driverId != null) 'driverId': driverId,
          if (truckId != null) 'truckId': truckId,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
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

  Future<Uint8List> exportTripsExcel() async {
    final response = await _send(
      (headers) => http.get(Uri.parse('$baseUrl/trips/export.xlsx'), headers: headers),
    );
    if (response.statusCode >= 400) {
      throw Exception('Unable to export trips');
    }
    return response.bodyBytes;
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
