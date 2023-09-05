// SquigglyServiceDiscovery.swift
// 23 jul 16

import Dispatch
import DistributedCluster
import ServiceDiscovery

public class SquigglyServiceDiscovery: ServiceDiscovery {
    public typealias Service = String
    public typealias Instance = Cluster.Endpoint
    
    public var defaultLookupTimeout: DispatchTimeInterval = .seconds(5)
    private let _serviceDiscovery: InMemoryServiceDiscovery<Service, Instance>
    
    public init() {
        _serviceDiscovery = .init(configuration: .default)
        _serviceDiscovery.register("lol.vola.squiggly", instances: [
            .productCluster(.lilBish),
            .productCluster(.lilBook),
        ])
        
    }
    
}

extension SquigglyServiceDiscovery {
    public func lookup(
        _ service: Service,
        deadline: DispatchTime?,
        callback: @escaping (Result<[Instance], any Error>) -> Void
    ) {
        _serviceDiscovery.lookup(service, deadline: deadline, callback: callback)
    }
    
    public func subscribe(
        to service: String,
        onNext nextResultHandler: @escaping (Result<[Cluster.Endpoint], any Error>) -> Void,
        onComplete completionHandler: @escaping (CompletionReason) -> Void
    ) -> CancellationToken {
        _serviceDiscovery.subscribe(to: service, onNext: nextResultHandler, onComplete: completionHandler)
    }
    
}


// MARK: - Discovery Settings

extension ServiceDiscoverySettings {
    public static var squiggly: ServiceDiscoverySettings? {
        return ServiceDiscoverySettings(
            SquigglyServiceDiscovery(),
            service: "lol.vola.squiggly"
        )
    }
    
}

