import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class AppIcons {
  AppIcons._();

  static final actionTheme = ActionIconThemeData(
    backButtonIconBuilder: (_) => const Icon(PhosphorIconsRegular.arrowLeft),
    closeButtonIconBuilder: (_) => const Icon(PhosphorIconsRegular.x),
    drawerButtonIconBuilder: (_) => const Icon(PhosphorIconsRegular.list),
    endDrawerButtonIconBuilder: (_) => const Icon(PhosphorIconsRegular.list),
  );
}
