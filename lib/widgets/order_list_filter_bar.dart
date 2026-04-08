import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Opción de chip para filtrar por `transaction_requests.status`.
class OrderStatusFilterOption {
  const OrderStatusFilterOption({
    required this.status,
    required this.label,
  });

  final String status;
  final String label;
}

/// Barra de búsqueda y chips de estado (scroll horizontal).
class OrderListFilterBar extends StatefulWidget {
  const OrderListFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    this.hintText = 'Buscar por producto, SKU o empresa',
    this.statusOptions,
    this.selectedStatus,
    this.onStatusChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String hintText;
  final List<OrderStatusFilterOption>? statusOptions;
  final String? selectedStatus;
  final ValueChanged<String?>? onStatusChanged;

  @override
  State<OrderListFilterBar> createState() => _OrderListFilterBarState();
}

class _OrderListFilterBarState extends State<OrderListFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant OrderListFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onText);
      widget.searchController.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onText);
    super.dispose();
  }

  void _onText() => setState(() {});

  bool get _hasStatusFilter =>
      widget.statusOptions != null &&
      widget.statusOptions!.isNotEmpty &&
      widget.onStatusChanged != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.searchController,
            onChanged: widget.onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: widget.searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      color: AppColors.textSecondary,
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.brandBlue, width: 1.2),
              ),
              isDense: true,
            ),
          ),
          if (_hasStatusFilter) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: widget.selectedStatus == null,
                    onSelected: (_) => widget.onStatusChanged!(null),
                    visualDensity: VisualDensity.compact,
                    selectedColor: AppColors.brandBlue.withOpacity(0.2),
                    checkmarkColor: AppColors.brandBlue,
                  ),
                  const SizedBox(width: 6),
                  ...widget.statusOptions!.map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label:
                            Text(o.label, style: const TextStyle(fontSize: 12)),
                        selected: widget.selectedStatus == o.status,
                        onSelected: (_) => widget.onStatusChanged!(o.status),
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.brandBlue.withOpacity(0.2),
                        checkmarkColor: AppColors.brandBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
