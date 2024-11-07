//
//  Session.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 20/10/2024.
// Session.swift

import Foundation

import Foundation

struct Session: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var data: [CyclingData]
    var name: String? // Added name property

    var displayName: String {
        name ?? dateFormatted
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

