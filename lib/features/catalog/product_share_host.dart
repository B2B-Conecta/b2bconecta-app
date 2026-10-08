import 'dart:async';

import 'package:flutter/material.dart';

import 'product_share_destination.dart';
import 'product_share_link.dart';

/// Cuando hay sesión, abre el producto que quedó pendiente en el enlace.
class ProductShareLinkHost extends StatefulWidget {
  const ProductShareLinkHost({super.key, required this.child});

  final Widget child;

  @override
  State<ProductShareLinkHost> createState() => _ProductShareLinkHostState();
}

class _ProductShareLinkHostState extends State<ProductShareLinkHost> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    ProductShareLink.pending.addListener(_onPending);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await ProductShareLink.restore();
    if (mounted) _onPending();
  }

  @override
  void dispose() {
    ProductShareLink.pending.removeListener(_onPending);
    super.dispose();
  }

  void _onPending() {
    if (_opening || ProductShareLink.pending.value == null) return;
    _opening = true;
    unawaited(_open());
  }

  Future<void> _open() async {
    final id = await ProductShareLink.take();
    _opening = false;
    if (!mounted || id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductShareDestinationScreen(productId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
