import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/business_repository.dart';
import 'api_image.dart';

class DestinationHeroGallery extends StatefulWidget {
  final List<DestinationImage> images;
  final BusinessRepository repository;
  const DestinationHeroGallery(
      {super.key, required this.images, required this.repository});
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
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _changed(int index) {
    setState(() => _index = index);
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.images.length) {
        ApiImage.prefetch(widget.images[i].url('display'), widget.repository);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const ColoredBox(
          color: Color(0xFFE5EDF5),
          child: Center(child: Icon(Icons.landscape_outlined, size: 64)));
    }
    return Stack(children: [
      Positioned.fill(
          child: PageView.builder(
              controller: _pages,
              onPageChanged: _changed,
              itemCount: widget.images.length,
              itemBuilder: (context, i) => GestureDetector(
                  onTap: () async {
                    final index = await Navigator.push<int>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FullscreenDestinationGallery(
                                images: widget.images,
                                initialIndex: i,
                                repository: widget.repository)));
                    if (mounted && index != null) {
                      _pages.jumpToPage(index);
                      _changed(index);
                    }
                  },
                  child: ApiImage(
                      imageUrl: widget.images[i].url('display'),
                      repository: widget.repository)))),
      if (widget.images.length > 1)
        Positioned(
            left: 0,
            right: 0,
            bottom: 78,
            child: IgnorePointer(
                child: Column(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.black54,
                  child: Text('${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white))),
              const SizedBox(height: 8),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      widget.images.length,
                      (i) => Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white54))))
            ]))),
    ]);
  }
}

class FullscreenDestinationGallery extends StatefulWidget {
  final List<DestinationImage> images;
  final int initialIndex;
  final BusinessRepository repository;
  const FullscreenDestinationGallery(
      {super.key,
      required this.images,
      required this.initialIndex,
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
  @override
  void dispose() {
    _pages.dispose();
    _thumbnails.dispose();
    super.dispose();
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
        ApiImage.prefetch(widget.images[i].url('display'), widget.repository);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
                                    repository: widget.repository,
                                    onZoom: (value) {
                                      if (i == _index && value != _zoomed) {
                                        setState(() => _zoomed = value);
                                      }
                                    }))),
                        SafeArea(
                            child: Column(children: [
                          Row(children: [
                            IconButton(
                                tooltip: 'Tutup galeri',
                                onPressed: () => Navigator.pop(context, _index),
                                icon: const Icon(Icons.close,
                                    color: Colors.white)),
                            const Spacer(),
                            Text('${_index + 1} / ${widget.images.length}',
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(width: 20)
                          ]),
                          const Spacer(),
                          SizedBox(
                              height: 76,
                              child: ListView.builder(
                                  controller: _thumbnails,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.images.length,
                                  itemBuilder: (_, i) => Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: InkWell(
                                          onTap: () {
                                            _pages.jumpToPage(i);
                                            _change(i);
                                          },
                                          child: Container(
                                              width: 68,
                                              decoration: BoxDecoration(
                                                  border: Border.all(
                                                      width: 3,
                                                      color: i == _index
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Colors
                                                              .transparent)),
                                              child: ApiImage(
                                                  imageUrl: widget.images[i]
                                                      .url('thumbnail'),
                                                  repository:
                                                      widget.repository)))))),
                          const SizedBox(height: 8),
                        ])),
                      ]))))));
}

class _ZoomPhoto extends StatefulWidget {
  final DestinationImage image;
  final BusinessRepository repository;
  final ValueChanged<bool> onZoom;
  const _ZoomPhoto(
      {super.key,
      required this.image,
      required this.repository,
      required this.onZoom});
  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final _transform = TransformationController();
  Offset _tap = Offset.zero;
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
        widget.onZoom(zoom);
      },
      child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          onInteractionUpdate: (_) =>
              widget.onZoom(_transform.value.getMaxScaleOnAxis() > 1.01),
          child: SizedBox.expand(
              child: Stack(fit: StackFit.expand, children: [
            ApiImage(
                imageUrl: widget.image.url('display'),
                repository: widget.repository,
                fit: BoxFit.contain),
            ApiImage(
                imageUrl: widget.image.url('fullscreen'),
                repository: widget.repository,
                fit: BoxFit.contain,
                placeholder: (_) => const SizedBox.shrink()),
          ]))));
}
