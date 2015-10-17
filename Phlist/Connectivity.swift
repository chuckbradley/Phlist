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
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "reachabilityChanged:",
            name: kReachabilityChangedNotification,
            object: nil)
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

        NSNotificationCenter.defaultCenter().postNotificationName(NETWORK_STATUS_NOTIFICATION, object: nil)
    }

    deinit {
        print("\ndeinit Connectivity")
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReachabilityChangedNotification, object: nil)
    }



/* to add observer for NETWORK_STATUS_NOTIFICATION:

// in viewDidLoad or didFinishLaunching...
     NSNotificationCenter.defaultCenter().addObserver(self, selector: "connectivityChanged", name: NETWORK_STATUS_NOTIFICATION, object: nil)

// add handler method:
    func connectivityChanged() {
        // do something with the connectivityStatus...
        print("connectivityChanged to \(connectivityStatus)")
    }

// in deinit:
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NETWORK_STATUS_NOTIFICATION, object: nil)
    }

*/


}


