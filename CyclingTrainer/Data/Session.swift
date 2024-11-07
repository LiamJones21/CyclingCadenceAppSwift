//
//  Session.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
// Session.swift

import Foundation

struct Session: Identifiable, Codable {
    var id: UUID
    var date: Date
    var name: String?
    var data: [CyclingData]
    
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func toDictionary() -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self),
           let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return dict
        }
        return [:]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Session? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let session = try? decoder.decode(Session.self, from: data) {
            return session
        }
        return nil
    }
}
