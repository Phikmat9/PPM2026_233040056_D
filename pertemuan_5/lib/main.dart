import 'package:flutter/material.dart';
import 'db_helper.dart'; // Menghubungkan ke berkas DbHelper

void main() {
  // Wajib dipanggil agar platform channel SQLite bisa berkomunikasi sebelum runApp berjalan
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Mahasiswa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomePage());
          case '/form':
            final argumen = settings.arguments as Catatan?;
            return MaterialPageRoute(
              builder: (_) => CatatanFormPage(initial: argumen),
            );
          case '/detail':
            final catatan = settings.arguments as Catatan;
            return MaterialPageRoute(
              builder: (_) => DetailCatatanPage(catatan: catatan),
            );
        }
        return null;
      },
    );
  }
}

// =========================================================================
// MODEL DATA (Mendukung Konversi Objek Dart ↔ Baris Database Map)
// =========================================================================
class Catatan {
  final int? id; // Berubah jadi int? (nullable) mengikuti struktur AUTOINCREMENT SQLite
  final String judul;
  final String isi;
  final String kategori;
  final String email;
  final DateTime dibuatPada;

  Catatan({
    this.id,
    required this.judul,
    required this.isi,
    required this.kategori,
    required this.email,
    required this.dibuatPada,
  });

  // Fungsi mengonversi Objek Dart ke Map sebelum dimasukkan ke SQLite
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'judul': judul,
    'isi': isi,
    'kategori': kategori,
    'email': email,
    'dibuat_pada': dibuatPada.millisecondsSinceEpoch, // DateTime disimpan sebagai milidetik (int)
  };

  // Fungsi mengonversi Baris Data Map dari SQLite kembali menjadi Objek Dart
  static Catatan fromMap(Map<String, Object?> m) => Catatan(
    id: m['id'] as int?,
    judul: m['judul'] as String,
    isi: m['isi'] as String,
    kategori: m['kategori'] as String,
    email: m['email'] as String,
    dibuatPada: DateTime.fromMillisecondsSinceEpoch(m['dibuat_pada'] as int),
  );

  // Helper CopyWith untuk mempermudah penggantian field data saat melakukan Edit
  Catatan copyWith({String? judul, String? isi, String? kategori, String? email}) =>
      Catatan(
        id: id,
        judul: judul ?? this.judul,
        isi: isi ?? this.isi,
        kategori: kategori ?? this.kategori,
        email: email ?? this.email,
        dibuatPada: dibuatPada,
      );
}

