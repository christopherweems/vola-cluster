import DistributedCluster

extension Cluster.Endpoint {
    public enum _VolaHost {
        case lilBish
        case lilBook
        
    }
    
    public static func productCluster(_ host: _VolaHost, usePrimaryPort: Bool = true) -> Self {
        .init(host: host.hostName, port: usePrimaryPort ? 9101 : 9103)
    }
    
    public static func inventoryCluster(_ host: _VolaHost, usePrimaryPort: Bool = true) -> Self {
        .init(host: host.hostName, port: usePrimaryPort ? 9102 : 9104)
    }
    
}


// MARK: - Helper Extensions

extension Cluster.Endpoint._VolaHost {
    fileprivate var hostName: String {
        switch self {
        case .lilBish:
            "100.65.195.83"
            
        case .lilBook:
            "100.116.244.41"
        }
    }
    
}
