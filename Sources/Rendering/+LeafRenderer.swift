@preconcurrency import LeafKit
import NIO
import AsyncHTTPClient
import Logging
import Foundation

extension LeafRenderer {
    package convenience init(
        subDirectory: String,
        extraSources: [any LeafSource] = [],
        logger: Logger
    ) throws {
        let path = "Templates/\(subDirectory)"
        let workingDirectory = FileManager.default.currentDirectoryPath
        let rootDirectory = "\(workingDirectory)/\(path)"
        let configuration = LeafConfiguration(rootDirectory: rootDirectory)
        let fileIO = NonBlockingFileIO(threadPool: NIOThreadPool.singleton)
        let fileIOSource = NIOLeafFiles(
            fileio: fileIO,
            limits: .default,
            sandboxDirectory: rootDirectory,
            viewDirectory: rootDirectory
        )
        let ghSource = GHLeafSource(
            path: path,
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
            eventLoop: HTTPClient.shared.eventLoopGroup.next()
        )
    }
}
