require 'log4r'

module DogTrainer
  # module to setup logging per-class throughout DogTrainer
  module Logging
    # Return the name of the class this logger is part of
    #
    # @return [String] logger class name
    def logger_name
      self.class.to_s
    end

    # Return a logger for the current class
    #
    # @return [Log4r::Logger]
    def logger
      if @logger.nil?
        name = logger_name
        if Log4r::Logger[name]
          @logger = Log4r::Logger[name]
        else
          @logger = Log4r::Logger.new(name)
          @logger.add(DogTrainer::Logging.outputter)
        end
      end
      @logger
    end

    class << self
      # Set the logger level and the output formatter
      def level=(level)
        outputter.level = level
        @level = level

        outputter.formatter = if level < Log4r::INFO
                                debug_formatter
                              else
                                default_formatter
                              end
      end

      # @!attribute [r] level
      #   @return [Integer] The current log level. Lower numbers correspond
      #     to more verbose log levels.
      attr_reader :level

      # @!attribute [r] formatter
      #   @api private
      #   @return [Log4r::Formatter]
      attr_reader :formatter

      # @!attribute [r] outputter
      #   @api private
      #   @return [Log4r::Outputter]
      attr_reader :outputter

      # Return a new log formatter with the default pattern
      #
      # @return [Log4r::PatternFormatter]
      def default_formatter
        Log4r::PatternFormatter.new(pattern: '%l\t -> %m')
      end

      # Return a new log formatter with the debug-level pattern
      #
      # @return [Log4r::PatternFormatter]
      def debug_formatter
        Log4r::PatternFormatter.new(pattern: '[%d - %C - %l] %m')
      end

      # Return the default log outputter (console)
      #
      # @return [Log4r::StderrOutputter]
      def default_outputter
        Log4r::StderrOutputter.new 'console'
      end
    end

    Log4r::Logger.global.level = Log4r::ALL

    @level     = Log4r::INFO
    @formatter = default_formatter
    @outputter = default_outputter
  end
end
