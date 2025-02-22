// Original Copyright © 2021 Brad Howes. All rights reserved.
// Modified code: Nick Ager 2024

import XCTest
@testable import MathParser

final class TokenTests: XCTestCase {
    
    let variables = ["a": 3.0, "b": 4.0, "ab": 99.0]
    let unaryFuncs: MathParser.UnaryFunctionDict = [  "DOUBLE":  { $0 * 2.0 } ]
    let binaryFuncs: MathParser.BinaryFunctionDict = [:]
    
    override func setUp() {}
    
    func evalToken(_ token: Token,
                   variables: MathParser.VariableDict? = nil,
                   unaryFunctions: MathParser.UnaryFunctionDict? = nil,
                   binaryFunctions: MathParser.BinaryFunctionDict? = nil) -> Double {
        (try? token.eval(state: .init(variables: variables ?? self.variables,
                                      unaryFunctions: unaryFunctions ?? self.unaryFuncs,
                                      binaryFunctions: binaryFunctions ?? self.binaryFuncs))) ?? .nan
    }
    
    func testConstant() {
        XCTAssertEqual(12.345, evalToken(.constant(value: 12.345)))
    }
    
    func testReducingToConstant() {
        XCTAssertEqual(5.0, evalToken(.reducer(
            lhs: .constant(value: 2.0),
            rhs: .constant(value: 3.0),
            op: { $0 + $1 }, name: "+")))
    }
    
    func testVariable() {
        XCTAssertTrue(evalToken(.variable(name: "blah")).isNaN)
    }
    
    func testExistingVariable() {
        let variable = Token.variable(name: "ab")
        XCTAssertEqual(99, evalToken(variable))
        XCTAssertTrue(variable.unresolved.variables.contains("ab"))
    }
    
    func testMissingSymbolGeneratesNaN() {
        let variable = Token.variable(name: "abc")
        XCTAssertTrue(evalToken(variable).isNaN)
    }
    
    func testMissingUnaryFuncGeneratesNaN() {
        XCTAssertTrue(evalToken(.unaryCall(op: nil, name: "abc", arg: .constant(value: 123.45))).isNaN)
    }
    
    func testMissingBinaryFuncGeneratesNaN() {
        let token: Token = .binaryCall(op: nil, name: "abc",
                                       arg1: .constant(value: 123.45),
                                       arg2: .variable(name: "a"))
        XCTAssertTrue(evalToken(token).isNaN)
        XCTAssertTrue(token.unresolved.variables.contains("a") && token.unresolved.binaryFunctions.contains("abc"))
    }
    
    func testUnaryCallResolution() {
        let variables = ["t": Double.pi / 4.0]
        XCTAssertTrue(evalToken(.unaryCall(op: nil, name: "sin", arg: .variable(name: "t"))).isNaN)
        XCTAssertTrue(evalToken(.unaryCall(op: sin, name: "sin", arg: .variable(name: "t"))).isNaN)
        XCTAssertEqual(0.7071067811865475,
                       evalToken(.unaryCall(op: sin, name: "sin", arg: .variable(name: "t")), variables: variables),
                       accuracy: 1.0E-8)
    }
    
    func testUnresolvedProcessing() {
        XCTAssertTrue(Token.constant(value: 1.2).unresolved.isEmpty)
        XCTAssertTrue(Token.variable(name: "foo").unresolved.count == 1)
        XCTAssertTrue(Token.unaryCall(op: nil, name: "foo", arg: .constant(value: 1.2)).unresolved.count == 1)
        XCTAssertTrue(Token.unaryCall(op: sin, name: "sin", arg: .constant(value: 1.2)).unresolved.isEmpty)
        XCTAssertTrue(Token.binaryCall(op: nil, name: "foo", arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.count == 1)
        XCTAssertTrue(Token.binaryCall(op: hypot, name: "hypot", arg1: .constant(value: 1.2), arg2: .constant(value: 2.1)).unresolved.isEmpty)
        XCTAssertTrue(Token.binaryCall(op: +, name: "+", arg1: .variable(name: "a"), arg2: .constant(value: 1.2)).unresolved.count == 1)
    }
    
    func testDescription() {
        XCTAssertEqual("1.23", Token.constant(value: 1.23).description)
        XCTAssertEqual("foobar", Token.variable(name: "foobar").description)
        XCTAssertEqual("unary(+(1.0, 2.0))", Token.unaryCall(op: nil, name: "unary",
                                                             arg: .binaryCall(op: (+), name: "+",
                                                                              arg1: .constant(value: 1),
                                                                              arg2: .constant(value: 2))).description)
        XCTAssertEqual("binary(1.0, blah)", Token.binaryCall(op: nil, name: "binary",
                                                             arg1: .constant(value: 1),
                                                             arg2: .variable(name: "blah")).description)
        XCTAssertEqual("+(1.0, 2.0)", Token.binaryCall(op: +, name: "+",
                                                       arg1: .constant(value: 1),
                                                       arg2: .constant(value: 2)).description)
    }
    
    func testTokenEvalThrowsError() {
        XCTAssertThrowsError(try Token.variable(name: "undefined").eval(state: .init(variables: variables,
                                                                                     unaryFunctions: unaryFuncs,
                                                                                     binaryFunctions: binaryFuncs)))
    }
    
    func testTokenEvalThrowsErrorForUndefinedVariable() {
        do {
            _ = try Token.variable(name: "undefined").eval(state: .init(variables: variables,
                                                                        unaryFunctions: unaryFuncs,
                                                                        binaryFunctions: binaryFuncs))
        } catch {
            print(error)
            XCTAssertEqual("\(error)", "Variable 'undefined' not found")
        }
    }
    
    func testTokenEvalThrowsErrorForUndefinedUnaryFunction() {
        do {
            _ = try Token.unaryCall(op: nil, name: "undefined", arg: .constant(value: 1.2))
                .eval(state: .init(variables: variables,
                                   unaryFunctions: unaryFuncs,
                                   binaryFunctions: binaryFuncs))
        } catch {
            print(error)
            XCTAssertEqual("\(error)", "Function 'undefined' not found")
        }
    }
    
    func testTokenEvalThrowsErrorForUndefinedBinaryFunction() {
        do {
            _ = try Token.binaryCall(op: nil, name: "undefined",
                                     arg1: .constant(value: 1.2),
                                     arg2: .constant(value: 2.4))
            .eval(state: .init(variables: variables,
                               unaryFunctions: unaryFuncs,
                               binaryFunctions: binaryFuncs))
        } catch {
            print(error)
            XCTAssertEqual("\(error)", "Function 'undefined' not found")
        }
    }
}
