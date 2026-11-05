// Edgy haptic feel test: plays each trackpad actuation pattern so you can pick favourites.
import Foundation
typealias CreateDefault = @convention(c) () -> UnsafeMutableRawPointer?
typealias GetDeviceID = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt64>) -> Int32
typealias ActCreate = @convention(c) (UInt64) -> Unmanaged<CFTypeRef>?
typealias ActOpen = @convention(c) (CFTypeRef) -> Int32
typealias ActActuate = @convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32
typealias ActClose = @convention(c) (CFTypeRef) -> Int32
let bundle = CFBundleCreate(nil, URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MultitouchSupport.framework") as CFURL)!
func fn<T>(_ n: String, _ t: T.Type) -> T { unsafeBitCast(CFBundleGetFunctionPointerForName(bundle, n as CFString)!, to: t) }
let device = fn("MTDeviceCreateDefault", CreateDefault.self)()
var id: UInt64 = 0
print("device id status:", fn("MTDeviceGetDeviceID", GetDeviceID.self)(device, &id), "id:", id)
guard let act = fn("MTActuatorCreateFromDeviceID", ActCreate.self)(id)?.takeRetainedValue() else { print("no actuator"); exit(1) }
print("open:", fn("MTActuatorOpen", ActOpen.self)(act))
let actuate = fn("MTActuatorActuate", ActActuate.self)
print("Rest a finger lightly on the trackpad. Playing patterns in 2 s…"); sleep(2)
for pattern: Int32 in [1, 2, 3, 4, 5, 6, 15, 16] {
  print("pattern \(pattern):", actuate(act, pattern, 0, 0, 0) == 0 ? "played" : "failed")
  Thread.sleep(forTimeInterval: 1.2)
}
_ = fn("MTActuatorClose", ActClose.self)(act)
