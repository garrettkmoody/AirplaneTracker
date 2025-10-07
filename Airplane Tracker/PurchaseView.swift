// PurchaseView SwiftUI
// Created by Adam Lyttle on 7/18/2024

// Make cool stuff and share your build with me:

//  --> x.com/adamlyttleapps
//  --> github.com/adamlyttleapps

// Special thanks:

//  --> Mario (https://x.com/marioapps_com) for recommending changes to fix
//      an issue Apple had rejecting the paywall due to excessive use of
//      the word "FREE"

import SwiftUI
import FirebaseAnalytics

struct PurchaseView: View {
    
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    @State private var shakeDegrees = 0.0
    @State private var shakeZoom = 0.9
    @State private var showCloseButton = false
    @State private var progress: CGFloat = 0.0

    @Binding var isPresented: Bool
    
    @State var showNoneRestoredAlert: Bool = false
    @State private var showTermsActionSheet: Bool = false

    @State private var freeTrial: Bool = true
    @State private var selectedProductId: String = ""
    
    let color: Color = Color.blue
    
    private let allowCloseAfter: CGFloat = 5.0 //time in seconds until close is allows
    
    var hasCooldown: Bool = true
    

    
    var callToActionText: String {
        if let selectedProduct = subscriptionManager.products.first(where: { $0.id == selectedProductId }) {
            // Check if it's the weekly subscription (which has the trial)
            if selectedProductId == SubscriptionTier.weekly.rawValue {
                return "Start Free Trial"
            } else {
                return "Unlock Now"
            }
        }
        return "Unlock Now"
    }
    
    var calculateFullPrice: Double? {
        if let weeklyProduct = subscriptionManager.products.first(where: { $0.id == SubscriptionTier.weekly.rawValue }) {
            return NSDecimalNumber(decimal: weeklyProduct.price).doubleValue * 52 // 52 weeks in a year
        }
        return nil
    }
    
