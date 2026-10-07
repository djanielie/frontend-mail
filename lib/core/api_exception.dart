class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.code = 'REQUEST_FAILED'});

  final String message;
  final int status;
  final String code;

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}
