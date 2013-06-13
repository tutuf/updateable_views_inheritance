module ActiveRecord #:nodoc:
  class Base #:nodoc:
    class << self
      private
      def instantiate_with_uvi_support( record )
        object = instantiate_without_uvi_support( record )
        if object.class.name == self.name
          object
        else
          object.class.find( object.id )
        end
      end
      alias_method_chain :instantiate, :uvi_support
    end
  end
end
