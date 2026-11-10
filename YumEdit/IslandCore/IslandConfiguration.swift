import Foundation
import CoreFoundation

#if compiler(>=6.2)
nonisolated
#endif
enum IslandError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

/// Bounds are serialization/overflow guards, never a claim that a value is safe on a device.
#if compiler(>=6.2)
nonisolated
#endif
struct IslandConfiguration: Codable, Equatable {
    let width: Int
    let height: Int
    let subtype: Int

    init(width: String, height: String, subtype: String) throws {
        guard [width, height, subtype].allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let w = Int(width), let h = Int(height), let s = Int(subtype) else {
            throw IslandError.invalid("请输入十进制正整数；不接受小数、符号或空白。")
        }
        self.width = w; self.height = h; self.subtype = s
        try validate()
    }

    func validate() throws {
        guard (1...16384).contains(width), (1...16384).contains(height), (1...65535).contains(subtype) else {
            throw IslandError.invalid("参数超出序列化保护范围。通过校验不代表设备兼容。")
        }
        guard width < height else { throw IslandError.invalid("本实验只接受竖屏 canvas_width < canvas_height。") }
    }

    func patched(gestalt: Data, resolution: Data) throws -> (Data, Data) {
        try validate()
        var mg = try Self.dictionary(gestalt)
        var res = try Self.dictionary(resolution)
        guard var extra = mg["CacheExtra"] as? [String: Any],
              var art = extra["oPeik/9e8lQWMszEjbPzng"] as? [String: Any],
              Self.integer(art["ArtworkDeviceSubType"]) != nil else {
            throw IslandError.invalid("MobileGestalt 缺少已知 ArtworkDeviceSubType 整数字段，拒绝猜测结构。")
        }
        for key in ["canvas_width", "canvas_height"] {
            if let value = res[key], Self.integer(value) == nil {
                throw IslandError.invalid("现有分辨率字段类型异常。")
            }
        }
        art["ArtworkDeviceSubType"] = subtype
        extra["oPeik/9e8lQWMszEjbPzng"] = art
        // This tool manages an already enabled island; it does not invent capability flags.
        mg["CacheExtra"] = extra
        res["canvas_width"] = width; res["canvas_height"] = height
        return (try Self.encode(mg), try Self.encode(res))
    }

    static func dictionary(_ data: Data) throws -> [String: Any] {
        guard data.count <= 16 * 1024 * 1024,
              let result = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw IslandError.invalid("需要小于 16 MiB 的 plist 字典。")
        }
        return result
    }
    static func integer(_ value: Any?) -> Int? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
              !["f", "d"].contains(String(cString: n.objCType)) else { return nil }
        return Int(n.stringValue)
    }
    static func encode(_ value: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }
}

/// Both preimages must be durably backed up before the first write. The caller serializes access.
#if compiler(>=6.2)
nonisolated
#endif
enum IslandTransaction {
    static func perform(original: [Data], proposed: [Data], backup: ([Data]) throws -> Void,
                        read: (Int) throws -> Data, write: (Int, Data) throws -> Void) throws {
        guard original.count == 2, proposed.count == 2 else { throw IslandError.invalid("需要两个文件。") }
        for i in 0..<2 { guard try read(i) == original[i] else { throw IslandError.invalid("文件已变化，请重新读取。") } }
        try backup(original)
        for i in 0..<2 { guard try read(i) == original[i] else { throw IslandError.invalid("备份期间文件已变化，未写入。") } }
        do {
            for i in 0..<2 {
                try write(i, proposed[i])
                guard try read(i) == proposed[i] else { throw IslandError.invalid("写后校验失败。") }
            }
        } catch {
            var failed = false
            for i in (0..<2).reversed() {
                do { try write(i, original[i]); if try read(i) != original[i] { failed = true } }
                catch { failed = true }
            }
            throw IslandError.invalid(failed ? "严重错误：回滚未完成。请勿重启，使用备份恢复。" : "写入失败，两个文件均已回滚并校验。")
        }
    }
}
