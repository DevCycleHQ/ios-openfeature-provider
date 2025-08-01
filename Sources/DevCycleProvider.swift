//
//  DevCycleProvider.swift
//  DevCycleOpenFeatureProvider
//

import Combine
import DevCycle
import Foundation
import OpenFeature

public struct DevCycleProviderMetadata: ProviderMetadata {
    public var name: String? = "DevCycle Provider"
}

public final class DevCycleProvider: FeatureProvider {
    /**
        Provider hooks
     */
    public var hooks: [any Hook] = []

    /**
        Provider metadata
     */
    public var metadata: ProviderMetadata = DevCycleProviderMetadata()

    /**
        The DevCycle client instance
     */
    internal(set) public var devcycleClient: DevCycleClientProtocol?

    /**
        The SDK key for DevCycle
     */
    private let sdkKey: String

    /**
        Options for DevCycle client
     */
    private let options: DevCycleOptions?

    /**
        Event handler for provider events
     */
    private let eventHandler = EventHandler()

    // MARK: - FeatureProvider Methods

    /**
        Initializes a new instance of the DevCycleProvider
        - Parameters:
          - sdkKey: The DevCycle SDK key
          - options: Optional configuration options
     */
    public init(sdkKey: String, options: DevCycleOptions? = nil) {
        self.sdkKey = sdkKey
        self.options = options
        if let logLevel = options?.logLevel {
            Log.level = logLevel
        }
    }

    /**
        Initializes the provider with the given context
        - Parameter initialContext: The initial evaluation context
     */
    public func initialize(initialContext: EvaluationContext?) async throws {
        if initialContext == nil {
            Log.warn(
                "DevCycleProvider initialized without context being set. "
                    + "It is highly recommended to set a context using `OpenFeature.setContext()` "
                    + "before setting an OpenFeature Provider using `OpenFeature.setProvider()` "
                    + "to avoid multiple API fetch calls."
            )
        }

        do {
            // If initialContext is nil, use anonymous user
            // Otherwise, convert context to user and throw any errors
            let user: DevCycleUser
            if let context = initialContext {
                user = try DevCycleProvider.dvcUserFromContext(context)
            } else {
                user = try DevCycleUser.builder().userId("anonymous").build()
            }

            // Initialize client
            try await initializeDevCycleClient(with: user)

            // Report provider ready
            eventHandler.send(.ready)
        } catch {
            // Report provider error
            eventHandler.send(
                ProviderEvent.error(errorCode: .providerNotReady, message: "Initialization error"))
            throw OpenFeatureError.providerFatalError(
                message: "DevCycle client initialization error: \(error)")
        }
    }

    public func observe() -> AnyPublisher<OpenFeature.ProviderEvent?, Never> {
        return eventHandler.observe()
    }

