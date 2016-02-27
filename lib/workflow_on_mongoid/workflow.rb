require 'workflow'

module Workflow
  module MongoidInstanceMethods
    def load_workflow_state
      send(self.class.workflow_column)
    end

    def persist_workflow_state(new_value)
      self.update_attribute(self.class.workflow_column, new_value)
    end

    private
    def write_initial_state
      send("#{self.class.workflow_column}=", current_state.to_s) if load_workflow_state.blank?
    end
  end

  def self.included(klass)
    klass.send :include, InstanceMethods

    # backup the parent workflow spec, making accessible through #inherited_workflow_spec
    if klass.superclass.respond_to?(:workflow_spec, true)
      klass.module_eval do
        # see http://stackoverflow.com/a/2495650/111995 for implementation explanation
        pro = Proc.new { klass.superclass.workflow_spec }
        singleton_class = class << self;
          self;
        end
        singleton_class.send(:define_method, :inherited_workflow_spec) do
          pro.call
        end
      end
    end

    klass.extend ClassMethods

    # Look for a hook; otherwise detect based on ancestor class.
    if klass.respond_to?(:workflow_adapter)
      klass.send :include, klass.workflow_adapter
    elsif Object.const_defined?(:ActiveRecord) && klass < ActiveRecord::Base
      klass.send :include, ActiveRecordInstanceMethods
      klass.before_validation :write_initial_state
    elsif Object.const_defined?(:Remodel) && klass < Remodel::Entity
      klass.send :include, RemodelInstanceMethods
    elsif Object.const_defined?(:Mongoid) && klass < Mongoid::Document
      klass.class_eval do
        klass.send :include, MongoidInstanceMethods
        klass.before_validation :write_initial_state
      end
    end
  end
end