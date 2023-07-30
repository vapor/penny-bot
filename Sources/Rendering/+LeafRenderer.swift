import LeafKit
import NIO
import AsyncHTTPClient
import Logging
import Foundation

private let leafRendererThreadPool: NIOThreadPool = {
    let pool = NIOThreadPool(numberOfThreads: 1)
    pool.start()
    return pool
}()

extension LeafRenderer {
    public convenience init(
        path: String,
        httpClient: HTTPClient,
        extraSources: [any LeafSource] = [],
        logger: Logger,
        on eventLoop: any EventLoop
    ) throws {
        let workingDirectory = FileManager.default.currentDirectoryPath
        let rootDirectory = "\(workingDirectory)/\(path)"
        let configuration = LeafConfiguration(rootDirectory: rootDirectory)
        
        let defaultSource: any LeafSource
        var isDebug: Bool {
#if DEBUG
            true
#else
            false
#endif
        }
        var isCI: Bool {
            ProcessInfo.processInfo.environment["CI"] != nil
        }
        if !isDebug || isCI {
            defaultSource = GHLeafSource(
                path: path,
                httpClient: httpClient,
                logger: logger
            )
        } else {
            let fileIO = NonBlockingFileIO(threadPool: leafRendererThreadPool)
            defaultSource = NIOLeafFiles(
                fileio: fileIO,
                limits: .default,
                sandboxDirectory: rootDirectory,
                viewDirectory: rootDirectory
            )
        }
        let sources = LeafSources()
        try sources.register(source: "default", using: defaultSource)
        for source in extraSources {
            try sources.register(source: "\(type(of: source))", using: source)
        }
        var tags: [String: any LeafTag] = defaultTags
        tags["raw"] = RawTag()
        self.init(
            configuration: configuration,
            tags: tags,
            sources: sources,
            eventLoop: eventLoop
        )
    }
}
