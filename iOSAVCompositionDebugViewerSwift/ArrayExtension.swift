//
//  ArrayExtension.swift
//  ProgrammingIOS8CollectionViews
//
//  Created by Justin Winter on 3/26/15.
//  Copyright (c) 2015 wintercreative. All rights reserved.
//

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


