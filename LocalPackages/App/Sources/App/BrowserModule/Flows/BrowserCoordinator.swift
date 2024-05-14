import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class BrowserCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.browser
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.explore
  }
  
  public override func start() {
    openBrowser()
  }
}

private extension BrowserCoordinator {
  func openBrowser() {
    let module = BrowserAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly)
    
    module.output.didTapSearch = { [weak self] in
      self?.openSearch()
    }
    
    module.output.didSelectCategory = { [weak self] category in
      self?.openCategory(category)
    }
    
    module.output.didSelectApp = { [weak self] app in
      self?.openApp(app)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCategory(_ category: PopularAppsCategory) {
    let module = BrowserCategoryAssembly.module(category: category)
    
    module.output.didSelectApp = { [weak self] app in
      self?.openApp(app)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func openApp(_ app: PopularApp) {
    let messageHandler = DefaultDappMessageHandler()
    let module = DappAssembly.module(app: app, messageHandler: messageHandler)
    
    messageHandler.connect = { [weak self, weak moduleView = module.view] protocolVersion, payload, completion in
      guard let moduleView else { 
        completion(.error(.unknownError))
        return
      }
      self?.performConnect(
        protocolVersion: protocolVersion,
        payload: payload,
        fromViewController: moduleView,
        completion: completion)
    }
    
    messageHandler.reconnect = {
      [weak self] app,
      completion in
      guard let self else { return }
      let wallet = self.keeperCoreMainAssembly.walletAssembly.walletStore.activeWallet
      let result = self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.reconnectBridgeDapp(
        wallet: wallet,
        appUrl: app.url
      )
      completion(result)
    }
    
    messageHandler.disconnect = {
      [weak self] app in
      guard let self else { return }
      let wallet = self.keeperCoreMainAssembly.walletAssembly.walletStore.activeWallet
      try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.disconnect(wallet: wallet, appUrl: app.url)
    }
    
    messageHandler.send = {
      [weak self] app, request, completion in
      guard let self else { return }
      self.openSend(app: app, appRequest: request, completion: completion)
    }

    module.view.modalPresentationStyle = .fullScreen
    router.present(module.view)
  }
  
  func openSearch() {
    
  }
  
  func performConnect(protocolVersion: Int,
                      payload: TonConnectRequestPayload,
                      fromViewController: UIViewController,
                      completion: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let manifest = try await keeperCoreMainAssembly.tonConnectAssembly.tonConnectService().loadManifest(
          url: payload.manifestUrl
        )
        let parameters = TonConnectParameters(
          version: .v2,
          clientId: UUID().uuidString,
          requestPayload: payload
        )
        await MainActor.run {
          ToastPresenter.hideToast()
          handleLoadedManifest(
            parameters: parameters,
            manifest: manifest,
            router: ViewControllerRouter(rootViewController: fromViewController),
            completion: completion
          )
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideToast()
          completion(.error(.appManifestNotFound))
        }
      }
    }
    
    @Sendable
    func handleLoadedManifest(parameters: TonConnectParameters,
                              manifest: TonConnectManifest,
                              router: ViewControllerRouter,
                              completion: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
      let connector = BridgeTonConnectConnectCoordinatorConnector(
        tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore) {
          completion($0)
        }
      let coordinator = TonConnectConnectCoordinator(
        router: router,
        connector: connector,
        parameters: parameters,
        manifest: manifest,
        showWalletPicker: false,
        coreAssembly: coreAssembly,
        keeperCoreMainAssembly: keeperCoreMainAssembly
      )
      
      coordinator.didCancel = { [weak self, weak coordinator] in
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }
      
      coordinator.didConnect = { [weak self, weak coordinator] in
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      }
      
      addChild(coordinator)
      coordinator.start()
    }
  }
  
  func openSend(app: PopularApp,
                appRequest: TonConnect.AppRequest,
                completion: @escaping (TonConnectAppsStore.SendTransactionResult) -> Void) {
    let wallet = self.keeperCoreMainAssembly.walletAssembly.walletStore.activeWallet
    guard let connectedApps = try? self.keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore.connectedApps(forWallet: wallet),
          let connectedApp = connectedApps.apps.first(where: { $0.manifest.host == app.url?.host }) else {
      completion(.error(.unknownApp))
      return
    }
    
    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    let coordinator = TonConnectConfirmationCoordinator(
      router: WindowRouter(window: window),
      wallet: wallet,
      appRequest: appRequest,
      app: connectedApp,
      confirmator: BridgeTonConnectConfirmationCoordinatorConfirmator(
        sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
        tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService(),
        connectionResponseHandler: { result in
          completion(result)
        }
      ),
      tonConnectConfirmationController: keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmationController(
        wallet: wallet,
        appRequest: appRequest,
        app: connectedApp
      ),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
