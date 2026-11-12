import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons that follow the surface actually behind them.
///
/// [builder] receives a key to put on the dark header. Icons stay light while
/// that header still covers the status bar and turn dark once it has scrolled
/// away and the light page background shows through. With [tracksHeader]
/// false the icons stay light (for pages whose dark header stays pinned).
class ScrollAwareStatusBar extends StatefulWidget {
  const ScrollAwareStatusBar({
    super.key,
    required this.builder,
    this.tracksHeader = true,
    this.navigationBarColor = Colors.transparent,
  });

  final Widget Function(BuildContext context, GlobalKey headerKey) builder;
  final bool tracksHeader;
  final Color navigationBarColor;

  @override
  State<ScrollAwareStatusBar> createState() => _ScrollAwareStatusBarState();
}

class _ScrollAwareStatusBarState extends State<ScrollAwareStatusBar> {
  final _headerKey = GlobalKey(debugLabel: 'status-bar-header');
  bool _headerUnderStatusBar = true;

  bool _measure() {
    if (!widget.tracksHeader) return true;
    final box = _headerKey.currentContext?.findRenderObject();
    // A header that was scrolled out of the list's cache is no longer built.
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    return bottom > MediaQuery.paddingOf(context).top;
  }

  bool _scheduled = false;

  bool _onScroll(ScrollNotification notification) {
    // Notifications arrive before the viewport lays out the new offset, so
    // measure once the frame is laid out.
    if (notification.metrics.axis == Axis.vertical && !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted) return;
        final next = _measure();
        if (next != _headerUnderStatusBar) {
          setState(() => _headerUnderStatusBar = next);
        }
      });
    }
    return false;
  }

  @override
  void didUpdateWidget(ScrollAwareStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.tracksHeader) _headerUnderStatusBar = true;
  }

  @override
  Widget build(BuildContext context) {
    final light = _headerUnderStatusBar;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: light ? Brightness.light : Brightness.dark,
          // iOS reads the bar background brightness instead.
          statusBarBrightness: light ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: widget.navigationBarColor,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: widget.builder(context, _headerKey),
      ),
    );
  }
}
