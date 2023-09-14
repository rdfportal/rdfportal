# frozen_string_literal: true

class Integer
  def readable_duration
    s = (self % 60).round(3)
    m = (self / 60).to_i % 60
    h = (self / 60 / 60).to_i % 24
    d = (self / 60 / 60 / 24).to_i

    "#{"#{d}d " if d.positive?}#{format('%<h>02d:%<m>02d:%<s>02d', { h:, m:, s: })}"
  end
end
