//
//  File.swift
//  
//
//  Created by Benny De Bock on 14/03/2022.
//

import Foundation

protocol UserRepository {
    
    // MARK: - Insert
    func insertUser(_ user: DynamoDBUser) async throws -> Task
    func updateUser(_ user: DynamoDBUser) async throws -> Task
    
    // MARK: - Retrieve
    func getUser(with discordId: String) async throws -> Task
    func getUser(with githubId: String) async throws -> Task
    
    // MARK: - Link users
    func linkGithub(with discordId: String, _ githubId: String) async throws -> Task
    func linkDiscord(with githubId: String, _ discordId: String) async throws -> Task
}
