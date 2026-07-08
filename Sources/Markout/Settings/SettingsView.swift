import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The Preferences window (⌘,). Three tabs bound directly to `@AppStorage`, so changes flow live
/// into the editor and preview by SwiftUI observation.
struct SettingsView: View {
    var body: some View {
        TabView {
            EditorSettingsTab()
                .tabItem { Label("Editor", systemImage: "textformat") }
            PreviewSettingsTab()
                .tabItem { Label("Preview", systemImage: "eye") }
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 460, height: 260)
        .padding(20)
    }
}

private struct EditorSettingsTab: View {
    @AppStorage(SettingsKey.editorFontSize) private var fontSize = SettingsDefault.editorFontSize
    @AppStorage(SettingsKey.softWrap) private var softWrap = SettingsDefault.softWrap
    @AppStorage(SettingsKey.showLineNumbers) private var showLineNumbers = SettingsDefault.showLineNumbers

    var body: some View {
        Form {
            Slider(value: $fontSize, in: 10...24, step: 1) {
                Text("Font size")
            } minimumValueLabel: {
                Text("10")
            } maximumValueLabel: {
                Text("24")
            }
            Text("\(Int(fontSize)) pt")
                .foregroundStyle(.secondary)

            Toggle("Soft wrap", isOn: $softWrap)
            Toggle("Show line numbers", isOn: $showLineNumbers)
        }
    }
}

private struct PreviewSettingsTab: View {
    @AppStorage(SettingsKey.previewThemeID) private var previewThemeID = SettingsDefault.previewThemeID
    @AppStorage(SettingsKey.customPreviewCSSPath) private var customCSSPath = SettingsDefault.customPreviewCSSPath

    private var customName: String? {
        customCSSPath.isEmpty ? nil : URL(fileURLWithPath: customCSSPath).lastPathComponent
    }

    /// On/off for using the imported custom CSS, backed by the `previewThemeID` sentinel.
    private var useCustom: Binding<Bool> {
        Binding(
            get: { previewThemeID == customPreviewThemeID },
            set: { previewThemeID = $0 ? customPreviewThemeID : SettingsDefault.previewThemeID })
    }

    var body: some View {
        Form {
            Text("Light / Dark is controlled per pane from the toolbar.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle("Use custom CSS for preview", isOn: useCustom)
                .disabled(customName == nil)

            if let customName {
                LabeledContent("Custom CSS", value: customName)
            }

            HStack {
                Button("Choose custom CSS…", action: chooseCustomCSS)
                if customName != nil {
                    Button("Clear", role: .destructive) {
                        customCSSPath = ""
                        if previewThemeID == customPreviewThemeID {
                            previewThemeID = SettingsDefault.previewThemeID
                        }
                    }
                }
            }
        }
    }

    private func chooseCustomCSS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "css") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Validate it is readable before selecting it.
        guard PreviewThemeStore.custom(fromFileURL: url) != nil else { return }
        customCSSPath = url.path
        previewThemeID = customPreviewThemeID
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage(SettingsKey.showWordCount) private var showWordCount = SettingsDefault.showWordCount

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            Toggle("Show word count", isOn: $showWordCount)
            LabeledContent("Markout", value: "v\(version)")
        }
    }
}
