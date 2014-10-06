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
      
      @conn = Bunny.new
      @conn.start
      @ch   = @conn.create_channel
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

    def conn
      @conn
    end
    
    def ch
      @ch
    end


    def run 
      current_tariff = self.tariff

      if current_tariff.present? && self.redis.present?
        # imei = on board devise id
        tdr_hash = self.get_tdr_data
        
        if tdr_hash.present?
          delivery_tag = tdr_hash['delivery_tag']
          tdr = Tdr.new(eval( tdr_hash['tdr'] ))
          if tdr.present?
            obd = OnBoardDevice.find_by_number(tdr.imei)
            if obd.present? && obd.truck.present? && obd.truck.company.present?
              customer = obd.truck.company              
              sum = eval(current_tariff.code)                         
              tdr.sum = sum
              self.send_tdr_to_rabbit(tdr)  

              # отправка ack в канал
              @ch.ack(delivery_tag)

              @current_logger.info p "Обработан tdr #{tdr} ::: sum #{sum} ::: #{tdr.full_info}"    
            end
          end
        end
      end
      @conn.close
    end
    
    # применяется в DSL
    def night_time?
      false
    end

    # информация из TDR кролика
    def get_tdr_data
      # conn = @conn
      # conn.start

      q    = @ch.queue(SETTINGS_CONFIG['runner']['input_queue'])      
      
      tdr_data = nil

      q.subscribe(:manual_ack => true) do |delivery_info, properties, body|
        tdr_data = Hash.new
        
        tdr_data['delivery_tag'] = delivery_info.delivery_tag
        tdr_data['tdr'] = body
      end
      # conn.close     

      @current_logger.info p "Bunny ::: recieve data #{tdr_data}"
      tdr_data
    end

    def send_tdr_to_rabbit(tdr)
      @current_logger.info p "Отправка tdr в RabbitMQ #{tdr} ::: sum #{tdr.sum} ::: #{tdr.full_info}"
      conn = Bunny.new
      conn.start
      ch   = conn.create_channel

      q    = ch.queue(SETTINGS_CONFIG['runner']['output_queue'])

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

      ch.default_exchange.publish(tdr_bson.to_s, :routing_key => q.name)
      conn.close
    end 

  end
end