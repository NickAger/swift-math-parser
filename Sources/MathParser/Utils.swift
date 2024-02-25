// Copyright © 2023 Brad Howes. All rights reserved.
// Modified  by Nick Ager 2024

import Foundation

@inlinable
func factorial(_ n: Double) -> Double { (1...Int(n)).map(Double.init).reduce(1.0, *) }

@inlinable
func multiply(lhs: Token, rhs: Token) -> Token { Token.reducer(lhs: lhs, rhs: rhs, op: (*), name: "*") }
