namespace :test do
  desc "Run all tests with documentation format"
  task :docs do
    sh "bundle exec rspec --format documentation"
  end

  desc "Run tests with coverage (requires simplecov)"
  task :coverage do
    ENV['COVERAGE'] = 'true'
    sh "bundle exec rspec"
  end

  desc "Run only model tests"
  task :models do
    sh "bundle exec rspec spec/models"
  end

  desc "Run only controller tests"
  task :controllers do
    sh "bundle exec rspec spec/controllers"
  end

  desc "Run only job tests"
  task :jobs do
    sh "bundle exec rspec spec/jobs"
  end

  desc "Run only service tests"
  task :services do
    sh "bundle exec rspec spec/services"
  end

  desc "Setup test database and run tests"
  task :setup do
    puts "Setting up test database..."
    sh "RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load"
    puts "\nRunning tests..."
    sh "bundle exec rspec"
  end
end
