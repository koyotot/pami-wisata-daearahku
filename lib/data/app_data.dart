// ============================================================
// lib/data/app_data.dart  ← SATU-SATUNYA sumber model data
// ============================================================
import 'business_repository.dart';

// ── Model User ─────────────────────────────────────────────
class User {
  final bool isLaravel;
  String id;
  String namaLengkap;
  String email;
  String noTelepon;
  String password;
  DateTime createdAt;

  User({
    this.isLaravel = false,
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.noTelepon,
    required this.password,
    required this.createdAt,
  });
}

// ── Auth State ─────────────────────────────────────────────
User? currentUser; // null = belum login

class Wisata {
  String id, nama, lokasi, deskripsi, hargaTiket, jamBuka, kategori;
  String? imagePath;
  double rating;
  bool isLaravel;
  int ratingCount;

  /// Laravel-only fields. [imageUrl] is relative to the API base URL (load it with
  /// `ApiImage`); [imagePath] stays null for Laravel destinations because the backend
  /// `image_path` is an internal storage path, not a URL.
  String? imageUrl;
  String categoryGuid;
  String timezone;
  int ticketPrice;
  bool isActive;

  Wisata({
    required this.id,
    required this.nama,
    required this.lokasi,
    required this.deskripsi,
    required this.hargaTiket,
    required this.jamBuka,
    required this.kategori,
    this.imagePath,
    this.rating = 0,
    this.isLaravel = false,
    this.ratingCount = 0,
    this.imageUrl,
    this.categoryGuid = '',
    this.timezone = 'Asia/Jakarta',
    this.ticketPrice = 0,
    this.isActive = true,
  });

  factory Wisata.fromDestination(Destination destination) {
    return Wisata(
      id: destination.guid,
      nama: destination.name,
      lokasi: destination.location,
      deskripsi: destination.description,
      hargaTiket: '${destination.currency} ${destination.ticketPrice}',
      jamBuka: destination.openingHours,
      kategori: destination.category?.name ?? '',
      imageUrl: destination.imageUrl,
      categoryGuid: destination.categoryGuid,
      timezone: destination.timezone,
      ticketPrice: destination.ticketPrice,
      isActive: destination.isActive,
      isLaravel: true,
      rating: destination.ratingAverage ?? 0,
      ratingCount: destination.ratingCount,
    );
  }
}

/// Status pendaftaran:
/// - 'menunggu'  → baru masuk, belum diproses admin
/// - 'disetujui' → admin menekan Setujui
/// - 'ditolak'   → admin menekan Tolak
class Pendaftar {
  String? id; // Laravel booking GUID.
  String userId; // Laravel owner GUID when provided by the server.
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
}

// Runtime presentation models; business records come from Laravel.
List<Wisata> daftarWisata = [];
List<Pendaftar> daftarPendaftar = [];
