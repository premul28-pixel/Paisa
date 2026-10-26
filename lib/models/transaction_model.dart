class TransactionModel {
  final int? id;
  final String type; // 'income' or 'expense'
  final double amount;
  final DateTime date;
  final String? source; // Used when type == 'income'
  final String? category; // Used when type == 'expense'
  final String paymentMethod; // 'Cash' or 'UPI'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.source,
    this.category,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convenient helper to check if this is an income transaction
  bool get isIncome => type.toLowerCase() == 'income';

  /// Convenient helper to check if this is an expense transaction
  bool get isExpense => type.toLowerCase() == 'expense';

  /// Factory constructor to create a TransactionModel from an SQLite map.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      source: map['source'] as String?,
      category: map['category'] as String?,
      paymentMethod: map['payment_method'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Converts the TransactionModel into a Map suitable for SQLite operations.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'source': source,
      'category': category,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Creates a copy of this TransactionModel with updated fields.
  TransactionModel copyWith({
    int? id,
    String? type,
    double? amount,
    DateTime? date,
    String? source,
    String? category,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      source: source ?? this.source,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, type: $type, amount: $amount, date: $date, source: $source, category: $category, paymentMethod: $paymentMethod, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel &&
        other.id == id &&
        other.type == type &&
        other.amount == amount &&
        other.date == date &&
        other.source == source &&
        other.category == category &&
        other.paymentMethod == paymentMethod &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
        id,
        type,
        amount,
        date,
        source,
        category,
        paymentMethod,
        notes,
      );
}
