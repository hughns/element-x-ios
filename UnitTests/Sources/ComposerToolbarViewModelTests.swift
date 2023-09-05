//
// Copyright 2023 New Vector Ltd
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

@testable import ElementX
import WysiwygComposer
import XCTest

@MainActor
class ComposerToolbarViewModelTests: XCTestCase {
    private var appSettings: AppSettings!
    private var wysiwygViewModel: WysiwygComposerViewModel!
    private var viewModel: ComposerToolbarViewModel!

    override func setUp() {
        AppSettings.reset()
        appSettings = AppSettings()
        appSettings.richTextEditorEnabled = true
        ServiceLocator.shared.register(appSettings: appSettings)
        wysiwygViewModel = WysiwygComposerViewModel()
        viewModel = ComposerToolbarViewModel(wysiwygViewModel: wysiwygViewModel)
    }

    func testComposerFocus() {
        viewModel.process(roomAction: .setMode(mode: .edit(originalItemId: TimelineItemIdentifier(timelineID: "mock"))))
        XCTAssertTrue(viewModel.state.bindings.composerFocused)
        viewModel.process(roomAction: .removeFocus)
        XCTAssertFalse(viewModel.state.bindings.composerFocused)
    }

    func testComposerMode() {
        let mode: RoomScreenComposerMode = .edit(originalItemId: TimelineItemIdentifier(timelineID: "mock"))
        viewModel.process(roomAction: .setMode(mode: mode))
        XCTAssertEqual(viewModel.state.composerMode, mode)
        viewModel.process(roomAction: .clear)
        XCTAssertEqual(viewModel.state.composerMode, .default)
    }

    func testComposerModeIsPublished() {
        let mode: RoomScreenComposerMode = .edit(originalItemId: TimelineItemIdentifier(timelineID: "mock"))
        let expectation = expectation(description: "Composer mode is published")
        let cancellable = viewModel
            .context
            .$viewState
            .map(\.composerMode)
            .removeDuplicates()
            .dropFirst()
            .sink(receiveValue: { composerMode in
                XCTAssertEqual(composerMode, mode)
                expectation.fulfill()
            })

        viewModel.process(roomAction: .setMode(mode: mode))

        wait(for: [expectation], timeout: 2.0)
        cancellable.cancel()
    }

    func testHandleKeyCommand() {
        XCTAssertTrue(viewModel.handleKeyCommand(.enter))
        XCTAssertFalse(viewModel.handleKeyCommand(.shiftEnter))
    }

    func testComposerFocusAfterEnablingRTE() {
        viewModel.process(viewAction: .enableTextFormatting)
        XCTAssertTrue(viewModel.state.bindings.composerFocused)
    }

    func testRTEDisabledAfterSendingMessage() {
        viewModel.process(viewAction: .enableTextFormatting)
        XCTAssertTrue(viewModel.state.bindings.composerFocused)
        viewModel.state.composerEmpty = false
        viewModel.process(viewAction: .sendMessage)
        XCTAssertFalse(viewModel.state.bindings.composerActionsEnabled)
    }

    func testAlertIsShownAfterLinkAction() {
        XCTAssertNil(viewModel.state.bindings.alertInfo)
        viewModel.process(viewAction: .enableTextFormatting)
        viewModel.process(viewAction: .composerAction(action: .link))
        XCTAssertNotNil(viewModel.state.bindings.alertInfo)
    }
}
