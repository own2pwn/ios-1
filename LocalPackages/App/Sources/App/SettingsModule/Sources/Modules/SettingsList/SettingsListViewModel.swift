import UIKit
import TKUIKit
import TKCore
import KeeperCore

public protocol SettingsListModuleOutput: AnyObject {
  var didTapEditWallet: ((Wallet) -> Void)? { get set }
}

protocol SettingsListViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateSettingsSections: (([SettingsListSection]) -> Void)? { get set }
  var didShowAlert: ((String, String?, [UIAlertAction]) -> Void)? { get set }
  var didSelectItem: ((IndexPath) -> Void)? { get set }
  
  func viewDidLoad()
  func selectItem(section: SettingsListSection, index: Int)
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell?
  func isHighlightableItem(section: SettingsListSection, index: Int) -> Bool
}

protocol SettingsListItemsProvider: AnyObject {
  var didUpdateSections: (() -> Void)? { get set }
  
  var title: String { get }
  
  func getSections() async -> [SettingsListSection]
  func selectItem(section: SettingsListSection, index: Int)
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell?
  func initialSelectedIndexPath() async -> IndexPath?
}

extension SettingsListItemsProvider {
  func initialSelectedIndexPath() async -> IndexPath? { nil }
}

final class SettingsListViewModelImplementation: SettingsListViewModel, SettingsListModuleOutput {
  
  // MARK: - SettingsListModuleOutput
  
  var didTapEditWallet: ((Wallet) -> Void)?
  
  // MARK: - SettingsListViewModel
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateSettingsSections: (([SettingsListSection]) -> Void)?
  var didShowAlert: ((String, String?, [UIAlertAction]) -> Void)?
  var didSelectItem: ((IndexPath) -> Void)?
  
  private var token: NSObjectProtocol?
  
  func viewDidLoad() {
    token = NotificationCenter.default.addObserver(forName: .didChangeThemeMode, object: nil, queue: .main, using: { [weak self] _ in
      guard let self = self else { return }
      Task {
        //      self?.viewDidLoad()
        let sections = await self.itemsProvider.getSections()
        let initialSelectedIndexPath = await self.itemsProvider.initialSelectedIndexPath()
        await MainActor.run {
          self.didUpdateSettingsSections?(sections)
          if let initialSelectedIndexPath = initialSelectedIndexPath {
            self.didSelectItem?(initialSelectedIndexPath)
          }
        }
      }
    })
    
    didUpdateTitle?(itemsProvider.title)
    
    itemsProvider.didUpdateSections = { [weak self] in
      guard let self = self else { return }
      Task {
        let sections = await self.itemsProvider.getSections()
        await MainActor.run {
          self.didUpdateSettingsSections?(sections)
        }
      }
    }
    
    Task {
      let sections = await itemsProvider.getSections()
      let initialSelectedIndexPath = await itemsProvider.initialSelectedIndexPath()
      await MainActor.run {
        didUpdateSettingsSections?(sections)
        if let initialSelectedIndexPath = initialSelectedIndexPath {
          didSelectItem?(initialSelectedIndexPath)
        }
      }
    }
  }
  
  func selectItem(section: SettingsListSection, index: Int) {
    switch section.items[index] {
    case let item as SettingsCell.Model:
      item.selectionHandler?()
    case _ as SettingsTextCell.Model:
      break
    default:
      itemsProvider.selectItem(section: section, index: index)
    }
  }
  
  func isHighlightableItem(section: SettingsListSection, index: Int) -> Bool {
    switch section.items[index] {
    case let item as SettingsCell.Model:
      return item.isHighlightable
    default:
      return true
    }
  }
  
  func cell(collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: AnyHashable) -> UICollectionViewCell? {
    itemsProvider.cell(collectionView: collectionView, indexPath: indexPath, itemIdentifier: itemIdentifier)
  }
  
  private let itemsProvider: SettingsListItemsProvider
  
  init(itemsProvider: SettingsListItemsProvider) {
    self.itemsProvider = itemsProvider
  }
}

