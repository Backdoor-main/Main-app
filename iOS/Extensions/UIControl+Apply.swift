//
//  UIControl+Apply.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import UIKit

extension UIControl {
    /// Apply a configuration to a UIControl and return it (builder pattern)
    /// - Parameter configuration: Configuration closure
    /// - Returns: The configured control
    @discardableResult
    func apply<T>(_ configuration: (T) -> Void) -> T where T: UIControl {
        // Apply the configuration to self
        configuration(self as! T)
        // Return self for chaining
        return self as! T
    }
}
