Qerl
=====

	
What is qerl
-----

Qerl is a Qiniu lib for Erlang

Qerl will:

> 1. upload file/binary to Qiniu
> 2. manage file/bucket
> 3. auth the request of upload or the callback from Qiniu
> 4. calculate qetag in parallel
> 5. retry automatically (for some http status codes)
> 6. ...


Build
-----

    $ rebar3 compile

USAGE
-----
	add it as a dependency in your application
	add your ak sk in the ./include/config.hrl
	add qerl in you app.src
	

	

    
