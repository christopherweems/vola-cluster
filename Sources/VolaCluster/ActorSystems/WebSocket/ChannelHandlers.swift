/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Channel handlers used to implement the networking layer of

  Based on the WebSocket example available in the NIO repository:
  https://github.com/apple/swift-nio/blob/main/Sources/NIOWebSocketServer/main.swift
*/

import NIOCore
import NIOPosix
import NIOHTTP1
import Distributed
import NIOWebSocket
import Foundation

public struct WebSocketReplyEnvelope: Sendable, Codable {
    internal let callID: WebSocketActorSystem.CallID
    internal let sender: WebSocketActorSystem.ActorID?
    internal let value: Data
    
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Client-side handlers

internal struct ConnectTo {
    internal let host: String
    internal let port: Int
    
}

internal final class HTTPInitialRequestHandler: ChannelInboundHandler, RemovableChannelHandler {
    public typealias InboundIn = HTTPClientResponsePart
    public typealias OutboundOut = HTTPClientRequestPart
    
    public let target: ConnectTo
    
    public init(target: ConnectTo) {
        self.target = target
        
    }
    
}

extension HTTPInitialRequestHandler {
    public func channelActive(context: ChannelHandlerContext) {
        // We are connected. It's time to send the message to the server to initialize the upgrade dance.
        var headers = HTTPHeaders()
        headers.add(name: "Host", value: "\(target.host):\(target.port)")
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        headers.add(name: "Content-Length", value: "\(0)")
        
        let requestHead = HTTPRequestHead(version: .http1_1,
                                          method: .GET,
                                          uri: "/",
                                          headers: headers)
        
        context.write(self.wrapOutboundOut(.head(requestHead)), promise: nil)
        
        let body = HTTPClientRequestPart.body(.byteBuffer(ByteBuffer()))
        context.write(self.wrapOutboundOut(body), promise: nil)
        
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let clientResponse = self.unwrapInboundIn(data)
        
        switch clientResponse {
        case .head(let responseHead):
            print("Received status: \(responseHead.status)")
            
        case .body(let byteBuffer):
            let string = String(buffer: byteBuffer)
            print("Received: '\(string)' back from the server.")
            
        case .end:
            print("Closing channel.")
            context.close(promise: nil)
        }
    }
    
    public func handlerRemoved(context: ChannelHandlerContext) {
        print("HTTP handler removed.")
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("error: ", error)
        
        // As we are not really interested getting notified on success or failure
        // we just pass nil as promise to reduce allocations.
        context.close(promise: nil)
    }
    
}

internal final class WebSocketMessageOutboundHandler: ChannelOutboundHandler {
    internal typealias OutboundIn = WebSocketWireEnvelope
    internal typealias OutboundOut = WebSocketFrame
    
    internal let actorSystem: WebSocketActorSystem
    
    internal init(actorSystem: WebSocketActorSystem) {
        self.actorSystem = actorSystem
        
    }
    
}

extension WebSocketMessageOutboundHandler {
    public func handlerRemoved(context: ChannelHandlerContext) {
        // While we do this, we should also notify the system about any cleanups
        // it might need to do. E.g. if it has receptionist connections to the peer
        // that has now disconnected, we should stop tasks interacting with it etc.
        print("WebSocket handler removed.")
    }
    
    internal func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        log("write", "unwrap \(Self.OutboundIn.self)")
        let envelope: WebSocketWireEnvelope = self.unwrapOutboundIn(data)
        
        switch envelope {
        case .connectionClose:
            var data = context.channel.allocator.buffer(capacity: 2)
            data.write(webSocketErrorCode: .protocolError)
            let frame = WebSocketFrame(fin: true,
                                       opcode: .connectionClose,
                                       data: data)
            context.writeAndFlush(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
                context.close(promise: nil)
            }
        case .reply, .call:
            let encoder = JSONEncoder()
            encoder.userInfo[.actorSystemKey] = actorSystem
            
            do {
                var data = ByteBuffer()
                try data.writeJSONEncodable(envelope, encoder: encoder)
                log("outbound-call", "Write: \(envelope), to: \(context)")
                
                let frame = WebSocketFrame(fin: true, opcode: .text, data: data)
                context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
            } catch {
                log("outbound-call", "Failed to serialize call [\(envelope)], error: \(error)")
            }
        }
    }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Server-side handlers

internal final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
    internal typealias InboundIn = HTTPServerRequestPart
    internal typealias OutboundOut = HTTPServerResponsePart
    
