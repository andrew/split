module Split
  class Experiment
    attr_accessor :name

    def initialize(name, *alternative_names)
      @name = name.to_s
      @alternatives = alternative_names.map do |alternative|
                        Split::Alternative.new(alternative, name)
                      end
    end

    def winner
      if w = Split.backend.winner(name)
        Split::Alternative.new(w, name)
      else
        nil
      end
    end

    def control
      alternatives.first
    end

    def reset_winner
      Split.backend.reset_winner(name)
    end

    def winner=(winner_name)
      Split.backend.set_winner(name, winner_name)
    end

    def start_time
      Split.backend.start_time(name)
    end

    def alternatives
      @alternatives.dup
    end

    def alternative_names
      @alternatives.map(&:name)
    end

    def next_alternative
      winner || random_alternative
    end

    def random_alternative
      weights = alternatives.map(&:weight)

      total = weights.inject(:+)
      point = rand * total

      alternatives.zip(weights).each do |n,w|
        return n if w >= point
        point -= w
      end
    end

    def version
      @version ||= (Split.backend.version(name) || 0)
    end

    def increment_version
      @version = Split.backend.increment_version(name)
    end

    def key
      if version.to_i > 0
        "#{name}:#{version}"
      else
        name
      end
    end

    def finished_key
      "#{key}:finished"
    end

    def reset
      alternatives.each(&:reset)
      reset_winner
      increment_version
    end

    def delete
      alternatives.each(&:delete)
      reset_winner
      Split.backend.delete(name)
      increment_version
    end

    def new_record?
      !Split.backend.exists?(name)
    end

    def save
      if new_record?
        Split.backend.save(name, @alternatives, Time.now)
      end
    end

    def self.load_alternatives_for(name)
      Split.backend.alternatives(name)
    end

    def self.all
      Split.backend.all_experiments.map {|e| find(e)}
    end

    def self.find(name)
      if Split.backend.exists?(name)
        self.new(name, *load_alternatives_for(name))
      end
    end

    def self.find_or_create(key, *alternatives)
      name = key.to_s.split(':')[0]

      if alternatives.length == 1
        if alternatives[0].is_a? Hash
          alternatives = alternatives[0].map{|k,v| {k => v} }
        else
          raise ArgumentError, 'You must declare at least 2 alternatives'
        end
      end

      alts = initialize_alternatives(alternatives, name)

      if Split.backend.exists?(name)
        existing_alternatives = load_alternatives_for(name)
        if existing_alternatives == alts.map(&:name)
          experiment = self.new(name, *alternatives)
        else
          exp = self.new(name, *existing_alternatives)
          exp.reset
          exp.alternatives.each(&:delete)
          experiment = self.new(name, *alternatives)
          experiment.save
        end
      else
        experiment = self.new(name, *alternatives)
        experiment.save
      end
      return experiment
    end
    
    def self.initialize_alternatives(alternatives, name)

      unless alternatives.all? { |a| Split::Alternative.valid?(a) }
        raise ArgumentError, 'Alternatives must be strings'
      end

      alternatives.map do |alternative|
        Split::Alternative.new(alternative, name)
      end
    end
  end
end