    var calculatePercentageSaved: Int {
        if let calculateFullPrice = calculateFullPrice,
           let yearlyProduct = subscriptionManager.products.first(where: { $0.id == SubscriptionTier.yearly.rawValue }) {
            
            let yearlyPrice = NSDecimalNumber(decimal: yearlyProduct.price).doubleValue
            let saved = Int(100 - ((yearlyPrice / calculateFullPrice) * 100))
            
            if saved > 0 {
                return saved
            }
        }
        return 90
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let isShortScreen = screenHeight < 700
            let spacing: CGFloat = isShortScreen ? 12 : 20
            let imageHeight: CGFloat = isShortScreen ? 100 : 140
            
            ZStack (alignment: .top) {
                
                HStack {
                    Spacer()
                    
                    if hasCooldown && !showCloseButton {
                        Circle()
                            .trim(from: 0.0, to: progress)
                            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .opacity(0.1 + 0.1 * self.progress)
                            .rotationEffect(Angle(degrees: -90))
                            .frame(width: 20, height: 20)
                            .foregroundColor(.blue)
                    }
                    else {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                }
                .padding(.top, 50)
                .padding(.trailing, 20)

                VStack (spacing: spacing) {
                
                ZStack {
                    // Plane icon with blue background circle
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: imageHeight, height: imageHeight)
                            .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "airplane")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: imageHeight * 0.5)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-45)) // Tilt the plane
                    }
                    .scaleEffect(shakeZoom)
                    .rotationEffect(.degrees(shakeDegrees))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            startShaking()
                        }
                    }
                }
                
                VStack (spacing: isShortScreen ? 6 : 10) {
                    Text("Track Unlimited Flights")
                        .font(.system(size: isShortScreen ? 24 : 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.bottom, isShortScreen ? 4 : 8)
                    
                    VStack (alignment: .leading) {
                        PurchaseFeatureView(title: "Track unlimited flights worldwide", icon: "airplane", color: color)
                        PurchaseFeatureView(title: "Real-time flight location & status", icon: "location.fill", color: color)
                        PurchaseFeatureView(title: "Save and monitor multiple flights", icon: "bookmark.fill", color: color)
                    }
                    .font(.system(size: isShortScreen ? 16 : 19))
                    .padding(.top, isShortScreen ? 8 : 16)
                }
                
                if !isShortScreen {
                    Spacer()
                }
                
                VStack (spacing: isShortScreen ? 16 : 20) {
                    VStack (spacing: 10) {
                        
                        let products = subscriptionManager.isLoading ? [] : subscriptionManager.products
                        
                        ForEach(products, id: \.id) { product in
                            
                            Button(action: {
                                withAnimation {
                                    selectedProductId = product.id
                                }
                                self.freeTrial = (product.id == SubscriptionTier.weekly.rawValue)
                            }) {
                                VStack {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            let tier = SubscriptionTier.allCases.first { $0.rawValue == product.id }
                                            Text(tier?.displayName ?? "Subscription")
                                                .font(.headline.bold())
                                            if product.id == SubscriptionTier.weekly.rawValue {
                                                Text("then \(product.displayPrice) per week")
                                                    .opacity(0.8)
                                            }
                                            else {
                                                HStack (spacing: 0) {
                                                    if let calculateFullPrice = calculateFullPrice, //round down
                                                       let calculateFullPriceLocalCurrency = toLocalCurrencyString(calculateFullPrice),
                                                       calculateFullPrice > 0
                                                    {
                                                        //shows the full price based on weekly calculaation
                                                        Text("\(calculateFullPriceLocalCurrency) ")
                                                            .strikethrough()
                                                            .opacity(0.4)
                                                        
                                                    }
                                                    Text(" \(product.displayPrice) per year")
                                                }
                                                .opacity(0.8)
                                            }
                                        }
                                        Spacer()
                                        if product.id == SubscriptionTier.weekly.rawValue {
                                            //removed: Some apps were being rejected with this caption present:
                                            /*Text("FREE")
                                                .font(.title2.bold())*/
                                        }
                                        else {
                                            VStack {
                                                Text("SAVE \(calculatePercentageSaved)%")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                            }
                                            .background(Color.red)
                                            .cornerRadius(6)
                                        }
                                        
                                        ZStack {
                                            Image(systemName: (selectedProductId == product.id) ? "circle.fill" : "circle")
                                                .foregroundColor((selectedProductId == product.id) ? color : Color.primary.opacity(0.15))
                                            
                                            if selectedProductId == product.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(Color.white)
                                                    .scaleEffect(0.7)
                                            }
                                        }
                                        .font(.title3.bold())
                                        
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }
                                //.background(Color(.systemGray4))
                                .cornerRadius(6)
                                .overlay(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke((selectedProductId == product.id) ? color : Color.primary.opacity(0.15), lineWidth: 1) // Border color and width
                                        RoundedRectangle(cornerRadius: 6)
                                            .foregroundColor((selectedProductId == product.id) ? color.opacity(0.05) : Color.primary.opacity(0.001))
                                    }
                                )
                            }
                            .accentColor(Color.primary)
                            
                        }
                        
                        HStack {
                            Toggle(isOn: $freeTrial) {
                                Text("Free Trial Enabled")
                                    .font(.headline.bold())
                            }
                            .tint(.blue)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .onChange(of: freeTrial) { freeTrial in
                                if !freeTrial {
                                    // Select yearly plan when trial is disabled
                                    withAnimation {
                                        self.selectedProductId = SubscriptionTier.yearly.rawValue
                                    }
                                }
                                else if freeTrial {
                                    // Select weekly plan when trial is enabled
                                    withAnimation {
                                        self.selectedProductId = SubscriptionTier.weekly.rawValue
                                    }
                                }
                            }
                        }
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                        
                    }
                    .opacity(subscriptionManager.isLoading ? 0 : 1)
                    
                    VStack (spacing: 25) {
                        
                        ZStack (alignment: .center) {
                            
                            //if purchasedModel.isPurchasing {
                            ProgressView()
                                .opacity(subscriptionManager.isLoading ? 1 : 0)
                            
                            Button(action: {
                                if !subscriptionManager.isLoading {
                                    // Log subscription button click
                                    Analytics.logEvent("subscription_button_clicked", parameters: [
                                        "product_id": selectedProductId,
                                        "button_text": callToActionText
                                    ])
                                    
                                    if let product = subscriptionManager.products.first(where: { $0.id == selectedProductId }) {
                                        Task {
                                            do {
                                                try await subscriptionManager.purchase(product)
                                            } catch {
                                                print("Purchase failed: \(error)")
                                            }
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    HStack {
                                        Text(callToActionText)
                                        Image(systemName: "chevron.right")
                                    }
                                    Spacer()
                                }
                                .padding()
                                .foregroundColor(.white)
                                .font(.title3.bold())
                            }
                            .background(color)
                            .cornerRadius(6)
                            .opacity(subscriptionManager.isLoading ? 0 : 1)
                            .padding(.top)
                            .padding(.bottom, 4)
                            
                            
                        }
                        
                    }
                    .opacity(subscriptionManager.isLoading ? 0 : 1)
                }
                .id("view-\(subscriptionManager.isLoading)")
                .background {
                    if subscriptionManager.isLoading {
                        ProgressView()
                    }
                }
                
                VStack (spacing: 5) {
                    
                    /*HStack (spacing: 4) {
                        Image(systemName: "figure.2.and.child.holdinghands")
                            .foregroundColor(Color.red)
                        Text("Family Sharing enabled")
                            .foregroundColor(.white)
                    }
                    .font(.footnote)*/
                    
                    HStack (spacing: 10) {
                        
                        Button("Restore") {
                            Task {
                                await subscriptionManager.restorePurchases()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    if !subscriptionManager.hasActiveSubscription {
                                        showNoneRestoredAlert = true
                                    }
                                }
                            }
                        }
                        .alert(isPresented: $showNoneRestoredAlert) {
                            Alert(title: Text("Restore Purchases"), message: Text("No purchases restored"), dismissButton: .default(Text("OK")))
                        }
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray), alignment: .bottom
                        )
                        .font(.footnote)
                        
                        
                        Button("Terms of Use & Privacy Policy") {
                            showTermsActionSheet = true
                        }
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray), alignment: .bottom
                        )
                        .actionSheet(isPresented: $showTermsActionSheet) {
                            ActionSheet(title: Text("View Terms & Conditions"), message: nil,
                                        buttons: [
                                            .default(Text("Terms of Use"), action: {
                                                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }),
                                            .default(Text("Privacy Policy"), action: {
                                                if let url = URL(string: "https://appsupportpages.web.app/airplane-tracker/privacy") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }),
                                            .cancel()
                                        ])
                        }
                        .font(.footnote)
                        
                        
                    }
                    //.font(.headline)
                    .foregroundColor(.gray)
                    .font(.system(size: 15))
                    
                    
                    
                    
                }

                
                }
                .padding(.top, isShortScreen ? 40 : 50)
                .padding(.bottom, geometry.safeAreaInsets.bottom + (isShortScreen ? 16.0 : 20.0))
            }
        }
        .padding(.horizontal)
        .onAppear {
            selectedProductId = SubscriptionTier.weekly.rawValue // Default to weekly (trial)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeIn(duration: allowCloseAfter)) {
                    self.progress = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + allowCloseAfter) {
                    withAnimation {
                        showCloseButton = true
                    }
                }
            }
        }
        .onChange(of: subscriptionManager.hasActiveSubscription) { isSubscribed in
            if(isSubscribed) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPresented = false
                }
            }
        }
        .onAppear {
            if(subscriptionManager.hasActiveSubscription) {
                isPresented = false
            }
        }
        
        
    }
    
    private func startShaking() {
            let totalDuration = 0.7 // Total duration of the shake animation
            let numberOfShakes = 3 // Total number of shakes
            let initialAngle: Double = 10 // Initial rotation angle
            
            withAnimation(.easeInOut(duration: totalDuration / 2)) {
                self.shakeZoom = 0.95
                DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration / 2) {
                    withAnimation(.easeInOut(duration: totalDuration / 2)) {
                        self.shakeZoom = 0.9
                    }
                }
            }

            for i in 0..<numberOfShakes {
                let delay = (totalDuration / Double(numberOfShakes)) * Double(i)
                let angle = initialAngle - (initialAngle / Double(numberOfShakes)) * Double(i)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(Animation.easeInOut(duration: totalDuration / Double(numberOfShakes * 2))) {
                        self.shakeDegrees = angle
                    }
                    withAnimation(Animation.easeInOut(duration: totalDuration / Double(numberOfShakes * 2)).delay(totalDuration / Double(numberOfShakes * 2))) {
                        self.shakeDegrees = -angle
                    }
                }
            }

            // Stop the shaking and reset to 0
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
                withAnimation {
                    self.shakeDegrees = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    startShaking()
                }
            }
        }
    
    
    struct PurchaseFeatureView: View {
        
        let title: String
        let icon: String
        let color: Color
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 27, height: 27, alignment: .center)
                .clipped()
                .foregroundColor(color)
                Text(title)
            }
        }
    }

    func toLocalCurrencyString(_ value: Double) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        //formatter.locale = locale
        return formatter.string(from: NSNumber(value: value))
    }

}

#Preview {
    PurchaseView(subscriptionManager: SubscriptionManager.shared, isPresented: .constant(true))
}
