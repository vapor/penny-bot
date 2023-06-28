#!/usr/bin/swift
import Foundation

let tableName = "penny-bot-table"
let port = 8091
let containerName = "dynamodb-sdm-users"
let awsProfileName = "vapor-benny"

print("Starting local database in container \(containerName). \nTable name is \(tableName)")

@discardableResult
func shell(_ args: String..., returnStdOut: Bool = false) -> (Int32, Pipe) {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
  let pipe = Pipe()
  if returnStdOut {
      task.standardOutput = pipe
  }
  task.launch()
  task.waitUntilExit()
  return (task.terminationStatus, pipe)
}

extension Pipe {
    func string() -> String? {
        let data = self.fileHandleForReading.readDataToEndOfFile()
        let result: String?
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            result = string
        } else {
            result = nil
        }
        return result
    }
}

print("Creating database... 💾")

let (dockerResult, _) = shell("docker", "run", "--name", containerName, "-p", "\(port):8000", "-d", "amazon/dynamodb-local")

guard dockerResult == 0 else {
    print("❌ ERROR: Failed to create the database")
    exit(1)
}

let (createTableResult, _) = shell("aws", "dynamodb", "create-table", "--table-name", tableName, "--region", "eu-west-2", 
"--attribute-definitions", "AttributeName=pk,AttributeType=S", "AttributeName=sk,AttributeType=S", "AttributeName=data1,AttributeType=S", "AttributeName=data2,AttributeType=S",
"--key-schema", "AttributeName=pk,KeyType=HASH", "AttributeName=sk,KeyType=RANGE",
"--global-secondary-index", 
"IndexName=GSI-1,KeySchema=[{AttributeName=data1,KeyType=HASH},{AttributeName=pk,KeyType=RANGE}],Projection={ProjectionType=ALL}", 
"IndexName=GSI-2,KeySchema=[{AttributeName=data2,KeyType=HASH},{AttributeName=pk,KeyType=RANGE}],Projection={ProjectionType=ALL}", 
"--billing-mode=PAY_PER_REQUEST", 
"--endpoint-url", "http://localhost:\(port)", "--profile", awsProfileName, returnStdOut: true)

guard createTableResult == 0 else {
    print("❌ ERROR: Failed to create the table")
    exit(1)
}

var timeoutRequests = 0

while !checkDatabaseIsUp() {
    if timeoutRequests > 5 {
        print("❌ ERROR: Failed to create the table")
        exit(1)
    }
    sleep(1)
    timeoutRequests += 1
}

func checkDatabaseIsUp() -> Bool {
    let (describeTableResult, describeTableOutput) = shell("aws", "dynamodb", "describe-table", "--table-name", tableName,
    "--region", "eu-west-2", "--endpoint-url",  "http://localhost:\(port)", "--profile", awsProfileName, returnStdOut: true)
    if describeTableResult != 0 {
        return false
    }

    do {
        guard let string = describeTableOutput.string() else {
            return false
        }
        let data = Data(string.utf8)
        let decoded = try JSONDecoder().decode(DescribeTableResult.self, from: data)
        guard decoded.Table.TableStatus == "ACTIVE" else {
            return false
        }
        return true
    } catch {
        return false
    }
}

struct DescribeTableResult: Codable {
    let Table: DescribeTableTable
}

struct DescribeTableTable: Codable {
    let TableStatus: String
}

print("Database created in Docker 🐳")
