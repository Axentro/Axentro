require "file_utils"

FileUtils.rm_rf("miners")
FileUtils.mkdir("miners")

AMOUNT = 20

(0..AMOUNT).to_a.each do |n|
  puts `axe wallet create -w miners/wallet_#{n}.json --testnet`
end

(0..AMOUNT).to_a.each do |n|
    File.open("./miners/start_miner_#{n}.sh", "w"){|f| f.puts "nohup axem -w ./miners/wallet_#{n}.json --testnet -n http://testnet.axentro.io --process=1 &" }
end

`chmod +x miners/*.sh`



(0..AMOUNT).to_a.each do |n|
     Process.run("nohup #{__DIR__}/miners/start_miner_#{n}.sh &", shell: true)
end



