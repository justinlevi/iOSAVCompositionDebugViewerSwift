import UIKit

extension Array {
  
  mutating func removeAtIndexes (ixs:[Int]) -> () {
    for i in ixs.sort(>) {
      self.removeAtIndex(i)
    }
  }
  
  subscript (safe index: Int) -> Element? {
    return self.indices ~= index ? self[index] : nil
  }
  
}


