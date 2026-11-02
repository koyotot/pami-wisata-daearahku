import 'package:flutter/material.dart';
import '../data/gallery_draft.dart';
import '../data/business_repository.dart';
import 'api_image.dart';

class AdminDestinationGalleryEditor extends StatelessWidget {
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

  Widget _image(GalleryDraftItem item, {BoxFit fit = BoxFit.cover}) => item
              .bytes !=
          null
      ? Image.memory(item.bytes!,
          fit: fit,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
      : ApiImage(
          imageUrl:
              item.image!.url(fit == BoxFit.cover ? 'thumbnail' : 'display'),
          adminGuid: destinationGuid,
          repository: repository,
          fit: fit);

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${items.length}/10 foto',
                  style: Theme.of(context).textTheme.titleSmall)),
          TextButton.icon(
              onPressed: enabled && items.length < 10 ? onAdd : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Tambah Foto'))
        ]),
        const Text(
            'JPEG, PNG, WebP · maksimal 5 MiB/foto. Tahan lalu geser untuk mengurutkan.'),
        const SizedBox(height: 12),
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tile = ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(fit: StackFit.expand, children: [
                    GestureDetector(
                        onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => Dialog(
                                    child: Stack(children: [
                                  AspectRatio(
                                      aspectRatio: 1,
                                      child: _image(items[index],
                                          fit: BoxFit.contain)),
                                  Align(
                                      alignment: Alignment.topRight,
                                      child: IconButton(
                                          tooltip: 'Tutup preview',
                                          icon: const Icon(Icons.close),
                                          onPressed: () =>
                                              Navigator.pop(context)))
                                ]))),
                        child: _image(items[index])),
                    Positioned(
                        left: 4,
                        bottom: 4,
                        child: Container(
                            color: Colors.black87,
                            padding: const EdgeInsets.all(4),
                            child: Text(
                                index == 0 ? '1 · Cover' : '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)))),
                    Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                            tooltip: 'Hapus foto ${index + 1}',
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.white),
                            iconSize: 18,
                            onPressed: enabled ? () => onRemove(index) : null,
                            icon: const Icon(Icons.close))),
                  ]));
              return DragTarget<int>(
                  onWillAcceptWithDetails: (d) => enabled && d.data != index,
                  onAcceptWithDetails: (d) => onReorder(d.data, index),
                  builder: (_, candidates, __) => LongPressDraggable<int>(
                      data: index,
                      maxSimultaneousDrags: enabled ? 1 : 0,
                      feedback: Material(
                          child: SizedBox(
                              width: 100,
                              height: 100,
                              child: _image(items[index]))),
                      childWhenDragging: Opacity(opacity: .3, child: tile),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              border: candidates.isEmpty
                                  ? null
                                  : Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 3)),
                          child: tile)));
            }),
      ]);
}
