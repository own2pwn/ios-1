import Foundation
import TonSwift

public enum Deeplink {
  case tonsign(TonsignDeeplink)
}

public struct TonSignModel {
  public let publicKey: TonSwift.PublicKey
  public let body: String
  public let returnURL: String?
  public let version: String?
  public let network: String?
}

public enum TonsignDeeplink {
  case plain
  case sign(TonSignModel)
  
  
}

//public enum Deeplink {
//  case ton(TonDeeplink)
//  case tonConnect(TonConnectDeeplink)
//  
//  public var string: String {
//    switch self {
//    case .ton(let tonDeeplink):
//      return tonDeeplink.string
//    case .tonConnect(let tonConnectDeeplink):
//      return tonConnectDeeplink.string
//    }
//  }
//}
//
//public enum TonDeeplink {
//  case transfer(recipient: String, jettonAddress: Address?)
//  
//  public var string: String {
//    let ton = "ton"
//    switch self {
//    case let .transfer(recipient, jettonAddress):
//      var components = URLComponents(string: ton)
//      components?.scheme = ton
//      components?.host = "transfer"
//      components?.path = "/\(recipient)"
//      if let jettonAddress {
//        components?.queryItems = [URLQueryItem(name: "jetton", value: jettonAddress.toRaw())]
//      }
//      return components?.string ?? ""
//    }
//  }
//}
//
//public struct TonConnectDeeplink {
//  let string: String
//}
