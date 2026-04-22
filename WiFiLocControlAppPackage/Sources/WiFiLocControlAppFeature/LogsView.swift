import SwiftUI

struct LogsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Size: \(model.logInfo.sizeText)")
                    .foregroundStyle(.secondary)

                if model.logInfo.byteCount > model.logInfo.displayedByteLimit {
                    Text("Showing last \(model.logInfo.displayLimitText)")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.clearLog()
                } label: {
                    Label("Clear Log", systemImage: "trash")
                }
                .disabled(model.logInfo.byteCount == 0)
                .help("Empty ~/Library/Logs/WiFiLocControl.log")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if model.logText.isEmpty {
                ContentUnavailableView("No Log Entries", systemImage: "doc.text.magnifyingglass")
            } else {
                ScrollView {
                    Text(model.logText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("Logs")
    }
}
