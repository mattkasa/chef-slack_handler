class SlackHandlerUtil
  attr_reader :run_status, :default_config

  def initialize(default_config, run_status)
    @default_config = default_config
    @run_status = run_status
  end

  def start_message(context = {})
    { color: 'warning',
      mrkdwn_in: ['text', 'fields'],
      text: context['start_message'] || default_config[:start_message],
      fallback: context['start_message'] || default_config[:start_message],
      fields: [
        custom_details(context),
        node_details(context),
        organization_details(context),
        environment_details(context),
        cookbook_details(context)
      ].flatten.compact }
  end

  # message sent on a successful run
  def success_message(context = {})
    { color: 'good',
      mrkdwn_in: ['text', 'fields'],
      text: context['success_message'] || default_config[:success_message],
      fallback: context['success_message'] || default_config[:success_message],
      fields: [
        custom_details(context),
        node_details(context),
        organization_details(context),
        environment_details(context),
        start_time_details(context),
        elapsed_time(context),
        resource_details(context),
        cookbook_details(context)
      ].flatten.compact,
      ts: run_status.end_time.to_i }
  end
  alias end_message success_message

  # message sent on a failed run
  def failure_message(context = {})
    { color: 'danger',
      mrkdwn_in: ['text', 'fields'],
      text: context['failure_message'] || default_config[:failure_message],
      fallback: context['failure_message'] || default_config[:failure_message],
      fields: [
        custom_details(context),
        node_details(context),
        organization_details(context),
        environment_details(context),
        start_time_details(context),
        elapsed_time(context),
        resource_details(context),
        cookbook_details(context),
        exception_details(context)
      ].flatten.compact,
      ts: run_status.end_time.to_i }
  end

  def fail_only(context = {})
    return context['fail_only'] unless context['fail_only'].nil?
    default_config[:fail_only]
  end

  def send_on_start(context = {})
    return context['send_start_message'] unless context['send_start_message'].nil?
    default_config[:send_start_message]
  end

  private

  def exception_details(_context)
    slack_field(title: 'Exception', value: "`#{run_status.exception.message}`")
  end

  def elapsed_time(context = {})
    return if (context['message_detail_level'] || default_config[:message_detail_level]) == 'basic'
    slack_field(title: 'Elapsed Time', value: Time.at(run_status.elapsed_time).utc.strftime("%H:%M:%S"), short: true)
  end

  def start_time_details(_context = {})
    slack_field(title: 'Started', value: run_status.start_time.to_s, short: true)
  end

  def node_details(_context = {})
    slack_field(title: 'Node', value: run_status.node.name, short: true)
  end

  def environment_details(context = {})
    if context['send_environment'].nil?
      return unless default_config[:send_environment]
    else
      return unless context['send_environment']
    end

    slack_field(title: 'Environment', value: run_status.node.chef_environment, short: true)
  end

  def organization_details(context = {})
    if context['send_organization'].nil?
      return unless default_config[:send_organization]
    else
      return unless context['send_organization']
    end
    organization = File.file?('/etc/chef/client.rb') ? File.open('/etc/chef/client.rb').read.match(%r{(?<=\/organizations\/)(\w+-?\w+)}) : "Organization not found in client.rb"
    slack_field(title: 'Organization', value: organization, short: true)
  end

  def resource_details(context = {})
    return unless (context['message_detail_level'] || default_config[:message_detail_level]) == 'resources'
    slack_field(title: 'Resources', value: run_context.updated_resources.join(', '))
  end

  def cookbook_details(context = {})
    return unless (context['cookbook_detail_level'] || default_config[:cookbook_detail_level]) == 'all'
    slack_field(title: 'Cookbooks', value: run_context.cookbook_collection.values.map { |cookbook| "#{cookbook.name} #{cookbook.version}" }.join(", "))
  end

  def slack_field(title:, value:, short: false)
    { title: title, value: value, short: short }
  end

  # using cookbook can inject slack fields by adding them to the webhook attribute under the 'custom_fields' key
  def custom_details(context = {})
    context['custom_fields']
  end
end
