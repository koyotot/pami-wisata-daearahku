import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../data/gallery_draft.dart';
import '../data/business_repository.dart';
import 'api_image.dart';

const _navy = Color(0xFF102D59);
const _blue = Color(0xFF1976D2);
const _tint = Color(0xFFE6F0FC);
const _muted = Color(0xFF728099);
const _border = Color(0xFFDCE4F0);

/// Destination gallery: large cover (item 0) plus numbered thumbnails.
/// Tapping a thumbnail makes it the cover; long-press drag reorders.
class AdminDestinationGalleryEditor extends StatelessWidget {
  static const maxPhotos = 10;

  final List<GalleryDraftItem> items;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, int) onReorder;
  final String? destinationGuid;
  final BusinessRepository repository;
  const AdminDestinationGalleryEditor(
      {super.key,
      required this.items,
      required this.enabled,
      required this.onAdd,
      required this.onRemove,
      required this.onReorder,
      required this.repository,
      this.destinationGuid});

  Widget _image(GalleryDraftItem item, {BoxFit fit = BoxFit.cover}) =>
      item.bytes != null
          ? Image.memory(item.bytes!,
              fit: fit,
              errorBuilder: (_, __, ___) =>
                  const Icon(PhosphorIconsRegular.imageBroken))
          : ApiImage(
              imageUrl: item.image!
                  .url(fit == BoxFit.cover ? 'thumbnail' : 'display'),
              adminGuid: destinationGuid,
              repository: repository,
              fit: fit);

  void _preview(BuildContext context, int index) => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
              child: Stack(children: [
            AspectRatio(
                aspectRatio: 1,
                child: _image(items[index], fit: BoxFit.contain)),
            Align(
                alignment: Alignment.topRight,
                child: IconButton(
                    tooltip: 'Tutup preview',
                    icon: const Icon(PhosphorIconsRegular.x),
                    onPressed: () => Navigator.pop(context)))
          ])));

  Widget _removeButton(int index, {double size = 32}) => SizedBox(
        width: size,
        height: size,
        child: IconButton(
            tooltip: 'Hapus foto ${index + 1}',
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _navy,
                disabledBackgroundColor: Colors.white70,
                shadowColor: Colors.black26,
                elevation: 1),
            iconSize: size * .45,
            onPressed: enabled ? () => onRemove(index) : null,
            icon: const Icon(PhosphorIconsBold.x)),
      );

  Widget _badge(Widget child, {EdgeInsets? padding}) => DecoratedBox(
        decoration: BoxDecoration(
            color: _navy.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(8)),
        child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: DefaultTextStyle.merge(
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                child: child)),
      );

  /// Wraps a tile so it can be dragged onto, and accept drops from, others.
  Widget _reorderable(BuildContext context, int index, Widget tile,
          {double feedbackSize = 90}) =>
      DragTarget<int>(
          onWillAcceptWithDetails: (d) => enabled && d.data != index,
          onAcceptWithDetails: (d) => onReorder(d.data, index),
          builder: (_, candidates, __) => LongPressDraggable<int>(
              data: index,
              maxSimultaneousDrags: enabled ? 1 : 0,
              feedback: Material(
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                      width: feedbackSize,
                      height: feedbackSize,
                      child: _image(items[index]))),
              childWhenDragging: Opacity(opacity: .3, child: tile),
              child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: candidates.isEmpty
                          ? null
                          : Border.all(color: _blue, width: 3)),
                  child: tile)));

  Widget _cover(BuildContext context) => _reorderable(
      context,
      0,
      AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            Semantics(
                button: true,
                label: 'Lihat foto sampul',
                child: GestureDetector(
                    onTap: () => _preview(context, 0),
                    child: _image(items[0]))),
            Positioned(top: 10, right: 10, child: _removeButton(0)),
            Positioned(
                left: 10,
                bottom: 10,
                child: _badge(const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIconsFill.star, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Foto Sampul'),
                ]))),
          ]),
        ),
      ),
      feedbackSize: 120);

  Widget _thumbnail(BuildContext context, int index) => _reorderable(
      context,
      index,
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          Semantics(
              button: true,
              label: 'Jadikan foto ${index + 1} sebagai sampul',
              child: GestureDetector(
                  onTap: enabled ? () => onReorder(index, 0) : null,
                  child: _image(items[index]))),
          Positioned(top: 4, right: 4, child: _removeButton(index, size: 26)),
          Positioned(
              left: 4,
              bottom: 4,
              child: _badge(Text('${index + 1}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2))),
        ]),
      ));

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${items.length}',
                        style: const TextStyle(
                            color: _navy, fontWeight: FontWeight.w800)),
                    const TextSpan(text: ' dari $maxPhotos foto'),
                  ]),
                  style: const TextStyle(color: _muted, fontSize: 13))),
          const SizedBox(width: 8),
          TextButton.icon(
              onPressed: enabled && items.length < maxPhotos ? onAdd : null,
              style: TextButton.styleFrom(
                  backgroundColor: _tint,
                  foregroundColor: _blue,
                  disabledBackgroundColor: _tint.withValues(alpha: .5),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: const Icon(PhosphorIconsBold.plus, size: 16),
              label: const Text('Tambah Foto',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        if (items.isEmpty)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Material(
              color: const Color(0xFFF5F8FD),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _border)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: enabled ? onAdd : null,
                child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsRegular.images,
                          color: _blue, size: 32),
                      SizedBox(height: 8),
                      Text('Belum ada foto',
                          style: TextStyle(
                              color: _navy, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Ketuk untuk menambahkan foto destinasi',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ]),
              ),
            ),
          )
        else ...[
          _cover(context),
          if (items.length > 1) ...[
            const SizedBox(height: 10),
            GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: items.length - 1,
                itemBuilder: (context, i) => _thumbnail(context, i + 1)),
          ],
        ],
        const SizedBox(height: 12),
        const Text(
            'Foto pertama adalah cover. Ketuk foto kecil untuk menjadikannya cover. '
            'Maksimal 10 foto (JPEG, PNG, WebP), masing-masing 5 MiB.',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.45)),
      ]);
}
