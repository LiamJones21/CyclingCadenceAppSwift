//
//  LocationManagerDelegate.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// LocationManager.swift
// CyclingCadenceApp

import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    weak var delegate: LocationManagerDelegate?
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation?

    func setup() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            delegate?.didUpdateLocation(location)
        }
    }
}




