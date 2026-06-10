import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'main.dart' show Catatan;

class DbHelper {
  // Private constructor agar class ini tidak bisa diinstansiasi dari luar (Singleton)
  DbHelper._();
  static final DbHelper instance = DbHelper._(); // Satu-satunya instance yang dipakai global

  static const _dbName = 'catatan_mahasiswa.db';
  static const _dbVersion = 1;
  static const tabel = 'catatan';

  Database? _db;

  // Getter untuk mengambil koneksi database yang sedang aktif
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  // Fungsi untuk membuka koneksi ke file database (.db)
  Future<Database> _openDb() async {
    final dir = await getDatabasesPath(); // Mengambil path folder database bawaan sistem HP
    final path = join(dir, _dbName);      // Menggabungkan path folder dengan nama file DB

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        // Query SQL untuk membuat tabel pertama kali saat aplikasi diinstal
        await db.execute('''
          CREATE TABLE $tabel (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            judul       TEXT NOT NULL,
            isi         TEXT NOT NULL,
            kategori    TEXT NOT NULL,
            email       TEXT NOT NULL,
            dibuat_pada INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // =========================================================================
  // OPERASI CRUD
  // =========================================================================

  // 1. CREATE (Tambah Data Baru)
  Future<int> insert(Catatan c) async {
    final db = await database;
    return db.insert(tabel, c.toMap());
  }

  // 2. READ (Ambil Semua Data, diurutkan dari yang terbaru dibuat)
  Future<List<Catatan>> getAll() async {
    final db = await database;
    final rows = await db.query(tabel, orderBy: 'dibuat_pada DESC');
    return rows.map(Catatan.fromMap).toList(); // Memetakan Map database menjadi Objek Dart
  }

  // 3. UPDATE (Perbarui Data Lama berdasarkan ID)
  Future<int> update(Catatan c) async {
    assert(c.id != null, 'Gagal update: ID Catatan tidak boleh null!');
    final db = await database;
    return db.update(
      tabel,
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  // 4. DELETE (Hapus Data berdasarkan ID)
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(
      tabel,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}