import Foundation

public extension String {
    func deletePrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
    
    /// A data representation of the hexadecimal bytes in this string.
    func hexDecodedData() -> Data {
      // Get the UTF8 characters of this string
      let chars = Array(utf8)

      // Keep the bytes in an UInt8 array and later convert it to Data
      var bytes = [UInt8]()
      bytes.reserveCapacity(count / 2)

      // It is a lot faster to use a lookup map instead of strtoul
      let map: [UInt8] = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
        0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
        0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // HIJKLMNO
      ]

      // Grab two characters at a time, map them and turn it into a byte
      for i in stride(from: 0, to: count, by: 2) {
        let index1 = Int(chars[i] & 0x1F ^ 0x10)
        let index2 = Int(chars[i + 1] & 0x1F ^ 0x10)
        bytes.append(map[index1] << 4 | map[index2])
      }

      return Data(bytes)
    }
}
