import LeafKit
import NIO
import Foundation

extension LeafRenderer {
    private static let leafRendererThreadPool: NIOThreadPool = {
        let pool = NIOThreadPool(numberOfThreads: 1)
        pool.start()
        return pool
    }()

    static func forGHHooks(eventLoop: any EventLoop) -> LeafRenderer {
        let workingDir = FileManager.default.currentDirectoryPath
        let rootDirectory = "\(workingDir)/templates/GHHooksLambda"
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

    func render(path: String, context: [String: LeafData]) async throws -> String {
        let buffer = try await self.render(path: "\(path).leaf", context: context).get()
        return String(buffer: buffer)
    }
}
