extension KiteConnectClient {
    /// Retrieves the current day's order book, including open and executed orders.
    public func orders() async throws -> [Order] {
        try await rest.send(.init(.get, path: ["orders"]))
    }

    /// Retrieves the order's state history in the sequence returned by Kite.
    public func orderHistory(orderID: String) async throws -> [Order] {
        try await rest.send(.init(.get, path: ["orders", orderID]))
    }

    /// Retrieves all trades executed during the current day.
    public func trades() async throws -> [Trade] {
        try await rest.send(.init(.get, path: ["trades"]))
    }

    /// Retrieves the trades executed for a particular order.
    public func orderTrades(orderID: String) async throws -> [Trade] {
        try await rest.send(.init(.get, path: ["orders", orderID, "trades"]))
    }
}
