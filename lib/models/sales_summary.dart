class SalesSummary {
  final double totalSales;
  final double totalPaid;
  final double totalDue;
  final int salesCount;
  final double averageSale;
  final int paidSales;
  final int unpaidSales;
  final int partialSales;

  SalesSummary({
    required this.totalSales,
    required this.totalPaid,
    required this.totalDue,
    required this.salesCount,
    required this.averageSale,
    required this.paidSales,
    required this.unpaidSales,
    required this.partialSales,
  });

  factory SalesSummary.empty() {
    return SalesSummary(
      totalSales: 0.0,
      totalPaid: 0.0,
      totalDue: 0.0,
      salesCount: 0,
      averageSale: 0.0,
      paidSales: 0,
      unpaidSales: 0,
      partialSales: 0,
    );
  }
}

class ProductSales {
  final int productId;
  final String productName;
  final String category;
  final double totalQuantity;
  final double totalSales;
  final int salesCount;

  ProductSales({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantity,
    required this.totalSales,
    required this.salesCount,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({
    required this.start,
    required this.end,
  });
}

class ItemWiseSalesData {
  final int invoiceNo;
  final DateTime date;
  final String itemName;
  final double saleQty;
  final double purchasePrice;
  final double salePrice;
  final double totalAmount;
  final double profit;
  final bool isStockMovement;
  final double stockIncreaseQty;
  final double stockDecreaseQty;
  final String? movementReason;
  final String? reference;

  ItemWiseSalesData({
    required this.invoiceNo,
    required this.date,
    required this.itemName,
    required this.saleQty,
    required this.purchasePrice,
    required this.salePrice,
    required this.totalAmount,
    required this.profit,
    this.isStockMovement = false,
    this.stockIncreaseQty = 0,
    this.stockDecreaseQty = 0,
    this.movementReason,
    this.reference,
  });
}
