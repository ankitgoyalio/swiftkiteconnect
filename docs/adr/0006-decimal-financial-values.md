# Use Decimal for financial values

Public models will use `Decimal` for prices, monetary amounts, and financial rates, including prices decoded from WebSocket packets. Preserving decimal values for callers' financial calculations takes priority over the conversion overhead on streaming data; counts and quantities will retain endpoint-appropriate numeric types.
