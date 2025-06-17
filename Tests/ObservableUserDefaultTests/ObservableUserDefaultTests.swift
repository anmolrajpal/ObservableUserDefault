import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ObservableUserDefaultMacros)
import ObservableUserDefaultMacros

let testMacros: [String: Macro.Type] = [
    "ObservableUserDefault": ObservableUserDefaultMacro.self,
]
#endif
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, macCatalyst 17.0, visionOS 1.0, *)
final class ObservableUserDefaultTests: XCTestCase {
   
   func testObservableUserDefault() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               var name: String?
           }
           """#,
           expandedSource:
           #"""
           @Observable
           class AppData {
               @ObservationIgnored
               var name: String? {
                   get {
                       access(keyPath: \.name)
                       if let data = UserDefaults.standard.data(forKey: "name"),
                           let decoded = try? JSONDecoder().decode(String.self, from: data) {
                           return decoded
                       } else {
                           return nil
                       }
                   }
                   set {
                       withMutation(keyPath: \.name) {
                           if let data = try? JSONEncoder().encode(newValue) {
                               UserDefaults.standard.set(data, forKey: "name")
                           }
                       }
                   }
               }
           }
           """#,
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultOptionalWithDefaultValue() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               var name: String? = "John"
           }
           """#,
           expandedSource:
           #"""
           @Observable
           class AppData {
               @ObservationIgnored
               var name: String? {
                   get {
                       access(keyPath: \.name)
                       if let data = UserDefaults.standard.data(forKey: "name"),
                           let decoded = try? JSONDecoder().decode(String.self, from: data) {
                           return decoded
                       } else {
                           return "John"
                       }
                   }
                   set {
                       withMutation(keyPath: \.name) {
                           if let data = try? JSONEncoder().encode(newValue) {
                               UserDefaults.standard.set(data, forKey: "name")
                           }
                       }
                   }
               }
           }
           """#,
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultWithCustomStore() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           @Observable
           class AppData {
               @ObservableUserDefault(store: .shared)
               @ObservationIgnored
               var name: String?
           }
           """#,
           expandedSource:
           #"""
           @Observable
           class AppData {
               @ObservationIgnored
               var name: String? {
                   get {
                       access(keyPath: \.name)
                       if let data = UserDefaults.shared.data(forKey: "name"),
                           let decoded = try? JSONDecoder().decode(String.self, from: data) {
                           return decoded
                       } else {
                           return nil
                       }
                   }
                   set {
                       withMutation(keyPath: \.name) {
                           if let data = try? JSONEncoder().encode(newValue) {
                               UserDefaults.shared.set(data, forKey: "name")
                           }
                       }
                   }
               }
           }
           """#,
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultWithRandomStaticStore() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           @Observable
           class AppData {
               nonisolated(unsafe) static var store: UserDefaults = UserDefaults(suiteName: "preview")!
               @ObservableUserDefault(store: store) 
               @ObservationIgnored 
               var phone: String = "1234567890"
           }
           fileprivate extension UserDefaults {
               static func random() -> UserDefaults {
                   UserDefaults(suiteName: .uuid())!
               }
           }
           extension String {
               static func uuid() -> String {
                   UUID().uuidString
               }
           }
           """#,
           expandedSource:
           #"""
           @Observable
           class AppData {
               nonisolated(unsafe) static var store: UserDefaults = UserDefaults(suiteName: "preview")!
               
               @ObservationIgnored
               var phone: String {
                   get {
                       access(keyPath: \.phone)
                       if let data = Self.store.data(forKey: "phone"),
                           let decoded = try? JSONDecoder().decode(String.self, from: data) {
                           return decoded
                       } else {
                           return "1234567890"
                       }
                   }
                   set {
                       withMutation(keyPath: \.phone) {
                           if let data = try? JSONEncoder().encode(newValue) {
                               Self.store.set(data, forKey: "phone")
                           }
                       }
                   }
               }
           }
           fileprivate extension UserDefaults {
               static func random() -> UserDefaults {
                   UserDefaults(suiteName: .uuid())!
               }
           }
           extension String {
               static func uuid() -> String {
                   UUID().uuidString
               }
           }
           """#,
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultNonOptionalDefaultValue() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               var name: String = "John"
           }
           """#,
           expandedSource:
           #"""
           @Observable
           class AppData {
               @ObservationIgnored
               var name: String {
                   get {
                       access(keyPath: \.name)
                       if let data = UserDefaults.standard.data(forKey: "name"),
                           let decoded = try? JSONDecoder().decode(String.self, from: data) {
                           return decoded
                       } else {
                           return "John"
                       }
                   }
                   set {
                       withMutation(keyPath: \.name) {
                           if let data = try? JSONEncoder().encode(newValue) {
                               UserDefaults.standard.set(data, forKey: "name")
                           }
                       }
                   }
               }
           }
           """#,
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultNonOptionalNoDefaultValue() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               var name: String
           }
           """#,
           expandedSource:
           #"""
           @Observable
           class AppData {
               @ObservationIgnored
               var name: String
           }
           """#
           ,
           diagnostics: [
               DiagnosticSpec(message: "'@ObservableUserDefault' arguments on non-optional types must provide default values", line: 3, column: 5)
           ],
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultStoringOptionalCodable() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           #"""
           struct Contact: Codable {
               let email: String
           }
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               var contact: Contact?
           }
           """#,
           expandedSource:
           #"""
           struct Contact: Codable {
               let email: String
           }
           @Observable
           class AppData {
               @ObservationIgnored
               var contact: Contact? {
                   get {
                       access(keyPath: \.contact)
                       if let data = UserDefaults.standard.data(forKey: "contact"),
                           let decoded = try? JSONDecoder().decode(Contact.self, from: data) {
                           return decoded
                       } else {
                           return nil
                       }
                   }
                   set {
                       withMutation(keyPath: \.contact) {
                           if let data = try? JSONEncoder().encode(newValue) {
                               UserDefaults.standard.set(data, forKey: "contact")
                           }
                       }
                   }
               }
           }
           """#,
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   func testObservableUserDefaultWithConstant() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           """
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               let name: String
           }
           """,
           expandedSource:
           """
           @Observable
           class AppData {
               @ObservationIgnored
               let name: String
           }
           """,
           diagnostics: [
               DiagnosticSpec(message: "'@ObservableUserDefault' can only be applied to variables", line: 3, column: 5)
           ],
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   func testObservableUserDefaultWithComputedProperty() throws {
       #if canImport(ObservableUserDefaultMacros)
       assertMacroExpansion(
           """
           @Observable
           class AppData {
               @ObservableUserDefault
               @ObservationIgnored
               var name: String {
                   return "John Appleseed"
               }
           }
           """,
           expandedSource:
           """
           @Observable
           class AppData {
               @ObservationIgnored
               var name: String {
                   return "John Appleseed"
               }
           }
           """,
           diagnostics: [
               DiagnosticSpec(message: "'@ObservableUserDefault' cannot be applied to computed properties", line: 2, column: 5)
           ],
           macros: testMacros
       )
       #else
       throw XCTSkip("macros are only supported when running tests for the host platform")
       #endif
   }
   
   
}
