//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum QRCodeReciprocateScreenViewModelAction {
    case cancel
    case done
    case waitingForAuth(URL)
}

struct QRCodeReciprocateScreenViewState: BindableState {
    var state: QRCodeReciprocateState = .initial
    
    private static let initialStateListItem3AttributedText = {
        let boldPlaceholder = "{bold}"
        var finalString = AttributedString(L10n.screenQrCodeLoginInitialStateItem3(boldPlaceholder))
        var boldString = AttributedString(L10n.screenQrCodeLoginInitialStateItem3Action)
        boldString.bold()
        finalString.replace(boldPlaceholder, with: boldString)
        return finalString
    }()
    
    let initialStateListItems = [
        AttributedString(L10n.screenQrCodeLoginInitialStateItem1(InfoPlistReader.main.productionAppName)),
        AttributedString(L10n.screenQrCodeLoginInitialStateItem2),
        initialStateListItem3AttributedText,
        AttributedString(L10n.screenQrCodeLoginInitialStateItem4)
    ]
    
    let connectionNotSecureListItems = [
        AttributedString(L10n.screenQrCodeLoginConnectionNoteSecureStateListItem1),
        AttributedString(L10n.screenQrCodeLoginConnectionNoteSecureStateListItem2),
        AttributedString(L10n.screenQrCodeLoginConnectionNoteSecureStateListItem3)
    ]
    
    var bindings = QRCodeReciprocateScreenViewStateBindings()
}

struct QRCodeReciprocateScreenViewStateBindings {
    var qrResult: Data?
}

enum QRCodeReciprocateScreenViewAction {
    case cancel
    case startScan
    case openSettings
}

enum QRCodeReciprocateState: Equatable {
    /// Initial state where the user is informed how to perform the scan
    case initial
    /// The camera is scanning
    case scan(QRCodeReciprocateScanningState)
    /// Codes are being shown
    case displayCode(QRCodeReciprocateDisplayCodeState)
    /// Any full screen error state
    case error(QRCodeReciprocateErrorState)
    
    enum QRCodeReciprocateErrorState: Equatable {
        case noCameraPermission
        case connectionNotSecure
        case cancelled
        case declined
        case expired
        case linkingNotSupported
        case deviceNotSupported
        case unknown
    }
    
    enum QRCodeReciprocateScanningState: Equatable {
        /// the QR code is scanning
        case scanning
        /// the QR code has been detected and is being processed
        case connecting
        /// the QR code was scanned, but an error occurred.
        case scanFailed(Error)
        
        enum Error: Equatable {
            /// the QR code has been processed and is invalid
            case invalid
            /// the QR code has been processed but it belongs to a device not signed in
            case deviceAlreadySignedIn
            
            var title: String {
                switch self {
                case .invalid:
                    L10n.screenQrCodeLoginInvalidScanStateSubtitle
                case .deviceAlreadySignedIn:
                    L10n.screenQrCodeLoginDeviceNotSignedInScanStateSubtitle // FIXME:
                }
            }
            
            var description: String {
                switch self {
                case .invalid:
                    L10n.screenQrCodeLoginInvalidScanStateDescription
                case .deviceAlreadySignedIn:
                    L10n.screenQrCodeLoginDeviceNotSignedInScanStateDescription // FIXME:
                }
            }
        }
    }
    
    enum QRCodeReciprocateDisplayCodeState: Equatable {
        case deviceCode(String)
        case verificationCode(String)
        
        var code: String {
            switch self {
            case .deviceCode(let code):
                return code
            case .verificationCode(let code):
                return code
            }
        }
    }
    
    var isScanning: Bool {
        switch self {
        case .scan(.scanning): true
        default: false
        }
    }
    
    var isError: Bool {
        switch self {
        case .error, .scan(.scanFailed): true
        default: false
        }
    }
    
    var shouldDisplayCancelButton: Bool {
        switch self {
        case .initial, .scan, .error(.noCameraPermission): true
        default: false
        }
    }
}