    private var responseBody: ByteBuffer!
    
    internal func handlerAdded(context: ChannelHandlerContext) {
        self.responseBody = context.channel.allocator.buffer(string: """
        <html><head></head><body><h2>oomph-cluster (run id: 618)</h2></body></html>
        """)
    }
    
    internal func handlerRemoved(context: ChannelHandlerContext) {
        self.responseBody = nil
    }
    
    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        log("write", "unwrap \(Self.InboundIn.self)")
        let reqPart = self.unwrapInboundIn(data)
        
        // We're not interested in request bodies here: we're just serving up GET responses
        // to get the client to initiate a websocket request.
        guard case .head(let head) = reqPart else {
            return
        }
        
        // GETs only.
        guard case .GET = head.method else {
            self.respond405(context: context)
            return
        }
        
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html")
        headers.add(name: "Content-Length", value: String(self.responseBody.readableBytes))
        headers.add(name: "Connection", value: "close")
        
        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                            status: .ok,
                                            headers: headers)
        
        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(self.responseBody))), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
            context.close(promise: nil)
        }
        
        context.flush()
    }
    
    private func respond405(context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        headers.add(name: "Connection", value: "close")
        headers.add(name: "Content-Length", value: "0")
        
        let head = HTTPResponseHead(version: .http1_1,
                                    status: .methodNotAllowed,
                                    headers: headers)
        
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
            context.close(promise: nil)
        }
        
        context.flush()
    }
}

internal final class WebSocketActorMessageInboundHandler: ChannelInboundHandler {
    internal typealias InboundIn = WebSocketFrame
    internal typealias OutboundOut = WebSocketWireEnvelope
    
    private var awaitingClose: Bool = false
    
    private let actorSystem: WebSocketActorSystem
    internal init(actorSystem: WebSocketActorSystem) {
        self.actorSystem = actorSystem
    }
    
}

extension WebSocketActorMessageInboundHandler {
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        
        switch frame.opcode {
        case .connectionClose:
            // Close the connection.
            //
            // We might also want to inform the actor system that this connection
            // went away, so it can terminate any tasks or actors working to
            // inform the remote receptionist on the now-gone system about our
            // actors.
            return
        case .text:
            var data = frame.unmaskedData
            let text = data.getString(at: 0, length: data.readableBytes) ?? ""
            log("inbound-call", "Received: \(text), from: \(context)")
            
            actorSystem.decodeAndDeliver(data: &data, from: context.remoteAddress, on: context.channel)
            
        case .binary, .continuation, .pong, .ping:
            // We ignore these frames.
            break
        default:
            // Unknown frames are errors.
            self.closeOnError(context: context)
        }
    }
    
    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
    
    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Handle a received close frame. In websockets, we're just going to send the close
        // frame and then close, unless we already sent our own close frame.
        if awaitingClose {
            // Cool, we started the close and were waiting for the user. We're done.
            context.close(promise: nil)
        } else {
            // This is an unsolicited close. We're going to send a response frame and
            // then, when we've sent it, close up shop. We should send back the close code the remote
            // peer sent us, unless they didn't send one at all.
            _ = context.write(self.wrapOutboundOut(.connectionClose)).map { () in
                context.close(promise: nil)
            }
        }
    }
    
    private func closeOnError(context: ChannelHandlerContext) {
        // We have hit an error, we want to close. We do that by sending a close frame and then
        // shutting down the write side of the connection.
        var data = context.channel.allocator.buffer(capacity: 2)
        data.write(webSocketErrorCode: .protocolError)
        
        context.write(self.wrapOutboundOut(.connectionClose)).whenComplete { (_: Result<Void, Error>) in
            context.close(mode: .output, promise: nil)
        }
        
        awaitingClose = true
    }
    
}


// MARK: - From TikTacFishPackage/Sources/TicTacFishShared/NaiveLogging

internal func debug(_ category: String, _ message: String, file: String = #fileID, line: Int = #line, function: String = #function) {
    // ignore
}

internal func log(_ category: String, _ message: String, file: String = #fileID, line: Int = #line, function: String = #function) {
    print("[\(category)][\(file):\(line)](\(function)) \(message)")
}
