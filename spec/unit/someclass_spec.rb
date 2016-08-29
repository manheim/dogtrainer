require 'spec_helper'
require 'dogtrainer'

describe DogTrainer::SomeClass do
  describe '#initialize' do
    subject { DogTrainer::SomeClass.new }
    it 'sets defaults' do
      expect(subject.instance_variable_get('@someoption')).to be_nil
    end
    it 'overrides defaults' do
      x = DogTrainer::SomeClass.new('foo')
      expect(x.instance_variable_get('@someoption')).to eq('foo')
    end
  end

  describe '#do_something' do
    subject { DogTrainer::SomeClass.new('foobar') }
    it 'logs things' do
      allow(subject.logger).to receive(:info)
      allow(subject.logger).to receive(:fatal)
      expect(subject.logger).to receive(:info).once.with('doing something')
      expect(subject.logger).to receive(:fatal).once\
        .with('log a fatal message - someoption=foobar')
      subject.do_something
    end
  end
end
