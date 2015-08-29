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
        var networkStatus: NetworkStatus = reachability.currentReachabilityStatus()
        
        if networkStatus.value == NotReachable.value {
            connectivityStatus = NOT_REACHABLE
        } else if networkStatus.value == ReachableViaWiFi.value {
            connectivityStatus = REACHABLE_WITH_WIFI
        } else if networkStatus.value == ReachableViaWWAN.value {
            connectivityStatus = REACHABLE_WITH_WWAN
        }
        // println("Connectivity changed to \(networkStatus.value): \(connectivityStatus)")
        
        NSNotificationCenter.defaultCenter().postNotificationName(NETWORK_STATUS_NOTIFICATION, object: nil)
    }

    deinit {
        println("deinit Connectivity")
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReachabilityChangedNotification, object: nil)
    }




//    static var reachabilityStatus = 0
//    static var reachabilityStatusDescription = NOT_REACHABLE
//    
//    private struct Constants {
//        static var singleton: Connectivity?
//    }
//    
//    class var one: Connectivity {
//        if Constants.singleton == nil {
//            Constants.singleton = Connectivity()
//        }
//        return Constants.singleton!
//    }
//
//    init() {
//        var internetReach: Reachability = Reachability.reachabilityForInternetConnection()
//        internetReach.startNotifier()
//        
//        setStatusWithReachability(internetReach)
//        
//    }
//
//    func beginObserving() {
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reachabilityChanged:", name: kReachabilityChangedNotification, object: nil)
//    }
//
//    func stopObserving() {
//        println("Connectivity - stopObserving")
//        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReachabilityChangedNotification, object: nil)
//    }
//    
//    func reachabilityChanged(notification: NSNotification) {
//        println("Reachability status changed...")
//        let reachability = notification.object as? Reachability
//        self.setStatusWithReachability(reachability!)
//    }
//
//
//    func setStatusWithReachability(reachability: Reachability) {
//        
//        var networkStatus: NetworkStatus = reachability.currentReachabilityStatus()
//        
//        println("StatusValue = \(networkStatus.value)")
//        if networkStatus.value == NotReachable.value {
//            println("Network Not Reachable")
//            Connectivity.reachabilityStatusDescription = NOT_REACHABLE
//        } else if networkStatus.value == ReachableViaWiFi.value {
//            println("Wi-Fi Network Reachable")
//            Connectivity.reachabilityStatusDescription = REACHABLE_WITH_WIFI
//        } else if networkStatus.value == ReachableViaWWAN.value {
//            println("Cellular Network Reachable")
//            Connectivity.reachabilityStatusDescription = REACHABLE_WITH_WWAN
//        }
//        Connectivity.reachabilityStatus = networkStatus.value
//        
//    }
//
//    deinit {
//        println("deinit Connectivity")
//        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReachabilityChangedNotification, object: nil)
//    }
    
    
    //    func statusChangedWithReachability(reachability: Reachability) {
    //        var networkStatus: NetworkStatus = reachability.currentReachabilityStatus()
    //        var statusString = ""
    //
    //        println("StatusValue = \(networkStatus.value)")
    //        if networkStatus.value == NotReachable.value {
    //            println("Network Not Reachable")
    //            reachabilityStatus = NOT_REACHABLE
    //        } else if networkStatus.value == ReachableViaWiFi.value {
    //            println("Wi-Fi Network Reachable")
    //            reachabilityStatus = REACHABLE_WITH_WIFI
    //        } else if networkStatus.value == ReachableViaWWAN.value {
    //            println("Cellular Network Reachable")
    //            reachabilityStatus = REACHABLE_WITH_WWAN
    //        }
    //
    //        NSNotificationCenter.defaultCenter().postNotificationName("NetworkConnectionChanged", object: nil)
    //    }

}


