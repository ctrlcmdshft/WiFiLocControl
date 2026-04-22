import SwiftUI

struct LogsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView(title: "Logs", subtitle: "Recent entries from ~/Library/Logs/WiFiLocControl.log")

            ScrollView {
                Text(model.logText.isEmpty ? "No log entries yet." : model.logText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh Logs", systemImage: "arrow.clockwise")
                }
            }
        }
        .padding(24)
    }
}
