//
//  File.swift
//  
//
//  Created by Nick Ager on 21/02/2024.
//

import Foundation

import XCTest
import Parsing
@testable import MathParser

final class AssignmentTests: XCTestCase {
    let parser = MathParser()
    
    func testAssigmentParser() {
        let result = parser.parse("avar = 45")
        XCTAssertNotNil(result)
        XCTAssertTrue(parser.variables.keys.contains("avar"))
        XCTAssertEqual(45.0, parser.variables["avar"])
    }

    func testAssigmentWithoutSpacesParser() {
        let result = parser.parse("avar=45")
        XCTAssertNotNil(result)
        XCTAssertTrue(parser.variables.keys.contains("avar"))
        XCTAssertEqual(45.0, parser.variables["avar"])
    }
    
    func testAssigmentWithoutSpace1Parser() {
        let result = parser.parse("avar =45")
        XCTAssertNotNil(result)
        XCTAssertTrue(parser.variables.keys.contains("avar"))
        XCTAssertEqual(45.0, parser.variables["avar"])
    }
    
    func testAssigmentWithoutSpace2Parser() {
        let result = parser.parse("avar= 45")
        XCTAssertNotNil(result)
        XCTAssertTrue(parser.variables.keys.contains("avar"))
        XCTAssertEqual(45.0, parser.variables["avar"])
    }
    
    func testAssigmentWithoutSpace3Parser() {
        let result = parser.parse(" avar= 45")
        XCTAssertNotNil(result)
        XCTAssertTrue(parser.variables.keys.contains("avar"))
        XCTAssertEqual(45.0, parser.variables["avar"])
    }
    
}
