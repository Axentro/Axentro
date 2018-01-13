module ::Sushi::Common::Color
  COLORS = %w(black red green yellow blue magenta cyan light_gray dark_gray light_red light_green light_yellow light_blue light_magenta light_cyan white)

  {% for color in COLORS %}
    def {{color.id}}(s) : String
      s.to_s.colorize.fore(:{{color.id}}).to_s
    end

    def {{color.id}}_bg(s) : String
      s.to_s.colorize.back(:{{color.id}}).to_s
    end
  {% end %}

end
