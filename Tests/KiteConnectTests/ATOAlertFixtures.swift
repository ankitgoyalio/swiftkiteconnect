//
//  ATOAlertFixtures.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

let documentedAlertList = #"""
{
  "status": "success",
  "data": [
    {
      "type": "simple",
      "user_id": "AB1234",
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "name": "NIFTY 50",
      "status": "enabled",
      "disabled_reason": "",
      "lhs_attribute": "LastTradedPrice",
      "lhs_exchange": "INDICES",
      "lhs_tradingsymbol": "NIFTY 50",
      "operator": ">=",
      "rhs_type": "constant",
      "rhs_attribute": "",
      "rhs_exchange": "",
      "rhs_tradingsymbol": "",
      "rhs_constant": 27000,
      "alert_count": 0,
      "created_at": "2025-05-26 12:07:50",
      "updated_at": "2025-05-26 12:07:50"
    },
    {
      "type": "ato",
      "user_id": "AB1234",
      "uuid": "e888ed4a-6801-406f-bdc2-002db5a8411d",
      "name": "buy gold",
      "status": "disabled",
      "disabled_reason": "",
      "basket": {
        "items": [
          {
            "id": 275218517,
            "tradingsymbol": "GOLDBEES",
            "exchange": "NSE",
            "instrument_token": 3693569,
            "weight": 10000,
            "params": {
              "validity": "DAY",
              "validity_ttl": 0,
              "variety": "regular",
              "product": "CNC",
              "order_type": "LIMIT",
              "transaction_type": "BUY",
              "quantity": 10000,
              "disclosed_quantity": 0,
              "price": 72.22,
              "trigger_price": 0,
              "squareoff": 0,
              "stoploss": 0,
              "trailing_stoploss": 0,
              "gtt": {
                "target": 0,
                "stoploss": 0
              },
              "tags": []
            }
          }
        ]
      },
      "lhs_attribute": "LastTradedPrice",
      "lhs_exchange": "NSE",
      "lhs_tradingsymbol": "GOLDBEES",
      "operator": "<=",
      "rhs_type": "constant",
      "rhs_attribute": "",
      "rhs_exchange": "",
      "rhs_tradingsymbol": "",
      "rhs_constant": 71.8,
      "alert_count": 1,
      "created_at": "2025-02-17 08:24:10",
      "updated_at": "2025-02-17 09:15:20"
    }
  ]
}
"""#
let documentedBasket = #"""
{
  "name": "alerts-basket",
  "type": "alert",
  "tags": [],
  "items": [
    {
      "type": "insert",
      "tradingsymbol": "RELIANCE",
      "exchange": "NSE",
      "weight": 10000,
      "params": {
        "transaction_type": "BUY",
        "product": "CNC",
        "order_type": "MARKET",
        "validity": "DAY",
        "validity_ttl": 1,
        "quantity": 1,
        "price": 0,
        "trigger_price": 0,
        "disclosed_quantity": 0,
        "last_price": 0,
        "variety": "regular",
        "tags": [],
        "squareoff": 0,
        "stoploss": 0,
        "trailing_stoploss": 0,
        "iceberg_legs": 0,
        "market_protection": -1
      }
    }
  ]
}
"""#
let documentedHistory = #"""
{
  "status": "success",
  "data": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "type": "simple",
      "meta": [
        {
          "instrument_token": 270857,
          "tradingsymbol": "NIFTY NEXT 50",
          "timestamp": "2025-02-17 09:16:46",
          "last_price": 58288.05,
          "ohlc": {
            "open": 59221.95,
            "high": 59241.8,
            "low": 58283.7,
            "close": 59557.95
          },
          "net_change": -1269.9,
          "exchange": "INDICES",
          "last_trade_time": "0001-01-01 00:00:00",
          "last_quantity": 0,
          "buy_quantity": 0,
          "sell_quantity": 0,
          "volume": 0,
          "volume_tick": 0,
          "average_price": 0,
          "oi": 0,
          "oi_day_high": 0,
          "oi_day_low": 0,
          "lower_circuit_limit": 0,
          "upper_circuit_limit": 0
        }
      ],
      "condition": "LastTradedPrice(\"INDICES:NIFTY NEXT 50\") <= 58290.35",
      "created_at": "2025-02-17 09:16:46",
      "order_meta": null
    }
  ]
}
"""#
let atoID = "e888ed4a-6801-406f-bdc2-002db5a8411d"

func atoRequest() -> KiteATOAlertRequest {
    KiteATOAlertRequest(
        name: "NIFTY 50",
        condition: KiteAlertCondition(
            lhs: KiteAlertInstrument(
                exchange: .unknown("INDICES"), tradingSymbol: "NIFTY 50", attribute: "LastTradedPrice",
            ),
            comparison: .greaterThanOrEqual, rhs: .constant(27000),
        ),
        basket: KiteAlertBasket(
            name: "alerts-basket",
            items: [
                KiteAlertBasketItem(
                    tradingSymbol: "RELIANCE", exchange: .nse,
                    params: KiteAlertOrderParameters(
                        transactionType: .buy, product: .cnc, orderType: .market, quantity: 1,
                    ),
                ),
            ],
        ),
    )
}

func atoResponse(basket: Bool = false) throws -> String {
    let list =
        try JSONSerialization.jsonObject(with: Data(documentedAlertList.utf8)) as! [String: Any]
    var alert = (list["data"] as! [[String: Any]])[1]
    if !basket {
        alert.removeValue(forKey: "basket")
    }
    return try String(
        decoding: JSONSerialization.data(withJSONObject: ["status": "success", "data": alert]),
        as: UTF8.self,
    )
}

func formFields(_ data: Data?) throws -> [String: String] {
    let text = try String(decoding: #require(data), as: UTF8.self)
    return Dictionary(
        uniqueKeysWithValues: text.split(separator: "&").map {
            let pair = $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(pair[0]).removingPercentEncoding!, String(pair[1]).removingPercentEncoding!)
        },
    )
}

func performATO(_ operation: String, client: KiteClient) async throws {
    if operation == "create" {
        _ = try await client.createAlert(atoRequest())
    } else {
        _ = try await client.modifyAlert(uuid: atoID, alert: atoRequest())
    }
}
