#!/usr/bin/env ruby
require 'net/http'
require 'socket'

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
    if i < 0 or i >= @elements.length
      return "ID out of range."
    end
    status = @elements[i].status 
    if status == false #false indicates success
      return "Done", @elements[i].value
    elsif status == nil #nil indicates failure
      return "Failure", status
    else
      return "In progress.", status
    end
  end
end

class Server
  def initialize(port)
    @server = TCPServer.new(port)
    begin
      @queue = DownloadQueue.new
      loop do
        #handle a client request and quit if we should
        continue = handle_request
        if not continue
          break #quit if we got a kill request
        end
      end
    ensure
      @server.close
    end
  end

  def handle_request
    client = @server.accept
    begin
      request = client.gets.chomp
      case request
        when "kill"
          return false
        when "check"
          #query our queue to see if our download has finished
          id = client.gets
          status, value = @queue.query(id)
          #print the status regardless of what it is
          client.puts(status)
          if status == "Done"
            #send our downloaded page if it's complete
            size = value.length
            client.puts(size)
            client.write(value)
          end
        when "download"
          #add a download to our queue
          uri = client.gets
          i = @queue.add(uri)
          client.puts(i)
        else
          puts("INVALID REQUEST #{request}")
      end
    ensure
      client.close
    end
    return true #continue accepting requests
  end
end

class Client
  def initialize(port)
    @socket = TCPSocket.new('localhost', port)
    begin
      case ARGV[0]
        when "kill"
          #send a kill message to our daemon
          @socket.puts("kill")
        when "check"
          #check the progress of a job id or get the resulting webpage
          check_id(ARGV[1])
        else
          #download a URL
          download_url(ARGV[0])
      end
    ensure
      #make sure that our socket gets closed
      @socket.close()
    end
  end

  def check_id(id)
    #send a check message and get the download status back
    @socket.puts("check")
    @socket.puts(id)
    status = @socket.gets.chomp
    if status == "Done"
      #if our download's done, print it to stdout
      size = @socket.gets.to_i
      data = @socket.read(size)
      puts(data)
    else
      #otherwise print our download status
      puts(status)
    end
  end

  def download_url(s)
    #make our url begin with http:// or https:// otherwise Net::HTTP
    #will complain
    url = (s[0..6] == "http://" or s[0..7] == "https://") ? s : "http://"+s
    #send our download message and the url
    @socket.puts("download")
    @socket.puts(url)
    #and print the id we get back
    id = @socket.gets
    puts(id)
  end
end

if ARGV.length < 1
  puts("Usage: downloader [start] [kill] [check id] [download url]")
  exit
end
if ARGV[0] == "start"
  Server.new(12345)
else
  Client.new(12345)
end
