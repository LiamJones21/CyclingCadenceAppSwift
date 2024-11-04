//
//  HealthKitManagerDelegate.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/3/24.
// HealthKitManager.swift
// CyclingCadenceApp

import Foundation
import HealthKit

// Import Protocols
import CoreMotion
import CoreLocation

class HealthKitManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    weak var delegate: HealthKitManagerDelegate?
    private let healthStore = HKHealthStore()
    var workoutSession: HKWorkoutSession?
    var workoutBuilder: HKLiveWorkoutBuilder?
    var workoutStartTime: Date?

    func authorizeHealthKit() {
        let typesToShare: Set = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set = [
            HKObjectType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization successful.")
            } else {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "No error")")
            }
        }
    }

    func startWorkout() {
        guard workoutSession == nil else { return }
        workoutStartTime = Date()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date(), completion: { (success, error) in
                // Handle errors if needed
            })
            delegate?.didStartWorkout()
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }

    func stopWorkout() {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        workoutStartTime = nil
        session.end()
        builder.endCollection(withEnd: Date(), completion: { (success, error) in
            // Handle errors if needed
            self.workoutSession = nil
            self.workoutBuilder = nil
            self.delegate?.didEndWorkout()
        })
    }

    // HKWorkoutSessionDelegate methods
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle state changes if needed
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }

    // HKLiveWorkoutBuilderDelegate methods
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle events if needed
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Handle collected data if needed
    }
}
