import 'package:flutter/material.dart';

class KelolaAdminScreen extends StatelessWidget {
  const KelolaAdminScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kelola Admin')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Pengelolaan daftar dan penghapusan admin belum tersedia melalui API.'),
          ),
        ),
      );
}
