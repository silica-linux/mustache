// The emoji of the folder emoji picker (folder_emoji.dart): a small, provisional set (Silica has no
// system emoji picker yet; the real one will replace this). Each line is `emoji keywords…`; the
// keywords feed the search. Categories in the order of the bar.

/// One emoji with its search keywords.
typedef EmojiItem = ({String emoji, String keywords});

/// A category of the picker: the emoji on its bar button and its items.
typedef EmojiCategory = ({String icon, List<EmojiItem> items});

List<EmojiItem> _parse(String block) => [
  for (final line in block.trim().split('\n'))
    if (line.trim().isNotEmpty)
      (
        emoji: line.trim().split(' ').first,
        keywords: line.trim().split(' ').skip(1).join(' '),
      ),
];

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

final List<EmojiCategory> emojiCategories = [
  (
    icon: '😀',
    items: _parse('''
😀 grin smile happy
😃 smile happy
😄 laugh happy
😁 beam grin
😆 laugh squint
😅 sweat smile
😂 joy tears laugh
🙂 slight smile
😉 wink
😊 blush smile
😍 love heart eyes
😘 kiss
😎 cool sunglasses
🤔 thinking
😐 neutral
😴 sleep
😭 cry sad
😡 angry
🥳 party celebrate
🤯 mind blown
😱 scream shock
🤗 hug
🙃 upside down
😇 angel
🤩 star struck
😬 grimace
🥰 love hearts
😜 silly tongue
🤓 nerd
👍 thumbs up yes
👎 thumbs down no
👏 clap
🙏 pray thanks
💪 strong muscle
👋 wave hello
✌️ peace victory
❤️ red heart love
💙 blue heart
💚 green heart
💜 purple heart
🧡 orange heart
💛 yellow heart
'''),
  ),
  (
    icon: '🐶',
    items: _parse('''
🐶 dog
🐱 cat
🐭 mouse
🐹 hamster
🐰 rabbit
🦊 fox
🐻 bear
🐼 panda
🐨 koala
🐯 tiger
🦁 lion
🐮 cow
🐷 pig
🐸 frog
🐵 monkey
🐔 chicken
🐧 penguin
🐦 bird
🦉 owl
🦋 butterfly
🐝 bee
🐢 turtle
🐍 snake
🐙 octopus
🐬 dolphin
🐳 whale
🦈 shark
🌳 tree
🌲 pine tree
🌴 palm tree
🌵 cactus
🌸 blossom flower
🌻 sunflower
🍀 clover luck
🌍 earth globe
🌙 moon
☀️ sun
⭐ star
🌈 rainbow
🔥 fire
💧 drop water
❄️ snow
'''),
  ),
  (
    icon: '🍎',
    items: _parse('''
🍎 apple red
🍐 pear
🍊 orange
🍋 lemon
🍌 banana
🍉 watermelon
🍇 grapes
🍓 strawberry
🍒 cherries
🍑 peach
🥭 mango
🍍 pineapple
🥥 coconut
🥝 kiwi
🍅 tomato
🥑 avocado
🥕 carrot
🌽 corn
🥦 broccoli
🍞 bread
🧀 cheese
🥚 egg
🍳 cooking
🥞 pancakes
🍔 burger
🍟 fries
🍕 pizza
🌭 hot dog
🌮 taco
🍣 sushi
🍜 noodles ramen
🍝 spaghetti pasta
🍰 cake
🍪 cookie
🍫 chocolate
🍩 donut
🍦 ice cream
☕ coffee
🍵 tea
🍺 beer
🍷 wine
🥤 drink
'''),
  ),
  (
    icon: '⚽',
    items: _parse('''
⚽ soccer football
🏀 basketball
🏈 american football
⚾ baseball
🎾 tennis
🏐 volleyball
🏉 rugby
🎱 billiards pool
🏓 ping pong
🏸 badminton
🥊 boxing
⛳ golf
🏹 archery
🎣 fishing
🎿 ski
🏂 snowboard
🏄 surf
🚴 cycling bike
🏊 swim
🧘 yoga
🎮 video game
🕹️ joystick
🎲 dice
♟️ chess
🎯 dart target
🎳 bowling
🎨 art palette
🎬 movie film
🎤 microphone sing
🎧 headphones music
🎵 music note
🎶 music notes
🎸 guitar
🎹 piano keyboard
🥁 drum
🎷 saxophone
🎺 trumpet
🎻 violin
🎭 theater
🏆 trophy
🥇 gold medal
🎉 party tada
🎁 gift
'''),
  ),
  (
    icon: '🚗',
    items: _parse('''
🚗 car
🚕 taxi
🚌 bus
🚎 trolley
🏎️ race car
🚓 police car
🚑 ambulance
🚒 fire truck
🚚 truck
🚜 tractor
🏍️ motorcycle
🚲 bicycle
🛴 scooter
🚂 train
🚆 train
🚇 metro subway
🚁 helicopter
✈️ airplane plane
🚀 rocket
🛸 ufo
🚢 ship
⛵ sailboat
⚓ anchor
🏠 house home
🏡 house garden
🏢 office building
🏫 school
🏥 hospital
🏦 bank
🏰 castle
🗼 tower
🗽 statue liberty
⛪ church
🕌 mosque
🏖️ beach
🏝️ island
🏔️ mountain
🌋 volcano
🏕️ camping
🌆 city
🌉 bridge
🗺️ map
'''),
  ),
  (
    icon: '💡',
    items: _parse('''
💡 idea bulb light
🔦 flashlight
🔒 lock
🔓 unlock
🔑 key
🔨 hammer
🛠️ tools
🔧 wrench
⚙️ gear settings
🧲 magnet
💻 laptop computer
🖥️ desktop computer
⌨️ keyboard
🖱️ mouse
💾 floppy save
💿 disc cd
📷 camera photo
📹 video camera
📺 tv television
📱 phone mobile
☎️ telephone
📡 antenna
🔋 battery
🔌 plug
📁 folder
📂 open folder
📄 page document
📝 memo note
📚 books
📖 book open
📌 pin
📎 paperclip
✂️ scissors
📦 package box
📬 mailbox
✉️ envelope mail
💰 money bag
💳 credit card
🧳 luggage
🎒 backpack
👜 handbag
👕 shirt
👟 shoe
⌚ watch
'''),
  ),
  (
    icon: '❤️',
    items: _parse('''
❤️ heart red
🧡 heart orange
💛 heart yellow
💚 heart green
💙 heart blue
💜 heart purple
🖤 heart black
🤍 heart white
💔 broken heart
💯 hundred
✅ check done
❌ cross no
❗ exclamation
❓ question
⚠️ warning
🚫 prohibited
♻️ recycle
➕ plus
➖ minus
✖️ multiply
➗ divide
💲 dollar
🔴 red circle
🟠 orange circle
🟡 yellow circle
🟢 green circle
🔵 blue circle
🟣 purple circle
⚫ black circle
⚪ white circle
🟥 red square
🟧 orange square
🟨 yellow square
🟩 green square
🟦 blue square
🟪 purple square
🔺 triangle up
🔻 triangle down
⬆️ arrow up
⬇️ arrow down
⬅️ arrow left
➡️ arrow right
🔄 refresh
'''),
  ),
  (
    icon: '🏁',
    items: _parse('''
🏁 chequered flag race
🚩 red flag
🏳️ white flag
🏴 black flag
🏳️‍🌈 rainbow flag pride
🇮🇹 italy
🇫🇷 france
🇩🇪 germany
🇪🇸 spain
🇬🇧 united kingdom
🇺🇸 united states
🇨🇦 canada
🇧🇷 brazil
🇦🇷 argentina
🇲🇽 mexico
🇯🇵 japan
🇨🇳 china
🇰🇷 south korea
🇮🇳 india
🇦🇺 australia
🇷🇺 russia
🇹🇷 turkey
🇵🇹 portugal
🇳🇱 netherlands
🇧🇪 belgium
🇨🇭 switzerland
🇦🇹 austria
🇸🇪 sweden
🇳🇴 norway
🇩🇰 denmark
🇫🇮 finland
🇵🇱 poland
🇬🇷 greece
🇮🇪 ireland
🇪🇺 european union
🇺🇳 united nations
'''),
  ),
];

/// The emoji whose keywords (or the emoji itself) contain every word of [query].
List<EmojiItem> searchEmoji(String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  return [
    for (final c in emojiCategories)
      for (final item in c.items)
        if (words.every(
          (w) => item.keywords.contains(w) || item.emoji.contains(w),
        ))
          item,
  ];
}
