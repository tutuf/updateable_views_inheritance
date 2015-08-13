gem "pg", "0.18.2"

require "pg"
require "rspec"

describe "Insert returning on view with rules and default value" do
  before(:each) do
    @conn = PG.connect(dbname: 'updateable_views_inheritance_test')
    @conn.exec(%q{ SET client_min_messages TO 'ERROR' })

    @conn.exec(%q{ CREATE TABLE parent ( id SERIAL PRIMARY KEY,
                                         name TEXT) })
    @conn.exec(%q{ CREATE TABLE child ( parent_id INTEGER PRIMARY KEY REFERENCES parent(id),
                                        surname TEXT) })

    @conn.exec(%q{ CREATE VIEW v AS (SELECT id, name, surname FROM parent JOIN child ON parent.id=child.parent_id) })
    @conn.exec(%q{ ALTER VIEW v ALTER id SET DEFAULT nextval('parent_id_seq'::regclass) })
    #
    # The old way that didn't return anything when binds are empty
    #
    # @conn.exec(%q{ CREATE RULE v_on_insert AS ON INSERT TO v DO INSTEAD
    #               (
    #                 SELECT setval('parent_id_seq', NEW.id);
    #                 INSERT INTO parent (id, name)
    #                   VALUES( currval('parent_id_seq'), NEW.name ) RETURNING id, name, NULL::text;
    #                 INSERT INTO child  (parent_id, surname)
    #                   VALUES( currval('parent_id_seq'), NEW.surname );
    #
    #               )
    #             })
    @conn.exec(%q{ CREATE RULE v_on_insert AS ON INSERT TO v DO INSTEAD
                  (
                    INSERT INTO parent (id, name)
                      VALUES( DEFAULT, NEW.name );
                    INSERT INTO child  (parent_id, surname)
                      VALUES( currval('parent_id_seq'), NEW.surname ) RETURNING parent_id, NULL::text, NULL::te;
                  )
                })

    @sql = %q{ INSERT INTO v (name, surname) VALUES ('parent', 'child') RETURNING id}
  end

  after(:each) do
    @conn.exec(%q{ DROP VIEW IF EXISTS v })
    @conn.exec(%q{ DROP TABLE IF EXISTS parent CASCADE})
    @conn.exec(%q{ DROP TABLE IF EXISTS child CASCADE})
  end

  it 'async exec with empty binds' do
    res = @conn.async_exec(@sql, [])
    expect(res.values).to eq([["1"]])
  end

  it 'async exec with no binds' do
    res = @conn.async_exec(@sql)
    expect(res.values).to eq([["1"]])
  end
end