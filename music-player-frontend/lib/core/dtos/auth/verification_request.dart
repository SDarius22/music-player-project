class VerificationRequest {
  final String email;
  final String code;

  VerificationRequest({required this.email, required this.code});

  Map<String, dynamic> toJson() => {'email': email, 'code': code};
}
