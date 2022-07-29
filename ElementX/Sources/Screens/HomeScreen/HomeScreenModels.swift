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

import Foundation
import UIKit

enum HomeScreenViewModelAction {
    case selectRoom(roomIdentifier: String)
    case tapUserAvatar
    case verifySession
}

enum HomeScreenViewAction {
    case loadRoomData(roomIdentifier: String)
    case selectRoom(roomIdentifier: String)
    case tapUserAvatar
    case verifySession
}

struct HomeScreenViewState: BindableState {
    var userDisplayName: String?
    var userAvatar: UIImage?
    
    var showSessionVerificationBanner = false
    
    var rooms: [HomeScreenRoom] = []
    
    var isLoadingRooms: Bool {
        rooms.count == 0
    }
    
    var searchFilteredRooms: [HomeScreenRoom] {
        guard !bindings.searchQuery.isEmpty else {
            // This extra filter is fine for now as there are always downstream filters
            // but if that changes, this approach should be reconsidered.
            return rooms.filter { _ in true }
        }
        
        return rooms.filter { $0.displayName?.localizedStandardContains(bindings.searchQuery) ?? false }
    }
    
    var bindings = HomeScreenViewStateBindings()
}

struct HomeScreenViewStateBindings {
    var searchQuery = ""
}

struct HomeScreenRoom: Identifiable, Equatable {
    let id: String
    
    var displayName: String?
    
    var lastMessage: String?
    
    var avatar: UIImage?
    
    let isDirect: Bool
    let isEncrypted: Bool
    
    let unreadCount: UInt
}

extension MutableCollection where Element == HomeScreenRoom {
    mutating func updateEach(_ update: (inout Element) -> Void) {
        for index in indices {
            update(&self[index])
        }
    }
}
