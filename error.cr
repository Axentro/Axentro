require "scrypt"

N = 1024
R = 8
P = 48
K = 256

password = "6dc36b8921df93dbdcf1d7cbfc952fd1a61db1051a0d2bbc6a9d2690228690e2"
salt = "5137391304548937013"

p ::Scrypt::Engine.crypto_scrypt(password, salt, N, R, P, K)
