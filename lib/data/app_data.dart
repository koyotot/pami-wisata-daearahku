// ============================================================
// lib/data/app_data.dart  ← SATU-SATUNYA sumber model data
// ============================================================
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Model User ─────────────────────────────────────────────
class User {
  String id;
  String namaLengkap;
  String email;
  String noTelepon;
  String password;
  DateTime createdAt;

  User({
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.noTelepon,
    required this.password,
    required this.createdAt,
  });
}

// ── Auth State ─────────────────────────────────────────────
List<User> daftarUser = [];
User? currentUser; // null = belum login

String nextUserId() => 'U${DateTime.now().millisecondsSinceEpoch}';

class Wisata {
  String id, nama, lokasi, deskripsi, hargaTiket, jamBuka, kategori;
  String? imagePath;
  double rating;

  Wisata({
    required this.id,
    required this.nama,
    required this.lokasi,
    required this.deskripsi,
    required this.hargaTiket,
    required this.jamBuka,
    required this.kategori,
    this.imagePath,
    this.rating = 4.5,
  });

  // Untuk simpan ke Firestore
  Map<String, dynamic> toMap() => {
        'nama': nama,
        'lokasi': lokasi,
        'deskripsi': deskripsi,
        'hargaTiket': hargaTiket,
        'jamBuka': jamBuka,
        'kategori': kategori,
        'imagePath': imagePath,
        'rating': rating,
        'createdAt': Timestamp.now(),
      };

  // Untuk baca dari Firestore
  factory Wisata.fromMap(Map<String, dynamic> m, String id) => Wisata(
        id: id,
        nama: m['nama'] ?? '',
        lokasi: m['lokasi'] ?? '',
        deskripsi: m['deskripsi'] ?? '',
        hargaTiket: m['hargaTiket'] ?? '',
        jamBuka: m['jamBuka'] ?? '',
        kategori: m['kategori'] ?? '',
        imagePath: m['imagePath'],
        rating: (m['rating'] as num?)?.toDouble() ?? 4.5,
      );
}

/// Status pendaftaran:
/// - 'menunggu'  → baru masuk, belum diproses admin
/// - 'disetujui' → admin menekan Setujui
/// - 'ditolak'   → admin menekan Tolak
class Pendaftar {
  String? id; // ID dokumen Firestore (null jika belum tersimpan)
  String userId; // uid pemilik pendaftaran (dari Firebase Auth)
  String namaPengunjung, noTelepon, email, wisata, tanggal, nomorBukti, catatan;
  int jumlahOrang;
  String status; // 'menunggu' | 'disetujui' | 'ditolak'

  Pendaftar({
    this.id,
    required this.userId,
    required this.namaPengunjung,
    required this.noTelepon,
    required this.email,
    required this.wisata,
    required this.tanggal,
    required this.jumlahOrang,
    required this.nomorBukti,
    required this.catatan,
    this.status = 'menunggu',
  });

  // Untuk simpan ke Firestore
  Map<String, dynamic> toMap() => {
        'userId': userId,
        'namaPengunjung': namaPengunjung,
        'noTelepon': noTelepon,
        'email': email,
        'wisata': wisata,
        'tanggal': tanggal,
        'jumlahOrang': jumlahOrang,
        'nomorBukti': nomorBukti,
        'catatan': catatan,
        'status': status,
        'createdAt': Timestamp.now(),
      };

  // Untuk baca dari Firestore
  factory Pendaftar.fromMap(Map<String, dynamic> m, String id) => Pendaftar(
        id: id,
        userId: m['userId'] ?? '',
        namaPengunjung: m['namaPengunjung'] ?? '',
        noTelepon: m['noTelepon'] ?? '',
        email: m['email'] ?? '',
        wisata: m['wisata'] ?? '',
        tanggal: m['tanggal'] ?? '',
        jumlahOrang: m['jumlahOrang'] ?? 1,
        nomorBukti: m['nomorBukti'] ?? '',
        catatan: m['catatan'] ?? '',
        status: m['status'] ?? 'menunggu',
      );
}

