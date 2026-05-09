import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt:    UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttempt    = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttempt = bestAttempt else {
            contentHandler(request.content)
            return
        }

        // The server places the image URL in the top-level payload as `image_url`.
        // It only sets this field when there is actually an image to fetch, so
        // bailing out here when it is missing means no NSE work for plain pushes.
        guard
            let urlString = request.content.userInfo["image_url"] as? String,
            let url       = URL(string: urlString)
        else {
            contentHandler(bestAttempt)
            return
        }

        downloadAttachment(from: url) { [weak self] attachment in
            guard let self = self, let bestAttempt = self.bestAttempt else { return }
            if let attachment = attachment {
                bestAttempt.attachments = [attachment]
            }
            self.contentHandler?(bestAttempt)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Out of time. Deliver whatever we have so far rather than dropping
        // the notification entirely.
        if let contentHandler = contentHandler, let bestAttempt = bestAttempt {
            contentHandler(bestAttempt)
        }
    }

    // MARK: - Image download

    private func downloadAttachment(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, _ in
            guard let tempURL = tempURL else {
                completion(nil)
                return
            }

            let suggestedExt = (response?.suggestedFilename as NSString?)?.pathExtension
            let fileExtension: String = {
                if let s = suggestedExt, !s.isEmpty { return s }
                if !url.pathExtension.isEmpty { return url.pathExtension }
                return "jpg"
            }()
            let fileName = ProcessInfo.processInfo.globallyUniqueString + "." + fileExtension
            let destURL  = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

            do {
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                let attachment = try UNNotificationAttachment(identifier: "image", url: destURL, options: nil)
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}
