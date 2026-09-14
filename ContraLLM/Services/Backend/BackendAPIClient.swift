//
//  BackendAPIClient.swift
//  ContraLLM
//
//  Small shared HTTP helper used by the Backend* service implementations to
//  call the Contra backend (see backend/worker). Centralizes request
//  building, the shared-secret header, timeouts, and error mapping so each
//  Backend*Service stays focused on its own request/response shapes.
//

import Foundation

struct BackendAPIClient {
    let configuration: APIConfiguration

    func get<Response: Decodable>(
        path: String,
        timeout: TimeInterval = 15
    ) async throws -> Response {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        applyAuthHeader(&request)
        return try await send(request)
    }

    func post<Request: Encodable, Response: Decodable>(
        path: String,
        body: Request,
        timeout: TimeInterval = 30
    ) async throws -> Response {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeader(&request)

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AIServiceError.invalidResponse
        }

        return try await send(request)
    }

    private func applyAuthHeader(_ request: inout URLRequest) {
        if !configuration.sharedSecret.isEmpty {
            request.setValue("Bearer \(configuration.sharedSecret)", forHTTPHeaderField: "Authorization")
        }
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw AIServiceError.unauthorized
        case 429:
            throw AIServiceError.rateLimited
        default:
            throw AIServiceError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AIServiceError.invalidResponse
        }
    }
}
