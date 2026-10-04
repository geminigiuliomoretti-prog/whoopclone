import '../models/ciclo_fisiologico.dart';
import '../models/allenamento.dart';
import '../models/voce_diario.dart';
import '../models/sonno.dart';

/// Interfaccia astratta del Repository per l'accesso ai dati Whoop
abstract class WhoopRepository {
  Future<void> initializeAndSeedDatabase();
  
  // Cicli Fisiologici
  Future<List<CicloFisiologico>> getCicliFisiologici();
  Future<CicloFisiologico?> getUltimoCicloFisiologico();
  Future<void> insertCicloFisiologico(CicloFisiologico ciclo);

  // Allenamenti
  Future<List<Allenamento>> getAllenamenti();
  Future<List<Allenamento>> getAllenamentiPerCiclo(String oraInizioCiclo);
  Future<void> insertAllenamento(Allenamento allenamento);

  // Voci Diario
  Future<List<VoceDiario>> getVociDiario();
  Future<List<VoceDiario>> getVociDiarioPerCiclo(String oraInizioCiclo);
  Future<void> insertVoceDiario(VoceDiario voce);

  // Sonno
  Future<List<Sonno>> getSonnoLogs();
  Future<Sonno?> getSonnoPerCiclo(String oraInizioCiclo);
  Future<void> insertSonno(Sonno sonno);
}
