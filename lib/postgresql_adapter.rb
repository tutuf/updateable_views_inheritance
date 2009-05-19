module ActiveRecord #:nodoc:
  module ConnectionAdapters #:nodoc:
    class PostgreSQLAdapter
      # Use this in migration to create child table and view.
      # Options: 
      # [:parent]
      #   parent relation
      # [:child_table_name]
      #   default is <tt>"#{child_view}_data"</tt>
      def create_child(child_view, options)
        raise 'Please call me with a parent, for example: create_child(:steam_locomotives, :parent => :locomotives)' unless options[:parent]
        parent_relation = options[:parent].to_s
        if tables.include?(parent_relation)
          parent_table = parent_relation
        else # view, interpreted as inheritance chain deeper than two levels
          parent_table = query("SELECT child_relation FROM class_table_inheritance WHERE child_aggregate_view = #{quote(parent_relation)}")[0][0]
        end
        child_table = options[:table] || "#{child_view}_data"
        child_table_pk = "#{child_view.singularize}_id"
        
        create_table(child_table, :id => false) do |t|
          t.integer child_table_pk, :null => false
          yield t
        end
        execute "ALTER TABLE #{child_table} ADD PRIMARY KEY (#{child_table_pk})"
        execute "ALTER TABLE #{child_table} ADD FOREIGN KEY (#{child_table_pk})
                 REFERENCES #{parent_table} ON DELETE CASCADE ON UPDATE CASCADE"
        
        create_child_view(parent_relation, child_view, child_table)
      end
      
      # Drop child view and table
      def drop_child(child_view)
        drop_view(child_view)
        child_table = query("SELECT child_relation FROM class_table_inheritance WHERE child_aggregate_view = #{quote(child_view)}")[0][0]
        drop_table(child_table)
        execute "DELETE FROM class_table_inheritance WHERE child_aggregate_view = #{quote(child_view)}"
      end
      
      # Creates aggregate updateable view of parent and child relations. The convention for naming child tables is
      # <tt>"#{child_view}_data"</tt>. If you don't follow it, supply +child_table_name+ as third argument.
      def create_child_view(parent_table, child_view, child_table=nil)
        child_table ||= child_view.to_s + "_data"

        parent_columns = columns(parent_table)
        child_columns  = columns(child_table)

        child_column_names = child_columns.collect{|c| c.name}
        parent_column_names = parent_columns.collect{|c| c.name}

        child_pk = pk_and_sequence_for(child_table)[0]
        child_column_names.delete(child_pk)

        parent_pk, parent_pk_seq = pk_and_sequence_for(parent_table)
        parent_column_names.delete(parent_pk)

        do_create_child_view(parent_table, parent_column_names, parent_pk, child_view, child_column_names, child_pk, child_table)
        make_child_view_updateable(parent_table, parent_column_names, parent_pk, parent_pk_seq, child_view, child_column_names, child_pk, child_table)

        # assign default values for table columns on the view - it is not automatic in Postgresql 8.1
        set_defaults(child_view, parent_table, parent_columns)
        set_defaults(child_view, child_table, child_columns)
        create_system_table_records(parent_table, child_view, child_table)
      end

      # Resets sequence to the max value of the table's pk if present respecting inheritance (i.e. one sequence can be shared by many tables).
      def reset_pk_sequence!(table, pk = nil, sequence = nil)
        parent = parent_table(table)
        if parent
          reset_pk_sequence!(parent, pk, sequence)
        else
          unless pk and sequence
            default_pk, default_sequence = pk_and_sequence_for(table)
            pk ||= default_pk
            sequence ||= default_sequence
          end
          if pk
            if sequence
              select_value <<-end_sql, 'Reset sequence'
                SELECT setval('#{sequence}', (SELECT COALESCE(MAX(#{pk})+(SELECT increment_by FROM #{sequence}), (SELECT min_value FROM #{sequence})) FROM #{table}), false)
              end_sql
            else
              @logger.warn "#{table} has primary key #{pk} with no default sequence" if @logger
            end
          end
        end
      end

      # Returns a relation's primary key and belonging sequence. If +relation+ is a table the result is its PK and sequence.
      # When it is a view, PK and sequence of the table at the root of the inheritance chain are returned.
      def pk_and_sequence_for(relation)
        result = query(<<-end_sql, 'PK')[0]
          SELECT attr.attname
            FROM pg_attribute attr,
                 pg_constraint cons
           WHERE cons.conrelid = attr.attrelid
             AND cons.conrelid = '#{relation}'::regclass
             AND cons.contype  = 'p'
             AND attr.attnum   = ANY(cons.conkey)
        end_sql
        if result.nil? or result.empty?
          parent = parent_table(relation)
          pk_and_sequence_for(parent) if parent
        else
          # log(result[0], "PK for #{relation}")
          [result[0], query("SELECT pg_get_serial_sequence('#{relation}', '#{result[0]}') ")[0][0]]
        end
      rescue
        nil
      end

      # Drops a view from the database.
      def drop_view(name)
        execute "DROP VIEW #{name}"
      end

      # Return the list of all views in the schema search path.
      def views(name=nil)
        schemas = schema_search_path.split(/,/).map { |p| quote(p) }.join(',')
        query(<<-SQL, name).map { |row| row[0] }
          SELECT viewname
            FROM pg_views
           WHERE schemaname IN (#{schemas})
        SQL
      end

      # Checks whether relation +name+ is a view.
      def is_view?(name)
        result = query(<<-SQL, name).map { |row| row[0] }
          SELECT viewname
            FROM pg_views
           WHERE viewname = '#{name}'
        SQL
        !result.empty?
      end

      # Recursively delete +parent_relation+ (if it is a view) and the children views the depend on it.
      def remove_parent_and_children_views(parent_relation)
        children_views = query(<<-end_sql)
          SELECT child_aggregate_view
            FROM class_table_inheritance
           WHERE parent_relation = '#{parent_relation}'
        end_sql
        children_views.each do |cv|
          remove_parent_and_children_views(cv)
          # drop the view only if it wasn't dropped beforehand in recursive call from other method.
          drop_view(cv) if is_view?(cv)
        end
        drop_view(parent_relation) if is_view?(parent_relation)
      end

      # Recreates views in the part of the hierarchy chain starting from the +parent_relation+.
      def rebuild_parent_and_children_views(parent_relation)
        # Current implementation is not very efficient - it can drop and recreate one and the same view in the bottom of the hierarchy many times.
        remove_parent_and_children_views(parent_relation)
        children = query(<<-end_sql)
          SELECT parent_relation, child_aggregate_view, child_relation
            FROM class_table_inheritance
           WHERE parent_relation = '#{parent_relation}'
        end_sql

        #if the parent is in the middle of the inheritance chain, it's a view that should be rebuilt as well
        parent = query(<<-end_sql)[0]
          SELECT parent_relation, child_aggregate_view, child_relation
            FROM class_table_inheritance
           WHERE child_aggregate_view = '#{parent_relation}'
        end_sql
        create_child_view(parent[0], parent[1], parent[2]) if (parent && !parent.empty?)

        children.each do |child|
          create_child_view(child[0], child[1], child[2])
          rebuild_parent_and_children_views(child[1])
        end
      end

      # Creates Single Table Inheritanche-like aggregate view called +sti_aggregate_view+
      # for +parent_relation+ and all its descendants. <i>The view isn't updateable.</i>
      # The order of all or just the first few columns in the aggregate view can be explicitly set
      # by passing array of column names as third argument.
      # If there are columns with the same name but different types in two or more relations
      # they will appear as a single column of type +text+ in the view.
      def create_single_table_inheritance_view(sti_aggregate_view, parent_relation, columns_for_view = nil)
        columns_for_view ||= []
        relations_heirarchy = get_view_hierarchy_for(parent_relation)
        relations = relations_heirarchy.flatten
        leaves_relations = get_leaves_relations(relations_heirarchy)
        all_columns = leaves_relations.map{|rel| columns(rel)}.flatten
        columns_hash = {}
        conflict_column_names = []
        all_columns.each do |col|
          c = columns_hash[col.name]
          if(c && col.sql_type != c.sql_type)
            conflict_column_names << col.name
          else 
            columns_hash[col.name] = col
          end
        end
        conflict_column_names = conflict_column_names.uniq.sort if !conflict_column_names.empty?
        sorted_column_names = (columns_for_view + columns_hash.keys.sort).uniq
        parent_klass_name = Tutuf::ClassTableReflection.get_klass_for_table(parent_relation)
        quoted_inheritance_column = quote_column_name(parent_klass_name.inheritance_column)
        queries = relations.map{|rel| generate_single_table_inheritanche_union_clause(rel, sorted_column_names, conflict_column_names, columns_hash, quoted_inheritance_column)}
        unioin_clauses = queries.join("\n UNION ")
        execute <<-end_sql
          CREATE VIEW #{sti_aggregate_view} AS (
            #{unioin_clauses}
          )
        end_sql
      end

      # Recreates the Single_Table_Inheritanche-like aggregate view +sti_aggregate_view+
      # for +parent_relation+ and all its descendants.
      def rebuild_single_table_inheritance_view(sti_aggregate_view, parent_relation, columns_for_view = nil)
        drop_view(sti_aggregate_view)
        create_single_table_inheritance_view(sti_aggregate_view, parent_relation, columns_for_view)
      end

      module Tutuf #:nodoc:
        class ClassTableReflection
          class << self
              # Returns all models' class objects that are ActiveRecord::Base descendants
              def all_db_klasses
                return @@klasses if defined?(@@klasses)
                @@klasses = []
                # load model classes so that inheritance_column is set correctly where defined
                model_filenames.collect{|m| load "#{RAILS_ROOT}/app/models/#{m}";m.match(%r{([^/]+?)\.rb$})[1].camelize.constantize }.each do |klass|
                  @@klasses << klass if  klass < ActiveRecord::Base
                end
                @@klasses.uniq
              end
        
              # Returns the class object for +table_name+
              def get_klass_for_table(table_name)
                klass_for_tables()[table_name.to_s]
              end
        
              # Returns hash with tables and thier corresponding class.
              # {table_name1 => ClassName1, ...}
              def klass_for_tables
                return @@tables_klasses if defined?(@@tables_klasses)
                @@tables_klasses = {}
                all_db_klasses.each do |klass|
                  @@tables_klasses[klass.table_name] = klass if klass.respond_to?(:table_name)
                end
                @@tables_klasses
              end
              
              # Returns filenames for models in the current Rails application
              def model_filenames
                Dir.chdir("#{RAILS_ROOT}/app/models"){ Dir["**/*.rb"] }
              end
          end
        end
      end

      private

        def do_create_child_view(parent_table, parent_columns, parent_pk, child_view, child_columns, child_pk, child_table)
          view_columns = parent_columns + child_columns
          execute <<-end_sql
            CREATE OR REPLACE VIEW #{child_view} AS (
              SELECT parent.#{parent_pk},
                     #{ view_columns.join(",") }
                FROM #{parent_table} parent
                     INNER JOIN #{child_table} child
                     ON ( parent.#{parent_pk}=child.#{child_pk} )
            )
          end_sql
        end

        # Creates rules for +INSERT+, +UPDATE+ and +DELETE+ on the view
        def make_child_view_updateable(parent_table, parent_columns, parent_pk, parent_pk_seq, child_view, child_columns, child_pk, child_table)
          # insert
          # NEW.#{parent_pk} can be explicitly specified and when it is null every call to it increments the sequence.
          # Setting the sequence to its value (explicitly supplied or the default) covers both cases.
          execute <<-end_sql  
            CREATE OR REPLACE RULE #{child_view}_insert AS
            ON INSERT TO #{child_view} DO INSTEAD (
              SELECT setval('#{parent_pk_seq}', NEW.#{parent_pk});
              INSERT INTO #{parent_table} 
                     ( #{ [parent_pk, parent_columns].flatten.join(", ") } )
                     VALUES( currval('#{parent_pk_seq}') #{ parent_columns.empty? ? '' : ',' + parent_columns.collect{ |col| "NEW." + col}.join(",") } );
              INSERT INTO #{child_table}
                     ( #{ [child_pk, child_columns].flatten.join(",")} )
                     VALUES( currval('#{parent_pk_seq}') #{ child_columns.empty? ? '' : ',' + child_columns.collect{ |col| "NEW." + col}.join(",") }  )
            )
          end_sql

          # delete
          execute <<-end_sql
           CREATE OR REPLACE RULE #{child_view}_delete AS
           ON DELETE TO #{child_view} DO INSTEAD
           DELETE FROM #{parent_table} WHERE #{parent_pk} = OLD.#{parent_pk}
          end_sql

          # update
          execute <<-end_sql
            CREATE OR REPLACE RULE #{child_view}_update AS
            ON UPDATE TO #{child_view} DO INSTEAD (
              #{ parent_columns.empty? ? '':
                 "UPDATE #{parent_table}
                     SET #{ parent_columns.collect{ |col| col + "= NEW." +col }.join(", ") }
                     WHERE #{parent_pk} = OLD.#{parent_pk};"} 
              #{ child_columns.empty? ? '':
                 "UPDATE #{child_table}
                     SET #{ child_columns.collect{ |col| col + " = NEW." +col }.join(", ") }
                     WHERE #{child_pk} = OLD.#{parent_pk}"
                }
            )
          end_sql
        end

        # Set default values from the table columns for a view
        def set_defaults(view_name, table_name, columns)
          columns.each do |column| 
            if !(default_value = get_default_value(table_name, column.name)).nil?
              execute("ALTER TABLE #{view_name} ALTER #{column.name} SET DEFAULT #{default_value}") 
            end
          end
        end

        # ActiveRecord::ConnectionAdapters::Column objects have nil default value for serial primary key
        def get_default_value(table_name, column_name)
          result = query(<<-end_sql, 'Column default value')[0]
            SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid) as constraint
              FROM pg_catalog.pg_attrdef d, pg_catalog.pg_attribute a, pg_catalog.pg_class c
             WHERE d.adrelid = a.attrelid 
               AND d.adnum = a.attnum 
               AND a.atthasdef 
               AND c.relname = '#{table_name}' 
               AND a.attrelid = c.oid
               AND a.attname = '#{column_name}'
               AND a.attnum > 0 AND NOT a.attisdropped
          end_sql
          if !result.nil? && !result.empty?
            result
          else
            nil
          end
        end

        def create_system_table_records(parent_relation, child_aggregate_view, child_relation)
          parent_relation, child_aggregate_view, child_relation = [parent_relation, child_aggregate_view, child_relation].collect{|rel| quote(rel.to_s)}
          exists = query <<-end_sql
            SELECT parent_relation, child_aggregate_view, child_relation
              FROM class_table_inheritance
             WHERE parent_relation      = #{parent_relation}
               AND child_aggregate_view = #{child_aggregate_view}
               AND child_relation       = #{child_relation}
          end_sql
          # log "res: #{exists}"
          if exists.nil? or exists.empty?
            execute "INSERT INTO class_table_inheritance (parent_relation, child_aggregate_view, child_relation)" +
                    "VALUES( #{parent_relation}, #{child_aggregate_view}, #{child_relation} )"
          end
        end

        def parent_table(relation)
          if table_exists?('class_table_inheritance')
            query(<<-end_sql, 'Parent relation')[0]
              SELECT parent_relation
                FROM class_table_inheritance
               WHERE child_aggregate_view = '#{relation}'
            end_sql
          end
        end
        
        # Single Table Inheritance Aggregate View
        
        # Nested list for the +parent_relation+ inheritance hierarchy
        # Every descendant relation is presented as an array with relation's name as first element
        # and the other elements are the relation's children presented in the same way as lists.
        # For example:
        # [[child_view1, [grandchild11,[...]], [grandchild12]],
        #  [child_view2, [...]
        # ]
        def get_view_hierarchy_for(parent_relation)
          hierarchy = []
          children = query(<<-end_sql)
            SELECT parent_relation, child_aggregate_view, child_relation
              FROM class_table_inheritance
            WHERE parent_relation = '#{parent_relation}'
          end_sql
          children.each do |child|
            hierarchy << [child[1], *get_view_hierarchy_for(child[1])]
          end
          hierarchy
        end
  
        def get_leaves_relations(hierarchy)
          return [] if hierarchy.nil? || hierarchy.empty?
          head, hierarchy = hierarchy.first, hierarchy[1..(hierarchy.size)]
          if(head.is_a? Array)
            return (get_leaves_relations(head) + get_leaves_relations(hierarchy)).compact
          elsif(hierarchy.nil? || hierarchy.empty?)
            return [head]
          else
            return get_leaves_relations(hierarchy).compact
          end
        end
  
        def generate_single_table_inheritanche_union_clause(rel, column_names, conflict_column_names, columns_hash, quoted_inheritance_column)
          relation_columns = columns(rel).collect{|c| c.name}
          columns_select = column_names.inject([]) do |arr, col_name| 
            sql_type = conflict_column_names.include?(col_name) ? 'text' : columns_hash[col_name].sql_type
            value = "NULL::#{sql_type}"
            if(relation_columns.include?(col_name))
              value = col_name
              value = "#{value}::text" if conflict_column_names.include?(col_name)
            end
            statement = " AS #{col_name}"
            statement = "#{value} #{statement}"
            arr << " #{statement}"
          end
          columns_select = columns_select.join(", ")
          rel_klass_name = Tutuf::ClassTableReflection.get_klass_for_table(rel)
          where_clause = " WHERE #{quoted_inheritance_column} = '#{rel_klass_name}'"
          ["SELECT", columns_select, "FROM #{rel} #{where_clause}"].join(" ")
        end
    end
  end
end
