import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../estructuras/grabacion_informacion_estructura.dart';

class GrabacionesDb {
  static const _nombre = 'uuy.db';

  /// v1: tabla original.
  /// v2: columna `duracion` -> `duracion_ms`, sin restricción de idiomas
  ///     (los modelos pueden tener cualquier etiqueta) y con ubicación
  ///     (`latitud`, `longitud`, `precision_metros`) y la carpeta del audio
  ///     (`ruta_sesion`; el audio se queda en disco, no en la base).
  static const version = 2;
  static const tabla = 'grabaciones';

  static Database? db;

  /// Solo para tests: ruta de la base de datos en lugar de la del sistema.
  @visibleForTesting
  static String? rutaPersonalizada;

  static Future<Database> get instancia async {
    db ??= await _abrir();
    return db!;
  }

  static Future<void> cerrar() async {
    await db?.close();
    db = null;
  }

  static Future<Database> _abrir() async {
    final ruta = rutaPersonalizada ?? join(await getDatabasesPath(), _nombre);
    return openDatabase(
      ruta,
      version: version,
      onCreate: (db, version) async {
        await _crearTabla(db, tabla);
        await _crearIndices(db);
      },
      onUpgrade: (db, versionAnterior, versionNueva) async {
        if (versionAnterior < 2) await _migrarAv2(db);
      },
    );
  }

  static Future<void> _crearTabla(DatabaseExecutor db, String nombre) =>
      db.execute('''
        CREATE TABLE $nombre (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero INTEGER NOT NULL,
          idioma TEXT NOT NULL,
          confianza REAL NOT NULL,
          version_modelo TEXT NOT NULL,
          prob_segmentos TEXT NOT NULL,
          fecha_hora TEXT NOT NULL,
          duracion_ms INTEGER NOT NULL,
          sample_rate_original INTEGER NOT NULL,
          latitud REAL CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),
          longitud REAL CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180),
          precision_metros REAL,
          ruta_sesion TEXT,
          CHECK ((latitud IS NULL) = (longitud IS NULL))
        )
      ''');

  static Future<void> _crearIndices(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_grabaciones_fecha ON $tabla (fecha_hora)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_grabaciones_idioma ON $tabla (idioma)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_grabaciones_ubicacion ON $tabla (latitud, longitud)',
    );
  }

  /// SQLite no permite quitar un CHECK ni renombrar columnas en versiones
  /// viejas de Android, así que se reconstruye la tabla conservando las filas.
  static Future<void> _migrarAv2(DatabaseExecutor db) async {
    const temporal = '${tabla}_v2';
    await _crearTabla(db, temporal);
    await db.execute('''
      INSERT INTO $temporal (id, numero, idioma, confianza, version_modelo,
        prob_segmentos, fecha_hora, duracion_ms, sample_rate_original)
      SELECT id, numero, idioma, confianza, version_modelo,
        prob_segmentos, fecha_hora, duracion, sample_rate_original
      FROM $tabla
    ''');
    await db.execute('DROP TABLE $tabla');
    await db.execute('ALTER TABLE $temporal RENAME TO $tabla');
    await _crearIndices(db);
  }

  static Future<int> insertar(ResultadoGrabacion r) async {
    final db = await instancia;
    return db.insert(tabla, r.toMap()..remove('id'));
  }

  static Future<List<ResultadoGrabacion>> todas() async {
    final db = await instancia;
    final filas = await db.query(tabla, orderBy: 'fecha_hora DESC');
    return filas.map(ResultadoGrabacion.fromMap).toList();
  }

  /// Grabaciones hechas dentro de un rectángulo de coordenadas
  /// (p. ej. lo visible en un mapa).
  static Future<List<ResultadoGrabacion>> enArea({
    required double latitudMin,
    required double latitudMax,
    required double longitudMin,
    required double longitudMax,
  }) async {
    final db = await instancia;
    final filas = await db.query(
      tabla,
      where: 'latitud BETWEEN ? AND ? AND longitud BETWEEN ? AND ?',
      whereArgs: [latitudMin, latitudMax, longitudMin, longitudMax],
      orderBy: 'fecha_hora DESC',
    );
    return filas.map(ResultadoGrabacion.fromMap).toList();
  }

  /// Número para la siguiente grabación (1, 2, 3, ...).
  static Future<int> siguienteNumero() async {
    final db = await instancia;
    final fila = await db.rawQuery('SELECT MAX(numero) AS maximo FROM $tabla');
    return ((fila.first['maximo'] as int?) ?? 0) + 1;
  }

  /// Borra las filas de una grabación cuando se elimina su carpeta.
  /// Compara también por nombre de carpeta (`Grabacion_<timestamp>`, único),
  /// porque Android puede dar la misma carpeta como /data/user/0/... o
  /// /data/data/...
  static Future<int> eliminarPorRutaSesion(String rutaSesion) async {
    final db = await instancia;
    final nombre = basename(rutaSesion);
    return db.delete(
      tabla,
      where: r"ruta_sesion = ? OR ruta_sesion LIKE ? ESCAPE '\'",
      whereArgs: [rutaSesion, '%/${nombre.replaceAll('_', r'\_')}'],
    );
  }

  static Future<void> eliminar(int id) async {
    final db = await instancia;
    await db.delete(tabla, where: 'id = ?', whereArgs: [id]);
  }
}
