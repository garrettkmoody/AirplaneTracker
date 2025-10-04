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
            UserDefaults.standard.synchronize() // Force sync
            print("💾 Saved \(flights.count) flights to UserDefaults")
            for flight in flights {
                print("   - \(flight.flightNumber) on \(flight.date)")
            }
        } else {
            print("❌ Failed to encode flights for saving")
        }
    }
    
    static func loadFlights() -> [SavedFlight] {
        guard let data = UserDefaults.standard.data(forKey: savedFlightsKey) else {
            print("📂 No saved flights data in UserDefaults")
            return []
        }
        
        guard let flights = try? JSONDecoder().decode([SavedFlight].self, from: data) else {
            print("❌ Failed to decode saved flights")
            return []
        }
        
        print("📂 Loaded \(flights.count) flights from UserDefaults")
        for flight in flights {
            print("   - \(flight.flightNumber) on \(flight.date)")
        }
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
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var savedFlights: [SavedFlight] = []
    @State private var loadedFlights: [Flight] = []
    @State private var isLoadingFlights = false
    @State private var showingSearchView = false
    @State private var hasLoadedFromStorage = false
    @State private var showingPaywall = false
    
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }
    
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
                                                    let removedFlight = savedFlights[index]
                                                    savedFlights.remove(at: index)
                                                    loadedFlights.remove(at: index)
                                                    FlightStorage.saveFlights(savedFlights)
                                                    print("🗑️ Deleted flight: \(removedFlight.flightNumber)")
                                                }
                                            })
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            .refreshable {
                                await refreshAllFlights()
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
        .fullScreenCover(isPresented: $showingPaywall) {
            PurchaseView(subscriptionManager: subscriptionManager, isPresented: $showingPaywall)
        }
        .onAppear {
            print("📱 ContentView appeared")
            
            // Show paywall on first launch
            if isFirstLaunch {
                showingPaywall = true
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                print("🎉 First launch - showing paywall")
            }
            
            // Load saved flights from UserDefaults only once
            if !hasLoadedFromStorage {
                print("📂 Loading flights from UserDefaults...")
                savedFlights = FlightStorage.loadFlights()
                print("📂 Loaded \(savedFlights.count) saved flights")
                hasLoadedFromStorage = true
            } else {
                print("⏭️ Skipping load - already loaded from storage")
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
    
    private func refreshAllFlights() async {
        guard !savedFlights.isEmpty else {
            return
        }
        
        print("🔄 Pull-to-refresh triggered")
        
        var flights: [Flight] = []
        
        for savedFlight in savedFlights {
            do {
                let flightDataArray = try await FlightAPIService.shared.searchFlight(
                    flightNumber: savedFlight.flightNumber,
                    date: savedFlight.date
                )
                
                if let flightData = flightDataArray.first,
                   let flight = FlightAPIService.convertToFlight(flightData) {
                    flights.append(flight)
                }
            } catch {
                print("  ❌ Error refreshing \(savedFlight.flightNumber): \(error)")
            }
        }
        
        await MainActor.run {
            loadedFlights = flights
            print("✅ Refreshed \(flights.count) flights")
        }
    }
}

struct FlightSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var savedFlights: [SavedFlight]
    let onFlightAdded: () -> Void
    
    @State private var flightNumber = ""
    @State private var selectedDate = Date()
    
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
                        Text("🔍 Search for a Flight")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Enter flight number and date")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Search Form
                    VStack(spacing: 15) {
                        // Flight Number and Date in a row
                        HStack(spacing: 12) {
                            // Flight Number
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Flight Number")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                TextField("e.g. AS25", text: $flightNumber)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .autocapitalization(.allCharacters)
                                    .disableAutocorrection(true)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Date Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .labelsHidden()
                            }
                            .frame(width: 140)
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
                // Format date as YYYY-MM-DD
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: selectedDate)
                
                // Search by flight number with date
                let flightDataArray = try await FlightAPIService.shared.searchFlight(
                    flightNumber: flightNumber.uppercased(),
                    date: dateString
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
            print("❌ Cannot save flight: no scheduled time")
            return
        }
        
        print("📝 Attempting to save flight: \(flight.flightNumber) on \(date)")
        
        // Check if not already saved
        if !savedFlights.contains(where: { $0.flightNumber == flight.flightNumber && $0.date == date }) {
            let savedFlight = SavedFlight(flightNumber: flight.flightNumber, date: date)
            savedFlights.append(savedFlight)
            print("✅ Flight saved! Total saved flights: \(savedFlights.count)")
            print("   Flight details: \(savedFlight.flightNumber) - \(savedFlight.date)")
            
            // Explicitly save to UserDefaults to ensure it persists
            FlightStorage.saveFlights(savedFlights)
            
            onFlightAdded()
        } else {
            print("⚠️ Flight already saved")
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
                
                VStack(alignment: .trailing, spacing: 8) {
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
            FlightDetailView(flight: flight, onSave: {
                onSave()
                isSaved = true
            })
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
            FlightDetailView(flight: flight, onDelete: onDelete)
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
    var onDelete: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    
    @State private var currentFlight: Flight
    @State private var isRefreshing = false
    @State private var isSaved = false
    
    init(flight: Flight, onDelete: (() -> Void)? = nil, onSave: (() -> Void)? = nil) {
        self.flight = flight
        self.onDelete = onDelete
        self.onSave = onSave
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
                    HStack(spacing: 16) {
                        // Show delete button if this is from saved flights
                        if let onDelete = onDelete {
                            Button(role: .destructive, action: {
                                onDelete()
                                dismiss()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Show save button if this is from search results
                        if let onSave = onSave {
                            Button(action: {
                                onSave()
                                isSaved = true
                            }) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(isSaved ? .blue : .blue)
                            }
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
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
            FlightPathMapView(
                coordinate: coordinate,
                region: region,
                annotations: createAnnotations(),
                departure: departure,
                flightNumber: flightNumber,
                location: location
            )
            .frame(height: 300)
            .cornerRadius(16)
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

// Custom MapKit view with polyline support
struct FlightPathMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let region: MKCoordinateRegion
    let annotations: [FlightMapPoint]
    let departure: AirportInfo?
    let flightNumber: String
    let location: LiveLocation
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Add annotations
        for item in annotations {
            let annotation = FlightAnnotation(
                coordinate: item.coordinate,
                title: item.label,
                type: item.type,
                heading: location.trueTrack?.deg ?? 0
            )
            mapView.addAnnotation(annotation)
        }
        
        // Draw red line from departure to current location
        if let dep = departure,
           let depLat = dep.location?.lat,
           let depLon = dep.location?.lon {
            let departureCoord = CLLocationCoordinate2D(latitude: depLat, longitude: depLon)
            let coordinates = [departureCoord, coordinate]
            let polyline = MKPolyline(coordinates: coordinates, count: 2)
            mapView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FlightPathMapView
        
        init(_ parent: FlightPathMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "FlightAnnotation"
            
            guard let flightAnnotation = annotation as? FlightAnnotation else {
                return nil
            }
            
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView.canShowCallout = true
            
            // Create custom view based on type
            let customView: UIView
            
            switch flightAnnotation.annotationType {
            case .plane:
                // Plane marker with rotation
                let container = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 70))
                
                let circle = UIView(frame: CGRect(x: 8, y: 0, width: 44, height: 44))
                circle.backgroundColor = .systemBlue
                circle.layer.cornerRadius = 22
                circle.layer.shadowColor = UIColor.systemBlue.cgColor
                circle.layer.shadowOpacity = 0.4
                circle.layer.shadowRadius = 6
                circle.layer.shadowOffset = .zero
                
                let imageView = UIImageView(frame: CGRect(x: 11, y: 11, width: 22, height: 22))
                imageView.image = UIImage(systemName: "airplane")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                imageView.contentMode = .scaleAspectFit
                
                // Rotate the plane icon
                let rotationAngle = (flightAnnotation.heading - 90) * .pi / 180 // Adjust for icon orientation
                imageView.transform = CGAffineTransform(rotationAngle: rotationAngle)
                
                circle.addSubview(imageView)
                container.addSubview(circle)
                
                // Label
                let label = UILabel(frame: CGRect(x: 0, y: 48, width: 60, height: 20))
                label.text = flightAnnotation.title
                label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                label.textAlignment = .center
                label.backgroundColor = .white
                label.layer.cornerRadius = 6
                label.clipsToBounds = true
                label.layer.shadowColor = UIColor.black.cgColor
                label.layer.shadowOpacity = 0.2
                label.layer.shadowRadius = 3
                label.layer.shadowOffset = .zero
                container.addSubview(label)
                
                customView = container
                
            case .departure:
                // Green circle for departure
                let container = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 30))
                
                let circle = UIView(frame: CGRect(x: 14, y: 0, width: 12, height: 12))
                circle.backgroundColor = .systemGreen
                circle.layer.cornerRadius = 6
                circle.layer.borderWidth = 2
                circle.layer.borderColor = UIColor.white.cgColor
                container.addSubview(circle)
                
                let label = UILabel(frame: CGRect(x: 0, y: 14, width: 40, height: 16))
                label.text = flightAnnotation.title
                label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
                label.textAlignment = .center
                label.backgroundColor = UIColor.white.withAlphaComponent(0.9)
                label.layer.cornerRadius = 4
                label.clipsToBounds = true
                container.addSubview(label)
                
                customView = container
                
            case .arrival:
                // Red circle for arrival
                let container = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 30))
                
                let circle = UIView(frame: CGRect(x: 14, y: 0, width: 12, height: 12))
                circle.backgroundColor = .systemRed
                circle.layer.cornerRadius = 6
                circle.layer.borderWidth = 2
                circle.layer.borderColor = UIColor.white.cgColor
                container.addSubview(circle)
                
                let label = UILabel(frame: CGRect(x: 0, y: 14, width: 40, height: 16))
                label.text = flightAnnotation.title
                label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
                label.textAlignment = .center
                label.backgroundColor = UIColor.white.withAlphaComponent(0.9)
                label.layer.cornerRadius = 4
                label.clipsToBounds = true
                container.addSubview(label)
                
                customView = container
            }
            
            annotationView.addSubview(customView)
            annotationView.frame = customView.frame
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemRed
                renderer.lineWidth = 3.0
                renderer.lineDashPattern = [2, 4] // Dashed line
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Custom annotation class
class FlightAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var annotationType: FlightMapPoint.AnnotationType
    var heading: Double
    
    init(coordinate: CLLocationCoordinate2D, title: String?, type: FlightMapPoint.AnnotationType, heading: Double) {
        self.coordinate = coordinate
        self.title = title
        self.annotationType = type
        self.heading = heading
        super.init()
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
