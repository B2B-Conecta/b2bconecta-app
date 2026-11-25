class CombinedMinimum {
  const CombinedMinimum({
    required this.id,
    required this.name,
    required this.units,
  });

  final String id;
  final String name;
  final int units;

  String get catalogLabel => 'Mín. $units uds combinables';

  static CombinedMinimum? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final name = value['name'];
    final units = value['minimum_units'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        units is! int ||
        units < 2) {
      return null;
    }
    return CombinedMinimum(id: id, name: name.trim(), units: units);
  }
}
