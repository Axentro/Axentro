FROM crystallang/crystal:0.29.0

RUN mkdir -p /usr/local/SushiChain
RUN mkdir -p /usr/local/bin

WORKDIR /usr/local/SushiChain

RUN apt-get update
RUN apt-get install curl libsqlite3-dev -y

COPY . .

RUN shards build

RUN ln -s /usr/local/SushiChain/bin/sushid /usr/local/bin/sushid
RUN ln -s /usr/local/SushiChain/bin/sushim /usr/local/bin/sushim
RUN ln -s /usr/local/SushiChain/bin/sushi  /usr/local/bin/sushi

EXPOSE 3000 3443
