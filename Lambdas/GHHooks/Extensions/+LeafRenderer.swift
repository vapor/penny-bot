import LeafKit
import NIO
import Foundation

extension LeafRenderer {
    private static let leafRendererThreadPool = NIOThreadPool(numberOfThreads: 1)

    static func forGHHooks(eventLoop: any EventLoop) -> LeafRenderer {
        let workingDir = FileManager.default.currentDirectoryPath
        let rootDirectory = "\(workingDir)/templates"
        let configuration = LeafConfiguration(rootDirectory: rootDirectory)
        let fileIO = NonBlockingFileIO(threadPool: leafRendererThreadPool)
        let leafSource = NIOLeafFiles(
            fileio: fileIO,
            limits: .default,
            sandboxDirectory: rootDirectory,
            viewDirectory: rootDirectory
        )
        return LeafRenderer(
            configuration: configuration,
            sources: .singleSource(leafSource),
            eventLoop: eventLoop
        )
    }
}
