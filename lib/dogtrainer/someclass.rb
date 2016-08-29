require 'dogtrainer/logging'

module DogTrainer
  # example class for DogTrainer
  class SomeClass
    include DogTrainer::Logging

    # Create an instance of SomeClass
    #
    # @param someoption [String] some string option
    def initialize(someoption = nil)
      @someoption = someoption
      logger.debug 'initializing class'
    end

    # Log a few things at different levels.
    def do_something
      logger.info 'doing something'
      logger.fatal "log a fatal message - someoption=#{@someoption}"
    end
  end
end
