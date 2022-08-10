//
//  MathUtilities.swift
//  EasyHTML
//
//  Created by Артем on 09/09/2018.
//  Copyright © 2018 Артем. All rights reserved.
//


import CoreGraphics

func clamp<T: Comparable>(value: T, minimum: T, maximum: T) -> T {
    min(max(value, minimum), maximum)
}

func rotate(vector: CGVector, by radians: Double) -> CGVector {

    let sine = CGFloat(sin(radians))
    let cosine = CGFloat(cos(radians))

    let dx = vector.dx * cosine - vector.dy * sine
    let dy = vector.dy * cosine + vector.dx * sine

    return CGVector(dx: dx, dy: dy)
}

func radians(degrees: CGFloat) -> CGFloat {
    degrees * CGFloat.pi / 180.0
}
