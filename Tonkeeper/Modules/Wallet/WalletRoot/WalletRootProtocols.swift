//
//  WalletRootProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 24.5.23..
//

import Foundation
import WalletCore

protocol WalletRootModuleOutput: AnyObject {
  func openQRScanner()
  func openSend(address: String?)
  func openReceive(address: String)
  func openBuy()
  func didSelectItem(_ item: WalletItemViewModel)
}

protocol WalletRootPresenterInput {
  func viewDidLoad()
  func didPullToRefresh()
}

protocol WalletRootViewInput: AnyObject {
  func didFinishLoading()
}
