//
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Combine
import SwiftUI
import MatrixRustSDK

typealias HomeScreenViewModelType = StateStoreViewModel<HomeScreenViewState, HomeScreenViewAction>

class HomeScreenViewModel: HomeScreenViewModelType, HomeScreenViewModelProtocol, SlidingSyncViewUpdatedDelegate {
    private let attributedStringBuilder: AttributedStringBuilderProtocol
    private let clientProxy: ClientProxyProtocol
    private let slidingSyncView: SlidingSyncViewProtocol
    
    private var roomUpdateListeners = Set<AnyCancellable>()
    private var viewUpdateObserver: StoppableSpawn?

    var callback: ((HomeScreenViewModelAction) -> Void)?
    
    // MARK: - Setup
    
    init(clientProxy: ClientProxyProtocol,
         attributedStringBuilder: AttributedStringBuilderProtocol) {
        self.attributedStringBuilder = attributedStringBuilder
        self.clientProxy = clientProxy
        self.slidingSyncView = clientProxy.homeScreenView
        
        super.init(initialViewState: HomeScreenViewState())
        
        viewUpdateObserver = slidingSyncView.onRoomsUpdated(update: self)
        
        updateRooms()
    }
    
    // MARK: - Public
    
    override func process(viewAction: HomeScreenViewAction) async {
        switch viewAction {
        case .loadRoomData(let roomIdentifier):
            await loadRoomDataForIdentifier(roomIdentifier)
        case .selectRoom(let roomIdentifier):
            callback?(.selectRoom(roomIdentifier: roomIdentifier))
        case .tapUserAvatar:
            callback?(.tapUserAvatar)
        case .verifySession:
            callback?(.verifySession)
        }
    }
        
    func updateWithUserAvatar(_ avatar: UIImage) {
        state.userAvatar = avatar
    }
    
    func updateWithUserDisplayName(_ displayName: String) {
        state.userDisplayName = displayName
    }
    
    func showSessionVerificationBanner() {
        state.showSessionVerificationBanner = true
    }
    
    func hideSessionVerificationBanner() {
        state.showSessionVerificationBanner = false
    }
    
    // MARK: - SlidingSyncViewUpdatedDelegate
    
    func didReceiveUpdate() {
        DispatchQueue.main.async {
            self.updateRooms()
        }
    }
    
    // MARK: - Private
    
    private func updateRooms() {
        state.rooms = slidingSyncView.currentRoomsList().compactMap { roomListEntry in
            switch roomListEntry {
            case .empty:
                return nil
            case .filled(let roomId):
                return buildOrUpdateRoomForIdentifier(roomId)
            case .invalidated(let roomId):
                return buildOrUpdateRoomForIdentifier(roomId)
            }
        }
    }
    
    private func buildOrUpdateRoomForIdentifier(_ identifier: String) -> HomeScreenRoom? {
        guard case .success(let slidingSyncRoom) = clientProxy.roomForIdentifier(identifier) else {
            return nil
        }
        
//        guard var room = state.rooms.first(where: { $0.id == slidingSyncRoom.roomId() }) else {
            return HomeScreenRoom(id: slidingSyncRoom.roomId(),
                                  displayName: slidingSyncRoom.name(),
                                  lastMessage: stringForLastRoomMessage(slidingSyncRoom.latestRoomMessage()),
                                  avatar: nil,
                                  isDirect: false,
                                  isEncrypted: false,
                                  unreadCount: UInt(slidingSyncRoom.unreadNotifications().notificationCount()))
//        }
//
//        room.displayName = slidingSyncRoom.name()
//        room.lastMessage = stringForLastRoomMessage(slidingSyncRoom.latestRoomMessage())
//
//        return room
    }
    
    private func loadRoomDataForIdentifier(_ roomIdentifier: String) async {
        
    }
    
    private func stringForLastRoomMessage(_ lastRoomMessage: AnyMessage?) -> String? {
        return nil
//        guard let lastRoomMessage = lastRoomMessage else {
//            return nil
//        }
//
//        let message = RoomMessageFactory().buildRoomMessageFrom(lastRoomMessage)
//
//        return message.body
    }
}
