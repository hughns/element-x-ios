//
//  ClientProxy.swift
//  ElementX
//
//  Created by Stefan Ceriu on 14.02.2022.
//  Copyright © 2022 Element. All rights reserved.
//

import Combine
import Foundation
import MatrixRustSDK
import UIKit

private class WeakClientProxyWrapper: ClientDelegate {
    private weak var clientProxy: ClientProxy?
    
    init(clientProxy: ClientProxy) {
        self.clientProxy = clientProxy
    }
    
    func didReceiveSyncUpdate() {
        clientProxy?.didReceiveSyncUpdate()
    }
}

class ClientProxy: ClientProxyProtocol, SlidingSyncDelegate {
    private let client: Client
    private let backgroundTaskService: BackgroundTaskServiceProtocol
    private let slidingSync: SlidingSync
    private var sessionVerificationControllerProxy: SessionVerificationControllerProxy?
    
    private var slidingSyncObserver: StoppableSpawn?
    private let slidingSyncView: SlidingSyncView
        
    deinit {
        client.setDelegate(delegate: nil)
    }
    
    let callbacks = PassthroughSubject<ClientProxyCallback, Never>()
    
    init(client: Client,
         backgroundTaskService: BackgroundTaskServiceProtocol) {
        self.client = client
        self.backgroundTaskService = backgroundTaskService
        
        do {
            slidingSyncView = try SlidingSyncViewBuilder()
                .name(name: "HomeScreen")
                .sort(sort: ["by_recency", "by_name"])
                .batchSize(size: 20)
                .syncMode(mode: .fullSync)
                .build()
            
            slidingSync = try client.slidingSync()
                .homeserver(url: "https://slidingsync.lab.element.dev")
                .addView(view: slidingSyncView)
                .build()
            
            slidingSync.onUpdate(update: self)
            slidingSyncObserver = slidingSync.sync()
        } catch {
            fatalError("Failed configuring sliding sync")
        }
        
        client.setDelegate(delegate: WeakClientProxyWrapper(clientProxy: self))
        Benchmark.startTrackingForIdentifier("ClientSync", message: "Started sync.")
        client.startSync()
    }
    
    var homeScreenView: SlidingSyncViewProtocol {
        slidingSyncView
    }
    
    var userIdentifier: String {
        do {
            return try client.userId()
        } catch {
            MXLog.error("Failed retrieving room info with error: \(error)")
            return "Unknown user identifier"
        }
    }
    
//    func subscribeToRoomChanges(_ roomIdentifier: String) {
//        slidingSync.subscribe(roomId: roomIdentifier, settings: nil)
//    }
    
    func roomForIdentifier(_ identifier: String) -> Result<SlidingSyncRoomProtocol, ClientProxyError> {
        guard let room = try? slidingSync.getRoom(roomId: identifier) else {
            return .failure(.failedRetrievingRoom)
        }
        
        return .success(room)
    }
    
    func roomProxyForIdentifier(_ identifier: String) async -> Result<RoomProxyProtocol, ClientProxyError> {
        await Task.detached { () -> Result<RoomProxyProtocol, ClientProxyError> in
            do {
                let room = try self.client.getRoom(roomId: identifier)
                return .success(RoomProxy(room: room, roomMessageFactory: RoomMessageFactory(), backgroundTaskService: self.backgroundTaskService))
            } catch {
                return .failure(.failedRetrievingRoom)
            }
        }
        .value
    }
    
    func loadUserDisplayName() async -> Result<String, ClientProxyError> {
        await Task.detached { () -> Result<String, ClientProxyError> in
            do {
                let displayName = try self.client.displayName()
                return .success(displayName)
            } catch {
                return .failure(.failedRetrievingDisplayName)
            }
        }
        .value
    }
        
    func loadUserAvatarURLString() async -> Result<String, ClientProxyError> {
        await Task.detached { () -> Result<String, ClientProxyError> in
            do {
                let avatarURL = try self.client.avatarUrl()
                return .success(avatarURL)
            } catch {
                return .failure(.failedRetrievingDisplayName)
            }
        }
        .value
    }
    
    func mediaSourceForURLString(_ urlString: String) -> MatrixRustSDK.MediaSource {
        MatrixRustSDK.mediaSourceFromUrl(url: urlString)
    }
    
    func loadMediaContentForSource(_ source: MatrixRustSDK.MediaSource) throws -> Data {
        let bytes = try client.getMediaContent(source: source)
        return Data(bytes: bytes, count: bytes.count)
    }
    
    func sessionVerificationControllerProxy() async -> Result<SessionVerificationControllerProxyProtocol, ClientProxyError> {
        await Task.detached {
            do {
                let sessionVerificationController = try self.client.getSessionVerificationController()
                return .success(SessionVerificationControllerProxy(sessionVerificationController: sessionVerificationController))
            } catch {
                return .failure(.failedRetrievingSessionVerificationController)
            }
        }
        .value
    }
    
    // MARK: - SlidingSyncDelegate
    
    func didReceiveSyncUpdate(summary: UpdateSummary) {
        MXLog.debug("Received sliding sync update: \(summary)")
    }
        
    // MARK: - Private
    
    fileprivate func didReceiveSyncUpdate() {
        Benchmark.logElapsedDurationForIdentifier("ClientSync", message: "Received sync update")
        
        callbacks.send(.receivedSyncUpdate)
    }
}
