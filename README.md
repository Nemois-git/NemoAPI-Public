# NemoAPI

A small, dependency-free Swift package for declaring an HTTP API contract **as types**, so a client and a
server compile against the same definition of every endpoint.

An endpoint is a Swift type that states its HTTP method, path, query, request/response DTOs, authentication
requirement, and caching policy. NemoAPI turns that declaration into a correctly encoded path and query on
the client, and exposes the same declaration to the server so route registration can be derived from it
instead of being retyped.

- **Typed paths.** Path parameters are read through key paths, so a rename is a compile error, not a 404.
- **Safe path encoding.** A parameter value can never add, remove, or reshape path segments.
- **Deterministic queries.** Any `Codable` model becomes sorted `URLQueryItem`s with a defined shape for
  booleans, numbers, arrays, nested objects, and dates.
- **A cache contract.** `cacheable` and `ttl` live next to the endpoint, with helpers that derive
  `Cache-Control`.
- **No dependencies.** Only Foundation.

## Requirements

- Swift 6.1 or later
- macOS 13, iOS 16, tvOS 16, watchOS 9, or visionOS 1 or later (`Duration` is the floor)

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Nemois-git/NemoAPI-Public.git", from: "0.2.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "NemoAPI", package: "NemoAPI-Public"),
    ]),
]
```

Then `import NemoAPI`.

> `from: "0.2.0"` allows any version up to (but excluding) `1.0.0`. While the package is `0.x`, a minor
> version can contain source-breaking changes; use `.upToNextMinor(from: "0.2.0")` to stay on `0.2.x`.

## Quick start

Declare the endpoint once, in a module both sides import:

```swift
import NemoAPI

struct Article: Codable, Sendable {
    let id: Int
    let title: String
}

struct ArticlePath: APIPathParameters {
    var id: Int

    static var pathLayout: [APIPathComponent<ArticlePath>] {
        [.path("articles"), .parameter(.init("id", \.id))]
    }
}

struct GetArticleEndpoint: APIEndpoint {
    typealias ResponseDTO = Article
    typealias Query = EmptyParameters
    typealias PathParameters = ArticlePath

    static let requireAuth: RequireAuth = .none
    static let method: APIMethod = .GET
    static let cacheable = true
    static let ttl: Duration = .minutes(5)
}
```

`RequestDTO` defaults to `EmptyParameters`; declare it only for endpoints that send a body.

On the client, build a `URLRequest` from any endpoint:

```swift
func makeRequest<E: APIEndpoint>(
    _ endpoint: E.Type,
    baseURL: URL,
    path: E.PathParameters,
    query: E.Query
) throws -> URLRequest {
    var components = try E.makePath(with: path)
    components.scheme = baseURL.scheme
    components.host = baseURL.host()
    components.port = baseURL.port

    let items = try query.queryItems
    if !items.isEmpty {
        components.queryItems = items
    }

    guard let url = components.url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = E.method.rawValue
    return request
}

let request = try makeRequest(
    GetArticleEndpoint.self,
    baseURL: URL(string: "https://api.example.com")!,
    path: ArticlePath(id: 42),
    query: EmptyParameters()
)
// GET https://api.example.com/articles/42
```

NemoAPI does not send requests or encode bodies. Transport, authentication, and the JSON coders for
`RequestDTO` / `ResponseDTO` stay in your client and server.

## Endpoints

| Requirement | Meaning |
|---|---|
| `RequestDTO` | Body type. Defaults to `EmptyParameters`. |
| `ResponseDTO` | Response type. |
| `Query` | An `APIQuery`. Use `EmptyParameters` when there is none. |
| `PathParameters` | An `APIPathParameters`. Use `EmptyParameters` for the root path. |
| `requireAuth` | `.strict`, `.optional`, or `.none`. Enforcement is up to the server; the value is the contract. |
| `method` | `GET`, `POST`, `PUT`, `PATCH`, or `DELETE`. |
| `cacheable`, `ttl` | Cache declaration. Defaults to not cacheable. See [Caching](#caching). |

`APIEndpoint.makePath(with:)` resolves the endpoint's path from its `PathParameters`.

## Path parameters

`pathLayout` lists constant segments and key-path-backed parameters in order:

```swift
struct UserPath: APIPathParameters {
    var id: String

