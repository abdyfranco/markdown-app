import Cocoa
import QuickLookUI
import UniformTypeIdentifiers

/// Data-based QuickLook preview: renders the Markdown file to HTML and hands
/// it to QuickLook, which displays it in its own web view.
@objc(PreviewProvider)
final class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let url = request.fileURL
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)

        let directory = url.deletingLastPathComponent()
        var attachments: [String: QLPreviewReplyAttachment] = [:]

        // Local images can only be shown when they're attached to the reply.
        let body = MarkdownRenderer.html(from: text) { src in
            guard !src.contains(":"), !src.hasPrefix("/"),
                  let path = src.removingPercentEncoding,
                  attachments.count < 32 else { return nil }
            let fileURL = directory.appendingPathComponent(path)
            guard let imageData = try? Data(contentsOf: fileURL),
                  imageData.count < 20_000_000 else { return nil }
            let id = "image-\(attachments.count)"
            let type = UTType(filenameExtension: fileURL.pathExtension) ?? .image
            attachments[id] = QLPreviewReplyAttachment(data: imageData, contentType: type)
            return "cid:\(id)"
        }

        let title = url.deletingPathExtension().lastPathComponent
        let html = PreviewTheme.page(body: body, title: title)

        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 860, height: 1000)) { reply in
            reply.stringEncoding = .utf8
            reply.attachments = attachments
            return Data(html.utf8)
        }
        reply.title = title
        return reply
    }
}
