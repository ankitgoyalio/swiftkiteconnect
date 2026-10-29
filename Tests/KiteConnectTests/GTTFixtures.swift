//
//  GTTFixtures.swift
//  swiftkiteconnect
//
//  Created by Ankit Goyal on 29/10/2026.

import Foundation
import KiteConnect
import Testing

let gttListJSON = #"""
{
    "status": "success",
    "data": [
        {
            "id": 112127,
            "user_id": "XX0000",
            "parent_trigger": null,
            "type": "single",
            "created_at": "2019-09-12 13:25:16",
            "updated_at": "2019-09-12 13:25:16",
            "expires_at": "2020-09-12 13:25:16",
            "status": "active",
            "condition": {
                "exchange": "NSE",
                "last_price": 798,
                "tradingsymbol": "INFY",
                "trigger_values": [
                    702
                ],
                "instrument_token": 408065
            },
            "orders": [
                {
                    "exchange": "NSE",
                    "tradingsymbol": "INFY",
                    "product": "CNC",
                    "order_type": "LIMIT",
                    "transaction_type": "BUY",
                    "quantity": 1,
                    "price": 702.5,
                    "result": null
                }
            ],
            "meta": {}
        },
        {
            "id": 105099,
            "user_id": "XX0000",
            "parent_trigger": null,
            "type": "two-leg",
            "created_at": "2019-09-09 15:13:22",
            "updated_at": "2019-09-09 15:15:08",
            "expires_at": "2020-01-01 12:00:00",
            "status": "triggered",
            "condition": {
                "exchange": "NSE",
                "last_price": 102.6,
                "tradingsymbol": "RAIN",
                "trigger_values": [
                    102.0,
                    103.7
                ],
                "instrument_token": 3926273
            },
            "orders": [
                {
                    "exchange": "NSE",
                    "tradingsymbol": "RAIN",
                    "product": "CNC",
                    "order_type": "LIMIT",
                    "transaction_type": "SELL",
                    "quantity": 1,
                    "price": 1,
                    "result": null
                },
                {
                    "exchange": "NSE",
                    "tradingsymbol": "RAIN",
                    "product": "CNC",
                    "order_type": "LIMIT",
                    "transaction_type": "SELL",
                    "quantity": 1,
                    "price": 1,
                    "result": {
                        "account_id": "XX0000",
                        "exchange": "NSE",
                        "tradingsymbol": "RAIN",
                        "validity": "DAY",
                        "product": "CNC",
                        "order_type": "LIMIT",
                        "transaction_type": "SELL",
                        "quantity": 1,
                        "price": 1,
                        "meta": "{\"app_id\":12617,\"gtt\":105099}",
                        "timestamp": "2019-09-09 15:15:08",
                        "triggered_at": 103.7,
                        "order_result": {
                            "status": "failed",
                            "order_id": "",
                            "rejection_reason": "Your order price is lower than the current lower circuit limit of 70.65. Place an order within the daily range."
                        }
                    }
                }
            ],
            "meta": null
        }
    ]
}

"""#

func gttDetailJSON() throws -> String {
    #"""
    {
        "status": "success",
        "data": {
            "id": 123,
            "user_id": "XX0000",
            "parent_trigger": null,
            "type": "two-leg",
            "created_at": "2019-09-09 15:13:22",
            "updated_at": "2019-09-09 15:15:08",
            "expires_at": "2020-01-01 12:00:00",
            "status": "triggered",
            "condition": {
                "exchange": "NSE",
                "last_price": 102.6,
                "tradingsymbol": "RAIN",
                "trigger_values": [
                    102.0,
                    103.7
                ],
                "instrument_token": 3926273
            },
            "orders": [
                {
                    "exchange": "NSE",
                    "tradingsymbol": "RAIN",
                    "product": "CNC",
                    "order_type": "LIMIT",
                    "transaction_type": "SELL",
                    "quantity": 1,
                    "price": 1,
                    "result": null
                },
                {
                    "exchange": "NSE",
                    "tradingsymbol": "RAIN",
                    "product": "CNC",
                    "order_type": "LIMIT",
                    "transaction_type": "SELL",
                    "quantity": 1,
                    "price": 1,
                    "result": {
                        "account_id": "XX0000",
                        "exchange": "NSE",
                        "tradingsymbol": "RAIN",
                        "validity": "DAY",
                        "product": "CNC",
                        "order_type": "LIMIT",
                        "transaction_type": "SELL",
                        "quantity": 1,
                        "price": 1,
                        "meta": "{\"app_id\":12617,\"gtt\":105099}",
                        "timestamp": "2019-09-09 15:15:08",
                        "triggered_at": 103.7,
                        "order_result": {
                            "status": "failed",
                            "order_id": "",
                            "rejection_reason": "Your order price is lower than the current lower circuit limit of 70.65. Place an order within the daily range."
                        }
                    }
                }
            ],
            "meta": null
        }
    }

    """#
}

func gttRequest(twoLeg: Bool = false) throws -> KiteGTTRequest {
    let instrument = try KiteInstrumentIdentity(exchange: .nse, tradingSymbol: "INFY")
    let order = KiteGTTOrderRequest(
        instrument: instrument, transactionType: .sell, quantity: 1, product: .cnc,
        price: Decimal(string: "702.123456789123456789")!,
    )
    return KiteGTTRequest(
        type: twoLeg ? .twoLeg : .single,
        condition: KiteGTTConditionRequest(
            instrument: instrument, triggerValues: twoLeg ? [702, 798] : [702], lastPrice: 742,
        ),
        orders: twoLeg
            ? [
                order,
                KiteGTTOrderRequest(
                    instrument: instrument, transactionType: .sell, quantity: 2, product: .cnc,
                    price: Decimal(string: "798.5")!,
                ),
            ] : [order],
    )
}

func performGTTOperation(_ operation: String, client: KiteClient) async throws {
    switch operation {
    case "create": _ = try await client.createGTT(gttRequest())
    case "modify": _ = try await client.modifyGTT(id: 123, trigger: gttRequest(twoLeg: true))
    case "delete": _ = try await client.deleteGTT(id: 123)
    case "get": _ = try await client.gttTrigger(id: 123)
    default: _ = try await client.gttTriggers()
    }
}
