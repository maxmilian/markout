import SwiftUI

/// The welcome window's content: what you can start from, and what you had open recently.
struct WelcomeView: View {
    @ObservedObject var store: RecentDocumentsStore
    var onOpen: (URL) -> Void
    var onNewDocument: () -> Void
    var onOpenPanel: () -> Void

    private var homeDirectory: String { NSHomeDirectory() }

    /// The welcome list is English-only copy, so rows format with a Gregorian calendar and a POSIX
    /// English locale regardless of the user's system locale.
    private var rowCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
    private var rowLocale: Locale { Locale(identifier: "en_US_POSIX") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Markout").font(.system(size: 22, weight: .semibold))
                Text("Markdown editor").foregroundStyle(.secondary).font(.callout)
            }

            HStack(spacing: 8) {
                Button("New Document", action: onNewDocument)
                    .keyboardShortcut(.defaultAction)
                Button("Open…", action: onOpenPanel)
            }

            Divider()

            if store.entries.isEmpty {
                Text("No recent documents")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.entries, id: \.path) { entry in
                            row(for: entry)
                            Divider()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 340)
    }

    @ViewBuilder
    private func row(for entry: RecentDocument) -> some View {
        let exists = FileManager.default.fileExists(atPath: entry.path)
        Button {
            onOpen(URL(fileURLWithPath: entry.path))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(RecentDocumentDisplay.name(for: entry.path))
                        .fontWeight(.medium)
                    Spacer()
                    Text(RecentDocumentDisplay.timestamp(
                        entry.openedAt, now: Date(),
                        calendar: rowCalendar, locale: rowLocale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(RecentDocumentDisplay.directory(
                    for: entry.path, homeDirectory: homeDirectory))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            // The tooltip sits on the content, not the Button: a disabled control is not
            // guaranteed to show its own help text.
            .help(exists ? entry.path : "File not found: \(entry.path)")
        }
        .buttonStyle(.plain)
        .disabled(!exists)
        .opacity(exists ? 1 : 0.4)
    }
}
