import Foundation
import TonSwift
import BigInt

public final class SendV3Controller {
  
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let knownAccountsStore: KnownAccountsStore
  private let dnsService: DNSService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let amountFormatter: AmountFormatter
  
  init(walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       knownAccountsStore: KnownAccountsStore,
       dnsService: DNSService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       amountFormatter: AmountFormatter) {
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.knownAccountsStore = knownAccountsStore
    self.dnsService = dnsService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.amountFormatter = amountFormatter
  }
  
  public func resolveRecipient(input: String) async -> Recipient? {
    let knownAccounts: [KnownAccount]
    do {
      knownAccounts = try await knownAccountsStore.getKnownAccounts()
    } catch {
      knownAccounts = []
    }
    
    if let friendlyAddress = try? FriendlyAddress(string: input) {
      return (Recipient(recipientAddress: .friendly(friendlyAddress),
                        isMemoRequired: knownAccounts.first(where: { $0.address == friendlyAddress.address })?.requireMemo ?? false))
    } else if let rawAddress = try? Address.parse(input) {
      return (Recipient(recipientAddress: .raw(rawAddress),
                        isMemoRequired: knownAccounts.first(where: { $0.address == rawAddress })?.requireMemo ?? false))
    } else if let domain = try? await dnsService.resolveDomainName(
      input,
      isTestnet: walletsStore.activeWallet.isTestnet) {
      return Recipient(recipientAddress: .domain(domain),
                       isMemoRequired: knownAccounts.first(where: { $0.address == domain.friendlyAddress.address })?.requireMemo ?? false)
    } else {
      return nil
    }
  }
  
  public func convertInputStringToAmount(input: String, targetFractionalDigits: Int) -> (amount: BigUInt, fractionalDigits: Int) {
    guard !input.isEmpty else { return (0, targetFractionalDigits) }
    let fractionalSeparator: String = .fractionalSeparator ?? ""
    let components = input.components(separatedBy: fractionalSeparator)
    guard components.count < 3 else {
      return (0, targetFractionalDigits)
    }
    
    var fractionalDigits = 0
    if components.count == 2 {
        let fractionalString = components[1]
        fractionalDigits = fractionalString.count
    }
    let zeroString = String(repeating: "0", count: max(0, targetFractionalDigits - fractionalDigits))
    let bigIntValue = BigUInt(stringLiteral: components.joined() + zeroString)
    return (bigIntValue, targetFractionalDigits)
  }
  
  public func convertAmountToInputString(amount: BigUInt, token: Token) -> String {
    let tokenFractionDigits: Int
    switch token {
    case .ton:
      tokenFractionDigits = TonInfo.fractionDigits
    case .jetton(let jettonItem):
      tokenFractionDigits = jettonItem.jettonInfo.fractionDigits
    }
    let formatted = amountFormatter.formatAmount(
      amount,
      fractionDigits: tokenFractionDigits,
      maximumFractionDigits: tokenFractionDigits
    )
    return formatted
  }
  
  public func isAmountAvailableToSend(amount: BigUInt, token: Token) async -> Bool {
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        return BigUInt(balance.walletBalance.balance.tonBalance.amount) >= amount
      case .jetton(let jettonItem):
        let jettonBalanceAmount = balance.walletBalance.balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo })?.quantity ?? 0
        return jettonBalanceAmount >= amount
      }
    } catch {
      return false
    }
  }
  
  public func convertTokenAmountToCurrency(token: Token, _ amount: BigUInt) async -> String {
    guard !amount.isZero else { return "" }
    let currency = await currencyStore.getActiveCurrency()
    switch token {
    case .ton:
      guard let rate = await tonRatesStore.getTonRates().first(where: { $0.currency == currency }) else { return ""}
      let converted = RateConverter().convert(amount: amount, amountFractionLength: TonInfo.fractionDigits, rate: rate)
      let formatted = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
      return "≈ \(formatted)"
    case .jetton(let jettonItem):
      let wallet = walletsStore.activeWallet
      do {
        let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
        guard let jettonBalance = balance.walletBalance.balance.jettonsBalance.first(where: {
          $0.item.jettonInfo == jettonItem.jettonInfo
        }) else { return "" }
        
        guard let rate = jettonBalance.rates[currency] else { return ""}
        let converted = RateConverter().convert(amount: amount, amountFractionLength: jettonItem.jettonInfo.fractionDigits, rate: rate)
        let formatted = amountFormatter.formatAmount(
          converted.amount,
          fractionDigits: converted.fractionLength,
          maximumFractionDigits: 2,
          currency: currency
        )
        return "≈ \(formatted)"
      } catch {
        return ""
      }
    }
  }
  
  public enum Remaining {
    case insufficient
    case remaining(String)
  }
  public func calculateRemaining(token: Token, tokenAmount: BigUInt) async -> Remaining {
    let wallet = walletsStore.activeWallet
    let amount: BigUInt
    let tokenSymbol: String?
    let fractionalDigits: Int
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        amount = BigUInt(balance.walletBalance.balance.tonBalance.amount)
        fractionalDigits = TonInfo.fractionDigits
        tokenSymbol = TonInfo.symbol
      case .jetton(let jettonItem):
        amount = balance.walletBalance.balance.jettonsBalance.first(where: {
          $0.item.jettonInfo == jettonItem.jettonInfo
        })?.quantity ?? 0
        fractionalDigits = jettonItem.jettonInfo.fractionDigits
        tokenSymbol = jettonItem.jettonInfo.symbol
      }
    } catch {
      return .insufficient
    }
    
    if amount >= tokenAmount {
      let remainingAmount = amount - tokenAmount
      let formatted = amountFormatter.formatAmount(
        remainingAmount,
        fractionDigits: fractionalDigits,
        maximumFractionDigits: fractionalDigits,
        symbol: tokenSymbol
      )
      return .remaining(formatted)
    } else {
      return .insufficient
    }
  }
  
  public func getMaximumAmount(token: Token) async -> BigUInt {
    let wallet = walletsStore.activeWallet
    do {
      let balance = try await walletBalanceStore.getBalanceState(wallet: wallet)
      switch token {
      case .ton:
        return BigUInt(balance.walletBalance.balance.tonBalance.amount)
      case .jetton(let jettonItem):
        return balance.walletBalance.balance.jettonsBalance.first(where: {
          $0.item.jettonInfo == jettonItem.jettonInfo
        })?.quantity ?? 0
      }
    } catch {
      return .zero
    }
  }
}

private extension String {
  static let groupSeparator = " "
  static var fractionalSeparator: String? {
    Locale.current.decimalSeparator
  }
}
