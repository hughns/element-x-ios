//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias MediaEventsTimelineScreenViewModelType = StateStoreViewModel<MediaEventsTimelineScreenViewState, MediaEventsTimelineScreenViewAction>

class MediaEventsTimelineScreenViewModel: MediaEventsTimelineScreenViewModelType, MediaEventsTimelineScreenViewModelProtocol {
    private let mediaTimelineViewModel: TimelineViewModelProtocol
    private let filesTimelineViewModel: TimelineViewModelProtocol
    private let mediaProvider: MediaProviderProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let appMediator: AppMediatorProtocol
    
    private var isOldestItemVisible = false
    
    private var activeTimelineViewModel: TimelineViewModelProtocol {
        switch state.bindings.screenMode {
        case .media:
            mediaTimelineViewModel
        case .files:
            filesTimelineViewModel
        }
    }
    
    private var mediaPreviewCancellable: AnyCancellable?
    
    private let actionsSubject: PassthroughSubject<MediaEventsTimelineScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<MediaEventsTimelineScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(mediaTimelineViewModel: TimelineViewModelProtocol,
         filesTimelineViewModel: TimelineViewModelProtocol,
         initialViewState: MediaEventsTimelineScreenViewState = .init(bindings: .init(screenMode: .media)),
         mediaProvider: MediaProviderProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         appMediator: AppMediatorProtocol) {
        self.mediaTimelineViewModel = mediaTimelineViewModel
        self.filesTimelineViewModel = filesTimelineViewModel
        self.mediaProvider = mediaProvider
        self.userIndicatorController = userIndicatorController
        self.appMediator = appMediator
        
        super.init(initialViewState: initialViewState, mediaProvider: mediaProvider)
        
        state.activeTimelineContextProvider = { [weak self] in
            guard let self else { fatalError() }
            
            return activeTimelineViewModel.context
        }
        
        mediaTimelineViewModel.context.$viewState.sink { [weak self] timelineViewState in
            guard let self, state.bindings.screenMode == .media else {
                return
            }
            
            updateWithTimelineViewState(timelineViewState)
        }
        .store(in: &cancellables)
        
        filesTimelineViewModel.context.$viewState.sink { [weak self] timelineViewState in
            guard let self, state.bindings.screenMode == .files else {
                return
            }
            
            updateWithTimelineViewState(timelineViewState)
        }
        .store(in: &cancellables)
        
        updateWithTimelineViewState(activeTimelineViewModel.context.viewState)
    }
    
    // MARK: - Public
    
    override func process(viewAction: MediaEventsTimelineScreenViewAction) {
        MXLog.info("View model: received view action: \(viewAction)")
        
        switch viewAction {
        case .changedScreenMode:
            updateWithTimelineViewState(activeTimelineViewModel.context.viewState)
        case .oldestItemDidAppear:
            isOldestItemVisible = true
            backPaginateIfNecessary(paginationStatus: activeTimelineViewModel.context.viewState.timelineState.paginationState.backward)
        case .oldestItemDidDisappear:
            isOldestItemVisible = false
        case .tappedItem(let item):
            handleItemTapped(item)
        }
    }
    
    // MARK: - Private
    
    private func updateWithTimelineViewState(_ timelineViewState: TimelineViewState) {
        var newGroups = [MediaEventsTimelineGroup]()
        var currentItems = [RoomTimelineItemViewState]()
        
        timelineViewState.timelineState.itemViewStates.filter { itemViewState in
            switch itemViewState.type {
            case .image, .video:
                state.bindings.screenMode == .media
            case .audio, .file, .voice:
                state.bindings.screenMode == .files
            case .separator:
                true
            default:
                false
            }
        }.reversed().forEach { item in
            if case .separator(let item) = item.type {
                let group = MediaEventsTimelineGroup(id: item.id.uniqueID.id,
                                                     title: titleForDate(item.timestamp),
                                                     items: currentItems)
                if !currentItems.isEmpty {
                    newGroups.append(group)
                    currentItems = []
                }
            } else {
                currentItems.append(item)
            }
        }
        
        if !currentItems.isEmpty {
            MXLog.warning("Found ungrouped timeline items, appending them at end.")
            let group = MediaEventsTimelineGroup(id: UUID().uuidString,
                                                 title: titleForDate(.now),
                                                 items: currentItems)
            newGroups.append(group)
        }

        state.groups = newGroups
        
        state.isBackPaginating = timelineViewState.timelineState.paginationState.backward == .paginating
        state.shouldShowEmptyState = newGroups.isEmpty && timelineViewState.timelineState.paginationState.backward == .timelineEndReached
        backPaginateIfNecessary(paginationStatus: timelineViewState.timelineState.paginationState.backward)
    }
    
    private func backPaginateIfNecessary(paginationStatus: PaginationStatus) {
        if paginationStatus == .idle, isOldestItemVisible {
            activeTimelineViewModel.context.send(viewAction: .paginateBackwards)
        }
    }
    
    private func handleItemTapped(_ item: RoomTimelineItemViewState) {
        let item: EventBasedMessageTimelineItemProtocol? = switch item.type {
        case .audio(let audioItem): audioItem
        case .file(let fileItem): fileItem
        case .image(let imageItem): imageItem
        case .video(let videoItem): videoItem
        default: nil
        }
        
        guard let item else {
            MXLog.error("Unexpected item type tapped.")
            return
        }
        
        let viewModel = TimelineMediaPreviewViewModel(initialItem: item,
                                                      timelineViewModel: activeTimelineViewModel,
                                                      mediaProvider: mediaProvider,
                                                      photoLibraryManager: PhotoLibraryManager(),
                                                      userIndicatorController: userIndicatorController,
                                                      appMediator: appMediator)
        viewModel.actions.sink { [weak self] action in
            guard let self else { return }
            switch action {
            case .viewInRoomTimeline(let itemID):
                state.bindings.mediaPreviewViewModel = nil
                actionsSubject.send(.viewInRoomTimeline(itemID))
            case .dismiss:
                state.bindings.mediaPreviewViewModel = nil
            }
        }
        .store(in: &cancellables)
        
        state.bindings.mediaPreviewViewModel = viewModel
    }
    
    private func titleForDate(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: .now, toGranularity: .month) {
            L10n.commonDateThisMonth
        } else {
            date.formatted(.dateTime.month(.wide).year())
        }
    }
}
