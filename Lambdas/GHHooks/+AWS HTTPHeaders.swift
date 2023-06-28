import AWSLambdaEvents

extension AWSLambdaEvents.HTTPHeaders {
    public func first(name: String) -> String? {
        guard !self.isEmpty else {
            return nil
        }

        return self.first { $0.0.utf8.compareCaseInsensitiveASCIIBytes(to: name.utf8) }?.1
    }
}

private extension Sequence where Self.Element == UInt8 {
    /// Compares the collection of `UInt8`s to a case insensitive collection.
    ///
    /// This collection could be get from applying the `UTF8View`
    ///   property on the string protocol.
    ///
    /// - Parameter bytes: The string constant in the form of a collection of `UInt8`
    /// - Returns: Whether the collection contains **EXACTLY** this array or no, but by ignoring case.
    func compareCaseInsensitiveASCIIBytes<T: Sequence>(to: T) -> Bool
    where T.Element == UInt8 {
        // fast path: we can get the underlying bytes of both
        let maybeMaybeResult = self.withContiguousStorageIfAvailable { lhsBuffer -> Bool? in
            to.withContiguousStorageIfAvailable { rhsBuffer in
                if lhsBuffer.count != rhsBuffer.count {
                    return false
                }

                for idx in 0 ..< lhsBuffer.count {
                    // let's hope this gets vectorised ;)
                    if lhsBuffer[idx] & 0xdf != rhsBuffer[idx] & 0xdf {
                        return false
                    }
                }
                return true
            }
        }

        if let maybeResult = maybeMaybeResult, let result = maybeResult {
            return result
        } else {
            return self.elementsEqual(to, by: {return ($0 & 0xdf) == ($1 & 0xdf)})
        }
    }
}
