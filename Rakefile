begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "class_table_inheritance"
    s.summary = "Class table inheritance for ActiveRecord"
    s.email = "sava@tutuf.com"
    s.homepage = "http://clti.rubyforge.org"
    s.description = "Class table inheritance (http://www.martinfowler.com/eaaCatalog/classTableInheritance.html) allows every ActiveRecord class in an inheritance chain to store its data in a separate database relation."
    s.authors = ["Sava Chankov", "Denitsa Belogusheva"]
    s.files.exclude 'test/debug.log'
    s.add_dependency 'activerecord', '>=2.3.2'
  end
rescue LoadError
  abort  "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

load 'tasks/class_table_inheritance_tasks.rake'

desc 'Run unit tests'
task :test => 'class_table_inheritance:test'
