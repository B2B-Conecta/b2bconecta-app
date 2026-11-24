import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'importer_catalog_logo.dart';

const supplierBlue = Color(0xFF004BDD);
const supplierHeaderTitleSize = 19.0;

Widget mobileSupplierLogo(BuildContext context,
    {String? path, double size = 64}) {
  final colors = Theme.of(context).colorScheme;
  return DecoratedBox(
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surface,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: ClipOval(
          child: ImporterCatalogLogo(
              storagePath: path,
              size: size,
              fallback: SizedBox.square(
                  dimension: size,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: colors.surface),
                      child: Icon(Icons.storefront_outlined,
                          color: colors.primary, size: size * .45))))));
}

AppBar mobileSupplierAppBar(
  BuildContext context, {
  required String title,
  required ProfileModel viewer,
  double? brandedToolbarHeight,
  PreferredSizeWidget? bottom,
  List<Widget> leadingActions = const [],
  List<Widget> actions = const [],
}) {
  final heading = Text(title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
          fontSize: supplierHeaderTitleSize, fontWeight: FontWeight.w700));
  return AppBar(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0A317B)
        : supplierBlue,
    foregroundColor: Colors.white,
    titleTextStyle:
        Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
    toolbarHeight: brandedToolbarHeight,
    title:
        brandedToolbarHeight == null ? heading : B2bHeaderTitle(title: heading),
    actions: [
      ...leadingActions,
      if (viewer.isAliado)
        ListenableBuilder(
            listenable: CartService.instance,
            builder: (context, _) => IconButton(
                tooltip: 'Bolsa',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => CartScreen(
                            profile: viewer,
                            liveTasaBcv: BcvBasePrice.cachedRate))),
                icon: Badge(
                    isLabelVisible: CartService.instance.itemCount > 0,
                    label: Text('${CartService.instance.itemCount}'),
                    child: const LucideIcon(LucideGlyph.handbag,
                        color: Colors.white, size: 22)))),
      ...actions,
      const SizedBox(width: 8),
    ],
    bottom: bottom,
  );
}
