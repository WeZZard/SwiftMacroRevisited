import SwiftMacroRevisited
import COW
import Observation
import Foundation

@propertyWrapper
struct Capitalized {
  
  var wrappedValue: String {
    didSet {
      wrappedValue = wrappedValue.capitalized
    }
  }
  
}

class Updater: CustomStringConvertible {
  
  func update() {
    
  }
  
  var description: String {
    return "<Updater: \(ObjectIdentifier(self))>"
  }
  
}

// MARK: - Variable Redeclaration

/* Not compiled 1:
 
func foo(_ bar: Int?) {
  let updater = Updater()
  #unwrap(bar) {
    let updater = Updater()
    print(bar)
    updater.update()
  }
  print(updater.description)
}
*/

// MARK: - Variable Redeclaration

/* Not compiled 2:
@COW
@DictionaryLike
struct User1 {
  
  var name: String
  
  var avatars: [URL]
  
  var trackParams: [String : Any]
  
  var info: [String : Any]?

}
 */


// MARK: - Variable Cannot Provide Both A 'read' Accessor And A Getter

/* Not compiled 3:
@COW
@DictionaryLike
struct User2 {
  
  var name: String
  
  var avatars: [URL]
  
  var trackParams: [String : Any]
  
  @UseDictionaryStorage
  var info: [String : Any]?

}
*/

// MARK: - Production Level of COW Macro Resolved Potential Name Conflicts

struct _Box {
  
}

@COW
struct User3 {
  
  var name: String
  
  var avatars: [URL]
  
  var trackParams: [String : Any]

}

// MARK: - A Conflict Brought by Accessor Macros Transforming Stored Properties into Computed

/* Not compiled 5:

@COW
struct User4 {
  
  @Capitalized
  var name: String = ""
  
}
*/

// MARK: - A Conflict Brought by Accessor Macros Transforming Stored Properties into Computed

/* Not compiled 6:
 
@COW
struct User5 {
  
  lazy var name: String = { "Jane Doe" }()
  
}
*/

// MARK: - A Conflict Brought by @Observable Transforming Stored Properties into Computed

/* Not compiled 7:
 
@Observable
class User6 {
  
  @Capitalized
  var name: String

  init(name: String) {
    self.name = name
  }
  
}
*/


// MARK: - Resolving Conlficts Brought by @Observable Transforming Stored Properties into Computed

@Observable
class User {

  @Capitalized
  @ObservationIgnored
  var _name: String
  
  init(name: String) {
    self.name = name
  }

  var name: String {
    init(initialValue) initializes(__name) {
      __name = Capitalized(wrappedValue: initialValue)
    }
    get {
      access(keyPath: \.name)
      return _name
    }
    set {
      withMutation(keyPath: \.name) {
        _name = newValue
      }
    }
  }
  
}


// MARK: - An Example of makeUniqueName


func foo() {
  #uniqueName()
}

