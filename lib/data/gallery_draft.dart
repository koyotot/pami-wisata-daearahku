import 'dart:math';
import 'dart:typed_data';
import 'business_repository.dart';

String galleryUuid() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class GalleryDraftItem {
  final DestinationImage? image;
  final Uint8List? bytes;
  final String key;
  final String filename;
  GalleryDraftItem.existing(DestinationImage value)
      : image = value,
        bytes = null,
        key = value.guid,
        filename = '';
  GalleryDraftItem.upload(this.bytes, this.filename)
      : image = null,
        key = galleryUuid();
  Map<String, dynamic> get manifest =>
      image == null ? {'upload_key': key} : {'image_guid': image!.guid};
}
