
module UpdateableViewsInheritance# :nodoc:
  module ActiveRecordExtensions #:nodoc:
    module ClassMethods #:nodoc:
      attr_accessor :disable_inheritance_instantiation

      def instantiate(attributes, column_types = {})
        object = super(attributes, column_types = {})
        if object.class.name == self.name || self.disable_inheritance_instantiation
          object
        else
          object.class.find(attributes.with_indifferent_access[:id])
        end
      end
    end
  end
end

# Here we override AR class methods. If you need to override
# instance methods, prepend() them to the class, not to the singleton class
ActiveRecord::Base.singleton_class.send :prepend, UpdateableViewsInheritance::ActiveRecordExtensions::ClassMethods

