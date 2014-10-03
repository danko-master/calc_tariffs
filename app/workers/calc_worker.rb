class CalcWorker
  include Sidekiq::Worker

  # перед стартом запускаем sidekiq
  # export BACKGROUNDJOBS_ENV=development && bundle exec sidekiq
  # export BACKGROUNDJOBS_ENV=test && bundle exec sidekiq
  # export BACKGROUNDJOBS_ENV=production && bundle exec sidekiq

  def perform
    tm = TariffMachine::Calculation.new
    tm.run
  end
end