// SortOrder.swift
// HitomiReader
//
// Represents the sorting order options supported by hitomi.la.

import Foundation

enum SortOrder: String, CaseIterable, Identifiable, Codable {
    case latest = "Latest"
    case popularToday = "Popular Today"
    case popularWeek = "Popular Week"
    case popularMonth = "Popular Month"
    case popularYear = "Popular Year"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .latest: return "Latest"
        case .popularToday: return "Popular (Today)"
        case .popularWeek: return "Popular (Week)"
        case .popularMonth: return "Popular (Month)"
        case .popularYear: return "Popular (Year)"
        }
    }
    
    var apiValue: String {
        switch self {
        case .latest: return ""
        case .popularToday: return "today"
        case .popularWeek: return "week"
        case .popularMonth: return "month"
        case .popularYear: return "year"
        }
    }
}
