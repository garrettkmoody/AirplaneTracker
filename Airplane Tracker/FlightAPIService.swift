//
//  FlightAPIService.swift
//  Airplane Tracker
//
//  Created by Garrett Moody on 10/3/25.
//

import Foundation
import SwiftUICore

// MARK: - API Models
struct FlightData: Codable, Identifiable {
    let id = UUID()
    let number: String?
    let callSign: String?
    let status: String?
    let isCargo: Bool?
    let departure: FlightEndpoint?
    let arrival: FlightEndpoint?
    let airline: AirlineInfo?
    let aircraft: AircraftInfo?
    let lastUpdatedUtc: String?
    let greatCircleDistance: Distance?
    let codeshareStatus: String?
    let location: LiveLocation?
    
    enum CodingKeys: String, CodingKey {
        case number, callSign, status, isCargo, departure, arrival, airline, aircraft
        case lastUpdatedUtc, greatCircleDistance, codeshareStatus, location
    }
}

struct FlightEndpoint: Codable {
    let airport: AirportInfo?
    let scheduledTime: TimeInfo?
    let revisedTime: TimeInfo?
    let predictedTime: TimeInfo?
    let runwayTime: TimeInfo?
    let terminal: String?
    let gate: String?
    let quality: [String]?
    
    enum CodingKeys: String, CodingKey {
        case airport, scheduledTime, revisedTime, predictedTime, runwayTime, terminal, gate, quality
    }
}

struct AirportInfo: Codable {
    let iata: String?
    let icao: String?
    let name: String?
    let shortName: String?
    let municipalityName: String?
    let countryCode: String?
    let location: LocationInfo?
    let timeZone: String?
    
    enum CodingKeys: String, CodingKey {
        case iata, icao, name, shortName, municipalityName, countryCode, location, timeZone
    }
}

struct LocationInfo: Codable {
    let lat: Double?
    let lon: Double?
}

struct TimeInfo: Codable {
    let local: String?
    let utc: String?
}

struct AirlineInfo: Codable {
    let name: String?
    let iata: String?
    let icao: String?
}

struct AircraftInfo: Codable {
    let model: String?
    let reg: String?
}

struct Distance: Codable {
    let km: Double?
    let mile: Double?
    let nm: Double?
    let meter: Double?
    let feet: Double?
}

struct LiveLocation: Codable {
    let lat: Double?
    let lon: Double?
    let altitude: Altitude?
    let pressureAltitude: Altitude?
    let groundSpeed: Speed?
    let trueTrack: Track?
    let pressure: Pressure?
    let reportedAtUtc: String?
}

struct Altitude: Codable {
    let meter: Double?
    let km: Double?
    let mile: Double?
    let nm: Double?
    let feet: Double?
}

struct Speed: Codable {
    let kt: Double?
    let kmPerHour: Double?
    let miPerHour: Double?
    let meterPerSecond: Double?
}

struct Track: Codable {
    let deg: Double?
    let rad: Double?
}

struct Pressure: Codable {
    let hPa: Double?
    let inHg: Double?
    let mmHg: Double?
}

// MARK: - API Error
enum FlightAPIError: LocalizedError {
    case invalidURL
    case missingRequiredParameters
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(String)
    case httpError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .missingRequiredParameters:
            return "Missing required parameters"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        }
    }
}

// MARK: - Flight API Service
class FlightAPIService {
    static let shared = FlightAPIService()
    
    // API base URL
    private let baseURL = "http://localhost:5000"
    
    private init() {}
    
    // MARK: - Search Flight
    /// Searches for a flight by flight number and optional date
    /// - Parameters:
    ///   - flightNumber: The flight number (e.g., "AS25", "AA1004")
    ///   - date: Optional date in YYYY-MM-DD format
    /// - Returns: Array of FlightData objects
    func searchFlight(flightNumber: String, date: String? = nil) async throws -> [FlightData] {
        guard !flightNumber.isEmpty else {
            throw FlightAPIError.missingRequiredParameters
        }
        
        // Remove spaces from flight number for URL
        let cleanFlightNumber = flightNumber.replacingOccurrences(of: " ", with: "")
        
        let urlString: String
        if let date = date {
            urlString = "\(baseURL)/flights/\(cleanFlightNumber)/\(date)"
        } else {
            urlString = "\(baseURL)/flights/\(cleanFlightNumber)"
        }
        
        guard let url = URL(string: urlString) else {
            throw FlightAPIError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Helper Methods
    private func performRequest(url: URL) async throws -> [FlightData] {
        let request = URLRequest(url: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FlightAPIError.invalidResponse
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode the response
                do {
                    let decoder = JSONDecoder()
                    
                    // Decode as array of FlightData
                    let flights = try decoder.decode([FlightData].self, from: data)
                    return flights
                } catch {
                    print("Decoding error: \(error)")
                    throw FlightAPIError.decodingError(error)
                }
                
            case 400:
                throw FlightAPIError.httpError(400, "Bad Request - Missing or invalid parameters")
            case 502:
                throw FlightAPIError.httpError(502, "Invalid response from aviation API")
            case 503:
                throw FlightAPIError.httpError(503, "Failed to fetch flight data from external API")
            default:
                throw FlightAPIError.httpError(httpResponse.statusCode, "Request failed")
            }
            
        } catch let error as FlightAPIError {
            throw error
        } catch {
            throw FlightAPIError.networkError(error)
        }
    }
    
    // MARK: - Utility Methods
    /// Formats a date to YYYY-MM-DD string
    static func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// Extracts date (YYYY-MM-DD) from UTC timestamp string
    static func extractDate(from utcString: String?) -> String? {
        guard let utcString = utcString else { return nil }
        // Format: "2025-10-03 20:28Z" -> extract "2025-10-03"
        let components = utcString.components(separatedBy: " ")
        return components.first
    }
    
    /// Converts FlightData to local Flight model for UI
    static func convertToFlight(_ flightData: FlightData) -> Flight? {
        guard let flightNumber = flightData.number,
              let airline = flightData.airline?.name,
              let departure = flightData.departure?.airport?.iata,
              let arrival = flightData.arrival?.airport?.iata else {
            return nil
        }
        
        let status = flightData.status ?? "Unknown"
        let statusColor: Color
        
        switch status.lowercased() {
        case "expected", "checkin", "boarding":
            statusColor = .blue
        case "enroute", "departed", "approaching":
            statusColor = .green
        case "delayed":
            statusColor = .orange
        case "canceled", "diverted", "canceleduncertain":
            statusColor = .red
        case "arrived":
            statusColor = .gray
        default:
            statusColor = .secondary
        }
        
        return Flight(
            flightNumber: flightNumber,
            airline: airline,
            departure: departure,
            arrival: arrival,
            status: status,
            statusColor: statusColor,
            fullData: flightData
        )
    }
    
    /// Formats ISO 8601 date string to readable format
    static func formatDateTime(_ isoString: String?) -> String? {
        guard let isoString = isoString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: isoString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else {
                return nil
            }
            
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .short
            return outputFormatter.string(from: date)
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .short
        return outputFormatter.string(from: date)
    }
}

