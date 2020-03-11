class Puppet::HTTP::Resolver::ServerList < Puppet::HTTP::Resolver
  def initialize(client, server_list_setting:, default_port:, services: )
    @client = client
    @server_list_setting = server_list_setting
    @default_port = default_port
    @services = services
    @resolved_service = nil
  end

  def resolve(session, name, ssl_context: nil)
    # If we're configured to use an explicit service host, e.g. report_server
    # then don't use server_list to resolve the `:report` service.
    return nil unless @services.include?(name)

    # If we already resolved the server_list, use that
    return @resolved_service if @resolved_service

    # Return the first simple service status endpoint we can connect to
    @server_list_setting.value.each do |server|
      host = server[0]
      port = server[1] || @default_port
      uri = URI("https://#{host}:#{port}/status/v1/simple/master")
      if get_success?(uri, session, ssl_context: ssl_context)
        @resolved_service = Puppet::HTTP::Service.create_service(@client, session, name, host, port)
        return @resolved_service
      end
    end

    raise Puppet::Error, _("Could not select a functional puppet master from server_list: '%{server_list}'") % { server_list: @server_list_setting.print(@server_list_setting.value) }
  end

  def get_success?(uri, session, ssl_context: nil)
    response = @client.get(uri, options: {ssl_context: ssl_context})
    return true if response.success?

    Puppet.debug(_("Puppet server %{host}:%{port} is unavailable: %{code} %{reason}") %
                 { host: uri.host, port: uri.port, code: response.code, reason: response.reason })
    return false
  rescue => detail
    session.add_exception(detail)
    #TRANSLATORS 'server_list' is the name of a setting and should not be translated
    Puppet.debug _("Unable to connect to server from server_list setting: %{detail}") % {detail: detail}
    return false
  end
end
