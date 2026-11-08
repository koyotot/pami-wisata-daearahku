import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import '../data/business_repository.dart';
import 'api_image.dart';

class DestinationHeroGallery extends StatefulWidget {
  final List<DestinationImage> images;
  final BusinessRepository repository;
  final String? adminGuid;
  final bool allowFullscreen;
  const DestinationHeroGallery(
      {super.key,
      required this.images,
      required this.repository,
      this.adminGuid,
      this.allowFullscreen = true});
  @override
  State<DestinationHeroGallery> createState() => _DestinationHeroGalleryState();
}

class _DestinationHeroGalleryState extends State<DestinationHeroGallery> {
  final _pages = PageController();
  int _index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _changed(0);
    });
  }

  @override
  void didUpdateWidget(DestinationHeroGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.images.length) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _changed(int index) {
    setState(() => _index = index);
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.images.length) {
        ApiImage.prefetch(widget.images[i].url('display'), widget.repository,
            adminGuid: widget.adminGuid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const ColoredBox(
          color: Color(0xFFE5EDF5),
          child: Center(child: Icon(PhosphorIconsRegular.mountains, size: 64)));
    }
    return Stack(children: [
      Positioned.fill(
          child: PageView.builder(
              controller: _pages,
              onPageChanged: _changed,
              itemCount: widget.images.length,
              itemBuilder: (context, i) => GestureDetector(
                  onTap: !widget.allowFullscreen
                      ? null
                      : () async {
                          final index = await Navigator.push<int>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => FullscreenDestinationGallery(
                                      images: widget.images,
                                      initialIndex: i,
                                      adminGuid: widget.adminGuid,
                                      repository: widget.repository)));
                          if (mounted && index != null) {
                            _pages.jumpToPage(index);
                            _changed(index);
                          }
                        },
                  child: ApiImage(
                      imageUrl: widget.images[i].url('display'),
                      adminGuid: widget.adminGuid,
                      repository: widget.repository)))),
      if (widget.images.length > 1) ...[
        Positioned(
          right: 20,
          bottom: 32,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF102D59).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Text('${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (i) => AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  width: i == _index ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _index ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

class FullscreenDestinationGallery extends StatefulWidget {
  final List<DestinationImage> images;
  final int initialIndex;
  final BusinessRepository repository;
  final String? adminGuid;
  const FullscreenDestinationGallery(
      {super.key,
      required this.images,
      required this.initialIndex,
      this.adminGuid,
      required this.repository});
  @override
  State<FullscreenDestinationGallery> createState() =>
      _FullscreenDestinationGalleryState();
}

class _FullscreenDestinationGalleryState
    extends State<FullscreenDestinationGallery> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  final _thumbnails = ScrollController();
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  bool _invalidated = false;
  @override
  void initState() {
    super.initState();
    if (widget.adminGuid != null) {
      widget.repository.api.session.sessionChanges.addListener(_accessChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _change(_index);
    });
  }

  @override
  void dispose() {
    if (widget.adminGuid != null) {
      widget.repository.api.session.sessionChanges
          .removeListener(_accessChanged);
    }
    _pages.dispose();
    _thumbnails.dispose();
    super.dispose();
  }

  void _accessChanged() {
    if (!mounted) return;
    setState(() => _invalidated = true);
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop(_index);
    }
  }

  void _change(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
    });
    if (_thumbnails.hasClients) {
      final offset =
          (index * 76.0 - _thumbnails.position.viewportDimension / 2 + 38)
              .clamp(0.0, _thumbnails.position.maxScrollExtent);
      _thumbnails.jumpTo(offset);
    }
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.images.length) {
        ApiImage.prefetch(widget.images[i].url('display'), widget.repository,
            adminGuid: widget.adminGuid);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _invalidated
      ? const Scaffold(backgroundColor: Colors.black)
      : PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) Navigator.of(context).pop(_index);
          },
          child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    Navigator.pop(context, _index)
              },
              child: Focus(
                  autofocus: true,
                  child: AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle.light.copyWith(
                          statusBarColor: Colors.transparent,
                          systemNavigationBarColor: Colors.black),
                      child: Scaffold(
                          backgroundColor: Colors.black,
                          body: Stack(children: [
                            Positioned.fill(
                                child: PageView.builder(
                                    controller: _pages,
                                    itemCount: widget.images.length,
                                    physics: _zoomed
                                        ? const NeverScrollableScrollPhysics()
                                        : const PageScrollPhysics(),
                                    onPageChanged: _change,
                                    itemBuilder: (_, i) => _ZoomPhoto(
                                        key: ValueKey(
                                            '${widget.images[i].guid}-${i == _index}'),
                                        image: widget.images[i],
                                        adminGuid: widget.adminGuid,
                                        repository: widget.repository,
                                        onSwipe: (direction) {
                                          if (i != _index ||
                                              _zoomed ||
                                              !_pages.hasClients) {
                                            return;
                                          }
                                          final next = (i + direction).clamp(
                                              0, widget.images.length - 1);
                                          if (next == i) return;
                                          if (MediaQuery.disableAnimationsOf(
                                              context)) {
                                            _pages.jumpToPage(next);
                                          } else {
                                            _pages.animateToPage(next,
                                                duration: const Duration(
                                                    milliseconds: 220),
                                                curve: Curves.easeOut);
                                          }
                                        },
                                        onZoom: (value) {
                                          if (i == _index && value != _zoomed) {
                                            setState(() => _zoomed = value);
                                          }
                                        }))),
                            SafeArea(
                                child: Column(children: [
                              SizedBox(
                                height: 48,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: Text(
                                        '${_index + 1} dari ${widget.images.length} foto',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        tooltip: 'Tutup galeri',
                                        onPressed: () =>
                                            Navigator.pop(context, _index),
                                        icon: const Icon(PhosphorIconsRegular.x,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                  height: 76,
                                  child: Center(
                                      child: ListView.builder(
                                          controller: _thumbnails,
                                          shrinkWrap: true,
                                          scrollDirection: Axis.horizontal,
                                          itemCount: widget.images.length,
                                          itemBuilder: (_, i) => Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: InkWell(
                                                  onTap: () {
                                                    if (i == _index) return;
                                                    _pages.jumpToPage(i);
                                                    _change(i);
                                                  },
                                                  child: Container(
                                                      width: 68,
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: Border.all(
                                                              width: 2,
                                                              color: i == _index
                                                                  ? const Color(
                                                                      0xFF1976D2)
                                                                  : const Color(0xFF728099)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.65))),
                                                      child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(6),
                                                          child: ApiImage(adminGuid: widget.adminGuid, imageUrl: widget.images[i].url('thumbnail'), repository: widget.repository)))))))),
                              const SizedBox(height: 8),
                            ])),
                          ]))))));
}

