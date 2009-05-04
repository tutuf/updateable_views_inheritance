module ActiveRecord
  class Base
    class << self
      private
      def instantiate_with_clti_support( record )
        object = instantiate_without_clti_support( record )
        if object.class.name == self.name
          object
        else
          object.class.find( object.id )
        end
      end
      alias_method_chain :instantiate, :clti_support
    end
  end
end
