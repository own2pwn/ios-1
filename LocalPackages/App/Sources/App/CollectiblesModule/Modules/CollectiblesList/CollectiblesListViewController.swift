import UIKit
import TKUIKit
import TKCoordinator

final class CollectiblesListViewController: GenericViewViewController<CollectiblesListView>, ScrollViewController {
  
  private var collectionController: CollectiblesListCollectionController!
  
  private let viewModel: CollectiblesListViewModel
  
  init(viewModel: CollectiblesListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = CollectiblesListCollectionController(
      collectionView: customView.collectionView
    )
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  func scrollToTop() {
    guard customView.collectionView.contentOffset.y > customView.collectionView.adjustedContentInset.top else { return }
    customView.collectionView.setContentOffset(
      CGPoint(x: 0,
              y: -customView.collectionView.adjustedContentInset.top),
      animated: true
    )
  }
}

private extension CollectiblesListViewController {
  func setupBindings() {
    viewModel.didUpdateSections = { [weak collectionController] sections in
      collectionController?.setSections(sections)
    }
    
    collectionController.loadNextPage = { [weak viewModel] in
      viewModel?.loadNext()
    }
    
    collectionController.didSelectNFT = { [weak viewModel] indexPath in
      viewModel?.didSelectNftAt(index: indexPath.item)
    }
  }
}
