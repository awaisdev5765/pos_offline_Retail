class LicenseModel {
  final String id;
  final String month;
  final String year;
  final String code;
  final String planType;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;

  LicenseModel({
    required this.id,
    required this.month,
    required this.year,
    required this.code,
    this.planType = 'monthly',
    this.isActive = false,
    required this.createdAt,
    this.activatedAt,
    this.expiresAt,
  });

  LicenseModel copyWith({
    String? id,
    String? month,
    String? year,
    String? code,
    String? planType,
    bool? isActive,
    DateTime? createdAt,
    DateTime? activatedAt,
    DateTime? expiresAt,
  }) {
    return LicenseModel(
      id: id ?? this.id,
      month: month ?? this.month,
      year: year ?? this.year,
      code: code ?? this.code,
      planType: planType ?? this.planType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month,
      'year': year,
      'code': code,
      'planType': planType,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'activatedAt': activatedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    return LicenseModel(
      id: json['id'] ?? '',
      month: json['month'] ?? '',
      year: json['year'] ?? '',
      code: json['code'] ?? '',
      planType: json['planType'] ?? 'monthly',
      isActive: json['isActive'] ?? false,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      activatedAt: json['activatedAt'] != null
          ? DateTime.parse(json['activatedAt'])
          : null,
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValid {
    return isActive && !isExpired;
  }

  String get displayName {
    if (planType == 'lifetime') return 'Lifetime';
    if (planType == 'yearly') return '1 Year License';
    return '$month $year';
  }
}

class LicenseStatus {
  final bool isValid;
  final String? currentMonth;
  final String? currentYear;
  final DateTime? expiresAt;
  final String? message;
  final bool needsActivation;

  LicenseStatus({
    required this.isValid,
    this.currentMonth,
    this.currentYear,
    this.expiresAt,
    this.message,
    this.needsActivation = false,
  });

  static LicenseStatus valid() {
    return LicenseStatus(
      isValid: true,
      message: 'License is valid',
    );
  }

  static LicenseStatus expired() {
    return LicenseStatus(
      isValid: false,
      message: 'License has expired. Please enter a new valid license code.',
      needsActivation: true,
    );
  }

  static LicenseStatus invalid() {
    return LicenseStatus(
      isValid: false,
      message: 'Invalid license code. Please check and try again.',
      needsActivation: true,
    );
  }

  static LicenseStatus requiresActivation() {
    return LicenseStatus(
      isValid: false,
      message: 'Please activate your license with a valid code.',
      needsActivation: true,
    );
  }
}
