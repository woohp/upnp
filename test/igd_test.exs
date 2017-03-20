defmodule UPnPIGDTest do
  use ExUnit.Case
  doctest UPnP

  test "discover returns a valid IGD device" do
    device = UPnP.InternetGatewayDevice.discover()
    assert is_binary(device)
    assert String.starts_with?(device, "http")
  end

  test "adding and deleting ports" do
    device = UPnP.InternetGatewayDevice.discover()
    assert UPnP.InternetGatewayDevice.add_port_mapping(device, 1234) == :ok
    assert UPnP.InternetGatewayDevice.add_port_mapping(device, 1234) == :ok
    assert UPnP.InternetGatewayDevice.delete_port_mapping(device, 1234) == :ok
  end

  test "getting external ip address" do
    device = UPnP.InternetGatewayDevice.discover()
    external_ip = UPnP.InternetGatewayDevice.get_external_ip_address(device)
    assert is_binary(external_ip)
    assert length(String.split(external_ip, ".")) == 4
  end
end
