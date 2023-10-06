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
        case productServer = 9101
        case productServerInventoryServerClient = 9102 // inventory server is the client
        case productServerMobileClient = 9103
        
    }
    
    public let name = "lol.vola.squiggly"
    
    private let role: InstanceRole

    public let productServer: (device: WellKnownDevice, port: Port)

    private let currentDevice: WellKnownDevice

    public func connectToPeers(on clusterSystem: ClusterSystem) async throws {
        // connect to the peers this node depends on base on its role
        switch role {
        case .inventoryServer, .inventoryClient, .productClient:
            let productServerEndpoint = self.endpoint(for: \.productServer)

            clusterSystem.cluster.join(endpoint: productServerEndpoint)
            try await clusterSystem.cluster.joined(endpoint: productServerEndpoint, within: .seconds(8))

        default:
            break
        }

    }
    
    @_spi(MayoInternal)
    public func waitForAllPeers() async throws {
        let clusterSystem = await ClusterSystem(self)
        try await clusterSystem.terminated
    }
    
    public init(currentDevice: WellKnownDevice, role: InstanceRole) {
        self.currentDevice = currentDevice
        self.role = role
        
        #if DEBUG
        #if BUILD_LIL_BISH_SERVER
        productServer = (.lilBish, .productServer)
        #else
        productServer = (.lilBook, .productServer)
        #endif
        
        #elseif !DEBUG
        productServer = (.doc, .productServer)
        #endif
        
    }

}


extension VolaCluster {
    public func endpoint(for endpointKeyPath: KeyPath<VolaCluster, (device: WellKnownDevice, port: Port)>) -> Cluster.Endpoint {
        let (device, port) = self[keyPath: endpointKeyPath]
        return .init(host: device.rawValue, port: port.rawValue)
    }

    public func endpoint(forConnectingTo endpointKeyPath: KeyPath<VolaCluster, (device: WellKnownDevice, port: Port)>) -> Cluster.Endpoint {
        let port: Port

        switch(currentDevice, role, endpointKeyPath) {
        case (_, .inventoryServer, \.productServer),
            (_, .inventoryClient, \.productServer):
            port = .productServerInventoryServerClient

        case (_, .productClient, \.productServer):
            port = .productServerMobileClient

        default:
            fatalError()
        }


        return .init(host: currentDevice.rawValue, port: port.rawValue)
    }

}


// MARK: - Helper Extensions

extension ClusterSystem {
    public convenience init(
        _ cluster: VolaCluster,
        configuredWith configureSettings: (inout ClusterSystemSettings) -> Void = { _ in () }
    ) async {
        await self.init(cluster.name, configuredWith: configureSettings)
    }

}
