import Foundation
import OpenFeature

/// Local test helper because the OpenFeature package does not export its test-only MutableContext.
final class MutableContext: EvaluationContext {
    private let queue = DispatchQueue(label: "com.devcycle.openfeature.tests.mutablecontext")
    private var targetingKey: String
    private var structure: MutableStructure

    init(targetingKey: String = "", structure: MutableStructure = MutableStructure()) {
        self.targetingKey = targetingKey
        self.structure = structure
    }

    convenience init(attributes: [String: Value]) {
        self.init(structure: MutableStructure(attributes: attributes))
    }

    func deepCopy() -> EvaluationContext {
        queue.sync {
            MutableContext(targetingKey: targetingKey, structure: structure.deepCopy())
        }
    }

    func getTargetingKey() -> String {
        queue.sync { targetingKey }
    }

    func keySet() -> Set<String> {
        queue.sync { structure.keySet() }
    }

    func getValue(key: String) -> Value? {
        queue.sync { structure.getValue(key: key) }
    }

    func asMap() -> [String: Value] {
        queue.sync { structure.asMap() }
    }

    func asObjectMap() -> [String: AnyHashable?] {
        queue.sync { structure.asObjectMap() }
    }

    func setTargetingKey(targetingKey: String) {
        queue.sync { self.targetingKey = targetingKey }
    }
}

extension MutableContext {
    @discardableResult
    func add(key: String, value: Value) -> MutableContext {
        queue.sync { structure.add(key: key, value: value) }
        return self
    }
}
