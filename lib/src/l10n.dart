// Localization: English is the source language, Italian the first translation (lib/l10n/*.arb,
// generated with `flutter gen-l10n`). The embedder passes the system languages
// (FlutterEngineUpdateLocales); the root resolves them against the supported locales, falling
// back to English.
//
// Strings are also needed outside widgets (file operations, sizes, dates, types), so the resolved
// translation is kept in [l10n]; [AppLocalizationsScope] keeps it in step with the platform and
// rebuilds the tree when the languages change.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// The languages Mustache is translated into.
const List<Locale> supportedLocales = [Locale('en'), Locale('it')];

AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

/// The texts in the resolved language (English until the root resolves the platform's).
AppLocalizations get l10n => _current;

/// The first preferred language Mustache has, otherwise English.
Locale resolveLocale(Iterable<Locale> preferred) {
  for (final locale in preferred) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return supportedLocales.first;
}

/// Uses the translation of `locale` from now on (tests, and the root on a language change).
void useLocale(Locale locale) =>
    _current = lookupAppLocalizations(resolveLocale([locale]));

/// The root of the tree: resolves the platform languages, keeps [l10n] in step and provides
/// [Localizations] to the widgets below.
class AppLocalizationsScope extends StatefulWidget {
  const AppLocalizationsScope({super.key, required this.child, this.locale});

  final Widget child;

  /// A fixed language (tests); null: the platform's.
  final Locale? locale;

  @override
  State<AppLocalizationsScope> createState() => _AppLocalizationsScopeState();
}

class _AppLocalizationsScopeState extends State<AppLocalizationsScope>
    with WidgetsBindingObserver {
  late Locale _locale = _resolve();

  Locale _resolve() =>
      resolveLocale([?widget.locale, ...PlatformDispatcher.instance.locales]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    useLocale(_locale);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final locale = _resolve();
    if (locale == _locale) return;
    setState(() => _locale = locale);
    useLocale(locale);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Localizations(
    locale: _locale,
    delegates: const [
      AppLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    child: widget.child,
  );
}

/// Two digits, for times.
String _two(int v) => v.toString().padLeft(2, '0');

/// "HH:MM" (24 hours in both languages).
String clockTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// A date with the short month name ("13 ott 2026, 12:56", "Oct 13, 2026, 12:56").
String shortDate(DateTime t) => l10n.dateShort(
  '${t.day}',
  l10n.monthsShort.split(',')[t.month - 1],
  '${t.year}',
  clockTime(t),
);

/// A date with the full month name ("13 ottobre 2026, 12:56").
String longDate(DateTime t) => l10n.dateLong(
  '${t.day}',
  l10n.monthsLong.split(',')[t.month - 1],
  '${t.year}',
  clockTime(t),
);

/// `value` with `digits` decimals and the language's decimal separator.
String decimal(double value, int digits) =>
    value.toStringAsFixed(digits).replaceAll('.', l10n.decimalSeparator);
