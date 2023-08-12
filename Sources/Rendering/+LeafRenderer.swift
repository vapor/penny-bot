import AsyncHTTPClient
import Foundation
import LeafKit
import Logging
import NIO

private let leafRendererThreadPool: NIOThreadPool = {
    let pool = NIOThreadPool(numberOfThreads: 1)
    pool.start()
    return pool
}()

extension LeafRenderer {
    public convenience init(
        subDirectory: String,
        httpClient: HTTPClient,
        extraSources: [any LeafSource] = [],
        logger: Logger,
        on eventLoop: any EventLoop
    ) throws {
        let path = "Templates/\(subDirectory)"
        let workingDirectory = FileManager.default.currentDirectoryPath
        let rootDirectory = "\(workingDirectory)/\(path)"
        let configuration = LeafConfiguration(rootDirectory: rootDirectory)
        let fileIO = NonBlockingFileIO(threadPool: leafRendererThreadPool)
        let fileIOSource = NIOLeafFiles(
            fileio: fileIO,
            limits: .default,
            sandboxDirectory: rootDirectory,
            viewDirectory: rootDirectory
        )
        let ghSource = GHLeafSource(
            path: path,
            httpClient: httpClient,
            logger: logger
        )
        let sources = LeafSources()
        try sources.register(source: "file-io", using: fileIOSource)
        try sources.register(source: "github", using: ghSource)
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
