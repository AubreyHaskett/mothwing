import Foundation

public enum DeviceInfo {
    /// Hardware identifier such as "iPhone14,6" (iPhone SE 3rd gen) so benchmark
    /// CSVs are labeled with the exact chip class being tested.
    public static func modelIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let id = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "Simulator(\(id))"
        }
        return "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "unknown" : identifier
        #endif
    }
}
