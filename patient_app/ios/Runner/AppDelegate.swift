import UIKit
import Flutter
import GoogleMaps  // Add this

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add this line with your API key
    GMSServices.provideAPIKey("AIzaSyBByqCokx-QHlal39-TCh9-HbpnMe6kz4M")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}