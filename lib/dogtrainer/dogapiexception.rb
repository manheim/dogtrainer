module DogTrainer
  # Exception raised for Datadog API errors (non-200 status code)
  class DogApiException < StandardError
    attr_reader :statuscode
    attr_reader :content

    def initialize(response)
      @statuscode = response[0]
      @content = if response.length > 1
                   response[1]
                 else
                   {}
                 end
      msg = "Datadog API call returned status #{@statuscode}"
      if @content.include?('errors')
        msg << ":\n"
        if @content['errors'].is_a?(Array)
          @content['errors'].each { |e| msg << "#{e}\n" }
        else
          msg << "#{content['errors']}\n"
        end
      end
      super(msg)
    end
  end
end
