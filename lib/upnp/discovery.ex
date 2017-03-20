defmodule UPnP.Discovery do
  @spec discover(String.t) :: Enumerable.t
  def discover(search_target) do
    discovery_packet = ~s"""
    M-SEARCH * HTTP/1.1\r
    HOST: 239.255.255.250:1900\r
    MAN: "ssdp:discover"\r
    MX: 1\r
    ST: #{search_target}\r
    \r\n\r
    """

    # send the discovery packet using UDP, and then wait for responses
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    :ok = :gen_udp.send(socket, {239, 255, 255, 250}, 1900, discovery_packet)

    discovery_responses = Stream.unfold(socket, &listen_discovery_responses/1)

    # parse each response packet for locations
    locations = discovery_responses
    |> Stream.flat_map(&parse_discovery_response/1)
    |> Stream.uniq()

    locations
  end

  @timeout 4000

  defp listen_discovery_responses(socket) do
    case :gen_udp.recv(socket, 1024, @timeout) do
      {:ok, {_, _, packet}} -> {packet, socket}
      _ -> nil
    end
  end

  @spec parse_discovery_response(String.t) :: [String.t]
  defp parse_discovery_response(packet) do
    packet
    |> String.split("\r\n")
    |> Enum.map(&String.split(&1, ":", parts: 2))
    |> Enum.filter_map(fn line_segments -> String.downcase(hd(line_segments)) == "location" end,
                       fn [_, value] -> String.trim(value) end)
  end
end
