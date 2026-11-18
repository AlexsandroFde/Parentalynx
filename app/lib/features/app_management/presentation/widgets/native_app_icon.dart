import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';

import '../services/installed_app_icons.dart';

/// Mostra o icone de um app instalado neste aparelho, com um icone generico enquanto carrega
/// ou quando nao ha.
///
/// Os icones vem do [InstalledAppIcons] da arvore de widgets.
class NativeAppIcon extends StatefulWidget {
  const NativeAppIcon({required this.packageName, this.size = 40, super.key});

  final String packageName;
  final double size;

  @override
  State<NativeAppIcon> createState() => _NativeAppIconState();
}

class _NativeAppIconState extends State<NativeAppIcon> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NativeAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _bytes = null;
      _load();
    }
  }

  void _load() {
    final InstalledAppIcons icons = context.read<InstalledAppIcons>();
    final String package = widget.packageName;
    _bytes = icons.cached(package);
    if (_bytes != null) {
      return;
    }
    unawaited(
      icons.iconFor(package).then((Uint8List? bytes) {
        if (mounted && bytes != null && widget.packageName == package) {
          setState(() => _bytes = bytes);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final Uint8List? bytes = _bytes;
    final AppColors colors = context.colors;
    final BorderRadius radius = context.shapes.tileRadius;
    if (bytes == null || bytes.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: radius),
        child: Icon(AppIcons.apps, size: size * 0.56, color: colors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Container(
            width: size,
            height: size,
            color: colors.surfaceMuted,
            child: Icon(AppIcons.apps, size: size * 0.56, color: colors.textSecondary),
          );
        },
      ),
    );
  }
}
