import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ObservableUserDefaultMacro·Old: AccessorMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        // Ensure the macro can only be attached to variable properties.
        guard let varDecl = declaration.as(VariableDeclSyntax.self), varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
            throw ObservableUserDefaultError.notVariableProperty
        }
        
        // Ensure the variable is defines a single property declaration, for example,
        // `var name: String` and not multiple declarations such as `var name, address: String`.
        guard varDecl.bindings.count == 1, let binding = varDecl.bindings.first else {
            throw ObservableUserDefaultError.propertyMustContainOnlyOneBinding
        }
        
        // Ensure there is no computed property block attached to the variable already.
        guard binding.accessorBlock == nil else {
            throw ObservableUserDefaultError.propertyMustHaveNoAccessorBlock
        }
        
        // Ensure there is no initial value assigned to the variable.
//        guard binding.initializer == nil else {
//            throw ObservableUserDefaultError.propertyMustHaveNoInitializer
//        }
        
        // For simple variable declarations, the binding pattern is `IdentifierPatternSyntax`,
        // which defines the name of a single variable.
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            throw ObservableUserDefaultError.propertyMustUseSimplePatternSyntax
        }
        
        // Check if there is an explicit argument provided to the macro.
        // If so, extract the key, defaultValue, and store to use, and provide stored properties from `UserDefaults` that use the values extracted from the macro argument.
        // If not, use a static property on `UserDefaults` with the same name as the property.
        guard let arguments = node.arguments else {
           // FIXME: Should always have default arguments
            return [
            #"""
            get {
                access(keyPath: \.\#(pattern))
                return UserDefaults.\#(pattern)
            }
            """#,
            #"""
            set {
                withMutation(keyPath: \.\#(pattern)) {
                    UserDefaults.\#(pattern) = newValue
                }
            }
            """#
            ]
        }
        
        // Ensure the macro has one and only one argument.
        guard let exprList = arguments.as(LabeledExprListSyntax.self), exprList.count == 1, let expr = exprList.first?.expression.as(FunctionCallExprSyntax.self) else {
            throw ObservableUserDefaultArgumentError.macroShouldOnlyContainOneArgument
        }
        
        func keyExpr() -> ExprSyntax? {
            expr.arguments.first(where: { $0.label?.text == "key" })?.expression
        }
        
        func defaultValueExpr() -> ExprSyntax? {
            expr.arguments.first(where: { $0.label?.text == "defaultValue" })?.expression
        }
        
        func storeExprDeclName() -> DeclReferenceExprSyntax? {
            expr.arguments.first(where: { $0.label?.text == "store" })?.expression.as(MemberAccessExprSyntax.self)?.declName
        }
        
        if let type = binding.typeAnnotation?.type.as(OptionalTypeSyntax.self), let keyExpr = keyExpr(), let storeName = storeExprDeclName() {
            
            guard defaultValueExpr() == nil else {
                throw ObservableUserDefaultArgumentError.optionalTypeShouldHaveNoDefaultValue
            }
            
            // Macro is attached to an optional type with an argument that contains no default value.
            return [
            #"""
            get {
                access(keyPath: \.\#(pattern))
                return UserDefaults.\#(storeName).value(forKey: \#(keyExpr)) as? \#(type.wrappedType)
            }
            """#,
            #"""
            set {
                withMutation(keyPath: \.\#(pattern)) {
                    UserDefaults.\#(storeName).set(newValue, forKey: \#(keyExpr))
                }
            }
            """#
            ]
            
        } else if let type = binding.typeAnnotation?.type, let keyExpr = keyExpr(), let storeName = storeExprDeclName() {
            
            guard let defaultValueExpr = defaultValueExpr() else {
                throw ObservableUserDefaultArgumentError.nonOptionalTypeMustHaveDefaultValue
            }
            
            // Macro is attached to a non-optional type with an argument that contains a default value.
            return [
            #"""
            get {
                access(keyPath: \.\#(pattern))
                return UserDefaults.\#(storeName).value(forKey: \#(keyExpr)) as? \#(type) ?? \#(defaultValueExpr)
            }
            """#,
            #"""
            set {
                withMutation(keyPath: \.\#(pattern)) {
                    UserDefaults.\#(storeName).set(newValue, forKey: \#(keyExpr))
                }
            }
            """#
            ]
            
        } else {
            throw ObservableUserDefaultArgumentError.unableToExtractRequiredValuesFromArgument
        }
    }
    
}

// MARK: - ObservableUserDefaultMacro
// This macro provides `@Observable`-compatible property wrapper behavior for properties persisted in UserDefaults.
// It automatically encodes and decodes the property using `JSONEncoder`/`JSONDecoder`.
//
// ## Rules:
// - Non-optional properties **must** provide a default value.
// - Optional properties will use `nil` as the default.
// - Defaults to using `UserDefaults.standard` unless overridden in future versions.
//
// ## Example Usage:
// ```swift
// @ObservableUserDefault
// var displayName: String? // Uses nil as default
//
// @ObservableUserDefault
// var email: String = "user@example.com" // Requires default value for non-optional
// ```
//
// The above will expand to:
// ```swift
// var displayName: String? {
//     get {
//         access(keyPath: \.$displayName)
//         if let data = UserDefaults.standard.data(forKey: "displayName"),
//            let decoded = try? JSONDecoder().decode(String.self, from: data) {
//             return decoded
//         } else {
//             return nil
//         }
//     }
//     set {
//         withMutation(keyPath: \.$displayName) {
//             if let data = try? JSONEncoder().encode(newValue) {
//                 UserDefaults.standard.set(data, forKey: "displayName")
//             }
//         }
//     }
// }
// ```
public struct ObservableUserDefaultMacro: AccessorMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {

       // Validate macro usage on a variable declaration
       guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
          throw ObservableUserDefaultError.notVariableProperty
       }
       
       // Ensure it's a var (not let)
       guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
          throw ObservableUserDefaultError.notVariableProperty
       }
       
       // Ensure exactly one binding
       guard varDecl.bindings.count == 1, let binding = varDecl.bindings.first else {
          throw ObservableUserDefaultError.propertyMustContainOnlyOneBinding
       }
       
       // Ensure no accessor block (not computed)
       guard binding.accessorBlock == nil else {
          throw ObservableUserDefaultError.propertyMustHaveNoAccessorBlock
       }
       
       // Ensure identifier pattern is simple
       guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
          throw ObservableUserDefaultError.propertyMustUseSimplePatternSyntax
       }
       
       // Ensure a type annotation exists
       guard let typeSyntax = binding.typeAnnotation?.type.trimmed else {
          throw ObservableUserDefaultError.propertyMustHaveNoInitializer
       }
       
       
       // Use variable name as UserDefaults key
//       access(keyPath: \.\#(pattern))
//       let key = ExprSyntax(stringLiteral: "\\#(pattern)")
       
       
       // Default to standard UserDefaults (future versions may support custom stores)
//       var store = ExprSyntax(stringLiteral: "UserDefaults.standard")
       
       func extractStoreExpr(from attribute: AttributeSyntax) -> ExprSyntax {
          
          guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) else {
             return "UserDefaults.standard" // fallback if no arguments provided
          }
          
          for arg in arguments {
             if arg.label?.text == "store" {
                return arg.expression
             }
          }
          
          return "UserDefaults.standard"
       }
       
       func resolveStoreExpr(_ expr: ExprSyntax) -> ExprSyntax {
          
          if let declRef = expr.as(DeclReferenceExprSyntax.self) {
             // Simple identifier like `store`
             return "Self.\(raw: declRef.baseName.text)"
          } else if let member = expr.as(MemberAccessExprSyntax.self) {
             // Unqualified member like `.shared` or `.standard`
             if member.base == nil {
                // We assume UserDefaults unless user specifies otherwise
                return "UserDefaults.\(raw: member.declName.baseName.text)"
             } else {
                // Already has base, e.g. `Something.shared`
                return expr
             }
          } else {
             // Function calls or complex expressions (e.g., UserDefaults(suiteName: ...))
             return expr
          }
//          
//          if let declRef = expr.as(DeclReferenceExprSyntax.self) {
//             // Unqualified identifier like `store`
//             return "Self.\(raw: declRef.baseName.text)"
//          } else {
//             // Return full expression as-is
//             return expr
//          }
       }
       
       let rawStoreExpr = extractStoreExpr(from: node)
       let storeExpr = resolveStoreExpr(rawStoreExpr)
       let store = storeExpr
       
       /*
       if let arguments = node.arguments {
          // Not using this block currently
          guard let exprList = arguments.as(LabeledExprListSyntax.self), exprList.count == 1 else {
             throw ObservableUserDefaultArgumentError.macroShouldOnlyContainOneArgument
          }
          
          func storeExpr() -> ExprSyntax? {
             exprList.first(where: { $0.label?.text == "store" })?.expression
          }
       }
        */
       
       // Check if a default initializer exists (for non-optional types)
       let defaultExpr = binding.initializer?.value
       
       // Determine if the variable is Optional
       let isOptional = typeSyntax.is(OptionalTypeSyntax.self)
       
       if isOptional {
          // For Optional<T>: decode from data if available, else return nil or explicitly provided default
          let wrappedType = typeSyntax.as(OptionalTypeSyntax.self)!.wrappedType
          
          let getter: AccessorDeclSyntax =
            #"""
            get {
                access(keyPath: \.\#(pattern))
                if let data = \#(store).data(forKey: "\#(pattern)"),
                    let decoded = try? JSONDecoder().decode(\#(wrappedType).self, from: data) {
                    return decoded
                } else {
                    return \#(defaultExpr ?? "nil")
                }
            }
            """#
          
          let setter: AccessorDeclSyntax =
            #"""
            set {
                withMutation(keyPath: \.\#(pattern)) {
                    if let data = try? JSONEncoder().encode(newValue) {
                        \#(store).set(data, forKey: "\#(pattern)")
                    }
                }
            }
            """#
          
          return [getter, setter]
          
       } else {
          // For non-Optional types: fail at compile-time if no default value is provided
          guard let defaultExpr else {
             throw ObservableUserDefaultArgumentError.nonOptionalTypeMustHaveDefaultValue
          }
          
          let getter: AccessorDeclSyntax =
            #"""
            get {
                access(keyPath: \.\#(pattern))
                if let data = \#(store).data(forKey: "\#(pattern)"),
                    let decoded = try? JSONDecoder().decode(\#(typeSyntax).self, from: data) {
                    return decoded
                } else {
                    return \#(defaultExpr)
                }
            }
            """#
          
          let setter: AccessorDeclSyntax =
            #"""
            set {
                withMutation(keyPath: \.\#(pattern)) {
                    if let data = try? JSONEncoder().encode(newValue) {
                        \#(store).set(data, forKey: "\#(pattern)")
                    }
                }
            }
            """#
          
          return [getter, setter]
       }
    }
}

// MARK: - Errors

enum ObservableUserDefaultError: Error, CustomStringConvertible {
    case notVariableProperty
    case propertyMustContainOnlyOneBinding
    case propertyMustHaveNoAccessorBlock
    case propertyMustHaveNoInitializer
    case propertyMustUseSimplePatternSyntax
    
    var description: String {
        switch self {
        case .notVariableProperty:
            return "'@ObservableUserDefault' can only be applied to variables"
        case .propertyMustContainOnlyOneBinding:
            return "'@ObservableUserDefault' cannot be applied to multiple variable bindings"
        case .propertyMustHaveNoAccessorBlock:
            return "'@ObservableUserDefault' cannot be applied to computed properties"
        case .propertyMustHaveNoInitializer:
            return "'@ObservableUserDefault' cannot be applied to stored properties"
        case .propertyMustUseSimplePatternSyntax:
            return "'@ObservableUserDefault' can only be applied to a variables using simple declaration syntax, for example, 'var name: String'"
        }
    }
}

enum ObservableUserDefaultArgumentError: Error, CustomStringConvertible {
    case macroShouldOnlyContainOneArgument
    case nonOptionalTypeMustHaveDefaultValue
    case optionalTypeShouldHaveNoDefaultValue
    case unableToExtractRequiredValuesFromArgument
    
    var description: String {
        switch self {
        case .macroShouldOnlyContainOneArgument:
            return "Must provide an argument when using '@ObservableUserDefault' with parentheses"
        case .nonOptionalTypeMustHaveDefaultValue:
            return "'@ObservableUserDefault' arguments on non-optional types must provide default values"
        case .optionalTypeShouldHaveNoDefaultValue:
            return "'@ObservableUserDefault' arguments on optional types should not use default values"
        case .unableToExtractRequiredValuesFromArgument:
            return "'@ObservableUserDefault' unable to extract the required values from the argument"
        }
    }
}

@main
struct ObservableUserDefaultPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObservableUserDefaultMacro.self
    ]
}
