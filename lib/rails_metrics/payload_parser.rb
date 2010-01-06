module RailsMetrics
  # Usually the payload for a given notification contains a lot of information,
  # as backtrace, controllers, response bodies and so on, and we don't need to
  # store all this data in the database.
  #
  # So, by default, RailsMetrics does not store any payload in the database, unless
  # you configure it. To do that, you simply need to call +add+:
  #
  #   RailsMetrics::PayloadParser.add "active_record.sql"
  #
  # "activerecord.sql" has as paylaod the :name (like "Product Load") and the :sql
  # to be performed. And now both of them will be stored in the database. You can
  # also select or remove any information from the hash through :slice and :except
  # options:
  #
  #   RailsMetrics::PayloadParser.add "active_record.sql", :slice => :sql
  #
  # Or:
  #
  #   RailsMetrics::PayloadParser.add "active_record.sql", :except => :name
  #
  # Finally, in some cases manipulating the hash is not enough and you might need
  # to customize it further, as in "action_controller.process_action". In such
  # cases, you can pass a block which will receive the payload as argument:
  #
  #   RailsMetrics::PayloadParser.add "action_controler.process_action" do |payload|
  #     { :method => payload[:controller].request.method }
  #   end
  #
  # RailsMetrics all come with default parsers (defined below), but if you want to gather
  # some info for other libraries (for example, paperclip) you need to define the parser
  # on your own. You can remove any parser whenever you want:
  #
  #   RailsMetrics::PayloadParser.delete "active_record.sql"
  #
  module PayloadParser
    @@parsers = {}

    def self.add(*names, &block)
      options = names.extract_options!

      names.each do |name|
        @@parsers[name.to_s] = if block_given?
          block
        elsif options.present?
          options.to_a.flatten
        else
          :all
        end
      end
    end

    def self.delete(*names)
      names.each { |name| @parsers.delete(name.to_s) }
    end

    def self.filter(name, payload)
      parser = @@parsers[name]
      case parser
      when Array
        payload.send(*args)
      when Proc
        parser.call(payload)
      when :all
        payload
      end
    end

    add "active_record.sql", "action_controller.write_fragment", "action_controller.read_fragment",
        "action_controller.exist_fragment?", "action_controller.expire_fragment",
        "action_controller.expire_page", "action_controller.cache_page"

    add "action_controller.render_template" do |payload|
      payload.each_value do |value|
        value.gsub!(Rails.root.to_s, "RAILS_ROOT")
      end
    end

    add "action_controller.process_action" do |payload|
      controller = payload.delete(:controller)

      {
        :controller => controller.controller_name,
        :action     => payload[:action],
        :method     => controller.request.method,
        :formats    => controller.request.formats
      }
    end

    add "action_mailer.deliver" do |payload|
      mail = payload[:mail]

      {
        :from    => mail.from,
        :to      => mail.to,
        :subject => mail.subject
      }
    end

    # TODO Render with exception
    # add "action_dispatch.show_exception"
  end
end