//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias QRCodeReciprocateScreenViewModelType = StateStoreViewModel<QRCodeReciprocateScreenViewState, QRCodeReciprocateScreenViewAction>

class QRCodeReciprocateScreenViewModel: QRCodeReciprocateScreenViewModelType, QRCodeReciprocateScreenViewModelProtocol {
    private let clientProxy: ClientProxyProtocol
    private let appMediator: AppMediatorProtocol
    
    private let actionsSubject: PassthroughSubject<QRCodeReciprocateScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<QRCodeReciprocateScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    private var scanTask: Task<Void, Never>?

    init(clientProxy: ClientProxyProtocol,
         appMediator: AppMediatorProtocol) {
        self.clientProxy = clientProxy
        self.appMediator = appMediator
        super.init(initialViewState: QRCodeReciprocateScreenViewState())
        setupSubscriptions()
    }
    
    // MARK: - Public
    
    override func process(viewAction: QRCodeReciprocateScreenViewAction) {
        switch viewAction {
        case .cancel:
            actionsSubject.send(.cancel)
        case .startScan:
            Task { await startScanIfPossible() }
        case .openSettings:
            appMediator.openAppSettings()
        }
    }
    
    // MARK: - Private
    
    private func setupSubscriptions() {
        context.$viewState
            // not using compactMap before remove duplicates because if there is an error, and the same code needs to be rescanned the transition to nil to clean the state would get ignored.
            .map(\.bindings.qrResult)
            .removeDuplicates()
            .compactMap { $0 }
            // this needs to be received on the main actor or the state change for connecting won't work properly
            .receive(on: DispatchQueue.main)
            .sink { [weak self] qrData in
                self?.handleScan(qrData: qrData)
            }
            .store(in: &cancellables)
        
        clientProxy.qrReciprocateProgressPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                MXLog.info("QR Login Progress changed to: \(progress)")

                guard let self,
                      // Let's not advance the state if the current state is already invalid
                      !state.state.isError else {
                    return
                }
                
                switch progress {
                case .establishingSecureChannel(_, let stringCode):
                    state.state = .displayCode(.deviceCode(stringCode))
                case .waitingForToken(let code):
                    state.state = .displayCode(.verificationCode(code))
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func startScanIfPossible() async {
        state.bindings.qrResult = nil
        state.state = await appMediator.requestAuthorizationIfNeeded() ? .scan(.scanning) : .error(.noCameraPermission)
    }
    
    private func handleScan(qrData: Data) {
        guard scanTask == nil else {
            return
        }
        
        state.state = .scan(.connecting)
        
        scanTask = Task { [weak self] in
            guard let self else {
                return
            }
            
            defer {
                scanTask = nil
            }
            
            MXLog.info("Scanning QR code: \(qrData)")
            switch await clientProxy.reciprocateWithQRCode(data: qrData) {
            case .success:
                MXLog.info("QR Reciprocate completed")
                actionsSubject.send(.done)
            case .failure(.qrCodeError(let error)):
                handleError(error)
            case .failure:
                handleError(.unknown)
            }
        }
    }
    
    private func handleError(_ error: QRCodeLoginError) {
        MXLog.error("Failed to scan the QR code: \(error)")
        switch error {
        case .invalidQRCode:
            state.state = .scan(.scanFailed(.invalid))
        case .deviceAlreadySignedIn:
            state.state = .scan(.scanFailed(.deviceAlreadySignedIn))
        case .cancelled:
            state.state = .error(.cancelled)
        case .connectionInsecure:
            state.state = .error(.connectionNotSecure)
        case .declined:
            state.state = .error(.declined)
        case .linkingNotSupported:
            state.state = .error(.linkingNotSupported)
        case .expired:
            state.state = .error(.expired)
        case .deviceNotSupported:
            state.state = .error(.deviceNotSupported)
        // these are not applicable to reciprocate so map these to unknown:
        case .providerNotAllowed, .deviceNotSignedIn, .unknown:
            state.state = .error(.unknown)
        }
    }
        
    /// Only for mocking initial states
    fileprivate init(state: QRCodeReciprocateState) {
        clientProxy = ClientProxyMock()
        appMediator = AppMediatorMock.default
        super.init(initialViewState: .init(state: state))
    }
}

extension QRCodeReciprocateScreenViewModel {
    static func mock(state: QRCodeReciprocateState) -> QRCodeReciprocateScreenViewModel {
        QRCodeReciprocateScreenViewModel(state: state)
    }
}
