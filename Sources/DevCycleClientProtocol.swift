import DevCycle
import Foundation

// Protocol for DevCycleClient used for dependency injection and testing.
// Only includes the subset of methods needed by DevCycleProvider.
public protocol DevCycleClientProtocol: AnyObject {
    func variableValue(key: String, defaultValue: Bool) -> Bool
    func variableValue(key: String, defaultValue: String) -> String
    func variableValue(key: String, defaultValue: NSString) -> NSString
    func variableValue(key: String, defaultValue: Double) -> Double
    func variableValue(key: String, defaultValue: NSNumber) -> NSNumber
    func variableValue(key: String, defaultValue: [String: Any]) -> [String: Any]
    func variableValue(key: String, defaultValue: NSDictionary) -> NSDictionary
    func variable<T>(key: String, defaultValue: T) -> DVCVariable<T>
    func variable(key: String, defaultValue: Bool) -> DVCVariable<Bool>
    func variable(key: String, defaultValue: String) -> DVCVariable<String>
    func variable(key: String, defaultValue: NSString) -> DVCVariable<NSString>
    func variable(key: String, defaultValue: Double) -> DVCVariable<Double>
    func variable(key: String, defaultValue: NSNumber) -> DVCVariable<NSNumber>
    func variable(key: String, defaultValue: [String: Any]) -> DVCVariable<[String: Any]>
    func variable(key: String, defaultValue: NSDictionary) -> DVCVariable<NSDictionary>
    func identifyUser(user: DevCycleUser, callback: ((Error?, [String: Variable]?) -> Void)?) throws
    func resetUser(callback: ((Error?, [String: Variable]?) -> Void)?) throws
    func allFeatures() -> [String: Feature]
    func allVariables() -> [String: Variable]
    func track(_ event: DevCycleEvent)
    func flushEvents(callback: ((Error?) -> Void)?)
    func close(callback: (() -> Void)?)
}

// Make DevCycleClient conform to the protocol
extension DevCycleClient: DevCycleClientProtocol {}
