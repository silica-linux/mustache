// The emoji of the folder emoji picker (folder_customize.dart): the whole Unicode set (fully
// qualified, without skin-tone variants, up to the Emoji version the system font draws), in the
// eight categories of the bar, with the CLDR names and keywords in English and Italian for the
// search. The table is generated: `emoji_table.g.dart`, by `tool/gen_emoji.dart`.

import 'emoji_table.g.dart';

/// One emoji with its search keywords.
typedef EmojiItem = ({String emoji, String keywords});

/// A category of the picker: the emoji on its bar button and its items.
typedef EmojiCategory = ({String icon, List<EmojiItem> items});

/// The emoji of each group of [emojiTable], keywords being every name and keyword of the
/// emoji (English and Italian, lower case).
Map<String, List<EmojiItem>> parseEmojiTable(String table) {
  final groups = <String, List<EmojiItem>>{};
  var items = <EmojiItem>[];
  for (final line in table.split('\n')) {
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      items = groups.putIfAbsent(line.substring(1), () => []);
      continue;
    }
    final fields = line.split('\t');
    if (fields.isEmpty || fields.first.isEmpty) continue;
    items.add((
      emoji: fields.first,
      keywords: fields.skip(1).where((f) => f.isNotEmpty).join('|'),
    ));
  }
  return groups;
}

/// The frequently used emoji before the user has used any.
const List<String> defaultFrequentEmoji = [
  '😀', '😂', '❤️', '👍', '🎉', '🔥', '⭐', '🎵', '📁', '🏠', '💼', '📷', //
  '🎮', '📚', '✈️', '🍕', '🌳', '💡', '🔒', '🛠️', '🎨', '💰', '🧳', '🎬',
];

/// The frequently used emoji, most recent first (kept for the session; the defaults at first).
final List<String> frequentEmoji = [...defaultFrequentEmoji];

/// [emoji] was picked: it goes first among the frequent ones.
void useEmoji(String emoji) {
  frequentEmoji
    ..remove(emoji)
    ..insert(0, emoji);
  if (frequentEmoji.length > 24) frequentEmoji.length = 24;
}

/// The categories in the order of the bar (frequently used comes before them in the picker).
final List<EmojiCategory> emojiCategories = () {
  final groups = parseEmojiTable(emojiTable);
  const bar = [
    ('smileys', '😀'),
    ('animals', '🐻'),
    ('food', '🍔'),
    ('activity', '⚽'),
    ('travel', '🚗'),
    ('objects', '💡'),
    ('symbols', '❤️'),
    ('flags', '🏁'),
  ];
  return [
    for (final (id, icon) in bar)
      if (groups[id] case final items? when items.isNotEmpty)
        (icon: icon, items: items),
  ];
}();

/// The emoji whose names and keywords (or the emoji itself) contain every word of [query]; the
/// ones whose English name has them all come first.
List<EmojiItem> searchEmoji(String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  final named = <EmojiItem>[];
  final other = <EmojiItem>[];
  for (final c in emojiCategories) {
    for (final item in c.items) {
      if (!words.every(
        (w) => item.keywords.contains(w) || item.emoji.contains(w),
      )) {
        continue;
      }
      final name = item.keywords.split('|').first;
      (words.every(name.contains) ? named : other).add(item);
    }
  }
  return [...named, ...other];
}
