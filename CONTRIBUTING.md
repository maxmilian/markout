# Contributing to Markout

Thanks for helping improve Markout. Contributions can be small: a focused bug fix, a test, a documentation correction, a translation update, or a UI polish pass.

## Good first contributions

- Fix Markdown rendering edge cases
- Improve editor behavior around lists, formatting, or pasted images
- Add or refine tests in `Tests/MarkoutTests/`
- Improve preview themes or export output
- Update documentation and localized README files

## Development workflow

1. Create a branch from `main`.
2. Make a focused change.
3. Regenerate the Xcode project if needed:

   ```sh
   xcodegen generate
   ```

4. Build or run tests:

   ```sh
   xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'
   ```

5. Open a pull request with a short description of the change, the user-facing impact, and the verification you ran.

## Code guidelines

- Prefer the existing architecture over new abstractions.
- Keep rendering behavior deterministic and offline.
- Add tests for parser, renderer, exporter, document, and editor utility changes.
- Avoid CDN dependencies; preview assets should stay vendored.
- Keep UI behavior native to macOS and consistent with SwiftUI conventions.

## Documentation and translations

The English `README.md` is the source of truth. When behavior changes, update it first. If the change affects public documentation, update the localized README files when practical:

- `README.zh-TW.md`
- `README.zh-CN.md`
- `README.ja.md`
- `README.ko.md`

Translation-only pull requests are welcome.

## AI-assisted contributions

AI-assisted contributions are welcome, but please review the output before submitting. You are responsible for the correctness of the code, tests, documentation, and any licensing implications of generated content.

## License

By contributing, you agree that your contributions will be licensed under the repository's [MIT License](LICENSE).
