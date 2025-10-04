//
//  ContentView.swift
//  Airplane Tracker
//
//  Created by Garrett Moody on 10/3/25.
//

import SwiftUI
import MapKit

// Saved flight reference - only stores flight number and date
struct SavedFlight: Identifiable, Codable {
    let id: UUID
    let flightNumber: String
    let date: String // YYYY-MM-DD format
    
    init(id: UUID = UUID(), flightNumber: String, date: String) {
        self.id = id
        self.flightNumber = flightNumber
        self.date = date
    }
}

// UserDefaults helper for persistence
class FlightStorage {
    private static let savedFlightsKey = "savedFlights"
    
    static func saveFlights(_ flights: [SavedFlight]) {
        if let encoded = try? JSONEncoder().encode(flights) {
            UserDefaults.standard.set(encoded, forKey: savedFlightsKey)
            print("💾 Saved \(flights.count) flights to UserDefaults")
        }
    }
    
    static func loadFlights() -> [SavedFlight] {
        guard let data = UserDefaults.standard.data(forKey: savedFlightsKey),
              let flights = try? JSONDecoder().decode([SavedFlight].self, from: data) else {
            print("📂 No saved flights found")
            return []
        }
        print("📂 Loaded \(flights.count) flights from UserDefaults")
        return flights
    }
}

// Full flight data with UI properties
struct Flight: Identifiable {
    let id = UUID()
    let flightNumber: String
    let airline: String
    let departure: String
    let arrival: String
    let status: String
    let statusColor: Color
    let fullData: FlightData // Store full API data for detail view
}

