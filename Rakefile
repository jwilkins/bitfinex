namespace "test" do
  desc "Unauthenticated API tests"
  task :unauthenticated do
    puts "running unauthenticated tests"
    res = `ruby test/test-unauth.rb`
    puts res
  end

  desc "Authenticated API tests"
  task :authenticated do
    puts "running authenticated tests"
    res = `ruby test/test-auth.rb`
    puts res
  end

  desc "All tests"
  task :all => [:authenticated, :unauthenticated] do
    puts "Finished running all tests"
  end
end

task :default => 'test:all'
