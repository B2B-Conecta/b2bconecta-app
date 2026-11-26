import '../catalog/combined_minimum.dart';
import 'cart_service.dart';

class CartCombinedMinimum {
  const CartCombinedMinimum({
    required this.ownerId,
    required this.rule,
    required this.units,
  });

  final String ownerId;
  final CombinedMinimum rule;
  final int units;

  bool get meets => units >= rule.units;
  int get missing => meets ? 0 : rule.units - units;

  static Iterable<CartCombinedMinimum> forLines(Iterable<CartLine> lines) {
    final groups = <(String, String), CartCombinedMinimum>{};
    for (final line in lines) {
      final rule = line.part.combinedMinimum;
      final owner = line.part.ownerId;
      if (rule == null || owner == null || owner.isEmpty) continue;
      final key = (owner, rule.id);
      final previous = groups[key];
      groups[key] = CartCombinedMinimum(
        ownerId: owner,
        rule: previous != null && previous.rule.units > rule.units
            ? previous.rule
            : rule,
        units: (previous?.units ?? 0) + line.quantity,
      );
    }
    return groups.values;
  }

  static bool meetsLines(Iterable<CartLine> lines) =>
      forLines(lines).every((group) => group.meets);
}
