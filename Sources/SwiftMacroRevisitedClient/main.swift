import SwiftMacroRevisited
import SwiftUI
import COW

let _ = #Color(0xFFEEAA) // Compiled

/* Not compiled:
let _ = #Color(0xFFEEA) // Invalid RGB, not compiled
*/

func foo(_ bar: Int?) {
  #unwrap(bar) {
    print(bar)
  }
}

@COW
struct User {

  var name: String

  var avatar: URL

  var avatarsInDifferentScales: [Int : URL]

  var userID: String

  var socialMedias: [String]

  var brief: String

  // ...

}
