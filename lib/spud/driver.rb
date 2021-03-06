# typed: true
require 'sorbet-runtime'
require 'spud/error'
require 'spud/help'
require 'spud/lister'
require 'spud/watch'
require 'spud/cli/parser'
require 'spud/cli/options'
require 'spud/task_runners/task'
require 'spud/task_runners/task_runners'
require 'spud/task_runners/spud_task_runner/task'

module Spud
  class Driver
    extend T::Sig

    sig {returns(T.nilable(Integer))}
    attr_reader :subprocess_pid

    def initialize
      @subprocess_pid = nil
    end

    sig {void}
    def run!
      if debug?
        puts "options: #{options.inspect}"
        puts "task: #{args.task}"
        puts "ordered: #{args.ordered}"
        puts "named: #{args.named}"
      end

      if options.help?
        Help.print!
        return
      end

      unless args.task
        lister.list_tasks!
        return
      end

      if options.inspect?
        inspect!
        return
      end

      invoke!
    rescue Error => error
      puts error.message
      raise error if debug?
    rescue Interrupt => error
      puts "handled interrupt #{error}" if debug?
    rescue => error
      puts "fatal: #{error.message}"
      raise error if debug?
    end

    sig {params(name: String, ordered: T::Array[String], named: T::Hash[T.any(String, Symbol), String]).returns(T.untyped)}
    def invoke(name, ordered, named)
      get_task(name).invoke(ordered, stringify_keys(named))
    end

    sig {params(pid: T.nilable(Integer)).void}
    def register_subprocess(pid)
      @subprocess_pid = pid
    end

    sig {returns(T::Boolean)}
    def debug?
      @debug ||= ENV.key?('SPUD_DEBUG') && ENV['SPUD_DEBUG'] != 'false'
    end

    private

    sig {void}
    def invoke!
      task_name = T.must(args.task)
      task = get_task(task_name)

      watches = options.watches
      watches = task.watches if watches.empty?

      if watches.empty?
        invoke(task_name, args.ordered, args.named)
      else
        raise Error, "watches only supported for Spud tasks" unless task.is_a?(TaskRunners::SpudTaskRunner::Task)

        Watch.run!(
          driver: self,
          task: task_name,
          ordered: args.ordered,
          named: args.named,
          watches: watches,
        )
      end
    end

    sig {void}
    def inspect!
      puts get_task(T.must(args.task)).details
    end

    sig {params(task_name: String).returns(TaskRunners::Task)}
    def get_task(task_name)
      task = tasks[task_name]
      raise Error, "no task found for '#{task_name}'" unless task

      task
    end

    sig {returns(T::Hash[String, TaskRunners::Task])}
    def tasks
      @tasks ||= TaskRunners.get.each_with_object({}) do |task_runner, tasks|
        task_runner.tasks(self).each do |task|
          tasks[task.name] = task
        end
      end
    end

    sig {returns(CLI::Results)}
    def args
      @args ||= CLI::Parser.parse!
    end

    sig {returns(Lister)}
    def lister
      @lister ||= Lister.new(tasks.values)
    end

    sig {returns(CLI::Options)}
    def options
      args.options
    end

    sig {params(hash: T::Hash[T.any(String, Symbol), T.untyped]).returns(T::Hash[String, T.untyped])}
    def stringify_keys(hash)
      hash.each_with_object({}) { |(key, value), new_hash| new_hash[key.to_s] = value }
    end
  end
end