// =========================================================================
// HALAMAN 1: HOME PAGE (MENGGUNAKAN FUTUREBUILDER & LOGIKA FILTER)
// =========================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Penampung state asinkron untuk daftar catatan
  late Future<List<Catatan>> _futureCatatan;

  String _filterTerpilih = 'Semua';
  final List<String> _opsiFilter = const ['Semua', 'Kuliah', 'Tugas', 'Pribadi', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    _muatUlangData(); // Ambil data dari database saat aplikasi pertama kali dibuka
  }

  // Fungsi utama untuk memicu pengambilan data ulang ke database (Source of Truth)
  void _muatUlangData() {
    setState(() {
      _futureCatatan = DbHelper.instance.getAll();
    });
  }

  String _formatTanggal(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _bukaForm({Catatan? initial}) async {
    // Menunggu form ditutup, lalu panggil _muatUlangData()
    await Navigator.pushNamed(context, '/form', arguments: initial);
    if (!mounted) return; // FIX: Menghindari async gaps warning
    _muatUlangData();
  }

  Future<void> _bukaDetailCatatan(Catatan dataCatatan) async {
    await Navigator.pushNamed(context, '/detail', arguments: dataCatatan);
    if (!mounted) return; // FIX: Menghindari async gaps warning
    _muatUlangData();
  }

  // Dialog konfirmasi untuk aksi destruktif (Hapus Data)
  Future<void> _konfirmasiHapus(Catatan c) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: Text('Catatan "${c.judul}" akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (yakin == true && mounted) {
      await DbHelper.instance.delete(c.id!); // Eksekusi hapus di DB
      if (!mounted) return; // FIX: Menghindari async gaps warning
      _muatUlangData(); // Segarkan UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catatan "${c.judul}" telah dihapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Mahasiswa', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _filterTerpilih,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.indigo),
              items: _opsiFilter.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
                );
              }).toList(),
              onChanged: (String? nilaiBaru) {
                if (nilaiBaru != null) {
                  setState(() {
                    _filterTerpilih = nilaiBaru;
                  });
                }
              },
            ),
          )
        ],
      ),
      body: FutureBuilder<List<Catatan>>(
        future: _futureCatatan,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final dataAsli = snapshot.data ?? const [];

          final listCatatanTerfilter = dataAsli.where((item) {
            if (_filterTerpilih == 'Semua') return true;
            return item.kategori == _filterTerpilih;
          }).toList();

          if (listCatatanTerfilter.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    dataAsli.isEmpty ? 'Belum ada catatan.' : 'Tidak ada catatan kategori "$_filterTerpilih"',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: listCatatanTerfilter.length,
            itemBuilder: (context, i) {
              final c = listCatatanTerfilter[i];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(c.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Kategori: ${c.kategori} | Oleh: ${c.email}'),
                      Text(_formatTanggal(c.dibuatPada), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.amber),
                        onPressed: () => _bukaForm(initial: c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _konfirmasiHapus(c),
                      ),
                    ],
                  ),
                  onTap: () => _bukaDetailCatatan(c),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _bukaForm(),
        tooltip: 'Tambah Catatan Baru',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// =========================================================================
// HALAMAN 2: REUSABLE FORM (MENDUKUNG MODE CREATE + MODE EDIT)
// =========================================================================
class CatatanFormPage extends StatefulWidget {
  final Catatan? initial;

  const CatatanFormPage({super.key, this.initial});

  @override
  State<CatatanFormPage> createState() => _CatatanFormPageState();
}

class _CatatanFormPageState extends State<CatatanFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulCtrl;
  late final TextEditingController _isiCtrl;
  late final TextEditingController _emailCtrl;

  late String _kategori;
  final _kategoriOpsi = const ['Kuliah', 'Tugas', 'Pribadi', 'Lainnya'];

  bool get _isEditMode => widget.initial != null;
  bool _sedangMenyimpan = false;

  @override
  void initState() {
    super.initState();
    _judulCtrl = TextEditingController(text: widget.initial?.judul ?? '');
    _isiCtrl = TextEditingController(text: widget.initial?.isi ?? '');
    _emailCtrl = TextEditingController(text: widget.initial?.email ?? '');
    _kategori = widget.initial?.kategori ?? 'Kuliah';
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _isiCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMenyimpan = true);

    try {
      if (_isEditMode) {
        final dataTerupdate = widget.initial!.copyWith(
          judul: _judulCtrl.text.trim(),
          isi: _isiCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          kategori: _kategori,
        );
        await DbHelper.instance.update(dataTerupdate);
      } else {
        final dataBaru = Catatan(
          judul: _judulCtrl.text.trim(),
          isi: _isiCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          kategori: _kategori,
          dibuatPada: DateTime.now(),
        );
        await DbHelper.instance.insert(dataBaru);
      }

      if (!mounted) return; // FIX: Menghindari async gaps warning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Catatan berhasil diperbarui!' : 'Catatan berhasil disimpan!'),
          backgroundColor: _isEditMode ? Colors.blue : Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sedangMenyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Catatan' : 'Tambah Catatan Baru'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _judulCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Catatan',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Judul wajib diisi!';
                if (v.trim().length < 3) return 'Judul minimal berisi 3 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Pengirim',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email wajib diisi!';
                final regexEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!regexEmail.hasMatch(v.trim())) {
                  return 'Format email tidak valid!';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _kategori, // FIX: Mengubah dari 'value' menjadi 'initialValue' demi menghindari deprecation warning
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _kategoriOpsi.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) => setState(() => _kategori = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _isiCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Isi Catatan',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Isi catatan tidak boleh kosong!';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sedangMenyimpan ? null : _simpan,
              icon: _sedangMenyimpan
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_isEditMode ? Icons.update : Icons.save),
              label: Text(
                _isEditMode ? 'Perbarui Catatan' : 'Simpan Catatan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// HALAMAN 3: DETAIL CATATAN (STATELESS VIEW)
// =========================================================================
class DetailCatatanPage extends StatelessWidget {
  final Catatan catatan;

  const DetailCatatanPage({super.key, required this.catatan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Catatan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.pushNamed(context, '/form', arguments: catatan);
              if (!context.mounted) return; // FIX: Menghindari async gaps warning
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(catatan.judul, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(catatan.kategori, style: const TextStyle(fontWeight: FontWeight.bold)),
                  avatar: const Icon(Icons.label, size: 16),
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  '${catatan.dibuatPada.day}/${catatan.dibuatPada.month}/${catatan.dibuatPada.year}',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text('Pengirim: ${catatan.email}', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
            const Divider(height: 32, thickness: 1.2),
            Text(catatan.isi, style: const TextStyle(fontSize: 16, height: 1.6)),
            const SizedBox(height: 40),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
              ),
            )
          ],
        ),
      ),
    );
  }
}