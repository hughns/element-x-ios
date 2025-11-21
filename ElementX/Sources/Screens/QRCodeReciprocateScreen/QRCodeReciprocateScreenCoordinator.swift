//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct QRCodeReciprocateScreenCoordinatorParameters {
    let clientProxy: ClientProxyProtocol
    let orientationManager: OrientationManagerProtocol
    let appMediator: AppMediatorProtocol
    let appSettings: AppSettings
    let presentationAnchor: UIWindow
}

enum QRCodeReciprocateScreenCoordinatorAction {
    case cancel
    case done
}

final class QRCodeReciprocateScreenCoordinator: CoordinatorProtocol {
    private let viewModel: QRCodeReciprocateScreenViewModelProtocol
    private let orientationManager: OrientationManagerProtocol
    private let appSettings: AppSettings
    private let presentationAnchor: UIWindow

    private var cancellables = Set<AnyCancellable>()
 
    private let actionsSubject: PassthroughSubject<QRCodeReciprocateScreenCoordinatorAction, Never> = .init()
    var actionsPublisher: AnyPublisher<QRCodeReciprocateScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: QRCodeReciprocateScreenCoordinatorParameters) {
        viewModel = QRCodeReciprocateScreenViewModel(clientProxy: parameters.clientProxy,
                                                     appMediator: parameters.appMediator)
        orientationManager = parameters.orientationManager
        appSettings = parameters.appSettings
        presentationAnchor = parameters.presentationAnchor
    }
    
    func start() {
        viewModel.actionsPublisher.sink { [weak self] action in
            MXLog.info("Coordinator: received view model action: \(action)")
            
            guard let self else { return }
            switch action {
            case .cancel:
                self.actionsSubject.send(.cancel)
            case .done:
                self.actionsSubject.send(.done)
            case .waitingForAuth(let url):
                let session = OIDCAccountSettingsPresenter(accountURL: url, presentationAnchor: presentationAnchor, appSettings: appSettings)
                session.start()
            }
        }
        .store(in: &cancellables)
        
        orientationManager.setOrientation(.portrait)
        orientationManager.lockOrientation(.portrait)
    }
    
    func stop() {
        orientationManager.lockOrientation(.all)
    }
        
    func toPresentable() -> AnyView {
        AnyView(QRCodeReciprocateScreen(context: viewModel.context))
    }
}
