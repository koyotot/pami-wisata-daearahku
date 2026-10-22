class Wisata {
  int id;
  String nama;
  String lokasi;
  String deskripsi;
  String hargaTiket;
  String jamBuka;
  String kategori;
  String? imagePath; // path gambar lokal (dari Image.file atau Image.memory)

  Wisata({
    required this.id,
    required this.nama,
    required this.lokasi,
    required this.deskripsi,
    required this.hargaTiket,
    required this.jamBuka,
    required this.kategori,
    this.imagePath,
  });
}
