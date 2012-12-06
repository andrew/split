module Split
  class Alternative
    attr_accessor :name
    attr_accessor :experiment_name
    attr_accessor :weight

    def initialize(name, experiment_name)
      @experiment_name = experiment_name
      if Hash === name
        @name = name.keys.first
        @weight = name.values.first
      else
        @name = name
        @weight = 1
      end
    end

    def to_s
      name
    end

    def participant_count
      Split.backend.alternative_participant_count(experiment_name, name)
    end

    def completed_count
      Split.backend.alternative_completed_count(experiment_name, name)
    end

    def increment_participation
      Split.backend.incr_alternative_participant_count(experiment_name, name)
    end

    def increment_completion
      Split.backend.incr_alternative_completed_count(experiment_name, name)
    end

    def control?
      experiment.control.name == self.name
    end

    def conversion_rate
      return 0 if participant_count.zero?
      (completed_count.to_f/participant_count.to_f)
    end

    def experiment
      Split::Experiment.find(experiment_name)
    end

    def z_score
      # CTR_E = the CTR within the experiment split
      # CTR_C = the CTR within the control split
      # E = the number of impressions within the experiment split
      # C = the number of impressions within the control split

      control = experiment.control

      alternative = self

      return 'N/A' if control.name == alternative.name

      ctr_e = alternative.conversion_rate
      ctr_c = control.conversion_rate

      e = alternative.participant_count
      c = control.participant_count

      return 0 if ctr_c.zero?

      standard_deviation = ((ctr_e / ctr_c**3) * ((e*ctr_e)+(c*ctr_c)-(ctr_c*ctr_e)*(c+e))/(c*e)) ** 0.5

      z_score = ((ctr_e / ctr_c) - 1) / standard_deviation
    end

    def save
      Split.backend.hsetnx key, 'participant_count', 0
      Split.backend.hsetnx key, 'completed_count', 0
    end

    def reset
      Split.backend.reset(experiment_name, name)
    end

    def delete
      Split.backend.delete(key)
    end

    def self.valid?(name)
      String === name || hash_with_correct_values?(name)
    end

    def self.hash_with_correct_values?(name)
      Hash === name && String === name.keys.first && Float(name.values.first) rescue false
    end

    private

    def key
      "#{experiment_name}:#{name}"
    end
  end
end