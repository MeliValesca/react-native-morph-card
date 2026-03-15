# react-native-morph-card

Native card-to-modal morph transition for React Native. The iOS App Store "card of the day" expand animation, as a library.

- Native animations on both platforms (UIKit `UIViewPropertyAnimator` / Android Transition framework)
- No JS-driven animation, no webview, no experimental flags
- Works with any navigation setup
- Supports old and new React Native architecture (Paper + Fabric)

> **Status:** Early development — the skeleton is in place, native morph animation is not yet implemented.

## Installation

```sh
yarn add react-native-morph-card
```

### iOS

```sh
cd ios && pod install
```

### Android

No additional steps required.

## Usage

```tsx
import { MorphCardSource } from 'react-native-morph-card';

function App() {
  return (
    <MorphCardSource style={styles.card}>
      <Pressable onPress={() => console.log('Morph!')}>
        <Text>Tap me</Text>
      </Pressable>
    </MorphCardSource>
  );
}
```

## Running the example app

The example app lives in the `example/` directory and uses [`react-native-test-app`](https://github.com/nicklasmoeller/react-native-test-app) to manage the native projects.

### Prerequisites

| Tool | Version |
|------|---------|
| Node.js | >= 18 |
| Yarn | 1.x |
| Ruby | >= 2.7 (for CocoaPods) |
| CocoaPods | ~> 1.15 |
| Xcode | >= 15 (iOS) |
| Android Studio | latest (Android) |
| JDK | 17 |

Make sure you have an iOS Simulator or Android Emulator available.

### 1. Install dependencies

From the repository root:

```sh
# Install root (library) dependencies
yarn install

# Install example app dependencies
cd example
yarn install
```

### 2. Run on iOS

```sh
# Install CocoaPods (from example/ios)
cd ios
bundle install
bundle exec pod install
cd ..

# Start Metro and build
yarn ios
```

This opens the app on the iOS Simulator. Metro starts automatically.

If you prefer to build from Xcode, open `example/ios/MorphCardExample.xcworkspace` and press Run.

### 3. Run on Android

Make sure an Android emulator is running (or a device is connected), then from `example/`:

```sh
yarn android
```

Gradle will download dependencies on first run — this can take a few minutes.

### 4. Start Metro separately (optional)

If you want to start the Metro bundler on its own (e.g. to see logs in a dedicated terminal):

```sh
cd example
yarn start
```

Then run `yarn ios` or `yarn android` in another terminal.

### Building JS bundles manually

Only needed if you want to test pre-built bundles (not required for normal development):

```sh
cd example
yarn build:ios
yarn build:android
```

### Troubleshooting

| Problem | Fix |
|---------|-----|
| `pod install` fails | Run `bundle install` first, then `bundle exec pod install` |
| Android build fails on first run | Make sure `ANDROID_HOME` is set and an emulator/device is available |
| Metro can't find `react-native-morph-card` | Run `yarn install` at the repo root first |
| Duplicate module errors | Delete `node_modules` in both root and `example/`, then reinstall |

## License

MIT
