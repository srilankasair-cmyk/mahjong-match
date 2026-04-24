# Mahjong Match

## About the Game

Mahjong is a game that my friends and I love deeply, but here in Finland very few people know how to play it. I found that memorizing and recognizing mahjong tiles is one of the highest barriers to learning the game, and a standard mahjong game requires four players, which makes it even harder to get started.

I wanted to build a game that helps people learn the basics of mahjong in a more approachable way — using simple tile-matching and elimination rules to introduce fundamental mahjong concepts such as Chow (eating a sequence), Pung (three of a kind), and Kong.

The prototype of this game comes from my childhood memories. In my hometown, mahjong was a part of everyday life. When I was young and could not yet understand the full rules, we would play similar tile-matching games for fun. Now I have turned that memory into a digital game, hoping to introduce more people to mahjong culture and the joy of finding order within chaos.

## Deployed Application

[https://srilankasair-cmyk.github.io/mahjong-match/](https://srilankasair-cmyk.github.io/mahjong-match/)

## How to Play

1. **Select a difficulty** on the level select screen (Easy, Medium, or Hard). Higher difficulties introduce more tile types and fewer hints.

2. **Draw tiles** from the wall by tapping the draw button. Tiles are added to your hand.

3. **Match tiles in your hand** to clear them:
   - **Chow**: three consecutive tiles of the same suit (e.g. 1, 2, 3 of Bamboo)
   - **Pung**: three identical tiles (e.g. three 7 of Characters)

4. **Special magic tiles** appear occasionally and grant bonus effects:
   - **Wind**: clears a set of tiles instantly
   - **Vanish**: removes a selected tile from your hand
   - **Shuffle**: reshuffles the remaining wall tiles

5. **Clear all tiles** before the wall runs out to win the round. Your score increases with each successful match.

## Project Structure

```
src/
└── lib/
    ├── main.dart          # Application entry point
    ├── models/            # Game data models
    ├── screens/           # UI screens (start, level select, game, result)
    ├── services/          # Audio service
    └── widgets/           # Reusable UI components
```
