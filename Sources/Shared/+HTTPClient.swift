import AsyncHTTPClient

extension HTTPClient.Configuration {
    package static var forPenny: Self {
        HTTPClient.Configuration(
            redirectConfiguration: .follow(max: 5, allowCycles: true),
            timeout: .init(
                connect: .seconds(15),
                read: .seconds(60),
                write: .seconds(60)
            ),
            decompression: .enabled(
                limit: .ratio(100)
            )
        )
    }
}
