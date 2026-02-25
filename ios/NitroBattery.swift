//
//  HybridNitroBattery.swift
//  Pods
//
//  Created by tconns94 on 22/09/2025.
//

import UIKit

class NitroBattery: HybridNitroBatterySpec {
  private var batteryStateListeners: [BatteryListenerBox] = []
  private var lowPowerListeners: [LowPowerListenerBox] = []
  private var listenerIdCounter: Int = 0
  private let listenerQueue = DispatchQueue(label: "com.nitrobattery.listeners", attributes: .concurrent)

  override init() {
    super.init()
    setupBatteryMonitoring()
    setupNotificationObservers()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    UIDevice.current.isBatteryMonitoringEnabled = false
  }

  // MARK: - Setup Methods

  private func setupBatteryMonitoring() {
    UIDevice.current.isBatteryMonitoringEnabled = true
  }

  private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(batteryStateDidChange),
      name: UIDevice.batteryStateDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(batteryLevelDidChange),
      name: UIDevice.batteryLevelDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(lowPowerModeChanged),
      name: Notification.Name.NSProcessInfoPowerStateDidChange,
      object: nil
    )
  }

  // MARK: - Public API

  func getLevel() -> Double {
    let level = UIDevice.current.batteryLevel
    // Return -1 if battery level is unavailable
    return level < 0 ? -1 : Double(level * 100)
  }

  func isCharging() -> Bool {
    let state = UIDevice.current.batteryState
    return state == .charging || state == .full
  }

  func isLowPowerModeEnabled() -> Bool {
    return ProcessInfo.processInfo.isLowPowerModeEnabled
  }

  func addBatteryStateListener(listener: @escaping (String) -> Void) throws {
    let box = BatteryListenerBox(listener)
    listenerQueue.async(flags: .barrier) {
      self.batteryStateListeners.append(box)
    }
  }

  func removeBatteryStateListener(listener: @escaping (String) -> Void) throws {
    listenerQueue.async(flags: .barrier) {
      self.batteryStateListeners.removeAll {
        $0.listener as AnyObject === listener as AnyObject
      }
    }
  }

  func addLowPowerListener(listener: @escaping () -> Void) throws {
    let box = LowPowerListenerBox(listener)
    listenerQueue.async(flags: .barrier) {
      self.lowPowerListeners.append(box)
    }
  }

  func removeLowPowerListener(listener: @escaping () -> Void) throws {
    listenerQueue.async(flags: .barrier) {
      self.lowPowerListeners.removeAll {
        $0.listener as AnyObject === listener as AnyObject
      }
    }
  }

  func removeAllListeners() {
    listenerQueue.async(flags: .barrier) {
      self.batteryStateListeners.removeAll()
      self.lowPowerListeners.removeAll()
    }
  }

  private func notifyBatteryStateListeners(state: String) {
    listenerQueue.async {
      let listeners = self.batteryStateListeners.map { $0.listener }
      DispatchQueue.main.async {
        listeners.forEach { $0(state) }
      }
    }
  }

  private func notifyLowPowerListeners() {
    listenerQueue.async {
    let listeners = self.lowPowerListeners.map { $0.listener }
      DispatchQueue.main.async {
        listeners.forEach { $0() }
      }
    }
  }

  // MARK: - Notification Handlers

  @objc private func batteryStateDidChange() {
    let state = getBatteryState()
    notifyBatteryStateListeners(state: state)
  }

  @objc private func batteryLevelDidChange() {
    // Optionally notify about level changes
    let state = getBatteryState()
    notifyBatteryStateListeners(state: state)
  }

  @objc private func lowPowerModeChanged() {
    if ProcessInfo.processInfo.isLowPowerModeEnabled {
      notifyLowPowerListeners()
    }
  }

  func getBatteryState() -> String {
    switch UIDevice.current.batteryState {
      case .charging: return "charging"
      case .full: return "full"
      case .unplugged: return "discharging"
      default: return "unknown"
    }
  }

  private class BatteryListenerBox {
    let listener: (String) -> Void
    init(_ l: @escaping (String) -> Void) { listener = l }
  }

  private class LowPowerListenerBox {
    let listener: () -> Void
    init(_ l: @escaping () -> Void) { listener = l }
  }
}
