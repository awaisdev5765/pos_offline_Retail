class ReceiptTemplate {
  final String id;
  final String name;
  final String? logoUrl;
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String businessEmail;
  final String? website;
  final String? taxId;
  final String? licenseNumber;
  final String? footerText;
  final bool showLogo;
  final bool showBusinessInfo;
  final bool showCustomerInfo;
  final bool showItemDetails;
  final bool showTaxBreakdown;
  final bool showPaymentInfo;
  final bool showFooter;
  final bool showQRCode;
  final String? customField1Label;
  final String? customField1Value;
  final String? customField2Label;
  final String? customField2Value;
  final String? customField3Label;
  final String? customField3Value;
  final double logoHeight;
  final double logoWidth;
  final int fontSize;
  final String fontFamily;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReceiptTemplate({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.businessEmail,
    this.website,
    this.taxId,
    this.licenseNumber,
    this.footerText,
    this.showLogo = true,
    this.showBusinessInfo = true,
    this.showCustomerInfo = true,
    this.showItemDetails = true,
    this.showTaxBreakdown = true,
    this.showPaymentInfo = true,
    this.showFooter = true,
    this.showQRCode = false,
    this.customField1Label,
    this.customField1Value,
    this.customField2Label,
    this.customField2Value,
    this.customField3Label,
    this.customField3Value,
    this.logoHeight = 60.0,
    this.logoWidth = 200.0,
    this.fontSize = 12,
    this.fontFamily = 'monospace',
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  ReceiptTemplate copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? website,
    String? taxId,
    String? licenseNumber,
    String? footerText,
    bool? showLogo,
    bool? showBusinessInfo,
    bool? showCustomerInfo,
    bool? showItemDetails,
    bool? showTaxBreakdown,
    bool? showPaymentInfo,
    bool? showFooter,
    bool? showQRCode,
    String? customField1Label,
    String? customField1Value,
    String? customField2Label,
    String? customField2Value,
    String? customField3Label,
    String? customField3Value,
    double? logoHeight,
    double? logoWidth,
    int? fontSize,
    String? fontFamily,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReceiptTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      businessEmail: businessEmail ?? this.businessEmail,
      website: website ?? this.website,
      taxId: taxId ?? this.taxId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      footerText: footerText ?? this.footerText,
      showLogo: showLogo ?? this.showLogo,
      showBusinessInfo: showBusinessInfo ?? this.showBusinessInfo,
      showCustomerInfo: showCustomerInfo ?? this.showCustomerInfo,
      showItemDetails: showItemDetails ?? this.showItemDetails,
      showTaxBreakdown: showTaxBreakdown ?? this.showTaxBreakdown,
      showPaymentInfo: showPaymentInfo ?? this.showPaymentInfo,
      showFooter: showFooter ?? this.showFooter,
      showQRCode: showQRCode ?? this.showQRCode,
      customField1Label: customField1Label ?? this.customField1Label,
      customField1Value: customField1Value ?? this.customField1Value,
      customField2Label: customField2Label ?? this.customField2Label,
      customField2Value: customField2Value ?? this.customField2Value,
      customField3Label: customField3Label ?? this.customField3Label,
      customField3Value: customField3Value ?? this.customField3Value,
      logoHeight: logoHeight ?? this.logoHeight,
      logoWidth: logoWidth ?? this.logoWidth,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'website': website,
      'taxId': taxId,
      'licenseNumber': licenseNumber,
      'footerText': footerText,
      'showLogo': showLogo,
      'showBusinessInfo': showBusinessInfo,
      'showCustomerInfo': showCustomerInfo,
      'showItemDetails': showItemDetails,
      'showTaxBreakdown': showTaxBreakdown,
      'showPaymentInfo': showPaymentInfo,
      'showFooter': showFooter,
      'showQRCode': showQRCode,
      'customField1Label': customField1Label,
      'customField1Value': customField1Value,
      'customField2Label': customField2Label,
      'customField2Value': customField2Value,
      'customField3Label': customField3Label,
      'customField3Value': customField3Value,
      'logoHeight': logoHeight,
      'logoWidth': logoWidth,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReceiptTemplate.fromJson(Map<String, dynamic> json) {
    return ReceiptTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logoUrl: json['logoUrl'],
      businessName: json['businessName'] ?? '',
      businessAddress: json['businessAddress'] ?? '',
      businessPhone: json['businessPhone'] ?? '',
      businessEmail: json['businessEmail'] ?? '',
      website: json['website'],
      taxId: json['taxId'],
      licenseNumber: json['licenseNumber'],
      footerText: json['footerText'],
      showLogo: json['showLogo'] ?? true,
      showBusinessInfo: json['showBusinessInfo'] ?? true,
      showCustomerInfo: json['showCustomerInfo'] ?? true,
      showItemDetails: json['showItemDetails'] ?? true,
      showTaxBreakdown: json['showTaxBreakdown'] ?? true,
      showPaymentInfo: json['showPaymentInfo'] ?? true,
      showFooter: json['showFooter'] ?? true,
      showQRCode: json['showQRCode'] ?? false,
      customField1Label: json['customField1Label'],
      customField1Value: json['customField1Value'],
      customField2Label: json['customField2Label'],
      customField2Value: json['customField2Value'],
      customField3Label: json['customField3Label'],
      customField3Value: json['customField3Value'],
      logoHeight: (json['logoHeight'] ?? 60.0).toDouble(),
      logoWidth: (json['logoWidth'] ?? 200.0).toDouble(),
      fontSize: json['fontSize'] ?? 12,
      fontFamily: json['fontFamily'] ?? 'monospace',
      isDefault: json['isDefault'] ?? false,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  static ReceiptTemplate getDefault() {
    final now = DateTime.now();
    return ReceiptTemplate(
      id: 'default',
      name: 'Default Template',
      businessName: 'Your Business Name',
      businessAddress: 'Your Business Address',
      businessPhone: 'Your Phone Number',
      businessEmail: 'your@email.com',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}
