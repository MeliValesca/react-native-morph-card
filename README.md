# react-native-morph-card

Native card-to-modal morph transition for React Native. Smoothly animates a card from a list into a fullscreen detail view, morphing size, position, and corner radius — then collapses back.

<video src="assets/demo.mov">

- Native animations on both platforms (UIKit `UIViewPropertyAnimator` / Android `ValueAnimator`)
- No JS-driven animation, no webview, no experimental flags
- Works with any navigation setup (React Navigation, expo-router, etc.)
- Supports React Native new architecture (Fabric)

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [API](#api)
  - [`<MorphCardSource>`](#morphcardsource)
  - [`<MorphCardTarget>`](#morphcardtarget)
  - [`useMorphTarget`](#usemorphtargetoptions)
  - [Imperative API](#imperative-api)
- [Running the Example App](#running-the-example-app)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

## Installation

```sh
npm install react-native-morph-card
# or
yarn add react-native-morph-card
```

### iOS

```sh
cd ios && pod install
```

### Android

No additional steps required.

## Usage

Wrap your card content in `MorphCardSource`. On the detail screen, use `MorphCardTarget` where the card should land. Use `useMorphTarget` for easy collapse handling.

> **Important:** `MorphCardSource` can wrap any React Native component (images, views, text, etc.). During the animation, the content is captured as a **bitmap snapshot** — but once the animation completes, the snapshot fades out and the source's children are automatically cloned into `MorphCardTarget` as live React components. The cloned children are rendered at the source card's original layout dimensions, so your component layout stays consistent. This means observable values (timers, animated values, live data) will update in real time after the transition finishes. If you use `resizeMode`, the bitmap is kept instead (native image scaling doesn't apply to React components).

```tsx
import React from 'react';
import { View, Image, Text, Pressable } from 'react-native';
import {
  MorphCardSource,
  MorphCardTarget,
  useMorphTarget,
} from 'react-native-morph-card';

// ── List screen ──
const ListScreen = ({ navigation }) => {
  return (
    <MorphCardSource
      width={200}
      height={150}
      borderRadius={16}
      expandDuration={350}
      onPress={(sourceTag) => navigation.navigate('Detail', { sourceTag })}
    >
      <Image source={albumArt} style={{ width: 200, height: 150 }} />
    </MorphCardSource>
  );
};

// ── Detail screen ──
const DetailScreen = ({ route, navigation }) => {
  const { dismiss } = useMorphTarget({
    sourceTag: route.params.sourceTag,
    navigation,
  });

  return (
    <View style={{ flex: 1 }}>
      <MorphCardTarget
        sourceTag={route.params.sourceTag}
        width={'100%'}
        height={300}
        collapseDuration={200}
        borderRadius={0}
      />
      <Pressable onPress={dismiss}>
        <Text>Close</Text>
      </Pressable>
    </View>
  );
};
```

## API

### `<MorphCardSource>`

Wraps the card content on the list/grid screen. Captures a snapshot and drives the expand animation.

| Prop              | Type                                       | Default        | Description                                                                                            |
| ----------------- | ------------------------------------------ | -------------- | ------------------------------------------------------------------------------------------------------ |
| `width`           | `DimensionValue`                           | —              | Card width                                                                                             |
| `height`          | `DimensionValue`                           | —              | Card height                                                                                            |
| `borderRadius`    | `number`                                   | `0`            | Corner radius of the card                                                                              |
| `backgroundColor` | `string`                                   | —              | Background color (enables "wrapper mode" where the background expands separately from the content)     |
| `duration`        | `number`                                   | `300`          | Default animation duration in ms (used for both expand and collapse if specific durations are not set) |
| `expandDuration`  | `number`                                   | —              | Duration of the expand animation in ms. Overrides `duration` for expand.                               |
| `resizeMode`      | `'cover' \| 'contain' \| 'stretch'`        | `'cover'`      | How the snapshot scales during animation. When set, the bitmap is kept after expand (no live children). **Recommended when wrapping an `<Image>` — without it, the image may not scale properly during the animation.** |
| `rotations`       | `number`                                   | `0`            | Number of full 360° rotations during the expand animation                                              |
| `rotationEndAngle`| `number`                                   | `0`            | Final rotation angle in degrees after expand (e.g. `45` to end tilted). Collapse reverses it back to 0 |
| `presentation`    | `'push' \| 'transparentModal'`             | `'push'`      | Presentation mode. `'push'` (default) plays the morph alongside a native push transition. `'transparentModal'` plays over a modal overlay with fade. |
| `onPress`         | `(sourceTag: number) => void`              | —              | Called on tap with the native view tag. Use this to navigate to the detail screen.                     |

### `<MorphCardTarget>`

Placed on the detail screen where the card should land. Triggers the expand animation on mount. After the animation, the source's children are automatically cloned here as live React components.

| Prop               | Type             | Default       | Description                                                                      |
| ------------------ | ---------------- | ------------- | -------------------------------------------------------------------------------- |
| `sourceTag`        | `number`         | **required**  | The source view tag from navigation params                                       |
| `width`            | `DimensionValue` | source width  | Target width after expand                                                        |
| `height`           | `DimensionValue` | source height | Target height after expand                                                       |
| `borderRadius`     | `number`         | source radius | Target corner radius. Set to `0` for no rounding.                                |
| `collapseDuration` | `number`         | —             | Duration of the collapse animation in ms. Falls back to the source's `duration`. |
| `contentOffsetY`   | `number`         | `0`           | Vertical offset for content snapshot in wrapper mode                             |
| `contentCentered`  | `boolean`        | `false`       | Center content snapshot horizontally in wrapper mode                             |

### `useMorphTarget(options)`

Hook that provides a `dismiss` function for collapsing back to the source card. The `navigation` object must support `goBack()` — works with React Navigation, expo-router, or any navigator that implements it.

```tsx
const { dismiss } = useMorphTarget({
  sourceTag: route.params.sourceTag,
  navigation,
});
```

> **Screen presentation:** The `presentation` prop controls how the detail screen is navigated to:
>
> - **`push`** (default): The card morph plays alongside the native push transition. Works with any animation style (`slide_from_right`, `default`, `fade`, etc.).
> - **`transparentModal`**: The card morph plays over a transparent modal overlay with fade. Use `presentation: 'transparentModal'` and `animation: 'none'` in React Navigation screen options.
>
> `useMorphTarget` auto-detects the presentation mode from the source — no extra config needed on the detail screen.

### Imperative API

For more control, use the imperative functions:

```tsx
import {
  morphExpand,
  morphCollapse,
  getViewTag,
} from 'react-native-morph-card';

// Expand from source to target
await morphExpand(sourceRef, targetRef);

// Collapse back (pass the sourceTag)
await morphCollapse(sourceTag);

// Get the native view tag from a ref
const tag = getViewTag(viewRef);
```

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
````

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

| Problem                                    | Fix                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `pod install` fails                        | Run `bundle install` first, then `bundle exec pod install`          |
| Android build fails on first run           | Make sure `ANDROID_HOME` is set and an emulator/device is available |
| Metro can't find `react-native-morph-card` | Run `yarn install` at the repo root first                           |
| Duplicate module errors                    | Delete `node_modules` in both root and `example/`, then reinstall   |

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue. Pull requests are appreciated — just make sure to open an issue first so we can discuss the approach.

## Roadmap

- Support for more screen presentation styles (e.g. iOS modal sheet, page sheet)
- Shared element transitions between arbitrary views
- Gesture-driven collapse (drag to dismiss)
- Spring physics configuration props

## License

MIT