    /**
        Called when the evaluation context changes
        - Parameters:
          - oldContext: The previous evaluation context
          - newContext: The new evaluation context
     */
    public func onContextSet(oldContext: EvaluationContext?, newContext: EvaluationContext)
        async throws
    {
        do {
            Log.debug("DevCycleProvider onContextSet: \(newContext)")
            guard let client = self.devcycleClient else {
                Log.warn(
                    "Context set before DevCycleProvider was fully initialized. "
                        + "The context will be ignored until initialization completes."
                )
                return
            }

            let user = try DevCycleProvider.dvcUserFromContext(newContext)

            // Mark provider as stale while context is being updated
            eventHandler.send(.stale)

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try client.identifyUser(user: user) { error, _ in
                        if let error = error {
                            print("DevCycle identify user error: \(error)")
                            self.eventHandler.send(
                                ProviderEvent.error(
                                    errorCode: .general, message: "User identification error"))
                            continuation.resume(throwing: error)
                        } else {
                            // Once user is identified, the context has been updated
                            self.eventHandler.send(.configurationChanged)
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            Log.error("DevCycleProvider onContextSet error: \(error)")
            eventHandler.send(
                ProviderEvent.error(errorCode: .general, message: "Context set error"))
            throw OpenFeatureError.generalError(message: "Error setting context: \(error)")
        }
    }

    /**
        Evaluates a boolean feature flag
        - Parameters:
          - key: The feature flag key
          - defaultValue: The default value to return if evaluation fails
          - context: The evaluation context
        - Returns: The provider evaluation with flag value and metadata
     */
    public func getBooleanEvaluation(
        key: String,
        defaultValue: Bool,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Bool> {
        // If client is nil, return default value with DEFAULT reason
        if devcycleClient == nil {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.defaultReason.rawValue
            )
        }

        let variable = devcycleClient!.variable(key: key, defaultValue: defaultValue)

        return ProviderEvaluation(
            value: variable.value,
            flagMetadata: DevCycleProvider.getFlagMetadata(variable: variable),
            reason: DevCycleProvider.getEvalReason(variable: variable)
        )
    }

    /**
        Evaluates a string feature flag
        - Parameters:
          - key: The feature flag key
          - defaultValue: The default value to return if evaluation fails
          - context: The evaluation context
        - Returns: The provider evaluation with flag value and metadata
     */
    public func getStringEvaluation(
        key: String,
        defaultValue: String,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<String> {
        // If client is nil, return default value with DEFAULT reason
        if devcycleClient == nil {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.defaultReason.rawValue
            )
        }

        let variable = devcycleClient!.variable(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(
            value: variable.value,
            flagMetadata: DevCycleProvider.getFlagMetadata(variable: variable),
            reason: DevCycleProvider.getEvalReason(variable: variable)
        )
    }

    /**
        Evaluates an integer feature flag
        - Parameters:
          - key: The feature flag key
          - defaultValue: The default value to return if evaluation fails
          - context: The evaluation context
        - Returns: The provider evaluation with flag value and metadata
     */
    public func getIntegerEvaluation(
        key: String,
        defaultValue: Int64,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Int64> {
        // If client is nil, return default value with DEFAULT reason
        if devcycleClient == nil {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.defaultReason.rawValue
            )
        }

        // DevCycle doesn't have a dedicated integer type, so we need to use Double
        let doubleValue = Double(defaultValue)
        let variable = devcycleClient!.variable(key: key, defaultValue: doubleValue)

        return ProviderEvaluation(
            value: Int64(variable.value),
            flagMetadata: DevCycleProvider.getFlagMetadata(variable: variable),
            reason: DevCycleProvider.getEvalReason(variable: variable)
        )
    }

    /**
        Evaluates a double feature flag
        - Parameters:
          - key: The feature flag key
          - defaultValue: The default value to return if evaluation fails
          - context: The evaluation context
        - Returns: The provider evaluation with flag value and metadata
     */
    public func getDoubleEvaluation(
        key: String,
        defaultValue: Double,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Double> {
        // If client is nil, return default value with DEFAULT reason
        if devcycleClient == nil {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.defaultReason.rawValue
            )
        }

        let variable = devcycleClient!.variable(key: key, defaultValue: defaultValue)
        return ProviderEvaluation(
            value: variable.value,
            flagMetadata: DevCycleProvider.getFlagMetadata(variable: variable),
            reason: DevCycleProvider.getEvalReason(variable: variable)
        )
    }

    /**
        Evaluates an object feature flag
        - Parameters:
          - key: The feature flag key
          - defaultValue: The default value to return if evaluation fails
          - context: The evaluation context
        - Returns: The provider evaluation with flag value and metadata
     */
    public func getObjectEvaluation(
        key: String,
        defaultValue: Value,
        context: EvaluationContext?
    ) throws -> ProviderEvaluation<Value> {
        // If client is nil, return default value with DEFAULT reason
        if devcycleClient == nil {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.defaultReason.rawValue
            )
        }

        let dictionaryValue = try DevCycleProvider.convertValueToDictionary(defaultValue)
        let variable = devcycleClient!.variable(key: key, defaultValue: dictionaryValue)

        return ProviderEvaluation(
            value: variable.isDefaulted
                ? defaultValue : DevCycleProvider.convertDictionaryToValue(variable.value),
            flagMetadata: DevCycleProvider.getFlagMetadata(variable: variable),
            reason: DevCycleProvider.getEvalReason(variable: variable)
        )
    }

    // MARK: - Internal Methods

    /**
        Creates and initializes the DevCycle client
        - Parameter user: The DevCycle user to initialize with
     */
    internal func initializeDevCycleClient(with user: DevCycleUser) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            do {
                self.devcycleClient = try DevCycleClient.builder()
                    .sdkKey(sdkKey)
                    .user(user)
                    .options(options ?? DevCycleOptions.builder().build())
                    .build { error in
                        if let error = error {
                            continuation.resume(
                                throwing: OpenFeatureError.providerFatalError(
                                    message: "DevCycle client initialization error: \(error)"))
                        } else {
                            continuation.resume()
                        }
                    }

                // TODO: add support for `ConfigurationChanged` and `Error` events to OF
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /**
        Converts an OpenFeature Value to Dictionary
        - Parameter value: The Value to convert
        - Returns: The converted Dictionary
     */
    internal static func convertValueToDictionary(_ value: Value) throws -> [String: Any] {
        // Only allow structure (object) values
        guard case .structure(let attributes) = value else {
            throw OpenFeatureError.parseError(
                message:
                    "DevCycle only supports object values for JSON flags. Received non-object value: \(value)"
            )
        }

        var dictionaryValue: [String: Any] = [:]

        for (key, value) in attributes {
            switch value {
            case .string(let stringValue):
                dictionaryValue[key] = stringValue
            case .boolean(let boolValue):
                dictionaryValue[key] = boolValue
            case let .double(doubleValue):
                dictionaryValue[key] = doubleValue
            case let .integer(intValue):
                dictionaryValue[key] = intValue
            case .structure(let structValue):
                // Recursively convert nested structures
                dictionaryValue[key] = try convertValueToDictionary(.structure(structValue))
            default:
                // Skip unsupported types
                Log.warn("Skipping unsupported value type in JSON flags for key '\(key)': \(value)")
                break
            }
        }

        return dictionaryValue
    }

    /**
        Converts a Dictionary to OpenFeature Value
        - Parameter dictionary: The dictionary to convert
        - Returns: The converted Value
     */
    internal static func convertDictionaryToValue(_ dictionary: [String: Any]) -> Value {
        var attributes: [String: Value] = [:]

        for (key, value) in dictionary {
            if let stringValue = value as? String {
                attributes[key] = .string(stringValue)
            } else if let boolValue = value as? Bool {
                attributes[key] = .boolean(boolValue)
            } else if let numberValue = value as? Double {
                attributes[key] = .double(numberValue)  // Use .double for numeric values
            } else if let numberValue = value as? Int64 {
                attributes[key] = .integer(numberValue)
            } else if let numberValue = value as? Int {
                attributes[key] = .integer(Int64(numberValue))
            } else if let nestedDict = value as? [String: Any] {
                if let structValue = convertDictionaryToValue(nestedDict).asStructure() {
                    attributes[key] = .structure(structValue)
                }
            } else if value is [Any] {
                // Log a warning instead of trying to convert arrays
                Log.warn(
                    "Arrays are not directly supported in OpenFeature Value. Skipping array value for key '\(key)'."
                )
            }
        }

        return .structure(attributes)
    }

    /**
        Converts OpenFeature evaluation context to DevCycle user
        - Parameter context: The evaluation context
        - Returns: The DevCycle user
     */
    internal static func dvcUserFromContext(_ context: EvaluationContext) throws -> DevCycleUser {
        // Extract attributes from context
        let attributes = unwrapValues(context.asMap())

        let userBuilder = DevCycleUser.builder()

        // Get first non-empty userId from context, attributes, or targetingKey
        let targetingKey = context.getTargetingKey()
        let userId = [
            // targetingKey defaults to empty string if not set
            targetingKey.isEmpty ? nil : targetingKey,
            attributes["user_id"] as? String,
            attributes["userId"] as? String,
        ]
        .compactMap { $0 }
        .first { !$0.isEmpty }

        // Set userId if available, else set isAnonymous to true
        if let userId = userId {
            _ = userBuilder.userId(userId)
        }

        // Create dictionaries to collect custom data
        var customData: [String: Any] = [:]
        var privateCustomData: [String: Any] = [:]

        for (key, value) in attributes {
            // Skip targetingKey, user_id, and userId as they're handled separately
            if key == "targetingKey" || key == "user_id" || key == "userId" {
                continue
            }

            // Handle known DevCycleUser properties
            if key == "email" || key == "name" || key == "language" || key == "country" {
                if let stringValue = value as? String {
                    switch key {
                    case "email":
                        _ = userBuilder.email(stringValue)
                    case "name":
                        _ = userBuilder.name(stringValue)
                    case "language":
                        _ = userBuilder.language(stringValue)
                    case "country":
                        _ = userBuilder.country(stringValue)
                    default:
                        break
                    }
                } else {
                    Log.warn(
                        "Expected DevCycleUser property \"\(key)\" to be \"String\" but got \"\(type(of: value))\" in EvaluationContext. Ignoring value."
                    )
                }
            } else if key == "isAnonymous" {
                if let boolValue = value as? Bool {
                    _ = userBuilder.isAnonymous(boolValue)
                } else {
                    Log.warn(
                        "Expected isAnonymous to be boolean but got \"\(type(of: value))\" in EvaluationContext. Ignoring value."
                    )
                }
            } else if key == "privateCustomData", let objectValue = value as? [String: Any] {
                privateCustomData = convertToDVCCustomData(objectValue)
            } else if key == "customData", let objectValue = value as? [String: Any] {
                let newData = convertToDVCCustomData(objectValue)
                for (dataKey, dataValue) in newData {
                    customData[dataKey] = dataValue
                }
            } else if isFlatJsonValue(value) {
                customData[key] = value
            } else {
                Log.warn(
                    "Unknown EvaluationContext property \"\(key)\" type. DevCycleUser only supports flat customData properties of type string / number / boolean / null"
                )
            }
        }

        // If no userId was set and isAnonymous wasn't explicitly set, default to anonymous
        if userId == nil && attributes["isAnonymous"] == nil {
            _ = userBuilder.isAnonymous(true)
        }

        // Add custom data to user
        if !customData.isEmpty {
            _ = userBuilder.customData(customData)
        }

        // Add private custom data to user
        if !privateCustomData.isEmpty {
            _ = userBuilder.privateCustomData(privateCustomData)
        }

        do {
            return try userBuilder.build()
        } catch {
            throw OpenFeatureError.invalidContextError
        }
    }

    internal static func unwrapValues(_ map: [String: Value]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in map {
            switch value {
            case .string(let str): result[key] = str
            case .boolean(let bool): result[key] = bool
            case .double(let dbl): result[key] = dbl
            case .integer(let int): result[key] = int
            case .structure(let dict): result[key] = unwrapValues(dict)
            default: break
            }
        }
        return result
    }

    internal static func isFlatJsonValue(_ value: Any) -> Bool {
        value is String || value is Int || value is Double || value is Bool || value is NSNull
            || value is NSNumber
    }

    /**
        Converts a dictionary to DevCycle CustomData
        - Parameter data: Dictionary to convert
        - Returns: Dictionary with valid custom data values
     */
    internal static func convertToDVCCustomData(_ data: [String: Any]) -> [String: Any] {
        var customData: [String: Any] = [:]
        for (key, value) in data {
            if isFlatJsonValue(value) {
                customData[key] = value
            } else {
                Log.warn(
                    "Custom data property \"\(key)\" has unsupported type \(type(of: value)). "
                        + "DevCycleUser only supports flat customData properties of type string / number / boolean / null"
                )
            }
        }
        return customData
    }

    internal static func getEvalReason<T>(variable: DVCVariable<T>) -> String {
        if let evalReason = variable.eval {
            return evalReason.reason
        }
        return variable.isDefaulted ? Reason.defaultReason.rawValue : Reason.targetingMatch.rawValue
    }

    internal static func getFlagMetadata<T>(variable: DVCVariable<T>) -> [String: FlagMetadataValue] {
        var flagMetadata: [String: FlagMetadataValue] = [:]
        if let evalReason = variable.eval {
            if let evalDetails = evalReason.details {
                flagMetadata["evalDetails"] = FlagMetadataValue.of(evalDetails)
            }
            if let evalTargetId = evalReason.targetId {
                flagMetadata["evalTargetId"] = FlagMetadataValue.of(evalTargetId)
            }
        }
        return flagMetadata
    }
}
