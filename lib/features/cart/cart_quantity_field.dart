import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Editing large orders should not require one tap per unit.
class CartQuantityField extends StatefulWidget {
  const CartQuantityField(
      {super.key,
      required this.quantity,
      required this.minimum,
      required this.maximum,
      required this.onChanged,
      this.embedded = false,
      this.semanticLabel});
  final int quantity;
  final int minimum;
  final int maximum;
  final ValueChanged<int>? onChanged;
  final bool embedded;
  final String? semanticLabel;

  @override
  State<CartQuantityField> createState() => CartQuantityFieldState();
}

class CartQuantityFieldState extends State<CartQuantityField> {
  late final _controller = TextEditingController(text: '${widget.quantity}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) commit();
  }

  /// Commit before an adjacent purchase action; focus loss can arrive later.
  int commit() {
    if (widget.onChanged == null) return widget.quantity;
    final parsed = int.tryParse(_controller.text);
    // A changing stock can invalidate the range before its control is rebuilt.
    if (widget.maximum < widget.minimum) return widget.quantity;
    final value =
        (parsed ?? widget.quantity).clamp(widget.minimum, widget.maximum);
    _controller.text = '$value';
    if (value != widget.quantity) widget.onChanged?.call(value);
    final message = parsed != null && parsed < widget.minimum
        ? 'Mínimo ${widget.minimum} unidades. Cantidad ajustada a $value.'
        : parsed != null && parsed > widget.maximum
            ? 'Disponibles ${widget.maximum} unidades. Cantidad ajustada a $value.'
            : null;
    if (message != null && mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3)));
    }
    return value;
  }

  @override
  void didUpdateWidget(covariant CartQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity) {
      _controller.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 64,
        height: widget.embedded
            ? (MediaQuery.textScalerOf(context).scale(18) + 24)
                .clamp(44, double.infinity)
            : null,
        child: Semantics(
          label: widget.semanticLabel ?? (widget.embedded ? 'Cantidad' : null),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: widget.onChanged != null,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7)
            ],
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            decoration: widget.embedded
                ? const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide:
                          BorderSide(color: Color(0xFF0039A0), width: 1.5),
                    ),
                    disabledBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  )
                : const InputDecoration(
                    labelText: 'Cantidad',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  ),
            onSubmitted: (_) {
              commit();
              _focus.unfocus();
            },
            onTapOutside: (_) {
              commit();
              _focus.unfocus();
            },
          ),
        ),
      );
}
