class CalcWorker
  include Sidekiq::Worker
  # sidekiq_options queue: :tariff

  def perform
    puts 'Doing hard work'
    tm = TariffMachine::Calculation.new
    puts tm
    tm.run
  end
end