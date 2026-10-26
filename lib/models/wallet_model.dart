class WalletModel {
  final int? id;
  final String name; // 'Cash' or 'UPI'
  final double balance;

  const WalletModel({
    this.id,
    required this.name,
    required this.balance,
  });

  /// Factory constructor to create a WalletModel from an SQLite map.
  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      balance: (map['balance'] as num).toDouble(),
    );
  }

  /// Converts the WalletModel into a Map for SQLite database operations.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'balance': balance,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Creates a copy of this WalletModel with updated fields.
  WalletModel copyWith({
    int? id,
    String? name,
    double? balance,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
    );
  }

  @override
  String toString() {
    return 'WalletModel(id: $id, name: $name, balance: $balance)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletModel &&
        other.id == id &&
        other.name == name &&
        other.balance == balance;
  }

  @override
  int get hashCode => Object.hash(id, name, balance);
}
