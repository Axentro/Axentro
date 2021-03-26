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

require "../spec_helper"

describe "License" do
  it "should have a license at the top of every crystal file" do
    exclusions = ["bin/ameba.cr"]
    Dir["**/*.cr"].reject(&.starts_with?("lib")).each do |file_path|
      # if this fails uncomment the line below to see the failed file
      # to fix: cd tools then crystal run add_license.cr
      # puts "file: #{file_path}"
      if !exclusions.includes?(file_path)
        File.read_lines(file_path).first.should eq("# Copyright © 2017-2020 The Axentro Core developers")
      end
    end
  end
end