    static var pathLayout: [APIPathComponent<UserPath>] {
        [.path("users"), .parameter(.init("id", \.id))]
    }
}
```

`.parameter(.init(name, keyPath))` takes the name used for the parameter (for example in a route template)
and a key path to a value that is `CustomStringConvertible & Sendable`.

`resolvePath()` returns `URLComponents` whose `percentEncodedPath` is safe to send. Each parameter value is
encoded on its own, so it stays exactly one segment:

| Value | Resulting path |
|---|---|
| `"123"` | `/users/123` |
| `"a b"` | `/users/a%20b` |
| `"a/b"` | `/users/a%2Fb` |
| `"x?y=1"` | `/users/x%3Fy=1` |
| `"../admin"` | `/users/..%2Fadmin` |
| `"한글"` | `/users/%ED%95%9C%EA%B8%80` |
| `"50%"` | `/users/50%25` |
| `""` | throws `APIReceiptError.emptyParameter` |
| `".."` | throws `APIReceiptError.invalidPath` |

A server that splits the raw path on `/` and percent-decodes each segment once gets the original value back.

Constant segments are not encoded, because routers match them undecoded. A constant that is empty, is `.`
or `..`, contains `/`, or contains a character that is not URL-safe throws `invalidPath`.

### Registering routes on a server

`pathLayout` is public, so a route template can be derived from the same declaration the client uses:

```swift
func routeTemplate<P: APIPathParameters>(_: P.Type) -> String {
    "/" + P.pathLayout.map { component -> String in
        switch component {
        case .path(let constant): constant
        case .parameter(let extractor): ":" + extractor.name
        }
    }.joined(separator: "/")
}

routeTemplate(ArticlePath.self)   // "/articles/:id"
```

Adapt the template syntax to your server framework.

## Query parameters

Conform any `Codable & Sendable` struct to `APIQuery`:

```swift
struct Filter: Codable, Sendable {
    var minPrice = 10
    var inStock = true
}

struct SearchQuery: APIQuery {
    var text = "swift"
    var page = 2
    var tags = ["a", "b"]
    var filter = Filter()
    var cursor: String? = nil
    var since = Date(timeIntervalSince1970: 1_700_000_000)
}

