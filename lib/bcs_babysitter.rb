module NRB

  autoload :LogEntry, 'log_entry'

  class BCSBabysitter

    attr_accessor :pause

    def initialize(bcs: nil, sns: nil, topic_arn: nil)
      raise ArgumentError.new("Need bcs: parameter") if bcs.nil?
      raise ArgumentError.new("Need sns: parameter") if sns.nil?
      raise ArgumentError.new("Need topic_arn: parameter") if topic_arn.nil?

      self.bcs = bcs
      self.pause ||= 5
      self.sns = sns
      self.topic_arn = topic_arn
    end


    def monitor
      while true do
        begin
          self.current = bcs.temp_probes
          changes = setpoint_changes
          alert changes: changes
          self.previous = current
        rescue Faraday::ConnectionFailed => e
          message = "#{Time.now} #{e}"
          alert message: message
        end
        sleep pause
      end
    end


    def setpoint_changes
      changes = []
      return changes if previous.nil?
      previous.each_with_index do |probe,i|
        if probe.name != current[i].name
          changes << "#{probe.name} changed names to #{current[i].name}"
        end
        if probe.setpoint != current[i].setpoint
          changes << "#{probe.name} changed setpoint from #{probe.setpoint} to #{current[i].setpoint}"
        end
      end
      changes
    end

  private

    attr_accessor :bcs, :current, :previous, :sns, :topic_arn

    def alert(changes: [], message: nil)
      if message.nil?
        if changes.empty?
          return
        else
          message = "#{Time.now} #{changes.inspect}"
        end
      end
      puts message
      begin
        sns.publish topic_arn: topic_arn, message: message
      rescue Aws::SNS::Errors::ServiceError => e
        puts "#{Time.now} #{e}"
      end
    end

  end

end
