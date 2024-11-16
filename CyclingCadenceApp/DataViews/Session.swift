//
//  Session.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// Session.swift

import Foundation

import Foundation

struct Session: Identifiable, Codable {
    var id: UUID // Ensure 'id' is not optional and has no default value
    var date: Date
    var data: [CyclingData]
    var name: String?

//         You may include an initializer if needed
     init(id: UUID = UUID(), date: Date, data: [CyclingData], name: String? = nil) {
         self.id = id
         self.date = date
         self.data = data
         self.name = name
     }

    var displayName: String {
        name ?? dateFormatted
    }
   
        
    func toDictionary() -> [String: Any] {
            return [
                "id": id.uuidString,
                "name": name,
                "date": date.iso8601,
                "data": data.map { $0.toDictionary() }
            ]
        }

        static func fromDictionary(_ dict: [String: Any]) -> Session? {
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = dict["name"] as? String,
                  let dateString = dict["date"] as? String,
                  let date = ISO8601DateFormatter().date(from: dateString),
                  let dataArray = dict["data"] as? [[String: Any]] else {
                return nil
            }

            let data = dataArray.compactMap { CyclingData.fromDictionary($0) }
            // Corrected parameter order
            return Session(id: id, date: date, data: data, name: name)
        }
    }

extension Date {
    var iso8601: String {
        return ISO8601DateFormatter().string(from: self)
    }
}
