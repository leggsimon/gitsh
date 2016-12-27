require 'spec_helper'
require 'gitsh/token_parser'

describe Gitsh::TokenParser do
  describe '.parse' do
    it 'parses Git commands' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens([:WORD, 'commit'], [:EOS]))

      expect(result).to eq command
      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(command: 'commit', args: []),
      )
    end

    it 'parses internal commands' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens([:WORD, ':echo'], [:EOS]))

      expect(result).to eq command
      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::InternalCommand,
        hash_including(command: 'echo', args: []),
      )
    end

    it 'parses shell commands' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens([:WORD, '!ls'], [:EOS]))

      expect(result).to eq command
      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::ShellCommand,
        hash_including(command: 'ls', args: []),
      )
    end

    it 'parses Git commands broken into multiple words' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens(
        [:WORD, 'com'], [:WORD, 'mit'], [:EOS]
      ))

      expect(result).to eq command
      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(command: 'commit', args: []),
      )
    end

    it 'parses commands with arguments' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens(
        [:WORD, 'commit'], [:SPACE], [:WORD, '-m'], [:SPACE], [:WORD, 'WIP'],
        [:EOS],
      ))

      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(
          command: 'commit',
          args: [
            Gitsh::Arguments::StringArgument.new('-m'),
            Gitsh::Arguments::StringArgument.new('WIP'),
          ],
        ),
      )
    end

    it 'parses commands with variable arguments' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens(
        [:WORD, 'commit'], [:SPACE], [:WORD, '-m'], [:SPACE], [:VAR, 'message'],
        [:EOS],
      ))

      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(
          command: 'commit',
          args: [
            Gitsh::Arguments::StringArgument.new('-m'),
            Gitsh::Arguments::VariableArgument.new('message'),
          ],
        ),
      )
    end

    it 'parses commands with subshell arguments' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens(
        [:WORD, 'commit'], [:SPACE], [:WORD, '-m'], [:SPACE],
        [:SUBSHELL, ':echo $message'], [:EOS],
      ))

      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(
          command: 'commit',
          args: [
            Gitsh::Arguments::StringArgument.new('-m'),
            Gitsh::Arguments::Subshell.new(':echo $message', interpreter_factory: double),
          ],
        ),
      )
    end

    it 'parses commands with composite arguments' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens(
        [:WORD, 'commit'], [:SPACE], [:WORD, '-m'], [:SPACE],
        [:WORD, 'Written by: '],
        [:VAR, 'user.name'], [:EOS],
      ))

      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(
          command: 'commit',
          args: [
            Gitsh::Arguments::StringArgument.new('-m'),
            Gitsh::Arguments::CompositeArgument.new([
              Gitsh::Arguments::StringArgument.new('Written by: '),
              Gitsh::Arguments::VariableArgument.new('user.name'),
            ]),
          ],
        ),
      )
    end

    it 'parses two commands combined with &&' do
      result = described_class.parse(tokens(
        [:WORD, 'add'], [:SPACE], [:WORD, '.'],
        [:AND], [:WORD, 'commit'], [:EOS],
      ))

      expect(result).to be_a(Gitsh::Commands::Tree::And)
    end

    it 'parses two commands combined with ||' do
      result = described_class.parse(tokens(
        [:WORD, 'add'], [:SPACE], [:WORD, '.'],
        [:OR], [:WORD, ':echo'], [:SPACE], [:WORD, 'Oops'], [:EOS],
      ))

      expect(result).to be_a(Gitsh::Commands::Tree::Or)
    end

    it 'parses two commands combined with ;' do
      result = described_class.parse(tokens(
        [:WORD, 'add'], [:SPACE], [:WORD, '.'],
        [:SEMICOLON], [:WORD, 'commit'], [:EOS],
      ))

      expect(result).to be_a(Gitsh::Commands::Tree::Multi)
    end

    it 'parses a command with a trailing semicolon' do
      command = double(:command)
      allow(Gitsh::Commands::Factory).to receive(:build).and_return(command)

      result = described_class.parse(tokens(
        [:WORD, 'commit'], [:SEMICOLON], [:EOS],
      ))

      expect(result).to eq command
      expect(Gitsh::Commands::Factory).to have_received(:build).with(
        Gitsh::Commands::GitCommand,
        hash_including(command: 'commit', args: []),
      )
    end
  end

  def tokens(*tokens)
    tokens.map.with_index do |token, i|
      type, value = token
      pos = RLTK::StreamPosition.new(i, 1, i, 10, nil)
      RLTK::Token.new(type, value, pos)
    end
  end
end
