import DistributedCluster

extension Cluster {
    struct Vola {
        enum WellKnownDevice: String, CaseIterable {
            #if DEBUG
            case lilBish = "100.65.195.83"
            case lilBook = "100.116.244.41"
            
            #else
            case doc = "100.103.224.86"
            
            #endif
            
        }
        
        enum Port: Int, CaseIterable {
            case productServer = 9101
            case inventoryServer = 9102
            case productServerClient = 9103
            case inventoryServerClient = 9104
            
        }
        
        private let _currentDevice: WellKnownDevice
        let productServer: (device: WellKnownDevice, port: Port)
        let inventoryServer: (device: WellKnownDevice, port: Port)
        
        func endpoint(for endpointKeyPath: KeyPath<Cluster.Vola, (device: WellKnownDevice, port: Port)>) -> Cluster.Endpoint {
            let (device, port) = self[keyPath: endpointKeyPath]
            return .init(host: device.rawValue, port: port.rawValue)
        }
        
        private var currentDevice: WellKnownDevice {
            @storageRestrictions(initializes: productServer, inventoryServer, _currentDevice)
            init {
                self._currentDevice = newValue
                
                switch newValue {
                case .lilBook:
                    #if BUILD_LIL_BISH_SERVER
                    productServer = (.lilBish, .productServer)
                    inventoryServer = (.lilBish, .inventoryServer)
                    #else
                    productServer = (.lilBook, .productServer)
                    inventoryServer = (.lilBook, .inventoryServer)
                    #endif
                    
                case .lilBish:
                    productServer = (.lilBook, .productServer)
                    inventoryServer = (.lilBook, .inventoryServer)
                    
                #if !DEBUG
                case .doc:
                    productServer = (.doc, .productServer)
                    inventoryServer = (.doc, .inventoryServer)
                    
                #endif
                }
            }
            get {
                _currentDevice
            }
        }
        
        func connectToPeers<ActorSystem>(on actorSystem: ActorSystem) async throws {
            #if BUILD_WEB_SOCKET_ACTOR_SYSTEM
            // as you were
            return
            
            #elseif BUILD_DISTRIBUTED_CLUSTER_SYSTEM
            // cluster.
            
            #endif
        }
        
        init(currentDevice: WellKnownDevice) async {
            self.currentDevice = currentDevice
            
        }
        
        
    }
    
    
}
