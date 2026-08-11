import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import '../models/driver.dart';
import '../models/expense.dart';
import '../models/truck.dart';

class ApiService {
  ApiService({required this.baseUrl});

  final String baseUrl;
  String? _token;

  Future<void> _loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<Map<String, String>> _headers({bool auth = false}) async {
    if (auth) {
      await _loadToken();
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
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
    await saveToken(body['accessToken']);
    return body;
  }

  Future<List<Trip>> fetchTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips'),
      headers: await _headers(auth: true),
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
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trips'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        if (driverId != null) 'driverId': driverId,
        if (truckId != null) 'truckId': truckId,
      }),
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
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/trips/$tripId'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        if (origin != null) 'origin': origin,
        if (destination != null) 'destination': destination,
        if (driverId != null) 'driverId': driverId,
        if (truckId != null) 'truckId': truckId,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to update trip');
    }
    return Trip.fromJson(body);
  }

  Future<Trip> updateTripStatus(String tripId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/trips/$tripId/status'),
      headers: await _headers(auth: true),
      body: jsonEncode({'status': status}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to update trip status');
    }
    return Trip.fromJson(body);
  }

  Future<List<Driver>> fetchDrivers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/drivers'),
      headers: await _headers(auth: true),
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
    final response = await http.get(
      Uri.parse('$baseUrl/trucks'),
      headers: await _headers(auth: true),
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
    final response = await http.post(
      Uri.parse('$baseUrl/trucks'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'plate': plate,
        'brand': brand,
        if (vin != null && vin.isNotEmpty) 'vin': vin,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to create truck');
    }
    return Truck.fromJson(body);
  }

  Future<Truck> updateTruck(String id, {required String plate, required String brand, String? vin}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/trucks/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'plate': plate,
        'brand': brand,
        if (vin != null && vin.isNotEmpty) 'vin': vin,
      }),
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
    final response = await http.post(
      Uri.parse('$baseUrl/drivers'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'licenseNumber': licenseNumber,
        'initialPassword': initialPassword,
        if (defaultTruckId != null) 'defaultTruckId': defaultTruckId,
      }),
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
    final response = await http.patch(
      Uri.parse('$baseUrl/drivers/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'licenseNumber': licenseNumber,
        if (defaultTruckId != null) 'defaultTruckId': defaultTruckId,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Unable to update driver');
    }
    return Driver.fromJson(body);
  }

  Future<void> deactivateDriver(String id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/drivers/$id/deactivate'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to deactivate driver');
    }
  }

  Future<void> reactivateDriver(String id) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/drivers/$id/reactivate'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode >= 400) {
      throw Exception('Failed to reactivate driver');
    }
  }

  Future<void> goOnline() async {
    final response = await http.post(
      Uri.parse('$baseUrl/drivers/me/go-online'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to go online');
    }
  }

  Future<void> goOffline() async {
    final response = await http.post(
      Uri.parse('$baseUrl/drivers/me/go-offline'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to go offline');
    }
  }

  Future<void> changePassword(String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: await _headers(auth: true),
      body: jsonEncode({'newPassword': newPassword}),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to update password');
    }
  }

  Future<List<Expense>> fetchExpenses(String tripId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/trips/$tripId/expenses'),
      headers: await _headers(auth: true),
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
    final response = await http.post(
      Uri.parse('$baseUrl/trips/$tripId/expenses'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'category': expenseCategoryToJson(category),
        'amount': amount,
        if (odometer != null) 'odometer': odometer,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
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
    final response = await http.patch(
      Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'category': expenseCategoryToJson(category),
        'amount': amount,
        'odometer': odometer,
        'reason': reason,
        'notes': notes,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Failed to update expense');
    }
    return Expense.fromJson(body);
  }

  Future<void> deleteExpense(String tripId, String expenseId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'),
      headers: await _headers(auth: true),
    );
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to delete expense');
    }
  }
}