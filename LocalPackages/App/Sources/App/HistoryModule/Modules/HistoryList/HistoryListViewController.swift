import UIKit
import TKUIKit
import TKCoordinator

final class HistoryListViewController: GenericViewViewController<HistoryListView>, ScrollViewController {

  private var collectionController: HistoryListCollectionController!
  private var headerViewController: UIViewController?
  
  private let viewModel: HistoryListViewModel
  
  init(viewModel: HistoryListViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    collectionController = HistoryListCollectionController(collectionView: customView.collectionView, headerViewProvider: { [weak self] in
      self?.headerViewController?.view
    })
    
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  func setHeaderViewController(_ headerViewController: UIViewController?) {
    self.headerViewController?.willMove(toParent: nil)
    self.headerViewController?.removeFromParent()
    self.headerViewController?.didMove(toParent: nil)
    self.headerViewController = headerViewController
    if let headerViewController = headerViewController {
      addChild(headerViewController)
    }
    headerViewController?.didMove(toParent: self)
    customView.collectionView.reloadData()
  }
  
  func scrollToTop() {
    guard scrollView.contentOffset.y > scrollView.adjustedContentInset.top else { return }
    scrollView.setContentOffset(
      CGPoint(x: 0,
              y: -scrollView.adjustedContentInset.top),
      animated: true
    )
  }
}

private extension HistoryListViewController {
  func setupBindings() {
    viewModel.didUpdateHistory = { [weak collectionController] sections in
      collectionController?.setSections(sections)
    }
    
    viewModel.didStartPagination = { [weak collectionController] pagination in
      collectionController?.showPagination(pagination)
    }
    
    viewModel.didStartLoading = { [weak collectionController] in
      collectionController?.showShimmer()
    }
    
    collectionController.loadNextPage = { [weak viewModel] in 
      viewModel?.loadNext()
    }
  }
}
