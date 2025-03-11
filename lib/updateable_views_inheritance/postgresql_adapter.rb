require 'active_record/connection_adapters/postgresql/utils'

module ActiveRecord #:nodoc:
  module ConnectionAdapters #:nodoc:
    module PostgreSQL
      module SchemaStatements
        # Use this in migration to create child table and view.
        # Options:
        # [:parent]
        #   Parent relation
        # [:table]
        #   Deprecated. Use :child_table instead
        # [:child_table]
        #   Default is <tt>"#{child_view}_data"</tt>
        # [:child_table_pk]
        #   Handy when :child_table is a view and PK cannot be inferred
        #   from the database.
        # [:skip_creating_child_table]
        #   When given, :child_table option also must be specified
        def create_child(child_view, options)
          raise 'Please call me with a parent, for example: create_child(:steam_locomotives, :parent => :locomotives)' unless options[:parent]

          parent_relation = options[:parent].to_s
          parent_table =  if is_view?(parent_relation) # interpreted as inheritance chain deeper than two levels
                            query(<<~SQL)[0][0]
                              SELECT child_relation
                              FROM updateable_views_inheritance
                              WHERE child_aggregate_view = #{quote(parent_relation)}
                            SQL
                          else
                            parent_relation
                          end

          child_table = options[:child_table] || options[:table] || "#{child_view}_data"
          child_table_pk = options[:child_table_pk].to_s if options[:child_table_pk]

          unless options.key?(:skip_creating_child_table)
          unqualified_child_view_name = Utils.extract_schema_qualified_name(child_view).identifier
          child_table_pk ||= "#{unqualified_child_view_name.singularize}_id"

          create_table(child_table, id: false) do |t|
            t.integer child_table_pk, null: false
            yield t
          end
          execute "ALTER TABLE #{child_table} ADD PRIMARY KEY (#{child_table_pk})"
          execute "ALTER TABLE #{child_table} ADD FOREIGN KEY (#{child_table_pk})
                  REFERENCES #{parent_table} ON DELETE CASCADE ON UPDATE CASCADE"
          end

          create_child_view(parent_relation, child_view, child_table, child_table_pk)
        end

        # Drop child view and table
        def drop_child(child_view)
          drop_view(child_view)
          child_table = query("SELECT child_relation FROM updateable_views_inheritance WHERE child_aggregate_view = #{quote(child_view)}")[0][0]
          drop_table(child_table)
          execute "DELETE FROM updateable_views_inheritance WHERE child_aggregate_view = #{quote(child_view)}"
        end

        # Creates aggregate updateable view of parent and child relations. The convention for naming child tables is
        # <tt>"#{child_view}_data"</tt>. If you don't follow it, supply +child_table_name+ as third argument.
        def create_child_view(parent_table, child_view, child_table = nil, child_table_pk = nil)
          child_table ||= "#{child_view}_data"

          parent_columns = columns(parent_table)
          child_columns  = columns(child_table)

          child_column_names = child_columns.map(&:name)
          parent_column_names = parent_columns.map(&:name)

          child_pk = child_table_pk || pk_and_sequence_for(child_table)[0]
          child_column_names.delete(child_pk)

          parent_pk, parent_pk_seq = pk_and_sequence_for(parent_table)
          parent_column_names.delete(parent_pk)

          do_create_child_view(parent_table, parent_column_names, parent_pk, child_view, child_column_names, child_pk, child_table)
          make_child_view_updateable(parent_table, parent_column_names, parent_pk, parent_pk_seq, child_view, child_column_names, child_pk, child_table)

          # assign default values for table columns on the view - it is not automatic in Postgresql 8.1
          set_defaults(child_view, parent_table)
          set_defaults(child_view, child_table)
          create_system_table_records(parent_table, child_view, child_table)
        end

        # Resets sequence to the max value of the table's pk if present respecting inheritance (i.e. one sequence can be shared by many tables).
        def reset_pk_sequence!(table, pk = nil, sequence = nil)
          parent = parent_table(table)
          if parent
            reset_pk_sequence!(parent, pk, sequence)
          else
            unless pk && sequence
              default_pk, default_sequence = pk_and_sequence_for(table)

              pk ||= default_pk
              sequence ||= default_sequence
            end

            if @logger && pk && !sequence
              @logger.warn "#{table} has primary key #{pk} with no default sequence."
            end

            if pk && sequence
              quoted_sequence = quote_table_name(sequence)
              max_pk = query_value("SELECT MAX(#{quote_column_name pk}) FROM #{quote_table_name(table)}", "SCHEMA")
              if max_pk.nil?
                if postgresql_version >= 100000
                  minvalue = query_value("SELECT seqmin FROM pg_sequence WHERE seqrelid = #{quote(quoted_sequence)}::regclass", "SCHEMA")
                else
                  minvalue = query_value("SELECT min_value FROM #{quoted_sequence}", "SCHEMA")
                end
              end

              query_value("SELECT setval(#{quote(quoted_sequence)}, #{max_pk ? max_pk : minvalue}, #{max_pk ? true : false})", "SCHEMA")
            end
          end
        end

        def primary_key(relation)
          res = pk_and_sequence_for(relation)
          res && res.first
        end

        # Returns a relation's primary key and belonging sequence.
        # If +relation+ is a table the result is its PK and sequence.
        # When it is a view, PK and sequence of the table at the root
        # of the inheritance chain are returned.
        def pk_and_sequence_for(relation)
          result = query(<<-SQL.squish, 'PK')[0]
            SELECT attr.attname
              FROM pg_attribute attr,
                   pg_constraint cons
             WHERE cons.conrelid = attr.attrelid
               AND cons.conrelid = '#{relation}'::regclass
               AND cons.contype  = 'p'
               AND attr.attnum   = ANY(cons.conkey)
          SQL

          if result.nil? or result.empty?
            parent = parent_table(relation)
            pk_and_sequence_for(parent) if parent
          else
            pk = result[0]
            sequence = query("SELECT pg_get_serial_sequence('#{relation}', '#{result[0]}') ")[0][0]
            if sequence
              # ActiveRecord expects PostgreSQL::Name object as sequence, not a string
              sequence_with_schema = Utils.extract_schema_qualified_name(sequence)
              [pk, sequence_with_schema]
            else
              [pk, nil]
            end
          end
        rescue
          nil
        end

        # Drops a view from the database.
        def drop_view(name)
          execute "DROP VIEW #{quote_table_name(name)}"
        end

        # Checks whether relation +name+ is a view.
        def is_view?(name)
          result = query(<<~SQL, name).map { |row| row[0] }
            SELECT viewname
              FROM pg_views
             WHERE viewname = '#{name}'
          SQL
          !result.empty?
        end

        # Recursively delete +parent_relation+ (if it is a view) and the children views the depend on it.
        def remove_parent_and_children_views(parent_relation)
          children_views = query(<<-SQL).map{|row| row[0]}
            SELECT child_aggregate_view
              FROM updateable_views_inheritance
             WHERE parent_relation = '#{parent_relation}'
          SQL
          children_views.each do |cv|
            remove_parent_and_children_views(cv)
            # drop the view only if it wasn't dropped beforehand in recursive call from other method.
            drop_view(cv) if is_view?(cv)
          end
          drop_view(parent_relation) if is_view?(parent_relation)
        end

        # Recreates all views in all hierarchy chains
        def rebuild_all_parent_and_children_views
          parent_relations = select_values('SELECT DISTINCT parent_relation FROM updateable_views_inheritance')
          parent_relations.each { |parent_relation| rebuild_parent_and_children_views(parent_relation) }
        end

        # Recreates views in the part of the hierarchy chain starting from the +parent_relation+.
        def rebuild_parent_and_children_views(parent_relation)
          # Current implementation is not very efficient - it can drop and recreate one and the same view in the bottom of the hierarchy many times.
          remove_parent_and_children_views(parent_relation)
          children = query(<<-SQL)
            SELECT parent_relation, child_aggregate_view, child_relation
              FROM updateable_views_inheritance
             WHERE parent_relation = '#{parent_relation}'
          SQL

          #if the parent is in the middle of the inheritance chain, it's a view that should be rebuilt as well
          parent = query(<<-SQL)[0]
            SELECT parent_relation, child_aggregate_view, child_relation
              FROM updateable_views_inheritance
             WHERE child_aggregate_view = '#{parent_relation}'
          SQL
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
          execute <<-SQL
            CREATE VIEW #{sti_aggregate_view} AS (
              #{unioin_clauses}
            )
          SQL
        end

        # Recreates the Single_Table_Inheritanche-like aggregate view +sti_aggregate_view+
        # for +parent_relation+ and all its descendants.
        def rebuild_single_table_inheritance_view(sti_aggregate_view, parent_relation, columns_for_view = nil)
          drop_view(sti_aggregate_view)
          create_single_table_inheritance_view(sti_aggregate_view, parent_relation, columns_for_view)
        end

        # Overriden - it solargraph-must return false, otherwise deleting fixtures won't work
        def supports_disable_referential_integrity?
          false
        end

        module Tutuf #:nodoc:
          class ClassTableReflection
            class << self
              # Returns all models' class objects that are ActiveRecord::Base descendants
              def all_db_klasses
                return @@klasses if defined?(@@klasses)

                @@klasses = []
                # load model classes so that inheritance_column is set correctly where defined
                model_filenames.collect{|m| load "#{Rails.root}/app/models/#{m}";m.match(%r{([^/]+?)\.rb$})[1].camelize.constantize }.each do |klass|
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
                Dir.chdir("#{Rails.root}/app/models"){ Dir["**/*.rb"] }
              end
            end
          end
        end

        # Set default values from the table columns for a view
        def set_defaults(view_name, table_name)
          column_definitions(table_name).each do |column_name, type, default, notnull|
            if !default.nil?
              execute("ALTER TABLE #{quote_table_name(view_name)} ALTER #{quote_column_name(column_name)} SET DEFAULT #{default}")
            end
          end
        end

        private

        def do_create_child_view(parent_table, parent_columns, parent_pk, child_view, child_columns, child_pk, child_table)
          view_columns = parent_columns + child_columns
          execute(<<~SQL)
            CREATE OR REPLACE VIEW #{quote_table_name(child_view)} AS (
              SELECT parent.#{parent_pk},
                     #{ view_columns.map { |col| quote_column_name(col) }.join(",") }
                FROM #{parent_table} parent
                     INNER JOIN #{child_table} child
                     ON ( parent.#{parent_pk}=child.#{child_pk} )
            )
          SQL
        end

        # Creates rules for +INSERT+, +UPDATE+ and +DELETE+ on the view
        def make_child_view_updateable(parent_table, parent_columns, parent_pk, parent_pk_seq, child_view, child_columns, child_pk, child_table)
          # insert
          # NEW.#{parent_pk} can be explicitly specified and when it is null every call to it increments the sequence.
          # Setting the sequence to its value (explicitly supplied or the default) covers both cases.
          execute(<<~SQL)
            CREATE OR REPLACE RULE #{quote_column_name("#{child_view}_insert")} AS
            ON INSERT TO #{quote_table_name(child_view)} DO INSTEAD (
              INSERT INTO #{parent_table}
                     ( #{ [parent_pk, parent_columns].flatten.map { |col| quote_column_name(col) }.join(", ") } )
                     VALUES( DEFAULT #{ parent_columns.empty? ? '' : ' ,' + parent_columns.collect{ |col| "NEW.#{quote_column_name(col)}" }.join(", ") } ) ;
              INSERT INTO #{child_table}
                     ( #{ [child_pk, child_columns].flatten.map { |col| quote_column_name(col) }.join(",")} )
                     VALUES( currval('#{parent_pk_seq}') #{ child_columns.empty? ? '' : ' ,' + child_columns.collect{ |col| "NEW.#{quote_column_name(col)}" }.join(", ") }  )
                     #{insert_returning_clause(parent_pk, child_pk, child_view)}
            )
          SQL

          # delete
          execute(<<~SQL)
            CREATE OR REPLACE RULE #{quote_column_name("#{child_view}_delete")} AS
            ON DELETE TO #{quote_table_name(child_view)} DO INSTEAD
            DELETE FROM #{parent_table} WHERE #{parent_pk} = OLD.#{parent_pk}
          SQL

          # update
          update_rule = <<~SQL
            CREATE OR REPLACE RULE #{quote_column_name("#{child_view}_update")} AS
            ON UPDATE TO #{quote_table_name(child_view)} DO INSTEAD (
          SQL
          unless parent_columns.empty?
            update_rule += <<~SQL
              UPDATE #{parent_table}
              SET #{parent_columns.map { |col| "#{quote_column_name(col)} = NEW.#{quote_column_name(col)}" }.join(', ')}
              WHERE #{parent_pk} = OLD.#{parent_pk};
            SQL
          end
          unless child_columns.empty?
            update_rule += <<~SQL
              UPDATE #{child_table}
              SET #{ child_columns.map { |col| "#{quote_column_name(col)} = NEW.#{quote_column_name(col)}" }.join(', ')}
              WHERE #{child_pk} = OLD.#{parent_pk}
            SQL
          end
          update_rule += ")"
          execute(update_rule)
        end

        def insert_returning_clause(parent_pk, child_pk, child_view)
          columns_cast = columns(child_view).map do |c|
            if c.name == parent_pk
              "#{child_pk}::#{c.sql_type}"
            else
              "NULL::#{c.sql_type}"
            end
          end.join(", ")
          "RETURNING #{columns_cast}"
        end

        def create_system_table_records(parent_relation, child_aggregate_view, child_relation)
          parent_relation, child_aggregate_view, child_relation = [parent_relation, child_aggregate_view, child_relation].collect{|rel| quote(rel.to_s)}
          exists = query <<~SQL
            SELECT parent_relation, child_aggregate_view, child_relation
              FROM updateable_views_inheritance
             WHERE parent_relation      = #{parent_relation}
               AND child_aggregate_view = #{child_aggregate_view}
               AND child_relation       = #{child_relation}
          SQL
          # log "res: #{exists}"
          if exists.nil? or exists.empty?
            execute "INSERT INTO updateable_views_inheritance (parent_relation, child_aggregate_view, child_relation)" +
                    "VALUES( #{parent_relation}, #{child_aggregate_view}, #{child_relation} )"
          end
        end

        def parent_table(relation)
          if data_source_exists?('updateable_views_inheritance')
           res = query(<<-SQL, 'Parent relation')[0]
              SELECT parent_relation
                FROM updateable_views_inheritance
               WHERE child_aggregate_view = '#{relation}'
            SQL
            res[0] if res
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
          children = query(<<-SQL)
            SELECT parent_relation, child_aggregate_view, child_relation
              FROM updateable_views_inheritance
            WHERE parent_relation = '#{parent_relation}'
          SQL
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
end
