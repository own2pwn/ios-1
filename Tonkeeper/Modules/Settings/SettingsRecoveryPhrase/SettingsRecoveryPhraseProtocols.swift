//
//  SettingsRecoveryPhraseProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 11.10.23..
//

import Foundation

protocol SettingsRecoveryPhraseModuleOutput: AnyObject {}

protocol SettingsRecoveryPhraseModuleInput: AnyObject {}

protocol SettingsRecoveryPhrasePresenterInput {
  func viewDidLoad()
}

protocol SettingsRecoveryPhraseViewInput: AnyObject {
  func update(with model: SettingsRecoveryPhraseView.Model)
}
