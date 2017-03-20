defmodule UPnP.InternetGatewayDevice do
  @search_target "urn:schemas-upnp-org:device:InternetGatewayDevice:1"
  def discover do
    locations = UPnP.Discovery.discover(@search_target)

    # hit each location to see if we we find valid services, and return the first valid IGD service
    locations
    |> Stream.map(&find_services/1)
    |> Stream.filter(&(&1))
    |> Enum.at(0)
  end

  def add_port_mapping(url, internal_client, internal_port, external_port, protocol) do
    {body, headers} = create_soap_request("AddPortMapping", internal_client, internal_port, external_port, protocol)
    {:ok, response} = HTTPoison.post(url, body, headers)
    if response.status_code == 200, do: :ok, else: :error
  end

  def add_port_mapping(url, port, protocol \\ "TCP") do
    internal_client = get_ipv4_address()
    add_port_mapping(url, internal_client, port, port, protocol)
  end

  def delete_port_mapping(url, external_port, protocol \\ "TCP") do
    {body, headers} = create_soap_request("DeletePortMapping", external_port, protocol)
    {:ok, response} = HTTPoison.post(url, body, headers)
    if response.status_code == 200, do: :ok, else: :error
  end

  def get_external_ip_address(url) do
    {body, headers} = create_soap_request("GetExternalIPAddress")
    {:ok, response} = HTTPoison.post(url, body, headers)
    parse_soap_response(response.body, "NewExternalIPAddress")
  end

  def get_ipv4_address do
    {:ok, addresses} = :inet.getifaddrs()

    addresses
    |> Enum.filter(fn {ifname, _} -> ifname != 'lo0' end)  # filter out the loopback addresses
    |> Enum.flat_map(fn {_, if_opts} -> if_opts end)  # don't care about interfaces, just get everything
    |> Enum.filter_map(fn {opt_name, value} -> opt_name == :addr and tuple_size(value) == 4 end,
                       fn {_, value} -> to_string(:inet.ntoa(value)) end)
    |> Enum.at(0)
  end

  defp find_services(url) do
    http_response = HTTPoison.get!(url)

    # setup SAX handler
    event_state = {false, nil, nil, nil}

    event_fun = fn event, _, {service_type, control_url, text, final_control_url} = state ->
      case event do
        {:endElement, _, 'serviceType', _} ->
          correct_service_type = text in [
            "urn:schemas-upnp-org:service:WANIPConnection:1",
            "urn:schemas-upnp-org:service:WANPPPConnection:1"
          ]
          {correct_service_type, control_url, nil, final_control_url}
        {:endElement, _, 'controlURL', _} ->
          {service_type, text, nil, final_control_url}
        {:endElement, _, 'service', _} ->
          if service_type do
            {nil, nil, nil, control_url}
          else
            {nil, nil, nil, final_control_url}
          end
        {:characters, new_text} -> {service_type, control_url, to_string(new_text), final_control_url}
        _ -> state
      end
    end
    parse_results = :xmerl_sax_parser.stream(http_response.body, event_state: event_state, event_fun: event_fun)
    {:ok, {_, _, _, control_url}, _} = parse_results

    if control_url do
      url_components = URI.parse(url)
      "#{url_components.scheme}://#{url_components.host}:#{url_components.port}#{control_url}"
    else
      nil
    end
  end

  defp parse_soap_response(content, element_name) do
    element_name = to_charlist(element_name)

    event_state = {nil, nil}
    event_fun = fn event, _, {text, final_text} = state ->
      case event do
        {:endElement, _, ^element_name, _} ->
          {nil, text}
        {:characters, new_text} ->
          {to_string(new_text), final_text}
        _ -> state
      end
    end
    parse_results = :xmerl_sax_parser.stream(content, event_state: event_state, event_fun: event_fun)
    {:ok, {_, text}, _} = parse_results
    text
  end

  defp create_soap_request("AddPortMapping" = method_name, internal_client, internal_port, external_port, protocol) do
    headers = create_soap_request_header(method_name)

    body_frag = ~s"""
    <NewRemoteHost></NewRemoteHost>
    <NewExternalPort>#{external_port}</NewExternalPort>
    <NewProtocol>#{protocol}</NewProtocol>
    <NewInternalPort>#{internal_port}</NewInternalPort>
    <NewInternalClient>#{internal_client}</NewInternalClient>
    <NewEnabled>1</NewEnabled>
    <NewPortMappingDescription>Insert description here</NewPortMappingDescription>
    <NewLeaseDuration>0</NewLeaseDuration>
    """
    body = create_soap_request_body_helper(method_name, body_frag)

    {body, headers}
  end

  defp create_soap_request("DeletePortMapping" = method_name, external_port, protocol) do
    headers = create_soap_request_header(method_name)

    body_frag = ~s"""
    <NewRemoteHost></NewRemoteHost>
    <NewExternalPort>#{external_port}</NewExternalPort>
    <NewProtocol>#{protocol}</NewProtocol>
    """
    body = create_soap_request_body_helper(method_name, body_frag)

    {body, headers}
  end

  defp create_soap_request("GetExternalIPAddress" = method_name) do
    headers = create_soap_request_header(method_name)
    body = create_soap_request_body_helper(method_name)
    {body, headers}
  end

  defp create_soap_request_body_helper(method_name, body_fragment \\ "") do
    ~s"""
    <?xml version="1.0"?>
    <SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
                       SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <SOAP-ENV:Body>
        <m:#{method_name} xmlns:m="urn:schemas-upnp-org:service:WANIPConnection:1">
          #{body_fragment}
        </m:#{method_name}>
      </SOAP-ENV:Body>
    </SOAP-ENV:Envelope>
    """
  end

  defp create_soap_request_header(method_name) do
    [
      {"Content-Type", ~s(text/xml; charset=\"utf-8\")},
      {"SOAPAction", ~s("urn:schemas-upnp-org:service:WANIPConnection:1##{method_name}")}
    ]
  end
end