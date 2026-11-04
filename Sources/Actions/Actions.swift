import EdgyCore

/// Batch EDGY-ACTIONS owns this module.
public enum ActionsInfo {
  public static let module = "Actions"
}

// FROZEN FACTORY SIGNATURE — the app calls this. Replace the body, never the signature.

/// The live action registry, backed by real system outputs. Only the app may call this;
/// tests must build registries from mock outputs.
public func makeLiveActionRegistry(settings: AppSettings) -> ActionPerforming { NoopActionRegistry() }

final class NoopActionRegistry: ActionPerforming {
  var available: [ActionDescriptor] { [] }
  func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {
    throw ActionError.unknownAction(id)
  }
}
