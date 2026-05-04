class EmailRequest {
  final String email;

  EmailRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}
