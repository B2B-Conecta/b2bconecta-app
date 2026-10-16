import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/catalog/importer_store_profile_screen.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'importer_store_share_link.dart';
import 'product_share_destination.dart';
import 'product_share_link.dart';

/// Cuando hay sesión, abre el producto o la vitrina que quedó en el enlace.
class ProductShareLinkHost extends StatefulWidget {
  const ProductShareLinkHost({
    super.key,
    required this.child,
    required this.viewer,
  });

  final Widget child;
  final ProfileModel viewer;

  @override
  State<ProductShareLinkHost> createState() => _ProductShareLinkHostState();
}

class _ProductShareLinkHostState extends State<ProductShareLinkHost> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    ProductShareLink.pending.addListener(_onPending);
    ImporterStoreShareLink.pending.addListener(_onPending);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await ProductShareLink.restore();
    await ImporterStoreShareLink.restore();
    if (mounted) _onPending();
  }

  @override
  void dispose() {
    ProductShareLink.pending.removeListener(_onPending);
    ImporterStoreShareLink.pending.removeListener(_onPending);
    super.dispose();
  }

  void _onPending() {
    if (_opening) return;
    if (ProductShareLink.pending.value == null &&
        ImporterStoreShareLink.pending.value == null) {
      return;
    }
    _opening = true;
    unawaited(_open());
  }

  Future<void> _open() async {
    final productId = await ProductShareLink.take();
    final storeId = await ImporterStoreShareLink.take();
    _opening = false;
    if (!mounted) return;
    if (productId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductShareDestinationScreen(productId: productId),
        ),
      );
      return;
    }
    if (storeId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImporterStoreProfileScreen(
          importerId: storeId,
          viewer: widget.viewer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
