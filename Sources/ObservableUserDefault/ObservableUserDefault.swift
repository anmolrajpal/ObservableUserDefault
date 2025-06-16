import Foundation

@attached(accessor, names: named(get), named(set))
public macro ObservableUserDefault(store: UserDefaults = .standard) = #externalMacro(
    module: "ObservableUserDefaultMacros",
    type: "ObservableUserDefaultMacro"
)
