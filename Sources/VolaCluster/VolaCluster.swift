import DistributedCluster

extension Cluster {
    public typealias Vola = VolaCluster
    
}

public struct VolaCluster {
    public enum WellKnownDevice: String, CaseIterable {
        // debug
        case lilBish = "100.65.195.83"
        case lilBook = "100.116.244.41"
        case lilPhone = "100.96.40.91"
        
        // production
        case doc = "100.103.224.86"
        case docMcFly = "100.81.142.40"
        
    }

    public enum InstanceRole {
        case productServer
        case inventoryServer
        case productClient
        case inventoryClient
        
        case tentpole
        
    }

    public enum Port: Int, CaseIterable {
        case tentpoleServer = 9100
        case productServer = 9101
        case productServerInventoryServerClient = 9102 // inventory server is the client
        case productServerMobileClient = 9103
        
    }
    
    public let name = "lol.vola.squiggly"
    
    private let role: InstanceRole
    
    public let tentpoleServer: (device: WellKnownDevice, port: Port) = (.docMcFly, .tentpoleServer)
    
    private let currentDevice: WellKnownDevice

    public func connectToPeers(on clusterSystem: ClusterSystem) async throws {
        guard role != .tentpole else { return }
        
        try await clusterSystem.cluster.joined(
            endpoint: self.endpoint(for: \.tentpoleServer),
            within: .seconds(8))
    }
    
    @_spi(MayoInternal)
    public func waitForAllPeers() async throws {
        let clusterSystem = await ClusterSystem(self)
        try await clusterSystem.terminated
    }
    
    public init(currentDevice: WellKnownDevice, role: InstanceRole) {
        self.currentDevice = currentDevice
        self.role = role
        
    }

}


extension VolaCluster {
    public var currentDeviceEndpoint: Cluster.Endpoint {
        .init(host: currentDevice.rawValue, port: port(for: role).rawValue)
    }
    
    public func endpoint(for endpointKeyPath: KeyPath<VolaCluster, (device: WellKnownDevice, port: Port)>) -> Cluster.Endpoint {
        let (device, port) = self[keyPath: endpointKeyPath]
        return .init(host: device.rawValue, port: port.rawValue)
    }
    
    private func port(for role: InstanceRole) -> Port {
        switch role {
        case .productServer:
            return .productServer
        case .inventoryServer:
            return .productServerInventoryServerClient
        case .productClient:
            return .productServerMobileClient
        case .inventoryClient:
            fatalError()
        case .tentpole:
            return .tentpoleServer
        }
    }
    
}


// MARK: - Helper Extensions

extension ClusterSystem {
    public convenience init(
        _ cluster: VolaCluster,
        configuredWith configureSettings: (inout ClusterSystemSettings) -> Void = { _ in () }
    ) async {
        await self.init(cluster.name) { settings in
            settings.endpoint = cluster.currentDeviceEndpoint
            configureSettings(&settings)
        }
    }

}
