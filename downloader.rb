#!/usr/bin/env ruby
require 'net/http'
require 'socket'

class DownloadQueue
  #could've used a struct instead
  class Connection
    #holds information about a download thread so we can list it nicely
    attr_accessor :thread, :url
    def initialize(thread, url)
      @thread = thread
      @url = url
    end
    def status
      status = @thread.status 
      if status == false #false indicates success
        return "Done", @thread.value
      elsif status == nil #nil indicates failure
        return "Failure", status
      else
        return "In progress", status
      end
    end
  end

  def initialize()
    @elements = []
  end

  def add(url)
    #instead of having a download queue, just pop off another thread for each
    #download, so they all get done at once and hopefully faster
    thread = Thread.new do
      Net::HTTP.get(URI(url))
    end
    @elements << Connection.new(thread, url)
    @elements.length-1 #return our job id
  end

  def query(id)
    i = id.to_i
    #make sure we have a valid id
    if i < 0 or i >= @elements.length
      return "ID out of range."
    end
    return @elements[i].status
  end
  def list
    #did this with reduce but realized I needed the index to have a nice list
    out = ""
    @elements.length.times do |i|
      status, _ = @elements[i].status
      out << "#{i} [#{status}]: #{@elements[i].url}\n"
    end
    out + "Done\n"
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
      string = client.gets.lstrip.chomp
      endOfRequest = string.index(' ')
      #make sure that the request is at least two words so substringing won't break
      if endOfRequest == nil
        #puts("INVALID REQUEST '#{string}'")
        #client.puts("INVALID REQUEST '#{string}'")
        return true
      end
      #split our string into a GET/POST and an argument
      request = string[0..endOfRequest-1]
      endOfRest = string.index(' ', endOfRequest+1)
      rest = string[endOfRequest+1..(endOfRest or string.length)]
      case request
        when "GET" #GETS only query or list
          #if they query a wildcard, give them a list of downloads back
          if rest == "*"
            client.puts(@queue.list)
            return true
          end
          #query our queue to see if our download has finished
          status, value = @queue.query(rest)
          #print the status regardless of what it is
          client.puts(status)
          if status == "Done"
            #send our downloaded page if it's complete
            size = value.length
            client.puts(size)
            client.write(value)
          end
        when "POST" #POSTS can kill our server or start a new download
          if rest == "kill"
            return false #kill our server if it's a kill request, otherwise handle
          end
          #add a download to our queue
          uri = rest
          i = @queue.add(uri)
          client.puts(i)
        else
          #puts("INVALID REQUEST '#{string}' '#{request}' '#{rest}'")
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
          @socket.puts("POST kill")
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
    #if we want to get a list:
    if id == "all"
      #print output until we get "Done"
      @socket.puts("GET *")
      loop do
        line = @socket.gets.chomp
        if line == "Done"
          break
        end
        puts(line)
      end
      return
    end
    #otherwise
    #send a check message and get the download status back
    @socket.puts("GET #{id}")
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
    #make our url begin with http:// or https:// otherwise Net::HTTP will
    #complain
    url = (s[0..6] == "http://" or s[0..7] == "https://") ? s : "http://"+s
    #send our download message and the url
    @socket.puts("POST #{url}")
    #and print the id we get back
    id = @socket.gets
    puts(id)
  end
end

if ARGV.length < 1
  puts("Usage: downloader [start] [kill] [check [id|all]] [url]")
  exit
end
if ARGV[0] == "start"
  Server.new(12345)
else
  Client.new(12345)
end
