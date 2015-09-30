//
//  Connectivity.swift
//  Phlist
//
//  Created by Chuck Bradley on 8/8/15.
//  Copyright (c) 2015 FreedomMind. All rights reserved.
//

import Foundation
import UIKit

let NOT_REACHABLE = "NotReachable"
let REACHABLE_WITH_WIFI = "ReachableWithWiFi"
let REACHABLE_WITH_WWAN = "ReachableWithWWAN"

let NETWORK_STATUS_NOTIFICATION = "NetworkConnectionChanged"

var connectivityStatus = NOT_REACHABLE

class Connectivity: NSObject {
    static let one = Connectivity()

    var internetReach:Reachability?

    override init() {
        super.init()

        internetReach = Reachability.reachabilityForInternetConnection()
        
        internetReach?.startNotifier()
        
        if internetReach != nil {
            self.statusChangedWithReachability(internetReach!)
        }

        // observe kReachabilityChangedNotification (defined in Reachability.h)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reachabilityChanged:", name: kReachabilityChangedNotification, object: nil)
        
    }

    func reachabilityChanged(notification: NSNotification) {
        if let reachability = notification.object as? Reachability {
            self.statusChangedWithReachability(reachability)
        }
    }
    
    func statusChangedWithReachability(reachability: Reachability) {
        let networkStatus: NetworkStatus = reachability.currentReachabilityStatus()
        
        if networkStatus.rawValue == NotReachable.rawValue {
            connectivityStatus = NOT_REACHABLE
        } else if networkStatus.rawValue == ReachableViaWiFi.rawValue {
            connectivityStatus = REACHABLE_WITH_WIFI
        } else if networkStatus.rawValue == ReachableViaWWAN.rawValue {
            connectivityStatus = REACHABLE_WITH_WWAN
        }
        // println("Connectivity changed to \(networkStatus.value): \(connectivityStatus)")
        
        NSNotificationCenter.defaultCenter().postNotificationName(NETWORK_STATUS_NOTIFICATION, object: nil)
    }

    deinit {
        print("deinit Connectivity")
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReachabilityChangedNotification, object: nil)
    }


}


