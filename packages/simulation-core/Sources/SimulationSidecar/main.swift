import Foundation
import SimulationProtocol

let server = RPCServer()
let arguments = Array(CommandLine.arguments.dropFirst())

func writeResponse(_ value: String) {
    FileHandle.standardOutput.write(Data("\(value)\n".utf8))
}

if let requestIndex = arguments.firstIndex(of: "--request") {
    let valueIndex = arguments.index(after: requestIndex)
    guard arguments.indices.contains(valueIndex) else {
        FileHandle.standardError.write(Data("--request requires a JSON-RPC payload\n".utf8))
        Foundation.exit(64)
    }
    writeResponse(server.handle(line: arguments[valueIndex]))
} else {
    while let line = readLine() {
        writeResponse(server.handle(line: line))
    }
}

