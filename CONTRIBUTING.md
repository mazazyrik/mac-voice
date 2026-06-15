# Contributing to MacVoice

Thanks for helping make Russian dictation on macOS better.

## Development

1. Use macOS 15+ on Apple Silicon.
2. Install Xcode 16+.
3. Fork and clone the repository.
4. Open `MacVoice.xcodeproj`.
5. Run the `MacVoice` scheme and complete onboarding with your own API key.

Never commit an OpenAI key, Apple certificate, app-specific password, generated
Keychain export, or local `.env` file.

## Pull requests

- Keep changes focused and follow the existing SwiftUI and concurrency style.
- Add or update tests for behavior changes.
- Run the unit and UI test scheme before submitting.
- Update English and Russian localizations together.
- Describe any new permission, network request, or persistent data.

## Design principles

- Prefer native Apple frameworks and avoid dependencies without a strong reason.
- Keep the number of controls small and provide safe defaults.
- Never lose recorded audio silently after a recoverable API failure.
- Treat clipboard and dictation content as sensitive user data.
- Keep API credentials in Keychain only.
