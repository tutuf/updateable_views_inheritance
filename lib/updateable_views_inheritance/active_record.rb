module ActiveRecord #:nodoc:
  class Base #:nodoc:
    class << self
      private
      def instantiate_with_updateable_views_inheritance_support( record )
        object = instantiate_without_updateable_views_inheritance_support( record )
        if object.class.name == self.name
          object
        else
          object.class.find( object.id )
        end
      end
      alias_method_chain :instantiate, :updateable_views_inheritance_support
    end
  end
end
