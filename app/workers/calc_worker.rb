class CalcWorker
  include Sidekiq::Worker

  # перед стартом запускаем sidekiq
  # export RAILS_ENV=development && bundle exec sidekiq
  # export RAILS_ENV=test && bundle exec sidekiq
  # export RAILS_ENV=production && bundle exec sidekiq

  def perform
    tm = TariffMachine::Calculation.new
    tm.run
  end
end