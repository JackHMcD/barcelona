# Building Barcelona

## Preparing your environment
Barcelona is currently ensured to build for macOS Big Sur and Monterey, on Intel and ARM, with Xcode 12 and Xcode 13. If you are on another system configuration, YMMV and it is not supported.

### Dependencies
- [xcodegen](https://github.com/yonaskolb/XcodeGen) - Barcelona's Xcodeproj is not checked in, it is instead generated locally via xcodegen.
- [xcpretty](https://github.com/xcpretty/xcpretty) - xcpretty is used in the Makefiles to provide cleaner output and reduce build times on CI. You don't need this dependency unless you are going to use the Makefiles.

#### Homebrew
> xcpretty is not on homebrew, so you'll need to install that through gem regardless.

```bash
brew install xcodegen && sudo gem install xcpretty
```

#### Gem
```bash
sudo gem install xcodegen xcpretty
```

### Building for iOS
Barcelona builds command-line tools for iOS, which Xcode does not support by default. You can run [configure-xcode-for-embedded-development](Scripts/configure-xcode-for-embedded-development), which was plucked from the WebKit repository and patches Xcode to let you build CLIs for embedded systems (iOS, watchOS, tvOS, etc.)

1. Close Xcode
2. Run `sudo ./Scripts/configure-xcode-for-embedded-development` from a shell
3. Reopen Xcode, you should be able to build the CLI tools for iOS

### Building for macOS
No preparation is neededot build for mcaOS.

## Compiling

### Compiling within Xcode
Compiling with Xcode is very straightforward, just select the scheme and build. For your convenience, there is a `tools` scheme which builds all of the command-line tools, and all of the frameworks as a side-effect.

### Compiling from the Terminal
Barcelona has a [Makefile](Makefile) which can build grapple and barcelona-mautrix for both iOS and macOS.

| Host  | Grapple            | Mautrix            | Both       |
|-------|--------------------|--------------------|------------|
| macOS | make grapple-macos | make mautrix-macos | make macos |
| iOS   | make grapple-ios   | make mautrix-ios   | make ios   |
