class RiderRegisterArgs {
  final String fullName;
  final String phone;
  final String email;

  RiderRegisterArgs({
    required this.fullName,
    required this.phone,
    required this.email,
  });

  RiderRegisterArgs copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? role,
  }) {
    return RiderRegisterArgs(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}
