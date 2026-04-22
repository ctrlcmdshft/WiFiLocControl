import Foundation

struct CommandResult {
    var status: Int32
    var output: String
    var error: String
}

struct ShellClient {
    func run(_ executable: String, _ arguments: [String] = []) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(status: 127, output: "", error: error.localizedDescription)
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(status: process.terminationStatus, output: output, error: error)
    }

    func existsInPath(_ command: String) -> Bool {
        run("/usr/bin/env", ["bash", "-lc", "command -v \(shellQuote(command)) >/dev/null"]).status == 0
    }
}

func shellQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

func locationKey(_ location: String) -> String {
    location.uppercased().replacingOccurrences(of: " ", with: "_")
}

func parseShellConfig(_ text: String) -> [String: String] {
    var values: [String: String] = [:]
    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else {
            continue
        }
        let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
        var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
            value = value
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        values[key] = value
    }
    return values
}

func shellConfigValue(_ value: String) -> String {
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}
