#!/bin/bash
# Reliable Android build script for react-native-morph-card
# Handles JDK 17 requirement, daemon cleanup, and port forwarding

set -e

JAVA_HOME_17="/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home"
EXAMPLE_DIR="$(dirname "$0")/example/android"
APK_PATH="$EXAMPLE_DIR/app/build/outputs/apk/debug/app-debug.apk"
PACKAGE="com.microsoft.reacttestapp"

echo "==> Killing stale Gradle/Kotlin processes..."
pkill -9 -f "GradleDaemon" 2>/dev/null || true
pkill -9 -f "org.gradle.launcher" 2>/dev/null || true
pkill -9 -f "kotlin-daemon" 2>/dev/null || true
sleep 3

echo "==> Cleaning daemon registry..."
rm -rf "$HOME/.gradle/daemon" 2>/dev/null || true
sleep 2

echo "==> Building with JDK 17..."
cd "$EXAMPLE_DIR"

# Retry up to 3 times for daemon connection issues
for i in 1 2 3; do
  echo "    Attempt $i..."
  if JAVA_HOME="$JAVA_HOME_17" ./gradlew assembleDebug --no-daemon \
    -Dkotlin.compiler.execution.strategy=in-process 2>&1 | tee /tmp/gradle_build.log | tail -5; then
    if grep -q "BUILD SUCCESSFUL" /tmp/gradle_build.log; then
      echo "==> Build successful!"
      break
    fi
  fi
  if [ $i -eq 3 ]; then
    echo "==> Build failed after 3 attempts. Check /tmp/gradle_build.log"
    exit 1
  fi
  echo "    Retrying in 10s..."
  pkill -9 -f "GradleDaemon" 2>/dev/null || true
  rm -rf "$HOME/.gradle/daemon" 2>/dev/null || true
  sleep 10
done

echo "==> Installing APK..."
adb install -r "$APK_PATH"

echo "==> Setting up port forwarding..."
adb reverse tcp:8081 tcp:8081

echo "==> Launching app..."
adb shell am force-stop "$PACKAGE"
sleep 1
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 2>/dev/null

echo "==> Done! App should be running."
