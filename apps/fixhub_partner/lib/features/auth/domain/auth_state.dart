/// Auth state models for the technician app.
///
/// Uses sealed classes for exhaustive pattern matching.
/// AuthUser includes technician-specific fields (verification, rating, etc.)

class AuthUser {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String role;
  final String? profilePictureUrl;
  final bool? isAvailable;
  final String? verificationStatus;
  final double? rating;
  final int? totalJobs;

  const AuthUser({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.role,
    this.profilePictureUrl,
    this.isAvailable,
    this.verificationStatus,
    this.rating,
    this.totalJobs,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return AuthUser(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String,
      profilePictureUrl: profile?['profilePictureUrl'] as String?,
      isAvailable: profile?['isAvailable'] as bool?,
      verificationStatus: profile?['verificationStatus'] as String?,
      rating: profile?['rating'] != null
          ? double.tryParse(profile!['rating'].toString())
          : null,
      totalJobs: profile?['totalJobs'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'email': email,
    'role': role,
    'profile': {
      'profilePictureUrl': profilePictureUrl,
      'isAvailable': isAvailable,
      'verificationStatus': verificationStatus,
      'rating': rating,
      'totalJobs': totalJobs,
    },
  };

  AuthUser copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? role,
    String? profilePictureUrl,
    bool? isAvailable,
    String? verificationStatus,
    double? rating,
    int? totalJobs,
  }) {
    return AuthUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rating: rating ?? this.rating,
      totalJobs: totalJobs ?? this.totalJobs,
    );
  }

  String get displayName => name ?? email ?? phone;

  bool get isVerified => verificationStatus == 'VERIFIED';
}

// ── Auth State Sealed Classes ─────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// OTP has been sent, waiting for user to enter it.
class AuthOtpSent extends AuthState {
  final String email;
  final String? devOtp;
  const AuthOtpSent({required this.email, this.devOtp});
}

/// OTP submitted, awaiting server verification.
class AuthVerifying extends AuthState {
  final String email;
  const AuthVerifying({required this.email});
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  final String? email; // Preserve email so user can retry
  const AuthError(this.message, {this.email});
}
