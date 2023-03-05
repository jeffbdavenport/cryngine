module Cryngine
  private module Input
    alias Window = Display::Window
    alias Keyboard = Devices::Keyboard
    alias Player = Map::Player
    # Seems too slow, but is the exact distance for a circle
    # BOTH_XY_MOVE = 0.7066666666666667
    BOTH_XY_MOVE = 0.77
    SPEED        =  250
    FPS          = Window::FPS
    class_property minus_x : Float64 = 0.0
    class_property minus_y : Float64 = 0.0
    class_property x_amount : Int16 = 0_i16
    class_property y_amount : Int16 = 0_i16
    class_property x_velocity : Int16 = 0_i16
    class_property y_velocity : Int16 = 0_i16
    class_getter mutex = Mutex.new
    class_getter input_mover_channel = Channel(Tuple(Int16, Int16)).new(2)

    class_property moved_time : Float64 = Time.monotonic.total_seconds

    class_getter map : Map
    @@map = uninitialized Map

    def self.speed
      SPEED
    end

    def self.rpg_2D_movement(map : Map)
      @@map = map

      # self.y
      # INPUT
      input_sleep = 1/FPS
      Loop.new(:input_x) do
        while x_velocity != 0
          sleep 50.microseconds
        end
        key_down = Keyboard.mutex.synchronize do
          Keyboard.key_down.dup
        end
        key_press = Keyboard.mutex.synchronize do
          Keyboard.key_press.dup
        end
        # Log.debug { "In X: #{Keyboard.key_down},#{Keyboard.key_press}" }

        mutex.synchronize do
          if (key_down[:left] || key_press[:left]) && (key_down[:right] || key_press[:right])
            self.x_amount = 0
          elsif key_down[:left] || key_press[:left]
            self.x_amount = -1
          elsif key_down[:right] || key_press[:right]
            self.x_amount = 1
          else
            self.x_amount = 0
          end
        end
        Keyboard.clear_x_press
        if x_amount == 0
          sleep(input_sleep)
          next
        end
        sleep_amount = if y_velocity != 0
                         (map.scaled_tile_height/BOTH_XY_MOVE)/speed
                       else
                         map.scaled_tile_height/speed
                       end
        # # puts "before Moving player"
        input_mover_channel.send({x_amount, 0_i16})
        sleep(sleep_amount)
      end

      Loop.new(:input_y) do
        while y_velocity != 0
          sleep 50.microseconds
        end
        key_down = Keyboard.mutex.synchronize do
          Keyboard.key_down.dup
        end
        key_press = Keyboard.mutex.synchronize do
          Keyboard.key_press.dup
        end
        # Log.debug { "In Y: #{key_down},#{key_press}" }
        mutex.synchronize do
          if (key_down[:up] || key_press[:up]) && (key_down[:down] || key_press[:down])
            self.y_amount = 0
          elsif key_down[:up] || key_press[:up]
            self.y_amount = -1
          elsif key_down[:down] || key_press[:down]
            self.y_amount = 1
          else
            self.y_amount = 0
          end
        end
        Keyboard.clear_y_press
        if y_amount == 0
          sleep(input_sleep)
          next
        end
        sleep_amount = if x_velocity != 0
                         (map.scaled_tile_width/BOTH_XY_MOVE)/speed
                       else
                         map.scaled_tile_width/speed
                       end

        input_mover_channel.send({0_i16, y_amount})
        # puts "Moving player"
        sleep(sleep_amount)
      end

      Loop.new(:input_mover) do
        x, y = input_mover_channel.receive
        # sleep 60.milliseconds
        # x2, y2 = input_mover_channel.receive unless input_mover_channel.empty?

        # x = x2 if x2 && x == 0
        # y = y2 if y2 && y == 0
        Player.move(x, y)
        self.moved_time = Time.monotonic.total_seconds
        self.x_velocity = x unless x == 0
        self.y_velocity = y unless y == 0
        self.minus_x = (x * map.scaled_tile_width).to_f unless x == 0
        self.minus_y = (y * map.scaled_tile_height).to_f unless y == 0
      end
    end

    def self.after_print_player_move
      mutex.synchronize do
        # We had finished our move

        if x_velocity != 0 && y_velocity != 0
          # self.minus_x = ((x_speed_mult/BOTH_XY_MOVE) - x_velocity*(speed*time))
          # self.minus_y = ((y_speed_mult/BOTH_XY_MOVE) - y_velocity*(speed*time))
          self.minus_x -= (x_velocity*speed/FPS)*BOTH_XY_MOVE
          self.minus_y -= (y_velocity*speed/FPS)*BOTH_XY_MOVE
        else
          # self.minus_x = (x_speed_mult - x_velocity*(speed*time)) unless minus_x == 0
          # self.minus_y = (y_speed_mult - y_velocity*(speed*time)) unless minus_y == 0
          self.minus_x -= (x_velocity*speed/FPS) unless minus_x == 0
          self.minus_y -= (y_velocity*speed/FPS) unless minus_y == 0
        end
        self.minus_x = 0 if minus_x < 0 && x_velocity > 0
        self.minus_y = 0 if minus_y < 0 && y_velocity > 0
        self.minus_x = 0 if minus_x > 0 && x_velocity < 0
        self.minus_y = 0 if minus_y > 0 && y_velocity < 0

        self.x_velocity = 0 if minus_x == 0
        self.y_velocity = 0 if minus_y == 0
      end
    end
  end
end
