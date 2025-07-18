import DevCycle
import Foundation

@testable import DevCycleOpenFeatureProvider

class DVCVariableMock<T> {
    var key: String
    var value: T
    var defaultValue: T
    var isDefaulted: Bool
    var evalReason: String?

    init(
        key: String, value: T, defaultValue: T, isDefaulted: Bool = true,
        evalReason: String? = nil
    ) {
        self.key = key
        self.value = value
        self.defaultValue = defaultValue
        self.isDefaulted = isDefaulted
        self.evalReason = evalReason
    }
}

class MockDevCycleClient: DevCycleClientProtocol {
    var mockVariableValue: [String: Any] = [:]
    var mockIsDefaulted: Bool = true
    var shouldDefault: Bool = true

    private func makeMockVariable<T>(key: String, defaultValue: T) -> DVCVariable<T> {
        let value: T? = shouldDefault ? nil : defaultValue
        
        // Requires DevCycle 1.24.2
        let evalReason = shouldDefault ? nil : EvalReason.createOFEvalReason(reason: "TARGETING_MATCH")
        return DVCVariable(key: key, value: value, defaultValue: defaultValue, eval: evalReason)
    }

    func variableValue(key: String, defaultValue: Bool) -> Bool { defaultValue }
    func variableValue(key: String, defaultValue: String) -> String { defaultValue }
    func variableValue(key: String, defaultValue: NSString) -> NSString { defaultValue }
    func variableValue(key: String, defaultValue: Double) -> Double { defaultValue }
    func variableValue(key: String, defaultValue: NSNumber) -> NSNumber { defaultValue }
    func variableValue(key: String, defaultValue: [String: Any]) -> [String: Any] { defaultValue }
    func variableValue(key: String, defaultValue: NSDictionary) -> NSDictionary { defaultValue }
    func variable<T>(key: String, defaultValue: T) -> DVCVariable<T> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: Bool) -> DVCVariable<Bool> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: String) -> DVCVariable<String> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: NSString) -> DVCVariable<NSString> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: Double) -> DVCVariable<Double> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: NSNumber) -> DVCVariable<NSNumber> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: [String: Any]) -> DVCVariable<[String: Any]> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func variable(key: String, defaultValue: NSDictionary) -> DVCVariable<NSDictionary> {
        makeMockVariable(key: key, defaultValue: defaultValue)
    }
    func identifyUser(user: DevCycleUser, callback: ((Error?, [String: Variable]?) -> Void)?) throws
    {
        callback?(nil, nil)
    }
    func resetUser(callback: ((Error?, [String: Variable]?) -> Void)?) throws {
        callback?(nil, nil)
    }
    func allFeatures() -> [String: Feature] { [:] }
    func allVariables() -> [String: Variable] { [:] }
    func track(_ event: DevCycleEvent) {}
    func flushEvents(callback: ((Error?) -> Void)?) { callback?(nil) }
    func close(callback: (() -> Void)?) { callback?() }
}
