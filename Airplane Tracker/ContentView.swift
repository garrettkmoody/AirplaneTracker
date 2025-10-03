//
//  ContentView.swift
//  Airplane Tracker
//
//  Created by Garrett Moody on 10/3/25.
//

import SwiftUI

struct Flight: Identifiable {
    let id = UUID()
    let flightNumber: String
    let airline: String
    let departure: String
    let arrival: String
    let status: String
    let statusColor: Color
}

struct ContentView: View {
    @State private var savedFlights: [Flight] = [
        Flight(flightNumber: "AA 1234", airline: "American Airlines", departure: "JFK", arrival: "LAX", status: "On Time", statusColor: .green),
        Flight(flightNumber: "DL 5678", airline: "Delta", departure: "ORD", arrival: "MIA", status: "Delayed", statusColor: .orange),
        Flight(flightNumber: "UA 9012", airline: "United", departure: "SFO", arrival: "SEA", status: "Boarding", statusColor: .blue)
    ]
    
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
                        // Search action
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
                                    ForEach(savedFlights) { flight in
                                        FlightCard(flight: flight)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .padding(.bottom, 0)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct FlightCard: View {
    let flight: Flight
    
    var body: some View {
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
            
            // Status badge
            Text(flight.status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(flight.statusColor)
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}
