/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Server side implementation of the WebSocket Actor System.
*/

import Distributed
import Foundation
import NIO
import NIOConcurrencyHelpers
#if os(iOS) || os(macOS) || os(watchOS)
import NIOTransportServices
#endif
import NIOCore
import NIOHTTP1
import NIOWebSocket
import NIOFoundationCompat

// ==== ----------------------------------------------------------------------------------------------------------------
// - MARK: Server-side networking stack

extension WebSocketActorSystem {
    internal func startServer(host: String, port: Int) throws -> any Channel {
        #if os(iOS) || os(macOS) || os(watchOS)
        // Upgrader performs upgrade from HTTP to WS connection
        let upgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { (channel: any Channel, head: HTTPRequestHead) in
                // Always upgrade; this is where we could do some auth checks
                channel.eventLoop.makeSucceededFuture(HTTPHeaders())
            },
            upgradePipelineHandler: { (channel: any Channel, _: HTTPRequestHead) in
                channel.pipeline.addHandlers(
                    WebSocketMessageOutboundHandler(actorSystem: self),
                    WebSocketActorMessageInboundHandler(actorSystem: self)
                )
            }
        )
        
        let bootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer { channel in
                let httpHandler = HTTPHandler()
                let config: NIOHTTPServerUpgradeConfiguration = (
                    upgraders: [upgrader],
                    completionHandler: { _ in
                        channel.pipeline.removeHandler(httpHandler, promise: nil)
                    }
                )
                return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            }
        
            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        let channel = try bootstrap.bind(host: host, port: port).wait()
        
        guard channel.localAddress != nil else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        
        return channel
        
        #else
        struct UnsupportedPlatformError: Error { }
        throw UnsupportedPlatformError()
        
        #endif
    }
    
}
