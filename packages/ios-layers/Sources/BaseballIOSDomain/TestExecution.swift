import Foundation

/// Test-host services must be isolated before XCTest starts invoking individual test methods.
public enum TestExecution {
    public static func isRunning(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["BASEBALL_TEST_ISOLATION"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }
}
