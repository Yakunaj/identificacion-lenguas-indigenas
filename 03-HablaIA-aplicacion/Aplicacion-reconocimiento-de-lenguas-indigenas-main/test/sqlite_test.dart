import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hablaia/estructuras/grabacion_informacion_estructura.dart';
import 'package:hablaia/estructuras/resultado_clasificacion_estructura.dart';
import 'package:hablaia/estructuras/sesion_grabacion_estructura.dart';
import 'package:hablaia/servicios/sqlite_servicio.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ResultadoGrabacion grabacion({
  String idioma = 'maya',
  DateTime? fecha,
  Ubicacion? ubicacion,
  String? rutaSesion,
  int numero = 1,
}) => ResultadoGrabacion(
  numero: numero,
  idioma: idioma,
  confianza: 87.5,
  versionModelo: 'mobilenetv3_es_maya@1.0',
  probabilidadesSegmento: [0.8, 0.95, 0.875],
  fechaHora: fecha ?? DateTime(2026, 11, 17, 10, 30),
  duracion: 15000,
  sampleRate: 44100,
  ubicacion: ubicacion,
  rutaSesion: rutaSesion,
);

ResultadoClasificacion segmento(double pMaya) =>
    ResultadoClasificacion.desdeProbabilidades(
      {'español': 1 - pMaya, 'maya': pMaya},
      versionModelo: 'mobilenetv3_es_maya@1.0',
    );

