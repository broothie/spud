# typed: strict
require 'sorbet-runtime'
require 'stringio'
require 'spud/driver'
require 'spud/shell/command'
require 'spud/task_runners/task'

module Spud
  module TaskRunners
    module Make
      class Task < TaskRunners::Task
        extend T::Sig

        sig {override.returns(String)}
        attr_reader :name

        sig {override.params(driver: Driver).returns(T::Array[TaskRunners::Task])}
        def self.tasks(driver)
          return [] unless File.exist?('Makefile')

          if `command -v make`.empty?
            puts 'Makefile detected, but no installation of `make` exists. Skipping make...'
            return []
          end

          source = File.read('Makefile')
          T.unsafe(source.scan(/^(\S+):.*/)).map(&:first).map do |name|
            new(driver, name, source)
          end
        end

        sig {params(driver: Driver, name: String, make_source: String).void}
        def initialize(driver, name, make_source)
          @driver = driver
          @name = name
          @make_source = make_source
        end

        sig {override.params(ordered: T::Array[String], named: T::Hash[String, String]).returns(T.untyped)}
        def invoke(ordered, named)
          system("make #{name}")
        end

        sig {override.returns(String)}
        def source
          'Makefile'
        end

        sig {override.returns(String)}
        def details
          lines = @make_source.split("\n")
          cursor = 0

          cursor += 1 until lines[cursor]&.start_with?(name)

          builder = StringIO.new
          while lines[cursor] && !lines[cursor]&.empty?
            builder.puts lines[cursor]
            cursor += 1
          end

          builder.string
        end
      end
    end
  end
end