// ── Data Awal (Seed) ───────────────────────────────────────
// Hanya dipakai untuk seed ke Firestore jika belum ada.
// Tidak akan duplikat meski app dibuka berkali-kali.
final List<Wisata> _wisataAwal = [
  Wisata(
    id: '',
    nama: 'Pantai Kuta',
    lokasi: 'Bali',
    deskripsi:
        'Pantai ikonik di Bali yang terkenal dengan pasir putihnya dan sunset yang memukau. Cocok untuk bersantai, berselancar, dan menikmati keindahan alam laut tropis.',
    hargaTiket: 'Gratis',
    jamBuka: '24 Jam',
    kategori: 'Pantai',
    imagePath:
        'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800&fit=crop',
  ),
  Wisata(
    id: '',
    nama: 'Candi Borobudur',
    lokasi: 'Magelang, Jawa Tengah',
    deskripsi:
        'Candi Buddha terbesar di dunia yang dibangun pada abad ke-8. Merupakan warisan dunia UNESCO dan menjadi kebanggaan budaya Indonesia.',
    hargaTiket: 'Rp 50.000',
    jamBuka: '08.00 – 17.00',
    kategori: 'Budaya',
    imagePath:
        'https://images.unsplash.com/photo-1596402184320-417e7178b2cd?w=800&fit=crop',
  ),
  Wisata(
    id: '',
    nama: 'Gunung Bromo',
    lokasi: 'Probolinggo, Jawa Timur',
    deskripsi:
        'Gunung berapi aktif yang terkenal dengan lautan pasir dan pemandangan matahari terbit yang luar biasa. Destinasi favorit para pecinta alam dan fotografer.',
    hargaTiket: 'Rp 30.000',
    jamBuka: '24 Jam',
    kategori: 'Alam',
    imagePath:
        'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?w=800&fit=crop',
  ),
];

// ── Runtime State ──────────────────────────────────────────
List<Wisata> daftarWisata = [];
List<Pendaftar> daftarPendaftar = [];

String nextWisataId() => DateTime.now().millisecondsSinceEpoch.toString();

// ============================================================
// SINKRONISASI DENGAN FIRESTORE
// ============================================================

/// Memuat daftar wisata dari Firestore.
///
/// Logika seed cerdas:
/// - Cek nama wisata awal satu per satu di Firestore.
/// - Jika belum ada → seed wisata tersebut.
/// - Jika sudah ada → skip (tidak duplikat).
/// - Data tambahan admin (AYAYA, Roti Romi, dll) tetap aman.
/// - Hasil akhir: semua data tampil (3 awal + tambahan admin).
Future<void> loadWisataFromFirestore() async {
  final col = FirebaseFirestore.instance.collection('wisata');
  final snapshot = await col.get();

  if (snapshot.docs.isEmpty) {
    // Firestore benar-benar kosong → seed semua 3 data awal sekaligus
    final batch = FirebaseFirestore.instance.batch();
    for (final wisata in _wisataAwal) {
      batch.set(col.doc(), wisata.toMap());
    }
    await batch.commit();

    final seeded = await col.get();
    daftarWisata =
        seeded.docs.map((d) => Wisata.fromMap(d.data(), d.id)).toList();
  } else {
    // Firestore sudah ada data → cek apakah 3 wisata awal sudah ada atau belum
    final namaYangAda = snapshot.docs
        .map((d) => (d.data()['nama'] ?? '').toString().toLowerCase())
        .toSet();

    final batch = FirebaseFirestore.instance.batch();
    bool adaYangDiseed = false;

    for (final wisata in _wisataAwal) {
      if (!namaYangAda.contains(wisata.nama.toLowerCase())) {
        // Wisata awal ini belum ada di Firestore → seed
        batch.set(col.doc(), wisata.toMap());
        adaYangDiseed = true;
      }
      // Sudah ada → skip, tidak duplikat
    }

    if (adaYangDiseed) await batch.commit();

    // Muat ulang semua data terbaru dari Firestore
    final latest = await col.get();
    daftarWisata =
        latest.docs.map((d) => Wisata.fromMap(d.data(), d.id)).toList();
  }
}

/// Memuat daftar pendaftar dari Firestore.
/// - Jika [userId] diisi → hanya ambil milik user tersebut (halaman riwayat).
/// - Jika [userId] null/kosong → ambil SEMUA pendaftaran (halaman admin).
Future<void> loadPendaftarFromFirestore({String? userId}) async {
  Query query = FirebaseFirestore.instance.collection('pendaftar');
  if (userId != null && userId.isNotEmpty) {
    query = query.where('userId', isEqualTo: userId);
  }

  final snapshot = await query.get();
  daftarPendaftar = snapshot.docs
      .map((d) => Pendaftar.fromMap(d.data() as Map<String, dynamic>, d.id))
      .toList();
}
