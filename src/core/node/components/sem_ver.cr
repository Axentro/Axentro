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

module ::Axentro::Core::NodeComponents
  class SemVer
    getter major_version : Int32
    getter minor_version : Int32
    getter patch_version : Int32

    def initialize(@version : String)
      info = validate
      @major_version = info[:major_version]
      @minor_version = info[:minor_version]
      @patch_version = info[:patch_version]
    end

    private def validate
      semver_regex = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$/
      raise "Invalid sementic version format for supplied version: #{@version} - it should be in the format e.g. 1.0.1" unless semver_regex.match(@version)

      data = semver_regex.match(@version).not_nil!
      {major_version: data[1].to_i, minor_version: data[2].to_i, patch_version: data[3].to_i}
    rescue e : Exception
      raise "Semantic versioning validation error: #{e.message || "unknown"}"
    end
  end
end
