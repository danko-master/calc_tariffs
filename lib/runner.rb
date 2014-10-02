#!/usr/bin/env ruby
# encoding: utf-8

# перед стартом запускаем sidekiq
# export BACKGROUNDJOBS_ENV=development && bundle exec sidekiq
# export BACKGROUNDJOBS_ENV=test && bundle exec sidekiq
# export BACKGROUNDJOBS_ENV=production && bundle exec sidekiq

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


if ENV['RAILS_ENV']
  p ENV['RAILS_ENV']
  p SETTINGS_CONFIG['runner']['instances']

  if SETTINGS_CONFIG['runner']['instances'].present?
    inst_num = SETTINGS_CONFIG['runner']['instances'].to_i
  else
    inst_num = 1
  end
  

  $redis = Redis.new
  p "Получение всех компаний"
  # ключи в запущенных instances
  $keys_instances = Hash.new
  
  Company.all.each do |customer|
    if $redis.get("customers:#{customer.id}").blank?
      $redis.set("customers:#{customer.id}", customer.id)
      $redis.set("customers:#{customer.id}:discount", customer.discount)
    end
  end

  p "Получаем тариф"
  # Получаем тариф
  # должна быть единственная настройка
  tariff_setting = TariffSetting.last
  if tariff_setting.present?
    tariff_id = eval(tariff_setting.code)
    tariff = Tariff.find_by_id tariff_id
    $tariff = tariff if tariff.present?
  end
  
  p "Получаем информацию из кролика"
  # получаем инфу для обработки, это необходимо, если будет работать несколько экземпляров приложения
  tdr_data = TariffMachine::Calculation.get_tdr_data
  if tdr_data.size > 0
    tdr_data.each_with_index do |tdr, index|
      $redis.set("tdr:#{index}", tdr)
    end
  end



  # $redis.set("tdr", TariffMachine::Calculation.get_tdr_data)
  # p "tdr from redis"
  # p $redis.get("tdr")

  ## dev ##
  tm = TariffMachine::Calculation.new
  # # puts tm
  tm.run
  ## end dev ##


  # CalcWorker.perform_async
  # while inst_num > 0 do 
    # i = inst_num
    # while i > 0 do 
    #   p i
    #   p "WORKER!"
    #   CalcWorker.perform_async
    #   i += -1
    # end
  # end

  ##########################################
  # добавить результат успешности сохранения в базу
  # необходимо передавать в rabbitmq
else
  puts 'Error: not found "RAILS_ENV"!'
end




# class Runner
#   p Tariff.first
# end

# if ENV['RAILS_ENV']
#   # require 'pry'
#   # require_relative 'config/config'
#   # $config = Configuration.load_config

#   # require 'redis'
#   # $redis = Redis.new(path: $config['redis'])
  
#   p ENV['RAILS_ENV']
#   p Tariff.all

# else
#   puts 'Error: not found "RAILS_ENV"!'
# end
