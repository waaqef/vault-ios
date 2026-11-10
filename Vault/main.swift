// [vault] for iPhone: a thin native shell around the live web app (https://vault.choseroxy.workers.dev).
// The site does everything; this adds what Safari won't allow a website: real haptics, background playback,
// and saving downloads. Because it loads the live site, every website update shows up here instantly.
import UIKit
import WebKit
import AVFoundation
import UserNotifications
import BackgroundTasks

let siteURL = URL(string: "https://vault.choseroxy.workers.dev/")!
let background = UIColor(red: 25 / 255, green: 25 / 255, blue: 25 / 255, alpha: 1)
let inboxTask = "com.choseroxy.vault.inbox"

// Notifications. iPhone app web views can't get web push, and real push needs a paid Apple developer account, so the
// app looks at the [vault] inbox itself (signed in with the web view's own cookie) and shows anything new:
// every minute while it's open or playing music, and now and then in the background, whenever iOS allows.
enum Inbox {
    static var lastId: Int {
        get { UserDefaults.standard.integer(forKey: "lastInboxId") }
        set { UserDefaults.standard.set(newValue, forKey: "lastInboxId") }
    }
    static func check(done: @escaping () -> Void = {}) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return done() }
            DispatchQueue.main.async {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    var req = URLRequest(url: siteURL.appendingPathComponent("api/inbox"))
                    req.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies.filter { siteURL.host!.hasSuffix($0.domain.trimmingCharacters(in: ["."])) })
                    URLSession.shared.dataTask(with: req) { data, response, _ in
                        defer { done() }
                        guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
                        let newest = rows.compactMap { $0["id"] as? Int }.max() ?? 0
                        let unread = rows.filter { ($0["read"] as? Int) == 0 }
                        DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = unread.count }
                        defer { lastId = max(lastId, newest) }
                        if lastId == 0 { return } // the first look: don't replay everything from before
                        for row in unread.prefix(5) {
                            guard let id = row["id"] as? Int, id > lastId, let title = row["title"] as? String else { continue }
                            let content = UNMutableNotificationContent()
                            content.title = title
                            content.body = row["body"] as? String ?? ""
                            content.sound = .default
                            content.userInfo = ["url": row["url"] as? String ?? "/"]
                            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "inbox-\(id)", content: content, trigger: nil))
                        }
                    }.resume()
                }
            }
        }
    }
    // Ask iOS to wake the app for another look in about 15 minutes (iOS decides when; often less often).
    static func scheduleBackground() {
        let req = BGAppRefreshTaskRequest(identifier: inboxTask)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }
}

final class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, WKDownloadDelegate {
    private var web: WKWebView!
    private var downloadFile: URL?
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let tick = UISelectionFeedbackGenerator()

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [] // songs can start without a fresh tap (next track, editor)
        config.applicationNameForUserAgent = "VaultApp/1 Mobile/15E148 Safari/604.1" // lets the site know it's in the app
        // The page calls window.webkit.messageHandlers.haptic.postMessage('light' | 'medium' | 'tick')
        config.userContentController.add(WeakHandler(self), name: "haptic")
        // window.webkit.messageHandlers.notify.postMessage({ action: 'status' | 'request' | 'settings' })
        config.userContentController.add(WeakHandler(self), name: "notify")

        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = false
        web.allowsLinkPreview = false
        web.isOpaque = false
        web.backgroundColor = background
        web.scrollView.backgroundColor = background
        web.scrollView.contentInsetAdjustmentBehavior = .never // the site handles the notch/home bar itself
        if #available(iOS 16.4, *) { web.isInspectable = true }
        view = web
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        light.prepare(); tick.prepare()
        web.load(URLRequest(url: siteURL))
        // while the app is running (on screen, or playing in the background): look at the inbox every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in Inbox.check() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in Inbox.check() }
    }

    // A notification was tapped: open what it's about.
    func open(path: String) {
        if let url = URL(string: path, relativeTo: siteURL) { web.load(URLRequest(url: url)) }
    }

    // MARK: notifications from the page
    private func notify(_ body: Any) {
        let action = (body as? [String: Any])?["action"] as? String
        switch action {
        case "request":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                self.reportNotify()
                Inbox.check()
            }
        case "settings":
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        default:
            reportNotify()
        }
    }
    private func reportNotify() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let state = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional ? "granted"
                : s.authorizationStatus == .denied ? "denied" : "default"
            DispatchQueue.main.async { self.web.evaluateJavaScript("window.vaultNotify && window.vaultNotify('\(state)')") }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: haptics from the page
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "notify" { return notify(message.body) }
        switch message.body as? String {
        case "medium": medium.impactOccurred()
        case "tick": tick.selectionChanged()
        default: light.impactOccurred()
        }
    }

    // MARK: links and downloads
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.shouldPerformDownload { return decisionHandler(.download) }
        // other websites open in Safari; the app stays on [vault]
        if let url = action.request.url, let host = url.host, host != siteURL.host, url.scheme?.hasPrefix("http") == true {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
        try? FileManager.default.removeItem(at: file)
        downloadFile = file
        completionHandler(file)
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadFile else { return }
        // ZIPs, songs and backups go to the share sheet: Save to Files, AirDrop, etc.
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(share, animated: true)
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        alert("Download failed: \(error.localizedDescription)")
    }

    // window.open / target=_blank
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }

    // Record button: let the page use the microphone (iOS still asks you the first time)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(origin.host == siteURL.host ? .grant : .prompt)
    }

    // plain JavaScript alerts / confirms
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alert(message, done: completionHandler)
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }

    // if iOS kills the page in the background, reload it
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    // no connection on launch: say so and retry when tapped
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let html = "<html><body style='background:#191919;color:#fff;font:17px -apple-system;display:grid;place-items:center;height:100vh;margin:0;text-align:center' onclick='location.href=\"\(siteURL.absoluteString)\"'><div><b>[vault]</b><p style='color:#999'>Can't reach [vault]. Tap to try again.</p></div></body></html>"
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func alert(_ message: String, done: (() -> Void)? = nil) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in done?() })
        present(a, animated: true)
    }
}

// Message handlers are held strongly by WebKit; this avoids a retain cycle with the view controller.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: inboxTask, using: nil) { task in
            Inbox.scheduleBackground() // and the next one
            task.expirationHandler = { task.setTaskCompleted(success: false) }
            Inbox.check { task.setTaskCompleted(success: true) }
        }
        // "playback" = keeps playing with the screen locked or the silent switch on (with UIBackgroundModes: audio)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = background
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        return true
    }
    func applicationDidEnterBackground(_ application: UIApplication) { Inbox.scheduleBackground() }
    // show notifications even while the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler done: @escaping () -> Void) {
        if let path = response.notification.request.content.userInfo["url"] as? String { (window?.rootViewController as? ViewController)?.open(path: path) }
        done()
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
