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

if !Dir.entries(".").includes?("add_license.cr")
  raise "Error: you must execute this file from the tools directory - please cd to the tools dir and run crystal run add_license.cr"
end

LICENSE = <<-LIC
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

LIC

Dir["../**/*.cr"].reject(&.starts_with?("../lib")).each do |file_path|
  lines = File.read_lines(file_path)
  if lines.first.starts_with?("# Copyright")
    puts "Good : #{file_path}"
  else
    puts "Amending : #{file_path}"
    content = [LICENSE] + lines
    File.open(file_path, "w", &.puts(content.join("\n")))
  end
end
