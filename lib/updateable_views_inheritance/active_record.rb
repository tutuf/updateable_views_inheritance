module ActiveRecord #:nodoc:
  class Base #:nodoc:
    class << self
      attr_accessor :disable_inheritance_instantiation

      private
      def instantiate_with_updateable_views_inheritance_support(attributes, column_types = {})
        object = instantiate_without_updateable_views_inheritance_support(attributes, column_types = {})
        if object.class.name == self.name || self.disable_inheritance_instantiation
          object
        else
          object.class.find(attributes.with_indifferent_access[:id])
        end
      end
      alias_method_chain :instantiate, :updateable_views_inheritance_support
    end
  end
end