/// Mérida, Yucatán.
final merida = Ubicacion(latitud: 20.9674, longitud: -89.5926, precisionMetros: 12.5);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory carpeta;

  setUp(() async {
    carpeta = await Directory.systemTemp.createTemp('hablaia_db_');
    GrabacionesDb.rutaPersonalizada = p.join(carpeta.path, 'uuy.db');
  });

  tearDown(() async {
    await GrabacionesDb.cerrar();
    await carpeta.delete(recursive: true);
  });

  group('GrabacionesDb', () {
    test('guarda y lee todos los campos, con ubicación', () async {
      final id = await GrabacionesDb.insertar(grabacion(ubicacion: merida));
      expect(id, greaterThan(0));

      final [leida] = await GrabacionesDb.todas();
      expect(leida.id, id);
      expect(leida.numero, 1);
      expect(leida.idioma, 'maya');
      expect(leida.confianza, 87.5);
      expect(leida.versionModelo, 'mobilenetv3_es_maya@1.0');
      expect(leida.probabilidadesSegmento, [0.8, 0.95, 0.875]);
      expect(leida.fechaHora, DateTime(2026, 11, 17, 10, 30));
      expect(leida.duracion, 15000);
      expect(leida.sampleRate, 44100);
      expect(leida.ubicacion, merida);
    });

    test('la ubicación es opcional', () async {
      await GrabacionesDb.insertar(grabacion());
      final [leida] = await GrabacionesDb.todas();
      expect(leida.ubicacion, isNull);
    });

    test('acepta cualquier idioma que devuelva un modelo (con acentos)', () async {
      for (final idioma in ['español', 'maya', 'náhuatl', "tének"]) {
        await GrabacionesDb.insertar(grabacion(idioma: idioma));
      }
      final idiomas = (await GrabacionesDb.todas()).map((g) => g.idioma).toSet();
      expect(idiomas, {'español', 'maya', 'náhuatl', 'tének'});
    });

    test('todas() ordena de la más reciente a la más vieja', () async {
      await GrabacionesDb.insertar(grabacion(fecha: DateTime(2026, 1, 1)));
      await GrabacionesDb.insertar(grabacion(fecha: DateTime(2026, 6, 1)));
      await GrabacionesDb.insertar(grabacion(fecha: DateTime(2026, 3, 1)));
      final fechas = (await GrabacionesDb.todas()).map((g) => g.fechaHora.month);
      expect(fechas, [6, 3, 1]);
    });

    test('eliminar', () async {
      final id = await GrabacionesDb.insertar(grabacion());
      await GrabacionesDb.insertar(grabacion(idioma: 'español'));
      await GrabacionesDb.eliminar(id);
      final [queda] = await GrabacionesDb.todas();
      expect(queda.idioma, 'español');
    });

    test('enArea filtra por coordenadas', () async {
      await GrabacionesDb.insertar(grabacion(ubicacion: merida));
      await GrabacionesDb.insertar(
        grabacion(idioma: 'español', ubicacion: Ubicacion(latitud: 19.4326, longitud: -99.1332)),
      );
      await GrabacionesDb.insertar(grabacion(idioma: 'náhuatl')); // sin ubicación

      // Península de Yucatán.
      final enYucatan = await GrabacionesDb.enArea(
        latitudMin: 18,
        latitudMax: 22,
        longitudMin: -92,
        longitudMax: -86,
      );
      expect(enYucatan.map((g) => g.idioma), ['maya']);
    });

    test('la tabla rechaza coordenadas incompletas o fuera de rango', () async {
      final db = await GrabacionesDb.instancia;
      final base = grabacion().toMap()..remove('id');

      for (final malo in [
        {'latitud': 20.0, 'longitud': null}, // falta longitud
        {'latitud': null, 'longitud': -89.0}, // falta latitud
        {'latitud': 91.0, 'longitud': 0.0},
        {'latitud': 0.0, 'longitud': -181.0},
      ]) {
        await expectLater(
          db.insert(GrabacionesDb.tabla, {...base, ...malo}),
          throwsA(isA<DatabaseException>()),
          reason: '$malo',
        );
      }
    });
  });

  group('conexión con la grabación', () {
    test('guarda la carpeta del audio (no el audio)', () async {
      const ruta = '/data/user/0/com.hablaia/cache/Grabacion_1731850000000';
      await GrabacionesDb.insertar(grabacion(rutaSesion: ruta));
      final [leida] = await GrabacionesDb.todas();
      expect(leida.rutaSesion, ruta);
    });

    test('siguienteNumero cuenta 1, 2, 3 aunque se borren filas', () async {
      expect(await GrabacionesDb.siguienteNumero(), 1);
      final id1 = await GrabacionesDb.insertar(grabacion(numero: 1));
      await GrabacionesDb.insertar(grabacion(numero: 2));
      expect(await GrabacionesDb.siguienteNumero(), 3);
      await GrabacionesDb.eliminar(id1);
      expect(await GrabacionesDb.siguienteNumero(), 3);
    });

    test('eliminarPorRutaSesion borra solo esa grabación', () async {
      await GrabacionesDb.insertar(
        grabacion(rutaSesion: '/data/user/0/com.hablaia/cache/Grabacion_12'),
      );
      await GrabacionesDb.insertar(
        grabacion(rutaSesion: '/data/user/0/com.hablaia/cache/Grabacion_123'),
      );
      await GrabacionesDb.insertar(
        grabacion(rutaSesion: '/data/user/0/com.hablaia/cache/GrabacionX12'),
      );

      // Misma carpeta, pero con la otra forma de ruta que usa Android.
      final borradas = await GrabacionesDb.eliminarPorRutaSesion(
        '/data/data/com.hablaia/cache/Grabacion_12',
      );
      expect(borradas, 1);
      expect(
        (await GrabacionesDb.todas()).map((g) => g.rutaSesion!.split('/').last),
        unorderedEquals(['Grabacion_123', 'GrabacionX12']),
      );
    });
  });

  group('SesionGrabacion', () {
    final inicio = DateTime(2026, 11, 17, 9);

    test('sin segmentos no hay nada que guardar', () {
      final sesion = SesionGrabacion(rutaSesion: '/x/Grabacion_1', inicio: inicio);
      expect(
        sesion.resumir(numero: 1, fin: inicio.add(const Duration(seconds: 3))),
        isNull,
      );
    });

    test('resume por mayoría y guarda en SQLite con ubicación', () async {
      final sesion = SesionGrabacion(rutaSesion: '/x/Grabacion_1', inicio: inicio)
        ..sampleRate = 44100
        ..agregar(segmento(0.9)) // maya 90 %
        ..agregar(segmento(0.3)) // español 70 %
        ..agregar(segmento(0.7)); // maya 70 %

      final fila = sesion.resumir(
        numero: await GrabacionesDb.siguienteNumero(),
        fin: inicio.add(const Duration(seconds: 15, milliseconds: 200)),
        ubicacion: merida,
      )!;

      expect(fila.idioma, 'maya');
      expect(fila.confianza, closeTo(80, 1e-9)); // promedio de 90 y 70
      expect(fila.probabilidadesSegmento, [0.9, 0.3, 0.7]);
      expect(fila.duracion, 15200);
      expect(fila.fechaHora, inicio);
      expect(fila.versionModelo, 'mobilenetv3_es_maya@1.0');

      await GrabacionesDb.insertar(fila);
      final [leida] = await GrabacionesDb.todas();
      expect(leida.numero, 1);
      expect(leida.idioma, 'maya');
      expect(leida.ubicacion, merida);
      expect(leida.rutaSesion, '/x/Grabacion_1');
      expect(leida.sampleRate, 44100);
    });

    test('en empate gana el idioma que apareció primero', () {
      final sesion = SesionGrabacion(rutaSesion: '/x/Grabacion_1', inicio: inicio)
        ..agregar(segmento(0.2)) // español
        ..agregar(segmento(0.9)); // maya
      expect(sesion.resumir(numero: 1, fin: inicio)!.idioma, 'español');
    });
  });

  group('migración desde la versión 1', () {
    test('conserva las filas y permite guardar ubicación e idiomas nuevos', () async {
      // Base de datos con el esquema original exacto (v1).
      final v1 = await openDatabase(
        GrabacionesDb.rutaPersonalizada!,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE grabaciones (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              numero INTEGER NOT NULL,
              idioma TEXT NOT NULL CHECK (idioma IN ('espanol', 'maya')),
              confianza REAL NOT NULL,
              version_modelo TEXT NOT NULL,
              prob_segmentos TEXT NOT NULL,
              fecha_hora TEXT NOT NULL,
              duracion INTEGER NOT NULL,
              sample_rate_original INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_grabaciones_fecha ON grabaciones (fecha_hora)');
          await db.execute('CREATE INDEX idx_grabaciones_idioma ON grabaciones (idioma)');
        },
      );
      await v1.insert('grabaciones', {
        'numero': 7,
        'idioma': 'maya',
        'confianza': 91.0,
        'version_modelo': 'viejo@0.9',
        'prob_segmentos': '[0.91]',
        'fecha_hora': '2025-05-30T13:36:00.000',
        'duracion': 5000,
        'sample_rate_original': 44100,
      });
      await v1.close();

      // Abrir con el código actual dispara la migración.
      final db = await GrabacionesDb.instancia;
      expect(await db.getVersion(), GrabacionesDb.version);

      final [vieja] = await GrabacionesDb.todas();
      expect(vieja.numero, 7);
      expect(vieja.duracion, 5000);
      expect(vieja.versionModelo, 'viejo@0.9');
      expect(vieja.ubicacion, isNull);

      await GrabacionesDb.insertar(grabacion(idioma: 'español', ubicacion: merida));
      expect(await GrabacionesDb.todas(), hasLength(2));

      final indices = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'grabaciones'",
      );
      expect(
        indices.map((f) => f['name']),
        containsAll(['idx_grabaciones_fecha', 'idx_grabaciones_idioma', 'idx_grabaciones_ubicacion']),
      );
    });
  });

  group('Ubicacion', () {
    test('rechaza coordenadas inválidas', () {
      expect(() => Ubicacion(latitud: 90.1, longitud: 0), throwsArgumentError);
      expect(() => Ubicacion(latitud: 0, longitud: 180.5), throwsArgumentError);
      expect(() => Ubicacion(latitud: double.nan, longitud: 0), throwsArgumentError);
      expect(
        () => Ubicacion(latitud: 0, longitud: 0, precisionMetros: -1),
        throwsArgumentError,
      );
      expect(Ubicacion(latitud: -90, longitud: 180).latitud, -90);
    });
  });
}
