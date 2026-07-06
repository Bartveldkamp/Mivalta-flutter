import Flutter
import UIKit
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Round 3 items 11+18: weather channel host — kept alive for the app's
  // lifetime so CLLocationManager callbacks have a delegate.
  private var weatherChannel: MivaltaWeatherChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeAppDataFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// DECISIONS Entry AM, invariant I-7 (mivalta-rust-engine
  /// docs/DECISIONS.md): platform backups must be vault-free. The vault
  /// lives in Application Support (Dart roots `vaultPath` at
  /// `getApplicationSupportDirectory()`), where the SQLCipher key files
  /// (`vault.key`, `cache.key`) sit BESIDE the ciphertext they protect — an
  /// iCloud/Finder backup would carry keys + ciphertext together, and a
  /// retained backup defeats crypto-erasure (destroying the on-device key
  /// cannot destroy the copy inside an old backup). Excluding the directory
  /// covers its whole subtree, including files created later. Device
  /// migration is served by the V5 encrypted vault export/import, never by
  /// platform backup.
  private func excludeAppDataFromBackup() {
    let fm = FileManager.default
    guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      NSLog("MiValta: Application Support not found — backup exclusion NOT applied")
      return
    }
    do {
      try fm.createDirectory(at: support, withIntermediateDirectories: true)
      var url = support
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
    } catch {
      // Loud in the log, non-fatal for launch: the exclusion is defense in
      // depth on top of the vault's own encryption.
      NSLog("MiValta: failed to exclude app data from backup: \(error)")
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MivaltaWeather") {
      weatherChannel = MivaltaWeatherChannel(messenger: registrar.messenger())
    }
  }
}

/// DR-024 W2: Weather channel with manual place support.
///
/// Round 3 items 11+18 (FOUNDER_FEEDBACK_2026-06-12): local weather via Apple
/// WeatherKit — the founder-approved OS-LEVEL exception to the no-cloud rule
/// (CLAUDE.md rule 6). The fetch runs entirely through Apple's OS frame
/// (CoreLocation one-shot + WeatherKit); MiValta servers are never involved.
/// Every failure path returns a FlutterError so the Dart side renders honest
/// absence (no icon) instead of fabricated conditions.
///
/// Methods:
///   - getWeatherAt(lat, lon): Fetch weather for specific coordinates (manual place)
///   - getWeatherWithGPS: Fetch weather using GPS (for GPS opt-in users)
class MivaltaWeatherChannel: NSObject, CLLocationManagerDelegate {
  private let channel: FlutterMethodChannel
  private let locationManager = CLLocationManager()
  private var pending: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mivalta/weather", binaryMessenger: messenger)
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "channel host gone", details: nil))
        return
      }
      switch call.method {
      case "getWeatherAt":
        // DR-024 W2: Fetch weather for specific coordinates (manual place).
        guard let args = call.arguments as? [String: Any],
              let lat = args["latitude"] as? Double,
              let lon = args["longitude"] as? Double else {
          result(FlutterError(code: "invalid_args", message: "latitude and longitude required", details: nil))
          return
        }
        self.getWeatherAt(latitude: lat, longitude: lon, result: result)
      case "getWeatherWithGPS":
        // DR-024 W2: Fetch weather using GPS (for GPS opt-in users).
        self.getWeatherWithGPS(result: result)
      case "getWeather":
        // Legacy method — still supported for backwards compatibility.
        // Prefer getWeatherAt or getWeatherWithGPS for new code.
        self.getWeatherWithGPS(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// DR-024 W2: Fetch weather for specific coordinates (manual place).
  /// No GPS permission required — coordinates provided by caller.
  private func getWeatherAt(latitude: Double, longitude: Double, result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported", message: "WeatherKit requires iOS 16+", details: nil))
      return
    }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "weather fetch already in flight", details: nil))
      return
    }
    pending = result
    let location = CLLocation(latitude: latitude, longitude: longitude)
    fetchWeather(for: location)
  }

  /// Fetch weather using GPS location (requires location permission).
  private func getWeatherWithGPS(result: @escaping FlutterResult) {
    guard #available(iOS 16.0, *) else {
      result(FlutterError(code: "unsupported", message: "WeatherKit requires iOS 16+", details: nil))
      return
    }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "weather fetch already in flight", details: nil))
      return
    }
    pending = result
    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      locationManager.requestLocation()
    default:
      finish(error: FlutterError(code: "denied", message: "location permission denied", details: nil))
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // This delegate method only fires on iOS 14+; the guard exists purely to
    // satisfy availability checking with the app's lower deployment target.
    // The feature itself is iOS 16+ (gated in getWeatherWithGPS).
    guard #available(iOS 14.0, *), pending != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied, .restricted:
      finish(error: FlutterError(code: "denied", message: "location permission denied", details: nil))
    default:
      break  // .notDetermined — waiting on the user's choice.
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, pending != nil else { return }
    fetchWeather(for: location)
  }

  /// Common weather fetch logic used by both coordinate-based and GPS-based methods.
  private func fetchWeather(for location: CLLocation) {
    if #available(iOS 16.0, *) {
      Task {
        do {
          let weather = try await WeatherService.shared.weather(for: location)
          let daily: [[String: Any]] = weather.dailyForecast.prefix(7).map { day in
            [
              "date": Self.dayFormatter.string(from: day.date),
              "symbol": day.symbolName,
              "condition": day.condition.description,
              "highC": day.highTemperature.converted(to: .celsius).value,
              "lowC": day.lowTemperature.converted(to: .celsius).value,
            ]
          }
          let payload: [String: Any] = [
            "symbol": weather.currentWeather.symbolName,
            "condition": weather.currentWeather.condition.description,
            "temperatureC": weather.currentWeather.temperature.converted(to: .celsius).value,
            "daily": daily,
          ]
          DispatchQueue.main.async { self.finish(success: payload) }
        } catch {
          DispatchQueue.main.async {
            self.finish(error: FlutterError(code: "weatherkit", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(error: FlutterError(code: "location", message: error.localizedDescription, details: nil))
  }

  private func finish(success payload: [String: Any]) {
    pending?(payload)
    pending = nil
  }

  private func finish(error: FlutterError) {
    pending?(error)
    pending = nil
  }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
  }()
}
