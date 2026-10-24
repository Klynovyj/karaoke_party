/// Formatiert ein Datum als "TT.MM.JJJJ HH:MM" ohne externe intl-Abhängigkeit.
String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