struct ContentView: View {
    @State private var savedFlights: [SavedFlight] = [] {
        didSet {
            // Automatically save whenever savedFlights changes
            FlightStorage.saveFlights(savedFlights)
        }
    }
    @State private var loadedFlights: [Flight] = []
    @State private var isLoadingFlights = false
    @State private var showingSearchView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Airplane Tracker")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                    
                    // Main search button
                    Button(action: {
                        showingSearchView = true
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                            
                            Text("Search for a Flight")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 30)
                    
                    // Saved Flights Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Saved Flights")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !savedFlights.isEmpty {
                                Menu {
                                    Button(action: {
                                        loadSavedFlights()
                                    }) {
                                        Label("Refresh All", systemImage: "arrow.clockwise")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        savedFlights.removeAll()
                                        loadedFlights.removeAll()
                                    }) {
                                        Label("Clear All", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Text("\(savedFlights.count)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 25)
                        
                        if savedFlights.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bookmark.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("No saved flights")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ScrollView {
                                VStack(spacing: 12) {
                                    if isLoadingFlights {
                                        ProgressView()
                                            .padding()
                                    } else {
                                        ForEach(Array(loadedFlights.enumerated()), id: \.element.id) { index, flight in
                                            FlightCard(flight: flight, onDelete: {
                                                // Find and remove the saved flight
                                                if index < savedFlights.count {
                                                    savedFlights.remove(at: index)
                                                    loadedFlights.remove(at: index)
                                                }
                                            })
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .padding(.bottom, 0)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSearchView) {
            FlightSearchView(savedFlights: $savedFlights, onFlightAdded: {
                loadSavedFlights()
            })
        }
        .onAppear {
            // Load saved flights from UserDefaults on app launch
            if savedFlights.isEmpty {
                savedFlights = FlightStorage.loadFlights()
            }
            // Then fetch live data
            loadSavedFlights()
        }
    }
    
    private func loadSavedFlights() {
        guard !savedFlights.isEmpty else {
            loadedFlights = []
            return
        }
        
        isLoadingFlights = true
        
        Task {
            var flights: [Flight] = []
            
            print("=== LOADING SAVED FLIGHTS ===")
            for savedFlight in savedFlights {
                print("Loading: \(savedFlight.flightNumber) on \(savedFlight.date)")
                do {
                    let flightDataArray = try await FlightAPIService.shared.searchFlight(
                        flightNumber: savedFlight.flightNumber,
                        date: savedFlight.date
                    )
                    
                    if let flightData = flightDataArray.first,
                       let flight = FlightAPIService.convertToFlight(flightData) {
                        flights.append(flight)
                        if flightData.location != nil {
                            print("  ✅ Has live location data")
                        } else {
                            print("  ⚠️ No live location data")
                        }
                    } else {
                        print("  ❌ Could not convert flight data")
                    }
                } catch {
                    print("  ❌ Error: \(error)")
                }
            }
            print("Loaded \(flights.count) of \(savedFlights.count) flights")
            print("============================\n")
            
            await MainActor.run {
                loadedFlights = flights
                isLoadingFlights = false
            }
        }
    }
}

struct FlightSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var savedFlights: [SavedFlight]
    let onFlightAdded: () -> Void
    
    @State private var flightNumber = ""
    
    @State private var searchResults: [Flight] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.97, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Info Text
                    VStack(spacing: 8) {
                        Text("🔍 Search by Flight Number")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Enter the full flight number including airline code")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Search Form
                    VStack(spacing: 15) {
                        // Flight Number
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Flight Number")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            TextField("e.g. AS25, AA1004, DL123", text: $flightNumber)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                        }
                        
                        // Search Button
                        Button(action: performSearch) {
                            HStack {
                                if isSearching {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "magnifyingglass")
                                    Text("Search Flight")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isSearching || flightNumber.isEmpty)
                    }
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    
                    // Results
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Search Results")
                                .font(.system(size: 18, weight: .bold))
                                .padding(.horizontal)
                            
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(searchResults) { flight in
                                        SearchResultCard(flight: flight, onSave: {
                                            saveFlight(flight)
                                        })
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Search Flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        errorMessage = nil
        isSearching = true
        searchResults = []
        
        Task {
            do {
                // Search by flight number
                let flightDataArray = try await FlightAPIService.shared.searchFlight(
                    flightNumber: flightNumber.uppercased()
                )
                
                // Convert to UI flights
                let flights = flightDataArray.compactMap { FlightAPIService.convertToFlight($0) }
                
                // Debug output
                print("=== FLIGHT DATA DEBUG ===")
                print("Total flights received: \(flightDataArray.count)")
                for (index, flightData) in flightDataArray.enumerated() {
                    let flightNum = flightData.number ?? "Unknown"
                    let airline = flightData.airline?.name ?? "Unknown"
                    print("\nFlight \(index + 1): \(airline) \(flightNum)")
                    print("  Status: \(flightData.status ?? "Unknown")")
                    print("  Departure: \(flightData.departure?.airport?.name ?? "Unknown")")
                    print("  Arrival: \(flightData.arrival?.airport?.name ?? "Unknown")")
                    print("  Aircraft: \(flightData.aircraft?.model ?? "Unknown")")
                    
                    if let location = flightData.location {
                        print("  ✅ LIVE LOCATION FOUND:")
                        print("    - Lat: \(location.lat?.description ?? "nil"), Lon: \(location.lon?.description ?? "nil")")
                        print("    - Altitude: \(location.altitude?.feet?.description ?? "nil") ft")
                        print("    - Speed: \(location.groundSpeed?.kt?.description ?? "nil") kts")
                        print("    - Track: \(location.trueTrack?.deg?.description ?? "nil")°")
                        print("    - Reported: \(location.reportedAtUtc ?? "nil")")
                    } else {
                        print("  ❌ No live location data")
                    }
                }
                print("========================\n")
                
                await MainActor.run {
                    searchResults = flights
                    isSearching = false
                    
                    if flights.isEmpty {
                        errorMessage = "No flights found for \(flightNumber)"
                    }
                }
                
            } catch let error as FlightAPIError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }
    
    private func saveFlight(_ flight: Flight) {
        // Extract date from scheduled departure time
        guard let date = FlightAPIService.extractDate(from: flight.fullData.departure?.scheduledTime?.utc) else {
            print("Cannot save flight: no scheduled time")
            return
        }
        
        // Check if not already saved
        if !savedFlights.contains(where: { $0.flightNumber == flight.flightNumber && $0.date == date }) {
            let savedFlight = SavedFlight(flightNumber: flight.flightNumber, date: date)
            savedFlights.append(savedFlight)
            onFlightAdded()
        }
    }
}

struct SearchResultCard: View {
    let flight: Flight
    let onSave: () -> Void
    @State private var isSaved = false
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack(spacing: 15) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "airplane.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(flight.flightNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(flight.airline)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(flight.departure)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(flight.arrival)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text(flight.status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(flight.statusColor)
                        .cornerRadius(8)
                    
                    Button(action: {
                        onSave()
                        isSaved = true
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isSaved ? .blue : .gray)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .sheet(isPresented: $showingDetail) {
            FlightDetailView(flight: flight)
        }
    }
}

struct FlightCard: View {
    let flight: Flight
    var onDelete: (() -> Void)? = nil
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack(spacing: 15) {
                // Airline icon
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "airplane.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(flight.flightNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(flight.airline)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(flight.departure)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(flight.arrival)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Status badge
                    Text(flight.status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(flight.statusColor)
                        .cornerRadius(8)
                    
                    // Live tracking indicator
                    if flight.fullData.location != nil {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Live")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .sheet(isPresented: $showingDetail) {
            FlightDetailView(flight: flight)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

struct FlightDetailView: View {
    @Environment(\.dismiss) var dismiss
    let flight: Flight
    
    @State private var currentFlight: Flight
    @State private var isRefreshing = false
    
    init(flight: Flight) {
        self.flight = flight
        _currentFlight = State(initialValue: flight)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(currentFlight.flightNumber)
                            .font(.system(size: 28, weight: .bold))
                        
                        Text(currentFlight.airline)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Text(currentFlight.status)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(currentFlight.statusColor)
                                .cornerRadius(20)
                            
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .padding(.top)
                    
                    // Route
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text(currentFlight.departure)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if let depAirport = currentFlight.fullData.departure?.airport?.name {
                                Text(depAirport)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 4) {
                            Text(currentFlight.arrival)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            if let arrAirport = currentFlight.fullData.arrival?.airport?.name {
                                Text(arrAirport)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Live Tracking Map
                    if let location = currentFlight.fullData.location,
                       let lat = location.lat,
                       let lon = location.lon {
                        LiveTrackingMapView(
                            location: location,
                            flightNumber: currentFlight.flightNumber,
                            departure: currentFlight.fullData.departure?.airport,
                            arrival: currentFlight.fullData.arrival?.airport
                        )
                    }
                    
                    // Departure Info
                    if let departure = currentFlight.fullData.departure {
                        InfoSection(title: "Departure", icon: "airplane.departure") {
                            if let airport = departure.airport?.name {
                                InfoRow(label: "Airport", value: airport)
                            }
                            if let terminal = departure.terminal {
                                InfoRow(label: "Terminal", value: terminal)
                            }
                            if let gate = departure.gate {
                                InfoRow(label: "Gate", value: gate)
                            }
                            if let scheduled = departure.scheduledTime?.local {
                                InfoRow(label: "Scheduled", value: scheduled)
                            }
                            if let revised = departure.revisedTime?.local {
                                InfoRow(label: "Revised", value: revised, valueColor: .orange)
                            }
                            if let runway = departure.runwayTime?.local {
                                InfoRow(label: "Runway Time", value: runway, valueColor: .green)
                            }
                        }
                    }
                    
                    // Arrival Info
                    if let arrival = currentFlight.fullData.arrival {
                        InfoSection(title: "Arrival", icon: "airplane.arrival") {
                            if let airport = arrival.airport?.name {
                                InfoRow(label: "Airport", value: airport)
                            }
                            if let terminal = arrival.terminal {
                                InfoRow(label: "Terminal", value: terminal)
                            }
                            if let gate = arrival.gate {
                                InfoRow(label: "Gate", value: gate)
                            }
                            if let scheduled = arrival.scheduledTime?.local {
                                InfoRow(label: "Scheduled", value: scheduled)
                            }
                            if let predicted = arrival.predictedTime?.local {
                                InfoRow(label: "Predicted", value: predicted, valueColor: .blue)
                            }
                            if let revised = arrival.revisedTime?.local {
                                InfoRow(label: "Revised", value: revised, valueColor: .orange)
                            }
                        }
                    }
                    
                    // Flight Info
                    InfoSection(title: "Flight Information", icon: "info.circle") {
                        if let callSign = currentFlight.fullData.callSign {
                            InfoRow(label: "Call Sign", value: callSign)
                        }
                        
                        if let aircraft = currentFlight.fullData.aircraft {
                            if let model = aircraft.model {
                                InfoRow(label: "Aircraft", value: model)
                            }
                            if let reg = aircraft.reg {
                                InfoRow(label: "Registration", value: reg)
                            }
                        }
                        
                        if let distance = currentFlight.fullData.greatCircleDistance {
                            if let miles = distance.mile {
                                InfoRow(label: "Distance", value: String(format: "%.0f miles", miles))
                            }
                        }
                        
                        if let codeshareStatus = currentFlight.fullData.codeshareStatus {
                            InfoRow(label: "Codeshare", value: codeshareStatus)
                        }
                        
                        if let updated = currentFlight.fullData.lastUpdatedUtc {
                            InfoRow(label: "Last Updated", value: updated)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(red: 0.95, green: 0.97, blue: 1.0))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refreshFlight) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(isRefreshing ? .gray : .blue)
                    }
                    .disabled(isRefreshing)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func refreshFlight() {
        // Extract date from scheduled departure time
        guard let date = FlightAPIService.extractDate(from: currentFlight.fullData.departure?.scheduledTime?.utc) else {
            print("Cannot refresh: no scheduled time")
            return
        }
        
        isRefreshing = true
        
        Task {
            do {
                print("🔄 Refreshing flight \(currentFlight.flightNumber) on \(date)")
                let flightDataArray = try await FlightAPIService.shared.searchFlight(
                    flightNumber: currentFlight.flightNumber,
                    date: date
                )
                
                if let flightData = flightDataArray.first,
                   let updatedFlight = FlightAPIService.convertToFlight(flightData) {
                    await MainActor.run {
                        currentFlight = updatedFlight
                        isRefreshing = false
                        print("✅ Flight refreshed successfully")
                    }
                } else {
                    await MainActor.run {
                        isRefreshing = false
                        print("❌ Could not refresh flight data")
                    }
                }
            } catch {
                await MainActor.run {
                    isRefreshing = false
                    print("❌ Error refreshing: \(error)")
                }
            }
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding()
        .background(
            Divider()
                .frame(maxWidth: .infinity)
                .frame(height: 1)
                .background(Color.gray.opacity(0.2))
                .padding(.leading, 0),
            alignment: .bottom
        )
    }
}

struct LiveTrackingMapView: View {
    let location: LiveLocation
    let flightNumber: String
    let departure: AirportInfo?
    let arrival: AirportInfo?
    
    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: location.lat ?? 0,
            longitude: location.lon ?? 0
        )
    }
    
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    Text("Live Tracking")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("In Flight")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Text("Lat: \(location.lat ?? 0, specifier: "%.4f"), Lon: \(location.lon ?? 0, specifier: "%.4f")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Map with flight path
            ZStack {
                Map(coordinateRegion: .constant(region), annotationItems: createAnnotations()) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        createMarkerView(for: item)
                    }
                }
                .frame(height: 300)
                .cornerRadius(16)
            }
            .padding(.horizontal)
            
            // Live Data Grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    LiveDataCard(
                        icon: "arrow.up",
                        label: "Altitude",
                        value: formatAltitude(location.altitude?.feet),
                        color: .blue
                    )
                    LiveDataCard(
                        icon: "speedometer",
                        label: "Ground Speed",
                        value: formatSpeed(location.groundSpeed?.kt),
                        color: .green
                    )
                }
                
                HStack(spacing: 12) {
                    LiveDataCard(
                        icon: "safari",
                        label: "Track",
                        value: formatTrack(location.trueTrack?.deg),
                        color: .orange
                    )
                    LiveDataCard(
                        icon: "clock",
                        label: "Updated",
                        value: formatTime(location.reportedAtUtc),
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)
            
            if let reportedAt = location.reportedAtUtc {
                Text("Last position: \(reportedAt)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.5))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func createMarkerView(for item: FlightMapPoint) -> some View {
        if item.type == .plane {
            // Plane marker
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.4), radius: 6)
                    
                    Image(systemName: "airplane")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(location.trueTrack?.deg ?? 0))
                }
                
                Text(flightNumber)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.2), radius: 3)
            }
        } else if item.type == .departure {
            // Departure marker
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                Text(item.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(4)
                    .shadow(radius: 2)
            }
        } else {
            // Arrival marker
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                Text(item.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(4)
                    .shadow(radius: 2)
            }
        }
    }
    
    private func createAnnotations() -> [FlightMapPoint] {
        var annotations: [FlightMapPoint] = []
        
        // Add plane location
        annotations.append(FlightMapPoint(
            coordinate: coordinate,
            label: flightNumber,
            type: .plane
        ))
        
        // Add departure airport
        if let dep = departure, let depLat = dep.location?.lat, let depLon = dep.location?.lon {
            annotations.append(FlightMapPoint(
                coordinate: CLLocationCoordinate2D(latitude: depLat, longitude: depLon),
                label: dep.iata ?? "DEP",
                type: .departure
            ))
        }
        
        // Add arrival airport
        if let arr = arrival, let arrLat = arr.location?.lat, let arrLon = arr.location?.lon {
            annotations.append(FlightMapPoint(
                coordinate: CLLocationCoordinate2D(latitude: arrLat, longitude: arrLon),
                label: arr.iata ?? "ARR",
                type: .arrival
            ))
        }
        
        return annotations
    }
    
    private func formatAltitude(_ altitude: Double?) -> String {
        guard let altitude = altitude else { return "N/A" }
        return String(format: "%.0f ft", altitude)
    }
    
    private func formatSpeed(_ speed: Double?) -> String {
        guard let speed = speed else { return "N/A" }
        return String(format: "%.0f kts", speed)
    }
    
    private func formatTrack(_ track: Double?) -> String {
        guard let track = track else { return "N/A" }
        let compass = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((track + 22.5) / 45.0) % 8
        return "\(compass[index]) (\(Int(track))°)"
    }
    
    private func formatTime(_ time: String?) -> String {
        guard let time = time else { return "N/A" }
        // Extract just the time portion from UTC string like "2025-10-04 00:16Z"
        let components = time.components(separatedBy: " ")
        if components.count >= 2 {
            return components[1].replacingOccurrences(of: "Z", with: " UTC")
        }
        return time
    }
}

struct FlightMapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let label: String
    let type: AnnotationType
    
    enum AnnotationType {
        case plane
        case departure
        case arrival
    }
}

struct LiveDataCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
