## 1.5.1 (27 February 2025)

Upgrade to Rails 5.1

## 1.5.0 (31 January 2025)

Upgrade to Rails 5

## 1.4.8 (17 December 2024)
Bugfixes:
  - Fix pk_and_sequence_for to be interoperable with other AR methods

## 1.4.7 (06 November 2024)

Bugfixes:
  - Fix create_child so that it can be used idempotently
    with :skip_creating_child_table.

## 1.4.6 (22 October 2024)

Features:

  - Add option for child primary key.

## 1.4.5 (09 October 2024)

Bugfixes:
## 1.4.5 (09 October 2024)

Bugfixes:

  - Quote table and column names.

## 1.4.3 (01 October 2024)

Features:

  - Add option to disable inheritance instantiation for less
  database hits when loading large object collections from a
  parent class.

  - Add option to skip creating child table in migrations.

## 1.4.2 (28 March 2017)

Upgrade to Rails 4.2


## 1.4.1 (20 March 2017)

Upgrade to Rails 4.1

## 1.4.0 (2 Feburary 2017)

Upgrade to Rails 4

## 1.3.0 (20 August 2015)

Features:

  - Rebuild views in all inheritance chains (must be run when upgrading from <= 1.2.1)

## 1.2.2 (18 August 2015)

Bugfixes:

  - Fixed compatibility with Rails 3.2.19+ and ActiveRecord's prepared statements

## 1.2.1 (27 August 2014)

Bugfixes:

  - Parent relations can be in a schema

## 1.2.0 (27 August 2014)

Features:

  - Support for PostgreSQL schemas

## 1.1.2 (14 June 2013)

Bugfixes:

  - Fixed generating migration on installation

Documentation:

  - README brought up to date

## 1.1.1 (14 June 2013)

Features:

  - Gemified and released on rubygems.org

## 1.1.0 (13 June 2013)

Features:

  - Updated for Rails 3.2.x

## 1.0.0 (14 September 2009)

Features:

  - class_table_inheritance plugin has behaved stably in production for a year
  - Supports Rails 2.1, 2.2 and 2.3
