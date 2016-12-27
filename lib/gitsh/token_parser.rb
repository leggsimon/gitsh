require 'rltk'

module Gitsh
  class TokenParser < RLTK::Parser
    class Environment < RLTK::Parser::Environment
      def env
        #FIXME
      end

      def command_class(command)
        Commands::GitCommand
      end
    end

    production(:command) do
      clause('compound_word') do |word|
        Commands::Factory.build(
          command_class(word),
          env: env,
          command: word,
          args: [],
        )
      end
      clause('compound_word SPACE argument_list') do |word, _, args|
        Commands::Factory.build(
          command_class(word),
          env: env,
          command: word,
          args: args,
        )
      end
    end

    list(:argument_list, :compound_argument, :SPACE)

    production(:compound_argument) do
      clause('argument') { |arg| arg }
      clause('argument compound_argument') do |arg, compoud|
        Arguments::CompositeArgument.new([arg, compoud])
      end
    end

    production(:argument) do
      clause(:compound_word) { |word| Arguments::StringArgument.new(word) }
      clause(:VAR) { |var| Arguments::VariableArgument.new(var) }
      clause(:compoud_subshell) do |subshell|
        Arguments::Subshell.new(subshell, interpreter_factory: Interpreter)
      end
    end

    production(:compound_word) do
      clause('WORD') { |word| word }
      clause('WORD compound_word') { |word, compound| word + compound }
    end

    production(:compoud_subshell) do
      clause('SUBSHELL') { |subshell| subshell }
      clause('SUBSHELL compoud_subshell') { |subshell, compoud| subshell + compoud }
    end

    finalize
  end
end
