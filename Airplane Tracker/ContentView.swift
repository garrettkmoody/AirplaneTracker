//
//  ContentView.swift
//  Airplane Tracker
//
//  Created by Garrett Moody on 10/3/25.
//

import SwiftUI
import MapKit
import StoreKit
import FirebaseAnalytics

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
    let fullData: FlightData? // Store full API data for detail view (nil for error states)
    let hasError: Bool // True if flight failed to load
    
    init(flightNumber: String, airline: String, departure: String, arrival: String, status: String, statusColor: Color, fullData: FlightData) {
        self.flightNumber = flightNumber
        self.airline = airline
        self.departure = departure
        self.arrival = arrival
        self.status = status
        self.statusColor = statusColor
        self.fullData = fullData
        self.hasError = false
    }
    
    // Error state initializer
    init(failedFlightNumber: String) {
        self.flightNumber = failedFlightNumber
        self.airline = "Failed to load"
        self.departure = ""
        self.arrival = ""
        self.status = "Error"
        self.statusColor = .red
        self.fullData = nil
        self.hasError = true
    }
}

struct ContentView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var savedFlights: [SavedFlight] = []
    @State private var loadedFlights: [Flight] = []
    @State private var isLoadingFlights = false
    @State private var showingSearchView = false
    @State private var hasLoadedFromStorage = false
    @State private var showingPaywall = false
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }
    
    private var hasSeenOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
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
                        Analytics.logEvent("search_button_clicked", parameters: nil)
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
                                            FlightCard(
                                                flight: flight,
                                                savedDate: index < savedFlights.count ? savedFlights[index].date : nil,
                                                onDelete: {
                                                    // Find and remove the saved flight
                                                    if index < savedFlights.count {
                                                        let removedFlight = savedFlights[index]
                                                        savedFlights.remove(at: index)
                                                        loadedFlights.remove(at: index)
                                                        FlightStorage.saveFlights(savedFlights)
                                                        print("🗑️ Deleted flight: \(removedFlight.flightNumber)")
                                                    }
                                                }
                                            )
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
            .navigationBarHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearchView) {
            FlightSearchView(
                savedFlights: $savedFlights,
                subscriptionManager: subscriptionManager,
                onFlightAdded: {
                    loadSavedFlights()
                },
                onUpgradeNeeded: {
                    showingSearchView = false
                    showingPaywall = true
                }
            )
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding, onComplete: {
                // After onboarding, show paywall
                showingPaywall = true
            })
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PurchaseView(subscriptionManager: subscriptionManager, isPresented: $showingPaywall)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                subscriptionManager: subscriptionManager,
                onUpgrade: {
                    Analytics.logEvent("upgrade_button_clicked", parameters: [
                        "source": "settings"
                    ])
                    showingSettings = false
                    showingPaywall = true
                }
            )
        }
        .onAppear {
            print("📱 ContentView appeared")
            
            // Show onboarding on first launch
            if isFirstLaunch && !hasSeenOnboarding {
                showingOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                print("🎉 First launch - showing onboarding")
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
                print("🔍 Loading saved flight:")
                print("   Flight Number: \(savedFlight.flightNumber)")
                print("   Saved Date: \(savedFlight.date)")
                print("   API Request: /flights/\(savedFlight.flightNumber)/\(savedFlight.date)?single=true")
                do {
                    let flightDataArray = try await FlightAPIService.shared.searchFlight(
                        flightNumber: savedFlight.flightNumber,
                        date: savedFlight.date,
                        single: true  // Only get the flight matching departure date
                    )
                    
                    if let flightData = flightDataArray.first,
                       let flight = FlightAPIService.convertToFlight(flightData) {
                        flights.append(flight)
                        print("   ✅ Flight data received:")
                        print("      Departure UTC: \(flightData.departure?.scheduledTime?.utc ?? "nil")")
                        print("      Arrival UTC: \(flightData.arrival?.scheduledTime?.utc ?? "nil")")
                        if flightData.location != nil {
                            print("      Has live location data: YES")
                        } else {
                            print("      Has live location data: NO")
                        }
                    } else {
                        print("  ❌ Could not convert flight data")
                        // Add error flight so user can see and delete it
                        flights.append(Flight(failedFlightNumber: savedFlight.flightNumber))
                    }
                } catch {
                    print("  ❌ Error: \(error)")
                    // Add error flight so user can see and delete it
                    flights.append(Flight(failedFlightNumber: savedFlight.flightNumber))
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
            print("   Refreshing: \(savedFlight.flightNumber) on date \(savedFlight.date)")
            do {
                let flightDataArray = try await FlightAPIService.shared.searchFlight(
                    flightNumber: savedFlight.flightNumber,
                    date: savedFlight.date,
                    single: true  // Only get the flight matching departure date
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
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onFlightAdded: () -> Void
    let onUpgradeNeeded: () -> Void
    
    @State private var flightNumber = ""
    @State private var selectedDate = Date()
    
    @State private var searchResults: [Flight] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchCount: Int = UserDefaults.standard.integer(forKey: "searchCount")
    @State private var showingPaywall = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.95, green: 0.97, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Free Search Indicator (for non-subscribers)
                    if !subscriptionManager.hasActiveSubscription {
                        HStack(spacing: 8) {
                            Image(systemName: searchCount >= 1 ? "exclamationmark.circle.fill" : "info.circle.fill")
                                .foregroundColor(searchCount >= 1 ? .orange : .blue)
                            
                            if searchCount >= 1 {
                                Text("No free searches remaining")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            } else {
                                Text("1 free search remaining")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                Analytics.logEvent("upgrade_button_clicked", parameters: [
                                    "source": "search_banner"
                                ])
                                showingPaywall = true
                            }) {
                                Text("Upgrade")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(searchCount >= 1 ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    
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
                    .padding(.top, subscriptionManager.hasActiveSubscription ? 20 : 10)
                    
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
                                        SearchResultCard(flight: flight, onSave: { completion in
                                            saveFlight(flight, completion: completion)
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
            .onAppear {
                // Reset search count if user subscribes
                if subscriptionManager.hasActiveSubscription {
                    searchCount = 0
                    UserDefaults.standard.set(0, forKey: "searchCount")
                }
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                PurchaseView(subscriptionManager: subscriptionManager, isPresented: $showingPaywall)
            }
            .onChange(of: subscriptionManager.hasActiveSubscription) { isSubscribed in
                if isSubscribed {
                    // Reset search count when user subscribes
                    searchCount = 0
                    UserDefaults.standard.set(0, forKey: "searchCount")
                }
            }
        }
    }
    
    private func performSearch() {
        // Check if user is subscribed
        if !subscriptionManager.hasActiveSubscription {
            // Non-subscribers can only do 1 search
            if searchCount >= 1 {
                print("🚫 Non-subscriber reached search limit")
                Analytics.logEvent("upgrade_button_clicked", parameters: [
                    "source": "search_limit_reached"
                ])
                showingPaywall = true
                return
            }
        }
        
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
                    
                    // Log successful search
                    Analytics.logEvent("flight_searched", parameters: [
                        "flight_number": flightNumber.uppercased(),
                        "results_count": flights.count,
                        "has_subscription": subscriptionManager.hasActiveSubscription
                    ])
                    
                    // Increment search count for non-subscribers
                    if !subscriptionManager.hasActiveSubscription {
                        searchCount += 1
                        UserDefaults.standard.set(searchCount, forKey: "searchCount")
                        print("📊 Search count: \(searchCount)")
                    }
                    
                    if flights.isEmpty {
                        errorMessage = "No flights found for \(flightNumber)"
                    }
                }
                
            } catch let error as FlightAPIError {
                await MainActor.run {
                    // Show "No flights found" for 503 errors
                    if case .httpError(let code, _) = error, code == 503 {
                        errorMessage = "No flights found for \(flightNumber)"
                    } else {
                        errorMessage = error.errorDescription
                    }
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
    
    private func saveFlight(_ flight: Flight, completion: @escaping (Bool) -> Void) {
        // Log save attempt
        Analytics.logEvent("save_flight_clicked", parameters: [
            "flight_number": flight.flightNumber,
            "has_subscription": subscriptionManager.hasActiveSubscription
        ])
        
        // Check if user is subscribed
        if !subscriptionManager.hasActiveSubscription {
            print("🚫 Non-subscriber attempted to save flight")
            Analytics.logEvent("upgrade_button_clicked", parameters: [
                "source": "save_flight_blocked"
            ])
            showingPaywall = true
            completion(false)
            return
        }
        
        // Extract date from LOCAL departure time (not UTC!)
        guard let departureLocal = flight.fullData?.departure?.scheduledTime?.local else {
            print("❌ Cannot save flight: no local scheduled departure time")
            completion(false)
            return
        }
        
        // Extract date from format like "2025-10-05 06:38-07:00"
        let dateComponents = departureLocal.components(separatedBy: " ")
        guard let date = dateComponents.first else {
            print("❌ Cannot save flight: invalid date format in \(departureLocal)")
            completion(false)
            return
        }
        
        print("🔍 DEBUG - Saving flight:")
        print("   Flight Number: \(flight.flightNumber)")
        print("   Departure Local: \(departureLocal)")
        print("   Extracted Departure Date: \(date)")
        print("   Arrival Local: \(flight.fullData?.arrival?.scheduledTime?.local ?? "nil")")
        print("📝 Saving flight: \(flight.flightNumber) on \(date) (using local departure date)")
        
        // Check if not already saved
        if !savedFlights.contains(where: { $0.flightNumber == flight.flightNumber && $0.date == date }) {
            let savedFlight = SavedFlight(flightNumber: flight.flightNumber, date: date)
            savedFlights.append(savedFlight)
            print("✅ Flight saved! Total saved flights: \(savedFlights.count)")
            print("   Flight details: \(savedFlight.flightNumber) - \(savedFlight.date)")
            
            // Explicitly save to UserDefaults to ensure it persists
            FlightStorage.saveFlights(savedFlights)
            
            // Log successful save
            Analytics.logEvent("flight_saved", parameters: [
                "flight_number": flight.flightNumber,
                "total_saved_flights": savedFlights.count
            ])
            
            onFlightAdded()
            completion(true)
        } else {
            print("⚠️ Flight already saved")
            completion(true) // Still return true since it's saved
        }
    }
}

struct SearchResultCard: View {
    let flight: Flight
    let onSave: (@escaping (Bool) -> Void) -> Void
    @State private var showingDetail = false
    @State private var isSaved = false
    
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
                    if flight.fullData?.location != nil {
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
                        onSave { success in
                            if success {
                                isSaved = true
                            }
                        }
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.blue)
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
            FlightDetailView(flight: flight, onSave: { completion in
                // Dismiss detail first, then trigger save (which may show paywall)
                // Set flag to prevent review prompt when dismissing programmatically
                UserDefaults.standard.set(true, forKey: "dismissedForPaywall")
                showingDetail = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onSave { success in
                        completion(success)
                        if success {
                            isSaved = true
                        }
                        // Clear flag after action completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            UserDefaults.standard.set(false, forKey: "dismissedForPaywall")
                        }
                    }
                }
            })
        }
    }
}

struct FlightCard: View {
    let flight: Flight
    var savedDate: String? = nil  // The date from SavedFlight for refresh purposes
    var onDelete: (() -> Void)? = nil
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            // Only show detail if flight loaded successfully
            if !flight.hasError {
                showingDetail = true
            }
        }) {
            HStack(spacing: 15) {
                // Icon
                Circle()
                    .fill(flight.hasError ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: flight.hasError ? "exclamationmark.triangle.fill" : "airplane.circle.fill")
                            .foregroundColor(flight.hasError ? .red : .blue)
                            .font(.system(size: 24))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(flight.flightNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if flight.hasError {
                        Text("Failed to load")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    } else {
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
                }
                
                Spacer()
                
                if !flight.hasError {
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
                        if flight.fullData?.location != nil {
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
            }
            .padding(16)
            .background(flight.hasError ? Color.red.opacity(0.05) : Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .sheet(isPresented: $showingDetail) {
            if !flight.hasError {
                FlightDetailView(flight: flight, onDelete: onDelete, savedDate: savedDate)
            }
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
    var onSave: ((@escaping (Bool) -> Void) -> Void)? = nil
    var savedDate: String? = nil  // The date from SavedFlight (YYYY-MM-DD format)
    
    @State private var currentFlight: Flight
    @State private var isRefreshing = false
    @State private var isSaved = false
    
    init(flight: Flight, onDelete: (() -> Void)? = nil, onSave: ((@escaping (Bool) -> Void) -> Void)? = nil, savedDate: String? = nil) {
        self.flight = flight
        self.onDelete = onDelete
        self.onSave = onSave
        self.savedDate = savedDate
        _currentFlight = State(initialValue: flight)
    }
    
    // Helper function to format time strings cleanly in airport's local timezone
    private func formatTimeClean(_ timeString: String?) -> String? {
        guard let timeString = timeString else { return nil }
        
        // Parse format like "2025-10-05 06:38-07:00"
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mmZZZZZ"
        
        guard let date = inputFormatter.date(from: timeString) else {
            return timeString // Return original if parsing fails
        }
        
        // Extract timezone offset from original string (e.g., "-07:00" from "2025-10-05 06:38-07:00")
        if let range = timeString.range(of: "[+-]\\d{2}:\\d{2}$", options: .regularExpression) {
            let offsetString = String(timeString[range])
            // Parse offset like "-07:00" into seconds
            let components = offsetString.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "+", with: "")
            if let hours = Int(components.prefix(3)), let minutes = Int(components.suffix(2)) {
                let seconds = (abs(hours) * 3600 + minutes * 60) * (hours < 0 ? -1 : 1)
                if let timezone = TimeZone(secondsFromGMT: seconds) {
                    let outputFormatter = DateFormatter()
                    outputFormatter.dateFormat = "MMM d, h:mm a"
                    outputFormatter.timeZone = timezone
                    return outputFormatter.string(from: date)
                }
            }
        }
        
        // Fallback: display in original timezone
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d, h:mm a"
        return outputFormatter.string(from: date)
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
                            
                            if let depAirport = currentFlight.fullData?.departure?.airport?.name {
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
                            
                            if let arrAirport = currentFlight.fullData?.arrival?.airport?.name {
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
                    if let location = currentFlight.fullData?.location,
                       let lat = location.lat,
                       let lon = location.lon {
                        LiveTrackingMapView(
                            location: location,
                            flightNumber: currentFlight.flightNumber,
                            departure: currentFlight.fullData?.departure?.airport,
                            arrival: currentFlight.fullData?.arrival?.airport,
                            timeUntilLanding: currentFlight.fullData?.timeUntilLanding
                        )
                    }
                    
                    // Departure Info
                    if let departure = currentFlight.fullData?.departure {
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
                            if let scheduled = formatTimeClean(departure.scheduledTime?.local) {
                                InfoRow(label: "Scheduled", value: scheduled)
                            }
                            if let revised = formatTimeClean(departure.revisedTime?.local) {
                                InfoRow(label: "Revised", value: revised, valueColor: .orange)
                            }
                            if let runway = formatTimeClean(departure.runwayTime?.local) {
                                InfoRow(label: "Runway Time", value: runway, valueColor: .green)
                            }
                        }
                    }
                    
                    // Arrival Info
                    if let arrival = currentFlight.fullData?.arrival {
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
                            if let scheduled = formatTimeClean(arrival.scheduledTime?.local) {
                                InfoRow(label: "Scheduled", value: scheduled)
                            }
                            if let predicted = formatTimeClean(arrival.predictedTime?.local) {
                                InfoRow(label: "Predicted", value: predicted, valueColor: .blue)
                            }
                        }
                    }
                    
                    // Flight Info
                    InfoSection(title: "Flight Information", icon: "info.circle") {
                        if let callSign = currentFlight.fullData?.callSign {
                            InfoRow(label: "Call Sign", value: callSign)
                        }
                        
                        if let aircraft = currentFlight.fullData?.aircraft {
                            if let model = aircraft.model {
                                InfoRow(label: "Aircraft", value: model)
                            }
                            if let reg = aircraft.reg {
                                InfoRow(label: "Registration", value: reg)
                            }
                        }
                        
                        if let distance = currentFlight.fullData?.greatCircleDistance {
                            if let miles = distance.mile {
                                InfoRow(label: "Distance", value: String(format: "%.0f miles", miles))
                            }
                        }
                        
                        if let codeshareStatus = currentFlight.fullData?.codeshareStatus {
                            InfoRow(label: "Codeshare", value: codeshareStatus)
                        }
                        
                        if let updated = currentFlight.fullData?.lastUpdatedUtc {
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
                                onSave { success in
                                    if success {
                                        isSaved = true
                                    }
                                }
                            }) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .onDisappear {
                // Request review after closing a search result detail for the first time
                // But NOT if it was dismissed programmatically for paywall
                if onSave != nil { // Only for search results, not saved flights
                    let hasRequestedReview = UserDefaults.standard.bool(forKey: "hasRequestedReview")
                    let dismissedForPaywall = UserDefaults.standard.bool(forKey: "dismissedForPaywall")
                    
                    if !hasRequestedReview && !dismissedForPaywall {
                        // Small delay to ensure the sheet is fully dismissed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                SKStoreReviewController.requestReview(in: windowScene)
                                UserDefaults.standard.set(true, forKey: "hasRequestedReview")
                                print("⭐ Requested App Store review")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func refreshFlight() {
        // Use savedDate if available, otherwise extract from local departure time
        let date: String
        if let savedDate = savedDate {
            date = savedDate
        } else {
            // Extract from local departure time
            guard let departureLocal = currentFlight.fullData?.departure?.scheduledTime?.local,
                  let extractedDate = departureLocal.components(separatedBy: " ").first else {
                print("Cannot refresh: no local departure time")
                return
            }
            date = extractedDate
        }
        
        isRefreshing = true
        
        Task {
            do {
                print("🔄 Refreshing flight \(currentFlight.flightNumber) on \(date)")
                let flightDataArray = try await FlightAPIService.shared.searchFlight(
                    flightNumber: currentFlight.flightNumber,
                    date: date,
                    single: true  // Only get the flight matching departure date
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
    let timeUntilLanding: TimeUntilLanding?
    
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
            // Time Until Landing Banner (if available)
            if let timeUntil = timeUntilLanding, let message = timeUntil.message {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Time Until Landing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Text(message)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
            }
            
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

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onUpgrade: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                // Subscription Section
                Section {
                    if subscriptionManager.hasActiveSubscription {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 24))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Premium Active")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Thank you for subscribing!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button(action: onUpgrade) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 24))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upgrade to Premium")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("Unlock unlimited flight tracking")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Subscription")
                }
                
                // Support Section
                Section {
                    Button(action: {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: windowScene)
                            print("⭐ Rate app button tapped")
                        }
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 20))
                            
                            Text("Rate App")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                } header: {
                    Text("Support")
                }
                
                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
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
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Paging content
                TabView(selection: $currentPage) {
                    // Slide 1 - Track Live Flights
                    OnboardingSlide(
                        imageName: "IMG_1949",
                        title: "Track Live Flights",
                        description: "Follow flights in real-time with live location tracking, altitude, speed, and flight path visualization."
                    )
                    .tag(0)
                    
                    // Slide 2 - Save & Monitor
                    OnboardingSlide(
                        imageName: "IMG_1950",
                        title: "Save & Monitor Flights",
                        description: "Save your favorite flights and check their status anytime. Get updates on departures, arrivals, and delays."
                    )
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Continue/Get Started button
                Button(action: {
                    if currentPage == 0 {
                        withAnimation {
                            currentPage = 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage == 0 ? "Continue" : "Get Started")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        isPresented = false
        // Small delay before showing paywall
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }
}

struct OnboardingSlide: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            // Image placeholder (will show the actual images)
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 40)
            } else {
                // Fallback icon if image not found
                Image(systemName: "airplane.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    ContentView()
}
