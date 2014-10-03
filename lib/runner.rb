#!/usr/bin/env ruby
# encoding: utf-8

# Run: export RAILS_ENV=development && ruby ./runner.rb
# Run: export RAILS_ENV=test && ruby ./runner.rb
# Run: export RAILS_ENV=production && ruby ./runner.rb

require_relative "../config/environment"

p "runner"
# p ENV['HOME']
# p ENV['PATH']
# p ENV['LANG']
# p ENV['GEM_HOME']
# p ENV['GEM_PATH']

current_logger = Logger.new Rails.root.join("log", "tariff_machine_runner." + Rails.env + ".log")


if ENV['RAILS_ENV']
  p ENV['RAILS_ENV']
  p SETTINGS_CONFIG['runner']['instances']

  if SETTINGS_CONFIG['runner']['instances'].present?
    inst_num = SETTINGS_CONFIG['runner']['instances'].to_i
  else
    inst_num = 1
  end
  

  $redis = Redis.new  
  # ключи в запущенных instances
  $redis.set("keys_instances", Hash.new)
  
  current_logger.info p "Получение всех компаний"
  Company.all.each do |customer|
    if $redis.get("customers:#{customer.id}").blank?
      $redis.set("customers:#{customer.id}", customer.id)
      $redis.set("customers:#{customer.id}:discount", customer.discount)
    end
  end
  
  tmp = 100

  while inst_num > 0
    unless $redis.keys("tdr:*").size > 0
      current_logger.info p "Ждем информацию из кролика"
      # получаем инфу для обработки, это необходимо, если будет работать несколько экземпляров приложения
      TariffMachine::Calculation.set_tdr_data_to_redis(current_logger)
    end

    
    # проверять будем по кол-ву актуальных tdr
    while tmp > 0 && $redis.keys("tdr:*").size > 0 do 
      i = inst_num
      while i > 0 do 
        # передаем для асинхронного выполнения
        CalcWorker.perform_async
        # tm = TariffMachine::Calculation.new
        # tm.run
        
        current_logger.info p "keys #{$redis.keys("tdr:*")}"
        i += -1
      end

      tmp = tmp - 1
    end
  end


  ##########################################
  # добавить результат успешности сохранения в базу
  # необходимо передавать в rabbitmq
else
  current_logger.info p 'Error: not found "RAILS_ENV"!'
end




# class Runner
#   p Tariff.first
# end




  # p "Получаем тариф"
  # # Получаем тариф
  # # должна быть единственная настройка
  # tariff_setting = TariffSetting.last
  # if tariff_setting.present?
  #   tariff_id = eval(tariff_setting.code)
  #   tariff = Tariff.find_by_id tariff_id
  #   if tariff.present?
  #     $tariff = tariff 
  #   end
  # end