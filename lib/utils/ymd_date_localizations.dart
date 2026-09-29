import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Custom MaterialLocalizations override to format and parse compact dates as YYYY/MM/DD
/// when users enter dates via text in DatePickerDialog.
class YmdMaterialLocalizations extends DefaultMaterialLocalizations {
  const YmdMaterialLocalizations();

  @override
  String get dateHelpText => 'yyyy/mm/dd';

  @override
  String formatCompactDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  @override
  DateTime? parseCompactDate(String? inputString) {
    if (inputString == null) return null;
    final normalized = inputString.trim().replaceAll('-', '/');
    final parts = normalized.split('/');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        if (year >= 1900 && year <= 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }
    }
    return super.parseCompactDate(inputString);
  }
}

class YmdLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const YmdLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const YmdMaterialLocalizations();
  }

  @override
  bool shouldReload(YmdLocalizationsDelegate old) => false;
}
