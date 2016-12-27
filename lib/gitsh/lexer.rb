require 'rltk/lexer'

module Gitsh
  class Lexer < RLTK::Lexer
    rule(/\s*;\s*/) { :SEMICOLON }
    rule(/\s*&&\s*/) { :AND }
    rule(/\s*\|\|\s*/) { :OR }

    rule(/\s+/) { :SPACE }

    rule(/[^\s'"\\$#;&|]+/) { |t| [:WORD, t] }
    rule(/\\[\s'"\\$#;&|]/) { |t| [:WORD, t[1]] }
    rule(/\\/) { |t| [:WORD, t] }

    rule(/#/) { push_state :comment }
    rule(/.*/, :comment) {}
    rule(/$/, :comment) { pop_state }

    rule(/''/) { [:WORD, ''] }
    rule(/'/) { push_state :hard_string }
    rule(/[^'\\]+/, :hard_string) { |t| [:WORD, t] }
    rule(/\\[\\']/, :hard_string) { |t| [:WORD, t[1]] }
    rule(/\\/, :hard_string) { [:WORD, '\\'] }
    rule(/'/, :hard_string) { pop_state }

    rule(/""/) { [:WORD, ''] }
    rule(/"/) { push_state :soft_string }
    rule(/[^"\\$]+/, :soft_string) { |t| [:WORD, t] }
    rule(/\\["\\$]/, :soft_string) { |t| [:WORD, t[1]] }
    rule(/\\/, :soft_string) { [:WORD, '\\'] }
    rule(/"/, :soft_string) { pop_state }

    [:default, :soft_string].each do |state|
      rule(/\$[a-z_][a-z0-9_.-]*/i, state) { |t| [:VAR, t[1..-1]] }
      rule(/\$\{[a-z_][a-z0-9_.-]*\}/i, state) { |t| [:VAR, t[2..-2]] }
    end

    [:default, :soft_string].each do |state|
      rule(/\$\(/, state) do
        @subshell_parens = 1
        push_state :subshell
      end
    end
    rule(/[^()]+/, :subshell) { |t| [:SUBSHELL, t] }
    rule(/\(/, :subshell) do
      @subshell_parens += 1
      [:SUBSHELL, '(']
    end
    rule(/\)/, :subshell) do
      @subshell_parens -= 1
      if @subshell_parens.zero?
        pop_state
      else
        [:SUBSHELL, ')']
      end
    end

    def self.lex(string, file_name = nil, env = RLTK::Lexer::Environment.new(@start_state))
      tokens = super

      if env.state == :hard_string
        tokens.insert(-2, RLTK::Token.new(:MISSING, '\''))
      elsif env.state == :soft_string
        tokens.insert(-2, RLTK::Token.new(:MISSING, '"'))
      elsif env.state == :subshell
        tokens.insert(-2, RLTK::Token.new(:MISSING, ')'))
      end

      tokens
    end
  end
end
