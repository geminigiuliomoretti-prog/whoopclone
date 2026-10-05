import 'package:flutter/material.dart';
import '../../core/constants/whoop_theme.dart';

enum DataProvenance {
  real,
  userEntered,
  bootstrap,
  partial,
  derived,
  unknown;

  String toDbString() {
    switch (this) {
      case DataProvenance.real:
        return 'REAL';
      case DataProvenance.userEntered:
        return 'USER_ENTERED';
      case DataProvenance.bootstrap:
        return 'BOOTSTRAP';
      case DataProvenance.partial:
        return 'PARTIAL';
      case DataProvenance.derived:
        return 'DERIVED';
      case DataProvenance.unknown:
        return 'UNKNOWN';
    }
  }
}

/// Badge visivo di provenienza dati (MCK-02 / MCK-03).
/// Informa chiaramente l'utente sull'origine della sessione di sonno, del recupero o delle metriche
/// (es. REAL da fascia BLE, USER_ENTERED da inserimento manuale, BOOTSTRAP da profilo iniziale, PARTIAL da finestra ridotta).
class ProvenanceBadge extends StatelessWidget {
  final String? provenance;
  final double fontSize;
  final EdgeInsets padding;

  const ProvenanceBadge({
    super.key,
    required dynamic provenance,
    this.fontSize = 9.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
  }) : provenance = provenance == DataProvenance.real
            ? 'REAL'
            : provenance == DataProvenance.userEntered
                ? 'USER_ENTERED'
                : provenance == DataProvenance.bootstrap
                    ? 'BOOTSTRAP'
                    : provenance == DataProvenance.partial
                        ? 'PARTIAL'
                        : provenance == DataProvenance.derived
                            ? 'DERIVED'
                            : (provenance is String ? provenance : null);

  const ProvenanceBadge.fromString(
    String? str, {
    super.key,
    this.fontSize = 9.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
  }) : provenance = str;

  @override
  Widget build(BuildContext context) {
    if (provenance == null || provenance!.isEmpty) {
      return const SizedBox.shrink();
    }

    final prov = provenance!.toUpperCase();

    Color bgColor;
    Color textColor;
    Color borderColor;
    String label;
    IconData icon;

    switch (prov) {
      case 'REAL':
        bgColor = const Color(0xFF132B1D);
        textColor = const Color(0xFF38E54D);
        borderColor = const Color(0xFF235A35);
        label = 'REALE';
        icon = Icons.bluetooth_connected;
        break;
      case 'USER_ENTERED':
      case 'MANUAL':
        bgColor = const Color(0xFF32230D);
        textColor = const Color(0xFFFFB74D);
        borderColor = const Color(0xFF6E4A1B);
        label = 'MANUALE';
        icon = Icons.edit_note;
        break;
      case 'BOOTSTRAP':
        bgColor = const Color(0xFF1B2338);
        textColor = const Color(0xFF64B5F6);
        borderColor = const Color(0xFF2A4374);
        label = 'BOOTSTRAP';
        icon = Icons.auto_awesome;
        break;
      case 'PARTIAL':
        bgColor = const Color(0xFF352F11);
        textColor = const Color(0xFFFFD54F);
        borderColor = const Color(0xFF706118);
        label = 'PARZIALE';
        icon = Icons.timelapse;
        break;
      case 'DERIVED':
      case 'CACHED':
        bgColor = const Color(0xFF1C2229);
        textColor = const Color(0xFF90A4AE);
        borderColor = const Color(0xFF37474F);
        label = prov;
        icon = Icons.insights;
        break;
      default:
        bgColor = const Color(0xFF1C2229);
        textColor = WhoopTheme.textMuted;
        borderColor = WhoopTheme.cardBorder;
        label = prov;
        icon = Icons.info_outline;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
