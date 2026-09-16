# Bingo

Classic five-line Bingo for Flutter, with local AI and private two-player
rooms. Easy, Medium, and Hard are immediately selectable; scores persist only
within a rematch series. Short WAV cues in `assets/sounds` cover clicks, turns,
round start, and wins.

## Multiplayer

Follow the step-by-step [multiplayer setup guide](MULTIPLAYER_SETUP.md) to run
the included server and provide `BINGO_SERVER_URL` to the app.

## Development checks

```bash
flutter pub get
flutter analyze
flutter test
```
