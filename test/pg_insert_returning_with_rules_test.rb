require_relative 'test_helper'

class InsertReturningOnViewWithRulesAndDefaultValue < ActiveSupport::TestCase
  def setup
    @conn = ActiveRecord::Base.connection.raw_connection
    @conn.exec("SET client_min_messages TO 'ERROR'")

    @conn.exec(<<-SQL.squish)
      CREATE TABLE parent (
        id SERIAL PRIMARY KEY,
        name TEXT
      )
    SQL

    @conn.exec(<<-SQL.squish)
      CREATE TABLE child (
        parent_id INTEGER PRIMARY KEY REFERENCES parent(id),
        surname TEXT
      )
    SQL

    @conn.exec(<<-SQL.squish)
      CREATE VIEW v AS (
        SELECT id, name, surname
        FROM parent JOIN child ON parent.id=child.parent_id
      )
    SQL

    @conn.exec(<<-SQL.squish)
     ALTER VIEW v ALTER id SET DEFAULT nextval('parent_id_seq'::regclass)
    SQL

    @conn.exec(<<-SQL.squish)
      CREATE RULE v_on_insert AS ON INSERT TO v DO INSTEAD (
        INSERT INTO parent (id, name)
          VALUES( DEFAULT, NEW.name );
        INSERT INTO child  (parent_id, surname)
          VALUES( currval('parent_id_seq'), NEW.surname ) RETURNING parent_id, NULL::text, NULL::text;
      )
    SQL

    @sql = "INSERT INTO v (name, surname) VALUES ('parent', 'child') RETURNING id"
  end

  def teardown
    @conn.exec("DROP VIEW IF EXISTS v")
    @conn.exec("DROP TABLE IF EXISTS parent CASCADE")
    @conn.exec("DROP TABLE IF EXISTS child CASCADE")
  end

  def test_async_exec_with_empty_binds
    res = @conn.async_exec(@sql, [])
    assert_equal [[1]], res.values
  end

  def test_async_exec_with_no_binds
    res = @conn.async_exec(@sql)
    assert_equal [[1]], res.values
  end
end
