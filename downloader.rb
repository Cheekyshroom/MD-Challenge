#!/usr/bin/env ruby
require 'net/http'
require 'socket'

Thread.abort_on_exception = true

class DownloadQueue
  def initialize()
    @elements = []
  end
  def add(url)
    #instead of having a download queue, just pop off another thread for each
    #download, so they all get done at once and hopefully faster
    @elements << Thread.new do
      Net::HTTP.get(URI(url))
    end
    @elements.length-1 #return our job id
  end
  def query(id)
    i = id.to_i
    #make sure we have a valid id
    if i < 0 or >= @elements.length
      return "ID out of range."
    end
    status = @elements[i].status 
    if status == false #false indicates success
      return "Done", @elements[i].value
    else if status == nil #nil indicates failure
      return "Failure", status
    else
      return "In progress.", status
    end
  end
end

def begin_server
  #start our daemon
  server = TCPServer.new(12345)
  begin
    queue = DownloadQueue.new
    loop do
      client = server.accept
      begin
        request = client.gets.chomp
        case request
          when "kill"
            break
          when "check"
            id = client.gets
            status, value = queue.query(id)
            client.puts(status)
            if status == "Done"
              size = value.length
              client.puts(size)
              client.write(value)
            end
          when "download"
            uri = client.gets
            i = queue.add(uri)
            client.puts(i)
          else
            puts("INVALID REQUEST #{request}")
        end
      ensure
        client.close
      end
    end
  ensure
    server.close
  end
end

def begin_client
  socket = TCPSocket.new('localhost', 12345)
  begin
    case ARGV[0]
      when "kill"
        #send a kill message to our daemon
        socket.puts("kill")
      when "check"
        #check the progress of a job id or get the resulting webpage
        #result, progress = check_id(socket)
        socket.puts("check")
        socket.puts(ARGV[1])
        status = socket.gets.chomp
        if status == "Done"
          size = socket.gets.to_i
          data = socket.read(size)
          puts(data)
        else
          puts(status)
        end
      else
        #download a URL
        url = (ARGV[0][0..6] == "http://" or ARGV[0][0..7] == "https://") ? ARGV[0] : "http://"+ARGV[0]
        socket.puts("download")
        socket.puts(url)
        id = socket.gets
        puts(id)
    end
  ensure
    #make sure that our socket gets closed
    socket.close()
  end
end

if ARGV.length < 1
  puts("Usage: downloader [start] [kill] [check id] [download url]")
  exit
end
if ARGV[0] == "start"
  begin_server
else
  begin_client
end