class _ZoomPhoto extends StatefulWidget {
  final DestinationImage image;
  final BusinessRepository repository;
  final String? adminGuid;
  final ValueChanged<bool> onZoom;
  final ValueChanged<int> onSwipe;
  const _ZoomPhoto(
      {super.key,
      required this.image,
      required this.repository,
      this.adminGuid,
      required this.onZoom,
      required this.onSwipe});
  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
  bool _zoomed = false;
  Offset _swipeStart = Offset.zero;
  Offset _swipeDelta = Offset.zero;
  bool _singlePointerSwipe = false;
  void _zoom(bool value) {
    if (_zoomed != value) setState(() => _zoomed = value);
    widget.onZoom(value);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
      onDoubleTapDown: (details) => _tap = details.localPosition,
      onDoubleTap: () {
        final zoom = _transform.value.getMaxScaleOnAxis() <= 1.01;
        _transform.value = zoom
            ? (Matrix4.identity()
              ..translateByDouble(-_tap.dx * 1.5, -_tap.dy * 1.5, 0, 1)
              ..scaleByDouble(2.5, 2.5, 1, 1))
            : Matrix4.identity();
        _zoom(zoom);
      },
      child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          panEnabled: _zoomed,
          onInteractionStart: (details) {
            _swipeStart = details.focalPoint;
            _swipeDelta = Offset.zero;
            _singlePointerSwipe = !_zoomed && details.pointerCount == 1;
          },
          onInteractionUpdate: (details) {
            _swipeDelta = details.focalPoint - _swipeStart;
            if (details.pointerCount != 1 || details.scale > 1.01 || _zoomed) {
              _singlePointerSwipe = false;
            }
            _zoom(_transform.value.getMaxScaleOnAxis() > 1.01);
          },
          onInteractionEnd: (_) {
            // InteractiveViewer can win Android's one-finger gesture before PageView.
            if (_singlePointerSwipe &&
                !_zoomed &&
                _swipeDelta.dx.abs() >= 48 &&
                _swipeDelta.dx.abs() > _swipeDelta.dy.abs() * 1.5) {
              widget.onSwipe(_swipeDelta.dx < 0 ? 1 : -1);
            }
            _singlePointerSwipe = false;
          },
          child: SizedBox.expand(
              child: Stack(fit: StackFit.expand, children: [
            ApiImage(
                adminGuid: widget.adminGuid,
                imageUrl: widget.image.url('display'),
                repository: widget.repository,
                fit: BoxFit.contain),
            ApiImage(
                adminGuid: widget.adminGuid,
                imageUrl: widget.image.url('fullscreen'),
                repository: widget.repository,
                fit: BoxFit.contain,
                placeholder: (_) => const SizedBox.shrink()),
          ]))));
}
