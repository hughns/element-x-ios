//
//  ClientProxyProtocol.swift
//  ElementX
//
//  Created by Stefan Ceriu on 26/05/2022.
//  Copyright © 2022 Element. All rights reserved.
//

import Combine
import Foundation
import MatrixRustSDK

enum ClientProxyCallback {
    case updatedRoomsList
    case receivedSyncUpdate
}

enum ClientProxyError: Error {
    case failedRetrievingAvatarURL
    case failedRetrievingDisplayName
    case failedRetrievingSessionVerificationController
    case failedLoadingMedia
    case failedRetrievingRoom
}

protocol ClientProxyProtocol {
    var callbacks: PassthroughSubject<ClientProxyCallback, Never> { get }
    
    var userIdentifier: String { get }
    
    var homeScreenView: SlidingSyncViewProtocol { get }
    
    func roomForIdentifier(_ identifier: String) -> Result<SlidingSyncRoomProtocol, ClientProxyError>
    
    func roomProxyForIdentifier(_ identifier: String) async -> Result<RoomProxyProtocol, ClientProxyError>
    
    func loadUserDisplayName() async -> Result<String, ClientProxyError>
        
    func loadUserAvatarURLString() async -> Result<String, ClientProxyError>
    
    func mediaSourceForURLString(_ urlString: String) -> MatrixRustSDK.MediaSource
    
    func loadMediaContentForSource(_ source: MatrixRustSDK.MediaSource) throws -> Data
    
    func sessionVerificationControllerProxy() async -> Result<SessionVerificationControllerProxyProtocol, ClientProxyError>
}
