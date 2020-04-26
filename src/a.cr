
words = ["hello","coool","woops","nice"]

channel = Channel(String).new(words.size)

words.each do |word|
    spawn { channel.send "#{word}_processed" }
end

results = Array.new(words.size){ channel.receive }

pp results

