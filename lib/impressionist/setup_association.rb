module Impressionist
  # Impressionist::SetupAssociation.new(entity).set
  class SetupAssociation
    def initialize(receiver)
      @receiver = receiver
    end


    def define_belongs_to
      if ::Rails::VERSION::MAJOR.to_i >= 5
        receiver.belongs_to(:impressionable, :polymorphic => true, :optional => true)	         
      else
        receiver.belongs_to(:impressionable, :polymorphic => true)
      end
    end

    def set
      define_belongs_to
    end

    private
      attr_reader :receiver
  end
end


