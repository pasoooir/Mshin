# Android Debug APK CI

## What the pipeline produces

The android-debug-export job in .github/workflows/godot-city-buildit-validation.yml exports the existing Godot Android Debug preset as:

godot-city-buildit/build/android/PasooCityBuildIt.apk

The job uses Godot 4.3 export templates, Java 17 and Android SDK 34. The project explicitly enables `rendering/textures/vram_compression/import_etc2_astc` because Godot's Android exporter rejects presets when ETC2/ASTC texture import is disabled; the normal editor import step must run after this setting is applied. It creates an ephemeral debug keystore inside the GitHub Actions runner, verifies the APK signature with apksigner, checks the package ID (com.pasoo.citybuildit) and application label, then uploads the APK as a 14-day workflow artifact.

## Downloading the CI APK

1. Open the successful Godot City BuildIt Validation run in GitHub Actions.
2. Open the Artifacts section at the bottom of the run summary.
3. Download PasooCityBuildIt-android-debug-<commit-sha>.
4. Extract the APK and install it on an Android test device.

## Explicit validation boundary

- A successful export proves that the project can be packaged and that the APK signature/package metadata pass CI checks.
- It does not prove successful installation or launch on a physical phone.
- It does not prove touch UX, landscape/fullscreen behavior, audio/haptics, thermal behavior, battery use, or 60 FPS.
- The CI debug keystore is temporary and is not suitable for release or Play Store distribution.
- iOS export is not included; it requires a macOS/Xcode signing workflow and separate provisioning.

Record physical-device model, Android version, screen resolution, install/launch result, orientation behavior, touch findings, and benchmark JSON before changing the corresponding README status from partial to complete.
