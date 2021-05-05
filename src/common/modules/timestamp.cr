# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Common::Timestamp
  def __timestamp : Int64
    Time.utc.to_unix_ms
  end

  module Int64::EpochMillisConverter
    def self.to_json(value : Int64, json : JSON::Builder)
      json.string(Time.unix_ms(value).to_s)
    end

    def self.from_json(value : JSON::PullParser) : Int64
      Time.parse_utc(value.read_string, "%Y-%m-%d %H:%M:%S %z").to_unix_ms
    end
  end
end
