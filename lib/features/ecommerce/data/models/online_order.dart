class OnlineOrder {
  final int id;
  final String customerName;
  final String customerEmail;
  final String shippingAddress;
  final List<OrderItem> items;
  final double total;
  final DateTime placedDate;
  final OrderStatus status;

  OnlineOrder({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.shippingAddress,
    required this.items,
    required this.total,
    required this.placedDate,
    required this.status,
  });
}

class OrderItem {
  final int id;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });
}

enum OrderStatus { pending, shipped, delivered, cancelled }