try SearchQuery().queryItems
// filter[inStock]=true
// filter[minPrice]=10
// page=2
// since=1700000000
// tags=a
// tags=b
// text=swift
```

`queryItems` flattens the model into `URLQueryItem`s with these rules:

| Value | Output |
|---|---|
| `String` | as is |
| `Bool` | `true` / `false` |
| `Int`, `UInt`, and sized variants | plain digits, exact (no floating-point round trip) |
| `Double`, `Float` | shortest round-trip text; whole values below 1e15 are written as integers (`3.0` becomes `3`); `NaN` and infinity throw |
| `Array` | the key is repeated: `tags=a&tags=b`; an empty array yields nothing |
| nested struct or dictionary | bracketed names: `filter[minPrice]=10` |
| `nil` | omitted |
| `Date` | per `dateEncoding` (below) |
| `Data` | base64 |
| `Decimal` | decimal text |
| `UUID`, enums with raw values | their natural string |

Items are sorted by full name, and repeated keys keep their element order, so the same query always
produces the same URL. That makes the URL a stable cache key.

`queryItems` **throws**. If a model cannot be encoded, you get the error instead of a request that silently
goes out without its query. A model whose root is not a keyed container (for example one that encodes as an
array) throws `APIReceiptError.wrongReceipt`.

### Dates

The default is seconds since 1970 (`1700000000`), which is what query decoders read by default. A query type
overrides it with a static property:

```swift
struct SinceQuery: APIQuery {
    static var dateEncoding: QueryDateEncoding { .iso8601 }
    var since: Date
}
```

| `QueryDateEncoding` | Example for 2023-11-14 22:13:20 UTC |
|---|---|
| `.secondsSince1970` (default) | `1700000000` |
| `.millisecondsSince1970` | `1700000000000` |
| `.iso8601` | `2023-11-14T22:13:20Z` (whole seconds) |
| `.iso8601WithFractionalSeconds` | `2023-11-14T22:13:20.500Z` (milliseconds) |

A type that encodes its dates itself (for example by writing `timeIntervalSince1970` in a custom
`encode(to:)`) is unaffected by `dateEncoding`.

### A note on `+`

`URLComponents` leaves `+` untouched in a query, as URI rules allow, but servers that follow HTML form
rules read it as a space. NemoAPI hands you the raw items and does no extra encoding. If your values may
contain `+`, replace it with `%2B` in `percentEncodedQuery` after assembling the URL.

## Caching

`cacheable` and `ttl` declare how long a successful response may be reused. The helpers derive everything
else from these two values, so the server and the client read one source of truth:

```swift
struct PrivateFeed: APIEndpoint {
    typealias ResponseDTO = Article
    typealias Query = EmptyParameters
    typealias PathParameters = EmptyParameters
    static let requireAuth: RequireAuth = .strict
    static let method: APIMethod = .GET
    static let cacheable = true
    static let ttl: Duration = .seconds(30)
}
```

| Helper | Meaning |
|---|---|
| `isCacheContractValid` | `true` when the declaration is consistent (see below) |
| `maxAgeSeconds` | `ttl` in whole seconds, rounded up; `0` when not cacheable or negative |
| `cacheControlValue` | a ready-to-send `Cache-Control` value |

A declaration is consistent when:

1. Only `GET` is cacheable.
2. A cacheable endpoint has a positive `ttl`.
3. A non-cacheable endpoint has no `ttl`.

`cacheControlValue` is `public, max-age=N` for an endpoint with `requireAuth == .none`, `private, max-age=N`
for any endpoint that requires or accepts authentication (the response may be user-specific), and
`no-store` when the endpoint is not cacheable or its declaration is inconsistent:

```swift
GetArticleEndpoint.cacheControlValue   // "public, max-age=300"
PrivateFeed.cacheControlValue          // "private, max-age=30"
CreateArticle.cacheControlValue        // "no-store"
```

This package cannot enumerate the endpoints you define, so assert the contract in your own tests:

```swift
import Testing

@Test func endpointsDeclareAConsistentCacheContract() {
    #expect(GetArticleEndpoint.isCacheContractValid)
    #expect(PrivateFeed.isCacheContractValid)
}
```

`Duration` gets three readability helpers: `.minutes(_:)`, `.hours(_:)`, and `.days(_:)`.

## Errors

`APIReceiptError` conforms to `LocalizedError`:

| Case | Thrown when |
|---|---|
| `emptyParameter` | a path parameter value is empty |
| `invalidPath` | a path value is `.` or `..`, or a constant segment is invalid |
| `wrongReceipt` | a query model does not encode to a keyed container |

Encoding failures from your own `Encodable` implementations are rethrown unchanged.

## Migrating from 0.1.x

- **`queryItems` now throws.** Add `try` at each call site. Previously an encoding failure produced an empty
  query without any signal.
- **Dates in queries are seconds since 1970 by default.** Previously the encoder's default (seconds since
  2001) was sent. A query type that encodes its own dates is unaffected.
- **Query items are sorted** and use `true`/`false` for booleans; arrays and nested models are flattened
  instead of being turned into a description string.
- **Path values are percent-encoded per segment**, and empty values, `.`/`..` values, and invalid constant
  segments throw instead of crashing a debug build or silently reshaping the path.
- **`APIReceiptError` conforms to `LocalizedError`**, so `localizedDescription` returns the declared message.
- **New API:** `QueryDateEncoding`, `APIQuery.dateEncoding`, and `APIEndpoint.cacheControlValue`.

## Development

```sh
swift build
swift test
swift test --enable-code-coverage
```

The test suite covers every line, function, and region of the package.

## License

NemoAPI is available under the MIT License. See [LICENSE](LICENSE).
