require 'spec_helper'
require 'gitsh/commands/internal_command'

describe Gitsh::Commands::InternalCommand::Exit do
  it_behaves_like "an internal command"

  describe '#execute' do
    it 'exits the program' do
      command = described_class.new(double('env'), 'exit', arguments())
      expect { command.execute }.to raise_exception(SystemExit)
    end
  end
end
