import LeafKit
import NIO
import AsyncHTTPClient
import Foundation

private let leafRendererThreadPool: NIOThreadPool = {
    let pool = NIOThreadPool(numberOfThreads: 1)
    pool.start()
    return pool
}()

extension LeafRenderer {
    public convenience init(
        httpClient: HTTPClient,
        rootDirectory: String,
        extraSources: [any LeafSource]
    ) throws {
        let configuration = LeafConfiguration(rootDirectory: rootDirectory)
        let fileIO = NonBlockingFileIO(threadPool: leafRendererThreadPool)
        let fileIOLeafSource = NIOLeafFiles(
            fileio: fileIO,
            limits: .default,
            sandboxDirectory: rootDirectory,
            viewDirectory: rootDirectory
        )
        let sources = LeafSources()
        try sources.register(source: "default", using: fileIOLeafSource)
        for source in extraSources {
            try sources.register(source: "\(type(of: source))", using: source)
        }
        self.init(
            configuration: configuration,
            sources: sources,
            eventLoop: httpClient.eventLoopGroup.next()
        )
    }
}
