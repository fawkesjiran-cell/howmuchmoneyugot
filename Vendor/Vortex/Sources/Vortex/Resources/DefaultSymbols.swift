//
// DefaultSymbols.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//
// Locally modified for this app: the packaged bitmap assets are not needed, so
// SF Symbols are used for the default particle symbols instead of Bundle.module.
//

import SwiftUI

extension Image {
    public static let circle = Image(systemName: "circle.fill")
    public static let confetti = Image(systemName: "square.fill")
    public static let sparkle = Image(systemName: "star.fill")
}
