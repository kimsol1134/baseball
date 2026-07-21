public struct RPCRequest: Codable, Equatable, Sendable {
    public let jsonrpc: String
    public let id: JSONValue
    public let method: String
    public let params: JSONValue?

    public init(jsonrpc: String = "2.0", id: JSONValue, method: String, params: JSONValue? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct RPCError: Codable, Equatable, Sendable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public struct RPCResponse: Codable, Equatable, Sendable {
    public let jsonrpc: String
    public let id: JSONValue
    public let result: JSONValue?
    public let error: RPCError?

    public init(id: JSONValue, result: JSONValue) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: JSONValue, error: RPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

public struct HealthResult: Codable, Equatable, Sendable {
    public let status: String
    public let protocolVersion: String
    public let coreVersion: String

    public init(status: String, protocolVersion: String, coreVersion: String) {
        self.status = status
        self.protocolVersion = protocolVersion
        self.coreVersion = coreVersion
    }
}

