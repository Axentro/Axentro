# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module Spec
  # :nodoc:
  def self.lines_cache
    @@lines_cache ||= {} of String => Array(String)
  end

  # :nodoc:
  def self.read_line(file, line)
    return nil unless File.file?(file)

    lines = lines_cache[file] ||= File.read_lines(file)
    lines[line - 1]?
  end

  # :nodoc:
  def self.relative_file(file)
    cwd = Dir.current
    if basename = file.lchop? cwd
      basename.lchop '/'
    else
      file
    end
  end
end
