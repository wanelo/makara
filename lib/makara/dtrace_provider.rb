require 'usdt'

module Makara
  class DTraceProvider
    attr_reader :provider, :probes

    def initialize
      @provider = USDT::Provider.create(:ruby, :makara)

      @probes = {
        # args: key, value
        cache_read: provider.probe(:cache, :read, :string, :string),
        # args: key, value, ttl
        cache_write: provider.probe(:cache, :write, :string, :string, :integer),
        # args: context_hash
        context_get_current: provider.probe(:context, :get_current, :string),
        # args: context_hash
        context_set_current: provider.probe(:context, :set_current, :string),
        # args: context_hash
        context_get_previous: provider.probe(:context, :get_previous, :string),
        # args: context_hash
        context_set_previous: provider.probe(:context, :set_previous, :string),
        # args:
        proxy_stick_to_master: provider.probe(:proxy, :stick_to_master),
        # args:
        proxy_appropriate_pool: provider.probe(:proxy, :appropriate_pool, :string)
      }
    end

    def self.provider
      @provider ||= new.tap do |p|
        p.provider.enable
      end
    end

    def self.fire!(probe_name, *args)
      raise "Unknown probe: #{probe_name}" unless self.provider.probes[probe_name]
      probe = self.provider.probes[probe_name]
      return probe.fire if probe.enabled? && args.empty?
      probe.fire(*args) if probe.enabled?
    end
  end
end
