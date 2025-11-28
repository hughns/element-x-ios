//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import CoreImage.CIFilterBuiltins
import MatrixRustSDK
import SwiftUI

struct QRCodeReciprocateScreen: View {
    @ObservedObject var context: QRCodeReciprocateScreenViewModel.Context
    @State private var qrFrame = CGRect.zero
    @FocusState private var checkCodeInputFocus
    
    var body: some View {
        NavigationStack {
            mainContent
                .toolbar { toolbar }
                .toolbar(.visible, for: .navigationBar)
                .background()
                .backgroundStyle(.compound.bgSubtleSecondary)
                .interactiveDismissDisabled()
        }
    }
    
    @ViewBuilder
    var mainContent: some View {
        switch context.viewState.state {
        case .initial:
            initialContent
        case .scanInstructions:
            scanInstructionsContent
        case .scan:
            qrScanContent
        case .displayQr:
            qrShowContent
        case .checkCode:
            checkCodeContent
        case .displayCode:
            displayCodeContent
        case .error:
            errorContent
        }
    }
    
    private var initialContent: some View {
        FullscreenDialog {
            VStack(alignment: .leading, spacing: 40) {
                VStack(spacing: 16) {
                    BigIcon(icon: \.computer, style: .default)
                    
                    VStack(spacing: 8) {
                        Text("What kind of device do you want to link?")
                            .foregroundColor(.compound.textPrimary)
                            .font(.compound.headingMDBold)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
            }
        } bottomContent: {
            Button("Mobile device") {
                context.send(viewAction: .startMobile)
            }
            .buttonStyle(.compound(.primary))
            Button("Desktop computer") {
                context.send(viewAction: .startDesktop)
            }
            .buttonStyle(.compound(.primary))
        }
    }

    private var scanInstructionsContent: some View {
        FullscreenDialog {
            VStack(alignment: .leading, spacing: 40) {
                VStack(spacing: 16) {
                    BigIcon(icon: \.computer, style: .default)
                    
                    VStack(spacing: 8) {
                        Text(L10n.screenQrCodeLoginInitialStateTitle(InfoPlistReader.main.productionAppName))
                            .foregroundColor(.compound.textPrimary)
                            .font(.compound.headingMDBold)
                            .multilineTextAlignment(.center)
                        
                        Text(L10n.screenQrCodeLoginInitialStateSubtitle)
                            .font(.compound.bodyMD)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.compound.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                
                SFNumberedListView(items: context.viewState.initialStateListItems)
            }
        } bottomContent: {
            Button(L10n.screenQrCodeLoginInitialStateButtonTitle) {
                context.send(viewAction: .startScan)
            }
            .buttonStyle(.compound(.primary))
        }
    }
    
    @ViewBuilder
    private var displayCodeContent: some View {
        if case let .displayCode(displayCodeState) = context.viewState.state {
            FullscreenDialog {
                VStack(spacing: 32) {
                    VStack(spacing: 40) {
                        displayCodeHeader(state: displayCodeState)
                        PINTextField(pinCode: .constant(displayCodeState.code),
                                     maxLength: displayCodeState.code.count,
                                     size: .small)
                            .disabled(true)
                    }
                    VStack(spacing: 4) {
                        ProgressView()
                        Text(L10n.screenQrCodeLoginVerifyCodeLoading)
                            .foregroundColor(.compound.textSecondary)
                            .font(.compound.bodySM)
                            .multilineTextAlignment(.center)
                    }
                }
            } bottomContent: {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
                .buttonStyle(.compound(.secondary))
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var checkCodeContent: some View {
        FullscreenDialog {
            VStack(alignment: .leading, spacing: 40) {
                VStack(spacing: 16) {
                    BigIcon(icon: \.computer, style: .default)
                    
                    VStack(spacing: 8) {
                        Text("Enter the number shown on your other device")
                            .foregroundColor(.compound.textPrimary)
                            .font(.compound.headingMDBold)
                            .multilineTextAlignment(.center)
                        
                        Text("This will verify that the connection to your other device is secure")
                            .font(.compound.bodyMD)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.compound.textSecondary)
                    }

                    VStack(spacing: 40) {
                        Text("Enter 2-digit code").font(.compound.bodyMD)

                        PINTextField(pinCode: $context.checkCodeInput, maxLength: 2,
                                     size: .medium)
                            .focused($checkCodeInputFocus)
                    }
                }
                .padding(.horizontal, 24)
            }
        } bottomContent: {
            Button(L10n.actionContinue) {
                context.send(viewAction: .checkCodeInput)
            }
            .buttonStyle(.compound(.primary))
            .disabled(context.checkCodeInput.count < 2)
        }
        .padding(.horizontal, 24)
        .onAppear { checkCodeInputFocus = true }
    }

    func generateQRCode(from data: Data) -> UIImage {
        let qrContext = CIContext()
        let qrFilter = CIFilter.qrCodeGenerator()
        
        qrFilter.message = data
        qrFilter.correctionLevel = "Q"

        if let outputImage = qrFilter.outputImage {
            if let cgImage = qrContext.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
    
    @ViewBuilder
    private var qrShowContent: some View {
        if case let .displayQr(qrCodeData) = context.viewState.state {
            FullscreenDialog {
                VStack(spacing: 16) {
                    BigIcon(icon: \.takePhotoSolid, style: .default)
                        
                    VStack(spacing: 8) {
                        Text("Open Element on the other device")
                            .foregroundColor(.compound.textPrimary)
                            .font(.compound.headingMDBold)
                            .multilineTextAlignment(.center)
                    }
                        
                    Image(uiImage: generateQRCode(from: qrCodeData))
                        .interpolation(.none) // to stop it getting blurred
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                }
                .padding(.horizontal, 24)
                    
                SFNumberedListView(items: [
                    "Open Element on the other device",
                    "Select \"Sign in with QR Code\"",
                    "Scan the QR code shown here with the other device"
                ])
            } bottomContent: { }.padding(.horizontal, 24)
        }
    }

    private func displayCodeHeader(state: QRCodeReciprocateState.QRCodeReciprocateDisplayCodeState) -> some View {
        VStack(spacing: 16) {
            switch state {
            case .deviceCode:
                BigIcon(icon: \.computer, style: .default)
                
                VStack(spacing: 8) {
                    Text(L10n.screenQrCodeLoginDeviceCodeTitle)
                        .foregroundColor(.compound.textPrimary)
                        .font(.compound.headingMDBold)
                        .multilineTextAlignment(.center)
                    
                    Text(L10n.screenQrCodeLoginDeviceCodeSubtitle)
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodyMD)
                        .multilineTextAlignment(.center)
                }
            case .verificationCode:
                BigIcon(icon: \.lock, style: .default)
                
                VStack(spacing: 8) {
                    Text(L10n.screenQrCodeLoginVerifyCodeTitle)
                        .foregroundColor(.compound.textPrimary)
                        .font(.compound.headingMDBold)
                        .multilineTextAlignment(.center)
                    
                    Text(L10n.screenQrCodeLoginVerifyCodeSubtitle)
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodyMD)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var qrScanContent: some View {
        FullscreenDialog {
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    BigIcon(icon: \.takePhotoSolid, style: .default)
                    
                    Text(L10n.screenQrCodeLoginScanningStateTitle)
                        .foregroundColor(.compound.textPrimary)
                        .font(.compound.headingMDBold)
                        .multilineTextAlignment(.center)
                }
                
                qrScanner
            }
        } bottomContent: {
            qrScanFooter
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var qrScanFooter: some View {
        if case let .scan(scanState) = context.viewState.state {
            switch scanState {
            case .connecting:
                VStack(spacing: 4) {
                    ProgressView()
                    Text(L10n.screenQrCodeLoginConnectingSubtitle)
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodySM)
                        .multilineTextAlignment(.center)
                }
            case .scanning:
                // To keep the spacing consistent between states
                Button("") { }
                    .buttonStyle(.compound(.primary))
                    .hidden()
            case .scanFailed(let error):
                VStack(spacing: 16) {
                    Button(L10n.screenQrCodeLoginInvalidScanStateRetryButton) {
                        context.send(viewAction: .startScan)
                    }
                    .buttonStyle(.compound(.primary))
                    
                    VStack(spacing: 4) {
                        Label(error.title,
                              icon: \.errorSolid,
                              iconSize: .medium,
                              relativeTo: .compound.bodyMDSemibold)
                            .labelStyle(.custom(spacing: 10))
                            .font(.compound.bodyMDSemibold)
                            .foregroundColor(.compound.textCriticalPrimary)
                        
                        Text(error.description)
                            .foregroundColor(.compound.textSecondary)
                            .font(.compound.bodySM)
                            .multilineTextAlignment(.center)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var qrScanner: some View {
        QRCodeScannerView(result: $context.qrResult, isScanning: context.viewState.state.isScanning)
            .aspectRatio(1.0, contentMode: .fill)
            .frame(maxWidth: 312)
            .readFrame($qrFrame)
            .background(.compound.bgCanvasDefault)
            .overlay(
                QRScannerViewOverlay(length: qrFrame.height)
            )
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.state.shouldDisplayCancelButton {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
            }
        }
    }
        
    @ViewBuilder
    private var errorContent: some View {
        if case let .error(errorState) = context.viewState.state {
            FullscreenDialog {
                errorContentHeader(errorState: errorState)
            } bottomContent: {
                errorContentFooter(errorState: errorState)
            }
            .padding(.horizontal, 24)
        }
    }
    
    @ViewBuilder
    private func errorContentHeader(errorState: QRCodeReciprocateState.QRCodeReciprocateErrorState) -> some View {
        switch errorState {
        case .noCameraPermission:
            VStack(spacing: 16) {
                BigIcon(icon: \.takePhotoSolid, style: .default)
                
                VStack(spacing: 8) {
                    Text(L10n.screenQrCodeLoginNoCameraPermissionStateTitle)
                        .foregroundColor(.compound.textPrimary)
                        .font(.compound.headingMDBold)
                        .multilineTextAlignment(.center)
                    
                    Text(L10n.screenQrCodeLoginNoCameraPermissionStateDescription(InfoPlistReader.main.productionAppName))
                        .foregroundColor(.compound.textSecondary)
                        .font(.compound.bodyMD)
                        .multilineTextAlignment(.center)
                }
            }
        case .connectionNotSecure:
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    BigIcon(icon: \.errorSolid, style: .alert)
                    
                    VStack(spacing: 8) {
                        Text(L10n.screenQrCodeLoginConnectionNoteSecureStateTitle)
                            .foregroundColor(.compound.textPrimary)
                            .font(.compound.headingMDBold)
                            .multilineTextAlignment(.center)
                        
                        Text(L10n.screenQrCodeLoginConnectionNoteSecureStateDescription)
                            .foregroundColor(.compound.textSecondary)
                            .font(.compound.bodyMD)
                            .multilineTextAlignment(.center)
                    }
                }
                
                VStack(spacing: 24) {
                    Text(L10n.screenQrCodeLoginConnectionNoteSecureStateListHeader)
                        .foregroundColor(.compound.textPrimary)
                        .font(.compound.bodyLGSemibold)
                        .multilineTextAlignment(.center)
                    
                    SFNumberedListView(items: context.viewState.connectionNotSecureListItems)
                }
            }
        default:
            simpleErrorStack(errorState: errorState)
        }
    }
    
    @ViewBuilder
    private func simpleErrorStack(errorState: QRCodeReciprocateState.QRCodeReciprocateErrorState) -> some View {
        let title = switch errorState {
        case .cancelled:
            L10n.screenQrCodeLoginErrorCancelledTitle
        case .declined:
            L10n.screenQrCodeLoginErrorDeclinedTitle
        case .expired:
            L10n.screenQrCodeLoginErrorExpiredTitle
        case .linkingNotSupported:
            L10n.screenQrCodeLoginErrorLinkingNotSuportedTitle
        case .deviceNotSupported:
            L10n.screenQrCodeLoginErrorSlidingSyncNotSupportedTitle(InfoPlistReader.main.bundleDisplayName)
        case .unknown:
            L10n.commonSomethingWentWrong
        default:
            fatalError("This should not be displayed")
        }
        
        let subtitle: String = switch errorState {
        case .cancelled:
            L10n.screenQrCodeLoginErrorCancelledSubtitle
        case .declined:
            L10n.screenQrCodeLoginErrorDeclinedSubtitle
        case .expired:
            L10n.screenQrCodeLoginErrorExpiredSubtitle
        case .linkingNotSupported:
            L10n.screenQrCodeLoginErrorLinkingNotSuportedSubtitle(InfoPlistReader.main.bundleDisplayName)
        case .deviceNotSupported:
            L10n.screenQrCodeLoginErrorSlidingSyncNotSupportedSubtitle(InfoPlistReader.main.bundleDisplayName)
        case .unknown:
            L10n.screenQrCodeLoginUnknownErrorDescription
        default:
            fatalError("This should not be displayed")
        }
        
        VStack(spacing: 16) {
            BigIcon(icon: \.errorSolid, style: .alert)
            
            VStack(spacing: 8) {
                Text(title)
                    .foregroundColor(.compound.textPrimary)
                    .font(.compound.headingMDBold)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .foregroundColor(.compound.textSecondary)
                    .font(.compound.bodyMD)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private func errorContentFooter(errorState: QRCodeReciprocateState.QRCodeReciprocateErrorState) -> some View {
        switch errorState {
        case .noCameraPermission:
            Button(L10n.screenQrCodeLoginNoCameraPermissionButton) {
                context.send(viewAction: .openSettings)
            }
            .buttonStyle(.compound(.primary))
        case .connectionNotSecure, .unknown, .expired, .declined, .deviceNotSupported:
            Button(L10n.screenQrCodeLoginStartOverButton) {
                context.send(viewAction: .startOver)
            }
            .buttonStyle(.compound(.primary))
        case .cancelled:
            Button(L10n.actionTryAgain) {
                context.send(viewAction: .startOver)
            }
            .buttonStyle(.compound(.primary))
        case .linkingNotSupported:
            VStack(spacing: 16) {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
                .buttonStyle(.compound(.tertiary))
            }
        }
    }
}

private struct QRScannerViewOverlay: View {
    let length: CGFloat
    
    private let dashRatio: CGFloat = 80.0 / 312.0
    private let emptyRatio: CGFloat = 232.0 / 312.0
    private let dashPhaseRatio: CGFloat = 40.0 / 312.0
    
    private var dashLength: CGFloat {
        length * dashRatio
    }
    
    private var emptyLength: CGFloat {
        length * emptyRatio
    }
    
    private var dashPhase: CGFloat {
        length * dashPhaseRatio
    }
    
    var body: some View {
        Rectangle()
            .stroke(.compound.textPrimary, style: StrokeStyle(lineWidth: 4.0, lineCap: .square, dash: [dashLength, emptyLength], dashPhase: dashPhase))
    }
}

// MARK: - Previews

struct QRCodeReciprocateScreen_Previews: PreviewProvider, TestablePreview {
    // Initial
    static let initialStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .initial)
    
    // Scanning
    static let scanningStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .scan(.scanning))
    
    static let connectingStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .scan(.connecting))
    
    static let invalidStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .scan(.scanFailed(.invalid)))
    
    static let deviceAlreadySignedInStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .scan(.scanFailed(.deviceAlreadySignedIn)))
    
    // Display Code
    static let deviceCodeStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .displayCode(.deviceCode("12")))
    
    static let verificationCodeStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .displayCode(.verificationCode("123456")))
    
    // Errors
    static let noCameraPermissionStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.noCameraPermission))
    
    static let connectionNotSecureStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.connectionNotSecure))
    
    static let linkingUnsupportedStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.linkingNotSupported))
    
    static let cancelledStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.cancelled))
    
    static let declinedStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.declined))
    
    static let expiredStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.expired))
    
    static let deviceNoSupportedViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.deviceNotSupported))
    
    static let unknownErrorStateViewModel = QRCodeReciprocateScreenViewModel.mock(state: .error(.unknown))
    
    static var previews: some View {
        QRCodeReciprocateScreen(context: initialStateViewModel.context)
            .previewDisplayName("Initial")
        
        QRCodeReciprocateScreen(context: scanningStateViewModel.context)
            .previewDisplayName("Scanning")
        
        QRCodeReciprocateScreen(context: connectingStateViewModel.context)
            .previewDisplayName("Connecting")
        
        QRCodeReciprocateScreen(context: invalidStateViewModel.context)
            .previewDisplayName("Invalid")
        
        QRCodeReciprocateScreen(context: deviceAlreadySignedInStateViewModel.context)
            .previewDisplayName("Device not signed in")
        
        QRCodeReciprocateScreen(context: deviceCodeStateViewModel.context)
            .previewDisplayName("Device code")
        
        QRCodeReciprocateScreen(context: verificationCodeStateViewModel.context)
            .previewDisplayName("Verification code")
        
        QRCodeReciprocateScreen(context: noCameraPermissionStateViewModel.context)
            .previewDisplayName("No Camera Permission")
        
        QRCodeReciprocateScreen(context: connectionNotSecureStateViewModel.context)
            .previewDisplayName("Connection not secure")
        
        QRCodeReciprocateScreen(context: linkingUnsupportedStateViewModel.context)
            .previewDisplayName("Linking unsupported")
        
        QRCodeReciprocateScreen(context: cancelledStateViewModel.context)
            .previewDisplayName("Cancelled")
        
        QRCodeReciprocateScreen(context: declinedStateViewModel.context)
            .previewDisplayName("Declined")
        
        QRCodeReciprocateScreen(context: expiredStateViewModel.context)
            .previewDisplayName("Expired")
        
        QRCodeReciprocateScreen(context: deviceNoSupportedViewModel.context)
            .previewDisplayName("Device not supported")
        
        QRCodeReciprocateScreen(context: unknownErrorStateViewModel.context)
            .previewDisplayName("Unknown error")
    }
}
