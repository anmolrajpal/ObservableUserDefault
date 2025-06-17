import SwiftUI
import ObservableUserDefault
import Observation

@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, macCatalyst 17.0, visionOS 1.0, *)
@Observable final class Person {
   
   nonisolated(unsafe) static var store: UserDefaults = .random()
   
   @ObservableUserDefault @ObservationIgnored var name: String?
   
   @ObservableUserDefault(store: .shared) @ObservationIgnored var age: Int = 0
   
   @ObservableUserDefault(store: store) @ObservationIgnored var phone: String = "234567890"
   
   @ObservableUserDefault @ObservationIgnored var nonOptional: String = ""
   
   @ObservableUserDefault @ObservationIgnored var contactOptional: Contact?
   
   @ObservableUserDefault @ObservationIgnored var contact: Contact = .init(email: "")
}

struct Contact: Codable {
   let email: String
}

fileprivate extension UserDefaults {
   nonisolated(unsafe) static let shared = UserDefaults(suiteName: "SHARED")!
   static func random() -> UserDefaults {
      UserDefaults(suiteName: .uuid())!
   }
}

extension String {
   static func uuid() -> String {
      UUID().uuidString
   }
}
