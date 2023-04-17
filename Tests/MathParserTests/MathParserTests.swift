// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
@testable import MathParser

final class MathParserTests: XCTestCase {

  var parser: MathParser!

  override func setUp() {
    parser = MathParser()
  }

  func testDouble() {
    XCTAssertEqual(3, parser.parse("3")?.eval())
    XCTAssertEqual(3, parser.parse(" 3")?.eval())
    XCTAssertEqual(3, parser.parse(" 3 ")?.eval())
    XCTAssertEqual(-3, parser.parse(" -3")?.eval())
    XCTAssertEqual(-3, parser.parse("-3 ")?.eval())
    XCTAssertEqual(-3.45, parser.parse("-3.45")?.eval())
    XCTAssertEqual(-3.45E2, parser.parse("-3.45E2 ")?.eval())
    XCTAssertNil(parser.parse("- 3")?.eval())
  }

  func testConstruction() {
    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return 0.0
      }
    })
    XCTAssertEqual(6, parser.parse("3*b")?.eval())
    XCTAssertEqual(1.5, parser.parse("3÷b")?.eval())

    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return 0.0
      }
    }, unaryFunctions: {name in
      switch name {
      case "foo": return {(value: Double) -> Double in value * 3}
      default: return nil
      }
    })
    XCTAssertEqual(7, parser.parse("a+3*b")?.eval())

    parser = MathParser(variables: {name in
      switch name {
      case "a": return 1.0
      case "b": return 2.0
      default: return 0.0
      }
    }, unaryFunctions: {name in
      switch name {
      case "foo": return {(value: Double) -> Double in value * 3}
      default: return nil
      }
    }, binaryFunctions: {name in
      switch name {
      case "bar": return {(x: Double, y: Double) -> Double in x * y}
      default: return nil
      }
    })
    XCTAssertEqual(42, parser.parse("bar(a+3*b,6)")?.eval())

    parser = MathParser(binaryFunctions: {name in
      switch name {
      case "bar": return {(x: Double, y: Double) -> Double in x * y}
      default: return nil
      }
    }, enableImpliedMultiplication: true)
    XCTAssertEqual(12, parser.parse("bar(3, 4)")?.eval())

    XCTAssertEqual(12, parser.parse("abc")?.eval(variables: {name in
      switch name {
      case "abc": return 12
      default: return nil
      }
    }))
  }

  func testImpliedMultiplicationOrUnaryFunction() {
    parser = MathParser(enableImpliedMultiplication: true)
    let variables = ["a": 2.0, "b": 3.0, "c": 4.0]
    XCTAssertTrue(parser.parse("abc(3)")!.eval(variables: variables.producer).isNaN)
    let unary = ["bc": { $0 * 10.0}]
    XCTAssertEqual(2.0 * 30.0, parser.parse("abc(3)")?.eval(variables: variables.producer, unaryFunctions: unary.producer))
  }

  func testImpliedMultiplicationWithUnaryFunction() {
    parser = MathParser(enableImpliedMultiplication: true)
    let variables = ["a": 2.0, "b": 3.0, "c": 4.0]
    let unary = ["bc": { $0 * 10.0}]
    XCTAssertEqual(2.0 * 30.0, parser.parse("abc(3)")!.eval(variables: variables.producer, unaryFunctions: unary.producer))
  }

  func testConstants() {
    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(.pi, parser.parse("pi")?.eval())
    XCTAssertEqual(.pi, parser.parse("π")?.eval())
    XCTAssertEqual(.pi, parser.parse("(pi)")?.eval())
    XCTAssertEqual(2 * .pi, parser.parse("2(pi)")?.eval())
    XCTAssertEqual(2 * .pi, parser.parse("2pi")?.eval())
  }

  func testAddition() {
    XCTAssertEqual(3, parser.parse("1+2")?.eval())
    XCTAssertEqual(6, parser.parse("1+2+3")?.eval())
    XCTAssertEqual(6, parser.parse(" 1+ 2 + 3 ")?.eval())
  }

  func testSubtraction() {
    XCTAssertEqual(-1, parser.parse("1 - 2")?.eval())
    XCTAssertEqual(-4, parser.parse("1 - 2 - 3")?.eval())
    XCTAssertEqual(-4, parser.parse(" 1 - 2 - 3 ")?.eval())
  }

  func testOrderOfOperations() {
    let expected: Double = 1.0 + 2.0 * 3.0 / 4.0 - pow(5.0, 6.0)
    let actual = parser.parse(" 1 + 2 * 3 / 4 - 5 ^ 6")
    XCTAssertEqual(expected, actual?.eval())
  }

  func testParentheses() {
    XCTAssertEqual(( 1.0 + 2.0 ) * 3.0 / 4.0 - pow(5.0, (6.0 + 7.0)),
                   parser.parse(" ( 1 + 2 ) * 3 / 4 - 5 ^ ( 6+ 7)")?.eval())
    XCTAssertEqual(1, parser.parse(" (1) ")?.eval())
    XCTAssertEqual(1, parser.parse("((1))")?.eval())
    XCTAssertNil(parser.parse(" () ")?.eval())
    XCTAssertEqual(parser.parse(" ( ( 8 + 9) *3) ")?.eval(), (8+9)*3)
  }

  func testNestedParentheses() {
    let expected: Double = ((1.0 + 2.0) * (3.0 + 4.0)) / pow(5.0, 1.0 + 3.0)
    let actual = parser.parse("((1 + 2) * (3 + 4)) / 5 ^ (1 + 3)")
    XCTAssertEqual(expected, actual?.eval())
    XCTAssertEqual(expected, actual?.value)
  }

  func testMissingClosingParenthesis() {
    XCTAssertNil(parser.parse("(1 + 2"))
  }

  func testMissingOpeningParenthesis() {
    XCTAssertNil(parser.parse("1 + 2)"))
  }

  func testSymbolFound() {
    XCTAssertEqual(pow(1 + 2 * .pi, 2), parser.parse("(1 + 2 * pi) ^ 2")?.eval())
  }

  func testSymbolNotFound() {
    XCTAssertTrue(parser.parse("(1 + 2 * pip) ^ 2")!.eval().isNaN)
  }

  func testFunction1Found() {
    XCTAssertEqual(sin(2 * .pi), parser.parse(" sin(2 * pi)")?.eval())
  }

  func testFunction1NotFound() {
    XCTAssertTrue(parser.parse(" sinc(2 * pi)")!.eval().isNaN)
  }

  func testFunction2Found() {
    XCTAssertEqual(pow(2 * .pi, 3.4), parser.parse(" pow(2 * pi, 3.4)")?.eval())
  }

  func testFunction2NotFound() {
    XCTAssertTrue(parser.parse(" blah(2 * pi, 3.4)")!.eval().isNaN)
  }

  func testImpliedMultiply() {
    // Default is disabled
    XCTAssertNil(parser.parse("2 pi"))
    XCTAssertNil(parser.parse("2pi"))
    XCTAssertNil(parser.parse("2 sin(pi / 2)"))
    XCTAssertNil(parser.parse("2 (1 + 2)"))

    let parser = MathParser(enableImpliedMultiplication: true)
    XCTAssertEqual(2.0 * .pi * 3.0, parser.parse("2 pi * 3")?.eval())
    XCTAssertEqual(.pi * 3.0, parser.parse("π 3")?.eval())
    XCTAssertEqual(2.0 * .pi * 3.0, parser.parse("2pi 3")?.eval())
    XCTAssertEqual(2.0 * sin(.pi / 2), parser.parse("2 sin(pi / 2)")?.eval())
    XCTAssertEqual(2.0 * (1 + 2), parser.parse("2(1 + 2)")?.eval())
    XCTAssertEqual(2.0 * .pi, parser.parse("2pi")?.eval())
    XCTAssertEqual(2.0 * 3, parser.parse("(3)2")?.eval())
    XCTAssertNil(parser.parse("2(3, 4)"))
  }

  func testEvalUnknownVariable() {
    let token = parser.parse("4 * sin(t * pi)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
  }

  func testEvalWithVariable() {
    let token = parser.parse("4 * sin(t * pi)")!
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalSymbolMap() {
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer)
    }

    XCTAssertEqual(0.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalSymbolMapDoesNotOverrideMathParserSymbolMap() {
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0, "pi": 3.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer)
    }

    XCTAssertEqual(0.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalUnaryFunctionMapDoesNotOverrideMathParserUnaryFunctionMap() {
    let functions: [String: (Double)->Double] = ["sin": cos]
    let token = parser.parse("4 * sin(t * pi)")!
    var variables = ["t": 0.0]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer, unaryFunctions: functions.producer)
    }

    XCTAssertEqual(0.0, eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, eval(at: 1.0), accuracy: 1e-5)
  }

  func testCustomEvalBinaryFunctionMap() {
    let token = parser.parse("4 * sin(foobar(t, 0.25) * pi)")!
    var variables = ["t": 0.0]
    let functions: [String:(Double, Double)->Double] = ["foobar": {$0 + $1}]

    func eval(at t: Double) -> Double {
      variables["t"] = t
      return token.eval(variables: variables.producer, binaryFunctions: functions.producer)
    }

    XCTAssertEqual(4 * sin(0.25 * .pi), eval(at: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4 * sin(0.75 * .pi), eval(at: 0.5), accuracy: 1e-5)
    XCTAssertEqual(4 * sin(1.25 * .pi), eval(at: 1.0), accuracy: 1e-5)
  }

  func testVariablesWithImpliedMultiplication1() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let token = parser.parse("4sin(tπ)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    XCTAssertEqual(0.0, token.eval("t", value: 0.0), accuracy: 1e-5)
    XCTAssertEqual(4.0, token.eval("t", value: 0.5), accuracy: 1e-5)
    XCTAssertEqual(0.0, token.eval("t", value: 1.0), accuracy: 1e-5)
  }

  func testUnaryFunction() {
    let token = parser.parse("(foo(t * pi))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    XCTAssertEqual(3.0 * .pi, token.eval(variables: {_ in 1.0}, unaryFunctions: {_ in {$0 * 3.0}}), accuracy: 1e-5)
  }

  func testBinaryFunction() {
    let token = parser.parse("( foo(t * pi , 2 * pi  ))")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)
    // At this point pi has been resolved, leaving t and foo.
    XCTAssertEqual(((1.5 * .pi) + (2.0 * .pi)) * 3,
                   token.eval(variables: {_ in 1.5}, binaryFunctions: {_ in {($0 + $1) * 3.0}}),
                   accuracy: 1e-5)
  }

  func testArcTan() {
    struct State {
      var x: Double;
      var y: Double;

      func lookup(name: String) -> Double {
        switch name {
        case "x": return x
        case "y": return y
        default: return .nan
        }
      }
    }

    let epsilon = 1e-5
    let token = parser.parse("atan2(y, x)")!
    XCTAssertNotNil(token)
    XCTAssertTrue(token.eval().isNaN)

    var s = State(x: 0.0, y: 0.0)
    let evaluator: () -> Double = { token.eval(variables: s.lookup) }
    XCTAssertEqual(evaluator(), 0.0, accuracy: epsilon)
    s.x = -1.0
    XCTAssertEqual(evaluator(), .pi, accuracy: epsilon)
    s.x = 1.0
    XCTAssertEqual(evaluator(), 0.0, accuracy: epsilon)
    s.x = 0.0
    s.y = -0.5
    XCTAssertEqual(evaluator(), -.pi / 2, accuracy: epsilon)
    s.y = 0.5
    XCTAssertEqual(evaluator(), .pi / 2, accuracy: epsilon)
    s.y = .nan
    XCTAssertTrue(evaluator().isNaN)
    s.x = 0.5
    s.y = 0.5
    XCTAssertEqual(evaluator(), 0.7853981633974483, accuracy: epsilon)
  }

  func testReadMeExample1() {
    let parser = MathParser()
    let evaluator = parser.parse("4 × sin(t × π) + 2 × sin(t × π)")
    var t = 0.0
    var v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.25
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.5
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    v = evaluator!.eval("u", value: 1.0)
    XCTAssertTrue(v.isNaN)
  }

  func testReadMeExample2() {
    let myVariables = ["foo": 123.4]
    let myFuncs: [String:(Double)->Double] = ["twice": {$0 + $0}]
    let parser = MathParser(variables: myVariables.producer, unaryFunctions: myFuncs.producer)
    let myEvalFuncs: [String:(Double)->Double] = ["power": {$0 * $0}]
    let evaluator = parser.parse("power(twice(foo))")
    XCTAssertEqual(evaluator?.eval(unaryFunctions: myEvalFuncs.producer), pow(123.4 * 2, 2))
  }

  func testReadMeExample3() {
    let parser = MathParser(enableImpliedMultiplication: true)
    let evaluator = parser.parse("4sin(t π) + 2sin(t π)")
    var t = 0.0
    var v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.25
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    t = 0.5
    v = evaluator!.eval("t", value: t)
    XCTAssertEqual(4 * sin(t * .pi) + 2 * sin(t * .pi), v)
    v = evaluator!.eval("u", value: 1.0)
    XCTAssertTrue(v.isNaN)
  }

  func testWolframExample() {
    // The following equations come from https://www.wolframalpha.com/input?i=Sawsbuck+Winter+Form%E2%80%90like+curve
    // The two parametric functions there were copied verbatim here as xw and yw. The
    let x = "((-2/9 sin(11/7 - 4 t) + 78/11 sin(t + 11/7) + 2/7 sin(2 t + 8/5) + 5/16 sin(3 t + 11/7) + 641/20) θ(107 π - t) θ(t - 103 π) + (-1/40 sin(10/7 - 48 t) - 1/20 sin(32/21 - 47 t) - 1/75 sin(9/7 - 44 t) - 1/10 sin(35/23 - 41 t) - 1/8 sin(23/15 - 33 t) - 1/13 sin(38/25 - 30 t) - 2/11 sin(23/15 - 27 t) - 1/7 sin(14/9 - 23 t) - 3/14 sin(20/13 - 22 t) - 1/5 sin(17/11 - 19 t) - 1/9 sin(38/25 - 18 t) - 1/13 sin(14/9 - 13 t) - 9/8 sin(17/11 - 12 t) - 3/10 sin(11/7 - 11 t) - 5/7 sin(14/9 - 9 t) - 6/7 sin(17/11 - 6 t) - 5/7 sin(11/7 - 5 t) - 131/15 sin(11/7 - 3 t) + 166/11 sin(t + 11/7) + 82/13 sin(2 t + 11/7) + 5/4 sin(4 t + 11/7) + 7/15 sin(7 t + 33/7) + 23/22 sin(8 t + 11/7) + 7/5 sin(10 t + 19/12) + 1/2 sin(14 t + 8/5) + 1/11 sin(15 t + 47/10) + 3/8 sin(16 t + 8/5) + 1/9 sin(17 t + 33/7) + 2/9 sin(20 t + 8/5) + 1/34 sin(21 t + 28/17) + 2/7 sin(24 t + 8/5) + 1/9 sin(25 t + 13/8) + 1/19 sin(28 t + 8/5) + 1/30 sin(29 t + 75/16) + 1/9 sin(31 t + 18/11) + 1/7 sin(32 t + 21/13) + 1/17 sin(37 t + 47/10) + 1/16 sin(38 t + 13/8) + 1/13 sin(39 t + 23/14) + 1/20 sin(42 t + 13/8) + 1/86 sin(43 t + 23/5) + 1/26 sin(46 t + 21/13) + 451/15) θ(103 π - t) θ(t - 99 π) + (-1/49 sin(14/9 - 6 t) - 7/13 sin(11/7 - 5 t) - 3/11 sin(11/7 - 4 t) - 3/5 sin(11/7 - 3 t) - 1/2 sin(11/7 - 2 t) + 91/11 sin(t + 11/7) - 8/5) θ(99 π - t) θ(t - 95 π) + (-1/31 sin(31/21 - 26 t) - 1/30 sin(22/15 - 23 t) - 1/17 sin(32/21 - 20 t) - 1/57 sin(32/21 - 19 t) - 1/22 sin(26/17 - 17 t) - 1/19 sin(32/21 - 16 t) - 1/10 sin(20/13 - 11 t) - 1/5 sin(14/9 - 8 t) - 2/11 sin(17/11 - 7 t) - 7/9 sin(11/7 - 4 t) - 27/5 sin(11/7 - 2 t) - 50/9 sin(11/7 - t) + 22/21 sin(3 t + 11/7) + 1/9 sin(5 t + 11/7) + 3/4 sin(6 t + 8/5) + 10/21 sin(9 t + 19/12) + 1/6 sin(10 t + 8/5) + 1/20 sin(12 t + 13/8) + 1/23 sin(13 t + 8/5) + 1/20 sin(15 t + 13/8) + 1/21 sin(18 t + 13/8) + 1/21 sin(21 t + 13/8) + 1/95 sin(22 t + 61/13) + 1/24 sin(24 t + 28/17) + 1/26 sin(25 t + 13/8) + 1/72 sin(27 t + 18/11) + 1/51 sin(28 t + 18/11) + 1/78 sin(30 t + 5/3) - 309/8) θ(95 π - t) θ(t - 91 π) + (-1/52 sin(11/8 - 30 t) - 1/17 sin(3/2 - 27 t) - 1/11 sin(16/11 - 24 t) - 1/29 sin(10/7 - 23 t) - 1/64 sin(6/5 - 20 t) - 1/13 sin(37/25 - 15 t) - 1/13 sin(7/5 - 12 t) - 1/7 sin(23/15 - 11 t) - 2/3 sin(17/11 - 8 t) - 11/16 sin(38/25 - 4 t) - 5/9 sin(14/9 - 3 t) + 35/11 sin(t + 11/7) + 73/8 sin(2 t + 11/7) + 2/11 sin(5 t + 17/11) + 67/33 sin(6 t + 19/12) + 3/11 sin(7 t + 11/7) + 1/5 sin(9 t + 13/8) + 9/11 sin(10 t + 8/5) + 6/17 sin(13 t + 19/12) + 2/11 sin(14 t + 11/7) + 1/6 sin(16 t + 19/12) + 1/14 sin(17 t + 13/8) + 1/55 sin(18 t + 5/3) + 1/14 sin(19 t + 8/5) + 1/6 sin(22 t + 13/8) + 1/12 sin(25 t + 13/8) + 1/16 sin(26 t + 18/11) + 1/26 sin(28 t + 18/11) + 1/18 sin(29 t + 5/3) + 1/22 sin(32 t + 8/5) - 159/4) θ(91 π - t) θ(t - 87 π) + (-1/82 sin(16/13 - 36 t) - 1/37 sin(13/9 - 33 t) - 1/13 sin(14/9 - 26 t) - 1/10 sin(14/9 - 25 t) - 1/10 sin(20/13 - 21 t) - 1/8 sin(14/9 - 16 t) - 5/11 sin(11/7 - 15 t) - 1/11 sin(25/17 - 14 t) - 5/16 sin(11/7 - 13 t) - 7/11 sin(14/9 - 8 t) - 25/26 sin(11/7 - 5 t) - 9/17 sin(11/7 - 3 t) - 17/8 sin(11/7 - t) + 36/5 sin(2 t + 11/7) + 78/11 sin(4 t + 11/7) + 25/8 sin(6 t + 11/7) + 3/8 sin(7 t + 33/7) + 2/5 sin(9 t + 11/7) + 3/11 sin(10 t + 8/5) + 1/25 sin(11 t + 13/9) + 94/93 sin(12 t + 8/5) + 1/25 sin(17 t + 14/3) + 1/8 sin(18 t + 11/7) + 1/3 sin(19 t + 8/5) + 1/3 sin(20 t + 11/7) + 2/11 sin(22 t + 19/12) + 1/8 sin(23 t + 33/7) + 1/14 sin(24 t + 33/7) + 1/10 sin(28 t + 11/7) + 1/6 sin(30 t + 8/5) + 1/31 sin(31 t + 11/7) + 1/19 sin(32 t + 11/7) + 1/41 sin(34 t + 11/7) + 1/72 sin(35 t + 113/56) + 1/19 sin(37 t + 23/5) + 1/60 sin(38 t + 19/13) - 523/10) θ(87 π - t) θ(t - 83 π) + (-1/28 sin(23/15 - 36 t) - 1/28 sin(3/2 - 32 t) - 1/16 sin(17/11 - 28 t) - 1/23 sin(20/13 - 24 t) - 1/11 sin(14/9 - 20 t) - 1/43 sin(3/2 - 11 t) - 1/3 sin(14/9 - 10 t) - 11/9 sin(11/7 - 6 t) - 75/8 sin(11/7 - 2 t) + 2/7 sin(t + 8/5) + 2/11 sin(3 t + 37/8) + 1/6 sin(4 t + 68/15) + 1/9 sin(5 t + 12/7) + 1/31 sin(7 t + 41/9) + 1/15 sin(8 t + 23/5) + 1/13 sin(9 t + 19/12) + 1/9 sin(12 t + 14/3) + 1/31 sin(13 t + 18/11) + 1/7 sin(14 t + 47/10) + 1/88 sin(15 t + 65/14) + 1/15 sin(16 t + 14/3) + 1/40 sin(17 t + 32/19) + 1/23 sin(18 t + 14/3) + 1/64 sin(21 t + 8/5) + 1/55 sin(22 t + 23/5) - 677/16) θ(83 π - t) θ(t - 79 π) + (-3/7 sin(14/9 - 5 t) - 31/32 sin(11/7 - 3 t) - 13/27 sin(11/7 - 2 t) + 42/5 sin(t + 11/7) + 1/9 sin(4 t + 33/7) + 1/10 sin(6 t + 11/7) - 1479/14) θ(79 π - t) θ(t - 75 π) + (-1/29 sin(19/13 - 33 t) - 1/10 sin(11/8 - 32 t) - 1/11 sin(13/9 - 31 t) - 1/92 sin(29/19 - 28 t) - 1/10 sin(10/7 - 26 t) - 2/9 sin(25/17 - 25 t) - 1/49 sin(10/7 - 22 t) - 1/12 sin(31/21 - 21 t) - 3/10 sin(34/23 - 19 t) - 1/3 sin(28/19 - 18 t) - 1/6 sin(17/11 - 15 t) - 5/6 sin(32/21 - 12 t) - 3/7 sin(3/2 - 11 t) - 1/8 sin(10/7 - 10 t) - 5/7 sin(14/9 - 9 t) - 13/12 sin(23/15 - 4 t) - 109/12 sin(14/9 - 3 t) + 44/3 sin(t + 11/7) + 41/7 sin(2 t + 11/7) + 10/13 sin(5 t + 21/13) + 5/11 sin(6 t + 8/5) + 2/7 sin(7 t + 23/14) + 13/8 sin(8 t + 8/5) + 1/7 sin(13 t + 5/3) + 4/7 sin(14 t + 13/8) + 1/3 sin(16 t + 23/14) + 3/10 sin(17 t + 23/14) + 1/19 sin(20 t + 17/11) + 3/13 sin(23 t + 17/10) + 1/5 sin(24 t + 5/3) + 1/12 sin(27 t + 27/16) + 1/8 sin(30 t + 22/13) + 1/12 sin(34 t + 19/11) + 1/20 sin(35 t + 11/6) - 758/7) θ(75 π - t) θ(t - 71 π) + (-1/62 sin(17/12 - 29 t) - 1/25 sin(14/9 - 24 t) - 1/14 sin(17/11 - 20 t) - 1/8 sin(14/9 - 16 t) - 1/13 sin(13/9 - 15 t) - 3/7 sin(20/13 - 7 t) - 8/11 sin(11/7 - 6 t) - 27/5 sin(11/7 - 2 t) + 103/8 sin(t + 11/7) + 43/11 sin(3 t + 19/12) + 31/11 sin(4 t + 8/5) + 15/7 sin(5 t + 8/5) + 1/5 sin(8 t + 47/10) + 5/9 sin(9 t + 8/5) + 1/9 sin(10 t + 32/19) + 1/6 sin(11 t + 19/12) + 1/22 sin(12 t + 16/9) + 3/11 sin(13 t + 8/5) + 1/37 sin(14 t + 32/7) + 1/6 sin(17 t + 23/14) + 1/8 sin(18 t + 17/10) + 1/10 sin(19 t + 5/3) + 1/43 sin(21 t + 13/8) + 1/60 sin(22 t + 27/14) + 1/22 sin(23 t + 21/13) + 1/29 sin(25 t + 8/5) + 1/23 sin(26 t + 16/9) + 1/14 sin(27 t + 5/3) + 1/42 sin(28 t + 47/10) + 1/98 sin(30 t + 50/11) - 47) θ(71 π - t) θ(t - 67 π) + (-76/75 sin(14/9 - 16 t) - 8/9 sin(14/9 - 13 t) - 2/7 sin(17/11 - 12 t) - 22/13 sin(14/9 - 10 t) - 1/38 sin(3/2 - 9 t) - 119/8 sin(11/7 - 3 t) - 70/9 sin(11/7 - t) + 41/5 sin(2 t + 11/7) + 13/12 sin(4 t + 14/9) + 7/6 sin(5 t + 8/5) + 13/6 sin(6 t + 11/7) + 201/50 sin(7 t + 11/7) + 19/7 sin(8 t + 19/12) + 2/13 sin(11 t + 75/16) + 5/14 sin(14 t + 13/8) + 3/13 sin(15 t + 8/5) + 3/8 sin(17 t + 14/3) + 1/91 sin(18 t + 19/6) + 1/46 sin(19 t + 17/11) + 8/13 sin(20 t + 13/8) + 3/5 sin(21 t + 13/8) + 8/17 sin(22 t + 13/8) + 12/23 sin(23 t + 18/11) + 1/5 sin(24 t + 19/11) + 1/3 sin(25 t + 18/11) + 5/11 sin(26 t + 18/11) + 4/9 sin(27 t + 18/11) + 4/11 sin(28 t + 23/14) + 4/15 sin(29 t + 5/3) + 1/10 sin(30 t + 23/13) + 1/10 sin(31 t + 19/11) + 1/46 sin(32 t + 61/15) + 1/8 sin(33 t + 5/3) + 2/11 sin(34 t + 13/8) - 683/8) θ(67 π - t) θ(t - 63 π) + (56/9 sin(t + 11/7) + 2/9 sin(2 t + 11/7) + 5/7 sin(3 t + 11/7) - 75/4) θ(63 π - t) θ(t - 59 π) + (-1/16 sin(3/2 - 39 t) - 1/10 sin(25/24 - 38 t) - 1/10 sin(7/5 - 37 t) - 1/10 sin(18/17 - 30 t) - 1/7 sin(9/7 - 29 t) - 3/7 sin(14/11 - 24 t) - 4/7 sin(11/8 - 23 t) - 7/15 sin(17/12 - 19 t) - 1/7 sin(3/2 - 17 t) - 2/11 sin(11/9 - 16 t) - 4/7 sin(28/19 - 13 t) - 1/27 sin(2/3 - 12 t) - 5/7 sin(22/15 - 11 t) - 5/8 sin(14/9 - 8 t) - 3 sin(37/25 - 6 t) - 57/10 sin(26/17 - 5 t) - 47/7 sin(17/11 - 2 t) - 239/15 sin(14/9 - t) + 19/8 sin(3 t + 13/8) + 87/13 sin(4 t + 13/8) + 14/9 sin(7 t + 28/17) + 1/14 sin(9 t + 35/8) + 1/15 sin(10 t + 9/7) + 12/13 sin(14 t + 17/10) + 8/13 sin(15 t + 7/4) + 4/9 sin(18 t + 5/3) + 3/11 sin(20 t + 18/11) + 2/7 sin(21 t + 37/19) + 1/8 sin(22 t + 5/3) + 1/9 sin(25 t + 65/14) + 2/7 sin(26 t + 11/6) + 1/8 sin(27 t + 47/10) + 1/10 sin(28 t + 11/7) + 1/7 sin(31 t + 79/39) + 4/11 sin(32 t + 13/7) + 1/29 sin(34 t + 1/3) + 1/36 sin(35 t + 38/9) + 1/7 sin(36 t + 11/6) - 72/7) θ(59 π - t) θ(t - 55 π) + (-1/7 sin(34/23 - 28 t) - 1/8 sin(13/9 - 27 t) - 1/16 sin(29/19 - 20 t) - 3/14 sin(10/7 - 19 t) - 1/9 sin(31/21 - 18 t) - 1/4 sin(14/9 - 15 t) - 3/5 sin(17/11 - 11 t) - 1/6 sin(10/7 - 10 t) - 1/9 sin(19/13 - 9 t) - 22/15 sin(14/9 - 7 t) - 197/49 sin(14/9 - 2 t) - 103/6 sin(11/7 - t) + 251/28 sin(3 t + 19/12) + 18/7 sin(4 t + 13/8) + 35/6 sin(5 t + 19/12) + 12/23 sin(6 t + 11/7) + 1/5 sin(8 t + 8/5) + 2/5 sin(12 t + 18/11) + 12/13 sin(13 t + 13/8) + 2/9 sin(14 t + 22/13) + 3/11 sin(16 t + 14/9) + 1/10 sin(17 t + 47/10) + 2/9 sin(21 t + 22/13) + 2/13 sin(22 t + 17/10) + 1/13 sin(23 t + 13/8) + 1/48 sin(24 t + 32/7) + 1/43 sin(25 t + 11/6) + 1/27 sin(26 t + 3/2) + 1/8 sin(29 t + 18/11) + 1/14 sin(30 t + 20/11) + 328/11) θ(55 π - t) θ(t - 51 π) + (-1/19 sin(23/15 - 32 t) - 1/46 sin(20/13 - 30 t) - 1/23 sin(23/15 - 28 t) - 1/27 sin(22/15 - 27 t) - 1/23 sin(20/13 - 26 t) - 1/15 sin(14/9 - 24 t) - 1/8 sin(17/11 - 22 t) - 1/14 sin(20/13 - 20 t) - 1/12 sin(17/11 - 18 t) - 1/12 sin(3/2 - 17 t) - 1/5 sin(17/11 - 16 t) - 1/38 sin(13/9 - 15 t) - 1/6 sin(14/9 - 14 t) - 4/11 sin(14/9 - 12 t) - 10/21 sin(14/9 - 10 t) - 2/11 sin(14/9 - 8 t) - 6/11 sin(14/9 - 7 t) - 2/3 sin(14/9 - 6 t) - 2/3 sin(11/7 - 5 t) - 20/13 sin(11/7 - 4 t) - 1/3 sin(14/9 - 3 t) - 59/7 sin(11/7 - 2 t) - 34/7 sin(11/7 - t) + 1/22 sin(9 t + 23/15) + 1/31 sin(11 t + 10/7) + 1/7 sin(13 t + 11/7) + 1/19 sin(19 t + 14/9) + 1/80 sin(21 t + 19/14) + 1/44 sin(23 t + 16/11) + 1/82 sin(25 t + 17/12) + 1/46 sin(31 t + 20/13) + 486/11) θ(51 π - t) θ(t - 47 π) + (-1/22 sin(15/11 - 35 t) - 3/10 sin(24/23 - 32 t) - 1/19 sin(1/8 - 31 t) - 1/5 sin(9/10 - 26 t) - 2/7 sin(31/32 - 25 t) - 1/6 sin(18/13 - 19 t) - 1/5 sin(2/3 - 18 t) - 6/13 sin(13/11 - 17 t) - 5/14 sin(13/11 - 13 t) - 9/5 sin(4/3 - 12 t) - 3/4 sin(17/13 - 8 t) - 3/13 sin(13/10 - 7 t) - 175/6 sin(14/9 - t) + 239/9 sin(2 t + 8/5) + 142/15 sin(3 t + 5/3) + 181/36 sin(4 t + 5/3) + 23/7 sin(5 t + 18/11) + 2/5 sin(6 t + 19/11) + 10/11 sin(9 t + 26/15) + 19/9 sin(10 t + 13/7) + 16/9 sin(11 t + 19/11) + 5/3 sin(14 t + 13/7) + 9/7 sin(15 t + 25/13) + 6/17 sin(16 t + 11/6) + 4/11 sin(20 t + 23/12) + 2/9 sin(21 t + 16/9) + 1/5 sin(22 t + 41/9) + 9/14 sin(23 t + 39/20) + 2/9 sin(24 t + 75/38) + 2/11 sin(27 t + 63/32) + 2/7 sin(28 t + 9/4) + 2/9 sin(29 t + 37/16) + 1/4 sin(30 t + 17/8) + 1/8 sin(33 t + 13/8) + 1/6 sin(36 t + 30/13) + 1/7 sin(37 t + 26/11) - 55/6) θ(47 π - t) θ(t - 43 π) + (-1/42 sin(3/2 - 26 t) - 1/25 sin(21/16 - 25 t) - 1/12 sin(16/11 - 24 t) - 1/9 sin(16/11 - 20 t) - 1/51 sin(6/5 - 19 t) - 2/9 sin(3/2 - 16 t) - 1/17 sin(15/11 - 15 t) - 1/7 sin(26/17 - 14 t) - 2/7 sin(20/13 - 12 t) - 1/8 sin(10/7 - 11 t) - 3/10 sin(17/11 - 10 t) - 2/5 sin(14/9 - 8 t) - 6/13 sin(3/2 - 7 t) - 7/6 sin(20/13 - 6 t) - 1/14 sin(9/7 - 5 t) - 2/7 sin(20/13 - 4 t) - 19/7 sin(17/11 - 3 t) - 101/9 sin(14/9 - 2 t) + 96/13 sin(t + 11/7) + 2/5 sin(9 t + 11/7) + 2/13 sin(13 t + 11/7) + 1/19 sin(17 t + 7/5) + 1/35 sin(18 t + 23/5) + 1/81 sin(27 t + 13/9) + 652/15) θ(43 π - t) θ(t - 39 π) + (-1/34 sin(7/5 - 33 t) - 1/17 sin(3/2 - 25 t) - 1/33 sin(11/7 - 23 t) - 2/9 sin(3/2 - 9 t) - 1/11 sin(7/5 - 8 t) - 21/10 sin(11/7 - t) + 11/6 sin(2 t + 11/7) + 16/7 sin(3 t + 13/8) + 37/8 sin(4 t + 8/5) + 23/22 sin(5 t + 33/7) + 7/6 sin(6 t + 8/5) + 1/8 sin(7 t + 7/4) + 2/9 sin(10 t + 23/14) + 2/7 sin(11 t + 5/3) + 1/12 sin(12 t + 18/11) + 1/18 sin(13 t + 13/7) + 3/8 sin(14 t + 23/14) + 1/8 sin(15 t + 47/10) + 1/17 sin(16 t + 34/23) + 1/36 sin(17 t + 41/9) + 1/26 sin(18 t + 19/12) + 1/34 sin(19 t + 51/11) + 1/17 sin(20 t + 17/10) + 1/8 sin(21 t + 23/13) + 1/18 sin(22 t + 19/11) + 1/14 sin(24 t + 13/8) + 1/57 sin(26 t + 15/11) + 1/25 sin(28 t + 23/13) + 1/50 sin(29 t + 2) + 1/28 sin(30 t + 9/5) + 1/29 sin(31 t + 15/8) + 1/71 sin(32 t + 18/11) + 1/43 sin(34 t + 19/12) - 64/21) θ(39 π - t) θ(t - 35 π) + (-67/34 sin(11/7 - 3 t) + 173/14 sin(t + 19/12) + 25/4 sin(2 t + 19/12) + 28/13 sin(4 t + 19/12) + 1/8 sin(5 t + 55/12) + 1/17 sin(6 t + 14/9) + 4/11 sin(7 t + 21/13) + 1/8 sin(8 t + 8/5) + 1/9 sin(9 t + 47/10) + 2/7 sin(10 t + 8/5) + 1/10 sin(11 t + 33/7) + 1/11 sin(12 t + 13/8) + 1/10 sin(13 t + 12/7) + 1/61 sin(14 t + 23/15) + 1/8 sin(16 t + 5/3) + 1/20 sin(17 t + 61/13) + 1/14 sin(18 t + 13/8) + 1/34 sin(19 t + 13/7) + 1/82 sin(20 t + 12/7) + 1/38 sin(21 t + 20/11) + 1/16 sin(22 t + 17/10) + 1/36 sin(23 t + 33/7) + 1/19 sin(24 t + 5/3) + 1/87 sin(25 t + 87/44) + 67/11) θ(35 π - t) θ(t - 31 π) + (-1/15 sin(14/9 - 10 t) - 1/16 sin(14/9 - 7 t) - 1/24 sin(17/11 - 4 t) - 7/3 sin(11/7 - t) + 1/3 sin(2 t + 33/7) + 10/9 sin(3 t + 11/7) + 1/7 sin(5 t + 11/7) + 1/12 sin(6 t + 33/7) + 1/19 sin(8 t + 47/10) + 1/51 sin(9 t + 75/16) + 1/22 sin(12 t + 47/10) + 1/32 sin(15 t + 11/7) + 224/13) θ(31 π - t) θ(t - 27 π) + (-1/13 sin(4/3 - 37 t) - 1/25 sin(16/13 - 36 t) - 1/9 sin(18/13 - 34 t) - 1/85 sin(8/15 - 33 t) - 1/52 sin(7/5 - 32 t) - 1/29 sin(10/7 - 28 t) - 1/8 sin(16/11 - 26 t) - 1/36 sin(3/4 - 25 t) - 1/6 sin(7/5 - 24 t) - 2/11 sin(7/5 - 23 t) - 1/7 sin(20/13 - 20 t) - 1/13 sin(13/9 - 15 t) - 1/5 sin(16/11 - 14 t) - 2/9 sin(7/5 - 13 t) - 5/8 sin(34/23 - 12 t) - 1/18 sin(5/11 - 11 t) - 40/27 sin(26/17 - 10 t) - 2/11 sin(7/5 - 9 t) - 42/11 sin(11/7 - 4 t) - 17/5 sin(11/7 - 2 t) + 71/8 sin(t + 11/7) + 1/4 sin(3 t + 8/5) + 36/7 sin(5 t + 8/5) + 5/6 sin(6 t + 23/14) + 3/13 sin(7 t + 61/13) + 23/22 sin(8 t + 8/5) + 1/6 sin(16 t + 17/10) + 3/11 sin(17 t + 27/16) + 1/46 sin(18 t + 191/48) + 1/5 sin(19 t + 18/11) + 1/46 sin(21 t + 9/7) + 1/30 sin(22 t + 13/9) + 1/12 sin(27 t + 19/12) + 1/18 sin(30 t + 16/9) + 1/69 sin(31 t + 14/9) + 1/66 sin(35 t + 7/8) + 181/10) θ(27 π - t) θ(t - 23 π) + (-1/33 sin(17/11 - 29 t) - 1/91 sin(3/2 - 25 t) - 1/18 sin(17/11 - 19 t) + 210/19 sin(t + 33/7) + 11/4 sin(2 t + 11/7) + 24/7 sin(3 t + 33/7) + 19/10 sin(4 t + 11/7) + 43/17 sin(5 t + 47/10) + 18/13 sin(6 t + 61/13) + 5/13 sin(7 t + 33/7) + 19/18 sin(8 t + 14/9) + 4/9 sin(9 t + 3/2) + 11/12 sin(10 t + 17/11) + 2/7 sin(11 t + 23/15) + 2/11 sin(12 t + 51/11) + 5/14 sin(13 t + 47/10) + 3/7 sin(14 t + 14/9) + 2/7 sin(15 t + 3/2) + 1/5 sin(16 t + 35/23) + 1/9 sin(17 t + 22/15) + 2/9 sin(18 t + 23/15) + 1/40 sin(20 t + 34/23) + 1/19 sin(21 t + 23/15) + 1/12 sin(22 t + 3/2) + 1/9 sin(24 t + 29/19) + 1/11 sin(27 t + 19/13) + 1/7 sin(28 t + 3/2) + 1/36 sin(30 t + 9/2) + 1/29 sin(31 t + 37/8) + 1/61 sin(32 t + 11/7) + 1/41 sin(33 t + 21/16) + 1/14 sin(34 t + 22/15) + 1/27 sin(35 t + 18/13) + 1/48 sin(36 t + 3/2) - 3/5) θ(23 π - t) θ(t - 19 π) + (-1/9 sin(7/5 - 41 t) - 1/11 sin(7/5 - 39 t) - 1/8 sin(4/3 - 38 t) - 1/45 sin(5/4 - 36 t) - 1/16 sin(7/5 - 34 t) - 1/7 sin(18/13 - 33 t) - 1/8 sin(13/9 - 31 t) - 1/6 sin(16/11 - 29 t) - 3/11 sin(7/5 - 28 t) - 1/3 sin(3/2 - 25 t) - 1/11 sin(5/4 - 24 t) - 5/13 sin(25/17 - 23 t) - 1/78 sin(2/5 - 22 t) - 2/7 sin(3/2 - 21 t) - 3/11 sin(16/11 - 19 t) - 3/7 sin(34/23 - 18 t) - 1/3 sin(3/2 - 16 t) - 1/33 sin(32/33 - 14 t) - 5/6 sin(20/13 - 13 t) - 22/7 sin(17/11 - 9 t) - 9/7 sin(11/7 - 7 t) - 1/10 sin(13/10 - 6 t) + 274/25 sin(t + 11/7) + 46/7 sin(2 t + 11/7) + 1/9 sin(3 t + 22/13) + 17/10 sin(4 t + 11/7) + 7/5 sin(5 t + 21/13) + 7/3 sin(8 t + 19/12) + 2/3 sin(10 t + 14/9) + 2/7 sin(11 t + 14/3) + 4/11 sin(12 t + 17/11) + 1/9 sin(15 t + 8/5) + 2/13 sin(17 t + 21/13) + 1/66 sin(26 t + 3/10) + 1/26 sin(27 t + 51/11) + 1/9 sin(30 t + 13/8) + 1/28 sin(32 t + 7/4) + 1/79 sin(37 t + 37/16) + 1/30 sin(40 t + 18/11) + 1/16 sin(42 t + 12/7) - 13/2) θ(19 π - t) θ(t - 15 π) + (-1/45 sin(11/7 - 31 t) - 1/14 sin(11/7 - 9 t) - 69/14 sin(11/7 - t) + 53/9 sin(2 t + 11/7) + 10/13 sin(3 t + 14/9) + 10/11 sin(4 t + 11/7) + 5/4 sin(5 t + 14/9) + 7/8 sin(6 t + 14/9) + 3/8 sin(7 t + 33/7) + 7/12 sin(8 t + 33/7) + 8/15 sin(10 t + 14/9) + 4/13 sin(11 t + 17/11) + 1/11 sin(12 t + 14/9) + 1/7 sin(13 t + 33/7) + 1/6 sin(14 t + 14/9) + 1/23 sin(15 t + 32/21) + 1/46 sin(16 t + 19/12) + 1/16 sin(19 t + 20/13) + 1/18 sin(20 t + 3/2) + 1/34 sin(21 t + 3/2) + 1/18 sin(22 t + 17/11) + 1/91 sin(23 t + 11/8) + 1/62 sin(24 t + 13/8) + 1/19 sin(25 t + 61/13) + 1/47 sin(26 t + 14/3) + 1/27 sin(27 t + 14/9) + 1/14 sin(28 t + 3/2) + 1/35 sin(29 t + 22/15) - 22/7) θ(15 π - t) θ(t - 11 π) + (-1/41 sin(9/7 - 53 t) - 1/21 sin(6/5 - 51 t) - 1/23 sin(7/6 - 50 t) - 1/6 sin(14/11 - 46 t) - 1/68 sin(7/8 - 44 t) - 1/11 sin(9/7 - 43 t) - 1/31 sin(4/11 - 42 t) - 1/8 sin(16/11 - 41 t) - 1/23 sin(6/7 - 37 t) - 6/13 sin(13/10 - 36 t) - 1/8 sin(9/11 - 35 t) - 3/13 sin(7/5 - 34 t) - 1/6 sin(10/7 - 29 t) - 4/11 sin(6/5 - 28 t) - 9/13 sin(4/3 - 27 t) - 1/3 sin(9/7 - 26 t) - 1/10 sin(17/16 - 25 t) - 1/12 sin(9/19 - 21 t) - 5/7 sin(10/7 - 20 t) - 4/11 sin(17/12 - 18 t) - sin(18/13 - 17 t) - 5/11 sin(11/8 - 16 t) - 6/13 sin(17/12 - 14 t) - 9/8 sin(10/7 - 13 t) - 7/9 sin(34/23 - 12 t) - 22/9 sin(3/2 - 8 t) - 59/29 sin(3/2 - 7 t) - 8/3 sin(38/25 - 6 t) - 20/7 sin(3/2 - 5 t) - 5/3 sin(23/15 - 4 t) - 43/7 sin(20/13 - 3 t) - 178/11 sin(14/9 - 2 t) + 157/15 sin(t + 11/7) + 9/7 sin(9 t + 23/14) + 39/20 sin(10 t + 5/3) + 9/13 sin(11 t + 5/3) + 8/13 sin(15 t + 5/3) + 1/9 sin(19 t + 8/7) + 4/13 sin(22 t + 61/13) + 7/10 sin(23 t + 12/7) + 1/15 sin(24 t + 47/11) + 5/14 sin(30 t + 9/5) + 3/10 sin(31 t + 15/8) + 1/27 sin(32 t + 38/9) + 1/13 sin(33 t + 5/4) + 1/8 sin(38 t + 19/10) + 1/14 sin(39 t + 9/4) + 1/5 sin(40 t + 20/11) + 1/52 sin(45 t + 21/20) + 1/27 sin(47 t + 11/8) + 1/21 sin(48 t + 23/10) + 1/31 sin(49 t + 17/10) + 1/28 sin(52 t + 7/4) + 483/10) θ(11 π - t) θ(t - 7 π) + (31/9 sin(t + 19/14) + 4/11 sin(2 t + 109/27) + 3/7 sin(3 t + 21/20) + 2/13 sin(4 t + 26/7) - 704/15) θ(7 π - t) θ(t - 3 π) + (71/9 sin(t + 6/5) + 1/3 sin(2 t + 19/6) + 3/4 sin(3 t + 9/8) + 1/13 sin(4 t + 2) + 4/11 sin(5 t + 5/7) + 1/10 sin(6 t + 24/7) + 2/9 sin(7 t + 9/13) + 1/12 sin(8 t + 24/7) + 1/6 sin(9 t + 4/9) + 1/13 sin(10 t + 19/6) + 1/7 sin(11 t + 4/11) + 1/15 sin(12 t + 32/9) + 1/10 sin(13 t + 2/5) + 1/15 sin(14 t + 59/17) + 1/12 sin(15 t + 4/11) + 1/16 sin(16 t + 46/13) + 1/16 sin(17 t + 8/15) + 1/19 sin(18 t + 24/7) + 1/17 sin(19 t + 5/9) + 1/28 sin(20 t + 73/21) + 1/21 sin(21 t + 3/5) + 1/27 sin(22 t + 59/17) + 296/7) θ(3 π - t) θ(t + π)) θ(sqrt(sgn(sin(t/2))))"

    let y = "((-32/11 sin(11/7 - t) + 23/9 sin(2 t + 11/7) + 5/12 sin(3 t + 19/12) + 7/10 sin(4 t + 11/7) - 624/5) θ(107 π - t) θ(t - 103 π) + (-1/6 sin(32/21 - 37 t) - 1/13 sin(14/9 - 31 t) - 1/13 sin(32/21 - 30 t) - 1/10 sin(11/7 - 29 t) - 6/17 sin(14/9 - 23 t) - 1/12 sin(3/2 - 22 t) - 1/10 sin(14/9 - 19 t) - 2/5 sin(14/9 - 16 t) - 17/12 sin(11/7 - 7 t) + 72/7 sin(t + 33/7) + 194/11 sin(2 t + 11/7) + 1/15 sin(3 t + 27/10) + 311/39 sin(4 t + 11/7) + 16/5 sin(5 t + 8/5) + 7/10 sin(6 t + 8/5) + 2/11 sin(8 t + 5/3) + 2/3 sin(9 t + 8/5) + 40/41 sin(10 t + 8/5) + 1/12 sin(11 t + 9/5) + 1/5 sin(12 t + 47/10) + 4/11 sin(13 t + 18/11) + 6/5 sin(14 t + 8/5) + 1/4 sin(15 t + 61/13) + 1/5 sin(17 t + 13/8) + 1/39 sin(18 t + 19/11) + 7/12 sin(20 t + 21/13) + 2/5 sin(21 t + 13/8) + 1/36 sin(24 t + 23/5) + 1/14 sin(25 t + 12/7) + 1/7 sin(26 t + 22/13) + 2/9 sin(27 t + 28/17) + 1/5 sin(28 t + 13/8) + 1/13 sin(32 t + 13/8) + 1/14 sin(33 t + 22/13) + 1/9 sin(34 t + 5/3) + 1/8 sin(35 t + 5/3) + 1/26 sin(38 t + 13/8) + 1/8 sin(39 t + 5/3) + 1/16 sin(40 t + 5/3) + 1/27 sin(41 t + 65/14) + 1/70 sin(42 t + 9/2) + 1/41 sin(43 t + 12/7) + 1/31 sin(44 t + 23/13) + 1/32 sin(45 t + 15/8) + 1/20 sin(46 t + 12/7) + 1/40 sin(47 t + 65/14) - 743/7) θ(103 π - t) θ(t - 99 π) + (-4/5 sin(11/7 - t) + 31/12 sin(2 t + 11/7) + 2/7 sin(3 t + 19/12) + 8/7 sin(4 t + 11/7) + 1/29 sin(5 t + 37/8) + 5/13 sin(6 t + 11/7) - 1625/12) θ(99 π - t) θ(t - 95 π) + (-1/29 sin(3/2 - 29 t) - 1/35 sin(11/7 - 19 t) - 1/9 sin(14/9 - 13 t) - 16/33 sin(11/7 - 5 t) - 106/35 sin(11/7 - t) + 33/16 sin(2 t + 11/7) + 1/3 sin(3 t + 11/7) + 23/12 sin(4 t + 11/7) + 1/5 sin(6 t + 14/9) + 4/9 sin(7 t + 8/5) + 7/11 sin(8 t + 11/7) + 1/10 sin(9 t + 47/10) + 1/9 sin(10 t + 14/9) + 1/7 sin(11 t + 21/13) + 1/6 sin(12 t + 11/7) + 1/22 sin(14 t + 11/7) + 1/58 sin(15 t + 33/7) + 1/14 sin(16 t + 8/5) + 1/64 sin(17 t + 17/10) + 1/17 sin(18 t + 21/13) + 1/67 sin(21 t + 14/3) + 1/16 sin(22 t + 8/5) + 1/24 sin(23 t + 5/3) + 1/26 sin(24 t + 8/5) + 1/28 sin(26 t + 8/5) + 1/45 sin(27 t + 18/11) + 1/90 sin(28 t + 20/13) + 1/51 sin(30 t + 8/5) - 893/7) θ(95 π - t) θ(t - 91 π) + (-1/20 sin(17/11 - 33 t) - 1/9 sin(37/25 - 29 t) - 1/37 sin(19/14 - 28 t) - 1/8 sin(20/13 - 25 t) - 1/11 sin(11/8 - 18 t) - 1/5 sin(3/2 - 17 t) - 8/15 sin(14/9 - 13 t) - 1/32 sin(10/9 - 10 t) - 8/11 sin(20/13 - 9 t) - 3/4 sin(11/7 - 7 t) - 38/5 sin(11/7 - 3 t) - 43/2 sin(11/7 - t) + 1/30 sin(2 t + 5/7) + 1/14 sin(4 t + 16/9) + 1/23 sin(5 t + 15/4) + 1/8 sin(6 t + 7/4) + 1/5 sin(8 t + 38/25) + 1/5 sin(11 t + 13/8) + 2/13 sin(12 t + 18/11) + 1/23 sin(14 t + 14/3) + 1/8 sin(15 t + 12/7) + 1/6 sin(16 t + 8/5) + 1/13 sin(19 t + 47/10) + 1/9 sin(20 t + 13/8) + 1/11 sin(21 t + 47/10) + 1/21 sin(22 t + 89/19) + 1/40 sin(23 t + 85/19) + 1/70 sin(24 t + 17/10) + 1/28 sin(26 t + 11/7) + 1/38 sin(27 t + 5/3) + 1/36 sin(30 t + 5/3) - 271/3) θ(91 π - t) θ(t - 87 π) + (-1/33 sin(3/2 - 37 t) - 1/9 sin(14/9 - 26 t) - 1/7 sin(14/9 - 25 t) - 2/11 sin(17/11 - 24 t) - 2/9 sin(11/7 - 16 t) - 79/2 sin(11/7 - t) + 8/5 sin(2 t + 11/7) + 37/6 sin(3 t + 11/7) + 9/13 sin(4 t + 11/7) + 35/13 sin(5 t + 11/7) + 3/10 sin(6 t + 19/12) + 1/3 sin(7 t + 20/13) + 3/4 sin(8 t + 11/7) + 1/7 sin(9 t + 13/8) + 3/4 sin(10 t + 11/7) + 5/13 sin(11 t + 19/12) + 3/14 sin(12 t + 11/7) + 4/13 sin(13 t + 19/12) + 1/4 sin(14 t + 47/10) + 1/27 sin(15 t + 31/21) + 1/32 sin(17 t + 14/3) + 1/5 sin(18 t + 11/7) + 2/9 sin(19 t + 8/5) + 2/5 sin(20 t + 11/7) + 5/14 sin(21 t + 11/7) + 1/10 sin(22 t + 18/11) + 1/16 sin(23 t + 18/11) + 1/14 sin(27 t + 47/10) + 1/8 sin(28 t + 8/5) + 1/11 sin(29 t + 19/12) + 1/8 sin(30 t + 19/12) + 1/8 sin(31 t + 11/7) + 1/54 sin(32 t + 23/15) + 1/20 sin(33 t + 13/8) + 1/23 sin(35 t + 47/10) + 1/69 sin(36 t + 19/11) + 1/39 sin(38 t + 7/4) - 1009/11) θ(87 π - t) θ(t - 83 π) + (-1/67 sin(3/2 - 35 t) - 1/48 sin(29/19 - 32 t) - 1/79 sin(35/23 - 31 t) - 1/38 sin(11/7 - 30 t) - 1/43 sin(17/11 - 28 t) - 1/10 sin(17/11 - 22 t) - 1/50 sin(14/9 - 21 t) - 1/19 sin(14/9 - 20 t) - 1/13 sin(14/9 - 17 t) - 1/6 sin(14/9 - 14 t) - 1/7 sin(14/9 - 13 t) - 1/6 sin(14/9 - 12 t) - 2/7 sin(14/9 - 9 t) - 6/11 sin(11/7 - 5 t) - 12/5 sin(11/7 - 4 t) - 62/21 sin(11/7 - t) + 12/13 sin(2 t + 19/12) + 9/10 sin(3 t + 19/12) + 4/11 sin(6 t + 33/7) + 3/11 sin(7 t + 8/5) + 2/5 sin(8 t + 8/5) + 1/11 sin(10 t + 8/5) + 1/8 sin(11 t + 8/5) + 1/13 sin(15 t + 18/11) + 1/12 sin(16 t + 18/11) + 1/29 sin(18 t + 18/11) + 1/46 sin(19 t + 18/11) + 1/68 sin(24 t + 7/4) + 1/84 sin(27 t + 47/10) + 1/44 sin(34 t + 22/13) - 387/11) θ(83 π - t) θ(t - 79 π) + (1/7 sin(t + 19/12) + 32/9 sin(2 t + 11/7) + 2/13 sin(3 t + 8/5) + 5/4 sin(4 t + 11/7) + 1/12 sin(5 t + 14/3) + 2/7 sin(6 t + 11/7) - 3169/24) θ(79 π - t) θ(t - 75 π) + (-1/23 sin(29/19 - 35 t) - 1/11 sin(20/13 - 29 t) - 7/20 sin(16/11 - 22 t) - 3/11 sin(38/25 - 21 t) - 1/16 sin(13/9 - 16 t) - 1/3 sin(17/11 - 11 t) - 11/12 sin(11/7 - 7 t) + 53/10 sin(t + 33/7) + 215/11 sin(2 t + 11/7) + 3/4 sin(3 t + 65/14) + 43/7 sin(4 t + 19/12) + 29/14 sin(5 t + 13/8) + 11/10 sin(6 t + 19/12) + 6/11 sin(8 t + 8/5) + 2/3 sin(9 t + 18/11) + 14/15 sin(10 t + 21/13) + 1/18 sin(12 t + 3/2) + 2/11 sin(13 t + 12/7) + 9/13 sin(14 t + 13/8) + 2/13 sin(15 t + 75/16) + 1/7 sin(17 t + 17/10) + 5/16 sin(18 t + 5/3) + 1/13 sin(19 t + 65/33) + 3/8 sin(20 t + 5/3) + 1/6 sin(23 t + 7/4) + 10/21 sin(24 t + 27/16) + 1/63 sin(25 t + 10/3) + 1/40 sin(26 t + 14/9) + 1/92 sin(27 t + 9/5) + 1/8 sin(30 t + 12/7) + 1/10 sin(31 t + 20/11) + 1/28 sin(32 t + 16/9) + 1/99 sin(33 t + 15/4) + 1/15 sin(34 t + 5/3) + 1/33 sin(36 t + 12/7) - 338/3) θ(75 π - t) θ(t - 71 π) + (-1/24 sin(20/13 - 18 t) - 1/39 sin(19/13 - 17 t) - 1/7 sin(14/9 - 3 t) - 3/2 sin(11/7 - 2 t) - 75/37 sin(11/7 - t) + 6/17 sin(4 t + 8/5) + 4/5 sin(5 t + 8/5) + 4/9 sin(6 t + 8/5) + 2/11 sin(7 t + 13/8) + 1/5 sin(8 t + 13/8) + 1/60 sin(9 t + 12/7) + 1/40 sin(10 t + 14/3) + 1/16 sin(11 t + 13/8) + 1/18 sin(12 t + 32/19) + 1/8 sin(13 t + 13/8) + 1/51 sin(14 t + 16/9) + 1/11 sin(15 t + 13/8) + 1/49 sin(16 t + 61/13) + 1/15 sin(19 t + 28/17) + 1/15 sin(20 t + 17/10) + 1/18 sin(21 t + 27/16) + 1/93 sin(23 t + 47/10) + 1/44 sin(24 t + 12/7) + 1/41 sin(27 t + 19/11) + 1/30 sin(28 t + 17/10) - 84/11) θ(71 π - t) θ(t - 67 π) + (-1/65 sin(14/9 - 33 t) - 1/19 sin(14/9 - 29 t) - 1/7 sin(38/25 - 23 t) - 1/21 sin(11/8 - 21 t) - 1/20 sin(13/9 - 20 t) - 3/11 sin(3/2 - 18 t) - 5/8 sin(17/11 - 17 t) - 8/9 sin(17/11 - 15 t) - 4/11 sin(37/25 - 12 t) - 5/7 sin(14/9 - 11 t) - 19/10 sin(14/9 - 9 t) - 41/27 sin(14/9 - 5 t) - 417/19 sin(11/7 - 3 t) + 377/14 sin(t + 11/7) + 67/9 sin(2 t + 11/7) + 5/11 sin(4 t + 19/12) + 4/9 sin(6 t + 3/2) + 5/11 sin(7 t + 13/8) + 8/5 sin(8 t + 11/7) + 11/8 sin(10 t + 19/12) + 4/9 sin(13 t + 8/5) + 1/60 sin(14 t + 20/19) + 5/12 sin(16 t + 21/13) + 1/82 sin(19 t + 19/8) + 2/7 sin(22 t + 23/14) + 3/11 sin(24 t + 8/5) + 1/11 sin(25 t + 16/9) + 1/7 sin(26 t + 13/8) + 1/7 sin(27 t + 8/5) + 1/4 sin(28 t + 5/3) + 1/9 sin(30 t + 18/11) + 1/29 sin(31 t + 31/7) + 1/13 sin(34 t + 5/3) - 353/8) θ(67 π - t) θ(t - 63 π) + (-68/23 sin(11/7 - t) + 1/2 sin(2 t + 11/7) + 3/11 sin(3 t + 33/7) - 503/6) θ(63 π - t) θ(t - 59 π) + (-1/5 sin(9/7 - 39 t) - 1/3 sin(7/5 - 33 t) - 5/16 sin(22/15 - 29 t) - 1/9 sin(4/11 - 28 t) - 2/7 sin(26/17 - 27 t) - 1/3 sin(10/7 - 23 t) - 1/21 sin(14/13 - 19 t) - 1/11 sin(9/7 - 18 t) - 1/9 sin(1/6 - 11 t) - 3/10 sin(22/15 - 10 t) - 81/7 sin(14/9 - t) + 520/11 sin(2 t + 19/12) + 11/2 sin(3 t + 8/5) + 36/7 sin(4 t + 19/12) + 7/5 sin(5 t + 21/13) + 2/9 sin(6 t + 14/9) + 1/17 sin(7 t + 41/9) + 7/6 sin(8 t + 22/13) + 29/9 sin(9 t + 5/3) + 1/13 sin(12 t + 33/8) + 20/13 sin(13 t + 5/3) + 1/7 sin(14 t + 30/7) + 5/8 sin(15 t + 8/5) + 1/10 sin(16 t + 56/13) + 7/11 sin(17 t + 17/10) + 3/11 sin(20 t + 16/9) + 5/13 sin(21 t + 25/13) + 3/13 sin(22 t + 26/15) + 1/11 sin(24 t + 3/7) + 1/12 sin(25 t + 37/12) + 5/6 sin(26 t + 25/14) + 9/13 sin(30 t + 11/6) + 1/13 sin(31 t + 29/9) + 1/7 sin(32 t + 9/7) + 2/5 sin(34 t + 23/13) + 1/6 sin(35 t + 14/3) + 1/9 sin(36 t + 11/7) + 1/13 sin(37 t + 20/7) + 3/11 sin(38 t + 20/11) - 614/7) θ(59 π - t) θ(t - 55 π) + (-1/10 sin(3/2 - 27 t) - 3/14 sin(23/15 - 19 t) - 1/4 sin(26/17 - 11 t) + 20/9 sin(t + 8/5) + 209/12 sin(2 t + 11/7) + 83/14 sin(3 t + 33/7) + 29/7 sin(4 t + 19/12) + 22/7 sin(5 t + 11/7) + 4/9 sin(6 t + 27/16) + 30/31 sin(7 t + 61/13) + 57/23 sin(8 t + 11/7) + 1/8 sin(9 t + 20/11) + 2/11 sin(10 t + 37/8) + 7/10 sin(12 t + 11/7) + 2/9 sin(13 t + 65/14) + 3/8 sin(14 t + 18/11) + 3/11 sin(15 t + 13/8) + 1/3 sin(16 t + 18/11) + 1/17 sin(17 t + 40/9) + 1/4 sin(18 t + 19/12) + 1/90 sin(20 t + 13/8) + 1/8 sin(21 t + 28/17) + 1/5 sin(22 t + 28/17) + 1/39 sin(23 t + 5/2) + 2/9 sin(24 t + 5/3) + 1/9 sin(25 t + 17/10) + 1/49 sin(26 t + 37/8) + 1/13 sin(28 t + 23/15) + 1/35 sin(29 t + 67/15) + 1/18 sin(30 t + 23/13) - 457/8) θ(55 π - t) θ(t - 51 π) + (-1/42 sin(13/9 - 32 t) - 1/11 sin(3/2 - 31 t) - 1/7 sin(20/13 - 26 t) - 1/25 sin(20/13 - 24 t) - 1/12 sin(26/17 - 21 t) - 1/9 sin(26/17 - 20 t) - 1/14 sin(14/9 - 19 t) - 1/5 sin(20/13 - 15 t) - 1/33 sin(14/9 - 14 t) - 6/13 sin(14/9 - 11 t) - 11/10 sin(14/9 - 9 t) - 28/9 sin(11/7 - 4 t) - 29/12 sin(11/7 - 2 t) - 625/26 sin(11/7 - t) + 14/11 sin(3 t + 11/7) + 2/3 sin(5 t + 11/7) + 1/36 sin(6 t + 50/11) + 1/14 sin(7 t + 5/3) + 3/5 sin(8 t + 11/7) + 5/12 sin(10 t + 11/7) + 5/9 sin(12 t + 19/12) + 1/11 sin(13 t + 47/10) + 1/9 sin(17 t + 13/8) + 2/11 sin(18 t + 19/12) + 2/11 sin(23 t + 13/8) + 1/42 sin(25 t + 37/25) + 1/43 sin(27 t + 18/11) + 1/20 sin(28 t + 8/5) + 1/20 sin(29 t + 13/8) - 47/12) θ(51 π - t) θ(t - 47 π) + (-1/6 sin(13/11 - 35 t) - 1/3 sin(12/11 - 33 t) - 3/11 sin(8/7 - 27 t) - 12/25 sin(11/8 - 23 t) - 5/6 sin(7/6 - 20 t) - 6/11 sin(10/9 - 19 t) - 1/12 sin(1/3 - 18 t) - 1/4 sin(5/7 - 14 t) - 5/4 sin(7/5 - 13 t) - 11/6 sin(11/8 - 10 t) - 4/7 sin(11/8 - 9 t) - 45/14 sin(26/17 - 7 t) - 398/57 sin(20/13 - 5 t) - 17/2 sin(20/13 - 3 t) - 46/5 sin(3/2 - 2 t) - 146/9 sin(14/9 - t) + 52/11 sin(4 t + 19/12) + 19/7 sin(6 t + 14/9) + sin(8 t + 8/5) + 1/2 sin(11 t + 27/14) + 16/11 sin(12 t + 19/11) + 1/6 sin(15 t + 21/8) + 16/13 sin(16 t + 13/7) + 1/5 sin(17 t + 21/8) + 1/23 sin(21 t + 29/14) + 1/3 sin(22 t + 20/11) + 4/13 sin(24 t + 20/11) + 1/8 sin(25 t + 8/3) + 1/9 sin(26 t + 12/7) + 1/13 sin(28 t + 19/13) + 1/8 sin(29 t + 20/9) + 1/13 sin(30 t + 37/8) + 1/5 sin(31 t + 19/9) + 1/22 sin(32 t + 15/8) + 1/9 sin(34 t + 1/4) + 1/11 sin(36 t + 79/39) + 1/9 sin(37 t + 19/7) + 87/13) θ(47 π - t) θ(t - 43 π) + (-1/26 sin(17/11 - 27 t) - 1/24 sin(25/17 - 25 t) - 1/71 sin(17/13 - 24 t) - 1/39 sin(19/13 - 22 t) - 1/11 sin(37/25 - 20 t) - 1/21 sin(14/9 - 18 t) - 7/20 sin(20/13 - 11 t) - 3/8 sin(14/9 - 9 t) - 5/7 sin(14/9 - 7 t) - 36/5 sin(14/9 - 2 t) - 39/8 sin(11/7 - t) + 14/15 sin(3 t + 11/7) + 10/11 sin(4 t + 8/5) + 11/15 sin(5 t + 21/13) + 3/8 sin(6 t + 8/5) + 7/9 sin(8 t + 8/5) + 1/9 sin(10 t + 31/21) + 1/9 sin(12 t + 11/7) + 1/15 sin(13 t + 14/3) + 1/11 sin(14 t + 8/5) + 1/20 sin(15 t + 47/10) + 1/10 sin(17 t + 23/14) + 1/20 sin(19 t + 13/8) + 1/41 sin(21 t + 14/9) + 1/19 sin(26 t + 5/3) + 164/3) θ(43 π - t) θ(t - 39 π) + (-1/46 sin(11/8 - 34 t) - 1/27 sin(11/8 - 31 t) - 1/31 sin(9/7 - 29 t) - 1/63 sin(38/25 - 28 t) - 1/23 sin(32/21 - 26 t) - 1/48 sin(11/10 - 23 t) - 1/14 sin(11/8 - 22 t) - 1/18 sin(10/7 - 21 t) - 1/7 sin(7/5 - 19 t) - 1/27 sin(14/9 - 16 t) - 1/10 sin(17/11 - 14 t) - 1/6 sin(16/11 - 12 t) - 1/4 sin(25/17 - 11 t) - 1/12 sin(32/21 - 8 t) - 1/49 sin(7/5 - 7 t) - 1/4 sin(14/9 - 6 t) - 19/6 sin(17/11 - 4 t) - 4/5 sin(17/11 - 3 t) + 35/17 sin(t + 19/12) + 73/12 sin(2 t + 19/12) + 5/11 sin(5 t + 14/9) + 1/6 sin(9 t + 5/3) + 3/10 sin(10 t + 28/17) + 1/10 sin(13 t + 21/13) + 1/33 sin(15 t + 13/9) + 1/8 sin(17 t + 12/7) + 1/36 sin(24 t + 14/3) + 1/13 sin(25 t + 17/10) + 1/29 sin(27 t + 28/17) + 1/81 sin(32 t + 13/7) + 1/82 sin(33 t + 7/4) + 405/7) θ(39 π - t) θ(t - 35 π) + (-1/20 sin(26/17 - 19 t) - 1/48 sin(16/11 - 15 t) - 8/15 sin(11/7 - 5 t) + 8/7 sin(t + 11/7) + 4/7 sin(2 t + 33/7) + 12/11 sin(3 t + 8/5) + 22/21 sin(4 t + 8/5) + 3/5 sin(6 t + 11/7) + 1/11 sin(7 t + 41/9) + 3/8 sin(8 t + 21/13) + 1/24 sin(9 t + 12/7) + 1/9 sin(10 t + 18/11) + 1/11 sin(11 t + 17/10) + 1/7 sin(12 t + 13/8) + 1/66 sin(13 t + 30/7) + 1/27 sin(14 t + 32/21) + 1/15 sin(17 t + 27/16) + 1/16 sin(20 t + 13/8) + 1/32 sin(21 t + 33/7) + 1/67 sin(24 t + 12/7) + 1/37 sin(26 t + 12/7) + 23) θ(35 π - t) θ(t - 31 π) + (-1/4 sin(11/7 - 7 t) - 2/11 sin(11/7 - 4 t) - 1/4 sin(11/7 - 3 t) - 8/5 sin(11/7 - t) + 13/7 sin(2 t + 11/7) + 3/7 sin(5 t + 33/7) + 3/11 sin(6 t + 33/7) + 1/27 sin(8 t + 75/16) + 1/15 sin(9 t + 47/10) + 1/15 sin(11 t + 47/10) + 1/66 sin(12 t + 8/5) + 1/42 sin(13 t + 11/7) + 1/47 sin(14 t + 11/7) + 1/41 sin(15 t + 33/7) + 262/7) θ(31 π - t) θ(t - 27 π) + (-1/27 sin(23/15 - 36 t) - 1/26 sin(14/9 - 32 t) - 1/7 sin(23/15 - 17 t) - 4 sin(11/7 - 2 t) - 5 sin(11/7 - t) + 53/18 sin(3 t + 19/12) + 2/7 sin(4 t + 9/5) + 33/8 sin(5 t + 8/5) + 7/3 sin(6 t + 21/13) + 2/5 sin(7 t + 79/17) + 11/16 sin(8 t + 61/13) + 12/11 sin(9 t + 13/8) + 11/16 sin(10 t + 5/3) + 1/6 sin(11 t + 12/7) + 1/14 sin(12 t + 60/13) + 2/9 sin(13 t + 23/14) + 1/7 sin(14 t + 7/4) + 2/9 sin(15 t + 5/3) + 1/25 sin(18 t + 37/8) + 2/9 sin(19 t + 18/11) + 1/94 sin(20 t + 29/11) + 1/29 sin(22 t + 32/7) + 1/12 sin(23 t + 19/11) + 1/12 sin(24 t + 11/6) + 1/8 sin(25 t + 12/7) + 1/23 sin(26 t + 32/7) + 1/70 sin(27 t + 15/7) + 1/11 sin(28 t + 16/9) + 1/14 sin(29 t + 7/4) + 1/31 sin(30 t + 32/7) + 1/99 sin(31 t + 13/8) + 1/19 sin(33 t + 17/10) + 1/40 sin(34 t + 19/10) + 1/64 sin(35 t + 17/10) + 1/32 sin(37 t + 19/11) + 1/54 sin(38 t + 28/13) + 1/17 sin(39 t + 23/13) + 1/26 sin(40 t + 33/7) + 604/17) θ(27 π - t) θ(t - 23 π) + (-1/85 sin(16/11 - 22 t) - 1/38 sin(20/13 - 17 t) - 2/5 sin(11/7 - 10 t) - 8/11 sin(11/7 - 6 t) + 27/2 sin(t + 33/7) + 11/12 sin(2 t + 19/12) + 23/17 sin(3 t + 33/7) + 17/14 sin(4 t + 14/9) + 19/10 sin(5 t + 14/9) + sin(7 t + 14/9) + 17/10 sin(8 t + 14/9) + 4/9 sin(9 t + 20/13) + 5/12 sin(11 t + 14/9) + 1/4 sin(12 t + 14/9) + 3/8 sin(13 t + 61/13) + 2/11 sin(14 t + 75/16) + 3/11 sin(15 t + 17/11) + 1/8 sin(16 t + 35/23) + 1/69 sin(18 t + 22/15) + 1/64 sin(19 t + 3/2) + 1/31 sin(21 t + 11/7) + 1/19 sin(23 t + 20/13) + 1/53 sin(24 t + 14/3) + 1/23 sin(25 t + 23/5) + 1/11 sin(26 t + 14/3) + 1/14 sin(27 t + 11/7) + 1/22 sin(28 t + 61/13) + 1/19 sin(29 t + 37/8) + 1/30 sin(30 t + 51/11) + 1/18 sin(31 t + 11/7) + 1/19 sin(32 t + 75/16) + 1/48 sin(33 t + 47/10) + 1/12 sin(34 t + 25/17) + 1/21 sin(35 t + 22/15) + 1/46 sin(36 t + 61/13) + 371/9) θ(23 π - t) θ(t - 19 π) + (-1/14 sin(13/9 - 42 t) - 1/19 sin(19/13 - 40 t) - 1/9 sin(22/15 - 38 t) - 1/26 sin(13/9 - 34 t) - 1/18 sin(11/7 - 31 t) - 1/20 sin(19/14 - 28 t) - 1/5 sin(19/13 - 27 t) - 1/8 sin(20/13 - 24 t) - 1/23 sin(14/11 - 23 t) - 1/7 sin(14/9 - 22 t) - 1/19 sin(26/17 - 20 t) - 2/7 sin(3/2 - 18 t) - 1/29 sin(19/13 - 17 t) - 2/5 sin(20/13 - 15 t) - 1/67 sin(13/10 - 13 t) - 6/7 sin(29/19 - 12 t) - 7/10 sin(14/9 - 11 t) - 31/9 sin(17/11 - 8 t) - 16/9 sin(20/13 - 7 t) - 52/15 sin(14/9 - 4 t) - 33/7 sin(14/9 - 3 t) - 615/28 sin(14/9 - 2 t) - 39/11 sin(14/9 - t) + 1/12 sin(5 t + 6/5) + 14/5 sin(6 t + 8/5) + 9/11 sin(9 t + 19/12) + 9/8 sin(10 t + 8/5) + 11/21 sin(14 t + 21/13) + 5/13 sin(16 t + 28/17) + 3/13 sin(19 t + 23/14) + 1/4 sin(21 t + 21/13) + 3/13 sin(25 t + 18/11) + 1/10 sin(26 t + 7/4) + 2/9 sin(29 t + 5/3) + 1/75 sin(30 t + 43/17) + 1/9 sin(32 t + 27/16) + 1/21 sin(33 t + 13/8) + 1/24 sin(35 t + 20/11) + 1/13 sin(36 t + 9/5) + 1/44 sin(37 t + 13/11) + 1/17 sin(39 t + 13/8) + 1/14 sin(41 t + 17/10) + 179/2) θ(19 π - t) θ(t - 15 π) + (-15/14 sin(11/7 - 4 t) + 21/2 sin(t + 11/7) + 59/8 sin(2 t + 33/7) + 8/17 sin(3 t + 8/5) + 10/21 sin(5 t + 75/16) + 17/8 sin(6 t + 47/10) + 7/13 sin(7 t + 47/10) + 1/4 sin(8 t + 11/7) + 43/44 sin(9 t + 14/9) + 1/3 sin(11 t + 47/10) + 1/2 sin(12 t + 47/10) + 1/15 sin(13 t + 61/13) + 1/52 sin(15 t + 13/8) + 1/10 sin(16 t + 33/7) + 1/9 sin(17 t + 11/7) + 1/22 sin(18 t + 47/10) + 1/10 sin(20 t + 14/3) + 1/51 sin(21 t + 5/3) + 1/24 sin(22 t + 79/17) + 1/22 sin(23 t + 51/11) + 1/11 sin(24 t + 47/10) + 1/42 sin(26 t + 3/2) + 1/17 sin(27 t + 17/11) + 1/22 sin(28 t + 65/14) + 1/31 sin(29 t + 23/5) + 1/19 sin(30 t + 14/3) + 1/41 sin(32 t + 14/3) + 1/84 sin(33 t + 17/11) + 917/12) θ(15 π - t) θ(t - 11 π) + (-1/43 sin(4/11 - 53 t) - 1/13 sin(13/9 - 50 t) - 1/13 sin(14/11 - 46 t) - 1/11 sin(17/13 - 45 t) - 1/6 sin(11/8 - 43 t) - 1/10 sin(14/11 - 41 t) - 1/5 sin(14/9 - 36 t) - 1/7 sin(18/17 - 35 t) - 1/7 sin(8/7 - 34 t) - 2/9 sin(11/8 - 33 t) - 3/8 sin(26/17 - 26 t) - 9/11 sin(19/13 - 24 t) - 3/11 sin(13/9 - 21 t) - 10/19 sin(13/9 - 17 t) - 25/19 sin(13/9 - 16 t) - 9/11 sin(17/12 - 13 t) - 9/8 sin(19/13 - 12 t) - 3/7 sin(11/9 - 9 t) - 192/35 sin(23/15 - 8 t) - 50/7 sin(17/11 - 6 t) - 16/5 sin(23/15 - 3 t) - 144/7 sin(14/9 - 2 t) - 24/7 sin(14/9 - t) + 59/20 sin(4 t + 13/8) + 7/11 sin(5 t + 4/3) + 26/9 sin(7 t + 14/9) + 21/20 sin(10 t + 17/10) + 5/7 sin(11 t + 5/3) + 2/7 sin(14 t + 11/6) + 15/11 sin(15 t + 5/3) + 5/4 sin(18 t + 17/10) + 1/4 sin(19 t + 2) + 1/3 sin(20 t + 13/8) + 1/8 sin(22 t + 15/7) + 9/11 sin(23 t + 27/16) + 2/11 sin(25 t + 7/6) + 1/8 sin(27 t + 32/21) + 1/6 sin(28 t + 19/10) + 3/11 sin(29 t + 69/35) + 6/13 sin(30 t + 16/9) + 1/16 sin(31 t + 38/11) + 3/13 sin(32 t + 5/3) + 5/11 sin(37 t + 7/4) + 1/7 sin(38 t + 30/7) + 5/11 sin(39 t + 20/11) + 1/10 sin(40 t + 42/17) + 1/35 sin(42 t + 8/13) + 1/12 sin(44 t + 11/7) + 1/5 sin(47 t + 27/14) + 1/14 sin(48 t + 37/15) + 1/36 sin(49 t + 16/11) + 1/9 sin(51 t + 17/9) + 1/25 sin(52 t + 12/5) + 944/11) θ(11 π - t) θ(t - 7 π) + (-3/13 sin(3/10 - 2 t) + 21/10 sin(t + 11/4) + 1/6 sin(3 t + 53/18) + 1/13 sin(4 t + 4/9) - 176/9) θ(7 π - t) θ(t - 3 π) + (-1/94 sin(11/10 - 22 t) - 1/75 sin(2/3 - 20 t) - 1/87 sin(21/16 - 18 t) - 1/58 sin(1/6 - 14 t) - 1/24 sin(1/5 - 12 t) - 1/20 sin(9/7 - 10 t) - 1/54 sin(19/18 - 8 t) - 1/7 sin(21/20 - 6 t) - 7/11 sin(1/8 - 2 t) + 38/7 sin(t + 17/8) + 3/7 sin(3 t + 14/11) + 1/11 sin(4 t + 53/13) + 2/9 sin(5 t + 10/7) + 1/15 sin(7 t + 5/6) + 1/10 sin(9 t + 7/6) + 1/22 sin(11 t + 7/9) + 1/35 sin(13 t + 7/10) + 1/51 sin(15 t + 18/13) + 1/74 sin(21 t + 33/13) + 269/5) θ(3 π - t) θ(t + π)) θ(sqrt(sgn(sin(t/2))))"

    let mp = MathParser(enableImpliedMultiplication: true)
    let xt: Evaluator! = mp.parse(x)
    XCTAssertNotNil(xt)
    let yt: Evaluator! = mp.parse(y)
    XCTAssertNotNil(yt)


    let unresolved = xt.unresolved
    XCTAssertTrue(unresolved.variables.contains("t") &&
                  unresolved.variables.count == 1 &&
                  unresolved.unaryFunctions.contains("sgn") &&
                  unresolved.unaryFunctions.contains("θ") &&
                  unresolved.unaryFunctions.count == 2 &&
                  unresolved.binaryFunctions.isEmpty)

    // The original Wolfram image has t going from 0 to 108π. It requires definitions for `sgn` and `θ`:
    // - sgn -- -1 if number is < 0, 1 if number is > 0 else 0
    // - θ -- 1 if number is >= 0 else 0

    var variables = ["t": 0.0]
    let unary = [
      "sgn": { x in x < 0.0 ? -1.0 : (x > 0.0 ? 1.0 : 0.0) },
      "θ": { x in x < 0.0 ? 0.0 : 1.0 }
    ]

    let xv = [50.872625489882026,
              33.25107337630128,
              -4.761603020749861,
              6.558079299631588,
              22.91692528468944,
              25.87107637827404,
              -81.6577131759006,
              -102.3006779451759,
              -55.76949080559591,
              -8.931155777727566]

    let yv = [58.88370675455304,
              89.15574592848417,
              37.48635206831484,
              22.74582329257655,
              -3.0495005749682234,
              -32.385818910140074,
              -70.01307568727277,
              -134.60732041788506,
              -107.58000277004543,
              -135.15110922952033]

    // Take 10 samples from the original range of 0 - 108π
    for t in 0..<10 {
      variables["t"] = Double(t) / 10.0 * 108 * .pi
      let x = xt.eval(variables: variables.producer, unaryFunctions: unary.producer)
      let y = yt.eval(variables: variables.producer, unaryFunctions: unary.producer)
      // print(x, y)
      XCTAssertEqual(xv[t], x, accuracy: 1.0E-8)
      XCTAssertEqual(yv[t], y, accuracy: 1.0E-8)
    }
  }
}
