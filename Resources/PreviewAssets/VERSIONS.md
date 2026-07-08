# Vendored Preview Assets

The preview `WKWebView` loads these third-party libraries locally (no CDN, works offline).
The app loads them relative to `Bundle.main.resourceURL` (see `HTMLTemplate.page`).

## Pinned versions

| Library | Version | License | Files |
|---------|---------|---------|-------|
| highlight.js | 11.9.0 | BSD-3-Clause | `highlight/highlight.min.js` |
| KaTeX | 0.16.9 | MIT | `katex/katex.min.js`, `katex/katex.min.css`, `katex/fonts/*` |
| Mermaid | 10.9.0 | MIT | `mermaid/mermaid.min.js` |

CSS authored in this repo (not vendored):
- `highlight/highlight-light.css`, `highlight/highlight-dark.css` — compact GitHub-style
  highlight.js token themes (swap for upstream `styles/github.css` / `github-dark.css` if preferred).
- `themes/*.css` — Markout preview themes (default, github, github-dark-dimmed, solarized).

## Fetching the JS/CSS engines

> The CI/sandbox environment that generated this scaffold has **no outbound network access to
> CDNs**, so `highlight.min.js`, `katex.min.js`, `katex.min.css`, the KaTeX `fonts/`, and
> `mermaid.min.js` are **not committed**. Run `./fetch-assets.sh` on a machine with network access
> (e.g. your Mac) once; the files then live in the bundle and never need re-fetching.

```sh
cd Resources/PreviewAssets && ./fetch-assets.sh
```

After fetching, `xcodegen generate` and build — `project.yml` already copies the whole
`Resources/PreviewAssets` folder into `Markout.app/Contents/Resources`.

## Notes

- KaTeX is driven via `katex.render(...)` over `.math-inline` / `.math-display` elements produced by
  `MathExtractor.reinsert` (not the delimiter-scanning `auto-render` extension), so `auto-render.min.js`
  is **not** required.
- Mermaid v10 renders via `mermaid.run(...)`; `HTMLTemplate.afterRender()` rewrites
  `code.language-mermaid` blocks to `<div class="mermaid">` first.
