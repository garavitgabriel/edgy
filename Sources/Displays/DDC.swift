import Foundation

/// DDC/CI message framing (VESA DDC/CI over I²C). Pure: no I/O, fully unit-tested.
///
/// Host → monitor messages go to I²C destination `0x6E` (7-bit address `0x37`) and start with the
/// host's source address `0x51`, then a length byte (`0x80 | payload count`), the payload and a
/// checksum. The checksum is the XOR of every byte of the message *including the destination
/// address*, which is sent by the I²C layer rather than being part of the buffer.
///
/// Monitor → host replies start with the monitor's source address `0x6E`; their checksum XORs in
/// the host's virtual destination address `0x50` instead.
enum DDC {
  /// 7-bit I²C address of the DDC/CI channel on every monitor.
  static let chipAddress: UInt8 = 0x37
  /// Destination byte of host → monitor messages (`chipAddress << 1`).
  static let writeDestination: UInt8 = 0x6E
  /// Source address the host puts first in every message.
  static let hostSource: UInt8 = 0x51
  /// Virtual destination the monitor addresses its replies to (for the checksum).
  static let replyDestination: UInt8 = 0x50
  /// Length byte flag: the low bits carry the payload count.
  static let lengthFlag: UInt8 = 0x80

  static let getVCPOpcode: UInt8 = 0x01
  static let getVCPReplyOpcode: UInt8 = 0x02
  static let setVCPOpcode: UInt8 = 0x03

  /// VCP code for luminance (brightness).
  static let luminance: UInt8 = 0x10

  /// Bytes in a complete get-VCP reply: source, length, 8 payload bytes, checksum.
  static let getVCPReplyLength = 11

  static func checksum(_ bytes: some Sequence<UInt8>, seed: UInt8) -> UInt8 {
    bytes.reduce(seed, ^)
  }

  /// A host → monitor message, starting with the host source address `0x51`.
  static func message(_ payload: [UInt8]) -> [UInt8] {
    var bytes: [UInt8] = [hostSource, lengthFlag | UInt8(payload.count)] + payload
    bytes.append(checksum(bytes, seed: writeDestination))
    return bytes
  }

  static func getVCPRequest(_ code: UInt8) -> [UInt8] {
    message([getVCPOpcode, code])
  }

  static func setVCP(_ code: UInt8, value: UInt16) -> [UInt8] {
    message([setVCPOpcode, code, UInt8(value >> 8), UInt8(value & 0xFF)])
  }

  /// Current and maximum value of one VCP feature, as reported by the monitor.
  struct VCPValue: Equatable, Sendable {
    var current: UInt16
    var maximum: UInt16
  }

  enum ReplyError: Error, Equatable, Sendable {
    /// Fewer bytes than a full reply (the monitor said nothing useful).
    case tooShort(Int)
    /// The checksum didn't match: a garbled transfer, worth retrying.
    case badChecksum
    /// A reply, but not to a get-VCP request (or a malformed length byte).
    case unexpectedOpcode(UInt8)
    /// A get-VCP reply for a different feature than asked for.
    case wrongCode(expected: UInt8, got: UInt8)
    /// The monitor understood the request but does not support this feature.
    case unsupported(UInt8)
  }

  /// Parses a get-VCP reply for `code`. Extra trailing bytes (some transports pad reads) are ignored.
  static func parseGetVCPReply(_ bytes: [UInt8], code: UInt8) throws(ReplyError) -> VCPValue {
    guard bytes.count >= getVCPReplyLength else { throw .tooShort(bytes.count) }
    let reply = Array(bytes.prefix(getVCPReplyLength))
    guard checksum(reply.prefix(getVCPReplyLength - 1), seed: replyDestination) == reply[10] else {
      throw .badChecksum
    }
    guard reply[1] == lengthFlag | 8, reply[2] == getVCPReplyOpcode else { throw .unexpectedOpcode(reply[2]) }
    guard reply[4] == code else { throw .wrongCode(expected: code, got: reply[4]) }
    guard reply[3] == 0 else { throw .unsupported(code) }
    return VCPValue(
      current: UInt16(reply[8]) << 8 | UInt16(reply[9]),
      maximum: UInt16(reply[6]) << 8 | UInt16(reply[7]))
  }
}
