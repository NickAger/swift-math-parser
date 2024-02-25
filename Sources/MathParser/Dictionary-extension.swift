// `appending` helper methods for dictionaries

public extension Dictionary where Key == String, Value == Double {
    func appending(_ other: [String: Double]?) -> [String: Double] {
        guard let other = other else { return self }
        var result = self
        for (key, value) in other { result[key] = value }
        return result
    }
}

public extension Dictionary where Key == String, Value == (Double) -> Double {
    func appending(_ other: [String: (Double) -> Double]?) -> [String: (Double) -> Double] {
        guard let other = other else { return self }
        var result = self
        for (key, value) in other { result[key] = value }
        return result
    }
}

public extension Dictionary where Key == String, Value == (Double, Double) -> Double {
    func appending(_ other: [String: (Double, Double) -> Double]?) -> [String: (Double, Double) -> Double] {
        guard let other = other else { return self }
        var result = self
        for (key, value) in other { result[key] = value }
        return result
    }
}
