import Foundation

struct DFUSerialInfo: Equatable, Sendable {
    let cpid: String?
    let bdid: Int?
    let ecid: String?
    let serialNumber: String?
    let isPwndfu: Bool
}

enum DFUSerialParser {
    static func parse(_ serial: String) -> DFUSerialInfo {
        let fields = Dictionary(
            uniqueKeysWithValues: serial
                .split(separator: " ")
                .compactMap { part -> (String, String)? in
                    let pieces = part.split(separator: ":", maxSplits: 1)
                    guard pieces.count == 2 else { return nil }
                    return (String(pieces[0]), String(pieces[1]))
                }
        )

        let cpid = fields["CPID"].map { "0x\($0.uppercased())" }
        let bdid = fields["BDID"].flatMap { Int($0, radix: 16) }
        let ecid = fields["ECID"]
        let serialNumber = fields["SRNM"]?
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let isPwndfu = serial.contains("PWND:[usbliter8]")

        return DFUSerialInfo(cpid: cpid, bdid: bdid, ecid: ecid, serialNumber: serialNumber, isPwndfu: isPwndfu)
    }
}
