// VolaClusterSystemProvider.swift
// 23 sep 5

import DistributedCluster

public protocol VolaClusterSystemProvider {
    var clusterSystem: ClusterSystem { get throws }
    func connectToCluster() async throws
    
}

public enum VolaClusterSystemProviderError: Error {
    case clusterSystemUninitialized
    
}
