import 'package:flutter/cupertino.dart';

@immutable
class User {
  final String email;
  final bool isAdmin;

  const User({required this.email, this.isAdmin = false});
}
