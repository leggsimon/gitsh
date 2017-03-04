require 'rltk'
require 'gitsh/arguments/string_argument'
require 'gitsh/arguments/composite_argument'
require 'gitsh/arguments/variable_argument'
require 'gitsh/arguments/subshell'
require 'gitsh/commands/factory'
require 'gitsh/commands/git_command'
require 'gitsh/commands/internal_command'
require 'gitsh/commands/shell_command'
require 'gitsh/commands/noop'
require 'gitsh/commands/tree'

module Gitsh
  class Parser < RLTK::Parser
    COMMAND_PREFIX_MATCHER = /^([:!])?(.+)$/
    COMMAND_CLASS_BY_PREFIX = {
      nil => Gitsh::Commands::GitCommand,
      ':' => Gitsh::Commands::InternalCommand,
      '!' => Gitsh::Commands::ShellCommand,
    }.freeze

    left :SEMICOLON
    left :OR
    left :AND

    production(:program) do
      clause('SPACE? commands SEMICOLON? SPACE?') { |_, c, _, _| c }
      clause('SPACE?') { |_| Commands::Noop.new }
    end

    production(:commands) do
      clause('command') { |c| c }
      clause('LEFT_PAREN commands RIGHT_PAREN') { |_, c, _| c }
      clause('commands SEMICOLON commands') { |c1, _, c2| Commands::Tree::Multi.new(c1, c2) }
      clause('commands OR commands') { |c1, _, c2| Commands::Tree::Or.new(c1, c2) }
      clause('commands AND commands') { |c1, _, c2| Commands::Tree::And.new(c1, c2) }
    end

    production(:command) do
      clause('word argument_list?') do |word, args|
        prefix, command = COMMAND_PREFIX_MATCHER.match(word).values_at(1, 2)

        Commands::Factory.build(
          COMMAND_CLASS_BY_PREFIX.fetch(prefix),
          command: command,
          args: (args || []),
        )
      end
    end

    production(:argument_list) do
      clause('SPACE argument') { |_, arg| [arg] }
      clause('argument_list SPACE argument') { |list, _, arg| list + [arg] }
    end

    production(:argument) do
      clause('argument_part') { |part| part }
      clause('argument_part argument') do |part, argument|
        Arguments::CompositeArgument.new([part, argument])
      end
    end

    production(:argument_part) do
      clause(:word) { |word| Arguments::StringArgument.new(word) }
      clause(:VAR) { |var| Arguments::VariableArgument.new(var) }
      clause(:subshell) { |subshell| Arguments::Subshell.new(subshell) }
    end

    production(:word, 'WORD+') { |words| words.inject(:+) }
    production(:subshell, 'SUBSHELL_START SUBSHELL+ SUBSHELL_END') do |_, subshells, _|
      subshells.inject(:+)
    end

    finalize
  end
end
