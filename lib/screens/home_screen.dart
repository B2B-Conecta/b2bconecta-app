import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/part_model.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

const _kCorporateRed = Color(0xFFE31B23);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<PartModel>> _partsFuture;

  @override
  void initState() {
    super.initState();
    _partsFuture = SupabaseService.fetchParts();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'MotoLink Pro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: _kCorporateRed),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(
                color: _kCorporateRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: const Text(
              'Repuestos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PartModel>>(
              future: _partsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _kCorporateRed),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade700),
                          const SizedBox(height: 12),
                          Text(
                            'No se pudieron cargar los repuestos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final parts = snapshot.data ?? [];
                if (parts.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay repuestos disponibles.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: parts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    return _PartCard(part: part);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 88,
                height: 88,
                child: part.imagenUrl != null && part.imagenUrl!.isNotEmpty
                    ? Image.network(
                        part.imagenUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${part.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kCorporateRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${part.stock}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Icon(Icons.precision_manufacturing_outlined,
          size: 40, color: Colors.grey.shade500),
    );
  }
}
