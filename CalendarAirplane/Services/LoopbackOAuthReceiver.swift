import Foundation
import Network

enum LoopbackOAuthReceiver {
    enum ReceiverError: LocalizedError {
        case timeout
        case invalidRequest
        case listenerFailed(String)

        var errorDescription: String? {
            switch self {
            case .timeout: return "Sign-in timed out waiting for Google to redirect back to the app."
            case .invalidRequest: return "Invalid OAuth redirect from Google."
            case .listenerFailed(let msg): return msg
            }
        }
    }

    /// Listens on `127.0.0.1:port` until Google redirects to `path` with query parameters.
    static func waitForRedirect(port: UInt16, path: String, timeout: TimeInterval = 180) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.calendarairplane.oauth-loopback")
            var finished = false
            var listener: NWListener?

            func finish(_ result: Result<URL, Error>) {
                queue.async {
                    guard !finished else { return }
                    finished = true
                    listener?.cancel()
                    listener = nil
                    continuation.resume(with: result)
                }
            }

            queue.asyncAfter(deadline: .now() + timeout) {
                finish(.failure(ReceiverError.timeout))
            }

            do {
                let nwPort = NWEndpoint.Port(rawValue: port)!
                let tcp = try NWListener(using: .tcp, on: nwPort)
                listener = tcp

                tcp.newConnectionHandler = { connection in
                    connection.start(queue: queue)
                    receiveRequest(on: connection) { requestLine in
                        guard requestLine.hasPrefix("GET ") else {
                            sendResponse(connection, status: 400, body: "Bad request")
                            return
                        }
                        let parts = requestLine.split(separator: " ", maxSplits: 2)
                        guard parts.count >= 2 else {
                            finish(.failure(ReceiverError.invalidRequest))
                            return
                        }
                        let target = String(parts[1])
                        guard target.hasPrefix(path) else {
                            sendResponse(connection, status: 404, body: "Not found")
                            return
                        }
                        guard let url = URL(string: "http://127.0.0.1:\(port)\(target)") else {
                            finish(.failure(ReceiverError.invalidRequest))
                            return
                        }
                        sendResponse(
                            connection,
                            status: 200,
                            body: "<html><body style='font-family:system-ui;padding:2rem'><h2>Signed in</h2><p>You can close this tab and return to Calendar Airplane.</p></body></html>"
                        )
                        finish(.success(url))
                    }
                }

                tcp.stateUpdateHandler = { state in
                    if case .failed(let error) = state {
                        finish(.failure(ReceiverError.listenerFailed(error.localizedDescription)))
                    }
                }

                tcp.start(queue: queue)
            } catch {
                finish(.failure(ReceiverError.listenerFailed(error.localizedDescription)))
            }
        }
    }

    private static func receiveRequest(on connection: NWConnection, completion: @escaping (String) -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, _ in
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            guard let line = text.split(separator: "\r\n", maxSplits: 1).first else { return }
            completion(String(line))
        }
    }

    private static func sendResponse(_ connection: NWConnection, status: Int, body: String) {
        let statusText = status == 200 ? "OK" : "Error"
        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: text/html; charset=utf-8\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
