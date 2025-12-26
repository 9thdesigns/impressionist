# frozen_string_literal: true

module Impressionist
  module CounterCache
    attr_reader :impressionable_class, :entity

    private

    # A valid impression must:
    # - have a valid impressionable class
    # - be counter_caching
    # - have a record saved in the db
    # then it should give it a try
    def impressionable_counter_cache_updatable?
      updatable? && impressionable_try
    end

    def updatable?
      valid_impressionable_class? && impressionable_find
    end

    def valid_impressionable_class?
      set_impressionable_class && counter_caching?
    end

    def set_impressionable_class
      klass_name = impressionable_type
      return false if klass_name.blank?

      # Security: Validate class name format to prevent injection
      unless klass_name.match?(/\A[A-Za-z][A-Za-z0-9_:]*\z/)
        impressionist_log("Invalid impressionable_type format: #{klass_name.inspect}")
        return false
      end

      # Security: Check against allowlist if configured
      if Impressionist.allowed_impressionable_types.present?
        unless Impressionist.valid_impressionable_type?(klass_name)
          impressionist_log("Impressionable type not in allowlist: #{klass_name}")
          return false
        end
      end

      return false unless klass_name.match?(/\A[A-Za-z][A-Za-z0-9_:]*\z/)

      # Security: Use safe_constantize with additional validation
      klass = klass_name.safe_constantize

      return false unless klass.present? && klass < ActiveRecord::Base
      
      # Ensure the constantized class is a valid ActiveRecord model
      if klass.nil?
        impressionist_log("Could not constantize: #{klass_name}")
        return false
      end

      unless klass < ActiveRecord::Base
        impressionist_log("#{klass_name} is not an ActiveRecord model")
        return false
      end

      @impressionable_class = klass
      true
    end

    def impressionist_log(str, mode = :error)
      Rails.logger.send(mode.to_s, "[Impressionist] #{str}")
    end

    # Receives an entity (instance of a Model) and then tries to update
    # counter_cache column
    # entity is an impressionable instance model
    def impressionable_try
      entity.try(:update_impressionist_counter_cache)
    end

    def impressionable_find
      # Security: Validate impressionable_id before querying
      id = impressionable_id
      return false if id.blank?

      # Validate ID format (integer or UUID)
      unless id.to_s.match?(/\A(\d+|[a-f0-9\-]{36})\z/i)
        impressionist_log("Invalid impressionable_id format: #{id.inspect}")
        return false
      end

      exception_rescuer do
        @entity = impressionable_class.find(id)
      end
      
      @entity.present?
    end

    def counter_caching?
      if impressionable_class.respond_to?(:impressionist_counter_caching?)
        impressionable_class.impressionist_counter_caching?
      else
        false
      end
    end

    # Returns false, as it is only handling one exception
    # It would make updatable fail, thereafter it would not try
    # to update cache_counter
    def exception_rescuer
      yield
    rescue ActiveRecord::RecordNotFound
      exception_to_log
      false
    rescue StandardError => e
      impressionist_log("Unexpected error finding impressionable: #{e.message}")
      false
    end

    def exception_to_log
      impressionist_log("Couldn't find #{impressionable_class} with id=#{impressionable_id}")
    end
  end
end
