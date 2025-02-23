//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias StartChatScreenViewModelType = StateStoreViewModel<StartChatScreenViewState, StartChatScreenViewAction>

class StartChatScreenViewModel: StartChatScreenViewModelType, StartChatScreenViewModelProtocol {
    private let userSession: UserSessionProtocol
    private let analytics: AnalyticsService
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let userDiscoveryService: UserDiscoveryServiceProtocol
    
    private var suggestedUsers = [UserProfileProxy]()
    
    private let actionsSubject: PassthroughSubject<StartChatScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<StartChatScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol,
         analytics: AnalyticsService,
         userIndicatorController: UserIndicatorControllerProtocol,
         userDiscoveryService: UserDiscoveryServiceProtocol) {
        self.userSession = userSession
        self.analytics = analytics
        self.userIndicatorController = userIndicatorController
        self.userDiscoveryService = userDiscoveryService
        
        super.init(initialViewState: StartChatScreenViewState(userID: userSession.clientProxy.userID), mediaProvider: userSession.mediaProvider)
        
        setupBindings()
        
        Task {
            suggestedUsers = await userSession.clientProxy.recentConversationCounterparts()
            
            if state.usersSection.type == .suggestions {
                state.usersSection = .init(type: .suggestions, users: suggestedUsers)
            }
        }
    }
    
    // MARK: - Public
    
    override func process(viewAction: StartChatScreenViewAction) {
        switch viewAction {
        case .close:
            actionsSubject.send(.close)
        case .createRoom:
            actionsSubject.send(.createRoom)
        case .selectUser(let user):
            showLoadingIndicator(delay: .milliseconds(200))
            Task {
                let currentDirectRoom = await userSession.clientProxy.directRoomForUserID(user.userID)
                switch currentDirectRoom {
                case .success(.some(let roomId)):
                    hideLoadingIndicator()
                    actionsSubject.send(.openRoom(withIdentifier: roomId))
                case .success:
                    hideLoadingIndicator()
                    state.bindings.selectedUserToInvite = user
                case .failure:
                    hideLoadingIndicator()
                    displayError()
                }
            }
        case .createDM(let user):
            Task { await createDirectRoom(user: user) }
        }
    }
    
    // MARK: - Private
    
    private func setupBindings() {
        context.$viewState
            .map(\.bindings.searchQuery)
            .debounceTextQueriesAndRemoveDuplicates()
            .sink { [weak self] _ in
                self?.fetchUsers()
            }
            .store(in: &cancellables)
    }
    
    // periphery:ignore - auto cancels when reassigned
    @CancellableTask
    private var fetchUsersTask: Task<Void, Never>?
    
    private func fetchUsers() {
        guard context.searchQuery.count >= 3 else {
            state.usersSection = .init(type: .suggestions, users: suggestedUsers)
            return
        }
        
        fetchUsersTask = Task {
            let result = await userDiscoveryService.searchProfiles(with: context.searchQuery)
            
            guard !Task.isCancelled else { return }
            
            switch result {
            case .success(let users):
                state.usersSection = .init(type: .searchResult, users: users)
            case .failure:
                break
            }
        }
    }
        
    private func createDirectRoom(user: UserProfileProxy) async {
        defer {
            hideLoadingIndicator()
        }
        showLoadingIndicator()
        switch await userSession.clientProxy.createDirectRoom(with: user.userID, expectedRoomName: user.displayName) {
        case .success(let roomId):
            analytics.trackCreatedRoom(isDM: true)
            actionsSubject.send(.openRoom(withIdentifier: roomId))
        case .failure:
            displayError()
        }
    }
    
    private func displayError() {
        state.bindings.alertInfo = AlertInfo(id: .failedCreatingRoom,
                                             title: L10n.commonError,
                                             message: L10n.screenStartChatErrorStartingChat)
    }
        
    // MARK: Loading indicator
    
    private static let loadingIndicatorIdentifier = "\(StartChatScreenViewModel.self)-Loading"
    
    private func showLoadingIndicator(delay: Duration? = nil) {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                              title: L10n.commonLoading,
                                                              persistent: true),
                                                delay: delay)
    }
    
    private func hideLoadingIndicator() {
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }
}
