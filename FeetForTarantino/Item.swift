//
//  Item.swift
//  FeetForTarantino
//
//  Created by Daniiar Erkinov on 28/3/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
