//
//  ClaudePetUITests.swift
//  ClaudePetUITests
//
//  macOS LSUIElement 앱이라 status bar 클릭은 불안정 →
//  앱이 --ui-test-preferences 인자를 받으면 시작 시 Preferences 창을 즉시 띄움.
//  핵심 컨트롤엔 accessibilityIdentifier로 안정 셀렉터 부여.

import XCTest

@MainActor
final class ClaudePetUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchWithPreferences() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-preferences"]
        app.launch()
        return app
    }

    // MARK: - Smoke

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
        app.terminate()
    }

    func testPreferencesOpens() throws {
        let app = launchWithPreferences()
        let idleSidebar = app.descendants(matching: .any)["sidebar-idle"]
        XCTAssertTrue(idleSidebar.waitForExistence(timeout: 5),
                      "Preferences 사이드바의 idle 항목이 5초 내 나타나야 함")
        app.terminate()
    }

    // MARK: - Navigation

    func testSidebarNavigation() throws {
        let app = launchWithPreferences()

        let waitingItem = app.descendants(matching: .any)["sidebar-waiting"]
        XCTAssertTrue(waitingItem.waitForExistence(timeout: 5))
        waitingItem.click()

        // Waiting 페이지에 들어가면 "Waiting 모션 사용" 토글이 보여야 함
        let toggle = app.descendants(matching: .any)["toggle-waiting-enabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3),
                      "Waiting 페이지에 toggle-waiting-enabled가 있어야 함")

        // general 페이지로 이동
        let general = app.descendants(matching: .any)["sidebar-general"]
        XCTAssertTrue(general.exists)
        general.click()

        app.terminate()
    }

    // MARK: - Waiting toggle

    func testWaitingToggleAndPersistence() throws {
        let app = launchWithPreferences()
        let waitingItem = app.descendants(matching: .any)["sidebar-waiting"]
        XCTAssertTrue(waitingItem.waitForExistence(timeout: 5))
        waitingItem.click()

        let toggle = app.descendants(matching: .any)["toggle-waiting-enabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))

        // 현재 상태 기록 후 반대로 토글
        let initialOn = (toggle.value as? String) == "1" || (toggle.value as? Bool) == true
        toggle.click()
        // debounce save(300ms) + 여유
        usleep(500_000)

        app.terminate()

        // 재시작 후에도 변경된 상태 유지되는지 확인
        let app2 = launchWithPreferences()
        let waiting2 = app2.descendants(matching: .any)["sidebar-waiting"]
        XCTAssertTrue(waiting2.waitForExistence(timeout: 5))
        waiting2.click()
        let toggle2 = app2.descendants(matching: .any)["toggle-waiting-enabled"]
        XCTAssertTrue(toggle2.waitForExistence(timeout: 3))

        let afterRestartOn = (toggle2.value as? String) == "1" || (toggle2.value as? Bool) == true
        XCTAssertNotEqual(initialOn, afterRestartOn,
                          "토글 상태가 재시작 후에도 유지되어야 함")

        // 원래대로 되돌리기 (다른 테스트 영향 방지)
        toggle2.click()
        usleep(500_000)
        app2.terminate()
    }

    // MARK: - 이미지 선택 picker (회귀 방어)

    /// 이전에 sandbox entitlement 누락 + LSUIElement 포커스 문제로
    /// 이미지 선택 버튼을 클릭해도 NSOpenPanel이 안 뜨던 버그가 있었음.
    /// 이 테스트는 그 버그의 재발을 막음.
    func testImagePickerOpensAndCancels() throws {
        let app = launchWithPreferences()

        let idleItem = app.descendants(matching: .any)["sidebar-idle"]
        XCTAssertTrue(idleItem.waitForExistence(timeout: 5))
        idleItem.click()

        let pickButton = app.descendants(matching: .any)["image-pick-idle"]
        XCTAssertTrue(pickButton.waitForExistence(timeout: 3),
                      "이미지 선택 버튼이 idle 페이지에 있어야 함")
        pickButton.click()

        // NSOpenPanel이 window로 뜸. "취소" / "Cancel" 버튼을 기다림.
        let cancelKO = app.buttons["취소"]
        let cancelEN = app.buttons["Cancel"]

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in cancelKO.exists || cancelEN.exists },
            object: nil
        )
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "이미지 선택 버튼 클릭 시 NSOpenPanel이 5초 내 떠야 함 (sandbox entitlement 회귀 방어)")

        // 정리: 떠있는 panel 닫기
        if cancelKO.exists {
            cancelKO.click()
        } else if cancelEN.exists {
            cancelEN.click()
        }

        app.terminate()
    }
}
