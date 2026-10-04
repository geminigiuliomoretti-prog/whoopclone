import 'package:flutter/foundation.dart';

/// Modello per la tabella `voci_diario`
/// Schema: id (PK AUTOINCREMENT), data_iso, chiave_domanda, risposta_bool, note.
@immutable
class VoceDiario {
  final int? id;
  final String dataIso; // YYYY-MM-DD
  final String chiaveDomanda;
  final bool rispostaBool;
  final String? note;

  const VoceDiario({
    this.id,
    required this.dataIso,
    required this.chiaveDomanda,
    required this.rispostaBool,
    this.note,
  });

  // Getters di compatibilità per la UI
  String get testoDomanda => chiaveDomanda;
  bool get rispostaAffermativa => rispostaBool;
  DateTime get oraInizioCiclo => DateTime.tryParse('${dataIso}T00:00:00.000Z') ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'data_iso': dataIso,
      'chiave_domanda': chiaveDomanda,
      'risposta_bool': rispostaBool ? 1 : 0,
      'note': note,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory VoceDiario.fromMap(Map<String, dynamic> map) {
    String dIso = map['data_iso'] as String? ?? '';
    if (dIso.isEmpty && map['ora_inizio_ciclo'] != null) {
      dIso = (map['ora_inizio_ciclo'] as String).substring(0, 10);
    } else if (dIso.isEmpty) {
      dIso = DateTime.now().toIso8601String().substring(0, 10);
    }

    return VoceDiario(
      id: map['id'] as int?,
      dataIso: dIso,
      chiaveDomanda: map['chiave_domanda'] as String? ?? map['testo_domanda'] as String? ?? '',
      rispostaBool: (map['risposta_bool'] ?? map['risposta_affermativa'] as int?) == 1,
      note: map['note'] as String?,
    );
  }
}
