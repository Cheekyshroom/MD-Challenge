# MD-Challenge

A webpage downloading tool, to use it:
(Make sure that you have port 12345 free).

And then decide if you want to manually fire off HTTP GET and POSTs to it, or use the command line utility.

If you want to use the utility:
Fire up the downloader with
```
./downloader.rb start &
```
and then set a couple pages up to download like so:
```
./downloader.rb google.com
```
which'll give you a job ID back.
Running:
```
./downloader.rb check <ID>
```
will tell you the status of your download, or if finished, print it to stdout.
If you want to see what IDs match what URLs, or want to see the progress of all downloads, use
```
./downloader.rb check all
```
which sends an HTTP GET request with a wildcard to our server.

When you want to stop running your daemon, simply run:
```
./downloader.rb kill
```

If you want to do everything manually, you can

1. Start it the same way.
2. Connect to port 12345 with your favorite utility (nc perhaps).
3. Send off a request like "POST _URL_" to get it downloading a URL.
4. Send off another request like "GET _ID_" or "GET *" to check your status or get downloads.
5. And finally send off a "POST kill" to finally kill your download server.
 

## Notes
Instead of threading it I wanted to make my program run as a daemon in the background.
Also, because it might be faster, I popped off a seperate thread for each page to download so it'd be asynch nicely (And as a plus avoid having to use mutexes or semaphores).
It might be nice to store the local port to connect to in an environment variable instead of hardcoding it too.
