require 'dogtrainer'

class LogTest
  include DogTrainer::Logging
end

describe DogTrainer::Logging do
  subject do
    LogTest.new
  end

  describe '#logger_name' do
    it 'returns the string class name' do
      expect(subject.logger_name).to eq('LogTest')
    end
  end

  describe '#logger' do
    it 'returns a new logger with the right outputter' do
      dbl = double(Log4r::Logger)
      out_dbl = double
      allow(subject).to receive(:logger_name).and_return('myname')
      allow(Log4r::Logger).to receive(:[]).and_return(nil)
      allow(Log4r::Logger).to receive(:new).and_return(dbl)
      allow(DogTrainer::Logging).to receive(:outputter).and_return(out_dbl)
      allow(dbl).to receive(:add)

      expect(subject).to receive(:logger_name).once
      expect(Log4r::Logger).to receive(:[]).once.with('myname')
      expect(Log4r::Logger).to receive(:new).once.with('myname')
      expect(dbl).to receive(:add).once.with(out_dbl)
      expect(subject.logger).to eq(dbl)
    end
    it 'returns the existing @logger if present' do
      dbl = double(Log4r::Logger)
      out_dbl = double
      log = subject.logger
      allow(subject).to receive(:logger_name).and_return('myname')
      allow(Log4r::Logger).to receive(:[]).and_return(nil)
      allow(Log4r::Logger).to receive(:new).and_return(dbl)
      allow(DogTrainer::Logging).to receive(:outputter).and_return(out_dbl)
      allow(dbl).to receive(:add)

      expect(subject).to_not receive(:logger_name)
      expect(Log4r::Logger).to_not receive(:[])
      expect(Log4r::Logger).to_not receive(:new)
      expect(dbl).to_not receive(:add)
      expect(subject.logger).to eq(log)
    end
  end

  describe '#level=' do
    context 'level >= INFO' do
      it 'sets the level' do
        DogTrainer::Logging.level = Log4r::WARN
        expect(DogTrainer::Logging.outputter.level).to eq(Log4r::WARN)
      end
      it 'sets the outputter to default' do
        DogTrainer::Logging.level = Log4r::WARN
        expect(DogTrainer::Logging.outputter.formatter)
          .to be_a(Log4r::PatternFormatter)
        expect(DogTrainer::Logging.outputter.formatter.pattern)
          .to eq('%l\t -> %m')
      end
    end
    context 'level < INFO' do
      it 'sets the level' do
        DogTrainer::Logging.level = Log4r::DEBUG
        expect(DogTrainer::Logging.outputter.level).to eq(Log4r::DEBUG)
      end
      it 'sets the outputter to default' do
        DogTrainer::Logging.level = Log4r::DEBUG
        expect(DogTrainer::Logging.outputter.formatter)
          .to be_a(Log4r::PatternFormatter)
        expect(DogTrainer::Logging.outputter.formatter.pattern)
          .to eq('[%d - %C - %l] %m')
      end
    end
  end
end
