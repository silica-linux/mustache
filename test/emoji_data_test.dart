import 'package:flutter_test/flutter_test.dart';
import 'package:mustache/src/emoji_data.dart';

void main() {
  test('the picker offers the full Unicode set in the eight categories', () {
    expect(emojiCategories, hasLength(8));
    final all = [
      for (final c in emojiCategories)
        for (final e in c.items) e.emoji,
    ];
    expect(all.length, greaterThan(1800));
    expect(all.toSet().length, all.length, reason: 'no emoji twice');
    for (final c in emojiCategories) {
      expect(c.items, isNotEmpty);
    }
    // People and body are with the smileys; flags, sequences and ZWJ emoji are in.
    expect(
      all,
      containsAll(['😀', '👍', '🐱', '🍕', '⚽', '🚗', '💡', '❤️', '🇮🇹']),
    );
    expect(all, contains('👨‍👩‍👧‍👦'));
    expect(all, contains('🏳️‍🌈'));
    // The 'component' group (skin tones, hair) and variants with a tone are not listed.
    expect(all.any((e) => e.contains('\u{1F3FB}')), isFalse);
  });

  test('search finds emoji by their CLDR names, in English and in Italian', () {
    String first(String q) => searchEmoji(q).first.emoji;
    expect(searchEmoji('cat').map((e) => e.emoji), contains('🐱'));
    expect(searchEmoji('gatto').map((e) => e.emoji), contains('🐱'));
    expect(searchEmoji('pizza').map((e) => e.emoji), contains('🍕'));
    expect(first('grinning face'), '😀');
    expect(first('pizza'), '🍕');
    expect(
      searchEmoji('bandiera italia').map((e) => e.emoji),
      contains('🇮🇹'),
    );
    expect(searchEmoji('GRINNING FACE').map((e) => e.emoji), contains('😀'));
    expect(searchEmoji('zzzzqqq'), isEmpty);
    expect(searchEmoji('  '), isEmpty);
  });
}
