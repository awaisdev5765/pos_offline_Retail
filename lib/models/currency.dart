class Currency {
  final String code;
  final String name;
  final String symbol;
  final double rate; // Exchange rate to USD

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.rate,
  });

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  /// One entry per ISO code (the raw [currencies] list may repeat codes).
  static List<Currency> get uniqueCurrencies {
    final seen = <String>{};
    return [
      for (final c in currencies)
        if (seen.add(c.code)) c,
    ];
  }

  static bool matchesSearch(Currency c, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.code.toLowerCase().contains(q) ||
        c.name.toLowerCase().contains(q) ||
        c.symbol.toLowerCase().contains(q);
  }

  static const List<Currency> currencies = [
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$', rate: 1.0),
    Currency(code: 'EUR', name: 'Euro', symbol: '€', rate: 0.85),
    Currency(code: 'GBP', name: 'British Pound', symbol: '£', rate: 0.73),
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', rate: 83.0),
    Currency(code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', rate: 280.0),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', rate: 110.0),
    Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', rate: 1.25),
    Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', rate: 1.35),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', rate: 0.92),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', rate: 6.45),
    Currency(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', rate: 1.35),
    Currency(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$', rate: 7.8),
    Currency(code: 'KRW', name: 'South Korean Won', symbol: '₩', rate: 1200.0),
    Currency(code: 'THB', name: 'Thai Baht', symbol: '฿', rate: 33.0),
    Currency(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', rate: 4.2),
    Currency(
        code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', rate: 14000.0),
    Currency(code: 'PHP', name: 'Philippine Peso', symbol: '₱', rate: 50.0),
    Currency(code: 'VND', name: 'Vietnamese Dong', symbol: '₫', rate: 23000.0),
    Currency(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', rate: 3.67),
    Currency(code: 'SAR', name: 'Saudi Riyal', symbol: 'ر.س', rate: 3.75),
    Currency(code: 'QAR', name: 'Qatari Riyal', symbol: 'ر.ق', rate: 3.64),
    Currency(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', rate: 0.30),
    Currency(code: 'BHD', name: 'Bahraini Dinar', symbol: 'د.ب', rate: 0.38),
    Currency(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع', rate: 0.38),
    Currency(code: 'JOD', name: 'Jordanian Dinar', symbol: 'د.ا', rate: 0.71),
    Currency(code: 'LBP', name: 'Lebanese Pound', symbol: 'ل.ل', rate: 1500.0),
    Currency(code: 'EGP', name: 'Egyptian Pound', symbol: '£', rate: 30.0),
    Currency(code: 'TRY', name: 'Turkish Lira', symbol: '₺', rate: 8.5),
    Currency(code: 'RUB', name: 'Russian Ruble', symbol: '₽', rate: 75.0),
    Currency(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', rate: 5.2),
    Currency(code: 'MXN', name: 'Mexican Peso', symbol: '\$', rate: 20.0),
    Currency(code: 'HTG', name: 'Haitian Gourde', symbol: 'G', rate: 132.0),
    Currency(code: 'ARS', name: 'Argentine Peso', symbol: '\$', rate: 100.0),
    Currency(code: 'CLP', name: 'Chilean Peso', symbol: '\$', rate: 800.0),
    Currency(code: 'COP', name: 'Colombian Peso', symbol: '\$', rate: 3800.0),
    Currency(code: 'PEN', name: 'Peruvian Sol', symbol: 'S/', rate: 3.7),
    Currency(code: 'UYU', name: 'Uruguayan Peso', symbol: '\$', rate: 45.0),
    Currency(code: 'ZAR', name: 'South African Rand', symbol: 'R', rate: 15.0),
    Currency(code: 'NGN', name: 'Nigerian Naira', symbol: '₦', rate: 410.0),
    Currency(code: 'KES', name: 'Kenyan Shilling', symbol: 'KSh', rate: 110.0),
    Currency(code: 'GHS', name: 'Ghanaian Cedi', symbol: '₵', rate: 6.0),
    Currency(code: 'MAD', name: 'Moroccan Dirham', symbol: 'د.م', rate: 9.0),
    Currency(code: 'TND', name: 'Tunisian Dinar', symbol: 'د.ت', rate: 2.8),
    Currency(code: 'DZD', name: 'Algerian Dinar', symbol: 'د.ج', rate: 135.0),
    Currency(code: 'LYD', name: 'Libyan Dinar', symbol: 'ل.د', rate: 4.5),
    Currency(code: 'ETB', name: 'Ethiopian Birr', symbol: 'Br', rate: 45.0),
    Currency(
        code: 'UGX', name: 'Ugandan Shilling', symbol: 'USh', rate: 3500.0),
    Currency(
        code: 'TZS', name: 'Tanzanian Shilling', symbol: 'TSh', rate: 2300.0),
    Currency(code: 'RWF', name: 'Rwandan Franc', symbol: 'RF', rate: 1000.0),
    Currency(code: 'BIF', name: 'Burundian Franc', symbol: 'FBu', rate: 2000.0),
    Currency(code: 'MWK', name: 'Malawian Kwacha', symbol: 'MK', rate: 800.0),
    Currency(code: 'ZMW', name: 'Zambian Kwacha', symbol: 'ZK', rate: 18.0),
    Currency(code: 'BWP', name: 'Botswana Pula', symbol: 'P', rate: 11.0),
    Currency(code: 'SZL', name: 'Swazi Lilangeni', symbol: 'L', rate: 15.0),
    Currency(code: 'LSL', name: 'Lesotho Loti', symbol: 'L', rate: 15.0),
    Currency(code: 'NAD', name: 'Namibian Dollar', symbol: 'N\$', rate: 15.0),
    Currency(code: 'AOA', name: 'Angolan Kwanza', symbol: 'Kz', rate: 650.0),
    Currency(code: 'MZN', name: 'Mozambican Metical', symbol: 'MT', rate: 60.0),
    Currency(code: 'CDF', name: 'Congolese Franc', symbol: 'FC', rate: 2000.0),
    Currency(
        code: 'XAF',
        name: 'Central African CFA Franc',
        symbol: 'FCFA',
        rate: 550.0),
    Currency(
        code: 'XOF',
        name: 'West African CFA Franc',
        symbol: 'FCFA',
        rate: 550.0),
    Currency(code: 'KMF', name: 'Comorian Franc', symbol: 'CF', rate: 450.0),
    Currency(code: 'DJF', name: 'Djiboutian Franc', symbol: 'Fdj', rate: 180.0),
    Currency(code: 'ERN', name: 'Eritrean Nakfa', symbol: 'Nfk', rate: 15.0),
    Currency(code: 'SOS', name: 'Somali Shilling', symbol: 'S', rate: 580.0),
    Currency(
        code: 'SSP', name: 'South Sudanese Pound', symbol: '£', rate: 130.0),
    Currency(code: 'SDG', name: 'Sudanese Pound', symbol: 'ج.س', rate: 55.0),
    Currency(
        code: 'CVE', name: 'Cape Verdean Escudo', symbol: '\$', rate: 100.0),
    Currency(
        code: 'STN',
        name: 'São Tomé and Príncipe Dobra',
        symbol: 'Db',
        rate: 20.0),
    Currency(code: 'GMD', name: 'Gambian Dalasi', symbol: 'D', rate: 50.0),
    Currency(code: 'GNF', name: 'Guinean Franc', symbol: 'FG', rate: 8500.0),
    Currency(code: 'LRD', name: 'Liberian Dollar', symbol: 'L\$', rate: 150.0),
    Currency(
        code: 'SLL', name: 'Sierra Leonean Leone', symbol: 'Le', rate: 10000.0),
  ];
}
