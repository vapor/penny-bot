import LeafKit
import NIO
import Foundation

private let leafRendererThreadPool: NIOThreadPool = {
    let pool = NIOThreadPool(numberOfThreads: 1)
    pool.start()
    return pool
}()

extension LeafRenderer {
    public convenience init(
        path: String,
        extraSources: [any LeafSource] = [],
        on eventLoop: any EventLoop
    ) throws {
        let workingDirectory = FileManager.default.currentDirectoryPath
        let rootDirectory = "\(workingDirectory)/\(path)/Templates"
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
