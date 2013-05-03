module Makara
  
  module Connection
    # module which gets extended on adapter instances
    # overrides execute so it will delegate to the makara adapter once
    module Decorator

      # if we have a makara adapter and we're not alrady hijacked,
      # allow the adapter to handle the execute

      def execute(*args)
        adapter = Makara.connection
        acceptor = (adapter && !adapter.hijacking?) ? adapter : nil
        return (defined?(super) ? super : nil) if acceptor.nil?
        acceptor.execute(*args)
      end

      def exec_query(*args)
        adapter = Makara.connection
        acceptor = (adapter && !adapter.hijacking?) ? adapter : nil
        return (defined?(super) ? super : nil) if acceptor.nil?
        acceptor.exec_query(*args)
      end
    end
  end
end