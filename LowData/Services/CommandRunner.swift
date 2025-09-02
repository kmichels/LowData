import Foundation

class CommandRunner {
    static let shared = CommandRunner()
    
    private init() {}
    
    func execute(_ command: String, arguments: [String] = []) async throws -> String {
        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = errorPipe
        task.arguments = ["-c", arguments.isEmpty ? command : "\(command) \(arguments.joined(separator: " "))"]
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.standardInput = nil
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try task.run()
                
                task.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if task.terminationStatus != 0 {
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: CommandError.executionFailed(errorOutput))
                    } else {
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    }
                }
            } catch {
                continuation.resume(throwing: CommandError.launchFailed(error.localizedDescription))
            }
        }
    }
    
    func executeWithTimeout(_ command: String, arguments: [String] = [], timeout: TimeInterval = 5.0) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.execute(command, arguments: arguments)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw CommandError.timeout
            }
            
            guard let result = try await group.next() else {
                throw CommandError.timeout
            }
            
            group.cancelAll()
            return result
        }
    }
}

enum CommandError: LocalizedError {
    case launchFailed(String)
    case executionFailed(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "Failed to launch command: \(message)"
        case .executionFailed(let message):
            return "Command execution failed: \(message)"
        case .timeout:
            return "Command timed out"
        }
    }
}