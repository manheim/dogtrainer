require 'cri'
require 'cri/command_dsl'
require 'dogtrainer/someclass'
require 'dogtrainer/logging'

module DogTrainer
  # module for handling CLI interface to the class
  module CLI
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # Geberate and return a {Cri::Command} definition for handling CLI args.
    #
    # @return [Cri::Command] instance
    def self.command
      @cmd ||= Cri::Command.define do
        name        'dogtrainer'
        usage       'dogtrainer [options]'
        summary     'Wrapper around DataDog dogapi gem to simplify creation and management of Monitors and Boards'
        description 'TODO: full description of command here'

        flag :h, :help, 'show help for this command' do |_value, cmd|
          verbose = (ARGV.include?('-v') || ARGV.include?('--verbose'))
          puts cmd.help(verbose: verbose)
          exit 0
        end
        # TODO: add options here using ``option``, ``optional``, ``flag``,
        # ``required``, etc. - see: <http://www.rubydoc.info/gems/cri>
        # --trace is handled by bin/dogtrainer
        flag nil, :trace, 'print full backtraces on error'
        flag :v, :verbose, 'enable verbose output'
        required :s, :someoption, 'some option that requires an argument'

        run do |opts, _args, _cmd|
          # set log level
          DogTrainer::Logging.level = if opts.fetch(:verbose, false)
                                            Log4r::DEBUG
                                          else
                                            Log4r::INFO
                                          end

          # TODO: get and validate our options...
          someoption = opts.fetch(:someoption, 'some default')

          myclass = DogTrainer::SomeClass.new(someoption)
          myclass.do_something
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end

# override Cri::CommandDSL to add a logger
module Cri
  # override Cri::CommandDSL to add a logger
  class CommandDSL
    include DogTrainer::Logging

    # Return a logger instance for the class
    #
    # @return [Log4r::Logger] the logger to use for this class
    def logger
      unless @logger
        @logger = Log4r::Logger.new(@command.name)
        @logger.add DogTrainer::Logging.outputter
      end
      @logger
    end
  end
end
