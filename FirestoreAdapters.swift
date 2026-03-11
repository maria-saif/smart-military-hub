import Foundation
import CryptoKit


private func deterministicUUID(from string: String) -> UUID {
    let hash = SHA256.hash(data: Data(string.utf8))
    let b = Array(hash.prefix(16))
    return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                       b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
}

@inline(__always) private func val(_ s: String?) -> String { s ?? "" }
@inline(__always) private func val(_ s: String)  -> String { s }


extension Soldier {

    static func fromFirestore(id docID: String, data: [String: Any]) -> Soldier {
        let name      = (data["fullName"] as? String) ?? (data["name"] as? String) ?? "—"
        let rank      = (data["rank"] as? String) ?? ""
        let unit      = (data["unit"] as? String) ?? ""
        let serviceId = (data["militaryId"] as? String) ?? (data["serviceId"] as? String) ?? ""

        let base  = serviceId.isEmpty ? (name + rank) : serviceId
        let uuid: UUID = UUID(uuidString: docID) ?? deterministicUUID(from: base)

        return Soldier(id: uuid, name: name, rank: rank, unit: unit)
    }

    static func fromDTO(_ dto: SoldierDTO) -> Soldier {
        let fullName  = val(dto.fullName)
        let rank      = val(dto.rank)
        let unit      = val(dto.unit)
        let serviceId = val(dto.militaryId)

        let base = serviceId.isEmpty ? (fullName + rank) : serviceId

        let uuid: UUID = {
            if let u = dto.id as? UUID { return u }
            if let s = dto.id as? String, let u = UUID(uuidString: s) { return u }
            if let s = dto.uid as? String, let u = UUID(uuidString: s) { return u }
            return deterministicUUID(from: base)
        }()

        return Soldier(id: uuid, name: fullName, rank: rank, unit: unit)
    }
}
