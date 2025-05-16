# DevCycle OpenFeature Provider

This package provides a DevCycle provider implementation for the [OpenFeature iOS SDK](https://openfeature.dev/docs/reference/technologies/client/swift) feature flagging SDK. It allows you to use DevCycle as the feature flag management system behind the standardized OpenFeature API.

## Requirements

The DevCycle OpenFeature Provider requires iOS 14.0+ / tvOS 14.0+ / watchOS 7.0+ / macOS 11.0+

## Installation

### Swift Package Manager

Add the dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/DevCycleHQ/ios-openfeature-provider.git", from: "1.0.0")
```

Then add `DevCycleOpenFeatureProvider` to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "DevCycleOpenFeatureProvider", package: "ios-openfeature-provider")
    ]
)
```

Note that this package automatically includes the DevCycle SDK as a dependency.

## Usage

```swift
import OpenFeature
import DevCycle
import DevCycleOpenFeatureProvider

// Configure DevCycle options if needed
let options = DevCycleOptions.builder()
    .logLevel(.debug)
    .build()

// Configure the DevCycle provider
let provider = DevCycleProvider(sdkKey: "<DEVCYCLE_MOBILE_SDK_KEY>", options: options)

// Set up the evaluation context
let evaluationContext = MutableContext(
    targetingKey: "user-123",
    structure: MutableStructure(attributes: [
        "email": .string("user@example.com"),
        "name": .string("Test User"),
        "customData": .structure(["customkey": .string("customValue")])
    ])
)

// Initialize OpenFeature with the DevCycle provider
Task {
    // Set the provider with initial context
    await OpenFeatureAPI.shared.setProviderAndWait(
        provider: provider, initialContext: evaluationContext)
    
    // Get a client
    let client = OpenFeatureAPI.shared.getClient()
    
    // Evaluate flags
    let boolValue = client.getBooleanValue(key: "my-boolean-flag", defaultValue: false)
    let stringValue = client.getStringValue(key: "my-string-flag", defaultValue: "default")
    
    print("Bool flag value: \(boolValue)")
    print("String flag value: \(stringValue)")
    
    // Update context later if needed
    let newContext = MutableContext(
        targetingKey: "user-123",
        structure: MutableStructure(attributes: [
            "country": .string("CA")
        ])
    )
    await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: newContext)
}
```

## Example App

An example iOS application demonstrating how to use the DevCycle OpenFeature Provider can be found in the [Examples](./Examples) directory. This example shows how to:

1. Initialize the DevCycle provider
2. Set up an evaluation context
3. Evaluate different types of feature flags
4. Handle flag changes

## Development

### Building and Testing

To build and test the provider:

```bash
swift build
swift test
```

### Local Development with DevCycle SDK

During development, you might want to test this provider with a local copy of the DevCycle SDK. To do this, you can temporarily modify the `Package.swift` file to use a local path reference:

```swift
// In Package.swift, replace:
.package(
    name: "DevCycle",
    url: "https://github.com/DevCycleHQ/ios-client-sdk.git",
    .upToNextMajor(from: "1.18.0")
)

// With:
.package(
    name: "DevCycle",
    path: "../ios-client-sdk"  // Adjust the path to your local DevCycle SDK repo
)
```

This setup allows for easier development and testing:
- Changes to the main DevCycle SDK are immediately reflected in the provider
- You can test changes to both packages together without publishing
- Make sure to revert this change before committing

### Dependencies

This package depends on:
- [DevCycle iOS SDK](https://github.com/DevCycleHQ/ios-client-sdk)
- [OpenFeature Swift SDK](https://github.com/open-feature/swift-sdk)