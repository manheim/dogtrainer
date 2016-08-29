require 'spec_helper'
require 'dogtrainer'

describe DogTrainer::CLI do
  subject do
    DogTrainer::CLI.command
  end

  context 'configuration' do
    it 'has the correct name' do
      expect(subject.name).to eq('dogtrainer')
    end
    it 'has the correct usage' do
      expect(subject.usage).to eq('dogtrainer [options]')
    end
    it 'has the correct summary' do
      expect(subject.summary).to eq('Wrapper around DataDog dogapi gem to simplify creation and management of Monitors and Boards')
    end
    it 'has the correct description' do
      expect(subject.description).to eq('TODO: full description of command here')
    end
  end
  context 'argument tests' do
    it 'prints help and exits on -h' do
      allow(DogTrainer::SomeClass).to receive(:new)
      allow(DogTrainer::SomeClass).to receive(:do_something)
      allow(subject).to receive(:help).and_return('myhelp')
      expect(DogTrainer::SomeClass).to_not receive(:new)
      expect(DogTrainer::SomeClass).to_not receive(:do_something)
      expect { subject.run(['-h']) }.to raise_error { |error|
        expect(error).to be_a(SystemExit)
        expect(error.status).to eq(0)
      }.and output("myhelp\n").to_stdout
    end
    it 'prints help and exits on --help' do
      allow(DogTrainer::SomeClass).to receive(:new)
      allow(DogTrainer::SomeClass).to receive(:do_something)
      allow(subject).to receive(:help).and_return('myhelp')
      expect(DogTrainer::SomeClass).to_not receive(:new)
      expect(DogTrainer::SomeClass).to_not receive(:do_something)
      expect { subject.run(['--help']) }.to raise_error { |error|
        expect(error).to be_a(SystemExit)
        expect(error.status).to eq(0)
      }.and output("myhelp\n").to_stdout
    end
  end
  context 'argument passing' do
    let(:dbl) { double('DogTrainer::SomeClass') }
    it 'passes nil and does something if someoption not specified' do
      allow(DogTrainer::SomeClass).to receive(:new).and_return(dbl)
      allow(dbl).to receive(:do_something)
      allow(DogTrainer::Logging).to receive(:level=)
      expect(DogTrainer::SomeClass).to receive(:new).once\
        .with('some default')
      expect(dbl).to receive(:do_something).once
      expect(DogTrainer::Logging).to receive(:level=).once.with(Log4r::INFO)
      expect { subject.run([]) }.to_not raise_error
    end
    it 'passes someoption to the class and does something' do
      allow(DogTrainer::SomeClass).to receive(:new).and_return(dbl)
      allow(dbl).to receive(:do_something)
      allow(DogTrainer::Logging).to receive(:level=)
      expect(DogTrainer::SomeClass).to receive(:new).once.with('foobar')
      expect(dbl).to receive(:do_something).once
      expect(DogTrainer::Logging).to receive(:level=).once.with(Log4r::INFO)
      expect { subject.run(['--someoption', 'foobar']) }.to_not raise_error
    end
    it 'sets logging level with -v' do
      allow(DogTrainer::SomeClass).to receive(:new).and_return(dbl)
      allow(dbl).to receive(:do_something)
      allow(DogTrainer::Logging).to receive(:level=)
      expect(DogTrainer::SomeClass).to receive(:new).once\
        .with('some default')
      expect(dbl).to receive(:do_something).once
      expect(DogTrainer::Logging).to receive(:level=).once\
        .with(Log4r::DEBUG)
      expect { subject.run(['-v']) }.to_not raise_error
    end
  end
end

describe Cri::CommandDSL do
  subject { Cri::CommandDSL.new(nil) }
  it 'creates a new logger on the first call' do
    dbl = double(Log4r::Logger)
    out_dbl = double
    allow(Log4r::Logger).to receive(:new).and_return(dbl)
    allow(DogTrainer::Logging).to receive(:outputter).and_return(out_dbl)
    allow(dbl).to receive(:add)
    expect(Log4r::Logger).to receive(:new).once
    expect(dbl).to receive(:add).once.with(out_dbl)
    expect(subject.logger).to eq(dbl)
  end
  it 'returns the existing logger on subsequent calls' do
    dbl = double(Log4r::Logger)
    out_dbl = double
    allow(Log4r::Logger).to receive(:new).and_return(dbl)
    allow(DogTrainer::Logging).to receive(:outputter).and_return(out_dbl)
    allow(dbl).to receive(:add)
    expect(Log4r::Logger).to receive(:new).once
    expect(dbl).to receive(:add).once.with(out_dbl)
    expect(subject.logger).to eq(dbl)
    expect(subject.logger).to eq(dbl)
  end
end
