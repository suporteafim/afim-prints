import XCTest

final class SafariInstallTests: XCTestCase {
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let outDir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? "/tmp/afim-shots"

    func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    }

    func first(_ q: [XCUIElement], timeout: TimeInterval = 8) -> XCUIElement? {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            for e in q where e.exists { return e }
            usleep(300_000)
        }
        return nil
    }

    func dismissPopups() {
        for _ in 0..<3 {
            var hit = false
            for l in ["Continuar", "Continue", "Fechar", "Close", "Agora Não", "Not Now", "OK"] {
                let b = safari.buttons[l]
                if b.exists && b.isHittable { b.tap(); sleep(2); hit = true }
            }
            if !hit { break }
        }
    }

    func testInstallSteps() throws {
        continueAfterFailure = true
        safari.launch()
        // Abre o site
        if #available(iOS 16.4, *) {
            XCUIDevice.shared.system.open(URL(string: "https://afim.expo.app")!)
        }
        sleep(12)
        // Se caiu no login do Google, volta
        if safari.webViews.firstMatch.staticTexts["Fazer login com o Google"].exists ||
           safari.webViews.firstMatch.staticTexts["Sign in with Google"].exists {
            safari.buttons["BackButton"].tap(); sleep(5)
        }
        dismissPopups()
        // fecha a dica do Safari (balão) tocando no conteúdo da página, se ainda aberta
        if safari.staticTexts["Ver os Favoritos, o Menu Compartilhar e as Abas Abertas"].exists {
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap(); sleep(2)
        }
        dismissPopups()
        shot("p1_safari")

        // iOS 26: Compartilhar fica no menu ⋯ ; iOS antigo: botão direto
        if let share = first([safari.buttons["ShareButton"], safari.buttons["Compartilhar"], safari.buttons["Share"]], timeout: 3) {
            share.tap()
        } else {
            if let more = first([safari.buttons["Mais"], safari.buttons["More"], safari.buttons["MoreButton"], safari.buttons["Menu"]], timeout: 3) {
                more.tap()
            } else {
                safari.coordinate(withNormalizedOffset: CGVector(dx: 0.866, dy: 0.94)).tap()
            }
            sleep(2)
            first([safari.buttons["Compartilhar"], safari.buttons["Share"], safari.staticTexts["Compartilhar"], safari.staticTexts["Share"]], timeout: 5)?.tap()
        }
        sleep(3)
        shot("p2_compartilhar")

        // Procura "Adicionar à Tela de Início"
        let labels = ["Adicionar à Tela de Início", "Add to Home Screen"]
        func addEl() -> XCUIElement? {
            for l in labels {
                for e in [safari.buttons[l], safari.cells[l], safari.staticTexts[l], springboard.buttons[l], springboard.cells[l]] where e.exists { return e }
                let p = NSPredicate(format: "label == %@", l)
                let m = safari.descendants(matching: .any).matching(p).firstMatch
                if m.exists { return m }
            }
            return nil
        }
        var tries = 0
        while (addEl().map { !$0.isHittable } ?? true) && tries < 6 {
            let sheet = safari.otherElements["ActivityListView"].exists ? safari.otherElements["ActivityListView"] : safari.collectionViews.firstMatch
            if sheet.exists { sheet.swipeUp() } else { safari.swipeUp() }
            sleep(1); tries += 1
        }
        shot("p3_adicionar_visivel")
        addEl()?.tap()
        sleep(3)
        shot("p4_confirmar")

        // Confirma "Adicionar"
        first([safari.buttons["Adicionar"], safari.buttons["Add"], safari.navigationBars.buttons["Adicionar"], safari.navigationBars.buttons["Add"]])?.tap()
        sleep(4)
        XCUIDevice.shared.press(.home)
        sleep(3)
        shot("p5_tela_inicio")

        // Abre o app pelo ícone
        let icon = springboard.icons["Afim"]
        if icon.waitForExistence(timeout: 5) {
            icon.tap(); sleep(10)
            shot("p6_app_1")
        }
    }
}
