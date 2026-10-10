import 'package:dio/dio.dart';
import 'api_constants.dart';
import 'dio_client.dart';

enum HttpMethod { get, post, put, delete, patch }

class ApiResponse {
  final bool isSuccess;
  final int? statusCode;
  final dynamic data;
  final String? errorMessage;

  ApiResponse({required this.isSuccess, this.statusCode, this.data, this.errorMessage});

  factory ApiResponse.success(dynamic data, {int? statusCode}) {
    return ApiResponse(isSuccess: true, statusCode: statusCode, data: data);
  }

  factory ApiResponse.failure(String errorMessage, {int? statusCode}) {
    return ApiResponse(isSuccess: false, statusCode: statusCode, errorMessage: errorMessage);
  }
}

class ApiService {
  final DioClient _dioClient;

  ApiService({DioClient? dioClient}) : _dioClient = dioClient ?? DioClient();

  /// Generic request executor that takes [endpoint], [method], [data], [queryParameters], and [headers]
  Future<ApiResponse> request({
    required String endpoint,
    required HttpMethod method,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? token,
  }) async {
    try {
      final dio = _dioClient.dio;

      final activeToken = (token != null && token.isNotEmpty) ? token : ApiConstants.defaultDevToken;

      final options = Options(
        method: method.name.toUpperCase(),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $activeToken',
          if (headers != null) ...headers,
        },
      );

      final response = await dio.request(endpoint, data: data, queryParameters: queryParameters, options: options);

      return ApiResponse.success(response.data, statusCode: response.statusCode);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Convenience GET request
  Future<ApiResponse> get(String endpoint, {Map<String, dynamic>? queryParameters, Map<String, String>? headers, String? token}) {
    return request(endpoint: endpoint, method: HttpMethod.get, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience POST request
  Future<ApiResponse> post(String endpoint, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, String>? headers, String? token}) {
    return request(endpoint: endpoint, method: HttpMethod.post, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience PUT request
  Future<ApiResponse> put(String endpoint, {dynamic data, Map<String, dynamic>? queryParameters, Map<String, String>? headers, String? token}) {
    return request(endpoint: endpoint, method: HttpMethod.put, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience DELETE request
  Future<ApiResponse> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? token,
  }) {
    return request(endpoint: endpoint, method: HttpMethod.delete, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  // Convenience PATCH request
  Future<ApiResponse> patch(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? token,
  }) {
    return request(endpoint: endpoint, method: HttpMethod.patch, data: data, queryParameters: queryParameters, headers: headers, token: token);
  }

  ApiResponse _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiResponse.failure('Connection timed out. Please check your internet connection.', statusCode: error.response?.statusCode);
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final serverMessage = error.response?.data?['message'] ?? error.response?.statusMessage ?? 'Server error occurred';
        return ApiResponse.failure('[$statusCode] $serverMessage', statusCode: statusCode);
      case DioExceptionType.cancel:
        return ApiResponse.failure('Request was cancelled.');
      case DioExceptionType.connectionError:
        return ApiResponse.failure('No internet connection available.');
      default:
        return ApiResponse.failure('Something went wrong. Please try again.');
    }
  }
}
