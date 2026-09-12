import CoreLocation

/// Background residency via the location background mode. Coarse accuracy and a huge distance
/// filter: we want the process alive, not the position. Needs UIBackgroundModes=location.
final class KeepAlive: NSObject, CLLocationManagerDelegate {
    static let shared = KeepAlive()
    private let lm = CLLocationManager()

    var status: CLAuthorizationStatus { lm.authorizationStatus }

    func start() {
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        lm.distanceFilter = CLLocationDistanceMax
        lm.pausesLocationUpdatesAutomatically = false
        lm.allowsBackgroundLocationUpdates = true
        lm.showsBackgroundLocationIndicator = false
        lm.requestAlwaysAuthorization()
        lm.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in Log.shared.add("location error: \(error.localizedDescription)") }
    }
}
