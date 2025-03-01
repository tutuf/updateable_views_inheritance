# Class Table Inheritance

[![Build](https://github.com/tutuf/updateable_views_inheritance/actions/workflows/build.yml/badge.svg)](https://github.com/tutuf/updateable_views_inheritance/actions?query=workflow:build)
[![Codecov](https://codecov.io/gh/tutuf/updateable_views_inheritance/graph/badge.svg?token=L8P5LYNNU4)](https://codecov.io/gh/tutuf/updateable_views_inheritance)
[![DeepSource](https://app.deepsource.com/gh/tutuf/updateable_views_inheritance.svg/?label=active+issues&show_trend=true&token=AMfm8-_-qDZoknMh9-8IYp3R)](https://app.deepsource.com/gh/tutuf/updateable_views_inheritance/)

Class Table Inheritance for ActiveRecord using updateable views

More about the pattern on
http://www.martinfowler.com/eaaCatalog/classTableInheritance.html. This gem
messes very little with Rails inheritance mechanism. Instead it relies on
updatable views in the database to represent classes in the inheritance chain.
The approach was [first suggested by John
Wilger](http://web.archive.org/web/20060408145717/johnwilger.com/articles/2005/09/29/class-table-inheritance-in-rails-with-postgresql).


# Requirements

Rails: 4.x

Ruby: 1.9.3+

Database: PostgreSQL only. Patches for other DBMS are welcome. Note that you are
not required to use updateable views, children relations can be tables with
some triggers involved.

# Usage

## Setup

* Add `gem 'updateable_views_inheritance'` to your `Gemfile`
* Run `rails generate updateable_views_inheritance:install && rake db:migrate`
* In `config/environment.rb` set `config.active_record.schema_format = :sql`

## Example

The database migration:

```ruby
class CtiExample < ActiveRecord::Migration
  def self.up
    create_table :locomotives do |t|
      t.column :name, :string
      t.column :max_speed, :integer
      t.column :type, :string
    end

    create_child(:steam_locomotives, parent: :locomotives) do |t|
      t.decimal :water_consumption, precision: 6, scale: 2
      t.decimal :coal_consumption,  precision: 6, scale: 2
    end

    create_child(:electric_locomotives,
                 table: :raw_electric_locomotives,
                 parent: :locomotives)  do |t|
      t.decimal :electricity_consumption, precision: 6, scale: 2
    end
  end

  def self.down
    drop_child  :steam_locomotives
    drop_child  :electric_locomotives
    drop_table  :locomotives
  end
end
```

And the models:

```ruby
class Locomotive
end

class SteamLocomotive < Locomotive
  self.table_name =  :steam_locomotives
end

class ElectricLocomotive < Locomotive
  self.table_name =  :electric_locomotives
end
```

Note that models of children classes must specify table name explicitly.

### Changing Columns in Underlying Tables

#### In the parent

```ruby
class ChangeColumnsInParentTable < ActiveRecord::Migration
  def self.up
    remove_parent_and_children_views(:locomotives)
    remove_column(:locomotives, :max_speed)
    rename_column(:name, :title)
    rebuild_parent_and_children_views(:locomotives)
  end
end
```

#### In a child

```ruby
class ChangeColumnInChildTable < ActiveRecord::Migration
  def self.up
    drop_view(:steam_locomotives)
    rename_column(:steam_locomotives_data, :coal_consumption, :fuel_consumption)
    create_child_view(:locomotives, :steam_locomotives)
  end
end
```

### Renaming Underlying Tables

```ruby
remove_parent_and_children_views(:old_name)
rename_table(:old_name,:new_name)
execute "UPDATE updateable_views_inheritance SET child_aggregate_view = 'new_name' WHERE child_aggregate_view = 'old_name'"
execute "UPDATE updateable_views_inheritance SET parent_relation = 'new_name' WHERE parent_relation = 'old_name'"
rebuild_parent_and_children_views(:new_name)
```

### Removing Classes

Note that you should remove only leaf classes (i.e. those that do not have
descendants). If you want to erase a whole chain or part of chain you have to
remove first the leaves and then their ancestors. Use `drop_child(child_view)`
in migrations.

### Using parent class without instantiating subclass

If you don't want to make a second SQL query to the subclass table when you instantiate
parent class with `Locomotive.find(1)` use
```ruby
class Locomotive
  self.disable_inheritance_instantiation = true
end
```
Quite handy for flat and wide class hierarchies (one parent class, many subclasses).

### Using existing table for inherited class

```ruby
class CreateIkarusBus < ActiveRecord::Migration
  def self.up
    # table `tbl_ikarus_buses` exists in the database
    end
    create_child(:ikarus_buses,
                 table: :tbl_ikarus_buses,
                 parent: :buses,
                 skip_creating_child_table: true)
  end
end
```
Useful when converting legacy DB schema to use inheritance.

### Using view as a child table

```ruby
      execute <<-SQL.squish
        CREATE VIEW punk_locomotives_data AS (
          SELECT steam_locomotives.id,
                 steam_locomotives.coal_consumption AS coal,
                 NULL AS electro
          FROM steam_locomotives
          UNION ALL
          SELECT electric_locomotives.id,
                 NULL AS coal,
                 electric_locomotives.electricity_consumption AS electro
          FROM electric_locomotives)
      SQL
      create_child(:punk_locomotives,
                   { parent: :locomotives,
                     child_table: :punk_locomotives_data,
                     child_table_pk: :id,
                     skip_creating_child_table: true })
```
Views in PostgreSQL cannot have primary keys, so you have to manually specify it
when you use. Note that views also cannot have `NOT NULL` constraints, although
the `NOT NULL` constraint of the underlying table will still be enforced.

## Compatibility with Single Table Inheritance

The approach of this gem is completely independent from Rails built-in Single
Table Inheritance. STI and CLTI can safely be mixed in one inheritance chain.

## Testing Your App

If you use fixtures, you must run `rake updateable_views_inheritance:fixture` to
generate fixture for the updateable_views_inheritance table after you
add/remove classes from the hierarchy or change underlying table or view names.
**Without it primary key sequence for inheritors' tables won't be bumped to the
max and it might not be possible to save objects!** If you don't use fixtures
for the classes in the hierarchy you don't need to do that.

This gem re-enables referential integrity on fixture loading. This means that
`fixtures :all` may fail when there are foreign key constraints on tables. To
fix this, explicitly declare fixture load order in `test_helper.rb`:

```
fixtures :roots, :trunks, :leafs, ...
```
for all fixtures you want to load.

## Gem Development & Testing

In order to run gem tests, you have to be a superuser in PostgreSQL.
