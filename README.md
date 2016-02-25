# MD-Challenge

A webpage downloading tool, to use it:
(Make sure that you have port 12345 free).
Fire up the downloader with
```
./daemon.rb &
```
and then set a couple pages up to download like so:
```
./interface.rb google.com
```
which'll give you a job ID back.
Running:
```
./interface.rb check <ID>
```
will tell you the status of your download, or if finished, print it to stdout.
When you want to stop running your daemon, simply run:
```
./interface.rb kill
```
