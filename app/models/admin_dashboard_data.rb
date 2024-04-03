# frozen_string_literal: true

class AdminDashboardData
  include StatsCacheable

  # kept for backward compatibility
  GLOBAL_REPORTS ||= []

  PROBLEM_MESSAGE_PREFIX = "admin-problem:"
  SCHEDULED_PROBLEM_STORAGE_KEY = "admin-found-scheduled-problems-list"

  def initialize(opts = {})
    @opts = opts
  end

  def get_json
    {}
  end

  def as_json(_options = nil)
    @json ||= get_json
  end

  def problems
    problems = []

    problems.concat(ProblemCheck.realtime.flat_map { |c| c.call(@opts).map(&:to_h) })

    problems += self.class.load_found_scheduled_check_problems
    problems.compact!

    if problems.empty?
      self.class.clear_problems_started
    else
      self.class.set_problems_started
    end

    problems
  end

  def self.add_problem_check(*syms, &blk)
    Discourse.deprecate(
      "`AdminDashboardData#add_problem_check` is deprecated. Implement a class that inherits `ProblemCheck` instead.",
      drop_from: "3.3",
    )
  end

  def self.add_found_scheduled_check_problem(problem)
    problems = load_found_scheduled_check_problems
    if problem.identifier.present?
      return if problems.find { |p| p.identifier == problem.identifier }
    end
    set_found_scheduled_check_problem(problem)
  end

  def self.set_found_scheduled_check_problem(problem)
    Discourse.redis.rpush(SCHEDULED_PROBLEM_STORAGE_KEY, JSON.dump(problem.to_h))
  end

  def self.clear_found_scheduled_check_problems
    Discourse.redis.del(SCHEDULED_PROBLEM_STORAGE_KEY)
  end

  def self.clear_found_problem(identifier)
    problems = load_found_scheduled_check_problems
    problem = problems.find { |p| p.identifier == identifier }
    Discourse.redis.lrem(SCHEDULED_PROBLEM_STORAGE_KEY, 1, JSON.dump(problem.to_h))
  end

  def self.load_found_scheduled_check_problems
    found_problems = Discourse.redis.lrange(SCHEDULED_PROBLEM_STORAGE_KEY, 0, -1)

    return [] if found_problems.blank?

    found_problems.filter_map do |problem|
      begin
        ProblemCheck::Problem.from_h(JSON.parse(problem))
      rescue JSON::ParserError => err
        Discourse.warn_exception(
          err,
          message: "Error parsing found problem JSON in admin dashboard: #{problem}",
        )
        nil
      end
    end
  end

  def self.fetch_stats
    new.as_json
  end

  def self.reports(source)
    source.map { |type| Report.find(type).as_json }
  end

  def self.stats_cache_key
    "dashboard-data-#{Report::SCHEMA_VERSION}"
  end

  def self.problems_started_key
    "dash-problems-started-at"
  end

  def self.set_problems_started
    existing_time = Discourse.redis.get(problems_started_key)
    Discourse.redis.setex(problems_started_key, 14.days.to_i, existing_time || Time.zone.now.to_s)
  end

  def self.clear_problems_started
    Discourse.redis.del problems_started_key
  end

  def self.problems_started_at
    s = Discourse.redis.get(problems_started_key)
    s ? Time.zone.parse(s) : nil
  end

  def self.fetch_problems(opts = {})
    new(opts).problems
  end
end
