// VolaServiceDiscovery.swift
// 23 jul 16

import Dispatch
import DistributedCluster
import ServiceDiscovery

public class VolaServiceDiscovery: ServiceDiscovery {
    public typealias Service = String
    public typealias Instance = Cluster.Endpoint
    
    public var defaultLookupTimeout: DispatchTimeInterval = .seconds(5)
    private let _serviceDiscovery: InMemoryServiceDiscovery<Service, Instance>
    
    public init() {
        _serviceDiscovery = .init(configuration: .default)
        _serviceDiscovery.register("lol.vola", instances: [
            .productCluster(host: .lilBish),
            .productCluster(host: .lilBook),
            
        ])
        
    }
    
}

extension VolaServiceDiscovery {
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

extension VolaServiceDiscovery {
    public static var _volaServices: ServiceDiscoverySettings? {
        return ServiceDiscoverySettings(
            VolaServiceDiscovery(),
            service: "lol.vola.squiggly"
        )
    }
    
}


// MARK: -

extension Cluster.Endpoint {
    fileprivate enum OomphHost {
        case lilBish
        case lilBook
        
    }
    
    fileprivate static func productCluster(host: OomphHost, usePrimaryPort: Bool = true) -> Self {
        .init(host: host.hostName, port: usePrimaryPort ? 9101 : 9103)
    }
    
    fileprivate static func inventoryCluster(host: OomphHost, usePrimaryPort: Bool = true) -> Self {
        .init(host: host.hostName, port: usePrimaryPort ? 9102 : 9104)
    }
    
}

extension Cluster.Endpoint.OomphHost {
    fileprivate var hostName: String {
        switch self {
        case .lilBish:
            VolaCluster.WellKnownDevice.lilBish.rawValue
            
        case .lilBook:
            VolaCluster.WellKnownDevice.lilBook.rawValue
        }
    }
    
}
