import StoreKit
import SwiftUI
import FirebaseAnalytics

// MARK: - Subscription Product IDs
enum SubscriptionTier: String, CaseIterable {
    case weekly = "subscription.airplanetrackerpro.weekly"
    case yearly = "subscription.airplanetrackerpro.yearly"
    
    var displayName: String {
        switch self {
        case .weekly:
            return "3-Day Trial"
        case .yearly:
            return "Yearly Plan"
        }
    }
    
    var description: String {
        return "Full access to track and save flights"
    }
}

// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    // Singleton instance for app-wide access
    static let shared = SubscriptionManager()
    
    // Published properties for UI updates
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // Transaction listener
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        // Start listening for transactions when initialized
        updateListenerTask = listenForTransactions()
        
        // Load available products and restore purchases on init
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    @MainActor
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get product IDs from our enum
            let productIDs = SubscriptionTier.allCases.map { $0.rawValue }
            
            // Request products from the App Store
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort products with yearly first, then weekly
            products = storeProducts.sorted { product1, product2 in
                if product1.id == SubscriptionTier.yearly.rawValue {
                    return true
                } else if product2.id == SubscriptionTier.yearly.rawValue {
                    return false
                } else {
                    return product1.price < product2.price
                }
            }
            
            if products.isEmpty {
                errorMessage = "No subscription products found."
                print("⚠️ No products loaded for IDs: \(productIDs)")
            } else {
                print("✅ Successfully loaded \(products.count) products: \(products.map { $0.id })")
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ Product loading error: \(error)")
        }
    }
    
    // MARK: - Subscription Status
    
    @MainActor
    func updateSubscriptionStatus() async {
        // Clear existing subscriptions
        purchasedSubscriptions.removeAll()
        
        // Get the latest transaction for each product
        for await result in StoreKit.Transaction.currentEntitlements {
            // Check if transaction is verified
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Find matching product
            if let product = products.first(where: { $0.id == transaction.productID }),
               !purchasedSubscriptions.contains(where: { $0.id == product.id }) {
                purchasedSubscriptions.append(product)
                print("🔒 Found active subscription: \(product.id)")
            }
        }
        
        print("📱 Subscription status updated: \(hasActiveSubscription)")
    }
    
    // MARK: - Purchase Functionality
    
    @MainActor
    func purchase(_ product: Product) async throws {
        // Begin purchasing process
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Submit payment for the product
            let result = try await product.purchase()
            
            // Check if purchase was successful
            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                guard case .verified(let transaction) = verification else {
                    errorMessage = "Transaction verification failed."
                    return
                }
                
                // Add to purchased subscriptions
                if !purchasedSubscriptions.contains(where: { $0.id == product.id }) {
                    purchasedSubscriptions.append(product)
                }
                
                // Finish the transaction
                await transaction.finish()
                
                // Log successful purchase
                Analytics.logEvent("subscription_purchased", parameters: [
                    "product_id": product.id,
                    "price": product.displayPrice
                ])
                
            case .userCancelled:
                break // User cancelled - no action needed
                
            case .pending:
                errorMessage = "Purchase is pending approval."
                
            default:
                errorMessage = "Purchase failed with unknown status."
            }
        } catch {
            errorMessage = "Failed to make purchase: \(error.localizedDescription)"
            print("Purchase error: \(error)")
            throw error
        }
    }
    
    @MainActor
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Attempt to sync app receipt with App Store
            try await AppStore.sync()
            
            // Update subscription status to reflect restored purchases
            await updateSubscriptionStatus()
            
            if purchasedSubscriptions.isEmpty {
                errorMessage = "No purchases to restore."
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("Restore error: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transactions from App Store
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    // Update UI from main thread
                    await self.handle(transaction: transaction)
                    
                    // Finish the transaction
                    await transaction.finish()
                }
            }
        }
    }
    
    @MainActor
    private func handle(transaction: StoreKit.Transaction) async {
        // Update subscription status when a transaction comes in
        if let product = products.first(where: { $0.id == transaction.productID }),
           !purchasedSubscriptions.contains(where: { $0.id == product.id }) {
            purchasedSubscriptions.append(product)
            print("🔄 Transaction handled for: \(product.id)")
        }
    }
    
    // Check if user has any active subscription
    var hasActiveSubscription: Bool {
        !purchasedSubscriptions.isEmpty
    }
    
    // Get the product for a specific tier
    func product(for tier: SubscriptionTier) -> Product? {
        products.first(where: { $0.id == tier.rawValue })
    }
    
    // Format price for display
    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }
    
    // Clear error message
    func clearErrorMessage() {
        errorMessage = nil
    }
} 
