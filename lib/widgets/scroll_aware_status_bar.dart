import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons that follow the surface actually behind them.
///
/// [builder] receives a key to put on the dark header. Icons stay light while
/// that header still covers the status bar and turn dark once it has scrolled
/// away and the light page background shows through. With [tracksHeader]
/// false the icons stay light (for pages whose dark header stays pinned).
/// A non-null [scrimColor] also paints that colour behind the status bar
/// once the header is gone, so scrolled text does not run under the icons.
class ScrollAwareStatusBar extends StatefulWidget {
  const ScrollAwareStatusBar({
    super.key,
    required this.builder,
    this.tracksHeader = true,
    this.navigationBarColor = Colors.transparent,
    this.scrimColor,
  });

  final Widget Function(BuildContext context, GlobalKey headerKey) builder;
  final bool tracksHeader;
  final Color navigationBarColor;
  final Color? scrimColor;

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
        child: widget.scrimColor == null
            ? widget.builder(context, _headerKey)
            : Stack(fit: StackFit.expand, children: [
                widget.builder(context, _headerKey),
                Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.paddingOf(context).top,
                    child: IgnorePointer(
                        child: AnimatedOpacity(
                            opacity: light ? 0 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: ColoredBox(color: widget.scrimColor!)))),
              ]),
      ),
    );
  }
}
