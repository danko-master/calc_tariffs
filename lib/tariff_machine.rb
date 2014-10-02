module TariffMachine
  class Customer
    def initialize(id)
      @discount = $redis.get("customers:#{id}:discount")
    end
    def discount
      @discount
    end
  end

  class Tdr
    def initialize(hash)
      # @path = hash
    end
  end

  class Calculation
    def initialize
      @serial_key = Time.now.to_f
    end

    def run
      puts "RUN"      
      if $tariff.present? && $redis.keys("tdr:*").size > 0
        tdr_key = get_tdr_key(0)    

        if tdr_key.present?          
          $keys_instances[@serial_key] = tdr_key
          p $keys_instances
          
          # TODO
          # из TDR брать данные по которым искать кастомера, далее по кастомеру делать скидку
          # imei = on board devise id

          # customer = Customer.new(2)
          # p customer.discount
          # sum = eval($tariff.code)
          # p "sum --- #{sum}"

          $keys_instances.delete(@serial_key)
          p $keys_instances
          # sum
        end
      else
        puts "Error! Tariff not found!"
      end
    end
    
    # применяется в DSL
    def night_time?
      false
    end

    def get_tdr_key(n)
      p "get_tdr_key"
      # берем первый ключ в редисе
      tdr_key = $redis.keys("tdr:*")[n]
      # смотрим, используется ли он кем-нибудь
      if $keys_instances.values.include? tdr_key
        # если да, то берем следующий ключ
        get_tdr_key(n+1)
      else
        tdr_key
      end
    end

    # информация из TDR кролика
    def self.get_tdr_data
      conn = Bunny.new
      conn.start

      ch   = conn.create_channel
      q    = ch.queue("svp")
      
      tdr_data_for_redis = []

      q.subscribe do |delivery_info, properties, body|
        puts " [x] RUBY Received RABBIT #{body}"
        data = eval(body)
        tdr_data_for_redis << data
      end
      conn.close     

      p "recieve data #{tdr_data_for_redis}"
      tdr_data_for_redis.flatten
    end


  end
end