module TariffMachine
  class Tdr
    def initialize(hash)
      @path = hash['path']
      @imei = hash['imei'].to_s
      @full_info = hash
      @sum
    end

    def imei
      @imei
    end

    def path
      @path
    end

    def full_info
      @full_info
    end

    def sum
      @sum
    end

    def sum=(sum)
      @sum = sum
    end
  end

  class Calculation
    def initialize
      @serial_key = Time.now.to_f     
      @redis = Redis.new
      @current_logger = Logger.new Rails.root.join("log", "tariff_machine_calculation." + Rails.env + ".log")
    end

    def tariff_setting
      TariffSetting.last
    end

    def tariff
      @tariff = Tariff.find_by_id eval(self.tariff_setting.code)
    end

    def redis
      @redis
    end

    def keys_instances
      eval self.redis.get("keys_instances")
    end

    def run 
      current_tariff = self.tariff

      if current_tariff.present? && self.redis.present? && self.redis.keys("tdr:*").size > 0
        tdr_key = get_tdr_key(0)    

        if tdr_key.present?    
          current_keys_instances = self.keys_instances      
          current_keys_instances[@serial_key] = tdr_key  
          self.redis.set("keys_instances", current_keys_instances)    

          # imei = on board devise id
          tdr = Tdr.new(eval(self.redis.get(tdr_key)))
          if tdr.present?
            obd = OnBoardDevice.find_by_oBD_number(tdr.imei)
            if obd.present? && obd.truck.present? && obd.truck.company.present?
              customer = obd.truck.company              
              sum = eval(current_tariff.code)                         
              self.redis.del(tdr_key) 
              tdr.sum = sum
              @current_logger.info p "Обработан tdr #{tdr} ::: sum #{sum} ::: #{tdr.full_info}" 
              self.send_tdr_to_rabbit(tdr)           
            end
          end

          current_keys_instances = self.keys_instances 
          current_keys_instances.delete(@serial_key)
          self.redis.set("keys_instances", current_keys_instances)
        end
      end
    end
    
    # применяется в DSL
    def night_time?
      false
    end

    def get_tdr_key(n)
      # берем первый ключ в редисе
      tdr_key = self.redis.keys("tdr:*")[n]
      # смотрим, используется ли он кем-нибудь
      if self.keys_instances.values.include? tdr_key
        # если да, то берем следующий ключ
        get_tdr_key(n+1)
      else
        tdr_key
      end
    end

    def send_tdr_to_rabbit(tdr)
      @current_logger.info p "Отправка tdr в RabbitMQ #{tdr} ::: sum #{tdr.sum} ::: #{tdr.full_info}"
      conn = Bunny.new
      conn.start

      ch   = conn.create_channel
      q    = ch.queue(SETTINGS_CONFIG['runner']['new_queue'])

      tdr_data = []
      tdr_bson = BSON::Document.new(
        # id машины
        imei: tdr.imei, 
        road_id: tdr.full_info['road_id'], 
        lat0: tdr.full_info['lat0'], 
        lon0: tdr.full_info['lon0'], 
        time0: tdr.full_info['time0'], 
        lat1: tdr.full_info['lat1'], 
        lon1: tdr.full_info['lon1'], 
        time1: tdr.full_info['time1'], 
        path: tdr.full_info['path'],
        sum: tdr.sum
      )

      tdr_data << tdr_bson

      ch.default_exchange.publish(tdr_data.to_s, :routing_key => q.name)
      conn.close
    end

    # информация из TDR кролика
    def self.get_tdr_data(current_logger)
      conn = Bunny.new
      conn.start

      ch   = conn.create_channel
      q    = ch.queue(SETTINGS_CONFIG['runner']['original_queue'])
      
      tdr_data_for_redis = []

      q.subscribe do |delivery_info, properties, body|
        data = eval(body)
        tdr_data_for_redis << data
      end
      conn.close     

      current_logger.info p "Bunny ::: recieve data #{tdr_data_for_redis}"
      tdr_data_for_redis.flatten
    end

    def self.set_tdr_data_to_redis(current_logger)
      tdr_data = TariffMachine::Calculation.get_tdr_data(current_logger)
      if tdr_data.size > 0
        tdr_data.each_with_index do |tdr, index|
          $redis.set("tdr:#{index}", tdr)
        end
      end
    end
  end
end