@preconcurrency package import LeafKit
package import Logging
import NIOPosix

package import class AsyncHTTPClient.HTTPClient
package import protocol NIOCore.EventLoop

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension LeafRenderer {
    package convenience init(
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
        let fileIO = NonBlockingFileIO(threadPool: NIOThreadPool.singleton)
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
