//
//  BloodGlucose.swift
//  CareKitCloud
//
//  Created by Ken on 8/15/25.
//

import CareKit
import CareKitFHIR
import CareKitStore
import Foundation
import SwiftData

@Model
class BloodGlucose {
    var title: String = ""
    
    init(title: String) {
        self.title = title
    }
    
}
