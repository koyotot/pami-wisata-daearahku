// ============================================================
// lib/theme/app_colors.dart
// ============================================================
// Satu sumber kebenaran untuk semua warna tema aplikasi.
// Cara pakai: import 'package:nama_app/theme/app_colors.dart';
// Ganti _C.teal → AppColors.teal, dst.
// ============================================================

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Tidak bisa di-instantiate

  // ── Background & Surface ──────────────────────────────────
  static const bg = Color(0xFF0D1B1E); // Latar utama (paling gelap)
  static const surface = Color(0xFF142226); // Latar section
  static const card = Color(0xFF1A2D32); // Latar kartu
  static const border = Color(0xFF254A44); // Garis batas default
  static const borderAlt = Color(0xFF1F3A40); // Garis batas alternatif

  // ── Teal (warna utama) ────────────────────────────────────
  static const teal = Color(0xFF0BC5A0);
  static const tealDark = Color(0xFF07897A);
  static const tealDeep = Color(0xFF054D44);

  // ── Gold (aksen premium) ──────────────────────────────────
  static const gold = Color(0xFFE8B86D);
  static const goldLight = Color(0xFFF5D49A);

  // ── Teks ─────────────────────────────────────────────────
  static const text = Color(0xFFEEF2F0); // Teks utama
  static const textMuted = Color(0xFF7FA89C); // Teks sekunder
  static const textDim = Color(0xFF4A706A); // Teks tersier / placeholder

  // ── Status & Semantik ─────────────────────────────────────
  static const danger = Color(0xFFFF6B6B); // Error / hapus / keluar
  static const success = Color(0xFF4ADE80); // Sukses / konfirmasi
  static const info = Color(0xFF38BDF8); // Informasi
  static const warning = Color(0xFFFB923C); // Peringatan

  // ── Warna tambahan (admin dashboard) ─────────────────────
  static const purple = Color(0xFFA78BFA);
  static const slate = Color(0xFF94A3B8);
}
