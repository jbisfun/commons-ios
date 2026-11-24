import SwiftUI

/// Fossify Commons' Donation model: a donation platform or a crypto address.
public struct Donation: Identifiable {
    public var name: String
    /// SF Symbol (stand-in for the platform logo).
    public var icon: String
    /// Website for platforms, address for cryptocurrencies.
    public var value: String
    /// Platform fee in percent; nil for cryptocurrencies.
    public var fee: Int?

    public var id: String { name }

    public init(name: String, icon: String, value: String, fee: Int? = nil) {
        self.name = name
        self.icon = icon
        self.value = value
        self.fee = fee
    }

    /// FossifyDonationPlatforms.
    public static let platforms = [
        Donation(name: "GitHub Sponsors", icon: "heart.circle", value: "https://github.com/sponsors/FossifyOrg", fee: 0),
        Donation(name: "Liberapay", icon: "hands.and.sparkles", value: "https://liberapay.com/naveensingh", fee: 0),
        Donation(name: "Open Collective", icon: "circle.dashed", value: "https://opencollective.com/fossify/donate?interval=month&amount=20", fee: 10),
        Donation(name: "Patreon", icon: "p.circle", value: "https://www.patreon.com/naveen3singh", fee: 10),
        Donation(name: "PayPal", icon: "creditcard", value: "https://paypal.me/naveen3singh", fee: 5),
    ]

    /// FossifyCryptoAddresses.
    public static let cryptos = [
        Donation(name: "Bitcoin (BTC)", icon: "bitcoinsign.circle", value: "bc1qn5h97qdqsazpzvxm7gryke6vmrcx85t7neqp95"),
        Donation(name: "Ethereum (ETH)", icon: "diamond", value: "0x9354fC372BC3BdA58766a8a9Fabadf77A76CdE01"),
        Donation(name: "Monero (XMR)", icon: "m.circle", value: "48FkVUcJ7AGeBMR4SC4J7QU5nAt6YNwKZWz6sGDT1s5haEY7reZtJr5CniXLaQzTzGAuZNoc83BQAcETHw1d3Lkn8AAf1XF"),
        Donation(name: "Tron (TRX)", icon: "t.circle", value: "TGi4VpD1D9A9ZvyP9d3aVowwzMSvev2hub"),
    ]
}

/// DonationActivity / DonationScreen: donation platforms (open, copy link) and
/// crypto addresses (copy).
public struct DonationView: View {
    @Environment(\.palette) private var palette
    @State private var toast: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Donate to Fossify")
            ScrollView {
                VStack(spacing: 0) {
                    Text("Platforms").sectionHeader(palette).padding(.leading, 40)
                    ForEach(Donation.platforms) { item in
                        row(item, description: item.fee == 0 ? "Little to no fee" : "Up to \(item.fee ?? 0)% fee") {
                            Launcher.open(URL(string: item.value))
                        }
                    }
                    Divider().overlay(palette.divider).padding(.top, 8)
                    Text("Cryptocurrency").sectionHeader(palette).padding(.leading, 40)
                    ForEach(Donation.cryptos) { item in
                        row(item, description: item.value) { toast = Launcher.copy(item.value) }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .toast($toast)
    }

    private func row(_ item: Donation, description: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(palette.textColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.system(size: 16)).foregroundStyle(palette.textColor)
                        Text(description).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { toast = Launcher.copy(item.value) } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 18))
                    .foregroundStyle(palette.primaryColor)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Copy to clipboard")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
    }
}
