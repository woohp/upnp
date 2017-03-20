defmodule UPnPDiscoveryTest do
  use ExUnit.Case
  doctest UPnP

  test "discover finds a location when searching for all targets" do
    location = UPnP.Discovery.discover("ssdp:all") |> Enum.any?()
    assert location == true
  end

  test "discover finds no targets when given bogus search target" do
    location = UPnP.Discovery.discover("bogus") |> Enum.any?()
    assert location == false
  end
end
