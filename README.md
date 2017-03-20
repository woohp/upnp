# UPnP

**Simple UPnP client library**

```elixir
iex(1)> device = UPnP.InternetGatewayDevice.discover()
"http://192.168.0.1:1900/ipc"
iex(2)> UPnP.InternetGatewayDevice.add_port_mapping(device, 1234)
:ok
iex(3)> UPnP.InternetGatewayDevice.delete_port_mapping(device, 1234)
:ok
iex(4)> UPnP.InternetGatewayDevice.get_external_ip_address(device)
"123.456.789.00"
```
