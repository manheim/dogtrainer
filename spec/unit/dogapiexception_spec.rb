require 'dogtrainer'

describe DogTrainer::DogApiException do
  subject { DogTrainer::DogApiException }
  describe 'attr_readers' do
    it 'has statuscode attr_reader' do
      expect(subject.new(['500', { 'errors' => ['foo'] }]).statuscode)
        .to eq('500')
    end
    it 'has content attr_reader' do
      expect(subject.new(['500', { 'errors' => ['foo'] }]).content)
        .to eq('errors' => ['foo'])
    end
  end
  describe 'when response is a single-element array' do
    it 'sets content to an empty hash' do
      expect(subject.new(['500']).content).to eq({})
    end
  end
  describe 'with errors in content' do
    context 'when errors is an Array' do
      it 'includes errors in the message' do
        x = subject.new(['500', { 'errors' => ['foo', "bar\nbaz"] }])
        expect(x.to_s)
          .to eq("Datadog API call returned status 500:\nfoo\nbar\nbaz\n")
      end
    end
    context 'when errors is a String' do
      it 'includes errors in the message' do
        x = subject.new(['500', { 'errors' => 'foo' }])
        expect(x.to_s)
          .to eq("Datadog API call returned status 500:\nfoo\n")
      end
    end
  end
  describe 'without errors in content' do
    it 'does not include errors in the message' do
      x = subject.new(['500', {}])
      expect(x.to_s).to eq('Datadog API call returned status 500')
    end
  end
  describe 'with a nil content' do
    it 'produces a correct message' do
      x = subject.new(['404', {}])
      expect(x.to_s).to eq('Datadog API call returned status 404')
    end
  end
end
