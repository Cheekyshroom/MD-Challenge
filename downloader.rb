#!/usr/bin/env ruby
require 'net/http'
require 'socket'

Thread.abort_on_exception = true

#because we don't want to 
class DownloadQueue
  def initialize()
    @elements = []
  end
  def add(url)
    puts("Adding #{url}")
    @elements << Thread.new do
      Net::HTTP.get(URI(url))
    end
    @elements.length-1
  end
  def query(id)
    puts("Querying id #{id}")
    i = id.to_i
    status = @elements[i].status
    if status == false #specifically not nil too.
      @elements[i].value
    else
      status
    end
  end
end

if ARGV.length < 1
  puts("Usage: downloader [start] [kill] [check id] [download url]")
  exit
end
if ARGV[0] == "start"
  #start our daemon
  puts("Making new server")
  server = TCPServer.new(12345)
  begin
    queue = DownloadQueue.new()
    loop do
      client = server.accept()
      begin
        puts("Request received")
        request = client.gets().chomp()
        case request
          when "kill"
            break
          when "check"
            id = client.gets()
            query = queue.query(id)
            client.puts(query)
          when "download"
            uri = client.gets()
            i = queue.add(uri)
            client.puts(i)
          else
            puts("INVALID REQUEST #{request}")
        end
      ensure
        client.close()
      end
    end
  ensure
    server.close()
  end
else
  socket = TCPSocket.new('localhost', 12345)
  begin
    case ARGV[0]
      when "kill"
        #kill our daemon
        #kill_daemon(socket)
        socket.puts("kill")
      when "check"
        #check the progress of a job id
        #result, progress = check_id(socket)
        socket.puts("check")
        socket.puts(ARGV[1])
        response = socket.gets()
        puts(response)
      else
        #download a URL
        socket.puts("download")
        socket.puts(ARGV[1])
        id = socket.gets()
        puts(id)
    end
  ensure
    socket.close()
  end
end

